AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function SWEP:PrimaryAttack()
    if self:GetIsHolding() then return end

    self:SetNextPrimaryFire(CurTime() + 0.1)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local tr = util.TraceLine({
        start = owner:EyePos(),
        endpos = owner:EyePos() + owner:GetAimVector() * self.CFG.GRAB_RANGE,
        filter = owner,
    })

    if not tr.Hit or not IsValid(tr.Entity) then return end
    if not self:CanGrabEntity(tr.Entity) then return end

    self:GrabEntity(tr.Entity, tr.HitPos)
end

function SWEP:GrabEntity(ent, hitPos)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end

    local dist = math.Clamp(hitPos:Distance(owner:EyePos()), 40, self.CFG.HOLD_DISTANCE)

    self._heldEnt = ent
    self._holdDistance = dist
    self._origCollisionGroup = ent:GetCollisionGroup()
    self._grabAngles = ent:GetAngles()

    ent._VerseHandsHolder = owner
    ent._VerseHandsDmgDisabled = true
    ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    phys:EnableDrag(false)
    phys:Wake()

    self:SetGrabbedEntity(ent)
    self:SetIsHolding(true)
    self:SetHoldType("fist")
end

function SWEP:DropEntity()
    local ent = self._heldEnt
    if not self:GetIsHolding() and not IsValid(ent) then return end

    if IsValid(ent) then
        local phys = ent:GetPhysicsObject()

        ent._VerseHandsHolder = nil
        ent._VerseHandsDmgDisabled = nil
        ent:SetCollisionGroup(self._origCollisionGroup or COLLISION_GROUP_NONE)

        if IsValid(phys) then
            phys:EnableDrag(true)
            phys:Wake()
        end
    end

    self._heldEnt = nil
    self._holdDistance = nil
    self._origCollisionGroup = nil
    self._grabAngles = nil

    self:SetGrabbedEntity(NULL)
    self:SetIsHolding(false)
    self:SetHoldType("normal")
end

function SWEP:SecondaryAttack()
    if not self:GetIsHolding() then return end

    self:SetNextSecondaryFire(CurTime() + 0.5)

    local ent = self._heldEnt
    local owner = self:GetOwner()
    if not IsValid(ent) or not IsValid(owner) then
        self:DropEntity()
        return
    end

    local phys = ent:GetPhysicsObject()
    self:DropEntity()

    if IsValid(phys) then
        local vel = owner:GetAimVector() * self.CFG.THROW_VELOCITY + Vector(0, 0, 60)
        phys:SetVelocity(vel)
    end
end

function SWEP:Think()
    if not self:GetIsHolding() then return end

    local owner = self:GetOwner()
    local ent = self._heldEnt

    if not IsValid(owner) or not IsValid(ent) then
        self:DropEntity()
        return
    end

    if not owner:Alive() then
        self:DropEntity()
        return
    end

    if not owner:KeyDown(IN_ATTACK) then
        self:DropEntity()
        return
    end

    if owner:GetGroundEntity() == ent then
        self:DropEntity()
        return
    end

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then
        self:DropEntity()
        return
    end

    local targetPos = owner:EyePos() + owner:GetAimVector() * self._holdDistance

    local distToTarget = ent:GetPos():Distance(targetPos)
    if distToTarget > self.CFG.MAX_HOLD_DISTANCE then
        self:DropEntity()
        return
    end

    phys:ComputeShadowControl({
        secondstoarrive = 0.06,
        pos = targetPos,
        angle = self._grabAngles or ent:GetAngles(),
        maxangular = 5000,
        maxangulardamp = 10000,
        maxspeed = self.CFG.MAX_VELOCITY,
        maxspeeddamp = self.CFG.MAX_VELOCITY * 2,
        dampfactor = 0.8,
        teleportdistance = 0,
        deltatime = FrameTime(),
    })

    local vel = phys:GetVelocity()
    local speed = vel:Length()
    if speed > self.CFG.MAX_VELOCITY then
        phys:SetVelocity(vel:GetNormalized() * self.CFG.MAX_VELOCITY)
    end
end

function SWEP:Holster()
    self:DropEntity()
    return true
end

function SWEP:OnRemove()
    self:DropEntity()
end

hook.Add("EntityTakeDamage", "VERSE::EntityTakeDamage::Hands", function(target, dmginfo)
    local inflictor = dmginfo:GetInflictor()
    if IsValid(inflictor) and inflictor._VerseHandsDmgDisabled then
        return true
    end

    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and attacker._VerseHandsDmgDisabled then
        return true
    end
end)

hook.Add("PlayerDeath", "VERSE::PlayerDeath::Hands", function(ply)
    local wep = ply:GetWeapon("verse_hands")
    if IsValid(wep) and wep.DropEntity then
        wep:DropEntity()
    end
end)

hook.Add("PlayerDisconnected", "VERSE::PlayerDisconnected::Hands", function(ply)
    local wep = ply:GetWeapon("verse_hands")
    if IsValid(wep) and wep.DropEntity then
        wep:DropEntity()
    end
end)

hook.Add("EntityRemoved", "VERSE::EntityRemoved::Hands", function(ent)
    if not ent._VerseHandsHolder then return end

    local holder = ent._VerseHandsHolder
    if not IsValid(holder) then return end

    local wep = holder:GetWeapon("verse_hands")
    if IsValid(wep) and wep._heldEnt == ent then
        wep._heldEnt = nil
        wep:SetGrabbedEntity(NULL)
        wep:SetIsHolding(false)
        wep:SetHoldType("normal")
    end
end)
