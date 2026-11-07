local T = VERSE.TalkMode
local VCFG = T.Config.Visual
local R = VERSE.Responsive
local Materials = VERSE.Materials
local function Clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function EaseInOut(t)
    t = Clamp01(t)
    return t * t * (3 - 2 * t)
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function ColorAlpha(c, a)
    return Color(c.r, c.g, c.b, math.Clamp(a or c.a or 255, 0, 255))
end

local function Ease(t)
    t = Clamp01(t)
    return t * t * (3 - 2 * t)
end

local function LerpColor(c1, c2, t)
    return Color(Lerp(c1.r, c2.r, t), Lerp(c1.g, c2.g, t), Lerp(c1.b, c2.b, t), Lerp(c1.a, c2.a, t))
end

local function drawRing(center, radius, width, col, segments)
    if radius <= 4 then return end
    width = math.max(1, math.floor(width or 24))
    segments = math.Clamp(math.floor(segments or 64), 16, 256)
    local outer = radius
    local inner = math.max(0, radius - width)
    render.SetColorMaterial()
    mesh.Begin(MATERIAL_TRIANGLE_STRIP, (segments + 1) * 2)
    for i = 0, segments do
        local a = (i / segments) * math.pi * 2
        local ca, sa = math.cos(a), math.sin(a)
        local o = center + Vector(ca, sa, 0) * outer
        local inn = center + Vector(ca, sa, 0) * inner
        mesh.Position(o)
        mesh.Color(col.r, col.g, col.b, col.a)
        mesh.AdvanceVertex()
        mesh.Position(inn)
        mesh.Color(col.r, col.g, col.b, col.a)
        mesh.AdvanceVertex()
    end

    mesh.End()
end

local lastModeId = nil
local previewUntil = 0
local fadeT0 = 0
local fadeFrom = 0
local fadeTo = 0
local curFade = 0
local expandT0 = 0
local expandFrom = 0
local expandTo = 0
local curRadius = 0
local function StartPreview(modeRange)
    expandT0 = RealTime()
    expandFrom = 0
    expandTo = modeRange
    curRadius = 0
    previewUntil = RealTime() + (VCFG.PreviewTime or 1)
    fadeT0 = RealTime()
    fadeFrom = curFade or 0
    fadeTo = 1
end

local function StartFadeOut()
    fadeT0 = RealTime()
    fadeFrom = curFade or 0
    fadeTo = 0
end

local function NotifyMode(ply, id)
    if not IsValid(ply) then return end
    if ply ~= LocalPlayer() then return end
    local data = T:GetData(id)
    ply:Notify("[Voix] " .. data.name, 1, 5, false)
end

local function SaveCookie(id)
    id = T:Normalize(id)
    cookie.Set(T.CK_KEY, id)
end

local function LoadCookie()
    local id = cookie.GetString(T.CK_KEY, T.DefaultId)
    return T:Normalize(id)
end

netstream.Hook(T.Net.Mode, function(fromEntIndex, id)
    local ply = Entity(tonumber(fromEntIndex) or -1)
    id = T:Normalize(id)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply == LocalPlayer() then SaveCookie(id) end
    NotifyMode(ply, id)
end)

local function SendOp(op, id)
    op = tonumber(op) or 0
    if op == 0 or op == 3 then
        netstream.Start(T.Net.Cmd, op, tostring(id or ""))
    else
        netstream.Start(T.Net.Cmd, op)
    end
end

local didInit = false
VERSE.Hook.AddNS("TalkMode", "InitPostEntity", "VERSE::InitPostEntity::TalkMode", function()
    if didInit then return end
    didInit = true
    Materials:SetAlias("hud_whisper_voice", "verse/hud/whisper_voice")
    Materials:SetAlias("hud_default_voice", "verse/hud/default_voice")
    Materials:SetAlias("hud_yell_voice", "verse/hud/yell_voice")
    SendOp(3, LoadCookie())
end)

