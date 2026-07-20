--[[
    nv_shops — servidor

    Regra da casa: a NUI e uma VITRINE. Ela nao sabe preco, nao sabe estoque e
    nao decide nada. Tudo que vale dinheiro -- preco, estoque, caixa, entrega --
    e lido do Config aqui dentro, a partir do id da loja e do nome do item.

    O cliente pode dizer O QUE quer comprar. Nunca quanto custa.
]]

local Ox = require '@ox_core.lib.init'

-- [shopId] = { cash = n, stock = { [item] = n } }
local shops = {}

local schemaReady = false

-- ---------------------------------------------------------------- catalogo --

--- Indice item -> definicao, por tipo de loja. Evita varrer a lista inteira a
--- cada compra.
---@type table<string, table<string, table>>
local catalogIndex = {}

for shopType, entries in pairs(Config.Catalog) do
    catalogIndex[shopType] = {}

    for i = 1, #entries do
        catalogIndex[shopType][entries[i].name] = entries[i]
    end
end

---@type table<number, table>
local shopById = {}

for i = 1, #Config.Shops do
    shopById[Config.Shops[i].id] = Config.Shops[i]
end

--- Definicao de um item PARA AQUELA LOJA.
---
--- Vale a checagem de `hunting`: sem ela, um cliente adulterado pediria rifle
--- de caca num Ammu-Nation do centro, onde a aba nem aparece.
---@param shop table
---@param itemName string
---@return table?
local function catalogEntry(shop, itemName)
    local entry = catalogIndex[shop.type] and catalogIndex[shop.type][itemName]
    if not entry then return end

    local category = nil

    for _, cat in ipairs(Config.Categories[shop.type] or {}) do
        if cat.id == entry.category then category = cat break end
    end

    if category and category.hunting and not shop.hunting then return end

    return entry
end

