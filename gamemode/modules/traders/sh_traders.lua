VERSE.Traders = VERSE.Traders or {}
local TRADERS = VERSE.Traders
TRADERS.Net = {
    OpenShop = "VERSE::Traders::OpenShop",
    BuyItem = "VERSE::Traders::BuyItem",
    AdminRequest = "VERSE::Traders::AdminRequest",
    AdminList = "VERSE::Traders::AdminList",
    AdminCreate = "VERSE::Traders::AdminCreate",
    AdminUpdate = "VERSE::Traders::AdminUpdate",
    AdminDelete = "VERSE::Traders::AdminDelete",
    AdminAddItem = "VERSE::Traders::AdminAddItem",
    AdminRemoveItem = "VERSE::Traders::AdminRemoveItem",
    AdminUpdateItem = "VERSE::Traders::AdminUpdateItem",
    AdminGetItems = "VERSE::Traders::AdminGetItems",
    AdminSyncItems = "VERSE::Traders::AdminSyncItems",
    AdminSavePos = "VERSE::Traders::AdminSavePos",
}

TRADERS.Config = {
    MaxNameLength = 64,
    MaxTraders = 50,
    BuyCooldown = 0.5,
    TableTraders = "verse_traders",
    TableItems = "verse_trader_items",
}