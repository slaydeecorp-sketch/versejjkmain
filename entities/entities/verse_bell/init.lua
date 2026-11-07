AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    local mdl = (VERSE and VERSE.Bell and VERSE.Bell.Config and VERSE.Bell.Config.EntityModel) or "models/props_c17/pottery02a.mdl"
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(true)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end

    self._useCooldowns = {}
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local now = CurTime()
    local sid = activator:SteamID64() or "?"
    if self._useCooldowns[sid] and now - self._useCooldowns[sid] < 0.5 then return end
    self._useCooldowns[sid] = now

    VERSE.Bell:OpenFor(activator, self)
end

function ENT:OnRemove()
    self._useCooldowns = nil
end
