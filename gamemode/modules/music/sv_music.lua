local M = VERSE.Music
local DB = VERSE.DB
local Log = VERSE.Log
if not M or not DB then return end
M._areaSources = M._areaSources or {}
M._dbTracks = M._dbTracks or {}
local function esc(v)
    return DB:Escape(v)
end

local function clean(v)
    v = tostring(v or "")
    v = string.Trim(v)
    v = string.Trim(v, '"')
    v = string.Trim(v, "'")
    return v
end

local function logInfo(...)
    if Log and Log.Info then Log:Info("[Music]", ...) end
end

local function logErr(...)
    if Log and Log.Error then Log:Error("[Music]", ...) end
end

local function isStaff(ply)
    return IsValid(ply) and (ply:IsDeveloper() or ply:IsStaff())
end

function M:CreateTable()
    local t = self.Config.TableTracks
    local q
    if DB:IsMySQL() then
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT NOT NULL AUTO_INCREMENT,
                track_id VARCHAR(64) NOT NULL,
                name VARCHAR(128) NOT NULL,
                artist VARCHAR(128) NOT NULL DEFAULT '',
                path VARCHAR(256) NOT NULL,
                category VARCHAR(32) NOT NULL DEFAULT 'chill',
                PRIMARY KEY (id),
                UNIQUE KEY uk_track (track_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(t)
    else
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                track_id TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                artist TEXT NOT NULL DEFAULT '',
                path TEXT NOT NULL,
                category TEXT NOT NULL DEFAULT 'chill'
            )
        ]]):format(t)
    end

    DB:Query(q, nil, function(err)
        logErr("CreateTable failed:", tostring(err))
        return true
    end)
end

function M:SeedTracks()
    local t = self.Config.TableTracks
    for _, tr in ipairs(self._SeedTracks or {}) do
        local q
        if DB:IsMySQL() then
            q = ("INSERT IGNORE INTO %s (track_id, name, artist, path, category) VALUES (%s,%s,%s,%s,%s)"):format(t, esc(tr.id), esc(tr.name), esc(tr.artist or ""), esc(tr.path), esc(tr.category or "chill"))
        else
            q = ("INSERT OR IGNORE INTO %s (track_id, name, artist, path, category) VALUES (%s,%s,%s,%s,%s)"):format(t, esc(tr.id), esc(tr.name), esc(tr.artist or ""), esc(tr.path), esc(tr.category or "chill"))
        end

        DB:Query(q, nil, function(err)
            logErr("Seed failed:", tostring(err))
            return true
        end)
    end
end

function M:LoadTracks(callback)
    local t = self.Config.TableTracks
    DB:Query("SELECT * FROM " .. t .. " ORDER BY id ASC", function(rows)
        local tracks = {}
        for _, row in ipairs(rows or {}) do
            tracks[#tracks + 1] = {
                id = clean(row.track_id),
                dbId = tonumber(row.id),
                name = clean(row.name),
                artist = clean(row.artist or ""),
                path = clean(row.path),
                category = clean(row.category or "chill"),
            }
        end

        self._dbTracks = tracks
        self.Tracks = tracks
        logInfo("Loaded " .. #tracks .. " tracks from DB")
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then netstream.Start(ply, self.Net.TrackList, tracks) end
        end

        if isfunction(callback) then callback(tracks) end
    end, function(err)
        logErr("LoadTracks failed:", tostring(err))
        return true
    end)
end

VERSE.DB:OnReady(function()
    M:CreateTable()
    timer.Simple(0.5, function()
        M:SeedTracks()
        timer.Simple(0.5, function() M:LoadTracks() end)
    end)
end)

VERSE.Hook.AddNS("Music", "PlayerInitialSpawn", "VERSE::Music::SendTracks", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        netstream.Start(ply, M.Net.TrackList, M._dbTracks or M.Tracks)
    end)
end)

netstream.Hook(M.Net.AdminRequest, function(ply)
    if not isStaff(ply) then return end
    netstream.Start(ply, M.Net.TrackList, M._dbTracks or M.Tracks)
end)

