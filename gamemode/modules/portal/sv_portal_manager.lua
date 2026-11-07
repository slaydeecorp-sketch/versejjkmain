-- sv_portal_manager.lua
-- Gestion des portails inter-serveurs.
-- Commandes :
--   verse_spawn_portal <ip:port> <password> <label>   → spawne un portail devant soi
--   verse_remove_portal                                → supprime le portail le plus proche
-- Les portails sont sauvegardés dans data/verse_portals.txt et rechargés au démarrage.

if not SERVER then return end

local DATA_FILE = "verse_portals.txt"

-- ── Sauvegarde ────────────────────────────────────────────────────────────────

function VERSE_Portal_Save()
    local list = {}
    for _, ent in ipairs(ents.FindByClass("sent_portal_server")) do
        if not IsValid(ent) then continue end
        local p, a = ent:GetPos(), ent:GetAngles()
        list[#list + 1] = {
            ip    = ent:GetDestIP(),
            pass  = ent._destPass or "",
            label = ent:GetDestLabel(),
            pos   = { p.x, p.y, p.z },
            ang   = { a.p, a.y, a.r },
        }
    end
    file.Write(DATA_FILE, util.TableToJSON(list, true))
end

-- ── Chargement ────────────────────────────────────────────────────────────────

local function spawnPortal(ip, pass, label, pos, ang)
    local ent = ents.Create("sent_portal_server")
    if not IsValid(ent) then return nil end
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:SetDestIP(ip)
    ent:SetDestLabel(label)
    ent._destPass = pass
    ent:Spawn()
    ent:Activate()
    return ent
end

local function loadPortals()
    if not file.Exists(DATA_FILE, "DATA") then return end
    local raw = file.Read(DATA_FILE, "DATA")
    if not raw or raw == "" then return end
    local list = util.JSONToTable(raw)
    if not istable(list) then return end
    for _, entry in ipairs(list) do
        local p   = entry.pos
        local a   = entry.ang
        local pos = Vector(p[1], p[2], p[3])
        local ang = Angle(a[1], a[2], a[3])
        spawnPortal(entry.ip, entry.pass or "", entry.label or entry.ip, pos, ang)
    end
    print("[VERSE Portal] " .. #list .. " portail(s) chargé(s).")
end

hook.Add("InitPostEntity", "VERSE::Portal::Load", function()
    timer.Simple(1, loadPortals)
end)

-- ── Commandes admin ───────────────────────────────────────────────────────────

local function isAdmin(ply)
    if not IsValid(ply) then return true end  -- console
    return ply:IsSuperAdmin() or (isfunction(ply.IsDeveloper) and ply:IsDeveloper())
end

local function notify(ply, msg, level)
    level = level or NOTIFY_HINT
    if IsValid(ply) and isfunction(ply.Notify) then
        ply:Notify(msg, level, 5)
    else
        print("[VERSE Portal] " .. msg)
    end
end

-- verse_spawn_portal <ip:port> <password> <label>
concommand.Add("verse_spawn_portal", function(ply, cmd, args, argStr)
    if IsValid(ply) and not isAdmin(ply) then
        notify(ply, "Permission refusée.", NOTIFY_ERROR)
        return
    end

    -- On parse argStr (chaîne brute) pour éviter que GMod splitte le ":" de l'IP
    argStr = (argStr or ""):Trim()
    local ip, rest = argStr:match("^(%S+)%s+(.*)")
    if not ip or ip == "" then
        notify(ply, "Usage: verse_spawn_portal <ip:port> <password> <label>", NOTIFY_HINT)
        return
    end
    local pass, label = (rest or ""):match("^(%S+)%s+(.*)")
    if not pass then pass = (rest or ""):Trim(); label = "" end
    label = (label or ""):Trim()
    if label == "" then label = ip end

    local pos, ang
    if IsValid(ply) then
        pos = ply:GetPos() + ply:GetForward() * 100 + Vector(0, 0, 30)
        ang = Angle(0, ply:GetAngles().y + 180, 0)
    else
        notify(ply, "Commande réservée aux joueurs en jeu.", NOTIFY_ERROR)
        return
    end

    local ent = spawnPortal(ip, pass, label, pos, ang)
    if not IsValid(ent) then
        notify(ply, "Erreur lors de la création du portail.", NOTIFY_ERROR)
        return
    end

    VERSE_Portal_Save()
    notify(ply, "Portail vers \"" .. label .. "\" spawné et sauvegardé.", NOTIFY_HINT)
end)

-- verse_remove_portal  → supprime le portail le plus proche du joueur (max 300 u)
concommand.Add("verse_remove_portal", function(ply, cmd, args)
    if not IsValid(ply) then
        print("[VERSE Portal] Commande réservée aux joueurs en jeu.")
        return
    end
    if not isAdmin(ply) then
        notify(ply, "Permission refusée.", NOTIFY_ERROR)
        return
    end

    local best, bestDist = nil, 300 * 300
    for _, ent in ipairs(ents.FindByClass("sent_portal_server")) do
        if not IsValid(ent) then continue end
        local d = ent:GetPos():DistToSqr(ply:GetPos())
        if d < bestDist then best = ent; bestDist = d end
    end

    if not IsValid(best) then
        notify(ply, "Aucun portail à moins de 300 unités.", NOTIFY_HINT)
        return
    end

    local label = best:GetDestLabel()
    best:Remove()
    VERSE_Portal_Save()
    notify(ply, "Portail vers \"" .. label .. "\" supprimé.", NOTIFY_HINT)
end)
