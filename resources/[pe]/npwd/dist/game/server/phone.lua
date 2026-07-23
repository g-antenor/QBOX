--[[
    nv_phone - Servidor: Resolução de Jogadores Próximos, Persistência de Contatos, Chamadas e Mensagens no Banco de Dados (MySQL / oxmysql)
]]

local MySQL = MySQL or exports.oxmysql
local ActiveCalls = {}
local callTokenCounter = 0
local CALL_RING_TIMEOUT = 60000 -- 1 minuto (chamada não atendida vira perdida)

--- Remove os ouvintes de "viva voz" do canal da chamada, restaurando cada um ao
--- canal em que estava antes (0 = sem chamada) para não quebrar ligações alheias.
--- @param session table sessão de chamada de um jogador (ActiveCalls[src])
local function clearSpeaker(session)
    if session and session.speakerAdded then
        for bysrc, prevCh in pairs(session.speakerAdded) do
            local restore = (type(prevCh) == 'number') and prevCh or 0
            pcall(function() exports['pma-voice']:setPlayerCall(bysrc, restore) end)
        end
        session.speakerAdded = nil
    end
end

--- Auxiliar para obter o identificador único do personagem (ox_core ou fallback)
local function getCharIdentifier(src)
    local ok, pObj = pcall(function() return exports.ox_core and exports.ox_core:GetPlayer(src) end)
    if ok and pObj and type(pObj) == 'table' then
        if pObj.charId then return tostring(pObj.charId) end
        if pObj.stateId then return tostring(pObj.stateId) end
        if type(pObj.get) == 'function' then
            local okVal, val = pcall(function() return pObj.get('charId') or pObj.get('stateId') end)
            if okVal and val then return tostring(val) end
        end
    end
    return tostring(src)
end

--- Auxiliar para obter dados do jogador (Nome do Personagem RP e Número de Telefone)
local function getPlayerData(src)
    local charName = nil
    local phoneNumber = nil
    local charId = getCharIdentifier(src)

    -- 1. Tentar obter via objeto do jogador no ox_core
    local okChar, pObj = pcall(function() return exports.ox_core and exports.ox_core:GetPlayer(src) end)
    if okChar and pObj and type(pObj) == 'table' then
        local fn, ln

        if type(pObj.get) == 'function' then
            pcall(function() fn = pObj.get('firstName') end)
            pcall(function() ln = pObj.get('lastName') end)
            if not fn then pcall(function() fn = pObj.get('firstname') end) end
            if not ln then pcall(function() ln = pObj.get('lastname') end) end
        end

        if not fn then fn = pObj.firstName or pObj.firstname end
        if not ln then ln = pObj.lastName or pObj.lastname end

        if fn and ln then
            charName = tostring(fn) .. ' ' .. tostring(ln)
        elseif pObj.name and pObj.name ~= GetPlayerName(tostring(src)) then
            charName = tostring(pObj.name)
        end

        local okP, resP = pcall(function()
            if type(pObj.getPhoneNumber) == 'function' then
                return pObj:getPhoneNumber()
            elseif type(pObj.get) == 'function' then
                return pObj.get('phoneNumber') or pObj.get('phone')
            elseif pObj.phoneNumber then
                return pObj.phoneNumber
            elseif pObj.phone then
                return pObj.phone
            end
        end)
        if okP and resP and resP ~= '' then phoneNumber = tostring(resP) end
    end

    -- 2. Se não encontrou nome RP completo, consultar na tabela `characters` do ox_core
    if not charName or charName == "" or not phoneNumber or phoneNumber == "" then
        local okDbName, nameRow = pcall(MySQL.single.await, [[
            SELECT `firstName`, `lastName`, `fullName`, `phoneNumber`
            FROM `characters` WHERE `charId` = ? OR `stateId` = ? LIMIT 1
        ]], { charId, charId })

        if okDbName and nameRow then
            if not charName or charName == "" then
                if nameRow.fullName and nameRow.fullName ~= '' then
                    charName = nameRow.fullName
                elseif nameRow.firstName and nameRow.lastName then
                    charName = tostring(nameRow.firstName) .. ' ' .. tostring(nameRow.lastName)
                end
            end

            if not phoneNumber or phoneNumber == "" then
                if nameRow.phoneNumber and nameRow.phoneNumber ~= '' then
                    phoneNumber = tostring(nameRow.phoneNumber)
                end
            end
        end
    end

    -- 3. Fallbacks finais se nenhum nome RP existir
    if not charName or charName == "" then
        charName = ("Cidadão %s"):format(tostring(src))
    end

    if not phoneNumber or phoneNumber == "" then
        phoneNumber = ("555-%04d"):format(tonumber(src) or 0)
    end

    return charName, phoneNumber
end

