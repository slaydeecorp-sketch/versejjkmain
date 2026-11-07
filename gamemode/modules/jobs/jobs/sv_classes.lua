-- sv_classes.lua
-- Persistance automatique des grades de classe dans verse_characters.job_id
-- + migration one-shot pour les anciens personnages encore en "citizen"
-- + application directe des stats HP/EO apres attribution d'un grade
-- + reapplication apres chaque respawn pour contrer les reinitialisations.
-- ─────────────────────────────────────────────────────────────────────────────

local DB = VERSE.DB
local CH -- initialisé après chargement complet des modules

-- Liste des job IDs qui constituent un grade de classe (standards + clans).
local CLASS_JOB_IDS = {
    -- Grades standards
    ["classe_4"]      = true,
    ["classe_3"]      = true,
    ["semi_classe_2"] = true,
    ["classe_2"]      = true,
    ["semi_classe_1"] = true,
    ["classe_1"]      = true,
    ["classe_s"]      = true,
    -- Grades de clan : Gojo
    ["classe_4_gojo"]      = true,
    ["classe_3_gojo"]      = true,
    ["semi_classe_2_gojo"] = true,
    ["classe_2_gojo"]      = true,
    ["semi_classe_1_gojo"] = true,
    ["classe_1_gojo"]      = true,
    ["classe_s_gojo"]      = true,
    ["elu_gojo"]           = true,
    -- Grades de clan : Sukuna
    ["vermine_sukuna"]      = true,
    ["abomination_sukuna"]  = true,
    ["corrupteur_sukuna"]   = true,
    ["executeur_sukuna"]    = true,
    ["fossoyeur_sukuna"]    = true,
    ["ravageur_sukuna"]     = true,
    ["calamite_sukuna"]     = true,
    -- Grades de clan : Zenin
    ["classe_4_zenin"]      = true,
    ["classe_3_zenin"]      = true,
    ["semi_classe_2_zenin"] = true,
    ["classe_2_zenin"]      = true,
    ["semi_classe_1_zenin"] = true,
    ["classe_1_zenin"]      = true,
    ["classe_s_zenin"]      = true,
    -- Grades de clan : Mahito
    ["vermine_mahito"]      = true,
    ["abomination_mahito"]  = true,
    ["corrupteur_mahito"]   = true,
    ["executeur_mahito"]    = true,
    ["fossoyeur_mahito"]    = true,
    ["ravageur_mahito"]     = true,
    ["calamite_mahito"]     = true,
    ["prince_fleaux_mahito"] = true,
    -- Grades supérieurs : Sukuna
    ["prince_fleaux_sukuna"] = true,
    ["roi_fleaux_sukuna"]    = true,
    -- Rôle spécial
    ["directeur"]            = true,
    -- Grades Fléaux génériques (sans clan)
    ["vermine"]              = true,
    ["abomination"]          = true,
    ["corrupteur"]           = true,
    ["executeur"]            = true,
    ["fossoyeur"]            = true,
    ["ravageur"]             = true,
    ["calamite"]             = true,
    ["prince_fleaux"]        = true,
}

-- ─── Application directe des stats ───────────────────────────────────────────
local function forceApplyClassStats(ply, jobId)
    if not IsValid(ply) then return end
    local job = VERSE.Jobs and VERSE.Jobs:Get(jobId)
    if not job then return end

    local stats     = job.stats or {}
    local hp        = math.max(1, tonumber(stats.health) or 100)
    local manaBonus = tonumber(stats.mana) or 0

    -- HP
    ply:SetMaxHealth(hp)
    ply:SetHealth(hp)

    -- Cache _statTotals (lu par GetStat / GetPlayerManaMax)
    if not istable(ply._statTotals) then ply._statTotals = {} end
    ply._statTotals["Health"] = hp
    ply._statTotals["Mana"]   = manaBonus

    -- NWVar stats (HUD client)
    if ply.SetPublicInt then
        ply:SetPublicInt("VERSE::Stats::Health", hp)
        ply:SetPublicInt("VERSE::Stats::Mana",   manaBonus)
    end

    -- Energie Occulte
    local C = VERSE and VERSE.Combat
    if C and C.SyncMana then
        local manaMax = C:GetPlayerManaMax(ply)  -- ManaBase(0) + manaBonus
        if ply.SetMana then
            ply:SetMana(manaMax, true)
        else
            C:SyncMana(ply)
        end
    end
end

