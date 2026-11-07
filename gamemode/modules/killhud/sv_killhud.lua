local CFG = VERSE.KillHUD.Config

resource.AddFile("materials/verse_hud/killhud1.png")

VERSE.Hook.AddNS("KillHUD", "PlayerDeath", "VERSE::PlayerDeath::KillHUD", function(victim, _, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if CFG.IgnoreSelfKill and attacker == victim then return end

    netstream.Start(attacker, CFG.NET.Show, victim:Nick())
end)
