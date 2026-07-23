--[[
    NPWD - Servidor: Sistema Financeiro do Banco (Maze Bank), Faturas e Transferências por Telefone
]]

local MySQL = MySQL or exports.oxmysql

--- Executa um método da conta ox_core (ex.: removeBalance/addBalance).
--- Necessário porque o objeto retornado por GetCharacterAccount cruza a fronteira
--- de export como tabela de dados pura (apenas `accountId`), SEM os métodos —
--- eles só existem via o proxy `exports.ox_core:CallAccount(accountId, metodo, ...)`.
---@param account table objeto/tabela da conta (precisa de `accountId`)
---@param method string nome do método ('removeBalance' | 'addBalance' | ...)
---@param params table argumentos do método
---@return table|nil resultado ({ success = bool, ... }) ou nil em falha de chamada
local function callAccount(account, method, params)
    if not account or not account.accountId then return nil end
    local ok, res = pcall(function()
        return exports.ox_core:CallAccount(account.accountId, method, params)
    end)
    if not ok then return nil end
    return res
end

--- Helper para obter charId e objeto account da conta do jogador
---@param source number
---@return number|nil charId
---@return table|nil account
local function getPlayerAccount(source)
    if not source or tonumber(source) <= 0 then return nil, nil end

    local charId = nil
    local okChar, pObj = pcall(function()
        return exports.ox_core and exports.ox_core:GetPlayer(source)
    end)

    if okChar and pObj and pObj.charId then
        charId = pObj.charId
    end

    if not charId then return nil, nil end

    local account = nil
    local okAcc, acc = pcall(function()
        return exports.ox_core and exports.ox_core:GetCharacterAccount(charId)
    end)

    if okAcc and acc then
        account = acc
    end

    return charId, account
end

--- Buscar charId e source pelo numero de telefone unico
---@param targetPhone string
---@return number|nil charId
---@return number|nil targetSource
local function getCharIdFromPhoneNumber(targetPhone)
    if not targetPhone or targetPhone == '' then return nil, nil end

    local rawPhone = tostring(targetPhone)
    local cleanPhone = rawPhone:gsub("%D", "")
    if cleanPhone == '' then cleanPhone = rawPhone end

    -- Buscar o charId na tabela `characters` pela coluna correta do ox_core: `phoneNumber`.
    -- A comparação ignora máscara (hífen/espaço/+) dos dois lados.
    local charId = nil
    local okDb, row = pcall(MySQL.single.await, [[
        SELECT `charId` FROM `characters`
        WHERE REPLACE(REPLACE(REPLACE(`phoneNumber`, '-', ''), ' ', ''), '+', '') = ?
        LIMIT 1
    ]], { cleanPhone })

    if okDb and row and row.charId then
        charId = row.charId
    end

    if not charId then return nil, nil end

    -- Resolver o source se o destinatário estiver online (nil se offline).
    local targetSource = nil
    local okTp, targetPlayer = pcall(function()
        return exports.ox_core and exports.ox_core:GetPlayerFromCharId(charId)
    end)
    if okTp and targetPlayer and targetPlayer.source then
        targetSource = targetPlayer.source
    end

    return charId, targetSource
end

