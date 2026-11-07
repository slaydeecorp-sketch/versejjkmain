VERSE.Hook.ClearNS("Chat")

local Chat = VERSE.Chat
local cfg = Chat.Config
local R = VERSE.Responsive
local Font = VERSE.Fonts
local L = VERSE.L
local V = VERSE.VGUI
local Materials = VERSE.Materials

Materials:SetAlias("chat_main_background", "verse/traders/main_background")

local _hrState = nil
if Chat.State then
    _hrState = {
        Messages = Chat.State.Messages or {},
        History = Chat.State.History or {},
        HistoryIndex = Chat.State.HistoryIndex or 0,
        WasOpen = Chat.State.Opened or false,
        EntryText = "",
        InputMode = Chat.State.InputMode or Chat.CH_IC,
    }
    if Chat.UI and IsValid(Chat.UI.Entry) then
        _hrState.EntryText = Chat.UI.Entry:GetValue() or ""
    end
end

if Chat.UI and IsValid(Chat.UI.Frame) then
    Chat.UI.Frame:KillFocus()
    Chat.UI.Frame:SetMouseInputEnabled(false)
    Chat.UI.Frame:SetKeyboardInputEnabled(false)
    Chat.UI.Frame:Remove()
end

Chat.UI = {}
Chat.State = {
    Opened = false,
    Alpha = 0,
    AlphaTarget = 0,
    History = (_hrState and _hrState.History) or {},
    HistoryIndex = (_hrState and _hrState.HistoryIndex) or 0,
    Messages = (_hrState and _hrState.Messages) or {},
    NextMsgId = (_hrState and _hrState.NextMsgId) or 0,
    SelectedRow = nil,
    InputMode = (_hrState and _hrState.InputMode) or Chat.CH_IC,
}

local S = Chat.State
local UI = Chat.UI
local ANIM_FADE_IN = 0.15
local ANIM_FADE_OUT = 3
local ALPHA_LERP = 15
local MAX_MESSAGES = 250
local MAX_HISTORY = 50

local CLR_INPUT_BG = Color(255, 255, 255, 50)
local CLR_TIME = Color(120, 120, 135)
local CLR_PH = Color(160, 160, 175)
local CLR_SCROLL_GRIP = Color(255, 255, 255, 80)
local color_white = Color(255, 255, 255)
-- Couleur réutilisable pour le fond du chat (évite ColorAlpha() dans frame.Paint)
local _chatBgCol = Color(255, 255, 255, 255)
-- Couleur réutilisable pour la sélection du text entry (évite Color() dans Paint)
local CLR_SELECTION = Color(255, 255, 255, 40)

local _fTitle, _fMsg, _fMsgBold, _fMsgItalic, _fInput, _fTime, _fPill, _fHud

local function ensureFonts()
    if _fTitle then return end
    local name = cfg.FontName or "Poppins"
    local sz = cfg.FontSize or 18
    _fTitle = Font:GetNamed("Poppins", "SemiBold", 24)
    _fMsg = Font:GetNamed(name, "Medium", sz)
    _fMsgBold = Font:GetNamed(name, "Bold", sz)
    _fMsgItalic = Font:GetNamed(name, "Italic", sz)
    _fInput = Font:GetNamed(name, "Medium", sz)
    _fTime = Font:GetNamed(name, "Regular", sz)
    _fPill = Font:GetNamed("Poppins", "Bold", 24)
    _fHud = Font:GetNamed(name, "Medium", sz)
end

local DEF_W = cfg.ChatW or 500
local DEF_H = cfg.ChatH or 380
local DEF_X = cfg.ChatX or 20
local DEF_Y = cfg.ChatY or -1

local function loadLayout()
    local w = DEF_W
    local h = DEF_H
    local x = DEF_X
    local y = DEF_Y
    return x, y, w, h
end

local function utf8Len(s)
    if not s or s == "" then return 0 end
    local ok, len = pcall(utf8.len, s)
    if ok and len then return len end
    return #s
end

