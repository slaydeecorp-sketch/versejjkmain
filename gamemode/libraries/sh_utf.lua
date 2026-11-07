utf = utf or {}
local hasUtf8 = utf8 ~= nil
local uc_lc = {
    ['А'] = 'а',
    ['Б'] = 'б',
    ['В'] = 'в',
    ['Г'] = 'г',
    ['Д'] = 'д',
    ['Е'] = 'е',
    ['Ё'] = 'ё',
    ['Ж'] = 'ж',
    ['З'] = 'з',
    ['И'] = 'и',
    ['Й'] = 'й',
    ['К'] = 'к',
    ['Л'] = 'л',
    ['М'] = 'м',
    ['Н'] = 'н',
    ['О'] = 'о',
    ['П'] = 'п',
    ['Р'] = 'р',
    ['С'] = 'с',
    ['Т'] = 'т',
    ['У'] = 'у',
    ['Ф'] = 'ф',
    ['Х'] = 'х',
    ['Ц'] = 'ц',
    ['Ч'] = 'ч',
    ['Ш'] = 'ш',
    ['Щ'] = 'щ',
    ['Ъ'] = 'ъ',
    ['Ы'] = 'ы',
    ['Ь'] = 'ь',
    ['Э'] = 'э',
    ['Ю'] = 'ю',
    ['Я'] = 'я'
}

local lc_uc = {}
for uc, lc in pairs(uc_lc) do
    lc_uc[lc] = uc
end

setmetatable(uc_lc, {
    __index = function(_, ch) return tostring(ch):lower() end
})

setmetatable(lc_uc, {
    __index = function(_, ch) return tostring(ch):upper() end
})

utf.charpattern = utf.charpattern or (hasUtf8 and utf8.charpattern) or "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*"
function utf.lower(text)
    text = tostring(text or "")
    return text:gsub(utf.charpattern, uc_lc)
end

function utf.upper(text)
    text = tostring(text or "")
    return text:gsub(utf.charpattern, lc_uc)
end

function utf.len(str)
    str = tostring(str or "")
    if hasUtf8 and utf8.len then
        local ok, res = pcall(utf8.len, str)
        if ok then return res end
    end
    return #str
end

function utf.sub(str, i, j)
    str = tostring(str or "")
    if hasUtf8 and utf8.sub then
        local ok, res = pcall(utf8.sub, str, i, j)
        if ok and res ~= nil then return res end
    end
    return string.sub(str, i, j)
end

utf.codes = utf.codes or (hasUtf8 and utf8.codes) or function(s)
    s = tostring(s or "")
    local i, n = 0, #s
    return function()
        i = i + 1
        if i <= n then return i, string.byte(s, i) end
    end
end

utf.char = utf.char or (hasUtf8 and utf8.char) or function(code) return string.char(code or 0) end