local E = VERSE.Effects or VERSE.Buffs
local C = VERSE.Combat
local ST = VERSE.SkillTree
if not E or not C or not ST then return end
local function hasPassive(ply, passiveId)
    return IsValid(ply) and ply:IsPlayer() and ST:HasPassiveBuff(ply, passiveId)
end

C:RegisterOutgoingModifier("passive_reinforced_strikes", 130, function(dmginfo, _, attacker)
    if not hasPassive(attacker, "reinforced_strikes") then return end
    local dtypes = dmginfo:GetDamageType()
    local isMelee = bit.band(dtypes, DMG_CLUB) ~= 0 or bit.band(dtypes, DMG_SLASH) ~= 0 or bit.band(dtypes, DMG_CRUSH) ~= 0
    if not isMelee then return end
    dmginfo:ScaleDamage(1.12)
end)

C:RegisterOutgoingModifier("passive_spirit_symbiosis", 131, function(dmginfo, _, attacker)
    if not hasPassive(attacker, "spirit_symbiosis") then return end
    local ap = tonumber(attacker:GetStat("AbilityPower")) or 0
    if ap <= 0 then return end
    dmginfo:SetDamage(dmginfo:GetDamage() + (ap * 0.15))
end)

C:RegisterOutgoingModifier("passive_piercing_output", 132, function(dmginfo, _, attacker)
    if not hasPassive(attacker, "piercing_output") then return end
    dmginfo:ScaleDamage(1.10)
end)

C:RegisterOutgoingModifier("passive_bloodline_surge", 133, function(dmginfo, _, attacker)
    if not hasPassive(attacker, "bloodline_surge") then return end
    local hp, max = attacker:Health(), math.max(1, attacker:GetMaxHealth())
    if hp / max <= 0.5 then dmginfo:ScaleDamage(1.18) end
end)

C:RegisterOutgoingModifier("passive_combat_brutality", 134, function(dmginfo, _, attacker)
    if not hasPassive(attacker, "combat_brutality") then return end
    dmginfo:ScaleDamage(1.15)
end)

C:RegisterIncomingModifier("passive_evasive_flow", 130, function(dmginfo, target)
    if not hasPassive(target, "evasive_flow") then return end
    if math.random() <= 0.08 then dmginfo:SetDamage(0) end
end)

C:RegisterIncomingModifier("passive_hidden_potential", 131, function(dmginfo, target)
    if not hasPassive(target, "hidden_potential") then return end
    local hp, max = target:Health(), math.max(1, target:GetMaxHealth())
    if hp / max <= 0.35 then dmginfo:ScaleDamage(0.7) end
end)

C:RegisterIncomingModifier("passive_combat_brutality_penalty", 132, function(dmginfo, target)
    if not hasPassive(target, "combat_brutality") then return end
    dmginfo:ScaleDamage(1.08)
end)

VERSE.Hook.AddNS("BuffsPassive", "VERSE::Combat::PostDamage", "VERSE::Combat::PostDamage::PassiveMomentum", function(target)
    if not IsValid(target) or not target:IsPlayer() then return end
    if not hasPassive(target, "unbroken_momentum") then return end
    E:ApplyTimedBuff(target, "momentum_speed", 2.0, {
        RunSpeed = 25,
        WalkSpeed = 10,
    })
end)