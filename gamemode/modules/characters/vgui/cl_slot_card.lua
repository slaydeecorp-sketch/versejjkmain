local Materials = VERSE.Materials
local Font      = VERSE.Fonts
local PANEL     = {}

-- ─── Couleurs pré-allouées Paint ─────────────────────────────────────────────
local _SC_COL_EMPTY_BG      = Color(50,  50,  50,  50)    -- .a muté
local _SC_COL_EMPTY_OUT1    = Color(255, 255, 255, 100)   -- .a muté
local _SC_COL_EMPTY_OUT2    = Color(255, 255, 255, 75)    -- .a muté
local _SC_COL_EMPTY_BTN_OUT = Color(255, 255, 255, 30)    -- .a muté
local _SC_COL_CHAR_BG       = Color(255, 255, 255, 45)    -- .a muté
local _SC_COL_CHAR_DARK     = Color(12,  12,  18,  228)   -- .a muté
local _SC_COL_CHAR_OUT1     = Color(255, 255, 255, 100)   -- .a muté
local _SC_COL_CHAR_OUT2     = Color(255, 255, 255, 50)    -- .a muté
local _SC_COL_FACTION       = Color(212, 212, 212, 255)
local _SC_COL_DIVIDER       = Color(255, 255, 255, 140)
local _SC_COL_LEVEL         = Color(239, 239, 239, 255)
local _SC_COL_PLAY_OUT      = Color(255, 255, 255, 50)    -- .a muté


function PANEL:Init()
    self:SetTxt("")
    self:SetRipple(true)
    self:SetGradient(false)
    self:SetColor(Mantle.color.button)
    self:SetColorHover(Mantle.color.button_hovered)
    self._slot        = 1
    self._character   = nil
    self._factionName = ""
    self._displayName = ""
    self._levelText   = "Niveau 1"
    self._bgKey       = "character_create_char_back"
    self._allowDelete = false
    self._onDelete    = nil
    self._onPlay      = nil
    self._onCreate    = nil
    self._deleteBtn   = nil

end

function PANEL:_X(value)
    local r = VERSE and VERSE.Responsive
    if r and r.X then return r:X(value) end
    return value
end

function PANEL:_Y(value)
    local r = VERSE and VERSE.Responsive
    if r and r.Y then return r:Y(value) end
    return value
end

function PANEL:SetSlot(slot)
    self._slot = math.max(1, math.floor(tonumber(slot) or 1))
end

function PANEL:SetCharacter(character)
    self._character = istable(character) and character or nil

end

function PANEL:SetTextData(factionName, displayName, levelText)
    self._factionName = tostring(factionName or "")
    self._displayName = tostring(displayName or "")
    self._levelText   = tostring(levelText   or "Niveau 1")
end

function PANEL:SetBackgroundMaterial(materialKey)
    self._bgKey = tostring(materialKey or "character_create_char_back")
end

function PANEL:SetActionHandlers(onPlay, onCreate, onDelete)
    self._onPlay   = isfunction(onPlay)   and onPlay   or nil
    self._onCreate = isfunction(onCreate) and onCreate or nil
    self._onDelete = isfunction(onDelete) and onDelete or nil
end

