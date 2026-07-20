--[[
    nv_adminmenu — editor de handling de veículos.

    Fluxo: seleciona o veículo (busca), ajusta os campos por categoria vendo o
    valor atual, e usa o botão Ajuda para saber o que cada ponto faz.

    ATENÇÃO: SetVehicleHandling* altera o veículo apenas NO SEU CLIENTE. Serve
    para testar/afinar valores; para valer no servidor inteiro, exporte o XML
    (opção "Copiar handling.meta") e coloque no handling.meta do veículo.
]]

local SEARCH_RADIUS = 60.0

-- Veículo em edição e os valores originais, para poder restaurar.
local vehicle = nil
local original = {}

--[[
    kind:
      'float'  -> GetVehicleHandlingFloat  / SetVehicleHandlingFloat
      'int'    -> GetVehicleHandlingInt    / SetVehicleHandlingInt
      'vector' -> GetVehicleHandlingVector / SetVehicleHandlingVector
]]
local CATEGORIES = {
    {
        name = 'Massa e Inércia',
        icon = 'fa-solid fa-weight-hanging',
        fields = {
            { key = 'fMass', kind = 'float', label = 'Massa (kg)',
              help = 'Peso do veículo. Afeta inércia, transferência de peso e como ele se comporta em colisões. Carro pesado freia e vira pior, mas empurra mais.' },
            { key = 'fInitialDragCoeff', kind = 'float', label = 'Coef. de Arrasto',
              help = 'Resistência do ar. Maior = perde velocidade mais rápido em alta e a velocidade final cai.' },
            { key = 'fPercentSubmerged', kind = 'float', label = '% Submerso',
              help = 'Quanto do veículo precisa submergir para afundar. Padrão 85. Menor = boia mais.' },
            { key = 'vecCentreOfMassOffset', kind = 'vector', label = 'Centro de Massa',
              help = 'Desloca o centro de massa (X lateral, Y frente/trás, Z altura). Baixar o Z é o ajuste clássico contra capotamento.' },
            { key = 'vecInertiaMultiplier', kind = 'vector', label = 'Multiplicador de Inércia',
              help = 'Resistência a girar em cada eixo. Valores menores deixam o carro mais ágil para mudar de direção; maiores, mais preguiçoso.' },
        }
    },
    {
        name = 'Motor e Transmissão',
        icon = 'fa-solid fa-gears',
        fields = {
            { key = 'fInitialDriveForce', kind = 'float', label = 'Força do Motor',
              help = 'O principal valor de aceleração. Aumentar deixa o carro mais forte em todas as marchas.' },
            { key = 'fInitialDriveMaxFlatVel', kind = 'float', label = 'Velocidade Máxima',
              help = 'Velocidade teórica de topo. Trabalha junto com o número de marchas e o arrasto.' },
            { key = 'nInitialDriveGears', kind = 'int', label = 'Número de Marchas',
              help = 'Quantidade de marchas. Mais marchas = escalonamento melhor, aceleração mais contínua.' },
            { key = 'fDriveInertia', kind = 'float', label = 'Inércia do Motor',
              help = 'Rapidez com que o motor ganha giro. Menor = RPM sobe devagar (sensação de motor pesado).' },
            { key = 'fDriveBiasFront', kind = 'float', label = 'Distribuição de Tração',
              help = '0.0 = tração traseira, 1.0 = dianteira, 0.5 = 4x4. Define o caráter do carro na saída de curva.' },
            { key = 'fClutchChangeRateScaleUpShift', kind = 'float', label = 'Troca (subindo)',
              help = 'Velocidade das trocas de marcha para cima. Maior = trocas mais rápidas.' },
            { key = 'fClutchChangeRateScaleDownShift', kind = 'float', label = 'Troca (descendo)',
              help = 'Velocidade das reduções. Maior = reduz mais rápido ao frear.' },
        }
    },
    {
        name = 'Freios',
        icon = 'fa-solid fa-hand',
        fields = {
            { key = 'fBrakeForce', kind = 'float', label = 'Força do Freio',
              help = 'Potência total de frenagem. Alto demais trava as rodas com facilidade.' },
            { key = 'fBrakeBiasFront', kind = 'float', label = 'Distribuição do Freio',
              help = 'Divisão frente/trás. Acima de 0.5 freia mais na frente (estável); abaixo, tende a rodar a traseira.' },
            { key = 'fHandBrakeForce', kind = 'float', label = 'Freio de Mão',
              help = 'Força do freio de mão. Aumentar facilita iniciar derrapagens.' },
        }
    },
    {
        name = 'Direção e Tração',
        icon = 'fa-solid fa-steering-wheel',
        fields = {
            { key = 'fSteeringLock', kind = 'float', label = 'Ângulo de Esterço',
              help = 'Ângulo máximo das rodas, em graus. Maior = vira mais fechado, mas fica nervoso em alta.' },
            { key = 'fTractionCurveMax', kind = 'float', label = 'Aderência Máxima',
              help = 'Grip em baixa e média velocidade. É o que segura o carro na curva.' },
            { key = 'fTractionCurveMin', kind = 'float', label = 'Aderência Mínima',
              help = 'Grip em alta velocidade. Se ficar muito abaixo da máxima, o carro solta o traseiro em velocidade.' },
            { key = 'fTractionCurveLateral', kind = 'float', label = 'Curva Lateral',
              help = 'Ângulo em que o pneu atinge o pico de aderência lateral. Afeta a progressividade da perda de grip.' },
            { key = 'fTractionBiasFront', kind = 'float', label = 'Distribuição de Aderência',
              help = 'Divisão do grip frente/trás. Aumentar reduz subesterço (o carro "entra" mais na curva).' },
            { key = 'fLowSpeedTractionLossMult', kind = 'float', label = 'Perda em Baixa',
              help = 'Patinação na largada. Maior = mais borracha queimada ao arrancar.' },
            { key = 'fTractionLossMult', kind = 'float', label = 'Perda por Superfície',
              help = 'Sensibilidade a piso ruim (terra, grama, molhado). Maior = perde mais grip fora do asfalto.' },
            { key = 'fTractionSpringDeltaMax', kind = 'float', label = 'Curso com Tração',
              help = 'Distância máxima que a roda pode estar do solo ainda tendo tração.' },
            { key = 'fCamberStiffnesss', kind = 'float', label = 'Rigidez de Cambagem',
              help = 'Efeito da cambagem no grip. Normalmente fica em 0.' },
        }
    },
    {
        name = 'Suspensão',
        icon = 'fa-solid fa-car-burst',
        fields = {
            { key = 'fSuspensionForce', kind = 'float', label = 'Força da Mola',
              help = 'Rigidez da suspensão. Maior = mais firme, menos rolagem, mais salto em piso irregular.' },
            { key = 'fSuspensionCompDamp', kind = 'float', label = 'Amortecimento (compressão)',
              help = 'Resistência ao comprimir. Controla o mergulho ao frear e ao pegar lombada.' },
            { key = 'fSuspensionReboundDamp', kind = 'float', label = 'Amortecimento (retorno)',
              help = 'Resistência ao voltar. Baixo demais deixa o carro saltitante.' },
            { key = 'fSuspensionUpperLimit', kind = 'float', label = 'Limite Superior',
              help = 'Curso máximo para cima da roda.' },
            { key = 'fSuspensionLowerLimit', kind = 'float', label = 'Limite Inferior',
              help = 'Curso máximo para baixo da roda.' },
            { key = 'fSuspensionRaise', kind = 'float', label = 'Altura da Carroceria',
              help = 'Sobe ou baixa o corpo do carro. Negativo = rebaixado.' },
            { key = 'fSuspensionBiasFront', kind = 'float', label = 'Distribuição da Suspensão',
              help = 'Divisão da rigidez entre frente e trás.' },
            { key = 'fAntiRollBarForce', kind = 'float', label = 'Barra Estabilizadora',
              help = 'Combate a rolagem lateral. Maior = carro mais plano nas curvas.' },
            { key = 'fAntiRollBarBiasFront', kind = 'float', label = 'Distribuição da Barra',
              help = 'Divisão da barra estabilizadora entre os eixos.' },
            { key = 'fRollCentreHeightFront', kind = 'float', label = 'Centro de Rolagem (frente)',
              help = 'Altura do eixo em torno do qual a frente rola. Mais alto = menos rolagem na dianteira.' },
            { key = 'fRollCentreHeightRear', kind = 'float', label = 'Centro de Rolagem (traseira)',
              help = 'Mesma coisa para a traseira.' },
        }
    },
    {
        name = 'Dano e Diversos',
        icon = 'fa-solid fa-screwdriver-wrench',
        fields = {
            { key = 'fCollisionDamageMult', kind = 'float', label = 'Dano por Colisão',
              help = 'Multiplicador de dano em batidas. 0 deixa o carro praticamente indestrutível.' },
            { key = 'fWeaponDamageMult', kind = 'float', label = 'Dano por Armas',
              help = 'Multiplicador de dano de tiros.' },
            { key = 'fDeformationDamageMult', kind = 'float', label = 'Deformação',
              help = 'Quanto a lataria amassa visualmente.' },
            { key = 'fEngineDamageMult', kind = 'float', label = 'Dano ao Motor',
              help = 'Quão rápido o motor morre ao levar dano.' },
            { key = 'fPetrolTankVolume', kind = 'float', label = 'Tanque de Combustível',
              help = 'Volume do tanque. Também influencia o quanto vaza/explode ao ser baleado.' },
            { key = 'fOilVolume', kind = 'float', label = 'Volume de Óleo',
              help = 'Volume de óleo do motor.' },
            { key = 'nMonetaryValue', kind = 'int', label = 'Valor Monetário',
              help = 'Preço de referência do veículo. Usado por alguns scripts de economia.' },
        }
    },
}

