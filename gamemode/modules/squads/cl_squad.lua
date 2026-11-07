local SQ = VERSE.Squads
local R = VERSE.Responsive
local Font = VERSE.Fonts

-- ─── Couleurs Paint pré-allouées ─────────────────────────────────────────────
local _SQ_COL_POPUP_BG      = Color(15,  7,   38,  235)
local _SQ_COL_POPUP_OUT     = Color(124, 77,  255, 255)
local _SQ_COL_SQUAD_NAME    = Color(200, 175, 255, 255)
SQ._frame = SQ._frame or nil
SQ._content = SQ._content or nil
SQ._invitePopup = SQ._invitePopup or nil
SQ._ui = SQ._ui or {}
SQ._nearbyList = SQ._nearbyList or {}
SQ._nearbyListCallback = SQ._nearbyListCallback or nil
SQ._state = SQ._state or {
    squad = nil,
    hudEnabled = true,
    squadMuted = false,
    mutedMics = {},
    mutedVoice = {},
    globalMicMuted = false,
    globalVoiceMuted = false,
}

VERSE.Hook.AddNS("Squad", "InitPostEntity", "VERSE::InitPostEntity::SquadMaterials", function()
    local M = VERSE.Materials
    M:SetAlias("squad_icon", "verse/squad/squad_icon")
    M:SetAlias("squad_leader_icon", "verse/squad/squad_leader_icon")
    M:SetAlias("squad_leave_icon", "verse/squad/leave_icon")
    M:SetAlias("squad_hud_health_bg", "verse/squad/hud_health_background")
    M:SetAlias("squad_hud_health_bar", "verse/squad/hud_health_bar")
    M:SetAlias("squad_micro_icon", "verse/squad/micro_icon")
    M:SetAlias("squad_voice_icon", "verse/squad/voice_icon")
end)

local function findPly(sid)
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:SteamID() == sid then return p end
    end
end

function SQ:IsMicOn(steamid)
    local p = findPly(steamid)
    if not IsValid(p) then return true end
    return p:GetNWBool(SQ.NW.SquadMicOn, true)
end

function SQ:IsListenOn(steamid)
    local p = findPly(steamid)
    if not IsValid(p) then return true end
    return p:GetNWBool(SQ.NW.SquadListen, true)
end

function SQ:ToggleMyMic()
    netstream.Start(SQ.Net.ToggleMic)
end

function SQ:ToggleMyListen()
    netstream.Start(SQ.Net.ToggleListen)
end

function SQ:IsLeader()
    local sq = self._state.squad
    return sq ~= nil and sq.leader == LocalPlayer():SteamID()
end

function SQ:RebuildUI()
    if not IsValid(self._content) then return end
    self._content:Clear()
    if self._state.squad then
        self._ui.buildManagePanel(self._content)
    else
        self._ui.buildRegisterPanel(self._content)
    end
end

function SQ:OpenUI()
    if IsValid(self._frame) then
        self._frame:MakePopup()
        self._frame:RequestFocus()
        return
    end

    local frame = vgui.Create("MantleFrame")
    frame:SetSize(R:XY(1920, 1080))
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(false)
    frame:LiteMode()
    frame:SetAlphaBackground(false)
    frame:SetClosable(true)
    frame:DisableCloseBtn()
    frame.allowEscClose = true
    frame.Paint = function() end
    frame.OnRemove = function()
        SQ._frame = nil
        SQ._content = nil
    end

    local content = vgui.Create("DPanel", frame)
    content:SetSize(R:XY(1920, 1080))
    content:SetPos(0, 0)
    content.Paint = function() end
    self._frame = frame
    self._content = content
    self:RebuildUI()
end

function SQ:CloseUI()
    if IsValid(self._frame) then self._frame:Close() end
    self._frame = nil
    self._content = nil
end

function SQ:ToggleUI()
    if IsValid(self._frame) then
        self:CloseUI()
    else
        self:OpenUI()
    end
end

