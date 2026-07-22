--[[
    nv_orgs — cliente

    O cliente aqui e uma ponte fina de proposito: ele abre a tela, repassa
    cliques e mostra o que o servidor responde. Nenhuma validacao mora aqui --
    a tela existir nao autoriza nada, e cada callback do servidor confere o
    admin por conta propria.
]]

--- Namespace compartilhado com place.lua e stashes.lua.
Panel = {}

local open = false

---@param message string
---@param type string?
local function notify(message, type)
    lib.notify({
        title = 'Organizacoes',
        description = message,
        type = type or 'inform',
        position = 'top'
    })
end

Panel.notify = notify

-- --------------------------------------------------- itens do ox_inv --

--- Handler dos itens usaveis (a chave). Registrado AQUI, no primeiro arquivo
--- do resource, e preenchido por client/keys.lua. Se o export ficasse na
--- ultima linha de keys.lua, qualquer erro no meio daquele arquivo impediria
--- o registro, e o ox_inventory culparia a chave por uma falha que nao e dela
--- -- foi a licao do useLockpick no nv_garage.
---@type table<string, function>
Panel.itemHandlers = {}

exports('useKey', function(...)
    local handler = Panel.itemHandlers.key

    if not handler then
        print('[nv_orgs] handler da chave nao foi registrado: procure o erro ANTERIOR a este no console.')
        return notify('Esta chave nao esta funcionando. Avise a equipe.', 'error')
    end

    return handler(...)
end)

local function close()
    if not open then return end

    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

Panel.close = close

--- Abre o painel. `selectSet` faz a tela ja voltar na organizacao certa --
--- usado quando o modo de posicionamento devolve o controle.
---@param selectSet string?
local function openPanel(selectSet)
    if open then return end

    local list = lib.callback.await('nv_orgs:list', false)

    -- Sem permissao o servidor devolve nil, e nao uma lista vazia: sao coisas
    -- diferentes e o jogador merece saber qual das duas aconteceu.
    if not list then
        return notify('Voce nao tem permissao para isso.', 'error')
    end

    open = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action  = 'open',
        list    = list,
        styles   = Config.Styles,
        subtypes = Config.Subtypes,
        actions = Config.Actions,
        select  = selectSet,
        limits  = {
            maxGrades  = Config.Grades.max,
            setMin     = Config.Org.setMinLength,
            setMax     = Config.Org.setMaxLength,
            labelMax   = Config.Org.labelMaxLength,
            searchMin  = Config.Search.minLength,
            stashSlots = Config.Stash.defaultSlots,
            stashWeight = Config.Stash.defaultWeight
        }
    })
end

Panel.open = openPanel

RegisterCommand(Config.Command, openPanel, false)

--- Abre o painel a partir de outro resource (o nv_adminmenu usa isto).
---
--- Export em vez de `ExecuteCommand('orgs')`: o nome do comando e
--- configuravel, entao quem chamasse pelo comando quebraria em silencio se
--- alguem trocasse `Config.Command`. O export tem nome fixo.
---
--- Nao ha checagem de permissao aqui de proposito -- quem autoriza e o
--- callback `nv_orgs:list` no servidor, e ele responde nil para quem nao e
--- admin. Um export que so abre uma tela nao precisa ser secreto.
exports('open', openPanel)

-- ------------------------------------------------------ callbacks NUI --

--- Encurta o repeticao de "recebe da NUI, chama o servidor, devolve".
---
---@param name string        nome do callback NUI
---@param callback string    callback do servidor
---@param build fun(data: table): ...  argumentos a enviar
---@param onOk fun(...)|nil  o que fazer no sucesso
local function bridge(name, callback, build, onOk)
    RegisterNUICallback(name, function(data, cb)
        if type(data) ~= 'table' then data = {} end

        local ok, err, extra = lib.callback.await(callback, false, build(data))

        if not ok then
            notify(err or 'Nao foi possivel.', 'error')
            return cb({ ok = false, error = err })
        end

        if onOk then onOk(extra, data) end

        cb({ ok = true, value = extra })
    end)
end

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

RegisterNUICallback('dealership', function(data, cb)
    cb(lib.callback.await('nv_orgs:dealership', false, data.set))
end)

