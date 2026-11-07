AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self._worldModel or "models/humans/group01/male_01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(true)

    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    local seq = self:LookupSequence("idle_all_01")
    if seq and seq > 0 then
        self:SetSequence(seq)
        self:SetPlaybackRate(1)
        self:SetCycle(0)
        self:ResetSequenceInfo()
    end

    self._useCooldowns = {}
end

function ENT:Think()
    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local traderId = self:GetTraderID()
    if not traderId or traderId <= 0 then return end

    local now = CurTime()
    local steamId = activator:SteamID64()
    if self._useCooldowns[steamId] and now - self._useCooldowns[steamId] < 0.5 then return end
    self._useCooldowns[steamId] = now

    local TRADERS = VERSE and VERSE.Traders
    if not TRADERS then return end

    local catalog = TRADERS:GetCatalog(traderId)
    if not catalog then return end

    local traderName = self:GetTraderName() or "Trader"
    netstream.Start(activator, TRADERS.Net.OpenShop, traderId, traderName, catalog)
end

function ENT:OnRemove()
    self._useCooldowns = nil
end
