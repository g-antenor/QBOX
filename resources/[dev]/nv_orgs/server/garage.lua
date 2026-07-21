--[[
    nv_orgs — servidor: estacionamento da organizacao

    Atendente (ped), vagas e frota. Comprar um veiculo debita o banco uma vez;
    retirar e guardar movimentam sempre o mesmo VIN, sem nova cobranca.

    Sobre a relacao com o nv_garage: nao ha duplicacao de mecanica. O veiculo
    criado aqui e um veiculo do ox_core com `group` preenchido, entao o
    nv_garage cuida de chave, ignicao e tranca exatamente como cuida de
    qualquer outro. O que este arquivo faz e a parte que o nv_garage nao tem:
    frota paga pelo caixa e acesso por cargo.
]]

local Ox = require '@ox_core.lib.init'

-- ------------------------------------------------------ catalogo de frota --

--- Lista de veiculos para o select da frota. Construida uma vez e guardada:
--- ler e ordenar o json do ox_core a cada abertura de dialogo seria trabalho
--- repetido para um dado que nao muda em runtime.
---@type { model: string, label: string, price: number, class: string, weight: number }[]?
local catalog

--- Le o catalogo do ox_core (common/data/vehicles.json).
---@return { model: string, label: string }[]
local function catalogFromOxCore()
    local file = LoadResourceFile('ox_core', 'common/data/vehicles.json')
    local ok, decoded = pcall(json.decode, file or '')

    if not ok or type(decoded) ~= 'table' then
        lib.print.warn('nv_orgs: nao foi possivel ler common/data/vehicles.json; a frota vai cair no campo de texto.')
        return {}
    end

    local cfg = Config.Dealership
    local filterCats = cfg.categories and next(cfg.categories) ~= nil
    local list = {}

    for model, data in pairs(decoded) do
        if type(data) == 'table' then
            -- Filtro de categoria: sem `categories` no config, tudo entra.
            local category = data.category or 'land'

            if not filterCats or cfg.categories[category] then
                local name = data.name or model
                local make = data.make

                list[#list + 1] = {
                    model = model,
                    label = (make and make ~= '') and ('%s %s'):format(make, name) or name,
                    price = math.max(1, math.floor(tonumber(data.price) or Config.VehicleBasePrice or 1000)),
                    class = data.category or data.class or 'land',
                    weight = math.max(0, math.floor(tonumber(data.weight) or 0))
                }
            end
        end
    end

    return list
end

--- Le o catalogo da futura dealership, se o export existir.
---@return { model: string, label: string }[]
local function catalogFromExport()
    local cfg = Config.Dealership.export

    if type(cfg) ~= 'table' or GetResourceState(cfg.resource) ~= 'started' then
        lib.print.warn(('nv_orgs: dealership "%s" nao esta rodando; a frota vai cair no campo de texto.')
            :format(cfg and cfg.resource or '?'))
        return {}
    end

    local ok, result = pcall(function()
        return exports[cfg.resource][cfg.method]()
    end)

    if not ok or type(result) ~= 'table' then return {} end

    -- Normaliza: aceita tanto { model, label } quanto { model = ... }.
    local list = {}

    for i = 1, #result do
        local entry = result[i]

        if type(entry) == 'table' and entry.model then
            list[#list + 1] = {
                model = entry.model,
                label = entry.label or entry.model,
                price = math.max(1, math.floor(tonumber(entry.price) or Config.VehicleBasePrice or 1000)),
                class = entry.category or entry.class or 'land',
                weight = math.max(0, math.floor(tonumber(entry.weight) or 0))
            }
        end
    end

    return list
end

--- Catalogo pronto: filtrado, ordenado e cortado no limite.
---@return { model: string, label: string }[]
local function getCatalog()
    if catalog then return catalog end

    local list = Config.Dealership.source == 'export'
        and catalogFromExport()
        or catalogFromOxCore()

    table.sort(list, function(a, b) return a.label < b.label end)

    -- Corta no teto: um select com centenas de itens fica lento, e a busca do
    -- proprio campo cobre o resto.
    local limit = Config.Dealership.limit or 600

    if #list > limit then
        for i = #list, limit + 1, -1 do
            list[i] = nil
        end
    end

    catalog = list

    return catalog
