local Bell = VERSE.Bell
local CFG = Bell.Config
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials

local CARD_NATIVE_W,  CARD_NATIVE_H  = 807, 204

local TEXT_PCT_X,     TEXT_PCT_Y     = 0.070, 0.350
local TEXT_PCT_W,     TEXT_PCT_H     = 0.800, 0.200
local TOGGLE_PCT_X,   TOGGLE_PCT_Y   = 0.069, 0.745
local TOGGLE_PCT_R                   = 0.062
local TOGGLE_HIT_PCT_W               = 0.32
local SEND_PCT_X,     SEND_PCT_Y     = 0.814, 0.660
local SEND_PCT_W,     SEND_PCT_H     = 0.135, 0.192

local RECEIVER_X,        RECEIVER_Y        = -15, 111
local RECEIVER_NATIVE_W, RECEIVER_NATIVE_H = 364, 137

local RECEIVER_TITLE_PCT_Y                 = 0.22
local RECEIVER_MSG_PCT_Y                   = 0.45
local RECEIVER_AUTHOR_PCT_Y                = 0.82

local TITLE_FONT_SIZE                  = 28
local MSG_BOX_W, MSG_BOX_H, MSG_FONT_SIZE = 317, 73, 24
local AUTHOR_FONT_SIZE                 = 25

local TITLE_PREFIX  = "ANNONCE "
local PLACEHOLDER   = "test"

local MAT_SENDER   = "hud_bellsender"
local MAT_RECEIVER = "hud_bellreceiver"

-- ─── Couleurs pré-allouées pour Bell (évite Color() par frame) ───────────────
local _BELL_COL_COUNTER_OVER  = Color(229, 59,  59,  230)   -- compteur plein
local _BELL_COL_COUNTER_NEAR  = Color(229, 180, 60,  220)   -- compteur proche
local _BELL_COL_COUNTER_NORM  = Color(200, 200, 200, 180)   -- compteur normal
local _BELL_COL_MAT_WHITE     = Color(255, 255, 255, 0)     -- .a muté (receiver)
local _BELL_COL_TITLE         = Color(229, 59,  59,  0)     -- .a muté
local _BELL_COL_MSG           = Color(255, 255, 255, 0)     -- .a muté
local _BELL_COL_AUTHOR        = Color(255, 255, 255, 0)     -- .a muté
-- ─────────────────────────────────────────────────────────────────────────────

local senderFrame

local function closeSender()
    if IsValid(senderFrame) then senderFrame:Remove() end
    senderFrame = nil
end

