-- ==========================================================================
-- NV_CHAT - roteamento de mensagens
--
-- Nao existe canal global: todo texto sem comando cai no canal local, que e
-- limitado por distancia. Os demais canais sao DM, ADM e Alerta.
-- ==========================================================================
-- Wrapper do ox_core (mesma forma usada pelo nv_adminmenu). O export cru
-- devolve so os dados do jogador, sem os metodos como getGroups().
local Ox = require '@ox_core.lib.init'

local lastMessage = {}

--- Mesma checagem do nv_adminmenu, para o servidor ter uma nocao unica de admin.
local function isAdmin(source)
    if IsPlayerAceAllowed(source, Config.AdminAce) then return true end

    local player = Ox.GetPlayer(source)
    if not player then return false end

    local ok, groups = pcall(function() return player.getGroups() end)
    if not ok or type(groups) ~= 'table' then return false end

    for i = 1, #Config.AdminGroups do
        if groups[Config.AdminGroups[i]] then return true end
    end

    return false
end

--- Nome do personagem. O ox_core replica isso no state bag do jogador ao
--- carregar o char, entao nao precisamos consultar o banco.
local function characterName(source)
    local name = Player(source).state.name

    if type(name) == 'string' and name ~= '' then return name end

    -- Sem personagem carregado (tela de selecao): cai no nome da conta.
    return GetPlayerName(source)
end

local function send(target, channel, author, text, meta)
    TriggerClientEvent('nv_chat:receive', target, {
        channel = channel,
        author = author,
        text = text,
        meta = meta
    })
end

local function notify(source, text)
    send(source, 'sistema', nil, text)
end

--- Resposta de comando de console: vai para o chat E para o F8.
--- Quem digitou no F8 nao esta olhando o chat, e sem isso o comando parecia
--- nao ter feito nada.
local function consoleReply(source, text)
    notify(source, text)
    TriggerClientEvent('nv_chat:consolePrint', source, text)
end

local function admins()
    local list = {}

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and isAdmin(src) then list[#list + 1] = src end
    end

    return list
end

--- Resolve o texto digitado em canal + conteudo.
--- Sem comando reconhecido, tudo vira canal local.
local function parse(text)
    if text:sub(1, 1) ~= '/' then
        return Config.DefaultChannel, text
    end

    local command, rest = text:match('^/(%S+)%s*(.*)$')
    if not command then return Config.DefaultChannel, text end

    command = command:lower()

    for name, channel in pairs(Config.Channels) do
        if not channel.internal then
            for _, alias in ipairs(channel.commands or {}) do
                if alias == command then return name, rest end
            end
        end
    end

    -- Comando desconhecido: nao vaza como mensagem local.
    return nil, nil, command
end

RegisterNetEvent('nv_chat:send', function(text)
    local source = source

    if type(text) ~= 'string' then return end

    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return end

    if #text > Config.MaxLength then
        text = text:sub(1, Config.MaxLength)
    end

    -- Anti-flood
    local now = GetGameTimer()
    if lastMessage[source] and now - lastMessage[source] < Config.Cooldown then return end
    lastMessage[source] = now

    local channelName, body, unknown = parse(text)

    if not channelName then
        return notify(source, ('Comando desconhecido: /%s'):format(unknown))
    end

    local channel = Config.Channels[channelName]

    if channel.adminOnly and not isAdmin(source) then
        return notify(source, 'Voce nao tem permissao para usar esse canal.')
    end

    local author = characterName(source)

    -- ---------------- DM ----------------
    if channel.needsTarget then
        local targetId, message = body:match('^(%d+)%s+(.+)$')
        targetId = tonumber(targetId)

        if not targetId or not message then
            return notify(source, 'Uso: /dm <id> <mensagem>')
        end

        if not GetPlayerName(targetId) then
            return notify(source, ('Jogador %d nao esta online.'):format(targetId))
        end

        if targetId == source then
            return notify(source, 'Voce nao pode enviar DM para si mesmo.')
        end

        send(targetId, 'dm', author, message, { direction = 'de', id = source })
        send(source, 'dm', characterName(targetId), message, { direction = 'para', id = targetId })

        return
    end

    if body == '' then return end

    -- ---------------- Alerta (todo o servidor) ----------------
    if channel.broadcast then
        return send(-1, channelName, author, body)
    end

    -- ---------------- ADM (somente admins) ----------------
    if channel.toAdmins then
        for _, admin in ipairs(admins()) do
            send(admin, channelName, author, body)
        end

        return
    end

    -- ---------------- Local (por distancia) ----------------
    local origin = GetEntityCoords(GetPlayerPed(source))
    local range = channel.range or 20.0

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)

        if target then
            local coords = GetEntityCoords(GetPlayerPed(target))

            if #(origin - coords) <= range then
                send(target, channelName, author, body)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastMessage[source] = nil
end)

-- ==========================================================================
-- COMPATIBILIDADE
-- Outros resources (ox_lib, txAdmin, scripts antigos) disparam chat:addMessage.
-- Mantemos o evento funcionando para nao quebra-los, entregando no canal
-- interno "sistema".
-- ==========================================================================
local function compatMessage(target, data)
    local text

    if type(data) == 'table' then
        text = data.args and (data.args[2] or data.args[1]) or data.message or data.text
    else
        text = tostring(data)
    end

    if not text then return end

    send(target, 'sistema', nil, text)