end

local function catalogVehicle(model)
    for _,entry in ipairs(getCatalog()) do if entry.model==model then return entry end end
end

lib.callback.register('nv_orgs:vehicleCatalog', function(source)
    if not Orgs.isAdmin(source) then return {} end

    return getCatalog()
end)

-- --------------------------------------------------------------- helpers --

--- "x y z heading" -> vector4
---@param text string?
---@return vector4?
local function toVec4(text)
    if type(text) ~= 'string' then return end

    local x, y, z, w = text:match('^(%S+) (%S+) (%S+) (%S+)$')

    x, y, z, w = tonumber(x), tonumber(y), tonumber(z), tonumber(w)

    if not x or not y or not z then return end

    return vec4(x, y, z, w or 0.0)
end

---@param coords table
---@param heading number?
---@return string
local function fromCoords(coords, heading)
    return ('%.3f %.3f %.3f %.2f'):format(coords.x, coords.y, coords.z, heading or 0.0)
end

--- Quantos cargos a organizacao tem.
---@param set string
---@return number
local function gradeCount(set)
    return MySQL.scalar.await(
        'SELECT COUNT(*) FROM `ox_group_grades` WHERE `group` = ?', { set }) or 0
end

-- ------------------------------------------------------ estado dos peds --

--- O que os clientes precisam para desenhar atendente e vagas.
---@type table[]
local garageCache = {}

