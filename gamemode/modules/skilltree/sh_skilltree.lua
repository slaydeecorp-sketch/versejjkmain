VERSE.SkillTree = VERSE.SkillTree or {}
local ST = VERSE.SkillTree
ST.Config = {
    Enabled = true,
    TableName = "verse_skilltree_characters",
    DefaultPoints = 3,
    BindSlotCount = 6,
    PresetCount = 2,
    MaterialAliases = {
        skilltree_main_background = "verse/skill_tree/main_background.png",
        skilltree_reset_link_icon = "verse/skill_tree/acheter_icon.png",
        skilltree_category_cursed_icon = "verse/skill_tree/pourvoir_icon.png",
        skilltree_category_martial_icon = "verse/skill_tree/voie_icon.png",
        skilltree_category_heritage_icon = "verse/skill_tree/heritage_icon.png",
        skilltree_category_clans_icon = "verse/skill_tree/clans_icon.png",
        skilltree_category_other_icon = "verse/skill_tree/autres_icon.png",
        skilltree_sub_application_icon = "verse/skill_tree/application_icon.png",
        skilltree_sub_control_icon = "verse/skill_tree/controle_icon.png",
        skilltree_sub_invocation_icon = "verse/skill_tree/invocation_icon.png",
        skilltree_sub_controle_icon   = "verse/skill_tree/controle_icon.png",
        skilltree_sub_projection_icon = "verse/skill_tree/projection_icon.png",
        skilltree_sub_poings_icon = "verse/skill_tree/poings_icon.png",
        skilltree_sub_katana_icon = "verse/skill_tree/katana_icon.png",
        skilltree_sub_naginata_icon = "verse/skill_tree/naginata_icon.png",
        skilltree_sub_heritage_big_icon = "verse/skill_tree/heritage_big_icon.png",
        skilltree_sub_clans_big_icon = "verse/skill_tree/clans_big_icon.png",
        skilltree_sub_autres_icon = "verse/skill_tree/autres_icon.png",
        -- Icones des techniques TCS (dans materials/icone/)
        tcs_spell_application_impact     = "icone/application/impact.png",
        tcs_spell_application_peau       = "icone/application/peau.png",
        tcs_spell_application_sprint     = "icone/application/sprint.png",
        tcs_spell_application_blackflash = "icone/application/blackflash.png",
        tcs_spell_invocation_grotte      = "icone/invocation/grotte.png",
        tcs_spell_invocation_reptilien   = "icone/invocation/reptilien.png",
        tcs_spell_invocation_etreinte    = "icone/invocation/etreinte.png",
        tcs_spell_invocation_purgatoire  = "icone/invocation/purgatoire.png",
        tcs_spell_projection_vicieuses   = "icone/projection/vicieuses.png",
        tcs_spell_projection_chercheuse  = "icone/projection/chercheuse.png",
        tcs_spell_projection_malediction = "icone/projection/malediction.png",
        tcs_spell_projection_pluie       = "icone/projection/pluie.png",
        -- Icones des techniques martiales (dans materials/icone/)
        tcs_weapon_lance_balayage        = "icone/lance/balayage.png",
        tcs_weapon_lance_trainee         = "icone/lance/trainee.png",
        tcs_weapon_lance_foudroyante     = "icone/lance/foudroyante.png",
        tcs_weapon_lance_lubu            = "icone/lance/lubu.png",
        tcs_weapon_katana_ouragan        = "icone/katana/ouragan.png",
        tcs_weapon_katana_danse          = "icone/katana/danse.png",
        tcs_weapon_katana_ruee           = "icone/katana/ruee.png",
        tcs_weapon_katana_eveil          = "icone/katana/eveil.png",
        tcs_weapon_fists_charge          = "icone/fists/charge.png",
        tcs_weapon_fists_fracas          = "icone/fists/fracas.png",
        tcs_weapon_fists_prise           = "icone/fists/prise.png",
        tcs_weapon_fists_rafale          = "icone/fists/rafale.png",
        -- Icones des techniques de Clan : Gojo (dans materials/icone/gojo/)
        tcs_clan_gojo_bleu               = "icone/gojo/bleu.png",
        tcs_clan_gojo_rouge              = "icone/gojo/Rouge.png",
        tcs_clan_gojo_infinie            = "icone/gojo/infini.png",
        tcs_clan_gojo_violet             = "icone/gojo/hollowpurple.png",
        -- Icones des techniques de Clan : Sukuna (dans materials/icone/sukuna/)
        tcs_clan_sukuna_laceration       = "icone/sukuna/laceration.png",
        tcs_clan_sukuna_effroi           = "icone/sukuna/effroi.png",
        tcs_clan_sukuna_dismantle        = "icone/sukuna/dismantle.png",
        tcs_clan_sukuna_fuga             = "icone/sukuna/fuga.png",
        -- Icones des techniques de Clan : Mahito (dans materials/icone/mahito/)
        tcs_clan_mahito_oursin           = "icone/mahito/oursin.png",
        tcs_clan_mahito_complete         = "icone/mahito/transformer.png",
        tcs_clan_mahito_ame              = "icone/mahito/voldame.png",
        tcs_clan_mahito_transfiguration  = "icone/mahito/transfiguration.png",
        -- Icones des techniques de Clan : Zenin (dans materials/icone/zenin/)
        tcs_clan_zenin_icon              = "icone/zenin/extension_zenin.png",
        tcs_clan_zenin_loup              = "icone/zenin/loup.png",
        tcs_clan_zenin_nue               = "icone/zenin/nue.png",
        tcs_clan_zenin_toad              = "icone/zenin/toad.png",
        tcs_clan_zenin_mahoraga          = "icone/zenin/mahoraga.png",
        -- Icones des techniques d'Heritage : Hanami (dans materials/icone/hanami/)
        tcs_heritage_hanami_racines      = "icone/hanami/racine.png",
        tcs_heritage_hanami_spores       = "icone/hanami/aurasporee.png",
        tcs_heritage_hanami_bourgeon     = "icone/hanami/bourgeon.png",
        tcs_heritage_hanami_arbre        = "icone/hanami/arbredevie.png",
        -- Icones des techniques d'Heritage : Jogo (dans materials/icone/jogo/)
        tcs_heritage_jogo_flamme         = "icone/jogo/flamme.png",
        tcs_heritage_jogo_eruption       = "icone/jogo/eruption.png",
        tcs_heritage_jogo_soleil         = "icone/jogo/soleil.png",
        tcs_heritage_jogo_meteor         = "icone/jogo/meteor.png",
        -- Icones des techniques d'Heritage : Itadori (dans materials/icone/itadori/)
        tcs_heritage_itadori_poing       = "icone/itadori/flash.png",
        tcs_heritage_itadori_flash       = "icone/itadori/taido.png",
        tcs_heritage_itadori_frappe      = "icone/itadori/contre.png",
        tcs_heritage_itadori_execution   = "icone/itadori/rafale.png",
        -- Icones des techniques d'Heritage : Todo (dans materials/icone/todo/)
        tcs_heritage_todo_boogie         = "icone/todo/boogie.png",
        tcs_heritage_todo_echange        = "icone/todo/echange.png",
        tcs_heritage_todo_combo          = "icone/todo/combo.png",
        tcs_heritage_todo_supreme        = "icone/todo/supreme.png",
        -- Icones des techniques d'Heritage : Yuta (dans materials/icone/yuta/)
        tcs_heritage_yuta_invocation     = "icone/yuta/amour.png",
        tcs_heritage_yuta_copie          = "icone/yuta/etreinte.png",
        tcs_heritage_yuta_inverse        = "icone/yuta/don.png",
        tcs_heritage_yuta_rika           = "icone/yuta/violetcopier.png",
        -- Icones des techniques d'Heritage : Finger Bearer (dans materials/icone/bearer/)
        tcs_heritage_finger_spurk        = "icone/bearer/spurk.png",
        tcs_heritage_finger_griffe       = "icone/bearer/griffe.png",
        tcs_heritage_finger_souffle      = "icone/bearer/souffle.png",
        tcs_heritage_finger_irradiation  = "icone/bearer/irradiation.png",
        -- Contrôle
        tcs_heritage_controle_tsukamoto  = "icone/controle/tsukamoto.png",
        tcs_heritage_controle_kappa      = "icone/controle/kappa.png",
        tcs_heritage_controle_tempete    = "icone/controle/tempete.png",
        tcs_heritage_controle_gonflette  = "icone/controle/gonflette.png",
        skilltree_sub_left_up_background = "verse/skill_tree/left_up_background.png",
        skilltree_sub_right_background = "verse/skill_tree/right_background.png",
        skilltree_sub_preset_icon = "verse/skill_tree/preset_icon.png",
        skilltree_sub_slot_hud = "verse/skill_tree/slot_hud.png",
    },
}

ST.Net = {
    Request = "VERSE::SkillTree::Request",
    Sync = "VERSE::SkillTree::Sync",
    Purchase = "VERSE::SkillTree::Purchase",
    Reset = "VERSE::SkillTree::Reset",
    Error = "VERSE::SkillTree::Error",
    AssignSlot = "VERSE::SkillTree::AssignSlot",
    ClearSlot = "VERSE::SkillTree::ClearSlot",
    SetActivePreset = "VERSE::SkillTree::SetActivePreset",
    UseSlot = "VERSE::SkillTree::UseSlot",
    Reroll = "VERSE::SkillTree::Reroll",
}

