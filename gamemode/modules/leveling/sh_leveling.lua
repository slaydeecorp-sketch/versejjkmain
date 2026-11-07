VERSE.Leveling = VERSE.Leveling or {}
local LVL = VERSE.Leveling

LVL.Config = {
    MaxLevel = 100,
    BaseEXP = 100,
    ExpGrowth = 1.01,
    PointsPerLevel = 1,
    TableName = "verse_leveling",
}

LVL.Net = {
    Sync = "VERSE::Leveling::Sync",
    LevelUp = "VERSE::Leveling::LevelUp",
}

LVL.NW = {
    Level = "VERSE.Level",
    EXP = "VERSE.EXP",
}

function LVL:RequiredEXP(level)
    level = math.max(1, math.floor(tonumber(level) or 1))
    return math.floor(self.Config.BaseEXP * math.pow(self.Config.ExpGrowth, level - 1))
end

function LVL:TotalEXPForLevel(level)
    local total = 0
    for i = 1, level - 1 do
        total = total + self:RequiredEXP(i)
    end
    return total
end

local PLAYER = FindMetaTable("Player")

function PLAYER:GetLevel()
    return math.max(1, self:GetNWInt(LVL.NW.Level, 1))
end

function PLAYER:GetEXP()
    return math.max(0, self:GetNWInt(LVL.NW.EXP, 0))
end

function PLAYER:GetMaxEXP()
    return LVL:RequiredEXP(self:GetLevel())
end
