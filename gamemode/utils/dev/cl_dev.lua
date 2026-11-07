local Dev = VERSE.Dev
local L = VERSE.L
local Font = VERSE.Fonts
local R = VERSE.Responsive

net.Receive(Dev.Net.Feedback, function()
    local msg = net.ReadString()
    local isError = net.ReadBool()
    if isError then
        VERSE.Log:Warn("[Dev]", msg)
    else
        VERSE.Log:Info("[Dev]", msg)
    end

    if VERSE.Notify then
        local ntype = isError and NOTIFY_ERROR or NOTIFY_HINT
        VERSE.Notify:Push(msg, ntype, 10)
    else
        chat.AddText(isError and Color(255, 80, 80) or Color(100, 255, 100), "[Dev] ", color_white, msg)
    end
end)

local svData = {}
local lastSyncTime = 0
net.Receive(Dev.Net.Sync, function()
    local count = net.ReadUInt(8)
    for _ = 1, count do
        local k = net.ReadString()
        local v = net.ReadString()
        svData[k] = v
    end

    lastSyncTime = RealTime()
end)

local hudEnabled = true
local HUD_MARGIN = 10
local HUD_PAD = 8
local HUD_LINE_H = 18
local colBg = Color(20, 20, 20, 200)
local colBorder = Color(80, 80, 80, 120)
local colTitle = Color(100, 200, 255)
local colLabel = Color(180, 180, 180)
local colValue = Color(255, 255, 255)
local colGood = Color(100, 255, 100)
local colWarn = Color(255, 200, 50)
local colBad = Color(255, 80, 80)
local colStale = Color(255, 80, 80, 150)
local function getNum(key, fallback)
    return tonumber(svData[key]) or fallback
end

local function getStr(key, fallback)
    return svData[key] or fallback
end

local function fpsColor(fps)
    if fps >= 60 then return colGood end
    if fps >= 30 then return colWarn end
    return colBad
end

local function tickColor(fps, expected)
    local ratio = fps / math.max(expected, 1)
    if ratio >= 0.95 then return colGood end
    if ratio >= 0.7 then return colWarn end
    return colBad
end

local function formatUptime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return ("%02d:%02d:%02d"):format(h, m, s)
end

local function isDev()
    local lp = LocalPlayer()
    return IsValid(lp) and lp.IsDeveloper and lp:IsDeveloper()
end