local function BuildOrder()
    local order = {}
    for _, m in ipairs(T.Modes or {}) do
        if m.hud and m.hud.icon then
            order[#order + 1] = {
                id = m.id,
                icon = m.hud.icon,
                iw = m.hud.iw or 20,
                ih = m.hud.ih or 20,
            }
        end
    end

    if #order == 0 then
        order = {
            {
                id = "Whisper",
                icon = "hud_whisper_voice",
                iw = 8,
                ih = 10
            },
            {
                id = "Normal",
                icon = "hud_default_voice",
                iw = 10,
                ih = 11
            },
            {
                id = "Yell",
                icon = "hud_yell_voice",
                iw = 12,
                ih = 11
            },
        }
    end
    return order
end

local ORDER = BuildOrder()
local function GetIndexById(id)
    for i, m in ipairs(ORDER) do
        if m.id == id then return i end
    end
    return 1
end

local A50 = math.floor(255 * 0.5)
local COL_BG = Color(22, 22, 22, A50)
local COL_BG_ACTIVE = Color(62, 62, 62, A50)
local COL_STROKE = Color(125, 125, 125, 255)
local COL_ICON = Color(146, 146, 146, 255)
local COL_ICON_ACT = color_white
-- Couleur mutée pour l'icône active (évite LerpColor+Color() à chaque frame)
local COL_ICON_LERPED = Color(146, 146, 146, 255)
-- Couleur mutée pour l'anneau de portée (évite ColorAlpha()+Color() à chaque frame)
local COL_RING = Color(0, 255, 0, 255)
local OUTLINE_W = 1
local RAD = 11
local ANIM_TIME = 0.18
local animFrom, animTo, animT0, lastIdx = 1, 1, 0, 1
VERSE.Hook.AddNS("TalkMode", "VERSE::HUDPaint::TalkMode", "VERSE::HUDPaint::TalkMode", function(ply)
    if not IsValid(ply) or ply ~= LocalPlayer() then return end
    local sw, sh = R:X(1920), R:Y(1080)
    local btnW = R:X(45)
    local btnH = R:Y(28)
    local gap = R:X(7)
    local padX = R:X(22)
    local padY = R:Y(10)
    local totalW = btnW * #ORDER + gap * (#ORDER - 1)
    local startX = math.floor(sw - padX - totalW)
    local startY = math.floor(sh - padY - btnH)
    local currentId = ply:GetTalkMode()
    local targetIdx = GetIndexById(currentId)
    if targetIdx ~= lastIdx then
        animFrom = lastIdx
        animTo = targetIdx
        animT0 = RealTime()
        lastIdx = targetIdx
    end

    local t = (RealTime() - animT0) / ANIM_TIME
    local k = Ease(t)
    local fromX = startX + (animFrom - 1) * (btnW + gap)
    local toX = startX + (animTo - 1) * (btnW + gap)
    local hiX = Lerp(fromX, toX, k)
    local hiY = startY
    local pop = 1 + (math.sin(k * math.pi) * 0.06)
    local hiW = btnW * pop
    local hiH = btnH * pop
    local hiOffX = (hiW - btnW) * 0.5
    local hiOffY = (hiH - btnH) * 0.5
    for i, m in ipairs(ORDER) do
        local x = startX + (i - 1) * (btnW + gap)
        local y = startY
        RNDX.Draw(RAD, x, y, btnW, btnH, COL_BG)
        RNDX.DrawOutlined(RAD, x, y, btnW, btnH, COL_STROKE, OUTLINE_W)
        local iw = R:X(m.iw)
        local ih = R:Y(m.ih)
        local ix = math.floor(x + (btnW - iw) * 0.5)
        local iy = math.floor(y + (btnH - ih) * 0.5)
        Materials:Draw(COL_ICON, m.icon, ix, iy, iw, ih, "noclamp smooth")
    end

    RNDX.Draw(RAD, hiX - hiOffX, hiY - hiOffY, hiW, hiH, COL_BG_ACTIVE)
    RNDX.DrawOutlined(RAD, hiX - hiOffX, hiY - hiOffY, hiW, hiH, COL_STROKE, OUTLINE_W)
    local m = ORDER[targetIdx]
    if m then
        local x = startX + (targetIdx - 1) * (btnW + gap)
        local y = startY
        local iconT = Clamp01(t)
        local k2 = Ease(iconT)
        -- Mutation de la couleur lerp (évite LerpColor+Color() à chaque frame)
        COL_ICON_LERPED.r = math.floor(Lerp(COL_ICON.r, 255, k2))
        COL_ICON_LERPED.g = math.floor(Lerp(COL_ICON.g, 255, k2))
        COL_ICON_LERPED.b = math.floor(Lerp(COL_ICON.b, 255, k2))
        COL_ICON_LERPED.a = math.floor(Lerp(COL_ICON.a, 255, k2))
        local iw = R:X(m.iw)
        local ih = R:Y(m.ih)
        local ix = math.floor(x + (btnW - iw) * 0.5)
        local iy = math.floor(y + (btnH - ih) * 0.5)
        Materials:Draw(COL_ICON_LERPED, m.icon, ix, iy, iw, ih, "noclamp smooth")
    end
end)

