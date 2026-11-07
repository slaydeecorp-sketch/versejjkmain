local Dev = VERSE.Dev
local Log = VERSE.Log
local L = VERSE.L

util.AddNetworkString(Dev.Net.Sync)
util.AddNetworkString(Dev.Net.Feedback)

local function plyName(ply)
    return IsValid(ply) and ply:Nick() or "Console"
end

local function sendFeedback(ply, msg, isError)
    net.Start(Dev.Net.Feedback)
    net.WriteString(tostring(msg))
    net.WriteBool(isError == true)
    net.Send(ply)
end

local function broadcast(msg)
    net.Start(Dev.Net.Feedback)
    net.WriteString(tostring(msg))
    net.WriteBool(false)
    net.Broadcast()
end

local syncCache = {}
local SYNC_INTERVAL = 2
local function collectStats()
    syncCache.tickrate = math.Round(1 / engine.TickInterval())
    syncCache.server_fps = math.Round(1 / FrameTime())
    syncCache.player_count = #player.GetAll()
    syncCache.max_players = game.MaxPlayers()
    syncCache.map = game.GetMap()
    syncCache.uptime = math.floor(CurTime())
    syncCache.ent_count = #ents.GetAll()
    syncCache.sv_hostname = GetConVar("hostname"):GetString()
    syncCache.password_locked = Dev.State.Locked and 1 or 0
    local netStats = net.GetStatistics and net.GetStatistics() or nil
    if netStats then
        syncCache.net_in = math.Round((netStats.IncomingSize or 0) / 1024, 1)
        syncCache.net_out = math.Round((netStats.OutgoingSize or 0) / 1024, 1)
    else
        syncCache.net_in = 0
        syncCache.net_out = 0
    end
    syncCache.ns_hooks  = table.Count(netstream.stored)
    syncCache.ns_sent   = netstream.stats.sent
    syncCache.ns_recv   = netstream.stats.received
    syncCache.ns_errors = netstream.stats.errors
end

local function sendSync(ply)
    net.Start(Dev.Net.Sync)
    net.WriteUInt(table.Count(syncCache), 8)
    for k, v in pairs(syncCache) do
        net.WriteString(tostring(k))
        net.WriteString(tostring(v))
    end

    net.Send(ply)
end

VERSE.Timers.CreateNS("Dev", "VERSE::Dev::SyncStats", SYNC_INTERVAL, 0, function()
    collectStats()
    for _, ply in ipairs(player.GetAll()) do
        if ply:IsDeveloper() then sendSync(ply) end
    end
end)

Dev.RegisterAction("password", {
    Description = "Set or remove server password",
    Permission = "developer",
    Usage = "verse_dev password [password]",
    Execute = function(ply, args)
        local pw = args[1] or ""
        if pw == "" then
            Dev.State.Password = ""
            Dev.State.Locked = false
            RunConsoleCommand("sv_password", "")
            Log:Info("[Dev]", L("dev.password_log_removed", {
                player = plyName(ply)
            }))
            return true, L(ply, "dev.password_removed")
        end

        Dev.State.Password = pw
        Dev.State.Locked = true
        RunConsoleCommand("sv_password", pw)
        Log:Info("[Dev]", L("dev.password_log_set", {
            player = plyName(ply)
        }))
        return true, L(ply, "dev.password_set", {
            password = pw
        })
    end,
})

Dev.RegisterAction("whitelist", {
    Description = "Manage password whitelist (add/remove/list SteamIDs)",
    Permission = "developer",
    Usage = "verse_dev whitelist <add/remove/list> [steamid]",
    Execute = function(ply, args)
        local sub = args[1] or ""
        if sub == "list" then
            if table.Count(Dev.State.Whitelist) == 0 then return true, L(ply, "dev.whitelist_empty") end
            local lines = {L(ply, "dev.whitelist_header")}
            for sid, _ in pairs(Dev.State.Whitelist) do
                table.insert(lines, " - " .. sid)
            end
            return true, table.concat(lines, "\n")
        end

        local sid = args[2] or ""
        if sid == "" then return false, L(ply, "dev.whitelist_steamid_required") end
        if sub == "add" then
            Dev.State.Whitelist[sid] = true
            Log:Info("[Dev]", L("dev.whitelist_log_add", {
                steamid = sid,
                player = plyName(ply)
            }))
            return true, L(ply, "dev.whitelist_added", {
                steamid = sid
            })
        elseif sub == "remove" then
            Dev.State.Whitelist[sid] = nil
            Log:Info("[Dev]", L("dev.whitelist_log_remove", {
                steamid = sid,
                player = plyName(ply)
            }))
            return true, L(ply, "dev.whitelist_removed", {
                steamid = sid
            })
        end
        return false, L(ply, "dev.whitelist_usage")
    end,
})

