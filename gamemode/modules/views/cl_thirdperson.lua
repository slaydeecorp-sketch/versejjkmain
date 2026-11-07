-- ─── Vue à la 3e personne intégrée (toggle F1) ───────────────────────────────
-- Remplace l'addon "Simple ThirdPerson". Caméra over-the-shoulder avec trace
-- anti-mur (la caméra ne traverse pas les murs). F1 active/désactive instantanément.
if SERVER then return end

VERSE.ThirdPerson = VERSE.ThirdPerson or {}
local TP = VERSE.ThirdPerson
if TP.Enabled == nil then TP.Enabled = true end

VERSE.Hook.AddNS("ThirdPerson", "PlayerSpawn", "VERSE::ThirdPerson::EnableOnSpawn", function(ply)
    if IsValid(ply) and ply == LocalPlayer() then
        TP.Enabled = true
    end
end)

-- ─── Réglages (faciles à ajuster) ────────────────────────────────────────────
local DISTANCE = 95             -- recul de la caméra derrière le joueur
local HEIGHT   = 6              -- hauteur de la caméra
local SHOULDER = 16             -- décalage épaule (droite ; 0 = centré derrière)
local HULL_MIN = Vector(-6, -6, -6)
local HULL_MAX = Vector(6, 6, 6)

local function canThirdPerson(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:InVehicle() then return false end
    return true
end

-- F1 = toggle. Détection directe de la touche (fiable quel que soit le bind, contrairement
-- au hook ShowHelp qui ne se déclenche que si F1 est bind sur gm_showhelp). Front montant
-- uniquement, et ignoré quand on tape (chat/console) ou que le menu jeu est ouvert.
local _f1Down = false
VERSE.Hook.AddNS("ThirdPerson", "Think", "VERSE::ThirdPerson::Toggle", function()
    local down = input.IsKeyDown(KEY_F1)
    if down and not _f1Down and not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible() then
        TP.Enabled = not TP.Enabled
    end
    _f1Down = down
end)

-- Caméra. Enregistré APRÈS Freecam/Staff (ordre alphabétique des fichiers) → la 3e
-- personne ne s'applique que si aucun de ces modes n'a déjà imposé une vue.
VERSE.Hook.AddNS("ThirdPerson", "CalcView", "VERSE::ThirdPerson::CalcView", function(ply, pos, angles, fov)
    if not TP.Enabled then return end
    if not canThirdPerson(ply) then return end

    local desired = pos
                  + angles:Right()   * SHOULDER
                  + angles:Up()      * HEIGHT
                  - angles:Forward() * DISTANCE

    local tr = util.TraceHull({
        start  = pos,
        endpos = desired,
        mins   = HULL_MIN,
        maxs   = HULL_MAX,
        filter = ply,
        mask   = MASK_SOLID,
    })

    return {
        origin = tr.Hit and tr.HitPos or desired,
        angles = angles,
        fov    = fov,
    }
end)

-- Dessine le joueur local quand la 3e personne est active.
VERSE.Hook.AddNS("ThirdPerson", "ShouldDrawLocalPlayer", "VERSE::ThirdPerson::DrawSelf", function(ply)
    if TP.Enabled and ply == LocalPlayer() and canThirdPerson(ply) then return true end
end)

-- Commande console équivalente (pour bind perso si besoin).
concommand.Add("verse_thirdperson", function()
    TP.Enabled = not TP.Enabled
end, nil, "Active/désactive la vue à la 3e personne (aussi sur F1).")
