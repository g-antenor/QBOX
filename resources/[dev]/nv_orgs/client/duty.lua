local dutyZones = {}
local servicePeds = {}

local function clearDutyClient()
    for _, zoneId in pairs(dutyZones) do
        pcall(function() exports.ox_target:removeZone(zoneId) end)
    end
    table.wipe(dutyZones)

    for _, ped in pairs(servicePeds) do
        if DoesEntityExist(ped) then
            pcall(function() exports.ox_target:removeLocalEntity(ped, 'nv_orgs_service_ped') end)
            DeleteEntity(ped)
        end
    end
    table.wipe(servicePeds)
end

RegisterNetEvent('nv_orgs:syncDutyPoints', function(cacheData)
    clearDutyClient()
    if type(cacheData) ~= 'table' then return end

    for set, data in pairs(cacheData) do
        if data.dutyPoint and type(data.dutyPoint) == 'table' then
            local p = data.dutyPoint
            local zoneId = exports.ox_target:addBoxZone({
                coords = vec3(p.x, p.y, p.z),
                size = vec3(1.5, 1.5, 2.0),
                rotation = p.w or 0.0,
                debug = false,
                options = {
                    {
                        name = 'nv_orgs_duty_' .. set,
                        icon = 'fa-solid fa-user-clock',
                        label = 'Bater Ponto',
                        groups = { [set] = 0 },
                        onSelect = function()
                            local ok, newDuty = lib.callback.await('nv_orgs:toggleDuty', false, set)
                            if ok then
                                if newDuty then
                                    lib.notify({ title = 'Serviço', description = 'Você entrou em serviço.', type = 'success' })
                                else
                                    lib.notify({ title = 'Serviço', description = 'Você saiu de serviço.', type = 'inform' })
                                end
                            end
                        end
                    }
                }
            })
            dutyZones[set] = zoneId
        end

        if data.servicePed and type(data.servicePed) == 'table' then
            local p = data.servicePed
            local model = lib.requestModel(`s_m_m_autoshop_01`) or lib.requestModel(`a_m_y_business_01`)
            if model then
                local ped = CreatePed(4, model, p.x, p.y, p.z, p.w or 0.0, false, false)
                PlaceObjectOnGroundProperly(ped)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetEntityCanBeDamaged(ped, false)
                SetPedCanRagdoll(ped, false)
                SetPedCanRagdollFromPlayerImpact(ped, false)
                SetPedCanBeTargetted(ped, false)
                SetBlockingOfNonTemporaryEvents(ped, true)

                exports.ox_target:addLocalEntity(ped, {
                    {
                        name = 'nv_orgs_service_ped',
                        icon = 'fa-solid fa-store',
                        label = 'Consultar Estoque',
                        onSelect = function()
                            TriggerEvent('nv_mdt:openGuest', set)
                        end
                    }
                })

                servicePeds[set] = ped
            end
        end
    end
end)

local pedVisibility = {}

local function setPedVisible(set, visible)
    pedVisibility[set] = visible
    local ped = servicePeds[set]
    if ped and DoesEntityExist(ped) then
        SetEntityVisible(ped, visible == true, false)
        if not visible then
            pcall(function() exports.ox_target:removeLocalEntity(ped, 'nv_orgs_service_ped') end)
        else
            pcall(function()
                exports.ox_target:addLocalEntity(ped, {
                    {
                        name = 'nv_orgs_service_ped',
                        icon = 'fa-solid fa-store',
                        label = 'Consultar Estoque',
                        onSelect = function()
                            TriggerEvent('nv_mdt:openGuest', set)
                        end
                    }
                })
            end)
        end
    end
end

RegisterNetEvent('nv_orgs:setServicePedVisibility', function(set, visible)
    setPedVisible(set, visible)
end)

exports('GetServicePed', function(set)
    return servicePeds[set]
end)

CreateThread(function()
    LocalPlayer.state:set('duty', false, true)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        LocalPlayer.state:set('duty', false, true)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        clearDutyClient()
    end
end)
