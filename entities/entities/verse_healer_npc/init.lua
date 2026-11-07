AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:OnInteract(activator)
    local maxHP = activator:GetMaxHealth() or 100
    local curHP = activator:Health()
    if curHP >= maxHP then
        activator:ChatPrint("Vous êtes déjà en pleine forme.")
        return
    end

    activator:SetHealth(maxHP)
    activator:EmitSound("items/medshot4.wav", 70, 100)

    local pos = self:GetPos() + Vector(0, 0, 50)
    local effect = EffectData()
    effect:SetOrigin(pos)
    effect:SetMagnitude(1)
    effect:SetScale(1)
    util.Effect("HealthDamage", effect, true, true)

    activator:ChatPrint(string.format("[%s] Vous avez été soigné (%d HP).", self:GetNPCName(), maxHP))
end
