GM.Name = "MangaRP"
GM.Author = "king_of_the_squirt"
DeriveGamemode("sandbox")

VERSE = VERSE or {}
VERSE.Flags = VERSE.Flags or {}
VERSE.Hot = VERSE.Hot or {}
VERSE.Hot._state = VERSE.Hot._state or {}
VERSE.Hot._known = VERSE.Hot._known or {}
VERSE.Hot._root = VERSE.Hot._root or nil
VERSE.Flags.FullReload = (VERSE.Flags.FullReload ~= nil) and VERSE.Flags.FullReload or false
VERSE.Flags.AutoInit = (VERSE.Flags.AutoInit ~= nil) and VERSE.Flags.AutoInit or true
VERSE._didInit = VERSE._didInit or false
VERSE.ExternalLoaded = VERSE.ExternalLoaded or {}
VERSE.Path = VERSE.Path or {}

local FolderName = GM.FolderName
function VERSE.Path.GMFolder()
    local gm = FolderName or engine.ActiveGamemode() or "verse"
    return gm
end

function VERSE.Path.GM(rel)
    rel = tostring(rel or ""):gsub("^/+", "")
    return VERSE.Path.GMFolder() .. "/gamemode/" .. rel
end

local function realmTag()
    return SERVER and "SV" or "CL"
end

local function logInfo(...)
    MsgC(color_white, ("[VERSE][%s] "):format(realmTag()))
    MsgN(...)
end

local function logWarn(...)
    MsgC(Color(255, 200, 0), ("[VERSE][%s][WARN] "):format(realmTag()))
    MsgN(...)
end

local function logErr(...)
    MsgC(Color(255, 80, 80), ("[VERSE][%s][ERR] "):format(realmTag()))
    MsgN(...)
end

VERSE.Boot = VERSE.Boot or {
    total = 0,
    ok = 0,
    err = 0,
    byPhase = {},
    errors = {},
    startedAt = 0,
}

local function bootReset()
    VERSE.Boot.total = 0
    VERSE.Boot.ok = 0
    VERSE.Boot.err = 0
    VERSE.Boot.byPhase = {}
    VERSE.Boot.errors = {}
    VERSE.Boot.startedAt = SysTime()
    VERSE.Boot._summarized = false
end

local function bootPhaseEnsure(phase)
    local p = VERSE.Boot.byPhase[phase]
    if not p then
        p = {
            total = 0,
            ok = 0,
            err = 0
        }

        VERSE.Boot.byPhase[phase] = p
    end
    return p
end

local function bootAddOk(phase)
    local p = bootPhaseEnsure(phase)
    VERSE.Boot.total = VERSE.Boot.total + 1
    VERSE.Boot.ok = VERSE.Boot.ok + 1
    p.total = p.total + 1
    p.ok = p.ok + 1
end

local function bootAddErr(phase, path, err)
    local p = bootPhaseEnsure(phase)
    VERSE.Boot.total = VERSE.Boot.total + 1
    VERSE.Boot.err = VERSE.Boot.err + 1
    p.total = p.total + 1
    p.err = p.err + 1
    table.insert(VERSE.Boot.errors, {
        path = path,
        err = err
    })
end

