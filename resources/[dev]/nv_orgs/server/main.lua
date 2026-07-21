--[[
    nv_orgs — servidor: base

    Carregado primeiro. Declara o namespace `Orgs`, cria a tabela e -- o mais
    importante -- reaplica as permissoes no boot.

    Sobre a arquitetura: este resource NAO tem tabela de organizacao, de cargo
    nem de membro. Todas ja existem no ox_core:

        organizacao ......... ox_groups
        cargos .............. ox_group_grades
        membros ............. character_groups
        caixa da empresa .... accounts (type = 'group')

    A unica coisa que falta la e a persistencia das PERMISSOES: o ox_core
    guarda `GlobalState['group.<nome>:permissions']` e nunca grava isso em
    lugar nenhum. Por isso existe `nv_org_grade_actions`, e por isso este
    arquivo tem uma rotina de reaplicacao.
]]

local Ox = require '@ox_core.lib.init'

Orgs = {}

-- ------------------------------------------------------------- schema --

Orgs.schemaReady = false

--- Garante que o grupo tenha exatamente uma conta empresarial padrao. O
--- ox_banking e Ox.GetGroupAccount ignoram contas de grupo com isDefault = 0.
function Orgs.ensureGroupAccount(set, label)
    local rows = MySQL.query.await([[
        SELECT `id`, `isDefault` FROM `accounts`
        WHERE `group` = ? AND `type` = 'group' ORDER BY `isDefault` DESC, `id`
    ]], { set }) or {}

    if #rows == 0 then
        local Ox = require '@ox_core.lib.init'
        local made = pcall(function() Ox.CreateAccount(set, label or set) end)
        if not made then return false end
        rows = MySQL.query.await([[
            SELECT `id`, `isDefault` FROM `accounts`
            WHERE `group` = ? AND `type` = 'group' ORDER BY `id`
        ]], { set }) or {}
    end

    if #rows == 0 then return false end

    local defaultId = rows[1].id
    MySQL.update.await([[
        UPDATE `accounts` SET `isDefault` = CASE WHEN `id` = ? THEN 1 ELSE 0 END
        WHERE `group` = ? AND `type` = 'group'
    ]], { defaultId, set })
    return true
end

