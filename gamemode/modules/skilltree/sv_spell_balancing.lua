-- ─────────────────────────────────────────────────────────────────────────────
-- VERSE :: Spell Balancing  (serveur)
-- Persistance DB + netstream handlers — tous les champs de sorts par rang.
-- ─────────────────────────────────────────────────────────────────────────────

if not SERVER then return end

local DB = VERSE.DB
if not DB then return end

TOOM_JJK        = TOOM_JJK or {}
TOOM_JJK.SPELLS = TOOM_JJK.SPELLS or {}

local _SB = TOOM_JJK.SPELLS.Balancing or {}
TOOM_JJK.SPELLS.Balancing = _SB
_SB.Overrides  = _SB.Overrides  or {}
_SB._originals = _SB._originals or {}
_SB.Net = _SB.Net or {
    SetOverride = "VERSE::SpellBalancing::Set",
    ResetRank   = "VERSE::SpellBalancing::ResetRank",
    ResetSpell  = "VERSE::SpellBalancing::ResetSpell",
    ResetAll    = "VERSE::SpellBalancing::ResetAll",
    SyncAll     = "VERSE::SpellBalancing::SyncAll",
    OpenMenu    = "VERSE::SpellBalancing::OpenMenu",
}

-- Fallbacks si sh_spell_balancing.lua de l'addon n'a pas chargé
if not _SB.ApplyOverrides then
    function _SB:ApplyOverrides()
        local reg = TOOM_JJK.SPELLS.Registered
        if not reg then return end
        for spellId, spell in pairs(reg) do
            if not self._originals[spellId] then
                local orig = { Cost = {}, Cooldown = {}, Upgrades = {} }
                for i = 1, 5 do
                    orig.Cost[i]     = spell.Cost     and spell.Cost[i]
                    orig.Cooldown[i] = spell.Cooldown and spell.Cooldown[i]
                    orig.Upgrades[i] = {}
                    if spell.Upgrades and spell.Upgrades[i] then
                        for k, v in pairs(spell.Upgrades[i]) do orig.Upgrades[i][k] = v end
                    end
                end
                self._originals[spellId] = orig
            end
        end
        for spellId, orig in pairs(self._originals) do
            local spell = reg[spellId]
            if spell then
                for rank = 1, 5 do
                    if spell.Cost     and orig.Cost[rank]     ~= nil then spell.Cost[rank]     = orig.Cost[rank]     end
                    if spell.Cooldown and orig.Cooldown[rank] ~= nil then spell.Cooldown[rank] = orig.Cooldown[rank] end
                    if spell.Upgrades and spell.Upgrades[rank] and orig.Upgrades[rank] then
                        for k, v in pairs(orig.Upgrades[rank]) do spell.Upgrades[rank][k] = v end
                    end
                end
            end
        end
        for spellId, rankOvs in pairs(self.Overrides) do
            local spell = reg[spellId]
            if spell then
                for rank, data in pairs(rankOvs) do
                    rank = tonumber(rank)
                    if rank and rank >= 1 and rank <= 5 then
                        if data.cost     ~= nil and spell.Cost     then spell.Cost[rank]     = data.cost     end
                        if data.cooldown ~= nil and spell.Cooldown then spell.Cooldown[rank] = data.cooldown end
                        if istable(data.upgrades) and spell.Upgrades and spell.Upgrades[rank] then
                            for k, v in pairs(data.upgrades) do spell.Upgrades[rank][k] = v end
                        end
                    end
                end
            end
        end
    end
end

if not _SB.GetOriginal then
    function _SB:GetOriginal(spellId, rank, field)
        local orig = self._originals[spellId]
        if orig then
            if field == "cost"     then return orig.Cost[rank] end
            if field == "cooldown" then return orig.Cooldown[rank] end
            return orig.Upgrades[rank] and orig.Upgrades[rank][field]
        end
        local spell = TOOM_JJK.SPELLS.Registered and TOOM_JJK.SPELLS.Registered[spellId]
        if not spell then return nil end
        if field == "cost"     then return spell.Cost     and spell.Cost[rank]     end
        if field == "cooldown" then return spell.Cooldown and spell.Cooldown[rank] end
        return spell.Upgrades and spell.Upgrades[rank] and spell.Upgrades[rank][field]
    end
end