function SQ:ShowInvitePopup(data)
    if IsValid(self._invitePopup) then self._invitePopup:Remove() end
    local scrW = ScrW()
    local pw, ph = R:X(440), R:Y(130)
    local p = vgui.Create("DPanel")
    p:SetPos(scrW * 0.5 - pw * 0.5, R:Y(70))
    p:SetSize(pw, ph)
    p:SetDrawOnTop(true)
    p:SetMouseInputEnabled(true)
    self._invitePopup = p
    gui.EnableScreenClicker(true)

    local function closePopup()
        if SQ._invitePopup == p then SQ._invitePopup = nil end
        if IsValid(p) then p:Remove() end
        if not IsValid(SQ._frame) then gui.EnableScreenClicker(false) end
    end

    p.OnRemove = function()
        if SQ._invitePopup == p then SQ._invitePopup = nil end
        if not IsValid(SQ._frame) then gui.EnableScreenClicker(false) end
    end

    local _popupHeaderFont = Font:GetNamed("Poppins", "SemiBold", 16)
    local _popupNameFont   = Font:GetNamed("Poppins", "Bold",     22)
    p.Paint = function(_, w, h)
        RNDX.Draw(R:Y(12), 0, 0, w, h, _SQ_COL_POPUP_BG)
        RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, _SQ_COL_POPUP_OUT, 2)
        draw.SimpleText(data.fromName .. " vous invite dans :", _popupHeaderFont, w * 0.5, R:Y(14), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(data.squadName), _popupNameFont, w * 0.5, R:Y(36), _SQ_COL_SQUAD_NAME, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local btnY = R:Y(80)
    local btnH = R:Y(38)
    local btnW = R:X(185)
    local _makeBtnFont = Font:GetNamed("Poppins", "SemiBold", 16)
    local function makeBtn(x, label, bg, bgHov, action)
        local btn = vgui.Create("DButton", p)
        btn:SetPos(x, btnY)
        btn:SetSize(btnW, btnH)
        btn:SetText("")
        btn.Paint = function(s, w, h)
            RNDX.Draw(R:Y(8), 0, 0, w, h, s:IsHovered() and bgHov or bg)
            draw.SimpleText(label, _makeBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function()
            action()
            closePopup()
        end
    end

    makeBtn(R:X(20), "Accepter", Color(50, 150, 60, 210), Color(70, 190, 80, 240), function() netstream.Start(SQ.Net.InviteRes, true) end)
    makeBtn(R:X(235), "Refuser", Color(150, 50, 50, 210), Color(190, 65, 65, 240), function() netstream.Start(SQ.Net.InviteRes, false) end)
    timer.Simple(SQ.Config.InviteTimeout, closePopup)
end

netstream.Hook(SQ.Net.Sync, function(data)
    SQ._state.squad = data
    if IsValid(SQ._frame) then SQ:RebuildUI() end
end)

netstream.Hook(SQ.Net.NearbyList, function(list)
    SQ._nearbyList = list or {}
    if isfunction(SQ._nearbyListCallback) then
        SQ._nearbyListCallback(SQ._nearbyList)
        SQ._nearbyListCallback = nil
    end
end)

netstream.Hook(SQ.Net.InviteNotify, function(data)
    if not data then
        if IsValid(SQ._invitePopup) then SQ._invitePopup:Remove() end
        SQ._invitePopup = nil
        return
    end

    SQ:ShowInvitePopup(data)
end)

VERSE.Hook.AddNS("Squad", "PlayerCanHearPlayersVoice", "VERSE::Squad::ClientMute", function(listener, speaker)
    if listener ~= LocalPlayer() then return end
    if not IsValid(speaker) or not speaker:IsPlayer() then return end

    local sq = SQ._state.squad
    if sq then
        local spSid = speaker:SteamID()
        local isSquad = false
        for _, m in ipairs(sq.members or {}) do
            local sid = type(m) == "table" and m.steamid or m
            if sid == spSid then isSquad = true break end
        end
        if isSquad then
            if not speaker:IsSquadMicOn() then return false, false end
            if not listener:IsSquadListenOn() then return false, false end
        end
        if SQ._state.squadMuted and isSquad then return false, false end
    end
end)

VERSE.Commands.Add("verse_squad", function() SQ:ToggleUI() end, nil, "client")
VERSE.Commands.Add("verse_squad_toggle_mic", function()
    if not SQ._state.squad then return end
    SQ:ToggleMyMic()
end, nil, "client")
VERSE.Commands.Add("verse_squad_toggle_listen", function()
    if not SQ._state.squad then return end
    SQ:ToggleMyListen()
end, nil, "client")