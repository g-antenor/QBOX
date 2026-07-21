local state = {}
local tracked, lastEngine, lastBody, lastSpeed
local airStarted, pendingAirDamage, lastAirTyre = nil, 0.0, 0
local lastRotation, rotationTravel, verticalStarted, fireDecision
local attached = {}

local function fresh()
    return { engineWear=0, bodyWear=0, offroadSeconds=0, tyres={100,100,100,100}, rollovers=0, engineFault=false, fireLevel=0 }
end

local function copyState(value)
    local out = fresh()
    if type(value) ~= 'table' then return out end
    for k,v in pairs(value) do if k ~= 'tyres' then out[k]=v end end
    if type(value.tyres)=='table' then for i=1,4 do out.tyres[i]=tonumber(value.tyres[i]) or 100 end end
    return out
end

local function tyreNative(i) return ({0,1,4,5})[i] end

local function applyMechanical(vehicle, data)
    if not DoesEntityExist(vehicle) then return end
    state = copyState(data)
    for i=1,4 do
        if state.tyres[i] <= Config.Tyres.burstAt and not IsVehicleTyreBurst(vehicle, tyreNative(i), false) then
            SetVehicleTyreBurst(vehicle, tyreNative(i), true, 1000.0)
        end
    end
    if state.engineFault then
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleUndriveable(vehicle, true)
    else
        SetVehicleUndriveable(vehicle, false)
    end
    if state.fireLevel > 0 and not IsEntityOnFire(vehicle) then StartEntityFire(vehicle) end
end

AddStateBagChangeHandler('nvMechanical', nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    CreateThread(function()
        local deadline=GetGameTimer()+5000
        while not DoesEntityExist(entity) and GetGameTimer()<deadline do Wait(50) end
        if DoesEntityExist(entity) then applyMechanical(entity, value) end
    end)
end)

exports('GetSnapshot', function(vehicle)
    vehicle = vehicle or cache.vehicle
    if vehicle and DoesEntityExist(vehicle) and Entity(vehicle).state.nvMechanical then
        state = copyState(Entity(vehicle).state.nvMechanical)
    end
    return copyState(state)
end)

local function save(vehicle)
    if vehicle and DoesEntityExist(vehicle) and NetworkGetEntityOwner(vehicle) == cache.playerId then
        TriggerServerEvent('nv_mechanic:save', VehToNet(vehicle), state)
    end
end

local function surfaceBelow(vehicle)
    local p=GetEntityCoords(vehicle)
    local ray=StartShapeTestRay(p.x,p.y,p.z+0.5,p.x,p.y,p.z-2.0,1,vehicle,7)
    local status,_,_,_,material
    repeat status,_,_,_,material=GetShapeTestResultIncludingMaterial(ray); if status==1 then Wait(0) end until status~=1
    return material
end

local function startFire(vehicle, level)
    if state.fireLevel >= level then return end
    state.fireLevel=level
    StartEntityFire(vehicle)
    fireDecision=GetGameTimer()+Config.Rollover.decisionSeconds*1000
    save(vehicle)
end

local function resetVehicle(vehicle)
    tracked=vehicle
    state=copyState(Entity(vehicle).state.nvMechanical)
    lastEngine=GetVehicleEngineHealth(vehicle)
    lastBody=GetVehicleBodyHealth(vehicle)
    lastSpeed=GetEntitySpeed(vehicle)
    airStarted=nil; pendingAirDamage=0; lastAirTyre=0
    lastRotation=GetEntityRotation(vehicle,2); rotationTravel=0; verticalStarted=nil; fireDecision=nil
    applyMechanical(vehicle,state)
end

local function angleDelta(a,b)
    local d=a-b
    if d>180 then d=d-360 elseif d < -180 then d=d+360 end
    return d
end