netstream.Hook(M.Net.AdminCreate, function(ply, data)
    if not isStaff(ply) then return end
    if not data or not data.track_id or not data.name or not data.path then
        if isfunction(ply.Notify) then ply:Notify("Données manquantes.", NOTIFY_ERROR, 3) end
        return
    end

    local t = M.Config.TableTracks
    local q = ("INSERT INTO %s (track_id, name, artist, path, category) VALUES (%s,%s,%s,%s,%s)"):format(t, esc(clean(data.track_id)), esc(clean(data.name)), esc(clean(data.artist or "")), esc(clean(data.path)), esc(clean(data.category or "chill")))
    DB:Query(q, function()
        logInfo(ply:Nick() .. " created track: " .. data.name)
        if isfunction(ply.Notify) then ply:Notify("OST créé avec succès.", NOTIFY_HINT, 3) end
        M:LoadTracks()
    end, function(err)
        logErr("AdminCreate failed:", tostring(err))
        if isfunction(ply.Notify) then ply:Notify("Erreur lors de la création.", NOTIFY_ERROR, 3) end
        return true
    end)
end)

netstream.Hook(M.Net.AdminUpdate, function(ply, data)
    if not isStaff(ply) then return end
    if not data or not data.dbId then
        if isfunction(ply.Notify) then ply:Notify("Données manquantes.", NOTIFY_ERROR, 3) end
        return
    end

    local t = M.Config.TableTracks
    local dbId = tonumber(data.dbId)
    local q = ("UPDATE %s SET name=%s, artist=%s, path=%s, category=%s WHERE id=%d"):format(t, esc(clean(data.name or "")), esc(clean(data.artist or "")), esc(clean(data.path or "")), esc(clean(data.category or "chill")), dbId)
    DB:Query(q, function()
        logInfo(ply:Nick() .. " updated track #" .. dbId)
        if isfunction(ply.Notify) then ply:Notify("OST mis à jour.", NOTIFY_HINT, 3) end
        M:LoadTracks()
    end, function(err)
        logErr("AdminUpdate failed:", tostring(err))
        if isfunction(ply.Notify) then ply:Notify("Erreur lors de la mise à jour.", NOTIFY_ERROR, 3) end
        return true
    end)
end)

netstream.Hook(M.Net.AdminDelete, function(ply, dbId)
    if not isStaff(ply) then return end
    dbId = tonumber(dbId)
    if not dbId then return end
    local t = M.Config.TableTracks
    DB:Query(("DELETE FROM %s WHERE id=%d"):format(t, dbId), function()
        logInfo(ply:Nick() .. " deleted track #" .. dbId)
        if isfunction(ply.Notify) then ply:Notify("OST supprimé.", NOTIFY_HINT, 3) end
        M:LoadTracks()
    end, function(err)
        logErr("AdminDelete failed:", tostring(err))
        if isfunction(ply.Notify) then ply:Notify("Erreur lors de la suppression.", NOTIFY_ERROR, 3) end
        return true
    end)
end)

