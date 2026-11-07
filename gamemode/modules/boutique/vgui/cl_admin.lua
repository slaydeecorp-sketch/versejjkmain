local BT = VERSE.Boutique
local Font = VERSE.Fonts
local Mats = VERSE.Materials
local _ui = BT._ui
local C = {
    bg = Color(12, 10, 20),
    panel = Color(22, 20, 32),
    panel2 = Color(30, 28, 42),
    border = Color(255, 255, 255, 18),
    accent = Color(171, 82, 255),
    green = Color(78, 220, 120),
    red = Color(240, 80, 80),
    text = Color(220, 218, 230),
    muted = Color(130, 125, 150),
    input = Color(18, 16, 28),
    inputBd = Color(171, 82, 255, 120),
    tabSel = Color(171, 82, 255, 180),
    row1 = Color(28, 26, 40, 200),
    row2 = Color(22, 20, 34, 200),
}

local function rnd(r, x, y, w, h, col)
    RNDX.Draw(r, x, y, w, h, col)
end

local function rndO(r, x, y, w, h, col, t)
    RNDX.DrawOutlined(r, x, y, w, h, col, t or 1)
end

-- ─── Couleurs pré-allouées (Paint callbacks) ──────────────────────────────────
local _ADM_COL_ENTRY_HL        = Color(171, 82,  255, 80)
local _ADM_COL_SBAR_GRIP       = Color(171, 82,  255, 100)
local _ADM_COL_BTN_EDIT        = Color(80,  80,  150, 155)   -- .a muté
local _ADM_COL_BTN_COPY        = Color(60,  130, 180, 155)   -- .a muté
local _ADM_COL_BTN_DEL         = Color(180, 50,  50,  155)   -- .a muté
local _ADM_COL_BTN_STATS       = Color(171, 82,  255, 155)   -- .a muté
local _ADM_COL_BTN_INFO        = Color(89,  187, 255, 155)   -- .a muté
local _ADM_COL_ROW_SEL_PROD    = Color(50,  30,  80,  220)
local _ADM_COL_ROW_HOV_PLY     = Color(50,  40,  70,  220)
local _ADM_COL_ROW_SEL_CREAT   = Color(55,  35,  80,  255)
local _ADM_COL_FALLBACK_ACCENT = Color(171, 82,  255, 255)
local _ADM_COL_ROW_SEL_POOL    = Color(50,  30,  80,  220)
local _ADM_COL_POOL_PCT        = Color(120, 210, 120, 255)
local _ADM_COL_CREATOR_OWNER   = Color(180, 180, 200, 255)
local _ADM_COL_CREATOR_RATE_OK = Color(100, 210, 255, 255)
local _ADM_COL_CREATOR_COINS   = Color(255, 200, 60,  255)
local _ADM_COL_TAB_SEL_BG      = Color(40,  30,  60,  255)
local _ADM_COL_TAB_NRM_BG      = Color(20,  18,  30,  200)
local _ADM_COL_PERIOD_BG       = Color(40,  30,  60,  200)
local _ADM_COL_CLOSE_BG        = Color(180, 50,  50,  160)   -- .a muté
local _ADM_COL_STAT_BG         = Color(22,  18,  32,  220)
local _ADM_COL_STAT_PLAYERS    = Color(100, 210, 255, 255)
local _ADM_COL_STAT_ACTS       = Color(78,  254, 122, 255)
local _ADM_COL_STAT_ROLLS      = Color(171, 82,  255, 255)
local _ADM_COL_STAT_AMOUNT     = Color(255, 200, 60,  255)
local _ADM_COL_INV_M1_HOV      = Color(180, 80,  80,  230)
local _ADM_COL_INV_M1_NRM      = Color(130, 45,  45,  180)
local _ADM_COL_INV_DEL_HOV     = Color(210, 55,  55,  240)
local _ADM_COL_INV_DEL_NRM     = Color(165, 35,  35,  180)
local _ADM_COL_TX_POS          = Color(78,  220, 120, 255)
local _ADM_COL_TX_NEG          = Color(240, 80,  80,  255)
local _ADM_COL_SUBTAB_SEL      = Color(50,  35,  80,  240)
local _ADM_COL_SUBTAB_NRM      = Color(28,  26,  40,  200)
local _ADM_COL_RECENT_ROLL     = Color(171, 82,  255, 255)
local _ADM_COL_RECENT_BUY      = Color(100, 210, 255, 255)
local _ADM_COL_RECENT_AMT      = Color(255, 200, 60,  255)
local _ADM_COL_PROW_COINS      = Color(255, 200, 60,  255)
local _ADM_COL_PROW_LINKED     = Color(78,  254, 122, 255)

local function label(parent, x, y, w, h, txt, fnt, col, ax, ay)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h)
    p.Paint = function(_, pw, ph) draw.SimpleText(txt, fnt, ax == TEXT_ALIGN_CENTER and pw * 0.5 or (ax == TEXT_ALIGN_RIGHT and pw or 0), ay == TEXT_ALIGN_CENTER and ph * 0.5 or 0, col or C.text, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP) end
    return p
end