end

-- Registrado sem callback: o AddEventHandler abaixo atende tanto o disparo
-- local (outro resource do servidor) quanto o vindo de um cliente. Passar um
-- callback aqui faria a mensagem ser processada duas vezes no caso local.
RegisterNetEvent('chat:addMessage')

AddEventHandler('chat:addMessage', function(data)
    local src = source

    -- source vazio/0 = disparo local de outro resource -> vale para todos.
    compatMessage((src == '' or src == 0) and -1 or src, data)
end)

-- ==========================================================================
-- COMANDOS DE CONSOLE
--
-- ensure/refresh/restart nao sao comandos de script: existem so no console do
-- servidor, nao entram na lista replicada para os clientes e por isso digitar
-- /ensure no chat nunca chegava a lugar nenhum. Aqui o servidor executa por
-- conta propria, depois de validar admin e a whitelist.
-- ==========================================================================
local consoleCommands = {}

for _, name in ipairs(Config.ConsoleCommands or {}) do
    consoleCommands[name:lower()] = true
end

--[[
    Por que NAO usamos `ExecuteCommand` para start/stop/restart/ensure:

    `ExecuteCommand` no servidor roda o comando com a identidade do RESOURCE
    que chamou (`resource.nv_chat`), e nao a do console. Como esse principal nao
    tem a ACE `command.ensure`, o servidor respondia "Access denied for command
    ensure" -- mesmo com o jogador sendo admin de verdade no txAdmin. A permissao
    que faltava nunca foi a dele.

    Daria para resolver com `add_ace resource.nv_chat command.ensure allow` no
    server.cfg, mas isso deixa o recurso dependente de uma linha de config que o
    txAdmin pode reescrever. As natives fazem a mesma coisa sem intermediario e
    sem ACE nenhuma.
]]
local resourceActions = {
    start = function(name)
        if GetResourceState(name) == 'started' then
            return false, ('"%s" ja esta rodando.'):format(name)
        end

        StartResource(name)

        return true, ('Resource "%s" iniciado.'):format(name)
    end,

    stop = function(name)
        if GetResourceState(name) ~= 'started' then
            return false, ('"%s" nao esta rodando.'):format(name)
        end

        StopResource(name)

        return true, ('Resource "%s" parado.'):format(name)
    end,

    restart = function(name)
        if GetResourceState(name) ~= 'started' then
            return false, ('"%s" nao esta rodando -- use start ou ensure.'):format(name)
        end

        StopResource(name)
        Wait(200)  -- o stop nao e instantaneo; subir por cima dele falha
        StartResource(name)

        return true, ('Resource "%s" reiniciado.'):format(name)
    end,

    ensure = function(name)
        if GetResourceState(name) == 'started' then
            StopResource(name)
            Wait(200)
        end

        StartResource(name)

        return true, ('Resource "%s" garantido no ar.'):format(name)
    end
}

--- Executa um comando de console liberado.
---@param command string
---@param argument string?
---@return boolean ok
---@return string reply
local function runConsoleCommand(command, argument)
    local action = resourceActions[command]

    if action then
        if not argument or argument == '' then
            return false, ('Uso: %s <resource>'):format(command)
        end

        -- Um nome so: "ensure a b" nao pode virar dois comandos.
        local name = argument:match('^(%S+)$')

        if not name then
            return false, 'Informe apenas um resource.'
        end

        if GetResourceState(name) == 'missing' then
            return false, ('Resource "%s" nao existe.'):format(name)
        end

        return action(name)
    end

    -- Sem native equivalente (refresh, por exemplo): cai no ExecuteCommand, que
    -- depende da ACE do resource. Se der "Access denied", a linha que falta e
    --     add_ace resource.nv_chat command.<nome> allow
    -- no server.cfg.
    ExecuteCommand(command .. (argument and (' ' .. argument) or ''))

    return true, ('Enviado ao console: %s'):format(command)
end

RegisterNetEvent('nv_chat:console', function(text)
    local source = source

    if type(text) ~= 'string' then return end

    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return end

    if not isAdmin(source) then
        return consoleReply(source, 'Você não tem permissão para executar comandos de console.')
    end

    -- Uma linha, um comando: impede encadear coisas na mesma mensagem.
    if text:find('[\r\n]') then
        return consoleReply(source, 'Comando inválido.')
    end

    local command = text:match('^(%S+)')

    -- Revalida no servidor: a checagem do cliente e so roteamento, nao seguranca.
    if not command or not consoleCommands[command:lower()] then
        return consoleReply(source, ('Comando de console não liberado: %s'):format(command or '?'))
    end

    print(('[nv_chat] %s (id %s) executou no console: %s')
        :format(GetPlayerName(source) or '?', source, text))

    local ok, reply = runConsoleCommand(command:lower(), text:match('^%S+%s+(.+)$'))

    consoleReply(source, reply)

    if ok then
        print(('[nv_chat] %s'):format(reply))
    end
end)
