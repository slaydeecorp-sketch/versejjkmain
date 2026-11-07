VERSE.Math = VERSE.Math or {}

local M = VERSE.Math

function M.Clamp(x, a, b)
    x = tonumber(x) or 0
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    if a > b then a, b = b, a end
    if x < a then return a end
    if x > b then return b end
    return x
end

function M.Clamp01(x)
    x = tonumber(x) or 0
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

function M.Lerp(a, b, t)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    t = tonumber(t) or 0
    return a + (b - a) * t
end

function M.InverseLerp(a, b, v)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    v = tonumber(v) or 0
    local d = (b - a)
    if d == 0 then return 0 end
    return (v - a) / d
end

function M.Remap(inA, inB, outA, outB, v, clamp01)
    local t = M.InverseLerp(inA, inB, v)
    if clamp01 then t = M.Clamp01(t) end
    return M.Lerp(outA, outB, t)
end

function M.RoundTo(x, step)
    x = tonumber(x) or 0
    step = tonumber(step) or 1
    if step == 0 then return x end
    return math.floor((x / step) + 0.5) * step
end

function M.ApproachExp(value, target, halflife, dt)
    value = tonumber(value) or 0
    target = tonumber(target) or 0
    halflife = tonumber(halflife) or 0
    dt = tonumber(dt) or 0

    if dt <= 0 or value == target then return value end
    if halflife <= 0 then return target end

    local k = 0.6931471805599453 / halflife
    local a = 1 - math.exp(-k * dt)
    return value + (target - value) * a
end

function M.SmoothDamp(current, target, currentVelocity, smoothTime, maxSpeed, dt)
    current = tonumber(current) or 0
    target = tonumber(target) or 0
    currentVelocity = tonumber(currentVelocity) or 0
    smoothTime = tonumber(smoothTime) or 0.15
    dt = tonumber(dt) or 0

    if smoothTime <= 0 then
        return target, 0
    end

    local omega = 2 / smoothTime
    local x = omega * dt
    local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = current - target
    local originalTarget = target

    if maxSpeed and tonumber(maxSpeed) and maxSpeed > 0 then
        local maxChange = maxSpeed * smoothTime
        change = M.Clamp(change, -maxChange, maxChange)
        target = current - change
    end

    local temp = (currentVelocity + omega * change) * dt
    local newVelocity = (currentVelocity - omega * temp) * exp
    local newValue = target + (change + temp) * exp

    if (originalTarget - current > 0) == (newValue > originalTarget) then
        newValue = originalTarget
        newVelocity = 0
    end

    return newValue, newVelocity
end