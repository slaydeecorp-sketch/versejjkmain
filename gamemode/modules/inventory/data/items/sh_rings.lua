local INV = VERSE.Inventory

INV:RegisterItem("bague_common", {
    name = "Bague Commune",
    description = "+5% Dégât Occulte, +50 PT Occulte.",
    category = "accessory",
    rarity = "common",
    max_stack = 1,
    weight = 0.1,
    icon = "verse/inventory/items/item_bague/1.png",
    equip_slot = "Ring",
    equip_stats = {
        AbilityPower = 5,
        Mana = 50,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("bague_rare", {
    name = "Bague Rare",
    description = "+7.5% Dégât Occulte, +100 PT Occulte, +100 HP.",
    category = "accessory",
    rarity = "rare",
    max_stack = 1,
    weight = 0.1,
    icon = "verse/inventory/items/item_bague/2.png",
    equip_slot = "Ring",
    equip_stats = {
        AbilityPower = 7.5,
        Mana = 100,
        Health = 100,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("bague_epic", {
    name = "Bague Épique",
    description = "+10% Dégât Occulte, +200 PT Occulte, +200 HP, 15% CDR.",
    category = "accessory",
    rarity = "epic",
    max_stack = 1,
    weight = 0.1,
    icon = "verse/inventory/items/item_bague/3.png",
    equip_slot = "Ring",
    equip_stats = {
        AbilityPower = 10,
        Mana = 200,
        Health = 200,
        CooldownReduction = 0.15,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})

INV:RegisterItem("bague_legendary", {
    name = "Bague Légendaire",
    description = "+15% Dégât Occulte, +400 PT Occulte, +350 HP, 20% CDR, +10% Move Speed.",
    category = "accessory",
    rarity = "legendary",
    max_stack = 1,
    weight = 0.1,
    icon = "verse/inventory/items/item_bague/4.png",
    equip_slot = "Ring",
    equip_stats = {
        AbilityPower = 15,
        Mana = 400,
        Health = 350,
        CooldownReduction = 0.20,
        WalkSpeed = 20,
        RunSpeed = 40,
    },
    usable = false,
    droppable = true,
    tradeable = true,
})
