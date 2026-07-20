local Ox = require '@ox_core.lib.init'
local deliveries = {}
local testDrives = {}
local vehicleColors = {
    [1] = { 17, 18, 20 }, [2] = { 232, 232, 229 },
    [3] = { 181, 31, 46 }, [4] = { 36, 78, 145 }
}
local REQUIRED_POINTS = {
    payment = 'local de pagamento', truckSpawn = 'spawn do caminhao',
    invoiceNpc = 'retirada da NF', trailerSpawn = 'spawn do trailer',
    unload = 'ponto de entrega', preview = 'preview',
    saleSpawn = 'spawn da compra', testSpawn = 'spawn do test-drive', blip = 'blip do local'
}

local function isDealershipJob(set)
    if type(set) ~= 'string' or GetResourceState('nv_orgs') ~= 'started' then return false end
    local ok, subtype = pcall(function() return exports.nv_orgs:GetOrgSubtype(set) end)
    if not ok or subtype ~= 'dealership' then return false end
    local group = Ox.GetGroup(set)
    return group ~= nil and (group.type == 'job' or group.type == 'state')
end

local function unitConfig(set)
    if not isDealershipJob(set) then return nil, 'Este job nao e do tipo concessionaria.' end
    local raw = exports.nv_orgs:GetDealershipConfig(set)
    if not raw or type(raw.points) ~= 'table' then return nil, 'A concessionaria ainda nao foi configurada.' end
    local missing = {}
    for point, label in pairs(REQUIRED_POINTS) do
        if type(raw.points[point]) ~= 'table' then missing[#missing + 1] = label end
    end
    if #missing > 0 then
        table.sort(missing)
        return nil, ('Configure os pontos pendentes: %s.'):format(table.concat(missing, ', '))
    end
    local group = Ox.GetGroup(set)
    local unit = { set = set, label = raw.label or (group and group.label) or set, categories = raw.categories or {} }
    for key, value in pairs(raw.points) do
        if key == 'blip' then
            unit.blip = value
        else
            unit[key] = key == 'unload' and vec3(value.x, value.y, value.z)
                or vec4(value.x, value.y, value.z, value.w or 0.0)
        end
    end
    return unit
end

local function unitFor(source, requested)
    local player = Ox.GetPlayer(source)
    if not player or not isDealershipJob(requested) then return nil, 'Voce nao pertence a uma concessionaria.' end
    local groups = player.getGroups()
    if not groups or groups[requested] == nil then return nil, 'Voce nao pertence a esta concessionaria.' end
    local unit, err = unitConfig(requested)
    if not unit then return nil, err end
    return unit, player
end

lib.callback.register('nv_dealership:myUnit', function(source)
    local player = Ox.GetPlayer(source)
    local groups = player and player.getGroups()
    if not groups then return end
    for set in pairs(groups) do
        if isDealershipJob(set) then return set end
    end
end)

lib.callback.register('nv_dealership:blips', function()
    if GetResourceState('nv_orgs') ~= 'started' then return {} end
    local ok, units = pcall(function() return exports.nv_orgs:GetDealerships() end)
    return ok and units or {}
end)

local function insideOperationalArea(source, unit)
    local blip = unit and unit.blip
    local ped = GetPlayerPed(source)
    if not blip or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vec3(blip.x, blip.y, blip.z)) <= (tonumber(blip.radius) or 60.0)
end

local function catalogEntry(model)
    for i = 1, #Config.Catalog do
        if Config.Catalog[i].model == model then return Config.Catalog[i] end
    end
end

local function deleteDeliveryEntities(job)
    if not job then return end
    if job.trailer and DoesEntityExist(job.trailer) then DeleteEntity(job.trailer) end
    for i = 1, #(job.cargo or {}) do
        if DoesEntityExist(job.cargo[i]) then DeleteEntity(job.cargo[i]) end
    end
    if job.truck and DoesEntityExist(job.truck) then DeleteEntity(job.truck) end
end

