--[[
    nv_orgs — servidor: criar, editar, listar e excluir organizacoes

    Sobre chamar o ox_core: `Ox.CreateGroup` e `Ox.DeleteGroup` sao funcoes
    async do lado JS. O proprio lib do ox_core (lib/server/vehicle.lua) trata o
    retorno delas como valor direto, porque o bridge do CFX resolve a promise
    antes de devolver para o Lua. Seguimos o mesmo precedente -- mas sempre
    dentro de pcall, ja que elas sinalizam erro com `throw`.
]]

local Ox = require '@ox_core.lib.init'

-- Estilos validos, em set para consulta rapida.
local validStyles = {}

for i = 1, #Config.Styles do
    validStyles[Config.Styles[i].value] = true
end

--- Acoes que um estilo aceita. Impede a NUI de gravar permissao inventada, e
--- tambem de dar a uma gang uma acao exclusiva de estatal.
---@param action string
---@param style string
---@return boolean
local function actionAllowed(action, style)
    for i = 1, #Config.Actions do
        local entry = Config.Actions[i]

        if entry.value == action then
            -- Sem `styles` a acao e comum a todos os estilos.
            if not entry.styles then return true end

            for j = 1, #entry.styles do
                if entry.styles[j] == style then return true end
            end

            return false
        end
    end

    return false
end

-- ---------------------------------------------------------- validacao --

--- Valida o `set` (nome tecnico da organizacao).
---@param set any
---@return boolean, string?
local function validateSet(set)
    if type(set) ~= 'string' then return false, 'Set invalido.' end

    if #set < Config.Org.setMinLength or #set > Config.Org.setMaxLength then
        return false, ('O set precisa ter entre %d e %d caracteres.')
            :format(Config.Org.setMinLength, Config.Org.setMaxLength)
    end

    if not set:match(Config.Org.setPattern) then
        return false, 'O set aceita apenas letras minusculas, numeros e _, comecando por letra.'
    end

    -- Nao deixa criar uma "organizacao" chamada admin e sequestrar o principal
    -- que da acesso a este proprio painel.
    for i = 1, #Config.Admin.groups do
        if set == Config.Admin.groups[i] then
            return false, 'Este nome e reservado.'
        end
    end

    return true
end

--- Valida a lista de cargos vinda da NUI (posicao 1 = mais alto).
---@param grades any
---@return boolean, string?
local function validateGrades(grades)
    if type(grades) ~= 'table' or #grades == 0 then
        return false, 'Crie pelo menos um cargo.'
    end

    if #grades > Config.Grades.max then
        return false, ('Maximo de %d cargos.'):format(Config.Grades.max)
    end

    for i = 1, #grades do
        local grade = grades[i]

        if type(grade) ~= 'table' or type(grade.label) ~= 'string' or grade.label == '' then
            return false, ('O cargo %d esta sem nome.'):format(i)
        end

        if #grade.label > 50 then
            return false, ('O nome do cargo %d e longo demais.'):format(i)
        end

        if grade.actions ~= nil and type(grade.actions) ~= 'table' then
            return false, 'Lista de acoes invalida.'
        end
    end

    return true
end

