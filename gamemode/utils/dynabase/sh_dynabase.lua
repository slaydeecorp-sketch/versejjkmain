VERSE.DynaBase = VERSE.DynaBase or {}
local DB = VERSE.DynaBase

DB.Packs = DB.Packs or {}
DB.PackOrder = DB.PackOrder or {}
DB.Enabled = DB.Enabled or {}

DB._mountedOnce = DB._mountedOnce or false
DB._registeredSources = DB._registeredSources or {}
DB._includedCache = DB._includedCache or {}
DB._lastApply = DB._lastApply or 0

local function L(key, vars)
    if VERSE.L then return VERSE.L(key, vars) end
    return tostring(key)
end

function DB.Log(key, vars, ...)
    local prefix = L("dynabase.log_prefix")
    local msg = L(key, vars)

    if select("#", ...) > 0 then
        msg = string.format(msg, ...)
    end

    if VERSE.Log and VERSE.Log.Print then
        VERSE.Log:Print(prefix .. msg)
    else
        print(prefix .. msg)
    end
end

function DB.Unique(list)
    local seen, out = {}, {}
    for _, v in ipairs(list or {}) do
        if isstring(v) and v ~= "" and not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    return out
end

function DB.NormalizeModelPath(mdl)
    if not isstring(mdl) then return nil end
    mdl = string.Trim(mdl)
    if mdl == "" then return nil end
    return string.Replace(mdl, "\\", "/")
end

function DB.BuildModelList(pack)
    if not istable(pack) then return {} end

    if istable(pack.models) and #pack.models > 0 then
        local out = {}
        for _, mdl in ipairs(pack.models) do
            mdl = DB.NormalizeModelPath(mdl)
            if mdl then out[#out + 1] = mdl end
        end
        return out
    end

    if isstring(pack.folder) and isstring(pack.file_pattern) and istable(pack.parts) then
        local out = {}
        for _, p in ipairs(pack.parts) do
            local mdl = pack.folder .. string.format(pack.file_pattern, p)
            mdl = DB.NormalizeModelPath(mdl)
            if mdl then out[#out + 1] = mdl end
        end
        return out
    end

    if istable(pack.folder_scan) and isstring(pack.folder_scan.path) then
        local base = DB.NormalizeModelPath(pack.folder_scan.path)
        if not base then return {} end

        local recursive = pack.folder_scan.recursive == true
        local pattern = pack.folder_scan.filter or "*.mdl"
        pattern = DB.NormalizeModelPath(pattern) or "*.mdl"

        local out = {}
        local function scan(dir)
            local files = file.Find(dir .. "/" .. pattern, "GAME")
            for _, f in ipairs(files or {}) do
                local mdl = DB.NormalizeModelPath(dir .. "/" .. f)
                if mdl then out[#out + 1] = mdl end
            end
            if not recursive then return end
            local _, subdirs = file.Find(dir .. "/*", "GAME")
            for _, d in ipairs(subdirs or {}) do
                scan(dir .. "/" .. d)
            end
        end

        scan(base)
        return out
    end

    return {}
end

function DB.ValidateModel(mdl, validate_files)
    if not validate_files then return true end
    return file.Exists(mdl, "GAME")
end

function DB.RegisterPack(pack)
    if not istable(pack) then return false end
    if not isstring(pack.id) or pack.id == "" then return false end

    if not isstring(pack.mount_name) or pack.mount_name == "" then
        pack.mount_name = pack.id
    end

    DB.Packs[pack.id] = pack

    local exists = false
    for _, id in ipairs(DB.PackOrder) do
        if id == pack.id then exists = true break end
    end
    if not exists then
        DB.PackOrder[#DB.PackOrder + 1] = pack.id
    end

    if DB.Enabled[pack.id] == nil then
        DB.Enabled[pack.id] = (pack.default_enabled ~= false)
    end

    return true
end

function DB.SetEnabled(id, state)
    if not isstring(id) or id == "" then return end
    DB.Enabled[id] = state and true or false
end

function DB.SetOrder(order)
    if not istable(order) then return end

    local out, seen = {}, {}
    for _, id in ipairs(order) do
        if isstring(id) and id ~= "" and DB.Packs[id] and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end

    for _, id in ipairs(DB.PackOrder) do
        if DB.Packs[id] and not seen[id] then
            out[#out + 1] = id
        end
    end

    DB.PackOrder = out
end

VERSE.DynaBase.RegisterPack({
    id = "verse_jjk",
    mount_name = "Verse | JJK",
    type = WOS_DYNABASE and WOS_DYNABASE.EXTENSION or 2,
    gender = WOS_DYNABASE and WOS_DYNABASE.SHARED or 1,
    validate_files = true,

    models = {
        "models/jjkf6064/jjk-anims_part1.mdl",
        "models/jjkf6064/jjk-anims_part2.mdl",
        "models/jjkf6064/jjk-anims_part3.mdl",
        "models/jjkf6064/jjk-anims_part4.mdl",
        "models/jjkf6064/jjk-anims_part5.mdl",
        "models/player/anim_extension_mod1.mdl",
        "models/player/anim_extension_mod2.mdl",
        "models/player/anim_extension_mod3.mdl",
        "models/player/anim_judgement.mdl",
        "models/player/anim_phalanx.mdl",
        "models/player/anim_pure.mdl",
        "models/player/anim_ryoku.mdl",
        "models/player/anim_vanguard.mdl",
        "models/player/wiltos/anim_extension_bs.mdl",
        "models/player/wiltos/anim_extension_mod1.mdl",
        "models/player/wiltos/anim_extension_mod2.mdl",
        "models/player/wiltos/anim_extension_mod3.mdl",
        "models/player/wiltos/anim_extension_mod4.mdl",
        "models/player/wiltos/anim_extension_mod5.mdl",
        "models/player/wiltos/anim_extension_mod6.mdl",
        "models/player/wiltos/anim_extension_mod11.mdl",
        "models/player/wiltos/anim_extension_mod12.mdl",
        "models/player/wiltos/anim_extension_mod14.mdl",
    },
})