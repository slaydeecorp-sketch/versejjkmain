local PANEL = {}
function PANEL:Init()
    self.title = nil
    self.placeholder = Mantle.lang.get('mantle', 'entry_default_placeholder')
    self:SetTall(26)
    self.action = function() end
    self.fontText = 'Fated.18'
    self.fontTitle = 'Fated.18'
    self.textEntry = vgui.Create('DTextEntry', self)
    self.textEntry:Dock(FILL)
    self.textEntry:SetText('')
    if self.textEntry.SetPaintBackground then self.textEntry:SetPaintBackground(false) end
    if self.textEntry.SetDrawLanguageID then self.textEntry:SetDrawLanguageID(false) end
    if self.textEntry.SetTextInset then self.textEntry:SetTextInset(6, 0) end
    self.textEntry.OnCloseFocus = function() self.action(self:GetValue()) end
    self.textEntry.OnEnter = function()
        if self._onEnter then self._onEnter(self:GetValue()) end
        self.action(self:GetValue())
    end

    self.textEntry.OnValueChange = function(_, val) if self._updateOnType and self._onValueChanged then self._onValueChanged(val) end end
    self._shadowLerp = 5
    self.textEntry.Paint = function(s, w, h)
        local ft = FrameTime()
        if Mantle.ui.convar.depth_ui then
            local target = s:IsEditing() and 8 or 4
            self._shadowLerp = Mantle.func.approachExp(self._shadowLerp, target, 4, ft)
            RNDX().Rect(0, 0, w, h):Rad(12):Color(Mantle.color.window_shadow):Shadow(self._shadowLerp, 9):Outline(1):Draw()
        end

        RNDX().Rect(0, 0, w, h):Rad(12):Color(Mantle.color.focus_panel):Draw()
        local value = self:GetValue() or ''
        local fontText = self.fontText or 'Fated.18'
        if s.SetFontInternal then s:SetFontInternal(fontText) end
        if s.SetFont then s:SetFont(fontText) end
        local placeholderCol = self._placeholderCol or Mantle.color.gray
        local textCol = self._textCol or Mantle.color.text
        local theme = Mantle.color.theme or textCol
        local highlightCol = self._highlightCol or Color(theme.r, theme.g, theme.b, 120)
        local cursorCol = self._cursorCol or theme
        local isFocused = s:HasFocus() or s:IsEditing()
        if value == '' and not isFocused then
            draw.SimpleText(self.placeholder, fontText, 6, h * 0.5, placeholderCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return true
        end

        s:DrawTextEntryText(textCol, highlightCol, cursorCol)
        return true
    end
    self.textEntry.PaintOver = nil
end

function PANEL:SetTitle(title)
    self.title = title
    self:SetTall(52)
    if IsValid(self.titlePanel) then self.titlePanel:Remove() end
    self.titlePanel = vgui.Create('DPanel', self)
    self.titlePanel:Dock(TOP)
    self.titlePanel:DockMargin(0, 0, 0, 6)
    self.titlePanel:SetTall(18)
    self.titlePanel.Paint = function(_, w, h)
        local fontTitle = self.fontTitle or 'Fated.18'
        draw.SimpleText(self.title, fontTitle, 0, 0, Mantle.color.text)
    end
end

function PANEL:SetPlaceholder(placeholder)
    self.placeholder = placeholder
end

function PANEL:GetValue()
    return self.textEntry:GetText()
end

function PANEL:SetValue(value)
    self.textEntry:SetValue(value)
end

function PANEL:SetNumeric(b)
    if IsValid(self.textEntry) then self.textEntry:SetNumeric(b == true) end
end

function PANEL:SetAllowNonAscii(b)
    if IsValid(self.textEntry) then self.textEntry:SetAllowNonAsciiCharacters(b == true) end
end

function PANEL:SetUpdateOnType(b)
    self._updateOnType = b == true
end

function PANEL:SetOnValueChanged(fn)
    self._onValueChanged = isfunction(fn) and fn or nil
end

function PANEL:SetOnEnter(fn)
    self._onEnter = isfunction(fn) and fn or nil
end

function PANEL:RequestFocus()
    if IsValid(self.textEntry) then self.textEntry:RequestFocus() end
end

function PANEL:SetPlaceholderColor(col)
    self._placeholderCol = col
end

function PANEL:SetTextColor(col)
    self._textCol = col
end

function PANEL:SetHighlightColor(col)
    self._highlightCol = col
end

function PANEL:SetCursorColor(col)
    self._cursorCol = col
end

function PANEL:SetFonts(textFont, titleFont)
    if isstring(textFont) and textFont ~= '' then
        self.fontText = textFont
    end

    if isstring(titleFont) and titleFont ~= '' then
        self.fontTitle = titleFont
    end

    return self
end

function PANEL:SetTextFont(font)
    if isstring(font) and font ~= '' then
        self.fontText = font
    end
    return self
end

function PANEL:SetTitleFont(font)
    if isstring(font) and font ~= '' then
        self.fontTitle = font
    end
    return self
end

vgui.Register('MantleEntry', PANEL, 'EditablePanel')
