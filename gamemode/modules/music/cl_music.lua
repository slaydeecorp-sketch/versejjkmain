VERSE.Hook.ClearNS("Music")
local M = VERSE.Music
local R = VERSE.Responsive
local Font = VERSE.Fonts
local L = VERSE.L
if not M then return end
M._channel = M._channel or nil
M._currentTrack = M._currentTrack or nil
M._playing = M._playing or false
M._paused = M._paused or false
M._volume = M._volume or (M.Config.DefaultVolume or 0.5)
M._startTime = M._startTime or 0
M._pauseTime = M._pauseTime or 0
M._mode = M._mode or "self"
M._areaKnown = M._areaKnown or {}
M._areaActiveId = nil
M._areaChannel = nil
M._areaRadius = M._areaRadius or (M.Config.AreaRadius or 1500)
M._myAreaSourceId = M._myAreaSourceId or nil
M._loop = (M._loop == nil) and true or M._loop
M._hearOthers = (M._hearOthers == nil) and true or M._hearOthers
M._frame = nil
M._activeCategory = M._activeCategory or "chill"
netstream.Hook(M.Net.TrackList, function(tracks)
    M.Tracks = tracks or {}
    if IsValid(M._frame) then hook.Run("VERSE::Music::TracksUpdated") end
end)

local function isFavorite(trackId)
    return cookie.GetString("verse_music_fav_" .. trackId, "") == "1"
end

local function setFavorite(trackId, val)
    cookie.Set("verse_music_fav_" .. trackId, val and "1" or "0")
end

