local ST = VERSE.SkillTree
local DB = VERSE.DB
if not ST then return end
ST._cache        = ST._cache        or {}
ST._loadoutCache = ST._loadoutCache or {}
ST._metaCache    = ST._metaCache    or {}
ST._busy         = ST._busy         or {}

local function stAcquire(charId, key)
    local k = tostring(charId) .. "_" .. tostring(key)
    if ST._busy[k] then return false end
    ST._busy[k] = true
    return true
end

local function stRelease(charId, key)
    ST._busy[tostring(charId) .. "_" .. tostring(key)] = nil
end
local function esc(value)
    return DB:Escape(value)
end

local function nowSQL()
    return os.time()
end

local function cloneState(state)
    return table.Copy(ST:NormalizeState(state))
end

local function cloneLoadout(loadout, state)
    return table.Copy(ST:NormalizeLoadout(loadout, state))
end

local function encodeNodes(nodes)
    nodes = ST:NormalizeNodeRanks(nodes)
    if next(nodes) == nil then return "{}" end
    return util.TableToJSON(nodes, false) or "{}"
end

local function decodeNodes(raw)
    if not isstring(raw) or raw == "" then return {} end
    local decoded = util.JSONToTable(raw)
    return ST:NormalizeNodeRanks(decoded)
end

local function encodeLoadout(loadout, state)
    loadout = ST:NormalizeLoadout(loadout, state)
    return util.TableToJSON(loadout, false) or "{}"
end

local function decodeLoadout(raw, state)
    if not isstring(raw) or raw == "" then return ST:GetDefaultLoadout() end
    local decoded = util.JSONToTable(raw)
    return ST:NormalizeLoadout(decoded, state)
end

local function shouldIgnoreAlterError(err)
    err = string.lower(tostring(err or ""))
    return string.find(err, "duplicate column", 1, true) ~= nil
        or string.find(err, "already exists", 1, true) ~= nil
        or string.find(err, "duplicate name", 1, true) ~= nil
        or string.find(err, "no such column name", 1, true) ~= nil
end

local function normalizePresetIndex(loadout, presetIndex)
    local normalized = ST:NormalizeLoadout(loadout)
    return math.Clamp(math.floor(tonumber(presetIndex) or normalized.active_preset or 1), 1, ST:GetPresetCount())
end

local function normalizeSlotIndex(slotIndex)
    return math.Clamp(math.floor(tonumber(slotIndex) or 0), 1, ST:GetBindSlotCount())
end

local function getHookExecutionName(execution)
    execution = istable(execution) and execution or {}

    local hookName = tostring(execution.hook or execution.event or "")
    if hookName ~= "" then return hookName end

    local namespace = tostring(execution.namespace or "")
    local name = tostring(execution.name or "")
    if namespace ~= "" and name ~= "" then
        return namespace .. "::" .. name
    end

    return ""
end

local ERROR_MESSAGES = {
    no_character = "No character selected.",
    bad_node = "Unknown skill tree node.",
    max_rank = "This node is already maxed.",
    requirements = "Node requirements are not met.",
    not_enough_points = "Not enough skill points.",
    bad_ability = "Unknown technique.",
    ability_locked = "This technique is not unlocked.",
    ability_not_bindable = "This technique cannot be bound to a slot.",
    empty_slot = "No technique is bound to this slot.",
    active_weapon_required = "You need an active combat weapon to use this technique.",
    missing_execution = "This technique has no usable execution yet.",
    missing_executor = "The technique executor is unavailable.",
    bad_execution = "This technique is configured incorrectly.",
    not_enough_mana = "Energie Occulte insuffisante.",
    cooldown = "This technique is still recharging.",
    apply_failed = "The technique could not be activated.",
    unknown_profile = "Unknown combat profile.",
    db_error = "A database error occurred while saving the loadout.",
    branch_locked = "Cette branche est bloquee par votre choix de pouvoir maudit.",
    class_locked  = "Votre grade ne vous permet pas d'acceder a cette technique.",
    bad_subtype = "Branche inconnue.",
    bad_rank = "Rang inconnu.",
    no_rerolls = "Aucun ticket reroll Pouvoir Maudit disponible.",
    already_rolled = "Votre Pouvoir Maudit est deja assigne.",
}

local PLAYER = FindMetaTable("Player")

ST:RegisterExecutionHandler("combat_buff", {
    execute = function(_, ply, abilityId, execution)
        local effects = VERSE and (VERSE.Effects or VERSE.Buffs)
        local buffProfile = tostring(execution.buff_profile or "")
        if buffProfile == "" then return false, "bad_execution" end
        if not effects or not isfunction(effects.ActivateCombatBuff) then return false, "missing_executor" end
        return effects:ActivateCombatBuff(ply, buffProfile)
    end,
})

ST:RegisterExecutionHandler("tcs_spell", {
    execute = function(_, ply, abilityId, execution)
        local spellId = tostring(execution.spell_id or "")
        if spellId == "" then return false, "bad_execution" end
        if not TOOM_JJK or not TOOM_JJK.SPELLS then return false, "missing_executor" end
        -- Cherche le slot equipe pour ce sort et utilise TryCast
        local equipped = ply._tcsEquippedSpells or {}
        for slot, sid in pairs(equipped) do
            if sid == spellId then
                TOOM_JJK.SPELLS:TryCast(ply, slot)
                return true
            end
        end
        return false, "empty_slot"
    end,
})

ST:RegisterExecutionHandler("hook", {
    execute = function(_, ply, abilityId, execution, abilityData)
        local hookName = getHookExecutionName(execution)
        if hookName == "" then return false, "bad_execution" end
        if not VERSE or not VERSE.Hook or not isfunction(VERSE.Hook.Run) then return false, "missing_executor" end

        local ok, reason = VERSE.Hook.Run(hookName, ply, tostring(abilityId or ""), execution, abilityData, ST)
        if ok == nil then return false, "missing_executor" end
        if ok == false then return false, reason or "apply_failed" end
        return true, reason or "ok"
    end,
})

