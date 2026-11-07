-- ─── Développeurs (serveur uniquement — ne jamais mettre dans sh_config.lua) ──
VERSE.Config.Access.Developers = {
    "STEAM_0:0:176462543",
    "STEAM_0:1:169787079",
    "STEAM_0:0:65692862",
    "STEAM_0:0:840461792",
}

-- Notifie chaque joueur connecté de son statut développeur via un NWBool
-- (utilisé côté client pour afficher/masquer les panels dev sans exposer les SteamIDs)
hook.Add("PlayerInitialSpawn", "VERSE::Security::SetDevBool", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        ply:SetNWBool("VERSE_IsDev", table.HasValue(VERSE.Config.Access.Developers, ply:SteamID()))
    end)
end)

VERSE.Config.Database = {
    EnableMySQL = true,
    Host = "",
    Username = "",
    Password = "",
    Database_name = "",
    Database_port = 3306,
    MultiStatements = false
}