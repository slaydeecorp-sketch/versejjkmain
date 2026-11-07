local SQ = VERSE.Squads
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local _ui = SQ._ui
local PW = R:X(1371)
local PH = R:Y(802)
local COL_BG = Color(15, 7, 38, 184)
local COL_BORDER = Color(50, 50, 50, 220)
local COL_PURPLE = Color(124, 77, 255)
local COL_WHITE = color_white
local COL_GRAY = Color(181, 181, 181)
local COL_MUTED = Color(125, 125, 125)
local COL_SLOT = Color(255, 255, 255, 26)

-- ─── Couleurs pré-allouées pour Squad UI (évite Color() par frame) ────────────
local _SQ_COL_TOGGLE_ON_HOV   = Color(100, 65,  200, 230)
local _SQ_COL_TOGGLE_OFF_HOV  = Color(70,  70,  100, 200)
local _SQ_COL_TOGGLE_ON_NORM  = Color(80,  50,  160, 200)
local _SQ_COL_TOGGLE_OFF_NORM = Color(50,  50,  70,  160)
local _SQ_COL_TOGGLE_BORD_OFF = Color(100, 100, 120, 255)
local _SQ_COL_SLOT_HOV_BG     = Color(255, 255, 255, 30)
local _SQ_COL_SLOT_HOV_BORD   = Color(185, 132, 255, 120)
local _SQ_COL_ENTRY_BORD      = Color(255, 255, 255, 50)
local _SQ_COL_ENTRY_PH        = Color(120, 120, 120, 255)
local _SQ_COL_ENTRY_HL        = Color(124, 77,  255, 80)
local _SQ_COL_ENTRY_TXT_EX    = Color(120, 120, 120, 255)
local _SQ_COL_LIST_BTN_HOV    = Color(255, 255, 255, 140)
local _SQ_COL_LIST_BTN_NORM   = Color(255, 255, 255, 102)
local _SQ_COL_MEMBER_HOV      = Color(80,  50,  140, 160)
local _SQ_COL_LEADER_BG       = Color(15,  7,   38,  240)
local _SQ_COL_CARD_LDR_BG     = Color(255, 255, 255, 28)
local _SQ_COL_CARD_LDR_OUT    = Color(150, 100, 255, 100)
local _SQ_COL_CARD_NORM_OUT   = Color(255, 255, 255, 35)
local _SQ_COL_CARD_ICON_LDR   = Color(200, 200, 200, 255)
local _SQ_COL_CARD_ICON_NORM  = Color(200, 200, 200, 140)
local _SQ_COL_KICK_HOV        = Color(220, 60,  60,  235)
local _SQ_COL_KICK_NORM       = Color(180, 50,  50,  180)
local _SQ_COL_EMPTY_HOV       = Color(255, 255, 255, 16)
local _SQ_COL_EMPTY_CIRC      = Color(200, 200, 200, 120)
local _SQ_COL_LEAVE_HOV       = Color(255, 100, 100, 210)
local _SQ_COL_LEAVE_NORM      = Color(255, 126, 126, 128)
-- ─────────────────────────────────────────────────────────────────────────────
local function PanelRoot(parent)
    local p = vgui.Create("DPanel", parent)
    p:SetSize(PW, PH)
    p:SetPos(ScrW() * 0.5 - PW * 0.5, ScrH() * 0.5 - PH * 0.5)
    p.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(15)):Blur(0.75):Color(COL_BG):Shadow(40, 60):Draw()
        RNDX.Draw(R:Y(15), 0, 0, w, h, COL_BG)
        local bx, by = R:X(29), R:Y(32)
        RNDX.DrawOutlined(R:Y(15), bx, by, w - bx * 2, h - by - R:Y(8), COL_BORDER, R:Y(3))
    end
    return p
end

