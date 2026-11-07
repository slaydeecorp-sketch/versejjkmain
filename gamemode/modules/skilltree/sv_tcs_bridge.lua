if not SERVER then return end

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local ST = VERSE.SkillTree
if not ST then return end

-- Retourne l'id TCS du sort lie a une ability du skill tree, ou nil.
local function getTCSSpellId(abilityId)
    local data = ST:GetAbilityData(abilityId)
    if not istable(data) then return nil end
    local exec = data.execution
    if not istable(exec) or exec.type ~= "tcs_spell" then return nil end
    local sid = tostring(exec.spell_id or "")
    return sid ~= "" and sid or nil
end

-- Niveau TCS = rang du noeud qui accorde l'ability (min 1).
local function getSpellLevel(abilityId, state)
    local nodeMap = ST:GetNodeMap()
    for nodeId, nodeData in pairs(nodeMap) do
        local abilities = nodeData.abilities or {}
        for _, aId in ipairs(abilities) do
            if aId == abilityId then
                return math.max(1, tonumber((state.nodes or {})[nodeId]) or 1)
            end
        end
    end
    return 1
end

-- Ensemble de tous les spell_id qui peuvent provenir du skill tree.
local function allTreeSpellIds()
    local ids = {}
    for _, abilityData in pairs(ST.Abilities or {}) do
        local exec = istable(abilityData) and abilityData.execution
        if istable(exec) and exec.type == "tcs_spell" then
            local sid = tostring(exec.spell_id or "")
            if sid ~= "" then ids[sid] = true end
        end
    end
    return ids
end

-- Renvoie le type d'arme TCS (lance/katana/fists) correspondant au premier noeud
-- martial débloqué dans l'état, ou nil si aucun noeud martial n'est présent.
local function getMartialWeaponTypeFromState(state)
    local weaponMap = ST.MartialWeaponMap or {}
    for nodeId, rank in pairs((state.nodes or {})) do
        if (tonumber(rank) or 0) > 0 then
            local node = ST:GetNode(nodeId)
            if node and weaponMap[tostring(node.subtype_id or "")] then
                return weaponMap[tostring(node.subtype_id)]
            end
        end
    end
    return nil
end

-- Synchronise entierement TCS depuis l'etat skill tree du joueur.
local function syncTCSFromState(ply, state, loadout)
    if not IsValid(ply) then return end
    if not TOOM_JJK or not TOOM_JJK.SPELLS then return end

    state = ST:NormalizeState(state)

    -- 1) Donne tous les sorts debloquees par le skill tree
    local unlocked = ST:GetUnlockedAbilitiesForState(state)
    for abilityId in pairs(unlocked) do
        local spellId = getTCSSpellId(abilityId)
        if spellId then
            local level = getSpellLevel(abilityId, state)
            ply:GiveSpell(spellId, level)
        end
    end

    -- 2) Retire les sorts du skill tree qui ne sont plus debloquees
    local treeIds = allTreeSpellIds()
    for spellId in pairs(treeIds) do
        if not unlocked then break end
        -- Cherche si ce spell est lie a une ability debloquee
        local stillOwned = false
        for abilityId in pairs(unlocked) do
            if getTCSSpellId(abilityId) == spellId then
                stillOwned = true
                break
            end
        end
        if not stillOwned then
            ply:RemoveSpell(spellId)
        end
    end

    -- 3) Equipe les slots depuis le preset actif du loadout
    if istable(loadout) then
        local presetIdx = math.max(1, tonumber(loadout.active_preset) or 1)
        local preset = istable(loadout.presets) and loadout.presets[presetIdx]
        if istable(preset) then
            local slots = preset.slots or {}
            for slotIdx = 1, ST:GetBindSlotCount() do
                local abilityId = tostring(slots[slotIdx] or "")
                local spellId = abilityId ~= "" and getTCSSpellId(abilityId) or nil
                ply:EquipSpell(slotIdx, spellId)
            end
        end
    end

    -- 4) Donne tcs_base uniquement si le joueur a une voie martiale débloquée.
    --    Utilise le flag permanent meta.martial_weapon_granted pour survivre aux resets.
    local charId = ST:GetCharacterUID(ply)
    local meta = charId and istable(ST._metaCache) and ST._metaCache[charId] or {}
    local granted = meta.martial_weapon_granted == true
    local weaponType = (isstring(meta.martial_weapon_type) and meta.martial_weapon_type ~= "") and meta.martial_weapon_type or nil

    if not granted then
        -- Scan des noeuds (premier chargement ou après migration)
        weaponType = getMartialWeaponTypeFromState(state)
        granted = weaponType ~= nil
    end

    if granted then
        if weaponType and isfunction(ply.SetTCSWeapon) then
            ply:SetTCSWeapon(weaponType)
        end
        -- Donne tcs_base au tick suivant (après le loadout du job)
        timer.Simple(0.3, function()
            if not IsValid(ply) then return end
            if not ply:HasWeapon("tcs_base") then
                ply:Give("tcs_base")
            end
        end)
    end
