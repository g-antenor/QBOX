--[[
    nv_hunting — cliente da CAÇA

    A pesca do mesmo resource vive em client/fishing.lua e não conversa com
    este arquivo.
]]

-- Quantos cortes cada carcaça ainda aguenta é decisão do SERVIDOR. Aqui não há
-- contador: o cliente só pergunta e obedece a resposta.

--- Animal configurado para a entidade, ou nil.
---
--- GetEntityModel estoura no engine quando o handle já não é mais um ped válido
--- (carcaça limpa pelo jogo entre o hover do target e a chamada). DoesEntityExist
--- sozinho não cobre isso, então checamos o tipo antes e ainda protegemos com
--- pcall.
---@param entity number
---@return table?
local function animalFor(entity)
    if type(entity) ~= 'number' or entity <= 0 then return end
    if not DoesEntityExist(entity) or not IsEntityAPed(entity) then return end

    local ok, model = pcall(GetEntityModel, entity)
    if not ok or not model or model == 0 then return end

    return Config.Hunting.Animals[model]
end

--- Isto é uma carcaça de animal configurado?
---
--- É o ÚNICO teste que decide se a opção aparece no target. Tudo que é
--- "requisito do jogador" (faca na mão, causa da morte) saiu daqui de
--- propósito: escondendo a opção, o jogo não tem como dizer o que falta, e o
--- sintoma é idêntico ao de um resource quebrado.
---@param entity number
---@return boolean
local function isCarcass(entity)
    if not animalFor(entity) then return false end

    return IsEntityDead(entity)
end

--- O jogador consegue esfolar esta carcaça agora?
---@param entity number
---@return boolean, string?
local function skinRequirements(entity)
    if GetSelectedPedWeapon(cache.ped) ~= Config.Hunting.Knife then
        return false, 'Você precisa estar com a faca na mão.'
    end

    if Config.Hunting.CheckKillWeapon then
        -- GetPedCauseOfDeath devolve o hash do que matou.
        local cause = GetPedCauseOfDeath(entity)
        local rejected = cause ~= 0 and Config.Hunting.RejectedCauses[cause]

        if rejected then
            return false, ('O animal foi %s: não sobrou couro aproveitável.'):format(rejected)
        end
    end

    return true
end

--- Um corte: minigame, animação e pedido de recompensa ao servidor.
---@param entity number
local function skin(entity)
    if not isCarcass(entity) then return end

    local allowed, reason = skinRequirements(entity)

    if not allowed then
        return lib.notify({ type = 'error', description = reason })
    end

    local animal = animalFor(entity)
    if not animal then return end

    if not exports.nv_minigames:Start(Config.Hunting.Minigame) then
        return lib.notify({ type = 'error', description = 'Você estragou o corte.' })
    end

    -- Reconfere: o minigame leva tempo e a carcaça pode ter sumido.
    if not DoesEntityExist(entity) then return end

    local ok = lib.progressBar({
        label = ('Esfolando %s...'):format(animal.label),
        duration = Config.Hunting.CutDuration,
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base' },
    })

    if not ok or not DoesEntityExist(entity) then return end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local result = lib.callback.await('nv_hunting:server:skin', false, netId)

    -- Servidor recusou (carcaça esgotada, longe demais, cedo demais).
    if not result then return end

    if result.finished then
        lib.notify({ type = 'inform', description = 'Não sobrou mais nada aproveitável.' })

        if DoesEntityExist(entity) then
            if NetworkGetEntityIsNetworked(entity) then
                NetworkRequestControlOfEntity(entity)
            end

            DeleteEntity(entity)
        end
    end
end

-- ------------------------------------------------------------- registro ---

CreateThread(function()
    local models = {}

    for model in pairs(Config.Hunting.Animals) do
        models[#models + 1] = model
    end

    -- `fa-knife` só existe no Font Awesome Pro; o ox_target usa o Free, então
    -- o ícone saía em branco. `fa-utensils` existe no Free.
    exports.ox_target:addModel(models, {
        {
            name = 'nv_hunting:skin',
            icon = 'fa-solid fa-utensils',
            label = 'Esfolar',
            distance = Config.Hunting.TargetDistance,
            canInteract = function(entity)
                return isCarcass(entity)
            end,
            onSelect = function(data)
                skin(data.entity)
            end,
        },
    })
end)

-- ---------------------------------------------------------- diagnóstico ---

--- Diz, para o animal que você está mirando, qual portão está reprovando.
--- Existe porque "não aparece nada" é um sintoma sem informação nenhuma: este
--- comando transforma isso em uma resposta.
RegisterCommand('huntdebug', function()
    local hit, entity = lib.raycast.fromCamera(511, 4, 20)

    if not hit or not entity or entity == 0 then
        return lib.notify({ type = 'error', description = 'Mire em um animal e use o comando de novo.' })
    end

    local model = DoesEntityExist(entity) and GetEntityModel(entity) or 0
    local animal = Config.Hunting.Animals[model]
    local cause = IsEntityAPed(entity) and GetPedCauseOfDeath(entity) or 0
    local weapon = GetSelectedPedWeapon(cache.ped)

    print(('[nv_hunting] entidade   : %s (ped: %s)'):format(entity, tostring(IsEntityAPed(entity))))
    print(('[nv_hunting] modelo     : %s -> %s'):format(model, animal and animal.label or 'NAO CONFIGURADO em Config.Hunting.Animals'))
    print(('[nv_hunting] morto      : %s'):format(tostring(IsEntityDead(entity))))
    print(('[nv_hunting] causa      : %s -> %s'):format(cause, Config.Hunting.RejectedCauses[cause] or 'aceita'))
    print(('[nv_hunting] sua arma   : %s (faca = %s)'):format(weapon, Config.Hunting.Knife))
    print(('[nv_hunting] alvo exibe : %s'):format(tostring(isCarcass(entity))))

    local allowed, reason = skinRequirements(entity)
    print(('[nv_hunting] pode cortar: %s%s'):format(tostring(allowed), reason and (' - ' .. reason) or ''))

    lib.notify({ description = 'Diagnóstico no console (F8).' })
end, false)
