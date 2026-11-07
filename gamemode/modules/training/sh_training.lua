VERSE.Training = VERSE.Training or {}
local T = VERSE.Training

T.Config = {
    TableName     = "verse_training_zones",
    DefaultRadius = 500,   -- rayon par défaut en unités Hammer
    RespawnDelay  = 0.1,   -- délai avant le respawn (secondes) — nécessaire pour GMod
    HUDText       = "Zone d'entraînement",
    HUDColor      = Color(80, 200, 255, 245),
    HUDBgColor    = Color(10, 18, 40, 200),
    HUDBorderColor= Color(60, 150, 255, 200),
}

T.Net = {
    Sync = "VERSE::Training::Sync", -- serveur → client : liste complète des zones
}
