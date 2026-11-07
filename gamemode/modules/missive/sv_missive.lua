local M    = VERSE.Missive
local CH   = VERSE.Characters
local DB   = VERSE.DB
local Chat = VERSE.Chat
if not M or not CH or not DB then return end

-- Envoie un /me visible au-dessus de la tête de l'expéditeur aux joueurs proches
local function broadcastMissiveMe(ply, senderName)
    if not IsValid(ply) then return end
    if not Chat then return end
    local radius = (Chat.Config and (Chat.Config.MERadius or Chat.Config.ICRadius)) or 600
    local posSq  = ply:GetPos()
    local radSq  = radius * radius
    local listeners = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and posSq:DistToSqr(p:GetPos()) <= radSq then
            listeners[#listeners + 1] = p
        end
    end
    if #listeners == 0 then return end
    netstream.Start(listeners, Chat.Net.Message, {
        channel = Chat.CH_ME,
        sender  = ply:SteamID64(),
        name    = senderName,
        text    = "envoie une missive",
        time    = os.date("%H:%M:%S"),
    })
end

local function esc(v) return DB:Escape(tostring(v)) end

local _missiveSendCD = {}
local _missiveListCD = {}
local _missiveReadCD = {}

-- ─── Création de la table (après que la DB soit prête) ───────────────────────
DB:OnReady():Next(function()
    local isMy = DB:IsMySQL()
    VERSE.Log:Info("[Missive] DB ready (MySQL=" .. tostring(isMy) .. ") — creating table if needed")

    local qCreate
    if isMy then
        qCreate = [[
            CREATE TABLE IF NOT EXISTS verse_missives (
                id                INT          NOT NULL AUTO_INCREMENT,
                sender_char_id    INT          NOT NULL,
                recipient_char_id INT          NOT NULL,
                sender_name       VARCHAR(128) NOT NULL DEFAULT '',
                title             VARCHAR(80)  NOT NULL DEFAULT '',
                body              TEXT         NOT NULL,
                is_read           TINYINT      NOT NULL DEFAULT 0,
                created_at        INT          NOT NULL DEFAULT 0,
                PRIMARY KEY (id),
                INDEX idx_missive_recipient (recipient_char_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]
    else
        qCreate = [[
            CREATE TABLE IF NOT EXISTS verse_missives (
                id                INTEGER  PRIMARY KEY AUTOINCREMENT,
                sender_char_id    INTEGER  NOT NULL,
                recipient_char_id INTEGER  NOT NULL,
                sender_name       TEXT     NOT NULL DEFAULT '',
                title             TEXT     NOT NULL DEFAULT '',
                body              TEXT     NOT NULL DEFAULT '',
                is_read           INTEGER  NOT NULL DEFAULT 0,
                created_at        INTEGER  NOT NULL DEFAULT 0
            )
        ]]
    end

    DB:Query(qCreate):Next(function()
        VERSE.Log:Info("[Missive] Table verse_missives OK")
        if not isMy then
            DB:Query([[CREATE INDEX IF NOT EXISTS idx_missive_recipient ON verse_missives (recipient_char_id)]])
            :Catch(function(err)
                VERSE.Log:Warn("[Missive] CREATE INDEX warning: " .. tostring(err))
            end)
        end
    end):Catch(function(err)
        VERSE.Log:Error("[Missive] CREATE TABLE failed: " .. tostring(err))
    end)
end)

-- ─── Lister les missives reçues ───────────────────────────────────────────────
netstream.Hook(M.Net.List, function(ply)
    if not IsValid(ply) then return end

    local now = CurTime()
    local sid = ply:SteamID()
    if (_missiveListCD[sid] or 0) + 3 > now then return end
    _missiveListCD[sid] = now

    -- Utilise l'API officielle CH:GetSelectedCharID qui gère déjà les cas nil/invalid.
    local charId = CH:GetSelectedCharID(ply)
    if not charId or charId <= 0 then
        VERSE.Log:Warn("[Missive] List refusé pour " .. tostring(ply:Nick()) .. " : charId=" .. tostring(charId))
        netstream.Start(ply, M.Net.List, {})
        return
    end

    local q = ("SELECT id, sender_char_id, sender_name, title, body, is_read, created_at "
             .. "FROM verse_missives WHERE recipient_char_id=%d "
             .. "ORDER BY created_at DESC LIMIT %d"):format(charId, M.MaxPerChar)

    DB:Query(q):Next(function(res)
        if not IsValid(ply) then return end
        local rows = (res and res.rows) or {}
        if not istable(rows) then rows = {} end
        local list = {}
        for _, r in ipairs(rows) do
            list[#list + 1] = {
                id             = tonumber(r.id) or 0,
                sender_char_id = tonumber(r.sender_char_id) or 0,
                sender_name    = tostring(r.sender_name or ""),
                title          = tostring(r.title or ""),
                body           = tostring(r.body or ""),
                is_read        = (tonumber(r.is_read) or 0),
                created_at     = tonumber(r.created_at) or 0,
            }
        end
        VERSE.Log:Info("[Missive] List -> " .. #list .. " missive(s) pour charId=" .. charId)
        netstream.Start(ply, M.Net.List, list)
    end):Catch(function(err)
        VERSE.Log:Error("[Missive] List DB error charId=" .. charId .. " : " .. tostring(err))
        if IsValid(ply) then
            netstream.Start(ply, M.Net.List, {})
        end
    end)
end)

-- ─── Envoyer une missive ──────────────────────────────────────────────────────
netstream.Hook(M.Net.Send, function(ply, data)
    if not IsValid(ply) or not istable(data) then return end

    local now = CurTime()
    local sid = ply:SteamID()
    if (_missiveSendCD[sid] or 0) + 5 > now then return end
    _missiveSendCD[sid] = now

    local char = CH:GetSelected(ply)
    if not istable(char) then
        netstream.Start(ply, M.Net.Result, false, "no_character") ; return
    end

    local senderCharId = tonumber(char.id)
    if not senderCharId or senderCharId <= 0 then
        netstream.Start(ply, M.Net.Result, false, "bad_character") ; return
    end

    local recipientCharId = tonumber(data.recipient_char_id)
    if not recipientCharId or recipientCharId <= 0 then
        netstream.Start(ply, M.Net.Result, false, "no_recipient") ; return
    end

    local title = tostring(data.title or ""):sub(1, M.MaxTitleLen):Trim()
    local body  = tostring(data.body  or ""):sub(1, M.MaxBodyLen):Trim()
    if title == "" or body == "" then
        netstream.Start(ply, M.Net.Result, false, "empty") ; return
    end

    local senderName = (tostring(char.firstname or "") .. " " .. tostring(char.lastname or "")):Trim()
    if senderName == "" then senderName = tostring(char.nickname or ply:Nick()) end

    DB:Query("SELECT id FROM verse_characters WHERE id=" .. esc(recipientCharId)):Next(function(res)
        if not IsValid(ply) then return end
        local rows = (res and res.rows) or (istable(res) and res) or {}
        if not rows[1] then
            netstream.Start(ply, M.Net.Result, false, "no_recipient")
            return
        end

        local now = os.time()
        local q = ("INSERT INTO verse_missives "
                 .. "(sender_char_id, recipient_char_id, sender_name, title, body, is_read, created_at) "
                 .. "VALUES (%d, %d, %s, %s, %s, 0, %d)"):format(
            senderCharId, recipientCharId,
            esc(senderName), esc(title), esc(body),
            now
        )

        DB:Query(q):Next(function()
            if not IsValid(ply) then return end
            netstream.Start(ply, M.Net.Result, true)
            -- /me au-dessus de la tête de l'expéditeur
            broadcastMissiveMe(ply, senderName)
            -- Notifier le destinataire s'il est connecté
            for _, p in ipairs(player.GetAll()) do
                if not IsValid(p) then continue end
                local pChar = CH:GetSelected(p)
                if istable(pChar) and tonumber(pChar.id) == recipientCharId then
                    netstream.Start(p, M.Net.Notify, senderName, title)
                    break
                end
            end
        end):Catch(function(err)
            VERSE.Log:Error("[Missive] Send error: " .. tostring(err))
            if IsValid(ply) then netstream.Start(ply, M.Net.Result, false, "db_error") end
        end)
    end):Catch(function(err)
        VERSE.Log:Error("[Missive] Send recipient check error: " .. tostring(err))
        if IsValid(ply) then netstream.Start(ply, M.Net.Result, false, "db_error") end
    end)
end)

-- ─── Notification au chargement du personnage (inter-serveur) ────────────────
VERSE.Hook.AddNS("Missive", "VERSE::Characters::Loaded", "VERSE::Missive::CharacterLoaded", function(ply, char)
    if not IsValid(ply) or not istable(char) then return end
    local charId = tonumber(char.id)
    if not charId or charId <= 0 then return end

    -- Compte les missives non lues
    DB:Query(("SELECT COUNT(*) AS cnt FROM verse_missives WHERE recipient_char_id=%d AND is_read=0"):format(charId))
    :Next(function(res)
        if not IsValid(ply) then return end
        local rows1 = (res and res.rows) or (istable(res) and res) or {}
        local row   = rows1[1]
        local cnt   = tonumber(row and row.cnt) or 0
        if cnt <= 0 then return end

        -- Récupère la plus récente pour l'aperçu
        DB:Query(("SELECT sender_name, title FROM verse_missives WHERE recipient_char_id=%d AND is_read=0 ORDER BY created_at DESC LIMIT 1"):format(charId))
        :Next(function(res2)
            if not IsValid(ply) then return end
            local rows2 = (res2 and res2.rows) or (istable(res2) and res2) or {}
            local r     = rows2[1]
            if not r then return end
            local senderName = tostring(r.sender_name or "?")
            local titleStr   = tostring(r.title or "")
            if cnt > 1 then
                titleStr = titleStr .. "  (+" .. (cnt - 1) .. " autre" .. (cnt > 2 and "s" or "") .. ")"
            end
            netstream.Start(ply, M.Net.Notify, senderName, titleStr)
        end):Catch(function(err)
            VERSE.Log:Error("[Missive] CharLoaded inner query error: " .. tostring(err))
        end)
    end):Catch(function(err)
        VERSE.Log:Error("[Missive] CharLoaded count error: " .. tostring(err))
    end)
end)

-- ─── Commande debug (admin) ──────────────────────────────────────────────────
-- Usage : verse_missive_test <nick_ou_steamid>
-- Insère une missive de test dans la boîte de réception du joueur ciblé.
concommand.Add("verse_missive_test", function(ply, cmd, args)
    local isAdmin = not IsValid(ply) or ply:IsSuperAdmin()
    if not isAdmin then return end
    local targetName = table.concat(args, " ")
    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if p:Nick():lower():find(targetName:lower(), 1, true) or p:SteamID() == targetName or p:SteamID64() == targetName then
            target = p ; break
        end
    end
    if not IsValid(target) then
        MsgN("[Missive] Cible introuvable : " .. tostring(targetName))
        return
    end
    local charId = CH:GetSelectedCharID(target)
    if not charId or charId <= 0 then
        MsgN("[Missive] Le joueur n'a pas de personnage sélectionné")
        return
    end
    local now = os.time()
    local q = ("INSERT INTO verse_missives (sender_char_id, recipient_char_id, sender_name, title, body, is_read, created_at) VALUES (0, %d, %s, %s, %s, 0, %d)"):format(
        charId,
        esc("Système"),
        esc("Test Missive"),
        esc("Ceci est une missive de test envoyée par commande admin."),
        now
    )
    DB:Query(q):Next(function()
        MsgN("[Missive] Missive de test insérée pour " .. target:Nick() .. " (charId=" .. charId .. ")")
        netstream.Start(target, M.Net.Notify, "Système", "Test Missive")
    end):Catch(function(err)
        MsgN("[Missive] Erreur lors de l'insertion : " .. tostring(err))
    end)
end)

-- ─── Nettoyage des cooldowns à la déconnexion ────────────────────────────────
hook.Add("PlayerDisconnected", "VERSE::Missive::CleanupCooldowns", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    _missiveSendCD[sid] = nil
    _missiveListCD[sid] = nil
    _missiveReadCD[sid] = nil
end)

-- ─── Marquer comme lue ────────────────────────────────────────────────────────
netstream.Hook(M.Net.MarkRead, function(ply, missiveId)
    if not IsValid(ply) then return end

    local now = CurTime()
    local sid = ply:SteamID()
    if (_missiveReadCD[sid] or 0) + 1 > now then return end
    _missiveReadCD[sid] = now

    missiveId = tonumber(missiveId)
    if not missiveId then return end
    local char = CH:GetSelected(ply)
    if not istable(char) then return end
    local charId = tonumber(char.id)
    if not charId then return end
    -- Sécurité : on ne peut marquer que ses propres missives
    DB:Query(("UPDATE verse_missives SET is_read=1 WHERE id=%d AND recipient_char_id=%d"):format(missiveId, charId))
end)
