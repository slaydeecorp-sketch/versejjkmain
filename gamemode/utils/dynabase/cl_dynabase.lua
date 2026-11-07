VERSE.DynaBase = VERSE.DynaBase or {}
local DB = VERSE.DynaBase

local PREF_PATH = "verse/dynabase_prefs.json"

local function LoadPrefs()
    local raw = file.Read(PREF_PATH, "DATA")
    if not raw or raw == "" then return end

    local tbl = util.JSONToTable(raw)
    if not istable(tbl) then return end

    if istable(tbl.enabled) then
        for id, st in pairs(tbl.enabled) do
            if DB.Packs[id] ~= nil then
                DB.Enabled[id] = st and true or false
            end
        end
    end

    if istable(tbl.order) then
        DB.SetOrder(tbl.order)
    end
end

local function SavePrefs()
    local data = {
        enabled = DB.Enabled,
        order = DB.PackOrder,
    }
    file.CreateDir("verse")
    file.Write(PREF_PATH, util.TableToJSON(data, true))
end

local function WOSReadyClient()
    if not wOS or not wOS.DynaBase or not isfunction(wOS.DynaBase.RegisterSource) then
        return false, "wOS.DynaBase missing"
    end
    if not wOS.AnimExtension then wOS.AnimExtension = {} end
    if not istable(wOS.AnimExtension.Mounted) then wOS.AnimExtension.Mounted = {} end
    if not IncludeModel or not isfunction(IncludeModel) then
        return false, "IncludeModel missing (sh_mounting.lua not loaded?)"
    end
    return true
end

local function EnsureMounted()
    if DB._mountedOnce then return true end

    local ok, why = WOSReadyClient()
    if not ok then
        DB.Log("dynabase.skip_registration", { why = tostring(why) })
        return false
    end

    for _, id in ipairs(DB.PackOrder) do
        local pack = DB.Packs[id]
        if not pack then continue end
        if not DB.Enabled[id] then continue end

        local mountName = pack.mount_name or id
        local validate = pack.validate_files == true

        if not wOS.AnimExtension.Mounted[mountName] then
            wOS.AnimExtension.Mounted[mountName] = true
            DB.Log("dynabase.mounted_extension", { mountName = mountName })
        end

        local models = DB.Unique(DB.BuildModelList(pack))
        if #models == 0 then
            DB.Log("dynabase.no_models_in_pack", { mountName = mountName, id = id })
            continue
        end

        local typ = pack.type or (WOS_DYNABASE and WOS_DYNABASE.EXTENSION) or 2
        local gender = pack.gender or (WOS_DYNABASE and WOS_DYNABASE.SHARED) or 1

        for i, mdl in ipairs(models) do
            if validate and not DB.ValidateModel(mdl, true) then
                DB.Log("dynabase.missing_file", { mdl = mdl })
                continue
            end

            local srcName = string.format("%s #%d (%s)", mountName, i, id)
            if DB._registeredSources[srcName] then continue end
            DB._registeredSources[srcName] = true

            wOS.DynaBase:RegisterSource({
                Name = srcName,
                Type = typ,
                Shared = (gender == (WOS_DYNABASE and WOS_DYNABASE.SHARED) or gender == 1) and mdl or nil,
                Male = (WOS_DYNABASE and gender == WOS_DYNABASE.MALE) and mdl or nil,
                Female = (WOS_DYNABASE and gender == WOS_DYNABASE.FEMALE) and mdl or nil,
                Zombie = (WOS_DYNABASE and gender == WOS_DYNABASE.ZOMBIE) and mdl or nil,
            })

            DB.Log("dynabase.registered", { srcName = srcName, mdl = mdl })
        end
    end

    DB._mountedOnce = true
    return true
end

local function IncludeForGender(gender)
    if not EnsureMounted() then return end

    DB._includedCache[gender] = DB._includedCache[gender] or {}
    local cache = DB._includedCache[gender]

    for _, id in ipairs(DB.PackOrder) do
        if not DB.Enabled[id] then continue end

        local pack = DB.Packs[id]
        if not pack then continue end
        if pack.gender and WOS_DYNABASE and gender ~= pack.gender then continue end

        local validate = pack.validate_files == true
        local models = DB.Unique(DB.BuildModelList(pack))

        for _, mdl in ipairs(models) do
            if cache[mdl] then continue end
            if validate and not DB.ValidateModel(mdl, true) then
                DB.Log("dynabase.skip_include_missing", { mdl = mdl })
                continue
            end
            cache[mdl] = true
            IncludeModel(mdl)
        end
    end
end

VERSE.Hook.AddNS("Dynabase", "PreLoadAnimations", "VERSE.DynaBase.PreLoadAnimations", function(gender)
    IncludeForGender(gender)
end)

function DB.Apply(force)
    local now = CurTime()
    if not force and (now - (DB._lastApply or 0)) < 0.75 then
        DB.Log("dynabase.apply_cooldown")
        return
    end

    DB._lastApply = now
    EnsureMounted()

    RunConsoleCommand("wos_dynabase_live_reload", "1")
    RunConsoleCommand("wos_dynabase_reloadmodels")
    DB.Log("dynabase.triggered_reload")
end

net.Receive("VERSE.DynaBase.Sync", function()
    local hasPolicy = net.ReadBool()

    if not hasPolicy then
        LoadPrefs()
        EnsureMounted()
        return
    end

    local orderCount = net.ReadUInt(16)
    local order = {}
    for i = 1, orderCount do order[i] = net.ReadString() end
    DB.SetOrder(order)

    local enabledCount = net.ReadUInt(16)
    local enabled = {}
    for i = 1, enabledCount do
        local id = net.ReadString()
        local st = net.ReadBool()
        enabled[id] = st
    end

    for id, st in pairs(enabled) do
        if DB.Packs[id] then
            DB.Enabled[id] = st and true or false
        end
    end

    DB._mountedOnce = false
    DB._includedCache = {}

    EnsureMounted()
    DB.Apply(true)
end)

net.Receive("VERSE.DynaBase.Apply", function()
    DB.Apply(true)
end)

VERSE.Hook.AddNS("Dynabase", "InitPostEntity", "VERSE.DynaBase.Init", function()
    timer.Simple(0, function()
        LoadPrefs()
        EnsureMounted()
    end)
end)

VERSE.Commands.Add("verse_animations_apply", function()
    DB.Apply(true)
end)

VERSE.Commands.Add("verse_animations_save", function()
    SavePrefs()
    DB.Log("dynabase.saved_prefs")
end)