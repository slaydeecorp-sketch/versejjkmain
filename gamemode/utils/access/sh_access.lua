VERSE.Config.Access = {
    Developers = {
        "STEAM_0:1:169787079", --- slayde
        "STEAM_0:0:65692862", --- call me zin
    },
    StaffGroups = {"admin", "moderator"},
    StaffPlusGroups = {"founder", "superadmin",},
    Rights = {
        user = {
            SpawnMenuOpen = false,
            CanTool = false,
            CanDrive = false,
            CanNoclip = false,
            Spawn = {
                prop = false,
                effect = false,
                ragdoll = false,
                swep = false,
                sent = false,
                npc = false,
                vehicle = false,
            },
            AllowedProperties = {}
        },
        staff = {
            SpawnMenuOpen = true,
            CanTool = true,
            CanDrive = true,
            CanNoclip = true,
            Spawn = {
                prop = true,
                effect = true,
                ragdoll = true,
                vehicle = true,
            },
            AllowedProperties = {
                remover = true,
                ignite = true,
                extinguish = true,
            }
        },
        staffplus = {
            Spawn = {
                swep = true,
                sent = true,
                npc = true,
            },
            AllowedProperties = {
                drive = true,
            }
        },
        developer = {},
    },
    GroupRights = {
        admin = {
            AllowedProperties = { drive = true }
        },
        moderator = {
            Inherits = "admin",
            CanTool = false,
            AllowedProperties = { ignite = false }
        },
        superadmin = {},
        founder = {
            Inherits = "superadmin",
            SpawnMenuOpen = true,
            CanTool = true,
            CanDrive = true,
        },
    },
}

VERSE.Access = VERSE.Access or {}
local A = VERSE.Access

local ORDER = { "user", "staff", "staffplus", "developer" }
local INDEX = { user = 1, staff = 2, staffplus = 3, developer = 4 }

local function toSet(list)
    local t = {}
    for _, v in ipairs(list or {}) do t[tostring(v)] = true end
    return t
end

local function mergeAllowedProps(dst, src)
    if not istable(src) then return dst end
    dst = istable(dst) and dst or {}
    for k, v in pairs(src) do
        if v == true or v == false then
            dst[k] = v
        end
    end
    return dst
end

local function deepMergeRights(dst, src)
    if not istable(src) then return dst end

    for k, v in pairs(src) do
        if k == "Inherits" then continue end

        if k == "AllowedProperties" then
            dst.AllowedProperties = mergeAllowedProps(dst.AllowedProperties, v)
        elseif istable(v) then
            dst[k] = istable(dst[k]) and dst[k] or {}
            deepMergeRights(dst[k], v)
        else
            dst[k] = v
        end
    end

    return dst
end

function A:Rebuild()
    local cfg = (VERSE.Config and VERSE.Config.Access) or {}

    self._devs = toSet(cfg.Developers)
    self._staff = toSet(cfg.StaffGroups)
    self._staffPlus = toSet(cfg.StaffPlusGroups)

    for group in pairs(self._staffPlus) do
        self._staff[group] = true
    end

    self._rightsCache = {}
end

VERSE.Hook.AddNS("Access", "Initialize", "VERSE::Initialize::Access", function()
    VERSE.Access:Rebuild()
end)

local function getRank(ply)
    if not IsValid(ply) then return "user" end
    if VERSE and VERSE.GetRank then return VERSE.GetRank(ply) or "user" end
    if ply.GetUserGroup then return ply:GetUserGroup() end
    return "user"
end

function A:IsDeveloper(ply)
    return IsValid(ply) and self._devs and self._devs[ply:SteamID()] == true or false
end

function A:IsStaff(ply)
    if not IsValid(ply) then return false end
    local g = getRank(ply)
    return self._staff and self._staff[g] == true or false
end

function A:IsStaffPlus(ply)
    if not IsValid(ply) then return false end
    local g = getRank(ply)
    return self._staffPlus and self._staffPlus[g] == true or false
end

function A:GetLevel(ply)
    local g = getRank(ply)
    if self:IsDeveloper(ply) and g ~= "user" then return "developer" end
    if self:IsStaffPlus(ply) then return "staffplus" end
    if self:IsStaff(ply) then return "staff" end
    return "user"
end

function A:GetRightsForLevel(level)
    local ac = (VERSE.Config and VERSE.Config.Access) or {}
    local rights = ac.Rights or {}

    level = tostring(level or "user")
    local max = INDEX[level] or 1

    local out = {}
    for i = 1, max do
        deepMergeRights(out, rights[ORDER[i]])
    end

    return out
end

function A:GetGroupRights(group)
    local ac = (VERSE.Config and VERSE.Config.Access) or {}
    local gr = ac.GroupRights or {}
    if not istable(gr[group]) then return nil end

    local visited = {}
    local function resolve(name, out)
        if not name or name == "" then return end
        if visited[name] then return end
        visited[name] = true

        local node = gr[name]
        if not istable(node) then return end

        local inh = node.Inherits
        if isstring(inh) then
            resolve(inh, out)
        elseif istable(inh) then
            for _, parent in ipairs(inh) do
                if isstring(parent) then resolve(parent, out) end
            end
        end

        deepMergeRights(out, node)
    end

    local out = {}
    resolve(group, out)
    out.Inherits = nil
    return out
end

function A:GetRights(ply)
    if not IsValid(ply) then
        return self:GetRightsForLevel("user")
    end

    self._rightsCache = self._rightsCache or {}

    local rank = getRank(ply)
    local sid = ply:SteamID() or "?"
    local key = sid .. "|" .. rank

    local cached = self._rightsCache[key]
    if cached then return cached end

    local out = self:GetRightsForLevel(self:GetLevel(ply))
    local gr = self:GetGroupRights(rank)
    if gr then deepMergeRights(out, gr) end

    self._rightsCache[key] = out
    return out
end

local meta = FindMetaTable("Player")

function meta:GetRank()
    return getRank(self)
end

function meta:IsDeveloper()
    return VERSE.Access:IsDeveloper(self)
end

function meta:IsStaff()
    return VERSE.Access:IsStaff(self)
end

function meta:IsStaffPlus()
    return VERSE.Access:IsStaffPlus(self)
end
