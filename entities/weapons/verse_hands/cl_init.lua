include("shared.lua")

local CLR_DEFAULT = Color(255, 255, 255, 120)
local CLR_CAN_GRAB = Color(255, 255, 255, 220)
local CLR_HOLDING = Color(130, 200, 255, 240)
local CLR_SHADOW = Color(0, 0, 0, 120)

function SWEP:DrawHUD()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local cx = ScrW() * 0.5
    local cy = ScrH() * 0.5
    local col = CLR_DEFAULT
    local radius = 3
    local thickness = 1

    if self:GetIsHolding() then
        col = CLR_HOLDING
        radius = 5
        thickness = 2
    else
        local tr = util.TraceLine({
            start = owner:EyePos(),
            endpos = owner:EyePos() + owner:GetAimVector() * self.CFG.GRAB_RANGE,
            filter = owner,
        })
        if tr.Hit and IsValid(tr.Entity) and self:CanGrabEntity(tr.Entity) then
            col = CLR_CAN_GRAB
            radius = 4
        end
    end

    draw.NoTexture()
    surface.SetDrawColor(CLR_SHADOW)
    surface.DrawCircle(cx + 1, cy + 1, radius, CLR_SHADOW)
    surface.SetDrawColor(col)
    surface.DrawCircle(cx, cy, radius, col)

    if thickness > 1 then
        surface.DrawCircle(cx, cy, radius - 1, col)
    end
end

function SWEP:DrawWorldModel() end
function SWEP:ViewModelDrawn() end

function SWEP:ShouldDrawViewModel()
    return false
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end