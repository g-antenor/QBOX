-- ==========================================================================
-- PERSISTENCIA DAS PREFERENCIAS DA HUD (KVP local do jogador)
-- ==========================================================================
local KVP_KEY = 'nv_hud:settings'

Settings = {}

local function deepCopy(src)
    if type(src) ~= 'table' then return src end

    local out = {}
    for k, v in pairs(src) do out[k] = deepCopy(v) end

    return out
end

--- Preenche campos ausentes de `target` com os valores de `defaults`.
local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == 'table' then
            if type(target[k]) ~= 'table' then target[k] = {} end
            applyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end

    return target
end

function Settings.load()
    local raw = GetResourceKvpString(KVP_KEY)
    local data = raw and json.decode(raw) or nil

    if type(data) ~= 'table' then data = {} end

    return applyDefaults(data, Config.Defaults)
end

function Settings.save(data)
    if type(data) ~= 'table' then return end

    SetResourceKvp(KVP_KEY, json.encode(applyDefaults(data, Config.Defaults)))
end

function Settings.reset()
    DeleteResourceKvp(KVP_KEY)

    return deepCopy(Config.Defaults)
end