RegisterNUICallback('dealershipPoint', function(data, cb)
    local options = {
        { value = 'payment', label = 'Local de pagamento' },
        { value = 'truckSpawn', label = 'Spawn do caminhao' },
        { value = 'invoiceNpc', label = 'Retirada da NF / NPC' },
        { value = 'trailerSpawn', label = 'Spawn do trailer' },
        { value = 'unload', label = 'Ponto de entrega' },
        { value = 'preview', label = 'Previa do veiculo' },
        { value = 'saleSpawn', label = 'Spawn da compra' },
        { value = 'testSpawn', label = 'Spawn do test-drive' }
    }
    local answer = lib.inputDialog('Configurar concessionaria', {{
        type = 'select', label = 'Ponto que recebera sua posicao atual', options = options, required = true
    }})
    if not answer then return cb({ ok = false }) end
    cb({ ok = true })
    close()
    Panel.placeDealershipPoint(data.set, answer[1], options)
end)

RegisterNUICallback('dealershipBlip', function(data, cb)
    local options = {}
    for i = 1, #(Config.DealershipBlips or {}) do
        options[i] = { value = Config.DealershipBlips[i].value, label = Config.DealershipBlips[i].label }
    end
    local answer = lib.inputDialog('Blip da concessionaria', {
        { type = 'select', label = 'Icone do mapa', options = options, searchable = true, required = true, default = 326 },
        { type = 'input', label = 'Nome exibido no mapa', default = 'Concessionaria', max = 50, required = true },
        { type = 'number', label = 'Raio da area operacional (metros)', default = 60, min = 10, max = 500, required = true }
    })
    if not answer then return cb({ ok = false }) end
    local coords = GetEntityCoords(cache.ped)
    local ok, err = lib.callback.await('nv_orgs:setDealershipBlip', false, data.set, {
        x = coords.x, y = coords.y, z = coords.z,
        sprite = answer[1], label = answer[2], radius = answer[3]
    })
    if not ok then notify(err or 'Nao foi possivel configurar o blip.', 'error') end
    cb({ ok = ok == true })
end)

RegisterNUICallback('removeDealershipCategory', function(data, cb)
    local ok, err = lib.callback.await('nv_orgs:removeDealershipCategory', false, data.set, data.category)
    if not ok then notify(err or 'Nao foi possivel remover a categoria.', 'error') end
    cb({ ok = ok == true })
end)

RegisterNUICallback('removeDealershipPoint', function(data, cb)
    local ok, err = lib.callback.await('nv_orgs:removeDealershipPoint', false, data.set, data.point)
    if not ok then notify(err or 'Nao foi possivel remover o ponto.', 'error') end
    cb({ ok = ok == true })
end)

RegisterNUICallback('dealershipCategories', function(data, cb)
    local answer = lib.inputDialog('Categorias da concessionaria', {{
        type = 'multi-select', label = 'Tipos vendidos', required = true, searchable = true,
        options = {
            { value = 'compact', label = 'Compactos' }, { value = 'sedan', label = 'Sedans' },
            { value = 'suv', label = 'SUVs' }, { value = 'coupe', label = 'Coupes' },
            { value = 'muscle', label = 'Muscle' }, { value = 'sportsclassic', label = 'Esportivos classicos' },
            { value = 'sports', label = 'Esportivos' }, { value = 'super', label = 'Super' },
            { value = 'motorcycle', label = 'Motos' }, { value = 'offroad', label = 'Off-road' },
            { value = 'industrial', label = 'Industriais' }, { value = 'utility', label = 'Utilitarios' },
            { value = 'van', label = 'Vans' }, { value = 'cycle', label = 'Bicicletas' },
            { value = 'boat', label = 'Barcos' }, { value = 'helicopter', label = 'Helicopteros' },
            { value = 'plane', label = 'Avioes' }, { value = 'service', label = 'Servico' },
            { value = 'emergency', label = 'Emergencia' }, { value = 'military', label = 'Militares' },
            { value = 'commercial', label = 'Comerciais' }, { value = 'train', label = 'Trens' },
            { value = 'openwheel', label = 'Formula' }
        }
    }})
    if not answer then return cb({ ok = false }) end
    local ok, err = lib.callback.await('nv_orgs:setDealershipCategories', false, data.set, answer[1])
    if not ok then notify(err or 'Nao foi possivel salvar as categorias.', 'error') end
    cb({ ok = ok == true })
end)

