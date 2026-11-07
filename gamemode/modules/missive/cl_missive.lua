local M    = VERSE.Missive
local CH   = VERSE.Characters
local R    = VERSE.Responsive
local Font = VERSE.Fonts
local Mats = VERSE.Materials
if not M or not R or not Font then return end

Mats:SetAlias("missive_bg",   "verse/missive/Rectangle133")
Mats:SetAlias("missive_pill", "verse/missive/Rectangle135")
Mats:SetAlias("missive_text", "verse/missive/Rectangle149")

M.Client = M.Client or { missives = {}, loaded = false }

-- ─── Palette ──────────────────────────────────────────────────────────────────
local C_BG      = Color(26,  22,  37,  242)
local C_PANEL   = Color(42,  36,  56,  242)
local C_INPUT   = Color(58,  52,  69,  242)
local C_SEL     = Color(90,  84,  104, 242)
local C_HOVER   = Color(70,  64,  82,  242)
local C_VIOLET  = Color(139, 92,  246, 242)
local C_VIOLETH = Color(162, 116, 255, 242)
local C_WHITE   = Color(255, 255, 255)
local C_GRAY    = Color(156, 163, 175)

-- ─── Couleurs pré-allouées (évite Color() par frame) ─────────────────────────
local _MSV_COL_FRAME_BG    = Color(20,  15,  35,  180)
local _MSV_COL_MAT_BG      = Color(255, 255, 255, 45)
local _MSV_COL_ICON        = Color(255, 255, 255, 255)   -- .a muté (hovered 255 vs 140)
local _MSV_COL_PANEL_BG1   = Color(30,  25,  46,  152)
local _MSV_COL_PANEL_BG2   = Color(30,  25,  46,  190)
-- ─────────────────────────────────────────────────────────────────────────────

local RESULT_MSGS = {
    no_recipient  = "Destinataire introuvable.",
    empty         = "Objet ou message vide.",
    db_error      = "Erreur serveur, réessayez.",
    no_character  = "Aucun personnage sélectionné.",
    bad_character = "Personnage invalide.",
}

-- ─── State ────────────────────────────────────────────────────────────────────
local _frame         = nil
local _selRecip      = nil   -- { id, name }
local _selMsg        = nil   -- inbox entry being read
local _cFilter       = ""    -- compose search filter
local _iFilter       = ""    -- inbox search filter
local _curTab        = "compose"
local _onListRefresh  = nil   -- set when frame is open
local _onSendResult   = nil   -- set when frame is open
local _buildInboxList = nil   -- forward declaration, assigned inside openMissive

local function pill(h) return math.floor(h * 0.55) end

local function styleVBar(vbar)
    vbar.Paint = function(s, w, h)
        RNDX.Draw(w, 0, 0, w, h, _MSV_COL_FRAME_BG)
    end
    vbar.btnUp.Paint   = function() end
    vbar.btnDown.Paint = function() end
    vbar.btnGrip.Paint = function(s, w, h)
        RNDX.Draw(w, 0, 0, w, h, C_VIOLET)
    end
end