local SB    = TOOM_JJK.SPELLS.Balancing
local NET   = SB.Net
local TABLE = "verse_spell_balancing"

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function esc(v)      return DB:Escape(tostring(v or "")) end
local function now()       return math.floor(os.time()) end
local function log(...)    if VERSE.Log then VERSE.Log:Info("[SpellBal]",  ...) end end
local function logErr(...) if VERSE.Log then VERSE.Log:Error("[SpellBal]", ...) end end

local function isSuperAdmin(ply)
    return IsValid(ply) and (ply:IsSuperAdmin() or (ply.IsDeveloper and ply:IsDeveloper()))
end

-- ─── DB ──────────────────────────────────────────────────────────────────────

local function createTable()
    local q
    if DB:IsMySQL() then
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                spell_id          VARCHAR(128) NOT NULL,
                rank_num          INT          NOT NULL DEFAULT 1,
                cost_override     FLOAT        NULL DEFAULT NULL,
                cooldown_override FLOAT        NULL DEFAULT NULL,
                upgrades_json     TEXT         NULL DEFAULT NULL,
                updated_at        INT          NOT NULL DEFAULT 0,
                PRIMARY KEY (spell_id, rank_num)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(TABLE)
    else
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                spell_id          TEXT    NOT NULL,
                rank_num          INTEGER NOT NULL DEFAULT 1,
                cost_override     REAL    NULL DEFAULT NULL,
                cooldown_override REAL    NULL DEFAULT NULL,
                upgrades_json     TEXT    NULL DEFAULT NULL,
                updated_at        INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (spell_id, rank_num)
            )
        ]]):format(TABLE)
    end
    DB:Query(q, function()
        log("Table", TABLE, "prête.")
        -- Migration : ajoute upgrades_json si absent (ancienne version)
        local alter = DB:IsMySQL()
            and ("ALTER TABLE %s ADD COLUMN IF NOT EXISTS upgrades_json TEXT NULL DEFAULT NULL"):format(TABLE)
            or  nil  -- SQLite: CREATE TABLE IF NOT EXISTS gère déjà ça
        if alter then
            DB:Query(alter, nil, function() end)
        end
        SB.loadFromDB()
    end, function(err)
        logErr("Création table:", tostring(err))
        return true
    end)
end

function SB.loadFromDB()
    DB:Query(("SELECT spell_id, rank_num, cost_override, cooldown_override, upgrades_json FROM %s"):format(TABLE),
    function(rows)
        SB.Overrides = {}
        for _, row in ipairs(rows or {}) do
            local sid  = tostring(row.spell_id or "")
            local rank = tonumber(row.rank_num)
            if sid == "" or not rank then continue end

            local cost = tonumber(row.cost_override)
            local cd   = tonumber(row.cooldown_override)
            local upgs = nil
            if row.upgrades_json and row.upgrades_json ~= "" then
                local ok, t = pcall(util.JSONToTable, row.upgrades_json)
                if ok and istable(t) then
                    -- Reconvertir les valeurs en number
                    upgs = {}
                    for k, v in pairs(t) do
                        local n = tonumber(v)
                        if n ~= nil then upgs[k] = n end
                    end
                    if not next(upgs) then upgs = nil end
                end
            end

            if cost or cd or upgs then
                SB.Overrides[sid] = SB.Overrides[sid] or {}
                SB.Overrides[sid][rank] = { cost = cost, cooldown = cd, upgrades = upgs }
            end
        end
        SB:ApplyOverrides()
        local cnt = 0
        for _ in pairs(SB.Overrides) do cnt = cnt + 1 end
        log("Overrides chargés:", cnt, "sort(s) modifié(s).")
    end,
    function(err)
        logErr("Chargement overrides:", tostring(err))
        return true
    end)
end

