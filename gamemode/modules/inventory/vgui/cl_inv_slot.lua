local INV = VERSE.Inventory
if not INV then return end
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local SLOT_RAD = 11
local ICON_PAD = 16
local COL = {
    outline = Color(231, 142, 255),
    drag_valid = Color(80, 255, 120, 200),
    drag_invalid = Color(255, 50, 70, 200),
    badge_bg = Color(20, 12, 35, 230),
    badge_text = Color(255, 255, 255, 240),
    equip_icon = Color(255, 255, 255, 38),
    dimmed = Color(0, 0, 0, 120),
}
-- Couleur mutée pour la bordure (évite Color() par frame selon la rareté)
local _SLOT_BORDER_COL = Color(231, 142, 255, 100)
-- Couleur de fond mutée selon hover (évite Color() par frame)
local _SLOT_BG_COL = Color(30, 15, 45, 255)

INV._heldItem = INV._heldItem or nil
INV._heldFromSlot = INV._heldFromSlot or nil
INV._heldFromEquip = INV._heldFromEquip or nil
INV._heldIsSplit = INV._heldIsSplit or false
function INV:GetHeldItem()
    return self._heldItem
end

function INV:PickUp(data, fromSlot, fromEquip, isSplit)
    self._heldItem = data and table.Copy(data) or nil
    self._heldFromSlot = fromSlot
    self._heldFromEquip = fromEquip
    self._heldIsSplit = isSplit == true
end

function INV:ClearHeld()
    self._heldItem = nil
    self._heldFromSlot = nil
    self._heldFromEquip = nil
    self._heldIsSplit = false
end

function INV:ReturnHeld()
    if self._heldItem then self:RequestSync() end
    self:ClearHeld()
end

local PANEL = {}
function PANEL:Init()
    self._slotIndex = 0
    self._slotData = nil
    self._isEquipSlot = false
    self._equipSlotType = nil
    self._hoverFrac = 0
    self._locked = false
    self:SetText("")
    self:SetCursor("hand")
    self:SetMouseInputEnabled(true)
end

function PANEL:SetSlot(slotIndex, isEquip, equipType)
    self._slotIndex = tonumber(slotIndex) or 0
    self._isEquipSlot = isEquip == true
    self._equipSlotType = equipType
end

function PANEL:SetSlotData(data)
    self._slotData = data
end

function PANEL:GetSlotData()
    return self._slotData
end

function PANEL:GetSlotIndex()
    return self._slotIndex
end

function PANEL:IsEquipSlot()
    return self._isEquipSlot
end

function PANEL:IsEmpty()
    return self._slotData == nil
end

function PANEL:SetLocked(locked)
    self._locked = locked == true
end

local function _S(v)
    return R and R.S and R:S(v) or v
end