bridge('buyDealershipTablet', 'nv_orgs:buyDealershipTablet', function(data)
    return data.set
end, function()
    notify('Tablet adquirido por $100.', 'success')
end)

-- Consultas: devolvem dados para a tela, sem notificacao.
RegisterNUICallback('get', function(data, cb)
    cb(lib.callback.await('nv_orgs:get', false, data and data.set) or false)
end)

RegisterNUICallback('members', function(data, cb)
    cb(lib.callback.await('nv_orgs:members', false, data and data.set) or {})
end)

RegisterNUICallback('search', function(data, cb)
    cb(lib.callback.await('nv_orgs:search', false, data and data.set, data and data.query) or {})
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('nv_orgs:list', false) or {})
end)

RegisterNUICallback('doors', function(data, cb)
    cb(lib.callback.await('nv_orgs:doors', false, data and data.set) or {})
end)

RegisterNUICallback('stashList', function(data, cb)
    cb(lib.callback.await('nv_orgs:stashes', false, data and data.set) or {})
end)

RegisterNUICallback('getDutyData', function(data, cb)
    cb(lib.callback.await('nv_orgs:getDutyData', false, data and data.set) or {})
end)

RegisterNUICallback('placeDutyPoint', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or type(data.set) ~= 'string' then return end
    close()
    Panel.placeDutyPoint(data.set)
end)

RegisterNUICallback('removeDutyPoint', function(data, cb)
    if type(data) ~= 'table' or type(data.set) ~= 'string' then return cb({ ok = false }) end
    local ok, err = lib.callback.await('nv_orgs:removeDutyPoint', false, data.set)
    if not ok then notify(err or 'Nao foi possivel remover o ponto de servico.', 'error') end
    cb({ ok = ok == true })
end)

RegisterNUICallback('placeServicePed', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or type(data.set) ~= 'string' then return end
    close()
    Panel.placeServicePed(data.set)
end)

RegisterNUICallback('removeServicePed', function(data, cb)
    if type(data) ~= 'table' or type(data.set) ~= 'string' then return cb({ ok = false }) end
    local ok, err = lib.callback.await('nv_orgs:removeServicePed', false, data.set)
    if not ok then notify(err or 'Nao foi possivel remover o PED de servico.', 'error') end
    cb({ ok = ok == true })
end)

RegisterNUICallback('contacts', function(data, cb)
    cb(lib.callback.await('nv_orgs:contacts', false, data and data.set) or {})
end)

RegisterNUICallback('garage', function(data, cb)
    cb(lib.callback.await('nv_orgs:garage', false, data and data.set) or false)
end)

RegisterNUICallback('wardrobe', function(data, cb)
    cb(lib.callback.await('nv_orgs:wardrobe', false, data and data.set) or false)
end)

RegisterNUICallback('craftProject',function(data,cb) cb(lib.callback.await('nv_orgs:craftProject',false,data and data.set) or false) end)
RegisterNUICallback('placeCraftProject',function(data,cb)
    cb(1);if type(data)~='table' then return end;close()
    local answer=lib.inputDialog('Bancada de crafting',{{type='input',label='Nome',default='Bancada da organizacao',required=true},{type='checkbox',label='Criar prop de caixa de ferramentas'}})
    if not answer then return Panel.open(data.set) end
    Panel.placeCraftProject(data.set,{label=answer[1],prop=answer[2]==true or answer[2]==1 or answer[2]=='true'})
end)
RegisterNUICallback('deleteCraftProject',function(data,cb)
    local ok,err=lib.callback.await('nv_orgs:deleteCraftProject',false,data and data.set);if not ok then notify(err or 'Nao foi possivel remover.','error') end;cb({ok=ok==true})
end)

-- ---------------------------------------------------------- vestiario --

