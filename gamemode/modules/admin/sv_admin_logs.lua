-- sv_admin_logs.lua
-- Journalisation des actions administratives (classes, points, branches, rangs).
-- Table MySQL/SQLite : verse_admin_logs
-- API publique : VERSE.AdminLogs:Log(adminPly, targetPly, action, oldValue, newValue)
--                VERSE.AdminLogs:GetRecent(limit, targetSid64, callback)
-- ─────────────────────────────────────────────────────────────────────────────

VERSE.AdminLogs = VERSE.AdminLogs or {}
local AL         = VERSE.AdminLogs
local DB         = VERSE.DB
local TABLE_NAME = "verse_admin_logs"

-- ─── Création de la table ─────────────────────────────────────────────────────
DB:OnReady(function()
    local isMy = DB:IsMySQL()
    local q

    if isMy then
        q = [[
            CREATE TABLE IF NOT EXISTS verse_admin_logs (
                id               INT          NOT NULL AUTO_INCREMENT,
                admin_steamid64  VARCHAR(32)  NOT NULL,
                admin_name       VARCHAR(64)  NOT NULL,
                target_steamid64 VARCHAR(32)  NOT NULL,
                target_name      VARCHAR(64)  NOT NULL,
                action           VARCHAR(64)  NOT NULL,
                old_value        VARCHAR(256) NOT NULL DEFAULT '',
                new_value        VARCHAR(256) NOT NULL DEFAULT '',
                created_at       INT          NOT NULL,
                PRIMARY KEY (id),
                INDEX idx_target  (target_steamid64),
                INDEX idx_admin   (admin_steamid64),
                INDEX idx_action  (action),
                INDEX idx_created (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]
    else
        q = [[
            CREATE TABLE IF NOT EXISTS verse_admin_logs (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                admin_steamid64  TEXT    NOT NULL,
                admin_name       TEXT    NOT NULL,
                target_steamid64 TEXT    NOT NULL,
                target_name      TEXT    NOT NULL,
                action           TEXT    NOT NULL,
                old_value        TEXT    NOT NULL DEFAULT '',
                new_value        TEXT    NOT NULL DEFAULT '',
                created_at       INTEGER NOT NULL
            )
        ]]
    end

    DB:Query(q, function()
        VERSE.Log:Info("[AdminLogs] Table '" .. TABLE_NAME .. "' initialisee.")
    end, function(err)
        VERSE.Log:Error("[AdminLogs] Erreur creation table : " .. tostring(err))
        return true
    end)
end)

-- ─── Écriture ────────────────────────────────────────────────────────────────
-- adminPly  : joueur admin (ou nil/invalid pour "SERVER")
-- targetPly : joueur ciblé (ou nil/invalid pour "unknown")
-- action    : identifiant de l'action (ex : "st_setclass")
-- oldValue  : valeur avant l'action (string)
-- newValue  : valeur après l'action (string)
function AL:Log(adminPly, targetPly, action, oldValue, newValue)
    local adminSid64 = IsValid(adminPly)  and adminPly:SteamID64()  or "SERVER"
    local adminName  = IsValid(adminPly)  and adminPly:Nick()       or "SERVER"
    local targetSid64 = IsValid(targetPly) and targetPly:SteamID64() or "unknown"
    local targetName  = IsValid(targetPly) and targetPly:Nick()      or "unknown"

    local q = ("INSERT INTO %s (admin_steamid64, admin_name, target_steamid64, target_name, action, old_value, new_value, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s, %d)"):format(
        TABLE_NAME,
        DB:Escape(adminSid64),
        DB:Escape(adminName),
        DB:Escape(targetSid64),
        DB:Escape(targetName),
        DB:Escape(tostring(action   or "")),
        DB:Escape(tostring(oldValue or "?")),
        DB:Escape(tostring(newValue or "?")),
        os.time()
    )

    DB:Query(q, nil, function(err)
        VERSE.Log:Error("[AdminLogs] Erreur ecriture log : " .. tostring(err))
        return true
    end)
end

-- ─── Lecture ──────────────────────────────────────────────────────────────────
-- limit       : nombre max de lignes (1–200)
-- targetSid64 : filtre par SteamID64 cible (nil = tous)
-- callback(rows) : rows est une table de lignes DB ou {} en cas d'erreur
function AL:GetRecent(limit, targetSid64, callback)
    limit = math.Clamp(math.floor(tonumber(limit) or 20), 1, 200)

    local where = ""
    if targetSid64 and tostring(targetSid64) ~= "" then
        where = " WHERE target_steamid64=" .. DB:Escape(tostring(targetSid64))
    end

    local q = ("SELECT * FROM %s%s ORDER BY created_at DESC LIMIT %d"):format(
        TABLE_NAME, where, limit
    )

    DB:Query(q, function(rows)
        if callback then callback(rows or {}) end
    end, function(err)
        VERSE.Log:Warn("[AdminLogs] Erreur lecture logs : " .. tostring(err))
        if callback then callback({}) end
        return true
    end)
end