ST.Passives = {}
ST.Abilities = {}
local _defaultAbilities = {
    black_flash = {
        title = "Black Flash",
        description = "Technique passive qui renforce les impacts en melee quand elle se declenche.",
        mana_cost = 18,
        icon = "skilltree_sub_poings_icon",
        bindable = false,
        passive = true,
        sort = 40,
    },
    cursed_burst = {
        title = "Cursed Burst",
        description = "Canalise une fenetre de puissance occulte qui augmente vos degats pendant une courte duree.",
        mana_cost = 28,
        icon = "skilltree_sub_control_icon",
        bindable = true,
        execution = {
            type = "combat_buff",
            buff_profile = "cursed_burst_window",
        },
        sort = 10,
    },
    limit_break = {
        title = "Limit Break",
        description = "Libere votre potentiel pour booster vitesse, degats et reduction de cooldown.",
        mana_cost = 40,
        icon = "skilltree_sub_application_icon",
        bindable = true,
        execution = {
            type = "combat_buff",
            buff_profile = "limit_break",
        },
        sort = 20,
    },
    shadow_dash = {
        title = "Shadow Dash",
        description = "Active une poussee de mobilite defensive pour engager ou disengager rapidement.",
        mana_cost = 22,
        icon = "skilltree_sub_projection_icon",
        bindable = true,
        execution = {
            type = "combat_buff",
            buff_profile = "shadow_dash_window",
        },
        sort = 30,
    },
    cursed_spirit_invoke = {
        title = "Cursed Spirit Invoke",
        description = "Technique invoquee reservee aux futures executions actives.",
        mana_cost = 34,
        icon = "skilltree_sub_invocation_icon",
        bindable = false,
        sort = 50,
    },
    domain_seed = {
        title = "Domain Seed",
        description = "Preparation de domaine reservee aux futures executions actives.",
        mana_cost = 55,
        icon = "skilltree_sub_heritage_big_icon",
        bindable = false,
        sort = 60,
    },
    iron_katana_draw = {
        title = "Iron Katana Draw",
        description = "Degaine rapide de test pour verifier les categories martiales dans le loadout.",
        mana_cost = 24,
        icon = "skilltree_sub_katana_icon",
        bindable = true,
        execution = {
            type = "combat_buff",
            buff_profile = "shadow_dash_window",
        },
        sort = 70,
    },
    naginata_arc = {
        title = "Naginata Arc",
        description = "Balayage de test avec une grande allonge pour les validations UI.",
        mana_cost = 26,
        icon = "skilltree_sub_naginata_icon",
        bindable = true,
        execution = {
            type = "combat_buff",
            buff_profile = "limit_break",
        },
        sort = 80,
    },
    clan_resolve = {
        title = "Clan Resolve",
        description = "Buff de test pour verifier l'affichage d'une branche heritage ou clan.",
        mana_cost = 32,
        icon = "skilltree_sub_clans_big_icon",
        bindable = true,
        execution = {
            type = "combat_buff",
            buff_profile = "cursed_burst_window",
        },
        sort = 90,
    },
    heritage_guard = {
        title = "Heritage Guard",
        description = "Technique defensive de test liee a un heritage pour les apercus UI.",
        mana_cost = 36,
        icon = "skilltree_sub_heritage_big_icon",
        bindable = true,
        execution = {
            type = "combat_buff",
            buff_profile = "shadow_dash_window",
        },
        sort = 100,
    },

    -- Application
    jjk_application_impact = {
        title = "Impact Maudit",
        description = "Vous donnez un coup puissant qui etourdit les ennemis.",
        mana_cost = 80,
        icon = "tcs_spell_application_impact",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_application_impact" },
        sort = 110,
    },
    jjk_application_peau = {
        title = "Peau Renforcee",
        description = "Vous renforcez votre peau pour resister a la douleur et aux degats.",
        mana_cost = 10,
        icon = "tcs_spell_application_peau",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_application_peau" },
        sort = 111,
    },
    jjk_application_sprint = {
        title = "Sprint Occulte",
        description = "Vous vous deplacez rapidement en avant, assenant un coup de pied a un ennemi sur votre passage.",
        mana_cost = 10,
        icon = "tcs_spell_application_sprint",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_application_sprint" },
        sort = 112,
    },
    jjk_application_blackflash = {
        title = "Black Flash",
        description = "Charge un coup puissant vers l'avant.",
        mana_cost = 10,
        icon = "tcs_spell_application_blackflash",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_application_blackflash" },
        sort = 113,
    },

    -- Invocation
    jjk_invocation_grotte = {
        title = "Invocation : Gribbloeil",
        description = "Vous invoquez une gribbloeil qui suit votre cible et la frappe.",
        mana_cost = 30,
        icon = "tcs_spell_invocation_grotte",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_invocation_grotte" },
        sort = 120,
    },
    jjk_invocation_reptilien = {
        title = "Invocation : Gardien Reptilien",
        description = "Vous invoquez un gardien reptilien qui plonge la ou vous visez pour intoxiquer la zone.",
        mana_cost = 40,
        icon = "tcs_spell_invocation_reptilien",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_invocation_reptilien" },
        sort = 121,
    },
    jjk_invocation_etreinte = {
        title = "Invocation : Etreinte de l'Araignee",
        description = "Vous invoquez un fleau qui projette une toile qui immobilise les ennemis.",
        mana_cost = 50,
        icon = "tcs_spell_invocation_etreinte",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_invocation_etreinte" },
        sort = 122,
    },
    jjk_invocation_purgatoire = {
        title = "Invocation : Purgatoire des Damnes",
        description = "Vous invoquez un Fleau poussant un hurlement qui inflige des degats et un effet de confusion.",
        mana_cost = 60,
        icon = "tcs_spell_invocation_purgatoire",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_invocation_purgatoire" },
        sort = 123,
    },

    -- Projection
    jjk_projection_vicieuses = {
        title = "Aiguilles Vicieuses",
        description = "Vous projettez 5 aiguilles en arc de cercle qui infligent des degats et ralentissent les ennemis.",
        mana_cost = 25,
        icon = "tcs_spell_projection_vicieuses",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_projection_vicieuses" },
        sort = 130,
    },
    jjk_projection_chercheuse = {
        title = "Aiguille Chercheuse",
        description = "Vous projettez une aiguille a tete chercheuse.",
        mana_cost = 35,
        icon = "tcs_spell_projection_chercheuse",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_projection_chercheuse" },
        sort = 131,
    },
    jjk_projection_malediction = {
        title = "Les 4 Maledictions",
        description = "Vous projettez 4 aiguilles qui infligent des degats et ralentissent les ennemis.",
        mana_cost = 45,
        icon = "tcs_spell_projection_malediction",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_projection_malediction" },
        sort = 132,
    },
    jjk_projection_pluie = {
        title = "Pluie de 1000 Aiguilles",
        description = "Vous projettez une pluie d'aiguilles qui infligent des degats.",
        mana_cost = 55,
        icon = "tcs_spell_projection_pluie",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_projection_pluie" },
        sort = 133,
    },

    -- Voie Martiale : Lance (Naginata)
    jjk_lance_balayage = {
        title = "Balayage de l'Empereur",
        description = "Vous donnez un puissant coup de lance face a vous puis reculez.",
        mana_cost = 10,
        icon = "tcs_weapon_lance_balayage",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_lance_balayage" },
        sort = 200,
    },
    jjk_lance_trainee = {
        title = "Trainee Tellurique",
        description = "Vous invoquez une trainee tellurique infligeant des degats a tous les ennemis dans son rayon.",
        mana_cost = 20,
        icon = "tcs_weapon_lance_trainee",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_lance_trainee" },
        sort = 201,
    },
    jjk_lance_foudroyante = {
        title = "Lance Foudroyante",
        description = "Vous lancez votre lance. Elle peut empaler un adversaire. Reactivez pour vous ruer dessus.",
        mana_cost = 30,
        icon = "tcs_weapon_lance_foudroyante",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_lance_foudroyante" },
        sort = 202,
    },
    jjk_lance_lubu = {
        title = "Charge de Lu Bu",
        description = "Vous chargez et vous deplacez rapidement en empalant vos ennemis, les etourdissant a l'impact.",
        mana_cost = 40,
        icon = "tcs_weapon_lance_lubu",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_lance_lubu" },
        sort = 203,
    },

    -- Voie Martiale : Katana
    jjk_katana_ouragan = {
        title = "Ouragan",
        description = "Vous projetez une tornade qui attire les ennemis sur son passage et inflige des degats sur la duree.",
        mana_cost = 10,
        icon = "tcs_weapon_katana_ouragan",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_katana_ouragan" },
        sort = 210,
    },
    jjk_katana_danse = {
        title = "Danse Ascendante",
        description = "Vous vous projetez en avant. Si vous touchez quelqu'un, il est etourdi et vous lui assenez une serie de coups.",
        mana_cost = 20,
        icon = "tcs_weapon_katana_danse",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_katana_danse" },
        sort = 211,
    },
    jjk_katana_ruee = {
        title = "Ruee d'Acier",
        description = "Vous vous projetez dans les airs avant de retomber pour infliger de lourds degats et provoquer un saignement.",
        mana_cost = 30,
        icon = "tcs_weapon_katana_ruee",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_katana_ruee" },
        sort = 212,
    },
    jjk_katana_eveil = {
        title = "Eveil du Samourai",
        description = "Vous vous immobilisez quelques secondes avant d'augmenter vos degats, vitesse d'attaque et vitesse.",
        mana_cost = 40,
        icon = "tcs_weapon_katana_eveil",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_katana_eveil" },
        sort = 213,
    },

    -- Voie Martiale : Poings Brutaux
    jjk_fists_charge = {
        title = "Poing Charge",
        description = "Vous chargez un coup puissant qui projette une onde de choc etourdissant les ennemis et brisant les gardes.",
        mana_cost = 10,
        icon = "tcs_weapon_fists_charge",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_fists_charge" },
        sort = 220,
    },
    jjk_fists_fracas = {
        title = "Fracas Sismique",
        description = "Vous vous elancez dans les airs avant de retomber en force, creant une onde de choc qui attire les ennemis.",
        mana_cost = 20,
        icon = "tcs_weapon_fists_fracas",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_fists_fracas" },
        sort = 221,
    },
    jjk_fists_prise = {
        title = "Prise au Sol",
        description = "Vous vous elancez. Si vous touchez un ennemi, vous le plaqucz au sol avec force, le etourdissant.",
        mana_cost = 30,
        icon = "tcs_weapon_fists_prise",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_fists_prise" },
        sort = 222,
    },
    jjk_fists_rafale = {
        title = "Rafale de Cent Coups",
        description = "Serie de coups rapides et puissants, puis un coup final critique. Touche plusieurs ennemis.",
        mana_cost = 40,
        icon = "tcs_weapon_fists_rafale",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_fists_rafale" },
        sort = 223,
    },

    -- ─── Techniques de Clan : Gojo ──────────────────────────────────────────
    jjk_gojo_bleu = {
        title = "Bleu",
        description = "Invoque une boule d'energie qui genere une force d'aspiration, effectuant deux rotations autour du lanceur.",
        mana_cost = 10,
        icon = "tcs_clan_gojo_bleu",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_gojo_bleu" },
        sort = 300,
    },
    jjk_gojo_red = {
        title = "Rouge",
        description = "Invoque une boule d'energie qui genere une force de repoussement face a lui et aveugle les ennemis.",
        mana_cost = 20,
        icon = "tcs_clan_gojo_rouge",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_gojo_red" },
        sort = 301,
    },
    jjk_gojo_infinite = {
        title = "Infinie",
        description = "S'enveloppe dans l'infinie, devenant intangible pendant quelques secondes.",
        mana_cost = 30,
        icon = "tcs_clan_gojo_infinie",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_gojo_infinite" },
        sort = 302,
    },
    jjk_gojo_violet = {
        title = "Violet",
        description = "Fusionne les forces d'attraction et de repulsion en une boule d'energie violette devastatrice en ligne droite.",
        mana_cost = 40,
        icon = "tcs_clan_gojo_violet",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_gojo_violet" },
        sort = 303,
    },

    -- ─── Techniques de Clan : Sukuna ────────────────────────────────────────
    jjk_sukuna_laceration = {
        title = "Laceration Rapide",
        description = "Projette un souffle face a vous qui inflige des degats et repousse les ennemis. Rang D.",
        mana_cost = 10,
        icon = "tcs_clan_sukuna_laceration",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_sukuna_laceration" },
        sort = 310,
    },
    jjk_sukuna_effroi = {
        title = "Effroi du Roi Fleau",
        description = "Plonge la cible dans une illusion puissante qui la rend immobile. Rang C.",
        mana_cost = 20,
        icon = "tcs_clan_sukuna_effroi",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_sukuna_effroi" },
        sort = 311,
    },
    jjk_sukuna_dismantle = {
        title = "Dismantle Slash",
        description = "Dissecque toute une zone devant vous, infligeant de lourds degats et du saignement. Rang B.",
        mana_cost = 30,
        icon = "tcs_clan_sukuna_dismantle",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_sukuna_dismantle" },
        sort = 312,
    },
    jjk_sukuna_fuga = {
        title = "Fuga",
        description = "Charge une fleche de feu qui provoque une explosion devastatrice. Rang A.",
        mana_cost = 40,
        icon = "tcs_clan_sukuna_fuga",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_sukuna_fuga" },
        sort = 313,
    },

    -- ─── Techniques de Clan : Mahito ────────────────────────────────────────
    jjk_mahito_oursin = {
        title = "Transformation : Oursin",
        description = "Saute et se transforme en oursin pour infliger des degats aux ennemis au contact. Rang D.",
        mana_cost = 10,
        icon = "tcs_clan_mahito_oursin",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_mahito_oursin" },
        sort = 320,
    },
    jjk_mahito_ame = {
        title = "Vol d'Ame",
        description = "Attrape la cible et draine une partie de son ame, volant ses points de vie. Rang C.",
        mana_cost = 20,
        icon = "tcs_clan_mahito_ame",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_mahito_ame" },
        sort = 321,
    },
    jjk_mahito_transfiguration = {
        title = "Transfiguration",
        description = "Fait sortir sa main du sol, transformant temporairement les cibles touchees en fleaux et les ralentissant. Rang B.",
        mana_cost = 30,
        icon = "tcs_clan_mahito_transfiguration",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_mahito_transfiguration" },
        sort = 322,
    },
    jjk_mahito_complete = {
        title = "Transformation : Complete",
        description = "Se transforme en predateur, gagnant vol de vie, boost de degats physiques et de vitesse. Rang A.",
        mana_cost = 40,
        icon = "tcs_clan_mahito_complete",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_mahito_complete" },
        sort = 323,
    },

    -- ─── Techniques de Clan : Zenin ─────────────────────────────────────────────
    jjk_zenin_loup = {
        title = "Chien Divin",
        description = "Invoque le Chien Divin depuis son ombre pour traquer et mordre les ennemis. Rang D.",
        mana_cost = 10,
        icon = "tcs_clan_zenin_loup",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_zenin_dog" },
        sort = 330,
    },
    jjk_zenin_nue = {
        title = "Nue",
        description = "Invoque Nue, l'oiseau de foudre, qui plonge sur les ennemis et les paralyse d'electricite. Rang C.",
        mana_cost = 20,
        icon = "tcs_clan_zenin_nue",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_zenin_bird" },
        sort = 331,
    },
    jjk_zenin_toad = {
        title = "Grand Crapaud",
        description = "Invoque un immense crapaud qui avale ou projette les ennemis avec sa langue. Rang B.",
        mana_cost = 30,
        icon = "tcs_clan_zenin_toad",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_zenin_toad" },
        sort = 332,
    },
    jjk_zenin_mahoraga = {
        title = "Mahoraga",
        description = "Invoque le General Divin aux Huit Poignees, le shikigami imbattable qui s'adapte a toute technique. Rang A.",
        mana_cost = 40,
        icon = "tcs_clan_zenin_mahoraga",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_zenin_mahoraga" },
        sort = 333,
    },

    -- ─── Heritage : Hanami ────────────────────────────────────────────────────────
    -- Remplace les spell_id par les IDs TCS correspondants si differents.
    -- ─── Heritage : Hanami ───────────────────────────────────────────────────────
    jjk_hanami_racines = {
        title = "Racines fixactrices",
        description = "Envoi des racines bloquant sur place les joueurs touches. Rang D.",
        mana_cost = 15,
        icon = "tcs_heritage_hanami_racines",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_hanami_racines" },
        sort = 400,
    },
    jjk_hanami_spores = {
        title = "Aura Sporee",
        description = "Deploie une plante qui expulse des spores toxiques. Rang C.",
        mana_cost = 25,
        icon = "tcs_heritage_hanami_spores",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_hanami_spores" },
        sort = 401,
    },
    jjk_hanami_bourgeon = {
        title = "Bourgeon Maudit",
        description = "Deploie une plante qui projette des salves sur les ennemis proches. Rang B.",
        mana_cost = 35,
        icon = "tcs_heritage_hanami_bourgeon",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_hanami_bourgeon" },
        sort = 402,
    },
    jjk_hanami_arbre = {
        title = "Arbre de Vie",
        description = "Deploie un arbre soignant toutes les personnes aux alentours. Rang A.",
        mana_cost = 50,
        icon = "tcs_heritage_hanami_arbre",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_hanami_arbre" },
        sort = 403,
    },

    -- ─── Heritage : Jogo ──────────────────────────────────────────────────────────
    jjk_jogo_embrasement = {
        title = "Embrasement",
        description = "Le joueur s'embrase et fait fondre le sol a proximite le transformant en lave. Rang D.",
        mana_cost = 15,
        icon = "tcs_heritage_jogo_embrasement",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_jogo_embrasement" },
        sort = 410,
    },
    jjk_jogo_poings = {
        title = "Poings de Magma",
        description = "S'entoure de poings de magma et enchaine un combo vers l'ennemi le plus proche, le brulant. Rang C.",
        mana_cost = 25,
        icon = "tcs_heritage_jogo_poings",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_jogo_poings" },
        sort = 411,
    },
    jjk_jogo_hibashira = {
        title = "Hibashira",
        description = "Deploie un geyser de feu qui brule et projette les ennemis. Rang B.",
        mana_cost = 35,
        icon = "tcs_heritage_jogo_hibashira",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_jogo_hibashira" },
        sort = 412,
    },
    jjk_jogo_meteor = {
        title = "Meteore Supreme",
        description = "Fait tomber une enorme meteorite du ciel a l'endroit vise. Rang A.",
        mana_cost = 55,
        icon = "tcs_heritage_jogo_meteor",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_jogo_meteor" },
        sort = 413,
    },

    -- ─── Heritage : Itadori ───────────────────────────────────────────────────────
    jjk_itadori_poing = {
        title = "Flash Attack",
        description = "Concentre l'energie occulte dans le poing puis fonce en avant pour frapper le premier ennemi rencontre. Rang D.",
        mana_cost = 15,
        icon = "tcs_heritage_itadori_poing",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_yuji_flash" },
        sort = 420,
    },
    jjk_itadori_flash = {
        title = "Mode Taido",
        description = "Augmente vos degats de melee, permet de double-sauter et d'esquiver plus rapidement. Rang C.",
        mana_cost = 25,
        icon = "tcs_heritage_itadori_flash",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_yuji_taido" },
        sort = 421,
    },
    jjk_itadori_frappe = {
        title = "Contre Black Flash",
        description = "Pendant un court instant, absorbe le prochain coup de melee et riposte avec un Black Flash. Rang B.",
        mana_cost = 35,
        icon = "tcs_heritage_itadori_frappe",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_yuji_counter" },
        sort = 422,
    },
    jjk_itadori_execution = {
        title = "Black Flash Enchaine",
        description = "Frappe declencheuse qui, en cas de touche, enchaine une combo fulgurante de quatre Black Flash. Rang A.",
        mana_cost = 55,
        icon = "tcs_heritage_itadori_execution",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_yuji_enchaine" },
        sort = 423,
    },

    -- ─── Heritage : Todo ──────────────────────────────────────────────────────────
    jjk_todo_boogie = {
        title = "Boogie Woogie",
        description = "Echange instantanement de position avec une cible en claquant des mains. Rang D.",
        mana_cost = 15,
        icon = "tcs_heritage_todo_boogie",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_todo_boogie" },
        sort = 430,
    },
    jjk_todo_echange = {
        title = "Concentration Ultime",
        description = "Entre dans une phase de concentration ultime ou l'utilisateur esquive automatiquement un certain nombre d'attaques physiques. Rang D.",
        mana_cost = 25,
        icon = "tcs_heritage_todo_echange",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_todo_concentration" },
        sort = 431,
    },
    jjk_todo_combo = {
        title = "Piege Boogie",
        description = "Lance un caillou en cloche. Reactive le sort avant son impact pour s'y teleporter et ecraser l'adversaire. Rang D.",
        mana_cost = 35,
        icon = "tcs_heritage_todo_combo",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_todo_piege_boogie" },
        sort = 432,
    },
    jjk_todo_supreme = {
        title = "Rainbow Flash",
        description = "Repousse l'adversaire d'un coup de pied, se teleporte derriere lui et enchaine un Black Flash qui le projette dans l'autre sens. Rang A.",
        mana_cost = 55,
        icon = "tcs_heritage_todo_supreme",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_todo_rainbow" },
        sort = 433,
    },

    -- ─── Heritage : Yuta ──────────────────────────────────────────────────────────
    jjk_yuta_invocation = {
        title = "Amour Juvénile",
        description = "Invoque Rika, un familier maudit qui contre-attaque vos cibles. Rang D.",
        mana_cost = 10,
        icon = "tcs_heritage_yuta_invocation",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_yuta_amour" },
        sort = 440,
    },
    jjk_yuta_copie = {
        title = "Étreinte Démoniaque",
        description = "Rika saisit votre cible par-derrière et l'immobilise. Rang C.",
        mana_cost = 15,
        icon = "tcs_heritage_yuta_copie",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_yuta_etreinte" },
        sort = 441,
    },
    jjk_yuta_inverse = {
        title = "Don de Rika",
        description = "Rika charge en ligne droite, inflige des degats et copie la derniere technique de la cible. Rang B.",
        mana_cost = 20,
        icon = "tcs_heritage_yuta_inverse",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_yuta_vol" },
        sort = 442,
    },
    jjk_yuta_rika = {
        title = "Violet Copié",
        description = "Yuta copie le Violet de Gojo et projette un rayon devastateur qui transperce tous les ennemis. Rang A.",
        mana_cost = 25,
        icon = "tcs_heritage_yuta_rika",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_yuta_violet" },
        sort = 443,
    },

    -- ─── Heritage : Finger Bearer ─────────────────────────────────────────────────
    jjk_finger_spurk = {
        title = "Spurk",
        description = "Crachez un projectile de poison qui ralentit l'ennemi touche. Rang D.",
        mana_cost = 15,
        icon = "tcs_heritage_finger_spurk",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_finger_spurk" },
        sort = 450,
    },
    jjk_finger_griffe = {
        title = "Griffe de l'Ombre",
        description = "Disparaissez dans l'ombre puis reapparaissez d'un coup de griffe pour etourdir un ennemi proche. Rang C.",
        mana_cost = 25,
        icon = "tcs_heritage_finger_griffe",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_finger_griffe" },
        sort = 451,
    },
    jjk_finger_souffle = {
        title = "Souffle Radioactif",
        description = "Projetez un souffle radioactif qui emporte et irradie les ennemis sur son chemin. Rang B.",
        mana_cost = 35,
        icon = "tcs_heritage_finger_souffle",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_finger_souffle" },
        sort = 452,
    },
    jjk_finger_irradiation = {
        title = "Irradiation",
        description = "Irradiez un ennemi d'une energie maudite devastatrice. Rang A.",
        mana_cost = 50,
        icon = "tcs_heritage_finger_irradiation",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_finger_irradiation" },
        sort = 453,
    },
    -- ── Contrôle ──────────────────────────────────────────────────────────────
    jjk_controle_tsukamoto = {
        title = "Controle : Tsukamoto",
        description = "Invoque Tsukamoto a vos cotes. Il contre-attaque le premier ennemi qui vous frappe. Rang D.",
        mana_cost = 10,
        icon = "tcs_heritage_controle_tsukamoto",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_controle_tsukamoto" },
        sort = 460,
    },
    jjk_controle_kappa = {
        title = "Controle : Ruee du Kappa",
        description = "Invoque le Kappa qui fonce en ligne droite en zigzaguant, infligeant des degats et stunant chaque cible touchee. Rang C.",
        mana_cost = 30,
        icon = "tcs_heritage_controle_kappa",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_controle_kappa" },
        sort = 461,
    },
    jjk_controle_tempete = {
        title = "Controle : Tempete rebondissante",
        description = "Invoque Cathy qui ricoche en etoile, infligeant des degats et ralentissant les cibles, puis explose au centre. Rang B.",
        mana_cost = 30,
        icon = "tcs_heritage_controle_tempete",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_controle_tempete" },
        sort = 462,
    },
    jjk_controle_gonflette = {
        title = "Controle : Tsukamoto Gonflette",
        description = "Invoque Tsukamoto qui se gonfle puis traque sans relache votre cible et la martele. Rang A.",
        mana_cost = 25,
        icon = "tcs_heritage_controle_gonflette",
        bindable = true,
        execution = { type = "tcs_spell", spell_id = "jjk_controle_gonflette" },
        sort = 463,
    },
}