-- ─── API publique ────────────────────────────────────────────────────────────
-- VERSE.Classes.ReapplyStats(ply) :
--   Réapplique les stats du grade de classe mémorisé sur le joueur SANS réinitialiser
--   la HP actuelle (sauf si RecalcStats l'avait déjà remise au plancher par erreur).
--   Appeler après tout ply:RecalcStats() appelé hors d'un SetPlayerJob (ex : reroll skilltree)
--   pour contrer la perte de stats de classe quand ply.Job est nil à ce moment-là.
VERSE.Classes = VERSE.Classes or {}
function VERSE.Classes.ReapplyStats(ply)
    if not IsValid(ply) then return end
    local jobId = ply._ClassJobId
    if not jobId or not CLASS_JOB_IDS[jobId] then return end
    local job = VERSE.Jobs and VERSE.Jobs:Get(jobId)
    if not job then return end

    local stats     = job.stats or {}
    local hp        = math.max(1, tonumber(stats.health) or 100)
    local manaBonus = tonumber(stats.mana) or 0

    -- HP : restaure le max et clamp le courant.
    -- Si le courant est déjà au max (RecalcStats a mis 100/100), on suppose que
    -- RecalcStats avait écrasé les vraies valeurs → restaure au max de classe.
    local curHp    = ply:Health()
    local curMax   = ply:GetMaxHealth()
    ply:SetMaxHealth(hp)
    if curHp >= curMax then
        -- Était à max (même après reset erroné) → restore au vrai max de classe.
        ply:SetHealth(hp)
    else
        ply:SetHealth(math.min(curHp, hp))
    end

    -- _statTotals et NWVars
    if not istable(ply._statTotals) then ply._statTotals = {} end
    ply._statTotals["Health"] = hp
    ply._statTotals["Mana"]   = manaBonus
    if ply.SetPublicInt then
        ply:SetPublicInt("VERSE::Stats::Health", hp)
        ply:SetPublicInt("VERSE::Stats::Mana",   manaBonus)
    end

    -- Energie Occulte : restaure le max et clamp le courant.
    local C = VERSE and VERSE.Combat
    if C and C.SyncMana then
        local manaMax = C:GetPlayerManaMax(ply)
        if ply.SetMana then
            local curMana = ply:GetMana()
            -- Si la mana était à 0 ou 1 après un reset erroné, restaure au max.
            if curMana <= 1 and manaMax > 1 then
                ply:SetMana(manaMax, true)
            else
                ply:SetMana(math.min(curMana, manaMax), true)
            end
        else
            C:SyncMana(ply)
        end
    end
end

-- ─── Hook VERSE::OnChanged::Jobs ─────────────────────────────────────────────
-- Mémorise le grade attribué sur le joueur ET applique les stats une frame plus
-- tard (après tous les autres traitements synchrones du même hook).
VERSE.Hook.AddNS("Classes", "VERSE::OnChanged::Jobs", "Classes::ApplyAndPersist", function(ply, jobId)
    if not IsValid(ply) then return end

    -- Si le nouveau job n'est PAS un grade de classe (ex : "citizen" lors du chargement
    -- d'un nouveau personnage), on efface le grade mémorisé pour éviter que les stats
    -- de l'ancien personnage ne se réappliquent au respawn.
    if not CLASS_JOB_IDS[jobId] then
        ply._ClassJobId = nil
        return
    end

    -- Mémorise le grade pour le retrouver après un respawn
    ply._ClassJobId = jobId

    -- Application différée
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if ply:GetJobID() ~= jobId then return end
        forceApplyClassStats(ply, jobId)
    end)

    -- Pendant LoadCharacter, le job_id vient déjà de la DB : ne pas réécrire.
    -- Sans ce guard, le hook écraserait le job_id du personnage précédent en DB.
    if ply.__loadingChar then return end

    -- Persistance verse_characters
    CH = CH or (VERSE and VERSE.Characters)
    if not CH then return end

    local charId = CH:GetSelectedCharID(ply)

    if not charId or charId == 0 then
        -- Pas de personnage sélectionné (joueur dans l'écran de sélection) :
        -- met à jour TOUS les personnages du joueur en DB et en cache
        -- pour que la classe soit persistée même sans personnage actif.
        local sid = isfunction(ply.SteamID64) and ply:SteamID64() or nil
        if sid and CH._cache and istable(CH._cache[sid]) then
            for _, char in pairs(CH._cache[sid]) do
                local cid = tonumber(char.id)
                if cid then
                    DB:Query("UPDATE verse_characters SET job_id=" .. DB:Escape(jobId) .. " WHERE id=" .. tostring(cid))
                    char.job_id = jobId
                end
            end
        end
        return
    end

    DB:Query(
        "UPDATE verse_characters SET job_id=" .. DB:Escape(jobId) ..
        " WHERE id=" .. tostring(math.floor(charId))
    )

    local selected = CH:GetSelected(ply)
    if istable(selected) then selected.job_id = jobId end
end)

-- ─── Hook PlayerSpawn ─────────────────────────────────────────────────────────
-- Après chaque respawn, réapplique les stats du grade mémorisé.
-- Le délai de 0.8s passe après tous les autres timers (mana sync à t=0,
-- inventory à t=0.5s, etc.) pour être le dernier à écrire les stats.
VERSE.Hook.AddNS("Classes", "PlayerSpawn", "Classes::ReapplyOnRespawn", function(ply)
    if not IsValid(ply) then return end
    local jobId = ply._ClassJobId
    if not jobId or not CLASS_JOB_IDS[jobId] then return end

    timer.Simple(0.8, function()
        if not IsValid(ply) then return end
        forceApplyClassStats(ply, jobId)
    end)
end)

-- ─── Migration one-shot (désactivée) ─────────────────────────────────────────
-- Plus nécessaire : les nouveaux personnages démarrent directement en classe_4
-- (voir sv_character.lua : res.job_id = "classe_4" dans CreateCharacter) et les
-- écritures de classe en DB utilisent désormais DB:Query + DB:Escape, donc
-- job_id ne peut plus redevenir "citizen" ou vide.  Relancer ce UPDATE à chaque
-- redémarrage était dangereux (risque d'écraser une classe valide si job_id
-- devenait accidentellement vide via un bug tiers).
-- DB:OnReady(function()
--     DB:Query("UPDATE verse_characters SET job_id='classe_4' WHERE job_id='citizen' OR job_id='' OR job_id IS NULL")
-- end)
