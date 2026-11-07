VERSE.VGUI = VERSE.VGUI or {}
local V = VERSE.VGUI
V._list = V._list or {}
V._ns = V._ns or {}
V._alias = V._alias or {}
V._seq = V._seq or 0
local function logErr(...)
    if VERSE.Log and VERSE.Log.Error then
        VERSE.Log:Error(...)
    else
        MsgN(...)
    end
end

local function normalizeName(name)
    if not isstring(name) then return nil end
    name = string.Trim(name)
    if name == "" then return nil end
    return name
end

local function normalizeNS(ns)
    if not isstring(ns) then return nil end
    ns = string.Trim(ns)
    if ns == "" then return nil end
    return ns
end

local function nextSeq()
    V._seq = (V._seq or 0) + 1
    return V._seq
end

local function getListClass(name)
    local entry = V._list[name]
    if not istable(entry) then return nil end
    return entry.class
end

function V.Resolve(name)
    name = normalizeName(name)
    if not name then return nil end
    local visited = {}
    local resolved = name
    for _ = 1, 64 do
        local target = V._alias[resolved]
        if not target then break end
        if visited[target] then break end
        visited[resolved] = true
        resolved = target
    end
    return resolved
end

function V.Exists(name)
    local resolved = V.Resolve(name)
    if not resolved then return false end
    if getListClass(resolved) then return true end
    return vgui.GetControlTable(resolved) ~= nil
end

function V.Get(name)
    local resolved = V.Resolve(name)
    if not resolved then return nil end
    local src = V._list[resolved]
    if not istable(src) then
        if vgui.GetControlTable(resolved) == nil then return nil end
        return {
            class = resolved,
            external = true,
        }
    end
    return {
        class = src.class,
        base = src.base,
        ns = src.ns,
        source = src.source,
        seq = src.seq,
    }
end

function V.List()
    local out = {}
    for class in pairs(V._list) do
        out[#out + 1] = class
    end

    table.sort(out)
    return out
end

function V.ListNS(ns)
    ns = normalizeNS(ns)
    if not ns then return {} end
    local map = V._ns[ns]
    if not istable(map) then return {} end
    local out = {}
    for class in pairs(map) do
        out[#out + 1] = class
    end

    table.sort(out)
    return out
end

function V.Count(ns)
    if ns == nil then
        local n = 0
        for _ in pairs(V._list) do
            n = n + 1
        end
        return n
    end

    ns = normalizeNS(ns)
    if not ns then return 0 end
    local map = V._ns[ns]
    if not istable(map) then return 0 end
    local n = 0
    for _ in pairs(map) do
        n = n + 1
    end
    return n
end

function V.Register(class, panel, base, opts)
    class = normalizeName(class)
    if not class or not istable(panel) then return false end
    opts = istable(opts) and opts or {}
    local overwrite = opts.overwrite == true
    local known = V._list[class]
    local existsInVGUI = vgui.GetControlTable(class) ~= nil
    if existsInVGUI and not overwrite and not known then
        logErr("[VGUI] Register blocked for existing external class: " .. class)
        return false
    end

    local ok, err = pcall(vgui.Register, class, panel, base)
    if not ok then
        logErr("[VGUI] Register failed: " .. class .. " -> " .. tostring(err))
        return false
    end

    local entry = known or {}
    entry.class = class
    entry.base = normalizeName(base)
    entry.source = normalizeName(opts.source)
    entry.seq = nextSeq()
    entry.ns = entry.ns or nil
    V._list[class] = entry
    return true
end

function V.Add(class, panel, base, opts)
    return V.Register(class, panel, base, opts)
end

function V.RegisterNS(ns, class, panel, base, opts)
    ns = normalizeNS(ns)
    if not ns then return false end
    if not V.Register(class, panel, base, opts) then return false end
    class = V.Resolve(class)
    if not class then return false end
    V._ns[ns] = V._ns[ns] or {}
    V._ns[ns][class] = true
    if V._list[class] then V._list[class].ns = ns end
    return true
end

function V.AddNS(ns, class, panel, base, opts)
    return V.RegisterNS(ns, class, panel, base, opts)
end

function V.Remove(class)
    class = normalizeName(class)
    if not class then return false end
    class = V.Resolve(class)
    if not class then return false end
    if not V._list[class] then return false end
    V._list[class] = nil
    for ns, map in pairs(V._ns) do
        if map[class] then
            map[class] = nil
            if next(map) == nil then V._ns[ns] = nil end
        end
    end

    for alias, target in pairs(V._alias) do
        if alias == class or target == class then V._alias[alias] = nil end
    end
    return true
end

function V.RemoveNS(ns, class)
    ns = normalizeNS(ns)
    class = normalizeName(class)
    if not ns or not class then return false end
    class = V.Resolve(class)
    if not class then return false end
    local map = V._ns[ns]
    if not map or not map[class] then return false end
    map[class] = nil
    if next(map) == nil then V._ns[ns] = nil end
    if V._list[class] and V._list[class].ns == ns then V._list[class].ns = nil end
    return true
end

function V.ClearNS(ns)
    ns = normalizeNS(ns)
    if not ns then return false end
    local map = V._ns[ns]
    if not map then return false end
    for class in pairs(map) do
        if V._list[class] and V._list[class].ns == ns then V._list[class].ns = nil end
    end

    V._ns[ns] = nil
    return true
end

function V.Clear()
    V._list = {}
    V._ns = {}
    V._alias = {}
    V._seq = 0
    return true
end

function V.Alias(alias, class, opts)
    alias = normalizeName(alias)
    class = normalizeName(class)
    if not alias or not class then return false end
    opts = istable(opts) and opts or {}
    class = V.Resolve(class) or class
    if not opts.allowMissing and not V.Exists(class) then return false end
    if V._alias[alias] and V._alias[alias] ~= class and opts.overwrite ~= true then return false end
    V._alias[alias] = class
    return true
end

function V.Unalias(alias)
    alias = normalizeName(alias)
    if not alias or not V._alias[alias] then return false end
    V._alias[alias] = nil
    return true
end

function V.Create(class, parent, panelName, noResolve)
    class = normalizeName(class)
    if not class then return nil end
    local useClass = noResolve and class or V.Resolve(class)
    if not useClass then return nil end
    return vgui.Create(useClass, parent, panelName)
end

function V.Make(class, parent, panelName, noResolve)
    return V.Create(class, parent, panelName, noResolve)
end