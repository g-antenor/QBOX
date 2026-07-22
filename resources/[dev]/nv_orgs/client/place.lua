--[[
    nv_orgs — cliente: modo de posicionamento

    Fechadura nao da para cadastrar por formulario: o ox_doorlock precisa do
    HASH DO MODELO, das coordenadas e do heading exatos do batente. Nada disso
    e digitavel -- so olhando para a porta o jogo sabe responder. Por isso o
    painel fecha, o admin anda ate o lugar e confirma na mira.

    O bau tem o mesmo problema em menor grau: o ponto precisa ser onde a pessoa
    vai realmente ficar em pe, e isso se ve melhor no chao do que num campo de
    texto.
]]

local placing = false
local outlinedDoors = {}

---@param entity number
---@param enabled boolean
local function setDoorOutline(entity, enabled)
    if not entity or entity == 0 then return end

    if DoesEntityExist(entity) then
        SetEntityDrawOutline(entity, enabled)
    end

    if enabled then
        outlinedDoors[entity] = true
    else
        outlinedDoors[entity] = nil
    end
end

local function clearDoorOutlines()
    for entity in pairs(outlinedDoors) do
        if DoesEntityExist(entity) then
            SetEntityDrawOutline(entity, false)
        end
    end

    table.wipe(outlinedDoors)
end

--- Texto de ajuda no rodape, no mesmo estilo do editor de props do
--- nv_adminmenu.
---@param lines string
local function showHelp(lines)
    lib.showTextUI(lines, {
        position = 'bottom-center',
        style = {
            width = '480px',
            padding = '14px',
            borderRadius = '6px',
            backgroundColor = '#17161a',
            border = '1px solid #232025',
            color = '#e6e4e3',
            fontSize = '11px',
            boxShadow = '0 10px 25px rgba(0, 0, 0, 0.65)',
            marginBottom = '20px'
        }
    })
end

--- Desliga tudo que o modo ligou. Chamada por todos os caminhos de saida,
--- inclusive os de erro -- deixar o jogador preso sem TextUI e com controles
--- bloqueados e pior do que a falha original.
local function finish(set)
    placing = false
    lib.hideTextUI()
    clearDoorOutlines()

    if set then Panel.open(set) end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then clearDoorOutlines() end
end)

-- ------------------------------------------------- mira com previa --

---@param point vector3
---@param size number
local function drawZonePreview(point, size)
    local color = Config.Placement.marker.color
    local radius = math.min(0.12, math.max(0.08, size * 0.065))
    DrawSphere(point.x, point.y, point.z + radius, radius,
        color.r, color.g, color.b, 1.0)
end

--- Modo de mira: o ponto vai para onde o admin esta OLHANDO, e nao para onde
--- ele esta pisando.
---
--- E a diferenca entre conseguir e nao conseguir posicionar um bau em cima de
--- um balcao ou de uma prateleira -- andar ate la nao coloca o ponto na altura
--- certa, e as setas sozinhas viram tentativa e erro.
---
--- Devolve as coordenadas confirmadas, ou nil se cancelou.
---@param label string
---@param size number  lado da zona do target, em metros
---@return vector3?
local function aimForPoint(label, size)
    local height = 0.0
    local lastPoint, lastHelp

    while true do
        Wait(0)

        -- Flag 1 = mundo/mapa. Sem peds nem veiculos: mirar um pedestre que
        -- passou na frente moveria o ponto para cima dele.
        local hit, _, endCoords = lib.raycast.fromCamera(1, 4, Config.Placement.aimRange)

        if hit and endCoords then
            lastPoint = vec3(endCoords.x, endCoords.y, endCoords.z)
        end
        local point = lastPoint and vec3(lastPoint.x, lastPoint.y, lastPoint.z + height) or nil

        if point then
            drawZonePreview(point, size)
        end

        local help = (([[
**%s**
Mova a mira com o mouse para posicionar o ponto.

Altura: **%+.2f m**  (setas **PARA CIMA / PARA BAIXO**)
%s
**[BACKSPACE]** cancelar
]]):format(
            label,
            height,
            point and '**[ENTER]** confirmar' or '_Mire numa superficie._'
        ))
        if help ~= lastHelp then
            lastHelp = help
            showHelp(help)
        end

        if IsControlPressed(0, 172) then height = height + Config.Placement.nudgeStep end
        if IsControlPressed(0, 173) then height = height - Config.Placement.nudgeStep end

        if IsControlJustReleased(0, 194) then return end

        if IsControlJustReleased(0, 191) and point then
            return point
        end
    end
