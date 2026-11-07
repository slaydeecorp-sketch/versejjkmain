local BT = VERSE.Boutique
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local _ui = BT._ui

-- ─── Couleurs pré-allouées pour boutique shared UI (évite Color() par frame) ──
local _SH_COL_ICON          = Color(255, 255, 255, 0)   -- .a muté
local _SH_COL_FALLBACK_FILL = Color(0,   0,   0,  34)   -- .a muté (via accent.r/g/b)
local _SH_COL_FALLBACK_OUT  = Color(0,   0,   0,  180)  -- .a muté (via accent.r/g/b)
local _SH_COL_FALLBACK_TXT  = Color(255, 255, 255, 230)
local _SH_COL_ACTION_BG     = Color(39,  39,  39,  0)   -- .a muté
local _SH_COL_HEADER_PILL   = Color(255, 255, 255, 0)   -- .a muté
local _SH_COL_CARD_SHADOW   = Color(0,   0,   0,  0)    -- .a muté
local _SH_COL_CARD_BG       = Color(255, 255, 255, 0)   -- .a muté
local _SH_COL_CARD_PRICE    = Color(225, 225, 225, 255)
local _SH_COL_QTY_BG        = Color(80,  80,  80,  0)   -- .a muté
local _SH_COL_LEFT_BG_TINT  = Color(255, 255, 255, 25)
local _SH_COL_LEFT_FILL     = Color(51,  51,  51,  153)
local _SH_COL_PREVIEW_TAG   = Color(77,  77,  77,  180)
local _SH_COL_BACK_BTN      = Color(180, 180, 180, 255)
-- ─────────────────────────────────────────────────────────────────────────────

local function getProductIcon(product)
    if product and product.icon and product.icon ~= "" then return product.icon, tonumber(product.icon_w) or 256, tonumber(product.icon_h) or 256 end
    return nil, 256, 256
end

local function drawProductIcon(alias, natW, natH, ax, ay, aw, ah, alpha)
    alpha = alpha or 255
    local scale = math.min(aw / R:X(natW), ah / R:Y(natH))
    local dw = R:X(natW) * scale
    local dh = R:Y(natH) * scale
    local dx = ax + (aw - dw) * 0.5
    local dy = ay + (ah - dh) * 0.5
    _SH_COL_ICON.a = alpha
    Materials:Draw(_SH_COL_ICON, alias, dx, dy, dw, dh, "noclamp smooth")
end

local function fadeColor(base, alpha)
    base = base or color_white
    return Color(base.r, base.g, base.b, alpha or 255)
end

