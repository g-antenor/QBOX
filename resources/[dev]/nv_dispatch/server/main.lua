--[[
    nv_dispatch — servidor

    Um alerta so existe se o SERVIDOR mandar. O cliente que comete o crime
    apenas conta o que fez e onde estava; quem decide se aquilo vira alerta,
    e para quem vai e este arquivo.

    Isso importa porque o cliente do ladrao e exatamente a maquina que tem
    interesse em suprimir o alerta. Se a supressao morasse la, bastaria nao
    enviar.
]]

local Ox = require '@ox_core.lib.init'

Dispatch = {}

-- Destinatarios congelados no momento do alerta. Atualizar um blip dez vezes
-- por segundo nao pode refazer a consulta de corporacoes dez vezes por segundo.
local vehicleAlerts = {}

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

        if player.charId and allowed[player.charId] and Player(player.source).state.duty == true then
            result[#result + 1] = player.source
        end
    end

    return result
end

-- ----------------------------------------------------------------- enviar --

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
        id       = type(data.id) == 'string' and data.id:match('^[%w_%-]+$') and data.id:sub(1, 64)
                   or ('%s_%d'):format(category, math.random(100000, 999999)),
        category = category,
        label    = settings.label,
        code     = settings.code,
        icon     = settings.icon,
        priority = settings.priority,
        detail   = type(data.detail) == 'string' and data.detail:sub(1, 90) or nil,
        plate    = type(data.plate) == 'string' and data.plate:sub(1, 12) or nil,
        street   = type(data.street) == 'string' and data.street:sub(1, 60) or nil,
        coords   = { x = coords.x, y = coords.y, z = coords.z },
        blip     = {
            sprite = settings.blipSprite,
            color  = settings.blipColor,
            radius = Config.Blip.radius,
            alpha  = Config.Blip.alpha,
            time   = math.min(tonumber(data.duration) or Config.Blip.duration, Config.Blip.duration),
            flash  = data.flash == true,
            area   = data.area ~= false
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

        if category == 'roubo_veiculo' or category == 'perda_sinal' then
            pcall(function()
                exports.nv_mdt:AddAutomaticReport({
                    type = category == 'roubo_veiculo' and 'furto' or 'outro',
                    citizen = payload.plate and ('Veiculo ' .. payload.plate) or 'Veiculo nao identificado',
                    notes = ('%s. Local: %s. Coordenadas: %.0f, %.0f.')
                        :format(payload.detail or settings.label, payload.street or 'nao informado', coords.x, coords.y),
                    author = 'Sistema de dispatch'
                })
            end)
        end
    end

    return true
end

--- Envia um alerta associado ao jogador informado pelo resource chamador.
---@param source number    quem cometeu
---@param category string
---@param coords vector3
---@param data table?
---@return boolean
function Dispatch.alert(source, category, coords, data)
    if not Config.Enabled then return false end
    return Dispatch.send(category, coords, data)
end

exports('Alert', function(source, category, coords, data)
    return Dispatch.alert(source, category, coords, data)
end)

--- Alerta sem autor: eventos do mundo que nao partem de um jogador.
exports('Send', function(category, coords, data)
    return Dispatch.send(category, coords, data)
end)

-- ------------------------------------------------- entradas de outros --
--                                                    resources          --

--- nv_garage: `Config.Lockpick.alertEvent` e `Config.Hotwire.alertEvent`.
---
--- A assinatura e `(coords)` porque e o que o nv_garage ja enviava quando estes
--- ganchos foram criados; mudar la seria mexer em codigo que funciona para
--- ganhar um parametro que este arquivo consegue deduzir.
local function vehicleTheft(source, coords, data)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    data = type(data) == 'table' and data or {}
    local reason = type(data.reason) == 'string' and data.reason:sub(1, 60) or 'Tentativa de furto de veiculo'
    local plate = type(data.plate) == 'string' and data.plate:sub(1, 12) or nil

    local sent = Dispatch.alert(source, 'roubo_veiculo', vec3(x, y, z), {
        id = data.id,
        netId = data.netId,
        detail = plate and ('%s - placa %s'):format(reason, plate) or reason,
        plate = plate,
        duration = math.min(tonumber(data.duration) or 60, 60),
        flash = true,
        area = false
    })

    if sent and type(data.id) == 'string' and data.id:match(('^vehicle_%d_'):format(source)) then
        local alertId = data.id:sub(1, 64)
        vehicleAlerts[alertId] = {
            source = source,
            targets = receivers(),
            expires = os.time() + math.min(tonumber(data.duration) or 60, 60)
        }

        SetTimeout(61000, function()
            vehicleAlerts[alertId] = nil
        end)
    end
end

exports('VehicleTheft', vehicleTheft)
RegisterNetEvent('nv_dispatch:carTheft', function(coords, data) vehicleTheft(source, coords, data) end)

local function stopVehicleTheft(source, alertId)
    if type(alertId) ~= 'string' or not alertId:match('^[%w_%-]+$') then return end
    if not alertId:match(('^vehicle_%d_'):format(source)) then return end

    local active = vehicleAlerts[alertId]
    local targets = active and active.source == source and active.targets or receivers()
    for i = 1, #targets do
        TriggerClientEvent('nv_dispatch:stopAlert', targets[i], alertId:sub(1, 64))
    end
    vehicleAlerts[alertId] = nil
end

exports('StopVehicleTheft', stopVehicleTheft)
RegisterNetEvent('nv_dispatch:carTheftStopped', function(alertId) stopVehicleTheft(source, alertId) end)

local function moveVehicleTheft(source, alertId, coords)
    if type(alertId) ~= 'string' or not alertId:match(('^vehicle_%d_'):format(source)) then return end
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end

    local active = vehicleAlerts[alertId]
    if not active or active.source ~= source or os.time() > active.expires then return end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    local ped = GetPlayerPed(source)
    local actual = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    if not actual or #(actual - vec3(x, y, z)) > 35.0 then return end

    local targets = active.targets
    for i = 1, #targets do
        TriggerClientEvent('nv_dispatch:updateAlert', targets[i], alertId:sub(1, 64), {
            x = x, y = y, z = z
        })
    end
end

exports('MoveVehicleTheft', moveVehicleTheft)
RegisterNetEvent('nv_dispatch:carTheftMoved', function(alertId, coords) moveVehicleTheft(source, alertId, coords) end)

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
