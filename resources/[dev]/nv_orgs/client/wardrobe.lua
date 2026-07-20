--[[
    nv_orgs — cliente: vestiario

    Desenha os pontos e aplica a roupa.

    A roupa e aplicada com os exports de baixo nivel do illenium-appearance
    (`setPedComponents` / `setPedProps`). Nao passamos pelo sistema de "job
    outfits" dele porque o bridge dele para o ox_core esta por fazer -- ver o
    comentario no topo de server/wardrobe.lua.

    Voltar a roupa civil e um evento do proprio illenium
    (`illenium-appearance:client:reloadSkin`), que recarrega a aparencia salva
    do personagem. Isso e melhor do que guardarmos a roupa anterior: a nossa
    copia ficaria velha assim que o jogador trocasse de roupa em qualquer loja.
]]

---@type table<number, number>
local zones = {}

local function clearZones()
    for id, zone in pairs(zones) do
        pcall(function() exports.ox_target:removeZone(zone) end)
        zones[id] = nil
    end
end

--- Nome do modelo do corpo, para casar com o que foi salvo.
---@return string
local function pedModelName()
    local model = GetEntityModel(cache.ped)

    -- Os dois corpos do multiplayer cobrem a esmagadora maioria dos casos; o
    -- resto vira o hash em texto, que ainda casa consigo mesmo.
    if model == joaat('mp_m_freemode_01') then return 'mp_m_freemode_01' end
    if model == joaat('mp_f_freemode_01') then return 'mp_f_freemode_01' end

    return tostring(model)
end

---@param outfit table
local function applyOutfit(outfit)
    local ped = cache.ped

    local ok = pcall(function()
        if outfit.components then exports['illenium-appearance']:setPedComponents(ped, outfit.components) end
        if outfit.props then exports['illenium-appearance']:setPedProps(ped, outfit.props) end
    end)

    if not ok then
        return Panel.notify('Nao foi possivel vestir a roupa.', 'error')
    end

    Panel.notify('Uniforme vestido.', 'success')
end

--- Menu do vestiario.
---@param set string
local function openWardrobe(set)
    local outfits = lib.callback.await('nv_orgs:outfitsFor', false, set, pedModelName())

    if not outfits then
        return Panel.notify('Voce nao tem acesso a este vestiario.', 'error')
    end

    local options = {
        {
            title = 'Roupa civil',
            description = 'Volta para a sua roupa salva.',
            icon = 'fa-solid fa-shirt',
            onSelect = function()
                TriggerEvent('illenium-appearance:client:reloadSkin')
            end
        }
    }

    for i = 1, #outfits do
        local entry = outfits[i]

        options[#options + 1] = {
            title = entry.label,
            icon = 'fa-solid fa-user-tie',
            onSelect = function()
                applyOutfit(entry.outfit)
            end
        }
    end

    if #outfits == 0 then
        options[#options + 1] = {
            title = 'Nenhum uniforme disponivel',
            description = 'Ou o seu cargo nao libera nenhum, ou nao ha uniforme salvo para o seu corpo.',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'nv_orgs_wardrobe',
        title = 'Vestiario',
        options = options
    })

    lib.showContext('nv_orgs_wardrobe')
end

---@param list table[]
local function drawWardrobes(list)
    clearZones()

    if type(list) ~= 'table' then return end

    for i = 1, #list do
        local point = list[i]

        zones[point.id] = exports.ox_target:addBoxZone({
            coords = vec3(point.coords.x, point.coords.y, point.coords.z),
            size = vec3(1.8, 1.8, 2.0),
            rotation = 0,
            debug = false,
            options = {
                {
                    name = ('nv_orgs_wardrobe_%d'):format(point.id),
                    label = 'Vestiario',
                    icon = 'fa-solid fa-shirt',
                    distance = 2.0,
                    -- Filtro nativo: quem nao alcanca o cargo nao ve a opcao.
                    groups = { [point.set] = point.minGrade },
                    onSelect = function()
                        openWardrobe(point.set)
                    end
                }
            }
        })
    end
end

RegisterNetEvent('nv_orgs:wardrobes', drawWardrobes)

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end

    Wait(1500)
    TriggerServerEvent('nv_orgs:requestWardrobes')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearZones() end
end)

-- ------------------------------------------------- captura (admin) --

--- Le a roupa que o admin esta vestindo agora.
---
--- Exposto no `Panel` para o main.lua chamar quando o admin clicar em salvar.
---@return table?
function Panel.currentOutfit()
    local ped = cache.ped

    local ok, components = pcall(function()
        return exports['illenium-appearance']:getPedComponents(ped)
    end)

    if not ok or type(components) ~= 'table' then return end

    local gotProps, props = pcall(function()
        return exports['illenium-appearance']:getPedProps(ped)
    end)

    return {
        model      = pedModelName(),
        components = components,
        props      = gotProps and type(props) == 'table' and props or {}
    }
end
