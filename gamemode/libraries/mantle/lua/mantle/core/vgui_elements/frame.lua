local R = VERSE.Responsive
local PANEL = {}
local mat_close = Material('verse/ui/close_btn_new.png')

VERSE._MantleFrames = VERSE._MantleFrames or setmetatable({}, { __mode = 'k' })

local function suppressPauseMenuOpen()
    VERSE._SuppressPauseMenuOpen = true
end

local function registerMantleFrame(frame)
    VERSE._MantleFrames[frame] = true
    VERSE._ActiveFrames = (VERSE._ActiveFrames or 0) + 1
end

local function unregisterMantleFrame(frame)
    if not VERSE._MantleFrames[frame] then return end
    VERSE._MantleFrames[frame] = nil
    VERSE._ActiveFrames = math.max((VERSE._ActiveFrames or 1) - 1, 0)
end

function PANEL:Init()
    self.bool_alpha = true
    self.bool_lite = false
    self.title = Mantle.lang.get('mantle', 'frame_title')
    self.center_title = ''
    self.allowEscClose = true
    VERSE._MantleFrameOrderSeq = (VERSE._MantleFrameOrderSeq or 0) + 1
    self._mantleFrameOrder = VERSE._MantleFrameOrderSeq
    self:SetKeyboardInputEnabled(true)
    self:DockPadding(R:X(6), R:Y(30), R:X(6), R:Y(6))
    registerMantleFrame(self)

    self.Think = function(s)
        if not s.allowEscClose then return end
        if input.WasKeyPressed and input.WasKeyPressed(KEY_ESCAPE) and IsValid(s) then
            suppressPauseMenuOpen()
            s:Close()
            Mantle.func.sound()
        end
    end

    self.top_panel = vgui.Create('Button', self)
    self.top_panel:SetText('')
    self.top_panel:SetCursor('sizeall')
    self.top_panel.Paint = nil
    self.top_panel.OnMousePressed = function(s, key)
        if key == MOUSE_LEFT then
            self.Dragging = {gui.MouseX() - self.x, gui.MouseY() - self.y}
            s:MouseCapture(true)
            self:SetAlpha(200)
        end
    end

    self.top_panel.OnMouseReleased = function(s, key)
        if key == MOUSE_LEFT then
            self.Dragging = nil
            s:MouseCapture(false)
            self:SetAlpha(255)
        end
    end

    self.top_panel.Think = function(s)
        if self.Dragging then
            local mouseX, mouseY = gui.MousePos()
            local newPosX, newPosY = mouseX - self.Dragging[1], mouseY - self.Dragging[2]
            self:SetPos(newPosX, newPosY)
        end
    end

    self.cls = vgui.Create('Button', self)
    self.cls:SetText('')
    self.cls.Paint = function(_, w, h) RNDX().Rect(R:X(2), R:Y(2), w - R:X(4), h - R:Y(4)):Color(Mantle.color.header_text):Material(mat_close):Draw() end
    self.cls.DoClick = function()
        self:Close()
        Mantle.func.sound()
    end

    self.cls.DoRightClick = function()
        local DM = Mantle.ui.derma_menu()
        DM:AddOption(Mantle.lang.get('mantle', 'frame_alpha'), function() self.bool_alpha = not self.bool_alpha end, self.bool_alpha and 'icon16/bullet_green.png' or 'icon16/bullet_red.png')
        local boolInput = self:IsKeyboardInputEnabled()
        DM:AddOption(Mantle.lang.get('mantle', 'frame_move_from_menu'), function() self:SetKeyboardInputEnabled(not boolInput) end, not boolInput and 'icon16/bullet_green.png' or 'icon16/bullet_red.png')
        DM:AddOption(Mantle.lang.get('mantle', 'frame_close_window'), function() self:Remove() end, 'icon16/cross.png')
    end
end

function PANEL:SetClosable(state)
    self.allowEscClose = state and true or false
end

function PANEL:SetAlphaBackground(is_alpha)
    self.bool_alpha = is_alpha
end

function PANEL:SetTitle(title)
    self.title = title
end

function PANEL:SetCenterTitle(center_title)
    self.center_title = center_title
end

function PANEL:ShowAnimation()
    Mantle.func.animate_appearance(self, self:GetWide(), self:GetTall(), 0.3, 0.2)
