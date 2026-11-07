VERSE.Table = VERSE.Table or {}

local T = VERSE.Table

function T.DeepCopy(src, seen)
    if not istable(src) then return src end
    seen = seen or {}
    if seen[src] then return seen[src] end

    local dst = {}
    seen[src] = dst

    for k, v in pairs(src) do
        dst[T.DeepCopy(k, seen)] = T.DeepCopy(v, seen)
    end

    local mt = getmetatable(src)
    if mt ~= nil then
        setmetatable(dst, T.DeepCopy(mt, seen))
    end

    return dst
end

function T.DeepMerge(dst, src, mode)
    if not istable(dst) then dst = {} end
    if not istable(src) then return dst end
    mode = mode or "overwrite"

    for k, v in pairs(src) do
        if istable(v) and istable(dst[k]) then
            T.DeepMerge(dst[k], v, mode)
        elseif istable(v) then
            dst[k] = T.DeepCopy(v)
        else
            if not (mode == "keep" and dst[k] ~= nil) then
                dst[k] = v
            end
        end
    end

    return dst
end

function T.DeepEqual(a, b, seen, opts)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if not istable(a) then return a == b end

    opts = opts or {}
    seen = seen or {}

    if seen[a] ~= nil then
        return seen[a] == b
    end
    seen[a] = b

    if opts.compareMeta and getmetatable(a) ~= getmetatable(b) then
        return false
    end

    for k, va in pairs(a) do
        local vb = b[k]
        if not T.DeepEqual(va, vb, seen, opts) then
            return false
        end
    end

    for k, _ in pairs(b) do
        if a[k] == nil then return false end
    end

    return true
end

function T.Get(root, path, default, opts)
    if not istable(root) then return default end
    if not isstring(path) or path == "" then return default end
    opts = opts or {}
    local sep = opts.sep or "."

    local cur = root
    for part in string.gmatch(path, "[^" .. sep .. "]+") do
        if not istable(cur) then return default end
        cur = cur[part]
        if cur == nil then return default end
    end

    return cur
end

function T.Set(root, path, value, opts)
    if not istable(root) then return false end
    if not isstring(path) or path == "" then return false end
    opts = opts or {}
    local sep = opts.sep or "."

    local cur = root
    local parts = {}

    for part in string.gmatch(path, "[^" .. sep .. "]+") do
        parts[#parts + 1] = part
    end

    if #parts == 0 then return false end

    for i = 1, #parts - 1 do
        local key = parts[i]
        local nxt = cur[key]
        if nxt == nil then
            nxt = {}
            cur[key] = nxt
        elseif not istable(nxt) then
            return false
        end
        cur = nxt
    end

    cur[parts[#parts]] = value
    return true
end

function T.Filter(tbl, pred)
    if not istable(tbl) then return {} end
    if not isfunction(pred) then return T.DeepCopy(tbl) end

    local out = {}
    for k, v in pairs(tbl) do
        if pred(v, k, tbl) then
            out[k] = v
        end
    end
    return out
end

function T.Map(tbl, fn)
    if not istable(tbl) then return {} end
    if not isfunction(fn) then return T.DeepCopy(tbl) end

    local out = {}
    for k, v in pairs(tbl) do
        local nk, nv = fn(v, k, tbl)
        if nv == nil and nk ~= nil then
            out[k] = nk
        else
            if nk ~= nil then
                out[nk] = nv
            end
        end
    end
    return out
end

function T.Reduce(tbl, fn, acc)
    if not istable(tbl) then return acc end
    if not isfunction(fn) then return acc end

    local first = (acc == nil)
    for k, v in pairs(tbl) do
        if first then
            acc = v
            first = false
        else
            acc = fn(acc, v, k, tbl)
        end
    end

    return acc
end

local function defaultKeyCmp(a, b)
    return tostring(a) < tostring(b)
end

function T.KeysSorted(tbl, cmp)
    if not istable(tbl) then return {} end
    cmp = cmp or defaultKeyCmp

    local keys = {}
    for k, _ in pairs(tbl) do
        keys[#keys + 1] = k
    end

    table.sort(keys, cmp)
    return keys
end

function T.PairsSorted(tbl, cmp)
    if not istable(tbl) then
        return function() return nil end
    end

    local keys = T.KeysSorted(tbl, cmp)
    local i = 0

    return function()
        i = i + 1
        local k = keys[i]
        if k == nil then return nil end
        return k, tbl[k]
    end
end

local function freezeOne(t, opts, seen)
    if not istable(t) then return t end
    seen = seen or {}
    if seen[t] then return t end
    seen[t] = true

    if opts and opts.deep then
        for k, v in pairs(t) do
            if istable(v) then
                freezeOne(v, opts, seen)
            end
        end
    end

    local mt = getmetatable(t) or {}
    if mt.__frozen then
        return t
    end

    mt.__frozen = true
    mt.__newindex = function()
        error("attempt to modify frozen table", 2)
    end

    mt.__metatable = "frozen"

    setmetatable(t, mt)
    return t
end

function T.Freeze(tbl, opts)
    opts = opts or {}
    return freezeOne(tbl, opts, {})
end

function T.ToPON(tbl)
    return pon.encode(tbl)
end

function T.FromPON(str, fallback)
    if not isstring(str) or str == "" then return fallback end
    local ok, res = pcall(pon.decode, str)
    if not ok then return fallback end
    return res
end

function T.KeyFromID(tbl, id, opts)
    if not istable(tbl) then return nil end
    opts = opts or {}
    local field = opts.field or "id"
    local cast = (opts.tonumberId ~= false)

    for k, v in pairs(tbl) do
        if istable(v) then
            local vid = v[field]
            if vid == id then return k end
            if cast and tonumber(vid) and tonumber(id) and tonumber(vid) == tonumber(id) then
                return k
            end
        end
    end

    return nil
end

function T.GetByID(tbl, id, opts)
    local k = T.KeyFromID(tbl, id, opts)
    if k == nil then return nil end
    return tbl[k]
end

function T.UpdateByID(tbl, id, newValue, opts)
    if not istable(tbl) then return false end
    local k = T.KeyFromID(tbl, id, opts)
    if k == nil then return false end
    tbl[k] = newValue
    return true
end

function T.RemoveByID(tbl, id, opts)
    if not istable(tbl) then return false end
    opts = opts or {}
    local k = T.KeyFromID(tbl, id, opts)
    if k == nil then
        if opts.onMissing == "trace" then
            ErrorNoHalt(("T.RemoveByID: id not found (%s)\n"):format(tostring(id)))
            debug.Trace()
        end
        return false
    end
    tbl[k] = nil
    return true
end

function T.PrintTypes(tbl, indent)
    if not istable(tbl) then
        print((" "):rep(indent or 0) .. tostring(tbl) .. " (" .. type(tbl) .. ")")
        return
    end

    indent = indent or 0
    for k, v in pairs(tbl) do
        local prefix = string.rep("  ", indent) .. tostring(k) .. " (" .. type(k) .. "): "
        if istable(v) then
            print(prefix .. "{table}")
            T.PrintTypes(v, indent + 1)
        else
            print(prefix .. tostring(v) .. " (" .. type(v) .. ")")
        end
    end
end