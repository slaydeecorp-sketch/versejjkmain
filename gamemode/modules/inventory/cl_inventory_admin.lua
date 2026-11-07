local INV = VERSE.Inventory
if not INV then return end
local R = VERSE.Responsive
local Font = VERSE.Fonts

local GRID_COLS = 8
local GRID_ROWS = 6
local SLOT_SIZE = 80
local SLOT_GAP = 10
local EQUIP_SIZE = 70

local COL = {
    text = Color(255, 255, 255),
    text_dim = Color(160, 160, 170),
    header_bg = Color(255, 255, 255, 13),
}

local function _Font(weight, size)
    return Font and Font.GetNamed and Font:GetNamed("Poppins", weight, size) or "DermaDefault"
end

local function _S(px) return R and R.X and R:X(px) or px end

INV._adminFrame = INV._adminFrame or nil
INV._adminInv = INV._adminInv or {}
INV._adminCharId = nil
INV._adminTooltip = INV._adminTooltip or nil

netstream.Hook(INV.Net.AdminSync, function(charId, inv)
    INV._adminCharId = tonumber(charId)
    INV._adminInv = INV:NormalizeInventory(inv or {})
    hook.Run("VERSE::Inventory::AdminUpdated")
end)

local function ensureAdminTooltip(parent)
    if IsValid(INV._adminTooltip) then
        INV._adminTooltip:SetParent(parent)
        return INV._adminTooltip
    end
    INV._adminTooltip = vgui.Create("VCInvTooltip", parent)
    return INV._adminTooltip
end

local function closeAdminTooltip()
    if IsValid(INV._adminTooltip) then INV._adminTooltip:ClearData() end
end

local function closeAdminDermaMenu()
    if Mantle and Mantle.ui and IsValid(Mantle.ui.menu_derma_menu) then
        Mantle.ui.menu_derma_menu:Remove()
        Mantle.ui.menu_derma_menu = nil
    end
end

