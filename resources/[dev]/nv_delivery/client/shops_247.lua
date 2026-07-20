--[[
    nv_delivery — cliente: abastecimento das lojas 24/7

    O ciclo completo:

      1. o gerente libera a carga e entrega a chave do caminhao;
      2. um motorista de NPC traz o caminhao ate a doca, desce, caminha e some;
      3. o jogador tira caixa por caixa do palete -- e a pilha diminui de
         verdade, porque cada caixa da pilha e um prop;
      4. com a porta traseira aberta, guarda cada caixa na carroceria;
      5. so com a carga TODA dentro o ponto de descarga aparece;
      6. na loja, tira caixa por caixa do caminhao e empilha no chao;
      7. volta ao gerente e recebe.

    Uma caixa por vez, sempre. Props e animacao moram aqui; contagem, chave e
    pagamento moram no servidor.
]]

local CFG = Config.Shops247

local job = nil
local depotPed
local dropZone

-- Anim de carregar caixa nas duas maos.
local CARRY_DICT = 'anim@heists@box_carry@'
local CARRY_CLIP = 'idle'

-- ------------------------------------------------------------ utilidades ---

local function notify(message, type)
    lib.notify({ title = 'Entrega 24/7', description = message, type = type or 'inform' })
end

local function deleteProp(entity)
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
end

--- Primeira vaga livre da doca. Todas ocupadas: usa a primeira e deixa o
--- jogador resolver -- melhor um caminhao encostado do que servico travado.
local function pickDockStop()
    for i = 1, #CFG.dockStops do
        local spot = CFG.dockStops[i]

        if #lib.getNearbyVehicles(vec3(spot.x, spot.y, spot.z), 3.5, false) == 0 then
            return spot
        end
    end

    return CFG.dockStops[1]
end

--- Espera uma entidade de rede aparecer neste cliente.
---
--- `NetToVeh`/`NetToPed` logo depois da criacao no servidor devolvem 0: a
--- entidade existe no servidor, mas ainda nao chegou aqui -- ainda mais
--- nascendo a 150m de distancia. Checar uma vez so fazia todo o servico
--- concluir "nao ha motorista" e cair no plano B.
---@param netId number?
---@param timeout number?
---@return number?
local function waitForNetEntity(netId, timeout)
    if not netId then return end

    local deadline = GetGameTimer() + (timeout or 15000)

    while GetGameTimer() < deadline do
        if NetworkDoesNetworkIdExist(netId) then
            local entity = NetToEnt(netId)

            if entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
        end

        Wait(100)
    end
end

local function truckEntity()
    if not job or not job.truckNet then return end

    local truck = NetToVeh(job.truckNet)

    if truck and truck ~= 0 and DoesEntityExist(truck) then return truck end
end

--- A carroceria esta acessivel?
---
--- Nem todo modelo tem porta traseira -- o benson, dependendo da versao, nao
--- tem. `GetVehicleDoorAngleRatio` num indice invalido devolve 0 para sempre,
--- ou seja, "fechada", e o alvo simplesmente nunca aparecia. Sem porta nao ha
--- o que abrir: a carroceria conta como aberta.
---@param truck number
---@return boolean
local function cargoOpen(truck)
    if not CFG.requireDoor then return true end
    if not GetIsDoorValid(truck, CFG.cargoDoor) then return true end

    return GetVehicleDoorAngleRatio(truck, CFG.cargoDoor) > 0.1
end

--- O jogador esta DENTRO da carroceria?
---
--- Medido em coordenadas relativas ao caminhao, e nao por uma zona no mundo:
--- assim a area anda junto com o veiculo. Uma zona fixa so funcionaria com o
--- caminhao parado no ponto exato onde ela tivesse sido criada.
---@param truck number
---@return boolean
local function playerInCargo(truck)
    local area = CFG.cargoArea
    local coords = GetEntityCoords(cache.ped)
    local offset = GetOffsetFromEntityGivenWorldCoords(truck, coords.x, coords.y, coords.z)

    return offset.y >= area.minY and offset.y <= area.maxY
        and math.abs(offset.x) <= area.maxX
        and offset.z >= area.minZ and offset.z <= area.maxZ
