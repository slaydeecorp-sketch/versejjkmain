local Anims = VERSE.Anims
Anims.SequenceState = Anims.SequenceState or setmetatable({}, {
    __mode = "k"
})

Anims.GestureState = Anims.GestureState or setmetatable({}, {
    __mode = "k"
})

Anims._SeqCache = Anims._SeqCache or {}
local ACT_IDLE = ACT_MP_STAND_IDLE or ACT_HL2MP_IDLE or -1
local function clampRate(rate)
    rate = tonumber(rate) or 1
    if rate ~= rate or rate <= 0 then rate = 1 end
    return math.max(rate, 0.001)
end

local function clampCycle(cycle)
    cycle = tonumber(cycle) or 0
    if cycle ~= cycle then cycle = 0 end
    return math.Clamp(cycle, 0, 1)
end

local function clampSlot(slot)
    slot = tonumber(slot) or (GESTURE_SLOT_VCD or 6)
    if slot < 0 then
        return 0
    elseif slot > 255 then
        return 255
    end
    return math.floor(slot)
end

local function cacheBucket(model)
    model = tostring(model or "")
    Anims._SeqCache[model] = Anims._SeqCache[model] or {}
    return Anims._SeqCache[model]
end

local function getSequenceNameSafe(ent, seqId, original)
    if isstring(original) and original ~= "" then return original end
    if not (IsValid(ent) and ent.GetSequenceName) then return nil end
    local ok, seqName = pcall(ent.GetSequenceName, ent, seqId)
    if ok and isstring(seqName) and seqName ~= "" then return seqName end
end

local function resolveSequenceCached(ent, seq)
    if not Anims.IsValidEnt(ent) then return -1 end
    if isnumber(seq) then return math.max(math.floor(seq), 0) end
    seq = tostring(seq or "")
    if seq == "" then return -1 end
    local model = ent:GetModel() or ""
    local bucket = cacheBucket(model)
    if bucket[seq] ~= nil then return bucket[seq] end
    local seqId = Anims.ResolveSequence(ent, seq)
    bucket[seq] = seqId
    return seqId
end

local function clearSequenceState(ent, invokeFinish)
    local state = Anims.SequenceState[ent]
    if not state then return false end
    Anims.SequenceState[ent] = nil
    if IsValid(ent) and ent.SetPlaybackRate then ent:SetPlaybackRate(1) end
    if invokeFinish and state.onFinish then
        local ok, err = pcall(state.onFinish, ent, state)
        if not ok then ErrorNoHalt(tostring(err) .. "\n") end
    end
    return true
end

local function clearGestureSlot(ent, slot)
    slot = clampSlot(slot)
    local slots = Anims.GestureState[ent]
    if not slots then return false end
    if ent.AnimResetGestureSlot then ent:AnimResetGestureSlot(slot) end
    slots[slot] = nil
    if next(slots) == nil then Anims.GestureState[ent] = nil end
    return true
end

