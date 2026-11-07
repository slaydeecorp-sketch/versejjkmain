VERSE.Fonts = VERSE.Fonts or {}

local F = VERSE.Fonts
F._created = F._created or {}
F._rev = F._rev or 0

local function logWarn(msg)
    if VERSE.Log and VERSE.Log.Warn then
        VERSE.Log:Warn(msg)
    else
        MsgC(Color(255, 200, 0), "[VERSE][Fonts] ", color_white, msg .. "\n")
    end
end

local function getCfg()
    return (VERSE.Config and VERSE.Config.Fonts) or nil
end

local function isEnabled()
    local cfg = getCfg()
    return not cfg or cfg.Enabled ~= false
end

local function clampSize(n)
    n = tonumber(n) or 16
    if n < 8 then n = 8 end
    if n > 128 then n = 128 end
    return n
end

local function round(n)
    return (n >= 0) and math.floor(n + 0.5) or math.ceil(n - 0.5)
end

local function normalizeBool(v) return v == true end

local function merge(dst, src)
    if not istable(src) then return dst end
    for k, v in pairs(src) do
        if v ~= nil then dst[k] = v end
    end
    return dst
end

local function getGlobalScale()
    if VERSE and VERSE.Responsive and VERSE.Responsive.GetScale then
        return tonumber(VERSE.Responsive:GetScale()) or 1
    end

    return 1
end

local function safeCreateFont(name, spec)
    local ok, err = pcall(surface.CreateFont, name, {
        font = spec.font,
        size = spec.size,
        weight = spec.weight,
        antialias = spec.antialias,
        extended = spec.extended,
        additive = spec.additive,
        outline = spec.outline,
        shadow = spec.shadow,
        italic = spec.italic,
        underline = spec.underline,
        strikeout = spec.strikeout,
        blursize = spec.blursize,
        scanlines = spec.scanlines,
    })

    if not ok then
        logWarn(("surface.CreateFont failed (%s): %s"):format(tostring(name), tostring(err)))
        return false
    end

    return true
end

local function makeKey(parts)
    return table.concat(parts, "|")
end

local function shortHash(s)
    local h = util.CRC(tostring(s))
    return string.sub(tostring(h), 1, 8)
end

local function buildNamedSpec(family, variant, size, opts)
    local cfg = getCfg() or {}
    local defaults = cfg.Defaults or {}
    local fams = cfg.Families or {}

    family = tostring(family or "")
    if family == "" then
        return nil, "GetNamed: family is empty"
    end

    local fam = fams[family]
    if not istable(fam) then
        return nil, ("GetNamed: unknown family '%s'"):format(family)
    end

    if tonumber(variant) and (size == nil) then
        size = tonumber(variant)
        variant = nil
    end

    local defaultVariant = tostring(cfg.DefaultVariant or "Regular")
    variant = (variant ~= nil and tostring(variant)) or defaultVariant
    if variant == "" then variant = defaultVariant end

    local v = fam[variant]
    if not istable(v) then
        return nil, ("GetNamed: unknown variant '%s' for family '%s'"):format(variant, family)
    end

    size = clampSize(size)
    opts = istable(opts) and opts or {}

    local spec = {}
    merge(spec, defaults)
    merge(spec, v)
    merge(spec, opts)

    local globalScale = getGlobalScale()
    local localScale = tonumber(spec.scale) or 1
    spec.size = clampSize(round(size * globalScale * localScale))
    spec.font = spec.font or "DermaDefault"
    spec.weight = tonumber(spec.weight) or 500
    spec.antialias = normalizeBool(spec.antialias)
    spec.extended = normalizeBool(spec.extended)
    spec.additive = normalizeBool(spec.additive)
    spec.outline = normalizeBool(spec.outline)
    spec.shadow = normalizeBool(spec.shadow)
    spec.italic = normalizeBool(spec.italic)
    spec.underline = normalizeBool(spec.underline)
    spec.strikeout = normalizeBool(spec.strikeout)
    spec.blursize = tonumber(spec.blursize) or 0
    spec.scanlines = tonumber(spec.scanlines) or 0

    return spec, nil, defaultVariant, family, variant
