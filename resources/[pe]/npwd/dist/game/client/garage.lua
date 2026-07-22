--[[
    npwd — cliente: integração do app de Garagem com o nv_garage e controle de NUI
]]

local function handleGetVehicles(data, cb)
    local ok, vehicles = pcall(function()
        if GetResourceState('nv_garage') == 'started' then
            return lib.callback.await('nv_garage:getPlayerVehicles', false)
        end
        return {}
    end)

    if ok and type(vehicles) == 'table' then
        cb(vehicles)
    else
        cb({})
    end
end

local currentPhoneTrackBlip = nil
local phoneTrackTimerThread = 0

local function handleTrackVehicle(data, cb)
    if type(data) ~= 'table' then
        cb({ ok = false })
        return
    end

    -- Se estiver fora da garagem e possuir bloqueador de sinal ativo, impede o rastreamento
    if data.status == 'out' and data.hasBlocker then
        TriggerEvent('ox_lib:notify', { type = 'error', description = 'Sinal GPS bloqueado! O veículo possui um bloqueador ativo.' })
        cb({ ok = false, blocked = true })
        return
    end

    local x, y, z
    if type(data.coords) == 'table' and tonumber(data.coords.x) and tonumber(data.coords.y) then
        x = tonumber(data.coords.x) + 0.0
        y = tonumber(data.coords.y) + 0.0
        z = tonumber(data.coords.z or 0) + 0.0
    end

    if not x or not y then
        TriggerEvent('ox_lib:notify', { type = 'error', description = 'Não foi possível determinar a localização no GPS.' })
        cb({ ok = false })
        return
    end

    phoneTrackTimerThread = phoneTrackTimerThread + 1
    local thisThread = phoneTrackTimerThread

    if currentPhoneTrackBlip and DoesBlipExist(currentPhoneTrackBlip) then
        RemoveBlip(currentPhoneTrackBlip)
        currentPhoneTrackBlip = nil
    end

    local targetName = (data.status == 'impound' and 'Pátio de Apreensão') or (data.label and data.label ~= '' and data.label) or 'Garagem / Veículo'

    currentPhoneTrackBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(currentPhoneTrackBlip, 161) -- Blip 161
    SetBlipColour(currentPhoneTrackBlip, 47) -- Cor Laranja
    SetBlipScale(currentPhoneTrackBlip, 0.9)
    SetBlipAsShortRange(currentPhoneTrackBlip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(targetName)
    EndTextCommandSetBlipName(currentPhoneTrackBlip)

    TriggerEvent('ox_lib:notify', {
        type = 'success',
        description = ('Localização de "%s" exibida no minimapa (30s)!'):format(targetName)
    })

    -- Remove o blip automaticamente após 30 segundos
    CreateThread(function()
        Wait(30000)
        if phoneTrackTimerThread == thisThread and currentPhoneTrackBlip and DoesBlipExist(currentPhoneTrackBlip) then
            RemoveBlip(currentPhoneTrackBlip)
            currentPhoneTrackBlip = nil
        end
    end)

    cb({ ok = true })
end

RegisterNUICallback('getGarageVehicles', handleGetVehicles)
RegisterNUICallback('npwd:getGarageVehicles', handleGetVehicles)

RegisterNUICallback('trackGarageVehicle', handleTrackVehicle)
RegisterNUICallback('npwd:trackGarageVehicle', handleTrackVehicle)

-- Bloqueia a abertura do Menu de Pausa (ESC) do FiveM ao fechar a NUI do celular
local function blockPauseMenu()
    CreateThread(function()
        local timeout = GetGameTimer() + 600
        while GetGameTimer() < timeout do
            DisableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE
            DisableControlAction(0, 200, true) -- INPUT_FRONTEND_PAUSE_ALTERNATE
            DisableControlAction(0, 1, true)   -- INPUT_LOOK_LR
            DisableControlAction(0, 2, true)   -- INPUT_LOOK_UD
            Wait(0)
        end
    end)
end

RegisterNUICallback('npwd:close', function(_, cb)
    blockPauseMenu()
    cb({})
end)

RegisterNUICallback('close', function(_, cb)
    blockPauseMenu()
    cb({})
end)

-- Intercepta o pressionamento da tecla ESC durante o foco na NUI
CreateThread(function()
    while true do
        Wait(0)
        if IsNuiFocused() or (global and global.isPhoneOpen) then
            if IsDisabledControlJustPressed(0, 200) or IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 199) or IsControlJustPressed(0, 199) then
                blockPauseMenu()
            end
        end
    end
end)

-- Garantia de desbloqueio do NPWD client.js ao carregar o personagem
RegisterNetEvent('ox_core:playerLoaded', function()
    TriggerEvent('npwd:setPlayerLoaded', true)
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('npwd:setPlayerLoaded', true)
end)
