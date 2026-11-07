local PANEL = {}
local DEFAULT_BASE = Color(12, 12, 20, 220)
local DEFAULT_HOVER = Color(255, 255, 255, 18)
local DEFAULT_OUTLINE = Color(255, 255, 255, 80)
local DEFAULT_OUTLINE_ACTIVE = Color(128, 89, 179)
function PANEL:_X(value)
    local responsive = VERSE and VERSE.Responsive or nil
    if responsive and responsive.X then return responsive:X(value) end
    return value
end

function PANEL:Init()
    self:SetText("")
    self._styleIndex = 0
    self._safeStyleIndex = 0
    self._onSelect = nil
    self._isSelected = nil
    self._baseColor = DEFAULT_BASE
    self._hoverColor = DEFAULT_HOVER
    self._outlineColor = DEFAULT_OUTLINE
    self._outlineActiveColor = DEFAULT_OUTLINE_ACTIVE
    -- Couleurs pré-allouées pour Paint (évite les allocations par frame)
    self._paintBase    = Color(DEFAULT_BASE.r,            DEFAULT_BASE.g,            DEFAULT_BASE.b,            DEFAULT_BASE.a or 220)  -- .a muté
    self._paintHover   = Color(DEFAULT_HOVER.r,           DEFAULT_HOVER.g,           DEFAULT_HOVER.b,           0)                       -- .a muté
    self._paintOut     = Color(DEFAULT_OUTLINE.r,         DEFAULT_OUTLINE.g,         DEFAULT_OUTLINE.b,         DEFAULT_OUTLINE.a or 80) -- .a muté
    self._paintActFill = Color(DEFAULT_OUTLINE_ACTIVE.r,  DEFAULT_OUTLINE_ACTIVE.g,  DEFAULT_OUTLINE_ACTIVE.b,  24)
end

function PANEL:SetStyleIndex(index)
    local safe = math.max(0, math.floor(tonumber(index) or 0))
    self._styleIndex = safe
    self._safeStyleIndex = safe
end

function PANEL:SetSafeStyleIndex(index)
    self._safeStyleIndex = math.max(0, math.floor(tonumber(index) or 0))
end

function PANEL:GetSafeStyleIndex()
    return self._safeStyleIndex or self._styleIndex or 0
end

function PANEL:SetOnSelect(callback)
    self._onSelect = isfunction(callback) and callback or nil
end

function PANEL:SetSelectedResolver(callback)
    self._isSelected = isfunction(callback) and callback or nil
end

function PANEL:SetPalette(baseColor, hoverColor, outlineColor, activeOutlineColor)
    if IsColor(baseColor) then
        self._baseColor = Color(baseColor.r, baseColor.g, baseColor.b, baseColor.a or 255)
        self._paintBase.r = baseColor.r;  self._paintBase.g = baseColor.g;  self._paintBase.b = baseColor.b
        self._paintBase.a = baseColor.a or 255
    end
    if IsColor(hoverColor) then
        self._hoverColor = Color(hoverColor.r, hoverColor.g, hoverColor.b, hoverColor.a or 255)
        self._paintHover.r = hoverColor.r;  self._paintHover.g = hoverColor.g;  self._paintHover.b = hoverColor.b
    end
    if IsColor(outlineColor) then
        self._outlineColor = Color(outlineColor.r, outlineColor.g, outlineColor.b, outlineColor.a or 255)
        self._paintOut.r = outlineColor.r;  self._paintOut.g = outlineColor.g;  self._paintOut.b = outlineColor.b
        self._paintOut.a = outlineColor.a or 255
    end
    if IsColor(activeOutlineColor) then
        self._outlineActiveColor = Color(activeOutlineColor.r, activeOutlineColor.g, activeOutlineColor.b, activeOutlineColor.a or 255)
        self._paintActFill.r = activeOutlineColor.r;  self._paintActFill.g = activeOutlineColor.g;  self._paintActFill.b = activeOutlineColor.b
    end
end

function PANEL:DoClick()
    if self._onSelect then self._onSelect(self, self:GetSafeStyleIndex()) end
end

function PANEL:Paint(width, height)
    self._hoverFrac = Lerp(FrameTime() * 12, self._hoverFrac or 0, self:IsHovered() and 1 or 0)
    local hoverFrac = self._hoverFrac or 0
    local selected = self._isSelected and self._isSelected(self) == true or false
    local baseColor = self._baseColor or DEFAULT_BASE
    local hoverColor = self._hoverColor or DEFAULT_HOVER
    local outlineColor = self._outlineColor or DEFAULT_OUTLINE
    local outlineActiveColor = self._outlineActiveColor or DEFAULT_OUTLINE_ACTIVE
    local baseAlpha = math.floor(Lerp(hoverFrac, baseColor.a or 220, math.min(255, (baseColor.a or 220) + 16)))
    local outlineAlpha = math.floor(Lerp(hoverFrac, outlineColor.a or 80, (outlineColor.a or 80) + 18))
    self._paintBase.a = baseAlpha
    RNDX().Rect(0, 0, width, height):Rad(self:_X(14)):Color(self._paintBase):Draw()
    if hoverFrac > 0 then
        self._paintHover.a = math.floor((hoverColor.a or 18) * hoverFrac)
        RNDX().Rect(0, 0, width, height):Rad(self:_X(14)):Color(self._paintHover):Draw()
    end
    local borderColor
    if selected then
        borderColor = outlineActiveColor
    else
        self._paintOut.a = outlineAlpha
        borderColor = self._paintOut
    end
    RNDX().Rect(0, 0, width, height):Rad(self:_X(14)):Color(borderColor):Outline(1):Draw()
    if selected then RNDX().Rect(0, 0, width, height):Rad(self:_X(14)):Color(self._paintActFill):Outline(1):Draw() end
end

VERSE.VGUI.RegisterNS("Characters", "VCHairTile", PANEL, "DButton", {
    source = "modules/characters/vgui/cl_hair_style_tile.lua",
    overwrite = true,
})