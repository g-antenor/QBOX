--[[
    nv_mdt — servidor: faturas pendentes

    Multas e custos de prisao viram divida, e nao um desconto imediato na hora
    da abordagem. Um cidadao pode estar sem dinheiro no bolso, e uma multa que
    so existe quando ha saldo nao e uma multa -- e um pedagio para quem por
    acaso estava com dinheiro.

    Os juros nao sao gravados no banco: sao CALCULADOS a cada leitura, a partir
    do valor original e da data de emissao. Guardar o valor ja corrigido exigiria
    uma rotina noturna que, ao falhar uma vez, perderia um dia de juros em
    silencio -- e um numero errado no banco e muito mais dificil de perceber do
    que uma rotina que nao rodou.
]]

local Ox = require '@ox_core.lib.init'

local function guard(source)
    return Mdt.canAccess(source, 'police')
end

-- --------------------------------------------------------------- leitura --

--- Faturas em aberto de um cidadao, ja com juros aplicados.
---@param charId number
---@return table[] rows
---@return number total
function Mdt.pendingInvoices(charId)
    if not Mdt.schemaReady then return {}, 0 end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT `id`, `kind`, `label`, `value`, `officer`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created,
               DATEDIFF(NOW(), `created`) AS days
        FROM `nv_mdt_invoices`
        WHERE `charId` = ? AND `paid` = 0
        ORDER BY `created`
    ]], { charId })

    if not ok or type(rows) ~= 'table' then return {}, 0 end

    local total = 0

    for i = 1, #rows do
        local row = rows[i]
        local amount, days = Mdt.invoiceTotal(row.value, row.days)

        -- `value` continua sendo o original e `total` e o que se paga hoje. A
        -- tela mostra os dois: ver "$250 → $325" explica o atraso sozinho, e
        -- so o numero final pareceria um erro de digitacao.
        row.days = days
        row.total = amount
        row.interest = amount - row.value

        total = total + amount
    end

    return rows, total
end

lib.callback.register('nv_mdt:police:invoices', function(source, charId)
    if not guard(source) then return end
    if type(charId) ~= 'number' then return end

    local rows, total = Mdt.pendingInvoices(charId)

    return { list = rows, total = total }
end)

--- Todas as faturas em aberto do servidor, agrupadas por cidadao.
---
--- E a aba "Faturas pendentes": a policia precisa poder olhar quem deve sem ter
--- de adivinhar um nome para buscar.
lib.callback.register('nv_mdt:police:invoiceList', function(source)
    if not guard(source) then return end
    if not Mdt.schemaReady then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT i.`charId`, c.`fullName`, c.`stateId`,
               COUNT(*) AS count,
               SUM(i.`value`) AS base,
               MAX(DATEDIFF(NOW(), i.`created`)) AS oldest
        FROM `nv_mdt_invoices` i
        JOIN `characters` c ON c.`charId` = i.`charId`
        WHERE i.`paid` = 0
        GROUP BY i.`charId`, c.`fullName`, c.`stateId`
        ORDER BY `base` DESC
        LIMIT 100
    ]])

    if not ok or type(rows) ~= 'table' then return {} end

    -- O total do grupo NAO pode sair de `SUM(value) * juros do mais antigo`:
    -- faturas do mesmo cidadao tem idades diferentes, e a de ontem seria
    -- cobrada com os juros da de tres dias atras. Por isso o total exato e
    -- recalculado fatura a fatura.
    for i = 1, #rows do
        local _, total = Mdt.pendingInvoices(rows[i].charId)

        rows[i].total = total
    end

    return rows
end)

-- ------------------------------------------------------------- cobranca --

--- Cobra faturas a forca.
---
--- `ids` nulo cobra TODAS as faturas em aberto do cidadao.
---
--- A conta pode ficar negativa, e esse e o ponto: sem isso, nao ter saldo seria
--- uma forma de nunca pagar, e bastaria andar quebrado para ser imune a multa.
lib.callback.register('nv_mdt:police:chargeInvoices', function(source, charId, ids)
    if not guard(source) then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(charId) ~= 'number' then return false, 'Dados invalidos.' end

    local rows, total = Mdt.pendingInvoices(charId)

    if #rows == 0 then return false, 'Este cidadao nao tem faturas em aberto.' end

    -- Selecao parcial: filtra pelos ids pedidos e recalcula o total. O valor
    -- NUNCA vem da tela -- ela manda quais faturas, nunca quanto.
    if type(ids) == 'table' and #ids > 0 then
        local wanted = {}

        for i = 1, #ids do wanted[tonumber(ids[i]) or -1] = true end

        local filtered, sum = {}, 0

        for i = 1, #rows do
            if wanted[rows[i].id] then
                filtered[#filtered + 1] = rows[i]
                sum = sum + rows[i].total
            end
        end

        if #filtered == 0 then return false, 'Nenhuma fatura selecionada.' end

        rows, total = filtered, sum
    end

    -- `GetPlayer` recebe source; aqui so temos o charId, e ele pode nem estar
    -- online. Devolve nil sem erro quando o cidadao esta fora.
    local ok, player = pcall(Ox.GetPlayerFromCharId, charId)

    if not ok then player = nil end

    -- O cidadao pode estar offline: a cobranca precisa funcionar mesmo assim,
    -- senao bastaria deslogar para escapar. Por isso o caminho principal e o
    -- ox_banking, que mexe na conta e nao no bolso.
    local charged = false

    local account = Ox.GetCharacterAccount(charId)

    if account then
        local ok, result = pcall(function()
            return account:removeBalance({
                amount = total,
                overdraw = Config.Invoices.allowNegative == true,
                message = 'Faturas - MDT'
            })
        end)

        charged = ok and type(result) == 'table' and result.success == true
    end

    -- Sem ox_banking (ou recusado por falta de saldo, quando o banco nao aceita
    -- negativo) cai para o dinheiro em maos, que so existe se ele estiver
    -- online.
    if not charged then
        if not Config.Invoices.allowNegative then
            return false, 'Saldo insuficiente e a conta nao pode ficar negativa.'
        end

        local target = player and player.source

        if not target then
            return false, 'Nao foi possivel debitar: cidadao offline e banco indisponivel.'
        end

        local cash = exports.ox_inventory:GetItemCount(target, Config.Invoices.account) or 0

        if cash < total then
            return false, ('Saldo insuficiente. Em maos: $%d de $%d.'):format(cash, total)
        end

        if not exports.ox_inventory:RemoveItem(target, Config.Invoices.account, total) then
            return false, 'Nao foi possivel debitar o valor.'
        end
    end

    -- Baixa so DEPOIS do debito. Na ordem inversa, uma falha na cobranca
    -- deixaria a divida quitada de graca.
    local marks = {}

    for i = 1, #rows do marks[#marks + 1] = { rows[i].id } end

    MySQL.prepare.await(
        'UPDATE `nv_mdt_invoices` SET `paid` = 1, `paidAt` = NOW() WHERE `id` = ?',
        marks)

    if player and player.source then
        TriggerClientEvent('ox_lib:notify', player.source, {
            title = 'Faturas',
            description = ('Foram cobradas %d fatura(s), total de $%d.'):format(#rows, total),
            type = 'inform'
        })
    end

    return true, nil, total
end)

--- Divida em aberto de um cidadao. Exposto para outros resources: e o que
--- permite, por exemplo, uma vistoria recusar servico a quem esta devendo.
exports('PendingTotal', function(charId)
    local _, total = Mdt.pendingInvoices(charId)

    return total
end)
