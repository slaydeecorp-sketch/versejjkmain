AddCSLuaFile()
SWEP.Base = "weapon_base"
SWEP.PrintName = "Combat SWEP Base"
SWEP.Author = ""
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "VERSE | Combat"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.SkillTreeProfile = "default"
SWEP.SkillTreeProfiles = SWEP.SkillTreeProfiles or {}
SWEP.SkillTreeAbilityHandlers = SWEP.SkillTreeAbilityHandlers or {}
SWEP.IsCombatSkillWeapon = true

local function normalizeToken(value)
    value = string.Trim(tostring(value or ""))
    return value
end

function SWEP:Initialize()
    if self.BaseClass and isfunction(self.BaseClass.Initialize) then self.BaseClass.Initialize(self) end
    self:SetHoldType("yuji_base")
    self:SetupSkillTree(self.SkillTreeProfile)
end

function SWEP:SetupSkillTree(profileId)
    profileId = normalizeToken(profileId)
    if profileId == "" then profileId = normalizeToken(self.SkillTreeProfile) end
    if profileId == "" then profileId = "default" end
    self.SkillTreeProfileId = profileId
    self._skillTreeNextUse = self._skillTreeNextUse or {}
    return profileId
end

function SWEP:GetSkillTreeProfileId()
    local profileId = normalizeToken(self.SkillTreeProfileId or self.SkillTreeProfile)
    if profileId == "" then profileId = "default" end
    return profileId
end

function SWEP:GetSkillTreeProfileTable(profileId)
    profileId = normalizeToken(profileId)
    if profileId == "" then profileId = self:GetSkillTreeProfileId() end
    local profiles = self.SkillTreeProfiles
    if not istable(profiles) then return nil end
    local profileData = profiles[profileId]
    if not istable(profileData) then return nil end
    return profileData
end

function SWEP:GetSkillTreeAbilityHandler(abilityId, _, _, context)
    abilityId = normalizeToken(abilityId)
    if abilityId == "" then return nil end
    local profileData = self:GetSkillTreeProfileTable(context and context.profile_id or nil)
    local profileHandlers = istable(profileData) and (istable(profileData.abilities) and profileData.abilities or profileData) or nil
    if istable(profileHandlers) and profileHandlers[abilityId] ~= nil then return profileHandlers[abilityId] end
    if istable(self.SkillTreeAbilityHandlers) and self.SkillTreeAbilityHandlers[abilityId] ~= nil then return self.SkillTreeAbilityHandlers[abilityId] end
    if istable(self.SkillTreeAbilities) and self.SkillTreeAbilities[abilityId] ~= nil then return self.SkillTreeAbilities[abilityId] end
    return nil
end

function SWEP:GetNextSkillTreeAbilityUse(abilityId)
    self._skillTreeNextUse = self._skillTreeNextUse or {}
    return tonumber(self._skillTreeNextUse[normalizeToken(abilityId)]) or 0
end

function SWEP:SetNextSkillTreeAbilityUse(abilityId, delay)
    abilityId = normalizeToken(abilityId)
    if abilityId == "" then return end
    self._skillTreeNextUse = self._skillTreeNextUse or {}
    self._skillTreeNextUse[abilityId] = CurTime() + math.max(0, tonumber(delay) or 0)
end

function SWEP:GetSkillTreeAbilityCooldown(_, handlerData, abilityData)
    local cooldown = nil
    if istable(handlerData) then cooldown = tonumber(handlerData.cooldown or handlerData.reuse_delay) end
    if cooldown == nil and istable(abilityData) then cooldown = tonumber(abilityData.cooldown) end
    return math.max(0, cooldown or 0)
end

function SWEP:CanUseSkillTreeAbility(abilityId, execution, abilityData, context, handlerData)
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return false, "bad_player" end
    if owner:GetActiveWeapon() ~= self then return false, "apply_failed" end
    if self:GetNextSkillTreeAbilityUse(abilityId) > CurTime() then return false, "cooldown" end
    local canUse = istable(handlerData) and (handlerData.canUse or handlerData.can_use) or nil
    if isfunction(canUse) then
        local ok, reason = canUse(self, owner, abilityId, execution, abilityData, context)
        if ok == false then return false, reason or "apply_failed" end
    end
    if isfunction(self.CanUseMappedSkillTreeAbility) then
        local ok, reason = self:CanUseMappedSkillTreeAbility(abilityId, execution, abilityData, context, handlerData)
        if ok == false then return false, reason or "apply_failed" end
    end
    return true, "ok"