VERSE.Hook.AddNS("TalkMode", "PostDrawTranslucentRenderables", "VERSE::PostDrawTranslucentRenderables::TalkMode", function()
    if not VCFG.Enabled then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local data = ply:GetTalkModeData()
    if not data or not data.visual or not data.visual.enabled then return end
    if data.visual.style ~= "disc" then return end
    local modeId = ply:GetTalkMode()
    local range = tonumber(data.range) or 600
    if lastModeId ~= modeId then
        lastModeId = modeId
        if VCFG.ShowOnModeChange then StartPreview(range) end
    end

    local speaking = false
    if VCFG.ShowWhileSpeaking and ply.IsSpeaking then speaking = ply:IsSpeaking() end
    local shouldShow = false
    if speaking then
        shouldShow = true
        previewUntil = RealTime() + 0.15
    elseif VCFG.ShowOnModeChange and RealTime() <= previewUntil then
        shouldShow = true
    end

    if shouldShow and fadeTo ~= 1 then
        fadeT0 = RealTime()
        fadeFrom = curFade or 0
        fadeTo = 1
    elseif (not shouldShow) and fadeTo ~= 0 then
        StartFadeOut()
    end

    do
        local t = (RealTime() - (fadeT0 or 0)) / ((fadeTo == 0) and (VCFG.FadeOutTime or 0.2) or 0.12)
        local k = EaseInOut(t)
        curFade = Lerp(fadeFrom or 0, fadeTo or 0, k)
        curFade = Clamp01(curFade)
    end

    if curFade <= 0.01 then return end
    do
        local et = (RealTime() - (expandT0 or 0)) / (VCFG.ExpandTime or 0.18)
        local ek = EaseInOut(et)
        curRadius = Lerp(expandFrom or 0, expandTo or range, ek)
        curRadius = math.Clamp(curRadius, 0, range)
        if curRadius >= range * 0.999 then curRadius = range end
    end

    local baseCol = data.visual.color or Color(0, 255, 0)
    local targetAlpha = speaking and (VCFG.AlphaSpeaking or 170) or (VCFG.AlphaPreview or 140)
    local a = math.floor(targetAlpha * curFade)
    local center = ply:GetPos()
    center.z = center.z + (VCFG.GroundOffset or 2)
    -- Mutation de la couleur pré-allouée (évite ColorAlpha()+Color() à chaque frame)
    COL_RING.r, COL_RING.g, COL_RING.b, COL_RING.a = baseCol.r, baseCol.g, baseCol.b, math.Clamp(a, 0, 255)
    drawRing(center, curRadius, VCFG.RingWidth or 28, COL_RING, VCFG.Segments or 96)
end)