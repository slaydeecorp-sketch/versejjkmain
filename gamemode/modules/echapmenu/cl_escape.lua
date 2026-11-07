local ESC = VERSE.Escape
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local Math = VERSE.Math

ESC._frame = ESC._frame or nil

local function shouldSuppressOpen()
    return VERSE._SuppressPauseMenuOpen == true
end

local function getTopBlockingMantleFrame()
    local frames = VERSE._MantleFrames or nil
    if not istable(frames) then return nil end

    local topFrame = nil
    local topOrder = -1

    for frame in pairs(frames) do
        if frame ~= ESC._frame and IsValid(frame) and not frame._isEscapeMenuFrame then
            local order = tonumber(frame._mantleFrameOrder) or 0
            if order >= topOrder then
                topOrder = order
                topFrame = frame
            end
        end
    end

    return topFrame
end

VERSE.Hook.AddNS("Escape", "InitPostEntity", "VERSE::InitPostEntity::Escape", function()
    Materials:SetAlias("escape_background", "verse/echapmenu/main_background")
    Materials:SetAlias("escape_logo", "verse/echapmenu/verse_logo")
    Materials:SetAlias("escape_boutique_icon", "verse/echapmenu/boutique_icon")
    Materials:SetAlias("escape_boutique_button", "verse/echapmenu/boutique_btn")
    Materials:SetAlias("escape_boutique_characters", "verse/echapmenu/boutique_characters")
end)

VERSE.Hook.AddNS("Escape", "Think", "VERSE::Think::EscapeSuppression", function()
    if VERSE._SuppressPauseMenuOpen and not input.IsKeyDown(KEY_ESCAPE) then
        VERSE._SuppressPauseMenuOpen = nil
    end
end)

function ESC:IsOpen()
    return IsValid(self._frame)
end

function ESC:Close()
    if self:IsOpen() then self._frame:Close() end
    self._frame = nil
    Mantle.func.sound()
end

local BTN_W = 400
local BTN_H = 80
local GAP_Y = 30
local START_X = 185
local START_Y = 300

local function HoverFrac(s, halflife)
    s._hoverFrac = s._hoverFrac or 0
    local target = s:IsHovered() and 1 or 0
    s._hoverFrac = Math.ApproachExp(s._hoverFrac, target, halflife or 0.08, FrameTime())
    return s._hoverFrac
end

