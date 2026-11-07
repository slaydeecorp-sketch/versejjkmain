local TRADERS = VERSE.Traders
local INV = VERSE.Inventory
if not TRADERS or not INV then return end
local R = VERSE.Responsive
local Materials = VERSE.Materials
local Font = VERSE.Fonts

local MONEY_ICON = "verse/inventory/items/money_bag.png"
Materials:SetAlias("traders_admin_background", "verse/traders/main_background")

TRADERS._adminFrame = nil
TRADERS._adminTraders = TRADERS._adminTraders or {}
TRADERS._adminCatalog = TRADERS._adminCatalog or {}
TRADERS._adminCatalogId = nil
TRADERS._adminSelectedId = nil
TRADERS._adminAddingItem = false

-- ─── Couleurs Paint pré-allouées ─────────────────────────────────────────────
local _TA_COL_FRAME_BG          = Color(255, 255, 255, 235)
local _TA_COL_FRAME_OUT         = Color(50,  50,  50,  255)
local _TA_COL_CLOSE_HOV         = Color(50,  50,  50,  225)
local _TA_COL_CLOSE_BG          = Color(50,  50,  50,  255)
local _TA_COL_CLOSE_X_DIM       = Color(255, 255, 255, 180)
local _TA_COL_SIDE_BG           = Color(65,  65,  65,  150)
local _TA_COL_RIGHT_BG          = Color(70,  44,  101, 180)
local _TA_COL_SBAR_GRIP         = Color(255, 255, 255, 30)
local _TA_COL_NOSEL_TEXT        = Color(200, 200, 200, 255)
local _TA_COL_LABEL_TEXT        = Color(180, 180, 180, 255)
local _TA_COL_PICKER_TITLE      = Color(200, 200, 200, 255)
local _TA_COL_SLOT_HOV          = Color(255, 255, 255, 40)
local _TA_COL_SLOT_NRM          = Color(255, 255, 255, 15)
local _TA_COL_ROW_BG            = Color(255, 255, 255, 10)
local _TA_COL_PRICE_GOLD        = Color(255, 220, 60,  255)
local _TA_COL_BTN_HOV           = Color(255, 255, 255, 20)
local _TA_COL_BTN_NRM           = Color(255, 255, 255, 10)
local _TA_COL_TRADER_SEL        = Color(122, 64,  255, 60)
local _TA_COL_TRADER_SUB        = Color(160, 160, 170, 255)

netstream.Hook(TRADERS.Net.AdminList, function(traderList)
    TRADERS._adminTraders = traderList or {}
    hook.Run("VERSE::Traders::AdminUpdated")
end)

netstream.Hook(TRADERS.Net.AdminSyncItems, function(traderId, catalog)
    TRADERS._adminCatalog = catalog or {}
    TRADERS._adminCatalogId = tonumber(traderId)
    hook.Run("VERSE::Traders::AdminCatalogUpdated")
end)

