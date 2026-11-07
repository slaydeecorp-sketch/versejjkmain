AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function SWEP:Equip(owner)
    if self.BaseClass and isfunction(self.BaseClass.Equip) then self.BaseClass.Equip(self, owner) end
    self:SetupSkillTree(self.SkillTreeProfile)
end

function SWEP:Deploy()
    self:SetupSkillTree(self.SkillTreeProfile)
    if self.BaseClass and isfunction(self.BaseClass.Deploy) then
        local ok = self.BaseClass.Deploy(self)
        if ok ~= nil then return ok end
    end
    return true
end
