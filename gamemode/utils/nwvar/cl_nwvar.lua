local NWVar = VERSE.NWVar

local OP_KEYS = 1
local OP_SET = 2
local OP_UNSET = 3
local OP_CLEAR = 4
local OP_FULLSYNC = 5
local OP_REQSYNC = 6
local SCOPE_PUBLIC = 1
local SCOPE_PRIVATE = 2

NWVar._idToKey = NWVar._idToKey or {}

local function readKey()
    local isId = net.ReadBool()
    if isId then
        local id = net.ReadUInt(16)
        return NWVar._idToKey[id]
    else
        local s = net.ReadString()
        return NWVar.NormalizeKey(s)
    end
end

local function readTyped(typeId)
    if typeId == NWVar.TYPE_STRING then
        return net.ReadString()
    elseif typeId == NWVar.TYPE_BOOL then
        return net.ReadBool()
    elseif typeId == NWVar.TYPE_INT then
        return net.ReadInt(32)
    elseif typeId == NWVar.TYPE_FLOAT then
        return net.ReadFloat()
    elseif typeId == NWVar.TYPE_ENTITY then
        return net.ReadEntity()
    end
    return nil
end

local function ensureClientTables(ent)
    ent.__verse_nwvar_pub = ent.__verse_nwvar_pub or {}
    ent.__verse_nwvar_priv = ent.__verse_nwvar_priv or {}
    for _, t in ipairs(NWVar.TypeOrder) do
        ent.__verse_nwvar_pub[t] = ent.__verse_nwvar_pub[t] or {}
        ent.__verse_nwvar_priv[t] = ent.__verse_nwvar_priv[t] or {}
    end
end

local function applySet(scope, ent, typeId, key, value)
    if not IsValid(ent) or not key then return end
    ensureClientTables(ent)
    local map = (scope == SCOPE_PUBLIC) and ent.__verse_nwvar_pub[typeId] or ent.__verse_nwvar_priv[typeId]
    local old = map[key]
    map[key] = value
    VERSE.Hook.Run("VERSE.NWVarChanged", ent, scope == SCOPE_PUBLIC and "public" or "private", typeId, key, old, value)
end

local function applyUnset(scope, ent, typeId, key)
    if not IsValid(ent) or not key then return end
    ensureClientTables(ent)
    local map = (scope == SCOPE_PUBLIC) and ent.__verse_nwvar_pub[typeId] or ent.__verse_nwvar_priv[typeId]
    local old = map[key]
    map[key] = nil
    VERSE.Hook.Run("VERSE.NWVarChanged", ent, scope == SCOPE_PUBLIC and "public" or "private", typeId, key, old, nil)
end

local function applyClear(scope, ent, typeIdOr0)
    if not IsValid(ent) then return end
    ensureClientTables(ent)
    local target = (scope == SCOPE_PUBLIC) and ent.__verse_nwvar_pub or ent.__verse_nwvar_priv
    if typeIdOr0 ~= 0 then
        target[typeIdOr0] = {}
        return
    end

    for _, t in ipairs(NWVar.TypeOrder) do
        target[t] = {}
    end
end

net.Receive(NWVar.Config.Channel, function()
    local op = net.ReadUInt(3)
    if op == OP_KEYS then
        local fromId = net.ReadUInt(16)
        local toId = net.ReadUInt(16)
        for id = fromId, toId do
            NWVar._idToKey[id] = NWVar.NormalizeKey(net.ReadString())
        end
        return
    end

    if op == OP_SET then
        local scope = net.ReadUInt(2)
        local ent = net.ReadEntity()
        local typeId = net.ReadUInt(3)
        local key = readKey()
        local value = readTyped(typeId)
        applySet(scope, ent, typeId, key, value)
        return
    end

    if op == OP_UNSET then
        local scope = net.ReadUInt(2)
        local ent = net.ReadEntity()
        local typeId = net.ReadUInt(3)
        local key = readKey()
        applyUnset(scope, ent, typeId, key)
        return
    end

    if op == OP_CLEAR then
        local scope = net.ReadUInt(2)
        local ent = net.ReadEntity()
        local typeIdOr0 = net.ReadUInt(3)
        applyClear(scope, ent, typeIdOr0)
        return
    end

    if op == OP_FULLSYNC then
        local isFirst = net.ReadBool()
        local isLast = net.ReadBool()
        local entCount = net.ReadUInt(14)
        for _ = 1, entCount do
            local ent = net.ReadEntity()
            if IsValid(ent) then ensureClientTables(ent) end
            for _ = 1, #NWVar.TypeOrder do
                local typeId = net.ReadUInt(3)
                local len = net.ReadUInt(12)
                for _ = 1, len do
                    local key = readKey()
                    local value = readTyped(typeId)
                    if IsValid(ent) and key then
                        ensureClientTables(ent)
                        ent.__verse_nwvar_pub[typeId][key] = value
                    end
                end
            end

            local hasPriv = net.ReadBool()
            if hasPriv then
                for _ = 1, #NWVar.TypeOrder do
                    local typeId = net.ReadUInt(3)
                    local len = net.ReadUInt(12)
                    for _ = 1, len do
                        local key = readKey()
                        local value = readTyped(typeId)
                        if IsValid(ent) and key then
                            ensureClientTables(ent)
                            ent.__verse_nwvar_priv[typeId][key] = value
                        end
                    end
                end
            end
        end

        VERSE.Hook.Run("VERSE.NWVarFullSync", isFirst, isLast)
        return
    end
end)

function NWVar.RequestResync()
    if NWVar.Config.AllowClientResyncRequest ~= true then return end
    net.Start(NWVar.Config.Channel)
    net.WriteUInt(OP_REQSYNC, 3)
    net.SendToServer()
end

local ENTITY = FindMetaTable("Entity")
local function makeGetClient(scope, typeId)
    return function(self, key, default)
        if not IsValid(self) then return default end
        key = NWVar.NormalizeKey(key)
        if not key then return default end
        ensureClientTables(self)
        local root = (scope == SCOPE_PUBLIC) and self.__verse_nwvar_pub or self.__verse_nwvar_priv
        local v = root[typeId][key]
        if v ~= nil then return v end
        return default
    end
end

for name, typeId in pairs(NWVar.TypeFromName) do
    ENTITY["GetPublic" .. name] = makeGetClient(SCOPE_PUBLIC, typeId)
    ENTITY["GetPrivate" .. name] = makeGetClient(SCOPE_PRIVATE, typeId)
end