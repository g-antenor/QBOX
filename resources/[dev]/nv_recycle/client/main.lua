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
    local function getNearbyDropId(entity)
        local drops = nil
        pcall(function()
            drops = exports.ox_inventory:GetDrops()
        end)
        
        if drops then
            -- 1. Try matching by exact entity handle
            for dropId, point in pairs(drops) do
                if point.entity == entity then
                    return dropId
                end
            end
            -- 2. Fallback to matching by coordinate distance
            local entityCoords = GetEntityCoords(entity)
            for dropId, point in pairs(drops) do
                local pCoords = point.coords
                if pCoords then
                    if type(pCoords) == 'table' then
                        pCoords = vec3(pCoords.x or pCoords[1] or 0, pCoords.y or pCoords[2] or 0, pCoords.z or pCoords[3] or 0)
                    end
                    if type(pCoords) == 'vector3' then
                        local dist = #(pCoords - entityCoords)
                        if dist < 3.0 then
                            return dropId
                        end
                    end
                end
            end
        end
        return nil
    end

    local function isTrashBagModel(model)
        return model == `prop_rub_binbag_01` or model == `prop_rub_binbag_03` 
            or model == GetHashKey('prop_rub_binbag_01') or model == GetHashKey('prop_rub_binbag_03')
            or model == -375613925 or model == -1859343714
    end

    local options = {
        {
            name = 'nv_recycle:scavenge',
            icon = 'fa-solid fa-dumpster',
            label = 'Vasculhar Lixeira',
            distance = 1.0,
            canInteract = function(entity, distance, coords, name)
                local model = GetEntityModel(entity)
                local isBag = isTrashBagModel(model)
                print("Scavenge canInteract | Model:", model, "IsBag:", isBag)
                if isBag then
                    local dropId = getNearbyDropId(entity)
                    print("Scavenge canInteract | DropID:", dropId)
                    return dropId == nil
                end
                return true
            end,
            onSelect = function(data)
                if data.entity then
                    startScavenging(data.entity)
                end
            end
        }
    }
    
    exports.ox_target:addModel(Config.TrashModels, options)
    
    -- Register target option to pick up dropped trash bags
    local pickupOptions = {
        {
            name = 'nv_recycle:pickup_bag',
            icon = 'fa-solid fa-hand-holding',
            label = 'Pegar Saco de Lixo',
            distance = 1.5,
            canInteract = function(entity, distance, coords, name)
                local model = GetEntityModel(entity)
                local isBag = isTrashBagModel(model)
                print("Pickup canInteract | Model:", model, "IsBag:", isBag)
                if isBag then
                    local dropId = getNearbyDropId(entity)
                    print("Pickup canInteract | DropID:", dropId)
                    return dropId ~= nil
                end
                return false
            end,
            onSelect = function(data)
                local dropId = getNearbyDropId(data.entity)
                if dropId then
                    lib.callback('nv_recycle:server:pickupBagDrop', false, function(success)
                        if success then
                            isRecycling = true
                            lib.progressBar({
                                duration = 1200,
                                label = 'Pegando saco de lixo...',
                                useLibClip = {
                                    animDict = 'pickup_object',
                                    animName = 'putdown_low',
                                    flag = 48
                                },
                                disable = {
                                    move = true,
                                    combat = true
                                }
                            })
                            isRecycling = false
                        end
                    end, dropId)
                else
                    exports.ox_inventory:openInventory()
                end
            end
        }
    }
    exports.ox_target:addModel({ 'prop_rub_binbag_01', 'prop_rub_binbag_03' }, pickupOptions)
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

