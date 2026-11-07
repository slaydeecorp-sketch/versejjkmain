ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "NPC Trader"
ENT.Category = "Verse"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "TraderID")
    self:NetworkVar("String", 0, "TraderName")
end
