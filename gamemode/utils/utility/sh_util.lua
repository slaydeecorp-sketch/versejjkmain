VERSE.Hook.AddNS("Utility", "PropBreak", "VERSE::PropBreak::Utility", function(attacker, ent)
    if IsValid(ent) and IsValid(ent:GetPhysicsObject()) then
        constraint.RemoveAll(ent)
    end
end)

VERSE.Hook.AddNS("Utility", "PlayerSwitchFlashlight", "VERSE::PlayerSwitchFlashlight::Utility", function(ply, enabled)
    return VERSE.Config.FlashlightMode
end)

concommand.Remove("gm_save")