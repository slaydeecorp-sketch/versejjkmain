local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local CFG = VERSE.KillHUD.Config

local FRAME_W, FRAME_H = 402, 78
local FRAME_X, FRAME_Y = (1920 - FRAME_W) * 0.5, 850
local TOP_TEXT = "VOUS AVEZ TUER"
local TOP_LETTER_SPACING = 16
local FADE_IN = CFG.FadeIn or 0.25
local FADE_OUT = CFG.FadeOut or 0.4
local DURATION = CFG.Duration or 2

local MAT_KILLHUD = "killhud1"

VERSE.Hook.AddNS("KillHUD", "HUDShouldDraw", "VERSE::HUDShouldDraw::KillHUD", function(name)
    if name == "CHudDeathNotice" then return false end
end)

VERSE.Hook.AddNS("KillHUD", "DrawDeathNotice", "VERSE::DrawDeathNotice::KillHUD", function()
    return true
end)

local bgColor = Color(255, 255, 255, 255)
local textColor = Color(255, 93, 93, 229)
local subColor = Color(235, 235, 235, 220)

local State = {
    active = false,
    startAt = 0, endAt = 0,
    name = "",
    x = 0, y = 0, w = 0, h = 0,
    cx = 0, topY = 0, nameY = 0,
    topFont = nil, nameFont = nil,
    topChars = nil, topTotalW = 0,
}

local function buildSpacedLayout(text, font, spacing)
    surface.SetFont(font)
    local chars = {}
    local total = 0
    local n = #text
    for i = 1, n do
        local c = text:sub(i, i)
        local cw = surface.GetTextSize(c)
        chars[i] = c
        chars[n + i] = cw
        total = total + cw
    end
    total = total + spacing * (n - 1)
    return chars, total, n
end

local function show(victimName)
    local now = CurTime()
    State.active = true
    State.startAt = now
    State.endAt = now + DURATION
    State.name = string.upper(tostring(victimName or ""))
    State.x = R:X(FRAME_X)
    State.y = R:Y(FRAME_Y)
    State.w = R:X(FRAME_W)
    State.h = R:Y(FRAME_H)
    State.cx = State.x + State.w * 0.5
    State.topY = State.y + R:Y(22)
    State.nameY = State.y + R:Y(52)
    State.topFont = Font:GetNamed("Poppins", "Light", 26)
    State.nameFont = Font:GetNamed("Poppins", "Bold", 60)
    State.topSpacing = R:X(TOP_LETTER_SPACING)
    State.topChars, State.topTotalW, State.topLen = buildSpacedLayout(TOP_TEXT, State.topFont, State.topSpacing)
end

netstream.Hook(CFG.NET.Show, show)

VERSE.Hook.AddNS("KillHUD", "HUDPaint", "VERSE::HUDPaint::KillHUD", function()
    if not State.active then return end

    local now = CurTime()
    if now >= State.endAt then
        State.active = false
        return
    end

    local a
    local s = State.startAt
    if now < s + FADE_IN then
        a = (now - s) / FADE_IN
    elseif now > State.endAt - FADE_OUT then
        a = (State.endAt - now) / FADE_OUT
    else
        a = 1
    end

    bgColor.a = 255 * a
    textColor.a = 229 * a
    subColor.a = 220 * a

    Materials:Draw(bgColor, MAT_KILLHUD, State.x, State.y, State.w, State.h, "noclamp smooth")

    local chars = State.topChars
    local n = State.topLen
    local font = State.topFont
    local spacing = State.topSpacing
    local x = State.cx - State.topTotalW * 0.5
    local y = State.topY
    for i = 1, n do
        draw.SimpleText(chars[i], font, x, y, subColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        x = x + chars[n + i] + spacing
    end

    draw.SimpleText(State.name, State.nameFont, State.cx, State.nameY, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
