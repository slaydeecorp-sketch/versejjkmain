local BT = VERSE.Boutique
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local _ui = BT._ui

-- ─── Couleurs pré-allouées pour Owned UI (évite Color() par frame) ───────────
local _OW_COL_SBAR_GRIP      = Color(255, 255, 255, 80)
local _OW_COL_EMPTY_BG       = Color(255, 255, 255, 12)   -- DrawDuplicate tint
local _OW_COL_EMPTY_FILL     = Color(38,  38,  38,  140)
local _OW_COL_EMPTY_OUT      = Color(255, 255, 255, 20)
local _OW_COL_EMPTY_TITLE    = Color(120, 120, 120, 255)
local _OW_COL_EMPTY_SUB      = Color(75,  75,  75,  255)
local _OW_COL_ROW_BG         = Color(255, 255, 255, 16)   -- DrawDuplicate tint
local _OW_COL_ROW_FILL       = Color(48,  48,  48,  155)
local _OW_COL_ROW_USE_TXT    = Color(130, 130, 130, 255)
local _OW_COL_TX_BG          = Color(255, 255, 255, 12)   -- DrawDuplicate tint
local _OW_COL_TX_FILL        = Color(38,  38,  38,  155)
local _OW_COL_TX_TIME        = Color(90,  90,  90,  255)
local _OW_COL_TX_COIN_POS    = Color(255, 207, 85,  255)
local _OW_COL_TX_COIN_NEG    = Color(240, 90,  90,  255)
local _OW_COL_SECTION_TITLE  = Color(215, 215, 215, 255)
local _OW_COL_SECTION_COUNT  = Color(100, 100, 100, 255)
local _OW_COL_DIVIDER        = Color(255, 255, 255, 45)
-- ─────────────────────────────────────────────────────────────────────────────

local INVENT_X = 120
local INVENT_W = 990
local DIV_X = 1128
local HIST_X = 1153
local HIST_W = 701
local HEADER_Y = 190
local CONTENT_Y = 242
local CONTENT_H = 708
local ROW_H = 92
local ROW_GAP = 8
local TX_H = 88
local TX_GAP = 8
local TX_CONFIG = {
    purchase = {
        label = "ACHAT",
        color = Color(78, 254, 122)
    },
    coins_add = {
        label = "COINS",
        color = Color(255, 207, 85)
    },
    roll_occult = {
        label = "ROULETTE",
        color = Color(98, 176, 255)
    },
    roll_heritage = {
        label = "HERITAGE",
        color = Color(255, 76, 76)
    },
    use_item = {
        label = "UTILISE",
        color = Color(171, 82, 255)
    },
}

local function getTxCfg(txType)
    return TX_CONFIG[tostring(txType or "")] or {
        label = string.upper(tostring(txType or "?")):sub(1, 10),
        color = Color(160, 160, 160)
    }
end

