local SQ = VERSE.Squads
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local CP = VERSE.CharacterPreview
local PB = VERSE.Progress
local HUD_X = R:X(27)
local HUD_Y = R:Y(715)
local HDR_ICON_SZ = R:Y(26)
local HDR_ICON_X = R:X(6)
local HDR_TEXT_X = R:X(40)
local HDR_MIC_W = R:X(10)
local HDR_MIC_H = R:Y(15)
local HDR_VOICE_W = R:X(11)
local HDR_VOICE_H = R:Y(13)
local ICON_FLAGS = "noclamp anisotropic"
local HDR_H = R:Y(48)
local ROW_H = R:Y(50)
local AVATAR_SZ = R:Y(40)
local AVATAR_X = R:X(0)
local NAME_X = R:X(51)
local BAR_X = R:X(52)
local BAR_W = R:X(155)
local BAR_H = R:Y(10)
local HP_TEXT_X = R:X(212)
local ROW_NAME_DY = R:Y(4)
local ROW_BAR_DY = R:Y(24)
local ROW_MIC_W = R:X(10)
local ROW_MIC_H = R:Y(15)
local ROW_VOICE_W = R:X(11)
local ROW_VOICE_H = R:Y(13)
local ROW_ICON_GAP = R:X(8)
local COL_WHITE = color_white
local COL_ACTIVE = Color(80, 220, 120)
local COL_MUTED = Color(230, 70, 70)
local COL_IDLE = Color(210, 210, 220)
SQ._hudModels = SQ._hudModels or {}
SQ._hudHitboxes = SQ._hudHitboxes or {}

-- ─── Polices pré-résolues (Font:GetNamed fait table.concat + CRC à chaque appel) ─
local FONT_TITLE   = Font:GetNamed("Poppins", "Bold",     26)
local FONT_SQ_NAME = Font:GetNamed("Poppins", "Medium",   20)
local FONT_MIC     = Font:GetNamed("Poppins", "Bold",     22)
local FONT_MEMBER  = Font:GetNamed("Poppins", "SemiBold", 24)
local FONT_INITIAL = Font:GetNamed("Poppins", "Bold",     13)
local FONT_HP      = Font:GetNamed("Poppins", "Medium",   18, { italic = true })