function ESC:BuildButtons(parent)
    if not IsValid(parent) then return end

    local buttons = self.Config.Buttons or {}
    for i, cfg in ipairs(buttons) do
        local x = START_X
        local y = START_Y + (i - 1) * (BTN_H + GAP_Y)

        local btn = vgui.Create("MantleBtn", parent)
        btn:SetSize(R:XY(BTN_W, BTN_H))
        btn:SetPos(R:XY(x, y))
        btn:SetText("")

        local font = Font:GetNamed("Poppins", "Bold", 30)
        local text = cfg.text or ""
        local textW = VERSE.GetTextSize(text, font)
        local iconW = R:X(cfg.iconX or 0)
        local iconH = R:Y(cfg.iconY or 0)
        local spacing = R:X(10)
        local totalW = iconW + spacing + textW
        btn._hoverT = btn._hoverT or 0
        btn._shine = btn._shine or 0
        btn._pulse = btn._pulse or 0

        -- Couleurs pré-allouées pour ce bouton (évite Color() par frame)
        local _btnColShine   = Color(255, 255, 255, 0)    -- .a muté (shine)
        local _btnColLine    = Color(cfg.color.r, cfg.color.g, cfg.color.b, 180)  -- .r/.g/.b stables, .a stable
        local _btnColIcon    = Color(cfg.color.r, cfg.color.g, cfg.color.b, 0)    -- .a muté
        local _btnColTxt     = Color(cfg.color.r, cfg.color.g, cfg.color.b, 0)    -- .a muté
        local _btnColOutline = Color(0, 0, 0, 0)          -- .a muté

        btn.Paint = function(s, w, h)
            local dt = FrameTime()
            local t = HoverFrac(s, 0.1)
            if t > 0.01 then
                s._shine = (s._shine + dt * 1.35) % 1
            else
                s._shine = Math.ApproachExp(s._shine, 0, 0.10, dt)
            end

            s._pulse = (s._pulse or 0) + dt * 6
            Materials:Draw(color_white, cfg.btnBackground, 0, 0, w, h, "noclamp smooth")

            local slideX = R:X(16) * t
            local liftY  = -R:Y(2) * t
            if t > 0.01 then
                local shineW = w * 0.28
                local shineH = h * 1.6
                local shineX = Math.Lerp(-shineW, w + shineW, s._shine)
                local shineY = -h * 0.3

                _btnColShine.a = math.floor(20 * t)
                RNDX().Rect(shineX, shineY, shineW, shineH)
                    :Rad(R:Y(10))
                    :Color(_btnColShine)
                    :Rotation(20)
                    :Draw()
            end

            local lineW = (w * 0.72) * t
            if lineW > 0.5 then
                local lineH = R:Y(4)
                local lineX = (w - lineW) * 0.5
                local lineY = h - R:Y(10)
                RNDX().Rect(lineX, lineY, lineW, lineH)
                    :Rad(R:Y(2))
                    :Color(_btnColLine)
                    :Draw()
            end

            local startX = (w - totalW) * 0.5 + slideX
            local iconY = h * 0.5 - iconH * 0.5 - R:Y(2) + liftY
            local textY = h * 0.5 + liftY
            local breath = (math.sin(s._pulse) * 0.5 + 0.5)
            local iconA = 200 + math.floor(55 * t)
            local textA = 210 + math.floor(45 * t)

            if t > 0.01 then
                iconA = iconA + math.floor(15 * breath * t)
                textA = textA + math.floor(10 * breath * t)
            end

            _btnColIcon.a = iconA
            Materials:Draw(_btnColIcon, cfg.icon, startX, iconY, iconW, iconH, "mips smooth")

            _btnColTxt.a = textA
            draw.SimpleText(text, font, startX + iconW + spacing, textY, _btnColTxt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            if t > 0.01 then
                _btnColOutline.a = math.floor(60 * t)
                RNDX().Rect(0, 0, w, h)
                    :Rad(R:Y(10))
                    :Outline(R:Y(2))
                    :Color(_btnColOutline)
                    :Draw()
            end
        end

        btn.DoClick = function()
            Mantle.func.sound()
            if isfunction(cfg.callback) then cfg.callback() end
        end
    end
end

local function OpenURLSafe(url)
    if not isstring(url) or url == "" then return end
    gui.OpenURL(url)
end

function ESC:HandleButton(id)
    if not id then return end

    if id == "resume" then
        self:Close()
        return
    end

    if id == "discord" then
        OpenURLSafe(self.Config.Links and self.Config.Links.Discord)
        return
    end

    if id == "wiki" then
        OpenURLSafe(self.Config.Links and self.Config.Links.Wiki)
        return
    end

    if id == "characters" then
        self:Close()
        RunConsoleCommand("verse_characters")
        return
    end

    if id == "settings" then
        gui.ActivateGameUI()
        RunConsoleCommand("gamemenucommand", "openoptionsdialog")
        self:Close()
        return
    end

    if id == "bind" then
        self:Close()
        if VERSE.Keybinds and VERSE.Keybinds.OpenBindMenu then
            VERSE.Keybinds.OpenBindMenu()
        end
        return
    end

    if id == "disconnect" then
        RunConsoleCommand("disconnect")
        return
    end

    if id == "boutique" then
        self:Close()
        if VERSE.Boutique and VERSE.Boutique.OpenUI then
            VERSE.Boutique:OpenUI()
        end
        return
    end
end

function ESC:Open()
    if self:IsOpen() then
        self._frame:MakePopup()
        self._frame:RequestFocus()
        return
    end

    local fr = vgui.Create("MantleFrame")
    if not IsValid(fr) then return end

    self._frame = fr
    fr._isEscapeMenuFrame = true
    fr:SetSize(R:XY(1920, 1080))
    fr:Center()
    fr:MakePopup()
    fr:RequestFocus()
    fr:SetDraggable(false)
    fr:LiteMode()
    fr:SetAlphaBackground(false)
    fr:SetClosable(false)
    fr:DisableCloseBtn()
    ESC:BuildButtons(fr)

    local _escBgCol    = Color(255, 255, 255, 240)
    local _escLabelCol = Color(190, 190, 190, 255)
    local _escCountFont = Font:GetNamed("Poppins", "Bold", 35)
    fr.Paint = function(s, w, h)
        Materials:DrawDuplicate(_escBgCol, "escape_background", 0, 0, w, h, "noclamp smooth")
        Materials:Draw(color_white, "escape_logo", R:X(212), R:Y(104), R:X(340), R:Y(131), "noclamp smooth")
        Materials:Draw(color_white, "escape_boutique_characters", R:X(1920 - 817), R:Y(1080 - 459 - 230), R:X(817), R:Y(459), "noclamp smooth")

        local countText = string.format("%d/%d", #player.GetAll(), game.MaxPlayers())
        local labelText = "joueurs connectés"
        local countW = VERSE.GetTextSize(countText, _escCountFont)
        local labelW = VERSE.GetTextSize(labelText, _escCountFont)
        local spacing = R:X(5)
        local totalW = countW + spacing + labelW
        local x = R:X(1920 - 43)
        local y = R:Y(46)
        draw.SimpleText(countText, _escCountFont, x - (totalW - countW), y + R:Y(1), color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(labelText, _escCountFont, x, y, _escLabelCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local oldOnClose = fr.OnClose
    fr.OnClose = function(s)
        oldOnClose(s)
        if ESC._frame == fr then ESC._frame = nil end
    end

    local boutiqueBtn = vgui.Create("MantleBtn", fr)
    boutiqueBtn:SetSize(R:XY(900, 186))
    boutiqueBtn:SetPos(R:XY(1920 - 900 + 40, 1080 - 186 - 56))
    boutiqueBtn:SetText("")

    local _boutAccent    = Color(169, 89, 255, 255)
    local _boutLineCol   = Color(169, 89, 255, 180)
    local _boutTitleFont = Font:GetNamed("Poppins", "Bold", 120)
    boutiqueBtn.Paint = function(s, w, h)
        local t = HoverFrac(s, 0.1)
        Materials:Draw(color_white, "escape_boutique_button", 0, 0, w, h, "noclamp smooth")

        local slideX = R:X(18) * t
        local size = 67
        Materials:Draw(_boutAccent, "escape_boutique_icon", R:X(200) + slideX, h * 0.5 - R:Y(size / 2 + 10), R:X(size), R:Y(size), "noclamp smooth")
        draw.SimpleText("BOUTIQUE", _boutTitleFont, w * 0.5 + R:X(5) + slideX, h * 0.5, _boutAccent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local lineW = w * 0.6 * t
        local lineH = R:Y(4)
        local lineX = (w - lineW) * 0.5
        local lineY = h - R:Y(14)

        if t > 0.001 then
            RNDX().Rect(lineX, lineY, lineW, lineH)
                :Rad(R:Y(2))
                :Color(_boutLineCol)
                :Draw()
        end
    end

    boutiqueBtn.DoClick = function(s)
        ESC:HandleButton("boutique")
    end
end

VERSE.Hook.AddNS("Escape", "OnPauseMenuShow", "VERSE::OnPauseMenuShow::Escape", function()
    if shouldSuppressOpen() then
        return false
    end

    local blockingFrame = getTopBlockingMantleFrame()
    if IsValid(blockingFrame) then
        if blockingFrame.allowEscClose then
            VERSE._SuppressPauseMenuOpen = true
            blockingFrame:Close()
            Mantle.func.sound()
        end
        return false
    end

    if ESC:IsOpen() then
        ESC:Close()
        return false
    end

    ESC:Open()
    return false
end)