-- ------------------------------------------------------------- helpers ----

local function getValue(field)
    if field.kind == 'int' then
        return GetVehicleHandlingInt(vehicle, 'CHandlingData', field.key)
    elseif field.kind == 'vector' then
        return GetVehicleHandlingVector(vehicle, 'CHandlingData', field.key)
    end

    return GetVehicleHandlingFloat(vehicle, 'CHandlingData', field.key)
end

local function setValue(field, value)
    -- Guarda o original na primeira alteração de cada campo.
    if original[field.key] == nil then
        original[field.key] = getValue(field)
    end

    if field.kind == 'int' then
        SetVehicleHandlingInt(vehicle, 'CHandlingData', field.key, math.floor(value + 0.5))
    elseif field.kind == 'vector' then
        SetVehicleHandlingVector(vehicle, 'CHandlingData', field.key, value)
    else
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', field.key, value + 0.0)
    end
end

local function formatValue(field)
    local value = getValue(field)

    if field.kind == 'vector' then
        return ('%.3f, %.3f, %.3f'):format(value.x, value.y, value.z)
    elseif field.kind == 'int' then
        return tostring(value)
    end

    return ('%.3f'):format(value)
end

local function vehicleLabel(veh)
    local model = GetEntityModel(veh)
    local name = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(name)

    if label == 'NULL' or label == '' then label = name end

    local plate = GetVehicleNumberPlateText(veh)
    -- Parênteses: gsub devolve dois valores e o segundo poluiria o format.
    return ('%s [%s]'):format(label, plate and (plate:gsub('%s+$', '')) or '?')
