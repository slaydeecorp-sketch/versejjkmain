AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ─── Net ──────────────────────────────────────────────────────────────────────
-- Réutilise le canal hitmarker de TCS pour que le client affiche les chiffres
-- exactement comme pour un joueur normal.
-- Format : WriteEntity(dummy), WriteFloat(dmg), WriteUInt(catId,3), WriteVector(relToTarget)

util.AddNetworkString("TCS:Hitmarker")   -- déjà déclaré par TCS ; safe de redéclarer

-- ─── Initialisation ───────────────────────────────────────────────────────────

function ENT:Initialize()
    self:SetModel(self.ModelPath)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetTakeDamage(DAMAGE_YES)

    self:SetMaxHealth(self.DummyMaxHP)
    self:SetHealth(self.DummyMaxHP)

    self:SetNWString("VDummyName", self.DummyName)

    self:PhysicsInit(SOLID_BBOX)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    self:DropToFloor()
end

function ENT:OnRemove() end

-- ─── Dégâts ───────────────────────────────────────────────────────────────────
-- Le mannequin est immortel : on intercepte les dégâts, on les affiche comme
-- hitmarker TCS, et on remet la vie au max immédiatement.

function ENT:OnTakeDamage(dmginfo)
    local dmg = dmginfo:GetDamage()
    if dmg <= 0 then return end

    -- Remettre immédiatement la vie au max (immortalité)
    self:SetHealth(self.DummyMaxHP)

    -- Identifier le type de dégât → catId TCS (même enum que cl_hitmarker.lua)
    -- 0=Unknown 1=Bleed 2=Melee 3=Occult 4=Venom
    local dt   = dmginfo:GetDamageType()
    local catId = 0
    if     bit.band(dt, DMG_SLASH)  ~= 0 then catId = 2   -- Melee
    elseif bit.band(dt, DMG_CLUB)   ~= 0 then catId = 2
    elseif bit.band(dt, DMG_BULLET) ~= 0 then catId = 2
    elseif bit.band(dt, DMG_BURN)   ~= 0 then catId = 3   -- Occult (magie/feu)
    elseif bit.band(dt, DMG_POISON) ~= 0 then catId = 4   -- Venom
    elseif bit.band(dt, DMG_DIRECT) ~= 0 then catId = 3
    end

    -- Position relative au mannequin – on utilise OBBCenter pour éviter que
    -- GetDamagePosition() retourne (0,0,0) et place le chiffre loin du dummy.
    local relToTarget = self:OBBCenter() + Vector(0, 0, 20)

    -- Envoyer uniquement à l'attaquant
    local atk = dmginfo:GetAttacker()
    if not IsValid(atk) or not atk:IsPlayer() then return end

    net.Start("TCS:Hitmarker")
        net.WriteEntity(self)
        net.WriteFloat(dmg)
        net.WriteUInt(catId, 3)
        net.WriteVector(relToTarget)
    net.Send(atk)
end

-- ─── Compatibilité TCS hitbox ─────────────────────────────────────────────────
-- IsTarget() et Alive() sont patchés directement sur la métatable Entity dans
-- sv_training_dummy.lua (les méthodes ENT ne surchargent pas la métatable C++).
-- Les stubs ci-dessous couvrent les méthodes Player-only appelées par TCS lors
-- des combos / projections (sv_attacks.lua) pour éviter les erreurs Lua.

-- SteamID64 : utilisé comme clé de timer unique dans OnTargetHitGround (TCS).
function ENT:SteamID64()
    return "dummy_" .. tostring(self:EntIndex())
end

-- PlayAnim : méthode custom TCS/Player – no-op sur le mannequin.
function ENT:PlayAnim(anim)
    -- pas d'animations de combat sur le mannequin
end

-- Think non nécessaire : le mannequin est statique (MOVETYPE_NONE), pas d'animations.
