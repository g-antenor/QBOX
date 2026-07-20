--[[
    nv_radio — cliente

    A transmissão em si é do pma-voice: ele já tem o push-to-talk (+radiotalk,
    LMENU por padrão), a animação e o som de clique. Este resource cuida do
    aparelho: ligar/desligar, sintonizar e sair do canal quando não deve mais
    estar nele.
]]

local voice = exports['pma-voice']

local radio = {
    open = false,
    power = false,
    frequency = Config.DefaultFrequency,
    volume = Config.DefaultVolume,
    micClick = Config.MicClickDefault,
}

-- Frequências guardadas pelo jogador (persistem entre sessões via KVP).
local KVP_KEY = 'nv_radio:saved'
local saved = {}

-- --------------------------------------------------------- filtro de voz --

--- Substitui o submix de rádio do pma-voice por um mais fechado, deixando a
--- voz com timbre de transmissão em vez de fala limpa.
local function applyVoiceFilter()
    local filter = Config.VoiceFilter
    if not filter or not filter.enabled then return end

    local submix = CreateAudioSubmix('nv_radio')

    SetAudioSubmixEffectRadioFx(submix, 0)
    SetAudioSubmixEffectParamInt(submix, 0, GetHashKey('default'), 1)
    SetAudioSubmixEffectParamFloat(submix, 0, GetHashKey('freq_low'), filter.freqLow)
    SetAudioSubmixEffectParamFloat(submix, 0, GetHashKey('freq_hi'), filter.freqHigh)
    SetAudioSubmixEffectParamFloat(submix, 0, GetHashKey('fudge'), 0.0)
    SetAudioSubmixEffectParamFloat(submix, 0, GetHashKey('rm_mod_freq'), 0.0)
    SetAudioSubmixEffectParamFloat(submix, 0, GetHashKey('rm_mix'), filter.rmMix)
    SetAudioSubmixEffectParamFloat(submix, 0, GetHashKey('o_freq_lo'), filter.outLow)
    SetAudioSubmixEffectParamFloat(submix, 0, GetHashKey('o_freq_hi'), filter.outHigh)

    SetAudioSubmixOutputVolumes(submix, 0, 1.0, 0.25, 0.0, 0.0, 1.0, 1.0)
    AddAudioSubmixOutput(submix, 0)

    voice:setEffectSubmix('radio', submix)
end

-- ------------------------------------------------------------------ util --

--- Frequência exibida (12.5) -> canal do pma-voice (125).
---@param frequency number
---@return number
local function toChannel(frequency)
    return math.floor(frequency * 10 + 0.5)
end

---@param frequency number
---@return string
local function labelFor(frequency)
    local key = tonumber(('%.1f'):format(frequency))

    return Config.Labels[key] or 'LIVRE'
end

---@return boolean
local function hasRadio()
    return (exports.ox_inventory:GetItemCount(Config.Item) or 0) > 0
end

-- ------------------------------------------------------------ favoritos --

local function loadSaved()
    local raw = GetResourceKvpString(KVP_KEY)
    if not raw then return end

    local ok, decoded = pcall(json.decode, raw)
    saved = (ok and type(decoded) == 'table') and decoded or {}
end

local function persistSaved()
    SetResourceKvp(KVP_KEY, json.encode(saved))
end

---@param frequency number
---@return integer|nil indice na lista de favoritos
local function indexOfSaved(frequency)
    for i = 1, #saved do
        if saved[i].frequency == frequency then return i end
    end
end

-- ---------------------------------------------------------------- estado --

--- Envia o estado atual para a NUI redesenhar o visor.
local function pushState()
    SendNUIMessage({
        action = 'state',
        state = {
            power = radio.power,
            frequency = radio.frequency,
            label = labelFor(radio.frequency),
            volume = radio.volume,
            micClick = radio.micClick,
            isSaved = indexOfSaved(radio.frequency) ~= nil,
        },
        saved = saved,
    })

    -- A HUD de voz mostra a frequência abaixo do alcance de fala.
    if GetResourceState('nv_hud') == 'started' then
        exports.nv_hud:SetRadioFrequency(radio.power and radio.frequency or 0)
    end

    -- O servidor precisa saber em que frequência cada um está para o efetivo do
    -- MDT poder exibir isso ao lado do nome. Só é enviado quando o estado muda
    -- de verdade (é isto que `pushState` significa), e não a cada frame.
    TriggerServerEvent('nv_radio:report', radio.power and radio.frequency or nil)
end

-- --------------------------------------------------------------- energia --

--- Sai do canal e zera o estado de transmissão.
local function powerOff(reason)
    if not radio.power then return end

    radio.power = false
    voice:setRadioChannel(0)

    if reason then
        lib.notify({ type = 'inform', description = reason })
    end

    pushState()
end