end

local function vehicleValid()
    if vehicle and DoesEntityExist(vehicle) then return true end

    vehicle = nil
    lib.notify({ type = 'error', description = 'Nenhum veículo selecionado (ou ele deixou de existir).' })
    return false
end

-- --------------------------------------------------------- indice de campos

-- Lookup key -> field, para traduzir o que volta da NUI.
local FIELD_BY_KEY = {}

for _, category in ipairs(CATEGORIES) do
    for _, field in ipairs(category.fields) do
        FIELD_BY_KEY[field.key] = field
    end
end

-- ---------------------------------------------------------------- tablet --

local tabletOpen = false
local testing = false

local openTablet

--- Monta o payload da NUI: categorias (sem os icones do ox_lib) e valores.
local function buildPayload()
    local categories, values = {}, {}

    for i, category in ipairs(CATEGORIES) do
        local fields = {}

        for j, field in ipairs(category.fields) do
            fields[j] = {
                key = field.key,
                label = field.label,
                kind = field.kind,
                help = field.help,
            }

            local value = getValue(field)

            if field.kind == 'vector' then
                values[field.key] = { x = value.x, y = value.y, z = value.z }
            else
                values[field.key] = value
            end
        end

        categories[i] = { name = category.name, fields = fields }
    end

    return categories, values