VERSE.Hook.AddNS("Dev", "HUDPaint", "VERSE::HUDPaint::Dev", function()
    if not hudEnabled then return end
    if not isDev() then return end
    local fontTitle = Font:GetNamed("Poppins", "Bold", 15)
    local fontText = Font:GetNamed("Poppins", "Medium", 12)
    local stale = (RealTime() - lastSyncTime) > 5
    local noData = table.Count(svData) == 0
    local expectedTick = getNum("tickrate", 66)
    local svFps = getNum("server_fps", 0)
    local plyCount = getNum("player_count", 0)
    local maxPly = getNum("max_players", 0)
    local mapName = getStr("map", "?")
    local uptime = getNum("uptime", 0)
    local entCount = getNum("ent_count", 0)
    local netIn = getNum("net_in", 0)
    local netOut = getNum("net_out", 0)
    local hostname = getStr("sv_hostname", "?")
    local locked = getNum("password_locked", 0) == 1
    local clFps = math.Round(1 / RealFrameTime())
    local ping = IsValid(LocalPlayer()) and LocalPlayer():Ping() or 0
    local lines = {
        {
            label = L("dev.hud_hostname"),
            value = hostname,
            color = colValue
        },
        {
            label = L("dev.hud_map"),
            value = mapName,
            color = colValue
        },
        {
            label = L("dev.hud_players"),
            value = plyCount .. "/" .. maxPly,
            color = colValue
        },
        {
            label = L("dev.hud_uptime"),
            value = formatUptime(uptime),
            color = colValue
        },
        {
            label = ""
        },
        {
            label = L("dev.hud_sv_fps"),
            value = tostring(svFps),
            color = fpsColor(svFps)
        },
        {
            label = L("dev.hud_tickrate"),
            value = tostring(expectedTick),
            color = tickColor(svFps, expectedTick)
        },
        {
            label = L("dev.hud_cl_fps"),
            value = tostring(clFps),
            color = fpsColor(clFps)
        },
        {
            label = L("dev.hud_ping"),
            value = ping .. " ms",
            color = ping < 80 and colGood or (ping < 150 and colWarn or colBad)
        },
        {
            label = ""
        },
        {
            label = L("dev.hud_entities"),
            value = tostring(entCount),
            color = entCount > 2000 and colWarn or colValue
        },
        {
            label = L("dev.hud_net_in"),
            value = netIn .. " KB/s",
            color = colValue
        },
        {
            label = L("dev.hud_net_out"),
            value = netOut .. " KB/s",
            color = colValue
        },
        { label = "" },
        {
            label = L("dev.hud_ns_hooks"),
            value = tostring(getNum("ns_hooks", 0)),
            color = colValue
        },
        {
            label = L("dev.hud_ns_sent"),
            value = tostring(getNum("ns_sent", 0)),
            color = colValue
        },
        {
            label = L("dev.hud_ns_recv"),
            value = tostring(getNum("ns_recv", 0)),
            color = colValue
        },
        {
            label = L("dev.hud_ns_errors"),
            value = tostring(getNum("ns_errors", 0)),
            color = getNum("ns_errors", 0) > 0 and colBad or colValue
        },
        {
            label = L("dev.hud_password"),
            value = locked and L("dev.state_on") or L("dev.state_off"),
            color = locked and colWarn or colGood
        },
    }

    local maxLabelW = 0
    local maxValueW = 0
    for _, line in ipairs(lines) do
        if line.value then
            local lw = VERSE.GetTextSize(line.label, fontText)
            local vw = VERSE.GetTextSize(line.value, fontText)
            if lw > maxLabelW then maxLabelW = lw end
            if vw > maxValueW then maxValueW = vw end
        end
    end

    local titleText = "VERSE Dev"
    local titleW = VERSE.GetTextSize(titleText, fontTitle)
    local contentW = math.max(maxLabelW + maxValueW + 20, titleW + 10)
    local w = contentW + HUD_PAD * 2
    local h = HUD_PAD * 2 + HUD_LINE_H + 4
    for _, line in ipairs(lines) do
        if line.value then
            h = h + HUD_LINE_H
        else
            h = h + 6
        end
    end

    if stale or noData then h = h + HUD_LINE_H end
    local x = ScrW() - w - HUD_MARGIN
    local y = HUD_MARGIN
    RNDX().Rect(x, y, w, h)
        :Rad(R:Y(6))
        :Color(colBg)
        :Blur(0.85)
        :Shadow(25, 30)
        :Draw()

    RNDX.DrawOutlined(R:Y(6), x, y, w, h, colBorder, 1)

    local cx = x + HUD_PAD
    local cy = y + HUD_PAD
    draw.SimpleText(titleText, fontTitle, cx, cy, colTitle, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    cy = cy + HUD_LINE_H + 4

    for _, line in ipairs(lines) do
        if line.value then
            draw.SimpleText(line.label, fontText, cx, cy, colLabel, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(line.value, fontText, x + w - HUD_PAD, cy, line.color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            cy = cy + HUD_LINE_H
        else
            cy = cy + 6
        end
    end

    if noData then
        draw.SimpleText(L("dev.hud_no_data"), fontText, cx, cy, colStale, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    elseif stale then
        draw.SimpleText(L("dev.hud_stale"), fontText, cx, cy, colStale, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end)

VERSE.Commands.Add("verse_dev_hud", function(ply, args, argStr)
    hudEnabled = not hudEnabled
    local state = hudEnabled and L("dev.state_on") or L("dev.state_off")
    if VERSE.Notify then VERSE.Notify:Push("Dev HUD: " .. state, NOTIFY_HINT, 3) end
end, nil, "client")