Dev.RegisterAction("slots", {
    Description = "Change max player slots (visual only, requires restart for real change)",
    Permission = "developer",
    Usage = "verse_dev slots <number>",
    Execute = function(ply, args)
        local n = tonumber(args[1])
        if not n or n < 1 or n > 128 then return false, L(ply, "dev.slots_invalid") end
        n = math.floor(n)
        RunConsoleCommand("maxplayers", tostring(n))
        Log:Info("[Dev]", L("dev.slots_log", {
            count = n,
            player = plyName(ply)
        }))
        return true, L(ply, "dev.slots_set", {
            count = n
        })
    end,
})

Dev.RegisterAction("hostname", {
    Description = "Change server hostname",
    Permission = "developer",
    Usage = "verse_dev hostname <name>",
    Execute = function(ply, args)
        local name = table.concat(args, " ")
        if name == "" then return false, L(ply, "dev.hostname_empty") end
        RunConsoleCommand("hostname", name)
        Log:Info("[Dev]", L("dev.hostname_log", {
            name = name,
            player = plyName(ply)
        }))
        return true, L(ply, "dev.hostname_set", {
            name = name
        })
    end,
})

Dev.RegisterAction("map", {
    Description = "Change current map",
    Permission = "developer",
    Usage = "verse_dev map <mapname>",
    Execute = function(ply, args)
        local mapName = args[1] or ""
        if mapName == "" then return false, L(ply, "dev.map_required") end
        Log:Info("[Dev]", L("dev.map_log", {
            map = mapName,
            player = plyName(ply)
        }))

        broadcast(L("dev.map_changing", {
            map = mapName
        }))

        timer.Simple(1, function() RunConsoleCommand("changelevel", mapName) end)
        return true, L(ply, "dev.map_changing", {
            map = mapName
        })
    end,
})

Dev.RegisterAction("gravity", {
    Description = "Set server gravity",
    Permission = "developer",
    Usage = "verse_dev gravity <number>",
    Execute = function(ply, args)
        local g = tonumber(args[1])
        if not g then return false, L(ply, "dev.gravity_invalid") end
        RunConsoleCommand("sv_gravity", tostring(g))
        Log:Info("[Dev]", L("dev.gravity_log", {
            value = g,
            player = plyName(ply)
        }))
        return true, L(ply, "dev.gravity_set", {
            value = g
        })
    end,
})

Dev.RegisterAction("noclip", {
    Description = "Toggle noclip for all or specific access level",
    Permission = "developer",
    Usage = "verse_dev noclip [0/1]",
    Execute = function(ply, args)
        local val = args[1]
        if val == "0" then
            RunConsoleCommand("sbox_noclip", "0")
            return true, L(ply, "dev.noclip_disabled")
        elseif val == "1" then
            RunConsoleCommand("sbox_noclip", "1")
            return true, L(ply, "dev.noclip_enabled")
        end

        local current = GetConVar("sbox_noclip"):GetBool()
        RunConsoleCommand("sbox_noclip", current and "0" or "1")
        return true, L(ply, "dev.noclip_toggled", {
            state = L(ply, current and "dev.state_off" or "dev.state_on")
        })
    end,
})

Dev.RegisterAction("pvp", {
    Description = "Toggle PvP (friendly fire)",
    Permission = "developer",
    Usage = "verse_dev pvp [0/1]",
    Execute = function(ply, args)
        local val = args[1]
        if val == "0" then
            RunConsoleCommand("sbox_playershurtplayers", "0")
            return true, L(ply, "dev.pvp_disabled")
        elseif val == "1" then
            RunConsoleCommand("sbox_playershurtplayers", "1")
            return true, L(ply, "dev.pvp_enabled")
        end

        local current = GetConVar("sbox_playershurtplayers"):GetBool()
        RunConsoleCommand("sbox_playershurtplayers", current and "0" or "1")
        return true, L(ply, "dev.pvp_toggled", {
            state = L(ply, current and "dev.state_off" or "dev.state_on")
        })
    end,
})

