--[[
    nv_mdt — servidor: mecanica

    Consulta de veiculo por placa e ordem de servico.
]]

local Ox = require '@ox_core.lib.init'

local function mechanicOrg(source)
    return Mdt.departmentsOf(source).mecanica
end

local function guard(source)
    return mechanicOrg(source) ~= nil
end

--- Veiculo pela placa, com o historico de consertos.
lib.callback.register('nv_mdt:mechanic:vehicle', function(source, plate)
    if not guard(source) then return end
    if type(plate) ~= 'string' or plate == '' then return end

    plate = plate:upper():gsub('%s+$', '')

    local vehicle = MySQL.single.await([[
        SELECT v.`plate`, v.`model`, COALESCE(c.`fullName`, g.`label`) AS owner,
               c.`charId` AS ownerId, v.`group` AS ownerSet
        FROM `vehicles` v
        LEFT JOIN `characters` c ON c.`charId` = v.`owner`
        LEFT JOIN `ox_groups` g ON g.`name` = v.`group`
        WHERE v.`plate` = ?
    ]], { plate })

    if not vehicle then return end

    vehicle.repairs = MySQL.query.await([[
        SELECT `id`, `parts`, `notes`, `total`, `mechanic`, `tow`, `orgSet`,
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
    local org = mechanicOrg(source)
    if not org then return false, 'Sem permissao.' end
    if not Mdt.schemaReady then return false, 'Banco indisponivel.' end
    if type(data) ~= 'table' or type(data.plate) ~= 'string' then return false, 'Dados invalidos.' end

    local player = Ox.GetPlayer(source)
    local permissionOk, permitted = player and pcall(function()
        return player.hasPermission(('group.%s.invoices'):format(org.set))
    end)
    if not permissionOk or permitted ~= true then return false, 'Seu cargo nao pode emitir cobrancas.' end

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

    -- O pagador e resolvido novamente pela placa; nome e charId vindos da NUI
    -- nunca decidem de quem sai o dinheiro.
    local billed = MySQL.single.await([[SELECT v.`owner` AS charId, c.`fullName`
        FROM `vehicles` v LEFT JOIN `characters` c ON c.`charId`=v.`owner`
        WHERE v.`plate`=?]], { data.plate:upper() })
    if not billed or not billed.charId then return false, 'O veiculo nao possui proprietario para cobrar.' end

    local payer = Ox.GetCharacterAccount(billed.charId)
    local business = Ox.GetGroupAccount(org.set)
    if not payer then return false, 'Conta do proprietario indisponivel.' end
    if not business then return false, 'Conta bancaria da oficina indisponivel.' end

    local transferred, transferResult = pcall(function()
        return payer.transferBalance({
            toId = business.accountId,
            amount = total,
            overdraw = Config.Mechanic.allowNegative == true,
            message = ('Servico mecanico - %s'):format(data.plate:upper()),
            note = ('Oficina %s'):format(org.label),
            actorId = player.charId
        })
    end)
    if not transferred or type(transferResult) ~= 'table' or transferResult.success ~= true then
        return false, 'Saldo insuficiente ou transferencia recusada.'
    end

    local inserted, insertError = pcall(MySQL.prepare.await, [[
        INSERT INTO `nv_mdt_repairs`
            (`plate`, `model`, `parts`, `notes`, `billedTo`, `billedCharId`, `tow`, `total`, `mechanic`, `orgSet`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.plate:upper(),
        type(data.model) == 'string' and data.model:sub(1, 60) or nil,
        table.concat(labels, ', '):sub(1, 1000),
        type(data.notes) == 'string' and data.notes:sub(1, 2000) or nil,
        billed.fullName or ('Char %s'):format(billed.charId),
        billed.charId,
        tow and 1 or 0,
        total,
        Mdt.authorName(source),
        org.set
    })

    if not inserted then
        -- A cobranca ocorreu antes da OS. Se a gravacao falhar, devolve pela
        -- mesma infraestrutura bancaria para nao deixar dinheiro sem recibo.
        pcall(function()
            business.transferBalance({
                toId = payer.accountId, amount = total, overdraw = false,
                message = 'Estorno - falha ao registrar ordem', actorId = player.charId
            })
        end)
        lib.print.error(('Falha ao registrar OS mecanica: %s'):format(tostring(insertError)))
        return false, 'A ordem falhou e a cobranca foi estornada.'
    end

    local foundPlayer, billedPlayer = pcall(Ox.GetPlayerFromCharId, billed.charId)
    if not foundPlayer then billedPlayer = nil end
    if billedPlayer and billedPlayer.source then
        TriggerClientEvent('ox_lib:notify', billedPlayer.source, {
            title = org.label,
            description = ('Servico do veiculo %s cobrado: $%d.'):format(data.plate:upper(), total),
            type = 'inform'
        })
    end

    return true, nil, total
end)

lib.callback.register('nv_mdt:mechanic:history', function(source)
    if not guard(source) then return end
    local org=mechanicOrg(source)
    local rows=MySQL.query.await([[
        SELECT `id`, `plate`, `model`, `parts`, `notes`, `billedTo`, `total`, `mechanic`, `tow`, `orgSet`,
               DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS created
        FROM `nv_mdt_repairs` WHERE `orgSet` = ? ORDER BY `created` DESC LIMIT 60
    ]], { org.set }) or {}
    for _,order in ipairs(exports.nv_mechanic:ListOrders(org.set) or {}) do
        rows[#rows+1]={id=order.id,plate=order.plate,model=order.model,parts=order.status=='cancelled' and 'ORDEM CANCELADA' or 'Ordem inspecionada',
            notes=order.cancelReason,billedTo=order.payment or '-',total=order.total,mechanic=order.mechanic,tow=0,orgSet=org.set,
            created=order.finishedLabel or order.createdLabel,status=order.status}
    end
    return rows
end)

local function orderPermission(source)
    local org=mechanicOrg(source);if not org then return end
    local player=Ox.GetPlayer(source);if not player then return end
    local ok,allowed=pcall(function() return player.hasPermission(('group.%s.invoices'):format(org.set)) end)
    return ok and allowed==true and org or nil,player
end

lib.callback.register('nv_mdt:mechanic:orders',function(source)
    local org=mechanicOrg(source);if not org then return {} end
    return exports.nv_mechanic:ListOrders(org.set)
end)

lib.callback.register('nv_mdt:mechanic:order',function(source,id)
    local org=mechanicOrg(source);return org and exports.nv_mechanic:GetOrder(org.set,id) or nil
end)

lib.callback.register('nv_mdt:mechanic:searchVehicles',function(source,query)
    if not guard(source) then return {} end
    return exports.nv_mechanic:SearchVehicles(query)
end)

lib.callback.register('nv_mdt:mechanic:searchCustomer',function(source,query)
    if not guard(source) or type(query)~='string' then return {} end
    query=query:gsub('^%s+',''):gsub('%s+$',''):gsub('^#','');local id=tonumber(query)
    if #query<(id and 1 or 2) then return {} end
    local term='%'..query:gsub('[%%_\\]','\\%0')..'%'
    return MySQL.query.await([[SELECT `charId`,`stateId`,`fullName` FROM `characters`
        WHERE (`fullName` LIKE ? OR `stateId` LIKE ? OR `charId`=?) AND `deleted` IS NULL LIMIT 15]],{term,term,id or -1}) or {}
end)

lib.callback.register('nv_mdt:mechanic:startOrder',function(source,id)
    local org=orderPermission(source);if not org then return false,'Seu cargo nao pode iniciar servicos.' end
    local ok,order=exports.nv_mechanic:StartOrder(org.set,tonumber(id));if not ok then return false,'Esta ordem nao pode ser iniciada.' end
    TriggerClientEvent('nv_mechanic:orderState',source,order);return true,nil,order
end)

lib.callback.register('nv_mdt:mechanic:cancelOrder',function(source,id,reason)
    local org=orderPermission(source);if not org then return false,'Seu cargo nao pode cancelar servicos.' end
    local ok,order=exports.nv_mechanic:CancelOrder(org.set,tonumber(id),reason);if not ok then return false,'Esta ordem nao pode ser cancelada.' end
    TriggerClientEvent('nv_mechanic:clearOrder',source);return true,nil,order
end)

lib.callback.register('nv_mdt:mechanic:completeOrder',function(source,data)
    local org,player=orderPermission(source);if not org then return false,'Seu cargo nao pode concluir servicos.' end
    if type(data)~='table' then return false,'Dados invalidos.' end
    local order=exports.nv_mechanic:GetOrder(org.set,tonumber(data.id));if not order or (order.status~='ready' and order.status~='in_progress') then return false,'Esta ordem nao pode ser concluida.' end
    local repairedTotal,repairedCount=0,0
    for key,done in pairs(order.completedParts or {}) do
        local repaired=done and order.requirements[key]
        if repaired then repairedTotal=repairedTotal+(tonumber(repaired.value) or 0);repairedCount=repairedCount+1 end
    end
    if repairedCount<1 or repairedTotal<1 then return false,'Repare ao menos uma peca antes de concluir.' end
    local payment=data.payment=='invoice' and 'invoice' or 'cash';local customer,invoiceId
    if payment=='cash' then
        if (exports.ox_inventory:GetItemCount(source,'money') or 0)<repairedTotal then return false,'Dinheiro insuficiente para receber o pagamento.' end
        if not exports.ox_inventory:RemoveItem(source,'money',repairedTotal) then return false,'Nao foi possivel registrar o dinheiro.' end
        local account=Ox.GetGroupAccount(org.set)
        local credited,result=pcall(function() return account and account.addBalance({amount=repairedTotal,message=('OS #%d - %s (dinheiro)'):format(order.id,order.plate)}) end)
        if not credited or type(result)~='table' or result.success~=true then exports.ox_inventory:AddItem(source,'money',repairedTotal);return false,'Caixa da oficina indisponivel.' end
    else
        customer=tonumber(data.customerCharId);if not customer then return false,'Selecione o cliente da fatura.' end
        if not MySQL.scalar.await('SELECT 1 FROM `characters` WHERE `charId`=? AND `deleted` IS NULL',{customer}) then return false,'Cliente nao encontrado.' end
        invoiceId=MySQL.insert.await([[INSERT INTO `nv_mdt_invoices` (`charId`,`kind`,`label`,`value`,`officer`)
            VALUES (?,?,?,?,?)]],{customer, (org and org.set) or 'mecanica', ('Ordem de servico #%d - %s'):format(order.id,order.plate),repairedTotal,Mdt.authorName(source)})
        if not invoiceId then return false,'Nao foi possivel criar a fatura.' end
        local targetPlayer = exports.ox_core:GetPlayerByCharId(customer)
        if targetPlayer and targetPlayer.source then
            TriggerEvent('npwd:serverCreateNotification', targetPlayer.source, {
                app = 'bank',
                title = 'Nova Fatura Recebida',
                content = ('Você recebeu uma fatura de $%d referente à OS #%d da Oficina'):format(repairedTotal, order.id)
            })
        end
    end
    local ok,updated=exports.nv_mechanic:CompleteOrder(org.set,order.id,payment,customer,invoiceId,repairedTotal,source)
    if not ok then
        if payment=='cash' then
            local account=Ox.GetGroupAccount(org.set);if account then pcall(function() account.removeBalance({amount=repairedTotal,message=('Estorno OS #%d'):format(order.id)}) end) end
            exports.ox_inventory:AddItem(source,'money',repairedTotal)
        elseif invoiceId then MySQL.update.await('DELETE FROM `nv_mdt_invoices` WHERE `id`=?',{invoiceId}) end
        return false,'A ordem mudou antes da conclusao.'
    end
    TriggerClientEvent('nv_mechanic:clearOrder',source);return true,nil,updated
end)
