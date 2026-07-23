--[[
    nv_delivery — servidor: abastecimento das lojas 24/7

    O servico so existe quando as lojas realmente precisam: quem responde por
    isso e o nv_shops, que mantem a fila de reposicao (loja sem item ou com
    estoque abaixo do limite). Sem fila, o gerente nao tem carga para dar.

    Quem conta caixa e quem paga e este arquivo. O cliente diz "coloquei uma
    caixa"; quantas existiam e quanto vale cada uma nunca sai daqui.
]]

local CFG = Config.Shops247

-- [src] = { truck, driver, total, placed, done, expires }
local jobs = {}

-- Uma corrida sem fim nao pode segurar o caminhao para sempre.
local JOB_TTL = 1800000  -- 30 min

-- --------------------------------------------------------------- fila ------

--- As lojas 24/7 precisam de reposicao agora?
---
--- Pergunta ao nv_shops em vez de manter uma segunda contagem: duas fontes
--- para a mesma verdade sempre divergem, e a que manda e a de quem tem o
--- estoque.
---@return table[]?
local function restockQueue()
    if GetResourceState('nv_shops') ~= 'started' then return end

    local ok, queue = pcall(function()
        return exports.nv_shops:GetRestockQueue()
    end)

    if not ok or type(queue) ~= 'table' then return end

    return queue
end

