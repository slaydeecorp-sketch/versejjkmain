local HUD = VERSE.HUD
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local PB = VERSE.Progress
local CP = VERSE.CharacterPreview
local health_id = "health_progress_bar"
local mana_id = "mana_progress_bar"
local level_id = "leve_progress_bar"
local _hudModelPanel = nil
local _hudModelSig = ""

-- ─── Cache FPS ────────────────────────────────────────────────────────────────
-- Tous les appels R:X/R:Y, Font:GetNamed, PB.Ensure/Set* sont faits UNE SEULE FOIS
-- dans initHud(), puis recalculés uniquement si la résolution change.
-- → Zéro allocation de table ni appel de police à chaque frame HUDPaint.
local _hudInited  = false
local _hudScrW, _hudScrH = 0, 0
local F_VALUE, F_LEVEL, F_NAME = nil, nil, nil
local COL_HEALTH  = Color(255, 255, 255)
local COL_MANA    = Color(255, 255, 255)
local COL_BG      = Color(255, 255, 255, 100)
local COL_LOGO    = Color(255, 255, 255, 102)
-- Tables de positions/tailles (H = health, M = mana, L = level, HUD = divers).
local _H, _M, _L, _HUD = {}, {}, {}, {}

local function initHud()
    local scrW, scrH = ScrW(), ScrH()
    if _hudInited and _hudScrW == scrW and _hudScrH == scrH then return end
    _hudInited = true;  _hudScrW = scrW;  _hudScrH = scrH

    F_VALUE = Font:GetNamed("Poppins", "Bold",       25)
    F_LEVEL = Font:GetNamed("Poppins", "Bold",       30)
    F_NAME  = Font:GetNamed("Poppins", "ItalicBold", 35)

    -- Health
    _H.x      = R:X(135);    _H.y      = R:Y(1080 - 75 - 72)
    _H.bgW    = R:X(390);    _H.bgH    = R:Y(75)
    _H.fillW  = R:X(340);    _H.fillH  = R:Y(25)
    _H.offX   = math.floor((_H.bgW - _H.fillW) * 0.5) - R:X(5)
    _H.offY   = math.floor((_H.bgH - _H.fillH) * 0.5)
    _H.rightX  = R:X(475);  _H.centerY = R:Y(1080 - 109)
    _H.iconW   = R:X(12);   _H.iconH   = R:Y(10)
    _H.spacing = R:X(6);    _H.iconBaseY = _H.centerY - _H.iconH * 0.5 - R:Y(1)
    PB.Ensure(health_id, { x=_H.x, y=_H.y, w=_H.bgW, h=_H.bgH, round=0, mode="linear", dir="lr" })
    PB.SetBgRect(health_id,   _H.x, _H.y, _H.bgW, _H.bgH)
    PB.SetFillRect(health_id, _H.x + _H.offX, _H.y + _H.offY, _H.fillW, _H.fillH)
    PB.SetBackground(health_id, "material", { material="hud_health_background", color=Color(255, 255, 255), uv=true, flags="noclamp smooth" })
    PB.SetFill(health_id,       "material", { material="hud_health_bar",         color=Color(255, 255, 255), uv=true, flags="noclamp smooth" })
    PB.SetSmooth(health_id, true, 3)

    -- Mana
    _M.x      = R:X(135);    _M.y      = R:Y(1080 - 75 - 37)
    _M.bgW    = R:X(390);    _M.bgH    = R:Y(75)
    _M.fillW  = R:X(340);    _M.fillH  = R:Y(25)
    _M.offX   = math.floor((_M.bgW - _M.fillW) * 0.5) - R:X(5)
    _M.offY   = math.floor((_M.bgH - _M.fillH) * 0.5)
    _M.rightX  = R:X(475);  _M.centerY = R:Y(1080 - 74)
    _M.iconW   = R:X(12);   _M.iconH   = R:Y(13)
    _M.spacing = R:X(6);    _M.iconBaseY = _M.centerY - _M.iconH * 0.5 - R:Y(1)
    PB.Ensure(mana_id, { x=_M.x, y=_M.y, w=_M.bgW, h=_M.bgH, round=0, mode="linear", dir="lr" })
    PB.SetBgRect(mana_id,   _M.x, _M.y, _M.bgW, _M.bgH)
    PB.SetFillRect(mana_id, _M.x + _M.offX, _M.y + _M.offY, _M.fillW, _M.fillH)
    PB.SetBackground(mana_id, "material", { material="hud_mana_background", color=Color(255, 255, 255), uv=true, flags="noclamp smooth" })
    PB.SetFill(mana_id,       "material", { material="hud_mana_bar",         color=Color(255, 255, 255), uv=true, flags="noclamp smooth" })
    PB.SetSmooth(mana_id, true, 3)

    -- Level
    _L.x      = R:X(44);     _L.y      = R:Y(1080 - 33 - 150)
    _L.bgW    = R:X(123);    _L.bgH    = R:Y(33)
    _L.fillW  = R:X(123);    _L.fillH  = R:Y(33)
    _L.offX   = math.floor((_L.bgW - _L.fillW) * 0.5)
    _L.offY   = math.floor((_L.bgH - _L.fillH) * 0.5)
    _L.textX  = R:X(104);   _L.textY  = R:Y(1080 - 200)
    PB.Ensure(level_id, { x=_L.x, y=_L.y, w=_L.bgW, h=_L.bgH, round=0, mode="linear", dir="lr" })
    PB.SetBgRect(level_id,   _L.x, _L.y, _L.bgW, _L.bgH)
    PB.SetFillRect(level_id, _L.x + _L.offX, _L.y + _L.offY, _L.fillW, _L.fillH)
    PB.SetBackground(level_id, "material", { material="hud_level_bar", color=Color(255, 255, 255), uv=true, flags="noclamp smooth" })
    PB.SetFill(level_id,       "material", { material="hud_level_bar", color=Color(255, 207, 85), uv=true, flags="noclamp smooth" })
    PB.SetSmooth(level_id, true, 3)

    -- Divers
    _HUD.bgX         = R:X(42);   _HUD.bgY         = R:Y(1080 - 223)
    _HUD.bgW         = R:X(553);  _HUD.bgH         = R:Y(223)
    _HUD.modelBgX    = R:X(38);   _HUD.modelBgY    = R:Y(1080 - 133 - 20)
    _HUD.modelBgW    = R:X(133);  _HUD.modelBgH    = R:Y(133)
    _HUD.modelFrameX = R:X(12);   _HUD.modelFrameY = R:Y(1080 - 188 - 7)
    _HUD.modelFrameW = R:X(182);  _HUD.modelFrameH = R:Y(188)
    _HUD.nameX       = R:X(181);  _HUD.nameY       = R:Y(1080 - 142)
    _HUD.modelS      = R:X(115)
    _HUD.modelX      = R:X(45);   _HUD.modelY      = R:Y(1080 - 115 - 35)
    _HUD.modelCX     = _HUD.modelX + _HUD.modelS * 0.5
    _HUD.modelCY     = _HUD.modelY + _HUD.modelS * 0.5
    _HUD.factionSize = R:X(40)
    _HUD.factionX    = R:X(85);   _HUD.factionY    = R:Y(1080 - 40 - 10)

    -- Logo haut droite (+15%)
    _HUD.logoW = R:X(154); _HUD.logoH = R:Y(67)
    _HUD.logoX = scrW - _HUD.logoW - R:X(50)
    _HUD.logoY = R:Y(50)
