local L = VERSE.L
local Log = VERSE.Log
local resource_extension_types = {"mdl", "wav", "mp3", "ogg", "aac", "vmt", "vtf", "png", "jpg", "ttf", "pcf"}

local function fmtSeconds(sec)
    sec = tonumber(sec) or 0
    return tostring(math.Round(sec, 2))
end

local function isValidWorkshopID(id)
    id = tostring(id or "")
    return id ~= "" and id ~= "0" and id:match("^%d+$") ~= nil
end

local function traverse(subPath, basePath, found_exts)
    local files, dirs = file.Find(subPath .. "*", basePath)
    if files then
        for _, fileName in ipairs(files) do
            local ext = string.GetExtensionFromFilename(fileName)
            if isstring(ext) and ext ~= "" then
                found_exts[string.lower(ext)] = true
            end
        end
    else
        Log:Warn(L("workshop.scan_failed_files", {
            subPath = subPath,
            basePath = basePath
        }))
    end

    if dirs then
        for _, dir in ipairs(dirs) do
            traverse(subPath .. dir .. "/", basePath, found_exts)
        end
    else
        Log:Warn(L("workshop.scan_failed_dirs", {
            subPath = subPath,
            basePath = basePath
        }))
    end
end

local dt = SysTime()
local addons = engine.GetAddons()
for _, addon in ipairs(addons) do
    addon.timeadded = nil
end

local csum = util.SHA256(table.ToString(resource_extension_types) .. table.ToString(addons))
Log:Warn(L("workshop.addons_checksum", {
    csum = csum
}))

local download_count = 0
local filecache = {}
if file.Exists("workshopdl_cache.txt", "DATA") then
    local raw = file.Read("workshopdl_cache.txt", "DATA")
    local parsed = raw and util.JSONToTable(raw) or nil
    if istable(parsed) then filecache = parsed end
end

if not istable(filecache) then filecache = {} end
if not istable(filecache.sendaddons) then filecache.sendaddons = {} end

if filecache.csum == csum then
    for _, id in ipairs(filecache.sendaddons) do
        if isValidWorkshopID(id) then
            resource.AddWorkshop(tostring(id))
            download_count = download_count + 1
        end
    end

    local elapsed = SysTime() - dt
    Log:Warn(L("workshop.cache_added", {
        count = download_count
    }))

    Log:Warn(L("workshop.done_in", {
        time = fmtSeconds(elapsed)
    }))
    return
else
    filecache.csum = csum
    filecache.sendaddons = {}
end

Log:Warn(L("workshop.scan_addons", {
    count = #addons
}))

local function any(t, condition)
    for _, value in ipairs(t) do
        if condition(value) then return true end
    end
    return false
end

for _, addon in ipairs(addons) do
    if not addon.downloaded or not addon.mounted then continue end
    local found_exts = {}
    traverse("", addon.title, found_exts)
    local addonWSID = tostring(addon.wsid or "")
    local addonModels = tonumber(addon.models) or 0
    local should_add = isValidWorkshopID(addonWSID)
        and (not found_exts.bsp)
        and (addonModels > 0 or any(resource_extension_types, function(ext) return found_exts[ext] end))
    if should_add then
        resource.AddWorkshop(addonWSID)
        download_count = download_count + 1
        filecache.sendaddons[#filecache.sendaddons + 1] = addonWSID
    end
end

Log:Warn(L("workshop.added_to_list", {
    count = download_count
}))

local elapsed = SysTime() - dt
local perAddon = (#addons > 0) and (elapsed / #addons) or 0
Log:Warn(L("workshop.done_seconds", {
    seconds = fmtSeconds(elapsed),
    perAddon = fmtSeconds(perAddon)
}))

file.Write("workshopdl_cache.txt", util.TableToJSON(filecache))
Log:Warn(L("workshop.cache_updated"))
