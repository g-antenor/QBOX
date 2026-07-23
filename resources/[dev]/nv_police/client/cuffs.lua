-- ------------------------------------------------------------- Algemas (cuffs) --

local isCuffed = false
local cuffPosition = 'behind'

--- Determina se o policial está atrás do cidadão (costas) ou na frente (frente)
local function getCuffOrientation(targetPed)
    local officerPed = cache.ped
    local targetForward = GetEntityForwardVector(targetPed)
    local officerCoords = GetEntityCoords(officerPed)
    local targetCoords = GetEntityCoords(targetPed)

    local dirToOfficer = vec3(
        officerCoords.x - targetCoords.x,
        officerCoords.y - targetCoords.y,
        officerCoords.z - targetCoords.z
    )

    local dot = (targetForward.x * dirToOfficer.x) + (targetForward.y * dirToOfficer.y)
    return dot < 0 and 'behind' or 'front'
end

--- Export: uso do item algema (handcuffs)
local function useHandcuffs()
    local targetPlayer, dist = GetClosestPlayer(Config.InteractionDistance)
    if targetPlayer == -1 then
        return lib.notify({ type = 'error', description = 'Nenhum cidadão por perto para algemar.' })
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    local targetPed = GetPlayerPed(targetPlayer)

    local targetState = Player(targetServerId).state
    if targetState.isCuffed then
        return lib.notify({ type = 'error', description = 'Este cidadão já está algemado.' })
    end

    local position = getCuffOrientation(targetPed)

    lib.requestAnimDict(Config.Anims.cuffArrest.dict)
    TaskPlayAnim(cache.ped, Config.Anims.cuffArrest.dict, Config.Anims.cuffArrest.cop, 8.0, -8.0, 3000, 49, 0, false, false, false)

    if lib.progressBar({
        duration = 3000,
        label = 'Algemando cidadão...',
        disable = { move = true, car = true, combat = true }
    }) then
        local success, err = lib.callback.await('nv_police:cuffPlayer', false, targetServerId, position)
        if success then
            lib.notify({ type = 'success', description = 'Cidadão algemado com sucesso.' })
        else
            lib.notify({ type = 'error', description = err or 'Não foi possível algemar.' })
        end
    end
end

--- Export: uso do item chave de algema (handcuff_key)
local function useHandcuffKey()
    local targetPlayer, dist = GetClosestPlayer(Config.InteractionDistance)
    if targetPlayer == -1 then
        return lib.notify({ type = 'error', description = 'Nenhum cidadão por perto para desalgemar.' })
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    local targetState = Player(targetServerId).state

    if not targetState.isCuffed then
        return lib.notify({ type = 'error', description = 'Este cidadão não está algemado.' })
    end

    lib.requestAnimDict(Config.Anims.uncuff.dict)
    TaskPlayAnim(cache.ped, Config.Anims.uncuff.clip, Config.Anims.uncuff.clip, 8.0, -8.0, 2500, 49, 0, false, false, false)

    if lib.progressBar({
        duration = 2500,
        label = 'Desalgemando cidadão...',
        disable = { move = true, car = true, combat = true }
    }) then
        local success, err = lib.callback.await('nv_police:uncuffPlayer', false, targetServerId)
        if success then
            lib.notify({ type = 'success', description = 'Cidadão desalgemado com sucesso.' })
        else
            lib.notify({ type = 'error', description = err or 'Não foi possível desalgemar.' })
        end
    end
end

exports('useHandcuffs', useHandcuffs)
exports('useHandcuffKey', useHandcuffKey)

-- -------------------------------------------- Loop de restrições do algemado --

local function startCuffedThread(pos)
    cuffPosition = pos or 'behind'
    isCuffed = true

    CreateThread(function()
        local animConfig = (cuffPosition == 'front') and Config.Anims.cuffFront or Config.Anims.cuffBehind

        while isCuffed do
            Wait(0)
            local ped = cache.ped

            -- Restrição de ações do controle
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 37, true)  -- Select Weapon
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 45, true)  -- Reload
            DisableControlAction(0, 140, true) -- Melee
            DisableControlAction(0, 141, true) -- Melee
            DisableControlAction(0, 142, true) -- Melee
            DisableControlAction(0, 257, true) -- Attack
            DisableControlAction(0, 263, true) -- Melee
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 23, true)  -- Enter vehicle (driver)
            DisableControlAction(0, 75, true)  -- Exit vehicle
            DisablePlayerFiring(ped, true)

            -- Manter a animação ativa se não estiver executando
            if not IsEntityPlayingAnim(ped, animConfig.dict, animConfig.clip, 3) then
                lib.requestAnimDict(animConfig.dict)
                TaskPlayAnim(ped, animConfig.dict, animConfig.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            -- Bloquear assento do motorista se entrar em veículo
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                if GetPedInVehicleSeat(vehicle, -1) == ped then
                    TaskLeaveVehicle(ped, vehicle, 16)
                end
            end
        end

        ClearPedTasks(cache.ped)
    end)
end

-- Ouvinte de mudanças na statebag do jogador local
AddStateBagChangeHandler('isCuffed', ('player:%d'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if value then
        local pos = LocalPlayer.state.cuffPosition or 'behind'
        startCuffedThread(pos)
    else
        isCuffed = false
        ClearPedTasks(cache.ped)
    end
end)
