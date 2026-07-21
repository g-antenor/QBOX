local equipped=false
local toolboxProp
local activeOrder

local function deleteToolbox()
    if toolboxProp and DoesEntityExist(toolboxProp) then DeleteEntity(toolboxProp) end
    toolboxProp=nil
end

local function carryToolbox()
    deleteToolbox()
    local model=joaat('prop_tool_box_04')
    if not lib.requestModel(model,3000) then return end
    toolboxProp=CreateObject(model,0,0,0,true,true,false)
    AttachEntityToEntity(toolboxProp,cache.ped,GetPedBoneIndex(cache.ped,57005),0.18,0.02,-0.02,-90.0,0.0,80.0,true,true,false,true,1,true)
    lib.requestAnimDict('anim@heists@box_carry@')
    TaskPlayAnim(cache.ped,'anim@heists@box_carry@','idle',8.0,-8.0,-1,49,0,false,false,false)
end

exports('useToolbox',function()
    if equipped then
        equipped=false;deleteToolbox();ClearPedSecondaryTask(cache.ped)
        return lib.notify({description='Caixa de ferramentas guardada.',type='inform'})
    end
    if not lib.callback.await('nv_mechanic:toolboxAccess',false) then
        return lib.notify({description='Somente mecanicos podem usar esta ferramenta.',type='error'})
    end
    equipped=true;carryToolbox();lib.notify({description='Modo de inspecao ativado.',type='success'})
end)

local function percent(value,min,max)
    return math.floor(math.max(0,math.min(100,((value-min)/(max-min))*100))+0.5)
end

local function inspectState(vehicle)
    local mechanical=Entity(vehicle).state.nvMechanical or {}
    local body=percent(GetVehicleBodyHealth(vehicle),0,1000)
    local report={
        engine=math.min(percent(GetVehicleEngineHealth(vehicle),-4000,1000),100-math.floor((mechanical.engineWear or 0)/10)),
        body=body,hood=GetIsDoorValid(vehicle,4) and (IsVehicleDoorDamaged(vehicle,4) and 0 or body) or 100,
        trunk=GetIsDoorValid(vehicle,5) and (IsVehicleDoorDamaged(vehicle,5) and 0 or body) or 100,
        bumperF=IsVehicleBumperBrokenOff(vehicle,true) and 0 or body,
        bumperR=IsVehicleBumperBrokenOff(vehicle,false) and 0 or body,
        fuel=percent(GetVehiclePetrolTankHealth(vehicle),0,1000),
        transmission=math.max(0,100-math.floor(((mechanical.offroadSeconds or 0)/Config.Offroad.criticalSeconds)*100))
    }
    for i=0,3 do report['door'..i]=GetIsDoorValid(vehicle,i) and (IsVehicleDoorDamaged(vehicle,i) and 0 or body) or 100 end
    for i=0,1 do report['window'..i]=IsVehicleWindowIntact(vehicle,i) and 100 or 0 end
    local tyres=mechanical.tyres or {}
    for _,i in ipairs({0,1,4,5}) do
        local map=({[0]=1,[1]=2,[4]=3,[5]=4})[i]
        report['tyre'..i]=IsVehicleTyreBurst(vehicle,i,false) and 0 or tonumber(tyres[map]) or 100
    end
    return report
end

local function inspectVehicle(vehicle,final)
    if not DoesEntityExist(vehicle) then return end
    deleteToolbox();ClearPedTasks(cache.ped)
    SetVehicleDoorOpen(vehicle,4,false,false)
    local done=lib.progressCircle({duration=Config.WorkOrders.inspectDuration,label=final and 'Conferindo reparos' or 'Analisando veiculo',canCancel=true,
        disable={move=true,car=true,combat=true},anim={dict='mini@repair',clip='fixing_a_ped'}})
    SetVehicleDoorShut(vehicle,4,false)
    if not done then if equipped then carryToolbox() end return end
    if final then
        TriggerEvent('nv_mdt:openMechanicOrder',activeOrder)
        return
    end
    local ok,err,order=lib.callback.await('nv_mechanic:createInspection',false,VehToNet(vehicle),inspectState(vehicle))
    if not ok then if equipped then carryToolbox() end return lib.notify({description=err or 'Inspecao falhou.',type='error'}) end
    activeOrder=order;activeOrder.vehicle=vehicle
    TriggerEvent('nv_mdt:openMechanicOrder',order)
end

local animations={
    torch={scenario='WORLD_HUMAN_WELDING'},
    engine={dict='mini@repair',clip='fixing_a_ped'},body={dict='mini@repair',clip='fixing_a_ped'},
    tyre={dict='amb@medic@standing@kneel@base',clip='base'},
    under={dict='amb@world_human_vehicle_mechanic@male@base',clip='base'}
}

local function repairPart(vehicle,key)
    if not activeOrder then return end
    local ok,err,token,animation=lib.callback.await('nv_mechanic:beginOrderRepair',false,activeOrder.id,key)
    if not ok then return lib.notify({description=err or 'Reparo indisponivel.',type='error'}) end
    local done=lib.progressCircle({duration=8000,label=('Reparando %s'):format(Config.WorkOrders.parts[key].label),canCancel=true,
        disable={move=true,car=true,combat=true},anim=animations[animation] or animations.body})
    if not done then return end
    local finished,finishErr,order=lib.callback.await('nv_mechanic:finishOrderRepair',false,token)
    if not finished then return lib.notify({description=finishErr or 'Reparo falhou.',type='error'}) end
    activeOrder=order;activeOrder.vehicle=vehicle
    lib.notify({description='Peca reparada.',type='success'})
end