local function ToggleBtn(parent, x, y, w, h, lblOn, lblOff, isOn, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn._on = isOn
    btn.Paint = function(s, bw, bh)
        local on = s._on
        local hov = s:IsHovered()
        RNDX.Draw(R:Y(8), 0, 0, bw, bh, hov and (on and _SQ_COL_TOGGLE_ON_HOV or _SQ_COL_TOGGLE_OFF_HOV) or (on and _SQ_COL_TOGGLE_ON_NORM or _SQ_COL_TOGGLE_OFF_NORM))
        RNDX.DrawOutlined(R:Y(8), 0, 0, bw, bh, on and COL_PURPLE or _SQ_COL_TOGGLE_BORD_OFF, 1)
        draw.SimpleText(on and lblOn or lblOff, Font:GetNamed("Poppins", "SemiBold", 13), bw * 0.5, bh * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function(s)
        s._on = not s._on
        if onClick then onClick(s._on) end
    end
    return btn
end

function _ui.buildRegisterPanel(parent)
    local p = PanelRoot(parent)
    p.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(15)):Blur(0.75):Color(COL_BG):Shadow(40, 60):Draw()
        RNDX.Draw(R:Y(15), 0, 0, w, h, COL_BG)
        local bx, by = R:X(29), R:Y(32)
        RNDX.DrawOutlined(R:Y(15), bx, by, w - bx * 2, h - by - R:Y(33), COL_BORDER, R:Y(3))
        draw.SimpleText("CRÉATION D'ESCOUADE", Font:GetNamed("Poppins", "Bold", 36), w * 0.5, R:Y(322), COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("Cliquez sur le bouton ci-dessous pour créer votre squad...", Font:GetNamed("Poppins", "Medium", 15), w * 0.5, R:Y(362), COL_GRAY, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local btnW, btnH = R:X(418), R:Y(68)
    local btn = vgui.Create("DButton", p)
    btn:SetPos(R:X(477), R:Y(409))
    btn:SetSize(btnW, btnH)
    btn:SetText("")
    btn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        RNDX.Draw(R:Y(8), 0, 0, w, h, hov and _SQ_COL_SLOT_HOV_BG or COL_SLOT)
        if hov then RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, _SQ_COL_SLOT_HOV_BORD, 1) end
        draw.SimpleText("Créer mon escouade", Font:GetNamed("Poppins", "Medium", 20), w * 0.5, h * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function() netstream.Start(SQ.Net.Create) end
end

function _ui.buildManagePanel(parent)
    local sq = SQ._state.squad
    if not sq then return end
    local isLeader = SQ:IsLeader()
    local p = PanelRoot(parent)
    local leaderName = ""
    for _, m in ipairs(sq.members) do
        if m.steamid == sq.leader then
            leaderName = m.name
            break
        end
    end

    p.Paint = function(_, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:Y(15)):Blur(0.75):Color(COL_BG):Shadow(40, 60):Draw()
        RNDX.Draw(R:Y(15), 0, 0, w, h, COL_BG)
        local bx, by = R:X(29), R:Y(32)
        RNDX.DrawOutlined(R:Y(15), bx, by, w - bx * 2, h - by - R:Y(33), COL_BORDER, R:Y(3))
        draw.SimpleText("ESCOUADE", Font:GetNamed("Poppins", "Bold", 36), w * 0.5, R:Y(104), COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("Créée par " .. leaderName, Font:GetNamed("Poppins", "Medium", 15), w * 0.5, R:Y(142), COL_GRAY, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        if isLeader then draw.SimpleText("Changer le nom de l'escouade", Font:GetNamed("Poppins", "SemiBold", 24), R:X(128), R:Y(307), COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
        local membCx = R:X(674)
        draw.SimpleText("Membres", Font:GetNamed("Poppins", "SemiBold", 18), membCx, R:Y(374), COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(#sq.members) .. "/" .. tostring(SQ.Config.MaxMembers), Font:GetNamed("Poppins", "SemiBold", 24), membCx, R:Y(407), COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local iconPnl = vgui.Create("DPanel", p)
    iconPnl:SetPos(R:X(71), R:Y(65))
    iconPnl:SetSize(R:X(56), R:Y(62))
    iconPnl.Paint = function(_, w, h) Materials:Draw(color_white, "squad_icon", 0, 0, w, h) end
    if isLeader then
        local entry = vgui.Create("MantleEntry", p)
        entry:SetPos(R:X(138), R:Y(367))
        entry:SetSize(R:X(353), R:Y(57))
        entry:SetPlaceholder(sq.name)
        entry:SetFonts(Font:GetNamed("Poppins", "Medium", 17), Font:GetNamed("Poppins", "Medium", 17))
        entry:SetTextColor(COL_WHITE)
        entry:SetPlaceholderColor(_SQ_COL_ENTRY_PH)
        entry:SetHighlightColor(_SQ_COL_ENTRY_HL)
        entry:SetCursorColor(COL_WHITE)
        entry.textEntry.Paint = function(s, w, h)
            RNDX.Draw(R:Y(8), 0, 0, w, h, COL_SLOT)
            RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, _SQ_COL_ENTRY_BORD, 1)
            local val = entry:GetValue() or ""
            if val == "" and not s:HasFocus() then
                draw.SimpleText(sq.name, Font:GetNamed("Poppins", "Medium", 17), R:X(23), h * 0.5, _SQ_COL_ENTRY_TXT_EX, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                return true
            end

            s:DrawTextEntryText(COL_WHITE, _SQ_COL_ENTRY_HL, COL_WHITE)
            return true
        end

        local function doRename()
            local n = (entry:GetValue() or ""):Trim()
            if n ~= "" then netstream.Start(SQ.Net.Rename, n) end
        end

        entry:SetOnEnter(doRename)
        local vBtn = vgui.Create("DButton", p)
        vBtn:SetPos(R:X(185), R:Y(449))
        vBtn:SetSize(R:X(260), R:Y(42))
        vBtn:SetText("")
        local _vBtnFont = Font:GetNamed("Poppins", "Medium", 16)
        vBtn.Paint = function(s, w, h)
            RNDX.Draw(R:Y(8), 0, 0, w, h, s:IsHovered() and _SQ_COL_LIST_BTN_HOV or _SQ_COL_LIST_BTN_NORM)
            draw.SimpleText("Valider", _vBtnFont, w * 0.5, h * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        vBtn.DoClick = doRename
    end

    local SLOT_X = R:X(856)
    local SLOT_W = R:X(353)
    local SLOT_H = R:Y(57)
    local SLOT_TOPS = {R:Y(234), R:Y(303), R:Y(372), R:Y(441), R:Y(510)}
    local _dropSlot = -1
    local _dropPanel = nil
    local function CloseDropdown()
        if IsValid(_dropPanel) then _dropPanel:Remove() end
        _dropPanel = nil
        _dropSlot = -1
        SQ._nearbyListCallback = nil
    end

    local function FillDropdown(list, dp)
        if not IsValid(dp) then return end
        dp:Clear()
        if #list == 0 then
            dp:SetSize(SLOT_W, R:Y(44))
            local lbl = vgui.Create("DLabel", dp)
            lbl:SetPos(R:X(16), 0)
            lbl:SetSize(SLOT_W - R:X(16), R:Y(44))
            lbl:SetFont(Font:GetNamed("Poppins", "Regular", 15))
            lbl:SetText("Aucun joueur à proximité.")
            lbl:SetTextColor(COL_MUTED)
            return
        end

        local rH, rG = R:Y(40), R:Y(4)
        dp:SetSize(SLOT_W, #list * (rH + rG) + R:Y(8))
        for i, data in ipairs(list) do
            local ry = R:Y(4) + (i - 1) * (rH + rG)
            local row = vgui.Create("DButton", dp)
            row:SetPos(R:X(4), ry)
            row:SetSize(SLOT_W - R:X(8), rH)
            row:SetText("")
            local d = data
            local _rowFont = Font:GetNamed("Poppins", "Medium", 15)
            row.Paint = function(s, w, h)
                if s:IsHovered() then RNDX.Draw(R:Y(6), 0, 0, w, h, _SQ_COL_MEMBER_HOV) end
                draw.SimpleText(d.name, _rowFont, R:X(16), h * 0.5, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            row.DoClick = function()
                netstream.Start(SQ.Net.Invite, d.steamid)
                CloseDropdown()
            end
        end
    end

    local function OpenDropdown(sIdx, absy)
        CloseDropdown()
        _dropSlot = sIdx
        local dp = vgui.Create("DPanel", p)
        dp:SetPos(SLOT_X, absy)
        dp:SetSize(SLOT_W, R:Y(44))
        dp:SetDrawOnTop(true)
        dp.Paint = function(_, w, h)
            RNDX.Draw(R:Y(8), 0, 0, w, h, _SQ_COL_LEADER_BG)
            RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, COL_PURPLE, 1)
        end

        _dropPanel = dp
        local ld = vgui.Create("DLabel", dp)
        ld:SetPos(R:X(16), 0)
        ld:SetSize(SLOT_W - R:X(16), R:Y(44))
        ld:SetFont(Font:GetNamed("Poppins", "Regular", 15))
        ld:SetText("Chargement...")
        ld:SetTextColor(COL_MUTED)
        SQ._nearbyListCallback = function(list)
            if IsValid(ld) then ld:Remove() end
            FillDropdown(list, dp)
        end

        netstream.Start(SQ.Net.NearbyReq)
    end

    local mySid = LocalPlayer():SteamID()
    for slot = 1, SQ.Config.MaxMembers do
        local sy = SLOT_TOPS[slot]
        local member = sq.members[slot]
        if member then
            local isMe = member.steamid == mySid
            local isLdr = member.isLeader
            local sp = vgui.Create("DPanel", p)
            sp:SetPos(SLOT_X, sy)
            sp:SetSize(SLOT_W, SLOT_H)
            local md = member
            local _memberFont = Font:GetNamed("Poppins", "Medium", 18)
            sp.Paint = function(_, w, h)
                RNDX.Draw(R:Y(8), 0, 0, w, h, isLdr and _SQ_COL_CARD_LDR_BG or COL_SLOT)
                RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, isLdr and _SQ_COL_CARD_LDR_OUT or _SQ_COL_CARD_NORM_OUT, 1)
                local iSz = R:Y(22)
                local iAlias = isLdr and "squad_leader_icon" or "squad_icon"
                Materials:Draw(isLdr and _SQ_COL_CARD_ICON_LDR or _SQ_COL_CARD_ICON_NORM, iAlias, R:X(20), h * 0.5 - iSz * 0.5, iSz, iSz)
                draw.SimpleText(md.name, _memberFont, R:X(58), h * 0.5, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            if isLeader and not isMe then
                local kb = vgui.Create("DButton", sp)
                kb:SetPos(SLOT_W - R:X(40), SLOT_H * 0.5 - R:Y(12))
                kb:SetSize(R:X(24), R:Y(24))
                kb:SetText("")
                local kd = member
                local _kickFont = Font:GetNamed("Poppins", "Bold", 16)
                kb.Paint = function(s, w, h)
                    RNDX.Draw(R:Y(5), 0, 0, w, h, s:IsHovered() and _SQ_COL_KICK_HOV or _SQ_COL_KICK_NORM)
                    draw.SimpleText("×", _kickFont, w * 0.5, h * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                kb.DoClick = function() netstream.Start(SQ.Net.Kick, kd.steamid) end
            end
        else
            local sb = vgui.Create("DButton", p)
            sb:SetPos(SLOT_X, sy)
            sb:SetSize(SLOT_W, SLOT_H)
            sb:SetText("")
            local sIdx = slot
            local _slotMedFont = Font:GetNamed("Poppins", "Medium", 18)
            local _slotPlusFont = Font:GetNamed("Poppins", "Bold", 22)
            sb.Paint = function(s, w, h)
                RNDX.Draw(R:Y(8), 0, 0, w, h, s:IsHovered() and _SQ_COL_EMPTY_HOV or COL_SLOT)
                RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, COL_SLOT, 1)
                draw.SimpleText("Le slot est disponible.", _slotMedFont, R:X(20), h * 0.5, COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local cSz = R:Y(28)
                local cX = R:X(308)
                local cCx = cX + cSz * 0.5
                local cCy = h * 0.5
                RNDX.DrawOutlined(cSz * 0.5, cX, cCy - cSz * 0.5, cSz, cSz, _SQ_COL_EMPTY_CIRC, 1)
                local _, plusH = VERSE.GetTextSize("+", _slotPlusFont)
                draw.SimpleText("+", _slotPlusFont, cCx - R:X(1), cCy - plusH * 0.5, COL_MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end

            sb.DoClick = function()
                if not isLeader then return end
                if _dropSlot == sIdx then
                    CloseDropdown()
                    return
                end

                local _, wy = sb:LocalToScreen(0, SLOT_H)
                local _, py = p:LocalToScreen(0, 0)
                OpenDropdown(sIdx, wy - py)
            end
        end
    end

    p.OnMousePressed = function() CloseDropdown() end
    local tW, tH = R:X(156), R:Y(40)
    local tGap = R:X(14)
    local nBtns = isLeader and 4 or 3
    local tStart = PW * 0.5 - (tW * nBtns + tGap * (nBtns - 1)) * 0.5
    local tY = R:Y(590)
    local col = 0
    local function BX()
        local x = tStart + col * (tW + tGap)
        col = col + 1
        return x
    end

    if isLeader then ToggleBtn(p, BX(), tY, tW, tH, "Degats ON", "Degats OFF", sq.damageEnabled, function() netstream.Start(SQ.Net.ToggleDmg) end) end
    local micBtn = ToggleBtn(p, BX(), tY, tW, tH, "Micro ON", "Micro OFF", LocalPlayer():GetNWBool(SQ.NW.SquadMicOn, true), function() netstream.Start(SQ.Net.ToggleMic) end)
    micBtn.Think = function(s) s._on = LocalPlayer():GetNWBool(SQ.NW.SquadMicOn, true) end
    local lBtn = ToggleBtn(p, BX(), tY, tW, tH, "Écoute ON", "Écoute OFF", LocalPlayer():GetNWBool(SQ.NW.SquadListen, true), function() netstream.Start(SQ.Net.ToggleListen) end)
    lBtn.Think = function(s) s._on = LocalPlayer():GetNWBool(SQ.NW.SquadListen, true) end
    ToggleBtn(p, BX(), tY, tW, tH, "HUD visible", "HUD caché", SQ._state.hudEnabled, function(on) SQ._state.hudEnabled = on end)
    local qBtn = vgui.Create("DButton", p)
    qBtn:SetPos(R:X(530), R:Y(659))
    qBtn:SetSize(R:X(311), R:Y(58))
    qBtn:SetText("")
    local _qBtnFont = Font:GetNamed("Poppins", "SemiBold", 18)
    qBtn.Paint = function(s, w, h)
        RNDX.Draw(R:Y(8), 0, 0, w, h, s:IsHovered() and _SQ_COL_LEAVE_HOV or _SQ_COL_LEAVE_NORM)
        local iSz = R:Y(22)
        local text = "Quitter l'escouade"
        local totalW = iSz + R:X(10) + VERSE.GetTextSize(text, _qBtnFont)
        local startX = w * 0.5 - totalW * 0.5
        Materials:Draw(color_white, "squad_leave_icon", startX, h * 0.5 - iSz * 0.5, iSz, iSz)
        draw.SimpleText(text, _qBtnFont, startX + iSz + R:X(10), h * 0.5, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    qBtn.DoClick = function()
        netstream.Start(SQ.Net.Leave)
        SQ:CloseUI()
    end
end