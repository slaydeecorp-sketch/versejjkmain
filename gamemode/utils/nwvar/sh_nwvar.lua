VERSE.NWVar = VERSE.NWVar or {}
local NWVar = VERSE.NWVar

NWVar.Config = NWVar.Config or {
    Channel = "VERSE::NWVar",
    UseKeyDictionary = true,
    MaxKeyLen = 64,
    MaxVarsPerEnt = 512,
    FullSyncEntsPerPacket = 48,
    FullSyncVarsBudget = 1200,
    AllowClientResyncRequest = true,
}

NWVar.TYPE_STRING = 1
NWVar.TYPE_BOOL = 2
NWVar.TYPE_INT = 3
NWVar.TYPE_FLOAT = 4
NWVar.TYPE_ENTITY = 5
NWVar.TypeName = {
    [NWVar.TYPE_STRING] = "String",
    [NWVar.TYPE_BOOL] = "Bool",
    [NWVar.TYPE_INT] = "Int",
    [NWVar.TYPE_FLOAT] = "Float",
    [NWVar.TYPE_ENTITY] = "Entity",
}

NWVar.TypeFromName = {
    String = NWVar.TYPE_STRING,
    Bool = NWVar.TYPE_BOOL,
    Int = NWVar.TYPE_INT,
    Float = NWVar.TYPE_FLOAT,
    Entity = NWVar.TYPE_ENTITY,
}

NWVar.TypeOrder = {
    NWVar.TYPE_STRING,
    NWVar.TYPE_BOOL,
    NWVar.TYPE_INT,
    NWVar.TYPE_FLOAT,
    NWVar.TYPE_ENTITY,
}

function NWVar.InferType(v)
    local t = type(v)
    if t == "string" then return NWVar.TYPE_STRING end
    if t == "boolean" then return NWVar.TYPE_BOOL end
    if t == "number" then
        if v % 1 ~= 0 then return NWVar.TYPE_FLOAT end
        return NWVar.TYPE_INT
    end

    if IsEntity and IsEntity(v) then return NWVar.TYPE_ENTITY end
    return nil
end

function NWVar.NormalizeKey(key)
    if key == nil then return nil end
    key = tostring(key)
    if key == "" then return nil end
    local maxLen = (NWVar.Config and NWVar.Config.MaxKeyLen) or 64
    if #key > maxLen then key = key:sub(1, maxLen) end
    return key
end