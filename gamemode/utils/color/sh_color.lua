VERSE.Color = VERSE.Color or {}

local C = VERSE.Color

function C.Lerp(a, b, t)
    if not IsColor(a) or not IsColor(b) then
        return Color(0, 0, 0, 255)
    end

    t = tonumber(t) or 0

    return Color(
        math.floor(a.r + (b.r - a.r) * t),
        math.floor(a.g + (b.g - a.g) * t),
        math.floor(a.b + (b.b - a.b) * t),
        math.floor(a.a + (b.a - a.a) * t)
    )
end

function C.WithAlpha(c, a)
    if not IsColor(c) then
        return Color(0, 0, 0, tonumber(a) or 255)
    end

    return Color(
        c.r,
        c.g,
        c.b,
        math.Clamp(tonumber(a) or c.a or 255, 0, 255)
    )
end

function C.FromHex(hex)
    if not isstring(hex) then
        return Color(0, 0, 0, 255)
    end

    hex = string.Trim(hex)
    hex = string.gsub(hex, "#", "")

    if #hex ~= 6 and #hex ~= 8 then
        return Color(0, 0, 0, 255)
    end

    local r = tonumber(string.sub(hex, 1, 2), 16)
    local g = tonumber(string.sub(hex, 3, 4), 16)
    local b = tonumber(string.sub(hex, 5, 6), 16)
    local a = 255

    if #hex == 8 then
        a = tonumber(string.sub(hex, 7, 8), 16) or 255
    end

    if not r or not g or not b then
        return Color(0, 0, 0, 255)
    end

    return Color(r, g, b, a)
end

function C.ToHex(c, opts)
    if not IsColor(c) then
        return "#000000"
    end

    opts = opts or {}

    local r = math.Clamp(c.r or 0, 0, 255)
    local g = math.Clamp(c.g or 0, 0, 255)
    local b = math.Clamp(c.b or 0, 0, 255)
    local a = math.Clamp(c.a or 255, 0, 255)

    local hex = string.format("%02X%02X%02X", r, g, b)

    if opts.withAlpha then
        hex = hex .. string.format("%02X", a)
    end

    if opts.prefix ~= false then
        hex = "#" .. hex
    end

    return hex
end