local function persistRank(spellId, rank, data)
    local costVal  = data.cost     ~= nil and tostring(data.cost)     or "NULL"
    local cdVal    = data.cooldown ~= nil and tostring(data.cooldown) or "NULL"
    local upgsJson = "NULL"
    if istable(data.upgrades) and next(data.upgrades) then
        local ok, j = pcall(util.TableToJSON, data.upgrades)
        if ok and j then
            upgsJson = esc(j)
        end
    end
    local spellIdQ = esc(spellId)
    local q
    if DB:IsMySQL() then
        q = ([[
            INSERT INTO %s (spell_id, rank_num, cost_override, cooldown_override, upgrades_json, updated_at)
            VALUES (%s, %d, %s, %s, %s, %d)
            ON DUPLICATE KEY UPDATE
                cost_override     = VALUES(cost_override),
                cooldown_override = VALUES(cooldown_override),
                upgrades_json     = VALUES(upgrades_json),
                updated_at        = VALUES(updated_at)
        ]]):format(TABLE, spellIdQ, rank, costVal, cdVal, upgsJson, now())
    else
        q = ([[
            INSERT OR REPLACE INTO %s (spell_id, rank_num, cost_override, cooldown_override, upgrades_json, updated_at)
            VALUES (%s, %d, %s, %s, %s, %d)
        ]]):format(TABLE, spellIdQ, rank, costVal, cdVal, upgsJson, now())
    end
    DB:Query(q, nil, function(err)
        logErr("persistRank", spellId, rank, ":", tostring(err))
        return true
    end)
end

local function deleteRank(spellId, rank)
    DB:Query(("DELETE FROM %s WHERE spell_id=%s AND rank_num=%d"):format(TABLE, esc(spellId), rank),
    nil, function(err) logErr("deleteRank", spellId, rank, ":", tostring(err)) return true end)
end

local function deleteSpell(spellId)
    DB:Query(("DELETE FROM %s WHERE spell_id=%s"):format(TABLE, esc(spellId)),
    nil, function(err) logErr("deleteSpell", spellId, ":", tostring(err)) return true end)
end

-- ─── Sync réseau ─────────────────────────────────────────────────────────────

local function packOverrides()
    local out = {}
    for spellId, rankOvs in pairs(SB.Overrides) do
        out[spellId] = {}
        for rank, data in pairs(rankOvs) do
            out[spellId][rank] = {
                cost     = data.cost,
                cooldown = data.cooldown,
                upgrades = data.upgrades,
            }
        end
    end
    return out
end

local function syncTo(ply)
    local packed = packOverrides()
    if ply then
        if IsValid(ply) then netstream.Start(ply, NET.SyncAll, packed) end
    else
        for _, p in ipairs(player.GetAll()) do
            netstream.Start(p, NET.SyncAll, packed)
        end
    end
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- cost, cooldown : number ou nil
-- upgrades : table { field=value, ... } ou nil
function SB.setRankOverride(spellId, rank, cost, cooldown, upgrades)
    spellId = tostring(spellId or "")
    rank    = tonumber(rank)
    if spellId == "" or not rank or rank < 1 or rank > 5 then return false end

    local spell = TOOM_JJK.SPELLS.Registered and TOOM_JJK.SPELLS.Registered[spellId]
    if not spell then return false, "bad_spell" end

    local function sanitizeNum(v, minV)
        v = tonumber(v)
        return v and math.max(minV or 0, v) or nil
    end
    cost     = sanitizeNum(cost,     1)
    cooldown = sanitizeNum(cooldown, 0)

    local cleanUpgrades = nil
    if istable(upgrades) then
        cleanUpgrades = {}
        for k, v in pairs(upgrades) do
            v = tonumber(v)
            if v ~= nil then cleanUpgrades[k] = v end
        end
        if not next(cleanUpgrades) then cleanUpgrades = nil end
    end

    -- Comparer aux originaux
    local origCost = SB:GetOriginal(spellId, rank, "cost")
    local origCD   = SB:GetOriginal(spellId, rank, "cooldown")

    local finalCost = (cost     ~= nil and cost     ~= origCost) and cost     or nil
    local finalCD   = (cooldown ~= nil and cooldown ~= origCD)   and cooldown or nil
    local finalUpgs = nil
    if cleanUpgrades then
        finalUpgs = {}
        for k, v in pairs(cleanUpgrades) do
            local origV = SB:GetOriginal(spellId, rank, k)
            if v ~= origV then finalUpgs[k] = v end
        end
        if not next(finalUpgs) then finalUpgs = nil end
    end

    if finalCost == nil and finalCD == nil and finalUpgs == nil then
        if SB.Overrides[spellId] then
            SB.Overrides[spellId][rank] = nil
            if not next(SB.Overrides[spellId]) then SB.Overrides[spellId] = nil end
        end
        deleteRank(spellId, rank)
    else
        SB.Overrides[spellId] = SB.Overrides[spellId] or {}
        SB.Overrides[spellId][rank] = { cost = finalCost, cooldown = finalCD, upgrades = finalUpgs }
        persistRank(spellId, rank, SB.Overrides[spellId][rank])
    end

    SB:ApplyOverrides()
    syncTo(nil)
    return true
