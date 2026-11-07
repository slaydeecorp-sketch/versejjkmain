VERSE.Bell = VERSE.Bell or {}
local Bell = VERSE.Bell

Bell.Config = {
    Cooldown = 5,
    UseRange = 100,
    MaxLength = 70,
    DisplayDuration = 10,
    FadeIn = 0.35,
    FadeOut = 0.5,
    EntityModel = "models/props_japan/gong01.mdl",
    Sound = "gong_bell_alert.mp3",
    CrossServer = {
        ServerTag    = "default",
        PollInterval = 3,
        TableName    = "verse_bell_alerts",
        TTLSeconds   = 300,
    },
}

Bell.Net = {
    Open    = "VERSE::Bell::Open",
    Send    = "VERSE::Bell::Send",
    Display = "VERSE::Bell::Display",
}

function Bell.GetFaction(ply)
    if not IsValid(ply) then return "" end
    local CH = VERSE.Characters
    local key = (CH and CH.AppearanceNW and CH.AppearanceNW.Faction) or "VERSE::Char::Faction"
    if ply.GetPublicString then return ply:GetPublicString(key, "") end
    return ply:GetNWString(key, "")
end

function Bell.GetFactionName(factionId)
    if not isstring(factionId) or factionId == "" then return "" end
    local CH = VERSE.Characters
    local cfg = CH and CH.GetConfig and CH:GetConfig() or nil
    local f = cfg and cfg.Factions and cfg.Factions[factionId] or nil
    if istable(f) and isstring(f.name) and f.name ~= "" then return f.name end
    return string.upper(factionId)
end
