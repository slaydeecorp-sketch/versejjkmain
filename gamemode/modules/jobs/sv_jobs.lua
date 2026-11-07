VERSE.Jobs.Whitelist = VERSE.Jobs.Whitelist or {}
local function wlAdd(jobID, steamID)
    VERSE.Jobs.Whitelist[jobID] = VERSE.Jobs.Whitelist[jobID] or {}
    VERSE.Jobs.Whitelist[jobID][steamID] = true
    VERSE.DB:Queue("REPLACE INTO verse_jobs_whitelist (job_id, steam_id) VALUES (" .. VERSE.DB:Escape(jobID) .. "," .. VERSE.DB:Escape(steamID) .. ")")
end

local function wlRemove(jobID, steamID)
    if VERSE.Jobs.Whitelist[jobID] then VERSE.Jobs.Whitelist[jobID][steamID] = nil end
    VERSE.DB:Queue("DELETE FROM verse_jobs_whitelist WHERE job_id=" .. VERSE.DB:Escape(jobID) .. " AND steam_id=" .. VERSE.DB:Escape(steamID))
end

function VERSE.Jobs:IsWhitelisted(jobID, steamID)
    local job = self:Get(jobID)
    if not job then return false end
    if not job.whitelisted then return true end
    return (VERSE.Jobs.Whitelist[jobID] or {})[steamID] == true
end

local function loadPersisted()
    VERSE.DB:Query("SELECT id, data FROM verse_jobs_dynamic", function(rows)
        if rows then
            for _, row in ipairs(rows) do
                local ok, data = pcall(util.JSONToTable, row.data)
                if ok and istable(data) then
                    data.dynamic = true
                    VERSE.Jobs:Register(row.id, data)
                end
            end
        end

        VERSE.DB:Query("SELECT id FROM verse_jobs_disabled", function(rows2)
            if rows2 then
                for _, row in ipairs(rows2) do
                    VERSE.Jobs.Registry[row.id] = nil
                end
            end

            VERSE.DB:Query("SELECT job_id, steam_id FROM verse_jobs_whitelist", function(rows3)
                if rows3 then
                    for _, row in ipairs(rows3) do
                        VERSE.Jobs.Whitelist[row.job_id] = VERSE.Jobs.Whitelist[row.job_id] or {}
                        VERSE.Jobs.Whitelist[row.job_id][row.steam_id] = true
                    end
                end
            end)
        end)
    end)
end

local function ensureSchema()
    local queries = {
        [[CREATE TABLE IF NOT EXISTS verse_jobs_dynamic (
            id   VARCHAR(128) NOT NULL PRIMARY KEY,
            data TEXT NOT NULL
        )]],
        [[CREATE TABLE IF NOT EXISTS verse_jobs_disabled (
            id VARCHAR(128) NOT NULL PRIMARY KEY
        )]],
        [[CREATE TABLE IF NOT EXISTS verse_jobs_whitelist (
            job_id   VARCHAR(128) NOT NULL,
            steam_id VARCHAR(32) NOT NULL,
            PRIMARY KEY (job_id, steam_id)
        )]],
    }

    local chain = VERSE.Promise.Resolve()
    for i = 1, #queries do
        local sqlText = queries[i]
        chain = chain:Next(function()
            return VERSE.DB:Query(sqlText)
        end)
    end
    return chain
end

