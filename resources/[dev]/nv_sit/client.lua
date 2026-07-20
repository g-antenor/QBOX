--[[
    nv_sit — sentar em bancos e cadeiras pelo ox_target.

    O ponto do assento vem das dimensoes reais do modelo, nao de um offset
    fixo, entao bancos de qualquer tamanho/origem sao tratados corretamente.
]]

local seated = false

-- Ajuste global vivo, alimentado por /sitdebug (some ao reiniciar o resource).
local debugTune = vec3(0.0, 0.0, 0.0)
local debugHeading = 0.0

--- Converte um ponto do mundo para o eixo lateral do prop.
--- So precisa do heading, entao evita depender da ordem de GetEntityMatrix.
---@param entity number
---@param world vector3
---@return number
local function lateralOffset(entity, world)
    local delta = world - GetEntityCoords(entity)
    local heading = math.rad(GetEntityHeading(entity))

    -- Vetor "direita" do prop no plano horizontal.
    return delta.x * math.cos(heading) + delta.y * math.sin(heading)
end

--- Calcula onde o ped deve ficar para sentar neste prop.
---@param entity number
---@param group table
---@param aimCoords vector3|nil ponto mirado no target (define o lugar no banco)
---@return vector3, number
local function getSeat(entity, group, aimCoords)
    local min, max = GetModelDimensions(GetEntityModel(entity))

    -- Centro do prop nos eixos lateral e de profundidade.
    local centerX = (min.x + max.x) * 0.5
    local centerY = (min.y + max.y) * 0.5

    -- Altura do assento medida a partir da BASE real do modelo, e nao da
    -- origem do prop. Props com origem no centro tem min.z negativo, entao
    -- ancorar em min.z jogava o ped para baixo do banco.
    local seatZ = min.z + (max.z - min.z) * Config.SeatHeightRatio

    local seatX = centerX

    if aimCoords then
        -- Senta onde mirou, sem deixar escorregar para fora das pontas.
        local limit = math.max(0.0, (max.x - min.x) * 0.5 - Config.SeatMargin)
        local aimed = lateralOffset(entity, aimCoords)

        seatX = centerX + math.max(-limit, math.min(limit, aimed - centerX))
    end

    local tune = group.tune or vec3(0.0, 0.0, 0.0)

    local coords = GetOffsetFromEntityInWorldCoords(
        entity,
        seatX + tune.x + debugTune.x,
        centerY + tune.y + debugTune.y,
        seatZ + tune.z + debugTune.z
    )

    local heading = (GetEntityHeading(entity) + group.heading + debugHeading) % 360.0

    return coords, heading
end

--- Ja existe alguem sentado nesse ponto?
---@param coords vector3
---@return boolean
local function isSeatTaken(coords)
    local self = cache.ped

    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= self and not IsPedDeadOrDying(ped, true) then
            if #(GetEntityCoords(ped) - coords) < Config.OccupiedRadius then
                return true
            end
        end
    end

    return false
end

--- O jogador pode sentar agora?
---@return boolean
local function canSit()
    local ped = cache.ped

    return not seated
        and not cache.vehicle
        and not IsPedDeadOrDying(ped, true)
        and not IsPedCuffed(ped)
        and not IsPedRagdoll(ped)
end

--- Levanta o jogador e devolve o controle.
local function standUp()
    if not seated then return end
    seated = false

    lib.hideTextUI()
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
end

--- Senta o jogador no prop e segura ate ele apertar a tecla de levantar.
---@param entity number
---@param group table
---@param aimCoords vector3|nil
local function sit(entity, group, aimCoords)
    if not canSit() then return end
    if not DoesEntityExist(entity) then return end

    local coords, heading = getSeat(entity, group, aimCoords)

    if isSeatTaken(coords) then
        return lib.notify({ type = 'error', description = 'Esse lugar já está ocupado.' })
    end

    seated = true

    TaskStartScenarioAtPosition(
        cache.ped, group.scenario,
        coords.x, coords.y, coords.z,
        heading,
        0,      -- duracao (0 = indefinido)
        true,   -- teleporta o ped para a posicao
        true    -- usa a posicao/heading informados
    )

    lib.showTextUI('[E] Levantar')

    CreateThread(function()
        -- Espera o cenario assumir antes de comecar a vigiar.
        Wait(500)

        while seated do
            -- Perdeu a pose (empurrao, dano, tiro): levanta sozinho.
            if not IsPedUsingAnyScenario(cache.ped) or IsPedDeadOrDying(cache.ped, true) then
                standUp()
                break
            end

            if IsControlJustReleased(0, Config.StandKey) then
                standUp()
                break
            end

            Wait(0)
        end
    end)
end

-- ------------------------------------------------------------ registro ----

CreateThread(function()
    for _, group in ipairs(Config.Groups) do
        exports.ox_target:addModel(group.models, {
            {
                name = 'nv_sit:sit',
                icon = group.icon,
                label = group.label,
                distance = Config.TargetDistance,
                canInteract = function(entity, _, coords)
                    if not canSit() then return false end

                    local seat = getSeat(entity, group, coords)
                    return not isSeatTaken(seat)
                end,
                onSelect = function(data)
                    -- data.coords e o ponto mirado: define o lugar no banco.
                    sit(data.entity, group, data.coords)
                end,
            },
        })
    end
end)

-- ------------------------------------------------------------------ debug --

--- /sitdebug [x] [y] [z] [heading]
--- Ajusta o assento em jogo e imprime o valor pronto para o config.
--- Sem argumentos, zera e mostra os valores atuais.
RegisterCommand('sitdebug', function(_, args)
    if #args == 0 then
        debugTune, debugHeading = vec3(0.0, 0.0, 0.0), 0.0
    else
        debugTune = vec3(
            tonumber(args[1]) or 0.0,
            tonumber(args[2]) or 0.0,
            tonumber(args[3]) or 0.0
        )
        debugHeading = tonumber(args[4]) or 0.0
    end

    print(('[nv_sit] tune = vec3(%.2f, %.2f, %.2f)  |  heading += %.1f')
        :format(debugTune.x, debugTune.y, debugTune.z, debugHeading))
    print('[nv_sit] se ficou bom, copie esse tune para o grupo em config.lua')
end, false)

-- ------------------------------------------------------------- ciclo de vida

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- Nunca deixar o jogador preso no cenario se o resource cair.
    standUp()
end)