RegisterNUICallback('placeWardrobe', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.set) ~= 'string' then return end

    local total = math.max(1, tonumber(data.grades) or 1)

    close()

    local answer = lib.inputDialog('Novo vestiario', {
        {
            type = 'slider',
            label = 'Cargos que podem usar (a partir do topo)',
            default = total,
            min = 1,
            max = total
        }
    })

    if not answer then return Panel.open(data.set) end

    Panel.placeWardrobe(data.set, answer[1])
end)

--- Salva como uniforme a roupa que o admin esta vestindo AGORA.
---
--- Nao ha editor de roupa aqui de proposito: o illenium ja tem um completo. O
--- fluxo e vestir a roupa por la e depois vir aqui salvar o que esta no corpo.
RegisterNUICallback('saveOutfit', function(data, cb)
    if type(data) ~= 'table' or type(data.set) ~= 'string' then
        return cb({ ok = false })
    end

    local total = math.max(1, tonumber(data.grades) or 1)
    local outfit = Panel.currentOutfit()

    if not outfit then
        notify('Nao foi possivel ler a sua roupa atual. O illenium-appearance esta rodando?', 'error')
        return cb({ ok = false })
    end

    local answer = lib.inputDialog(data.id and 'Editar uniforme' or 'Salvar uniforme', {
        {
            type = 'input',
            label = 'Nome do uniforme',
            description = 'A roupa salva e a que voce esta vestindo agora.',
            default = data.label or 'Uniforme',
            required = true,
            max = 50
        },
        {
            type = 'slider',
            label = 'Cargos que podem vestir (a partir do topo)',
            default = math.min(tonumber(data.minPosition) or total, total),
            min = 1,
            max = total
        }
    })

    if not answer then return cb({ ok = false }) end

    local ok, err = lib.callback.await('nv_orgs:saveOutfit', false, data.set, {
        id          = data.id,
        label       = answer[1],
        minPosition = answer[2],
        model       = outfit.model,
        components  = outfit.components,
        props       = outfit.props
    })

    if not ok then
        notify(err or 'Nao foi possivel salvar o uniforme.', 'error')
        return cb({ ok = false })
    end

    notify('Uniforme salvo.', 'success')
    cb({ ok = true })
end)

-- ---------------------------------------------------- estacionamento --

--- O modelo do atendente e pedido antes de sair do painel: e a unica coisa que
--- o admin precisa decidir, e decidir isso andando pelo mapa seria pior.
RegisterNUICallback('placeGaragePed', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.set) ~= 'string' then return end

    close()

    local answer = lib.inputDialog('Atendente da frota', {
        {
            type = 'input',
            label = 'Modelo do ped',
            description = 'Nome do modelo, como s_m_y_valet_01.',
            default = 's_m_y_valet_01',
            required = true,
            max = 24
        }
    })

    if not answer or not answer[1] then return Panel.open(data.set) end

    Panel.placeGaragePed(data.set, answer[1])
end)

RegisterNUICallback('placeSpawns', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.set) ~= 'string' then return end

    close()
    Panel.placeSpawns(data.set)
end)

