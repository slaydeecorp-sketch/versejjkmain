AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ─── Initialisation ───────────────────────────────────────────────────────────

function ENT:Initialize()
    self:SetModel(self.ModelPath)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    -- COLLISION_GROUP_NONE : entité pleinement traçable par tous les types de traces.
    -- COLLISION_GROUP_NPC bloquait certaines traces de TCS (FindInSphere + LOS check).
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetTakeDamage(DAMAGE_YES)

    self:SetMaxHealth(self.MobMaxHP)
    self:SetHealth(self.MobMaxHP)

    self:SetNWFloat("VMobHP",    self.MobMaxHP)
    self:SetNWFloat("VMobMaxHP", self.MobMaxHP)
    self:SetNWString("VMobName", self.MobName)
    self:SetNWBool("VMobDead",   false)

    self._state        = "IDLE"
    self._target       = nil
    self._lastAttacker = nil
    self._attacking    = false
    self._staggering   = false
    self._dead         = false
    self._nextAttack   = 0

    -- Bornes de collision explicites (configurables dans shared.lua → MobBBoxMins/Maxs).
    -- On les force AVANT PhysicsInit pour que la VPhysics hull corresponde.
    self:SetCollisionBounds(self.MobBBoxMins, self.MobBBoxMaxs)

    -- La bbox étant centrée (Z symétrique), l'origine doit être à mi-hauteur du sol.
    -- DropToFloor() ne suffit pas avec MOVETYPE_NONE + SOLID_BBOX centré.
    -- On remonte l'entité de MobHalfHeight pour que ses pieds touchent le sol.
    self:SetPos(self:GetPos() + Vector(0, 0, self.MobHalfHeight))

    -- Debug : bornes OBB du modèle compilé (à comparer avec MobBBoxMins/Maxs)
    print("[MOB] =================== INIT ===================")
    print("[MOB] Modèle      :", self.ModelPath)
    print("[MOB] OBBMins     :", self:OBBMins(),   "  OBBMaxs:", self:OBBMaxs())
    print("[MOB] OBBCenter   :", self:OBBCenter())
    print("[MOB] BBox config : Mins=" .. tostring(self.MobBBoxMins) .. "  Maxs=" .. tostring(self.MobBBoxMaxs))
    for i = 0, self:GetSequenceCount() - 1 do
        print("[MOB] seq", i, "->", self:GetSequenceName(i))
    end
    print("[MOB] Cherche AnimIdle  '" .. tostring(self.AnimIdle)   .. "' -> seq", self:LookupSequence(self.AnimIdle))
    print("[MOB] Cherche AnimRun   '" .. tostring(self.AnimRun)    .. "' -> seq", self:LookupSequence(self.AnimRun))
    print("[MOB] Cherche AnimAttack'" .. tostring(self.AnimAttack) .. "' -> seq", self:LookupSequence(self.AnimAttack))
    print("[MOB] ===============================================")

    self:_PlayAnim(self.AnimIdle, true)

    -- Timer AI garanti (évite tout problème de scheduling Think)
    local eid = self:EntIndex()
    self._timerName = "VMob_AI_" .. eid
    timer.Create(self._timerName, 0.1, 0, function()
        if not IsValid(self) then
            timer.Remove(self._timerName or "")
            return
        end
        self:_AITick()
    end)
end

function ENT:OnRemove()
    if self._timerName then timer.Remove(self._timerName) end
end

-- ─── Utilitaires ──────────────────────────────────────────────────────────────

function ENT:_PlayAnim(animName, loop)
    local seq = self:LookupSequence(animName)
    if not seq or seq < 0 then return end
    self:ResetSequence(seq)
    self:SetPlaybackRate(1)
    self:SetCycle(0)
end

function ENT:_FaceTarget(targetPos)
    local dir = targetPos - self:GetPos()
    dir.z = 0
    if dir:LengthSqr() < 1 then return end
    local ang = dir:Angle()
    ang.p = 0
    ang.r = 0
    self:SetAngles(ang)
end

function ENT:_SnapToGround()
    local pos = self:GetPos()
    local tr  = util.TraceLine({
        start  = pos + Vector(0, 0, 100),
        endpos = pos - Vector(0, 0, 1000),
        filter = self,
    })
    if tr.Hit then
        -- L'origine du modèle est au centre du mob (bbox symétrique).
        -- Pour que les pieds touchent le sol, il faut l'élever de MobHalfHeight.
        self:SetPos(tr.HitPos + Vector(0, 0, self.MobHalfHeight))
    end