local function getFavorites()
    local result = {}
    for _, t in ipairs(M.Tracks) do
        if isFavorite(t.id) then result[#result + 1] = t end
    end
    return result
end

function M:Play(track)
    self:StopSelf()
    if not track then return end
    M._loadingTrack = track.id
    local filePath = "sound/" .. track.path
    sound.PlayFile(filePath, "noplay", function(channel, errId, errStr)
        if M._loadingTrack ~= track.id then
            if IsValid(channel) then channel:Stop() end
            return
        end

        M._loadingTrack = nil
        if not IsValid(channel) then
            VERSE.Log:Error("[Music] PlayFile failed: " .. tostring(errStr))
            return
        end

        if IsValid(M._channel) then M._channel:Stop() end
        M._channel = channel
        M._currentTrack = track
        local realDur = channel:GetLength()
        if realDur and realDur > 0 then
            M._currentTrack = table.Copy(track)
            M._currentTrack.duration = realDur
        end

        M._playing = true
        M._paused = false
        M._startTime = RealTime()
        M._pauseTime = 0
        channel:SetVolume(M._volume)
        channel:Play()
    end)
end

function M:PlayForArea(track)
    if not track then return end
    M._expectingMyArea = true
    netstream.Start(M.Net.AreaPlay, {
        trackId = track.id,
        radius = M._areaRadius or M.Config.AreaRadius,
    })
end

function M:StopSelf()
    M._playing = false
    M._paused = false
    M._currentTrack = nil
    if IsValid(M._channel) then
        M._channel:Stop()
        M._channel = nil
    end
end

function M:StopArea()
    if M._myAreaSourceId then netstream.Start(M.Net.AreaStop, M._myAreaSourceId) end
    M._areaKnown[M._myAreaSourceId] = nil
    M._myAreaSourceId = nil
    M._radiusPreviewUntil = 0
    self:AreaRefreshActive()
end

function M:StopAreaChannel()
    if IsValid(M._areaChannel) then
        M._areaChannel:Stop()
        M._areaChannel = nil
    end

    M._areaActiveId = nil
end

function M:StopAllAreaLocal()
    self:StopAreaChannel()
    M._areaKnown = {}
    M._myAreaSourceId = nil
end

function M:AreaRefreshActive()
    if not M._hearOthers then
        self:StopAreaChannel()
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local myPos = ply:GetPos()
    local bestId, bestDist = nil, math.huge
    for sid, src in pairs(M._areaKnown) do
        -- Ne pas rejouer sa propre source via _areaChannel : le diffuseur
        -- l'entend déjà via _channel (playback personnel). Sans ce guard
        -- il entendrait la même piste en double.
        if sid ~= M._myAreaSourceId then
            if src.pos then
                local dist = myPos:DistToSqr(src.pos)
                if dist < bestDist then
                    bestId = sid
                    bestDist = dist
                end
            else
                if not bestId then bestId = sid end
            end
        end
    end

    if not bestId then
        self:StopAreaChannel()
        return
    end

    if M._areaActiveId == bestId and IsValid(M._areaChannel) then return end
    self:StopAreaChannel()
    local src = M._areaKnown[bestId]
    if not src or not src.track then return end
    M._areaActiveId = bestId
    local filePath = "sound/" .. src.track.path
    sound.PlayFile(filePath, "noplay", function(channel, errId, errStr)
        if not IsValid(channel) then return end
        if M._areaActiveId ~= bestId then
            channel:Stop()
            return
        end

        M._areaChannel = channel
        channel:SetVolume(M._volume)
        if src.elapsed and src.elapsed > 0 then channel:SetTime(src.elapsed) end
        channel:Play()
    end)
end

function M:AreaAddSource(sourceId, track, elapsed, pos, radius)
    if not track or not sourceId then return end
    M._areaKnown[sourceId] = {
        track = track,
        pos = pos,
        radius = radius or M.Config.AreaRadius,
        elapsed = elapsed,
    }

    self:AreaRefreshActive()
end

function M:AreaRemoveSource(sourceId)
    if not sourceId then return end
    M._areaKnown[sourceId] = nil
    if M._areaActiveId == sourceId then self:StopAreaChannel() end
    self:AreaRefreshActive()
end

function M:Pause()
    if not M._playing or M._paused then return end
    if not IsValid(M._channel) then return end
    M._paused = true
    M._pauseTime = RealTime()
    M._channel:Pause()
end

function M:Resume()
    if not M._playing or not M._paused then return end
    if not IsValid(M._channel) then return end
    M._paused = false
    local pauseDur = RealTime() - M._pauseTime
    M._startTime = M._startTime + pauseDur
    M._channel:Play()
end

function M:SetVolume(vol)
    M._volume = math.Clamp(tonumber(vol) or 0.5, 0, 1)
    if IsValid(M._channel) then M._channel:SetVolume(M._volume) end
    if IsValid(M._areaChannel) then M._areaChannel:SetVolume(M._volume) end
end

function M:GetElapsed()
    if not M._playing then return 0 end
    if IsValid(M._channel) then return M._channel:GetTime() end
    if M._paused then return M._pauseTime - M._startTime end
    return RealTime() - M._startTime
end

function M:IsPlaying()
    return M._playing and IsValid(M._channel)
end

function M:Stop()
    -- Stoppe la diffusion zone si une source appartient au joueur,
    -- indépendamment du mode actuel (l'utilisateur peut avoir changé
    -- de mode entre le Play et le Stop).
    if M._myAreaSourceId then M:StopArea() end
    M:StopSelf()
end

VERSE.Hook.AddNS("Music", "Think", "VERSE::Music::LoopThink", function()
    if not M._playing or M._paused then return end
    if not IsValid(M._channel) then return end
    if M._channel:GetState() == GMOD_CHANNEL_STOPPED and M._currentTrack then
        if M._loop then
            M:Play(M._currentTrack)
        else
            M:StopSelf()
        end
    end
end)

function M:DoPlay(track)
    if M._mode == "area" then
        M:Play(track)
        M:PlayForArea(track)
    else
        M:Play(track)
    end
end

local CLR_FRAME = Color(26, 16, 48)
local CLR_FRAME_OUTLINE = Color(40, 30, 65, 120)
local CLR_SIDE_BG = Color(35, 25, 60)
local CLR_SIDE_OUTLINE = Color(55, 40, 90)
local CLR_CAT_DEFAULT = Color(40, 30, 65)
local CLR_CAT_HOVER = Color(55, 40, 85)
local CLR_CAT_ACTIVE = Color(124, 77, 255)
local CLR_ROW_BG = Color(38, 24, 68)
local CLR_ROW_HOVER = Color(55, 38, 90)
local CLR_ROW_PLAYING = Color(100, 60, 180, 200)
local CLR_BAR_BG = Color(20, 14, 40, 245)
local CLR_ACCENT = Color(124, 77, 255)
local CLR_ACCENT_LIGHT = Color(155, 109, 255)
local CLR_TEXT_DIM = Color(150, 140, 180)
local CLR_FAV_ON = Color(255, 200, 50)
local CLR_FAV_OFF = Color(90, 75, 120)
local CLR_PLAY_BG = Color(50, 35, 80)
local CLR_PLAY_HOVER = Color(75, 55, 120)
local CLR_TRACK = Color(90, 85, 105)
local CLR_DOT = Color(195, 195, 200)
local CLR_CHECK_ON = Color(124, 77, 255)
local CLR_CHECK_BOX = Color(45, 35, 70)

-- ─── Couleurs pré-allouées pour Music (évite Color() par frame) ───────────────
local _MUS_COL_CHECK_HOV   = Color(65,  55,  90,  255)    -- hearBtn hover
local _MUS_COL_FAV_BG_HOV  = Color(60,  50,  85,  255)    -- favBtn hover bg
local _MUS_COL_FAV_BG_NORM = Color(45,  35,  65,  255)    -- favBtn normal bg
local _MUS_COL_SEARCH_HL   = Color(255, 255, 255, 40)      -- searchEntry highlight
local _MUS_COL_BTN_HOVERED = Color(0,   0,   0,   255)    -- r/g/b mutés (hover = +15)
-- ─────────────────────────────────────────────────────────────────────────────
function M:OpenUI()
    if IsValid(M._frame) then M._frame:Remove() end
    local frameW, frameH = R:X(1371), R:Y(802)
    local fTitle = Font:GetNamed("Poppins", "Bold", 38)
    local fCat = Font:GetNamed("Poppins", "SemiBold", 16)
    local fName   = Font:GetNamed("Poppins", "SemiBold", 17)
    local fArtist = Font:GetNamed("Poppins", "Regular",  13)
    local fTime = Font:GetNamed("Poppins", "Regular", 15)
    local fIcon = Font:GetNamed("Poppins", "Bold", 28)
    local fStar = Font:GetNamed("Poppins", "Bold", 22)
    local fPlay = Font:GetNamed("Poppins", "Bold", 28)
    local fSearch = Font:GetNamed("Poppins", "Regular", 15)
    local frame = vgui.Create("MantleFrame")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("")
    frame:SetAlphaBackground(false)
    frame:DisableCloseBtn()
    frame:SetClosable(true)
    M._frame = frame
    frame.Paint = function(_, w, h)
        RNDX.Draw(R:Y(15), 0, 0, w, h, CLR_FRAME)
        RNDX.DrawOutlined(R:Y(15), 0, 0, w, h, CLR_FRAME_OUTLINE, 2)
    end

    local sideX, sideY = R:X(15), R:Y(15)
    local sideW = R:X(295)
    local sideH = frameH - R:Y(30)
    local contentX = sideX + sideW + R:X(15)
    local contentY = R:Y(80)
    local contentW = frameW - contentX - R:X(15)
    local barH = R:Y(105)
    local contentH = frameH - contentY - barH - R:Y(30)
    local sidePanel = vgui.Create("DPanel", frame)
    sidePanel:SetPos(sideX, sideY)
    sidePanel:SetSize(sideW, sideH)
    sidePanel.Paint = function(_, w, h)
        RNDX.Draw(R:Y(12), 0, 0, w, h, CLR_SIDE_BG)
        RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, CLR_SIDE_OUTLINE, 1)
    end

    local innerPad = R:X(12)
    local searchIconFont = Font:GetNamed("Poppins", "Bold", 18)
    local searchEntry = vgui.Create("DTextEntry", sidePanel)
    searchEntry:SetPos(innerPad, R:Y(15))
    searchEntry:SetSize(sideW - innerPad * 2, R:Y(40))
    searchEntry:SetFont(fSearch)
    searchEntry:SetDrawLanguageID(false)
    searchEntry:SetUpdateOnType(true)
    searchEntry:SetPaintBackground(false)
    searchEntry:SetTextColor(color_white)
    searchEntry:SetCursorColor(color_white)
    if searchEntry.SetAllowNonAsciiCharacters then searchEntry:SetAllowNonAsciiCharacters(true) end
    searchEntry.Paint = function(s, w, h)
        RNDX.Draw(R:Y(28), 0, 0, w, h, CLR_SIDE_BG)
        RNDX.DrawOutlined(R:Y(28), 0, 0, w, h, CLR_SIDE_OUTLINE, 1)
        local val = s:GetValue() or ""
        if val == "" and not s:HasFocus() then
            draw.SimpleText("Q", searchIconFont, R:X(18), h / 2, CLR_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(L("music.search"), fSearch, R:X(42), h / 2, CLR_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            s:DrawTextEntryText(color_white, _MUS_COL_SEARCH_HL, color_white)
        end
        return true
    end

    local catStartY = R:Y(70)
    local catH = R:Y(44)
    local catGap = R:Y(8)
    local function refreshTrackList()
    end

    for i, cat in ipairs(M.Categories) do
        local btn = vgui.Create("MantleBtn", sidePanel)
        btn:SetPos(innerPad, catStartY + (i - 1) * (catH + catGap))
        btn:SetSize(sideW - innerPad * 2, catH)
        btn:SetTxt(L(cat.name))
        btn:SetFont(fCat)
        btn:SetRadius(R:Y(10))
        btn:SetGradient(false)
        btn:SetRipple(true)
        local catId = cat.id
        btn:SetColor(CLR_CAT_DEFAULT)
        btn:SetColorHover(CLR_CAT_HOVER)
        btn.Think = function(s)
            local active = M._activeCategory == catId
            if active then
                s:SetColor(CLR_CAT_ACTIVE)
                s:SetColorHover(CLR_ACCENT_LIGHT)
            else
                s:SetColor(CLR_CAT_DEFAULT)
                s:SetColorHover(CLR_CAT_HOVER)
            end
        end

        btn.DoClick = function()
            M._activeCategory = catId
            searchEntry:SetText("")
            refreshTrackList()
        end
    end

    local fCheck = Font:GetNamed("Poppins", "Regular", 18)
    local checkH = R:Y(28)
    local checkY = sideH - checkH - R:Y(15)
    local hearBtn = vgui.Create("DButton", sidePanel)
    hearBtn:SetPos(innerPad, checkY)
    hearBtn:SetSize(sideW - innerPad * 2, checkH)
    hearBtn:SetText("")
    hearBtn:SetCursor("hand")
    hearBtn.Paint = function(s, w, h)
        local on = M._hearOthers
        local hov = s:IsHovered()
        local boxSz = R:Y(16)
        local boxY = (h - boxSz) / 2
        local boxBg = on and CLR_CHECK_ON or (hov and _MUS_COL_CHECK_HOV or CLR_CHECK_BOX)
        RNDX.Draw(R:Y(4), R:X(4), boxY, boxSz, boxSz, boxBg)
        if on then draw.SimpleText("✓", fCheck, R:X(4) + boxSz / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
        draw.SimpleText(L("music.hear_others"), fCheck, R:X(4) + boxSz + R:X(8), h / 2, hov and color_white or CLR_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    hearBtn.DoClick = function()
        M._hearOthers = not M._hearOthers
        if not M._hearOthers then
            M:StopAreaChannel()
        else
            netstream.Start(M.Net.AreaResync)
        end
    end

    local titlePanel = vgui.Create("DPanel", frame)
    titlePanel:SetPos(contentX, R:Y(20))
    titlePanel:SetSize(contentW, R:Y(50))
    titlePanel.Paint = function(_, w, h) draw.SimpleText(L("music.title"), fTitle, w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
    local trackScroll = vgui.Create("MantleScrollPanel", frame)
    trackScroll:SetPos(contentX, contentY)
    trackScroll:SetSize(contentW, contentH)
    local function buildTrackRows(tracks)
        trackScroll:Clear()
        local rowH = R:Y(60)
        local gap = R:Y(5)
        local btnSz = R:X(36)
        for _, track in ipairs(tracks) do
            local row = vgui.Create("DPanel")
            row:SetTall(rowH)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, gap)
            row:SetMouseInputEnabled(true)
            row.Paint = function(s, w, h)
                local hov = s:IsHovered()
                local playing = M._currentTrack and M._currentTrack.id == track.id
                local bg = playing and CLR_ROW_PLAYING or (hov and CLR_ROW_HOVER or CLR_ROW_BG)
                RNDX.Draw(R:Y(12), 0, 0, w, h, bg)
                if playing then RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, CLR_ACCENT, 1) end
                draw.SimpleText("♫", fIcon, R:X(22), h / 2 - R:Y(2), playing and CLR_ACCENT_LIGHT or CLR_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(track.name, fName, R:X(55), h * 0.36, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(track.artist or "", fArtist, R:X(55), h * 0.65, CLR_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local favBtn = vgui.Create("DButton", row)
            favBtn:SetSize(btnSz, btnSz)
            favBtn:SetPos(contentW - R:X(95), (rowH - btnSz) / 2)
            favBtn:SetText("")
            favBtn:SetCursor("hand")
            favBtn.Paint = function(s, w, h)
                local fav = isFavorite(track.id)
                local hov = s:IsHovered()
                RNDX.Draw(w / 2, 0, 0, w, h, hov and _MUS_COL_FAV_BG_HOV or _MUS_COL_FAV_BG_NORM)
                draw.SimpleText("★", fStar, w / 2, h / 2 - R:Y(1), fav and CLR_FAV_ON or CLR_FAV_OFF, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            favBtn.DoClick = function()
                setFavorite(track.id, not isFavorite(track.id))
                if M._activeCategory == "favorites" then refreshTrackList() end
            end

            local playBtn = vgui.Create("DButton", row)
            playBtn:SetSize(btnSz, btnSz)
            playBtn:SetPos(contentW - R:X(50), (rowH - btnSz) / 2)
            playBtn:SetText("")
            playBtn:SetCursor("hand")
            playBtn.Paint = function(s, w, h)
                local hov = s:IsHovered()
                RNDX.Draw(w / 2, 0, 0, w, h, hov and CLR_PLAY_HOVER or CLR_PLAY_BG)
                draw.SimpleText("▶", fPlay, w / 2 + R:X(1), h / 2 - R:Y(1), hov and color_white or CLR_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            playBtn.DoClick = function() M:DoPlay(track) end
            trackScroll:AddItem(row)
        end
    end

    refreshTrackList = function()
        local tracks
        if M._activeCategory == "favorites" then
            tracks = getFavorites()
        else
            tracks = M:GetTracksByCategory(M._activeCategory)
        end

        buildTrackRows(tracks)
    end

    searchEntry.OnChange = function(s)
        local q = string.Trim(s:GetValue() or "")
        if q == "" then
            refreshTrackList()
        else
            buildTrackRows(M:SearchTracks(q))
        end
    end

    hook.Add("VERSE::Music::TracksUpdated", "VERSE::Music::UIRefresh", function()
        if not IsValid(trackScroll) then return end
        refreshTrackList()
    end)

    local barNewH = R:Y(105)
    local barW = contentW
    local playerBar = vgui.Create("DPanel", frame)
    playerBar:SetPos(contentX, frameH - barNewH - R:Y(10))
    playerBar:SetSize(barW, barNewH)
    playerBar.Paint = function(_, w, h)
        RNDX.Draw(R:Y(16), 0, 0, w, h, CLR_BAR_BG)
        RNDX.DrawOutlined(R:Y(16), 0, 0, w, h, CLR_SIDE_OUTLINE, 1)
    end

    local padX = R:X(25)
    local padY = R:Y(14)
    local progW = barW - padX * 2
    local progH = R:Y(35)
    local progressPanel = vgui.Create("DPanel", playerBar)
    progressPanel:SetPos(padX, padY)
    progressPanel:SetSize(progW, progH)
    progressPanel._dragging = false
    progressPanel._dragFrac = 0
    progressPanel.Paint = function(s, w, h)
        local elapsed = M:GetElapsed()
        local dur = (M._currentTrack and M._currentTrack.duration) or 1
        local frac = s._dragging and s._dragFrac or math.Clamp(elapsed / dur, 0, 1)
        local tY = R:Y(6)
        local tH = R:Y(3)
        RNDX.Draw(2, 0, tY, w, tH, CLR_TRACK)
        if frac > 0.001 then RNDX.Draw(2, 0, tY, w * frac, tH, CLR_ACCENT) end
        local dotR = s._dragging and R:Y(12) or R:Y(10)
        RNDX().Circle(math.max(R:Y(5), w * frac), tY + tH / 2, dotR):Color(CLR_DOT):Draw()
        local displayTime = s._dragging and (dur * s._dragFrac) or elapsed
        draw.SimpleText(M:FormatTime(displayTime), fTime, 0, R:Y(16), CLR_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(M:FormatTime(dur), fTime, w, R:Y(16), CLR_TEXT_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    progressPanel.OnMousePressed = function(s, code)
        if code ~= MOUSE_LEFT then return end
        if not M._playing or not IsValid(M._channel) then return end
        s._dragging = true
        s:MouseCapture(true)
        local mx = s:CursorPos()
        s._dragFrac = math.Clamp(mx / s:GetWide(), 0, 1)
    end

    progressPanel.OnMouseReleased = function(s, code)
        if code ~= MOUSE_LEFT or not s._dragging then return end
        s._dragging = false
        s:MouseCapture(false)
        if IsValid(M._channel) and M._currentTrack then
            local dur = M._currentTrack.duration or 1
            M._channel:SetTime(dur * s._dragFrac)
            M._startTime = RealTime() - (dur * s._dragFrac)
            if M._paused then M._pauseTime = RealTime() end
        end
    end

    progressPanel.OnCursorMoved = function(s, mx) if s._dragging then s._dragFrac = math.Clamp(mx / s:GetWide(), 0, 1) end end
    local row2Y = padY + progH + R:Y(8)
    local btnSz = R:Y(28)
    local btnGap = R:X(8)
    local fMode = Font:GetNamed("Poppins", "SemiBold", 20)
    local fLoop = Font:GetNamed("Poppins", "Bold", 22)
    local fRadNum = Font:GetNamed("Poppins", "SemiBold", 24)
    local CLR_MODE_SELF = Color(62, 60, 72)
    local CLR_MODE_AREA = Color(124, 77, 255)
    local CLR_CTRL_BG = Color(55, 52, 68)
    local CLR_CTRL_HOVER = Color(72, 68, 88)
    local CLR_LOOP_ON = Color(124, 77, 255)
    local curX = padX
    local pauseBtn = vgui.Create("DButton", playerBar)
    pauseBtn:SetPos(curX, row2Y)
    pauseBtn:SetSize(btnSz, btnSz)
    pauseBtn:SetText("")
    pauseBtn:SetCursor("hand")
    pauseBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        RNDX.Draw(R:Y(6), 0, 0, w, h, hov and CLR_CTRL_HOVER or CLR_CTRL_BG)
        local clr = color_white
        if M._paused then
            draw.NoTexture()
            surface.SetDrawColor(clr)
            local ox = w * 0.35
            surface.DrawPoly({
                {
                    x = ox,
                    y = R:Y(5)
                },
                {
                    x = w - R:X(5),
                    y = h / 2
                },
                {
                    x = ox,
                    y = h - R:Y(5)
                },
            })
        else
            local bw = R:X(4)
            local gap = R:X(4)
            local sx = (w - bw * 2 - gap) / 2
            RNDX.Draw(1, sx, R:Y(6), bw, h - R:Y(12), clr)
            RNDX.Draw(1, sx + bw + gap, R:Y(6), bw, h - R:Y(12), clr)
        end
    end

    pauseBtn.DoClick = function()
        if M._paused then
            M:Resume()
        else
            M:Pause()
        end
    end

    curX = curX + btnSz + btnGap
    local stopBtn = vgui.Create("DButton", playerBar)
    stopBtn:SetPos(curX, row2Y)
    stopBtn:SetSize(btnSz, btnSz)
    stopBtn:SetText("")
    stopBtn:SetCursor("hand")
    stopBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        RNDX.Draw(R:Y(6), 0, 0, w, h, hov and CLR_CTRL_HOVER or CLR_CTRL_BG)
        local m = R:Y(7)
        RNDX.Draw(2, m, m, w - m * 2, h - m * 2, color_white)
    end

    stopBtn.DoClick = function() M:Stop() end
    curX = curX + btnSz + btnGap
    local loopBtn = vgui.Create("DButton", playerBar)
    loopBtn:SetPos(curX, row2Y)
    loopBtn:SetSize(btnSz, btnSz)
    loopBtn:SetText("")
    loopBtn:SetCursor("hand")
    loopBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        local on = M._loop
        local bg = on and CLR_LOOP_ON or CLR_CTRL_BG
        if hov then
            -- Mutation de la couleur pré-allouée (évite Color() à chaque frame)
            _MUS_COL_BTN_HOVERED.r, _MUS_COL_BTN_HOVERED.g, _MUS_COL_BTN_HOVERED.b = bg.r + 15, bg.g + 15, bg.b + 15
            bg = _MUS_COL_BTN_HOVERED
        end
        RNDX.Draw(R:Y(6), 0, 0, w, h, bg)
        draw.SimpleText("↻", fLoop, w / 2, h / 2 - R:Y(1), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    loopBtn.DoClick = function() M._loop = not M._loop end
    curX = curX + btnSz + R:X(15)
    local modeBtnW = R:X(110)
    local modeBtn = vgui.Create("DButton", playerBar)
    modeBtn:SetPos(curX, row2Y)
    modeBtn:SetSize(modeBtnW, btnSz)
    modeBtn:SetText("")
    modeBtn:SetCursor("hand")
    modeBtn.Paint = function(s, w, h)
        local isArea = M._mode == "area"
        local hov = s:IsHovered()
        local bg = isArea and CLR_MODE_AREA or CLR_MODE_SELF
        if hov then
            -- Mutation de la couleur pré-allouée (évite Color() à chaque frame)
            _MUS_COL_BTN_HOVERED.r, _MUS_COL_BTN_HOVERED.g, _MUS_COL_BTN_HOVERED.b = bg.r + 15, bg.g + 15, bg.b + 15
            bg = _MUS_COL_BTN_HOVERED
        end
        RNDX.Draw(R:Y(8), 0, 0, w, h, bg)
        local txt = isArea and L("music.mode_area") or L("music.mode_self")
        draw.SimpleText(txt, fMode, w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    modeBtn.DoClick = function()
        M._mode = (M._mode == "self") and "area" or "self"
    end
    curX = curX + modeBtnW + R:X(10)
    local radMin = M.Config.AreaRadiusMin or 500
    local radMax = M.Config.AreaRadiusMax or 3000
    local radSliderW = R:X(150)
    local radSlider = vgui.Create("DPanel", playerBar)
    radSlider:SetPos(curX, row2Y)
    radSlider:SetSize(radSliderW, btnSz)
    radSlider._dragging = false
    radSlider.Paint = function(s, w, h)
        if M._mode ~= "area" then return end
        local frac = math.Clamp(((M._areaRadius or 1500) - radMin) / (radMax - radMin), 0, 1)
        local slPad = R:X(8)
        local slW = w - slPad * 2
        local slY = h / 2 + R:Y(2)
        local slH = R:Y(3)
        RNDX.Draw(2, slPad, slY - slH / 2, slW, slH, CLR_TRACK)
        if frac > 0.01 then RNDX.Draw(2, slPad, slY - slH / 2, slW * frac, slH, CLR_ACCENT) end
        local dotX = slPad + slW * frac
        RNDX().Circle(dotX, slY, R:Y(8)):Color(CLR_DOT):Draw()
        draw.SimpleText(tostring(math.floor(M._areaRadius or 1500)), fRadNum, w / 2, h / 2 - R:Y(8), CLR_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    radSlider.OnMousePressed = function(s, code)
        if code ~= MOUSE_LEFT or M._mode ~= "area" then return end
        s._dragging = true
        s:MouseCapture(true)
        local mx = s:CursorPos()
        local slPad = R:X(8)
        local slW = s:GetWide() - slPad * 2
        local frac = math.Clamp((mx - slPad) / slW, 0, 1)
        M._areaRadius = math.floor(radMin + frac * (radMax - radMin))
        M._radiusPreviewUntil = RealTime() + 3
    end

    radSlider.OnMouseReleased = function(s, code)
        if code == MOUSE_LEFT then
            s._dragging = false
            s:MouseCapture(false)
        end
    end

    radSlider.OnCursorMoved = function(s, mx)
        if not s._dragging or M._mode ~= "area" then return end
        local slPad = R:X(8)
        local slW = s:GetWide() - slPad * 2
        local frac = math.Clamp((mx - slPad) / slW, 0, 1)
        M._areaRadius = math.floor(radMin + frac * (radMax - radMin))
        M._radiusPreviewUntil = RealTime() + 3
    end

    local vW = R:X(140)
    local vX = barW - vW - padX
    local volPanel = vgui.Create("DPanel", playerBar)
    volPanel:SetPos(vX, row2Y)
    volPanel:SetSize(vW, btnSz)
    volPanel._dragging = false
    volPanel.Paint = function(s, w, h)
        local slPad = R:X(10)
        local slW = w - slPad * 2
        local slY = h / 2 + R:Y(10)
        local slH = R:Y(3)
        local frac = M._volume
        RNDX.Draw(2, slPad, slY - slH / 2, slW, slH, CLR_TRACK)
        if frac > 0.001 then RNDX.Draw(2, slPad, slY - slH / 2, slW * frac, slH, CLR_ACCENT) end
        local dotX = slPad + slW * frac
        RNDX().Circle(dotX, slY, R:Y(8)):Color(CLR_DOT):Draw()
        draw.SimpleText("Volume", fMode, w / 2, h / 2 - R:Y(2), CLR_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    volPanel.OnMousePressed = function(s, code)
        if code == MOUSE_LEFT then
            s._dragging = true
            s:MouseCapture(true)
            local mx = s:CursorPos()
            local frac = math.Clamp((mx - R:X(10)) / (s:GetWide() - R:X(20)), 0, 1)
            M:SetVolume(frac)
        end
    end

    volPanel.OnMouseReleased = function(s, code)
        if code == MOUSE_LEFT then
            s._dragging = false
            s:MouseCapture(false)
        end
    end

    volPanel.OnCursorMoved = function(s, mx)
        if s._dragging then
            local frac = math.Clamp((mx - R:X(10)) / (s:GetWide() - R:X(20)), 0, 1)
            M:SetVolume(frac)
        end
    end

    refreshTrackList()
    local oldRemove = frame.Remove
    frame.Remove = function(s)
        hook.Remove("VERSE::Music::TracksUpdated", "VERSE::Music::UIRefresh")
        oldRemove(s)
    end
end

function M:CloseUI()
    if IsValid(M._frame) then
        M._frame:Remove()
        M._frame = nil
    end
end

function M:ToggleUI()
    if IsValid(M._frame) then
        M:CloseUI()
    else
        M:OpenUI()
    end
end

VERSE.Commands.Add("verse_ost_menu", function() M:ToggleUI() end, nil, "client")
netstream.Hook(M.Net.AreaPlay, function(data)
    if not istable(data) then return end
    local track = M:GetTrack(data.trackId)
    if not track then return end
    local pos = data.pos and Vector(data.pos.x, data.pos.y, data.pos.z) or nil
    local radius = data.radius or M.Config.AreaRadius
    if M._expectingMyArea then
        M._myAreaSourceId = data.sourceId
        M._expectingMyArea = false
    end

    M:AreaAddSource(data.sourceId, track, nil, pos, radius)
end)

netstream.Hook(M.Net.AreaSync, function(data)
    if not istable(data) then return end
    local track = M:GetTrack(data.trackId)
    if not track then return end
    local pos = data.pos and Vector(data.pos.x, data.pos.y, data.pos.z) or nil
    local radius = data.radius or M.Config.AreaRadius
    local known = M._areaKnown[data.sourceId]
    if known then
        known.pos = pos
        known.radius = radius
        if M._areaActiveId == data.sourceId and IsValid(M._areaChannel) then
            M:AreaRefreshActive()
            return
        end
    end

    M:AreaAddSource(data.sourceId, track, data.elapsed, pos, radius)
end)

netstream.Hook(M.Net.AreaStop, function(data)
    if not istable(data) then return end
    M:AreaRemoveSource(data.sourceId)
end)

M._radiusPreviewUntil = 0
M._vizRadius = M._areaRadius or M.Config.AreaRadius or 1500
local sphereMat = Material("models/wireframe")
VERSE.Hook.AddNS("Music", "PostDrawTranslucentRenderables", "VERSE::Music::AreaViz", function(_, _, sky)
    if sky then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    -- La sphère n'est visible QUE pendant l'ajustement du slider (3 s après le dernier mouvement).
    local timeLeft = M._radiusPreviewUntil - RealTime()
    if timeLeft <= 0 then return end
    local fadeAlpha = math.Clamp(timeLeft / 1, 0, 1)   -- fade-out sur la dernière seconde
    local pos, targetR
    if M._myAreaSourceId then
        local src = M._areaKnown[M._myAreaSourceId]
        pos    = (src and src.pos) or ply:GetPos()
        targetR = (src and src.radius) or M._areaRadius or M.Config.AreaRadius
    else
        pos    = ply:GetPos()
        targetR = M._areaRadius or M.Config.AreaRadius
    end

    M._vizRadius = Lerp(FrameTime() * 6, M._vizRadius or targetR, targetR)
    local radius = M._vizRadius
    render.SetColorModulation(124 / 255, 77 / 255, 255 / 255)
    render.SetBlend(fadeAlpha * 0.25)
    render.SetMaterial(sphereMat)
    render.DrawSphere(pos, radius, 32, 20, Color(124, 77, 255, 60))
    render.DrawSphere(pos, -radius, 32, 20, Color(124, 77, 255, 60))
    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)
end)