end

-- ─── Hooks ───────────────────────────────────────────────────────────────────

-- Chargement initial du personnage : sync complet
hook.Add("VERSE::SkillTree::PlayerSynced", "VERSE::TCSBridge::PlayerSynced", function(ply, charId, state, loadout)
    syncTCSFromState(ply, state, loadout)
end)

-- Noeud achete : donne le(s) sort(s) TCS du noeud + change l'arme si branche martiale
hook.Add("VERSE::SkillTree::NodePurchased", "VERSE::TCSBridge::NodePurchased", function(ply, nodeId, state)
    if not IsValid(ply) or not TOOM_JJK or not TOOM_JJK.SPELLS then return end
    local node = ST:GetNode(nodeId)
    if not node then return end
    local rank = math.max(1, tonumber((state.nodes or {})[nodeId]) or 1)
    for _, abilityId in ipairs(node.abilities or {}) do
        local spellId = getTCSSpellId(abilityId)
        if spellId then
            ply:GiveSpell(spellId, rank)
        end
    end

    -- Changement d'arme TCS si branche martiale choisie
    local subtypeId = tostring(node.subtype_id or "")
    local weaponMap = ST.MartialWeaponMap or {}
    local tcsWeaponId = weaponMap[subtypeId]
    if tcsWeaponId and isfunction(ply.SetTCSWeapon) then
        ply:SetTCSWeapon(tcsWeaponId)

        -- Persiste le flag permanent + le type d'arme dans le meta
        local charId = ST:GetCharacterUID(ply)
        if charId then
            local meta = table.Copy(ST._metaCache[charId] or {})
            meta.martial_weapon_granted = true
            meta.martial_weapon_type = tcsWeaponId
            ST._metaCache[charId] = meta
            -- Sauvegarde le meta immediatement (SaveCharacterState inclut _metaCache)
            local cachedState = ST._cache[charId]
            if cachedState then
                ST:SaveCharacterState(charId, cachedState)
            end
        end

        -- Re-donner tcs_base pour que le SWEP recharge les donnees d'arme
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end
            ply:StripWeapon("tcs_base")
            timer.Simple(0.1, function()
                if not IsValid(ply) then return end
                ply:Give("tcs_base")
                ply:SelectWeapon("tcs_base")
            end)
        end)
    end
end)

-- Slot assigne dans le loadout skill tree : equipe dans TCS
hook.Add("VERSE::SkillTree::SlotAssigned", "VERSE::TCSBridge::SlotAssigned", function(ply, presetIndex, slotIndex, abilityId, state, loadout)
    if not IsValid(ply) or not TOOM_JJK or not TOOM_JJK.SPELLS then return end
    -- N'agir que sur le preset actif (TCS n'a qu'un jeu de slots)
    local activePreset = istable(loadout) and (tonumber(loadout.active_preset) or 1) or 1
    if presetIndex ~= activePreset then return end
    local spellId = getTCSSpellId(abilityId)
    ply:EquipSpell(slotIndex, spellId)
end)

-- Slot vide dans le loadout skill tree : desequipe dans TCS
hook.Add("VERSE::SkillTree::SlotCleared", "VERSE::TCSBridge::SlotCleared", function(ply, presetIndex, slotIndex, state, loadout)
    if not IsValid(ply) or not TOOM_JJK or not TOOM_JJK.SPELLS then return end
    local activePreset = istable(loadout) and (tonumber(loadout.active_preset) or 1) or 1
    if presetIndex ~= activePreset then return end
    ply:UnequipSpell(slotIndex)
end)

-- Changement de preset : re-synchronise les 6 slots TCS depuis le nouveau preset
hook.Add("VERSE::SkillTree::PresetChanged", "VERSE::TCSBridge::PresetChanged", function(ply, presetIndex, state, loadout)
    if not IsValid(ply) or not TOOM_JJK or not TOOM_JJK.SPELLS then return end
    if not istable(loadout) then return end
    local preset = istable(loadout.presets) and loadout.presets[presetIndex]
    if not istable(preset) then return end
    local slots = preset.slots or {}
    for slotIdx = 1, ST:GetBindSlotCount() do
        local abilityId = tostring(slots[slotIdx] or "")
        local spellId = abilityId ~= "" and getTCSSpellId(abilityId) or nil
        ply:EquipSpell(slotIdx, spellId)
    end
end)

-- Reset du skill tree : retire tous les sorts TCS issus de l'arbre
hook.Add("VERSE::SkillTree::StateReset", "VERSE::TCSBridge::StateReset", function(ply, resetState)
    if not IsValid(ply) or not TOOM_JJK or not TOOM_JJK.SPELLS then return end
    -- Desequipe tous les slots
    for slotIdx = 1, ST:GetBindSlotCount() do
        ply:UnequipSpell(slotIdx)
    end
    -- Retire tous les sorts du skill tree
    for spellId in pairs(allTreeSpellIds()) do
        ply:RemoveSpell(spellId)
    end
end)
