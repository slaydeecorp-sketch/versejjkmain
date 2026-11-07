local Holdtypes = VERSE.HoldTypes

local LAND_LOCK_LOCAL = 0.12
local LAND_DEDUP = 0.40
local SUPPRESS_NET_AFTER_LOCAL = 0.50
local LAND_MIN_TIME = 0.10
local LAND_MAX_TIME = 0.70
local LAND_CANCEL_IF_AIR = true
local LAND_INTERRUPT_ON_MOVE = true
local LAND_INTERRUPT_MIN = 0.12

Holdtypes._SeqCache = Holdtypes._SeqCache or {}

local function lookupSeqCached(ply, seqName)
    if not (IsValid(ply) and isstring(seqName) and seqName ~= "") then return -1 end
    local mdl = ply:GetModel() or ""
    if mdl == "" then return ply:LookupSequence(seqName) end

    local byModel = Holdtypes._SeqCache[mdl]
    if not byModel then
        byModel = {}
        Holdtypes._SeqCache[mdl] = byModel
    end

    local cached = byModel[seqName]
    if cached ~= nil then return cached end

    local seq = ply:LookupSequence(seqName)
    byModel[seqName] = seq or -1
    return byModel[seqName]
end

local function calcStartCycle(ply, seqId, data)
    if not (IsValid(ply) and isnumber(seqId) and seqId >= 0 and istable(data)) then return 0 end

    if data.StartCycle ~= nil then
        local c = tonumber(data.StartCycle) or 0
        return math.Clamp(c, 0, 1)
    end

    if data.StartTime ~= nil then
        local t = tonumber(data.StartTime) or 0
        if t <= 0 then return 0 end

        local dur = 0
        if ply.SequenceDuration then
            dur = tonumber(ply:SequenceDuration(seqId)) or 0
        end
        if dur <= 0 then return 0 end

        return math.Clamp(t / dur, 0, 1)
    end

    return 0
end

