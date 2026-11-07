local Voice = VERSE.Voice
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials

VERSE.Hook.AddNS("Voice", "InitPostEntity", "VERSE::InitPostEntity::Voice", function()
    Materials:SetAlias("micro_icon", "verse/hud/micro_icon")
end)

local entries = entries or {}
local pnlRoot = pnlRoot or nil
local ENTRY_W, ENTRY_H = 260, 44
local GAP_Y = 8
local SHOW_DUR = 0.16
local HIDE_DUR = 0.28
local SLIDE_OUT = 46

-- ─── Couleurs pré-allouées pour le Paint des entrées voix (évite Color() par frame) ─
local _VC_COL_BLUR   = Color(62, 62, 62, 75)    -- .a muté selon _p
local _VC_COL_BG     = Color(62, 62, 62, 130)   -- .a muté selon _p
local _VC_COL_BORDER = Color(255, 255, 255, 30)  -- .a muté selon _p
local _VC_COL_AVATAR = Color(255, 255, 255, 175)
local _VC_COL_ICON   = Color(0,   0,   0,   80)
local _VC_COL_EQ     = Color(255, 255, 255, 0)   -- .a muté selon p et alpha

local function clamp01(t) return (t < 0) and 0 or ((t > 1) and 1 or t) end

local function easeOutCubic(t)
    t = clamp01(t)
    local u = 1 - t
    return 1 - (u * u * u)
end

local function easeInOutQuad(t)
    t = clamp01(t)
    if t < 0.5 then return 2 * t * t end
    t = (2 * t) - 1
    return 1 - 0.5 * (1 - t) * (1 - t)
end

local function EnsureRoot()
    if IsValid(pnlRoot) then return pnlRoot end
    pnlRoot = vgui.Create("DPanel")
    pnlRoot:SetSize(ScrW(), ScrH())
    pnlRoot:SetPos(0, 0)
    pnlRoot:SetMouseInputEnabled(false)
    pnlRoot:SetKeyboardInputEnabled(false)
    pnlRoot.Paint = nil
    return pnlRoot
end

local function StartHide(e)
    if not IsValid(e) then return end
    if e._state == "hiding" then return end
    e._state = "hiding"
    e._t0 = RealTime()
    e._dur = HIDE_DUR
    e._a0 = e._a or e:GetAlpha() or 255
    e._xoff0 = e._xoff or 0
end

local function StartShow(e)
    if not IsValid(e) then return end
    e._state = "showing"
    e._t0 = RealTime()
    e._dur = SHOW_DUR
    e._a0 = e._a or e:GetAlpha() or 0
    e._xoff0 = e._xoff or 0
end

local function RemoveEntry(ply)
    local e = entries[ply]
    if not IsValid(e) then
        entries[ply] = nil
        return
    end
    StartHide(e)
end

