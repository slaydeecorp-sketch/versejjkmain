-- sh_tenues_boutique.lua
-- Items de tenues de la boutique : enregistrés dans le système d'inventaire.
-- Slot d'équipement : "Outfit" → applique equip_model au joueur.
-- droppable/tradeable = false → items liés au compte (non cessibles).
--
-- gender : "male" / "female" / "unisex". Une tenue male/female ne peut être
--          équipée que sur un personnage du même sexe (vérif côté serveur).
-- icon   : verse/boutique/<rarete>[f].png  (suffixe "f" pour les tenues femme)
--          commun / rare / epique / legendaire / mythique
-- ─────────────────────────────────────────────────────────────────────────────

local INV = VERSE.Inventory
if not INV then return end

INV:RegisterItem("tenue_boutique1", {
    name        = "Style Urbain",
    description = "Un look décontracté de tous les jours : t-shirt et jogging.",
    category    = "outfit",
    rarity      = "common",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/commun.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/boutique1.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_boutique2", {
    name        = "Costume Rayé",
    description = "Un complet à fines rayures, cravate rouge. Élégance assurée.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/rare.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/boutique2.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_boutique3", {
    name        = "Drapé d'Ombre",
    description = "Une longue tenue sombre et fluide au décolleté marqué.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epique.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/boutique3.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_boutique4", {
    name        = "Manteau de l'Effroi",
    description = "Une parure de plumes et d'écailles sombres, inquiétante.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/boutique4.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_boutique5", {
    name        = "Hakama du Vagabond",
    description = "Torse nu et hakama en lambeaux : l'allure d'un guerrier errant.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epique.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/boutique5.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_boutique6", {
    name        = "Garde Écarlate",
    description = "Robe noire ceinte d'une écharpe écarlate et d'une épaulière.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/boutique6.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_chefgojo", {
    name        = "Haori du Patriarche",
    description = "Kimono blanc immaculé à ceinture noire, digne d'un chef de clan.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/chefgojo.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_chefmahito", {
    name        = "Habit du Métamorphe",
    description = "Sarouel clair et torse nu : l'allure brute d'une âme difforme.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/chefmahito.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fboutique", {
    name        = "Élégance Nocturne",
    description = "Une longue robe bleu nuit et ses gants, d'une grande élégance.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epiquef.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fboutique.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_ffleau", {
    name        = "Ensemble d'Ombre",
    description = "Crop top et jupe noirs, gants et bottes : tenue de combat agile.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/raref.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/ffleau.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fgojo", {
    name        = "Agilité de l'Infini",
    description = "Brassière noire et cargo ample : une tenue souple et sportive.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epiquef.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fgojo.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fgojo2", {
    name        = "Haori de Lumière",
    description = "Un kimono blanc immaculé et son hakama, rayonnant de pureté.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendairef.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fgojo2.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fleau", {
    name        = "Combinaison Asymétrique",
    description = "Une salopette navy à une seule épaule, à la coupe singulière.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/rare.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fleau.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fleau2", {
    name        = "Manteau du Moine Errant",
    description = "Kimono navy et plastron vert et or, dans le style d'un moine voyageur.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fleau2.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fmahito", {
    name        = "Garde de l'Âme",
    description = "Crop top à manches longues et pantalon évasé noir, ceinturon clouté.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epiquef.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fmahito.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fmedecin", {
    name        = "Tenue de Praticienne",
    description = "Blazer menthe, pantalon gris et talons : une allure de praticienne.",
    category    = "outfit",
    rarity      = "common",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/communf.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fmedecin.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fsukuna", {
    name        = "Robe Funeste",
    description = "Une robe gothique noir et blanc, d'une élégance funèbre.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epiquef.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fsukuna.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_fzenin", {
    name        = "Lignée Noire",
    description = "Col roulé noir, pantalon ajusté et ceinture claire : sobre et net.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epiquef.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/fzenin.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_mahito", {
    name        = "Habit Rapiécé",
    description = "Un blazer au motif cousu et grillagé, comme une âme recousue.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/mahito.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_medecin2", {
    name        = "Toge Vermillon",
    description = "Une longue robe rouge à liserés sombres, héritée d'un vieux guérisseur.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/rare.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/medecin2.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_street", {
    name        = "Survêtement Cosy",
    description = "Sweat et jogging assortis : confort et décontraction.",
    category    = "outfit",
    rarity      = "common",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/commun.png",
    equip_slot  = "Outfit",
    equip_model = "models/kleyyn_jjk/tenues/street.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_boss_event3", {
    name        = "Manteau de l'Errant",
    description = "Un long manteau noir, genouillère et bottes lacées : allure de baroudeur.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epique.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/boss_event3.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_choso", {
    name        = "Tenue du Frère Aîné",
    description = "Kimono blanc, gilet et ceinture pourpres : la prestance d'un aîné.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epique.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/choso.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_gojo_1", {
    name        = "Uniforme de l'Élu",
    description = "Uniforme navy à col haut, sobre et impeccable.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/rare.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/gojo_1.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_gojo_2", {
    name        = "Tenue de Plage",
    description = "Hoodie orange ouvert et short noir : prêt pour la détente au soleil.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/rare.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/gojo_2.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_gojo_3", {
    name        = "Costume Noir",
    description = "Un costume noir classique, cravate et chaussures de ville.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/rare.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/gojo_3.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_kasumi_miwa", {
    name        = "Costume Marine",
    description = "Un costume croisé bleu marine à boutons dorés, soigné.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/raref.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/kasumi_miwa.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_mai_mai", {
    name        = "Allié du Corbeau",
    description = "Combinaison navy bouffante et bottes à talon, sous le signe du corbeau.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/raref.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/mai_mai.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_mai_zenin", {
    name        = "Qipao Azur",
    description = "Une longue robe bleue fendue à col mandarin, élégante.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/raref.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/mai_zenin.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_megumi", {
    name        = "Tenue d'Exorciste Sombre",
    description = "Veste navy à col haut, pantalon court et bottes : sobre et sombre.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/rare.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/megumi.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_naobito", {
    name        = "Haori du Doyen",
    description = "Haori gris sur kimono noir et hakama brun : l'autorité d'un ancien.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/naobito.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_nobara", {
    name        = "Uniforme d'Écolière",
    description = "Veste navy à boutons dorés et jupe plissée : l'uniforme scolaire.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/raref.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/nobara.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_noritoshi", {
    name        = "Uniforme du Calme",
    description = "Kimono navy à liserés dorés et ceinture blanche, posé et maîtrisé.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epique.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/noritoshi.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_suguru", {
    name        = "Manteau du Renégat",
    description = "Robe navy à col haut, hakama et bottes : l'allure d'un dissident.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epique.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/suguru.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_sukuna", {
    name        = "Tenue Maudite",
    description = "Haut blanc sans manches et ceinture noire : l'aura du Roi des Fléaux.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/sukuna.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_sukuna_2", {
    name        = "Yukata du Roi",
    description = "Kimono gris clair, obi à losanges et liseré navy : la prestance d'un roi.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/sukuna_2.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_toji", {
    name        = "Tenue du Mercenaire",
    description = "T-shirt noir et sarouel gris : l'équipement sobre d'un tueur.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epique.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/toji.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_utahime", {
    name        = "Tenue de Miko",
    description = "Haut blanc et hakama rouge : l'habit traditionnel d'une prêtresse.",
    category    = "outfit",
    rarity      = "epic",
    gender      = "female",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/epiquef.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/utahime.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_yin", {
    name        = "Tenue d'Exorciste Écarlate",
    description = "Veste navy à col rouge et baskets rouges : rehaussée de touches écarlates.",
    category    = "outfit",
    rarity      = "rare",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/rare.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/yin.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})

INV:RegisterItem("tenue_yuta_okkotsu", {
    name        = "Tenue du Fiancé Maudit",
    description = "Veste blanche, jean noir et baskets : un style lycéen décontracté.",
    category    = "outfit",
    rarity      = "legendary",
    gender      = "male",
    max_stack   = 1,
    weight      = 0.5,
    icon        = "verse/boutique/legendaire.png",
    equip_slot  = "Outfit",
    equip_model = "models/slayde_jjk/tenues/yuta_okkotsu.mdl",
    usable      = false,
    droppable   = false,
    tradeable   = false,
})