netstream.Hook(M.Net.AreaPlay, function(ply, data)
    if not IsValid(ply) then return end
    local trackId = istable(data) and data.trackId or data
    local customRadius = istable(data) and tonumber(data.radius) or nil
    local track = M:GetTrack(trackId)
    if not track then
        if isfunction(ply.Notify) then ply:Notify("Track introuvable.", NOTIFY_ERROR, 3) end
        return
    end

    local pos = ply:GetPos()
    local radius = math.Clamp(customRadius or M.Config.AreaRadius, M.Config.AreaRadiusMin or 500, M.Config.AreaRadiusMax or 3000)
    local radiusSqr = radius * radius

    -- Stoppe toutes les sources existantes qui se chevauchent avec la nouvelle zone
    for sid, src in pairs(M._areaSources) do
        local srcRadius = src.radius or M.Config.AreaRadius
        local checkDist = math.max(radius, srcRadius)
        if src.pos:DistToSqr(pos) <= checkDist * checkDist then
            M._areaSources[sid] = nil
            -- Notifie le propriétaire de la source déplacée (s'il est différent du nouveau diffuseur)
            if IsValid(src.ply) and src.ply ~= ply and isfunction(src.ply.Notify) then
                src.ply:Notify("Votre OST de zone a été remplacé par " .. ply:Nick() .. ".", NOTIFY_HINT, 4)
            end
            -- Envoie AreaStop à tous les joueurs dans la zone de l'ancienne source
            local stopRadiusSqr = srcRadius * srcRadius
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and src.pos:DistToSqr(p:GetPos()) <= stopRadiusSqr then
                    if p._musicAreaIn then p._musicAreaIn[sid] = nil end
                    netstream.Start(p, M.Net.AreaStop, { sourceId = sid })
                end
            end
        end
    end

    local sid = ply:SteamID64()
    M._areaSources[sid] = {
        ply = ply,
        trackId = trackId,
        pos = pos,
        radius = radius,
        startTime = CurTime(),
    }

    local targets = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and pos:DistToSqr(p:GetPos()) <= radiusSqr then
            targets[#targets + 1] = p
            p._musicAreaIn = p._musicAreaIn or {}
            p._musicAreaIn[sid] = true
        end
    end

    netstream.Start(targets, M.Net.AreaPlay, {
        trackId = trackId,
        sourceId = sid,
        pos = {
            x = pos.x,
            y = pos.y,
            z = pos.z
        },
        radius = radius,
    })

    Log:Info("[Music] " .. ply:Nick() .. " started area OST: " .. track.name .. " (radius: " .. radius .. ")")
end)

netstream.Hook(M.Net.AreaStop, function(ply, sourceId)
    if not IsValid(ply) then return end
    sourceId = sourceId or ply:SteamID64()
    local src = M._areaSources[sourceId]
    if not src then return end
    if src.ply ~= ply and not (ply.IsDeveloper and ply:IsDeveloper()) then
        if isfunction(ply.Notify) then ply:Notify("Vous ne pouvez pas arrêter cet OST.", NOTIFY_ERROR, 3) end
        return
    end

    M._areaSources[sourceId] = nil
    local pos = src.pos
    local radius = src.radius or M.Config.AreaRadius
    local radiusSqr = radius * radius
    local targets = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and pos:DistToSqr(p:GetPos()) <= radiusSqr then targets[#targets + 1] = p end
    end

    netstream.Start(targets, M.Net.AreaStop, {
        sourceId = sourceId
    })

    Log:Info("[Music] " .. ply:Nick() .. " stopped area OST")
end)

timer.Create("VERSE::Music::AreaSync", M.Config.AreaTickRate or 0.5, 0, function()
    for sid, src in pairs(M._areaSources) do
        if not IsValid(src.ply) or (CurTime() - src.startTime > 1800) then
            M._areaSources[sid] = nil
            for _, p in ipairs(player.GetAll()) do
                netstream.Start(p, M.Net.AreaStop, {
                    sourceId = sid
                })
            end
        end
    end

    for sid, src in pairs(M._areaSources) do
        if IsValid(src.ply) then src.pos = src.ply:GetPos() end
    end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local plyPos = ply:GetPos()
        for sid, src in pairs(M._areaSources) do
            local radius = src.radius or M.Config.AreaRadius
            local radiusSqr = radius * radius
            local inRange = src.pos:DistToSqr(plyPos) <= radiusSqr
            ply._musicAreaIn = ply._musicAreaIn or {}
            if inRange and not ply._musicAreaIn[sid] then
                ply._musicAreaIn[sid] = true
                local elapsed = CurTime() - src.startTime
                netstream.Start(ply, M.Net.AreaSync, {
                    trackId = src.trackId,
                    sourceId = sid,
                    pos = {
                        x = src.pos.x,
                        y = src.pos.y,
                        z = src.pos.z
                    },
                    radius = radius,
                    elapsed = elapsed,
                })
            elseif not inRange and ply._musicAreaIn[sid] then
                ply._musicAreaIn[sid] = nil
                netstream.Start(ply, M.Net.AreaStop, {
                    sourceId = sid
                })
            end
        end
    end
end)

VERSE.Hook.AddNS("Music", "PlayerDisconnected", "VERSE::Music::Cleanup", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if M._areaSources[sid] then
        M._areaSources[sid] = nil
        for _, p in ipairs(player.GetAll()) do
            netstream.Start(p, M.Net.AreaStop, {
                sourceId = sid
            })
        end
    end
end)

netstream.Hook(M.Net.AreaResync, function(ply)
    if not IsValid(ply) then return end
    local plyPos = ply:GetPos()
    for sid, src in pairs(M._areaSources) do
        if src.ply == ply then continue end
        local radius = src.radius or M.Config.AreaRadius
        if src.pos:DistToSqr(plyPos) <= radius * radius then
            local elapsed = CurTime() - src.startTime
            ply._musicAreaIn = ply._musicAreaIn or {}
            ply._musicAreaIn[sid] = true
            netstream.Start(ply, M.Net.AreaSync, {
                trackId = src.trackId,
                sourceId = sid,
                pos = { x = src.pos.x, y = src.pos.y, z = src.pos.z },
                radius = radius,
                elapsed = elapsed,
            })
        end
    end
end)

VERSE.Commands.Add("verse_ost_forceplay", function(ply, args)
    local nameQuery = args[1]
    local trackIdx = tonumber(args[2]) or 1
    local radius = tonumber(args[3]) or M.Config.AreaRadius
    if not nameQuery then
        if isfunction(ply.Notify) then ply:Notify("Usage: verse_ost_forceplay <name> <track_index> [radius]", NOTIFY_ERROR, 5) end
        return
    end

    local target
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(nameQuery), 1, true) then
            target = p
            break
        end
    end

    if not IsValid(target) then
        if isfunction(ply.Notify) then ply:Notify("Joueur introuvable: " .. nameQuery, NOTIFY_ERROR, 3) end
        return
    end

    local tracks = M._dbTracks or M.Tracks or {}
    local track = tracks[trackIdx]
    if not track then
        if isfunction(ply.Notify) then ply:Notify("Track #" .. trackIdx .. " introuvable. Total: " .. #tracks, NOTIFY_ERROR, 3) end
        return
    end

    radius = math.Clamp(radius, M.Config.AreaRadiusMin or 500, M.Config.AreaRadiusMax or 3000)
    local pos = target:GetPos()
    local sid = "force_" .. target:SteamID64() .. "_" .. os.time()
    for existSid, src in pairs(M._areaSources) do
        if src.ply == target then
            M._areaSources[existSid] = nil
            for _, p in ipairs(player.GetAll()) do
                netstream.Start(p, M.Net.AreaStop, {
                    sourceId = existSid
                })
            end
        end
    end

    M._areaSources[sid] = {
        ply = target,
        trackId = track.id,
        pos = pos,
        radius = radius,
        startTime = CurTime(),
    }

    local radiusSqr = radius * radius
    local targets = {}
    local added = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and pos:DistToSqr(p:GetPos()) <= radiusSqr then
            targets[#targets + 1] = p
            added[p] = true
            p._musicAreaIn = p._musicAreaIn or {}
            p._musicAreaIn[sid] = true
        end
    end

    if IsValid(ply) and not added[ply] then
        targets[#targets + 1] = ply
        ply._musicAreaIn = ply._musicAreaIn or {}
        ply._musicAreaIn[sid] = true
    end

    netstream.Start(targets, M.Net.AreaPlay, {
        trackId = track.id,
        sourceId = sid,
        pos = {
            x = pos.x,
            y = pos.y,
            z = pos.z
        },
        radius = radius,
    })

    if isfunction(ply.Notify) then ply:Notify("OST '" .. track.name .. "' forcé sur " .. target:Nick() .. " (radius: " .. radius .. ")", NOTIFY_HINT, 5) end
    Log:Info("[Music] " .. ply:Nick() .. " force-played '" .. track.name .. "' on " .. target:Nick())
end, "developer", "server")