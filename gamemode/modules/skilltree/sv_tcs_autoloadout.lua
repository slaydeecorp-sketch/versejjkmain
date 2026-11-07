if not SERVER then return end

-- Donne tcs_base apres le PlayerLoadout du job (qui fait StripWeapons)
-- UNIQUEMENT si le joueur a deja debloque au moins une competence martiale.
-- On utilise un timer.Simple(0) pour s'executer au tick suivant, apres tous les hooks de loadout.

local function giveTCS(ply)
    if not IsValid(ply) then return end
    local ST = VERSE.SkillTree
    if not ST then return end

    local charId = ST:GetCharacterUID(ply)
    if not charId then return end

    -- Verifie le flag permanent (meta.martial_weapon_granted)
    local meta = ST._metaCache and ST._metaCache[charId]
    local granted = istable(meta) and meta.martial_weapon_granted == true

    if not granted then
        -- Fallback : scan des noeuds dans le cache (si deja charge)
        local state = ST._cache and ST._cache[charId]
        if state then
            local weaponMap = ST.MartialWeaponMap or {}
            for nodeId, rank in pairs(state.nodes or {}) do
                if (tonumber(rank) or 0) > 0 then
                    local node = ST:GetNode(nodeId)
                    if node and weaponMap[tostring(node.subtype_id or "")] then
                        granted = true
                        break
                    end
                end
            end
        end
        -- Si les donnees ne sont pas encore chargees, ne pas donner l'arme.
        -- syncTCSFromState (VERSE::SkillTree::PlayerSynced) s'en chargera plus tard.
        if not granted then return end
    end

    -- Applique le type d'arme TCS enregistre dans le meta
    if istable(meta) and isstring(meta.martial_weapon_type) and meta.martial_weapon_type ~= "" then
        if isfunction(ply.SetTCSWeapon) then
            ply:SetTCSWeapon(meta.martial_weapon_type)
        end
    end

    if not ply:HasWeapon("tcs_base") then
        ply:Give("tcs_base")
    end
    ply:SelectWeapon("tcs_base")
end

VERSE.Hook.AddNS("TCSAutoLoadout", "PlayerSpawn", "VERSE::TCSAutoLoadout::PlayerSpawn", function(ply)
    timer.Simple(0, function()
        giveTCS(ply)
    end)
end)
