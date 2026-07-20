--[[
    nv_adminmenu — cliente: painel de administracao

    Abre com a tecla configurada em `Config.PanelKey`. O painel e uma tela: as
    acoes que mexem em outro jogador ou no mundo vao para o servidor, que
    revalida admin. Ficam aqui apenas as que sao locais por natureza -- noclip,
    invisibilidade, teleporte para o marcador.
]]

local open = false

-- Estados locais que o painel alterna. Sao do CLIENTE porque so afetam quem
-- clicou: nao ha o que o servidor decida sobre a sua propria invisibilidade.
local invisible = false
local godmode = false

local function notify(message, type)
    lib.notify({ title = 'Painel Admin', description = message, type = type or 'inform' })
end

-- ------------------------------------------------------------- abrir ------

local function closePanel()
    if not open then return end

    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'panel:close' })
end

local function openPanel()
    if open then return end

    local data = lib.callback.await('nv_adminmenu:panel:open', false)

    if not data then
        return notify('Voce nao tem permissao para abrir o painel.', 'error')
    end

    open = true

    data.action = 'panel:open'
    data.noclip = AdminTools and AdminTools.noclipActive and AdminTools.noclipActive() or false

    -- Estado do alinhador de props. Vai junto na abertura porque e pequeno e
    -- muda pouco: uma segunda viagem so para preencher quatro campos seria
    -- latencia sem ganho.
    if AdminTools and AdminTools.getPropConfig then
        data.props = AdminTools.getPropConfig()
        data.props.saved = AdminTools.getSavedProps and AdminTools.getSavedProps() or {}
    end

    SetNuiFocus(true, true)
    SendNUIMessage(data)
end

exports('OpenPanel', openPanel)

-- O client.lua carrega ANTES deste arquivo e nao teria como enxergar
-- `openPanel`. Publicar aqui e o que faz o /adminmenu abrir a tela.
if AdminTools then AdminTools.openPanel = openPanel end

-- ------------------------------------------------------- acoes locais -----

--- Teleporta para o marcador do mapa.
---
--- O `z` do waypoint nao vem no blip, so x e y. Testamos alturas de cima para
--- baixo ate achar chao: sem isso o teleporte cairia embaixo do mapa em
--- qualquer lugar que nao fosse o nivel do mar.
local function teleportToWaypoint()
    local blip = GetFirstBlipInfoId(8)

    if not DoesBlipExist(blip) then
        return notify('Nenhum marcador no mapa.', 'error')
    end

    local coords = GetBlipInfoIdCoord(blip)

    for height = 1, 1000, 24 do
        SetPedCoordsKeepVehicle(cache.ped, coords.x, coords.y, height + 0.0)

        local found, ground = GetGroundZFor_3dCoord(coords.x, coords.y, height + 0.0, false)

        if found then
            SetPedCoordsKeepVehicle(cache.ped, coords.x, coords.y, ground)

            return notify('Teleportado para o marcador.', 'success')
        end

        Wait(10)
    end

    notify('Nao foi possivel achar o chao no marcador.', 'error')
end

local function healSelf()
    local ped = cache.ped

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end

local function reviveSelf()
    local ped = cache.ped

    if IsEntityDead(ped) then
        local coords = GetEntityCoords(ped)

        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    end

    healSelf()
end

local function currentVehicle()
    local vehicle = cache.vehicle

    if vehicle and DoesEntityExist(vehicle) then return vehicle end
end

--- Veiculo temporario para teste. Nao passa pelo ox_core de proposito: e um
--- carro descartavel, sem dono e sem registro -- quem quer um veiculo de
--- verdade usa "Registrar", que grava no nome de alguem.
---@param model string
local function spawnVehicle(model)
    local hash = joaat(model)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return notify(('Modelo invalido: %s'):format(model), 'error')
    end

    if not lib.requestModel(hash, 8000) then
        return notify('O modelo nao carregou a tempo.', 'error')
    end

    local coords = GetEntityCoords(cache.ped)
    local forward = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 4.0, 0.0)

    local vehicle = CreateVehicle(hash, forward.x, forward.y, coords.z,
        GetEntityHeading(cache.ped) + 90.0, true, false)

    SetModelAsNoLongerNeeded(hash)

    if not vehicle or vehicle == 0 then
        return notify('Nao foi possivel criar o veiculo.', 'error')
    end

    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, 'ADMIN')
    TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)

    notify(('%s criado.'):format(model:upper()), 'success')
end

-- --------------------------------------------------- despacho de acoes ----

local actions = {}

function actions.noclip()
    if not AdminTools or not AdminTools.toggleNoclip then return end

    AdminTools.toggleNoclip()

    SendNUIMessage({
        action = 'panel:noclip',
        value = AdminTools.noclipActive and AdminTools.noclipActive() or false
    })
end

function actions.revive() reviveSelf() end
function actions.heal() healSelf() end
function actions.armour() SetPedArmour(cache.ped, 100) end
function actions.waypoint() teleportToWaypoint() end

function actions.invisible()
    invisible = not invisible
    SetEntityVisible(cache.ped, not invisible, false)

    notify(invisible and 'Voce esta invisivel.' or 'Voce esta visivel.', 'inform')
end

function actions.godmode()
    godmode = not godmode
    SetEntityInvincible(cache.ped, godmode)
    SetPlayerInvincible(PlayerId(), godmode)

    notify(godmode and 'Modo deus ligado.' or 'Modo deus desligado.', 'inform')
