--[[
    nv_shops — cliente

    Ponte entre o balcao e a NUI. Nao ha logica de preco nem de estoque aqui:
    o que a vitrine desenha veio do servidor no `open`, e a compra volta para o
    servidor conferir tudo de novo.
]]

local open = false
local currentShop

---@type number[]
local attendants = {}

-- ------------------------------------------------------------------ abrir --

---@param shopId number
local function openShop(shopId)
    if open then return end

    local data = lib.callback.await('nv_shops:open', false, shopId)

    if not data then
        return lib.notify({ type = 'error', description = 'A loja esta fechada no momento.' })
    end

    open = true
    currentShop = shopId

    data.action = 'open'

    SetNuiFocus(true, true)
    SendNUIMessage(data)
end

local function closeShop()
    if not open then return end

    open = false
    currentShop = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ------------------------------------------------------------ callbacks --

RegisterNUICallback('close', function(_, cb)
    closeShop()
    cb(1)
end)

RegisterNUICallback('buy', function(data, cb)
    if not open or type(data) ~= 'table' or type(data.cart) ~= 'table' then
        return cb({ ok = false, error = 'Carrinho invalido.' })
    end

    -- O id vem do estado do CLIENTE, nao do payload da NUI: assim uma tela
    -- adulterada nao compra na loja do outro lado do mapa.
    local ok, err, total = lib.callback.await('nv_shops:buy', false, currentShop, data.cart)

    if not ok then
        return cb({ ok = false, error = err or 'Nao foi possivel comprar.' })
    end

    lib.notify({
        type = 'success',
        title = 'Compra concluida',
        description = ('Voce pagou $%d. A nota fiscal esta no seu bolso.'):format(total or 0)
    })

    cb({ ok = true })
end)

-- ------------------------------------------------------------ atendentes --

---@param shop table
---@return number?
local function createAttendant(shop)
    local settings = Config.Peds[shop.type]

    if not Config.Peds.enabled or not settings or not settings.model then return end

    local model = joaat(settings.model)

    if not lib.requestModel(model, 5000) then
        lib.print.warn(('Modelo "%s" nao carregou; a loja "%s" fica so com a zona.')
            :format(settings.model, shop.label))
        return
    end

    local coords = shop.coords
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z + Config.Peds.zOffset,
        shop.pedHeading or 0.0, false, true)

    SetModelAsNoLongerNeeded(model)

    if not ped or ped == 0 then return end

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if settings.scenario then
        TaskStartScenarioInPlace(ped, settings.scenario, 0, true)
    end

    attendants[#attendants + 1] = ped

    return ped
end

-- ---------------------------------------------------------------- blips --

CreateThread(function()
    for i = 1, #Config.Shops do
        local shop = Config.Shops[i]
        local settings = Config.Blips[shop.type]

        if settings then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)

            SetBlipSprite(blip, settings.sprite)
            SetBlipColour(blip, settings.color)
            SetBlipScale(blip, settings.scale)
            SetBlipDisplay(blip, 4)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(shop.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ------------------------------------------------------------ interacao --

CreateThread(function()
    for i = 1, #Config.Shops do
        local shop = Config.Shops[i]

        local option = {
            name = ('nv_shops_%d'):format(shop.id),
            label = shop.type == 'ammunation' and 'Falar com o vendedor' or 'Falar com o atendente',
            icon = shop.type == 'ammunation' and 'fa-solid fa-gun' or 'fa-solid fa-basket-shopping',
            distance = Config.MaxDistance,
            onSelect = function()
                openShop(shop.id)
            end
        }

        local attendant = createAttendant(shop)

        -- O atendente vira o alvo quando existe; a esfera e o plano B para
        -- quando o modelo nao carrega, para a loja nunca ficar inacessivel.
        if attendant then
            exports.ox_target:addLocalEntity(attendant, { option })
        else
            exports.ox_target:addSphereZone({
                coords = shop.coords,
                radius = 1.2,
                debug = false,
                options = { option }
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #attendants do
        if DoesEntityExist(attendants[i]) then DeleteEntity(attendants[i]) end
    end

    if open then SetNuiFocus(false, false) end
end)
