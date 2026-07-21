local Ox = require '@ox_core.lib.init'
local active = {}
local ready = false

CreateThread(function()
    ready = pcall(MySQL.query.await, [[CREATE TABLE IF NOT EXISTS `nv_mechanic_orders` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `orgSet` VARCHAR(20) NOT NULL,
        `plate` VARCHAR(16) NOT NULL,
        `model` VARCHAR(60) NOT NULL,
        `vin` VARCHAR(32) NULL,
        `netId` INT UNSIGNED NULL,
        `mechanicCharId` INT UNSIGNED NOT NULL,
        `mechanic` VARCHAR(100) NOT NULL,
        `customerCharId` INT UNSIGNED NULL,
        `status` VARCHAR(24) NOT NULL DEFAULT 'draft',
        `inspection` LONGTEXT NOT NULL,
        `requirements` LONGTEXT NOT NULL,
        `completedParts` LONGTEXT NOT NULL,
        `total` INT UNSIGNED NOT NULL DEFAULT 0,
        `payment` VARCHAR(20) NULL,
        `invoiceId` INT UNSIGNED NULL,
        `cancelReason` VARCHAR(255) NULL,
        `created` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        `finished` DATETIME NULL,
        PRIMARY KEY (`id`), KEY `nv_mechanic_orders_org` (`orgSet`,`status`),
        KEY `nv_mechanic_orders_plate` (`plate`)
    )]])
    if not ready then
        lib.print.error('Nao foi possivel criar nv_mechanic_orders.')
        return
    end

    -- Mantem ordens criadas antes da remocao de engine_parts utilizaveis.
    local migrated = pcall(MySQL.update.await, [[UPDATE `nv_mechanic_orders`
        SET `requirements` = REPLACE(`requirements`, 'engine_parts', 'sheet_metal')
        WHERE `requirements` LIKE '%engine_parts%']])

    if not migrated then
        lib.print.error('Nao foi possivel migrar engine_parts para sheet_metal nas ordens existentes.')
    end
end)

local function decode(value)
    if type(value) == 'table' then return value end
    local ok, data = pcall(json.decode, value or '{}')
    return ok and type(data) == 'table' and data or {}
end

local function mechanicOrg(source)
    local player = Ox.GetPlayer(source)
    if not player then return end
    local row = MySQL.single.await([[SELECT g.`name` AS `set`,g.`label` FROM `character_groups` cg
        JOIN `ox_groups` g ON g.`name`=cg.`name`
        JOIN `nv_org_subtype` s ON s.`group`=g.`name` AND s.`subtype`=?
        WHERE cg.`charId`=? LIMIT 1]], { Config.MechanicSubtype, player.charId })
    return row, player
end

local function entityFromNet(netId)
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if entity == 0 or not DoesEntityExist(entity) then return end
    return entity
end

local function nearby(source, entity)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and entity and #(GetEntityCoords(ped)-GetEntityCoords(entity)) <= Config.WorkOrders.repairDistance
end

local function rowData(row)
    if not row then return end
    row.inspection=decode(row.inspection);row.requirements=decode(row.requirements);row.completedParts=decode(row.completedParts)
    return row
end

local function getOrder(id)
    return rowData(MySQL.single.await([[SELECT *,DATE_FORMAT(`created`,'%d/%m/%Y %H:%i') AS createdLabel,
        DATE_FORMAT(`finished`,'%d/%m/%Y %H:%i') AS finishedLabel FROM `nv_mechanic_orders` WHERE `id`=?]], { tonumber(id) }))
end

local function requirements(report)
    local needed, total = {}, 0
    for key, spec in pairs(Config.WorkOrders.parts) do
        local value = tonumber(report[key]) or 100
        if value < 99.5 then
            needed[key] = { label=spec.label,item=spec.item,amount=spec.amount,tool=spec.tool,
                value=spec.value,animation=spec.animation,missing=value <= 0,percent=value }
            total = total + spec.value
        end
    end
    return needed, total
end

lib.callback.register('nv_mechanic:toolboxAccess', function(source)
    local org = mechanicOrg(source)
    return org ~= nil and (exports.ox_inventory:GetItemCount(source, Config.WorkOrders.toolbox) or 0) > 0
end)

