function VERSE.Commands._RegisterSV(name)
    local def = VERSE.Commands._list[name]
    if not def then return end
    if def.realm == "client" then return end

    def._sv_registered = def._sv_registered or false
    if def._sv_registered then return end
    def._sv_registered = true

    concommand.Add(name, function(ply, cmd, args, argStr)
        VERSE.Commands._Execute(name, ply, args, argStr)
    end)
end

util.AddNetworkString(VERSE.Commands.ReloadNet)
util.AddNetworkString(VERSE.Commands.ReloadFileNet)

local function collectHotReloadTargets(opt)
    opt = opt or {}
    if not (VERSE and VERSE.Hot and VERSE.Hot.CollectAll) then return {} end

    local filter = opt.filter
    local files = VERSE.Hot.CollectAll()
    local targets = {}
    if opt.forceAll then
        for _, p in ipairs(files) do
            if (not filter) or string.find(p, filter, 1, true) then
                targets[#targets + 1] = p
            end
        end
        return targets
    end

    local changed, added = VERSE.Hot.Diff(filter)
    for _, p in ipairs(added) do
        targets[#targets + 1] = p
    end

    for _, p in ipairs(changed) do
        targets[#targets + 1] = p
    end

    return targets
end

local function isClientReloadPath(fullPath)
    local fileName = string.GetFileFromFilename(fullPath or "")
    return string.StartWith(fileName, "cl_") or string.StartWith(fileName, "sh_")
end

local function sendClientHotReload(targets)
    local playersList = player.GetHumans()
    if #playersList == 0 then return end
    if not istable(targets) or #targets == 0 then return end

    for _, fullPath in ipairs(targets) do
        if isClientReloadPath(fullPath) then
            local body = file.Read(fullPath, "LUA")
            if not isstring(body) or body == "" then
                MsgN(("[VERSE] HotReload(client): skipped empty file %s"):format(tostring(fullPath)))
            else
                local payload = util.Compress(body)
                local payloadLen = payload and #payload or 0
                if payloadLen <= 0 then
                    MsgN(("[VERSE] HotReload(client): compress failed for %s"):format(tostring(fullPath)))
                elseif payloadLen >= 60000 then
                    MsgN(("[VERSE] HotReload(client): payload too large for %s (%d bytes)"):format(tostring(fullPath), payloadLen))
                else
                    net.Start(VERSE.Commands.ReloadFileNet)
                    net.WriteString(fullPath)
                    net.WriteUInt(payloadLen, 32)
                    net.WriteData(payload, payloadLen)
                    net.Send(playersList)
                end
            end
        end
    end
end

VERSE.Hook.AddNS("Commands", "Initialize", "VERSE::Initialize::Commands", function()
    for name, def in pairs(VERSE.Commands._list or {}) do
        if def.realm ~= "client" then
            VERSE.Commands._RegisterSV(name)
        end
    end
end)

VERSE.Commands.Add("verse_reload", function(ply, cmd, args)
    if IsValid(ply) and VERSE.Access and not VERSE.Access:IsDeveloper(ply) then return end

    VERSE.Flags = VERSE.Flags or {}
    VERSE.Flags.FullReload = false

    local opt = {
        restartModules = false,
        forceAll = false,
        filter = nil,
    }

    if args[1] == "-a" then
        opt.forceAll = true
        table.remove(args, 1)
    end

    if args[1] == "-m" then
        opt.restartModules = true
        table.remove(args, 1)
    end

    if args[1] == "-f" and args[2] then
        opt.filter = args[2]
    end

    local targets = collectHotReloadTargets(opt)
    local ok, n = VERSE.Hot.Reload(opt)
    sendClientHotReload(targets)
    MsgN(("[VERSE] verse_reload: ok=%s files=%d"):format(tostring(ok), tonumber(n) or 0))
end)
