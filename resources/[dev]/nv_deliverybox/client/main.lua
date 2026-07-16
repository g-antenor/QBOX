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
    SetBlipSprite(currentDeliveryBlip, 1) -- Blip padrão de ponto
    SetBlipColour(currentDeliveryBlip, 5) -- Amarelo
    SetBlipScale(currentDeliveryBlip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Entrega: " .. label)
    EndTextCommandSetBlipName(currentDeliveryBlip)
    SetBlipRoute(currentDeliveryBlip, true) -- Ativa a rota no mini-mapa
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

-- Limpa estado das caixas locais do trabalho atual (sem remover os pallets fixos)
local function cleanLocalProps()
    for id, prop in pairs(localProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    localProps = {}
end

RegisterNetEvent('nv_deliverybox:cleanJobState', function()
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
    print("[nv_deliverybox] deliverAtDoor triggered. Held item:", held and json.encode(held))
    if not held then
        print("[nv_deliverybox] Error: Player does not have any delivery item!")
        return
    end
    
    local slot = held.slot
    local itemName = held.name
    
    -- Executa animação de se agachar para colocar
    requestAnimDict('pickup_object')
    TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 1000, 48, 0, false, false, false)
    Wait(800)
    
    print("[nv_deliverybox] Awaiting completeDelivery callback on slot:", slot)
    local success = lib.callback.await('nv_deliverybox:completeDelivery', false, slot)
    print("[nv_deliverybox] completeDelivery result:", success)
    if success then
        -- Cria prop físico permanente no chão
        local model = getPropModel(itemName)
        if model then
            lib.requestModel(model)
            local prop = CreateObject(model, currentDeliveryCoords.x, currentDeliveryCoords.y, currentDeliveryCoords.z - 0.98, true, true, false)
            PlaceObjectOnGroundProperly(prop)
            FreezeEntityPosition(prop, true)
            print("[nv_deliverybox] Created physical ground prop:", prop)
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
                name = 'nv_deliverybox:place_pkg',
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
            name = 'nv_deliverybox:start',
            label = 'Solicitar Entrega',
            icon = 'fa-solid fa-truck-ramp-box',
            distance = 1.0,
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
                local success, result = lib.callback.await('nv_deliverybox:startJob', false)
                if success then
                    activeJob = result.packages
                    local palletId = result.palletId
                    
                    -- Limpa props antigos de caixa se houver
                    cleanLocalProps()
                    
                    -- Coordenadas do pallet atribuído
                    local palletCoords = Config.Pallets[palletId].coords
                    local baseCoords = vec3(palletCoords.x, palletCoords.y, palletCoords.z)
                    local heading = palletCoords.w
                    
                    -- Definição dos slots de empilhamento no pallet
                    local slots = {
                        [1] = {lx = -0.25, ly = -0.25, lz = -0.85}, -- Base inferior esquerda
                        [2] = {lx = 0.25, ly = -0.25, lz = -0.85},  -- Base inferior direita
                        [3] = {lx = -0.25, ly = 0.25, lz = -0.85},  -- Base superior esquerda
                        [4] = {lx = -0.15, ly = -0.15, lz = -0.60}, -- Camada média esquerda
                        [5] = {lx = 0.0, ly = 0.0, lz = -0.40}      -- Topo central
                    }
                    
                    -- Spawn físico de cada pacote em seu respectivo slot no pallet atribuído (gerado localmente)
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
            name = 'nv_deliverybox:cancel',
            label = 'Cancelar Serviço',
            icon = 'fa-solid fa-xmark',
            canInteract = function()
                return activeJob ~= nil
            end,
            onSelect = function()
                local held = exports.ox_inventory:GetHoldingItem()
                local isHoldingDelivery = held and (held.name == 'delivery_letter' or held.name == 'delivery_small_box' or held.name == 'delivery_large_package')
                TriggerServerEvent('nv_deliverybox:cancelJob', isHoldingDelivery)
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
    
    -- Executa a animação de se agachar para pegar
    requestAnimDict('pickup_object')
    TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, 8.0, 1000, 48, 0, false, false, false)
    
    if lib.progressBar({
        duration = 1000,
        label = 'Pegando encomenda...',
        useLib = true,
        disable = { move = true, car = true, combat = true }
    }) then
        local success = lib.callback.await('nv_deliverybox:pickupPackage', false, pkgId)
        if success then
            -- Deleta o prop localmente e remove das tabelas do cliente
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
                Wait(250) -- Sincroniza inventário
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
            name = 'nv_deliverybox:pickup_pkg',
            label = 'Pegar Encomenda',
            icon = 'fa-solid fa-box',
            distance = 1.0,
            canInteract = function(entity, distance, coords, name, bone)
                return isPackageFromPallet(entity)
            end,
            onSelect = function(data)
                pickupPackage(data.entity)
            end
        }
    })
