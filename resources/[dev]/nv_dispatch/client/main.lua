--[[
    nv_dispatch — cliente

    Recebe alertas do servidor, desenha na tela e cria o blip. Nao decide nada:
    se este arquivo recebeu um alerta, e porque o servidor ja concluiu que este
    jogador devia receber.
]]

-- Alertas vivos, do mais novo para o mais velho.
---@type table[]
local recent = {}

-- Blips criados por alertas, para apagar quando esfriam.
---@type table<number, boolean>
local blips = {}
local alertBlips = {}

local function removeAlertBlips(alertId)
    local pair = alertBlips[alertId]
    if not pair then return end

    for _, blip in pairs(pair) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        blips[blip] = nil
    end

    alertBlips[alertId] = nil
end

-- ------------------------------------------------------------------ blip --

---@param alert table
local function createBlip(alert)
    local coords = alert.coords
    local info = alert.blip

    local area
    if info.area ~= false then
        area = AddBlipForRadius(coords.x, coords.y, coords.z, info.radius)
        SetBlipHighDetail(area, true)
        SetBlipColour(area, info.color)
        SetBlipAlpha(area, info.alpha)
        blips[area] = true
    end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, info.sprite)
    SetBlipColour(blip, info.color)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    if info.flash then SetBlipFlashTimer(blip, info.time * 1000) end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(alert.label)
    EndTextCommandSetBlipName(blip)

    blips[blip] = true
    alertBlips[alert.id] = { area = area, blip = blip }

    -- O flash e um chamariz para o alerta que acabou de chegar, nao um estado
    -- permanente: um mapa com seis blips piscando nao destaca nenhum.
    SetTimeout(info.flash and info.time * 1000 or 10000, function()
        if DoesBlipExist(blip) then SetBlipFlashes(blip, false) end
    end)

    SetTimeout(info.time * 1000, function()
        removeAlertBlips(alert.id)
    end)
end

--- Limpa todos os alertas e blips ativos do dispatch quando o jogador sai de servico.
local function clearDispatch()
    recent = {}
    for alertId in pairs(alertBlips) do
        removeAlertBlips(alertId)
    end
    for blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
    alertBlips = {}
    SendNUIMessage({ action = 'clear' })
end

-- ----------------------------------------------------------- marcar rota --

--- Coloca o waypoint no alerta mais recente.
local function markLatest()
    if not LocalPlayer.state.duty then
        return lib.notify({
            title = 'Dispatch',
            description = 'Voce nao esta em servico.',
            type = 'inform'
        })
    end

    local alert = recent[1]

    if not alert then
        return lib.notify({
            title = 'Dispatch',
            description = 'Nenhum chamado recente.',
            type = 'inform'
        })
    end

    SetNewWaypoint(alert.coords.x, alert.coords.y)

    lib.notify({
        title = 'Dispatch',
        description = ('Rota tracada: %s'):format(alert.label),
        type = 'success'
    })
end

exports('MarkLatest', markLatest)

--- Marca um chamado qualquer no mapa. E o que o botao "marcar no mapa" da lista
--- de chamados do MDT usa -- por isso e export, e nao so a bind.
exports('MarkCoords', function(x, y)
    x, y = tonumber(x), tonumber(y)

    if not x or not y then return false end

    SetNewWaypoint(x, y)

    return true
end)

-- --------------------------------------------------------------- alertas --

RegisterNetEvent('nv_dispatch:alert', function(alert)
    if not LocalPlayer.state.duty then return end
    if type(alert) ~= 'table' or type(alert.coords) ~= 'table' then return end

    -- Nome da rua so pode ser resolvido no cliente: as natives de mapa nao
    -- existem no servidor. Por isso o alerta chega sem rua e ganha uma aqui.
    if not alert.street then
        local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(
            alert.coords.x, alert.coords.y, alert.coords.z))

        alert.street = street ~= '' and street or 'Local desconhecido'
    end

    table.insert(recent, 1, alert)

    while #recent > Config.MaxOnScreen do
        table.remove(recent)
    end

    createBlip(alert)

    SendNUIMessage({
        action       = 'alert',
        alert        = alert,
        duration     = Config.Duration,
        markKey      = Config.MarkKey,
        maxOnScreen  = Config.MaxOnScreen
    })

    if Config.Sound then
        PlaySoundFrontend(-1, Config.Sound.name, Config.Sound.set, true)
    end
end)

RegisterNetEvent('nv_dispatch:stopAlert', function(alertId)
    if type(alertId) ~= 'string' then return end
    removeAlertBlips(alertId)
end)

RegisterNetEvent('nv_dispatch:updateAlert', function(alertId, coords)
    if not LocalPlayer.state.duty then return end
    if type(alertId) ~= 'string' or type(coords) ~= 'table' then return end

    local pair = alertBlips[alertId]
    if not pair then return end

    for _, blip in pairs(pair) do
        if DoesBlipExist(blip) then SetBlipCoords(blip, coords.x, coords.y, coords.z) end
    end

    for i = 1, #recent do
        if recent[i].id == alertId then
            recent[i].coords = coords
            break
        end
    end
end)

AddStateBagChangeHandler('duty', ('player:%d'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if not value then
        clearDispatch()
    end
end)

lib.addKeybind({
    name = 'nv_dispatch_mark',
    description = 'Marcar no mapa o ultimo chamado',
    defaultKey = Config.MarkKey,
    onPressed = markLatest
})

-- ------------------------------------------------------------- limpeza --

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
