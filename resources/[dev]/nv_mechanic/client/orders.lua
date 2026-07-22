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
    local explicitWindows=Entity(vehicle).state.nvBrokenWindows or {}
    for i=0,1 do
        -- Uma porta arrancada faz o native informar o vidro como quebrado
        -- mesmo quando ele estava inteiro. So contamos o vidro se ele foi
        -- realmente quebrado ou se a porta ainda esta instalada.
        local explicitlyBroken=explicitWindows[tostring(i)]==true or explicitWindows[i]==true
        local broken=explicitlyBroken or (not IsVehicleDoorDamaged(vehicle,i) and not IsVehicleWindowIntact(vehicle,i))
        report['window'..i]=broken and 0 or 100
    end
    report.windshield=GetEntityBoneIndexByName(vehicle,'windscreen')~=-1 and (IsVehicleWindowIntact(vehicle,6) and 100 or 0) or 100
    report.rearWindow=GetEntityBoneIndexByName(vehicle,'windscreen_r')~=-1 and (IsVehicleWindowIntact(vehicle,7) and 100 or 0) or 100
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
    -- A toolbox foi usada nesta inspecao e o modo termina aqui. Para exibir
    -- "Inspecionar veiculo" novamente e necessario usar o item outra vez.
    if not final then equipped=false end
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
    -- Trabalhos sob o carro devem comecar com o mecanico olhando para o
    -- centro do veiculo, para a animacao avancar para baixo dele e nao
    -- atravessar lateralmente a carroceria.
    if animation=='under' then
        local center=GetEntityCoords(vehicle)
        TaskTurnPedToFaceCoord(cache.ped,center.x,center.y,center.z,650)
        Wait(650)
    end
    local done=lib.progressCircle({duration=8000,label=('Reparando %s'):format(Config.WorkOrders.parts[key].label),canCancel=true,
        disable={move=true,car=true,combat=true},anim=animations[animation] or animations.body})
    if not done then return end
    local finished,finishErr,order=lib.callback.await('nv_mechanic:finishOrderRepair',false,token)
    if not finished then return lib.notify({description=finishErr or 'Reparo falhou.',type='error'}) end
    activeOrder=order;activeOrder.vehicle=vehicle
    -- No MDT a conclusao parcial continua permitida: uma unica peca reparada
    -- ja atualiza a ordem e libera a acao de concluir/cobrar.
    TriggerEvent('nv_mdt:updateMechanicOrder',order)
    lib.notify({description='Peca reparada.',type='success'})
end

-- O FiveM nao possui o native SetVehicleDoorFixed. Para recolocar uma porta
-- arrancada, o veiculo precisa ser corrigido e os demais danos reaplicados.
function RestoreMechanicVehicleDoor(vehicle, doorIndex)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local tankHealth = GetVehiclePetrolTankHealth(vehicle)
    local dirtLevel = GetVehicleDirtLevel(vehicle)
    local damagedDoors, burstTyres, brokenWindows = {}, {}, {}

    for index = 0, 5 do damagedDoors[index] = index ~= doorIndex and IsVehicleDoorDamaged(vehicle, index) end
    for _, index in ipairs({ 0, 1, 2, 3, 4, 5 }) do burstTyres[index] = IsVehicleTyreBurst(vehicle, index, false) end
    for index = 0, 7 do
        -- Portas 0-3 usam o mesmo indice para o respectivo vidro. Quando a
        -- porta esta arrancada, o jogo informa esse vidro como quebrado; ele
        -- nao deve ser quebrado novamente depois que a porta nova aparecer.
        local belongsToInstalledDoor = doorIndex <= 3 and index == doorIndex
        brokenWindows[index] = not belongsToInstalledDoor and not IsVehicleWindowIntact(vehicle, index)
    end

    local frontBumper = IsVehicleBumperBrokenOff(vehicle, true)
    local rearBumper = IsVehicleBumperBrokenOff(vehicle, false)

    SetVehicleFixed(vehicle)
    SetVehicleEngineHealth(vehicle, engineHealth)
    SetVehicleBodyHealth(vehicle, bodyHealth)
    SetVehiclePetrolTankHealth(vehicle, tankHealth)
    SetVehicleDirtLevel(vehicle, dirtLevel)

    for index = 0, 5 do
        if damagedDoors[index] then SetVehicleDoorBroken(vehicle, index, true) end
    end
    for index, broken in pairs(burstTyres) do
        if broken then SetVehicleTyreBurst(vehicle, index, true, 1000.0) end
    end
    for index = 0, 7 do
        if brokenWindows[index] then SmashVehicleWindow(vehicle, index) end
    end
    if frontBumper then SetVehicleBumperBrokenOff(vehicle, true, true) end
    if rearBumper then SetVehicleBumperBrokenOff(vehicle, false, true) end

    -- Fecha sem o modo instantaneo para evitar o efeito seco de a peca surgir.
    SetVehicleDoorOpen(vehicle, doorIndex, false, true)
    Wait(50)
    SetVehicleDoorShut(vehicle, doorIndex, false)
