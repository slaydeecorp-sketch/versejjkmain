local C = VERSE.Combat
if not C then return end
local LOG_NS = "VERSE::Combat"
C:RegisterOutgoingModifier("stats_flat_damage", 50, function(dmginfo, _, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    local bonus = attacker:GetStat("Damage")
    if bonus and bonus > 0 then dmginfo:SetDamage(dmginfo:GetDamage() + bonus) end
end)

C:RegisterOutgoingModifier("stats_melee_damage", 60, function(dmginfo, _, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    local dtypes = dmginfo:GetDamageType()
    local isMelee = bit.band(dtypes, DMG_CLUB) ~= 0 or bit.band(dtypes, DMG_SLASH) ~= 0 or bit.band(dtypes, DMG_CRUSH) ~= 0
    if not isMelee then return end
    local bonus = attacker:GetStat("MeleeDamage")
    if bonus and bonus > 0 then dmginfo:SetDamage(dmginfo:GetDamage() + bonus) end
end)

C:RegisterIncomingModifier("stats_damage_reduction", 50, function(dmginfo, target)
    if not IsValid(target) or not target:IsPlayer() then return end
    local reduction = target:GetStat("DamageReduction")
    if reduction and reduction > 0 then
        reduction = math.Clamp(reduction, 0, 0.90)
        dmginfo:SetDamage(dmginfo:GetDamage() * (1 - reduction))
    end
end)

local nextRegenAt = setmetatable({}, {__mode = "k"})
VERSE.Timers.CreateNS("Combat", "HealthRegen", C:GetHealthRegenThinkInterval(), 0, function()
    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then
            nextRegenAt[ply] = nil
        else
            local regen = tonumber(ply:GetStat("HealthRegen")) or 0
            if regen <= 0 then
                nextRegenAt[ply] = nil
            else
                local interval = C:GetHealthRegenInterval(ply)
                local dueAt = tonumber(nextRegenAt[ply]) or (now + interval)
                local maxDueAt = now + interval
                if dueAt > maxDueAt then dueAt = maxDueAt end
                if now >= dueAt then
                    local hp = ply:Health()
                    local max = ply:GetMaxHealth()
                    if hp < max then
                        ply:SetHealth(math.min(hp + regen, max))
                    end

                    dueAt = now + interval
                end

                nextRegenAt[ply] = dueAt
            end
        end
    end
end)

VERSE.Hook.AddNS("Combat", "EntityTakeDamage", "VERSE::EntityTakeDamage::Combat", function(target, dmginfo)
    if not IsValid(target) then return end
    if dmginfo:GetDamage() <= 0 then return end
    local attacker = dmginfo:GetAttacker()
    local stop = VERSE.Hook.Run("VERSE::Combat::PreDamage", target, dmginfo, attacker)
    if stop == VERSE.Hook.STOP then return true end
    if IsValid(attacker) and attacker:IsPlayer() then
        for i = 1, #C._outgoing do
            local mod = C._outgoing[i]
            local ok, err = pcall(mod.fn, dmginfo, target, attacker)
            if not ok then VERSE.Log:Error(LOG_NS, "Outgoing modifier '" .. mod.id .. "' error: " .. tostring(err)) end
        end
    end

    VERSE.Hook.Run("VERSE::Combat::AfterOutgoing", target, dmginfo, attacker)
    for i = 1, #C._incoming do
        local mod = C._incoming[i]
        local ok, err = pcall(mod.fn, dmginfo, target, attacker)
        if not ok then VERSE.Log:Error(LOG_NS, "Incoming modifier '" .. mod.id .. "' error: " .. tostring(err)) end
    end

    VERSE.Hook.Run("VERSE::Combat::PostDamage", target, dmginfo, attacker)
end)

hook.Add("GetFallDamage", "VERSE::Combat::NoFallDamage", function(ply, speed) return 0 end)

hook.Add("EntityEmitSound", "VERSE::Combat::BlockFallSound", function(data)
    local name = string.lower(tostring(data.SoundName or ""))
    local orig = string.lower(tostring(data.OriginalSoundName or ""))
    if string.find(name, "fallpain", 1, true) or string.find(name, "falldamage", 1, true) or string.find(name, "fallgib", 1, true) then return false end
    if string.find(orig, "fallpain", 1, true) or string.find(orig, "falldamage", 1, true) or string.find(orig, "fallgib", 1, true) then return false end
end)
