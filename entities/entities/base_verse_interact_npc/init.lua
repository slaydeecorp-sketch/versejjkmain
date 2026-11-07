AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
function ENT:Initialize()
    self:SetModel(self.WorldModel or "models/humans/group01/male_04.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(true)
    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
    local seq = self:LookupSequence("idle_all_01")
    if seq and seq > 0 then
        self:SetSequence(seq)
        self:SetPlaybackRate(1)
        self:SetCycle(0)
        self:ResetSequenceInfo()
    end

    if not self:GetNPCName() or self:GetNPCName() == "" then self:SetNPCName(self.DefaultNPCName or "NPC") end
    self._useCooldowns = {}
    if self.OnSpawned then self:OnSpawned() end
end

function ENT:Think()
    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
    local now = CurTime()
    local sid = activator:SteamID64()
    local cd = self.UseCooldown or 0.5
    if self._useCooldowns[sid] and now - self._useCooldowns[sid] < cd then return end
    self._useCooldowns[sid] = now
    if self.OnInteract then self:OnInteract(activator) end
end

function ENT:OnRemove()
    self._useCooldowns = nil
end

function ENT:OnInteract(activator)
end