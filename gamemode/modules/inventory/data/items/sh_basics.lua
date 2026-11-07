local INV = VERSE.Inventory

INV:RegisterItem("health_potion", {
    name = "Health Potion",
    description = "Restores a small amount of health.",
    category = "consumable",
    rarity = "common",
    max_stack = 10,
    weight = 0.5,
    icon = "verse/inventory/items/fallback_icon.png",
    usable = true,
    droppable = true,
    tradeable = true,
    on_use = "heal",
})

INV:RegisterItem("cursed_scroll", {
    name = "Cursed Scroll",
    description = "A scroll imbued with cursed energy.",
    category = "resource",
    rarity = "rare",
    max_stack = 20,
    weight = 0.2,
    icon = "verse/inventory/items/fallback_icon.png",
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("cursed_blade", {
    name = "Cursed Blade",
    description = "A weapon infused with cursed energy. Deals additional damage.",
    category = "equipment",
    rarity = "epic",
    max_stack = 1,
    weight = 3.0,
    icon = "verse/inventory/items/fallback_icon.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        Damage = 12,
        MeleeDamage = 8,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("binding_ring", {
    name = "Binding Ring",
    description = "Enhances cursed energy control. +20 Mana, +2 ManaRegen, +50 Health.",
    category = "accessory",
    rarity = "uncommon",
    max_stack = 1,
    weight = 0.1,
    icon = "verse/inventory/items/fallback_icon.png",
    equip_slot = "Ring",
    equip_stats = {
        Health = 50,
        Mana = 20,
        ManaRegen = 2,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("cursed_talisman", {
    name = "Cursed Talisman",
    description = "A protective charm. +3 HealthRegen, +0.08 DamageReduction, +15 Armor.",
    category = "artifact",
    rarity = "rare",
    max_stack = 1,
    weight = 0.2,
    icon = "verse/inventory/items/fallback_icon.png",
    equip_slot = "Talisman",
    equip_stats = {
        HealthRegen = 3,
        DamageReduction = 0.08,
        Armor = 15,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("jujutsu_uniform", {
    name = "Jujutsu High Uniform",
    description = "The standard uniform of Tokyo Jujutsu High. +20 Armor, +10 Health.",
    category = "outfit",
    rarity = "uncommon",
    max_stack = 1,
    weight = 1.0,
    icon = "verse/inventory/items/fallback_icon.png",
    equip_slot = "Outfit",
    equip_model = "models/slayde_jjk/tenues/choso.mdl",
    equip_stats = {
        Armor = 20,
        Health = 10,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("sukuna_finger", {
    name = "Sukuna's Finger",
    description = "One of the twenty indestructible cursed objects. Radiates immense cursed energy.",
    category = "resource",
    rarity = "cursed",
    max_stack = 5,
    weight = 0.3,
    icon = "verse/inventory/items/fallback_icon.png",
    usable = false,
    droppable = false,
    tradeable = false,
})
