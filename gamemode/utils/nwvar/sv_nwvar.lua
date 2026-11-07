local NWVar = VERSE.NWVar

util.AddNetworkString(NWVar.Config.Channel)

local OP_KEYS = 1
local OP_SET = 2
local OP_UNSET = 3
local OP_CLEAR = 4
local OP_FULLSYNC = 5
local OP_REQSYNC = 6
local SCOPE_PUBLIC = 1
local SCOPE_PRIVATE = 2

NWVar._pub = NWVar._pub or {}
NWVar._priv = NWVar._priv or {}
NWVar._keyToId = NWVar._keyToId or {}
NWVar._idToKey = NWVar._idToKey or {}
NWVar._nextKeyId = NWVar._nextKeyId or 1
NWVar._plyKnownKeyMax = NWVar._plyKnownKeyMax or {}

local function isValidPly(p)
    return IsValid(p) and p:IsPlayer()
end

local function ensureEntTables(ent)
    NWVar._pub[ent] = NWVar._pub[ent] or {}
    NWVar._priv[ent] = NWVar._priv[ent] or {}
    for _, t in ipairs(NWVar.TypeOrder) do
        NWVar._pub[ent][t] = NWVar._pub[ent][t] or {}
    end
end

local function ensurePrivTables(ent, ply)
    ensureEntTables(ent)
    local map = NWVar._priv[ent]
    map[ply] = map[ply] or {}
    for _, t in ipairs(NWVar.TypeOrder) do
        map[ply][t] = map[ply][t] or {}
    end
end

local function countVarsForEntPublic(ent)
    local sum = 0
    local pub = NWVar._pub[ent]
    if not pub then return 0 end
    for _, t in ipairs(NWVar.TypeOrder) do
        for _ in pairs(pub[t] or {}) do
            sum = sum + 1
        end
    end
    return sum
end

local function countVarsForEntPrivate(ent, ply)
    local sum = 0
    local priv = NWVar._priv[ent]
    if not priv or not priv[ply] then return 0 end
    for _, t in ipairs(NWVar.TypeOrder) do
        for _ in pairs(priv[ply][t] or {}) do
            sum = sum + 1
        end
    end
    return sum
end

function NWVar:GetKeyId(key)
    key = NWVar.NormalizeKey(key)
    if not key then return nil end
    local id = self._keyToId[key]
    if id then return id end
    id = self._nextKeyId
    self._nextKeyId = id + 1
    self._keyToId[key] = id
    self._idToKey[id] = key
    return id
end

local function sendKeyUpdates(ply)
    if not NWVar.Config.UseKeyDictionary then return end
    if not isValidPly(ply) then return end
    local knownMax = NWVar._plyKnownKeyMax[ply] or 0
    local nextId = NWVar._nextKeyId or 1
    local maxId = nextId - 1
    if maxId <= knownMax then return end
    net.Start(NWVar.Config.Channel)
    net.WriteUInt(OP_KEYS, 3)
    net.WriteUInt(knownMax + 1, 16)
    net.WriteUInt(maxId, 16)
    for id = knownMax + 1, maxId do
        net.WriteString(NWVar._idToKey[id] or "")
    end

    net.Send(ply)
    NWVar._plyKnownKeyMax[ply] = maxId
end

local function writeTyped(typeId, value)
    if typeId == NWVar.TYPE_STRING then
        net.WriteString(tostring(value or ""))
    elseif typeId == NWVar.TYPE_BOOL then
        net.WriteBool(value == true)
    elseif typeId == NWVar.TYPE_INT then
        net.WriteInt(tonumber(value) or 0, 32)
    elseif typeId == NWVar.TYPE_FLOAT then
        net.WriteFloat(tonumber(value) or 0)
    elseif typeId == NWVar.TYPE_ENTITY then
        net.WriteEntity(IsValid(value) and value or Entity(0))
    else
        net.WriteString(tostring(value or ""))
    end
end

local function writeKey(key)
    if NWVar.Config.UseKeyDictionary then
        local id = NWVar:GetKeyId(key)
        net.WriteBool(true)
        net.WriteUInt(id or 0, 16)
    else
        net.WriteBool(false)
        net.WriteString(key or "")
    end
end

