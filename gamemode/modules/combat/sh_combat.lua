VERSE.Combat = VERSE.Combat or {}
local C = VERSE.Combat
C._incoming = C._incoming or {}
C._outgoing = C._outgoing or {}
C._manaFailNotifyAt = C._manaFailNotifyAt or setmetatable({}, {__mode = "k"})
C.Config = C.Config or {
    HealthRegenBaseInterval = 3,
    HealthRegenMinInterval = 0.25,
    HealthRegenThinkInterval = 0.25,
    ManaBase = 0,
    ManaRegenBase = 4,
    ManaRegenBaseInterval = 1.25,
    ManaRegenMinInterval = 0.15,
    ManaRegenThinkInterval = 0.25,
    ManaValueKey = "VERSE::Combat::Mana",
    ManaMaxKey = "VERSE::Combat::ManaMax",
    AbilityManaCosts = {
        cursed_burst = 28,
        cursed_spirit_invoke = 34,
        black_flash = 18,
        limit_break = 40,
        shadow_dash = 22,
        domain_seed = 55,
    },
    BuffProfileAbilityMap = {
        limit_break = "limit_break",
        cursed_burst_window = "cursed_burst",
        shadow_dash_window = "shadow_dash",
    },
    BuffProfiles = {
        limit_break = {
            duration = 8,
            stats = {
                Damage = 15,
                MeleeDamage = 20,
                RunSpeed = 30,
                CooldownReduction = 0.15,
            },
        },
        cursed_burst_window = {
            duration = 4,
            stats = {
                Damage = 10,
                AbilityPower = 16,
            },
        },
        shadow_dash_window = {
            duration = 2.5,
            stats = {
                RunSpeed = 40,
                DamageReduction = 0.15,
            },
        },
    },
    DamageNumbersEnabled = true,
    DamageNumbersShowSelf = false,
    DamageNumbersNetMessage = "VERSE::Combat::DamageNumbers",
}

function C:GetConfigNumber(key, defaultValue)
    local value = tonumber(self.Config and self.Config[key])
    if value == nil then return tonumber(defaultValue) or 0 end
    return value
end

function C:SetConfigNumber(key, value)
    key = tostring(key or "")
    if key == "" then return false end
    value = tonumber(value)
    if value == nil then return false end
    self.Config[key] = value
    return true
end

function C:GetHealthRegenThinkInterval()
    return math.max(0.05, self:GetConfigNumber("HealthRegenThinkInterval", 0.25))
end

function C:GetHealthRegenInterval(ply)
    local base = math.max(0.01, self:GetConfigNumber("HealthRegenBaseInterval", 3))
    local minValue = math.max(0.01, self:GetConfigNumber("HealthRegenMinInterval", 0.25))
    local interval = base

    local override = VERSE.Hook.Run("VERSE::Combat::GetHealthRegenInterval", ply, base, self)
    if tonumber(override) then
        interval = tonumber(override)
    end

    return math.max(minValue, interval)
end

function C:GetManaKey()
    return tostring((self.Config and self.Config.ManaValueKey) or "VERSE::Combat::Mana")
end

function C:GetManaMaxKey()
    return tostring((self.Config and self.Config.ManaMaxKey) or "VERSE::Combat::ManaMax")
end

function C:GetPlayerManaMax(ply)
    local base = math.max(0, self:GetConfigNumber("ManaBase", 0))
    local bonus = 0
    if IsValid(ply) and ply:IsPlayer() and isfunction(ply.GetStat) then
        bonus = tonumber(ply:GetStat("Mana")) or 0
    end

    local maxMana = math.max(1, base + bonus)
    local override = VERSE.Hook.Run("VERSE::Combat::GetManaMax", ply, maxMana, self)
    if tonumber(override) then maxMana = tonumber(override) end
    return math.max(1, maxMana)
end

