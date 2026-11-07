local E = VERSE.Effects or VERSE.Buffs
local C = VERSE.Combat
local ST = VERSE.SkillTree
if not E or not C or not ST then return end
C:RegisterOutgoingModifier("debuff_passive_armor_break", 220, function(_, target, attacker)
    if not IsValid(target) or not target:IsPlayer() then return end
    if not (IsValid(attacker) and attacker:IsPlayer() and ST:HasPassiveBuff(attacker, "piercing_output")) then return end
    if math.random() <= 0.18 then
        E:ApplyTimedDebuff(target, "armor_break", 4, {
            Armor = -20,
            DamageReduction = -0.08,
        }, {
            attacker = attacker,
        })
    end
end)