--- Formulario de veiculo da frota.
---
--- Fica num dialogo do ox_lib, e nao em campos na NUI, porque o painel ja tem
--- tres listas na mesma aba -- mais um formulario inline ali viraria bagunca.
RegisterNUICallback('fleetDialog', function(data, cb)
    if type(data) ~= 'table' or type(data.set) ~= 'string' then
        return cb({ ok = false })
    end

    local total = math.max(1, tonumber(data.grades) or 1)

    -- Catalogo da concessionaria: o modelo vira uma lista pesquisavel em vez
    -- de um campo aberto, entao nao da mais para gravar um spawn code que nao
    -- existe.
    local catalog = lib.callback.await('nv_orgs:vehicleCatalog', false)

    -- Monta a linha do modelo. Com catalogo, um select pesquisavel; sem ele
    -- (json ilegivel, dealership fora do ar), cai no campo de texto de antes,
    -- para a frota nunca ficar impossivel de montar.
    local modelRow

    if type(catalog) == 'table' and #catalog > 0 then
        local options = {}
        local hasCurrent = false

        for i = 1, #catalog do
            options[i] = {
                value = catalog[i].model,
                label = ('%s [%s] - $%d'):format(catalog[i].label, catalog[i].model, catalog[i].price or 1000)
            }

            if catalog[i].model == data.model then hasCurrent = true end
        end

        -- Editando um veiculo cujo modelo saiu do catalogo: injeta o atual como
        -- opcao, senao salvar sem tocar no modelo o trocaria por outro.
        if data.model and data.model ~= '' and not hasCurrent then
            options[#options + 1] = { value = data.model, label = ('%s (fora do catalogo)'):format(data.model) }
        end

        modelRow = {
            type = 'select',
            label = 'Modelo',
            description = 'O valor exibido sera pago pelo banco da organizacao na compra.',
            options = options,
            default = data.model ~= '' and data.model or nil,
            searchable = true,
            required = true
        }
    else
        modelRow = {
            type = 'input',
            label = 'Modelo',
            description = 'Catalogo indisponivel. Digite o spawn code, como police.',
            default = data.model,
            required = true,
            max = 20
        }
    end

    local answer = lib.inputDialog(data.id and 'Editar veiculo' or 'Novo veiculo da frota', {
        modelRow,
        {
            type = 'input',
            label = 'Nome exibido',
            default = data.label,
            max = 50
        },
        {
            type = 'slider',
            label = 'Liberado ate o cargo (1 = so o mais alto)',
            default = math.min(tonumber(data.minPosition) or total, total),
            min = 1,
            max = total
        }
    })

    if not answer then return cb({ ok = false }) end

    local ok, err = lib.callback.await('nv_orgs:saveFleet', false, data.set, {
        id          = data.id,
        model       = answer[1],
        label       = answer[2],
        minPosition = answer[3]
    })

    if not ok then
        notify(err or 'Nao foi possivel salvar o veiculo.', 'error')
        return cb({ ok = false })
    end

    notify('Frota atualizada.', 'success')
    cb({ ok = true })
end)

--- Renomear pede o nome novo por dialogo, e nao por campo na NUI: o painel ja
--- tem o foco do mouse, e um input inline aqui exigiria estado extra para uma
--- acao que acontece de vez em quando.
RegisterNUICallback('renameDoor', function(data, cb)
    if type(data) ~= 'table' or type(data.set) ~= 'string' or type(data.id) ~= 'number' then
        return cb({ ok = false })
    end

    local answer = lib.inputDialog('Renomear fechadura', {
        {
            type = 'input',
            label = 'Nome',
            default = data.label,
            required = true,
            max = 40
        }
    })

    if not answer or not answer[1] then return cb({ ok = false }) end

    local ok, err = lib.callback.await('nv_orgs:renameDoor', false, data.set, data.id, answer[1])

    if not ok then
        notify(err or 'Nao foi possivel renomear.', 'error')
        return cb({ ok = false })
    end

    notify('Fechadura renomeada.', 'success')
    cb({ ok = true })
end)

--- Excluir fechadura passa pelo net event do ox_doorlock, que le o ACE do
--- `source` -- por isso sai daqui, do cliente do admin.
RegisterNUICallback('deleteDoor', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'number' then
        return cb({ ok = false })
    end

    TriggerServerEvent('ox_doorlock:editDoorlock', data.id, nil)
    notify('Fechadura removida.', 'success')

    cb({ ok = true })
end)

-- Posicionamento: o painel PRECISA fechar, senao o admin nao consegue andar
-- nem mirar. `Panel.open` no fim devolve a tela na mesma organizacao.
RegisterNUICallback('placeDoors', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.set) ~= 'string' then return end

    close()
    Panel.placeDoors(data.set)
end)

--- Antes de posicionar, o admin define o bau: nome, quantos cargos do topo o
--- abrem, e se e o da gerencia. Perguntar aqui e nao na NUI evita levar esse
--- formulario inteiro para dentro do painel por causa de uma acao pontual.
RegisterNUICallback('placeStash', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.set) ~= 'string' then return end

    local total = tonumber(data.grades) or 1

    close()

    local answer = lib.inputDialog('Novo bau', {
        {
            type = 'input',
            label = 'Nome',
            default = data.label or 'Bau',
            required = true,
            max = 40
        },
        {
            type = 'slider',
            label = 'Cargos que podem abrir (a partir do topo)',
            default = math.min(tonumber(data.minPosition) or total, total),
            min = 1,
            max = math.max(total, 1)
        },
        {
            type = 'checkbox',
            label = 'Este e o bau de gerencia',
            checked = data.management == true
        }
    })

    if not answer then
        -- Cancelou: devolve o painel em vez de largar o admin sem tela.
        return Panel.open(data.set)
    end

    Panel.placeStash(data.set, {
        slot        = data.slot,
        label       = answer[1],
        minPosition = answer[2],
        management  = answer[3] == true
    })
