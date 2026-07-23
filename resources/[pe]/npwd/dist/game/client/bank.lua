--[[
    NPWD - Cliente: Callbacks NUI para Banco (Maze Bank), Transferências por Telefone e Faturas
]]

RegisterNuiCallback('npwd:bank:fetchData', function(data, cb)
    local ok, result = pcall(function()
        return lib.callback.await('npwd:bank:getData', false)
    end)

    if ok and type(result) == 'table' then
        cb(result)
    else
        cb({ balance = 0, accountNumber = "#0000", statement = {}, invoices = {}, invoicesTotal = 0 })
    end
end)

RegisterNuiCallback('npwd:bank:transfer', function(data, cb)
    if type(data) ~= 'table' then
        cb({ success = false, message = "Dados inválidos." })
        return
    end

    local ok, result = pcall(function()
        return lib.callback.await('npwd:bank:transfer', false, data.targetPhone, data.amount)
    end)

    if ok and type(result) == 'table' then
        cb(result)
    else
        cb({ success = false, message = "Erro ao conectar com o servidor para transferência." })
    end
end)

RegisterNuiCallback('npwd:bank:payInvoice', function(data, cb)
    if type(data) ~= 'table' then
        cb({ success = false, message = "Dados inválidos." })
        return
    end

    local ok, result = pcall(function()
        return lib.callback.await('npwd:bank:payInvoice', false, data.invoiceId, data.payAll)
    end)

    if ok and type(result) == 'table' then
        cb(result)
    else
        cb({ success = false, message = "Erro ao conectar com o servidor para pagamento." })
    end
end)