for abilityId, abilityData in pairs(_defaultAbilities) do
    if not istable(ST.Abilities[abilityId]) then
        ST.Abilities[abilityId] = table.Copy(abilityData)
    else
        for key, value in pairs(abilityData) do
            if ST.Abilities[abilityId][key] == nil then
                ST.Abilities[abilityId][key] = istable(value) and table.Copy(value) or value
            end
        end
    end
end

ST.Tree = {
    {
        id = "cursed_powers",
        title = "Pouvoirs Maudits",
        icon = "skilltree_category_cursed_icon",
        color = Color(30, 155, 255),
        subtypes = {
            {
                id = "cursed_application",
                title = "Application",
                icon = "skilltree_sub_application_icon",
                color = Color(30, 155, 255),
                description = "Techniques d'application de l'energie occulte sur soi-meme ou ses coups.",
                nodes = {
                    {
                        id = "cp_application_impact",
                        title = "Impact Maudit",
                        description = "Coup puissant qui etourdit les ennemis. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_application_impact" },
                    },
                    {
                        id = "cp_application_peau",
                        title = "Peau Renforcee",
                        description = "Renforcez votre peau pour resister aux degats. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "cp_application_impact", rank = 1 } },
                        abilities = { "jjk_application_peau" },
                    },
                    {
                        id = "cp_application_sprint",
                        title = "Sprint Occulte",
                        description = "Dash vers l'avant en assenant un coup de pied. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "cp_application_peau", rank = 1 } },
                        abilities = { "jjk_application_sprint" },
                    },
                    {
                        id = "cp_application_blackflash",
                        title = "Black Flash",
                        description = "Charge un coup puissant a energie occulte condensee. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "cp_application_sprint", rank = 1 } },
                        abilities = { "jjk_application_blackflash" },
                    },
                },
            },
            {
                id = "cursed_invocation",
                title = "Invocation",
                icon = "skilltree_sub_invocation_icon",
                color = Color(50, 200, 70),
                description = "Techniques d'invocation de fleau et de creatures maudites.",
                nodes = {
                    {
                        id = "cp_invocation_grotte",
                        title = "Invocation : Gribbloeil",
                        description = "Invoquez une gribbloeil qui traque et frappe votre cible. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_invocation_grotte" },
                    },
                    {
                        id = "cp_invocation_reptilien",
                        title = "Invocation : Gardien Reptilien",
                        description = "Invoquez un reptilien qui intoxique la zone visee. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "cp_invocation_grotte", rank = 1 } },
                        abilities = { "jjk_invocation_reptilien" },
                    },
                    {
                        id = "cp_invocation_etreinte",
                        title = "Invocation : Etreinte de l'Araignee",
                        description = "Invoquez un fleau qui projette une toile immobilisante. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "cp_invocation_reptilien", rank = 1 } },
                        abilities = { "jjk_invocation_etreinte" },
                    },
                    {
                        id = "cp_invocation_purgatoire",
                        title = "Invocation : Purgatoire des Damnes",
                        description = "Invoquez un fleau dont le hurlement inflige degats et confusion. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "cp_invocation_etreinte", rank = 1 } },
                        abilities = { "jjk_invocation_purgatoire" },
                    },
                },
            },
            {
                id = "cursed_projection",
                title = "Projection",
                icon = "skilltree_sub_projection_icon",
                color = Color(220, 30, 30),
                description = "Techniques de projection de malefices et d'aiguilles occultes.",
                nodes = {
                    {
                        id = "cp_projection_vicieuses",
                        title = "Aiguilles Vicieuses",
                        description = "Projettez 5 aiguilles en arc qui ralentissent les ennemis. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_projection_vicieuses" },
                    },
                    {
                        id = "cp_projection_chercheuse",
                        title = "Aiguille Chercheuse",
                        description = "Projettez une aiguille a tete chercheuse. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "cp_projection_vicieuses", rank = 1 } },
                        abilities = { "jjk_projection_chercheuse" },
                    },
                    {
                        id = "cp_projection_malediction",
                        title = "Les 4 Maledictions",
                        description = "Projettez 4 aiguilles qui infligent degats et ralentissement. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "cp_projection_chercheuse", rank = 1 } },
                        abilities = { "jjk_projection_malediction" },
                    },
                    {
                        id = "cp_projection_pluie",
                        title = "Pluie de 1000 Aiguilles",
                        description = "Projettez une pluie d'aiguilles devastatrice. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "cp_projection_malediction", rank = 1 } },
                        abilities = { "jjk_projection_pluie" },
                    },
                },
            },
            -- ── Contrôle ────────────────────────────────────────────────────────
            {
                id = "cursed_controle",
                title = "Controle",
                icon = "skilltree_sub_controle_icon",
                color = Color(255, 140, 0),
                description = "Techniques de controle des esprits maudits : Tsukamoto, le Kappa et Cathy.",
                nodes = {
                    {
                        id = "cp_controle_tsukamoto",
                        title = "Tsukamoto",
                        description = "Invoque Tsukamoto a vos cotes. Il contre-attaque le premier ennemi qui vous frappe. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_controle_tsukamoto" },
                    },
                    {
                        id = "cp_controle_kappa",
                        title = "Ruee du Kappa",
                        description = "Invoque le Kappa qui fonce en zigzaguant, infligeant des degats et stunant les cibles. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "cp_controle_tsukamoto", rank = 1 } },
                        abilities = { "jjk_controle_kappa" },
                    },
                    {
                        id = "cp_controle_tempete",
                        title = "Tempete rebondissante",
                        description = "Invoque Cathy qui ricoche en etoile, infligeant des degats et ralentissant les cibles, puis explose. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "cp_controle_kappa", rank = 1 } },
                        abilities = { "jjk_controle_tempete" },
                    },
                    {
                        id = "cp_controle_gonflette",
                        title = "Tsukamoto Gonflette",
                        description = "Invoque Tsukamoto qui se gonfle puis traque sans relache votre cible et la martele. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "cp_controle_tempete", rank = 1 } },
                        abilities = { "jjk_controle_gonflette" },
                    },
                },
            },
        },
    },
    {
        id = "voie_martiale",
        title = "Voie Martiale",
        icon = "skilltree_category_martial_icon",
        color = Color(240, 195, 30),
        subtypes = {
            {
                id = "martial_lance",
                title = "Lance (Naginata)",
                icon = "skilltree_sub_naginata_icon",
                color = Color(215, 45, 175),
                description = "Maitrisez la lance et ses techniques devastatrices a longue portee.",
                nodes = {
                    {
                        id = "vm_lance_balayage",
                        title = "Balayage de l'Empereur",
                        description = "Coup de lance frontal puissant suivi d'un recul. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_lance_balayage" },
                    },
                    {
                        id = "vm_lance_trainee",
                        title = "Trainee Tellurique",
                        description = "Trainee qui inflige des degats en zone. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "vm_lance_balayage", rank = 1 } },
                        abilities = { "jjk_lance_trainee" },
                    },
                    {
                        id = "vm_lance_foudroyante",
                        title = "Lance Foudroyante",
                        description = "Lancez votre lance pour empaler et etourdir. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "vm_lance_trainee", rank = 1 } },
                        abilities = { "jjk_lance_foudroyante" },
                    },
                    {
                        id = "vm_lance_lubu",
                        title = "Charge de Lu Bu",
                        description = "Charge devastatrice qui empale et etourdit les ennemis. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "vm_lance_foudroyante", rank = 1 } },
                        abilities = { "jjk_lance_lubu" },
                    },
                },
            },
            {
                id = "martial_katana",
                title = "Katana",
                icon = "skilltree_sub_katana_icon",
                color = Color(0, 180, 165),
                description = "Maitrisez le katana et ses techniques de precision fulgurantes.",
                nodes = {
                    {
                        id = "vm_katana_ouragan",
                        title = "Ouragan",
                        description = "Tornade qui attire les ennemis et inflige des degats. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_katana_ouragan" },
                    },
                    {
                        id = "vm_katana_danse",
                        title = "Danse Ascendante",
                        description = "Projection vers l'avant et serie de coups si contact. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "vm_katana_ouragan", rank = 1 } },
                        abilities = { "jjk_katana_danse" },
                    },
                    {
                        id = "vm_katana_ruee",
                        title = "Ruee d'Acier",
                        description = "Plongee aerienne causant lourds degats et saignement. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "vm_katana_danse", rank = 1 } },
                        abilities = { "jjk_katana_ruee" },
                    },
                    {
                        id = "vm_katana_eveil",
                        title = "Eveil du Samourai",
                        description = "Augmente degats, vitesse d'attaque et vitesse de deplacement. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "vm_katana_ruee", rank = 1 } },
                        abilities = { "jjk_katana_eveil" },
                    },
                },
            },
            {
                id = "martial_fists",
                title = "Poings Brutaux",
                icon = "skilltree_sub_poings_icon",
                color = Color(240, 195, 30),
                description = "Maitrisez le combat a mains nues et ses techniques sismiques.",
                nodes = {
                    {
                        id = "vm_fists_charge",
                        title = "Poing Charge",
                        description = "Onde de choc qui etourdit et brise les gardes. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_fists_charge" },
                    },
                    {
                        id = "vm_fists_fracas",
                        title = "Fracas Sismique",
                        description = "Retombee en force creant une onde qui attire les ennemis. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "vm_fists_charge", rank = 1 } },
                        abilities = { "jjk_fists_fracas" },
                    },
                    {
                        id = "vm_fists_prise",
                        title = "Prise au Sol",
                        description = "Projection et placage au sol avec etourdissement. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "vm_fists_fracas", rank = 1 } },
                        abilities = { "jjk_fists_prise" },
                    },
                    {
                        id = "vm_fists_rafale",
                        title = "Rafale de Cent Coups",
                        description = "Serie de coups rapides terminee par un impact critique devastateur. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "vm_fists_prise", rank = 1 } },
                        abilities = { "jjk_fists_rafale" },
                    },
                },
            },
        },
    },
    -- ─── Techniques de Clan ──────────────────────────────────────────────────────
    -- Accessible uniquement aux joueurs ayant un job de clan (ex : classe_4_gojo).
    -- Chaque sous-type correspond à un clan. Les tiers débloqués sont définis dans
    -- ST.ClassGates avec la clé "clan".
    --
    -- Paliers d'accès (par rapport au grade de clan attribué) :
    --   Classe 4  → tier 1   |  Classe 3      → tier 1 (inchangé)
    --   Semi-C.2  → tier 2   |  Classe 2      → tier 3
    --   Semi-C.1  → tier 3 (inchangé)   |  Classe 1 → tier 4   |  Classe S → tier 5
    -- ─────────────────────────────────────────────────────────────────────────────
    {
        id = "technique_clan",
        title = "Technique de Clan",
        icon = "skilltree_category_clans_icon",
        color = Color(100, 180, 255),
        subtypes = {
            {
                id = "clan_gojo",
                title = "Clan Gojo",
                icon = "skilltree_sub_clans_big_icon",
                color = Color(100, 180, 255),
                description = "Techniques hereditaires du clan Gojo, transmises aux seuls membres dignes.",
                nodes = {
                    -- Tier 1 : debloque a Classe 4 Gojo
                    {
                        id = "gojo_bleu",
                        title = "Bleu",
                        description = "Invoque une boule d'energie qui aspire les ennemis autour du lanceur. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_gojo_bleu" },
                    },
                    -- Tier 2 : debloque a Semi-Classe 2 Gojo
                    {
                        id = "gojo_rouge",
                        title = "Rouge",
                        description = "Invoque une boule d'energie qui repousse et aveugle les ennemis. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "gojo_bleu", rank = 1 } },
                        abilities = { "jjk_gojo_red" },
                    },
                    -- Tier 3 : debloque a Classe 2 Gojo
                    {
                        id = "gojo_infinie",
                        title = "Infinie",
                        description = "S'enveloppe dans l'infinie, devenant intangible pendant quelques secondes. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "gojo_rouge", rank = 1 } },
                        abilities = { "jjk_gojo_infinite" },
                    },
                    -- Tier 4 : debloque a Classe 1 Gojo (et Classe S)
                    {
                        id = "gojo_violet",
                        title = "Violet",
                        description = "Fusionne Bleu et Rouge en une sphere devastatrice en ligne droite. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "gojo_infinie", rank = 1 } },
                        abilities = { "jjk_gojo_violet" },
                    },
                },
            },
            {
                id = "clan_sukuna",
                title = "Clan Sukuna",
                icon = "skilltree_sub_clans_big_icon",
                color = Color(200, 30, 30),
                description = "Techniques hereditaires du clan Sukuna, portees par les dignes successeurs du Roi des Fleaux.",
                nodes = {
                    -- Tier 1 : debloque a Classe 4 Sukuna
                    {
                        id = "sukuna_laceration",
                        title = "Laceration Rapide",
                        description = "Projette un souffle devastateur qui repousse les ennemis. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_sukuna_laceration" },
                    },
                    -- Tier 2 : debloque a Semi-Classe 2 Sukuna
                    {
                        id = "sukuna_effroi",
                        title = "Effroi du Roi Fleau",
                        description = "Plonge la cible dans une illusion qui la rend immobile. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "sukuna_laceration", rank = 1 } },
                        abilities = { "jjk_sukuna_effroi" },
                    },
                    -- Tier 3 : debloque a Classe 2 Sukuna
                    {
                        id = "sukuna_dismantle",
                        title = "Dismantle Slash",
                        description = "Dissecque une zone entiere, infligeant lourds degats et saignement. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "sukuna_effroi", rank = 1 } },
                        abilities = { "jjk_sukuna_dismantle" },
                    },
                    -- Tier 4 : debloque a Classe 1 Sukuna (et Classe S)
                    {
                        id = "sukuna_fuga",
                        title = "Fuga",
                        description = "Charge une fleche de feu qui provoque une explosion devastatrice. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "sukuna_dismantle", rank = 1 } },
                        abilities = { "jjk_sukuna_fuga" },
                    },
                },
            },
            {
                id = "clan_mahito",
                title = "Clan Mahito",
                icon = "skilltree_sub_clans_big_icon",
                color = Color(80, 180, 120),
                description = "Techniques hereditaires du clan Mahito, maitres de la transfiguration des ames.",
                nodes = {
                    -- Tier 1 : debloque a Classe 4 Mahito
                    {
                        id = "mahito_oursin",
                        title = "Transformation : Oursin",
                        description = "Se transforme en oursin pour infliger des degats au contact. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_mahito_oursin" },
                    },
                    -- Tier 2 : debloque a Semi-Classe 2 Mahito
                    {
                        id = "mahito_ame",
                        title = "Vol d'Ame",
                        description = "Attrape la cible et draine son ame pour voler ses points de vie. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "mahito_oursin", rank = 1 } },
                        abilities = { "jjk_mahito_ame" },
                    },
                    -- Tier 3 : debloque a Classe 2 Mahito
                    {
                        id = "mahito_transfiguration",
                        title = "Transfiguration",
                        description = "Fait sortir sa main du sol et transforme les cibles en fleaux, les ralentissant. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "mahito_ame", rank = 1 } },
                        abilities = { "jjk_mahito_transfiguration" },
                    },
                    -- Tier 4 : debloque a Classe 1 Mahito (et Classe S)
                    {
                        id = "mahito_complete",
                        title = "Transformation : Complete",
                        description = "Se transforme en predateur avec vol de vie, boost degats et vitesse. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "mahito_transfiguration", rank = 1 } },
                        abilities = { "jjk_mahito_complete" },
                    },
                },
            },
            {
                id = "clan_zenin",
                title = "Clan Zenin",
                icon = "skilltree_sub_heritage_big_icon",
                color = Color(200, 160, 40),
                description = "Techniques hereditaires du clan Zenin, maitres des Dix Ombres et de l'invocation de shikigami.",
                nodes = {
                    -- Tier 1 : debloque a Classe 4 Zenin
                    {
                        id = "zenin_loup",
                        title = "Chien Divin",
                        description = "Invoque le Chien Divin depuis son ombre pour traquer et mordre les ennemis. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_zenin_loup" },
                    },
                    -- Tier 2 : debloque a Semi-Classe 2 Zenin
                    {
                        id = "zenin_nue",
                        title = "Nue",
                        description = "Invoque Nue, l'oiseau de foudre, qui plonge et paralyse les ennemis. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "zenin_loup", rank = 1 } },
                        abilities = { "jjk_zenin_nue" },
                    },
                    -- Tier 3 : debloque a Classe 2 Zenin
                    {
                        id = "zenin_toad",
                        title = "Grand Crapaud",
                        description = "Invoque un immense crapaud qui avale ou projette les ennemis avec sa langue. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "zenin_nue", rank = 1 } },
                        abilities = { "jjk_zenin_toad" },
                    },
                    -- Tier 4 : debloque a Classe 1 Zenin (et Classe S)
                    {
                        id = "zenin_mahoraga",
                        title = "Mahoraga",
                        description = "Invoque le General Divin aux Huit Poignees, le shikigami imbattable. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "zenin_toad", rank = 1 } },
                        abilities = { "jjk_zenin_mahoraga" },
                    },
                },
            },
        },
    },
    -- ─── Heritage ──────────────────────────────────────────────────────────────────
    -- Accessible uniquement aux joueurs ayant un job d'heritage (ex : classe_4_hanami).
    -- Obtenu via le reroll Heritage en boutique (reward_type = "skilltree_branch").
    -- ──────────────────────────────────────────────────────────────────────────────
    {
        id = "heritage",
        title = "Heritage",
        icon = "skilltree_category_heritage_icon",
        color = Color(167, 111, 255),
        subtypes = {
            -- ── Hanami ──────────────────────────────────────────────────────────
            {
                id = "heritage_hanami",
                title = "Hanami",
                icon = "skilltree_sub_heritage_big_icon",
                color = Color(120, 200, 100),
                description = "Techniques heritees de l'esprit maudit Hanami, maitre de la nature et de la vegetation.",
                nodes = {
                    -- Tier 1 : debloque a Classe 4
                    {
                        id = "hanami_racines",
                        title = "Racines fixactrices",
                        description = "Envoi des racines bloquant sur place les joueurs touches. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_hanami_racines" },
                    },
                    -- Tier 2 : debloque a Classe 3
                    {
                        id = "hanami_spores",
                        title = "Aura Sporee",
                        description = "Deploie une plante qui expulse des spores toxiques. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "hanami_racines", rank = 1 } },
                        abilities = { "jjk_hanami_spores" },
                    },
                    -- Tier 3 : debloque a Classe 2
                    {
                        id = "hanami_bourgeon",
                        title = "Bourgeon Maudit",
                        description = "Deploie une plante qui projette des salves sur les ennemis proches. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "hanami_spores", rank = 1 } },
                        abilities = { "jjk_hanami_bourgeon" },
                    },
                    -- Tier 4 : debloque a Semi-Classe 1
                    {
                        id = "hanami_arbre",
                        title = "Arbre de Vie",
                        description = "Deploie un arbre soignant toutes les personnes aux alentours. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "hanami_bourgeon", rank = 1 } },
                        abilities = { "jjk_hanami_arbre" },
                    },
                },
            },
            -- ── Jogo ────────────────────────────────────────────────────────────
            {
                id = "heritage_jogo",
                title = "Jogo",
                icon = "skilltree_sub_heritage_big_icon",
                color = Color(255, 120, 40),
                description = "Techniques heritees de l'esprit maudit Jogo, incarnation des volcans et du feu.",
                nodes = {
                    -- Tier 1 : debloque a Classe 4
                    {
                        id = "jogo_embrasement",
                        title = "Embrasement",
                        description = "Le joueur s'embrase et fait fondre le sol a proximite le transformant en lave. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_jogo_embrasement" },
                    },
                    -- Tier 2 : debloque a Classe 3
                    {
                        id = "jogo_poings",
                        title = "Poings de Magma",
                        description = "S'entoure de poings de magma et enchaine un combo vers l'ennemi le plus proche, le brulant. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "jogo_embrasement", rank = 1 } },
                        abilities = { "jjk_jogo_poings" },
                    },
                    -- Tier 3 : debloque a Classe 2
                    {
                        id = "jogo_hibashira",
                        title = "Hibashira",
                        description = "Deploie un geyser de feu qui brule et projette les ennemis. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "jogo_poings", rank = 1 } },
                        abilities = { "jjk_jogo_hibashira" },
                    },
                    -- Tier 4 : debloque a Semi-Classe 1
                    {
                        id = "jogo_meteor",
                        title = "Meteore Supreme",
                        description = "Fait tomber une enorme meteorite du ciel a l'endroit vise. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "jogo_hibashira", rank = 1 } },
                        abilities = { "jjk_jogo_meteor" },
                    },
                },
            },
            -- ── Itadori ─────────────────────────────────────────────────────────
            {
                id = "heritage_itadori",
                title = "Itadori",
                icon = "skilltree_sub_heritage_big_icon",
                color = Color(220, 80, 180),
                description = "Techniques heritees de Yuji Itadori, vessel de Ryomen Sukuna, maitre de l'energie maudite rose.",
                nodes = {
                    {
                        id = "itadori_poing",
                        title = "Flash Attack",
                        description = "Concentre l'energie occulte dans le poing puis fonce en avant pour frapper le premier ennemi rencontre. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_itadori_poing" },
                    },
                    {
                        id = "itadori_flash",
                        title = "Mode Taido",
                        description = "Augmente vos degats de melee, permet de double-sauter et d'esquiver plus rapidement. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "itadori_poing", rank = 1 } },
                        abilities = { "jjk_itadori_flash" },
                    },
                    {
                        id = "itadori_frappe",
                        title = "Contre Black Flash",
                        description = "Pendant un court instant, absorbe le prochain coup de melee et riposte avec un Black Flash. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "itadori_flash", rank = 1 } },
                        abilities = { "jjk_itadori_frappe" },
                    },
                    {
                        id = "itadori_execution",
                        title = "Black Flash Enchaine",
                        description = "Frappe declencheuse qui, en cas de touche, enchaine une combo fulgurante de quatre Black Flash. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "itadori_frappe", rank = 1 } },
                        abilities = { "jjk_itadori_execution" },
                    },
                },
            },
            -- ── Todo ────────────────────────────────────────────────────────────
            {
                id = "heritage_todo",
                title = "Todo",
                icon = "skilltree_sub_heritage_big_icon",
                color = Color(80, 160, 255),
                description = "Techniques heritees d'Aoi Todo, maitre du Boogie Woogie et des echanges de position.",
                nodes = {
                    {
                        id = "todo_boogie",
                        title = "Boogie Woogie",
                        description = "Echange instantanement de position avec une cible en claquant des mains. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_todo_boogie" },
                    },
                    {
                        id = "todo_echange",
                        title = "Concentration Ultime",
                        description = "Entre dans une phase de concentration ultime ou l'utilisateur esquive automatiquement un certain nombre d'attaques physiques. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "todo_boogie", rank = 1 } },
                        abilities = { "jjk_todo_echange" },
                    },
                    {
                        id = "todo_combo",
                        title = "Piege Boogie",
                        description = "Lance un caillou en cloche. Reactive le sort avant son impact pour s'y teleporter et ecraser l'adversaire. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "todo_echange", rank = 1 } },
                        abilities = { "jjk_todo_combo" },
                    },
                    {
                        id = "todo_supreme",
                        title = "Rainbow Flash",
                        description = "Repousse l'adversaire d'un coup de pied, se teleporte derriere lui et enchaine un Black Flash qui le projette dans l'autre sens. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "todo_combo", rank = 1 } },
                        abilities = { "jjk_todo_supreme" },
                    },
                },
            },
            -- ── Yuta ────────────────────────────────────────────────────────────
            {
                id = "heritage_yuta",
                title = "Yuta",
                icon = "skilltree_sub_heritage_big_icon",
                color = Color(100, 220, 255),
                description = "Techniques heritees de Yuta Okkotsu, l'un des quatre etudiants de rang special, lie a Rika.",
                nodes = {
                    {
                        id = "yuta_invocation",
                        title = "Amour Juvénile",
                        description = "Invoque Rika, un familier maudit qui contre-attaque vos cibles. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_yuta_invocation" },
                    },
                    {
                        id = "yuta_copie",
                        title = "Étreinte Démoniaque",
                        description = "Rika saisit votre cible par-derrière et l'immobilise. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "yuta_invocation", rank = 1 } },
                        abilities = { "jjk_yuta_copie" },
                    },
                    {
                        id = "yuta_inverse",
                        title = "Don de Rika",
                        description = "Rika charge en ligne droite, inflige des degats et copie la derniere technique de la cible. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "yuta_copie", rank = 1 } },
                        abilities = { "jjk_yuta_inverse" },
                    },
                    {
                        id = "yuta_rika",
                        title = "Violet Copié",
                        description = "Yuta copie le Violet de Gojo et projette un rayon devastateur qui transperce tous les ennemis. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "yuta_inverse", rank = 1 } },
                        abilities = { "jjk_yuta_rika" },
                    },
                },
            },
            -- ── Finger Bearer ───────────────────────────────────────────────────
            {
                id = "heritage_finger",
                title = "Finger Bearer",
                icon = "skilltree_sub_heritage_big_icon",
                color = Color(220, 200, 60),
                description = "Techniques heritees d'un porteur de doigt de Sukuna : poison, ombre et radiation.",
                nodes = {
                    {
                        id = "finger_spurk",
                        title = "Spurk",
                        description = "Crachez un projectile de poison qui ralentit l'ennemi touche. Rang D.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 1,
                        abilities = { "jjk_finger_spurk" },
                    },
                    {
                        id = "finger_griffe",
                        title = "Griffe de l'Ombre",
                        description = "Disparaissez dans l'ombre puis reapparaissez d'un coup de griffe pour etourdir un ennemi proche. Rang C.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 2,
                        requires = { { id = "finger_spurk", rank = 1 } },
                        abilities = { "jjk_finger_griffe" },
                    },
                    {
                        id = "finger_souffle",
                        title = "Souffle Radioactif",
                        description = "Projetez un souffle radioactif qui emporte et irradie les ennemis sur son chemin. Rang B.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 3,
                        requires = { { id = "finger_griffe", rank = 1 } },
                        abilities = { "jjk_finger_souffle" },
                    },
                    {
                        id = "finger_irradiation",
                        title = "Irradiation",
                        description = "Irradiez un ennemi d'une energie maudite devastatrice. Rang A.",
                        node_type = "ability",
                        maxRank = 1,
                        cost = 4,
                        requires = { { id = "finger_souffle", rank = 1 } },
                        abilities = { "jjk_finger_irradiation" },
                    },
                },
            },
        },
    },
}

