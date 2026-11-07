VERSE.DynaBase = VERSE.DynaBase or {}
local DB = VERSE.DynaBase

util.AddNetworkString("VERSE.DynaBase.Sync")
util.AddNetworkString("VERSE.DynaBase.Apply")

local flags = { FCVAR_REPLICATED, FCVAR_ARCHIVE }
local c_enforce = CreateConVar("verse_dynabase_enforce", "0", flags, "0 = client may use local prefs, 1 = server enforces enabled packs & order")
local c_enabled = CreateConVar("verse_dynabase_enabled", "", flags, "Comma separated pack ids to enable (only used when enforce=1). Empty = enable all registered packs.")
local c_order = CreateConVar("verse_dynabase_order", "", flags, "Comma separated pack ids order (only used when enforce=1). Others appended.")

local function csvToList(s)
    s = tostring(s or "")
    if s == "" then return {} end
    local out, seen = {}, {}
    for _, v in ipairs(string.Explode(",", s)) do
        v = string.Trim(v)
        if v ~= "" and not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    return out
end

local function BuildServerPolicy()
    if not c_enforce:GetBool() then return nil end

    local enabledList = csvToList(c_enabled:GetString())
    local orderList = csvToList(c_order:GetString())

    local enabled = {}
    if #enabledList > 0 then
        for _, id in ipairs(enabledList) do enabled[id] = true end
    else
        for id, _ in pairs(DB.Packs) do enabled[id] = true end
    end

    local order, seen = {}, {}
    for _, id in ipairs(orderList) do
        if DB.Packs[id] and not seen[id] then
            seen[id] = true
            order[#order + 1] = id
        end
    end
    for _, id in ipairs(DB.PackOrder) do
        if DB.Packs[id] and not seen[id] then
            order[#order + 1] = id
        end
    end

    return { enabled = enabled, order = order }
end

local function SendPolicy(ply)
    local policy = BuildServerPolicy()

    net.Start("VERSE.DynaBase.Sync")
    net.WriteBool(policy ~= nil)

    if policy then
        net.WriteUInt(#policy.order, 16)
        for _, id in ipairs(policy.order) do net.WriteString(id) end

        local cnt = 0
        for _ in pairs(policy.enabled) do cnt = cnt + 1 end
        net.WriteUInt(cnt, 16)
        for id, st in pairs(policy.enabled) do
            net.WriteString(id)
            net.WriteBool(st and true or false)
        end
    end

    net.Send(ply)
end

VERSE.Hook.AddNS("Dynabase", "PlayerInitialSpawn", "VERSE.DynaBase.SyncOnJoin", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        SendPolicy(ply)
    end)
end)

local function ForceApplyClients()
    net.Start("VERSE.DynaBase.Apply")
    net.Broadcast()
end

cvars.AddChangeCallback("verse_dynabase_enforce", function() ForceApplyClients() end, "VERSE.DynaBase")
cvars.AddChangeCallback("verse_dynabase_enabled", function() ForceApplyClients() end, "VERSE.DynaBase")
cvars.AddChangeCallback("verse_dynabase_order", function() ForceApplyClients() end, "VERSE.DynaBase")

VERSE.Commands.Add("verse_dynabase_apply_all", function(ply)
    if IsValid(ply) and not ply:IsDeveloper() then return end
    ForceApplyClients()
end)