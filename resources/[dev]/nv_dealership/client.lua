local currentUnit, currentConfig, previewVehicle, previewModel, previewInteractive
local testActive, deliveryBlip
local tabletProp
local locationBlips = {}
local vehicleColors = {
    [1] = { 17, 18, 20 }, [2] = { 232, 232, 229 },
    [3] = { 181, 31, 46 }, [4] = { 36, 78, 145 }
}

local function applyPreviewColor(colorId)
    if not previewVehicle or not DoesEntityExist(previewVehicle) then return end
    local color = vehicleColors[tonumber(colorId)] or vehicleColors[1]
    SetVehicleCustomPrimaryColour(previewVehicle, color[1], color[2], color[3])
    SetVehicleCustomSecondaryColour(previewVehicle, color[1], color[2], color[3])
end

local function refreshLocationBlips()
    for i = 1, #locationBlips do
        if DoesBlipExist(locationBlips[i]) then RemoveBlip(locationBlips[i]) end
    end
    locationBlips = {}
    local units = lib.callback.await('nv_dealership:blips', false) or {}
    for i = 1, #units do
        local point = units[i].points and units[i].points.blip
        if point then
            local blip = AddBlipForCoord(point.x, point.y, point.z)
            SetBlipSprite(blip, tonumber(point.sprite) or 326)
            SetBlipColour(blip, tonumber(point.color) or 1)
            SetBlipScale(blip, tonumber(point.scale) or 0.85)
            SetBlipDisplay(blip, 4)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(point.label or units[i].label or 'Concessionaria')
            EndTextCommandSetBlipName(blip)
            locationBlips[#locationBlips + 1] = blip
        end
    end
end

RegisterNetEvent('nv_dealership:refreshBlips', refreshLocationBlips)
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
    exports.ox_target:addLocalEntity(previewVehicle, {{
        name = 'nv_dealership_test', icon = 'fa-solid fa-gauge-high', label = 'Test-drive',
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
        previewVehicle = CreateVehicle(hash, unit.preview.x, unit.preview.y, unit.preview.z, unit.preview.w, false, false)
        previewModel = model
        SetEntityVisible(previewVehicle, true, false)
        SetEntityAlpha(previewVehicle, 255, false)
        SetVehicleOnGroundProperly(previewVehicle)
        SetEntityInvincible(previewVehicle, true)
        FreezeEntityPosition(previewVehicle, true)
        SetVehicleDoorsLocked(previewVehicle, 2)
    end

    if previewInteractive then
        exports.ox_target:removeLocalEntity(previewVehicle, 'nv_dealership_test')
    end
    previewInteractive = interactive == true
    -- A colisao desligada fazia alguns modelos aparecerem parcialmente
    -- enterrados/translucidos no showroom. A interatividade controla apenas o
    -- target do test-drive; a previa permanece totalmente visivel e solida.
    SetEntityCollision(previewVehicle, true, true)
    applyPreviewColor(colorId)
    if previewInteractive then enableTestDriveTarget(model) end
end

local function openUnit(unitId)
    local data, err = lib.callback.await('nv_dealership:data', false, unitId)
    if not data then
        return notify(err or 'A concessionaria nao esta configurada.', 'error')
    end
    currentUnit = unitId
    currentConfig = data.config
    startTablet()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = data,
        maxOrder = Config.MaxOrderUnits,
        previewActive = previewInteractive == true
    })
end

exports('open', function()
    local unitId = lib.callback.await('nv_dealership:myUnit', false)
    if unitId then return openUnit(unitId) end
    notify('Voce nao tem acesso a nenhuma concessionaria.', 'error')
end)

RegisterNUICallback('close', function(_, cb)
    -- Se o vendedor apenas selecionou um carro, a previa era temporaria e deve
    -- sumir junto com o tablet. Uma previa confirmada pelo botao permanece no
    -- showroom ate ser removida explicitamente.
    if not previewInteractive then deletePreview() end
    stopTablet()
    SetNuiFocus(false, false)
    cb(1)
end)

RegisterNUICallback('preview', function(data, cb)
    preview(data.model, true, data.color)
    cb(1)
end)

RegisterNUICallback('removePreview', function(_, cb)
    deletePreview()
    cb(1)
end)

RegisterNUICallback('selectVehicle', function(data, cb)
    preview(data.model, false, data.color)
    cb(1)
end)

RegisterNUICallback('previewColor', function(data, cb)
    applyPreviewColor(data.color)
    cb(1)
end)

RegisterNUICallback('nearby', function(_, cb)
    cb(lib.callback.await('nv_dealership:nearby', false) or {})
end)

RegisterNUICallback('sell', function(data, cb)
    local ok, err = lib.callback.await('nv_dealership:sell', false, currentUnit, data.model, data.target, data.color)
    cb({ ok = ok, error = err })
end)

local function route(coords, label)
    if deliveryBlip and DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
    deliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, 1)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(label); EndTextCommandSetBlipName(deliveryBlip)
end

local createInvoiceNpc

RegisterNUICallback('order', function(data, cb)
    local ok, err, result = lib.callback.await('nv_dealership:order', false, currentUnit, data.items)
    cb({ ok = ok, error = err, invoice = result and result.invoice })
    if ok then
        stopTablet()
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        local truck = NetToVeh(result.truckNet)
        createInvoiceNpc(currentUnit, result.destination)
        route(currentConfig.truckSpawn, 'Caminhao da concessionaria')
        CreateThread(function()
            while truck == 0 or not DoesEntityExist(truck) do truck = NetToVeh(result.truckNet); Wait(200) end
            while GetVehiclePedIsIn(cache.ped, false) ~= truck do Wait(500) end
            route(result.destination, 'Validar nota fiscal')
        end)
    end
end)

createInvoiceNpc = function(unitId, invoiceNpc)
        local model = lib.requestModel(Config.DeliveryNpcModel)
        local npc = CreatePed(4, model, invoiceNpc.x, invoiceNpc.y, invoiceNpc.z - 1.0, invoiceNpc.w, false, false)
        FreezeEntityPosition(npc, true); SetEntityInvincible(npc, true); SetBlockingOfNonTemporaryEvents(npc, true)
        exports.ox_target:addLocalEntity(npc, {{
            name = 'nv_dealership_invoice_' .. unitId, icon = 'fa-solid fa-file-invoice', label = 'Validar nota fiscal',
            onSelect = function()
                local ok, err, result = lib.callback.await('nv_dealership:validateInvoice', false, unitId)
                if not ok then return notify(err or 'Nota fiscal invalida.', 'error') end
                route(result.unload, 'Descarga da concessionaria')
                CreateThread(function()
                    local trailer
                    while not trailer do trailer = NetToVeh(result.trailerNet); Wait(100) end
                    exports.ox_target:addLocalEntity(trailer, {{
                        name = 'nv_dealership_unload', icon = 'fa-solid fa-truck-ramp-box', label = 'Descarregar',
                        onSelect = function()
                            if #(GetEntityCoords(trailer) - result.unload) > 12.0 then return notify('Leve o trailer ao ponto marcado.', 'error') end
                            for i = 1, result.units do
                                if not lib.progressBar({ duration = 1800, label = ('Descarregando veiculo %d/%d'):format(i, result.units),
                                    canCancel = false, disable = { move = true, combat = true } }) then return end
                                if not lib.callback.await('nv_dealership:unloadOne', false, result.trailerNet) then
                                    return notify('A descarga foi interrompida.', 'error')
                                end
                            end
                            local done, message = lib.callback.await('nv_dealership:completeDelivery', false, result.trailerNet)
                            if done then
                                if deliveryBlip then RemoveBlip(deliveryBlip); deliveryBlip = nil end
                                notify('Entrega concluida. Estoque atualizado.', 'success')
                            else notify(message or 'Nao foi possivel concluir.', 'error') end
                        end
                    }})
                end)
            end
        }})
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deletePreview()
    stopTablet()
    SetNuiFocus(false, false)
    for i = 1, #locationBlips do
        if DoesBlipExist(locationBlips[i]) then RemoveBlip(locationBlips[i]) end
    end
end)
