local INV = VERSE.Inventory
if not INV then return end
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local COL = {
    bg = Color(22, 14, 38, 240),
    outline = Color(231, 142, 255, 60),
    text_name = Color(255, 255, 255),
    text_desc_l = Color(180, 170, 200),
    text_desc = Color(220, 215, 235),
    divider = Color(231, 142, 255, 40),
    stat_val = Color(255, 255, 255),
}

local TIP_W = 300
local TIP_RAD = 10
local TIP_PAD = 16
local ICON_SIZE = 50
local LINE_H = 26
local DIVIDER_GAP = 8
local PANEL = {}
function PANEL:Init()
    self._data = nil
    self._def = nil
    self._lines = {}
    self._totalH = 0
    self:SetDrawOnTop(true)
    self:SetMouseInputEnabled(false)
    self:SetKeyboardInputEnabled(false)
    self:SetVisible(false)
    self:SetZPos(32000)
end

local function _S(v)
    return R and R.S and R:S(v) or v
end

local function _Font(variant, size)
    if Font and Font.GetNamed then return Font:GetNamed("Poppins", variant, size) end
    return "DermaDefault"
end

-- Polices pré-résolues (évite Font:GetNamed dans le Paint callback à chaque frame)
local _TIP_FONT_NAME    = nil   -- "Bold", 24
local _TIP_FONT_RARITY  = nil   -- "SemiBold", 18
local _TIP_FONT_LABEL   = nil   -- "Medium", 17
local _TIP_FONT_DESC    = nil   -- "Regular", 18
local _TIP_FONT_STAT    = nil   -- "Medium", 18
local _TIP_COL_SHADOW   = Color(0, 0, 0, 120)   -- pour le shadow du RNDX

local function ensureTipFonts()
    if _TIP_FONT_NAME then return end
    _TIP_FONT_NAME   = _Font("Bold",     24)
    _TIP_FONT_RARITY = _Font("SemiBold", 18)
    _TIP_FONT_LABEL  = _Font("Medium",   17)
    _TIP_FONT_DESC   = _Font("Regular",  18)
    _TIP_FONT_STAT   = _Font("Medium",   18)
end

hook.Add("OnScreenSizeChanged", "VERSE::InvTooltip::FontReset", function()
    _TIP_FONT_NAME = nil   -- force re-résolution à la prochaine frame de Paint
end)

function PANEL:SetSlotData(data)
    if not data then
        self:ClearData()
        return
    end

    self._data = data
    self._def = INV:GetItemDef(data.item_id)
    self:_Build()
    self:SetVisible(true)
end

function PANEL:ClearData()
    self._data = nil
    self._def = nil
    self._lines = {}
    self:SetVisible(false)
end

function PANEL:_Build()
    self._lines = {}
    local def = self._def
    local data = self._data
    if not def or not data then return end
    local rarity = INV:GetItemRarity(data.item_id)
    local rarityCol = INV:GetRarityColor(rarity)

    table.insert(self._lines, {
        type = "name",
        text = def.name or data.item_id,
        color = COL.text_name,
    })

    if rarity ~= "common" then
        local rn = string.upper(string.sub(rarity, 1, 1)) .. string.sub(rarity, 2)
        table.insert(self._lines, {
            type = "rarity",
            text = rn,
            color = rarityCol,
        })
    end

    if def.description and def.description ~= "" then
        table.insert(self._lines, { type = "divider" })
        table.insert(self._lines, {
            type = "label",
            text = "Description :",
        })
        table.insert(self._lines, {
            type = "desc",
            text = def.description,
        })
    end

    local hasStats = (def.weight and def.weight > 0) or (data.amount and data.amount > 1) or def.equip_slot
    if hasStats then
        table.insert(self._lines, { type = "divider" })
    end

    if def.weight and def.weight > 0 then
        table.insert(self._lines, {
            type = "stat",
            label = "Weight",
            value = string.format("%.1f", def.weight),
        })
    end

    if data.amount and data.amount > 1 then
        local amountStr
        if INV:IsInfiniteStack(data.item_id) then
            amountStr = VERSE.Format.Money(data.amount)
        else
            amountStr = tostring(data.amount) .. "/" .. tostring(INV:GetMaxStack(data.item_id))
        end
        table.insert(self._lines, {
            type = "stat",
            label = "Amount",
            value = amountStr,
        })
    end

    if def.equip_slot then
        local slotName = def.equip_slot
        for k, v in pairs(INV.EquipSlots or {}) do
            if v == def.equip_slot then slotName = k break end
        end
        table.insert(self._lines, {
            type = "stat",
            label = "Slot",
            value = tostring(slotName),
        })
    end

    local pad = _S(TIP_PAD)
    local iconS = _S(ICON_SIZE)
    local textX = pad + iconS + _S(10)
    local textW = _S(TIP_W) - textX - pad
    local h = pad * 2
    for _, line in ipairs(self._lines) do
        if line.type == "divider" then
            h = h + _S(DIVIDER_GAP) * 2 + 1
        elseif line.type == "desc" then
            local font = _Font("Regular", 18)
            local wrapped = self:_WrapText(line.text, font, textW)
            h = h + _S(LINE_H) * #wrapped
        else
            h = h + _S(LINE_H)
        end
    end

    self._totalH = math.max(h, iconS + pad * 2)
    self:SetSize(_S(TIP_W), self._totalH)
