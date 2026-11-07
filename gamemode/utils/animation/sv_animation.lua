local Anims = VERSE.Anims

local function normalizeTargets(targets)
    if targets == nil then return nil end
    if istable(targets) then
        local out = {}
        for _, p in ipairs(targets) do
            if IsValid(p) and p:IsPlayer() then out[#out + 1] = p end
        end
        return (#out > 0) and out or nil
    end

    if IsValid(targets) and targets:IsPlayer() then return targets end
    return nil
end

function Anims.NetPlay(ent, seq, opts, targets)
    if not IsValid(ent) then return end
    if not isstring(seq) and not isnumber(seq) then return end
    opts = Anims.MergeOpts(opts)
    opts.onFinish = nil
    local isId = isnumber(seq)
    local isGesture = opts.slot ~= nil
    local rate = tonumber(opts.rate) or 1
    if isGesture then
        local slot = tonumber(opts.slot) or (GESTURE_SLOT_VCD or 6)
        if slot < 0 then
            slot = 0
        elseif slot > 255 then
            slot = 255
        end

        local weight = tonumber(opts.weight) or 1
        if weight ~= weight or weight < 0 then weight = 0 end
        local dur = tonumber(opts.duration)
        if not dur or dur ~= dur or dur <= 0 then dur = Anims.DurationAnimation(ent, seq, rate) end
        local norestart = opts.norestart == true
        netstream.Start(normalizeTargets(targets), Anims.Net.Play, ent, true, isId, isId and math.max(seq, 0) or tostring(seq), rate, slot, weight, dur, norestart)
    else
        local loop = not not opts.loop
        local startCycle = tonumber(opts.startCycle) or 0
        local transition = tonumber(opts.transition) or 0
        local boneBlend = opts.boneBlend == true
        netstream.Start(normalizeTargets(targets), Anims.Net.Play, ent, false, isId, isId and math.max(seq, 0) or tostring(seq), rate, loop, startCycle, transition, boneBlend)
    end
end

function Anims.NetStop(ent, opts, targets)
    if not IsValid(ent) then return end
    opts = opts or {}
    local isGesture = opts.slot ~= nil
    if isGesture then
        local slot = tonumber(opts.slot) or (GESTURE_SLOT_VCD or 6)
        if slot < 0 then
            slot = 0
        elseif slot > 255 then
            slot = 255
        end

        netstream.Start(normalizeTargets(targets), Anims.Net.Stop, ent, true, slot)
    else
        netstream.Start(normalizeTargets(targets), Anims.Net.Stop, ent, false)
    end
end

function Anims.NetTune(ent, slot, rate, weight, durLeft, kill, targets)
    if not (IsValid(ent) and ent:IsPlayer()) then return end
    slot = tonumber(slot) or (GESTURE_SLOT_VCD or 6)
    if slot < 0 then
        slot = 0
    elseif slot > 255 then
        slot = 255
    end

    rate = tonumber(rate) or 1
    weight = tonumber(weight) or 0
    durLeft = tonumber(durLeft) or 0.05
    netstream.Start(normalizeTargets(targets), Anims.Net.Tune, ent, slot, rate, weight, durLeft, kill == true)
end

local meta = FindMetaTable("Player")
function meta:PlayAnimation(seq, opts, targets)
    Anims.NetPlay(self, seq, opts, targets)
end

function meta:StopAnimation(opts, targets)
    Anims.NetStop(self, opts, targets)
end

function meta:TuneAnimation(slot, rate, weight, durLeft, kill, targets)
    Anims.NetTune(self, slot, rate, weight, durLeft, kill, targets)
end