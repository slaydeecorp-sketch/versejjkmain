VERSE.I18N = VERSE.I18N or {}

local I = VERSE.I18N
I.dict = I.dict or {}

local function _configDefault()
    local cfg = (VERSE.Config and VERSE.Config.I18N) or {}
    return cfg.Default or cfg.Fallback
end

I.default = I.default or _configDefault() or "fr"
I.fallback = I.fallback or _configDefault() or I.default

local function logWarn(...)
    if VERSE.Log and VERSE.Log.Warn then VERSE.Log:Warn(...)
    else MsgC(Color(255, 200, 0), "[I18N] ", color_white, table.concat({ ... }, " "), "\n") end
end

local function normalize(lang)
    if not isstring(lang) then return nil end
    lang = string.Trim(string.lower(lang))
    if lang == "" then return nil end
    lang = string.Replace(lang, "-", "_")
    lang = string.match(lang, "^[a-z]+") or lang
    return lang
end

local function isSupported(lang)
    local cfg = (VERSE.Config and VERSE.Config.I18N) or {}
    local sup = cfg.Supported
    if not istable(sup) then return true end
    for _, v in ipairs(sup) do
        if v == lang then return true end
    end

    return false
end

local function fmt(str, vars)
    if not vars then return str end
    return (string.gsub(str, "{([%w_]+)}", function(k)
        local v = vars[k]
        if v == nil then return "{" .. k .. "}" end
        return tostring(v)
    end))
end

local function getPath(t, key)
    if not istable(t) then return nil end
    local cur = t
    for part in string.gmatch(key, "[^%.]+") do
        if not istable(cur) then return nil end
        cur = cur[part]
        if cur == nil then return nil end
    end
    return cur
end

local function plural_en(n)
    return (n == 1) and "one" or "other"
end

local function plural_ru(n)
    n = math.abs(tonumber(n) or 0)
    local n10 = n % 10
    local n100 = n % 100
    if n10 == 1 and n100 ~= 11 then return "one" end
    if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then return "few" end
    if n10 == 0 or (n10 >= 5 and n10 <= 9) or (n100 >= 11 and n100 <= 14) then return "many" end
    return "other"
end

local function pickPlural(lang, forms, n)
    if not istable(forms) then return nil end
    local rule = (lang == "ru") and plural_ru or plural_en
    local k = rule(n)
    return forms[k] or forms.other or forms.many or forms.few or forms.one
end

function I.Setup(defaultLang, fallbackLang)
    defaultLang = normalize(defaultLang) or "ru"
    fallbackLang = normalize(fallbackLang) or defaultLang

    if not isSupported(defaultLang) then logWarn("Default lang not in Supported:", defaultLang) end
    if not isSupported(fallbackLang) then logWarn("Fallback lang not in Supported:", fallbackLang) end

    I.default = defaultLang
    I.fallback = fallbackLang
end

function I.Add(lang, entries)
    lang = normalize(lang)
    if not lang or not istable(entries) then return end

    I.dict[lang] = I.dict[lang] or {}
    for k, v in pairs(entries) do
        I.dict[lang][k] = v
    end
end

function I.GetPlayerLang(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return I.default end
    local lang = normalize(ply:GetNWString("verse_lang", ""))
    if lang and isSupported(lang) then return lang end
    return I.default
end

function I.T(key, vars, lang)
    if not isstring(key) or key == "" then return "" end

    lang = normalize(lang) or I.default
    local fb = I.fallback

    local langDict = I.dict[lang]
    local raw = getPath(langDict, key)

    if raw == nil and fb and fb ~= lang then
        local fbDict = I.dict[fb]
        raw = getPath(fbDict, key)
    end

    if raw == nil then
        return fmt(key, vars)
    end

    if istable(raw) and vars and vars.count ~= nil then
        local s = pickPlural(lang, raw, vars.count)
        if isstring(s) then return fmt(s, vars) end
    end

    if isstring(raw) then
        return fmt(raw, vars)
    end

    return tostring(raw)
end

local meta = FindMetaTable("Player")
function meta:GetLang()
    return I.GetPlayerLang(self)
end

function meta:L(key, vars, forcedLang)
    return I.T(key, vars, forcedLang or self:GetLang())
end

function VERSE.L(a, b, c, d)
    local ply, key, vars, forcedLang

    if IsValid(a) and a:IsPlayer() then
        ply = a
        key = b
        vars = c
        forcedLang = d
    else
        key = a
        vars = b
        forcedLang = c
    end

    if forcedLang ~= nil then
        return I.T(key, vars, forcedLang)
    end

    if IsValid(ply) then
        return I.T(key, vars, ply:GetLang())
    end

    if CLIENT then
        local lp = LocalPlayer()
        if IsValid(lp) then
            return I.T(key, vars, lp:GetLang())
        end
    end

    return I.T(key, vars, nil)
end