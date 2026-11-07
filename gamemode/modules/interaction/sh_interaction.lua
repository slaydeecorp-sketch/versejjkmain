VERSE.Interaction = VERSE.Interaction or {}
local IT = VERSE.Interaction

-- ─── Canaux réseau ────────────────────────────────────────────────────────────

IT.Net = {
    Request          = "VERSE::Interaction::Request",
    Popup            = "VERSE::Interaction::Popup",
    Response         = "VERSE::Interaction::Response",
    CarrySync        = "VERSE::Interaction::CarrySync",
    MoneyGive        = "VERSE::Interaction::MoneyGive",
    Notify           = "VERSE::Interaction::Notify",
    FouillerInventory = "VERSE::Interaction::FouillerInventory", -- serveur → requester : inventaire de la cible
}

-- ─── Configuration ────────────────────────────────────────────────────────────

IT.Config = {
    MaxRange     = 220,   -- distance max d'interaction (unités Hammer)
    HoldTime     = 2.0,   -- secondes de maintien E pour ouvrir le menu
    DropHoldTime = 1.5,   -- secondes de maintien E pour poser quelqu'un
    PopupTimeout = 15,    -- secondes avant expiration automatique d'un popup
}
