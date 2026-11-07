VERSE.Format = VERSE.Format or {}

local Fmt = VERSE.Format

function Fmt.Money(n, opts)
    opts = opts or {}
    local sep = opts.sep or " "

    n = tonumber(n) or 0
    local sign = ""
    if n < 0 then
        sign = "-"
        n = -n
    end

    n = math.floor(n + 0.5)

    local s = tostring(n)
    local out = {}
    local len = #s
    local i = len

    while i > 3 do
        out[#out + 1] = string.sub(s, i - 2, i)
        i = i - 3
    end
    if i > 0 then
        out[#out + 1] = string.sub(s, 1, i)
    end

    for l = 1, math.floor(#out / 2) do
        out[l], out[#out - l + 1] = out[#out - l + 1], out[l]
    end

    return sign .. table.concat(out, sep)
end

function Fmt.Percent(value, opts)
    opts = opts or {}
    local digits = tonumber(opts.digits)
    if digits == nil then digits = 1 end
    if digits < 0 then digits = 0 end

    local base = opts.base or "ratio"
    local trimZeros = (opts.trimZeros ~= false)
    local decimalSep = opts.decimalSep or "."

    local v = tonumber(value) or 0
    if base ~= "percent" then
        v = v * 100
    end

    local fmt = "%." .. tostring(digits) .. "f"
    local s = string.format(fmt, v)

    if decimalSep ~= "." then
        s = string.Replace(s, ".", decimalSep)
    end

    if trimZeros and digits > 0 then
        local pat = string.PatternSafe(decimalSep) .. "0+$"
        s = string.gsub(s, pat, "")
        s = string.gsub(s, string.PatternSafe(decimalSep) .. "$", "")
    end

    return s .. "%"
end

function Fmt.Bytes(bytes, opts)
    opts = opts or {}
    local si = (opts.si ~= false)
    local digits = tonumber(opts.digits)
    if digits == nil then digits = 2 end
    if digits < 0 then digits = 0 end

    local trimZeros = (opts.trimZeros ~= false)
    local decimalSep = opts.decimalSep or "."

    local b = tonumber(bytes) or 0
    local sign = ""
    if b < 0 then
        sign = "-"
        b = -b
    end

    local base = si and 1000 or 1024
    local units = si
        and { "B", "kB", "MB", "GB", "TB", "PB", "EB" }
        or { "B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB" }

    if b < base then
        return sign .. tostring(math.floor(b + 0.5)) .. " " .. units[1]
    end

    local u = 1
    local v = b
    while v >= base and u < #units do
        v = v / base
        u = u + 1
    end

    local fmt = "%." .. tostring(digits) .. "f"
    local s = string.format(fmt, v)

    if decimalSep ~= "." then
        s = string.Replace(s, ".", decimalSep)
    end

    if trimZeros and digits > 0 then
        local pat = string.PatternSafe(decimalSep) .. "0+$"
        s = string.gsub(s, pat, "")
        s = string.gsub(s, string.PatternSafe(decimalSep) .. "$", "")
    end

    return sign .. s .. " " .. units[u]
end

function Fmt.Color(c, opts)
    opts = opts or {}

    if not IsColor(c) then
        return (opts.prefix == false) and "000000" or "#000000"
    end

    local r = math.Clamp(c.r or 0, 0, 255)
    local g = math.Clamp(c.g or 0, 0, 255)
    local b = math.Clamp(c.b or 0, 0, 255)
    local a = math.Clamp(c.a or 255, 0, 255)

    local s = string.format("%02X%02X%02X", r, g, b)
    if opts.withAlpha then
        s = s .. string.format("%02X", a)
    end

    if opts.prefix ~= false then
        s = "#" .. s
    end

    return s
end