local S = VERSE.Stats
local PLAYER = FindMetaTable("Player")

local function ensureRuntime(ply)
    if not istable(ply._statRuntime) then
        ply._statRuntime = {
            sources = {
                _base = {},
            },
        }
    end

    local sources = ply._statRuntime.sources
    sources._base = sources._base or {}
    for index = 1, #(S.LegacySources or {}) do
        local sourceId = S.LegacySources[index]
        sources[sourceId] = sources[sourceId] or {}
    end

    return ply._statRuntime
end

local function normalizeSourceMap(map, mode)
    if not istable(map) then return {} end

    local out = {}
    for rawKey, value in pairs(map) do
        local key = S:ResolveKey(rawKey)
        if key then
            value = tonumber(value)
            if value ~= nil then
                if mode == "set" then
                    out[key] = { set = value }
                else
                    out[key] = { add = value }
                end
            end
        end
    end

    return out
end

local function applyTotals(ply, totals, prevTotals, fullReset)
    local hp = math.max(1, math.floor(totals.Health or S.Defaults.Health or 100))
    local armor = math.max(0, math.floor(totals.Armor or S.Defaults.Armor or 0))
    local walkSpeed = math.max(10, math.floor(totals.WalkSpeed or S.Defaults.WalkSpeed or 200))
    local runSpeed = math.max(10, math.floor(totals.RunSpeed or S.Defaults.RunSpeed or 400))
    local jumpPower = math.floor(totals.JumpPower or S.Defaults.JumpPower or 200)

    local prevMaxHp = ply:GetMaxHealth()
    local curHp = ply:Health()
    local wasFullHp = curHp >= prevMaxHp
    ply:SetMaxHealth(hp)
    if fullReset == true then
        ply:SetHealth(hp)
    elseif wasFullHp then
        ply:SetHealth(hp)
    else
        ply:SetHealth(math.min(curHp, hp))
    end

    if fullReset == true then
        ply:SetArmor(armor)
    else
        local prevArmor = math.max(0, math.floor((prevTotals and prevTotals.Armor) or S.Defaults.Armor or 0))
        local curArmor = ply:Armor()
        local wasFullArmor = prevArmor > 0 and curArmor >= prevArmor
        if wasFullArmor then
            ply:SetArmor(armor)
        else
            ply:SetArmor(math.Clamp(curArmor, 0, armor))
        end
    end

    ply:SetWalkSpeed(walkSpeed)
    ply:SetRunSpeed(runSpeed)
    ply:SetJumpPower(jumpPower)

    local C = VERSE.Combat
    if C and C.SyncMana and ply.GetMana and ply.GetManaMax then
        local prevMaxMana = ply:GetManaMax()
        local curMana = ply:GetMana()
        local wasFullMana = curMana >= prevMaxMana

        for key, definition in pairs(S.Definitions) do
            ply:SetPublicInt("VERSE::Stats::" .. key, math.floor(totals[key] ~= nil and totals[key] or definition.default or 0))
        end

        local newMaxMana = ply:GetManaMax()
        if fullReset == true then
            ply:SetMana(newMaxMana, true)
        elseif wasFullMana then
            ply:SetMana(newMaxMana, true)
        else
            ply:SetMana(math.min(curMana, newMaxMana), true)
        end
        return
    end

    for key, definition in pairs(S.Definitions) do
        ply:SetPublicInt("VERSE::Stats::" .. key, math.floor(totals[key] ~= nil and totals[key] or definition.default or 0))
    end
end

function PLAYER:RecalcStats(fullReset)
    if not IsValid(self) then return end

    local prevTotals = self._statTotals or {}
    local totals, breakdown = S:ResolveAll(self, { includeBreakdown = true })
    self._statTotals = totals
    self._statBreakdown = breakdown
    applyTotals(self, totals, prevTotals, fullReset == true)
end

function PLAYER:GetStatBreakdown(key)
    if not IsValid(self) then return {} end
    key = S:ResolveKey(key)
    if not key then return {} end
    return istable(self._statBreakdown) and self._statBreakdown[key] or {}
end

function PLAYER:GetStatBase(key)
    if not IsValid(self) then return 0 end
    key = S:ResolveKey(key)
    if not key then return 0 end
    local runtime = ensureRuntime(self)
    local base = runtime.sources._base or {}
    return tonumber(base[key]) or S.Defaults[key] or 0
end

function PLAYER:SetStatBase(key, value)
    if not IsValid(self) then return end
    key = S:ResolveKey(key)
    if not key then return end

    local runtime = ensureRuntime(self)
    local base = runtime.sources._base
    value = tonumber(value) or 0
    if base[key] == value then return end
    base[key] = value
    self:RecalcStats()
