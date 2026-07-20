--[[
    nv_mdt — servidor: mecanica

    Consulta de veiculo por placa e ordem de servico.
]]

local function guard(source)
    return Mdt.canAccess(source, 'mecanica')
end

--- Veiculo pela placa, com o historico de consertos.
lib.callback.register('nv_mdt:mechanic:vehicle', function(source, plate)
    if not guard(source) then return end
    if type(plate) ~= 'string' or plate == '' then return end

    plate = plate:upper():gsub('%s+$', '')

    local vehicle = MySQL.single.await([[
        SELECT v.`plate`, v.`model`, c.`fullName` AS owner, c.`charId` AS ownerId
        FROM `vehicles` v
        LEFT JOIN `characters` c ON c.`charId` = v.`owner`
        WHERE v.`plate` = ?
    ]], { plate })

    if not vehicle then return end

    vehicle.repairs = MySQL.query.await([[
        SELECT `id`, `parts`, `notes`, `total`, `mechanic`, `tow`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_repairs` WHERE `plate` = ? ORDER BY `created` DESC LIMIT 20
    ]], { plate }) or {}

    return vehicle
end)

--- Fecha a ordem de servico.
---
--- O total e recalculado aqui pelos precos do config. O que a tela mostra
--- enquanto o mecanico clica nas pecas e uma previa -- se o valor viesse dela,
--- daria para emitir uma nota de qualquer quantia.
lib.callback.register('nv_mdt:mechanic:repair', function(source, data)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(data) ~= 'table' or type(data.plate) ~= 'string' then return false, 'Dados invalidos.' end

    if type(data.parts) ~= 'table' or #data.parts == 0 then
        return false, 'Selecione ao menos uma peca.'
    end

    local labels = {}
    local total = 0

    for _, key in ipairs(data.parts) do
        for _, part in ipairs(Config.Mechanic.parts) do
            if part.key == key then
                labels[#labels + 1] = part.label
                total = total + part.value
                break
            end
        end
    end

    if #labels == 0 then return false, 'Peca invalida.' end

    local tow = data.tow == true

    if tow then total = total + Config.Mechanic.towFee end

    MySQL.prepare.await([[
        INSERT INTO `nv_mdt_repairs`
            (`plate`, `model`, `parts`, `notes`, `billedTo`, `tow`, `total`, `mechanic`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.plate:upper(),
        type(data.model) == 'string' and data.model:sub(1, 60) or nil,
        table.concat(labels, ', '):sub(1, 1000),
        type(data.notes) == 'string' and data.notes:sub(1, 2000) or nil,
        type(data.billedTo) == 'string' and data.billedTo:sub(1, 100) or nil,
        tow and 1 or 0,
        total,
        Mdt.authorName(source)
    })

    return true, nil, total
end)

lib.callback.register('nv_mdt:mechanic:history', function(source)
    if not guard(source) then return end

    return MySQL.query.await([[
        SELECT `id`, `plate`, `model`, `parts`, `notes`, `billedTo`, `total`, `mechanic`, `tow`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_repairs` ORDER BY `created` DESC LIMIT 60
    ]]) or {}
end)
