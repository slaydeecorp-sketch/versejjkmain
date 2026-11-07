VERSE.Stats = VERSE.Stats or {}
local S = VERSE.Stats

S.Keys = S.Keys or {}
S.Defaults = S.Defaults or {}
S.Definitions = S.Definitions or {}
S.Aliases = S.Aliases or {}
S.ProviderOrder = S.ProviderOrder or {}
S.Providers = S.Providers or {}
S.LegacySources = S.LegacySources or {
    "Buff",
    "TempBuff",
}

local function sortProviders()
    table.sort(S.ProviderOrder, function(a, b)
        local pa = tonumber(a.priority) or 0
        local pb = tonumber(b.priority) or 0
        if pa ~= pb then return pa > pb end
        local oa = tonumber(a.order) or 0
        local ob = tonumber(b.order) or 0
        if oa ~= ob then return oa < ob end
        return tostring(a.id) < tostring(b.id)
    end)
end

local function canonicalAlias(alias)
    alias = tostring(alias or "")
    if alias == "" then return nil end
    return string.lower(alias)
end

function S.RegisterAlias(alias, key)
    local normalizedKey = S.ResolveKey and S:ResolveKey(key) or key
    if not isstring(normalizedKey) or normalizedKey == "" then return nil end

    alias = canonicalAlias(alias)
    if not alias then return nil end

    S.Aliases[alias] = normalizedKey
    return normalizedKey
end

function S:Register(key, i18nKey, default, opts)
    assert(isstring(key) and key ~= "", "Stats.Register: key must be a non-empty string")

    opts = istable(opts) and opts or {}
    local definition = {
        key = key,
        i18nKey = i18nKey or key,
        default = tonumber(default) or 0,
        min = opts.min ~= nil and tonumber(opts.min) or nil,
        max = opts.max ~= nil and tonumber(opts.max) or nil,
        round = opts.round ~= false,
    }

    S.Keys[key] = definition.i18nKey
    S.Defaults[key] = definition.default
    S.Definitions[key] = definition
    S:RegisterAlias(key, key)

    local lowerKey = string.lower(key)
    if lowerKey ~= key then
        S:RegisterAlias(lowerKey, key)
    end

    local noPascal = string.gsub(lowerKey, "([a-z])([A-Z])", "%1_%2")
    noPascal = string.lower(noPascal)
    if noPascal ~= lowerKey then
        S:RegisterAlias(noPascal, key)
        S:RegisterAlias(string.gsub(noPascal, "_", ""), key)
    end

    if istable(opts.aliases) then
        for index = 1, #opts.aliases do
            S:RegisterAlias(opts.aliases[index], key)
        end
    end

    return definition
end

function S:ResolveKey(key)
    if not isstring(key) or key == "" then return nil end
    if self.Definitions[key] then return key end
    return self.Aliases[canonicalAlias(key)]
end

function S:GetDefinition(key)
    key = self:ResolveKey(key)
    if not key then return nil end
    return self.Definitions[key]
end

function S.GetStatName(key)
    local definition = S:GetDefinition(key)
    if not definition then return tostring(key or "") end

    local i18nKey = definition.i18nKey
    local name = VERSE.L and VERSE.L(i18nKey)
    return (isstring(name) and name ~= i18nKey) and name or i18nKey
end

function S.MakeSet(value)
    return { set = tonumber(value) or 0 }
end

function S.MakeAdd(value)
    return { add = tonumber(value) or 0 }
end

function S.MakeMul(value)
    return { mul = tonumber(value) or 1 }
end

