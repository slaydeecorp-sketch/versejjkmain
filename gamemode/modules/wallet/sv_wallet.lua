local W   = VERSE.Wallet
local DB  = VERSE.DB
local CH  = VERSE.Characters
local INV = VERSE.Inventory

W._cache = W._cache or {}   -- [charId] = amount (number)

local T = "verse_wallet"

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function getCharId(ply)
    if not IsValid(ply) then return nil end
    if CH and CH.GetSelected then
        local char = CH:GetSelected(ply)
        if istable(char) then return tonumber(char.id) end
    end
    return nil
end

-- ─── Création de la table DB ──────────────────────────────────────────────────

function W:CreateTable()
    local q
    if DB:IsMySQL() then
        q = [[
            CREATE TABLE IF NOT EXISTS verse_wallet (
                char_id INT NOT NULL,
                amount  INT NOT NULL DEFAULT 0,
                PRIMARY KEY (char_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]
    else
        q = [[
            CREATE TABLE IF NOT EXISTS verse_wallet (
                char_id INTEGER NOT NULL,
                amount  INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (char_id)
            )
        ]]
    end
    DB:Query(q, function() end, function(err)
        if VERSE.Log then VERSE.Log:Error("[Wallet] create table failed: " .. tostring(err)) end
        return true
    end)
end

-- ─── Lecture cache ─────────────────────────────────────────────────────────────

function W:GetCached(charId)
    return self._cache[tonumber(charId)] or 0
end

-- ─── Écriture DB ──────────────────────────────────────────────────────────────

function W:_WriteDB(charId, amount)
    local q
    if DB:IsMySQL() then
        q = ("INSERT INTO %s (char_id, amount) VALUES (%d, %d) ON DUPLICATE KEY UPDATE amount=VALUES(amount)"):format(T, charId, amount)
    else
        q = ("INSERT OR REPLACE INTO %s (char_id, amount) VALUES (%d, %d)"):format(T, charId, amount)
    end
    DB:Query(q, function() end, function(err)
        if VERSE.Log then VERSE.Log:Error("[Wallet] write failed: " .. tostring(err)) end
        return true
    end)
end

-- ─── Chargement depuis la DB ───────────────────────────────────────────────────
-- Si le joueur n'a pas encore de ligne dans verse_wallet (migration),
-- on récupère l'argent depuis l'inventaire et on le supprime.

function W:Load(charId, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(0) end
        return
    end

    if self._cache[charId] ~= nil then
        if callback then callback(self._cache[charId]) end
        return
    end

    DB:Query(("SELECT amount FROM %s WHERE char_id=%d"):format(T, charId)):Next(function(res)
        local row    = res.rows and res.rows[1]
        local amount = row and math.max(0, math.floor(tonumber(row.amount) or 0)) or 0

        -- Migration : si première utilisation, rapatrie l'argent depuis l'inventaire
        if not row and INV and INV._cache and INV._cache[charId] then
            local migrated = 0
            for _, slot in pairs(INV._cache[charId]) do
                if istable(slot) and slot.item_id == (INV.CurrencyItemID or "money") then
                    migrated = migrated + math.max(0, math.floor(tonumber(slot.amount) or 0))
                end
            end
            if migrated > 0 then
                amount = migrated
                INV:RemoveItem(charId, INV.CurrencyItemID or "money", migrated, function() end)
                if VERSE.Log then
                    VERSE.Log:Info(("[Wallet] Migration charId=%d : %d Y transférés depuis l'inventaire"):format(charId, migrated))
                end
            end
        end

        self._cache[charId] = amount
        self:_WriteDB(charId, amount)
        if callback then callback(amount) end
    end):Catch(function(err)
        if VERSE.Log then VERSE.Log:Error("[Wallet] load failed: " .. tostring(err)) end
        self._cache[charId] = 0
        if callback then callback(0) end
    end)
end

-- ─── API publique ──────────────────────────────────────────────────────────────

function W:SetAmount(charId, amount, callback)
    charId = tonumber(charId)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end
    self._cache[charId] = amount
    self:_WriteDB(charId, amount)
    if callback then callback(true) end
end

function W:AddAmount(charId, amount, callback)
    charId = tonumber(charId)
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end
    local cur = self._cache[charId] or 0
    self:SetAmount(charId, cur + amount, callback)
end

function W:DeductAmount(charId, amount, callback)
    charId = tonumber(charId)
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end
    local cur = self._cache[charId] or 0
    if cur < amount then
        if callback then callback(false, "not_enough") end
        return
    end
    self:SetAmount(charId, cur - amount, callback)
end

function W:Unload(charId)
    self._cache[tonumber(charId)] = nil
end

-- ─── Sync client ──────────────────────────────────────────────────────────────

function W:Sync(ply, charId)
    if not IsValid(ply) then return end
    local amount = charId and (self._cache[tonumber(charId)] or 0) or 0
    netstream.Start(ply, W.Net.Sync, amount)
end

-- ─── Remplacement des méthodes PLAYER ────────────────────────────────────────
-- Ces définitions écrasent celles de sv_inventory.lua (wallet charge après inventory).

local PLAYER = FindMetaTable("Player")

function PLAYER:GetMoney()
    local cid = getCharId(self)
    return cid and W:GetCached(cid) or 0
end

function PLAYER:HasMoney(amount)
    return self:GetMoney() >= math.max(0, math.floor(tonumber(amount) or 0))
end

function PLAYER:AddMoney(amount, callback)
    local cid = getCharId(self)
    if not cid then
        if callback then callback(false, "no_character") end
        return
    end
    W:AddAmount(cid, amount, function(ok, err)
        if ok then W:Sync(self, cid) end
        if callback then callback(ok, err) end
    end)
end

function PLAYER:DeductMoney(amount, callback)
    local cid = getCharId(self)
    if not cid then
        if callback then callback(false, "no_character") end
        return
    end
    W:DeductAmount(cid, amount, function(ok, err)
        if ok then W:Sync(self, cid) end
        if callback then callback(ok, err) end
    end)
end

function PLAYER:SetMoney(amount, callback)
    local cid = getCharId(self)
    if not cid then
        if callback then callback(false, "no_character") end
        return
    end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    W:SetAmount(cid, amount, function(ok, err)
        if ok then W:Sync(self, cid) end
        if callback then callback(ok, err) end
    end)
end

-- ─── Hooks ────────────────────────────────────────────────────────────────────

VERSE.Hook.AddNS("Wallet", "VERSE::Characters::Loaded", "VERSE::Wallet::CharLoaded", function(ply)
    if not IsValid(ply) then return end
    local cid = getCharId(ply)
    if not cid then return end
    W:Load(cid, function()
        W:Sync(ply, cid)
    end)
end)

VERSE.Hook.AddNS("Wallet", "VERSE::Characters::Unloaded", "VERSE::Wallet::CharUnloaded", function(ply, charId)
    if charId then W:Unload(charId) end
end)

VERSE.Hook.AddNS("Wallet", "PlayerDisconnected", "VERSE::Wallet::Disconnect", function(ply)
    local cid = getCharId(ply)
    if cid then W:Unload(cid) end
end)

VERSE.DB:OnReady(function() W:CreateTable() end)