local function utf8Sub(s, i, j)
    if not s or s == "" then return "" end
    local ok, result = pcall(function()
        local startByte = utf8.offset(s, i) or 1
        local endByte
        if j then
            endByte = (utf8.offset(s, j + 1) or (#s + 1)) - 1
        else
            endByte = #s
        end
        return string.sub(s, startByte, endByte)
    end)
    if ok then return result end
    return string.sub(s, 1, j or #s)
end

local function submitText(text)
    text = string.Trim(tostring(text or ""))
    if text == "" then return end
    local maxLen = cfg.MaxMessageLen or 256
    if utf8Len(text) > maxLen then text = utf8Sub(text, 1, maxLen) end

    local mode = S.InputMode or Chat.CH_IC
    local prefix = ""
    if mode == Chat.CH_OOC then prefix = "/ooc " end

    netstream.Start(Chat.Net.ClientSay, prefix .. text)
end

local INPUT_MODES = {
    { ch = Chat.CH_IC,  label = "IC" },
    { ch = Chat.CH_OOC, label = "OOC" },
}

local function getInputModeIndex()
    for i, m in ipairs(INPUT_MODES) do
        if m.ch == S.InputMode then return i end
    end
    return 1
end

local function cycleInputMode(dir)
    local idx = getInputModeIndex()
    idx = ((idx - 1 + dir) % #INPUT_MODES) + 1
    S.InputMode = INPUT_MODES[idx].ch
end

local function getInputModeLabel()
    local pill = Chat:GetPill(S.InputMode)
    return pill.label
end

local function getInputModeBg()
    return Chat:GetPillBgColor(S.InputMode)
end

local function getInputModeTextColor()
    return Chat:GetPillTextColor(S.InputMode)
end

function scrollToBottom()
    if not UI.Scroll or not IsValid(UI.Scroll) then return end
    local scroll = UI.Scroll
    scroll:InvalidateLayout(true)
    scroll:GetCanvas():InvalidateLayout(true)

    local attempts = 0
    local function doScroll()
        if not IsValid(scroll) then return end
        local sbar = scroll:GetVBar()
        local canvasH = sbar.CanvasSize or 0
        sbar:SetScroll(canvasH)
        sbar:AnimateTo(canvasH, 0.1, 0, 0.3)
        attempts = attempts + 1
        if attempts < 3 then timer.Simple(0.05, doScroll) end
    end
    timer.Simple(0, doScroll)
end

function Chat:PlayChannelSound(channel)
    if not cfg.SoundEnabled then return end
    surface.PlaySound("buttons/lightswitch2.wav")
end

function Chat:GetNameColor(channel, sender)
    local pill = self:GetPill(channel)
    return pill.msg or color_white
end

function Chat:AddMessage(channel, name, text, timestamp, extra, isLocal)
    local maxHist = cfg.MaxHistory or MAX_MESSAGES
    S.NextMsgId = S.NextMsgId + 1

    local msg = {
        id = S.NextMsgId,
        channel = channel or Chat.CH_IC,
        name = name or "",
        text = text or "",
        extra = extra,
        time = timestamp or os.date("%H:%M"),
        addedAt = RealTime(),
    }

    S.Messages[#S.Messages + 1] = msg
    if #S.Messages > maxHist then table.remove(S.Messages, 1) end

    if S.Opened and IsValid(UI.Frame) and UI.Scroll then
        UI.SpawnMessagePanel(msg)
        if IsValid(UI.Scroll) then
            UI.Scroll:InvalidateLayout(true)
            UI.Scroll:GetCanvas():InvalidateLayout(true)
        end
        if cfg.AutoScroll then scrollToBottom() end
    end

    if not isLocal then Chat:PlayChannelSound(channel) end
    return msg
end

function UI.SpawnMessagePanel(msg)
    if not UI.Scroll or not IsValid(UI.Scroll) then return end
    ensureFonts()

    local scroll = UI.Scroll
    local ch = msg.channel
    local isSys = (msg.name == "")
    local nameCol = Chat:GetNameColor(ch, msg.sender)
    local textCol = Chat:GetChannelColor(ch, msg.success)
    local _, _, chatW, _ = loadLayout()
    local maxW = R:X(chatW - 30)
    local lineH = R:Y(20)
    local TW = VERSE.TextWrap

    local timeText = msg.time and (msg.time .. "  ") or ""
    local timeW = 0
    if timeText ~= "" then timeW = VERSE.GetTextSize(timeText, _fTime) end

    local nameText = ""
    local nameW = 0
    if not isSys then
        if ch == Chat.CH_ME then
            nameText = (msg.name or "") .. " "
        elseif ch == Chat.CH_DO then
            nameText = "(NL)  "
        elseif ch == Chat.CH_NA then
            nameText = "(NA)  " .. (msg.name or "") .. " :  "
        else
            nameText = (msg.name or "") .. " :  "
        end
        if nameText ~= "" then nameW = VERSE.GetTextSize(nameText, _fMsgBold) end
    end

    local bodyText
    if ch == Chat.CH_ME then bodyText = msg.text
    elseif ch == Chat.CH_DO then bodyText = msg.text
    elseif ch == Chat.CH_NA then bodyText = msg.text
    else bodyText = msg.text end

    local prefixW = timeW + nameW
    local firstMaxW = maxW - prefixW
    local wrappedLines = {}

    if TW and firstMaxW > 0 then
        local narrowLines = TW(bodyText, _fMsg, lineH, firstMaxW)
        if narrowLines and narrowLines[1] then
            local firstLine = string.gsub(narrowLines[1], "%.%.%.$", "")
            wrappedLines[1] = { text = firstLine, x = prefixW }
            local rest = string.sub(bodyText, #firstLine + 1):gsub("^%s+", "")
            if rest ~= "" then
                local restLines = TW(rest, _fMsg, lineH, maxW)
                for _, rl in ipairs(restLines) do
                    wrappedLines[#wrappedLines + 1] = { text = rl, x = 0 }
                end
            end
        else
            wrappedLines[1] = { text = bodyText, x = prefixW }
        end
    else
        wrappedLines[1] = { text = bodyText, x = prefixW }
    end

    local rowH = math.max(#wrappedLines * lineH + R:Y(4), R:Y(24))
    local _mTime = Color(CLR_TIME.r, CLR_TIME.g, CLR_TIME.b, 0)
    local _mName = Color(nameCol.r, nameCol.g, nameCol.b, 0)
    local _mTxt = Color(textCol.r, textCol.g, textCol.b, 0)
    local _mSel = Color(80, 130, 220, 0)

    local row = V.Create("DPanel", scroll)
    row:Dock(TOP)
    row:SetTall(rowH)
    row:DockMargin(0, 0, 0, R:Y(2))
    row:SetMouseInputEnabled(true)
    row._copyText = (msg.time or "") .. " " .. (msg.name or "") .. ": " .. (msg.text or "")

    row.OnMousePressed = function(s, code)
        if code == MOUSE_RIGHT and s._copyText ~= "" then
            SetClipboardText(s._copyText)
        end
    end

    local spawnTime = RealTime()
    row.Paint = function(s, w, h)
        local age = RealTime() - spawnTime
        local alpha = math.Clamp(age / ANIM_FADE_IN, 0, 1)
        if not S.Opened then
            local holdTime = cfg.MessageLifetime or 15
            local fadeAge = age - holdTime
            if fadeAge > 0 then
                alpha = math.Clamp(1 - fadeAge / ANIM_FADE_OUT, 0, 1)
                if alpha <= 0 then s:SetVisible(false) return end
            end
        end

        local a255 = math.floor(255 * alpha)
        local curX = 0

        if timeText ~= "" then
            _mTime.a = a255
            draw.SimpleText(timeText, _fTime, curX, R:Y(2), _mTime, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            curX = timeW
        end

        if nameText ~= "" then
            _mName.a = a255
            draw.SimpleText(nameText, _fMsgBold, curX, R:Y(2), _mName, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        _mTxt.a = a255
        for li, wl in ipairs(wrappedLines) do
            local segments = Chat:ParseFormatting(wl.text)
            local segX = wl.x
            local segY = (li - 1) * lineH + R:Y(2)
            for _, seg in ipairs(segments) do
                local font = _fMsg
                if seg.style == "bold" then font = _fMsgBold
                elseif seg.style == "italic" then font = _fMsgItalic end
                draw.SimpleText(seg.text, font, segX, segY, _mTxt, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                segX = segX + VERSE.GetTextSize(seg.text, font)
            end
        end
    end

    row:SetTall(rowH)
end

function Chat:Build()
    if IsValid(UI.Frame) then UI.Frame:Remove() end
    ensureFonts()

    local lx, ly, lw, lh = loadLayout()
    local frame = V.Create("MantleFrame")
    frame:SetSize(R:XY(lw, lh))
    frame:SetPos(R:XY(lx, ly))
    frame:DisableCloseBtn()
    frame:SetDraggable(false)
    frame:SetClosable(false)
    frame:LiteMode()

    frame.Paint = function(_, w, h)
        local a = S.Alpha / 255
        if a < 0.01 then return end
        RNDX.DrawBlur(0, 0, w, h, nil, R:Y(15), R:Y(15), R:Y(15), R:Y(15), 255)
        _chatBgCol.a = math.floor(255 * a)
        Materials:Draw(_chatBgCol, "chat_main_background", 0, 0, w, h)
    end

    frame.Think = function(s)
        if not S.Opened then return end
        if not IsValid(UI.Entry) then return end
        local te = UI.Entry.textEntry or UI.Entry
        if IsValid(te) and not te:HasFocus() then te:RequestFocus() end
    end

    local titleLbl = V.Create("DLabel", frame)
    titleLbl:SetPos(R:X(15), R:Y(12))
    titleLbl:SetSize(R:X(200), R:Y(30))
    titleLbl:SetFont(_fTitle)
    titleLbl:SetText("Chat - Verse")
    titleLbl:SetTextColor(color_white)

    local inputBarH = R:Y(42)
    local inputBar = V.Create("DPanel", frame)
    inputBar:Dock(BOTTOM)
    inputBar:SetTall(inputBarH)
    inputBar:DockMargin(R:X(10), R:Y(6), R:X(10), R:Y(10))
    inputBar.Paint = function(_, w, h)
        RNDX.Draw(R:Y(8), 0, 0, w, h, CLR_INPUT_BG)
    end

    local modePill = V.Create("DButton", inputBar)
    modePill:Dock(LEFT)
    modePill:SetWide(R:X(60))
    modePill:DockMargin(R:X(6), R:Y(6), 0, R:Y(6))
    modePill:SetText("")
    modePill:SetCursor("hand")
    modePill.Paint = function(s, w, h)
        local bg = getInputModeBg()
        local txt = getInputModeTextColor()
        RNDX.Draw(R:Y(9), 0, 0, w, h, bg)
        draw.SimpleText(getInputModeLabel(), _fPill, w / 2, h / 2, txt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    modePill.DoClick = function() cycleInputMode(1) end
    modePill.DoRightClick = function() cycleInputMode(-1) end

    local entry = V.Create("DTextEntry", inputBar)
    entry:Dock(FILL)
    entry:DockMargin(R:X(8), 0, R:X(10), 0)
    entry:SetFont(_fInput)
    entry:SetText("")
    entry:SetDrawLanguageID(false)
    entry:SetUpdateOnType(true)
    entry:SetPaintBackground(false)
    entry:SetTextColor(color_white)
    entry:SetCursorColor(color_white)
    entry:SetHighlightColor(Color(255, 255, 255, 40))
    if entry.SetAllowNonAsciiCharacters then entry:SetAllowNonAsciiCharacters(true) end

    entry.Paint = function(s, w, h)
        local val = s:GetValue() or ""
        if val == "" and not s:HasFocus() then
            draw.SimpleText(L("chat.placeholder"), _fInput, 0, h / 2, CLR_PH, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return true
        end
        s:DrawTextEntryText(color_white, CLR_SELECTION, color_white)
        return true
    end

    entry._limitMax = cfg.MaxMessageLen or 1024
    entry.AllowInput = function(s, char)
        local val = s:GetValue() or ""
        if utf8Len(val) >= s._limitMax then return true end
    end
    entry.OnChange = function(s)
        local val = s:GetValue() or ""
        local len = utf8Len(val)
        if len > s._limitMax then
            local trimmed = utf8Sub(val, 1, s._limitMax)
            s:SetText(trimmed)
            s:SetCaretPos(#trimmed)
        end
    end

    local function handleChatKey(s, key)
        if key == KEY_ESCAPE then
            Chat:Close()
            return true
        end

        if key == KEY_TAB then
            cycleInputMode(1)
            return true
        end

        if key == KEY_ENTER or key == KEY_PAD_ENTER then
            local text = string.Trim(entry:GetValue() or "")
            if text ~= "" then
                if S.History[#S.History] ~= text then
                    if #S.History >= MAX_HISTORY then table.remove(S.History, 1) end
                    S.History[#S.History + 1] = text
                end
                S.HistoryIndex = #S.History + 1
                submitText(text)
            end
            Chat:Close()
            return true
        end

        if key == KEY_UP then
            if S.HistoryIndex > 1 then
                S.HistoryIndex = S.HistoryIndex - 1
                local text = S.History[S.HistoryIndex] or ""
                entry:SetText(text)
                entry:SetCaretPos(#text)
            end
            return true
        end

        if key == KEY_DOWN then
            if S.HistoryIndex <= #S.History then
                S.HistoryIndex = S.HistoryIndex + 1
                local text = S.History[S.HistoryIndex] or ""
                entry:SetText(text)
                entry:SetCaretPos(#text)
            end
            return true
        end
    end

    entry.OnKeyCodeTyped = handleChatKey
    local innerTE = entry.textEntry or entry
    if innerTE ~= entry then
        innerTE.OnKeyCodeTyped = handleChatKey
    end

    UI.Entry = entry
    UI.ModePill = modePill

    local scrollContainer = V.Create("DPanel", frame)
    scrollContainer:Dock(FILL)
    scrollContainer:DockMargin(R:X(10), R:Y(42), R:X(10), R:Y(4))
    scrollContainer.Paint = nil

    local scroll = V.Create("DScrollPanel", scrollContainer)
    scroll:Dock(FILL)
    local sbar = scroll:GetVBar()
    sbar:SetWide(R:X(3))
    sbar.Paint = nil
    sbar.btnUp.Paint = nil
    sbar.btnDown.Paint = nil
    sbar.btnGrip.Paint = function(s, w, h) RNDX.Draw(2, 0, 0, w, h, CLR_SCROLL_GRIP) end
    UI.Scroll = scroll

    UI.Frame = frame
end

function Chat:SwitchCategory() end

function Chat:Open()
    if S.Opened then return end
    S.Opened = true
    S.AlphaTarget = 255
    S.HistoryIndex = #S.History + 1
    if not IsValid(UI.Frame) then Chat:Build() end
    UI.Frame:MakePopup()
    UI.Frame:SetVisible(true)
    UI.Frame:SetMouseInputEnabled(true)
    UI.Frame:SetKeyboardInputEnabled(true)
    if IsValid(UI.Entry) then
        UI.Entry:SetText("")
        UI.Entry:RequestFocus()
    end

    if UI.Scroll and IsValid(UI.Scroll) then
        UI.Scroll:GetCanvas():Clear()
        for _, msg in ipairs(S.Messages) do
            UI.SpawnMessagePanel(msg)
        end
        if cfg.AutoScroll then scrollToBottom() end
    end

    gamemode.Call("StartChat")
end

function Chat:Close()
    if not S.Opened then return end
    S.Opened = false
    S.AlphaTarget = 0

    if IsValid(S.SelectedRow) then S.SelectedRow:MouseCapture(false) end
    S.SelectedRow = nil

    if IsValid(UI.Entry) then
        local innerTE = UI.Entry.textEntry or UI.Entry
        if IsValid(innerTE) then innerTE:KillFocus() end
        UI.Entry:KillFocus()
    end

    if IsValid(UI.Frame) then
        UI.Frame:MouseCapture(false)
        UI.Frame:SetMouseInputEnabled(false)
        UI.Frame:SetKeyboardInputEnabled(false)
        UI.Frame:Remove()
        UI.Frame = nil
    end

    UI.Entry = nil
    UI.Scroll = nil
    gamemode.Call("FinishChat")
end

function Chat:IsOpen()
    return S.Opened
end

VERSE.Hook.AddNS("Chat", "Think", "VERSE::Chat::AlphaThink", function()
    local dt = FrameTime()
    S.Alpha = Lerp(dt * ALPHA_LERP, S.Alpha, S.AlphaTarget)
    if not IsValid(UI.Frame) then return end
    if S.Alpha < 1 and not S.Opened then
        UI.Frame:SetVisible(false)
    elseif S.Alpha > 0 then
        UI.Frame:SetVisible(true)
    end
    UI.Frame:SetAlpha(math.floor(S.Alpha))
end)

local _lastCopy = 0
VERSE.Hook.AddNS("Chat", "Think", "VERSE::Chat::CopyThink", function()
    if not S.Opened then return end
    if not S.SelectedRow or not IsValid(S.SelectedRow) then return end
    if input.IsKeyDown(KEY_LCONTROL) and input.IsKeyDown(KEY_C) then
        if RealTime() - _lastCopy < 0.5 then return end
        _lastCopy = RealTime()
        local row = S.SelectedRow
        if row._copyText and row._copyText ~= "" then SetClipboardText(row._copyText) end
    end
end)

VERSE.Hook.AddNS("Chat", "StartChat", "VERSE::Chat::StartChat", function(teamChat)
    if not cfg.Enabled then return end
    Chat:Open()
    return true
end)

VERSE.Hook.AddNS("Chat", "FinishChat", "VERSE::Chat::FinishChat", function() end)

VERSE.Hook.AddNS("Chat", "PlayerBindPress", "VERSE::Chat::BindPress", function(ply, bind, pressed)
    if not pressed then return end
    if bind == "messagemode" or bind == "messagemode2" then
        if not cfg.Enabled then return end
        Chat:Open()
        return true
    end
end)

netstream.Hook(Chat.Net.Message, function(data)
    if not istable(data) then return end
    local me = LocalPlayer()
    local isLocal = IsValid(me) and data.sender and data.sender == me:SteamID64()
    local msg = Chat:AddMessage(data.channel or Chat.CH_ALL, data.name, data.text, data.time, data.extra, isLocal)
    if msg and data.success ~= nil then msg.success = data.success end
    -- /me → bulle au-dessus de la tête
    if data.channel == Chat.CH_ME and data.sender and isstring(data.text) and data.text ~= "" then
        hook.Run("VERSE::Chat::MeMessage", data.sender, data.text)
    end
end)

local _origChatAddText = chat.AddText
chat.AddText = function(...)
    local args = { ... }
    local text = ""
    for _, v in ipairs(args) do
        if isstring(v) then text = text .. v end
    end
    if text ~= "" then Chat:AddMessage(Chat.CH_ALL, "", text) end
    if _origChatAddText then _origChatAddText(...) end
end

local _mHudCol = Color(255, 255, 255, 0)
local _mHudName = Color(255, 255, 255, 0)
local _mHudTime = Color(120, 120, 135, 0)
local _mShadow = Color(0, 0, 0, 0)
local SHADOW_OFFSET = 1

local function drawTextShadow(text, font, x, y, col, ax, ay)
    _mShadow.a = col.a
    draw.SimpleText(text, font, x + SHADOW_OFFSET, y + SHADOW_OFFSET, _mShadow, ax, ay)
    draw.SimpleText(text, font, x, y, col, ax, ay)
end

VERSE.Hook.AddNS("Chat", "DrawOverlay", "VERSE::Chat::HUDMessages", function()
    if S.Opened then return end
    if not cfg.Enabled then return end
    ensureFonts()

    local now = RealTime()
    local lifetime = cfg.MessageLifetime or 15
    local visible = {}

    for i = #S.Messages, math.max(#S.Messages - 15, 1), -1 do
        local msg = S.Messages[i]
        if not msg then break end
        if now - msg.addedAt > lifetime then break end
        visible[#visible + 1] = msg
        if #visible >= 8 then break end
    end

    if #visible == 0 then return end

    local fx, fy, fw, fh
    if IsValid(UI.Frame) then
        fx, fy = UI.Frame:GetPos()
        fw, fh = UI.Frame:GetSize()
    else
        local clx, cly, clw, clh = loadLayout()
        fx, fy = R:X(clx), R:Y(cly)
        fw, fh = R:X(clw), R:Y(clh)
    end

    local baseX = fx + R:X(12)
    local maxW = fw - R:X(24)
    local lineH = R:Y(20)
    local TextWrap = VERSE.TextWrap

    local totalLines = 0
    local wrappedMsgs = {}

    for i = #visible, 1, -1 do
        local msg = visible[i]
        local ch = msg.channel or Chat.CH_IC
        local isSys = (msg.name == "")

        local timeText = msg.time and (msg.time .. "  ") or ""
        local timeW = 0
        if timeText ~= "" then timeW = VERSE.GetTextSize(timeText, _fTime) end

        local nameText = ""
        local nameW = 0
        if not isSys then
            if ch == Chat.CH_ME then nameText = (msg.name or "") .. " "
            elseif ch == Chat.CH_DO then nameText = "(NL)  "
            elseif ch == Chat.CH_NA then nameText = "(NA)  " .. (msg.name or "") .. " :  "
            else nameText = (msg.name or "") .. " :  " end
            if nameText ~= "" then nameW = VERSE.GetTextSize(nameText, _fMsgBold) end
        end

        local bodyText
        if ch == Chat.CH_ME then bodyText = msg.text
        elseif ch == Chat.CH_DO then bodyText = msg.text
        elseif ch == Chat.CH_NA then bodyText = msg.text
        else bodyText = msg.text end

        local prefixW = timeW + nameW
        local firstMaxW = maxW - prefixW
        local lines = {}

        if TextWrap and firstMaxW > 0 then
            local narrowLines = TextWrap(bodyText, _fHud, lineH, firstMaxW)
            if narrowLines and narrowLines[1] then
                local firstLine = string.gsub(narrowLines[1], "%.%.%.$", "")
                lines[1] = firstLine
                local rest = string.sub(bodyText, #firstLine + 1):gsub("^%s+", "")
                if rest ~= "" then
                    local restLines = TextWrap(rest, _fHud, lineH, maxW)
                    if restLines then for _, rl in ipairs(restLines) do lines[#lines + 1] = rl end end
                end
            else
                lines[1] = bodyText
            end
        else
            lines = { bodyText }
        end

        wrappedMsgs[i] = {
            lines = lines,
            msg = msg,
            timeText = timeText,
            timeW = timeW,
            nameText = nameText,
            nameW = nameW,
            prefixW = prefixW,
        }
        totalLines = totalLines + #lines
    end

    local msgGap = R:Y(4)
    local baseY = fy + fh - totalLines * lineH - #visible * msgGap - R:Y(8)
    local curY = baseY

    for i = #visible, 1, -1 do
        local wm = wrappedMsgs[i]
        if not wm then continue end
        local msg = wm.msg
        local ch = msg.channel or Chat.CH_IC
        local age = now - msg.addedAt
        local fadeStart = lifetime - 3
        local alpha = age > fadeStart and math.Clamp(1 - (age - fadeStart) / 3, 0, 1) or 1
        local a255 = math.floor(220 * alpha)
        local textCol = Chat:GetChannelColor(ch, msg.success)
        local nameCol = Chat:GetNameColor(ch, msg.sender)

        for li, line in ipairs(wm.lines) do
            local lx = baseX
            if li == 1 then
                if wm.timeText ~= "" then
                    _mHudTime.a = a255
                    drawTextShadow(wm.timeText, _fTime, lx, curY, _mHudTime, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    lx = lx + wm.timeW
                end

                if wm.nameText ~= "" then
                    _mHudName.r, _mHudName.g, _mHudName.b, _mHudName.a = nameCol.r, nameCol.g, nameCol.b, a255
                    drawTextShadow(wm.nameText, _fMsgBold, lx, curY, _mHudName, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    lx = lx + wm.nameW
                end

                _mHudCol.r, _mHudCol.g, _mHudCol.b, _mHudCol.a = textCol.r, textCol.g, textCol.b, a255
                drawTextShadow(line, _fHud, lx, curY, _mHudCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                _mHudCol.r, _mHudCol.g, _mHudCol.b, _mHudCol.a = textCol.r, textCol.g, textCol.b, a255
                drawTextShadow(line, _fHud, baseX, curY, _mHudCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            curY = curY + lineH
        end
        curY = curY + msgGap
    end
end)

if _hrState and _hrState.WasOpen then
    local savedText = _hrState.EntryText or ""
    timer.Simple(0.1, function()
        Chat:Open()
        if savedText ~= "" and IsValid(Chat.UI.Entry) then
            Chat.UI.Entry:SetValue(savedText)
            Chat.UI.Entry:SetCaretPos(#savedText)
        end
    end)
end

_hrState = nil

-- ─── Bulles /me au-dessus des têtes ───────────────────────────────────────────

local _meBubbles   = {}   -- { [sid64] = { text, startTime, duration } }
local _meFontReady = false

local function meFontEnsure()
    if _meFontReady then return end
    _meFontReady = true
    surface.CreateFont("VERSE_MeBubble", {
        font = "Poppins", size = 40, weight = 500, antialias = true,
    })
end

-- Cache sid64→player mis à jour via les hooks pour éviter player.GetAll() à chaque frame de rendu.
local _meSid64Map = {}
hook.Add("PlayerSpawn",        "VERSE::MeBubble::SidMapAdd",    function(p) if IsValid(p) then _meSid64Map[p:SteamID64()] = p end end)
hook.Add("PlayerDisconnected", "VERSE::MeBubble::SidMapRemove", function(p) if IsValid(p) then _meSid64Map[p:SteamID64()] = nil end end)
hook.Add("InitPostEntity",     "VERSE::MeBubble::SidMapInit",   function()
    _meSid64Map = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then _meSid64Map[p:SteamID64()] = p end
    end
end)

local function meFindPlayer(sid64)
    local p = _meSid64Map[sid64]
    if p and IsValid(p) then return p end
    -- Fallback lent si le cache est vide/désynchronisé
    for _, pl in ipairs(player.GetAll()) do
        if IsValid(pl) and pl:SteamID64() == sid64 then
            _meSid64Map[sid64] = pl
            return pl
        end
    end
end

-- Découpe le texte en lignes ne dépassant pas maxW pixels (en unités 2D)
local function meWrapText(text, maxW)
    surface.SetFont("VERSE_MeBubble")
    local words   = string.Explode(" ", text)
    local lines   = {}
    local current = ""
    for _, word in ipairs(words) do
        local test = current == "" and word or (current .. " " .. word)
        if surface.GetTextSize(test) > maxW and current ~= "" then
            lines[#lines + 1] = current
            current = word
        else
            current = test
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return lines
end

-- Déclenché depuis le handler netstream ci-dessus
hook.Add("VERSE::Chat::MeMessage", "VERSE::MeBubble::Store", function(sid64, text)
    local duration = math.Clamp(#text * 0.055 + 3.5, 4.5, 9)
    _meBubbles[sid64] = {
        text      = "* " .. text .. " *",
        startTime = RealTime(),
        duration  = duration,
    }
end)

-- Couleurs pré-allouées pour le rendu des bulles /me (évite Color() dans la boucle de rendu)
local _meBubbleColShadow = Color(0,   0,   0,   200)
local _meBubbleColText   = Color(255, 255, 255, 255)
local _meHeadOffset      = Vector(0, 0, 22)
local _meFallbackOffset  = Vector(0, 0, 95)

-- Rendu 3D des bulles dans le monde
VERSE.Hook.AddNS("Chat", "PostDrawTranslucentRenderables", "VERSE::MeBubble::Draw", function(_, _, skybox)
    if skybox then return end
    meFontEnsure()

    local now         = RealTime()
    local viewPos     = EyePos()
    local MAX_DIST_SQ = 650 * 650
    local MAX_LINE_W  = 560

    for sid64, bubble in pairs(_meBubbles) do
        local elapsed = now - bubble.startTime

        if elapsed >= bubble.duration then
            _meBubbles[sid64] = nil
            continue
        end

        local ply = meFindPlayer(sid64)
        if not IsValid(ply) or not ply:Alive() then continue end
        if viewPos:DistToSqr(ply:GetPos()) > MAX_DIST_SQ then continue end

        -- Alpha : fade-in rapide (5 %), plein, fade-out sur les 30 % finaux
        local prog  = elapsed / bubble.duration
        local alpha
        if prog < 0.05 then
            alpha = math.floor(255 * (prog / 0.05))
        elseif prog > 0.70 then
            alpha = math.floor(255 * (1 - (prog - 0.70) / 0.30))
        else
            alpha = 255
        end
        if alpha <= 0 then continue end

        -- Position : au-dessus du bone de tête
        local headPos
        local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then
            local mat = ply:GetBoneMatrix(headBone)
            if mat then headPos = mat:GetTranslation() + _meHeadOffset end
        end
        headPos = headPos or (ply:GetPos() + _meFallbackOffset)

        local dist  = viewPos:Distance(ply:GetPos())
        local scale = math.Clamp(0.07 + dist / 4800, 0.07, 0.19)
        local ang   = (headPos - viewPos):Angle()

        cam.Start3D2D(headPos, Angle(0, ang.y - 90, 90), scale)

            local lines  = meWrapText(bubble.text, MAX_LINE_W)
            local lh     = 43
            local totalH = #lines * lh

            -- Texte uniquement : ombre portée + blanc pur, sans fond ni bordure
            -- Réutilisation des Color pré-alloués (mutation de .a uniquement)
            _meBubbleColShadow.a = math.floor(200 * alpha / 255)
            _meBubbleColText.a   = alpha
            for i, line in ipairs(lines) do
                local ly = -totalH / 2 + (i - 1) * lh + lh * 0.5
                -- Ombre
                draw.SimpleText(line, "VERSE_MeBubble", 1, ly + 1,
                    _meBubbleColShadow,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                -- Texte blanc
                draw.SimpleText(line, "VERSE_MeBubble", 0, ly,
                    _meBubbleColText,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

        cam.End3D2D()
    end
end)