CreateThread(function()
    local lastSave=0
    while true do
        Wait(Config.UpdateInterval)
        local vehicle=cache.vehicle
        if not vehicle or cache.seat ~= -1 then tracked=nil goto continue end
        if vehicle ~= tracked then resetVehicle(vehicle) end
        if NetworkGetEntityOwner(vehicle) ~= cache.playerId then goto continue end

        local now=GetGameTimer()
        local speed=GetEntitySpeed(vehicle)
        local engine=GetVehicleEngineHealth(vehicle)
        local body=GetVehicleBodyHealth(vehicle)
        local class=GetVehicleClass(vehicle)

        -- Colisao: o dano adicional acompanha a perda nativa e a desaceleracao brusca.
        local impact=math.max(0,(lastSpeed-speed)*3.6)
        local nativeLoss=math.max(0,lastBody-body)
        if impact >= Config.Damage.minimumImpact and nativeLoss > 0.5 then
            local loss=math.min(Config.Damage.maximumEngineLoss,(impact+nativeLoss)*Config.Damage.collisionMultiplier)
            if class==8 or class==13 then loss=loss*Config.Damage.motorcycleMultiplier end
            SetVehicleEngineHealth(vehicle,engine-loss)
            state.engineWear=math.min(1000,state.engineWear+loss)
            state.bodyWear=math.min(1000,state.bodyWear+nativeLoss)
            engine=engine-loss
            -- Pancadas severas podem arrancar a peca do lado atingido. O
            -- snapshot nativo da garagem persiste exatamente esse indice.
            if impact >= 45.0 and nativeLoss >= 25.0 then
                local door=math.random(0,3)
                if GetIsDoorValid(vehicle,door) then SetVehicleDoorBroken(vehicle,door,true) end
                if math.random(100)<=45 then SmashVehicleWindow(vehicle,door) end
            end
        end

        -- Tempo no ar: um pneu por fracao do limite e dano de motor represado ate pousar.
        if IsEntityInAir(vehicle) and speed > 2.0 then
            airStarted=airStarted or now
            local seconds=(now-airStarted)/1000
            pendingAirDamage=math.max(pendingAirDamage,seconds*Config.Airborne.engineDamagePerSecond)
            local wanted=math.min(4,math.floor(seconds/(Config.Airborne.allTyresSeconds/4)))
            while lastAirTyre < wanted do
                lastAirTyre=lastAirTyre+1
                state.tyres[lastAirTyre]=0
                SetVehicleTyreBurst(vehicle,tyreNative(lastAirTyre),true,1000.0)
            end
        elseif airStarted then
            local seconds=(now-airStarted)/1000
            if seconds >= Config.Airborne.graceSeconds then
                local vertical=math.abs(GetEntityVelocity(vehicle).z)
                local loss=pendingAirDamage+vertical*Config.Airborne.landingVerticalMultiplier
                SetVehicleEngineHealth(vehicle,GetVehicleEngineHealth(vehicle)-loss)
                state.engineWear=math.min(1000,state.engineWear+loss)
            end
            airStarted=nil; pendingAirDamage=0; lastAirTyre=0
        end

        -- Terra e uso dos pneus. Classe off-road e isenta; o contador e acumulativo.
        if speed >= Config.Offroad.minimumSpeed and not Config.Offroad.offroadClasses[class] then
            local material=surfaceBelow(vehicle)
            if material and not Config.Offroad.roadMaterials[material] then
                state.offroadSeconds=math.min(Config.Offroad.criticalSeconds,state.offroadSeconds+Config.UpdateInterval/1000)
                for i=1,4 do state.tyres[i]=math.max(0,state.tyres[i]-Config.Offroad.tyreWearPerSecond*Config.UpdateInterval/1000) end
                if state.offroadSeconds >= Config.Offroad.criticalSeconds then
                    state.engineFault=true
                    SetVehicleEngineHealth(vehicle,0.0)
                    engine=0.0
                end
            end
        end
        local km=speed*(Config.UpdateInterval/1000)/1000
        for i=1,4 do state.tyres[i]=math.max(0,state.tyres[i]-km*Config.Tyres.normalWearPerKm) end

        -- Voltas completas acumuladas no mesmo acidente.
        local rot=GetEntityRotation(vehicle,2)
        rotationTravel=rotationTravel+math.abs(angleDelta(rot.y,lastRotation.y))+math.abs(angleDelta(rot.x,lastRotation.x))
        lastRotation=rot
        if rotationTravel>=360 then
            local turns=math.floor(rotationTravel/360); rotationTravel=rotationTravel%360
            state.rollovers=math.min(255,state.rollovers+turns)
            if state.rollovers>=Config.Rollover.fireAfter then startFire(vehicle,state.rollovers>=Config.Rollover.extraDangerAfter and 2 or 1) end
        elseif IsVehicleOnAllWheels(vehicle) and speed<1.0 then rotationTravel=math.max(0,rotationTravel-30) end

        local pitch=math.abs(rot.x)
        if pitch>=Config.Vertical.angle and not Entity(vehicle).state.nvOnLift then
            verticalStarted=verticalStarted or now
            if now-verticalStarted>=Config.Vertical.seconds*1000 then startFire(vehicle,2) end
        else verticalStarted=nil end

        if fireDecision and now>=fireDecision then
            local chance=state.fireLevel>=2 and Config.Rollover.extraExplosionChance or Config.Rollover.baseExplosionChance
            if math.random(100)<=chance then TriggerServerEvent('nv_mechanic:explode',VehToNet(vehicle)) end
            fireDecision=nil
        end
        if state.engineFault or engine<=Config.Damage.stopEngineAt then
            SetVehicleEngineOn(vehicle,false,true,true); SetVehicleUndriveable(vehicle,true)
        end
        if now-lastSave>=Config.SaveInterval then save(vehicle); lastSave=now end
        lastEngine=engine; lastBody=body; lastSpeed=speed
        ::continue::
    end
end)

