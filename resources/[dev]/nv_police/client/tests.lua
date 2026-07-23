-- ------------------------------------------------ Testes Forenses e Bafômetro --

--- Monitoramento de disparos de arma de fogo pelo jogador local
CreateThread(function()
    while true do
        Wait(50)
        local ped = cache.ped
        if IsPedShooting(ped) then
            TriggerServerEvent('nv_police:recordShot')
            Wait(1000)
        end
    end
end)

--- Executa amostragem e envia callback ao servidor
local function runGenericTest(itemSlot, testType, labelText)
    local targetPlayer, dist = GetClosestPlayer(Config.InteractionDistance)
    if targetPlayer == -1 then
        return lib.notify({ type = 'error', description = 'Nenhum cidadão por perto para realizar o teste.' })
    end

    local targetServerId = GetPlayerServerId(targetPlayer)

    lib.requestAnimDict(Config.Anims.sample.dict)
    TaskPlayAnim(cache.ped, Config.Anims.sample.dict, Config.Anims.sample.clip, 8.0, -8.0, 2500, 49, 0, false, false, false)

    if lib.progressBar({
        duration = 2500,
        label = labelText,
        disable = { move = true, car = true, combat = true }
    }) then
        local success, resultText = lib.callback.await('nv_police:runTest', false, itemSlot, testType, targetServerId)
        if success then
            lib.notify({ type = 'success', description = resultText })
        else
            lib.notify({ type = 'error', description = resultText or 'Falha ao processar teste.' })
        end
    end
end

--- Export: uso do Teste de Pólvora
local function useGunpowderTest(data)
    local slot = type(data) == 'table' and data.slot or nil
    runGenericTest(slot, 'polvora', 'Coletando amostra de pólvora...')
end

--- Export: uso do Teste de Drogas
local function useDrugTest(data)
    local slot = type(data) == 'table' and data.slot or nil
    runGenericTest(slot, 'drogas', 'Coletando amostra de reagente químico...')
end

--- Export: uso do Bafômetro
local function useBreathalyzer(data)
    local slot = type(data) == 'table' and data.slot or nil
    local targetPlayer, dist = GetClosestPlayer(Config.InteractionDistance)
    if targetPlayer == -1 then
        return lib.notify({ type = 'error', description = 'Nenhum cidadão por perto para realizar o teste.' })
    end

    local targetPed = GetPlayerPed(targetPlayer)
    local targetServerId = GetPlayerServerId(targetPlayer)

    -- Verificação de máscara (componente 1) e capacete (prop 0)
    local maskDrawable = GetPedDrawableVariation(targetPed, 1)
    local helmetProp = GetPedPropIndex(targetPed, 0)
    local isObstructed = (maskDrawable > 0) or (helmetProp ~= -1)

    if isObstructed then
        -- Teste obstruído: registra falha sem capturar sopro
        lib.notify({ type = 'error', description = 'O teste falhou: o cidadão está usando máscara ou capacete.' })
        lib.callback.await('nv_police:runBreathalyzerTest', false, slot, targetServerId, true)
        return
    end

    -- Teste desobstruído: executa sopro no bafômetro
    lib.requestAnimDict(Config.Anims.sample.dict)
    TaskPlayAnim(cache.ped, Config.Anims.sample.dict, Config.Anims.sample.clip, 8.0, -8.0, 3000, 49, 0, false, false, false)

    if lib.progressBar({
        duration = 3000,
        label = 'Realizando teste de bafômetro...',
        disable = { move = true, car = true, combat = true }
    }) then
        local success, resultText = lib.callback.await('nv_police:runBreathalyzerTest', false, slot, targetServerId, false)
        if success then
            lib.notify({ type = 'inform', description = resultText })
        else
            lib.notify({ type = 'error', description = resultText or 'Falha no teste.' })
        end
    end
end

exports('useGunpowderTest', useGunpowderTest)
exports('useDrugTest', useDrugTest)
exports('useBreathalyzer', useBreathalyzer)
