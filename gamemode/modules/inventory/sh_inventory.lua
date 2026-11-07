VERSE.Inventory = VERSE.Inventory or {}
local INV = VERSE.Inventory
INV.Config = {
    Enabled = true,
    TableName = "verse_inventory",
    SlotCount = 48,
    MaxStackDefault = 64,
    MaxWeight = 0,
    DropEnabled = true,
    TransferEnabled = true,
    TransferMaxDistance = 200,
    StartingMoney = 500,
}

INV.Net = {
    Request = "VERSE::Inventory::Request",
    Sync = "VERSE::Inventory::Sync",
    Error = "VERSE::Inventory::Error",
    Move = "VERSE::Inventory::Move",
    Stack = "VERSE::Inventory::Stack",
    Split = "VERSE::Inventory::Split",
    Use = "VERSE::Inventory::Use",
    Drop = "VERSE::Inventory::Drop",
    Transfer = "VERSE::Inventory::Transfer",
    Equip = "VERSE::Inventory::Equip",
    Unequip = "VERSE::Inventory::Unequip",
    Sort = "VERSE::Inventory::Sort",
    Delete = "VERSE::Inventory::Delete",
    AdminView = "VERSE::Inventory::AdminView",
    AdminSync = "VERSE::Inventory::AdminSync",
    AdminGive = "VERSE::Inventory::AdminGive",
    AdminRemove = "VERSE::Inventory::AdminRemove",
}

INV.EquipSlots = {
    Weapon = 101,
    Ring = 102,
    Talisman = 103,
    Outfit = 104,
}

INV.EquipSlotNames = {
    [101] = "Weapon",
    [102] = "Ring",
    [103] = "Talisman",
    [104] = "Outfit",
}

INV.EquipSlotIcons = {
    [101] = "inv_slot_weapon",
    [102] = "inv_slot_ring",
    [103] = "inv_slot_talisman",
    [104] = "inv_slot_outfit",
}

INV.Rarities = {
    common = {
        color = Color(180, 180, 180),
        order = 1
    },
    uncommon = {
        color = Color(30, 255, 100),
        order = 2
    },
    rare = {
        color = Color(50, 150, 255),
        order = 3
    },
    epic = {
        color = Color(180, 50, 255),
        order = 4
    },
    legendary = {
        color = Color(255, 180, 30),
        order = 5
    },
    cursed = {
        color = Color(255, 30, 60),
        order = 6
    },
}

INV.Categories = {
    {
        id = "all",
        name = "Tout"
    },
    {
        id = "equipment",
        name = "Équipement"
    },
    {
        id = "artifact",
        name = "Artefact"
    },
    {
        id = "consumable",
        name = "Consommable"
    },
    {
        id = "resource",
        name = "Ressource"
    },
    {
        id = "outfit",
        name = "Tenue"
    },
    {
        id = "accessory",
        name = "Accessoire"
    },
    {
        id = "currency",
        name = "Monnaie"
    },
}

INV.Items = INV.Items or {}
INV.UseHandlers = INV.UseHandlers or {}
function INV:RegisterItem(itemId, def)
    itemId = tostring(itemId or "")
    if itemId == "" or not istable(def) then return false end
    self.Items[itemId] = table.Copy(def)
    return true
end

function INV:GetItemDef(itemId)
    itemId = tostring(itemId or "")
    if itemId == "" then return nil end
    return self.Items[itemId]
end

function INV:GetItemName(itemId)
    local def = self:GetItemDef(itemId)
    return istable(def) and tostring(def.name or itemId) or tostring(itemId)
end

function INV:GetMaxStack(itemId)
    local def = self:GetItemDef(itemId)
    local ms = istable(def) and tonumber(def.max_stack) or nil
    if ms == 0 or ms == math.huge then return math.huge end
    if ms and ms >= 1 then return math.floor(ms) end
    return self.Config.MaxStackDefault
end

function INV:IsInfiniteStack(itemId)
    return self:GetMaxStack(itemId) == math.huge
end

function INV:GetItemWeight(itemId)
    local def = self:GetItemDef(itemId)
    return istable(def) and tonumber(def.weight) or 0
end

function INV:IsEnabled()
    return self.Config.Enabled == true
end

function INV:IsEquipSlot(slot)
    slot = tonumber(slot) or 0
    return self.EquipSlotNames[slot] ~= nil
end

function INV:GetEquipSlotName(slot)
    return self.EquipSlotNames[tonumber(slot) or 0]
end

function INV:CanEquipToSlot(itemId, equipSlot)
    local def = self:GetItemDef(itemId)
    if not def or not def.equip_slot then return false end
    return def.equip_slot == equipSlot or def.equip_slot == self:GetEquipSlotName(equipSlot)
end

function INV:GetRarityDef(rarity)
    return self.Rarities[tostring(rarity or "common")] or self.Rarities.common
end

function INV:GetRarityColor(rarity)
    local def = self:GetRarityDef(rarity)
    return def and def.color or self.Rarities.common.color
end

function INV:GetItemRarity(itemId)
    local def = self:GetItemDef(itemId)
    return istable(def) and tostring(def.rarity or "common") or "common"
end

function INV:GetSlotCount()
    return math.max(1, math.floor(tonumber(self.Config.SlotCount) or 30))
end

function INV:GetTableName()
    return tostring((self.Config and self.Config.TableName) or "verse_inventory")
end

function INV:GetCharacterUID(plyOrCharId)
    if not plyOrCharId then return nil end
    if IsValid(plyOrCharId) and plyOrCharId:IsPlayer() then
        local CH = VERSE and VERSE.Characters
        if CH and CH.GetSelectedCharID then return tonumber(CH:GetSelectedCharID(plyOrCharId)) or nil end
        return nil
    end

    if istable(plyOrCharId) then return tonumber(plyOrCharId.id) or tonumber(plyOrCharId.char_id) or nil end
    return tonumber(plyOrCharId) or nil
end

function INV:NormalizeSlotData(raw)
    if not istable(raw) then return nil end
    local itemId = tostring(raw.item_id or "")
    if itemId == "" then return nil end
    if not self:GetItemDef(itemId) then return nil end
    local maxStack = self:GetMaxStack(itemId)
    local amount = math.Clamp(math.floor(tonumber(raw.amount) or 1), 1, maxStack)
    local metadata = istable(raw.metadata) and table.Copy(raw.metadata) or nil
    return {
        item_id = itemId,
        amount = amount,
        metadata = metadata
    }
end

function INV:NormalizeInventory(raw)
    local out = {}
    if not istable(raw) then return out end
    local slotCount = self:GetSlotCount()
    for slot = 1, slotCount do
        local data = raw[slot]
        if istable(data) then out[slot] = self:NormalizeSlotData(data) end
    end

    for eqSlot, _ in pairs(self.EquipSlotNames) do
        local data = raw[eqSlot]
        if istable(data) then out[eqSlot] = self:NormalizeSlotData(data) end
    end
    return out
end

function INV:MetadataMatch(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    return util.TableToJSON(a) == util.TableToJSON(b)
end

function INV:RegisterUseHandler(handlerName, fn)
    handlerName = tostring(handlerName or "")
    if handlerName == "" or not isfunction(fn) then return false end
    self.UseHandlers[handlerName] = fn
    return true
end

function INV:GetUseHandler(handlerName)
    handlerName = tostring(handlerName or "")
    if handlerName == "" then return nil end
    return self.UseHandlers[handlerName]
end

INV.CurrencyItemID = "money"