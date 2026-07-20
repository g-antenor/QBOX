Config = {}

-- ============================================================================
-- COMPORTAMENTO
-- ============================================================================

-- Tecla que abre o chat.
Config.OpenKey = 'T'

-- Segundos que o chat continua visivel depois de fechar a caixa de texto
-- (ou depois da ultima mensagem recebida).
Config.FadeAfter = 5

-- Numero maximo de mensagens mantidas na tela.
Config.MaxMessages = 40

-- Tamanho maximo de uma mensagem.
Config.MaxLength = 240

-- Intervalo minimo entre mensagens do mesmo jogador (ms), anti-flood.
Config.Cooldown = 700

-- ============================================================================
-- CANAIS
-- NAO existe chat global: texto sem comando vai para o canal local.
--
--   adminOnly = so admins podem enviar
--   range     = alcance em metros (nil = sem limite de distancia)
--   toAdmins  = entrega apenas para admins
--   broadcast = entrega para todo mundo no servidor
-- ============================================================================
Config.DefaultChannel = 'local'

Config.Channels = {
    ['local'] = {
        label = 'LOCAL',
        commands = { 'l', 'local' },
        range = 20.0,
        color = '#e6e4e3',
        help = 'Fala com quem esta por perto'
    },

    ['dm'] = {
        label = 'DM',
        commands = { 'dm', 'pm' },
        needsTarget = true,
        color = '#aa66cc',
        help = 'Mensagem privada: /dm <id> <mensagem>'
    },

    ['adm'] = {
        label = 'ADM',
        commands = { 'adm', 'admin' },
        adminOnly = true,
        toAdmins = true,
        color = '#4a90d9',
        help = 'Canal interno da administracao'
    },

    ['alerta'] = {
        label = 'ALERTA',
        commands = { 'alerta', 'alert' },
        adminOnly = true,
        broadcast = true,
        color = '#ff2438',
        help = 'Aviso da administracao para todo o servidor'
    },

    -- Canal interno: mensagens vindas de outros resources via chat:addMessage
    -- e retornos do proprio chat (erros, confirmacoes). Nao e digitavel.
    ['sistema'] = {
        label = 'SISTEMA',
        internal = true,
        color = '#86828a'
    }
}

-- ============================================================================
-- COMANDOS DE CONSOLE
--
-- `ensure`, `refresh`, `restart` e afins NAO sao comandos de script: existem
-- apenas no console do servidor. Eles nao entram na lista de comandos que o
-- cliente conhece, entao digitar /ensure no chat nunca chegava ao servidor.
--
-- Os nomes listados aqui sao encaminhados para o servidor executar no proprio
-- console, sempre exigindo admin.
--
-- MANTENHA CURTA: cada nome aqui vira poder de administracao pelo chat.
-- Nunca inclua exec, set, add_ace, add_principal, rcon_password ou quit.
-- ============================================================================
Config.ConsoleCommands = {
    'ensure',
    'restart',
    'start',
    'stop',
    'refresh',
}

-- ============================================================================
-- ADMIN
-- Mesma convencao usada pelo nv_adminmenu.
-- ============================================================================
Config.AdminGroups = { 'admin', 'superadmin', 'god', "giveitem", "fishdeploy", "orgs" }
Config.AdminAce = 'command'
