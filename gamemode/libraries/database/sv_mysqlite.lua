require("mysqloo")

local debug = debug
local error = error
local ErrorNoHalt = ErrorNoHalt
local hook = hook
local pairs = pairs
local require = require
local sql = sql
local string = string
local table = table
local timer = timer
local tostring = tostring
local mysqlOO
local TMySQL
local _G = _G
local ipairs = ipairs
local type = type
local pcall = pcall
local unpack = unpack
local isstring = isstring
local isnumber = isnumber
local istable = istable
local multistatements
local MySQLite_config = MySQLite_config or RP_MySQLConfig or FPP_MySQLConfig
local moduleLoaded

local function loadMySQLModule()
    if moduleLoaded or not MySQLite_config or not MySQLite_config.EnableMySQL then return end
    local moo, tmsql = util.IsBinaryModuleInstalled("mysqloo"), util.IsBinaryModuleInstalled("tmysql4")
    if not moo and not tmsql then error("Could not find a suitable MySQL module. Please either:\n  - Install tmysql. It can be obtained from https://github.com/SuperiorServers/gm_tmysql4\n  - Install MySQLOO. It can be obtained from https://github.com/FredyH/MySQLOO\nDue to this error, MySQL is disabled. This means that SQLite is used instead to store data.") end
    moduleLoaded = true
    require(moo and tmsql and MySQLite_config.Preferred_module or moo and "mysqloo" or tmsql and "tmysql4")
    multistatements = CLIENT_MULTI_STATEMENTS
    mysqlOO = mysqloo
    TMySQL = tmysql
    if MySQLite_config.Preferred_module == "tmysql4" then
        if not tmsql then
            ErrorNoHalt("The preferred module for MySQL is selected to be tmysql4. However, tmysql4 does not appear to be installed. Please either:\n  - Install tmysql. It can be obtained from https://github.com/SuperiorServers/gm_tmysql4\n  - Select MySQLOO as the preferred module for MySQL. MySQLOO appears to be installed.")
            return
        end

        if not tmysql.Version or tmysql.Version < 4.1 then
            MsgC(Color(255, 0, 0), "Using older tmysql version, please consider updating!\n")
            MsgC(Color(255, 0, 0), "Newer Version: https://github.com/SuperiorServers/gm_tmysql4\n")
        end

        TMySQL.Connect = tmysql.Version and tmysql.Version >= 4.1 and TMySQL.Connect or TMySQL.initialize
        TMySQL.SetOption = tmysql.Version and tmysql.Version >= 4.1 and TMySQL.SetOption or TMySQL.Option
    else
        if not moo then ErrorNoHalt("The preferred module for MySQL is selected to be MySQLOO. However, MySQLOO does not appear to be installed. Please either:\n  - Install MySQLOO. It can be obtained from https://github.com/FredyH/MySQLOO\n  - Select tmysql4 as the preferred module for MySQL. tmysql4 appears to be installed.") end
    end
end

loadMySQLModule()
module("MySQLite")
local function arbitraryTableValue(tbl)
    for _, v in pairs(tbl) do
        return v
    end
end

function initialize(config)
    MySQLite_config = config or MySQLite_config
    if not MySQLite_config then ErrorNoHalt("Warning: No MySQL config!") end
    loadMySQLModule()
    if MySQLite_config.EnableMySQL then
        connectToMySQL(MySQLite_config.Host, MySQLite_config.Username, MySQLite_config.Password, MySQLite_config.Database_name, MySQLite_config.Database_port)
    else
        timer.Simple(0, function()
            _G.GAMEMODE.DatabaseInitialized = _G.GAMEMODE.DatabaseInitialized or function() end
            hook.Call("DatabaseInitialized", _G.GAMEMODE)
        end)
    end
end

local CONNECTED_TO_MYSQL = false
local connectAttempts = 0
local maxAttempts = 2
local msOOConnect
databaseObject = nil
local queuedQueries
local cachedQueries
function isMySQL()
    return CONNECTED_TO_MYSQL
end

function begin()
    if not CONNECTED_TO_MYSQL then
        sql.Begin()
    else
        if queuedQueries then
            debug.Trace()
            error("Transaction ongoing!")
        end

        queuedQueries = {}
    end
end

function commit(onFinished)
    if not CONNECTED_TO_MYSQL then
        sql.Commit()
        if onFinished then onFinished() end
        return
    end

    if not queuedQueries then error("No queued queries! Call begin() first!") end
    if #queuedQueries == 0 then
        queuedQueries = nil
        if onFinished then onFinished() end
        return
    end

    local queue = table.Copy(queuedQueries)
    queuedQueries = nil
    local queuePos = 0
    local call
    call = function(...)
        queuePos = queuePos + 1
        if queue[queuePos].callback then queue[queuePos].callback(...) end
        if queuePos + 1 > #queue then
            if onFinished then onFinished() end
            return
        end

        local nextQuery = queue[queuePos + 1]
        query(nextQuery.query, call, nextQuery.onError)
    end

    query(queue[1].query, call, queue[1].onError)
