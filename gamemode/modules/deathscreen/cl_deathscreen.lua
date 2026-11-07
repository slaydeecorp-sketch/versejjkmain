local R = VERSE.Responsive
local Deathscreen = VERSE.Deathscreen
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local Math = VERSE.Math
local CFG = Deathscreen.Config

VERSE.Hook.AddNS("Deathscreen", "InitPostEntity", "VERSE::InitPostEntity::Deathscreen", function()
    Materials:SetAlias("deathscreen_background", "verse/deathscreen/main_background")
    Materials:SetAlias("deathscreen_text", "verse/deathscreen/death_text")
    Materials:SetAlias("deathscreen_disconnect_icon", "verse/deathscreen/disconnect_icon")
    Materials:SetAlias("deathscreen_disconnect_btn", "verse/deathscreen/disconnect_btn")
    Materials:SetAlias("deathscreen_playername_btn", "verse/deathscreen/playername_btn")
end)

Deathscreen.UI = Deathscreen.UI or {}
local UI = Deathscreen.UI
UI._NextRespawnRequest = UI._NextRespawnRequest or 0
local function Destroy()
    UI._dsModelPanel = nil
    if IsValid(UI.Frame) then UI.Frame:Remove() end
    UI.Frame = nil
    UI.RespawnAt = nil
    UI.TimerLabel = nil
    UI.RespawnBtn = nil
    UI.TimerText = nil
end

local function HoverFrac(s, halflife)
    s._hoverFrac = s._hoverFrac or 0
    local target = s:IsHovered() and 1 or 0
    s._hoverFrac = Math.ApproachExp(s._hoverFrac, target, halflife or 0.10, FrameTime())
    return s._hoverFrac
end

local IDLE_POOL = {
    {
        Sequence = "f606-jjk-gojo-as_cp_050_00_storymode_idle_02",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-nobara-as_cp_040_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-geto-as_cp_120_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-todo-as_cp_100_00_storymode_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-geto-as_cp_120_00_storymode_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-nanami-as_cp_090_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-momo-as_cp_180_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-toji-as_cp_170_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-choso-as_cp_230_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-eso-as_cp_160_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-todo-as_cp_100_00_storymode_idle_02",
        Weight = 1
    },
}

