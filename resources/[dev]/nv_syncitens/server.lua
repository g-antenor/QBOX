local savedAttachments = {}
local dbFileName = "data.json"

-- Save attachments to data.json
local function saveDatabase()
    local ok, jsonStr = pcall(json.encode, savedAttachments, { indent = true })
    if ok then
        SaveResourceFile(GetCurrentResourceName(), dbFileName, jsonStr, -1)
    else
        print("^1[nv_syncitens] Erro ao codificar banco de dados para salvar.^7")
    end
end

-- Load attachments from data.json on startup
local function loadDatabase()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), dbFileName)
    if fileContent then
        local ok, data = pcall(json.decode, fileContent)
        if ok and type(data) == "table" then
            savedAttachments = data
            local count = 0
            local migrated = false
            for model, anims in pairs(data) do
                for animName, val in pairs(anims) do
                    count = count + 1
                    if val.name == nil then
                        val.name = ""
                        migrated = true
                    end
                end
            end
            if migrated then
                saveDatabase()
                print("^2[nv_syncitens] Banco de dados migrado: Adicionados campos 'name' em branco aos registros existentes.^7")
            end
            print(string.format("^2[nv_syncitens] Banco de dados carregado. %d alinhamentos de props salvos.^7", count))
        else
            print("^1[nv_syncitens] Erro ao decodificar data.json. Inicializando banco vazio.^7")
            savedAttachments = {}
        end
    else
        -- Create default empty file
        SaveResourceFile(GetCurrentResourceName(), dbFileName, "{}", -1)
        savedAttachments = {}
        print("^3[nv_syncitens] Banco de dados data.json não encontrado. Criado arquivo padrão vazio.^7")
    end
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        loadDatabase()
    end
end)

-- Sync data to client when requested
RegisterNetEvent("nv_syncitens:server:requestSync", function()
    local src = source
    TriggerClientEvent("nv_syncitens:client:syncAttachments", src, savedAttachments)
end)

-- Register new attachment details
RegisterNetEvent("nv_syncitens:server:saveAttachment", function(model, animName, data)
    local src = source
    
    if not savedAttachments[model] then
        savedAttachments[model] = {}
    end
    
    savedAttachments[model][animName] = data
    saveDatabase()
    
    -- Sync updated database to all connected clients
    TriggerClientEvent("nv_syncitens:client:syncAttachments", -1, savedAttachments)
    
    TriggerClientEvent("chat:addMessage", src, {
        color = { 0, 255, 0},
        multiline = true,
        args = { "nv_syncitens", string.format("Ajuste do item '%s' para a animação '%s' registrado globalmente no banco de dados!", model, animName) }
    })
end)
