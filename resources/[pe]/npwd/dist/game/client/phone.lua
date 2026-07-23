--[[
    nv_phone - Cliente: Sistema de Telefone, Contatos, Recentes e Chamadas entre Jogadores
]]

--- Buscar jogadores próximos (dentro de 5.0 metros)
RegisterNuiCallback('npwd:getNearbyPlayers', function(data, cb)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyPlayers = {}

    local activePlayers = GetActivePlayers()
    for i = 1, #activePlayers do
        local targetPed = GetPlayerPed(activePlayers[i])
        local targetServerId = GetPlayerServerId(activePlayers[i])
        
        if targetServerId ~= GetPlayerServerId(PlayerId()) and DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(playerCoords - targetCoords)
            if dist <= 5.0 then
                nearbyPlayers[#nearbyPlayers + 1] = {
                    id = targetServerId,
                    distance = math.floor(dist * 10) / 10
                }
            end
        end
    end

    lib.callback('npwd:resolveNearbyPlayersNames', false, function(playersWithNames)
        cb(playersWithNames or nearbyPlayers)
    end, nearbyPlayers)
end)

--- Compartilhar contato com um jogador próximo
RegisterNuiCallback('npwd:shareContact', function(data, cb)
    if not data or not data.targetId then
        cb({ success = false, message = "Selecione um jogador próximo." })
        return
    end

    TriggerServerEvent('npwd:serverShareContact', data.targetId)
    cb({ success = true, message = "Solicitação de compartilhamento enviada." })
end)

--- Receber solicitação de contato recebido do servidor
RegisterNetEvent('npwd:clientReceiveSharedContact', function(senderId, contactData)
    SendNUIMessage({
        action = "receiveSharedContact",
        data = {
            senderId = senderId,
            name = contactData.name,
            number = contactData.number
        }
    })
end)

RegisterNetEvent('npwd:onIncomingContactNotification', function(senderName, senderPhone)
    -- Apenas o som; a exibição (modal ou notificação) é tratada por
    -- 'npwd:clientReceiveSharedContact' para não duplicar a UI.
    PlaySoundFrontend(-1, "Event_Message_In", "GTAO_FM_Events_Soundset", 1)
end)

--- Callback NUI para aceitar contato recebido
RegisterNuiCallback('npwd:acceptSharedContact', function(data, cb)
    if not data or not data.name or not data.number then
        cb({ success = false })
        return
    end

    TriggerServerEvent('npwd:saveSharedContact', data.name, data.number)
    cb({ success = true })
end)

-- =======================================================
-- PERSISTÊNCIA DE BANCO DE DADOS (CONTATOS E RECENTES)
-- =======================================================

RegisterNuiCallback('npwd:getContacts', function(data, cb)
    lib.callback('npwd:getPhoneContacts', false, function(contacts)
        cb(contacts or {})
    end)
end)

RegisterNuiCallback('npwd:saveContact', function(data, cb)
    if data and (data.name or data.display) and data.number then
        local name = data.name or data.display
        TriggerServerEvent('npwd:serverAddContact', name, data.number, data.avatar or '')
    end
    cb({ success = true })
end)

RegisterNuiCallback('npwd:updateContact', function(data, cb)
    if data and data.id and (data.name or data.display) and data.number then
        local name = data.name or data.display
        TriggerServerEvent('npwd:serverUpdateContact', data.id, name, data.number, data.avatar or '')
    end
    cb({ success = true })
end)

RegisterNuiCallback('npwd:deleteContact', function(data, cb)
    if data and data.id then
        TriggerServerEvent('npwd:serverDeleteContact', data.id)
    end
    cb({ success = true })
end)

RegisterNuiCallback('npwd:getRecents', function(data, cb)
    lib.callback('npwd:getPhoneRecents', false, function(recents)
        cb(recents or {})
    end)
end)

RegisterNuiCallback('npwd:deleteRecentCall', function(data, cb)
    if data and data.id then
        TriggerServerEvent('npwd:serverDeleteRecentCall', data.id)
    end
    cb({ success = true })
end)