end
-- ──────────────────────────────────────────────────────────────────────────────
VERSE.Hook.AddNS("MainHUD", "InitPostEntity", "VERSE::InitPostEntity::MainHUD", function()
    Materials:SetAlias("hud_model_background", "verse/newhud/model_background")
    Materials:SetAlias("hud_level_background", "verse/hud/level_background")
    Materials:SetAlias("hud_level_bar", "verse/hud/level_bar")
    Materials:SetAlias("hud_health_background", "verse/newhud/health_background")
    Materials:SetAlias("hud_health_bar", "verse/newhud/health_bar")
    Materials:SetAlias("hud_health_icon", "verse/hud/health_icon")
    Materials:SetAlias("hud_mana_background", "verse/newhud/mana_background")
    Materials:SetAlias("hud_mana_bar", "verse/newhud/mana_bar")
    Materials:SetAlias("hud_mana_icon", "verse/hud/mana_icon")
    Materials:SetAlias("hud_exorcist_faction", "verse/hud/exorcist_faction")
    Materials:SetAlias("hud_spirits_faction", "verse/hud/spirits_faction")
    Materials:SetAlias("hud_verse_logo", "verse/boutique/verse_log")
end)

local function destroyHudModel()
    if IsValid(_hudModelPanel) then
        local CH = VERSE.Characters
        local chCtx = CH and CH.__ClientCharacterContext
        if istable(_hudModelPanel._markEnts) and chCtx and chCtx.clearBodyMarkLayerSet then
            chCtx.clearBodyMarkLayerSet(_hudModelPanel._markEnts)
        end
        _hudModelPanel:Remove()
    end
    _hudModelPanel = nil
    _hudModelSig = ""
