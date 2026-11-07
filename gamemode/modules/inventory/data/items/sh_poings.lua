local INV = VERSE.Inventory

INV:RegisterItem("poings_common", {
    name = "Poings Communs",
    description = "57 Physique.",
    category = "equipment",
    rarity = "common",
    max_stack = 1,
    weight = 0.5,
    icon = "verse/inventory/items/item_poings/1.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 57,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("poings_rare", {
    name = "Poings Rares",
    description = "63 Physique, +50 HP.",
    category = "equipment",
    rarity = "rare",
    max_stack = 1,
    weight = 0.5,
    icon = "verse/inventory/items/item_poings/2.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 63,
        Health = 50,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("poings_epic", {
    name = "Poings Épiques",
    description = "69 Physique, +100 HP, +5% Attack Speed.",
    category = "equipment",
    rarity = "epic",
    max_stack = 1,
    weight = 0.5,
    icon = "verse/inventory/items/item_poings/3.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 69,
        Health = 100,
        AttackSpeed = 0.05,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("poings_legendary", {
    name = "Poings Légendaires",
    description = "75 Physique, +150 HP, +10% Attack Speed.",
    category = "equipment",
    rarity = "legendary",
    max_stack = 1,
    weight = 0.5,
    icon = "verse/inventory/items/item_poings/4.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 75,
        Health = 150,
        AttackSpeed = 0.10,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("poings_cursed", {
    name = "Poings Maudits",
    description = "90 Physique, +200 HP, +15% Attack Speed, Coup Spécial.",
    category = "equipment",
    rarity = "cursed",
    max_stack = 1,
    weight = 0.5,
    icon = "verse/inventory/items/item_poings/5.png",
    equip_slot = "Weapon",
    equip_swep = "weapon_crowbar",
    equip_stats = {
        MeleeDamage = 90,
        Health = 200,
        AttackSpeed = 0.15,
    },
    has_special_attack = true,
    usable = false,
    droppable = true,
    tradeable = true,
})
