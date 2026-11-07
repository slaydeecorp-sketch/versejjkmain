local BT = VERSE.Boutique
local DB = VERSE.DB
if not BT or not DB then return end
local _btCreatorCD = {}
BT._cache = BT._cache or {}
BT._busy = BT._busy or {}
BT.RerollPool = BT.RerollPool or {}

-- ─── Utilitaires ─────────────────────────────────────────────────────────────

local function esc(value)
    return DB:Escape(value)
end

local function now()
    return math.floor(os.time())
end

local function logInfo(...)
    if VERSE.Log and VERSE.Log.Info then VERSE.Log:Info("[Boutique]", ...) end
end

local function logErr(...)
    if VERSE.Log and VERSE.Log.Error then
        VERSE.Log:Error("[Boutique]", ...)
    else
        ErrorNoHalt("[Boutique] " .. table.concat({...}, " ") .. "\n")
    end
end

-- ─── Cache global des ventes (pour purchase_limit_global) ────────────────────
BT._globalSold = BT._globalSold or {} -- [item_id] = total vendu tous joueurs confondus

local function loadGlobalSold()
    local tbl = BT:GetItemsTableName()
    DB:Query(("SELECT item_id, SUM(amount) as total FROM %s GROUP BY item_id"):format(tbl), function(rows)
        rows = rows or {}
        for _, row in ipairs(rows) do
            local id = tostring(row.item_id or "")
            if id ~= "" then
                BT._globalSold[id] = math.max(0, math.floor(tonumber(row.total) or 0))
            end
        end
        logInfo("GlobalSold chargé : " .. table.Count(BT._globalSold) .. " produits.")
    end, function(err)
        logErr("loadGlobalSold échoué :", tostring(err))
        return true
    end)
end

function BT:EncodeLastRoll(data)
    data = self:NormalizeLastRoll(data)
    if not data then return "" end
    local ok, json = pcall(util.TableToJSON, data, false)
    if not ok then return "" end
    return tostring(json or "")
end

function BT:DecodeLastRoll(raw)
    raw = tostring(raw or "")
    if raw == "" then return nil end
    local ok, data = pcall(util.JSONToTable, raw)
    if not ok or not istable(data) then return nil end
    return self:NormalizeLastRoll(data)
end