local function clearAllGestureState(ent)
    local slots = Anims.GestureState[ent]
    if not slots then return end
    local pending = {}
    for slot in pairs(slots) do
        pending[#pending + 1] = slot
    end

    for _, slot in ipairs(pending) do
        clearGestureSlot(ent, slot)
    end

    Anims.GestureState[ent] = nil
end

local function playSequence(ent, seq, opts)
    local seqId = resolveSequenceCached(ent, seq)
    if seqId < 0 then return false end
    opts = Anims.MergeOpts(opts)
    local rate = clampRate(opts.rate)
    local loop = opts.loop ~= false
    local startCycle = clampCycle(opts.startCycle)
    local baseDuration = Anims.SeqDuration(ent, seqId)
    local state = {
        seqId = seqId,
        seqName = getSequenceNameSafe(ent, seqId, seq),
        rate = rate,
        loop = loop,
        startCycle = startCycle,
        startedAt = CurTime(),
        baseDuration = baseDuration,
        onFinish = opts.onFinish,
        transition = tonumber(opts.transition) or 0,
        boneBlend = opts.boneBlend == true,
        model = ent:GetModel() or "",
    }

    state.startedAt = state.startedAt - ((baseDuration * startCycle) / rate)
    Anims.SequenceState[ent] = state
    if ent.ResetSequence then ent:ResetSequence(seqId) end
    if ent.ResetSequenceInfo then ent:ResetSequenceInfo() end
    if ent.SetCycle then ent:SetCycle(startCycle) end
    if ent.SetPlaybackRate then ent:SetPlaybackRate(rate) end
    return true, seqId
end

local function playGesture(ent, seq, opts)
    local seqId = resolveSequenceCached(ent, seq)
    if seqId < 0 then return false end
    opts = Anims.MergeOpts(opts)
    local slot = clampSlot(opts.slot)
    local rate = clampRate(opts.rate)
    local startCycle = clampCycle(opts.startCycle)
    local weight = tonumber(opts.weight) or 1
    if weight ~= weight or weight < 0 then weight = 0 end
    local slots = Anims.GestureState[ent]
    if not slots then
        slots = {}
        Anims.GestureState[ent] = slots
    end

    if not opts.norestart then clearGestureSlot(ent, slot) end
    local layer
    if ent.AddVCDSequenceToGestureSlot then layer = ent:AddVCDSequenceToGestureSlot(slot, seqId, startCycle, opts.loop ~= true) end
    slots[slot] = {
        slot = slot,
        seqId = seqId,
        seqName = getSequenceNameSafe(ent, seqId, seq),
        layer = layer,
        rate = rate,
        weight = weight,
        targetWeight = weight,
        fadeLeft = 0.08,
        loop = opts.loop == true,
        killWhenFaded = false,
        endAt = tonumber(opts.duration) and (CurTime() + math.max(tonumber(opts.duration) or 0, 0.01)) or nil,
    }
    return true, seqId
end

function Anims.GetSequenceState(ent)
    return Anims.SequenceState[ent]
end

function Anims.GetGestureState(ent, slot)
    local slots = Anims.GestureState[ent]
    if not slots then return nil end
    if slot == nil then return slots end
    return slots[clampSlot(slot)]
end

function Anims.IsPlaying(ent, seq)
    local state = Anims.GetSequenceState(ent)
    if not state then return false end
    if isnumber(seq) then return state.seqId == math.max(math.floor(seq), 0) end
    seq = string.lower(tostring(seq or ""))
    return seq ~= "" and string.lower(state.seqName or "") == seq
end

function Anims.Play(ent, seq, opts)
    if not Anims.IsValidEnt(ent) then return false end
    opts = Anims.MergeOpts(opts)
    if opts.slot ~= nil then return playGesture(ent, seq, opts) end
    return playSequence(ent, seq, opts)
end

function Anims.Stop(ent, opts)
    if not Anims.IsValidEnt(ent) then return false end
    opts = opts or {}
    if opts.slot ~= nil then return clearGestureSlot(ent, opts.slot) end
    clearAllGestureState(ent)
    return clearSequenceState(ent, false)
end

function Anims.Tune(ent, slot, rate, weight, durLeft, kill)
    if not Anims.IsValidEnt(ent) then return false end
    local state = Anims.GetGestureState(ent, slot)
    if not state then return false end
    state.rate = clampRate(rate or state.rate)
    weight = tonumber(weight)
    if weight ~= nil and weight == weight then state.targetWeight = math.max(weight, 0) end
    durLeft = tonumber(durLeft) or 0.05
    if durLeft ~= durLeft or durLeft <= 0 then durLeft = 0.05 end
    state.fadeLeft = math.max(durLeft, 0.01)
    if kill == true then
        state.killWhenFaded = true
        state.targetWeight = 0
        state.endAt = CurTime() + state.fadeLeft
    end
    return true
end

local function updateSequenceState(ply, now)
    local state = Anims.SequenceState[ply]
    if not state then return false end
    if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) or ply:InVehicle() then
        clearSequenceState(ply, false)
        return false
    end

    local model = ply:GetModel() or ""
    if state.model ~= model and state.seqName then
        local seqId = resolveSequenceCached(ply, state.seqName)
        if seqId < 0 then
            clearSequenceState(ply, false)
            return false
        end

        state.seqId = seqId
        state.baseDuration = Anims.SeqDuration(ply, seqId)
        state.model = model
        if ply.ResetSequence then ply:ResetSequence(seqId) end
    end

    local baseDuration = math.max(state.baseDuration or 0.1, 0.1)
    local cycle = state.startCycle + ((now - state.startedAt) * state.rate / baseDuration)
    if state.loop then
        cycle = cycle % 1
    elseif cycle >= 1 then
        clearSequenceState(ply, true)
        return false
    end

    cycle = math.Clamp(cycle, 0, 0.999)
    if ply.SetPlaybackRate then ply:SetPlaybackRate(state.rate) end
    if ply.SetCycle then ply:SetCycle(cycle) end
    return true
