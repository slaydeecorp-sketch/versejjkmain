ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "VERSE Interact NPC (Base)"
ENT.Category = "VERSE | NPC"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.WorldModel = "models/humans/group01/male_04.mdl"
ENT.DefaultNPCName = "NPC"
ENT.HintText = "[E] Interagir"
ENT.UseCooldown = 0.5
function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "NPCName")
end