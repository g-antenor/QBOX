local function useBlocker(expectedAction)
    local vehicle = cache.vehicle
    if not vehicle or cache.seat ~= -1 then
        return lib.notify({
            title = 'Bloqueador de sinal',
            description = 'Entre no banco do motorista para instalar ou retirar.',
            type = 'error'
        })
    end

    local netId = VehToNet(vehicle)
    local allowed, err, action = lib.callback.await('nv_garage:blockerAction', false, netId, expectedAction)
    if not allowed then
        if err == 'noop' then return end
        return lib.notify({ title = 'Bloqueador de sinal', description = err or 'Nao foi possivel.', type = 'error' })
    end

    if not lib.progressBar({
        duration = Config.Blocker.useTime,
        label = action == 'remove' and 'Retirando bloqueador...' or 'Instalando bloqueador...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
    }) then return end

    if cache.vehicle ~= vehicle or cache.seat ~= -1 then return end

    local success = exports.nv_minigames:Start(Config.Blocker.minigame)
    local ok, callbackErr, installed, result = lib.callback.await(
        'nv_garage:useBlocker', false, netId, expectedAction, success == true)

    if not ok then
        return lib.notify({ title = 'Bloqueador de sinal', description = callbackErr or 'Nao foi possivel.', type = 'error' })
    end
    if result == 'broken' then
        return lib.notify({ title = 'Bloqueador de sinal', description = 'Bloqueador quebrou', type = 'error' })
    end
    lib.notify({
        title = 'Bloqueador de sinal',
        description = installed and 'Bloqueador instalado neste veiculo.' or 'Bloqueador retirado do veiculo.',
        type = 'success'
    })
end

exports('installBlocker', function() useBlocker('install') end)
exports('removeBlocker', function() useBlocker('remove') end)
