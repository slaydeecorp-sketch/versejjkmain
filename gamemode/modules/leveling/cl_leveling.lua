local LVL = VERSE.Leveling
local R = VERSE.Responsive

if not LVL then return end

local _popup = nil
local _popupStart = 0
local POPUP_FADE_IN  = 0.3
local POPUP_HOLD     = 3.5
local POPUP_FADE_OUT = 0.5
local POPUP_TOTAL    = POPUP_FADE_IN + POPUP_HOLD + POPUP_FADE_OUT

local _levelupMat = Material("verse/character/levelup.png", "noclamp smooth")

local function showLevelUpPopup()
    _popupStart = RealTime()
    _popup = true
    LocalPlayer():EmitSound("verse/character/levelup.mp3", 75, 100, 0.5)
end

VERSE.Hook.AddNS("Leveling", "HUDPaint", "VERSE::Leveling::Popup", function()
    if not _popup then return end

    local age = RealTime() - _popupStart
    if age > POPUP_TOTAL then
        _popup = nil
        return
    end

    local alpha
    if age < POPUP_FADE_IN then
        alpha = age / POPUP_FADE_IN
    elseif age < POPUP_FADE_IN + POPUP_HOLD then
        alpha = 1
    else
        alpha = 1 - (age - POPUP_FADE_IN - POPUP_HOLD) / POPUP_FADE_OUT
    end
    alpha = math.Clamp(alpha, 0, 1)

    local sw = ScrW()
    local popW = R:X(320)
    local popH = R:Y(110)
    local px   = (sw - popW) / 2
    local py   = R:Y(180)
    local slideY = py - R:Y(20) * (1 - alpha)

    surface.SetMaterial(_levelupMat)
    surface.SetDrawColor(255, 255, 255, math.floor(255 * alpha))
    surface.DrawTexturedRect(px, slideY, popW, popH)
end)

netstream.Hook(LVL.Net.LevelUp, function(data)
    if not istable(data) then return end
    showLevelUpPopup()
end)
