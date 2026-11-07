VERSE.DB = VERSE.DB or {}
local DB = VERSE.DB

DB._init = DB._init or false
DB.ready = DB.ready or false
DB.callbacks = DB.callbacks or {}

local function emit(name, ...)
    if not (VERSE.Hook and VERSE.Hook.Run) then return end

    local ev = "VERSE." .. tostring(name)
    local ok, err = pcall(VERSE.Hook.Run, ev, ...)
    if not ok then
        (VERSE.Err or ErrorNoHalt)("[VERSE.Hook] " .. tostring(ev) .. " failed: " .. tostring(err) .. "\n")
    end
end

local function safePCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        (VERSE.Err or ErrorNoHalt)(tostring(err) .. "\n")
        return false, err
    end
    return true
end

function DB:IsReady()
    return self.ready == true
end

function DB:IsMySQL()
    return (MySQLite and MySQLite.isMySQL and MySQLite.isMySQL()) and true or false
end

function DB:OnReady(fn)
    if fn == nil then
        return VERSE.Promise.New(function(resolve)
            if self.ready then
                timer.Simple(0, resolve)
                return
            end
            table.insert(self.callbacks, resolve)
        end)
    end

    if self.ready then
        local ok, err = pcall(fn)
        if not ok then (VERSE.Err or ErrorNoHalt)("DB:OnReady callback failed: " .. tostring(err) .. "\n") end
        return
    end
    table.insert(self.callbacks, fn)
end

function DB:_FireReady()
    if self.ready then return end
    self.ready = true

    local isMy = self:IsMySQL()
    emit("DBReady", isMy)

    for i = 1, #self.callbacks do
        local fn = self.callbacks[i]
        local ok, err = pcall(fn)
        if not ok then (VERSE.Err or ErrorNoHalt)("DB ready callback failed: " .. tostring(err) .. "\n") end
    end
    self.callbacks = {}
end

local function buildConfig(configOverride)
    local cfg = {}
    if VERSE.Config and istable(VERSE.Config.Database) then
        for k, v in pairs(VERSE.Config.Database) do
            cfg[k] = v
        end
    end

    if istable(configOverride) then
        for k, v in pairs(configOverride) do
            cfg[k] = v
        end
    end

    cfg.EnableMySQL = tobool(cfg.EnableMySQL)
    cfg.Host = cfg.Host or "127.0.0.1"
    cfg.Username = cfg.Username or "root"
    cfg.Password = cfg.Password or ""
    cfg.Database_name = cfg.Database_name or "verse"
    cfg.Database_port = tonumber(cfg.Database_port) or 3306
    cfg.MultiStatements = tobool(cfg.MultiStatements)

    if cfg.Preferred_module ~= "mysqloo" and cfg.Preferred_module ~= "tmysql4" then
        cfg.Preferred_module = "mysqloo"
    end

    return cfg
end

function DB:_BeginReadyProbe(cfg)
    if self.ready then return end

    if not tobool(cfg.EnableMySQL) then
        timer.Simple(0, function()
            self:_FireReady()
        end)
        return
    end

    local tname = "VERSE_DBReadyProbe"
    timer.Remove(tname)

    local tries = 0
    timer.Create(tname, 1, 0, function()
        if self.ready then
            timer.Remove(tname)
            return
        end

        tries = tries + 1

        self:QueryValue("SELECT 1", function(v)
            if self.ready then
                timer.Remove(tname)
                return
            end

            self:_FireReady()
            timer.Remove(tname)
        end, function(err)
            if tries == 1 or tries % 10 == 0 then
                VERSE.Log:Info(("DB probe: waiting MySQL... tries=%d err=%s"):format(tries, tostring(err)))
            end

            return true
        end)
    end)
end

function DB:Init(configOverride)
    if self._init then return end
    self._init = true

    local cfg = buildConfig(configOverride)
    emit("PreDBInit", cfg)

    if VERSE.Log and VERSE.Log.Info then
        VERSE.Log:Info(("DB init (MySQLite): EnableMySQL=%s Host=%s DB=%s Port=%s"):format(
            tostring(cfg.EnableMySQL),
            tostring(cfg.Host),
            tostring(cfg.Database_name),
            tostring(cfg.Database_port)
        ))
    end

    if not MySQLite or not MySQLite.initialize then
        local e = "MySQLite not loaded: include libraries/database/sv_mysqlite.lua before utils/database/sv_database.lua"
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error(e) end
        (VERSE.Err or ErrorNoHalt)(e .. "\n")
        emit("PostDBInit", cfg, false, e)
        return
    end

    local ok, err = safePCall(MySQLite.initialize, cfg)
    emit("PostDBInit", cfg, ok, err)

    if ok then
        self:_BeginReadyProbe(cfg)
    end
end

