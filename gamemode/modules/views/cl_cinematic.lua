VERSE.Cinematic = VERSE.Cinematic or {}
local C = VERSE.Cinematic

C.Active = C.Active or false
C._fade = C._fade or 0

local BAR_RATIO = 0.15
local FADE_TIME = 0.49

local HIDE_NAMES = {
    CHudHealth = true,
    CHudBattery = true,
    CHudSuitPower = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudCrosshair = true,
    CHudWeaponSelection = true,
    CHudDamageIndicator = true,
    CHudDeathNotice = true,
    CHudHintDisplay = true,
    CHudZoom = true,
    CTargetID = true,
    HUDDrawPickupHistory = true,
    OnScreenHint = true,
    CHudChat = true,
}

function C:IsActive()
    return self.Active
end

function C:IsHUDHidden()
    return self.Active or self._fade > 0.01
end

function C:SetActive(on)
    self.Active = on and true or false
end

function C:Toggle()
    self:SetActive(not self.Active)
end

local function hideHUD()
    if C:IsHUDHidden() then return false end
end

VERSE.Hook.AddNS("Cinematic", "HUDShouldDraw", "VERSE::HUDShouldDraw::Cinematic", function(name)
    if HIDE_NAMES[name] and C:IsHUDHidden() then return false end
end)

VERSE.Hook.AddNS("Cinematic", "HUDDrawTargetID", "VERSE::HUDDrawTargetID::Cinematic", hideHUD)
VERSE.Hook.AddNS("Cinematic", "HUDDrawPickupHistory", "VERSE::HUDDrawPickupHistory::Cinematic", hideHUD)

VERSE.Hook.AddNS("Cinematic", "HUDPaint", "VERSE::HUDPaint::Cinematic::Bars", function()
    local target = C.Active and 1 or 0
    C._fade = math.Approach(C._fade, target, RealFrameTime() / FADE_TIME)
    -- Bandes noires désactivées temporairement
    -- if C._fade <= 0.001 then return end
    -- local sw, sh = ScrW(), ScrH()
    -- local h = math.floor(sh * BAR_RATIO * C._fade + 0.5)
    -- if h <= 0 then return end
    -- surface.SetDrawColor(0, 0, 0, 255)
    -- surface.DrawRect(0, 0, sw, h)
    -- surface.DrawRect(0, sh - h, sw, h)
end)

concommand.Add("verse_cinematic", function()
    C:Toggle()
end)
