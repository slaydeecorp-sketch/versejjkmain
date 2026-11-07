-- cl_scoreboard.lua — Scoreboard VERSE
-- Affiche : avatar steam (rond), nom RP, grade (job), niveau, ping.
-- Joueurs inconnus (jamais présentés) → "???" sauf le ping.

local W = function(v) return ScrW() * v / 1920 end
local H = function(v) return ScrH() * v / 1080 end

-- ─── Matériaux ────────────────────────────────────────────────────────────────
local matBg      = Material("verse/scoreboard/Rectangle107.png")
local matRow     = Material("verse/scoreboard/Rectangle108.png")
local matLogo    = Material("verse/scoreboard/verselogo.png")
local matArrow   = Material("verse/scoreboard/vector.png")
-- scrollbar dessinée en code (pas de dépendance matériau)

-- ─── Polices ──────────────────────────────────────────────────────────────────
surface.CreateFont("SB_Row", {
    font      = "Poppins SemiBold",
    size      = 26,
    weight    = 600,
    antialias = true,
})
surface.CreateFont("SB_Header", {
    font      = "Poppins SemiBold",
    size      = 26,
    weight    = 600,
    antialias = true,
})
surface.CreateFont("SB_Count_Bold", {
    font      = "Poppins SemiBold",
    size      = 34,
    weight    = 700,
    antialias = true,
})
surface.CreateFont("SB_Count_Regular", {
    font      = "Poppins",
    size      = 34,
    weight    = 400,
    antialias = true,
})

-- ─── Couleurs faction ─────────────────────────────────────────────────────────
local FACTION_COLOR = {
    exorcist = Color(80,  140, 255),
    spirit   = Color(220, 50,  50),
}

local CLR_WHITE     = Color(255, 255, 255)
local CLR_GRAY      = Color(155, 155, 165)
local CLR_UNKNOWN   = Color(110, 110, 120)
local CLR_PING_DEAD = Color(60,  60,  70)

-- ─── Layout ───────────────────────────────────────────────────────────────────
local PANEL_W = W(1178)
local PANEL_H = H(667)
local PANEL_X = W(371)
local PANEL_Y = H(206)

local ROW_H   = H(70)
local ROW_GAP = H(8)
local AV_SIZE = H(42)   -- avatar plus petit

-- Centres des colonnes (relatifs à l'intérieur d'une ligne / du panel)
-- Ligne totale : W(1117)
local COL_AV_X  = W(55)   -- centre avatar
local COL_NAME  = W(240)  -- centre colonne Nom
local COL_GRADE = W(490)  -- centre colonne Grade
local COL_LEVEL = W(690)  -- centre colonne Niveau
local COL_PING  = W(940)  -- centre colonne Ping

local HDR_Y = H(103)
local ARROW_SIZE_W = W(10)
local ARROW_SIZE_H = H(7)

-- ─── Tri ──────────────────────────────────────────────────────────────────────
local sortMode = "name"
local sortAsc  = true

-- ─── API acquaintances ────────────────────────────────────────────────────────
local function getAPI()
    local CH = VERSE and VERSE.Characters
    return CH and CH.Introduce
end

local function isStranger(ply)
    if not IsValid(ply) or ply == LocalPlayer() then return false end
    local api = getAPI()
    if not api or not api.IsStranger then return false end
    local charId = api.GetCharId and api.GetCharId(ply) or 0
    if charId <= 0 then return false end
    return api.IsStranger(ply)
end

local function getDisplayName(ply)
    if ply == LocalPlayer() then
        local CH  = VERSE and VERSE.Characters
        local sel = CH and CH.Client and CH.Client.selected
        if istable(sel) then
            local first = sel.firstname or sel.first_name or ""
            local last  = sel.lastname  or sel.last_name  or ""
            if first ~= "" then
                return last ~= "" and (first .. " " .. last) or first
            end
        end
        return ply:Nick()
    end
    local api = getAPI()
    if not api or not api.GetDisplayName then return ply:Nick() end
    local name = api.GetDisplayName(ply, "???")
    if not name or name == "" or name == "????" then return "???" end
    return name
end

local function cleanJobName(name)
    -- Supprime les suffixes entre crochets : "Classe S [Gojo]" → "Classe S"
    -- et entre parenthèses : "Classe S (Gojo)" → "Classe S"
    return (name:gsub("%s*%[.-%]%s*$", ""):gsub("%s*%(.-%)%s*$", ""))
end

local function safeGetJobName(ply)
    if not IsValid(ply) then return "???" end
    -- Priorité : NWString publique "VERSE::JobID" (synchronisée à tous les clients)
    local jobId = ply:GetPublicString("VERSE::JobID", "")
    if jobId and jobId ~= "" then
        local job = VERSE and VERSE.Jobs and VERSE.Jobs:Get(jobId)
        if job and isstring(job.name) then return cleanJobName(job.name) end
    end
    -- Fallback : GetJob() (fonctionne pour le LocalPlayer via sa table Job locale)
    local ok, job = pcall(function() return ply:GetJob() end)
    if ok and istable(job) and isstring(job.name) then return cleanJobName(job.name) end
    return "???"
