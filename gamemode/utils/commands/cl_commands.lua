local function logReloadErr(...)
    if VERSE and VERSE.Log and VERSE.Log.Error then
        VERSE.Log:Error(...)
    else
        MsgN(...)
    end
end

local function runClientHotChunk(fullPath, body)
    if not isstring(fullPath) or fullPath == "" then return false, "bad_path" end
    if not isstring(body) or body == "" then return false, "empty_body" end

    if VERSE and VERSE.Hook then VERSE.Hook.Call("PreHotReloadFile", fullPath) end
    local chunk = CompileString(body, "@" .. fullPath, false)
    if isstring(chunk) then
        if VERSE and VERSE.Hook then VERSE.Hook.Call("PostHotReloadFile", fullPath) end
        return false, chunk
    end

    local ok, err = pcall(chunk)
    if VERSE and VERSE.Hook then VERSE.Hook.Call("PostHotReloadFile", fullPath) end
    if not ok then return false, err end
    return true
end

net.Receive(VERSE.Commands.ReloadFileNet, function()
    local fullPath = net.ReadString()
    local payloadLen = net.ReadUInt(32)
    if payloadLen <= 0 then
        logReloadErr("[VERSE] HotReload(client): empty payload for ", tostring(fullPath))
        return
    end

    local payload = net.ReadData(payloadLen)
    local body = payload and util.Decompress(payload) or nil
    if not body then
        logReloadErr("[VERSE] HotReload(client): decompress failed for ", tostring(fullPath))
        return
    end

    local ok, err = runClientHotChunk(fullPath, body)
    if not ok then
        logReloadErr("[VERSE] HotReload(client) failed: ", tostring(fullPath), " -> ", tostring(err))
        return
    end

    MsgN(("[VERSE] HotReload(client): %s"):format(tostring(fullPath)))
end)

function VERSE.Commands._RegisterCL(name)
    local def = VERSE.Commands._list[name]
    if not def then return end
    if def.realm == "server" then return end

    def._cl_registered = def._cl_registered or false
    if def._cl_registered then return end
    def._cl_registered = true

    concommand.Add(name, function(ply, cmd, args, argStr)
        VERSE.Commands._Execute(name, LocalPlayer(), args, argStr)
    end)
end

VERSE.Hook.AddNS("Commands", "InitPostEntity", "VERSE::InitPostEntity::Commands", function()
    for name, def in pairs(VERSE.Commands._list or {}) do
        if def.realm ~= "server" then
            VERSE.Commands._RegisterCL(name)
        end
    end
end)
