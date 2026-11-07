-- ─────────────────────────────────────────────────────────────────────────────
-- VERSE :: SkillTree :: Balancing  (client)
-- Menu VGUI temps réel — accès superadmin uniquement.
-- Reçoit les overrides via netstream, les affiche et permet de les modifier.
-- ─────────────────────────────────────────────────────────────────────────────

if not CLIENT then return end

local ST   = VERSE.SkillTree
local BAL  = ST.Balancing
local NET  = BAL.Net
local R    = VERSE.Responsive
local Font = VERSE.Fonts

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function lerpFactor(speed)
    return math.Clamp(FrameTime() * speed, 0, 1)
end
local function smooth(current, target, speed)
    return Lerp(lerpFactor(speed or 12), current or 0, target or 0)
end

-- Couleurs globales
local COL_BG        = Color(6,  8, 14, 252)
local COL_BG2       = Color(10, 13, 22, 255)
local COL_BORDER    = Color(255, 255, 255, 18)
local COL_HEADER    = Color(14, 18, 30, 255)
local COL_ROW_EVEN  = Color(12, 15, 25, 200)
local COL_ROW_ODD   = Color(8,  11, 20, 200)
local COL_ACCENT    = Color(120, 80, 220)
local COL_WARN      = Color(220, 100, 60)
local COL_OK        = Color(60, 200, 120)
local COL_TEXT      = Color(210, 215, 230)
local COL_MUTED     = Color(120, 128, 148)
local COL_MODIFIED  = Color(255, 200, 60)
-- ─── Couleurs Paint pré-allouées ─────────────────────────────────────────────
local _STB_COL_SHADOW           = Color(0,   0,   0,   140)
local _STB_COL_ACCENT_TITLE     = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 240)
local _STB_COL_ACCENT_BADGE     = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 140)
local _STB_COL_SBAR_BG          = Color(20,  22,  35,  200)
local _STB_COL_SBAR_GRIP        = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 140)
local _STB_COL_INP_BG           = Color(18,  22,  38,  230)
local _STB_COL_INP_OUT          = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 40)  -- .a muté
local _STB_COL_INP_SEL          = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 200)
local _STB_COL_CLOSE_WARN       = Color(COL_WARN.r,   COL_WARN.g,   COL_WARN.b,   0)   -- .a muté
local _STB_COL_CLOSE_X          = Color(220, 220, 230, 200)                              -- .a muté
local _STB_COL_SRCH_SEL         = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 180)

-- Récupère la valeur "brute" d'un node (avant tout override).
local function getRawNodeValue(nodeId, field)
    for _, cat in ipairs(ST.Tree or {}) do
        for _, sub in ipairs(cat.subtypes or {}) do
            for _, n in ipairs(sub.nodes or {}) do
                if n.id == nodeId then
                    return tonumber(n[field]) or (field == "maxRank" and 1 or 1)
                end
            end
        end
    end
    return 1
end

-- Construit la liste plate des nodes groupés par catégorie/subtype
local function buildNodeList()
    local list = {}
    for _, cat in ipairs(ST.Tree or {}) do
        for _, sub in ipairs(cat.subtypes or {}) do
            for _, node in ipairs(sub.nodes or {}) do
                list[#list + 1] = {
                    id       = node.id,
                    label    = node.title or node.id,
                    cat      = cat,
                    sub      = sub,
                    rawCost  = tonumber(node.cost)    or 1,
                    rawMR    = tonumber(node.maxRank)  or 1,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.cat.id ~= b.cat.id then return (a.cat.id or "") < (b.cat.id or "") end
        if a.sub.id ~= b.sub.id then return (a.sub.id or "") < (b.sub.id or "") end
        return (a.label or "") < (b.label or "")
    end)
    return list
end

-- ─── Fenêtre principale ───────────────────────────────────────────────────────

local _frame = nil

