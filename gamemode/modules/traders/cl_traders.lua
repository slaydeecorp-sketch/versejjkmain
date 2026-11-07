local TRADERS = VERSE.Traders
local INV = VERSE.Inventory
local R = VERSE.Responsive
local Materials = VERSE.Materials
local Font = VERSE.Fonts
Materials:SetAlias("traders_main_background", "verse/traders/main_background")
local MONEY_ICON = "verse/inventory/items/money_bag.png"

-- ─── Couleurs pré-allouées pour Traders UI (évite Color() par frame) ──────────
local _TR_COL_CLOSE_HOV     = Color(50,  50,  50,  225)
local _TR_COL_CLOSE_NORM    = Color(50,  50,  50,  255)
local _TR_COL_CLOSE_TXT_HOV = Color(255, 255, 255, 255)
local _TR_COL_CLOSE_TXT_NRM = Color(255, 255, 255, 180)
local _TR_COL_FRAME_BG      = Color(255, 255, 255, 235)
local _TR_COL_FRAME_BORD    = Color(50,  50,  50,  255)
local _TR_COL_SCROLL_BG     = Color(65,  65,  65,  150)
local _TR_COL_GRIP          = Color(255, 255, 255, 30)
local _TR_COL_RIGHT_BG      = Color(70,  44,  101, 180)
local _TR_COL_CIRCLE_OUTER  = Color(255, 255, 255, 60)
local _TR_COL_CIRCLE_INNER  = Color(255, 255, 255, 30)
local _TR_COL_DESC_TXT      = Color(200, 200, 200, 255)
local _TR_COL_ROW_SEL       = Color(255, 255, 255, 75)
local _TR_COL_ROW_NORM      = Color(255, 255, 255, 30)
-- ─────────────────────────────────────────────────────────────────────────────

TRADERS._shopFrame = nil
TRADERS._shopSelectedItem = nil
function TRADERS:CloseShop()
    if IsValid(self._shopFrame) then
        self._shopFrame:Remove()
        self._shopFrame = nil
    end

    self._shopSelectedItem = nil
end