local function bootSummary()
    local dt = SysTime() - (VERSE.Boot.startedAt or SysTime())
    logInfo(("Boot summary: ok=%d, err=%d, total=%d (%.3fs)"):format(VERSE.Boot.ok, VERSE.Boot.err, VERSE.Boot.total, dt))
    for _, phase in ipairs(VERSE.LoadPhases or {}) do
        local p = VERSE.Boot.byPhase[phase]
        if p then
            logInfo((" - %s: ok=%d, err=%d, total=%d"):format(phase, p.ok, p.err, p.total))
        else
            logInfo((" - %s: (no files)"):format(phase))
        end
    end

    if VERSE.Boot.err > 0 then
        logWarn("Errors:")
        for i = 1, math.min(#VERSE.Boot.errors, 10) do
            local e = VERSE.Boot.errors[i]
            logErr((" %d) %s -> %s"):format(i, tostring(e.path), tostring(e.err)))
        end

        if #VERSE.Boot.errors > 10 then logWarn((" ...and %d more"):format(#VERSE.Boot.errors - 10)) end
    end
end

local function bootSummaryOnce(tag)
    if VERSE.Boot._summarized then return end
    VERSE.Boot._summarized = true
    if tag then logInfo("Boot summary tag:", tag) end
    bootSummary()
end

local function extKey(name)
    return tostring(name) .. "@" .. (SERVER and "SV" or "CL")
end

local function extBaseNameFromDir(addonBaseDir)
    return string.GetFileFromFilename(addonBaseDir)
end

local function isExternalLuaAddonFolder(baseDir)
    return file.Exists(baseDir .. "/lua", "LUA") or (select(2, file.Find(baseDir .. "/lua/*", "LUA")) ~= nil)
end

local function extPatchLuaFuncs(rootLuaDir, fn)
    local _include = include
    local _AddCSLuaFile = AddCSLuaFile
    local function normalizeGamemodePrefix(p)
        if not isstring(p) then return p end
        local gm = VERSE.Path.GMFolder() or (GM and GM.FolderName) or "verse"
        if string.StartWith(p, "verse/") and gm ~= "verse" then p = gm .. "/" .. string.sub(p, #"verse/" + 1) end
        if string.StartWith(p, "gamemodes/verse/") and gm ~= "verse" then p = "gamemodes/" .. gm .. "/" .. string.sub(p, #"gamemodes/verse/" + 1) end
        return p
    end

    local function resolve(relPath)
        relPath = normalizeGamemodePrefix(relPath)
        if file.Exists(relPath, "LUA") then return relPath end
        local prefixed = rootLuaDir .. "/" .. relPath
        if file.Exists(prefixed, "LUA") then return prefixed end
        if string.StartWith(relPath, "lua/") then
            local rel2 = string.sub(relPath, 5)
            local pref2 = rootLuaDir .. "/" .. rel2
            if file.Exists(pref2, "LUA") then return pref2 end
        end
        return relPath
    end

    include = function(path) return _include(resolve(path)) end
    AddCSLuaFile = function(path) return _AddCSLuaFile(resolve(path)) end
    local ok, err = pcall(fn)
    include = _include
    AddCSLuaFile = _AddCSLuaFile
    return ok, err
end

local function extIncludeAutorunFile(rootLuaDir, fullAutorunPath, phaseTag)
    local fileName = string.GetFileFromFilename(fullAutorunPath)
    local isCL = string.StartWith(fileName, "cl_")
    local isSV = string.StartWith(fileName, "sv_")
    local isSH = string.StartWith(fileName, "sh_")
    local function run()
        return extPatchLuaFuncs(rootLuaDir, function() include(fullAutorunPath) end)
    end

    if SERVER then
        AddCSLuaFile(fullAutorunPath)
        if isSV or isSH or (not isCL) then
            local ok, err = run()
            if ok then
                bootAddOk(phaseTag)
            else
                bootAddErr(phaseTag, fullAutorunPath, err)
            end
        else
            bootAddOk(phaseTag)
        end
    else
        if isCL or isSH or (not isSV) then
            local ok, err = run()
            if ok then
                bootAddOk(phaseTag)
            else
                bootAddErr(phaseTag, fullAutorunPath, err)
            end
        else
            bootAddOk(phaseTag)
        end
    end
end

local function extAddCSLuaFileRecursive(rootLuaDir)
    if not SERVER then return end
    local function walk(dir)
        local files, dirs = file.Find(dir .. "/*", "LUA")
        files = files or {}
        dirs = dirs or {}
        for _, f in ipairs(files) do
            if string.EndsWith(f, ".lua") then AddCSLuaFile(dir .. "/" .. f) end
        end

        for _, d in ipairs(dirs) do
            walk(dir .. "/" .. d)
        end
    end

    walk(rootLuaDir)
end

local function loadExternalLuaAddon(addonBaseDir, phaseTag, cfg)
    local addonName = extBaseNameFromDir(addonBaseDir)
    local key = extKey(addonName)
    if VERSE.ExternalLoaded[key] then
        logInfo("External addon skipped (already loaded):", addonBaseDir)
        return
    end

    cfg = cfg or {}
    if cfg.enabled == false then
        logInfo("External addon skipped (disabled):", addonBaseDir)
        VERSE.ExternalLoaded[key] = true
        return
    end

    if cfg.realm == "client" and SERVER then
        logInfo("External addon skipped (client-only):", addonBaseDir)
        VERSE.ExternalLoaded[key] = true
        return
    end

    if cfg.realm == "server" and CLIENT then
        logInfo("External addon skipped (server-only):", addonBaseDir)
        VERSE.ExternalLoaded[key] = true
        return
    end

    local rootLuaDir = addonBaseDir .. "/lua"
    if SERVER and cfg.skipInit ~= true then extAddCSLuaFileRecursive(rootLuaDir) end
    if cfg.skipInit == true then
        logInfo("External addon: files present, init skipped by config:", addonBaseDir)
        VERSE.ExternalLoaded[key] = true
        return
    end

    local glob = cfg.autorunGlob or "lua/autorun/*.lua"
    local autorunPattern = addonBaseDir .. "/" .. glob
    local autorunFiles = file.Find(autorunPattern, "LUA") or {}
    table.sort(autorunFiles, function(a, b) return a:lower() < b:lower() end)
    if #autorunFiles == 0 then
        logWarn("External addon has no autorun files:", autorunPattern)
        VERSE.ExternalLoaded[key] = true
        return
    end

    logInfo("External addon:", addonBaseDir)
    local autorunDir = string.GetPathFromFilename(autorunPattern)
    autorunDir = string.TrimRight(autorunDir, "/")
    for _, f in ipairs(autorunFiles) do
        extIncludeAutorunFile(rootLuaDir, autorunDir .. "/" .. f, phaseTag)
    end

    VERSE.ExternalLoaded[key] = true
end

VERSE.LoadPhases = {"config", "libraries", "utils", "modules",}
VERSE.SubOrder = VERSE.SubOrder or {
    libraries = {"database", "responsive",},
    utils = {"hook", "commands", "i18n", "promise", "database", "timers", "fonts",},
    modules = {"characters"},
}

VERSE.ExternalAddons = VERSE.ExternalAddons or {
    ["paint"] = {
        enabled = true,
        skipInit = false,
        realm = "both",
        autorunGlob = "lua/autorun/*.lua",
    },
    ["epoe"] = {
        enabled = true,
        skipInit = false,
        realm = "both",
        autorunGlob = "lua/autorun/*.lua",
    },
    ["luadev"] = {
        enabled = true,
        skipInit = false,
        realm = "both",
        autorunGlob = "lua/autorun/*.lua",
    },
    ["sqlworkbench"] = {
        enabled = true,
        skipInit = false,
        realm = "both",
        autorunGlob = "lua/autorun/*.lua",
    },
}

local function includeByRealm(fullPath, fileName, phase)
    local isCL = string.StartWith(fileName, "cl_")
    local isSV = string.StartWith(fileName, "sv_")
    local isSH = string.StartWith(fileName, "sh_")
    local function safeInclude()
        return include(fullPath)
    end

    if SERVER then
        if isCL or isSH then AddCSLuaFile(fullPath) end
        if isSV or isSH then
            local ok, err = pcall(safeInclude)
            if ok then
                bootAddOk(phase)
            else
                bootAddErr(phase, fullPath, err)
            end
        end
    else
        if isCL or isSH then
            local ok, err = pcall(safeInclude)
            if ok then
                bootAddOk(phase)
            else
                bootAddErr(phase, fullPath, err)
            end
        end
    end
end

local function shouldLoadFile(fileName)
    return string.StartWith(fileName, "cl_") or string.StartWith(fileName, "sv_") or string.StartWith(fileName, "sh_")
end

local function folderExists(path)
    local _, dirs = file.Find(path .. "/*", "LUA")
    return dirs ~= nil
end

local function loadFolderFilesOrdered(folder, phase)
    local files = file.Find(folder .. "/*", "LUA") or {}
    table.sort(files, function(a, b) return a:lower() < b:lower() end)
    for _, f in ipairs(files) do
        if string.StartWith(f, "sh_") and shouldLoadFile(f) then includeByRealm(folder .. "/" .. f, f, phase) end
    end

    if SERVER then
        for _, f in ipairs(files) do
            if string.StartWith(f, "sv_") and shouldLoadFile(f) then includeByRealm(folder .. "/" .. f, f, phase) end
        end
    end

    for _, f in ipairs(files) do
        if string.StartWith(f, "cl_") and shouldLoadFile(f) then includeByRealm(folder .. "/" .. f, f, phase) end
    end
end

local function loadFolderRecursive(folder, phase)
    local _, dirs = file.Find(folder .. "/*", "LUA")
    dirs = dirs or {}
    table.sort(dirs, function(a, b) return a:lower() < b:lower() end)
    loadFolderFilesOrdered(folder, phase)
    for _, subDir in ipairs(dirs) do
        loadFolderRecursive(folder .. "/" .. subDir, phase)
    end
end

local function loadPhase(root, phase)
    local phasePath = root .. phase
    if not folderExists(phasePath) then
        logInfo("Phase:", phase, "(missing)")
        return
    end

    logInfo("Phase:", phase)
    loadFolderFilesOrdered(phasePath, phase)
    local _, allDirs = file.Find(phasePath .. "/*", "LUA")
    allDirs = allDirs or {}
    if phase == "libraries" then
        for name, cfg in pairs(VERSE.ExternalAddons or {}) do
            local addonDir = phasePath .. "/" .. name
            if folderExists(addonDir) and isExternalLuaAddonFolder(addonDir) then loadExternalLuaAddon(addonDir, phase, cfg) end
        end
    end

    local dirSet = {}
    for _, d in ipairs(allDirs) do
        dirSet[d] = true
    end

    if phase == "libraries" and VERSE.ExternalAddons then
        for name, cfg in pairs(VERSE.ExternalAddons) do
            if cfg.enabled ~= false then dirSet[name] = nil end
        end
    end

    local order = (VERSE.SubOrder and VERSE.SubOrder[phase]) or {}
    for _, sub in ipairs(order) do
        if dirSet[sub] then
            loadFolderRecursive(phasePath .. "/" .. sub, phase)
            dirSet[sub] = nil
        end
    end

    local rest = {}
    for d, _ in pairs(dirSet) do
        table.insert(rest, d)
    end

    table.sort(rest, function(a, b) return a:lower() < b:lower() end)
    for _, sub in ipairs(rest) do
        loadFolderRecursive(phasePath .. "/" .. sub, phase)
    end
end

local function hotReadCRC(fullPath)
    local body = file.Read(fullPath, "LUA")
    if not body then return nil end
    return util.CRC(body)
end

local function hotShouldLoadFile(fileName)
    return string.StartWith(fileName, "cl_") or string.StartWith(fileName, "sv_") or string.StartWith(fileName, "sh_")
end

local function hotFolderExists(path)
    local _, dirs = file.Find(path .. "/*", "LUA")
    return dirs ~= nil
end

function VERSE.Hot._CollectFolderFilesOrdered(folder)
    local files = file.Find(folder .. "/*", "LUA") or {}
    table.sort(files, function(a, b) return a:lower() < b:lower() end)
    local out = {}
    for _, f in ipairs(files) do
        if string.StartWith(f, "sh_") and hotShouldLoadFile(f) then table.insert(out, folder .. "/" .. f) end
    end

    if SERVER then
        for _, f in ipairs(files) do
            if string.StartWith(f, "sv_") and hotShouldLoadFile(f) then table.insert(out, folder .. "/" .. f) end
        end
    end

    for _, f in ipairs(files) do
        if string.StartWith(f, "cl_") and hotShouldLoadFile(f) then table.insert(out, folder .. "/" .. f) end
    end
    return out
end

function VERSE.Hot._CollectFolderRecursive(folder, out)
    out = out or {}
    local _, dirs = file.Find(folder .. "/*", "LUA")
    dirs = dirs or {}
    table.sort(dirs, function(a, b) return a:lower() < b:lower() end)
    local ordered = VERSE.Hot._CollectFolderFilesOrdered(folder)
    for _, p in ipairs(ordered) do
        table.insert(out, p)
    end

    for _, subDir in ipairs(dirs) do
        VERSE.Hot._CollectFolderRecursive(folder .. "/" .. subDir, out)
    end
    return out
end

function VERSE.Hot.CollectAll()
    local root = VERSE.Hot._root
    if not root then
        root = VERSE.Path.GM()
        VERSE.Hot._root = root
    end

    local all = {}
    for _, phase in ipairs(VERSE.LoadPhases or {}) do
        local phasePath = root .. phase
        if hotFolderExists(phasePath) then
            local phaseRootFiles = VERSE.Hot._CollectFolderFilesOrdered(phasePath)
            for _, p in ipairs(phaseRootFiles) do
                table.insert(all, p)
            end

            local _, allDirs = file.Find(phasePath .. "/*", "LUA")
            allDirs = allDirs or {}
            local dirSet = {}
            for _, d in ipairs(allDirs) do
                dirSet[d] = true
            end

            local order = (VERSE.SubOrder and VERSE.SubOrder[phase]) or {}
            for _, sub in ipairs(order) do
                if dirSet[sub] then
                    VERSE.Hot._CollectFolderRecursive(phasePath .. "/" .. sub, all)
                    dirSet[sub] = nil
                end
            end

            local rest = {}
            for d, _ in pairs(dirSet) do
                table.insert(rest, d)
            end

            table.sort(rest, function(a, b) return a:lower() < b:lower() end)
            for _, sub in ipairs(rest) do
                VERSE.Hot._CollectFolderRecursive(phasePath .. "/" .. sub, all)
            end
        end
    end
    return all
end

local function hotIncludeByRealm(fullPath, phaseTag)
    local fileName = string.GetFileFromFilename(fullPath)
    local isCL = string.StartWith(fileName, "cl_")
    local isSV = string.StartWith(fileName, "sv_")
    local isSH = string.StartWith(fileName, "sh_")
    local function safeInclude()
        return include(fullPath)
    end

    if SERVER then
        if isCL or isSH then AddCSLuaFile(fullPath) end
        if isSV or isSH then
            if VERSE.Hook then VERSE.Hook.Call("PreHotReloadFile", fullPath) end
            local ok, err = pcall(safeInclude)
            if not ok then
                logErr(("HotReload failed [%s]: %s -> %s"):format(phaseTag or "?", fullPath, err))
                return false, err
            end

            if VERSE.Hook then VERSE.Hook.Call("PostHotReloadFile", fullPath) end
            return true
        end
        return true
    else
        if isCL or isSH then
            if VERSE.Hook then VERSE.Hook.Call("PreHotReloadFile", fullPath) end
            local ok, err = pcall(safeInclude)
            if not ok then
                logErr(("HotReload failed [%s]: %s -> %s"):format(phaseTag or "?", fullPath, err))
                return false, err
            end

            if VERSE.Hook then VERSE.Hook.Call("PostHotReloadFile", fullPath) end
            return true
        end
        return true
    end
end

function VERSE.Hot.Diff(filterSubstr)
    local files = VERSE.Hot.CollectAll()
    local changed, added = {}, {}
    for _, p in ipairs(files) do
        if not filterSubstr or string.find(p, filterSubstr, 1, true) then
            local crc = hotReadCRC(p)
            if crc then
                local old = VERSE.Hot._state[p]
                if old == nil then
                    table.insert(added, p)
                elseif old ~= crc then
                    table.insert(changed, p)
                end
            end

            VERSE.Hot._known[p] = true
        end
    end
    return changed, added
end

function VERSE.Hot.Commit(paths)
    for _, p in ipairs(paths or {}) do
        local crc = hotReadCRC(p)
        if crc then VERSE.Hot._state[p] = crc end
    end
end

function VERSE.Hot.Reload(options)
    options = options or {}
    if VERSE.Hook then VERSE.Hook.Call("PreHotReload", options) end
    local filter = options.filter
    local files = VERSE.Hot.CollectAll()
    local targets = {}
    if options.forceAll then
        for _, p in ipairs(files) do
            if (not filter) or string.find(p, filter, 1, true) then table.insert(targets, p) end
        end
    else
        local changed, added = VERSE.Hot.Diff(filter)
        for _, p in ipairs(added) do
            table.insert(targets, p)
        end

        for _, p in ipairs(changed) do
            table.insert(targets, p)
        end
    end

    if #targets == 0 then
        logInfo("HotReload: nothing changed")
        if VERSE.Hook then VERSE.Hook.Call("PostHotReload", options) end
        return true, 0
    end

    logInfo(("HotReload: reloading %d file(s)"):format(#targets))
    local okCount = 0
    for _, p in ipairs(targets) do
        local ok = hotIncludeByRealm(p, "hot")
        if ok then okCount = okCount + 1 end
    end

    VERSE.Hot.Commit(targets)
    if VERSE.Hook then VERSE.Hook.Call("PostHotReload", options) end
    return true, okCount
end

function VERSE:Init()
    bootReset()
    local root = VERSE.Path.GM()
    logInfo("Boot start:", root)
    for _, phase in ipairs(self.LoadPhases) do
        loadPhase(root, phase)
    end

    bootSummaryOnce("after_phases")
    if VERSE.Hot and VERSE.Hot.Commit then
        local all = VERSE.Hot.CollectAll()
        VERSE.Hot.Commit(all)
    end

    if VERSE.Particles and VERSE.Particles.Load then
        local ok, err = pcall(function() VERSE.Particles:Load() end)
        if not ok then
            logErr("Particles:Load failed:", err)
        else
            logInfo("Particles:Load called")
        end
    end

    local function startAfterDBReady(reason)
        if VERSE._didPostDBStart then return end
        VERSE._didPostDBStart = true
        logInfo("Post-DB start:", reason or "db_ready")
        if SERVER then resource.AddWorkshop("3126986993") end
    end

    if CLIENT then
        startAfterDBReady("client_no_db")
        return
    end

    if SERVER and VERSE.DB and VERSE.DB.Init then
        local ok, err = pcall(function() VERSE.DB:Init() end)
        if not ok then
            logErr("DB:Init failed:", err)
            startAfterDBReady("db_init_failed")
            return
        end

        logInfo("DB:Init called")
    else
        startAfterDBReady("no_db_system")
        return
    end

    logInfo("Waiting for DB ready signal...")
    if VERSE.DB and VERSE.DB.OnReady then
        local ok, err = pcall(function() VERSE.DB:OnReady(function() startAfterDBReady("db_ready_callback") end) end)
        if not ok then
            logErr("DB:OnReady call failed:", err)
            startAfterDBReady("db_onready_failed")
        end
    else
        startAfterDBReady("db_no_onready")
    end
end

function GM:Initialize()
    MsgN("Gamemode Initialized - " .. os.date("%H:%M:%S", os.time()))
end

function GM:OnReloaded()
    MsgN("Gamemode Reloaded - " .. os.date("%H:%M:%S", os.time()))
    if not (VERSE and VERSE.Flags and VERSE.Flags.FullReload) then
        MsgN("[VERSE] OnReloaded: full init skipped")
        return
    end

    VERSE.Flags.FullReload = false
    if VERSE.Hook then VERSE.Hook.Call("PreReload") end
    if VERSE.Init then VERSE:Init() end
    if VERSE.Hook then VERSE.Hook.Call("PostReload") end
end

GAMEMODE = GM