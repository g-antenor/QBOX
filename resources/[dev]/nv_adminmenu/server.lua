local savedAttachments = {}
local dbFileName = "data.json"

local Ox = require '@ox_core.lib.init'

-- Helper function to check if user is admin
local function isAdmin(source)
    if IsPlayerAceAllowed(source, 'command') then return true end
    local player = Ox.GetPlayer(source)
    if not player then return false end
    local groups = player.getGroups()
    return groups and (groups['admin'] or groups['superadmin'] or groups['god']) ~= nil
end

-- Save attachments to data.json
local function saveDatabase()
    local ok, jsonStr = pcall(json.encode, savedAttachments, { indent = true })
    if ok then
        SaveResourceFile(GetCurrentResourceName(), dbFileName, jsonStr, -1)
    else
        print("^1[nv_adminmenu] Erro ao codificar banco de dados para salvar.^7")
    end
end

-- Load attachments from data.json on startup
local function loadDatabase()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), dbFileName)
    if fileContent then
        local ok, data = pcall(json.decode, fileContent)
        if ok and type(data) == "table" then
            savedAttachments = data
            local count = 0
            local migrated = false
            for model, anims in pairs(data) do
                for animName, val in pairs(anims) do
                    count = count + 1
                    if val.name == nil then
                        val.name = ""
                        migrated = true
                    end
                end
            end
            if migrated then
                saveDatabase()
                print("^2[nv_adminmenu] Banco de dados migrado: Adicionados campos 'name' em branco aos registros existentes.^7")
            end
            print(string.format("^2[nv_adminmenu] Banco de dados carregado. %d alinhamentos de props salvos.^7", count))
        else
            print("^1[nv_adminmenu] Erro ao decodificar data.json. Inicializando banco vazio.^7")
            savedAttachments = {}
        end
    else
        -- Create default empty file
        SaveResourceFile(GetCurrentResourceName(), dbFileName, "{}", -1)
        savedAttachments = {}
        print("^3[nv_adminmenu] Banco de dados data.json não encontrado. Criado arquivo padrão vazio.^7")
    end
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        loadDatabase()
    end
end)

-- Sync data to client when requested (Checks if requester is admin)
RegisterNetEvent("nv_syncitens:server:requestSync", function()
    local src = source
    if not isAdmin(src) then return end
    TriggerClientEvent("nv_syncitens:client:syncAttachments", src, savedAttachments)
end)

-- Register new attachment details (Checks if requester is admin)
RegisterNetEvent("nv_syncitens:server:saveAttachment", function(model, animName, data)
    local src = source
    if not isAdmin(src) then return end
    
    if not savedAttachments[model] then
        savedAttachments[model] = {}
    end
    
    savedAttachments[model][animName] = data
    saveDatabase()
    
    -- Sync updated database to all connected clients
    TriggerClientEvent("nv_syncitens:client:syncAttachments", -1, savedAttachments)
    
    TriggerClientEvent("chat:addMessage", src, {
        color = { 0, 255, 0},
        multiline = true,
        args = { "nv_adminmenu", string.format("Ajuste do item '%s' para a animação '%s' registrado no banco de dados!", model, animName) }
    })
end)

-- ==========================================================================
-- ADMIN FUNCTIONALITY EXPORTS & CALLBACKS
-- ==========================================================================

-- Check if player is admin
lib.callback.register('nv_adminmenu:server:isAdmin', function(source)
    return isAdmin(source)
end)

-- Fetch online players
lib.callback.register('nv_adminmenu:server:getOnlinePlayers', function(source)
    if not isAdmin(source) then return {} end
    
    local players = {}
    local activePlayers = GetPlayers()
    for i = 1, #activePlayers do
        local src = tonumber(activePlayers[i])
        local name = GetPlayerName(src)
        table.insert(players, { id = src, name = name })
    end
    return players
end)

-- Promote player to admin
RegisterNetEvent('nv_adminmenu:server:makeAdmin', function(targetId)
    local src = source
    if not isAdmin(src) then return end
    
    local target = Ox.GetPlayer(targetId)
    if not target then return end
    
    ExecuteCommand(('setgroup %d admin 1'):format(targetId))
    
    local identifiers = GetPlayerIdentifiers(targetId)
    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, 8) == "license:" then
            ExecuteCommand(('add_principal identifier.%s group.admin'):format(id))
            break
        end
    end
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Jogador promovido a admin com sucesso!' })
    TriggerClientEvent('ox_lib:notify', targetId, { type = 'info', description = 'Você foi promovido a administrador!' })
end)

-- Revive player
RegisterNetEvent('nv_adminmenu:server:revivePlayer', function(targetId)
    local src = source
    if not isAdmin(src) then return end
    
    TriggerClientEvent('nv_adminmenu:client:revive', targetId)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Comando de Reviver enviado ao jogador!' })
end)

-- Pull player to admin's coordinate
RegisterNetEvent('nv_adminmenu:server:pullPlayer', function(targetId)
    local src = source
    if not isAdmin(src) then return end
    
    local adminPed = GetPlayerPed(src)
    local adminCoords = GetEntityCoords(adminPed)
    
    TriggerClientEvent('nv_adminmenu:client:teleport', targetId, adminCoords)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Teleportou o jogador até você!' })
end)

-- Open pedmenu for target player
RegisterNetEvent('nv_adminmenu:server:givePedMenu', function(targetId)
    local src = source
    if not isAdmin(src) then return end
    
    TriggerClientEvent('nv_adminmenu:client:openPedMenu', targetId)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Pedmenu enviado para o jogador!' })
end)

-- Register command to open admin menu
lib.addCommand('adminmenu', {
    help = 'Abrir Menu Administrativo',
    restricted = 'group.admin'
}, function(source, args, raw)
    TriggerClientEvent('nv_adminmenu:client:openMenu', source)
end)
