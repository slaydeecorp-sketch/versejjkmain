local P = VERSE.Promise
local DB = VERSE.DB

function P.DB(sql)
    return DB:Query(sql)
end

function P.DBValue(sql)
    return DB:QueryValue(sql)
end

function P.WhenReady()
    return DB:OnReady()
end

function P.Transaction(list)
    return DB:TransactionP(list)
end