local function PickWeightedIdle(pool)
    if not istable(pool) or #pool == 0 then return nil end
    local total = 0
    for i = 1, #pool do
        local w = tonumber(pool[i].Weight) or 0
        if w > 0 then total = total + w end
    end

    if total <= 0 then return pool[1].Sequence end
    local r = math.Rand(0, total)
    local acc = 0
    for i = 1, #pool do
        local w = tonumber(pool[i].Weight) or 0
        if w > 0 then
            acc = acc + w
            if r <= acc then return pool[i].Sequence end
        end
    end
    return pool[#pool].Sequence
end

local function RespawnLeft()
    local now = CurTime()
    local at = tonumber(UI.RespawnAt) or now
    return math.max(0, at - now)
end

local function CanClickRespawn()
    if not UI.RespawnAt then return false end
    if CurTime() < UI.RespawnAt then return false end
    if CurTime() < (UI._NextRespawnRequest or 0) then return false end
    return true
end

local function UpdateTimerLabel()
    local left = RespawnLeft()
    if left <= 0 then
        UI.TimerText = "Disponible"
    else
        UI.TimerText = string.format("Réapparition dans %.1f", left)
    end
end

-- ─── Helpers d'apparence pour le DModelPanel ────────────────────────────────
-- Le DModelPanel n'exécute pas les hooks PrePlayerDraw/PostPlayerDraw du système
-- VERSE. On reconstruit manuellement la couleur de peau et la tête custom ici.

-- Palette de teintes de peau par défaut (doit correspondre à DEFAULT_SKIN_TONES de cl_character.lua)
local DS_SKIN_TONES = {
    Color(255, 244, 230), Color(240, 220, 198), Color(223, 196, 168),
    Color(192, 156, 126), Color(150, 113, 86),  Color(105, 75, 58),
}

-- Parseur de couleur au format "R,G,B" ou "R,G,B,A" (même format que parseAppearanceColor)
local function parseDeathColor(str, fallback)
    if isstring(str) and str ~= "" then
        local r, g, b = string.match(str, "^(%d+),(%d+),(%d+)")
        if r and g and b then
            return Color(
                math.Clamp(tonumber(r), 0, 255),
                math.Clamp(tonumber(g), 0, 255),
                math.Clamp(tonumber(b), 0, 255)
            )
        end
    end
    return fallback
end

-- Retourne vrai si le nom de bodygroup correspond à la tête intégrée du corps.
local function isHeadBodygroupName(name)
    name = string.lower(tostring(name or ""))
    return string.find(name, "head", 1, true) ~= nil
        or string.find(name, "face", 1, true) ~= nil
        or string.find(name, "tete", 1, true) ~= nil
        or string.find(name, "tête", 1, true) ~= nil
        or name == "hair"
        or string.find(name, "cheveu", 1, true) ~= nil
end

-- ─── Couleurs pré-allouées (évite des Color() à chaque frame dans les Paint) ──
local _DS_COL_BTN_ICON  = Color(255, 255, 255, 255)   -- alpha muté dans Paint
local _DS_COL_BTN_TXT   = Color(255, 255, 255, 255)   -- alpha muté dans Paint
local _DS_COL_BTN_TIMER = Color(255, 80,  80,  255)   -- alpha muté dans Paint
local _DS_COL_BTN_SHINE = Color(255, 255, 255, 0)     -- alpha muté dans Paint
local _DS_COL_BTN_LINE  = Color(255, 80,  80,  180)
local _DS_COL_BTN_SHADE = Color(0,   0,   0,   0)     -- alpha muté dans Paint
local _DS_COL_KILLER_NAME = Color(171, 82, 255, 255)
local _DS_COL_WHITE_125 = Color(255, 255, 255, 125)
local _DS_COL_TEXT_SEMI   = Color(255, 255, 255, 50)
-- Polices du bouton respawn : résolues une seule fois à l'ouverture du screen.
local _DS_FONT_TITLE = nil
local _DS_FONT_TIMER = nil

local function Open(respawnAt, killerName, killerModel, killerBodygroups, killerAppearance)
    Destroy()
    UI.RespawnAt = tonumber(respawnAt) or CurTime()
    local sw, sh = 1920, 1080
    local f = vgui.Create("MantleFrame")
    f:SetSize(R:XY(sw, sh))
    f:Center()
    f:MakePopup()
    f:LiteMode()
    f:RequestFocus()
    f:SetAlphaBackground(false)
    f:SetClosable(false)
    f:SetDraggable(false)
    f:DisableCloseBtn()
    f:SetKeyboardInputEnabled(true)
    UI.Frame = f
    f.Paint = function(_, w, h)
        Materials:DrawDuplicate(color_white, "deathscreen_background", 0, 0, w, h)
        Materials:Draw(_DS_COL_TEXT_SEMI, "deathscreen_text", R:X(30), R:Y(120), R:X(793), R:Y(720))
        RNDX().Rect(0, 0, w, h):Rad(0):Blur(0.25):Draw()
    end

    local respawnBtn = vgui.Create("MantleBtn", f)
    respawnBtn:SetSize(R:XY(400, 80))
    respawnBtn:SetPos(R:XY(170, 855))
    respawnBtn:SetText("")
    UI.RespawnBtn = respawnBtn
    UpdateTimerLabel()

    local iconW = R:X(28)
    local iconH = R:Y(43)
    local spacing = R:X(12)
    -- Résoudre les polices UNE SEULE FOIS à l'ouverture (pas dans Paint)
    _DS_FONT_TITLE = Font:GetNamed("Poppins", "Bold", 35)
    _DS_FONT_TIMER = Font:GetNamed("Poppins", "Bold", 24)
    local _titleText = "Respawn"
    local _titleW, _titleH = VERSE.GetTextSize(_titleText, _DS_FONT_TITLE)

    respawnBtn._shine = 0
    respawnBtn._pulse = 0
    respawnBtn.Paint = function(s, w, h)
        local dt = FrameTime()
        local canClick = CanClickRespawn()
        s:SetEnabled(canClick)

        local t = 0
        if canClick then
            t = HoverFrac(s, 0.10)
        else
            s._hoverFrac = Math.ApproachExp(s._hoverFrac or 0, 0, 0.10, dt)
            t = s._hoverFrac or 0
        end

        local baseA = canClick and 85 or 45
        _DS_COL_BTN_ICON.a = baseA
        Materials:Draw(_DS_COL_BTN_ICON, "deathscreen_disconnect_btn", 0, 0, w, h, "noclamp smooth")

        if t > 0.01 then
            s._shine = (s._shine + dt * 1.35) % 1
        else
            s._shine = Math.ApproachExp(s._shine or 0, 0, 0.10, dt)
        end

        s._pulse = (s._pulse or 0) + dt * 6
        local slideX = R:X(16) * t
        local liftY = -R:Y(2) * t

        if t > 0.01 then
            local shineW = w * 0.28
            local shineH = h * 1.6
            local shineX = Math.Lerp(-shineW, w + shineW, s._shine)
            local shineY = -h * 0.3
            local a = math.floor(20 * t)
            _DS_COL_BTN_SHINE.a = a
            RNDX().Rect(shineX, shineY, shineW, shineH):Rad(R:Y(10)):Color(_DS_COL_BTN_SHINE):Rotation(20):Draw()
        end

        local lineW = (w * 0.72) * t
        if lineW > 0.5 then
            local lineH = R:Y(4)
            local lineX = (w - lineW) * 0.5
            local lineY = h - R:Y(10)
            RNDX().Rect(lineX, lineY, lineW, lineH):Rad(R:Y(2)):Color(_DS_COL_BTN_LINE):Draw()
        end

        local breath = math.sin(s._pulse) * 0.5 + 0.5
        local iconA = canClick and (200 + math.floor(55 * t)) or 120
        local textA = canClick and (210 + math.floor(45 * t)) or 140
        if canClick and t > 0.01 then
            iconA = iconA + math.floor(15 * breath * t)
            textA = textA + math.floor(10 * breath * t)
        end

        local timerText = UI.TimerText or ""
        local timerW, timerH = VERSE.GetTextSize(timerText, _DS_FONT_TIMER)
        local blockH = _titleH + R:Y(4) + timerH
        local centerY = h * 0.5 + liftY
        local titleY = centerY - blockH * 0.5 + _titleH * 0.5 + R:Y(5)
        local timerY = titleY + _titleH * 0.5 - R:Y(5) + timerH * 0.5
        local iconBlockCenterY = centerY
        local iconY = iconBlockCenterY - iconH * 0.5
        local contentW = iconW + spacing + math.max(_titleW, timerW)
        local startX = (w - contentW) * 0.5 + slideX
        local iconX = startX
        local textX = startX + iconW + spacing

        _DS_COL_BTN_ICON.a = iconA
        Materials:Draw(_DS_COL_BTN_ICON, "deathscreen_disconnect_icon", iconX, iconY, iconW, iconH, "noclamp")
        _DS_COL_BTN_TXT.a = textA
        draw.SimpleText(_titleText, _DS_FONT_TITLE, textX, titleY, _DS_COL_BTN_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local timerA = canClick and (170 + math.floor(40 * t)) or 110
        _DS_COL_BTN_TIMER.a = timerA
        draw.SimpleText(timerText, _DS_FONT_TIMER, textX, timerY, _DS_COL_BTN_TIMER, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if t > 0.01 then
            local shadeA = math.floor(60 * t)
            _DS_COL_BTN_SHADE.a = shadeA
            RNDX().Rect(0, 0, w, h):Rad(R:Y(10)):Outline(R:Y(2)):Color(_DS_COL_BTN_SHADE):Draw()
        end
    end

    respawnBtn.DoClick = function()
        if not CanClickRespawn() then return end
        UI._NextRespawnRequest = CurTime() + 0.35
        netstream.Start(CFG.NET.Request)
    end

    local killerPanel = vgui.Create("DPanel", f)
    killerPanel:SetSize(R:XY(1053, sh))
    killerPanel:SetPos(R:XY(sw - 1053, 0))
    killerPanel:SetPaintBackground(false)
    killerPanel._killerName = tostring(killerName or "Unknown")

    -- ─── Apparence du killer → CP:CreateFromAppearance ──────────────────────────
    -- On utilise exactement le même système que le menu de sélection de personnage.
    -- CP gère : EF_BONEMERGE (tête suit les os automatiquement), PostDrawModel
    -- (rendu de la tête avec couleur de peau dans le contexte 3D natif du DModelPanel),
    -- PreDrawModel (couleur de peau du corps), caméra automatique.
    local CP = VERSE.CharacterPreview
    if not CP then
        ErrorNoHalt("[Deathscreen] VERSE.CharacterPreview n'est pas disponible — tête du killer non affichée\n")
    end
    local ka = istable(killerAppearance) and killerAppearance or {}

    local skinC
    if ka.skinColor and ka.skinColor ~= "" then
        skinC = parseDeathColor(ka.skinColor, nil)
    end
    if not skinC then
        -- Utilise la même palette que CP (peut être custom via ConfigTable("SkinColorPalette"))
        -- pour que la teinte de peau corresponde exactement à ce qu'on voit en jeu.
        local palette = (CP and CP.GetSkinPalette and CP.GetSkinPalette()) or DS_SKIN_TONES
        local idx = math.Clamp(math.floor(tonumber(ka.skinTone or 1)), 1, #palette)
        skinC = palette[idx]
    end

    local bodyMdl = tostring(killerModel or "")
    if bodyMdl == "" then bodyMdl = "models/player/kleiner.mdl" end

    local hairColorFallback = (CP and CP.DEFAULT_HAIR) or Color(62, 44, 30)
    local CH    = VERSE.Characters
    local CHctx = CH and CH.__ClientCharacterContext
    local heightVal  = tonumber(ka.height) or 170
    local modelScale = (CH and CH.GetHeightScale) and CH:GetHeightScale(heightVal) or 1
    local app = {
        bodyModel    = bodyMdl,
        headModel    = tostring(ka.headModel or ""),
        bodyStyle    = tonumber(ka.bodyStyle)    or 0,
        headStyle    = tonumber(ka.headStyle)    or 0,
        hairStyle    = tonumber(ka.hairStyle)    or 0,
        skinColor    = skinC or (CP and CP.DEFAULT_SKIN) or Color(255, 244, 230),
        hairColor    = parseDeathColor(tostring(ka.hairColor    or ""), hairColorFallback),
        modelScale   = modelScale,
        eyebrowStyle = tonumber(ka.eyebrowStyle) or 1,
        eyebrowColor = parseDeathColor(tostring(ka.eyebrowColor or ""), nil),
        irisStyle    = tonumber(ka.irisStyle)    or 1,
        irisSize     = tonumber(ka.irisSize)     or 100,
        eyeColor     = parseDeathColor(tostring(ka.eyeColor     or ""), Color(255, 255, 255)),
        bodyMarksJson = tostring(ka.bodyMarks or ""),
    }

    if CP then
        -- skinMatcher : isSkinMaterialNameBase filtre les matériaux non-peau (chemise, pantalon…)
        -- Sans ce filtre, tintEntity applique la couleur de peau sur TOUS les matériaux du corps
        -- → chemise blanche devient marron. Avec le filtre, seuls les slots "_skin" sont teintés.
        local skinMatcher = CHctx and CHctx.isSkinMaterialNameBase or nil
        killerPanel.Model = CP:CreateFromAppearance(killerPanel, app, {
            fov         = 50,
            idle        = false,
            skinMatcher = skinMatcher,
        })
    end
    UI._dsModelPanel = killerPanel.Model

    if IsValid(killerPanel.Model) then
        local root = killerPanel.Model.Entity
        if IsValid(root) then
            -- Bodygroups de la tenue équipée
            if istable(killerBodygroups) then
                for i, v in ipairs(killerBodygroups) do
                    root:SetBodygroup(i - 1, v)
                end
            end
            -- Animation idle aléatoire depuis le pool JJK
            local idleName = PickWeightedIdle(IDLE_POOL) or "idle_all_01"
            local seq = root:LookupSequence(idleName)
            if not seq or seq < 0 then
                seq = root:LookupSequence("idle_all_01")
                if not seq or seq < 0 then seq = 0 end
            end
            killerPanel._seq    = seq
            killerPanel._animT0 = SysTime()
            local dur = root:SequenceDuration(seq)
            if not dur or dur <= 0 then dur = 3 end
            killerPanel._seqDur = dur
            root:SetSequence(seq)
            root:SetCycle(0)
            root:SetPlaybackRate(0)

            -- ── Caméra : lookAt vers le haut du buste → personnage décalé vers le bas ─
            -- Le lookAt est le point qui apparaît AU CENTRE du viewport.
            -- En le pointant vers la tête (h*0.35 au-dessus du centre), tout le corps
            -- descend d'environ 200px dans le cadre.
            local mins, maxs = root:GetRenderBounds()
            local center = (mins + maxs) * 0.5
            local h      = math.max(1, maxs.z - mins.z)
            local rad    = math.max(maxs.x - mins.x, maxs.y - mins.y, h)
            killerPanel.Model:SetFOV(35)
            killerPanel.Model:SetLookAt(center + Vector(0, 0, h * 0.22))
            killerPanel.Model:SetCamPos(center + Vector(rad * 1.7, rad * 0.12, h * 0.35))
        end

        -- ── Tatouages (body marks) ─────────────────────────────────────────────────
        -- Les fonctions body mark sont dans CH.__ClientCharacterContext (pas sur CH directement).
        local fnParse = CHctx and CHctx.parseResolvedBodyMarks
        local fnSync  = CHctx and CHctx.syncBodyMarkLayerSet
        local fnDraw  = CHctx and CHctx.drawBodyMarkLayerSet
        local fnClear = CHctx and CHctx.clearBodyMarkLayerSet

        local rawMarks = tostring(app.bodyMarksJson or "")
        local resolvedMarks = {}
        if rawMarks ~= "" and fnParse then
            resolvedMarks = fnParse(rawMarks) or {}
        end
        local headEnt = killerPanel.Model._headEnt
        if IsValid(headEnt) and fnSync then
            killerPanel._markEnts = fnSync(headEnt, {}, resolvedMarks, "select_killer")
        else
            killerPanel._markEnts = {}
        end

        -- ── Override PostDrawModel : ajoute le rendu des tatouages ─────────────────
        local basePDM = killerPanel.Model.PostDrawModel
        killerPanel.Model.PostDrawModel = function(s)
            if basePDM then basePDM(s) end
            if istable(killerPanel._markEnts) and fnDraw then
                fnDraw(killerPanel._markEnts)
            end
        end

        -- ── Nettoyage des entités-layer à la suppression du panel ─────────────────
        local baseOnRemove = killerPanel.Model.OnRemove
        killerPanel.Model.OnRemove = function(s)
            if istable(killerPanel._markEnts) then
                if fnClear then
                    killerPanel._markEnts = fnClear(killerPanel._markEnts)
                else
                    for k, ent in pairs(killerPanel._markEnts) do
                        if IsValid(ent) then ent:Remove() end
                    end
                    killerPanel._markEnts = nil
                end
            end
            if baseOnRemove then baseOnRemove(s) end
        end

        -- ── LayoutEntity : animation manuelle + invalidation os pour EF_BONEMERGE ─
        killerPanel.Model.LayoutEntity = function(s, ent)
            if not IsValid(ent) then return end
            if killerPanel._seq then ent:SetSequence(killerPanel._seq) end
            local t0  = killerPanel._animT0
            local dur = killerPanel._seqDur or 3
            if t0 then
                local t = SysTime() - t0
                ent:SetCycle((t / dur) % 1)
                ent:SetPlaybackRate(0)
            end
            ent:InvalidateBoneCache()
            ent:SetupBones()
            if IsValid(s._headEnt) then
                s._headEnt:InvalidateBoneCache()
                s._headEnt:SetupBones()
            end
        end
    end
    -- ─────────────────────────────────────────────────────────────────────────────

    killerPanel.PerformLayout = function(s, w, h)
        local barH = R:Y(147)
        local barY = h - barH - R:Y(80)
        local viewH = math.max(1, barY - R:Y(20))
        if IsValid(s.Model) then
            s.Model:SetPos(0, 0)
            s.Model:SetSize(w, viewH)
        end
    end

    local _killerNameFont = Font:GetNamed("Poppins", "Bold", 65)
    killerPanel.PaintOver = function(s, w, h)
        local name = s._killerName or "Unknown"
        local barW = R:X(736)
        local barH = R:Y(147)
        local barX = w * 0.5 - barW / 2
        local barY = h - barH - R:Y(100)
        Materials:Draw(_DS_COL_WHITE_125, "deathscreen_playername_btn", barX, barY, barW, barH, "noclamp smooth")
        draw.SimpleText(name, _killerNameFont, w * 0.5, barY + barH * 0.5, _DS_COL_KILLER_NAME, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

netstream.Hook(CFG.NET.Open, function(respawnAt, killerName, killerModel, killerBodygroups, killerAppearance) Open(respawnAt, killerName, killerModel, killerBodygroups, killerAppearance) end)
netstream.Hook(CFG.NET.Close, function() Destroy() end)
VERSE.Hook.AddNS("Deathscreen", "Think", "VERSE::Think::Deathscreen", function()
    if not IsValid(LocalPlayer()) then return end
    if not IsValid(UI.Frame) then return end
    if LocalPlayer():Alive() then
        Destroy()
        return
    end
    UpdateTimerLabel()
end)