end

function actions.pedmenu()
    TriggerEvent('illenium-appearance:client:openClothingShopMenu', true)
end

function actions.fix()
    local vehicle = currentVehicle()

    if not vehicle then return notify('Voce nao esta num veiculo.', 'error') end

    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
end

function actions.clean()
    local vehicle = currentVehicle()

    if not vehicle then return notify('Voce nao esta num veiculo.', 'error') end

    SetVehicleDirtLevel(vehicle, 0.0)
    WashDecalsFromVehicle(vehicle, 1.0)
end

function actions.deleteVehicle()
    local vehicle = currentVehicle()

    if not vehicle then return notify('Voce nao esta num veiculo.', 'error') end

    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)

    notify('Veiculo removido.', 'success')
end

function actions.spawnVehicle(data)
    if type(data.model) == 'string' then spawnVehicle(data.model) end
end

function actions.handling()
    if OpenHandlingMenu then OpenHandlingMenu() end
end

function actions.coords()
    if AdminTools and AdminTools.startCoordsOverlay then AdminTools.startCoordsOverlay() end
end

function actions.propSelect()
    if AdminTools and AdminTools.startPropSelection then AdminTools.startPropSelection() end
end

--- Salva os campos do formulario e inicia o editor em mundo.
---
--- Os dois passos vem juntos de proposito: "configurar" sem "iniciar" nao
--- produz nada visivel, e separar em dois cliques so criaria a chance de
--- editar com a configuracao antiga.
function actions.propAlign(data)
    if not AdminTools or not AdminTools.startPropAlign then return end

    if AdminTools.setPropConfig then AdminTools.setPropConfig(data) end

    -- O editor toma a tela: com o painel aberto por cima, o admin nao veria o
    -- prop que esta ajustando.
    closePanel()

    AdminTools.startPropAlign()
end

--- Equipa um alinhamento ja salvo, para conferir como ficou.
function actions.holdProp(data)
    if type(data.model) ~= 'string' or type(data.anim) ~= 'string' then return end

    closePanel()
    ExecuteCommand(('holditem %s %s'):format(data.model, data.anim))
end

function actions.orgs()
    if AdminTools and AdminTools.openOrgs then AdminTools.openOrgs() end
end

function actions.stopAnim() ExecuteCommand('stopitem') end
function actions.refreshSkin() ExecuteCommand('refreshskin') end

function actions.eventGas() TriggerServerEvent('nv_adminmenu:server:startGasEvent') end
function actions.eventShops() TriggerServerEvent('nv_adminmenu:server:startShop247Event') end

-- ------------------------------------------------------- callbacks NUI ----

RegisterNUICallback('panel_close', function(_, cb)
    closePanel()
    cb(1)
end)

RegisterNUICallback('panel_action', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.action) ~= 'string' then return end

    local handler = actions[data.action]

    if handler then handler(data) end
end)

RegisterNUICallback('panel_give', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    TriggerServerEvent('nv_adminmenu:panel:giveItem', data.target, data.item, data.count)
end)

RegisterNUICallback('panel_player', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    TriggerServerEvent('nv_adminmenu:panel:playerAction', data.action, data.target)
end)

RegisterNUICallback('panel_vehicle', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    -- O evento que ja existe, e nao um repasse novo: ele resolve garagem mais
    -- proxima, log e aviso ao dono.
    TriggerServerEvent('nv_adminmenu:server:giveVehicle', data.target, data.model)
end)

RegisterNUICallback('panel_world', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    TriggerServerEvent('nv_adminmenu:panel:world', data.kind, data.value)
end)

-- ------------------------------------------- eventos vindos do servidor ---

RegisterNetEvent('nv_adminmenu:panel:client:heal', function()
    healSelf()
    notify('Voce foi curado por um administrador.', 'success')
end)

RegisterNetEvent('nv_adminmenu:panel:client:armour', function()
    SetPedArmour(cache.ped, 100)
    notify('Voce recebeu um colete.', 'success')
end)

RegisterNetEvent('nv_adminmenu:panel:client:kill', function()
    SetEntityHealth(cache.ped, 0)
end)

RegisterNetEvent('nv_adminmenu:panel:client:weather', function(weather)
    if type(weather) ~= 'string' then return end

    SetWeatherTypeOverTime(weather, 8.0)

    -- O override precisa de um instante para assentar; limpar antes disso faz
    -- o clima voltar ao que era.
    SetTimeout(9000, function()
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypePersist(weather)
        SetWeatherTypeNow(weather)
        SetWeatherTypeNowPersist(weather)
    end)
end)

RegisterNetEvent('nv_adminmenu:panel:client:time', function(hour)
    hour = tonumber(hour)

    if not hour then return end

    NetworkOverrideClockTime(math.floor(hour), 0, 0)
end)

-- ------------------------------------------------------------ keybind -----

lib.addKeybind({
    name = 'nv_adminmenu_panel',
    description = 'Abrir o painel de administracao',
    defaultKey = Config.PanelKey,
    onPressed = function()
        -- A mesma tecla fecha: procurar o X depois de abrir por atalho e um
        -- passo a mais no gesto mais repetido.
        if open then return closePanel() end

        openPanel()
    end
})

lib.addCommand('painel', {
    help = 'Abrir o painel de administracao'
}, openPanel)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and open then
        SetNuiFocus(false, false)
    end
end)