--- Entra na frequência atual, se o servidor permitir.
---@return boolean
local function powerOn()
    if not hasRadio() then
        lib.notify({ type = 'error', description = 'Você não tem um rádio.' })
        return false
    end

    local allowed, reason = lib.callback.await('nv_radio:server:canJoin', false, radio.frequency)

    if not allowed then
        lib.notify({ type = 'error', description = reason or 'Não foi possível sintonizar.' })
        return false
    end

    radio.power = true
    voice:setRadioChannel(toChannel(radio.frequency))
    voice:setRadioVolume(radio.volume)

    pushState()
    return true
end

--- Troca de frequência mantendo o rádio ligado.
---@param frequency number
local function setFrequency(frequency)
    frequency = tonumber(('%.1f'):format(frequency)) or Config.DefaultFrequency

    if frequency < Config.MinFrequency or frequency > Config.MaxFrequency then
        return lib.notify({
            type = 'error',
            description = ('Frequência fora da faixa (%.1f - %.1f).')
                :format(Config.MinFrequency, Config.MaxFrequency)
        })
    end

    -- Desligado: só guarda o valor, sem pedir autorização ainda.
    if not radio.power then
        radio.frequency = frequency
        return pushState()
    end

    local allowed, reason = lib.callback.await('nv_radio:server:canJoin', false, frequency)

    if not allowed then
        return lib.notify({ type = 'error', description = reason or 'Frequência negada.' })
    end

    radio.frequency = frequency
    voice:setRadioChannel(toChannel(frequency))

    lib.notify({ type = 'success', description = ('Sintonizado em %.1f'):format(frequency) })
    pushState()
end

-- ------------------------------------------------------------------- NUI --

local function openRadio()
    if radio.open then return end

    if not hasRadio() then
        return lib.notify({ type = 'error', description = 'Você não tem um rádio.' })
    end

    radio.open = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        min = Config.MinFrequency,
        max = Config.MaxFrequency,
        maxVolume = Config.MaxVolume,
        maxSaved = Config.MaxSaved,
    })

    pushState()
end

local function closeRadio()
    if not radio.open then return end

    radio.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    closeRadio()
end)

RegisterNUICallback('power', function(data, cb)
    cb(1)

    if data and data.on then
        powerOn()
    else
        powerOff()
    end
end)

RegisterNUICallback('frequency', function(data, cb)
    cb(1)

    if data and tonumber(data.value) then
        setFrequency(tonumber(data.value))
    end
end)

RegisterNUICallback('volume', function(data, cb)
    cb(1)

    local value = tonumber(data and data.value)
    if not value then return end

    radio.volume = math.max(0, math.min(Config.MaxVolume, math.floor(value)))
    voice:setRadioVolume(radio.volume)
end)

--- Guarda (ou remove) a frequência atual nos favoritos.
RegisterNUICallback('save', function(_, cb)
    cb(1)

    local existing = indexOfSaved(radio.frequency)

    if existing then
        table.remove(saved, existing)
        lib.notify({ type = 'inform', description = ('%.1f removida.'):format(radio.frequency) })
    else
        if #saved >= Config.MaxSaved then
            return lib.notify({
                type = 'error',
                description = ('Você já tem %d frequências salvas.'):format(Config.MaxSaved)
            })
        end

        saved[#saved + 1] = {
            frequency = radio.frequency,
            label = labelFor(radio.frequency),
        }

        lib.notify({ type = 'success', description = ('%.1f salva.'):format(radio.frequency) })
    end

    persistSaved()
    pushState()
end)

RegisterNUICallback('micclick', function(data, cb)
    cb(1)

    radio.micClick = data and data.on and true or false

    -- O pma-voice controla o clique pelo volume dos dois sons.
    local level = radio.micClick and 100 or 0

    voice:setMicClickOnVolume(level)
    voice:setMicClickOffVolume(level)
end)

-- ------------------------------------------------------------- vigilância --

-- Perder o rádio ou morrer tira o jogador do canal. Sem isso daria para
-- entregar o item e continuar ouvindo a frequência.
CreateThread(function()
    while true do
        Wait(Config.WatchInterval)

        if radio.power then
            if not hasRadio() then
                powerOff('Você não está mais com o rádio.')
                closeRadio()
            elseif IsPedDeadOrDying(cache.ped, true) then
                powerOff('O rádio desligou.')
                closeRadio()
            end
        end
    end
end)

-- ------------------------------------------------------------------ init --

CreateThread(function()
    loadSaved()

    -- O submix precisa do pma-voice já iniciado para o setEffectSubmix pegar.
    Wait(1000)
    applyVoiceFilter()
end)

-- ---------------------------------------------------------------- entrada --

--- Chamado pelo ox_inventory ao usar o item (client.export em items.lua).
exports('useRadio', function()
    openRadio()
end)

exports('openRadio', openRadio)
exports('getFrequency', function()
    return radio.power and radio.frequency or nil
end)

lib.addKeybind({
    name = 'nv_radio',
    description = 'Abrir o rádio',
    defaultKey = 'F3',
    onPressed = openRadio,
})

RegisterCommand('radio', openRadio, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Nunca deixar o jogador preso no foco da NUI nem num canal fantasma.
    SetNuiFocus(false, false)
    voice:setRadioChannel(0)
end)