end)

-- Thread de escuta de GPS ("Pegar o endereço") e controle de UI de endereço
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
                        SetNewWaypoint(currentDeliveryCoords.x, currentDeliveryCoords.y)
                        createDeliveryBlip(currentDeliveryCoords, metadata.deliveryLabel)
                        lib.notify({ type = 'info', description = "Rota de entrega traçada no GPS: " .. (metadata.deliveryLabel or "Destino") })
                        
                        -- Cria a zona no target se NÃO for uma entrega para NPC
                        if not metadata.hasNPC then
                            createDeliveryTargetZone(currentDeliveryCoords)
                        else
                            removeDeliveryTargetZone()
                        end

                        showingAddressUI = false
                        lib.hideTextUI()
                    else
                        lib.notify({ type = 'error', description = "Erro nos metadados de endereço do pacote." })
                    end
                end
            else
                if showingAddressUI then
                    showingAddressUI = false
                    lib.hideTextUI()
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

-- Thread dinâmica para detectar proximidade do destino e spawnar NPC destinatário
CreateThread(function()
    while true do
        local wait = 1000
        local heldItem = nil
        local deliveryItems = {'delivery_letter', 'delivery_small_box', 'delivery_large_package'}
        for _, name in ipairs(deliveryItems) do
            local slot = exports.ox_inventory:GetSlotWithItem(name)
            if slot then
                heldItem = slot
                break
            end
        end
        
        if heldItem and currentDeliveryCoords and heldItem.metadata and heldItem.metadata.hasNPC then
            local pedCoords = GetEntityCoords(cache.ped)
            local dist = #(pedCoords - currentDeliveryCoords)
            
            if dist < 12.0 then
                wait = 250
                -- Spawna o NPC destinatário se ainda não existir
                if not spawnedReceiverNPC then
                    local npcModel = Config.ReceiverNPCs[math.random(1, #Config.ReceiverNPCs)]
                    lib.requestModel(npcModel)
                    
                    spawnedReceiverNPC = CreatePed(4, npcModel, currentDeliveryCoords.x, currentDeliveryCoords.y, currentDeliveryCoords.z - 1.0, 0.0, false, true)
                    SetEntityInvincible(spawnedReceiverNPC, true)
                    FreezeEntityPosition(spawnedReceiverNPC, true)
                    SetBlockingOfNonTemporaryEvents(spawnedReceiverNPC, true)
                    
                    -- Adiciona interação via ox_target no NPC dinâmico
                    exports.ox_target:addLocalEntity(spawnedReceiverNPC, {
                        {
                            name = 'nv_deliverybox:deliver_pkg',
                            label = 'Entregar Encomenda',
                            icon = 'fa-solid fa-hands-holding',
                            distance = 1.0,
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
                                local held = nil
                                local deliveryItems = {'delivery_letter', 'delivery_small_box', 'delivery_large_package'}
                                for _, name in ipairs(deliveryItems) do
                                    local slot = exports.ox_inventory:GetSlotWithItem(name)
                                    if slot then
                                        held = slot
                                        break
                                    end
                                end
                                print("[nv_deliverybox] NPC deliver onSelect triggered. Held:", held and json.encode(held))
                                if not held then return end
                                
                                print("[nv_deliverybox] Awaiting NPC completeDelivery callback on slot:", held.slot)
                                local success = lib.callback.await('nv_deliverybox:completeDelivery', false, held.slot)
                                print("[nv_deliverybox] NPC completeDelivery result:", success)
                                if success then
                                    local npc = spawnedReceiverNPC
                                    spawnedReceiverNPC = nil
                                    
                                    -- Animação de entrega/recebimento no player e NPC
                                    requestAnimDict("mp_safehouselost@")
                                    TaskPlayAnim(cache.ped, "mp_safehouselost@", "package_dropoff", 8.0, -8.0, 2000, 48, 0, false, false, false)
                                    TaskPlayAnim(npc, "mp_safehouselost@", "package_dropoff", 8.0, -8.0, 2000, 48, 0, false, false, false)
                                    Wait(1500)
                                    
                                    -- Cria o prop na mão do NPC
                                    local model = getPropModel(held.name)
                                    if model then
                                        lib.requestModel(model)
                                        local prop = CreateObject(model, currentDeliveryCoords.x, currentDeliveryCoords.y, currentDeliveryCoords.z, false, true, false)
                                        AttachEntityToEntity(prop, npc, GetPedBoneIndex(npc, 57005), 0.1, 0.05, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                                        
                                        -- NPC anda em frente e depois desaparece
                                        local heading = GetEntityHeading(npc)
                                        local rad = math.rad(heading)
                                        local forward = vec3(-math.sin(rad), math.cos(rad), 0.0)
                                        local walkCoords = GetEntityCoords(npc) + (forward * 7.0)
                                        
                                        FreezeEntityPosition(npc, false)
                                        ClearPedTasks(npc)
                                        TaskGoStraightToCoord(npc, walkCoords.x, walkCoords.y, walkCoords.z, 1.0, -1, 0.0, 0.0)
                                        
                                        CreateThread(function()
                                            local timer = 6000
                                            while timer > 0 and DoesEntityExist(npc) do
                                                Wait(500)
                                                timer = timer - 500
                                                local currentNPCCoords = GetEntityCoords(npc)
                                                if #(currentNPCCoords - walkCoords) < 1.2 then
                                                    break
                                                end
                                            end
                                            
                                            -- Fade out suave antes de deletar
                                            if DoesEntityExist(npc) then
                                                SetEntityAlpha(npc, 200, false)
                                                Wait(100)
                                                SetEntityAlpha(npc, 150, false)
                                                Wait(100)
                                                SetEntityAlpha(npc, 100, false)
                                                Wait(100)
                                                SetEntityAlpha(npc, 50, false)
                                                Wait(100)
                                            end
                                            
                                            if DoesEntityExist(prop) then DeleteEntity(prop) end
                                            if DoesEntityExist(npc) then DeleteEntity(npc) end
                                        end)
                                    else
                                        DeleteEntity(npc)
                                    end
                                    
                                    removeDeliveryBlip()
                                    currentDeliveryCoords = nil
                                end
                            end
                        }
                    })
                end
            else
                -- Remove o NPC se o jogador se afastar sem concluir a entrega
                if spawnedReceiverNPC then
                    DeleteEntity(spawnedReceiverNPC)
                    spawnedReceiverNPC = nil
                end
            end
        else
            -- Limpeza preventiva de NPC dinâmico se guardar a caixa
            if spawnedReceiverNPC then
                DeleteEntity(spawnedReceiverNPC)
                spawnedReceiverNPC = nil
            end
        end
        Wait(wait)
    end
end)

-- Thread para desenhar a marcação no chão no ponto de entrega
CreateThread(function()
    while true do
        local wait = 1000
        if currentDeliveryCoords then
            local pedCoords = GetEntityCoords(cache.ped)
            local dist = #(pedCoords - currentDeliveryCoords)
            if dist < 25.0 then
                wait = 0
                -- Desenha o marker no chão (Tipo 27 = anel plano/glowing ring)
                DrawMarker(27, currentDeliveryCoords.x, currentDeliveryCoords.y, currentDeliveryCoords.z - 0.98, 
                    0.0, 0.0, 0.0, -- direção
                    0.0, 0.0, 0.0, -- rotação
                    1.5, 1.5, 1.0, -- escala
                    255, 204, 0, 100, -- Cor RGBA (Amarelo translúcido)
                    false, true, 2, false, nil, nil, false
                )
            end
        end
        Wait(wait)
    end
end)

-- Limpeza geral ao descarregar recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if mainNPC then
        DeleteEntity(mainNPC)
    end
    if spawnedReceiverNPC then
        DeleteEntity(spawnedReceiverNPC)
    end
    cleanLocalProps()
    removeDeliveryTargetZone()
    -- Deleta os 3 pallets físicos estáticos
    for i = 1, #spawnedPallets do
        if DoesEntityExist(spawnedPallets[i]) then
            DeleteEntity(spawnedPallets[i])
        end
    end
    spawnedPallets = {}
    removeDeliveryBlip()
    lib.hideTextUI()
    if carryingProp and DoesEntityExist(carryingProp) then
        DeleteEntity(carryingProp)
    end
end)

local carryingProp = nil
local carryingItemName = nil
local activeCarryAnim = { dict = "anim@heists@box_carry@", name = "idle" }

local function stopCarrying()
    if carryingProp and DoesEntityExist(carryingProp) then
        DeleteEntity(carryingProp)
    end
    carryingProp = nil
    carryingItemName = nil
    ClearPedTasks(cache.ped)
end

local function startCarrying(itemName)
    if carryingProp then stopCarrying() end

    local model = getPropModel(itemName)
    if not model then return end

    lib.requestModel(model)
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    carryingProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    
    -- Default carrying values
    local animDict = "anim@heists@box_carry@"
    local animName = "idle"
    local boneId = 60309
    local ox, oy, oz = 0.025, 0.08, 0.255
    local rx, ry, rz = -145.0, 290.0, 0.0

    -- Query nv_syncitens database export using pcall to avoid script crashing if not running
    local hasSync, data = pcall(function()
        return exports.nv_syncitens:getAttachment(model)
    end)

    if hasSync and data then
        animDict = data.animDict or animDict
        animName = data.animName or animName
        boneId = data.boneId or boneId
        if data.offset then
            ox, oy, oz = data.offset.x or ox, data.offset.y or oy, data.offset.z or oz
        end
        if data.rotation then
            rx, ry, rz = data.rotation.x or rx, data.rotation.y or ry, data.rotation.z or rz
        end
    end

    activeCarryAnim.dict = animDict
    activeCarryAnim.name = animName

    -- Attach using custom database values
    AttachEntityToEntity(carryingProp, ped, GetPedBoneIndex(ped, boneId), ox, oy, oz, rx, ry, rz, true, true, false, true, 1, true)
    
    carryingItemName = itemName

    -- Play carrying animation
    requestAnimDict(animDict)
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
end

CreateThread(function()
    while true do
        local wait = 500
        local ped = cache.ped
        
        -- Find if we have a delivery item in inventory
        local currentBox = nil
        local deliveryItems = {'delivery_letter', 'delivery_small_box', 'delivery_large_package'}
        for _, name in ipairs(deliveryItems) do
            if exports.ox_inventory:GetSlotWithItem(name) then
                currentBox = name
                break
            end
        end

        if currentBox then
            wait = 0
            if not carryingProp or carryingItemName ~= currentBox then
                startCarrying(currentBox)
            end

            -- Ensure animation is playing
            if not IsEntityPlayingAnim(ped, activeCarryAnim.dict, activeCarryAnim.name, 3) then
                requestAnimDict(activeCarryAnim.dict)
                TaskPlayAnim(ped, activeCarryAnim.dict, activeCarryAnim.name, 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            -- Disable running, jumping, and entering vehicles
            DisableControlAction(0, 21, true) -- INPUT_SPRINT (Sprint/Run)
            DisableControlAction(0, 22, true) -- INPUT_JUMP (Jump)
            DisableControlAction(0, 23, true) -- INPUT_ENTER (Enter vehicle / F)
            DisableControlAction(0, 75, true) -- INPUT_VEH_EXIT (Exit vehicle)
            
            -- Disable firing/aiming
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true) -- Attack (LMB)
            DisableControlAction(0, 25, true) -- Aim (RMB)
        else
            if carryingProp then
                stopCarrying()
            end
        end
        Wait(wait)
    end
end)