end

--- Aplica no veiculo o que veio da NUI.
---@return integer quantidade de campos aplicados
local function applyValues(values)
    if type(values) ~= 'table' then return 0 end

    local count = 0

    for key, value in pairs(values) do
        local field = FIELD_BY_KEY[key]

        if field then
            if field.kind == 'vector' and type(value) == 'table' then
                setValue(field, vec3(value.x or 0.0, value.y or 0.0, value.z or 0.0))
                count = count + 1
            elseif type(value) == 'number' then
                setValue(field, value)
                count = count + 1
            end
        end
    end

    return count
end

local function closeTablet()
    if not tabletOpen then return end

    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

--- Esconde o tablet e deixa o admin dirigir, avisando como voltar.
local function enterTestMode()
    closeTablet()
    testing = true

    lib.showTextUI(
        'Testando handling  \n`F7`  Voltar ao editor  ·  `/handling`  ·  `/handlingreset`',
        { position = 'bottom-center', icon = 'car-side' }
    )
end

function openTablet()
    if not vehicleValid() then return end

    if testing then
        testing = false
        lib.hideTextUI()
    end

    local categories, values = buildPayload()

    tabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        vehicle = vehicleLabel(vehicle),
        categories = categories,
        values = values,
    })
end

-- --------------------------------------------------------------- acoes ----