function PANEL:Paint(w, h)
    local ft = FrameTime()
    local data = self._slotData
    local hovered = self:IsHovered() or self:IsChildHovered()
    local rad = _S(SLOT_RAD)
    local pad = _S(ICON_PAD)
    local isEquip = self._isEquipSlot
    local held = INV:GetHeldItem()
    local isSource = held and INV._heldFromSlot == self._slotIndex
    self._hoverFrac = math.Clamp(self._hoverFrac + (hovered and ft * 6 or -ft * 8), 0, 1)
    local borderAlpha = math.floor(Lerp(self._hoverFrac, 100, 200))
    -- Mutation de la couleur de bordure pré-allouée (évite Color() à chaque frame)
    if data then
        local rarity = INV:GetItemRarity(data.item_id)
        if rarity ~= "common" then
            local rc = INV:GetRarityColor(rarity)
            _SLOT_BORDER_COL.r, _SLOT_BORDER_COL.g, _SLOT_BORDER_COL.b = rc.r, rc.g, rc.b
        else
            _SLOT_BORDER_COL.r, _SLOT_BORDER_COL.g, _SLOT_BORDER_COL.b = 231, 142, 255
        end
    else
        _SLOT_BORDER_COL.r, _SLOT_BORDER_COL.g, _SLOT_BORDER_COL.b = 231, 142, 255
    end
    _SLOT_BORDER_COL.a = borderAlpha
    local borderCol = _SLOT_BORDER_COL

    local bgBright = math.floor(Lerp(self._hoverFrac, 0, 10))
    _SLOT_BG_COL.r = 30 + bgBright
    _SLOT_BG_COL.g = 15 + bgBright
    _SLOT_BG_COL.b = 45 + bgBright
    RNDX().Rect(0, 0, w, h):Rad(rad):Color(_SLOT_BG_COL):Draw()
    if hovered and held and not isSource then
        local canPlace = true
        if isEquip and not INV:CanEquipToSlot(held.item_id, self._slotIndex) then canPlace = false end
        local hc = canPlace and COL.drag_valid or COL.drag_invalid
        RNDX().Rect(0, 0, w, h):Rad(rad):Color(hc):Outline(1):Draw()
    else
        RNDX().Rect(0, 0, w, h):Rad(rad):Color(borderCol):Outline(1):Draw()
    end

    if isEquip then
        local cornerSize = 117
        Materials:Draw(borderCol, "inv_corner_bg", w * .5 - R:X(cornerSize) * .5, h * .5 - R:Y(cornerSize) * .5, R:X(cornerSize), R:Y(cornerSize), "noclamp smooth")
    end

    if data then
        local def = INV:GetItemDef(data.item_id)
        local icon = def and def.icon or "inv_fallback_icon"
        Materials:Draw(color_white, icon, pad, pad, w - pad * 2, h - pad * 2, "noclamp smooth")
        local rarity = INV:GetItemRarity(data.item_id)
        if rarity ~= "common" then
            local starSize = _S(10)
            local rc = INV:GetRarityColor(rarity)
            draw.SimpleText("★", "DermaDefault", w - starSize - _S(4) + starSize * 0.5, _S(4) + starSize * 0.5, rc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if data.amount and data.amount > 1 then
            local font = Font and Font.GetNamed and Font:GetNamed("Poppins", "Bold", 18) or "DermaDefault"
            local text
            local amt = data.amount
            if amt >= 1000000 then
                text = string.format("%.1fM", amt / 1000000)
            elseif amt >= 10000 then
                text = string.format("%.1fk", amt / 1000)
            else
                text = tostring(amt)
            end
            if not INV:IsInfiniteStack(data.item_id) then text = "x" .. text end
            draw.SimpleText(text, font, w - _S(8), h - _S(6), COL.badge_text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        end

        if isSource then RNDX().Rect(0, 0, w, h):Rad(rad):Color(COL.dimmed):Draw() end
        if self._locked then RNDX().Rect(0, 0, w, h):Rad(rad):Color(COL.dimmed):Draw() end
    elseif isEquip and self._equipSlotType then
        local iconAlias = INV.EquipSlotIcons[self._equipSlotType]
        if iconAlias then
            local nativeSizes = {
                [101] = {
                    w = 66,
                    h = 63
                },
                [102] = {
                    w = 48,
                    h = 57
                },
                [103] = {
                    w = 85,
                    h = 85
                },
            }

            local ns = nativeSizes[self._equipSlotType]
            local iw = _S(ns and ns.w or 64)
            local ih = _S(ns and ns.h or 64)
            Materials:Draw(COL.equip_icon, iconAlias, (w - iw) * 0.5, (h - ih) * 0.5, iw, ih, "noclamp smooth")
        end
    end
end

function PANEL:OnMousePressed(mc)
    if IsValid(INV._tooltip) then INV._tooltip:ClearData() end
    local held = INV:GetHeldItem()
    local data = self._slotData
    local slot = self._slotIndex
    local isEquip = self._isEquipSlot
    local fromSlot = INV._heldFromSlot
    local fromEquip = INV._heldFromEquip
    local isSplit = INV._heldIsSplit
    if mc == MOUSE_LEFT then
        if held then
            if fromSlot == slot then
                INV:ClearHeld()
                return
            end

            if isSplit then
                if not data then
                    if isEquip or fromEquip then return end
                    INV:RequestSplit(fromSlot, held.amount, slot)
                    INV:ClearHeld()
                elseif data.item_id == held.item_id and INV:MetadataMatch(data.metadata, held.metadata) and not isEquip and not fromEquip then
                    local maxStack = INV:GetMaxStack(data.item_id)
                    local canFit = maxStack - data.amount
                    if canFit > 0 then
                        local place = math.min(held.amount, canFit)
                        INV:RequestSplit(fromSlot, place, slot)
                        INV:ClearHeld()
                    end
                end
            else
                if not data then
                    if isEquip and not INV:CanEquipToSlot(held.item_id, slot) then return end
                    if fromEquip and not isEquip then
                        INV:RequestUnequip(fromSlot)
                    elseif not fromEquip and isEquip then
                        INV:RequestEquip(fromSlot, slot)
                    else
                        INV:RequestMove(fromSlot, slot)
                    end

                    INV:ClearHeld()
                elseif data.item_id == held.item_id and INV:MetadataMatch(data.metadata, held.metadata) and not isEquip and not fromEquip then
                    INV:RequestStack(fromSlot, slot)
                    INV:ClearHeld()
                else
                    if isEquip and not INV:CanEquipToSlot(held.item_id, slot) then return end
                    if not fromEquip and not isEquip then
                        INV:RequestMove(fromSlot, slot)
                    elseif not fromEquip and isEquip then
                        INV:RequestEquip(fromSlot, slot)
                    elseif fromEquip and not isEquip then
                        INV:RequestUnequip(fromSlot)
                    end

                    INV:ClearHeld()
                end
            end
        else
            if data then INV:PickUp(data, slot, isEquip) end
        end
    elseif mc == MOUSE_RIGHT then
        if held then
            if fromSlot == slot then
                INV:ClearHeld()
                return
            end

            if not isEquip and not fromEquip then
                if not data then
                    INV:RequestSplit(fromSlot, 1, slot)
                    held.amount = held.amount - 1
                    if held.amount <= 0 then INV:ClearHeld() end
                elseif data.item_id == held.item_id and INV:MetadataMatch(data.metadata, held.metadata) then
                    local maxStack = INV:GetMaxStack(data.item_id)
                    if data.amount < maxStack then
                        INV:RequestSplit(fromSlot, 1, slot)
                        held.amount = held.amount - 1
                        if held.amount <= 0 then INV:ClearHeld() end
                    end
                end
            end
        else
            if data and self._onRightClick then
                if self._onHoverEnd then self._onHoverEnd(self) end
                self._onRightClick(self)
            end
        end
    end
end

function PANEL:OnMouseReleased(mc)
end

function PANEL:OnCursorExited()
    if self._onHoverEnd then self._onHoverEnd(self) end
end

function PANEL:OnCursorEntered()
    if self._onHoverStart then self._onHoverStart(self) end
end

function PANEL:SetOnHoverStart(fn)
    self._onHoverStart = fn
end

function PANEL:SetOnHoverEnd(fn)
    self._onHoverEnd = fn
end

function PANEL:SetOnRightClick(fn)
    self._onRightClick = fn
end

VERSE.VGUI.RegisterNS("Inventory", "VCInvSlot", PANEL, "DButton", {
    source = "modules/inventory/vgui/cl_inv_slot.lua",
    overwrite = true,
})