--[[
    nv_mdt — servidor: hospital

    Pacientes, consultas e anotacoes.

    O paciente e um personagem do ox_core (`charId`), e nao um nome digitado:
    assim o historico segue a pessoa mesmo que ela troque de nome, e duas
    pessoas homonimas nao compartilham prontuario.
]]

local function guard(source)
    return Mdt.canAccess(source, 'hospital')
end

---@param term string
---@return string
local function like(term)
    return '%' .. term:gsub('[%%_\\]', '\\%0') .. '%'
end

-- ----------------------------------------------------------- paciente --

lib.callback.register('nv_mdt:hospital:search', function(source, query)
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

lib.callback.register('nv_mdt:hospital:patient', function(source, charId)
    if not guard(source) then return end
    if type(charId) ~= 'number' then return end

    local patient = MySQL.single.await([[
        SELECT `charId`, `stateId`, `fullName`, `gender`,
               DATE_FORMAT(`dateOfBirth`, '%d/%m/%Y') AS dob,
               TIMESTAMPDIFF(YEAR, `dateOfBirth`, CURDATE()) AS age
        FROM `characters` WHERE `charId` = ? AND `deleted` IS NULL
    ]], { charId })

    if not patient then return end

    patient.history = MySQL.query.await([[
        SELECT `id`, `reasons`, `total`, `doctor`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_consults` WHERE `charId` = ? ORDER BY `created` DESC LIMIT 40
    ]], { charId }) or {}

    patient.notes = MySQL.query.await([[
        SELECT `id`, `notes`, `author`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_notes` WHERE `charId` = ? ORDER BY `created` DESC LIMIT 40
    ]], { charId }) or {}

    return patient
end)

lib.callback.register('nv_mdt:hospital:addNote', function(source, charId, notes)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end

    if type(charId) ~= 'number' or type(notes) ~= 'string' or notes == '' then
        return false, 'Escreva a anotacao.'
    end

    MySQL.prepare.await(
        'INSERT INTO `nv_mdt_notes` (`charId`, `notes`, `author`) VALUES (?, ?, ?)',
        { charId, notes:sub(1, 2000), Mdt.authorName(source) })

    return true
end)

-- ----------------------------------------------------------- consulta --

--- Preco da consulta, calculado SEMPRE aqui.
---
--- A tela mostra um total enquanto o medico monta a consulta, mas aquele
--- numero e so previsao: quem cobra e este calculo, com os precos do config.
--- Aceitar o total da NUI deixaria qualquer um cobrar o que quisesse.
---@param data table
---@return number total
---@return table breakdown
local function priceOf(data)
    local cfg = Config.Hospital
    local injuries = 0

    for _, zone in ipairs(cfg.bodyZones) do
        local severity = tonumber(data.injuries and data.injuries[zone.key]) or 0

        severity = math.max(0, math.min(cfg.maxSeverity, math.floor(severity)))
        injuries = injuries + severity * cfg.pricePerInjury
    end

    local resources = 0

    for _, key in ipairs(data.resources or {}) do
        for _, item in ipairs(cfg.resources) do
            if item.key == key then
                resources = resources + item.value
                break
            end
        end
    end

    local hours = math.max(0, math.min(48, tonumber(data.hours) or 0))
    local hourCost = math.floor(hours * cfg.pricePerHour)
    local rescue = data.rescue and cfg.rescueFee or 0

    return injuries + resources + hourCost + rescue, {
        injuries = injuries,
        resources = resources,
        hours = hourCost,
        rescue = rescue
    }
end

lib.callback.register('nv_mdt:hospital:consult', function(source, data)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local charId = tonumber(data.charId)
    local name

    if charId then
        name = MySQL.scalar.await('SELECT `fullName` FROM `characters` WHERE `charId` = ?', { charId })

        if not name then return false, 'Paciente nao encontrado.' end
    else
        -- Atendimento de alguem sem ficha (turista, indigente): aceita o nome
        -- solto, mas sem `charId` o historico nao gruda em ninguem.
        name = type(data.name) == 'string' and data.name ~= '' and data.name:sub(1, 100) or nil

        if not name then return false, 'Selecione o paciente.' end
    end

    -- Motivos validos so os do config.
    local reasons = {}

    for _, key in ipairs(data.reasons or {}) do
        for _, item in ipairs(Config.Hospital.reasons) do
            if item.key == key then
                reasons[#reasons + 1] = item.label
                break
            end
        end
    end

    local total = priceOf(data)

    MySQL.prepare.await([[
        INSERT INTO `nv_mdt_consults`
            (`charId`, `name`, `reasons`, `injuries`, `resources`, `hours`, `rescue`, `total`, `doctor`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        charId, name,
        table.concat(reasons, ', '):sub(1, 255),
        json.encode(data.injuries or {}),
        json.encode(data.resources or {}),
        math.max(0, math.min(48, tonumber(data.hours) or 0)),
        data.rescue and 1 or 0,
        total,
        Mdt.authorName(source)
    })

    return true, nil, total
end)

lib.callback.register('nv_mdt:hospital:history', function(source)
    if not guard(source) then return end

    return MySQL.query.await([[
        SELECT `id`, `name`, `reasons`, `total`, `doctor`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_consults` ORDER BY `created` DESC LIMIT 60
    ]]) or {}
end)

-- ----------------------------------------------------------- chamados --

lib.callback.register('nv_mdt:hospital:addCall', function(source, data)
    if not guard(source) then return false, 'Sem permissao.' end
    if type(data) ~= 'table' then return false, 'Dados invalidos.' end

    if not Mdt.addCall('hospital', data) then
        return false, 'Informe o titulo do chamado.'
    end

    return true
end)

lib.callback.register('nv_mdt:hospital:calls', function(source)
    if not guard(source) then return end

    return Mdt.getCalls('hospital', Config.Calls.keep)
end)
