VERSE.Voice = VERSE.Voice or {}
local Voice = VERSE.Voice

Voice.Net = Voice.Net or {
    Sync = "VERSE::Voice::Sync",
}

Voice.Config = Voice.Config or {
    Enabled = true,
    Spatial = true,
    UseLOS = false,
    AdminHearAll = false,
    Debug = false,
}

local meta = FindMetaTable("Player")

function meta:GetVoiceModeId()
    local T = VERSE.TalkMode
    if not T then return "Normal" end
    return self:GetNW2String(T.NW_KEY, T.DefaultId or "Normal")
end