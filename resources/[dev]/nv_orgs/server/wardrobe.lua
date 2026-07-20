--[[
    nv_orgs — servidor: vestiario

    Pontos e roupas de trabalho.

    Sobre nao usar o sistema de "job outfits" do illenium-appearance: ele
    existe e e completo (tabela propria, minrank, menus prontos), mas o bridge
    dele para o ox_core esta por fazer -- `Framework.GetJob()` em
    `server/framework/ox/main.lua` e literalmente `return ---@todo`, e o
    `getManagementOutfits` quebra na linha seguinte ao tentar ler
    `job.grade.level` de um nil.

    Preencher aquele bridge daria o sistema pronto, mas seria um patch dentro
    de um resource de terceiro -- some no proximo update dele. Entao guardamos
    a roupa aqui e aplicamos com os exports de baixo nivel do illenium
    (`setPedComponents` / `setPedProps`), que sao estaveis e publicos.
]]

local Ox = require '@ox_core.lib.init'

---@param set string
---@return number
local function gradeCount(set)
    return MySQL.scalar.await(
        'SELECT COUNT(*) FROM `ox_group_grades` WHERE `group` = ?', { set }) or 0
end

-- ------------------------------------------------------ pontos: sync --

---@type table[]
local pointCache = {}

local function loadPoints()
    if not Orgs.schemaReady then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT w.`id`, w.`group`, w.`coords`, w.`minPosition`,
               (SELECT COUNT(*) FROM `ox_group_grades` g WHERE g.`group` = w.`group`) AS total
        FROM `nv_org_wardrobes` w
    ]])

    if not ok or type(rows) ~= 'table' then return {} end

    local result = {}

    for i = 1, #rows do
        local row = rows[i]
        local x, y, z = row.coords:match('^(%S+) (%S+) (%S+)$')

        x, y, z = tonumber(x), tonumber(y), tonumber(z)

        if x and y and z then
            local total = tonumber(row.total) or 0
            local position = math.max(1, math.min(tonumber(row.minPosition) or 1, math.max(total, 1)))

            result[#result + 1] = {
                id       = row.id,
                set      = row.group,
                coords   = { x = x, y = y, z = z },
                -- Mesma conversao dos baus: a posicao e estavel, o grade nao.
                minGrade = total > 0 and Orgs.positionToGrade(position, total) or 255
            }
        end
    end

    return result
end

---@param target number?
function Orgs.syncWardrobes(target)
    pointCache = loadPoints()

    TriggerClientEvent('nv_orgs:wardrobes', target or -1, pointCache)
end

CreateThread(function()
    while not Orgs.schemaReady do Wait(500) end

    Orgs.syncWardrobes()
end)

RegisterNetEvent('nv_orgs:requestWardrobes', function()
    TriggerClientEvent('nv_orgs:wardrobes', source, pointCache)
end)

-- ---------------------------------------------------------- admin: ler --

lib.callback.register('nv_orgs:wardrobe', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' or not Orgs.schemaReady then return end

    local points = MySQL.query.await(
        'SELECT `id`, `coords`, `minPosition` FROM `nv_org_wardrobes` WHERE `group` = ? ORDER BY `id`',
        { set }) or {}

    -- O JSON da roupa nao vai para a tela: sao centenas de bytes por peca e a
    -- NUI nao faz nada com eles.
    local outfits = MySQL.query.await(
        'SELECT `id`, `label`, `model`, `minPosition` FROM `nv_org_outfits` WHERE `group` = ? ORDER BY `label`',
        { set }) or {}

    return { points = points, outfits = outfits }
end)

-- ------------------------------------------------------- admin: pontos --

