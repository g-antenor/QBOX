--[[
    nv_minigames — client

    Todos os exports sao BLOQUEANTES e devolvem boolean (sucesso/falha),
    no mesmo estilo do lib.skillCheck do ox_lib:

        local ok = exports.nv_minigames:Locked({ difficulty = 'medium' })
        if ok then ... end

    Opcoes comuns:
        difficulty = 'easy' | 'medium' | 'hard'   (default 'medium')
        timeout    = ms ate falhar sozinho        (default 30000)

    Qualquer parametro do preset pode ser sobrescrito diretamente, ex.:
        exports.nv_minigames:Mines({ size = 6, mines = 9, reveals = 8 })
]]

local activePromise = nil

--- Copia as opcoes e aplica os padroes do Config (nunca muta a tabela do caller).
---@param options table|nil
---@return table
local function withDefaults(options)
    local out = {}

    if options then
        for k, v in pairs(options) do out[k] = v end
    end

    if out.difficulty == nil then out.difficulty = Config.Default.difficulty end
    if out.timeout == nil then out.timeout = Config.Default.timeout end

    return out
end

--- Inicia uma partida e bloqueia a thread ate o resultado.
---@param game string
---@param options table|nil
---@param needsMouse boolean|nil
---@return boolean
local function play(game, options, needsMouse)
    -- Uma partida por vez: evita dois minigames disputando o foco da NUI.
    if activePromise then return false end

    activePromise = promise.new()

    SetNuiFocus(true, needsMouse == true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'start',
        game = game,
        options = withDefaults(options),
    })

    return Citizen.Await(activePromise)
end

--- Resolve um preset do Config em (game, options).
---@param name string
---@param overrides table|nil
---@return string|nil, table
local function resolvePreset(name, overrides)
    local preset = Config.Presets[name]

    if not preset then
        if not Config.AllowUnknownPreset then
            print(('[nv_minigames] preset desconhecido: "%s"'):format(tostring(name)))
            return nil, {}
        end
        preset = Config.Fallback
    end

    local options = {}
    for k, v in pairs(preset) do options[k] = v end
    if overrides then
        for k, v in pairs(overrides) do options[k] = v end
    end

    local game = options.game
    options.game = nil

    return game, options
end

--- Libera o foco e resolve a promise pendente (se houver).
local function release(success)
    SetNuiFocus(false, false)

    local p = activePromise
    activePromise = nil

    if p then p:resolve(success and true or false) end
end

RegisterNUICallback('finish', function(data, cb)
    cb(1)
    release(data and data.success)
end)

-- ---------------------------------------------------------------- exports --

exports('Locked', function(options)
    return play('locked', options, false)
end)

exports('Mines', function(options)
    return play('mines', options, true)
end)

exports('SkillBar', function(options)
    return play('skillbar', options, false)
end)

exports('ProgressTiming', function(options)
    return play('timing', options, false)
end)

--- Forma recomendada: roda um preset nomeado do config.lua.
--- exports.nv_minigames:Start('arrombar_porta')
--- exports.nv_minigames:Start('arrombar_porta', { pins = 6 })  -- ajuste pontual
exports('Start', function(name, overrides)
    local game, options = resolvePreset(name, overrides)
    if not game then return false end

    return play(game, options, game == 'mines')
end)

--- Acesso direto, sem preset: exports.nv_minigames:Play('locked', { ... })
exports('Play', function(game, options)
    return play(game, options, game == 'mines')
end)

--- Cancela a partida em andamento (conta como falha).
exports('Cancel', function()
    if not activePromise then return end
    SendNUIMessage({ action = 'abort' })
    release(false)
end)

-- ------------------------------------------------------------- ciclo de vida

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- Nunca deixar o jogador preso no foco da NUI se o resource cair.
    release(false)
end)

-- ------------------------------------------------------------------- testes

--- /minigame <jogo> [dificuldade]   — testa um jogo cru
RegisterCommand('minigame', function(_, args)
    local game = args[1] or 'locked'
    local difficulty = args[2]

    CreateThread(function()
        local ok = play(game, { difficulty = difficulty }, game == 'mines')
        print(('[nv_minigames] %s (%s) -> %s'):format(game, difficulty or Config.Default.difficulty,
            ok and 'sucesso' or 'falha'))
    end)
end, false)

--- /minigamepreset <preset>         — testa um preset do config.lua
RegisterCommand('minigamepreset', function(_, args)
    local name = args[1]

    if not name then
        local names = {}
        for preset in pairs(Config.Presets) do names[#names + 1] = preset end
        table.sort(names)
        print('[nv_minigames] presets: ' .. table.concat(names, ', '))
        return
    end

    CreateThread(function()
        local game, options = resolvePreset(name, nil)
        if not game then return end

        local ok = play(game, options, game == 'mines')
        print(('[nv_minigames] preset %s (%s) -> %s'):format(name, game, ok and 'sucesso' or 'falha'))
    end)
end, false)
