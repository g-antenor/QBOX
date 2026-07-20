--[[
    nv_adminmenu — servidor: painel de administracao

    Cada acao revalida admin. O painel e uma tela: nao guarda permissao, nao
    decide nada, e um cliente que chame estes eventos direto passa exatamente
    pelas mesmas checagens de quem clicou no botao.
]]

local Ox = require '@ox_core.lib.init'

--- Repetida aqui porque `isAdmin` do server.lua e local ao arquivo.
---@param source number
---@return boolean
local function panelIsAdmin(source)
    if IsPlayerAceAllowed(source, 'command') then return true end

    local player = Ox.GetPlayer(source)
    if not player then return false end

    local ok, groups = pcall(function() return player.getGroups() end)
    if not ok or type(groups) ~= 'table' then return false end

    return (groups['admin'] or groups['superadmin'] or groups['god']) ~= nil
end

local function notify(source, message, type)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Painel Admin',
        description = message,
        type = type or 'inform'
    })
end

-- ------------------------------------------------------------- catalogos --

--- Itens do ox_inventory, achatados para a busca da NUI.
---
--- Montado UMA vez e reaproveitado: sao centenas de entradas, e serializar
--- isso a cada abertura do painel seria desperdicio puro.
---@type table[]?
local itemCatalog

local function buildItemCatalog()
    if itemCatalog then return itemCatalog end

    itemCatalog = {}

    local ok, items = pcall(function() return exports.ox_inventory:Items() end)

    if not ok or type(items) ~= 'table' then
        lib.print.warn('Nao foi possivel ler os itens do ox_inventory.')
        return itemCatalog
    end

    for name, item in pairs(items) do
        itemCatalog[#itemCatalog + 1] = {
            name  = name,
            label = item.label or name,
            -- Arma e municao aparecem marcadas: dar uma arma sem querer,
            -- procurando por outra coisa, e um acidente caro.
            weapon = name:find('^WEAPON_') ~= nil,
            ammo   = name:find('^ammo%-') ~= nil
        }
    end

    table.sort(itemCatalog, function(a, b) return a.label < b.label end)

    return itemCatalog
end

--- Veiculos do catalogo do ox_core.
---@type table[]?
local vehicleCatalog

local function buildVehicleCatalog()
    if vehicleCatalog then return vehicleCatalog end

    vehicleCatalog = {}

    local file = LoadResourceFile('ox_core', 'common/data/vehicles.json')
    local ok, decoded = pcall(json.decode, file or '')

    if not ok or type(decoded) ~= 'table' then
        lib.print.warn('Nao foi possivel ler common/data/vehicles.json do ox_core.')
        return vehicleCatalog
    end

    for model, entry in pairs(decoded) do
        local make = entry.make ~= '' and entry.make or nil

        vehicleCatalog[#vehicleCatalog + 1] = {
            name  = model,
            label = make and ('%s %s'):format(make, entry.name or model) or (entry.name or model)
        }
    end

    table.sort(vehicleCatalog, function(a, b) return a.label < b.label end)

    return vehicleCatalog
end

-- --------------------------------------------------------------- abrir ----

lib.callback.register('nv_adminmenu:panel:open', function(source)
    if not panelIsAdmin(source) then return end

    local players = {}

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)

        if src then
            local player = Ox.GetPlayer(src)
            local name = GetPlayerName(src) or '?'

            players[#players + 1] = {
                id      = src,
                name    = name,
                -- Nome do personagem quando houver: numa cidade, o nome da
                -- conta nao diz quem e a pessoa em jogo.
                char    = player and Player(src).state.name or nil,
                isSelf  = src == source
            }
        end
    end

    table.sort(players, function(a, b) return a.id < b.id end)

    return {
        players  = players,
        items    = buildItemCatalog(),
        vehicles = buildVehicleCatalog()
    }
end)

-- ----------------------------------------------------------- dar item ----

