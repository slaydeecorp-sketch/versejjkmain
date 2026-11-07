local TD  = VERSE.TrainingDummy
local DB  = VERSE.DB
local Log = VERSE.Log
if not TD or not DB then return end

local cfg = TD.Config
TD._dummies = TD._dummies or {}  -- [id] = { id, ent, pos, ang_y, map }

local function esc(v) return DB:Escape(tostring(v)) end

-- ─── Utilitaire notify ────────────────────────────────────────────────────────

local function notify(ply, msg, kind)
    if not IsValid(ply) then return end
    netstream.Start(ply, TD.Net.Notify, msg, kind or "info")
end

-- ─── Table DB ─────────────────────────────────────────────────────────────────

local function createTable()
    local tbl = cfg.TableName
    local q
    if DB:IsMySQL() then
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id      INT NOT NULL AUTO_INCREMENT,
                map     VARCHAR(64)  NOT NULL,
                pos_x   FLOAT NOT NULL DEFAULT 0,
                pos_y   FLOAT NOT NULL DEFAULT 0,
                pos_z   FLOAT NOT NULL DEFAULT 0,
                ang_y   FLOAT NOT NULL DEFAULT 0,
                PRIMARY KEY (id),
                KEY idx_map (map)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(tbl)
    else
        q = ([[
            CREATE TABLE IF NOT EXISTS %s (
                id    INTEGER PRIMARY KEY AUTOINCREMENT,
                map   TEXT  NOT NULL,
                pos_x REAL  NOT NULL DEFAULT 0,
                pos_y REAL  NOT NULL DEFAULT 0,
                pos_z REAL  NOT NULL DEFAULT 0,
                ang_y REAL  NOT NULL DEFAULT 0
            )
        ]]):format(tbl)
    end

    DB:Query(q):Next(function()
        Log:Info("[TrainingDummy] Table '" .. tbl .. "' prete.")
        TD:LoadDummies()
    end):Catch(function(err)
        Log:Error("[TrainingDummy] CreateTable: " .. tostring(err))
    end)
end

-- ─── Spawn d'un mannequin ─────────────────────────────────────────────────────

local function spawnDummy(pos, ang_y, dbId)
    local ent = ents.Create("verse_training_dummy")
    if not IsValid(ent) then
        Log:Error("[TrainingDummy] Impossible de créer verse_training_dummy (entité introuvable)")
        return nil
    end
    ent:SetPos(pos)
    ent:SetAngles(Angle(0, ang_y or 0, 0))
    ent:Spawn()
    ent:Activate()

    TD._dummies[dbId] = { id = dbId, ent = ent, pos = pos, ang_y = ang_y or 0, map = game.GetMap() }
    return ent
end

-- ─── Chargement depuis la DB ──────────────────────────────────────────────────

function TD:LoadDummies()
    local tbl        = cfg.TableName
    local currentMap = game.GetMap()
    DB:Query(("SELECT * FROM %s WHERE map=%s"):format(tbl, esc(currentMap))):Next(function(rows)
        rows = rows or {}
        local count = 0
        for _, row in ipairs(rows) do
            local id  = tonumber(row.id)
            local pos = Vector(tonumber(row.pos_x) or 0, tonumber(row.pos_y) or 0, tonumber(row.pos_z) or 0)
            local aY  = tonumber(row.ang_y) or 0
            if id then
                spawnDummy(pos, aY, id)
                count = count + 1
            end
        end
        Log:Info("[TrainingDummy] " .. count .. " mannequin(s) charge(s) sur " .. currentMap)
    end):Catch(function(err)
        Log:Error("[TrainingDummy] LoadDummies: " .. tostring(err))
    end)
end

-- ─── Placement (admin) ────────────────────────────────────────────────────────

