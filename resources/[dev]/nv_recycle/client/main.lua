local activeScavenging = false
local searchedBins = {}

-- Helper to wait while checking if player presses X (Control 73) to cancel
local function waitWithCancel(ms)
    local start = GetGameTimer()
    while GetGameTimer() - start < ms do
        if IsControlJustPressed(0, 73) then
            return true
        end
        Wait(0)
    end
    return false
end

-- Stop animation and clean up controls
local function stopScavenging(ped)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    lib.hideTextUI()
    activeScavenging = false
end

-- Rummaging function triggered by ox_target
local function startScavenging(entity)
    if activeScavenging then return end

    local ped = cache.ped
    local coords = GetEntityCoords(entity)
    -- Unique string key based on coords (survives streaming entity ID refresh)
    local binKey = string.format("%.1f_%.1f_%.1f", coords.x, coords.y, coords.z)

    -- Check Cooldown
    local curTime = GetGameTimer()
    if searchedBins[binKey] and curTime < searchedBins[binKey] then
        lib.notify({
            type = 'error',
            title = 'Lixeira Vazia',
            description = 'Esta lixeira já foi revirada recentemente. Tente outra.'
        })
        return
    end

    activeScavenging = true
    FreezeEntityPosition(ped, true)

    -- Pick a random number of rounds between 3 and 5
    local totalRounds = math.random(3, 5)
    local completedAll = true
    local totalHits = 0

    -- Disable movement keys and allow canceling with X key (Control 73)
    CreateThread(function()
        while activeScavenging do
            DisableControlAction(0, 21, true) -- Sprint
            DisableControlAction(0, 22, true) -- Jump
            DisableControlAction(0, 30, true) -- Move Left/Right
            DisableControlAction(0, 31, true) -- Move Up/Down
            
            if IsControlJustPressed(0, 73) then
                lib.cancelProgressBar()
            end
            Wait(0)
        end
    end)

    -- Execute rounds
    for round = 1, totalRounds do
        if not activeScavenging then
            completedAll = false
            break
        end

        -- Play/restart the search animation looping
        lib.requestAnimDict(Config.SearchAnim.dict)
        TaskPlayAnim(ped, Config.SearchAnim.dict, Config.SearchAnim.name, 8.0, -8.0, -1, Config.SearchAnim.flag, 0, false, false, false)

        -- 1. Progress Bar: Searching (Once per round)
        -- No anim passed directly to progressBar so it doesn't clear the active search animation!
        local searchSuccess = lib.progressBar({
            duration = 1500,
            label = 'Vasculhando...',
            disable = {
                move = true,
                car = true,
                combat = true
            }
        })

        if not searchSuccess or not activeScavenging then
            lib.notify({ type = 'info', description = 'Você parou de vasculhar.' })
            completedAll = false
            activeScavenging = false
            break
        end

        -- Scale difficulty smoothly based on round (easier progression)
        local speed = 0.6 + ((round - 1) * 0.15)
        local area = math.max(10, 30 - ((round - 1) * 3.5))

        -- 2. Trigger 3 consecutive skill checks at the same level
        local keyOptions = {'w', 'a', 's', 'd'}
        local success = lib.skillCheck({
            { areaSize = area, speedMultiplier = speed },
            { areaSize = area, speedMultiplier = speed },
            { areaSize = area, speedMultiplier = speed }
        }, keyOptions)

        if not success or not activeScavenging then
            lib.notify({
                type = 'error',
                title = 'Procura Interrompida',
                description = 'Nada mais de útil foi encontrado.'
            })
            completedAll = false
            activeScavenging = false
            break
        end

        -- 3. Progress Bar: Pickup anim upon succeeding the sequence of 3 checks (overrides search anim)
        local pickupSuccess = lib.progressBar({
            duration = 1000,
            label = 'Pegando algo...',
            anim = {
                dict = 'pickup_object',
                clip = 'pickup_low',
                flag = 48
            },
            disable = {
                move = true,
                car = true,
                combat = true
            }
        })

        if not pickupSuccess or not activeScavenging then
            lib.notify({ type = 'info', description = 'Você parou de vasculhar.' })
            completedAll = false
            activeScavenging = false
            break
        end

        -- Award item for completing the round (all 3 hits succeeded)
        local isFinalRound = (round == totalRounds)
        TriggerServerEvent("nv_recycle:server:rewardItem", round, isFinalRound)
    end

    -- Cooldown is always applied to this bin coords upon finishing, failing, or canceling
    searchedBins[binKey] = GetGameTimer() + (Config.CooldownTime * 1000)
    stopScavenging(ped)