CreateThread(function()
    -- Mesmo padrao do nv_garage: tenta com chave estrangeira e, se o schema do
    -- ox_core nao permitir, cai para a versao sem FK. Ter a tabela sem cascata
    -- e melhor do que nao ter tabela nenhuma.
    local columns = [[
        `group`  VARCHAR(20) NOT NULL,
        `grade`  TINYINT UNSIGNED NOT NULL,
        `action` VARCHAR(40) NOT NULL,
        PRIMARY KEY (`group`, `grade`, `action`)
    ]]

    local withFk = ([[
        CREATE TABLE IF NOT EXISTS `nv_org_grade_actions` (
            %s,
            CONSTRAINT `nv_org_grade_actions_group_fk`
                FOREIGN KEY (`group`) REFERENCES `ox_groups` (`name`)
                ON DELETE CASCADE ON UPDATE CASCADE
        )
    ]]):format(columns)

    local withoutFk = ('CREATE TABLE IF NOT EXISTS `nv_org_grade_actions` (%s)'):format(columns)

    if pcall(MySQL.query.await, withFk) then
        Orgs.schemaReady = true
    elseif pcall(MySQL.query.await, withoutFk) then
        Orgs.schemaReady = true

        lib.print.warn('nv_org_grade_actions criada SEM chave estrangeira: apagar uma organizacao vai deixar as acoes dela orfas na tabela.')
    else
        return lib.print.error('Nao foi possivel criar `nv_org_grade_actions`. As acoes por cargo nao vao sobreviver ao restart.')
    end

    -- Baus: `RegisterStash` do ox_inventory so vive em memoria, entao a
    -- definicao precisa ficar aqui e ser reaplicada a cada boot -- mesma razao
    -- da tabela de acoes.
    --
    -- Fechaduras NAO tem tabela: elas moram no `ox_doorlock` e o vinculo com a
    -- organizacao e o PREFIXO DO NOME (`nv_orgs:<set>:...`). Guardar o id aqui
    -- criaria duas fontes de verdade que sairiam de sincronia na primeira vez
    -- que alguem editasse uma porta pelo /doorlock.
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_org_stashes` (
            `group`     VARCHAR(20) NOT NULL,
            `slot`      VARCHAR(20) NOT NULL,
            `label`     VARCHAR(50) NOT NULL,
            `coords`    VARCHAR(60) NOT NULL,
            `slots`     SMALLINT UNSIGNED NOT NULL DEFAULT 50,
            `maxWeight` INT UNSIGNED NOT NULL DEFAULT 100000,
            PRIMARY KEY (`group`, `slot`)
        )
    ]])

    -- Acesso do bau.
    --
    -- Guardamos a POSICAO (1 = so o cargo mais alto, 2 = os dois mais altos) e
    -- nao o grade do ox_core. O grade depende de quantos cargos existem, entao
    -- gravar ele deixaria o acesso errado no dia em que alguem adicionasse um
    -- cargo -- "os 2 do topo" viraria "os 3 do topo" sem ninguem pedir.
    pcall(MySQL.query.await, 'ALTER TABLE `nv_org_stashes` ADD COLUMN `minPosition` TINYINT UNSIGNED NOT NULL DEFAULT 1')
    pcall(MySQL.query.await, 'ALTER TABLE `nv_org_stashes` ADD COLUMN `management` TINYINT(1) NOT NULL DEFAULT 0')

    -- Contatos: o numero precisa sobreviver ao restart (o papel que esta no
    -- bolso do jogador continua valendo) e ser unico no servidor inteiro, para
    -- nao colidir com o telefone de ninguem.
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_org_contacts` (
            `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `group`   VARCHAR(20) NOT NULL,
            `number`  VARCHAR(20) NOT NULL,
            `active`  TINYINT(1) NOT NULL DEFAULT 1,
            `created` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `nv_org_contacts_number` (`number`),
            KEY `nv_org_contacts_group` (`group`)
        )
    ]])

    -- Estacionamento: atendente, vagas e frota.
    --
    -- Tres tabelas em vez de uma coluna JSON porque as vagas e a frota sao
    -- listas que crescem e sao consultadas separadamente -- guardar tudo num
    -- blob obrigaria a reescrever a frota inteira para mudar o preco de um
    -- carro.
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_org_garages` (
            `group` VARCHAR(20) NOT NULL,
            `ped`   VARCHAR(90) NULL,
            PRIMARY KEY (`group`)
        )
    ]])

    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_org_spawns` (
            `id`     INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `group`  VARCHAR(20) NOT NULL,
            `coords` VARCHAR(80) NOT NULL,
            PRIMARY KEY (`id`),
            KEY `nv_org_spawns_group` (`group`)
        )
    ]])

    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_org_fleet` (
            `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `group`       VARCHAR(20) NOT NULL,
            `model`       VARCHAR(20) NOT NULL,
            `label`       VARCHAR(50) NOT NULL,
            `price`       INT UNSIGNED NOT NULL DEFAULT 0,
            `minPosition` TINYINT UNSIGNED NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            KEY `nv_org_fleet_group` (`group`)
        )
    ]])

    pcall(MySQL.query.await, [[CREATE TABLE IF NOT EXISTS `nv_org_vehicle_state` (
        `vin` CHAR(17) NOT NULL, `group` VARCHAR(20) NOT NULL,
        `taken_by` INT UNSIGNED NULL, `taken_at` DATETIME NULL,
        `returned_by` INT UNSIGNED NULL, `returned_at` DATETIME NULL,
        PRIMARY KEY (`vin`), KEY `nv_org_vehicle_state_group` (`group`)
    )]])

    -- Vestiario: pontos e roupas.
    --
    -- `model` na roupa nao e detalhe: componente 4 de um corpo masculino nao
    -- e a mesma peca no feminino. Aplicar a roupa errada no corpo errado
    -- deforma o personagem, entao a roupa so aparece para quem tem o mesmo
    -- modelo de quem a salvou.
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_org_wardrobes` (
            `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `group`       VARCHAR(20) NOT NULL,
            `coords`      VARCHAR(60) NOT NULL,
            `minPosition` TINYINT UNSIGNED NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            KEY `nv_org_wardrobes_group` (`group`)
        )
    ]])

    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_org_outfits` (
            `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `group`       VARCHAR(20) NOT NULL,
            `label`       VARCHAR(50) NOT NULL,
            `model`       VARCHAR(24) NOT NULL,
            `outfit`      LONGTEXT NOT NULL,
            `minPosition` TINYINT UNSIGNED NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            KEY `nv_org_outfits_group` (`group`)
        )
    ]])

    -- Subtipo da organizacao (police / hospital / mecanica para as estatais).
    -- Tabela separada, e nao coluna em `ox_groups`: o schema do ox_groups e do
    -- framework, e o `type` ja carrega o estilo -- misturar o subtipo ali
    -- quebraria `GetGroupsByType` e a listagem `WHERE type IN (...)`.
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `nv_org_subtype` (
            `group`   VARCHAR(20) NOT NULL,
            `subtype` VARCHAR(30) NULL,
            PRIMARY KEY (`group`)
        )
    ]])

    -- Instalacoes anteriores usavam o ingles `mechanic`, mas o MDT sempre
    -- identificou o departamento como `mecanica`. Unifica sem exigir que o
    -- administrador recrie sets, membros, conta ou recursos da organizacao.
    pcall(MySQL.update.await,
        "UPDATE `nv_org_subtype` SET `subtype` = 'mecanica' WHERE `subtype` = 'mechanic'")

    Orgs.syncPermissions()
end)

-- Repara contas antigas criadas antes da normalizacao de isDefault.
CreateThread(function()
    Wait(1500)
    local styles = {}
    for i = 1, #Config.Styles do styles[#styles + 1] = Config.Styles[i].value end
    local placeholders = ('?,'):rep(#styles):sub(1, -2)
    local groups = MySQL.query.await(([[
        SELECT `name`, `label` FROM `ox_groups` WHERE `type` IN (%s)
    ]]):format(placeholders), styles) or {}

    for i = 1, #groups do
        if not Orgs.ensureGroupAccount(groups[i].name, groups[i].label) then
            lib.print.error(('Nao foi possivel reparar a conta da organizacao `%s`.'):format(groups[i].name))
        end
    end

    -- O banking exige um accountRole nao nulo para listar contas de grupo.
    -- Viewer concede somente visualizacao; cargos com a acao bank conservam o
    -- papel superior que ja foi gravado pelo painel.
    MySQL.update.await(([[
        UPDATE `ox_group_grades` gg
        JOIN `ox_groups` g ON g.`name` = gg.`group`
        SET gg.`accountRole` = 'viewer'
        WHERE g.`type` IN (%s) AND gg.`accountRole` IS NULL
    ]]):format(placeholders), styles)

    -- Atualiza o cache/GlobalState usado pelo ox_core e pelo ox_banking.
    Orgs.reloadGroups()
end)

-- ------------------------------------------------------------- subtipo --

--- O subtipo faz sentido para este estilo?
--- `state` + 'police' = sim; `gang` + qualquer subtipo = nao (gangs nao tem).
---@param style string
---@param subtype string?
---@return boolean
function Orgs.subtypeValid(style, subtype)
    local list = Config.Subtypes[style]

    -- Estilo sem subtipos so aceita "sem subtipo".
    if not list then return subtype == nil end
    if subtype == nil then return true end

    for i = 1, #list do
        if list[i].value == subtype then return true end
    end

    return false
end

--- Grava (ou limpa) o subtipo de uma organizacao.
---@param set string
---@param subtype string?
function Orgs.setSubtype(set, subtype)
    if not set or not Orgs.schemaReady then return end

    if subtype == nil then
        MySQL.query.await('DELETE FROM `nv_org_subtype` WHERE `group` = ?', { set })
        return
    end

    MySQL.prepare.await([[
        INSERT INTO `nv_org_subtype` (`group`, `subtype`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `subtype` = VALUES(`subtype`)
    ]], { set, subtype })
end

--- O subtipo de uma organizacao, ou nil.
---@param set string
---@return string?
function Orgs.getSubtype(set)
    if not set or not Orgs.schemaReady then return end

    local value = MySQL.scalar.await('SELECT `subtype` FROM `nv_org_subtype` WHERE `group` = ?', { set })

    return value
end

-- Para o dispatch, o hospital, etc.: "esta organizacao e uma policia?" sem
-- depender do nome do set.
exports('GetOrgSubtype', function(set)
    return Orgs.getSubtype(set)
end)

-- --------------------------------------------------------- permissoes --

--- Reaplica em `GlobalState` todas as acoes gravadas no banco.
---
--- E o coracao do resource. `SetGroupPermission` escreve so em memoria, entao
--- sem esta rotina toda organizacao perde as permissoes no restart e ninguem
--- consegue abrir bau nenhum ate alguem reeditar tudo na mao.
function Orgs.syncPermissions()
    if not Orgs.schemaReady then return end

    local ok, rows = pcall(MySQL.query.await,
        'SELECT `group`, `grade`, `action` FROM `nv_org_grade_actions`')

    if not ok or type(rows) ~= 'table' then
        return lib.print.error('Nao foi possivel ler `nv_org_grade_actions`; as permissoes ficaram vazias.')
    end

    for i = 1, #rows do
        local row = rows[i]

        pcall(function()
            exports.ox_core:SetGroupPermission(row.group, row.grade, row.action, 'allow')
        end)
    end

    lib.print.info(('nv_orgs: %d permissao(oes) reaplicada(s).'):format(#rows))
end

--- Regrava as acoes de uma organizacao inteira.
---
--- Apaga e reinsere em vez de fazer diff: a lista e pequena e "o que esta no
--- banco e exatamente o que a UI mandou" e muito mais facil de raciocinar do
--- que um conjunto de inserts e deletes parciais.
---@param set string
---@param gradeActions table<number, string[]> grade (ox_core) -> lista de acoes
function Orgs.saveActions(set, gradeActions)
    if not Orgs.schemaReady then return end

    MySQL.query.await('DELETE FROM `nv_org_grade_actions` WHERE `group` = ?', { set })

    local values = {}

    for grade, actions in pairs(gradeActions) do
        for i = 1, #actions do
            values[#values + 1] = { set, grade, actions[i] }
        end
    end

    if #values > 0 then
        MySQL.prepare.await(
            'INSERT INTO `nv_org_grade_actions` (`group`, `grade`, `action`) VALUES (?, ?, ?)',
            values)
    end
end

--- Acoes de uma organizacao, agrupadas por grade do ox_core.
---@param set string
---@return table<number, string[]>
function Orgs.loadActions(set)
    local result = {}

    if not Orgs.schemaReady then return result end

    local ok, rows = pcall(MySQL.query.await,
        'SELECT `grade`, `action` FROM `nv_org_grade_actions` WHERE `group` = ?', { set })

    if not ok or type(rows) ~= 'table' then return result end

    for i = 1, #rows do
        local row = rows[i]

        result[row.grade] = result[row.grade] or {}
        result[row.grade][#result[row.grade] + 1] = row.action
    end

    return result
end

-- --------------------------------------------------------------- admin --

--- Este jogador pode mexer em organizacoes?
---
--- Checado em TODO callback, e nao so na abertura do painel: o menu e apenas
--- uma tela, e qualquer um consegue disparar um callback pelo console.
---@param source number
---@return boolean
function Orgs.isAdmin(source)
    if not source or source == 0 then return false end

    if IsPlayerAceAllowed(source, Config.Admin.ace) then return true end

    local player = Ox.GetPlayer(source)
    if not player then return false end

    local ok, groups = pcall(function() return player.getGroups() end)
    if not ok or type(groups) ~= 'table' then return false end

    for i = 1, #Config.Admin.groups do
        if groups[Config.Admin.groups[i]] then return true end
    end

    return false
end

-- ----------------------------------------------------- ordem dos cargos --

--[[
    O ox_core usa grade MAIOR = mais alto (e grade 0 = "sem grupo", que e como
    se remove alguem). A tela pede o contrario: posicao 1 no topo da lista e o
    chefe.

    Nao inventamos coluna para isso -- e so uma inversao na fronteira da UI. As
    duas funcoes abaixo sao o unico lugar do resource que sabe disso, e todo
    dado que entra ou sai da NUI passa por elas.
]]

---@param position number posicao na lista (1 = mais alto)
---@param total number quantidade de cargos
---@return number grade do ox_core
function Orgs.positionToGrade(position, total)
    return total - position + 1
end

---@param grade number grade do ox_core
---@param total number quantidade de cargos
---@return number posicao na lista (1 = mais alto)
function Orgs.gradeToPosition(grade, total)
    return total - grade + 1
end

--- Um TINYINT(1) do banco virou verdadeiro?
---
--- O oxmysql pode devolver TINYINT(1) como BOOLEAN ou como NUMERO, conforme a
--- configuracao do driver. Comparar so com `== 1` funciona numa instalacao e
--- falha silenciosamente na outra -- foi o que fez um contato recem-criado
--- aparecer como inativo. Este helper aceita as duas formas.
---@param value any
---@return boolean
function Orgs.truthy(value)
    return value == 1 or value == true or value == '1'
end

--- Papel bancario deduzido da posicao (ver Config.Grades.accountRoles).
---@param position number
---@return string
function Orgs.accountRoleFor(position)
    return Config.Grades.accountRoles[position] or Config.Grades.accountRoles.default
end

-- ------------------------------------------------------------- recarga --

--- Forca o ox_core a reler os grupos do banco.
---
--- Necessario porque ele guarda os grupos em memoria (`groups[name]`) e nao
--- expoe um export de update -- editar `ox_group_grades` por baixo nao surtiria
--- efeito nenhum ate o proximo restart. O comando `reloadgroups` chama o mesmo
--- `LoadGroups()` que roda no boot.
---
--- Cuidado conhecido: `LoadGroups` refaz o setup de cada grupo do banco, mas
--- nao remove da memoria um grupo que deixou de existir. Por isso a exclusao
--- usa `DeleteGroup` do proprio ox_core, e nao um DELETE direto.
function Orgs.reloadGroups()
    ExecuteCommand('reloadgroups')
end