function TD:Place(ply)
    if not IsValid(ply) then return end

    local pos  = ply:GetPos()
    local angY = ply:GetAngles().y
    local map  = game.GetMap()
    local tbl  = cfg.TableName

    local q = ("INSERT INTO %s (map, pos_x, pos_y, pos_z, ang_y) VALUES (%s, %f, %f, %f, %f)"):format(
        tbl, esc(map), pos.x, pos.y, pos.z, angY
    )

    DB:Query(q):Next(function(_, lastInsert)
        local id = tonumber(lastInsert)

        local finalize = function(fid)
            if not fid or fid <= 0 then
                notify(ply, "Erreur : impossible d'obtenir l'ID du mannequin.", "error")
                return
            end
            local ent = spawnDummy(pos, angY, fid)
            if IsValid(ent) then
                notify(ply, "Mannequin placé et sauvegardé (ID " .. fid .. ").", "success")
                Log:Info("[TrainingDummy] " .. ply:Nick() .. " a placé un mannequin (id=" .. fid .. ") sur " .. map)
            else
                notify(ply, "Mannequin sauvegardé mais spawn échoué.", "error")
            end
        end

        if not id or id <= 0 then
            -- Fallback MySQL : lastInsert parfois absent
            DB:QueryValue(("SELECT MAX(id) FROM %s WHERE map=%s"):format(tbl, esc(map))):Next(function(val)
                finalize(tonumber(val))
            end):Catch(function(err)
                Log:Error("[TrainingDummy] Place QueryMax: " .. tostring(err))
                notify(ply, "Erreur DB lors du placement.", "error")
            end)
        else
            finalize(id)
        end
    end):Catch(function(err)
        Log:Error("[TrainingDummy] Place Insert: " .. tostring(err))
        notify(ply, "Erreur DB lors du placement.", "error")
    end)
end

-- ─── Suppression (admin) ──────────────────────────────────────────────────────

function TD:Remove(ply)
    if not IsValid(ply) then return end

    local pos     = ply:GetPos()
    local maxDist = cfg.MaxRange
    local nearest, nearestDist, nearestId = nil, math.huge, nil

    for id, d in pairs(TD._dummies) do
        if IsValid(d.ent) then
            local dist = pos:Distance(d.ent:GetPos())
            if dist < nearestDist then
                nearestDist = dist
                nearest     = d
                nearestId   = id
            end
        end
    end

    if not nearest or nearestDist > maxDist then
        notify(ply, "Aucun mannequin à portée (" .. maxDist .. " unités max).", "error")
        return
    end

    -- Supprimer l'entité
    if IsValid(nearest.ent) then nearest.ent:Remove() end
    TD._dummies[nearestId] = nil

    -- Supprimer en DB
    local tbl = cfg.TableName
    DB:Query(("DELETE FROM %s WHERE id=%d"):format(tbl, nearestId)):Next(function()
        notify(ply, "Mannequin (ID " .. nearestId .. ") supprimé.", "success")
        Log:Info("[TrainingDummy] " .. ply:Nick() .. " a supprimé le mannequin id=" .. nearestId)
    end):Catch(function(err)
        Log:Error("[TrainingDummy] Remove Delete: " .. tostring(err))
        notify(ply, "Mannequin retiré en jeu mais erreur DB.", "error")
    end)
end

-- ─── Commandes console ────────────────────────────────────────────────────────
-- verse_dummy place   → place un mannequin à ta position, le sauvegarde en DB
-- verse_dummy remove  → supprime le mannequin le plus proche (< MaxRange)
-- verse_dummy list    → liste tous les mannequins sur la map

