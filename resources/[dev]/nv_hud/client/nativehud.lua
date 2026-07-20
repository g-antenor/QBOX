-- ==========================================================================
-- SUPRESSAO DA HUD NATIVA DO GTA
--
-- Este arquivo e carregado ANTES de todos os outros e nao depende de nada
-- (nem de Config, nem de Settings, nem do ox_lib). Se qualquer outra parte
-- do nv_hud falhar, a HUD classica continua desligada.
--
-- Valores fixos de proposito: qualquer leitura de config aqui reintroduziria
-- um ponto de falha.
-- ==========================================================================

-- Unico estado compartilhado: se o radar/minimapa deve aparecer.
-- O restante do nv_hud so escreve aqui; nunca controla o resto da HUD nativa.
NativeHud = { radar = true }

local COMPONENTS = {
    1,  -- WANTED_STARS
    2,  -- WEAPON_ICON
    3,  -- CASH
    4,  -- MP_CASH
    6,  -- VEHICLE_NAME
    7,  -- AREA_NAME
    8,  -- VEHICLE_CLASS
    9,  -- STREET_NAME
    13, -- CASH_CHANGE
    20, -- WEAPON_WHEEL_STATS
    22  -- HUD_WEAPONS
}

CreateThread(function()
    -- As barras de vida/colete NAO sao componentes de HUD: elas sao desenhadas
    -- dentro do scaleform do radar, por isso sobreviviam ao DisplayHud(false).
    -- SETUP_HEALTH_ARMOUR com parametro 3 poe o minimapa no modo "golfe", que
    -- nao possui essas barras. Precisa ser reenviado a cada frame.
    -- Metodo original de @glitchdetector.
    local minimap = RequestScaleformMovie('minimap')

    while not HasScaleformMovieLoaded(minimap) do Wait(0) end

    -- Aqui basta esperar o scaleform carregar; quem reinicializa o radar para
    -- aplicar posicao/tamanho e o main.lua, com o toggle de bigmap.
    -- Garantia de nao herdar um bigmap preso de uma sessao anterior.
    SetRadarBigmapEnabled(false, false)

    while true do
        BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()

        -- Derruba a HUD inteira...
        DisplayHud(false)

        -- ...e reforca os componentes que voltam sozinhos em alguns fluxos
        -- (troca de personagem, entrar/sair de veiculo, morte).
        for i = 1, #COMPONENTS do
            HideHudComponentThisFrame(COMPONENTS[i])
        end

        -- DisplayHud(false) derruba o radar junto, entao reaplicamos.
        DisplayRadar(NativeHud.radar)

        Wait(0)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    DisplayHud(true)
    DisplayRadar(true)
end)
