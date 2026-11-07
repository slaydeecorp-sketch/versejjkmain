local PANEL = {}
function PANEL:Init()
    self.Paint = function() end
    self._gap = 10
    self._positionCallback = nil
    self._positionYToDataSign = -1
    self._positionPad = vgui.Create("VCMarkAxis", self)
    self._positionPad:SetAxisLabels("X", "Y")
    self._positionPad:SetText("Position")
    self._positionPad:SetRange(-300, 300)
    if self._positionPad.SetInvertY then self._positionPad:SetInvertY(false) end
    self._positionPad:SetPadValues(0, 0, true)
    self._sizePad = vgui.Create("VCMarkAxis", self)
    self._sizePad:SetAxisLabels("Largeur", "Hauteur")
    self._sizePad:SetText("Taille")
    self._sizePad:SetRange(1, 50)
    if self._sizePad.SetInvertY then self._sizePad:SetInvertY(false) end
    self._sizePad:SetPadValues(24, 24, true)
end

function PANEL:_X(value)
    local responsive = VERSE and VERSE.Responsive or nil
    if responsive and responsive.X then return responsive:X(value) end
    return value
end

function PANEL:PerformLayout(width, height)
    local gap = self:_X(self._gap or 10)
    local panelWidth = math.max(1, math.floor((width - gap) * 0.5))
    self._sizePad:SetPos(0, 0)
    self._sizePad:SetSize(panelWidth, height)
    self._positionPad:SetPos(panelWidth + gap, 0)
    self._positionPad:SetSize(math.max(1, width - panelWidth - gap), height)
end

function PANEL:SetPadTheme(theme)
    if IsValid(self._positionPad) and self._positionPad.SetTheme then self._positionPad:SetTheme(theme) end
    if IsValid(self._sizePad) and self._sizePad.SetTheme then self._sizePad:SetTheme(theme) end
end

function PANEL:SetPadFonts(titleFont, valueFont)
    if IsValid(self._positionPad) and self._positionPad.SetFonts then self._positionPad:SetFonts(titleFont, valueFont) end
    if IsValid(self._sizePad) and self._sizePad.SetFonts then self._sizePad:SetFonts(titleFont, valueFont) end
end

function PANEL:SetPositionCallback(callback)
    self._positionCallback = isfunction(callback) and callback or nil
    if IsValid(self._positionPad) and self._positionPad.SetOnChanged then
        self._positionPad:SetOnChanged(function(valueX, valueY)
            local sign = tonumber(self._positionYToDataSign) or -1
            local dataY = math.floor((tonumber(valueY) or 0) * sign)
            if self._positionCallback then self._positionCallback(valueX, dataY) end
        end)
    end
end

function PANEL:SetSizeCallback(callback)
    if IsValid(self._sizePad) and self._sizePad.SetOnChanged then self._sizePad:SetOnChanged(callback) end
end

function PANEL:SetPositionText(text)
    if IsValid(self._positionPad) and self._positionPad.SetText then self._positionPad:SetText(text) end
end

function PANEL:SetSizeText(text)
    if IsValid(self._sizePad) and self._sizePad.SetText then self._sizePad:SetText(text) end
end

function PANEL:SetPositionAxisLabels(xLabel, yLabel)
    if IsValid(self._positionPad) and self._positionPad.SetAxisLabels then self._positionPad:SetAxisLabels(xLabel, yLabel) end
end

function PANEL:SetSizeAxisLabels(xLabel, yLabel)
    if IsValid(self._sizePad) and self._sizePad.SetAxisLabels then self._sizePad:SetAxisLabels(xLabel, yLabel) end
end

function PANEL:SetPositionRange(minValue, maxValue)
    if IsValid(self._positionPad) and self._positionPad.SetRange then self._positionPad:SetRange(minValue, maxValue) end
end

function PANEL:SetSizeRange(minValue, maxValue)
    if IsValid(self._sizePad) and self._sizePad.SetRange then self._sizePad:SetRange(minValue, maxValue) end
end

function PANEL:SetPositionValues(valueX, valueY, silent)
    if not (IsValid(self._positionPad) and self._positionPad.SetPadValues) then return end
    local sign = tonumber(self._positionYToDataSign) or -1
    local displayY = math.floor((tonumber(valueY) or 0) * sign)
    self._positionPad:SetPadValues(valueX, displayY, silent)
end

function PANEL:SetSizeValues(valueX, valueY, silent)
    if IsValid(self._sizePad) and self._sizePad.SetPadValues then self._sizePad:SetPadValues(valueX, valueY, silent) end
end

function PANEL:SetValues(posX, posY, sizeX, sizeY, silent)
    self:SetPositionValues(posX, posY, silent)
    self:SetSizeValues(sizeX, sizeY, silent)
end

VERSE.VGUI.RegisterNS("Characters", "VCMarkTransform", PANEL, "DPanel", {
    source = "modules/characters/vgui/cl_bodymark_transform.lua",
    overwrite = true,
})
