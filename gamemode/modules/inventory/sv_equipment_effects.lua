local INV = VERSE.Inventory
local S = VERSE.Stats
local EQ = {}
INV.Equipment = EQ
local STAT_SOURCE_PREFIX = "equip_slot_"
local EQUIP_SLOTS = { 101, 102, 103, 104 }
local function getStatSource(equipSlot)
    return STAT_SOURCE_PREFIX .. tostring(equipSlot)
end

S:RegisterProvider("equipment", function(ply)
    local runtime = ply._statRuntime
    if not runtime or not runtime.sources then return nil end
    local out = {}
    for _, slotId in ipairs(EQUIP_SLOTS) do
        local src = runtime.sources[getStatSource(slotId)]
        if istable(src) then
            for key, value in pairs(src) do
                value = tonumber(value)
                if value and value ~= 0 then
                    out[key] = out[key] or {
                        add = 0
                    }

                    out[key].add = out[key].add + value
                end
            end
        end
    end
    return next(out) and out or nil
end, {
    priority = 700
})

local function findPlayerByCharId(charId)
    charId = tonumber(charId)
    if not charId then return nil end
    for _, ply in ipairs(player.GetAll()) do
        if INV:GetCharacterUID(ply) == charId then return ply end
    end
    return nil
end

function EQ:ApplySlotEffect(ply, equipSlot, itemData)
    if not IsValid(ply) or not itemData then return end
    local def = INV:GetItemDef(itemData.item_id)
    if not def then return end

    local source = getStatSource(equipSlot)

    if istable(def.equip_stats) and next(def.equip_stats) then
        ply:SetStatBuffBulk(source, def.equip_stats)
    end

    if def.equip_swep and isstring(def.equip_swep) and def.equip_swep ~= "" and (not ply:HasWeapon(def.equip_swep)) then
        ply:Give(def.equip_swep)
        ply._equipSWEPs = ply._equipSWEPs or {}
        ply._equipSWEPs[def.equip_swep] = true
    end

    if def.equip_model and isstring(def.equip_model) and def.equip_model ~= "" then
        -- Sauvegarde le modèle original (avant la tenue)
        if not ply._originalModel then
            ply._originalModel = ply:GetModel()
        end
        -- Stocke dans Job.custom.model → PlayerSetModel et ApplyPlayerAppearance l'utiliseront en priorité
        if ply.Job then
            ply.Job.custom = ply.Job.custom or {}
            ply.Job.custom.model = def.equip_model
            ply.Job.resolvedModel = def.equip_model
        end
        ply:SetModel(def.equip_model)
    end

    if isfunction(def.on_equip) then
        def.on_equip(ply, itemData, equipSlot)
    end
end

function EQ:RemoveSlotEffect(ply, equipSlot, itemData)
    if not IsValid(ply) then return end

    local source = getStatSource(equipSlot)
    ply:ClearStatBuff(source)

    if itemData then
        local def = INV:GetItemDef(itemData.item_id)
        if def then
            if def.equip_swep and isstring(def.equip_swep) and def.equip_swep ~= "" and ply:HasWeapon(def.equip_swep) then
                ply:StripWeapon(def.equip_swep)
                if ply._equipSWEPs then ply._equipSWEPs[def.equip_swep] = nil end
            end

            if def.equip_model and isstring(def.equip_model) and def.equip_model ~= "" then
                -- Retire le modèle de la tenue de Job.custom.model
                if ply.Job and ply.Job.custom then
                    ply.Job.custom.model = nil
                end
                -- Restaure le modèle original du personnage
                local restoreMdl = ply._originalModel
                ply._originalModel = nil
                if restoreMdl and restoreMdl ~= "" then
                    if ply.Job then ply.Job.resolvedModel = restoreMdl end
                    ply:SetModel(restoreMdl)
                end
            end

            if isfunction(def.on_unequip) then
                def.on_unequip(ply, itemData, equipSlot)
            end
        end
    end
end

function EQ:ApplyAll(ply, fullReset)
    if not IsValid(ply) then return end
    local charId = INV:GetCharacterUID(ply)
    if not charId then return end
    local inv = INV._cache[charId]
    if not inv then return end

    -- Sauvegarde le modèle de base (avant tenue) une seule fois
    -- pour que RemoveSlotEffect puisse le restaurer correctement
    if not ply._originalModel then
        ply._originalModel = ply:GetModel()
    end

    local applied = false
    for slotId, _ in pairs(INV.EquipSlotNames) do
        local data = inv[slotId]
        if data then
            EQ:ApplySlotEffect(ply, slotId, data)
            applied = true
        end
    end

    if fullReset and applied then
        ply:RecalcStats(true)
        VERSE.Classes.ReapplyStats(ply)

        local C = VERSE.Combat
        if C and C.InitializeMana then
            C:InitializeMana(ply, true)
        end
    end
end

