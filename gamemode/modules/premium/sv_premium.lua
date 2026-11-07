-- ─── Premium subscription – server ──────────────────────────────────────────
-- Commandes console (appelées par Tebex) :
--   verse_premium_give   <steamid64> <tier>   → active / renouvelle l'abonnement
--   verse_premium_revoke <steamid64>           → révoque l'abonnement
--
-- Paliers :
--   1 → Premium I   (14,99 €) : 1 250 coins/mois
--   2 → Premium II  (39,99 €) : 3 750 coins/mois
--   3 → Premium III (69,99 €) : 8 000 coins/mois
--
-- Tous les paliers donnent : Coupe Fille + ×1,5 EXP + 1 slot personnage.
--
-- Sync cross-serveur :
--   • Connexion  → requête DB directe (jamais le cache seul).
--   • Toutes les 5 min → rechargement complet du cache + sync des joueurs en ligne.
-- ─────────────────────────────────────────────────────────────────────────────

local PR = VERSE.Premium
local DB = VERSE.DB
local CH = VERSE.Characters

if not DB then return end

-- Cache : steamid64 (string) → { expires_at = number, tier = number }
PR._cache = PR._cache or {}

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function esc(v) return DB:Escape(tostring(v or "")) end

local function findOnline(steamid64)
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:SteamID64() == steamid64 then return p end
    end
end

-- Positionne le NWInt du palier (0 = pas premium).
local function setNW(ply, tier)
    if IsValid(ply) then ply:SetNWInt(PR.NW, math.Clamp(math.floor(tonumber(tier) or 0), 0, 3)) end
end

local function validTier(t)
    t = math.floor(tonumber(t) or 0)
    return t >= 1 and t <= 3 and t or nil
end

-- ─── Chargement du cache ─────────────────────────────────────────────────────

local function loadCache(cb)
    DB:Query("SELECT steamid64, expires_at, tier FROM verse_premium", function(rows)
        PR._cache = {}
        for _, row in ipairs(rows or {}) do
            local sid = tostring(row.steamid64 or "")
            local exp = tonumber(row.expires_at) or 0
            local t   = validTier(row.tier) or 1
            if sid ~= "" and exp > 0 then
                PR._cache[sid] = { expires_at = exp, tier = t }
            end
        end
        VERSE.Log:Info("[Premium] " .. table.Count(PR._cache) .. " abonne(s) charges.")
        if cb then cb() end
    end, function(err)
        VERSE.Log:Error("[Premium] Chargement cache erreur : " .. tostring(err))
    end)
end

-- ─── Schéma DB ───────────────────────────────────────────────────────────────

