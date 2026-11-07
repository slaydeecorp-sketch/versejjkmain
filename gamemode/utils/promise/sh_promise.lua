VERSE.Promise = VERSE.Promise or {}
local P = VERSE.Promise

P.__index = P
P._isPromise = true

local PENDING = 0
local FULFILLED = 1
local REJECTED = 2

local function safeLog(level, msg)
    if VERSE and VERSE.Log and VERSE.Log[level] then VERSE.Log[level](VERSE.Log, msg) end
end

local function defer(fn)
    timer.Simple(0, fn)
end

local function tryRun(fn, value, resolve, reject)
    local ok, result = pcall(fn, value)
    if ok then
        resolve(result)
    else
        reject(result ~= nil and result or "unknown error")
    end
end

function P.New(executor)
    local self = setmetatable({
        _state = PENDING,
        _value = nil,
        _queue = {},
        _caught = false,
    }, P)

    local settled = false
    local function resolve(value)
        if settled then return end
        settled = true
        self:_settle(FULFILLED, value)
    end

    local function reject(reason)
        if settled then return end
        settled = true
        self:_settle(REJECTED, reason)
    end

    local ok, err = pcall(executor, resolve, reject)
    if not ok then reject(err ~= nil and err or "unknown error") end
    return self
end

function P:_settle(state, value)
    if state == REJECTED and value == nil then value = "unknown error" end
    if state == FULFILLED and type(value) == "table" and value._isPromise then
        value:_enqueue(function(v) self:_settle(FULFILLED, v) end, function(e) self:_settle(REJECTED, e) end, nil, nil)
        return
    end

    self._state = state
    self._value = value
    if state == REJECTED then defer(function() if not self._caught then safeLog("Warn", "[Promise] Unhandled rejection: " .. tostring(value)) end end) end
    local queue = self._queue
    self._queue = {}
    for i = 1, #queue do
        self:_dispatch(queue[i])
    end
end

function P:_enqueue(onFulfill, onReject, resolve, reject)
    local entry = {onFulfill, onReject, resolve or function() end, reject or function() end}
    if self._state == PENDING then
        self._queue[#self._queue + 1] = entry
    else
        self:_dispatch(entry)
    end
end

function P:_dispatch(entry)
    local state = self._state
    local value = self._value
    defer(function()
        local fn
        if state == FULFILLED then
            fn = entry[1]
        else
            fn = entry[2]
        end
        if isfunction(fn) then
            tryRun(fn, value, entry[3], entry[4])
        else
            if state == FULFILLED then
                entry[3](value)
            else
                entry[4](value)
            end
        end
    end)
end

function P:Next(onFulfill, onReject)
    if isfunction(onReject) then self._caught = true end
    return P.New(function(resolve, reject) self:_enqueue(isfunction(onFulfill) and function(v) tryRun(onFulfill, v, resolve, reject) end or nil, isfunction(onReject) and function(e) tryRun(onReject, e, resolve, reject) end or nil, resolve, reject) end)
end

function P:Catch(onReject)
    return self:Next(nil, onReject)
end

function P:Finally(fn)
    return self:Next(function(v)
        local ok, err = pcall(fn)
        if not ok then error(err, 0) end
        return v
    end, function(e)
        local ok, err = pcall(fn)
        if not ok then error(err ~= nil and err or "unknown error", 0) end
        error(e ~= nil and e or "unknown error", 0)
    end)
end

function P.Resolve(value)
    return P.New(function(resolve) resolve(value) end)
end

function P.Reject(reason)
    return P.New(function(_, reject) reject(reason) end)
end

function P.All(list)
    if #list == 0 then return P.Resolve({}) end
    return P.New(function(resolve, reject)
        local results = {}
        local remaining = #list
        local done = false
        for i, p in ipairs(list) do
            p:Next(function(v)
                if done then return end
                results[i] = v
                remaining = remaining - 1
                if remaining == 0 then resolve(results) end
            end):Catch(function(e)
                if done then return end
                done = true
                reject(e)
            end)
        end
    end)
end

function P.AllSettled(list)
    if #list == 0 then return P.Resolve({}) end
    return P.New(function(resolve)
        local results = {}
        local remaining = #list
        local function finish(i, entry)
            results[i] = entry
            remaining = remaining - 1
            if remaining == 0 then resolve(results) end
        end

        for i, p in ipairs(list) do
            local idx = i
            p:Next(function(v)
                finish(idx, {
                    status = "fulfilled",
                    value = v
                })
            end):Catch(function(e)
                finish(idx, {
                    status = "rejected",
                    reason = e
                })
            end)
        end
    end)
end

function P.Race(list)
    return P.New(function(resolve, reject)
        local done = false
        for _, p in ipairs(list) do
            p:Next(function(v)
                if done then return end
                done = true
                resolve(v)
            end):Catch(function(e)
                if done then return end
                done = true
                reject(e)
            end)
        end
    end)
end