-- ==========================================================================
-- NV_CHAT - ponte entre o jogo e a NUI
-- ==========================================================================
local isOpen = false
local ready = false

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function openChat()
    if isOpen or IsPauseMenuActive() then return end

    isOpen = true

    -- Foco de teclado sem cursor: o jogador digita mas continua enxergando
    -- a mira/camera normalmente.
    SetNuiFocus(true, false)
    sendNui('open')
end

local function closeChat()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    sendNui('close')
end

-- ==========================================================================
-- ABERTURA (tecla T)
-- ==========================================================================
RegisterCommand('+nv_chat', openChat, false)
RegisterCommand('-nv_chat', function() end, false)
RegisterKeyMapping('+nv_chat', 'Abrir o chat', 'keyboard', Config.OpenKey)

-- ==========================================================================
-- COMANDOS x CANAIS
-- Barra pode ser duas coisas: um canal do chat (/l, /dm, /adm) ou um comando
-- do jogo (/adminmenu, /handling). Sem essa separacao, todo /comando virava
-- "Comando desconhecido" no servidor do chat e nunca chegava no jogo.
-- ==========================================================================
local chatAliases = {}

for _, channel in pairs(Config.Channels) do
    if not channel.internal then
        for _, alias in ipairs(channel.commands or {}) do
            chatAliases[alias:lower()] = true
        end
    end
end

-- Comandos que existem so no console do servidor (ensure, refresh, ...).
local consoleCommands = {}

for _, name in ipairs(Config.ConsoleCommands or {}) do
    consoleCommands[name:lower()] = true
end

-- O console do jogo (F8) so executa comandos que existem no CLIENTE. Como
-- ensure/refresh/restart sao comandos de console do servidor, eles nao estao
-- na lista replicada e digitar no F8 nao fazia absolutamente nada -- nem erro.
--
-- Registramos cada um como comando de cliente que so encaminha o texto ao
-- servidor. A permissao continua sendo decidida la (isAdmin + whitelist), aqui
-- nao ha checagem de seguranca nenhuma: isso e roteamento.
for name in pairs(consoleCommands) do
    RegisterCommand(name, function(_, args, raw)
        -- `raw` vem com o comando inteiro, que e o formato que o servidor espera.
        local text = raw and raw:gsub('^%s+', '') or name

        print(('[nv_chat] encaminhando ao console do servidor: %s'):format(text))
        TriggerServerEvent('nv_chat:console', text)
    end, false)
end

--- Primeira palavra depois da barra, em minusculo.
---@param text string
---@return string|nil
local function commandWord(text)
    if text:sub(1, 1) ~= '/' then return nil end

    local command = text:match('^/(%S+)')

    return command and command:lower() or nil
end

-- ==========================================================================
-- NUI -> CLIENT
-- ==========================================================================
RegisterNUICallback('send', function(data, cb)
    closeChat()

    if type(data) == 'table' and type(data.text) == 'string' and data.text ~= '' then
        local word = commandWord(data.text)

        if word and consoleCommands[word] then
            -- Console do servidor: o cliente nao tem como executar, entao
            -- pedimos ao servidor (que valida admin e a whitelist de novo).
            TriggerServerEvent('nv_chat:console', data.text:sub(2))
        elseif word and not chatAliases[word] then
            -- ExecuteCommand roda os comandos registrados no cliente e
            -- encaminha ao servidor os de script (ex.: /adminmenu).
            ExecuteCommand(data.text:sub(2))
        else
            TriggerServerEvent('nv_chat:send', data.text)
        end
    end

    cb(1)
end)

RegisterNUICallback('cancel', function(_, cb)
    closeChat()
    cb(1)
end)

RegisterNUICallback('ready', function(_, cb)
    ready = true

    sendNui('config', {
        fadeAfter = Config.FadeAfter,
        maxMessages = Config.MaxMessages,
        maxLength = Config.MaxLength,
        channels = Config.Channels,
        defaultChannel = Config.DefaultChannel
    })

    cb(1)
end)

-- ==========================================================================
-- SERVIDOR -> NUI
-- ==========================================================================
-- Retorno dos comandos de console, impresso no F8.
RegisterNetEvent('nv_chat:consolePrint', function(text)
    if type(text) == 'string' then print(('[nv_chat] %s'):format(text)) end
end)

RegisterNetEvent('nv_chat:receive', function(message)
    if not ready or type(message) ~= 'table' then return end

    sendNui('message', message)
end)

-- ==========================================================================
-- COMPATIBILIDADE
-- Resources antigos usam TriggerClientEvent('chat:addMessage', ...).
-- ==========================================================================
RegisterNetEvent('chat:addMessage', function(data)
    if not ready then return end

    local text

    if type(data) == 'table' then
        text = data.args and (data.args[2] or data.args[1]) or data.message or data.text
    else
        text = tostring(data)
    end

    if not text then return end

    sendNui('message', { channel = 'sistema', text = text })
end)

-- Sugestoes do chat antigo: aceitas e ignoradas, apenas para nao gerar erro
-- em resources que as registram na inicializacao.
RegisterNetEvent('chat:addSuggestion', function() end)
RegisterNetEvent('chat:removeSuggestion', function() end)
RegisterNetEvent('chat:clear', function()
    if ready then sendNui('clear') end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
end)