end

local function updateGestureState(ply, now, frameTime)
    local slots = Anims.GestureState[ply]
    if not slots then return false end
    local handled = false
    local toClear = {}
    for slot, state in pairs(slots) do
        handled = true
        local fadeFrac = math.Clamp(frameTime / math.max(state.fadeLeft or 0.05, 0.01), 0, 1)
        state.weight = Lerp(fadeFrac, state.weight or 0, state.targetWeight or 0)
        if state.layer ~= nil then
            if ply.SetLayerPlaybackRate then pcall(ply.SetLayerPlaybackRate, ply, state.layer, state.rate or 1) end
            if ply.SetLayerWeight then pcall(ply.SetLayerWeight, ply, state.layer, state.weight or 0) end
        end

        if state.endAt and now >= state.endAt then
            toClear[#toClear + 1] = slot
        elseif state.killWhenFaded and (state.weight or 0) <= 0.02 then
            toClear[#toClear + 1] = slot
        end
    end

    for _, slot in ipairs(toClear) do
        clearGestureSlot(ply, slot)
    end
    return handled
end

VERSE.Hook.AddNS("Animations", "CalcMainActivity", "VERSE::CalcMainActivity::Animations", function(ply)
    local state = Anims.SequenceState[ply]
    if not state then return end
    if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) or ply:InVehicle() then
        clearSequenceState(ply, false)
        return
    end

    if ply.SetPlaybackRate then ply:SetPlaybackRate(state.rate or 1) end
    return ACT_IDLE, state.seqId
end, {
    priority = 100
})

VERSE.Hook.AddNS("Animations", "UpdateAnimation", "VERSE::UpdateAnimation::Animations", function(ply)
    local now = CurTime()
    local seqHandled = updateSequenceState(ply, now)
    local gestureHandled = updateGestureState(ply, now, FrameTime())
    if seqHandled or gestureHandled then return true end
end, {
    priority = 100
})

VERSE.Hook.AddNS("Animations", "EntityRemoved", "VERSE::EntityRemoved::Animations", function(ent)
    clearSequenceState(ent, false)
    clearAllGestureState(ent)
end)

netstream.Hook(Anims.Net.Play, function(ent, isGesture, isId, seq, rate, a, b, c, d)
    if not IsValid(ent) then return end
    local resolvedSeq = seq
    if isId == true then
        resolvedSeq = tonumber(seq) or 0
    else
        resolvedSeq = tostring(seq or "")
    end

    rate = tonumber(rate) or 1
    if isGesture == true then
        local slot = tonumber(a) or (GESTURE_SLOT_VCD or 6)
        local weight = tonumber(b) or 1
        local dur = tonumber(c) or 1
        local norestart = d == true
        Anims.Play(ent, resolvedSeq, {
            slot = slot,
            rate = rate,
            weight = weight,
            duration = dur,
            norestart = norestart,
        })
    else
        local loop = a == true
        local startCycle = tonumber(b) or 0
        local transition = tonumber(c) or 0
        local boneBlend = d == true
        Anims.Play(ent, resolvedSeq, {
            rate = rate,
            loop = loop,
            startCycle = startCycle,
            transition = transition,
            boneBlend = boneBlend,
        })
    end
end)

netstream.Hook(Anims.Net.Stop, function(ent, isGesture, slot)
    if not IsValid(ent) then return end
    if isGesture == true then
        Anims.Stop(ent, {
            slot = tonumber(slot) or (GESTURE_SLOT_VCD or 6)
        })
    else
        Anims.Stop(ent)
    end
end)

netstream.Hook(Anims.Net.Tune, function(ent, slot, rate, w, dl, kill)
    if not (IsValid(ent) and ent:IsPlayer()) then return end
    slot = tonumber(slot) or (GESTURE_SLOT_VCD or 6)
    rate = tonumber(rate) or 1
    w = tonumber(w) or 0
    dl = tonumber(dl) or 0.05
    kill = kill == true
    Anims.Tune(ent, slot, rate, w, dl, kill)
end)