end

local function getSortValue(ply, mode)
    local stranger = isStranger(ply)
    if mode == "name"   then return stranger and "\xff\xff" or string.lower(getDisplayName(ply)) end
    if mode == "grade"  then return stranger and "\xff\xff" or string.lower(safeGetJobName(ply)) end
    if mode == "niveau" then return stranger and 999999     or (ply:GetLevel() or 0) end
    if mode == "ping"   then return ply:Ping() end
    return 0
end

local function sortedPlayers()
    local list = player.GetAll()
    local lp   = IsValid(LocalPlayer()) and LocalPlayer()
    table.sort(list, function(a, b)
        if lp then
            if a == lp then return true end
            if b == lp then return false end
        end
        local va, vb = getSortValue(a, sortMode), getSortValue(b, sortMode)
        if type(va) ~= type(vb) then return tostring(va) < tostring(vb) end
        return sortAsc and (va < vb) or (va > vb)
    end)
    return list
end

-- ─── Barres de ping dessinées en code ─────────────────────────────────────────
local function drawPingBars(cx, cy, ping)
    local bars   = 4
    local barW   = W(4)
    local barGap = W(2)
    local maxH   = H(14)
    local totalW = bars * barW + (bars - 1) * barGap
    local startX = cx - totalW / 2
    local active = ping < 60 and 4 or ping < 120 and 3 or ping < 200 and 2 or 1
    for i = 1, bars do
        local bh = maxH * (i / bars)
        local bx = startX + (i - 1) * (barW + barGap)
        local by = cy - maxH / 2 + (maxH - bh)
        surface.SetDrawColor(i <= active and CLR_WHITE or CLR_PING_DEAD)
        surface.DrawRect(bx, by, barW, bh)
    end
end