--- NUI Callback ao receber chamada de alguém
RegisterNuiCallback('npwd:onIncomingCallNotification', function(data, cb)
    if data and data.name then
        PlaySoundFrontend(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", true)
    end
    cb({ success = true })
end)

--- NUI Callback de chamada perdida
RegisterNuiCallback('npwd:onMissedCallNotification', function(data, cb)
    if data and data.name then
        PlaySoundFrontend(-1, "Event_Message_Purple", "GTAO_FM_Events_Soundset", true)
    end
    cb({ success = true })
end)

-- =======================================================
-- GERENCIAMENTO DE CHAMADAS ENTRE JOGADORES (CLIENT-SIDE)
-- =======================================================

--- Iniciar chamada via NUI
RegisterNuiCallback('npwd:startCall', function(data, cb)
    if not data or not data.number then
        cb({ success = false })
        return
    end

    TriggerServerEvent('npwd:serverStartCall', data.number)
    cb({ success = true })
end)

--- Atender chamada via NUI
RegisterNuiCallback('npwd:answerCall', function(data, cb)
    TriggerServerEvent('npwd:serverAnswerCall')
    cb({ success = true })
end)

--- Desligar / Recusar chamada via NUI
RegisterNuiCallback('npwd:endCall', function(data, cb)
    TriggerServerEvent('npwd:serverEndCall')
    cb({ success = true })
end)

RegisterNuiCallback('npwd:declineCall', function(data, cb)
    TriggerServerEvent('npwd:serverDeclineCall')
    cb({ success = true })
end)

-- =======================================================
-- GERENCIAMENTO DE PROP E ANIMAÇÃO DO CELULAR (ORELHA / MÃO)
-- =======================================================
local phoneProp = nil
local currentAnimState = nil -- 'text', 'call', nil
local isPhoneVisibleState = false
local currentCallChannel = 0
local isCallMuted = false

local function loadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end
    end
end

local function attachPhoneProp()
    if not phoneProp or not DoesEntityExist(phoneProp) then
        local model = `p_amb_phone_01`
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        local ped = PlayerPedId()
        phoneProp = CreateObject(model, 1.0, 1.0, 1.0, true, true, false)
        local bone = GetPedBoneIndex(ped, 28422) -- SKEL_R_Hand
        AttachEntityToEntity(phoneProp, ped, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
    end
end

local function detachPhoneProp()
    if phoneProp and DoesEntityExist(phoneProp) then
        DeleteEntity(phoneProp)
        phoneProp = nil
    end
end

local function playPhoneAnimation(animType)
    local ped = PlayerPedId()
    if currentAnimState == animType then return end

    currentAnimState = animType

    if animType == 'call' then
        attachPhoneProp()
        loadAnimDict("cellphone@")
        TaskPlayAnim(ped, "cellphone@", "cellphone_call_listen_base", 3.0, -1.0, -1, 49, 0, false, false, false)
    elseif animType == 'text' then
        attachPhoneProp()
        loadAnimDict("cellphone@")
        TaskPlayAnim(ped, "cellphone@", "cellphone_text_read_base", 3.0, -1.0, -1, 49, 0, false, false, false)
    else
        ClearPedTasks(ped)
        detachPhoneProp()
    end
end

local function stopPhoneAnimation()
    currentAnimState = nil
    local ped = PlayerPedId()
    StopAnimTask(ped, "cellphone@", "cellphone_call_listen_base", 1.0)
    StopAnimTask(ped, "cellphone@", "cellphone_text_read_base", 1.0)
    detachPhoneProp()
end

--- Restaura o estado da voz e da chamada de voz (pma-voice) ao encerrar uma ligação.
local function resetCallVoiceState()
    if isCallMuted then
        MumbleSetActive(true)
        isCallMuted = false
    end
    currentCallChannel = 0
    if exports['pma-voice'] then
        exports['pma-voice']:setCallChannel(0)
    end
end

--- Ao desligar/encerrar a chamada o jogador faz a animação de "olhar o celular".
--- Se o telefone estiver aberto, mantém a animação padrão; senão, dá uma olhada
--- rápida e guarda o aparelho.
local function endCallAnimation()
    playPhoneAnimation('text')
    if not isPhoneVisibleState then
        SetTimeout(2500, function()
            if currentAnimState == 'text' and not isPhoneVisibleState then
                stopPhoneAnimation()
            end
        end)
    end
end

function isPhoneVisible()
    return isPhoneVisibleState
end
exports('isPhoneVisible', isPhoneVisible)

function setPhoneVisible(bool)
    isPhoneVisibleState = (bool == true)
    if isPhoneVisibleState then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
        SendNUIMessage({ action = "open" })
        if currentAnimState ~= 'call' then
            playPhoneAnimation('text')
        end
    else
        SendNUIMessage({ action = "close" })
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        if currentAnimState ~= 'call' then
            stopPhoneAnimation()
        end
    end
end
exports('setPhoneVisible', setPhoneVisible)

RegisterCommand('phone', function()
    setPhoneVisible(not isPhoneVisibleState)
end, false)

RegisterKeyMapping('phone', 'Abrir Telefone (NPWD)', 'keyboard', 'F1')

RegisterNetEvent('npwd:openPhone', function()
    setPhoneVisible(true)
end)

RegisterNetEvent('npwd:closePhone', function()
    setPhoneVisible(false)
end)

RegisterNetEvent('npwd:open', function()
    setPhoneVisible(true)
end)

RegisterNetEvent('npwd:close', function()
    setPhoneVisible(false)
end)

RegisterNetEvent('npwd:toggle', function()
    setPhoneVisible(not isPhoneVisibleState)
end)

RegisterNetEvent('npwd:setPhoneVisible', function(bool)
    setPhoneVisible(bool)
end)

RegisterNuiCallback('npwd:closePhone', function(data, cb)
    setPhoneVisible(false)
    cb({ success = true })
end)

--- Eventos de rede recebidos do servidor para NUI
RegisterNetEvent('npwd:clientCallRinging', function(targetNumber, targetName)
    playPhoneAnimation('call')
    SendNUIMessage({
        action = "callRinging",
        number = targetNumber,
        name = targetName
    })
end)

RegisterNetEvent('npwd:clientIncomingCall', function(senderNumber, senderName)
    -- Ao RECEBER a chamada NÃO fazemos a animação de telefone na orelha:
    -- ela só acontece quando o jogador atende (npwd:clientCallConnected).
    SendNUIMessage({
        action = "incomingCall",
        number = senderNumber,
        name = senderName
    })
end)

RegisterNetEvent('npwd:clientCallConnected', function(callChannel)
    -- Chamada atendida: agora sim ambos fazem a animação de telefone na orelha.
    playPhoneAnimation('call')
    isCallMuted = false
    if callChannel and exports['pma-voice'] then
        currentCallChannel = tonumber(callChannel) or 0
        exports['pma-voice']:setCallChannel(currentCallChannel)
    end
    SendNUIMessage({
        action = "callConnected"
    })
end)

RegisterNetEvent('npwd:clientCallDeclined', function(partnerName)
    resetCallVoiceState()
    endCallAnimation()
    SendNUIMessage({
        action = "callDeclined",
        name = partnerName
    })
end)

RegisterNetEvent('npwd:clientMissedCall', function(senderName, senderNumber)
    resetCallVoiceState()
    endCallAnimation()
    SendNUIMessage({
        action = "missedCall",
        name = senderName,
        number = senderNumber
    })
end)

RegisterNetEvent('npwd:clientCallEnded', function(reason)
    resetCallVoiceState()
    endCallAnimation()
    SendNUIMessage({
        action = "callEnded",
        reason = reason
    })
end)

RegisterNetEvent('npwd:clientCallFailed', function(reason)
    resetCallVoiceState()
    endCallAnimation()
    SendNUIMessage({
        action = "callFailed",
        reason = reason or "number_not_found"
    })
end)

--- Mudo da chamada: silencia (ou reativa) a voz do jogador para os demais da ligação.
RegisterNuiCallback('npwd:setCallMute', function(data, cb)
    local muted = data and data.muted == true
    isCallMuted = muted
    MumbleSetActive(not muted)
    cb({ success = true })
end)

--- Raio (em metros) para o viva voz captar quem está ao lado. 1m era pequeno
--- demais (praticamente sobreposto ao ped) e ninguém era detectado.
local SPEAKER_RADIUS = 2.8

--- Viva voz: calcula os jogadores dentro de SPEAKER_RADIUS e envia ao servidor
--- para que entrem/saiam do canal da chamada (ouvindo o interlocutor pelo
--- "alto-falante").
RegisterNuiCallback('npwd:setCallSpeaker', function(data, cb)
    local enabled = data and data.enabled == true
    local nearby = {}
    if enabled then
        local myId = GetPlayerServerId(PlayerId())
        local playerCoords = GetEntityCoords(PlayerPedId())
        local activePlayers = GetActivePlayers()
        for i = 1, #activePlayers do
            local targetPed = GetPlayerPed(activePlayers[i])
            local targetServerId = GetPlayerServerId(activePlayers[i])
            if targetServerId ~= myId and DoesEntityExist(targetPed) then
                if #(playerCoords - GetEntityCoords(targetPed)) <= SPEAKER_RADIUS then
                    nearby[#nearby + 1] = targetServerId
                end
            end
        end
    end
    TriggerServerEvent('npwd:serverSetSpeaker', enabled, nearby)
    cb({ success = true })
end)

--- Callback NUI para gerenciar foco do teclado ao digitar em inputs
RegisterNuiCallback('npwd:setNuiFocusInput', function(data, cb)
    local isFocused = data and data.focus == true
    if isFocused then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    else
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    end
    cb({ success = true })
end)

-- =======================================================
-- SISTEMA DE MENSAGENS / SMS (CLIENT-SIDE)
-- =======================================================

RegisterNuiCallback('npwd:getConversations', function(data, cb)
    lib.callback('npwd:getConversations', false, function(conversations)
        cb(conversations or {})
    end)
end)

RegisterNuiCallback('npwd:getMessages', function(data, cb)
    lib.callback('npwd:getMessages', false, function(result)
        cb(result or { conversationId = 0, messages = {} })
    end, data and data.conversationId, data and data.targetNumber)
end)

RegisterNuiCallback('npwd:sendMessage', function(data, cb)
    if data and data.message then
        TriggerServerEvent('npwd:serverSendMessage', data.targetNumber, data.message, data.conversationId)
    end
    cb({ success = true })
end)

RegisterNuiCallback('npwd:deleteConversation', function(data, cb)
    if data and data.conversationId then
        TriggerServerEvent('npwd:serverDeleteConversation', data.conversationId)
    end
    cb({ success = true })
end)

--- Repassa ao servidor o estado de digitação da conversa aberta.
RegisterNuiCallback('npwd:setTyping', function(data, cb)
    if data and data.targetNumber then
        TriggerServerEvent('npwd:serverSetTyping', data.targetNumber, data.typing == true)
    end
    cb({ success = true })
end)

RegisterNetEvent('npwd:clientReceiveMessage', function(msgData)
    SendNUIMessage({
        action = "receiveMessage",
        data = msgData
    })
end)

--- Recebe o estado "digitando" do outro participante e repassa à NUI.
RegisterNetEvent('npwd:clientTyping', function(senderNumber, senderName, isTyping)
    SendNUIMessage({
        action = "typing",
        data = {
            senderNumber = senderNumber,
            senderName = senderName,
            typing = isTyping == true
        }
    })
end)

RegisterNetEvent('npwd:onIncomingMessageNotification', function(senderName, messageText, senderNumber)
    PlaySoundFrontend(-1, "Event_Message_In", "GTAO_FM_Events_Soundset", 1)
    SendNUIMessage({
        app = "PHONE",
        method = "npwd:createNotification",
        data = {
            app = "messages",
            title = senderName or "Mensagem Recebida",
            content = messageText or "Você recebeu uma nova mensagem.",
            senderNumber = senderNumber
        }
    })
end)

-- =======================================================
-- BLOCO DE NOTAS (CLIENT-SIDE)
-- =======================================================

RegisterNuiCallback('npwd:getNotes', function(data, cb)
    lib.callback('npwd:getNotes', false, function(notes)
        cb(notes or {})
    end)
end)

RegisterNuiCallback('npwd:saveNote', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('npwd:serverSaveNote', {
            id = data.id,
            title = data.title,
            content = data.content,
            color = data.color
        })
    end
    cb({ success = true })
end)

RegisterNuiCallback('npwd:deleteNote', function(data, cb)
    if data and data.id then
        TriggerServerEvent('npwd:serverDeleteNote', data.id)
    end
    cb({ success = true })
end)

--- Compartilha a nota aberta com um jogador próximo (mesmo fluxo do contato).
RegisterNuiCallback('npwd:shareNote', function(data, cb)
    if not data or not data.targetId or type(data.note) ~= 'table' then
        cb({ success = false, message = "Selecione um jogador próximo." })
        return
    end
    TriggerServerEvent('npwd:serverShareNote', data.targetId, data.note)
    cb({ success = true, message = "Nota enviada." })
end)

--- Aceitar nota recebida via compartilhamento.
RegisterNuiCallback('npwd:acceptSharedNote', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('npwd:saveSharedNote', {
            title = data.title,
            content = data.content,
            color = data.color
        })
    end
    cb({ success = true })
end)

--- Recebe uma nota compartilhada do servidor e repassa à NUI.
RegisterNetEvent('npwd:clientReceiveSharedNote', function(noteData)
    SendNUIMessage({
        action = "receiveSharedNote",
        data = noteData
    })
end)

RegisterNetEvent('npwd:onIncomingNoteNotification', function(senderName, noteTitle)
    PlaySoundFrontend(-1, "Event_Message_In", "GTAO_FM_Events_Soundset", 1)
end)