end)

-- Acoes: mudam estado e avisam o jogador.
bridge('create', 'nv_orgs:create',
    function(data) return data.org end,
    function() notify('Organizacao criada.', 'success') end)

bridge('update', 'nv_orgs:update',
    function(data) return data.set, data.org end,
    function() notify('Organizacao atualizada.', 'success') end)

--- Excluir tem um passo a mais que os outros: as fechaduras.
---
--- Elas vivem no ox_doorlock e ficariam com `groups = { <set> = 1 }` apontando
--- para um grupo que nao existe mais -- ou seja, trancadas para sempre, sem
--- ninguem no mundo capaz de abrir. Como a exclusao de porta usa o mesmo net
--- event da criacao (que le o ACE do `source`), ela precisa partir daqui, do
--- cliente do admin, e nao do nosso servidor.
RegisterNUICallback('delete', function(data, cb)
    if type(data) ~= 'table' or type(data.set) ~= 'string' then
        return cb({ ok = false })
    end

    local doors = lib.callback.await('nv_orgs:doors', false, data.set) or {}

    for i = 1, #doors do
        TriggerServerEvent('ox_doorlock:editDoorlock', doors[i].id, nil)
    end

    local ok, err = lib.callback.await('nv_orgs:delete', false, data.set)

    if not ok then
        notify(err or 'Nao foi possivel excluir.', 'error')
        return cb({ ok = false, error = err })
    end

    notify(('Organizacao excluida (%d fechadura(s) removida(s)).'):format(#doors), 'success')

    cb({ ok = true })
end)

bridge('hire', 'nv_orgs:hire',
    function(data) return data.set, data.charId, data.position end,
    function(name) notify(('%s foi contratado.'):format(name or 'Personagem'), 'success') end)

bridge('setGrade', 'nv_orgs:setGrade',
    function(data) return data.set, data.charId, data.position end,
    function() notify('Cargo alterado.', 'success') end)

bridge('fire', 'nv_orgs:fire',
    function(data) return data.set, data.charId end,
    function() notify('Membro demitido.', 'success') end)

bridge('deleteStash', 'nv_orgs:deleteStash',
    function(data) return data.set, data.slot end,
    function() notify('Bau removido. Os itens continuam guardados.', 'success') end)

bridge('deleteGaragePed', 'nv_orgs:deleteGaragePed',
    function(data) return data.set end,
    function() notify('Atendente removido.', 'success') end)

bridge('deleteSpawn', 'nv_orgs:deleteSpawn',
    function(data) return data.set, data.id end,
    function() notify('Vaga removida.', 'success') end)

bridge('deleteFleet', 'nv_orgs:deleteFleet',
    function(data) return data.set, data.id end,
    function() notify('Veiculo removido da frota.', 'success') end)

bridge('deleteWardrobe', 'nv_orgs:deleteWardrobe',
    function(data) return data.set, data.id end,
    function() notify('Vestiario removido.', 'success') end)

bridge('deleteOutfit', 'nv_orgs:deleteOutfit',
    function(data) return data.set, data.id end,
    function() notify('Uniforme removido.', 'success') end)

bridge('genKey', 'nv_orgs:generateKey',
    function(data) return data.set end,
    function(org) notify(('Chave de %s gerada. Esta com voce para distribuir.'):format(org or 'organizacao'), 'success') end)

bridge('newContact', 'nv_orgs:newContact',
    function(data) return data.set end,
    function(number) notify(('Novo numero: %s. O papel esta com voce.'):format(number or '?'), 'success') end)

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
    if resource == GetCurrentResourceName() and open then
        SetNuiFocus(false, false)
    end
end)