lib.callback.register('nv_mechanic:createInspection', function(source, netId, raw)
    while not ready do Wait(50) end
    local org, player = mechanicOrg(source)
    local entity = entityFromNet(netId)
    if not org or not player or not nearby(source,entity) then return false,'Sem permissao ou longe do veiculo.' end
    if (exports.ox_inventory:GetItemCount(source,Config.WorkOrders.toolbox) or 0)<1 then return false,'Falta caixa de ferramentas.' end
    if type(raw)~='table' then return false,'Inspecao invalida.' end
    local report={}
    for key in pairs(Config.WorkOrders.parts) do report[key]=math.min(100,math.max(0,tonumber(raw[key]) or 100)) end
    local plate=(GetVehicleNumberPlateText(entity) or 'SEMPLACA'):gsub('^%s+',''):gsub('%s+$','')
    local model=tostring(GetEntityModel(entity));local req,total=requirements(report)
    local existing=MySQL.single.await([[SELECT `id` FROM `nv_mechanic_orders` WHERE `orgSet`=? AND `plate`=?
        AND `model`=? AND `status` IN ('draft','in_progress','ready','awaiting_payment') ORDER BY `id` DESC LIMIT 1]],{org.set,plate,model})
    local id
    if existing then
        id=existing.id
        MySQL.update.await([[UPDATE `nv_mechanic_orders` SET `netId`=?,`inspection`=?,`requirements`=?,`total`=?,
            `mechanicCharId`=?,`mechanic`=? WHERE `id`=?]],{netId,json.encode(report),json.encode(req),total,player.charId,GetPlayerName(source) or ('ID '..source),id})
    else
        id=MySQL.insert.await([[INSERT INTO `nv_mechanic_orders`
            (`orgSet`,`plate`,`model`,`netId`,`mechanicCharId`,`mechanic`,`inspection`,`requirements`,`completedParts`,`total`)
            VALUES (?,?,?,?,?,?,?,?,?,?)]],{org.set,plate,model,netId,player.charId,GetPlayerName(source) or ('ID '..source),json.encode(report),json.encode(req),'{}',total})
    end
    return true,nil,getOrder(id)
end)

local function orderFor(source,id)
    local org,player=mechanicOrg(source);if not org then return end
    local order=getOrder(id);if not order or order.orgSet~=org.set then return end
    return order,player,org
end

-- Portas dianteiras carregam seus respectivos vidros. Se o diagnostico
-- marcou os dois como quebrados, a troca usa ambos os materiais e conclui os
-- dois componentes. Se apenas a porta quebrou, nenhum vidro e cobrado.
local doorWindows={door0='window0',door1='window1'}

lib.callback.register('nv_mechanic:beginOrderRepair', function(source,id,key)
    local order=orderFor(source,id);local spec=Config.WorkOrders.parts[key]
    if not order or order.status~='in_progress' or not spec or not order.requirements[key] or order.completedParts[key] then return false,'Reparo indisponivel.' end
    local entity=entityFromNet(order.netId);if not nearby(source,entity) then return false,'Aproxime-se do veiculo.' end
    if (exports.ox_inventory:GetItemCount(source,spec.item) or 0)<spec.amount then return false,('Falta %s.'):format(spec.label) end
    local windowKey=doorWindows[key]
    if windowKey and order.requirements[windowKey] and not order.completedParts[windowKey] then
        local glass=Config.WorkOrders.parts[windowKey]
        if (exports.ox_inventory:GetItemCount(source,glass.item) or 0)<glass.amount then return false,('Falta %s.'):format(glass.label) end
    end
    if spec.tool and (exports.ox_inventory:GetItemCount(source,spec.tool) or 0)<1 then return false,('Falta ferramenta: %s.'):format(spec.tool) end
    local token=('%s:%s'):format(id,key);if active[token] then return false,'Peca em reparo.' end
    active[token]={source=source,id=tonumber(id),key=key,expires=os.time()+120};return true,nil,token,spec.animation
end)

local function useTool(source,name,wear)
    local slots=exports.ox_inventory:GetInventoryItems(source) or {}
    for _,slot in pairs(slots) do
        if slot.name==name and slot.metadata and slot.metadata.durability then
            local durability=tonumber(slot.metadata.durability) or 0
            if durability>100 then durability=100 end
            if durability<wear then return false end
            exports.ox_inventory:SetDurability(source,slot.slot,math.max(0,durability-wear));return true
        end
    end
    return exports.ox_inventory:RemoveItem(source,name,1)==true
end

