function VERSE.GetTextSize(text, font)
    if font then surface.SetFont(font) end
    return surface.GetTextSize(text)
end

function VERSE.FirstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

local hasUtf = utf and utf.len and utf.sub

local function SafeUtfLen(str)
    if hasUtf then
        local ok, len = pcall(utf.len, str)
        if ok and len then return len end
    end
    return #str
end

local function SafeUtfSub(str, i, j)
    if hasUtf then
        local ok, res = pcall(utf.sub, str, i, j)
        if ok and res then return res end
    end
    return string.sub(str, i, j)
end

local HUGE_WORD_BYTES = 256
local HUGE_CHUNK_BYTES = 32
local function HyphenateWord(word, font, maxWidth)
    local getTextSize = VERSE.GetTextSize

    if getTextSize(word, font) <= maxWidth then
        return { word }
    end

    if #word > HUGE_WORD_BYTES then
        local chunks = {}
        local lenBytes = #word
        local i = 1

        while i <= lenBytes do
            local last = math.min(i + HUGE_CHUNK_BYTES - 1, lenBytes)
            local slice = string.sub(word, i, last)

            if last < lenBytes then
                table.insert(chunks, slice .. "-")
            else
                table.insert(chunks, slice)
            end

            i = last + 1
        end

        return chunks
    end

    local chunks = {}
    local current = ""
    local len = SafeUtfLen(word)

    for i = 1, len do
        local ch = SafeUtfSub(word, i, i)
        local test = current .. ch

        local toMeasure = (current ~= "" and (test .. "-")) or (test .. "-")
        local w = getTextSize(toMeasure, font)

        if w > maxWidth and current ~= "" then
            table.insert(chunks, current .. "-")
            current = ch
        else
            current = test
        end
    end

    if current ~= "" then
        table.insert(chunks, current)
    end

    return chunks
end

VERSE._wrapCache = VERSE._wrapCache or {}
local wrapCache = VERSE._wrapCache
local WRAP_CACHE_LIMIT = 256

local function MakeWrapKey(text, font, maxWidth, maxLines)
    local raw = tostring(text) .. "|" .. tostring(font) .. "|" .. tostring(maxWidth) .. "|" .. tostring(maxLines or 0)
    if util and util.CRC then
        return util.CRC(raw)
    end
    return raw
end

function VERSE.TextWrap(text, font, spacing, maxWidth, maxLines)
    local getTextSize = VERSE.GetTextSize

    if not text or text == "" then
        return {}, 0, 0
    end

    local key = MakeWrapKey(text, font, maxWidth, maxLines)
    local cached = wrapCache[key]
    if cached then
        local lines = cached.lines
        local widest = cached.widest
        local totalHeight = #lines * spacing
        return lines, widest, totalHeight
    end

    local rawWords = string.Explode(" ", text)
    local words = {}
    for _, word in ipairs(rawWords) do
        if word ~= "" then
            local pieces = HyphenateWord(word, font, maxWidth)
            for _, part in ipairs(pieces) do
                table.insert(words, part)
            end
        end
    end

    local lines = {}
    local currentLine = ""

    for _, word in ipairs(words) do
        local testLine
        if currentLine ~= "" then
            testLine = currentLine .. " " .. word
        else
            testLine = word
        end

        if getTextSize(testLine, font) <= maxWidth then
            currentLine = testLine
        else
            if currentLine ~= "" then
                table.insert(lines, currentLine)
            end
            currentLine = word
        end
    end

    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    if maxLines and #lines > maxLines then
        local shortened = lines[maxLines]
        local len = SafeUtfLen(shortened)

        while getTextSize(shortened .. "...", font) > maxWidth and len > 1 do
            len = len - 1
            shortened = SafeUtfSub(shortened, 1, len)
        end

        lines[maxLines] = shortened .. "..."

        for i = #lines, maxLines + 1, -1 do
            table.remove(lines, i)
        end
    end

    local widestLineWidth = 0
    for _, line in ipairs(lines) do
        local w = getTextSize(line, font)
        if w > widestLineWidth then
            widestLineWidth = w
        end
    end

    local totalHeight = #lines * spacing

    if not wrapCache._size then wrapCache._size = 0 end
    if wrapCache._size >= WRAP_CACHE_LIMIT then
        wrapCache = {}
        VERSE._wrapCache = wrapCache
        wrapCache._size = 0
    end

    wrapCache[key] = {
        lines = lines,
        widest = widestLineWidth
    }
    wrapCache._size = wrapCache._size + 1

    return lines, widestLineWidth, totalHeight
end