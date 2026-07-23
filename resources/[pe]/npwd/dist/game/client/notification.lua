--[[
    NPWD - Cliente: Manipulador de Notificações NUI do Celular
]]

--- Exibe notificação visual na NUI do celular e toca efeito sonoro
---@param data table { app = string, title = string, content = string, duration = number }
local function sendNotification(data)
    if type(data) ~= 'table' then return end

    if not data.notisId then
        data.notisId = 'notif_' .. tostring(math.random(100000, 999999))
    end

    PlaySoundFrontend(-1, "Notification_Incoming", "GTAO_FM_Events_Soundset", true)

    SendNUIMessage({
        app = "PHONE",
        method = "npwd:createNotification",
        data = data
    })
end

exports('createNotification', sendNotification)
exports('sendNotification', sendNotification)
exports('SendNotification', sendNotification)
exports('Notify', sendNotification)

RegisterNetEvent('npwd:createNotification', function(data)
    sendNotification(data)
end)