-- ─── Couleurs constantes (évite d'allouer un Color() par frame) ──────────────
local COL_SHADOW       = Color(0,   0,   0,   150)
local COL_SQ_NAME      = Color(190, 190, 200, 255)
local COL_AVATAR_ME    = Color(124, 77,  255, 220)
local COL_AVATAR_OTHER = Color(55,  35,  95,  200)

-- ─── Cache des barres de progression (évite PB.Ensure + SetBg + SetFill chaque frame) ─
local _pbSetup = {}   -- [pbId] = true quand le bar est entièrement configuré

local function S(text, font, x, y, col, ha, va)
    draw.SimpleText(text, font, x + 1, y + 1, COL_SHADOW, ha, va)
    draw.SimpleText(text, font, x, y, col, ha, va)
end

local function FindPlayer(steamid)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:SteamID() == steamid then return ply end
    end
end

local function GetAppSig(ply)
    local app = CP:ReadAppearance(ply)
    return table.concat({
        tostring(app.bodyModel or ""),
        tostring(app.headModel or ""),
        tostring(app.bodyStyle or 0),
        tostring(app.headStyle or 0),
        tostring(app.hairStyle or 0),
        tostring(app.modelScale or 1),
        tostring(app.skinColor or ""),
        tostring(app.hairColor or ""),
        tostring(app.eyebrowStyle or 0),
        tostring(app.eyebrowColor or ""),
        tostring(app.irisStyle or 0),
        tostring(app.irisSize or 0),
        tostring(app.eyeColor or ""),
    }, "\31")
end

local function GetOrCreateModel(steamid, ply)
    if not IsValid(ply) then return nil end
    local sig = GetAppSig(ply)
    local cached = SQ._hudModels[steamid]
    if cached and IsValid(cached.panel) and cached.sig == sig then return cached.panel end
    if cached and IsValid(cached.panel) then cached.panel:Remove() end
    local app = CP:ReadAppearance(ply)
    local mdl = CP:CreateFromAppearance(nil, app, {
        fov = 30,
        idle = false
    })

    if not IsValid(mdl) then
        SQ._hudModels[steamid] = nil
        return nil
    end

    mdl:SetSize(AVATAR_SZ, AVATAR_SZ)
    mdl:SetPos(-9999, -9999)
    mdl:SetPaintedManually(true)
    mdl:SetMouseInputEnabled(false)
    mdl:SetKeyboardInputEnabled(false)
    local root = mdl.Entity
    if IsValid(root) then
        local boneId = root:LookupBone("ValveBiped.Bip01_Head1")
        if not boneId then
            for _, name in ipairs({"ValveBiped.Bip01_Head", "head", "Head", "bip_head"}) do
                boneId = root:LookupBone(name)
                if boneId then break end
            end
        end

        if boneId then
            root:SetupBones()
            local matrix = root:GetBoneMatrix(boneId)
            local headPos = (matrix and matrix:GetTranslation()) or root:GetBonePosition(boneId) or Vector(0, 0, 60)
            mdl:SetLookAt(headPos)
            mdl:SetCamPos(headPos + Vector(35, -5, 0))
        end
    end

    SQ._hudModels[steamid] = {
        panel = mdl,
        sig = sig
    }
    return mdl
end

local function DrawModelCircle(mdl, x, y, sz)
    local cx = x + sz * 0.5
    local cy = y + sz * 0.5
    Materials:DrawDuplicate(color_white, "hud_model_bg", x, y, sz, sz, "noclamp smooth")
    Materials:Draw(color_white, "hud_model_background", x, y, sz, sz, "noclamp smooth")
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
    RNDX.DrawCircle(cx, cy, sz, color_white)
    render.OverrideColorWriteEnable(false)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    mdl:SetPos(x, y)
    mdl:SetSize(sz, sz)
    mdl:PaintManual()
    render.SetStencilEnable(false)
    render.ClearStencil()
end

local function CleanupModels(activeSids)
    for sid, cached in pairs(SQ._hudModels) do
        if not activeSids[sid] then
            if IsValid(cached.panel) then cached.panel:Remove() end
            SQ._hudModels[sid] = nil
        end
    end
end

local function mouseInside(mx, my, bx, by, bw, bh)
    return mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
end

local function DrawHUD()
    local sq = SQ._state.squad
    if not sq or not SQ._state.hudEnabled then
        if not sq then
            for _, cached in pairs(SQ._hudModels) do
                if IsValid(cached.panel) then cached.panel:Remove() end
            end
            SQ._hudModels = {}
            _pbSetup = {}   -- on réinitialise le cache PB quand le squad se dissout
        end
        SQ._hudHitboxes = {}
        return
    end

    if not IsValid(LocalPlayer()) then return end
    local members = sq.members
    if not members or #members == 0 then return end
    local x = HUD_X
    local y = HUD_Y - HDR_H - #members * ROW_H
    local activeSids = {}
    local hitboxes = {}
    SQ._hudHitboxes = hitboxes
    Materials:Draw(COL_WHITE, "squad_icon", x + HDR_ICON_X, y + R:Y(3), HDR_ICON_SZ, HDR_ICON_SZ)
    S("Squad", FONT_TITLE, x + HDR_TEXT_X, y - R:Y(3), COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    S(tostring(sq.name or ""), FONT_SQ_NAME, x + HDR_TEXT_X, y + R:Y(18), COL_SQ_NAME, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    local ghX = x + R:X(170)
    local ghY = y + R:Y(6)
    local myMicOn = LocalPlayer():GetNWBool(SQ.NW.SquadMicOn, true)
    local myListenOn = LocalPlayer():GetNWBool(SQ.NW.SquadListen, true)
    local micCol = myMicOn and COL_ACTIVE or COL_MUTED
    local voiceCol = myListenOn and COL_ACTIVE or COL_MUTED
    Materials:Draw(micCol, "squad_micro_icon", ghX, ghY, HDR_MIC_W, HDR_MIC_H, ICON_FLAGS)
    S("M", FONT_MIC, ghX + HDR_MIC_W + R:X(4), ghY - R:Y(1), micCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    hitboxes[#hitboxes + 1] = {
        x = ghX,
        y = ghY,
        w = HDR_MIC_W + R:X(18),
        h = HDR_MIC_H,
        action = function() SQ:ToggleMyMic() end,
    }

    local ghX2 = ghX + R:X(44)
    Materials:Draw(voiceCol, "squad_voice_icon", ghX2, ghY + R:Y(1), HDR_VOICE_W, HDR_VOICE_H, ICON_FLAGS)
    S("L", FONT_MIC, ghX2 + HDR_VOICE_W + R:X(4), ghY - R:Y(1), voiceCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    hitboxes[#hitboxes + 1] = {
        x = ghX2,
        y = ghY,
        w = HDR_VOICE_W + R:X(18),
        h = HDR_VOICE_H,
        action = function() SQ:ToggleMyListen() end,
    }

    -- ── Construire la map steamid→joueur UNE SEULE FOIS (évite N×player.GetAll()) ──
    local playerMap = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then playerMap[p:SteamID()] = p end
    end

    local rowStartY = y + HDR_H
    for i, m in ipairs(members) do
        local ry = rowStartY + (i - 1) * ROW_H
        local sid = m.steamid
        activeSids[sid] = true
        local ply = playerMap[sid]
        local mdl = GetOrCreateModel(sid, ply)
        if IsValid(mdl) then
            DrawModelCircle(mdl, x + AVATAR_X, ry, AVATAR_SZ)
        else
            local isMe = sid == LocalPlayer():SteamID()
            draw.RoundedBox(AVATAR_SZ * 0.5, x + AVATAR_X, ry, AVATAR_SZ, AVATAR_SZ, isMe and COL_AVATAR_ME or COL_AVATAR_OTHER)
            draw.SimpleText(string.upper(string.sub(m.name or "?", 1, 1)), FONT_INITIAL, x + AVATAR_X + AVATAR_SZ * 0.5, ry + AVATAR_SZ * 0.5, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        S(m.name or "", FONT_MEMBER, x + NAME_X, ry + ROW_NAME_DY, COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local hp = IsValid(ply) and math.max(0, ply:Health()) or 0
        local maxhp = IsValid(ply) and math.max(1, ply:GetMaxHealth()) or 100
        local barX = x + BAR_X
        local barY = ry + ROW_BAR_DY
        local pbId = "squad_hp_" .. sid
        -- ── Setup de la barre : une seule fois par pbId (pas chaque frame) ──────
        if not _pbSetup[pbId] then
            PB.Ensure(pbId, {
                x = barX,
                y = barY,
                w = BAR_W,
                h = BAR_H,
                round = R:Y(3),
                mode = "linear",
                dir = "lr",
            })
            PB.SetBgRect(pbId, barX, barY, BAR_W, BAR_H)
            PB.SetFillRect(pbId, barX, barY, BAR_W, BAR_H)
            PB.SetBackground(pbId, "material", {
                material = "squad_hud_health_bg",
                uv = true,
                flags = "noclamp smooth"
            })
            PB.SetFill(pbId, "material", {
                material = "squad_hud_health_bar",
                uv = true,
                flags = "noclamp smooth"
            })
            PB.SetSmooth(pbId, true, 3)
            _pbSetup[pbId] = true
        end
        PB.SetValue(pbId, hp / maxhp)
        PB.Draw(pbId)
        local hpStr = string.format("%d/%d", hp, maxhp)
        S(hpStr, FONT_HP, x + HP_TEXT_X, barY - R:Y(4), COL_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local hpTextW = VERSE.GetTextSize(hpStr, FONT_HP)
        local iconX = x + HP_TEXT_X + hpTextW + R:X(10)
        local micY = ry + (ROW_H - ROW_MIC_H) * 0.5
        local voiceY = ry + (ROW_H - ROW_VOICE_H) * 0.5
        local isMe = sid == LocalPlayer():SteamID()

        local micOn = SQ:IsMicOn(sid)
        local listenOn = SQ:IsListenOn(sid)
        local micCol2 = micOn and COL_ACTIVE or COL_MUTED
        local voiceCol2 = listenOn and COL_ACTIVE or COL_MUTED

        Materials:Draw(micCol2, "squad_micro_icon", iconX, micY, ROW_MIC_W, ROW_MIC_H, ICON_FLAGS)
        if isMe then
            hitboxes[#hitboxes + 1] = {
                x = iconX,
                y = micY,
                w = ROW_MIC_W,
                h = ROW_MIC_H,
                action = function() SQ:ToggleMyMic() end,
            }
        end

        local voiceX = iconX + ROW_MIC_W + ROW_ICON_GAP
        Materials:Draw(voiceCol2, "squad_voice_icon", voiceX, voiceY, ROW_VOICE_W, ROW_VOICE_H, ICON_FLAGS)
        if isMe then
            hitboxes[#hitboxes + 1] = {
                x = voiceX,
                y = voiceY,
                w = ROW_VOICE_W,
                h = ROW_VOICE_H,
                action = function() SQ:ToggleMyListen() end,
            }
        end
    end

    -- Nettoyer le cache PB pour les membres qui ont quitté le squad
    for pbId in pairs(_pbSetup) do
        local sid = string.match(pbId, "^squad_hp_(.+)$")
        if sid and not activeSids[sid] then
            _pbSetup[pbId] = nil
        end
    end

    CleanupModels(activeSids)
end

VERSE.Hook.AddNS("Squad", "HUDPaint", "VERSE::HUDPaint::SquadHUD", DrawHUD)

if IsValid(SQ._hudClickOverlay) then
    SQ._hudClickOverlay:Remove()
    SQ._hudClickOverlay = nil
end

local function tryHudClick()
    if not (SQ._state.squad and SQ._state.hudEnabled) then return end
    local mx, my = gui.MousePos()
    if mx == 0 and my == 0 then return end
    for _, hit in ipairs(SQ._hudHitboxes or {}) do
        if mouseInside(mx, my, hit.x, hit.y, hit.w, hit.h) then
            hit.action()
            return true
        end
    end
end

VERSE.Hook.AddNS("Squad", "GUIMousePressed", "VERSE::GUIMousePressed::SquadHUD", function(code, aimVec)
    if code ~= MOUSE_LEFT then return end
    if tryHudClick() then return true end
end)

VERSE.Hook.AddNS("Squad", "VGUIMousePressed", "VERSE::VGUIMousePressed::SquadHUD", function(pnl, code)
    if code ~= MOUSE_LEFT then return end
    tryHudClick()
end)