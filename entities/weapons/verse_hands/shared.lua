SWEP.PrintName = "Hands"
SWEP.Author = ""
SWEP.Category = "VERSE | Main"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.UseHands = true
SWEP.Slot = 0
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""

SWEP.CFG = {
    GRAB_RANGE = 120,
    HOLD_DISTANCE = 75,
    MAX_HOLD_DISTANCE = 200,
    MAX_MASS = 100,
    MAX_VELOCITY = 600,
    THROW_VELOCITY = 350,
}

function SWEP:SetupDataTables()
    self:NetworkVar("Entity", 0, "GrabbedEntity")
    self:NetworkVar("Bool", 0, "IsHolding")
end

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:Deploy()
    self:SetHoldType("normal")
    return true
end

local BLOCKED_CLASSES = {
    ["player"] = true,
    ["worldspawn"] = true,
}

function SWEP:CanGrabEntity(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() or ent:IsNPC() or ent:IsVehicle() or ent:IsWorld() then return false end
    if BLOCKED_CLASSES[ent:GetClass()] then return false end
    if ent.VerseNoGrab then return false end

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return false end
    if not phys:IsMotionEnabled() then return false end
    if phys:GetMass() > self.CFG.MAX_MASS then return false end

    if IsValid(ent._VerseHandsHolder) and ent._VerseHandsHolder ~= self:GetOwner() then
        return false
    end

    return true
end
