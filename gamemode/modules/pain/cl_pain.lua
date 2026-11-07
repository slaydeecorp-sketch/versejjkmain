local P = VERSE.Pain
if not P then return end

local _inPain   = false
local _frac     = 0        -- interpolation overlay (0→1)
local _channel  = nil      -- IGModAudioChannel (son en boucle)

-- ─── Police ───────────────────────────────────────────────────────────────────
local _fontReady = false
local PAIN_FONT  = "VERSE_Pain_Label"

local function ensureFont()
    if _fontReady then return end
    _fontReady = true
    surface.CreateFont(PAIN_FONT, {
        font      = "Poppins",
        size      = 26,
        weight    = 700,
        antialias = true,
        shadow    = true,
    })
end

-- ─── Son ──────────────────────────────────────────────────────────────────────
local function startSound()
    if _channel then return end
    sound.PlayFile("sound/verse/pain/coeur.mp3", "", function(ch, errCode, errStr)
        if not IsValid(ch) then
            if VERSE and VERSE.Log then
                VERSE.Log:Warn("[Pain] Son introuvable : verse/pain/coeur.mp3 (" .. tostring(errStr) .. ")")
            end
            return
        end
        _channel = ch
        ch:EnableLooping(true)
        ch:SetVolume(0.8)
        ch:Play()
    end)
end

local function stopSound()
    if IsValid(_channel) then
        _channel:Stop()
    end
    _channel = nil
end

-- ─── Réception état depuis le serveur ─────────────────────────────────────────
netstream.Hook(P.Net.State, function(state)
    _inPain = state == true
    if _inPain then
        startSound()
    else
        stopSound()
    end
end)

-- ─── Overlay + texte ─────────────────────────────────────────────────────────
-- Couleur vignette : rouge sombre sur les bords + assombrissement central.
-- L'alpha cible est 160 (clairement visible sans être totalement opaque).
local PAIN_VIGNETTE_ALPHA = 160
-- Couleur pré-allouée pour le texte (évite Color() dans HUDPaint à chaque frame)
local _PAIN_COL_TEXT = Color(255, 80, 80, 0)   -- .a muté

hook.Add("HUDPaint", "VERSE::Pain::Overlay", function()
    local target = _inPain and 1 or 0
    if target == 0 and _frac < 0.001 then return end

    _frac = math.Approach(_frac, target, FrameTime() * 2)

    if _frac > 0.001 then
        local sw, sh  = ScrW(), ScrH()
        local alpha   = math.floor(PAIN_VIGNETTE_ALPHA * _frac)
        local textAlpha = math.floor(255 * _frac)

        -- ── Overlay rouge plein écran (un seul rect, pas de chevauchement) ──
        surface.SetDrawColor(180, 0, 0, alpha)
        surface.DrawRect(0, 0, sw, sh)

        -- ── Texte "Vous êtes blessé" ───────────────────────────────────────
        ensureFont()
        _PAIN_COL_TEXT.a = textAlpha
        draw.SimpleText(
            "Vous êtes blessé",
            PAIN_FONT,
            sw * 0.5,
            62,
            _PAIN_COL_TEXT,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
    end
end)

-- ─── Icône au-dessus de la tête ─────────────────────────────────────────────
-- Material chargé une seule fois (jamais en cours de frame).
local _painIconMat    = nil
local _painIconReady  = false

local function getPainIconMat()
    if _painIconReady then return _painIconMat end
    _painIconReady = true
    local m = Material("verse/pain/guerison.png", "noclamp smooth")
    _painIconMat = (m and not m:IsError()) and m or nil
    return _painIconMat
end

-- Cache de bone tête par joueur (même logique que cl_character_nameplates).
local _painHeadBoneCache = {}

local function _getPainHeadPos(ply)
    if not IsValid(ply) then return nil end
    local idx    = ply:EntIndex()
    local model  = ply:GetModel()
    local cached = _painHeadBoneCache[idx]
    local boneId
    if cached and cached.model == model then
        boneId = cached.boneId
    else
        boneId = ply:LookupBone("ValveBiped.Bip01_Head1") or false
        _painHeadBoneCache[idx] = { model = model, boneId = boneId }
    end
    if boneId then
        local mat = ply:GetBoneMatrix(boneId)
        if mat then return mat:GetTranslation() + Vector(0, 0, 15) end
    end
    local obb = ply:OBBMaxs()
    return ply:GetPos() + Vector(0, 0, (obb and obb.z or 72) + 15)
end

local ICON_MAX_DIST  = 300
local ICON_FADE_NEAR = 200
local ICON_SIZE      = 52   -- px dans l'espace 3D2D (+30 %)
-- L'icône est centrée à Y = -(ICON_SIZE/2 + 28) → juste au-dessus du texte de nom.
local ICON_Y         = -(ICON_SIZE + 20)

hook.Add("PostDrawTranslucentRenderables", "VERSE::Pain::HeadIcon", function(_, _, skybox)
    if skybox then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local mat = getPainIconMat()
    if not mat then return end

    local viewPos = EyePos()
    local maxSqr  = ICON_MAX_DIST  * ICON_MAX_DIST
    local fadeSqr = ICON_FADE_NEAR * ICON_FADE_NEAR

    cam.IgnoreZ(true)

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        if not ply:GetNWBool("VERSE_InPain", false) then continue end

        local distSqr = viewPos:DistToSqr(ply:GetPos())
        if distSqr > maxSqr then continue end

        local headPos = _getPainHeadPos(ply)
        if not headPos then continue end

        -- Calcul alpha (fondu entre ICON_FADE_NEAR et ICON_MAX_DIST)
        local alpha = 255
        if distSqr > fadeSqr then
            local t = (distSqr - fadeSqr) / (maxSqr - fadeSqr)
            alpha = math.floor(math.Clamp(1 - t, 0, 1) * 255)
        end
        if alpha < 3 then continue end

        local ang   = (headPos - viewPos):Angle()
        local dist  = math.sqrt(distSqr)
        local scale = math.Clamp(0.09 + dist / 4200, 0.09, 0.22)

        cam.Start3D2D(headPos, Angle(0, ang.y - 90, 90), scale)
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(-ICON_SIZE * 0.5, ICON_Y, ICON_SIZE, ICON_SIZE)
        cam.End3D2D()
    end

    cam.IgnoreZ(false)
end)

-- ─── Blocage des slots de compétences côté client ────────────────────────────
-- RequestUseSlot envoie directement le netstream sans passer par un hook.
-- On wrappe la fonction elle-même pour intercepter avant l'envoi réseau.
hook.Add("InitPostEntity", "VERSE::Pain::WrapSkillSlot", function()
    local ST = VERSE and VERSE.SkillTree
    if not ST or not isfunction(ST.RequestUseSlot) then return end
    local _orig = ST.RequestUseSlot
    ST.RequestUseSlot = function(self, ...)
        if _inPain then return end
        return _orig(self, ...)
    end
end)

-- ─── Nettoyage à la connexion / déconnexion ───────────────────────────────────
hook.Add("InitPostEntity", "VERSE::Pain::ClientInit", function()
    stopSound()
    _inPain = false
    _frac   = 0
end)

hook.Add("ShutDown", "VERSE::Pain::Shutdown", function()
    stopSound()
end)