end

function PANEL:Think()
    if not self:IsVisible() then return end
    local mx, my = gui.MousePos()
    local parent = self:GetParent()
    local px, py = 0, 0
    if IsValid(parent) then px, py = parent:LocalToScreen(0, 0) end
    local sw, sh = ScrW(), ScrH()
    local w, h = self:GetSize()
    local x = mx + _S(16) - px
    local y = my - _S(8) - py
    if mx + _S(16) + w > sw then x = mx - w - _S(8) - px end
    if my - _S(8) + h > sh then y = sh - h - _S(4) - py end
    if my - _S(8) - py < 0 then y = 0 end
    self:SetPos(x, y)
end

function PANEL:Paint(w, h)
    ensureTipFonts()
    local rad = _S(TIP_RAD)
    local pad = _S(TIP_PAD)

    RNDX().Rect(0, 0, w, h):Rad(rad):Color(COL.bg):Shadow(_S(8), 0, _TIP_COL_SHADOW):Draw()
    RNDX().Rect(0, 0, w, h):Rad(rad):Color(COL.outline):Outline(1):Draw()

    local iconS = _S(ICON_SIZE)
    local iconX = pad
    local iconY = pad
    local def = self._def
    local icon = def and def.icon or "inv_fallback_icon"
    Materials:Draw(color_white, icon, iconX, iconY, iconS, iconS, "noclamp smooth")

    local textX = iconX + iconS + _S(10)
    local textW = w - textX - pad
    local yOff = pad
    for _, line in ipairs(self._lines) do
        if line.type == "name" then
            draw.SimpleText(line.text, _TIP_FONT_NAME, textX, yOff, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            yOff = yOff + _S(LINE_H)
        elseif line.type == "rarity" then
            draw.SimpleText(line.text, _TIP_FONT_RARITY, textX, yOff, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            yOff = yOff + _S(LINE_H)
        elseif line.type == "divider" then
            yOff = yOff + _S(DIVIDER_GAP)
            surface.SetDrawColor(COL.divider)
            surface.DrawRect(textX, yOff, textW, 1)
            yOff = yOff + 1 + _S(DIVIDER_GAP)
        elseif line.type == "label" then
            draw.SimpleText(line.text, _TIP_FONT_LABEL, textX, yOff, COL.text_desc_l, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            yOff = yOff + _S(LINE_H)
        elseif line.type == "desc" then
            local wrapped = self:_WrapText(line.text, _TIP_FONT_DESC, textW)
            for _, wl in ipairs(wrapped) do
                draw.SimpleText(wl, _TIP_FONT_DESC, textX, yOff, COL.text_desc, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                yOff = yOff + _S(LINE_H)
            end
        elseif line.type == "stat" then
            draw.SimpleText(line.label, _TIP_FONT_STAT, textX, yOff, COL.text_desc_l, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(line.value, _TIP_FONT_STAT, w - pad, yOff, COL.stat_val, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            yOff = yOff + _S(LINE_H)
        end
    end
end

function PANEL:_WrapText(text, font, maxW)
    surface.SetFont(font)
    local tw = surface.GetTextSize(text)
    if tw <= maxW then return {text} end
    local lines = {}
    local words = string.Explode(" ", text)
    local cur = ""
    for _, word in ipairs(words) do
        local test = cur == "" and word or (cur .. " " .. word)
        if surface.GetTextSize(test) > maxW and cur ~= "" then
            table.insert(lines, cur)
            cur = word
        else
            cur = test
        end
    end

    if cur ~= "" then table.insert(lines, cur) end
    return lines
end

VERSE.VGUI.RegisterNS("Inventory", "VCInvTooltip", PANEL, "DPanel", {
    source = "modules/inventory/vgui/cl_inv_tooltip.lua",
    overwrite = true,
})
