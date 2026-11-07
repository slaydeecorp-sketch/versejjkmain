local INV = VERSE.Inventory
if not INV then return end
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local GRID_COLS = 8
local GRID_ROWS = 6
local SLOT_SIZE = 72
local SLOT_GAP = 12
local EQUIP_SIZE = 133
local COL = {
    bg_overlay = Color(0, 0, 0, 178),
    inner_glow = Color(231, 142, 255, 48),
    text = Color(255, 255, 255),
    text_placeholder = Color(158, 163, 176),
    text_label = Color(140, 140, 140),
    btn_bg = Color(255, 255, 255, 28),
    btn_bg_hover = Color(255, 255, 255, 56),
    btn_bg_active = Color(255, 255, 255, 74),
    header_bg = Color(255, 255, 255, 13),
    search_bg = Color(255, 255, 255, 28),
    equip_bg = Color(217, 74, 255, 54),
    equip_border = Color(231, 142, 255),
    equip_dash = Color(217, 74, 255, 196),
    tooltip_bg = Color(78, 78, 78, 178),
    rare_color = Color(58, 114, 255),
}

-- ─── Couleurs pré-allouées pour l'UI inventaire (évite Color() par frame) ─────
local _INV_COL_POPUP_BG       = Color(0,   0,   0,   160)
local _INV_COL_POPUP_INNER    = Color(22,  16,  34,  252)
local _INV_COL_POPUP_BORD     = Color(231, 142, 255, 25)
local _INV_COL_MINUS_NORM     = Color(36,  28,  52,  255)
local _INV_COL_MINUS_HOV      = Color(50,  38,  68,  255)
local _INV_COL_ACCENT_TXT     = Color(231, 142, 255, 255)
local _INV_COL_ENTRY_BG       = Color(36,  28,  52,  255)
local _INV_COL_SLIDER_BG      = Color(36,  28,  52,  255)
local _INV_COL_SLIDER_FILL    = Color(138, 43,  226, 255)
local _INV_COL_SLIDER_KNOB    = Color(210, 140, 255, 255)
local _INV_COL_PRESET_ACT     = Color(138, 43,  226, 255)
local _INV_COL_PRESET_HOV     = Color(50,  38,  68,  255)
local _INV_COL_PRESET_NORM    = Color(36,  28,  52,  255)
local _INV_COL_PRESET_TXT_IN  = Color(180, 160, 210, 255)
local _INV_COL_CANCEL_HOV     = Color(50,  38,  68,  255)
local _INV_COL_CANCEL_NORM    = Color(36,  28,  52,  255)
local _INV_COL_CANCEL_TXT     = Color(160, 150, 180, 255)
local _INV_COL_CONFIRM_HOV    = Color(160, 70,  255, 255)
local _INV_COL_CONFIRM_NORM   = Color(138, 43,  226, 255)
local _INV_COL_FRAME_BG       = Color(255, 255, 255, 0)   -- .a muté (animation)
local _INV_COL_DRAG_ICON      = Color(255, 255, 255, 220)
local _INV_COL_DRAG_AMT       = Color(255, 255, 255, 240)
local _INV_COL_CLOSE_BTN      = Color(255, 255, 255, 0)   -- .a muté
local _INV_COL_WALLET_BG      = Color(180, 140, 20,  18)
local _INV_COL_WALLET_BORD    = Color(255, 215, 80,  55)
local _INV_COL_WALLET_TXT     = Color(255, 215, 80,  230)
local _INV_COL_HOLD_ICON_FONT = nil  -- lazy-init font pour held item
-- ─────────────────────────────────────────────────────────────────────────────

INV._uiFrame = INV._uiFrame or nil
INV._tooltip = INV._tooltip or nil
VERSE.Hook.AddNS("Inventory", "InitPostEntity", "VERSE::InitPostEntity::Inventory", function()
    Materials:SetAlias("inv_background", "verse/inventory/main_background")
    Materials:SetAlias("inv_icon_bag", "verse/inventory/inventory_icon")
    Materials:SetAlias("inv_icon_search", "verse/inventory/search_icon")
    Materials:SetAlias("inv_icon_close", "verse/inventory/close_icon")
    Materials:SetAlias("inv_slot_weapon", "verse/inventory/arme_slot_icon")
    Materials:SetAlias("inv_slot_ring", "verse/inventory/bague_slot_icon")
    Materials:SetAlias("inv_slot_talisman", "verse/inventory/talisman_slot_icon")
    Materials:SetAlias("inv_slot_outfit", "verse/inventory/outfit_slot_icon")
    Materials:SetAlias("inv_fallback_icon", "verse/inventory/items/fallback_icon")
    Materials:SetAlias("inv_corner_bg", "verse/inventory/corner_background")
end)

local function _Font(variant, size)
    if Font and Font.GetNamed then return Font:GetNamed("Poppins", variant, size) end
    return "DermaDefault"
end

local function ensureTooltip(parent)
    if IsValid(INV._tooltip) then
        INV._tooltip:SetParent(parent)
        return INV._tooltip
    end

    INV._tooltip = vgui.Create("VCInvTooltip", parent)
    return INV._tooltip
end

local function closeDermaMenu()
    if Mantle and Mantle.ui and IsValid(Mantle.ui.menu_derma_menu) then
        Mantle.ui.menu_derma_menu:Remove()
        Mantle.ui.menu_derma_menu = nil
    end
end

