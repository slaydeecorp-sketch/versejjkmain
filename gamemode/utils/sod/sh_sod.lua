VERSE.Sod = VERSE.Sod or {}
local Sod = VERSE.Sod

function Sod:new(f, z, r, x0)
    if not isnumber(f) or not isnumber(z) or not isnumber(r) then error("Invalid arguments.") end
    if isangle(x0) then
        x0 = x0:Forward()
    elseif not isvector(x0) then
        return
    end

    local obj = setmetatable({
        xp = nil,
        y = nil,
        yd = nil,
        w = nil,
        z = nil,
        d = nil,
        k1 = nil,
        k2 = nil,
        k3 = nil
    }, {
        __index = self
    })

    obj.w = 2 * math.pi * f
    obj.z = z
    obj.d = obj.w * math.sqrt(math.abs(z * z - 1))
    obj.k1 = z / (math.pi * f)
    obj.k2 = 1 / ((2 * math.pi * f) * (2 * math.pi * f))
    obj.k3 = r * z / (2 * math.pi * f)
    obj.xp = Vector(x0)
    obj.y = Vector(x0)
    obj.yd = Vector(0, 0, 0)
    return obj
end

function Sod:SetVector(x0)
    if isangle(x0) then
        x0 = x0:Forward()
    elseif not isvector(x0) then
        return
    end

    self.xp = Vector(x0)
    self.y = Vector(x0)
    self.yd = Vector(0, 0, 0)
end

function Sod:Update(T, x, xd)
    if not isnumber(T) or T <= 0 then return self.y end
    if isangle(x) then
        x = x:Forward()
    elseif not isvector(x) then
        return
    end

    if x == self.y then return self.y end
    if xd == nil then
        xd = (x - self.xp) / T
        self.xp = x
    end

    local k2Stable = math.max(self.k2, T * T / 2 + T * self.k1 / 2, T * self.k1)
    self.y = self.y + T * self.yd
    self.yd = self.yd + T * (x + self.k3 * xd - self.y - self.k1 * self.yd) / k2Stable
    return self.y
end

function Sod:UpdateExpensive(T, x, xd)
    if not isnumber(T) or T <= 0 then return self.y end
    if isangle(x) then
        x = x:Forward()
    elseif not isvector(x) then
        return
    end

    if x == self.y then return self.y end
    if xd == nil then
        xd = (x - self.xp) / T
        self.xp = x
    end

    local k1Stable, k2Stable
    if self.w * T < self.z then
        k1Stable = self.k1
        k2Stable = math.max(self.k2, T * T / 2 + T * self.k1 / 2, T * self.k1)
    else
        local t1 = math.exp(-self.z * self.w * T)
        local alpha = 2 * t1 * (self.z <= 1 and math.cos(T * self.d) or math.cosh(T * self.d))
        local beta = t1 * t1
        local t2 = T / (1 + beta - alpha)
        k1Stable = (1 - beta) * t2
        k2Stable = T * t2
    end

    self.y = self.y + T * self.yd
    self.yd = self.yd + T * (x + self.k3 * xd - self.y - k1Stable * self.yd) / k2Stable
    return self.y
end