lib.callback.register('nv_orgs:addWardrobe', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local coords = data.coords

    if type(coords) ~= 'table' or type(coords.x) ~= 'number' then
        return false, 'Coordenada invalida.'
    end

    local total = gradeCount(set)
    if total == 0 then return false, 'Crie os cargos antes do vestiario.' end

    local position = math.max(1, math.min(total, math.floor(tonumber(data.minPosition) or total)))

    MySQL.prepare.await(
        'INSERT INTO `nv_org_wardrobes` (`group`, `coords`, `minPosition`) VALUES (?, ?, ?)',
        { set, ('%.3f %.3f %.3f'):format(coords.x, coords.y, coords.z), position })

    Orgs.syncWardrobes()

    return true
end)

lib.callback.register('nv_orgs:deleteWardrobe', function(source, set, id)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(id) ~= 'number' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_wardrobes` WHERE `id` = ? AND `group` = ?', { id, set })
    Orgs.syncWardrobes()

    return true
end)

-- ------------------------------------------------------- admin: roupas --

--- Salva a roupa que o admin esta vestindo.
---
--- O cliente manda componentes e props ja lidos com os exports do illenium;
--- aqui so validamos a forma e guardamos. Confiar na forma e aceitavel: o pior
--- que um payload torto faz e a roupa nao aplicar para quem escolher.
lib.callback.register('nv_orgs:saveOutfit', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    if type(data.components) ~= 'table' or type(data.props) ~= 'table' then
        return false, 'Nao foi possivel ler a roupa atual.'
    end

    if type(data.model) ~= 'string' or data.model == '' then
        return false, 'Modelo do personagem desconhecido.'
    end

    local total = gradeCount(set)
    if total == 0 then return false, 'Crie os cargos antes do vestiario.' end

    local label = type(data.label) == 'string' and data.label ~= '' and data.label:sub(1, 50)
        or 'Uniforme'

    local position = math.max(1, math.min(total, math.floor(tonumber(data.minPosition) or total)))

    local encoded = json.encode({ components = data.components, props = data.props })

    if data.id then
        MySQL.query.await([[
            UPDATE `nv_org_outfits` SET `label` = ?, `model` = ?, `outfit` = ?, `minPosition` = ?
            WHERE `id` = ? AND `group` = ?
        ]], { label, data.model, encoded, position, data.id, set })
    else
        MySQL.prepare.await([[
            INSERT INTO `nv_org_outfits` (`group`, `label`, `model`, `outfit`, `minPosition`)
            VALUES (?, ?, ?, ?, ?)
        ]], { set, label, data.model, encoded, position })
    end

    return true
end)

lib.callback.register('nv_orgs:deleteOutfit', function(source, set, id)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(id) ~= 'number' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_outfits` WHERE `id` = ? AND `group` = ?', { id, set })

    return true
end)

-- ------------------------------------------------------- uso pelo membro --

--- As roupas que ESTE jogador pode vestir.
---
--- Filtra por duas coisas: o cargo dele e o modelo do corpo. A segunda e a que
--- costuma ser esquecida -- uniforme salvo num corpo feminino aplicado num
--- masculino nao "fica estranho", ele deforma o personagem.
lib.callback.register('nv_orgs:outfitsFor', function(source, set, model)
    if type(set) ~= 'string' or not Orgs.schemaReady then return end

    local player = Ox.GetPlayer(source)
    if not player then return end

    local ok, groups = pcall(function() return player.getGroups() end)
    if not ok or type(groups) ~= 'table' then return end

    local grade = groups[set]
    if not grade then return end

    local total = gradeCount(set)
    if total == 0 then return end

    local position = Orgs.gradeToPosition(grade, total)

    local rows = MySQL.query.await(
        'SELECT `id`, `label`, `model`, `outfit`, `minPosition` FROM `nv_org_outfits` WHERE `group` = ? ORDER BY `label`',
        { set }) or {}

    local result = {}

    for i = 1, #rows do
        local row = rows[i]

        if position <= row.minPosition and (type(model) ~= 'string' or row.model == model) then
            local decoded, outfit = pcall(json.decode, row.outfit)

            if decoded and type(outfit) == 'table' then
                result[#result + 1] = {
                    id     = row.id,
                    label  = row.label,
                    outfit = outfit
                }
            end
        end
    end

    return result
end)