local function createTable()
    local q
    if DB:IsMySQL() then
        q = [[
            CREATE TABLE IF NOT EXISTS verse_premium (
                steamid64  VARCHAR(32) NOT NULL PRIMARY KEY,
                tier       TINYINT     NOT NULL DEFAULT 1,
                granted_at INTEGER     NOT NULL,
                granted_by VARCHAR(64) NOT NULL DEFAULT 'console',
                expires_at BIGINT      NOT NULL DEFAULT 0
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    else
        q = [[
            CREATE TABLE IF NOT EXISTS verse_premium (
                steamid64  TEXT    NOT NULL PRIMARY KEY,
                tier       INTEGER NOT NULL DEFAULT 1,
                granted_at INTEGER NOT NULL,
                granted_by TEXT    NOT NULL DEFAULT 'console',
                expires_at INTEGER NOT NULL DEFAULT 0
            );
        ]]
    end

    DB:Query(q, function()
        VERSE.Log:Info("[Premium] Table verse_premium prête.")
        -- Migrations pour tables existantes sans colonne tier ou expires_at.
        local migrations = {}
        if DB:IsMySQL() then
            migrations = {
                "ALTER TABLE verse_premium ADD COLUMN IF NOT EXISTS expires_at BIGINT  NOT NULL DEFAULT 0",
                "ALTER TABLE verse_premium ADD COLUMN IF NOT EXISTS tier       TINYINT NOT NULL DEFAULT 1",
            }
        else
            migrations = {
                "ALTER TABLE verse_premium ADD COLUMN expires_at INTEGER NOT NULL DEFAULT 0",
                "ALTER TABLE verse_premium ADD COLUMN tier       INTEGER NOT NULL DEFAULT 1",
            }
        end
        local function runNext(i)
            if i > #migrations then loadCache() return end
            DB:Query(migrations[i], function() runNext(i + 1) end, function() runNext(i + 1) end)
        end
        runNext(1)
    end, function(err)
        VERSE.Log:Error("[Premium] CreateTable erreur : " .. tostring(err))
    end)
end

DB:OnReady(function() createTable() end)

-- ─── Sync à la connexion ─────────────────────────────────────────────────────
-- Toujours interroger la DB : le cache RAM peut être périmé si le premium a
-- été accordé sur un autre serveur depuis le dernier rechargement.

hook.Add("PlayerInitialSpawn", "VERSE::Premium::Sync", function(ply)
    local sid = ply:SteamID64()
    DB:Query("SELECT expires_at, tier FROM verse_premium WHERE steamid64=" .. esc(sid),
    function(rows)
        if not IsValid(ply) then return end
        local row    = rows and rows[1]
        local exp    = row and tonumber(row.expires_at) or 0
        local t      = validTier(row and row.tier) or 1
        local active = exp > os.time()
        if active then
            PR._cache[sid] = { expires_at = exp, tier = t }
            setNW(ply, t)
        else
            PR._cache[sid] = nil
            setNW(ply, 0)
        end
    end,
    function(err)
        -- Fallback sur le cache si la requête échoue.
        VERSE.Log:Warn("[Premium] Sync join DB erreur pour " .. sid .. " : " .. tostring(err))
        local entry = PR._cache[sid]
        local tier  = (istable(entry) and entry.expires_at > os.time()) and entry.tier or 0
        setNW(ply, tier)
    end)
end)

-- ─── Rechargement périodique ─────────────────────────────────────────────────
-- Toutes les 5 min : recharge le cache complet depuis la DB pour capter les
-- grants cross-serveur et révoquer les expirations en cours de session.

local function refreshCacheAndSync()
    loadCache(function()
        local now = os.time()
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:IsPlayer() then continue end
            local sid   = ply:SteamID64()
            local entry = PR._cache[sid]
            local tier  = (istable(entry) and entry.expires_at > now) and entry.tier or 0
            setNW(ply, tier)
            if tier == 0 and istable(entry) then
                -- Expiration détectée pour ce joueur en ligne.
                PR._cache[sid] = nil
                ply:ChatPrint("[Premium] Votre abonnement Premium a expiré. Merci de le renouveler sur la boutique !")
                VERSE.Log:Info("[Premium] Abonnement expiré pour " .. sid)
            end
        end
    end)
end

timer.Create("VERSE::Premium::ExpiryCheck", 300, 0, refreshCacheAndSync)

-- ─── Grant / Renewal ─────────────────────────────────────────────────────────

function PR:Give(steamid64, tier, grantedBy, callback)
    steamid64 = tostring(steamid64 or ""):Trim()
    if steamid64 == "" then
        if callback then callback(false, "bad_steamid") end
        return
    end

    tier = validTier(tier)
    if not tier then
        if callback then callback(false, "bad_tier") end
        return
    end

    grantedBy = tostring(grantedBy or "console")

    local now      = os.time()
    local existing = PR._cache[steamid64]
    local prevExp  = istable(existing) and existing.expires_at or nil
    local isNew    = (prevExp == nil or prevExp <= now)

    -- Renouvellement anticipé : prolonge depuis l'expiration courante.
    local tierCfgGive = PR.Tiers[tier]
    local base        = (prevExp and prevExp > now) and prevExp or now
    local newExpiry   = base + (tierCfgGive and tierCfgGive.duration_secs or 30 * 24 * 3600)

    local q
    if DB:IsMySQL() then
        q = ("INSERT INTO verse_premium (steamid64, tier, granted_at, granted_by, expires_at) VALUES (%s, %d, %d, %s, %d) ON DUPLICATE KEY UPDATE tier=%d, granted_at=%d, granted_by=%s, expires_at=%d")
            :format(esc(steamid64), tier, now, esc(grantedBy), newExpiry,
                    tier, now, esc(grantedBy), newExpiry)
    else
        q = ("INSERT OR REPLACE INTO verse_premium (steamid64, tier, granted_at, granted_by, expires_at) VALUES (%s, %d, %d, %s, %d)")
            :format(esc(steamid64), tier, now, esc(grantedBy), newExpiry)
    end

    DB:Query(q, function()
        PR._cache[steamid64] = { expires_at = newExpiry, tier = tier }

        local tierCfg   = PR.Tiers[tier]
        local tierName  = tierCfg and tierCfg.name or ("Premium " .. tier)
        local expiryStr = os.date("%d/%m/%Y", newExpiry)
        local target    = findOnline(steamid64)

        if IsValid(target) then
            setNW(target, tier)
            if isNew then
                target:ChatPrint(("[Premium] %s activé ! (+%.0f%% EXP, +%d coins) – Expire le %s")
                    :format(tierName, (tierCfg.exp_mult - 1) * 100, tierCfg.coins, expiryStr))
            else
                target:ChatPrint(("[Premium] %s renouvelé ! Nouveau terme : %s")
                    :format(tierName, expiryStr))
            end
        end

        if callback then callback(true, isNew, newExpiry, tier) end
    end, function(err)
        VERSE.Log:Error("[Premium] Give DB erreur : " .. tostring(err))
        if callback then callback(false, err) end
    end)
end

-- ─── Commande verse_premium_give ─────────────────────────────────────────────
-- Usage (Tebex) :
--   verse_premium_give {id} 1   → Premium I
--   verse_premium_give {id} 2   → Premium II
--   verse_premium_give {id} 3   → Premium III

VERSE.Commands.Add("verse_premium_give", function(ply, args)
    if IsValid(ply) then
        ply:ChatPrint("[Premium] Console uniquement.")
        return
    end

    local rawId  = tostring(args[1] or ""):Trim()
    local rawTier = tostring(args[2] or ""):Trim()

    if rawId == "" or rawTier == "" then
        print("[Premium] Usage : verse_premium_give <steamid64> <tier>")
        print("[Premium] Exemple : verse_premium_give 76561198XXXXXXXXX 1")
        return
    end

    if not string.match(rawId, "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
        print("[Premium] SteamID64 invalide : " .. rawId)
        return
    end

    local tier = validTier(rawTier)
    if not tier then
        print("[Premium] Palier invalide : " .. rawTier .. " (attendu : 1, 2 ou 3)")
        return
    end

    PR:Give(rawId, tier, "tebex", function(ok, isNew, newExpiry, t)
        if not ok then
            print("[Premium] ERREUR grant : " .. tostring(newExpiry))
            return
        end

        local tierCfg   = PR.Tiers[t]
        local expiryStr = os.date("%d/%m/%Y %H:%M", newExpiry)
        local action    = isNew and "accordé" or "renouvelé"
        print(("[Premium] %s %s à %s. Expire le %s."):format(tierCfg.name, action, rawId, expiryStr))

        -- Coins boutique selon le palier.
        local BT = VERSE and VERSE.Boutique
        if BT and BT.AddCoinsBySteamID then
            local steamId = util.SteamIDFrom64(rawId)
            BT:AddCoinsBySteamID(steamId, tierCfg.coins, "premium_activation", function(coinsOk, balOrErr)
                if coinsOk then
                    print(("[Premium] +%d coins boutique → %s."):format(tierCfg.coins, rawId))
                else
                    print("[Premium] ERREUR coins boutique : " .. tostring(balOrErr))
                end
            end)
        else
            print("[Premium] Avertissement : VERSE.Boutique non disponible, coins non attribués.")
        end
    end)
end)

-- ─── Commande verse_premium_revoke ───────────────────────────────────────────
-- Usage : verse_premium_revoke <steamid64>

VERSE.Commands.Add("verse_premium_revoke", function(ply, args)
    if IsValid(ply) then
        ply:ChatPrint("[Premium] Console uniquement.")
        return
    end

    local rawId = tostring(args[1] or ""):Trim()
    if rawId == "" then
        print("[Premium] Usage : verse_premium_revoke <steamid64>")
        return
    end

    if not string.match(rawId, "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
        print("[Premium] SteamID64 invalide : " .. rawId)
        return
    end

    PR._cache[rawId] = nil
    DB:Query("DELETE FROM verse_premium WHERE steamid64=" .. esc(rawId),
    function()
        print("[Premium] Premium révoqué pour " .. rawId .. ".")
        local target = findOnline(rawId)
        if IsValid(target) then
            setNW(target, 0)
            target:ChatPrint("[Premium] Votre abonnement Premium a été révoqué par un administrateur.")
        end
    end,
    function(err)
        print("[Premium] ERREUR révocation : " .. tostring(err))
    end)
end)

-- ─── Multiplicateur EXP ──────────────────────────────────────────────────────

local PLAYER_META = FindMetaTable("Player")
if PLAYER_META and PLAYER_META.AddEXP then
    local _origAddEXP = PLAYER_META.AddEXP
    function PLAYER_META:AddEXP(amount)
        amount = math.floor(tonumber(amount) or 0)
        if amount > 0 then
            local mult = PR:GetEXPMult(self)
            if mult > 1 then
                amount = math.floor(amount * mult)
            end
        end
        _origAddEXP(self, amount)
    end
else
    VERSE.Log:Warn("[Premium] PLAYER:AddEXP introuvable – multiplicateur EXP non appliqué.")
end

-- ─── Slots de personnage supplémentaires ─────────────────────────────────────

if CH and CH.GetSlots then
    local _origGetSlots = CH.GetSlots
    CH.GetSlots = function(self, ply)
        local base  = _origGetSlots(self, ply)
        local extra = PR:GetExtraSlots(ply)
        return base + extra
    end
else
    VERSE.Log:Warn("[Premium] CH:GetSlots introuvable – slots supplémentaires non appliqués.")
end
