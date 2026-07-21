local Ox = require '@ox_core.lib.init'
local projects = {}
local crafting = {}
local outputs = {}
local nextOutputId = 0
local databaseReady = false

for i = 1, #Config.Projects do
    local project = Config.Projects[i]
    assert(type(project.id) == 'string' and not projects[project.id], ('Projeto duplicado/invalido: %s'):format(project.id or i))
    projects[project.id] = project
    project.staticRecipes = project.recipes or {}
    outputs[project.id] = {}
end

local function decode(value, fallback)
    if type(value) ~= 'string' then return fallback end
    local ok, data = pcall(json.decode, value)
    return ok and type(data) == 'table' and data or fallback
end

local function reloadRecipes()
    for _, project in pairs(projects) do
        project.recipes = {}
        for i = 1, #project.staticRecipes do project.recipes[i] = project.staticRecipes[i] end
    end
    local rows = MySQL.query.await('SELECT * FROM `nv_crafting_recipes` ORDER BY `id`') or {}
    for i = 1, #rows do
        local row, project = rows[i], projects[rows[i].projectId]
        if project and not project.dynamic and project.access and project.access.set == row.orgSet then
            project.recipes[#project.recipes + 1] = {
                id = ('db:%d'):format(row.id), dbId = row.id, item = row.item,
                label = row.label, description = row.description,
                count = row.count, duration = row.duration,
                ingredients = decode(row.ingredients, {}), tools = decode(row.tools, {})
            }
        end
    end
end

local function loadDynamicProjects()
    local rows=MySQL.query.await([[SELECT p.*,g.`type` AS `orgType`,s.`subtype` FROM `nv_crafting_projects` p
        LEFT JOIN `ox_groups` g ON g.`name`=p.`orgSet`
        LEFT JOIN `nv_org_subtype` s ON s.`group`=p.`orgSet`]]) or {}
    for _,row in ipairs(rows) do
        local id='org:'..row.orgSet
        local configured=Config.RecipesByType or {}
        local recipes=configured[row.subtype] or configured[row.orgType] or configured.default or {}
        projects[id]={id=id,label=row.label or 'Bancada da organizacao',subtitle='',coords=vec3(row.x,row.y,row.z),heading=row.heading or 0.0,
            access={set=row.orgSet,minGrade=0,permission='craft'},prop={enabled=row.prop==1 or row.prop==true,model=row.propModel or 'prop_tool_box_04'},
            staticRecipes=recipes,recipes=recipes,dynamic=true,recipeType=row.subtype or row.orgType}
        outputs[id]=outputs[id] or {}
    end
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nv_crafting_projects` (
        `orgSet` VARCHAR(20) NOT NULL,`label` VARCHAR(80) NOT NULL,`x` DOUBLE NOT NULL,`y` DOUBLE NOT NULL,`z` DOUBLE NOT NULL,
        `heading` FLOAT NOT NULL DEFAULT 0,`prop` TINYINT(1) NOT NULL DEFAULT 0,`propModel` VARCHAR(80) NULL,
        PRIMARY KEY (`orgSet`))]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nv_crafting_recipes` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `projectId` VARCHAR(50) NOT NULL,
        `orgSet` VARCHAR(20) NOT NULL,
        `item` VARCHAR(60) NOT NULL,
        `label` VARCHAR(80) NOT NULL,
        `description` VARCHAR(255) NULL,
        `count` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
        `duration` INT UNSIGNED NOT NULL DEFAULT 3000,
        `ingredients` LONGTEXT NOT NULL,
        `tools` LONGTEXT NOT NULL,
        PRIMARY KEY (`id`), KEY `nv_crafting_recipe_org` (`orgSet`, `projectId`)
    )]])
    loadDynamicProjects();reloadRecipes()
    databaseReady = true
end)

