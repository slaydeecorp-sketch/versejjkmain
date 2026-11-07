local Bell = VERSE.Bell
local CFG = Bell.Config

util.AddNetworkString(Bell.Net.Display)

if CFG.Sound and CFG.Sound ~= "" then resource.AddSingleFile("sound/" .. CFG.Sound) end
resource.AddSingleFile("materials/hud_bellsender.png")
resource.AddSingleFile("materials/hud_bellreceiver.png")

Bell._cooldowns = Bell._cooldowns or {}

function Bell:OpenFor(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsValid(ent) or ent:GetClass() ~= "verse_bell" then return end
    netstream.Start(ply, Bell.Net.Open, ent)
end

local function broadcastLocal(payload, faction)
    local recipients = {}
    for _, recv in ipairs(player.GetAll()) do
        if IsValid(recv) and Bell.GetFaction(recv) == faction then
            recipients[#recipients + 1] = recv
        end
    end
    if #recipients == 0 then return end

    net.Start(Bell.Net.Display)
    net.WriteTable(payload)
    net.Send(recipients)
end

function Bell:Broadcast(author, faction, message, opts)
    opts = opts or {}
    local payload = {
        author      = tostring(author or ""),
        factionName = Bell.GetFactionName(faction),
        message     = tostring(message or ""),
    }

    broadcastLocal(payload, faction)

    if opts.cross then
        Bell:SendCrossServer({
            author      = payload.author,
            faction     = tostring(faction or ""),
            factionName = payload.factionName,
            message     = payload.message,
        })
    end
end

local TABLE  = CFG.CrossServer.TableName
local TAG    = CFG.CrossServer.ServerTag
Bell._lastId = Bell._lastId or 0

local function dbReady()
    return VERSE.DB and VERSE.DB:IsReady() and VERSE.DB:IsMySQL()
end

function Bell:SendCrossServer(payload)
    if not dbReady() then return end
    local DB = VERSE.DB
    local sql = string.format(
        "INSERT INTO %s (origin, author, faction, faction_name, message) VALUES (%s, %s, %s, %s, %s)",
        TABLE,
        DB:Escape(TAG),
        DB:Escape(payload.author or ""),
        DB:Escape(payload.faction or ""),
        DB:Escape(payload.factionName or ""),
        DB:Escape(payload.message or ""))
    DB:Query(sql, nil, function(err)
        VERSE.Log:Warn("[Bell] cross-server INSERT failed: " .. tostring(err))
    end)
end

function Bell:IngestCrossServer(row)
    if not istable(row) then return end
    local faction = tostring(row.faction or "")
    if faction == "" then return end

    broadcastLocal({
        author      = tostring(row.author or "?"),
        factionName = tostring(row.faction_name or row.factionName or Bell.GetFactionName(faction)),
        message     = tostring(row.message or ""),
    }, faction)
end

local function pollCrossServer()
    if not dbReady() then return end
    local DB = VERSE.DB
    local sql = string.format(
        "SELECT id, origin, author, faction, faction_name, message, UNIX_TIMESTAMP(created_at) AS ts FROM %s WHERE id > %d AND origin <> %s ORDER BY id ASC LIMIT 50",
        TABLE, Bell._lastId, DB:Escape(TAG))

    DB:Query(sql, function(rows)
        if not istable(rows) then return end
        for _, row in ipairs(rows) do
            local rid = tonumber(row.id) or 0
            if rid > Bell._lastId then Bell._lastId = rid end
            Bell:IngestCrossServer(row)
        end
    end, function(err)
        VERSE.Log:Warn("[Bell] cross-server SELECT failed: " .. tostring(err))
    end)
end

local function cleanupOld()
    if not dbReady() then return end
    local ttl = math.max(60, CFG.CrossServer.TTLSeconds or 300)
    VERSE.DB:Query(string.format(
        "DELETE FROM %s WHERE created_at < (NOW() - INTERVAL %d SECOND)", TABLE, ttl))
end

VERSE.DB:OnReady(function()
    if not VERSE.DB:IsMySQL() then
        VERSE.Log:Warn("[Bell] cross-server disabled: DB is not MySQL (SQLite fallback active)")
        return
    end

    VERSE.DB:Query(string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            id           BIGINT AUTO_INCREMENT PRIMARY KEY,
            origin       VARCHAR(64)  NOT NULL,
            author       VARCHAR(64)  NOT NULL,
            faction      VARCHAR(64)  NOT NULL,
            faction_name VARCHAR(128) NOT NULL DEFAULT '',
            message      TEXT         NOT NULL,
            created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_id (id),
            INDEX idx_origin (origin)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], TABLE), function()
        VERSE.DB:QueryValue(string.format("SELECT COALESCE(MAX(id), 0) FROM %s", TABLE), function(maxId)
            Bell._lastId = tonumber(maxId) or 0
            VERSE.Log:Info(("[Bell] cross-server ready (table=%s, lastId=%d)"):format(TABLE, Bell._lastId))
        end)

        timer.Create("VERSE::Bell::Poll",    math.max(1, CFG.CrossServer.PollInterval or 3), 0, pollCrossServer)
        timer.Create("VERSE::Bell::Cleanup", 60, 0, cleanupOld)
    end, function(err)
        VERSE.Log:Error("[Bell] CREATE TABLE failed: " .. tostring(err))
    end)
end)

netstream.Hook(Bell.Net.Send, function(ply, entIdx, message, cross)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local ent = Entity(tonumber(entIdx) or -1)
    if not IsValid(ent) or ent:GetClass() ~= "verse_bell" then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > CFG.UseRange * CFG.UseRange then return end

    local sid = ply:SteamID64() or "?"
    local now = CurTime()
    if now - (Bell._cooldowns[sid] or 0) < CFG.Cooldown then
        ply:Notify("Cloche : patiente avant de réessayer.", NOTIFY_ERROR, 4)
        return
    end

    local text = string.Trim(tostring(message or ""))
    if text == "" then return end
    if #text > CFG.MaxLength then text = string.sub(text, 1, CFG.MaxLength) end
    text = string.gsub(text, "%c", "")
    if text == "" then return end

    local faction = Bell.GetFaction(ply)
    if faction == "" then
        ply:Notify("Cloche : aucune faction.", NOTIFY_ERROR, 4)
        return
    end

    Bell._cooldowns[sid] = now
    Bell:Broadcast(ply:Nick(), faction, text, { cross = cross == true })
end)

-- Nettoyage du cooldown au déconnect (évite l'accumulation d'entrées mortes).
hook.Add("PlayerDisconnected", "VERSE::Bell::CleanupCooldown", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if sid then Bell._cooldowns[sid] = nil end
end)