--- Gera o bloco do handling.meta com os valores atuais.
local function buildMeta()
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
    local lines = { '<Item type="CHandlingData">', ('  <handlingName>%s</handlingName>'):format(model) }

    for _, category in ipairs(CATEGORIES) do
        for _, field in ipairs(category.fields) do
            local value = getValue(field)

            if field.kind == 'vector' then
                lines[#lines + 1] = ('  <%s x="%.5f" y="%.5f" z="%.5f" />'):format(field.key, value.x, value.y, value.z)
            elseif field.kind == 'int' then
                lines[#lines + 1] = ('  <%s value="%d" />'):format(field.key, value)
            else
                lines[#lines + 1] = ('  <%s value="%.5f" />'):format(field.key, value)
            end
        end
    end

    lines[#lines + 1] = '</Item>'

    return table.concat(lines, '\n'), model
end

--- Devolve todos os campos alterados ao valor de origem.
local function restoreOriginal()
    if not vehicleValid() then return end

    local count = 0

    for key, value in pairs(original) do
        local field = FIELD_BY_KEY[key]

        if field then
            if field.kind == 'int' then
                SetVehicleHandlingInt(vehicle, 'CHandlingData', key, value)
            elseif field.kind == 'vector' then
                SetVehicleHandlingVector(vehicle, 'CHandlingData', key, value)
            else
                SetVehicleHandlingFloat(vehicle, 'CHandlingData', key, value)
            end

            count = count + 1
        end
    end

    original = {}

    lib.notify({
        type = count > 0 and 'success' or 'inform',
        description = count > 0 and ('%d valores restaurados.'):format(count) or 'Nada havia sido alterado.'
    })
end

-- ------------------------------------------------------- callbacks da NUI --

RegisterNUICallback('handling_test', function(data, cb)
    cb(1)

    applyValues(data and data.values)
    enterTestMode()
end)

RegisterNUICallback('handling_save', function(data, cb)
    cb(1)

    if not vehicleValid() then return closeTablet() end

    applyValues(data and data.values)

    local meta, model = buildMeta()

    lib.setClipboard(meta)
    TriggerServerEvent('nv_adminmenu:server:saveHandling', model, data and data.values)

    SendNUIMessage({
        action = 'status',
        text = ('Salvo em %s — handling.meta copiado.'):format(model),
        ok = true,
    })
end)

RegisterNUICallback('handling_close', function(_, cb)
    cb(1)
    closeTablet()
end)

-- --------------------------------------------------------------- entrada --

--- Busca por veiculos proximos e deixa escolher num select pesquisavel.
local function selectVehicle()
    local pedCoords = GetEntityCoords(cache.ped)
    local found = {}

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local distance = #(GetEntityCoords(veh) - pedCoords)

        if distance <= SEARCH_RADIUS then
            found[#found + 1] = { entity = veh, distance = distance }
        end
    end

    if #found == 0 then
        return lib.notify({ type = 'error', description = 'Nenhum veículo encontrado por perto.' })
    end

    table.sort(found, function(a, b) return a.distance < b.distance end)

    local options = {}
    local current = cache.vehicle

    for i = 1, #found do
        local veh = found[i].entity

        options[i] = {
            value = tostring(veh),
            label = ('%s — %.0fm%s'):format(
                vehicleLabel(veh),
                found[i].distance,
                veh == current and '  (você está nele)' or ''
            )
        }
    end

    local input = lib.inputDialog('Selecionar Veículo', {
        {
            type = 'select',
            label = 'Veículo',
            description = 'Digite para filtrar pelo nome ou placa',
            options = options,
            searchable = true,
            required = true,
            default = current and tostring(current) or options[1].value,
        }
    })

    if not input then return end

    local picked = tonumber(input[1])

    if not picked or not DoesEntityExist(picked) then
        return lib.notify({ type = 'error', description = 'Veículo inválido.' })
    end

    -- Troca de veiculo zera o historico de restauracao.
    vehicle = picked
    original = {}

    openTablet()
end

--- Ponto de entrada do menu de admin: escolhe o veiculo e abre o tablet.
local function openHandlingMenu()
    selectVehicle()
end

lib.addKeybind({
    name = 'nv_handling_reopen',
    description = 'Voltar ao editor de handling',
    defaultKey = 'F7',
    onPressed = function()
        -- So reage durante o teste, para nao roubar a tecla no jogo normal.
        if testing then openTablet() end
    end
})

RegisterCommand('handling', function()
    lib.callback('nv_adminmenu:server:isAdmin', false, function(allowed)
        if not allowed then return end

        -- Durante o teste, /handling volta direto para o mesmo veiculo.
        if testing then return openTablet() end

        openHandlingMenu()
    end)
end, false)

RegisterCommand('handlingreset', function()
    lib.callback('nv_adminmenu:server:isAdmin', false, function(allowed)
        if allowed then restoreOriginal() end
    end)
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Nunca deixar o jogador preso no foco da NUI se o resource cair.
    SetNuiFocus(false, false)
    lib.hideTextUI()
end)

exports('openHandlingMenu', openHandlingMenu)

-- Exposto no ambiente global do resource para o client.lua chamar a partir do
-- menu principal (handling.lua carrega depois, mas o onSelect so roda em runtime).
OpenHandlingMenu = openHandlingMenu