function C:GetManaRegenAmount(ply)
    -- Recharge à 15 % du max d'énergie occulte par seconde.
    -- On multiplie par l'intervalle pour que la quantité ajoutée par tick
    -- soit toujours équivalente à 15 %/s, quelle que soit la fréquence des ticks.
    local maxMana = 1
    if IsValid(ply) and ply:IsPlayer() and isfunction(ply.GetManaMax) then
        maxMana = math.max(1, ply:GetManaMax())
    end
    local interval = math.max(0.01, self:GetManaRegenInterval(ply))
    local regen = maxMana * 0.05 * interval
    local override = VERSE.Hook.Run("VERSE::Combat::GetManaRegen", ply, regen, self)
    if tonumber(override) then regen = tonumber(override) end
    return math.max(0, regen)
end

function C:GetManaRegenThinkInterval()
    return math.max(0.05, self:GetConfigNumber("ManaRegenThinkInterval", 0.25))
end

function C:GetManaRegenInterval(ply)
    local base = math.max(0.01, self:GetConfigNumber("ManaRegenBaseInterval", 1.25))
    local minValue = math.max(0.01, self:GetConfigNumber("ManaRegenMinInterval", 0.15))
    local interval = base
    local override = VERSE.Hook.Run("VERSE::Combat::GetManaRegenInterval", ply, base, self)
    if tonumber(override) then interval = tonumber(override) end
    return math.max(minValue, interval)
end

function C:GetAbilityManaCost(abilityId, ply, defaultValue)
    abilityId = tostring(abilityId or "")
    if abilityId == "" then return 0 end

    local cost
    local skillTree = VERSE and VERSE.SkillTree
    if skillTree and isfunction(skillTree.GetAbilityManaCost) then
        cost = tonumber(skillTree:GetAbilityManaCost(abilityId))
    end

    if cost == nil and istable(self.Config and self.Config.AbilityManaCosts) then
        cost = tonumber(self.Config.AbilityManaCosts[abilityId])
    end

    if cost == nil then cost = tonumber(defaultValue) or 0 end
    cost = math.max(0, cost)

    if IsValid(ply) and ply:IsPlayer() and isfunction(ply.GetStat) then
        local reduction = tonumber(ply:GetStat("ManaCostReduction")) or 0
        reduction = math.Clamp(reduction, 0, 0.85)
        cost = cost * (1 - reduction)
    end

    local override = VERSE.Hook.Run("VERSE::Combat::GetAbilityManaCost", ply, abilityId, cost, self)
    if tonumber(override) then cost = tonumber(override) end
    return math.max(0, math.floor(cost + 0.5))
end

function C:GetAbilityIdFromBuffProfile(buffProfile)
    buffProfile = tostring(buffProfile or "")
    if buffProfile == "" then return nil end
    local map = self.Config and self.Config.BuffProfileAbilityMap
    if not istable(map) then return nil end
    local abilityId = tostring(map[buffProfile] or "")
    if abilityId == "" then return nil end
    return abilityId
end

function C:GetBuffProfileData(buffProfile)
    buffProfile = tostring(buffProfile or "")
    if buffProfile == "" then return nil end
    local profiles = self.Config and self.Config.BuffProfiles
    if not istable(profiles) then return nil end
    local data = profiles[buffProfile]
    if not istable(data) then return nil end
    return data
end

function C:CanUseAbility(ply, abilityId, options)
    options = istable(options) and options or {}
    if not IsValid(ply) or not ply:IsPlayer() then return false, "bad_player", 0, 0 end

    abilityId = tostring(abilityId or "")
    if abilityId == "" then return false, "bad_ability", 0, 0 end

    if options.ignoreUnlock ~= true then
        local skillTree = VERSE and VERSE.SkillTree
        if skillTree and isfunction(skillTree.HasAbility) and not skillTree:HasAbility(ply, abilityId) then
            return false, "ability_locked", 0, tonumber(ply.GetMana and ply:GetMana() or 0) or 0
        end
    end

    local cost = options.manaCost
    if cost == nil then
        cost = self:GetAbilityManaCost(abilityId, ply, options.defaultCost)
    else
        cost = math.max(0, math.floor((tonumber(cost) or 0) + 0.5))
    end

    local mana = tonumber(ply.GetMana and ply:GetMana() or 0) or 0
    if mana < cost then return false, "not_enough_mana", cost, mana end
    return true, "ok", cost, mana
