VERSE.Responsive = VERSE.Responsive or {}
local R = VERSE.Responsive

R.REF_W = 1920
R.REF_H = 1080
R.MODE = "min"
R.CLAMP_MIN = 0.75
R.CLAMP_MAX = 1.50
R._sw = R._sw or ScrW()
R._sh = R._sh or ScrH()
R._cacheX = R._cacheX or {}
R._cacheY = R._cacheY or {}
R._cacheS = R._cacheS or {}

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function round(v)
    return (v >= 0) and math.floor(v + 0.5) or math.ceil(v - 0.5)
end

function R:Invalidate()
    self._sw, self._sh = ScrW(), ScrH()
    self._cacheX = {}
    self._cacheY = {}
    self._cacheS = {}
end

function R:GetScaleX()
    return self._sw / self.REF_W
end

function R:GetScaleY()
    return self._sh / self.REF_H
end

function R:GetScale()
    local sx = self:GetScaleX()
    local sy = self:GetScaleY()
    local s
    if self.MODE == "w" then
        s = sx
    elseif self.MODE == "h" then
        s = sy
    else
        s = math.min(sx, sy)
    end
    return clamp(s, self.CLAMP_MIN, self.CLAMP_MAX)
end

function R:X(px)
    px = tonumber(px) or 0
    local v = self._cacheX[px]
    if v ~= nil then return v end
    v = px * self:GetScaleX()
    self._cacheX[px] = v
    return v
end

function R:Y(px)
    px = tonumber(px) or 0
    local v = self._cacheY[px]
    if v ~= nil then return v end
    v = px * self:GetScaleY()
    self._cacheY[px] = v
    return v
end

function R:S(px)
    px = tonumber(px) or 0
    local v = self._cacheS[px]
    if v ~= nil then return v end
    v = px * self:GetScale()
    self._cacheS[px] = v
    return v
end

function R:XY(x, y)
    return self:X(x), self:Y(y)
end

function R:RXY(x, y)
    return self:RX(x), self:RY(y)
end

function R:SS(x, y)
    return self:S(x), self:S(y)
end

function R:RSS(x, y)
    return self:RS(x), self:RS(y)
end

function R:RX(px)
    return round(self:X(px))
end

function R:RY(px)
    return round(self:Y(px))
end

function R:RS(px)
    return round(self:S(px))
end

function R:CenterX(w)
    return (self._sw - w) * 0.5
end

function R:CenterY(h)
    return (self._sh - h) * 0.5
end

hook.Add("OnScreenSizeChanged", "VERSE::OnScreenSizeChanged::Responsive", function()
    if not VERSE or not VERSE.Responsive then return end
    VERSE.Responsive:Invalidate()
end)

R:Invalidate()