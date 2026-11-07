AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:OnInteract(activator)
    local BB = VERSE and VERSE.Barbershop
    if not BB or not BB.OpenForPlayer then
        activator:ChatPrint("[Barbershop] Module non chargé.")
        return
    end
    BB:OpenForPlayer(activator, self)
end