local function AddOrRefreshEntry(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    -- Ne pas afficher d'entrée en mode cinématique
    if VERSE.Cinematic and VERSE.Cinematic:IsHUDHidden() then return end

    local root = EnsureRoot()
    local e = entries[ply]

    if not IsValid(e) then
        e = vgui.Create("DPanel", root)
        e:SetSize(R:XY(ENTRY_W, ENTRY_H))
        e:SetAlpha(0)
        e._state = "showing"
        e._t0 = RealTime()
        e._dur = SHOW_DUR
        e._a = 0
        e._a0 = 0
        e._xoff = 0
        e._xoff0 = 0
        e._vol = 0

        e.Paint = function(self, w, h)
            local p = self._p or 0
            local blur = 0.85 + (p * 0.85)
            local radMain = R:Y(16)

            -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
            _VC_COL_BLUR.a   = 75  * (1 - 0.35 * p)
            _VC_COL_BG.a     = 130 * (1 - 0.35 * p)
            _VC_COL_BORDER.a = 30  * (1 - 0.55 * p)

            RNDX().Rect(0, 0, w, h)
                :Rad(radMain)
                :Blur(blur)
                :Color(_VC_COL_BLUR)
                :Shadow(25, 30)
                :Draw()

            RNDX.Draw(radMain, 0, 0, w, h, _VC_COL_BG)
            RNDX.DrawOutlined(radMain, 0, 0, w, h, _VC_COL_BORDER)

            local avSize = R:XY(37, 37)
            local avX, avY = R:XY(4, 4)
            RNDX.Draw(R:Y(14), avX, avY, avSize, avSize, _VC_COL_AVATAR)

            local iconW = R:X(14)
            local iconH = R:Y(21)
            local iconX = avX + (avSize - iconW) * 0.5
            local iconY = avY + (avSize - iconH) * 0.5
            Materials:Draw(_VC_COL_ICON, "micro_icon", iconX, iconY, iconW, iconH, "noclamp smooth")

            local volNow = 0
            if IsValid(ply) and ply.VoiceVolume then
                volNow = tonumber(ply:VoiceVolume()) or 0
            end
            volNow = clamp01(volNow)

            local s = math.Clamp(FrameTime() * 14, 0, 1)
            self._vol = (self._vol or 0) + (volNow - (self._vol or 0)) * s
            local v = self._vol or 0
            local t = RealTime()
            local eqW = R:X(113)
            local eqH = R:Y(36)
            local eqX = w - R:X(16) - eqW
            local eqY = R:Y(4)
            local aMul = math.Clamp((self:GetAlpha() or 255) / 255, 0, 1)
            local eqA = math.floor(190 * (1 - (p * 0.35)) * aMul)
            _VC_COL_EQ.a = eqA
            local bars = 10
            local gap = math.max(1, math.floor(eqW * 0.06))
            local barW = math.max(1, math.floor((eqW - gap * (bars - 1)) / bars))
            local usedW = barW * bars + gap * (bars - 1)
            local ox = eqX + math.floor((eqW - usedW) * 0.5)
            local midY = eqY + eqH * 0.5
            local minHalf = math.max(1, math.floor(eqH * 0.10))
            local maxAdd = math.max(1, math.floor(eqH * 0.40))
            local globalWobble = math.sin(t * 6) * (eqH * 0.02) * v

            for i = 1, bars do
                local phase = i * 0.85
                local n1 = math.abs(math.sin(t * 10 + phase))
                local n2 = math.abs(math.sin(t * 6 + phase * 1.7))
                local k = math.Clamp(n1 * 0.65 + n2 * 0.35, 0, 1)
                local halfH = minHalf + (maxAdd * v * k)
                local wobble = math.sin(t * 9 + phase * 1.3) * (eqH * 0.03) * v
                local cx = ox + (i - 1) * (barW + gap)
                local topY = (midY + globalWobble + wobble) - halfH
                local bh = halfH * 2
                RNDX.Draw(math.min(barW * 0.5, R:Y(6)), cx, topY, barW, bh, _VC_COL_EQ)
            end
        end

        e.Name = vgui.Create("MantleText", e)
        e.Name:SetSize(R:XY(90, 37))
        e.Name:SetPos(R:XY(40, 4))
        e.Name:SetMouseInputEnabled(false)
        e.Name:SetKeyboardInputEnabled(false)
        e.Name:SetText(IsValid(ply) and ply:Nick() or "?")
        e.Name:SetFont(Font:GetNamed("Poppins", "Medium", 16))
        e.Name:SetColor(color_white)
        e.Name:SetAlign(TEXT_ALIGN_LEFT)
        e.Name:SetVAlign("center")
        e.Name:SetPadding(R:XY(5))

        entries[ply] = e
    end

    StartShow(e)
end

local function LayoutEntries()
    local baseX = ScrW() - R:X(20) - R:X(ENTRY_W)
    local baseY = ScrH() - R:Y(45 + 270)
    local gap = R:Y(GAP_Y)

    local list = {}
    for ply, e in pairs(entries) do
        if IsValid(e) and IsValid(ply) then
            list[#list + 1] = { ply = ply, e = e }
        end
    end

    table.sort(list, function(a, b)
        return a.ply:EntIndex() < b.ply:EntIndex()
    end)

    for i = 1, #list do
        local e = list[i].e
        local xoff = e._xoff or 0
        local y = baseY - (i - 1) * (e:GetTall() + gap)
        e:SetPos(baseX + xoff, y)
    end
end

VERSE.Hook.AddNS("Voice", "Think", "VERSE::Think::Voice", function()
    if not IsValid(pnlRoot) then return end

    -- En mode cinématique : masquer immédiatement toutes les entrées visibles
    if VERSE.Cinematic and VERSE.Cinematic:IsHUDHidden() then
        for ply, e in pairs(entries) do
            if IsValid(e) and e._state ~= "hiding" then
                StartHide(e)
            end
        end
    end

    local dirty    = false
    local animating = false   -- true si au moins un panel est en cours d'animation
    local now = RealTime()
    local slide = R:X(SLIDE_OUT)

    for ply, e in pairs(entries) do
        if not IsValid(e) or not IsValid(ply) then
            entries[ply] = nil
            dirty = true
        else
            local st = e._state or "idle"
            if st ~= "idle" then animating = true end
            local t0 = e._t0 or now
            local dur = e._dur or 0.001
            local t = clamp01((now - t0) / dur)

            if st == "showing" then
                local k = easeOutCubic(t)

                local a = (e._a0 or 0) + (255 - (e._a0 or 0)) * k
                e._a = a
                e:SetAlpha(math.Clamp(a, 0, 255))

                local xoff = (e._xoff0 or 0) + (0 - (e._xoff0 or 0)) * k
                e._xoff = xoff
                e._p = 0

                if IsValid(e.Name) then
                    e.Name:SetAlpha(e:GetAlpha() or 255)
                end

                if t >= 1 then
                    e._state = "idle"
                    e._a0 = nil
                    e._xoff0 = nil
                end

            elseif st == "hiding" then
                local k = easeInOutQuad(t)

                local a0 = e._a0 or (e._a or 255)
                local a = a0 + (0 - a0) * k
                e._a = a
                e:SetAlpha(math.Clamp(a, 0, 255))

                local xo0 = e._xoff0 or (e._xoff or 0)
                local xoff = xo0 + (slide - xo0) * k
                e._xoff = xoff
                e._p = k

                if IsValid(e.Name) then
                    e.Name:SetAlpha(e:GetAlpha() or 255)
                end

                if t >= 1 or a <= 2 then
                    e:Remove()
                    entries[ply] = nil
                    dirty = true
                end
            else
                e._p = 0
                e._xoff = e._xoff or 0

                if IsValid(e.Name) then
                    e.Name:SetAlpha(e:GetAlpha() or 255)
                end
            end
        end
    end

    -- Repositionner uniquement si la liste a changé (dirty) ou si un panel
    -- est en animation (xoff se met à jour frame par frame).
    if dirty or animating then
        LayoutEntries()
    end
end)

VERSE.Hook.AddNS("Voice", "PlayerStartVoice", "VERSE::PlayerStartVoice::Voice", function(ply)
    AddOrRefreshEntry(ply)
    LayoutEntries()
end)

VERSE.Hook.AddNS("Voice", "PlayerEndVoice", "VERSE::PlayerEndVoice::Voice", function(ply)
    RemoveEntry(ply)
end)

net.Receive(Voice.Net.Sync, function()
    local ply = net.ReadEntity()
    local isSpeaking = net.ReadBool()

    if not IsValid(ply) or not ply:IsPlayer() then return end
    if isSpeaking then
        AddOrRefreshEntry(ply)
        LayoutEntries()
    else
        RemoveEntry(ply)
    end
end)