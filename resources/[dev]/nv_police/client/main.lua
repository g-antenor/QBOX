local isHandsUp = false
local isPointing = false

-- Helper para obter o jogador mais proximo
function GetClosestPlayer(maxDist)
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local players = GetActivePlayers()
    local closestPlayer = -1
    local closestDistance = maxDist or Config.InteractionDistance

    for i = 1, #players do
        local targetPed = GetPlayerPed(players[i])
        if targetPed ~= ped and DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(coords - targetCoords)
            if dist < closestDistance then
                closestPlayer = players[i]
                closestDistance = dist
            end
        end
    end

    return closestPlayer, closestDistance
end

-- ------------------------------------------------------------- Mãos ao alto (X) --

local function toggleHandsUp()
    if LocalPlayer.state.isCuffed then return end

    isHandsUp = not isHandsUp
    LocalPlayer.state:set('handsUp', isHandsUp, true)

    if isHandsUp then
        lib.requestAnimDict(Config.Anims.handsUp.dict)
        TaskPlayAnim(cache.ped, Config.Anims.handsUp.dict, Config.Anims.handsUp.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        ClearPedTasks(cache.ped)
    end
end

lib.addKeybind({
    name = 'nv_police_handsup',
    description = 'Levantar / abaixar as mãos',
    defaultKey = Config.Keybinds.handsUp,
    onPressed = toggleHandsUp
})

-- ------------------------------------------------------------------ Apontar (B) --

local function startPointing()
    if isPointing then return end
    isPointing = true
    LocalPlayer.state:set('isPointing', true, true)

    lib.requestAnimDict('anim@mp_point')
    SetPedConfigFlag(cache.ped, 36, true)
    TaskMoveNetworkByName(cache.ped, 'task_mp_pointing', 0.5, 0, 'task_mp_pointing', 24)
end

local function stopPointing()
    if not isPointing then return end
    isPointing = false
    LocalPlayer.state:set('isPointing', false, true)

    RequestTaskMoveNetworkStateTransition(cache.ped, 'Stop')
    SetPedConfigFlag(cache.ped, 36, false)
    ClearPedSecondaryTask(cache.ped)
end

lib.addKeybind({
    name = 'nv_police_pointing',
    description = 'Apontar com o dedo',
    defaultKey = Config.Keybinds.pointing,
    onPressed = function()
        if isPointing then
            stopPointing()
        else
            startPointing()
        end
    end
})

-- Thread para atualizar a direcao do apontar enquanto ativo
CreateThread(function()
    while true do
        if isPointing then
            local camPitch = GetGameplayCamRelativePitch()
            if camPitch < -70.0 then camPitch = -70.0 elseif camPitch > 42.0 then camPitch = 42.0 end
            camPitch = (camPitch + 70.0) / 112.0

            local camHeading = GetGameplayCamRelativeHeading()
            if camHeading < -180.0 then camHeading = -180.0 elseif camHeading > 180.0 then camHeading = 180.0 end
            camHeading = (camHeading + 180.0) / 360.0

            SetTaskMoveNetworkSignalFloat(cache.ped, 'Pitch', camPitch)
            SetTaskMoveNetworkSignalFloat(cache.ped, 'Heading', camHeading * -1.0 + 1.0)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- -------------------------------------------------- Interações via ox_target --

CreateThread(function()
    exports.ox_target:addGlobalPlayer({
        {
            name = 'nv_police_search',
            icon = 'fa-solid fa-hand-holding-hand',
            label = 'Revistar',
            distance = 1.5,
            canInteract = function(entity, distance, coords, name, bone)
                if not DoesEntityExist(entity) then return false end
                local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
                if targetPlayer == -1 then return false end
                local serverId = GetPlayerServerId(targetPlayer)
                local state = Player(serverId).state
                return state.isCuffed == true or state.handsUp == true
            end,
            onSelect = function(data)
                local targetPlayer = NetworkGetPlayerIndexFromPed(data.entity)
                if targetPlayer == -1 then return end
                local targetServerId = GetPlayerServerId(targetPlayer)

                lib.requestAnimDict(Config.Anims.search.dict)
                TaskPlayAnim(cache.ped, Config.Anims.search.dict, Config.Anims.search.clip, 8.0, -8.0, 1500, 49, 0, false, false, false)

                if lib.progressBar({
                    duration = 1500,
                    label = 'Revistando...',
                    disable = { move = true, car = true, combat = true }
                }) then
                    exports.ox_inventory:openInventory('inspect', targetServerId)
                end
            end
        }
    })
end)