Dev.RegisterAction("godmode", {
    Description = "Toggle god mode for yourself or a player",
    Permission = "developer",
    Usage = "verse_dev godmode [player name]",
    Execute = function(ply, args)
        local target = ply
        if args[1] and args[1] ~= "" then
            local found = nil
            local search = string.lower(args[1])
            for _, p in ipairs(player.GetAll()) do
                if string.find(string.lower(p:Nick()), search, 1, true) then
                    found = p
                    break
                end
            end

            if not IsValid(found) then
                return false, L(ply, "dev.godmode_player_not_found", {
                    search = args[1]
                })
            end

            target = found
        end

        if not IsValid(target) then return false, L(ply, "dev.godmode_no_target") end
        local hasGod = target:HasGodMode()
        if hasGod then
            target:GodDisable()
        else
            target:GodEnable()
        end

        local stateKey = hasGod and "dev.godmode_disabled" or "dev.godmode_enabled"
        Log:Info("[Dev]", L("dev.godmode_log", {
            state = L(stateKey),
            target = target:Nick(),
            player = plyName(ply)
        }))
        return true, L(ply, "dev.godmode_toggled", {
            state = L(ply, stateKey),
            player = target:Nick()
        })
    end,
})

Dev.RegisterAction("kick", {
    Description = "Kick a player from the server",
    Permission = "staff",
    Usage = "verse_dev kick <player name> [reason]",
    Execute = function(ply, args)
        local search = args[1]
        if not search or search == "" then return false, L(ply, "dev.kick_name_required") end
        local reason = #args > 1 and table.concat(args, " ", 2) or L(ply, "dev.kick_default_reason")
        local found = nil
        search = string.lower(search)
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), search, 1, true) then
                found = p
                break
            end
        end

        if not IsValid(found) then
            return false, L(ply, "dev.kick_player_not_found", {
                search = args[1]
            })
        end

        Log:Info("[Dev]", L("dev.kick_log", {
            target = found:Nick(),
            reason = reason,
            player = plyName(ply)
        }))

        found:Kick(reason)
        return true, L(ply, "dev.kick_done", {
            player = found:Nick(),
            reason = reason
        })
    end,
})

Dev.RegisterAction("debug", {
    Description = "Toggle VERSE debug mode",
    Permission = "developer",
    Usage = "verse_dev debug [0/1]",
    Execute = function(ply, args)
        local val = args[1]
        if val == "0" then
            VERSE.Config.Debug = false
            VERSE.Config.LogLevel = "info"
            return true, L(ply, "dev.debug_off")
        elseif val == "1" then
            VERSE.Config.Debug = true
            VERSE.Config.LogLevel = "debug"
            return true, L(ply, "dev.debug_on")
        end

        VERSE.Config.Debug = not VERSE.Config.Debug
        VERSE.Config.LogLevel = VERSE.Config.Debug and "debug" or "info"
        local state = L(ply, VERSE.Config.Debug and "dev.state_on" or "dev.state_off")
        return true, L(ply, "dev.debug_toggled", {
            state = state,
            level = VERSE.Config.LogLevel
        })
    end,
})

Dev.RegisterAction("status", {
    Description = "Show server status overview",
    Permission = "staff",
    Usage = "verse_dev status",
    Execute = function(ply, args)
        local on = L(ply, "dev.state_on")
        local off = L(ply, "dev.state_off")
        local lines = {}
        table.insert(lines, L(ply, "dev.status_header"))
        table.insert(lines, L(ply, "dev.status_hostname", {
            value = GetConVar("hostname"):GetString()
        }))

        table.insert(lines, L(ply, "dev.status_map", {
            value = game.GetMap()
        }))

        table.insert(lines, L(ply, "dev.status_players", {
            current = #player.GetAll(),
            max = game.MaxPlayers()
        }))

        table.insert(lines, L(ply, "dev.status_tickrate", {
            value = math.Round(1 / engine.TickInterval())
        }))

        table.insert(lines, L(ply, "dev.status_uptime", {
            value = string.FormattedTime(CurTime(), "%02i:%02i:%02i")
        }))

        table.insert(lines, L(ply, "dev.status_password", {
            value = L(ply, Dev.State.Locked and "dev.status_password_set" or "dev.status_password_none")
        }))

        table.insert(lines, L(ply, "dev.status_gravity", {
            value = GetConVar("sv_gravity"):GetString()
        }))

        table.insert(lines, L(ply, "dev.status_pvp", {
            value = GetConVar("sbox_playershurtplayers"):GetBool() and on or off
        }))

        table.insert(lines, L(ply, "dev.status_debug", {
            value = VERSE.Config.Debug and on or off
        }))
        return true, table.concat(lines, "\n")
    end,
})