end

local function ensureHudModel(ply)
    if not CP then CP = VERSE.CharacterPreview end
    if not CP then return end
    local app = CP:ReadAppearance(ply)
    local CH = VERSE.Characters
    local sel = CH and CH.Client and CH.Client.selected
    local selFaction = sel and isstring(sel.faction) and sel.faction ~= "" and sel.faction or ""
    local bodyMarksSig = ""
    if selFaction ~= "" and sel.body_marks then
        bodyMarksSig = util.TableToJSON(sel.body_marks, false) or ""
    end
    local sig = table.concat({
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
        bodyMarksSig,
    }, "\31")
    local mx = R:X(38)
    local my = R:Y(1080 - 130 - 35)
    local size = R:X(130)
    if IsValid(_hudModelPanel) and _hudModelSig == sig then
        _hudModelPanel:SetPos(mx, my)
        _hudModelPanel:SetSize(size, size)
        return
    end

    destroyHudModel()
    _hudModelSig = sig
    local chCtxForSkin = CH and CH.__ClientCharacterContext
    local skinMatcher = chCtxForSkin and chCtxForSkin.isSkinMaterialNameBase or nil
    _hudModelPanel = CP:CreateFromAppearance(nil, app, {
        fov         = 30,
        idle        = false,
        skinMatcher = skinMatcher,
    })

    if not IsValid(_hudModelPanel) then
        destroyHudModel()
        return
    end

    _hudModelPanel:SetPos(mx, my)
    _hudModelPanel:SetSize(size, size)
    _hudModelPanel:SetMouseInputEnabled(false)
    _hudModelPanel:SetKeyboardInputEnabled(false)
    _hudModelPanel:SetPaintedManually(true)

    -- Les fonctions body mark sont dans CH.__ClientCharacterContext, pas sur CH directement
    local chCtx = CH and CH.__ClientCharacterContext
    if IsValid(_hudModelPanel._headEnt) and selFaction ~= "" and chCtx and chCtx.syncBodyMarkLayerSet and CH.GetResolvedBodyMarks then
        local resolvedMarks = CH:GetResolvedBodyMarks(selFaction, sel and sel.body_marks) or {}
        _hudModelPanel._markEnts = chCtx.syncBodyMarkLayerSet(_hudModelPanel._headEnt, {}, resolvedMarks, "hud_portrait")
        local basePost = _hudModelPanel.PostDrawModel
        _hudModelPanel.PostDrawModel = function(s)
            if basePost then basePost(s) end
            if istable(s._markEnts) and chCtx.drawBodyMarkLayerSet then
                chCtx.drawBodyMarkLayerSet(s._markEnts, nil)
            end
        end
    end

    local root = _hudModelPanel.Entity
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
            local headPos = matrix and matrix:GetTranslation() or root:GetBonePosition(boneId) or Vector(0, 0, 60)
            _hudModelPanel:SetLookAt(headPos)
            _hudModelPanel:SetCamPos(headPos + Vector(35, -5, 0))
        end
    end
end

VERSE.Hook.AddNS("MainHUD", "HUDShouldDraw", "VERSE::HUDShouldDraw::MainHUD", function(name)
    if not HUD.Config.Hide then return end
    if HUD.Config.Hide[name] then return false end
end)

VERSE.Hook.AddNS("MainHUD", "HUDDrawTargetID", "VERSE::HUDDrawTargetID::MainHUD", function()
    if not HUD.Config.Hide["CTargetID"] then return end
    return false
end)

VERSE.Hook.AddNS("MainHUD", "HUDDrawPickupHistory", "VERSE::HUDDrawPickupHistory::MainHUD", function()
    if not HUD.Config.Hide["HUDDrawPickupHistory"] then return end
    return false
end)

VERSE.Hook.AddNS("MainHUD", "OnScreenHint", "VERSE::OnScreenHint::MainHUD", function()
    if not HUD.Config.Hide["OnScreenHint"] then return end
    return false
end)

-- ─── Cache des valeurs de texte HUD (évite les concaténations à chaque frame) ─
local _hudLastHealth, _hudLastMaxHealth, _hudHealthStr = -1, -1, "0/0"
local _hudLastMana,   _hudLastMaxMana,   _hudManaStr   = -1, -1, "0/0"
local _hudLastLevel,                     _hudLevelStr  = -1, "Level 0"

