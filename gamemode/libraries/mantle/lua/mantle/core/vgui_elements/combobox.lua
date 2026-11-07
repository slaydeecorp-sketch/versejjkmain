local PANEL = {}
local HEIGHT = 32
local PAD = 12
local RADIUS = 12
function PANEL:Init()
    self.choices = {}
    self.selected = nil
    self.opened = false
    self:SetTall(HEIGHT)
    self:SetText('')
    self.hoverAnim = 0
    self.OnSelect = function(_, _, _) end
    self._fontText = 'Fated.16'
    self._fontPlaceholder = nil
    self._fontMenu = 'Fated.16'
    self.btn = vgui.Create('Button', self)
    self.btn:Dock(FILL)
    self.btn:DockMargin(0, 0, 0, 0)
    self.btn:SetText('')
    self.btn:SetCursor('hand')
    self.btn.Paint = function(s, w, h)
        if s:IsHovered() then
            self.hoverAnim = Mantle.func.approachExp(self.hoverAnim, 1, 8, FrameTime())
        else
            self.hoverAnim = Mantle.func.approachExp(self.hoverAnim, 0, 12, FrameTime())
        end

        if Mantle.ui.convar.depth_ui then RNDX().Rect(0, 0, w, h):Rad(12):Color(Mantle.color.window_shadow):Shadow(4, 9):Outline(1):Draw() end
        RNDX().Rect(0, 0, w, h):Rad(RADIUS):Color(Mantle.color.focus_panel):Draw()
        if self.hoverAnim > 0 then
            local hcol = Color(Mantle.color.hover.r, Mantle.color.hover.g, Mantle.color.hover.b, math.floor(255 * self.hoverAnim))
            RNDX().Rect(0, 0, w, h):Rad(RADIUS):Color(hcol):Draw()
        end

        local text = self.selected or self.placeholder or (Mantle.lang.get('mantle', 'color_select') .. '...')
        local col = self.selected and Mantle.color.text or Mantle.color.gray
        local fontText = self._fontText or 'Fated.16'
        local fontPh = self._fontPlaceholder or fontText
        local useFont = (self.selected ~= nil) and fontText or fontPh
        draw.SimpleText(text, useFont, PAD, h * 0.5, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local arrowSize = 6
        local ax = w - PAD - arrowSize
        local ay = h * 0.5
        surface.SetDrawColor(col)
        draw.NoTexture()
        surface.DrawPoly({
            {
                x = ax - arrowSize,
                y = ay - arrowSize / 2
            },
            {
                x = ax + arrowSize,
                y = ay - arrowSize / 2
            },
            {
                x = ax,
                y = ay + arrowSize / 2
            },
        })
    end

    self.btn.DoClick = function()
        if self.opened then
            self:CloseMenu()
        else
            self:OpenMenu()
            Mantle.func.sound()
        end
    end
end

function PANEL:AddChoice(text, data)
    table.insert(self.choices, {
        text = text,
        data = data
    })
end

function PANEL:SetValue(val)
    self.selected = val
end

function PANEL:GetValue()
    return self.selected
end

function PANEL:SetPlaceholder(text)
    self.placeholder = text
end

function PANEL:OpenMenu()
    if IsValid(self.menu) then self.menu:CloseMenu() end
    local x, y = self:LocalToScreen(0, self:GetTall())
    local menu = vgui.Create('MantleDermaMenu')
    menu:SetParent(nil)
    menu:SetPos(x, y)
    local menuFont = self._fontMenu or self._fontText or 'Fated.16'
    for i, choice in ipairs(self.choices) do
        local function onClick()
            self.selected = choice.text
            self.selectedData = choice.data
            if IsValid(menu) then menu:CloseMenu() end
            if self.OnSelect then self.OnSelect(i, choice.text, choice.data) end
            Mantle.func.sound()
        end

        local opt = menu:AddOption(choice.text, onClick)
        if IsValid(opt) and opt.SetFont then opt:SetFont(menuFont) end
    end

    menu:MakePopup()
    menu:SetKeyboardInputEnabled(false)
    menu._initPosSet = false
    if menu.UpdateSize then menu:UpdateSize() end
    self.menu = menu
    self.opened = true
    menu.OnRemove = function() if IsValid(self) then self.opened = false end end
end

function PANEL:CloseMenu()
    if IsValid(self.menu) then self.menu:CloseMenu() end
    self.opened = false
end

function PANEL:OnRemove()
    self:CloseMenu()
end

function PANEL:SetSelectedByData(data)
    for _, c in ipairs(self.choices or {}) do
        if c.data == data then
            self.selected = c.text
            self.selectedData = c.data
            return true
        end
    end
    return false
end

function PANEL:SetSelected(text, data)
    self.selected = text
    self.selectedData = data
end

function PANEL:GetSelectedData()
    return self.selectedData
end

function PANEL:SetFonts(textFont, menuFont, placeholderFont)
    if isstring(textFont) and textFont ~= '' then self._fontText = textFont end
    if isstring(menuFont) and menuFont ~= '' then self._fontMenu = menuFont end
    if isstring(placeholderFont) and placeholderFont ~= '' then self._fontPlaceholder = placeholderFont end
    return self
end

function PANEL:SetTextFont(font)
    if isstring(font) and font ~= '' then self._fontText = font end
    return self
end

function PANEL:SetMenuFont(font)
    if isstring(font) and font ~= '' then self._fontMenu = font end
    return self
end

function PANEL:SetPlaceholderFont(font)
    if isstring(font) and font ~= '' then self._fontPlaceholder = font end
    return self
end

vgui.Register('MantleComboBox', PANEL, 'Panel')