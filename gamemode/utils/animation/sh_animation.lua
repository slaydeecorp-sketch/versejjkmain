VERSE.Anims = VERSE.Anims or {}
local Anims = VERSE.Anims

Anims.Net = {
    Play = "VERSE::Anims::Play",
    Stop = "VERSE::Anims::Stop",
    Tune = "VERSE::Anims::Tune",
}

Anims.Defaults = {
    rate = 1,
    loop = true,
    startCycle = 0,
    transition = 0.18,
    boneBlend = false,
    slot = nil,
    weight = 1,
    duration = nil,
    norestart = false,
}

function Anims.IsValidEnt(ent)
    return IsValid(ent) and ent.GetSequence and ent.LookupSequence
end

function Anims.IsValidPly(ply)
    return IsValid(ply) and ply:IsPlayer()
end

function Anims.MergeOpts(opts)
    opts = opts or {}
    local out = {}
    for k, v in pairs(Anims.Defaults) do out[k] = v end
    for k, v in pairs(opts) do out[k] = v end
    return out
end

function Anims.ResolveSequence(ent, seq)
    if not Anims.IsValidEnt(ent) then return -1 end
    if isnumber(seq) then return math.max(math.floor(seq), 0) end
    if not isstring(seq) or seq == "" then return -1 end
    local id = ent:LookupSequence(seq)
    if not id or id < 0 then return -1 end
    return id
end

function Anims.SeqDuration(ent, seqId)
    if not IsValid(ent) or not seqId or seqId < 0 then return 0.1 end
    local d = ent:SequenceDuration(seqId)
    if not d or d <= 0 then return 0.1 end
    return d
end

function Anims.DurationAnimation(ent, seq, rate)
    local seqId = Anims.ResolveSequence(ent, seq)
    if seqId < 0 then return 1 end
    local base = Anims.SeqDuration(ent, seqId)
    local r = tonumber(rate) or 1
    if r ~= r or r <= 0 then r = 1 end
    r = math.max(r, 0.001)
    return base / r
end