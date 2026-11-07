VERSE.Materials = VERSE.Materials or {}
local Materials = VERSE.Materials
Materials.Cache = Materials.Cache or {}
Materials.Stats = Materials.Stats or {
    hits = 0,
    misses = 0,
    errors = 0
}

Materials.FallbackPath = Materials.FallbackPath or "error"
Materials.FallbackFlags = Materials.FallbackFlags or "smooth"
Materials.DefaultFlags = Materials.DefaultFlags or "noclamp smooth"
Materials.Alias = Materials.Alias or {}
local function Trim(s)
    return (s and s:gsub("^%s+", ""):gsub("%s+$", "")) or ""
end

local function NormalizePath(path)
    path = Trim(path)
    if path == "" then return "" end
    if Materials.Alias[path] then path = Materials.Alias[path] end
    path = path:gsub("^materials/", "")
    path = path:gsub("^material/", "")
    path = path:gsub("%.png$", "")
    path = path:gsub("%.vmt$", "")
    path = path:gsub("%.vtf$", "")
    path = path:gsub("\\", "/")
    return path
end

local function MakeKey(path, flags)
    return path .. "|" .. (flags or "")
end

local function CreateMaterial(path, flags)
    local mat = Material(path .. ".png", flags)
    if mat and not mat:IsError() then return mat, false end
    mat = Material(path, flags)
    if mat and not mat:IsError() then return mat, false end
    return Material(Materials.FallbackPath, Materials.FallbackFlags), true
end

function Materials:Get(path, flags)
    flags = flags or self.DefaultFlags
    path = NormalizePath(path)
    if path == "" then
        self.Stats.errors = self.Stats.errors + 1
        return Material(self.FallbackPath, self.FallbackFlags)
    end

    local key = MakeKey(path, flags)
    local cached = self.Cache[key]
    if cached then
        self.Stats.hits = self.Stats.hits + 1
        return cached
    end

    self.Stats.misses = self.Stats.misses + 1
    local mat, isErr = CreateMaterial(path, flags)
    if isErr then self.Stats.errors = self.Stats.errors + 1 end
    self.Cache[key] = mat
    return mat
end

function Materials:SetAlias(name, path)
    name = Trim(name)
    path = Trim(path)
    if name == "" or path == "" then return end
    self.Alias[name] = path
end

function Materials:RemoveAlias(name)
    name = Trim(name)
    if name == "" then return end
    self.Alias[name] = nil
end

function Materials:SetDefaultFlags(flags)
    flags = Trim(flags)
    if flags == "" then return end
    self.DefaultFlags = flags
end

function Materials:ClearCache()
    self.Cache = {}
    self.Stats = {
        hits = 0,
        misses = 0,
        errors = 0
    }
end

function Materials:GetStats()
    return self.Stats.hits, self.Stats.misses, self.Stats.errors
end

function Materials:Precache(list)
    if not istable(list) then return end
    for _, v in ipairs(list) do
        if isstring(v) then
            self:Get(v)
        elseif istable(v) then
            self:Get(v[1], v[2])
        end
    end
end

function Materials:Draw(col, matOrPath, x, y, w, h, flags)
    if col ~= nil then surface.SetDrawColor(col) end
    local mat = matOrPath
    if isstring(matOrPath) then mat = self:Get(matOrPath, flags) end
    if not mat then mat = Material(self.FallbackPath, self.FallbackFlags) end
    surface.SetMaterial(mat)
    surface.DrawTexturedRect(x, y, w, h)
end

function Materials:DrawUV(col, matOrPath, x, y, w, h, u0, v0, u1, v1, flags)
    if col ~= nil then surface.SetDrawColor(col) end
    local mat = matOrPath
    if isstring(matOrPath) then mat = self:Get(matOrPath, flags) end
    if not mat then mat = Material(self.FallbackPath, self.FallbackFlags) end
    surface.SetMaterial(mat)
    surface.DrawTexturedRectUV(x, y, w, h, u0 or 0, v0 or 0, u1 or 1, v1 or 1)
end

function Materials:Binder(matOrPath, flags)
    local mat = matOrPath
    if isstring(matOrPath) then mat = self:Get(matOrPath, flags) end
    return function(col, x, y, w, h)
        if col ~= nil then surface.SetDrawColor(col) end
        surface.SetMaterial(mat)
        surface.DrawTexturedRect(x, y, w, h)
    end
end

function Materials:DrawDuplicate(col, matOrPath, x, y, w, h, flags)
    self:Draw(col, matOrPath, x, y, w, h, flags)
    self:Draw(col, matOrPath, x, y, w, h, flags)
end

function Materials:DrawRotated(col, matOrPath, cx, cy, w, h, rot, flags)
    if col ~= nil then surface.SetDrawColor(col) end
    local mat = matOrPath
    if isstring(matOrPath) then mat = self:Get(matOrPath, flags) end
    if not mat then mat = Material(self.FallbackPath, self.FallbackFlags) end
    surface.SetMaterial(mat)
    surface.DrawTexturedRectRotated(cx, cy, w, h, rot or 0)
end