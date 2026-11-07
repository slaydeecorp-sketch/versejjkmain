-- ─────────────────────────────────────────────────────────────────────────────
-- VERSE :: SkillTree :: Balancing  (serveur)
-- Menu d'équilibrage temps réel des nodes du skilltree.
-- Accès réservé aux superadmins (ply:IsSuperAdmin()).
-- Persiste les overrides en base de données.
-- ─────────────────────────────────────────────────────────────────────────────

if not SERVER then return end

local ST = VERSE.SkillTree
local DB = VERSE.DB
if not ST or not DB then return end

local BAL     = ST.Balancing
local NET     = BAL.Net
local TABLE   = "verse_skilltree_balancing"

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function esc(v)   return DB:Escape(tostring(v or "")) end
local function now()    return math.floor(os.time()) end
local function log(...)
    if VERSE.Log and VERSE.Log.Info then VERSE.Log:Info("[Balancing]", ...) end
end
local function logErr(...)
    if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[Balancing]", ...) end
end

local function isSuperAdmin(ply)
    return IsValid(ply) and (ply:IsSuperAdmin() or (ply.IsDeveloper and ply:IsDeveloper()))
end

-- ─── DB ──────────────────────────────────────────────────────────────────────

local function createTable()
    local q
    if DB:IsMySQL() then
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                node_id         VARCHAR(128) NOT NULL PRIMARY KEY,
                cost_override   INT NULL DEFAULT NULL,
                maxrank_override INT NULL DEFAULT NULL,
                updated_at      INT NOT NULL DEFAULT 0
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(TABLE)
    else
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                node_id          TEXT    NOT NULL PRIMARY KEY,
                cost_override    INTEGER NULL DEFAULT NULL,
                maxrank_override INTEGER NULL DEFAULT NULL,
                updated_at       INTEGER NOT NULL DEFAULT 0
            )
        ]]):format(TABLE)
    end
    DB:Query(q, function()
        log("Table", TABLE, "prête.")
        BAL.loadFromDB()
    end, function(err)
        logErr("Impossible de créer la table:", tostring(err))
        return true
    end)
end

-- Charge tous les overrides depuis la DB et les applique.
function BAL.loadFromDB()
    DB:Query(("SELECT node_id, cost_override, maxrank_override FROM %s"):format(TABLE),
    function(rows)
        BAL.Overrides = {}
        for _, row in ipairs(rows or {}) do
            local nid  = tostring(row.node_id or "")
            local cost = tonumber(row.cost_override)
            local mr   = tonumber(row.maxrank_override)
            if nid ~= "" and (cost or mr) then
                BAL.Overrides[nid] = { cost = cost, maxRank = mr }
            end
        end
        ST:ApplyBalancingOverrides()
        log("Overrides chargés:", table.Count(BAL.Overrides), "node(s) modifié(s).")
    end,
    function(err)
        logErr("Chargement des overrides échoué:", tostring(err))
        return true
    end)
end

-- Persiste un override en base (INSERT OR REPLACE / ON DUPLICATE KEY UPDATE).
local function persistOverride(nodeId, cost, maxRank)
    local costVal   = cost    and tostring(math.floor(cost))    or "NULL"
    local mrVal     = maxRank and tostring(math.floor(maxRank)) or "NULL"
    local q
    if DB:IsMySQL() then
        q = ([[
            INSERT INTO %s (node_id, cost_override, maxrank_override, updated_at)
            VALUES (%s, %s, %s, %d)
            ON DUPLICATE KEY UPDATE
                cost_override    = VALUES(cost_override),
                maxrank_override = VALUES(maxrank_override),
                updated_at       = VALUES(updated_at)
        ]]):format(TABLE, esc(nodeId), costVal, mrVal, now())
    else
        q = ([[
            INSERT OR REPLACE INTO %s (node_id, cost_override, maxrank_override, updated_at)
            VALUES (%s, %s, %s, %d)
        ]]):format(TABLE, esc(nodeId), costVal, mrVal, now())
    end
    DB:Query(q, nil, function(err)
        logErr("Erreur persistance override", nodeId, ":", tostring(err))
        return true
    end)
end

-- Supprime un override de la base.
local function deleteOverride(nodeId)
    DB:Query(("DELETE FROM %s WHERE node_id=%s"):format(TABLE, esc(nodeId)),
    nil, function(err) logErr("Erreur suppression override", nodeId, ":", tostring(err)) return true end)
end

-- ─── Diffusion aux clients ────────────────────────────────────────────────────

-- Sérialise les overrides en table simple pour envoi réseau.
local function packOverrides()
    local out = {}
    for nodeId, ov in pairs(BAL.Overrides) do
        out[nodeId] = { cost = ov.cost, maxRank = ov.maxRank }
    end
    return out
end

-- Envoie les overrides complets à un joueur (ou à tous si ply = nil).
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

-- ─── API publique ─────────────────────────────────────────────────────────────

