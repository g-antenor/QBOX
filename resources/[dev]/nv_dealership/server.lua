local Ox = require '@ox_core.lib.init'
local deliveries = {}
local testDrives = {}
local scrapLocks = {}
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

local catalog, catalogByModel = {}, {}
local coreVehicles = exports.ox_core:GetVehicleData() or {}
for model, data in pairs(coreVehicles) do
    local class = Config.VehicleClasses[tonumber(data.class)]
    local override = Config.VehicleOverrides[model] or {}
    if class and override.enabled ~= false then
        local price = math.max(1, math.floor(tonumber(override.price) or tonumber(data.price) or 1))
        local entry = {
            model = model,
            label = override.label or data.name or model,
            brand = override.brand or data.make or '',
            category = class.key,
            categoryLabel = class.label,
            class = tonumber(data.class),
            type = data.type,
            price = price,
            cost = math.max(1, math.floor(tonumber(override.cost) or price * Config.WholesaleRate)),
            weight = tonumber(data.weight) and math.max(1, math.floor(tonumber(data.weight))) or nil
        }
        catalog[#catalog + 1], catalogByModel[model] = entry, entry
    end
end
table.sort(catalog, function(a, b)
    if a.label == b.label then return a.model < b.model end
    return a.label < b.label
end)

local categoryAliases = {
    compact = { 'compact', 'compacts' },
    sedan = { 'sedan', 'sedans' },
    suv = { 'suv', 'suvs' },
    coupe = { 'coupe', 'coupes' },
    muscle = { 'muscle', 'muscles' },
    sportsclassic = { 'sportsclassic', 'sportsclassics' },
    sports = { 'sports', 'sport', 'sports' },
    super = { 'super', 'supers' },
    motorcycle = { 'motorcycle', 'motorcycles', 'moto', 'motos' },
    offroad = { 'offroad', 'offroads' },
    industrial = { 'industrial', 'industrials' },
    utility = { 'utility', 'utilities' },
    van = { 'van', 'vans' },
    cycle = { 'cycle', 'cycles', 'bike', 'bikes' },
    boat = { 'boat', 'boats' },
    helicopter = { 'helicopter', 'helicopters' },
    plane = { 'plane', 'planes' }
}

local function categoryEnabled(categories, category)
    if type(categories) ~= 'table' then return false end
    local aliases = categoryAliases[category] or { category, category .. 's' }
    for i = 1, #aliases do
        local key = aliases[i]
        if categories[key] == true or categories[key] == 1 then
            return true
        end
    end
    return false
end

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
    if not player then return nil, 'Jogador nao encontrado.' end
    if not requested then
        local groups = player.getGroups()
        if groups then
            for set in pairs(groups) do
                if isDealershipJob(set) then requested = set; break end
            end
        end
    end
    if not isDealershipJob(requested) then return nil, 'Voce nao pertence a uma concessionaria.' end
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
    return type(model) == 'string' and catalogByModel[model]
end

local function isScrapyardVehicle(entry)
    if not entry then return false end
    if entry.class == 14 or entry.class == 15 or entry.class == 16 then return false end
    if entry.type == 'boat' or entry.type == 'heli' or entry.type == 'plane' then return false end
    return true
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
    for i = 1, #catalog do
        result[#result + 1] = { model = catalog[i].model, label = catalog[i].label,
            category = catalog[i].category, price = catalog[i].price, weight = catalog[i].weight }
    end
    return result
end)

local function handleData(source, unitId)
    local unit, unitError = unitFor(source, unitId)
    if not unit then return nil, unitError end
    local rows = MySQL.query.await('SELECT `model`, `quantity` FROM `nv_dealership_stock` WHERE `unit` = ?', { unitId }) or {}
    local stock = {}
    for i = 1, #rows do stock[rows[i].model] = rows[i].quantity end
    local vehicles = {}
    for i = 1, #catalog do
        local entry = catalog[i]
        local canOrder = categoryEnabled(unit.categories, entry.category)
        if canOrder or (stock[entry.model] or 0) > 0 then
            vehicles[#vehicles + 1] = { model = entry.model, label = entry.label, brand = entry.brand,
                category = entry.categoryLabel, price = entry.price, cost = entry.cost, weight = entry.weight,
                stock = stock[entry.model] or 0, canOrder = canOrder }
        end
    end
    local account = Ox.GetGroupAccount(unit.set)
    return { unit = unitId, label = unit.label, vehicles = vehicles, balance = account and account.balance or 0,
        config = { preview = unit.preview, truckSpawn = unit.truckSpawn } }
end

