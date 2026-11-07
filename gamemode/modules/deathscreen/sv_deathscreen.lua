local Deathscreen = VERSE.Deathscreen
local CFG = Deathscreen.Config

local function EnsureState(ply)
    ply._Death = ply._Death or {}
    return ply._Death
end

function Deathscreen:SetDeathState(ply, deadAt, respawnAt, killerName, killerModel, killerBodygroups, killerAppearance)
    if not IsValid(ply) then return end
    local st = EnsureState(ply)
    st.deadAt = deadAt
    st.respawnAt = respawnAt
    st.canRespawn = false
    st.killerName = tostring(killerName or "Unknown")
    st.killerModel = tostring(killerModel or "")
    st.killerBodygroups = istable(killerBodygroups) and killerBodygroups or {}
    st.killerAppearance = istable(killerAppearance) and killerAppearance or {}
end

function Deathscreen:ClearDeathState(ply)
    if not IsValid(ply) then return end
    ply._Death = nil
end

function Deathscreen:GetDeathState(ply)
    if not IsValid(ply) then return nil end
    return ply._Death
end

function Deathscreen:CanRespawnNow(ply)
    local st = self:GetDeathState(ply)
    if not st then return false end
    return CurTime() >= (tonumber(st.respawnAt) or 0)
end

local function SafeModel(ent)
    if not IsValid(ent) then return "" end
    if ent == game.GetWorld() then return "" end
    if ent.GetModel then
        local mdl = ent:GetModel()
        if isstring(mdl) and mdl ~= "" then return mdl end
    end
    return ""
end

local function BuildKillerInfo(attacker, inflictor)
    local src = attacker
    if not IsValid(src) or src == game.GetWorld() and (IsValid(inflictor) and inflictor ~= game.GetWorld()) then
        src = inflictor
    end

    local killerName = Deathscreen:GetEntityName(src)
    local killerModel = SafeModel(src)
    if killerModel == "" then
        killerModel = "models/player/kleiner.mdl"
    end

    local killerBodygroups = {}
    if IsValid(src) and src.IsPlayer and src:IsPlayer() then
        for i = 0, src:GetNumBodyGroups() - 1 do
            killerBodygroups[i + 1] = src:GetBodygroup(i)
        end
    end

    -- Apparence visuelle du tueur (tête custom, couleur de peau, coiffure…)
    -- Ces données sont nécessaires côté client car le DModelPanel ne déclenche
    -- pas PrePlayerDraw/PostPlayerDraw — le système VERSE d'apparence n'y tourne pas.
    local killerAppearance = {}
    if IsValid(src) and src.IsPlayer and src:IsPlayer() then
        local CH = VERSE.Characters
        local nw = (CH and CH.AppearanceNW) or {}
        local function pubStr(key, def) return (key and src.GetPublicString and src:GetPublicString(key, def)) or def end
        local function pubInt(key, def) return (key and src.GetPublicInt  and src:GetPublicInt(key,  def)) or def end
        killerAppearance = {
            headModel    = pubStr(nw.HeadModel,    ""),
            skinColor    = pubStr(nw.SkinColor,    ""),
            skinTone     = pubInt(nw.SkinTone,     1),
            bodyStyle    = pubInt(nw.BodyStyle,    0),
            headStyle    = pubInt(nw.HeadStyle,    0),
            hairStyle    = pubInt(nw.HairStyle,    0),
            hairColor    = pubStr(nw.HairColor,    ""),
            headType     = pubInt(nw.HeadType,     1),
            eyebrowStyle = pubInt(nw.EyebrowStyle, 1),
            eyebrowColor = pubStr(nw.EyebrowColor, ""),
            irisStyle    = pubInt(nw.IrisStyle,    1),
            irisSize     = pubInt(nw.IrisSize,     100),
            eyeColor     = pubStr(nw.EyeColor,     ""),
            bodyMarks    = pubStr(nw.BodyMarks,    ""),
            height       = pubInt(nw.Height,       170),
        }
    end

    return killerName, killerModel, killerBodygroups, killerAppearance
end

function Deathscreen:SendOpenFromState(ply)
    if not IsValid(ply) then return end

    local st = self:GetDeathState(ply)
    if not st then return end
    if ply._DeathClientReady ~= true then return end

    netstream.Start(ply, CFG.NET.Open,
        tonumber(st.respawnAt) or CurTime(),
        tostring(st.killerName or "Unknown"),
        tostring(st.killerModel or "models/player/kleiner.mdl"),
        st.killerBodygroups or {},
        st.killerAppearance or {}
    )