-- ------------------------------------------------------------------ schema --

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end

    local ok = pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_shops` (
            `id`    INT PRIMARY KEY,
            `type`  VARCHAR(20) NOT NULL,
            `label` VARCHAR(80) NOT NULL,
            `cash`  INT NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local okStock = pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_shop_stock` (
            `shop_id`   INT NOT NULL,
            `item`      VARCHAR(50) NOT NULL,
            `stock`     INT NOT NULL DEFAULT 0,
            `max_stock` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`shop_id`, `item`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    if not ok or not okStock then
        return lib.print.error('Nao foi possivel criar as tabelas do nv_shops. As lojas nao vao abrir.')
    end

    schemaReady = true

    -- Semeia loja e estoque. `INSERT IGNORE` deixa isto idempotente: rodar de
    -- novo depois de adicionar uma loja no config so cria a que faltava, sem
    -- zerar o caixa das que ja existem.
    for i = 1, #Config.Shops do
        local shop = Config.Shops[i]

        MySQL.query.await('INSERT IGNORE INTO `nv_shops` (`id`, `type`, `label`, `cash`) VALUES (?, ?, ?, ?)',
            { shop.id, shop.type, shop.label, 0 })

        for _, entry in ipairs(Config.Catalog[shop.type] or {}) do
            MySQL.query.await(
                'INSERT IGNORE INTO `nv_shop_stock` (`shop_id`, `item`, `stock`, `max_stock`) VALUES (?, ?, ?, ?)',
                { shop.id, entry.name, entry.stock, entry.stock })
        end
    end

    -- Carrega tudo para a memoria: uma compra nao pode esperar duas queries.
    local rows = MySQL.query.await('SELECT `id`, `cash` FROM `nv_shops`') or {}

    for _, row in ipairs(rows) do
        shops[row.id] = { cash = row.cash, stock = {} }
    end

    local stockRows = MySQL.query.await('SELECT `shop_id`, `item`, `stock`, `max_stock` FROM `nv_shop_stock`') or {}

    for _, row in ipairs(stockRows) do
        local shop = shops[row.shop_id]

        if shop then
            shop.stock[row.item] = { stock = row.stock, max = row.max_stock }
        end
    end

    lib.print.info(('nv_shops pronto: %d lojas carregadas.'):format(#Config.Shops))
end)

-- ------------------------------------------------------------- persistencia --

local function saveStock(shopId, item, value)
    MySQL.prepare('UPDATE `nv_shop_stock` SET `stock` = ? WHERE `shop_id` = ? AND `item` = ?',
        { value, shopId, item })
end

local function saveCash(shopId, value)
    MySQL.prepare('UPDATE `nv_shops` SET `cash` = ? WHERE `id` = ?', { value, shopId })
end

-- ------------------------------------------------------------------ vitrine --

lib.callback.register('nv_shops:open', function(source, shopId)
    if not schemaReady then return end

    local shop = shopById[shopId]
    local data = shops[shopId]

    if not shop or not data then return end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - shop.coords) > Config.MaxDistance + 2.0 then return end

    -- Categorias visiveis nesta loja. A aba de caca some onde nao ha caca.
    local categories = {}

    for _, cat in ipairs(Config.Categories[shop.type] or {}) do
        if not cat.hunting or shop.hunting then
            categories[#categories + 1] = { id = cat.id, label = cat.label, icon = cat.icon }
        end
    end

    local products = {}

    for _, entry in ipairs(Config.Catalog[shop.type] or {}) do
        if catalogEntry(shop, entry.name) then
            local stock = data.stock[entry.name]

            products[#products + 1] = {
                name     = entry.name,
                label    = entry.label,
                price    = entry.price,
                category = entry.category,
                stock    = stock and stock.stock or 0
            }
        end
    end

    return {
        id         = shop.id,
        label      = shop.label,
        type       = shop.type,
        categories = categories,
        products   = products,
        money      = exports.ox_inventory:GetItemCount(source, Config.MoneyItem) or 0
    }
end)

-- ------------------------------------------------------------------- compra --

--- Compra. `cart` = { { name = string, qty = number }, ... }
---
--- A ordem das etapas nao e arbitraria: conferimos TUDO antes de mexer em
--- qualquer coisa. Tirar o dinheiro e so entao descobrir que o inventario
--- estava cheio deixaria o jogador sem dinheiro e sem item.
lib.callback.register('nv_shops:buy', function(source, shopId, cart)
    if not schemaReady then return false, 'Loja indisponivel.' end
    if type(cart) ~= 'table' or #cart == 0 then return false, 'Carrinho vazio.' end

    local shop = shopById[shopId]
    local data = shops[shopId]

    if not shop or not data then return false, 'Loja invalida.' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'Jogador invalido.' end

    if #(GetEntityCoords(ped) - shop.coords) > Config.MaxDistance then
        return false, 'Voce se afastou do balcao.'
    end

    local player = Ox.GetPlayer(source)
    if not player then return false, 'Personagem nao carregado.' end

    -- ------------------------------------------------ 1. valida o carrinho --
    local total = 0
    local lines = {}

    for i = 1, #cart do
        local line = cart[i]

        if type(line) ~= 'table' or type(line.name) ~= 'string' then
            return false, 'Carrinho invalido.'
        end

        local qty = math.floor(tonumber(line.qty) or 0)

        if qty < 1 or qty > Config.MaxCartQuantity then
            return false, 'Quantidade invalida.'
        end

        local entry = catalogEntry(shop, line.name)
        if not entry then return false, 'Esta loja nao vende esse item.' end

        local stock = data.stock[entry.name]

        if not stock or stock.stock < qty then
            return false, ('Sem estoque: %s.'):format(entry.label)
        end

        if entry.license then
            local licenses = player.getLicenses and player.getLicenses() or nil

            if licenses and not licenses[entry.license] then
                return false, ('Voce precisa da licenca "%s" para comprar %s.')
                    :format(entry.license, entry.label)
            end
        end

        -- O PRECO vem do config, nunca do carrinho recebido.
        total = total + entry.price * qty

        lines[#lines + 1] = { entry = entry, qty = qty }
    end

    -- --------------------------------------------- 2. dinheiro e mochila --
    -- Somente dinheiro vivo. Nao ha ramo de cartao aqui de proposito.
    if (exports.ox_inventory:GetItemCount(source, Config.MoneyItem) or 0) < total then
        return false, ('Dinheiro insuficiente. Total: $%d.'):format(total)
    end

    for i = 1, #lines do
        local line = lines[i]

        if not exports.ox_inventory:CanCarryItem(source, line.entry.name, line.qty) then
            return false, ('Sem espaco para levar %s.'):format(line.entry.label)
        end
    end

    -- ------------------------------------------------------ 3. efetiva --
    if not exports.ox_inventory:RemoveItem(source, Config.MoneyItem, total) then
        return false, 'Nao foi possivel cobrar a compra.'
    end

    local receipt = {}

    for i = 1, #lines do
        local line = lines[i]
        local entry = line.entry

        exports.ox_inventory:AddItem(source, entry.name, line.qty, entry.metadata)

        local stock = data.stock[entry.name]
        stock.stock = stock.stock - line.qty

        saveStock(shopId, entry.name, stock.stock)

        receipt[#receipt + 1] = ('%dx %s'):format(line.qty, entry.label)
    end

    data.cash = data.cash + total
    saveCash(shopId, data.cash)

    -- -------------------------------------------------- 4. nota fiscal --
    if Config.ReceiptItem and exports.ox_inventory:CanCarryItem(source, Config.ReceiptItem, 1) then
        exports.ox_inventory:AddItem(source, Config.ReceiptItem, 1, {
            loja  = shop.label,
            total = total,
            itens = table.concat(receipt, ', '),
            data  = os.date('%d/%m/%Y %H:%M'),
            description = ('%s\nTotal: $%d\n%s'):format(shop.label, total, table.concat(receipt, ', '))
        })
    end

    return true, nil, total
end)

-- ------------------------------------------------------- fila de reposicao --

--- Lojas que precisam de reposicao: sem algum item OU com o estoque total
--- abaixo do percentual configurado.
---@return table[] lista de { id, label, empty, percent }
function GetRestockQueue()
    local queue = {}

    for id, data in pairs(shops) do
        local shop = shopById[id]

        if shop then
            local current, max, empty = 0, 0, 0

            for _, stock in pairs(data.stock) do
                current = current + stock.stock
                max = max + stock.max

                if stock.stock <= 0 then empty = empty + 1 end
            end

            local percent = max > 0 and (current / max * 100) or 100

            if empty > 0 or percent < Config.Restock.lowStockPercent then
                queue[#queue + 1] = {
                    id      = id,
                    label   = shop.label,
                    empty   = empty,
                    percent = math.floor(percent + 0.5)
                }
            end
        end
    end

    return queue
end

exports('GetRestockQueue', GetRestockQueue)

--- Esvazia o estoque de algumas lojas, criando a condicao de reposicao.
---
--- Existe para o evento manual do adminmenu: o evento dos postos coloca os
--- postos em nivel critico, e o equivalente aqui e zerar prateleira. Sem isto
--- o admin so conseguiria "avisar" sobre uma fila que talvez nem exista.
---
--- Escolhe as lojas com MAIS estoque: zerar quem ja estava vazio nao mudaria
--- nada e o evento pareceria nao ter funcionado.
---@param count number? quantas lojas esvaziar
---@return number esvaziadas
function DrainShops(count)
    -- Erro em vez de "0 lojas": o resource pode estar no ar com o estoque
    -- ainda vindo do banco, e devolver zero em silencio faria o chamador
    -- concluir que nao ha lojas -- que e uma conclusao diferente e errada.
    if not schemaReady then
        error('nv_shops ainda esta carregando o estoque do banco de dados.', 0)
    end

    count = count or Config.Restock.minStores

    local candidates = {}

    for id, data in pairs(shops) do
        local current = 0

        for _, stock in pairs(data.stock) do
            current = current + stock.stock
        end

        candidates[#candidates + 1] = { id = id, current = current }
    end

    table.sort(candidates, function(a, b) return a.current > b.current end)

    local drained = 0

    for i = 1, math.min(count, #candidates) do
        local data = shops[candidates[i].id]

        for item, stock in pairs(data.stock) do
            if stock.stock > 0 then
                stock.stock = 0
                saveStock(candidates[i].id, item, 0)
            end
        end

        drained = drained + 1
    end

    return drained
end

exports('DrainShops', DrainShops)

--- A conta ja roda; a rota de entrega ainda nao existe.
---
--- Enquanto `Config.Restock.event` for nil isto apenas observa e registra. Foi
--- pedido assim: primeiro a logica de quem precisa de reposicao, depois o
--- evento que manda alguem entregar.
CreateThread(function()
    while not schemaReady do Wait(1000) end

    while true do
        Wait(Config.Restock.interval)

        local queue = GetRestockQueue()

        if #queue >= Config.Restock.minStores then
            if Config.Restock.log then
                local names = {}

                for i = 1, #queue do
                    names[i] = ('%s (%d%%%s)'):format(queue[i].label, queue[i].percent,
                        queue[i].empty > 0 and (', %d item(ns) zerado(s)'):format(queue[i].empty) or '')
                end

                lib.print.info(('Reposicao pendente em %d lojas: %s'):format(#queue, table.concat(names, ' | ')))
            end

            if Config.Restock.event then
                TriggerEvent(Config.Restock.event, queue)
            end
        end
    end
end)

-- ----------------------------------------------------------------- admin --

lib.addCommand('shopstock', {
    help = 'Mostra estoque e caixa de uma loja',
    params = { { name = 'id', type = 'number', help = 'Id da loja' } },
    restricted = 'group.admin'
}, function(source, args)
    local shop = shopById[args.id]
    local data = shops[args.id]

    if not shop or not data then
        return TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Loja nao encontrada.' })
    end

    print(('[nv_shops] %s -- caixa $%d'):format(shop.label, data.cash))

    for item, stock in pairs(data.stock) do
        print(('  %-24s %d/%d'):format(item, stock.stock, stock.max))
    end

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'inform',
        description = ('%s: caixa $%d. Estoque no console.'):format(shop.label, data.cash)
    })
end)

lib.addCommand('shoprestock', {
    help = 'Repoe o estoque de uma loja (ou de todas)',
    params = { { name = 'id', type = 'number', help = 'Id da loja; 0 = todas' } },
    restricted = 'group.admin'
}, function(source, args)
    local targets = {}

    if args.id == 0 then
        for id in pairs(shops) do targets[#targets + 1] = id end
    else
        targets[1] = args.id
    end

    local done = 0

    for _, id in ipairs(targets) do
        local data = shops[id]

        if data then
            for item, stock in pairs(data.stock) do
                stock.stock = stock.max
                saveStock(id, item, stock.stock)
            end

            done = done + 1
        end
    end

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = ('Estoque reposto em %d loja(s).'):format(done)
    })
end)