-- ─── Avatar rond ──────────────────────────────────────────────────────────────
local function makeRoundAvatar(parent, ply, size, cx, cy)
    local x = cx - size / 2
    local y = cy - size / 2
    local av = vgui.Create("AvatarImage", parent)
    av:SetSize(size, size)
    av:SetPos(x, y)
    av:SetPlayer(ply, 64)
    av:SetPaintedManually(true)

    local mask = vgui.Create("DPanel", parent)
    mask:SetSize(size, size)
    mask:SetPos(x, y)
    mask.Paint = function(self, w, h)
        render.SetStencilEnable(true)
        render.ClearStencil()
        render.SetStencilTestMask(255)
        render.SetStencilWriteMask(255)
        render.SetStencilReferenceValue(1)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
        render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
        surface.SetDrawColor(255, 255, 255)
        local pts, r = {}, w / 2
        for i = 0, 64 do
            local a = math.rad((i / 64) * -360)
            pts[#pts + 1] = { x = r + math.sin(a) * r, y = r + math.cos(a) * r }
        end
        surface.DrawPoly(pts)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
        av:PaintManual()
        render.SetStencilEnable(false)
    end
end

-- ─── Lignes joueurs ───────────────────────────────────────────────────────────
local scoreboard, scroll
local PlayerLines = {}
local headerIcons = {}

local function createRow(ply)
    local line = vgui.Create("DPanel", scroll)
    line:SetSize(W(1117), ROW_H)
    makeRoundAvatar(line, ply, AV_SIZE, COL_AV_X, ROW_H / 2)

    -- Cache du ping pour éviter la concaténation à chaque frame
    local _cachedPing, _cachedPingStr = -1, "0ms"
    line.Paint = function(self, w, h)
        local cy = h / 2

        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(matRow)
        surface.DrawTexturedRect(0, 0, w, h)

        local stranger  = isStranger(ply)
        local factionId = ply:GetPublicString("VERSE::Char::Faction") or ""
        local gradeClr  = (stranger or not FACTION_COLOR[factionId]) and CLR_UNKNOWN or FACTION_COLOR[factionId]

        -- Nom RP
        draw.SimpleText(
            stranger and "???" or getDisplayName(ply),
            "SB_Row", COL_NAME, cy, CLR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Grade
        draw.SimpleText(
            stranger and "???" or safeGetJobName(ply),
            "SB_Row", COL_GRADE, cy, gradeClr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Niveau
        draw.SimpleText(
            stranger and "???" or tostring(ply:GetLevel() or 0),
            "SB_Row", COL_LEVEL, cy, CLR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Ping : barres + ms centrés sur COL_PING
        local pingVal = ply:Ping()
        if pingVal ~= _cachedPing then
            _cachedPing    = pingVal
            _cachedPingStr = pingVal .. "ms"
        end
        local barsW   = W(4) * 4 + W(2) * 3
        local barsCX  = COL_PING - W(22)
        drawPingBars(barsCX, cy, pingVal)
        draw.SimpleText(_cachedPingStr, "SB_Row", barsCX + barsW / 2 + W(8), cy, CLR_GRAY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    return line
end

local function buildRows()
    local players = sortedPlayers()
    local seen    = {}
    for i, ply in ipairs(players) do
        if not IsValid(PlayerLines[ply]) then
            PlayerLines[ply] = createRow(ply)
        end
        PlayerLines[ply]:SetPos(0, (i - 1) * (ROW_H + ROW_GAP))
        seen[ply] = true
    end
    for ply, line in pairs(PlayerLines) do
        if not seen[ply] then
            if IsValid(line) then line:Remove() end
            PlayerLines[ply] = nil
        end
    end
end

hook.Add("EntityRemoved", "SB_RemoveLine", function(ent)
    if not ent:IsPlayer() then return end
    local line = PlayerLines[ent]
    if IsValid(line) then line:Remove() end
    PlayerLines[ent] = nil
end)

-- ─── En-têtes de colonnes (centrés) ──────────────────────────────────────────
local function addHeaderBtn(parent, label, centerX, mode)
    local btnW = W(200)
    local btn  = vgui.Create("DButton", parent)
    btn:SetSize(btnW, H(38))
    btn:SetPos(centerX - btnW / 2, HDR_Y)
    btn:SetText(label)
    btn:SetFont("SB_Header")
    btn:SetTextColor(CLR_WHITE)
    btn.Paint = function() end

    -- Flèche : DPanel avec rotation pour indiquer le sens du tri
    local angle = 0
    local arr   = vgui.Create("DPanel", parent)
    arr:SetSize(ARROW_SIZE_W, ARROW_SIZE_H)
    arr:SetPos(centerX + W(22), HDR_Y + H(14))
    arr.Paint = function(self, w, h)
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(matArrow)
        surface.DrawTexturedRectRotated(w / 2, h / 2, w, h, angle)
    end

    headerIcons[#headerIcons + 1] = {
        mode     = mode,
        setAngle = function(a) angle = a end,
    }

    btn.DoClick = function()
        if sortMode == mode then sortAsc = not sortAsc
        else sortMode = mode; sortAsc = true end
        -- Met à jour la rotation de toutes les flèches
        for _, entry in ipairs(headerIcons) do
            if entry.mode == sortMode then
                entry.setAngle(sortAsc and 0 or 180)
            else
                entry.setAngle(0)
            end
        end
        buildRows()
    end
end

-- ─── Scoreboard principal ─────────────────────────────────────────────────────
hook.Add("ScoreboardShow", "MyCustomTAB", function()
    if not IsValid(scoreboard) then
        scoreboard = vgui.Create("DFrame")
        scoreboard:SetSize(PANEL_W, PANEL_H)
        scoreboard:SetPos(PANEL_X, PANEL_Y)
        scoreboard:SetTitle("")
        scoreboard:ShowCloseButton(false)
        scoreboard:SetDraggable(false)

        scoreboard.Paint = function(self, w, h)
            surface.SetDrawColor(255, 255, 255, 242)
            surface.SetMaterial(matBg)
            surface.DrawTexturedRect(0, 0, w, h)

            local lW, lH = W(112), H(46)
            surface.SetMaterial(matLogo)
            surface.DrawTexturedRect(w / 2 - lW / 2, H(20), lW, lH)

            local countStr = player.GetCount() .. "/" .. game.MaxPlayers()
            local labelStr = " joueurs"
            surface.SetFont("SB_Count_Bold")
            local bw = surface.GetTextSize(countStr)
            surface.SetFont("SB_Count_Regular")
            local rw = surface.GetTextSize(labelStr)
            local startX = w - W(60) - bw - rw
            local textY  = H(52)
            draw.SimpleText(countStr, "SB_Count_Bold",   startX,      textY, CLR_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(labelStr, "SB_Count_Regular", startX + bw, textY, CLR_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        scroll = vgui.Create("DScrollPanel", scoreboard)
        scroll:Dock(FILL)
        scroll:DockMargin(W(10), H(148), W(25), H(20))

        local vbar = scroll:GetVBar()
        vbar:SetWide(W(4))
        function vbar:Paint(w, h)
            draw.RoundedBox(w, w / 2, 0, w, h, Color(20, 15, 35, 200))
        end
        function vbar.btnUp:Paint()   end
        function vbar.btnDown:Paint() end
        function vbar.btnGrip:Paint(w, h)
            draw.RoundedBox(w, w / 2, 0, w, h, Color(138, 80, 255, 255))
        end

        addHeaderBtn(scoreboard, "Nom",    COL_NAME,  "name")
        addHeaderBtn(scoreboard, "Grade",  COL_GRADE, "grade")
        addHeaderBtn(scoreboard, "Niveau", COL_LEVEL, "niveau")
        addHeaderBtn(scoreboard, "Ping",   COL_PING,  "ping")

        buildRows()
    end

    scoreboard:SetVisible(true)
    gui.EnableScreenClicker(true)
    return true
end)

hook.Add("ScoreboardHide", "MyCustomTAB", function()
    if IsValid(scoreboard) then scoreboard:SetVisible(false) end
    gui.EnableScreenClicker(false)
    return true
end)

hook.Add("Think", "SB_AutoRefresh", function()
    if not IsValid(scoreboard) or not scoreboard:IsVisible() then return end
    if scoreboard._nextRefresh and CurTime() < scoreboard._nextRefresh then return end
    buildRows()
    scoreboard._nextRefresh = CurTime() + 2
end)