local function withPlayerState(ply, callback)
    if not IsValid(ply) then
        if callback then callback(false, "bad_player") end
        return
    end

    local charId = ST:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    ST:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            if callback then callback(false, stateOrError) end
            return
        end

        if callback then callback(true, charId, ST:NormalizeState(stateOrError)) end
    end)
end

function PLAYER:GetSkillTreePoints(callback)
    local charId = ST:GetCharacterUID(self)
    if not charId then
        if callback then callback(false, "no_character") end
        return 0
    end

    local cached = ST._cache[charId]
    if cached then
        local points = math.max(0, math.floor(tonumber(cached.available_points) or 0))
        if callback then callback(true, points, cloneState(cached), charId) end
        return points
    end

    if callback then
        withPlayerState(self, function(ok, loadedCharId, state)
            if not ok then
                callback(false, loadedCharId)
                return
            end

            callback(true, math.max(0, state.available_points or 0), state, loadedCharId)
        end)
    end
end

function ST:_WriteCharacterProfile(charId, state, loadout, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(false, "bad_character") end
        return
    end

    state = self:NormalizeState(state)
    loadout = self:NormalizeLoadout(loadout, state)
    self._cache[charId] = cloneState(state)
    self._loadoutCache[charId] = cloneLoadout(loadout, state)

    local createdAt = nowSQL()
    local updatedAt = createdAt
    local skillsJson = encodeNodes(state.nodes)
    local loadoutJson = encodeLoadout(loadout, state)
    local metaJson = util.TableToJSON(self._metaCache[charId] or {}, false) or "{}"
    local tableName = self:GetTableName()
    local query

    if DB:IsMySQL() then
        query = ([[
            INSERT INTO %s (char_id, available_points, spent_points, skills_json, loadout_json, active_preset, meta_json, created_at, updated_at)
            VALUES (%d, %d, %d, %s, %s, %d, %s, %d, %d)
            ON DUPLICATE KEY UPDATE
                available_points = VALUES(available_points),
                spent_points = VALUES(spent_points),
                skills_json = VALUES(skills_json),
                loadout_json = VALUES(loadout_json),
                active_preset = VALUES(active_preset),
                meta_json = VALUES(meta_json),
                updated_at = VALUES(updated_at)
        ]]):format(tableName, charId, state.available_points, state.spent_points, esc(skillsJson), esc(loadoutJson), loadout.active_preset, esc(metaJson), createdAt, updatedAt)
    else
        query = ([[
            INSERT OR REPLACE INTO %s (char_id, available_points, spent_points, skills_json, loadout_json, active_preset, meta_json, created_at, updated_at)
            VALUES (%d, %d, %d, %s, %s, %d, %s,
                COALESCE((SELECT created_at FROM %s WHERE char_id=%d), %d),
                %d)
        ]]):format(tableName, charId, state.available_points, state.spent_points, esc(skillsJson), esc(loadoutJson), loadout.active_preset, esc(metaJson), tableName, charId, createdAt, updatedAt)
    end

    DB:Query(query, function()
        if callback then callback(true, cloneState(state), cloneLoadout(loadout, state)) end
    end, function(err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[SkillTree] save profile failed: " .. tostring(err)) end
        if callback then callback(false, "db_error") end
        return true
    end)
end

function PLAYER:SetSkillTreePoints(amount, callback)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    withPlayerState(self, function(ok, charId, state)
        if not ok then
            if callback then callback(false, charId) end
            return
        end

        state.available_points = amount
        ST:SaveCharacterState(charId, state, function(saved, stateOrError)
            if not saved then
                if callback then callback(false, stateOrError or "db_error") end
                return
            end

            if self.RecalcStats then self:RecalcStats() end
            local _self = self
            timer.Simple(0, function()
                if not IsValid(_self) then return end
                if VERSE.Classes and VERSE.Classes.ReapplyStats then
                    VERSE.Classes.ReapplyStats(_self)
                end
            end)
            ST:SendSync(self, charId, state)
            if callback then callback(true, cloneState(state)) end
        end)
    end)
end

function PLAYER:AddSkillTreePoints(amount, callback)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 0 then return self:TakeSkillTreePoints(math.abs(amount), callback) end
    withPlayerState(self, function(ok, charId, state)
        if not ok then
            if callback then callback(false, charId) end
            return
        end

        state.available_points = math.max(0, (state.available_points or 0) + amount)
        ST:SaveCharacterState(charId, state, function(saved, stateOrError)
            if not saved then
                if callback then callback(false, stateOrError or "db_error") end
                return
            end

            if self.RecalcStats then self:RecalcStats() end
            -- Restaure les stats de classe après RecalcStats (qui peut remettre HP/mana
            -- au défaut si ply.Job est nil au moment du calcul dans la chaîne async).
            local _self = self
            timer.Simple(0, function()
                if not IsValid(_self) then return end
                if VERSE.Classes and VERSE.Classes.ReapplyStats then
                    VERSE.Classes.ReapplyStats(_self)
                end
            end)
            ST:SendSync(self, charId, state)
            if callback then callback(true, cloneState(state)) end
        end)
    end)
end

function PLAYER:TakeSkillTreePoints(amount, callback)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    withPlayerState(self, function(ok, charId, state)
        if not ok then
            if callback then callback(false, charId) end
            return
        end

        state.available_points = math.max(0, (state.available_points or 0) - amount)
        ST:SaveCharacterState(charId, state, function(saved, stateOrError)
            if not saved then
                if callback then callback(false, stateOrError or "db_error") end
                return
            end

            if self.RecalcStats then self:RecalcStats() end
            local _self = self
            timer.Simple(0, function()
                if not IsValid(_self) then return end
                if VERSE.Classes and VERSE.Classes.ReapplyStats then
                    VERSE.Classes.ReapplyStats(_self)
                end
            end)
            ST:SendSync(self, charId, state)
            if callback then callback(true, cloneState(state)) end
        end)
    end)
end

function PLAYER:GetPoints(callback)
    return self:GetSkillTreePoints(callback)
end

function PLAYER:SetPoints(amount, callback)
    return self:SetSkillTreePoints(amount, callback)
end

function PLAYER:AddPoints(amount, callback)
    return self:AddSkillTreePoints(amount, callback)
end

function PLAYER:TakePoints(amount, callback)
    return self:TakeSkillTreePoints(amount, callback)
end

function ST:CreateTables()
    local tableName = self:GetTableName()
    local query
    if DB:IsMySQL() then
        query = ([[
            CREATE TABLE IF NOT EXISTS %s (
                char_id INT NOT NULL,
                available_points INT NOT NULL,
                spent_points INT NOT NULL,
                skills_json TEXT NULL,
                loadout_json TEXT NULL,
                active_preset INT NOT NULL DEFAULT 1,
                created_at INT NOT NULL,
                updated_at INT NOT NULL,
                PRIMARY KEY (char_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(tableName)
    else
        query = ([[
            CREATE TABLE IF NOT EXISTS %s (
                char_id INTEGER PRIMARY KEY,
                available_points INTEGER NOT NULL,
                spent_points INTEGER NOT NULL,
                skills_json TEXT,
                loadout_json TEXT,
                active_preset INTEGER NOT NULL DEFAULT 1,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
        ]]):format(tableName)
    end

    DB:Query(query, function() end, function(err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[SkillTree] create table failed: " .. tostring(err)) end
        return true
    end)
end

function ST:EnsureSchema()
    local tableName = self:GetTableName()
    local queries = {
        ("ALTER TABLE %s ADD COLUMN loadout_json TEXT NULL"):format(tableName),
        ("ALTER TABLE %s ADD COLUMN active_preset INT NOT NULL DEFAULT 1"):format(tableName),
        ("ALTER TABLE %s ADD COLUMN meta_json TEXT NULL"):format(tableName),
    }

    for _, query in ipairs(queries) do
        DB:Query(query, function() end, function(err)
            if shouldIgnoreAlterError(err) then return true end
            if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[SkillTree] schema update failed: " .. tostring(err)) end
            return true
        end)
    end
end

function ST:LoadCharacterState(charId, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(false, "bad_character") end
        return
    end

    local cached = self._cache[charId]
    if cached then
        if callback then callback(true, cloneState(cached)) end
        return
    end

    local query = ("SELECT available_points, spent_points, skills_json, loadout_json, active_preset, meta_json FROM %s WHERE char_id=%d LIMIT 1"):format(self:GetTableName(), charId)
    DB:Query(query):Next(function(result)
        local rows = result.rows or {}
        local row = rows[1]
        local state
        local loadout
        if row then
            state = self:NormalizeState({
                available_points = row.available_points,
                spent_points = row.spent_points,
                nodes = decodeNodes(row.skills_json),
            })
            if not row.loadout_json or tostring(row.loadout_json) == "" then
                loadout = self:GetDefaultLoadout()
            else
                loadout = decodeLoadout(row.loadout_json, state)
                loadout.active_preset = math.Clamp(math.floor(tonumber(row.active_preset) or loadout.active_preset or 1), 1, self:GetPresetCount())
            end
            local metaRaw = tostring(row.meta_json or "")
            self._metaCache[charId] = (metaRaw ~= "" and util.JSONToTable(metaRaw)) or {}
            -- Migration ancien format meta.branch (string) -> meta.branches[group.id] (table)
            do
                local m = self._metaCache[charId]
                if istable(m) and m.branch and not istable(m.branches) then
                    local sid = tostring(m.branch)
                    local group = self:GetExclusiveGroupForSubtype(sid)
                    if group then
                        m.branches = { [group.id] = sid }
                    end
                    m.branch = nil
                end
            end
        else
            state = self:GetDefaultState()
            loadout = self:GetDefaultLoadout()
            -- Nouveau personnage : 1 reroll pouvoir maudit offert à la création
            self._metaCache[charId] = { cursed_rerolls = 1 }
            self:_WriteCharacterProfile(charId, state, loadout)
        end

        self._cache[charId] = cloneState(state)
        self._loadoutCache[charId] = cloneLoadout(loadout, state)
        if callback then callback(true, cloneState(state)) end
    end):Catch(function(err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[SkillTree] load state failed: " .. tostring(err)) end
        if callback then callback(false, "db_error") end
    end)
end

function ST:LoadCharacterLoadout(charId, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(false, "bad_character") end
        return
    end

    local cachedState = self._cache[charId]
    local cachedLoadout = self._loadoutCache[charId]
    if cachedState and cachedLoadout then
        if callback then callback(true, cloneLoadout(cachedLoadout, cachedState)) end
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            if callback then callback(false, stateOrError) end
            return
        end

        if callback then
            callback(true, cloneLoadout(self._loadoutCache[charId], stateOrError))
        end
    end)
end

function ST:SaveCharacterState(charId, state, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(false, "bad_character") end
        return
    end

    state = self:NormalizeState(state)
    local loadout = self._loadoutCache[charId] or self:GetDefaultLoadout()
    self:_WriteCharacterProfile(charId, state, loadout, function(ok, savedState)
        if callback then callback(ok, savedState or "db_error") end
    end)
end

function ST:SaveCharacterLoadout(charId, loadout, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(false, "bad_character") end
        return
    end

    local state = self._cache[charId]
    if not state then
        self:LoadCharacterState(charId, function(ok, stateOrError)
            if not ok then
                if callback then callback(false, stateOrError) end
                return
            end

            self:SaveCharacterLoadout(charId, loadout, callback)
        end)
        return
    end

    loadout = self:NormalizeLoadout(loadout, state)
    self:_WriteCharacterProfile(charId, state, loadout, function(ok, _, savedLoadout)
        if callback then callback(ok, savedLoadout or "db_error") end
    end)
end

function ST:DeleteCharacterState(charId)
    charId = tonumber(charId)
    if not charId or charId <= 0 then return end
    self._cache[charId] = nil
    self._loadoutCache[charId] = nil
    local query = ("DELETE FROM %s WHERE char_id=%d"):format(self:GetTableName(), charId)
    DB:Query(query, function() end, function(err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[SkillTree] delete state failed: " .. tostring(err)) end
        return true
    end)
end

function ST:SendError(ply, code)
    if not IsValid(ply) then return end
    if tostring(code or "") == "active_weapon_required" then
        netstream.Start(ply, self.Net.Error, tostring(code or "unknown"))
        return
    end
    local message = ERROR_MESSAGES[tostring(code or "unknown")]
    if message and isfunction(ply.Notify) then
        ply:Notify(message, NOTIFY_ERROR, 3.5)
    end
    netstream.Start(ply, self.Net.Error, tostring(code or "unknown"))
end

function ST:SendSync(ply, charId, state, loadout)
    if not IsValid(ply) then return end
    local cid = tonumber(charId) or 0
    local meta = istable(self._metaCache[cid]) and self._metaCache[cid] or {}
    local branches = istable(meta.branches) and meta.branches or {}
    local cursedRerolls = math.max(0, math.floor(tonumber(meta.cursed_rerolls) or 0))
    netstream.Start(ply, self.Net.Sync, cid, self:NormalizeState(state), self:NormalizeLoadout(loadout, state), branches, cursedRerolls)
end

function ST:SyncPlayer(ply)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        self:SendError(ply, "no_character")
        self:SendSync(ply, 0, self:GetDefaultState(), self:GetDefaultLoadout())
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            self:SendError(ply, stateOrError)
            return
        end

        self:SendSync(ply, charId, stateOrError, self._loadoutCache[charId])
        hook.Run("VERSE::SkillTree::PlayerSynced", ply, charId, stateOrError, self._loadoutCache[charId])
    end)
end

function ST:PurchaseNode(ply, nodeId)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        self:SendError(ply, "no_character")
        return
    end

    -- Busy lock : bloque les achats simultanés pour ce personnage
    if not stAcquire(charId, "purchase") then return end

    nodeId = tostring(nodeId or "")
    if nodeId == "" or not self:GetNode(nodeId) then
        stRelease(charId, "purchase")
        self:SendError(ply, "bad_node")
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            stRelease(charId, "purchase")
            self:SendError(ply, stateOrError)
            return
        end

        local state = self:NormalizeState(stateOrError)
        local node  = self:GetNode(nodeId)
        local meta  = self._metaCache[charId] or {}

        if node and node.subtype_id and self:IsSubtypeLockedByMeta(node.subtype_id, meta) then
            stRelease(charId, "purchase")
            self:SendError(ply, "branch_locked")
            return
        end

        if self:IsNodeLockedByClass(ply, nodeId) then
            stRelease(charId, "purchase")
            self:SendError(ply, "class_locked")
            return
        end

        local allowed, reason = self:CanUnlockNode(state, nodeId)
        if not allowed then
            stRelease(charId, "purchase")
            self:SendError(ply, reason)
            return
        end

        -- Enregistrement automatique du choix de branche au premier achat dans un groupe exclusif
        if node and node.subtype_id then
            local group = self:GetExclusiveGroupForSubtype(node.subtype_id)
            if group then
                local currentMeta = table.Copy(self._metaCache[charId] or {})
                currentMeta.branches = istable(currentMeta.branches) and table.Copy(currentMeta.branches) or {}
                if not currentMeta.branches[group.id] or currentMeta.branches[group.id] == "" then
                    currentMeta.branches[group.id] = node.subtype_id
                    self._metaCache[charId] = currentMeta
                end
            end
        end

        local currentRank = self:GetNodeRank(state, nodeId)
        state.available_points = math.max(0, state.available_points - node.cost)
        state.spent_points     = math.max(0, state.spent_points + node.cost)
        state.nodes[node.id]   = math.Clamp(currentRank + 1, 0, node.maxRank)

        self:SaveCharacterState(charId, state, function(saved)
            stRelease(charId, "purchase")
            if not saved then
                self:SendError(ply, "db_error")
                return
            end

            if ply.RecalcStats then ply:RecalcStats() end
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                if VERSE.Classes and VERSE.Classes.ReapplyStats then VERSE.Classes.ReapplyStats(ply) end
            end)
            self:SendSync(ply, charId, state, self._loadoutCache[charId])
            hook.Run("VERSE::SkillTree::NodePurchased", ply, nodeId, state)
        end)
    end)
end

function ST:ResetState(ply)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        self:SendError(ply, "no_character")
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            self:SendError(ply, stateOrError)
            return
        end

        local state = self:NormalizeState(stateOrError)
        local totalPoints = math.max(0, (state.available_points or 0) + (state.spent_points or 0))
        local resetState = {
            available_points = totalPoints,
            spent_points = 0,
            nodes = {},
        }

        self:SaveCharacterState(charId, resetState, function(saved)
            if not saved then
                self:SendError(ply, "db_error")
                return
            end

            if ply.RecalcStats then ply:RecalcStats() end
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                if VERSE.Classes and VERSE.Classes.ReapplyStats then
                    VERSE.Classes.ReapplyStats(ply)
                end
            end)
            self._loadoutCache[charId] = self:NormalizeLoadout(self._loadoutCache[charId], resetState)
            self:SaveCharacterLoadout(charId, self._loadoutCache[charId], function(savedLoadoutOk)
                if not savedLoadoutOk then
                    self:SendError(ply, "db_error")
                    return
                end

                self:SendSync(ply, charId, resetState, self._loadoutCache[charId])
                hook.Run("VERSE::SkillTree::StateReset", ply, resetState)
            end)
        end)
    end)
end

function ST:AssignAbilityToSlot(ply, presetIndex, slotIndex, abilityId)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        self:SendError(ply, "no_character")
        return
    end

    abilityId = tostring(abilityId or "")
    if abilityId == "" then
        self:SendError(ply, "bad_ability")
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            self:SendError(ply, stateOrError)
            return
        end

        local state = self:NormalizeState(stateOrError)
        if not self:GetUnlockedAbilitiesForState(state)[abilityId] then
            self:SendError(ply, "ability_locked")
            return
        end

        if not self:IsAbilityBindable(abilityId) then
            self:SendError(ply, "ability_not_bindable")
            return
        end

        local loadout = self:NormalizeLoadout(self._loadoutCache[charId], state)
        presetIndex = normalizePresetIndex(loadout, presetIndex)
        slotIndex = normalizeSlotIndex(slotIndex)
        local preset = loadout.presets[presetIndex]

        for idx = 1, self:GetBindSlotCount() do
            if preset.slots[idx] == abilityId then
                preset.slots[idx] = ""
            end
        end

        preset.slots[slotIndex] = abilityId
        self:SaveCharacterLoadout(charId, loadout, function(saved, savedLoadout)
            if not saved then
                self:SendError(ply, savedLoadout or "db_error")
                return
            end

            self:SendSync(ply, charId, state, savedLoadout)
            hook.Run("VERSE::SkillTree::SlotAssigned", ply, presetIndex, slotIndex, abilityId, state, savedLoadout)
        end)
    end)
end

function ST:ClearAbilitySlot(ply, presetIndex, slotIndex)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        self:SendError(ply, "no_character")
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            self:SendError(ply, stateOrError)
            return
        end

        local state = self:NormalizeState(stateOrError)
        local loadout = self:NormalizeLoadout(self._loadoutCache[charId], state)
        presetIndex = normalizePresetIndex(loadout, presetIndex)
        slotIndex = normalizeSlotIndex(slotIndex)
        loadout.presets[presetIndex].slots[slotIndex] = ""

        self:SaveCharacterLoadout(charId, loadout, function(saved, savedLoadout)
            if not saved then
                self:SendError(ply, savedLoadout or "db_error")
                return
            end

            self:SendSync(ply, charId, state, savedLoadout)
            hook.Run("VERSE::SkillTree::SlotCleared", ply, presetIndex, slotIndex, state, savedLoadout)
        end)
    end)
end

function ST:SetActivePreset(ply, presetIndex)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        self:SendError(ply, "no_character")
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            self:SendError(ply, stateOrError)
            return
        end

        local state = self:NormalizeState(stateOrError)
        local loadout = self:NormalizeLoadout(self._loadoutCache[charId], state)
        loadout.active_preset = normalizePresetIndex(loadout, presetIndex)

        self:SaveCharacterLoadout(charId, loadout, function(saved, savedLoadout)
            if not saved then
                self:SendError(ply, savedLoadout or "db_error")
                return
            end

            self:SendSync(ply, charId, state, savedLoadout)
            hook.Run("VERSE::SkillTree::PresetChanged", ply, presetIndex, state, savedLoadout)
        end)
    end)
end

local function tryWeaponAbility(ply, abilityId, execution, abilityData, context)
    if not IsValid(ply) or not isfunction(ply.GetActiveWeapon) then return false, false, "bad_player" end
    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) or not isfunction(weapon.TryUseSkillTreeAbility) then return false, false, "active_weapon_required" end
    local handled, ok, reason = weapon:TryUseSkillTreeAbility(abilityId, execution, abilityData, context)
    if not handled then return false, false, reason or "missing_executor" end
    return true, ok == true, reason or (ok and "ok" or "apply_failed")
end

function ST:UseAbility(ply, abilityId, context)
    if not IsValid(ply) or not ply:IsPlayer() then return false, "bad_player" end

    abilityId = tostring(abilityId or "")
    if abilityId == "" then return false, "bad_ability" end
    if not self:HasAbility(ply, abilityId) then return false, "ability_locked" end

    local abilityData = self:GetAbilityData(abilityId)
    if not self:IsAbilityBindable(abilityId, abilityData) then return false, "ability_not_bindable" end

    local execution = self:GetAbilityExecution(abilityId, abilityData)
    if not execution then return false, "missing_execution" end

    context = istable(context) and table.Copy(context) or {}
    context.ability_id = abilityId

    local handledByWeapon, weaponOk, weaponReason = tryWeaponAbility(ply, abilityId, execution, abilityData, context)
    if handledByWeapon then
        return weaponOk, weaponReason
    end

    -- Fallback : appelle directement le handler d'exécution enregistré.
    -- Cela permet aux techniques de type "combat_buff", "hook", etc. de fonctionner
    -- même sans arme TCS active (ex : armes TOOM_JJK qui n'ont pas TryUseSkillTreeAbility).
    local executionType = tostring(execution.type or "")
    local handler = executionType ~= "" and self:GetExecutionHandler(executionType) or nil
    if handler and isfunction(handler.execute) then
        local ok, reason = handler.execute(self, ply, abilityId, execution, abilityData, context)
        return ok == true, reason or (ok and "ok" or "apply_failed")
    end

    return false, weaponReason or "missing_executor"
end

function ST:UseBoundSlot(ply, slotIndex)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        self:SendError(ply, "no_character")
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            self:SendError(ply, stateOrError)
            return
        end

        local state = self:NormalizeState(stateOrError)
        local loadout = self:NormalizeLoadout(self._loadoutCache[charId], state)
        local abilityId = self:GetBoundAbilityId(loadout, slotIndex, loadout.active_preset)
        if abilityId == "" then
            self:SendError(ply, "empty_slot")
            return
        end

        local okUse, reason = self:UseAbility(ply, abilityId, {
            slot_index = slotIndex,
            preset_index = loadout.active_preset,
            triggered_by = "bind_slot",
        })
        if not okUse then
            self:SendError(ply, reason)
            return
        end

        self:SendSync(ply, charId, state, loadout)
    end)
end

-- ─── Tirage aléatoire pondéré ────────────────────────────────────────────────
-- Retourne un subtype id depuis la liste `available`, en respectant les poids
-- définis dans ST.RerollChancesConfig[groupId].
-- Retourne "__nothing__" si l'option "Rien" est tirée.
local function weightedRandom(available, chancesConfig, groupId)
    local cfg      = chancesConfig and chancesConfig[groupId]
    local weights  = cfg and istable(cfg.weights) and cfg.weights or {}
    local nothingW = cfg and math.max(0, tonumber(cfg.nothingWeight) or 0) or 0

    -- Construction du pool pondéré
    local pool   = {}
    local totalW = nothingW
    for _, sid in ipairs(available) do
        local w = math.max(0, tonumber(weights[sid]) or 1)
        totalW  = totalW + w
        pool[#pool + 1] = { id = sid, w = w }
    end

    if totalW <= 0 then
        -- Fallback uniforme si tous les poids sont nuls
        return available[math.random(1, #available)]
    end

    if nothingW > 0 then
        pool[#pool + 1] = { id = "__nothing__", w = nothingW }
    end

    -- Tirage
    local roll = math.random() * totalW
    local cumW = 0
    for _, entry in ipairs(pool) do
        cumW = cumW + entry.w
        if roll <= cumW then return entry.id end
    end

    return pool[#pool].id  -- ne devrait jamais arriver
end

-- Effectue le tirage aléatoire du Pouvoir Maudit pour le joueur.
-- Conditions : avoir au moins 1 ticket reroll ET aucune branche déjà assignée.
function ST:PerformCursedReroll(ply)
    if not IsValid(ply) then return end
    local charId = self:GetCharacterUID(ply)
    if not charId then self:SendError(ply, "no_character") return end

    -- Busy lock : bloque les rerolls simultanés
    if not stAcquire(charId, "reroll") then return end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            stRelease(charId, "reroll")
            self:SendError(ply, stateOrError)
            return
        end

        local meta    = table.Copy(self._metaCache[charId] or {})
        local rerolls = self:GetCursedRerolls(meta)
        if rerolls <= 0 then
            stRelease(charId, "reroll")
            self:SendError(ply, "no_rerolls")
            return
        end

        -- Trouver le premier groupe reroll défini
        local group = nil
        for _, g in ipairs(self.ExclusiveGroups or {}) do
            if self:IsRerollGroup(g.id) then group = g break end
        end
        if not group then stRelease(charId, "reroll") return end

        meta.branches = istable(meta.branches) and table.Copy(meta.branches) or {}
        if tostring(meta.branches[group.id] or "") ~= "" then
            stRelease(charId, "reroll")
            self:SendError(ply, "already_rolled")
            return
        end

        -- Tirage pondéré parmi les sous-types du groupe
        local available = group.subtypes or {}
        if #available == 0 then stRelease(charId, "reroll") return end
        local chosen    = weightedRandom(available, self.RerollChancesConfig, group.id)
        local isNothing = (chosen == "__nothing__")

        meta.cursed_rerolls = math.max(0, rerolls - 1)
        if not isNothing then
            meta.branches[group.id] = chosen
        end
        self._metaCache[charId] = meta

        local state = self:NormalizeState(stateOrError)
        self:SaveCharacterState(charId, state, function(saved)
            stRelease(charId, "reroll")
            if not saved then self:SendError(ply, "db_error") return end
            self:SendSync(ply, charId, state, self._loadoutCache[charId])
            -- Resync TCS (comme AdminSetBranch) pour que les sorts utilisables
            -- correspondent immédiatement à la branche tirée.
            hook.Run("VERSE::SkillTree::PlayerSynced", ply, charId, state, self._loadoutCache[charId])
            if VERSE.Log then
                VERSE.Log:Info("[SkillTree] Reroll PM : " .. ply:Nick() .. " → " .. (isNothing and "RIEN" or chosen))
            end
        end)
    end)
end

-- Variante boutique : effectue le reroll SANS verifier/consommer les tickets meta.
-- Utilisee quand l'item est consomme cote boutique (l'item EST le ticket).
-- Si une branche etait deja assignee, les noeuds de l'ancienne branche sont rembourses.
function ST:PerformCursedRerollForced(ply, callback)
    if not IsValid(ply) then
        if callback then callback(false, "bad_player") end
        return
    end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            if callback then callback(false, stateOrError) end
            return
        end

        -- Trouve le groupe reroll
        local group = nil
        for _, g in ipairs(self.ExclusiveGroups or {}) do
            if self:IsRerollGroup(g.id) then group = g break end
        end
        if not group then
            if callback then callback(false, "no_group") end
            return
        end

        local available = group.subtypes or {}
        if #available == 0 then
            if callback then callback(false, "no_subtypes") end
            return
        end

        local state = self:NormalizeState(stateOrError)
        local meta  = table.Copy(self._metaCache[charId] or {})
        meta.branches = istable(meta.branches) and table.Copy(meta.branches) or {}

        -- Si une branche etait deja assignee : rembourse les noeuds de cette branche
        local oldBranch = tostring(meta.branches[group.id] or "")
        if oldBranch ~= "" then
            local refund = 0
            for nodeId, rank in pairs(state.nodes) do
                local node = self:GetNode(nodeId)
                if node and tostring(node.subtype_id or "") == oldBranch then
                    local g2 = self:GetExclusiveGroupForSubtype(node.subtype_id)
                    if g2 and g2.id == group.id then
                        refund = refund + (node.cost or 1) * math.max(1, tonumber(rank) or 1)
                        state.nodes[nodeId] = nil
                    end
                end
            end
            if refund > 0 then
                state.available_points = (state.available_points or 0) + refund
                state.spent_points = math.max(0, (state.spent_points or 0) - refund)
            end
        end

        -- Tirage pondéré (retente une fois si on retombe sur la même branche)
        local chosen    = weightedRandom(available, self.RerollChancesConfig, group.id)
        local isNothing = (chosen == "__nothing__")
        if not isNothing and chosen == oldBranch and #available > 1 then
            chosen    = weightedRandom(available, self.RerollChancesConfig, group.id)
            isNothing = (chosen == "__nothing__")
        end

        if isNothing then
            meta.branches[group.id] = nil
        else
            meta.branches[group.id] = chosen
        end
        self._metaCache[charId] = meta

        self:SaveCharacterState(charId, state, function(saved)
            if not saved then
                if callback then callback(false, "db_error") end
                return
            end
            if ply.RecalcStats then ply:RecalcStats() end
            -- Restaure les stats de classe après RecalcStats (qui peut remettre HP=100/mana=1
            -- si ply.Job est nil au moment du calcul dans la chaîne async).
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                if VERSE.Classes and VERSE.Classes.ReapplyStats then
                    VERSE.Classes.ReapplyStats(ply)
                end
            end)
            self:SendSync(ply, charId, state, self._loadoutCache[charId])
            -- Déclenche la resync TCS (comme AdminSetBranch) : retire les sorts de
            -- l'ancienne branche, donne ceux de la nouvelle, met à jour les binds.
            -- Sans ça, le reroll change la branche dans l'arbre mais le joueur garde
            -- les sorts utilisables de l'ancien pouvoir.
            hook.Run("VERSE::SkillTree::PlayerSynced", ply, charId, state, self._loadoutCache[charId])
            if VERSE.Log then
                VERSE.Log:Info("[SkillTree] Reroll PM boutique : " .. ply:Nick() .. " -> " .. (isNothing and "RIEN" or chosen))
            end
            if callback then callback(true, isNothing and "__nothing__" or chosen) end
        end)
    end)
end

-- Donne des tickets reroll pouvoir maudit (admin/console).
function ST:AdminGiveCursedReroll(ply, amount, callback)
    if not IsValid(ply) then
        if callback then callback(false, "bad_player") end
        return
    end
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    local charId = self:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end
    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            if callback then callback(false, stateOrError) end
            return
        end
        local meta = table.Copy(self._metaCache[charId] or {})
        meta.cursed_rerolls = math.max(0, (tonumber(meta.cursed_rerolls) or 0) + amount)
        self._metaCache[charId] = meta
        local state = self:NormalizeState(stateOrError)
        self:SaveCharacterState(charId, state, function(saved)
            if not saved then
                if callback then callback(false, "db_error") end
                return
            end
            self:SendSync(ply, charId, state, self._loadoutCache[charId])
            if callback then callback(true, meta.cursed_rerolls) end
        end)
    end)
end

netstream.Hook(ST.Net.Request, function(ply) ST:SyncPlayer(ply) end)
netstream.Hook(ST.Net.Purchase, function(ply, nodeId) ST:PurchaseNode(ply, nodeId) end)
-- Le reset de l'arbre est exclusivement déclenché via l'article boutique
-- (use_mode = "reset_skilltree" dans sv_boutique.lua → AdminResetTree).
-- Ce hook est intentionnellement bloqué pour éviter les resets gratuits.
netstream.Hook(ST.Net.Reset, function(ply)
    if not IsValid(ply) then return end
    if ply:IsSuperAdmin() then
        -- Uniquement les superadmins peuvent reset depuis la console du jeu
        ST:AdminResetTree(ply, function(ok)
            if ok and IsValid(ply) and ply.Notify then
                ply:Notify("Arbre réinitialisé (admin).", NOTIFY_HINT, 4)
            end
        end)
        return
    end
    -- Joueur normal : refus silencieux (le reset se fait via l'article boutique)
    if IsValid(ply) and ply.Notify then
        ply:Notify("Utilisez l'article de reset depuis votre inventaire boutique.", NOTIFY_ERROR, 5)
    end
end)
netstream.Hook(ST.Net.AssignSlot, function(ply, presetIndex, slotIndex, abilityId) ST:AssignAbilityToSlot(ply, presetIndex, slotIndex, abilityId) end)
netstream.Hook(ST.Net.ClearSlot, function(ply, presetIndex, slotIndex) ST:ClearAbilitySlot(ply, presetIndex, slotIndex) end)
netstream.Hook(ST.Net.SetActivePreset, function(ply, presetIndex) ST:SetActivePreset(ply, presetIndex) end)
netstream.Hook(ST.Net.UseSlot, function(ply, slotIndex)
    if not IsValid(ply) then return end
    local charId = ST:GetCharacterUID(ply)
    if not charId then return end
    if not stAcquire(charId, "useslot") then return end
    ST:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            stRelease(charId, "useslot")
            ST:SendError(ply, stateOrError)
            return
        end
        local state = ST:NormalizeState(stateOrError)
        local loadout = ST:NormalizeLoadout(ST._loadoutCache[charId], state)
        local abilityId = ST:GetBoundAbilityId(loadout, slotIndex, loadout.active_preset)
        if abilityId == "" then
            stRelease(charId, "useslot")
            ST:SendError(ply, "empty_slot")
            return
        end
        local okUse, reason = ST:UseAbility(ply, abilityId, {
            slot_index = slotIndex,
            preset_index = loadout.active_preset,
            triggered_by = "bind_slot",
        })
        stRelease(charId, "useslot")
        if not okUse then
            ST:SendError(ply, reason)
            return
        end
        ST:SendSync(ply, charId, state, loadout)
    end)
end)
netstream.Hook(ST.Net.Reroll, function(ply) ST:PerformCursedReroll(ply) end)
VERSE.Hook.AddNS("SkillTree", "VERSE::Characters::Loaded", "VERSE::SkillTree::CharacterLoaded", function(ply) ST:SyncPlayer(ply) end)
VERSE.Hook.AddNS("SkillTree", "VERSE::Characters::Deleted", "VERSE::SkillTree::CharacterDeleted", function(charId) ST:DeleteCharacterState(charId) end)
VERSE.DB:OnReady(function()
    ST:CreateTables()
    ST:EnsureSchema()
end)

-- ─── Admin API ────────────────────────────────────────────────────────────────

function ST:AdminGivePoints(ply, amount, callback)
    if not IsValid(ply) then
        if callback then callback(false, "bad_player") end
        return
    end
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    ply:AddSkillTreePoints(amount, callback)
end

function ST:AdminSetBranch(ply, subtypeId, callback)
    if not IsValid(ply) then
        if callback then callback(false, "bad_player") end
        return
    end
    subtypeId = tostring(subtypeId or "")
    local group = self:GetExclusiveGroupForSubtype(subtypeId)
    if not group then
        if callback then callback(false, "bad_subtype") end
        return
    end

    local charId = self:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            if callback then callback(false, stateOrError) end
            return
        end

        local state = self:NormalizeState(stateOrError)

        -- Rembourse et supprime les noeuds des branches bloquees
        local refund = 0
        for nodeId, rank in pairs(state.nodes) do
            local node = self:GetNode(nodeId)
            if node and node.subtype_id and node.subtype_id ~= subtypeId then
                local g = self:GetExclusiveGroupForSubtype(node.subtype_id)
                if g and g.id == group.id then
                    refund = refund + (node.cost or 1) * math.max(1, rank)
                    state.nodes[nodeId] = nil
                end
            end
        end
        state.available_points = (state.available_points or 0) + refund
        state.spent_points = math.max(0, (state.spent_points or 0) - refund)

        local meta = table.Copy(self._metaCache[charId] or {})
        meta.branches = istable(meta.branches) and table.Copy(meta.branches) or {}
        meta.branches[group.id] = subtypeId
        self._metaCache[charId] = meta

        self:SaveCharacterState(charId, state, function(saved)
            if not saved then
                if callback then callback(false, "db_error") end
                return
            end
            if ply.RecalcStats then ply:RecalcStats() end
            -- Restaure les stats de classe après RecalcStats (qui peut remettre HP=100/mana=1
            -- si ply.Job est nil au moment du calcul dans la chaîne async).
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                if VERSE.Classes and VERSE.Classes.ReapplyStats then
                    VERSE.Classes.ReapplyStats(ply)
                end
            end)
            self:SendSync(ply, charId, state, self._loadoutCache[charId])
            -- Déclenche la resync TCS (retire les sorts de l'ancienne branche,
            -- donne ceux de la nouvelle, met à jour les binds de technique).
            hook.Run("VERSE::SkillTree::PlayerSynced", ply, charId, state, self._loadoutCache[charId])
            if callback then callback(true, subtypeId, refund) end
        end)
    end)
end

function ST:AdminSetRank(ply, rankId, callback)
    if not IsValid(ply) then
        if callback then callback(false, "bad_player") end
        return
    end
    local rankData = self:GetRankData(rankId)
    if not rankData then
        if callback then callback(false, "bad_rank") end
        return
    end

    local charId = self:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    local meta = table.Copy(self._metaCache[charId] or {})
    meta.rank = rankId
    self._metaCache[charId] = meta

    ply:AddSkillTreePoints(rankData.points, function(ok, stateOrError)
        if ok then
            -- _WriteCharacterProfile sera appele par AddSkillTreePoints -> SaveCharacterState
            -- meta_json sera inclus automatiquement via _metaCache
        end
        if callback then callback(ok, rankData) end
    end)
end

-- ─── AdminGiveAbility ────────────────────────────────────────────────────────
-- Donne directement une technique à un joueur en déverrouillant le nœud
-- correspondant (rang 1) dans son état, sans vérification de points/branche.
function ST:AdminGiveAbility(ply, abilityId, callback)
    if not IsValid(ply) then
        if callback then callback(false, "bad_player") end
        return
    end
    abilityId = tostring(abilityId or "")
    if abilityId == "" or not self:GetAbilityData(abilityId) then
        if callback then callback(false, "bad_ability") end
        return
    end

    local charId = self:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    -- Cherche le nœud qui octroie cette technique
    local targetNodeId = nil
    for nodeId, node in pairs(self:GetNodeMap() or {}) do
        if istable(node.abilities) then
            for _, aid in ipairs(node.abilities) do
                if tostring(aid) == abilityId then
                    targetNodeId = nodeId
                    break
                end
            end
        end
        if targetNodeId then break end
    end

    if not targetNodeId then
        if callback then callback(false, "node_not_found") end
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            if callback then callback(false, stateOrError) end
            return
        end

        local state = self:NormalizeState(stateOrError)
        state.nodes = state.nodes or {}
        local currentRank = tonumber(state.nodes[targetNodeId]) or 0

        if currentRank >= 1 then
            -- Technique déjà déverrouillée
            if callback then callback(true, "already_owned") end
            return
        end

        state.nodes[targetNodeId] = 1

        self:SaveCharacterState(charId, state, function(saved)
            if not saved then
                if callback then callback(false, "db_error") end
                return
            end
            if IsValid(ply) and ply.RecalcStats then ply:RecalcStats() end
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                if VERSE.Classes and VERSE.Classes.ReapplyStats then
                    VERSE.Classes.ReapplyStats(ply)
                end
            end)
            self:SendSync(ply, charId, state, self._loadoutCache and self._loadoutCache[charId] or nil)
            if callback then callback(true) end
        end)
    end)
end

function ST:AdminResetTree(ply, callback)
    if not IsValid(ply) then
        if callback then callback(false, "bad_player") end
        return
    end
    local charId = self:GetCharacterUID(ply)
    if not charId then
        if callback then callback(false, "no_character") end
        return
    end

    self:LoadCharacterState(charId, function(ok, stateOrError)
        if not ok then
            if callback then callback(false, stateOrError) end
            return
        end

        local state = self:NormalizeState(stateOrError)
        local totalPoints = math.max(0, (state.available_points or 0) + (state.spent_points or 0))
        local resetState = { available_points = totalPoints, spent_points = 0, nodes = {} }

        -- On CONSERVE le meta (branches choisies : heritage + technique maudite, et
        -- tickets de reroll). Un reset d'arbre rembourse les points et efface les
        -- noeuds, mais ne doit PAS retirer l'heritage ni le pouvoir maudit du joueur
        -- (l'effacer ici etait le bug : le joueur perdait son heritage au reset).
        self._metaCache[charId] = istable(self._metaCache[charId]) and self._metaCache[charId] or {}

        self:SaveCharacterState(charId, resetState, function(savedOk)
            if not savedOk then
                if callback then callback(false, "db_error") end
                return
            end

            self._loadoutCache[charId] = self:NormalizeLoadout(self._loadoutCache[charId], resetState)
            self:SaveCharacterLoadout(charId, self._loadoutCache[charId], function(savedLoadout)
                if not savedLoadout then
                    if callback then callback(false, "db_error") end
                    return
                end
                if ply.RecalcStats then ply:RecalcStats() end
                timer.Simple(0, function()
                    if not IsValid(ply) then return end
                    if VERSE.Classes and VERSE.Classes.ReapplyStats then
                        VERSE.Classes.ReapplyStats(ply)
                    end
                end)
                self:SendSync(ply, charId, resetState, self._loadoutCache[charId])
                hook.Run("VERSE::SkillTree::StateReset", ply, resetState)
                if callback then callback(true) end
            end)
        end)
    end)
end
