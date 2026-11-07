local Voice = VERSE.Voice

util.AddNetworkString(Voice.Net.Sync)

local function HasLOS(listener, speaker)
    if not Voice.Config.UseLOS then return true end
    if not (IsValid(listener) and IsValid(speaker)) then return false end

    local startPos = listener:EyePos()
    local endPos = speaker:EyePos()

    local tr = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = { listener, speaker },
        mask = MASK_SOLID_BRUSHONLY
    })

    return not tr.Hit
end

local function CanHear(listener, speaker)
    if not Voice.Config.Enabled then return false end
    if not (IsValid(listener) and IsValid(speaker)) then return false end
    if not (listener:IsPlayer() and speaker:IsPlayer()) then return false end
    if listener == speaker then return true end
    if not listener:Alive() then return false end
    if Voice.Config.AdminHearAll and listener:IsStaff() then return true end
    local modeId = speaker:GetTalkMode()
    if not VERSE.TalkMode:CanHear(listener, speaker, modeId) then return false end
    if not HasLOS(listener, speaker) then return false end
    return true
end

VERSE.Hook.AddNS("Voice", "PlayerCanHearPlayersVoice", "VERSE::PlayerCanHearPlayersVoice::Voice", function(listener, speaker)
    local ok = CanHear(listener, speaker)
    if not ok then return false, false end
    return true, Voice.Config.Spatial and true or false
end)

local speaking = speaking or {}
VERSE.Hook.AddNS("Voice", "PlayerStartVoice", "VERSE::PlayerStartVoice::Voice", function(ply)
    if not IsValid(ply) then return end
    speaking[ply] = true
    net.Start(Voice.Net.Sync)
        net.WriteEntity(ply)
        net.WriteBool(true)
    net.Broadcast()
end)

VERSE.Hook.AddNS("Voice", "PlayerEndVoice", "VERSE::PlayerEndVoice::Voice", function(ply)
    if not IsValid(ply) then return end
    speaking[ply] = nil
    net.Start(Voice.Net.Sync)
        net.WriteEntity(ply)
        net.WriteBool(false)
    net.Broadcast()
end)