VERSE.Commands.Add("verse_dummy", function(ply, args)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        notify(ply, "Permission refusée.", "error")
        return
    end

    local action = args[1]

    if action == "place" then
        TD:Place(ply)

    elseif action == "remove" then
        TD:Remove(ply)

    elseif action == "list" then
        local map = game.GetMap()
        local lines = { "=== Mannequins sur " .. map .. " ===" }
        local n = 0
        for id, d in pairs(TD._dummies) do
            local p = IsValid(d.ent) and d.ent:GetPos() or d.pos
            lines[#lines + 1] = ("  [%d] %.0f %.0f %.0f"):format(id, p.x, p.y, p.z)
            n = n + 1
        end
        lines[#lines + 1] = "Total : " .. n
        for _, l in ipairs(lines) do ply:ChatPrint(l) end

    elseif action == "hitbox" then
        -- Affiche la BBox + OBB de chaque mannequin pendant 10 secondes
        local count = 0
        for id, d in pairs(TD._dummies) do
            local ent = d.ent
            if not IsValid(ent) then continue end
            local pos  = ent:GetPos()
            local ang  = ent:GetAngles()
            local mins = ent:OBBMins()
            local maxs = ent:OBBMaxs()
            -- BBox monde (rouge)
            debugoverlay.BoxAngles(pos, mins, maxs, ang, 10, Color(255, 60, 60, 80))
            -- Centre + axes (blanc)
            debugoverlay.Cross(pos + ent:OBBCenter(), 8, 10, Color(255, 255, 255, 200), true)
            -- Texte info
            debugoverlay.Text(pos + Vector(0,0,80), ("Dummy #%d  OBB: %.0fx%.0fx%.0f"):format(
                id,
                maxs.x - mins.x,
                maxs.y - mins.y,
                maxs.z - mins.z
            ), 10, true)
            count = count + 1
        end
        if count == 0 then
            notify(ply, "Aucun mannequin valide sur la map.", "error")
        else
            notify(ply, ("Hitbox affichée pour %d mannequin(s) pendant 10s."):format(count), "info")
        end

    else
        ply:ChatPrint("Usage : verse_dummy <place|remove|list|hitbox>")
    end
end, nil, "server")

-- ─── Rechargement des mannequins quand un joueur rejoint (sécurité) ───────────
-- Les entités sont déjà spawnées au chargement de la map ; ce hook re-vérifie
-- simplement qu'elles sont encore valides et les respawn si besoin.

hook.Add("PlayerInitialSpawn", "VERSE::TrainingDummy::Respawn", function()
    for id, d in pairs(TD._dummies) do
        if not IsValid(d.ent) then
            Log:Warn("[TrainingDummy] Mannequin id=" .. id .. " invalide, respawn...")
            spawnDummy(d.pos, d.ang_y, id)
        end
    end
end)

-- ─── Patch métatable TCS ─────────────────────────────────────────────────────
-- TCS définit IsTarget() sur FindMetaTable("Entity") avec un guard IsPlayer()
-- qui bloque tous les non-joueurs. Les méthodes ENT ne surchargent PAS les
-- méthodes de la métatable C++ de GMod → on wrappe directement la métatable.
-- Différé d'un tick pour être certain que TCS est chargé avant nous.
timer.Simple(0, function()
    local metaEnt = FindMetaTable("Entity")
    if not metaEnt then return end

    -- IsTarget : TCS renvoie false immédiatement si !IsPlayer() → on autorise
    -- le mannequin avant que la vérification IsPlayer() soit atteinte.
    if isfunction(metaEnt.IsTarget) then
        local _origIsTarget = metaEnt.IsTarget
        metaEnt.IsTarget = function(self, ...)
            if IsValid(self) and self:GetClass() == "verse_training_dummy" then
                return true
            end
            return _origIsTarget(self, ...)
        end
    end

    -- Alive : Entity:Alive() n'existe pas dans la métatable GMod (Player only).
    -- TCS l'appelle directement sur les cibles (sv_hitbox.lua) après IsTarget().
    -- On ajoute un fallback sûr uniquement si la méthode est absente.
    if not isfunction(metaEnt.Alive) then
        metaEnt.Alive = function(self)
            if self:IsPlayer() then
                local metaPly = FindMetaTable("Player")
                if metaPly and isfunction(metaPly.Alive) then
                    return metaPly.Alive(self)
                end
            end
            return IsValid(self)
        end
    end

    Log:Info("[TrainingDummy] Patch métatable TCS appliqué.")
end)

-- ─── Init : créer la table puis charger ──────────────────────────────────────

DB:OnReady():Next(function()
    createTable()
end):Catch(function(err)
    Log:Error("[TrainingDummy] DB OnReady: " .. tostring(err))
end)