end

-- ─── Recherche de cible ───────────────────────────────────────────────────────

function ENT:_FindTarget()
    local pos     = self:GetPos()
    local rangeSq = self.AggroRange * self.AggroRange
    local best, bestSq = nil, rangeSq

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive()  then continue end
        local dSq = pos:DistToSqr(ply:GetPos())
        if dSq < bestSq then bestSq = dSq; best = ply end
    end
    return best
end

-- ─── Dégâts & mort ───────────────────────────────────────────────────────────

function ENT:OnTakeDamage(dmginfo)
    if self._dead then return end

    local dmg   = dmginfo:GetDamage()
    local newHP = math.max(0, self:Health() - dmg)
    self:SetHealth(newHP)
    self:SetNWFloat("VMobHP", newHP)

    local atk = dmginfo:GetAttacker()
    if IsValid(atk) and atk:IsPlayer() then self._lastAttacker = atk end

    -- ── Hitmarker TCS (même format que le mannequin) ──────────────────────────
    -- catId : 0=Unknown 1=Bleed 2=Melee 3=Occult 4=Venom
    -- Utilise TCS.Enums si disponible, sinon fallback manuel.
    local dt    = dmginfo:GetDamageType()
    local catId = 0
    if TCS and TCS.Enums and TCS.Enums.GetDamageCategory then
        local catName = TCS.Enums.GetDamageCategory(dt)
        if     catName == "Bleed"  then catId = 1
        elseif catName == "Melee"  then catId = 2
        elseif catName == "Occult" then catId = 3
        elseif catName == "Venom"  then catId = 4
        elseif catName == "Burn"   then catId = 3
        end
    else
        if     bit.band(dt, DMG_SLASH)      ~= 0 then catId = 2
        elseif bit.band(dt, DMG_CLUB)       ~= 0 then catId = 1
        elseif bit.band(dt, DMG_BULLET)     ~= 0 then catId = 3
        elseif bit.band(dt, DMG_ENERGYBEAM) ~= 0 then catId = 3
        elseif bit.band(dt, DMG_POISON)     ~= 0 then catId = 4
        elseif bit.band(dt, DMG_BURN)       ~= 0 then catId = 3
        end
    end

    if IsValid(atk) and atk:IsPlayer() then
        local relToTarget = self:OBBCenter() + Vector(0, 0, 20)
        net.Start("TCS:Hitmarker")
            net.WriteEntity(self)
            net.WriteFloat(dmg)
            net.WriteUInt(catId, 3)
            net.WriteVector(relToTarget)
        net.Send(atk)
    end

    if newHP <= 0 then self:_Die() else self:_Stagger() end
end

function ENT:_Die()
    if self._dead then return end
    self._dead = true

    if self._timerName then timer.Remove(self._timerName) end

    self:SetNWBool("VMobDead", true)
    self:SetNWFloat("VMobHP",  0)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self:_PlayAnim(self.AnimDeath, false)

    local atk = self._lastAttacker
    if IsValid(atk) and atk:IsPlayer() then
        if isfunction(atk.AddEXP) then atk:AddEXP(self.MobXP) end
        if VERSE and VERSE.Mobs then
            netstream.Start(atk, VERSE.Mobs.Net.XPGain, self.MobXP)
        end
        if VERSE and VERSE.Log then
            VERSE.Log:Info("[Mobs] " .. atk:Nick() .. " a tué " .. self.MobName .. " (+" .. self.MobXP .. " XP)")
        end
    end

    timer.Simple(self.DeathRemoveDelay, function()
        if IsValid(self) then self:Remove() end
    end)
end

-- ─── Stagger ─────────────────────────────────────────────────────────────────

function ENT:_Stagger()
    if self._staggering or self._attacking or self._dead then return end
    self._staggering = true
    self:_PlayAnim(self.AnimHit, false)

    timer.Simple(self.StaggerDuration, function()
        if not IsValid(self) or self._dead then return end
        self._staggering = false
        self:_PlayAnim(self._state == "CHASE" and self.AnimRun or self.AnimIdle, true)
    end)
end

-- ─── Attaque ─────────────────────────────────────────────────────────────────