Dev.RegisterAction("netstream", {
    Description = "Show netstream stats or list registered hooks",
    Permission = "developer",
    Usage = "verse_dev netstream [hooks|stats]",
    Execute = function(ply, args)
        local sub = args[1] or "stats"

        if sub == "hooks" then
            local names = {}
            for name, _ in pairs(netstream.stored) do
                table.insert(names, name)
            end
            table.sort(names)
            if #names == 0 then
                return true, L(ply, "dev.netstream_no_hooks")
            end
            local lines = { L(ply, "dev.netstream_hooks_header", { count = #names }) }
            for _, name in ipairs(names) do
                table.insert(lines, "  - " .. name)
            end
            return true, table.concat(lines, "\n")
        end

        local lines = {
            L(ply, "dev.netstream_header"),
            L(ply, "dev.netstream_hooks",  { count = table.Count(netstream.stored) }),
            L(ply, "dev.netstream_sent",   { count = netstream.stats.sent }),
            L(ply, "dev.netstream_recv",   { count = netstream.stats.received }),
            L(ply, "dev.netstream_errors", { count = netstream.stats.errors }),
        }
        return true, table.concat(lines, "\n")
    end,
})

Dev.RegisterAction("help", {
    Description = "List all dev commands",
    Permission = "staff",
    Usage = "verse_dev help",
    Execute = function(ply, args)
        local lines = {L(ply, "dev.help_header")}
        for _, action in ipairs(Dev.GetActions()) do
            local perm = action.Permission or "developer"
            table.insert(lines, (" %s [%s] - %s"):format(action.ID, perm, action.Description))
            if action.Usage and action.Usage ~= "" then table.insert(lines, ("   > %s"):format(action.Usage)) end
        end
        return true, table.concat(lines, "\n")
    end,
})

VERSE.Hook.AddNS("Dev", "CheckPassword", "VERSE::CheckPassword::Dev", function(steamID64, ipAddress, svPassword, clPassword, name)
    if not Dev.State.Locked then return end
    if Dev.State.Password == "" then return end
    local sid = util.SteamIDFrom64(steamID64)
    if VERSE.Config.Access and VERSE.Config.Access.Developers then
        for _, devSID in ipairs(VERSE.Config.Access.Developers) do
            if sid == devSID then return end
        end
    end

    if Dev.State.Whitelist[sid] then return end
    if Dev.State.Whitelist[steamID64] then return end
    if clPassword ~= Dev.State.Password then return false, L("dev.server_locked") end
end)

VERSE.Commands.Add("verse_dev", function(ply, args, argStr)
    local actionID = args[1]
    if not actionID or actionID == "" then
        VERSE.Commands._Execute("verse_dev", ply, {"help"}, "help")
        return
    end

    table.remove(args, 1)
    local action = Dev.GetAction(actionID)
    if not action then
        sendFeedback(ply, L(ply, "dev.unknown_action", {
            action = actionID
        }), true)
        return
    end

    local perm = action.Permission or "developer"
    local hasPerm = false
    if not IsValid(ply) then
        hasPerm = true
    elseif perm == "developer" and ply:IsDeveloper() then
        hasPerm = true
    elseif perm == "staffplus" and (ply:IsStaffPlus() or ply:IsDeveloper()) then
        hasPerm = true
    elseif perm == "staff" and (ply:IsStaff() or ply:IsStaffPlus() or ply:IsDeveloper()) then
        hasPerm = true
    end

    if not hasPerm then
        sendFeedback(ply, L(ply, "dev.no_permission", {
            action = actionID
        }), true)
        return
    end

    local ok, msg = action.Execute(ply, args)
    if IsValid(ply) then
        sendFeedback(ply, msg or (ok and "Done" or "Failed"), not ok)
    else
        MsgN("[VERSE][Dev] " .. (msg or (ok and "Done" or "Failed")))
    end
end, "staff", "server")