local function removeInvoiceItems(source, invoice, onlySlot)
    if onlySlot then
        return exports.ox_inventory:RemoveItem(source, 'dealership_invoice', 1, nil, onlySlot) == true
    end

    local removed = false
    local slots = exports.ox_inventory:Search(source, 'slots', 'dealership_invoice') or {}
    for _, slot in pairs(slots) do
        if slot.metadata and slot.metadata.invoice == invoice then
            removed = exports.ox_inventory:RemoveItem(source, 'dealership_invoice', 1, nil, slot.slot) == true or removed
        end
    end
    return removed
end

local pickupMinutes = math.max(1, math.floor(tonumber(Config.OrderPickupMinutes) or 20))
local expiryCondition = ('`created_at` <= DATE_SUB(NOW(), INTERVAL %d MINUTE)'):format(pickupMinutes)

local function refundExpiredOrder(row)
    local claimed = MySQL.update.await(([[
        UPDATE `nv_dealership_orders` SET `status` = 'refunding'
        WHERE `invoice` = ? AND `status` = 'paid' AND %s
    ]]):format(expiryCondition), { row.invoice })
    if claimed ~= 1 then return false end

    local account = Ox.GetGroupAccount(row.unit)
    local credited, result = pcall(function()
        return account and account.addBalance({
            amount = tonumber(row.total) or 0,
            message = ('Estorno: pedido %s nao retirado'):format(row.invoice)
        })
    end)
    if not credited or type(result) ~= 'table' or result.success ~= true then
        MySQL.update.await("UPDATE `nv_dealership_orders` SET `status` = 'paid' WHERE `invoice` = ? AND `status` = 'refunding'", { row.invoice })
        print(('[nv_dealership] Nao foi possivel estornar a NF %s para o caixa %s.'):format(row.invoice, row.unit))
        return false
    end

    MySQL.update.await("UPDATE `nv_dealership_orders` SET `status` = 'cancelled' WHERE `invoice` = ? AND `status` = 'refunding'", { row.invoice })
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        local player = Ox.GetPlayer(source)
        if player and tonumber(player.charId) == tonumber(row.seller) then
            removeInvoiceItems(source, row.invoice)
            local job = deliveries[source]
            if job and job.invoice == row.invoice then
                deleteDeliveryEntities(job)
                deliveries[source] = nil
            end
            TriggerClientEvent('nv_dealership:orderExpired', source, row.invoice)
            break
        end
    end
    return true
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `nv_dealership_stock` (
            `unit` VARCHAR(30) NOT NULL, `model` VARCHAR(60) NOT NULL, `quantity` INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`unit`, `model`)
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `nv_dealership_orders` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `invoice` VARCHAR(24) NOT NULL,
            `unit` VARCHAR(30) NOT NULL, `seller` INT NOT NULL, `items` LONGTEXT NOT NULL,
            `total` INT UNSIGNED NOT NULL, `status` VARCHAR(20) NOT NULL DEFAULT 'paid',
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`), UNIQUE KEY (`invoice`)
        )
    ]])

    while true do
        local expired = MySQL.query.await(([=[
            SELECT `invoice`, `unit`, `seller`, `total` FROM `nv_dealership_orders`
            WHERE `status` = 'paid' AND %s
        ]=]):format(expiryCondition)) or {}
        for i = 1, #expired do refundExpiredOrder(expired[i]) end
        Wait(30000)
    end
end)

exports('GetCatalog', function()
    local result = {}
    for i = 1, #Config.Catalog do
        result[#result + 1] = { model = Config.Catalog[i].model, label = Config.Catalog[i].label,
            category = Config.Catalog[i].category, price = Config.Catalog[i].price }
    end
    return result
end)

lib.callback.register('nv_dealership:data', function(source, unitId)
    local unit, unitError = unitFor(source, unitId)
    if not unit then return nil, unitError end
    local rows = MySQL.query.await('SELECT `model`, `quantity` FROM `nv_dealership_stock` WHERE `unit` = ?', { unitId }) or {}
    local stock = {}
    for i = 1, #rows do stock[rows[i].model] = rows[i].quantity end
    local vehicles = {}
    for i = 1, #Config.Catalog do
        local entry = Config.Catalog[i]
        if unit.categories[entry.category] or (stock[entry.model] or 0) > 0 then
            vehicles[#vehicles + 1] = { model = entry.model, label = entry.label, brand = entry.brand,
                category = entry.category, price = entry.price, cost = entry.cost,
                stock = stock[entry.model] or 0, canOrder = unit.categories[entry.category] == true }
        end
    end
    local account = Ox.GetGroupAccount(unit.set)
    return { unit = unitId, label = unit.label, vehicles = vehicles, balance = account and account.balance or 0,
        config = { preview = unit.preview, truckSpawn = unit.truckSpawn } }
end)

lib.callback.register('nv_dealership:nearby', function(source)
    local ped, result = GetPlayerPed(source), {}
    if ped == 0 then return result end
    local origin = GetEntityCoords(ped)
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= source then
            local targetPed = GetPlayerPed(id)
            if targetPed ~= 0 and #(origin - GetEntityCoords(targetPed)) <= 5.0 then
                local player = Ox.GetPlayer(id)
                result[#result + 1] = { id = id, name = player and (player.get('name') or player.name) or ('ID ' .. id) }
            end
        end
    end
    return result
end)

lib.callback.register('nv_dealership:startTest', function(source, unitId, model)
    local unit = unitFor(source, unitId)
    local entry = catalogEntry(model)
    if not unit or not entry or testDrives[source] then return false end
    local ped = GetPlayerPed(source)
    testDrives[source] = { bucket = Config.TestBucketBase + source, model = model, label = entry.label }
    SetPlayerRoutingBucket(source, testDrives[source].bucket)
    return true, nil, { spawn = unit.testSpawn, seconds = Config.TestDriveSeconds }
end)

lib.callback.register('nv_dealership:registerTestVehicle', function(source, netId)
    local test = testDrives[source]
    if not test or test.netId or type(netId) ~= 'number' then return false, 'Test-drive nao encontrado.' end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local deadline = GetGameTimer() + 5000
    while vehicle == 0 and GetGameTimer() < deadline do
        Wait(50)
        vehicle = NetworkGetEntityFromNetworkId(netId)
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityModel(vehicle) ~= GetHashKey(test.model)
        or GetEntityRoutingBucket(vehicle) ~= test.bucket then
        return false, 'Nao foi possivel registrar o veiculo de teste.'
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+$', '')
    if not exports.nv_garage:GiveKey(source, plate, ('Test-drive: %s'):format(test.label)) then
        return false, 'Nao foi possivel entregar a chave do test-drive.'
    end

    test.plate, test.netId = plate, netId
    return true
end)

lib.callback.register('nv_dealership:endTest', function(source)
    local test = testDrives[source]
    if test then
        if test.plate then exports.nv_garage:RemoveKey(source, test.plate) end
        SetPlayerRoutingBucket(source, 0)
        testDrives[source] = nil
    end
    return true
end)

lib.callback.register('nv_dealership:sell', function(source, unitId, model, targetId, colorId)
    local unit = unitFor(source, unitId)
    local target = Ox.GetPlayer(tonumber(targetId))
    local entry = catalogEntry(model)
    if not unit or not target or not entry then return false, 'Venda invalida.' end
    local color = vehicleColors[tonumber(colorId)] or vehicleColors[1]
    if not insideOperationalArea(source, unit) then return false, 'Va ate a area da concessionaria para vender.' end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(target.source))) > 6.0 then
        return false, 'O comprador se afastou.'
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - vec3(unit.payment.x, unit.payment.y, unit.payment.z)) > 8.0 then
        return false, 'Va ate o local de pagamento da concessionaria.'
    end
    local changed = MySQL.update.await([[
        UPDATE `nv_dealership_stock` SET `quantity` = `quantity` - 1
        WHERE `unit` = ? AND `model` = ? AND `quantity` > 0
    ]], { unitId, model })
    if changed ~= 1 then return false, 'Veiculo sem estoque.' end
    local buyerAccount = Ox.GetCharacterAccount(target.charId)
    local groupAccount = Ox.GetGroupAccount(unit.set)
    if not buyerAccount or not groupAccount then
        MySQL.update.await('UPDATE `nv_dealership_stock` SET `quantity` = `quantity` + 1 WHERE `unit` = ? AND `model` = ?', { unitId, model })
        return false, 'Conta do comprador ou da organizacao indisponivel.'
    end
    local charged, debit = pcall(function()
        return buyerAccount.removeBalance({ amount = entry.price, message = ('Compra: %s'):format(entry.label) })
    end)
    if not charged or type(debit) ~= 'table' or debit.success ~= true then
        MySQL.update.await('UPDATE `nv_dealership_stock` SET `quantity` = `quantity` + 1 WHERE `unit` = ? AND `model` = ?', { unitId, model })
        return false, 'Saldo insuficiente do comprador.'
    end
    local credited, credit = pcall(function()
        return groupAccount.addBalance({ amount = entry.price, message = ('Venda: %s'):format(entry.label) })
    end)
    if not credited or type(credit) ~= 'table' or credit.success ~= true then
        buyerAccount.addBalance({ amount = entry.price, message = 'Estorno de venda recusada' })
        MySQL.update.await('UPDATE `nv_dealership_stock` SET `quantity` = `quantity` + 1 WHERE `unit` = ? AND `model` = ?', { unitId, model })
        return false, 'Nao foi possivel creditar o caixa da organizacao.'
    end
    local vehicle
    local ok = pcall(function()
        vehicle = Ox.CreateVehicle({
            model = model,
            owner = target.charId,
            properties = { color1 = color, color2 = color }
        },
            vec3(unit.saleSpawn.x, unit.saleSpawn.y, unit.saleSpawn.z), unit.saleSpawn.w)
    end)
    if not ok or not vehicle then
        MySQL.update.await('UPDATE `nv_dealership_stock` SET `quantity` = `quantity` + 1 WHERE `unit` = ? AND `model` = ?', { unitId, model })
        groupAccount.removeBalance({ amount = entry.price, message = 'Estorno de veiculo nao criado' })
        buyerAccount.addBalance({ amount = entry.price, message = 'Estorno de veiculo nao criado' })
        return false, 'Nao foi possivel criar o veiculo.'
    end
    exports.nv_garage:GiveKey(target.source, vehicle.plate, entry.label)
    return true, nil, entry.label
end)

lib.callback.register('nv_dealership:order', function(source, unitId, requested)
    local unit, player = unitFor(source, unitId)
    if not unit or type(requested) ~= 'table' then return false, 'Pedido invalido.' end
    if not insideOperationalArea(source, unit) then return false, 'Va ate a area da concessionaria para fazer o pedido.' end
    local clean, units, total = {}, 0, 0
    for model, quantity in pairs(requested) do
        local entry, count = catalogEntry(model), math.floor(tonumber(quantity) or 0)
        if entry and unit.categories[entry.category] and count > 0 then
            units, total = units + count, total + entry.cost * count
            clean[#clean + 1] = { model = model, label = entry.label, quantity = count, cost = entry.cost }
        end
    end
    if units < 1 or units > Config.MaxOrderUnits then return false, 'O pedido deve ter entre 1 e 10 unidades.' end
    if not exports.ox_inventory:CanCarryItem(source, 'dealership_invoice', 1) then
        return false, 'Sem espaco para guardar a nota fiscal.'
    end
    local account = Ox.GetGroupAccount(unit.set)
    if not account then return false, 'Caixa da concessionaria indisponivel.' end
    local charged, result = pcall(function()
        return account.removeBalance({ amount = total, message = ('Compra de estoque: %d veiculos'):format(units) })
    end)
    if not charged or type(result) ~= 'table' or result.success ~= true then
        return false, 'Saldo insuficiente no caixa.'
    end
    local truck = tonumber(CreateVehicle(Config.TruckModel, unit.truckSpawn.x, unit.truckSpawn.y, unit.truckSpawn.z, unit.truckSpawn.w, true, true)) or 0
    local deadline = GetGameTimer() + 5000
    while truck ~= 0 and not DoesEntityExist(truck) and GetGameTimer() < deadline do Wait(50) end
    if truck == 0 or not DoesEntityExist(truck) then
        account.addBalance({ amount = total, message = 'Estorno: caminhao indisponivel' })
        return false, 'Nao foi possivel criar o caminhao. O valor foi estornado.'
    end
    local invoice = ('NF-%s-%06d'):format(os.date('%y%m%d'), math.random(0, 999999))
    local saved, orderId = pcall(MySQL.insert.await,
        'INSERT INTO `nv_dealership_orders` (`invoice`,`unit`,`seller`,`items`,`total`) VALUES (?,?,?,?,?)',
        { invoice, unitId, player.charId, json.encode(clean), total })
    local added = saved and orderId and exports.ox_inventory:AddItem(
        source, 'dealership_invoice', 1, { invoice = invoice, label = invoice })
    if not added then
        if orderId then MySQL.update.await('DELETE FROM `nv_dealership_orders` WHERE `id` = ?', { orderId }) end
        if DoesEntityExist(truck) then DeleteEntity(truck) end
        account.addBalance({ amount = total, message = 'Estorno: pedido nao iniciado' })
        return false, 'Nao foi possivel gerar a NF. O valor foi estornado.'
    end
    deliveries[source] = { invoice = invoice, unit = unitId, items = clean, totalUnits = units, truck = truck }
    exports.nv_garage:GiveKey(source, GetVehicleNumberPlateText(truck), 'Caminhao da concessionaria')
    return true, nil, { invoice = invoice, truckNet = NetworkGetNetworkIdFromEntity(truck), destination = unit.invoiceNpc }
end)

lib.callback.register('nv_dealership:validateInvoice', function(source, requestedUnit)
    local slots = exports.ox_inventory:Search(source, 'slots', 'dealership_invoice') or {}
    local player = Ox.GetPlayer(source)
    if not player then return false, 'Jogador nao encontrado.' end

    local found, row, unit
    for _, slot in pairs(slots) do
        local invoice = slot.metadata and slot.metadata.invoice
        if invoice then
            local candidate = MySQL.single.await(([[
                SELECT `invoice`, `unit`, `seller`, `items`, `total`, `status`
                FROM `nv_dealership_orders`
                WHERE `invoice` = ? AND `seller` = ? AND `unit` = ?
                    AND `status` = 'paid' AND NOT (%s)
            ]]):format(expiryCondition), { invoice, player.charId, requestedUnit })
            local candidateUnit = candidate and unitConfig(candidate.unit)
            if candidateUnit
                and #(GetEntityCoords(GetPlayerPed(source)) - vec3(candidateUnit.invoiceNpc.x,
                    candidateUnit.invoiceNpc.y, candidateUnit.invoiceNpc.z)) <= 6.0 then
                found, row, unit = slot, candidate, candidateUnit
                break
            end
        end
    end
    if not found then return false, 'Nenhuma nota fiscal valida foi encontrada.' end

    local claimed = MySQL.update.await(([[
        UPDATE `nv_dealership_orders` SET `status` = 'collecting'
        WHERE `invoice` = ? AND `seller` = ? AND `status` = 'paid' AND NOT (%s)
    ]]):format(expiryCondition), { row.invoice, player.charId })
    if claimed ~= 1 then
        if refundExpiredOrder(row) then
            removeInvoiceItems(source, row.invoice, found.slot)
            return false, 'O prazo desta nota fiscal expirou.'
        end
        return false, 'Esta nota fiscal nao e mais valida.'
    end
    if not removeInvoiceItems(source, row.invoice, found.slot) then
        MySQL.update.await("UPDATE `nv_dealership_orders` SET `status` = 'paid' WHERE `invoice` = ? AND `status` = 'collecting'", { row.invoice })
        return false, 'Nao foi possivel recolher a nota fiscal.'
    end

    local items = json.decode(row.items) or {}
    local total = 0
    for i = 1, #items do total = total + items[i].quantity end
    local previous = deliveries[source]
    local job = { invoice = row.invoice, unit = row.unit, items = items, totalUnits = total,
        truck = previous and previous.invoice == row.invoice and previous.truck or nil }
    deliveries[source] = job

    local trailer = tonumber(CreateVehicle(Config.TrailerModel, unit.trailerSpawn.x, unit.trailerSpawn.y, unit.trailerSpawn.z, unit.trailerSpawn.w, true, true)) or 0
    local deadline = GetGameTimer() + 5000
    while trailer ~= 0 and not DoesEntityExist(trailer) and GetGameTimer() < deadline do Wait(50) end
    if trailer == 0 or not DoesEntityExist(trailer) then
        MySQL.update.await("UPDATE `nv_dealership_orders` SET `status` = 'paid' WHERE `invoice` = ? AND `status` = 'collecting'", { row.invoice })
        exports.ox_inventory:AddItem(source, 'dealership_invoice', 1, { invoice = row.invoice, label = row.invoice })
        deliveries[source] = previous
        return false, 'Nao foi possivel criar o trailer. Tente novamente.'
    end
    job.trailer = trailer
    job.unloaded = 0
    return true, nil, { trailerNet = NetworkGetNetworkIdFromEntity(trailer), unload = unit.unload, units = job.totalUnits }
end)

lib.callback.register('nv_dealership:unloadOne', function(source, trailerNet)
    local job = deliveries[source]
    if not job or not job.trailer or NetworkGetNetworkIdFromEntity(job.trailer) ~= tonumber(trailerNet) then return false end
    local unit = unitConfig(job.unit)
    if #(GetEntityCoords(job.trailer) - unit.unload) > 12.0 then return false end
    if job.unloaded >= job.totalUnits then return false end
    job.unloaded = job.unloaded + 1
    return true
end)

lib.callback.register('nv_dealership:completeDelivery', function(source, trailerNet)
    local job = deliveries[source]
    if not job or not job.trailer or NetworkGetNetworkIdFromEntity(job.trailer) ~= tonumber(trailerNet) then return false end
    local unit = unitConfig(job.unit)
    if #(GetEntityCoords(job.trailer) - unit.unload) > 12.0 then return false, 'Leve o trailer ate o ponto de descarga.' end
    if job.unloaded ~= job.totalUnits then return false, 'Ainda ha veiculos no trailer.' end
    local claimed = MySQL.update.await([[
        UPDATE `nv_dealership_orders` SET `status` = 'delivering'
        WHERE `invoice` = ? AND `status` = 'collecting'
    ]], { job.invoice })
    if claimed ~= 1 then return false, 'Esta entrega ja foi concluida ou cancelada.' end
    for i = 1, #job.items do
        local item = job.items[i]
        MySQL.prepare.await([[
            INSERT INTO `nv_dealership_stock` (`unit`,`model`,`quantity`) VALUES (?,?,?)
            ON DUPLICATE KEY UPDATE `quantity` = `quantity` + VALUES(`quantity`)
        ]], { job.unit, item.model, item.quantity })
    end
    MySQL.update.await("UPDATE `nv_dealership_orders` SET `status` = 'delivered' WHERE `invoice` = ? AND `status` = 'delivering'", { job.invoice })
    if DoesEntityExist(job.trailer) then DeleteEntity(job.trailer) end
    if job.truck and DoesEntityExist(job.truck) then DeleteEntity(job.truck) end
    deliveries[source] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    local test = testDrives[source]
    if test and test.plate then exports.nv_garage:RemoveKey(source, test.plate) end
    testDrives[source] = nil
    local job = deliveries[source]
    if not job then return end
    deleteDeliveryEntities(job)
    deliveries[source] = nil
end)