end

-- Initialize ox_target model options on start
CreateThread(function()
    local options = {
        {
            name = 'nv_recycle:scavenge',
            icon = 'fa-solid fa-dumpster',
            label = 'Vasculhar Lixeira',
            distance = 1.0,
            onSelect = function(data)
                if data.entity then
                    startScavenging(data.entity)
                end
            end
        }
    }
    
    exports.ox_target:addModel(Config.TrashModels, options)
end)

local carriedProp = nil
local activeCarryDict = nil
local activeCarryAnim = nil

local function removeCarriedProp()
    if carriedProp and DoesEntityExist(carriedProp) then
        DetachEntity(carriedProp, true, true)
        DeleteEntity(carriedProp)
        carriedProp = nil
    end
    if activeCarryDict then
        StopAnimTask(cache.ped, activeCarryDict, activeCarryAnim, 3.0)
        activeCarryDict = nil
        activeCarryAnim = nil
    end
end

local function applyCarriedProp(modelHash)
    removeCarriedProp()
    
    local ped = cache.ped
    lib.requestModel(modelHash)
    
    local coords = GetEntityCoords(ped)
    carriedProp = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    
    -- Attach to Left Hand (Bone 57005)
    AttachEntityToEntity(carriedProp, ped, GetPedBoneIndex(ped, 57005), 0.15, -0.05, -0.05, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    activeCarryDict = "missfbi4prept1"
    activeCarryAnim = "_bag_walk_garbage"
    lib.requestAnimDict(activeCarryDict)
    TaskPlayAnim(ped, activeCarryDict, activeCarryAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
end

-- Thread checking inventory for full trash bags and applying carry prop
CreateThread(function()
    while true do
        Wait(1500)
        
        local ped = cache.ped
        if IsEntityDead(ped) or IsPedInAnyVehicle(ped, true) then
            if carriedProp then
                removeCarriedProp()
            end
        else
            local items = exports.ox_inventory:GetPlayerItems()
            local foundFullBag = nil
            
            if items then
                for _, item in ipairs(items) do
                    if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.isFull then
                        foundFullBag = item
                        break
                    end
                end
            end
            
            if foundFullBag then
                local model = foundFullBag.name == 'trash_bag_black' and `prop_rub_binbag_01` or `prop_rub_binbag_03`
                if not carriedProp or GetEntityModel(carriedProp) ~= model then
                    applyCarriedProp(model)
                else
                    if not IsEntityPlayingAnim(ped, activeCarryDict, activeCarryAnim, 3) then
                        TaskPlayAnim(ped, activeCarryDict, activeCarryAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
                    end
                end
            else
                if carriedProp then
                    removeCarriedProp()
                end
            end
        end
    end
end)

-- Thread checking if player has open trunk inventory of a garbage truck and showing recycle prompt
local isRecycling = false
CreateThread(function()
    while true do
        Wait(1000)
        
        local currentInv = exports.ox_inventory:GetCurrentInventory()
        if currentInv and currentInv.type == 'trunk' and not isRecycling then
            local entity = currentInv.entity
            if DoesEntityExist(entity) then
                local model = GetEntityModel(entity)
                if model == `trash` or model == `trash2` then
                    -- Query server to check if there are full bags inside
                    local hasFullBags = lib.callback.await('nv_recycle:server:checkTrunkForBags', false, currentInv.id)
                    
                    if hasFullBags then
                        lib.showTextUI('[E] Reciclar Lixo')
                        
                        -- Keep checking while the same trunk is open
                        while exports.ox_inventory:GetCurrentInventory() == currentInv and not isRecycling do
                            if IsControlJustPressed(0, 38) then -- E key
                                lib.hideTextUI()
                                isRecycling = true
                                TriggerServerEvent('nv_recycle:server:recycleTrunk', currentInv.id, NetworkGetNetworkIdFromEntity(entity))
                                
                                -- Run 1 minute compacting progress bar
                                lib.progressBar({
                                    duration = 60000,
                                    label = 'Processando Reciclagem...',
                                    canCancel = false,
                                    disable = {}
                                })
                                isRecycling = false
                                break
                            end
                            Wait(0)
                        end
                        lib.hideTextUI()
                    end
                end
            end
        end
    end
end)
