--[[
    nv_garage — cliente: pontos de garagem e ponte com a NUI
]]

local menuOpen = false
local currentGarage
local currentOrganization

-- ------------------------------------------------------------- blips --

CreateThread(function()
    for _, garage in pairs(Config.Garages) do
        if garage.blip then
            local blip = AddBlipForCoord(garage.ped.x, garage.ped.y, garage.ped.z)

            SetBlipSprite(blip, garage.blip.sprite or 357)
            SetBlipColour(blip, garage.blip.color or 3)
            SetBlipScale(blip, garage.blip.scale or 0.8)
            SetBlipDisplay(blip, 4)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(garage.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- --------------------------------------------------------- ponto livre --

--- Primeiro ponto de saida sem nada em cima.
--- Sem isso o veiculo nasce dentro do anterior e os dois saem voando.
---@param garage table
---@return number
local function freeSpawnIndex(garage)
    for index = 1, #garage.spawns do
        local spawn = garage.spawns[index]
        local occupied = lib.getNearbyVehicles(vec3(spawn.x, spawn.y, spawn.z), 2.5, true)

        if #occupied == 0 then return index end
    end

    -- Todos ocupados: usa o primeiro e deixa o jogador lidar com a fila.
    return 1
end

-- ------------------------------------------------------------ abrir --

---@param garageName string
local function openMenu(garageName)
    if menuOpen or Garage.busy then return end

    local data = lib.callback.await('nv_garage:list', false, garageName)

    if not data then
        return Garage.notify('Nao foi possivel abrir a garagem.', 'error')
    end

    menuOpen = true
    currentGarage = garageName

    SetNuiFocus(true, true)
    SendNUIMessage({
        action  = 'open',
        label   = data.label,
        list    = data.list,
        bars    = Config.Bars,
        impound = data.impound,
        strict  = data.strict,
        fee     = data.fee
    })
end

local function openOrganizationMenu(set)
    if menuOpen or Garage.busy then return end
    local data=lib.callback.await('nv_orgs:fleetFor',false,set)
    if not data then return Garage.notify('Voce nao tem acesso a esta garagem.','error') end
    menuOpen=true
    currentGarage=nil
    currentOrganization=set
    SetNuiFocus(true,true)
    SendNUIMessage({action='open',label=data.org or set,list=data.owned or {},bars=Config.Bars,impound=false,strict=false,organization=true})
end

RegisterNetEvent('nv_garage:openOrganization',openOrganizationMenu)
exports('OpenOrganization',openOrganizationMenu)

local function closeMenu()
    if not menuOpen then return end

    menuOpen = false
    currentGarage = nil
    currentOrganization = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- --------------------------------------------------------- sair do carro --

--- Desce do veiculo antes de guarda-lo, com a animacao normal de saida.
---
--- Guardar com o jogador ainda no banco fazia o carro sumir por baixo dele: o
--- ped ficava um instante flutuando na posicao de dirigir antes de cair. Sair
--- primeiro resolve isso e ainda faz o gesto parecer o que e -- estacionar,
--- descer, entregar.
---
---@param vehicle number
---@return boolean ok
local function leaveVehicle(vehicle)
    if cache.vehicle ~= vehicle then return true end

    -- Animacao desligada no config: guarda direto, como antes.
    if not Config.Garage.exitAnimation then return true end

    -- Descer de um carro em movimento derruba o ped no chao. Melhor recusar do
    -- que entregar um estacionamento com cambalhota.
    if GetEntitySpeed(vehicle) > 2.0 then
        Garage.notify('Pare o veiculo antes de guardar.', 'error')
        return false
    end

    TaskLeaveVehicle(cache.ped, vehicle, 0)

    -- Espera a animacao terminar de verdade. O deadline existe porque a saida
    -- pode ser interrompida (carro capota, jogador morre) e travar aqui seria
    -- pior do que guardar mesmo assim.
    local deadline = GetGameTimer() + 4000

    while cache.vehicle and GetGameTimer() < deadline do
        Wait(50)
    end

    -- Respiro para a porta fechar antes de o carro sumir.
    Wait(250)

    return true
end

local currentTrackBlip = nil
local trackTimerThread = 0

local function trackVehicleLocation(data)
    if type(data) ~= 'table' then return false end

    -- Se estiver fora da garagem e possuir bloqueador de sinal ativo, bloqueia o rastreamento
    if data.status == 'out' and data.hasBlocker then
        TriggerEvent('ox_lib:notify', { type = 'error', description = 'Sinal GPS bloqueado! O veículo possui um bloqueador de sinal ativo.' })
        return false
    end

    local x, y, z
    if type(data.coords) == 'table' and tonumber(data.coords.x) and tonumber(data.coords.y) then
        x = tonumber(data.coords.x) + 0.0
        y = tonumber(data.coords.y) + 0.0
        z = tonumber(data.coords.z or 0) + 0.0
    end

    if not x or not y then
        TriggerEvent('ox_lib:notify', { type = 'error', description = 'Não foi possível determinar a localização no GPS.' })
        return false
    end

    trackTimerThread = trackTimerThread + 1
    local thisThread = trackTimerThread

    if currentTrackBlip and DoesBlipExist(currentTrackBlip) then
        RemoveBlip(currentTrackBlip)
        currentTrackBlip = nil
    end

    local blipLabel = (data.status == 'impound' and 'Pátio de Apreensão') or (data.label and data.label ~= '' and data.label) or 'Garagem / Veículo'

    currentTrackBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(currentTrackBlip, 161) -- Blip 161
    SetBlipColour(currentTrackBlip, 47) -- Laranja
    SetBlipScale(currentTrackBlip, 0.9)
    SetBlipAsShortRange(currentTrackBlip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipLabel)
    EndTextCommandSetBlipName(currentTrackBlip)

    TriggerEvent('ox_lib:notify', {
        type = 'success',
        description = ('Localização de "%s" exibida no minimapa (30s)!'):format(blipLabel)
    })

    -- Remove o blip automaticamente após 30 segundos
    CreateThread(function()
        Wait(30000)
        if trackTimerThread == thisThread and currentTrackBlip and DoesBlipExist(currentTrackBlip) then
            RemoveBlip(currentTrackBlip)
            currentTrackBlip = nil
        end
    end)

    return true
end

RegisterNUICallback('track', function(data, cb)
    local ok = trackVehicleLocation(data)
    cb({ ok = ok })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('takeOut', function(data, cb)
    local garageName = currentGarage

    if currentOrganization then
        local ok,err=lib.callback.await('nv_orgs:takeFleetVehicle',false,currentOrganization,data and data.id)
        if not ok then Garage.notify(err or 'Nao foi possivel liberar o veiculo.','error'); return cb({ok=false,error=err}) end
        closeMenu()
        Garage.notify('Veiculo liberado. A chave esta com voce.','success')
        return cb({ok=true})
    end

    if not garageName or type(data) ~= 'table' or type(data.id) ~= 'number' then
        return cb({ ok = false })
    end

    local garage = Config.Garages[garageName]
    if not garage then return cb({ ok = false }) end

    local ok, err = lib.callback.await('nv_garage:takeOut', false, garageName, data.id, freeSpawnIndex(garage))

    if not ok then
        Garage.notify(err or 'Nao foi possivel liberar o veiculo.', 'error')
        return cb({ ok = false, error = err })
    end

    closeMenu()
    Garage.notify('Veiculo liberado. A chave esta com voce.', 'success')

    cb({ ok = true })
end)

RegisterNUICallback('store', function(data, cb)
    local garageName = currentGarage

    if currentOrganization then
        if type(data)~='table' or type(data.plate)~='string' then return cb({ok=false}) end
        local nearby=lib.getNearbyVehicles(GetEntityCoords(cache.ped),12.0,true)
        local target
        for i=1,#nearby do if Garage.plateOf(nearby[i].vehicle)==data.plate then target=nearby[i].vehicle break end end
        if not target then Garage.notify('Traga o veiculo ate a garagem para guarda-lo.','error'); return cb({ok=false}) end
        local mechanical=GetResourceState('nv_mechanic')=='started' and exports.nv_mechanic:GetSnapshot(target) or nil
        local ok,err=lib.callback.await('nv_orgs:storeFleetVehicle',false,currentOrganization,VehToNet(target),lib.getVehicleProperties(target),mechanical)
        if not ok then Garage.notify(err or 'Nao foi possivel guardar.','error'); return cb({ok=false,error=err}) end
        closeMenu(); Garage.notify('Veiculo guardado.','success'); return cb({ok=true})
    end

    if not garageName or type(data) ~= 'table' or type(data.plate) ~= 'string' then
        return cb({ ok = false })
    end

    -- A NUI so conhece a placa; a entidade quem acha e o cliente.
    local target

    if cache.vehicle and Garage.plateOf(cache.vehicle) == data.plate then
        target = cache.vehicle
    else
        local nearby = lib.getNearbyVehicles(GetEntityCoords(cache.ped), 12.0, true)

        for i = 1, #nearby do
            if Garage.plateOf(nearby[i].vehicle) == data.plate then
                target = nearby[i].vehicle
                break
            end
        end
    end

    if not target then
        Garage.notify('Traga o veiculo ate a garagem para guarda-lo.', 'error')
        return cb({ ok = false })
    end

    local netId = VehToNet(target)

    -- Fecha o painel antes da animacao: guardar dali so acontece com o carro
    -- na garagem, e ver o proprio ped descendo por tras de um menu aberto e
    -- estranho.
    closeMenu()

    if not leaveVehicle(target) then return cb({ ok = false }) end
    if not DoesEntityExist(target) then return cb({ ok = false }) end

    local mechanical = GetResourceState('nv_mechanic') == 'started'
        and exports.nv_mechanic:GetSnapshot(target) or nil
    local ok, err = lib.callback.await('nv_garage:store', false, garageName,
        netId, lib.getVehicleProperties(target), mechanical)

    if not ok then
        Garage.notify(err or 'Nao foi possivel guardar.', 'error')
        return cb({ ok = false, error = err })
    end

    -- O menu ja foi fechado antes da animacao.
    Garage.notify('Veiculo guardado.', 'success')

    cb({ ok = true })
end)

-- --------------------------------------------------------------- vagas --

--- Guarda o veiculo em que o jogador esta, na vaga onde ele parou.
---
--- O servidor grava a posicao exata da entidade antes de despawnar, entao
--- "onde parou" e literal: nao e o centro da vaga, e onde o carro ficou.
---@param garageName string
local function storeHere(garageName)
    local vehicle = cache.vehicle

    if not vehicle then return end

    if cache.seat ~= -1 then
        return Garage.notify('So quem esta ao volante pode guardar o veiculo.', 'error')
    end

    if Garage.busy then return end

    -- O netId e lido ANTES de descer: durante a animacao o carro continua o
    -- mesmo, mas `cache.vehicle` ja zerou e a referencia se perderia.
    local netId = VehToNet(vehicle)

    Garage.busy = true

    local left = leaveVehicle(vehicle)

    Garage.busy = false

    if not left then return end
    if not DoesEntityExist(vehicle) then return end

    -- `getVehicleProperties` so existe no cliente: e daqui que sai o estado do
    -- carro (portas arrancadas, vidros, pneus, mods) para o servidor salvar.
    local mechanical = GetResourceState('nv_mechanic') == 'started'
        and exports.nv_mechanic:GetSnapshot(vehicle) or nil
    local ok, err = lib.callback.await('nv_garage:store', false, garageName,
        netId, lib.getVehicleProperties(vehicle), mechanical)

    if not ok then
        return Garage.notify(err or 'Nao foi possivel guardar.', 'error')
    end

    Garage.notify('Veiculo guardado nesta vaga.', 'success')
end

--- Marcador + [E] em cada vaga.
---
--- A vaga faz UMA coisa: guardar o veiculo em que voce esta. Abrir a lista e
--- com o atendente, e so com ele -- uma vaga que tambem abria a garagem
--- transformava o ped em decoracao, porque ninguem anda ate o balcao quando o
--- chao ja resolve.
---@param garageName string
---@param garage table
local function createSpotPoints(garageName, garage)
    -- No patio as vagas nao tem interacao nenhuma: nao se guarda ali, e a
    -- liberacao e com o fiscal. Elas continuam existindo no servidor, que e
    -- quem usa a lista de `spawns` para escolher onde o carro nasce.
    if garage.impound then return end

    local marker = Config.Garage.spotMarker or Config.Garage.marker

    for index = 1, #garage.spawns do
        local spawn = garage.spawns[index]

        lib.points.new({
            coords = vec3(spawn.x, spawn.y, spawn.z),
            distance = marker.drawDistance,
            garageName = garageName,

            nearby = function(self)
                -- Marcador so quando ligado no config. Com uma vaga a cada
                -- dois metros, dez circulos vermelhos acesos ao mesmo tempo
                -- viram poluicao visual; o [E] de perto ja diz onde parar.
                if Config.Garage.showSpotMarkers then
                    DrawMarker(marker.type, self.coords.x, self.coords.y, self.coords.z,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        marker.scale.x, marker.scale.y, marker.scale.z,
                        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                        false, true, 2, nil, nil, false)
                end

                -- A pe a vaga nao oferece nada: quem esta fora do carro fala
                -- com o atendente.
                local driving = cache.vehicle and cache.seat == -1

                if menuOpen or not driving or self.currentDistance > Config.Garage.spotRadius then
                    if self.showing then
                        self.showing = false
                        lib.hideTextUI()
                    end

                    return
                end

                if not self.showing then
                    self.showing = true
                    lib.showTextUI('[E] Guardar veiculo nesta vaga')
                end

                if IsControlJustReleased(0, 38) then
                    lib.hideTextUI()
                    self.showing = false

                    storeHere(self.garageName)
                end
            end,

            onExit = function(self)
                if self.showing then
                    self.showing = false
                    lib.hideTextUI()
                end
            end
        })
    end
end

-- ----------------------------------------------------------- atendente --

--- Peds criados por este resource, para apagar no stop.
---@type number[]
local attendants = {}

--- Cria o atendente da garagem.
---
--- Devolve o ped, ou nil se o modelo nao carregou -- nesse caso quem chama
--- precisa cair na zona invisivel, senao a garagem fica sem interacao.
---@param garage table
---@return number?
local function createAttendant(garage)
    local settings = garage.impound and Config.Peds.impound or Config.Peds.garage

    if not settings or not settings.model then return end

    local model = joaat(settings.model)

    -- 5s: modelo de ped e leve, e travar o boot do resource esperando um
    -- modelo que talvez nem exista no servidor nao vale a pena.
    if not lib.requestModel(model, 5000) then
        lib.print.warn(('Nao foi possivel carregar o modelo "%s" do atendente.'):format(settings.model))
        return
    end

    -- O `ped` da garagem e a coordenada de quem esta EM PE ali, entao vem com
    -- a altura dos olhos. Sem o desconto o atendente nasce flutuando.
    local coords = garage.ped
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z + Config.Peds.zOffset,
        garage.pedHeading or 0.0, false, true)

    SetModelAsNoLongerNeeded(model)

    if not ped or ped == 0 then return end

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)  -- nao foge de tiro nem de buzina

    if settings.scenario then
        TaskStartScenarioInPlace(ped, settings.scenario, 0, true)
    end

    attendants[#attendants + 1] = ped

    return ped
end

-- ---------------------------------------------------------- interacao --

CreateThread(function()
    -- As vagas sempre existem, independente de `useTarget`: elas sao o [E] de
    -- guardar e o unico lugar que sabe em que ponto o carro parou.
    for name, garage in pairs(Config.Garages) do
        createSpotPoints(name, garage)
    end

    if Config.Garage.useTarget and GetResourceState('ox_target') == 'started' then
        for name, garage in pairs(Config.Garages) do
            local label = garage.impound and 'Falar com o fiscal' or 'Falar com o atendente'
            local icon = garage.impound and 'fa-solid fa-clipboard-list' or 'fa-solid fa-warehouse'

            local option = {
                name = ('nv_garage_%s'):format(name),
                label = label,
                icon = icon,
                distance = Config.Garage.radius + 1.0,
                onSelect = function()
                    openMenu(name)
                end
            }

            local attendant = Config.Peds.enabled and createAttendant(garage)

            if attendant then
                -- O alvo e o proprio atendente: mirar a pessoa e mais claro do
                -- que mirar um ponto no ar onde ela por acaso esta.
                exports.ox_target:addLocalEntity(attendant, { option })
            else
                exports.ox_target:addBoxZone({
                    coords = garage.ped,
                    size = vec3(Config.Garage.radius * 2, Config.Garage.radius * 2, 2.0),
                    rotation = 0,
                    debug = false,
                    options = { option }
                })
            end
        end

        return
    end

    -- Sem ox_target o atendente e so cenario: quem abre a lista e o [E].
    if Config.Peds.enabled then
        for _, garage in pairs(Config.Garages) do
            createAttendant(garage)
        end
    end

    -- Sem ox_target: marcador no chao e tecla E.
    --
    -- O patio fica de fora tambem aqui. Sem ox_target ele fica sem interacao
    -- nenhuma, e isso e proposital: a regra e "so pelo fiscal", e um [E] no
    -- chao seria justamente o atalho que se quis tirar.
    for name, garage in pairs(Config.Garages) do
        if not garage.impound then
            lib.points.new({
                coords = garage.ped,
                distance = Config.Garage.marker.drawDistance,
                garageName = name,

                nearby = function(self)
                    local marker = Config.Garage.marker

                    DrawMarker(marker.type, self.coords.x, self.coords.y, self.coords.z,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        marker.scale.x, marker.scale.y, marker.scale.z,
                        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                        false, true, 2, nil, nil, false)

                    if self.currentDistance > Config.Garage.radius then
                        if self.showing then
                            self.showing = false
                            lib.hideTextUI()
                        end

                        return
                    end

                    if not self.showing then
                        self.showing = true
                        lib.showTextUI(('[E] %s'):format(garage.label))
                    end

                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        self.showing = false
                        openMenu(self.garageName)
                    end
                end,

                onExit = function(self)
                    if self.showing then
                        self.showing = false
                        lib.hideTextUI()
                    end
                end
            })
        end
    end
end)

-- ESC fecha, como em qualquer menu.
CreateThread(function()
    while true do
        if menuOpen then
            if IsControlJustReleased(0, 322) then closeMenu() end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Sem isto cada restart deixa um atendente parado no lugar, e em pouco
    -- tempo ha uma fila de sosias na garagem.
    for i = 1, #attendants do
        if DoesEntityExist(attendants[i]) then DeleteEntity(attendants[i]) end
    end

    if menuOpen then
        SetNuiFocus(false, false)
    end
end)

-- ------------------------------------------------- captura de posicao ----

--- Imprime no F8 a linha de config do atendente da garagem mais proxima, com a
--- posicao e a direcao em que voce esta agora.
---
--- Existe porque a posicao certa do atendente e uma decisao que so se toma
--- dentro do jogo: "dentro da casinha" nao e uma coordenada que se calcula
--- olhando o mapa, e chutar 12 pares de numeros produziria doze atendentes
--- dentro de paredes. Entao: entre na guarita, olhe para onde o atendente deve
--- olhar, digite /garageped e cole a linha no config.
RegisterCommand('garageped', function()
    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)

    local closest, closestDistance

    for name, garage in pairs(Config.Garages) do
        local distance = #(coords - garage.ped)

        if not closestDistance or distance < closestDistance then
            closest, closestDistance = name, distance
        end
    end

    if not closest then
        return print('[nv_garage] nenhuma garagem configurada.')
    end

    print(('[nv_garage] garagem mais proxima: %s (%.1fm)'):format(closest, closestDistance))
    print(('        ped        = vec3(%.2f, %.2f, %.2f),'):format(coords.x, coords.y, coords.z))
    print(('        pedHeading = %.2f,'):format(heading))
end, false)

-- Ultima linha do arquivo: e o que /nvgaragecheck usa para saber que
-- garage.lua carregou inteiro.
Garage.garageLoaded = true
