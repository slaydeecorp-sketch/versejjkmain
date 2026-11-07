local C = VERSE.Combat
if not C then return end

local PLAYER = FindMetaTable("Player")

function PLAYER:GetManaMax()
    if not IsValid(self) then return 1 end

    local fallback = C.GetPlayerManaMax and C:GetPlayerManaMax(self) or C:GetConfigNumber("ManaBase", 100)
    return math.max(1, tonumber(self:GetPublicFloat(C:GetManaMaxKey(), fallback)) or fallback)
end

function PLAYER:GetMana()
    if not IsValid(self) then return 0 end

    local maxMana = self:GetManaMax()
    local mana = tonumber(self:GetPublicFloat(C:GetManaKey(), maxMana)) or maxMana
    return math.Clamp(mana, 0, maxMana)
end

if not PLAYER.GetCurrentMana then
    function PLAYER:GetCurrentMana()
        return self:GetMana()
    end
end