local function pickDeterministicWeighted(ply, state, list)
    if #list == 1 then return list[1] end
    local total = 0
    for i = 1, #list do
        local w = tonumber(list[i] and list[i].Weight) or 1
        if w > 0 then total = total + w end
    end

    if total <= 0 then
        local idx = math.floor(util.SharedRandom("VERSE_hold_pick", 1, #list + 1, ply:EntIndex() + state))
        return list[idx]
    end

    local r = util.SharedRandom("VERSE_hold_pick_w", 0, total, ply:EntIndex() + state)
    local acc = 0
    for i = 1, #list do
        local w = tonumber(list[i] and list[i].Weight) or 1
        if w > 0 then
            acc = acc + w
            if r <= acc then return list[i] end
        end
    end
    return list[#list]
end

local function normalizeEntry(entry)
    if not entry then return end

    if isstring(entry) then
        return {
            Sequence = entry,
            Weight = 1,
            Rate = 1,
            StartTime = nil,
            StartCycle = nil
        }
    end

    if istable(entry) then
        if entry.Sequence then
            entry.Weight = (entry.Weight ~= nil) and entry.Weight or 1
            entry.Rate = (entry.Rate ~= nil) and entry.Rate or 1
            return entry
        end
        return entry
    end
end

function VERSE.HoldTypeMeta:GetActDataByState(state, ply, _depth)
    _depth = _depth or 0
    if _depth > 3 then return end

    local entry = normalizeEntry(self.Translations and self.Translations[state])
    if entry then
        if entry.Sequence then return entry end
        local picked = pickDeterministicWeighted(ply, state, entry)
        return normalizeEntry(picked)
    end

    local baseKey = self:GetBaseHoldType()
    if baseKey and baseKey ~= self.HoldType then
        local base = Holdtypes[baseKey]
        if base and base.GetActDataByState then
            return base:GetActDataByState(state, ply, _depth + 1)
        end
    end
end

local function hardResetBaseAnim(ply)
    ply._LastBaseState = nil
    ply._LastBaseSeq = nil
    ply._LastHoldKey = nil
    ply._HT_ActiveSeq = nil
    ply._HT_ActiveStartCycle = nil
    ply._HT_LastCycle = nil
    ply._HT_LoopArmed = nil
end

local function beginLandState(ply, hold, stamp, sourceTag)
    local landData = hold:GetActDataByState(Holdtypes.State.LAND, ply)
    if not (landData and landData.Sequence) then return end

    local seq = lookupSeqCached(ply, landData.Sequence)
    if not (seq and seq >= 0) then return end

    local rate = tonumber(landData.Rate) or 1
    if rate <= 0 then rate = 1 end

    local dur = 0
    if ply.SequenceDuration then
        dur = tonumber(ply:SequenceDuration(seq)) or 0
    end

    local t = (dur > 0) and (dur / rate) or 0.25
    t = math.Clamp(t, LAND_MIN_TIME, LAND_MAX_TIME)

    local now = CurTime()
    ply._HT_LandUntil = now + t
    ply._HT_LandSeq = seq
    ply._HT_LandRate = rate
    ply._HT_LandStamp = stamp
    ply._HT_LandSource = sourceTag
    ply._HT_LandBeganAt = now
end

local function maybePlayLand(ply, hold, stamp, sourceTag)
    local now = CurTime()

    local lastPlayedAt = ply._LandPlayedAt or -1
    if lastPlayedAt > 0 and (now - lastPlayedAt) <= LAND_DEDUP then
        if sourceTag == "net" then ply._lastSyncedLandAt = stamp end
        return
    end

    if sourceTag == "net" and ply._LocalLandAt and (now - ply._LocalLandAt) <= SUPPRESS_NET_AFTER_LOCAL then
        ply._lastSyncedLandAt = stamp
        return
    end

    local lastStamp = ply._LandStamp or -1
    if lastStamp > 0 and math.abs(stamp - lastStamp) <= LAND_DEDUP then
        if sourceTag == "net" then ply._lastSyncedLandAt = stamp end
        return
    end

    beginLandState(ply, hold, stamp, sourceTag)

    ply._LandPlayedAt = now
    ply._LandStamp = stamp

    if sourceTag == "local" then
        ply._LocalLandAt = now
    elseif sourceTag == "net" then
        ply._lastSyncedLandAt = stamp
    end
end

local function isForceActive(ply, now)
    if not IsValid(ply) then return false end
    local untilTime = ply._VerseForcedUntil
    if not untilTime or untilTime <= 0 then return false end
    return now < untilTime
end

function Holdtypes:ForceLocalState(state, duration, rateOrNil)
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    duration = tonumber(duration) or 0
    if duration <= 0 then return self:ClearLocalForce() end
    lp._VerseForcedState = tonumber(state) or self.State.IDLE
    lp._VerseForcedUntil = CurTime() + duration
    lp._VerseForcedRate = (rateOrNil ~= nil) and tonumber(rateOrNil) or nil
end

function Holdtypes:ClearLocalForce()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    lp._VerseForcedState = nil
    lp._VerseForcedUntil = nil
    lp._VerseForcedRate = nil
end

local function resolveStateAndRate(ply, baseState, baseRate)
    local now = CurTime()
    if isForceActive(ply, now) then
        local st = ply._VerseForcedState or baseState
        local rt = (ply._VerseForcedRate ~= nil) and ply._VerseForcedRate or baseRate
        return st, rt
    end
    return baseState, baseRate
end

net.Receive(Holdtypes.NetLand, function()
    local ply = net.ReadEntity()
    local stamp = net.ReadFloat()
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end
    local hold = Holdtypes[wep:GetHoldType()]
    if not hold then return end
    maybePlayLand(ply, hold, stamp, "net")
end)

net.Receive(Holdtypes.NetForce, function()
    local ply = net.ReadEntity()
    local enabled = net.ReadBool()
    if not IsValid(ply) or not ply:IsPlayer() then return end

    if not enabled then
        ply._VerseForcedState = nil
        ply._VerseForcedUntil = nil
        ply._VerseForcedRate = nil
        return
    end

    local st = net.ReadUInt(4)
    local untilTime = net.ReadFloat()
    local hasRate = net.ReadBool()
    local rate = nil
    if hasRate then rate = net.ReadFloat() end

    ply._VerseForcedState = st
    ply._VerseForcedUntil = untilTime
    ply._VerseForcedRate = rate
end)

VERSE.Hook.AddNS("Holdtypes", "CalcMainActivity", "VERSE::CalcMainActivity::Holdtypes", function(ply, vel)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end

    local holdKey = wep:GetHoldType()
    local hold = Holdtypes[holdKey]
    if not hold then return end

    local now = CurTime()
    local onGround = ply:IsOnGround()
    local wasAir = ply._WasAir or false
    if wasAir and onGround and (now - (ply._LastLand or 0) > LAND_LOCK_LOCAL) then
        ply._LastLand = now
        maybePlayLand(ply, hold, now, "local")
    end
    ply._WasAir = not onGround

    local now2 = CurTime()
    if ply._HT_LandUntil and now2 < ply._HT_LandUntil then
        if LAND_CANCEL_IF_AIR and not ply:IsOnGround() then
            ply._HT_LandUntil = nil
            ply._HT_LandSeq = nil
            ply._HT_LandRate = nil
            hardResetBaseAnim(ply)
        else
            if LAND_INTERRUPT_ON_MOVE then
                local landAge = (ply._HT_LandBeganAt and (now2 - ply._HT_LandBeganAt)) or 0
                if landAge >= LAND_INTERRUPT_MIN then
                    local wantsMove = ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT) or ply:KeyDown(IN_SPEED)
                    local wantsDuck = ply:KeyDown(IN_DUCK)
                    if wantsMove or wantsDuck then
                        ply._HT_LandUntil = nil
                        ply._HT_LandSeq = nil
                        ply._HT_LandRate = nil
                        hardResetBaseAnim(ply)
                    end
                end
            end

            if ply._HT_LandUntil and now2 < ply._HT_LandUntil then
                local baseState = Holdtypes.State.LAND
                local state, rate = resolveStateAndRate(ply, baseState, ply._HT_LandRate or 1)

                local data = hold:GetActDataByState(state, ply)
                if not (data and data.Sequence) then
                    ply._HT_LandUntil = nil
                    ply._HT_LandSeq = nil
                    ply._HT_LandRate = nil
                    hardResetBaseAnim(ply)
                else
                    local seq = ply._HT_LandSeq
                    if not (seq and seq >= 0) then
                        seq = lookupSeqCached(ply, data.Sequence)
                    end
                    if seq and seq >= 0 then
                        if ply._LastBaseState ~= state or ply._LastBaseSeq ~= seq or ply._LastHoldKey ~= holdKey then
                            ply._HT_ActiveSeq = seq
                            ply._HT_ActiveStartCycle = 0
                            if ply.ResetSequence then ply:ResetSequence(seq) end
                            if ply.SetCycle then ply:SetCycle(0) end
                            ply._HT_LastCycle = nil
                            ply._HT_LoopArmed = nil
                            ply._LastBaseState = state
                            ply._LastBaseSeq = seq
                            ply._LastHoldKey = holdKey
                        else
                            ply._HT_ActiveSeq = seq
                            ply._HT_ActiveStartCycle = 0
                        end

                        local finalRate = (tonumber(data.Rate) or 1) * (tonumber(rate) or 1)
                        ply:SetPlaybackRate(finalRate)

                        local act = Holdtypes.StateToAct[state] or ACT_MP_STAND_IDLE
                        return act, seq
                    end
                end
            end
        end
    end

    local baseState = Holdtypes:DecideMoveState(ply)
    local state, rate = resolveStateAndRate(ply, baseState, 1)

    local data = hold:GetActDataByState(state, ply)
    if not (data and data.Sequence) then return end

    local seq = lookupSeqCached(ply, data.Sequence)
    if not (seq and seq >= 0) then return end

    if ply._LastBaseState ~= state or ply._LastBaseSeq ~= seq or ply._LastHoldKey ~= holdKey then
        local startCycle = calcStartCycle(ply, seq, data)
        ply._HT_ActiveSeq = seq
        ply._HT_ActiveStartCycle = startCycle
        if ply.ResetSequence then ply:ResetSequence(seq) end
        if ply.SetCycle then ply:SetCycle(startCycle) end
        ply._HT_LastCycle = nil
        ply._HT_LoopArmed = nil
        ply._LastBaseState = state
        ply._LastBaseSeq = seq
        ply._LastHoldKey = holdKey
    else
        ply._HT_ActiveSeq = seq
        ply._HT_ActiveStartCycle = calcStartCycle(ply, seq, data)
    end

    local finalRate = (tonumber(data.Rate) or 1) * (tonumber(rate) or 1)
    ply:SetPlaybackRate(finalRate)

    local act = Holdtypes.StateToAct[state] or ACT_MP_STAND_IDLE
    return act, seq
end)

VERSE.Hook.AddNS("Holdtypes", "UpdateAnimation", "VERSE::UpdateAnimation::Holdtypes", function(ply, vel, maxseqgroundspeed)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end
    local hold = Holdtypes[wep:GetHoldType()]
    if not hold then return end

    local now = CurTime()
    if ply._HT_LandUntil and now >= ply._HT_LandUntil then
        ply._HT_LandUntil = nil
        ply._HT_LandSeq = nil
        ply._HT_LandRate = nil
        ply._HT_LandBeganAt = nil
    end

    local baseState = Holdtypes:DecideMoveState(ply)
    local state, rate = resolveStateAndRate(ply, baseState, 1)
    local data = hold:GetActDataByState(state, ply)

    if data then
        local finalRate = (tonumber(data.Rate) or 1) * (tonumber(rate) or 1)
        ply:SetPlaybackRate(finalRate)

        if ply.GetCycle and ply.SetCycle then
            local startCycle = ply._HT_ActiveStartCycle
            local activeSeq = ply._HT_ActiveSeq
            if startCycle and startCycle > 0 and startCycle < 0.95 and activeSeq ~= nil then
                local c = ply:GetCycle()
                local last = ply._HT_LastCycle

                if last ~= nil and (not ply._HT_LoopArmed) and c > 0.92 then
                    ply._HT_LoopArmed = true
                end

                if ply._HT_LoopArmed and c > 0.985 then
                    ply:SetCycle(startCycle)
                    ply._HT_LoopArmed = false
                    ply._HT_LastCycle = startCycle
                    return true
                end

                if ply._HT_LoopArmed and c < 0.50 then
                    ply._HT_LoopArmed = false
                end

                ply._HT_LastCycle = c
            else
                ply._HT_LastCycle = nil
                ply._HT_LoopArmed = nil
            end
        end

        return true
    end
end)