end

function PANEL:Close()
    self:AlphaTo(0, 0.1, 0, function() self:Remove() end)
end

function PANEL:OnRemove()
    unregisterMantleFrame(self)
end

function PANEL:DisableCloseBtn()
    self.cls:SetVisible(false)
end

function PANEL:SetDraggable(is_draggable)
    self.top_panel:SetVisible(is_draggable)
end

function PANEL:LiteMode()
    self.bool_lite = true
    self:DockPadding(R:X(6), R:Y(6), R:X(6), R:Y(6))
    self.cls:SetZPos(2)
end

function PANEL:Notify(text, duration, col)
    if self._mantleAppearing then
        Mantle.func.on_appear(self, function(fr)
            if IsValid(fr) then fr:Notify(text, duration, col) end
        end)
        return
    end

    if IsValid(self.messagePanel) then self.messagePanel:Remove() end
    duration = duration or 2
    col = col or Mantle.color.theme
    surface.SetFont('Fated.20')
    local tw, th = surface.GetTextSize(text)
    local padL, padT, padR, padB = self:GetDockPadding()
    local mp = vgui.Create('Panel', self)
    mp:SetMouseInputEnabled(false)
    mp:SetAlpha(0)
    local padX = R:X(16)
    local padY = R:Y(8)
    mp:SetSize(tw + padX, th + padY)
    local innerW = self:GetWide() - padL - padR
    local innerH = self:GetTall() - padT - padB
    local x = math.Round(padL + (innerW - mp:GetWide()) * 0.5)
    local endY = math.Round(padT + innerH - mp:GetTall() - R:Y(16))
    local startY = self:GetTall() + mp:GetTall()
    mp:SetPos(x, startY)
    mp:SetZPos(32767)
    mp.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(16)):Color(col):Shadow(7, 20):Outline(3):Clip(self):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:Y(16)):Color(col):Draw()
        draw.SimpleText(text, 'Fated.20', w * 0.5, h * 0.5 - R:Y(1), Mantle.color.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    mp:MoveTo(x, endY, 0.3, 0, 0.7)
    mp:AlphaTo(255, 0.3, 0, function()
        timer.Simple(duration, function()
            if not IsValid(mp) then return end
            mp:AlphaTo(0, 0.25, 0, function() if IsValid(mp) then mp:Remove() end end)
        end)
    end)

    self.messagePanel = mp
end

function PANEL:Paint(w, h)
    RNDX().Rect(0, 0, w, h):Rad(R:Y(6)):Color(Mantle.color.window_shadow):Shadow(10, 16):Shape(RNDX.SHAPE_IOS):Draw()
    if not self.bool_lite then RNDX().Rect(0, 0, w, R:Y(24)):Radii(R:Y(6), R:Y(6), 0, 0):Color(Mantle.color.header):Draw() end
    local headerTall = self.bool_lite and 0 or R:Y(24)
    if self.bool_alpha and Mantle.ui.convar.blur then RNDX().Rect(0, headerTall, w, h - headerTall):Radii(self.bool_lite and R:Y(6) or 0, self.bool_lite and R:Y(6) or 0, R:Y(6), R:Y(6)):Blur():Draw() end
    if not self.bool_lite then Mantle.func.gradient(0, R:Y(24), w, R:Y(6), 2, Mantle.color.window_shadow) end
    RNDX().Rect(0, headerTall, w, h - headerTall):Radii(self.bool_lite and R:Y(6) or 0, self.bool_lite and R:Y(6) or 0, R:Y(6), R:Y(6)):Color((self.bool_alpha and Mantle.ui.convar.blur) and Mantle.color.background_alpha or Mantle.color.background):Draw()
    if not self.bool_lite then
        if self.center_title ~= '' then draw.SimpleText(self.center_title, 'Fated.20b', w * 0.5, R:Y(12), Mantle.color.header_text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
        draw.SimpleText(self.title, 'Fated.16', R:X(6), R:Y(4), Mantle.color.header_text)
    end
end

function PANEL:PerformLayout(w, h)
    self.top_panel:SetSize(w, R:Y(24))
    self.cls:SetSize(R:X(20), R:Y(20))
    self.cls:SetPos(w - R:X(22), R:Y(2))
end

vgui.Register('MantleFrame', PANEL, 'EditablePanel')