local function makeBtn(parent, x, y, w, h, txt, col, onClick)
    col = col or C.accent
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    local _btnCol  = Color(col.r, col.g, col.b, 190)  -- .a muté
    local _btnFont = Font:GetNamed("Poppins", "SemiBold", 15)
    btn.Paint = function(s, bw, bh)
        _btnCol.a = s:IsHovered() and 230 or 190
        rnd(6, 0, 0, bw, bh, _btnCol)
        draw.SimpleText(txt, _btnFont, bw * 0.5, bh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = onClick
    return btn
end

local function makeEntry(parent, x, y, w, h, placeholder, numeric)
    local e = vgui.Create("DTextEntry", parent)
    e:SetPos(x, y)
    e:SetSize(w, h)
    e:SetFont(Font:GetNamed("Poppins", "Regular", 15))
    e:SetTextColor(C.text)
    e:SetCursorColor(color_white)
    e:SetHighlightColor(Color(171, 82, 255, 80))
    if numeric then e:SetNumeric(true) end
    e.Paint = function(s, ew, eh)
        rnd(6, 0, 0, ew, eh, C.input)
        rndO(6, 0, 0, ew, eh, s:HasFocus() and C.accent or C.inputBd)
        local val = s:GetValue() or ""
        if val == "" and not s:HasFocus() then
            draw.SimpleText(placeholder, Font:GetNamed("Poppins", "Regular", 14), 8, eh * 0.5, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return true
        end

        s:DrawTextEntryText(C.text, _ADM_COL_ENTRY_HL, color_white)
        return true
    end
    return e
end

local function makeMantleCombo(parent, x, y, w, h, choices, defaultData)
    local combo = vgui.Create("MantleComboBox", parent)
    combo:SetPos(x, y)
    combo:SetSize(w, h)
    combo:SetFonts(Font:GetNamed("Poppins", "Regular", 15), Font:GetNamed("Poppins", "Regular", 15))
    for _, ch in ipairs(choices or {}) do
        combo:AddChoice(ch.label, ch.value)
    end

    if defaultData ~= nil then combo:SetSelectedByData(defaultData) end
    return combo
end

local function makeScroll(parent, x, y, w, h)
    local s = vgui.Create("DScrollPanel", parent)
    s:SetPos(x, y)
    s:SetSize(w, h)
    s.Paint = function() end
    local sb = s:GetVBar()
    sb:SetWide(4)
    sb.Paint = function() end
    sb.btnUp.Paint = function() end
    sb.btnDown.Paint = function() end
    sb.btnGrip.Paint = function(_, bw, bh) rnd(3, 0, 0, bw, bh, _ADM_COL_SBAR_GRIP) end
    return s
end

local ADM = {
    frame = nil,
    tab = "products",
    editProduct = nil,
    editRarity = nil,
    playerData = nil,
    playerSteam = "",
    rerollTab = "",
    rerollPool = {},
    editPoolEntry = nil,
    creators = {},
    editCreator = nil,
    creatorStats = {},
    creatorStatsReqAt = 0,
    statsCreator = nil,
    statsPeriod = "all",
    creatorDetails = nil,
    creatorDetailsReqAt = 0,
}

local function rebuildAdmin()
    if not IsValid(ADM.frame) then return end
    ADM.frame:InvalidateLayout(true)
    if isfunction(ADM._rebuild) then ADM._rebuild() end
end

local USEMODES = {
    {
        label = "Reroll Pouvoir Occulte",
        value = "open_occult_page"
    },
    {
        label = "Reroll Héritage",
        value = "open_heritage_page"
    },
    {
        label = "Ouvrir Pack",
        value = "open_pack"
    },
    {
        label = "Passer Premium",
        value = "consume_generic"
    },
    {
        label = "Reset Arbre de Talents",
        value = "reset_skilltree"
    },
}

local CATEGORIES = {
    {
        label = "Rerolls",
        value = "rerolls"
    },
    {
        label = "Packs",
        value = "packs"
    },
    {
        label = "Outfits",
        value = "outfits"
    },
}

local REWARD_TYPES = {
    {
        label = "Boutique Coins",
        value = "coins"
    },
    {
        label = "Money",
        value = "money"
    },
    {
        label = "Inventory Item",
        value = "item"
    },
    {
        label = "Skill Tree (Branche Exclusive)",
        value = "skilltree"
    },
    {
        label = "Rien (Aucune récompense)",
        value = "nothing"
    },
}

local function buildProductEditor(parent, x, y, w, h, product, onSave)
    local p = product or {}
    local BG = vgui.Create("DPanel", parent)
    BG:SetPos(x, y)
    BG:SetSize(w, h)
    BG.Paint = function(_, bw, bh)
        rnd(10, 0, 0, bw, bh, C.panel)
        rndO(10, 0, 0, bw, bh, C.border)
    end

    local LPAD, GY, GH, GW1, GW2 = 16, 10, 32, 148, w - 148 - 16 * 2 - 8
    local function row(yOff, lbl, widget)
        label(BG, LPAD, yOff, GW1, GH, lbl, Font:GetNamed("Poppins", "Medium", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        widget:SetParent(BG)
        widget:SetPos(LPAD + GW1 + 8, yOff)
        widget:SetSize(GW2, GH)
    end

    local cy = 12
    label(BG, LPAD, cy, w - LPAD * 2, 26, product and ("Modifier: " .. (p.name or "")) or "Nouveau produit", Font:GetNamed("Poppins", "Bold", 18), C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    cy = cy + 32
    local eID = makeEntry(BG, 0, 0, 1, 1, "id_unique")
    row(cy, "ID", eID)
    eID:SetValue(p.id or "")
    cy = cy + GH + GY
    local eName = makeEntry(BG, 0, 0, 1, 1, "Nom du produit")
    row(cy, "Nom", eName)
    eName:SetValue(p.name or "")
    cy = cy + GH + GY
    local rarChoices = {
        {
            label = "- Aucune -",
            value = ""
        }
    }

    for _, r in ipairs(BT.Rarities or {}) do
        rarChoices[#rarChoices + 1] = {
            label = r.name,
            value = r.id
        }
    end

    local dCat = makeMantleCombo(BG, 0, 0, 1, 1, CATEGORIES, p.category or "rerolls")
    row(cy, "Catégorie", dCat)
    cy = cy + GH + GY
    local dMode = makeMantleCombo(BG, 0, 0, 1, 1, USEMODES, p.use_mode or "consume_generic")
    row(cy, "Use Mode", dMode)
    cy = cy + GH + GY
    local ePrice = makeEntry(BG, 0, 0, 1, 1, "0", true)
    row(cy, "Prix (coins)", ePrice)
    ePrice:SetValue(tostring(p.price or 0))
    cy = cy + GH + GY
    local dRar = makeMantleCombo(BG, 0, 0, 1, 1, rarChoices, p.rarity or "")
    row(cy, "Rareté", dRar)
    cy = cy + GH + GY
    local eIcon = makeEntry(BG, 0, 0, 1, 1, "verse/boutique/...")
    row(cy, "Chemin icône", eIcon)
    eIcon:SetValue(p.icon or "")
    cy = cy + GH + GY
    local eBanner = makeEntry(BG, 0, 0, 1, 1, "verse/boutique/... (heritage/occulte)")
    row(cy, "Banner image", eBanner)
    eBanner:SetValue(p.banner_image or "")
    cy = cy + GH + GY
    local eIconW = makeEntry(BG, 0, 0, 1, 1, "256", true)
    row(cy, "Icon W", eIconW)
    eIconW:SetValue(tostring(p.icon_w or 256))
    cy = cy + GH + GY
    local eIconH = makeEntry(BG, 0, 0, 1, 1, "256", true)
    row(cy, "Icon H", eIconH)
    eIconH:SetValue(tostring(p.icon_h or 256))
    cy = cy + GH + GY
    label(BG, LPAD, cy, GW1, GH, "Accent R G B", Font:GetNamed("Poppins", "Medium", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    local cw3 = math.floor((GW2 - 8) / 3)
    local eAR = makeEntry(BG, LPAD + GW1 + 8, cy, cw3, GH, "R", true)
    eAR:SetValue(tostring(p.accent_r or 171))
    local eAG = makeEntry(BG, LPAD + GW1 + 8 + cw3 + 4, cy, cw3, GH, "G", true)
    eAG:SetValue(tostring(p.accent_g or 82))
    local eAB = makeEntry(BG, LPAD + GW1 + 8 + cw3 * 2 + 8, cy, cw3, GH, "B", true)
    eAB:SetValue(tostring(p.accent_b or 255))
    cy = cy + GH + GY
    local eWeight = makeEntry(BG, 0, 0, 1, 1, "1", true)
    row(cy, "Poids (weight)", eWeight)
    eWeight:SetValue(tostring(p.weight or 1))
    cy = cy + GH + GY
    local ePLL = makeEntry(BG, 0, 0, 1, 1, "0 = illimité", true)
    row(cy, "Limite locale", ePLL)
    ePLL:SetValue(tostring(p.purchase_limit_local or 0))
    cy = cy + GH + GY
    local ePLG = makeEntry(BG, 0, 0, 1, 1, "0 = illimité", true)
    row(cy, "Limite globale", ePLG)
    ePLG:SetValue(tostring(p.purchase_limit_global or 0))
    cy = cy + GH + GY
    local eSort = makeEntry(BG, 0, 0, 1, 1, "0", true)
    row(cy, "Ordre", eSort)
    eSort:SetValue(tostring(p.sort_order or 0))
    cy = cy + GH + GY
    local eUT = makeEntry(BG, 0, 0, 1, 1, "Utiliser")
    row(cy, "Texte utilisation", eUT)
    eUT:SetValue(p.use_text or "Utiliser")
    cy = cy + GH + GY
    local ePT = makeEntry(BG, 0, 0, 1, 1, "Acheter")
    row(cy, "Texte achat", ePT)
    ePT:SetValue(p.purchase_text or "Acheter")
    cy = cy + GH + GY
    local eFB = makeEntry(BG, 0, 0, 1, 1, "LABEL")
    row(cy, "Fallback label", eFB)
    eFB:SetValue(p.fallback_label or "")
    cy = cy + GH + GY
    local previewX = LPAD + GW1 + 8
    local previewW = math.min(GW2, 110)
    local prevPanel = vgui.Create("DPanel", BG)
    prevPanel:SetPos(previewX, cy)
    prevPanel:SetSize(previewW, 110)
    prevPanel.Paint = function(_, pw, ph)
        rnd(8, 0, 0, pw, ph, C.panel2)
        rndO(8, 0, 0, pw, ph, C.border)
        local iconPath = eIcon:GetValue() or ""
        if iconPath ~= "" then
            Mats:Draw(color_white, iconPath, 8, 8, pw - 16, ph - 16, "noclamp smooth")
        else
            draw.SimpleText("aperçu", Font:GetNamed("Poppins", "Regular", 13), pw * 0.5, ph * 0.5, C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    label(BG, LPAD, cy, GW1, 110, "Aperçu icône", Font:GetNamed("Poppins", "Medium", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    cy = cy + 118
    local saveBtnW = (w - LPAD * 2) * 0.5 - 4
    makeBtn(BG, LPAD, cy, saveBtnW, 36, "Enregistrer", C.green, function()
        local data = {
            id = eID:GetValue():Trim(),
            name = eName:GetValue():Trim(),
            category = dCat:GetSelectedData() or "rerolls",
            price = tonumber(ePrice:GetValue()) or 0,
            icon = eIcon:GetValue():Trim(),
            icon_w = tonumber(eIconW:GetValue()) or 256,
            icon_h = tonumber(eIconH:GetValue()) or 256,
            banner_image = eBanner:GetValue():Trim(),
            use_mode = dMode:GetSelectedData() or "consume_generic",
            use_text = eUT:GetValue():Trim(),
            purchase_text = ePT:GetValue():Trim(),
            fallback_label = eFB:GetValue():Trim(),
            rarity = dRar:GetSelectedData() or "",
            accent_r = tonumber(eAR:GetValue()) or 171,
            accent_g = tonumber(eAG:GetValue()) or 82,
            accent_b = tonumber(eAB:GetValue()) or 255,
            weight = tonumber(eWeight:GetValue()) or 1,
            purchase_limit_local = tonumber(ePLL:GetValue()) or 0,
            purchase_limit_global = tonumber(ePLG:GetValue()) or 0,
            sort_order = tonumber(eSort:GetValue()) or 0,
            enabled = 1,
        }

        if data.id == "" then
            LocalPlayer():Notify("ID requis.", NOTIFY_ERROR, 3)
            return
        end

        netstream.Start(BT.Net.Admin.SaveProduct, data)
        if onSave then onSave() end
    end)

    makeBtn(BG, LPAD + saveBtnW + 8, cy, saveBtnW, 36, "Annuler", C.muted, function() if onSave then onSave(true) end end)
    cy = cy + 44
    BG:SetTall(cy + 8)
    return BG
end

local function buildProductsTab(content, fw, fh)
    local listW = math.floor(fw * 0.38)
    local edW = fw - listW - 24
    local listBg = vgui.Create("DPanel", content)
    listBg:SetPos(8, 8)
    listBg:SetSize(listW, fh - 16)
    listBg.Paint = function(_, w, h)
        rnd(10, 0, 0, w, h, C.panel)
        rndO(10, 0, 0, w, h, C.border)
    end

    label(listBg, 14, 10, listW - 28, 26, "Produits", Font:GetNamed("Poppins", "Bold", 20), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    makeBtn(listBg, 12, 44, listW - 24, 34, "+ Nouveau produit", C.green, function()
        ADM.editProduct = {}
        rebuildAdmin()
    end)

    local scroll = makeScroll(listBg, 8, 86, listW - 16, fh - 104)
    local canvas = scroll:GetCanvas()
    canvas.Paint = function() end
    local sorted = {}
    for _, p in pairs(BT.Products or {}) do
        sorted[#sorted + 1] = p
    end

    table.sort(sorted, function(a, b) return (tonumber(a.sort_order) or 0) < (tonumber(b.sort_order) or 0) end)
    local rowH = 68
    local btnW = 46
    local btnH = rowH - 22
    local btnY = 11
    local btnG = 4
    local rw = listW - 16
    for i, p in ipairs(sorted) do
        local row = vgui.Create("DPanel", canvas)
        row:SetPos(0, (i - 1) * (rowH + 4))
        row:SetSize(rw, rowH)
        local _p = p
        local _prodNameFont = Font:GetNamed("Poppins", "SemiBold", 17)
        local _prodSubFont  = Font:GetNamed("Poppins", "Regular",  14)
        row.Paint = function(_, prw, prh)
            local bgC = ADM.editProduct and ADM.editProduct.id == _p.id and _ADM_COL_ROW_SEL_PROD or (i % 2 == 0 and C.row2 or C.row1)
            rnd(8, 0, 0, prw, prh, bgC)
            local ac = _p.accent or _ADM_COL_FALLBACK_ACCENT
            rnd(4, 0, prh * 0.18, 3, prh * 0.64, ac)
            draw.SimpleText(_p.name or _p.id, _prodNameFont, 12, prh * 0.35, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText((_p.category or "") .. " · " .. tostring(_p.price or 0) .. " coins", _prodSubFont, 12, prh * 0.72, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local _prodEditFont = Font:GetNamed("Poppins", "SemiBold", 14)
        local _prodCopyFont = Font:GetNamed("Poppins", "SemiBold", 13)
        local editBtn = vgui.Create("DButton", row)
        editBtn:SetPos(rw - btnW * 3 - btnG * 3, btnY)
        editBtn:SetSize(btnW, btnH)
        editBtn:SetText("")
        editBtn.Paint = function(s, ew, eh)
            _ADM_COL_BTN_EDIT.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, ew, eh, _ADM_COL_BTN_EDIT)
            draw.SimpleText("Edit", _prodEditFont, ew * 0.5, eh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        editBtn.DoClick = function()
            ADM.editProduct = table.Copy(_p)
            rebuildAdmin()
        end

        local copyBtn = vgui.Create("DButton", row)
        copyBtn:SetPos(rw - btnW * 2 - btnG * 2, btnY)
        copyBtn:SetSize(btnW, btnH)
        copyBtn:SetText("")
        copyBtn.Paint = function(s, ew, eh)
            _ADM_COL_BTN_COPY.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, ew, eh, _ADM_COL_BTN_COPY)
            draw.SimpleText("Copie", _prodCopyFont, ew * 0.5, eh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        copyBtn.DoClick = function()
            local copy = table.Copy(_p)
            copy.id = copy.id .. "_copy"
            copy.name = (copy.name or "") .. " (copie)"
            ADM.editProduct = copy
            rebuildAdmin()
        end

        local _prodDelFont = Font:GetNamed("Poppins", "SemiBold", 14)
        local delBtn = vgui.Create("DButton", row)
        delBtn:SetPos(rw - btnW - btnG, btnY)
        delBtn:SetSize(btnW, btnH)
        delBtn:SetText("")
        delBtn.Paint = function(s, ew, eh)
            _ADM_COL_BTN_DEL.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, ew, eh, _ADM_COL_BTN_DEL)
            draw.SimpleText("Del", _prodDelFont, ew * 0.5, eh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        delBtn.DoClick = function() Derma_Query("Supprimer " .. (_p.name or _p.id) .. " ?", "Confirmer", "Oui", function() netstream.Start(BT.Net.Admin.DelProduct, _p.id) end, "Non", function() end) end
    end

    canvas:SetTall(math.max(#sorted * (rowH + 4), scroll:GetTall()))
    if ADM.editProduct ~= nil then
        local edScroll = makeScroll(content, listW + 16, 8, edW, fh - 16)
        buildProductEditor(edScroll:GetCanvas(), 0, 0, edW - 8, 9999, ADM.editProduct, function()
            ADM.editProduct = nil
            rebuildAdmin()
        end)
    end
end

local function buildRaritiesTab(content, fw, fh)
    local listW = math.floor(fw * 0.45)
    local edW = fw - listW - 24
    local listBg = vgui.Create("DPanel", content)
    listBg:SetPos(8, 8)
    listBg:SetSize(listW, fh - 16)
    listBg.Paint = function(_, w, h)
        rnd(10, 0, 0, w, h, C.panel)
        rndO(10, 0, 0, w, h, C.border)
    end

    label(listBg, 14, 10, listW - 28, 26, "Raretés", Font:GetNamed("Poppins", "Bold", 20), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    makeBtn(listBg, 12, 44, listW - 24, 34, "+ Nouvelle rareté", C.green, function()
        ADM.editRarity = {}
        rebuildAdmin()
    end)

    local scroll = makeScroll(listBg, 8, 86, listW - 16, fh - 104)
    local canvas = scroll:GetCanvas()
    canvas.Paint = function() end
    local rowH = 58
    for i, r in ipairs(BT.Rarities or {}) do
        local row = vgui.Create("DPanel", canvas)
        row:SetPos(0, (i - 1) * (rowH + 4))
        row:SetSize(listW - 16, rowH)
        local _r = r
        local _rarCol    = Color(_r.color_r or 160, _r.color_g or 160, _r.color_b or 160)
        local _rarNameFt = Font:GetNamed("Poppins", "SemiBold", 17)
        local _rarSubFt  = Font:GetNamed("Poppins", "Regular",  13)
        row.Paint = function(_, prw, prh)
            rnd(8, 0, 0, prw, prh, i % 2 == 0 and C.row2 or C.row1)
            rnd(36, prh * 0.12, prh * 0.12, prh * 0.76, prh * 0.76, _rarCol)
            draw.SimpleText(_r.name or _r.id, _rarNameFt, prh + 8, prh * 0.38, _rarCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(_r.id, _rarSubFt, prh + 8, prh * 0.74, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local rbW = 54
        local rbH = rowH - 18
        local rbY = 9
        local _rarEditFont = Font:GetNamed("Poppins", "SemiBold", 14)
        local editBtn = vgui.Create("DButton", row)
        editBtn:SetPos(listW - 16 - rbW * 2 - 8, rbY)
        editBtn:SetSize(rbW, rbH)
        editBtn:SetText("")
        editBtn.Paint = function(s, ew, eh)
            _ADM_COL_BTN_EDIT.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, ew, eh, _ADM_COL_BTN_EDIT)
            draw.SimpleText("Edit", _rarEditFont, ew * 0.5, eh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        editBtn.DoClick = function()
            ADM.editRarity = table.Copy(_r)
            rebuildAdmin()
        end

        local _rarDelFont = Font:GetNamed("Poppins", "SemiBold", 14)
        local delBtn = vgui.Create("DButton", row)
        delBtn:SetPos(listW - 16 - rbW - 4, rbY)
        delBtn:SetSize(rbW, rbH)
        delBtn:SetText("")
        delBtn.Paint = function(s, ew, eh)
            _ADM_COL_BTN_DEL.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, ew, eh, _ADM_COL_BTN_DEL)
            draw.SimpleText("Del", _rarDelFont, ew * 0.5, eh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        delBtn.DoClick = function() Derma_Query("Supprimer la rareté " .. (_r.name or _r.id) .. " ?", "Confirmer", "Oui", function() netstream.Start(BT.Net.Admin.DelRarity, _r.id) end, "Non", function() end) end
    end

    canvas:SetTall(math.max(#(BT.Rarities or {}) * (rowH + 4), scroll:GetTall()))
    if ADM.editRarity ~= nil then
        local er = ADM.editRarity
        local edBg = vgui.Create("DPanel", content)
        edBg:SetPos(listW + 16, 8)
        edBg:SetSize(edW, 280)
        edBg.Paint = function(_, w, h)
            rnd(10, 0, 0, w, h, C.panel)
            rndO(10, 0, 0, w, h, C.border)
        end

        local LPAD, GY, GH, GW1, GW2 = 16, 10, 32, 125, edW - 125 - 16 * 2 - 8
        local function row(yOff, lbl, widget)
            label(edBg, LPAD, yOff, GW1, GH, lbl, Font:GetNamed("Poppins", "Medium", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            widget:SetParent(edBg)
            widget:SetPos(LPAD + GW1 + 8, yOff)
            widget:SetSize(GW2, GH)
        end

        local cy = 12
        label(edBg, LPAD, cy, edW - LPAD * 2, 26, er.id and ("Modifier: " .. er.id) or "Nouvelle rareté", Font:GetNamed("Poppins", "Bold", 18), C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        cy = cy + 32
        local eRID = makeEntry(edBg, 0, 0, 1, 1, "id_rarete")
        row(cy, "ID", eRID)
        eRID:SetValue(er.id or "")
        cy = cy + GH + GY
        local eRNm = makeEntry(edBg, 0, 0, 1, 1, "Nom")
        row(cy, "Nom", eRNm)
        eRNm:SetValue(er.name or "")
        cy = cy + GH + GY
        label(edBg, LPAD, cy, GW1, GH, "Couleur R G B", Font:GetNamed("Poppins", "Medium", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local cw3 = math.floor((GW2 - 8) / 3)
        local eRR = makeEntry(edBg, LPAD + GW1 + 8, cy, cw3, GH, "R", true)
        eRR:SetValue(tostring(er.color_r or 160))
        local eRG = makeEntry(edBg, LPAD + GW1 + 8 + cw3 + 4, cy, cw3, GH, "G", true)
        eRG:SetValue(tostring(er.color_g or 160))
        local eRB = makeEntry(edBg, LPAD + GW1 + 8 + cw3 * 2 + 8, cy, cw3, GH, "B", true)
        eRB:SetValue(tostring(er.color_b or 160))
        cy = cy + GH + GY
        local colorPrev = vgui.Create("DPanel", edBg)
        colorPrev:SetPos(LPAD + GW1 + 8, cy)
        colorPrev:SetSize(72, 32)
        colorPrev.Paint = function(_, pw, ph)
            local cr = math.Clamp(tonumber(eRR:GetValue()) or 160, 0, 255)
            local cg = math.Clamp(tonumber(eRG:GetValue()) or 160, 0, 255)
            local cb = math.Clamp(tonumber(eRB:GetValue()) or 160, 0, 255)
            rnd(6, 0, 0, pw, ph, Color(cr, cg, cb))
        end

        cy = cy + 40
        edBg:SetTall(cy + 52)
        local saveBtnW = (edW - LPAD * 2) * 0.5 - 4
        makeBtn(edBg, LPAD, cy, saveBtnW, 36, "Enregistrer", C.green, function()
            local data = {
                id = eRID:GetValue():Trim(),
                name = eRNm:GetValue():Trim(),
                color_r = math.Clamp(tonumber(eRR:GetValue()) or 160, 0, 255),
                color_g = math.Clamp(tonumber(eRG:GetValue()) or 160, 0, 255),
                color_b = math.Clamp(tonumber(eRB:GetValue()) or 160, 0, 255),
            }

            if data.id == "" then
                LocalPlayer():Notify("ID requis.", NOTIFY_ERROR, 3)
                return
            end

            netstream.Start(BT.Net.Admin.SaveRarity, data)
            ADM.editRarity = nil
            rebuildAdmin()
        end)

        makeBtn(edBg, LPAD + saveBtnW + 8, cy, saveBtnW, 36, "Annuler", C.muted, function()
            ADM.editRarity = nil
            rebuildAdmin()
        end)
    end
end

local function buildPlayersTab(content, fw, fh)
    local panelW = math.floor(fw * 0.38)
    local detW = fw - panelW - 24
    local searchBg = vgui.Create("DPanel", content)
    searchBg:SetPos(8, 8)
    searchBg:SetSize(panelW, fh - 16)
    searchBg.Paint = function(_, w, h)
        rnd(10, 0, 0, w, h, C.panel)
        rndO(10, 0, 0, w, h, C.border)
    end

    label(searchBg, 14, 10, panelW - 28, 26, "Recherche joueur", Font:GetNamed("Poppins", "Bold", 20), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    local eSearch = makeEntry(searchBg, 12, 44, panelW - 90, 36, "SteamID ou nom...")
    eSearch:SetValue(ADM.playerSteam or "")
    makeBtn(searchBg, panelW - 72, 44, 60, 36, "Chercher", C.accent, function()
        local raw = eSearch:GetValue():Trim()
        if raw == "" then return end
        local steamID = raw
        if not BT:IsValidSteamID(raw) then
            local search = string.lower(raw)
            for _, ply in ipairs(player.GetAll()) do
                local nick = string.lower(isfunction(ply.Nick) and ply:Nick() or "")
                if string.find(nick, search, 1, true) then
                    steamID = isfunction(ply.SteamID) and ply:SteamID() or ""
                    break
                end
            end
        end

        ADM.playerSteam = steamID
        netstream.Start(BT.Net.Admin.GetPlayer, steamID)
    end)

    label(searchBg, 14, 90, panelW - 28, 22, "Joueurs en ligne:", Font:GetNamed("Poppins", "Medium", 16), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    local pScroll = makeScroll(searchBg, 8, 116, panelW - 16, fh - 134)
    local pCanvas = pScroll:GetCanvas()
    pCanvas.Paint = function() end
    local rowH = 54
    local allPlys = player.GetAll()
    for i, ply in ipairs(allPlys) do
        if IsValid(ply) then
            local row = vgui.Create("DButton", pCanvas)
            row:SetPos(0, (i - 1) * (rowH + 2))
            row:SetSize(panelW - 16, rowH)
            row:SetText("")
            local _ply = ply
            local _plyNickFont = Font:GetNamed("Poppins", "SemiBold", 17)
            local _plySidFont  = Font:GetNamed("Poppins", "Regular",  14)
            row.Paint = function(s, rw, rh)
                rnd(8, 0, 0, rw, rh, s:IsHovered() and _ADM_COL_ROW_HOV_PLY or (i % 2 == 0 and C.row2 or C.row1))
                draw.SimpleText(isfunction(_ply.Nick) and _ply:Nick() or "?", _plyNickFont, 12, rh * 0.34, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(isfunction(_ply.SteamID) and _ply:SteamID() or "?", _plySidFont, 12, rh * 0.72, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            row.DoClick = function()
                local sid = isfunction(_ply.SteamID) and _ply:SteamID() or ""
                ADM.playerSteam = sid
                eSearch:SetValue(sid)
                netstream.Start(BT.Net.Admin.GetPlayer, sid)
            end
        end
    end

    pCanvas:SetTall(math.max(#allPlys * (rowH + 2), pScroll:GetTall()))
    local detBg = vgui.Create("DPanel", content)
    detBg:SetPos(panelW + 16, 8)
    detBg:SetSize(detW, fh - 16)
    detBg.Paint = function(_, w, h)
        rnd(10, 0, 0, w, h, C.panel)
        rndO(10, 0, 0, w, h, C.border)
    end

    local pd = ADM.playerData
    if not pd then
        label(detBg, 0, 0, detW, fh - 16, "Sélectionnez un joueur", Font:GetNamed("Poppins", "Medium", 20), C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    local cy = 14
    label(detBg, 14, cy, detW - 28, 26, (pd.nick ~= "" and pd.nick or "Hors-ligne") .. "  [" .. (pd.steamID or "?") .. "]", Font:GetNamed("Poppins", "Bold", 19), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    cy = cy + 32
    local coinsVal = tonumber((pd.account and pd.account.coins) or 0) or 0
    label(detBg, 14, cy, detW - 28, 24, "Coins: " .. tostring(coinsVal), Font:GetNamed("Poppins", "SemiBold", 18), Color(255, 207, 85), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    cy = cy + 32
    local coinsBtnW = 100
    local coinsEntW = detW - 28 - coinsBtnW * 2 - 10
    local eCoins = makeEntry(detBg, 14, cy, coinsEntW, 34, "montant...", true)
    makeBtn(detBg, 14 + coinsEntW + 4, cy, coinsBtnW, 34, "+ Donner", C.green, function()
        local amt = math.floor(tonumber(eCoins:GetValue()) or 0)
        if amt <= 0 then return end
        netstream.Start(BT.Net.Admin.ModBalance, pd.steamID, amt)
    end)

    makeBtn(detBg, 14 + coinsEntW + coinsBtnW + 8, cy, coinsBtnW, 34, "- Retirer", C.red, function()
        local amt = math.floor(tonumber(eCoins:GetValue()) or 0)
        if amt <= 0 then return end
        netstream.Start(BT.Net.Admin.ModBalance, pd.steamID, -amt)
    end)

    cy = cy + 42
    label(detBg, 14, cy, detW - 28, 22, "Inventaire:", Font:GetNamed("Poppins", "Bold", 17), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    cy = cy + 26
    local gfH = 34
    local gfIdW = math.floor((detW - 16) * 0.48)
    local gfQtyW = math.floor((detW - 16) * 0.17)
    local gfBtnW = detW - 16 - gfIdW - gfQtyW - 10
    local eGiveId = makeEntry(detBg, 8, cy, gfIdW, gfH, "product_id...", false)
    local eGiveQty = makeEntry(detBg, 8 + gfIdW + 4, cy, gfQtyW, gfH, "qté", true)
    eGiveQty:SetValue("1")
    makeBtn(detBg, 8 + gfIdW + gfQtyW + 8, cy, gfBtnW, gfH, "+ Donner", C.green, function()
        local iid = string.Trim(eGiveId:GetValue() or "")
        local qty = math.max(1, math.floor(tonumber(eGiveQty:GetValue()) or 1))
        if iid == "" then return end
        netstream.Start(BT.Net.Admin.GiveItem, pd.steamID, iid, qty)
    end)

    cy = cy + gfH + 6
    local invH = math.floor((fh - 16 - cy) * 0.40)
    local invScroll = makeScroll(detBg, 8, cy, detW - 16, invH)
    local invCanvas = invScroll:GetCanvas()
    invCanvas.Paint = function() end
    local iRowH = 38
    local iBtnW = 32
    local iBtnGap = 4
    local iRow = 0
    for itemId, amount in pairs(pd.items or {}) do
        local p = BT:GetProduct(itemId)
        local rw = detW - 16
        local rowPanel = vgui.Create("DPanel", invCanvas)
        rowPanel:SetPos(0, iRow * iRowH)
        rowPanel:SetSize(rw, iRowH - 2)
        local _itemId, _amount, _p, _iRow = itemId, amount, p, iRow
        rowPanel.Paint = function(_, prw, prh)
            rnd(6, 0, 0, prw, prh, _iRow % 2 == 0 and C.row1 or C.row2)
            local nameStr = (_p and _p.name) or _itemId
            local amtX = prw - iBtnW * 2 - iBtnGap * 2 - 12
            draw.SimpleText(nameStr, Font:GetNamed("Poppins", "Regular", 15), 10, prh * 0.5, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("x" .. tostring(_amount), Font:GetNamed("Poppins", "Bold", 15), amtX, prh * 0.5, C.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local bH = 24
        local bY = math.floor((iRowH - 2 - bH) / 2)
        local m1 = vgui.Create("DButton", rowPanel)
        m1:SetPos(rw - iBtnW * 2 - iBtnGap * 2, bY)
        m1:SetSize(iBtnW, bH)
        m1:SetText("")
        m1:SetCursor("hand")
        local _m1Font  = Font:GetNamed("Poppins", "Bold", 13)
        m1.Paint = function(s, w, h)
            rnd(4, 0, 0, w, h, s:IsHovered() and _ADM_COL_INV_M1_HOV or _ADM_COL_INV_M1_NRM)
            draw.SimpleText("-1", _m1Font, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        m1.DoClick = function() netstream.Start(BT.Net.Admin.RemoveItem, pd.steamID, _itemId, 1) end
        local del = vgui.Create("DButton", rowPanel)
        del:SetPos(rw - iBtnW - iBtnGap, bY)
        del:SetSize(iBtnW, bH)
        del:SetText("")
        del:SetCursor("hand")
        local _delFont = Font:GetNamed("Poppins", "Bold", 15)
        del.Paint = function(s, w, h)
            rnd(4, 0, 0, w, h, s:IsHovered() and _ADM_COL_INV_DEL_HOV or _ADM_COL_INV_DEL_NRM)
            draw.SimpleText("×", _delFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        del.DoClick = function() netstream.Start(BT.Net.Admin.RemoveItem, pd.steamID, _itemId, _amount) end
        iRow = iRow + 1
    end

    invCanvas:SetTall(math.max(iRow * iRowH, invScroll:GetTall()))
    cy = cy + invH + 10
    label(detBg, 14, cy, detW - 28, 22, "Historique:", Font:GetNamed("Poppins", "Bold", 17), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    cy = cy + 26
    local txH = fh - 16 - cy - 8
    local txScroll = makeScroll(detBg, 8, cy, detW - 16, txH)
    local txCanvas = txScroll:GetCanvas()
    txCanvas.Paint = function() end
    local TX_COLORS = {
        purchase = Color(78, 220, 120),
        coins_add = Color(255, 207, 85),
        roll_occult = Color(98, 176, 255),
        roll_heritage = Color(255, 76, 76),
        use_item = Color(171, 82, 255)
    }

    local txRowH = 42
    for i, tx in ipairs(pd.transactions or {}) do
        local tRow = vgui.Create("DPanel", txCanvas)
        tRow:SetPos(0, (i - 1) * txRowH)
        tRow:SetSize(detW - 16, txRowH - 2)
        local _tx = tx
        tRow.Paint = function(_, rw, rh)
            rnd(6, 0, 0, rw, rh, i % 2 == 0 and C.row2 or C.row1)
            local tc = TX_COLORS[_tx.tx_type] or C.muted
            rnd(3, 0, rh * 0.12, 4, rh * 0.76, tc)
            local nm = tostring((_tx.payload and _tx.payload.name) or _tx.item_id or "-")
            draw.SimpleText(string.upper(_tx.tx_type or "?"), Font:GetNamed("Poppins", "Bold", 14), 14, rh * 0.3, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(nm, Font:GetNamed("Poppins", "Regular", 15), 14, rh * 0.72, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if (_tx.coins_delta or 0) ~= 0 then
                local sign = _tx.coins_delta > 0 and "+" or ""
                draw.SimpleText(sign .. tostring(_tx.coins_delta), Font:GetNamed("Poppins", "Bold", 15), rw - 12, rh * 0.5, _tx.coins_delta > 0 and _ADM_COL_TX_POS or _ADM_COL_TX_NEG, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
    end

    txCanvas:SetTall(math.max(#(pd.transactions or {}) * txRowH, txScroll:GetTall()))
end


local function buildCreatorsTab(content, fw, fh)
    local listW = math.floor(fw * 0.48)
    local edW = fw - listW - 24
    local LPAD, GY, GH = 16, 8, 32
    if (SysTime() - (ADM.creatorStatsReqAt or 0)) > 2 then
        ADM.creatorStatsReqAt = SysTime()
        netstream.Start(BT.Net.Admin.GetCreatorStats)
    end

    local listBg = vgui.Create("DPanel", content)
    listBg:SetPos(8, 8)
    listBg:SetSize(listW, fh - 16)
    listBg.Paint = function(_, w, h)
        rnd(10, 0, 0, w, h, C.panel)
        rndO(10, 0, 0, w, h, C.border)
    end

    label(listBg, LPAD, 10, listW - LPAD * 2, 26, "Créateurs", Font:GetNamed("Poppins", "Bold", 20), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    makeBtn(listBg, 12, 44, (listW - 28) * 0.5, 34, "+ New Creator", C.green, function()
        ADM.editCreator = {
            id = 0,
            code = "",
            owner_name = "",
            steamid = "",
            payout_rate = 0,
            buyer_discount = 0,
            enabled = true,
            notes = ""
        }

        rebuildAdmin()
    end)

    makeBtn(listBg, 12 + (listW - 28) * 0.5 + 4, 44, (listW - 28) * 0.5, 34, "Refresh stats", C.accent, function()
        ADM.creatorStatsReqAt = 0
        netstream.Start(BT.Net.Admin.GetCreatorStats)
    end)

    local scroll = makeScroll(listBg, 8, 86, listW - 16, fh - 104)
    local canvas = scroll:GetCanvas()
    canvas.Paint = function() end
    local rowH = 96
    local sorted = {}
    for _, entry in pairs(ADM.creators or {}) do
        sorted[#sorted + 1] = entry
    end

    table.sort(sorted, function(a, b) return (a.id or 0) < (b.id or 0) end)
    for i, entry in ipairs(sorted) do
        local _e = entry
        local stats = ADM.creatorStats and ADM.creatorStats[_e.code] or nil
        local row = vgui.Create("DPanel", canvas)
        row:SetPos(0, (i - 1) * (rowH + 4))
        row:SetSize(listW - 16, rowH)
        local _crCodeFont  = Font:GetNamed("Poppins", "Bold",    17)
        local _crOwnerFont = Font:GetNamed("Poppins", "Medium",  12)
        local _crRateFont  = Font:GetNamed("Poppins", "Medium",  12)
        local _crStatFont  = Font:GetNamed("Poppins", "SemiBold", 13)
        local _crStatSubFt = Font:GetNamed("Poppins", "Regular",  11)
        local _crNoneFont  = Font:GetNamed("Poppins", "Regular",  14)
        row.Paint = function(_, rw, rh)
            local isSel = ADM.editCreator and ADM.editCreator.id == _e.id
            rnd(8, 0, 0, rw, rh, isSel and _ADM_COL_ROW_SEL_CREAT or (i % 2 == 0 and C.row2 or C.row1))
            if isSel then rndO(8, 0, 0, rw, rh, C.accent, 1) end
            draw.SimpleText(_e.code, _crCodeFont, 12, 10, _e.enabled and color_white or C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local owner = _e.owner_name ~= "" and _e.owner_name or "(anonyme)"
            draw.SimpleText(owner, _crOwnerFont, 12, 32, _ADM_COL_CREATOR_OWNER, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local rateCol = (_e.payout_rate or 0) > 0 and _ADM_COL_CREATOR_RATE_OK or C.muted
            draw.SimpleText("Rate: " .. tostring(_e.payout_rate or 0) .. "%", _crRateFont, 12, 50, rateCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local statsX = rw - 180
            if stats then
                draw.SimpleText(tostring(stats.unique_players or 0) .. " joueurs", _crStatFont, statsX, 8, _ADM_COL_CREATOR_RATE_OK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(tostring(stats.total_amount or 0) .. " coins", _crStatFont, statsX, 26, _ADM_COL_CREATOR_COINS, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(tostring(stats.rolls_count or 0) .. " rolls · " .. tostring(stats.purchases_count or 0) .. " achats", _crStatSubFt, statsX, 44, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                draw.SimpleText("-", _crNoneFont, statsX, 20, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        row.DoClick = function()
            ADM.editCreator = table.Copy(_e)
            rebuildAdmin()
        end

        local rbW, rbH = 42, 26
        local rbY = rowH - rbH - 8
        local rbGap = 4
        local delBtn = vgui.Create("DButton", row)
        delBtn:SetPos(listW - 16 - rbW - 4, rbY)
        delBtn:SetSize(rbW, rbH)
        delBtn:SetText("")
        local _crBtnFont = Font:GetNamed("Poppins", "SemiBold", 13)
        delBtn.Paint = function(s, bw, bh)
            _ADM_COL_BTN_DEL.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, bw, bh, _ADM_COL_BTN_DEL)
            draw.SimpleText("Del", _crBtnFont, bw * 0.5, bh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        delBtn.DoClick = function() Derma_Query("Supprimer le créateur " .. _e.code .. " ?", "Confirmer", "Oui", function() netstream.Start(BT.Net.Admin.DelCreator, _e.id) end, "Non", function() end) end
        local editBtn = vgui.Create("DButton", row)
        editBtn:SetPos(listW - 16 - rbW * 2 - rbGap - 4, rbY)
        editBtn:SetSize(rbW, rbH)
        editBtn:SetText("")
        editBtn.Paint = function(s, bw, bh)
            _ADM_COL_BTN_INFO.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, bw, bh, _ADM_COL_BTN_INFO)
            draw.SimpleText("Edit", _crBtnFont, bw * 0.5, bh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        editBtn.DoClick = function()
            ADM.editCreator = table.Copy(_e)
            ADM.statsCreator = nil
            rebuildAdmin()
        end

        local statsBtn = vgui.Create("DButton", row)
        statsBtn:SetPos(listW - 16 - rbW * 3 - rbGap * 2 - 4, rbY)
        statsBtn:SetSize(rbW, rbH)
        statsBtn:SetText("")
        statsBtn.Paint = function(s, bw, bh)
            _ADM_COL_BTN_STATS.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, bw, bh, _ADM_COL_BTN_STATS)
            draw.SimpleText("Stats", _crBtnFont, bw * 0.5, bh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        statsBtn.DoClick = function()
            ADM.statsCreator = _e.code
            ADM.editCreator = nil
            ADM.creatorDetails = nil
            ADM.creatorDetailsReqAt = SysTime()
            netstream.Start(BT.Net.Admin.GetCreatorDetails, _e.code, ADM.statsPeriod or "all")
            rebuildAdmin()
        end
    end

    canvas:SetTall(math.max(#sorted * (rowH + 4), scroll:GetTall()))
    if ADM.statsCreator then
        local code = ADM.statsCreator
        local panel = vgui.Create("DPanel", content)
        panel:SetPos(listW + 16, 8)
        panel:SetSize(edW, fh - 16)
        panel.Paint = function(_, w, h)
            rnd(10, 0, 0, w, h, C.panel)
            rndO(10, 0, 0, w, h, C.border)
        end

        local cy = 12
        label(panel, LPAD, cy, edW - LPAD * 2, 26, "Stats: " .. code, Font:GetNamed("Poppins", "Bold", 20), C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        makeBtn(panel, edW - LPAD - 70, cy, 70, 24, "Close", C.muted, function()
            ADM.statsCreator = nil
            ADM.creatorDetails = nil
            rebuildAdmin()
        end)

        cy = cy + 36
        local periods = {
            {
                id = "all",
                label = "All time"
            },
            {
                id = "month",
                label = "Month"
            },
            {
                id = "week",
                label = "Week"
            },
            {
                id = "day",
                label = "Day"
            },
        }

        local pbW = 88
        for i, pd in ipairs(periods) do
            local _pd = pd
            local sel = ADM.statsPeriod == _pd.id
            local pbtn = vgui.Create("DButton", panel)
            pbtn:SetPos(LPAD + (i - 1) * (pbW + 6), cy)
            pbtn:SetSize(pbW, 28)
            pbtn:SetText("")
            local _pbtnFont = Font:GetNamed("Poppins", sel and "Bold" or "Medium", 13)
            pbtn.Paint = function(s, bw, bh)
                rnd(6, 0, 0, bw, bh, sel and C.accent or _ADM_COL_PERIOD_BG)
                if not sel then rndO(6, 0, 0, bw, bh, C.border) end
                draw.SimpleText(_pd.label, _pbtnFont, bw * 0.5, bh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            pbtn.DoClick = function()
                ADM.statsPeriod = _pd.id
                ADM.creatorDetails = nil
                netstream.Start(BT.Net.Admin.GetCreatorDetails, code, _pd.id)
                rebuildAdmin()
            end
        end

        makeBtn(panel, edW - LPAD - 150, cy, 150, 28, "Export CSV", C.green, function() netstream.Start(BT.Net.Admin.ExportCreatorCSV, code, ADM.statsPeriod or "all") end)
        cy = cy + 40
        local details = ADM.creatorDetails
        if not details or details.code ~= code then
            label(panel, LPAD, cy, edW - LPAD * 2, 40, "Chargement...", Font:GetNamed("Poppins", "Regular", 14), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return
        end

        local totals = details.totals or {}
        local statBg = vgui.Create("DPanel", panel)
        statBg:SetPos(LPAD, cy)
        statBg:SetSize(edW - LPAD * 2, 84)
        local _statLblFont = Font:GetNamed("Poppins", "Medium", 12)
        local _statValFont = Font:GetNamed("Poppins", "Bold",   24)
        local _statLabels = {
            { lbl = "Joueurs",     valFn = function() return tostring(totals.unique_players or 0) end, col = _ADM_COL_STAT_PLAYERS },
            { lbl = "Activations", valFn = function() return tostring(totals.links         or 0) end, col = _ADM_COL_STAT_ACTS    },
            { lbl = "Rolls",       valFn = function() return tostring(totals.rolls          or 0) end, col = _ADM_COL_STAT_ROLLS   },
            { lbl = "Achats",      valFn = function() return tostring(totals.purchases      or 0) end, col = _ADM_COL_STAT_PLAYERS },
            { lbl = "Coins",       valFn = function() return tostring(totals.amount         or 0) end, col = _ADM_COL_STAT_AMOUNT  },
            { lbl = "Événements",  valFn = function() return tostring(totals.events         or 0) end, col = color_white           },
        }
        statBg.Paint = function(_, w, h)
            rnd(8, 0, 0, w, h, _ADM_COL_STAT_BG)
            rndO(8, 0, 0, w, h, C.border)
            local colW = w / #_statLabels
            for i, e in ipairs(_statLabels) do
                local cx = (i - 1) * colW + colW * 0.5
                draw.SimpleText(e.lbl,      _statLblFont, cx, 14, C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                draw.SimpleText(e.valFn(),  _statValFont, cx, 32, e.col,   TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        end

        cy = cy + 94
        local colsY = cy
        local colW = (edW - LPAD * 3) * 0.5
        local colH = fh - colsY - 16
        local playersBg = vgui.Create("DPanel", panel)
        playersBg:SetPos(LPAD, colsY)
        playersBg:SetSize(colW, colH)
        local _topPlyrFont = Font:GetNamed("Poppins", "Bold", 13)
        playersBg.Paint = function(_, w, h)
            rnd(8, 0, 0, w, h, _ADM_COL_STAT_BG)
            rndO(8, 0, 0, w, h, C.border)
            draw.SimpleText("Top joueurs (par coins)", _topPlyrFont, 10, 8, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local pScroll = makeScroll(playersBg, 6, 28, colW - 12, colH - 36)
        local pCanvas = pScroll:GetCanvas()
        pCanvas.Paint = function() end
        local prowH = 44
        local players = details.players or {}
        for i, pl in ipairs(players) do
            local _pl = pl
            local prow = vgui.Create("DPanel", pCanvas)
            prow:SetPos(0, (i - 1) * (prowH + 3))
            prow:SetSize(colW - 12, prowH)
            local _prowSidFont  = Font:GetNamed("Poppins", "SemiBold", 12)
            local _prowCoFont   = Font:GetNamed("Poppins", "Medium",   11)
            local _prowLinkFont = Font:GetNamed("Poppins", "SemiBold", 10)
            local _prowSubFont  = Font:GetNamed("Poppins", "Regular",  11)
            local _prowDateFont = Font:GetNamed("Poppins", "Regular",  10)
            prow.Paint = function(_, w, h)
                rnd(6, 0, 0, w, h, i % 2 == 0 and C.row2 or C.row1)
                draw.SimpleText(_pl.steamid, _prowSidFont, 8, 6, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("coins: " .. _pl.amount, _prowCoFont, 8, 22, _ADM_COL_PROW_COINS, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                if _pl.linked then
                    draw.SimpleText("● lié", _prowLinkFont, w - 8, 6, _ADM_COL_PROW_LINKED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                    local rightLine = tostring(_pl.rolls) .. " rolls · " .. tostring(_pl.purchases) .. " achats"
                    if _pl.link_bonus and _pl.link_bonus > 0 then
                        rightLine = rightLine .. " · bonus " .. _pl.link_bonus
                    end
                    draw.SimpleText(rightLine, _prowSubFont, w - 8, 22, C.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                else
                    draw.SimpleText(tostring(_pl.rolls) .. " rolls · " .. tostring(_pl.purchases) .. " achats", _prowSubFont, w - 8, 22, C.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                    local lastStr = _pl.last_activity and _pl.last_activity > 0 and os.date("%Y-%m-%d %H:%M", _pl.last_activity) or "-"
                    draw.SimpleText(lastStr, _prowDateFont, w - 8, 6, C.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                end
            end
        end

        pCanvas:SetTall(math.max(#players * (prowH + 3), pScroll:GetTall()))
        local recentBg = vgui.Create("DPanel", panel)
        recentBg:SetPos(LPAD * 2 + colW, colsY)
        recentBg:SetSize(colW, colH)
        local _recentHdrFont = Font:GetNamed("Poppins", "Bold", 13)
        recentBg.Paint = function(_, w, h)
            rnd(8, 0, 0, w, h, _ADM_COL_STAT_BG)
            rndO(8, 0, 0, w, h, C.border)
            draw.SimpleText("Événements récents (50)", _recentHdrFont, 10, 8, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local rScroll = makeScroll(recentBg, 6, 28, colW - 12, colH - 36)
        local rCanvas = rScroll:GetCanvas()
        rCanvas.Paint = function() end
        local rrowH = 42
        local recent = details.recent or {}
        for i, ev in ipairs(recent) do
            local _ev = ev
            local rrow = vgui.Create("DPanel", rCanvas)
            rrow:SetPos(0, (i - 1) * (rrowH + 2))
            rrow:SetSize(colW - 12, rrowH)
            local _rrowTypeFont = Font:GetNamed("Poppins", "Bold",    11)
            local _rrowProdFont = Font:GetNamed("Poppins", "Regular",  10)
            local _rrowSidFont  = Font:GetNamed("Poppins", "Regular",  9)
            local _rrowAmtFont  = Font:GetNamed("Poppins", "SemiBold", 12)
            local _rrowDateFont = Font:GetNamed("Poppins", "Regular",  10)
            rrow.Paint = function(_, w, h)
                rnd(6, 0, 0, w, h, i % 2 == 0 and C.row2 or C.row1)
                local typeCol = _ev.event_type == "roll" and _ADM_COL_RECENT_ROLL or _ADM_COL_RECENT_BUY
                draw.SimpleText(string.upper(_ev.event_type), _rrowTypeFont, 8, 6, typeCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(_ev.product_id, _rrowProdFont, 8, 20, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(_ev.steamid, _rrowSidFont, 8, 30, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(_ev.amount .. "c", _rrowAmtFont, w - 8, 6, _ADM_COL_RECENT_AMT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                local atStr = _ev.at > 0 and os.date("%m-%d %H:%M", _ev.at) or ""
                draw.SimpleText(atStr, _rrowDateFont, w - 8, 24, C.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end
        end

        rCanvas:SetTall(math.max(#recent * (rrowH + 2), rScroll:GetTall()))
        return
    end

    if not ADM.editCreator then
        local edBg = vgui.Create("DPanel", content)
        edBg:SetPos(listW + 16, 8)
        edBg:SetSize(edW, 80)
        edBg.Paint = function(_, w, h)
            rnd(10, 0, 0, w, h, C.panel)
            rndO(10, 0, 0, w, h, C.border)
        end

        label(edBg, LPAD, 0, edW - LPAD * 2, 80, "Sélectionnez un créateur ou cliquez + New Creator", Font:GetNamed("Poppins", "Regular", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        return
    end

    local ec = ADM.editCreator
    local edBg = vgui.Create("DPanel", content)
    edBg:SetPos(listW + 16, 8)
    edBg:SetSize(edW, GH * 6 + GY * 6 + 220)
    edBg.Paint = function(_, w, h)
        rnd(10, 0, 0, w, h, C.panel)
        rndO(10, 0, 0, w, h, C.border)
    end

    local cy = 12
    label(edBg, LPAD, cy, edW - LPAD * 2, 26, ec.id ~= 0 and ("Edit: " .. (ec.code or "")) or "Nouveau créateur", Font:GetNamed("Poppins", "Bold", 18), C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    cy = cy + 34
    local function erow(lbl, widget, h)
        h = h or GH
        label(edBg, LPAD, cy, 140, h, lbl, Font:GetNamed("Poppins", "Medium", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        widget:SetParent(edBg)
        widget:SetPos(LPAD + 148, cy)
        widget:SetSize(edW - LPAD - 148 - LPAD, h)
        cy = cy + h + GY
    end

    local eCode = makeEntry(edBg, 0, 0, 1, 1, "MYCODE")
    eCode:SetValue(ec.code or "")
    erow("Code", eCode)
    local eOwner = makeEntry(edBg, 0, 0, 1, 1, "Pseudo du créateur")
    eOwner:SetValue(ec.owner_name or "")
    erow("Owner name", eOwner)
    local eSteamID = makeEntry(edBg, 0, 0, 1, 1, "STEAM_0:0:12345678")
    eSteamID:SetValue(ec.steamid or "")
    erow("Steam ID créateur", eSteamID)
    local eRate = makeEntry(edBg, 0, 0, 1, 1, "0", true)
    eRate:SetValue(tostring(ec.payout_rate or 0))
    erow("Payout %", eRate)
    local eDiscount = makeEntry(edBg, 0, 0, 1, 1, "0", true)
    eDiscount:SetValue(tostring(ec.buyer_discount or 0))
    erow("Réduction acheteur %", eDiscount)
    local eNotes = makeEntry(edBg, 0, 0, 1, 1, "Notes internes")
    eNotes:SetValue(ec.notes or "")
    erow("Notes", eNotes)

    if not istable(ec.bonus_rewards) then ec.bonus_rewards = {} end

    local BONUS_TYPES = {
        { label = "Coins", value = "coins" },
        { label = "Produit du magasin", value = "item" },
    }

    local productChoices = { { label = "— Aucun —", value = "" } }
    local sortedProducts = {}
    for _, p in pairs(BT.Products or {}) do sortedProducts[#sortedProducts + 1] = p end
    table.sort(sortedProducts, function(a, b) return tostring(a.name or a.id) < tostring(b.name or b.id) end)
    for _, p in ipairs(sortedProducts) do
        productChoices[#productChoices + 1] = {
            label = tostring(p.name or p.id) .. " [" .. tostring(p.id) .. "]",
            value = tostring(p.id),
        }
    end

    label(edBg, LPAD, cy, edW - LPAD * 2, 22, "Récompenses", Font:GetNamed("Poppins", "SemiBold", 15), C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    cy = cy + 26

    local rewardWidgets = {}
    local rewardRowH = GH
    for i, reward in ipairs(ec.bonus_rewards) do
        local _i = i
        local rowY = cy
        local innerW = edW - LPAD * 2
        local typeW = 170
        local delW = 32
        local fieldGap = 6
        local amtW = 80
        local itemW = innerW - typeW - amtW - delW - fieldGap * 3
        local coinsFullW = innerW - typeW - delW - fieldGap * 2

        local initialType = reward.type or "coins"
        if initialType ~= "coins" and initialType ~= "item" then initialType = "coins" end

        local dType = makeMantleCombo(edBg, LPAD, rowY, typeW, rewardRowH, BONUS_TYPES, initialType)

        local eAmt = makeEntry(edBg, LPAD + typeW + fieldGap, rowY, amtW, rewardRowH, "0", true)
        eAmt:SetValue(tostring(reward.amount or 0))

        local dItem = makeMantleCombo(edBg, LPAD + typeW + amtW + fieldGap * 2, rowY, itemW, rewardRowH, productChoices, reward.item or "")

        local function applyVisibility(t)
            if t == "item" then
                eAmt:SetPos(LPAD + typeW + fieldGap, rowY)
                eAmt:SetWide(amtW)
                dItem:SetVisible(true)
            else
                eAmt:SetPos(LPAD + typeW + fieldGap, rowY)
                eAmt:SetWide(coinsFullW)
                dItem:SetVisible(false)
            end
        end
        applyVisibility(initialType)

        dType.OnSelect = function(_, _, data)
            local newType = data or "coins"
            ec.bonus_rewards[_i].type = newType
            applyVisibility(newType)
        end
        dItem.OnSelect = function(_, _, data) ec.bonus_rewards[_i].item = data or "" end

        makeBtn(edBg, LPAD + innerW - delW, rowY, delW, rewardRowH, "X", C.red, function()
            table.remove(ec.bonus_rewards, _i)
            rebuildAdmin()
        end)

        rewardWidgets[_i] = { type = dType, amount = eAmt, item = dItem }
        cy = cy + rewardRowH + 4
    end

    makeBtn(edBg, LPAD, cy, edW - LPAD * 2, rewardRowH, "+ Ajouter une récompense", C.green, function()
        ec.bonus_rewards[#ec.bonus_rewards + 1] = { type = "coins", amount = 0, item = "" }
        rebuildAdmin()
    end)
    cy = cy + rewardRowH + 10

    makeBtn(edBg, LPAD + 148, cy, 140, GH, ec.enabled and "Enabled" or "Disabled", ec.enabled and C.green or C.red, function()
        ec.enabled = not ec.enabled
        rebuildAdmin()
    end)

    cy = cy + GH + GY + 6
    local statBg = vgui.Create("DPanel", edBg)
    statBg:SetPos(LPAD, cy)
    statBg:SetSize(edW - LPAD * 2, 100)
    local _stats = ADM.creatorStats and ADM.creatorStats[ec.code] or nil
    local _edStatHdrFont  = Font:GetNamed("Poppins", "Bold",    15)
    local _edStatValFont  = Font:GetNamed("Poppins", "Medium",  13)
    local _edStatNoneFont = Font:GetNamed("Poppins", "Regular", 13)
    statBg.Paint = function(_, w, h)
        rnd(8, 0, 0, w, h, _ADM_COL_STAT_BG)
        rndO(8, 0, 0, w, h, C.border)
        draw.SimpleText("Statistiques", _edStatHdrFont, 12, 10, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if _stats then
            local col1X, col2X = 12, w * 0.5 + 8
            draw.SimpleText("Joueurs uniques: " .. tostring(_stats.unique_players or 0), _edStatValFont, col1X, 34, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Coins dépensés: " .. tostring(_stats.total_amount or 0), _edStatValFont, col1X, 54, _ADM_COL_STAT_AMOUNT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Événements: " .. tostring(_stats.events_count or 0), _edStatValFont, col1X, 74, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Rolls: " .. tostring(_stats.rolls_count or 0), _edStatValFont, col2X, 34, _ADM_COL_STAT_ROLLS, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Achats: " .. tostring(_stats.purchases_count or 0), _edStatValFont, col2X, 54, _ADM_COL_STAT_PLAYERS, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local lastStr = _stats.last_activity and _stats.last_activity > 0 and os.date("%Y-%m-%d %H:%M", _stats.last_activity) or "-"
            draw.SimpleText("Dernière activité: " .. lastStr, _edStatValFont, col2X, 74, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        else
            draw.SimpleText("Aucune activité enregistrée", _edStatNoneFont, 12, 50, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    cy = cy + 108
    edBg:SetTall(cy + 54)
    local halfW = (edW - LPAD * 2 - 8) * 0.5
    makeBtn(edBg, LPAD, cy, halfW, 36, "Save", C.green, function()
        local code = tostring(eCode:GetValue() or ""):upper():Trim()
        if code == "" then
            LocalPlayer():Notify("Code requis.", NOTIFY_ERROR, 3)
            return
        end

        local rewardsOut = {}
        for i, w in ipairs(rewardWidgets) do
            local cur = ec.bonus_rewards[i] or {}
            local t = (w.type.GetSelectedData and w.type:GetSelectedData()) or cur.type or "coins"
            local amt = math.max(0, math.floor(tonumber(w.amount:GetValue()) or 0))
            local itm = (w.item.GetSelectedData and w.item:GetSelectedData()) or cur.item or ""
            if amt > 0 then
                rewardsOut[#rewardsOut + 1] = { type = t, amount = amt, item = itm }
            end
        end

        netstream.Start(BT.Net.Admin.SaveCreator, {
            id = ec.id or 0,
            code = code,
            owner_name = tostring(eOwner:GetValue() or ""):Trim(),
            steamid = tostring(eSteamID:GetValue() or ""):Trim(),
            payout_rate = math.max(0, math.floor(tonumber(eRate:GetValue()) or 0)),
            buyer_discount = math.min(99, math.max(0, math.floor(tonumber(eDiscount:GetValue()) or 0))),
            notes = tostring(eNotes:GetValue() or ""):Trim(),
            enabled = ec.enabled ~= false,
            bonus_rewards = rewardsOut,
        })

        ADM.editCreator = nil
    end)

    makeBtn(edBg, LPAD + halfW + 8, cy, halfW, 36, "Cancel", C.red, function()
        ADM.editCreator = nil
        rebuildAdmin()
    end)
end

local function buildRerollsTab(content, fw, fh)
    local listW = math.floor(fw * 0.42)
    local edW = fw - listW - 24
    local listBg = vgui.Create("DPanel", content)
    listBg:SetPos(8, 8)
    listBg:SetSize(listW, fh - 16)
    listBg.Paint = function(_, w, h)
        rnd(10, 0, 0, w, h, C.panel)
        rndO(10, 0, 0, w, h, C.border)
    end

    label(listBg, 14, 10, listW - 28, 26, "Reroll Pool", Font:GetNamed("Poppins", "Bold", 20), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    local rerollProducts = {}
    for _, p in pairs(BT.Products or {}) do
        if p.use_mode == "open_occult_page" or p.use_mode == "open_heritage_page" then rerollProducts[#rerollProducts + 1] = p end
    end

    table.sort(rerollProducts, function(a, b) return (tonumber(a.sort_order) or 0) < (tonumber(b.sort_order) or 0) end)
    local rerollTabValid = false
    for _, p in ipairs(rerollProducts) do
        if p.id == ADM.rerollTab then
            rerollTabValid = true
            break
        end
    end

    if not rerollTabValid then ADM.rerollTab = rerollProducts[1] and rerollProducts[1].id or "" end
    if #rerollProducts == 0 then
        label(listBg, 14, 42, listW - 28, 28, "No reroll product found (open_occult_page / open_heritage_page)", Font:GetNamed("Poppins", "Regular", 13), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    else
        local subTabW = math.floor((listW - 28) / #rerollProducts)
        for i, p in ipairs(rerollProducts) do
            local _p = p
            local sbtn = vgui.Create("DButton", listBg)
            sbtn:SetPos(12 + (i - 1) * subTabW, 42)
            sbtn:SetSize(subTabW - 2, 28)
            sbtn:SetText("")
            local _subtabFont   = Font:GetNamed("Poppins", ADM.rerollTab == _p.id and "SemiBold" or "Regular", 12)
            local _subtabAccent = _p.accent or C.accent
            sbtn.Paint = function(s, sw, sh)
                local sel = ADM.rerollTab == _p.id
                rnd(6, 0, 0, sw, sh, sel and _ADM_COL_SUBTAB_SEL or _ADM_COL_SUBTAB_NRM)
                if sel then rnd(0, 0, sh - 2, sw, 2, C.accent) end
                draw.SimpleText(_p.name or _p.id, _subtabFont, sw * 0.5, sh * 0.5, sel and _subtabAccent or C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            sbtn.DoClick = function()
                ADM.rerollTab = _p.id
                ADM.editPoolEntry = nil
                rebuildAdmin()
            end
        end
    end

    makeBtn(listBg, 12, 76, listW - 24, 32, "+ New entry", C.green, function()
        ADM.editPoolEntry = {
            id = 0,
            roll_type = ADM.rerollTab
        }

        rebuildAdmin()
    end)

    local pool = ADM.rerollPool[ADM.rerollTab] or {}
    local totalWeight = 0
    for _, e in ipairs(pool) do
        totalWeight = totalWeight + math.max(1, tonumber(e.weight) or 1)
    end

    local scroll = makeScroll(listBg, 8, 114, listW - 16, fh - 132)
    local canvas = scroll:GetCanvas()
    canvas.Paint = function() end
    local rowH = 58
    local btnW = 46
    local btnH = rowH - 18
    local btnY = 9
    local rw = listW - 16
    for i, entry in ipairs(pool) do
        local _e = entry
        local row = vgui.Create("DPanel", canvas)
        row:SetPos(0, (i - 1) * (rowH + 4))
        row:SetSize(rw, rowH)
        local _poolNameFont = Font:GetNamed("Poppins", "SemiBold", 15)
        local _poolSubFont  = Font:GetNamed("Poppins", "Regular",  12)
        local _poolPctFont  = Font:GetNamed("Poppins", "Bold",     13)
        row.Paint = function(_, prw, prh)
            local bgC = ADM.editPoolEntry and ADM.editPoolEntry.id == _e.id and _ADM_COL_ROW_SEL_POOL or (i % 2 == 0 and C.row2 or C.row1)
            rnd(8, 0, 0, prw, prh, bgC)
            local rc = BT:GetRarityColor(_e.rarity)
            rnd(4, 0, prh * 0.18, 3, prh * 0.64, rc)
            if _e.icon and _e.icon ~= "" then Mats:Draw(color_white, _e.icon, 10, (prh - 36) * 0.5, 36, 36, "noclamp smooth") end
            local pct = totalWeight > 0 and (math.floor((math.max(1, tonumber(_e.weight) or 1) / totalWeight) * 1000) / 10) or 0
            local pctStr = string.format("%.1f%%", pct)
            draw.SimpleText(_e.name or "?", _poolNameFont, 54, prh * 0.32, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(_e.reward_type) .. " = " .. tostring(_e.reward_value), _poolSubFont, 54, prh * 0.62, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(pctStr, _poolPctFont, prw - btnW * 2 - 16, prh * 0.5, _ADM_COL_POOL_PCT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local _poolBtnFont = Font:GetNamed("Poppins", "SemiBold", 13)
        local editBtn = vgui.Create("DButton", row)
        editBtn:SetPos(rw - btnW * 2 - 8, btnY)
        editBtn:SetSize(btnW, btnH)
        editBtn:SetText("")
        editBtn.Paint = function(s, ew, eh)
            _ADM_COL_BTN_EDIT.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, ew, eh, _ADM_COL_BTN_EDIT)
            draw.SimpleText("Edit", _poolBtnFont, ew * 0.5, eh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        editBtn.DoClick = function()
            ADM.editPoolEntry = table.Copy(_e)
            rebuildAdmin()
        end

        local delBtn = vgui.Create("DButton", row)
        delBtn:SetPos(rw - btnW - 4, btnY)
        delBtn:SetSize(btnW, btnH)
        delBtn:SetText("")
        delBtn.Paint = function(s, ew, eh)
            _ADM_COL_BTN_DEL.a = s:IsHovered() and 220 or 155
            rnd(6, 0, 0, ew, eh, _ADM_COL_BTN_DEL)
            draw.SimpleText("Del", _poolBtnFont, ew * 0.5, eh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        delBtn.DoClick = function() Derma_Query("Delete " .. (_e.name or "?") .. "?", "Confirm", "Yes", function() netstream.Start(BT.Net.Admin.DelPoolEntry, _e.id, ADM.rerollTab) end, "No", function() end) end
    end

    canvas:SetTall(math.max(#pool * (rowH + 4), scroll:GetTall()))
    if ADM.editPoolEntry ~= nil then
        local ep = ADM.editPoolEntry
        local edScroll = makeScroll(content, listW + 16, 8, edW, fh - 16)
        local BG = vgui.Create("DPanel", edScroll:GetCanvas())
        BG:SetPos(0, 0)
        BG:SetSize(edW - 8, 650)
        BG.Paint = function(_, bw, bh)
            rnd(10, 0, 0, bw, bh, C.panel)
            rndO(10, 0, 0, bw, bh, C.border)
        end

        local LPAD, GY, GH, GW1, GW2 = 16, 10, 32, 148, (edW - 8) - 148 - 16 * 2 - 8
        local function row(yOff, lbl, widget)
            label(BG, LPAD, yOff, GW1, GH, lbl, Font:GetNamed("Poppins", "Medium", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            widget:SetParent(BG)
            widget:SetPos(LPAD + GW1 + 8, yOff)
            widget:SetSize(GW2, GH)
        end

        local cy = 12
        label(BG, LPAD, cy, (edW - 8) - LPAD * 2, 26, (ep.id and ep.id > 0) and ("Edit entry #" .. ep.id) or "New entry", Font:GetNamed("Poppins", "Bold", 18), C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        cy = cy + 34
        local eName = makeEntry(BG, 0, 0, 1, 1, "Entry name")
        row(cy, "Name", eName)
        eName:SetValue(ep.name or "")
        cy = cy + GH + GY
        local eIcon = makeEntry(BG, 0, 0, 1, 1, "verse/boutique/...")
        row(cy, "Icon (path)", eIcon)
        eIcon:SetValue(ep.icon or "")
        cy = cy + GH + GY
        local eResultIcon = makeEntry(BG, 0, 0, 1, 1, "verse/boutique/... (vide = utilise Icon)")
        row(cy, "Result icon", eResultIcon)
        eResultIcon:SetValue(ep.result_icon or "")
        cy = cy + GH + GY
        local previewW = math.min(GW2, 80)
        local prevPanel = vgui.Create("DPanel", BG)
        prevPanel:SetPos(LPAD + GW1 + 8, cy)
        prevPanel:SetSize(previewW, 80)
        prevPanel.Paint = function(_, pw, ph)
            rnd(6, 0, 0, pw, ph, C.panel2)
            rndO(6, 0, 0, pw, ph, C.border)
            local iconPath = eIcon:GetValue() or ""
            if iconPath ~= "" then
                Mats:Draw(color_white, iconPath, 4, 4, pw - 8, ph - 8, "noclamp smooth")
            else
                draw.SimpleText("preview", Font:GetNamed("Poppins", "Regular", 12), pw * 0.5, ph * 0.5, C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        label(BG, LPAD, cy, GW1, 80, "Icon preview", Font:GetNamed("Poppins", "Medium", 15), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local prevResult = vgui.Create("DPanel", BG)
        prevResult:SetPos(LPAD + GW1 + 8 + previewW + 8, cy)
        prevResult:SetSize(previewW, 80)
        prevResult.Paint = function(_, pw, ph)
            rnd(6, 0, 0, pw, ph, C.panel2)
            rndO(6, 0, 0, pw, ph, C.border)
            local iconPath = eResultIcon:GetValue() or ""
            if iconPath == "" then iconPath = eIcon:GetValue() or "" end
            if iconPath ~= "" then
                Mats:Draw(color_white, iconPath, 4, 4, pw - 8, ph - 8, "noclamp smooth")
            else
                draw.SimpleText("result preview", Font:GetNamed("Poppins", "Regular", 11), pw * 0.5, ph * 0.5, C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        cy = cy + 88
        local rarChoices = {
            {
                label = "- None -",
                value = ""
            }
        }

        for _, r in ipairs(BT.Rarities or {}) do
            rarChoices[#rarChoices + 1] = {
                label = r.name,
                value = r.id
            }
        end

        local dRar = makeMantleCombo(BG, 0, 0, 1, 1, rarChoices, ep.rarity or "")
        row(cy, "Rarity", dRar)
        cy = cy + GH + GY
        local eWeight = makeEntry(BG, 0, 0, 1, 1, "1", true)
        row(cy, "Weight", eWeight)
        eWeight:SetValue(tostring(ep.weight or 1))
        cy = cy + GH + GY
        local dRewardType = makeMantleCombo(BG, 0, 0, 1, 1, REWARD_TYPES, ep.reward_type or "coins")
        row(cy, "Reward type", dRewardType)
        cy = cy + GH + GY
        local eRewardVal = makeEntry(BG, 0, 0, 1, 1, "amount / item_id / stub")
        row(cy, "Reward value", eRewardVal)
        eRewardVal:SetValue(tostring(ep.reward_value or "0"))
        cy = cy + GH + GY
        local tabProduct = BT:GetProduct(ADM.rerollTab)
        local isHeritage = tabProduct and tabProduct.use_mode == "open_heritage_page"
        local eVideoUrl
        if isHeritage then
            eVideoUrl = makeEntry(BG, 0, 0, 1, 1, "https://... (.webm/.mp4, vide = désactivé)")
            row(cy, "Video URL", eVideoUrl)
            eVideoUrl:SetValue(ep.video_url or "")
            cy = cy + GH + GY
        end

        local eSort = makeEntry(BG, 0, 0, 1, 1, "0", true)
        row(cy, "Sort order", eSort)
        eSort:SetValue(tostring(ep.sort_order or 0))
        cy = cy + GH + GY
        BG:SetTall(cy + 60)
        local saveBtnW = ((edW - 8) - LPAD * 2) * 0.5 - 4
        makeBtn(BG, LPAD, cy + 4, saveBtnW, 36, "Save", C.green, function()
            local data = {
                id = ep.id or 0,
                roll_type = ADM.rerollTab,
                name = eName:GetValue():Trim(),
                icon = eIcon:GetValue():Trim(),
                result_icon = eResultIcon:GetValue():Trim(),
                rarity = dRar:GetSelectedData() or "",
                weight = math.max(1, math.floor(tonumber(eWeight:GetValue()) or 1)),
                reward_type = dRewardType:GetSelectedData() or "coins",
                reward_value = eRewardVal:GetValue():Trim(),
                video_url = (eVideoUrl and eVideoUrl:GetValue():Trim()) or "",
                sort_order = math.floor(tonumber(eSort:GetValue()) or 0),
            }

            if data.name == "" then
                LocalPlayer():Notify("Name required.", NOTIFY_ERROR, 3)
                return
            end

            netstream.Start(BT.Net.Admin.SavePoolEntry, data)
            ADM.editPoolEntry = nil
            rebuildAdmin()
        end)

        makeBtn(BG, LPAD + saveBtnW + 8, cy + 4, saveBtnW, 36, "Cancel", C.muted, function()
            ADM.editPoolEntry = nil
            rebuildAdmin()
        end)
    end
end

function BT:OpenAdminUI()
    if IsValid(ADM.frame) then
        ADM.frame:Close()
        return
    end

    ADM.editProduct = nil
    ADM.editRarity = nil
    ADM.playerData = nil
    ADM.editPoolEntry = nil
    netstream.Start(BT.Net.Admin.RequestData)
    local FW, FH = ScrW() * 0.88, ScrH() * 0.88
    local frame = vgui.Create("DFrame")
    frame:SetSize(FW, FH)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    ADM.frame = frame
    frame.Paint = function(_, w, h)
        rnd(12, 0, 0, w, h, C.bg)
        rndO(12, 0, 0, w, h, C.border)
        draw.SimpleText("Admin Boutique", Font:GetNamed("Poppins", "Bold", 18), w * 0.5, 20, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(FW - 44, 6)
    closeBtn:SetSize(36, 28)
    closeBtn:SetText("")
    local _closeXFont = Font:GetNamed("Poppins", "Bold", 14)
    closeBtn.Paint = function(s, w, h)
        _ADM_COL_CLOSE_BG.a = s:IsHovered() and 220 or 160
        rnd(6, 0, 0, w, h, _ADM_COL_CLOSE_BG)
        draw.SimpleText("✕", _closeXFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    closeBtn.DoClick = function() frame:Close() end
    local TABS = {
        {
            id = "products",
            label = "Produits"
        },
        {
            id = "rarities",
            label = "Raretés"
        },
        {
            id = "players",
            label = "Joueurs"
        },
        {
            id = "rerolls",
            label = "Rerolls"
        },
        {
            id = "creators",
            label = "Créateurs"
        },
        {
            id = "pack_tenue",
            label = "Pack Tenues"
        },
    }

    local tabH = 38
    local tabW = math.floor(FW / #TABS)
    for i, tab in ipairs(TABS) do
        local tb = vgui.Create("DButton", frame)
        tb:SetPos((i - 1) * tabW, 44)
        tb:SetSize(tabW, tabH)
        tb:SetText("")
        local _tab = tab
        local _tabFont = Font:GetNamed("Poppins", ADM.tab == _tab.id and "Bold" or "Medium", 15)
        tb.Paint = function(s, tw, th)
            local sel = ADM.tab == _tab.id
            rnd(0, 0, 0, tw, th, sel and _ADM_COL_TAB_SEL_BG or _ADM_COL_TAB_NRM_BG)
            if sel then rnd(0, 0, th - 3, tw, 3, C.accent) end
            draw.SimpleText(_tab.label, _tabFont, tw * 0.5, th * 0.5, sel and C.accent or C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        tb.DoClick = function()
            ADM.tab = _tab.id
            rebuildAdmin()
        end
    end

    local contentY = 44 + tabH + 4
    local contentH = FH - contentY - 8
    local content = vgui.Create("DPanel", frame)
    content:SetPos(0, contentY)
    content:SetSize(FW, contentH)
    content.Paint = function() end
    local function rebuild()
        content:Clear()
        if ADM.tab == "products" then
            buildProductsTab(content, FW, contentH)
        elseif ADM.tab == "rarities" then
            buildRaritiesTab(content, FW, contentH)
        elseif ADM.tab == "players" then
            buildPlayersTab(content, FW, contentH)
        elseif ADM.tab == "rerolls" then
            buildRerollsTab(content, FW, contentH)
        elseif ADM.tab == "creators" then
            buildCreatorsTab(content, FW, contentH)
        elseif ADM.tab == "pack_tenue" then
            _ui.buildPackTenueAdminTab(content, FW, contentH)
        end
    end

    ADM._rebuild = rebuild
    rebuild()
    frame.OnRemove = function()
        ADM.frame = nil
        ADM._rebuild = nil
    end
end

_ui.onAdminDataSync = function(data)
    if istable(data.reroll_pool) then ADM.rerollPool = data.reroll_pool end
    if istable(data.creators) then ADM.creators = data.creators end
    if istable(data.pack_tenue_packs) then BT.PackTenuePacks = data.pack_tenue_packs end
    if IsValid(ADM.frame) and isfunction(ADM._rebuild) then ADM._rebuild() end
end

_ui.onAdminCreatorStats = function(stats)
    ADM.creatorStats = istable(stats) and stats or {}
    if IsValid(ADM.frame) and isfunction(ADM._rebuild) then ADM._rebuild() end
end

_ui.onAdminCreatorDetails = function(details)
    ADM.creatorDetails = istable(details) and details or nil
    if IsValid(ADM.frame) and isfunction(ADM._rebuild) then ADM._rebuild() end
end

_ui.onAdminCSVExportResult = function(ok, pathOrErr, count)
    local lp = LocalPlayer()
    if ok then
        if IsValid(lp) and isfunction(lp.Notify) then lp:Notify("CSV export: " .. tostring(count) .. " lignes → data/" .. tostring(pathOrErr), NOTIFY_HINT, 6) end
        chat.AddText(Color(100, 210, 255), "[Boutique] CSV exporté: ", color_white, "garrysmod/data/", tostring(pathOrErr), " (", tostring(count), " lignes)")
    else
        if IsValid(lp) and isfunction(lp.Notify) then lp:Notify("CSV export échoué: " .. tostring(pathOrErr), NOTIFY_ERROR, 5) end
    end
end

_ui.onAdminPlayerData = function(data)
    ADM.playerData = data
    ADM.tab = "players"
    if IsValid(ADM.frame) and isfunction(ADM._rebuild) then ADM._rebuild() end
end

_ui.onAdminRerollPoolData = function(rollType, pool)
    if rollType and rollType ~= "" then ADM.rerollPool[rollType] = istable(pool) and pool or {} end
    if IsValid(ADM.frame) and isfunction(ADM._rebuild) then ADM._rebuild() end
end