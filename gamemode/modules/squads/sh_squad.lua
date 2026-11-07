VERSE.Squads = VERSE.Squads or {}
local SQ = VERSE.Squads
SQ.Config = {
    MaxMembers = 5,
    InviteRadius = 1500,
    InviteTimeout = 30,
    MaxNameLength = 30,
}

SQ.Net = {
    Create = "VERSE::Squad::Create",
    Invite = "VERSE::Squad::Invite",
    InviteRes = "VERSE::Squad::InviteResponse",
    Leave = "VERSE::Squad::Leave",
    Kick = "VERSE::Squad::Kick",
    Rename = "VERSE::Squad::Rename",
    ToggleDmg = "VERSE::Squad::ToggleDamage",
    ToggleVoice = "VERSE::Squad::ToggleVoice",
    ToggleMic = "VERSE::Squad::ToggleMic",
    ToggleListen = "VERSE::Squad::ToggleListen",
    NearbyReq = "VERSE::Squad::NearbyRequest",
    Sync = "VERSE::Squad::Sync",
    InviteNotify = "VERSE::Squad::InviteNotify",
    NearbyList = "VERSE::Squad::NearbyList",
}

SQ.NW = {
    SquadId = "VERSE.Squad.Id",
    SquadVoice = "VERSE.Squad.Voice",
    SquadMicOn = "VERSE.Squad.MicOn",
    SquadListen = "VERSE.Squad.Listen",
}

local PLAYER = FindMetaTable("Player")
function PLAYER:GetSquadId()
    return self:GetNWString(SQ.NW.SquadId, "")
end

function PLAYER:IsInSquad()
    return self:GetSquadId() ~= ""
end

function PLAYER:HasSquadVoice()
    return self:GetNWBool(SQ.NW.SquadVoice, false)
end

function PLAYER:IsSquadMicOn()
    return self:GetNWBool(SQ.NW.SquadMicOn, true)
end

function PLAYER:IsSquadListenOn()
    return self:GetNWBool(SQ.NW.SquadListen, true)
end

function PLAYER:InSameSquad(other)
    if not IsValid(other) then return false end
    local sid = self:GetSquadId()
    return sid ~= "" and sid == other:GetSquadId()
end