local function formatDate(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return "" end
    return os.date("%d/%m/%y %H:%M", ts)
end

local function textEntry(parent, x, y, w, h, placeholder, multi)
    local rad = multi and R:Y(12) or pill(h)
    local bg = vgui.Create("DPanel", parent)
    bg:SetPos(x, y) ; bg:SetSize(w, h)
    bg.Paint = function(s, pw, ph) RNDX.Draw(rad, 0, 0, pw, ph, C_INPUT) end

    local e = vgui.Create("DTextEntry", bg)
    local px = R:X(18)
    if multi then
        e:SetPos(px, R:Y(10))
        e:SetSize(w - px*2, h - R:Y(20))
        e:SetMultiline(true)
    else
        e:SetPos(px, 0)
        e:SetSize(w - px*2, h)
    end
    e:SetDrawBackground(false) ; e:SetDrawBorder(false) ; e:SetPaintBackground(false)
    e:SetPlaceholderText(placeholder) ; e:SetPlaceholderColor(C_GRAY)
    e:SetTextColor(C_WHITE) ; e:SetFont(Font:GetNamed("Poppins", "Regular", 15))
    return bg, e
end

-- ─── Open ─────────────────────────────────────────────────────────────────────
local function openMissive()
    if IsValid(_frame) then _frame:Remove() end
    _selRecip = nil ; _selMsg = nil ; _cFilter = "" ; _iFilter = "" ; _curTab = "compose"

    local FW, FH = R:X(960), R:Y(760)
    local fr = vgui.Create("DFrame")
    fr:SetPos((ScrW()-FW)*.5, (ScrH()-FH)*.5)
    fr:SetSize(FW, FH) ; fr:SetTitle("") ; fr:SetDraggable(true)
    fr:ShowCloseButton(false) ; fr:MakePopup()
    _frame = fr

    fr.Paint = function(s, w, h) RNDX.Draw(R:Y(20), 0, 0, w, h, C_BG) end
    -- OnRemove est défini plus bas, après buildInboxList, pour pouvoir inclure _buildInboxList

    -- Main container
    local MP = R:X(14) ; local MPY = R:Y(14)
    local MW = FW - MP*2 ; local MH = FH - MPY*2
    local main = vgui.Create("DPanel", fr)
    main:SetPos(MP, MPY) ; main:SetSize(MW, MH)
    main.Paint = function(s, w, h)
        RNDX.Draw(R:Y(16), 0, 0, w, h, C_PANEL)
        Mats:Draw(_MSV_COL_MAT_BG, "missive_bg", 0, 0, w, h)
    end

    local PAD = R:X(22) ; local PADY = R:Y(18)
    local TITLEH = R:Y(56)

    -- ── Close ─────────────────────────────────────────────────────────────────
    local cbtn = vgui.Create("DButton", main)
    cbtn:SetPos(MW - R:X(36), R:Y(14)) ; cbtn:SetSize(R:X(22), R:Y(22)) ; cbtn:SetText("")
    local _cbtnFont = Font:GetNamed("Poppins", "Regular", 15)
    cbtn.Paint = function(s, w, h)
        -- Mutation de la couleur pré-allouée (évite Color() à chaque frame)
        _MSV_COL_ICON.a = s:IsHovered() and 255 or 140
        draw.SimpleText("✕", _cbtnFont, w*.5, h*.5, _MSV_COL_ICON, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    cbtn.DoClick = function() fr:Remove() end

    -- ── Title ─────────────────────────────────────────────────────────────────
    local titleLbl = vgui.Create("DLabel", main)
    titleLbl:SetPos(0, PADY) ; titleLbl:SetSize(MW, TITLEH)
    titleLbl:SetFont(Font:GetNamed("Poppins","Bold",30))
    titleLbl:SetTextColor(C_WHITE) ; titleLbl:SetContentAlignment(5)
    titleLbl:SetText("Missives — Envoi")

    -- ── Tabs ──────────────────────────────────────────────────────────────────
    local TAB_W = R:X(116) ; local TAB_H = R:Y(30) ; local TAB_Y = PADY + R:Y(10)
    local _tabBtns = {}

    local contentY = PADY + TITLEH + R:Y(10)
    local contentH = MH - contentY - PADY
    local contentW = MW - PAD*2

    -- Content panels
    local composePanel = vgui.Create("DPanel", main)
    composePanel:SetPos(PAD, contentY) ; composePanel:SetSize(contentW, contentH)
    composePanel.Paint = function() end

    local inboxPanel = vgui.Create("DPanel", main)
    inboxPanel:SetPos(PAD, contentY) ; inboxPanel:SetSize(contentW, contentH)
    inboxPanel.Paint = function() end
    inboxPanel:SetVisible(false)

    local function switchTab(tabId)
        _curTab = tabId
        for id, btn in pairs(_tabBtns) do btn._active = (id == tabId) end
        titleLbl:SetText(tabId == "compose" and "Missives — Envoi" or "Missives — Réception")
        composePanel:SetVisible(tabId == "compose")
        inboxPanel:SetVisible(tabId == "inbox")
        if tabId == "inbox" then
            -- Décaler d'une frame pour que inboxPanel ait eu le temps de PerformLayout
            -- (sinon canvas.wide = 0, les boutons Dock(TOP) ont width=0 et sont invisibles)
            timer.Simple(0, function()
                if not IsValid(iScroll) then return end
                if _buildInboxList then _buildInboxList() end
            end)
            -- Demander les données au serveur (arrivera après le timer de toute façon)
            netstream.Start(M.Net.List)
        end
    end

    local tabDefs = { { id="compose", label="Envoi" }, { id="inbox", label="Réception" } }
    for i, t in ipairs(tabDefs) do
        local btn = vgui.Create("DButton", main)
        local bx = PAD + (i-1)*(TAB_W + R:X(8))
        btn:SetPos(bx, TAB_Y) ; btn:SetSize(TAB_W, TAB_H) ; btn:SetText("") ; btn:SetCursor("hand")
        btn._active = (t.id == _curTab)
        local _id = t.id ; local _lbl = t.label
        btn.Paint = function(s, w, h)
            local bg = btn._active and C_VIOLET or (s:IsHovered() and C_HOVER or C_INPUT)
            RNDX.Draw(pill(h), 0, 0, w, h, bg)
            draw.SimpleText(_lbl, Font:GetNamed("Poppins", btn._active and "SemiBold" or "Regular", 13),
                w*.5, h*.5, C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() switchTab(_id) end
        _tabBtns[t.id] = btn
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- COMPOSE
    -- ─────────────────────────────────────────────────────────────────────────
    local LEFTW  = R:X(240) ; local GAP = R:X(14)
    local RIGHTW = contentW - LEFTW - GAP ; local RIGHTX = LEFTW + GAP
    local SEARCHH = R:Y(42) ; local ITEMH = R:Y(45) ; local ITEMGAP = R:Y(8)

    -- Left search
    local _, cSearchE = textEntry(composePanel, 0, 0, LEFTW, SEARCHH, "Rechercher")

    -- Left list bg
    local cListBg = vgui.Create("DPanel", composePanel)
    cListBg:SetPos(0, SEARCHH + R:Y(10)) ; cListBg:SetSize(LEFTW, contentH - SEARCHH - R:Y(10))
    cListBg.Paint = function(s, w, h) RNDX.Draw(R:Y(14), 0, 0, w, h, _MSV_COL_PANEL_BG1) end

    local cScroll = vgui.Create("DScrollPanel", cListBg)
    cScroll:SetPos(R:X(8), R:Y(8)) ; cScroll:SetSize(LEFTW - R:X(16), cListBg:GetTall() - R:Y(16))
    styleVBar(cScroll:GetVBar())

    -- Right compose pane
    local cRight = vgui.Create("DPanel", composePanel)
    cRight:SetPos(RIGHTX, 0) ; cRight:SetSize(RIGHTW, contentH)
    cRight.Paint = function(s, w, h) RNDX.Draw(R:Y(16), 0, 0, w, h, _MSV_COL_PANEL_BG2) end

    local RPAD = R:X(20) ; local RPADY = R:Y(18)

    local cRecipLbl = vgui.Create("DLabel", cRight)
    cRecipLbl:SetPos(RPAD, RPADY) ; cRecipLbl:SetSize(RIGHTW - RPAD*2, R:Y(38))
    cRecipLbl:SetFont(Font:GetNamed("Poppins","Bold",19))
    cRecipLbl:SetTextColor(C_GRAY) ; cRecipLbl:SetContentAlignment(5)
    cRecipLbl:SetText("Sélectionner un destinataire")

    local function updateRecipLbl()
        if _selRecip then
            cRecipLbl:SetText(_selRecip.name) ; cRecipLbl:SetTextColor(C_WHITE)
        else
            cRecipLbl:SetText("Sélectionner un destinataire") ; cRecipLbl:SetTextColor(C_GRAY)
        end
    end

    local INPH   = R:Y(44)
    local cTitleY = RPADY + R:Y(38) + R:Y(12)
    local _, cTitleE = textEntry(cRight, RPAD, cTitleY, RIGHTW - RPAD*2, INPH, "Titre")

    local BODYH = contentH - RPADY - R:Y(38) - R:Y(12) - INPH - R:Y(12) - R:Y(50) - R:Y(18)
    local cBodyY = cTitleY + INPH + R:Y(12)
    local _, cBodyE = textEntry(cRight, RPAD, cBodyY, RIGHTW - RPAD*2, BODYH, "Texte", true)

    local BTNH = R:Y(46) ; local BTNW = R:X(160)
    local cBtnY = cBodyY + BODYH + R:Y(14)
    local cSendBtn = vgui.Create("DButton", cRight)
    cSendBtn:SetPos(RPAD + math.floor((RIGHTW - RPAD*2 - BTNW)*.5), cBtnY)
    cSendBtn:SetSize(BTNW, BTNH) ; cSendBtn:SetText("") ; cSendBtn:SetCursor("hand")
    cSendBtn.Paint = function(s, w, h)
        RNDX.Draw(pill(h), 0, 0, w, h, s:IsHovered() and C_VIOLETH or C_VIOLET)
        draw.SimpleText("Envoyer", Font:GetNamed("Poppins","SemiBold",18),
            w*.5, h*.5, C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    cSendBtn.DoClick = function()
        if not _selRecip then LocalPlayer():Notify("Sélectionner un destinataire.", NOTIFY_ERROR, 3) ; return end
        local title = cTitleE:GetValue():Trim()
        local body  = cBodyE:GetValue():Trim()
        if title == "" or body == "" then LocalPlayer():Notify("Titre et texte requis.", NOTIFY_ERROR, 3) ; return end
        cSendBtn:SetEnabled(false)
        netstream.Start(M.Net.Send, { recipient_char_id = _selRecip.id, title = title, body = body })
    end

    -- Player list builder
    local function buildPlayerList()
        local cCanvas   = cScroll:GetCanvas()
        cCanvas:Clear()
        local API        = CH.Introduce
        local acqEnabled = CH.AcquaintancesEnabled and CH:AcquaintancesEnabled() or false
        local filterLow  = _cFilter:lower()
        local lp         = LocalPlayer()
        local count = 0

        for _, ply in ipairs(player.GetAll()) do
            if ply == lp then continue end
            local charId = API and API.GetCharId(ply) or 0
            if charId <= 0 then continue end
            if acqEnabled and not (API and API.KnowsPlayer(ply)) then continue end
            local name = (API and acqEnabled and API.GetKnownName(charId)) or ply:Nick()
            if filterLow ~= "" and not name:lower():find(filterLow, 1, true) then continue end

            count = count + 1
            local btn = vgui.Create("DButton", cCanvas)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, ITEMGAP)
            btn:SetTall(ITEMH)
            btn:SetText("") ; btn:SetCursor("hand")
            local _id = charId ; local _name = name
            btn.Paint = function(s, w, h)
                local isSel = _selRecip and _selRecip.id == _id
                local bg = isSel and C_SEL or (s:IsHovered() and C_HOVER or C_INPUT)
                RNDX.Draw(pill(h), 0, 0, w, h, bg)
                draw.SimpleText(_name, Font:GetNamed("Poppins", isSel and "Bold" or "Regular", 14),
                    w*.5, h*.5, C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function()
                _selRecip = { id = _id, name = _name }
                updateRecipLbl()
                cScroll:InvalidateLayout(true)
            end
        end

        if count == 0 then
            local items = filterLow == "" and { { text = "????", color = C_GRAY } } or {}
            for i = 1, math.max(1, 10 - #items) do
                items[#items+1] = { text = "", color = C_INPUT }
            end
            for _, item in ipairs(items) do
                local pnl = vgui.Create("DPanel", cCanvas)
                pnl:Dock(TOP)
                pnl:DockMargin(0, 0, 0, ITEMGAP)
                pnl:SetTall(ITEMH)
                local _t = item.text ; local _c = item.color
                pnl.Paint = function(s, w, h)
                    RNDX.Draw(pill(h), 0, 0, w, h, C_INPUT)
                    if _t ~= "" then
                        draw.SimpleText(_t, Font:GetNamed("Poppins","Regular",14),
                            w*.5, h*.5, _c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
        end

        cScroll:InvalidateLayout(true)
        cCanvas:InvalidateLayout(true)
    end

    cSearchE.OnChange = function(s) _cFilter = s:GetValue() ; buildPlayerList() end
    buildPlayerList()

    -- ─────────────────────────────────────────────────────────────────────────
    -- INBOX
    -- ─────────────────────────────────────────────────────────────────────────
    local _, iSearchE = textEntry(inboxPanel, 0, 0, LEFTW, SEARCHH, "Rechercher")

    local iListBg = vgui.Create("DPanel", inboxPanel)
    iListBg:SetPos(0, SEARCHH + R:Y(10)) ; iListBg:SetSize(LEFTW, contentH - SEARCHH - R:Y(10))
    iListBg.Paint = function(s, w, h) RNDX.Draw(R:Y(14), 0, 0, w, h, _MSV_COL_PANEL_BG1) end

    local iScroll = vgui.Create("DScrollPanel", iListBg)
    iScroll:SetPos(R:X(8), R:Y(8)) ; iScroll:SetSize(LEFTW - R:X(16), iListBg:GetTall() - R:Y(16))
    styleVBar(iScroll:GetVBar())

    -- Read pane
    local iRight = vgui.Create("DPanel", inboxPanel)
    iRight:SetPos(RIGHTX, 0) ; iRight:SetSize(RIGHTW, contentH)
    iRight.Paint = function(s, w, h) RNDX.Draw(R:Y(16), 0, 0, w, h, _MSV_COL_PANEL_BG2) end

    local iSenderLbl = vgui.Create("DLabel", iRight)
    iSenderLbl:SetPos(RPAD, RPADY) ; iSenderLbl:SetSize(RIGHTW - RPAD*2, R:Y(32))
    iSenderLbl:SetFont(Font:GetNamed("Poppins","Bold",18)) ; iSenderLbl:SetTextColor(C_WHITE) ; iSenderLbl:SetContentAlignment(5)
    iSenderLbl:SetText("")

    local iTitleLbl = vgui.Create("DLabel", iRight)
    iTitleLbl:SetPos(RPAD, RPADY + R:Y(34)) ; iTitleLbl:SetSize(RIGHTW - RPAD*2, R:Y(26))
    iTitleLbl:SetFont(Font:GetNamed("Poppins","SemiBold",14)) ; iTitleLbl:SetTextColor(C_GRAY) ; iTitleLbl:SetContentAlignment(5)
    iTitleLbl:SetText("")

    local iDateLbl = vgui.Create("DLabel", iRight)
    iDateLbl:SetPos(RPAD, RPADY + R:Y(34) + R:Y(26)) ; iDateLbl:SetSize(RIGHTW - RPAD*2, R:Y(22))
    iDateLbl:SetFont(Font:GetNamed("Poppins","Regular",12)) ; iDateLbl:SetTextColor(Color(120,115,140)) ; iDateLbl:SetContentAlignment(5)
    iDateLbl:SetText("")

    local IBODYY = RPADY + R:Y(34) + R:Y(26) + R:Y(22) + R:Y(12)
    local IBODYH = contentH - IBODYY - RPADY
    local iBodyBg = vgui.Create("DPanel", iRight)
    iBodyBg:SetPos(RPAD, IBODYY) ; iBodyBg:SetSize(RIGHTW - RPAD*2, IBODYH)
    iBodyBg.Paint = function(s, w, h) RNDX.Draw(R:Y(12), 0, 0, w, h, C_INPUT) end

    local iBodyRt = vgui.Create("DTextEntry", iBodyBg)
    iBodyRt:SetPos(R:X(16), R:Y(12)) ; iBodyRt:SetSize(RIGHTW - RPAD*2 - R:X(32), IBODYH - R:Y(24))
    iBodyRt:SetMultiline(true)
    iBodyRt:SetEditable(false)
    iBodyRt:SetDrawBackground(false)
    iBodyRt:SetDrawBorder(false)
    iBodyRt:SetPaintBackground(false)
    iBodyRt:SetTextColor(C_WHITE)
    iBodyRt:SetFont(Font:GetNamed("Poppins", "Regular", 13))

    local function showMsg(msg)
        _selMsg = msg
        if not msg then
            iSenderLbl:SetText("") ; iTitleLbl:SetText("") ; iDateLbl:SetText("") ; iBodyRt:SetText("") ; return
        end
        iSenderLbl:SetText("De : " .. tostring(msg.sender_name or "?"))
        iTitleLbl:SetText(tostring(msg.title or ""))
        iDateLbl:SetText(formatDate(msg.created_at))
        iBodyRt:SetText(tostring(msg.body or ""))
        local alreadyRead = msg.is_read == true or msg.is_read == 1
        if not alreadyRead then
            netstream.Start(M.Net.MarkRead, msg.id)
            msg.is_read = 1
        end
        iScroll:InvalidateLayout(true)
    end

    local function buildInboxList()
        -- Force le DScrollPanel à recalculer sa taille de canvas avant d'y ajouter des enfants
        iScroll:PerformLayout()
        local canvas = iScroll:GetCanvas()
        canvas:Clear()

        local filterLow = _iFilter:lower()
        local count = 0

        for _, msg in ipairs(M.Client.missives) do
            local sender = tostring(msg.sender_name or "?")
            local title  = tostring(msg.title or "")
            if filterLow == "" or sender:lower():find(filterLow,1,true) or title:lower():find(filterLow,1,true) then
                count = count + 1
                local btn = vgui.Create("DButton", canvas)
                btn:Dock(TOP)
                btn:DockMargin(0, 0, 0, ITEMGAP)
                btn:SetTall(ITEMH)
                btn:SetText("") ; btn:SetCursor("hand")
                local _msg = msg ; local _sender = sender ; local _title = title
                btn.Paint = function(s, w, h)
                    local isSel  = _selMsg and _selMsg.id == _msg.id
                    local isRead = _msg.is_read == true or _msg.is_read == 1
                    local bg = isSel and C_SEL or (s:IsHovered() and C_HOVER or C_INPUT)
                    RNDX.Draw(pill(h), 0, 0, w, h, bg)
                    if not isRead then
                        RNDX.Draw(R:Y(4), w - R:X(10), R:Y(5), R:Y(8), R:Y(8), C_VIOLET)
                    end
                    draw.SimpleText(_sender, Font:GetNamed("Poppins", isRead and "Regular" or "SemiBold", 13),
                        w*.5, h*.5 - R:Y(7), C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText(_title, Font:GetNamed("Poppins","Regular",11),
                        w*.5, h*.5 + R:Y(7), C_GRAY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                btn.DoClick = function() showMsg(_msg) end
            end
        end

        if count == 0 then
            for i = 1, 6 do
                local pnl = vgui.Create("DPanel", canvas)
                pnl:Dock(TOP)
                pnl:DockMargin(0, 0, 0, ITEMGAP)
                pnl:SetTall(ITEMH)
                pnl.Paint = function(s, w, h) RNDX.Draw(pill(h), 0, 0, w, h, C_INPUT) end
            end
        end

        iScroll:InvalidateLayout(true)
        canvas:InvalidateLayout(true)
    end

    iSearchE.OnChange = function(s) _iFilter = s:GetValue() ; buildInboxList() end

    -- Exposer buildInboxList via la variable module pour que switchTab puisse l'appeler
    _buildInboxList = function()
        if IsValid(iScroll) then buildInboxList() end
    end

    _onListRefresh = _buildInboxList

    fr.OnRemove = function()
        _frame          = nil
        _onListRefresh  = nil
        _onSendResult   = nil
        _buildInboxList = nil
    end

    _onSendResult = function(ok, reason)
        if IsValid(cSendBtn) then cSendBtn:SetEnabled(true) end
        if ok then
            LocalPlayer():Notify("Missive envoyée.", NOTIFY_HINT, 4)
            if IsValid(cTitleE) then cTitleE:SetText("") end
            if IsValid(cBodyE)  then cBodyE:SetText("") end
        else
            local msg = RESULT_MSGS[tostring(reason)] or "Erreur inconnue."
            LocalPlayer():Notify(msg, NOTIFY_ERROR, 5)
        end
    end
end

-- ─── Netstream ────────────────────────────────────────────────────────────────
netstream.Hook(M.Net.List, function(list)
    M.Client.missives = istable(list) and list or {}
    M.Client.loaded   = true
    if _onListRefresh then _onListRefresh() end
end)

netstream.Hook(M.Net.Result, function(ok, reason)
    if _onSendResult then
        _onSendResult(ok, reason)
    else
        if ok then LocalPlayer():Notify("Missive envoyée.", NOTIFY_HINT, 4)
        else LocalPlayer():Notify(RESULT_MSGS[tostring(reason)] or "Erreur inconnue.", NOTIFY_ERROR, 5) end
    end
end)

netstream.Hook(M.Net.Notify, function(senderName, title)
    VERSE.Notify:Push("✉  Missive de " .. tostring(senderName) .. " : " .. tostring(title), NOTIFY_GENERIC, 7)
    -- Précharger la liste immédiatement (panneau ouvert ou non)
    -- Quand la réponse arrive, _onListRefresh mettra à jour l'UI si le panneau est ouvert
    netstream.Start(M.Net.List)
end)

-- ─── Commande ─────────────────────────────────────────────────────────────────
concommand.Add("verse_missive", function()
    if not IsValid(LocalPlayer()) then return end
    openMissive()
end)