end

function Panel.placeCraftProject(set,options)
    if placing then return end;placing=true;options=options or {}
    CreateThread(function()
        local point=aimForPoint('Posicionando bancada de crafting',1.5)
        if not point then Panel.notify('Posicionamento cancelado.','inform');return finish(set) end
        local ok,err=lib.callback.await('nv_orgs:saveCraftProject',false,set,{label=options.label,prop=options.prop,
            x=point.x,y=point.y,z=point.z,heading=GetEntityHeading(cache.ped)})
        Panel.notify(ok and 'Bancada configurada.' or (err or 'Nao foi possivel salvar.'),ok and 'success' or 'error');finish(set)
    end)
end

--- Posiciona um ponto da concessionaria pela mira, com previa da area e da
--- direcao usada por spawns de veiculo.
function Panel.placeDealershipPoint(set, pointType, options)
    if placing then return end
    placing = true

    local label = pointType
    for i = 1, #(options or {}) do
        if options[i].value == pointType then label = options[i].label break end
    end

    CreateThread(function()
        local point = aimForPoint(('Concessionaria: %s'):format(label), 1.8)
        if not point then
            Panel.notify('Posicionamento cancelado.', 'inform')
            return finish(set)
        end

        local heading = GetGameplayCamRot(2).z
        local ok, err = lib.callback.await('nv_orgs:setDealershipPoint', false, set, pointType, {
            x = point.x, y = point.y, z = point.z, w = heading
        })
        Panel.notify(ok and 'Ponto configurado.' or (err or 'Nao foi possivel salvar o ponto.'),
            ok and 'success' or 'error')
        finish(set)
    end)
end

function Panel.placeDutyPoint(set)
    if placing then return end
    placing = true

    CreateThread(function()
        local point = aimForPoint('Ponto de Serviço (Bater Ponto)', 1.8)
        if not point then
            Panel.notify('Posicionamento cancelado.', 'inform')
            return finish(set)
        end

        local heading = GetGameplayCamRot(2).z
        local ok, err = lib.callback.await('nv_orgs:setDutyPoint', false, set, {
            x = point.x, y = point.y, z = point.z, w = heading
        })
        Panel.notify(ok and 'Ponto de serviço configurado.' or (err or 'Nao foi possivel salvar o ponto.'),
            ok and 'success' or 'error')
        finish(set)
    end)
end

function Panel.placeServicePed(set)
    if placing then return end
    placing = true

    CreateThread(function()
        local point = aimForPoint('PED de Serviço (Atendimento)', 1.8)
        if not point then
            Panel.notify('Posicionamento cancelado.', 'inform')
            return finish(set)
        end

        local heading = GetGameplayCamRot(2).z
        local ok, err = lib.callback.await('nv_orgs:setServicePed', false, set, {
            x = point.x, y = point.y, z = point.z, w = heading
        })
        Panel.notify(ok and 'PED de serviço configurado.' or (err or 'Nao foi possivel salvar o PED.'),
            ok and 'success' or 'error')
        finish(set)
    end)
end

-- --------------------------------------------------------- fechaduras --

--- A entidade de porta que o jogador esta mirando, se houver.
---
--- Porta no GTA e um objeto (tipo 3). O raycast usa a flag 16 (objetos) para
--- nao esbarrar em pedestre ou veiculo passando na frente.
---@return number?
local function aimedDoor()
    local hit, entity = lib.raycast.fromCamera(16, 4, Config.Placement.doorRange)

    if not hit or not entity or entity == 0 then return end
    if not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 3 then return end

    return entity
end

--- Dados de uma porta no formato que o ox_doorlock grava.
---@param entity number
---@return table
local function doorData(entity)
    local coords = GetEntityCoords(entity)

    return {
        coords  = { x = coords.x, y = coords.y, z = coords.z },
        model   = GetEntityModel(entity),
        heading = GetEntityHeading(entity)
    }