VERSE.Hook.AddNS("Database", "DatabaseInitialized", "VERSE::DB::Ready", function()
    local isMy = (MySQLite and MySQLite.isMySQL and MySQLite.isMySQL()) and true or false
    if VERSE.Log and VERSE.Log.Info then
        VERSE.Log:Info(("DatabaseInitialized (MySQL=%s)"):format(tostring(isMy)))
    end

    emit("DatabaseInitialized", isMy)
    DB:_FireReady()
end)

function DB:Escape(v)
    if MySQLite and MySQLite.SQLStr then
        return MySQLite.SQLStr(v)
    end
    return sql.SQLStr(v, true)
end

local function normalizeQueryError(err, q, fallbackSql)
    if isstring(err) and err ~= "" then return err end
    if isstring(q) and q ~= "" and q ~= fallbackSql then return q end
    if istable(err) then
        if isstring(err.error) and err.error ~= "" then return err.error end
        if isstring(err.err) and err.err ~= "" then return err.err end
        if isstring(err.message) and err.message ~= "" then return err.message end
        if isstring(err.msg) and err.msg ~= "" then return err.msg end
        for _, v in pairs(err) do
            if isstring(v) and v ~= "" and #v > 3 then return v end
        end
        local j = util.TableToJSON(err)
        if isstring(j) and j ~= "{}" and j ~= "[]" then return "db_error: " .. j end
    end
    if err ~= nil then return tostring(err) end
    if isstring(q) and q ~= "" then return q end
    return "unknown_db_error"
end

function DB:Query(sqlText, callback, onError)
    if callback == nil then
        return VERSE.Promise.New(function(resolve, reject)
            self:Query(sqlText, function(rows, lastInsert)
                resolve({ rows = rows, lastInsert = lastInsert })
            end, function(err, q)
                reject(normalizeQueryError(err, q, sqlText))
                return true
            end)
        end)
    end

    emit("PreDBQuery", sqlText)

    local function errWrap(err, q)
        local normErr = normalizeQueryError(err, q, sqlText)
        local sqlOut = isstring(q) and q or sqlText
        emit("DBQueryError", sqlOut, normErr)
        if onError then return onError(normErr, sqlOut) end
    end

    if not MySQLite or not MySQLite.query then
        return errWrap("MySQLite.query missing", sqlText)
    end

    return MySQLite.query(sqlText, callback, errWrap)
end

function DB:QueryValue(sqlText, callback, onError)
    if callback == nil then
        return VERSE.Promise.New(function(resolve, reject)
            self:QueryValue(sqlText, resolve, function(err)
                reject(err)
                return true
            end)
        end)
    end

    if not MySQLite or not MySQLite.queryValue then
        if onError then onError("MySQLite.queryValue missing", sqlText) end
        return
    end
    return MySQLite.queryValue(sqlText, callback, onError)
end

function DB:Begin()
    if not MySQLite or not MySQLite.begin then return end
    return MySQLite.begin()
end

function DB:Commit(onFinished)
    if onFinished == nil then
        return VERSE.Promise.New(function(resolve, reject)
            self:Commit(function(ok, err)
                if ok then resolve() else reject(err) end
            end)
        end)
    end

    if not MySQLite or not MySQLite.commit then
        if onFinished then onFinished(false, "MySQLite.commit missing") end
        return
    end
    return MySQLite.commit(onFinished)
end

function DB:Queue(sqlText, callback, onError)
    if callback == nil then
        return VERSE.Promise.New(function(resolve, reject)
            self:Queue(sqlText, function(rows, lastInsert)
                resolve({ rows = rows, lastInsert = lastInsert })
            end, function(err)
                reject(err)
                return true
            end)
        end)
    end

    if not MySQLite or not MySQLite.queueQuery then
        if onError then onError("MySQLite.queueQuery missing", sqlText) end
        return
    end
    return MySQLite.queueQuery(sqlText, callback, onError)
end

function DB:TableExists(tbl, callback, onError)
    if callback == nil then
        return VERSE.Promise.New(function(resolve, reject)
            self:TableExists(tbl, resolve, function(err)
                reject(err)
                return true
            end)
        end)
    end

    if not MySQLite or not MySQLite.tableExists then
        if onError then onError("MySQLite.tableExists missing", tbl) end
        return
    end
    return MySQLite.tableExists(tbl, callback, onError)
end

function DB:TransactionP(queries)
    return VERSE.Promise.New(function(resolve, reject)
        local errored = false

        local function onError(err)
            if errored then return true end
            errored = true
            reject(err)
            return true
        end

        self:Begin()
        for _, sqlText in ipairs(queries) do
            self:Queue(sqlText, function() end, onError)
        end
        self:Commit(function()
            if not errored then resolve() end
        end)
    end)
end

function DB:Ping(callback)
    if not self:IsReady() then
        if callback then callback(false, "DB not ready") end
        return
    end

    if not self:IsMySQL() then
        if callback then callback(true, "SQLite mode") end
        return
    end

    self:QueryValue("SELECT 1", function(v)
        if callback then callback(v == "1" or v == 1, nil) end
    end, function(err)
        if callback then callback(false, err) end
        return true
    end)
end