VERSE.Hook.AddNS("MainHUD", "HUDPaint", "VERSE::HUDPaint::MainHUD", function()
    if VERSE.Cinematic and VERSE.Cinematic:IsHUDHidden() then return end
    local _BT = VERSE.Boutique
    local _ST = VERSE.SkillTree
    local _ESC = VERSE.Escape
    if (_BT and IsValid(_BT._frame))
    or (_ST and _ST.Client and IsValid(_ST.Client.frame))
    or (_ESC and _ESC:IsOpen()) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not ply:Alive() then return end

    -- Initialise (ou recalcule si résolution changée) toutes les positions/polices/PB.
    initHud()

    local name      = ply:Nick()
    local health    = ply:Health()
    local maxHealth = ply:GetMaxHealth()
    local mana      = math.floor(tonumber(ply.GetMana    and ply:GetMana()    or 0)   or 0)
    local maxMana   = math.max(1, math.floor(tonumber(ply.GetManaMax and ply:GetManaMax() or 100) or 100))
    local level     = ply:GetLevel()
    local EXP       = ply:GetEXP()
    local maxEXP    = ply:GetMaxEXP()

    -- Mise à jour des strings seulement quand les valeurs changent (pas à chaque frame)
    if health ~= _hudLastHealth or maxHealth ~= _hudLastMaxHealth then
        _hudLastHealth = health; _hudLastMaxHealth = maxHealth
        _hudHealthStr = string.format("%d/%d", health, maxHealth)
    end
    if mana ~= _hudLastMana or maxMana ~= _hudLastMaxMana then
        _hudLastMana = mana; _hudLastMaxMana = maxMana
        _hudManaStr = string.format("%d/%d", mana, maxMana)
    end
    if level ~= _hudLastLevel then
        _hudLastLevel = level
        _hudLevelStr = "Level " .. level
    end

    --Materials:DrawDuplicate(COL_BG, "hud_main_background", _HUD.bgX, _HUD.bgY, _HUD.bgW, _HUD.bgH, "noclamp smooth")

    -- Health bar (config statique dans initHud, seul le ratio change)
    PB.SetValue(health_id, health / maxHealth)
    PB.Draw(health_id)
    do
        local textW = VERSE.GetTextSize(_hudHealthStr, F_VALUE)
        local iconX = _H.rightX - textW - _H.spacing - _H.iconW
        Materials:Draw(COL_HEALTH, "hud_health_icon", iconX, _H.iconBaseY, _H.iconW, _H.iconH, "noclamp smooth")
        draw.SimpleText(_hudHealthStr, F_VALUE, _H.rightX, _H.centerY, COL_HEALTH, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Mana bar
    PB.SetValue(mana_id, mana / maxMana)
    PB.Draw(mana_id)
    do
        local textW = VERSE.GetTextSize(_hudManaStr, F_VALUE)
        local iconX = _M.rightX - textW - _M.spacing - _M.iconW
        Materials:Draw(COL_MANA, "hud_mana_icon", iconX, _M.iconBaseY, _M.iconW, _M.iconH, "noclamp smooth")
        draw.SimpleText(_hudManaStr, F_VALUE, _M.rightX, _M.centerY, COL_MANA, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Level bar
    PB.SetValue(level_id, EXP / maxEXP)
    PB.Draw(level_id)
    draw.SimpleText(_hudLevelStr, F_LEVEL, _L.textX, _L.textY, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText(name, F_NAME, _HUD.nameX, _HUD.nameY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Portrait du personnage
    Materials:DrawDuplicate(color_white, "hud_model_background", _HUD.modelBgX, _HUD.modelBgY, _HUD.modelBgW, _HUD.modelBgH, "noclamp smooth")
    ensureHudModel(ply)
    if IsValid(_hudModelPanel) then
        _hudModelPanel:SetPos(_HUD.modelX, _HUD.modelY)
        _hudModelPanel:SetSize(_HUD.modelS, _HUD.modelS)
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
        RNDX.DrawCircle(_HUD.modelCX, _HUD.modelCY, _HUD.modelS, color_white)
        render.OverrideColorWriteEnable(false)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
        _hudModelPanel:PaintManual()
        render.SetStencilEnable(false)
    end

    -- Icône de faction
    Materials:Draw(color_white, "hud_exorcist_faction", _HUD.factionX, _HUD.factionY, _HUD.factionSize, _HUD.factionSize, "noclamp smooth")

    -- Logo VERSE haut droite (40% opacité)
    Materials:Draw(COL_LOGO, "hud_verse_logo", _HUD.logoX, _HUD.logoY, _HUD.logoW, _HUD.logoH, "noclamp smooth")

    VERSE.Hook.Run("VERSE::HUDPaint::TalkMode", ply)
end)