--- Localiza o `source` de um jogador online a partir do número de telefone.
--- @param targetNumber string  Número do destinatário (com ou sem máscara).
--- @return number|nil src, string|nil name, string|nil number
--- Chamada por: envio de mensagens, digitação e chamadas.
local function findOnlinePlayerByNumber(targetNumber)
    if not targetNumber or targetNumber == "" then return nil end
    local cleanTarget = tostring(targetNumber):gsub("%s+", ""):gsub("-", "")

    local players = GetPlayers()
    for i = 1, #players do
        local pSrc = tonumber(players[i])
        if pSrc then
            local name, num = getPlayerData(pSrc)
            local cleanNum = tostring(num):gsub("%s+", ""):gsub("-", "")
            if cleanNum == cleanTarget or tostring(pSrc) == cleanTarget then
                return pSrc, name, num
            end
        end
    end
    return nil
end

-- =======================================================
-- PERSISTÊNCIA DE CONTATOS (MYSQL / OXMYSQL)
-- =======================================================

--- Callback para buscar todos os contatos do personagem no Banco de Dados
lib.callback.register('npwd:getPhoneContacts', function(source)
    local identifier = getCharIdentifier(source)
    local query = 'SELECT id, display AS name, number, avatar FROM npwd_phone_contacts WHERE identifier = ? ORDER BY display ASC'
    local success, result = pcall(function()
        return MySQL.query.await(query, { identifier })
    end)
    if success and result then
        return result
    end
    return {}
end)

--- Verifica se o personagem já possui um contato com o número informado.
--- A comparação ignora máscara (espaços e hífens) para evitar duplicatas.
--- @param identifier string identificador do personagem
--- @param number string número a validar
--- @return boolean existe
local function contactExists(identifier, number)
    local clean = tostring(number):gsub("%s+", ""):gsub("-", "")
    local ok, id = pcall(function()
        return MySQL.scalar.await(
            "SELECT id FROM npwd_phone_contacts WHERE identifier = ? AND REPLACE(REPLACE(`number`, '-', ''), ' ', '') = ? LIMIT 1",
            { identifier, clean }
        )
    end)
    return ok and id ~= nil
end

--- Adicionar um novo contato no banco de dados (evita duplicar número já existente)
RegisterNetEvent('npwd:serverAddContact', function(contactName, contactNumber, avatarUrl)
    local src = source
    if not contactName or not contactNumber then return end
    local identifier = getCharIdentifier(src)
    local avatar = avatarUrl or ''

    if contactExists(identifier, contactNumber) then return end

    pcall(function()
        MySQL.insert('INSERT INTO npwd_phone_contacts (identifier, display, number, avatar) VALUES (?, ?, ?, ?)', {
            identifier, contactName, contactNumber, avatar
        })
    end)
end)

--- Editar um contato existente no banco de dados
RegisterNetEvent('npwd:serverUpdateContact', function(contactId, contactName, contactNumber, avatarUrl)
    local src = source
    if not contactId or not contactName or not contactNumber then return end
    local identifier = getCharIdentifier(src)
    local avatar = avatarUrl or ''

    pcall(function()
        MySQL.update('UPDATE npwd_phone_contacts SET display = ?, number = ?, avatar = ? WHERE id = ? AND identifier = ?', {
            contactName, contactNumber, avatar, contactId, identifier
        })
    end)
end)

--- Deletar um contato do banco de dados
RegisterNetEvent('npwd:serverDeleteContact', function(contactId)
    local src = source
    if not contactId then return end
    local identifier = getCharIdentifier(src)

    pcall(function()
        MySQL.update('DELETE FROM npwd_phone_contacts WHERE id = ? AND identifier = ?', {
            contactId, identifier
        })
    end)
end)

--- Salvar contato recebido via compartilhamento no banco de dados
RegisterNetEvent('npwd:saveSharedContact', function(contactName, contactNumber)
    local src = source
    if not contactName or not contactNumber then return end
    local identifier = getCharIdentifier(src)

    -- Não duplicar: se o número já estiver nos contatos, apenas avisa.
    if contactExists(identifier, contactNumber) then
        TriggerEvent('npwd:serverCreateNotification', src, {
            app = 'phone',
            title = 'Contato já existe',
            content = ('%s (%s) já está nos seus contatos.'):format(contactName, contactNumber)
        })
        return
    end

    pcall(function()
        MySQL.insert('INSERT INTO npwd_phone_contacts (identifier, display, number, avatar) VALUES (?, ?, ?, ?)', {
            identifier, contactName, contactNumber, ''
        })
    end)

    TriggerEvent('npwd:serverCreateNotification', src, {
        app = 'phone',
        title = 'Contato Salvo',
        content = ('%s (%s) foi adicionado aos seus contatos.'):format(contactName, contactNumber)
    })
end)

-- =======================================================
-- PERSISTÊNCIA DE HISTÓRICO DE LIGAÇÕES (RECENTES - MYSQL)
-- =======================================================

