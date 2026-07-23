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

-- ==========================================================================
-- SERVER EVENTS (Eventos menu)
-- ==========================================================================

-- Trigger the gas station replenishment event via nv_delivery
RegisterNetEvent('nv_adminmenu:server:startGasEvent', function()
    local src = source
    if not isAdmin(src) then return end

    if GetResourceState('nv_delivery') ~= 'started' then
        return TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'O recurso nv_delivery não está ativo.'
        })
    end

    local ok, success, affected = pcall(function()
        return exports.nv_delivery:startGasEvent()
    end)

    if ok and success then
        print(('[nv_adminmenu] %s (id %s) iniciou o evento de postos (%d postos).')
            :format(GetPlayerName(src) or '?', src, affected or 0))
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Falha ao iniciar o evento de postos de gasolina.'
        })
    end
end)

-- Register command to open admin menu
lib.addCommand('adminmenu', {
    help = 'Abrir Menu Administrativo',
    restricted = 'group.admin'
}, function(source, args, raw)
    TriggerClientEvent('nv_adminmenu:client:openMenu', source)
end)

-- ==========================================================================
-- HANDLING
-- Presets salvos pelo tablet, guardados em handling.json. Servem como
-- registro do que foi afinado: o valor definitivo vai para o handling.meta
-- do veiculo (o tablet copia o XML pronto ao salvar).
-- ==========================================================================
local handlingFile = 'handling.json'
local savedHandling = {}

do
    local raw = LoadResourceFile(GetCurrentResourceName(), handlingFile)

    if raw then
        savedHandling = json.decode(raw) or {}
    end
end

RegisterNetEvent('nv_adminmenu:server:saveHandling', function(model, values)
    local src = source

    if not isAdmin(src) then return end
    if type(model) ~= 'string' or type(values) ~= 'table' then return end

    savedHandling[model] = values

    local ok, encoded = pcall(json.encode, savedHandling, { indent = true })

    if ok then
        SaveResourceFile(GetCurrentResourceName(), handlingFile, encoded, -1)
        print(('^2[nv_adminmenu] Handling de %s salvo em %s^7'):format(model, handlingFile))
    else
        print('^1[nv_adminmenu] Erro ao codificar handling.json^7')
    end
end)

lib.callback.register('nv_adminmenu:server:getHandling', function(source, model)
    if not isAdmin(source) then return nil end

    return model and savedHandling[model] or savedHandling
end)

-- ==========================================================================
-- VEICULOS
--
-- Cria um veiculo no nome de um jogador, ja guardado na garagem configurada.
-- Sem coordenadas o ox_core so grava a linha no banco e nao spawna nada, que
-- e exatamente o que queremos: o dono retira pelo painel da garagem.
-- ==========================================================================

--- Catalogo do ox_core (`common/data/vehicles.json`), lido uma vez.
---@type table<string, table>?
local vehicleCatalog

local function loadCatalog()
    if vehicleCatalog then return vehicleCatalog end

    local file = LoadResourceFile('ox_core', 'common/data/vehicles.json')
    local ok, decoded = pcall(json.decode, file or '')

    if not ok or type(decoded) ~= 'table' then
        print('^1[nv_adminmenu] Nao foi possivel ler common/data/vehicles.json do ox_core.^7')
        vehicleCatalog = {}
    else
        vehicleCatalog = decoded
    end

    return vehicleCatalog
end

--- Lista para o select pesquisavel. O nome do modelo entra no rotulo de
--- proposito: e por ele que se procura quando se sabe o que quer.
lib.callback.register('nv_adminmenu:server:getVehicleList', function(source)
    if not isAdmin(source) then return {} end

    local list = {}

    for model, entry in pairs(loadCatalog()) do
        local name = entry.name or model
        local make = entry.make ~= '' and entry.make or nil

        list[#list + 1] = {
            value = model,
            label = make and ('%s %s  (%s)'):format(make, name, model)
                or ('%s  (%s)'):format(name, model)
        }
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    return list
end)

RegisterNetEvent('nv_adminmenu:server:giveVehicle', function(targetId, model)
    local src = source

    if not isAdmin(src) then return end

    targetId = tonumber(targetId)

    if not targetId or type(model) ~= 'string' then return end

    model = model:lower()

    -- Modelo fora do catalogo faz o ox_core lancar erro: melhor recusar aqui,
    -- com uma mensagem que diz o que houve.
    if not loadCatalog()[model] then
        return TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Modelo desconhecido: %s'):format(model)
        })
    end

    local target = Ox.GetPlayer(targetId)

    if not target or not target.charId then
        return TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'O jogador precisa estar com um personagem carregado.'
        })
    end

    local settings = Config.Vehicles or {}
    local garage = settings.garage or 'legion'

    -- A garagem mais proxima de quem vai receber. O nv_garage e quem conhece
    -- as garagens; pcall porque ele pode nao estar rodando.
    if settings.useNearest ~= false and GetResourceState('nv_garage') == 'started' then
        local ok, nearest = pcall(function()
            return exports.nv_garage:NearestGarage(targetId)
        end)

        if ok and type(nearest) == 'string' then garage = nearest end
    end

    local ok, vehicle = pcall(Ox.CreateVehicle, {
        model = model,
        owner = target.charId,
        stored = garage
    })

    if not ok or not vehicle then
        print(('^1[nv_adminmenu] Falha ao criar %s para o charId %s: %s^7')
            :format(model, target.charId, tostring(vehicle)))

        return TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Nao foi possivel criar o veiculo. Veja o console do servidor.'
        })
    end

    print(('[nv_adminmenu] %s (id %s) criou %s [%s] para %s (charId %s), guardado em "%s".')
        :format(GetPlayerName(src) or '?', src, model, vehicle.plate or '?',
            GetPlayerName(targetId) or '?', target.charId, garage))

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('%s entregue a %s. Placa %s, guardado na garagem "%s".')
            :format(model:upper(), GetPlayerName(targetId) or targetId, vehicle.plate or '?', garage)
    })

    if targetId ~= src then
        TriggerClientEvent('ox_lib:notify', targetId, {
            type = 'success',
            description = ('Um veiculo foi registrado no seu nome (placa %s). Retire na garagem mais proxima.')
                :format(vehicle.plate or '?')
        })
    end
end)

-- Evento manual das lojas 24/7. Espelha o dos postos: esvazia as prateleiras
-- (a condicao) e avisa os jogadores (o chamado).
RegisterNetEvent('nv_adminmenu:server:startShop247Event', function()
    local src = source
    if not isAdmin(src) then return end

    if GetResourceState('nv_delivery') ~= 'started' then
        return TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'O recurso nv_delivery não está ativo.'
        })
    end

    local ok, success, affected, reason = pcall(function()
        return exports.nv_delivery:startShop247Event()
    end)

    if ok and success then
        print(('[nv_adminmenu] %s (id %s) iniciou o evento das lojas 24/7 (%d lojas).')
            :format(GetPlayerName(src) or '?', src, affected or 0))

        return
    end

    -- `ok == false` significa que a chamada em si estourou (export inexistente,
    -- resource caido). Distinguir isso de "rodou e recusou" e o que evita
    -- procurar o problema no lugar errado.
    local message = ok and (reason or 'O evento recusou.')
        or ('Erro ao chamar o nv_delivery: %s'):format(tostring(affected))

    print(('^1[nv_adminmenu] evento 24/7 falhou: %s^7'):format(message))

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'error',
        description = message,
        duration = 7000
    })
end)
