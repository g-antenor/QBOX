--[[
    nv_mdt — cliente

    Ponte fina: abre a tela, repassa cliques, devolve respostas. Nenhuma
    validacao mora aqui -- a tela existir nao autoriza nada, e todo callback do
    servidor reconfere o acesso pelo subtipo da organizacao.
]]

local open = false

---@param message string
---@param type string?
local function notify(message, type)
    lib.notify({
        title = 'MDT',
        description = message,
        type = type or 'inform',
        position = 'top'
    })
end

local function close()
    if not open then return end

    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openMdt()
    if open then return end

    local data = lib.callback.await('nv_mdt:open', false)

    -- Sem departamento nenhum: nao e "erro", e falta de acesso. Dizer isso e
    -- melhor do que abrir uma tela vazia.
    if not data or not data.tabs or #data.tabs == 0 then
        return notify('Voce nao tem acesso ao MDT.', 'error')
    end

    open = true
    data.action = 'open'

    SetNuiFocus(true, true)
    SendNUIMessage(data)
end

RegisterCommand(Config.Command, openMdt, false)

if Config.Keybind then
    lib.addKeybind({
        name = 'nv_mdt',
        description = 'Abrir o MDT',
        defaultKey = Config.Keybind,
        onPressed = openMdt
    })
end

exports('open', openMdt)

-- ------------------------------------------------------ ponte generica --

--- Encaminha um callback NUI para um callback do servidor.
---
--- A tela manda `{ endpoint, args }` e recebe o retorno cru. Sem isto seriam
--- ~20 blocos identicos de RegisterNUICallback, e cada um seria mais um lugar
--- para esquecer um `cb`.
RegisterNUICallback('call', function(data, cb)
    if type(data) ~= 'table' or type(data.endpoint) ~= 'string' then
        return cb(false)
    end

    -- Whitelist por prefixo: a NUI so alcanca callbacks deste resource.
    if data.endpoint:sub(1, 7) ~= 'nv_mdt:' then return cb(false) end

    local args = data.args or {}

    -- O tamanho vem da NUI (data.n) e conta os argumentos de verdade: um valor
    -- nulo no meio deixa buraco no array decodificado, e o operador # pararia
    -- de contar ali -- o argumento seguinte sumiria em silencio.
    cb(lib.callback.await(data.endpoint, false, table.unpack(args, 1, data.n or #args)))
end)

--- Igual ao de cima, mas para acoes: mostra a notificacao de erro/sucesso.
RegisterNUICallback('action', function(data, cb)
    if type(data) ~= 'table' or type(data.endpoint) ~= 'string' then
        return cb({ ok = false })
    end

    if data.endpoint:sub(1, 7) ~= 'nv_mdt:' then return cb({ ok = false }) end

    local args = data.args or {}
    local ok, err, extra = lib.callback.await(data.endpoint, false, table.unpack(args, 1, data.n or #args))

    if not ok then
        notify(err or 'Nao foi possivel concluir.', 'error')
        return cb({ ok = false, error = err })
    end

    if data.success then notify(data.success, 'success') end

    cb({ ok = true, value = extra })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

-- ---------------------------------------------------------- live map --

--- Converte coordenada do mundo para porcentagem no mapa da tela.
---
--- Os limites sao os do mapa jogavel do GTA V. Nao sao exatos ao metro -- o
--- mapa nao e um retangulo perfeito -- mas colocam o ponto no bairro certo,
--- que e o que um Live Map precisa.
RegisterNUICallback('mapBounds', function(_, cb)
    cb({ minX = -4000.0, maxX = 4500.0, minY = -4000.0, maxY = 8000.0 })
end)

--- Marca um chamado no mapa e fecha o MDT.
---
--- Fechar faz parte da acao: o motivo de tracar a rota e ir ate la, e deixar o
--- terminal aberto por cima do para-brisa obrigaria a um segundo gesto que so
--- existe porque a tela nao entendeu o que voce pediu.
RegisterNUICallback('markMap', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    local x, y = tonumber(data.x), tonumber(data.y)

    if not x or not y then
        return notify('Este chamado nao tem posicao registrada.', 'error')
    end

    close()
    SetNewWaypoint(x, y)

    notify('Rota tracada.', 'success')
end)

-- ---------------------------------------------------------- retratos --

--[[
    FOTO DO EFETIVO

    E o mesmo retrato que o GTA usa no menu de pausa: `RegisterPedheadshot`
    renderiza o ped num txd, e a NUI consegue exibi-lo por `nui-img`.

    DUAS LIMITACOES, e as duas sao reais:

    1. So funciona para peds carregados no mundo. Um colega do outro lado do
       mapa nao esta em streaming, e nao ha retrato para ele -- a tela cai nas
       iniciais, que e melhor do que um quadrado vazio.

    2. O jogo tem um numero pequeno de handles simultaneos. Por isso o lote
       anterior e liberado antes de pedir um novo: sem isso, depois de algumas
       aberturas do MDT o registro passa a falhar em silencio e ninguem tem
       foto nenhuma.
]]
---@type number[]
local headshots = {}

local function releaseHeadshots()
    for i = 1, #headshots do
        if IsPedheadshotValid(headshots[i]) then
            UnregisterPedheadshot(headshots[i])
        end
    end

    headshots = {}
end

RegisterNUICallback('headshots', function(data, cb)
    local result = {}

    if type(data) ~= 'table' or type(data.ids) ~= 'table' then return cb(result) end

    releaseHeadshots()

    for i = 1, math.min(#data.ids, 12) do
        local serverId = tonumber(data.ids[i])
        local index = serverId and GetPlayerFromServerId(serverId) or -1

        if index ~= -1 then
            local ped = GetPlayerPed(index)

            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local handle = RegisterPedheadshot(ped)

                -- Deadline curto: o retrato e um enfeite util, nao um dado que
                -- justifique segurar a tela.
                local deadline = GetGameTimer() + 1500

                while not IsPedheadshotReady(handle) and GetGameTimer() < deadline do
                    Wait(0)
                end

                if IsPedheadshotReady(handle) and IsPedheadshotValid(handle) then
                    local txd = GetPedheadshotTxdString(handle)

                    result[tostring(serverId)] = ('https://nui-img/%s/%s'):format(txd, txd)
                    headshots[#headshots + 1] = handle
                else
                    UnregisterPedheadshot(handle)
                end
            end
        end
    end

    cb(result)
end)

-- ------------------------------------------------------------ fechar --

CreateThread(function()
    while true do
        if open then
            if IsControlJustReleased(0, 322) then close() end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    releaseHeadshots()

    if open then SetNuiFocus(false, false) end
end)
