local Materials = VERSE.Materials
local Font = VERSE.Fonts
local PANEL = {}

-- ─── Couleurs pré-allouées ────────────────────────────────────────────────────
local _FC_COL_DARK_OVERLAY  = Color(12,  12,  12,  245)  -- .a muté
local _FC_COL_MINI_IMG      = Color(255, 255, 255, 25)   -- .a muté
local _FC_COL_HOVER_OUT     = Color(255, 255, 255, 50)   -- .a muté
local _FC_COL_BADGE_FILL    = Color(128, 89,  179, 255)
local _FC_COL_CHECK         = Color(23,  23,  23,  255)
local _FC_COL_SUB_LINE      = Color(255, 255, 255, 140)
function PANEL:Init()
    self:SetTxt("")
    self:SetRipple(true)
    self:SetGradient(false)
    self:SetColor(Mantle.color.button)
    self:SetColorHover(Mantle.color.button_hovered)
    self._selected = false
    self._factionId = ""
    self._factionName = ""
    self._bgKey = ""
    self._miniKey = ""
    self._onChoose = nil
end

function PANEL:_X(value)
    local responsive = VERSE and VERSE.Responsive or nil
    if responsive and responsive.X then return responsive:X(value) end
    return value
end

function PANEL:_Y(value)
    local responsive = VERSE and VERSE.Responsive or nil
    if responsive and responsive.Y then return responsive:Y(value) end
    return value
end

function PANEL:SetFactionData(factionId, factionName, bgKey, miniKey)
    self._factionId = tostring(factionId or "")
    self._factionName = tostring(factionName or self._factionId or "")
    self._bgKey = tostring(bgKey or "")
    self._miniKey = tostring(miniKey or "")
end

function PANEL:SetSelected(selected)
    self._selected = selected == true
end

function PANEL:SetOnChoose(callback)
    self._onChoose = isfunction(callback) and callback or nil
end

function PANEL:DoClick()
    if self._onChoose then self._onChoose(self, self._factionId) end
end

local _fcNameFont = Font:GetNamed("Poppins", "Bold",    48)
local _fcSubFont  = Font:GetNamed("Poppins", "Regular", 35)
function PANEL:Paint(width, height)
    local hoverFrac = self._hoverFrac or 0
    local pressFrac = math.max(self._pressFrac or 0, self._clickFrac or 0)
    if self._bgKey ~= "" then Materials:Draw(color_white, self._bgKey, 0, 0, width, height) end
    _FC_COL_DARK_OVERLAY.a = self._selected and 200 or (245 - math.floor(hoverFrac * 18))
    RNDX.Draw(self:_Y(14), 0, 0, width, height, _FC_COL_DARK_OVERLAY)
    if self._miniKey ~= "" then
        if self._selected then
            Materials:Draw(color_white, self._miniKey, width * .5 - self:_X(478 / 2), height - self:_Y(588), self:_X(478), self:_Y(588))
        else
            _FC_COL_MINI_IMG.a = 25 + math.floor(hoverFrac * 40)
            Materials:Draw(_FC_COL_MINI_IMG, self._miniKey, width * .5 - self:_X(478 / 2), height - self:_Y(588), self:_X(478), self:_Y(588))
        end
    end
    if not self._selected then
        _FC_COL_HOVER_OUT.a = 50 + math.floor(hoverFrac * 45)
        RNDX().Rect(0, 0, width, height):Rad(self:_Y(14)):Color(_FC_COL_HOVER_OUT):Outline(self:_Y(2)):Draw()
    else
        -- r/g/b channels vary with pressFrac — new Color() is acceptable here
        RNDX().Rect(0, 0, width, height):Rad(self:_Y(14)):Color(Color(128 - math.floor(pressFrac * 8), 89 - math.floor(pressFrac * 6), 179 - math.floor(pressFrac * 4))):Outline(self:_Y(3)):Draw()
        local badgeSize = self:_Y(28)
        local badgeX = width - badgeSize - self:_X(14)
        local badgeY = height - badgeSize - self:_Y(14)
        RNDX.Draw(self:_Y(4), badgeX, badgeY, badgeSize, badgeSize, _FC_COL_BADGE_FILL)
        local x1 = math.floor(badgeX + badgeSize * 0.28)
        local y1 = math.floor(badgeY + badgeSize * 0.54)
        local x2 = math.floor(badgeX + badgeSize * 0.44)
        local y2 = math.floor(badgeY + badgeSize * 0.70)
        local x3 = math.floor(badgeX + badgeSize * 0.74)
        local y3 = math.floor(badgeY + badgeSize * 0.34)
        surface.SetDrawColor(_FC_COL_CHECK.r, _FC_COL_CHECK.g, _FC_COL_CHECK.b, _FC_COL_CHECK.a)
        for offset = -1, 1 do
            surface.DrawLine(x1, y1 + offset, x2, y2 + offset)
            surface.DrawLine(x2, y2 + offset, x3, y3 + offset)
        end
    end

    draw.SimpleText(self._factionName ~= "" and self._factionName or self._factionId, _fcNameFont, width * 0.5, self:_Y(69), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    local subY = self:_Y(108)
    local lineW = self:_X(95)
    local lineH = self:_Y(2)
    local padX = self:_X(55)
    RNDX.Draw(0, padX, subY - lineH * 0.5, lineW, lineH, _FC_COL_SUB_LINE)
    RNDX.Draw(0, width - padX - lineW, subY - lineH * 0.5, lineW, lineH, _FC_COL_SUB_LINE)
    draw.SimpleText("Rejoignez cette faction", _fcSubFont, width * 0.5, subY, _FC_COL_SUB_LINE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

VERSE.VGUI.RegisterNS("Characters", "VCFactionCard", PANEL, "MantleBtn", {
    source = "modules/characters/vgui/cl_faction_card.lua",
    overwrite = true,
})
