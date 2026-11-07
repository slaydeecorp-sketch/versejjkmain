local P = VERSE.Pain
if not P then return end

-- ─── Activation / désactivation ───────────────────────────────────────────────
local function setPain(ply, state)
    if ply._inPain == state then return end
    ply._inPain = state

    if state then
        -- Bloque le sprint TCS : cooldown infini + flag
        ply._nextSprint    = CurTime() + 999999
        ply._isSprinting   = false
        -- État pour TOOM_JJK.PreventAttackState (sorts)
        ply.States         = ply.States or {}
        ply.States["pain"] = true
    else
        -- Réinitialise le cooldown sprint
        ply._nextSprint    = nil
        ply._isSprinting   = false
        if ply.States then
            ply.States["pain"] = nil
        end
        -- Restaure la vitesse de déplacement directement depuis _statTotals
        -- sans appeler RecalcStats() : ce dernier peut remettre les HP à 100
        -- (valeur GMod par défaut) si la chaîne de recalcul repart de zéro.
        local stats    = istable(ply._statTotals) and ply._statTotals or {}
        local walkSpd  = tonumber(stats["WalkSpeed"]) or ply:GetWalkSpeed()
        local runSpd   = tonumber(stats["RunSpeed"])  or ply:GetRunSpeed()
        ply:SetWalkSpeed(math.max(walkSpd, 50))
        ply:SetRunSpeed(math.max(runSpd,  50))
    end

    -- Broadcast à tous les clients (icône au-dessus de la tête)
    ply:SetNWBool("VERSE_InPain", state)
    -- Notification privée au joueur concerné (overlay + son)
    netstream.Start(ply, P.Net.State, state)
end

local function checkPain(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then
        if IsValid(ply) and ply._inPain then setPain(ply, false) end
        return
    end
    local maxHp = ply:GetMaxHealth()
    if maxHp <= 0 then return end
    setPain(ply, ply:Health() / maxHp < P.Threshold)
end

-- ─── Surveillance HP ──────────────────────────────────────────────────────────
-- Après chaque dégât (déféré d'un tick pour lire la vie post-dégât réel)
VERSE.Hook.AddNS("Pain", "VERSE::Combat::PostDamage", "VERSE::Pain::PostDamage",
function(target, _, _2)
    if IsValid(target) and target:IsPlayer() then
        timer.Simple(0, function()
            if IsValid(target) then checkPain(target) end
        end)
    end
end)

-- Détection de la régénération (toutes les 1s)
timer.Create("VERSE::Pain::RegenCheck", 1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
            checkPain(ply)
        end
    end
end)

hook.Add("PlayerSpawn", "VERSE::Pain::ClearOnSpawn", function(ply)
    if IsValid(ply) then setPain(ply, false) end
end)

hook.Add("PlayerDeath", "VERSE::Pain::ClearOnDeath", function(ply)
    if IsValid(ply) then setPain(ply, false) end
end)

-- ─── Blocage du sprint + vitesse divisée par 2 (per-tick) ───────────────────
-- On lit la vitesse RÉELLE depuis _statTotals (valeur du système de stats) pour
-- ne pas accumuler de réductions successives si SetWalkSpeed a déjà été modifié.
local function getPainHalfSpeed(ply)
    local fullWalk = (istable(ply._statTotals) and ply._statTotals["WalkSpeed"])
                  or ply:GetWalkSpeed()
    return math.max(50, math.floor(fullWalk * 0.5))
end

hook.Add("PlayerPreThink", "VERSE::Pain::SpeedCap", function(ply)
    if not IsValid(ply) or not ply._inPain then return end
    local half = getPainHalfSpeed(ply)
    -- Applique uniquement si la vitesse a été modifiée par un autre système
    if ply:GetWalkSpeed() ~= half then ply:SetWalkSpeed(half) end
    if ply:GetRunSpeed()  ~= half then ply:SetRunSpeed(half)  end
    -- Écrase le cooldown sprint TCS en continu
    ply._nextSprint  = CurTime() + 999999
    ply._isSprinting = false
end)

-- Filet de sécurité via SetupMove (couvre aussi les cas edge de TCS / véhicule)
hook.Add("SetupMove", "VERSE::Pain::SetupMove", function(ply, mv, _)
    if not IsValid(ply) or not ply._inPain then return end
    local half = getPainHalfSpeed(ply)
    if mv:GetMaxSpeed() > half then
        mv:SetMaxSpeed(half)
        mv:SetMaxClientSpeed(half)
    end
end)

-- ─── Wrapping TCS (différé d'un tick pour s'assurer que l'addon est chargé) ───
timer.Simple(0, function()

    -- 1) Attaques corps-à-corps (TCS.Attacks.PerformAttack)
    if TCS and TCS.Attacks and isfunction(TCS.Attacks.PerformAttack) then
        local orig = TCS.Attacks.PerformAttack
        TCS.Attacks.PerformAttack = function(self, wep)
            local owner = IsValid(wep) and wep:GetOwner() or nil
            if IsValid(owner) and owner:IsPlayer() and owner._inPain then return end
            return orig(self, wep)
        end
    end

    -- 2) Esquives (méthode player meta)
    local meta = FindMetaTable("Player")
    if meta and isfunction(meta.Dodge) then
        local orig = meta.Dodge
        meta.Dodge = function(self, ...)
            if self._inPain then return end
            return orig(self, ...)
        end
    end

    -- 3) Sorts : injection dans TOOM_JJK.PreventAttackState
    --    La table utilise des CLÉS string (["state"]=true), pas un tableau.
    --    `table.insert` ajoutait une clé numérique [1]="pain" qui ne matchait
    --    jamais le check `ply.States[state]` (state=1 au lieu de "pain").
    --    Fix : assignation directe de la clé string.
    if TOOM_JJK and istable(TOOM_JJK.PreventAttackState) then
        TOOM_JJK.PreventAttackState["pain"] = true
    end

end)
