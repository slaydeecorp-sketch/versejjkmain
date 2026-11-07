local INV = VERSE.Inventory

INV:RegisterItem("lance_common", {
    name = "Lance Commune",
    description = "45 Physique.",
    category = "equipment",
    rarity = "common",
    max_stack = 1,
    weight = 3.0,
    icon = "verse/inventory/items/item_lance/1.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 45,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("lance_rare", {
    name = "Lance Rare",
    description = "50 Physique, +100 HP.",
    category = "equipment",
    rarity = "rare",
    max_stack = 1,
    weight = 3.0,
    icon = "verse/inventory/items/item_lance/2.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 50,
        Health = 100,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("lance_epic", {
    name = "Lance Épique",
    description = "55 Physique, +200 HP, +5% Résistance.",
    category = "equipment",
    rarity = "epic",
    max_stack = 1,
    weight = 3.0,
    icon = "verse/inventory/items/item_lance/3.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 55,
        Health = 200,
        DamageReduction = 0.05,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("lance_legendary", {
    name = "Lance Légendaire",
    description = "60 Physique, +300 HP, +10% Résistance.",
    category = "equipment",
    rarity = "legendary",
    max_stack = 1,
    weight = 3.0,
    icon = "verse/inventory/items/item_lance/4.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 60,
        Health = 300,
        DamageReduction = 0.10,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("lance_cursed", {
    name = "Lance Maudite",
    description = "75 Physique, +400 HP, +15% Résistance, Coup Spécial.",
    category = "equipment",
    rarity = "cursed",
    max_stack = 1,
    weight = 3.0,
    icon = "verse/inventory/items/item_lance/5.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 75,
        Health = 400,
        DamageReduction = 0.15,
    },
    has_special_attack = true,
    usable = false,
    droppable = true,
    tradeable = true,
})
