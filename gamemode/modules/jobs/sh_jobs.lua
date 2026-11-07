VERSE.Config = VERSE.Config or {}
VERSE.Config.Jobs = VERSE.Config.Jobs or {}

local cfg = VERSE.Config.Jobs
if cfg.Enabled == nil then cfg.Enabled = true end
if cfg.DefaultJobID == nil then cfg.DefaultJobID = "citizen" end
if cfg.Persist == nil then cfg.Persist = true end
if cfg.PersistKey == nil then cfg.PersistKey = "verse_job_id" end

VERSE.Jobs = VERSE.Jobs or {}
VERSE.Jobs.Registry = VERSE.Jobs.Registry or {}

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        out[k] = deepCopy(v)
    end
    return out
end

function VERSE.Jobs:Register(id, data)
    assert(isstring(id) and id ~= "", "Job id must be a non-empty string")
    assert(istable(data), "Job data must be a table")
    local job = deepCopy(data)
    job.id = id
    job.name = job.name or id
    job.color = job.color or color_white
    job.model = job.model
    job.loadout = job.loadout or {}
    job.extras = job.extras or {}
    job.stats = job.stats or {}
    job.whitelisted = job.whitelisted == true
    job.respawn = job.respawn == true
    job.spawn   = istable(job.spawn) and job.spawn or nil
    VERSE.Jobs.Registry[id] = job
    VERSE.Jobs._RebuildMeta()
end

function VERSE.Jobs:Unregister(id)
    if not VERSE.Jobs.Registry[id] then return false end
    VERSE.Jobs.Registry[id] = nil
    VERSE.Jobs._RebuildMeta()
    return true
end

function VERSE.Jobs:Get(id)
    return VERSE.Jobs.Registry[id]
end

function VERSE.Jobs:GetAll()
    return VERSE.Jobs.Registry
end

function VERSE.Jobs:GetDefaultID()
    return VERSE.Config.Jobs.DefaultJobID or "citizen"
end

function VERSE.Jobs:IsEnabled()
    return VERSE.Config.Jobs.Enabled == true
end

local PLAYER = FindMetaTable("Player")
local function toPascal(key)
    key = tostring(key or ""):gsub("[^%w_]", "_")
    local out = {}
    for part in key:gmatch("[^_]+") do
        out[#out + 1] = part:sub(1, 1):upper() .. part:sub(2)
    end
    return table.concat(out)
end

local function ensureFn(name, fn)
    if not PLAYER[name] then PLAYER[name] = fn end
end

local function jobData(ply)
    ply.Job = ply.Job or {
        id = nil,
        extras = {},
        stats = {}
    }
    return ply.Job
end

ensureFn("GetJobID", function(ply) return jobData(ply).id end)
ensureFn("GetJob", function(ply)
    local id = ply:GetJobID()
    return id and VERSE.Jobs:Get(id) or nil
end)

ensureFn("GetExtra", function(ply, key, fallback)
    local v = jobData(ply).extras[key]
    return v ~= nil and v or fallback
end)

ensureFn("SetExtra", function(ply, key, value) jobData(ply).extras[key] = value end)
ensureFn("GetStat", function(ply, key, fallback)
    local v = jobData(ply).stats[key]
    return v ~= nil and v or fallback
end)

ensureFn("SetStat", function(ply, key, value) jobData(ply).stats[key] = value end)
function VERSE.Jobs._RebuildMeta()
    local extKeys, stKeys = {}, {}
    for _, job in pairs(VERSE.Jobs.Registry) do
        for k, v in pairs(job.extras or {}) do
            if extKeys[k] == nil then extKeys[k] = v end
        end

        for k, v in pairs(job.stats or {}) do
            if stKeys[k] == nil then stKeys[k] = v end
        end
    end

    for key, sample in pairs(extKeys) do
        local s = toPascal(key)
        if type(sample) == "boolean" then
            ensureFn("Is" .. s, function(ply) return ply:GetExtra(key, false) == true end)
            ensureFn("Set" .. s, function(ply, val) ply:SetExtra(key, val == true) end)
        else
            ensureFn("Get" .. s, function(ply) return ply:GetExtra(key, sample) end)
            ensureFn("Set" .. s, function(ply, val) ply:SetExtra(key, val) end)
        end
    end

    for key, sample in pairs(stKeys) do
        local s = toPascal(key) .. "Stat"
        ensureFn("Get" .. s, function(ply) return ply:GetStat(key, sample) end)
        ensureFn("Set" .. s, function(ply, val) ply:SetStat(key, val) end)
    end
end

VERSE.Jobs._RebuildMeta()