local function sendSet(recips, scope, ent, typeId, key, value)
    if not IsValid(ent) then return end
    if not recips then return end
    if NWVar.Config.UseKeyDictionary then
        if recips == true then
            for _, p in ipairs(player.GetAll()) do
                sendKeyUpdates(p)
            end
        elseif istable(recips) then
            for _, p in ipairs(recips) do
                sendKeyUpdates(p)
            end
        elseif isValidPly(recips) then
            sendKeyUpdates(recips)
        end
    end

    net.Start(NWVar.Config.Channel)
    net.WriteUInt(OP_SET, 3)
    net.WriteUInt(scope, 2)
    net.WriteEntity(ent)
    net.WriteUInt(typeId, 3)
    writeKey(key)
    writeTyped(typeId, value)
    if recips == true then
        net.Broadcast()
    elseif istable(recips) then
        net.Send(recips)
    elseif isValidPly(recips) then
        net.Send(recips)
    end
end

local function sendUnset(recips, scope, ent, typeId, key)
    if not IsValid(ent) then return end
    if not recips then return end
    if NWVar.Config.UseKeyDictionary then
        if recips == true then
            for _, p in ipairs(player.GetAll()) do
                sendKeyUpdates(p)
            end
        elseif istable(recips) then
            for _, p in ipairs(recips) do
                sendKeyUpdates(p)
            end
        elseif isValidPly(recips) then
            sendKeyUpdates(recips)
        end
    end

    net.Start(NWVar.Config.Channel)
    net.WriteUInt(OP_UNSET, 3)
    net.WriteUInt(scope, 2)
    net.WriteEntity(ent)
    net.WriteUInt(typeId, 3)
    writeKey(key)
    if recips == true then
        net.Broadcast()
    elseif istable(recips) then
        net.Send(recips)
    elseif isValidPly(recips) then
        net.Send(recips)
    end
end

local function sendClear(recips, scope, ent, typeIdOr0)
    if not IsValid(ent) then return end
    if not recips then return end
    net.Start(NWVar.Config.Channel)
    net.WriteUInt(OP_CLEAR, 3)
    net.WriteUInt(scope, 2)
    net.WriteEntity(ent)
    net.WriteUInt(typeIdOr0 or 0, 3)
    if recips == true then
        net.Broadcast()
    elseif istable(recips) then
        net.Send(recips)
    elseif isValidPly(recips) then
        net.Send(recips)
    end
end

function NWVar:SetPublic(ent, key, value, typeId)
    if not IsValid(ent) then return end
    key = NWVar.NormalizeKey(key)
    if not key then return end
    typeId = typeId or NWVar.InferType(value)
    if not typeId then return end
    ensureEntTables(ent)
    if countVarsForEntPublic(ent) >= (NWVar.Config.MaxVarsPerEnt or 512) then return end
    local bucket = NWVar._pub[ent][typeId]
    local old = bucket[key]
    bucket[key] = value
    sendSet(true, SCOPE_PUBLIC, ent, typeId, key, value)
    VERSE.Hook.Run("VERSE.NWVarChanged", ent, "public", typeId, key, old, value)
end

function NWVar:UnsetPublic(ent, key, typeId)
    if not IsValid(ent) then return end
    key = NWVar.NormalizeKey(key)
    if not key then return end
    ensureEntTables(ent)
    if typeId then
        local bucket = NWVar._pub[ent][typeId]
        local old = bucket and bucket[key]
        if bucket then bucket[key] = nil end
        sendUnset(true, SCOPE_PUBLIC, ent, typeId, key)
        VERSE.Hook.Run("VERSE.NWVarChanged", ent, "public", typeId, key, old, nil)
        return
    end

    for _, t in ipairs(NWVar.TypeOrder) do
        local bucket = NWVar._pub[ent][t]
        if bucket and bucket[key] ~= nil then
            local old = bucket[key]
            bucket[key] = nil
            sendUnset(true, SCOPE_PUBLIC, ent, t, key)
            VERSE.Hook.Run("VERSE.NWVarChanged", ent, "public", t, key, old, nil)
            break
        end
    end
end

