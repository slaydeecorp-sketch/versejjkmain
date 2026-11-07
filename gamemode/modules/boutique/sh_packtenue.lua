-- sh_packtenue.lua
-- Définition des items de tenues disponibles (auto depuis l'inventaire) + packs DB.
-- BT.OutfitItems    : items de tenue disponibles (modèles), synchronisés depuis
--                     les items d'inventaire de catégorie "outfit".
-- BT.PackTenuePacks : packs gérés via l'admin et persistés en DB.
-- ─────────────────────────────────────────────────────────────────────────────

VERSE.Boutique = VERSE.Boutique or {}
local BT = VERSE.Boutique

-- ─── Items de tenue (auto-sync depuis l'inventaire) ──────────────────────────
-- Toute tenue enregistrée dans l'inventaire (category = "outfit", avec equip_model)
-- devient automatiquement disponible dans les packs de tenue. Plus besoin de
-- maintenir une 2e liste codée en dur ici.
BT.OutfitItems = BT.OutfitItems or {}

function BT:SyncOutfitItems()
    local INV = VERSE.Inventory
    if not INV or not istable(INV.Items) then return end
    for id, def in pairs(INV.Items) do
        if istable(def) and tostring(def.category) == "outfit"
            and isstring(def.equip_model) and def.equip_model ~= "" then
            BT.OutfitItems[id] = {
                id    = id,
                name  = tostring(def.name or id),
                model = def.equip_model,
            }
        end
    end
end

-- Tente immédiatement (si l'inventaire est déjà chargé : hot reload), puis après
-- l'init complète du serveur/client (ordre de chargement des modules non garanti).
BT:SyncOutfitItems()
hook.Add("InitPostEntity", "VERSE::Boutique::SyncOutfitItems", function()
    BT:SyncOutfitItems()
end)

-- ─── Packs (chargés depuis DB via sv_packtenue.lua) ──────────────────────────
-- Structure d'un pack :
-- {
--     id         = "pack_tenue_1",
--     name       = "Pack Tenue 1",
--     price      = 500,
--     icon       = "verse/boutique/chest_h 1",  -- chemin matériau
--     sort_order = 1,
--     outfits    = {
--         { id = "tenue_boutique1", weight = 50 },  -- weight = poids relatif
--         { id = "tenue_boutique2", weight = 30 },
--     },
-- }
BT.PackTenuePacks = BT.PackTenuePacks or {}
