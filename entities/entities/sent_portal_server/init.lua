AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("VERSE::Portal::Connect")

local COOLDOWN = 3
local _lastUse = {}

function ENT:Initialize()
    self:SetModel("models/hunter/misc/sphere075x075.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
    self:SetUseType(SIMPLE_USE)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local steamid = activator:SteamID()
    local now     = CurTime()
    if (_lastUse[steamid] or 0) + COOLDOWN > now then return end
    _lastUse[steamid] = now

    local ip    = self:GetDestIP()
    local label = self:GetDestLabel()
    local pass  = self._destPass or ""

    if ip == "" then return end

    activator:Notify("Transfert vers " .. label .. "...", NOTIFY_HINT, 3)

    timer.Simple(1.5, function()
        if not IsValid(activator) then return end
        net.Start("VERSE::Portal::Connect")
        net.WriteString(ip)
        net.WriteString(pass)
        net.Send(activator)
    end)
end

function ENT:OnRemove()
    VERSE_Portal_Save()
end
