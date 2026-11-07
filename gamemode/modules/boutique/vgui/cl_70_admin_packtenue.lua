-- vgui/cl_70_admin_packtenue.lua
-- Onglet admin "Pack Tenues" : création / modification / suppression de packs.
-- Export : _ui.buildPackTenueAdminTab(content, fw, fh)
--          _ui.onPackTenueSync(packs)   (hook appelé par cl_boutique.lua)
-- ─────────────────────────────────────────────────────────────────────────────

local BT   = VERSE.Boutique
local Font = VERSE.Fonts
local _ui  = BT._ui

-- ─── Couleurs (reprises de cl_admin.lua) ─────────────────────────────────────
local C = {
    bg      = Color(12, 10, 20),
    panel   = Color(22, 20, 32),
    panel2  = Color(30, 28, 42),
    border  = Color(255, 255, 255, 18),
    accent  = Color(171, 82, 255),
    green   = Color(78, 220, 120),
    red     = Color(240, 80, 80),
    text    = Color(220, 218, 230),
    muted   = Color(130, 125, 150),
    input   = Color(18, 16, 28),
    inputBd = Color(171, 82, 255, 120),
    row1    = Color(28, 26, 40, 200),
    row2    = Color(22, 20, 34, 200),
}

local function rnd(r, x, y, w, h, col)   RNDX.Draw(r, x, y, w, h, col) end
local function rndO(r, x, y, w, h, col, t) RNDX.DrawOutlined(r, x, y, w, h, col, t or 1) end

-- ─── Couleurs pré-allouées (Paint callbacks) ─────────────────────────────────
local _APA_COL_ENTRY_HL        = Color(171, 82,  255, 80)
local _APA_COL_SBAR_GRIP       = Color(171, 82,  255, 100)
local _APA_COL_ROW_SEL         = Color(50,  35,  75,  220)
local _APA_COL_ROW_HOV         = Color(38,  30,  55,  180)
local _APA_COL_BADGE_WARN      = Color(255, 200, 60,  255)
local _APA_COL_DEL_BG          = Color(180, 50,  50,  160)  -- .a muté

-- ─── État local du module ─────────────────────────────────────────────────────
local PTA = {
    editPack    = nil,    -- pack en cours d'édition (copie locale)
    editOutfits = {},     -- tableau des outfits en cours d'édition
    _rebuild    = nil,    -- fonction de rebuild de l'onglet
    content     = nil,    -- panel content de l'onglet
}

local function rebuildTab()
    if isfunction(PTA._rebuild) then PTA._rebuild() end
end