--- Monta o pacote enviado aos clientes.
---@return table[]
local function loadGarages()
    if not Orgs.schemaReady then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT g.`group`, g.`ped`, o.`type` AS style,
               (SELECT COUNT(*) FROM `ox_group_grades` gg WHERE gg.`group` = g.`group`) AS grades
        FROM `nv_org_garages` g
        JOIN `ox_groups` o ON o.`name` = g.`group`
        WHERE g.`ped` IS NOT NULL
    ]])

    if not ok or type(rows) ~= 'table' then return {} end

    local spawnRows=MySQL.query.await('SELECT `group`,`coords` FROM `nv_org_spawns` ORDER BY `id`') or {}
    local spawnsByGroup={}
    for i=1,#spawnRows do
        local spawn=toVec4(spawnRows[i].coords)
        if spawn then
            local list=spawnsByGroup[spawnRows[i].group] or {}
            list[#list+1]={x=spawn.x,y=spawn.y,z=spawn.z,w=spawn.w}
            spawnsByGroup[spawnRows[i].group]=list
        end
    end

    local result = {}

    for i = 1, #rows do
        local row = rows[i]
        local model, rest = row.ped:match('^(%S+) (.+)$')
        local spot = toVec4(rest)

        if model and spot then
            result[#result + 1] = {
                set     = row.group,
                model   = model,
                coords  = { x = spot.x, y = spot.y, z = spot.z },
                heading = spot.w,
                spawns  = spawnsByGroup[row.group] or {},
                -- Job so aparece para quem e do set; organizacao estatal
                -- aparece para todo mundo (mas so membro interage). Foi o
                -- pedido, e faz sentido: delegacia tem atendente visivel, a
                -- garagem de uma empresa privada nao.
                publicPed = row.style == 'state'
            }
        end
    end

    return result
end

---@param target number?
function Orgs.syncGarages(target)
    garageCache = loadGarages()

    TriggerClientEvent('nv_orgs:garages', target or -1, garageCache)
end

CreateThread(function()
    while not Orgs.schemaReady do Wait(500) end

    Orgs.syncGarages()
end)

RegisterNetEvent('nv_orgs:requestGarages', function()
    TriggerClientEvent('nv_orgs:garages', source, garageCache)
end)

-- ------------------------------------------------------------ consultas --

lib.callback.register('nv_orgs:garage', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' or not Orgs.schemaReady then return end

    local row = MySQL.single.await('SELECT `ped` FROM `nv_org_garages` WHERE `group` = ?', { set })

    local spawns = MySQL.query.await(
        'SELECT `id`, `coords` FROM `nv_org_spawns` WHERE `group` = ? ORDER BY `id`', { set }) or {}

    local fleet = MySQL.query.await(
        'SELECT `id`, `model`, `label`, `price`, `minPosition` FROM `nv_org_fleet` WHERE `group` = ? ORDER BY `label`',
        { set }) or {}

    for i=1,#fleet do
        local entry=catalogVehicle(fleet[i].model)
        fleet[i].price=entry and entry.price or Config.VehicleBasePrice or 1000
    end

    return {
        ped    = row and row.ped or nil,
        spawns = spawns,
        fleet  = fleet
    }
end)

-- ------------------------------------------------------------ atendente --

lib.callback.register('nv_orgs:saveGaragePed', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local model = type(data.model) == 'string' and data.model ~= '' and data.model or 's_m_y_valet_01'
    local coords = data.coords

    if type(coords) ~= 'table' or type(coords.x) ~= 'number' then
        return false, 'Coordenada invalida.'
    end

    MySQL.prepare.await([[
        INSERT INTO `nv_org_garages` (`group`, `ped`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `ped` = VALUES(`ped`)
    ]], { set, ('%s %s'):format(model:sub(1, 24), fromCoords(coords, data.heading)) })

    Orgs.syncGarages()

    return true
end)

lib.callback.register('nv_orgs:deleteGaragePed', function(source, set)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_garages` WHERE `group` = ?', { set })
    Orgs.syncGarages()

    return true
end)

-- ---------------------------------------------------------------- vagas --

lib.callback.register('nv_orgs:addSpawn', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local coords = data.coords

    if type(coords) ~= 'table' or type(coords.x) ~= 'number' then
        return false, 'Coordenada invalida.'
    end

    MySQL.prepare.await('INSERT INTO `nv_org_spawns` (`group`, `coords`) VALUES (?, ?)',
        { set, fromCoords(coords, data.heading) })

    return true
end)

lib.callback.register('nv_orgs:deleteSpawn', function(source, set, id)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(id) ~= 'number' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_spawns` WHERE `id` = ? AND `group` = ?', { id, set })

    return true
end)

-- ---------------------------------------------------------------- frota --

lib.callback.register('nv_orgs:saveFleet', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local model = type(data.model) == 'string' and data.model:lower():gsub('%s', '') or ''

    if model == '' then return false, 'Informe o modelo do veiculo.' end
    if #model > 20 then return false, 'Nome de modelo longo demais.' end

    local total = gradeCount(set)
    if total == 0 then return false, 'Crie os cargos antes de montar a frota.' end

    local label = type(data.label) == 'string' and data.label ~= '' and data.label:sub(1, 50)
        or model:upper()

    local catalogEntry=catalogVehicle(model)
    if not catalogEntry then return false,'Modelo inexistente no catalogo.' end
    local price = catalogEntry.price
    local position = math.max(1, math.min(total, math.floor(tonumber(data.minPosition) or total)))

    if data.id then
        MySQL.query.await([[
            UPDATE `nv_org_fleet` SET `model` = ?, `label` = ?, `price` = ?, `minPosition` = ?
            WHERE `id` = ? AND `group` = ?
        ]], { model, label, price, position, data.id, set })
    else
        MySQL.prepare.await([[
            INSERT INTO `nv_org_fleet` (`group`, `model`, `label`, `price`, `minPosition`)
            VALUES (?, ?, ?, ?, ?)
        ]], { set, model, label, price, position })
    end

    return true
end)

lib.callback.register('nv_orgs:deleteFleet', function(source, set, id)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(id) ~= 'number' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_fleet` WHERE `id` = ? AND `group` = ?', { id, set })

    return true
end)

-- ------------------------------------------------------- uso pelo membro --

local locks={}
local function membership(source,set)
    local player=Ox.GetPlayer(source)
    if not player then return end
    local ok,groups=pcall(function() return player.getGroups() end)
    if not ok or type(groups)~='table' or groups[set]==nil then return end
    return player,groups[set]
end

--- Comprar exige as duas condicoes: ser o lider (cargo mais alto) e possuir a
--- acao `buyVehicles`. Assim a permissao nao libera compra para cargo comum e
--- ser chefe sozinho tambem nao ignora a configuracao feita no painel.
local function canBuyFleet(player,set,grade)
    local permitted=false
    pcall(function() permitted=player.hasPermission(('group.%s.buyVehicles'):format(set))==true end)
    local total=gradeCount(set)
    return permitted and total>0 and Orgs.gradeToPosition(grade,total)==1
end

local function canUseFleet(player,set)
    local permitted=false
    pcall(function() permitted=player.hasPermission(('group.%s.vehicles'):format(set))==true end)
    return permitted
end

local function quality(properties, mechanical)
    local engine=math.max(0,math.min(100,(tonumber(properties.engineHealth) or 1000)/10))
    local body=math.max(0,math.min(100,(tonumber(properties.bodyHealth) or 1000)/10))
    local tank=math.max(0,math.min(100,(tonumber(properties.tankHealth) or 1000)/10))
    local tyres=100
    if mechanical and type(mechanical.tyres)=='table' then
        local sum=0 for i=1,4 do sum=sum+(tonumber(mechanical.tyres[i]) or 100) end tyres=sum/4
    end
    local mech=mechanical and mechanical.engineFault and 0 or 100
    return math.floor(engine*.35+body*.25+tyres*.20+tank*.10+mech*.10+.5),math.floor(engine+.5),math.floor(body+.5),math.floor(tyres+.5)
end

lib.callback.register('nv_orgs:fleetFor', function(source,set)
    if type(set)~='string' or not Orgs.schemaReady then return end
    local player,grade=membership(source,set); if not player then return end
    local org=MySQL.single.await('SELECT `label` FROM `ox_groups` WHERE `name`=?',{set})
    if not org then return end
    local owned=MySQL.query.await([[SELECT v.`id`,v.`vin`,v.`plate`,v.`model`,v.`data`,v.`stored`,
        v.`group` AS `vehicleGroup`,
        s.`taken_by` AS `takenById`, c.`fullName` AS `takenBy`, DATE_FORMAT(s.`taken_at`,'%d/%m %H:%i') AS `takenAt`
        FROM `vehicles` v LEFT JOIN `nv_org_vehicle_state` s ON s.`vin`=v.`vin`
        LEFT JOIN `characters` c ON c.`charId`=s.`taken_by`
        WHERE v.`group`=? OR s.`group`=? ORDER BY v.`id`]],{set,set}) or {}
    for i=1,#owned do
        -- Recupera compras feitas por uma versao anterior que registrou o VIN
        -- na frota, mas deixou de preencher a coluna group de vehicles.
        if owned[i].vehicleGroup~=set then
            MySQL.update.await('UPDATE `vehicles` SET `group`=? WHERE `id`=?',{set,owned[i].id})
        end
        owned[i].vehicleGroup=nil
        local ok,data=pcall(json.decode,owned[i].data or '{}'); if not ok or type(data)~='table' then data={} end
        local properties=data.properties or data
        local live=Ox.GetVehicleFromVin(owned[i].vin)
        if live and live.entity and DoesEntityExist(live.entity) then
            properties.engineHealth=GetVehicleEngineHealth(live.entity)
            properties.bodyHealth=GetVehicleBodyHealth(live.entity)
            properties.tankHealth=GetVehiclePetrolTankHealth(live.entity)
        end
        local mechanical
        if GetResourceState('nv_mechanic')=='started' then mechanical=exports.nv_mechanic:GetSnapshot(owned[i].vin) end
        owned[i].quality,owned[i].engine,owned[i].body,owned[i].tyres=quality(properties,mechanical)
        owned[i].status=owned[i].stored==set and 'stored' or (owned[i].stored and 'impound' or 'out')
        owned[i].ownerLabel=org.label
        owned[i].data=nil
        local entry=catalogVehicle(owned[i].model); owned[i].label=entry and entry.label or owned[i].model

        -- Recuperacao para veiculo retirado antes desta correcao: se continua
        -- atribuido a este personagem, garante a chave ao reabrir o menu.
        if owned[i].status=='out' and tonumber(owned[i].takenById)==tonumber(player.charId) then
            pcall(function() exports.nv_garage:GiveKey(source,owned[i].plate,owned[i].label) end)
        end
        owned[i].takenById=nil
    end
    local templates=MySQL.query.await('SELECT `id`,`model`,`label`,`minPosition` FROM `nv_org_fleet` WHERE `group`=? ORDER BY `label`',{set}) or {}
    for i=1,#templates do local entry=catalogVehicle(templates[i].model); templates[i].price=entry and entry.price or Config.VehicleBasePrice or 1000 end
    local permitted=canBuyFleet(player,set,grade)
    local canUse=canUseFleet(player,set)
    for i=1,#owned do
        owned[i].authorized=canUse
        if owned[i].status=='impound' and GetResourceState('nv_garage')=='started' then
            local ok,fee=pcall(function() return exports.nv_garage:GetImpoundFee(owned[i].vin) end)
            owned[i].fee=ok and (tonumber(fee) or 0) or 0
        end
        owned[i].here=owned[i].status=='stored'
        owned[i].garageLabel=org.label
    end
    return {owned=owned,catalog=templates,canBuy=permitted,canUse=canUse,org=org.label}
end)

lib.callback.register('nv_orgs:buyFleetVehicle',function(source,set,fleetId)
    if type(set)~='string' or type(fleetId)~='number' then return false,'Dados invalidos.' end
    local player,grade=membership(source,set); if not player then return false,'Voce nao pertence a esta organizacao.' end
    local allowed=canBuyFleet(player,set,grade)
    if not allowed then return false,'Seu cargo nao pode comprar veiculos.' end
    local row=MySQL.single.await('SELECT `model`,`label` FROM `nv_org_fleet` WHERE `id`=? AND `group`=?',{fleetId,set})
    if not row then return false,'Modelo nao autorizado.' end
    local entry=catalogVehicle(row.model); if not entry then return false,'Modelo fora do catalogo.' end
    local account=Ox.GetGroupAccount(set); if not account then return false,'Conta da organizacao indisponivel.' end
    local orgLabel=MySQL.scalar.await('SELECT `label` FROM `ox_groups` WHERE `name`=?',{set}) or set
    local ok,result=pcall(function() return account.removeBalance({amount=entry.price,message=('Compra de veiculo: %s'):format(entry.label)}) end)
    if not ok or type(result)~='table' or result.success~=true then return false,('Saldo insuficiente (precisa de $%d).'):format(entry.price) end
    local made,vehicle=pcall(function()
        return Ox.CreateVehicle({model=row.model,group=set,stored=set,data={registeredOwner=orgLabel}})
    end)
    if not made or not vehicle or not vehicle.id then
        pcall(function() account.addBalance({amount=entry.price,message='Estorno de compra de veiculo'}) end)
        return false,'Falha ao criar o veiculo; valor estornado.'
    end

    -- Confirma explicitamente o destino. Alem de proteger contra versoes do
    -- ox_core que ignoram `stored` durante CreateVehicle, isto garante que a
    -- consulta da frota enxergue o carro imediatamente apos a compra.
    MySQL.update.await(
        'UPDATE `vehicles` SET `group`=?, `stored`=? WHERE `id`=? AND `vin`=?',
        {set,set,vehicle.id,vehicle.vin}
    )
    -- UPDATE pode devolver zero quando os valores ja eram iguais; por isso a
    -- confirmacao precisa ler o registro, nao confiar em affectedRows.
    local persisted=MySQL.single.await(
        'SELECT `group`,`stored` FROM `vehicles` WHERE `id`=? AND `vin`=?',
        {vehicle.id,vehicle.vin}
    )
    if not persisted or persisted.group~=set or persisted.stored~=set then
        pcall(function() vehicle.delete() end)
        pcall(function() account.addBalance({amount=entry.price,message='Estorno de compra de veiculo'}) end)
        return false,'Falha ao vincular o veiculo a garagem; valor estornado.'
    end
    MySQL.prepare.await([[INSERT INTO `nv_org_vehicle_state` (`vin`,`group`) VALUES (?,?)
        ON DUPLICATE KEY UPDATE `group`=VALUES(`group`)]],{vehicle.vin,set})
    return true,nil,('%s comprado em nome da organizacao.'):format(entry.label)
end)

lib.callback.register('nv_orgs:takeFleetVehicle',function(source,set,vehicleId)
    if type(set)~='string' or type(vehicleId)~='number' then return false,'Dados invalidos.' end
    local member=membership(source,set)
    if not member then return false,'Voce nao pertence a esta organizacao.' end
    if not canUseFleet(member,set) then return false,'Seu cargo nao pode retirar veiculos da frota.' end
    if locks[vehicleId] then return false,'Veiculo em movimentacao.' end
    locks[vehicleId]=true
    local row=MySQL.single.await('SELECT `id`,`vin`,`plate`,`model`,`stored` FROM `vehicles` WHERE `id`=? AND `group`=?',{vehicleId,set})
    local impoundName='impound'
    local impounded=row and row.stored==impoundName
    if not row or (row.stored~=set and not impounded) then locks[vehicleId]=nil return false,'O veiculo nao esta disponivel.' end
    local spawns=MySQL.query.await('SELECT `coords` FROM `nv_org_spawns` WHERE `group`=? ORDER BY `id`',{set}) or {}
    local spot
    for i=1,#spawns do local candidate=toVec4(spawns[i].coords); if candidate then
        local occupied=false for _,entity in ipairs(GetAllVehicles()) do if #(GetEntityCoords(entity)-vec3(candidate.x,candidate.y,candidate.z))<2.5 then occupied=true break end end
        if not occupied then spot=candidate break end
    end end
    if not spot then locks[vehicleId]=nil return false,'Nenhuma vaga livre.' end
    local charged,account,fee=false,nil,0
    if impounded then
        account=Ox.GetGroupAccount(set)
        if not account then locks[vehicleId]=nil return false,'Conta da organizacao indisponivel.' end
        local ok,value=pcall(function() return exports.nv_garage:GetImpoundFee(row.vin) end)
        fee=ok and (tonumber(value) or 0) or 0
        if fee>0 then
            local paid,result=pcall(function()
                return account.removeBalance({amount=fee,message=('Patio: liberacao do veiculo %s'):format(row.plate)})
            end)
            if not paid or type(result)~='table' or result.success~=true then
                locks[vehicleId]=nil
                return false,('Saldo insuficiente no caixa da organizacao (taxa: $%d).'):format(fee)
            end
            charged=true
        end
    end
    local vehicle=Ox.SpawnVehicle(row.id,vec3(spot.x,spot.y,spot.z),spot.w)
    if not vehicle then
        if charged then pcall(function() account.addBalance({amount=fee,message='Estorno: falha ao liberar veiculo do patio'}) end) end
        locks[vehicleId]=nil return false,'Nao foi possivel retirar o veiculo.'
    end
    if GetResourceState('nv_mechanic')=='started' then exports.nv_mechanic:ApplyToEntity(row.vin,vehicle.entity) end
    local keyCall,keyGiven,keyError=pcall(function()
        return exports.nv_garage:GiveKey(source,row.plate,(catalogVehicle(row.model) or {}).label or row.model)
    end)
    if not keyCall or keyGiven~=true then
        -- Sem chave a retirada nao pode ser concluida. Devolve o mesmo VIN a
        -- garagem para o jogador tentar novamente apos liberar um slot.
        pcall(function() vehicle.setStored(set,true) end)
        if charged then pcall(function() account.addBalance({amount=fee,message='Estorno: chave nao entregue'}) end) end
        locks[vehicleId]=nil
        local reasons={
            inventory_full='O inventario nao possui um slot livre.',
            invalid_inventory='O inventario do personagem ainda nao esta carregado.',
            invalid_item='O item vehiclekey nao esta registrado no ox_inventory.',
            invalid_source_or_plate='Os dados do personagem ou da placa sao invalidos.',
            invalid_plate='A placa do veiculo esta vazia.'
        }
        local reason=keyCall and keyError or keyGiven
        return false,reasons[reason] or ('Nao foi possivel entregar a chave (%s).'):format(tostring(reason or 'erro desconhecido'))
    end
    if impounded then pcall(function() exports.nv_garage:ClearImpound(row.vin) end) end
    pcall(function() exports.nv_garage:MarkOut(row.vin) end)
    local player=Ox.GetPlayer(source)
    MySQL.prepare.await([[INSERT INTO `nv_org_vehicle_state` (`vin`,`group`,`taken_by`,`taken_at`) VALUES (?,?,?,NOW())
        ON DUPLICATE KEY UPDATE `taken_by`=VALUES(`taken_by`),`taken_at`=NOW()]],{row.vin,set,player and player.charId})
    locks[vehicleId]=nil
    return true,nil,row.plate
end)

lib.callback.register('nv_orgs:storeFleetVehicle',function(source,set,netId,properties,mechanical)
    if type(set)~='string' then return false,'Sem permissao.' end
    local member=membership(source,set)
    if not member or not canUseFleet(member,set) then return false,'Seu cargo nao pode movimentar veiculos da frota.' end
    local vehicle=Ox.GetVehicleFromNetId(netId); if not vehicle or vehicle.group~=set then return false,'Este veiculo nao pertence a esta organizacao.' end
    if not vehicle.entity or #(GetEntityCoords(GetPlayerPed(source))-GetEntityCoords(vehicle.entity))>8.0 then return false,'Aproxime o veiculo da garagem.' end
    local spawns=MySQL.query.await('SELECT `coords` FROM `nv_org_spawns` WHERE `group`=?',{set}) or {}
    local atSpot=false
    for i=1,#spawns do
        local spot=toVec4(spawns[i].coords)
        if spot and #(GetEntityCoords(vehicle.entity)-vec3(spot.x,spot.y,spot.z))<=4.0 then atSpot=true break end
    end
    if not atSpot then return false,'Estacione o veiculo em uma vaga da organizacao.' end
    if type(properties)=='table' then vehicle.setProperties(properties) end
    if type(mechanical)=='table' and GetResourceState('nv_mechanic')=='started' then exports.nv_mechanic:SaveSnapshot(vehicle.vin,mechanical) end
    local plate=vehicle.plate
    local stored=pcall(function() vehicle.setStored(set,true) end)
    if not stored then return false,'Falha ao persistir o veiculo; ele foi mantido no local.' end
    if plate and GetResourceState('nv_garage')=='started' then
        pcall(function() exports.nv_garage:RemoveKey(source,plate) end)
    end
    local player=Ox.GetPlayer(source)
    MySQL.prepare.await([[INSERT INTO `nv_org_vehicle_state` (`vin`,`group`,`returned_by`,`returned_at`) VALUES (?,?,?,NOW())
        ON DUPLICATE KEY UPDATE `returned_by`=VALUES(`returned_by`),`returned_at`=NOW()]],{vehicle.vin,set,player and player.charId})
    return true
end)
