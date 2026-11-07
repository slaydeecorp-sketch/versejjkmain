local INV = VERSE.Inventory
if not INV then return end
INV.Client = INV.Client or {
    charId = 0,
    slots = {},
    equipment = {},
    lastError = nil,
}

local function splitSyncData(inventory)
    local slots = {}
    local equipment = {}
    local slotCount = INV:GetSlotCount()
    for k, v in pairs(inventory) do
        local slot = tonumber(k)
        if slot and slot >= 1 and slot <= slotCount then
            slots[slot] = v
        elseif slot and INV:IsEquipSlot(slot) then
            equipment[slot] = v
        end
    end
    return slots, equipment
end

netstream.Hook(INV.Net.Sync, function(charId, inventory)
    INV.Client.charId = tonumber(charId) or 0
    local normalized = INV:NormalizeInventory(inventory)
    INV.Client.slots, INV.Client.equipment = splitSyncData(normalized)
    INV.Client.lastError = nil
    hook.Run("VERSE::Inventory::Updated")
end)

netstream.Hook(INV.Net.Error, function(code)
    INV.Client.lastError = tostring(code or "unknown")
    hook.Run("VERSE::Inventory::Error", INV.Client.lastError)
end)

function INV:RequestSync()
    netstream.Start(self.Net.Request)
end

function INV:RequestMove(fromSlot, toSlot)
    netstream.Start(self.Net.Move, tonumber(fromSlot), tonumber(toSlot))
end

function INV:RequestStack(fromSlot, toSlot)
    netstream.Start(self.Net.Stack, tonumber(fromSlot), tonumber(toSlot))
end

function INV:RequestSplit(fromSlot, splitAmount, targetSlot)
    netstream.Start(self.Net.Split, tonumber(fromSlot), tonumber(splitAmount), tonumber(targetSlot) or nil)
end

function INV:RequestUse(slot)
    netstream.Start(self.Net.Use, tonumber(slot))
end

function INV:RequestDrop(slot, amount)
    netstream.Start(self.Net.Drop, tonumber(slot), tonumber(amount) or 1)
end

function INV:RequestTransfer(targetSteamID64, fromSlot, amount)
    netstream.Start(self.Net.Transfer, tostring(targetSteamID64), tonumber(fromSlot), tonumber(amount) or 1)
end

function INV:RequestEquip(fromSlot, equipSlot)
    netstream.Start(self.Net.Equip, tonumber(fromSlot), tonumber(equipSlot))
end

function INV:RequestUnequip(equipSlot)
    netstream.Start(self.Net.Unequip, tonumber(equipSlot))
end

function INV:RequestSort()
    netstream.Start(self.Net.Sort)
end

function INV:RequestDelete(slot, amount)
    netstream.Start(self.Net.Delete, tonumber(slot), tonumber(amount) or nil)
end

function INV:GetClientSlot(slot)
    slot = tonumber(slot)
    if self:IsEquipSlot(slot) then return self.Client.equipment[slot] end
    return self.Client.slots[slot]
end

function INV:GetClientInventory()
    return table.Copy(self.Client.slots)
end

function INV:GetClientEquipment()
    return table.Copy(self.Client.equipment)
end

function INV:GetEquippedItem(equipSlot)
    return self.Client.equipment[tonumber(equipSlot)]
end

function INV:GetClientItemCount(itemId)
    local total = 0
    for _, data in pairs(self.Client.slots) do
        if data and data.item_id == itemId then total = total + data.amount end
    end
    return total
end

function INV:GetClientMoney()
    return self:GetClientItemCount(self.CurrencyItemID)
end

function INV:GetFilledSlotCount()
    local count = 0
    for slot = 1, self:GetSlotCount() do
        if self.Client.slots[slot] then count = count + 1 end
    end
    return count
end

function INV:FindClientEmptySlot()
    for slot = 1, self:GetSlotCount() do
        if not self.Client.slots[slot] then return slot end
    end
    return nil
end

VERSE.Hook.AddNS("Inventory", "VERSE::Characters::ClientSelected", "VERSE::Inventory::SelectedChanged", function(selected)
    if selected then
        INV:RequestSync()
    else
        INV.Client.charId = 0
        INV.Client.slots = {}
        INV.Client.equipment = {}
        hook.Run("VERSE::Inventory::Updated")
    end
end)