function PANEL:SetDeleteEnabled(enabled)
    self._allowDelete = enabled == true
    local hasCharacter    = istable(self._character)
    local shouldShowDelete = hasCharacter and self._allowDelete and isfunction(self._onDelete)

    if shouldShowDelete and not IsValid(self._deleteBtn) then
        local _delBtnOutline = Color(255, 180, 190, 70)  -- .a muté
        local _delBtnFont    = Font:GetNamed("Poppins", "Bold", 22)
        local deleteBtn = vgui.Create("DButton", self)
        deleteBtn:SetText("")
        deleteBtn.Paint = function(s, width, height)
            s._hoverFrac = Lerp(math.min(FrameTime() * 12, 1), s._hoverFrac or 0, s:IsHovered() and 1 or 0)
            s._pressFrac = Lerp(math.min(FrameTime() * 18, 1), s._pressFrac or 0, s.Depressed   and 1 or 0)
            local hoverFrac = s._hoverFrac or 0
            local pressFrac = s._pressFrac or 0
            -- r/g/b interpolate with hoverFrac — dynamic Color() accepted here
            local bg = Color(
                math.floor(Lerp(hoverFrac, 58,  82)),
                math.floor(Lerp(hoverFrac, 22,  28)),
                math.floor(Lerp(hoverFrac, 34,  44)),
                math.floor(Lerp(hoverFrac, 210, 235))
            )
            if pressFrac > 0 then
                bg = Color(math.max(0, bg.r - 10), math.max(0, bg.g - 8), math.max(0, bg.b - 8), bg.a)
            end
            local inset = self:_Y(pressFrac > 0 and 3 or 2)
            RNDX().Rect(0, 0, width, height):Rad(self:_Y(12)):Color(bg):Draw()
            _delBtnOutline.a = math.floor(Lerp(hoverFrac, 70, 130))
            RNDX().Rect(0, 0, width, height):Rad(self:_Y(12))
                :Color(_delBtnOutline):Outline(self:_Y(1)):Draw()
            draw.SimpleText("X", _delBtnFont,
                width * 0.5, height * 0.5 + inset - self:_Y(1),
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        deleteBtn.DoClick = function()
            if self._onDelete then self._onDelete(self._slot, self._character) end
        end
        self._deleteBtn = deleteBtn
    elseif not shouldShowDelete and IsValid(self._deleteBtn) then
        self._deleteBtn:Remove()
        self._deleteBtn = nil
    end

    self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
    -- Bouton supprimer (haut droite)
    if IsValid(self._deleteBtn) then
        self._deleteBtn:SetSize(self:_X(35), self:_Y(35))
        self._deleteBtn:SetPos(width - self:_X(58), self:_Y(18))
    end


end

function PANEL:OnRemove()
    if IsValid(self._deleteBtn) then self._deleteBtn:Remove() self._deleteBtn = nil end
end

function PANEL:DoClick()
    if self._character then
        if self._onPlay   then self._onPlay(self._slot, self._character) end
    else
        if self._onCreate then self._onCreate(self._slot) end
    end
end

function PANEL:Paint(width, height)
    local hoverFrac    = self._hoverFrac or 0
    local pressFrac    = math.max(self._pressFrac or 0, self._clickFrac or 0)
    local hasCharacter = istable(self._character)

    -- ── Slot vide ─────────────────────────────────────────────────────────────
    if not hasCharacter then
        _SC_COL_EMPTY_BG.a = 50 + math.floor(hoverFrac * 20)
        Materials:Draw(_SC_COL_EMPTY_BG, "character_create_char_back", 0, 0, width, height)
        _SC_COL_EMPTY_OUT1.a = 100 + math.floor(hoverFrac * 45)
        RNDX().Rect(0, 0, width, height):Rad(self:_Y(22))
            :Color(_SC_COL_EMPTY_OUT1):Outline(self:_Y(2)):Draw()
        _SC_COL_EMPTY_OUT2.a = 75 + math.floor(hoverFrac * 25)
        RNDX().Rect(0, 0, width, height):Rad(self:_Y(22))
            :Color(_SC_COL_EMPTY_OUT2):Outline(self:_Y(2)):Shadow(25 + math.floor(hoverFrac * 12), 39):Draw()

        -- r/g/b interpolate with hoverFrac/pressFrac — dynamic Color() accepted
        local createBtnColor = Color(
            math.floor(Lerp(hoverFrac, 77, 96)),
            math.floor(Lerp(hoverFrac, 77, 92)),
            math.floor(Lerp(hoverFrac, 77, 108)),
            255
        )
        if pressFrac > 0 then
            createBtnColor = Color(
                math.max(0, createBtnColor.r - 8),
                math.max(0, createBtnColor.g - 8),
                math.max(0, createBtnColor.b - 8), 255)
        end
        RNDX().Rect(width * .5 - self:_X(316 / 2), height - self:_Y(64 + 46), self:_X(316), self:_Y(64))
            :Rad(self:_Y(23)):Color(createBtnColor):Draw()
        _SC_COL_EMPTY_BTN_OUT.a = 30 + math.floor(hoverFrac * 55)
        RNDX().Rect(width * .5 - self:_X(316 / 2), height - self:_Y(64 + 46), self:_X(316), self:_Y(64))
            :Rad(self:_Y(23)):Color(_SC_COL_EMPTY_BTN_OUT):Outline(self:_Y(2)):Draw()
        draw.SimpleText(VERSE.L("character.create_character_text"),
            Font:GetNamed("Poppins", "Bold", 25),
            width * .5, height - self:_Y(79),
            color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    -- ── Slot occupé ───────────────────────────────────────────────────────────
    _SC_COL_CHAR_BG.a = 45 + math.floor(hoverFrac * 18)
    Materials:Draw(_SC_COL_CHAR_BG, self._bgKey or "character_create_char_back", 0, 0, width, height)
    _SC_COL_CHAR_DARK.a = 228 - math.floor(hoverFrac * 12)
    RNDX().Rect(0, 0, width, height):Rad(self:_Y(22))
        :Color(_SC_COL_CHAR_DARK):Draw()
    _SC_COL_CHAR_OUT1.a = 100 + math.floor(hoverFrac * 40)
    RNDX().Rect(0, 0, width, height):Rad(self:_Y(22))
        :Color(_SC_COL_CHAR_OUT1):Outline(self:_Y(2)):Draw()
    _SC_COL_CHAR_OUT2.a = 50 + math.floor(hoverFrac * 20)
    RNDX().Rect(0, 0, width, height):Rad(self:_Y(22))
        :Color(_SC_COL_CHAR_OUT2):Outline(self:_Y(1)):Shadow(25 + math.floor(hoverFrac * 12), 39):Draw()

    Materials:Draw(color_white, "character_japan_icon",
        width * .5 - self:_X(55 / 2), self:_Y(39), self:_X(55), self:_Y(55))

    draw.SimpleText(
        self._factionName ~= "" and self._factionName or "Sans faction",
        Font:GetNamed("Poppins", "Medium", 24),
        width * 0.5, self:_Y(42),
        _SC_COL_FACTION, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local lineY = self:_Y(62)
    local lineW = self:_X(170)
    RNDX().Rect(self:_X(42),              lineY, lineW, self:_Y(2)):Rad(self:_Y(1)):Color(_SC_COL_DIVIDER):Draw()
    RNDX().Rect(width - self:_X(42) - lineW, lineY, lineW, self:_Y(2)):Rad(self:_Y(1)):Color(_SC_COL_DIVIDER):Draw()

    draw.SimpleText(
        self._displayName ~= "" and self._displayName or ("Personnage " .. tostring(self._slot or 1)),
        Font:GetNamed("Poppins", "Bold", 34),
        width * 0.5, self:_Y(104),
        color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText(
        self._levelText or "Niveau 1",
        Font:GetNamed("Poppins", "Medium", 18),
        width * 0.5, self:_Y(138),
        _SC_COL_LEVEL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local btnW = self:_X(350)
    local btnH = self:_Y(64)
    local btnX = width * 0.5 - btnW * 0.5
    local btnY = height - btnH - self:_Y(46)
    -- r/g/b interpolate with hoverFrac/pressFrac — dynamic Color() accepted
    local playColor = Color(
        math.floor(Lerp(hoverFrac, 77,  96)),
        math.floor(Lerp(hoverFrac, 77,  90)),
        math.floor(Lerp(hoverFrac, 77, 108)),
        220
    )
    if pressFrac > 0 then
        playColor = Color(
            math.max(0, playColor.r - 10),
            math.max(0, playColor.g - 10),
            math.max(0, playColor.b - 10),
            playColor.a)
    end
    RNDX().Rect(btnX, btnY, btnW, btnH):Rad(self:_Y(23)):Color(playColor):Draw()
    _SC_COL_PLAY_OUT.a = 50 + math.floor(hoverFrac * 50)
    RNDX().Rect(btnX, btnY, btnW, btnH):Rad(self:_Y(23))
        :Color(_SC_COL_PLAY_OUT):Outline(self:_Y(2)):Draw()
    draw.SimpleText("Jouer", Font:GetNamed("Poppins", "Bold", 28),
        width * 0.5, btnY + btnH * 0.5,
        color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

VERSE.VGUI.RegisterNS("Characters", "VCSlotCard", PANEL, "MantleBtn", {
    source    = "modules/characters/vgui/cl_slot_card.lua",
    overwrite = true,
})
