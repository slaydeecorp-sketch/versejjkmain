-- ─── Grades de puissance ───────────────────────────────────────────────────────
-- Chaque grade est un job dont seul le staff peut attribuer (whitelisted = true).
-- Les stats "health" et "mana" sont lues par le provider "job" dans sv_stats.lua
-- (priorité 900) et appliquées immédiatement via ply:RecalcStats().
-- Le modèle du personnage et l'armement restent gérés par le système de personnages.
-- ──────────────────────────────────────────────────────────────────────────────

-- Classe 4 ── grade d'entrée
VERSE.Jobs:Register("classe_4", {
    name        = "Classe 4",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 600,
        mana     = 500,
        runspeed = 400,
    },
})

-- Classe 3
VERSE.Jobs:Register("classe_3", {
    name        = "Classe 3",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 1200,
        mana     = 900,
        runspeed = 410,
    },
})

-- Semi-classe 2 ── palier intermédiaire entre Classe 3 et Classe 2
VERSE.Jobs:Register("semi_classe_2", {
    name        = "Semi-classe 2",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 1800,
        mana     = 1300,
        runspeed = 420,
    },
})

-- Classe 2
VERSE.Jobs:Register("classe_2", {
    name        = "Classe 2",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 2600,
        mana     = 1800,
        runspeed = 430,
    },
})

-- Semi-classe 1 ── palier intermédiaire entre Classe 2 et Classe 1
VERSE.Jobs:Register("semi_classe_1", {
    name        = "Semi-classe 1",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 3500,
        mana     = 2300,
        runspeed = 440,
    },
})

-- Classe 1
VERSE.Jobs:Register("classe_1", {
    name        = "Classe 1",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 5000,
        mana     = 3000,
        runspeed = 450,
    },
})

-- Classe S ── grade le plus élevé
VERSE.Jobs:Register("classe_s", {
    name        = "Classe S",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 7000,
        mana     = 4200,
        runspeed = 460,
    },
})

-- ─── Grades de clan : Gojo ──────────────────────────────────────────────────
VERSE.Jobs:Register("classe_4_gojo", {
    name        = "Classe 4 [Gojo]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 600,
        mana     = 500,
        runspeed = 400,
    },
})

VERSE.Jobs:Register("classe_3_gojo", {
    name        = "Classe 3 [Gojo]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 1200,
        mana     = 900,
        runspeed = 410,
    },
})

VERSE.Jobs:Register("semi_classe_2_gojo", {
    name        = "Semi-Classe 2 [Gojo]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 1800,
        mana     = 1300,
        runspeed = 420,
    },
})

VERSE.Jobs:Register("classe_2_gojo", {
    name        = "Classe 2 [Gojo]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 2600,
        mana     = 1800,
        runspeed = 430,
    },
})

VERSE.Jobs:Register("semi_classe_1_gojo", {
    name        = "Semi-Classe 1 [Gojo]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 3500,
        mana     = 2300,
        runspeed = 440,
    },
})

VERSE.Jobs:Register("classe_1_gojo", {
    name        = "Classe 1 [Gojo]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 5000,
        mana     = 3000,
        runspeed = 450,
    },
})

VERSE.Jobs:Register("classe_s_gojo", {
    name        = "Classe S [Gojo]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 7000,
        mana     = 4200,
        runspeed = 460,
    },
})
VERSE.Jobs:Register("elu_gojo", {
    name        = "Élu [Gojo]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats       = { health = 7000, mana = 4200, runspeed = 460 },
})

-- ─── Clan Zenin ───────────────────────────────────────────────────────────────
VERSE.Jobs:Register("classe_4_zenin", {
    name        = "Classe 4 [Zenin]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 600,
        mana     = 500,
        runspeed = 400,
    },
})

VERSE.Jobs:Register("classe_3_zenin", {
    name        = "Classe 3 [Zenin]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 1200,
        mana     = 900,
        runspeed = 410,
    },
})

VERSE.Jobs:Register("semi_classe_2_zenin", {
    name        = "Semi-Classe 2 [Zenin]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 1800,
        mana     = 1300,
        runspeed = 420,
    },
})

VERSE.Jobs:Register("classe_2_zenin", {
    name        = "Classe 2 [Zenin]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 2600,
        mana     = 1800,
        runspeed = 430,
    },
})

VERSE.Jobs:Register("semi_classe_1_zenin", {
    name        = "Semi-Classe 1 [Zenin]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 3500,
        mana     = 2300,
        runspeed = 440,
    },
})

VERSE.Jobs:Register("classe_1_zenin", {
    name        = "Classe 1 [Zenin]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 5000,
        mana     = 3000,
        runspeed = 450,
    },
})

VERSE.Jobs:Register("classe_s_zenin", {
    name        = "Classe S [Zenin]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = {
        health   = 7000,
        mana     = 4200,
        runspeed = 460,
    },
})

-- ─── Point de spawn commun à tous les Fléaux ─────────────────────────────────
local _FLEAUX_SPAWN = {
    min = { x = 11760.079102, y = 4705.861816, z = -6132.991211 },
    max = { x = 12883.205078, y = 4729.693359, z = -6132.983887 },
    ang = { p = 88.89,        y = -90.978,     r = 0            },
}