function NWVar:ClearPublic(ent, typeIdOrNil)
    if not IsValid(ent) then return end
    ensureEntTables(ent)
    if typeIdOrNil then
        NWVar._pub[ent][typeIdOrNil] = {}
        sendClear(true, SCOPE_PUBLIC, ent, typeIdOrNil)
        return
    end

    for _, t in ipairs(NWVar.TypeOrder) do
        NWVar._pub[ent][t] = {}
    end

    sendClear(true, SCOPE_PUBLIC, ent, 0)
end

function NWVar:SetPrivate(ent, ply, key, value, typeId)
    if not (IsValid(ent) and isValidPly(ply)) then return end
    key = NWVar.NormalizeKey(key)
    if not key then return end
    typeId = typeId or NWVar.InferType(value)
    if not typeId then return end
    ensurePrivTables(ent, ply)
    if countVarsForEntPrivate(ent, ply) >= (NWVar.Config.MaxVarsPerEnt or 512) then return end
    local bucket = NWVar._priv[ent][ply][typeId]
    local old = bucket[key]
    bucket[key] = value
    sendSet(ply, SCOPE_PRIVATE, ent, typeId, key, value)
    VERSE.Hook.Run("VERSE.NWVarChanged", ent, "private", typeId, key, old, value, ply)
end

function NWVar:UnsetPrivate(ent, ply, key, typeId)
    if not (IsValid(ent) and isValidPly(ply)) then return end
    key = NWVar.NormalizeKey(key)
    if not key then return end
    ensurePrivTables(ent, ply)
    if typeId then
        local bucket = NWVar._priv[ent][ply][typeId]
        local old = bucket and bucket[key]
        if bucket then bucket[key] = nil end
        sendUnset(ply, SCOPE_PRIVATE, ent, typeId, key)
        VERSE.Hook.Run("VERSE.NWVarChanged", ent, "private", typeId, key, old, nil, ply)
        return
    end

    for _, t in ipairs(NWVar.TypeOrder) do
        local bucket = NWVar._priv[ent][ply][t]
        if bucket and bucket[key] ~= nil then
            local old = bucket[key]
            bucket[key] = nil
            sendUnset(ply, SCOPE_PRIVATE, ent, t, key)
            VERSE.Hook.Run("VERSE.NWVarChanged", ent, "private", t, key, old, nil, ply)
            break
        end
    end
end

function NWVar:ClearPrivate(ent, ply, typeIdOrNil)
    if not (IsValid(ent) and isValidPly(ply)) then return end
    ensurePrivTables(ent, ply)
    if typeIdOrNil then
        NWVar._priv[ent][ply][typeIdOrNil] = {}
        sendClear(ply, SCOPE_PRIVATE, ent, typeIdOrNil)
        return
    end

    for _, t in ipairs(NWVar.TypeOrder) do
        NWVar._priv[ent][ply][t] = {}
    end

    sendClear(ply, SCOPE_PRIVATE, ent, 0)
end

local function writeKeyForFullSync(ply, key)
    if NWVar.Config.UseKeyDictionary then
        local id = NWVar:GetKeyId(key)
        sendKeyUpdates(ply)
        net.WriteBool(true)
        net.WriteUInt(id or 0, 16)
    else
        net.WriteBool(false)
        net.WriteString(key or "")
    end
end

local function writeVarMap(ply, typeId, map, budgetRef)
    local count = 0
    for _ in pairs(map) do
        count = count + 1
    end

    net.WriteUInt(typeId, 3)
    net.WriteUInt(count, 12)
    for k, v in pairs(map) do
        if budgetRef and budgetRef.left then
            budgetRef.left = budgetRef.left - 1
            if budgetRef.left < 0 then break end
        end

        writeKeyForFullSync(ply, k)
        writeTyped(typeId, v)
    end
end