local function applyCarriedProp(modelName, modelHash)
    removeCarriedProp()
    
    local ped = cache.ped
    lib.requestModel(modelHash)
    
    local coords = GetEntityCoords(ped)
    carriedProp = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    
    local animData = nil
    if GetResourceState("nv_syncitens") == "started" then
        pcall(function()
            animData = exports.nv_syncitens:getAttachment(modelName, "Carregar reciclavel")
            if not animData then
                animData = exports.nv_syncitens:getAttachment("prop_rub_binbag_01", "Carregar reciclavel")
            end
        end)
    end
    
    if animData then
        local bone = animData.boneId or 57005
        local offset = animData.offset or { x = 0.15, y = -0.05, z = -0.05 }
        local rot = animData.rotation or { x = -90.0, y = 0.0, z = 0.0 }
        
        activeCarryDict = animData.animDict or Config.CarryAnim.dict
        activeCarryAnim = animData.animName or Config.CarryAnim.name
        
        AttachEntityToEntity(carriedProp, ped, GetPedBoneIndex(ped, bone), offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    else
        -- Fallback to default
        AttachEntityToEntity(carriedProp, ped, GetPedBoneIndex(ped, 57005), 0.15, -0.05, -0.05, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
        activeCarryDict = Config.CarryAnim.dict
        activeCarryAnim = Config.CarryAnim.name
    end
    
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
                for _, item in pairs(items) do
                    if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.isFull then
                        foundFullBag = item
                        break
                    end
                end
            end
            
            if foundFullBag then
                local modelName = foundFullBag.name == 'trash_bag_black' and 'prop_rub_binbag_01' or 'prop_rub_binbag_03'
                local modelHash = GetHashKey(modelName)
                if not carriedProp or GetEntityModel(carriedProp) ~= modelHash then
                    applyCarriedProp(modelName, modelHash)
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

-- Helper functions to check for full bags in inventory
local function hasFullBagInInventory()
    local items = exports.ox_inventory:GetPlayerItems()
    if items then
        for _, item in pairs(items) do
            if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.isFull then
                return true
            end
        end
    end
    return false
end

local function getFirstFullBagInInventory()
    local items = exports.ox_inventory:GetPlayerItems()
    if items then
        for _, item in pairs(items) do
            if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.isFull then
                return item
            end
        end
    end
    return nil
end

local isRecycling = false

-- Register target options for garbage trucks (trash & trash2) on the boot/trunk bone
CreateThread(function()
    local vehicleOptions = {
        {
            name = 'nv_recycle:throw_bag',
            icon = 'fa-solid fa-trash',
            label = 'Jogar Saco de Lixo',
            bones = { 'boot', 'trunk' },
            distance = 2.0,
            canInteract = function(entity, distance, coords, name)
                local model = GetEntityModel(entity)
                if (model == `trash` or model == `trash2`) and not isRecycling then
                    local state = Entity(entity).state.recycleState or { bagsCount = 0, status = 'idle' }
                    return state.status == 'idle' and state.bagsCount < 3 and hasFullBagInInventory()
                end
                return false
            end,
            onSelect = function(data)
                local entity = data.entity
                if DoesEntityExist(entity) then
                    local bag = getFirstFullBagInInventory()
                    if bag then
                        local vehicleNetId = NetworkGetNetworkIdFromEntity(entity)
                        lib.callback('nv_recycle:server:throwBag', false, function(success)
                            if success then
                                isRecycling = true
                                lib.progressBar({
                                    duration = 3000,
                                    label = 'Jogando saco de lixo...',
                                    useLibClip = {
                                        animDict = 'mp_safehousevagos@',
                                        animName = 'package_dropoff',
                                        flag = 49
                                    },
                                    disable = {
                                        move = true,
                                        combat = true
                                    }
                                })
                                isRecycling = false
                            end
                        end, vehicleNetId, bag.name, bag.slot)
                    end
                end
            end
        },
        {
            name = 'nv_recycle:compact_trunk',
            icon = 'fa-solid fa-compress',
            label = 'Compactar Lixo',
            bones = { 'boot', 'trunk' },
            distance = 2.0,
            canInteract = function(entity, distance, coords, name)
                local model = GetEntityModel(entity)
                if (model == `trash` or model == `trash2`) and not isRecycling then
                    local state = Entity(entity).state.recycleState or { bagsCount = 0, status = 'idle' }
                    return state.status == 'idle' and state.bagsCount >= 1
                end
                return false
            end,
            onSelect = function(data)
                local entity = data.entity
                if DoesEntityExist(entity) then
                    local vehicleNetId = NetworkGetNetworkIdFromEntity(entity)
                    lib.callback('nv_recycle:server:compactTrunk', false, function(success)
                        -- State changes are managed by the server and sync visually via state bags / events
                    end, vehicleNetId)
                end
            end
        },
        {
            name = 'nv_recycle:collect_recycle',
            icon = 'fa-solid fa-hands-holding',
            label = 'Coletar Materiais Reciclados',
            bones = { 'boot', 'trunk' },
            distance = 2.0,
            canInteract = function(entity, distance, coords, name)
                local model = GetEntityModel(entity)
                if (model == `trash` or model == `trash2`) and not isRecycling then
                    local state = Entity(entity).state.recycleState or { bagsCount = 0, status = 'idle' }
                    return state.status == 'ready_to_collect'
                end
                return false
            end,
            onSelect = function(data)
                local entity = data.entity
                if DoesEntityExist(entity) then
                    local vehicleNetId = NetworkGetNetworkIdFromEntity(entity)
                    lib.callback('nv_recycle:server:collectRecycle', false, function(success)
                        if success then
                            isRecycling = true
                            lib.progressBar({
                                duration = 3000,
                                label = 'Coletando materiais reciclados...',
                                useLibClip = {
                                    animDict = 'anim@gangops@facility@servers@bodysearch@',
                                    animName = 'player_search',
                                    flag = 49
                                },
                                disable = {
                                    move = true,
                                    combat = true
                                }
                            })
                            isRecycling = false
                        end
                    end, vehicleNetId)
                end
            end
        }
    }
    exports.ox_target:addGlobalVehicle(vehicleOptions)
end)

-- Visual Trunk Door Control Sync
RegisterNetEvent('nv_recycle:client:setTrunkDoor', function(vehicleNetId, open)
    if NetworkDoesNetworkIdExist(vehicleNetId) then
        local vehicle = NetToVeh(vehicleNetId)
        if DoesEntityExist(vehicle) then
            if open then
                SetVehicleDoorOpen(vehicle, 5, false, false)
            else
                SetVehicleDoorShut(vehicle, 5, false)
            end
        end
    end
end)

-- Command to reload/unbug the screen/UI
RegisterCommand('reloadscreen', function()
    -- 1. Force release NUI focus
    SetNuiFocus(false, false)
    
    -- 2. Force close inventory
    pcall(function()
        exports.ox_inventory:closeInventory()
    end)
    
    -- 3. Cancel active progress bars
    pcall(function()
        exports.ox_lib:cancelProgressBar()
    end)

    -- 4. Hide Text UIs and menus
    pcall(function()
        exports.ox_lib:hideTextUI()
    end)
    pcall(function()
        exports.ox_lib:hideRadial()
    end)
    
    -- 5. Force disable inputs and cursor
    SetNuiFocusKeepInput(false)
    
    -- 6. Inform user
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0 },
        multiline = true,
        args = { "Suporte", "Sua tela foi reiniciada e as interfaces foram fechadas!" }
    })
end, false)

RegisterCommand('debugdrops', function()
    local drops = nil
    pcall(function()
        drops = exports.ox_inventory:GetDrops()
    end)
    
    print("Drops count: " .. tostring(drops and table.type and table.type(drops) or (drops and "table" or "nil")))
    if drops then
        for dropId, point in pairs(drops) do
            print(string.format("Drop ID: %s | Coords: %s | Entity: %s | Model: %s", 
                tostring(dropId), 
                tostring(point.coords), 
                tostring(point.entity), 
                tostring(point.model)
            ))
        end
    else
        print("No drops returned from export!")
    end
    
    local pedCoords = GetEntityCoords(cache.ped)
    print("Player coords: " .. tostring(pedCoords))
end, false)
