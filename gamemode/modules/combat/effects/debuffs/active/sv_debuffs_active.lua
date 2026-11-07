local E = VERSE.Effects or VERSE.Buffs
local C = VERSE.Combat
local ST = VERSE.SkillTree

if not E or not C or not ST then return end

local function hasAbility(ply, abilityId)
    return IsValid(ply) and ply:IsPlayer() and ST:HasAbility(ply, abilityId)
end

C:RegisterOutgoingModifier("debuff_active_bleed", 230, function(_, target, attacker)
    if not IsValid(target) or not target:IsPlayer() then return end
    if not hasAbility(attacker, "black_flash") then return end

    if math.random() <= 0.22 then
        if C.TryConsumeAbilityMana then
            local ok = C:TryConsumeAbilityMana(attacker, "black_flash", {
                notifyOnFail = false,
            })
            if not ok then return end
        end

        E:ApplyTimedDebuff(target, "bleed", 5, {
            RunSpeed = -12,
        }, {
            attacker = attacker,
            damagePerTick = 3,
            tickEvery = 1,
        })
    end
end)
