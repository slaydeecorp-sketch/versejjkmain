local A = VERSE.Access

local function hasSpawnRight(rights, key)
    local s = rights and rights.Spawn
    return istable(s) and s[key] == true
end

local function callBase(self, fn, ...)
    if self.BaseClass and isfunction(self.BaseClass[fn]) then
        return self.BaseClass[fn](self, ...)
    end

    local sb = gmod.GetGamemode and gmod.GetGamemode()
    if sb and sb.BaseClass and isfunction(sb.BaseClass[fn]) then
        return sb.BaseClass[fn](self, ...)
    end

    return true
end

function GM:PlayerSpawnProp(ply, model)
    local r = A:GetRights(ply)
    if not hasSpawnRight(r, "prop") then return false end
    return callBase(self, "PlayerSpawnProp", ply, model)
end

function GM:PlayerSpawnEffect(ply, model)
    local r = A:GetRights(ply)
    if not hasSpawnRight(r, "effect") then return false end
    return callBase(self, "PlayerSpawnEffect", ply, model)
end

function GM:PlayerSpawnRagdoll(ply, model)
    local r = A:GetRights(ply)
    if not hasSpawnRight(r, "ragdoll") then return false end
    return callBase(self, "PlayerSpawnRagdoll", ply, model)
end

function GM:PlayerSpawnSWEP(ply, class, wep)
    local r = A:GetRights(ply)
    if not hasSpawnRight(r, "swep") then return false end
    return callBase(self, "PlayerSpawnSWEP", ply, class, wep)
end

function GM:PlayerSpawnSENT(ply, class)
    local r = A:GetRights(ply)
    if not hasSpawnRight(r, "sent") then return false end
    return callBase(self, "PlayerSpawnSENT", ply, class)
end

function GM:PlayerSpawnNPC(ply, npcType, wep)
    local r = A:GetRights(ply)
    if not hasSpawnRight(r, "npc") then return false end
    return callBase(self, "PlayerSpawnNPC", ply, npcType, wep)
end

function GM:PlayerSpawnVehicle(ply, model, name, tbl)
    local r = A:GetRights(ply)
    if not hasSpawnRight(r, "vehicle") then return false end
    return callBase(self, "PlayerSpawnVehicle", ply, model, name, tbl)
end

function GM:CanTool(ply, tr, tool)
    local r = A:GetRights(ply)
    if not r or r.CanTool ~= true then return false end
    return callBase(self, "CanTool", ply, tr, tool)
end

function GM:CanDrive(ply, ent)
    local r = A:GetRights(ply)
    if not r or r.CanDrive ~= true then return false end
    return callBase(self, "CanDrive", ply, ent)
end

function GM:CanProperty(ply, property, ent)
    local r = A:GetRights(ply) or {}
    local allowed = r.AllowedProperties

    if istable(allowed) and allowed[property] ~= true then
        return false
    end

    return true
end

function GM:PlayerNoClip(ply, desiredState)
    local r = A:GetRights(ply)
    if not r or r.CanNoclip ~= true then return false end
    return callBase(self, "PlayerNoClip", ply, desiredState)
end