function NWVar:FullSync(ply)
    if not isValidPly(ply) then return end
    sendKeyUpdates(ply)
    local entsList, n = {}, 0
    for ent, _ in pairs(self._pub) do
        if IsValid(ent) then
            n = n + 1
            entsList[n] = ent
        else
            self._pub[ent] = nil
            self._priv[ent] = nil
        end
    end

    local perPacket = self.Config.FullSyncEntsPerPacket or 48
    local budgetMax = self.Config.FullSyncVarsBudget or 1200
    local idx = 1
    while idx <= n do
        local last = math.min(idx + perPacket - 1, n)
        local budget = {
            left = budgetMax
        }

        net.Start(self.Config.Channel)
        net.WriteUInt(OP_FULLSYNC, 3)
        net.WriteBool(idx == 1)
        net.WriteBool(last == n)
        net.WriteUInt(last - idx + 1, 14)
        for i = idx, last do
            local ent = entsList[i]
            net.WriteEntity(ent)
            for _, t in ipairs(self.TypeOrder) do
                writeVarMap(ply, t, (self._pub[ent] and self._pub[ent][t]) or {}, budget)
            end

            local privMap = self._priv[ent] and self._priv[ent][ply]
            if privMap then
                net.WriteBool(true)
                for _, t in ipairs(self.TypeOrder) do
                    writeVarMap(ply, t, privMap[t] or {}, budget)
                end
            else
                net.WriteBool(false)
            end
        end

        net.Send(ply)
        idx = last + 1
    end
end

VERSE.Hook.AddNS("NWVar", "EntityRemoved", "VERSE::EntityRemoved::NWVar", function(ent)
    if NWVar._pub[ent] then NWVar._pub[ent] = nil end
    if NWVar._priv[ent] then NWVar._priv[ent] = nil end
end)

VERSE.Hook.AddNS("NWVar", "PlayerDisconnected", "VERSE::PlayerDisconnected::NWVar", function(ply)
    NWVar._plyKnownKeyMax[ply] = nil
    for ent, map in pairs(NWVar._priv) do
        if map and map[ply] then map[ply] = nil end
        if not IsValid(ent) then NWVar._priv[ent] = nil end
    end
end)

VERSE.Hook.AddNS("NWVar", "PlayerInitialSpawn", "VERSE::PlayerInitialSpawn::NWVar", function(ply)
    timer.Simple(1, function()
        if isValidPly(ply) then
            NWVar:FullSync(ply)
        end
    end)
end)

net.Receive(NWVar.Config.Channel, function(_, ply)
    if not isValidPly(ply) then return end
    local op = net.ReadUInt(3)
    if op == OP_REQSYNC then
        if NWVar.Config.AllowClientResyncRequest ~= true then return end
        NWVar:FullSync(ply)
    end
end)

local ENTITY = FindMetaTable("Entity")
local function makeGetPublic(typeId)
    return function(self, key, default)
        if not IsValid(self) then return default end
        key = NWVar.NormalizeKey(key)
        if not key then return default end
        ensureEntTables(self)
        local v = NWVar._pub[self][typeId][key]
        if v ~= nil then return v end
        return default
    end
end

local function makeGetPrivate(typeId)
    return function(self, ply, key, default)
        if not (IsValid(self) and isValidPly(ply)) then return default end
        key = NWVar.NormalizeKey(key)
        if not key then return default end
        ensurePrivTables(self, ply)
        local v = NWVar._priv[self][ply][typeId][key]
        if v ~= nil then return v end
        return default
    end
end

local function makeSetPublic(typeId)
    return function(self, key, value) NWVar:SetPublic(self, key, value, typeId) end
end

local function makeSetPrivate(typeId)
    return function(self, ply, key, value) NWVar:SetPrivate(self, ply, key, value, typeId) end
end

for name, typeId in pairs(NWVar.TypeFromName) do
    ENTITY["GetPublic" .. name] = makeGetPublic(typeId)
    ENTITY["GetPrivate" .. name] = makeGetPrivate(typeId)
    ENTITY["SetPublic" .. name] = makeSetPublic(typeId)
    ENTITY["SetPrivate" .. name] = makeSetPrivate(typeId)
end

function ENTITY:SetPublicNW(key, value, typeId)
    NWVar:SetPublic(self, key, value, typeId)
end

function ENTITY:SetPrivateNW(ply, key, value, typeId)
    NWVar:SetPrivate(self, ply, key, value, typeId)
end

function ENTITY:UnsetPublicNW(key, typeId)
    NWVar:UnsetPublic(self, key, typeId)
end

function ENTITY:UnsetPrivateNW(ply, key, typeId)
    NWVar:UnsetPrivate(self, ply, key, typeId)
end

function ENTITY:ClearPublicNW(typeIdOrNil)
    NWVar:ClearPublic(self, typeIdOrNil)
end

function ENTITY:ClearPrivateNW(ply, typeIdOrNil)
    NWVar:ClearPrivate(self, ply, typeIdOrNil)
end