local T   = VERSE.Training
local DB  = VERSE.DB
local Log = VERSE.Log
if not T or not DB then return end

T._zones = T._zones or {} -- [id] = { id, name, map, pos=Vector, radius=number }

local cfg = T.Config
local function esc(v) return DB:Escape(tostring(v)) end

-- ─── Table DB ─────────────────────────────────────────────────────────────────

function T:CreateTables()
    local tbl = cfg.TableName
    local q
    if DB:IsMySQL() then
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id         INT NOT NULL AUTO_INCREMENT,
                name       VARCHAR(128) NOT NULL DEFAULT 'Zone d entr',
                map        VARCHAR(64)  NOT NULL,
                pos_x      FLOAT NOT NULL DEFAULT 0,
                pos_y      FLOAT NOT NULL DEFAULT 0,
                pos_z      FLOAT NOT NULL DEFAULT 0,
                radius     FLOAT NOT NULL DEFAULT 500,
                created_at INT NOT NULL,
                PRIMARY KEY (id),
                KEY idx_map (map)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(tbl)
    else
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                name       TEXT    NOT NULL DEFAULT 'Zone',
                map        TEXT    NOT NULL,
                pos_x      REAL    NOT NULL DEFAULT 0,
                pos_y      REAL    NOT NULL DEFAULT 0,
                pos_z      REAL    NOT NULL DEFAULT 0,
                radius     REAL    NOT NULL DEFAULT 500,
                created_at INTEGER NOT NULL
            )
        ]]):format(tbl)
    end

    DB:Query(q, function()
        Log:Info("[Training] Table '" .. tbl .. "' prete.")
        T:LoadZones()
    end, function(err)
        Log:Error("[Training] CreateTables: " .. tostring(err))
        return true
    end)
end

-- ─── Chargement ───────────────────────────────────────────────────────────────

function T:LoadZones()
    local tbl = cfg.TableName
    local currentMap = game.GetMap()
    DB:Query(("SELECT * FROM %s WHERE map=%s"):format(tbl, esc(currentMap)), function(rows)
        self._zones = {}
        rows = rows or {}
        for _, row in ipairs(rows) do
            local id = tonumber(row.id)
            if id then
                self._zones[id] = {
                    id     = id,
                    name   = tostring(row.name or "Zone"),
                    map    = currentMap,
                    pos    = Vector(tonumber(row.pos_x) or 0, tonumber(row.pos_y) or 0, tonumber(row.pos_z) or 0),
                    radius = math.max(50, tonumber(row.radius) or cfg.DefaultRadius),
                }
            end
        end
        local n = table.Count(self._zones)
        Log:Info("[Training] " .. n .. " zone(s) chargee(s) sur " .. currentMap)
        self:SyncAll()
    end, function(err)
        Log:Error("[Training] LoadZones: " .. tostring(err))
        return true
    end)
end

-- ─── Création ─────────────────────────────────────────────────────────────────

function T:CreateZone(name, pos, radius, callback)
    local tbl = cfg.TableName
    local currentMap = game.GetMap()
    radius = math.max(50, math.floor(tonumber(radius) or cfg.DefaultRadius))
    name   = string.sub(tostring(name or "Zone"), 1, 64)

    local q = ("INSERT INTO %s (name, map, pos_x, pos_y, pos_z, radius, created_at) VALUES (%s, %s, %f, %f, %f, %f, %d)"):format(
        tbl, esc(name), esc(currentMap), pos.x, pos.y, pos.z, radius, os.time()
    )
    DB:Query(q, function(_, lastInsert)
        local id = tonumber(lastInsert)
        local finalize = function(fid)
            if not fid or fid <= 0 then
                if callback then callback(false) end
                return
            end
            self._zones[fid] = {
                id     = fid,
                name   = name,
                map    = currentMap,
                pos    = Vector(pos.x, pos.y, pos.z),
                radius = radius,
            }
            self:SyncAll()
            if callback then callback(true, fid) end
        end
        if not id or id <= 0 then
            -- Fallback MySQL : lastInsert parfois non renvoyé par l'adaptateur
            DB:QueryValue(("SELECT MAX(id) FROM %s WHERE map=%s"):format(tbl, esc(currentMap)), function(val)
                finalize(tonumber(val))
            end)
        else
            finalize(id)
        end
    end, function(err)
        Log:Error("[Training] CreateZone: " .. tostring(err))
        if callback then callback(false) end
        return true
    end)
end

-- ─── Suppression ──────────────────────────────────────────────────────────────

function T:DeleteZone(id, callback)
    id = tonumber(id)
    if not id or not self._zones[id] then
        if callback then callback(false, "not_found") end
        return
    end
    local tbl = cfg.TableName
    DB:Query(("DELETE FROM %s WHERE id=%d"):format(tbl, id), function()
        self._zones[id] = nil
        self:SyncAll()
        if callback then callback(true) end
    end, function(err)
        Log:Error("[Training] DeleteZone: " .. tostring(err))
        if callback then callback(false, err) end
        return true
    end)
end

-- ─── Utilitaires ──────────────────────────────────────────────────────────────

function T:GetZoneAt(pos)
    for _, zone in pairs(self._zones) do
        if zone.pos:Distance(pos) <= zone.radius then
            return zone
        end
    end
    return nil
end

-- ─── Sync clients ─────────────────────────────────────────────────────────────

function T:BuildSyncPayload()
    local payload = {}
    for _, zone in pairs(self._zones) do
        payload[#payload + 1] = {
            id     = zone.id,
            name   = zone.name,
            pos    = { x = zone.pos.x, y = zone.pos.y, z = zone.pos.z },
            radius = zone.radius,
        }
    end
    return payload
end