--- Callback para buscar dados consolidados do banco (Saldo, Extrato e Faturas)
lib.callback.register('npwd:bank:getData', function(source)
    local charId, account = getPlayerAccount(source)
    if not charId then
        return { balance = 0, accountNumber = "#0000", statement = {}, invoices = {}, invoicesTotal = 0 }
    end

    local balance = 0
    if account and type(account.balance) == 'number' then
        balance = account.balance
    end

    -- Consulta direta no banco de dados para garantir sincronizacao total de saldo
    local okBalRow, balRow = pcall(MySQL.single.await, [[
        SELECT `balance` FROM `accounts` WHERE `owner` = ? AND `type` = 'personal' LIMIT 1
    ]], { charId })

    if okBalRow and balRow and type(balRow.balance) == 'number' then
        balance = balRow.balance
    end

    if balance == 0 then
        local okInvCount, moneyCount = pcall(function()
            return exports.ox_inventory and exports.ox_inventory:GetItemCount(source, 'money')
        end)
        if okInvCount and moneyCount and moneyCount > 0 then
            balance = moneyCount
        end
    end

    -- 1. Buscar faturas em aberto da tabela `nv_mdt_invoices`
    local invoices = {}
    local invoicesTotal = 0

    local okInv, rowsInv = pcall(MySQL.query.await, [[
        SELECT `id`, `kind`, `label`, `value`, `officer`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created,
               DATEDIFF(NOW(), `created`) AS days
        FROM `nv_mdt_invoices`
        WHERE `charId` = ? AND `paid` = 0
        ORDER BY `created` DESC
    ]], { charId })

    if okInv and type(rowsInv) == 'table' then
        for i = 1, #rowsInv do
            local row = rowsInv[i]
            local days = math.max(0, math.floor(row.days or 0))
            local rate = 0.1 -- 10% ao dia por atraso
            local total = math.floor(row.value + (row.value * rate * math.min(days, 3)))

            -- Resolver o nome real da ORG emissora para exibir na embed verde.
            -- A coluna `kind` guarda: o `org.set` (grupo) nas faturas de mecânica
            -- e strings fixas ('multa'/'prisao') nas de polícia.
            local kindLabel = nil
            if row.kind and row.kind ~= '' then
                -- 1) Via principal e confiável: a tabela `ox_groups` (name -> label).
                local okDbG, gRow = pcall(MySQL.single.await, "SELECT `label` FROM `ox_groups` WHERE `name` = ? LIMIT 1", { row.kind })
                if okDbG and gRow and gRow.label and gRow.label ~= '' then
                    kindLabel = gRow.label
                end
            end

            -- 2) Mapeamento por tipo (faturas de polícia não gravam o grupo).
            if not kindLabel or kindLabel == '' then
                local kLower = string.lower(row.kind or '')
                if kLower:find('police') or kLower:find('policia') or kLower == 'multa' or kLower == 'prisao' then
                    kindLabel = 'Polícia Militar'
                elseif kLower:find('mechanic') or kLower:find('mecanica') then
                    kindLabel = 'Oficina Mecânica'
                elseif kLower:find('hospital') or kLower:find('medico') then
                    kindLabel = 'Centro Médico'
                elseif row.kind and row.kind ~= '' then
                    kindLabel = row.kind:gsub("^%l", string.upper)
                else
                    kindLabel = 'Cobrança'
                end
            end

            invoices[#invoices + 1] = {
                id = row.id,
                kind = kindLabel,
                label = row.label or 'Fatura / Multa',
                officer = row.officer or 'Emissor Oficial',
                value = row.value,
                days = days,
                total = total,
                date = row.created or 'Hoje'
            }
            invoicesTotal = invoicesTotal + total
        end
    end

    -- 2. Buscar extrato de movimentações (ox_banking_logs ou nv_mdt_invoices pagas)
    local statement = {}

    local okLog, rowsLog = pcall(MySQL.query.await, [[
        SELECT `id`, `amount`, `message`, `name`, `type`,
               DATE_FORMAT(`date`, '%d/%m %H:%i') AS formattedDate
        FROM `ox_banking_logs`
        WHERE `charId` = ? OR `target` = ?
        ORDER BY `id` DESC LIMIT 20
    ]], { charId, charId })

    if okLog and type(rowsLog) == 'table' and #rowsLog > 0 then
        for i = 1, #rowsLog do
            local l = rowsLog[i]
            statement[#statement + 1] = {
                id = l.id,
                type = l.type or 'transaction',
                label = l.message or l.name or 'Movimentação Bancária',
                amount = l.amount,
                date = l.formattedDate or 'Recentemente'
            }
        end
    end

    if #statement == 0 then
        local okPaid, rowsPaid = pcall(MySQL.query.await, [[
            SELECT `id`, `label`, `value`, `kind`,
                   DATE_FORMAT(`paidAt`, '%d/%m %H:%i') AS paidDate
            FROM `nv_mdt_invoices`
            WHERE `charId` = ? AND `paid` = 1
            ORDER BY `paidAt` DESC LIMIT 10
        ]], { charId })

        if okPaid and type(rowsPaid) == 'table' then
            for i = 1, #rowsPaid do
                local p = rowsPaid[i]
                statement[#statement + 1] = {
                    id = 'inv_' .. p.id,
                    type = 'invoice',
                    label = 'Fatura Paga: ' .. (p.label or 'MDT'),
                    amount = -p.value,
                    date = p.paidDate or 'Recentemente'
                }
            end
        end

        statement[#statement + 1] = {
            id = 'init_bal',
            type = 'deposit',
            label = 'Saldo em Conta (Maze Bank)',
            amount = balance,
            date = 'Hoje'
        }
    end

    -- 3. Obter nome real do cidadão e número de telefone
    local charName = nil
    local phoneNumber = nil

    local okChar, pObj = pcall(function() return exports.ox_core and exports.ox_core:GetPlayer(source) end)
    if okChar and pObj then
        local okFn, fn = pcall(function() return pObj.get and pObj.get('firstName') end)
        local okLn, ln = pcall(function() return pObj.get and pObj.get('lastName') end)
        if okFn and fn and okLn and ln then
            charName = tostring(fn) .. ' ' .. tostring(ln)
        end

        if not charName then
            local okFull, full = pcall(function() return pObj.get and pObj.get('fullName') end)
            if okFull and full and type(full) == 'string' and full ~= '' then
                charName = full
            end
        end

        if not charName and pObj.firstName and pObj.lastName then
            charName = tostring(pObj.firstName) .. ' ' .. tostring(pObj.lastName)
        end

        local okP, resP = pcall(function() return pObj:getPhoneNumber() end)
        if okP and resP then phoneNumber = tostring(resP) end
    end

    -- Consultar na tabela characters do ox_core (colunas: firstName, lastName, fullName, phoneNumber)
    local okDbName, nameRow = pcall(MySQL.single.await, [[
        SELECT `firstName`, `lastName`, `fullName`, `phoneNumber`
        FROM `characters` WHERE `charId` = ? LIMIT 1
    ]], { charId })

    if okDbName and nameRow then
        if not charName or charName == "" or charName == "Cidadão NV2" then
            if nameRow.fullName and nameRow.fullName ~= '' then
                charName = nameRow.fullName
            elseif nameRow.firstName and nameRow.lastName then
                charName = nameRow.firstName .. ' ' .. nameRow.lastName
            end
        end

        if not phoneNumber or phoneNumber == '' then
            if nameRow.phoneNumber and nameRow.phoneNumber ~= '' then
                phoneNumber = nameRow.phoneNumber
            end
        end
    end

    if not charName or charName == "" then
        local steamName = GetPlayerName(tostring(source))
        if steamName and steamName ~= "" then
            charName = steamName
        else
            charName = ("Cidadão #%04d"):format(charId)
        end
    end

    if not phoneNumber or phoneNumber == '' then
        phoneNumber = ("555-%04d"):format(charId)
    end

    return {
        balance = balance,
        accountNumber = ("#%04d"):format(charId),
        charId = charId,
        charName = charName,
        phoneNumber = phoneNumber,
        statement = statement,
        invoices = invoices,
        invoicesTotal = invoicesTotal
    }