end

function Deathscreen:SendOpen(ply, attacker, inflictor)
    if not IsValid(ply) then return end

    local now = CurTime()
    local respawnAt = now + (CFG.RespawnDelay or 0)
    local killerName, killerModel, killerBodygroups, killerAppearance = BuildKillerInfo(attacker, inflictor)

    self:SetDeathState(ply, now, respawnAt, killerName, killerModel, killerBodygroups, killerAppearance)
    ply.NextSpawnTime = respawnAt
    self:SendOpenFromState(ply)

    timer.Create(("VERSE.Deathscreen.OpenRetry.%d"):format(ply:UserID()), 0.25, 40, function()
        if not IsValid(ply) then return end

        if ply:Alive() then
            timer.Remove(("VERSE.Deathscreen.OpenRetry.%d"):format(ply:UserID()))
            return
        end

        local st = Deathscreen:GetDeathState(ply)
        if not st then
            timer.Remove(("VERSE.Deathscreen.OpenRetry.%d"):format(ply:UserID()))
            return
        end

        if ply._DeathClientReady == true then
            Deathscreen:SendOpenFromState(ply)
            timer.Remove(("VERSE.Deathscreen.OpenRetry.%d"):format(ply:UserID()))
        end
    end)
end

function Deathscreen:SendClose(ply)
    if not IsValid(ply) then return end
    if ply._DeathClientReady ~= true then return end
    netstream.Start(ply, CFG.NET.Close)
end

function Deathscreen:TryRespawn(ply)
    if not IsValid(ply) then return false end
    if ply:Alive() then return false end

    local st = self:GetDeathState(ply)
    if CFG.BlockRespawnUntilTimer == true then
        if not st then return false end
        if not self:CanRespawnNow(ply) then return false end
    end

    ply.NextSpawnTime = CurTime()
    if st then st.canRespawn = true end
    ply:Spawn()
    self:SendClose(ply)
    self:ClearDeathState(ply)
    return true
end

VERSE.Hook.AddNS("Deathscreen", "PlayerDeath", "VERSE::PlayerDeath::Deathscreen", function(ply, inflictor, attacker)
    if not IsValid(ply) then return end
    Deathscreen:SendOpen(ply, attacker, inflictor)
end)

VERSE.Hook.AddNS("Deathscreen", "PlayerDeathThink", "VERSE::PlayerDeathThink::Deathscreen", function(ply)
    if CFG.BlockRespawnUntilTimer ~= true then return end
    if not IsValid(ply) then return end
    local st = Deathscreen:GetDeathState(ply)
    if not st then return end
    if Deathscreen:CanRespawnNow(ply) then
        st.canRespawn = true
        return true
    end
    return false
end)

VERSE.Hook.AddNS("Deathscreen", "PlayerSpawn", "VERSE::PlayerSpawn::Deathscreen", function(ply)
    if not IsValid(ply) then return end

    local hadDeath = Deathscreen:GetDeathState(ply) ~= nil
    if hadDeath then
        Deathscreen:SendClose(ply)
        Deathscreen:ClearDeathState(ply)
    end
end)

VERSE.Hook.AddNS("Deathscreen", "PlayerFullLoad", "VERSE::PlayerFullLoad::Deathscreen", function(ply)
    if not IsValid(ply) then return end
    ply._DeathClientReady = true
    if not ply:Alive() then Deathscreen:SendOpenFromState(ply) end
end)

VERSE.Hook.AddNS("Deathscreen", "PlayerDisconnected", "VERSE::PlayerDisconnected::Deathscreen", function(ply)
    if not IsValid(ply) then return end
    ply._DeathClientReady = nil
    timer.Remove(("VERSE.Deathscreen.OpenRetry.%d"):format(ply:UserID()))
end)

netstream.Hook(CFG.NET.Request, function(ply)
    if not IsValid(ply) then return end
    -- Cooldown 1s : empêche le spam de requêtes de respawn
    local now = CurTime()
    if (ply._lastRespawnRequest or 0) + 1 > now then return end
    ply._lastRespawnRequest = now
    Deathscreen:TryRespawn(ply)
end)