function ENT:_DoAttack()
    if self._attacking or self._staggering or self._dead then return end
    if CurTime() < self._nextAttack then return end

    self._attacking = true
    self:_PlayAnim(self.AnimAttack, false)

    timer.Simple(self.AttackDmgFrame, function()
        if not IsValid(self) or self._dead then return end
        local t = self._target
        if not IsValid(t) then return end
        if self:GetPos():Distance(t:GetPos()) <= self.AttackRange * 1.4 then
            local dmg = DamageInfo()
            dmg:SetDamage(self.MobDamage)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH)
            t:TakeDamageInfo(dmg)
        end
    end)

    timer.Simple(self.AttackTotalTime, function()
        if not IsValid(self) or self._dead then return end
        self._attacking  = false
        self._nextAttack = CurTime() + self.AttackCooldown
        if self._state == "ATTACK" and not self._staggering then
            self:_PlayAnim(self.AnimIdle, true)
        end
    end)
end

-- ─── Changement d'état ───────────────────────────────────────────────────────

function ENT:_SetState(newState)
    if self._state == newState then return end
    self._state = newState

    if newState == "IDLE" then
        self._target = nil
        self:_PlayAnim(self.AnimIdle, true)
    elseif newState == "CHASE" then
        self:_PlayAnim(self.AnimRun, true)
    elseif newState == "ATTACK" then
        self:_PlayAnim(self.AnimIdle, true)
    end
end

-- ─── Boucle IA (timer 0.1s) ───────────────────────────────────────────────────

function ENT:_AITick()
    if self._dead or self._staggering then return end

    -- Colle au sol
    self:_SnapToGround()

    local pos = self:GetPos()

    if self._state == "IDLE" then

        local t = self:_FindTarget()
        if IsValid(t) then
            self._target = t
            self:_SetState("CHASE")
        end

    elseif self._state == "CHASE" then

        local t = self._target
        if not IsValid(t) or not t:Alive() then
            self:_SetState("IDLE")
            return
        end

        local dist = pos:Distance(t:GetPos())

        if dist > self.LoseRange then
            self:_SetState("IDLE")
        elseif dist <= self.AttackRange then
            self:_SetState("ATTACK")
        elseif not self._attacking then
            local dir = t:GetPos() - pos
            dir.z = 0
            dir:Normalize()
            local newPos = pos + dir * (self.MobSpeed * 0.1)
            local tr = util.TraceLine({
                start  = newPos + Vector(0, 0, 100),
                endpos = newPos - Vector(0, 0, 1000),
                filter = self,
            })
            if tr.Hit then newPos = tr.HitPos + Vector(0, 0, 1) end
            self:SetPos(newPos)
            self:_FaceTarget(t:GetPos())
        end

    elseif self._state == "ATTACK" then

        local t = self._target
        if not IsValid(t) or not t:Alive() then
            self:_SetState("IDLE")
            return
        end

        local dist = pos:Distance(t:GetPos())

        if dist > self.AttackRange * 1.6 then
            self:_SetState("CHASE")
        else
            self:_FaceTarget(t:GetPos())
            self:_DoAttack()
        end

    end
end

-- ─── Compatibilité TCS ───────────────────────────────────────────────────────
-- Même stubs que le mannequin d'entraînement pour éviter les erreurs Lua
-- quand TCS appelle des méthodes Player-only ou Entity-only sur cette entité.

-- SteamID64 : utilisé comme clé de timer dans OnTargetHitGround (TCS).
function ENT:SteamID64()
    return "mob_" .. tostring(self:EntIndex())
end

-- PlayAnim : méthode custom TCS/Player – délègue à _PlayAnim interne.
function ENT:PlayAnim(anim)
    if anim and not self._dead then
        self:_PlayAnim(anim, false)
    end
end

-- IsTarget : TCS sv_meta définit IsTarget() comme renvoyant false pour tout
--            ce qui n'est pas un Player. On surcharge ici pour que les coups de
--            poing (performRotatedDiagonalHitBox) puissent toucher le mob.
function ENT:IsTarget()
    return not self._dead
end

-- Alive : méthode Player-only dans GMod ; TCS la vérifie dans le hitbox loop.
function ENT:Alive()
    return not self._dead
end

-- SetEyeAngles : Player-only. Appelé après un coup projeté (shouldProject).
function ENT:SetEyeAngles(ang) end   -- no-op pour un mob

-- hasState : TCS vérifie des states (ex: "jjk_untargettable") sur toutes entités.
function ENT:hasState(state)
    return false
end

-- ─── Think (animations uniquement) ───────────────────────────────────────────

function ENT:Think()
    self:NextThink(CurTime())
    return true
end