end

-- --------------------------------------------------------- caixa na mao ----

local function dropCarried()
    if not job or not job.carrying then return end

    DetachEntity(job.carrying, true, true)
    deleteProp(job.carrying)

    job.carrying = nil
    ClearPedTasks(cache.ped)
end

--- Poe uma caixa nas maos do jogador.
local function carryBox()
    if not job or job.carrying then return false end

    lib.requestAnimDict(CARRY_DICT, 3000)
    lib.requestModel(CFG.boxModel, 3000)

    local coords = GetEntityCoords(cache.ped)
    local box = CreateObject(CFG.boxModel, coords.x, coords.y, coords.z, false, false, false)

    -- Offsets da caixa nas maos: tentativa e erro, nao ha formula. Se ela
    -- aparecer atravessada no peito, e aqui que se ajusta.
    AttachEntityToEntity(box, cache.ped, GetPedBoneIndex(cache.ped, 60309),
        0.05, 0.12, -0.25, 300.0, 180.0, 0.0, false, false, false, false, 2, true)

    TaskPlayAnim(cache.ped, CARRY_DICT, CARRY_CLIP, 3.0, 3.0, -1, 49, 0, false, false, false)

    job.carrying = box

    return true
end

-- ------------------------------------------------------------- paletes -----

--- Monta os paletes com o proprio prop da caixa.
---
--- Empilhar caixas de verdade em vez de usar um prop de "monte de caixas" e o
--- que permite a pilha DIMINUIR: tirar uma caixa apaga uma caixa. Com um prop
--- unico, o palete ficaria cheio ate o fim mesmo depois de esvaziado.
--- Posicoes das 8 caixas de um palete, calculadas a partir do TAMANHO REAL
--- dos modelos.
---
--- Os offsets estavam no config, chutados, e por isso as caixas afundavam no
--- estrado ou flutuavam. Medir resolve de vez e sobrevive a troca de prop:
--- mude o modelo da caixa no config e a pilha se reorganiza sozinha.
---
--- Dois detalhes que a medicao cobre e o chute nao cobria:
---   * a origem do prop nem sempre esta na base (min.z negativo), entao o z
---     precisa somar `-min.z` para a base encostar na superficie;
---   * a altura do estrado varia por modelo.
---@return vector3[]
local function computeStackSlots()
    local bmin, bmax = GetModelDimensions(CFG.boxModel)
    local pmin, pmax = GetModelDimensions(CFG.palletModel)

    local width  = bmax.x - bmin.x
    local depth  = bmax.y - bmin.y
    local height = bmax.z - bmin.z

    -- Quanto subir para a BASE da caixa ficar na altura desejada.
    local base = -bmin.z

    -- Topo do estrado, medido a partir do chao.
    local palletTop = pmax.z - pmin.z

    local gap = 0.02
    local dx = (width + gap) * 0.5
    local dy = (depth + gap) * 0.5

    local slots = {}

    -- Duas camadas de quatro: quatro sobre o estrado, quatro sobre essas.
    for layer = 0, 1 do
        local z = palletTop + layer * height + base

        slots[#slots + 1] = vec3(-dx, -dy, z)
        slots[#slots + 1] = vec3( dx, -dy, z)
        slots[#slots + 1] = vec3(-dx,  dy, z)
        slots[#slots + 1] = vec3( dx,  dy, z)
    end

    return slots
end

local function spawnPallets()
    lib.requestModel(CFG.boxModel, 5000)
    lib.requestModel(CFG.palletModel, 5000)

    local slots = computeStackSlots()

    local remaining = job.total
    local spots = #CFG.palletSpots

    for i = 1, spots do
        -- Divide o que sobrou pelos paletes que faltam: com 5 caixas e 2
        -- paletes, vira 3 e 2 -- e nao 2 e 2 com uma caixa perdida.
        local amount = math.ceil(remaining / (spots - i + 1))

        remaining = remaining - amount

        local spot = CFG.palletSpots[i]
        local stack = {}

        -- O estrado. Fica na lista de props do palete para ser apagado junto
        -- no fim do servico, mesmo nao sendo uma caixa.
        local pallet = CreateObject(CFG.palletModel, spot.x, spot.y, spot.z, false, false, false)

        PlaceObjectOnGroundProperly(pallet)
        SetEntityHeading(pallet, spot.w)
        FreezeEntityPosition(pallet, true)

        job.pallets[#job.pallets + 1] = pallet

        -- O chao do estrado, e nao o z bruto do config: o ponto do palete pode
        -- ter sido capturado com o jogador em pe ali, e ai vem alto demais.
        local ground = GetEntityCoords(pallet).z

        for slot = 1, math.min(amount, #slots) do
            local offset = slots[slot]
            local box = CreateObject(CFG.boxModel,
                spot.x + offset.x, spot.y + offset.y, ground + offset.z, false, false, false)

            SetEntityHeading(box, spot.w)
            FreezeEntityPosition(box, true)

            stack[#stack + 1] = box
        end

        job.stacks[#job.stacks + 1] = stack

        -- O alvo e o palete inteiro, nao cada caixa: mirar a caixa certa de
        -- uma pilha e um teste de pontaria, nao de jogo.
        local index = #job.stacks

        job.zones[#job.zones + 1] = exports.ox_target:addSphereZone({
            coords = vec3(spot.x, spot.y, spot.z + 0.4),
            radius = 1.6,
            debug = false,
            options = {
                {
                    name = ('nv_delivery_pallet_%d'):format(index),
                    icon = 'fa-solid fa-box',
                    label = 'Pegar uma caixa',
                    distance = 2.0,
                    canInteract = function()
                        return job ~= nil and not job.carrying and #job.stacks[index] > 0
                    end,
                    onSelect = function()
                        local stack = job.stacks[index]

                        if #stack == 0 or not carryBox() then return end

                        -- Some a caixa do topo: e a que a pessoa "pegou".
                        deleteProp(stack[#stack])
                        stack[#stack] = nil

                        notify('Guarde a caixa na carroceria do caminhao.', 'inform')
                    end
                }
            }
        })
    end

    SetModelAsNoLongerNeeded(CFG.boxModel)
    SetModelAsNoLongerNeeded(CFG.palletModel)
end

-- ------------------------------------------------------- carroceria -------

--- Guarda a caixa da mao dentro do caminhao.
local function loadBox()
    local truck = truckEntity()

    if not truck then return notify('O caminhao nao esta por perto.', 'error') end
    if not job.carrying then return notify('Voce nao esta com nenhuma caixa.', 'error') end

    local ok, count, full = lib.callback.await('nv_delivery:shop247:loadBox', false)

    if not ok then return notify('Nao foi possivel guardar a caixa.', 'error') end

    dropCarried()

    lib.requestModel(CFG.boxModel, 3000)

    local slot = CFG.cargoSlots[math.min(count, #CFG.cargoSlots)]
    local coords = GetEntityCoords(truck)
    local box = CreateObject(CFG.boxModel, coords.x, coords.y, coords.z, false, false, false)

    -- Presa ao caminhao: a carga tem que andar junto com ele.
    AttachEntityToEntity(box, truck, 0, slot.x, slot.y, slot.z, 0.0, 0.0, 0.0,
        false, false, false, false, 2, true)

    job.cargo[#job.cargo + 1] = box
    job.loaded = count

    if not full then
        return notify(('%d de %d carregadas.'):format(count, job.total), 'success')
    end

    -- So agora o destino existe. Antes disso a rota levaria o jogador a sair
    -- com o caminhao pela metade.
    job.blip = AddBlipForCoord(CFG.dropPoint.x, CFG.dropPoint.y, CFG.dropPoint.z)

    SetBlipSprite(job.blip, 59)
    SetBlipColour(job.blip, 1)
    SetBlipRoute(job.blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Descarga 24/7')
    EndTextCommandSetBlipName(job.blip)

    notify('Carga completa. Leve o caminhao ate a loja.', 'success')
end

--- Tira uma caixa da carroceria para as maos.
local function unloadBox()
    if not job.carrying and #job.cargo > 0 and carryBox() then
        deleteProp(job.cargo[#job.cargo])
        job.cargo[#job.cargo] = nil

        notify('Coloque a caixa no chao, na area marcada.', 'inform')
    end
end

--- Alvos do caminhao: guardar (no galpao) e retirar (na loja).
---@param netId number
local function addTruckTargets(netId)
    exports.ox_target:addEntity(netId, {
        {
            name = 'nv_delivery_truck_load',
            icon = 'fa-solid fa-boxes-packing',
            label = 'Colocar a caixa aqui',
            -- Alcance curto: quem carrega esta em cima da carroceria, nao
            -- mirando de longe.
            distance = 4.0,
            canInteract = function(entity)
                if not job or not job.carrying then return false end

                -- Subir na carroceria e o gesto: a caixa e colocada de dentro.
                return cargoOpen(entity) and playerInCargo(entity)
            end,
            onSelect = loadBox
        },
        {
            name = 'nv_delivery_truck_unload',
            icon = 'fa-solid fa-box-open',
            label = 'Pegar caixa da carroceria',
            distance = 3.0,
            canInteract = function(entity)
                -- Uma caixa por vez, e so na loja: com a carga incompleta ou
                -- longe do destino nao ha o que descarregar.
                if not job or job.carrying or #job.cargo == 0 then return false end
                if job.loaded < job.total then return false end
                if not cargoOpen(entity) then return false end

                local drop = vec3(CFG.dropPoint.x, CFG.dropPoint.y, CFG.dropPoint.z)

                return #(GetEntityCoords(entity) - drop) <= CFG.truckDistance
            end,
            onSelect = unloadBox
        }
    })
end

-- ---------------------------------------------------- colocar no chao ------

--- Coloca a caixa da mao no chao, a frente do jogador.
---
--- Substituiu a pre-visualizacao com fantasma e rotacao. Aquilo dava controle
--- fino sobre a pilha, mas ao custo de tres teclas e um loop de mira para uma
--- acao que se repete de cinco a oito vezes seguidas. Um [E] resolve: quem
--- escolhe onde a caixa cai e a POSICAO DO JOGADOR, que ele ja controla
--- andando -- empilhar continua sendo possivel, so que sem interface.
local function placeBox()
    if not job or not job.carrying then
        return notify('Voce nao esta com nenhuma caixa.', 'error')
    end

    local ok, count, finished = lib.callback.await('nv_delivery:shop247:placeBox', false)

    if not ok then
        return notify('Esta caixa nao foi aceita. O caminhao esta perto o suficiente?', 'error')
    end

    -- Um passo a frente do ped: colocar embaixo dele faria a caixa nascer
    -- dentro das pernas e empurra-lo.
    local spot = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 0.8, -0.9)
    local heading = GetEntityHeading(cache.ped)

    dropCarried()

    lib.requestModel(CFG.boxModel, 3000)

    local box = CreateObject(CFG.boxModel, spot.x, spot.y, spot.z, false, false, false)

    -- Assenta no chao (ou em cima da caixa que ja estiver ali, que e como a
    -- pilha se forma).
    PlaceObjectOnGroundProperly(box)
    SetEntityHeading(box, heading)
    FreezeEntityPosition(box, true)

    job.boxes[#job.boxes + 1] = box
    job.placed = count

    if not finished then
        return notify(('%d de %d entregues.'):format(count, job.total), 'success')
    end

    notify('Carga completa. Volte ao gerente para receber.', 'success')

    -- A loja recolhe tudo de uma vez, e nao caixa a caixa: some a pilha
    -- inteira depois da pausa.
    local boxes = job.boxes

    job.boxes = {}

    SetTimeout(CFG.despawnDelay * 1000, function()
        for i = 1, #boxes do deleteProp(boxes[i]) end
    end)
end

-- ------------------------------------------------------ zona de descarga ---

local function createDropZone()
    if dropZone then return end

    -- Guarda o texto que esta na tela: reenviar o mesmo TextUI a cada frame
    -- faz ele piscar.
    local showing = false

    local function hide()
        if not showing then return end

        showing = false
        lib.hideTextUI()
    end

    dropZone = lib.zones.sphere({
        coords = vec3(CFG.dropPoint.x, CFG.dropPoint.y, CFG.dropPoint.z),
        radius = CFG.dropRadius,
        debug = false,

        inside = function()
            -- O aviso e o circulo so existem com caixa na mao: parado ali de
            -- maos vazias nao ha nada a fazer.
            if not job or not job.carrying then return hide() end

            DrawMarker(1, CFG.dropPoint.x, CFG.dropPoint.y, CFG.dropPoint.z - 0.95,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                CFG.dropRadius * 2, CFG.dropRadius * 2, 0.5,
                255, 36, 56, 90, false, false, 2, false, nil, nil, false)

            if not showing then
                showing = true
                lib.showTextUI('[E] Colocar a caixa no chao')
            end

            if IsControlJustPressed(0, 38) then
                hide()
                placeBox()
            end
        end,

        onExit = hide
    })
end

-- --------------------------------------------------------------- servico ---

local function cleanJob()
    if not job then return end

    dropCarried()

    for _, stack in ipairs(job.stacks) do
        for i = 1, #stack do deleteProp(stack[i]) end
    end

    for i = 1, #job.pallets do deleteProp(job.pallets[i]) end

    for i = 1, #job.cargo do deleteProp(job.cargo[i]) end
    for i = 1, #job.boxes do deleteProp(job.boxes[i]) end

    for i = 1, #job.zones do
        exports.ox_target:removeZone(job.zones[i])
    end

    if job.truckNet then
        exports.ox_target:removeEntity(job.truckNet,
            { 'nv_delivery_truck_load', 'nv_delivery_truck_unload' })
    end

    if job.blip and DoesBlipExist(job.blip) then RemoveBlip(job.blip) end

    job = nil
end

--- O motorista traz o caminhao ate a doca, desce, caminha e some.
---@param truck number
---@param driver number?
local function runDriver(truckNet, driverNet)
    local stop = pickDockStop()

    CreateThread(function()
        -- Espera as duas entidades chegarem ANTES de decidir qualquer coisa.
        local truck = waitForNetEntity(truckNet)
        local driver = waitForNetEntity(driverNet, 5000)

        -- Espera o servidor realmente colocar o NPC no banco
        local timeout = GetGameTimer() + 5000

        while GetGameTimer() < timeout do
            if GetPedInVehicleSeat(truck, -1) == driver then
                break
            end

            Wait(100)
        end

        if not truck then return end

        if not driver then
            -- So agora vale desistir da encenacao: o caminhao aparece na vaga
            -- para o servico nao ficar travado por causa dela.
            SetEntityCoords(truck, stop.x, stop.y, stop.z, false, false, false, false)
            SetEntityHeading(truck, stop.w)
            return
        end

        -- Controle da entidade PRIMEIRO. Sem ele o TaskVehicleDriveToCoord e
        -- aceito e ignorado -- o caminhao simplesmente nao anda.
        local deadline = GetGameTimer() + 3000

        while not NetworkHasControlOfEntity(driver) and GetGameTimer() < deadline do
            NetworkRequestControlOfEntity(driver)
            NetworkRequestControlOfEntity(truck)
            Wait(100)
        end

        SetVehicleEngineOn(truck, true, true, false)
        SetVehicleDoorsLocked(truck, 1)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetDriverAbility(driver, 1.0)
        SetDriverAggressiveness(driver, 0.0)
        SetPedKeepTask(driver, true)

        TaskVehicleDriveToCoordLongrange(driver, truck, stop.x, stop.y, stop.z, 14.0, 786603, 6.0)

            
        -- Prazo porque o transito do GTA as vezes prende um caminhao para
        -- sempre; sem ele o motorista ficaria eternamente a caminho.
        deadline = GetGameTimer() + 120000

        while GetGameTimer() < deadline do
            Wait(500)

            if not DoesEntityExist(truck) or not DoesEntityExist(driver) then return end
            if #(GetEntityCoords(truck) - vec3(stop.x, stop.y, stop.z)) < 7.0 then break end
        end

        if not DoesEntityExist(driver) then return end

        -- O motorista precisa estar sob nosso controle para aceitar a ordem de
        -- descer; ele pode ter migrado de dono durante a viagem.
        NetworkRequestControlOfEntity(driver)
        Wait(100)

        SetPedKeepTask(driver, false)
        ClearPedTasks(driver)
        TaskLeaveVehicle(driver, truck, 0)

        -- Sair nao e garantido: motor batido, porta travada, task perdida na
        -- migracao. Depois de 6s tiramos a mao dele -- ficar sentado para
        -- sempre e pior do que aparecer ao lado do caminhao.
        deadline = GetGameTimer() + 6000

        while GetGameTimer() < deadline do
            Wait(250)

            if not DoesEntityExist(driver) then return end
            if not IsPedInAnyVehicle(driver, false) then break end
        end

        if not DoesEntityExist(driver) then return end

        if IsPedInAnyVehicle(driver, false) then
            ClearPedTasksImmediately(driver)

            local side = GetOffsetFromEntityInWorldCoords(truck, -2.2, 0.0, 0.0)

            SetEntityCoords(driver, side.x, side.y, side.z, false, false, false, false)
        end

        -- Sai andando e some fora de cena, em vez de evaporar ao lado do
        -- jogador.
        local exit = CFG.driverExit

        TaskGoStraightToCoord(driver, exit.x, exit.y, exit.z, 1.0, 20000, exit.w, 0.5)

        deadline = GetGameTimer() + 25000

        while GetGameTimer() < deadline do
            Wait(500)

            if not DoesEntityExist(driver) then return end
            if #(GetEntityCoords(driver) - vec3(exit.x, exit.y, exit.z)) < 2.0 then break end
        end

        deleteProp(driver)
    end)
end

local function startJob()
    if job then return notify('Voce ja esta numa entrega.', 'error') end

    local ok, err, data = lib.callback.await('nv_delivery:shop247:start', false)

    if not ok then return notify(err or 'Nao foi possivel comecar.', 'error') end

    job = {
        total    = data.total,
        loaded   = 0,
        placed   = 0,
        carrying = nil,
        truckNet = data.truckNet,
        pallets  = {},   -- os estrados
        stacks   = {},   -- caixas ainda no palete
        cargo    = {},   -- caixas dentro do caminhao
        boxes    = {},   -- caixas ja no chao da loja
        zones    = {}
    }

    -- Os netIds, e nao as entidades: quem espera elas chegarem e o runDriver.
    runDriver(data.truckNet, data.driverNet)

    addTruckTargets(data.truckNet)
    spawnPallets()
    createDropZone()

    notify(('Carga liberada: %d caixas. A chave do caminhao esta com voce.'):format(data.total), 'success')
end

local function finishJob()
    local ok, err, pay = lib.callback.await('nv_delivery:shop247:finish', false)

    if not ok then return notify(err or 'Nao foi possivel receber.', 'error') end

    cleanJob()
    notify(('Servico concluido. Voce recebeu $%d.'):format(pay or 0), 'success')
end

-- ---------------------------------------------------------------- gerente --

CreateThread(function()
    lib.requestModel(CFG.npcModel, 5000)

    local c = CFG.npcCoords

    depotPed = CreatePed(4, CFG.npcModel, c.x, c.y, c.z - 1.0, c.w, false, true)

    SetModelAsNoLongerNeeded(CFG.npcModel)
    FreezeEntityPosition(depotPed, true)
    SetEntityInvincible(depotPed, true)
    SetBlockingOfNonTemporaryEvents(depotPed, true)
    TaskStartScenarioInPlace(depotPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)

    exports.ox_target:addLocalEntity(depotPed, {
        {
            name = 'nv_delivery_247_start',
            icon = 'fa-solid fa-truck-ramp-box',
            label = 'Pegar entrega das lojas 24/7',
            distance = 2.5,
            canInteract = function() return job == nil end,
            onSelect = startJob
        },
        {
            name = 'nv_delivery_247_finish',
            icon = 'fa-solid fa-hand-holding-dollar',
            label = 'Receber pagamento',
            distance = 2.5,
            canInteract = function() return job ~= nil end,
            onSelect = finishJob
        },
        {
            name = 'nv_delivery_247_cancel',
            icon = 'fa-solid fa-xmark',
            label = 'Cancelar entrega',
            distance = 2.5,
            canInteract = function() return job ~= nil end,
            onSelect = function()
                TriggerServerEvent('nv_delivery:shop247:cancel')
                cleanJob()
            end
        }
    })

    local blip = AddBlipForCoord(c.x, c.y, c.z)

    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Distribuidora 24/7')
    EndTextCommandSetBlipName(blip)
end)

-- ----------------------------------------------------------- diagnostico --

--- Por que o alvo de pegar caixa nao aparece?
---
--- Sao cinco condicoes, e um alvo escondido nao diz qual delas falhou -- o
--- sintoma de "nao tem estoque" e identico ao de "porta fechada". Este comando
--- responde a pergunta em vez de deixar adivinhar.
RegisterCommand('247debug', function()
    if not job then
        return print('[nv_delivery] nenhum servico ativo.')
    end

    local truck = truckEntity()

    print('[nv_delivery] ---- estado do servico 24/7 ----')
    print(('  carga        : %d/%d carregadas, %d entregues'):format(job.loaded, job.total, job.placed))
    print(('  na mao       : %s'):format(job.carrying and 'sim' or 'nao'))
    print(('  na carroceria: %d prop(s)'):format(#job.cargo))

    if not truck then
        return print('  caminhao     : NAO ENCONTRADO (fora de alcance?)')
    end

    local drop = vec3(CFG.dropPoint.x, CFG.dropPoint.y, CFG.dropPoint.z)
    local doorValid = GetIsDoorValid(truck, CFG.cargoDoor)

    print(('  porta %d      : valida=%s  angulo=%.2f  -> acessivel=%s')
        :format(CFG.cargoDoor, tostring(doorValid),
            GetVehicleDoorAngleRatio(truck, CFG.cargoDoor), tostring(cargoOpen(truck))))

    print(('  caminhao->loja: %.1fm (limite %.1f)')
        :format(#(GetEntityCoords(truck) - drop), CFG.truckDistance))

    print(('  voce->caminhao: %.1fm'):format(#(GetEntityCoords(cache.ped) - GetEntityCoords(truck))))
    print(('  dentro da carroceria: %s'):format(tostring(playerInCargo(truck))))
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    cleanJob()
    deleteProp(depotPed)
    lib.hideTextUI()
end)