function TRADERS:OpenShopUI(traderId, traderName, catalog)
    self:CloseShop()
    if not catalog or #catalog == 0 then return end
    local frameW = R:X(1010)
    local frameH = R:Y(797)
    local frame = vgui.Create("MantleFrame")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("")
    frame:SetAlphaBackground(false)
    frame:DisableCloseBtn()
    self._shopFrame = frame

    local btnClose = vgui.Create("DButton", frame)
    btnClose:SetSize(R:XY(42, 42))
    btnClose:SetPos(R:XY(1010 - 42 - 52, 34))
    btnClose:SetText("")
    local _closeBtnFont = Font:GetNamed("Poppins", "Bold", 22)
    btnClose.Paint = function(_, w, h)
        local hovered = btnClose:IsHovered()
        RNDX.Draw(R:Y(21), 0, 0, w, h, hovered and _TR_COL_CLOSE_HOV or _TR_COL_CLOSE_NORM)
        draw.SimpleText("X", _closeBtnFont, w * 0.5, h * 0.5, hovered and _TR_COL_CLOSE_TXT_HOV or _TR_COL_CLOSE_TXT_NRM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnClose.DoClick = function()
        TRADERS:CloseShop()
    end

    local _frameTitleFont = Font:GetNamed("Poppins", "SemiBold", 64)
    frame.Paint = function(_, w, h)
        Materials:DrawDuplicate(_TR_COL_FRAME_BG, "traders_main_background", 0, 0, w, h)
        RNDX.DrawOutlined(R:Y(15), R:X(28), R:Y(14), R:X(963), R:Y(755), _TR_COL_FRAME_BORD, 3)
        draw.SimpleText("Magasin", _frameTitleFont, w * 0.5 + R:X(20), R:Y(65), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local rightW = R:X(384)
    local rightH = R:Y(625)
    local rightX = R:X(1010 - 384 - 76)
    local rightY = R:Y(111)
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetSize(R:XY(442, 625))
    scroll:SetPos(R:XY(76, 111))
    scroll.Paint = function(_, w, h) RNDX.Draw(R:Y(10), 0, 0, w, h, _TR_COL_SCROLL_BG) end
    local sbar = scroll:GetVBar()
    sbar:SetWide(R:X(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h) RNDX.Draw(R:Y(2), 0, 0, w, h, _TR_COL_GRIP) end
    local container = vgui.Create("DPanel", scroll)
    container:Dock(TOP)
    container.Paint = function() end
    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:SetSize(rightW, rightH)
    rightPanel:SetPos(rightX, rightY)
    rightPanel.Paint = function(_, w, h) RNDX.Draw(R:Y(10), 0, 0, w, h, _TR_COL_RIGHT_BG) end
    local detailIcon = vgui.Create("DPanel", rightPanel)
    detailIcon:SetSize(R:X(120), R:Y(120))
    detailIcon.Paint = function(_, w, h)
        local cx, cy = w * 0.5, h * 0.5
        local sz = R:X(100)
        local item = TRADERS._shopSelectedItem
        if not item then return end
        RNDX().Circle(cx, cy, sz):Color(_TR_COL_CIRCLE_OUTER):DropShadow(R:X(20), R:X(25)):Draw()
        RNDX().Circle(cx, cy, sz):Color(_TR_COL_CIRCLE_INNER):Draw()
        local icon = item.icon or ""
        if icon ~= "" then
            local icoS = R:X(64)
            Materials:Draw(color_white, icon, cx - icoS * 0.5, cy - icoS * 0.5, icoS, icoS, "noclamp smooth")
        end
    end
    local detailName = vgui.Create("DPanel", rightPanel)
    detailName:SetSize(rightW, R:Y(40))
    detailName.Paint = function(_, w, h)
        local item = TRADERS._shopSelectedItem
        if not item then return end
        local rarityColor = INV:GetRarityColor(item.rarity)
        draw.SimpleText(item.name, Font:GetNamed("Poppins", "SemiBold", 32), w * 0.5, h * 0.5, rarityColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local detailDesc = vgui.Create("DPanel", rightPanel)
    detailDesc:SetSize(rightW - R:X(40), R:Y(160))
    detailDesc._cachedLines = nil
    detailDesc._cachedItemId = nil
    detailDesc.Paint = function(_, w, h)
        local item = TRADERS._shopSelectedItem
        if not item then return end

        local descFont = Font:GetNamed("Poppins", "Medium", 20)
        if detailDesc._cachedItemId ~= item.item_id then
            local desc = item.description or ""
            if desc == "" then desc = "Aucune description." end
            local lineH = R:Y(24)
            detailDesc._cachedLines = { VERSE.TextWrap(desc, descFont, lineH, w) }
            detailDesc._cachedItemId = item.item_id
        end

        local lines = detailDesc._cachedLines[1] or {}
        local lineH = R:Y(24)
        for i, line in ipairs(lines) do
            draw.SimpleText(line, descFont, w * 0.5, (i - 1) * lineH, _TR_COL_DESC_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end

    local detailPrice = vgui.Create("DPanel", rightPanel)
    detailPrice:SetSize(rightW, R:Y(35))
    detailPrice.Paint = function(_, w, h)
        local item = TRADERS._shopSelectedItem
        if not item then return end
        local priceText = tostring(item.price)
        local priceFont = Font:GetNamed("Poppins", "Medium", 24)
        local tw = VERSE.GetTextSize(priceText, priceFont)
        local icoS = 42
        local totalW = R:X(icoS + 4) + tw
        local sx = (w - totalW) * 0.5
        Materials:Draw(color_white, MONEY_ICON, sx, h * 0.5 - R:Y(icoS) * 0.5, R:X(icoS), R:Y(icoS), "noclamp smooth")
        draw.SimpleText(priceText, priceFont, sx + R:X(icoS + 4), h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local btnBuyW = R:X(280)
    local btnBuyH = R:Y(60)
    local btnBuyX = R:X(57)
    local btnBuyY = R:Y(625 - 60 - 21)
    local btnBuy = vgui.Create("MantleBtn", rightPanel)
    btnBuy:SetSize(btnBuyW, btnBuyH)
    btnBuy:SetPos(btnBuyX, btnBuyY)
    btnBuy:SetTxt("Acheter")
    btnBuy:SetColor(Color(122, 64, 255))
    btnBuy:SetColorHover(Color(122, 64, 255, 200))
    btnBuy:SetRadius(R:Y(12))
    btnBuy:SetGradient(false)
    btnBuy:SetRipple(true)
    btnBuy.DoClick = function()
        local item = TRADERS._shopSelectedItem
        if not item then return end
        netstream.Start(TRADERS.Net.BuyItem, traderId, item.item_id, 1)
    end

    local function layoutDetail()
        local cw = rightW
        detailIcon:SetPos((cw - R:X(120)) * 0.5, R:Y(30))
        detailName:SetPos(0, R:Y(165))
        detailDesc:SetPos(R:X(20), R:Y(215))
        detailPrice:SetPos(0, R:Y(625 - 60 - 21 - 10 - 35))
    end

    layoutDetail()
    local noSelLabel = vgui.Create("DPanel", rightPanel)
    noSelLabel:SetSize(rightW, rightH)
    noSelLabel:SetPos(0, 0)
    noSelLabel.Paint = function(_, w, h) draw.SimpleText("Sélectionner un objet", Font:GetNamed("Poppins", "SemiBold", 32), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
    local function setDetailVisible(visible)
        detailIcon:SetVisible(visible)
        detailName:SetVisible(visible)
        detailDesc:SetVisible(visible)
        detailPrice:SetVisible(visible)
        btnBuy:SetVisible(visible)
        noSelLabel:SetVisible(not visible)
    end

    setDetailVisible(false)

    local totalItemH = 31 + #catalog * (75 + 12) - 12
    container:SetTall(R:Y(totalItemH))

    for i, item in ipairs(catalog) do
        local btn = vgui.Create("DButton", container)
        btn:SetSize(R:X(398), R:Y(75))
        btn:SetPos(R:X(18), R:Y(31 + (i - 1) * (75 + 12)))
        btn:SetText("")
        local _rowNameFont  = Font:GetNamed("Poppins", "SemiBold", 26)
        local _rowPriceFont = Font:GetNamed("Poppins", "Medium",   20)
        btn.Paint = function(_, w, h)
            local isSelected = TRADERS._shopSelectedItem and TRADERS._shopSelectedItem.item_id == item.item_id
            RNDX.Draw(R:Y(8), 0, 0, w, h, (isSelected or btn:IsHovered()) and _TR_COL_ROW_SEL or _TR_COL_ROW_NORM)
            draw.SimpleText(item.name, _rowNameFont, R:X(16), R:Y(14), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local icoS = 32
            Materials:Draw(color_white, MONEY_ICON, R:X(12), R:Y(38), R:X(icoS), R:Y(icoS), "noclamp smooth")
            draw.SimpleText(tostring(item.price), _rowPriceFont, R:X(10 + icoS + 5), R:Y(45), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        btn.DoClick = function()
            TRADERS._shopSelectedItem = item
            setDetailVisible(true)
        end
    end

    VERSE.Hook.AddNS("Traders", "VERSE::Inventory::Updated", "VERSE::Traders::ShopMoneyRefresh", function() if not IsValid(frame) then VERSE.Hook.RemoveNS("Traders", "VERSE::Inventory::Updated", "VERSE::Traders::ShopMoneyRefresh") end end)
    frame.OnRemove = function()
        VERSE.Hook.RemoveNS("Traders", "VERSE::Inventory::Updated", "VERSE::Traders::ShopMoneyRefresh")
        TRADERS._shopFrame = nil
        TRADERS._shopSelectedItem = nil
    end
end

netstream.Hook(TRADERS.Net.OpenShop, function(traderId, traderName, catalog) TRADERS:OpenShopUI(traderId, traderName, catalog) end)