end

local function getAbilityDisplayName(abilityId)
    abilityId = tostring(abilityId or "")
    if abilityId == "" then return "Technique" end

    local skillTree = VERSE and VERSE.SkillTree
    local abilityData = nil
    if skillTree and isfunction(skillTree.GetAbilityData) then
        abilityData = skillTree:GetAbilityData(abilityId)
    elseif skillTree and istable(skillTree.Abilities) then
        abilityData = skillTree.Abilities[abilityId]
    end

    local title = istable(abilityData) and tostring(abilityData.title or "") or ""
    if title ~= "" then return title end
    return abilityId
end

local function buildManaFailMessage(abilityId, currentMana, requiredMana)
    local abilityName = getAbilityDisplayName(abilityId)
    local have = math.max(0, math.floor(tonumber(currentMana) or 0))
    local need = math.max(0, math.floor(tonumber(requiredMana) or 0))
    return string.format("%s: Energie Occulte insuffisante %d/%d", abilityName, have, need)
end

function C:TryConsumeAbilityMana(ply, abilityId, options)
    if CLIENT then return false, "server_only", 0, 0 end
    options = istable(options) and options or {}
    local canUse, reason, cost, mana = self:CanUseAbility(ply, abilityId, options)
    if not canUse then
        if reason == "not_enough_mana" and options.notifyOnFail ~= false and IsValid(ply) and ply:IsPlayer() and isfunction(ply.Notify) then
            local now = CurTime()
            local nextAt = tonumber(self._manaFailNotifyAt[ply]) or 0
            if now >= nextAt then
                local msg = buildManaFailMessage(abilityId, mana, cost)
                ply:Notify(msg, NOTIFY_ERROR, 3.5)
                self._manaFailNotifyAt[ply] = now + 0.9
            end
        end
        return false, reason, cost, mana
    end

    if cost > 0 and isfunction(ply.TakeMana) then
        local taken = tonumber(ply:TakeMana(cost)) or 0
        if taken < cost then
            local leftMana = tonumber(ply.GetMana and ply:GetMana() or 0) or 0
            if options.notifyOnFail ~= false and isfunction(ply.Notify) then
                local msg = buildManaFailMessage(abilityId, leftMana, cost)
                ply:Notify(msg, NOTIFY_ERROR, 3.5)
            end
            return false, "not_enough_mana", cost, leftMana
        end
    end

    VERSE.Hook.Run("VERSE::Combat::AbilityManaSpent", ply, tostring(abilityId or ""), cost)
    return true, "ok", cost, tonumber(ply.GetMana and ply:GetMana() or 0) or 0
end

function C:RegisterIncomingModifier(id, priority, fn)
    id = tostring(id or "")
    if id == "" or not isfunction(fn) then return end
    priority = tonumber(priority) or 100
    self:UnregisterModifier(id)
    self._incoming[#self._incoming + 1] = {
        id = id,
        priority = priority,
        fn = fn
    }

    table.sort(self._incoming, function(a, b) return a.priority < b.priority end)
end

function C:RegisterOutgoingModifier(id, priority, fn)
    id = tostring(id or "")
    if id == "" or not isfunction(fn) then return end
    priority = tonumber(priority) or 100
    self:UnregisterModifier(id)
    self._outgoing[#self._outgoing + 1] = {
        id = id,
        priority = priority,
        fn = fn
    }

    table.sort(self._outgoing, function(a, b) return a.priority < b.priority end)
end

function C:UnregisterModifier(id)
    id = tostring(id or "")
    for _, tbl in ipairs({self._incoming, self._outgoing}) do
        for i = #tbl, 1, -1 do
            if tbl[i].id == id then table.remove(tbl, i) end
        end
    end
end

function C:GetIncomingModifiers()
    return self._incoming
end

function C:GetOutgoingModifiers()
    return self._outgoing
end