lib.callback.register('nv_mdt:dealership:data', handleData)
lib.callback.register('nv_dealership:data', handleData)

local function handleNearby(source)
    local ped, result = GetPlayerPed(source), {}
    if ped == 0 then return result end

    local selfPlayer = Ox.GetPlayer(source)
    if selfPlayer then
        local selfName = selfPlayer.get('name') or ('ID %d'):format(source)
        result[#result + 1] = { id = source, name = selfName .. ' (Voce)' }
    end

    local origin = GetEntityCoords(ped)
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= source then
            local targetPed = GetPlayerPed(id)
            if targetPed ~= 0 and #(origin - GetEntityCoords(targetPed)) <= 5.0 then
                local player = Ox.GetPlayer(id)
                if player then
                    result[#result + 1] = { id = id, name = player.get('name') or ('ID %d'):format(id) }
                end
            end
        end
    end
    return result
end

lib.callback.register('nv_mdt:dealership:nearby', handleNearby)
lib.callback.register('nv_dealership:nearby', handleNearby)

lib.callback.register('nv_dealership:scrapVehicle', function(source, netId)
    local config = Config.Scrapyard
    if not config or config.enabled ~= true or type(netId) ~= 'number' then
        return false, 'Ferro-velho indisponivel.'
    end

    local player = Ox.GetPlayer(source)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not player or entity == 0 or not DoesEntityExist(entity) then
        return false, 'Veiculo nao encontrado.'
    end
    local scrapyardCoords = vec3(config.coords.x, config.coords.y, config.coords.z)
    if #(GetEntityCoords(GetPlayerPed(source)) - scrapyardCoords) > 5.0 then
        return false, 'Fale com o responsavel pelo patio para vender.'
    end
    if #(GetEntityCoords(entity) - scrapyardCoords) > (tonumber(config.vehicleRadius) or 6.0) then
        return false, 'Leve o veiculo ate o ponto do ferro-velho.'
    end

    local entry
    for i = 1, #catalog do
        if joaat(catalog[i].model) == GetEntityModel(entity) then entry = catalog[i]; break end
    end
    local weight = entry and entry.weight
    if not entry or type(weight) ~= 'number' or weight <= 0 then
        return false, 'Este veiculo nao consta na lista de carros.'
    end
    if not isScrapyardVehicle(entry) then
        return false, 'Barcos e aeronaves nao sao aceitos.'
    end

    local vehicle = Ox.GetVehicleFromNetId(netId)
    if not vehicle or vehicle.owner ~= player.charId or vehicle.group then
        return false, 'Voce nao possui as documentacoes deste veiculo.'
    end
    if scrapLocks[vehicle.vin] then return false, 'Este veiculo ja esta sendo processado.' end
    scrapLocks[vehicle.vin] = true

    local value = math.floor(weight * math.max(0, tonumber(config.pricePerKg) or 0))
    if value < 1 then
        scrapLocks[vehicle.vin] = nil
        return false, 'Valor do ferro-velho invalido.'
    end
    local account = Ox.GetCharacterAccount(player.charId)
    if not account then
        scrapLocks[vehicle.vin] = nil
        return false, 'Conta do proprietario indisponivel.'
    end

    local credited, credit = pcall(function()
        return account.addBalance({ amount = value, message = ('Ferro-velho: %s (%s kg)'):format(entry.model, weight) })
    end)
    if not credited or type(credit) ~= 'table' or credit.success ~= true then
        scrapLocks[vehicle.vin] = nil
        return false, 'Nao foi possivel realizar o pagamento.'
    end

    local plate = vehicle.plate
    local deleted = pcall(function() vehicle.delete() end)
    if not deleted then
        account.removeBalance({ amount = value, message = 'Estorno: falha no ferro-velho' })
        scrapLocks[vehicle.vin] = nil
        return false, 'Nao foi possivel destruir o veiculo.'
    end

    if plate then exports.nv_garage:RemoveKey(source, plate) end
    scrapLocks[vehicle.vin] = nil
    return true, nil, value
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

local pendingSales = {}

local function handleCreateSaleProposal(source, unitId, model, targetId, colorId)
    local duty = Player(source).state.duty
    if not duty then
        return false, 'Voce precisa estar em servico para emitir Notas Fiscais.'
    end
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

    local rows = MySQL.query.await([[
        SELECT `quantity` FROM `nv_dealership_stock` WHERE `unit` = ? AND `model` = ?
    ]], { unitId, model })
    if not rows or #rows == 0 or (rows[1].quantity or 0) < 1 then
        return false, 'Veiculo sem estoque.'
    end

    local buyerCash = exports.ox_inventory:GetItemCount(target.source, 'money') or 0
    if buyerCash < entry.price then
        return false, ('O comprador nao possui $%s em dinheiro no inventario.'):format(entry.price)
    end

    local sellerPlayer = Ox.GetPlayer(source)
    local sellerName = sellerPlayer and sellerPlayer.get('name') or ('ID %d'):format(source)
    local nfNumber = ('NF-%06d'):format(math.random(100000, 999999))

    local proposal = {
        sellerSource = source,
        sellerName = sellerName,
        targetSource = target.source,
        buyerCharId = target.charId,
        buyerName = target.get('name') or ('ID %d'):format(target.source),
        unitId = unitId,
        unitLabel = unit.label,
        model = model,
        label = entry.label,
        price = entry.price,
        colorId = tonumber(colorId) or 1,
        color = color,
        nfNumber = nfNumber,
        createdAt = os.time(),
        expiresAt = os.time() + 600
    }

    pendingSales[target.source] = proposal

    local metadata = {
        description = ('NF nº %s - %s ($%s)'):format(nfNumber, entry.label, entry.price),
        nfNumber = nfNumber,
        unitId = unitId,
        unitLabel = unit.label,
        model = model,
        price = entry.price,
        label = entry.label,
        sellerSource = source,
        sellerName = sellerName,
        colorId = tonumber(colorId) or 1,
        color = color,
        createdAt = os.time(),
        expiresAt = os.time() + 600
    }

    pendingSales[target.source] = metadata

    exports.ox_inventory:AddItem(target.source, 'invoice', 1, metadata)

    TriggerClientEvent('nv_dealership:receiveSaleProposal', target.source, metadata)

    return true, nil, metadata
end

local function handleConfirmInvoicePayment(source, targetSlot)
    local slots = exports.ox_inventory:Search(source, 'slots', 'invoice') or {}
    local item = nil

    if targetSlot and type(slots) == 'table' then
        for _, s in pairs(slots) do
            if s and s.slot == targetSlot then
                item = s
                break
            end
        end
    end

    if not item and type(slots) == 'table' then
        for _, s in pairs(slots) do
            if s and (s.metadata or s.info) then
                local m = s.metadata or s.info
                if m.nfNumber or m.model then
                    item = s
                    break
                end
            end
        end
    end

    local meta = (item and (item.metadata or item.info)) or pendingSales[source]
    if not meta or not meta.model then
        return false, 'Nenhuma Nota Fiscal valida encontrada no seu inventario.'
    end

    if meta.expiresAt and os.time() > meta.expiresAt then
        if item then
            exports.ox_inventory:RemoveItem(source, 'invoice', 1, nil, item.slot)
        end
        pendingSales[source] = nil
        TriggerClientEvent('nv_dealership:refreshBlips', source)
        return false, 'Esta Nota Fiscal expirou (validade de 10 minutos ultrapassada).'
    end

    local unit = unitConfig(meta.unitId)
    if not unit then return false, 'Concessionaria invalida.' end

    local cashCount = exports.ox_inventory:GetItemCount(source, 'money') or 0
    if cashCount < meta.price then
        return false, ('Saldo insuficiente em dinheiro no inventario (necessario $%s).'):format(meta.price)
    end

    local rows = MySQL.query.await([[
        SELECT `quantity` FROM `nv_dealership_stock` WHERE `unit` = ? AND `model` = ? AND `quantity` > 0
    ]], { meta.unitId, meta.model })
    if not rows or #rows == 0 or (rows[1].quantity or 0) < 1 then
        return false, 'Este veiculo nao possui mais unidades em estoque na concessionaria.'
    end

    local changed = MySQL.update.await([[
        UPDATE `nv_dealership_stock` SET `quantity` = `quantity` - 1
        WHERE `unit` = ? AND `model` = ? AND `quantity` > 0
    ]], { meta.unitId, meta.model })
    if changed ~= 1 then
        return false, 'Este veiculo acabou no estoque no momento do pagamento.'
    end

    local removedCash = exports.ox_inventory:RemoveItem(source, 'money', meta.price)
    if not removedCash then
        MySQL.update.await('UPDATE `nv_dealership_stock` SET `quantity` = `quantity` + 1 WHERE `unit` = ? AND `model` = ?', { meta.unitId, meta.model })
        return false, 'Nao foi possivel remover o dinheiro do seu inventario.'
    end

    local groupAccount = Ox.GetGroupAccount(unit.set)
    if groupAccount then
        pcall(function()
            groupAccount.addBalance({ amount = meta.price, message = ('Venda NF %s: %s'):format(meta.nfNumber or '', meta.label) })
        end)
    end

    if item and item.slot then
        exports.ox_inventory:RemoveItem(source, 'invoice', 1, nil, item.slot)
    else
        exports.ox_inventory:RemoveItem(source, 'invoice', 1)
    end

    local player = Ox.GetPlayer(source)
    local buyerCharId = meta.buyerCharId or (player and player.charId)
    local color = vehicleColors[tonumber(meta.colorId)] or vehicleColors[1]

    local spawnCoords = vec3(unit.saleSpawn.x, unit.saleSpawn.y, unit.saleSpawn.z)
    local spawnHeading = unit.saleSpawn.w or 0.0

    local vehicle
    local ok = pcall(function()
        vehicle = Ox.CreateVehicle({
            model = meta.model,
            owner = buyerCharId,
            properties = { color1 = color, color2 = color }
        }, spawnCoords, spawnHeading)
    end)

    if not ok or not vehicle then
        MySQL.update.await('UPDATE `nv_dealership_stock` SET `quantity` = `quantity` + 1 WHERE `unit` = ? AND `model` = ?', { meta.unitId, meta.model })
        exports.ox_inventory:AddItem(source, 'money', meta.price)
        if groupAccount then
            pcall(function()
                groupAccount.removeBalance({ amount = meta.price, message = 'Estorno de veiculo nao criado' })
            end)
        end
        return false, 'Nao foi possivel criar e posicionar o veiculo no local de entrega.'
    end

    exports.nv_garage:GiveKey(source, vehicle.plate, meta.label)

    if meta.sellerSource and GetPlayerPed(meta.sellerSource) ~= 0 and meta.sellerSource ~= source then
        TriggerClientEvent('ox_lib:notify', meta.sellerSource, {
            title = 'Concessionaria',
            description = ('Pagamento efetuado! O veiculo %s (%s) foi entregue ao comprador.'):format(meta.label, vehicle.plate),
            type = 'success'
        })
    end

    pendingSales[source] = nil
    TriggerClientEvent('nv_dealership:refreshBlips', source)

    return true, nil, { label = meta.label, plate = vehicle.plate }
end

local function handleCancelInvoicePayment(source, targetSlot)
    if targetSlot then
        exports.ox_inventory:RemoveItem(source, 'invoice', 1, nil, targetSlot)
    else
        local slots = exports.ox_inventory:Search(source, 'slots', 'invoice') or {}
        if #slots > 0 and slots[1] then
            exports.ox_inventory:RemoveItem(source, 'invoice', 1, nil, slots[1].slot)
        end
    end
    pendingSales[source] = nil
    TriggerClientEvent('nv_dealership:refreshBlips', source)
    return true
end

lib.callback.register('nv_mdt:dealership:sell', handleCreateSaleProposal)
lib.callback.register('nv_dealership:sell', handleCreateSaleProposal)
lib.callback.register('nv_dealership:createSaleProposal', handleCreateSaleProposal)
lib.callback.register('nv_mdt:dealership:confirmPayment', handleConfirmInvoicePayment)
lib.callback.register('nv_mdt:dealership:confirmInvoicePayment', handleConfirmInvoicePayment)
lib.callback.register('nv_dealership:confirmPayment', handleConfirmInvoicePayment)
lib.callback.register('nv_dealership:confirmInvoicePayment', handleConfirmInvoicePayment)
lib.callback.register('nv_mdt:dealership:cancelPayment', handleCancelInvoicePayment)
lib.callback.register('nv_mdt:dealership:cancelInvoicePayment', handleCancelInvoicePayment)
lib.callback.register('nv_dealership:cancelPayment', handleCancelInvoicePayment)
lib.callback.register('nv_dealership:cancelInvoicePayment', handleCancelInvoicePayment)

local function handleOrder(source, unitId, requested)
    local duty = Player(source).state.duty
    if not duty then
        return false, 'Voce precisa estar em servico para fazer pedidos de estoque.'
    end
    local unit, player = unitFor(source, unitId)
    if not unit or type(requested) ~= 'table' then return false, 'Pedido invalido.' end
    if deliveries[source] then
        return false, 'Voce ja possui um pedido de entrega em andamento. Conclua o pedido atual antes de fazer outro.'
    end
    for src, job in pairs(deliveries) do
        if job and job.unit == unitId then
            return false, 'Esta concessionaria ja possui um pedido de entrega em andamento. Conclua-o antes de fazer outro.'
        end
    end
    if not insideOperationalArea(source, unit) then return false, 'Va ate a area da concessionaria para fazer o pedido.' end
    local clean, units, total = {}, 0, 0
    for model, quantity in pairs(requested) do
        local entry, count = catalogEntry(model), math.floor(tonumber(quantity) or 0)
        if entry and categoryEnabled(unit.categories, entry.category) and count > 0 then
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
    local payload = {
        invoice = invoice,
        truckNet = NetworkGetNetworkIdFromEntity(truck),
        destination = unit.invoiceNpc,
        unitId = unitId,
        truckSpawn = unit.truckSpawn
    }
    TriggerClientEvent('nv_dealership:startDeliveryMission', source, payload)
    return true, nil, payload
end

lib.callback.register('nv_mdt:dealership:order', handleOrder)
lib.callback.register('nv_dealership:order', handleOrder)

lib.callback.register('nv_dealership:validateInvoice', function(source, requestedUnit)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'Jogador nao encontrado.' end

    local job = deliveries[source]
    if not job or not job.invoice then
        return false, 'Voce nao possui nenhum pedido de entrega ativo.'
    end

    if job.trailer and DoesEntityExist(job.trailer) then
        return false, 'O trailer desta entrega ja foi retirado.'
    end

    local slots = exports.ox_inventory:Search(source, 'slots', 'dealership_invoice') or {}
    local invoiceSlot = nil
    for _, slot in pairs(slots) do
        if slot and slot.metadata and slot.metadata.invoice == job.invoice then
            invoiceSlot = slot
            break
        end
    end

    if not invoiceSlot then
        return false, 'Nota fiscal incorreta ou ausente no inventario.'
    end

    local unit = unitConfig(job.unit)
    if not unit then return false, 'Concessionaria nao encontrada.' end

    if #(GetEntityCoords(GetPlayerPed(source)) - vec3(unit.invoiceNpc.x, unit.invoiceNpc.y, unit.invoiceNpc.z)) > 12.0 then
        return false, 'Aproxime-se do local de retirada para validar a Nota Fiscal.'
    end

    local claimed = MySQL.update.await([[
        UPDATE `nv_dealership_orders` SET `status` = 'collecting'
        WHERE `invoice` = ? AND `seller` = ? AND `status` = 'paid'
    ]], { job.invoice, player.charId })

    if claimed ~= 1 then
        return false, 'Nota fiscal invalida ou ja processada.'
    end

    if not removeInvoiceItems(source, job.invoice, invoiceSlot.slot) then
        MySQL.update.await("UPDATE `nv_dealership_orders` SET `status` = 'paid' WHERE `invoice` = ?", { job.invoice })
        return false, 'Nao foi possivel recolher a nota fiscal.'
    end

    local trailer = tonumber(CreateVehicle(Config.TrailerModel, unit.trailerSpawn.x, unit.trailerSpawn.y, unit.trailerSpawn.z, unit.trailerSpawn.w, true, true)) or 0
    local deadline = GetGameTimer() + 5000
    while trailer ~= 0 and not DoesEntityExist(trailer) and GetGameTimer() < deadline do Wait(50) end
    if trailer == 0 or not DoesEntityExist(trailer) then
        MySQL.update.await("UPDATE `nv_dealership_orders` SET `status` = 'paid' WHERE `invoice` = ?", { job.invoice })
        exports.ox_inventory:AddItem(source, 'dealership_invoice', 1, { invoice = job.invoice, label = job.invoice })
        return false, 'Nao foi possivel criar o trailer. Tente novamente.'
    end

    job.trailer = trailer
    job.unloaded = 0

    return true, nil, {
        trailerNet = NetworkGetNetworkIdFromEntity(trailer),
        trailerSpawn = unit.trailerSpawn,
        truckNet = job.truck and DoesEntityExist(job.truck) and NetworkGetNetworkIdFromEntity(job.truck) or nil,
        unload = unit.unload,
        units = job.totalUnits
    }
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

lib.callback.register('nv_mdt:dealership:preview', function(source, data)
    if type(data) ~= 'table' or not data.model or not data.set then return false end
    TriggerClientEvent('nv_dealership:clientPreview', source, data.set, data.model)
    return true
end)

lib.callback.register('nv_mdt:dealership:previewFromPed', function(source, data)
    if type(data) ~= 'table' or not data.model or not data.set then return false end
    TriggerClientEvent('nv_dealership:clientPreviewFromPed', source, data.set, data.model)
    return true
end)

lib.callback.register('nv_dealership:getUnitConfig', function(source, set)
    local unit = unitConfig(set)
    return unit
end)

