VERSE.String = VERSE.String or {}

local S = VERSE.String

function S.Trim(str)
    if not isstring(str) then return "" end
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    return str
end

function S.StartsWith(str, prefix)
    if not isstring(str) or not isstring(prefix) then return false end
    if prefix == "" then return true end
    return string.sub(str, 1, #prefix) == prefix
end

function S.EndsWith(str, suffix)
    if not isstring(str) or not isstring(suffix) then return false end
    if suffix == "" then return true end
    return string.sub(str, -#suffix) == suffix
end

function S.SplitFast(str, sep, opts)
    if not isstring(str) then return {} end
    if not isstring(sep) or sep == "" then return { str } end

    opts = opts or {}
    local maxParts = opts.maxParts
    local keepEmpty = opts.keepEmpty == true

    local out = {}
    local start = 1
    local sepLen = #sep
    local n = 0

    while true do
        if maxParts and n >= (maxParts - 1) then
            local tail = string.sub(str, start)
            if keepEmpty or tail ~= "" then
                out[#out + 1] = tail
            end
            break
        end

        local pos = string.find(str, sep, start, true)
        if not pos then
            local tail = string.sub(str, start)
            if keepEmpty or tail ~= "" then
                out[#out + 1] = tail
            end
            break
        end

        local part = string.sub(str, start, pos - 1)
        if keepEmpty or part ~= "" then
            out[#out + 1] = part
        end

        start = pos + sepLen
        n = n + 1
    end

    return out
end

function S.FormatSafe(fmt, ...)
    if not isstring(fmt) then
        return "", "fmt is not a string"
    end

    local ok, res = pcall(string.format, fmt, ...)
    if ok then
        return res
    end

    return fmt, res
end

function S.Slugify(str, opts)
    if not isstring(str) then return "" end
    opts = opts or {}

    local sep = opts.sep or "-"
    local maxLen = opts.maxLen

    str = string.lower(str)
    str = S.Trim(str)
    str = string.gsub(str, "[%s_]+", sep)
    str = string.gsub(str, "[^a-z0-9" .. string.PatternSafe(sep) .. "]+", sep)
    str = string.gsub(str, string.PatternSafe(sep) .. "+", sep)
    str = string.gsub(str, "^" .. string.PatternSafe(sep) .. "+", "")
    str = string.gsub(str, string.PatternSafe(sep) .. "+$", "")

    if maxLen and isnumber(maxLen) and maxLen > 0 and #str > maxLen then
        str = string.sub(str, 1, maxLen)
        str = string.gsub(str, string.PatternSafe(sep) .. "+$", "")
    end

    return str
end

function S.Humanize(str, opts)
    if not isstring(str) then return "" end
    opts = opts or {}

    str = S.Trim(str)
    str = string.gsub(str, "[_%-%s]+", " ")
    str = string.gsub(str, "([a-z0-9])([A-Z])", "%1 %2")
    str = string.gsub(str, "%s+", " ")
    str = S.Trim(str)

    if opts.capitalize == false then
        return str
    end

    if str == "" then return "" end
    return string.upper(string.sub(str, 1, 1)) .. string.lower(string.sub(str, 2))
end