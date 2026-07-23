--[[
    NPWD - Servidor: Exportação e manipulador de Notificações para o Celular
]]

--- Envia notificação de celular para um jogador específico ou para todos (-1)
---@param target number|table Target source (number), -1 (todos) ou tabela de dados se target omitido
---@param data table|nil { app = string, title = string, content = string, duration = number }
local function sendNotification(target, data)
    if type(target) == 'table' and data == nil then
        data = target
        target = -1
    end

    if type(data) ~= 'table' then return end

    if not data.notisId then
        data.notisId = 'notif_' .. tostring(math.random(100000, 999999))
    end

    local targetSrc = tonumber(target) or -1
    TriggerClientEvent('npwd:createNotification', targetSrc, data)
end

exports('createNotification', sendNotification)
exports('sendNotification', sendNotification)
exports('SendNotification', sendNotification)
exports('Notify', sendNotification)

RegisterNetEvent('npwd:serverCreateNotification', function(target, data)
    sendNotification(target, data)
end)

AddEventHandler('npwd:serverCreateNotification', function(target, data)
    sendNotification(target, data)
end)
