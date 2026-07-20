--[[
    nv_orgs — cliente: chave

    Usar a chave tranca ou destranca a porta mais proxima da organizacao. O
    cliente nao decide nada: le o set gravado na chave e pergunta ao servidor,
    que confere posse E filiacao antes de mexer na porta.

    O set vem do metadata do item -- o ox_inventory entrega isso em
    `slot.metadata` no segundo argumento do export.
]]

--- Chamado pelo ox_inventory ao usar a chave.
---@param _data table  dados do item (nao usados; o set vem do slot)
---@param slot table    { name, slot, metadata }
local function useKey(_data, slot)
    local set = type(slot) == 'table' and type(slot.metadata) == 'table' and slot.metadata.set or nil

    if type(set) ~= 'string' or set == '' then
        return Panel.notify('Esta chave nao esta gravada para nenhuma organizacao.', 'error')
    end

    local ok, err, result = lib.callback.await('nv_orgs:useKey', false, set)

    if not ok then
        return Panel.notify(err or 'Nao foi possivel usar a chave.', 'error')
    end

    -- Pequeno gesto de girar a chave, como no nv_garage.
    lib.requestAnimDict('anim@mp_player_intmenu@key_fob@', 2000)
    TaskPlayAnim(cache.ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 8.0, -1, -1, 48, 0, false, false, false)
    Wait(600)
    StopAnimTask(cache.ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 1.0)

    Panel.notify(('Porta %s.'):format(result or 'alterada'), 'success')
end

-- O export vive em main.lua; aqui so preenchemos o handler.
Panel.itemHandlers.key = useKey
