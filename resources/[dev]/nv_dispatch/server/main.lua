--[[
    nv_dispatch — servidor

    Um alerta so existe se o SERVIDOR mandar. O cliente que comete o crime
    apenas conta o que fez e onde estava; quem decide se aquilo vira alerta,
    para quem vai e se o bloqueador estava ativo e este arquivo.

    Isso importa porque o cliente do ladrao e exatamente a maquina que tem
    interesse em suprimir o alerta. Se a supressao morasse la, bastaria nao
    enviar.
]]

local Ox = require '@ox_core.lib.init'

Dispatch = {}

-- Bloqueios ativos, por charId -> os.time() em que expiram.
--
-- Por charId e nao por source: sair e voltar no servidor trocaria o source e
-- limparia o bloqueio, o que daria ao ladrao um botao de cancelar consequencia.
---@type table<number, number>
local jammed = {}

-- ------------------------------------------------------------ destinatarios --

--- charIds que pertencem a alguma organizacao dos subtipos configurados.
---
--- Consultado a cada alerta em vez de cacheado: entrar e sair de uma corporacao
--- e raro, mas um cache errado aqui significa policial novo sem dispatch ou
--- ex-policial recebendo tudo -- os dois piores erros possiveis nesta funcao.
---@return table<number, boolean>
local function departmentCharIds()
    local subtypes = Config.Departments

    if type(subtypes) ~= 'table' or #subtypes == 0 then return {} end

    local placeholders = string.rep('?', #subtypes, ', ')

    local ok, rows = pcall(MySQL.query.await, ([[
        SELECT DISTINCT cg.`charId`
        FROM `character_groups` cg
        JOIN `nv_org_subtype` s ON s.`group` = cg.`name`
        WHERE s.`subtype` IN (%s)
    ]]):format(placeholders), subtypes)

    if not ok or type(rows) ~= 'table' then
        -- Sem nv_orgs instalado a tabela nao existe. Devolver vazio e o certo:
        -- e melhor um dispatch mudo do que um dispatch para o servidor inteiro.
        return {}
    end

    local set = {}

    for i = 1, #rows do
        set[rows[i].charId] = true
    end

    return set
end

--- Sources online que devem receber o alerta.
---@return number[]
local function receivers()
    local allowed = departmentCharIds()

    if not next(allowed) then return {} end

    local players = Ox.GetPlayers() or {}
    local result = {}

    for i = 1, #players do
        local player = players[i]

        if player.charId and allowed[player.charId] then
            result[#result + 1] = player.source
        end
    end

    return result
end

-- --------------------------------------------------------------- bloqueio --

--- Este personagem esta com bloqueador ativo agora?
---@param charId number?
---@return boolean
local function isJammed(charId)
    if not charId then return false end

    local until_ = jammed[charId]

    if not until_ then return false end

    if os.time() >= until_ then
        jammed[charId] = nil
        return false
    end

    return true
end

Dispatch.isJammed = isJammed

exports('IsJammed', function(source)
    local player = Ox.GetPlayer(source)

    return player and isJammed(player.charId) or false
end)

-- ----------------------------------------------------------------- enviar --

--- Coordenada deslocada aleatoriamente dentro de um raio.
---
--- Usada no alerta de perda de sinal: o ponto exato entregaria justamente o que
--- o bloqueador acabou de esconder.
---@param coords vector3
---@param radius number
---@return vector3
local function blur(coords, radius)
    local angle = math.random() * math.pi * 2
    local distance = math.sqrt(math.random()) * radius

    return vec3(
        coords.x + math.cos(angle) * distance,
        coords.y + math.sin(angle) * distance,
        coords.z
    )
end

--- Dispara um alerta.
---
---@param category string   chave de Config.Categories
---@param coords vector3
---@param data table?       { detail, street, source }
---@return boolean
function Dispatch.send(category, coords, data)
    if not Config.Enabled then return false end

    local settings = Config.Categories[category]

    if not settings then
        lib.print.warn(('categoria de dispatch desconhecida: %s'):format(tostring(category)))
        return false
    end

    if type(coords) ~= 'vector3' then return false end

    data = data or {}

    local targets = receivers()

    -- Ninguem de servico. O alerta nao vira nada em tela, mas ainda vira
    -- historico no MDT: o crime aconteceu, e a corporacao deve poder ver depois
    -- que aconteceu enquanto nao havia ninguem.
    local payload = {
        id       = ('%s_%d'):format(category, math.random(100000, 999999)),
        category = category,
        label    = settings.label,
        code     = settings.code,
        icon     = settings.icon,
        priority = settings.priority,
        detail   = type(data.detail) == 'string' and data.detail:sub(1, 90) or nil,
        street   = type(data.street) == 'string' and data.street:sub(1, 60) or nil,
        coords   = { x = coords.x, y = coords.y, z = coords.z },
        blip     = {
            sprite = settings.blipSprite,
            color  = settings.blipColor,
            radius = Config.Blip.radius,
            alpha  = Config.Blip.alpha,
            time   = Config.Blip.duration
        }
    }

    for i = 1, #targets do
        TriggerClientEvent('nv_dispatch:alert', targets[i], payload)
    end

    -- Historico no MDT. Falha em silencio de proposito: MDT fora do ar nao pode
    -- impedir a policia de receber o alerta na tela.
    if Config.MdtDepartment and GetResourceState('nv_mdt') == 'started' then
        pcall(function()
            exports.nv_mdt:AddCall(Config.MdtDepartment, {
                title    = payload.detail and ('%s — %s'):format(settings.label, payload.detail) or settings.label,
                location = payload.street,
                priority = settings.priority,
                x        = coords.x,
                y        = coords.y
            })
        end)
    end

    return true
end

--- Igual ao `send`, mas respeitando o bloqueador de quem cometeu o crime.
---
--- E este o ponto em que o bloqueador age -- nao no cliente, nao no nv_garage.
--- Qualquer resource que chame `Alert` ganha o comportamento de graca, e nenhum
--- deles precisa saber que bloqueador existe.
---
---@param source number    quem cometeu
---@param category string
---@param coords vector3
---@param data table?
---@return boolean
function Dispatch.alert(source, category, coords, data)
    if not Config.Enabled then return false end

    local player = Ox.GetPlayer(source)
    local charId = player and player.charId

    if isJammed(charId) then
        -- Trocado, nao apagado: sai um "perda de sinal" com a posicao borrada.
        -- A policia sabe que algo acontece naquela regiao, sem saber o que.
        Dispatch.send('perda_sinal', blur(coords, Config.Jammer.blur), {
            detail = 'Interferencia em equipamento de rastreio'
        })

        return false
    end

    return Dispatch.send(category, coords, data)
end

exports('Alert', function(source, category, coords, data)
    return Dispatch.alert(source, category, coords, data)
end)

--- Alerta sem autor: eventos do mundo que nao partem de um jogador.
exports('Send', function(category, coords, data)
    return Dispatch.send(category, coords, data)
end)

-- ------------------------------------------------------------- bloqueador --

--- Chamado pelo cliente quando o jogador usa o item.
---
--- O sorteio de falha e feito AQUI. No cliente, "falhou" seria uma informacao
--- que a maquina do ladrao produz sobre si mesma -- e ela tem todo o interesse
--- em nunca falhar.
lib.callback.register('nv_dispatch:useJammer', function(source)
    if not Config.Enabled then
        return false, 'O aparelho nao encontra nenhuma rede para bloquear.'
    end

    local player = Ox.GetPlayer(source)
    if not player then return false end

    local cfg = Config.Jammer

    if (exports.ox_inventory:GetItemCount(source, cfg.item) or 0) < 1 then
        return false, 'Voce nao tem um bloqueador.'
    end

    if isJammed(player.charId) then
        return false, 'Ja ha um bloqueio ativo.'
    end

    local failed = math.random(100) <= cfg.failChance

    -- O desgaste sai nos dois casos: o aparelho trabalhou, tendo funcionado ou
    -- nao. Cobrar so no sucesso faria da falha um evento sem custo.
    exports.ox_inventory:RemoveItem(source, cfg.item, 1)

    if failed then
        return false, 'O bloqueador falhou. Nenhum sinal foi cortado.'
    end

    jammed[player.charId] = os.time() + cfg.duration

    return true, nil, cfg.duration
end)

-- ------------------------------------------------- entradas de outros --
--                                                    resources          --

--- nv_garage: `Config.Lockpick.alertEvent` e `Config.Hotwire.alertEvent`.
---
--- A assinatura e `(coords)` porque e o que o nv_garage ja enviava quando estes
--- ganchos foram criados; mudar la seria mexer em codigo que funciona para
--- ganhar um parametro que este arquivo consegue deduzir.
RegisterNetEvent('nv_dispatch:carTheft', function(coords)
    if type(coords) ~= 'vector3' then return end

    Dispatch.alert(source, 'roubo_veiculo', coords, {
        detail = 'Tentativa de furto de veiculo'
    })
end)

RegisterNetEvent('nv_dispatch:robbery', function(coords)
    if type(coords) ~= 'vector3' then return end

    Dispatch.alert(source, 'roubo_civil', coords)
end)

RegisterNetEvent('nv_dispatch:atmRobbery', function(coords)
    if type(coords) ~= 'vector3' then return end

    Dispatch.alert(source, 'roubo_caixa', coords)
end)

RegisterNetEvent('nv_dispatch:atmExplosion', function(coords)
    if type(coords) ~= 'vector3' then return end

    Dispatch.alert(source, 'explosao_caixa', coords)
end)

-- Limpeza: um charId que saiu nao precisa manter o bloqueio na memoria depois
-- de expirar, e ninguem passa por aqui para conferir.
CreateThread(function()
    while true do
        Wait(60000)

        local now = os.time()

        for charId, until_ in pairs(jammed) do
            if now >= until_ then jammed[charId] = nil end
        end
    end
end)
