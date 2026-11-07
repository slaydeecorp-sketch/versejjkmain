local PlayTime = VERSE.PlayTime
local DB = VERSE.DB

util.AddNetworkString("VERSE::PlayTime::Sync")

PlayTime._cache = PlayTime._cache or {}

local function sid64(ply)
    if not IsValid(ply) or not ply.SteamID64 then return nil end
    local id = ply:SteamID64()
    if not id or id == "0" or id == "" then return nil end
    return id
end

local function now()
    return os.time()
end

local function getEntryBySID(id)
    PlayTime._cache[id] = PlayTime._cache[id] or {
        total = PlayTime.Config.DefaultTotal or 0,
        join = 0,
        loaded = false,
        lastSaveAt = 0,
    }
    return PlayTime._cache[id]
end

function PlayTime:GetTotalSeconds(ply)
    local id = sid64(ply)
    if not id then return 0 end
    return tonumber(getEntryBySID(id).total) or 0
end

function PlayTime:GetSessionSeconds(ply)
    local id = sid64(ply)
    if not id then return 0 end

    local e = getEntryBySID(id)
    if not e.join or e.join <= 0 then return 0 end

    local s = now() - e.join
    if s < 0 then s = 0 end
    return s
end

function PlayTime:GetCurrentTotalSeconds(ply)
    return self:GetTotalSeconds(ply) + self:GetSessionSeconds(ply)
end

local function sqlEscape(v)
    return DB:Escape(tostring(v or ""))
end

local function ensureTable()
    local tbl = PlayTime.Config.Table or "verse_playtime"

    local q = ([[
        CREATE TABLE IF NOT EXISTS %s (
            steamid64 VARCHAR(32) NOT NULL PRIMARY KEY,
            total_seconds BIGINT NOT NULL,
            last_seen BIGINT NOT NULL
        )
    ]]):format(tbl)

    DB:Query(q):Catch(function(err)
        VERSE.Log:Error("[PlayTime] create table failed: " .. tostring(err))
    end)
end

local function loadTotal(ply)
    local id = sid64(ply)
    if not id then return end

    local tbl = PlayTime.Config.Table or "verse_playtime"
    local e = getEntryBySID(id)
    e.join = now()

    local q = ("SELECT total_seconds FROM %s WHERE steamid64=%s LIMIT 1"):format(tbl, sqlEscape(id))

    DB:Query(q):Next(function(res)
        local data = res.rows or {}
        local total = PlayTime.Config.DefaultTotal or 0

        if data[1] and data[1].total_seconds ~= nil then
            total = tonumber(data[1].total_seconds) or total
        end

        e.total = total
        e.loaded = true
        e.lastSaveAt = now()
        PlayTime:SyncToClient(ply)

        if VERSE.Hook and VERSE.Hook.Run then
            VERSE.Hook.Run("VERSE.PlayTimeLoaded", ply, total)
        end
    end):Catch(function(err)
        VERSE.Log:Error("[PlayTime] load failed: " .. tostring(err))
        e.loaded = true
        PlayTime:SyncToClient(ply)
    end)
end

local function writeTotalBySID(id, totalSeconds)
    local tbl = PlayTime.Config.Table or "verse_playtime"
    totalSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))

    local last = now()
    if DB:IsMySQL() then
        local q = ([[
            INSERT INTO %s (steamid64, total_seconds, last_seen)
            VALUES (%s, %d, %d)
            ON DUPLICATE KEY UPDATE
                total_seconds=VALUES(total_seconds),
                last_seen=VALUES(last_seen)
        ]]):format(tbl, sqlEscape(id), totalSeconds, last)

        DB:Query(q)
        return
    end

    local q = ([[
        REPLACE INTO %s (steamid64, total_seconds, last_seen)
        VALUES (%s, %d, %d)
    ]]):format(tbl, sqlEscape(id), totalSeconds, last)

    DB:Query(q)
end

function PlayTime:Flush(ply, reason)
    local id = sid64(ply)
    if not id then return end

    local e = getEntryBySID(id)
    if not e.join or e.join <= 0 then return end

    local session = now() - e.join
    if session < 0 then session = 0 end

    local newTotal = (tonumber(e.total) or 0) + session
    newTotal = math.max(0, math.floor(newTotal))

    e.total = newTotal
    e.join = now()
    e.lastSaveAt = now()

    writeTotalBySID(id, newTotal)

    if VERSE.Hook and VERSE.Hook.Run then
        VERSE.Hook.Run("VERSE.PlayTimeFlushed", ply, newTotal, reason)
    end
end

function PlayTime:SyncToClient(ply)
    if not IsValid(ply) then return end
    local id = sid64(ply)
    if not id then return end

    local e = getEntryBySID(id)
    local total = tonumber(e.total) or 0
    local session = self:GetSessionSeconds(ply)

    net.Start("VERSE::PlayTime::Sync")
        net.WriteUInt(math.min(total, 0xFFFFFFFF), 32)
        net.WriteUInt(math.min(session, 0xFFFFFFFF), 32)
    net.Send(ply)
end

local function startLoops()
    local ns = "PlayTime"

    -- Sync réduit à 30s (le client n'a pas besoin d'une précision inférieure)
    VERSE.Timers.CreateNS(ns, "Sync", PlayTime.Config.SyncInterval or 30, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                PlayTime:SyncToClient(ply)
            end
        end
    end)

    VERSE.Timers.CreateNS(ns, "Save", PlayTime.Config.SaveInterval or 60, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() ~= nil then
                PlayTime:Flush(ply, "autosave")
            end
        end
    end)
end

DB:OnReady():Next(function()
    ensureTable()
    startLoops()

    for _, ply in ipairs(player.GetAll()) do
        loadTotal(ply)
    end
end)

VERSE.Hook.AddNS("PlayTime", "PlayerInitialSpawn", "VERSE::PlayerInitialSpawn::PlayTime", function(ply)
    local id = sid64(ply)
    if id then
        local e = getEntryBySID(id)
        e.join = now()
    end

    DB:OnReady():Next(function()
        if IsValid(ply) then
            loadTotal(ply)
        end
    end)
end)

VERSE.Hook.AddNS("PlayTime", "PlayerDisconnected", "VERSE::PlayerDisconnected::PlayTime", function(ply)
    PlayTime:Flush(ply, "disconnect")

    local id = sid64(ply)
    if id then
        PlayTime._cache[id] = nil
    end
end)

VERSE.Hook.AddNS("PlayTime", "ShutDown", "VERSE::ShutDown::PlayTime", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            PlayTime:Flush(ply, "shutdown")
        end
    end
end)