VERSE.DB:OnReady(function()
    ensureSchema():Next(loadPersisted):Catch(function(err)
        if VERSE.Log and VERSE.Log.Error then
            VERSE.Log:Error("[Jobs] schema init failed: " .. tostring(err))
        end
    end)
end)
local function pickModel(job)
    if not job or not job.model then return nil end
    if istable(job.model) then
        local mdl = job.model[math.random(#job.model)]
        return (isstring(mdl) and mdl ~= "") and mdl or nil
    end

    if isstring(job.model) and job.model ~= "" then return job.model end
    return nil
end

local function applyStats(ply, fullReset)
    if VERSE.Stats and ply.RecalcStats then
        ply:RecalcStats(fullReset ~= false)
        return
    end

    if not ply.Job or not ply.Job.stats then return end
    local stats = ply.Job.stats
    local hp = tonumber(stats.health)
    local ar = tonumber(stats.armor)
    local ws = tonumber(stats.walkspeed)
    local rs = tonumber(stats.runspeed)
    local jp = tonumber(stats.jumppower)

    if hp and hp > 0 then
        ply:SetMaxHealth(hp)
        ply:SetHealth(hp)
    end

    if ar then ply:SetArmor(ar) end
    if ws and ws > 0 then ply:SetWalkSpeed(ws) end
    if rs and rs > 0 then ply:SetRunSpeed(rs) end
    if jp and jp > 0 then ply:SetJumpPower(jp) end
end

local function syncJob(ply)
    ply:SetPublicString("VERSE::JobID", ply:GetJobID() or "")
    netstream.Start(ply, "VERSE::Jobs::Sync", ply:GetJobID() or "", ply.Job and ply.Job.extras or {}, ply.Job and ply.Job.stats or {})
end

local function syncRegistry(ply)
    local list = {}
    for id, job in pairs(VERSE.Jobs.Registry) do
        list[id] = {
            id = id,
            name = job.name,
            model = job.model or {},
            loadout = job.loadout or {},
            stats = job.stats or {},
            extras = job.extras or {},
            whitelisted = job.whitelisted == true,
            dynamic = job.dynamic == true,
            respawn = job.respawn == true,
            spawn = job.spawn,
        }
    end

    netstream.Start(ply, "VERSE::Jobs::RegistrySync", list)
end

local function syncWhitelist(ply)
    netstream.Start(ply, "VERSE::Jobs::WhitelistSync", VERSE.Jobs.Whitelist)
end

local function broadcastRegistry()
    for _, p in ipairs(player.GetAll()) do
        if p:IsDeveloper() or p:IsStaff() then syncRegistry(p) end
    end
end

local function broadcastWhitelist()
    for _, p in ipairs(player.GetAll()) do
        if p:IsDeveloper() or p:IsStaff() then syncWhitelist(p) end
    end
end

function VERSE.Jobs:SetPlayerJob(ply, jobID, opts)
    if not IsValid(ply) then return false end
    opts = opts or {}
    if not VERSE.Jobs:IsEnabled() then jobID = VERSE.Jobs:GetDefaultID() end
    local job = VERSE.Jobs:Get(jobID)
    if not job then
        jobID = VERSE.Jobs:GetDefaultID()
        job = VERSE.Jobs:Get(jobID)
        if not job then return false end
    end

    if not opts.skipWhitelist and job.whitelisted and not VERSE.Jobs:IsWhitelisted(jobID, ply:SteamID()) then
        jobID = VERSE.Jobs:GetDefaultID()
        job = VERSE.Jobs:Get(jobID)
        if not job then return false end
    end

    local prevCustom = (ply.Job and ply.Job.id == jobID) and ply.Job.custom or nil
    ply.Job = {
        id = jobID,
        extras = table.Copy(job.extras or {}),
        stats = table.Copy(job.stats or {}),
        custom = prevCustom,
        resolvedModel = pickModel(job),
    }

    if not opts.noLoadout then
        ply:StripWeapons()
        for _, wep in ipairs(job.loadout or {}) do
            ply:Give(wep)
        end
    end

    applyStats(ply)
    if VERSE.Config.Jobs.Persist and not opts.noPersist then ply:SetPData(VERSE.Config.Jobs.PersistKey, jobID) end
    syncJob(ply)
    VERSE.Hook.Run("VERSE::OnChanged::Jobs", ply, jobID, job)
    return true
end

function VERSE.Jobs:LoadPlayerJob(ply)
    local jobID
    if not VERSE.Jobs:IsEnabled() then
        jobID = VERSE.Jobs:GetDefaultID()
    elseif VERSE.Config.Jobs.Persist then
        jobID = ply:GetPData(VERSE.Config.Jobs.PersistKey, VERSE.Jobs:GetDefaultID())
    else
        jobID = VERSE.Jobs:GetDefaultID()
    end

    -- __loadingChar empêche VERSE::OnChanged::Jobs d'écraser la DB
    -- (évite que "classe_4" par défaut n'écrase tous les personnages du joueur
    -- si le cache CH._cache est déjà peuplé au moment du PlayerInitialSpawn).
    -- noPersist empêche de renforcer "classe_4" dans PData à chaque reconnexion.
    ply.__loadingChar = true
    local result = VERSE.Jobs:SetPlayerJob(ply, jobID, {
        noLoadout      = true,
        skipWhitelist  = true,
        noPersist      = true,
    })
    ply.__loadingChar = nil
    return result
end

VERSE.Hook.AddNS("Jobs", "PlayerInitialSpawn", "VERSE::PlayerInitialSpawn::Jobs", function(ply) VERSE.Jobs:LoadPlayerJob(ply) end)
local function resolveModel(ply, job)
    local custom = ply.Job and ply.Job.custom
    if custom and isstring(custom.model) and custom.model ~= "" then return custom.model end
    if ply.Job and isstring(ply.Job.resolvedModel) and ply.Job.resolvedModel ~= "" then return ply.Job.resolvedModel end
    if job then
        local gender  = ply:GetNWString("VERSE::CharGender", "male")
        local headMdl = (gender == "female") and job.head_female or job.head_male
        if isstring(headMdl) and headMdl ~= "" then return headMdl end
    end
    return pickModel(job)
end

local function applySpawnPos(ply, job)
    if not istable(job.spawn) then return end
    local mn, mx = job.spawn.min, job.spawn.max
    if not istable(mn) or not istable(mx) then return end
    local mnx, mny, mnz = tonumber(mn.x) or 0, tonumber(mn.y) or 0, tonumber(mn.z) or 0
    local mxx, mxy, mxz = tonumber(mx.x) or 0, tonumber(mx.y) or 0, tonumber(mx.z) or 0
    local rx = math.Rand(math.min(mnx, mxx), math.max(mnx, mxx))
    local ry = math.Rand(math.min(mny, mxy), math.max(mny, mxy))
    local rz = math.Rand(math.min(mnz, mxz), math.max(mnz, mxz))
    ply:SetPos(Vector(rx, ry, rz))
    -- Angle de spawn optionnel : job.spawn.ang = { p, y, r }
    if istable(job.spawn.ang) then
        local p = tonumber(job.spawn.ang.p) or 0
        local y = tonumber(job.spawn.ang.y) or 0
        local r = tonumber(job.spawn.ang.r) or 0
        ply:SetEyeAngles(Angle(p, y, r))
    end
end

VERSE.Hook.AddNS("Jobs", "PlayerSpawn", "VERSE::PlayerSpawn::Jobs", function(ply)
    local id = ply:GetJobID() or VERSE.Jobs:GetDefaultID()
    local job = VERSE.Jobs:Get(id)
    if not job then return end
    applySpawnPos(ply, job)
end)

function GAMEMODE:PlayerSetModel(ply)
    local id = ply:GetJobID() or VERSE.Jobs:GetDefaultID()
    local job = VERSE.Jobs:Get(id)
    local mdl = job and resolveModel(ply, job) or nil
    if mdl then
        ply:SetModel(mdl)
    else
        self.BaseClass.PlayerSetModel(self, ply)
    end
end

VERSE.Hook.AddNS("Jobs", "PlayerLoadout", "VERSE::PlayerLoadout::Jobs", function(ply)
    local id = ply:GetJobID() or VERSE.Jobs:GetDefaultID()
    local job = VERSE.Jobs:Get(id)
    if not job then return end
    local custom = ply.Job and ply.Job.custom
    local loadout = (custom and istable(custom.loadout) and #custom.loadout > 0 and custom.loadout) or (job.loadout or {})
    ply:StripWeapons()
    for _, wep in ipairs(loadout) do
        ply:Give(wep)
    end

    applyStats(ply)
    syncJob(ply)
    return true
end)

netstream.Hook("VERSE::Jobs::Request", function(ply, what)
    if not IsValid(ply) then return end
    if what == "registry" and (ply:IsDeveloper() or ply:IsStaff()) then
        syncRegistry(ply)
    elseif what == "whitelist" and (ply:IsDeveloper() or ply:IsStaff()) then
        syncWhitelist(ply)
    end
end)

netstream.Hook("VERSE::Jobs::Create", function(ply, id, data)
    if not IsValid(ply) or not ply:IsDeveloper() then return end
    if id == "" or not istable(data) then return end
    data.dynamic = true
    VERSE.Jobs:Register(id, data)
    VERSE.DB:Queue("REPLACE INTO verse_jobs_dynamic (id, data) VALUES (" .. VERSE.DB:Escape(id) .. "," .. VERSE.DB:Escape(util.TableToJSON(data)) .. ")")
    VERSE.DB:Queue("DELETE FROM verse_jobs_disabled WHERE id=" .. VERSE.DB:Escape(id))
    broadcastRegistry()
    ply:Notify(VERSE.L("jobs.notify_job_created", {id = id}), NOTIFY_HINT, 4)
end)

netstream.Hook("VERSE::Jobs::Delete", function(ply, id)
    if not IsValid(ply) or not ply:IsDeveloper() then return end
    if id == "" or id == VERSE.Jobs:GetDefaultID() then return end
    VERSE.Jobs:Unregister(id)
    VERSE.DB:Queue("DELETE FROM verse_jobs_dynamic WHERE id=" .. VERSE.DB:Escape(id))
    VERSE.DB:Queue("REPLACE INTO verse_jobs_disabled (id) VALUES (" .. VERSE.DB:Escape(id) .. ")")
    for _, p in ipairs(player.GetAll()) do
        if p:GetJobID() == id then
            VERSE.Jobs:SetPlayerJob(p, VERSE.Jobs:GetDefaultID())
            p:Spawn()
        end
    end

    broadcastRegistry()
    ply:Notify(VERSE.L("jobs.notify_job_deleted", {id = id}), NOTIFY_HINT, 4)
end)

netstream.Hook("VERSE::Jobs::Edit", function(ply, id, data)
    if not IsValid(ply) or not ply:IsDeveloper() then return end
    if id == "" or not istable(data) then return end
    data.dynamic = true
    VERSE.Jobs:Register(id, data)
    VERSE.DB:Queue("REPLACE INTO verse_jobs_dynamic (id, data) VALUES (" .. VERSE.DB:Escape(id) .. "," .. VERSE.DB:Escape(util.TableToJSON(data)) .. ")")
    VERSE.DB:Queue("DELETE FROM verse_jobs_disabled WHERE id=" .. VERSE.DB:Escape(id))
    for _, p in ipairs(player.GetAll()) do
        if p:GetJobID() == id then
            VERSE.Jobs:SetPlayerJob(p, id, {
                noLoadout = true,
                skipWhitelist = true,
                noPersist = true
            })
        end
    end

    broadcastRegistry()
    ply:Notify(VERSE.L("jobs.notify_job_edited", {id = id}), NOTIFY_HINT, 4)
end)

netstream.Hook("VERSE::Jobs::SetPlayer", function(ply, targetSID, jobID, customData)
    if not IsValid(ply) then return end
    if not (ply:IsDeveloper() or ply:IsStaff()) then return end
    local target
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == targetSID then
            target = p
            break
        end
    end

    if not IsValid(target) then return end
    local job = VERSE.Jobs:Get(jobID)
    if not job then return end
    if job.whitelisted then
        wlAdd(jobID, target:SteamID())
        broadcastWhitelist()
    end

    customData = istable(customData) and customData or {}
    local useCustomLoadout = istable(customData.loadout) and #customData.loadout > 0
    local finalLoadout = useCustomLoadout and customData.loadout or (job.loadout or {})
    VERSE.Jobs:SetPlayerJob(target, jobID, {
        skipWhitelist = true,
        noLoadout = true
    })

    if not IsValid(target) or not target.Job then return end
    local custom = {}
    if isstring(customData.model) and customData.model ~= "" then custom.model = customData.model end
    if useCustomLoadout then custom.loadout = customData.loadout end
    local hp = tonumber(customData.hp)
    if hp and hp > 0 then target.Job.stats.health = hp end
    local armor = tonumber(customData.armor)
    if armor and armor >= 0 then target.Job.stats.armor = armor end
    target.Job.custom = custom
    if job.respawn then
        target:Spawn()
    else
        local mdl = resolveModel(target, job)
        if mdl then target:SetModel(mdl) end
        applySpawnPos(target, job)
        target:StripWeapons()
        for _, wep in ipairs(finalLoadout) do
            target:Give(wep)
        end

        if hp and hp > 0 then
            target:SetMaxHealth(hp)
            target:SetHealth(hp)
        end

        if armor and armor >= 0 then target:SetArmor(armor) end
        syncJob(target)
    end

    local jobName = job.name or jobID
    target:Notify(VERSE.L("jobs.notify_job_received",     {job = jobName}),                          NOTIFY_HINT, 5)
    ply:Notify(VERSE.L("jobs.notify_job_assigned_done",   {job = jobName, player = target:Nick()}),   NOTIFY_HINT, 4)
end)

netstream.Hook("VERSE::Jobs::WhitelistAdd", function(ply, jobID, steamID)
    if not IsValid(ply) then return end
    if not (ply:IsDeveloper() or ply:IsStaff()) then return end
    if jobID == "" or steamID == "" then return end
    wlAdd(jobID, steamID)
    broadcastWhitelist()
end)

netstream.Hook("VERSE::Jobs::WhitelistRemove", function(ply, jobID, steamID)
    if not IsValid(ply) then return end
    if not (ply:IsDeveloper() or ply:IsStaff()) then return end
    if jobID == "" or steamID == "" then return end
    wlRemove(jobID, steamID)
    broadcastWhitelist()
end)
