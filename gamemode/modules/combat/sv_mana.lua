local C = VERSE.Combat
if not C then return end

local PLAYER = FindMetaTable("Player")
local nextRegenAt = setmetatable({}, { __mode = "k" })

local function isValidAlivePlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive()
end

local function getManaMax(ply)
    return math.max(1, tonumber(C:GetPlayerManaMax(ply)) or 1)
end

function C:SyncMana(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local maxMana = getManaMax(ply)
    local mana = tonumber(ply:GetPublicFloat(self:GetManaKey(), maxMana)) or maxMana
    mana = math.Clamp(mana, 0, maxMana)

    ply:SetPublicFloat(self:GetManaKey(), mana)
    ply:SetPublicFloat(self:GetManaMaxKey(), maxMana)
end

function PLAYER:GetManaMax()
    if not IsValid(self) then return 1 end
    return getManaMax(self)
end

function PLAYER:GetMana()
    if not IsValid(self) then return 0 end

    local maxMana = self:GetManaMax()
    local mana = tonumber(self:GetPublicFloat(C:GetManaKey(), maxMana)) or maxMana
    mana = math.Clamp(mana, 0, maxMana)

    return mana
end

function PLAYER:SetMana(amount, silent)
    if not IsValid(self) then return 0 end

    local old = self:GetMana()
    local maxMana = self:GetManaMax()
    local nextValue = math.Clamp(tonumber(amount) or 0, 0, maxMana)

    self:SetPublicFloat(C:GetManaKey(), nextValue)
    self:SetPublicFloat(C:GetManaMaxKey(), maxMana)

    if silent ~= true and old ~= nextValue then
        VERSE.Hook.Run("VERSE::Combat::ManaChanged", self, old, nextValue, maxMana)
    end

    return nextValue
end

function PLAYER:AddMana(amount, silent)
    amount = tonumber(amount) or 0
    if amount <= 0 then return self:GetMana() end
    return self:SetMana(self:GetMana() + amount, silent)
end

function PLAYER:TakeMana(amount, silent)
    amount = tonumber(amount) or 0
    if amount <= 0 then return 0 end

    local current = self:GetMana()
    local taken = math.min(current, amount)
    self:SetMana(current - taken, silent)
    return taken
end

function PLAYER:HasMana(amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    return self:GetMana() >= amount
end

if not PLAYER.GetCurrentMana then
    function PLAYER:GetCurrentMana()
        return self:GetMana()
    end
end

if not PLAYER.SetCurrentMana then
    function PLAYER:SetCurrentMana(amount, silent)
        return self:SetMana(amount, silent)
    end
end

if not PLAYER.AddCurrentMana then
    function PLAYER:AddCurrentMana(amount, silent)
        return self:AddMana(amount, silent)
    end
end

if not PLAYER.TakeCurrentMana then
    function PLAYER:TakeCurrentMana(amount, silent)
        return self:TakeMana(amount, silent)
    end
end

function C:InitializeMana(ply, fullRestore)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    self:SyncMana(ply)
    if fullRestore == true then
        ply:SetMana(ply:GetManaMax(), true)
    else
        ply:SetMana(ply:GetMana(), true)
    end

    nextRegenAt[ply] = CurTime() + self:GetManaRegenInterval(ply)
end

local function manaRegenThink()
    local now = CurTime()

    for _, ply in ipairs(player.GetAll()) do
        if not isValidAlivePlayer(ply) then
            nextRegenAt[ply] = nil
        else
            local regen = C:GetManaRegenAmount(ply)
            if regen <= 0 then
                nextRegenAt[ply] = nil
            else
                local interval = C:GetManaRegenInterval(ply)
                local dueAt = tonumber(nextRegenAt[ply]) or (now + interval)
                local maxDueAt = now + interval
                if dueAt > maxDueAt then dueAt = maxDueAt end

                if now >= dueAt then
                    if ply:GetMana() < ply:GetManaMax() then
                        ply:AddMana(regen)
                    else
                        -- Mana max atteinte : sync uniquement pour garder ManaMax à jour
                        C:SyncMana(ply)
                    end
                    dueAt = now + interval
                end

                nextRegenAt[ply] = dueAt
            end
        end
    end
end

VERSE.Timers.CreateNS("Combat", "ManaRegen", C:GetManaRegenThinkInterval(), 0, manaRegenThink)

VERSE.Hook.AddNS("Combat", "PlayerInitialSpawn", "VERSE::Combat::Mana::InitialSpawn", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        C:InitializeMana(ply, true)
    end)
end)

VERSE.Hook.AddNS("Combat", "PlayerSpawn", "VERSE::Combat::Mana::Spawn", function(ply)
    if not IsValid(ply) then return end
    C:InitializeMana(ply, true)
end)

VERSE.Hook.AddNS("Combat", "VERSE::Characters::Loaded", "VERSE::Combat::Mana::CharacterLoaded", function(ply)
    if not IsValid(ply) then return end
    C:InitializeMana(ply, true)
end)

VERSE.Hook.AddNS("Combat", "VERSE::OnChanged::Jobs", "VERSE::Combat::Mana::JobChanged", function(ply)
    if not IsValid(ply) then return end
    local oldMax = tonumber(ply:GetPublicFloat(C:GetManaMaxKey(), C:GetPlayerManaMax(ply))) or C:GetPlayerManaMax(ply)
    local ratio = oldMax > 0 and (ply:GetMana() / oldMax) or 1

    C:SyncMana(ply)

    local newMax = ply:GetManaMax()
    local projected = math.Clamp(newMax * ratio, 0, newMax)
    ply:SetMana(projected, true)
end)

VERSE.Hook.AddNS("Combat", "PlayerDisconnected", "VERSE::Combat::Mana::Disconnect", function(ply)
    nextRegenAt[ply] = nil
end)
