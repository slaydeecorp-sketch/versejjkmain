-- ─── Network ──────────────────────────────────────────────────────────────────
-- Réutilise le canal hitmarker TCS (safe de redéclarer)
util.AddNetworkString("TCS:Hitmarker")

-- ─── Patch métatable TCS ─────────────────────────────────────────────────────
-- TCS définit IsTarget() avec un guard IsPlayer() qui bloque les non-joueurs.
-- On wrappe la métatable Entity pour que tous les verse_mob_* soient des cibles.
-- Différé d'un tick pour être certain que TCS est chargé avant.
timer.Simple(0, function()
    local metaEnt = FindMetaTable("Entity")
    if not metaEnt then return end

    -- IsTarget : autorise les mobs verse avant le check IsPlayer() de TCS.
    if isfunction(metaEnt.IsTarget) then
        local _origIsTarget = metaEnt.IsTarget
        metaEnt.IsTarget = function(self, ...)
            if IsValid(self) and string.find(self:GetClass(), "verse_mob_", 1, true) then
                -- Ne pas cibler un mob mort (VMobDead = true)
                return not self:GetNWBool("VMobDead", false)
            end
            return _origIsTarget(self, ...)
        end
    end

    -- Alive : Entity:Alive() n'existe pas dans la métatable GMod (Player only).
    -- TCS l'appelle sur les cibles après IsTarget().
    -- On ajoute le fallback uniquement s'il n'est pas déjà présent (le mannequin
    -- peut l'avoir ajouté en premier — dans ce cas on le remplace pour supporter
    -- la vérification VMobDead des mobs).
    local _prevAlive = isfunction(metaEnt.Alive) and metaEnt.Alive or nil
    metaEnt.Alive = function(self)
        if self:IsPlayer() then
            local metaPly = FindMetaTable("Player")
            if metaPly and isfunction(metaPly.Alive) then
                return metaPly.Alive(self)
            end
        end
        -- Mob verse : mort si VMobDead
        if string.find(self:GetClass() or "", "verse_mob_", 1, true) then
            return IsValid(self) and not self:GetNWBool("VMobDead", false)
        end
        -- Fallback générique (couvre le mannequin d'entraînement etc.)
        if _prevAlive then return _prevAlive(self) end
        return IsValid(self)
    end

    VERSE.Log:Info("[Mobs] Patch métatable TCS appliqué.")
end)

-- ─── Commande de spawn ────────────────────────────────────────────────────────
-- verse_mob_spawn faiblard  → spawn le mob là où tu regardes
-- verse_mob_kill            → supprime tous les mobs verse_mob_* de la map

VERSE.Commands.Add("verse_mob_spawn", function(ply, args)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        if isfunction(ply.Notify) then ply:Notify("Permission refusee.", NOTIFY_ERROR, 3) end
        return
    end

    local mobType = string.lower(tostring(args[1] or "faiblard"))
    local entClass = "verse_mob_" .. mobType

    -- Vérifie que la classe existe
    if not scripted_ents.GetStored(entClass) then
        if isfunction(ply.Notify) then ply:Notify("Mob inconnu : " .. mobType, NOTIFY_ERROR, 3) end
        return
    end

    local tr  = ply:GetEyeTrace()
    if not tr or not tr.Hit then return end
    local pos = tr.HitPos + Vector(0, 0, 5)

    local mob = ents.Create(entClass)
    if not IsValid(mob) then
        if isfunction(ply.Notify) then ply:Notify("Erreur lors de la creation du mob.", NOTIFY_ERROR, 3) end
        return
    end

    mob:SetPos(pos)
    -- Le mob fait face au joueur qui le spawn
    local ang = (ply:GetPos() - pos):Angle()
    ang.p = 0
    ang.r = 0
    mob:SetAngles(ang)
    mob:Spawn()
    mob:Activate()

    if isfunction(ply.Notify) then
        ply:Notify("Mob '" .. mobType .. "' spawné.", NOTIFY_HINT, 3)
    end
    VERSE.Log:Info("[Mobs] " .. ply:Nick() .. " a spawné un " .. entClass .. " à " .. tostring(pos))
end)

VERSE.Commands.Add("verse_mob_kill", function(ply, args)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        if isfunction(ply.Notify) then ply:Notify("Permission refusee.", NOTIFY_ERROR, 3) end
        return
    end

    local count = 0
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and string.find(ent:GetClass(), "verse_mob_", 1, true) then
            ent:Remove()
            count = count + 1
        end
    end
    if isfunction(ply.Notify) then
        ply:Notify(count .. " mob(s) supprime(s).", NOTIFY_HINT, 3)
    end
end)
