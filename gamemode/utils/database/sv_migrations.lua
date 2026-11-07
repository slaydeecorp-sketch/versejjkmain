VERSE.DBM = VERSE.DBM or {}
local M = VERSE.DBM
local DB = VERSE.DB

M._init = M._init or false
M._running = M._running or false
M._migrations = M._migrations or {}
M.TableName = M.TableName or "verse_schema_migrations"

local function logInfo(msg)
    if VERSE.Log and VERSE.Log.Info then
        VERSE.Log:Info("[DBM] " .. msg)
    else
        print("[DBM] " .. msg)
    end
end

local function logErr(msg)
    if VERSE.Log and VERSE.Log.Error then
        VERSE.Log:Error("[DBM] " .. msg)
    else
        ErrorNoHalt("[DBM] " .. msg .. "\n")
    end
end

local function ident(name)
    if DB:IsMySQL() then return "`" .. name .. "`" end
    return "\"" .. name .. "\""
end

local function ensureMigrationsTable()
    local tbl = M.TableName
    local q

    if DB:IsMySQL() then
        q = string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                id VARCHAR(128) NOT NULL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], ident(tbl))
    else
        q = string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                id VARCHAR(128) NOT NULL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                applied_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
        ]], ident(tbl))
    end

    return DB:Query(q)
end

local function fetchApplied()
    local tbl = M.TableName
    local q = "SELECT id FROM " .. ident(tbl) .. ";"

    return DB:Query(q):Next(function(res)
        local set = {}
        local rows = res.rows or {}
        for i = 1, #rows do
            local id = rows[i] and rows[i].id
            if id ~= nil then set[tostring(id)] = true end
        end
        return set
    end)
end

local function markApplied(mig)
    local tbl = M.TableName
    local q = string.format(
        "INSERT INTO %s (id, name) VALUES (%s, %s);",
        ident(tbl),
        DB:Escape(mig.id),
        DB:Escape(mig.name or "")
    )
    return DB:Query(q)
end

local function makeCtx()
    local ctx = {}

    function ctx:Query(sqlText)
        return DB:Query(sqlText)
    end

    function ctx:Queue(sqlText, cb, onErr)
        return DB:Queue(sqlText, cb, onErr)
    end

    function ctx:Escape(v)
        return DB:Escape(v)
    end

    function ctx:IsMySQL()
        return DB:IsMySQL()
    end

    function ctx:AddIndex(tableName, indexName, colsSql)
        if self:IsMySQL() then
            local check = string.format("SHOW INDEX FROM %s WHERE Key_name=%s;",
                ident(tableName), self:Escape(indexName)
            )
            return DB:Query(check):Next(function(res)
                local rows = res.rows or {}
                if #rows > 0 then return end
                local create = string.format("CREATE INDEX %s ON %s (%s);",
                    ident(indexName), ident(tableName), colsSql
                )
                return DB:Query(create)
            end)
        end

        local q = string.format("CREATE INDEX IF NOT EXISTS %s ON %s (%s);",
            ident(indexName), ident(tableName), colsSql
        )
        return DB:Query(q)
    end

    return ctx
end

function M:Register(id, name, upFn)
    if not isstring(id) or id == "" then error("DBM:Register: id required", 2) end
    if not isfunction(upFn) then error("DBM:Register: up function required", 2) end

    M._migrations[#M._migrations + 1] = {
        id = id,
        name = name or id,
        up = upFn
    }
end

local function sortMigrations()
    table.sort(M._migrations, function(a, b)
        return tostring(a.id) < tostring(b.id)
    end)
end

local function runMigrationUp(mig, ctx)
    return VERSE.Promise.New(function(resolve, reject)
        local okp, errp = pcall(function()
            if not mig.up then
                resolve()
                return
            end

            local nparams = 0
            if debug and debug.getinfo then
                local info = debug.getinfo(mig.up, "u")
                nparams = info and info.nparams or 0
            end

            if nparams >= 2 then
                mig.up(ctx, function(okm, errm)
                    if okm then resolve() else reject(errm) end
                end)
                return
            end

            local result = mig.up(ctx)
            if result and result._isPromise then
                result:Next(resolve):Catch(reject)
            else
                resolve()
            end
        end)

        if not okp then reject(errp) end
    end)
end

function M:RunAll()
    if self._running then return end
    self._running = true

    if not DB or not DB.OnReady then
        logErr("VERSE.DB is missing; include sv_database.lua before sv_migrations.lua")
        self._running = false
        return
    end

    local self_ = self

    DB:OnReady():Next(function()
        return ensureMigrationsTable()
    end):Next(function()
        return fetchApplied()
    end):Next(function(applied)
        sortMigrations()

        local pending = {}
        for i = 1, #M._migrations do
            local mig = M._migrations[i]
            if not applied[tostring(mig.id)] then
                pending[#pending + 1] = mig
            end
        end

        if #pending == 0 then
            logInfo("No pending migrations.")
            VERSE.Hook.Run("VERSE.MigrationsDone", 0)
            self_._running = false
            return
        end

        logInfo(("Pending migrations: %d"):format(#pending))
        VERSE.Hook.Run("VERSE.MigrationsStart", #pending)

        local ctx = makeCtx()
        if DB.Begin then DB:Begin() end

        local chain = VERSE.Promise.Resolve()
        for i = 1, #pending do
            local mig = pending[i]
            chain = chain:Next(function()
                logInfo(("Applying %s - %s"):format(tostring(mig.id), tostring(mig.name)))
                VERSE.Hook.Run("VERSE.MigrationStart", mig.id, mig.name)

                return runMigrationUp(mig, ctx):Next(function()
                    return markApplied(mig)
                end):Next(function()
                    VERSE.Hook.Run("VERSE.MigrationDone", mig.id, mig.name)
                end):Catch(function(err)
                    logErr(("Migration %s failed: %s"):format(tostring(mig.id), tostring(err)))
                    VERSE.Hook.Run("VERSE.MigrationError", mig.id, err)
                    error(err, 0)
                end)
            end)
        end

        return chain:Next(function()
            return VERSE.Promise.New(function(resolve, reject)
                if DB.Commit then
                    DB:Commit(function(okc, errc)
                        if okc then resolve() else reject(errc) end
                    end)
                else
                    resolve()
                end
            end)
        end):Next(function()
            logInfo("All migrations applied.")
            VERSE.Hook.Run("VERSE.MigrationsDone", #pending)
            self_._running = false
        end):Catch(function(err)
            logErr("Commit or migration chain failed: " .. tostring(err))
            VERSE.Hook.Run("VERSE.MigrationsError", "commit", err)
            self_._running = false
        end)
    end):Catch(function(err)
        logErr("RunAll setup failed: " .. tostring(err))
        self_._running = false
    end)
end