RegisterNetEvent('nv_mechanic:applyOrderPart',function(netId,key)
    local vehicle=NetToVeh(netId);if not DoesEntityExist(vehicle) then return end
    local spec=Config.WorkOrders.parts[key]
    if spec.door then SetVehicleDoorFixed(vehicle,spec.door)
    elseif spec.tyre then SetVehicleTyreFixed(vehicle,spec.tyre)
    elseif spec.window then FixVehicleWindow(vehicle,spec.window)
    elseif key=='hood' then SetVehicleDoorFixed(vehicle,4)
    elseif key=='trunk' then SetVehicleDoorFixed(vehicle,5)
    elseif key=='engine' then SetVehicleEngineHealth(vehicle,1000.0);SetVehicleUndriveable(vehicle,false)
    elseif key=='fuel' then SetVehiclePetrolTankHealth(vehicle,1000.0)
    elseif key=='body' or key=='bumperF' or key=='bumperR' then SetVehicleDeformationFixed(vehicle) end
end)

local partOffsets={
    engine=vec3(0.0,0.65,1.15),hood=vec3(0.0,1.45,0.82),bumperF=vec3(0.0,2.25,0.42),
    trunk=vec3(0.0,-1.35,0.92),bumperR=vec3(0.0,-2.15,0.42),body=vec3(0.0,0.0,1.42),
    door0=vec3(-1.0,0.72,0.82),door1=vec3(1.0,0.72,0.82),door2=vec3(-1.0,-0.72,0.82),door3=vec3(1.0,-0.72,0.82),
    window0=vec3(-0.72,0.48,1.35),window1=vec3(0.72,0.48,1.35),
    tyre0=vec3(-1.02,1.28,0.30),tyre1=vec3(1.02,1.28,0.30),tyre4=vec3(-1.02,-1.25,0.30),tyre5=vec3(1.02,-1.25,0.30),
    fuel=vec3(-0.72,-1.62,0.48),transmission=vec3(0.0,-0.12,0.42)
}
local function partPosition(vehicle,key)
    local min,max=GetModelDimensions(GetEntityModel(vehicle));local offset=partOffsets[key] or vec3(0.0,0.0,1.2)
    local halfWidth=math.max(0.8,(max.x-min.x)*0.5);local halfLength=math.max(1.5,(max.y-min.y)*0.5)
    local x=offset.x*halfWidth;local y=offset.y
    if math.abs(offset.y)>1.0 then y=(offset.y>0 and 1 or -1)*math.min(math.abs(offset.y),halfLength*.92) end
    return GetOffsetFromEntityInWorldCoords(vehicle,x,y,offset.z)
end
local function drawText(pos,text,color)
    local visible,x,y=World3dToScreen2d(pos.x,pos.y,pos.z);if not visible then return end
    local width=math.max(.035,#text*.0027)
    DrawRect(x,y+.012,width,.027,5,6,9,185)
    SetTextScale(.26,.26);SetTextFont(4);SetTextCentre(true);SetTextColour(color[1],color[2],color[3],235);SetTextOutline();BeginTextCommandDisplayText('STRING');AddTextComponentSubstringPlayerName(text);EndTextCommandDisplayText(x,y)
end

CreateThread(function()
    while true do
        if activeOrder and activeOrder.vehicle and DoesEntityExist(activeOrder.vehicle) then
            local vehicle=activeOrder.vehicle
            if #(GetEntityCoords(cache.ped)-GetEntityCoords(vehicle))<18.0 then
                for key,req in pairs(activeOrder.requirements or {}) do
                    local pos=partPosition(vehicle,key)
                    local done=activeOrder.completedParts and activeOrder.completedParts[key]
                    local text=done and ('OK - '..req.label) or (req.missing and ('Falta: '..req.label) or (('%s: %d%%'):format(req.label,req.percent)))
                    drawText(pos,text,done and {55,220,110} or {255,70,80})
                end
                Wait(0)
            else Wait(500) end
        else Wait(700) end
    end
end)

CreateThread(function()
    local options={{name='nv_mechanic_inspect',label='Inspecionar veiculo',icon='fa-solid fa-magnifying-glass',distance=2.5,
        canInteract=function() return equipped end,onSelect=function(data) inspectVehicle(data.entity,false) end},
        {name='nv_mechanic_finalize',label='Conferir e finalizar reparos',icon='fa-solid fa-clipboard-check',distance=2.5,
        canInteract=function(entity)
            if not activeOrder or activeOrder.vehicle~=entity or (activeOrder.status~='ready' and activeOrder.status~='in_progress') then return false end
            for _,done in pairs(activeOrder.completedParts or {}) do if done then return true end end
            return false
        end,onSelect=function(data) inspectVehicle(data.entity,true) end}}
    for key,spec in pairs(Config.WorkOrders.parts) do
        options[#options+1]={name='nv_mechanic_order_'..key,label='Reparar: '..spec.label,icon='fa-solid fa-screwdriver-wrench',distance=2.5,
            canInteract=function(entity) return activeOrder and activeOrder.status=='in_progress' and activeOrder.vehicle==entity and activeOrder.requirements[key] and not activeOrder.completedParts[key] end,
            onSelect=function(data) repairPart(data.entity,key) end}
    end
    exports.ox_target:addGlobalVehicle(options)
end)

RegisterNetEvent('nv_mechanic:orderState',function(order)
    activeOrder=order
    if activeOrder and activeOrder.netId then activeOrder.vehicle=NetToVeh(activeOrder.netId) end
end)
RegisterNetEvent('nv_mechanic:clearOrder',function() activeOrder=nil end)
AddEventHandler('onResourceStop',function(resource) if resource==GetCurrentResourceName() then deleteToolbox() end end)
