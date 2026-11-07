VERSE.Progress = VERSE.Progress or {}
local PB = VERSE.Progress
local Materials = VERSE.Materials
PB._items = PB._items or {}
local function clamp01(x)
    if x ~= x then return 0 end
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function clamp_round(w, h, r)
    return math.max(0, math.min(r or 0, math.floor(math.min(w, h) / 2)))
end

local function resolve_mat(m, flags)
    if not m then return nil end
    if type(m) == "IMaterial" then return m end
    if isstring(m) then return Materials:Get(m, flags) end
    return nil
end

local function MaskRoundedRect(x, y, w, h, r, drawInside)
    r = clamp_round(w, h, r)
    render.ClearStencil()
    render.SetStencilEnable(true)
    render.SetStencilWriteMask(0xFF)
    render.SetStencilTestMask(0xFF)
    render.SetStencilReferenceValue(1)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
    render.SetStencilFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
    render.OverrideColorWriteEnable(true, false, false)
    RNDX.Draw(r, x, y, w, h, color_white)
    render.OverrideColorWriteEnable(false)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    drawInside()
    render.SetStencilEnable(false)
end

local function rect_resolve(base, rect)
    if not istable(rect) then return base.x, base.y, base.w, base.h end
    local x = rect.x ~= nil and rect.x or base.x
    local y = rect.y ~= nil and rect.y or base.y
    local w = rect.w ~= nil and rect.w or base.w
    local h = rect.h ~= nil and rect.h or base.h
    return x, y, w, h
end

local DEFAULT = {
    x = 0,
    y = 0,
    w = 200,
    h = 18,
    round = 8,
    value = 1,
    _value = 1,
    smooth = 14,
    smoothEnabled = true,
    mode = "linear",
    dir = "lr",
    cw = true,
    startAngle = -90,
    radius = nil,
    thickness = -1,
    bgRect = nil,
    fillRect = nil,
    bg = {
        mode = "none",
        color = Color(0, 0, 0, 0),
        material = nil,
        flags = nil,
        round = nil,
        uv = true,
    },
    fill = {
        mode = "color",
        color = Color(255, 255, 255, 255),
        material = nil,
        flags = nil,
        round = nil,
        uv = true,
    },
}

local function ensure_item(id)
    local it = PB._items[id]
    if it then return it end
    it = table.Copy(DEFAULT)
    it.id = id
    PB._items[id] = it
    return it
end

local function apply_block(dst, src)
    if not istable(src) then return end
    for k, v in pairs(src) do
        dst[k] = v
    end
end

function PB.Create(id, opts)
    local it = ensure_item(id)
    if opts then PB.Update(id, opts) end
    return it
end

function PB.Ensure(id, opts)
    return PB.Create(id, opts)
end

function PB.Update(id, opts)
    local it = ensure_item(id)
    opts = opts or {}
    for k, v in pairs(opts) do
        if k ~= "bg" and k ~= "fill" then it[k] = v end
    end

    apply_block(it.bg, opts.bg)
    apply_block(it.fill, opts.fill)
    it.value = clamp01(it.value or 0)
    it._value = clamp01(it._value or it.value)
    it.round = clamp_round(it.w or 0, it.h or 0, it.round)
    it.mode = (it.mode == "circle") and "circle" or "linear"
    local d = it.dir
    if d ~= "lr" and d ~= "rl" and d ~= "tb" and d ~= "bt" then it.dir = "lr" end
    return it
end

function PB.SetRect(id, x, y, w, h)
    return PB.Update(id, {
        x = x,
        y = y,
        w = w,
        h = h
    })
end

function PB.SetRound(id, r)
    return PB.Update(id, {
        round = r
    })
end

function PB.SetValue(id, v)
    local it = ensure_item(id)
    it.value = clamp01(v or 0)
    return it
end

function PB.SetValueInstant(id, v)
    local it = ensure_item(id)
    v = clamp01(v or 0)
    it.value = v
    it._value = v
    return it
end

function PB.SetSmooth(id, enabled, speed)
    local it = ensure_item(id)
    it.smoothEnabled = not not enabled
    if speed ~= nil then it.smooth = tonumber(speed) or it.smooth end
    return it
end

function PB.SetLinear(id, dir)
    return PB.Update(id, {
        mode = "linear",
        dir = dir
    })
end

function PB.SetCircle(id, cw, startAngle)
    return PB.Update(id, {
        mode = "circle",
        cw = not not cw,
        startAngle = startAngle
    })
end

function PB.SetBgRect(id, x, y, w, h)
    return PB.Update(id, {
        bgRect = {
            x = x,
            y = y,
            w = w,
            h = h
        }
    })
end

function PB.SetFillRect(id, x, y, w, h)
    return PB.Update(id, {
        fillRect = {
            x = x,
            y = y,
            w = w,
            h = h
        }
    })
end

function PB.SetBackground(id, mode, opt)
    local it = ensure_item(id)
    opt = opt or {}
    it.bg.mode = mode or "none"
    if opt.color ~= nil then it.bg.color = opt.color end
    if opt.material ~= nil then it.bg.material = opt.material end
    if opt.flags ~= nil then it.bg.flags = opt.flags end
    if opt.round ~= nil then it.bg.round = opt.round end
    if opt.uv ~= nil then it.bg.uv = not not opt.uv end
    return it
end