local function closeTooltip()
    if IsValid(INV._tooltip) then INV._tooltip:ClearData() end
end

local _amountPopup = nil
local function openAmountPopup(title, maxAmount, onConfirm)
    if IsValid(_amountPopup) then _amountPopup:Remove() end

    local pad = R:X(20)
    local pw, ph = R:X(300), R:Y(260)

    local frame = vgui.Create("DFrame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    if IsValid(frame.btnMinim) then frame.btnMinim:SetVisible(false) end
    if IsValid(frame.btnMaxim) then frame.btnMaxim:SetVisible(false) end
    if IsValid(frame.btnClose) then frame.btnClose:SetVisible(false) end
    _amountPopup = frame

    local _value = 1
    local _closing = false
    local textEntry

    local function closePopup(confirm)
        if _closing then return end
        _closing = true
        local val = _value
        frame:Remove()
        _amountPopup = nil
        if confirm and onConfirm then onConfirm(val) end
    end

    local function setValue(n)
        _value = math.Clamp(math.floor(tonumber(n) or 1), 1, maxAmount)
        if IsValid(textEntry) and not textEntry:HasFocus() then
            textEntry:SetText(tostring(_value))
        end
    end

    frame.Paint = function(s, w, h)
        RNDX().Rect(0, 0, w, h):Color(_INV_COL_POPUP_BG):Draw()

        local cx = math.floor((w - pw) * 0.5)
        local cy = math.floor((h - ph) * 0.5)
        RNDX().Rect(cx, cy, pw, ph):Rad(R:X(12)):Color(_INV_COL_POPUP_INNER):Draw()
        RNDX().Rect(cx, cy, pw, ph):Rad(R:X(12)):Color(_INV_COL_POPUP_BORD):Outline(1):Draw()

        draw.SimpleText(title, _Font("Bold", 18), w * 0.5, cy + R:Y(20), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        surface.SetDrawColor(231, 142, 255, 40)
        surface.DrawRect(cx + pad, cy + R:Y(38), pw - pad * 2, 1)
    end
    frame.OnMousePressed = function(s, mc)
        local mx, my = s:CursorPos()
        local cx = math.floor((ScrW() - pw) * 0.5)
        local cy = math.floor((ScrH() - ph) * 0.5)
        if mx < cx or mx > cx + pw or my < cy or my > cy + ph then
            closePopup(false)
        end
    end

    local cx = math.floor((ScrW() - pw) * 0.5)
    local cy = math.floor((ScrH() - ph) * 0.5)

    local rowY = cy + R:Y(50)
    local rowH = R:Y(36)
    local pmW = R:X(36)
    local inputW = pw - pad * 2 - pmW * 2 - R:X(12)

    local minusBtn = vgui.Create("DButton", frame)
    minusBtn:SetPos(cx + pad, rowY)
    minusBtn:SetSize(pmW, rowH)
    minusBtn:SetText("")
    minusBtn.Paint = function(s, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:X(6)):Color(s:IsHovered() and _INV_COL_MINUS_HOV or _INV_COL_MINUS_NORM):Draw()
        draw.SimpleText("-", _Font("Bold", 22), w * 0.5, h * 0.5 - 1, _INV_COL_ACCENT_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    minusBtn.DoClick = function()
        setValue(_value - (input.IsShiftDown() and 10 or 1))
    end
    minusBtn.DoRightClick = function()
        setValue(_value - 100)
    end

    textEntry = vgui.Create("DTextEntry", frame)
    textEntry:SetPos(cx + pad + pmW + R:X(4), rowY)
    textEntry:SetSize(inputW, rowH)
    textEntry:SetFont(_Font("Bold", 18))
    textEntry:SetTextColor(color_white)
    textEntry:SetCursorColor(Color(231, 142, 255))
    textEntry:SetHighlightColor(Color(138, 43, 226, 120))
    textEntry:SetPaintBackground(false)
    textEntry:SetNumeric(true)
    textEntry:SetUpdateOnType(true)
    textEntry:SetDrawLanguageID(false)
    textEntry:SetText("1")
    textEntry.Paint = function(s, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:X(6)):Color(_INV_COL_ENTRY_BG):Draw()
        s:DrawTextEntryText(s:GetTextColor(), s:GetHighlightColor(), s:GetCursorColor())
    end
    timer.Simple(0, function()
        if IsValid(textEntry) then
            textEntry:RequestFocus()
            textEntry:SelectAllText()
        end
    end)
    textEntry.OnValueChange = function(s, val)
        if not s:HasFocus() then return end
        local n = tonumber(val)
        if n then _value = math.Clamp(math.floor(n), 1, maxAmount) end
    end
    textEntry.OnEnter = function(s)
        local n = tonumber(s:GetText())
        if n then _value = math.Clamp(math.floor(n), 1, maxAmount) end
        closePopup(true)
    end
    textEntry.OnLoseFocus = function(s)
        local n = tonumber(s:GetText())
        if n then _value = math.Clamp(math.floor(n), 1, maxAmount) end
        s:SetText(tostring(_value))
    end

    local plusBtn = vgui.Create("DButton", frame)
    plusBtn:SetPos(cx + pw - pad - pmW, rowY)
    plusBtn:SetSize(pmW, rowH)
    plusBtn:SetText("")
    plusBtn.Paint = function(s, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:X(6)):Color(s:IsHovered() and _INV_COL_MINUS_HOV or _INV_COL_MINUS_NORM):Draw()
        draw.SimpleText("+", _Font("Bold", 22), w * 0.5, h * 0.5 - 1, _INV_COL_ACCENT_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    plusBtn.DoClick = function()
        setValue(_value + (input.IsShiftDown() and 10 or 1))
    end
    plusBtn.DoRightClick = function()
        setValue(_value + 100)
    end

    local sliderY = rowY + rowH + R:Y(10)
    local sliderH = R:Y(20)
    local barH = R:Y(6)
    local sliderPanel = vgui.Create("DPanel", frame)
    sliderPanel:SetPos(cx + pad, sliderY)
    sliderPanel:SetSize(pw - pad * 2, sliderH)
    sliderPanel.Paint = function(s, w, h)
        local by = math.floor((h - barH) * 0.5)
        RNDX().Rect(0, by, w, barH):Rad(barH * 0.5):Color(_INV_COL_SLIDER_BG):Draw()
        local frac = maxAmount > 1 and math.Clamp((_value - 1) / (maxAmount - 1), 0, 1) or 1
        local fillW = math.max(barH, math.floor(w * frac))
        RNDX().Rect(0, by, fillW, barH):Rad(barH * 0.5):Color(_INV_COL_SLIDER_FILL):Draw()
        local knobR = R:X(7)
        local kx = math.floor(frac * (w - knobR * 2)) + knobR
        local ky = math.floor(h * 0.5)
        RNDX().Rect(kx - knobR, ky - knobR, knobR * 2, knobR * 2):Rad(knobR):Color(_INV_COL_SLIDER_KNOB):Draw()
    end
    sliderPanel._dragging = false
    sliderPanel.OnMousePressed = function(s, mc)
        if mc == MOUSE_LEFT then
            s._dragging = true
            s:MouseCapture(true)
            local mx = s:CursorPos()
            local frac = math.Clamp(mx / s:GetWide(), 0, 1)
            setValue(1 + frac * (maxAmount - 1))
        end
    end
    sliderPanel.OnMouseReleased = function(s, mc)
        if mc == MOUSE_LEFT and s._dragging then
            s._dragging = false
            s:MouseCapture(false)
        end
    end
    sliderPanel.Think = function(s)
        if s._dragging then
            local mx = s:CursorPos()
            local frac = math.Clamp(mx / s:GetWide(), 0, 1)
            setValue(1 + frac * (maxAmount - 1))
        end
    end

    local presetY = sliderY + sliderH + R:Y(8)
    local presetH = R:Y(26)
    local presets = {
        { label = "1", val = 1 },
        { label = "25%", val = math.max(1, math.floor(maxAmount * 0.25)) },
        { label = "50%", val = math.max(1, math.floor(maxAmount * 0.5)) },
        { label = "Max", val = maxAmount },
    }
    local presetGap = R:X(6)
    local presetTotalW = pw - pad * 2
    local presetBtnW = math.floor((presetTotalW - presetGap * (#presets - 1)) / #presets)

    for i, p in ipairs(presets) do
        local bx = cx + pad + (i - 1) * (presetBtnW + presetGap)
        local btn = vgui.Create("DButton", frame)
        btn:SetPos(bx, presetY)
        btn:SetSize(presetBtnW, presetH)
        btn:SetText("")
        btn.Paint = function(s, w, h)
            local hov = s:IsHovered()
            local active = (_value == p.val)
            local bg = active and _INV_COL_PRESET_ACT or (hov and _INV_COL_PRESET_HOV or _INV_COL_PRESET_NORM)
            RNDX().Rect(0, 0, w, h):Rad(R:X(5)):Color(bg):Draw()
            draw.SimpleText(p.label, _Font("Medium", 13), w * 0.5, h * 0.5, active and color_white or _INV_COL_PRESET_TXT_IN, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() setValue(p.val) end
    end

    local bbtnH = R:Y(34)
    local bbtnY = cy + ph - bbtnH - R:Y(14)
    local bbtnGap = R:X(10)
    local bbtnW = math.floor((pw - pad * 2 - bbtnGap) * 0.5)

    local cancelBtn = vgui.Create("DButton", frame)
    cancelBtn:SetPos(cx + pad, bbtnY)
    cancelBtn:SetSize(bbtnW, bbtnH)
    cancelBtn:SetText("")
    cancelBtn.Paint = function(s, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:X(8)):Color(s:IsHovered() and _INV_COL_CANCEL_HOV or _INV_COL_CANCEL_NORM):Draw()
        draw.SimpleText("Annuler", _Font("Medium", 14), w * 0.5, h * 0.5, _INV_COL_CANCEL_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    cancelBtn.DoClick = function() closePopup(false) end

    local confirmBtn = vgui.Create("DButton", frame)
    confirmBtn:SetPos(cx + pad + bbtnW + bbtnGap, bbtnY)
    confirmBtn:SetSize(bbtnW, bbtnH)
    confirmBtn:SetText("")
    confirmBtn.Paint = function(s, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:X(8)):Color(s:IsHovered() and _INV_COL_CONFIRM_HOV or _INV_COL_CONFIRM_NORM):Draw()
        draw.SimpleText("Confirmer", _Font("Medium", 14), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    confirmBtn.DoClick = function() closePopup(true) end

    frame.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then closePopup(false) end
    end
end

local function showContextMenu(slotPanel)
    local data = slotPanel:GetSlotData()
    if not data then return end
    local def = INV:GetItemDef(data.item_id)
    local slot = slotPanel:GetSlotIndex()
    local isEquip = slotPanel:IsEquipSlot()
    if not Mantle or not Mantle.ui or not Mantle.ui.derma_menu then return end

    closeDermaMenu()
    closeTooltip()

    timer.Simple(0, function()
        if not IsValid(INV._uiFrame) then return end

        local dm = Mantle.ui.derma_menu()

        if def and def.usable and not isEquip then
            dm:AddOption("Utiliser", function() INV:RequestUse(slot) end)
        end

        if isEquip then
            dm:AddOption("Déséquiper", function() INV:RequestUnequip(slot) end)
        elseif def and def.equip_slot then
            local eqId = INV.EquipSlots[def.equip_slot]
            if eqId then
                dm:AddOption("Équiper", function() INV:RequestEquip(slot, eqId) end)
            end
        end

        if data.amount and data.amount > 1 and not isEquip then
            dm:AddOption("Diviser", function()
                local half = math.ceil(data.amount / 2)
                local heldData = table.Copy(data)
                heldData.amount = half
                INV:PickUp(heldData, slot, isEquip, true)
            end)
        end

        if def and def.droppable ~= false and not isEquip then
            dm:AddOption("Jeter (x1)", function() INV:RequestDrop(slot, 1) end)
            if data.amount and data.amount > 1 then
                dm:AddOption("Jeter plusieurs...", function()
                    openAmountPopup("Jeter", data.amount, function(n)
                        INV:RequestDrop(slot, n)
                    end)
                end)
                dm:AddOption("Tout jeter", function() INV:RequestDrop(slot, data.amount) end)
            end
        end

        if not isEquip then
            dm:AddSpacer()
            dm:AddOption("Supprimer (x1)", function() INV:RequestDelete(slot, 1) end)
            if data.amount and data.amount > 1 then
                dm:AddOption("Supprimer plusieurs...", function()
                    openAmountPopup("Supprimer", data.amount, function(n)
                        INV:RequestDelete(slot, n)
                    end)
                end)
                dm:AddOption("Tout supprimer", function() INV:RequestDelete(slot) end)
            end
        end
    end)
end

local function tryShowTooltip(s)
    if INV:GetHeldItem() then return end
    if Mantle and Mantle.ui and IsValid(Mantle.ui.menu_derma_menu) then return end
    local d = s:GetSlotData()
    if d and IsValid(INV._uiFrame) then
        ensureTooltip(INV._uiFrame):SetSlotData(d)
    end
end

local function setupSlotCallbacks(slot)
    slot:SetOnHoverStart(function(s) tryShowTooltip(s) end)
    slot:SetOnHoverEnd(function() closeTooltip() end)
    slot:SetOnRightClick(function(s) showContextMenu(s) end)

    local origThink = slot.Think
    slot.Think = function(s)
        if origThink then origThink(s) end
        local menuOpen = Mantle and Mantle.ui and IsValid(Mantle.ui.menu_derma_menu)
        local hasHeld = INV:GetHeldItem() ~= nil
        local hovered = s:IsHovered() and s:GetSlotData()

        if hovered and ((s._menuWasOpen and not menuOpen) or (s._hadHeld and not hasHeld)) then
            tryShowTooltip(s)
        end

        s._menuWasOpen = menuOpen
        s._hadHeld = hasHeld
    end
end

function INV:OpenUI()
    if IsValid(self._uiFrame) then
        self._uiFrame:Remove()
        self._uiFrame = nil
    end

    local scrw, scrh = 1920, 1080
    local frame = vgui.Create("MantleFrame")
    frame:SetSize(R:XY(scrw, scrh))
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(false)
    frame:LiteMode()
    frame:SetAlphaBackground(false)
    frame:SetClosable(true)
    frame._animFrac = 0
    frame._animDir = 1
    frame._animDone = false

    local function easeOutQuart(t)
        local t1 = 1 - t
        return 1 - t1 * t1 * t1 * t1
    end

    local function easeInCubic(t)
        return t * t * t
    end

    frame.Paint = function(s, w, h)
        local ft = FrameTime()
        local speed = s._animDir == 1 and 3.5 or 5.0
        s._animFrac = math.Clamp(s._animFrac + s._animDir * ft * speed, 0, 1)

        local ease = s._animDir == 1 and easeOutQuart(s._animFrac) or easeInCubic(s._animFrac)

        local bgAlpha = math.floor(ease * 240)
        _INV_COL_FRAME_BG.a = bgAlpha
        Materials:Draw(_INV_COL_FRAME_BG, "inv_background", 0, 0, w, h, "noclamp smooth")

        if s._animDir == -1 and s._animFrac <= 0 and not s._animDone then
            s._animDone = true
            timer.Simple(0, function() if IsValid(s) then s:Remove() end end)
        end
    end

    frame.Think_Original = frame.Think
    frame.Think = function(s)
        if s.Think_Original then s:Think_Original() end

        local ease = s._animDir == 1 and easeOutQuart(s._animFrac) or easeInCubic(s._animFrac)
        s:SetAlpha(math.floor(ease * 255))

        for _, child in ipairs(s:GetChildren()) do
            if IsValid(child) and child._baseX then
                local mid = ScrW() * 0.5
                local dist = R:X(80)
                if child._baseX < mid then
                    child:SetPos(child._baseX + (1 - ease) * -dist, child._baseY)
                else
                    child:SetPos(child._baseX + (1 - ease) * dist, child._baseY)
                end
            end
        end
    end

    frame.Close = function(s)
        if s._animDir == -1 then return end
        s._animDir = -1
        closeDermaMenu()
        closeTooltip()
        INV:ClearHeld()
        for _, child in ipairs(s:GetChildren()) do
            if IsValid(child) and (child.ClassName == "DModelPanel" or child._isCharPreview) then
                child:SetVisible(false)
            end
        end
    end

    frame.PaintOver = function(s, w, h)
        local held = INV:GetHeldItem()
        if not held then return end
        local mx, my = gui.MousePos()
        local fx, fy = s:GetPos()
        local lx, ly = mx - fx, my - fy
        local iconS = R:X(64)
        local def = INV:GetItemDef(held.item_id)
        local icon = def and def.icon or "inv_fallback_icon"
        Materials:Draw(_INV_COL_DRAG_ICON, icon, lx - iconS * 0.5, ly - iconS * 0.5, iconS, iconS, "noclamp smooth")
        if held.amount and held.amount > 1 then
            if not _INV_COL_HOLD_ICON_FONT then _INV_COL_HOLD_ICON_FONT = Font and Font.GetNamed and Font:GetNamed("Poppins", "Bold", 13) or "DermaDefault" end
            draw.SimpleText(tostring(held.amount), _INV_COL_HOLD_ICON_FONT, lx + iconS * 0.3, ly + iconS * 0.3, _INV_COL_DRAG_AMT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    frame.OnRemove = function()
        INV:ReturnHeld()
        closeDermaMenu()
        closeTooltip()
        self._uiFrame = nil
        hook.Remove("VERSE::Inventory::Updated", "VERSE::Inventory::UI::Refresh")
        hook.Remove("VERSE::Inventory::Error", "VERSE::Inventory::UI::Error")
    end

    self._uiFrame = frame
    self._searchFilter = ""
    self._categoryFilter = "all"
    self._sortMode = nil
    self._slotPanels = {}
    self._equipPanels = {}
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(R:XY(39, 30))
    closeBtn:SetSize(R:XY(140, 30))
    closeBtn:SetText("")
    closeBtn:SetCursor("hand")
    closeBtn._hoverFrac = 0
    local _closeBtnFont = _Font("Medium", 20)
    closeBtn.Paint = function(s, w, h)
        local ft = FrameTime()
        s._hoverFrac = math.Clamp(s._hoverFrac + (s:IsHovered() and ft * 8 or -ft * 6), 0, 1)
        _INV_COL_CLOSE_BTN.a = math.floor(Lerp(s._hoverFrac, 200, 255))
        local iconW, iconH = R:X(27), R:Y(23)
        local iconY = (h - iconH) * 0.5
        Materials:Draw(_INV_COL_CLOSE_BTN, "inv_icon_close", 0, iconY, iconW, iconH, "noclamp smooth")
        draw.SimpleText("Fermer", _closeBtnFont, R:X(37), h * 0.5, _INV_COL_CLOSE_BTN, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    closeBtn.DoClick = function() self:CloseUI() end
    self:_BuildCharacterPanel(frame)
    self:_BuildInventoryPanel(frame)
    local tooltip = ensureTooltip(frame)
    if IsValid(tooltip) then tooltip:SetParent(frame) end

    for _, child in ipairs(frame:GetChildren()) do
        if IsValid(child) then
            local cx, cy = child:GetPos()
            child._baseX = cx
            child._baseY = cy
        end
    end

    VERSE.Hook.AddNS("Inventory", "VERSE::Inventory::Updated", "VERSE::Inventory::UI::Refresh", function() if IsValid(self._uiFrame) then self:_RefreshSlots() end end)
    VERSE.Hook.AddNS("Inventory", "VERSE::Inventory::Error", "VERSE::Inventory::UI::Error", function(code) if IsValid(self._uiFrame) then VERSE.Log:Warn("[Inventory] " .. tostring(code or "Error")) end end)
end

function INV:CloseUI()
    local fr = self._uiFrame
    if not IsValid(fr) then return end
    if fr._animDir == -1 then return end

    fr._animDir = -1
    fr._animSpeed = 5.5
    if IsValid(self._tooltip) then self._tooltip:ClearData() end
end

function INV:ToggleUI()
    if IsValid(self._uiFrame) and self._uiFrame._animDir ~= -1 then
        self:CloseUI()
    elseif not IsValid(self._uiFrame) then
        self:OpenUI()
    end
end

function INV:_BuildCharacterPanel(frame)
    local CP = VERSE.CharacterPreview
    if CP then
        local app = CP:ReadAppearance(LocalPlayer())
        local equipment = self:GetClientEquipment()
        local outfitData = equipment and equipment[INV.EquipSlots.Outfit]
        if outfitData then
            local def = INV:GetItemDef(outfitData.item_id)
            if def and def.equip_model and def.equip_model ~= "" and app.bodyModel == def.equip_model then
                local CH = VERSE.Characters
                local charData = CH and CH.Client and CH.Client.selected
                if istable(charData) and isstring(charData.model) and charData.model ~= "" then
                    app.bodyModel = charData.model
                end
            end
        end
        self._baseAppearance = app
        local mdl = CP:CreateSized(frame, R:X(282), R:Y(87), R:X(427), R:Y(900), nil, { fov = 20 })
        if IsValid(mdl) then
            mdl._isCharPreview = true
            self._charPreview = mdl
            self._camReady = true
            mdl.PerformLayout = function() end
        end
    end
    local equipData = self:GetClientEquipment()
    self:_CreateEquipSlot(frame, R:X(172), R:Y(392), R:X(EQUIP_SIZE), INV.EquipSlots.Weapon, equipData)
    self:_CreateEquipSlot(frame, R:X(172), R:Y(554), R:X(EQUIP_SIZE), INV.EquipSlots.Outfit, equipData)
    self:_CreateEquipSlot(frame, R:X(687), R:Y(392), R:X(EQUIP_SIZE), INV.EquipSlots.Ring, equipData)
    self:_CreateEquipSlot(frame, R:X(687), R:Y(554), R:X(EQUIP_SIZE), INV.EquipSlots.Talisman, equipData)
end

function INV:_CreateEquipSlot(parent, x, y, size, eqSlotId, equipData)
    local slot = vgui.Create("VCInvSlot", parent)
    slot:SetPos(x, y)
    slot:SetSize(size, size)
    slot:SetSlot(eqSlotId, true, eqSlotId)
    slot:SetSlotData(equipData[eqSlotId])
    setupSlotCallbacks(slot)
    self._equipPanels[eqSlotId] = slot
end

function INV:_BuildInventoryPanel(frame)
    local headerBg = vgui.Create("DPanel", frame)
    headerBg:SetPos(R:XY(952, 226))
    headerBg:SetSize(R:XY(248, 55))
    headerBg.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:X(12)):Color(COL.header_bg):Draw()
        local iconS = R:X(32)
        Materials:Draw(COL.text, "inv_icon_bag", R:X(23), (h - iconS) * 0.5, iconS, iconS, "noclamp smooth")
    end

    local titleLabel = vgui.Create("DLabel", headerBg)
    titleLabel:SetPos(R:X(87), 0)
    titleLabel:SetSize(R:X(150), R:Y(55))
    titleLabel:SetText("Inventaire")
    titleLabel:SetFont(_Font("Bold", 20))
    titleLabel:SetTextColor(COL.text)
    titleLabel:SetContentAlignment(4)
    local searchEntry = vgui.Create("MantleEntry", frame)
    searchEntry:SetPos(R:XY(1447, 230))
    searchEntry:SetSize(R:XY(253, 48))
    searchEntry:SetPlaceholder("Recherchez")
    searchEntry:SetFonts(_Font("Medium", 16), _Font("Medium", 16))
    searchEntry:SetTextColor(COL.text)
    searchEntry:SetPlaceholderColor(COL.text_placeholder)
    self._searchEntry = searchEntry
    searchEntry.textEntry:SetUpdateOnType(true)
    searchEntry.textEntry.OnValueChange = function(_, val)
        self._searchFilter = string.lower(tostring(val or ""))
        self:_ApplyFilters()
    end
    local gridX = R:X(952)
    local gridY = R:Y(311)
    local slotS = R:X(SLOT_SIZE)
    local slotG = R:X(SLOT_GAP)
    local gridPanel = vgui.Create("DPanel", frame)
    local gridW = GRID_COLS * slotS + (GRID_COLS - 1) * slotG
    local gridH = GRID_ROWS * slotS + (GRID_ROWS - 1) * slotG
    gridPanel:SetPos(gridX, gridY)
    gridPanel:SetSize(gridW, gridH)
    gridPanel.Paint = function() end
    local slotCount = self:GetSlotCount()
    local slots = self:GetClientInventory()
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
            slot:SetSlotData(slots[idx])
            setupSlotCallbacks(slot)
            self._slotPanels[idx] = slot
        end
    end

    local btnY = gridY + gridH + R:Y(10)
    local btnH = R:Y(36)

    local filterCombo = vgui.Create("MantleComboBox", frame)
    filterCombo:SetPos(R:X(1293), btnY)
    filterCombo:SetSize(R:X(115), btnH)
    filterCombo:SetPlaceholder("Filtrer")
    filterCombo:SetFonts(_Font("Medium", 18), _Font("Medium", 18), _Font("Medium", 18))
    for _, cat in ipairs(INV.Categories) do
        filterCombo:AddChoice(cat.name, cat.id)
    end
    filterCombo:SetSelected("All", "all")
    filterCombo.OnSelect = function(_, text, data)
        self._categoryFilter = data or "all"
        self:_ApplyFilters()
    end

    local sortPlaceholders = {
        name = "Rechercher par nom...",
        rarity = "Rechercher par rareté...",
        category = "Rechercher par catégorie...",
    }
    local sortCombo = vgui.Create("MantleComboBox", frame)
    sortCombo:SetPos(R:X(1422), btnY)
    sortCombo:SetSize(R:X(115), btnH)
    sortCombo:SetPlaceholder("Trier")
    sortCombo:SetFonts(_Font("Medium", 18), _Font("Medium", 18), _Font("Medium", 18))
    sortCombo:AddChoice("Nom", "name")
    sortCombo:AddChoice("Rareté", "rarity")
    sortCombo:AddChoice("Catégorie", "category")
    sortCombo.OnSelect = function(_, text, data)
        self._sortMode = data or "name"
        if IsValid(self._searchEntry) then
            self._searchEntry:SetPlaceholder(sortPlaceholders[data] or "Recherchez")
        end
        self:_ApplyFilters()
    end

    self:_CreateActionBtn(frame, R:X(1551), btnY, R:X(149), btnH, "Ranger tout", function() INV:RequestSort() end)

    -- ── Portefeuille ──────────────────────────────────────────────────────────
    local walletW = R:X(326)
    local walletPanel = vgui.Create("DPanel", frame)
    walletPanel:SetPos(gridX, btnY)
    walletPanel:SetSize(walletW, btnH)
    local _walletFont = _Font("SemiBold", 18)
    walletPanel.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:X(8)):Color(_INV_COL_WALLET_BG):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:X(8)):Color(_INV_COL_WALLET_BORD):Outline(1):Draw()
        local amount = VERSE.Wallet and VERSE.Wallet.GetAmount and VERSE.Wallet:GetAmount() or 0
        local txt = "Portefeuille  " .. amount .. " Y"
        draw.SimpleText(txt, _walletFont, w * 0.5, h * 0.5, _INV_COL_WALLET_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self._walletPanel = walletPanel
end

function INV:_CreateActionBtn(parent, x, y, w, h, text, onClick)
    local btn = vgui.Create("MantleBtn", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetTxt(text)
    btn:SetFont(_Font("Medium", 18))
    btn:SetColor(Color(50, 50, 50))
    btn:SetColorHover(Color(70, 70, 70))
    btn:SetRadius(R:X(8))
    btn:SetGradient(false)
    btn:SetRipple(true)
    btn.DoClick = function(s) if onClick then onClick(s) end end
    return btn
end


function INV:_RefreshSlots()
    local slots = self:GetClientInventory()
    local equipment = self:GetClientEquipment()
    for idx, panel in pairs(self._slotPanels) do
        if IsValid(panel) then panel:SetSlotData(slots[idx]) end
    end

    for eqSlot, panel in pairs(self._equipPanels) do
        if IsValid(panel) then panel:SetSlotData(equipment[eqSlot]) end
    end

    self._previewDirty = true
    self:_RefreshPreviewModel(equipment)

    self:_ApplyFilters()
end

function INV:_RefreshPreviewModel(equipment)
    local mdl = self._charPreview
    if not IsValid(mdl) or not mdl.Entity then return end
    local CP = VERSE.CharacterPreview
    if not CP then return end

    local outfitSlot = INV.EquipSlots.Outfit
    local outfitData = equipment and equipment[outfitSlot]
    local targetModel = nil

    if outfitData then
        local def = INV:GetItemDef(outfitData.item_id)
        if def and def.equip_model and def.equip_model ~= "" then
            targetModel = def.equip_model
        end
    end

    local app = self._baseAppearance
    if not app then
        app = CP:ReadAppearance(LocalPlayer())
        self._baseAppearance = app
    end

    local bodyModel  = targetModel or app.bodyModel
    local baseModel  = app.bodyModel  -- modèle de base pour le calcul de caméra

    local root = mdl.Entity
    if not IsValid(root) then return end

    local currentModel = root:GetModel()
    if currentModel == bodyModel and not self._previewDirty then return end
    self._previewDirty = false

    if IsValid(mdl._headEnt) then mdl._headEnt:Remove() end
    mdl._headEnt = nil

    -- ══ IMPORTANT ══
    -- On travaille DIRECTEMENT sur l'entité (root:SetModel) et NON via mdl:SetModel.
    -- mdl:SetModel recrée l'entité → InvalidateLayout → PerformLayout de GMod
    -- recalcule la caméra depuis les bounds du nouveau modèle → zoom incontrôlé.
    -- En passant par root:SetModel, aucun InvalidateLayout n'est déclenché.

    -- 1) Charger le modèle de BASE sur l'entité pour lire des bounds stables
    root:SetModel(baseModel)
    root:SetAngles(Angle(0, 0, 0))
    root:SetPos(Vector(0, 0, 0))
    root:SetModelScale(app.modelScale or 1, 0)

    -- 2) Calculer la caméra depuis le modèle de base (une seule fois à l'ouverture)
    if not self._camReady then
        local mins, maxs = root:GetRenderBounds()
        local center = (mins + maxs) * 0.5
        local height = math.max(1, maxs.z - mins.z)
        local radius = math.max(maxs.x - mins.x, maxs.y - mins.y, height)
        mdl:SetFOV(20)
        mdl:SetLookAt(center + Vector(0, 0, height * 0.1))
        mdl:SetCamPos(center + Vector(radius * 0.95, radius * 0.1, height * 0.35))
        self._camReady = true
    end

    -- 3) Switcher sur le modèle d'affichage (tenue ou base)
    if bodyModel ~= baseModel then
        root:SetModel(bodyModel)
        root:SetModelScale(app.modelScale or 1, 0)
    end

    CP.SetBodygroup(root, app.bodyStyle)

    if CP.ApplyIdleAnimation then
        CP.ApplyIdleAnimation(root)
    end

    mdl._headEnt = CP.SpawnMerged(app.headModel, root)
    if IsValid(mdl._headEnt) then
        CP.SetBodygroup(mdl._headEnt, app.headStyle)
        if mdl._headEnt.GetBodygroupCount and mdl._headEnt.SetBodygroup then
            local hairMax = math.max(0, (tonumber(mdl._headEnt:GetBodygroupCount(1)) or 0) - 1)
            mdl._headEnt:SetBodygroup(1, math.Clamp(math.floor(tonumber(app.hairStyle) or 0), 0, hairMax))
        end
        mdl._headEnt:SetModelScale(app.modelScale or 1, 0)
    end

    mdl._cpSkinColor = app.skinColor or CP.DEFAULT_SKIN
    mdl._cpHairColor = app.hairColor or CP.DEFAULT_HAIR
    mdl._cpApp = app
end

function INV:_SortEntries(entries)
    local mode = self._sortMode
    if not mode then return end

    table.sort(entries, function(a, b)
        local da = a.panel:GetSlotData()
        local db = b.panel:GetSlotData()
        if not da and not db then return a.idx < b.idx end
        if not da then return false end
        if not db then return true end

        if mode == "name" then
            local defA = self:GetItemDef(da.item_id)
            local defB = self:GetItemDef(db.item_id)
            local nameA = defA and string.lower(defA.name or "") or string.lower(da.item_id or "")
            local nameB = defB and string.lower(defB.name or "") or string.lower(db.item_id or "")
            if nameA ~= nameB then return nameA < nameB end
            return a.idx < b.idx
        elseif mode == "rarity" then
            local rarA = self:GetItemRarity(da.item_id)
            local rarB = self:GetItemRarity(db.item_id)
            local ordA = (self.Rarities[rarA] and self.Rarities[rarA].order) or 0
            local ordB = (self.Rarities[rarB] and self.Rarities[rarB].order) or 0
            if ordA ~= ordB then return ordA > ordB end
            return a.idx < b.idx
        elseif mode == "category" then
            local defA = self:GetItemDef(da.item_id)
            local defB = self:GetItemDef(db.item_id)
            local catA = defA and string.lower(defA.category or "misc") or "misc"
            local catB = defB and string.lower(defB.category or "misc") or "misc"
            if catA ~= catB then return catA < catB end
            local nameA = defA and string.lower(defA.name or "") or ""
            local nameB = defB and string.lower(defB.name or "") or ""
            if nameA ~= nameB then return nameA < nameB end
            return a.idx < b.idx
        end

        return a.idx < b.idx
    end)
end

function INV:_ApplyFilters()
    local search = self._searchFilter or ""
    local cat = self._categoryFilter or "all"
    local sortMode = self._sortMode
    local slotS = R:X(SLOT_SIZE)
    local slotG = R:X(SLOT_GAP)
    local hasFilter = search ~= "" or cat ~= "all"
    local hasSort = sortMode ~= nil

    local sorted = {}
    for idx, panel in pairs(self._slotPanels) do
        if IsValid(panel) then
            table.insert(sorted, { idx = idx, panel = panel })
        end
    end
    table.sort(sorted, function(a, b) return a.idx < b.idx end)

    if not hasFilter and not hasSort then
        for _, entry in ipairs(sorted) do
            local gi = entry.idx - 1
            local col = gi % GRID_COLS
            local row = math.floor(gi / GRID_COLS)
            entry.panel:SetPos(col * (slotS + slotG), row * (slotS + slotG))
            entry.panel:SetVisible(true)
            entry.panel:SetLocked(false)
        end
        return
    end

    local matchItems = {}
    local nonMatchItems = {}
    local emptySlots = {}
    for _, entry in ipairs(sorted) do
        local data = entry.panel:GetSlotData()
        if not data then
            table.insert(emptySlots, entry)
        else
            local def = self:GetItemDef(data.item_id)
            local match = true

            if search ~= "" then
                local found = false
                if sortMode == "rarity" then
                    local rarity = self:GetItemRarity(data.item_id)
                    local rarLower = string.lower(rarity or "")
                    found = string.find(rarLower, search, 1, true) ~= nil
                elseif sortMode == "category" then
                    local catName = def and string.lower(def.category or "misc") or "misc"
                    found = string.find(catName, search, 1, true) ~= nil
                else
                    local name = def and string.lower(def.name or "") or ""
                    local desc = def and string.lower(def.description or "") or ""
                    local id = string.lower(data.item_id or "")
                    found = string.find(name, search, 1, true) or string.find(desc, search, 1, true) or string.find(id, search, 1, true)
                end
                if not found then match = false end
            end

            if match and cat ~= "all" and def and (def.category or "misc") ~= cat then
                match = false
            end

            if match then
                table.insert(matchItems, entry)
            else
                table.insert(nonMatchItems, entry)
            end
        end
    end

    if hasSort then
        self:_SortEntries(matchItems)
    end

    local pos = 0
    for _, entry in ipairs(matchItems) do
        local col = pos % GRID_COLS
        local row = math.floor(pos / GRID_COLS)
        entry.panel:SetPos(col * (slotS + slotG), row * (slotS + slotG))
        entry.panel:SetVisible(true)
        entry.panel:SetLocked(false)
        pos = pos + 1
    end
    for _, entry in ipairs(emptySlots) do
        local col = pos % GRID_COLS
        local row = math.floor(pos / GRID_COLS)
        entry.panel:SetPos(col * (slotS + slotG), row * (slotS + slotG))
        entry.panel:SetVisible(true)
        entry.panel:SetLocked(false)
        pos = pos + 1
    end
    for _, entry in ipairs(nonMatchItems) do
        local col = pos % GRID_COLS
        local row = math.floor(pos / GRID_COLS)
        entry.panel:SetPos(col * (slotS + slotG), row * (slotS + slotG))
        entry.panel:SetVisible(true)
        entry.panel:SetLocked(true)
        pos = pos + 1
    end
end

concommand.Add("verse_inventory", function() INV:ToggleUI() end)