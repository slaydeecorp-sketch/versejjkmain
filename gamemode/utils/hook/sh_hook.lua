VERSE.Hook = VERSE.Hook or {}

local H = VERSE.Hook

H._list = H._list or {}
H._ns   = H._ns   or {}
H._bind = H._bind or {}
H._seq  = H._seq  or 0
H.STOP = H.STOP or {}

local function logErr(...)
    if VERSE.Log and VERSE.Log.Error then
        VERSE.Log:Error(...)
    else
        MsgN(...)
    end
end

local function normalizeEvent(event)
    if not isstring(event) or event == "" then return nil end
    return event
end

local function normalizeId(id)
    if not isstring(id) or id == "" then return nil end
    return id
end

local function ensureEvent(event)
    H._list[event] = H._list[event] or {}
    return H._list[event]
end

local function nextSeq()
    H._seq = (H._seq or 0) + 1
    return H._seq
end

local function makeEntry(fn, pr, once)
    return {
        fn = fn,
        pr = tonumber(pr) or 0,
        once = tobool(once),
        seq = nextSeq()
    }
end

local function snapshotSorted(list)
    local arr = {}
    for id, e in pairs(list) do
        arr[#arr + 1] = { id = id, e = e }
    end

    table.sort(arr, function(a, b)
        local pa, pb = a.e.pr or 0, b.e.pr or 0
        if pa ~= pb then return pa > pb end
        local sa, sb = a.e.seq or 0, b.e.seq or 0
        if sa ~= sb then return sa < sb end
        return tostring(a.id) < tostring(b.id)
    end)

    return arr
end

function H.Exists(event, id)
    event = normalizeEvent(event); if not event then return false end
    id = normalizeId(id); if not id then return false end
    local list = H._list[event]
    return list and list[id] ~= nil or false
end

function H.Count(event)
    event = normalizeEvent(event); if not event then return 0 end
    local list = H._list[event]
    if not list then return 0 end
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    return n
end

function H.List(event)
    event = normalizeEvent(event); if not event then return {} end
    local list = H._list[event] or {}
    local out = {}
    for id in pairs(list) do out[#out + 1] = id end
    table.sort(out)
    return out
end

function H.Add(event, id, fn, prOrOpts)
    event = normalizeEvent(event); if not event then return false end
    id = normalizeId(id); if not id then return false end
    if not isfunction(fn) then return false end

    H.BindGMod(event)

    local pr = 0
    local once = false
    if istable(prOrOpts) then
        pr = tonumber(prOrOpts.priority) or 0
        once = tobool(prOrOpts.once)
    else
        pr = tonumber(prOrOpts) or 0
    end

    local list = ensureEvent(event)
    list[id] = makeEntry(fn, pr, once)
    return true
end

function H.Once(event, id, fn, prOrOpts)
    local opts = prOrOpts
    if not istable(opts) then opts = { priority = tonumber(prOrOpts) or 0 } end
    opts.once = true
    return H.Add(event, id, fn, opts)
end

function H.AddNS(ns, event, id, fn, prOrOpts)
    if not isstring(ns) or ns == "" then return false end
    if not H.Add(event, id, fn, prOrOpts) then return false end
    event = normalizeEvent(event)
    id = normalizeId(id)
    H._ns[ns] = H._ns[ns] or {}
    H._ns[ns][event] = H._ns[ns][event] or {}
    H._ns[ns][event][id] = true
    return true
end

function H.OnceNS(ns, event, id, fn, prOrOpts)
    local opts = prOrOpts
    if not istable(opts) then opts = { priority = tonumber(prOrOpts) or 0 } end
    opts.once = true
    return H.AddNS(ns, event, id, fn, opts)
end

function H.Remove(event, id)
    event = normalizeEvent(event); if not event then return false end
    id = normalizeId(id); if not id then return false end
    local list = H._list[event]
    if not list or not list[id] then return false end
    list[id] = nil
    return true
end

function H.RemoveNS(ns, event, id)
    if not isstring(ns) or ns == "" then return false end
    event = normalizeEvent(event); if not event then return false end
    id = normalizeId(id); if not id then return false end

    local map = H._ns[ns]
    if not map or not map[event] or not map[event][id] then
        return false
    end

    map[event][id] = nil
    if next(map[event]) == nil then map[event] = nil end
    if next(map) == nil then H._ns[ns] = nil end

    local removed = H.Remove(event, id)
    return removed
end

function H.Clear(event)
    event = normalizeEvent(event); if not event then return false end
    H._list[event] = nil

    for ns, map in pairs(H._ns) do
        if map[event] then map[event] = nil end
        if next(map) == nil then H._ns[ns] = nil end
    end

    return true
end

function H.ClearNS(ns)
    if not isstring(ns) or ns == "" then return false end
    local map = H._ns[ns]
    if not map then return false end

    for event, ids in pairs(map) do
        for id in pairs(ids) do
            H.Remove(event, id)
        end
    end

    H._ns[ns] = nil
    return true
end

function H.Call(event, ...)
    event = normalizeEvent(event); if not event then return end
    local list = H._list[event]
    if not list then return end

    local arr = snapshotSorted(list)
    for i = 1, #arr do
        local id = arr[i].id
        local ent = list[id]
        if ent and ent.fn then
            local ok, a, b, c, d, e2 = pcall(ent.fn, ...)
            if not ok then
                logErr("[HOOK ERROR]", event, id, a)
            else
                if a ~= nil then
                    if ent.once then list[id] = nil end
                    return a, b, c, d, e2
                end
            end

            if ent.once then
                list[id] = nil
            end
        end
    end
end

function H.Run(event, ...)
    event = normalizeEvent(event); if not event then return end
    local list = H._list[event]
    if not list then return end

    local arr = snapshotSorted(list)
    for i = 1, #arr do
        local id = arr[i].id
        local e = list[id]
        if e and e.fn then
            local ok, a, b, c, d, e2 = pcall(e.fn, ...)
            if not ok then
                logErr("[HOOK ERROR]", event, id, a)
            else
                if a == H.STOP then
                    if e.once then list[id] = nil end
                    return
                end
                if a ~= nil then
                    if e.once then list[id] = nil end
                    return a, b, c, d, e2
                end
            end

            if e.once then
                list[id] = nil
            end
        end
    end
end

function H.BindGMod(event, preferRun)
    event = normalizeEvent(event); if not event then return false end
    if H._bind[event] then return true end

    local gid = "VERSE::HookBridge::" .. event
    H._bind[event] = gid

    hook.Add(event, gid, function(...)
        if preferRun then
            return H.Run(event, ...)
        else
            return H.Call(event, ...)
        end
    end)

    return true
end

function H.UnbindGMod(event)
    event = normalizeEvent(event); if not event then return false end
    local gid = H._bind[event]
    if not gid then return false end
    hook.Remove(event, gid)
    H._bind[event] = nil
    return true
end