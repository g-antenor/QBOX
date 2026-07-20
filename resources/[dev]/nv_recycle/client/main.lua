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

    -- Abre a sessao no servidor ANTES de qualquer coisa. E o servidor que
    -- decide quantas rodadas existem e que guarda o cooldown da lixeira; o
    -- controle daqui e so conforto de UX.
    local totalRounds = lib.callback.await('nv_recycle:server:startScavenge', false, coords)

    if not totalRounds then
        lib.notify({
            type = 'error',
            title = 'Lixeira Vazia',
            description = 'Esta lixeira já foi revirada recentemente. Tente outra.'
        })
        return
    end

    activeScavenging = true
    FreezeEntityPosition(ped, true)

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

        -- Escalada de dificuldade por rodada: o setor encolhe e o cursor
        -- acelera. Os valores sao overrides do preset 'reciclagem' do
        -- nv_minigames — o preset define quantas rodadas e o piso; aqui so
        -- muda o que depende da rodada atual.
        --
        -- `zone` e a largura do setor em % da barra, `speed` e a velocidade do
        -- cursor em %/s (o preset 'medium' do skillbar usa 16 e 92).
        local zone = math.max(9, 22 - ((round - 1) * 2.5))
        local speed = 70 + ((round - 1) * 14)

        -- 2. Minigame de pericia (skillbar do nv_minigames)
        local success = exports.nv_minigames:Start('reciclagem', {
            zone = zone,
            speed = speed
        })

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
                dict = 'anim@heists@ornate_bank@grab_cash',
                clip = 'grab',
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

-- ==========================================================================
-- RECYCLING SELL MENU & INTERACTIONS
-- ==========================================================================
local function openSellMenu()
    lib.callback('nv_recycle:server:getSellPrices', false, function(prices)
        if not prices then return end
        
        local options = {}
        local totalEstimate = 0
        local hasAny = false
        
        for _, cfg in ipairs(Config.SellableItems or {}) do
            local count = exports.ox_inventory:Search('count', cfg.item) or 0
            local price = prices[cfg.item] or 1
            local itemTotal = count * price
            
            if count > 0 then
                hasAny = true
                totalEstimate = totalEstimate + itemTotal
                
                table.insert(options, {
                    title = cfg.label,
                    description = string.format("Quantidade: %d  \nPreço Unitário: $%d | Total: $%d", count, price, itemTotal),
                    icon = 'fa-solid fa-recycle',
                    onSelect = function()
                        local duration = count >= 500 and 20000 or 5000
                        local success = lib.progressBar({
                            duration = duration,
                            label = 'Entregando materiais...',
                            anim = {
                                dict = 'mp_safehouselost@',
                                clip = 'package_dropoff',
                                flag = 48
                            },
                            disable = {
                                move = true,
                                car = true,
                                combat = true
                            }
                        })
                        
                        if success then
                            TriggerServerEvent('nv_recycle:server:sellItem', cfg.item)
                            Wait(500)
                            openSellMenu()
                        else
                            lib.notify({ type = 'info', description = 'Venda cancelada.' })
                            openSellMenu()
                        end
                    end
                })
            end
        end
        
        table.insert(options, 1, {
            title = 'Vender Todos os Recicláveis',
            description = string.format("Valor total estimado: $%d", totalEstimate),
            disabled = not hasAny,
            icon = 'fa-solid fa-dollar-sign',
            onSelect = function()
                local totalCount = 0
                for _, subCfg in ipairs(Config.SellableItems or {}) do
                    totalCount = totalCount + (exports.ox_inventory:Search('count', subCfg.item) or 0)
                end
                
                local duration = totalCount >= 500 and 20000 or 5000
                local success = lib.progressBar({
                    duration = duration,
                    label = 'Entregando todos os materiais...',
                    anim = {
                        dict = 'mp_safehouselost@',
                        clip = 'package_dropoff',
                        flag = 48
                    },
                    disable = {
                        move = true,
                        car = true,
                        combat = true
                    }
                })
                
                if success then
                    TriggerServerEvent('nv_recycle:server:sellAll')
                    Wait(500)
                    openSellMenu()
                else
                    lib.notify({ type = 'info', description = 'Venda cancelada.' })
                    openSellMenu()
                end
            end
        })
        
        lib.registerContext({
            id = 'nv_recycle_sell_menu',
            title = 'Comércio de Recicláveis',
            options = options
        })
        lib.showContext('nv_recycle_sell_menu')
    end)
end

CreateThread(function()
    local sellOptions = {
        {
            name = 'nv_recycle:sell_materials',
            icon = 'fa-solid fa-dollar-sign',
            label = 'Vender Recicláveis',
            distance = 2.0,
            onSelect = function()
                openSellMenu()
            end
        }
    }
    exports.ox_target:addModel({ -14708062, 4280259234, 811169045 }, sellOptions)
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
                    if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.weight and item.metadata.weight > 0 then
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
            if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.weight and item.metadata.weight > 0 then
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
            if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.weight and item.metadata.weight > 0 then
                return item
            end
        end
    end
    return nil
end


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
end, false)

RegisterNetEvent('nv_recycle:client:playThrowAnim', function()
    local ped = cache.ped
    lib.requestAnimDict('anim@heists@narcotics@trash')
    TaskPlayAnim(ped, 'anim@heists@narcotics@trash', 'throw_b', 8.0, -8.0, 1000, 48, 0.0, false, false, false)
    Wait(500)
    if carriedProp and DoesEntityExist(carriedProp) then
        DeleteEntity(carriedProp)
        carriedProp = nil
    end
end)
