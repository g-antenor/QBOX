local Ox = require '@ox_core.lib.init'

local placedProps = {} -- [netId] = { item = string, source = number }

--- Obtém o nome formatado do cidadão
local function getCharacterName(src)
    local player = Ox.GetPlayer(src)
    if player then
        local name = player.get('name')
        if name and name ~= '' then return name end
    end

    local charId = player and player.charId
    if charId then
        local row = MySQL.single.await('SELECT `fullName`, `firstName`, `lastName` FROM `characters` WHERE `charId` = ?', { charId })
        if row then
            if row.fullName and row.fullName ~= '' then return row.fullName end
            if row.firstName and row.lastName then return ('%s %s'):format(row.firstName, row.lastName) end
        end
    end

    return GetPlayerName(src) or ('ID %d'):format(src)
end

-- ----------------------------------------------------------- Algemas e Chave --

lib.callback.register('nv_police:cuffPlayer', function(source, targetServerId, cuffPosition)
    local targetPed = GetPlayerPed(targetServerId)
    local sourcePed = GetPlayerPed(source)

    if not targetPed or targetPed == 0 or #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) > 4.0 then
        return false, 'O cidadão está muito distante.'
    end

    local count = exports.ox_inventory:GetItemCount(source, Config.Items.handcuffs)
    if count < 1 then
        return false, 'Você não possui algemas.'
    end

    if exports.ox_inventory:RemoveItem(source, Config.Items.handcuffs, 1) then
        exports.ox_inventory:AddItem(source, Config.Items.handcuffKey, 1)

        Player(targetServerId).state:set('isCuffed', true, true)
        Player(targetServerId).state:set('cuffPosition', cuffPosition or 'behind', true)
        return true
    end

    return false, 'Não foi possível utilizar as algemas.'
end)

lib.callback.register('nv_police:uncuffPlayer', function(source, targetServerId)
    local targetPed = GetPlayerPed(targetServerId)
    local sourcePed = GetPlayerPed(source)

    if not targetPed or targetPed == 0 or #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) > 4.0 then
        return false, 'O cidadão está muito distante.'
    end

    local count = exports.ox_inventory:GetItemCount(source, Config.Items.handcuffKey)
    if count < 1 then
        return false, 'Você não possui a chave de algemas.'
    end

    if exports.ox_inventory:RemoveItem(source, Config.Items.handcuffKey, 1) then
        exports.ox_inventory:AddItem(source, Config.Items.handcuffs, 1)

        Player(targetServerId).state:set('isCuffed', false, true)
        Player(targetServerId).state:set('cuffPosition', nil, true)
        return true
    end

    return false, 'Não foi possível utilizar a chave.'
end)

-- ----------------------------------------- Registro de Eventos e Disparos --

RegisterNetEvent('nv_police:recordShot', function()
    local src = source
    Player(src).state:set('lastShotTime', os.time(), true)
end)

-- ------------------------------------------------------------- Testes Forenses --

lib.callback.register('nv_police:runTest', function(source, slot, testType, targetServerId)
    if not slot or not targetServerId then return false, 'Parâmetros inválidos.' end

    local charName = getCharacterName(targetServerId)
    local isPositive = false

    if testType == 'polvora' then
        local shotTime = Player(targetServerId).state.lastShotTime or 0
        isPositive = (os.time() - shotTime) < 600 -- 10 minutos
    elseif testType == 'drogas' then
        local drugTime = Player(targetServerId).state.lastDrugTime or 0
        isPositive = (os.time() - drugTime) < 600 -- 10 minutos
    end

    local statusText = isPositive and 'Positivo' or 'Negativo'
    local descriptionText = ('Resultado: %s | Cidadão: %s'):format(statusText, charName)

    exports.ox_inventory:SetMetadata(source, slot, {
        description = descriptionText,
        status = statusText:lower(),
        targetName = charName,
        testedAt = os.date('%H:%M:%S')
    })

    return true, descriptionText
end)

lib.callback.register('nv_police:runBreathalyzerTest', function(source, slot, targetServerId, obstructed)
    if not slot or not targetServerId then return false, 'Parâmetros inválidos.' end

    local charName = getCharacterName(targetServerId)

    if obstructed then
        local descriptionText = ('Resultado: Negativo (Obstruído) | Cidadão: %s'):format(charName)

        exports.ox_inventory:SetMetadata(source, slot, {
            description = descriptionText,
            status = 'obstruido',
            targetName = charName,
            testedAt = os.date('%H:%M:%S')
        })

        return true, descriptionText
    end

    local drinkTime = Player(targetServerId).state.lastDrinkTime or 0
    local isPositive = (os.time() - drinkTime) < 600 -- 10 minutos

    local statusText = isPositive and 'Positivo' or 'Negativo'
    local descriptionText = ('Resultado: %s | Cidadão: %s'):format(statusText, charName)

    exports.ox_inventory:SetMetadata(source, slot, {
        description = descriptionText,
        status = statusText:lower(),
        targetName = charName,
        testedAt = os.date('%H:%M:%S')
    })

    return true, descriptionText
end)

-- --------------------------------------------------------- Spawning de Props --

lib.callback.register('nv_police:placeProp', function(source, itemName, coords, rotation)
    local propData = Config.Props[itemName]
    if not propData then return false, 'Item de prop desconhecido.' end

    local count = exports.ox_inventory:GetItemCount(source, itemName)
    if count < 1 then return false, 'Você não possui este item.' end

    if exports.ox_inventory:RemoveItem(source, itemName, 1) then
        local obj = CreateObjectNoOffset(propData.model, coords.x, coords.y, coords.z, true, true, false)
        SetEntityRotation(obj, rotation.x, rotation.y, rotation.z, 2, true)
        
        while not DoesEntityExist(obj) do Wait(10) end
        
        local netId = NetworkGetNetworkIdFromEntity(obj)
        placedProps[netId] = { item = itemName, source = source }
        return true
    end

    return false, 'Não foi possível posicionar o objeto.'
end)

lib.callback.register('nv_police:removeProp', function(source, netId)
    if not netId or netId == 0 then return false, 'Objeto inválido.' end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false, 'Objeto não encontrado.'
    end

    local model = GetEntityModel(entity)
    local itemName = nil

    if placedProps[netId] then
        itemName = placedProps[netId].item
    else
        for itemKey, cfg in pairs(Config.Props) do
            if cfg.model == model then
                itemName = itemKey
                break
            end
        end
    end

    if not itemName then
        itemName = 'police_cone' -- fallback seguro
    end

    DeleteEntity(entity)
    placedProps[netId] = nil

    exports.ox_inventory:AddItem(source, itemName, 1)
    return true
end)