--- Callback para buscar o histórico de ligações recentes no Banco de Dados.
--- Cada registro guarda `transmitter` (quem ligou) e `receiver` (quem recebeu);
--- aqui calculamos, em relação ao MEU número, quem é o outro lado (`contact`)
--- e a direção (`direction`: 'outgoing' quando eu liguei, senão 'incoming').
lib.callback.register('npwd:getPhoneRecents', function(source)
    local identifier = getCharIdentifier(source)
    local _, myPhone = getPlayerData(source)
    local myClean = tostring(myPhone or ''):gsub('[%s%-()]', '')

    local query = 'SELECT id, transmitter, receiver, is_accepted, start, end FROM npwd_calls WHERE identifier = ? ORDER BY id DESC LIMIT 30'
    local success, result = pcall(function()
        return MySQL.query.await(query, { identifier })
    end)
    if success and result then
        for i = 1, #result do
            local row = result[i]
            local tClean = tostring(row.transmitter or ''):gsub('[%s%-()]', '')
            local outgoing = (myClean ~= '' and tClean == myClean)
            row.direction = outgoing and 'outgoing' or 'incoming'
            row.contact = outgoing and row.receiver or row.transmitter
        end
        return result
    end
    return {}
end)

--- Salvar um registro de ligação no banco de dados
local function saveCallRecord(src, transmitterNum, receiverNum, isAccepted, startTime)
    local identifier = getCharIdentifier(src)
    local nowTime = os.date('%Y-%m-%d %H:%M:%S')
    pcall(function()
        MySQL.insert('INSERT INTO npwd_calls (identifier, transmitter, receiver, is_accepted, start, end) VALUES (?, ?, ?, ?, ?, ?)', {
            identifier, transmitterNum, receiverNum, isAccepted and 1 or 0, tostring(startTime or nowTime), nowTime
        })
    end)
end

--- Deletar um registro do histórico de chamadas no banco de dados
RegisterNetEvent('npwd:serverDeleteRecentCall', function(callId)
    local src = source
    if not callId then return end
    local identifier = getCharIdentifier(src)

    pcall(function()
        MySQL.update('DELETE FROM npwd_calls WHERE id = ? AND identifier = ?', {
            callId, identifier
        })
    end)
end)

-- =======================================================
-- PERSISTÊNCIA DE MENSAGENS E CONVERSAS (MYSQL / OXMYSQL)
-- =======================================================

--- Helper para obter ou criar ID de conversa entre dois números
local function getOrCreateConversation(senderIdentifier, senderPhone, targetPhone)
    local cleanSender = tostring(senderPhone):gsub("%s+", ""):gsub("-", "")
    local cleanTarget = tostring(targetPhone):gsub("%s+", ""):gsub("-", "")
    
    local queryFind = [[
        SELECT c.id FROM npwd_messages_conversations c
        JOIN npwd_messages_participants p1 ON p1.conversation_id = c.id
        JOIN npwd_messages_participants p2 ON p2.conversation_id = c.id
        WHERE p1.participant = ? AND p2.participant = ? LIMIT 1
    ]]
    local successFind, existing = pcall(function()
        return MySQL.scalar.await(queryFind, { cleanSender, cleanTarget })
    end)

    if successFind and existing then return existing end

    local convList = cleanSender .. ',' .. cleanTarget
    local convId = pcall(function()
        return MySQL.insert.await('INSERT INTO npwd_messages_conversations (conversation_list, label) VALUES (?, ?)', {
            convList, targetPhone
        })
    end)

    if convId then
        pcall(function()
            MySQL.insert('INSERT INTO npwd_messages_participants (conversation_id, participant) VALUES (?, ?)', { convId, cleanSender })
            MySQL.insert('INSERT INTO npwd_messages_participants (conversation_id, participant) VALUES (?, ?)', { convId, cleanTarget })
        end)
    end

    return convId
end

--- Callback para buscar lista de conversas do jogador
lib.callback.register('npwd:getConversations', function(source)
    local senderName, senderPhone = getPlayerData(source)
    local cleanSender = tostring(senderPhone):gsub("%s+", ""):gsub("-", "")

    local query = [[
        SELECT 
            c.id,
            c.label,
            c.updatedAt,
            p_target.participant AS targetNumber,
            m.message AS lastMessage,
            m.createdAt AS lastTime,
            m.author AS lastAuthor
        FROM npwd_messages_conversations c
        JOIN npwd_messages_participants p_user ON p_user.conversation_id = c.id AND p_user.participant = ?
        LEFT JOIN npwd_messages_participants p_target ON p_target.conversation_id = c.id AND p_target.participant != ?
        LEFT JOIN npwd_messages m ON m.id = c.last_message_id
        ORDER BY c.updatedAt DESC
    ]]

    local success, result = pcall(function()
        return MySQL.query.await(query, { cleanSender, cleanSender })
    end)

    if success and result then
        return result
    end
    return {}
end)