end)

--- Callback para realizar transferência bancária por número de telefone
lib.callback.register('npwd:bank:transfer', function(source, targetPhone, amount)
    local senderCharId, senderAccount = getPlayerAccount(source)
    if not senderCharId or not senderAccount then
        return { success = false, message = "Não foi possível acessar sua conta bancária." }
    end

    amount = math.floor(tonumber(amount) or 0)
    targetPhone = tostring(targetPhone or ''):gsub("%s+", "")

    if targetPhone == '' then
        return { success = false, message = "Informe o número de telefone do destinatário." }
    end

    if amount <= 0 then
        return { success = false, message = "Especifique um valor maior que zero." }
    end

    -- Obter saldo atual diretamente do banco de dados ou da conta
    local currentBalance = senderAccount.balance or 0
    local okBalRow, balRow = pcall(MySQL.single.await, [[
        SELECT `balance` FROM `accounts` WHERE `owner` = ? AND `type` = 'personal' LIMIT 1
    ]], { senderCharId })

    if okBalRow and balRow and type(balRow.balance) == 'number' then
        currentBalance = balRow.balance
    end

    if currentBalance < amount then
        return { success = false, message = ("Saldo insuficiente! Saldo em conta: $%d"):format(currentBalance) }
    end

    -- Buscar destinatario por telefone
    local targetCharId, targetSource = getCharIdFromPhoneNumber(targetPhone)
    if not targetCharId then
        return { success = false, message = ("Nenhum destinatário encontrado com o telefone '%s'."):format(targetPhone) }
    end

    if senderCharId == targetCharId then
        return { success = false, message = "Você não pode transferir para seu próprio número de telefone." }
    end

    -- Buscar conta bancaria do destinatario via ox_core
    local targetAccount = nil
    local okTargetAcc, tAcc = pcall(function()
        return exports.ox_core and exports.ox_core:GetCharacterAccount(targetCharId)
    end)

    if okTargetAcc and tAcc then
        targetAccount = tAcc
    end

    if not targetAccount then
        return { success = false, message = "Conta bancária do destinatário indisponível." }
    end

    -- 1. Debitar da conta do remetente
    local debitRes = callAccount(senderAccount, 'removeBalance', {
        amount = amount,
        overdraw = false,
        message = ("Transferência para Tel: %s"):format(targetPhone)
    })

    if type(debitRes) ~= 'table' or debitRes.success ~= true then
        return { success = false, message = "Falha ao debitar valor da sua conta bancária." }
    end

    -- 2. Creditar na conta do destinatario
    callAccount(targetAccount, 'addBalance', {
        amount = amount,
        message = ("Transferência recebida (Tel: %s)"):format(targetPhone)
    })

    -- 3. Sincronizar com tabela de logs do ox_banking se disponivel
    pcall(MySQL.insert.await, [[
        INSERT INTO `ox_banking_logs` (`charId`, `target`, `amount`, `message`, `type`, `date`)
        VALUES (?, ?, ?, ?, 'transfer', NOW())
    ]], { senderCharId, targetCharId, amount, ("Transferência para Tel %s"):format(targetPhone) })

    -- 4. Enviar notificação no celular do destinatario
    if targetSource then
        TriggerEvent('npwd:serverCreateNotification', targetSource, {
            app = 'bank',
            title = 'Transferência Recebida',
            content = ('Você recebeu $%s via transferência bancária.'):format(amount)
        })
    end

    return {
        success = true,
        message = ("Transferência de $%d enviada com sucesso para %s!"):format(amount, targetPhone),
        newBalance = senderAccount.balance or (currentBalance - amount)
    }
end)