end

RegisterNetEvent('nv_mechanic:applyOrderPart',function(netId,key)
    local vehicle=NetToVeh(netId);if not DoesEntityExist(vehicle) then return end
    local spec=Config.WorkOrders.parts[key]
    if spec.door then RestoreMechanicVehicleDoor(vehicle,spec.door)
    elseif spec.tyre then SetVehicleTyreFixed(vehicle,spec.tyre)
    elseif spec.window then
        FixVehicleWindow(vehicle,spec.window)
        local broken=Entity(vehicle).state.nvBrokenWindows or {};broken[tostring(spec.window)]=nil;broken[spec.window]=nil
        Entity(vehicle).state:set('nvBrokenWindows',broken,true)
    elseif key=='hood' then RestoreMechanicVehicleDoor(vehicle,4)
    elseif key=='trunk' then RestoreMechanicVehicleDoor(vehicle,5)
    elseif key=='engine' then SetVehicleEngineHealth(vehicle,1000.0);SetVehicleUndriveable(vehicle,false)
    elseif key=='fuel' then SetVehiclePetrolTankHealth(vehicle,1000.0)
    elseif key=='body' or key=='bumperF' or key=='bumperR' then SetVehicleDeformationFixed(vehicle) end
end)

-- Memoriza um vidro quebrado enquanto a porta ainda existe. Assim, se ela for
-- arrancada depois, a inspecao consegue distinguir "porta" de "porta+vidro".
CreateThread(function()
    while true do
        local vehicle=cache.vehicle
        if vehicle and vehicle~=0 then
            local broken=Entity(vehicle).state.nvBrokenWindows or {};local changed=false
            for i=0,1 do
                if not IsVehicleDoorDamaged(vehicle,i) and not IsVehicleWindowIntact(vehicle,i) and not broken[tostring(i)] then
                    broken[tostring(i)]=true;changed=true
                end
            end
            if changed then Entity(vehicle).state:set('nvBrokenWindows',broken,true) end
        end
        Wait(750)
    end
end)

RegisterNetEvent('nv_mechanic:finalizeVehicle',function(netId)
    local vehicle=NetToVeh(netId)
    if not DoesEntityExist(vehicle) then return end

    local deadline=GetGameTimer()+2000
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer()<deadline do
        NetworkRequestControlOfEntity(vehicle)
        Wait(0)
    end

    StopEntityFire(vehicle)
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleEngineHealth(vehicle,1000.0)
    SetVehicleBodyHealth(vehicle,1000.0)
    SetVehiclePetrolTankHealth(vehicle,1000.0)
    SetVehicleUndriveable(vehicle,false)
    for _,index in ipairs({0,1,2,3,4,5}) do SetVehicleTyreFixed(vehicle,index) end
    for index=0,7 do FixVehicleWindow(vehicle,index) end
end)

local partOffsets={
    engine=vec3(0.0,0.65,1.15),hood=vec3(0.0,1.45,0.82),bumperF=vec3(0.0,2.25,0.42),
    trunk=vec3(0.0,-1.35,0.92),bumperR=vec3(0.0,-2.15,0.42),body=vec3(0.0,0.0,1.42),
    door0=vec3(-1.0,0.72,0.82),door1=vec3(1.0,0.72,0.82),door2=vec3(-1.0,-0.72,0.82),door3=vec3(1.0,-0.72,0.82),
    window0=vec3(-0.72,0.48,1.35),window1=vec3(0.72,0.48,1.35),
    windshield=vec3(0.0,0.72,1.48),rearWindow=vec3(0.0,-0.72,1.42),
    tyre0=vec3(-1.02,1.28,0.30),tyre1=vec3(1.02,1.28,0.30),tyre4=vec3(-1.02,-1.25,0.30),tyre5=vec3(1.02,-1.25,0.30),
    fuel=vec3(-0.72,-1.62,0.48),transmission=vec3(0.0,-0.12,0.42)
}
local function partPosition(vehicle,key)
    local min,max=GetModelDimensions(GetEntityModel(vehicle));local offset=partOffsets[key] or vec3(0.0,0.0,1.2)
    local halfWidth=math.max(0.8,(max.x-min.x)*0.5);local halfLength=math.max(1.5,(max.y-min.y)*0.5)
    local x=offset.x*halfWidth;local y=offset.y
    if math.abs(offset.y)>1.0 then y=(offset.y>0 and 1 or -1)*math.min(math.abs(offset.y),halfLength*.92) end
    -- Combustivel e transmissao acompanham a parte inferior de cada modelo,
    -- em vez de usar uma altura fixa que pode cair no meio da carroceria.
    local z=(key=='fuel' or key=='transmission') and (min.z+.12) or offset.z
    return GetOffsetFromEntityInWorldCoords(vehicle,x,y,z)
