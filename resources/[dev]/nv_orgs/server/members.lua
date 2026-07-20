--[[
    nv_orgs — servidor: membros

    Contratar, promover e demitir.

    Um detalhe que atravessa o arquivo inteiro: `Ox.GetPlayer` so enxerga quem
    esta ONLINE. Uma organizacao, porem, e feita principalmente de gente
    offline. Entao a fonte de verdade aqui e a tabela `character_groups`, e o
    `player.setGroup` e usado APENAS como atalho para quem esta conectado --
    ele atualiza o statebag e o principal do ACE na hora, coisa que um UPDATE
    no banco nao faria.
]]

local Ox = require '@ox_core.lib.init'

--- Quantos cargos esta organizacao tem.
---@param set string
---@return number
local function gradeCount(set)
    return MySQL.scalar.await(
        'SELECT COUNT(*) FROM `ox_group_grades` WHERE `group` = ?', { set }) or 0
end

--- O jogador online com este charId, se houver.
---@param charId number
---@return table?
local function onlinePlayer(charId)
    local ok, player = pcall(function() return Ox.GetPlayerFromCharId(charId) end)

    if ok then return player end
end

--- Aplica o grade. Banco sempre; memoria tambem, se estiver online.
---
--- Grade 0 no ox_core significa "remover do grupo", e e assim que a demissao
--- acontece -- nao existe um `removeGroup` separado.
---@param charId number
---@param set string
---@param grade number
local function applyGrade(charId, set, grade)
    local player = onlinePlayer(charId)

    if player then
        pcall(function() player.setGroup(set, grade) end)
        return
    end

    if grade == 0 then
        MySQL.query.await('DELETE FROM `character_groups` WHERE `charId` = ? AND `name` = ?',
            { charId, set })

        return
    end

    MySQL.query.await([[
        INSERT INTO `character_groups` (`charId`, `name`, `grade`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `grade` = VALUES(`grade`)
    ]], { charId, set, grade })
end

-- ------------------------------------------------------------ listagem --

--- Membros de uma organizacao, do cargo mais alto para o mais baixo.
lib.callback.register('nv_orgs:members', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' then return end

    local total = gradeCount(set)
    if total == 0 then return {} end

    local rows = MySQL.query.await([[
        SELECT c.`charId`, c.`stateId`, c.`fullName`, cg.`grade`, gg.`label` AS gradeLabel
        FROM `character_groups` cg
        JOIN `characters` c ON c.`charId` = cg.`charId`
        LEFT JOIN `ox_group_grades` gg ON gg.`group` = cg.`name` AND gg.`grade` = cg.`grade`
        WHERE cg.`name` = ?
        ORDER BY cg.`grade` DESC, c.`fullName`
    ]], { set }) or {}

    for i = 1, #rows do
        rows[i].position = Orgs.gradeToPosition(rows[i].grade, total)
        rows[i].online = onlinePlayer(rows[i].charId) ~= nil
    end

    return rows
end)

-- --------------------------------------------------------------- busca --

--- Procura personagens para contratar.
---
--- Exclui quem ja esta na organizacao: aparecer na busca alguem que ja e
--- membro so gera clique perdido.
lib.callback.register('nv_orgs:search', function(source, set, query)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' or type(query) ~= 'string' then return end

    query = query:gsub('^%s+', ''):gsub('%s+$', '')

    -- "#12" e como o ID aparece na maioria das telas de admin; aceitar o
    -- prefixo evita o usuario ter que saber que aqui ele nao vale.
    query = query:gsub('^#', '')

    -- Numero e sempre uma busca por ID, e ID pode ter um digito so. Exigir o
    -- minimo geral aqui fazia "1" nunca chegar ao banco -- que era exatamente
    -- o caso de procurar o proprio personagem pelo charId.
    local asId = tonumber(query)
    local minimum = asId and 1 or Config.Search.minLength

    if #query < minimum then return {} end

    -- LIKE com escape dos curingas: sem isto, digitar "%" listaria o servidor
    -- inteiro.
    local term = '%' .. query:gsub('[%%_\\]', '\\%0') .. '%'

    -- `stateId` e um codigo gerado (VARCHAR(7)), NAO o charId. Procurar so por
    -- ele deixava o ID numerico -- que e o que aparece na maioria das telas de
    -- admin -- sem nenhuma forma de ser encontrado.
    return MySQL.query.await([[
        SELECT c.`charId`, c.`stateId`, c.`fullName`
        FROM `characters` c
        WHERE (c.`fullName` LIKE ? OR c.`stateId` LIKE ? OR c.`charId` = ?)
          AND c.`deleted` IS NULL
          AND c.`charId` NOT IN (SELECT cg.`charId` FROM `character_groups` cg WHERE cg.`name` = ?)
        ORDER BY (c.`charId` = ?) DESC, c.`fullName`
        LIMIT ?
    ]], { term, term, asId or -1, set, asId or -1, Config.Search.limit }) or {}
end)

-- ---------------------------------------------------------- contratar --

lib.callback.register('nv_orgs:hire', function(source, set, charId, position)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(charId) ~= 'number' then return false, 'Dados invalidos.' end

    local total = gradeCount(set)
    if total == 0 then return false, 'Esta organizacao nao tem cargos.' end

    -- Sem posicao informada, entra no cargo mais baixo. E o que se espera de
    -- uma contratacao.
    position = type(position) == 'number' and position or total

    if position < 1 or position > total then return false, 'Cargo invalido.' end

    local character = MySQL.single.await(
        'SELECT `charId`, `fullName` FROM `characters` WHERE `charId` = ? AND `deleted` IS NULL',
        { charId })

    if not character then return false, 'Personagem nao encontrado.' end

    local already = MySQL.scalar.await(
        'SELECT `grade` FROM `character_groups` WHERE `charId` = ? AND `name` = ?',
        { charId, set })

    if already then return false, 'Este personagem ja e membro.' end

    applyGrade(charId, set, Orgs.positionToGrade(position, total))

    return true, nil, character.fullName
end)

-- ------------------------------------------------------------ promover --

--- Move um membro para outro cargo. Serve para subir e para descer.
lib.callback.register('nv_orgs:setGrade', function(source, set, charId, position)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end

    if type(set) ~= 'string' or type(charId) ~= 'number' or type(position) ~= 'number' then
        return false, 'Dados invalidos.'
    end

    local total = gradeCount(set)
    if total == 0 then return false, 'Esta organizacao nao tem cargos.' end
    if position < 1 or position > total then return false, 'Cargo invalido.' end

    local current = MySQL.scalar.await(
        'SELECT `grade` FROM `character_groups` WHERE `charId` = ? AND `name` = ?',
        { charId, set })

    if not current then return false, 'Este personagem nao e membro.' end

    applyGrade(charId, set, Orgs.positionToGrade(position, total))

    return true
end)

-- -------------------------------------------------------------- demitir --

lib.callback.register('nv_orgs:fire', function(source, set, charId)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(charId) ~= 'number' then return false, 'Dados invalidos.' end

    local current = MySQL.scalar.await(
        'SELECT `grade` FROM `character_groups` WHERE `charId` = ? AND `name` = ?',
        { charId, set })

    if not current then return false, 'Este personagem nao e membro.' end

    applyGrade(charId, set, 0)

    return true
end)