lib.callback.register('nv_delivery:shop247:available', function(source)
    local queue = restockQueue()

    if not queue then
        return false, 'O sistema de estoque das lojas esta fora do ar.'
    end

    if #queue == 0 then
        return false, 'Nenhuma loja precisa de reposicao agora.'
    end

    return true, ('%d loja(s) aguardando reposicao.'):format(#queue)
end)

--- Aviso disparado pelo nv_shops quando a fila enche.
---
--- O servico ja e "puxado" (so comeca com fila), entao isto e so o chamado --
--- e o que faz alguem sair de casa para pegar a corrida em vez de descobrir
--- por acaso ao passar no galpao.
local function sendPhoneNotification(target, data)
    if GetResourceState('npwd') ~= 'started' then return end
    TriggerEvent('npwd:serverCreateNotification', target, data)
end

RegisterNetEvent('nv_delivery:shop247:restockNeeded', function(queue)
    -- Evento do proprio servidor: um cliente nao pode forjar o chamado.
    if source ~= 0 and source ~= '' then return end
    if type(queue) ~= 'table' or #queue == 0 then return end

    sendPhoneNotification(-1, {
        app = '247',
        title = 'Distribuidora 24/7',
        content = ('%d loja(s) estão sem estoque. Há carga esperando no galpão.'):format(#queue),
        duration = 8000
    })
end)

--- Dispara o evento a mao (menu de admin).
---
--- Nao basta avisar: se as lojas estiverem cheias, o `start` recusa a corrida
--- e o evento vira um anuncio mentiroso. Entao ele CRIA a condicao primeiro --
--- esvazia algumas lojas -- e so depois chama. E o mesmo que o evento dos
--- postos faz ao coloca-los em nivel critico.
---@return boolean ok
---@return number afetadas
---@return string? motivo da falha
local function startShop247Event()
    if GetResourceState('nv_shops') ~= 'started' then
        return false, 0, 'O nv_shops nao esta rodando.'
    end

    -- O erro do pcall era engolido: qualquer falha aqui virava a mesma
    -- mensagem generica, e a causa real morria sem aparecer em lugar nenhum.
    local ok, err = pcall(function() exports.nv_shops:DrainShops() end)

    if not ok then
        print(('^1[nv_delivery] DrainShops falhou: %s^7'):format(tostring(err)))

        return false, 0, 'Erro ao esvaziar o estoque (veja o console).'
    end

    local queue = restockQueue()

    if not queue then
        return false, 0, 'O nv_shops nao respondeu a consulta de estoque.'
    end

    if #queue == 0 then
        -- Chegar aqui depois de um drain bem-sucedido quase sempre significa
        -- que as lojas ainda nao terminaram de carregar do banco.
        return false, 0, 'Estoque esvaziado, mas a fila voltou vazia. As lojas ja terminaram de carregar?'
    end

    TriggerEvent('nv_delivery:shop247:restockNeeded', queue)

    return true, #queue
end

exports('startShop247Event', startShop247Event)

-- ------------------------------------------------------------ comecar ------

local function cleanup(src)
    local job = jobs[src]
    if not job then return end

    if job.truck and DoesEntityExist(job.truck) then DeleteEntity(job.truck) end
    if job.driver and DoesEntityExist(job.driver) then DeleteEntity(job.driver) end

    jobs[src] = nil
end

lib.callback.register('nv_delivery:shop247:start', function(source)
    local src = source

    if jobs[src] then return false, 'Voce ja esta numa entrega.' end

    local queue = restockQueue()

    if not queue or #queue == 0 then
        return false, 'Nenhuma loja precisa de reposicao agora.'
    end

    local ped = GetPlayerPed(src)

    if not ped or ped == 0 or #(GetEntityCoords(ped) - vec3(CFG.npcCoords.x, CFG.npcCoords.y, CFG.npcCoords.z)) > 8.0 then
        return false, 'Fale com o gerente no galpao.'
    end

    local spawn = CFG.truckSpawn
    local truck = CreateVehicle(CFG.truckModel, spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    local deadline = GetGameTimer() + 5000

    while not DoesEntityExist(truck) and GetGameTimer() < deadline do Wait(50) end

    if not DoesEntityExist(truck) then
        return false, 'Nao foi possivel tirar o caminhao da garagem.'
    end

    -- Motorista sai do servidor para existir para todo mundo: um ped local
    -- dirigindo um caminhao em rede daria um caminhao andando sozinho na tela
    -- dos outros.
    local driver = CreatePed(4, CFG.driverModel, spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    deadline = GetGameTimer() + 5000

    while not DoesEntityExist(driver) and GetGameTimer() < deadline do Wait(50) end

    if DoesEntityExist(driver) then
        TaskWarpPedIntoVehicle(driver, truck, -1)
    end

    local total = math.random(CFG.box.min, CFG.box.max)

    jobs[src] = {
        truck   = truck,
        driver  = DoesEntityExist(driver) and driver or nil,
        total   = total,
        loaded  = 0,   -- caixas ja dentro da carroceria
        placed  = 0,   -- caixas ja no chao da loja
        done    = false,
        expires = GetGameTimer() + JOB_TTL
    }

    -- A chave sai do nv_garage, e nao um item improvisado aqui: chave de
    -- caminhao tem que ser a mesma chave de qualquer outro veiculo, senao a
    -- ignicao do garage nao a reconhece.
    local plate = GetVehicleNumberPlateText(truck)

    if plate and GetResourceState('nv_garage') == 'started' then
        pcall(function()
            exports.nv_garage:GiveKey(src, plate, 'Caminhao de entrega')
        end)
    end

    return true, nil, {
        truckNet  = NetworkGetNetworkIdFromEntity(truck),
        driverNet = DoesEntityExist(driver) and NetworkGetNetworkIdFromEntity(driver) or nil,
        total     = total
    }
end)

-- -------------------------------------------------------- carregar ------

--- Uma caixa entrou na carroceria.
---
--- Contada no servidor pelo mesmo motivo das outras: e ela que libera o ponto
--- de descarga. Se o cliente decidisse "carreguei tudo", entregaria um
--- caminhao vazio.
lib.callback.register('nv_delivery:shop247:loadBox', function(source)
    local src = source
    local job = jobs[src]

    if not job or job.done then return false end
    if job.loaded >= job.total then return false end

    local ped = GetPlayerPed(src)
    local truck = job.truck

    if not ped or ped == 0 or not truck or not DoesEntityExist(truck) then return false end
    if #(GetEntityCoords(ped) - GetEntityCoords(truck)) > 6.0 then return false end

    job.loaded = job.loaded + 1

    return true, job.loaded, job.loaded >= job.total
end)

-- ------------------------------------------------------- colocar caixa ------

--- Uma caixa posta no chao da loja.
---
--- O cliente manda apenas "coloquei". Quantas faltam e decisao daqui: sem
--- isso, um cliente adulterado chamaria isto N vezes e receberia por caixas
--- que nunca existiram.
lib.callback.register('nv_delivery:shop247:placeBox', function(source)
    local src = source
    local job = jobs[src]

    if not job then return false end
    if job.done then return false end

    if GetGameTimer() > job.expires then
        cleanup(src)
        return false
    end

    if job.placed >= job.total then return false end

    -- A carga tem que estar TODA no caminhao antes da primeira entrega. E a
    -- mesma regra que esconde o ponto de descarga no cliente, repetida aqui
    -- porque esconder nao e impedir.
    if job.loaded < job.total then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local drop = vec3(CFG.dropPoint.x, CFG.dropPoint.y, CFG.dropPoint.z)

    -- Empilhar "em volta do ponto" e o pedido, entao o raio e generoso -- mas
    -- existe: sem ele daria para descarregar o caminhao do outro lado do mapa.
    if #(GetEntityCoords(ped) - drop) > CFG.dropRadius + 2.0 then
        return false
    end

    -- O caminhao tambem precisa estar perto: a caixa sai da carroceria, entao
    -- entregar com o caminhao estacionado a dois bairros nao faz sentido.
    local truck = job.truck

    if not truck or not DoesEntityExist(truck)
        or #(GetEntityCoords(truck) - drop) > CFG.truckDistance then
        return false
    end

    job.placed = job.placed + 1

    local finished = job.placed >= job.total

    if finished then job.done = true end

    return true, job.placed, finished
end)

-- ----------------------------------------------------------- receber ------

lib.callback.register('nv_delivery:shop247:finish', function(source)
    local src = source
    local job = jobs[src]

    if not job then return false, 'Voce nao esta em uma entrega.' end

    if not job.done then
        return false, ('Ainda faltam %d caixa(s).'):format(job.total - job.placed)
    end

    local ped = GetPlayerPed(src)

    if not ped or ped == 0 or #(GetEntityCoords(ped) - vec3(CFG.npcCoords.x, CFG.npcCoords.y, CFG.npcCoords.z)) > 8.0 then
        return false, 'Volte ao gerente no galpao para receber.'
    end

    -- Pagamento montado aqui, a partir do que o SERVIDOR contou.
    local pay = job.placed * CFG.box.value + (CFG.deliveryReward or 0)

    cleanup(src)

    exports.ox_inventory:AddItem(src, 'money', pay)

    -- A carga saiu do caixa das lojas: entregar suprimento custa dinheiro a
    -- quem recebe, senao a mercadoria aparece do nada na economia.
    local cost = CFG.deliveryCost or 0

    if cost > 0 then
        MySQL.update('UPDATE `shops_247` SET `cash` = GREATEST(0, `cash` - ?)', { cost })
    end

    return true, nil, pay
end)

RegisterNetEvent('nv_delivery:shop247:cancel', function()
    local src = source

    if not jobs[src] then return end

    cleanup(src)

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'inform',
        description = 'Entrega cancelada. Nada foi pago.'
    })
end)

AddEventHandler('playerDropped', function()
    cleanup(source)
end)

-- Corridas abandonadas (jogador travou, caiu sem disparar o evento) nao podem
-- deixar caminhao e motorista parados no mapa para sempre.
CreateThread(function()
    while true do
        Wait(120000)

        local now = GetGameTimer()

        for src, job in pairs(jobs) do
            if now > job.expires or not GetPlayerName(src) then
                cleanup(src)
            end
        end
    end
end)