--- Callback para buscar as mensagens de uma conversa (com paginação/janela).
--- @param opts table|nil { beforeId = number, aroundId = number, limit = number }
---   - sem opts: as `limit` (padrão 40) mensagens MAIS RECENTES
---   - beforeId: página de mensagens ANTERIORES ao id (carregar histórico ao subir)
---   - aroundId: janela centrada no id (usada ao pular para um resultado de busca)
lib.callback.register('npwd:getMessages', function(source, conversationId, targetNumber, opts)
    local src = source
    local senderName, senderPhone = getPlayerData(src)
    local identifier = getCharIdentifier(src)

    local convId = tonumber(conversationId)
    if not convId and targetNumber then
        convId = getOrCreateConversation(identifier, senderPhone, targetNumber)
    end

    if not convId then return { conversationId = 0, messages = {} } end

    opts = type(opts) == 'table' and opts or {}
    local limit = tonumber(opts.limit) or 40
    if limit > 100 then limit = 100 end

    local rows
    local hasMoreOlder = false

    local function markSelf(list)
        for i = 1, #list do
            list[i].self = (tostring(list[i].user_identifier) == tostring(identifier))
        end
    end

    if opts.aroundId then
        -- Janela: metade antes e metade depois do id alvo
        local half = math.floor(limit / 2)
        local before = MySQL.query.await(
            'SELECT id, message, user_identifier, author, createdAt FROM npwd_messages WHERE conversation_id = ? AND id <= ? ORDER BY id DESC LIMIT ?',
            { tostring(convId), tonumber(opts.aroundId), half + 1 }) or {}
        local after = MySQL.query.await(
            'SELECT id, message, user_identifier, author, createdAt FROM npwd_messages WHERE conversation_id = ? AND id > ? ORDER BY id ASC LIMIT ?',
            { tostring(convId), tonumber(opts.aroundId), half }) or {}
        -- Se veio 1 a mais no "before", ainda há mensagens mais antigas
        hasMoreOlder = (#before > half)
        if hasMoreOlder then before[#before] = nil end
        -- before está em DESC; inverte para ASC
        local merged = {}
        for i = #before, 1, -1 do merged[#merged + 1] = before[i] end
        for i = 1, #after do merged[#merged + 1] = after[i] end
        rows = merged
    elseif opts.beforeId then
        -- Página anterior (mais antigas): pega DESC e inverte para ASC
        local desc = MySQL.query.await(
            'SELECT id, message, user_identifier, author, createdAt FROM npwd_messages WHERE conversation_id = ? AND id < ? ORDER BY id DESC LIMIT ?',
            { tostring(convId), tonumber(opts.beforeId), limit + 1 }) or {}
        hasMoreOlder = (#desc > limit)
        if hasMoreOlder then desc[#desc] = nil end
        rows = {}
        for i = #desc, 1, -1 do rows[#rows + 1] = desc[i] end
    else
        -- Mais recentes: DESC e inverte para ASC (mais recente no fim)
        local desc = MySQL.query.await(
            'SELECT id, message, user_identifier, author, createdAt FROM npwd_messages WHERE conversation_id = ? ORDER BY id DESC LIMIT ?',
            { tostring(convId), limit + 1 }) or {}
        hasMoreOlder = (#desc > limit)
        if hasMoreOlder then desc[#desc] = nil end
        rows = {}
        for i = #desc, 1, -1 do rows[#rows + 1] = desc[i] end
    end

    rows = rows or {}
    markSelf(rows)
    return { conversationId = convId, messages = rows, hasMoreOlder = hasMoreOlder }
end)

--- Busca mensagens por texto dentro de uma conversa (para o "Buscar mensagem")
lib.callback.register('npwd:searchMessages', function(source, conversationId, query)
    local identifier = getCharIdentifier(source)
    local convId = tonumber(conversationId)
    if not convId or type(query) ~= 'string' then return { matches = {} } end

    local q = query:gsub('%s+$', ''):gsub('^%s+', '')
    if q == '' then return { matches = {} } end

    local like = '%' .. q:gsub('([%%_])', '\\%1') .. '%'
    local ok, res = pcall(function()
        return MySQL.query.await(
            'SELECT id, message, user_identifier, author, createdAt FROM npwd_messages WHERE conversation_id = ? AND message LIKE ? ORDER BY id DESC LIMIT 30',
            { tostring(convId), like })
    end)
    if ok and res then
        for i = 1, #res do
            res[i].self = (tostring(res[i].user_identifier) == tostring(identifier))
        end
        return { matches = res }
    end
    return { matches = {} }
end)

--- Enviar mensagem via NUI/Servidor
RegisterNetEvent('npwd:serverSendMessage', function(targetNumber, messageText, conversationId)
    local src = source
    if not messageText or messageText:gsub("%s+", "") == "" then return end

    local senderName, senderPhone = getPlayerData(src)
    local identifier = getCharIdentifier(src)

    local convId = tonumber(conversationId)
    if not convId and targetNumber then
        convId = getOrCreateConversation(identifier, senderPhone, targetNumber)
    end

    if not convId then return end

    local msgId = MySQL.insert.await('INSERT INTO npwd_messages (message, user_identifier, conversation_id, author) VALUES (?, ?, ?, ?)', {
        messageText, identifier, tostring(convId), senderName
    })

    pcall(function()
        MySQL.update('UPDATE npwd_messages_conversations SET last_message_id = ?, updatedAt = CURRENT_TIMESTAMP() WHERE id = ?', {
            msgId, convId
        })
    end)

    local msgPayload = {
        id = msgId,
        conversationId = convId,
        senderNumber = senderPhone,
        targetNumber = targetNumber,
        author = senderName,
        message = messageText,
        user_identifier = identifier,
        createdAt = os.date('%H:%M')
    }

    -- Localizar destinatário online por número (feito antes para poder
    -- informar o número real do remetente na visão do destinatário).
    local targetSrc = findOnlinePlayerByNumber(targetNumber)

    -- Eco para o remetente (self = true -> balão "enviado" / outgoing).
    msgPayload.self = true
    TriggerClientEvent('npwd:clientReceiveMessage', src, msgPayload)

    -- Entrega em tempo real ao destinatário (self = false -> "recebido" / incoming).
    if targetSrc and targetSrc ~= src then
        local targetPayload = {}
        for k, v in pairs(msgPayload) do targetPayload[k] = v end
        targetPayload.self = false
        -- Para o destinatário, o número que ele "conversa" é o do remetente.
        targetPayload.targetNumber = senderPhone
        TriggerClientEvent('npwd:clientReceiveMessage', targetSrc, targetPayload)
        TriggerClientEvent('npwd:onIncomingMessageNotification', targetSrc, senderName, messageText, senderPhone)
    end
end)

--- Sinaliza (ou remove) o estado "digitando" para o destinatário em tempo real.
--- @param targetNumber string  Número do destinatário da conversa.
--- @param isTyping boolean      true enquanto digita, false ao parar/enviar.
--- Chamada por: NUI do app de mensagens (client `npwd:setTyping`).
RegisterNetEvent('npwd:serverSetTyping', function(targetNumber, isTyping)
    local src = source
    local senderName, senderPhone = getPlayerData(src)

    local targetSrc = findOnlinePlayerByNumber(targetNumber)
    if targetSrc and targetSrc ~= src then
        TriggerClientEvent('npwd:clientTyping', targetSrc, senderPhone, senderName, isTyping == true)
    end
end)

--- Deletar conversa
RegisterNetEvent('npwd:serverDeleteConversation', function(conversationId)
    local src = source
    if not conversationId then return end

    pcall(function()
        MySQL.update('DELETE FROM npwd_messages_conversations WHERE id = ?', { conversationId })
        MySQL.update('DELETE FROM npwd_messages_participants WHERE conversation_id = ?', { conversationId })
        MySQL.update('DELETE FROM npwd_messages WHERE conversation_id = ?', { conversationId })
    end)
end)

-- =======================================================
-- BLOCO DE NOTAS (MYSQL / OXMYSQL)
-- =======================================================

--- Garante a existência da tabela `npwd_notes` e das colunas `color`/`updatedAt`.
--- Reaproveita a tabela legada (id, identifier, title, content) quando já existir.
CreateThread(function()
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `npwd_notes` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `title` VARCHAR(120) NOT NULL DEFAULT '',
            `content` MEDIUMTEXT NULL,
            `color` VARCHAR(20) NOT NULL DEFAULT '#a855f7',
            `updatedAt` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `npwd_notes_identifier` (`identifier`)
        )]])
    end)
    -- Colunas novas para tabelas legadas (ignora erro se já existirem).
    pcall(function()
        MySQL.query.await("ALTER TABLE `npwd_notes` ADD COLUMN `color` VARCHAR(20) NOT NULL DEFAULT '#a855f7'")
    end)
    pcall(function()
        MySQL.query.await("ALTER TABLE `npwd_notes` ADD COLUMN `updatedAt` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP")
    end)
end)

--- Callback: lista as notas do personagem (mais recentes primeiro)
lib.callback.register('npwd:getNotes', function(source)
    local identifier = getCharIdentifier(source)
    local query = [[
        SELECT `id`, `title`, `content`, `color`,
               DATE_FORMAT(`updatedAt`, '%d/%m/%Y %H:%i') AS updated
        FROM `npwd_notes` WHERE `identifier` = ? ORDER BY `updatedAt` DESC, `id` DESC
    ]]
    local ok, result = pcall(function() return MySQL.query.await(query, { identifier }) end)
    if ok and result then return result end
    return {}
end)

--- Criar/atualizar uma nota. Se `noteId` vier, atualiza; senão insere.
--- @param note table { id?, title, content, color }
RegisterNetEvent('npwd:serverSaveNote', function(note)
    local src = source
    if type(note) ~= 'table' then return end
    local identifier = getCharIdentifier(src)

    local title = tostring(note.title or ''):sub(1, 120)
    local content = tostring(note.content or '')
    local color = tostring(note.color or '#a855f7'):sub(1, 20)
    local noteId = tonumber(note.id)

    if title == '' and content == '' then return end

    pcall(function()
        if noteId then
            MySQL.update('UPDATE `npwd_notes` SET `title` = ?, `content` = ?, `color` = ? WHERE `id` = ? AND `identifier` = ?', {
                title, content, color, noteId, identifier
            })
        else
            MySQL.insert('INSERT INTO `npwd_notes` (`identifier`, `title`, `content`, `color`) VALUES (?, ?, ?, ?)', {
                identifier, title, content, color
            })
        end
    end)
end)

--- Excluir uma nota do personagem
RegisterNetEvent('npwd:serverDeleteNote', function(noteId)
    local src = source
    if not noteId then return end
    local identifier = getCharIdentifier(src)
    pcall(function()
        MySQL.update('DELETE FROM `npwd_notes` WHERE `id` = ? AND `identifier` = ?', { noteId, identifier })
    end)
end)

--- Compartilhar uma nota com um jogador próximo (espelha o fluxo de contato).
--- @param targetId number server id do destinatário
--- @param note table { title, content, color }
RegisterNetEvent('npwd:serverShareNote', function(targetId, note)
    local src = source
    local targetSrc = tonumber(targetId)
    if not targetSrc or targetSrc <= 0 or type(note) ~= 'table' then return end

    local senderName = getPlayerData(src)
    local payload = {
        title = tostring(note.title or 'Nota'):sub(1, 120),
        content = tostring(note.content or ''),
        color = tostring(note.color or '#a855f7'):sub(1, 20),
        from = senderName
    }

    TriggerClientEvent('npwd:clientReceiveSharedNote', targetSrc, payload)
    TriggerClientEvent('npwd:onIncomingNoteNotification', targetSrc, senderName, payload.title)
end)

--- Salvar nota recebida via compartilhamento na conta de quem aceitou.
RegisterNetEvent('npwd:saveSharedNote', function(note)
    local src = source
    if type(note) ~= 'table' then return end
    local identifier = getCharIdentifier(src)

    local title = tostring(note.title or 'Nota'):sub(1, 120)
    local content = tostring(note.content or '')
    local color = tostring(note.color or '#a855f7'):sub(1, 20)

    pcall(function()
        MySQL.insert('INSERT INTO `npwd_notes` (`identifier`, `title`, `content`, `color`) VALUES (?, ?, ?, ?)', {
            identifier, title, content, color
        })
    end)

    TriggerEvent('npwd:serverCreateNotification', src, {
        app = 'notes',
        title = 'Nota Salva',
        content = ('"%s" foi adicionada às suas notas.'):format(title)
    })
end)

-- =======================================================
-- RESOLUÇÃO DE JOGADORES PRÓXIMOS
-- =======================================================

lib.callback.register('npwd:resolveNearbyPlayersNames', function(source, nearbyList)
    if not nearbyList or type(nearbyList) ~= 'table' then return {} end

    local result = {}
    for i = 1, #nearbyList do
        local item = nearbyList[i]
        local targetSrc = tonumber(item.id)
        if targetSrc and targetSrc > 0 and GetPlayerName(tostring(targetSrc)) then
            local charName = getPlayerData(targetSrc)
            result[#result + 1] = {
                id = targetSrc,
                name = charName,
                distance = item.distance
            }
        end
    end
    return result
end)

--- Enviar solicitação de contato compartilhado para o alvo
RegisterNetEvent('npwd:serverShareContact', function(targetId)
    local src = source
    local targetSrc = tonumber(targetId)
    if not targetSrc or targetSrc <= 0 then return end

    local senderName, senderPhone = getPlayerData(src)

    TriggerClientEvent('npwd:clientReceiveSharedContact', targetSrc, src, {
        name = senderName,
        number = senderPhone
    })

    TriggerClientEvent('npwd:onIncomingContactNotification', targetSrc, senderName, senderPhone)
end)

-- =======================================================
-- GERENCIAMENTO DE CHAMADAS ENTRE JOGADORES (SERVER-SIDE)
-- =======================================================

local function findOnlinePlayerByNumber(targetNumber)
    if not targetNumber or targetNumber == "" then return nil end
    local cleanTarget = tostring(targetNumber):gsub("%s+", ""):gsub("-", "")

    local players = GetPlayers()
    for i = 1, #players do
        local pSrc = tonumber(players[i])
        if pSrc then
            local name, num = getPlayerData(pSrc)
            local cleanNum = tostring(num):gsub("%s+", ""):gsub("-", "")
            if cleanNum == cleanTarget or tostring(pSrc) == cleanTarget then
                return pSrc, name, num
            end
        end
    end
    return nil
end

RegisterNetEvent('npwd:serverStartCall', function(targetNumber)
    local src = source
    local callerName, callerPhone = getPlayerData(src)

    local targetSrc, targetName, targetPhone = findOnlinePlayerByNumber(targetNumber)

    if not targetSrc or targetSrc == src then
        -- Número não existe / offline
        saveCallRecord(src, callerPhone, tostring(targetNumber), false, os.date('%Y-%m-%d %H:%M:%S'))
        TriggerClientEvent('npwd:clientCallFailed', src, 'invalid_number')
        return
    end

    -- Registrar sessão de chamada
    callTokenCounter = callTokenCounter + 1
    local token = callTokenCounter
    local nowStart = os.date('%Y-%m-%d %H:%M:%S')

    ActiveCalls[src] = {
        partner = targetSrc,
        callerPhone = callerPhone,
        targetPhone = targetPhone,
        callerName = callerName,
        targetName = targetName,
        isCaller = true,
        isAccepted = false,
        startTime = nowStart,
        token = token
    }
    ActiveCalls[targetSrc] = {
        partner = src,
        callerPhone = callerPhone,
        targetPhone = targetPhone,
        callerName = callerName,
        targetName = targetName,
        isCaller = false,
        isAccepted = false,
        startTime = nowStart,
        token = token
    }

    TriggerClientEvent('npwd:clientCallRinging', src, targetPhone, targetName)
    TriggerClientEvent('npwd:clientIncomingCall', targetSrc, callerPhone, callerName)

    -- Timeout: se ninguém atender em 1 minuto, encerra para ambos e registra perdida
    SetTimeout(CALL_RING_TIMEOUT, function()
        local session = ActiveCalls[src]
        if not session or session.token ~= token or session.isAccepted then return end

        saveCallRecord(src, session.callerPhone, session.targetPhone, false, session.startTime)
        ActiveCalls[src] = nil

        if ActiveCalls[targetSrc] and ActiveCalls[targetSrc].token == token then
            saveCallRecord(targetSrc, session.callerPhone, session.targetPhone, false, session.startTime)
            ActiveCalls[targetSrc] = nil
        end

        -- Quem ligou vê a chamada encerrada; quem recebeu registra como perdida
        TriggerClientEvent('npwd:clientCallEnded', src, 'no_answer')
        TriggerClientEvent('npwd:clientMissedCall', targetSrc, session.callerName, session.callerPhone)
    end)
end)

RegisterNetEvent('npwd:serverAnswerCall', function()
    local src = source
    local session = ActiveCalls[src]
    if not session then return end

    session.isAccepted = true
    local partnerSrc = session.partner
    local callChannel = math.min(src, partnerSrc) * 1000 + math.max(src, partnerSrc)

    -- A partir do atendimento marca o início da conversa (para o tempo total correto)
    local talkStart = os.date('%Y-%m-%d %H:%M:%S')
    session.startTime = talkStart
    session.callChannel = callChannel

    if partnerSrc and ActiveCalls[partnerSrc] then
        ActiveCalls[partnerSrc].isAccepted = true
        ActiveCalls[partnerSrc].startTime = talkStart
        ActiveCalls[partnerSrc].callChannel = callChannel
        TriggerClientEvent('npwd:clientCallConnected', partnerSrc, callChannel)
    end

    TriggerClientEvent('npwd:clientCallConnected', src, callChannel)
end)

--- Viva voz: adiciona/remove jogadores próximos (raio definido no client) no canal da chamada
--- para que ouçam (e sejam ouvidos) na ligação enquanto o viva voz estiver ativo.
--- @param enabled boolean estado do viva voz
--- @param nearbyIds table lista de server ids próximos calculada no client
RegisterNetEvent('npwd:serverSetSpeaker', function(enabled, nearbyIds)
    local src = source
    local session = ActiveCalls[src]
    if not session or not session.isAccepted or not session.callChannel then return end

    if enabled then
        session.speakerAdded = session.speakerAdded or {}
        if type(nearbyIds) == 'table' then
            for i = 1, #nearbyIds do
                local bysrc = tonumber(nearbyIds[i])
                -- Inclui TODOS os jogadores próximos no canal da chamada, inclusive os
                -- que já estão em outra ligação. O partner já está no canal (ignorado).
                if bysrc and bysrc ~= src and bysrc ~= session.partner and not session.speakerAdded[bysrc] then
                    -- Guarda o canal atual do jogador para restaurá-lo ao desligar o viva voz.
                    local prevCh = 0
                    local ok, ch = pcall(function() return Player(bysrc).state.callChannel end)
                    if ok and type(ch) == 'number' then prevCh = ch end

                    pcall(function() exports['pma-voice']:setPlayerCall(bysrc, session.callChannel) end)
                    session.speakerAdded[bysrc] = prevCh
                end
            end
        end
    else
        clearSpeaker(session)
    end
end)

RegisterNetEvent('npwd:serverDeclineCall', function()
    local src = source
    local session = ActiveCalls[src]
    if not session then return end

    local partnerSrc = session.partner
    local isCaller = session.isCaller

    clearSpeaker(session)
    if partnerSrc then clearSpeaker(ActiveCalls[partnerSrc]) end

    saveCallRecord(src, session.callerPhone, session.targetPhone, false, session.startTime)
    ActiveCalls[src] = nil

    if partnerSrc and ActiveCalls[partnerSrc] then
        saveCallRecord(partnerSrc, session.callerPhone, session.targetPhone, false, session.startTime)
        ActiveCalls[partnerSrc] = nil

        if isCaller then
            -- O jogador que ligou cancelou/desligou -> o outro recebe Chamada Perdida
            TriggerClientEvent('npwd:clientCallEnded', src, 'cancelled')
            TriggerClientEvent('npwd:clientMissedCall', partnerSrc, session.callerName, session.callerPhone)
        else
            -- O jogador que recebeu recusou -> AMBOS recebem Chamada Recusada
            TriggerClientEvent('npwd:clientCallDeclined', src, session.callerName)
            TriggerClientEvent('npwd:clientCallDeclined', partnerSrc, session.targetName)
        end
    else
        TriggerClientEvent('npwd:clientCallEnded', src, 'cancelled')
    end
end)

RegisterNetEvent('npwd:serverEndCall', function()
    local src = source
    local session = ActiveCalls[src]
    if not session then return end

    if not session.isAccepted then
        local partnerSrc = session.partner
        local isCaller = session.isCaller
        clearSpeaker(session)
        if partnerSrc then clearSpeaker(ActiveCalls[partnerSrc]) end
        saveCallRecord(src, session.callerPhone, session.targetPhone, false, session.startTime)
        ActiveCalls[src] = nil

        if partnerSrc and ActiveCalls[partnerSrc] then
            saveCallRecord(partnerSrc, session.callerPhone, session.targetPhone, false, session.startTime)
            ActiveCalls[partnerSrc] = nil

            if isCaller then
                TriggerClientEvent('npwd:clientCallEnded', src, 'cancelled')
                TriggerClientEvent('npwd:clientMissedCall', partnerSrc, session.callerName, session.callerPhone)
            else
                TriggerClientEvent('npwd:clientCallDeclined', src, session.callerName)
                TriggerClientEvent('npwd:clientCallDeclined', partnerSrc, session.targetName)
            end
        else
            TriggerClientEvent('npwd:clientCallEnded', src, 'cancelled')
        end
        return
    end

    local partnerSrc = session.partner
    clearSpeaker(session)
    if partnerSrc then clearSpeaker(ActiveCalls[partnerSrc]) end
    saveCallRecord(src, session.callerPhone, session.targetPhone, true, session.startTime)

    ActiveCalls[src] = nil
    TriggerClientEvent('npwd:clientCallEnded', src, 'ended')

    if partnerSrc and ActiveCalls[partnerSrc] then
        saveCallRecord(partnerSrc, session.callerPhone, session.targetPhone, true, session.startTime)
        ActiveCalls[partnerSrc] = nil
        TriggerClientEvent('npwd:clientCallEnded', partnerSrc, 'ended')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local session = ActiveCalls[src]
    if session then
        local partnerSrc = session.partner
        clearSpeaker(session)
        if partnerSrc then clearSpeaker(ActiveCalls[partnerSrc]) end
        saveCallRecord(src, session.callerPhone, session.targetPhone, false, session.startTime)
        ActiveCalls[src] = nil
        if partnerSrc and ActiveCalls[partnerSrc] then
            saveCallRecord(partnerSrc, session.callerPhone, session.targetPhone, false, session.startTime)
            ActiveCalls[partnerSrc] = nil
            TriggerClientEvent('npwd:clientCallEnded', partnerSrc, 'partner_disconnected')
        end
    end
end)

-- =======================================================
-- GALERIA DE FOTOS (CÂMERA) — PERSISTÊNCIA (MYSQL / OXMYSQL)
-- =======================================================

CreateThread(function()
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `npwd_photos` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `identifier` VARCHAR(64) NOT NULL,
                `image` LONGTEXT NOT NULL,
                `orientation` VARCHAR(12) NOT NULL DEFAULT 'portrait',
                `createdAt` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                INDEX `idx_photos_identifier` (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)
end)

--- Callback para buscar as fotos da galeria do personagem
lib.callback.register('npwd:getPhotos', function(source)
    local identifier = getCharIdentifier(source)
    local ok, res = pcall(function()
        return MySQL.query.await('SELECT id, image, orientation, createdAt FROM npwd_photos WHERE identifier = ? ORDER BY id DESC LIMIT 60', { identifier })
    end)
    if ok and res then return res end
    return {}
end)

--- Salvar uma foto (data URL base64) na galeria do personagem
RegisterNetEvent('npwd:serverSavePhoto', function(image, orientation)
    local src = source
    if type(image) ~= 'string' or image == '' then return end
    if #image > 8000000 then return end -- limite defensivo (~8MB por foto)
    local identifier = getCharIdentifier(src)
    local ori = (orientation == 'landscape') and 'landscape' or 'portrait'
    pcall(function()
        MySQL.insert('INSERT INTO npwd_photos (identifier, image, orientation) VALUES (?, ?, ?)', { identifier, image, ori })
    end)
end)

--- Excluir uma foto da galeria do personagem
RegisterNetEvent('npwd:serverDeletePhoto', function(photoId)
    local src = source
    if not photoId then return end
    local identifier = getCharIdentifier(src)
    pcall(function()
        MySQL.update('DELETE FROM npwd_photos WHERE id = ? AND identifier = ?', { photoId, identifier })
    end)
end)

print('^2[nv_phone:phone] Módulo de contatos, chamadas e mensagens com persistência MySQL (oxmysql) carregado com sucesso.^7')
