local PANEL = {}
local function safeColor(value, fallback)
    if IsColor(value) then return Color(value.r, value.g, value.b, value.a or 255) end
    return fallback
end

function PANEL:Init()
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(false)
    self:SetCursor("hand")
    self._title = ""
    self._axisXLabel = "X"
    self._axisYLabel = "Y"
    self._minValue = 0
    self._maxValue = 100
    self._valueX = 0
    self._valueY = 0
    self._dragging = false
    self._onChanged = nil
    self._invertY = false
    self._theme = {
        base = Color(6, 6, 12, 170),
        outline = Color(255, 255, 255, 18),
        axis = Color(255, 255, 255, 62),
        cursor = Color(128, 89, 179, 240),
        value = Color(255, 255, 255, 210),
    }
    -- Pré-alloué pour le halo du curseur (évite Color() par frame dans Paint)
    self._paintCursorHalo = Color(128, 89, 179, 75)
end

function PANEL:SetInvertY(invert)
    self._invertY = invert == true
end

function PANEL:OnRemove()
    self._dragging = false
    self:MouseCapture(false)
end

function PANEL:_R()
    return VERSE and VERSE.Responsive or nil
end

function PANEL:_X(value)
    local responsive = self:_R()
    if responsive and responsive.X then return responsive:X(value) end
    return value
end

function PANEL:_Y(value)
    local responsive = self:_R()
    if responsive and responsive.Y then return responsive:Y(value) end
    return value
end

function PANEL:SetTheme(theme)
    theme = istable(theme) and theme or {}
    local current = self._theme or {}
    self._theme = {
        base = safeColor(theme.base, current.base or Color(6, 6, 12, 170)),
        outline = safeColor(theme.outline, current.outline or Color(255, 255, 255, 18)),
        axis = safeColor(theme.axis, current.axis or Color(255, 255, 255, 62)),
        cursor = safeColor(theme.cursor, current.cursor or Color(128, 89, 179, 240)),
        value = safeColor(theme.value, current.value or Color(255, 255, 255, 210)),
    }
    -- Met à jour le halo pré-alloué si le curseur a changé
    local nc = self._theme.cursor
    if nc and self._paintCursorHalo then
        self._paintCursorHalo.r = nc.r
        self._paintCursorHalo.g = nc.g
        self._paintCursorHalo.b = nc.b
    end
end

function PANEL:SetFonts(titleFont, valueFont)
    self._titleFont = titleFont
    self._valueFont = valueFont
end

function PANEL:SetOnChanged(callback)
    self._onChanged = isfunction(callback) and callback or nil
end

function PANEL:SetText(text)
    self._title = tostring(text or "")
end

function PANEL:SetAxisLabels(xLabel, yLabel)
    self._axisXLabel = tostring(xLabel or "X")
    self._axisYLabel = tostring(yLabel or "Y")
end

function PANEL:SetRange(minValue, maxValue)
    self._minValue = math.floor(tonumber(minValue) or self._minValue or 0)
    self._maxValue = math.floor(tonumber(maxValue) or self._maxValue or self._minValue or 0)
    if self._maxValue < self._minValue then self._maxValue = self._minValue end
    self:SetPadValues(self._valueX, self._valueY, true)
end

function PANEL:SetPadValues(valueX, valueY, silent)
    local minN = self._minValue or 0
    local maxN = self._maxValue or minN
    local nextX = math.Clamp(math.floor(tonumber(valueX) or minN), minN, maxN)
    local nextY = math.Clamp(math.floor(tonumber(valueY) or minN), minN, maxN)
    local changed = nextX ~= self._valueX or nextY ~= self._valueY
    self._valueX = nextX
    self._valueY = nextY
    if changed and silent ~= true and self._onChanged then self._onChanged(nextX, nextY) end
end

function PANEL:SetValues(valueX, valueY, silent)
    self:SetPadValues(valueX, valueY, silent)
end

function PANEL:GetPadValues()
    return self._valueX, self._valueY
end

