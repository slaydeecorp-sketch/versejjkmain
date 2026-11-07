local Animations = VERSE.Animations
local Anims = VERSE.Anims
Animations.Active = Animations.Active or {}
local nextPlayAt = {}
local nextStopAt = {}
local CANCEL_MASK = bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_JUMP, IN_DUCK, IN_SPEED, IN_WALK, IN_USE, IN_ATTACK, IN_ATTACK2, IN_RELOAD)
local function canUse(map, ply, delay)
    delay = tonumber(delay) or 0
    local now = CurTime()
    local nextAt = map[ply] or 0
    if now < nextAt then return false end
    map[ply] = now + math.max(delay, 0)
    return true
end

local function getActiveState(ply)
    if not IsValid(ply) then return nil end
    local active = Animations.Active[ply]
    if active and active.finishAt and CurTime() >= active.finishAt then
        Animations.Active[ply] = nil
        return nil
    end
    return active
end

function Animations.IsPlaying(ply)
    return getActiveState(ply) ~= nil
end

function Animations.StopPlayer(ply, silent)
    if not IsValid(ply) then return false end
    local hadActive = Animations.Active[ply] ~= nil
    Animations.Active[ply] = nil
    if hadActive and silent ~= true then ply:StopAnimation() end
    return hadActive
end

function Animations.StartPlayer(ply, sequence)
    if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) then return false end
    if ply:InVehicle() then return false end
    sequence = Animations.SanitizeSequenceName(sequence)
    if not sequence then return false end
    local entry = Animations.GetConfiguredEntry(sequence)
    if not entry then return false, "not_configured" end
    local loop = entry.loop == true
    local rate = tonumber(entry.rate) or 1
    local active = getActiveState(ply)
    if active and active.sequence == sequence then
        Animations.StopPlayer(ply)
        return false, "toggled_off"
    end

    if active then Animations.StopPlayer(ply) end
    Animations.Active[ply] = {
        sequence = entry.sequence,
        loop = loop,
        rate = rate,
        startedAt = CurTime(),
        finishAt = (loop ~= true and Anims and Anims.DurationAnimation and (CurTime() + Anims.DurationAnimation(ply, entry.sequence, rate))) or nil,
    }

    ply:PlayAnimation(entry.sequence, {
        loop = loop,
        rate = rate,
    })
    return true
end

netstream.Hook(Animations.Net.RequestPlay, function(ply, sequence)
    if not IsValid(ply) then return end
    if not canUse(nextPlayAt, ply, Animations.Config.RequestCooldown) then return end
    Animations.StartPlayer(ply, sequence)
end)

netstream.Hook(Animations.Net.RequestStop, function(ply)
    if not IsValid(ply) then return end
    if not canUse(nextStopAt, ply, Animations.Config.StopCooldown) then return end
    Animations.StopPlayer(ply)
end)

VERSE.Hook.AddNS("Animations", "StartCommand", "VERSE::StartCommand::Animations", function(ply, cmd)
    if not Animations.IsPlaying(ply) then return end
    if not (IsValid(ply) and ply:Alive()) or ply:InVehicle() then
        Animations.StopPlayer(ply)
        return
    end

    local buttons = cmd:GetButtons()
    if bit.band(buttons, CANCEL_MASK) ~= 0 then
        Animations.StopPlayer(ply)
        return
    end

    if math.abs(cmd:GetForwardMove()) > 0 or math.abs(cmd:GetSideMove()) > 0 or math.abs(cmd:GetUpMove()) > 0 then Animations.StopPlayer(ply) end
end)

VERSE.Hook.AddNS("Animations", "Think", "VERSE::Think::Animations", function()
    for ply, active in pairs(Animations.Active) do
        if not IsValid(ply) then
            Animations.Active[ply] = nil
        elseif active.finishAt and CurTime() >= active.finishAt then
            Animations.Active[ply] = nil
        end
    end
end)

VERSE.Hook.AddNS("Animations", "PlayerDisconnected", "VERSE::PlayerDisconnected::Animations", function(ply)
    Animations.Active[ply] = nil
    nextPlayAt[ply] = nil
    nextStopAt[ply] = nil
end)

VERSE.Hook.AddNS("Animations", "PlayerDeath", "VERSE::PlayerDeath::Animations", function(ply) Animations.StopPlayer(ply) end)
VERSE.Hook.AddNS("Animations", "PlayerSilentDeath", "VERSE::PlayerSilentDeath::Animations", function(ply) Animations.StopPlayer(ply) end)
VERSE.Hook.AddNS("Animations", "PlayerSpawn", "VERSE::PlayerSpawn::Animations", function(ply) if Animations.IsPlaying(ply) then Animations.StopPlayer(ply) end end)
VERSE.Hook.AddNS("Animations", "PlayerSwitchWeapon", "VERSE::PlayerSwitchWeapon::Animations", function(ply) if Animations.IsPlaying(ply) then Animations.StopPlayer(ply) end end)
VERSE.Hook.AddNS("Animations", "VERSE::Combat::PostDamage", "VERSE::Combat::PostDamage::Animations", function(target) if IsValid(target) and target:IsPlayer() and Animations.IsPlaying(target) then Animations.StopPlayer(target) end end)
VERSE.Commands.Add("verse_animations_stop", function(ply)
    if not IsValid(ply) then return end
    Animations.StopPlayer(ply)
end)