function T:SyncTo(ply)
    if not IsValid(ply) then return end
    netstream.Start(ply, T.Net.Sync, self:BuildSyncPayload())
end

function T:SyncAll()
    local payload = self:BuildSyncPayload()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            netstream.Start(ply, T.Net.Sync, payload)
        end
    end
end

-- ─── Respawn dans la zone ─────────────────────────────────────────────────────

hook.Add("PlayerDeath", "VERSE::Training::InstantRespawn", function(ply, inflictor, attacker)
    if not IsValid(ply) then return end
    local zone = T:GetZoneAt(ply:GetPos())
    if not zone then return end

    -- Sauvegarde de la position exacte du décès
    local deathPos = Vector(ply:GetPos().x, ply:GetPos().y, ply:GetPos().z)

    timer.Simple(cfg.RespawnDelay, function()
        if not IsValid(ply) then return end
        ply:Spawn()
        -- Tick suivant : repositionnement et soins complets
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            ply:SetPos(deathPos)
            ply:SetHealth(ply:GetMaxHealth())
            -- Rechargement de la mana si le système existe
            if isfunction(ply.SetMana) and isfunction(ply.GetManaMax) then
                ply:SetMana(ply:GetManaMax())
            elseif isfunction(ply.SetMana) then
                ply:SetMana(100)
            end
        end)
    end)
end)

-- Sync des zones aux nouveaux joueurs
VERSE.Hook.AddNS("Training", "PlayerInitialSpawn", "VERSE::Training::SyncNew", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then T:SyncTo(ply) end
    end)
end)

-- ─── Commandes admin ──────────────────────────────────────────────────────────
-- verse_trainzone create <nom> <rayon>  → crée une zone à ta position
-- verse_trainzone delete <id>           → supprime la zone par son ID
-- verse_trainzone list                  → liste toutes les zones sur la map
-- verse_trainzone tp <id>               → se téléporte au centre d'une zone

VERSE.Commands.Add("verse_trainzone", function(ply, args)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        if isfunction(ply.Notify) then ply:Notify("Permission refusee.", NOTIFY_ERROR, 3) end
        return
    end

    local action = args[1]

    -- ── create ────────────────────────────────────────────────────────────────
    if action == "create" then
        local name   = args[2] or "Zone d'entrainement"
        local radius = tonumber(args[3]) or cfg.DefaultRadius
        local pos    = ply:GetPos()
        T:CreateZone(name, pos, radius, function(ok, id)
            if ok then
                if isfunction(ply.Notify) then
                    ply:Notify("Zone #" .. id .. " '" .. name .. "' creee (rayon " .. radius .. ")", NOTIFY_HINT, 6)
                end
                Log:Info("[Training] " .. ply:Nick() .. " a cree la zone #" .. id .. " '" .. name .. "' r=" .. radius .. " pos=" .. tostring(pos))
            else
                if isfunction(ply.Notify) then ply:Notify("Erreur lors de la creation.", NOTIFY_ERROR, 3) end
            end
        end)

    -- ── delete ────────────────────────────────────────────────────────────────
    elseif action == "delete" then
        local id = tonumber(args[2])
        if not id then
            if isfunction(ply.Notify) then ply:Notify("Usage: verse_trainzone delete <id>", NOTIFY_HINT, 4) end
            return
        end
        T:DeleteZone(id, function(ok)
            if ok then
                if isfunction(ply.Notify) then ply:Notify("Zone #" .. id .. " supprimee.", NOTIFY_HINT, 3) end
                Log:Info("[Training] " .. ply:Nick() .. " a supprime la zone #" .. id)
            else
                if isfunction(ply.Notify) then ply:Notify("Zone #" .. id .. " introuvable.", NOTIFY_ERROR, 3) end
            end
        end)

    -- ── list ──────────────────────────────────────────────────────────────────
    elseif action == "list" then
        local count = table.Count(T._zones)
        if count == 0 then
            ply:ChatPrint("[Training] Aucune zone d'entrainement sur " .. game.GetMap() .. ".")
            return
        end
        ply:ChatPrint("[Training] " .. count .. " zone(s) sur " .. game.GetMap() .. " :")
        for id, zone in pairs(T._zones) do
            ply:ChatPrint(("  #%d  '%s'  rayon=%.0f  pos=(%.0f, %.0f, %.0f)"):format(
                id, zone.name, zone.radius, zone.pos.x, zone.pos.y, zone.pos.z
            ))
        end

    -- ── tp ────────────────────────────────────────────────────────────────────
    elseif action == "tp" then
        local id = tonumber(args[2])
        local zone = id and T._zones[id]
        if not zone then
            if isfunction(ply.Notify) then ply:Notify("Zone introuvable.", NOTIFY_ERROR, 3) end
            return
        end
        ply:SetPos(zone.pos + Vector(0, 0, 10))
        if isfunction(ply.Notify) then ply:Notify("Teleporte vers la zone #" .. id .. " '" .. zone.name .. "'", NOTIFY_HINT, 3) end

    else
        if isfunction(ply.Notify) then
            ply:Notify("Usage: verse_trainzone <create|delete|list|tp>", NOTIFY_HINT, 5)
        end
        ply:ChatPrint("[Training] Commandes :")
        ply:ChatPrint("  verse_trainzone create <nom> <rayon>  — cree une zone a votre position")
        ply:ChatPrint("  verse_trainzone delete <id>           — supprime une zone")
        ply:ChatPrint("  verse_trainzone list                  — liste les zones de la map")
        ply:ChatPrint("  verse_trainzone tp <id>               — teleporte au centre d'une zone")
    end
end)

-- ─── Init ─────────────────────────────────────────────────────────────────────

DB:OnReady(function()
    T:CreateTables()
end)