-- Modifie cost et/ou maxRank d'un node. Passe nil pour ne pas toucher la propriété.
function BAL.setOverride(nodeId, cost, maxRank)
    nodeId = tostring(nodeId or "")
    if nodeId == "" then return false end
    local node = ST:GetNode(nodeId)
    if not node then return false, "bad_node" end

    cost    = cost    and math.max(1, math.floor(tonumber(cost)    or 1)) or nil
    maxRank = maxRank and math.max(1, math.floor(tonumber(maxRank) or 1)) or nil

    local existing = BAL.Overrides[nodeId] or {}
    local newCost  = cost    ~= nil and cost    or existing.cost
    local newMR    = maxRank ~= nil and maxRank or existing.maxRank

    -- Ne sauvegarder que si différent des valeurs d'origine
    local baseNode = ST:GetNode(nodeId)   -- valeur originale (avant override)
    -- On lit la valeur originale depuis _nodeMap avant application — utiliser les
    -- champs du node tel qu'il était avant tout override (stocké dans le Tree).
    -- Pour ça on cherche dans ST.Tree directement.
    local origCost, origMR
    do
        local rawNode = nil
        for _, cat in ipairs(ST.Tree or {}) do
            for _, sub in ipairs(cat.subtypes or {}) do
                for _, n in ipairs(sub.nodes or {}) do
                    if n.id == nodeId then rawNode = n break end
                end
                if rawNode then break end
            end
            if rawNode then break end
        end
        origCost = rawNode and (tonumber(rawNode.cost)    or 1) or 1
        origMR   = rawNode and (tonumber(rawNode.maxRank) or 1) or 1
    end

    local finalCost = (newCost ~= origCost)  and newCost  or nil
    local finalMR   = (newMR   ~= origMR)    and newMR    or nil

    if finalCost == nil and finalMR == nil then
        -- Revient aux valeurs d'origine → supprimer l'override
        BAL.Overrides[nodeId] = nil
        deleteOverride(nodeId)
    else
        BAL.Overrides[nodeId] = { cost = finalCost, maxRank = finalMR }
        persistOverride(nodeId, finalCost, finalMR)
    end

    ST:ApplyBalancingOverrides()
    syncTo(nil)
    return true
end

-- Supprime tous les overrides d'un node.
function BAL.resetNode(nodeId)
    nodeId = tostring(nodeId or "")
    if BAL.Overrides[nodeId] then
        BAL.Overrides[nodeId] = nil
        deleteOverride(nodeId)
        ST:ApplyBalancingOverrides()
        syncTo(nil)
    end
end

-- Supprime TOUS les overrides.
function BAL.resetAll()
    BAL.Overrides = {}
    DB:Query(("DELETE FROM %s"):format(TABLE), nil,
        function(err) logErr("Erreur resetAll:", tostring(err)) return true end)
    ST:ApplyBalancingOverrides()
    syncTo(nil)
end

-- ─── Netstream handlers ───────────────────────────────────────────────────────

-- Client demande le menu → on lui envoie les overrides complets
netstream.Hook(NET.OpenMenu, function(ply)
    if not isSuperAdmin(ply) then return end
    syncTo(ply)
    netstream.Start(ply, NET.OpenMenu)   -- signal "ouvre le menu"
end)

-- Client envoie un override
netstream.Hook(NET.SetOverride, function(ply, nodeId, cost, maxRank)
    if not isSuperAdmin(ply) then return end
    nodeId  = tostring(nodeId or "")
    cost    = tonumber(cost)
    maxRank = tonumber(maxRank)
    local ok, err = BAL.setOverride(nodeId, cost, maxRank)
    if ok then
        log(ply:Nick(), "modifie", nodeId, "→ cost=", tostring(cost), "maxRank=", tostring(maxRank))
    else
        logErr("setOverride échoué pour", nodeId, ":", tostring(err))
    end
end)

-- Client demande le reset d'un node
netstream.Hook(NET.ResetNode, function(ply, nodeId)
    if not isSuperAdmin(ply) then return end
    BAL.resetNode(tostring(nodeId or ""))
    log(ply:Nick(), "reset override", nodeId)
end)

-- Client demande le reset global
netstream.Hook(NET.ResetAll, function(ply)
    if not isSuperAdmin(ply) then return end
    BAL.resetAll()
    log(ply:Nick(), "reset ALL overrides")
end)

-- ─── Sync au chargement du joueur ────────────────────────────────────────────

VERSE.Hook.AddNS("Balancing", "VERSE::Characters::Loaded", "VERSE::Balancing::SyncOnLoad", function(ply)
    if IsValid(ply) then syncTo(ply) end
end)

-- ─── Initialisation ──────────────────────────────────────────────────────────

VERSE.DB:OnReady(function()
    createTable()
end)

-- Commande console superadmin (fallback)
concommand.Add("verse_balancing_open", function(ply)
    if not IsValid(ply) then return end
    if not isSuperAdmin(ply) then return end
    syncTo(ply)
    netstream.Start(ply, NET.OpenMenu)
end)