function INV:OpenAdminInventory(charId, charName)
    charId = tonumber(charId)
    if not charId or charId <= 0 then return end
    if IsValid(self._adminFrame) then self._adminFrame:Remove() end

    charName = tostring(charName or "Personnage #" .. charId)

    netstream.Start(INV.Net.AdminView, charId)

    local frame = vgui.Create("MantleFrame")
    frame:SetSize(_S(960), _S(750))
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("Inventaire : " .. charName)
    frame:SetCenterTitle("Inventaire Admin")
    self._adminFrame = frame

    local adminCharId = charId
    local slotPanels = {}
    local equipPanels = {}

    local function showAdminContextMenu(slotPanel)
        local data = slotPanel:GetSlotData()
        if not data then return end
        local slotIdx = slotPanel:GetSlotIndex()

        closeAdminDermaMenu()
        closeAdminTooltip()

        timer.Simple(0, function()
            if not IsValid(frame) then return end
            local dm = Mantle.ui.derma_menu()
            local def = INV:GetItemDef(data.item_id)
            local itemName = def and def.name or data.item_id

            dm:AddOption("Retirer : " .. itemName, function()
                netstream.Start(INV.Net.AdminRemove, adminCharId, slotIdx)
            end)

            if data.amount and data.amount > 1 then
                dm:AddOption("Retirer x1", function()
                    netstream.Start(INV.Net.AdminRemove, adminCharId, slotIdx)
                end)
            end
        end)
    end

    local function tryShowAdminTooltip(s)
        if Mantle and Mantle.ui and IsValid(Mantle.ui.menu_derma_menu) then return end
        local d = s:GetSlotData()
        if d and IsValid(frame) then
            ensureAdminTooltip(frame):SetSlotData(d)
        end
    end

    local function setupAdminSlot(slot)
        slot:SetOnHoverStart(function(s) tryShowAdminTooltip(s) end)
        slot:SetOnHoverEnd(function() closeAdminTooltip() end)
        slot:SetOnRightClick(function(s) showAdminContextMenu(s) end)

        slot.OnMousePressed = function(s, mc)
            if mc == MOUSE_RIGHT then
                local data = s:GetSlotData()
                if data and s._onRightClick then
                    if s._onHoverEnd then s._onHoverEnd(s) end
                    s._onRightClick(s)
                end
            end
        end

        local origThink = slot.Think
        slot.Think = function(s)
            if origThink then origThink(s) end
            local menuOpen = Mantle and Mantle.ui and IsValid(Mantle.ui.menu_derma_menu)
            local hovered = s:IsHovered() and s:GetSlotData()
            if hovered and s._menuWasOpen and not menuOpen then
                tryShowAdminTooltip(s)
            end
            s._menuWasOpen = menuOpen
        end
    end

    local topBar = vgui.Create("DPanel", frame)
    topBar:Dock(TOP)
    topBar:SetTall(_S(50))
    topBar:DockMargin(_S(12), _S(5), _S(12), _S(5))
    topBar.Paint = function() end

    local itemCombo = vgui.Create("MantleComboBox", topBar)
    itemCombo:Dock(LEFT)
    itemCombo:SetWide(_S(260))
    itemCombo:SetPlaceholder("Sélectionner un item...")
    itemCombo:SetFonts(_Font("Medium", 14), _Font("Medium", 14), _Font("Medium", 14))

    local sortedItems = {}
    for id, def in pairs(INV.Items) do
        table.insert(sortedItems, { id = id, name = def.name or id })
    end
    table.sort(sortedItems, function(a, b) return a.name < b.name end)
    for _, item in ipairs(sortedItems) do
        itemCombo:AddChoice(item.name, item.id)
    end

    local amountEntry = vgui.Create("MantleEntry", topBar)
    amountEntry:Dock(LEFT)
    amountEntry:SetWide(_S(80))
    amountEntry:DockMargin(_S(8), 0, 0, 0)
    amountEntry:SetPlaceholder("Qté")
    amountEntry:SetFonts(_Font("Medium", 14), _Font("Medium", 14))
    amountEntry:SetTextColor(COL.text)
    if amountEntry.textEntry then
        amountEntry.textEntry:SetNumeric(true)
    end

    local btnGive = vgui.Create("MantleBtn", topBar)
    btnGive:Dock(LEFT)
    btnGive:SetWide(_S(110))
    btnGive:DockMargin(_S(8), 0, 0, 0)
    btnGive:SetTxt("Donner")
    btnGive:SetColor(Color(50, 130, 80))
    btnGive:SetColorHover(Color(60, 150, 95))
    btnGive:SetRadius(_S(8))
    btnGive:SetGradient(false)
    btnGive:SetRipple(true)
    btnGive.DoClick = function()
        local selectedItemId = itemCombo:GetSelectedData()
        if not selectedItemId or selectedItemId == "" then return end
        local amt = tonumber(amountEntry:GetValue()) or 1
        if amt < 1 then amt = 1 end
        netstream.Start(INV.Net.AdminGive, adminCharId, selectedItemId, amt)
    end

    local btnRefresh = vgui.Create("MantleBtn", topBar)
    btnRefresh:Dock(RIGHT)
    btnRefresh:SetWide(_S(100))
    btnRefresh:SetTxt("Refresh")
    btnRefresh:SetColor(Color(70, 90, 130))
    btnRefresh:SetColorHover(Color(85, 105, 150))
    btnRefresh:SetRadius(_S(8))
    btnRefresh:SetGradient(false)
    btnRefresh:SetRipple(true)
    btnRefresh.DoClick = function()
        netstream.Start(INV.Net.AdminView, adminCharId)
    end

    local _equipBarFont = _Font("SemiBold", 14)
    local equipBar = vgui.Create("DPanel", frame)
    equipBar:Dock(TOP)
    equipBar:SetTall(_S(EQUIP_SIZE + 24))
    equipBar:DockMargin(_S(12), 0, _S(12), _S(5))
    equipBar.Paint = function(_, w, h)
        draw.SimpleText("Équipement", _equipBarFont, _S(4), _S(2), COL.text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local eqSize = _S(EQUIP_SIZE)
    local eqGap = _S(12)
    local eqStartX = _S(4)
    local eqStartY = _S(22)
    local eqIdx = 0
    for name, slotId in SortedPairs(INV.EquipSlots) do
        local slot = vgui.Create("VCInvSlot", equipBar)
        slot:SetPos(eqStartX + eqIdx * (eqSize + eqGap), eqStartY)
        slot:SetSize(eqSize, eqSize)
        slot:SetSlot(slotId, true, slotId)
        slot:SetSlotData(nil)
        setupAdminSlot(slot)
        equipPanels[slotId] = slot
        eqIdx = eqIdx + 1
    end

    local gridPanel = vgui.Create("DPanel", frame)
    gridPanel:Dock(FILL)
    gridPanel:DockMargin(_S(12), _S(5), _S(12), _S(12))
    gridPanel.Paint = function() end

    local slotS = _S(SLOT_SIZE)
    local slotG = _S(SLOT_GAP)
    local slotCount = INV:GetSlotCount()

    for row = 0, GRID_ROWS - 1 do
        for col = 0, GRID_COLS - 1 do
            local idx = row * GRID_COLS + col + 1
            if idx > slotCount then break end

            local sx = col * (slotS + slotG)
            local sy = row * (slotS + slotG)

            local slot = vgui.Create("VCInvSlot", gridPanel)
            slot:SetPos(sx, sy)
            slot:SetSize(slotS, slotS)
            slot:SetSlot(idx, false)
            slot:SetSlotData(nil)
            setupAdminSlot(slot)
            slotPanels[idx] = slot
        end
    end

    local function refreshSlots()
        local inv = INV._adminInv or {}
        for idx, panel in pairs(slotPanels) do
            if IsValid(panel) then panel:SetSlotData(inv[idx]) end
        end
        for slotId, panel in pairs(equipPanels) do
            if IsValid(panel) then panel:SetSlotData(inv[slotId]) end
        end
    end

    VERSE.Hook.AddNS("Inventory", "VERSE::Inventory::AdminUpdated", "VERSE::Inventory::AdminUI::Refresh", function()
        if not IsValid(frame) then
            hook.Remove("VERSE::Inventory::AdminUpdated", "VERSE::Inventory::AdminUI::Refresh")
            return
        end
        refreshSlots()
    end)

    frame.OnRemove = function()
        VERSE.Hook.RemoveNS("Inventory", "VERSE::Inventory::AdminUpdated", "VERSE::Inventory::AdminUI::Refresh")
        closeAdminDermaMenu()
        closeAdminTooltip()
        INV._adminFrame = nil
    end

    if INV._adminCharId == adminCharId then
        refreshSlots()
    end
end