end

local function allRepairsCompleted()
    if not activeOrder or not next(activeOrder.requirements or {}) then return false end
    for key in pairs(activeOrder.requirements) do
        if not (activeOrder.completedParts and activeOrder.completedParts[key]) then return false end
    end
    return true
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
                    local text=done and ('OK - '..req.label) or (req.missing and ('Falta: '..req.label) or (('%s: %d%%'):format(req.label,math.floor(tonumber(req.percent) or 0))))
                    drawText(pos,text,done and {55,220,110} or {255,70,80})
                end
                Wait(0)
            else Wait(500) end
        else Wait(700) end
    end
end)

-- O carro e dividido em seis setores ao redor da carroceria. A opcao depende
-- de onde o mecanico esta, e nao de um bone que pode desaparecer junto com a
-- peca. Isso permite instalar portas arrancadas e continua separando os lados.
local partSector={
    engine='front',hood='front',bumperF='front',windshield='front',
    door1='frontRight',window1='frontRight',tyre1='frontRight',
    door3='rearRight',tyre5='rearRight',
    trunk='rear',bumperR='rear',transmission='rear',rearWindow='rear',
    door2='rearLeft',tyre4='rearLeft',fuel='rearLeft',
    door0='frontLeft',window0='frontLeft',tyre0='frontLeft'
}

local function mechanicSector(vehicle)
    local min,max=GetModelDimensions(GetEntityModel(vehicle))
    local z=math.max(.35,math.min(.7,(max.z-min.z)*.38))
    local anchors={
        front=vec3(0.0,max.y+.12,z),
        frontRight=vec3(max.x+.10,max.y*.38,z),
        rearRight=vec3(max.x+.10,min.y*.38,z),
        rear=vec3(0.0,min.y-.12,z),
        rearLeft=vec3(min.x-.10,min.y*.38,z),
        frontLeft=vec3(min.x-.10,max.y*.38,z)
    }
    local player=GetEntityCoords(cache.ped)
    local closest,closestDistance
    for name,offset in pairs(anchors) do
        local world=GetOffsetFromEntityInWorldCoords(vehicle,offset.x,offset.y,offset.z)
        local distance=#(player-world)
        if not closestDistance or distance<closestDistance then closest,closestDistance=name,distance end
    end
    -- Obriga o mecanico a estar junto da parte correspondente.
    return closestDistance and closestDistance<=1.45 and closest or nil
end

CreateThread(function()
    local options={{name='nv_mechanic_inspect',label='Inspecionar veiculo',icon='fa-solid fa-magnifying-glass',distance=2.5,
        canInteract=function() return equipped and toolboxProp and DoesEntityExist(toolboxProp) end,onSelect=function(data) inspectVehicle(data.entity,false) end},
        {name='nv_mechanic_finalize',label='Conferir e finalizar reparos',icon='fa-solid fa-clipboard-check',distance=2.5,
        canInteract=function(entity)
            return activeOrder and activeOrder.vehicle==entity and activeOrder.status=='ready' and allRepairsCompleted()
        end,onSelect=function(data) inspectVehicle(data.entity,true) end}}
    for key,spec in pairs(Config.WorkOrders.parts) do
        local partKey=key
        options[#options+1]={name='nv_mechanic_order_'..partKey,label='Reparar: '..spec.label,icon='fa-solid fa-screwdriver-wrench',distance=1.7,
            canInteract=function(entity)
                local sector=mechanicSector(entity)
                return activeOrder and activeOrder.status=='in_progress' and activeOrder.vehicle==entity
                    and activeOrder.requirements[partKey]
                    and not (activeOrder.completedParts and activeOrder.completedParts[partKey])
                    and sector and (partKey=='body' or partSector[partKey]==sector)
            end,
            onSelect=function(data) repairPart(data.entity,partKey) end}
    end
    exports.ox_target:addGlobalVehicle(options)
end)

RegisterNetEvent('nv_mechanic:orderState',function(order)
    activeOrder=order
    if activeOrder and activeOrder.netId then activeOrder.vehicle=NetToVeh(activeOrder.netId) end
end)
RegisterNetEvent('nv_mechanic:clearOrder',function() activeOrder=nil end)
AddEventHandler('onResourceStop',function(resource) if resource==GetCurrentResourceName() then deleteToolbox() end end)