end

local function buildFontName(family, variant, defaultVariant, spec, keyHash)
    local nameParts = { "VERSE", family }

    local useVariantInName = (variant ~= defaultVariant)
    if useVariantInName then
        nameParts[#nameParts + 1] = variant
    end

    if spec.italic then
        nameParts[#nameParts + 1] = "Italic"
    end

    nameParts[#nameParts + 1] = tostring(spec.size)

    local baseName = table.concat(nameParts, ".")

    if keyHash and keyHash ~= "" then
        return baseName .. "." .. keyHash
    end

    return baseName
end

function F:GetNamed(family, variant, size, opts)
    if not isEnabled() then return "DermaDefault" end

    local spec, err, defaultVariant, famName, varName = buildNamedSpec(family, variant, size, opts)
    if not spec then
        logWarn(err or "GetNamed: build spec failed")
        return "DermaDefault"
    end

    local key = makeKey({
        "named",
        tostring(famName), tostring(varName),
        tostring(spec.font),
        tostring(spec.size),
        tostring(spec.weight),
        tostring(spec.antialias),
        tostring(spec.extended),
        tostring(spec.additive),
        tostring(spec.outline),
        tostring(spec.shadow),
        tostring(spec.italic),
        tostring(spec.underline),
        tostring(spec.strikeout),
        tostring(spec.blursize),
        tostring(spec.scanlines),
        tostring(self._rev or 0),
    })

    local existing = self._created[key]
    if existing then
        return existing
    end

    local keyHash = shortHash(key)
    local fontName = buildFontName(famName, varName, defaultVariant, spec, keyHash)

    self._created[key] = fontName
    safeCreateFont(fontName, spec)

    return fontName
end

function F:Get(path, opts)
    if not isEnabled() then return "DermaDefault" end
    if type(path) ~= "string" then return "DermaDefault" end

    local parts = string.Explode(".", path)
    if parts[1] ~= "VERSE" or not parts[2] then
        return path
    end

    local last = parts[#parts]
    local prev = parts[#parts - 1]
    if last and prev
        and string.match(last, "^%d%d%d%d%d%d%d%d$")
        and tonumber(prev)
    then
        return path
    end

    local family = parts[2]
    local size = tonumber(parts[#parts])
    if not size then
        logWarn(("Fonts:Get: invalid size in '%s'"):format(path))
        return "DermaDefault"
    end

    local italic = false
    local variant = nil

    for i = 3, #parts - 1 do
        local p = parts[i]
        if p == "Italic" then
            italic = true
        else
            variant = p
        end
    end

    opts = istable(opts) and opts or {}
    if italic then
        opts = table.Copy(opts)
        opts.italic = true
    end

    return self:GetNamed(family, variant, size, opts)
end

function F:Rebuild()
    self._rev = (self._rev or 0) + 1
    self._created = {}
end

VERSE.Hook.AddNS("Fonts", "OnScreenSizeChanged", "VERSE::OnScreenSizeChanged::Fonts", function()
    local cfg = getCfg()
    if not cfg or cfg.AutoRebuildOnScaleChange == false then return end
    if VERSE and VERSE.Fonts and VERSE.Fonts.Rebuild then
        VERSE.Fonts:Rebuild()
    end
end)

VERSE.Hook.AddNS("Fonts", "InitPostEntity", "VERSE::InitPostEntity::Fonts", function()
    local cfg = getCfg()
    if not cfg or cfg.AutoRebuildOnScaleChange == false then return end
    if VERSE and VERSE.Fonts and VERSE.Fonts.Rebuild then
        VERSE.Fonts:Rebuild()
    end
end)