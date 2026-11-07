VERSE.Effects = VERSE.Effects or VERSE.Buffs or {}
VERSE.Buffs = VERSE.Effects
local E = VERSE.Effects
E.Net = E.Net or {
    Sync = "VERSE::Effects::Sync",
}

E.Config = E.Config or {
    TickInterval = 1,
}

function E:HasBuff(_, _)
    return false
end

function E:HasDebuff(_, _)
    return false
end