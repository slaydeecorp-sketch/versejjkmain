local T = VERSE.TalkMode
local meta = FindMetaTable("Player")
local nextChangeAt = {}
local initDone = {}
local function CanChange(ply)
    local t = CurTime()
    local at = nextChangeAt[ply] or 0
    if t < at then return false end
    nextChangeAt[ply] = t + 0.35
    return true
end

local function BroadcastMode(ply, id)
    netstream.Start(nil, T.Net.Mode, ply:EntIndex(), tostring(id))
end

function meta:SetTalkMode(id, silent)
    id = T:Normalize(id)
    self:SetPublicString(T.NW_KEY, id)
    if not silent then BroadcastMode(self, id) end
    return id
end

function meta:CycleTalkMode(step, silent)
    local id = self:GetTalkMode()
    local nextId = T:Next(id, step or 1)
    return self:SetTalkMode(nextId, silent)
end

VERSE.Hook.AddNS("TalkMode", "PlayerInitialSpawn", "VERSE::PlayerInitialSpawn::TalkMode", function(ply)
    initDone[ply] = nil
    ply:SetTalkMode(T.DefaultId, true)
end)

VERSE.Hook.AddNS("TalkMode", "PlayerDisconnected", "VERSE::PlayerDisconnected::TalkMode", function(ply)
    nextChangeAt[ply] = nil
    initDone[ply] = nil
end)

netstream.Hook(T.Net.Cmd, function(ply, op, id)
    if not IsValid(ply) then return end
    op = tonumber(op) or 0
    if op == 3 then
        if initDone[ply] then return end
        initDone[ply] = true
        local normalized = T:Normalize(id)
        ply:SetTalkMode(normalized, true)
        return
    end

    if not CanChange(ply) then return end
    if op == 0 then
        ply:SetTalkMode(id)
    elseif op == 1 then
        ply:CycleTalkMode(1)
    elseif op == 2 then
        ply:CycleTalkMode(-1)
    end
end)

VERSE.Commands.Add("verse_talkmode", function(ply, _, args)
    if not IsValid(ply) then return end
    if not CanChange(ply) then return end
    local sub = tostring(args[1] or ""):lower()
    if sub == "" then
        ply:CycleTalkMode(1)
        return
    end

    if sub == "set" then
        ply:SetTalkMode(args[2])
        return
    end

    if sub == "next" then
        ply:CycleTalkMode(1)
        return
    end

    if sub == "prev" then
        ply:CycleTalkMode(-1)
        return
    end
end)