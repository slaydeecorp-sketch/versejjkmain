local TRADERS = VERSE.Traders
local DB = VERSE.DB
local INV = VERSE.Inventory
if not TRADERS or not DB then return end
TRADERS._cache = TRADERS._cache or {}
TRADERS._items = TRADERS._items or {}
TRADERS._busy  = TRADERS._busy  or {}
TRADERS._entities = TRADERS._entities or {}
local function esc(v)
    return DB:Escape(v)
end

local function logInfo(...)
    if VERSE.Log and VERSE.Log.Info then VERSE.Log:Info("[Traders]", ...) end
end

local function logErr(...)
    if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[Traders]", ...) end
end

-- Actions marchands réservées aux superadmins uniquement
local function isAdmin(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

function TRADERS:CreateTables()
    local t1 = self.Config.TableTraders
    local t2 = self.Config.TableItems
    local q1, q2
    if DB:IsMySQL() then
        q1 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT NOT NULL AUTO_INCREMENT,
                name VARCHAR(128) NOT NULL,
                model VARCHAR(255) NOT NULL,
                map VARCHAR(64) NOT NULL,
                pos_x FLOAT NOT NULL,
                pos_y FLOAT NOT NULL,
                pos_z FLOAT NOT NULL,
                ang_y FLOAT NOT NULL DEFAULT 0,
                created_at INT NOT NULL,
                PRIMARY KEY (id),
                KEY idx_map (map)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(t1)
        q2 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT NOT NULL AUTO_INCREMENT,
                trader_id INT NOT NULL,
                item_id VARCHAR(64) NOT NULL,
                price INT NOT NULL,
                sort_order INT NOT NULL DEFAULT 0,
                PRIMARY KEY (id),
                UNIQUE KEY uq_trader_item (trader_id, item_id),
                KEY idx_trader_id (trader_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(t2)
    else
        q1 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                model TEXT NOT NULL,
                map TEXT NOT NULL,
                pos_x REAL NOT NULL,
                pos_y REAL NOT NULL,
                pos_z REAL NOT NULL,
                ang_y REAL NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
            )
        ]]):format(t1)
        q2 = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                trader_id INTEGER NOT NULL,
                item_id TEXT NOT NULL,
                price INTEGER NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0,
                UNIQUE(trader_id, item_id)
            )
        ]]):format(t2)
    end

    DB:Query(q1, function() logInfo("Table created:", t1) end, function(err)
        logErr("Create table failed:", t1, tostring(err))
        return true
    end)

    DB:Query(q2, function() logInfo("Table created:", t2) end, function(err)
        logErr("Create table failed:", t2, tostring(err))
        return true
    end)
end