function TRADERS:OpenAdminPanel()
    if IsValid(self._adminFrame) then self._adminFrame:Remove() end
    netstream.Start(TRADERS.Net.AdminRequest)

    local frameW = R:X(1010)
    local frameH = R:Y(797)

    local frame = vgui.Create("MantleFrame")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("")
    frame:SetAlphaBackground(false)
    frame:DisableCloseBtn()
    self._adminFrame = frame
    self._adminSelectedId = nil
    self._adminAddingItem = false

    local _frameTitleFont = Font:GetNamed("Poppins", "SemiBold", 48)
    frame.Paint = function(_, w, h)
        Materials:DrawDuplicate(_TA_COL_FRAME_BG, "traders_admin_background", 0, 0, w, h)
        RNDX.DrawOutlined(R:Y(15), R:X(28), R:Y(14), R:X(963), R:Y(755), _TA_COL_FRAME_OUT, 3)
        draw.SimpleText("Gestion", _frameTitleFont, frameW * 0.5 + R:X(20), R:Y(60), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local btnClose = vgui.Create("DButton", frame)
    btnClose:SetSize(R:X(42), R:Y(42))
    btnClose:SetPos(R:X(1010 - 42 - 52), R:Y(34))
    btnClose:SetText("")
    local _closeBtnFont = Font:GetNamed("Poppins", "Bold", 22)
    btnClose.Paint = function(_, w, h)
        local hovered = btnClose:IsHovered()
        RNDX.Draw(R:Y(21), 0, 0, w, h, hovered and _TA_COL_CLOSE_HOV or _TA_COL_CLOSE_BG)
        draw.SimpleText("X", _closeBtnFont, w * 0.5, h * 0.5, hovered and color_white or _TA_COL_CLOSE_X_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnClose.DoClick = function()
        if IsValid(frame) then frame:Remove() end
    end

    local sideW = R:X(300)
    local contentX = R:X(76)
    local contentY = R:Y(111)
    local contentH = R:Y(625)

    local sidePanel = vgui.Create("DPanel", frame)
    sidePanel:SetPos(contentX, contentY)
    sidePanel:SetSize(sideW, contentH)
    sidePanel.Paint = function(_, w, h)
        RNDX.Draw(R:Y(10), 0, 0, w, h, _TA_COL_SIDE_BG)
    end

    local createBar = vgui.Create("DPanel", sidePanel)
    createBar:SetPos(R:X(10), R:Y(10))
    createBar:SetSize(sideW - R:X(20), R:Y(40))
    createBar.Paint = function() end

    local btnCreateNew = vgui.Create("MantleBtn", createBar)
    btnCreateNew:SetSize(sideW - R:X(20), R:Y(40))
    btnCreateNew:SetPos(0, 0)
    btnCreateNew:SetTxt("+ Créer un marchand")
    btnCreateNew:SetColor(Color(50, 130, 80))
    btnCreateNew:SetColorHover(Color(60, 150, 95))
    btnCreateNew:SetRadius(R:Y(8))
    btnCreateNew:SetGradient(false)
    btnCreateNew:SetRipple(true)
    btnCreateNew.DoClick = function()
        Derma_StringRequest("Créer un marchand", "Entrez le nom :", "Trader", function(name)
            Derma_StringRequest("Modèle", "Entrez le chemin du modèle :", "models/humans/group01/male_01.mdl", function(model)
                netstream.Start(TRADERS.Net.AdminCreate, name, model)
            end)
        end)
    end

    local traderScroll = vgui.Create("DScrollPanel", sidePanel)
    traderScroll:SetPos(R:X(8), R:Y(60))
    traderScroll:SetSize(sideW - R:X(16), contentH - R:Y(68))

    local tsbar = traderScroll:GetVBar()
    tsbar:SetWide(R:X(4))
    tsbar.Paint = function() end
    tsbar.btnUp.Paint = function() end
    tsbar.btnDown.Paint = function() end
    tsbar.btnGrip.Paint = function(_, w, h) RNDX.Draw(R:Y(2), 0, 0, w, h, _TA_COL_SBAR_GRIP) end

    local rightX = contentX + sideW + R:X(12)
    local rightW = R:X(1010 - 76 - 76) - sideW - R:X(12)

    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:SetPos(rightX, contentY)
    rightPanel:SetSize(rightW, contentH)
    rightPanel.Paint = function(_, w, h)
        RNDX.Draw(R:Y(10), 0, 0, w, h, _TA_COL_RIGHT_BG)
    end

    local noSelLabel = vgui.Create("DPanel", rightPanel)
    noSelLabel:SetSize(rightW, contentH)
    noSelLabel:SetPos(0, 0)
    local _noSelFont = Font:GetNamed("Poppins", "SemiBold", 28)
    noSelLabel.Paint = function(_, w, h)
        draw.SimpleText("Sélectionner un marchand", _noSelFont, w * 0.5, h * 0.5, _TA_COL_NOSEL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local editContainer = vgui.Create("DPanel", rightPanel)
    editContainer:SetPos(R:X(16), R:Y(16))
    editContainer:SetSize(rightW - R:X(32), contentH - R:Y(32))
    editContainer.Paint = function() end

    local editNameLabel = vgui.Create("DPanel", editContainer)
    editNameLabel:SetPos(0, 0)
    editNameLabel:SetSize(R:X(200), R:Y(20))
    local _editLabelFont = Font:GetNamed("Poppins", "Medium", 16)
    editNameLabel.Paint = function(_, w, h)
        draw.SimpleText("Nom du NPC", _editLabelFont, 0, h * 0.5, _TA_COL_LABEL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local editNameEntry = vgui.Create("MantleEntry", editContainer)
    editNameEntry:SetPos(0, R:Y(22))
    editNameEntry:SetSize(R:X(240), R:Y(34))
    editNameEntry:SetPlaceholder("Nom...")
    editNameEntry:SetFonts(Font:GetNamed("Poppins", "Medium", 16), Font:GetNamed("Poppins", "Medium", 16))
    editNameEntry:SetTextColor(color_white)

    local editModelLabel = vgui.Create("DPanel", editContainer)
    editModelLabel:SetPos(R:X(255), 0)
    editModelLabel:SetSize(R:X(200), R:Y(20))
    editModelLabel.Paint = function(_, w, h)
        draw.SimpleText("Modèle", _editLabelFont, 0, h * 0.5, _TA_COL_LABEL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local editModelEntry = vgui.Create("MantleEntry", editContainer)
    editModelEntry:SetPos(R:X(255), R:Y(22))
    editModelEntry:SetSize(R:X(300), R:Y(34))
    editModelEntry:SetPlaceholder("models/...")
    editModelEntry:SetFonts(Font:GetNamed("Poppins", "Medium", 16), Font:GetNamed("Poppins", "Medium", 16))
    editModelEntry:SetTextColor(color_white)

    local btnSave = vgui.Create("MantleBtn", editContainer)
    btnSave:SetPos(0, R:Y(66))
    btnSave:SetSize(R:X(140), R:Y(36))
    btnSave:SetTxt("Sauvegarder")
    btnSave:SetColor(Color(122, 64, 255))
    btnSave:SetColorHover(Color(140, 80, 255))
    btnSave:SetRadius(R:Y(8))
    btnSave:SetGradient(false)
    btnSave:SetRipple(true)
    btnSave.DoClick = function()
        local tid = TRADERS._adminSelectedId
        if not tid then return end
        netstream.Start(TRADERS.Net.AdminUpdate, tid, {
            name = editNameEntry:GetValue(),
            model = editModelEntry:GetValue(),
        })
    end

    local btnSavePos = vgui.Create("MantleBtn", editContainer)
    btnSavePos:SetPos(R:X(150), R:Y(66))
    btnSavePos:SetSize(R:X(170), R:Y(36))
    btnSavePos:SetTxt("Sauvegarder position")
    btnSavePos:SetColor(Color(70, 90, 130))
    btnSavePos:SetColorHover(Color(85, 105, 150))
    btnSavePos:SetRadius(R:Y(8))
    btnSavePos:SetGradient(false)
    btnSavePos:SetRipple(true)
    btnSavePos.DoClick = function()
        local tid = TRADERS._adminSelectedId
        if not tid then return end
        netstream.Start(TRADERS.Net.AdminSavePos, tid)
    end

    local btnDelete = vgui.Create("MantleBtn", editContainer)
    btnDelete:SetPos(R:X(330), R:Y(66))
    btnDelete:SetSize(R:X(120), R:Y(36))
    btnDelete:SetTxt("Supprimer")
    btnDelete:SetColor(Color(180, 50, 50))
    btnDelete:SetColorHover(Color(200, 65, 65))
    btnDelete:SetRadius(R:Y(8))
    btnDelete:SetGradient(false)
    btnDelete:SetRipple(true)
    btnDelete.DoClick = function()
        local tid = TRADERS._adminSelectedId
        if not tid then return end
        Derma_Query("Supprimer le marchand ?", "Confirmation", "Oui", function()
            netstream.Start(TRADERS.Net.AdminDelete, tid)
            TRADERS._adminSelectedId = nil
        end, "Non", function() end)
    end

    local catalogY = R:Y(120)
    local catalogLabel = vgui.Create("DPanel", editContainer)
    catalogLabel:SetPos(0, catalogY)
    catalogLabel:SetSize(R:X(200), R:Y(24))
    local _catalogLabelFont = Font:GetNamed("Poppins", "SemiBold", 20)
    catalogLabel.Paint = function(_, w, h)
        draw.SimpleText("Catalogue", _catalogLabelFont, 0, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local btnAddItem = vgui.Create("MantleBtn", editContainer)
    btnAddItem:SetPos(R:X(170), catalogY)
    btnAddItem:SetSize(R:X(140), R:Y(24))
    btnAddItem:SetTxt("+ Ajouter")
    btnAddItem:SetColor(Color(50, 130, 80))
    btnAddItem:SetColorHover(Color(60, 150, 95))
    btnAddItem:SetRadius(R:Y(6))
    btnAddItem:SetGradient(false)
    btnAddItem:SetRipple(true)
    btnAddItem.DoClick = function()
        TRADERS._adminAddingItem = not TRADERS._adminAddingItem
        hook.Run("VERSE::Traders::AdminCatalogUpdated")
    end

    local catalogScroll = vgui.Create("DScrollPanel", editContainer)
    catalogScroll:SetPos(0, catalogY + R:Y(32))
    catalogScroll:SetSize(editContainer:GetWide(), contentH - R:Y(32) - catalogY - R:Y(48))

    local csbar = catalogScroll:GetVBar()
    csbar:SetWide(R:X(4))
    csbar.Paint = function() end
    csbar.btnUp.Paint = function() end
    csbar.btnDown.Paint = function() end
    csbar.btnGrip.Paint = function(_, w, h) RNDX.Draw(R:Y(2), 0, 0, w, h, _TA_COL_SBAR_GRIP) end

    local pickerPanel = vgui.Create("DPanel", editContainer)
    pickerPanel:SetPos(0, catalogY + R:Y(32))
    pickerPanel:SetSize(editContainer:GetWide(), contentH - R:Y(32) - catalogY - R:Y(48))
    pickerPanel.Paint = function() end
    pickerPanel:SetVisible(false)

    local pickerTitle = vgui.Create("DPanel", pickerPanel)
    pickerTitle:SetPos(0, 0)
    pickerTitle:SetSize(pickerPanel:GetWide(), R:Y(30))
    local _pickerTitleFont = Font:GetNamed("Poppins", "Medium", 16)
    pickerTitle.Paint = function(_, w, h)
        draw.SimpleText("Sélectionner un objet à ajouter :", _pickerTitleFont, 0, h * 0.5, _TA_COL_PICKER_TITLE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local pickerScroll = vgui.Create("DScrollPanel", pickerPanel)
    pickerScroll:SetPos(0, R:Y(34))
    pickerScroll:SetSize(pickerPanel:GetWide(), pickerPanel:GetTall() - R:Y(34))

    local psbar = pickerScroll:GetVBar()
    psbar:SetWide(R:X(4))
    psbar.Paint = function() end
    psbar.btnUp.Paint = function() end
    psbar.btnDown.Paint = function() end
    psbar.btnGrip.Paint = function(_, w, h) RNDX.Draw(R:Y(2), 0, 0, w, h, _TA_COL_SBAR_GRIP) end

    local COLS = 5
    local SLOT_W = R:X(95)
    local SLOT_H = R:Y(95)
    local SLOT_GAP = R:X(8)

    local sortedItems = {}
    for id, def in pairs(INV.Items) do
        if id ~= INV.CurrencyItemID then
            table.insert(sortedItems, { id = id, def = def })
        end
    end
    table.sort(sortedItems, function(a, b) return (a.def.name or a.id) < (b.def.name or b.id) end)

    local gridRows = math.ceil(#sortedItems / COLS)
    local gridContainer = vgui.Create("DPanel", pickerScroll)
    gridContainer:Dock(TOP)
    gridContainer:SetTall(gridRows * (SLOT_H + SLOT_GAP))
    gridContainer.Paint = function() end

    for i, entry in ipairs(sortedItems) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)

        local slot = vgui.Create("DButton", gridContainer)
        slot:SetSize(SLOT_W, SLOT_H)
        slot:SetPos(col * (SLOT_W + SLOT_GAP), row * (SLOT_H + SLOT_GAP))
        slot:SetText("")
        slot:SetTooltip(entry.def.name or entry.id)

        local rarityColor = INV:GetRarityColor(entry.def.rarity or "common")
        local icon = entry.def.icon or ""

        local _slotNameFont = Font:GetNamed("Poppins", "Bold", 16)
        local _slotDisplayName = entry.def.name or entry.id
        if #_slotDisplayName > 12 then _slotDisplayName = string.sub(_slotDisplayName, 1, 11) .. "." end
        slot.Paint = function(_, w, h)
            local hovered = slot:IsHovered()
            RNDX.Draw(R:Y(8), 0, 0, w, h, hovered and _TA_COL_SLOT_HOV or _TA_COL_SLOT_NRM)

            if icon ~= "" then
                local icoS = R:X(48)
                Materials:Draw(color_white, icon, (w - icoS) * 0.5, R:Y(8), icoS, icoS, "noclamp smooth")
            end

            draw.SimpleText(_slotDisplayName, _slotNameFont, w * 0.5, h - R:Y(14), rarityColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        slot.DoClick = function()
            local tid = TRADERS._adminSelectedId
            if not tid then return end
            Derma_StringRequest("Prix", "Indiquez le prix pour " .. (entry.def.name or entry.id) .. ":", "100", function(priceStr)
                local price = tonumber(priceStr) or 0
                if price < 0 then price = 0 end
                netstream.Start(TRADERS.Net.AdminAddItem, tid, entry.id, price, 0)
                TRADERS._adminAddingItem = false
                hook.Run("VERSE::Traders::AdminCatalogUpdated")
            end)
        end
    end

    local function setEditVisible(visible)
        editContainer:SetVisible(visible)
        noSelLabel:SetVisible(not visible)
    end
    setEditVisible(false)

    local function refreshCatalogList()
        catalogScroll:Clear()

        local showPicker = TRADERS._adminAddingItem
        catalogScroll:SetVisible(not showPicker)
        pickerPanel:SetVisible(showPicker)
        btnAddItem:SetTxt(showPicker and "Retour" or "+ Ajouter")

        local catalog = TRADERS._adminCatalog or {}
        for i, item in ipairs(catalog) do
            local row = vgui.Create("DPanel", catalogScroll)
            row:Dock(TOP)
            row:SetTall(R:Y(44))
            row:DockMargin(0, 0, 0, R:Y(4))

            local rarityColor = INV:GetRarityColor(item.rarity)
            local icon = item.icon or ""

            row.Paint = function(_, w, h)
                RNDX.Draw(R:Y(8), 0, 0, w, h, _TA_COL_ROW_BG)
            end

            local iconPanel = vgui.Create("DPanel", row)
            iconPanel:Dock(LEFT)
            iconPanel:SetWide(R:X(40))
            iconPanel:DockMargin(R:X(6), R:Y(4), 0, R:Y(4))
            iconPanel.Paint = function(_, w, h)
                if icon ~= "" then
                    Materials:Draw(color_white, icon, 0, 0, w, h, "noclamp smooth")
                end
            end

            local namePanel = vgui.Create("DPanel", row)
            namePanel:Dock(LEFT)
            namePanel:SetWide(R:X(140))
            namePanel:DockMargin(R:X(8), 0, 0, 0)
            local _rowNameFont = Font:GetNamed("Poppins", "SemiBold", 16)
            namePanel.Paint = function(_, w, h)
                draw.SimpleText(item.name, _rowNameFont, 0, h * 0.5, rarityColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local pricePanel = vgui.Create("DPanel", row)
            pricePanel:Dock(LEFT)
            pricePanel:SetWide(R:X(80))
            local _rowPriceFont = Font:GetNamed("Poppins", "Medium", 16)
            pricePanel.Paint = function(_, w, h)
                local icoS = R:Y(18)
                Materials:Draw(color_white, MONEY_ICON, 0, h * 0.5 - icoS * 0.5, icoS, icoS, "noclamp smooth")
                draw.SimpleText(tostring(item.price), _rowPriceFont, icoS + R:X(4), h * 0.5, _TA_COL_PRICE_GOLD, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local editPriceEntry = vgui.Create("MantleEntry", row)
            editPriceEntry:Dock(LEFT)
            editPriceEntry:SetWide(R:X(60))
            editPriceEntry:DockMargin(R:X(4), R:Y(6), 0, R:Y(6))
            editPriceEntry:SetPlaceholder("Prix")
            editPriceEntry:SetFonts(Font:GetNamed("Poppins", "Medium", 16), Font:GetNamed("Poppins", "Medium", 16))
            editPriceEntry:SetTextColor(color_white)
            if editPriceEntry.textEntry then editPriceEntry.textEntry:SetNumeric(true) end

            local btnEditPrice = vgui.Create("MantleBtn", row)
            btnEditPrice:Dock(LEFT)
            btnEditPrice:SetWide(R:X(44))
            btnEditPrice:DockMargin(R:X(4), R:Y(6), 0, R:Y(6))
            btnEditPrice:SetTxt("Mod.")
            btnEditPrice:SetColor(Color(70, 90, 130))
            btnEditPrice:SetColorHover(Color(85, 105, 150))
            btnEditPrice:SetRadius(R:Y(4))
            btnEditPrice:SetGradient(false)
            btnEditPrice:SetRipple(true)
            btnEditPrice.DoClick = function()
                local tid = TRADERS._adminSelectedId
                if not tid then return end
                local newPrice = tonumber(editPriceEntry:GetValue())
                if not newPrice or newPrice < 0 then return end
                netstream.Start(TRADERS.Net.AdminUpdateItem, tid, item.item_id, newPrice)
            end

            local btnRemove = vgui.Create("MantleBtn", row)
            btnRemove:Dock(RIGHT)
            btnRemove:SetWide(R:X(44))
            btnRemove:DockMargin(0, R:Y(6), R:X(4), R:Y(6))
            btnRemove:SetTxt("X")
            btnRemove:SetColor(Color(180, 50, 50))
            btnRemove:SetColorHover(Color(200, 65, 65))
            btnRemove:SetRadius(R:Y(4))
            btnRemove:SetGradient(false)
            btnRemove:SetRipple(true)
            btnRemove.DoClick = function()
                local tid = TRADERS._adminSelectedId
                if not tid then return end
                netstream.Start(TRADERS.Net.AdminRemoveItem, tid, item.item_id)
            end
        end
    end

    local function refreshSidebar()
        traderScroll:Clear()
        local traders = TRADERS._adminTraders or {}
        for _, trader in ipairs(traders) do
            local btn = vgui.Create("DButton", traderScroll)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, R:Y(4))
            btn:SetTall(R:Y(60))
            btn:SetText("")

            local tid = trader.id
            local _btnNameFont = Font:GetNamed("Poppins", "SemiBold", 18)
            local _btnSubFont  = Font:GetNamed("Poppins", "Medium",   14)
            local _btnSubText  = "#" .. tostring(tid) .. " • " .. tostring(trader.map)
            btn.Paint = function(_, w, h)
                local isSelected = TRADERS._adminSelectedId == tid
                local isHovered = btn:IsHovered()
                local bg = isSelected and _TA_COL_TRADER_SEL or (isHovered and _TA_COL_BTN_HOV or _TA_COL_BTN_NRM)
                RNDX.Draw(R:Y(8), 0, 0, w, h, bg)

                draw.SimpleText(trader.name, _btnNameFont, R:X(12), R:Y(10), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(_btnSubText, _btnSubFont, R:X(12), R:Y(34), _TA_COL_TRADER_SUB, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            btn.DoClick = function()
                TRADERS._adminSelectedId = tid
                TRADERS._adminAddingItem = false
                setEditVisible(true)
                editNameEntry:SetValue(trader.name or "")
                editModelEntry:SetValue(trader.model or "")
                netstream.Start(TRADERS.Net.AdminGetItems, tid)
            end
        end
    end

    VERSE.Hook.AddNS("Traders", "VERSE::Traders::AdminUpdated", "VERSE::Traders::AdminPanel::Refresh", function()
        if not IsValid(frame) then
            VERSE.Hook.RemoveNS("Traders", "VERSE::Traders::AdminUpdated", "VERSE::Traders::AdminPanel::Refresh")
            return
        end
        refreshSidebar()
    end)

    VERSE.Hook.AddNS("Traders", "VERSE::Traders::AdminCatalogUpdated", "VERSE::Traders::AdminPanel::CatalogRefresh", function()
        if not IsValid(frame) then
            VERSE.Hook.RemoveNS("Traders", "VERSE::Traders::AdminCatalogUpdated", "VERSE::Traders::AdminPanel::CatalogRefresh")
            return
        end
        if TRADERS._adminCatalogId == TRADERS._adminSelectedId then
            refreshCatalogList()
        end
    end)

    frame.OnRemove = function()
        VERSE.Hook.RemoveNS("Traders", "VERSE::Traders::AdminUpdated", "VERSE::Traders::AdminPanel::Refresh")
        VERSE.Hook.RemoveNS("Traders", "VERSE::Traders::AdminCatalogUpdated", "VERSE::Traders::AdminPanel::CatalogRefresh")
        TRADERS._adminFrame = nil
        TRADERS._adminSelectedId = nil
        TRADERS._adminAddingItem = false
    end

    refreshSidebar()
end

VERSE.Commands.Add("verse_traders_admin", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not ply:IsStaff() then return end
    TRADERS:OpenAdminPanel()
end, nil, "client")