--- Converte a lista da NUI (1 = mais alto) para o formato do ox_core
--- (indice+1 = grade, grade maior = mais alto).
---@param grades table
---@param style string  estilo da organizacao, que limita as acoes aceitas
---@return table oxGrades  lista { label, accountRole } na ordem do ox_core
---@return table<number, string[]> gradeActions  grade -> acoes filtradas
local function toOxGrades(grades, style)
    local total = #grades
    local oxGrades = {}
    local gradeActions = {}

    for grade = 1, total do
        local position = Orgs.gradeToPosition(grade, total)
        local entry = grades[position]

        local actions = {}

        for _, action in ipairs(entry.actions or {}) do
            if actionAllowed(action, style) then actions[#actions + 1] = action end
        end

        local bankAllowed = false
        for i = 1, #actions do
            if actions[i] == 'bank' then bankAllowed = true break end
        end

        oxGrades[grade] = {
            label = entry.label,
            -- Viewer faz a conta aparecer no ox_banking, mas nao permite
            -- depositar, sacar ou gerenciar. A acao bank eleva o papel.
            accountRole = bankAllowed and Orgs.accountRoleFor(position) or 'viewer'
        }

        gradeActions[grade] = actions
    end

    return oxGrades, gradeActions
end

-- ------------------------------------------------------------ listagem --

--- Lista as organizacoes.
---
--- Filtra por `type`: sem isso, grupos internos como `admin` apareceriam na
--- tela e alguem acabaria excluindo o proprio acesso.
lib.callback.register('nv_orgs:list', function(source)
    if not Orgs.isAdmin(source) then return end

    local styles = {}

    for i = 1, #Config.Styles do
        styles[#styles + 1] = Config.Styles[i].value
    end

    local placeholders = ('?,'):rep(#styles):sub(1, -2)

    local rows = MySQL.query.await(([[
        SELECT
            g.`name`  AS set_name,
            g.`label` AS label,
            g.`type`  AS style,
            (SELECT s.`subtype` FROM `nv_org_subtype` s WHERE s.`group` = g.`name`) AS subtype,
            (SELECT COUNT(*) FROM `character_groups` cg WHERE cg.`name` = g.`name`) AS members,
            (SELECT a.`balance` FROM `accounts` a
              WHERE a.`group` = g.`name` AND a.`type` = 'group' LIMIT 1) AS balance,
            (SELECT COUNT(*) FROM `ox_group_grades` gg WHERE gg.`group` = g.`name`) AS grades
        FROM `ox_groups` g
        WHERE g.`type` IN (%s)
        ORDER BY g.`label`
    ]]):format(placeholders), styles) or {}

    return rows
end)

--- Detalhe de uma organizacao, ja no formato que a tela desenha.
lib.callback.register('nv_orgs:get', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' then return end

    local org = MySQL.single.await(
        'SELECT `name` AS set_name, `label`, `type` AS style FROM `ox_groups` WHERE `name` = ?',
        { set })

    if not org then return end

    local rows = MySQL.query.await(
        'SELECT `grade`, `label` FROM `ox_group_grades` WHERE `group` = ? ORDER BY `grade`',
        { set }) or {}

    local actions = Orgs.loadActions(set)
    local total = #rows
    local grades = {}

    for i = 1, total do
        local row = rows[i]
        local position = Orgs.gradeToPosition(row.grade, total)

        grades[position] = {
            label = row.label,
            actions = actions[row.grade] or {}
        }
    end

    org.grades = grades
    org.subtype = Orgs.getSubtype(set)

    return org
end)

-- -------------------------------------------------------------- criar --

lib.callback.register('nv_orgs:create', function(source, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local set = type(data.set) == 'string' and data.set:lower() or nil
    local ok, err = validateSet(set)
    if not ok then return false, err end

    if type(data.label) ~= 'string' or data.label == '' then
        return false, 'Informe o nome da organizacao.'
    end

    if #data.label > Config.Org.labelMaxLength then
        return false, ('O nome pode ter no maximo %d caracteres.'):format(Config.Org.labelMaxLength)
    end

    if not validStyles[data.style] then return false, 'Estilo invalido.' end

    -- Subtipo: aceito so quando o estilo tem subtipos e o valor esta na lista.
    -- Estilos sem subtipo simplesmente nao guardam nada.
    local subtype = type(data.subtype) == 'string' and data.subtype ~= '' and data.subtype or nil

    if not Orgs.subtypeValid(data.style, subtype) then
        return false, 'Subtipo invalido para este estilo.'
    end

    ok, err = validateGrades(data.grades)
    if not ok then return false, err end

    local exists = MySQL.scalar.await('SELECT `name` FROM `ox_groups` WHERE `name` = ?', { set })
    if exists then return false, 'Ja existe uma organizacao com esse set.' end

    local oxGrades, gradeActions = toOxGrades(data.grades, data.style)

    -- CreateGroup grava ox_groups e ox_group_grades numa transacao so, e
    -- sinaliza erro com throw -- dai o pcall.
    local called, createError = pcall(function()
        Ox.CreateGroup({
            name       = set,
            label      = data.label,
            type       = data.style,
            colour     = Config.Org.colour,
            hasAccount = Config.Org.hasAccount,
            grades     = oxGrades
        })
    end)

    if not called then
        lib.print.error(('Falha ao criar a organizacao `%s` no ox_core: %s'):format(set, tostring(createError)))
        return false, ('O ox_core recusou a criacao: %s'):format(tostring(createError))
    end

    -- CreateGroup e async no ox_core e nao devolve um booleano. Confirme o
    -- resultado persistido antes de criar os dados complementares da org.
    local persisted = MySQL.scalar.await('SELECT 1 FROM `ox_groups` WHERE `name` = ?', { set })

    if not persisted then
        lib.print.error(('O ox_core nao persistiu a organizacao `%s`. Verifique a conexao com o banco.'):format(set))
        return false, 'Nao foi possivel gravar a organizacao no banco de dados.'
    end

    -- SetupGroup cria a conta em segundo plano. Aguarde-a e, caso o framework
    -- ainda nao a tenha materializado, crie explicitamente antes de concluir.
    if Config.Org.hasAccount and not Orgs.ensureGroupAccount(set, data.label) then
        lib.print.error(('A organizacao `%s` foi criada, mas a conta bancaria nao foi persistida.')
            :format(set))
    end

    Orgs.saveActions(set, gradeActions)
    Orgs.setSubtype(set, subtype)
    Orgs.syncPermissions()

    return true, nil, set
end)

-- ------------------------------------------------------------ atualizar --

lib.callback.register('nv_orgs:update', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local org = MySQL.single.await('SELECT `name` FROM `ox_groups` WHERE `name` = ?', { set })
    if not org then return false, 'Organizacao nao encontrada.' end

    if type(data.label) ~= 'string' or data.label == '' then
        return false, 'Informe o nome da organizacao.'
    end

    if #data.label > Config.Org.labelMaxLength then
        return false, ('O nome pode ter no maximo %d caracteres.'):format(Config.Org.labelMaxLength)
    end

    if not validStyles[data.style] then return false, 'Estilo invalido.' end

    local subtype = type(data.subtype) == 'string' and data.subtype ~= '' and data.subtype or nil

    if not Orgs.subtypeValid(data.style, subtype) then
        return false, 'Subtipo invalido para este estilo.'
    end

    local ok, err = validateGrades(data.grades)
    if not ok then return false, err end

    local oxGrades, gradeActions = toOxGrades(data.grades, data.style)
    local total = #oxGrades

    -- Ninguem pode ficar num grade que deixou de existir: seria um membro sem
    -- cargo, invisivel na tela e imune a promocao. Rebaixa para o topo atual.
    MySQL.query.await(
        'UPDATE `character_groups` SET `grade` = ? WHERE `name` = ? AND `grade` > ?',
        { total, set, total })

    MySQL.query.await('UPDATE `ox_groups` SET `label` = ?, `type` = ? WHERE `name` = ?',
        { data.label, data.style, set })

    -- O ox_core nao tem UpdateGroup, entao os cargos sao reescritos direto.
    -- Apagar e reinserir mantem o banco igual ao que a tela mandou, sem diff.
    MySQL.query.await('DELETE FROM `ox_group_grades` WHERE `group` = ?', { set })

    local values = {}

    for grade = 1, total do
        values[#values + 1] = { set, grade, oxGrades[grade].label, oxGrades[grade].accountRole }
    end

    MySQL.prepare.await(
        'INSERT INTO `ox_group_grades` (`group`, `grade`, `label`, `accountRole`) VALUES (?, ?, ?, ?)',
        values)

    Orgs.saveActions(set, gradeActions)

    -- Trocar de estilo pode invalidar o subtipo (uma estatal que virou gang
    -- nao tem "policia"). `setSubtype(nil)` limpa; `subtypeValid` acima ja
    -- garantiu que o valor combina com o estilo novo.
    Orgs.setSubtype(set, subtype)

    -- Sem isto o ox_core continuaria com os cargos antigos em memoria e nada
    -- do que acabamos de gravar teria efeito ate o proximo restart.
    Orgs.reloadGroups()
    Orgs.syncPermissions()

    -- Mudar as acoes muda quem abre os baus: o `groups` do ox_inventory e do
    -- target e derivado delas. Sem este sync, tirar a acao de um cargo nao
    -- fecharia o bau para ele ate o proximo restart.
    --
    -- Checado por existencia porque resources.lua carrega depois deste arquivo;
    -- em tempo de execucao ja esta la.
    if Orgs.syncStashes then Orgs.syncStashes() end

    return true
end)

-- ------------------------------------------------------------- excluir --

lib.callback.register('nv_orgs:delete', function(source, set)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' then return false, 'Dados invalidos.' end

    local org = MySQL.single.await('SELECT `name` FROM `ox_groups` WHERE `name` = ?', { set })
    if not org then return false, 'Organizacao nao encontrada.' end

    -- `DeleteGroup` do ox_core, e nao DELETE direto: ele tira o grupo da
    -- memoria, remove o principal do ACE e zera o grupo de quem estava online.
    -- Um DELETE no banco deixaria tudo isso vivo ate o restart.
    local deleted = pcall(function() Ox.DeleteGroup(set) end)

    if not deleted then
        return false, 'O ox_core recusou a exclusao. Confira o console do servidor.'
    end

    if Orgs.schemaReady then
        MySQL.query.await('DELETE FROM `nv_org_grade_actions` WHERE `group` = ?', { set })

        -- `nv_org_stashes` nao tem chave estrangeira (a tabela e criada sem
        -- FK), entao a limpeza e explicita. Deixar a linha para tras faria o
        -- bau ser reregistrado no proximo boot apontando para um grupo que nao
        -- existe mais.
        MySQL.query.await('DELETE FROM `nv_org_stashes` WHERE `group` = ?', { set })
        MySQL.query.await('DELETE FROM `nv_org_subtype` WHERE `group` = ?', { set })
    end

    if Orgs.syncStashes then Orgs.syncStashes() end

    return true
end)
