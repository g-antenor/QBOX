--[[
    nv_mdt — servidor: policia

    Cidadaos, multas, prisoes, procurados, porte de arma, veiculos e
    ocorrencias.

    Sobre CNH e porte de arma: nao ha tabela propria. O ox_core ja tem
    `ox_licenses` com 'driver' e 'weapon', e `character_licenses` ligando ao
    personagem. Usar isso significa que a CNH que o MDT le e cassa e a MESMA
    que qualquer outro resource do servidor consulta -- criar uma paralela
    daria duas verdades sobre a mesma pergunta.
]]

local Ox = require '@ox_core.lib.init'

--- Toda chamada da policia passa por aqui antes de fazer qualquer coisa.
---@param source number
---@return boolean
local function guard(source)
    return Mdt.canAccess(source, 'police')
end

--- Escapa curingas do LIKE. Sem isto, digitar "%" lista o servidor inteiro.
---@param term string
---@return string
local function like(term)
    return '%' .. term:gsub('[%%_\\]', '\\%0') .. '%'
end

-- ------------------------------------------------------------ cidadao --

--- Busca por nome ou ID. Aceita "#12" porque e assim que o ID aparece nas
--- outras telas de admin do servidor.
lib.callback.register('nv_mdt:police:searchCitizen', function(source, query)
    if not guard(source) then return end
    if type(query) ~= 'string' then return {} end

    query = query:gsub('^%s+', ''):gsub('%s+$', ''):gsub('^#', '')

    local asId = tonumber(query)

    if #query < (asId and 1 or 2) then return {} end

    local term = like(query)

    return MySQL.query.await([[
        SELECT `charId`, `stateId`, `fullName`,
               DATE_FORMAT(`dateOfBirth`, '%d/%m/%Y') AS dob
        FROM `characters`
        WHERE (`fullName` LIKE ? OR `stateId` LIKE ? OR `charId` = ?)
          AND `deleted` IS NULL
        ORDER BY (`charId` = ?) DESC, `fullName`
        LIMIT 15
    ]], { term, term, asId or -1, asId or -1 }) or {}
end)

--- Ficha completa de um cidadao.
lib.callback.register('nv_mdt:police:citizen', function(source, charId)
    if not guard(source) then return end
    if type(charId) ~= 'number' then return end

    local citizen = MySQL.single.await([[
        SELECT `charId`, `stateId`, `fullName`, `phoneNumber`,
               DATE_FORMAT(`dateOfBirth`, '%d/%m/%Y') AS dob
        FROM `characters` WHERE `charId` = ? AND `deleted` IS NULL
    ]], { charId })

    if not citizen then return end

    -- Licencas do ox_core.
    local licenses = MySQL.query.await(
        'SELECT `name` FROM `character_licenses` WHERE `charId` = ?', { charId }) or {}

    citizen.driver = false
    citizen.weapon = false

    for i = 1, #licenses do
        if licenses[i].name == Config.Licenses.driver then citizen.driver = true end
        if licenses[i].name == Config.Licenses.weapon then citizen.weapon = true end
    end

    citizen.fines = MySQL.query.await([[
        SELECT `id`, `label`, `value`, `officer`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_fines` WHERE `charId` = ? ORDER BY `created` DESC
    ]], { charId }) or {}

    citizen.arrests = MySQL.query.await([[
        SELECT `id`, `reasons`, `notes`, `officer`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_arrests` WHERE `charId` = ? ORDER BY `created` DESC
    ]], { charId }) or {}

    local wanted = MySQL.single.await(
        [[SELECT `reason`, `type`, `evidence`, `officer`,
                 DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
          FROM `nv_mdt_wanted` WHERE `charId` = ?]], { charId })

    citizen.wanted = wanted or false

    -- Faturas em aberto, ja com juros. Vem junto da ficha porque "quanto essa
    -- pessoa deve" e uma das primeiras perguntas de qualquer abordagem, e
    -- obrigar a abrir outra aba para responder isso e atrito puro.
    local invoices, invoicesTotal = Mdt.pendingInvoices(charId)

    citizen.invoices = invoices
    citizen.invoicesTotal = invoicesTotal

    -- Veiculos no nome dele: a policia quase sempre chega no cidadao pela
    -- placa, e o caminho inverso tambem e util.
    citizen.vehicles = MySQL.query.await(
        'SELECT `plate`, `model` FROM `vehicles` WHERE `owner` = ? ORDER BY `plate`',
        { charId }) or {}

    local total = 0

    for i = 1, #citizen.fines do total = total + citizen.fines[i].value end

    citizen.finesTotal = total

    return citizen
end)