lib.callback.register('nv_crafting:projects',function()
    while not databaseReady do Wait(50) end
    local list={};for _,p in pairs(projects) do list[#list+1]={id=p.id,label=p.label,subtitle=p.subtitle,coords=p.coords,heading=p.heading,public=p.public==true,access=p.access,prop=p.prop,marker=p.marker} end
    return list
end)

RegisterNetEvent('nv_crafting:reloadProjects',function()
    if not databaseReady then return end
    for id,p in pairs(projects) do if id:sub(1,4)=='org:' then projects[id]=nil end end
    loadDynamicProjects();reloadRecipes();TriggerClientEvent('nv_crafting:refreshProjects',-1)
end)

local function editableProjects(set)
    local list = {}
    for id, project in pairs(projects) do
        if not project.public and project.access and project.access.set == set then
            list[#list + 1] = { id = id, label = project.label }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

exports('GetEditableProjects', editableProjects)

exports('GetOrgRecipes', function(set)
    while not databaseReady do Wait(50) end
    local rows = MySQL.query.await([[SELECT `id`, `projectId`, `item`, `label`, `description`,
        `count`, `duration`, `ingredients`, `tools` FROM `nv_crafting_recipes`
        WHERE `orgSet`=? ORDER BY `label`]], { set }) or {}
    for i = 1, #rows do
        rows[i].ingredients = decode(rows[i].ingredients, {})
        rows[i].tools = decode(rows[i].tools, {})
    end
    return rows
end)

local function cleanMap(value, tool)
    local clean, seen = {}, 0
    if type(value) ~= 'table' then return clean end
    for name, amount in pairs(value) do
        local item = type(name) == 'string' and exports.ox_inventory:Items(name)
        amount = tonumber(amount)
        if item and amount and amount > 0 and seen < 30 then
            clean[name] = tool and math.min(100, math.max(0.1, amount)) or math.min(10000, math.floor(amount))
            seen = seen + 1
        end
    end
    return clean
end

exports('SaveOrgRecipe', function(set, data)
    while not databaseReady do Wait(50) end
    if type(data) ~= 'table' or type(data.projectId) ~= 'string' then return false, 'Dados invalidos.' end
    local project = projects[data.projectId]
    if not project or not project.access or project.access.set ~= set then return false, 'Ponto nao pertence a oficina.' end
    local resultItem = type(data.item) == 'string' and exports.ox_inventory:Items(data.item)
    if not resultItem then return false, 'Item de resultado invalido.' end
    local ingredients, tools = cleanMap(data.ingredients, false), cleanMap(data.tools, true)
    if not next(ingredients) then return false, 'Selecione ao menos um material.' end
    for name in pairs(tools) do
        if ingredients[name] then return false, 'Um item nao pode ser material e ferramenta ao mesmo tempo.' end
    end
    local count = math.min(100, math.max(1, math.floor(tonumber(data.count) or 1)))
    local duration = math.min(600000, math.max(500, math.floor(tonumber(data.duration) or 3000)))
    local label = type(data.label) == 'string' and data.label:sub(1, 80) or resultItem.label or data.item
    local description = type(data.description) == 'string' and data.description:sub(1, 255) or nil
    local id = tonumber(data.id)
    if id then
        local changed = MySQL.update.await([[UPDATE `nv_crafting_recipes` SET `projectId`=?, `item`=?,
            `label`=?, `description`=?, `count`=?, `duration`=?, `ingredients`=?, `tools`=?
            WHERE `id`=? AND `orgSet`=?]], { data.projectId, data.item, label, description, count,
            duration, json.encode(ingredients), json.encode(tools), id, set })
        if not changed or changed < 1 then return false, 'Receita nao encontrada.' end
    else
        id = MySQL.insert.await([[INSERT INTO `nv_crafting_recipes`
            (`projectId`,`orgSet`,`item`,`label`,`description`,`count`,`duration`,`ingredients`,`tools`)
            VALUES (?,?,?,?,?,?,?,?,?)]], { data.projectId, set, data.item, label, description, count,
            duration, json.encode(ingredients), json.encode(tools) })
    end
    reloadRecipes()
    return true, nil, id
end)

exports('DeleteOrgRecipe', function(set, id)
    while not databaseReady do Wait(50) end
    local changed = MySQL.update.await('DELETE FROM `nv_crafting_recipes` WHERE `id`=? AND `orgSet`=?', { tonumber(id), set })
    if not changed or changed < 1 then return false, 'Receita nao encontrada.' end
    reloadRecipes()
    return true
end)

local function outputsPayload(projectId)
    local list = {}
    local queue = outputs[projectId] or {}
    for i = 1, #queue do
        local entry = queue[i]
        list[i] = {
            id = entry.id, item = entry.item, label = entry.label,
            description = entry.description, count = entry.count,
            createdAt = entry.createdAt
        }
    end
    return list
end

local function getAccess(source, project)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'Personagem nao carregado.' end
    if project.public then return true, nil, player end

    local access = project.access
    if not access or type(access.set) ~= 'string' then return false, 'Acesso da bancada nao configurado.' end
    local groups = player.getGroups and player.getGroups() or {}
    local grade = groups and groups[access.set]
    if grade == nil or grade < (access.minGrade or 0) then return false, 'Seu cargo nao acessa esta bancada.' end

    if access.permission then
        local permission = ('group.%s.%s'):format(access.set, access.permission)
        if not player.hasPermission or not player.hasPermission(permission) then
            return false, 'Seu cargo nao possui permissao para fabricar.'
        end
    end
    return true, nil, player
end

local function nearby(source, project)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - project.coords) <= Config.ServerDistance
end

local function inventoryPayload(source)
    local slots = exports.ox_inventory:GetInventoryItems(source) or {}
    local merged = {}
    for _, slot in pairs(slots) do
        if slot and slot.name and slot.count and slot.count > 0 then
            local row = merged[slot.name]
            if row then row.count = row.count + slot.count else
                local definition = exports.ox_inventory:Items(slot.name) or {}
                merged[slot.name] = {
                    name = slot.name, label = slot.label or definition.label or slot.name,
                    count = slot.count, description = definition.description,
                    hasDurability = slot.metadata and slot.metadata.durability ~= nil or false
                }
            end
            if slot.metadata and slot.metadata.durability ~= nil then merged[slot.name].hasDurability = true end
        end
    end
    local list = {}
    for _, item in pairs(merged) do list[#list + 1] = item end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function recipesPayload(project)
    local list = {}
    for i = 1, #project.recipes do
        local recipe = project.recipes[i]
        local result = exports.ox_inventory:Items(recipe.item)
        if result then
            local ingredients = {}
            for name, count in pairs(recipe.ingredients or {}) do
                local item = exports.ox_inventory:Items(name)
                if item then ingredients[#ingredients + 1] = { name = name, label = item.label or name, count = count } end
            end
            for name, wear in pairs(recipe.tools or {}) do
                local item = exports.ox_inventory:Items(name)
                if item then ingredients[#ingredients + 1] = {
                    name = name, label = item.label or name, count = 1,
                    tool = true, wear = wear
                } end
            end
            table.sort(ingredients, function(a, b) return a.label < b.label end)
            list[#list + 1] = {
                id = recipe.id or tostring(i), item = recipe.item,
                label = recipe.label or result.label or recipe.item,
                description = recipe.description or result.description,
                count = recipe.count or 1, duration = recipe.duration or 3000,
                ingredients = ingredients,
                layout = recipe.layout
            }
        else
            lib.print.warn(('Item resultado "%s" do projeto "%s" nao existe.'):format(recipe.item, project.id))
        end
    end
    return list
end

lib.callback.register('nv_crafting:open', function(source, projectId)
    local project = projects[projectId]
    if not project or not nearby(source, project) then return nil, 'Voce esta longe da bancada.' end
    local allowed, err = getAccess(source, project)
    if not allowed then return nil, err end
    return {
        project = { id = project.id, label = project.label, subtitle = project.subtitle },
        recipes = recipesPayload(project), inventory = inventoryPayload(source),
        outputs = outputsPayload(project.id), maxQuantity = Config.MaxCraftQuantity
    }
end)

lib.callback.register('nv_crafting:craft', function(source, projectId, recipeId, requestedQuantity)
    if crafting[source] then return false, 'Voce ja esta fabricando.' end
    local project = projects[projectId]
    if not project or not nearby(source, project) then return false, 'Voce se afastou da bancada.' end
    local allowed, err = getAccess(source, project)
    if not allowed then return false, err end

    local recipe
    for i = 1, #(project.recipes or {}) do
        local candidate = project.recipes[i]
        if (candidate.id or tostring(i)) == recipeId then recipe = candidate break end
    end
    if not recipe then return false, 'Receita invalida.' end
    local quantity = math.floor(tonumber(requestedQuantity) or 1)
    if quantity < 1 or quantity > Config.MaxCraftQuantity then
        return false, 'Quantidade de fabricacao invalida.'
    end
    local output = math.max(1, math.floor(tonumber(recipe.count) or 1)) * quantity

    local toolUsage = {}
    local inventoryItems = exports.ox_inventory:GetInventoryItems(source) or {}
    for name, wear in pairs(recipe.tools or {}) do
        local durableSlot, durableValue
        for _, slot in pairs(inventoryItems) do
            if slot.name == name and slot.metadata and slot.metadata.durability then
                local value = slot.metadata.durability
                if value > 100 then
                    local definition = exports.ox_inventory:Items(name)
                    local degrade = (slot.metadata.degrade or definition.degrade or 1) * 60
                    value = math.max(0, ((value - os.time()) * 100) / degrade)
                end
                if not durableValue or value > durableValue then durableSlot, durableValue = slot.slot, value end
            end
        end
        local totalWear = tonumber(wear) * quantity
        if durableSlot then
            if durableValue < totalWear then return false, ('Durabilidade insuficiente: %s.'):format(name) end
            toolUsage[#toolUsage + 1] = { name = name, slot = durableSlot, durability = durableValue - totalWear }
        else
            if exports.ox_inventory:GetItemCount(source, name) < quantity then
                return false, ('Ferramenta insuficiente: %s.'):format(name)
            end
            toolUsage[#toolUsage + 1] = { name = name, consume = quantity }
        end
    end
    for name, baseCount in pairs(recipe.ingredients or {}) do
        local count = baseCount * quantity
        if exports.ox_inventory:GetItemCount(source, name) < count then
            local item = exports.ox_inventory:Items(name)
            return false, ('Material insuficiente: %s.'):format(item and item.label or name)
        end
    end

    crafting[source] = true
    local completed = lib.callback.await('nv_crafting:progress', source,
        (recipe.duration or 3000) * quantity, recipe.label or recipe.item)
    if not completed or not nearby(source, project) then crafting[source] = nil return false, 'Fabricacao cancelada.' end
    allowed, err = getAccess(source, project)
    if not allowed then crafting[source] = nil return false, err end

    -- Revalida imediatamente antes de consumir. Em caso de falha parcial, os
    -- materiais ja retirados sao devolvidos.
    local removed = {}
    for name, baseCount in pairs(recipe.ingredients or {}) do
        local count = baseCount * quantity
        if exports.ox_inventory:GetItemCount(source, name) < count then
            for n, qty in pairs(removed) do exports.ox_inventory:AddItem(source, n, qty) end
            crafting[source] = nil
            return false, 'Os materiais mudaram durante a fabricacao.'
        end
        if not exports.ox_inventory:RemoveItem(source, name, count) then
            for n, qty in pairs(removed) do exports.ox_inventory:AddItem(source, n, qty) end
            crafting[source] = nil
            return false, 'Nao foi possivel consumir os materiais.'
        end
        removed[name] = count
    end

    for i = 1, #toolUsage do
        local tool = toolUsage[i]
        if tool.slot then
            exports.ox_inventory:SetDurability(source, tool.slot, math.max(0, tool.durability))
        elseif not exports.ox_inventory:RemoveItem(source, tool.name, tool.consume) then
            for name, count in pairs(removed) do exports.ox_inventory:AddItem(source, name, count) end
            crafting[source] = nil
            return false, 'Nao foi possivel consumir uma ferramenta.'
        end
    end

    local definition = exports.ox_inventory:Items(recipe.item) or {}
    local queue = outputs[project.id]
    -- Cada unidade vira uma entrada propria. Itens iguais nunca sao agrupados.
    for i = 1, output do
        nextOutputId = nextOutputId + 1
        queue[#queue + 1] = {
            id = nextOutputId, item = recipe.item,
            label = recipe.label or definition.label or recipe.item,
            description = recipe.description or definition.description,
            count = 1, metadata = recipe.metadata,
            createdAt = os.date('%H:%M')
        }
    end

    crafting[source] = nil
    return true, { inventory = inventoryPayload(source), outputs = outputsPayload(project.id) }
end)

local function validateBench(source, projectId)
    local project = projects[projectId]
    if not project or not nearby(source, project) then return nil, 'Voce esta longe da bancada.' end
    local allowed, err = getAccess(source, project)
    if not allowed then return nil, err end
    return project
end

lib.callback.register('nv_crafting:takeOutput', function(source, projectId, outputId)
    local project, err = validateBench(source, projectId)
    if not project then return false, err end
    local queue = outputs[projectId]
    local index, entry
    for i = 1, #queue do
        if queue[i].id == tonumber(outputId) then index, entry = i, queue[i] break end
    end
    if not entry then return false, 'Esse item ja foi retirado.' end
    if not exports.ox_inventory:CanCarryItem(source, entry.item, entry.count, entry.metadata) then
        return false, 'Sem espaco no inventario.'
    end
    local success = exports.ox_inventory:AddItem(source, entry.item, entry.count, entry.metadata)
    if not success then return false, 'Nao foi possivel retirar o item.' end
    table.remove(queue, index)
    return true, { inventory = inventoryPayload(source), outputs = outputsPayload(projectId) }
end)

lib.callback.register('nv_crafting:getOutputs', function(source, projectId)
    local project, err = validateBench(source, projectId)
    if not project then return false, err end
    return true, outputsPayload(projectId)
end)

lib.callback.register('nv_crafting:takeAllOutputs', function(source, projectId)
    local project, err = validateBench(source, projectId)
    if not project then return false, err end
    local queue = outputs[projectId]
    if #queue == 0 then return false, 'Nao ha itens prontos.' end

    local taken = 0
    -- Remove de tras para frente e preserva na bancada o que nao couber.
    for i = #queue, 1, -1 do
        local entry = queue[i]
        if exports.ox_inventory:CanCarryItem(source, entry.item, entry.count, entry.metadata) then
            local success = exports.ox_inventory:AddItem(source, entry.item, entry.count, entry.metadata)
            if success then
                table.remove(queue, i)
                taken = taken + 1
            end
        end
    end
    if taken == 0 then return false, 'Sem espaco para retirar os itens.' end
    return true, { inventory = inventoryPayload(source), outputs = outputsPayload(projectId), taken = taken }
end)

AddEventHandler('playerDropped', function() crafting[source] = nil end)
