VERSE.TalkMode = VERSE.TalkMode or {}
local T = VERSE.TalkMode

T.NET_TAG = T.NET_TAG or "VERSE::TalkMode"
T.NW_KEY = T.NW_KEY or "VERSE.TalkMode"
T.CK_KEY = T.CK_KEY or "verse_talkmode"

T.Net = T.Net or {
    Cmd = "VERSE::TalkMode::Cmd",
    Mode = "VERSE::TalkMode::Mode",
}

T.Config = {
    Visual = {
        Enabled = true,
        ShowWhileSpeaking = false,
        ShowOnModeChange = true,
        ExpandTime = 0.2,
        PreviewTime = 1,
        FadeOutTime = 0.3,
        Segments = 96,
        RingWidth = 28,
        GroundOffset = 2,
        AlphaSpeaking = 170,
        AlphaPreview = 140,
    },
}

T.Modes = {
    {
        id = "Whisper",
        name = "Chuchoter",
        chatPrefix = "[Chuchoter] ",
        range = 250,
        hud = { icon = "hud_whisper_voice", iw = 15, ih = 19 },
        visual = { enabled = true, color = Color(255, 255, 0), style = "disc" },
    },
    {
        id = "Normal",
        name = "Parler",
        chatPrefix = "",
        range = 600,
        hud = { icon = "hud_default_voice", iw = 20, ih = 21 },
        visual = { enabled = true, color = Color(0, 255, 0), style = "disc" },
    },
    {
        id = "Yell",
        name = "Crier",
        chatPrefix = "[Crier] ",
        range = 1000,
        hud = { icon = "hud_yell_voice", iw = 24, ih = 21 },
        visual = { enabled = true, color = Color(255, 0, 0), style = "disc" },
    },
}

T.DefaultId = T.DefaultId or "Normal"

function T:Normalize(id)
    id = tostring(id or "")
    if id == "" then return self.DefaultId end
    for _, m in ipairs(self.Modes) do
        if m.id == id then return m.id end
    end
    return self.DefaultId
end

function T:GetIndex(id)
    id = self:Normalize(id)
    for i, m in ipairs(self.Modes) do
        if m.id == id then return i end
    end
    return 1
end

function T:Next(id, step)
    step = tonumber(step) or 1
    local idx = self:GetIndex(id)
    local n = #self.Modes
    idx = ((idx - 1 + step) % n) + 1
    return self.Modes[idx].id
end

function T:GetData(id)
    id = self:Normalize(id)
    for _, m in ipairs(self.Modes) do
        if m.id == id then return m end
    end
    return self.Modes[self:GetIndex(self.DefaultId)]
end

function T:GetRange(id)
    local d = self:GetData(id)
    return tonumber(d.range) or 600
end

function T:CanHear(listener, speaker, speakerModeId)
    if not IsValid(listener) or not IsValid(speaker) then return false end
    local r = self:GetRange(speakerModeId or speaker:GetTalkMode())
    return listener:GetPos():DistToSqr(speaker:GetPos()) <= (r * r)
end

local meta = FindMetaTable("Player")

function meta:GetTalkMode()
    local v = self:GetPublicString(T.NW_KEY, T.DefaultId)
    return T:Normalize(v)
end

function meta:GetTalkModeData()
    return T:GetData(self:GetTalkMode())
end

function meta:GetTalkRange()
    return T:GetRange(self:GetTalkMode())
end