local function openSender(ent)
    closeSender()
    if not IsValid(ent) then return end

    local mat = Materials:Get(MAT_SENDER)
    local mw = (mat and mat:Width()  > 0) and mat:Width()  or CARD_NATIVE_W
    local mh = (mat and mat:Height() > 0) and mat:Height() or CARD_NATIVE_H

    local cardW = R:S(CARD_NATIVE_W)
    local cardH = cardW * (mh / mw)

    local cardX = (ScrW() - cardW) * 0.5
    local cardY = (ScrH() - cardH) * 0.5

    local function cx(p) return cardX + cardW * p end
    local function cy(p) return cardY + cardH * p end
    local function cw(p) return cardW * p end
    local function ch(p) return cardH * p end

    local frame = vgui.Create("DFrame")
    senderFrame = frame
    frame:SetSize(ScrW(), ScrH())
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()

    local cross = false

    frame.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 160)
        surface.DrawRect(0, 0, w, h)
        Materials:Draw(color_white, MAT_SENDER, cardX, cardY, cardW, cardH, "noclamp smooth")
    end

    frame.OnMousePressed = function(_, code)
        local mx, my = gui.MouseX(), gui.MouseY()
        if code == MOUSE_LEFT and (mx < cardX or mx > cardX + cardW or my < cardY or my > cardY + cardH) then
            closeSender()
        end
    end

    frame.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then closeSender() end
    end

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(cx(TEXT_PCT_X), cy(TEXT_PCT_Y))
    entry:SetSize(cw(TEXT_PCT_W), ch(TEXT_PCT_H))
    entry:SetFont(Font:GetNamed("Poppins", "Medium", 22))
    entry:SetPlaceholderText(PLACEHOLDER)
    entry:SetTextColor(color_white)
    entry:SetMaximumCharCount(CFG.MaxLength)
    entry:SetUpdateOnType(true)
    entry:SetDrawLanguageID(false)
    entry:RequestFocus()

    local counterFont = Font:GetNamed("Poppins", "Medium", 14)
    entry.Paint = function(s, w, h)
        s:DrawTextEntryText(s:GetTextColor(), s:GetHighlightColor(), s:GetCursorColor())

        local len = #(s:GetValue() or "")
        local max = CFG.MaxLength
        -- Utilise les couleurs pré-allouées (évite Color() à chaque frame)
        local col = (len >= max) and _BELL_COL_COUNTER_OVER
                 or (len >= max * 0.9) and _BELL_COL_COUNTER_NEAR
                 or _BELL_COL_COUNTER_NORM
        draw.SimpleText(len .. " / " .. max, counterFont, w - 6, h - 4,
            col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    end

    local function send()
        local text = string.Trim(entry:GetValue() or "")
        if text == "" then return end
        netstream.Start(Bell.Net.Send, ent:EntIndex(), text, cross)
        closeSender()
    end
    entry.OnEnter = send

    local toggleR = ch(TOGGLE_PCT_R)

    local toggle = vgui.Create("DButton", frame)
    toggle:SetText("")
    toggle:SetCursor("hand")
    toggle:SetPos(cx(TOGGLE_PCT_X) - toggleR, cy(TOGGLE_PCT_Y) - toggleR)
    toggle:SetSize(cw(TOGGLE_HIT_PCT_W), toggleR * 2 + ch(0.015))
    toggle.PaintOver = function() end
    toggle.Paint = function()
        if not cross then return end
        draw.NoTexture()
        surface.SetDrawColor(229, 59, 59, 240)
        local seg, segs = 32, {}
        for i = 0, seg do
            local a = (i / seg) * math.pi * 2
            segs[#segs + 1] = { x = toggleR + math.cos(a) * toggleR, y = toggleR + math.sin(a) * toggleR }
        end
        surface.DrawPoly(segs)
    end
    toggle.DoClick = function() cross = not cross end

    local sendBtn = vgui.Create("DButton", frame)
    sendBtn:SetPos(cx(SEND_PCT_X), cy(SEND_PCT_Y))
    sendBtn:SetSize(cw(SEND_PCT_W), ch(SEND_PCT_H))
    sendBtn:SetText("")
    sendBtn.Paint = function() end
    sendBtn.PaintOver = function() end
    sendBtn.DoClick = send
end

netstream.Hook(Bell.Net.Open, openSender)

local active
local iLerp = 0

net.Receive(Bell.Net.Display, function()
    local payload = net.ReadTable()
    if not istable(payload) then return end
    local now = CurTime()
    active = {
        author      = tostring(payload.author or "?"),
        factionName = tostring(payload.factionName or ""),
        message     = tostring(payload.message or ""),
        startAt     = now,
        endAt       = now + CFG.DisplayDuration,
    }
    if CFG.Sound and CFG.Sound ~= "" then
        sound.PlayFile("sound/" .. CFG.Sound, "noplay", function(channel, errId, errStr)
            if not IsValid(channel) then
                VERSE.Log:Warn("[Bell] PlayFile failed: " .. tostring(errStr))
                return
            end
            channel:SetVolume(1)
            channel:Play()
        end)
    end
end)

VERSE.Hook.AddNS("Bell", "Think", "VERSE::Think::Bell", function()
    if not active then
        iLerp = Lerp(FrameTime() * 6, iLerp, 0)
        return
    end

    local now = CurTime()
    if now >= active.endAt then
        active = nil
        return
    end

    local target = 1
    if now < active.startAt + CFG.FadeIn then
        target = (now - active.startAt) / CFG.FadeIn
    elseif now > active.endAt - CFG.FadeOut then
        target = (active.endAt - now) / CFG.FadeOut
    end
    iLerp = Lerp(FrameTime() * 8, iLerp, math.Clamp(target, 0, 1))
end)

local _bellTitleFont  = nil
local _bellMsgFont    = nil
local _bellAuthorFont = nil
local function ensureBellFonts()
    if _bellTitleFont then return end
    _bellTitleFont  = Font:GetNamed("Poppins", "Black",   TITLE_FONT_SIZE)
    _bellMsgFont    = Font:GetNamed("Poppins", "Regular", MSG_FONT_SIZE)
    _bellAuthorFont = Font:GetNamed("Poppins", "Regular", AUTHOR_FONT_SIZE)
end

VERSE.Hook.AddNS("Bell", "HUDPaint", "VERSE::HUDPaint::Bell", function()
    if not active or iLerp <= 0.01 then return end

    local a = math.floor(255 * iLerp)
    local mat = Materials:Get(MAT_RECEIVER)
    local mw = (mat and mat:Width()  > 0) and mat:Width()  or RECEIVER_NATIVE_W
    local mh = (mat and mat:Height() > 0) and mat:Height() or RECEIVER_NATIVE_H

    local hudW = R:S(RECEIVER_NATIVE_W)
    local hudH = hudW * (mh / mw)
    local hx, hy = R:S(RECEIVER_X), R:S(RECEIVER_Y)
    local cx = hx + hudW * 0.5
    local pxScale = R:GetScale()
    -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
    _BELL_COL_MAT_WHITE.a = a
    Materials:Draw(_BELL_COL_MAT_WHITE, MAT_RECEIVER, hx, hy, hudW, hudH, "noclamp smooth")

    ensureBellFonts()

    local title = TITLE_PREFIX .. string.upper(active.factionName or "")
    _BELL_COL_TITLE.a = a
    draw.SimpleText(title, _bellTitleFont, cx, hy + hudH * RECEIVER_TITLE_PCT_Y,
        _BELL_COL_TITLE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetFont(_bellMsgFont)
    local _, lineH = surface.GetTextSize("Ay")
    if not lineH or lineH <= 0 then lineH = math.floor(MSG_FONT_SIZE * pxScale * 1.2) end

    local maxLines = math.max(1, math.floor((MSG_BOX_H * pxScale) / lineH))
    local lines = VERSE.TextWrap(active.message, _bellMsgFont, lineH, MSG_BOX_W * pxScale, maxLines) or {}
    _BELL_COL_MSG.a = a
    local msgY = hy + hudH * RECEIVER_MSG_PCT_Y
    for i, line in ipairs(lines) do
        draw.SimpleText(line, _bellMsgFont, cx, msgY + (i - 1) * lineH,
            _BELL_COL_MSG, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    _BELL_COL_AUTHOR.a = a
    draw.SimpleText(active.author, _bellAuthorFont, cx, hy + hudH * RECEIVER_AUTHOR_PCT_Y,
        _BELL_COL_AUTHOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