end

--- Modo de criacao de fechaduras.
---
--- Acumula portas numa lista e so grava no fim. Porta dupla existe no
--- ox_doorlock como UM registro com duas entradas em `doors`, entao duas
--- portas selecionadas viram um par -- e e assim que portas de garagem e de
--- delegacia funcionam de verdade.
---@param set string
function Panel.placeDoors(set)
    if placing then return end

    placing = true

    local picked = {}
    local pickedEntities = {}
    local aimedEntity
    local groups = lib.callback.await('nv_orgs:doorGroups', false, set)

    if not groups then
        return finish(set)
    end

    CreateThread(function()
        while placing do
            Wait(0)

            local entity = aimedDoor()

            if aimedEntity and aimedEntity ~= entity and not pickedEntities[aimedEntity] then
                setDoorOutline(aimedEntity, false)
            end

            aimedEntity = entity

            if entity then
                -- Contorno so na porta mirada: sem isso o admin nao tem como
                -- saber se esta mirando o batente ou a parede atras dele.
                setDoorOutline(entity, true)
            end

            showHelp(([[
**Criando fechaduras — %s**
Mire numa porta e pressione **[E]** para marcar.
Marque uma folha para porta simples ou duas folhas lado a lado para porta dupla.

Marcadas: **%d/2**
**[ENTER]** concluir  •  **[BACKSPACE]** cancelar
 ]]):format(set, #picked))

            -- E
            if IsControlJustReleased(0, 38) then
                if entity then
                    local data = doorData(entity)
                    local duplicate = false

                    for i = 1, #picked do
                        if #(vec3(picked[i].coords.x, picked[i].coords.y, picked[i].coords.z)
                            - vec3(data.coords.x, data.coords.y, data.coords.z)) < 0.05
                        then
                            duplicate = true
                            break
                        end
                    end

                    if duplicate then
                        Panel.notify('Esta porta ja foi marcada.', 'error')
                    elseif #picked >= 2 then
                        Panel.notify('Uma fechadura aceita no maximo duas folhas.', 'error')
                    elseif picked[1] and #(vec3(picked[1].coords.x, picked[1].coords.y, picked[1].coords.z)
                        - vec3(data.coords.x, data.coords.y, data.coords.z)) > Config.Placement.doubleDistance
                    then
                        Panel.notify(('A segunda porta deve estar a no maximo %.1f m da primeira.')
                            :format(Config.Placement.doubleDistance), 'error')
                    else
                        picked[#picked + 1] = data
                        pickedEntities[entity] = true
                        Panel.notify(('Porta marcada (%d).'):format(#picked), 'success')
                    end
                else
                    Panel.notify('Mire numa porta.', 'error')
                end
            end

            -- BACKSPACE
            if IsControlJustReleased(0, 194) then
                Panel.notify('Criacao de fechaduras cancelada.', 'inform')

                return finish(set)
            end

            -- ENTER
            if IsControlJustReleased(0, 191) then
                if #picked == 0 then
                    Panel.notify('Marque ao menos uma porta.', 'error')
                else
                    placing = false
                    lib.hideTextUI()
                    clearDoorOutlines()

                    -- O nome e pedido AQUI, e nao antes de comecar: so depois de
                    -- marcar as portas o admin sabe o que elas sao de fato.
                    local answer = lib.inputDialog('Nome da fechadura', {
                    {
                        type = 'input',
                        label = 'Nome',
                        description = 'Aparece na lista de fechaduras da organizacao.',
                        placeholder = 'Sala do Chefe',
                        required = true,
                        max = 40
                    },
                    {
                        type = 'checkbox',
                        label = 'Permitir lockpick',
                        description = 'Permite destrancar esta fechadura com os itens do ox_doorlock.',
                        checked = false
                    }
                    })

                    if not answer or not answer[1] then
                        Panel.notify('Criacao cancelada: sem nome.', 'error')

                        return finish(set)
                    end

                    local desired = answer[1]
                    local allowLockpick = answer[2] == true

                    -- Uma ou duas folhas sempre geram um unico registro. No caso
                    -- duplo, o ox_doorlock recebe ambas no array `doors`.
                    local groupsOfDoors = { picked }

                local created = 0
                local doubles = 0

                for i = 1, #groupsOfDoors do
                    local pair = groupsOfDoors[i]
                    local name = lib.callback.await('nv_orgs:doorName', false, set, desired)

                    if not name then break end

                    local data = {
                        name        = name,
                        groups      = groups,
                        maxDistance = 2.5,
                        state       = 1,
                        hideUi      = false,
                        lockpick    = allowLockpick or nil
                    }

                    if pair[2] then
                        data.doors = { pair[1], pair[2] }
                        -- O evento do ox_doorlock recebe tabelas comuns pelo
                        -- bridge; calcular aqui evita subtracao de table no servidor.
                        data.coords = {
                            x = (pair[1].coords.x + pair[2].coords.x) / 2,
                            y = (pair[1].coords.y + pair[2].coords.y) / 2,
                            z = (pair[1].coords.z + pair[2].coords.z) / 2
                        }
                        doubles = doubles + 1
                    else
                        data.coords  = pair[1].coords
                        data.model   = pair[1].model
                        data.heading = pair[1].heading
                    end

                    -- Disparado do CLIENTE de proposito: o ox_doorlock exige o
                    -- ACE `command.doorlock` e le o `source` do evento. Chamar
                    -- do nosso servidor nao teria source e seria recusado.
                    TriggerServerEvent('ox_doorlock:editDoorlock', nil, data)

                    created = created + 1

                    -- O nome seguinte depende do anterior ja estar gravado.
                    Wait(250)
                end

                Panel.notify(doubles > 0
                    and ('%d fechadura(s) criada(s), %d dupla(s).'):format(created, doubles)
                    or ('%d fechadura(s) criada(s).'):format(created), 'success')

                    return finish(set)
                end
            end
        end
    end)
end

-- --------------------------------------------------------------- baus --

--- Modo de posicionamento de um bau.
---
--- O ponto comeca a frente do jogador e acompanha ele: em vez de digitar
--- coordenada, o admin anda ate onde quer e confirma.
---@param set string
---@param options table { slot?, label, minPosition, management }
--- @param set string
--- @param options table { slot?, label, minPosition, management }
function Panel.placeStash(set, options)
    if placing then return end

    placing = true
    options = type(options) == 'table' and options or {}

    local label = type(options.label) == 'string' and options.label ~= '' and options.label or 'Bau'

    CreateThread(function()
        local point = aimForPoint(('Posicionando: %s'):format(label), Config.Stash.zoneSize)

        placing = false
        lib.hideTextUI()

        if not point then
            Panel.notify('Posicionamento cancelado.', 'inform')
            return finish(set)
        end

        local ok, err = lib.callback.await('nv_orgs:saveStash', false, set, {
            slot        = options.slot,
            label       = label,
            minPosition = options.minPosition,
            management  = options.management,
            coords      = { x = point.x, y = point.y, z = point.z }
        })

        Panel.notify(ok and ('%s posicionado.'):format(label) or (err or 'Nao foi possivel salvar o bau.'),
            ok and 'success' or 'error')

        finish(set)
    end)
end



-- ------------------------------------------- estacionamento: atendente --

--- Posiciona o atendente da frota. O ped fica onde o admin estiver, virado
--- para onde ele estiver olhando -- e por isso o heading vem do proprio ped.
---@param set string
---@param model string
function Panel.placeGaragePed(set, model)
    if placing then return end

    placing = true

    CreateThread(function()
        while placing do
            Wait(0)

            local coords = GetEntityCoords(cache.ped)

            showHelp(([[
**Posicionando o atendente — %s**
Fique onde o atendente deve ficar, olhando para onde ele deve olhar.

Modelo: **%s**
**[ENTER]** confirmar  •  **[BACKSPACE]** cancelar
]]):format(set, model))

            if IsControlJustReleased(0, 194) then
                Panel.notify('Posicionamento cancelado.', 'inform')

                return finish(set)
            end

            if IsControlJustReleased(0, 191) then
                placing = false
                lib.hideTextUI()

                local ok, err = lib.callback.await('nv_orgs:saveGaragePed', false, set, {
                    model   = model,
                    coords  = { x = coords.x, y = coords.y, z = coords.z },
                    heading = GetEntityHeading(cache.ped)
                })

                Panel.notify(ok and 'Atendente posicionado.' or (err or 'Nao foi possivel.'),
                    ok and 'success' or 'error')

                return finish(set)
            end
        end
    end)
end

-- ----------------------------------------------- estacionamento: vagas --

--- Marca vagas de estacionamento.
---
--- Acumula quantas o admin quiser numa passada so: garagem de delegacia tem
--- oito vagas, e sair e voltar no painel a cada uma seria trabalho a toa.
--- O heading importa aqui -- e a direcao em que o carro nasce.
---@param set string
function Panel.placeSpawns(set)
    if placing then return end

    placing = true

    local added = 0

    CreateThread(function()
        while placing do
            Wait(0)

            local coords = GetEntityCoords(cache.ped)
            local heading = GetEntityHeading(cache.ped)
            local marker = Config.Placement.marker

            -- Seta no chao apontando para o heading atual: sem ela nao da para
            -- saber de que lado o carro vai nascer.
            DrawMarker(20, coords.x, coords.y, coords.z - 0.9,
                0.0, 0.0, 0.0, 0.0, 0.0, heading,
                1.2, 1.2, 1.2,
                marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                false, false, 2, nil, nil, false)

            showHelp(([[
**Marcando vagas — %s**
Fique em cima da vaga, virado para onde o carro deve nascer.

**[E]** marcar vaga  •  marcadas: **%d**
**[ENTER]** concluir  •  **[BACKSPACE]** cancelar
]]):format(set, added))

            if IsControlJustReleased(0, 38) then
                local ok = lib.callback.await('nv_orgs:addSpawn', false, set, {
                    coords  = { x = coords.x, y = coords.y, z = coords.z },
                    heading = heading
                })

                if ok then
                    added = added + 1
                    Panel.notify(('Vaga %d marcada.'):format(added), 'success')
                else
                    Panel.notify('Nao foi possivel marcar a vaga.', 'error')
                end
            end

            if IsControlJustReleased(0, 194) then
                Panel.notify(added > 0 and ('%d vaga(s) marcada(s).'):format(added) or 'Cancelado.',
                    'inform')

                return finish(set)
            end

            if IsControlJustReleased(0, 191) then
                Panel.notify(('%d vaga(s) marcada(s).'):format(added),
                    added > 0 and 'success' or 'inform')

                return finish(set)
            end
        end
    end)
end

-- ------------------------------------------------------------ vestiario --

--- Marca pontos de vestiario. Varios por organizacao, como pedido.
---@param set string
---@param minPosition number
--- Marca pontos de vestiario. Varios por organizacao, como pedido.
---@param set string
---@param minPosition number
function Panel.placeWardrobe(set, minPosition)
    if placing then return end

    placing = true

    local added = 0

    CreateThread(function()
        -- Um ponto por vez, mas em laco: mirar, confirmar, mirar de novo. Sair
        -- e voltar no painel a cada vestiario seria trabalho a toa.
        while true do
            local point = aimForPoint(
                ('Vestiario %d — mire e confirme'):format(added + 1), 1.8)

            if not point then break end

            local ok = lib.callback.await('nv_orgs:addWardrobe', false, set, {
                coords = { x = point.x, y = point.y, z = point.z },
                minPosition = minPosition
            })

            if ok then
                added = added + 1
                Panel.notify(('Vestiario %d marcado. Mire no proximo ou cancele para sair.'):format(added), 'success')
            else
                Panel.notify('Nao foi possivel marcar o ponto.', 'error')
                break
            end
        end

        placing = false
        lib.hideTextUI()

        Panel.notify(('%d ponto(s) marcado(s).'):format(added), added > 0 and 'success' or 'inform')
        finish(set)
    end)
end



-- ------------------------------------------------------------- limpeza --

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and placing then
        placing = false
        lib.hideTextUI()
    end
end)