-- ─── Grades de clan : Sukuna ────────────────────────────────────────────────
VERSE.Jobs:Register("vermine_sukuna", {
    name        = "Vermine [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 600,  mana = 500,  runspeed = 400 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("abomination_sukuna", {
    name        = "Abomination [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 1200, mana = 900,  runspeed = 410 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("corrupteur_sukuna", {
    name        = "Corrupteur [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 1800, mana = 1300, runspeed = 420 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("executeur_sukuna", {
    name        = "Exécuteur [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 2600, mana = 1800, runspeed = 430 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("fossoyeur_sukuna", {
    name        = "Fossoyeur [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 3500, mana = 2300, runspeed = 440 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("ravageur_sukuna", {
    name        = "Ravageur [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 5000, mana = 3000, runspeed = 450 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("calamite_sukuna", {
    name        = "Calamité [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 7000, mana = 4200, runspeed = 460 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("prince_fleaux_sukuna", {
    name        = "Prince des Fléaux [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 5000, mana = 3000, runspeed = 460 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("roi_fleaux_sukuna", {
    name        = "Roi des Fléaux [Sukuna]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 7000, mana = 4200, runspeed = 460 },
    spawn = _FLEAUX_SPAWN,
})

-- ─── Grades de clan : Mahito ─────────────────────────────────────────────────
VERSE.Jobs:Register("vermine_mahito", {
    name        = "Vermine [Mahito]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 600,  mana = 500,  runspeed = 400 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("abomination_mahito", {
    name        = "Abomination [Mahito]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 1200, mana = 900,  runspeed = 410 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("corrupteur_mahito", {
    name        = "Corrupteur [Mahito]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 1800, mana = 1300, runspeed = 420 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("executeur_mahito", {
    name        = "Exécuteur [Mahito]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 2600, mana = 1800, runspeed = 430 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("fossoyeur_mahito", {
    name        = "Fossoyeur [Mahito]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 3500, mana = 2300, runspeed = 440 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("ravageur_mahito", {
    name        = "Ravageur [Mahito]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 5000, mana = 3000, runspeed = 450 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("calamite_mahito", {
    name        = "Calamité [Mahito]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 7000, mana = 4200, runspeed = 460 },
    spawn = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("prince_fleaux_mahito", {
    name        = "Prince des Fléaux [Mahito]",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats = { health = 5000, mana = 3000, runspeed = 460 },
    spawn = _FLEAUX_SPAWN,
})

-- ─── Grades Fléaux génériques (sans clan, sans whitelist) ────────────────────
VERSE.Jobs:Register("vermine", {
    name    = "Vermine",
    loadout = { "verse_hands", "verse_freecam" },
    stats   = { health = 600,  mana = 500,  runspeed = 400 },
    spawn   = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("abomination", {
    name    = "Abomination",
    loadout = { "verse_hands", "verse_freecam" },
    stats   = { health = 1200, mana = 900,  runspeed = 410 },
    spawn   = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("corrupteur", {
    name    = "Corrupteur",
    loadout = { "verse_hands", "verse_freecam" },
    stats   = { health = 1800, mana = 1300, runspeed = 420 },
    spawn   = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("executeur", {
    name    = "Exécuteur",
    loadout = { "verse_hands", "verse_freecam" },
    stats   = { health = 2600, mana = 1800, runspeed = 430 },
    spawn   = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("fossoyeur", {
    name    = "Fossoyeur",
    loadout = { "verse_hands", "verse_freecam" },
    stats   = { health = 3500, mana = 2300, runspeed = 440 },
    spawn   = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("ravageur", {
    name    = "Ravageur",
    loadout = { "verse_hands", "verse_freecam" },
    stats   = { health = 5000, mana = 3000, runspeed = 450 },
    spawn   = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("calamite", {
    name    = "Calamité",
    loadout = { "verse_hands", "verse_freecam" },
    stats   = { health = 7000, mana = 4200, runspeed = 460 },
    spawn   = _FLEAUX_SPAWN,
})
VERSE.Jobs:Register("prince_fleaux", {
    name    = "Prince des Fléaux",
    loadout = { "verse_hands", "verse_freecam" },
    stats   = { health = 5000, mana = 3000, runspeed = 460 },
    spawn   = _FLEAUX_SPAWN,
})

-- ─── Rôle spécial : Directeur ────────────────────────────────────────────────
VERSE.Jobs:Register("directeur", {
    name        = "Directeur",
    whitelisted = true,
    loadout     = { "verse_hands", "verse_freecam" },
    stats       = { health = 7000, mana = 4200, runspeed = 460 },
})

-- ─── Grade de départ ────────────────────────────────────────────────────────
-- Tout nouveau joueur (ou joueur sans PData) commence en Classe 4.
-- Le staff monte ensuite manuellement via st_setclass dans le menu SAM.
VERSE.Config        = VERSE.Config or {}
VERSE.Config.Jobs   = VERSE.Config.Jobs or {}
VERSE.Config.Jobs.DefaultJobID = "classe_4"