function BT:GetSteamID(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply.SteamID then return "" end
    return tostring(ply:SteamID() or ""):Trim()
end

function BT:GetCachedState(steamID)
    steamID = tostring(steamID or ""):Trim()
    if steamID == "" then return nil end
    return self._cache[steamID]
end

function BT:SetCachedState(steamID, state)
    steamID = tostring(steamID or ""):Trim()
    if steamID == "" then return end
    self._cache[steamID] = self:SanitizeSyncState(state)
end

function BT:ClearCachedState(steamID)
    steamID = tostring(steamID or ""):Trim()
    if steamID == "" then return end
    self._cache[steamID] = nil
end

function BT:AcquireBusy(steamID, key)
    steamID = tostring(steamID or ""):Trim()
    key = tostring(key or "default")
    if steamID == "" then return false end
    self._busy[steamID] = self._busy[steamID] or {}
    if self._busy[steamID][key] then return false end
    self._busy[steamID][key] = true
    return true
end

function BT:ReleaseBusy(steamID, key)
    steamID = tostring(steamID or ""):Trim()
    key = tostring(key or "default")
    local bySteamID = self._busy[steamID]
    if not bySteamID then return end
    bySteamID[key] = nil
    if not next(bySteamID) then self._busy[steamID] = nil end
end

function BT:BuildAccountFromRow(row, steamID)
    if not istable(row) then return self:GetDefaultAccount(steamID) end
    return self:NormalizeAccount({
        steamid = row.steamid,
        coins = row.coins,
        creator_code = row.creator_code,
        total_spent = row.total_spent,
        last_roll_type = row.last_roll_type,
        last_roll_payload = self:DecodeLastRoll(row.last_roll_payload),
        last_purchase_at = row.last_purchase_at,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }, steamID)
end

function BT:BuildEnsureAccountQuery(steamID)
    local ts = now()
    local tbl = self:GetAccountTableName()
    local coins = self:GetDefaultCoins()
    if DB:IsMySQL() then return ([[
            INSERT INTO %s
                (steamid, coins, creator_code, total_spent, last_roll_type, last_roll_payload, last_purchase_at, created_at, updated_at)
            VALUES
                (%s, %d, %s, 0, %s, %s, 0, %d, %d)
            ON DUPLICATE KEY UPDATE steamid = steamid
        ]]):format(tbl, esc(steamID), coins, esc(""), esc(""), esc(""), ts, ts) end
    return ([[
        INSERT OR IGNORE INTO %s
            (steamid, coins, creator_code, total_spent, last_roll_type, last_roll_payload, last_purchase_at, created_at, updated_at)
        VALUES
            (%s, %d, %s, 0, %s, %s, 0, %d, %d)
    ]]):format(tbl, esc(steamID), coins, esc(""), esc(""), esc(""), ts, ts)
end

function BT:BuildAccountUpdateQuery(account)
    account = self:NormalizeAccount(account or {})
    return ([[
        UPDATE %s
        SET
            coins = %d,
            creator_code = %s,
            total_spent = %d,
            last_roll_type = %s,
            last_roll_payload = %s,
            last_purchase_at = %d,
            updated_at = %d
        WHERE steamid = %s
    ]]):format(self:GetAccountTableName(), math.max(0, math.floor(tonumber(account.coins) or 0)), esc(account.creator_code or ""), math.max(0, math.floor(tonumber(account.total_spent) or 0)), esc(account.last_roll_type or ""), esc(self:EncodeLastRoll(account.last_roll_payload)), math.max(0, math.floor(tonumber(account.last_purchase_at) or 0)), math.max(0, math.floor(tonumber(account.updated_at) or 0)), esc(account.steamid or ""))
end

function BT:BuildItemSyncQuery(steamID, itemId, amount)
    steamID = tostring(steamID or ""):Trim()
    itemId = tostring(itemId or ""):Trim()
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return ("DELETE FROM %s WHERE steamid=%s AND item_id=%s"):format(self:GetItemsTableName(), esc(steamID), esc(itemId)) end
    local ts = now()
    if DB:IsMySQL() then return ([[
            INSERT INTO %s (steamid, item_id, amount, updated_at)
            VALUES (%s, %s, %d, %d)
            ON DUPLICATE KEY UPDATE amount = VALUES(amount), updated_at = VALUES(updated_at)
        ]]):format(self:GetItemsTableName(), esc(steamID), esc(itemId), amount, ts) end
    return ([[
        INSERT OR REPLACE INTO %s (steamid, item_id, amount, updated_at)
        VALUES (%s, %s, %d, %d)
    ]]):format(self:GetItemsTableName(), esc(steamID), esc(itemId), amount, ts)
end

function BT:RunQueries(queries, onSuccess, onError)
    queries = istable(queries) and queries or {}
    if #queries == 0 then
        if onSuccess then onSuccess() end
        return
    end

    if DB.TransactionP then
        DB:TransactionP(queries):Next(function() if onSuccess then onSuccess() end end):Catch(function(err) if onError then onError(err) end end)
        return
    end

    local index = 1
    local function runNext()
        local query = queries[index]
        if not query then
            if onSuccess then onSuccess() end
            return
        end

        DB:Query(query, function()
            index = index + 1
            runNext()
        end, function(err)
            if onError then onError(err) end
            return true
        end)
    end

    runNext()
end

function BT:WriteTransaction(steamID, txType, coinsDelta, itemId, payload)
    steamID = tostring(steamID or ""):Trim()
    if not self:IsValidSteamID(steamID) then return end
    txType = tostring(txType or "")
    coinsDelta = math.floor(tonumber(coinsDelta) or 0)
    itemId = tostring(itemId or "")
    local ts = now()
    local payloadJson = ""
    if istable(payload) then
        local ok, json = pcall(util.TableToJSON, payload, false)
        if ok then payloadJson = tostring(json or "") end
    end

    local tx = {
        id = ts,
        tx_type = txType,
        item_id = itemId,
        coins_delta = coinsDelta,
        payload = istable(payload) and payload or {},
        created_at = ts,
    }

    local state = self._cache[steamID]
    if state then
        local txs = state.transactions or {}
        table.insert(txs, 1, tx)
        while #txs > 25 do
            table.remove(txs)
        end

        state.transactions = txs
    end

    local q = ("INSERT INTO %s (steamid, tx_type, item_id, coins_delta, payload, created_at) VALUES (%s, %s, %s, %d, %s, %d)"):format(self:GetTransactionsTableName(), esc(steamID), esc(txType), esc(itemId), coinsDelta, esc(payloadJson), ts)
    DB:Query(q, nil, function(err)
        logErr("WriteTransaction failed:", tostring(err))
        return true
    end)
end

function BT:CreateTables()
    local tblAccounts = self:GetAccountTableName()
    local tblItems = self:GetItemsTableName()
    local q1
    local q2
    if DB:IsMySQL() then
        q1 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                steamid VARCHAR(32) NOT NULL PRIMARY KEY,
                coins INT NOT NULL DEFAULT 0,
                creator_code VARCHAR(24) NOT NULL DEFAULT '',
                total_spent INT NOT NULL DEFAULT 0,
                last_roll_type VARCHAR(32) NOT NULL DEFAULT '',
                last_roll_payload TEXT NOT NULL,
                last_purchase_at INT NOT NULL DEFAULT 0,
                created_at INT NOT NULL,
                updated_at INT NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(tblAccounts)
        q2 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT NOT NULL AUTO_INCREMENT,
                steamid VARCHAR(32) NOT NULL,
                item_id VARCHAR(64) NOT NULL,
                amount INT NOT NULL DEFAULT 0,
                updated_at INT NOT NULL,
                PRIMARY KEY (id),
                UNIQUE KEY uq_verse_boutique_item (steamid, item_id),
                KEY idx_verse_boutique_steamid (steamid)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(tblItems)
    else
        q1 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                steamid TEXT NOT NULL PRIMARY KEY,
                coins INTEGER NOT NULL DEFAULT 0,
                creator_code TEXT NOT NULL DEFAULT '',
                total_spent INTEGER NOT NULL DEFAULT 0,
                last_roll_type TEXT NOT NULL DEFAULT '',
                last_roll_payload TEXT NOT NULL DEFAULT '',
                last_purchase_at INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
        ]]):format(tblAccounts)
        q2 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                steamid TEXT NOT NULL,
                item_id TEXT NOT NULL,
                amount INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL,
                UNIQUE(steamid, item_id)
            )
        ]]):format(tblItems)
    end

    local tblTx = self:GetTransactionsTableName()
    local q3
    if DB:IsMySQL() then
        q3 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT NOT NULL AUTO_INCREMENT,
                steamid VARCHAR(32) NOT NULL,
                tx_type VARCHAR(32) NOT NULL DEFAULT '',
                item_id VARCHAR(64) NOT NULL DEFAULT '',
                coins_delta INT NOT NULL DEFAULT 0,
                payload TEXT NOT NULL,
                created_at INT NOT NULL,
                PRIMARY KEY (id),
                KEY idx_verse_boutique_tx_steamid (steamid)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(tblTx)
    else
        q3 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                steamid TEXT NOT NULL,
                tx_type TEXT NOT NULL DEFAULT '',
                item_id TEXT NOT NULL DEFAULT '',
                coins_delta INTEGER NOT NULL DEFAULT 0,
                payload TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL
            )
        ]]):format(tblTx)
    end

    DB:Query(q1, function() logInfo("Account table ready:", tblAccounts) end, function(err)
        logErr("Failed to create boutique account table:", tostring(err))
        return true
    end)

    DB:Query(q2, function() logInfo("Items table ready:", tblItems) end, function(err)
        logErr("Failed to create boutique item table:", tostring(err))
        return true
    end)

    DB:Query(q3, function() logInfo("Transactions table ready:", tblTx) end, function(err)
        logErr("Failed to create boutique transactions table:", tostring(err))
        return true
    end)

    local tblRarities = self:GetRaritiesTableName()
    local tblProducts = self:GetProductsTableName()
    local qR, qP
    if DB:IsMySQL() then
        qR = ([[CREATE TABLE IF NOT EXISTS %s (
            id VARCHAR(64) NOT NULL PRIMARY KEY,
            name VARCHAR(128) NOT NULL DEFAULT '',
            color_r INT NOT NULL DEFAULT 160,
            color_g INT NOT NULL DEFAULT 160,
            color_b INT NOT NULL DEFAULT 160
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(tblRarities)
        qP = ([[CREATE TABLE IF NOT EXISTS %s (
            id VARCHAR(64) NOT NULL PRIMARY KEY,
            name VARCHAR(128) NOT NULL DEFAULT '',
            category VARCHAR(32) NOT NULL DEFAULT 'rerolls',
            price INT NOT NULL DEFAULT 0,
            icon VARCHAR(128) NOT NULL DEFAULT '',
            icon_w INT NOT NULL DEFAULT 256,
            icon_h INT NOT NULL DEFAULT 256,
            preview_model VARCHAR(256) NOT NULL DEFAULT '',
            use_mode VARCHAR(64) NOT NULL DEFAULT '',
            use_text VARCHAR(64) NOT NULL DEFAULT 'Utiliser',
            purchase_text VARCHAR(64) NOT NULL DEFAULT 'Acheter',
            fallback_label VARCHAR(32) NOT NULL DEFAULT '',
            rarity VARCHAR(64) NOT NULL DEFAULT '',
            accent_r INT NOT NULL DEFAULT 171,
            accent_g INT NOT NULL DEFAULT 82,
            accent_b INT NOT NULL DEFAULT 255,
            weight INT NOT NULL DEFAULT 1,
            purchase_limit_local INT NOT NULL DEFAULT 0,
            purchase_limit_global INT NOT NULL DEFAULT 0,
            sort_order INT NOT NULL DEFAULT 0,
            enabled INT NOT NULL DEFAULT 1,
            display_type VARCHAR(32) NOT NULL DEFAULT 'icon'
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(tblProducts)
    else
        qR = ([[CREATE TABLE IF NOT EXISTS %s (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL DEFAULT '',
            color_r INTEGER NOT NULL DEFAULT 160,
            color_g INTEGER NOT NULL DEFAULT 160,
            color_b INTEGER NOT NULL DEFAULT 160
        )]]):format(tblRarities)
        qP = ([[CREATE TABLE IF NOT EXISTS %s (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL DEFAULT '',
            category TEXT NOT NULL DEFAULT 'rerolls',
            price INTEGER NOT NULL DEFAULT 0,
            icon TEXT NOT NULL DEFAULT '',
            icon_w INTEGER NOT NULL DEFAULT 256,
            icon_h INTEGER NOT NULL DEFAULT 256,
            preview_model TEXT NOT NULL DEFAULT '',
            use_mode TEXT NOT NULL DEFAULT '',
            use_text TEXT NOT NULL DEFAULT 'Utiliser',
            purchase_text TEXT NOT NULL DEFAULT 'Acheter',
            fallback_label TEXT NOT NULL DEFAULT '',
            rarity TEXT NOT NULL DEFAULT '',
            accent_r INTEGER NOT NULL DEFAULT 171,
            accent_g INTEGER NOT NULL DEFAULT 82,
            accent_b INTEGER NOT NULL DEFAULT 255,
            weight INTEGER NOT NULL DEFAULT 1,
            purchase_limit_local INTEGER NOT NULL DEFAULT 0,
            purchase_limit_global INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            enabled INTEGER NOT NULL DEFAULT 1,
            display_type TEXT NOT NULL DEFAULT 'icon'
        )]]):format(tblProducts)
    end

    DB:Query(qR, function()
        logInfo("Rarities table ready:", tblRarities)
        BT:LoadRarities()
    end, function(err)
        logErr("Failed to create rarities table:", tostring(err))
        return true
    end)

    DB:Query(qP, function()
        logInfo("Products table ready:", tblProducts)
        local altVid = DB:IsMySQL() and ("ALTER TABLE %s ADD COLUMN video_url VARCHAR(512) NOT NULL DEFAULT ''"):format(tblProducts) or ("ALTER TABLE %s ADD COLUMN video_url TEXT NOT NULL DEFAULT ''"):format(tblProducts)
        DB:Query(altVid, function() end, function() return true end)
        local altBanner = DB:IsMySQL() and ("ALTER TABLE %s ADD COLUMN banner_image VARCHAR(256) NOT NULL DEFAULT ''"):format(tblProducts) or ("ALTER TABLE %s ADD COLUMN banner_image TEXT NOT NULL DEFAULT ''"):format(tblProducts)
        DB:Query(altBanner, function() end, function() return true end)
        BT:LoadProducts()
    end, function(err)
        logErr("Failed to create products table:", tostring(err))
        return true
    end)

    local tblPool = self:GetRerollPoolTableName()
    local qPool
    if DB:IsMySQL() then
        qPool = ([[CREATE TABLE IF NOT EXISTS %s (
            id INT NOT NULL AUTO_INCREMENT,
            roll_type VARCHAR(32) NOT NULL DEFAULT 'occult',
            name VARCHAR(128) NOT NULL DEFAULT '',
            icon VARCHAR(256) NOT NULL DEFAULT '',
            result_icon VARCHAR(256) NOT NULL DEFAULT '',
            rarity VARCHAR(64) NOT NULL DEFAULT '',
            weight INT NOT NULL DEFAULT 1,
            reward_type VARCHAR(32) NOT NULL DEFAULT 'coins',
            reward_value VARCHAR(128) NOT NULL DEFAULT '0',
            video_url VARCHAR(512) NOT NULL DEFAULT '',
            sort_order INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(tblPool)
    else
        qPool = ([[CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            roll_type TEXT NOT NULL DEFAULT 'occult',
            name TEXT NOT NULL DEFAULT '',
            icon TEXT NOT NULL DEFAULT '',
            result_icon TEXT NOT NULL DEFAULT '',
            rarity TEXT NOT NULL DEFAULT '',
            weight INTEGER NOT NULL DEFAULT 1,
            reward_type TEXT NOT NULL DEFAULT 'coins',
            reward_value TEXT NOT NULL DEFAULT '0',
            video_url TEXT NOT NULL DEFAULT '',
            sort_order INTEGER NOT NULL DEFAULT 0
        )]]):format(tblPool)
    end

    DB:Query(qPool, function()
        logInfo("RerollPool table ready:", tblPool)
        local altVidPool = DB:IsMySQL() and ("ALTER TABLE %s ADD COLUMN video_url VARCHAR(512) NOT NULL DEFAULT ''"):format(tblPool) or ("ALTER TABLE %s ADD COLUMN video_url TEXT NOT NULL DEFAULT ''"):format(tblPool)
        DB:Query(altVidPool, function() end, function() return true end)
        local altResIcon = DB:IsMySQL() and ("ALTER TABLE %s ADD COLUMN result_icon VARCHAR(256) NOT NULL DEFAULT ''"):format(tblPool) or ("ALTER TABLE %s ADD COLUMN result_icon TEXT NOT NULL DEFAULT ''"):format(tblPool)
        DB:Query(altResIcon, function() end, function() return true end)
        BT:LoadRerollPool()
    end, function(err)
        logErr("Failed to create reroll pool table:", tostring(err))
        return true
    end)

    local tblCreators = self:GetCreatorsTableName()
    local tblCreatorEvents = self:GetCreatorEventsTableName()
    local qCreators, qCreatorEvents
    if DB:IsMySQL() then
        qCreators = ([[CREATE TABLE IF NOT EXISTS %s (
            id INT NOT NULL AUTO_INCREMENT,
            code VARCHAR(32) NOT NULL,
            owner_name VARCHAR(128) NOT NULL DEFAULT '',
            steamid VARCHAR(32) NOT NULL DEFAULT '',
            payout_rate INT NOT NULL DEFAULT 0,
            buyer_discount INT NOT NULL DEFAULT 0,
            enabled TINYINT NOT NULL DEFAULT 1,
            created_at INT NOT NULL DEFAULT 0,
            notes TEXT,
            bonus_type VARCHAR(16) NOT NULL DEFAULT 'coins',
            bonus_amount INT NOT NULL DEFAULT 0,
            bonus_item VARCHAR(64) NOT NULL DEFAULT '',
            bonus_rewards TEXT,
            PRIMARY KEY (id),
            UNIQUE KEY uq_creator_code (code)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(tblCreators)
        qCreatorEvents = ([[CREATE TABLE IF NOT EXISTS %s (
            id INT NOT NULL AUTO_INCREMENT,
            code VARCHAR(32) NOT NULL,
            steamid VARCHAR(32) NOT NULL,
            event_type VARCHAR(16) NOT NULL DEFAULT 'purchase',
            amount INT NOT NULL DEFAULT 0,
            product_id VARCHAR(64) NOT NULL DEFAULT '',
            at INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            KEY idx_creator_code (code),
            KEY idx_creator_steamid (steamid),
            KEY idx_creator_at (at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(tblCreatorEvents)
    else
        qCreators = ([[CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            owner_name TEXT NOT NULL DEFAULT '',
            steamid TEXT NOT NULL DEFAULT '',
            payout_rate INTEGER NOT NULL DEFAULT 0,
            buyer_discount INTEGER NOT NULL DEFAULT 0,
            enabled INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL DEFAULT 0,
            notes TEXT,
            bonus_type TEXT NOT NULL DEFAULT 'coins',
            bonus_amount INTEGER NOT NULL DEFAULT 0,
            bonus_item TEXT NOT NULL DEFAULT '',
            bonus_rewards TEXT
        )]]):format(tblCreators)
        qCreatorEvents = ([[CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            steamid TEXT NOT NULL,
            event_type TEXT NOT NULL DEFAULT 'purchase',
            amount INTEGER NOT NULL DEFAULT 0,
            product_id TEXT NOT NULL DEFAULT '',
            at INTEGER NOT NULL DEFAULT 0
        )]]):format(tblCreatorEvents)
    end

    DB:Query(qCreators, function()
        logInfo("Creators table ready:", tblCreators)
        local function altColCreators(col, def)
            local q = DB:IsMySQL() and ("ALTER TABLE %s ADD COLUMN %s"):format(tblCreators, def) or ("ALTER TABLE %s ADD COLUMN %s"):format(tblCreators, def)
            DB:Query(q, function() end, function() return true end)
        end

        altColCreators("bonus_type", DB:IsMySQL() and "bonus_type VARCHAR(16) NOT NULL DEFAULT 'coins'" or "bonus_type TEXT NOT NULL DEFAULT 'coins'")
        altColCreators("bonus_amount", DB:IsMySQL() and "bonus_amount INT NOT NULL DEFAULT 0" or "bonus_amount INTEGER NOT NULL DEFAULT 0")
        altColCreators("bonus_item", DB:IsMySQL() and "bonus_item VARCHAR(64) NOT NULL DEFAULT ''" or "bonus_item TEXT NOT NULL DEFAULT ''")
        altColCreators("bonus_rewards", "bonus_rewards TEXT")
        altColCreators("steamid", DB:IsMySQL() and "steamid VARCHAR(32) NOT NULL DEFAULT ''" or "steamid TEXT NOT NULL DEFAULT ''")
        altColCreators("buyer_discount", DB:IsMySQL() and "buyer_discount INT NOT NULL DEFAULT 0" or "buyer_discount INTEGER NOT NULL DEFAULT 0")
        BT:LoadCreators()
    end, function(err)
        logErr("Failed to create creators table:", tostring(err))
        return true
    end)

    DB:Query(qCreatorEvents, function() logInfo("CreatorEvents table ready:", tblCreatorEvents) end, function(err)
        logErr("Failed to create creator events table:", tostring(err))
        return true
    end)

    local tblCreatorLinks = self:GetCreatorLinksTableName()
    local qCreatorLinks
    if DB:IsMySQL() then
        qCreatorLinks = ([[CREATE TABLE IF NOT EXISTS %s (
            id INT NOT NULL AUTO_INCREMENT,
            code VARCHAR(32) NOT NULL,
            steamid VARCHAR(32) NOT NULL,
            bonus_amount INT NOT NULL DEFAULT 0,
            linked_at INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY uq_code_steamid (code, steamid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(tblCreatorLinks)
    else
        qCreatorLinks = ([[CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            steamid TEXT NOT NULL,
            bonus_amount INTEGER NOT NULL DEFAULT 0,
            linked_at INTEGER NOT NULL DEFAULT 0,
            UNIQUE(code, steamid)
        )]]):format(tblCreatorLinks)
    end

    DB:Query(qCreatorLinks, function() logInfo("CreatorLinks table ready:", tblCreatorLinks) end, function(err)
        logErr("Failed to create creator links table:", tostring(err))
        return true
    end)

    -- ── Table Pack Tenues ──────────────────────────────────────────────────────
    local tblPackTenue = tostring(self:GetConfigValue("TablePackTenue", "verse_boutique_packtenue"))
    local qPackTenue
    if DB:IsMySQL() then
        qPackTenue = ([[CREATE TABLE IF NOT EXISTS `%s` (
            `pack_id` VARCHAR(64) NOT NULL PRIMARY KEY,
            `data` TEXT NOT NULL DEFAULT '',
            `updated_at` INT NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(tblPackTenue)
    else
        qPackTenue = ([[CREATE TABLE IF NOT EXISTS `%s` (
            `pack_id` TEXT NOT NULL PRIMARY KEY,
            `data` TEXT NOT NULL DEFAULT '',
            `updated_at` INTEGER NOT NULL DEFAULT 0
        )]]):format(tblPackTenue)
    end

    DB:Query(qPackTenue, function()
        logInfo("PackTenue table ready:", tblPackTenue)
        -- Charger les packs maintenant que la table existe
        if isfunction(BT.LoadPackTenuePacks) then
            BT:LoadPackTenuePacks()
        end
    end, function(err)
        logErr("Failed to create pack tenue table:", tostring(err))
        return true
    end)
end

function BT:LoadRarities(callback)
    DB:Query(("SELECT * FROM %s"):format(self:GetRaritiesTableName()), function(rows)
        self.Rarities = {}
        for _, row in ipairs(rows or {}) do
            self.Rarities[#self.Rarities + 1] = {
                id = tostring(row.id or ""),
                name = tostring(row.name or ""),
                color_r = tonumber(row.color_r) or 160,
                color_g = tonumber(row.color_g) or 160,
                color_b = tonumber(row.color_b) or 160,
            }
        end

        self:RebuildDerivedData()
        if callback then callback() end
    end, function(err)
        logErr("LoadRarities failed:", tostring(err))
        return true
    end)
end

function BT:LoadProducts(callback)
    DB:Query(("SELECT * FROM %s ORDER BY sort_order ASC"):format(self:GetProductsTableName()), function(rows)
        self.Products = {}
        for _, row in ipairs(rows or {}) do
            local id = tostring(row.id or "")
            if id ~= "" then
                self.Products[id] = {
                    id = id,
                    name = tostring(row.name or ""),
                    category = tostring(row.category or "rerolls"),
                    price = tonumber(row.price) or 0,
                    icon = tostring(row.icon or ""),
                    icon_w = tonumber(row.icon_w) or 256,
                    icon_h = tonumber(row.icon_h) or 256,
                    video_url = tostring(row.video_url or ""),
                    banner_image = tostring(row.banner_image or ""),
                    use_mode = tostring(row.use_mode or ""),
                    use_text = tostring(row.use_text or "Utiliser"),
                    purchase_text = tostring(row.purchase_text or "Acheter"),
                    fallback_label = tostring(row.fallback_label or ""),
                    rarity = tostring(row.rarity or ""),
                    accent = Color(tonumber(row.accent_r) or 171, tonumber(row.accent_g) or 82, tonumber(row.accent_b) or 255),
                    accent_r = tonumber(row.accent_r) or 171,
                    accent_g = tonumber(row.accent_g) or 82,
                    accent_b = tonumber(row.accent_b) or 255,
                    weight = tonumber(row.weight) or 1,
                    purchase_limit_local = tonumber(row.purchase_limit_local) or 0,
                    purchase_limit_global = tonumber(row.purchase_limit_global) or 0,
                    sort_order = tonumber(row.sort_order) or 0,
                    enabled = tonumber(row.enabled) or 1,
                }
            end
        end

        self:RebuildDerivedData()
        if callback then callback() end
    end, function(err)
        logErr("LoadProducts failed:", tostring(err))
        return true
    end)
end

function BT:SaveProductToDB(p, callback)
    local tbl = self:GetProductsTableName()
    local q
    local banner = esc(p.banner_image or "")
    if DB:IsMySQL() then
        q = ([[INSERT INTO %s (id,name,category,price,icon,icon_w,icon_h,video_url,banner_image,use_mode,use_text,purchase_text,fallback_label,rarity,accent_r,accent_g,accent_b,weight,purchase_limit_local,purchase_limit_global,sort_order,enabled)
        VALUES (%s,%s,%s,%d,%s,%d,%d,%s,%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d)
        ON DUPLICATE KEY UPDATE name=%s,category=%s,price=%d,icon=%s,icon_w=%d,icon_h=%d,video_url=%s,banner_image=%s,use_mode=%s,use_text=%s,purchase_text=%s,fallback_label=%s,rarity=%s,accent_r=%d,accent_g=%d,accent_b=%d,weight=%d,purchase_limit_local=%d,purchase_limit_global=%d,sort_order=%d,enabled=%d]]):format(tbl, esc(p.id), esc(p.name), esc(p.category), p.price, esc(p.icon), p.icon_w, p.icon_h, esc(p.video_url or ""), banner, esc(p.use_mode), esc(p.use_text), esc(p.purchase_text), esc(p.fallback_label), esc(p.rarity), p.accent_r, p.accent_g, p.accent_b, p.weight, p.purchase_limit_local, p.purchase_limit_global, p.sort_order, p.enabled, esc(p.name), esc(p.category), p.price, esc(p.icon), p.icon_w, p.icon_h, esc(p.video_url or ""), banner, esc(p.use_mode), esc(p.use_text), esc(p.purchase_text), esc(p.fallback_label), esc(p.rarity), p.accent_r, p.accent_g, p.accent_b, p.weight, p.purchase_limit_local, p.purchase_limit_global, p.sort_order, p.enabled)
    else
        q = ([[INSERT OR REPLACE INTO %s (id,name,category,price,icon,icon_w,icon_h,video_url,banner_image,use_mode,use_text,purchase_text,fallback_label,rarity,accent_r,accent_g,accent_b,weight,purchase_limit_local,purchase_limit_global,sort_order,enabled)
        VALUES (%s,%s,%s,%d,%s,%d,%d,%s,%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d)]]):format(tbl, esc(p.id), esc(p.name), esc(p.category), p.price, esc(p.icon), p.icon_w, p.icon_h, esc(p.video_url or ""), banner, esc(p.use_mode), esc(p.use_text), esc(p.purchase_text), esc(p.fallback_label), esc(p.rarity), p.accent_r, p.accent_g, p.accent_b, p.weight, p.purchase_limit_local, p.purchase_limit_global, p.sort_order, p.enabled)
    end

    DB:Query(q, function() if callback then callback(true) end end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end

function BT:DeleteProductFromDB(productId, callback)
    local q = ("DELETE FROM %s WHERE id=%s"):format(self:GetProductsTableName(), esc(productId))
    DB:Query(q, function() if callback then callback(true) end end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end

function BT:SaveRarityToDB(r, callback)
    local tbl = self:GetRaritiesTableName()
    local q
    if DB:IsMySQL() then
        q = ([[INSERT INTO %s (id,name,color_r,color_g,color_b) VALUES (%s,%s,%d,%d,%d)
        ON DUPLICATE KEY UPDATE name=%s,color_r=%d,color_g=%d,color_b=%d]]):format(tbl, esc(r.id), esc(r.name), r.color_r, r.color_g, r.color_b, esc(r.name), r.color_r, r.color_g, r.color_b)
    else
        q = ([[INSERT OR REPLACE INTO %s (id,name,color_r,color_g,color_b) VALUES (%s,%s,%d,%d,%d)]]):format(tbl, esc(r.id), esc(r.name), r.color_r, r.color_g, r.color_b)
    end

    DB:Query(q, function() if callback then callback(true) end end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end

function BT:DeleteRarityFromDB(rarityId, callback)
    local q = ("DELETE FROM %s WHERE id=%s"):format(self:GetRaritiesTableName(), esc(rarityId))
    DB:Query(q, function() if callback then callback(true) end end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end

function BT:LoadRerollPool(callback)
    DB:Query(("SELECT * FROM %s ORDER BY sort_order ASC, id ASC"):format(self:GetRerollPoolTableName()), function(rows)
        self.RerollPool = {}
        for _, row in ipairs(rows or {}) do
            local entry = {
                id = math.floor(tonumber(row.id) or 0),
                roll_type = tostring(row.roll_type or ""),
                name = tostring(row.name or ""),
                icon = tostring(row.icon or ""),
                result_icon = tostring(row.result_icon or ""),
                rarity = tostring(row.rarity or ""),
                weight = math.max(1, math.floor(tonumber(row.weight) or 1)),
                reward_type = tostring(row.reward_type or "coins"),
                reward_value = tostring(row.reward_value or "0"),
                video_url = tostring(row.video_url or ""),
                sort_order = math.floor(tonumber(row.sort_order) or 0),
            }

            local rt = entry.roll_type
            if rt ~= "" then
                if not self.RerollPool[rt] then self.RerollPool[rt] = {} end
                self.RerollPool[rt][#self.RerollPool[rt] + 1] = entry
            end
        end

        if callback then callback() end
    end, function(err)
        logErr("LoadRerollPool failed:", tostring(err))
        return true
    end)
end

function BT:SavePoolEntryToDB(entry, callback)
    local tbl = self:GetRerollPoolTableName()
    local entryId = math.floor(tonumber(entry.id) or 0)
    local q
    if entryId > 0 then
        q = ("UPDATE %s SET roll_type=%s,name=%s,icon=%s,result_icon=%s,rarity=%s,weight=%d,reward_type=%s,reward_value=%s,video_url=%s,sort_order=%d WHERE id=%d"):format(tbl, esc(entry.roll_type), esc(entry.name), esc(entry.icon), esc(entry.result_icon or ""), esc(entry.rarity), entry.weight, esc(entry.reward_type), esc(entry.reward_value), esc(entry.video_url or ""), entry.sort_order, entryId)
    else
        q = ("INSERT INTO %s (roll_type,name,icon,result_icon,rarity,weight,reward_type,reward_value,video_url,sort_order) VALUES (%s,%s,%s,%s,%s,%d,%s,%s,%s,%d)"):format(tbl, esc(entry.roll_type), esc(entry.name), esc(entry.icon), esc(entry.result_icon or ""), esc(entry.rarity), entry.weight, esc(entry.reward_type), esc(entry.reward_value), esc(entry.video_url or ""), entry.sort_order)
    end

    DB:Query(q, function() if callback then callback(true) end end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end

function BT:DeletePoolEntryFromDB(entryId, callback)
    local q = ("DELETE FROM %s WHERE id=%d"):format(self:GetRerollPoolTableName(), math.floor(tonumber(entryId) or 0))
    DB:Query(q, function() if callback then callback(true) end end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end

BT.Creators = BT.Creators or {}
function BT:LoadCreators(callback)
    DB:Query(("SELECT * FROM %s ORDER BY id ASC"):format(self:GetCreatorsTableName()), function(rows)
        self.Creators = {}
        for _, row in ipairs(rows or {}) do
            local code = self:NormalizeCreatorCode(tostring(row.code or ""))
            if code ~= "" then
                local rewards = {}
                local rawRewards = tostring(row.bonus_rewards or "")
                if rawRewards ~= "" then
                    local ok, decoded = pcall(util.JSONToTable, rawRewards)
                    if ok and istable(decoded) then
                        for _, r in ipairs(decoded) do
                            if istable(r) then
                                rewards[#rewards + 1] = {
                                    type = tostring(r.type or "coins"),
                                    amount = math.max(0, math.floor(tonumber(r.amount) or 0)),
                                    item = tostring(r.item or ""),
                                }
                            end
                        end
                    end
                end

                if #rewards == 0 then
                    local legacyAmt = math.max(0, math.floor(tonumber(row.bonus_amount) or 0))
                    if legacyAmt > 0 then
                        rewards[#rewards + 1] = {
                            type = tostring(row.bonus_type or "coins"),
                            amount = legacyAmt,
                            item = tostring(row.bonus_item or ""),
                        }
                    end
                end

                self.Creators[code] = {
                    id = math.floor(tonumber(row.id) or 0),
                    code = code,
                    owner_name = tostring(row.owner_name or ""),
                    steamid = tostring(row.steamid or ""),
                    payout_rate = math.max(0, math.floor(tonumber(row.payout_rate) or 0)),
                    buyer_discount = math.min(99, math.max(0, math.floor(tonumber(row.buyer_discount) or 0))),
                    enabled = (tonumber(row.enabled) or 1) ~= 0,
                    created_at = math.floor(tonumber(row.created_at) or 0),
                    notes = tostring(row.notes or ""),
                    bonus_rewards = rewards,
                }
            end
        end

        if callback then callback() end
    end, function(err)
        logErr("LoadCreators failed:", tostring(err))
        return true
    end)
end

function BT:GetCreator(code)
    code = self:NormalizeCreatorCode(code)
    if code == "" then return nil end
    return self.Creators and self.Creators[code] or nil
end

function BT:SaveCreatorToDB(entry, callback)
    local tbl = self:GetCreatorsTableName()
    local entryId = math.floor(tonumber(entry.id) or 0)
    local rewards = {}
    if istable(entry.bonus_rewards) then
        for _, r in ipairs(entry.bonus_rewards) do
            if istable(r) then
                local t = tostring(r.type or "coins")
                if t ~= "coins" and t ~= "item" then t = "coins" end
                local amt = math.max(0, math.floor(tonumber(r.amount) or 0))
                local itm = tostring(r.item or "")
                if amt > 0 then
                    rewards[#rewards + 1] = {
                        type = t,
                        amount = amt,
                        item = itm
                    }
                end
            end
        end
    end

    local rewardsJson = util.TableToJSON(rewards) or "[]"
    local q
    if entryId > 0 then
        q = ("UPDATE %s SET code=%s,owner_name=%s,steamid=%s,payout_rate=%d,buyer_discount=%d,enabled=%d,notes=%s,bonus_rewards=%s WHERE id=%d"):format(tbl, esc(entry.code), esc(entry.owner_name or ""), esc(tostring(entry.steamid or "")), math.max(0, math.floor(tonumber(entry.payout_rate) or 0)), math.min(99, math.max(0, math.floor(tonumber(entry.buyer_discount) or 0))), entry.enabled and 1 or 0, esc(entry.notes or ""), esc(rewardsJson), entryId)
    else
        q = ("INSERT INTO %s (code,owner_name,steamid,payout_rate,buyer_discount,enabled,created_at,notes,bonus_rewards) VALUES (%s,%s,%s,%d,%d,%d,%d,%s,%s)"):format(tbl, esc(entry.code), esc(entry.owner_name or ""), esc(tostring(entry.steamid or "")), math.max(0, math.floor(tonumber(entry.payout_rate) or 0)), math.min(99, math.max(0, math.floor(tonumber(entry.buyer_discount) or 0))), entry.enabled and 1 or 0, now(), esc(entry.notes or ""), esc(rewardsJson))
    end

    DB:Query(q, function() if callback then callback(true) end end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end

function BT:DeleteCreatorFromDB(entryId, callback)
    local tbl = self:GetCreatorsTableName()
    local q = ("DELETE FROM %s WHERE id=%d"):format(tbl, math.floor(tonumber(entryId) or 0))
    DB:Query(q, function() if callback then callback(true) end end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end

function BT:LogCreatorEvent(code, steamID, eventType, amount, productId)
    code = self:NormalizeCreatorCode(code)
    if code == "" then return end
    local creator = self:GetCreator(code)
    if not creator or not creator.enabled then return end
    local tbl = self:GetCreatorEventsTableName()
    local amt = math.max(0, math.floor(tonumber(amount) or 0))
    local q = ("INSERT INTO %s (code,steamid,event_type,amount,product_id,at) VALUES (%s,%s,%s,%d,%s,%d)"):format(tbl, esc(code), esc(tostring(steamID or "")), esc(tostring(eventType or "purchase")), amt, esc(tostring(productId or "")), now())
    DB:Query(q, function() end, function(err)
        logErr("LogCreatorEvent failed:", tostring(err))
        return true
    end)
end

function BT:GetCreatorAggregateStats(callback)
    local evTbl = self:GetCreatorEventsTableName()
    local lnkTbl = self:GetCreatorLinksTableName()
    local out = {}
    local qEvents = ("SELECT code, COUNT(DISTINCT steamid) AS unique_players, COUNT(*) AS events_count, SUM(amount) AS total_amount, SUM(CASE WHEN event_type='roll' THEN 1 ELSE 0 END) AS rolls_count, SUM(CASE WHEN event_type='purchase' THEN 1 ELSE 0 END) AS purchases_count, MAX(at) AS last_activity FROM %s GROUP BY code"):format(evTbl)
    DB:Query(qEvents, function(rows)
        for _, row in ipairs(rows or {}) do
            local code = tostring(row.code or "")
            if code ~= "" then
                out[code] = {
                    code = code,
                    unique_players = math.floor(tonumber(row.unique_players) or 0),
                    events_count = math.floor(tonumber(row.events_count) or 0),
                    total_amount = math.floor(tonumber(row.total_amount) or 0),
                    rolls_count = math.floor(tonumber(row.rolls_count) or 0),
                    purchases_count = math.floor(tonumber(row.purchases_count) or 0),
                    links_count = 0,
                    last_activity = math.floor(tonumber(row.last_activity) or 0),
                }
            end
        end

        local qLinks = ("SELECT code, COUNT(DISTINCT steamid) AS links_count, COALESCE(SUM(bonus_amount),0) AS bonus_total, MAX(linked_at) AS last_link FROM %s GROUP BY code"):format(lnkTbl)
        DB:Query(qLinks, function(lrows)
            for _, row in ipairs(lrows or {}) do
                local code = tostring(row.code or "")
                if code ~= "" then
                    local entry = out[code] or {
                        code = code,
                        unique_players = 0,
                        events_count = 0,
                        total_amount = 0,
                        rolls_count = 0,
                        purchases_count = 0,
                        links_count = 0,
                        last_activity = 0,
                    }

                    entry.links_count = math.floor(tonumber(row.links_count) or 0)
                    if entry.unique_players < entry.links_count then entry.unique_players = entry.links_count end
                    local lastLink = math.floor(tonumber(row.last_link) or 0)
                    if lastLink > entry.last_activity then entry.last_activity = lastLink end
                    out[code] = entry
                end
            end

            if callback then callback(out) end
        end, function()
            if callback then callback(out) end
            return true
        end)
    end, function(err)
        logErr("GetCreatorAggregateStats failed:", tostring(err))
        if callback then callback({}) end
        return true
    end)
end

local function sinceForPeriod(period)
    period = tostring(period or "all")
    if period == "day" then return now() - 86400 end
    if period == "week" then return now() - 7 * 86400 end
    if period == "month" then return now() - 30 * 86400 end
    return 0
end

function BT:GetCreatorDetails(code, period, callback)
    code = self:NormalizeCreatorCode(code)
    if code == "" then
        if callback then callback(nil) end
        return
    end

    local tbl = self:GetCreatorEventsTableName()
    local lnkTbl = self:GetCreatorLinksTableName()
    local since = sinceForPeriod(period)
    local whereClause = ("WHERE code=%s AND at >= %d"):format(esc(code), since)
    local lnkWhere = ("WHERE code=%s AND linked_at >= %d"):format(esc(code), since)
    local details = {
        code = code,
        period = tostring(period or "all"),
        since = since,
        totals = {
            unique_players = 0,
            events = 0,
            amount = 0,
            rolls = 0,
            purchases = 0,
            links = 0,
            last_activity = 0
        },
        players = {},
        recent = {},
    }

    local qLinkCount = ("SELECT COUNT(DISTINCT steamid) AS links_count, MAX(linked_at) AS last_link FROM %s %s"):format(lnkTbl, lnkWhere)
    DB:Query(qLinkCount, function(lcRows)
        local lc = (lcRows or {})[1] or {}
        details.totals.links = math.floor(tonumber(lc.links_count) or 0)
        details.totals.unique_players = details.totals.links
        details.totals.last_activity = math.floor(tonumber(lc.last_link) or 0)
    end, function() return true end)

    local qTotals = ("SELECT COUNT(DISTINCT steamid) AS u, COUNT(*) AS e, COALESCE(SUM(amount),0) AS a, SUM(CASE WHEN event_type='roll' THEN 1 ELSE 0 END) AS r, SUM(CASE WHEN event_type='purchase' THEN 1 ELSE 0 END) AS p, MAX(at) AS la FROM %s %s"):format(tbl, whereClause)
    DB:Query(qTotals, function(totRows)
        local tr = (totRows or {})[1] or {}
        local eventPlayers = math.floor(tonumber(tr.u) or 0)
        if eventPlayers > details.totals.unique_players then details.totals.unique_players = eventPlayers end
        details.totals.events = math.floor(tonumber(tr.e) or 0)
        details.totals.amount = math.floor(tonumber(tr.a) or 0)
        details.totals.rolls = math.floor(tonumber(tr.r) or 0)
        details.totals.purchases = math.floor(tonumber(tr.p) or 0)
        local lastEvent = math.floor(tonumber(tr.la) or 0)
        if lastEvent > details.totals.last_activity then details.totals.last_activity = lastEvent end
        local playersMap = {}
        local qPlayers = ("SELECT steamid, COUNT(*) AS e, COALESCE(SUM(amount),0) AS a, SUM(CASE WHEN event_type='roll' THEN 1 ELSE 0 END) AS r, SUM(CASE WHEN event_type='purchase' THEN 1 ELSE 0 END) AS p, MAX(at) AS la FROM %s %s GROUP BY steamid ORDER BY a DESC LIMIT 100"):format(tbl, whereClause)
        DB:Query(qPlayers, function(playerRows)
            for _, pr in ipairs(playerRows or {}) do
                local sid = tostring(pr.steamid or "")
                if sid ~= "" then
                    playersMap[sid] = {
                        steamid = sid,
                        events = math.floor(tonumber(pr.e) or 0),
                        amount = math.floor(tonumber(pr.a) or 0),
                        rolls = math.floor(tonumber(pr.r) or 0),
                        purchases = math.floor(tonumber(pr.p) or 0),
                        last_activity = math.floor(tonumber(pr.la) or 0),
                        linked = false,
                        link_bonus = 0,
                        linked_at = 0,
                    }
                end
            end

            local qLinks = ("SELECT steamid, bonus_amount, linked_at FROM %s %s ORDER BY linked_at DESC LIMIT 100"):format(lnkTbl, lnkWhere)
            DB:Query(qLinks, function(linkRows)
                for _, lr in ipairs(linkRows or {}) do
                    local sid = tostring(lr.steamid or "")
                    if sid ~= "" then
                        local bonus = math.max(0, math.floor(tonumber(lr.bonus_amount) or 0))
                        local lat = math.floor(tonumber(lr.linked_at) or 0)
                        local entry = playersMap[sid]
                        if not entry then
                            entry = {
                                steamid = sid,
                                events = 0,
                                amount = 0,
                                rolls = 0,
                                purchases = 0,
                                last_activity = 0,
                            }

                            playersMap[sid] = entry
                        end

                        entry.linked = true
                        entry.link_bonus = bonus
                        entry.linked_at = lat
                        if lat > entry.last_activity then entry.last_activity = lat end
                    end
                end

                for _, p in pairs(playersMap) do
                    details.players[#details.players + 1] = p
                end

                table.sort(details.players, function(a, b)
                    if a.amount ~= b.amount then return a.amount > b.amount end
                    return a.last_activity > b.last_activity
                end)

                while #details.players > 50 do
                    table.remove(details.players)
                end

                local qRecent = ("SELECT steamid,event_type,amount,product_id,at FROM %s %s ORDER BY at DESC LIMIT 50"):format(tbl, whereClause)
                DB:Query(qRecent, function(recentRows)
                    for _, er in ipairs(recentRows or {}) do
                        details.recent[#details.recent + 1] = {
                            steamid = tostring(er.steamid or ""),
                            event_type = tostring(er.event_type or ""),
                            amount = math.floor(tonumber(er.amount) or 0),
                            product_id = tostring(er.product_id or ""),
                            at = math.floor(tonumber(er.at) or 0),
                        }
                    end

                    if callback then callback(details) end
                end, function(err)
                    logErr("GetCreatorDetails recent failed:", tostring(err))
                    if callback then callback(details) end
                    return true
                end)
            end, function(err)
                logErr("GetCreatorDetails links failed:", tostring(err))
                if callback then callback(details) end
                return true
            end)
        end, function(err)
            logErr("GetCreatorDetails players failed:", tostring(err))
            if callback then callback(details) end
            return true
        end)
    end, function(err)
        logErr("GetCreatorDetails totals failed:", tostring(err))
        if callback then callback(nil) end
        return true
    end)
end

function BT:ExportCreatorEventsCSV(code, period, callback)
    code = self:NormalizeCreatorCode(code)
    if code == "" then
        if callback then callback(false, "bad_code") end
        return
    end

    local tbl = self:GetCreatorEventsTableName()
    local since = sinceForPeriod(period)
    local q = ("SELECT steamid,event_type,amount,product_id,at FROM %s WHERE code=%s AND at >= %d ORDER BY at ASC"):format(tbl, esc(code), since)
    DB:Query(q, function(rows)
        local lines = {"steamid,event_type,amount,product_id,at,at_iso"}
        for _, r in ipairs(rows or {}) do
            local at = math.floor(tonumber(r.at) or 0)
            lines[#lines + 1] = string.format('%s,%s,%d,%s,%d,"%s"', tostring(r.steamid or ""), tostring(r.event_type or ""), math.floor(tonumber(r.amount) or 0), tostring(r.product_id or ""):gsub(",", "_"), at, at > 0 and os.date("%Y-%m-%d %H:%M:%S", at) or "")
        end

        local body = table.concat(lines, "\n")
        local dir = "verse/boutique_exports"
        file.CreateDir(dir)
        local filename = string.format("%s/creator_%s_%s_%d.csv", dir, code, tostring(period or "all"), now())
        local ok = pcall(file.Write, filename, body)
        if callback then callback(ok, filename, #(rows or {})) end
    end, function(err)
        logErr("ExportCreatorEventsCSV failed:", tostring(err))
        if callback then callback(false, tostring(err)) end
        return true
    end)
end

function BT:BroadcastProductsAndRarities()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then BT:SyncPlayer(ply) end
    end
end

function BT:LoadStateBySteamID(steamID, callback)
    steamID = tostring(steamID or ""):Trim()
    if not self:IsValidSteamID(steamID) then
        if callback then callback(false, "invalid_steamid") end
        return
    end

    local fail = function(err)
        if callback then callback(false, err) end
        return true
    end

    local tblAccount = self:GetAccountTableName()
    local tblItems = self:GetItemsTableName()
    local tblTx = self:GetTransactionsTableName()
    local _self = self
    local function parseItems(rows)
        local items = {}
        for _, row in ipairs(rows or {}) do
            local id = tostring(row.item_id or ""):Trim()
            local amt = math.max(0, math.floor(tonumber(row.amount) or 0))
            if id ~= "" and amt > 0 then items[id] = amt end
        end
        return items
    end

    local function parseTx(rows)
        local out = {}
        for _, row in ipairs(rows or {}) do
            local decoded = {}
            local raw = tostring(row.payload or "")
            if raw ~= "" then
                local ok, d = pcall(util.JSONToTable, raw)
                if ok and istable(d) then decoded = d end
            end

            out[#out + 1] = {
                id = math.floor(tonumber(row.id) or 0),
                tx_type = tostring(row.tx_type or ""),
                item_id = tostring(row.item_id or ""),
                coins_delta = math.floor(tonumber(row.coins_delta) or 0),
                payload = decoded,
                created_at = math.floor(tonumber(row.created_at) or 0),
            }
        end
        return out
    end

    DB:Query(_self:BuildEnsureAccountQuery(steamID), function()
        DB:Query(("SELECT * FROM %s WHERE steamid=%s LIMIT 1"):format(tblAccount, esc(steamID)), function(accRows)
            local account = _self:BuildAccountFromRow((accRows or {})[1], steamID)
            DB:Query(("SELECT item_id, amount FROM %s WHERE steamid=%s"):format(tblItems, esc(steamID)), function(itemRows)
                local items = parseItems(itemRows)
                DB:Query(("SELECT id,tx_type,item_id,coins_delta,payload,created_at FROM %s WHERE steamid=%s ORDER BY created_at DESC LIMIT 25"):format(tblTx, esc(steamID)), function(txRows)
                    if callback then
                        callback(true, {
                            account = account,
                            items = items,
                            transactions = parseTx(txRows)
                        })
                    end
                end, function()
                    if callback then
                        callback(true, {
                            account = account,
                            items = items,
                            transactions = {}
                        })
                    end
                    return true
                end)
            end, fail)
        end, fail)
    end, fail)
end

function BT:PersistState(steamID, state, changedItems, callback)
    steamID = tostring(steamID or ""):Trim()
    state = self:SanitizeSyncState(state)
    state.account.steamid = steamID
    local queries = {self:BuildAccountUpdateQuery(state.account)}
    if changedItems == true then
        changedItems = {}
        for itemId in pairs(state.items or {}) do
            changedItems[itemId] = true
        end
    end

    if istable(changedItems) then
        for itemId in pairs(changedItems) do
            queries[#queries + 1] = self:BuildItemSyncQuery(steamID, itemId, state.items[itemId] or 0)
        end
    end

    self:RunQueries(queries, function() if callback then callback(true) end end, function(err) if callback then callback(false, err) end end)
end

function BT:FindOnlinePlayerBySteamID(steamID)
    steamID = tostring(steamID or ""):Trim()
    if steamID == "" then return nil end
    for _, ply in ipairs(player.GetAll()) do
        if self:GetSteamID(ply) == steamID then return ply end
    end
    return nil
end

function BT:SyncPlayer(ply)
    if not IsValid(ply) then return end
    local steamID = self:GetSteamID(ply)
    local state = self:GetCachedState(steamID)
    if not state then return end
    local syncData = self:SanitizeSyncState(state)
    syncData.products = self.Products or {}
    syncData.rarities = self.Rarities or {}
    syncData.reroll_pool = self.RerollPool or {}
    syncData.pack_tenue_packs = self.PackTenuePacks or {}
    local _cc = state.account and state.account.creator_code or ""
    local _cr = _cc ~= "" and self:GetCreator(_cc) or nil
    syncData.creator_discount = (_cr and _cr.buyer_discount) or 0
    netstream.Start(ply, self.Net.Sync, syncData)
end

function BT:LoadPlayer(ply, callback)
    if not IsValid(ply) then
        if callback then callback(false, "invalid_player") end
        return
    end

    local steamID = self:GetSteamID(ply)
    if not self:IsValidSteamID(steamID) then
        if callback then callback(false, "invalid_steamid") end
        return
    end

    self:LoadStateBySteamID(steamID, function(ok, stateOrErr)
        if not ok then
            if callback then callback(false, stateOrErr) end
            return
        end

        self:SetCachedState(steamID, stateOrErr)
        if IsValid(ply) then self:SyncPlayer(ply) end
        if callback then callback(true, self:GetCachedState(steamID)) end
    end)
end

function BT:WithPlayerState(ply, callback)
    if not IsValid(ply) then
        callback(false, "invalid_player")
        return
    end

    local steamID = self:GetSteamID(ply)
    local cached = self:GetCachedState(steamID)
    if cached then
        callback(true, cached)
        return
    end

    self:LoadPlayer(ply, function(ok, stateOrErr) callback(ok, stateOrErr) end)
end

function BT:AddCoinsBySteamID(steamID, amount, reason, callback)
    steamID = tostring(steamID or ""):Trim()
    amount = math.floor(tonumber(amount) or 0)
    if not self:IsValidSteamID(steamID) then
        if callback then callback(false, "invalid_steamid") end
        return
    end

    if amount == 0 then
        if callback then callback(false, "bad_amount") end
        return
    end

    self:LoadStateBySteamID(steamID, function(ok, stateOrErr)
        if not ok then
            if callback then callback(false, stateOrErr) end
            return
        end

        local state = self:SanitizeSyncState(stateOrErr)
        state.account.coins = math.max(0, state.account.coins + amount)
        state.account.updated_at = now()
        self:PersistState(steamID, state, nil, function(saveOk, saveErr)
            if not saveOk then
                if callback then callback(false, saveErr) end
                return
            end

            local targetPly = self:FindOnlinePlayerBySteamID(steamID)
            self:SetCachedState(steamID, state)
            self:WriteTransaction(steamID, "coins_add", amount, "", {
                reason = tostring(reason or "")
            })

            if IsValid(targetPly) then
                self:SyncPlayer(targetPly)
                if isfunction(targetPly.Notify) then
                    local sign = amount > 0 and "+" or ""
                    targetPly:Notify(sign .. amount .. " coins", NOTIFY_HINT, 4)
                end
            end

            if callback then callback(true, state.account.coins, reason) end
        end)
    end)
end

function BT:HasBeenRewardedForCreator(code, steamID, callback)
    code = self:NormalizeCreatorCode(code)
    steamID = tostring(steamID or "")
    if code == "" or steamID == "" then
        if callback then callback(false) end
        return
    end

    local q = ("SELECT id FROM %s WHERE code=%s AND steamid=%s LIMIT 1"):format(self:GetCreatorLinksTableName(), esc(code), esc(steamID))
    DB:Query(q, function(rows) if callback then callback(rows and rows[1] ~= nil) end end, function()
        if callback then callback(false) end
        return true
    end)
end

function BT:RecordCreatorLink(code, steamID, bonusAmount, callback)
    code = self:NormalizeCreatorCode(code)
    steamID = tostring(steamID or "")
    if code == "" or steamID == "" then
        if callback then callback(false) end
        return
    end

    local q
    if DB:IsMySQL() then
        q = ("INSERT IGNORE INTO %s (code,steamid,bonus_amount,linked_at) VALUES (%s,%s,%d,%d)"):format(self:GetCreatorLinksTableName(), esc(code), esc(steamID), math.max(0, math.floor(bonusAmount or 0)), now())
    else
        q = ("INSERT OR IGNORE INTO %s (code,steamid,bonus_amount,linked_at) VALUES (%s,%s,%d,%d)"):format(self:GetCreatorLinksTableName(), esc(code), esc(steamID), math.max(0, math.floor(bonusAmount or 0)), now())
    end

    DB:Query(q, function() if callback then callback(true) end end, function()
        if callback then callback(false) end
        return true
    end)
end

function BT:SaveCreatorCode(ply, code, callback)
    local normalized = self:NormalizeCreatorCode(code)
    if normalized ~= "" and not self:GetCreator(normalized) then
        if callback then callback(false, "unknown_code") end
        if IsValid(ply) and isfunction(ply.Notify) then ply:Notify("Ce code créateur n'existe pas.", NOTIFY_ERROR, 5) end
        return
    end

    local steamID = self:GetSteamID(ply)
    if not self:AcquireBusy(steamID, "creator_code") then
        if callback then callback(false, "busy") end
        return
    end

    self:WithPlayerState(ply, function(ok, stateOrErr)
        if not ok then
            self:ReleaseBusy(steamID, "creator_code")
            if callback then callback(false, stateOrErr) end
            return
        end

        local state    = self:SanitizeSyncState(stateOrErr)
        local wasEmpty = tostring(state.account.creator_code or "") == ""
        local oldCode  = tostring(state.account.creator_code or "")
        state.account.creator_code = normalized
        state.account.updated_at   = now()
        local function finalize()
            self:PersistState(steamID, state, nil, function(saveOk, saveErr)
                self:ReleaseBusy(steamID, "creator_code")
                if not saveOk then
                    if callback then callback(false, saveErr) end
                    return
                end

                self:SetCachedState(steamID, state)
                self:SyncPlayer(ply)
                if callback then callback(true, state.account.creator_code) end
            end)
        end

        if normalized == "" then
            if not wasEmpty and IsValid(ply) and isfunction(ply.Notify) then ply:Notify("Code créateur retiré de votre compte.", NOTIFY_HINT, 4) end
            finalize()
            return
        end

        if normalized == oldCode then
            if IsValid(ply) and isfunction(ply.Notify) then ply:Notify("Ce code est déjà lié à votre compte.", NOTIFY_HINT, 4) end
            finalize()
            return
        end

        self:HasBeenRewardedForCreator(normalized, steamID, function(already)
            if already then
                if IsValid(ply) and isfunction(ply.Notify) then
                    local creator = self:GetCreator(normalized) or {}
                    local display = normalized
                    if creator.owner_name and creator.owner_name ~= "" then display = normalized .. " (" .. creator.owner_name .. ")" end
                    ply:Notify("Compte relié au code " .. display .. ". Récompense déjà reçue précédemment.", NOTIFY_HINT, 6)
                end

                finalize()
                return
            end

            local creator = self:GetCreator(normalized) or {}
            local rewards = istable(creator.bonus_rewards) and creator.bonus_rewards or {}
            local totalApplied = 0
            local msgParts = {}
            for _, r in ipairs(rewards) do
                local rt = tostring(r.type or "coins")
                local amt = math.max(0, math.floor(tonumber(r.amount) or 0))
                if amt > 0 then
                    if rt == "item" then
                        local itemId = tostring(r.item or "")
                        if itemId ~= "" then
                            local prod = self:GetProduct(itemId)
                            if prod then
                                state.items = state.items or {}
                                state.items[itemId] = math.max(0, (state.items[itemId] or 0) + amt)
                                totalApplied = totalApplied + amt
                                msgParts[#msgParts + 1] = "+" .. amt .. "x " .. tostring(prod.name or itemId)
                            end
                        end
                    elseif rt == "coins" then
                        state.account.coins = math.max(0, (state.account.coins or 0) + amt)
                        totalApplied = totalApplied + amt
                        msgParts[#msgParts + 1] = "+" .. amt .. " coins"
                    end
                end
            end

            self:RecordCreatorLink(normalized, steamID, totalApplied, function()
                if IsValid(ply) and isfunction(ply.Notify) then
                    local creatorDisplay = normalized
                    if creator.owner_name and creator.owner_name ~= "" then creatorDisplay = normalized .. " (" .. creator.owner_name .. ")" end
                    if #msgParts > 0 then
                        ply:Notify("Code " .. creatorDisplay .. " activé · Récompense : " .. table.concat(msgParts, ", "), NOTIFY_HINT, 7)
                    else
                        ply:Notify("Code " .. creatorDisplay .. " lié à votre compte.", NOTIFY_HINT, 5)
                    end
                end

                finalize()
            end)
        end)
    end)
end

function BT:PurchaseProduct(ply, productId, amount, callback)
    if not IsValid(ply) then
        if callback then callback(false, "invalid_player") end
        return
    end

    local steamID = self:GetSteamID(ply)
    local product = self:GetProduct(productId)
    amount = math.Clamp(math.floor(tonumber(amount) or 1), 1, 99)
    if not product then
        if callback then callback(false, "invalid_product") end
        return
    end

    if not self:AcquireBusy(steamID, "purchase") then
        if callback then callback(false, "busy") end
        return
    end

    self:WithPlayerState(ply, function(ok, stateOrErr)
        if not ok then
            self:ReleaseBusy(steamID, "purchase")
            if callback then callback(false, stateOrErr) end
            return
        end

        local state = self:SanitizeSyncState(stateOrErr)
        local totalCost = math.max(0, math.floor(tonumber(product.price) or 0)) * amount
        if totalCost <= 0 then
            self:ReleaseBusy(steamID, "purchase")
            if callback then callback(false, "bad_cost") end
            return
        end

        if state.account.coins < totalCost then
            self:ReleaseBusy(steamID, "purchase")
            if callback then callback(false, "not_enough_coins") end
            return
        end

        -- Vérification purchase_limit_global (limite totale toutes steamids)
        local limitGlobal = math.floor(tonumber(product.purchase_limit_global) or 0)
        if limitGlobal > 0 then
            local alreadySold = math.floor(tonumber(BT._globalSold[product.id]) or 0)
            if alreadySold + amount > limitGlobal then
                amount = limitGlobal - alreadySold
                if amount <= 0 then
                    self:ReleaseBusy(steamID, "purchase")
                    if callback then callback(false, "global_limit_reached") end
                    if IsValid(ply) and isfunction(ply.Notify) then ply:Notify("Stock épuisé pour cet article.", NOTIFY_ERROR, 4) end
                    return
                end
                totalCost = math.max(0, math.floor(tonumber(product.price) or 0)) * amount
                if state.account.coins < totalCost then
                    self:ReleaseBusy(steamID, "purchase")
                    if callback then callback(false, "not_enough_coins") end
                    return
                end
            end
        end

        -- Vérification purchase_limit_local (limite par joueur)
        local limitLocal = math.floor(tonumber(product.purchase_limit_local) or 0)
        if limitLocal > 0 then
            local alreadyOwned = math.floor(tonumber(state.items[product.id]) or 0)
            if alreadyOwned + amount > limitLocal then
                amount = limitLocal - alreadyOwned
                if amount <= 0 then
                    self:ReleaseBusy(steamID, "purchase")
                    if callback then callback(false, "purchase_limit_reached") end
                    if IsValid(ply) and isfunction(ply.Notify) then ply:Notify("Limite d'achat atteinte pour cet article.", NOTIFY_ERROR, 4) end
                    return
                end
                -- Ajuste le coût si la quantité a été réduite
                totalCost = math.max(0, math.floor(tonumber(product.price) or 0)) * amount
                if state.account.coins < totalCost then
                    self:ReleaseBusy(steamID, "purchase")
                    if callback then callback(false, "not_enough_coins") end
                    return
                end
            end
        end

        if state.account.creator_code and state.account.creator_code ~= "" then
            local _discCreator = BT:GetCreator(state.account.creator_code)
            if _discCreator and (_discCreator.buyer_discount or 0) > 0 then
                local _discAmt = math.floor(totalCost * _discCreator.buyer_discount / 100)
                totalCost = math.max(1, totalCost - _discAmt)
            end
        end

        state.account.coins            = math.max(0, state.account.coins - totalCost)
        state.account.total_spent      = math.max(0, state.account.total_spent + totalCost)
        state.account.last_purchase_at = now()
        state.account.updated_at       = state.account.last_purchase_at
        state.items[product.id]        = math.max(0, (state.items[product.id] or 0) + amount)
        self:PersistState(steamID, state, {
            [product.id] = true
        }, function(saveOk, saveErr)
            self:ReleaseBusy(steamID, "purchase")
            if not saveOk then
                if callback then callback(false, saveErr) end
                return
            end

            self:SetCachedState(steamID, state)
            -- Incrémente le compteur global de ventes
            BT._globalSold[product.id] = (BT._globalSold[product.id] or 0) + amount
            self:WriteTransaction(steamID, "purchase", -totalCost, product.id, {
                name = product.name,
                amount = amount,
            })

            if state.account.creator_code and state.account.creator_code ~= "" then
                self:LogCreatorEvent(state.account.creator_code, steamID, "purchase", totalCost, product.id)
                local _creator = BT:GetCreator(state.account.creator_code)
                if _creator and _creator.steamid ~= "" and _creator.payout_rate > 0 then
                    local _payout = math.max(1, math.floor(totalCost * _creator.payout_rate / 100))
                    BT:AddCoinsBySteamID(_creator.steamid, _payout, "creator_payout:" .. _creator.code)
                end
            end
            self:SyncPlayer(ply)
            if isfunction(ply.Notify) then ply:Notify(product.name .. " x" .. amount .. " achete", NOTIFY_HINT, 4) end
            if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Boutique::ProductPurchased", ply, product, amount, self:SanitizeSyncState(state)) end
            if callback then callback(true, self:SanitizeSyncState(state), product, amount) end
        end)
    end)
end

function BT:PickWeighted(pool)
    if not istable(pool) or #pool == 0 then return nil end
    local totalWeight = 0
    for i = 1, #pool do
        totalWeight = totalWeight + math.max(0, tonumber(pool[i].weight) or 0)
    end

    if totalWeight <= 0 then return pool[math.random(#pool)] end
    local roll = math.Rand(0, totalWeight)
    local cursor = 0
    for i = 1, #pool do
        cursor = cursor + math.max(0, tonumber(pool[i].weight) or 0)
        if roll <= cursor then return pool[i] end
    end
    return pool[#pool]
end

function BT:UseOwnedItem(ply, itemId, callback)
    if not IsValid(ply) then
        if callback then callback(false, "invalid_player") end
        return
    end

    itemId = tostring(itemId or ""):Trim()
    if itemId == "" then
        if callback then callback(false, "invalid_item") end
        return
    end

    local steamID = self:GetSteamID(ply)
    local product = self:GetProduct(itemId)
    if not product then
        if callback then callback(false, "invalid_product") end
        return
    end

    if product.use_mode == "open_occult_page" or product.use_mode == "open_heritage_page" or product.use_mode == "open_martial_page" then
        if callback then callback(true, "page_only") end
        return
    end

    -- Reroll Pouvoir Maudit : traite directement ici sans attendre le flux standard
    if product.use_mode == "cursed_reroll" then
        local ST = VERSE.SkillTree
        if not ST or not isfunction(ST.PerformCursedRerollForced) then
            if callback then callback(false, "missing_executor") end
            return
        end
        if not self:AcquireBusy(steamID, "use_" .. itemId) then
            if callback then callback(false, "busy") end
            return
        end
        self:WithPlayerState(ply, function(ok, stateOrErr)
            if not ok then
                self:ReleaseBusy(steamID, "use_" .. itemId)
                if callback then callback(false, stateOrErr) end
                return
            end
            local state = self:SanitizeSyncState(stateOrErr)
            local currentAmount = math.max(0, state.items[itemId] or 0)
            if currentAmount <= 0 then
                self:ReleaseBusy(steamID, "use_" .. itemId)
                if callback then callback(false, "not_owned") end
                return
            end
            -- Consomme l'item boutique
            state.items[itemId] = currentAmount - 1
            state.account.updated_at = now()
            self:PersistState(steamID, state, { [itemId] = true }, function(saveOk, saveErr)
                self:ReleaseBusy(steamID, "use_" .. itemId)
                if not saveOk then
                    if callback then callback(false, saveErr) end
                    return
                end
                self:SetCachedState(steamID, state)
                -- Declenche le reroll skill tree (sans ticket meta)
                ST:PerformCursedRerollForced(ply, function(rollOk, chosenOrErr)
                    local payload = {
                        kind = "cursed_reroll",
                        id = itemId,
                        name = product.name or "Reroll Pouvoir Maudit",
                        rarity = "epic",
                        result = rollOk and tostring(chosenOrErr or "") or "",
                        at = now(),
                    }
                    self:WriteTransaction(steamID, "use_item", 0, itemId, payload)
                    self:SyncPlayer(ply)
                    netstream.Start(ply, self.Net.RollResult, payload.kind, payload)
                    if not rollOk then
                        if isfunction(ply.Notify) then ply:Notify("Reroll impossible : " .. tostring(chosenOrErr or "erreur"), NOTIFY_ERROR, 4) end
                    else
                        if isfunction(ply.Notify) then ply:Notify(payload.name .. " : Pouvoir assigné !", NOTIFY_HINT, 4) end
                    end
                    if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Boutique::ItemUsed", ply, product, payload, self:SanitizeSyncState(state)) end
                    if callback then callback(rollOk, rollOk and payload or chosenOrErr) end
                end)
            end)
        end)
        return
    end

    if not self:AcquireBusy(steamID, "use_" .. itemId) then
        if callback then callback(false, "busy") end
        return
    end

    self:WithPlayerState(ply, function(ok, stateOrErr)
        if not ok then
            self:ReleaseBusy(steamID, "use_" .. itemId)
            if callback then callback(false, stateOrErr) end
            return
        end

        local state = self:SanitizeSyncState(stateOrErr)
        local currentAmount = math.max(0, state.items[itemId] or 0)
        if currentAmount <= 0 then
            self:ReleaseBusy(steamID, "use_" .. itemId)
            if callback then callback(false, "not_owned") end
            return
        end

        state.items[itemId] = currentAmount - 1
        state.account.updated_at = now()
        local payload
        if product.use_mode == "reset_skilltree" then
            local ST = VERSE.SkillTree
            if ST and isfunction(ST.AdminResetTree) then
                ST:AdminResetTree(ply, function(ok, err)
                    if not ok then
                        if IsValid(ply) and ply.Notify then
                            ply:Notify("Erreur lors du reset de l'arbre : " .. tostring(err), NOTIFY_ERROR, 5)
                        end
                    else
                        if IsValid(ply) and ply.Notify then
                            ply:Notify("Arbre de compétences réinitialisé ! Vos points ont été remboursés.", NOTIFY_HINT, 6)
                        end
                    end
                end)
            end
            payload = {
                kind = "reset_points",
                id = itemId,
                name = tostring(product.name or "Reset Arbre"),
                rarity = "epic",
                at = now(),
            }
        elseif product.use_mode == "open_pack" then
            local packPool = (self.PackOpenPools and self.PackOpenPools[itemId]) or {}
            local reward = self:PickWeighted(packPool)
            payload = {
                kind = "pack",
                id = reward and tostring(reward.name or itemId) or itemId,
                name = reward and tostring(reward.name or product.name) or product.name,
                rarity = reward and tostring(reward.rarity or "common") or "common",
                at = now(),
            }
        else
            payload = {
                kind = "generic",
                id = itemId,
                name = product.name,
                rarity = "common",
                at = now(),
            }
        end

        state.account.last_roll_type = payload.kind
        state.account.last_roll_payload = payload
        self:PersistState(steamID, state, {
            [itemId] = true
        }, function(saveOk, saveErr)
            self:ReleaseBusy(steamID, "use_" .. itemId)
            if not saveOk then
                if callback then callback(false, saveErr) end
                return
            end

            self:SetCachedState(steamID, state)
            self:WriteTransaction(steamID, "use_item", 0, itemId, payload)
            self:SyncPlayer(ply)
            netstream.Start(ply, self.Net.RollResult, payload.kind, payload)
            if isfunction(ply.Notify) then ply:Notify(payload.name, NOTIFY_HINT, 4) end
            if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Boutique::ItemUsed", ply, product, payload, self:SanitizeSyncState(state)) end
            if callback then callback(true, payload) end
        end)
    end)
end

function BT:DoRoll(ply, rollKind, callback)
    if not IsValid(ply) then
        if callback then callback(false, "invalid_player") end
        return
    end

    local steamID = self:GetSteamID(ply)
    local itemId = nil
    for _, p in pairs(self.Products or {}) do
        if (rollKind == "occult" and p.use_mode == "open_occult_page") or (rollKind == "heritage" and p.use_mode == "open_heritage_page") then
            itemId = p.id
            break
        end
    end

    if not itemId then
        if callback then callback(false, "no_product") end
        return
    end

    local busyKey = "roll_" .. rollKind
    if not self:AcquireBusy(steamID, busyKey) then
        if callback then callback(false, "busy") end
        return
    end

    self:WithPlayerState(ply, function(ok, stateOrErr)
        if not ok then
            self:ReleaseBusy(steamID, busyKey)
            if callback then callback(false, stateOrErr) end
            return
        end

        local state = self:SanitizeSyncState(stateOrErr)
        if (state.items[itemId] or 0) <= 0 then
            self:ReleaseBusy(steamID, busyKey)
            if callback then callback(false, "not_owned") end
            return
        end

        state.items[itemId] = math.max(0, (state.items[itemId] or 0) - 1)
        local pool = self.RerollPool and self.RerollPool[itemId] or {}
        local reward = self:PickWeighted(pool)
        local changedItems = {
            [itemId] = true
        }

        local payload
        if reward then
            local resultAsset = tostring(reward.result_icon or "")
            if resultAsset == "" then resultAsset = tostring(reward.icon or "") end
            payload = {
                kind = rollKind,
                id = tostring(reward.id or ""),
                name = tostring(reward.name),
                rarity = tostring(reward.rarity or "common"),
                asset = resultAsset,
                video_url = tostring(reward.video_url or ""),
                at = now(),
                reward_type = reward.reward_type,
                reward_value = reward.reward_value,
            }

            if reward.reward_type == "coins" then
                local amount = math.max(0, math.floor(tonumber(reward.reward_value) or 0))
                state.account.coins = math.max(0, state.account.coins + amount)
            elseif reward.reward_type == "money" then
                local onlinePly = self:FindOnlinePlayerBySteamID(steamID)
                if IsValid(onlinePly) then onlinePly:AddMoney(math.floor(tonumber(reward.reward_value) or 0)) end
            elseif reward.reward_type == "item" then
                local rewardItemId = tostring(reward.reward_value or ""):Trim()
                if rewardItemId ~= "" then
                    local onlinePly = self:FindOnlinePlayerBySteamID(steamID)
                    if IsValid(onlinePly) and onlinePly.AddItem then
                        onlinePly:AddItem(rewardItemId, 1, nil, function(ok, err) if not ok then logErr("DoRoll: AddItem failed for", rewardItemId, "->", tostring(err)) end end)
                    else
                        logErr("DoRoll: player not online or AddItem unavailable for item reward", rewardItemId)
                    end
                end
            elseif reward.reward_type == "skilltree_branch" or reward.reward_type == "skilltree" then
                local subtypeId = tostring(reward.reward_value or ""):Trim()
                if subtypeId ~= "" then
                    local onlinePly = self:FindOnlinePlayerBySteamID(steamID)
                    if IsValid(onlinePly) then
                        local ST = VERSE and VERSE.SkillTree
                        if ST and ST.AdminSetBranch then
                            -- Vérifie si le joueur a déjà une branche dans le même groupe exclusif.
                            -- Si oui, on diffère l'application et on laisse le client choisir.
                            local group          = ST.GetExclusiveGroupForSubtype and ST:GetExclusiveGroupForSubtype(subtypeId)
                            local charId         = group and ST.GetCharacterUID    and ST:GetCharacterUID(onlinePly)
                            local existingBranch = ""
                            if charId and group then
                                local cachedMeta = ST._metaCache and ST._metaCache[charId]
                                if istable(cachedMeta) and istable(cachedMeta.branches) then
                                    existingBranch = tostring(cachedMeta.branches[group.id] or "")
                                end
                            end

                            -- Le popup de remplacement (différé + confirmation) n'est
                            -- voulu QUE pour l'héritage. Le pouvoir occulte s'applique
                            -- toujours directement, sans confirmation.
                            local hasExistingHeritage = existingBranch ~= "" and existingBranch ~= subtypeId and rollKind == "heritage"
                            payload.has_existing_heritage = hasExistingHeritage

                            if hasExistingHeritage then
                                -- Résout le nom d'affichage de l'ancien héritage pour le popup client.
                                local existingBranchName = existingBranch
                                for _, cat in ipairs((ST.Tree or {})) do
                                    for _, sub in ipairs(cat.subtypes or {}) do
                                        if tostring(sub.id or "") == existingBranch then
                                            existingBranchName = tostring(sub.title or existingBranch)
                                            break
                                        end
                                    end
                                end
                                payload.existing_branch_name = existingBranchName

                                -- Application différée : le joueur doit confirmer son choix côté client.
                                BT._pendingHeritagePick = BT._pendingHeritagePick or {}
                                BT._pendingHeritagePick[steamID] = subtypeId
                                logInfo("DoRoll: heritage deferred for", steamID, "- new:", subtypeId, "/ existing:", existingBranch)
                            else
                                -- Pas d'héritage existant : on applique immédiatement.
                                ST:AdminSetBranch(onlinePly, subtypeId, function(ok, _, refund)
                                    if not ok then
                                        logErr("DoRoll: AdminSetBranch failed for", subtypeId)
                                    else
                                        logInfo("DoRoll: branch set to", subtypeId, "for", steamID, "(refund:", tostring(refund or 0), "pts)")
                                    end
                                end)
                            end
                        else
                            logErr("DoRoll: VERSE.SkillTree unavailable for skilltree_branch reward")
                        end
                    else
                        logErr("DoRoll: player not online for skilltree_branch reward", subtypeId)
                    end
                end
            elseif reward.reward_type == "nothing" then
                -- Rien : le ticket est consommé mais aucune récompense n'est attribuée.
                logInfo("DoRoll: 'nothing' result for", steamID, "- ticket consumed, no reward given")
            end
        else
            payload = {
                kind = rollKind,
                id = "empty_pool",
                name = "Pool vide",
                rarity = "common",
                asset = "",
                at = now(),
            }
        end

        state.account.last_roll_type = rollKind
        state.account.last_roll_payload = payload
        state.account.updated_at = now()
        self:PersistState(steamID, state, changedItems, function(saveOk, saveErr)
            self:ReleaseBusy(steamID, busyKey)
            if not saveOk then
                if callback then callback(false, saveErr) end
                return
            end

            self:SetCachedState(steamID, state)
            self:WriteTransaction(steamID, "roll_" .. rollKind, 0, itemId, payload)

            self:SyncPlayer(ply)
            netstream.Start(ply, self.Net.RollResult, rollKind, payload)
            if callback then callback(true, payload) end
        end)
    end)
end

function BT:StartOccultRoll(ply, callback)
    self:DoRoll(ply, "occult", callback)
end

function BT:StartHeritageRoll(ply, callback)
    self:DoRoll(ply, "heritage", callback)
end

local function noPermissionNotify(ply, cmd)
    if IsValid(ply) and isfunction(ply.Notify) then ply:Notify("Permission refusee: " .. tostring(cmd), NOTIFY_ERROR, 4) end
end

local function resolveCommandTarget(raw)
    raw = tostring(raw or ""):Trim()
    if raw == "" then return nil, nil end
    if BT:IsValidSteamID(raw) then return BT:FindOnlinePlayerBySteamID(raw), raw end
    local search = string.lower(raw)
    for _, ply in ipairs(player.GetAll()) do
        if BT:GetSteamID(ply) == raw then return ply, raw end
    end

    for _, ply in ipairs(player.GetAll()) do
        local steamNick = string.lower(tostring((ply.SteamNick and ply:SteamNick()) or ""))
        local displayNick = string.lower(tostring((ply.Nick and ply:Nick()) or ""))
        if string.find(steamNick, search, 1, true) or string.find(displayNick, search, 1, true) then return ply, BT:GetSteamID(ply) end
    end
    return nil, nil
end

netstream.Hook(BT.Net.RequestSync, function(ply)
    if not IsValid(ply) then return end
    BT:LoadPlayer(ply)
end)

netstream.Hook(BT.Net.SaveCreatorCode, function(ply, code)
    if not IsValid(ply) then return end
    local now = CurTime()
    local sid = ply:SteamID()
    if (_btCreatorCD[sid] or 0) + 10 > now then return end
    _btCreatorCD[sid] = now
    BT:SaveCreatorCode(ply, code)
end)

netstream.Hook(BT.Net.BuyProduct, function(ply, productId, amount)
    if not IsValid(ply) then return end
    BT:PurchaseProduct(ply, productId, amount, function(ok, err)
        if not ok and isfunction(ply.Notify) then
            local msg = ({
                invalid_product = "Produit introuvable.",
                not_enough_coins = "Pas assez de coins.",
                busy = "Action deja en cours.",
            })[tostring(err or "")]

            ply:Notify(msg or ("Erreur boutique: " .. tostring(err)), NOTIFY_ERROR, 4)
        end
    end)
end)

netstream.Hook(BT.Net.UseOwnedItem, function(ply, itemId)
    if not IsValid(ply) then return end
    BT:UseOwnedItem(ply, itemId, function(ok, err)
        if not ok and isfunction(ply.Notify) then
            local msg = ({
                not_owned = "Vous ne possedez pas cet objet.",
                busy = "Action deja en cours.",
            })[tostring(err or "")]

            ply:Notify(msg or ("Erreur boutique: " .. tostring(err)), NOTIFY_ERROR, 4)
        end
    end)
end)

netstream.Hook(BT.Net.StartOccultRoll, function(ply)
    if not IsValid(ply) then return end
    BT:StartOccultRoll(ply, function(ok, err) if not ok and isfunction(ply.Notify) then ply:Notify(err == "not_owned" and "Aucun reroll pouvoir occulte disponible." or ("Erreur boutique: " .. tostring(err)), NOTIFY_ERROR, 4) end end)
end)

netstream.Hook(BT.Net.StartHeritageRoll, function(ply)
    if not IsValid(ply) then return end
    BT:StartHeritageRoll(ply, function(ok, err) if not ok and isfunction(ply.Notify) then ply:Notify(err == "not_owned" and "Aucun reroll heritage disponible." or ("Erreur boutique: " .. tostring(err)), NOTIFY_ERROR, 4) end end)
end)

netstream.Hook(BT.Net.ResolveHeritageRoll, function(ply, accepted)
    if not IsValid(ply) then return end
    accepted = tobool(accepted)
    local steamID = BT:GetSteamID(ply)

    -- Applique ou annule un héritage différé (popup de choix côté client).
    BT._pendingHeritagePick = BT._pendingHeritagePick or {}
    local pendingSubtype = BT._pendingHeritagePick[steamID]
    if pendingSubtype then
        BT._pendingHeritagePick[steamID] = nil
        if accepted then
            local ST = VERSE and VERSE.SkillTree
            if ST and ST.AdminSetBranch then
                ST:AdminSetBranch(ply, pendingSubtype, function(ok, _, refund)
                    if not ok then
                        logErr("ResolveHeritageRoll: AdminSetBranch failed for", pendingSubtype)
                    else
                        logInfo("ResolveHeritageRoll: branch set to", pendingSubtype, "for", steamID, "(refund:", tostring(refund or 0), "pts)")
                    end
                end)
            end
        else
            logInfo("ResolveHeritageRoll: player kept old heritage for", steamID, "- new branch discarded:", pendingSubtype)
        end
    end

    if VERSE.Hook and VERSE.Hook.Run then
        VERSE.Hook.Run("VERSE::Boutique::HeritageResolved", ply, accepted)
    end
end)

VERSE.Commands.Add("verse_boutique_coins", function(ply, args)
    if IsValid(ply) and not ply:IsDeveloper() then
        noPermissionNotify(ply, "verse_boutique_coins")
        return
    end

    local targetArg = tostring(args[1] or ""):Trim()
    local amount = math.floor(tonumber(args[2]) or 0)
    if targetArg == "" or amount == 0 then
        if IsValid(ply) and isfunction(ply.Notify) then ply:Notify("Usage: verse_boutique_coins <steamid|player> <amount>", NOTIFY_HINT, 5) end
        return
    end

    local targetPly, steamID = resolveCommandTarget(targetArg)
    if not steamID and BT:IsValidSteamID(targetArg) then steamID = targetArg end
    if not steamID then
        if IsValid(ply) and isfunction(ply.Notify) then ply:Notify("SteamID ou joueur introuvable.", NOTIFY_ERROR, 4) end
        return
    end

    BT:AddCoinsBySteamID(steamID, amount, "command", function(ok, balance)
        if not ok then
            if IsValid(ply) and isfunction(ply.Notify) then ply:Notify("Erreur boutique.", NOTIFY_ERROR, 4) end
            return
        end

        local targetLabel = IsValid(targetPly) and (targetPly:Nick() .. " [" .. steamID .. "]") or steamID
        if IsValid(ply) and isfunction(ply.Notify) then
            local sign = amount > 0 and "+" or ""
            ply:Notify(sign .. amount .. " coins -> " .. targetLabel .. " (solde: " .. tostring(balance) .. ")", NOTIFY_HINT, 5)
        else
            print(("[Boutique] %s%d -> %s (balance=%s)"):format(amount > 0 and "+" or "", amount, targetLabel, tostring(balance)))
        end
    end)
end, "developer")

local meta = FindMetaTable("Player")
function meta:GetBoutiqueCoins()
    local state = BT:GetCachedState(BT:GetSteamID(self))
    if not state or not state.account then return 0 end
    return math.max(0, math.floor(tonumber(state.account.coins) or 0))
end

function meta:AddBoutiqueCoins(amount, reason, callback)
    BT:AddCoinsBySteamID(BT:GetSteamID(self), amount, reason, callback)
end

local function adminDataSync(ply)
    if not IsValid(ply) then return end
    netstream.Start(ply, BT.Net.Admin.DataSync, {
        products         = BT.Products or {},
        rarities         = BT.Rarities or {},
        reroll_pool      = BT.RerollPool or {},
        creators         = BT.Creators or {},
        pack_tenue_packs = BT.PackTenuePacks or {},
    })
end

netstream.Hook(BT.Net.Admin.RequestData, function(ply)
    if not ply:IsDeveloper() then return end
    adminDataSync(ply)
end)

netstream.Hook(BT.Net.Admin.SaveProduct, function(ply, data)
    if not ply:IsDeveloper() or not istable(data) then return end
    local id = tostring(data.id or ""):Trim()
    if id == "" then return end
    local p = {
        id = id,
        name = tostring(data.name or ""),
        category = tostring(data.category or "rerolls"),
        price = math.max(0, math.floor(tonumber(data.price) or 0)),
        icon = tostring(data.icon or ""),
        icon_w = math.max(16, math.floor(tonumber(data.icon_w) or 256)),
        icon_h = math.max(16, math.floor(tonumber(data.icon_h) or 256)),
        video_url = tostring(data.video_url or ""),
        banner_image = tostring(data.banner_image or ""),
        use_mode = tostring(data.use_mode or ""),
        use_text = tostring(data.use_text or "Utiliser"),
        purchase_text = tostring(data.purchase_text or "Acheter"),
        fallback_label = tostring(data.fallback_label or ""),
        rarity = tostring(data.rarity or ""),
        accent_r = math.Clamp(math.floor(tonumber(data.accent_r) or 171), 0, 255),
        accent_g = math.Clamp(math.floor(tonumber(data.accent_g) or 82), 0, 255),
        accent_b = math.Clamp(math.floor(tonumber(data.accent_b) or 255), 0, 255),
        weight = math.max(1, math.floor(tonumber(data.weight) or 1)),
        purchase_limit_local = math.max(0, math.floor(tonumber(data.purchase_limit_local) or 0)),
        purchase_limit_global = math.max(0, math.floor(tonumber(data.purchase_limit_global) or 0)),
        sort_order = math.floor(tonumber(data.sort_order) or 0),
        enabled = (data.enabled == false or data.enabled == 0) and 0 or 1,
    }

    BT:SaveProductToDB(p, function(ok, err)
        if not ok then
            logErr("Admin SaveProduct failed:", tostring(err))
            return
        end

        BT:LoadProducts(function()
            BT:BroadcastProductsAndRarities()
            adminDataSync(ply)
        end)
    end)
end)

netstream.Hook(BT.Net.Admin.DelProduct, function(ply, productId)
    if not ply:IsDeveloper() then return end
    productId = tostring(productId or ""):Trim()
    if productId == "" then return end
    BT:DeleteProductFromDB(productId, function(ok, err)
        if not ok then
            logErr("Admin DelProduct failed:", tostring(err))
            return
        end

        BT.Products[productId] = nil
        BT:RebuildDerivedData()
        BT:BroadcastProductsAndRarities()
        adminDataSync(ply)
    end)
end)

netstream.Hook(BT.Net.Admin.SaveRarity, function(ply, data)
    if not ply:IsDeveloper() or not istable(data) then return end
    local id = tostring(data.id or ""):Trim()
    if id == "" then return end
    local r = {
        id = id,
        name = tostring(data.name or ""),
        color_r = math.Clamp(math.floor(tonumber(data.color_r) or 160), 0, 255),
        color_g = math.Clamp(math.floor(tonumber(data.color_g) or 160), 0, 255),
        color_b = math.Clamp(math.floor(tonumber(data.color_b) or 160), 0, 255),
    }

    BT:SaveRarityToDB(r, function(ok, err)
        if not ok then
            logErr("Admin SaveRarity failed:", tostring(err))
            return
        end

        BT:LoadRarities(function()
            BT:BroadcastProductsAndRarities()
            adminDataSync(ply)
        end)
    end)
end)

netstream.Hook(BT.Net.Admin.DelRarity, function(ply, rarityId)
    if not ply:IsDeveloper() then return end
    rarityId = tostring(rarityId or ""):Trim()
    if rarityId == "" then return end
    BT:DeleteRarityFromDB(rarityId, function(ok, err)
        if not ok then
            logErr("Admin DelRarity failed:", tostring(err))
            return
        end

        BT:LoadRarities(function()
            BT:BroadcastProductsAndRarities()
            adminDataSync(ply)
        end)
    end)
end)

netstream.Hook(BT.Net.Admin.GetPlayer, function(ply, steamID)
    if not ply:IsDeveloper() then return end
    steamID = tostring(steamID or ""):Trim()
    if not BT:IsValidSteamID(steamID) then return end
    BT:LoadStateBySteamID(steamID, function(ok, stateOrErr)
        if not ok then return end
        local state = BT:SanitizeSyncState(stateOrErr)
        local nick = ""
        local onlinePly = BT:FindOnlinePlayerBySteamID(steamID)
        if IsValid(onlinePly) then nick = isfunction(onlinePly.Nick) and onlinePly:Nick() or "" end
        netstream.Start(ply, BT.Net.Admin.PlayerData, {
            steamID = steamID,
            nick = nick,
            account = state.account,
            items = state.items,
            transactions = state.transactions,
        })
    end)
end)

netstream.Hook(BT.Net.Admin.ModBalance, function(ply, steamID, amount)
    if not ply:IsDeveloper() then return end
    steamID = tostring(steamID or ""):Trim()
    amount = math.floor(tonumber(amount) or 0)
    if not BT:IsValidSteamID(steamID) or amount == 0 then return end
    BT:AddCoinsBySteamID(steamID, amount, "admin", function(ok, balance)
        if not ok then return end
        logInfo("Admin ModBalance:", steamID, amount, "new balance:", tostring(balance))
        local targetPly = BT:FindOnlinePlayerBySteamID(steamID)
        if IsValid(targetPly) then BT:SyncPlayer(targetPly) end
        BT:LoadStateBySteamID(steamID, function(ok2, s2)
            if not ok2 then return end
            local state = BT:SanitizeSyncState(s2)
            local nick = ""
            if IsValid(targetPly) then nick = isfunction(targetPly.Nick) and targetPly:Nick() or "" end
            netstream.Start(ply, BT.Net.Admin.PlayerData, {
                steamID = steamID,
                nick = nick,
                account = state.account,
                items = state.items,
                transactions = state.transactions,
            })
        end)
    end)
end)

function BT:AdminModifyItem(steamID, itemId, delta, callback)
    steamID = tostring(steamID or ""):Trim()
    itemId = tostring(itemId or ""):Trim()
    delta = math.floor(tonumber(delta) or 0)
    if not self:IsValidSteamID(steamID) or itemId == "" or delta == 0 then
        if callback then callback(false, "invalid_args") end
        return
    end

    self:LoadStateBySteamID(steamID, function(ok, stateOrErr)
        if not ok then
            if callback then callback(false, stateOrErr) end
            return
        end

        local state = self:SanitizeSyncState(stateOrErr)
        local cur = math.floor(tonumber(state.items[itemId] or 0) or 0)
        local newAmt = math.max(0, cur + delta)
        state.items[itemId] = newAmt
        local changed = {}
        changed[itemId] = true
        self:PersistState(steamID, state, changed, function(saveOk, saveErr)
            if not saveOk then
                if callback then callback(false, saveErr) end
                return
            end

            self:SetCachedState(steamID, state)
            local tPly = self:FindOnlinePlayerBySteamID(steamID)
            if IsValid(tPly) then self:SyncPlayer(tPly) end
            if callback then callback(true, newAmt) end
        end)
    end)
end

local function adminResendPlayerData(adminPly, steamID)
    BT:LoadStateBySteamID(steamID, function(ok, s)
        if not ok or not IsValid(adminPly) then return end
        local state = BT:SanitizeSyncState(s)
        local nick = ""
        local tPly = BT:FindOnlinePlayerBySteamID(steamID)
        if IsValid(tPly) then nick = isfunction(tPly.Nick) and tPly:Nick() or "" end
        netstream.Start(adminPly, BT.Net.Admin.PlayerData, {
            steamID = steamID,
            nick = nick,
            account = state.account,
            items = state.items,
            transactions = state.transactions,
        })
    end)
end

netstream.Hook(BT.Net.Admin.GiveItem, function(ply, steamID, itemId, amount)
    if not ply:IsDeveloper() then return end
    steamID = tostring(steamID or ""):Trim()
    itemId = tostring(itemId or ""):Trim()
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if not BT:IsValidSteamID(steamID) or itemId == "" then return end
    BT:AdminModifyItem(steamID, itemId, amount, function(ok, err)
        if not ok then
            logErr("Admin GiveItem failed:", tostring(err))
            return
        end

        logInfo("Admin GiveItem:", steamID, itemId, "+" .. amount)
        adminResendPlayerData(ply, steamID)
    end)
end)

netstream.Hook(BT.Net.Admin.RemoveItem, function(ply, steamID, itemId, amount)
    if not ply:IsDeveloper() then return end
    steamID = tostring(steamID or ""):Trim()
    itemId = tostring(itemId or ""):Trim()
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if not BT:IsValidSteamID(steamID) or itemId == "" then return end
    BT:AdminModifyItem(steamID, itemId, -amount, function(ok, err)
        if not ok then
            logErr("Admin RemoveItem failed:", tostring(err))
            return
        end

        logInfo("Admin RemoveItem:", steamID, itemId, "-" .. amount)
        adminResendPlayerData(ply, steamID)
    end)
end)

netstream.Hook(BT.Net.Admin.GetRerollPool, function(ply, rollType)
    if not ply:IsDeveloper() then return end
    rollType = tostring(rollType or "occult")
    netstream.Start(ply, BT.Net.Admin.RerollPoolData, rollType, BT.RerollPool and BT.RerollPool[rollType] or {})
end)

netstream.Hook(BT.Net.Admin.SavePoolEntry, function(ply, data)
    if not ply:IsDeveloper() or not istable(data) then return end
    local entry = {
        id = math.floor(tonumber(data.id) or 0),
        roll_type = tostring(data.roll_type or "occult"),
        name = tostring(data.name or ""):Trim(),
        icon = tostring(data.icon or ""):Trim(),
        result_icon = tostring(data.result_icon or ""):Trim(),
        rarity = tostring(data.rarity or ""),
        weight = math.max(1, math.floor(tonumber(data.weight) or 1)),
        reward_type = tostring(data.reward_type or "coins"),
        reward_value = tostring(data.reward_value or "0"):Trim(),
        video_url = tostring(data.video_url or ""):Trim(),
        sort_order = math.floor(tonumber(data.sort_order) or 0),
    }

    if entry.name == "" then return end
    BT:SavePoolEntryToDB(entry, function(ok, err)
        if not ok then
            logErr("Admin SavePoolEntry failed:", tostring(err))
            return
        end

        logInfo("Admin SavePoolEntry:", entry.roll_type, entry.name)
        BT:LoadRerollPool(function() adminDataSync(ply) end)
    end)
end)

netstream.Hook(BT.Net.Admin.DelPoolEntry, function(ply, entryId, rollType)
    if not ply:IsDeveloper() then return end
    entryId = math.floor(tonumber(entryId) or 0)
    rollType = tostring(rollType or "")
    if entryId <= 0 then return end
    BT:DeletePoolEntryFromDB(entryId, function(ok, err)
        if not ok then
            logErr("Admin DelPoolEntry failed:", tostring(err))
            return
        end

        logInfo("Admin DelPoolEntry:", entryId)
        BT:LoadRerollPool(function() adminDataSync(ply) end)
    end)
end)

netstream.Hook(BT.Net.Admin.SaveCreator, function(ply, data)
    if not ply:IsDeveloper() or not istable(data) then return end
    local code = BT:NormalizeCreatorCode(tostring(data.code or ""))
    if code == "" then
        if isfunction(ply.Notify) then ply:Notify("Code invalide : format non reconnu.", NOTIFY_ERROR, 4) end
        return
    end

    local rewards = {}
    if istable(data.bonus_rewards) then
        for _, r in ipairs(data.bonus_rewards) do
            if istable(r) then
                local rt = tostring(r.type or "coins")
                if rt ~= "coins" and rt ~= "item" then rt = "coins" end
                local amt = math.max(0, math.floor(tonumber(r.amount) or 0))
                local itm = tostring(r.item or ""):sub(1, 64)
                if amt > 0 then
                    rewards[#rewards + 1] = {
                        type = rt,
                        amount = amt,
                        item = itm
                    }
                end
            end
        end
    end

    local entry = {
        id = math.floor(tonumber(data.id) or 0),
        code = code,
        owner_name = tostring(data.owner_name or ""):sub(1, 128),
        steamid = tostring(data.steamid or ""):Trim():sub(1, 32),
        payout_rate = math.max(0, math.floor(tonumber(data.payout_rate) or 0)),
        buyer_discount = math.min(99, math.max(0, math.floor(tonumber(data.buyer_discount) or 0))),
        enabled = (data.enabled == false or data.enabled == 0) and false or true,
        notes = tostring(data.notes or ""):sub(1, 512),
        bonus_rewards = rewards,
    }

    BT:SaveCreatorToDB(entry, function(ok, err)
        if not ok then
            logErr("Admin SaveCreator failed:", tostring(err))
            if isfunction(ply.Notify) then ply:Notify("Erreur: " .. tostring(err or "save"), NOTIFY_ERROR, 4) end
            return
        end

        logInfo("Admin SaveCreator:", entry.code, entry.owner_name)
        BT:LoadCreators(function() adminDataSync(ply) end)
    end)
end)

netstream.Hook(BT.Net.Admin.DelCreator, function(ply, entryId)
    if not ply:IsDeveloper() then return end
    entryId = math.floor(tonumber(entryId) or 0)
    if entryId <= 0 then return end
    BT:DeleteCreatorFromDB(entryId, function(ok, err)
        if not ok then
            logErr("Admin DelCreator failed:", tostring(err))
            return
        end

        logInfo("Admin DelCreator:", entryId)
        BT:LoadCreators(function() adminDataSync(ply) end)
    end)
end)

netstream.Hook(BT.Net.Admin.GetCreatorStats, function(ply)
    if not ply:IsDeveloper() then return end
    BT:GetCreatorAggregateStats(function(stats) if IsValid(ply) then netstream.Start(ply, BT.Net.Admin.CreatorStatsData, stats) end end)
end)

netstream.Hook(BT.Net.Admin.GetCreatorDetails, function(ply, code, period)
    if not ply:IsDeveloper() then return end
    BT:GetCreatorDetails(tostring(code or ""), tostring(period or "all"), function(details) if IsValid(ply) then netstream.Start(ply, BT.Net.Admin.CreatorDetailsData, details) end end)
end)

netstream.Hook(BT.Net.Admin.ExportCreatorCSV, function(ply, code, period)
    if not ply:IsDeveloper() then return end
    BT:ExportCreatorEventsCSV(tostring(code or ""), tostring(period or "all"), function(ok, pathOrErr, count) if IsValid(ply) then netstream.Start(ply, BT.Net.Admin.CSVExportResult, ok, tostring(pathOrErr or ""), tonumber(count) or 0) end end)
end)

VERSE.DB:OnReady(function()
    BT:CreateTables()
    -- Chargement différé pour laisser le temps aux tables d'être créées
    timer.Simple(1, function() loadGlobalSold() end)
end)
VERSE.Hook.AddNS("Boutique", "PlayerFullLoad", "VERSE::Boutique::PlayerFullLoad", function(ply) BT:LoadPlayer(ply) end)
VERSE.Hook.AddNS("Boutique", "PlayerDisconnected", "VERSE::Boutique::PlayerDisconnected", function(ply)
    local sid = BT:GetSteamID(ply)
    BT:ClearCachedState(sid)
    _btCreatorCD[ply:SteamID()] = nil
end)
concommand.Add("verse_tebex_addcoins", function(ply, _, args)
    if IsValid(ply) then return end
    local rawId = tostring(args[1] or ""):Trim()
    local amount = math.floor(tonumber(args[2]) or 0)
    if rawId == "" or amount <= 0 then
        print("[Tebex] Usage: verse_tebex_addcoins <steamid64> <amount>")
        return
    end

    local steamID = rawId
    if string.match(rawId, "^%d+$") then steamID = util.SteamIDFrom64(rawId) end
    if not BT:IsValidSteamID(steamID) then
        print("[Tebex] Invalid SteamID: " .. rawId .. " -> " .. tostring(steamID))
        return
    end

    BT:AddCoinsBySteamID(steamID, amount, "tebex", function(ok, balanceOrErr)
        if not ok then
            print(("[Tebex] ERROR +%d coins -> %s : %s"):format(amount, steamID, tostring(balanceOrErr)))
            return
        end

        print(("[Tebex] +%d coins -> %s (new balance: %s)"):format(amount, steamID, tostring(balanceOrErr)))
    end)
end)