lib.callback.register('nv_mechanic:finishOrderRepair', function(source,token)
    local job=active[token];active[token]=nil
    if not job or job.source~=source or job.expires<os.time() then return false,'Reparo expirou.' end
    local order=orderFor(source,job.id);local spec=Config.WorkOrders.parts[job.key]
    local entity=order and entityFromNet(order.netId);if not order or not nearby(source,entity) then return false,'Veiculo indisponivel.' end
    if not exports.ox_inventory:RemoveItem(source,spec.item,spec.amount) then return false,'Material indisponivel.' end
    local windowKey=doorWindows[job.key]
    local glass=windowKey and order.requirements[windowKey] and not order.completedParts[windowKey] and Config.WorkOrders.parts[windowKey] or nil
    if glass and not exports.ox_inventory:RemoveItem(source,glass.item,glass.amount) then
        exports.ox_inventory:AddItem(source,spec.item,spec.amount);return false,'Vidro automotivo indisponivel.'
    end
    if spec.tool and not useTool(source,spec.tool,5) then
        exports.ox_inventory:AddItem(source,spec.item,spec.amount)
        if glass then exports.ox_inventory:AddItem(source,glass.item,glass.amount) end
        return false,'Ferramenta sem durabilidade.'
    end
    order.completedParts[job.key]=true
    if glass then order.completedParts[windowKey]=true end
    local complete=true;for key in pairs(order.requirements) do if not order.completedParts[key] then complete=false break end end
    MySQL.update.await('UPDATE `nv_mechanic_orders` SET `completedParts`=?,`status`=? WHERE `id`=?',{json.encode(order.completedParts),complete and 'ready' or 'in_progress',order.id})
    TriggerClientEvent('nv_mechanic:applyOrderPart',source,order.netId,job.key)
    if glass then TriggerClientEvent('nv_mechanic:applyOrderPart',source,order.netId,windowKey) end
    return true,nil,getOrder(order.id)
end)

exports('GetOrder', function(set,id) local o=getOrder(id);return o and o.orgSet==set and o or nil end)
exports('ListOrders', function(set)
    local rows=MySQL.query.await([[SELECT `id`,`plate`,`model`,`mechanic`,`status`,`total`,`payment`,`cancelReason`,
        DATE_FORMAT(`created`,'%d/%m/%Y %H:%i') AS `createdLabel`,DATE_FORMAT(`finished`,'%d/%m/%Y %H:%i') AS `finishedLabel`
        FROM `nv_mechanic_orders` WHERE `orgSet`=? ORDER BY `id` DESC LIMIT 100]],{set}) or {};return rows
end)
exports('SearchVehicles', function(query)
    query=tostring(query or ''):upper():gsub('^%s+',''):gsub('%s+$','')
    if #query<1 then return {} end
    local found,seen={},{}
    local rows=MySQL.query.await([[SELECT v.`plate`,CAST(v.`model` AS CHAR) AS `model`,c.`fullName` AS `owner`
        FROM `vehicles` v LEFT JOIN `characters` c ON c.`charId`=v.`owner`
        WHERE UPPER(v.`plate`) LIKE ? ORDER BY v.`plate` LIMIT 20]],{'%'..query:gsub('[%%_]','')..'%'}) or {}
    for _,row in ipairs(rows) do local plate=tostring(row.plate):upper():gsub('%s+$','');seen[plate]=true;row.plate=plate;row.online=false;found[#found+1]=row end
    for _,entity in ipairs(GetAllVehicles()) do
        local plate=(GetVehicleNumberPlateText(entity) or ''):upper():gsub('^%s+',''):gsub('%s+$','')
        if plate:find(query,1,true) then
            if seen[plate] then for _,row in ipairs(found) do if row.plate==plate then row.online=true;row.netId=NetworkGetNetworkIdFromEntity(entity) break end end
            else found[#found+1]={plate=plate,model=tostring(GetEntityModel(entity)),online=true,netId=NetworkGetNetworkIdFromEntity(entity)};seen[plate]=true end
        end
    end
    return found
end)
exports('StartOrder', function(set,id)
    local current=getOrder(id);local nextStatus=current and next(current.requirements)==nil and 'ready' or 'in_progress'
    local changed=MySQL.update.await([[UPDATE `nv_mechanic_orders` SET `status`=? WHERE `id`=? AND `orgSet`=? AND `status`='draft']],{nextStatus,id,set})
    return changed and changed>0,getOrder(id)
end)
exports('CancelOrder', function(set,id,reason)
    local changed=MySQL.update.await([[UPDATE `nv_mechanic_orders` SET `status`='cancelled',`cancelReason`=?,`finished`=NOW()
        WHERE `id`=? AND `orgSet`=? AND `status` IN ('draft','in_progress','ready','awaiting_payment')]],{tostring(reason or 'Cancelada'):sub(1,255),id,set})
    return changed and changed>0,getOrder(id)
end)
exports('CompleteOrder', function(set,id,payment,customerCharId,invoiceId,total,mechanicSource)
    local current=getOrder(id)
    local status=payment=='invoice' and 'awaiting_payment' or 'completed'
    local changed=MySQL.update.await([[UPDATE `nv_mechanic_orders` SET `status`=?,`payment`=?,`customerCharId`=?,`invoiceId`=?,`total`=?,`finished`=NOW()
        WHERE `id`=? AND `orgSet`=? AND `status` IN ('in_progress','ready')]],{status,payment,customerCharId,invoiceId,total,id,set})
    if changed and changed>0 and current and current.netId then
        exports.nv_mechanic:RestoreVehicle(current.netId,mechanicSource)
    end
    return changed and changed>0,getOrder(id)
end)

AddEventHandler('playerDropped',function() for token,job in pairs(active) do if job.source==source then active[token]=nil end end end)