--- Callback para pagar faturas (individual ou todas)
lib.callback.register('npwd:bank:payInvoice', function(source, invoiceId, payAll)
    local charId, account = getPlayerAccount(source)
    if not charId or not account then
        return { success = false, message = "Conta bancária indisponível." }
    end

    local query = "SELECT `id`, `kind`, `label`, `value`, `officer`, DATEDIFF(NOW(), `created`) AS days FROM `nv_mdt_invoices` WHERE `charId` = ? AND `paid` = 0"
    local params = { charId }

    if not payAll and invoiceId then
        query = query .. " AND `id` = ?"
        params[#params + 1] = invoiceId
    end

    local rows = MySQL.query.await(query, params)
    if not rows or #rows == 0 then
        return { success = false, message = "Nenhuma fatura pendente para pagamento." }
    end

    local totalAmount = 0
    local invoiceIds = {}

    for i = 1, #rows do
        local r = rows[i]
        local days = math.max(0, math.floor(r.days or 0))
        local rate = 0.1
        local itemTotal = math.floor(r.value + (r.value * rate * math.min(days, 3)))
        totalAmount = totalAmount + itemTotal
        invoiceIds[#invoiceIds + 1] = r.id
    end

    local currentBalance = account.balance or 0
    local okBalRow, balRow = pcall(MySQL.single.await, [[
        SELECT `balance` FROM `accounts` WHERE `owner` = ? AND `type` = 'personal' LIMIT 1
    ]], { charId })

    if okBalRow and balRow and type(balRow.balance) == 'number' then
        currentBalance = balRow.balance
    end

    if currentBalance < totalAmount then
        return { success = false, message = ("Saldo insuficiente! Total das faturas: $%d | Saldo: $%d"):format(totalAmount, currentBalance) }
    end

    -- Debitar valor total da conta bancaria ox_core
    local debitRes = callAccount(account, 'removeBalance', {
        amount = totalAmount,
        overdraw = false,
        message = ("Pagamento de %d Fatura(s) - NV2"):format(#rows)
    })

    if type(debitRes) ~= 'table' or debitRes.success ~= true then
        return { success = false, message = "Falha no débito bancário para quitação da(s) fatura(s)." }
    end

    -- Marcar faturas como pagas em `nv_mdt_invoices`
    for i = 1, #invoiceIds do
        MySQL.update.await("UPDATE `nv_mdt_invoices` SET `paid` = 1, `paidAt` = NOW() WHERE `id` = ?", { invoiceIds[i] })
    end

    -- Gravar log bancario sincronizado no ox_banking
    pcall(MySQL.insert.await, [[
        INSERT INTO `ox_banking_logs` (`charId`, `amount`, `message`, `type`, `date`)
        VALUES (?, ?, ?, 'invoice', NOW())
    ]], { charId, totalAmount, ("Pagamento de %d fatura(s)"):format(#rows) })

    return {
        success = true,
        message = ("%d fatura(s) paga(s) no valor total de $%d!"):format(#rows, totalAmount),
        paidCount = #rows,
        totalPaid = totalAmount,
        newBalance = account.balance or (currentBalance - totalAmount)
    }
end)

--- Exportação publica para emitir notificação de nova fatura no celular do jogador
---@param targetPlayerOrCharId number Source do jogador ou charId
---@param amount number Valor da fatura
---@param issuerName string Nome do emissor (Ex: Polícia, Mecânica)
---@param label string Motivo ou descrição
local function notifyInvoice(targetPlayerOrCharId, amount, issuerName, label)
    if not targetPlayerOrCharId then return end

    local targetSrc = tonumber(targetPlayerOrCharId)
    if not targetSrc or targetSrc <= 0 or not GetPlayerName(tostring(targetSrc)) then
        local okP, p = pcall(function()
            return exports.ox_core and exports.ox_core:GetPlayerFromCharId(tonumber(targetPlayerOrCharId))
        end)
        targetSrc = okP and p and p.source
    end

    if not targetSrc then return end

    TriggerEvent('npwd:serverCreateNotification', targetSrc, {
        app = 'bank',
        title = 'Nova Fatura Recebida',
        content = ('Você recebeu uma fatura de $%s emitida por %s (%s).'):format(
            tostring(amount or 0),
            tostring(issuerName or 'MDT'),
            tostring(label or 'Cobrança')
        )
    })
end

exports('notifyInvoice', notifyInvoice)
AddEventHandler('npwd:notifyInvoice', notifyInvoice)

print('^2[nv_phone:bank] Módulo bancário carregado com sucesso.^7')