local function openBalancingMenu()
    if not IsValid(LocalPlayer()) then return end
    if not LocalPlayer():IsSuperAdmin() and not (LocalPlayer().IsDeveloper and LocalPlayer():IsDeveloper()) then
        notification.AddLegacy("Accès refusé.", NOTIFY_ERROR, 3)
        return
    end

    -- Ne réouvrir que si déjà ouvert → rafraîchit
    if IsValid(_frame) then _frame:Remove() end

    local scrW, scrH = ScrW(), ScrH()
    local FW = math.min(R:X(1280), scrW - R:X(80))
    local FH = math.min(R:Y(800),  scrH - R:Y(60))
    local FX = math.floor((scrW - FW) * 0.5)
    local FY = math.floor((scrH - FH) * 0.5)

    local frame = vgui.Create("DFrame")
    frame:SetSize(FW, FH)
    frame:SetPos(FX, FY)
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:SetSizable(true)
    frame:SetDeleteOnClose(true)
    frame:MakePopup()
    _frame = frame

    -- ── Ferme le panneau standard ──
    for _, child in ipairs(frame:GetChildren()) do
        if child.ClassName == "DLabel" or child.ClassName == "DImageButton" then
            child:SetVisible(false)
        end
    end

    local fontTitle   = Font:GetNamed("Poppins", "Bold",     20)
    local fontHeader  = Font:GetNamed("Poppins", "SemiBold", 13)
    local fontRow     = Font:GetNamed("Poppins", "Medium",   13)
    local fontRowSm   = Font:GetNamed("Poppins", "Regular",  11)
    local fontBtn     = Font:GetNamed("Poppins", "SemiBold", 13)
    local fontInput   = Font:GetNamed("Poppins", "Regular",  13)
    local fontSearch  = Font:GetNamed("Poppins", "Regular",  13)

    -- ── Fond principal ──
    frame.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(12)):Color(_STB_COL_SHADOW):DropShadow(R:X(28), R:X(40)):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:Y(12)):Color(COL_BG):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:Y(12)):Outline(1):Color(COL_BORDER):Draw()
    end

    local PAD    = R:X(14)
    local TOPBAR = R:Y(52)

    -- ── Topbar ──
    local topBar = vgui.Create("DPanel", frame)
    topBar:SetPos(0, 0)
    topBar:SetSize(FW, TOPBAR)
    topBar.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(12)):Color(COL_HEADER):Draw()
        -- ligne de séparation bas
        surface.SetDrawColor(255, 255, 255, 16)
        surface.DrawRect(PAD, h - 1, w - PAD * 2, 1)
        -- titre
        draw.SimpleText("⚖  Équilibrage du Skill Tree", fontTitle,
            PAD + R:X(6), h * 0.5,
            _STB_COL_ACCENT_TITLE,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        -- badge superadmin (décalé pour laisser place au bouton Sorts & Dégâts)
        draw.SimpleText("SUPERADMIN", fontRowSm, w - PAD - R:X(4) - R:X(170) - R:X(46), h * 0.5,
            _STB_COL_ACCENT_BADGE,
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- ── Bouton "Sorts & Dégâts" (ouvre le panneau spell balancing) ──
    local SPELLBTN_W = R:X(170)
    local btnSpells = vgui.Create("DButton", topBar)
    btnSpells:SetSize(SPELLBTN_W, R:Y(32))
    btnSpells:SetPos(FW - R:X(44) - R:X(10) - SPELLBTN_W, math.floor((TOPBAR - R:Y(32)) * 0.5))
    btnSpells:SetText("")
    btnSpells._h = 0
    local COL_SPELL_BTN = Color(80, 50, 200)
    local _spBtnFill    = Color(COL_SPELL_BTN.r, COL_SPELL_BTN.g, COL_SPELL_BTN.b, 180)
    local _spBtnOutline = Color(120, 80, 255, 60)
    local _spBtnTxt     = Color(220, 200, 255, 220)
    btnSpells.Think = function(pnl) pnl._h = smooth(pnl._h, pnl:IsHovered() and 1 or 0, 14) end
    btnSpells.Paint = function(pnl, w, h)
        local hv = pnl._h
        _spBtnFill.r = math.min(255, COL_SPELL_BTN.r + math.floor(30*hv))
        _spBtnFill.g = math.min(255, COL_SPELL_BTN.g + math.floor(20*hv))
        _spBtnFill.b = math.min(255, COL_SPELL_BTN.b + math.floor(40*hv))
        _spBtnFill.a = math.floor(180 + 60*hv)
        RNDX().Rect(0,0,w,h):Rad(R:Y(6)):Color(_spBtnFill):Draw()
        _spBtnOutline.a = math.floor(60 + 120*hv)
        RNDX().Rect(0,0,w,h):Rad(R:Y(6)):Outline(1):Color(_spBtnOutline):Draw()
        _spBtnTxt.a = 220 + math.floor(35*hv)
        draw.SimpleText("⚡ Sorts & Dégâts →", fontBtn, w*0.5, h*0.5, _spBtnTxt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnSpells.DoClick = function()
        -- Demande au serveur d'ouvrir le panneau d'équilibrage des sorts
        local SBNet = TOOM_JJK and TOOM_JJK.SPELLS and TOOM_JJK.SPELLS.Balancing and TOOM_JJK.SPELLS.Balancing.Net
        if SBNet then
            netstream.Start(SBNet.OpenMenu)
        else
            -- Fallback : concommande directe
            RunConsoleCommand("verse_spell_balancing_open")
        end
    end

    -- ── Bouton fermer ──
    local btnClose = vgui.Create("DButton", topBar)
    btnClose:SetSize(R:X(32), R:Y(32))
    btnClose:SetPos(FW - R:X(44), math.floor((TOPBAR - R:Y(32)) * 0.5))
    btnClose:SetText("")
    btnClose._h = 0
    btnClose.Think = function(pnl) pnl._h = smooth(pnl._h, pnl:IsHovered() and 1 or 0, 14) end
    btnClose.Paint = function(pnl, w, h)
        local a = pnl._h
        _STB_COL_CLOSE_WARN.a = math.floor(180 * a)
        _STB_COL_CLOSE_X.a    = 200 + math.floor(55 * a)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(6)):Color(_STB_COL_CLOSE_WARN):Draw()
        draw.SimpleText("✕", fontBtn, w * 0.5, h * 0.5, _STB_COL_CLOSE_X, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnClose.DoClick = function() frame:Close() end

    -- ── Barre de recherche ──
    local SEARCHBAR_H = R:Y(36)
    local searchBar = vgui.Create("DPanel", frame)
    searchBar:SetPos(PAD, TOPBAR + R:Y(10))
    searchBar:SetSize(FW - PAD * 2, SEARCHBAR_H)
    searchBar.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(8)):Color(COL_BG2):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:Y(8)):Outline(1):Color(COL_BORDER):Draw()
    end

    local searchIcon = vgui.Create("DLabel", searchBar)
    searchIcon:SetPos(R:X(10), 0)
    searchIcon:SetSize(R:X(24), SEARCHBAR_H)
    searchIcon:SetText("🔍")
    searchIcon:SetFont(fontRowSm)
    searchIcon:SetContentAlignment(5)
    searchIcon:SetTextColor(COL_MUTED)

    local searchEntry = vgui.Create("DTextEntry", searchBar)
    searchEntry:SetPos(R:X(34), math.floor((SEARCHBAR_H - R:Y(22)) * 0.5))
    searchEntry:SetSize(FW - PAD * 2 - R:X(50), R:Y(22))
    searchEntry:SetFont(fontSearch)
    searchEntry:SetText("")
    searchEntry:SetPlaceholderText("Rechercher un node...")
    searchEntry:SetPlaceholderColor(COL_MUTED)
    searchEntry:SetTextColor(COL_TEXT)
    searchEntry.Paint = function(pnl, w, h)
        pnl:DrawTextEntryText(COL_TEXT, _STB_COL_SRCH_SEL, COL_TEXT)
    end

    -- ── Zone principale ──
    local BOTTOM_H = R:Y(52)
    local listY    = TOPBAR + SEARCHBAR_H + R:Y(20)
    local listH    = FH - listY - BOTTOM_H - R:Y(10)

    -- Colonnes
    local COL_W = {
        name    = math.floor((FW - PAD * 2) * 0.30),
        cat     = math.floor((FW - PAD * 2) * 0.14),
        defCost = math.floor((FW - PAD * 2) * 0.08),
        inpCost = math.floor((FW - PAD * 2) * 0.09),
        defMR   = math.floor((FW - PAD * 2) * 0.08),
        inpMR   = math.floor((FW - PAD * 2) * 0.09),
        actions = math.floor((FW - PAD * 2) * 0.22),
    }
    local ROW_H   = R:Y(38)
    local HDR_H   = R:Y(28)

    -- Header colonnes
    local colHeader = vgui.Create("DPanel", frame)
    colHeader:SetPos(PAD, listY)
    colHeader:SetSize(FW - PAD * 2, HDR_H)
    colHeader.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(6)):Color(COL_HEADER):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:Y(6)):Outline(1):Color(COL_BORDER):Draw()
    end

    local function drawHeaderLabel(parent, x, w, txt)
        local lbl = vgui.Create("DLabel", parent)
        lbl:SetPos(x + R:X(6), 0)
        lbl:SetSize(w - R:X(6), HDR_H)
        lbl:SetText(txt)
        lbl:SetFont(fontHeader)
        lbl:SetTextColor(COL_MUTED)
        lbl:SetContentAlignment(4) -- left center
    end

    local cx = 0
    drawHeaderLabel(colHeader, cx, COL_W.name,    "Node")          cx = cx + COL_W.name
    drawHeaderLabel(colHeader, cx, COL_W.cat,     "Catégorie")     cx = cx + COL_W.cat
    drawHeaderLabel(colHeader, cx, COL_W.defCost, "Coût défaut")   cx = cx + COL_W.defCost
    drawHeaderLabel(colHeader, cx, COL_W.inpCost, "Coût override") cx = cx + COL_W.inpCost
    drawHeaderLabel(colHeader, cx, COL_W.defMR,   "Rang max déf.") cx = cx + COL_W.defMR
    drawHeaderLabel(colHeader, cx, COL_W.inpMR,   "Rang max ovr.") cx = cx + COL_W.inpMR
    drawHeaderLabel(colHeader, cx, COL_W.actions, "Actions")

    -- ScrollPanel
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(PAD, listY + HDR_H + R:Y(2))
    scroll:SetSize(FW - PAD * 2, listH - HDR_H - R:Y(2))

    local sbar = scroll:GetVBar()
    sbar:SetWide(R:X(5))
    sbar.Paint        = function(_, w, h) RNDX().Rect(0, 0, w, h):Rad(R:Y(2)):Color(_STB_COL_SBAR_BG):Draw() end
    sbar.btnUp.Paint  = function() end
    sbar.btnDown.Paint= function() end
    sbar.btnGrip.Paint= function(_, w, h) RNDX().Rect(0, 0, w, h):Rad(R:Y(2)):Color(_STB_COL_SBAR_GRIP):Draw() end

    -- Container for rows
    local rowContainer = vgui.Create("DPanel", scroll)
    rowContainer:SetSize(FW - PAD * 2 - R:X(8), 1)
    rowContainer.Paint = function() end

    -- Table of row panels indexed by nodeId for later refresh
    local rowPanels = {}
    local allNodeData = buildNodeList()

    local function getInputVal(entry)
        local v = tonumber(entry:GetValue())
        return v and math.max(1, math.floor(v)) or nil
    end

    local function makeInputEntry(parent, x, y, w, h, initVal)
        local bg = vgui.Create("DPanel", parent)
        bg:SetPos(x, y)
        bg:SetSize(w, h)
        bg._focused = 0
        bg.Paint = function(pnl, pw, ph)
            _STB_COL_INP_OUT.a = math.floor(40 + 140 * pnl._focused)
            RNDX().Rect(0, 0, pw, ph):Rad(R:Y(5)):Color(_STB_COL_INP_BG):Draw()
            RNDX().Rect(0, 0, pw, ph):Rad(R:Y(5)):Outline(1):Color(_STB_COL_INP_OUT):Draw()
        end
        local entry = vgui.Create("DTextEntry", bg)
        entry:SetPos(R:X(4), math.floor((h - R:Y(18)) * 0.5))
        entry:SetSize(w - R:X(8), R:Y(18))
        entry:SetFont(fontInput)
        entry:SetText(tostring(initVal or ""))
        entry:SetNumeric(true)
        entry:SetTextColor(COL_TEXT)
        entry.Paint = function(pnl, pw, ph)
            pnl:DrawTextEntryText(COL_TEXT, _STB_COL_INP_SEL, COL_TEXT)
        end
        entry.OnGetFocus = function() bg._focused = 1 end
        entry.OnLoseFocus = function() bg._focused = 0 end
        return entry
    end

    local function makeButton(parent, x, y, w, h, txt, col, onClick)
        col = col or COL_ACCENT
        local btn = vgui.Create("DButton", parent)
        btn:SetPos(x, y)
        btn:SetSize(w, h)
        btn:SetText("")
        btn._h = 0
        local _abFill    = Color(col.r, col.g, col.b, 160)
        local _abOutline = Color(col.r, col.g, col.b, 120)
        local _abTxt     = Color(255, 255, 255, 220)
        btn.Think = function(pnl) pnl._h = smooth(pnl._h, pnl:IsHovered() and 1 or 0, 14) end
        btn.Paint = function(pnl, pw, ph)
            local hv = pnl._h
            local r = math.min(255, col.r + math.floor(25 * hv))
            local g = math.min(255, col.g + math.floor(10 * hv))
            local b = math.min(255, col.b + math.floor(25 * hv))
            _abFill.r = r; _abFill.g = g; _abFill.b = b; _abFill.a = math.floor(160 + 70 * hv)
            RNDX().Rect(0, 0, pw, ph):Rad(R:Y(5)):Color(_abFill):Draw()
            _abOutline.r = r; _abOutline.g = g; _abOutline.b = b; _abOutline.a = math.floor(120 + 100 * hv)
            RNDX().Rect(0, 0, pw, ph):Rad(R:Y(5)):Outline(1):Color(_abOutline):Draw()
            _abTxt.a = 220 + math.floor(35 * hv)
            draw.SimpleText(txt, fontBtn, pw * 0.5, ph * 0.5, _abTxt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = onClick
        return btn
    end

    -- Construit les lignes selon le filtre texte
    local function rebuildRows(filter)
        filter = (filter or ""):lower():Trim()

        -- Vide le container
        for _, child in ipairs(rowContainer:GetChildren()) do
            child:Remove()
        end
        rowPanels = {}

        local visibleNodes = {}
        for _, data in ipairs(allNodeData) do
            local label = (data.label or data.id):lower()
            local catLbl = (data.cat.label or data.cat.id or ""):lower()
            local subLbl = (data.sub.label or data.sub.id or ""):lower()
            if filter == "" or label:find(filter, 1, true) or catLbl:find(filter, 1, true) or subLbl:find(filter, 1, true) then
                visibleNodes[#visibleNodes + 1] = data
            end
        end

        local totalH = #visibleNodes * ROW_H
        rowContainer:SetSize(FW - PAD * 2 - R:X(8), math.max(totalH, R:Y(40)))

        local IBTN_H  = R:Y(26)
        local IBTN_W  = math.floor((COL_W.actions - R:X(8)) * 0.5) - R:X(3)
        local ROW_PAD = math.floor((ROW_H - IBTN_H) * 0.5)

        for i, data in ipairs(visibleNodes) do
            local ry = (i - 1) * ROW_H

            local row = vgui.Create("DPanel", rowContainer)
            row:SetPos(0, ry)
            row:SetSize(FW - PAD * 2 - R:X(8), ROW_H)

            local isEven = (i % 2 == 0)
            row.Paint = function(pnl, w, h)
                local ov  = BAL.Overrides[data.id]
                local bgC = isEven and COL_ROW_EVEN or COL_ROW_ODD
                RNDX().Rect(0, 0, w, h):Color(bgC):Draw()
                if ov then
                    -- Surlignage discret si override actif
                    RNDX().Rect(0, 0, R:X(3), h):Color(COL_MODIFIED):Draw()
                end
                -- Séparateur bas
                surface.SetDrawColor(255, 255, 255, 8)
                surface.DrawRect(0, h - 1, w, 1)
            end

            local cc = 0

            -- Node name
            local lblName = vgui.Create("DLabel", row)
            lblName:SetPos(cc + R:X(8), 0)
            lblName:SetSize(COL_W.name - R:X(8), ROW_H)
            lblName:SetText(data.label or data.id)
            lblName:SetFont(fontRow)
            lblName:SetTextColor(COL_TEXT)
            lblName:SetContentAlignment(4)
            cc = cc + COL_W.name

            -- Categorie
            local catCol = data.cat.color or Color(140, 140, 170)
            local lblCat = vgui.Create("DLabel", row)
            lblCat:SetPos(cc + R:X(4), 0)
            lblCat:SetSize(COL_W.cat - R:X(4), ROW_H)
            lblCat:SetText(data.cat.label or data.cat.id or "")
            lblCat:SetFont(fontRowSm)
            lblCat:SetTextColor(Color(catCol.r, catCol.g, catCol.b, 200))
            lblCat:SetContentAlignment(4)
            cc = cc + COL_W.cat

            -- Coût défaut
            local lblDefCost = vgui.Create("DLabel", row)
            lblDefCost:SetPos(cc + R:X(4), 0)
            lblDefCost:SetSize(COL_W.defCost - R:X(4), ROW_H)
            lblDefCost:SetText(tostring(data.rawCost))
            lblDefCost:SetFont(fontRow)
            lblDefCost:SetTextColor(COL_MUTED)
            lblDefCost:SetContentAlignment(5)
            cc = cc + COL_W.defCost

            -- Input coût
            local ov      = BAL.Overrides[data.id]
            local initCost = ov and ov.cost or data.rawCost
            local inpCost = makeInputEntry(row, cc + R:X(2), ROW_PAD, COL_W.inpCost - R:X(4), IBTN_H, initCost)
            cc = cc + COL_W.inpCost

            -- MaxRank défaut
            local lblDefMR = vgui.Create("DLabel", row)
            lblDefMR:SetPos(cc + R:X(4), 0)
            lblDefMR:SetSize(COL_W.defMR - R:X(4), ROW_H)
            lblDefMR:SetText(tostring(data.rawMR))
            lblDefMR:SetFont(fontRow)
            lblDefMR:SetTextColor(COL_MUTED)
            lblDefMR:SetContentAlignment(5)
            cc = cc + COL_W.defMR

            -- Input maxRank
            local initMR = ov and ov.maxRank or data.rawMR
            local inpMR  = makeInputEntry(row, cc + R:X(2), ROW_PAD, COL_W.inpMR - R:X(4), IBTN_H, initMR)
            cc = cc + COL_W.inpMR

            -- Boutons
            local bx = cc + R:X(4)
            makeButton(row, bx, ROW_PAD, IBTN_W, IBTN_H, "✔ Apply", COL_OK, function()
                local newCost = getInputVal(inpCost)
                local newMR   = getInputVal(inpMR)
                if not newCost and not newMR then
                    notification.AddLegacy("Valeurs invalides.", NOTIFY_ERROR, 3)
                    return
                end
                netstream.Start(NET.SetOverride, data.id, newCost or data.rawCost, newMR or data.rawMR)
            end)
            makeButton(row, bx + IBTN_W + R:X(6), ROW_PAD, IBTN_W, IBTN_H, "↺ Reset", COL_WARN, function()
                netstream.Start(NET.ResetNode, data.id)
                -- Remet les inputs aux valeurs d'origine
                inpCost:SetText(tostring(data.rawCost))
                inpMR:SetText(tostring(data.rawMR))
            end)

            rowPanels[data.id] = {
                row      = row,
                inpCost  = inpCost,
                inpMR    = inpMR,
                rawCost  = data.rawCost,
                rawMR    = data.rawMR,
            }
        end

        rowContainer:SizeToChildren(false, true)
    end

    rebuildRows("")

    searchEntry.OnChange = function(pnl)
        rebuildRows(pnl:GetValue())
    end

    -- ── Barre du bas ──
    local bottomBar = vgui.Create("DPanel", frame)
    bottomBar:SetPos(0, FH - BOTTOM_H)
    bottomBar:SetSize(FW, BOTTOM_H)
    bottomBar.Paint = function(_, w, h)
        surface.SetDrawColor(255, 255, 255, 16)
        surface.DrawRect(PAD, 0, w - PAD * 2, 1)
        RNDX().Rect(0, 1, w, h - 1):Rad(R:Y(10)):Color(COL_HEADER):Draw()
    end

    -- Compteur d'overrides actifs
    local lblCount = vgui.Create("DLabel", bottomBar)
    lblCount:SetPos(PAD + R:X(6), 0)
    lblCount:SetSize(R:X(300), BOTTOM_H)
    lblCount:SetFont(fontRowSm)
    lblCount:SetTextColor(COL_MUTED)
    lblCount:SetContentAlignment(4)
    lblCount.Think = function(pnl)
        local n = table.Count(BAL.Overrides)
        pnl:SetText(n > 0 and (tostring(n) .. " override(s) actif(s)") or "Aucun override actif")
        pnl:SetTextColor(n > 0 and COL_MODIFIED or COL_MUTED)
    end

    -- Bouton Tout réinitialiser
    local btnResetAll = makeButton(bottomBar,
        FW - PAD - R:X(200) - R:X(110) - R:X(10),
        math.floor((BOTTOM_H - R:Y(34)) * 0.5),
        R:X(200), R:Y(34),
        "⚠ Tout réinitialiser", COL_WARN,
        function()
            Derma_Query(
                "Supprimer TOUS les overrides du skill tree ?",
                "Confirmation",
                "Confirmer", function()
                    netstream.Start(NET.ResetAll)
                end,
                "Annuler", function() end
            )
        end
    )

    -- Bouton Fermer
    makeButton(bottomBar,
        FW - PAD - R:X(110),
        math.floor((BOTTOM_H - R:Y(34)) * 0.5),
        R:X(110), R:Y(34),
        "Fermer", Color(60, 65, 90),
        function() frame:Close() end
    )

    -- Refresh les inputs quand les overrides changent depuis le réseau
    function frame:RefreshOverrides()
        for nodeId, rp in pairs(rowPanels) do
            if IsValid(rp.inpCost) and IsValid(rp.inpMR) then
                local ov = BAL.Overrides[nodeId]
                rp.inpCost:SetText(tostring(ov and ov.cost    or rp.rawCost))
                rp.inpMR:SetText  (tostring(ov and ov.maxRank or rp.rawMR))
            end
        end
    end

    _frame = frame
end

-- ─── Netstream handlers ───────────────────────────────────────────────────────

-- Reçoit la synchronisation complète des overrides
netstream.Hook(NET.SyncAll, function(packed)
    BAL.Overrides = {}
    if istable(packed) then
        for nodeId, ov in pairs(packed) do
            if istable(ov) then
                BAL.Overrides[tostring(nodeId)] = {
                    cost    = tonumber(ov.cost),
                    maxRank = tonumber(ov.maxRank),
                }
            end
        end
    end
    ST:ApplyBalancingOverrides()
    -- Si le menu est ouvert, on rafraîchit
    if IsValid(_frame) and isfunction(_frame.RefreshOverrides) then
        _frame:RefreshOverrides()
    end
end)

-- Serveur signal "ouvre le menu"
netstream.Hook(NET.OpenMenu, function()
    openBalancingMenu()
end)

-- ─── Concommand client ────────────────────────────────────────────────────────

concommand.Add("verse_balancing_open", function()
    -- Demande au serveur d'ouvrir le menu (le serveur vérifie les droits puis renvoie NET.OpenMenu)
    netstream.Start(NET.OpenMenu)
end)