end

function SB.resetRank(spellId, rank)
    spellId = tostring(spellId or "")
    rank    = tonumber(rank)
    if spellId == "" or not rank then return end
    if SB.Overrides[spellId] then
        SB.Overrides[spellId][rank] = nil
        if not next(SB.Overrides[spellId]) then SB.Overrides[spellId] = nil end
    end
    deleteRank(spellId, rank)
    SB:ApplyOverrides()
    syncTo(nil)
end

function SB.resetSpell(spellId)
    spellId = tostring(spellId or "")
    SB.Overrides[spellId] = nil
    deleteSpell(spellId)
    SB:ApplyOverrides()
    syncTo(nil)
end

function SB.resetAll()
    SB.Overrides = {}
    DB:Query(("DELETE FROM %s"):format(TABLE), nil,
        function(err) logErr("resetAll:", tostring(err)) return true end)
    SB:ApplyOverrides()
    syncTo(nil)
end

-- ─── Netstream ───────────────────────────────────────────────────────────────

netstream.Hook(NET.OpenMenu, function(ply)
    if not isSuperAdmin(ply) then return end
    syncTo(ply)
    netstream.Start(ply, NET.OpenMenu)
end)

-- data = { cost=X, cooldown=X, upgrades={k=v,...} }
netstream.Hook(NET.SetOverride, function(ply, spellId, rank, data)
    if not isSuperAdmin(ply) then return end
    if not istable(data) then return end
    local ok, err = SB.setRankOverride(spellId, rank, data.cost, data.cooldown, data.upgrades)
    if ok then
        log(ply:Nick(), "modifie", spellId, "rang", tostring(rank))
    else
        logErr("setRankOverride échoué:", spellId, "rang", tostring(rank), ":", tostring(err))
    end
end)

netstream.Hook(NET.ResetRank, function(ply, spellId, rank)
    if not isSuperAdmin(ply) then return end
    SB.resetRank(tostring(spellId or ""), tonumber(rank))
    log(ply:Nick(), "reset rang", tostring(rank), "de", tostring(spellId))
end)

netstream.Hook(NET.ResetSpell, function(ply, spellId)
    if not isSuperAdmin(ply) then return end
    SB.resetSpell(tostring(spellId or ""))
    log(ply:Nick(), "reset sort", tostring(spellId))
end)

netstream.Hook(NET.ResetAll, function(ply)
    if not isSuperAdmin(ply) then return end
    SB.resetAll()
    log(ply:Nick(), "reset ALL spell overrides")
end)

-- ─── Init ────────────────────────────────────────────────────────────────────

VERSE.Hook.AddNS("SpellBalancing", "VERSE::Characters::Loaded", "VERSE::SpellBal::SyncOnLoad", function(ply)
    if IsValid(ply) then syncTo(ply) end
end)

VERSE.DB:OnReady(function() createTable() end)

-- Les sorts TCS peuvent être enregistrés APRÈS que loadFromDB() ait été appelé
-- (ordre de chargement addon vs gamemode). On ré-applique plusieurs fois après
-- l'init pour s'assurer que tous les sorts sont patchés même si la DB répond tard.
hook.Add("Initialize", "VERSE::SpellBal::ApplyAfterInit", function()
    -- Tente immédiatement, puis à t+1s, puis à t+3s (pour MySQL lent)
    local function tryApply()
        if TOOM_JJK and TOOM_JJK.SPELLS and TOOM_JJK.SPELLS.Registered and next(SB.Overrides or {}) then
            SB:ApplyOverrides()
            log("ApplyOverrides post-Initialize: OK")
        end
    end
    timer.Simple(0,   tryApply)
    timer.Simple(1,   tryApply)
    timer.Simple(3,   tryApply)
end)

concommand.Add("verse_spell_balancing_open", function(ply)
    if not IsValid(ply) then return end
    if not isSuperAdmin(ply) then return end
    syncTo(ply)
    netstream.Start(ply, NET.OpenMenu)
end)
