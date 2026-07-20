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

-- ------------------------------------------------------------------ blip --

---@param alert table
local function createBlip(alert)
    local coords = alert.coords
    local info = alert.blip

    -- A area vem primeiro para o icone ficar por cima dela.
    local area = AddBlipForRadius(coords.x, coords.y, coords.z, info.radius)

    SetBlipHighDetail(area, true)
    SetBlipColour(area, info.color)
    SetBlipAlpha(area, info.alpha)

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, info.sprite)
    SetBlipColour(blip, info.color)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(alert.label)
    EndTextCommandSetBlipName(blip)

    blips[area] = true
    blips[blip] = true

    -- O flash e um chamariz para o alerta que acabou de chegar, nao um estado
    -- permanente: um mapa com seis blips piscando nao destaca nenhum.
    SetTimeout(10000, function()
        if DoesBlipExist(blip) then SetBlipFlashes(blip, false) end
    end)

    SetTimeout(info.time * 1000, function()
        if DoesBlipExist(area) then RemoveBlip(area) end
        if DoesBlipExist(blip) then RemoveBlip(blip) end

        blips[area] = nil
        blips[blip] = nil
    end)
end

-- ----------------------------------------------------------- marcar rota --

--- Coloca o waypoint no alerta mais recente.
local function markLatest()
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

lib.addKeybind({
    name = 'nv_dispatch_mark',
    description = 'Marcar no mapa o ultimo chamado',
    defaultKey = Config.MarkKey,
    onPressed = markLatest
})

-- ------------------------------------------------------------ bloqueador --

--- Chamado pelo ox_inventory quando o jogador usa o bloqueador de sinal.
---
--- A barra de progresso roda ANTES do sorteio: se o resultado saisse primeiro,
--- cancelar a barra ao ver que falhou devolveria o item.
local function useJammer()
    if not lib.progressBar({
        duration = Config.Jammer.useTime,
        label = 'Ativando bloqueador...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
    }) then
        return
    end

    local ok, err, duration = lib.callback.await('nv_dispatch:useJammer', false)

    if not ok then
        return lib.notify({
            title = 'Bloqueador de sinal',
            description = err or 'Nao foi possivel.',
            type = 'error'
        })
    end

    lib.notify({
        title = 'Bloqueador de sinal',
        description = ('Sinal cortado por %d segundos.'):format(duration or 0),
        type = 'success'
    })
end

exports('useJammer', useJammer)

-- ------------------------------------------------------------- limpeza --

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
