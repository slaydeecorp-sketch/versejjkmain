ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "Portail Serveur"
ENT.Author          = "VERSE"
ENT.Spawnable       = false
ENT.AdminSpawnable  = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "DestIP")
    self:NetworkVar("String", 1, "DestLabel")
end
