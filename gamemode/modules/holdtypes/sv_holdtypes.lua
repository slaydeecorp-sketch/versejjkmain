local Holdtypes = VERSE.HoldTypes

util.AddNetworkString(Holdtypes.NetLand)
util.AddNetworkString(Holdtypes.NetForce)

local LAND_LOCK = 0.12
local function getHoldForWeapon(ply, wep)
    local holdKey = wep:GetHoldType()
    if ply._VerseHoldKey ~= holdKey then
        ply._VerseHoldKey = holdKey
        ply._VerseHold = Holdtypes[holdKey]
    end
    return ply._VerseHold
end

local function recipientsPVSWithOwner(ply)
    local recips = RecipientFilter()
    recips:AddPVS(ply:GetPos())
    recips:AddPlayer(ply)
    return recips
end

local function sendLandEvent(ply, stamp)
    if not IsValid(ply) then return end
    net.Start(Holdtypes.NetLand)
    net.WriteEntity(ply)
    net.WriteFloat(stamp)
    net.Send(recipientsPVSWithOwner(ply))
end

function Holdtypes:ForceState(ply, state, duration, rateOrNil, reasonOrNil)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not isnumber(state) then return end
    duration = tonumber(duration) or 0
    if duration <= 0 then return self:ClearForce(ply) end
    local untilTime = CurTime() + duration
    ply._VerseForcedState = state
    ply._VerseForcedUntil = untilTime
    ply._VerseForcedRate = (rateOrNil ~= nil) and tonumber(rateOrNil) or nil
    net.Start(self.NetForce)
    net.WriteEntity(ply)
    net.WriteBool(true)
    net.WriteUInt(math.Clamp(state, 0, 15), 4)
    net.WriteFloat(untilTime)
    net.WriteBool(ply._VerseForcedRate ~= nil)
    if ply._VerseForcedRate ~= nil then net.WriteFloat(ply._VerseForcedRate) end
    net.Send(recipientsPVSWithOwner(ply))
    VERSE.Hook.Run("VERSE::HoldTypes::Forced", ply, state, untilTime, ply._VerseForcedRate, reasonOrNil)
end

function Holdtypes:ClearForce(ply, reasonOrNil)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    ply._VerseForcedState = nil
    ply._VerseForcedUntil = nil
    ply._VerseForcedRate = nil
    net.Start(self.NetForce)
    net.WriteEntity(ply)
    net.WriteBool(false)
    net.Send(recipientsPVSWithOwner(ply))
    VERSE.Hook.Run("VERSE::HoldTypes::ForceCleared", ply, reasonOrNil)
end

VERSE.Hook.AddNS("Holdtypes", "PlayerDisconnected", "VERSE::PlayerDisconnected::Holdtypes", function(ply)
    if not IsValid(ply) then return end
    ply._VerseForcedState = nil
    ply._VerseForcedUntil = nil
    ply._VerseForcedRate = nil
end)

VERSE.Hook.AddNS("Holdtypes", "Tick", "VERSE::Tick::HoldTypes", function()
    for _, ply in ipairs(player.GetHumans()) do
        if not IsValid(ply) then continue end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then
            ply._VerseHoldKey = nil
            ply._VerseHold = nil
            ply._WasAir = nil
            ply._LastLand = nil
            continue
        end

        local hold = getHoldForWeapon(ply, wep)
        if not hold then
            ply._WasAir = nil
            ply._LastLand = nil
            continue
        end

        local onGround = ply:IsOnGround()
        local wasAir = ply._WasAir or false
        local now = CurTime()
        local justLand = wasAir and onGround and (now - (ply._LastLand or 0) > LAND_LOCK)
        if justLand then
            ply._LastLand = now
            sendLandEvent(ply, now)
        end

        ply._WasAir = not onGround
    end
end)

VERSE.Hook.AddNS("Holdtypes", "Initialize", "VERSE::Initialize::Holdtypes", function()
    for _, ht in pairs(Holdtypes) do
        if istable(ht) and ht.Translations then ht.Translations = nil end
    end
end)