local currentUnit, currentConfig, previewVehicle, previewModel, previewInteractive
local testActive, deliveryBlip
local tabletProp
local locationBlips = {}
local scrapyardNpc, scrapyardBlip
local vehicleColors = {
    [1] = { 17, 18, 20 }, [2] = { 232, 232, 229 },
    [3] = { 181, 31, 46 }, [4] = { 36, 78, 145 }
}
local scrapVehicles = {}
for model, data in pairs(exports.ox_core:GetVehicleData() or {}) do
    local override = Config.VehicleOverrides[model] or {}
    local vehicleClass = tonumber(data.class)
    local accepted = vehicleClass ~= 14 and vehicleClass ~= 15 and vehicleClass ~= 16
        and data.type ~= 'boat' and data.type ~= 'heli' and data.type ~= 'plane'
    if Config.VehicleClasses[vehicleClass] and accepted and override.enabled ~= false and tonumber(data.weight) then
        scrapVehicles[joaat(model)] = {
            model = model,
            weight = math.max(1, math.floor(tonumber(data.weight)))
        }
    end
end

local function applyPreviewColor(colorId)
    if not previewVehicle or not DoesEntityExist(previewVehicle) then return end
    local color = vehicleColors[tonumber(colorId)] or vehicleColors[1]
    SetVehicleCustomPrimaryColour(previewVehicle, color[1], color[2], color[3])
    SetVehicleCustomSecondaryColour(previewVehicle, color[1], color[2], color[3])
end

local function getFirstInvoiceFromInventory()
    local slots = exports.ox_inventory:Search('slots', 'invoice') or {}
    if type(slots) == 'table' then
        for _, item in pairs(slots) do
            if item then
                local meta = item.metadata or item.info or {}
                if meta and (meta.nfNumber or meta.model or meta.price or meta.label) then
                    local data = {}
                    for k, v in pairs(meta) do data[k] = v end
                    data.slot = item.slot
                    return data
                end
            end
        end
    end

    if currentPendingSale then
        return currentPendingSale
    end

    return nil
end

local function openBuyerInvoiceModal(sale)
    if not sale then
        return lib.notify({
            title = 'Concessionaria',
            description = 'Nenhuma Nota Fiscal valida encontrada no inventario.',
            type = 'error'
        })
    end
    TriggerEvent('nv_mdt:openInvoiceModal', sale)
end

RegisterNetEvent('nv_dealership:receiveSaleProposal', function(proposal)
    currentPendingSale = proposal
    refreshLocationBlips()
    lib.notify({
        title = 'Nota Fiscal Emitida',
        description = ('Voce recebeu a Nota Fiscal do veiculo %s ($%s). Va ate o Caixa para realizar o pagamento.'):format(proposal.label, proposal.price),
        type = 'inform',
        duration = 10000
    })
end)

RegisterNetEvent('nv_dealership:clearSaleProposal', function()
    currentPendingSale = nil
    refreshLocationBlips()
end)

local paymentZones = {}

local function refreshPaymentTargets(units)
    for set, zoneId in pairs(paymentZones) do
        exports.ox_target:removeZone(zoneId)
    end
    paymentZones = {}

    local firstInvoice = getFirstInvoiceFromInventory()

    for i = 1, #units do
        local u = units[i]
        local payment = u.points and u.points.payment
        if payment and payment.x then
            local coords = vec3(payment.x, payment.y, payment.z)
            local options = {}

            if firstInvoice and (firstInvoice.unitId == u.set or not firstInvoice.unitId) then
                options[#options + 1] = {
                    name = 'nv_dealership_pay_invoice_' .. u.set,
                    icon = 'fa-solid fa-file-invoice-dollar',
                    label = 'Pagar NF',
                    distance = 3.5,
                    onSelect = function()
                        local currentInvoice = getFirstInvoiceFromInventory()
                        if currentInvoice then
                            openBuyerInvoiceModal(currentInvoice)
                        else
                            lib.notify({
                                title = 'Concessionaria',
                                description = 'Nenhuma Nota Fiscal valida encontrada no inventario.',
                                type = 'error'
                            })
                        end
                    end
                }
            end

            if #options > 0 then
                local zoneId = exports.ox_target:addBoxZone({
                    coords = coords,
                    size = vec3(1.5, 1.5, 2.0),
                    rotation = payment.w or 0.0,
                    debug = false,
                    options = options
                })
                paymentZones[u.set] = zoneId
            end
        end
    end