end

function queueQuery(sqlText, callback, errorCallback)
    if CONNECTED_TO_MYSQL then
        table.insert(queuedQueries, {
            query = sqlText,
            callback = callback,
            onError = errorCallback
        })
        return
    end

    query(sqlText, callback, errorCallback)
end

local function msOOQuery(sqlText, callback, errorCallback, queryValue)
    local queryObject = databaseObject:query(sqlText)
    local data
    queryObject.onData = function(Q, D)
        data = data or {}
        data[#data + 1] = D
    end

    queryObject.onError = function(Q, E)
        if databaseObject:status() == mysqlOO.DATABASE_NOT_CONNECTED then
            table.insert(cachedQueries, {sqlText, callback, queryValue})
            msOOConnect(MySQLite_config.Host, MySQLite_config.Username, MySQLite_config.Password, MySQLite_config.Database_name, MySQLite_config.Database_port)
            return
        end

        local errStr = (type(E) == "string" and E ~= "" and E)
            or (type(Q) == "string" and Q ~= "" and Q)
            or tostring(E or Q or "unknown mysql error")
        local supp = errorCallback and errorCallback(errStr, sqlText)
        if not supp then error(errStr .. " (" .. sqlText .. ")") end
    end

    queryObject.onSuccess = function()
        local res = queryValue and data and data[1] and arbitraryTableValue(data[1]) or not queryValue and data or nil
        if callback then callback(res, queryObject:lastInsert()) end
    end

    queryObject:start()
end

local preparedStatements = {}
local paramTypes = {}
paramTypes["number"] = function(queryObj, paramIndex, paramValue) return queryObj:setNumber(paramIndex, paramValue) end
paramTypes["string"] = function(queryObj, paramIndex, paramValue) return queryObj:setString(paramIndex, paramValue) end
paramTypes["boolean"] = function(queryObj, paramIndex, paramValue) return queryObj:setBoolean(paramIndex, paramValue) end
local function msOOPrepare(sqlText, sqlParams, callback, errorCallback)
    local queryObject
    if preparedStatements[sqlText] then
        queryObject = preparedStatements[sqlText]
    else
        queryObject = databaseObject:prepare(sqlText)
        preparedStatements[sqlText] = queryObject
    end

    for i, param in ipairs(sqlParams) do
        local paramType = type(param)
        if paramTypes[paramType] then
            paramTypes[paramType](queryObject, i, param)
        else
            queryObject:setString(i, param)
        end
    end

    queryObject.onError = function(_, E)
        local errStr = (type(E) == "string" and E ~= "" and E) or tostring(E or "unknown mysql error")
        local supp = errorCallback and errorCallback(errStr, sqlText)
        if not supp then error(errStr .. " (" .. sqlText .. ")") end
    end

    queryObject.onSuccess = function(_, data) if callback then callback(data, queryObject:lastInsert(), queryObject:affectedRows()) end end
    queryObject:start()
end

local function tmsqlPrepare(sqlText, sqlParams, callback, errorCallback)
    local queryObject
    if preparedStatements[sqlText] then
        queryObject = preparedStatements[sqlText]
    else
        queryObject = databaseObject:Prepare(sqlText)
        preparedStatements[sqlText] = queryObject
    end

    for i, param in ipairs(sqlParams) do
        param = SQLStr(param, true)
    end

    local varcount = queryObject:GetArgCount()
    sqlParams[varcount + 1] = function(results)
        if results[1].error ~= nil then
            local errStr = (type(results[1].error) == "string" and results[1].error ~= "" and results[1].error) or tostring(results[1].error or "unknown tmysql error")
            local supp = errorCallback and errorCallback(errStr, sqlText)
            if not supp then error(errStr .. " (" .. sqlText .. ")") end
        end

        if callback then callback(results[1].data, results[1].lastid, results[1].affected) end
    end

    queryObject:Run(unpack(sqlParams, 1, varcount + 2))
end

local function tmsqlQuery(sqlText, callback, errorCallback, queryValue)
    local call = function(res)
        res = res[1]
        if not res.status then
            local errStr = (type(res.error) == "string" and res.error ~= "" and res.error) or tostring(res.error or "unknown tmysql error")
            local supp = errorCallback and errorCallback(errStr, sqlText)
            if not supp then error(errStr .. " (" .. sqlText .. ")") end
            return
        end

        if not res.data or #res.data == 0 then res.data = nil end
        if queryValue and callback then return callback(res.data and res.data[1] and arbitraryTableValue(res.data[1]) or nil) end
        if callback then callback(res.data, res.lastid) end
    end

    databaseObject:Query(sqlText, call)
end

local function SQLiteQuery(sqlText, callback, errorCallback, queryValue)
    local Result = queryValue and sql.QueryValue(sqlText) or sql.Query(sqlText)
    if Result == false then
        local err = sql.LastError()
        if not isstring(err) or err == "" then err = "SQL error: " .. tostring(sqlText):sub(1, 200) end
        local supp = errorCallback and errorCallback(err, sqlText)
        if supp == false then error(err .. " (" .. sqlText .. ")", 2) end
        return
    end

    if callback then callback(Result) end
    return Result
end

local function SQLitePrepare(sqlText, sqlParams, callback, errorCallback)
    for _, param in ipairs(sqlParams) do
        sqlText = sqlText:gsub("%?", sql.SQLStr(param), 1)
    end
    return SQLiteQuery(sqlText, callback, errorCallback, false)
end

function query(sqlText, callback, errorCallback)
    local qFunc = (CONNECTED_TO_MYSQL and ((mysqlOO and msOOQuery) or (TMySQL and tmsqlQuery))) or SQLiteQuery
    return qFunc(sqlText, callback, errorCallback, false)
end

function queryValue(sqlText, callback, errorCallback)
    local qFunc = (CONNECTED_TO_MYSQL and ((mysqlOO and msOOQuery) or (TMySQL and tmsqlQuery))) or SQLiteQuery
    return qFunc(sqlText, callback, errorCallback, true)
end

function prepare(sqlText, sqlParams, callback, errorCallback)
    local qFunc = (CONNECTED_TO_MYSQL and ((mysqlOO and msOOPrepare) or (TMySQL and tmsqlPrepare))) or SQLitePrepare
    return qFunc(sqlText, sqlParams, callback, errorCallback, false)
end

local function onConnected()
    CONNECTED_TO_MYSQL = true
    for k, v in pairs(cachedQueries or {}) do
        cachedQueries[k] = nil
        if v[3] then
            queryValue(v[1], v[2])
        else
            query(v[1], v[2])
        end
    end

    cachedQueries = {}
    local GM = _G.GAMEMODE or _G.GM
    hook.Call("DatabaseInitialized", GM.DatabaseInitialized and GM or nil)
end

msOOConnect = function(host, username, password, database_name, database_port)
    databaseObject = mysqlOO.connect(host, username, password, database_name, database_port)
    databaseObject.onConnectionFailed = function(_, msg)
        connectAttempts = (connectAttempts or 0) + 1

        local m = tostring(msg or "unknown")
        ErrorNoHalt(("[MySQLite] Connection failed (%d/%d): %s | retry in 5 seconds\n")
            :format(connectAttempts, maxAttempts, m))

        if connectAttempts >= maxAttempts then
            ErrorNoHalt("[MySQLite] Max attempts reached. Falling back to SQLite mode.\n")

            CONNECTED_TO_MYSQL = false
            MySQLite_config.EnableMySQL = false
            databaseObject = nil

            timer.Simple(0, function()
                _G.GAMEMODE.DatabaseInitialized = _G.GAMEMODE.DatabaseInitialized or function() end
                hook.Call("DatabaseInitialized", _G.GAMEMODE)
            end)

            return
        end

        timer.Simple(5, function()
            msOOConnect(MySQLite_config.Host, MySQLite_config.Username, MySQLite_config.Password, MySQLite_config.Database_name, MySQLite_config.Database_port)
        end)
    end

    databaseObject.onConnected = onConnected
    databaseObject:connect()
end

local function tmsqlConnect(host, username, password, database_name, database_port)
    local db, err = TMySQL.Connect(host, username, password, database_name, database_port, nil, MySQLite_config.MultiStatements and multistatements or nil)
    if err then error("Connection failed! " .. err .. "\n") end
    databaseObject = db
    onConnected()
    if TMySQL.Version and TMySQL.Version >= 4.1 then hook.Add("Think", "MySQLite:tmysqlPoll", function() db:Poll() end) end
end

function connectToMySQL(host, username, password, database_name, database_port)
    database_port = database_port or 3306
    local func = mysqlOO and msOOConnect or TMySQL and tmsqlConnect or function() end
    func(host, username, password, database_name, database_port)
end

function SQLStr(sqlStr)
    local escape = not CONNECTED_TO_MYSQL and sql.SQLStr or mysqlOO and function(str) return "\"" .. databaseObject:escape(tostring(str)) .. "\"" end or TMySQL and function(str) return "\"" .. databaseObject:Escape(tostring(str)) .. "\"" end
    return escape(sqlStr)
end

function tableExists(tbl, callback, errorCallback)
    if not CONNECTED_TO_MYSQL then
        local exists = sql.TableExists(tbl)
        callback(exists)
        return exists
    end

    queryValue(string.format("SHOW TABLES LIKE %s", SQLStr(tbl)), function(v) callback(v ~= nil) end, errorCallback)
end