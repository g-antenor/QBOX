local activeJob = nil
local mainNPC = nil
local spawnedReceiverNPC = nil
local currentDeliveryCoords = nil
local showingAddressUI = false

-- Referências para os pallets físicos estáticos e props locais de caixas
local spawnedPallets = {} -- Índice de 1 a 3 contendo as entidades dos pallets
local localProps = {}     -- Chave: pkgId, Valor: Entidade do prop de entrega
local currentTargetZone = nil -- Zona de target para entrega de chão

-- Função auxiliar para obter o modelo correspondente ao nome do item
local function getPropModel(itemName)
    if itemName == 'delivery_letter' then return Config.Models.letter end
    if itemName == 'delivery_small_box' then return Config.Models.small end
    if itemName == 'delivery_large_package' then return Config.Models.large end
    return nil
end

-- Helper function to request animations
local function requestAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- Helper to check if player is wearing the required uniform
local function hasRequiredShirt()
    local ped = cache.ped
    local drawable = GetPedDrawableVariation(ped, Config.RequiredShirt.componentId)
    local texture = GetPedTextureVariation(ped, Config.RequiredShirt.componentId)
    return drawable == Config.RequiredShirt.drawableId and texture == Config.RequiredShirt.textureId
end

-- Blip de entrega
local currentDeliveryBlip = nil
local function createDeliveryBlip(coords, label)
    if currentDeliveryBlip then
        RemoveBlip(currentDeliveryBlip)
    end
    currentDeliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(currentDeliveryBlip, 1)
    SetBlipColour(currentDeliveryBlip, 5)
    SetBlipScale(currentDeliveryBlip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Entrega: " .. label)
    EndTextCommandSetBlipName(currentDeliveryBlip)
    SetBlipRoute(currentDeliveryBlip, true)
end

local function removeDeliveryBlip()
    if currentDeliveryBlip then
        RemoveBlip(currentDeliveryBlip)
        currentDeliveryBlip = nil
    end
end

-- Remove a zona do target no chão
local function removeDeliveryTargetZone()
    if currentTargetZone then
        exports.ox_target:removeZone(currentTargetZone)
        currentTargetZone = nil
    end
end

-- Limpa estado das caixas locais do trabalho atual
local function cleanLocalProps()
    for id, prop in pairs(localProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    localProps = {}
end

RegisterNetEvent('nv_delivery:cleanJobState', function()
    activeJob = nil
    currentDeliveryCoords = nil
    removeDeliveryBlip()
    removeDeliveryTargetZone()
    cleanLocalProps()
    if spawnedReceiverNPC and DoesEntityExist(spawnedReceiverNPC) then
        DeleteEntity(spawnedReceiverNPC)
        spawnedReceiverNPC = nil
    end
    showingAddressUI = false
    lib.hideTextUI()
end)

-- Lógica para colocar o pacote no chão e finalizar entrega
local function deliverAtDoor()
    local held = nil
    local deliveryItems = {'delivery_letter', 'delivery_small_box', 'delivery_large_package'}
    for _, name in ipairs(deliveryItems) do
        local slot = exports.ox_inventory:GetSlotWithItem(name)
        if slot then
            held = slot
            break
        end
    end
    if not held then return end
    
    local slot = held.slot
    local itemName = held.name
    
    -- Executa animação de se agachar para colocar
    requestAnimDict('pickup_object')
    TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 1000, 48, 0, false, false, false)
    Wait(800)
    
    local success = lib.callback.await('nv_delivery:completeDelivery', false, slot)
    if success then
        -- Cria prop físico permanente no chão temporariamente
        local model = getPropModel(itemName)
        if model then
            lib.requestModel(model)
            local prop = CreateObject(model, currentDeliveryCoords.x, currentDeliveryCoords.y, currentDeliveryCoords.z - 0.98, true, true, false)
            PlaceObjectOnGroundProperly(prop)
            FreezeEntityPosition(prop, true)
            SetTimeout(10000, function()
                if DoesEntityExist(prop) then
                    DeleteEntity(prop)
                end
            end)
        end
        
        removeDeliveryBlip()
        removeDeliveryTargetZone()
        currentDeliveryCoords = nil
    else
        ClearPedTasks(cache.ped)
    end
end

-- Cria a zona do target no chão para entrega física
local function createDeliveryTargetZone(coords)
    removeDeliveryTargetZone()
    
    currentTargetZone = exports.ox_target:addSphereZone({
        coords = coords,
        radius = 1.0,
        debug = false,
        options = {
            {
                name = 'nv_delivery:place_pkg',
                label = 'Deixar Encomenda',
                icon = 'fa-solid fa-arrow-down-to-bracket',
                canInteract = function()
                    local hasItem = false
                    local deliveryItems = {'delivery_letter', 'delivery_small_box', 'delivery_large_package'}
                    for _, name in ipairs(deliveryItems) do
                        if exports.ox_inventory:GetSlotWithItem(name) then
                            hasItem = true
                            break
                        end
                    end
                    return hasItem
                end,
                onSelect = function()
                    deliverAtDoor()
                end
            }
        }
    })
end

-- Helper para calcular offsets locais relativos à rotação do pallet
local function getOffsetCoords(base, h, lx, ly, lz)
    local rad = math.rad(h)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    local rx = base.x + (lx * cos - ly * sin)
    local ry = base.y + (lx * sin + ly * cos)
    local rz = base.z + lz
    return vec3(rx, ry, rz)
end

-- Spawn inicial dos 3 Pallets fixos ao carregar o script
CreateThread(function()
    lib.requestModel(Config.Models.pallet)
    for i, palletConfig in ipairs(Config.Pallets) do
        local coords = palletConfig.coords
        local pallet = CreateObject(Config.Models.pallet, coords.x, coords.y, coords.z - 1.0, false, true, false)
        FreezeEntityPosition(pallet, true)
        SetEntityRotation(pallet, 0.0, 0.0, coords.w, 2, true)
        spawnedPallets[i] = pallet
    end
end)

-- Spawn do NPC inicializador do serviço
CreateThread(function()
    lib.requestModel(Config.StartNPC.model)
    mainNPC = CreatePed(4, Config.StartNPC.model, Config.StartNPC.coords.x, Config.StartNPC.coords.y, Config.StartNPC.coords.z - 1.0, Config.StartNPC.coords.w, false, true)
    
    SetEntityInvincible(mainNPC, true)
    FreezeEntityPosition(mainNPC, true)
    SetBlockingOfNonTemporaryEvents(mainNPC, true)
    
    -- Executa animação em loop para o NPC inicializador
    if Config.StartNPC.anim then
        requestAnimDict(Config.StartNPC.anim.dict)
        TaskPlayAnim(mainNPC, Config.StartNPC.anim.dict, Config.StartNPC.anim.name, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
    
    -- Registra o NPC inicializador no ox_target
    exports.ox_target:addLocalEntity(mainNPC, {
        {
            name = 'nv_delivery:start',
            label = 'Solicitar Entrega',
            icon = 'fa-solid fa-truck-ramp-box',
            distance = 1.5,
            canInteract = function()
                return not activeJob
            end,
            onSelect = function()
                -- Valida uniforme
                if not hasRequiredShirt() then
                    lib.notify({
                        type = 'error',
                        description = string.format("Você precisa estar vestido com o uniforme de entrega (Camiseta ID: %d)!", Config.RequiredShirt.drawableId)
                    })
                    return
                end
                
                -- Inicia serviço no servidor
                local success, result = lib.callback.await('nv_delivery:startJob', false)
                if success then
                    activeJob = result.packages
                    local palletId = result.palletId
                    
                    cleanLocalProps()
                    
                    local palletCoords = Config.Pallets[palletId].coords
                    local baseCoords = vec3(palletCoords.x, palletCoords.y, palletCoords.z)
                    local heading = palletCoords.w
                    
                    local slots = {
                        [1] = {lx = -0.25, ly = -0.25, lz = -0.85},
                        [2] = {lx = 0.25, ly = -0.25, lz = -0.85},
                        [3] = {lx = -0.25, ly = 0.25, lz = -0.85},
                        [4] = {lx = -0.15, ly = -0.15, lz = -0.60},
                        [5] = {lx = 0.0, ly = 0.0, lz = -0.40}
                    }
                    
                    -- Spawn físico de cada pacote em seu respectivo slot no pallet
                    for i, pkg in ipairs(activeJob) do
                        local slot = slots[i]
                        local spawnCoords = getOffsetCoords(baseCoords, heading, slot.lx, slot.ly, slot.lz)
                        
                        lib.requestModel(pkg.model)
                        local prop = CreateObject(pkg.model, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, true, false)
                        FreezeEntityPosition(prop, true)
                        SetEntityRotation(prop, 0.0, 0.0, heading, 2, true)
                        
                        localProps[pkg.id] = prop
                    end
                    
                    lib.notify({ type = 'success', description = string.format("Serviço iniciado! Dirija-se ao Pallet %d para retirar as encomendas.", palletId) })
                else
                    lib.notify({ type = 'error', description = result or "Não foi possível iniciar o serviço." })
                end
            end
        },
        {
            name = 'nv_delivery:cancel',
            label = 'Cancelar Serviço',
            icon = 'fa-solid fa-xmark',
            distance = 1.5,
            canInteract = function()
                return activeJob ~= nil
            end,
            onSelect = function()
                local held = exports.ox_inventory:GetHoldingItem()
                local isHoldingDelivery = held and (held.name == 'delivery_letter' or held.name == 'delivery_small_box' or held.name == 'delivery_large_package')
                TriggerServerEvent('nv_delivery:cancelJob', isHoldingDelivery)
            end
        }
    })
end)

-- Verifica se a entidade coletada pertence ao pallet do jogador
local function isPackageFromPallet(entity)
    if not activeJob then return false end
    for id, prop in pairs(localProps) do
        if prop == entity then
            return true
        end
    end
    return false
end

-- Lógica de pegar o pacote físico do pallet
local function pickupPackage(entity)
    local pkgId = nil
    for id, prop in pairs(localProps) do
        if prop == entity then
            pkgId = id
            break
        end
    end
    
    if not pkgId then return end
    
    requestAnimDict('pickup_object')
    TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, 8.0, 1000, 48, 0, false, false, false)
    
    if lib.progressBar({
        duration = 1000,
        label = 'Pegando encomenda...',
        useLib = true,
        disable = { move = true, car = true, combat = true }
    }) then
        local success = lib.callback.await('nv_delivery:pickupPackage', false, pkgId)
        if success then
            if localProps[pkgId] and DoesEntityExist(localProps[pkgId]) then
                DeleteEntity(localProps[pkgId])
                localProps[pkgId] = nil
            end
            
            local itemName = nil
            for i, pkg in ipairs(activeJob) do
                if pkg.id == pkgId then
                    itemName = pkg.itemName
                    table.remove(activeJob, i)
                    break
                end
            end
            
            lib.notify({ type = 'success', description = "Você coletou a encomenda!" })
            if itemName then
                Wait(250)
            end
        end
    else
        ClearPedTasks(cache.ped)
    end
end

-- Registra a interação do Target com os modelos de encomendas
CreateThread(function()
    exports.ox_target:addModel({Config.Models.letter, Config.Models.small, Config.Models.large}, {
        {
            name = 'nv_delivery:pickup_pkg',
            label = 'Pegar Encomenda',
            icon = 'fa-solid fa-box',
            distance = 1.5,
            canInteract = function(entity, distance, coords, name, bone)
                return isPackageFromPallet(entity)
            end,
            onSelect = function(data)
                pickupPackage(data.entity)
            end
        }
    })
end)

-- Thread de escuta de GPS e controle de UI de endereço
CreateThread(function()
    while true do
        local wait = 500
        local heldItem = nil
        local deliveryItems = {'delivery_letter', 'delivery_small_box', 'delivery_large_package'}
        for _, name in ipairs(deliveryItems) do
            local slot = exports.ox_inventory:GetSlotWithItem(name)
            if slot then
                heldItem = slot
                break
            end
        end
        if heldItem and (heldItem.name == 'delivery_letter' or heldItem.name == 'delivery_small_box' or heldItem.name == 'delivery_large_package') then
            local packageCoords = heldItem.metadata and heldItem.metadata.deliveryCoords and vector3(heldItem.metadata.deliveryCoords.x, heldItem.metadata.deliveryCoords.y, heldItem.metadata.deliveryCoords.z)
            local isAlreadyMarked = false
            if packageCoords and currentDeliveryCoords and #(currentDeliveryCoords - packageCoords) < 1.0 then
                isAlreadyMarked = true
            end

            if not isAlreadyMarked then
                wait = 0
                
                if not showingAddressUI then
                    showingAddressUI = true
                    lib.showTextUI('[E] Pegar o endereço')
                end
                
                if IsControlJustPressed(0, 38) then -- [E]
                    local metadata = heldItem.metadata
                    if metadata and metadata.deliveryCoords then
                        currentDeliveryCoords = vector3(metadata.deliveryCoords.x, metadata.deliveryCoords.y, metadata.deliveryCoords.z)
                        createDeliveryBlip(currentDeliveryCoords, metadata.deliveryLabel or "Destinatário")
                        createDeliveryTargetZone(currentDeliveryCoords)
                        lib.notify({ type = 'info', description = "Coordenadas marcadas no GPS! Siga a rota até a entrega." })
                        
                        -- Spawn local receiver NPC if box
                        if metadata.hasNPC then
                            if spawnedReceiverNPC and DoesEntityExist(spawnedReceiverNPC) then
                                DeleteEntity(spawnedReceiverNPC)
                            end
                            local npcModel = Config.ReceiverNPCs[math.random(1, #Config.ReceiverNPCs)]
                            lib.requestModel(npcModel)
                            spawnedReceiverNPC = CreatePed(4, npcModel, currentDeliveryCoords.x, currentDeliveryCoords.y, currentDeliveryCoords.z - 0.98, 0.0, false, true)
                            SetEntityInvincible(spawnedReceiverNPC, true)
                            FreezeEntityPosition(spawnedReceiverNPC, true)
                            SetBlockingOfNonTemporaryEvents(spawnedReceiverNPC, true)
                        end
                        
                        showingAddressUI = false
                        lib.hideTextUI()
                    end
                end
            end
        else
            if showingAddressUI then
                showingAddressUI = false
                lib.hideTextUI()
            end
        end
        Wait(wait)
    end
end)
