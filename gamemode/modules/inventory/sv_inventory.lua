local INV = VERSE.Inventory
local DB = VERSE.DB
if not INV then return end
INV._cache = INV._cache or {}
INV._busy  = INV._busy  or {}

-- ─── Rate limiting par joueur ─────────────────────────────────────────────────
-- Empêche le spam d'actions réseau (ex: Sort → 48 writes par appel)
INV._actionCooldowns = INV._actionCooldowns or {}
local ACTION_COOLDOWNS = {
    sort     = 2.0, -- Sort est lourd (jusqu'à 48 DB writes)
    drop     = 1.0,
    use      = 0.5,
    transfer = 1.0,
    split    = 0.3,
    move     = 0.3,
    stack    = 0.3,
    equip    = 0.3,
    unequip  = 0.3,
    delete   = 0.3,
}

local function checkCooldown(ply, action)
    if not IsValid(ply) then return false end
    local sid = ply:SteamID()
    INV._actionCooldowns[sid] = INV._actionCooldowns[sid] or {}
    local cd = ACTION_COOLDOWNS[action] or 0.3
    local last = INV._actionCooldowns[sid][action] or 0
    if CurTime() - last < cd then return false end
    INV._actionCooldowns[sid][action] = CurTime()
    return true
end

hook.Add("PlayerDisconnected", "VERSE::Inventory::CooldownCleanup", function(ply)
    INV._actionCooldowns[ply:SteamID()] = nil
end)

local function invAcquire(charId, key)
    local k = tostring(charId) .. "_" .. tostring(key)
    if INV._busy[k] then return false end
    INV._busy[k] = true
    return true
end

local function invRelease(charId, key)
    INV._busy[tostring(charId) .. "_" .. tostring(key)] = nil
end
local function esc(v)
    return DB:Escape(v)
end

local function nowSQL()
    return os.time()
end

local function cloneInventory(inv)
    return table.Copy(INV:NormalizeInventory(inv))
end

local function encodeMetadata(meta)
    if not istable(meta) or next(meta) == nil then return "NULL" end
    return esc(util.TableToJSON(meta, false) or "{}")
end

local function decodeMetadata(raw)
    if not isstring(raw) or raw == "" or raw == "NULL" then return nil end
    return util.JSONToTable(raw)
end

local ERROR_MESSAGES = {
    no_character = "No character selected.",
    invalid_item = "Unknown item.",
    invalid_slot = "Invalid inventory slot.",
    slot_occupied = "That slot is already occupied.",
    slot_empty = "That slot is empty.",
    inventory_full = "Inventory is full.",
    not_enough = "Not enough of that item.",
    stack_full = "Stack is already full.",
    not_stackable = "These items cannot be stacked together.",
    not_usable = "This item cannot be used.",
    not_droppable = "This item cannot be dropped.",
    not_tradeable = "This item cannot be traded.",
    target_invalid = "Invalid target player.",
    target_too_far = "Target player is too far away.",
    target_full = "Target player's inventory is full.",
    bad_amount = "Invalid amount.",
    db_error = "A database error occurred.",
    cannot_equip = "This item cannot be equipped in that slot.",
    wrong_gender = "Cette tenue n'est pas du bon sexe pour ce personnage.",
}

local PLAYER = FindMetaTable("Player")
function INV:CreateTables()
    local t = self:GetTableName()
    local query
    if DB:IsMySQL() then
        query = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT NOT NULL AUTO_INCREMENT,
                char_id INT NOT NULL,
                slot INT NOT NULL,
                item_id VARCHAR(64) NOT NULL,
                amount INT NOT NULL DEFAULT 1,
                metadata TEXT NULL,
                created_at INT NOT NULL,
                updated_at INT NOT NULL,
                PRIMARY KEY (id),
                UNIQUE KEY uq_char_slot (char_id, slot),
                KEY idx_char_id (char_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(t)
    else
        query = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                char_id INTEGER NOT NULL,
                slot INTEGER NOT NULL,
                item_id TEXT NOT NULL,
                amount INTEGER NOT NULL DEFAULT 1,
                metadata TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                UNIQUE(char_id, slot)
            )
        ]]):format(t)
    end

    DB:Query(query, function() end, function(err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[Inventory] create table failed: " .. tostring(err)) end
        return true
    end)
end

function INV:LoadInventory(charId, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(false, "no_character") end
        return
    end

    local cached = self._cache[charId]
    if cached then
        if callback then callback(true, cloneInventory(cached)) end
        return
    end

    local query = ("SELECT slot, item_id, amount, metadata FROM %s WHERE char_id=%d"):format(self:GetTableName(), charId)
    DB:Query(query):Next(function(result)
        local rows = result.rows or {}
        local inv = {}
        for _, row in ipairs(rows) do
            local slot = tonumber(row.slot)
            local isNormalSlot = slot and slot >= 1 and slot <= self:GetSlotCount()
            local isEquipSlot = slot and self:IsEquipSlot(slot)
            if isNormalSlot or isEquipSlot then
                inv[slot] = self:NormalizeSlotData({
                    item_id = row.item_id,
                    amount = row.amount,
                    metadata = decodeMetadata(row.metadata),
                })
            end
        end

        local orphaned = {}
        for slot, data in pairs(inv) do
            if not self:GetItemDef(data.item_id) then
                table.insert(orphaned, slot)
            end
        end

        if #orphaned > 0 then
            for _, slot in ipairs(orphaned) do
                inv[slot] = nil
                self:SaveSlot(charId, slot, nil)
            end

            if VERSE.Log and VERSE.Log.Warn then
                VERSE.Log:Warn("[Inventory] Removed " .. #orphaned .. " orphaned item(s) for char " .. charId)
            end
        end

        self._cache[charId] = inv
        if callback then callback(true, cloneInventory(inv)) end
    end):Catch(function(err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[Inventory] load failed: " .. tostring(err)) end
        if callback then callback(false, "db_error") end
    end)
end

function INV:SaveSlot(charId, slot, slotData, callback)
    charId = tonumber(charId)
    slot = tonumber(slot)
    if not charId or not slot then
        if callback then callback(false) end
        return
    end

    local t = self:GetTableName()
    local query
    if not slotData then
        query = ("DELETE FROM %s WHERE char_id=%d AND slot=%d"):format(t, charId, slot)
    else
        local now = nowSQL()
        local metaStr = encodeMetadata(slotData.metadata)
        if DB:IsMySQL() then
            query = ([[
                INSERT INTO %s (char_id, slot, item_id, amount, metadata, created_at, updated_at)
                VALUES (%d, %d, %s, %d, %s, %d, %d)
                ON DUPLICATE KEY UPDATE
                    item_id = VALUES(item_id),
                    amount = VALUES(amount),
                    metadata = VALUES(metadata),
                    updated_at = VALUES(updated_at)
            ]]):format(t, charId, slot, esc(slotData.item_id), slotData.amount, metaStr, now, now)
        else
            query = ([[
                INSERT OR REPLACE INTO %s (char_id, slot, item_id, amount, metadata, created_at, updated_at)
                VALUES (%d, %d, %s, %d, %s,
                    COALESCE((SELECT created_at FROM %s WHERE char_id=%d AND slot=%d), %d),
                    %d)
            ]]):format(t, charId, slot, esc(slotData.item_id), slotData.amount, metaStr, t, charId, slot, now, now)
        end
    end

    DB:Query(query, function() if callback then callback(true) end end, function(err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[Inventory] save slot failed: " .. tostring(err)) end
        if callback then callback(false) end
        return true
    end)
end

function INV:DeleteInventory(charId)
    charId = tonumber(charId)
    if not charId or charId <= 0 then return end
    self._cache[charId] = nil
    local query = ("DELETE FROM %s WHERE char_id=%d"):format(self:GetTableName(), charId)
    DB:Query(query, function() end, function(err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[Inventory] delete failed: " .. tostring(err)) end
        return true
    end)
end

function INV:FindFirstEmptySlot(charId)
    local inv = self._cache[charId] or {}
    local slotCount = self:GetSlotCount()
    local occupied = 0
    for slot = 1, slotCount do
        local data = inv[slot]
        if not data then return slot end
        if not self:GetItemDef(data.item_id) then
            inv[slot] = nil
            self:SaveSlot(charId, slot, nil)
            return slot
        end
        occupied = occupied + 1
    end
    return nil
end

function INV:FindStackableSlot(charId, itemId, metadata)
    local inv = self._cache[charId] or {}
    local maxStack = self:GetMaxStack(itemId)
    if maxStack <= 1 then return nil end
    for slot = 1, self:GetSlotCount() do
        local data = inv[slot]
        if data and data.item_id == itemId and data.amount < maxStack and self:MetadataMatch(data.metadata, metadata) then return slot, data end
    end
    return nil
end

function INV:AddItem(charId, itemId, amount, metadata, callback)
    charId = tonumber(charId)
    itemId = tostring(itemId or "")
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if not charId or charId <= 0 then
        if callback then callback(false, "no_character") end
        return
    end

    local def = self:GetItemDef(itemId)
    if not def then
        if callback then callback(false, "invalid_item") end
        return
    end

    self:LoadInventory(charId, function(ok, _)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local remaining = amount
        local maxStack = self:GetMaxStack(itemId)
        local slotsToSave = {}
        if maxStack > 1 then
            for slot = 1, self:GetSlotCount() do
                if remaining <= 0 then break end
                local data = self._cache[charId][slot]
                if data and data.item_id == itemId and data.amount < maxStack and self:MetadataMatch(data.metadata, metadata) then
                    local canAdd = math.min(remaining, maxStack - data.amount)
                    data.amount = data.amount + canAdd
                    remaining = remaining - canAdd
                    slotsToSave[slot] = data
                end
            end
        end

        while remaining > 0 do
            local emptySlot = self:FindFirstEmptySlot(charId)
            if not emptySlot then break end
            local toPlace = math.min(remaining, maxStack)
            local newData = {
                item_id = itemId,
                amount = toPlace,
                metadata = metadata and table.Copy(metadata) or nil,
            }

            self._cache[charId][emptySlot] = newData
            slotsToSave[emptySlot] = newData
            remaining = remaining - toPlace
        end

        if next(slotsToSave) == nil then
            if callback then callback(false, "inventory_full") end
            return
        end

        local saveCount = table.Count(slotsToSave)
        local savedCount = 0
        local hadError = false
        for slot, slotData in pairs(slotsToSave) do
            self:SaveSlot(charId, slot, slotData, function(savedOk)
                savedCount = savedCount + 1
                if not savedOk then hadError = true end
                if savedCount >= saveCount then
                    if remaining > 0 then
                        if callback then callback(false, "inventory_full") end
                    elseif hadError then
                        if callback then callback(false, "db_error") end
                    else
                        if callback then callback(true) end
                    end
                end
            end)
        end
    end)
end

function INV:RemoveItem(charId, itemId, amount, callback)
    charId = tonumber(charId)
    itemId = tostring(itemId or "")
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if not charId or charId <= 0 then
        if callback then callback(false, "no_character") end
        return
    end

    self:LoadInventory(charId, function(ok, _)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local total = 0
        local inv = self._cache[charId] or {}
        for slot = 1, self:GetSlotCount() do
            if inv[slot] and inv[slot].item_id == itemId then total = total + inv[slot].amount end
        end

        if total < amount then
            if callback then callback(false, "not_enough") end
            return
        end

        local remaining = amount
        local slotsToSave = {}
        for slot = 1, self:GetSlotCount() do
            if remaining <= 0 then break end
            local data = inv[slot]
            if data and data.item_id == itemId then
                local take = math.min(remaining, data.amount)
                data.amount = data.amount - take
                remaining = remaining - take
                if data.amount <= 0 then
                    self._cache[charId][slot] = nil
                    slotsToSave[slot] = false
                else
                    slotsToSave[slot] = data
                end
            end
        end

        local saveCount = table.Count(slotsToSave)
        local savedCount = 0
        for slot, slotData in pairs(slotsToSave) do
            self:SaveSlot(charId, slot, slotData or nil, function()
                savedCount = savedCount + 1
                if savedCount >= saveCount and callback then callback(true) end
            end)
        end
    end)
end

function INV:RemoveItemFromSlot(charId, slot, amount, callback)
    charId = tonumber(charId)
    slot = tonumber(slot)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    local slotCount = self:GetSlotCount()
    if not charId or charId <= 0 then
        if callback then callback(false, "no_character") end
        return
    end

    if not slot or slot < 1 or slot > slotCount then
        if callback then callback(false, "invalid_slot") end
        return
    end

    self:LoadInventory(charId, function(ok, _)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local data = self._cache[charId] and self._cache[charId][slot]
        if not data then
            if callback then callback(false, "slot_empty") end
            return
        end

        if data.amount < amount then
            if callback then callback(false, "not_enough") end
            return
        end

        data.amount = data.amount - amount
        if data.amount <= 0 then
            self._cache[charId][slot] = nil
            self:SaveSlot(charId, slot, nil, function(savedOk) if callback then callback(savedOk and true or false, savedOk and nil or "db_error") end end)
        else
            self:SaveSlot(charId, slot, data, function(savedOk) if callback then callback(savedOk and true or false, savedOk and nil or "db_error") end end)
        end
    end)
end

function INV:MoveItem(charId, fromSlot, toSlot, callback)
    charId = tonumber(charId)
    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    local slotCount = self:GetSlotCount()
    if not charId or not fromSlot or not toSlot then
        if callback then callback(false, "invalid_slot") end
        return
    end

    if fromSlot < 1 or fromSlot > slotCount or toSlot < 1 or toSlot > slotCount then
        if callback then callback(false, "invalid_slot") end
        return
    end

    if fromSlot == toSlot then
        if callback then callback(true) end
        return
    end

    self:LoadInventory(charId, function(ok)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local inv = self._cache[charId]
        local fromData = inv[fromSlot]
        local toData = inv[toSlot]
        if not fromData then
            if callback then callback(false, "slot_empty") end
            return
        end

        inv[fromSlot] = toData
        inv[toSlot] = fromData
        if callback then callback(true) end
        self:SaveSlot(charId, fromSlot, toData)
        self:SaveSlot(charId, toSlot, fromData)
    end)
end

function INV:StackItems(charId, fromSlot, toSlot, callback)
    charId = tonumber(charId)
    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    local slotCount = self:GetSlotCount()
    if not charId or not fromSlot or not toSlot then
        if callback then callback(false, "invalid_slot") end
        return
    end

    if fromSlot < 1 or fromSlot > slotCount or toSlot < 1 or toSlot > slotCount then
        if callback then callback(false, "invalid_slot") end
        return
    end

    if fromSlot == toSlot then
        if callback then callback(true) end
        return
    end

    self:LoadInventory(charId, function(ok)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local inv = self._cache[charId]
        local fromData = inv[fromSlot]
        local toData = inv[toSlot]
        if not fromData or not toData then
            if callback then callback(false, "slot_empty") end
            return
        end

        if fromData.item_id ~= toData.item_id then
            if callback then callback(false, "not_stackable") end
            return
        end

        if not self:MetadataMatch(fromData.metadata, toData.metadata) then
            if callback then callback(false, "not_stackable") end
            return
        end

        local maxStack = self:GetMaxStack(toData.item_id)
        if toData.amount >= maxStack then
            if callback then callback(false, "stack_full") end
            return
        end

        local canMove = math.min(fromData.amount, maxStack - toData.amount)
        toData.amount = toData.amount + canMove
        fromData.amount = fromData.amount - canMove
        if fromData.amount <= 0 then inv[fromSlot] = nil end
        if callback then callback(true) end
        self:SaveSlot(charId, fromSlot, inv[fromSlot])
        self:SaveSlot(charId, toSlot, toData)
    end)
end

function INV:SplitStack(charId, fromSlot, splitAmount, targetSlot, callback)
    charId = tonumber(charId)
    fromSlot = tonumber(fromSlot)
    splitAmount = math.max(1, math.floor(tonumber(splitAmount) or 1))
    targetSlot = tonumber(targetSlot)
    local slotCount = self:GetSlotCount()
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    if not fromSlot or fromSlot < 1 or fromSlot > slotCount then
        if callback then callback(false, "invalid_slot") end
        return
    end

    self:LoadInventory(charId, function(ok)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local inv = self._cache[charId]
        local fromData = inv[fromSlot]
        if not fromData then
            if callback then callback(false, "slot_empty") end
            return
        end

        if fromData.amount <= 1 or splitAmount >= fromData.amount then
            if callback then callback(false, "bad_amount") end
            return
        end

        if targetSlot then
            if targetSlot < 1 or targetSlot > slotCount then
                if callback then callback(false, "invalid_slot") end
                return
            end

            if inv[targetSlot] then
                if callback then callback(false, "slot_occupied") end
                return
            end
        else
            targetSlot = self:FindFirstEmptySlot(charId)
            if not targetSlot then
                if callback then callback(false, "inventory_full") end
                return
            end
        end

        local newData = {
            item_id = fromData.item_id,
            amount = splitAmount,
            metadata = fromData.metadata and table.Copy(fromData.metadata) or nil,
        }

        fromData.amount = fromData.amount - splitAmount
        inv[targetSlot] = newData
        if callback then callback(true) end
        self:SaveSlot(charId, fromSlot, fromData)
        self:SaveSlot(charId, targetSlot, newData)
    end)
end

function INV:UseItem(ply, slot, callback)
    if not IsValid(ply) then
        if callback then callback(false, "no_character") end
        return
    end

    local charId = self:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    slot = tonumber(slot)
    if not slot or slot < 1 or slot > self:GetSlotCount() then
        if callback then callback(false, "invalid_slot") end
        return
    end

    self:LoadInventory(charId, function(ok)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local data = self._cache[charId] and self._cache[charId][slot]
        if not data then
            if callback then callback(false, "slot_empty") end
            return
        end

        local def = self:GetItemDef(data.item_id)
        if not def or not def.usable then
            if callback then callback(false, "not_usable") end
            return
        end

        local handlerName = tostring(def.on_use or "")
        local handler = self:GetUseHandler(handlerName)
        if not handler then
            if callback then callback(false, "not_usable") end
            return
        end

        local consumed, consumeAmount = handler(ply, data.item_id, data, slot)
        if consumed then
            consumeAmount = math.max(1, math.floor(tonumber(consumeAmount) or 1))
            self:RemoveItemFromSlot(charId, slot, consumeAmount, function(removeOk, removeErr) if callback then callback(removeOk, removeErr) end end)
        else
            if callback then callback(true) end
        end
    end)
end

function INV:DropItem(ply, slot, amount, callback)
    if not IsValid(ply) then
        if callback then callback(false, "no_character") end
        return
    end

    if not self.Config.DropEnabled then
        if callback then callback(false, "not_droppable") end
        return
    end

    local charId = self:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    slot = tonumber(slot)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if not slot or slot < 1 or slot > self:GetSlotCount() then
        if callback then callback(false, "invalid_slot") end
        return
    end

    local inv = self._cache[charId]
    if not inv then
        if callback then callback(false, "no_character") end
        return
    end

    local data = inv[slot]
    if not data then
        if callback then callback(false, "slot_empty") end
        return
    end

    local def = self:GetItemDef(data.item_id)
    if not def or def.droppable == false then
        if callback then callback(false, "not_droppable") end
        return
    end

    if data.amount < amount then
        if callback then callback(false, "not_enough") end
        return
    end

    local droppedData = {
        item_id = data.item_id,
        amount = amount,
        metadata = data.metadata and table.Copy(data.metadata) or nil,
    }

    if data.amount <= amount then
        inv[slot] = nil
    else
        data.amount = data.amount - amount
    end

    if callback then callback(true) end
    self:SaveSlot(charId, slot, inv[slot] or nil)

    local pos = ply:GetPos() + Vector(0, 0, 40)
    local ent = ents.Create("verse_dropped_item")
    if IsValid(ent) then
        local model = (def.custom and def.custom.world_model) or "models/props_junk/cardboard_box004a.mdl"
        ent._worldModel = model
        ent:SetPos(pos)
        ent:Spawn()
        ent:SetDropData(droppedData)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(ply:GetAimVector() * 180 + Vector(0, 0, 120))
        end
    end
end

function INV:TransferItem(ply, targetPly, fromSlot, amount, callback)
    if not IsValid(ply) or not IsValid(targetPly) then
        if callback then callback(false, "target_invalid") end
        return
    end

    if not self.Config.TransferEnabled then
        if callback then callback(false, "not_tradeable") end
        return
    end

    if ply == targetPly then
        if callback then callback(false, "target_invalid") end
        return
    end

    local charId = self:GetCharacterUID(ply)
    local targetCharId = self:GetCharacterUID(targetPly)
    if not charId or not targetCharId then
        if callback then callback(false, "no_character") end
        return
    end

    fromSlot = tonumber(fromSlot)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if not fromSlot or fromSlot < 1 or fromSlot > self:GetSlotCount() then
        if callback then callback(false, "invalid_slot") end
        return
    end

    local dist = ply:GetPos():Distance(targetPly:GetPos())
    if dist > self.Config.TransferMaxDistance then
        if callback then callback(false, "target_too_far") end
        return
    end

    self:LoadInventory(charId, function(ok)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local data = self._cache[charId] and self._cache[charId][fromSlot]
        if not data then
            if callback then callback(false, "slot_empty") end
            return
        end

        local def = self:GetItemDef(data.item_id)
        if not def or def.tradeable == false then
            if callback then callback(false, "not_tradeable") end
            return
        end

        if data.amount < amount then
            if callback then callback(false, "not_enough") end
            return
        end

        local transferMeta = data.metadata and table.Copy(data.metadata) or nil
        local transferItemId = data.item_id
        self:RemoveItemFromSlot(charId, fromSlot, amount, function(removeOk, removeErr)
            if not removeOk then
                if callback then callback(false, removeErr or "db_error") end
                return
            end

            self:AddItem(targetCharId, transferItemId, amount, transferMeta, function(addOk, addErr)
                if not addOk then
                    self:AddItem(charId, transferItemId, amount, transferMeta, function() end)
                    if callback then callback(false, addErr or "target_full") end
                    return
                end

                self:SendSync(ply, charId)
                self:SendSync(targetPly, targetCharId)
                if callback then callback(true) end
            end)
        end)
    end)
end

function INV:EquipItem(charId, fromSlot, equipSlot, callback)
    charId = tonumber(charId)
    fromSlot = tonumber(fromSlot)
    equipSlot = tonumber(equipSlot)
    if not charId or not fromSlot or not equipSlot then
        if callback then callback(false, "invalid_slot") end
        return
    end

    if not self:IsEquipSlot(equipSlot) then
        if callback then callback(false, "invalid_slot") end
        return
    end

    if fromSlot < 1 or fromSlot > self:GetSlotCount() then
        if callback then callback(false, "invalid_slot") end
        return
    end

    self:LoadInventory(charId, function(ok)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local inv = self._cache[charId]
        local fromData = inv[fromSlot]
        if not fromData then
            if callback then callback(false, "slot_empty") end
            return
        end

        if not self:CanEquipToSlot(fromData.item_id, equipSlot) then
            if callback then callback(false, "invalid_slot") end
            return
        end

        local existingEquip = inv[equipSlot]
        inv[fromSlot] = existingEquip
        inv[equipSlot] = fromData
        if callback then callback(true) end
        self:SaveSlot(charId, fromSlot, existingEquip)
        self:SaveSlot(charId, equipSlot, fromData)
    end)
end

function INV:UnequipItem(charId, equipSlot, callback)
    charId = tonumber(charId)
    equipSlot = tonumber(equipSlot)
    if not charId or not equipSlot then
        if callback then callback(false, "invalid_slot") end
        return
    end

    if not self:IsEquipSlot(equipSlot) then
        if callback then callback(false, "invalid_slot") end
        return
    end

    self:LoadInventory(charId, function(ok)
        if not ok then
            if callback then callback(false, "db_error") end
            return
        end

        local inv = self._cache[charId]
        local equipData = inv[equipSlot]
        if not equipData then
            if callback then callback(false, "slot_empty") end
            return
        end

        local emptySlot = self:FindFirstEmptySlot(charId)
        if not emptySlot then
            if callback then callback(false, "inventory_full") end
            return
        end

        inv[equipSlot] = nil
        inv[emptySlot] = equipData
        if callback then callback(true) end
        self:SaveSlot(charId, equipSlot, nil)
        self:SaveSlot(charId, emptySlot, equipData)
    end)
end

function INV:SortInventory(charId, callback)
    charId = tonumber(charId)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    local inv = self._cache[charId]
    if not inv then
        if callback then callback(false, "no_character") end
        return
    end

    do
        local items = {}
        local slotCount = self:GetSlotCount()
        for slot = 1, slotCount do
            if inv[slot] then
                table.insert(items, inv[slot])
                inv[slot] = nil
            end
        end

        local merged = {}
        for _, item in ipairs(items) do
            local found = false
            for _, m in ipairs(merged) do
                if m.item_id == item.item_id and self:MetadataMatch(m.metadata, item.metadata) then
                    local maxStack = self:GetMaxStack(m.item_id)
                    local canAdd = math.min(item.amount, maxStack - m.amount)
                    if canAdd > 0 then
                        m.amount = m.amount + canAdd
                        item.amount = item.amount - canAdd
                    end

                    if item.amount <= 0 then
                        found = true
                        break
                    end
                end
            end

            if not found and item.amount > 0 then table.insert(merged, item) end
        end

        table.sort(merged, function(a, b)
            local defA = self:GetItemDef(a.item_id)
            local defB = self:GetItemDef(b.item_id)
            local catA = defA and defA.category or "misc"
            local catB = defB and defB.category or "misc"
            if catA ~= catB then return catA < catB end
            if a.item_id ~= b.item_id then return a.item_id < b.item_id end
            return a.amount > b.amount
        end)

        for i, item in ipairs(merged) do
            if i <= slotCount then inv[i] = item end
        end

        if callback then callback(true) end
        for slot = 1, slotCount do
            self:SaveSlot(charId, slot, inv[slot] or nil)
        end
    end
end

function INV:SendError(ply, code)
    if not IsValid(ply) then return end
    local msg = ERROR_MESSAGES[tostring(code or "")] or code
    if isfunction(ply.Notify) then ply:Notify(tostring(msg), NOTIFY_ERROR, 3.5) end
    netstream.Start(ply, self.Net.Error, tostring(code or "unknown"))
end

function INV:CleanOrphans(charId)
    local inv = self._cache[tonumber(charId)]
    if not inv then return end
    for slot, data in pairs(inv) do
        if istable(data) and not self:GetItemDef(data.item_id) then
            inv[slot] = nil
            self:SaveSlot(charId, slot, nil)
        end
    end
end

function INV:SendSync(ply, charId)
    if not IsValid(ply) then return end
    charId = tonumber(charId)
    self:CleanOrphans(charId)
    local inv = cloneInventory(self._cache[charId] or {})
    netstream.Start(ply, self.Net.Sync, charId or 0, inv)
end

function INV:SyncPlayer(ply)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        netstream.Start(ply, self.Net.Sync, 0, {})
        return
    end

    self:LoadInventory(charId, function(ok)
        if ok then
            self:SendSync(ply, charId)
        else
            self:SendError(ply, "db_error")
        end
    end)
end

function PLAYER:GetInventory(callback)
    local charId = INV:GetCharacterUID(self)
    if not charId then
        if callback then callback(false, "no_character") end
        return nil
    end

    local cached = INV._cache[charId]
    if cached then
        if callback then callback(true, cloneInventory(cached)) end
        return cloneInventory(cached)
    end

    if callback then INV:LoadInventory(charId, function(ok, inv) callback(ok, inv) end) end
    return nil
end

function PLAYER:AddItem(itemId, amount, metadata, callback)
    local charId = INV:GetCharacterUID(self)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    INV:AddItem(charId, itemId, amount, metadata, function(ok, err)
        if ok then INV:SendSync(self, charId) end
        if callback then callback(ok, err) end
    end)
end

function PLAYER:RemoveItem(itemId, amount, callback)
    local charId = INV:GetCharacterUID(self)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    INV:RemoveItem(charId, itemId, amount, function(ok, err)
        if ok then INV:SendSync(self, charId) end
        if callback then callback(ok, err) end
    end)
end

function PLAYER:HasItem(itemId, amount)
    local charId = INV:GetCharacterUID(self)
    if not charId then return false end
    local inv = INV._cache[charId] or {}
    local total = 0
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    for _, data in pairs(inv) do
        if data.item_id == itemId then
            total = total + data.amount
            if total >= amount then return true end
        end
    end
    return false
end

function PLAYER:GetItemCount(itemId)
    local charId = INV:GetCharacterUID(self)
    if not charId then return 0 end
    local inv = INV._cache[charId] or {}
    local total = 0
    for _, data in pairs(inv) do
        if data.item_id == itemId then total = total + data.amount end
    end
    return total
end

function PLAYER:GetMoney()
    return self:GetItemCount(INV.CurrencyItemID)
end

function PLAYER:HasMoney(amount)
    return self:HasItem(INV.CurrencyItemID, amount)
end

function PLAYER:AddMoney(amount, callback)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        if callback then callback(false, "bad_amount") end
        return
    end
    self:AddItem(INV.CurrencyItemID, amount, nil, callback)
end

function PLAYER:DeductMoney(amount, callback)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        if callback then callback(false, "bad_amount") end
        return
    end
    if not self:HasMoney(amount) then
        if callback then callback(false, "not_enough") end
        return
    end
    self:RemoveItem(INV.CurrencyItemID, amount, callback)
end

function PLAYER:SetMoney(amount, callback)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local current = self:GetMoney()
    if current == amount then
        if callback then callback(true) end
        return
    elseif amount > current then
        self:AddMoney(amount - current, callback)
    elseif amount == 0 then
        self:RemoveItem(INV.CurrencyItemID, current, callback)
    else
        self:DeductMoney(current - amount, callback)
    end
end

netstream.Hook(INV.Net.Request, function(ply) INV:SyncPlayer(ply) end)
netstream.Hook(INV.Net.Move, function(ply, fromSlot, toSlot)
    local charId = INV:GetCharacterUID(ply)
    if not charId then INV:SendError(ply, "no_character") return end
    if not checkCooldown(ply, "move") then return end
    if not invAcquire(charId, "move") then return end

    INV:MoveItem(charId, fromSlot, toSlot, function(ok, err)
        invRelease(charId, "move")
        if not ok then INV:SendError(ply, err) return end
        INV:SendSync(ply, charId)
    end)
end)

netstream.Hook(INV.Net.Stack, function(ply, fromSlot, toSlot)
    local charId = INV:GetCharacterUID(ply)
    if not charId then INV:SendError(ply, "no_character") return end
    if not checkCooldown(ply, "stack") then return end
    if not invAcquire(charId, "stack") then return end

    INV:StackItems(charId, fromSlot, toSlot, function(ok, err)
        invRelease(charId, "stack")
        if not ok then INV:SendError(ply, err) return end
        INV:SendSync(ply, charId)
    end)
end)

netstream.Hook(INV.Net.Split, function(ply, fromSlot, splitAmount, targetSlot)
    local charId = INV:GetCharacterUID(ply)
    if not charId then INV:SendError(ply, "no_character") return end
    if not checkCooldown(ply, "split") then return end
    if not invAcquire(charId, "split") then return end

    INV:SplitStack(charId, fromSlot, splitAmount, targetSlot, function(ok, err)
        invRelease(charId, "split")
        if not ok then INV:SendError(ply, err) return end
        INV:SendSync(ply, charId)
    end)
end)

local function itemName(itemId)
    local def = INV:GetItemDef(itemId)
    return def and def.name or itemId
end

netstream.Hook(INV.Net.Use, function(ply, slot)
    local charId = INV:GetCharacterUID(ply)
    if not charId then INV:SendError(ply, "no_character") return end
    if not checkCooldown(ply, "use") then return end
    if not invAcquire(charId, "use") then return end

    local inv = INV._cache[charId]
    local data = inv and inv[tonumber(slot)]
    INV:UseItem(ply, slot, function(ok, err)
        invRelease(charId, "use")
        if not ok then INV:SendError(ply, err) return end
        INV:SendSync(ply, charId)
        if data and isfunction(ply.Notify) then ply:Notify("Utilisé : " .. itemName(data.item_id), NOTIFY_HINT, 3) end
    end)
end)

netstream.Hook(INV.Net.Drop, function(ply, slot, amount)
    local charId = INV:GetCharacterUID(ply)
    if not charId then INV:SendError(ply, "no_character") return end
    if not checkCooldown(ply, "drop") then return end
    if not invAcquire(charId, "drop") then return end

    local inv = INV._cache[charId]
    local data = inv and inv[tonumber(slot)]
    local name = data and itemName(data.item_id) or "?"
    INV:DropItem(ply, slot, amount, function(ok, err)
        invRelease(charId, "drop")
        if not ok then INV:SendError(ply, err) return end
        INV:SendSync(ply, charId)
        if isfunction(ply.Notify) then
            local amt = math.max(1, math.floor(tonumber(amount) or 1))
            local text = amt > 1 and ("Jeté : " .. amt .. "x " .. name) or ("Jeté : " .. name)
            ply:Notify(text, NOTIFY_HINT, 3)
        end
    end)
end)

netstream.Hook(INV.Net.Transfer, function(ply, targetSteamID64, fromSlot, amount)
    local charId = INV:GetCharacterUID(ply)
    if not charId then INV:SendError(ply, "no_character") return end
    if not checkCooldown(ply, "transfer") then return end
    if not invAcquire(charId, "transfer") then return end

    -- Validation du SteamID64 : chiffres uniquement, 15-20 caractères
    local sid64str = tostring(targetSteamID64 or "")
    if not sid64str:match("^%d+$") or #sid64str < 15 or #sid64str > 20 then
        invRelease(charId, "transfer")
        INV:SendError(ply, "target_invalid")
        return
    end

    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID64() == sid64str then target = p break end
    end

    if not IsValid(target) then
        invRelease(charId, "transfer")
        INV:SendError(ply, "target_invalid")
        return
    end

    INV:TransferItem(ply, target, fromSlot, amount, function(ok, err)
        invRelease(charId, "transfer")
        if not ok then INV:SendError(ply, err) end
    end)
end)

netstream.Hook(INV.Net.Equip, function(ply, fromSlot, equipSlot)
    local charId = INV:GetCharacterUID(ply)
    if not charId then
        INV:SendError(ply, "no_character")
        return
    end
    if not checkCooldown(ply, "equip") then return end
    if not invAcquire(charId, "equip") then return end

    local inv = INV._cache[charId]
    local data = inv and inv[tonumber(fromSlot)]
    local name = data and itemName(data.item_id) or "?"

    -- Restriction de sexe : une tenue marquée male/female ne peut être équipée que
    -- sur un personnage du même sexe (gender "unisex" ou absent = pas de restriction).
    local def = data and INV:GetItemDef(data.item_id)
    if def and def.gender and def.gender ~= "unisex" then
        local ch = CH and CH.GetSelected and CH:GetSelected(ply)
        local plyGender = (istable(ch) and tostring(ch.gender or "male")) or "male"
        if def.gender ~= plyGender then
            invRelease(charId, "equip")
            INV:SendError(ply, "wrong_gender")
            return
        end
    end

    INV:EquipItem(charId, fromSlot, equipSlot, function(ok, err)
        invRelease(charId, "equip")
        if not ok then
            INV:SendError(ply, err)
            return
        end

        INV:SendSync(ply, charId)
        if isfunction(ply.Notify) then ply:Notify("Équipé : " .. name, NOTIFY_HINT, 3) end
    end)
end)

netstream.Hook(INV.Net.Unequip, function(ply, equipSlot)
    local charId = INV:GetCharacterUID(ply)
    if not charId then
        INV:SendError(ply, "no_character")
        return
    end

    local inv = INV._cache[charId]
    local data = inv and inv[tonumber(equipSlot)]
    local name = data and itemName(data.item_id) or "?"
    INV:UnequipItem(charId, equipSlot, function(ok, err)
        if not ok then
            INV:SendError(ply, err)
            return
        end

        INV:SendSync(ply, charId)
        if isfunction(ply.Notify) then ply:Notify("Déséquipé : " .. name, NOTIFY_HINT, 3) end
    end)
end)

netstream.Hook(INV.Net.Sort, function(ply)
    local charId = INV:GetCharacterUID(ply)
    if not charId then
        INV:SendError(ply, "no_character")
        return
    end
    if not checkCooldown(ply, "sort") then return end

    INV:SortInventory(charId, function(ok, err)
        if not ok then
            INV:SendError(ply, err)
            return
        end

        INV:SendSync(ply, charId)
    end)
end)

netstream.Hook(INV.Net.Delete, function(ply, slot, amount)
    local charId = INV:GetCharacterUID(ply)
    if not charId then INV:SendError(ply, "no_character") return end
    if not checkCooldown(ply, "delete") then return end
    if not invAcquire(charId, "delete") then return end

    slot   = tonumber(slot)
    amount = math.max(1, math.floor(tonumber(amount) or 1))  -- jamais nil/négatif/0
    if not slot then invRelease(charId, "delete") return end

    local cache = INV._cache[charId]
    if not cache or not cache[slot] then
        invRelease(charId, "delete")
        INV:SendError(ply, "empty_slot")
        return
    end

    local data = cache[slot]
    local name = INV:GetItemName(data.item_id)

    if amount > 0 and amount < data.amount then
        data.amount = data.amount - amount
        INV:SaveSlot(charId, slot, data)
        if isfunction(ply.Notify) then ply:Notify("Supprimé : " .. amount .. "x " .. name, NOTIFY_HINT, 3) end
    else
        local removed = data.amount or 1
        cache[slot] = nil
        INV:SaveSlot(charId, slot, nil)
        if isfunction(ply.Notify) then ply:Notify("Supprimé : " .. removed .. "x " .. name, NOTIFY_HINT, 3) end
    end
    invRelease(charId, "delete")

    INV:SendSync(ply, charId)
end)

local function isAdmin(ply)
    if not IsValid(ply) then return false end
    local CH = VERSE.Characters
    if CH and CH.CanAccessAdminCharacters then return CH:CanAccessAdminCharacters(ply) end
    return ply:IsSuperAdmin()
end

netstream.Hook(INV.Net.AdminView, function(ply, targetCharId)
    if not isAdmin(ply) then return end
    targetCharId = tonumber(targetCharId)
    if not targetCharId or targetCharId <= 0 then return end

    INV:LoadInventory(targetCharId, function(ok)
        if not ok then
            INV:SendError(ply, "db_error")
            return
        end
        local inv = cloneInventory(INV._cache[targetCharId] or {})
        netstream.Start(ply, INV.Net.AdminSync, targetCharId, inv)
    end)
end)

netstream.Hook(INV.Net.AdminGive, function(ply, targetCharId, itemId, amount)
    if not isAdmin(ply) then return end
    targetCharId = tonumber(targetCharId)
    itemId = tostring(itemId or "")
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if not targetCharId or targetCharId <= 0 then return end

    local def = INV:GetItemDef(itemId)
    if not def then
        if isfunction(ply.Notify) then ply:Notify("Item invalide : " .. itemId, NOTIFY_ERROR, 3) end
        return
    end

    INV:AddItem(targetCharId, itemId, amount, nil, function(ok, err)
        if not ok then
            if isfunction(ply.Notify) then ply:Notify("Erreur : " .. tostring(err), NOTIFY_ERROR, 3) end
            return
        end

        if isfunction(ply.Notify) then ply:Notify("Donné : " .. amount .. "x " .. (def.name or itemId), NOTIFY_HINT, 3) end

        local inv = cloneInventory(INV._cache[targetCharId] or {})
        netstream.Start(ply, INV.Net.AdminSync, targetCharId, inv)

        for _, p in ipairs(player.GetAll()) do
            local cid = INV:GetCharacterUID(p)
            if cid == targetCharId then
                INV:SendSync(p, targetCharId)
                break
            end
        end
    end)
end)

netstream.Hook(INV.Net.AdminRemove, function(ply, targetCharId, slot)
    if not isAdmin(ply) then return end
    targetCharId = tonumber(targetCharId)
    slot = tonumber(slot)
    if not targetCharId or targetCharId <= 0 or not slot then return end

    INV:LoadInventory(targetCharId, function(ok)
        if not ok then
            INV:SendError(ply, "db_error")
            return
        end

        local cache = INV._cache[targetCharId]
        if not cache or not cache[slot] then
            if isfunction(ply.Notify) then ply:Notify("Slot vide.", NOTIFY_ERROR, 3) end
            return
        end

        local removed = cache[slot]
        local name = INV:GetItemName(removed.item_id)

        if INV:IsEquipSlot(slot) then
            local EQ = INV.Equipment
            if EQ then
                for _, p in ipairs(player.GetAll()) do
                    local cid = INV:GetCharacterUID(p)
                    if cid == targetCharId then
                        EQ:RemoveSlotEffect(p, slot, removed)
                        p:RecalcStats(false)
                        break
                    end
                end
            end
        end

        cache[slot] = nil
        INV:SaveSlot(targetCharId, slot, nil)
        if isfunction(ply.Notify) then ply:Notify("Retiré : " .. (removed.amount or 1) .. "x " .. name, NOTIFY_HINT, 3) end

        local inv = cloneInventory(cache)
        netstream.Start(ply, INV.Net.AdminSync, targetCharId, inv)

        for _, p in ipairs(player.GetAll()) do
            local cid = INV:GetCharacterUID(p)
            if cid == targetCharId then
                INV:SendSync(p, targetCharId)
                break
            end
        end
    end)
end)

VERSE.Hook.AddNS("Inventory", "VERSE::Characters::Loaded", "VERSE::Inventory::CharacterLoaded", function(ply) INV:SyncPlayer(ply) end)
VERSE.Hook.AddNS("Inventory", "VERSE::Characters::Deleted", "VERSE::Inventory::CharacterDeleted", function(charId) INV:DeleteInventory(charId) end)
VERSE.DB:OnReady(function() INV:CreateTables() end)