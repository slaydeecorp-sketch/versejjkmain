VERSE.DBX = VERSE.DBX or {}
local X = VERSE.DBX

local function logInfo(msg)
    if VERSE.Log and VERSE.Log.Info then
        VERSE.Log:Info("[DBX] " .. msg)
    else
        print("[DBX] " .. msg)
    end
end

local function logErr(msg)
    if VERSE.Log and VERSE.Log.Error then
        VERSE.Log:Error("[DBX] " .. msg)
    else
        ErrorNoHalt("[DBX] " .. msg .. "\n")
    end
end

local function requireMysqloo()
    if not mysqloo then
        error("mysqloo is required for MySQL side transfers", 2)
    end
end

local function sqliteListTables()
    local rows = sql.Query("SELECT name FROM sqlite_master WHERE type='table';") or {}
    local out = {}
    for i = 1, #rows do
        local n = rows[i] and rows[i].name
        if n and n ~= "sqlite_sequence" then
            out[#out + 1] = n
        end
    end
    return out
end

local function sqliteTableInfo(tableName)
    local rows = sql.Query("PRAGMA table_info(" .. tableName .. ");") or {}
    local cols = {}
    for i = 1, #rows do
        cols[#cols + 1] = rows[i].name
    end
    return cols
end

local function sqliteSelectBatch(tableName, cols, whereSql, orderSql, limit, offset)
    local colsSql = "*"
    if istable(cols) and #cols > 0 then
        colsSql = table.concat(cols, ",")
    end

    local q = ("SELECT %s FROM %s%s%s LIMIT %d OFFSET %d;")
        :format(colsSql, tableName, whereSql or "", orderSql or "", limit, offset)

    return sql.Query(q) or {}
end

local function sqliteValue(v)
    if v == nil then return "NULL" end
    if isnumber(v) then return tostring(v) end
    if isbool(v) then return v and "1" or "0" end
    return sql.SQLStr(tostring(v), true)
end

local function sqliteInsertMany(tableName, cols, rows, mode)
    local verb = "INSERT"
    if mode == "replace" then verb = "INSERT OR REPLACE"
    elseif mode == "ignore" then verb = "INSERT OR IGNORE"
    end

    local colsSql = "(" .. table.concat(cols, ",") .. ")"
    local tuples = {}

    for i = 1, #rows do
        local r = rows[i]
        local parts = {}
        for c = 1, #cols do
            local key = cols[c]
            local v = r[key]

            if v == nil then
                parts[#parts + 1] = "NULL"
            elseif isnumber(v) then
                parts[#parts + 1] = tostring(v)
            elseif isbool(v) then
                parts[#parts + 1] = v and "1" or "0"
            else
                parts[#parts + 1] = "'" .. sqliteValue(v) .. "'"
            end
        end
        tuples[#tuples + 1] = "(" .. table.concat(parts, ",") .. ")"
    end

    local q = ("%s INTO %s %s VALUES %s;"):format(verb, tableName, colsSql, table.concat(tuples, ","))
    return sql.Query(q)
end

local function mysqlConnect(cfg)
    requireMysqloo()
    return mysqloo.connect(cfg.Host, cfg.Username, cfg.Password, cfg.Database_name, tonumber(cfg.Database_port) or 3306)
end

local function mysqlQuery(db, sqlText, onOk, onErr)
    local q = db:query(sqlText)
    function q:onSuccess(data) if onOk then onOk(data) end end
    function q:onError(err) if onErr then onErr(err) end end
    q:start()
end

local function mysqlEsc(db, v)
    if v == nil then return "NULL" end
    if isnumber(v) then return tostring(v) end
    if isbool(v) then return v and "1" or "0" end
    return "'" .. db:escape(tostring(v)) .. "'"
end

local function mysqlInsertMany(db, tableName, cols, rows, mode, onOk, onErr)
    local verb = "REPLACE"
    if mode == "ignore" then verb = "INSERT IGNORE"
    elseif mode == "insert" then verb = "INSERT"
    end

    local colsSql = "`" .. table.concat(cols, "`,`") .. "`"
    local tuples = {}

    for i = 1, #rows do
        local r = rows[i]
        local parts = {}
        for c = 1, #cols do
            local key = cols[c]
            parts[#parts + 1] = mysqlEsc(db, r[key])
        end
        tuples[#tuples + 1] = "(" .. table.concat(parts, ",") .. ")"
    end

    local q = ("%s INTO `%s` (%s) VALUES %s;"):format(verb, tableName, colsSql, table.concat(tuples, ","))
    mysqlQuery(db, q, onOk, onErr)
end

local function mysqlFetchColumns(db, tableName, cb)
    mysqlQuery(db, "SHOW COLUMNS FROM `" .. tableName .. "`;", function(rows)
        if not istable(rows) or #rows == 0 then return cb(false, "No columns for " .. tableName) end
        local cols = {}
        for i = 1, #rows do cols[#cols + 1] = rows[i].Field end
        cb(true, cols)
    end, function(err)
        cb(false, err)
    end)
end

local function mysqlSelectBatch(db, tableName, cols, whereSql, orderSql, limit, offset, cb)
    local colsSql = "*"
    if istable(cols) and #cols > 0 then
        colsSql = "`" .. table.concat(cols, "`,`") .. "`"
    end

    local q = ("SELECT %s FROM `%s`%s%s LIMIT %d OFFSET %d;")
        :format(colsSql, tableName, whereSql or "", orderSql or "", limit, offset)

    mysqlQuery(db, q, function(rows) cb(true, rows or {}) end, function(err) cb(false, err) end)
end

function X:TransferTable(sourceType, sourceCfg, targetType, targetCfg, tableName, opts, cb)
    opts = opts or {}
    local batchSize = tonumber(opts.batchSize) or 500
    local mode = opts.mode or "replace"

    local whereSql = ""
    if isstring(opts.where) and opts.where ~= "" then whereSql = " WHERE " .. opts.where end

    local orderSql = ""
    if isstring(opts.orderBy) and opts.orderBy ~= "" then orderSql = " ORDER BY " .. opts.orderBy end

    local function fail(err)
        logErr(("Transfer %s failed: %s"):format(tableName, tostring(err)))
        if cb then cb(false, err) end
    end

    local function done(total)
        logInfo(("Transfer %s done. rows=%d"):format(tableName, total or 0))
        if cb then cb(true) end
    end

    local function getSourceColumns(mysqlDb, cbCols)
        if istable(opts.columns) and #opts.columns > 0 then
            return cbCols(true, opts.columns)
        end

        if sourceType == "sqlite" then
            local cols = sqliteTableInfo(tableName)
            if not cols or #cols == 0 then return cbCols(false, "sqlite: no columns for " .. tableName) end
            return cbCols(true, cols)
        end

        mysqlFetchColumns(mysqlDb, tableName, cbCols)
    end

    if sourceType == "sqlite" and targetType == "mysql" then
        local dst = mysqlConnect(targetCfg)

        dst.onConnected = function()
            getSourceColumns(nil, function(ok, colsOrErr)
                if not ok then return fail(colsOrErr) end
                local cols = colsOrErr

                local offset = 0
                local total = 0

                local function step()
                    local rows = sqliteSelectBatch(tableName, cols, whereSql, orderSql, batchSize, offset)
                    if not istable(rows) or #rows == 0 then
                        return done(total)
                    end

                    mysqlInsertMany(dst, tableName, cols, rows, mode,
                        function()
                            total = total + #rows
                            offset = offset + #rows
                            if total % (batchSize * 10) == 0 then
                                logInfo(("Transfer %s progress: %d rows"):format(tableName, total))
                            end
                            step()
                        end,
                        function(err)
                            fail(err)
                        end
                    )
                end

                logInfo(("Transfer %s (sqlite -> mysql) started (batch=%d, mode=%s)"):format(tableName, batchSize, mode))
                step()
            end)
        end

        dst.onConnectionFailed = function(_, err) fail("mysql connect failed: " .. tostring(err)) end
        dst:connect()
        return
    end

    if sourceType == "mysql" and targetType == "sqlite" then
        local src = mysqlConnect(sourceCfg)

        src.onConnected = function()
            getSourceColumns(src, function(ok, colsOrErr)
                if not ok then return fail(colsOrErr) end
                local cols = colsOrErr

                local offset = 0
                local total = 0

                local function step()
                    mysqlSelectBatch(src, tableName, cols, whereSql, orderSql, batchSize, offset, function(ok2, rowsOrErr)
                        if not ok2 then return fail(rowsOrErr) end
                        local rows = rowsOrErr

                        if not istable(rows) or #rows == 0 then
                            return done(total)
                        end

                        local err = sqliteInsertMany(tableName, cols, rows, mode)
                        if isstring(err) and err ~= "" then
                            return fail(err)
                        end

                        total = total + #rows
                        offset = offset + #rows
                        if total % (batchSize * 10) == 0 then
                            logInfo(("Transfer %s progress: %d rows"):format(tableName, total))
                        end

                        step()
                    end)
                end

                logInfo(("Transfer %s (mysql -> sqlite) started (batch=%d, mode=%s)"):format(tableName, batchSize, mode))
                step()
            end)
        end

        src.onConnectionFailed = function(_, err) fail("mysql connect failed: " .. tostring(err)) end
        src:connect()
        return
    end

    fail(("Unsupported transfer direction: %s -> %s"):format(tostring(sourceType), tostring(targetType)))
end

function X:TransferTables(sourceType, sourceCfg, targetType, targetCfg, tables, opts, cb)
    if not istable(tables) or #tables == 0 then
        if cb then cb(false, "tables list empty") end
        return
    end

    local i = 1
    local function nextOne()
        local t = tables[i]
        if not t then
            if cb then cb(true) end
            return
        end

        self:TransferTable(sourceType, sourceCfg, targetType, targetCfg, t, opts, function(ok, err)
            if not ok then
                if cb then cb(false, err) end
                return
            end
            i = i + 1
            nextOne()
        end)
    end

    nextOne()
end

function X:SQLiteListTables()
    return sqliteListTables()
end