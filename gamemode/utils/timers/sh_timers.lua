VERSE.Timers = VERSE.Timers or {}
VERSE.Timers._ns = VERSE.Timers._ns or {}

local function logErr(...)
    if VERSE.Log then VERSE.Log:Error(...) else MsgN(...) end
end

local function track(ns, name)
    VERSE.Timers._ns[ns] = VERSE.Timers._ns[ns] or {}
    VERSE.Timers._ns[ns][name] = true
end

local function fullName(ns, id)
    return ("verse:%s:%s"):format(ns, id)
end

function VERSE.Timers.CreateNS(ns, id, delay, reps, fn)
    if not ns or ns == "" then return end
    if not id or id == "" then return end
    if not isfunction(fn) then return end

    local name = fullName(ns, id)
    track(ns, name)

    timer.Create(name, delay, reps or 0, function()
        local ok, err = pcall(fn)
        if not ok then
            logErr("[TIMER ERROR]", name, err)
        end
    end)
end

function VERSE.Timers.SimpleNS(ns, id, delay, fn)
    if not ns or ns == "" then return end
    if not id or id == "" then return end
    if not isfunction(fn) then return end

    local name = fullName(ns, id)
    track(ns, name)

    timer.Simple(delay, function()
        local ok, err = pcall(fn)
        if not ok then
            logErr("[TIMER ERROR]", name, err)
        end

        if VERSE.Timers._ns[ns] then
            VERSE.Timers._ns[ns][name] = nil
        end
    end)
end

function VERSE.Timers.RemoveNS(ns, id)
    if not ns or ns == "" then return end
    if not id or id == "" then return end

    local name = fullName(ns, id)
    timer.Remove(name)

    if VERSE.Timers._ns[ns] then
        VERSE.Timers._ns[ns][name] = nil
    end
end

function VERSE.Timers.ClearNS(ns)
    if not ns or ns == "" then return end

    local map = VERSE.Timers._ns[ns]
    if not map then return end

    for name, _ in pairs(map) do
        timer.Remove(name)
    end

    VERSE.Timers._ns[ns] = nil
end