VERSE.Dev = VERSE.Dev or {}
local Dev = VERSE.Dev

Dev.Net = {
    Sync = "VERSE::Dev::Sync",
    Feedback = "VERSE::Dev::Feedback",
}

Dev.Actions = Dev.Actions or {}

Dev.State = {
    Password = "",
    Locked = false,
    Whitelist = {},
}

function Dev.RegisterAction(id, tbl)
    if not id or id == "" then return end
    if not istable(tbl) then return end
    if not isfunction(tbl.Execute) then return end
    tbl.ID = id
    tbl.Permission = tbl.Permission or "developer"
    tbl.Description = tbl.Description or ""
    tbl.Realm = tbl.Realm or "server"
    Dev.Actions[id] = tbl
end

function Dev.GetAction(id)
    return Dev.Actions[id]
end

function Dev.GetActions()
    local out = {}
    for id, action in pairs(Dev.Actions) do
        table.insert(out, action)
    end

    table.sort(out, function(a, b) return a.ID < b.ID end)
    return out
end

Dev.SyncKeys = {"tickrate", "server_fps", "player_count", "max_players", "map", "uptime", "ent_count", "net_in", "net_out", "sv_hostname", "password_locked", "ns_hooks", "ns_sent", "ns_recv", "ns_errors"}