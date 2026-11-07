local Notify = VERSE.Notify
local R = VERSE.Responsive
local Font = VERSE.Fonts

local cfg = VERSE.Config or {}
cfg.NotificationSounds = cfg.NotificationSounds or {}

local MAX_W = 446
local DEF_H = 45
local MAX_LINES = 30

-- ─── Couleurs pré-allouées pour le Paint des panels (évite Color() par frame) ─
local _NTF_COL_BLUR    = Color(62,  62,  62,  75)
local _NTF_COL_BG      = Color(62,  62,  62,  130)
local _NTF_COL_BORDER  = Color(255, 255, 255, 30)
local _NTF_COL_BADGE   = Color(229, 59,  59,  230)
local _NTF_COL_WHITE   = Color(255, 255, 255, 255)
local _NTF_COL_BAR     = Color(200, 200, 200, 0)   -- alpha muté dans Paint

local function makeKey(text, typ)
    return string.lower(tostring(text or "")) .. "::" .. tostring(typ or 0)
end

local function setSound(id, path)
    if id ~= nil and cfg.NotificationSounds[id] == nil then
        cfg.NotificationSounds[id] = path
    end
end

setSound(NOTIFY_GENERIC, "verse/ui/notifications/generic.mp3")
setSound(NOTIFY_ERROR, "verse/ui/notifications/error.mp3")
setSound(NOTIFY_UNDO, "verse/ui/notifications/undo.mp3")
setSound(NOTIFY_HINT, "verse/ui/notifications/hint.mp3")
setSound(NOTIFY_CLEANUP, "verse/ui/notifications/cleanup.mp3")

if _G.NOTIFY_MONEY == nil and Notify.RegisterType then
    _G.NOTIFY_MONEY = Notify:RegisterType("MONEY")
end
setSound(_G.NOTIFY_MONEY, "verse/ui/notifications/money.mp3")

local defaultType = NOTIFY_GENERIC
function Notify:PlaySound(t, soundOrDisable)
    local st = type(soundOrDisable)
    local disableSound = (st == "boolean") and soundOrDisable or false
    local customSound = (st == "string") and soundOrDisable or nil
    if disableSound then return end

    if customSound and customSound ~= "" then
        surface.PlaySound(customSound)
        return
    end

    local snds = cfg.NotificationSounds or {}
    local path = snds[t] or snds[defaultType]
    if path and path ~= "" then surface.PlaySound(path) end
end

VERSE._NotifyPanels = VERSE._NotifyPanels or setmetatable({}, { __mode = "k" })

local list = {}
local keyed = {}
local closing = setmetatable({}, { __mode = "k" })

local function rebuildLines(panel, baseText, count, fontName, lineSpacing, maxTextW)
    local txt = tostring(baseText or "")
    if (count or 1) > 1 then
        txt = string.format("%s (x%d)", txt, count)
    end

    surface.SetFont(fontName)
    local _, line_h = surface.GetTextSize("Ay")
    line_h = (type(line_h) == "number" and line_h > 0) and line_h or 16

    local extra = math.max(0, (lineSpacing or line_h) - line_h)
    local _, widest, totalH = Mantle.MantleTextMeasure(txt, fontName, maxTextW, MAX_LINES, extra)

    panel.baseText = baseText
    panel.stackCount = count or 1
    panel._wrapText = txt
    panel._widest = widest
    panel._totalH = totalH

    local padding = panel._padding or R:Y(10)
    local maxW = panel._maxW or R:X(MAX_W)
    local textW = math.min(widest, maxTextW)
    local w = math.min(textW + padding * 2 + (panel._iconOffset or 0), maxW)
    local h = math.max(totalH + padding * 2, panel._minH or R:Y(DEF_H))

    panel:SetSize(w, h)

    if IsValid(panel._mt) then
        panel._mt:SetText(panel._wrapText or "")
        panel._mt:SetMaxLines(MAX_LINES)
        panel._mt:SetFont(fontName)
        panel._mt:SetColor(Color(255, 255, 255))
        panel._mt:SetAlign(TEXT_ALIGN_LEFT)
        panel._mt:SetVAlign("center")
        panel._mt:SetPadding(0)
        panel._mt:SetLineSpacing(extra)
        panel:InvalidateLayout(true)
    end
end

local function Reposition()
    local scrW, scrH = ScrW(), ScrH()
    local baseY = scrH - R:Y(241)

    for i = #list, 1, -1 do
        local p = list[i]
        if IsValid(p) and not closing[p] then
            local w = p:GetWide()
            local targetY = baseY - p:GetTall()
            local targetX = scrW - R:X(40) - w
            p:MoveTo(targetX, targetY, 0.22, 0, 0.15)
            baseY = targetY - R:Y(8)
        end
    end
end

local function BeginClose(p)
    if not IsValid(p) or closing[p] then return end

    closing[p] = true
    p:Stop()

    local x, y = p:GetPos()
    local outDur = 0.18
    local outDx = R:X(28)
    p:MoveTo(x + outDx, y, outDur, 0, 0)

    p:AlphaTo(0, outDur, 0, function()
        if IsValid(p) then p:Remove() end
    end)
end

function Notify:Push(text, ntype, len, soundOrDisable)
    local t = self:ResolveType(ntype or defaultType)
    local du = tonumber(len) or 5
    local panel = self:_MergeOrCreate(text or "", t, du)
    self:PlaySound(t, soundOrDisable)
    VERSE.Log:Info(tostring(text))
    return panel
end

