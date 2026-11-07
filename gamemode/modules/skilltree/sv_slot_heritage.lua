-- ─────────────────────────────────────────────────────────────────────────────
-- Slot Heritage Persistence
-- Chaque héritage attribué à un personnage est lié au SLOT du joueur.
-- Si le personnage est supprimé et qu'un nouveau est créé sur le même slot,
-- l'héritage est automatiquement restauré.
-- ─────────────────────────────────────────────────────────────────────────────

local SH = {}

-- ─── Caches ───────────────────────────────────────────────────────────────────
-- [steamid64] = slot
local _activeSlot = {}
-- [steamid64][groupId] = true  →  le joueur avait déjà un héritage sauvegardé sur ce slot
local _hadHeritage = {}

-- ─── Helpers DB ──────────────────────────────────────────────────────────────

-- Utilise STRICTEMENT la couche DB du projet (VERSE.DB:Query, appel colon avec
-- gestion d'erreur). Pas de fallback sql.Query (SQLite local) : l'héritage doit
-- toujours s'écrire dans la vraie base MySQL partagée, jamais en local.
local function dbQuery(q, callback)
    if not (VERSE and VERSE.DB and VERSE.DB.Query) then
        MsgC(Color(220, 80, 80), "[SlotHeritage] VERSE.DB indisponible, requête ignorée.\n")
        return
    end
    VERSE.DB:Query(q, callback, function(err)
        MsgC(Color(220, 80, 80), "[SlotHeritage] Erreur DB: " .. tostring(err) .. "\n")
        return true
    end)
end

-- Échappement via la couche projet (MySQL-aware), pas sql.SQLStr (SQLite).
local function esc(v) return VERSE.DB:Escape(tostring(v or "")) end

-- ─── Initialisation table ────────────────────────────────────────────────────

local function initDB()
    dbQuery([[
        CREATE TABLE IF NOT EXISTS verse_slot_heritage (
            steamid64   VARCHAR(32) NOT NULL,
            slot        INTEGER     NOT NULL,
            group_id    VARCHAR(64) NOT NULL,
            branch_id   VARCHAR(64) NOT NULL,
            updated_at  INTEGER     NOT NULL DEFAULT 0,
            PRIMARY KEY (steamid64, slot, group_id)
        )
    ]])
end

-- ─── CRUD ─────────────────────────────────────────────────────────────────────

function SH:Save(steamid64, slot, groupId, branchId)
    if not steamid64 or not slot or not groupId or not branchId then return end

    local t = os.time()

    -- REPLACE INTO : portable MySQL ET SQLite (contrairement à "INSERT OR REPLACE"
    -- qui est de la syntaxe SQLite uniquement → erreur sur MySQL).
    local q = string.format(
        "REPLACE INTO verse_slot_heritage (steamid64, slot, group_id, branch_id, updated_at) VALUES (%s, %d, %s, %s, %d)",
        esc(steamid64), tonumber(slot),
        esc(groupId), esc(branchId), t
    )

    dbQuery(q)

    MsgC(
        Color(100, 210, 120),
        "[SlotHeritage] Sauvegarde → steamid=" .. steamid64 ..
        "  slot=" .. slot ..
        "  " .. groupId .. "=" .. branchId .. "\n"
    )
end

function SH:Delete(steamid64, slot, groupId)
    if not steamid64 or not slot or not groupId then return end
    local q = string.format(
        "DELETE FROM verse_slot_heritage WHERE steamid64=%s AND slot=%d AND group_id=%s",
        esc(steamid64), tonumber(slot), esc(groupId)
    )
    dbQuery(q)
    MsgC(Color(220, 140, 60),
        "[SlotHeritage] Supprimé → steamid=" .. steamid64 ..
        "  slot=" .. slot .. "  group=" .. groupId .. "\n")
end

function SH:Fetch(steamid64, slot, callback)
    local q = string.format(
        "SELECT group_id, branch_id FROM verse_slot_heritage WHERE steamid64=%s AND slot=%d",
        esc(steamid64), tonumber(slot)
    )
    dbQuery(q, callback)
end

-- ─── Restore ─────────────────────────────────────────────────────────────────

function SH:RestoreForPlayer(steamid64, slot, ply)
    if not IsValid(ply) then return end

    self:Fetch(steamid64, slot, function(rows)
        if not IsValid(ply) then return end
        if not rows or #rows == 0 then return end

        local ST = VERSE and VERSE.SkillTree
        if not ST then return end

        -- Récupère les branches déjà assignées au personnage
        local charId = ST:GetCharacterUID(ply)
        if not charId then return end

        -- Charge l'état pour comparer les branches existantes
        ST:LoadCharacterState(charId, function(ok, stateOrErr)
            if not ok or not IsValid(ply) then return end

            local meta     = ST._metaCache[charId] or {}
            local branches = istable(meta.branches) and meta.branches or {}

            -- Marque quels groupes ont un héritage sauvegardé sur ce slot
            _hadHeritage[steamid64] = _hadHeritage[steamid64] or {}
            for _, row in ipairs(rows) do
                _hadHeritage[steamid64][row.group_id] = true
            end

            for _, row in ipairs(rows) do
                local groupId  = row.group_id
                local branchId = row.branch_id

                -- Déjà assigné → rien à faire
                if branches[groupId] == branchId then
                    MsgC(Color(160, 210, 160),
                        "[SlotHeritage] Déjà présent : " .. branchId .. "\n")
                    continue
                end

                MsgC(Color(100, 210, 120),
                    "[SlotHeritage] Restauration → " .. branchId ..
                    " pour " .. steamid64 .. " slot=" .. tostring(slot) .. "\n")

                ST:AdminSetBranch(ply, branchId, function(success, reason)
                    if success then
                        MsgC(Color(100, 210, 120),
                            "[SlotHeritage] ✔ Héritage restauré : " .. branchId .. "\n")
                    else
                        MsgC(Color(220, 80, 80),
                            "[SlotHeritage] ✘ Échec restauration " .. branchId ..
                            " (" .. tostring(reason) .. ")\n")
                    end
                end)
            end
        end)
    end)
end

-- ─── Hook dans AdminSetBranch ─────────────────────────────────────────────────

local function hookAdminSetBranch()
    local ST = VERSE and VERSE.SkillTree
    if not ST or not ST.AdminSetBranch then return false end
    if ST._slotHeritageHooked then return true end

    local origFn = ST.AdminSetBranch

    ST.AdminSetBranch = function(self, ply, subtypeId, callback)
        origFn(self, ply, subtypeId, function(success, sid, refund)

            if success and IsValid(ply) then
                local group = self:GetExclusiveGroupForSubtype(subtypeId)
                if group then
                    local steamid = ply:SteamID64()
                    local slot    = _activeSlot[steamid]
                    if steamid and slot then
                        local hadIt = _hadHeritage[steamid] and _hadHeritage[steamid][group.id]
                        if hadIt then
                            -- Le joueur avait déjà un héritage sur ce slot et reroll → il le perd
                            SH:Delete(steamid, slot, group.id)
                            _hadHeritage[steamid][group.id] = nil
                        else
                            -- Premier héritage sur ce slot → on le sauvegarde
                            SH:Save(steamid, slot, group.id, subtypeId)
                            _hadHeritage[steamid] = _hadHeritage[steamid] or {}
                            _hadHeritage[steamid][group.id] = true
                        end
                    else
                        MsgC(Color(220, 160, 50),
                            "[SlotHeritage] AdminSetBranch : slot introuvable pour " ..
                            tostring(steamid) .. "\n")
                    end
                end
            end

            if callback then callback(success, sid, refund) end
        end)
    end

    ST._slotHeritageHooked = true
    MsgC(Color(100, 210, 120), "[SlotHeritage] Hook AdminSetBranch installé.\n")
    return true
end

-- ─── Hooks VERSE ─────────────────────────────────────────────────────────────

local function registerHooks()
    if not VERSE or not VERSE.Hook then return end

    -- Mise à jour du cache de slot + restauration à chaque chargement de personnage
    VERSE.Hook.AddNS(
        "SlotHeritage",
        "VERSE::Characters::Loaded",
        "SH::OnCharLoaded",
        function(ply, char)
            if not IsValid(ply) or not char then return end

            local steamid = ply:SteamID64()
            local slot    = char.slot
            if not steamid or not slot then return end

            -- Met à jour le cache
            _activeSlot[steamid] = slot

            -- Petit délai pour s'assurer que le charState est bien initialisé dans ST
            timer.Simple(0.2, function()
                if not IsValid(ply) then return end
                SH:RestoreForPlayer(steamid, slot, ply)
            end)
        end
    )
end

-- Nettoyage du cache au déconnect
hook.Add("PlayerDisconnected", "SlotHeritage::ClearCache", function(ply)
    if not IsValid(ply) then return end
    local steamid = ply:SteamID64()
    if steamid then
        _activeSlot[steamid]    = nil
        _hadHeritage[steamid]   = nil
    end
end)

-- ─── Initialisation ──────────────────────────────────────────────────────────

-- La création de la table DOIT attendre que la connexion MySQL soit prête.
-- Sinon le CREATE TABLE part avant la connexion (VERSE.DB indisponible) et la
-- table n'est jamais créée → "Table ... doesn't exist" aux requêtes suivantes.
-- VERSE.DB:OnReady rappelle immédiatement si la DB est déjà connectée (hot reload).
local function ensureTable()
    if VERSE and VERSE.DB and VERSE.DB.OnReady then
        VERSE.DB:OnReady(function() initDB() end)
    else
        initDB()
    end
end

local function init()
    ensureTable()
    hookAdminSetBranch()
    registerHooks()
end

-- Tente immédiatement (rechargement à chaud)
init()

-- Backup au démarrage serveur
hook.Add("Initialize", "SlotHeritage::Init", function()
    init()
end)

-- Si le SkillTree se charge plus tard
if VERSE and VERSE.Hook then
    VERSE.Hook.AddNS(
        "SlotHeritage",
        "VERSE::SkillTree::Ready",
        "SH::HookST",
        function()
            hookAdminSetBranch()
        end
    )
end