end

local function refreshLocationBlips()
    for i = 1, #locationBlips do
        if DoesBlipExist(locationBlips[i]) then RemoveBlip(locationBlips[i]) end
    end
    locationBlips = {}

    local units = lib.callback.await('nv_dealership:blips', false) or {}

    for i = 1, #units do
        local u = units[i]
        local point = u.points and u.points.blip
        if point then
            local blip = AddBlipForCoord(point.x, point.y, point.z)
            SetBlipSprite(blip, tonumber(point.sprite) or 326)
            SetBlipColour(blip, tonumber(point.color) or 1)
            SetBlipScale(blip, tonumber(point.scale) or 0.85)
            SetBlipDisplay(blip, 4)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(point.label or u.label or 'Concessionaria')
            EndTextCommandSetBlipName(blip)
            locationBlips[#locationBlips + 1] = blip
        end
    end
    refreshPaymentTargets(units)
end

RegisterNetEvent('nv_dealership:refreshBlips', refreshLocationBlips)
RegisterNetEvent('ox_inventory:updateInventory', refreshLocationBlips)
CreateThread(function()
    Wait(1000)
    refreshLocationBlips()
end)

local function stopTablet()
    if tabletProp and DoesEntityExist(tabletProp) then DeleteEntity(tabletProp) end
    tabletProp = nil
    StopAnimTask(cache.ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
end

local function startTablet()
    stopTablet()
    local dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
    lib.requestAnimDict(dict)
    local model = lib.requestModel('prop_cs_tablet')
    tabletProp = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    AttachEntityToEntity(tabletProp, cache.ped, GetPedBoneIndex(cache.ped, 60309),
        0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(cache.ped, dict, 'base', 3.0, 3.0, -1, 49, 0.0, false, false, false)
end

local function notify(message, kind)
    lib.notify({ title = 'Concessionaria', description = message, type = kind or 'inform' })
end

local function sellToScrapyard()
    local config = Config.Scrapyard
    local coords = vec3(config.coords.x, config.coords.y, config.coords.z)
    local vehicle = lib.getClosestVehicle(coords, tonumber(config.vehicleRadius) or 6.0, false)
    if not vehicle or vehicle == 0 then
        return notify('Estacione o veiculo perto do responsavel pelo patio.', 'error')
    end

    local vehicleData = scrapVehicles[GetEntityModel(vehicle)]
    if not vehicleData then
        return notify('Este veiculo nao consta na lista de carros ou nao e aceito.', 'error')
    end
    local weight = vehicleData.weight

    local value = math.floor(weight * (tonumber(config.pricePerKg) or 0))
    local answer = lib.alertDialog({
        header = 'Vender ao ferro-velho',
        content = ('O veiculo pesa **%s kg** e sera destruido permanentemente.\n\nValor: **$%s**'):format(
            weight, value),
        centered = true,
        cancel = true,
        labels = { confirm = 'Vender veiculo', cancel = 'Cancelar' }
    })
    if answer ~= 'confirm' then return end

    local ok, err, paid = lib.callback.await('nv_dealership:scrapVehicle', false, VehToNet(vehicle))
    if ok then
        notify(('Veiculo vendido ao ferro-velho por $%s.'):format(paid), 'success')
    else
        notify(err or 'Nao foi possivel vender o veiculo.', 'error')
    end
end

CreateThread(function()
    local config = Config.Scrapyard
    if not config or config.enabled ~= true then return end

    local model = lib.requestModel(config.npcModel or 's_m_y_xmech_02')
    scrapyardNpc = CreatePed(4, model, config.coords.x, config.coords.y, config.coords.z - 1.0,
        config.coords.w or 0.0, false, false)
    SetEntityAsMissionEntity(scrapyardNpc, true, true)
    FreezeEntityPosition(scrapyardNpc, true)
    SetEntityInvincible(scrapyardNpc, true)
    SetBlockingOfNonTemporaryEvents(scrapyardNpc, true)
    exports.ox_target:addLocalEntity(scrapyardNpc, {{
        name = 'nv_dealership_scrapyard',
        icon = 'fa-solid fa-scale-balanced',
        label = 'Vender veiculo por peso',
        distance = 2.0,
        onSelect = sellToScrapyard
    }})
    SetModelAsNoLongerNeeded(model)

    local blipConfig = config.blip
    if blipConfig and blipConfig.enabled then
        scrapyardBlip = AddBlipForCoord(config.coords.x, config.coords.y, config.coords.z)
        SetBlipSprite(scrapyardBlip, tonumber(blipConfig.sprite) or 318)
        SetBlipColour(scrapyardBlip, tonumber(blipConfig.color) or 1)
        SetBlipScale(scrapyardBlip, tonumber(blipConfig.scale) or 0.75)
        SetBlipAsShortRange(scrapyardBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(blipConfig.label or 'Ferro-velho')
        EndTextCommandSetBlipName(scrapyardBlip)
    end
end)

RegisterNetEvent('nv_dealership:orderExpired', function(invoice)
    if deliveryBlip then RemoveBlip(deliveryBlip); deliveryBlip = nil end
    notify(('O prazo da %s expirou. O valor foi devolvido ao caixa da concessionaria.'):format(invoice), 'error')
end)

local function deletePreview()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        if previewInteractive then
            exports.ox_target:removeLocalEntity(previewVehicle, 'nv_dealership_test')
        end
        DeleteEntity(previewVehicle)
    end
    previewVehicle, previewModel, previewInteractive = nil, nil, nil
end

local function enableTestDriveTarget(model)
    if not previewVehicle or not DoesEntityExist(previewVehicle) then return end
    pcall(function() exports.ox_target:removeLocalEntity(previewVehicle, { 'nv_dealership_test' }) end)
    exports.ox_target:addLocalEntity(previewVehicle, {{
        name = 'nv_dealership_test',
        icon = 'fa-solid fa-gauge-high',
        label = 'Test-drive',
        distance = 3.5,
        canInteract = function()
            return not testActive
        end,
        onSelect = function()
            if testActive then return end
            local back = GetEntityCoords(cache.ped)
            local heading = GetEntityHeading(cache.ped)
            local ok, err, data = lib.callback.await('nv_dealership:startTest', false, currentUnit, model)
            if not ok then return notify(err or 'Test-drive indisponivel.', 'error') end
            testActive = true
            stopTablet()
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
            local testHash = lib.requestModel(model)
            local vehicle = CreateVehicle(testHash, data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w, true, true)
            SetVehicleNumberPlateText(vehicle, ('NVTD%04d'):format(GetPlayerServerId(PlayerId()) % 10000))
            local registered, registerError = lib.callback.await(
                'nv_dealership:registerTestVehicle', false, VehToNet(vehicle))
            if not registered then
                testActive = false
                if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
                lib.callback.await('nv_dealership:endTest', false)
                SetEntityCoords(cache.ped, back.x, back.y, back.z, false, false, false, false)
                SetEntityHeading(cache.ped, heading)
                return notify(registerError or 'Nao foi possivel iniciar o test-drive.', 'error')
            end
            SetPedIntoVehicle(cache.ped, vehicle, -1)
            local deadline = GetGameTimer() + data.seconds * 1000
            CreateThread(function()
                local shownSecond
                while testActive and DoesEntityExist(vehicle) and GetGameTimer() < deadline
                    and GetVehiclePedIsIn(cache.ped, false) == vehicle do
                    local left = math.max(0, math.ceil((deadline - GetGameTimer()) / 1000))
                    if left ~= shownSecond then
                        shownSecond = left
                        lib.showTextUI(('TEST-DRIVE | Tempo restante: %02d:%02d'):format(left // 60, left % 60),
                            { position = 'top-center', icon = 'stopwatch' })
                    end
                    Wait(250)
                end
                lib.hideTextUI()
                testActive = false
                if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
                lib.callback.await('nv_dealership:endTest', false)
                SetEntityCoords(cache.ped, back.x, back.y, back.z, false, false, false, false)
                SetEntityHeading(cache.ped, heading)
            end)
        end
    }})
end

local function preview(model, interactive, colorId)
    local unit = currentConfig
    if not unit then return end

    if previewModel ~= model or not previewVehicle or not DoesEntityExist(previewVehicle) then
        deletePreview()
        local hash = lib.requestModel(model)
        previewVehicle = CreateVehicle(hash, unit.preview.x, unit.preview.y, unit.preview.z, unit.preview.w, true, false)
        previewModel = model
    end

    SetEntityVisible(previewVehicle, true, false)
    SetEntityAlpha(previewVehicle, 255, false)
    SetVehicleOnGroundProperly(previewVehicle)
    SetEntityInvincible(previewVehicle, true)
    FreezeEntityPosition(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetVehicleDoorsLockedForAllPlayers(previewVehicle, true)
    SetVehicleCanBeVisiblyDamaged(previewVehicle, false)
    SetVehicleEngineCanDegrade(previewVehicle, false)

    local vehState = Entity(previewVehicle).state
    vehState:set('isDealershipPreview', true, true)
    vehState:set('nvLocked', true, true)
    vehState:set('noLockpick', true, true)
    vehState:set('noHotwire', true, true)
    vehState:set('noBlocker', true, true)

    if previewInteractive then
        pcall(function() exports.ox_target:removeLocalEntity(previewVehicle, { 'nv_dealership_test' }) end)
    end
    previewInteractive = interactive == true
    SetEntityCollision(previewVehicle, true, true)
    applyPreviewColor(colorId)
    if previewInteractive then
        enableTestDriveTarget(model)
    end
end

RegisterNetEvent('nv_dealership:clientPreview', function(set, model)
    if not currentConfig or currentUnit ~= set then
        currentConfig = lib.callback.await('nv_dealership:getUnitConfig', false, set)
        currentUnit = set
    end
    preview(model, true, 1)
    notify('Veiculo exibido na previa do showroom.', 'success')
end)

RegisterNetEvent('nv_dealership:clientPreviewFromPed', function(set, model)
    stopTablet()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    if not currentConfig or currentUnit ~= set then
        currentConfig = lib.callback.await('nv_dealership:getUnitConfig', false, set)
        currentUnit = set
    end

    preview(model, true, 1)
    notify('Veiculo exibido na previa do showroom.', 'success')
end)

local deliveryBlip = nil
local currentTruckNet = nil

local function removeDeliveryBlip()
    if deliveryBlip and DoesBlipExist(deliveryBlip) then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
end

local function setRouteBlip(coords, label, sprite, color)
    removeDeliveryBlip()
    local x = tonumber(coords and coords.x)
    local y = tonumber(coords and coords.y)
    local z = tonumber(coords and coords.z)
    if not x or not y or not z then return end

    deliveryBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(deliveryBlip, sprite or 1)
    SetBlipDisplay(deliveryBlip, 4)
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipColour(deliveryBlip, color or 1)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, color or 1)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(deliveryBlip)

    SetNewWaypoint(x, y)
end

local function setEntityBlip(entity, label, sprite, color)
    removeDeliveryBlip()
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    deliveryBlip = AddBlipForEntity(entity)
    SetBlipSprite(deliveryBlip, sprite or 1)
    SetBlipDisplay(deliveryBlip, 4)
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipColour(deliveryBlip, color or 1)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, color or 1)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(deliveryBlip)

    local coords = GetEntityCoords(entity)
    if coords then SetNewWaypoint(coords.x, coords.y) end
end

local createInvoiceNpc

local function startDeliveryMission(data)
    if type(data) ~= 'table' or not data.destination then return end
    local unitId = data.unitId
    local destination = data.destination
    local truckSpawn = data.truckSpawn
    local truckNet = data.truckNet

    currentTruckNet = truckNet
    createInvoiceNpc(unitId, destination)

    -- Passo 1: Solicitada a compra -> Marca no minimapa a localização exata do caminhão
    if truckSpawn then
        setRouteBlip(truckSpawn, 'Caminhão da Concessionária', 67, 1)
    end

    CreateThread(function()
        -- Passo 2: Monitora quando o jogador entra no caminhão e liga o motor
        while true do
            Wait(300)
            local currentVeh = GetVehiclePedIsIn(cache.ped, false)
            local truck = truckNet and NetToVeh(truckNet) or 0

            local isMyTruck = false
            if currentVeh ~= 0 then
                if (truck ~= 0 and currentVeh == truck) or (truckNet and NetworkGetNetworkIdFromEntity(currentVeh) == truckNet) then
                    isMyTruck = true
                elseif GetEntityModel(currentVeh) == joaat(Config.TruckModel) then
                    isMyTruck = true
                end
            end

            if isMyTruck and GetIsVehicleEngineRunning(currentVeh) then
                break
            end
        end

        -- Entrou e ligou o caminhão -> Marca a localização destacada do PED no mapa com rota
        setRouteBlip(destination, 'Retirar Encomenda (Nota Fiscal)', 1, 1)
    end)
end

RegisterNetEvent('nv_dealership:startDeliveryMission', function(data)
    if data then startDeliveryMission(data) end
end)

exports('open', function()
    local unitId = lib.callback.await('nv_dealership:myUnit', false)
    if unitId then
        exports.nv_mdt:open()
    else
        notify('Voce nao tem acesso a nenhuma concessionaria.', 'error')
    end
end)

local invoiceNpcPed = nil
local invoicePoint = nil

local function removeInvoicePoint(unitId)
    if invoicePoint then
        invoicePoint:remove()
        invoicePoint = nil
    end
    if invoiceNpcPed and DoesEntityExist(invoiceNpcPed) then
        if unitId then
            exports.ox_target:removeLocalEntity(invoiceNpcPed, 'nv_dealership_invoice_' .. unitId)
        end
        DeleteEntity(invoiceNpcPed)
        invoiceNpcPed = nil
    end
end

createInvoiceNpc = function(unitId, invoiceNpc)
    if not invoiceNpc then return end
    removeInvoicePoint(unitId)

    local coords = vec3(invoiceNpc.x, invoiceNpc.y, invoiceNpc.z)
    invoicePoint = lib.points.new({
        coords = coords,
        distance = 120,
        onEnter = function()
            if invoiceNpcPed and DoesEntityExist(invoiceNpcPed) then return end
            local model = lib.requestModel(Config.DeliveryNpcModel)
            if not model then return end

            local z = invoiceNpc.z
            local foundGround, groundZ = GetGroundZFor_3dCoord(invoiceNpc.x, invoiceNpc.y, invoiceNpc.z, false)
            if foundGround and math.abs(groundZ - invoiceNpc.z) < 3.0 then
                z = groundZ
            end

            invoiceNpcPed = CreatePed(4, model, invoiceNpc.x, invoiceNpc.y, z, invoiceNpc.w or 0.0, false, false)
            PlaceObjectOnGroundProperly(invoiceNpcPed)
            FreezeEntityPosition(invoiceNpcPed, true)
            SetEntityInvincible(invoiceNpcPed, true)
            SetEntityCanBeDamaged(invoiceNpcPed, false)
            SetPedCanRagdoll(invoiceNpcPed, false)
            SetPedCanRagdollFromPlayerImpact(invoiceNpcPed, false)
            SetPedCanBeTargetted(invoiceNpcPed, false)
            SetBlockingOfNonTemporaryEvents(invoiceNpcPed, true)

            exports.ox_target:addLocalEntity(invoiceNpcPed, {{
                name = 'nv_dealership_invoice_' .. unitId,
                icon = 'fa-solid fa-file-invoice',
                label = 'Validar nota fiscal',
                onSelect = function()
                    local ok, err, result = lib.callback.await('nv_dealership:validateInvoice', false, unitId)
                    if not ok then return notify(err or 'Nota fiscal invalida.', 'error') end

                    -- Passo 3: Interagindo com o PED -> Spawna o trailer e marca no minimapa onde ele está
                    CreateThread(function()
                        if result.trailerSpawn then
                            setRouteBlip(result.trailerSpawn, 'Trailer de Veículos', 479, 1)
                        end

                        local trailer = 0
                        while trailer == 0 or not DoesEntityExist(trailer) do
                            trailer = NetToVeh(result.trailerNet)
                            Wait(100)
                        end

                        setEntityBlip(trailer, 'Trailer de Veículos', 479, 1)

                        -- Passo 4: Aguarda engatar o trailer no caminhão
                        local truckNet = result.truckNet or currentTruckNet
                        CreateThread(function()
                            while DoesEntityExist(trailer) do
                                Wait(400)
                                local currentVeh = GetVehiclePedIsIn(cache.ped, false)
                                local isAttached = false

                                if currentVeh ~= 0 then
                                    if IsVehicleAttachedToTrailer(currentVeh) then
                                        isAttached = true
                                    else
                                        local hasTrailer, trailerEnt = GetVehicleTrailerVehicle(currentVeh)
                                        if hasTrailer and trailerEnt ~= 0 then
                                            isAttached = true
                                        end
                                    end
                                end

                                if isAttached then
                                    break
                                end
                            end

                            -- Engatou o trailer -> Marca a localização do ponto de entrega na concessionária
                            if DoesEntityExist(trailer) then
                                setRouteBlip(result.unload, 'Ponto de Descarga (Concessionária)', 38, 1)
                            end
                        end)

                        -- Adicionar ox_target no trailer para descarga
                        exports.ox_target:addLocalEntity(trailer, {{
                            name = 'nv_dealership_unload',
                            icon = 'fa-solid fa-truck-ramp-box',
                            label = 'Descarregar',
                            onSelect = function()
                                if #(GetEntityCoords(trailer) - result.unload) > 12.0 then
                                    return notify('Leve o trailer ao ponto de descarga da concessionária.', 'error')
                                end

                                -- Tocar animação rpemotes-reborn (ou fallback) durante todo o descarregamento
                                local playedEmote = false
                                if GetResourceState('rpemotes-reborn') == 'started' then
                                    pcall(function()
                                        exports['rpemotes-reborn']:EmoteCommandStart('clipboard')
                                        playedEmote = true
                                    end)
                                else
                                    lib.requestAnimDict('missfam4')
                                    TaskPlayAnim(cache.ped, 'missfam4', 'base', 8.0, -8.0, -1, 49, 0, false, false, false)
                                    playedEmote = true
                                end

                                local success = true
                                for i = 1, result.units do
                                    if not lib.progressBar({
                                        duration = 1800,
                                        label = ('Descarregando veiculo %d/%d'):format(i, result.units),
                                        canCancel = false,
                                        disable = { move = true, combat = true }
                                    }) then
                                        success = false
                                        break
                                    end

                                    if not lib.callback.await('nv_dealership:unloadOne', false, result.trailerNet) then
                                        notify('A descarga foi interrompida.', 'error')
                                        success = false
                                        break
                                    end
                                end

                                local resOk, resErr, resData = lib.callback.await('nv_dealership:completeDelivery', false, result.trailerNet)

                                -- Parar animação somente após concluir todos os descarregamentos
                                if GetResourceState('rpemotes-reborn') == 'started' and playedEmote then
                                    pcall(function() exports['rpemotes-reborn']:EmoteCancel() end)
                                else
                                    ClearPedTasks(cache.ped)
                                end

                                if resOk then
                                    removeDeliveryBlip()
                                    removeInvoicePoint(unitId)

                                    -- Deletar entidades do caminhão e trailer localmente no cliente
                                    if DoesEntityExist(trailer) then DeleteVehicle(trailer) end
                                    local truck = truckNet and NetToVeh(truckNet) or 0
                                    if truck ~= 0 and DoesEntityExist(truck) then DeleteVehicle(truck) end

                                    notify('Entrega concluida. Estoque atualizado.', 'success')
                                else
                                    notify(resErr or 'Nao foi possivel concluir.', 'error')
                                end
                            end
                        }})
                    end)
                end
            }})
        end,
        onExit = function()
            if invoiceNpcPed and DoesEntityExist(invoiceNpcPed) then
                exports.ox_target:removeLocalEntity(invoiceNpcPed, 'nv_dealership_invoice_' .. unitId)
                DeleteEntity(invoiceNpcPed)
                invoiceNpcPed = nil
            end
        end
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deletePreview()
    stopTablet()
    removeDeliveryBlip()
    removeInvoicePoint()
    SetNuiFocus(false, false)
    for i = 1, #locationBlips do
        if DoesBlipExist(locationBlips[i]) then RemoveBlip(locationBlips[i]) end
    end
    for set, zoneId in pairs(paymentZones) do
        exports.ox_target:removeZone(zoneId)
    end
    paymentZones = {}
    if scrapyardNpc and DoesEntityExist(scrapyardNpc) then
        exports.ox_target:removeLocalEntity(scrapyardNpc, 'nv_dealership_scrapyard')
        DeleteEntity(scrapyardNpc)
    end
    if scrapyardBlip and DoesBlipExist(scrapyardBlip) then RemoveBlip(scrapyardBlip) end
end)
