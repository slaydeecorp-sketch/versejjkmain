local E = VERSE.Effects or VERSE.Buffs
local C = VERSE.Combat
local ST = VERSE.SkillTree
if not E then return end

local profileToAbility = {
    limit_break = "limit_break",
    cursed_burst_window = "cursed_burst",
    shadow_dash_window = "shadow_dash",
}

function E:ActivateCombatBuff(ply, buffProfile)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    buffProfile = tostring(buffProfile or "")
    if buffProfile == "" then return false end

    local abilityId = profileToAbility[buffProfile] or (C and C:GetAbilityIdFromBuffProfile(buffProfile))
    if abilityId and ST and ST.HasAbility and not ST:HasAbility(ply, abilityId) then
        return false, "ability_locked"
    end

    local manaSpent = 0
    if abilityId and C and C.TryConsumeAbilityMana then
        local ok, reason, cost = C:TryConsumeAbilityMana(ply, abilityId)
        if not ok then return false, reason or "not_enough_mana" end
        manaSpent = tonumber(cost) or 0
    end

    local profileData = C and C.GetBuffProfileData and C:GetBuffProfileData(buffProfile) or nil
    if not istable(profileData) then return false, "unknown_profile" end

    local applied = self:ApplyTimedBuff(
        ply,
        buffProfile,
        tonumber(profileData.duration) or 0,
        table.Copy(profileData.stats or {})
    )

    if not applied and manaSpent > 0 and C and ply.AddMana then
        ply:AddMana(manaSpent)
    end

    if not applied then return false, "apply_failed" end
    return true, "ok"
end