end

function SWEP:ActivateSkillTreeBuffAbility(buffProfile, abilityId, execution, abilityData, context)
    local owner = self:GetOwner()
    local effects = VERSE and (VERSE.Effects or VERSE.Buffs)
    if not IsValid(owner) or not owner:IsPlayer() then return false, "bad_player" end
    if not effects or not isfunction(effects.ActivateCombatBuff) then return false, "missing_executor" end
    return effects:ActivateCombatBuff(owner, buffProfile, abilityId, execution, abilityData, context)
end

function SWEP:RunSkillTreeHookAbility(hookName, abilityId, execution, abilityData, context)
    if not VERSE or not VERSE.Hook or not isfunction(VERSE.Hook.Run) then return false, "missing_executor" end
    local owner = self:GetOwner()
    local ok, reason = VERSE.Hook.Run(hookName, owner, abilityId, execution, abilityData, VERSE.SkillTree, context, self)
    if ok == nil then return false, "missing_executor" end
    if ok == false then return false, reason or "apply_failed" end
    return true, reason or "ok"
end

function SWEP:ExecuteSkillTreeAbility(abilityId, execution, abilityData, context, handlerData)
    local owner = self:GetOwner()
    if isfunction(handlerData) then return handlerData(self, owner, abilityId, execution, abilityData, context) end
    if istable(handlerData) then
        if isfunction(handlerData.onUse) then return handlerData.onUse(self, owner, abilityId, execution, abilityData, context) end
        if isfunction(handlerData.use) then return handlerData.use(self, owner, abilityId, execution, abilityData, context) end
        local buffProfile = normalizeToken(handlerData.buff_profile or (istable(execution) and execution.buff_profile) or "")
        if buffProfile ~= "" then return self:ActivateSkillTreeBuffAbility(buffProfile, abilityId, execution, abilityData, context) end
        local hookName = normalizeToken(handlerData.hook or handlerData.event)
        if hookName ~= "" then return self:RunSkillTreeHookAbility(hookName, abilityId, execution, abilityData, context) end
    end

    execution = istable(execution) and execution or {}
    local executionType = normalizeToken(execution.type)
    if executionType == "combat_buff" then
        local buffProfile = normalizeToken(execution.buff_profile)
        if buffProfile == "" then return false, "bad_execution" end
        return self:ActivateSkillTreeBuffAbility(buffProfile, abilityId, execution, abilityData, context)
    end

    if executionType == "hook" then
        local hookName = normalizeToken(execution.hook or execution.event)
        if hookName == "" then return false, "bad_execution" end
        return self:RunSkillTreeHookAbility(hookName, abilityId, execution, abilityData, context)
    end

    return false, "missing_executor"
end

function SWEP:TryUseSkillTreeAbility(abilityId, execution, abilityData, context)
    if CLIENT then return false end
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() or owner:GetActiveWeapon() ~= self then return false end

    context = istable(context) and table.Copy(context) or {}
    context.weapon = self
    context.profile_id = self:GetSkillTreeProfileId()

    local handlerData = self:GetSkillTreeAbilityHandler(abilityId, execution, abilityData, context)
    local executionType = normalizeToken(istable(execution) and execution.type or "")
    if handlerData == nil and executionType ~= "combat_buff" and executionType ~= "hook" then return false end

    local canUse, reason = self:CanUseSkillTreeAbility(abilityId, execution, abilityData, context, handlerData)
    if not canUse then return true, false, reason or "apply_failed" end
    if isfunction(self.OnSkillTreeAbilityStart) then self:OnSkillTreeAbilityStart(abilityId, execution, abilityData, context, handlerData) end

    local ok, useReason = self:ExecuteSkillTreeAbility(abilityId, execution, abilityData, context, handlerData)
    if ok then
        local cooldown = self:GetSkillTreeAbilityCooldown(abilityId, handlerData, abilityData, context)
        if cooldown > 0 then self:SetNextSkillTreeAbilityUse(abilityId, cooldown) end
        if isfunction(self.OnSkillTreeAbilityUsed) then self:OnSkillTreeAbilityUsed(abilityId, execution, abilityData, context, handlerData) end
    elseif isfunction(self.OnSkillTreeAbilityFailed) then
        self:OnSkillTreeAbilityFailed(abilityId, useReason or "apply_failed", execution, abilityData, context, handlerData)
    end

    return true, ok == true, useReason or (ok and "ok" or "apply_failed")
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
