VERSE.Staff = VERSE.Staff or {}
local S = VERSE.Staff

S.Config = {
    UpdateRate  = 0.5,
    ESPMaxDist  = 0,
    BanDuration = 0,
}

S.Net = {
    Toggle    = "VERSE::Staff::Toggle",
    Data      = "VERSE::Staff::Data",
    Kick      = "VERSE::Staff::Kick",
    Ban       = "VERSE::Staff::Ban",
    Search    = "VERSE::Staff::Search",
    Inventory = "VERSE::Staff::Inventory",
    Teleport  = "VERSE::Staff::Teleport",
    Bring     = "VERSE::Staff::Bring",
    Freeze    = "VERSE::Staff::Freeze",
    Heal      = "VERSE::Staff::Heal",
    Warn      = "VERSE::Staff::Warn",
    GiveMoney = "VERSE::Staff::GiveMoney",
    SetJob    = "VERSE::Staff::SetJob",
}

-- ─── Enregistrement des permissions dans SAM ─────────────────────────────────
-- Rend les permissions visibles dans l'onglet Ranks de SAM (attribution par groupe).

local _STAFF_PERMS = {
    { "verse_staff",     "Staff VERSE" },  -- activer le mode staff ESP
    { "can_kick",        "Staff VERSE" },  -- kicker un joueur
    { "can_ban",         "Staff VERSE" },  -- banner un joueur
    { "verse_search",    "Staff VERSE" },  -- fouiller l'inventaire
    { "can_goto",        "Staff VERSE" },  -- se téléporter vers un joueur
    { "can_bring",       "Staff VERSE" },  -- ramener un joueur
    { "can_freeze",      "Staff VERSE" },  -- geler un joueur
    { "verse_heal",      "Staff VERSE" },  -- soigner un joueur
    { "verse_warn",      "Staff VERSE" },  -- avertir un joueur
    { "verse_givemoney", "Staff VERSE" },  -- donner/retirer de l'argent
    { "setclass",        "Staff VERSE" },  -- changer le job d'un joueur
}

local function _registerStaffPerms()
    if not (sam and sam.permissions and isfunction(sam.permissions.add)) then return end
    for _, p in ipairs(_STAFF_PERMS) do
        sam.permissions.add(p[1], p[2])
    end
end

_registerStaffPerms()
hook.Add("Initialize", "VERSE::Staff::SAMPerms", _registerStaffPerms)