-- -------------------------------------------------------------- multa --

--- Resolve chaves de multa vindas da tela para as entradas do config.
---
--- Os valores vem do CONFIG, nunca da tela: senao daria para forjar uma multa
--- de um centavo -- ou de um milhao, o que e o mesmo problema por outro lado.
---@param keys string[]
---@return table[] fines
---@return number total
local function resolveFines(keys)
    local chosen, total = {}, 0

    if type(keys) ~= 'table' then return chosen, total end

    for i = 1, #keys do
        for j = 1, #Config.Police.fines do
            local fine = Config.Police.fines[j]

            if fine.key == keys[i] then
                chosen[#chosen + 1] = fine
                total = total + fine.value
                break
            end
        end
    end

    return chosen, total
end

Mdt.resolveFines = resolveFines

lib.callback.register('nv_mdt:police:fine', function(source, charId, keys, notes)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(charId) ~= 'number' or type(keys) ~= 'table' or #keys == 0 then
        return false, 'Selecione ao menos uma infracao.'
    end

    local exists = MySQL.scalar.await('SELECT `charId` FROM `characters` WHERE `charId` = ?', { charId })
    if not exists then return false, 'Cidadao nao encontrado.' end

    local officer = Mdt.authorName(source)
    local fines, total = resolveFines(keys)

    if #fines == 0 then return false, 'Infracao invalida.' end

    --[[
        DUAS TABELAS, DOIS SIGNIFICADOS

        `nv_mdt_fines` e o REGISTRO da infracao: o que foi aplicado, por quem,
        quando. Nao muda nunca e nao some quando a divida e quitada -- e a ficha
        do cidadao.

        `nv_mdt_invoices` e a DIVIDA: o que ainda falta pagar, com juros. Uma
        fatura paga sai da cobranca, mas a multa continua na ficha.

        Guardar os dois no mesmo lugar obrigaria a escolher entre apagar
        historico ao receber o pagamento ou cobrar para sempre quem ja pagou.
    ]]
    local fineRows, invoiceRows = {}, {}
    local note = type(notes) == 'string' and notes ~= '' and notes:sub(1, 200) or nil

    for i = 1, #fines do
        local label = note and ('%s (%s)'):format(fines[i].label, note) or fines[i].label

        fineRows[#fineRows + 1] = { charId, fines[i].label, fines[i].value, officer }
        invoiceRows[#invoiceRows + 1] = { charId, 'multa', label:sub(1, 120), fines[i].value, officer }
    end

    MySQL.prepare.await(
        'INSERT INTO `nv_mdt_fines` (`charId`, `label`, `value`, `officer`) VALUES (?, ?, ?, ?)',
        fineRows)

    MySQL.prepare.await(
        'INSERT INTO `nv_mdt_invoices` (`charId`, `kind`, `label`, `value`, `officer`) VALUES (?, ?, ?, ?, ?)',
        invoiceRows)

    return true, nil, total
end)

-- ------------------------------------------------------------ prisao --

--- Tipos penais validos, por `key`. Um so lugar para prisao e procurado.
---@return table<string, table>
local function arrestTypeMap()
    local map = {}

    for i = 1, #Config.Police.arrestTypes do
        map[Config.Police.arrestTypes[i].key] = Config.Police.arrestTypes[i]
    end

    return map
end

Mdt.arrestTypeMap = arrestTypeMap

--- Registra a prisao e gera a fatura correspondente.
---
---@param data table { types, notes, reduction, evidence, fines }
--- `legacyNotes` e o terceiro argumento da assinatura antiga `(charId, reasons,
--- notes)`. Sem ele, a descricao digitada na tela atual seria descartada.
lib.callback.register('nv_mdt:police:arrest', function(source, charId, data, legacyNotes)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(charId) ~= 'number' or type(data) ~= 'table' then
        return false, 'Dados invalidos.'
    end

    local allowed = arrestTypeMap()

    --[[
        COMPATIBILIDADE COM A TELA ANTIGA

        A tela atual manda `(charId, {'Roubo', 'Furto'}, notas)` -- um array de
        ROTULOS, nao um objeto com chaves de tipo. Enquanto a NUI nao e
        reescrita, traduzimos aqui em vez de deixar o registro de prisao
        falhando em silencio.

        Isto sai quando a tela nova entrar.
    ]]
    if data[1] ~= nil and data.types == nil then
        local byLabel, types = {}, {}

        for key, entry in pairs(allowed) do byLabel[entry.label] = key end

        for i = 1, #data do
            if byLabel[data[i]] then types[#types + 1] = byLabel[data[i]] end
        end

        data = { types = types, notes = legacyNotes }
    end

    local chosen, labels = {}, {}

    if type(data.types) == 'table' then
        for i = 1, #data.types do
            local entry = allowed[data.types[i]]

            if entry then
                chosen[#chosen + 1] = entry
                labels[#labels + 1] = entry.label
            end
        end
    end

    if #chosen == 0 then return false, 'Selecione ao menos um tipo.' end

    -- A reducao vem da tela, entao so vale se estiver na lista do config.
    -- Aceitar um numero cru daria ao cliente o poder de zerar qualquer pena.
    local reduction = tonumber(data.reduction) or 0
    local validReduction = false

    for i = 1, #Config.Police.reductions do
        if Config.Police.reductions[i] == reduction then validReduction = true break end
    end

    if not validReduction then return false, 'Reducao de pena invalida.' end

    local fines, total = resolveFines(data.fines)
    local officer = Mdt.authorName(source)

    MySQL.prepare.await([[
        INSERT INTO `nv_mdt_arrests`
            (`charId`, `reasons`, `notes`, `fines`, `reduction`, `evidence`, `officer`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { charId, table.concat(labels, ', '):sub(1, 255),
          type(data.notes) == 'string' and data.notes:sub(1, 1000) or nil,
          #fines > 0 and json.encode(fines) or nil,
          reduction,
          type(data.evidence) == 'string' and data.evidence:sub(1, 1000) or nil,
          officer })

    -- As multas atreladas viram divida, exatamente como as multas avulsas.
    --
    -- A reducao de pena NAO desconta a multa: ela reduz tempo de cadeia, que e
    -- outra moeda. Misturar as duas faria com que aceitar 50% de reducao
    -- tambem cortasse metade da divida, e o acordo deixaria de ter custo.
    if #fines > 0 then
        local rows = {}

        for i = 1, #fines do
            rows[#rows + 1] = { charId, 'prisao',
                ('%s — %s'):format(fines[i].label, labels[1]):sub(1, 120),
                fines[i].value, officer }
        end

        MySQL.prepare.await(
            'INSERT INTO `nv_mdt_invoices` (`charId`, `kind`, `label`, `value`, `officer`) VALUES (?, ?, ?, ?, ?)',
            rows)
    end

    local jail = Config.Police.jail
    local baseMinutes = math.max(1, tonumber(jail and jail.minutesPerCharge) or 5) * #chosen
    local sentenceMinutes = math.max(1, math.ceil(baseMinutes * (100 - reduction) / 100))
    local ok, target = pcall(Ox.GetPlayerFromCharId, charId)

    if ok and target and target.source and jail and jail.coords then
        TriggerClientEvent('nv_mdt:client:jail', target.source, sentenceMinutes * 60)
    end

    return true, nil, { total = total, sentence = sentenceMinutes }
end)

-- --------------------------------------------------------- procurados --

--- Coloca ou tira da lista de procurados.
---
--- O tipo penal e o MESMO de "Registrar prisao": um procurado por homicidio e o
--- mesmo tipo que uma prisao por homicidio, e duas listas separadas divergiriam
--- na primeira vez que alguem editasse uma delas.
---
---@param data table|false|nil  { reason, type, evidence } -- falso remove
lib.callback.register('nv_mdt:police:setWanted', function(source, charId, data)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(charId) ~= 'number' then return false, 'Dados invalidos.' end

    -- Nulo/falso = tirar da lista.
    if data == nil or data == false then
        MySQL.query.await('DELETE FROM `nv_mdt_wanted` WHERE `charId` = ?', { charId })
        return true
    end

    -- Compatibilidade: a tela antiga mandava so a string do motivo.
    if type(data) == 'string' then data = { reason = data } end

    if type(data) ~= 'table' or type(data.reason) ~= 'string' or data.reason == '' then
        return false, 'Informe o motivo.'
    end

    local kind = data.type

    if kind ~= nil and not arrestTypeMap()[kind] then
        return false, 'Tipo invalido.'
    end

    MySQL.prepare.await([[
        INSERT INTO `nv_mdt_wanted` (`charId`, `reason`, `type`, `evidence`, `officer`)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `reason`   = VALUES(`reason`),
            `type`     = VALUES(`type`),
            `evidence` = VALUES(`evidence`),
            `officer`  = VALUES(`officer`)
    ]], { charId, data.reason:sub(1, 120), kind,
          type(data.evidence) == 'string' and data.evidence:sub(1, 1000) or nil,
          Mdt.authorName(source) })

    return true
end)

lib.callback.register('nv_mdt:police:wantedList', function(source)
    if not guard(source) then return end

    return MySQL.query.await([[
        SELECT w.`charId`, c.`fullName`, c.`stateId`, w.`reason`, w.`type`,
               w.`evidence`, w.`officer`,
               DATE_FORMAT(w.`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_wanted` w
        JOIN `characters` c ON c.`charId` = w.`charId`
        ORDER BY w.`created` DESC
    ]]) or {}
end)

-- ---------------------------------------------------------- porte de arma --

--- Um cidadao pode receber porte?
---
--- Regra: prisao registrada bloqueia. `Config.Police.gunBlockReasons` vazio
--- significa "qualquer prisao"; preenchido, so os motivos listados bloqueiam.
---@param charId number
---@return boolean, string?
local function gunEligible(charId)
    local arrests = MySQL.query.await(
        'SELECT `reasons` FROM `nv_mdt_arrests` WHERE `charId` = ?', { charId }) or {}

    if #arrests == 0 then return true end

    local blockList = Config.Police.gunBlockReasons

    if not blockList or #blockList == 0 then
        return false, ('Possui prisao registrada: %s'):format(arrests[1].reasons)
    end

    for i = 1, #arrests do
        for j = 1, #blockList do
            if arrests[i].reasons:find(blockList[j], 1, true) then
                return false, ('Prisao por %s'):format(blockList[j])
            end
        end
    end

    return true
end

lib.callback.register('nv_mdt:police:gunCheck', function(source, charId)
    if not guard(source) then return end
    if type(charId) ~= 'number' then return end

    local eligible, reason = gunEligible(charId)

    local has = MySQL.scalar.await(
        'SELECT 1 FROM `character_licenses` WHERE `charId` = ? AND `name` = ?',
        { charId, Config.Licenses.weapon })

    return { eligible = eligible, reason = reason, licensed = has ~= nil }
end)

--- Concede ou cassa o porte. Escreve em `character_licenses` do ox_core.
lib.callback.register('nv_mdt:police:setLicense', function(source, charId, license, grant)
    if not guard(source) then return false, 'Sem permissao.' end
    if type(charId) ~= 'number' then return false, 'Dados invalidos.' end

    if license ~= Config.Licenses.weapon and license ~= Config.Licenses.driver then
        return false, 'Licenca invalida.'
    end

    if grant then
        -- Porte so para quem esta limpo. A CNH nao tem essa trava: cassar e
        -- devolver CNH e decisao do departamento de transito, nao da ficha
        -- criminal.
        if license == Config.Licenses.weapon then
            local eligible, reason = gunEligible(charId)

            if not eligible then
                return false, reason or 'Cidadao nao elegivel.'
            end
        end

        MySQL.prepare.await(
            'INSERT IGNORE INTO `character_licenses` (`charId`, `name`) VALUES (?, ?)',
            { charId, license })

        return true
    end

    MySQL.query.await('DELETE FROM `character_licenses` WHERE `charId` = ? AND `name` = ?',
        { charId, license })

    return true
end)

-- ----------------------------------------------------------- veiculos --

lib.callback.register('nv_mdt:police:vehicle', function(source, plate)
    if not guard(source) then return end
    if type(plate) ~= 'string' or plate == '' then return end

    plate = plate:upper():gsub('%s+$', '')

    local vehicle = MySQL.single.await([[
        SELECT v.`plate`, v.`vin`, v.`model`, v.`stored`,
               c.`fullName` AS owner, c.`charId` AS ownerId
        FROM `vehicles` v
        LEFT JOIN `characters` c ON c.`charId` = v.`owner`
        WHERE v.`plate` = ?
    ]], { plate })

    if not vehicle then return end

    local flag = MySQL.single.await(
        'SELECT `stolen` FROM `nv_mdt_vehicle_flags` WHERE `plate` = ?', { plate })

    vehicle.stolen = flag and (flag.stolen == 1 or flag.stolen == true) or false

    vehicle.seizures = MySQL.query.await([[
        SELECT `reason`, `officer`, DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_seizures` WHERE `plate` = ? ORDER BY `created` DESC
    ]], { plate }) or {}

    -- Multas do DONO: o registro de multa e por pessoa, e associar tudo do
    -- dono ao carro seria mentira. Aqui vao so as que o dono tem, rotuladas
    -- como tal na tela.
    if vehicle.ownerId then
        vehicle.ownerFines = MySQL.query.await([[
            SELECT `label`, `value`, DATE_FORMAT(`created`, '%d/%m/%Y') AS created
            FROM `nv_mdt_fines` WHERE `charId` = ? ORDER BY `created` DESC LIMIT 10
        ]], { vehicle.ownerId }) or {}
    else
        vehicle.ownerFines = {}
    end

    return vehicle
end)

lib.callback.register('nv_mdt:police:trackVehicle', function(source, plate)
    if not guard(source) then return end
    if type(plate) ~= 'string' or plate == '' then return end

    plate = plate:gsub('^%s+', ''):gsub('%s+$', ''):upper()

    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        local entity = vehicles[i]
        local current = (GetVehicleNumberPlateText(entity) or '')
            :gsub('^%s+', ''):gsub('%s+$', ''):upper()

        if current == plate then
            local netId = NetworkGetNetworkIdFromEntity(entity)
            if GetResourceState('nv_garage') == 'started'
                and exports.nv_garage:IsVehicleBlocked(netId) then
                return { blocked = true }
            end

            local coords = GetEntityCoords(entity)
            return { x = coords.x, y = coords.y, z = coords.z }
        end
    end

    return { unavailable = true }
end)

lib.callback.register('nv_mdt:police:setStolen', function(source, plate, stolen)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(plate) ~= 'string' or plate == '' then return false, 'Placa invalida.' end

    plate = plate:upper()

    MySQL.prepare.await([[
        INSERT INTO `nv_mdt_vehicle_flags` (`plate`, `stolen`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `stolen` = VALUES(`stolen`)
    ]], { plate, stolen and 1 or 0 })

    return true
end)

lib.callback.register('nv_mdt:police:seize', function(source, plate, reason)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end

    if type(plate) ~= 'string' or type(reason) ~= 'string' or reason == '' then
        return false, 'Informe o motivo da apreensao.'
    end

    MySQL.prepare.await(
        'INSERT INTO `nv_mdt_seizures` (`plate`, `reason`, `officer`) VALUES (?, ?, ?)',
        { plate:upper(), reason:sub(1, 120), Mdt.authorName(source) })

    return true
end)

lib.callback.register('nv_mdt:police:stolenList', function(source)
    if not guard(source) then return end

    return MySQL.query.await([[
        SELECT f.`plate`, v.`model`, c.`fullName` AS owner
        FROM `nv_mdt_vehicle_flags` f
        LEFT JOIN `vehicles` v ON v.`plate` = f.`plate`
        LEFT JOIN `characters` c ON c.`charId` = v.`owner`
        WHERE f.`stolen` = 1
        ORDER BY f.`plate`
    ]]) or {}
end)

-- -------------------------------------------------------- ocorrencias --

--- Registra ocorrencias geradas por recursos confiaveis do servidor, como o
--- dispatch. Nao e evento de rede e por isso nao aceita chamada direta da NUI.
exports('AddAutomaticReport', function(data)
    if not Mdt.schemaReady or type(data) ~= 'table' then return false end

    local validType = false
    for i = 1, #Config.Police.reportTypes do
        if Config.Police.reportTypes[i].value == data.type then validType = true break end
    end

    if not validType then return false end

    MySQL.prepare.await([[
        INSERT INTO `nv_mdt_reports` (`type`, `citizen`, `phone`, `involved`, `notes`, `author`)
        VALUES (?, ?, NULL, NULL, ?, ?)
    ]], {
        data.type,
        type(data.citizen) == 'string' and data.citizen:sub(1, 100) or nil,
        type(data.notes) == 'string' and data.notes:sub(1, 2000) or nil,
        type(data.author) == 'string' and data.author:sub(1, 80) or 'Sistema'
    })

    return true
end)

--- Historico de ocorrencias, com busca e filtro por periodo.
---
--- A busca cobre cidadao, responsavel e descricao: quem procura uma ocorrencia
--- lembra de UMA dessas tres coisas, e raramente sabe de antemao qual.
---@param filters table? { search, period }
lib.callback.register('nv_mdt:police:reports', function(source, filters)
    if not guard(source) then return end

    filters = type(filters) == 'table' and filters or {}

    local where, args = {}, {}

    if type(filters.search) == 'string' then
        local search = filters.search:gsub('^%s+', ''):gsub('%s+$', '')

        if #search >= 2 then
            local term = like(search)

            where[#where + 1] = '(`citizen` LIKE ? OR `author` LIKE ? OR `notes` LIKE ?)'
            args[#args + 1] = term
            args[#args + 1] = term
            args[#args + 1] = term
        end
    end

    -- O periodo vem por CHAVE e o numero de dias sai do config. Aceitar os dias
    -- direto da tela nao seria perigoso, mas seria a mesma classe de descuido
    -- que deixa passar um valor de multa vindo do cliente.
    if type(filters.period) == 'string' and filters.period ~= 'all' then
        for i = 1, #Config.ReportPeriods do
            local period = Config.ReportPeriods[i]

            if period.key == filters.period and period.days then
                where[#where + 1] = '`created` >= DATE_SUB(NOW(), INTERVAL ? DAY)'
                args[#args + 1] = period.days
                break
            end
        end
    end

    local clause = #where > 0 and ('WHERE %s'):format(table.concat(where, ' AND ')) or ''

    local rows = MySQL.query.await(([[
        SELECT `id`, `type`, `citizen`, `phone`, `involved`, `notes`, `author`,
               DATE_FORMAT(`created`, '%%d/%%m/%%Y %%H:%%i') AS created
        FROM `nv_mdt_reports` %s ORDER BY `created` DESC LIMIT 120
    ]]):format(clause), args) or {}

    -- `involved` sai do banco como texto; a tela espera lista. Decodificar aqui
    -- evita que cada lugar que exibe uma ocorrencia tenha de lembrar disso.
    for i = 1, #rows do
        if rows[i].involved then
            local ok, decoded = pcall(json.decode, rows[i].involved)

            rows[i].involved = (ok and type(decoded) == 'table') and decoded or {}
        else
            rows[i].involved = {}
        end
    end

    return rows
end)

lib.callback.register('nv_mdt:police:addReport', function(source, data)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local valid = false

    for i = 1, #Config.Police.reportTypes do
        if Config.Police.reportTypes[i].value == data.type then valid = true break end
    end

    if not valid then return false, 'Tipo invalido.' end

    -- Envolvidos: so nome e charId, e o charId so entra se o cidadao existir de
    -- verdade. Guardar um id qualquer vindo da tela criaria ocorrencias
    -- apontando para pessoas que nao existem, e o perfil abriria vazio meses
    -- depois sem ninguem entender por que.
    local involved = {}

    if type(data.involved) == 'table' then
        for i = 1, math.min(#data.involved, 12) do
            local entry = data.involved[i]

            if type(entry) == 'table' and type(entry.name) == 'string' then
                local charId = tonumber(entry.charId)

                if charId then
                    local exists = MySQL.scalar.await(
                        'SELECT `charId` FROM `characters` WHERE `charId` = ?', { charId })

                    if not exists then charId = nil end
                end

                involved[#involved + 1] = { charId = charId, name = entry.name:sub(1, 100) }
            end
        end
    end

    MySQL.prepare.await([[
        INSERT INTO `nv_mdt_reports` (`type`, `citizen`, `phone`, `involved`, `notes`, `author`)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { data.type,
          type(data.citizen) == 'string' and data.citizen:sub(1, 100) or nil,
          type(data.phone) == 'string' and data.phone:sub(1, 20) or nil,
          #involved > 0 and json.encode(involved) or nil,
          type(data.notes) == 'string' and data.notes:sub(1, 2000) or nil,
          Mdt.authorName(source) })

    return true
end)

--- Quem esta preenchendo a ocorrencia: nome e telefone do proprio policial.
---
--- O formulario pede os dois, e digitar o proprio nome toda vez e trabalho que
--- o servidor ja sabe fazer -- alem de ser o unico jeito de o campo nao poder
--- ser preenchido com o nome de outra pessoa.
lib.callback.register('nv_mdt:police:self', function(source)
    if not guard(source) then return end

    local player = Ox.GetPlayer(source)
    if not player then return end

    local row = MySQL.single.await(
        'SELECT `fullName`, `phoneNumber` FROM `characters` WHERE `charId` = ?',
        { player.charId })

    return {
        name  = row and row.fullName or Mdt.authorName(source),
        phone = row and row.phoneNumber or nil
    }
end)