RegisterNetEvent('nv_adminmenu:panel:giveItem', function(targetId, itemName, count)
    local src = source

    if not panelIsAdmin(src) then return end

    targetId = tonumber(targetId)
    count = math.floor(tonumber(count) or 0)

    if type(itemName) ~= 'string' or not targetId then return end

    if count < 1 or count > 1000 then
        return notify(src, 'Quantidade invalida (1 a 1000).', 'error')
    end

    if not GetPlayerName(targetId) then
        return notify(src, 'Jogador nao esta online.', 'error')
    end

    -- O item precisa existir: `AddItem` com nome errado falha em silencio, e o
    -- admin ficaria achando que deu.
    local ok, item = pcall(function() return exports.ox_inventory:Items(itemName) end)

    if not ok or not item then
        return notify(src, ('Item desconhecido: %s'):format(itemName), 'error')
    end

    if not exports.ox_inventory:CanCarryItem(targetId, itemName, count) then
        return notify(src, 'O jogador nao tem espaco para isso.', 'error')
    end

    if not exports.ox_inventory:AddItem(targetId, itemName, count) then
        return notify(src, 'Nao foi possivel entregar o item.', 'error')
    end

    print(('[nv_adminmenu] %s (id %s) deu %dx %s para %s (id %s).')
        :format(GetPlayerName(src) or '?', src, count, itemName, GetPlayerName(targetId) or '?', targetId))

    notify(src, ('%dx %s entregue a %s.'):format(count, item.label or itemName, GetPlayerName(targetId)), 'success')

    if targetId ~= src then
        notify(targetId, ('Voce recebeu %dx %s.'):format(count, item.label or itemName), 'success')
    end
end)

-- ------------------------------------------------------ acoes em jogador --

--- Acoes que o servidor apenas repassa ao cliente do alvo.
local relayActions = {
    revive   = 'nv_adminmenu:client:revive',
    heal     = 'nv_adminmenu:panel:client:heal',
    armour   = 'nv_adminmenu:panel:client:armour',
    pedmenu  = 'nv_adminmenu:client:openPedMenu'
}

RegisterNetEvent('nv_adminmenu:panel:playerAction', function(action, targetId)
    local src = source

    if not panelIsAdmin(src) then return end

    targetId = tonumber(targetId)

    if type(action) ~= 'string' or not targetId or not GetPlayerName(targetId) then return end

    local event = relayActions[action]

    if event then
        TriggerClientEvent(event, targetId)

        return notify(src, ('Acao "%s" enviada.'):format(action), 'success')
    end

    if action == 'bring' then
        local coords = GetEntityCoords(GetPlayerPed(src))

        TriggerClientEvent('nv_adminmenu:client:teleport', targetId, coords)

        return notify(src, 'Jogador trazido ate voce.', 'success')
    end

    if action == 'goto' then
        local coords = GetEntityCoords(GetPlayerPed(targetId))

        TriggerClientEvent('nv_adminmenu:client:teleport', src, coords)

        return notify(src, 'Voce foi ate o jogador.', 'success')
    end

    if action == 'kill' then
        TriggerClientEvent('nv_adminmenu:panel:client:kill', targetId)

        print(('[nv_adminmenu] %s (id %s) matou %s (id %s).')
            :format(GetPlayerName(src) or '?', src, GetPlayerName(targetId) or '?', targetId))

        return notify(src, 'Jogador morto.', 'success')
    end

    if action == 'admin' then
        local target = Ox.GetPlayer(targetId)

        if not target then return notify(src, 'Personagem nao carregado.', 'error') end

        ExecuteCommand(('setgroup %d admin 1'):format(targetId))

        for _, id in ipairs(GetPlayerIdentifiers(targetId)) do
            if id:sub(1, 8) == 'license:' then
                ExecuteCommand(('add_principal identifier.%s group.admin'):format(id))
                break
            end
        end

        print(('[nv_adminmenu] %s (id %s) promoveu %s (id %s) a admin.')
            :format(GetPlayerName(src) or '?', src, GetPlayerName(targetId) or '?', targetId))

        notify(targetId, 'Voce foi promovido a administrador.', 'inform')

        return notify(src, 'Jogador promovido a admin.', 'success')
    end
end)

-- ---------------------------------------------------------- dar veiculo --
--
-- Nao ha handler de veiculo aqui de proposito. O painel dispara direto o
-- `nv_adminmenu:server:giveVehicle`, que ja existe e ja resolve garagem mais
-- proxima, log e avisos.
--
-- Um repasse server-side nao funcionaria: aquele handler le `source` para
-- saber quem pediu, e num TriggerEvent local `source` vem vazio -- a checagem
-- de admin recusaria a propria chamada.

-- ---------------------------------------------------------------- mundo --

RegisterNetEvent('nv_adminmenu:panel:world', function(kind, value)
    local src = source

    if not panelIsAdmin(src) then return end

    if kind == 'weather' and type(value) == 'string' then
        TriggerClientEvent('nv_adminmenu:panel:client:weather', -1, value)

        return notify(src, ('Clima alterado para %s.'):format(value), 'success')
    end

    if kind == 'time' then
        local hour = math.floor(tonumber(value) or -1)

        if hour < 0 or hour > 23 then return end

        TriggerClientEvent('nv_adminmenu:panel:client:time', -1, hour)

        return notify(src, ('Hora ajustada para %02d:00.'):format(hour), 'success')
    end
end)
