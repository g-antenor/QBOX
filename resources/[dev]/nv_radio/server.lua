--[[
    nv_radio — servidor

    Responsabilidade única: decidir se o jogador pode entrar numa frequência.
    O cliente desenha a interface, mas quem autoriza é aqui — caso contrário
    bastaria alterar o NUI para entrar no canal da polícia.
]]

-- Wrapper do ox_core (mesma forma usada pelo nv_chat e nv_adminmenu).
local Ox = require '@ox_core.lib.init'

---@param source number
---@param groups string[]
---@return boolean
local function hasAnyGroup(source, groups)
    local player = Ox.GetPlayer(source)
    if not player then return false end

    local ok, playerGroups = pcall(function() return player.getGroups() end)
    if not ok or type(playerGroups) ~= 'table' then return false end

    for i = 1, #groups do
        if playerGroups[groups[i]] then return true end
    end

    return false
end

--- O jogador realmente tem o rádio no inventário?
---@param source number
---@return boolean
local function hasRadio(source)
    local count = exports.ox_inventory:GetItemCount(source, Config.Item)

    return (count or 0) > 0
end

--- Autoriza (ou não) sintonizar uma frequência.
lib.callback.register('nv_radio:server:canJoin', function(source, frequency)
    if type(frequency) ~= 'number' then return false, 'Frequência inválida.' end

    if frequency < Config.MinFrequency or frequency > Config.MaxFrequency then
        return false, ('Frequência fora da faixa (%.1f - %.1f).')
            :format(Config.MinFrequency, Config.MaxFrequency)
    end

    if not hasRadio(source) then
        return false, 'Você não tem um rádio.'
    end

    -- Compara com uma casa decimal para casar com a chave do config.
    local key = tonumber(('%.1f'):format(frequency))
    local restriction = Config.Restricted[key]

    if restriction and not hasAnyGroup(source, restriction) then
        return false, 'Essa frequência é restrita.'
    end

    return true
end)

-- --------------------------------------------------- frequência publicada --

--[[
    O cliente avisa em que frequência está, e o servidor publica isso num
    statebag do jogador. É o que permite ao efetivo do MDT mostrar a modulação
    ao lado do nome sem precisar perguntar a cada cliente.

    É informação DECLARADA, não verificada: o statebag diz onde o rádio afirma
    estar, e um cliente adulterado pode mentir. Isso é aceitável aqui porque o
    valor só é exibido — quem de fato entra no canal de voz continua sendo
    decidido por `canJoin`, que confere item e restrição de grupo.
]]
RegisterNetEvent('nv_radio:report', function(frequency)
    local player = Player(source)

    if not player then return end

    if type(frequency) ~= 'number' then
        return player.state:set('radio', nil, true)
    end

    if frequency < Config.MinFrequency or frequency > Config.MaxFrequency then
        return player.state:set('radio', nil, true)
    end

    player.state:set('radio', tonumber(('%.1f'):format(frequency)), true)
end)