-- Auto-configure maxRank = 5 pour tous les noeuds lies a des sorts TCS (5 niveaux d'amelioration)
do
    local tcsAbils = {}
    for aId, aData in pairs(ST.Abilities or {}) do
        if istable(aData) and istable(aData.execution) and aData.execution.type == "tcs_spell" then
            tcsAbils[tostring(aId)] = true
        end
    end
    for _, cat in ipairs(ST.Tree or {}) do
        for _, sub in ipairs(cat.subtypes or {}) do
            for _, node in ipairs(sub.nodes or {}) do
                if node.node_type == "ability" then
                    for _, aid in ipairs(node.abilities or {}) do
                        if tcsAbils[tostring(aid)] then
                            node.maxRank = 5
                            break
                        end
                    end
                end
            end
        end
    end
end

ST.ExclusiveGroups = {
    {
        id      = "cursed_power_branch",
        label   = "Pouvoir Maudit",
        subtypes = { "cursed_application", "cursed_invocation", "cursed_projection", "cursed_controle" },
    },
    {
        id      = "martial_branch",
        label   = "Voie Martiale",
        subtypes = { "martial_lance", "martial_katana", "martial_fists" },
    },
    {
        id      = "heritage_branch",
        label   = "Heritage",
        subtypes = { "heritage_hanami", "heritage_jogo", "heritage_itadori", "heritage_todo", "heritage_yuta", "heritage_finger" },
    },
}

-- Groupes dont l'accès est réservé au système de reroll.
-- Un joueur ne peut PAS acheter librement dans ces branches :
-- il doit d'abord utiliser un ticket reroll pour se faire assigner une branche aléatoire.
ST.RerollGroups = { "cursed_power_branch", "heritage_branch" }

-- ─── Chances de reroll personnalisées ────────────────────────────────────────
-- Pour chaque groupe de reroll, définis le poids de chaque sous-type ainsi que
-- le poids de l'option "Rien" (nothingWeight = 0 → désactivée).
-- Les poids sont RELATIFS entre eux, pas des pourcentages directs.
--   Exemple : si application=2, invocation=1, projection=1 et nothingWeight=0
--             → Application 50%, Invocation 25%, Projection 25%
--   Exemple : nothingWeight=1 avec 3 sous-types à poids 1 chacun
--             → chaque sous-type ~25%, Rien ~25%
-- ─────────────────────────────────────────────────────────────────────────────
ST.RerollChancesConfig = ST.RerollChancesConfig or {
    ["cursed_power_branch"] = {
        weights = {
            cursed_application = 1,
            cursed_invocation  = 1,
            cursed_projection  = 1,
            cursed_controle    = 1,
        },
        nothingWeight = 0,        -- poids de "Rien" (0 = désactivé)
        nothingLabel  = "Rien",   -- libellé affiché dans le tooltip
        nothingColor  = Color(140, 140, 140),
    },
    ["heritage_branch"] = {
        weights = {
            heritage_hanami  = 1,
            heritage_jogo    = 1,
            heritage_itadori = 1,
            heritage_todo    = 1,
            heritage_yuta    = 1,
            heritage_finger  = 1,
        },
        nothingWeight = 0,
        nothingLabel  = "Rien",
        nothingColor  = Color(140, 140, 140),
    },
}

-- ─── Portails de classe ───────────────────────────────────────────────────────
-- Définit combien de "tiers" de nœuds chaque grade (job) débloque dans chaque
-- grande catégorie de l'arbre. Le tier d'un nœud = sa position dans la branche
-- (node_index : 1=Rang D, 2=Rang C, 3=Rang B, 4=Rang A).
--
-- Lecture : si un joueur est "classe_2", il peut acheter jusqu'au tier 3 dans
-- la catégorie "cursed" ET jusqu'au tier 3 dans la catégorie "martial".
-- ─────────────────────────────────────────────────────────────────────────────
ST.ClassGates = {
    --              cursed  martial  heritage
    -- Heritage : C4=tier1 | C3=tier2 | SC2=tier2 | C2=tier3 | SC1=tier4 | C1=tier4 | CS=tier4
    classe_4      = { cursed = 1, martial = 0, heritage = 1 },
    classe_3      = { cursed = 1, martial = 1, heritage = 2 },
    semi_classe_2 = { cursed = 2, martial = 2, heritage = 2 },
    classe_2      = { cursed = 3, martial = 3, heritage = 3 },
    semi_classe_1 = { cursed = 4, martial = 4, heritage = 4 },
    classe_1      = { cursed = 4, martial = 4, heritage = 4 },
    classe_s      = { cursed = 4, martial = 4, heritage = 4 },

    -- ─── Grades de clan : Gojo ───────────────────────────────────────────────
    -- Memes paliers cursed/martial que leurs equivalents, plus le palier clan.
    --   Classe 4 / Classe 3      : clan tier 1 (pas de nouveau palier a Classe 3)
    --   Semi-Classe 2 / Classe 2 : clan tiers 2 et 3
    --   Semi-Classe 1            : clan tier 3 (inchange)
    --   Classe 1 / Classe S      : clan tiers 4 et 5
    --  Bleu (D) @ C4 | Rouge (C) @ SC2 | Infinie (B) @ C2 | Violet (A) @ C1+CS
    classe_4_gojo      = { cursed = 1, martial = 0, clan = 1, heritage = 1 },
    classe_3_gojo      = { cursed = 1, martial = 1, clan = 1, heritage = 2 },
    semi_classe_2_gojo = { cursed = 2, martial = 2, clan = 2, heritage = 2 },
    classe_2_gojo      = { cursed = 3, martial = 3, clan = 3, heritage = 3 },
    semi_classe_1_gojo = { cursed = 4, martial = 4, clan = 3, heritage = 4 },
    classe_1_gojo      = { cursed = 4, martial = 4, clan = 4, heritage = 4 },
    classe_s_gojo      = { cursed = 4, martial = 4, clan = 4, heritage = 4 },

    -- ─── Grades de clan : Sukuna ─────────────────────────────────────────────
    --  Laceration (D) @ vermine | Effroi (C) @ corrupteur | Dismantle (B) @ executeur | Fuga (A) @ ravageur+calamite
    vermine_sukuna      = { cursed = 1, martial = 0, clan = 1, heritage = 1 },
    abomination_sukuna  = { cursed = 1, martial = 1, clan = 1, heritage = 2 },
    corrupteur_sukuna   = { cursed = 2, martial = 2, clan = 2, heritage = 2 },
    executeur_sukuna    = { cursed = 3, martial = 3, clan = 3, heritage = 3 },
    fossoyeur_sukuna    = { cursed = 4, martial = 4, clan = 3, heritage = 4 },
    ravageur_sukuna     = { cursed = 4, martial = 4, clan = 4, heritage = 4 },
    calamite_sukuna     = { cursed = 4, martial = 4, clan = 4, heritage = 4 },

    -- ─── Grades de clan : Mahito ─────────────────────────────────────────────
    --  Oursin (D) @ vermine | Complete (C) @ corrupteur | Vol d'Ame (B) @ executeur | Transfig. (A) @ ravageur+calamite
    vermine_mahito      = { cursed = 1, martial = 0, clan = 1, heritage = 1 },
    abomination_mahito  = { cursed = 1, martial = 1, clan = 1, heritage = 2 },
    corrupteur_mahito   = { cursed = 2, martial = 2, clan = 2, heritage = 2 },
    executeur_mahito    = { cursed = 3, martial = 3, clan = 3, heritage = 3 },
    fossoyeur_mahito    = { cursed = 4, martial = 4, clan = 3, heritage = 4 },
    ravageur_mahito     = { cursed = 4, martial = 4, clan = 4, heritage = 4 },
    calamite_mahito     = { cursed = 4, martial = 4, clan = 4, heritage = 4 },

    -- ─── Grades Fléaux génériques ─────────────────────────────────────────────
    -- Même paliers cursed/martial/heritage que leur équivalent exorciste :
    --   vermine      = classe_4     | abomination   = classe_3
    --   corrupteur   = semi_classe_2| executeur      = classe_2
    --   fossoyeur    = semi_classe_1| ravageur       = classe_1
    --   calamite     = classe_s     | prince_fleaux  = classe_s
    vermine      = { cursed = 1, martial = 0, heritage = 1 },
    abomination  = { cursed = 1, martial = 1, heritage = 2 },
    corrupteur   = { cursed = 2, martial = 2, heritage = 2 },
    executeur    = { cursed = 3, martial = 3, heritage = 3 },
    fossoyeur    = { cursed = 4, martial = 4, heritage = 4 },
    ravageur     = { cursed = 4, martial = 4, heritage = 4 },
    calamite     = { cursed = 4, martial = 4, heritage = 4 },
    prince_fleaux = { cursed = 4, martial = 4, heritage = 4 },
    directeur     = { cursed = 4, martial = 4, heritage = 4 },

    -- ─── Grades de clan Fléaux : Sukuna ──────────────────────────────────────
    prince_fleaux_sukuna = { cursed = 4, martial = 4, clan = 4, heritage = 4 },
    roi_fleaux_sukuna    = { cursed = 4, martial = 4, clan = 4, heritage = 4 },

    -- ─── Grades de clan Fléaux : Mahito ──────────────────────────────────────
    prince_fleaux_mahito = { cursed = 4, martial = 4, clan = 4, heritage = 4 },

    -- ─── Grades de clan : Zenin ──────────────────────────────────────────────
    --  Restriction (D) @ C4 | Projection (C) @ SC2 | Rapport (B) @ C2 | Dix Ombres (A) @ C1+CS
    classe_4_zenin      = { cursed = 1, martial = 0, clan = 1, heritage = 1 },
    classe_3_zenin      = { cursed = 1, martial = 1, clan = 1, heritage = 2 },
    semi_classe_2_zenin = { cursed = 2, martial = 2, clan = 2, heritage = 2 },
    classe_2_zenin      = { cursed = 3, martial = 3, clan = 3, heritage = 3 },
    semi_classe_1_zenin = { cursed = 4, martial = 4, clan = 3, heritage = 4 },
    classe_1_zenin      = { cursed = 4, martial = 4, clan = 4, heritage = 4 },
    classe_s_zenin      = { cursed = 4, martial = 4, clan = 4, heritage = 4 },
}

-- Associe l'id de catégorie d'arbre à la clé de portail correspondante.
-- Toute catégorie absente de cette table est considérée sans portail (accès libre).
local _categoryGateKey = {
    cursed_powers  = "cursed",
    voie_martiale  = "martial",
    technique_clan = "clan",      -- verrou : seuls les jobs de clan (ex: _gojo) y ont acces
    heritage       = "heritage",  -- verrou : accessible a tout job ayant le palier heritage (obtenu via reroll heritage)
}

-- Retourne la clé de portail ("cursed" ou "martial") pour une catégorie, ou nil.
function ST:GetGateKeyForCategory(categoryId)
    return _categoryGateKey[tostring(categoryId or "")]
end

-- Retourne le nombre maximum de tiers accessibles pour un grade donné dans une catégorie.
-- Retourne 999 si la catégorie n'est pas gérée par un portail (accès illimité).
-- Retourne 0 si le grade est inconnu (tout verrouillé).
function ST:GetClassGateTier(jobId, categoryId)
    local gate = istable(self.ClassGates) and self.ClassGates[tostring(jobId or "")] or nil
    if not gate then return 0 end
    local key = self:GetGateKeyForCategory(categoryId)
    if not key then return 999 end
    return tonumber(gate[key]) or 0
end

-- Retourne true si le nœud est verrouillé par le portail de classe du joueur.
-- Fonctionne côté serveur ET client (GetPublicString est disponible partout).
function ST:IsNodeLockedByClass(ply, nodeId)
    local node = self:GetNode(nodeId)
    if not node then return false end
    local key = self:GetGateKeyForCategory(tostring(node.category_id or ""))
    if not key then return false end  -- catégorie sans portail → libre
    -- Récupère le job du joueur (méthode directe ou via NW string)
    local jobId = ""
    if IsValid(ply) then
        if isfunction(ply.GetJobID) then jobId = tostring(ply:GetJobID() or "") end
        if jobId == "" and isfunction(ply.GetPublicString) then
            jobId = tostring(ply:GetPublicString("VERSE::JobID") or "")
        end
    end
    if jobId == "" then return true end  -- pas de grade → tout verrouillé
    local maxTier = self:GetClassGateTier(jobId, node.category_id)
    -- node_index = position du nœud dans la branche (1 à 4)
    return (node.node_index or 1) > maxTier
end

-- ─── Helpers clan ────────────────────────────────────────────────────────────
-- Correspondance suffixe de job → id du subtype clan dans l'arbre.
local _clanSuffixToSubtype = {
    gojo   = "clan_gojo",
    sukuna = "clan_sukuna",
    mahito = "clan_mahito",
    zenin  = "clan_zenin",
}

-- Retourne l'id du subtype clan (ex: "clan_gojo") depuis un job_id,
-- ou nil si le joueur n'appartient à aucun clan.
function ST:GetClanSubtypeIdForJob(jobId)
    jobId = tostring(jobId or "")
    if jobId == "" then return nil end
    for suffix, subtypeId in pairs(_clanSuffixToSubtype) do
        if string.EndsWith(jobId, "_" .. suffix) then
            return subtypeId
        end
    end
    return nil
end

-- Retourne l'id du subtype clan du joueur local/donné, ou nil.
-- Retourne l'ID du sous-type d'heritage assigné au joueur (côté client via ST.Client.branches),
-- ou nil s'il n'en a pas.
function ST:GetPlayerHeritageSubtypeId()
    local branches = istable(self.Client) and istable(self.Client.branches) and self.Client.branches or {}
    return branches["heritage_branch"] or nil
end

function ST:GetPlayerClanSubtypeId(ply)
    local jobId = ""
    if IsValid(ply) then
        if isfunction(ply.GetJobID) then
            jobId = tostring(ply:GetJobID() or "")
        end
        if jobId == "" and isfunction(ply.GetPublicString) then
            jobId = tostring(ply:GetPublicString("VERSE::JobID") or "")
        end
    end
    return self:GetClanSubtypeIdForJob(jobId)
end

-- Mapping subtype → arme TCS correspondante
ST.MartialWeaponMap = {
    martial_lance  = "lance",
    martial_katana = "katana",
    martial_fists  = "fists",
}

ST.Ranks = {
    { id = "grade_4",      label = "Grade 4",       points = 5  },
    { id = "grade_3",      label = "Grade 3",       points = 10 },
    { id = "grade_2",      label = "Grade 2",       points = 15 },
    { id = "grade_1",      label = "Grade 1",       points = 20 },
    { id = "semi_grade_1", label = "Semi-Grade 1",  points = 25 },
    { id = "special",      label = "Grade Special", points = 30 },
}

function ST:GetExclusiveGroupForSubtype(subtypeId)
    subtypeId = tostring(subtypeId or "")
    for _, group in ipairs(self.ExclusiveGroups or {}) do
        for _, sid in ipairs(group.subtypes or {}) do
            if sid == subtypeId then return group end
        end
    end
    return nil
end

function ST:GetRankData(rankId)
    rankId = tostring(rankId or "")
    for _, r in ipairs(self.Ranks or {}) do
        if tostring(r.id or "") == rankId then return r end
    end
    return nil
end

-- Retourne true si le groupe donné fait partie des groupes reroll-only.
function ST:IsRerollGroup(groupId)
    groupId = tostring(groupId or "")
    for _, rgId in ipairs(self.RerollGroups or {}) do
        if tostring(rgId) == groupId then return true end
    end
    return false
end

-- Retourne true si la branche n'est pas encore débloquée via reroll
-- (groupe reroll-only ET aucune branche assignée pour ce groupe).
function ST:IsSubtypeRerollLocked(subtypeId, meta)
    subtypeId = tostring(subtypeId or "")
    local group = self:GetExclusiveGroupForSubtype(subtypeId)
    if not group or not self:IsRerollGroup(group.id) then return false end
    local branches = meta and istable(meta.branches) and meta.branches or {}
    return tostring(branches[group.id] or "") == ""
end

-- Retourne le nombre de tickets reroll pouvoir maudit disponibles dans le meta.
function ST:GetCursedRerolls(meta)
    meta = istable(meta) and meta or {}
    return math.max(0, math.floor(tonumber(meta.cursed_rerolls) or 0))
end

function ST:IsSubtypeLockedByMeta(subtypeId, meta)
    subtypeId = tostring(subtypeId or "")
    -- Verrou reroll : branche non encore assignée via tirage
    if self:IsSubtypeRerollLocked(subtypeId, meta) then return true end
    -- Verrou exclusif : une autre branche du même groupe a été choisie
    local group = self:GetExclusiveGroupForSubtype(subtypeId)
    if not group then return false end
    local branches = meta and istable(meta.branches) and meta.branches or {}
    local chosen = tostring(branches[group.id] or "")
    if chosen == "" then return false end
    return chosen ~= subtypeId
end

ST._nodeMap = nil
ST._abilitySourceMap = nil
local _legacyCategoryFallback = {
    id = "_legacy",
    title = "Fallback",
    color = Color(120, 120, 120),
    subtypes = {
        {
            id = "_legacy_nodes",
            title = "Fallback Nodes",
            color = Color(120, 120, 120),
            description = "",
            nodes = {
                {
                    id = "fallback_node_1",
                    title = "Fallback Node 1",
                    description = "Fallback node for legacy data with basic stat bonuses.",
                    node_type = "stat",
                    maxRank = 3,
                    cost = 1,
                    stat_effects = {
                        Health = 0,
                    },
                },
            },
        },
    },
}

ST._legacyCategory = _legacyCategoryFallback
ST._nodeMap = nil
ST._abilitySourceMap = nil
function ST:GetCategory(categoryId)
    categoryId = tostring(categoryId or "")
    if categoryId == "" then return nil end
    for i = 1, #self.Tree do
        if self.Tree[i].id == categoryId then return self.Tree[i] end
    end
    return nil
end

function ST:GetCategoryForSubtype(subtypeId)
    subtypeId = tostring(subtypeId or "")
    for i = 1, #self.Tree do
        local subs = self.Tree[i].subtypes or {}
        for j = 1, #subs do
            if subs[j].id == subtypeId then return self.Tree[i], subs[j] end
        end
    end
    return nil, nil
end

function ST:IsEnabled()
    return self.Config.Enabled == true
end

function ST:GetTableName()
    return tostring((self.Config and self.Config.TableName) or "verse_skilltree_characters")
end

function ST:GetDefaultPoints()
    return math.max(0, math.floor(tonumber((self.Config and self.Config.DefaultPoints) or 0) or 0))
end

function ST:GetDefaultState()
    return {
        available_points = self:GetDefaultPoints(),
        spent_points = 0,
        nodes = {},
    }
end

function ST:GetBindSlotCount()
    return math.max(1, math.floor(tonumber((self.Config and self.Config.BindSlotCount) or 6) or 6))
end

function ST:GetPresetCount()
    return math.max(1, math.floor(tonumber((self.Config and self.Config.PresetCount) or 3) or 3))
end

function ST:GetDefaultLoadout()
    local slotCount = self:GetBindSlotCount()
    local presetCount = self:GetPresetCount()
    local presets = {}

    for presetIndex = 1, presetCount do
        local preset = {
            name = "Preset " .. tostring(presetIndex),
            slots = {},
        }

        for slotIndex = 1, slotCount do
            preset.slots[slotIndex] = ""
        end

        presets[presetIndex] = preset
    end

    return {
        active_preset = 1,
        presets = presets,
    }
end

ST.ExecutionHandlers = ST.ExecutionHandlers or {}

function ST:RegisterExecutionHandler(executionType, handlerData)
    executionType = tostring(executionType or "")
    if executionType == "" or not istable(handlerData) then return false end

    local merged = self.ExecutionHandlers[executionType] or {}
    for key, value in pairs(handlerData) do
        merged[key] = value
    end

    self.ExecutionHandlers[executionType] = merged
    return true
end

function ST:GetExecutionHandler(executionType)
    executionType = tostring(executionType or "")
    if executionType == "" then return nil end
    return self.ExecutionHandlers[executionType]
end

function ST:GetAbilityExecution(abilityId, abilityData)
    abilityId = tostring(abilityId or "")
    if abilityId == "" then return nil end

    abilityData = istable(abilityData) and abilityData or self:GetAbilityData(abilityId)
    local execution = istable(abilityData) and abilityData.execution or nil
    if not istable(execution) then return nil end

    local normalized = table.Copy(execution)
    normalized.type = tostring(normalized.type or "")
    if normalized.type == "" then return nil end
    return normalized
end

function ST:GetExecutionDisplayName(executionType)
    executionType = tostring(executionType or "")
    if executionType == "" then return "" end

    local handler = self:GetExecutionHandler(executionType)
    local label = handler and tostring(handler.label or "") or ""
    if label ~= "" then return label end

    executionType = executionType:gsub("_", " ")
    return executionType:gsub("^%l", string.upper)
end

function ST:IsExecutionBindable(execution, abilityId, abilityData)
    if not istable(execution) then return false end

    local handler = self:GetExecutionHandler(tostring(execution.type or ""))
    if not handler or not isfunction(handler.bindable) then return false end
    return handler.bindable(self, execution, tostring(abilityId or ""), abilityData) == true
end

ST:RegisterExecutionHandler("combat_buff", {
    label = "Technique active",
    bindable = function(_, execution)
        return tostring(execution.buff_profile or "") ~= ""
    end,
})

ST:RegisterExecutionHandler("hook", {
    label = "Action executee",
    bindable = function(_, execution)
        return tostring(execution.hook or execution.event or "") ~= ""
    end,
})

ST:RegisterExecutionHandler("tcs_spell", {
    label = "Technique occulte",
    bindable = function(_, execution)
        return tostring(execution.spell_id or "") ~= ""
    end,
})

function ST:GetCharacterUID(charOrPlayer)
    if not charOrPlayer then return nil end
    if IsValid(charOrPlayer) and charOrPlayer:IsPlayer() then
        local characters = VERSE and VERSE.Characters
        if characters and characters.GetSelectedCharID then return tonumber(characters:GetSelectedCharID(charOrPlayer)) or nil end
        return nil
    end

    if istable(charOrPlayer) then return tonumber(charOrPlayer.id) or tonumber(charOrPlayer.char_id) or tonumber(charOrPlayer.uid) or nil end
    return tonumber(charOrPlayer) or nil
end

function ST:GetNodeMap()
    if self._nodeMap then return self._nodeMap end
    local map = {}
    local function indexCategory(cat, catIndex)
        local subtypes = istable(cat) and cat.subtypes or nil
        if not istable(subtypes) then return end
        for stIndex = 1, #subtypes do
            local sub = subtypes[stIndex]
            local nodes = istable(sub) and sub.nodes or nil
            if istable(nodes) then
                for nodeIndex = 1, #nodes do
                    local node = nodes[nodeIndex]
                    if istable(node) and isstring(node.id) and node.id ~= "" and not map[node.id] then
                        local copy = table.Copy(node)
                        copy.category_id = cat.id
                        copy.category_title = cat.title
                        copy.category_icon = cat.icon
                        copy.category_color = cat.color
                        copy.subtype_id = sub.id
                        copy.subtype_title = sub.title
                        copy.subtype_icon = sub.icon
                        copy.subtype_color = sub.color
                        copy.category_index = catIndex
                        copy.subtype_index = stIndex
                        copy.node_index = nodeIndex
                        copy.maxRank = math.max(1, math.floor(tonumber(copy.maxRank) or 1))
                        copy.cost = math.max(1, math.floor(tonumber(copy.cost) or 1))
                        map[copy.id] = copy
                    end
                end
            end
        end
    end

    for catIndex = 1, #self.Tree do
        indexCategory(self.Tree[catIndex], catIndex)
    end

    if istable(self._legacyCategory) then indexCategory(self._legacyCategory, 0) end
    self._nodeMap = map
    return map
end

function ST:GetNode(nodeId)
    nodeId = tostring(nodeId or "")
    if nodeId == "" then return nil end
    return self:GetNodeMap()[nodeId]
end

function ST:NormalizeNodeRanks(raw)
    local out = {}
    local nodeMap = self:GetNodeMap()
    if not istable(raw) then return out end
    for nodeId, rank in pairs(raw) do
        local node = nodeMap[tostring(nodeId or "")]
        local safeRank = math.floor(tonumber(rank) or 0)
        if node and safeRank > 0 then out[node.id] = math.Clamp(safeRank, 0, node.maxRank) end
    end
    return out
end

function ST:NormalizeState(raw)
    local defaultState = self:GetDefaultState()
    raw = istable(raw) and raw or {}
    local availablePoints = math.max(0, math.floor(tonumber(raw.available_points) or defaultState.available_points))
    local spentPoints = math.max(0, math.floor(tonumber(raw.spent_points) or defaultState.spent_points))
    local nodes = self:NormalizeNodeRanks(raw.nodes)
    return {
        available_points = availablePoints,
        spent_points = spentPoints,
        nodes = nodes,
    }
end

function ST:IsAbilityBindable(abilityId, abilityData)
    abilityId = tostring(abilityId or "")
    if abilityId == "" then return false end

    abilityData = istable(abilityData) and abilityData or self:GetAbilityData(abilityId)
    if not istable(abilityData) then return false end
    if abilityData.bindable ~= nil then return abilityData.bindable == true end

    local execution = self:GetAbilityExecution(abilityId, abilityData)
    return self:IsExecutionBindable(execution, abilityId, abilityData)
end

function ST:GetAbilityDisplayName(abilityId)
    local abilityData = self:GetAbilityData(abilityId)
    local title = istable(abilityData) and tostring(abilityData.title or "") or ""
    if title ~= "" then return title end
    return tostring(abilityId or "")
end

function ST:GetAbilityDescription(abilityId)
    local abilityData = self:GetAbilityData(abilityId)
    return istable(abilityData) and tostring(abilityData.description or "") or ""
end

function ST:GetAbilityIcon(abilityId, fallbackValue)
    local abilityData = self:GetAbilityData(abilityId)
    local icon = istable(abilityData) and tostring(abilityData.icon or "") or ""
    if icon ~= "" then return icon end
    return fallbackValue
end

function ST:GetAvailableAbilitiesForState(rawState, bindableOnly)
    local state = self:NormalizeState(rawState)
    local unlocked = self:GetUnlockedAbilitiesForState(state)
    local abilities = {}

    for abilityId in pairs(unlocked) do
        local abilityData = self:GetAbilityData(abilityId) or {}
        local bindable = self:IsAbilityBindable(abilityId, abilityData)
        if not bindableOnly or bindable then
            abilities[#abilities + 1] = {
                id = abilityId,
                data = abilityData,
                bindable = bindable,
            }
        end
    end

    table.sort(abilities, function(a, b)
        if a.bindable ~= b.bindable then return a.bindable and not b.bindable end
        local aSort = tonumber(a.data and a.data.sort) or 1000
        local bSort = tonumber(b.data and b.data.sort) or 1000
        if aSort ~= bSort then return aSort < bSort end
        return self:GetAbilityDisplayName(a.id) < self:GetAbilityDisplayName(b.id)
    end)

    return abilities
end

function ST:NormalizeLoadout(raw, rawState)
    local defaultLoadout = self:GetDefaultLoadout()
    local normalized = {
        active_preset = 1,
        presets = {},
    }
    local slotCount = self:GetBindSlotCount()
    local presetCount = self:GetPresetCount()
    local unlocked = rawState ~= nil and self:GetUnlockedAbilitiesForState(rawState) or nil
    raw = istable(raw) and raw or {}
    normalized.active_preset = math.Clamp(math.floor(tonumber(raw.active_preset) or 1), 1, presetCount)

    for presetIndex = 1, presetCount do
        local sourcePreset = istable(raw.presets) and raw.presets[presetIndex] or nil
        local preset = {
            name = tostring((istable(sourcePreset) and sourcePreset.name) or defaultLoadout.presets[presetIndex].name or ("Preset " .. tostring(presetIndex))),
            slots = {},
        }

        for slotIndex = 1, slotCount do
            local abilityId = tostring((istable(sourcePreset) and istable(sourcePreset.slots) and sourcePreset.slots[slotIndex]) or "")
            if abilityId ~= "" then
                local abilityData = self:GetAbilityData(abilityId)
                local bindable = self:IsAbilityBindable(abilityId, abilityData)
                local isUnlocked = unlocked == nil or unlocked[abilityId] == true
                if bindable and isUnlocked then
                    preset.slots[slotIndex] = abilityId
                else
                    preset.slots[slotIndex] = ""
                end
            else
                preset.slots[slotIndex] = ""
            end
        end

        normalized.presets[presetIndex] = preset
    end

    return normalized
end

function ST:GetLoadoutPreset(rawLoadout, presetIndex)
    local loadout = self:NormalizeLoadout(rawLoadout)
    presetIndex = math.Clamp(math.floor(tonumber(presetIndex) or loadout.active_preset or 1), 1, self:GetPresetCount())
    return loadout.presets[presetIndex], presetIndex
end

function ST:GetLoadoutSlots(rawLoadout, presetIndex)
    local preset = self:GetLoadoutPreset(rawLoadout, presetIndex)
    return preset and preset.slots or {}
end

function ST:GetBoundAbilityId(rawLoadout, slotIndex, presetIndex)
    slotIndex = math.Clamp(math.floor(tonumber(slotIndex) or 0), 1, self:GetBindSlotCount())
    local slots = self:GetLoadoutSlots(rawLoadout, presetIndex)
    return tostring(slots[slotIndex] or "")
end

function ST:GetNodeRank(state, nodeId)
    state = self:NormalizeState(state)
    return tonumber(state.nodes[tostring(nodeId or "")]) or 0
end

function ST:CanUnlockNode(state, nodeId)
    local node = self:GetNode(nodeId)
    if not node then return false, "bad_node" end
    state = self:NormalizeState(state)
    local currentRank = self:GetNodeRank(state, node.id)
    if currentRank >= node.maxRank then return false, "max_rank" end
    local requirements = istable(node.requires) and node.requires or nil
    if requirements then
        for index = 1, #requirements do
            local requirement = requirements[index]
            local requirementId = tostring(requirement.id or "")
            local requiredRank = math.max(1, math.floor(tonumber(requirement.rank) or 1))
            if self:GetNodeRank(state, requirementId) < requiredRank then return false, "requirements" end
        end
    end

    local cost = math.max(1, math.floor(tonumber(node.cost) or 1))
    if (tonumber(state.available_points) or 0) < cost then return false, "not_enough_points" end
    return true
end

function ST:GetStatBonusesForState(rawState)
    local state = self:NormalizeState(rawState)
    local bonuses = {}
    for nodeId, rank in pairs(state.nodes or {}) do
        local node = self:GetNode(nodeId)
        local effects = node and (node.stat_effects or node.effects) or nil
        rank = math.max(0, math.floor(tonumber(rank) or 0))
        if node and istable(effects) and rank > 0 then
            for statKey, valuePerRank in pairs(effects) do
                valuePerRank = tonumber(valuePerRank)
                if valuePerRank then bonuses[statKey] = (bonuses[statKey] or 0) + (valuePerRank * rank) end
            end
        end
    end
    return bonuses
end

function ST:GetPassiveBuffsForState(rawState)
    local state = self:NormalizeState(rawState)
    local unlocked = {}
    for nodeId, rank in pairs(state.nodes or {}) do
        local node = self:GetNode(nodeId)
        local passives = node and node.passive_buffs or nil
        rank = math.max(0, math.floor(tonumber(rank) or 0))
        if node and istable(passives) and rank > 0 then
            for index = 1, #passives do
                local passiveId = tostring(passives[index] or "")
                if passiveId ~= "" then unlocked[passiveId] = true end
            end
        end
    end
    return unlocked
end

function ST:GetUnlockedAbilitiesForState(rawState)
    local state = self:NormalizeState(rawState)
    local unlocked = {}
    for nodeId, rank in pairs(state.nodes or {}) do
        local node = self:GetNode(nodeId)
        local abilities = node and node.abilities or nil
        rank = math.max(0, math.floor(tonumber(rank) or 0))
        if node and istable(abilities) and rank > 0 then
            for index = 1, #abilities do
                local abilityId = tostring(abilities[index] or "")
                if abilityId ~= "" then unlocked[abilityId] = true end
            end
        end
    end
    return unlocked
end

function ST:GetStatBonusesForPlayer(ply)
    local charId = self:GetCharacterUID(ply)
    if not charId then return {} end
    if SERVER then return self:GetStatBonusesForState(self._cache and self._cache[charId] or nil) end
    if self.Client and tonumber(self.Client.charId) == tonumber(charId) then return self:GetStatBonusesForState(self.Client.state) end
    return {}
end

function ST:GetPassiveBuffsForPlayer(ply)
    local charId = self:GetCharacterUID(ply)
    if not charId then return {} end
    if SERVER then return self:GetPassiveBuffsForState(self._cache and self._cache[charId] or nil) end
    if self.Client and tonumber(self.Client.charId) == tonumber(charId) then return self:GetPassiveBuffsForState(self.Client.state) end
    return {}
end

function ST:GetUnlockedAbilitiesForPlayer(ply)
    local charId = self:GetCharacterUID(ply)
    if not charId then return {} end
    if SERVER then return self:GetUnlockedAbilitiesForState(self._cache and self._cache[charId] or nil) end
    if self.Client and tonumber(self.Client.charId) == tonumber(charId) then return self:GetUnlockedAbilitiesForState(self.Client.state) end
    return {}
end

function ST:GetLoadoutForPlayer(ply)
    local charId = self:GetCharacterUID(ply)
    if not charId then return self:GetDefaultLoadout() end
    if SERVER then
        return self:NormalizeLoadout(self._loadoutCache and self._loadoutCache[charId] or nil, self._cache and self._cache[charId] or nil)
    end
    if self.Client and tonumber(self.Client.charId) == tonumber(charId) then
        return self:NormalizeLoadout(self.Client.loadout, self.Client.state)
    end
    return self:GetDefaultLoadout()
end

function ST:GetBoundAbilityForPlayer(ply, slotIndex, presetIndex)
    return self:GetBoundAbilityId(self:GetLoadoutForPlayer(ply), slotIndex, presetIndex)
end

function ST:HasPassiveBuff(ply, passiveId)
    passiveId = tostring(passiveId or "")
    if passiveId == "" then return false end
    return self:GetPassiveBuffsForPlayer(ply)[passiveId] == true
end

function ST:HasAbility(ply, abilityId)
    abilityId = tostring(abilityId or "")
    if abilityId == "" then return false end
    return self:GetUnlockedAbilitiesForPlayer(ply)[abilityId] == true
end

function ST:GetAbilityData(abilityId)
    abilityId = tostring(abilityId or "")
    if abilityId == "" then return nil end
    return self.Abilities and self.Abilities[abilityId] or nil
end

function ST:GetAbilityManaCost(abilityId, defaultValue)
    local abilityData = self:GetAbilityData(abilityId)
    if not istable(abilityData) then return tonumber(defaultValue) or 0 end
    local manaCost = tonumber(abilityData.mana_cost)
    if manaCost == nil then return tonumber(defaultValue) or 0 end
    return math.max(0, manaCost)
end

-- ─── Système d'équilibrage temps réel ────────────────────────────────────────
-- Permet aux superadmins de modifier cost / maxRank de chaque node sans redémarrer.
-- Les overrides sont stockés en mémoire dans ST.Balancing.Overrides et persistés
-- en base de données. Côté client, ils sont reçus via netstream et appliqués au
-- _nodeMap local pour que l'UI reflète immédiatement les nouvelles valeurs.

ST.Balancing = ST.Balancing or {}
ST.Balancing.Overrides = ST.Balancing.Overrides or {}   -- { [nodeId] = { cost=X, maxRank=Y } }
ST.Balancing.Net = {
    SetOverride  = "VERSE::SkillTree::Balancing::Set",
    ResetNode    = "VERSE::SkillTree::Balancing::ResetNode",
    ResetAll     = "VERSE::SkillTree::Balancing::ResetAll",
    SyncAll      = "VERSE::SkillTree::Balancing::SyncAll",
    OpenMenu     = "VERSE::SkillTree::Balancing::OpenMenu",
}

-- Applique les overrides en mémoire sur le _nodeMap.
-- Invalide le cache d'abord pour forcer sa reconstruction avec les valeurs de base,
-- puis injecte les overrides par-dessus (évite d'accumuler des overrides successifs).
function ST:ApplyBalancingOverrides()
    self._nodeMap = nil              -- invalide le cache
    local map = self:GetNodeMap()   -- reconstruit depuis ST.Tree (valeurs d'origine)
    for nodeId, ov in pairs(self.Balancing.Overrides) do
        local node = map[nodeId]
        if node then
            if ov.cost    ~= nil then node.cost    = math.max(1, math.floor(tonumber(ov.cost)    or 1)) end
            if ov.maxRank ~= nil then node.maxRank = math.max(1, math.floor(tonumber(ov.maxRank) or 1)) end
        end
    end
end

-- Retourne l'override actif pour un node donné (nil si aucun).
function ST:GetBalancingOverride(nodeId)
    return self.Balancing.Overrides[tostring(nodeId or "")]
end