RegisterNetEvent('nv_mechanic:explodeClient',function(netId)
    local vehicle=NetToVeh(netId)
    if DoesEntityExist(vehicle) and NetworkGetEntityOwner(vehicle)==cache.playerId then NetworkExplodeVehicle(vehicle,true,false,false) end
end)

RegisterNetEvent('nv_mechanic:stopFire',function(netId)
    local vehicle=NetToVeh(netId)
    if DoesEntityExist(vehicle) then StopEntityFire(vehicle) end
end)

exports('useExtinguisher',function()
    local vehicle=lib.getClosestVehicle(GetEntityCoords(cache.ped),3.5,false)
    if not vehicle or not IsEntityOnFire(vehicle) then return lib.notify({description='Nenhum motor em chamas por perto.',type='error'}) end
    local done=lib.progressCircle({duration=5000,label='Apagando incendio',canCancel=true,disable={combat=true},
        anim={dict='weapons@first_person@aim_rng@generic@projectile@thermal_charge@',clip='plant_floor'}})
    if done then TriggerServerEvent('nv_mechanic:extinguish',VehToNet(vehicle)) end
end)

RegisterNetEvent('nv_mechanic:applyRepair',function(netId,kind,index)
    local vehicle=NetToVeh(netId); index=tonumber(index)
    if not DoesEntityExist(vehicle) then return end
    if kind=='engine' or kind=='offroad' then SetVehicleEngineHealth(vehicle,1000.0); SetVehicleUndriveable(vehicle,false)
    elseif kind=='body' then SetVehicleBodyHealth(vehicle,1000.0); SetVehicleDeformationFixed(vehicle)
    elseif kind=='tyre' and index then SetVehicleTyreFixed(vehicle,index)
    elseif kind=='door' and index then SetVehicleDoorFixed(vehicle,index)
    elseif kind=='hood' then SetVehicleDoorFixed(vehicle,4)
    elseif kind=='trunk' then SetVehicleDoorFixed(vehicle,5)
    elseif kind=='window' and index then FixVehicleWindow(vehicle,index) end
end)

local function nearestComponent(vehicle,kind)
    local p=GetEntityCoords(cache.ped)
    local choices=kind=='tyre' and {{'wheel_lf',0},{'wheel_rf',1},{'wheel_lr',4},{'wheel_rr',5}}
        or kind=='door' and {{'door_dside_f',0},{'door_pside_f',1},{'door_dside_r',2},{'door_pside_r',3}}
        or kind=='window' and {{'window_lf',0},{'window_rf',1},{'window_lr',2},{'window_rr',3}}
    if not choices then return end
    local best,bestDist
    for _,v in ipairs(choices) do
        local bone=GetEntityBoneIndexByName(vehicle,v[1])
        if bone~=-1 then local d=#(p-GetWorldPositionOfEntityBone(vehicle,bone)); if not bestDist or d<bestDist then bestDist=d;best=v[2] end end
    end
    return best,bestDist
end

local function damaged(vehicle,kind,index)
    if kind=='engine' then return GetVehicleEngineHealth(vehicle)<950 or state.engineFault end
    if kind=='offroad' then return state.offroadSeconds>0 end
    if kind=='body' then return GetVehicleBodyHealth(vehicle)<950 end
    if kind=='tyre' then return index and IsVehicleTyreBurst(vehicle,index,false) end
    if kind=='door' then return index and IsVehicleDoorDamaged(vehicle,index) end
    if kind=='hood' then return GetIsDoorValid(vehicle,4) and IsVehicleDoorDamaged(vehicle,4) end
    if kind=='trunk' then return GetIsDoorValid(vehicle,5) and IsVehicleDoorDamaged(vehicle,5) end
    if kind=='window' then return index and not IsVehicleWindowIntact(vehicle,index) end
end

-- Guincho tradicional e plataforma. O motorista do guincho controla a anexacao.
RegisterCommand('reboque',function()
    local tow=cache.vehicle
    if not tow or cache.seat~=-1 or not Config.TowModels[GetEntityModel(tow)] then return end
    if not lib.callback.await('nv_mechanic:isMechanic',false) then
        return lib.notify({description='Somente membros de uma mecanica podem operar o reboque.',type='error'})
    end
    local cfg=Config.TowModels[GetEntityModel(tow)]
    if attached[tow] and DoesEntityExist(attached[tow]) then DetachEntity(attached[tow],true,true); attached[tow]=nil; return end
    local coords=GetOffsetFromEntityInWorldCoords(tow,0.0,-5.0,0.0)
    local target=lib.getClosestVehicle(coords,5.0,false)
    if not target or target==tow then return end
    if cfg.type=='hook' then AttachVehicleToTowTruck(tow,target,false,0.0,0.0,0.0)
    else AttachEntityToEntity(target,tow,0,cfg.offset.x,cfg.offset.y,cfg.offset.z,0.0,0.0,0.0,false,false,true,false,2,true) end
    attached[tow]=target
end,false)
