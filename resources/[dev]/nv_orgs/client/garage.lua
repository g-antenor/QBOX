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

--- Todos os peds criados por esta instancia. A chave e a entidade para que
--- duas threads concorrentes nunca sobrescrevam a referencia uma da outra.
---@type table<number, string>
local peds = {}
local garagePoints = {}

--- Cada redesenho invalida as threads de carregamento do desenho anterior.
local drawGeneration = 0

--- Ultima lista recebida do servidor, para poder redesenhar quando o cargo do
--- jogador mudar sem que a configuracao tenha mudado.
---@type table[]
local lastList = {}

local function clearAll()
    for i=1,#garagePoints do pcall(function() garagePoints[i]:remove() end) end
    table.wipe(garagePoints)
    lib.hideTextUI()

    for ped in pairs(peds) do
        if DoesEntityExist(ped) then
            -- `addLocalEntity` se desfaz com `removeLocalEntity`, e nao com
            -- `removeZone` -- ele nao devolve id de zona nenhum.
            pcall(function() exports.ox_target:removeLocalEntity(ped) end)
            SetEntityAsMissionEntity(ped,true,true)
            DeleteEntity(ped)
        end

        peds[ped] = nil
    end
end

--- Remove atendentes orfaos deixados por uma instancia anterior. O filtro usa
--- modelo e coordenada exata para nao atingir NPCs normais do mapa.
local function clearOrphans(entry,model)
    local expected=vec3(entry.coords.x,entry.coords.y,entry.coords.z-1.0)
    for _,ped in ipairs(GetGamePool('CPed')) do
        if ped~=cache.ped and DoesEntityExist(ped) and GetEntityModel(ped)==model
            and #(GetEntityCoords(ped)-expected)<0.75 then
            pcall(function() exports.ox_target:removeLocalEntity(ped) end)
            SetEntityAsMissionEntity(ped,true,true)
            DeleteEntity(ped)
            peds[ped]=nil
        end
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

local function storeCompanyVehicle(set)
    local vehicle=cache.vehicle
    if not vehicle or cache.seat~=-1 then return Panel.notify('Esteja ao volante do veiculo.','error') end
    local mechanical=GetResourceState('nv_mechanic')=='started' and exports.nv_mechanic:GetSnapshot(vehicle) or nil
    local ok,err=lib.callback.await('nv_orgs:storeFleetVehicle',false,set,VehToNet(vehicle),lib.getVehicleProperties(vehicle),mechanical)
    Panel.notify(ok and 'Veiculo guardado na garagem da organizacao.' or (err or 'Nao foi possivel guardar.'),ok and 'success' or 'error')
end

local function createGaragePoints(entry)
    for i=1,#(entry.spawns or {}) do
        local spawn=entry.spawns[i]
        local point=lib.points.new({coords=vec3(spawn.x,spawn.y,spawn.z),distance=12.0,set=entry.set})
        function point:nearby()
            local driving=cache.vehicle and cache.seat==-1
            if not driving or self.currentDistance>2.2 then
                if self.showing then self.showing=false; lib.hideTextUI() end
                return
            end
            if not self.showing then self.showing=true; lib.showTextUI('[E] Guardar veiculo nesta vaga') end
            if IsControlJustReleased(0,38) then
                self.showing=false
                lib.hideTextUI()
                storeCompanyVehicle(self.set)
            end
        end
        function point:onExit()
            if self.showing then self.showing=false; lib.hideTextUI() end
        end
        garagePoints[#garagePoints+1]=point
    end
end

-- ------------------------------------------------------------- desenho --

---@param list table[]
local function drawGarages(list)
    if type(list) == 'table' then lastList = list end

    drawGeneration = drawGeneration + 1
    local generation = drawGeneration
    clearAll()

    for i = 1, #lastList do
        local entry = lastList[i]

        -- Organizacao estatal: o atendente existe para todo mundo (delegacia
        -- tem recepcao). Job: o ped so e criado para quem e do set -- a
        -- garagem de uma empresa privada nao precisa existir para a cidade.
        -- Nos dois casos a INTERACAO fica com o filtro `groups` do target.
        if entry.publicPed or isMember(entry.set) then
        if isMember(entry.set) then createGaragePoints(entry) end
        local model = joaat(entry.model)

        CreateThread(function()
            if not lib.requestModel(model, 8000) then
                lib.print.warn(('nv_orgs: modelo de atendente "%s" nao carregou.'):format(entry.model))
                return
            end

            -- Uma sincronizacao mais nova chegou enquanto o modelo carregava.
            -- Nao crie um NPC que ja nasceu obsoleto.
            if generation~=drawGeneration then
                SetModelAsNoLongerNeeded(model)
                return
            end

            clearOrphans(entry,model)

            local ped = CreatePed(4, model, entry.coords.x, entry.coords.y, entry.coords.z - 1.0,
                entry.heading or 0.0, false, true)

            SetModelAsNoLongerNeeded(model)

            if not ped or ped == 0 then return end

            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)

            peds[ped] = entry.set

            -- Uma sincronizacao pode chegar entre a criacao e o registro do
            -- target. A entidade antiga nao deve sobreviver a ela.
            if generation~=drawGeneration or GetResourceState(GetCurrentResourceName())~='started' then
                peds[ped]=nil
                if DoesEntityExist(ped) then
                    SetEntityAsMissionEntity(ped,true,true)
                    DeleteEntity(ped)
                end
                return
            end
            local targets={
                {
                    name = ('nv_orgs_fleet_%s'):format(entry.set),
                    label = 'Frota da organizacao',
                    icon = 'fa-solid fa-warehouse',
                    distance = 2.5,
                    -- Filtro nativo do ox_target: quem nao e do set nao ve a
                    -- opcao, mesmo que o ped esteja visivel.
                    groups = { [entry.set] = 1 },
                    onSelect = function()
                        if GetResourceState('nv_garage')~='started' then
                            return Panel.notify('A garagem esta reiniciando. Tente novamente em alguns segundos.','error')
                        end
                        exports.nv_garage:OpenOrganization(entry.set)
                    end
                }
            }
            exports.ox_target:addLocalEntity(ped,targets)
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

-- No restart do resource o ox_target costuma ficar pronto antes de o ox_core
-- preencher o personagem local. Nesse intervalo `isMember` retorna falso e os
-- atendentes de empresas privadas nao sao desenhados. Refazemos a sincronizacao
-- quando o personagem termina de carregar, que e o momento em que os grupos ja
-- podem ser consultados com seguranca.
AddEventHandler('ox:playerLoaded', function()
    TriggerServerEvent('nv_orgs:requestGarages')
end)

AddEventHandler('ox:playerLogout', function()
    lastList = {}
    drawGeneration = drawGeneration + 1
    clearAll()
end)

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end

    -- Cobre tanto o start normal quanto um `restart nv_orgs` com o jogador ja
    -- conectado. Nao dependemos apenas do evento, pois ele pode ter ocorrido
    -- antes deste arquivo ser carregado.
    local deadline = GetGameTimer() + 15000
    while not Ox.GetPlayer().charId and GetGameTimer() < deadline do Wait(250) end
    TriggerServerEvent('nv_orgs:requestGarages')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        drawGeneration = drawGeneration + 1
        clearAll()
    end
end)