local function formatRelTime(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return "-" end
    local diff = os.time() - ts
    if diff < 60 then
        return "instant"
    elseif diff < 3600 then
        return math.floor(diff / 60) .. "min"
    elseif diff < 86400 then
        return math.floor(diff / 3600) .. "h"
    else
        return math.floor(diff / 86400) .. "j"
    end
end

local function makeScroll(parent, x, y, w, h)
    local s = vgui.Create("DScrollPanel", parent)
    s:SetPos(x, y)
    s:SetSize(w, h)
    s.Paint = function() end
    local sbar = s:GetVBar()
    sbar:SetWide(R:X(5))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(_, bw, bh) RNDX.Draw(R:Y(4), 0, 0, bw, bh, _OW_COL_SBAR_GRIP) end
    return s
end

local function buildEmptyPanel(parent, x, y, w, h, title, subtitle)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h)
    local _emptyTitleFont = Font:GetNamed("Poppins", "SemiBold", 32)
    local _emptySubFont   = Font:GetNamed("Poppins", "Medium",   20)
    p.Paint = function(_, pw, ph)
        Materials:DrawDuplicate(_OW_COL_EMPTY_BG, "boutique_background", 0, 0, pw, ph, "noclamp smooth")
        RNDX.Draw(R:Y(14), 0, 0, pw, ph, _OW_COL_EMPTY_FILL)
        RNDX.DrawOutlined(R:Y(14), 0, 0, pw, ph, _OW_COL_EMPTY_OUT, 1)
        local cy = ph * 0.43
        draw.SimpleText(title, _emptyTitleFont, pw * 0.5, cy, _OW_COL_EMPTY_TITLE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, _emptySubFont, pw * 0.5, cy + R:Y(48), _OW_COL_EMPTY_SUB, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function buildInventaireRow(canvas, product, y)
    local amount = _ui.getItemCount(product.id)
    local accent = _ui.cardAccent(product.id)
    local useMode = tostring(product.use_mode or "")
    local canUse = useMode == "consume_generic" or useMode == "open_pack" or useMode == "reset_skilltree" or useMode == "open_occult_page" or useMode == "open_heritage_page" or useMode == "open_martial_page"
    local row = vgui.Create("DPanel", canvas)
    row:SetPos(0, y)
    row:SetSize(R:XY(INVENT_W, ROW_H))
    local iconSz = R:Y(62)
    local iconX = R:X(14)
    local iconY = (R:Y(ROW_H) - iconSz) * 0.5
    -- Couleurs pré-allouées pour cette ligne (accent est dynamique)
    local _rowAccentStrong = Color(accent.r, accent.g, accent.b, 220)
    local _rowAccentOut    = Color(accent.r, accent.g, accent.b, 45)
    local _rowAccentFill   = Color(accent.r, accent.g, accent.b, 28)
    local _rowAccentOut2   = Color(accent.r, accent.g, accent.b, 100)
    local _rowBadgeFill    = Color(accent.r, accent.g, accent.b, 28)
    local _rowBadgeOut     = Color(accent.r, accent.g, accent.b, 120)
    local _rowNameFont     = Font:GetNamed("Poppins", "SemiBold", 22)
    local _rowUseFont      = Font:GetNamed("Poppins", "Medium",   16)
    local _rowAmtFont      = Font:GetNamed("Poppins", "Bold",     18)
    row.Paint = function(s, w, h)
        Materials:DrawDuplicate(_OW_COL_ROW_BG, "boutique_background", 0, 0, w, h, "noclamp smooth")
        RNDX.Draw(R:Y(10), 0, 0, w, h, _OW_COL_ROW_FILL)
        RNDX.Draw(R:Y(5), R:X(2), R:Y(9), R:X(3), h - R:Y(18), _rowAccentStrong)
        RNDX.DrawOutlined(R:Y(10), 0, 0, w, h, _rowAccentOut, 1)
        RNDX.Draw(R:Y(8), iconX, iconY, iconSz, iconSz, _rowAccentFill)
        RNDX.DrawOutlined(R:Y(8), iconX, iconY, iconSz, iconSz, _rowAccentOut2, 1)
        local icon, iw, ih = _ui.getProductIcon(product)
        local pad = R:Y(7)
        if icon then
            _ui.drawProductIcon(icon, iw, ih, iconX + pad, iconY + pad, iconSz - pad * 2, iconSz - pad * 2)
        else
            _ui.drawProductFallback(product, iconX + pad, iconY + pad, iconSz - pad * 2, iconSz - pad * 2)
        end

        local textX = iconX + iconSz + R:X(14)
        draw.SimpleText(product.name, _rowNameFont, textX, h * 0.34, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(product.use_text or "Utiliser", _rowUseFont, textX, h * 0.70, _OW_COL_ROW_USE_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local btnReserve = canUse and R:X(144) or 0
        local badgeW = R:X(64)
        local badgeH = R:Y(30)
        local badgeX = w - btnReserve - R:X(12) - badgeW
        local badgeY = (h - badgeH) * 0.5
        RNDX.Draw(R:Y(7), badgeX, badgeY, badgeW, badgeH, _rowBadgeFill)
        RNDX.DrawOutlined(R:Y(7), badgeX, badgeY, badgeW, badgeH, _rowBadgeOut, 1)
        draw.SimpleText("x" .. tostring(amount), _rowAmtFont, badgeX + badgeW * 0.5, badgeY + badgeH * 0.5, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if canUse then
        local btnW = R:X(122)
        local btnH = R:Y(38)
        local btn = vgui.Create("DButton", row)
        btn:SetPos(R:X(INVENT_W) - R:X(14) - btnW, (R:Y(ROW_H) - btnH) * 0.5)
        btn:SetSize(btnW, btnH)
        btn:SetText("")
        local _useBtnFill = Color(accent.r, accent.g, accent.b, 0)  -- .a muté
        local _useBtnOut  = Color(accent.r, accent.g, accent.b, 0)  -- .a muté
        local _useBtnFont = Font:GetNamed("Poppins", "SemiBold", 18)
        btn.Paint = function(s, w, h)
            local hov = s:IsHovered()
            _useBtnFill.a = hov and 75 or 40
            _useBtnOut.a  = hov and 210 or 130
            RNDX.Draw(R:Y(8), 0, 0, w, h, _useBtnFill)
            RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, _useBtnOut, 1)
            draw.SimpleText("Utiliser", _useBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function()
            if useMode == "open_occult_page" then
                BT:SetPage("power")
            elseif useMode == "open_heritage_page" then
                BT:SetPage("heritage")
            elseif useMode == "open_martial_page" then
                BT:SetPage("martial")
            else
                netstream.Start(BT.Net.UseOwnedItem, product.id)
            end
        end
    end
end

local function buildTxEntry(canvas, tx, y)
    local cfg = getTxCfg(tx.tx_type)
    local c = cfg.color
    local name = tostring((tx.payload and tx.payload.name) or tx.item_id or "-")
    local entry = vgui.Create("DPanel", canvas)
    entry:SetPos(0, y)
    entry:SetSize(R:XY(HIST_W, TX_H))
    -- Couleurs pré-allouées pour cette entrée (c est dynamique par tx)
    local _txAccentStrong = Color(c.r, c.g, c.b, 230)
    local _txAccentOut    = Color(c.r, c.g, c.b, 38)
    local _txBadgeFill    = Color(c.r, c.g, c.b, 38)
    local _txLabelFont    = Font:GetNamed("Poppins", "Bold",   13)
    local _txNameFont     = Font:GetNamed("Poppins", "Medium", 19)
    local _txTimeFont     = Font:GetNamed("Poppins", "Medium", 15)
    local _txCoinFont     = Font:GetNamed("Poppins", "Bold",   19)
    entry.Paint = function(_, w, h)
        Materials:DrawDuplicate(_OW_COL_TX_BG, "boutique_background", 0, 0, w, h, "noclamp smooth")
        RNDX.Draw(R:Y(8), 0, 0, w, h, _OW_COL_TX_FILL)
        RNDX.Draw(R:Y(5), R:X(2), R:Y(8), R:X(3), h - R:Y(16), _txAccentStrong)
        RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, _txAccentOut, 1)
        local bW = R:X(105)
        local bH = R:Y(26)
        local bX = R:X(14)
        local bY = R:Y(12)
        RNDX.Draw(R:Y(5), bX, bY, bW, bH, _txBadgeFill)
        draw.SimpleText(cfg.label, _txLabelFont, bX + bW * 0.5, bY + bH * 0.5, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(name, _txNameFont, bX, h - R:Y(18), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(formatRelTime(tx.created_at), _txTimeFont, w - R:X(12), bY + bH * 0.5, _OW_COL_TX_TIME, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        if tx.coins_delta ~= 0 then
            local sign = tx.coins_delta > 0 and "+" or ""
            local coinCol = tx.coins_delta > 0 and _OW_COL_TX_COIN_POS or _OW_COL_TX_COIN_NEG
            draw.SimpleText(sign .. tostring(tx.coins_delta) .. " coins", _txCoinFont, w - R:X(12), h - R:Y(18), coinCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end

local function buildSectionHeader(parent, x, y, w, title, countLabel)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, R:Y(44))
    local _secTitleFont = Font:GetNamed("Poppins", "Bold",   26)
    local _secCountFont = Font:GetNamed("Poppins", "Medium", 18)
    p.Paint = function(_, pw, ph)
        draw.SimpleText(title, _secTitleFont, R:X(4), ph * 0.5, _OW_COL_SECTION_TITLE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(countLabel, _secCountFont, pw - R:X(4), ph * 0.5, _OW_COL_SECTION_COUNT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

local function buildOwnedPage(parent)
    local owned = _ui.ownedProductIds()
    local transactions = (BT._state and BT._state.transactions) or {}
    local ownedLabel = tostring(#owned) .. " objet" .. (#owned ~= 1 and "s" or "")
    local txLabel = tostring(#transactions) .. " entree" .. (#transactions ~= 1 and "s" or "")
    buildSectionHeader(parent, R:X(INVENT_X), R:Y(HEADER_Y), R:X(INVENT_W), "INVENTAIRE", ownedLabel)
    buildSectionHeader(parent, R:X(HIST_X), R:Y(HEADER_Y), R:X(HIST_W), "HISTORIQUE", txLabel)
    local divider = vgui.Create("DPanel", parent)
    divider:SetPos(R:XY(DIV_X, HEADER_Y))
    divider:SetSize(R:XY(5, CONTENT_Y - HEADER_Y + CONTENT_H))
    divider.Paint = function(_, w, h) RNDX.Draw(R:Y(4), 0, 0, w, h, _OW_COL_DIVIDER) end
    if #owned == 0 then
        buildEmptyPanel(parent, R:X(INVENT_X), R:Y(CONTENT_Y), R:X(INVENT_W), R:Y(CONTENT_H), "Inventaire vide", "Achetez des packs et rerolls pour les voir ici.")
    else
        local scroll = makeScroll(parent, R:X(INVENT_X), R:Y(CONTENT_Y), R:X(INVENT_W), R:Y(CONTENT_H))
        local canvas = scroll:GetCanvas()
        local yOff = 0
        for i = 1, #owned do
            local product = BT:GetProduct(owned[i])
            if product then
                buildInventaireRow(canvas, product, yOff)
                yOff = yOff + R:Y(ROW_H + ROW_GAP)
            end
        end

        canvas:SetTall(math.max(yOff, scroll:GetTall()))
    end

    if #transactions == 0 then
        buildEmptyPanel(parent, R:X(HIST_X), R:Y(CONTENT_Y), R:X(HIST_W), R:Y(CONTENT_H), "Aucune transaction", "Vos achats apparaitront ici.")
    else
        local scroll2 = makeScroll(parent, R:X(HIST_X), R:Y(CONTENT_Y), R:X(HIST_W), R:Y(CONTENT_H))
        local canvas2 = scroll2:GetCanvas()
        local yOff2 = 0
        for i = 1, #transactions do
            buildTxEntry(canvas2, transactions[i], yOff2)
            yOff2 = yOff2 + R:Y(TX_H + TX_GAP)
        end

        canvas2:SetTall(math.max(yOff2, scroll2:GetTall()))
    end

    _ui.createBackButton(parent)
end

_ui.buildOwnedPage = buildOwnedPage