local E = VERSE.Effects or VERSE.Buffs
if not E then return end

VERSE.Effects = E
VERSE.Buffs = E

E._state = E._state or setmetatable({}, { __mode = "k" })

local function playerKey(ply)
    if not IsValid(ply) then return "invalid" end
    return tostring(ply:SteamID64() or ply:UserID() or ply:EntIndex())
end

local function ensureState(ply)
    if not IsValid(ply) then return nil end

    local state = E._state[ply]
    if not istable(state) then
        state = {
            buffs = {},
            debuffs = {},
        }
        E._state[ply] = state
    end

    return state
end

local function setBuffSource(ply, source, stats)
    if not IsValid(ply) or not isfunction(ply.SetStatBuffBulk) then return end
    ply:SetStatBuffBulk(source, stats or {})
end

local function clearBuffSource(ply, source)
    if not IsValid(ply) or not isfunction(ply.ClearStatBuff) then return end
    ply:ClearStatBuff(source)
end

function E:HasBuff(ply, buffId)
    buffId = tostring(buffId or "")
    if buffId == "" then return false end

    local state = ensureState(ply)
    if not state then return false end
    return istable(state.buffs[buffId])
end

function E:HasDebuff(ply, debuffId)
    debuffId = tostring(debuffId or "")
    if debuffId == "" then return false end

    local state = ensureState(ply)
    if not state then return false end
    return istable(state.debuffs[debuffId])
end

function E:GetBuffState(ply, buffId)
    buffId = tostring(buffId or "")
    if buffId == "" then return nil end

    local state = ensureState(ply)
    if not state then return nil end
    return state.buffs[buffId]
end

function E:GetDebuffState(ply, debuffId)
    debuffId = tostring(debuffId or "")
    if debuffId == "" then return nil end

    local state = ensureState(ply)
    if not state then return nil end
    return state.debuffs[debuffId]
end

function E:RemoveBuff(ply, buffId)
    buffId = tostring(buffId or "")
    if buffId == "" then return end

    local state = ensureState(ply)
    if not state then return end

    local entry = state.buffs[buffId]
    if not entry then return end

    state.buffs[buffId] = nil
    clearBuffSource(ply, entry.source)
end

function E:RemoveDebuff(ply, debuffId)
    debuffId = tostring(debuffId or "")
    if debuffId == "" then return end

    local state = ensureState(ply)
    if not state then return end

    local entry = state.debuffs[debuffId]
    if not entry then return end

    state.debuffs[debuffId] = nil
    clearBuffSource(ply, entry.source)
end

function E:ApplyTimedBuff(ply, buffId, duration, statMap, data)
    if not IsValid(ply) then return false end

    buffId = tostring(buffId or "")
    duration = math.max(0.1, tonumber(duration) or 0)
    if buffId == "" then return false end

    local state = ensureState(ply)
    local token = tostring(CurTime()) .. ":" .. tostring(math.random(1000, 9999))
    local source = "Buff:" .. buffId

    state.buffs[buffId] = {
        id = buffId,
        source = source,
        token = token,
        expiresAt = CurTime() + duration,
        stats = statMap or {},
        data = istable(data) and data or {},
    }

    setBuffSource(ply, source, statMap)

    local timerId = ("ExpireBuff:%s:%s"):format(playerKey(ply), buffId)
    VERSE.Timers.CreateNS("Effects", timerId, duration, 1, function()
        if not IsValid(ply) then return end

        local current = state.buffs[buffId]
        if not current then return end
        if current.token ~= token then return end

        E:RemoveBuff(ply, buffId)
    end)

    return true
end

function E:ApplyTimedDebuff(ply, debuffId, duration, statMap, data)
    if not IsValid(ply) then return false end

    debuffId = tostring(debuffId or "")
    duration = math.max(0.1, tonumber(duration) or 0)
    if debuffId == "" then return false end

    local state = ensureState(ply)
    local token = tostring(CurTime()) .. ":" .. tostring(math.random(1000, 9999))
    local source = "Debuff:" .. debuffId

    state.debuffs[debuffId] = {
        id = debuffId,
        source = source,
        token = token,
        expiresAt = CurTime() + duration,
        stats = statMap or {},
        data = istable(data) and data or {},
        nextTickAt = CurTime(),
    }

    setBuffSource(ply, source, statMap)

    local timerId = ("ExpireDebuff:%s:%s"):format(playerKey(ply), debuffId)
    VERSE.Timers.CreateNS("Effects", timerId, duration, 1, function()
        if not IsValid(ply) then return end

        local current = state.debuffs[debuffId]
        if not current then return end
        if current.token ~= token then return end

        E:RemoveDebuff(ply, debuffId)
    end)

    return true
end

local function applyDebuffDot(ply, debuff)
    local dot = tonumber(debuff.data and debuff.data.damagePerTick) or 0
    if dot <= 0 or not IsValid(ply) or not ply:Alive() then return end

    local info = DamageInfo()
    info:SetDamage(dot)
    info:SetDamageType(DMG_GENERIC)

    if IsValid(debuff.data and debuff.data.attacker) then
        info:SetAttacker(debuff.data.attacker)
    else
        info:SetAttacker(game.GetWorld())
    end

    info:SetInflictor(game.GetWorld())
    ply:TakeDamageInfo(info)
end

local function tickDebuffs()
    local now = CurTime()

    for ply, state in pairs(E._state) do
        if not IsValid(ply) or not istable(state) then
            E._state[ply] = nil
        else
            for debuffId, debuff in pairs(state.debuffs) do
                if not istable(debuff) then
                    state.debuffs[debuffId] = nil
                else
                    local tickEvery = math.max(0.1, tonumber(debuff.data and debuff.data.tickEvery) or 1)
                    if now >= (debuff.nextTickAt or 0) then
                        debuff.nextTickAt = now + tickEvery
                        applyDebuffDot(ply, debuff)
                    end
                end
            end
        end
    end
end

VERSE.Timers.CreateNS("Effects", "DebuffTick", E.Config.TickInterval or 1, 0, tickDebuffs)

VERSE.Hook.AddNS("Effects", "PlayerDisconnected", "VERSE::PlayerDisconnected::Effects", function(ply)
    E._state[ply] = nil
end)

VERSE.Hook.AddNS("Effects", "PlayerSpawn", "VERSE::PlayerSpawn::Effects", function(ply)
    if not IsValid(ply) then return end

    local state = ensureState(ply)
    if not state then return end

    for buffId, buff in pairs(state.buffs) do
        if istable(buff) then
            clearBuffSource(ply, buff.source)
        end
        state.buffs[buffId] = nil
    end

    for debuffId, debuff in pairs(state.debuffs) do
        if istable(debuff) then
            clearBuffSource(ply, debuff.source)
        end
        state.debuffs[debuffId] = nil
    end
end)