function EQ:RemoveAll(ply)
    if not IsValid(ply) then return end

    for slotId, _ in pairs(INV.EquipSlotNames) do
        ply:ClearStatBuff(getStatSource(slotId))
    end

    if ply._originalModel then
        ply:SetModel(ply._originalModel)
        ply._originalModel = nil
    end

    local charId = INV:GetCharacterUID(ply)
    if not charId then return end
    local inv = INV._cache[charId]
    if not inv then return end
    for slotId, _ in pairs(INV.EquipSlotNames) do
        local data = inv[slotId]
        if data then
            local def = INV:GetItemDef(data.item_id)
            if def and def.equip_swep and isstring(def.equip_swep) and ply:HasWeapon(def.equip_swep) then ply:StripWeapon(def.equip_swep) end
        end
    end
end

local function wrapEquipFunctions()
    if not INV.EquipItem or not INV.UnequipItem then return end

    if not INV._origEquipItem then
        INV._origEquipItem = INV.EquipItem
    end
    if not INV._origUnequipItem then
        INV._origUnequipItem = INV.UnequipItem
    end

    local origEquip = INV._origEquipItem
    local origUnequip = INV._origUnequipItem

    function INV:EquipItem(charId, fromSlot, equipSlot, callback)
        local ply = findPlayerByCharId(charId)
        if ply then
            local inv = self._cache[charId]
            local oldData = inv and inv[tonumber(equipSlot)]
            if oldData then EQ:RemoveSlotEffect(ply, equipSlot, oldData) end
        end

        origEquip(self, charId, fromSlot, equipSlot, function(ok, err)
            if ok and ply and IsValid(ply) then
                local inv = self._cache[charId]
                local newData = inv and inv[tonumber(equipSlot)]
                if newData then EQ:ApplySlotEffect(ply, equipSlot, newData) end
                ply:RecalcStats(false)
                VERSE.Classes.ReapplyStats(ply)
            end

            if callback then callback(ok, err) end
        end)
    end

    function INV:UnequipItem(charId, equipSlot, callback)
        local ply = findPlayerByCharId(charId)
        local inv = self._cache[charId]
        local oldData = inv and inv[tonumber(equipSlot)]
        origUnequip(self, charId, equipSlot, function(ok, err)
            if ok and ply and IsValid(ply) and oldData then
                EQ:RemoveSlotEffect(ply, equipSlot, oldData)
                ply:RecalcStats(false)
                VERSE.Classes.ReapplyStats(ply)
            end
            if callback then callback(ok, err) end
        end)
    end
end

wrapEquipFunctions()
VERSE.Hook.AddNS("Inventory", "InitPostEntity", "VERSE::Inventory::WrapEquip", wrapEquipFunctions)
timer.Simple(0, wrapEquipFunctions)

VERSE.Hook.AddNS("Inventory", "PlayerSpawn", "VERSE::Inventory::EquipOnSpawn", function(ply)
    timer.Simple(0.5, function()
        if IsValid(ply) then EQ:ApplyAll(ply, true) end
    end)
end)

VERSE.Hook.AddNS("Inventory", "VERSE::Characters::Loaded", "VERSE::Inventory::EquipOnCharLoad", function(ply)
    if not IsValid(ply) then return end

    -- Nettoie l'état d'équipement de l'ancien personnage sans toucher au modèle
    -- (ApplyPlayerAppearance a déjà défini le bon modèle du nouveau personnage)
    if ply.Job and ply.Job.custom then
        ply.Job.custom.model = nil
    end
    if ply.Job then ply.Job.resolvedModel = nil end
    -- _originalModel remis à nil : ApplyAll le re-capturera depuis le modèle actuel (nouveau perso)
    ply._originalModel = nil

    -- Efface les stat buffs des anciens slots d'équipement
    for _, slotId in ipairs(EQUIP_SLOTS) do
        ply:ClearStatBuff(getStatSource(slotId))
    end

    -- Retire les SWEPs donnés par l'équipement de l'ancien personnage
    if istable(ply._equipSWEPs) then
        for swep, _ in pairs(ply._equipSWEPs) do
            if ply:HasWeapon(swep) then ply:StripWeapon(swep) end
        end
    end
    ply._equipSWEPs = {}

    timer.Simple(1, function()
        if IsValid(ply) then EQ:ApplyAll(ply, true) end
    end)
end)

VERSE.Hook.AddNS("Inventory", "VERSE::Inventory::Loaded", "VERSE::Inventory::EquipOnLoad", function(ply, charId)
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        EQ:ApplyAll(ply, true)
        -- Re-envoyer la liste de personnages au client maintenant que le cache inventaire
        -- est disponible : corrige l'affichage de la tenue sur la carte au premier chargement
        local CH = VERSE.Characters
        if CH and CH.SendList then
            CH:SendList(ply)
        end
    end)
end)

VERSE.Hook.AddNS("Inventory", "PlayerDisconnected", "VERSE::Inventory::EquipCleanup", function(ply)
    EQ:RemoveAll(ply)
end)