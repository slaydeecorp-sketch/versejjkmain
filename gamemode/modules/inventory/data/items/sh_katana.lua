local INV = VERSE.Inventory

INV:RegisterItem("katana_common", {
    name = "Katana Commun",
    description = "51 Physique.",
    category = "equipment",
    rarity = "common",
    max_stack = 1,
    weight = 2.5,
    icon = "verse/inventory/items/item_epee/1.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 51,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("katana_rare", {
    name = "Katana Rare",
    description = "56 Physique, +75 HP.",
    category = "equipment",
    rarity = "rare",
    max_stack = 1,
    weight = 2.5,
    icon = "verse/inventory/items/item_epee/2.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 56,
        Health = 75,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("katana_epic", {
    name = "Katana Épique",
    description = "61 Physique, +150 HP, +3% Résistance.",
    category = "equipment",
    rarity = "epic",
    max_stack = 1,
    weight = 2.5,
    icon = "verse/inventory/items/item_epee/3.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 61,
        Health = 150,
        DamageReduction = 0.03,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("katana_legendary", {
    name = "Katana Légendaire",
    description = "66 Physique, +225 HP, +6% Résistance, +5% Attack Speed.",
    category = "equipment",
    rarity = "legendary",
    max_stack = 1,
    weight = 2.5,
    icon = "verse/inventory/items/item_epee/4.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 66,
        Health = 225,
        DamageReduction = 0.06,
        AttackSpeed = 0.05,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("katana_cursed", {
    name = "Katana Maudit",
    description = "82 Physique, +300 HP, +10% Résistance, +7.5% Attack Speed, Coup Spécial.",
    category = "equipment",
    rarity = "cursed",
    max_stack = 1,
    weight = 2.5,
    icon = "verse/inventory/items/item_epee/5.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 82,
        Health = 300,
        DamageReduction = 0.10,
        AttackSpeed = 0.075,
    },
    has_special_attack = true,
    usable = false,
    droppable = true,
    tradeable = true,
})