-- ─── Helpers UI ──────────────────────────────────────────────────────────────
local function makeEntry(parent, x, y, w, h, placeholder, numeric)
    local e = vgui.Create("DTextEntry", parent)
    e:SetPos(x, y)
    e:SetSize(w, h)
    e:SetFont(Font:GetNamed("Poppins", "Regular", 14))
    e:SetTextColor(C.text)
    e:SetCursorColor(color_white)
    e:SetHighlightColor(Color(171, 82, 255, 80))
    if numeric then e:SetNumeric(true) end
    e.Paint = function(s, ew, eh)
        rnd(5, 0, 0, ew, eh, C.input)
        rndO(5, 0, 0, ew, eh, s:HasFocus() and C.accent or C.inputBd)
        local val = s:GetValue() or ""
        if val == "" and not s:HasFocus() then
            draw.SimpleText(placeholder, Font:GetNamed("Poppins", "Regular", 13), 8, eh * 0.5, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return true
        end
        s:DrawTextEntryText(C.text, _APA_COL_ENTRY_HL, color_white)
        return true
    end
    return e
end

local function makeBtn(parent, x, y, w, h, txt, col, onClick)
    col = col or C.accent
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    local _btnCol  = Color(col.r, col.g, col.b, 190)  -- .a muté
    local _btnFont = Font:GetNamed("Poppins", "SemiBold", 14)
    btn.Paint = function(s, bw, bh)
        _btnCol.a = s:IsHovered() and 230 or 190
        rnd(6, 0, 0, bw, bh, _btnCol)
        draw.SimpleText(txt, _btnFont, bw * 0.5, bh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = onClick
    return btn
end

local function makeScroll(parent, x, y, w, h)
    local s = vgui.Create("DScrollPanel", parent)
    s:SetPos(x, y)
    s:SetSize(w, h)
    s.Paint = function() end
    local sb = s:GetVBar()
    sb:SetWide(4)
    sb.Paint = function() end
    sb.btnUp.Paint   = function() end
    sb.btnDown.Paint = function() end
    sb.btnGrip.Paint = function(_, bw, bh) rnd(3, 0, 0, bw, bh, _APA_COL_SBAR_GRIP) end
    return s
end

local function label(parent, x, y, w, h, txt, size, col, ax)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h)
    p.Paint = function(_, pw, ph)
        draw.SimpleText(txt, Font:GetNamed("Poppins", "Medium", size or 14),
            ax == TEXT_ALIGN_CENTER and pw*0.5 or 4, ph*0.5,
            col or C.text, ax or TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return p
end

-- ─── Initialisation d'un nouveau pack vide ───────────────────────────────────
local function newEmptyPack()
    return {
        id         = "",
        name       = "",
        price      = 0,
        icon       = "chest_h_img",
        chest_img  = "",
        sort_order = 0,
        gender     = "",
        outfits    = {},
    }
end

local function deepCopyPack(pack)
    local p = {
        id         = tostring(pack.id or ""),
        name       = tostring(pack.name or ""),
        price      = math.floor(tonumber(pack.price) or 0),
        icon       = tostring(pack.icon or "chest_h_img"),
        chest_img  = tostring(pack.chest_img or ""),
        sort_order = math.floor(tonumber(pack.sort_order) or 0),
        gender     = tostring(pack.gender or ""),
        outfits    = {},
    }
    for _, o in ipairs(pack.outfits or {}) do
        p.outfits[#p.outfits + 1] = {
            id     = tostring(o.id or ""),
            weight = math.max(1, math.floor(tonumber(o.weight) or 1)),
        }
    end
    return p
end

-- ─── Panneau liste des packs (gauche) ────────────────────────────────────────
local function buildPackList(parent, x, y, w, h)
    local bg = vgui.Create("DPanel", parent)
    bg:SetPos(x, y)
    bg:SetSize(w, h)
    bg.Paint = function(_, bw, bh)
        rnd(8, 0, 0, bw, bh, C.panel)
        rndO(8, 0, 0, bw, bh, C.border)
    end

    -- Titre
    label(bg, 0, 6, w, 22, "Packs de tenues", 15, C.accent, TEXT_ALIGN_CENTER)

    -- Bouton + Nouveau
    makeBtn(bg, 8, 34, w - 16, 28, "+ Nouveau pack", C.green, function()
        PTA.editPack = newEmptyPack()
        rebuildTab()
    end)

    -- Liste scrollable
    local scroll = makeScroll(bg, 4, 70, w - 8, h - 74)

    local packList = {}
    for _, p in pairs(BT.PackTenuePacks or {}) do
        packList[#packList + 1] = p
    end
    table.sort(packList, function(a, b)
        return (tonumber(a.sort_order) or 0) < (tonumber(b.sort_order) or 0)
    end)

    local ROW_H = 48
    local ROW_PAD = 4
    for i, pack in ipairs(packList) do
        local row = vgui.Create("DButton", scroll)
        row:SetPos(0, (i - 1) * (ROW_H + ROW_PAD))
        row:SetSize(w - 8, ROW_H)
        row:SetText("")
        local _pack = pack
        local _rowNameFont  = Font:GetNamed("Poppins", "SemiBold", 14)
        local _rowSubFont   = Font:GetNamed("Poppins", "Regular",  12)
        row.Paint = function(s, rw, rh)
            local sel     = PTA.editPack and PTA.editPack.id == _pack.id
            local hovered = s:IsHovered()
            local bg_col  = sel and _APA_COL_ROW_SEL or (hovered and _APA_COL_ROW_HOV or C.row1)
            rnd(6, 0, 0, rw, rh, bg_col)
            if sel then rndO(6, 0, 0, rw, rh, C.accent, 1) end
            draw.SimpleText(tostring(_pack.name or "?"),
                _rowNameFont,
                10, rh * 0.38, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(_pack.price or 0) .. " coins | " .. tostring(#(_pack.outfits or {})) .. " tenues",
                _rowSubFont,
                10, rh * 0.72, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            PTA.editPack = deepCopyPack(_pack)
            rebuildTab()
        end
    end

    if #packList == 0 then
        label(scroll, 0, 10, w - 8, 30, "Aucun pack défini", 13, C.muted, TEXT_ALIGN_CENTER)
    end

    return bg
end

-- ─── Panneau éditeur (droite) ─────────────────────────────────────────────────
local function buildEditor(parent, x, y, w, h)
    local bg = vgui.Create("DPanel", parent)
    bg:SetPos(x, y)
    bg:SetSize(w, h)
    bg.Paint = function(_, bw, bh)
        rnd(8, 0, 0, bw, bh, C.panel)
        rndO(8, 0, 0, bw, bh, C.border)
    end

    if not PTA.editPack then
        label(bg, 0, 0, w, h, "← Sélectionne un pack ou crée-en un nouveau", 14, C.muted, TEXT_ALIGN_CENTER)
        return bg
    end

    local ep  = PTA.editPack
    local PAD = 14
    local EH  = 30
    local GAP = 8
    local cy  = 10

    -- Titre éditeur
    local isNew = (ep.id == "")
    label(bg, PAD, cy, w - PAD * 2, 22, isNew and "Nouveau pack" or ("Modifier: " .. ep.name), 16, C.accent)
    cy = cy + 28

    -- Champs : ID
    label(bg, PAD, cy, 110, EH, "ID unique", 13, C.muted)
    local eID = makeEntry(bg, PAD + 114, cy, w - PAD * 2 - 114, EH, "pack_tenue_1")
    eID:SetValue(ep.id)
    cy = cy + EH + GAP

    -- Nom
    label(bg, PAD, cy, 110, EH, "Nom", 13, C.muted)
    local eName = makeEntry(bg, PAD + 114, cy, w - PAD * 2 - 114, EH, "Pack Tenue 1")
    eName:SetValue(ep.name)
    cy = cy + EH + GAP

    -- Prix
    label(bg, PAD, cy, 110, EH, "Prix (coins)", 13, C.muted)
    local ePrice = makeEntry(bg, PAD + 114, cy, 120, EH, "500", true)
    ePrice:SetValue(tostring(ep.price))
    cy = cy + EH + GAP

    -- Icône (alias matériau fallback)
    label(bg, PAD, cy, 110, EH, "Icône (alias)", 13, C.muted)
    local eIcon = makeEntry(bg, PAD + 114, cy, w - PAD * 2 - 114, EH, "chest_h_img")
    eIcon:SetValue(ep.icon)
    cy = cy + EH + GAP

    -- Image coffre personnalisée (chemin matériau ou URL)
    label(bg, PAD, cy, 110, EH, "Image coffre", 13, C.muted)
    local eChestImg = makeEntry(bg, PAD + 114, cy, w - PAD * 2 - 114, EH, "verse/boutique/mon_coffre  ou  https://...")
    eChestImg:SetValue(ep.chest_img or "")
    cy = cy + EH + 2

    -- Aide visuelle sous le champ
    local helpLbl = vgui.Create("DPanel", bg)
    helpLbl:SetPos(PAD + 114, cy)
    helpLbl:SetSize(w - PAD * 2 - 114, 14)
    helpLbl.Paint = function(_, _, lh)
        draw.SimpleText(
            "Chemin relatif materials/ (sans extension) ou URL https://",
            Font:GetNamed("Poppins", "Regular", 11),
            0, lh * 0.5, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    cy = cy + 16 + GAP

    -- Sort order
    label(bg, PAD, cy, 110, EH, "Ordre (sort)", 13, C.muted)
    local eSort = makeEntry(bg, PAD + 114, cy, 80, EH, "0", true)
    eSort:SetValue(tostring(ep.sort_order))
    cy = cy + EH + GAP

    -- Genre (icône sur la carte)
    label(bg, PAD, cy, 110, EH, "Genre", 13, C.muted)
    local eGender = vgui.Create("DComboBox", bg)
    eGender:SetPos(PAD + 114, cy)
    eGender:SetSize(130, EH)
    eGender:AddChoice("— aucun —", "")
    eGender:AddChoice("♂  Homme",  "male")
    eGender:AddChoice("♀  Femme",  "female")
    -- Sélection initiale
    local gv = tostring(ep.gender or "")
    if gv == "male"   then eGender:ChooseOptionID(2)
    elseif gv == "female" then eGender:ChooseOptionID(3)
    else eGender:ChooseOptionID(1) end
    cy = cy + EH + GAP + 4

    -- ── Section outfits ────────────────────────────────────────────────────────

    -- En-tête section + indicateur de total
    local totalPct = 0
    for _, o in ipairs(ep.outfits or {}) do
        totalPct = totalPct + math.max(1, math.floor(tonumber(o.weight) or 1))
    end

    -- Panel titre + badge total (mis à jour via _totalPanel.Paint)
    local titleRow = vgui.Create("DPanel", bg)
    titleRow:SetPos(PAD, cy)
    titleRow:SetSize(w - PAD * 2, 20)
    titleRow.Paint = function(_, tw, th)
        draw.SimpleText("Tenues dans ce pack",
            Font:GetNamed("Poppins", "SemiBold", 14),
            0, th * 0.5, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        -- Badge total à droite
        local tot = 0
        for _, o in ipairs(ep.outfits or {}) do
            tot = tot + math.max(1, math.floor(tonumber(o.weight) or 1))
        end
        local badgeCol = tot == 100 and C.green or (tot > 100 and C.red or _APA_COL_BADGE_WARN)
        local badgeTxt = "Total : " .. tostring(tot) .. " %"
        if tot == 100 then badgeTxt = badgeTxt .. "  ✓" end
        draw.SimpleText(badgeTxt,
            Font:GetNamed("Poppins", "SemiBold", 13),
            tw, th * 0.5, badgeCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    cy = cy + 24

    -- Légende colonnes
    local legendRow = vgui.Create("DPanel", bg)
    legendRow:SetPos(PAD, cy)
    legendRow:SetSize(w - PAD * 2, 16)
    legendRow.Paint = function(_, lw, lh)
        draw.SimpleText("Tenue",
            Font:GetNamed("Poppins", "Regular", 11),
            6, lh * 0.5, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Chance (%)",
            Font:GetNamed("Poppins", "Regular", 11),
            lw - 100, lh * 0.5, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    cy = cy + 18

    -- Liste des outfits
    local outfitListH = math.min(math.max(#ep.outfits, 1) * 36 + 4, 180)
    local scroll = makeScroll(bg, PAD, cy, w - PAD * 2, outfitListH)

    for i, o in ipairs(ep.outfits or {}) do
        local ROW_W = w - PAD * 2 - 8
        local outRow = vgui.Create("DPanel", scroll)
        outRow:SetPos(0, (i - 1) * 36)
        outRow:SetSize(ROW_W, 34)
        local _i = i
        local _o = o

        outRow.Paint = function(_, rw, rh)
            rnd(5, 0, 0, rw, rh, _i % 2 == 0 and C.row2 or C.row1)
            local outfitDef = (BT.OutfitItems or {})[_o.id]
            local dispName  = (outfitDef and outfitDef.name) or _o.id
            draw.SimpleText(dispName,
                Font:GetNamed("Poppins", "Regular", 13),
                6, rh * 0.5, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- Champ chance (%)
        -- Limite : 1–100, valeur stockée dans o.weight
        local chanceEntry = makeEntry(outRow, ROW_W - 100, 2, 52, 30, "50", true)
        chanceEntry:SetValue(tostring(math.max(1, math.min(100, math.floor(tonumber(o.weight) or 50)))))
        chanceEntry.OnValueChange = function(_, val)
            local v = math.max(1, math.min(100, math.floor(tonumber(val) or 1)))
            ep.outfits[_i].weight = v
        end
        -- Clampe à la sortie du focus
        chanceEntry.OnLoseFocus = function(s)
            local v = math.max(1, math.min(100, math.floor(tonumber(s:GetValue()) or 1)))
            ep.outfits[_i].weight = v
            s:SetValue(tostring(v))
        end

        -- Label "%"
        local pctLbl = vgui.Create("DPanel", outRow)
        pctLbl:SetPos(ROW_W - 46, 2)
        pctLbl:SetSize(14, 30)
        pctLbl.Paint = function(_, _, ph)
            draw.SimpleText("%",
                Font:GetNamed("Poppins", "SemiBold", 13),
                0, ph * 0.5, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- Bouton supprimer tenue
        local delO = vgui.Create("DButton", outRow)
        delO:SetPos(ROW_W - 40, 4)
        delO:SetSize(36, 26)
        delO:SetText("")
        local _delFont = Font:GetNamed("Poppins", "Bold", 13)
        delO.Paint = function(s, bw, bh)
            _APA_COL_DEL_BG.a = s:IsHovered() and 220 or 160
            rnd(5, 0, 0, bw, bh, _APA_COL_DEL_BG)
            draw.SimpleText("✕",
                _delFont,
                bw * 0.5, bh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        delO.DoClick = function()
            table.remove(ep.outfits, _i)
            rebuildTab()
        end
    end

    cy = cy + outfitListH + GAP

    -- Dropdown pour ajouter une tenue
    if BT.SyncOutfitItems then BT:SyncOutfitItems() end
    local outfitChoices = {}
    for id, def in pairs(BT.OutfitItems or {}) do
        outfitChoices[#outfitChoices + 1] = { label = def.name, value = id }
    end
    table.sort(outfitChoices, function(a, b) return a.label < b.label end)

    -- Tracking de la sélection via OnSelect (MantleComboBox n'a pas GetSelected)
    local selectedOutfitId = outfitChoices[1] and outfitChoices[1].value or ""

    local combo = vgui.Create("MantleComboBox", bg)
    combo:SetPos(PAD, cy)
    combo:SetSize(w - PAD * 2 - 90, EH)
    combo:SetFonts(Font:GetNamed("Poppins", "Regular", 13), Font:GetNamed("Poppins", "Regular", 13))
    for _, ch in ipairs(outfitChoices) do combo:AddChoice(ch.label, ch.value) end
    combo.OnSelect = function(_, index, lbl, data)
        selectedOutfitId = tostring(data or lbl or "")
    end

    makeBtn(bg, w - PAD - 84, cy, 84, EH, "+ Ajouter", C.accent, function()
        if not selectedOutfitId or selectedOutfitId == "" then return end
        ep.outfits[#ep.outfits + 1] = { id = selectedOutfitId, weight = 50 }
        rebuildTab()
    end)
    cy = cy + EH + GAP + 6

    -- ── Boutons Sauvegarder / Supprimer ───────────────────────────────────────
    local btnW = math.floor((w - PAD * 2 - GAP) * 0.5)
    makeBtn(bg, PAD, cy, btnW, 32, "💾 Sauvegarder", C.green, function()
        -- Lecture des valeurs des champs texte
        ep.id         = eID:GetValue():Trim()
        ep.name       = eName:GetValue():Trim()
        ep.price      = math.max(0, math.floor(tonumber(ePrice:GetValue()) or 0))
        ep.icon       = eIcon:GetValue():Trim()
        ep.chest_img  = eChestImg:GetValue():Trim()
        ep.sort_order = math.floor(tonumber(eSort:GetValue()) or 0)
        local _, gVal = eGender:GetSelected()
        ep.gender     = tostring(gVal or "")

        if ep.id == "" or ep.name == "" then
            local lp = LocalPlayer()
            if IsValid(lp) and lp.Notify then lp:Notify("L'ID et le nom sont obligatoires.", NOTIFY_ERROR, 4) end
            return
        end

        netstream.Start(BT.Net.Admin.SavePackTenue, {
            id         = ep.id,
            name       = ep.name,
            price      = ep.price,
            icon       = ep.icon,
            chest_img  = ep.chest_img,
            sort_order = ep.sort_order,
            gender     = ep.gender,
            outfits    = ep.outfits,
        })
    end)

    if not isNew then
        makeBtn(bg, PAD + btnW + GAP, cy, btnW, 32, "🗑 Supprimer", C.red, function()
            netstream.Start(BT.Net.Admin.DelPackTenue, ep.id)
            PTA.editPack = nil
            rebuildTab()
        end)
    end

    return bg
end

-- ─── Construction de l'onglet ─────────────────────────────────────────────────
local function buildPackTenueAdminTab(content, fw, fh)
    local PAD   = 8
    local LIST_W = 240
    local EDIT_W = fw - LIST_W - PAD * 3

    buildPackList(content, PAD, PAD, LIST_W, fh - PAD * 2)
    buildEditor(content, PAD * 2 + LIST_W, PAD, EDIT_W, fh - PAD * 2)

    -- Enregistrement du rebuild pour refresh interne
    PTA.content = content
end

-- ─── Exports ─────────────────────────────────────────────────────────────────
_ui.buildPackTenueAdminTab = function(content, fw, fh)
    -- Stocke rebuild pour les actions asynchrones (sync)
    PTA._rebuild = function()
        if not IsValid(content) then PTA._rebuild = nil; return end
        content:Clear()
        buildPackTenueAdminTab(content, fw, fh)
    end
    buildPackTenueAdminTab(content, fw, fh)
end

_ui.onPackTenueSync = function(packs)
    -- Appelé par cl_boutique.lua quand PackTenueSync arrive
    -- Met à jour BT.PackTenuePacks (déjà fait avant l'appel), rebuild si onglet ouvert
    if isfunction(PTA._rebuild) then PTA._rebuild() end
end
