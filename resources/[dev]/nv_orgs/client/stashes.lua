--[[
    nv_orgs — cliente: targets dos baus

    O `RegisterStash` do servidor define QUEM pode abrir; este arquivo desenha
    ONDE se clica. Sao coisas separadas de proposito: o filtro de acesso mora
    no ox_inventory e vale mesmo que alguem force a abertura por outro caminho,
    enquanto o target e so a porta de entrada visivel.

    O `groups` da opcao de target usa o mesmo `{ set = grade minimo }`. O
    ox_target avalia isso nativamente (client/framework/ox.lua troca o
    `hasPlayerGotGroup` por `player.getGroup`), entao quem nao e da organizacao
    simplesmente nao ve a opcao.
]]

--- Zonas criadas, por nome do stash. Guardadas para poder remover na hora de
--- redesenhar -- sem isso cada sync empilharia zonas sobre as antigas.
---@type table<string, number>
local zones = {}

local function clearZones()
    for name, id in pairs(zones) do
        pcall(function() exports.ox_target:removeZone(id) end)
        zones[name] = nil
    end
end

--- Redesenha todos os targets de bau.
---@param list table[]
local function drawStashes(list)
    clearZones()

    if type(list) ~= 'table' then return end

    for i = 1, #list do
        local stash = list[i]

        if type(stash) == 'table' and type(stash.coords) == 'table' and stash.name then
            local id = exports.ox_target:addBoxZone({
                coords = vec3(stash.coords.x, stash.coords.y, stash.coords.z),
                size = vec3(Config.Stash.zoneSize, Config.Stash.zoneSize, 1.6),
                rotation = 0,
                debug = false,
                options = {
                    {
                        name = ('nv_orgs_stash_%s'):format(stash.name),
                        label = stash.label,
                        icon = 'fa-solid fa-box-archive',
                        distance = Config.Stash.targetDistance,
                        -- Filtro nativo do ox_target: quem nao alcanca o grade
                        -- minimo nao ve a opcao.
                        groups = { [stash.set] = stash.minGrade },
                        onSelect = function()
                            exports.ox_inventory:openInventory('stash', stash.name)
                        end
                    }
                }
            })

            zones[stash.name] = id
        end
    end
end

RegisterNetEvent('nv_orgs:stashes', drawStashes)

--- Pede a lista ao entrar. O evento de sync do servidor cobre as mudancas
--- feitas com o jogador ja online; esta chamada cobre quem acabou de conectar.
CreateThread(function()
    -- Espera o ox_target subir: registrar zona antes disso nao tem efeito.
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end

    Wait(1000)
    TriggerServerEvent('nv_orgs:requestStashes')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearZones() end
end)