function TRADERS:LoadAll(callback)
    local currentMap = game.GetMap()
    local t1 = self.Config.TableTraders
    local t2 = self.Config.TableItems
    local query = ("SELECT * FROM %s WHERE map = %s"):format(t1, esc(currentMap))
    DB:Query(query, function(rows)
        rows = rows or {}
        self._cache = {}
        self._items = {}
        for _, row in ipairs(rows) do
            local id = tonumber(row.id)
            if id then
                self._cache[id] = {
                    id = id,
                    name = row.name or "Trader",
                    model = row.model or "models/humans/group01/male_01.mdl",
                    map = row.map,
                    pos = Vector(tonumber(row.pos_x) or 0, tonumber(row.pos_y) or 0, tonumber(row.pos_z) or 0),
                    ang = Angle(0, tonumber(row.ang_y) or 0, 0),
                }
            end
        end

        local traderIds = table.GetKeys(self._cache)
        if #traderIds == 0 then
            logInfo("No traders on map:", currentMap)
            self:SpawnAll()
            if callback then callback(true) end
            return
        end

        local idList = table.concat(traderIds, ",")
        local itemQuery = ("SELECT * FROM %s WHERE trader_id IN (%s)"):format(t2, idList)
        DB:Query(itemQuery, function(itemRows)
            itemRows = itemRows or {}
            for _, row in ipairs(itemRows) do
                local tid = tonumber(row.trader_id)
                local itemId = row.item_id
                if tid and itemId then
                    if not self._items[tid] then self._items[tid] = {} end
                    self._items[tid][itemId] = {
                        price = tonumber(row.price) or 0,
                        sort_order = tonumber(row.sort_order) or 0,
                    }
                end
            end

            logInfo(("Loaded %d traders, map: %s"):format(#traderIds, currentMap))
            self:SpawnAll()
            if callback then callback(true) end
        end, function(err)
            logErr("Load items failed:", tostring(err))
            self:SpawnAll()
            if callback then callback(false, err) end
            return true
        end)
    end, function(err)
        logErr("Load traders failed:", tostring(err))
        if callback then callback(false, err) end
        return true
    end)
end

function TRADERS:SpawnAll()
    for id, _ in pairs(self._entities) do
        local ent = self._entities[id]
        if IsValid(ent) then ent:Remove() end
    end

    self._entities = {}
    for id, data in pairs(self._cache) do
        self:SpawnOne(id)
    end
end

function TRADERS:SpawnOne(traderId)
    local data = self._cache[traderId]
    if not data then return nil end
    if IsValid(self._entities[traderId]) then self._entities[traderId]:Remove() end
    local ent = ents.Create("verse_trader_npc")
    if not IsValid(ent) then
        logErr("Failed to create entity for trader:", traderId)
        return nil
    end

    ent._worldModel = data.model
    ent:SetPos(data.pos)
    ent:SetAngles(data.ang)
    ent:Spawn()
    ent:Activate()
    ent:SetTraderID(traderId)
    ent:SetTraderName(data.name)
    self._entities[traderId] = ent
    return ent
end

function TRADERS:Create(name, model, pos, ang, callback)
    local t1 = self.Config.TableTraders
    local currentMap = game.GetMap()
    local count = table.Count(self._cache)
    if count >= self.Config.MaxTraders then
        if callback then callback(false, "max_traders") end
        return
    end

    name = string.sub(tostring(name or "Trader"), 1, self.Config.MaxNameLength)
    model = tostring(model or "models/humans/group01/male_01.mdl")
    local query = ("INSERT INTO %s (name, model, map, pos_x, pos_y, pos_z, ang_y, created_at) VALUES (%s, %s, %s, %f, %f, %f, %f, %d)"):format(t1, esc(name), esc(model), esc(currentMap), pos.x, pos.y, pos.z, ang.y, os.time())
    DB:Query(query, function(_, lastInsert)
        local traderId = tonumber(lastInsert)
        if not traderId or traderId <= 0 then
            DB:QueryValue(("SELECT MAX(id) FROM %s"):format(t1), function(val)
                traderId = tonumber(val) or 0
                self._cache[traderId] = {
                    id = traderId,
                    name = name,
                    model = model,
                    map = currentMap,
                    pos = Vector(pos.x, pos.y, pos.z),
                    ang = Angle(0, ang.y, 0),
                }

                self._items[traderId] = {}
                self:SpawnOne(traderId)
                if callback then callback(true, traderId) end
            end)
            return
        end

        self._cache[traderId] = {
            id = traderId,
            name = name,
            model = model,
            map = currentMap,
            pos = Vector(pos.x, pos.y, pos.z),
            ang = Angle(0, ang.y, 0),
        }

        self._items[traderId] = {}
        self:SpawnOne(traderId)
        if callback then callback(true, traderId) end
    end, function(err)
        logErr("Create trader failed:", tostring(err))
        if callback then callback(false, err) end
        return true
    end)
end

function TRADERS:Update(traderId, data, callback)
    traderId = tonumber(traderId)
    if not traderId or not self._cache[traderId] then
        if callback then callback(false, "not_found") end
        return
    end

    local cached = self._cache[traderId]
    local newName = data.name and string.sub(tostring(data.name), 1, self.Config.MaxNameLength) or cached.name
    local newModel = data.model and tostring(data.model) or cached.model
    local t1 = self.Config.TableTraders
    local query = ("UPDATE %s SET name=%s, model=%s WHERE id=%d"):format(t1, esc(newName), esc(newModel), traderId)
    DB:Query(query, function()
        local modelChanged = cached.model ~= newModel
        cached.name = newName
        cached.model = newModel
        local ent = self._entities[traderId]
        if IsValid(ent) then
            ent:SetTraderName(newName)
            if modelChanged then self:SpawnOne(traderId) end
        end

        if callback then callback(true) end
    end, function(err)
        logErr("Update trader failed:", tostring(err))
        if callback then callback(false, err) end
        return true
    end)
end

function TRADERS:Delete(traderId, callback)
    traderId = tonumber(traderId)
    if not traderId then
        if callback then callback(false, "invalid_id") end
        return
    end

    local t1 = self.Config.TableTraders
    local t2 = self.Config.TableItems
    DB:Query(("DELETE FROM %s WHERE trader_id=%d"):format(t2, traderId), function() end, function(err)
        logErr("Delete trader items failed:", tostring(err))
        return true
    end)

    DB:Query(("DELETE FROM %s WHERE id=%d"):format(t1, traderId), function()
        local ent = self._entities[traderId]
        if IsValid(ent) then ent:Remove() end
        self._entities[traderId] = nil
        self._cache[traderId] = nil
        self._items[traderId] = nil
        if callback then callback(true) end
    end, function(err)
        logErr("Delete trader failed:", tostring(err))
        if callback then callback(false, err) end
        return true
    end)
end

function TRADERS:AddItem(traderId, itemId, price, sortOrder, callback)
    traderId = tonumber(traderId)
    if not traderId or not self._cache[traderId] then
        if callback then callback(false, "not_found") end
        return
    end

    if not INV or not INV:GetItemDef(itemId) then
        if callback then callback(false, "invalid_item") end
        return
    end

    price = math.max(0, math.floor(tonumber(price) or 0))
    sortOrder = math.floor(tonumber(sortOrder) or 0)
    local t2 = self.Config.TableItems
    local query
    if DB:IsMySQL() then
        query = ("INSERT INTO %s (trader_id, item_id, price, sort_order) VALUES (%d, %s, %d, %d) ON DUPLICATE KEY UPDATE price=%d, sort_order=%d"):format(t2, traderId, esc(itemId), price, sortOrder, price, sortOrder)
    else
        query = ("INSERT OR REPLACE INTO %s (trader_id, item_id, price, sort_order) VALUES (%d, %s, %d, %d)"):format(t2, traderId, esc(itemId), price, sortOrder)
    end

    DB:Query(query, function()
        if not self._items[traderId] then self._items[traderId] = {} end
        self._items[traderId][itemId] = {
            price = price,
            sort_order = sortOrder,
        }

        if callback then callback(true) end
    end, function(err)
        logErr("Add item failed:", tostring(err))
        if callback then callback(false, err) end
        return true
    end)
end

function TRADERS:RemoveItem(traderId, itemId, callback)
    traderId = tonumber(traderId)
    if not traderId then
        if callback then callback(false, "invalid_id") end
        return
    end

    local t2 = self.Config.TableItems
    DB:Query(("DELETE FROM %s WHERE trader_id=%d AND item_id=%s"):format(t2, traderId, esc(itemId)), function()
        if self._items[traderId] then self._items[traderId][itemId] = nil end
        if callback then callback(true) end
    end, function(err)
        logErr("Remove item failed:", tostring(err))
        if callback then callback(false, err) end
        return true
    end)
end

function TRADERS:UpdateItemPrice(traderId, itemId, price, callback)
    traderId = tonumber(traderId)
    price = math.max(0, math.floor(tonumber(price) or 0))
    if not traderId or not self._items[traderId] or not self._items[traderId][itemId] then
        if callback then callback(false, "not_found") end
        return
    end

    local t2 = self.Config.TableItems
    DB:Query(("UPDATE %s SET price=%d WHERE trader_id=%d AND item_id=%s"):format(t2, price, traderId, esc(itemId)), function()
        self._items[traderId][itemId].price = price
        if callback then callback(true) end
    end, function(err)
        logErr("Update price failed:", tostring(err))
        if callback then callback(false, err) end
        return true
    end)
end

function TRADERS:GetCatalog(traderId)
    traderId = tonumber(traderId)
    if not traderId or not self._items[traderId] then return {} end
    local catalog = {}
    for itemId, info in pairs(self._items[traderId]) do
        local def = INV and INV:GetItemDef(itemId)
        if def then
            table.insert(catalog, {
                item_id = itemId,
                price = info.price,
                sort_order = info.sort_order,
                name = def.name or itemId,
                icon = def.icon or "",
                rarity = def.rarity or "common",
                category = def.category or "",
                description = def.description or "",
            })
        end
    end

    table.sort(catalog, function(a, b)
        if a.sort_order ~= b.sort_order then return a.sort_order < b.sort_order end
        return a.name < b.name
    end)
    return catalog
end

function TRADERS:GetTraderList()
    local list = {}
    for id, data in pairs(self._cache) do
        table.insert(list, {
            id = data.id,
            name = data.name,
            model = data.model,
            map = data.map,
        })
    end

    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

netstream.Hook(TRADERS.Net.BuyItem, function(ply, traderId, itemId, amount)
    if not IsValid(ply) then return end
    traderId = tonumber(traderId)
    amount   = math.Clamp(math.floor(tonumber(amount) or 1), 1, 100)
    if not traderId or not TRADERS._cache[traderId] then return end
    if not TRADERS._items[traderId] or not TRADERS._items[traderId][itemId] then return end

    local charId = INV:GetCharacterUID(ply)
    if not charId then return end

    -- Busy lock : bloque les achats simultanés du même joueur
    local sid = ply:SteamID()
    if TRADERS._busy[sid] then return end
    TRADERS._busy[sid] = true

    local itemInfo   = TRADERS._items[traderId][itemId]
    local totalPrice = math.max(0, math.floor((itemInfo.price or 0) * amount))

    if not ply:HasMoney(totalPrice) then
        TRADERS._busy[sid] = nil
        if isfunction(ply.Notify) then ply:Notify("Pas assez d'argent !", NOTIFY_ERROR, 3) end
        return
    end

    ply:DeductMoney(totalPrice, function(ok)
        if not ok then
            TRADERS._busy[sid] = nil
            if isfunction(ply.Notify) then ply:Notify("Erreur de débit.", NOTIFY_ERROR, 3) end
            return
        end

        ply:AddItem(itemId, amount, nil, function(itemOk)
            TRADERS._busy[sid] = nil
            if itemOk then
                local def  = INV:GetItemDef(itemId)
                local name = def and def.name or itemId
                local text = amount > 1 and ("Acheté : " .. name .. " x" .. amount) or ("Acheté : " .. name)
                if isfunction(ply.Notify) then ply:Notify(text, NOTIFY_HINT, 3) end
                INV:SendSync(ply, charId)
            else
                -- Remboursement si l'ajout échoue (inventaire plein) — avec confirmation
                ply:AddMoney(totalPrice, function(refundOk)
                    if not refundOk then
                        VERSE.Log:Error("[Traders] REMBOURSEMENT ECHOUE pour " .. ply:Nick() .. " (" .. totalPrice .. " Y, item=" .. tostring(itemId) .. ")")
                    end
                    INV:SendSync(ply, charId)
                end)
                if isfunction(ply.Notify) then ply:Notify("Inventaire plein !", NOTIFY_ERROR, 3) end
            end
        end)
    end)
end)

netstream.Hook(TRADERS.Net.AdminRequest, function(ply)
    if not isAdmin(ply) then return end
    netstream.Start(ply, TRADERS.Net.AdminList, TRADERS:GetTraderList())
end)

netstream.Hook(TRADERS.Net.AdminCreate, function(ply, name, model)
    if not isAdmin(ply) then return end
    if isstring(model) and model ~= "" and not util.IsValidModel(model) then
        if isfunction(ply.Notify) then ply:Notify("Modèle invalide.", NOTIFY_ERROR, 4) end
        return
    end
    local tr = ply:GetEyeTrace()
    local pos = tr.HitPos + Vector(0, 0, 5)
    local ang = Angle(0, (ply:GetPos() - pos):Angle().y, 0)
    TRADERS:Create(name, model, pos, ang, function(ok, traderId)
        if ok then
            logInfo("[Admin] " .. ply:Nick() .. " a créé le marchand '" .. tostring(name) .. "' (id=" .. tostring(traderId) .. ")")
            if isfunction(ply.Notify) then ply:Notify("Marchand créé : " .. tostring(name), NOTIFY_HINT, 3) end
            netstream.Start(ply, TRADERS.Net.AdminList, TRADERS:GetTraderList())
        else
            if isfunction(ply.Notify) then ply:Notify("Erreur lors de la création du marchand.", NOTIFY_ERROR, 3) end
        end
    end)
end)

netstream.Hook(TRADERS.Net.AdminUpdate, function(ply, traderId, data)
    if not isAdmin(ply) then return end
    if not istable(data) then return end
    local newModel = data.model
    if isstring(newModel) and newModel ~= "" and not util.IsValidModel(newModel) then
        if isfunction(ply.Notify) then ply:Notify("Modèle invalide.", NOTIFY_ERROR, 4) end
        return
    end
    logInfo("[Admin] " .. ply:Nick() .. " modifie le marchand #" .. tostring(traderId))
    TRADERS:Update(traderId, data, function(ok) if ok then netstream.Start(ply, TRADERS.Net.AdminList, TRADERS:GetTraderList()) end end)
end)

netstream.Hook(TRADERS.Net.AdminDelete, function(ply, traderId)
    if not isAdmin(ply) then return end
    logInfo("[Admin] " .. ply:Nick() .. " supprime le marchand #" .. tostring(traderId))
    TRADERS:Delete(traderId, function(ok)
        if ok then
            if isfunction(ply.Notify) then ply:Notify("Marchand supprimé.", NOTIFY_HINT, 3) end
            netstream.Start(ply, TRADERS.Net.AdminList, TRADERS:GetTraderList())
        end
    end)
end)

netstream.Hook(TRADERS.Net.AdminGetItems, function(ply, traderId)
    if not isAdmin(ply) then return end
    local catalog = TRADERS:GetCatalog(traderId)
    netstream.Start(ply, TRADERS.Net.AdminSyncItems, traderId, catalog)
end)

netstream.Hook(TRADERS.Net.AdminAddItem, function(ply, traderId, itemId, price, sortOrder)
    if not isAdmin(ply) then return end
    logInfo("[Admin] " .. ply:Nick() .. " ajoute item '" .. tostring(itemId) .. "' prix=" .. tostring(price) .. " au marchand #" .. tostring(traderId))
    TRADERS:AddItem(traderId, itemId, price, sortOrder, function(ok)
        if ok then
            local catalog = TRADERS:GetCatalog(traderId)
            netstream.Start(ply, TRADERS.Net.AdminSyncItems, traderId, catalog)
        end
    end)
end)

netstream.Hook(TRADERS.Net.AdminRemoveItem, function(ply, traderId, itemId)
    if not isAdmin(ply) then return end
    logInfo("[Admin] " .. ply:Nick() .. " retire item '" .. tostring(itemId) .. "' du marchand #" .. tostring(traderId))
    TRADERS:RemoveItem(traderId, itemId, function(ok)
        if ok then
            local catalog = TRADERS:GetCatalog(traderId)
            netstream.Start(ply, TRADERS.Net.AdminSyncItems, traderId, catalog)
        end
    end)
end)

netstream.Hook(TRADERS.Net.AdminUpdateItem, function(ply, traderId, itemId, price)
    if not isAdmin(ply) then return end
    logInfo("[Admin] " .. ply:Nick() .. " modifie prix item '" .. tostring(itemId) .. "' -> " .. tostring(price) .. "Y (marchand #" .. tostring(traderId) .. ")")
    TRADERS:UpdateItemPrice(traderId, itemId, price, function(ok)
        if ok then
            local catalog = TRADERS:GetCatalog(traderId)
            netstream.Start(ply, TRADERS.Net.AdminSyncItems, traderId, catalog)
        end
    end)
end)

netstream.Hook(TRADERS.Net.AdminSavePos, function(ply, traderId)
    if not isAdmin(ply) then return end
    traderId = tonumber(traderId)
    if not traderId or not TRADERS._cache[traderId] then return end

    local ent = TRADERS._entities[traderId]
    if not IsValid(ent) then
        if isfunction(ply.Notify) then ply:Notify("Erreur : entité introuvable.", NOTIFY_ERROR, 3) end
        return
    end

    local pos = ent:GetPos()
    local ang = ent:GetAngles()

    local t1 = TRADERS.Config.TableTraders
    DB:Query(("UPDATE %s SET pos_x=%f, pos_y=%f, pos_z=%f, ang_y=%f WHERE id=%d"):format(
        t1, pos.x, pos.y, pos.z, ang.y, traderId
    ), function()
        local cached = TRADERS._cache[traderId]
        cached.pos = Vector(pos.x, pos.y, pos.z)
        cached.ang = Angle(0, ang.y, 0)
        if isfunction(ply.Notify) then ply:Notify("Position sauvegardée.", NOTIFY_HINT, 3) end
    end, function(err)
        logErr("Save pos failed:", tostring(err))
        if isfunction(ply.Notify) then ply:Notify("Erreur de sauvegarde de la position.", NOTIFY_ERROR, 3) end
        return true
    end)
end)

VERSE.DB:OnReady(function()
    TRADERS:CreateTables()
    timer.Simple(0.5, function() TRADERS:LoadAll() end)
end)

VERSE.Hook.AddNS("Traders", "PostCleanupMap", "VERSE::Traders::PostCleanup", function()
    logInfo("Map cleanup detected, respawning traders...")
    TRADERS:SpawnAll()
end)