function PANEL:_GetInteractiveRect()
    local left = self:_X(10)
    local right = self:_X(10)
    local top = self:_Y(30)
    local bottom = self:_Y(24)
    local width = math.max(1, self:GetWide() - left - right)
    local height = math.max(1, self:GetTall() - top - bottom)
    return left, top, width, height
end

function PANEL:_ApplyCursor(localX, localY, silent)
    local areaX, areaY, areaW, areaH = self:_GetInteractiveRect()
    local clampedX = math.Clamp(localX, areaX, areaX + areaW)
    local clampedY = math.Clamp(localY, areaY, areaY + areaH)
    local normalizedX = (clampedX - areaX) / areaW
    local normalizedY = (clampedY - areaY) / areaH
    if self._invertY == true then normalizedY = 1 - normalizedY end
    local minN = self._minValue or 0
    local maxN = self._maxValue or minN
    local valueX = math.floor(minN + (normalizedX * (maxN - minN)) + 0.5)
    local valueY = math.floor(minN + (normalizedY * (maxN - minN)) + 0.5)
    self:SetPadValues(valueX, valueY, silent)
end

function PANEL:OnMousePressed(keyCode)
    if keyCode ~= MOUSE_LEFT then return end
    self._dragging = true
    self:MouseCapture(true)
    local x, y = self:CursorPos()
    self:_ApplyCursor(x, y, false)
end

function PANEL:OnMouseReleased(keyCode)
    if keyCode ~= MOUSE_LEFT then return end
    self._dragging = false
    self:MouseCapture(false)
end

function PANEL:OnCursorMoved(x, y)
    if not self._dragging then return end
    self:_ApplyCursor(x, y, false)
end

function PANEL:Paint(width, height)
    local areaX, areaY, areaW, areaH = self:_GetInteractiveRect()
    local theme = self._theme or {}
    local titleFont = self._titleFont or "DermaDefaultBold"
    local valueFont = self._valueFont or "DermaDefault"
    RNDX().Rect(0, 0, width, height):Rad(self:_X(14)):Color(theme.base or color_black):Draw()
    RNDX().Rect(0, 0, width, height):Rad(self:_X(14)):Color(theme.outline or color_white):Outline(1):Draw()
    RNDX().Rect(areaX, areaY + (areaH * 0.5), areaW, 1):Color(theme.axis or color_white):Draw()
    RNDX().Rect(areaX + (areaW * 0.5), areaY, 1, areaH):Color(theme.axis or color_white):Draw()
    draw.SimpleText(self._title or "", titleFont, areaX, self:_Y(4), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(self._axisXLabel or "X", valueFont, areaX + areaW, areaY + self:_Y(8), theme.value or color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    draw.SimpleText(self._axisYLabel or "Y", valueFont, areaX + areaW, areaY + areaH - self:_Y(8), theme.value or color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    local minN = self._minValue or 0
    local maxN = self._maxValue or minN
    local range = math.max(1, maxN - minN)
    local normalizedX = math.Clamp(((self._valueX or minN) - minN) / range, 0, 1)
    local normalizedY = math.Clamp(((self._valueY or minN) - minN) / range, 0, 1)
    if self._invertY == true then normalizedY = 1 - normalizedY end
    local cursorX = areaX + (normalizedX * areaW)
    local cursorY = areaY + (normalizedY * areaH)
    local cursorColor = theme.cursor or color_white
    RNDX().Circle(cursorX, cursorY, math.max(3, self:_X(5))):Color(cursorColor):Draw()
    RNDX().Circle(cursorX, cursorY, math.max(5, self:_X(8))):Color(self._paintCursorHalo):Outline(1):Draw()
    draw.SimpleText(tostring(self._axisXLabel or "X") .. ": " .. tostring(math.floor(self._valueX or 0)) .. "   " .. tostring(self._axisYLabel or "Y") .. ": " .. tostring(math.floor(self._valueY or 0)), valueFont, areaX, height - self:_Y(6), theme.value or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
end

VERSE.VGUI.RegisterNS("Characters", "VCMarkAxis", PANEL, "DPanel", {
    source = "modules/characters/vgui/cl_bodymark_axispad.lua",
    overwrite = true,
})
