--[[
    nv_orgs — cliente: atendente do estacionamento

    Desenha o ped de cada organizacao e a opcao de target nele.

    Visibilidade e interacao sao coisas SEPARADAS aqui, e isso foi pedido:
    numa organizacao estatal o atendente aparece para todo mundo (uma delegacia
    tem recepcao visivel), mas so membro consegue interagir. Num job, o ped nem
    e criado para quem nao e do set -- a garagem de uma empresa privada nao
    precisa existir para o resto da cidade.
]]

local Ox = require '@ox_core.lib.init'

--- Peds criados, por set.
---@type table<string, number>
local peds = {}

--- Ultima lista recebida do servidor, para poder redesenhar quando o cargo do
--- jogador mudar sem que a configuracao tenha mudado.
---@type table[]
local lastList = {}

local function clearAll()
    for set, ped in pairs(peds) do
        if DoesEntityExist(ped) then
            -- `addLocalEntity` se desfaz com `removeLocalEntity`, e nao com
            -- `removeZone` -- ele nao devolve id de zona nenhum.
            pcall(function() exports.ox_target:removeLocalEntity(ped) end)
            DeleteEntity(ped)
        end

        peds[set] = nil
    end
end

--- O jogador pertence a esta organizacao?
---@param set string
---@return boolean
local function isMember(set)
    local ok, player = pcall(function() return Ox.GetPlayer() end)

    if not ok or not player then return false end

    local got, grade = pcall(function() return player.getGroup(set) end)

    return got and grade ~= nil and grade ~= false
end

-- ------------------------------------------------------------- frota --

--- Menu de retirada, montado com o que o SERVIDOR disse que este jogador pode
--- ver. A lista nao e filtrada aqui: o cliente nao sabe o cargo de ninguem.
---@param set string
local function openFleet(set)
    local data = lib.callback.await('nv_orgs:fleetFor', false, set)

    if not data then
        return Panel.notify('Voce nao tem acesso a esta garagem.', 'error')
    end

    if #data.fleet == 0 then
        return Panel.notify('Nenhum veiculo liberado para o seu cargo.', 'inform')
    end

    local options = {}

    for i = 1, #data.fleet do
        local entry = data.fleet[i]

        options[#options + 1] = {
            title = entry.label,
            description = entry.price > 0
                and ('$%d — pago pelo caixa da empresa'):format(entry.price)
                or 'Sem custo',
            icon = 'fa-solid fa-car',
            onSelect = function()
                local ok, err, label = lib.callback.await('nv_orgs:takeFleetVehicle', false, set, entry.id)

                if not ok then
                    return Panel.notify(err or 'Nao foi possivel retirar.', 'error')
                end

                Panel.notify(('%s liberado. A chave esta com voce.'):format(label or 'Veiculo'), 'success')
            end
        }
    end

    lib.registerContext({
        id = 'nv_orgs_fleet',
        title = data.balance
            and ('Frota — caixa: $%s'):format(data.balance)
            or 'Frota',
        options = options
    })

    lib.showContext('nv_orgs_fleet')
end

-- ------------------------------------------------------------- desenho --

---@param list table[]
local function drawGarages(list)
    if type(list) == 'table' then lastList = list end

    clearAll()

    for i = 1, #lastList do
        local entry = lastList[i]

        -- Organizacao estatal: o atendente existe para todo mundo (delegacia
        -- tem recepcao). Job: o ped so e criado para quem e do set -- a
        -- garagem de uma empresa privada nao precisa existir para a cidade.
        -- Nos dois casos a INTERACAO fica com o filtro `groups` do target.
        if entry.publicPed or isMember(entry.set) then
        local model = joaat(entry.model)

        CreateThread(function()
            if not lib.requestModel(model, 8000) then
                lib.print.warn(('nv_orgs: modelo de atendente "%s" nao carregou.'):format(entry.model))
                return
            end

            local ped = CreatePed(4, model, entry.coords.x, entry.coords.y, entry.coords.z - 1.0,
                entry.heading or 0.0, false, true)

            SetModelAsNoLongerNeeded(model)

            if not ped or ped == 0 then return end

            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)

            peds[entry.set] = ped

            exports.ox_target:addLocalEntity(ped, {
                {
                    name = ('nv_orgs_fleet_%s'):format(entry.set),
                    label = 'Frota da organizacao',
                    icon = 'fa-solid fa-warehouse',
                    distance = 2.5,
                    -- Filtro nativo do ox_target: quem nao e do set nao ve a
                    -- opcao, mesmo que o ped esteja visivel.
                    groups = { [entry.set] = 1 },
                    onSelect = function()
                        openFleet(entry.set)
                    end
                }
            })
        end)
        end
    end
end

RegisterNetEvent('nv_orgs:garages', drawGarages)

--- Contratado ou demitido? Os peds de job aparecem ou somem conforme o set.
--- Se este evento nao existir na sua versao do ox_core, o ped se ajusta no
--- proximo relog -- nao trava nada.
RegisterNetEvent('ox:setGroup', function()
    drawGarages(nil)
end)

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end

    Wait(1500)
    TriggerServerEvent('nv_orgs:requestGarages')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearAll() end
end)
