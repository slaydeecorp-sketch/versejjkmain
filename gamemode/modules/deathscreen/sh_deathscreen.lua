VERSE.Deathscreen = VERSE.Deathscreen or {}
local Deathscreen = VERSE.Deathscreen

Deathscreen.Config = {
    RespawnDelay = 10,
    BlockRespawnUntilTimer = true,

    NET = {
        Open = "VERSE::Deathscreen::Open",
        Close = "VERSE::Deathscreen::Close",
        Request = "VERSE::Deathscreen::Request",
    }
}

function Deathscreen:GetEntityName(ent)
    if not IsValid(ent) then return "World" end

    if ent == game.GetWorld() then
        return "World"
    end

    if ent:IsPlayer() then
        return ent:Nick()
    end

    local cls = ent:GetClass()
    if isstring(cls) and cls ~= "" then
        return cls
    end

    return "Unknown"
end

function Deathscreen:Net(key)
    return Deathscreen.Config.NET[key]
end