local function drawFallbackBadge(x, y, w, h, accent, text, fontSize)
    _SH_COL_FALLBACK_FILL.r = accent and accent.r or 0
    _SH_COL_FALLBACK_FILL.g = accent and accent.g or 0
    _SH_COL_FALLBACK_FILL.b = accent and accent.b or 0
    _SH_COL_FALLBACK_FILL.a = 34
    _SH_COL_FALLBACK_OUT.r = _SH_COL_FALLBACK_FILL.r
    _SH_COL_FALLBACK_OUT.g = _SH_COL_FALLBACK_FILL.g
    _SH_COL_FALLBACK_OUT.b = _SH_COL_FALLBACK_FILL.b
    _SH_COL_FALLBACK_OUT.a = 180
    RNDX.Draw(R:Y(18), x, y, w, h, _SH_COL_FALLBACK_FILL)
    RNDX.DrawOutlined(R:Y(18), x, y, w, h, _SH_COL_FALLBACK_OUT, 2)
    draw.SimpleText(tostring(text or "?"), Font:GetNamed("Poppins", "Bold", fontSize or 28), x + w * 0.5, y + h * 0.5, _SH_COL_FALLBACK_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function drawProductFallback(product, x, y, w, h)
    local accent = product and product.accent or Color(171, 82, 255)
    local label = tostring((product and product.fallback_label) or string.upper(string.sub(tostring(product and product.name or "?"), 1, 8)))
    if w <= R:X(110) or h <= R:Y(110) then
        label = string.upper(string.sub(label, 1, 3))
    elseif w <= R:X(180) or h <= R:Y(180) then
        label = string.upper(string.sub(label, 1, 6))
    end

    drawFallbackBadge(x, y, w, h, accent, label, h >= R:Y(220) and 30 or 24)
end

local function drawOccultFallback(entry, x, y, w, h)
    local accent = BT:GetRarityColor(entry and entry.rarity)
    local label = string.upper(string.sub(tostring(entry and entry.name or "?"), 1, 1))
    drawFallbackBadge(x, y, w, h, accent, label, 36)
end

local function allProductIds()
    local out = {}
    for _, pageId in ipairs({"rerolls", "premium", "packs"}) do
        local products = BT:GetPageProductList(pageId)
        for i = 1, #products do
            out[#out + 1] = products[i].id
        end
    end
    return out
end

local function cardAccent(productId)
    local product = BT:GetProduct(productId)
    return product and product.accent or color_white
end

local function getItemCount(itemId)
    return math.max(0, math.floor(tonumber((BT._state.items or {})[itemId]) or 0))
end

local function getQuantity(pageId)
    return math.max(1, math.floor(tonumber((BT._state.quantities or {})[pageId]) or 1))
end

local function getSelectedProduct(pageId)
    local state = BT._state
    local selectedId = state.selected[pageId]
    local product = BT:GetProduct(selectedId)
    if product then return product end
    local list = BT:GetPageProductList(pageId)
    return list[1]
end

local function setSelectedProduct(pageId, productId)
    BT._state.selected[pageId] = productId
    if pageId == "owned" then BT:RebuildContent() end
end

local function clampQuantity(pageId, delta)
    local state = BT._state
    state.quantities[pageId] = math.Clamp((state.quantities[pageId] or 1) + delta, 1, 99)
    if IsValid(BT._content) then BT._content:InvalidateLayout(true) end
end

local function setQuantity(pageId, value)
    local state = BT._state
    state.quantities[pageId] = math.Clamp(math.floor(tonumber(value) or 1), 1, 99)
    if IsValid(BT._content) then BT._content:InvalidateLayout(true) end
end

local function ownedProductIds()
    local out, seen = {}, {}
    for _, productId in ipairs(allProductIds()) do
        local amount = getItemCount(productId)
        if amount > 0 and not seen[productId] then
            seen[productId] = true
            out[#out + 1] = productId
        end
    end
    return out
end

local function makeActionButton(parent, x, y, w, h, label, accent, callback)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    local _actBtnFont = Font:GetNamed("Poppins", "Medium", 16)
    btn.Paint = function(s, pw, ph)
        _SH_COL_ACTION_BG.a = s:IsHovered() and 220 or 180
        RNDX.Draw(R:Y(12), 0, 0, pw, ph, _SH_COL_ACTION_BG)
        RNDX.DrawOutlined(R:Y(12), 0, 0, pw, ph, accent, 2)
        draw.SimpleText(label, _actBtnFont, pw * 0.5, ph * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = callback
    return btn
end

local function makeHeaderPill(parent, x, y, w, h, text, accent, callback)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    local _pillFont = Font:GetNamed("Poppins", "Medium", 20)
    btn.Paint = function(s, pw, ph)
        _SH_COL_HEADER_PILL.a = s:IsHovered() and 70 or 40
        RNDX.Draw(R:Y(8), 0, 0, pw, ph, _SH_COL_HEADER_PILL)
        draw.SimpleText(text, _pillFont, pw * 0.5, ph * 0.5, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = callback
    return btn
end

local _SH_COL_BACK_BG = Color(38, 38, 38)
local function createBackButton(parent)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetPos(R:X(1724), R:Y(1011))
    btn:SetSize(R:X(148), R:Y(41))
    local _backFont = Font:GetNamed("Poppins", "Regular", 24, { extended = true })
    btn.Paint = function(s, pw, ph)
        local shade = s:IsHovered() and 52 or 38
        _SH_COL_BACK_BG.r = shade
        _SH_COL_BACK_BG.g = shade
        _SH_COL_BACK_BG.b = shade
        RNDX.Draw(R:Y(12), 0, 0, pw, ph, _SH_COL_BACK_BG)

        local label = "Retour"
        local arrow = "\226\134\144"
        local gap   = R:X(6)
        local arrowYOff = -R:Y(3)
        surface.SetFont(_backFont)
        local tw = surface.GetTextSize(label)
        local aw = surface.GetTextSize(arrow)
        local startX = (pw - (aw + gap + tw)) * 0.5
        local cy = ph * 0.5
        draw.SimpleText(arrow, _backFont, startX, cy + arrowYOff, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(label, _backFont, startX + aw + gap, cy, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function() BT:SetPage("home") end
    return btn
end

local _cardOutNorm = Color(255, 255, 255, 235)
local function paintGenericCardBackground(w, h, accent, hovered, selected)
    _SH_COL_CARD_SHADOW.a = hovered and 100 or 70
    _SH_COL_CARD_BG.a     = hovered and 35  or 18
    RNDX.Draw(0, R:X(10), R:Y(10), w - R:X(20), h - R:Y(20), _SH_COL_CARD_SHADOW)
    RNDX.Draw(R:Y(16), 0, 0, w, h, _SH_COL_CARD_BG)
    RNDX.DrawOutlined(R:Y(16), 0, 0, w, h, selected and accent or _cardOutNorm, selected and 3 or 2)
end

local function createCatalogCard(parent, product, x, y, w, h, pageId)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.Paint = function(s, pw, ph)
        local sel = getSelectedProduct(pageId)
        local selected = sel and sel.id == product.id
        local hovered = s:IsHovered()
        local accent = cardAccent(product.id)
        paintGenericCardBackground(pw, ph, accent, hovered, selected)
        local icon, iconW, iconH = getProductIcon(product)
        if pageId == "rerolls" then
            -- Page rerolls : image plein cadre, sans titre ni prix
            if icon then
                drawProductIcon(icon, iconW, iconH, 0, 0, pw, ph, selected and 255 or 240)
            else
                drawProductFallback(product, R:X(44), R:Y(36), pw - R:X(88), ph - R:Y(70))
            end
        else
            if icon then
                drawProductIcon(icon, iconW, iconH, R:X(28), 0, pw - R:X(56), ph, selected and 255 or 240)
            else
                drawProductFallback(product, R:X(44), R:Y(36), pw - R:X(88), ph - R:Y(154))
            end
            draw.SimpleText(product.name, Font:GetNamed("Poppins", "SemiBold", 20), pw * 0.5, ph - R:Y(64), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            local _cardDisc = BT._state and BT._state.creator_discount or 0
            if _cardDisc > 0 then
                local _cardDiscPrice = math.max(1, math.floor(product.price - math.floor(product.price * _cardDisc / 100)))
                draw.SimpleText(tostring(_cardDiscPrice) .. " coins", Font:GetNamed("Poppins", "Medium", 15), pw * 0.5, ph - R:Y(34), Color(100, 220, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(tostring(product.price) .. " coins", Font:GetNamed("Poppins", "Medium", 15), pw * 0.5, ph - R:Y(34), _SH_COL_CARD_PRICE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    btn.DoClick = function()
        setSelectedProduct(pageId, product.id)
        BT:RebuildContent()
    end
    return btn
end

local function createQuantityControls(parent, pageId, x, y)
    local btnW = R:X(42)
    local btnH = R:Y(42)
    local boxW = R:X(130)
    local gap = R:X(8)
    local minus = vgui.Create("DButton", parent)
    minus:SetPos(x, y)
    minus:SetSize(btnW, btnH)
    minus:SetText("")
    local _qtyBtnFont = Font:GetNamed("Poppins", "Bold", 22)
    minus.Paint = function(s, w, h)
        _SH_COL_QTY_BG.a = s:IsHovered() and 220 or 180
        RNDX.Draw(R:Y(10), 0, 0, w, h, _SH_COL_QTY_BG)
        draw.SimpleText("-", _qtyBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    minus.DoClick = function()
        clampQuantity(pageId, -1)
        BT:RebuildContent()
    end

    local qty = vgui.Create("DTextEntry", parent)
    qty:SetPos(x + btnW + gap, y)
    qty:SetSize(boxW, btnH)
    qty:SetFont(Font:GetNamed("Poppins", "Medium", 20))
    qty:SetNumeric(true)
    qty:SetDrawLanguageID(false)
    qty:SetDrawBorder(false)
    qty:SetPaintBackground(false)
    qty:SetTextColor(color_white)
    qty:SetCursorColor(color_white)
    qty:SetHighlightColor(Color(171, 82, 255, 120))
    qty:SetContentAlignment(5)
    qty:SetText(tostring(getQuantity(pageId)))
    qty:SetUpdateOnType(false)
    qty.Paint = function(s, w, h)
        _SH_COL_QTY_BG.a = 190
        RNDX.Draw(R:Y(10), 0, 0, w, h, _SH_COL_QTY_BG)
        s:DrawTextEntryText(s:GetTextColor(), s:GetHighlightColor(), s:GetCursorColor())
    end
    qty.OnEnter = function(s)
        setQuantity(pageId, s:GetText())
        s:KillFocus()
        BT:RebuildContent()
    end
    qty.OnLoseFocus = function(s)
        setQuantity(pageId, s:GetText())
        s:SetText(tostring(getQuantity(pageId)))
        BT:RebuildContent()
    end

    local plus = vgui.Create("DButton", parent)
    plus:SetPos(x + btnW + gap + boxW + gap, y)
    plus:SetSize(btnW, btnH)
    plus:SetText("")
    plus.Paint = function(s, w, h)
        _SH_COL_QTY_BG.a = s:IsHovered() and 220 or 180
        RNDX.Draw(R:Y(10), 0, 0, w, h, _SH_COL_QTY_BG)
        draw.SimpleText("+", _qtyBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    plus.DoClick = function()
        clampQuantity(pageId, 1)
        BT:RebuildContent()
    end
end

local function buildLeftInfoCard(parent, pageId, product)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(R:XY(120, 226))
    panel:SetSize(R:XY(449, 667))

    local _leftNameFont  = Font:GetNamed("Poppins", "SemiBold", 36)
    local _leftPrevFont  = Font:GetNamed("Poppins", "Medium",   14)
    local _leftStockFont = Font:GetNamed("Poppins", "SemiBold", 24)
    local _leftQtyFont   = Font:GetNamed("Poppins", "SemiBold", 20)
    local _leftTotalFont = Font:GetNamed("Poppins", "Medium",   20)
    local _leftPriceFont = Font:GetNamed("Poppins", "SemiBold", 32)
    panel.Paint = function(_, w, h)
        Materials:DrawDuplicate(_SH_COL_LEFT_BG_TINT, "boutique_background", 0, 0, w, h, "noclamp smooth")
        RNDX.Draw(R:Y(16), 0, 0, w, h, _SH_COL_LEFT_FILL)
        draw.SimpleText(product.name, _leftNameFont, w * 0.5, R:Y(48), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if pageId == "rerolls" then
            if product.preview_label then
                RNDX.Draw(R:Y(8), w * 0.5 - R:X(60), R:Y(80), R:X(120), R:Y(28), _SH_COL_PREVIEW_TAG)
                draw.SimpleText(product.preview_label, _leftPrevFont, w * 0.5, R:Y(94), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        elseif pageId == "owned" then
            draw.SimpleText("Stock: " .. tostring(getItemCount(product.id)), _leftStockFont, w * 0.5, R:Y(80), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if pageId ~= "packs" then
            local icon, iconW, iconH = getProductIcon(product)
            if icon then
                local areaY = R:Y(110)
                local areaH = R:Y(492) - areaY
                drawProductIcon(icon, iconW, iconH, R:X(30), areaY, w - R:X(60), areaH)
            end
        end

        draw.SimpleText("Quantité", _leftQtyFont, w * 0.5, R:Y(504), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local qty = (pageId == "owned") and math.max(1, getItemCount(product.id)) or getQuantity(pageId)
        local total = math.max(0, math.floor(tonumber(product.price) or 0)) * qty
        local _panelDisc = BT._state and BT._state.creator_discount or 0
        if _panelDisc > 0 then
            total = math.max(1, total - math.floor(total * _panelDisc / 100))
        end
        local priceStr = tostring(total) .. " Points"
        local totalW = VERSE.GetTextSize("TOTAL", _leftTotalFont)
        local innerGap = R:X(12)
        local priceW = VERSE.GetTextSize(priceStr, _leftPriceFont)
        local blockW = totalW + innerGap + priceW
        local blockX = (w - blockW) * 0.5
        local rowY = R:Y(627)
        draw.SimpleText("TOTAL", _leftTotalFont, blockX, rowY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(priceStr, _leftPriceFont, blockX + totalW + innerGap, rowY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if pageId == "packs" then
        local qtyBox = vgui.Create("DPanel", panel)
        qtyBox:SetPos(R:XY(160, 532))
        qtyBox:SetSize(R:XY(130, 42))
        local _qtyBoxFont = Font:GetNamed("Poppins", "Medium", 20)
        qtyBox.Paint = function(_, w, h)
            _SH_COL_QTY_BG.a = 190
            RNDX.Draw(R:Y(10), 0, 0, w, h, _SH_COL_QTY_BG)
            draw.SimpleText("1", _qtyBoxFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    else
        createQuantityControls(panel, pageId, R:X(109), R:Y(532))
    end

    if pageId ~= "owned" then
        makeActionButton(parent, R:X(249), R:Y(922), R:X(191), R:Y(37), product.purchase_text or "Acheter", Color(89, 187, 255), function() netstream.Start(BT.Net.BuyProduct, product.id, getQuantity(pageId)) end)
    else
        local label = product.use_text or "Utiliser"
        makeActionButton(parent, R:X(249), R:Y(922), R:X(191), R:Y(37), label, Color(171, 82, 255), function()
            local useMode = product.use_mode
            if useMode == "open_occult_page" then
                -- Ouvre la boutique si elle n'est pas déjà ouverte,
                -- navigue sur la page pouvoir occulte et lance le roll automatiquement.
                if not IsValid(BT._frame) then BT:OpenUI() end
                BT:SetPage("power")
                timer.Simple(0.05, function()
                    if BT._ui and isfunction(BT._ui.beginOccultRoll) then
                        BT._ui.beginOccultRoll()
                    end
                end)
            elseif useMode == "open_heritage_page" then
                if not IsValid(BT._frame) then BT:OpenUI() end
                BT:SetPage("heritage")
            else
                netstream.Start(BT.Net.UseOwnedItem, product.id)
            end
        end)
    end
end

_ui.getProductIcon = getProductIcon
_ui.drawProductIcon = drawProductIcon
_ui.drawProductFallback = drawProductFallback
_ui.drawOccultFallback = drawOccultFallback
_ui.allProductIds = allProductIds
_ui.cardAccent = cardAccent
_ui.getItemCount = getItemCount
_ui.getQuantity = getQuantity
_ui.getSelectedProduct = getSelectedProduct
_ui.setSelectedProduct = setSelectedProduct
_ui.clampQuantity = clampQuantity
_ui.setQuantity = setQuantity
_ui.ownedProductIds = ownedProductIds
_ui.makeActionButton = makeActionButton
_ui.makeHeaderPill = makeHeaderPill
_ui.createBackButton = createBackButton
_ui.paintGenericCardBg = paintGenericCardBackground
_ui.createCatalogCard = createCatalogCard
_ui.createQuantityControls = createQuantityControls
_ui.buildLeftInfoCard = buildLeftInfoCard