function PB.SetFill(id, mode, opt)
    local it = ensure_item(id)
    opt = opt or {}
    it.fill.mode = mode or "color"
    if opt.color ~= nil then it.fill.color = opt.color end
    if opt.material ~= nil then it.fill.material = opt.material end
    if opt.flags ~= nil then it.fill.flags = opt.flags end
    if opt.round ~= nil then it.fill.round = opt.round end
    if opt.uv ~= nil then it.fill.uv = not not opt.uv end
    return it
end

function PB.SetBgMaterial(id, matOrPath, flags)
    return PB.SetBackground(id, "material", {
        material = matOrPath,
        flags = flags
    })
end

function PB.SetFillMaterial(id, matOrPath, flags)
    return PB.SetFill(id, "material", {
        material = matOrPath,
        flags = flags
    })
end

function PB.SetBgColor(id, col)
    return PB.SetBackground(id, "color", {
        color = col
    })
end

function PB.SetFillColor(id, col)
    return PB.SetFill(id, "color", {
        color = col
    })
end

local function draw_block(x, y, w, h, block, round, uv)
    if not block or block.mode == "none" then return end
    if w <= 0 or h <= 0 then return end
    round = clamp_round(w, h, round)
    if block.mode == "color" then
        local col = block.color
        if not col or col.a == 0 then return end
        RNDX.Draw(round, x, y, w, h, col)
        return
    end

    if block.mode == "material" then
        local mat = resolve_mat(block.material, block.flags)
        if not mat or mat:IsError() then return end
        local col = block.color or color_white
        if uv and block.uv then
            Materials:DrawUV(col, mat, x, y, w, h, uv.u0 or 0, uv.v0 or 0, uv.u1 or 1, uv.v1 or 1)
        else
            Materials:Draw(col, mat, x, y, w, h)
        end
        return
    end
end

local function draw_linear(it, p)
    local mx, my, mw, mh = it.x, it.y, it.w, it.h
    local mr = clamp_round(mw, mh, it.round)
    local bx, by, bw, bh = rect_resolve(it, it.bgRect)
    local fx, fy, fw, fh = rect_resolve(it, it.fillRect)
    local bgRound = (it.bg and it.bg.round ~= nil) and it.bg.round or mr
    local fillRound = (it.fill and it.fill.round ~= nil) and it.fill.round or mr
    MaskRoundedRect(mx, my, mw, mh, mr, function()
        draw_block(bx, by, bw, bh, it.bg, bgRound, nil)
        if p <= 0 then return end
        local ffx, ffy, ffw, ffh = fx, fy, fw, fh
        local uv = {
            u0 = 0,
            v0 = 0,
            u1 = 1,
            v1 = 1
        }

        if it.dir == "lr" then
            ffw = math.floor(fw * p + 0.5)
            uv.u1 = p
        elseif it.dir == "rl" then
            ffw = math.floor(fw * p + 0.5)
            ffx = fx + (fw - ffw)
            uv.u0 = 1 - p
        elseif it.dir == "tb" then
            ffh = math.floor(fh * p + 0.5)
            uv.v1 = p
        elseif it.dir == "bt" then
            ffh = math.floor(fh * p + 0.5)
            ffy = fy + (fh - ffh)
            uv.v0 = 1 - p
        end

        draw_block(ffx, ffy, ffw, ffh, it.fill, fillRound, uv)
    end)
end

local function draw_circle(it, p)
    local x, y, w, h = it.x, it.y, it.w, it.h
    local d = math.min(w, h)
    local cx, cy = x + w * 0.5, y + h * 0.5
    local rad = it.radius or (d * 0.5)
    if it.bg and it.bg.mode ~= "none" then
        local c = RNDX().Circle(cx, cy, rad * 2)
        if it.bg.mode == "color" and it.bg.color then
            c:Color(it.bg.color)
        elseif it.bg.mode == "material" and it.bg.material then
            local m = resolve_mat(it.bg.material, it.bg.flags)
            if m and not m:IsError() then c:Material(m) end
        end

        if (it.thickness or -1) >= 0 then c:Outline(it.thickness) end
        c:StartAngle(0):EndAngle(360):Draw()
    end

    if p <= 0 then return end
    local start = it.startAngle or -90
    local span = 360 * p
    local a1, a2
    if it.cw then
        a1 = start
        a2 = start - span
    else
        a1 = start
        a2 = start + span
    end

    local c = RNDX().Circle(cx, cy, rad * 2)
    if it.fill.mode == "color" and it.fill.color then
        c:Color(it.fill.color)
    elseif it.fill.mode == "material" and it.fill.material then
        local m = resolve_mat(it.fill.material, it.fill.flags)
        if m and not m:IsError() then c:Material(m) end
    end

    if (it.thickness or -1) >= 0 then c:Outline(it.thickness) end
    c:StartAngle(a1):EndAngle(a2):Draw()
end

local function draw_item(it)
    local target = clamp01(it.value or 0)
    if it.smoothEnabled then
        local spd = math.max(0, tonumber(it.smooth) or 0)
        local t = 1 - math.exp(-spd * FrameTime())
        it._value = it._value + (target - it._value) * t
    else
        it._value = target
    end

    local p = clamp01(it._value or 0)
    if it.mode == "circle" then
        draw_circle(it, p)
    else
        draw_linear(it, p)
    end
end

function PB.Draw(id)
    local it = PB._items[id]
    if not it then return end
    draw_item(it)
end

function PB.DrawAll()
    for _, it in pairs(PB._items) do
        draw_item(it)
    end
end

VERSE.Hook.AddNS("Progress", "ShutDown", "VERSE::ShutDown::Progress", function() PB._items = {} end)