function S:NormalizeContribution(key, raw)
    local definition = self:GetDefinition(key)
    if not definition or raw == nil then return nil end

    if isnumber(raw) then
        return { add = tonumber(raw) or 0 }
    end

    if not istable(raw) then return nil end

    local contribution = {}
    if raw.set ~= nil then contribution.set = tonumber(raw.set) or definition.default end
    if raw.add ~= nil then contribution.add = tonumber(raw.add) or 0 end
    if raw.mul ~= nil then contribution.mul = tonumber(raw.mul) or 1 end
    if raw.post_add ~= nil then contribution.post_add = tonumber(raw.post_add) or 0 end
    if raw.min ~= nil then contribution.min = tonumber(raw.min) end
    if raw.max ~= nil then contribution.max = tonumber(raw.max) end
    if raw.value ~= nil and contribution.add == nil and contribution.set == nil then
        contribution.add = tonumber(raw.value) or 0
    end

    if next(contribution) == nil then return nil end
    return contribution
end

function S:RegisterProvider(id, fn, opts)
    assert(isstring(id) and id ~= "", "Stats.RegisterProvider: id must be non-empty")
    assert(isfunction(fn), "Stats.RegisterProvider: fn must be a function")

    opts = istable(opts) and opts or {}
    local provider = {
        id = id,
        fn = fn,
        priority = tonumber(opts.priority) or 0,
        order = tonumber(opts.order) or (#self.ProviderOrder + 1),
    }

    self.Providers[id] = provider

    local replaced = false
    for index = 1, #self.ProviderOrder do
        if self.ProviderOrder[index].id == id then
            self.ProviderOrder[index] = provider
            replaced = true
            break
        end
    end

    if not replaced then
        self.ProviderOrder[#self.ProviderOrder + 1] = provider
    end

    sortProviders()
    return provider
end

function S:UnregisterProvider(id)
    if not self.Providers[id] then return false end
    self.Providers[id] = nil
    for index = #self.ProviderOrder, 1, -1 do
        if self.ProviderOrder[index].id == id then
            table.remove(self.ProviderOrder, index)
        end
    end
    return true
end

local function applyContributionToState(state, breakdown, providerId, key, contribution)
    local slot = state[key]
    if contribution.set ~= nil then slot.value = contribution.set end
    if contribution.add ~= nil then slot.value = slot.value + contribution.add end
    if contribution.mul ~= nil then slot.mul = slot.mul * contribution.mul end
    if contribution.post_add ~= nil then slot.post_add = slot.post_add + contribution.post_add end
    if contribution.min ~= nil then slot.min = slot.min and math.max(slot.min, contribution.min) or contribution.min end
    if contribution.max ~= nil then slot.max = slot.max and math.min(slot.max, contribution.max) or contribution.max end

    if istable(breakdown) then
        breakdown[key][#breakdown[key] + 1] = {
            source = providerId,
            contribution = table.Copy(contribution),
        }
    end
end

local function applyProviderContributions(statsModule, state, breakdown, providerId, contributionMap)
    for rawKey, rawContribution in pairs(contributionMap) do
        local key = statsModule:ResolveKey(rawKey)
        if key then
            local contribution = statsModule:NormalizeContribution(key, rawContribution)
            if contribution then
                applyContributionToState(state, breakdown, providerId, key, contribution)
            end
        end
    end
end

function S:ResolveAll(ply, opts)
    opts = istable(opts) and opts or {}
    local includeBreakdown = opts.includeBreakdown == true
    local resolved = {}
    local state = {}
    local breakdown = includeBreakdown and {} or nil

    for key, definition in pairs(self.Definitions) do
        state[key] = {
            value = definition.default,
            mul = 1,
            post_add = 0,
            min = definition.min,
            max = definition.max,
        }
        if includeBreakdown then breakdown[key] = {} end
    end

    for index = 1, #self.ProviderOrder do
        local provider = self.ProviderOrder[index]
        if provider and isfunction(provider.fn) then
            local ok, contributionMap = pcall(provider.fn, ply, opts.context)
            if ok and istable(contributionMap) then
                applyProviderContributions(self, state, breakdown, provider.id, contributionMap)
            elseif not ok and VERSE.Log and VERSE.Log.Error then
                VERSE.Log:Error("[Stats] provider failed: " .. tostring(provider.id) .. " -> " .. tostring(contributionMap))
            end
        end
    end

    for key, slot in pairs(state) do
        local definition = self.Definitions[key]
        local value = (slot.value * slot.mul) + slot.post_add
        if slot.min ~= nil then value = math.max(slot.min, value) end
        if slot.max ~= nil then value = math.min(slot.max, value) end
        if definition.round ~= false then
            value = math.floor(value + 0.5)
        end
        resolved[key] = value
    end

    return resolved, breakdown
end

function S:Resolve(ply, key, opts)
    local resolvedKey = self:ResolveKey(key)
    if not resolvedKey then return tonumber(opts and opts.fallback) or 0 end

    if SERVER and IsValid(ply) and istable(ply._statTotals) and ply._statTotals[resolvedKey] ~= nil then
        return ply._statTotals[resolvedKey]
    end

    local resolved = self:ResolveAll(ply, opts)
    return resolved[resolvedKey] ~= nil and resolved[resolvedKey] or (self.Defaults[resolvedKey] or 0)
end

function S:Get(ply, key, fallback)
    local resolvedKey = self:ResolveKey(key)
    if not resolvedKey then return tonumber(fallback) or 0 end

    if SERVER and IsValid(ply) and istable(ply._statTotals) and ply._statTotals[resolvedKey] ~= nil then
        return ply._statTotals[resolvedKey]
    end

    if IsValid(ply) and ply.GetPublicInt then
        return ply:GetPublicInt("VERSE::Stats::" .. resolvedKey, self.Defaults[resolvedKey] or tonumber(fallback) or 0)
    end

    return self.Defaults[resolvedKey] or tonumber(fallback) or 0
end

S:Register("Health", "stats.Health", 100, { min = 1, aliases = { "health" } })
S:Register("Armor", "stats.Armor", 0, { min = 0, aliases = { "armor" } })
S:Register("WalkSpeed", "stats.WalkSpeed", 200, { min = 10, aliases = { "walkspeed", "walk_speed" } })
S:Register("RunSpeed", "stats.RunSpeed", 400, { min = 10, aliases = { "runspeed", "run_speed" } })
S:Register("JumpPower", "stats.JumpPower", 200, { aliases = { "jumppower", "jump_power" } })
S:Register("Damage", "stats.Damage", 0, { aliases = { "damage" } })
S:Register("MeleeDamage", "stats.MeleeDamage", 0, { aliases = { "meleedamage", "melee_damage" } })
S:Register("AbilityPower", "stats.AbilityPower", 0, { aliases = { "abilitypower", "ability_power", "cursedpower", "cursed_power" } })
S:Register("Mana", "stats.Mana", 0, { min = 0, aliases = { "mana", "maxmana", "max_mana" } })
S:Register("ManaRegen", "stats.ManaRegen", 0, { min = 0, aliases = { "manaregen", "mana_regen" } })
S:Register("ManaCostReduction", "stats.ManaCostReduction", 0, { min = 0, max = 0.95, round = false, aliases = { "manacostreduction", "mana_cost_reduction", "abilitycostreduction", "ability_cost_reduction" } })
S:Register("CooldownReduction", "stats.CooldownReduction", 0, { aliases = { "cooldownreduction", "cooldown_reduction" } })
S:Register("HealthRegen", "stats.HealthRegen", 0, { aliases = { "healthregen", "health_regen" } })
S:Register("DamageReduction", "stats.DamageReduction", 0, { aliases = { "damagereduction", "damage_reduction" } })
S:Register("AttackSpeed", "stats.AttackSpeed", 0, { min = 0, round = false, aliases = { "attackspeed", "attack_speed" } })

local PLAYER = FindMetaTable("Player")

function PLAYER:GetStat(key, fallback)
    return S:Get(self, key, fallback)
end

function PLAYER:GetStatValue(key, fallback)
    return S:Get(self, key, fallback)
end