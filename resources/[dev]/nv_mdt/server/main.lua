--[[
    nv_mdt — servidor: base

    Schema, controle de acesso e chamados.

    O CONTROLE DE ACESSO e o ponto mais importante deste arquivo. Quem entra no
    MDT nao esta numa lista aqui: entra quem pertence a uma organizacao cujo
    SUBTIPO no nv_orgs e police, hospital ou mecanica. Isso significa que criar
    uma segunda corporacao de policia no painel de organizacoes ja da MDT a ela,
    sem tocar em codigo -- e tambem que tirar o subtipo tira o acesso.
]]

local Ox = require '@ox_core.lib.init'

Mdt = {}
Mdt.schemaReady = false

-- ------------------------------------------------------------- schema --

CreateThread(function()
    local tables = {
        -- Multas. `charId` e do ox_core; sem FK porque as tabelas do nv_orgs
        -- seguem o mesmo padrao (criadas em runtime, tolerantes a schema
        -- antigo).
        [[CREATE TABLE IF NOT EXISTS `nv_mdt_fines` (
            `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `charId`  INT UNSIGNED NOT NULL,
            `label`   VARCHAR(60) NOT NULL,
            `value`   INT UNSIGNED NOT NULL DEFAULT 0,
            `officer` VARCHAR(80) NOT NULL,
            `created` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_fines_char` (`charId`)
        )]],

        -- `reduction` e a % de reducao de pena; `fines` guarda as multas
        -- atreladas ao tipo (JSON), para a prisao poder ser reaberta depois e
        -- mostrar o que foi cobrado, e nao so quanto.
        [[CREATE TABLE IF NOT EXISTS `nv_mdt_arrests` (
            `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `charId`    INT UNSIGNED NOT NULL,
            `reasons`   VARCHAR(255) NOT NULL,
            `notes`     TEXT NULL,
            `fines`     TEXT NULL,
            `reduction` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `evidence`  TEXT NULL,
            `officer`   VARCHAR(80) NOT NULL,
            `created`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_arrests_char` (`charId`)
        )]],

        [[CREATE TABLE IF NOT EXISTS `nv_mdt_wanted` (
            `charId`   INT UNSIGNED NOT NULL,
            `reason`   VARCHAR(120) NOT NULL,
            `type`     VARCHAR(40) NULL,
            `evidence` TEXT NULL,
            `officer`  VARCHAR(80) NOT NULL,
            `created`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`charId`)
        )]],

        -- Ocorrencias da policia. `involved` e um JSON com os envolvidos
        -- (charId + nome): a ocorrencia raramente tem um unico cidadao, e uma
        -- coluna de texto perderia a ligacao com o cadastro.
        [[CREATE TABLE IF NOT EXISTS `nv_mdt_reports` (
            `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `type`     VARCHAR(20) NOT NULL,
            `citizen`  VARCHAR(100) NULL,
            `phone`    VARCHAR(20) NULL,
            `involved` TEXT NULL,
            `notes`    TEXT NULL,
            `author`   VARCHAR(80) NOT NULL,
            `created`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_reports_created` (`created`)
        )]],

        -- Apreensao e roubo de veiculo, por PLACA (a placa e o que a policia
        -- ve na rua; o vin nao).
        [[CREATE TABLE IF NOT EXISTS `nv_mdt_vehicle_flags` (
            `plate`  VARCHAR(12) NOT NULL,
            `stolen` TINYINT(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`plate`)
        )]],

        [[CREATE TABLE IF NOT EXISTS `nv_mdt_seizures` (
            `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `plate`   VARCHAR(12) NOT NULL,
            `reason`  VARCHAR(120) NOT NULL,
            `officer` VARCHAR(80) NOT NULL,
            `created` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_seizures_plate` (`plate`)
        )]],

        -- Hospital: consultas e anotacoes.
        [[CREATE TABLE IF NOT EXISTS `nv_mdt_consults` (
            `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `charId`    INT UNSIGNED NULL,
            `name`      VARCHAR(100) NOT NULL,
            `reasons`   VARCHAR(255) NULL,
            `injuries`  TEXT NULL,
            `resources` TEXT NULL,
            `hours`     DECIMAL(5,2) NOT NULL DEFAULT 0,
            `rescue`    TINYINT(1) NOT NULL DEFAULT 0,
            `total`     INT UNSIGNED NOT NULL DEFAULT 0,
            `doctor`    VARCHAR(80) NOT NULL,
            `created`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_consults_char` (`charId`)
        )]],

        [[CREATE TABLE IF NOT EXISTS `nv_mdt_notes` (
            `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `charId`  INT UNSIGNED NOT NULL,
            `notes`   TEXT NOT NULL,
            `author`  VARCHAR(80) NOT NULL,
            `created` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_notes_char` (`charId`)
        )]],

        -- Mecanica: ordens de servico.
        [[CREATE TABLE IF NOT EXISTS `nv_mdt_repairs` (
            `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `plate`    VARCHAR(12) NOT NULL,
            `model`    VARCHAR(60) NULL,
            `parts`    TEXT NULL,
            `notes`    TEXT NULL,
            `billedTo` VARCHAR(100) NULL,
            `tow`      TINYINT(1) NOT NULL DEFAULT 0,
            `total`    INT UNSIGNED NOT NULL DEFAULT 0,
            `mechanic` VARCHAR(80) NOT NULL,
            `created`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_repairs_plate` (`plate`)
        )]],

        -- Chamados. Alimentados por outros resources (export `AddCall`) e pela
        -- propria tela do hospital.
        [[CREATE TABLE IF NOT EXISTS `nv_mdt_calls` (
            `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `dept`     VARCHAR(20) NOT NULL,
            `title`    VARCHAR(120) NOT NULL,
            `location` VARCHAR(120) NULL,
            `priority` VARCHAR(10) NOT NULL DEFAULT 'media',
            `x`        FLOAT NULL,
            `y`        FLOAT NULL,
            `created`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_calls_dept` (`dept`, `created`)
        )]],

        --[[
            FATURAS PENDENTES

            Multas e custos de prisao viram divida, nao desconto imediato: o
            cidadao pode nao ter o dinheiro no bolso na hora da abordagem, e uma
            multa que so existe se houver saldo nao e multa.

            `value` e o valor ORIGINAL e nunca muda. Os juros sao calculados a
            partir dele e de `created` toda vez que a fatura e lida -- guardar o
            valor ja corrigido exigiria um cron que, se falhasse uma noite,
            perderia um dia de juros em silencio. Ver `Mdt.invoiceTotal`.
        ]]
        [[CREATE TABLE IF NOT EXISTS `nv_mdt_invoices` (
            `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `charId`  INT UNSIGNED NOT NULL,
            `kind`    VARCHAR(20) NOT NULL DEFAULT 'multa',
            `label`   VARCHAR(120) NOT NULL,
            `value`   INT UNSIGNED NOT NULL DEFAULT 0,
            `paid`    TINYINT(1) NOT NULL DEFAULT 0,
            `officer` VARCHAR(80) NOT NULL,
            `created` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `paidAt`  DATETIME NULL,
            PRIMARY KEY (`id`),
            KEY `nv_mdt_invoices_char` (`charId`, `paid`)
        )]]
    }

    local failed = 0

    for i = 1, #tables do
        if not pcall(MySQL.query.await, tables[i]) then failed = failed + 1 end
    end

    if failed > 0 then
        return lib.print.error(('nv_mdt: %d tabela(s) nao puderam ser criadas. O MDT vai abrir, mas nada sera salvo.'):format(failed))
    end

    --[[
        COLUNAS NOVAS EM TABELAS ANTIGAS

        `CREATE TABLE IF NOT EXISTS` nao toca numa tabela que ja existe, entao
        quem ja rodava o MDT antes destas colunas continuaria sem elas -- e o
        primeiro INSERT quebraria com "unknown column", que e um erro que nao
        explica nada sobre a causa.

        Cada ALTER vai num pcall proprio: "coluna ja existe" e o resultado
        NORMAL aqui, nao uma falha. Falhar em silencio e o comportamento certo.
    ]]
    local additions = {
        'ALTER TABLE `nv_mdt_calls` ADD COLUMN `x` FLOAT NULL',
        'ALTER TABLE `nv_mdt_calls` ADD COLUMN `y` FLOAT NULL',
        'ALTER TABLE `nv_mdt_arrests` ADD COLUMN `fines` TEXT NULL',
        'ALTER TABLE `nv_mdt_arrests` ADD COLUMN `reduction` TINYINT UNSIGNED NOT NULL DEFAULT 0',
        'ALTER TABLE `nv_mdt_arrests` ADD COLUMN `evidence` TEXT NULL',
        'ALTER TABLE `nv_mdt_wanted` ADD COLUMN `type` VARCHAR(40) NULL',
        'ALTER TABLE `nv_mdt_wanted` ADD COLUMN `evidence` TEXT NULL',
        'ALTER TABLE `nv_mdt_reports` ADD COLUMN `phone` VARCHAR(20) NULL',
        'ALTER TABLE `nv_mdt_reports` ADD COLUMN `involved` TEXT NULL',
        'ALTER TABLE `nv_mdt_repairs` ADD COLUMN `orgSet` VARCHAR(20) NULL',
        'ALTER TABLE `nv_mdt_repairs` ADD COLUMN `billedCharId` INT UNSIGNED NULL'
    }

    for i = 1, #additions do
        pcall(MySQL.query.await, additions[i])
    end

    Mdt.schemaReady = true
end)

-- ------------------------------------------------------------- faturas --

--- Valor corrigido de uma fatura, com os juros por atraso.
---
--- Regra: +10% do valor ORIGINAL por dia vencido, ate no maximo 3 dias. Depois
--- disso a divida congela -- juros infinitos transformam uma multa esquecida
--- num numero que ninguem nunca vai pagar, e uma divida impagavel deixa de ser
--- uma consequencia para virar um personagem abandonado.
---
--- Juros simples, e nao compostos, pelo mesmo motivo: e a conta que o jogador
--- consegue fazer de cabeca ao ver "3 dias".
---
---@param value number    valor original
---@param days number     dias corridos desde a emissao
---@return number total
---@return number days    dias efetivamente cobrados (0-3)
function Mdt.invoiceTotal(value, days)
    days = math.max(0, math.min(Config.Invoices.maxDays, math.floor(days or 0)))

    return math.floor(value + value * (Config.Invoices.dailyRate * days)), days
end


-- ------------------------------------------------------------- acesso --

--- Departamentos que este jogador pode abrir.
---
--- Uma consulta so: os grupos do personagem, cruzados com o subtipo que o
--- nv_orgs guarda. Nao usamos o export do nv_orgs aqui porque precisamos do
--- conjunto inteiro de uma vez, e nao de um subtipo por chamada.
---@param source number
---@return table<string, { set: string, label: string, grade: number }>
function Mdt.departmentsOf(source)
    local player = Ox.GetPlayer(source)
    if not player then return {} end

    local charId = player.charId
    if not charId then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT s.`subtype`, g.`name` AS set_name, g.`label`, cg.`grade`
        FROM `character_groups` cg
        JOIN `ox_groups` g ON g.`name` = cg.`name`
        JOIN `nv_org_subtype` s ON s.`group` = g.`name`
        WHERE cg.`charId` = ? AND s.`subtype` IS NOT NULL
    ]], { charId })

    if not ok or type(rows) ~= 'table' then return {} end

    local result = {}

    for i = 1, #rows do
        local row = rows[i]

        -- Subtipo que nao e departamento do MDT (se algum dia existirem
        -- outros) simplesmente nao entra.
        if Config.Departments[row.subtype] then
            result[row.subtype] = {
                set   = row.set_name,
                label = row.label,
                grade = row.grade
            }
        end
    end

    return result
end

--- O jogador tem acesso a este departamento?
---@param source number
---@param subtype string
---@return boolean
function Mdt.canAccess(source, subtype)
    return Mdt.departmentsOf(source)[subtype] ~= nil
end

--- Nome do personagem de quem esta operando, para assinar os registros.
---@param source number
---@return string
function Mdt.authorName(source)
    local player = Ox.GetPlayer(source)

    if not player then return 'Desconhecido' end

    local ok, name = pcall(function()
        return player.get('name') or player.name
    end)

    return (ok and type(name) == 'string' and name) or ('Char %s'):format(player.charId or '?')
end

-- ---------------------------------------------------------- chamados --

--- Registra um chamado. Exposto para um dispatch futuro alimentar o MDT.
---@param dept string  'policia' | 'hospital' | 'mecanica'
---@param data table   { title, location, priority }
---@return boolean
function Mdt.addCall(dept, data)
    if not Mdt.schemaReady then return false end
    if type(dept) ~= 'string' or type(data) ~= 'table' then return false end
    if type(data.title) ~= 'string' or data.title == '' then return false end

    local priority = data.priority

    if priority ~= 'alta' and priority ~= 'baixa' then priority = 'media' end

    -- Coordenadas sao opcionais: um chamado registrado a mao pela tela do
    -- hospital nao tem posicao, e a lista precisa aceitar isso sem inventar um
    -- ponto no meio do mapa.
    MySQL.prepare.await(
        'INSERT INTO `nv_mdt_calls` (`dept`, `title`, `location`, `priority`, `x`, `y`) VALUES (?, ?, ?, ?, ?, ?)',
        { dept:sub(1, 20), data.title:sub(1, 120), (data.location or ''):sub(1, 120), priority,
          tonumber(data.x), tonumber(data.y) })

    -- Poda: sem isto a tabela cresce para sempre e o dashboard fica lento.
    MySQL.query.await([[
        DELETE FROM `nv_mdt_calls`
        WHERE `dept` = ? AND `id` NOT IN (
            SELECT `id` FROM (
                SELECT `id` FROM `nv_mdt_calls` WHERE `dept` = ?
                ORDER BY `created` DESC LIMIT ?
            ) keep
        )
    ]], { dept, dept, Config.Calls.keep })

    return true
end

exports('AddCall', function(dept, data) return Mdt.addCall(dept, data) end)

--- Chamados de um departamento, mais recentes primeiro.
---@param dept string
---@param limit number?
---@return table[]
function Mdt.getCalls(dept, limit)
    if not Mdt.schemaReady then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT `id`, `title`, `location`, `priority`, `x`, `y`,
               DATE_FORMAT(`created`, '%d/%m %H:%i') AS created
        FROM `nv_mdt_calls` WHERE `dept` = ?
        ORDER BY `created` DESC LIMIT ?
    ]], { dept, limit or Config.Calls.dashboardLimit })

    return (ok and type(rows) == 'table') and rows or {}
end

-- ----------------------------------------------------- colegas online --

--- Membros da organizacao que estao online agora.
---
--- E o "players online" do dashboard e a fonte do Live Map: em vez de listar o
--- servidor inteiro, lista so quem e do mesmo set -- que e o que um MDT de
--- departamento deveria mostrar.
---@param set string
---@return table[]
function Mdt.onlineMembers(set)
    local result = {}

    local all = Ox.GetPlayers() or {}
    local players = {}

    -- Algumas versoes aceitam filtro em GetPlayers e outras apenas retornam
    -- uma lista vazia. Filtrar aqui mantem dashboard e Live Map consistentes.
    for i = 1, #all do
        local got, grade = pcall(function() return all[i].getGroup(set) end)

        if got and grade then players[#players + 1] = all[i] end
    end

    for i = 1, #players do
        local player = players[i]
        local ped = GetPlayerPed(player.source)
        local coords = (ped and ped ~= 0) and GetEntityCoords(ped) or nil

        result[#result + 1] = {
            source = player.source,
            name   = player.name or ('Char %s'):format(player.charId or '?'),
            coords = coords and { x = coords.x, y = coords.y } or nil
        }
    end

    return result
end

-- ------------------------------------------------------------ abertura --

--- Tudo que a tela precisa para desenhar: quais abas existem e as tabelas de
--- referencia (multas, motivos, pecas...) que vivem no config.
lib.callback.register('nv_mdt:open', function(source)
    local departments = Mdt.departmentsOf(source)

    if not next(departments) then return end

    local tabs = {}

    for subtype, org in pairs(departments) do
        local dept = Config.Departments[subtype]

        tabs[#tabs + 1] = {
            id      = dept.id,
            subtype = subtype,
            label   = dept.label,
            icon    = dept.icon,
            org     = org.label,
            set     = org.set
        }
    end

    table.sort(tabs, function(a, b) return a.label < b.label end)

    return {
        tabs = tabs,
        config = {
            police = {
                fines       = Config.Police.fines,
                arrestTypes = Config.Police.arrestTypes,
                reductions  = Config.Police.reductions,
                reportTypes = Config.Police.reportTypes,
                periods     = Config.ReportPeriods,
                documents   = Config.Police.documents,
                cameras     = (function()
                    local rows = {}
                    for i = 1, #(Config.Police.cameras or {}) do
                        rows[i] = { id = Config.Police.cameras[i].id, label = Config.Police.cameras[i].label }
                    end
                    return rows
                end)(),
                invoices    = {
                    dailyRate = Config.Invoices.dailyRate,
                    maxDays   = Config.Invoices.maxDays
                }
            },
            hospital = {
                reasons        = Config.Hospital.reasons,
                resources      = Config.Hospital.resources,
                bodyZones      = Config.Hospital.bodyZones,
                pricePerInjury = Config.Hospital.pricePerInjury,
                pricePerHour   = Config.Hospital.pricePerHour,
                rescueFee      = Config.Hospital.rescueFee,
                maxSeverity    = Config.Hospital.maxSeverity
            },
            mechanic = {
                parts  = Config.Mechanic.parts,
                towFee = Config.Mechanic.towFee
            },
            pageSize = Config.PageSize
        }
    }
end)

--- Dashboard de um departamento: chamados + colegas online.
lib.callback.register('nv_mdt:dashboard', function(source, subtype)
    local departments = Mdt.departmentsOf(source)
    local org = departments[subtype]

    if not org then return end

    local dept = Config.Departments[subtype]

    return {
        calls  = Mdt.getCalls(dept.id),
        online = Mdt.onlineMembers(org.set)
    }
end)

--- Membros da organizacao com o cargo de cada um (aba "Comandos").
lib.callback.register('nv_mdt:staff', function(source, subtype)
    local departments = Mdt.departmentsOf(source)
    local org = departments[subtype]

    if not org then return end

    local rows = MySQL.query.await([[
        SELECT cg.`charId`, c.`fullName` AS name, gg.`label` AS rank_label, cg.`grade`
        FROM `character_groups` cg
        JOIN `characters` c ON c.`charId` = cg.`charId`
        LEFT JOIN `ox_group_grades` gg ON gg.`group` = cg.`name` AND gg.`grade` = cg.`grade`
        WHERE cg.`name` = ?
        ORDER BY cg.`grade` DESC, c.`fullName`
    ]], { org.set }) or {}

    --[[
        EFETIVO: TRES ESTADOS, NAO DOIS

        "Em servico" e "fora de servico" nao cobrem o caso mais comum de todos:
        quem simplesmente nao esta jogando agora. Tratar offline como "fora de
        servico" faria a lista parecer cheia de gente disponivel que nao esta
        nem no servidor.

        - online + de servico -> `servico`
        - online, sem servico  -> `fora`
        - offline              -> `offline` (cinza na tela)
    ]]
    local online = {}
    local players = Ox.GetPlayers() or {}

    for i = 1, #players do
        if players[i].charId then online[players[i].charId] = players[i].source end
    end

    for i = 1, #rows do
        local playerSource = online[rows[i].charId]

        rows[i].source = playerSource
        rows[i].online = playerSource ~= nil

        if not playerSource then
            rows[i].status = 'offline'
        else
            -- O statebag de servico e escrito por quem controla o ponto (o
            -- nv_orgs). Sem ele, quem esta online conta como fora de servico:
            -- e o padrao seguro -- afirmar que alguem esta de servico sem base
            -- coloca um policial no mapa que ninguem pode cobrar.
            local duty = Player(playerSource).state.duty

            rows[i].status = duty and 'servico' or 'fora'
        end

        -- Frequencia de radio, para o embed de status. O nv_radio publica isso
        -- num statebag do jogador; nil e exibido como "sem radio".
        if playerSource then
            rows[i].radio = Player(playerSource).state.radio
        end
    end

    return rows
end)