function Notify:_MergeOrCreate(text, nType, duration)
    local key = makeKey(text, nType)
    local now = UnPredictedCurTime()
    local panel = keyed[key]

    if IsValid(panel) then
        if closing[panel] then
            closing[panel] = nil
            panel:Stop()
            panel:SetAlpha(255)
        end

        panel.stackCount = (panel.stackCount or 1) + 1
        panel.endTime = now + (tonumber(duration) or 5)

        local fontName = panel._font or "DermaDefault"
        rebuildLines(panel, panel.baseText or text, panel.stackCount, fontName, panel._lineSpacing, panel._maxTextW)

        Reposition()
        return panel
    end

    self:_CreatePanel(text, nType, duration)
    return keyed[key]
end

function Notify:_CreatePanel(text, nType, duration)
    local fontName = Font:GetNamed("Poppins", "Medium", 20)
    local boldFont = Font:GetNamed("Poppins", "Bold", 25)
    local lineSpacing = R:Y(15)
    local padding = R:Y(10)
    local badgeSize = R:Y(30)
    local badgePad = R:Y(4)
    local iconOffset = badgeSize + badgePad * 2 + R:X(10)
    local maxW = R:X(MAX_W)
    local maxTextW = maxW - (padding * 2 + iconOffset)

    local p = vgui.Create("DPanel")
    p:SetPaintBackground(false)
    p:SetDrawOnTop(true)

    local now = UnPredictedCurTime()
    p.endTime = now + (tonumber(duration) or 5)
    p._totalDuration = tonumber(duration) or 5
    p.baseText = tostring(text or "")
    p.stackCount = 1
    p.nType = nType
    p._font = fontName
    p._boldFont = boldFont
    p._lineSpacing = lineSpacing
    p._padding = padding
    p._iconOffset = iconOffset
    p._maxTextW = maxTextW
    p._maxW = maxW
    p._minH = R:Y(DEF_H)
    p._VERSE_IS_NOTIFY = true
    VERSE._NotifyPanels[p] = true
    p._mt = vgui.Create("MantleText", p)
    p._mt:SetMouseInputEnabled(false)
    p._mt:SetKeyboardInputEnabled(false)
    p._mt:SetFont(fontName)
    p._mt:SetColor(Color(255, 255, 255))
    p._mt:SetAlign(TEXT_ALIGN_LEFT)
    p._mt:SetVAlign("center")
    p._mt:SetPadding(0)
    p._mt:SetMaxLines(MAX_LINES)
    rebuildLines(p, p.baseText, 1, fontName, lineSpacing, maxTextW)

    local scrW, scrH = ScrW(), ScrH()
    local w, h = p:GetSize()
    p:SetPos(scrW + w, scrH - R:Y(241) - h)

    p.PerformLayout = function(s, pw, ph)
        local bsz = badgeSize
        local tx = (badgePad + bsz + badgePad + R:X(10))
        local textW = pw - tx - padding
        local textH = ph

        if IsValid(s._mt) then
            s._mt:SetPos(tx, 0)
            s._mt:SetSize(math.max(1, textW), math.max(1, textH))
        end
    end

    local key = makeKey(text, nType)
    keyed[key] = p
    p._stackKey = key

    p.OnRemove = function(s)
        if s._stackKey and keyed[s._stackKey] == s then keyed[s._stackKey] = nil end
        closing[s] = nil
        VERSE._NotifyPanels[s] = nil
    end

    p.Paint = function(s, pw, ph)
        local x, y = 0, 0
        local radMain = R:Y(16)

        RNDX().Rect(x, y, pw, ph)
            :Rad(radMain)
            :Blur(0.85)
            :Color(_NTF_COL_BLUR)
            :Shadow(25, 30)
            :Draw()

        RNDX.Draw(radMain, x, y, pw, ph, _NTF_COL_BG)
        RNDX.DrawOutlined(radMain, x, y, pw, ph, _NTF_COL_BORDER)

        local bsz = badgeSize
        local bx = x + badgePad
        local by = y + (ph - bsz) * 0.5
        RNDX.Draw(R:Y(14), bx, by, bsz, bsz, _NTF_COL_BADGE)
        draw.SimpleText("!", s._boldFont, bx + bsz / 2, by + bsz / 2, _NTF_COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local total = math.max(s._totalDuration or 0, 0.001)
        local left = math.max((s.endTime or 0) - UnPredictedCurTime(), 0)
        local frac = math.Clamp(left / total, 0, 1)

        local barH = R:Y(3)
        local barMargin = R:X(44)
        local barFullW = pw - barMargin * 2
        local barW = barFullW * frac
        local barX = x + (pw - barW) / 2
        local barY = y + ph - barH - R:Y(3)
        _NTF_COL_BAR.a = 40 + 120 * frac
        RNDX.Draw(barH / 2, barX, barY, barW, barH, _NTF_COL_BAR)
    end

    table.insert(list, p)
    Reposition()
end

netstream.Hook(Notify.Net.Push, function(text, typ, dur, disableSound, customSound)
    text = tostring(text or "")
    typ = tonumber(typ) or NOTIFY_GENERIC
    dur = tonumber(dur) or 5

    if disableSound == true then
        Notify:Push(text, typ, dur, true)
    elseif isstring(customSound) and customSound ~= "" then
        Notify:Push(text, typ, dur, customSound)
    else
        Notify:Push(text, typ, dur)
    end
end)

local function cleanup()
    local now = UnPredictedCurTime()

    for i = #list, 1, -1 do
        local p = list[i]

        if not IsValid(p) then
            table.remove(list, i)
        elseif now >= (p.endTime or 0) and not closing[p] then
            BeginClose(p)
            Reposition()
        end
    end
end

VERSE.Hook.AddNS("Notify", "Think", "VERSE::Think::Notify", cleanup)

function notification.AddLegacy(desc, typ, dur, sound)
    Notify:Push(desc, typ, dur, sound)
end