end

function PLAYER:SetStatBaseBulk(map, fullReset)
    if not IsValid(self) or not istable(map) then return end

    local runtime = ensureRuntime(self)
    local base = runtime.sources._base
    local changed = false

    for rawKey, value in pairs(map) do
        local key = S:ResolveKey(rawKey)
        if key then
            value = tonumber(value) or 0
            if base[key] ~= value then
                base[key] = value
                changed = true
            end
        end
    end

    if changed then self:RecalcStats(fullReset == true) end
end

function PLAYER:GetStatBuff(source, key)
    if not IsValid(self) then return 0 end
    if not isstring(source) or source == "" or source == "_base" then return 0 end
    key = S:ResolveKey(key)
    if not key then return 0 end

    local runtime = ensureRuntime(self)
    local sourceMap = runtime.sources[source] or {}
    return tonumber(sourceMap[key]) or 0
end

function PLAYER:SetStatBuff(source, key, value)
    if not IsValid(self) then return end
    if not isstring(source) or source == "" or source == "_base" then return end
    key = S:ResolveKey(key)
    if not key then return end

    local runtime = ensureRuntime(self)
    runtime.sources[source] = runtime.sources[source] or {}
    value = tonumber(value) or 0
    if runtime.sources[source][key] == value then return end
    runtime.sources[source][key] = value
    self:RecalcStats()
end

function PLAYER:SetStatBuffBulk(source, map)
    if not IsValid(self) then return end
    if not isstring(source) or source == "" or source == "_base" then return end
    if not istable(map) then return end

    local runtime = ensureRuntime(self)
    runtime.sources[source] = runtime.sources[source] or {}
    local sourceMap = runtime.sources[source]
    local changed = false

    for rawKey, value in pairs(map) do
        local key = S:ResolveKey(rawKey)
        if key then
            value = tonumber(value) or 0
            if sourceMap[key] ~= value then
                sourceMap[key] = value
                changed = true
            end
        end
    end

    if changed then self:RecalcStats() end
end

function PLAYER:ClearStatBuff(source)
    if not IsValid(self) or not isstring(source) or source == "" or source == "_base" then return end

    local runtime = ensureRuntime(self)
    if not next(runtime.sources[source] or {}) then return end
    runtime.sources[source] = {}
    self:RecalcStats()
end

function PLAYER:ClearAllStatBuffs()
    if not IsValid(self) then return end

    local runtime = ensureRuntime(self)
    for sourceId, _ in pairs(runtime.sources) do
        if sourceId ~= "_base" then
            runtime.sources[sourceId] = {}
        end
    end
    self:RecalcStats()
end

S:RegisterProvider("base", function(ply)
    local runtime = ensureRuntime(ply)
    return normalizeSourceMap(runtime.sources._base, "set")
end, { priority = 1000 })

S:RegisterProvider("job", function(ply)
    local jobStats = ply.Job and ply.Job.stats or nil
    if not istable(jobStats) then return nil end
    return normalizeSourceMap(jobStats, "set")
end, { priority = 900 })

S:RegisterProvider("skilltree", function(ply)
    local skillTree = VERSE and VERSE.SkillTree
    if not skillTree or not skillTree.GetStatBonusesForPlayer then return nil end
    return normalizeSourceMap(skillTree:GetStatBonusesForPlayer(ply), "add")
end, { priority = 800 })

for index = 1, #(S.LegacySources or {}) do
    local sourceId = S.LegacySources[index]
    S:RegisterProvider("legacy_" .. sourceId, function(ply)
        local runtime = ensureRuntime(ply)
        return normalizeSourceMap(runtime.sources[sourceId], "add")
    end, { priority = 200 - index })
end

VERSE.Hook.AddNS("Stats", "PlayerInitialSpawn", "VERSE::PlayerInitialSpawn::Stats", function(ply)
    ply._statRuntime = nil
    ply._statTotals = nil
    ply._statBreakdown = nil
    ensureRuntime(ply)
    ply:RecalcStats(true)
end)

VERSE.Hook.AddNS("Stats", "VERSE::Characters::Loaded", "VERSE::Stats::CharacterLoaded", function(ply)
    if IsValid(ply) then ply:RecalcStats(true) end
end)

VERSE.Hook.AddNS("Stats", "VERSE::OnChanged::Jobs", "VERSE::Stats::JobChanged", function(ply)
    if IsValid(ply) then ply:RecalcStats(true) end
end)