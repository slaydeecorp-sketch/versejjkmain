VERSE.Time = VERSE.Time or {}

local Time = VERSE.Time

function Time.Now()
    return CurTime()
end

function Time.Sys()
    return SysTime()
end

function Time.FormatSeconds(seconds, opts)
    opts = opts or {}

    seconds = tonumber(seconds) or 0
    if seconds < 0 then seconds = 0 end

    local total = math.floor(seconds + 0.5)

    local s = total % 60
    local m = math.floor(total / 60) % 60
    local h = math.floor(total / 3600)

    if h > 0 or opts.showHours then
        local hs = tostring(h)
        if opts.padHours and h < 10 then
            hs = "0" .. hs
        end
        return string.format("%s:%02d:%02d", hs, m, s)
    end

    return string.format("%d:%02d", m, s)
end

function Time.CooldownReady(last, cd)
    last = tonumber(last) or 0
    cd = tonumber(cd) or 0

    if cd <= 0 then return true end
    return (Time.Now() - last) >= cd
end

function Time.CooldownLeft(last, cd)
    last = tonumber(last) or 0
    cd = tonumber(cd) or 0

    if cd <= 0 then return 0 end

    local left = cd - (Time.Now() - last)
    if left < 0 then return 0 end
    return left
end