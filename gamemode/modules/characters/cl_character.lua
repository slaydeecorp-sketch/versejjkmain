local CH = VERSE.Characters
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Language = VERSE.L
local Materials = VERSE.Materials
local characterSelectFrame, characterCreateFrame, characterAdminFrame = nil, nil, nil
local CHAR_PREVIEW_MDL = "models/verse/head/base_head1.mdl"
local CHAR_VIEW_W = 1129
local CHAR_CAM_ANG = Angle(2, 0, 0)
local CHAR_MDL_POS = Vector(5000, 5000, -35)
local CHAR_MDL_ANG = Angle(0, 180, 0)
local CHAR_CAM_FOV = 48
local DEFAULT_SKIN_TONES = {Color(255, 244, 230), Color(240, 220, 198), Color(223, 196, 168), Color(192, 156, 126), Color(150, 113, 86), Color(105, 75, 58),}
local _CH_COL_MARK_HIDE = Color(255, 255, 255, 0)
local _CH_COL_MARK_SHOW = Color(255, 255, 255, 255)
local DEFAULT_HAIR_COLOR = Color(62, 44, 30)
local DEFAULT_EYE_COLOR = Color(255, 255, 255)
local FACE_SKIN_RUNTIME_MATERIALS = {}
local function computeCamFromModel(mdlPos, mdlAng, dist, height)
    dist = dist or 86
    height = height or 52
    local fwd = Angle(0, mdlAng.y, 0):Forward()
    local camPos = mdlPos + fwd * dist + Vector(0, 0, height)
    local camAng = Angle(3, mdlAng.y + 180, 0)
    return camPos, camAng
end

local function bindAnimatedCard(panel, baseX, baseY, opts)
    if not IsValid(panel) then return panel end
    opts = opts or {}
    panel._baseX = tonumber(baseX) or panel:GetX()
    panel._baseY = tonumber(baseY) or panel:GetY()
    panel._hoverFrac = panel._hoverFrac or 0
    panel._pressFrac = panel._pressFrac or 0
    panel._clickFrac = panel._clickFrac or 0
    panel._clickAnimUntil = nil
    panel._clickAnimDur = math.max(0.05, tonumber(opts.clickDuration) or 0.14)
    panel._hoverLift = tonumber(opts.hoverLift) or 10
    panel._pressDrop = tonumber(opts.pressDrop) or 4
    local prevDoClick = panel.DoClick
    panel.DoClick = function(selfBtn, ...)
        selfBtn._clickAnimUntil = RealTime() + selfBtn._clickAnimDur
        if prevDoClick then return prevDoClick(selfBtn, ...) end
    end

    panel.Think = function(selfBtn)
        local hoverTarget = selfBtn:IsHovered() and 1 or 0
        local isPressed = selfBtn.Depressed == true
        local hoverRate = math.min(FrameTime() * 10, 1)
        local pressRate = math.min(FrameTime() * 16, 1)
        selfBtn._hoverFrac = Lerp(hoverRate, selfBtn._hoverFrac or 0, hoverTarget)
        selfBtn._pressFrac = Lerp(pressRate, selfBtn._pressFrac or 0, isPressed and 1 or 0)
        local clickFrac = 0
        if selfBtn._clickAnimUntil then
            local remaining = selfBtn._clickAnimUntil - RealTime()
            if remaining > 0 then
                clickFrac = remaining / selfBtn._clickAnimDur
            else
                selfBtn._clickAnimUntil = nil
            end
        end

        selfBtn._clickFrac = clickFrac
        local pressVisual = math.max(selfBtn._pressFrac or 0, clickFrac)
        local yOffset = math.floor(((-selfBtn._hoverLift * (selfBtn._hoverFrac or 0)) + (selfBtn._pressDrop * pressVisual)) + 0.5)
        local nx = selfBtn._baseX
        local ny = selfBtn._baseY + yOffset
        if selfBtn:GetX() ~= nx or selfBtn:GetY() ~= ny then selfBtn:SetPos(nx, ny) end
    end
    return panel
end

Materials:SetAlias("character_main_background", "verse/character/main_background")
Materials:SetAlias("character_closed_character", "verse/character/closed_character")
Materials:SetAlias("character_exorcist_fraction", "verse/character/exorcist_fraction")
Materials:SetAlias("character_spirit_fraction", "verse/character/spirit_fraction")
Materials:SetAlias("character_japan_icon", "verse/character/japan_icon")
Materials:SetAlias("character_logo_verse", "verse/character/logo_verse")
Materials:SetAlias("character_star_icon", "verse/character/star_icon")
Materials:SetAlias("character_create_char_back", "verse/character/create_char_back")
Materials:SetAlias("character_exorcist_fraction_background", "verse/character/exorcist_fraction_background")
Materials:SetAlias("character_spirit_fraction_background", "verse/character/spirit_fraction_background")
Materials:SetAlias("character_female_icon", "verse/character/female_icon")
Materials:SetAlias("character_male_icon", "verse/character/male_icon")
Materials:SetAlias("character_right_panel", "verse/character/right_panel")
function CH:ErrorText(code)
    code = tostring(code or "unknown")
    local key = "character.error_" .. code
    local text = Language(key)
    if not isstring(text) or text == key then text = Language("character.error_unknown") end
    if code:find("^bad_nickname_") or code:find("^bad_firstname_") or code:find("^bad_lastname_") then
        local minN = CH:ConfigInt("NameMin", 2, 1, 64)
        local maxN = CH:ConfigInt("NameMax", 18, minN, 64)
        if code:sub(-6) == "_short" or code:sub(-6) == "_empty" then
            text = string.format("%s (min. %d)", text, minN)
        elseif code:sub(-5) == "_long" then
            text = ("%s (max. %d)").format(text, maxN)
        end
    end

    if code:find("^bad_description") then
        local minD = CH:ConfigInt("DescMin", 0, 0, 8192)
        local maxD = CH:ConfigInt("DescMax", 512, 0, 8192)
        if code:sub(-6) == "_short" or code:sub(-6) == "_empty" then
            if minD > 0 then text = ("%s (min. %d)").format(text, minD) end
        elseif code == "bad_description" then
            text = ("%s (max. %d)").format(text, maxD)
        end
    end
    return text
end

function CH:NotifyError(code, duration)
    duration = tonumber(duration) or 4
    local frame = IsValid(characterCreateFrame) and characterCreateFrame or (IsValid(characterAdminFrame) and characterAdminFrame) or (IsValid(characterSelectFrame) and characterSelectFrame) or nil
    if IsValid(frame) and frame.Notify then
        frame:Notify(self:ErrorText(code), duration)
    else
        VERSE.Log:Error("[Characters] error: " .. tostring(code))
    end
end

CH.Client = CH.Client or {
    slots = 1,
    list = {},
    adminList = {},
    selected = nil,
    lastError = nil,
    knownNames = {},
}

CH.Client.adminList = CH.Client.adminList or {}
local function ensureLocalKnownName()
    local selected = CH.Client and CH.Client.selected or nil
    if not istable(selected) then return end
    local id = tonumber(selected.id)
    if not id then return end
    local displayName = CH.GetDisplayName and CH:GetDisplayName(selected) or ""
    displayName = tostring(displayName or "")
    if displayName == "" then return end
    CH.Client.knownNames = CH.Client.knownNames or {}
    CH.Client.knownNames[id] = displayName
end

local WORLD_APPEARANCE = CH.WorldAppearance or {}
if istable(WORLD_APPEARANCE) then
    for _, state in pairs(WORLD_APPEARANCE) do
        if istable(state) and IsValid(state.headEnt) then state.headEnt:Remove() end
    end
end

CH.WorldAppearance = WORLD_APPEARANCE
local nextWorldAppearanceRefresh = 0
local WORLD_APPEARANCE_MATERIALS = {}
local WORLD_SKIN_PALETTE_CACHE = nil
local WORLD_SKIN_PALETTE_SOURCE = nil
local function cloneAppearanceColor(colorValue, fallback)
    if IsColor(colorValue) then return Color(colorValue.r, colorValue.g, colorValue.b, colorValue.a or 255) end
    local fb = fallback or color_white
    return Color(fb.r, fb.g, fb.b, fb.a or 255)
end

local function parseAppearanceColor(value, fallback)
    if IsColor(value) then return Color(value.r, value.g, value.b, value.a or 255) end
    if istable(value) and value.r and value.g and value.b then return Color(tonumber(value.r) or 255, tonumber(value.g) or 255, tonumber(value.b) or 255, tonumber(value.a) or 255) end
    if isstring(value) and value ~= "" then
        local r, g, b, a = string.match(value, "^(%d+),(%d+),(%d+),?(%d*)$")
        if r and g and b then return Color(math.Clamp(tonumber(r) or 255, 0, 255), math.Clamp(tonumber(g) or 255, 0, 255), math.Clamp(tonumber(b) or 255, 0, 255), math.Clamp(tonumber(a) or 255, 0, 255)) end
    end
    return cloneAppearanceColor(fallback or DEFAULT_HAIR_COLOR, DEFAULT_HAIR_COLOR)
end

local FACE_MATERIAL_SLOT_CACHE = {}
local FACE_EYEBROW_RUNTIME_MATERIALS = {}
local FACE_EYE_RUNTIME_MATERIALS = {}
local HAIR_RUNTIME_MATERIALS = {}
-- Dégradé cheveux : on ne peut pas générer un render target pendant la passe de
-- rendu principale (push de RT imbriqué). _inMainRender est vrai pendant cette
-- passe ; les générations demandées à ce moment sont mises en file et traitées
-- dans un Think (hors rendu).
local _inMainRender = false
local _hairGradGenQueue = {}
local HEAD_HAIR_SLOT_CACHE = {}
local IRIS_RUNTIME_MATERIALS = {}
local HEAD_PUPIL_SLOT_CACHE = {}
local function _findPupilSlotIndex(ent)
    if not IsValid(ent) or not ent.GetMaterials then return nil end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if mdl == "" then return nil end
    local cached = HEAD_PUPIL_SLOT_CACHE[mdl]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local mats = ent:GetMaterials() or {}
    for i, matName in ipairs(mats) do
        local lower = string.lower(tostring(matName or ""))
        if string.find(lower, "pupils", 1, true) and not string.find(lower, "back_eyes", 1, true) then
            local variant = string.match(lower, "pupils(%d+)")
            if not variant or variant == "" then
                HEAD_PUPIL_SLOT_CACHE[mdl] = i - 1
                return i - 1
            end
        end
    end

    HEAD_PUPIL_SLOT_CACHE[mdl] = false
    return nil
end

local function _getIrisRuntimeMaterial(style, sizePct, color)
    style = math.Clamp(math.floor(tonumber(style) or 1), 1, 55)
    sizePct = math.Clamp(math.floor(tonumber(sizePct) or 100), 40, 200)
    local r, g, b = 255, 255, 255
    if IsColor(color) then
        r = math.Clamp(math.floor(tonumber(color.r) or 255), 0, 255)
        g = math.Clamp(math.floor(tonumber(color.g) or 255), 0, 255)
        b = math.Clamp(math.floor(tonumber(color.b) or 255), 0, 255)
    end

    local key = string.format("%d|%d|%d,%d,%d", style, sizePct, r, g, b)
    local cached = IRIS_RUNTIME_MATERIALS[key]
    if cached and not cached:IsError() then return cached end
    local uvScale = 100 / sizePct
    local runtimeName = "verse__char__iris_" .. string.gsub(key, "[|,]", "_")
    local texName = (style == 1) and "verse/head/verse_pupils" or ("verse/head/verse_pupils" .. tostring(style))
    local mat = CreateMaterial(runtimeName, "VertexLitGeneric", {
        ["$model"] = 1,
        ["$basetexture"] = texName,
        ["$basetexturetransform"] = string.format("center .5 .5 scale %.4f %.4f rotate 0 translate 0 0", uvScale, uvScale),
        ["$lightwarptexture"] = "slayde_jjk/shared/lightwarpshader",
        ["$color2"] = string.format("[%.4f %.4f %.4f]", r / 255, g / 255, b / 255),
        ["$alphatest"] = 1,
        ["$alphatestreference"] = 0.05,
    })

    IRIS_RUNTIME_MATERIALS[key] = mat
    return mat
end

local function setEntityIris(ent, style, sizePct, color)
    if not IsValid(ent) or not ent.SetSubMaterial then return end
    local slot = _findPupilSlotIndex(ent)
    if slot == nil then return end
    local mat = _getIrisRuntimeMaterial(style, sizePct, color)
    if mat and not mat:IsError() then
        ent:SetSubMaterial(slot, "!" .. mat:GetName())
    else
        ent:SetSubMaterial(slot, "")
    end
end

CH.SetEntityIris = setEntityIris
CH.FlexLabels = CH.FlexLabels or {
    nose1 = "Largeur du nez",
    nose2 = "Longueur du nez",
    jawdrop = "Hauteur de la mâchoire",
    jaw1 = "Largeur de la mâchoire",
    jaw2 = "Profondeur de la mâchoire",
    eyes = "Écart des yeux",
    mouth = "Largeur de la bouche",
    mouth2 = "Épaisseur des lèvres",
}

local FLEX_ID_CACHE = {}
local FLEX_PER_FRAME_MAX_DIST_SQ = 600 * 600  -- réduit : lip-sync inutile au-delà de 6m
local function _getFlexId(ent, name)
    if not IsValid(ent) or not ent.GetFlexIDByName then return nil end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    FLEX_ID_CACHE[mdl] = FLEX_ID_CACHE[mdl] or {}
    local cache = FLEX_ID_CACHE[mdl]
    local cached = cache[name]
    if cached ~= nil then return cached end
    local id = ent:GetFlexIDByName(name)
    if id == nil then return nil end
    cache[name] = id
    return id
end

local function applyFlex(ent, tbl)
    if not IsValid(ent) or not ent.SetFlexWeight then return end
    tbl = istable(tbl) and tbl or {}
    local changed = false
    local anyNonzero = false
    local cache = ent._verseFlexCache
    if not cache then
        cache = {}
        ent._verseFlexCache = cache
    end

    for _, name in ipairs(CH.FlexControllers) do
        local id = _getFlexId(ent, name)
        if id ~= nil then
            local v = tonumber(tbl[name]) or 0
            if v < 0 then v = 0 end
            if v > 1 then v = 1 end
            ent:SetFlexWeight(id, v)
            if v > 0 then anyNonzero = true end
            if cache[name] ~= v then
                cache[name] = v
                changed = true
            end
        end
    end

    if anyNonzero then
        if ent.SetFlexScale then ent:SetFlexScale(1) end
        if ent.CalcFlexes then pcall(ent.CalcFlexes, ent) end
    end

    if changed and ent.SetupBones then
        if ent.InvalidateBoneCache then ent:InvalidateBoneCache() end
        ent:SetupBones()
    end
end

CH.ApplyFlex = applyFlex
local EYEBROW_RUNTIME_MATERIALS = {}
local HEAD_EYEBROW_SLOT_CACHE = {}
local function _findEyebrowSlot(ent)
    if not IsValid(ent) or not ent.GetMaterials then return nil end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if mdl == "" then return nil end
    local cached = HEAD_EYEBROW_SLOT_CACHE[mdl]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local mats = ent:GetMaterials() or {}
    for i, matName in ipairs(mats) do
        local lower = string.lower(tostring(matName or ""))
        if string.find(lower, "pilo", 1, true) then
            HEAD_EYEBROW_SLOT_CACHE[mdl] = i - 1
            return i - 1
        end
    end
    return nil
end

local function _getEyebrowRuntimeMat(color)
    local r, g, b = 255, 255, 255
    if IsColor(color) then
        r = math.Clamp(math.floor(tonumber(color.r) or 255), 0, 255)
        g = math.Clamp(math.floor(tonumber(color.g) or 255), 0, 255)
        b = math.Clamp(math.floor(tonumber(color.b) or 255), 0, 255)
    end

    local key = string.format("%d,%d,%d", r, g, b)
    local cached = EYEBROW_RUNTIME_MATERIALS[key]
    if cached and not cached:IsError() then return cached end
    local name = "verse__char__eyebrow_tint_v4_" .. string.gsub(key, ",", "_")
    local mat = CreateMaterial(name, "VertexLitGeneric", {
        ["$model"] = 1,
        ["$basetexture"] = "verse/head/verse_pilo",
        ["$lightwarptexture"] = "verse/shared/toon",
        ["$nocull"] = 1,
        ["$alphatest"] = 1,
        ["$alphatestreference"] = 0.05,
        ["$color2"] = string.format("[%.4f %.4f %.4f]", r / 255, g / 255, b / 255),
    })

    EYEBROW_RUNTIME_MATERIALS[key] = mat
    return mat
end

local function setEntityEyebrowColor(ent, color)
    if not IsValid(ent) or not ent.SetSubMaterial then return end
    local slot = _findEyebrowSlot(ent)
    if slot == nil then return end
    local mat = _getEyebrowRuntimeMat(color)
    if mat and not mat:IsError() then
        ent:SetSubMaterial(slot, "!" .. mat:GetName())
    else
        ent:SetSubMaterial(slot, "")
    end
end

CH.SetEntityEyebrowColor = setEntityEyebrowColor

-- ── Système couleur des cils ───────────────────────────────────────────────────
local EYELASH_RUNTIME_MATERIALS = {}
local HEAD_EYELASH_SLOT_CACHE   = {}   -- invalidé si le modèle change de matériaux
local DEFAULT_EYELASH_COLOR     = Color(0, 0, 0, 255)

local function _findEyelashSlot(ent)
    if not IsValid(ent) or not ent.GetMaterials then return nil end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if mdl == "" then return nil end
    local cached = HEAD_EYELASH_SLOT_CACHE[mdl]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local mats = ent:GetMaterials() or {}
    -- Si la liste est vide le modèle n'est pas encore chargé par le moteur :
    -- on ne met PAS en cache (false) afin de réessayer au prochain appel.
    if #mats == 0 then return nil end

    for i, matName in ipairs(mats) do
        local lower = string.lower(tostring(matName or ""))
        -- Recherche "cil" / "lash" / "verse_detail" (verse_details = texture des cils)
        -- NOTE : "detail" seul est trop générique (skin_detail, normal_detail…).
        -- "verse_detail" cible uniquement verse/head/verse_details.
        if string.find(lower, "cil", 1, true) or string.find(lower, "lash", 1, true) or string.find(lower, "verse_detail", 1, true) then
            HEAD_EYELASH_SLOT_CACHE[mdl] = i - 1
            return i - 1
        end
    end

    -- Le modèle est chargé (liste non vide) mais aucun slot cils trouvé → cache définitif.
    HEAD_EYELASH_SLOT_CACHE[mdl] = false
    return nil
end

local function _getEyelashRuntimeMat(color)
    local r, g, b = 0, 0, 0
    if IsColor(color) then
        r = math.Clamp(math.floor(tonumber(color.r) or 0), 0, 255)
        g = math.Clamp(math.floor(tonumber(color.g) or 0), 0, 255)
        b = math.Clamp(math.floor(tonumber(color.b) or 0), 0, 255)
    end

    local key = string.format("%d,%d,%d", r, g, b)
    local cached = EYELASH_RUNTIME_MATERIALS[key]
    if cached and not cached:IsError() then return cached end
    -- v6 : modèle d'éclairage IDENTIQUE aux CHEVEUX (VertexLitGeneric + lightwarp
    -- toon + couleur via $color2), au lieu de $selfillum. Ainsi les cils réagissent
    -- à la lumière exactement comme les cheveux (cohérence demandée) au lieu d'afficher
    -- une couleur plate auto-illuminée.
    -- $alphatest masque les pixels hors-cils (alpha < 0.05) ; $color2 multiplie la
    -- texture par la couleur choisie (comme la teinte des cheveux sur verse_hair).
    local name = "verse__char__eyelash_tint_v6_" .. string.gsub(key, ",", "_")
    local mat = CreateMaterial(name, "VertexLitGeneric", {
        ["$model"]             = 1,
        ["$basetexture"]       = "verse/head/verse_details",
        ["$nocull"]            = 1,
        ["$alphatest"]         = 1,
        ["$alphatestreference"]= 0.05,
        ["$lightwarptexture"]  = "slayde_jjk/shared/lightwarpshader",
        ["$color2"]            = string.format("[%.4f %.4f %.4f]", r / 255, g / 255, b / 255),
    })

    EYELASH_RUNTIME_MATERIALS[key] = mat
    return mat
end

-- Retourne true si le sub-material a bien été appliqué (ou si le modèle n'a
-- définitivement pas de slot cils), false uniquement si le modèle n'est pas
-- encore chargé et qu'il faut réessayer au prochain frame.
-- Règle : l'appelant NE doit mettre à jour son sig QUE si la valeur est true.
local function setEntityEyelashColor(ent, color)
    if not IsValid(ent) or not ent.SetSubMaterial then return false end
    local slot = _findEyelashSlot(ent)
    if slot == nil then
        -- Distinguer "modèle pas encore chargé" de "modèle sans slot cils" :
        --   • cache == nil  → pas encore scanné / liste matériaux vide → réessayer (false)
        --   • cache == false → slot définitivement absent sur ce modèle → rien à faire,
        --     on retourne true pour mémoriser le sig et ne JAMAIS réessayer (évite
        --     des centaines d'appels/seconde pour les modèles sans texture cils).
        local mdl = string.lower(tostring(ent:GetModel() or ""))
        if HEAD_EYELASH_SLOT_CACHE[mdl] == false then return true end
        return false
    end
    local mat = _getEyelashRuntimeMat(color or DEFAULT_EYELASH_COLOR)
    if mat and not mat:IsError() then
        ent:SetSubMaterial(slot, "!" .. mat:GetName())
    else
        ent:SetSubMaterial(slot, "")
    end
    return true
end

CH.SetEntityEyelashColor = setEntityEyelashColor

-- ConCommand de diagnostic : dump les matériaux du headEnt du joueur local
-- et force un re-scan + re-application immédiate de la couleur des cils.
-- Usage console : verse_debug_eyelash
concommand.Add("verse_debug_eyelash", function()
    if not LocalPlayer():IsSuperAdmin() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then MsgN("[EyelashDebug] Pas de joueur local.") return end

    local state = WORLD_APPEARANCE and WORLD_APPEARANCE[ply]
    if not state then MsgN("[EyelashDebug] Pas de WORLD_APPEARANCE pour le joueur local.") return end

    local headEnt = state.headEnt
    MsgN("[EyelashDebug] ── état cils ──────────────────────────────")
    MsgN("[EyelashDebug] headEnt valid    : " .. tostring(IsValid(headEnt)))
    MsgN("[EyelashDebug] eyelashColor     : " .. tostring(state.eyelashColor))
    MsgN("[EyelashDebug] appliedEyelashSig: " .. tostring(state.appliedEyelashSig))

    -- Valeur brute du NW var serveur → client
    local nw = CH.AppearanceNW or {}
    local rawNW = (ply.GetPublicString and nw.EyelashColor and ply:GetPublicString(nw.EyelashColor, "<<ABSENT>>")) or "<<ABSENT>>"
    MsgN("[EyelashDebug] NW EyelashColor  : '" .. rawNW .. "'")

    -- Valeur dans CH.Client.selected (packet Selected)
    local selColor = istable(CH.Client) and istable(CH.Client.selected) and CH.Client.selected.eyelash_color or "<<ABSENT>>"
    MsgN("[EyelashDebug] Selected.eyelash_color: '" .. tostring(selColor) .. "'")

    if not IsValid(headEnt) then MsgN("[EyelashDebug] Pas de headEnt.") return end

    local mdl = string.lower(tostring(headEnt:GetModel() or ""))
    MsgN("[EyelashDebug] modèle           : " .. mdl)
    MsgN("[EyelashDebug] cache slot       : " .. tostring(HEAD_EYELASH_SLOT_CACHE[mdl]))

    local mats = headEnt:GetMaterials() or {}
    MsgN("[EyelashDebug] GetMaterials() (" .. #mats .. " slots):")
    for i, m in ipairs(mats) do
        MsgN("  [" .. (i-1) .. "] " .. tostring(m))
    end

    -- Réinitialise le cache et force un re-scan + re-application immédiate
    HEAD_EYELASH_SLOT_CACHE[mdl] = nil
    state.appliedEyelashSig = nil
    local ok = setEntityEyelashColor(headEnt, state.eyelashColor or DEFAULT_EYELASH_COLOR)
    MsgN("[EyelashDebug] Re-application   : " .. (ok and "OK (slot trouvé)" or "ÉCHOUÉ (slot introuvable)"))
    MsgN("[EyelashDebug] cache après scan : " .. tostring(HEAD_EYELASH_SLOT_CACHE[mdl]))
end, nil, "Diagnostique et re-applique la couleur des cils en jeu")

-- ──────────────────────────────────────────────────────────────────────────────

local function _findHairSlotIndex(ent)
    if not IsValid(ent) or not ent.GetMaterials then return nil end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if mdl == "" then return nil end
    local cached = HEAD_HAIR_SLOT_CACHE[mdl]
    if cached ~= nil then return cached end
    local mats = ent:GetMaterials() or {}
    for i, matName in ipairs(mats) do
        local lower = string.lower(tostring(matName or ""))
        local isHair = (string.find(lower, "hair", 1, true) and not string.find(lower, "chair", 1, true)) or string.find(lower, "cheveux", 1, true) or string.find(lower, "cheveu", 1, true) or string.find(lower, "verse_hair", 1, true)
        if isHair then
            HEAD_HAIR_SLOT_CACHE[mdl] = i - 1
            return i - 1
        end
    end

    HEAD_HAIR_SLOT_CACHE[mdl] = false
    return nil
end

local function _getTintedHairMaterial(color)
    if not IsColor(color) then return nil end
    local r, g, b, a = color.r or 255, color.g or 255, color.b or 255, color.a or 255
    local key = string.format("%d,%d,%d,%d", r, g, b, a)
    local cached = HAIR_RUNTIME_MATERIALS[key]
    if cached and not cached:IsError() then return cached end
    local runtimeName = "verse__char__hair_" .. string.gsub(key, ",", "_")
    local mat = CreateMaterial(runtimeName, "VertexLitGeneric", {
        ["$model"] = 1,
        ["$basetexture"] = "verse/head/verse_hair",
        ["$bumpmap"] = "slayde_jjk/shared/normal",
        ["$lightwarptexture"] = "slayde_jjk/shared/lightwarpshader",
        ["$color2"] = string.format("[%.4f %.4f %.4f]", r / 255, g / 255, b / 255),
    })

    HAIR_RUNTIME_MATERIALS[key] = mat
    return mat
end

local function setEntityHairColor(ent, color)
    if not IsValid(ent) or not ent.SetSubMaterial then return end
    local slot = _findHairSlotIndex(ent)
    if slot == nil then return end
    if not IsColor(color) then
        ent:SetSubMaterial(slot, "")
        return
    end

    local mat = _getTintedHairMaterial(color)
    if mat and not mat:IsError() then
        ent:SetSubMaterial(slot, "!" .. mat:GetName())
    else
        ent:SetSubMaterial(slot, "")
    end
end

CH.SetEntityHairColor = setEntityHairColor

-- ─── EXPÉRIMENTAL : dégradé de couleur des cheveux (test serveur exo) ─────────
-- Génère une texture de cheveux teintée en dégradé vertical (c2 en haut → c1 en
-- bas) via un render target : on dessine la texture cheveux puis on la multiplie
-- par un dégradé de couleur. Le résultat sert de $basetexture au matériau cheveux.
-- Indépendant de l'UV exact du modèle (le dégradé suit l'UV vertical de la texture).
local function _getGradientHairMaterial(c1, c2)
    if not IsColor(c1) then return nil end
    c2 = IsColor(c2) and c2 or c1
    local key = string.format("grad_%d_%d_%d__%d_%d_%d", c1.r, c1.g, c1.b, c2.r, c2.g, c2.b)
    local cached = HAIR_RUNTIME_MATERIALS[key]
    if cached and not cached:IsError() then return cached end

    -- Pendant la passe de rendu principale, on ne peut pas push un render target
    -- (imbrication) : on diffère la génération à un Think et on renvoie nil.
    if _inMainRender then
        _hairGradGenQueue[key] = { c1, c2 }
        return nil
    end

    -- Matériau brut de la texture cheveux (pour la dessiner dans le RT)
    local baseMat = HAIR_RUNTIME_MATERIALS["_hairbase_unlit"]
    if not baseMat then
        baseMat = CreateMaterial("verse__hairgrad_basetex", "UnlitGeneric", {
            ["$basetexture"] = "verse/head/verse_hair",
        })
        HAIR_RUNTIME_MATERIALS["_hairbase_unlit"] = baseMat
    end

    local SZ = 1024  -- = résolution de la texture cheveux d'origine (détail des mèches préservé)
    local rt = GetRenderTargetEx("verse_hairgrad_" .. key, SZ, SZ,
        RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, bit.bor(2, 256), 0, IMAGE_FORMAT_RGBA8888)

    render.PushRenderTarget(rt)
        render.Clear(0, 0, 0, 255, true, true)
        cam.Start2D()
            -- 1) Dégradé vertical LISSE et OPAQUE (une ligne de 1px par rangée).
            -- Opaque → les rangées se recouvrent sans jamais s'assombrir : aucune
            -- jointure visible (haut = c2 = racines, bas = c1 = pointes).
            draw.NoTexture()
            for y = 0, SZ - 1 do
                local t = y / (SZ - 1)
                surface.SetDrawColor(
                    math.floor(Lerp(t, c2.r, c1.r)),
                    math.floor(Lerp(t, c2.g, c1.g)),
                    math.floor(Lerp(t, c2.b, c1.b)),
                    255)
                surface.DrawRect(0, y, SZ, 1)
            end
            -- 2) Multiplie la texture cheveux par-dessus, EN UNE SEULE PASSE.
            -- result = dst(dégradé) * src(texture) → un seul multiply, pas de seams.
            render.OverrideBlend(true, BLEND_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(baseMat)
            surface.DrawTexturedRect(0, 0, SZ, SZ)
            render.OverrideBlend(false)
        cam.End2D()
    render.PopRenderTarget()

    -- Matche le VMT d'origine (verse/head/verse_hair.vmt) : toon lightwarp + nocull.
    local mat = CreateMaterial("verse__hairgradmat_" .. key, "VertexLitGeneric", {
        ["$model"] = 1,
        ["$basetexture"] = "verse/head/verse_hair",
        ["$lightwarptexture"] = "verse/shared/toon",
        ["$nocull"] = 1,
    })
    mat:SetTexture("$basetexture", rt)
    HAIR_RUNTIME_MATERIALS[key] = mat
    return mat
end

-- Retourne true UNIQUEMENT si le dégradé a été appliqué (slot trouvé + matériau
-- prêt). Si le matériau n'est pas encore généré (différé hors rendu), retourne
-- false pour que l'appelant réessaie au prochain frame.
local function setEntityHairGradient(ent, c1, c2)
    if not IsValid(ent) or not ent.SetSubMaterial then return false end
    local slot = _findHairSlotIndex(ent)
    if slot == nil then return false end
    local mat = _getGradientHairMaterial(c1, c2)
    if mat and not mat:IsError() then
        ent:SetSubMaterial(slot, "!" .. mat:GetName())
        return true
    end
    return false
end
CH.SetEntityHairGradient = setEntityHairGradient

-- Commande de test : applique un dégradé sur la tête du joueur LOCAL (en jeu).
-- Usage : verse_test_hairgrad <r_bas> <g_bas> <b_bas> <r_haut> <g_haut> <b_haut>
-- Exemple (noir → violet) : verse_test_hairgrad 15 10 25 170 60 220
concommand.Add("verse_test_hairgrad", function(_, _, args)
    if not LocalPlayer():IsSuperAdmin() then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local state = WORLD_APPEARANCE[lp]
    local head  = state and state.headEnt
    if not IsValid(head) then
        print("[HairGradient] Aucune tête trouvée. Sois en jeu avec un perso (pas en création).")
        return
    end
    local c1 = Color(tonumber(args[1]) or 15,  tonumber(args[2]) or 10,  tonumber(args[3]) or 25)
    local c2 = Color(tonumber(args[4]) or 170, tonumber(args[5]) or 60,  tonumber(args[6]) or 220)
    -- Pré-génère le render target MAINTENANT (hors rendu de scène) pour éviter un
    -- push de RT imbriqué dans PostPlayerDraw. Le matériau sera ensuite en cache.
    local mat = _getGradientHairMaterial(c1, c2)
    if not mat or mat:IsError() then
        print("[HairGradient] Échec de génération du matériau dégradé.")
        return
    end
    -- Active le dégradé dans la boucle de rendu (PostPlayerDraw l'applique chaque frame).
    state.hairGradient = { c1, c2 }
    state.appliedHairColorSig = nil  -- force la ré-application immédiate
    print("[HairGradient] Dégradé activé — bas: " .. tostring(c1) .. "  haut: " .. tostring(c2))
end)

-- Désactive le dégradé et revient à la couleur unie.
concommand.Add("verse_test_hairgrad_off", function()
    if not LocalPlayer():IsSuperAdmin() then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local state = WORLD_APPEARANCE[lp]
    if state then
        state.hairGradient = nil
        state.appliedHairColorSig = nil
    end
    print("[HairGradient] Dégradé désactivé.")
end)

-- Traite la file de génération des dégradés EN DEHORS de la passe de rendu.
-- (Générer un render target pendant PrePlayerDraw/PostDrawModel = push imbriqué.)
hook.Add("Think", "VERSE::Characters::HairGradGenQueue", function()
    if _inMainRender then return end
    local key = next(_hairGradGenQueue)
    if not key then return end
    local pair = _hairGradGenQueue[key]
    _hairGradGenQueue[key] = nil
    if pair then _getGradientHairMaterial(pair[1], pair[2]) end
end)

local function normalizeAppearanceModelPath(mdl)
    mdl = string.Trim(tostring(mdl or ""))
    if mdl == "" then return "" end
    return string.lower(string.gsub(mdl, "\\", "/"))
end

local function isFaceControlModel(mdl)
    if CH.HasFaceMaterialControls then return CH:HasFaceMaterialControls(mdl) end
    local path = normalizeAppearanceModelPath(mdl)
    return path == "models/verse/head/base_head1.mdl" or path == "models/verse/head/base_head10.mdl"
end

local function getEyebrowStyleCount()
    if CH.GetEyebrowStyleCount then return CH:GetEyebrowStyleCount() end
    local materials = CH.FaceEyebrowMaterials
    if not istable(materials) or #materials <= 0 then return 1 end
    return #materials
end

local function getEyebrowMaterialPath(style)
    if CH.GetEyebrowMaterialPath then return CH:GetEyebrowMaterialPath(style) end
    local materials = CH.FaceEyebrowMaterials
    if not istable(materials) or #materials <= 0 then return "" end
    local index = math.Clamp(math.floor(tonumber(style) or 1), 1, #materials)
    return tostring(materials[index] or materials[1] or "")
end

local function getEyeStyleCount()
    if CH.GetEyeStyleCount then return CH:GetEyeStyleCount() end
    local materials = CH.FaceEyeMaterials
    if not istable(materials) or #materials <= 0 then return 1 end
    return #materials
end

local function getEyeMaterialPath(style)
    if CH.GetEyeMaterialPath then return CH:GetEyeMaterialPath(style) end
    local materials = CH.FaceEyeMaterials
    if not istable(materials) or #materials <= 0 then return "" end
    local index = math.Clamp(math.floor(tonumber(style) or 1), 1, #materials)
    return tostring(materials[index] or materials[1] or "")
end

local function normalizeMaterialPath(matName)
    matName = string.Trim(tostring(matName or ""))
    if matName == "" then return "" end
    matName = string.lower(tostring(matName or ""))
    matName = string.gsub(matName, "\\", "/")
    matName = string.gsub(matName, "%.vmt$", "")
    matName = string.gsub(matName, "%.vtf$", "")
    if string.sub(matName, 1, 10) == "materials/" then matName = string.sub(matName, 11) end
    return matName
end

local function normalizeMaterialPathRaw(matName)
    matName = string.Trim(tostring(matName or ""))
    if matName == "" then return "" end
    matName = string.gsub(matName, "\\", "/")
    matName = string.gsub(matName, "%.vmt$", "")
    matName = string.gsub(matName, "%.vtf$", "")
    if string.sub(string.lower(matName), 1, 10) == "materials/" then matName = string.sub(matName, 11) end
    return matName
end

local FACE_MATERIAL_CLASS_CACHE = {}
local function classifyFaceMaterialKind(matName)
    local rawName = normalizeMaterialPathRaw(matName)
    local normalizedName = normalizeMaterialPath(rawName)
    if normalizedName == "" then return false, false end
    local cached = FACE_MATERIAL_CLASS_CACHE[normalizedName]
    if cached then return cached.isEye, cached.isEyebrow end
    local function matchPupil(name)
        if not name or name == "" then return false end
        if string.find(name, "back_eyes", 1, true) then return false end
        if string.find(name, "pupils", 1, true) then return true end
        if string.find(name, "pupil", 1, true) then return true end
        if string.find(name, "iris", 1, true) then return true end
        if string.find(name, "/eyes", 1, true) then return true end
        return false
    end

    local isEye = matchPupil(normalizedName)
    local isEyebrow = string.find(normalizedName, "/eyebrow", 1, true) ~= nil or string.find(normalizedName, "eyebrow", 1, true) ~= nil
    if not isEye or not isEyebrow then
        local mat = Material(rawName)
        if (not mat or mat:IsError()) and rawName ~= normalizedName then mat = Material(normalizedName) end
        if mat and not mat:IsError() and mat.GetTexture then
            local baseTex = mat:GetTexture("$basetexture")
            local baseTexName = baseTex and baseTex.GetName and normalizeMaterialPath(baseTex:GetName()) or ""
            if baseTexName ~= "" then
                if not isEye then isEye = matchPupil(baseTexName) end
                if not isEyebrow then isEyebrow = string.find(baseTexName, "/eyebrow", 1, true) ~= nil or string.find(baseTexName, "eyebrow", 1, true) ~= nil end
            end
        end
    end

    FACE_MATERIAL_CLASS_CACHE[normalizedName] = {
        isEye = isEye,
        isEyebrow = isEyebrow,
    }
    return isEye, isEyebrow
end

local BODY_MARK_LAYER_MATERIALS = {}
-- Opacité par nom de matériau (0..1). Appliquée au DESSIN via render.SetBlend,
-- car le pass opaque (où les tatouages sont dessinés) ignore le $alpha du matériau.
local BODY_MARK_MAT_OPACITY = {}
local BODY_MARK_LAYER_HIDDEN_MATERIAL = nil
local BODY_MARK_TEXTURE_PATH_CACHE = {}
local BODY_MARK_OFFSET_MIN = (CH and CH.BODY_MARK_OFFSET_MIN) or -300
local BODY_MARK_OFFSET_MAX = (CH and CH.BODY_MARK_OFFSET_MAX) or 300
local BODY_MARK_DEPTH_MIN = (CH and CH.BODY_MARK_DEPTH_MIN) or -200
local BODY_MARK_DEPTH_MAX = (CH and CH.BODY_MARK_DEPTH_MAX) or 200
local BODY_MARK_SIZE_MIN = (CH and CH.BODY_MARK_SIZE_MIN) or -50
local BODY_MARK_SIZE_MAX = (CH and CH.BODY_MARK_SIZE_MAX) or 50
local BODY_MARK_DEFAULT_X = (CH and CH.BODY_MARK_DEFAULT_X) or 0
local BODY_MARK_DEFAULT_Y = (CH and CH.BODY_MARK_DEFAULT_Y) or 0
local BODY_MARK_DEFAULT_Z = (CH and CH.BODY_MARK_DEFAULT_Z) or -5
local BODY_MARK_DEFAULT_ROTATE = (CH and CH.BODY_MARK_DEFAULT_ROT) or 0
local BODY_MARK_DEFAULT_SIZE = (CH and CH.BODY_MARK_DEFAULT_SIZE) or 24
local BODY_MARK_SIZE_SCALE_BASE = 30
local BODY_MARK_LAYER_SCALE_BIAS = 1.0015
local BODY_MARK_LAYER_SCALE_STEP = 0.0050
local BODY_MARK_LAYER_DEPTH_MAX = 0.99999
local BODY_MARK_LAYER_MATERIAL_REV = "v29"
-- Couleurs pré-allouées pour drawBodyMarkLayerSetWorld (évite des allocations chaque frame).
local BODY_MARK_COLOR_HIDE = Color(255, 255, 255, 0)
local BODY_MARK_COLOR_SHOW = Color(255, 255, 255, 255)
local MENU_FACE_SLOTS_CACHE = {} -- cache faceSlots par chemin de modèle (menu context)
local BODY_MARK_UV_SCALE_AT_MIN = 8.0
local BODY_MARK_UV_SCALE_AT_MAX = 0.22
local SPIRIT_ACCESSORY_POSITION_SCALE = 0.03
local SPIRIT_ACCESSORY_SIZE_BASE = 24
local SPIRIT_ACCESSORY_SCALE_MIN = 0.2
local SPIRIT_ACCESSORY_SCALE_MAX = 4
local function parseResolvedBodyMarks(value)
    if istable(value) then return value end
    if not isstring(value) or value == "" then return {} end
    local parsed = util.JSONToTable(value)
    if istable(parsed) then return parsed end
    return {}
end

local function getBodyMarkDepthMax(zValue)
    local z = tonumber(zValue) or BODY_MARK_DEFAULT_Z
    return math.Clamp(0.9993 - (z * 0.00005), 0.9982, 0.99995)
end

local function isEyeMaterialName(matName)
    local isEye = classifyFaceMaterialKind(matName)
    return isEye == true
end

local function isEyebrowMaterialName(matName)
    local _, isEyebrow = classifyFaceMaterialKind(matName)
    return isEyebrow == true
end

local function isSkinMaterialNameBase(matName)
    matName = normalizeMaterialPath(matName)
    if matName == "" then return false end
    if isEyeMaterialName(matName) or isEyebrowMaterialName(matName) then return false end
    if string.find(matName, "slayde_jjk/face/", 1, true) ~= nil then return true end
    if string.find(matName, "slayde_jjk/base/peau_", 1, true) ~= nil then return true end
    if string.find(matName, "peau", 1, true) ~= nil then return true end
    if string.match(matName, "^face_%d+$") ~= nil then return true end
    if string.find(matName, "_skin", 1, true) ~= nil then return true end
    return false
end

local SKIN_RUNTIME_MATERIALS = {}
local HEAD_SKIN_SLOT_CACHE = {}
local function _getTintedSkinMaterial(baseMatName, color)
    if not isstring(baseMatName) or baseMatName == "" then return nil end
    if not IsColor(color) then return nil end
    local r, g, b = color.r or 255, color.g or 255, color.b or 255
    local keyMat = string.lower(baseMatName)
    local key = keyMat .. "|" .. string.format("%d,%d,%d", r, g, b)
    local cached = SKIN_RUNTIME_MATERIALS[key]
    if cached and not cached:IsError() then return cached end
    local baseMat = Material(baseMatName)
    local baseTex = "verse/head/verse_skin"
    if baseMat and not baseMat:IsError() and baseMat.GetTexture then
        local tex = baseMat:GetTexture("$basetexture")
        if tex and tex.GetName then baseTex = tex:GetName() end
    end

    local runtimeName = "verse__char__skin_" .. string.gsub(key, "[^%w]+", "_")
    local mat = CreateMaterial(runtimeName, "VertexLitGeneric", {
        ["$model"] = 1,
        ["$basetexture"] = baseTex,
        ["$lightwarptexture"] = "verse/shared/toon",
        ["$nocull"] = 1,
        ["$color2"] = string.format("[%.4f %.4f %.4f]", r / 255, g / 255, b / 255),
        ["$color"] = string.format("[%.4f %.4f %.4f]", r / 255, g / 255, b / 255),
    })

    SKIN_RUNTIME_MATERIALS[key] = mat
    return mat
end

local function setEntitySkinColorRuntime(ent, color)
    if not IsValid(ent) or not ent.GetMaterials or not ent.SetSubMaterial then return end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if mdl == "" then return end
    local cachedSlots = HEAD_SKIN_SLOT_CACHE[mdl]
    if cachedSlots == nil then
        cachedSlots = {}
        for i, matName in ipairs(ent:GetMaterials() or {}) do
            if isSkinMaterialNameBase(matName) then
                cachedSlots[#cachedSlots + 1] = {
                    slot = i - 1,
                    name = matName
                }
            end
        end

        HEAD_SKIN_SLOT_CACHE[mdl] = cachedSlots
    end

    if not IsColor(color) then
        for _, s in ipairs(cachedSlots) do
            ent:SetSubMaterial(s.slot, "")
        end
        return
    end

    for _, s in ipairs(cachedSlots) do
        local mat = _getTintedSkinMaterial(s.name, color)
        if mat and not mat:IsError() then
            ent:SetSubMaterial(s.slot, "!" .. mat:GetName())
        else
            ent:SetSubMaterial(s.slot, "")
        end
    end
end

CH.SetEntitySkinColorRuntime = setEntitySkinColorRuntime
local function isMouthTeethMaterialName(matName)
    -- Exclut explicitement les matériaux de dents/bouche/langue de l'application du tatouage.
    if string.find(matName, "teeth",   1, true) ~= nil then return true end
    if string.find(matName, "tooth",   1, true) ~= nil then return true end
    if string.find(matName, "mouth",   1, true) ~= nil then return true end
    if string.find(matName, "bouche",  1, true) ~= nil then return true end
    if string.find(matName, "tongue",  1, true) ~= nil then return true end
    if string.find(matName, "langue",  1, true) ~= nil then return true end
    if string.find(matName, "gum",     1, true) ~= nil then return true end
    if string.find(matName, "gencive", 1, true) ~= nil then return true end
    if string.find(matName, "throat",  1, true) ~= nil then return true end
    if string.find(matName, "gorge",   1, true) ~= nil then return true end
    if string.find(matName, "jaw",     1, true) ~= nil then return true end
    if string.find(matName, "machoire",1, true) ~= nil then return true end
    if string.find(matName, "lip",     1, true) ~= nil then return true end
    if string.find(matName, "levre",   1, true) ~= nil then return true end
    -- Intérieur bouche / cavité (noms anglais courants sur modèles anime/JJK)
    if string.find(matName, "inner",   1, true) ~= nil then return true end
    if string.find(matName, "inside",  1, true) ~= nil then return true end
    if string.find(matName, "oral",    1, true) ~= nil then return true end
    if string.find(matName, "cavity",  1, true) ~= nil then return true end
    if string.find(matName, "dental",  1, true) ~= nil then return true end
    if string.find(matName, "chin",    1, true) ~= nil then return true end
    if string.find(matName, "menton",  1, true) ~= nil then return true end
    if string.find(matName, "neck",    1, true) ~= nil then return true end
    if string.find(matName, "cou",     1, true) ~= nil then return true end
    return false
end

local function isBodyMarkFaceMaterialName(matName)
    matName = normalizeMaterialPath(matName)
    if matName == "" then return false end
    if isEyeMaterialName(matName) or isEyebrowMaterialName(matName) then return false end
    -- Exclure dents/bouche/langue avant les tests inclusifs
    if isMouthTeethMaterialName(matName) then return false end
    if isSkinMaterialNameBase(matName) then return true end
    if string.find(matName, "slayde_jjk/face/", 1, true) ~= nil then return true end
    if string.find(matName, "/face", 1, true) ~= nil then return true end
    if string.match(matName, "^face_%d+$") ~= nil then return true end
    if string.find(matName, "_skin", 1, true) ~= nil then return true end
    return false
end

local function clearBodyMarkLayerSet(layerSet)
    if not istable(layerSet) then return {} end
    for key, ent in pairs(layerSet) do
        if isstring(key) and string.sub(key, 1, 2) == "__" then
            layerSet[key] = nil
        else
            if IsValid(ent) then ent:Remove() end
            layerSet[key] = nil
        end
    end
    return layerSet
end

local BODY_MARK_ENABLED_CVAR = CreateClientConVar("verse_char_body_marks", "1", true, false, "0 = disable body marks for perf")
local BODY_MARK_DIST_CVAR = CreateClientConVar("verse_char_body_marks_dist", "500", true, false, "Max distance to render body marks")
local BODY_MARK_DOT_THRESHOLD = 0.2
-- getMenuFaceSlots : retourne (et cache) les indices de slots "face/peau" pour le modèle de headEnt.
-- Utilisé par syncBodyMarkLayerSet en contexte menu (v28) pour éviter de créer une entité-layer.
local BODY_MARK_DEBUG_CVAR = CreateClientConVar("verse_bodymark_debug", "0", false, false, "1 = affiche les noms de matériaux des slots de tatouage dans la console")
local function getMenuFaceSlots(headEnt)
    if not IsValid(headEnt) then return {} end
    local modelPath = string.lower(tostring(headEnt:GetModel() or ""))
    if modelPath == "" then return {} end
    local debug = BODY_MARK_DEBUG_CVAR:GetBool()
    local cached = MENU_FACE_SLOTS_CACHE[modelPath]
    if cached then
        if debug then
            MsgN("[BodyMark] getMenuFaceSlots (cache) pour " .. modelPath .. " = slots: " .. table.concat(cached, ", "))
        end
        return cached
    end
    local materials = headEnt:GetMaterials() or {}
    local faceSlots = {}
    if debug then MsgN("[BodyMark] getMenuFaceSlots pour " .. modelPath .. " (" .. #materials .. " slots) :") end
    for slotIndex, baseMatName in ipairs(materials) do
        local included = isBodyMarkFaceMaterialName(baseMatName)
        if debug then
            MsgN(string.format("  slot %d : %s  -> %s", slotIndex - 1, tostring(baseMatName), included and "INCLUS" or "exclu"))
        end
        if included then
            faceSlots[#faceSlots + 1] = slotIndex - 1
        end
    end
    if debug then MsgN("[BodyMark] faceSlots = " .. table.concat(faceSlots, ", ")) end
    MENU_FACE_SLOTS_CACHE[modelPath] = faceSlots
    return faceSlots
end

-- verse_bodymark_clearcache : vide le cache des face-slots pour forcer une réanalyse.
concommand.Add("verse_bodymark_clearcache", function()
    if not LocalPlayer():IsSuperAdmin() then return end
    MENU_FACE_SLOTS_CACHE = {}
    MsgN("[BodyMark] Cache vidé. Rouvre le menu de personnage pour voir les slots.")
end)

-- verse_bodymark_dump : affiche le contenu actuel du cache (même si buildé sans debug activé).
concommand.Add("verse_bodymark_dump", function()
    if not LocalPlayer():IsSuperAdmin() then return end
    local count = 0
    for mdl, slots in pairs(MENU_FACE_SLOTS_CACHE) do
        count = count + 1
        MsgN("[BodyMark] DUMP " .. mdl .. " → slots: " .. table.concat(slots, ", "))
    end
    if count == 0 then
        MsgN("[BodyMark] DUMP : cache vide (ouvre le menu de personnage d'abord).")
    end
end)

-- Pré-déclaration pour que drawBodyMarkLayerSet puisse y accéder (définie après).
local getBodyMarkLayerHiddenMaterial

-- drawBodyMarkLayerSet : contexte DModelPanel (création, sélection, HUD portrait).
-- Approche v28 — dessine headEnt directement, AUCUNE entité ClientsideModel dans le menu :
--   PROBLÈME v26 : entité-layer avec $vertexalpha+$alphatest → RENDERMODE_NORMAL ignore SetColor alpha
--   → vertex alpha = 1.0 → alphatest passe → slots cheveux (bodygroup 1=0, default) s'affichent blanc.
--   PROBLÈME v27 : entité-layer encore créée par syncBodyMarkLayerSet (skipBoneMerge=true),
--   SetNoDraw(true) n'empêche PAS le rendu automatique en contexte DModelPanel → artefact toujours visible.
--
--   SOLUTION v28 :
--   • syncBodyMarkLayerSet (skipBoneMerge=true) stocke une table Lua simple {__isMenuLayer=true, ...}
--     au lieu de créer toute entité ClientsideModel → ZERO entité supplémentaire dans le monde.
--   • drawBodyMarkLayerSet détecte __isMenuLayer et redessine headEnt directement.
--   • face-slots → matériau tatouage. Slots non-visage : sub-matériaux de headEnt inchangés
--     → second rendu visuellement identique pour cheveux/yeux/etc → invisible. ✓
--   • DepthRange légèrement réduit → tatouage passe devant le premier rendu. ✓
--   • En jeu (namespace "world_") : entité ClientsideModel créée normalement via ensureBodyMarkLayerEntity.
local function drawBodyMarkLayerSet(layerSet, _ownerEnt)
    if not istable(layerSet) then return end
    if not BODY_MARK_ENABLED_CVAR:GetBool() then return end
    local frame = FrameNumber and FrameNumber() or 0
    if layerSet.__lastDrawFrame == frame then return end
    layerSet.__lastDrawFrame = frame

    local headEnt = layerSet.__headEnt
    if not IsValid(headEnt) then return end

    local sortedKeys = layerSet.__sortedKeys
    if not sortedKeys then
        sortedKeys = {}
        for k in pairs(layerSet) do
            if not (isstring(k) and string.sub(k, 1, 2) == "__") then sortedKeys[#sortedKeys + 1] = k end
        end
        table.sort(sortedKeys)
        layerSet.__sortedKeys = sortedKeys
    end

    local n = #sortedKeys
    if n <= 0 then return end

    local hiddenMat     = getBodyMarkLayerHiddenMaterial()
    local hiddenMatName = hiddenMat and not hiddenMat:IsError() and ("!" .. hiddenMat:GetName()) or nil
    for layerIdx = 1, n do
        local entry = layerSet[sortedKeys[layerIdx]]
        local mat, faceSlots, nonFaceSlots
        if istable(entry) and (entry.__isMenuLayer or entry.__isWorldLayer) then
            mat          = entry.__bodyMarkMat
            faceSlots    = entry.__faceSlots
            nonFaceSlots = entry.__nonFaceSlots
        elseif IsValid(entry) then
            mat       = entry.__bodyMarkMat
            faceSlots = entry.__faceSlots
        end
        if mat and istable(faceSlots) and #faceSlots > 0 and hiddenMatName then
            local matName = "!" .. mat:GetName()
            -- Capture les sous-matériaux ACTUELS des slots avant de les écraser.
            -- Les couleurs cheveux/sourcils/cils sont des sous-matériaux teintés ;
            -- les remettre à "" (comme avant) effaçait la teinte → cheveux blancs
            -- dès qu'un tatouage/cicatrice était dessiné. On restaure donc la valeur
            -- d'origine de chaque slot au lieu de "".
            local savedNon, savedFace
            if nonFaceSlots then
                savedNon = {}
                for i, slot in ipairs(nonFaceSlots) do savedNon[i] = headEnt:GetSubMaterial(slot) end
            end
            savedFace = {}
            for i, slot in ipairs(faceSlots) do savedFace[i] = headEnt:GetSubMaterial(slot) end

            -- Approche hiddenMat : slots non-visage invisibles via vertex alpha,
            -- slots visage avec le matériau tatouage. Élimine le bug bouche/dents.
            if nonFaceSlots then
                for _, slot in ipairs(nonFaceSlots) do headEnt:SetSubMaterial(slot, hiddenMatName) end
            end
            for _, slot in ipairs(faceSlots) do headEnt:SetSubMaterial(slot, matName) end
            headEnt:SetColor(Color(255, 255, 255, 0))
            headEnt:SetRenderMode(RENDERMODE_TRANSCOLOR)
            render.DepthRange(0, BODY_MARK_LAYER_DEPTH_MAX - (layerIdx - 1) * 0.0001)
            -- Opacité du tatouage : render.SetBlend module l'alpha au rendu (le pass
            -- opaque ignore le $alpha du matériau, mais respecte render.SetBlend).
            local _bmAlpha = BODY_MARK_MAT_OPACITY[mat:GetName()] or 1
            if _bmAlpha < 1 then render.SetBlend(_bmAlpha) end
            headEnt:DrawModel()
            if _bmAlpha < 1 then render.SetBlend(1) end
            render.DepthRange(0, 1)
            headEnt:SetColor(Color(255, 255, 255, 255))
            headEnt:SetRenderMode(RENDERMODE_NORMAL)
            -- Restaure les sous-matériaux d'origine (teintes préservées).
            if nonFaceSlots then
                for i, slot in ipairs(nonFaceSlots) do headEnt:SetSubMaterial(slot, savedNon[i] or "") end
            end
            for i, slot in ipairs(faceSlots) do headEnt:SetSubMaterial(slot, savedFace[i] or "") end
        end
    end
end

getBodyMarkLayerHiddenMaterial = function()
    local cached = BODY_MARK_LAYER_HIDDEN_MATERIAL
    if cached and not cached:IsError() then return cached end
    -- Matériau caché v9 — fonctionne dans le pass OPAQUE (où DrawModel() s'exécute).
    -- Pourquoi v1-v8 échouaient : $translucent+$alpha=0 est ignoré en pass opaque →
    --   le moteur rend le matériau comme opaque blanc (base texture blanche, alpha ignoré).
    -- Solution v9 : $vertexalpha=1 + $alphatest=1 + $alphatestreference=0.01
    --   • L'entité a SetColor(255,255,255,0) → vertex alpha = 0.
    --   • $vertexalpha=1 : le shader multiplie l'alpha texture par le vertex alpha.
    --     → alpha effectif = texture_alpha(1.0) × vertex_alpha(0.0) = 0.0
    --   • $alphatest=1 avec reference=0.01 : pixel rejeté si alpha < 0.01.
    --     → 0.0 < 0.01 → TOUS les pixels rejetés → slot complètement invisible. ✓
    -- Le matériau du tatouage (VertexLitGeneric + $translucent, sans $vertexalpha) IGNORE
    --   le vertex alpha → s'affiche normalement malgré SetColor(alpha=0) sur l'entité. ✓
    cached = CreateMaterial("verse__char__body_mark__hidden_v9", "UnlitGeneric", {
        ["$basetexture"] = "vgui/white",
        ["$vertexalpha"] = 1,
        ["$alphatest"] = 1,
        ["$alphatestreference"] = 0.01,
    })
    if cached and not cached:IsError() then
        BODY_MARK_LAYER_HIDDEN_MATERIAL = cached
        return cached
    end
    return nil
end

local function drawBodyMarkLayerSetWorld(layerSet, ownerEnt, headEnt)
    if not istable(layerSet) or not IsValid(headEnt) or not IsValid(ownerEnt) then return end
    if not BODY_MARK_ENABLED_CVAR:GetBool() then return end
    local sortedKeys = layerSet.__sortedKeys
    if not sortedKeys then
        sortedKeys = {}
        for k in pairs(layerSet) do
            if not (isstring(k) and string.sub(k, 1, 2) == "__") then sortedKeys[#sortedKeys + 1] = k end
        end
        table.sort(sortedKeys)
        layerSet.__sortedKeys = sortedKeys
    end
    local n = #sortedKeys
    if n <= 0 then return end
    if IsValid(ownerEnt) then
        local lp = LocalPlayer()
        if IsValid(lp) and lp ~= ownerEnt then
            local maxDist = BODY_MARK_DIST_CVAR:GetFloat()
            if maxDist > 0 then
                local eyePos = EyePos()
                local ownerPos = ownerEnt:GetPos()
                if eyePos:DistToSqr(ownerPos) > maxDist * maxDist then return end
                local eyeDir = EyeAngles():Forward()
                local toOwner = (ownerPos - eyePos):GetNormalized()
                if eyeDir:Dot(toOwner) < BODY_MARK_DOT_THRESHOLD then return end
            end
        end
    end

    -- Correction bug bouche/dents : au lieu de render.MaterialOverride qui applique le
    -- tatouage à TOUS les slots (y compris dents/intérieur bouche), on applique le tatouage
    -- uniquement aux face-slots déjà calculés par syncBodyMarkLayerSet (__faceSlots).
    -- Tous les autres slots sont DÉJÀ en hiddenMaterial (initialisé dans syncBodyMarkLayerSet) ;
    -- il suffit de mettre l'entité en alpha=0 pour que le matériau caché v9 (vertex alpha)
    -- rende ces slots invisibles, tandis que le matériau tatouage (sans $vertexalpha)
    -- ignore l'alpha de l'entité et s'affiche normalement.
    local hiddenMat = getBodyMarkLayerHiddenMaterial()
    local hiddenMatName = hiddenMat and not hiddenMat:IsError() and ("!" .. hiddenMat:GetName()) or nil
    for layerIdx = 1, n do
        local ent = layerSet[sortedKeys[layerIdx]]
        if IsValid(ent) then
            -- Réforcer SetNoDraw chaque frame : défense contre PAC3 / autre système
            -- qui pourrait appeler SetNoDraw(false) sur l'entité entre deux frames.
            ent:SetNoDraw(true)
            local mat       = ent.__bodyMarkMat
            local faceSlots = ent.__faceSlots
            if not mat then
                -- Pas de matériau : rien à dessiner.
            elseif istable(faceSlots) and #faceSlots > 0 and hiddenMatName then
                -- Approche par slot : tatouage uniquement sur la peau du visage.
                -- L'entité reste TOUJOURS à alpha=0 (BODY_MARK_COLOR_HIDE) :
                --   • hiddenMat + alpha=0 → vertex alpha=0 → $alphatest rejette → invisible si auto-rendu.
                --   • tatouage mat (sans $vertexalpha) → ignore alpha=0 → rendu normal via DrawModel(). ✓
                local tatMatName = "!" .. mat:GetName()
                ent:SetColor(BODY_MARK_COLOR_HIDE)
                for _, slot in ipairs(faceSlots) do
                    ent:SetSubMaterial(slot, tatMatName)
                end
                local _bmAlpha = BODY_MARK_MAT_OPACITY[mat:GetName()] or 1
                render.DepthRange(0, BODY_MARK_LAYER_DEPTH_MAX - (layerIdx - 1) * 0.0001)
                if _bmAlpha < 1 then render.SetBlend(_bmAlpha) end
                ent:DrawModel()
                if _bmAlpha < 1 then render.SetBlend(1) end
                render.DepthRange(0, 1)
                -- Restaure les face-slots sur hiddenMat : si l'entité s'auto-rend,
                -- tous les slots sont invisibles (hiddenMat + alpha=0). ✓
                for _, slot in ipairs(faceSlots) do
                    ent:SetSubMaterial(slot, hiddenMatName)
                end
                -- NE PAS restaurer BODY_MARK_COLOR_SHOW : l'entité reste à alpha=0 en permanence.
            else
                -- Fallback : MaterialOverride si face-slots non disponibles.
                ent:SetColor(BODY_MARK_COLOR_HIDE)
                local _bmAlpha = BODY_MARK_MAT_OPACITY[mat:GetName()] or 1
                render.DepthRange(0, BODY_MARK_LAYER_DEPTH_MAX - (layerIdx - 1) * 0.0001)
                render.MaterialOverride(mat)
                if _bmAlpha < 1 then render.SetBlend(_bmAlpha) end
                ent:DrawModel()
                if _bmAlpha < 1 then render.SetBlend(1) end
                render.MaterialOverride()
                render.DepthRange(0, 1)
            end
        end
    end
end


local function parseBodyMarkVMTBaseTexture(matPath)
    if not file or not file.Exists or not file.Read then return nil end
    matPath = string.Trim(tostring(matPath or ""))
    if matPath == "" then return nil end
    matPath = string.gsub(matPath, "\\", "/")
    if string.sub(string.lower(matPath), 1, 10) == "materials/" then matPath = string.sub(matPath, 11) end
    matPath = string.gsub(matPath, "%.vmt$", "")
    if matPath == "" or not file.Exists("materials/" .. matPath .. ".vmt", "GAME") then return nil end
    local raw = file.Read("materials/" .. matPath .. ".vmt", "GAME")
    if not isstring(raw) or raw == "" then return nil end
    local texturePath = string.match(raw, [["%$basetexture"%s*"([^"]+)"]]) or string.match(raw, [[%$basetexture%s*"([^"]+)"]]) or string.match(raw, [[%$basetexture%s+([%w_/%.-]+)]])
    texturePath = string.Trim(tostring(texturePath or ""))
    if texturePath == "" then return nil end
    texturePath = string.gsub(texturePath, "\\", "/")
    if string.sub(string.lower(texturePath), 1, 10) == "materials/" then texturePath = string.sub(texturePath, 11) end
    texturePath = string.gsub(texturePath, "%.vtf$", "")
    texturePath = string.gsub(texturePath, "%.png$", "")
    texturePath = string.gsub(texturePath, "%.jpg$", "")
    texturePath = string.gsub(texturePath, "%.jpeg$", "")
    if texturePath == "" then return nil end
    return texturePath
end

local function resolveBodyMarkTexturePath(path)
    local rawPath = string.Trim(tostring(path or ""))
    if rawPath == "" then return "" end
    local cacheKey = string.lower(string.gsub(rawPath, "\\", "/"))
    local cached = BODY_MARK_TEXTURE_PATH_CACHE[cacheKey]
    if cached ~= nil then return cached ~= false and cached or "" end
    local function remember(resolved)
        resolved = string.Trim(tostring(resolved or ""))
        if resolved ~= "" then resolved = string.gsub(resolved, "\\", "/") end
        if string.sub(string.lower(resolved), 1, 10) == "materials/" then resolved = string.sub(resolved, 11) end
        BODY_MARK_TEXTURE_PATH_CACHE[cacheKey] = (resolved ~= "" and resolved) or false
        return resolved
    end

    local normalizedPath = string.gsub(rawPath, "\\", "/")
    if string.sub(string.lower(normalizedPath), 1, 10) == "materials/" then normalizedPath = string.sub(normalizedPath, 11) end
    local lowerPath = string.lower(normalizedPath)
    local ext = string.match(lowerPath, "%.([%w]+)$")
    local basePath = ext and string.sub(normalizedPath, 1, #normalizedPath - (#ext + 1)) or normalizedPath
    local function extractTexture(matPath)
        matPath = string.Trim(tostring(matPath or ""))
        if matPath == "" then return nil end
        local material = Material(matPath)
        if not material or material:IsError() or not material.GetTexture then return nil end
        local texture = material:GetTexture("$basetexture")
        if not texture or not texture.GetName then return nil end
        local textureName = string.Trim(tostring(texture:GetName() or ""))
        if textureName == "" then return nil end
        return textureName
    end

    local texturePath = extractTexture(normalizedPath)
    if texturePath ~= nil and texturePath ~= "" then return remember(texturePath) end
    if basePath ~= normalizedPath then
        texturePath = extractTexture(basePath)
        if texturePath ~= nil and texturePath ~= "" then return remember(texturePath) end
    end

    local fromVMT = parseBodyMarkVMTBaseTexture(basePath)
    if fromVMT ~= nil and fromVMT ~= "" then return remember(fromVMT) end
    if ext == "png" or ext == "jpg" or ext == "jpeg" then return remember("") end
    if file.Exists("materials/" .. basePath .. ".vtf", "GAME") then return remember(basePath) end
    return remember("")
end

local function buildBodyMarkTransformKV(mark)
    local rawX = tonumber(mark.x) or BODY_MARK_DEFAULT_X
    local rawY = tonumber(mark.y) or BODY_MARK_DEFAULT_Y
    local anchorX = 0.5 + math.Clamp(rawX / 300, -0.45, 0.45)
    local anchorY = 0.5 - math.Clamp(rawY / 300, -0.45, 0.45)
    local sizeX = math.Clamp(tonumber(mark.size_x) or tonumber(mark.size) or BODY_MARK_DEFAULT_SIZE, BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
    local sizeY = math.Clamp(tonumber(mark.size_y) or tonumber(mark.size) or BODY_MARK_DEFAULT_SIZE, BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
    local range = math.max(1, BODY_MARK_SIZE_MAX - BODY_MARK_SIZE_MIN)
    local fX = math.Clamp((sizeX - BODY_MARK_SIZE_MIN) / range, 0, 1)
    local fY = math.Clamp((sizeY - BODY_MARK_SIZE_MIN) / range, 0, 1)
    local uvX = Lerp(fX, BODY_MARK_UV_SCALE_AT_MIN, BODY_MARK_UV_SCALE_AT_MAX)
    local uvY = Lerp(fY, BODY_MARK_UV_SCALE_AT_MIN, BODY_MARK_UV_SCALE_AT_MAX)
    local rotate = tonumber(mark.rotate) or BODY_MARK_DEFAULT_ROTATE
    return string.format("center %.4f %.4f scale %.4f %.4f rotate %.4f translate %.4f %.4f", anchorX, anchorY, uvX, uvY, rotate, 0.5 - anchorX, 0.5 - anchorY)
end

local BODY_MARK_TEXTURE_PRELOADED = {}
local function preloadBodyMarkTexture(path)
    if BODY_MARK_TEXTURE_PRELOADED[path] then return end
    Material(path, "smooth alphatest clamp s t")
    BODY_MARK_TEXTURE_PRELOADED[path] = true
end

local function getBodyMarkLayerMaterial(namespace, markId, materialPath, mark)
    local texturePath = resolveBodyMarkTexturePath(materialPath)
    if texturePath == "" then return nil end
    preloadBodyMarkTexture(texturePath)
    local r, g, b = 0, 0, 0
    local rawCol = mark and mark.color
    if isstring(rawCol) and rawCol ~= "" then
        local rr, gg, bb = string.match(rawCol, "^(%d+),(%d+),(%d+)$")
        if rr then r, g, b = math.Clamp(tonumber(rr) or 0, 0, 255), math.Clamp(tonumber(gg) or 0, 0, 255), math.Clamp(tonumber(bb) or 0, 0, 255) end
    elseif IsColor(rawCol) then
        r, g, b = math.Clamp(math.floor(rawCol.r or 0), 0, 255), math.Clamp(math.floor(rawCol.g or 0), 0, 255), math.Clamp(math.floor(rawCol.b or 0), 0, 255)
    end

    local qSize = math.floor(tonumber(mark.size) or 0)
    local qSizeX = math.floor(tonumber(mark.size_x) or qSize)
    local qSizeY = math.floor(tonumber(mark.size_y) or qSize)
    local qX = math.floor(tonumber(mark.x) or 0)
    local qY = math.floor(tonumber(mark.y) or 0)
    local qRot = math.floor(tonumber(mark.rotate) or 0)
    -- Opacité du tatouage/cicatrice (0-100, défaut 100 = opaque).
    local qOpacity = math.Clamp(math.floor(tonumber(mark.opacity) or 100), 0, 100)
    local cacheKey = table.concat({tostring(namespace or "body_mark"), tostring(markId or "mark"), string.lower(texturePath), string.format("%d_%d_%d", r, g, b), string.format("s%d_%d_%d_x%d_y%d_r%d_a%d", qSize, qSizeX, qSizeY, qX, qY, qRot, qOpacity),}, "::")
    local runtimeKey = string.gsub(cacheKey, "[^%w_]+", "_")
    local runtimeName = "verse__char__body_mark_layer__" .. BODY_MARK_LAYER_MATERIAL_REV .. "__" .. runtimeKey
    local cached = BODY_MARK_LAYER_MATERIALS[cacheKey]
    if cached == nil then
        -- UnlitGeneric : rendu sans éclairage de scène → la couleur sélectionnée
        -- correspond EXACTEMENT à ce qui s'affiche (blanc = blanc pur, noir = noir pur).
        -- VertexLitGeneric était incorrect : la lumière ambiante assombrissait les couleurs
        -- claires (le blanc devenait gris, le noir restait noir par coïncidence).
        -- $color2 multiplie le pixel de la texture par la couleur choisie :
        --   texture_blanc × [0,0,0] = noir  |  texture_blanc × [1,1,1] = blanc  etc.
        -- L'ancien "or 1" pour le noir (0,0,0) était un bug : il produisait [1,1,1]
        -- ce qui laissait la texture inchangée au lieu de la noircir.
        local cr = r / 255
        local cg = g / 255
        local cb = b / 255
        cached = CreateMaterial(runtimeName, "UnlitGeneric", {
            ["$basetexture"] = texturePath,
            ["$translucent"] = 1,
            ["$clamps"] = 1,
            ["$clampt"] = 1,
            ["$color2"] = string.format("[%.4f %.4f %.4f]", cr, cg, cb),
            ["$basetexturetransform"] = buildBodyMarkTransformKV(mark),
        })

        if not cached or cached:IsError() then cached = false end
        BODY_MARK_LAYER_MATERIALS[cacheKey] = cached
    end
    -- Mémorise l'opacité de ce matériau (appliquée au dessin via render.SetBlend).
    BODY_MARK_MAT_OPACITY[runtimeName] = qOpacity / 100

    if cached == false then return nil end
    return cached
end

local function ensureBodyMarkLayerEntity(parentEnt, currentEnt, boneParent, skipBoneMerge)
    if not IsValid(parentEnt) then
        if IsValid(currentEnt) then currentEnt:Remove() end
        return nil
    end

    local modelPath = tostring(parentEnt:GetModel() or "")
    if modelPath == "" then
        if IsValid(currentEnt) then currentEnt:Remove() end
        return nil
    end

    local ent = currentEnt
    if IsValid(ent) then
        if tostring(ent:GetModel() or "") ~= modelPath then ent:SetModel(modelPath) end
    else
        ent = ClientsideModel(modelPath)
    end

    if not IsValid(ent) then return nil end
    ent:SetNoDraw(true)

    if skipBoneMerge then
        -- Contexte DModelPanel (menus création / sélection) — approche v27 :
        -- • L'entité-layer n'est JAMAIS dessinée dans le menu (drawBodyMarkLayerSet v27 dessine
        --   headEnt directement). Elle sert uniquement à stocker __faceSlots/__bodyMarkMat.
        -- • Pas de SetParent ni EF_BONEMERGE → DModelPanel ne l'auto-dessine pas.
        -- • SetColor(alpha=0) = filet de sécurité si l'entité était rendue accidentellement.
        if ent:GetParent() ~= NULL then
            ent._verseMarkSig = nil
            ent:SetParent(nil)
        end
        ent:RemoveEffects(EF_BONEMERGE)
        ent:RemoveEffects(EF_BONEMERGE_FASTCULL)
        ent:RemoveEffects(EF_PARENT_ANIMATES)
        ent:SetColor(Color(255, 255, 255, 0))
    else
        -- Contexte en jeu : parent + EF_BONEMERGE pour que les bones suivent l'animation.
        -- L'entité est auto-rendue par le moteur (SetNoDraw=false appliqué par syncBodyMarkLayerSet).
        local actualParent = (IsValid(boneParent) and boneParent) or parentEnt
        if ent:GetParent() ~= actualParent then
            ent._verseMarkSig = nil
        end
        ent:SetPos(actualParent:GetPos())
        ent:SetAngles(actualParent:GetAngles())
        ent:SetParent(actualParent)
        -- RemoveEffects avant AddEffects : garantit une initialisation propre de EF_BONEMERGE
        -- (même correction que pour headEnt — évite les os flottants sur les entités réutilisées).
        ent:RemoveEffects(EF_BONEMERGE)
        ent:RemoveEffects(EF_BONEMERGE_FASTCULL)
        ent:RemoveEffects(EF_PARENT_ANIMATES)
        ent:AddEffects(EF_BONEMERGE)
        -- EF_BONEMERGE_FASTCULL absent : gèle les bones dans la géométrie solide (noclip).
        ent:AddEffects(EF_PARENT_ANIMATES)
        ent:SetLocalPos(vector_origin)
        ent:SetLocalAngles(angle_zero)
        -- alpha=0 : hiddenMat ($vertexalpha=1) rejette tous ses pixels → slots non-visage invisibles.
        -- tatMat (sans $vertexalpha) ignore l'alpha de l'entité → s'affiche normalement.
        ent:SetColor(Color(255, 255, 255, 0))
        ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
    end

    return ent
end

local function syncBodyMarkLayerSet(headEnt, layerSet, resolvedMarks, namespace, boneParent)
    layerSet = istable(layerSet) and layerSet or {}
    if not IsValid(headEnt) or not istable(resolvedMarks) or next(resolvedMarks) == nil then return clearBodyMarkLayerSet(layerSet) end

    -- Contexte DModelPanel (menus création / sélection) : namespace commence par "create_" ou "select_".
    -- Dans ce contexte, on retire EF_BONEMERGE des entités-layer pour qu'elles ne soient PAS
    -- auto-dessinées par DModelPanel lors du rendu de headEnt → zéro artefact blanc.
    -- Le tatouage est affiché via drawBodyMarkLayerSet qui redessine headEnt directement.
    -- En jeu (namespace "world_"), EF_BONEMERGE est conservé pour que les bones suivent l'animation.
    local skipBoneMerge = isstring(namespace) and (
        string.sub(namespace, 1, 7) == "create_" or
        string.sub(namespace, 1, 7) == "select_"
    )

    local keep = {}
    local baseScale = tonumber(headEnt:GetModelScale()) or 1
    local bodygroup = headEnt.GetBodygroup and headEnt:GetBodygroup(0) or 0
    local sortedKeys = {}
    for k in pairs(resolvedMarks) do
        sortedKeys[#sortedKeys + 1] = k
    end

    table.sort(sortedKeys)
    for layerIdx, key in ipairs(sortedKeys) do
        local mark = resolvedMarks[key]
        local materialPath = istable(mark) and string.Trim(tostring(mark.material or "")) or ""
        if materialPath ~= "" then
            local overlayMaterial = getBodyMarkLayerMaterial(namespace, key, materialPath, mark)
            if overlayMaterial then
                if skipBoneMerge then
                    -- Contexte DModelPanel (menus création / sélection) — approche v28 :
                    -- Aucune entité ClientsideModel créée → zéro artefact blanc garanti.
                    -- Les face-slots proviennent de headEnt directement (même modèle, cache par path).
                    local faceSlots = getMenuFaceSlots(headEnt)
                    if #faceSlots > 0 then
                        local allMats = headEnt:GetMaterials() or {}
                        local faceSlotSet = {}
                        for _, s in ipairs(faceSlots) do faceSlotSet[s] = true end
                        local nonFaceSlots = {}
                        for slotIdx = 0, #allMats - 1 do
                            if not faceSlotSet[slotIdx] then
                                nonFaceSlots[#nonFaceSlots + 1] = slotIdx
                            end
                        end
                        local existing = layerSet[key]
                        if istable(existing) and existing.__isMenuLayer then
                            existing.__bodyMarkMat  = overlayMaterial
                            existing.__faceSlots    = faceSlots
                            existing.__nonFaceSlots = nonFaceSlots
                        else
                            if IsValid(existing) then existing:Remove() end
                            layerSet[key] = {
                                __isMenuLayer   = true,
                                __faceSlots     = faceSlots,
                                __nonFaceSlots  = nonFaceSlots,
                                __bodyMarkMat   = overlayMaterial,
                            }
                        end
                        keep[key] = true
                    end
                else
                    -- Contexte en jeu (namespace "world_") : table Lua simple, ZERO entité CSM.
                    -- Une entité CSM avec EF_BONEMERGE coûte ~90ms/frame côté moteur (→ 10 FPS).
                    -- Le tatouage est dessiné dans PostPlayerDraw via SetSubMaterial + DrawModel.
                    local tatName = "!" .. overlayMaterial:GetName()
                    local faceSlots = getMenuFaceSlots(headEnt)
                    if #faceSlots > 0 then
                        local allMats = headEnt:GetMaterials() or {}
                        local faceSlotSet = {}
                        for _, s in ipairs(faceSlots) do faceSlotSet[s] = true end
                        local nonFaceSlots = {}
                        for slotIdx = 0, #allMats - 1 do
                            if not faceSlotSet[slotIdx] then
                                nonFaceSlots[#nonFaceSlots + 1] = slotIdx
                            end
                        end
                        local existing = layerSet[key]
                        if istable(existing) and existing.__isWorldLayer then
                            existing.__bodyMarkMat  = overlayMaterial
                            existing.__tatName      = tatName
                            existing.__faceSlots    = faceSlots
                            existing.__nonFaceSlots = nonFaceSlots
                        else
                            if IsValid(existing) then existing:Remove() end
                            layerSet[key] = {
                                __isWorldLayer  = true,
                                __faceSlots     = faceSlots,
                                __nonFaceSlots  = nonFaceSlots,
                                __bodyMarkMat   = overlayMaterial,
                                __tatName       = tatName,
                            }
                        end
                        keep[key] = true
                    end
                end
            end
        end
    end

    for key, ent in pairs(layerSet) do
        if isstring(key) and string.sub(key, 1, 2) == "__" then
            layerSet[key] = nil
        elseif not keep[key] then
            if IsValid(ent) then ent:Remove() end
            layerSet[key] = nil
        end
    end

    layerSet.__sortedKeys = nil
    -- Stocker la référence headEnt pour drawBodyMarkLayerSet (redraw DModelPanel).
    -- Doit être après la boucle de nettoyage qui efface les clés "__*".
    layerSet.__headEnt = headEnt
    return layerSet
end

local function getFaceMaterialSlot(ent, slotKey, matcher)
    if not IsValid(ent) then return nil end
    local modelPath = ent:GetModel()
    local normalizedModelPath = normalizeAppearanceModelPath(modelPath)
    local materials = ent.GetMaterials and ent:GetMaterials() or {}
    local configuredSlots = {}
    local function pushConfiguredSlot(value)
        value = tonumber(value)
        if value == nil then return end
        local slot = math.max(0, math.floor(value))
        for _, existing in ipairs(configuredSlots) do
            if existing == slot then return end
        end

        configuredSlots[#configuredSlots + 1] = slot
    end

    local byModel = CH.FaceMaterialSlots and CH.FaceMaterialSlots[normalizedModelPath] or nil
    local rawSlot = istable(byModel) and byModel[slotKey] or nil
    if istable(rawSlot) then
        for _, candidate in ipairs(rawSlot) do
            pushConfiguredSlot(candidate)
        end
    else
        pushConfiguredSlot(rawSlot)
    end

    if #configuredSlots <= 0 and CH.GetFaceMaterialSlot then pushConfiguredSlot(CH:GetFaceMaterialSlot(modelPath, slotKey)) end
    if #configuredSlots > 0 then
        for _, slot in ipairs(configuredSlots) do
            local exactMat = materials[slot + 1]
            if exactMat ~= nil and matcher(exactMat) then return slot end
        end
    end

    local cacheKey = table.concat({tostring(ent:GetModel() or ""), tostring(slotKey or "")}, "\31")
    local cached = FACE_MATERIAL_SLOT_CACHE[cacheKey]
    if cached ~= nil then return cached >= 0 and cached or nil end
    local slotIndex = nil
    for idx, matName in ipairs(ent:GetMaterials() or {}) do
        if matcher(matName) then
            slotIndex = idx - 1
            break
        end
    end

    if slotIndex == nil and #configuredSlots > 0 then slotIndex = configuredSlots[1] end
    FACE_MATERIAL_SLOT_CACHE[cacheKey] = slotIndex or -1
    return slotIndex
end

local function isConfiguredFaceSlot(ent, slotIndex, slotKey)
    if not IsValid(ent) then return false end
    slotIndex = math.max(0, math.floor(tonumber(slotIndex) or -1))
    if slotIndex < 0 then return false end
    local modelPath = normalizeAppearanceModelPath(ent:GetModel())
    local byModel = CH.FaceMaterialSlots and CH.FaceMaterialSlots[modelPath] or nil
    local rawSlot = istable(byModel) and byModel[slotKey] or nil
    local function equalsSlot(value)
        value = tonumber(value)
        if value == nil then return false end
        return slotIndex == math.max(0, math.floor(value))
    end

    if istable(rawSlot) then
        for _, candidate in ipairs(rawSlot) do
            if equalsSlot(candidate) then return true end
        end
    elseif equalsSlot(rawSlot) then
        return true
    end

    if CH.GetFaceMaterialSlot then
        local exactSlot = CH:GetFaceMaterialSlot(ent:GetModel(), slotKey)
        if equalsSlot(exactSlot) then return true end
    end
    return false
end

local function shouldSkipFaceSkinTintSlot(ent, slotIndex)
    if not IsValid(ent) or slotIndex == nil then return false end
    if not isFaceControlModel(ent:GetModel()) then return false end
    slotIndex = math.max(0, math.floor(tonumber(slotIndex) or 0))
    if isConfiguredFaceSlot(ent, slotIndex, "eyes") then return true end
    if isConfiguredFaceSlot(ent, slotIndex, "eyebrow") then return true end
    local eyeSlot = getFaceMaterialSlot(ent, "eyes", isEyeMaterialName)
    if eyeSlot ~= nil and slotIndex == eyeSlot then return true end
    local eyebrowSlot = getFaceMaterialSlot(ent, "eyebrow", isEyebrowMaterialName)
    if eyebrowSlot ~= nil and slotIndex == eyebrowSlot then return true end
    return false
end

local function applyEntityEyebrowMaterial(ent, style)
    if not IsValid(ent) or not ent.SetSubMaterial or not isFaceControlModel(ent:GetModel()) then return end
    local slotIndex = getFaceMaterialSlot(ent, "eyebrow", isEyebrowMaterialName)
    if slotIndex == nil then return end
    style = math.Clamp(math.floor(tonumber(style) or 1), 1, getEyebrowStyleCount())
    if style <= 1 then
        ent:SetSubMaterial(slotIndex, "")
        return
    end

    local texturePath = getEyebrowMaterialPath(style)
    if texturePath == "" then
        ent:SetSubMaterial(slotIndex, "")
        return
    end

    local runtimeMat = FACE_EYEBROW_RUNTIME_MATERIALS[style]
    if not runtimeMat then
        local runtimeName = ("verse__char__eyebrow_variant_%d"):format(style)
        runtimeMat = CreateMaterial(runtimeName, "VertexLitGeneric", {
            ["$model"] = 1,
            ["$basetexture"] = texturePath,
            ["$bumpmap"] = "slayde_jjk/shared/normal",
            ["$lightwarptexture"] = "slayde_jjk/shared/lightwarpshader",
            ["$alphatest"] = 1,
        })

        FACE_EYEBROW_RUNTIME_MATERIALS[style] = runtimeMat
    end

    if runtimeMat and not runtimeMat:IsError() then
        ent:SetSubMaterial(slotIndex, "!" .. runtimeMat:GetName())
    else
        ent:SetSubMaterial(slotIndex, "")
    end
end

local function getActiveEyebrowMaterial(style)
    style = math.Clamp(math.floor(tonumber(style) or 1), 1, getEyebrowStyleCount())
    if style <= 1 then
        local mat = Material("slayde_jjk/face/eyebrow")
        if mat and not mat:IsError() then return mat end
        return nil
    end

    local runtimeMat = FACE_EYEBROW_RUNTIME_MATERIALS[style]
    if runtimeMat and not runtimeMat:IsError() then return runtimeMat end
    return nil
end

local function setEyebrowMaterialTint(style, color)
    if not IsColor(color) then return end
    local mat = getActiveEyebrowMaterial(style)
    if not mat then return end
    mat:SetVector("$color2", Vector(color.r / 255, color.g / 255, color.b / 255))
end

local function getEyeStyleRuntimeMaterial(style)
    style = math.Clamp(math.floor(tonumber(style) or 1), 1, getEyeStyleCount())
    local texturePath = getEyeMaterialPath(style)
    if texturePath == "" then return nil end
    local runtimeMat = FACE_EYE_RUNTIME_MATERIALS[style]
    if runtimeMat and not runtimeMat:IsError() then return runtimeMat end
    local runtimeName = ("verse__char__eye_variant_v5_%d"):format(style)
    runtimeMat = CreateMaterial(runtimeName, "VertexLitGeneric", {
        ["$model"] = 1,
        ["$basetexture"] = texturePath,
        ["$lightwarptexture"] = "slayde_jjk/shared/lightwarpshader",
        ["$vertexcolor"] = 1,
        ["$vertexalpha"] = 1,
        ["$color2"] = "[1 1 1]",
        ["$alphatest"] = 1,
        ["$translucent"] = 0,
    })

    FACE_EYE_RUNTIME_MATERIALS[style] = runtimeMat
    if runtimeMat and not runtimeMat:IsError() then return runtimeMat end
    return nil
end

local function setEyeMaterialSize(entOrStyle, styleOrIrisSize, maybeIrisSize)
    if IsValid(entOrStyle) then
        local ent = entOrStyle
        local sizePct
        if maybeIrisSize ~= nil then
            sizePct = tonumber(maybeIrisSize)
            if styleOrIrisSize ~= nil then ent._verseIrisStyle = styleOrIrisSize end
        else
            sizePct = tonumber(styleOrIrisSize)
        end

        if sizePct then
            ent._verseIrisSize = sizePct
            local style = tonumber(ent._verseIrisStyle) or 1
            local color = ent._verseEyeColor or color_white
            setEntityIris(ent, style, sizePct, color)
            return true
        end
    end
    return false
end

local function applyEntityEyeMaterial(ent, style)
    if not IsValid(ent) then return end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if not string.find(mdl, "verse/head/base_head", 1, true) then return end
    ent._verseIrisStyle = style
    local sizePct = tonumber(ent._verseIrisSize) or (CH.GetDefaultIrisSize and CH:GetDefaultIrisSize()) or 100
    local color = ent._verseEyeColor or color_white
    setEntityIris(ent, style, sizePct, color)
end

local function setEntityIrisSize(ent, sizePct)
    if not IsValid(ent) then return end
    ent._verseIrisSize = tonumber(sizePct) or 100
    local style = tonumber(ent._verseIrisStyle) or 1
    local color = ent._verseEyeColor or color_white
    setEntityIris(ent, style, ent._verseIrisSize, color)
end

local function setEntityEyeTintColor(ent, color)
    if not IsValid(ent) then return end
    if IsColor(color) then ent._verseEyeColor = Color(color.r or 255, color.g or 255, color.b or 255, 255) end
    local style = tonumber(ent._verseIrisStyle) or 1
    local sizePct = tonumber(ent._verseIrisSize) or (CH.GetDefaultIrisSize and CH:GetDefaultIrisSize()) or 100
    setEntityIris(ent, style, sizePct, ent._verseEyeColor or color_white)
end

CH.SetEntityIrisSize = setEntityIrisSize
CH.SetEntityEyeColor = setEntityEyeTintColor
local function getActiveEyeMaterial(style)
    style = math.Clamp(math.floor(tonumber(style) or 1), 1, getEyeStyleCount())
    local runtimeMat = getEyeStyleRuntimeMaterial(style)
    if runtimeMat and not runtimeMat:IsError() then return runtimeMat end
    local mat = Material(getEyeMaterialPath(style))
    if mat and not mat:IsError() then return mat end
    return nil
end

local function setEyeMaterialTint(style, color)
    if not IsColor(color) then return end
    local mat = getActiveEyeMaterial(style)
    if not mat then return end
    mat:SetVector("$color2", Vector(color.r / 255, color.g / 255, color.b / 255))
end

local function getMaterialTextureName(mat, key)
    if not mat or mat:IsError() or not mat.GetTexture then return nil end
    local texture = mat:GetTexture(key)
    if not texture or not texture.GetName then return nil end
    local textureName = string.Trim(tostring(texture:GetName() or ""))
    if textureName == "" then return nil end
    return textureName
end

local function getFaceSkinRuntimeMaterial(matName)
    local sourceMat = Material(matName)
    if not sourceMat or sourceMat:IsError() then return nil end
    local baseTexture = getMaterialTextureName(sourceMat, "$basetexture")
    if not baseTexture then return nil end
    local cacheKey = string.lower(baseTexture)
    local cached = FACE_SKIN_RUNTIME_MATERIALS[cacheKey]
    if cached == false then return nil end
    if cached and not cached:IsError() then return cached end
    local runtimeName = "verse__char__face_skin__" .. string.gsub(cacheKey, "[^%w_]+", "_")
    local params = {
        ["$model"] = 1,
        ["$basetexture"] = baseTexture,
        ["$lightwarptexture"] = getMaterialTextureName(sourceMat, "$lightwarptexture") or "slayde_jjk/shared/lightwarpshader",
        ["$color2"] = "[1 1 1]",
        ["$blendtintbybasealpha"] = 1,
        ["$blendtintcoloroverbase"] = 0,
    }

    local bumpTexture = getMaterialTextureName(sourceMat, "$bumpmap")
    if bumpTexture then params["$bumpmap"] = bumpTexture end
    local runtimeMat = CreateMaterial(runtimeName, "VertexLitGeneric", params)
    if not runtimeMat or runtimeMat:IsError() then
        FACE_SKIN_RUNTIME_MATERIALS[cacheKey] = false
        return nil
    end

    FACE_SKIN_RUNTIME_MATERIALS[cacheKey] = runtimeMat
    return runtimeMat
end

local function setFaceSlotDirectMaterialTint(ent, slotKey, matcher, color)
    if not IsValid(ent) or not IsColor(color) then return end
    local slotIndex = getFaceMaterialSlot(ent, slotKey, matcher)
    if slotIndex == nil then return end
    local materials = ent.GetMaterials and ent:GetMaterials() or nil
    local matName = istable(materials) and materials[slotIndex + 1] or nil
    if not isstring(matName) or matName == "" then return end
    local rawName = normalizeMaterialPathRaw(matName)
    local normalizedName = normalizeMaterialPath(rawName)
    local mat = Material(rawName)
    if (not mat or mat:IsError()) and rawName ~= normalizedName then mat = Material(normalizedName) end
    if not mat or mat:IsError() then return end
    mat:SetVector("$color2", Vector(color.r / 255, color.g / 255, color.b / 255))
end

local function resetFaceFeatureTint(ent)
    if not IsValid(ent) or not isFaceControlModel(ent:GetModel()) then return end
    setFaceSlotDirectMaterialTint(ent, "eyes", isEyeMaterialName, color_white)
    setFaceSlotDirectMaterialTint(ent, "eyebrow", isEyebrowMaterialName, color_white)
end

local function setFaceHeadSkinTint(ent, color)
    if not IsValid(ent) or not IsColor(color) or not isFaceControlModel(ent:GetModel()) then return end
    local vec = Vector(color.r / 255, color.g / 255, color.b / 255)
    for idx, matName in ipairs(ent:GetMaterials() or {}) do
        local slotIndex = idx - 1
        if not shouldSkipFaceSkinTintSlot(ent, slotIndex) and isSkinMaterialNameBase(matName) then
            local runtimeMat = getFaceSkinRuntimeMaterial(matName)
            if runtimeMat and not runtimeMat:IsError() then
                runtimeMat:SetVector("$color2", vec)
                ent:SetSubMaterial(slotIndex, "!" .. runtimeMat:GetName())
            else
                local mat = Material(matName)
                if mat and not mat:IsError() then mat:SetVector("$color2", vec) end
            end
        end
    end

    resetFaceFeatureTint(ent)
end

local function clearFaceHeadSkinTint(ent)
    if not IsValid(ent) or not isFaceControlModel(ent:GetModel()) then return end
    for idx, matName in ipairs(ent:GetMaterials() or {}) do
        local slotIndex = idx - 1
        if not shouldSkipFaceSkinTintSlot(ent, slotIndex) and isSkinMaterialNameBase(matName) then
            local runtimeMat = getFaceSkinRuntimeMaterial(matName)
            if runtimeMat and not runtimeMat:IsError() then
                ent:SetSubMaterial(slotIndex, "")
            else
                local mat = Material(matName)
                if mat and not mat:IsError() then mat:SetVector("$color2", Vector(1, 1, 1)) end
            end
        end
    end

    resetFaceFeatureTint(ent)
end

local function buildWorldSkinPalette()
    local configured = CH:ConfigTable("SkinColorPalette", nil)
    if configured == WORLD_SKIN_PALETTE_SOURCE and istable(WORLD_SKIN_PALETTE_CACHE) and #WORLD_SKIN_PALETTE_CACHE > 0 then return WORLD_SKIN_PALETTE_CACHE end
    if not istable(configured) or #configured == 0 then
        WORLD_SKIN_PALETTE_SOURCE = configured
        WORLD_SKIN_PALETTE_CACHE = DEFAULT_SKIN_TONES
        return DEFAULT_SKIN_TONES
    end

    local out = {}
    for _, colorValue in ipairs(configured) do
        if IsColor(colorValue) then
            out[#out + 1] = Color(colorValue.r, colorValue.g, colorValue.b, colorValue.a or 255)
        elseif istable(colorValue) and colorValue.r and colorValue.g and colorValue.b then
            out[#out + 1] = Color(tonumber(colorValue.r) or 255, tonumber(colorValue.g) or 255, tonumber(colorValue.b) or 255, tonumber(colorValue.a) or 255)
        end
    end

    if #out == 0 then
        WORLD_SKIN_PALETTE_SOURCE = configured
        WORLD_SKIN_PALETTE_CACHE = DEFAULT_SKIN_TONES
        return DEFAULT_SKIN_TONES
    end

    WORLD_SKIN_PALETTE_SOURCE = configured
    WORLD_SKIN_PALETTE_CACHE = out
    return out
end

local function getWorldTintMaterials(ent, matcher)
    if not IsValid(ent) then return nil end
    local cacheKind = "all"
    if matcher == isSkinMaterialNameBase then
        cacheKind = "skin"
    elseif matcher == isEyeMaterialName then
        cacheKind = "eyes"
    end

    local cacheKey = table.concat({tostring(ent:GetModel() or ""), cacheKind,}, "\31")
    local cached = WORLD_APPEARANCE_MATERIALS[cacheKey]
    if cached then return cached end
    cached = {}
    for idx, matName in ipairs(ent:GetMaterials() or {}) do
        local slotIndex = idx - 1
        if not matcher or (matcher(matName) and not (matcher == isSkinMaterialNameBase and shouldSkipFaceSkinTintSlot(ent, slotIndex))) then
            local mat = Material(matName)
            if mat and not mat:IsError() then cached[#cached + 1] = mat end
        end
    end

    WORLD_APPEARANCE_MATERIALS[cacheKey] = cached
    return cached
end

-- Vecteur réutilisé à chaque appel pour éviter une allocation par frame×joueur
local _tintVec = Vector(1, 1, 1)
local function setWorldEntityTint(ent, color, matcher)
    if not IsValid(ent) or not IsColor(color) then return end
    _tintVec.x = color.r / 255
    _tintVec.y = color.g / 255
    _tintVec.z = color.b / 255
    for _, mat in ipairs(getWorldTintMaterials(ent, matcher) or {}) do
        mat:SetVector("$color2", _tintVec)
    end

    if matcher == isSkinMaterialNameBase and ent.SetPlayerColor then ent:SetPlayerColor(_tintVec) end
end

-- Réinitialise uniquement $color2 (matériau partagé) à blanc neutre.
-- Ne touche PAS SetPlayerColor : celui-ci est maintenu persistant sur l'entité
-- joueur afin que la couleur de peau reste correcte même hors de la plage
-- WorldAppearanceDistance (où Pre/PostPlayerDraw ne s'exécutent plus).
local _whiteVec = Vector(1, 1, 1)
local function resetBodyColor2Only(ent, matcher)
    if not IsValid(ent) then return end
    for _, mat in ipairs(getWorldTintMaterials(ent, matcher) or {}) do
        mat:SetVector("$color2", _whiteVec)
    end
end

local function setWorldBodygroup(ent, groupId, value)
    if not IsValid(ent) or not ent.GetNumBodyGroups or not ent.GetBodygroupCount then return end
    groupId = tonumber(groupId) or 0
    if ent:GetNumBodyGroups() <= groupId then return end
    local count = tonumber(ent:GetBodygroupCount(groupId)) or 0
    local maxValue = math.max(0, count - 1)
    local safeValue = math.Clamp(math.floor(tonumber(value) or 0), 0, maxValue)
    if CH.NormalizeBodygroupValue then safeValue = CH:NormalizeBodygroupValue(ent:GetModel(), groupId, safeValue, maxValue) end
    ent:SetBodygroup(groupId, safeValue)
end

local BUILTIN_HEAD_BG_CACHE = {}
local function hideBuiltInHeadBodygroups(ent)
    if not IsValid(ent) or not ent.GetNumBodyGroups or not ent.GetBodygroupName or not ent.GetBodygroupCount or not ent.SetBodygroup then return end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if mdl == "" then return end
    local cached = BUILTIN_HEAD_BG_CACHE[mdl]
    if cached == nil then
        cached = {}
        local total = ent:GetNumBodyGroups() or 0
        for i = 0, total - 1 do
            local name = string.lower(tostring(ent:GetBodygroupName(i) or ""))
            if name ~= "" and name ~= "body" and (string.find(name, "head", 1, true) or string.find(name, "tete", 1, true) or string.find(name, "tête", 1, true) or string.find(name, "face", 1, true) or name == "hair" or string.find(name, "cheveu", 1, true)) then
                local count = tonumber(ent:GetBodygroupCount(i)) or 0
                if count > 1 then
                    cached[#cached + 1] = {
                        id = i,
                        hideValue = count - 1
                    }
                end
            end
        end

        BUILTIN_HEAD_BG_CACHE[mdl] = cached
    end

    for _, entry in ipairs(cached) do
        ent:SetBodygroup(entry.id, entry.hideValue)
    end
end

CH.HideBuiltInHeadBodygroups = hideBuiltInHeadBodygroups

-- Restaure les bodygroups de tête cachés par hideBuiltInHeadBodygroups (remet à 0 = visible).
-- Appelé par removeWorldAppearance pour éviter le joueur "sans tête" quand le headEnt est supprimé.
local function restoreBuiltInHeadBodygroups(ent)
    if not IsValid(ent) then return end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    if mdl == "" then return end
    local cached = BUILTIN_HEAD_BG_CACHE[mdl]
    if not istable(cached) then return end
    for _, entry in ipairs(cached) do
        ent:SetBodygroup(entry.id, 0)
    end
end
local function getPublicCharId(ply)
    if not IsValid(ply) or not ply.GetPublicInt then return 0 end
    return math.max(0, tonumber(ply:GetPublicInt(CH:ConfigString("VarChar", "VERSE::CharID"), 0)) or 0)
end

local function getWorldAppearanceDistanceSqr()
    local rawDistance = tonumber(CH:GetConfig("WorldAppearanceDistance", 1800)) or 1800
    if rawDistance <= 0 then return nil end
    rawDistance = math.Clamp(rawDistance, 0, 20000)
    return rawDistance * rawDistance
end

local function getWorldAppearanceRefreshInterval()
    return math.Clamp(tonumber(CH:GetConfig("WorldAppearanceRefresh", 0.25)) or 0.25, 0.05, 2)
end

local function isCharacterMenuOpen()
    return IsValid(characterCreateFrame) or IsValid(characterSelectFrame) or IsValid(characterAdminFrame)
end

local function shouldKeepWorldAppearance(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local lp = LocalPlayer()
    if not IsValid(lp) then return false end
    -- Le joueur local conserve TOUJOURS son apparence (third-person, deathscreen…)
    -- même si un menu personnage est ouvert.
    if ply == lp then return true end
    if isCharacterMenuOpen() then return false end
    local maxDistSqr = getWorldAppearanceDistanceSqr()
    if maxDistSqr and lp:GetPos():DistToSqr(ply:GetPos()) > maxDistSqr then return false end
    return true
end

local function removeWorldAppearance(ply)
    local state = WORLD_APPEARANCE[ply]
    if not state then return end
    -- Réinitialise uniquement $color2 (partagé) à blanc neutre.
    -- SetPlayerColor est intentionnellement laissé à sa dernière valeur de peau :
    -- cela évite que le corps du joueur devienne tout blanc une fois hors de la
    -- plage WorldAppearanceDistance (le joueur reste coloré même sans headEnt).
    resetBodyColor2Only(ply, isSkinMaterialNameBase)
    -- Restaure la tête intégrée AVANT de supprimer le headEnt :
    -- sans ça, le joueur devient "sans tête" pendant quelques frames
    -- (bodygroup encore en mode caché, headEnt supprimé).
    if IsValid(ply) then restoreBuiltInHeadBodygroups(ply) end
    state.markEnts = clearBodyMarkLayerSet(state.markEnts)
    if IsValid(state.headEnt) then
        setWorldEntityTint(state.headEnt, color_white, isSkinMaterialNameBase)
        state.headEnt:Remove()
    end

    if IsValid(state.accessoryEnt) then state.accessoryEnt:Remove() end
    if IsValid(state.hairEnt) then state.hairEnt:Remove() end
    WORLD_APPEARANCE[ply] = nil
end

local function clearWorldAppearanceStates()
    for ply in pairs(WORLD_APPEARANCE) do
        removeWorldAppearance(ply)
    end
end

local function spawnWorldAppearancePart(parent, mdl, useBoneMerge)
    if not IsValid(parent) or not isstring(mdl) or mdl == "" then return nil end
    local ent = ClientsideModel(mdl)
    if not IsValid(ent) then return nil end
    if useBoneMerge == nil then useBoneMerge = true end
    ent:SetPos(parent:GetPos())
    ent:SetAngles(parent:GetAngles())
    ent:SetNoDraw(true)
    ent:SetParent(parent)
    ent:RemoveEffects(EF_BONEMERGE)
    ent:RemoveEffects(EF_BONEMERGE_FASTCULL)
    ent:RemoveEffects(EF_PARENT_ANIMATES)
    if useBoneMerge then
        ent:AddEffects(EF_BONEMERGE)
        -- EF_BONEMERGE_FASTCULL absent intentionnellement (voir headEnt pour l'explication).
        ent:AddEffects(EF_PARENT_ANIMATES)
    end

    ent:SetLocalPos(vector_origin)
    ent:SetLocalAngles(angle_zero)
    ent:InvalidateBoneCache()
    ent:SetupBones()
    return ent
end

function CH:ApplySpiritAccessoryClientTransform(ent, baseScale, rawTransform)
    if not IsValid(ent) then return false end
    local transform = rawTransform
    if self.NormalizeSpiritAccessoryTransform then transform = self:NormalizeSpiritAccessoryTransform("spirit", 1, rawTransform) end
    if not istable(transform) then transform = {} end
    local tx = tonumber(transform.x) or 0
    local ty = tonumber(transform.y) or 0
    local tz = tonumber(transform.z) or 0
    local size = tonumber(transform.size) or SPIRIT_ACCESSORY_SIZE_BASE
    local scale = math.Clamp(size / SPIRIT_ACCESSORY_SIZE_BASE, SPIRIT_ACCESSORY_SCALE_MIN, SPIRIT_ACCESSORY_SCALE_MAX)
    local base = tonumber(baseScale) or 1
    local localPos = Vector(tx * SPIRIT_ACCESSORY_POSITION_SCALE, ty * SPIRIT_ACCESSORY_POSITION_SCALE, tz * SPIRIT_ACCESSORY_POSITION_SCALE)
    local transformSig = string.format("%.4f|%.4f|%.4f|%.4f|%.4f", base, localPos.x, localPos.y, localPos.z, scale)
    if ent._verseSpiritAccessoryTransformSig == transformSig then return false end
    ent._verseSpiritAccessoryTransformSig = transformSig
    ent:SetModelScale(base * scale, 0)
    ent:SetLocalPos(localPos)
    ent:SetLocalAngles(angle_zero)
    local matrix = Matrix()
    if matrix.SetUnpacked then matrix:SetUnpacked(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) end
    ent:EnableMatrix("RenderMultiply", matrix)
    return true
end

local function refreshWorldAppearance(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        removeWorldAppearance(ply)
        return nil
    end

    local nowFast = CurTime()
    local stateFast = WORLD_APPEARANCE[ply]
    if stateFast and stateFast.nextRefreshAt and nowFast < stateFast.nextRefreshAt and IsValid(stateFast.rootEnt) then return stateFast end
    if not shouldKeepWorldAppearance(ply) then
        removeWorldAppearance(ply)
        return nil
    end

    local charId = getPublicCharId(ply)
    if charId <= 0 then
        removeWorldAppearance(ply)
        return nil
    end

    local nw = CH.AppearanceNW or {}
    local factionId = (ply.GetPublicString and nw.Faction and ply:GetPublicString(nw.Faction, "")) or ""
    local headModel = (ply.GetPublicString and nw.HeadModel and ply:GetPublicString(nw.HeadModel, "")) or ""
    local spiritAccessory = (ply.GetPublicInt and nw.SpiritAccessory and ply:GetPublicInt(nw.SpiritAccessory, 0)) or 0
    local legacySizeX = (ply.GetPublicInt and nw.SpiritAccessorySizeX and ply:GetPublicInt(nw.SpiritAccessorySizeX, BODY_MARK_DEFAULT_SIZE)) or BODY_MARK_DEFAULT_SIZE
    local legacySizeY = (ply.GetPublicInt and nw.SpiritAccessorySizeY and ply:GetPublicInt(nw.SpiritAccessorySizeY, BODY_MARK_DEFAULT_SIZE)) or BODY_MARK_DEFAULT_SIZE
    local spiritAccessoryRawData = {
        x = (ply.GetPublicInt and nw.SpiritAccessoryX and ply:GetPublicInt(nw.SpiritAccessoryX, BODY_MARK_DEFAULT_X)) or BODY_MARK_DEFAULT_X,
        y = (ply.GetPublicInt and nw.SpiritAccessoryY and ply:GetPublicInt(nw.SpiritAccessoryY, BODY_MARK_DEFAULT_Y)) or BODY_MARK_DEFAULT_Y,
        z = (ply.GetPublicInt and nw.SpiritAccessoryZ and ply:GetPublicInt(nw.SpiritAccessoryZ, 0)) or 0,
        size = (ply.GetPublicInt and nw.SpiritAccessorySize and ply:GetPublicInt(nw.SpiritAccessorySize, math.floor((legacySizeX + legacySizeY) * 0.5))) or math.floor((legacySizeX + legacySizeY) * 0.5),
    }

    local spiritAccessoryData = (CH.NormalizeSpiritAccessoryTransform and CH:NormalizeSpiritAccessoryTransform(factionId, spiritAccessory, spiritAccessoryRawData)) or spiritAccessoryRawData
    local accessoryModel = (CH.ResolveSpiritAccessoryModel and CH:ResolveSpiritAccessoryModel(factionId, spiritAccessory)) or ""
    local shouldUseAccessory = accessoryModel ~= "" and headModel ~= ""
    local hairModelIdx = (ply.GetPublicInt and nw.HairModel and ply:GetPublicInt(nw.HairModel, 0)) or 0
    local hairModelList = CH.HairModels or {}
    local hairModelPath = (hairModelIdx > 0 and isstring(hairModelList[hairModelIdx]) and hairModelList[hairModelIdx]) or ""
    local rootModel = tostring(ply:GetModel() or "")
    local signature = table.concat({tostring(charId), rootModel, headModel, tostring(accessoryModel), tostring(hairModelIdx)}, "\31")
    local state = WORLD_APPEARANCE[ply]
    local missingHead = headModel ~= "" and (not state or not IsValid(state.headEnt))
    local missingAccessory = shouldUseAccessory and (not state or not IsValid(state.accessoryEnt))
    local missingHair = hairModelPath ~= "" and (not state or not IsValid(state.hairEnt))
    local mustRebuild = not state or state.signature ~= signature or not IsValid(state.rootEnt) or missingHead or missingAccessory or missingHair
    local now = CurTime()
    if mustRebuild then
        removeWorldAppearance(ply)
        state = {
            rootEnt = ply,
            signature = signature,
            markEnts = {},
        }

        WORLD_APPEARANCE[ply] = state
        if headModel ~= "" then
            local headEnt = ClientsideModel(headModel)
            if not IsValid(headEnt) then
                -- ClientsideModel a échoué (modèle non précaché, path invalide, etc.)
                -- missingHead sera vrai au prochain PrePlayerDraw → retry automatique
                if VERSE.Log then VERSE.Log:Warn("[Characters] ClientsideModel() a échoué pour " .. tostring(headModel) .. " (joueur: " .. tostring(IsValid(ply) and ply:Nick() or "?") .. ")") end
            else
                headEnt:SetPos(ply:GetPos())
                headEnt:SetAngles(ply:GetAngles())
                headEnt:SetNoDraw(true)
                headEnt:SetParent(ply)
                headEnt:RemoveEffects(EF_BONEMERGE)
                headEnt:RemoveEffects(EF_BONEMERGE_FASTCULL)
                headEnt:RemoveEffects(EF_PARENT_ANIMATES)
                headEnt:AddEffects(EF_BONEMERGE)
                -- EF_BONEMERGE_FASTCULL intentionnellement absent :
                -- il gèle les bones à leur dernière position valide quand
                -- l'entité est à l'intérieur d'un brush (noclip → sol) →
                -- la tête flotte à l'ancienne position. Sans FASTCULL,
                -- le moteur recalcule les bones même dans la géométrie solide.
                headEnt:AddEffects(EF_PARENT_ANIMATES)
                headEnt:SetLocalPos(vector_origin)
                headEnt:SetLocalAngles(angle_zero)
                headEnt:InvalidateBoneCache()
                headEnt:SetupBones()
                -- Render bounds volontairement très larges : sans EF_BONEMERGE_FASTCULL,
                -- le moteur cull le headEnt sur ses propres bounds (minuscules par défaut)
                -- indépendamment du joueur. Ces bounds garantissent aucun culling
                -- prématuré à toute distance de jeu raisonnable.
                headEnt:SetRenderBounds(Vector(-200, -200, -100), Vector(200, 200, 300))
                headEnt._verseCharOwner = ply
                headEnt._verseCharTintKind = "skin"
                state.headEnt = headEnt
            end -- IsValid(headEnt)
        end -- headModel ~= ""

        if shouldUseAccessory and IsValid(state.headEnt) then
            state.accessoryEnt = spawnWorldAppearancePart(state.headEnt, accessoryModel, false)
            if shouldUseAccessory and not IsValid(state.accessoryEnt) then
                if VERSE.Log then VERSE.Log:Warn("[Characters] spawnWorldAppearancePart() a échoué pour accessory " .. tostring(accessoryModel) .. " (joueur: " .. tostring(IsValid(ply) and ply:Nick() or "?") .. ")") end
            end
        end

        if hairModelPath ~= "" then
            local hairEnt = spawnWorldAppearancePart(ply, hairModelPath, true)
            if IsValid(hairEnt) then
                hairEnt:SetRenderBounds(Vector(-200, -200, -100), Vector(200, 200, 300))
                hairEnt._verseCharOwner = ply
                state.hairEnt = hairEnt
            end
        end
    end

    if not mustRebuild and state.nextRefreshAt and now < state.nextRefreshAt then return state end
    state.nextRefreshAt = now + getWorldAppearanceRefreshInterval()
    -- Si le headEnt n'a pas pu être créé (modèle non précaché), on raccourcit
    -- le prochain retry à 0.05s au lieu d'attendre le refresh complet (0.35s).
    if headModel ~= "" and not IsValid(state.headEnt) then
        state.nextRefreshAt = now + 0.05
    end
    local skinPalette = buildWorldSkinPalette()
    local defaultHeight = CH:ConfigInt("DefaultHeight", 165, 50, 400)
    local skinIndex = (ply.GetPublicInt and nw.SkinTone and ply:GetPublicInt(nw.SkinTone, 1)) or 1
    skinIndex = math.Clamp(math.floor(tonumber(skinIndex) or 1), 1, math.max(1, #skinPalette))
    local heightValue = (ply.GetPublicInt and nw.Height and ply:GetPublicInt(nw.Height, defaultHeight)) or defaultHeight
    state.modelScale = (CH.GetHeightScale and CH:GetHeightScale(heightValue)) or 1
    local exactSkinColor = (ply.GetPublicString and nw.SkinColor and ply:GetPublicString(nw.SkinColor, "")) or ""
    if exactSkinColor ~= "" then
        state.skinColor = parseAppearanceColor(exactSkinColor, skinPalette[skinIndex] or DEFAULT_SKIN_TONES[1])
    else
        state.skinColor = cloneAppearanceColor(skinPalette[skinIndex] or DEFAULT_SKIN_TONES[1], DEFAULT_SKIN_TONES[1])
    end

    -- Persiste SetPlayerColor sur l'entité joueur dès que la couleur de peau est calculée.
    -- Cela garantit que le corps reste correctement coloré même quand le joueur sort de la
    -- plage WorldAppearanceDistance (où Pre/PostPlayerDraw ne s'exécutent plus et où
    -- removeWorldAppearance ne touche plus SetPlayerColor).
    if IsValid(ply) and ply.SetPlayerColor then
        local sc = state.skinColor or DEFAULT_SKIN_TONES[1]
        local newSig = string.format("%d,%d,%d", sc.r, sc.g, sc.b)
        if state._persistedSkinSig ~= newSig then
            ply:SetPlayerColor(Vector(sc.r / 255, sc.g / 255, sc.b / 255))
            state._persistedSkinSig = newSig
        end
    end

    state.hairColor = parseAppearanceColor((ply.GetPublicString and nw.HairColor and ply:GetPublicString(nw.HairColor, "")) or "", DEFAULT_HAIR_COLOR)
    -- Dégradé de cheveux : si une couleur de pointes est définie (chaîne non vide),
    -- on active le dégradé racines(hairColor) → pointes(tipColor). state.hairGradient
    -- = { c1 = pointes (bas de la texture), c2 = racines (haut) } — cf. PostPlayerDraw.
    do
        local rawTip = (ply.GetPublicString and nw.HairTipColor and ply:GetPublicString(nw.HairTipColor, "")) or ""
        if rawTip ~= "" then
            local tipColor = parseAppearanceColor(rawTip, state.hairColor or DEFAULT_HAIR_COLOR)
            state.hairGradient = { tipColor, state.hairColor }
            -- Demande la génération du matériau dégradé. Si on est en pleine passe de
            -- rendu (refreshWorldAppearance est appelé depuis PrePlayerDraw), la
            -- génération est mise en file et traitée par le Think, hors rendu.
            if _getGradientHairMaterial then _getGradientHairMaterial(tipColor, state.hairColor) end
        elseif state.hairGradient ~= nil then
            state.hairGradient = nil
            state.appliedHairColorSig = nil  -- force le retour à la couleur unie
        end
    end
    state.eyebrowStyle = (ply.GetPublicInt and nw.EyebrowStyle and ply:GetPublicInt(nw.EyebrowStyle, 1)) or 1
    state.eyebrowColor = parseAppearanceColor((ply.GetPublicString and nw.EyebrowColor and ply:GetPublicString(nw.EyebrowColor, "")) or "", state.hairColor or DEFAULT_HAIR_COLOR)
    state.eyelashColor = parseAppearanceColor((ply.GetPublicString and nw.EyelashColor and ply:GetPublicString(nw.EyelashColor, "")) or "", DEFAULT_EYELASH_COLOR)
    state.irisStyle = (ply.GetPublicInt and nw.IrisStyle and ply:GetPublicInt(nw.IrisStyle, 1)) or 1
    state.irisSize = (ply.GetPublicInt and nw.IrisSize and ply:GetPublicInt(nw.IrisSize, CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100)) or (CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100)
    if CH.NormalizeIrisSize then state.irisSize = CH:NormalizeIrisSize(state.irisSize) end
    state.eyeColor = parseAppearanceColor((ply.GetPublicString and nw.EyeColor and ply:GetPublicString(nw.EyeColor, "")) or "", DEFAULT_EYE_COLOR)
    state.headType = (ply.GetPublicInt and nw.HeadType and ply:GetPublicInt(nw.HeadType, 1)) or 1
    local flexRaw = (ply.GetPublicString and nw.Flex and ply:GetPublicString(nw.Flex, "")) or ""
    state.flex = (CH.NormalizeFlexTable and CH:NormalizeFlexTable(flexRaw)) or {}
    state.flexSig = flexRaw
    local bodyMarksRaw = (ply.GetPublicString and nw.BodyMarks and ply:GetPublicString(nw.BodyMarks, "")) or ""
    if ply == LocalPlayer() and istable(CH.Client.selected) then
        local sel = CH.Client.selected
        if CH.GetResolvedBodyMarks and isstring(sel.faction) and sel.faction ~= "" then
            state.bodyMarks = CH:GetResolvedBodyMarks(sel.faction, sel.body_marks) or {}
        else
            state.bodyMarks = parseResolvedBodyMarks(bodyMarksRaw)
        end
    else
        state.bodyMarks = parseResolvedBodyMarks(bodyMarksRaw)
    end
    state.bodyStyle = (ply.GetPublicInt and nw.BodyStyle and ply:GetPublicInt(nw.BodyStyle, 0)) or 0
    state.headStyle = (ply.GetPublicInt and nw.HeadStyle and ply:GetPublicInt(nw.HeadStyle, 0)) or 0
    state.hairStyle = (ply.GetPublicInt and nw.HairStyle and ply:GetPublicInt(nw.HairStyle, 0)) or 0
    state.spiritAccessory = spiritAccessory
    state.spiritAccessoryData = spiritAccessoryData
    if state.appliedBodyStyle ~= state.bodyStyle then
        setWorldBodygroup(ply, 0, state.bodyStyle)
        state.appliedBodyStyle = state.bodyStyle
    end

    if IsValid(state.headEnt) then hideBuiltInHeadBodygroups(ply) end
    if IsValid(state.headEnt) then
        local headChanged = false
        if state.appliedHeadStyle ~= state.headStyle then
            setWorldBodygroup(state.headEnt, 0, state.headStyle)
            state.appliedHeadStyle = state.headStyle
        end

        if state.appliedHairStyleOnHead ~= state.hairStyle then
            setWorldBodygroup(state.headEnt, 1, state.hairStyle)
            state.appliedHairStyleOnHead = state.hairStyle
        end

        if state.appliedHeadScale ~= state.modelScale then
            state.headEnt:SetModelScale(state.modelScale, 0)
            state.appliedHeadScale = state.modelScale
            headChanged = true
        end

        if mustRebuild or headChanged then
            state.headEnt:InvalidateBoneCache()
            state.headEnt:SetupBones()
        end

        if mustRebuild or state.appliedFlexSig ~= state.flexSig then
            if CH.ApplyFlex then CH.ApplyFlex(state.headEnt, state.flex) end
            state.appliedFlexSig = state.flexSig
        end

        state.markEnts = syncBodyMarkLayerSet(state.headEnt, state.markEnts, state.bodyMarks, "world_" .. tostring(ply:EntIndex()), ply)
    end

    if IsValid(state.accessoryEnt) then
        local accessoryChanged = false
        if CH.ApplySpiritAccessoryClientTransform then
            accessoryChanged = CH:ApplySpiritAccessoryClientTransform(state.accessoryEnt, state.modelScale, state.spiritAccessoryData) or accessoryChanged
        elseif state.appliedAccessoryScale ~= state.modelScale then
            state.accessoryEnt:SetModelScale(state.modelScale, 0)
            state.appliedAccessoryScale = state.modelScale
            accessoryChanged = true
        end

        if mustRebuild or accessoryChanged then
            state.accessoryEnt:InvalidateBoneCache()
            state.accessoryEnt:SetupBones()
        end
    end
    return state
end

VERSE.Hook.AddNS("Characters", "Think", "VERSE::Think::Characters::WorldAppearance", function()
    local now = CurTime()
    if now < nextWorldAppearanceRefresh then return end
    nextWorldAppearanceRefresh = now + getWorldAppearanceRefreshInterval()
    for ply in pairs(WORLD_APPEARANCE) do
        if not IsValid(ply) or not shouldKeepWorldAppearance(ply) then removeWorldAppearance(ply) end
    end
end)

-- ─── Reconstruction de la tête après sortie de véhicule ──────────────────────
-- Quand un joueur quitte un véhicule (ex : siège lubu controller supprimé),
-- les bodygroups de tête intégrée peuvent rester dans l'état "caché" alors que
-- le headEnt n'est plus synchronisé → joueur sans tête.
-- On force removeWorldAppearance (qui restaure les bodygroups via
-- restoreBuiltInHeadBodygroups) puis le PrePlayerDraw suivant recrée le headEnt.
VERSE.Hook.AddNS("Characters", "PlayerLeaveVehicle", "VERSE::Characters::WorldAppearance::VehicleExit", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    -- Supprime l'état courant (appelle restoreBuiltInHeadBodygroups en interne pour
    -- remettre la tête intégrée visible) et force une reconstruction complète au
    -- prochain PrePlayerDraw (WORLD_APPEARANCE[ply] = nil → mustRebuild = true).
    removeWorldAppearance(ply)
end)

-- ─── Tracker de passe principale ─────────────────────────────────────────────
-- PostPlayerDraw se déclenche aussi pendant le rendu des shadow maps (render
-- target = nil, comme la scène principale). Sans guard, le hook shadow consomme
-- le token FrameNumber, puis la vraie passe saute le dessin de la tête et
-- la restauration de la teinte skin → joueur sans tête et sans couleur à distance.
-- PreRender/PostRender ne se déclenchent QUE pendant la passe caméra principale.
-- (_inMainRender est déclaré en haut du fichier pour être visible par le
-- générateur de dégradé, qui doit différer la création de RT hors de cette passe.)
hook.Add("PreRender",  "VERSE::Characters::MainRenderTrack", function() _inMainRender = true  end)
hook.Add("PostRender", "VERSE::Characters::MainRenderTrack", function() _inMainRender = false end)

VERSE.Hook.AddNS("Characters", "PrePlayerDraw", "VERSE::PrePlayerDraw::Characters::WorldAppearance", function(ply)
    if not _inMainRender then return end   -- ignorer shadow maps / depth prepass
    if ply:GetNWBool("VERSE_StaffMode") then
        -- Joueur local en staff : corps déjà invisible depuis notre point de vue,
        -- on maintient quand même l'état d'apparence des AUTRES joueurs en staff
        -- pour que la tête revienne instantanément quand ils quittent le staff mode.
        if ply ~= LocalPlayer() then refreshWorldAppearance(ply) end
        return
    end
    local state = refreshWorldAppearance(ply)
    if not state then return end
    local skinTint = state.skinColor or DEFAULT_SKIN_TONES[1]
    setWorldEntityTint(ply, skinTint, isSkinMaterialNameBase)
end)

local function applyVoiceMouthFlex(state, ply)
    local base = state.flex or {}
    if not IsValid(state.headEnt) or not IsValid(ply) then return base end
    local rawSpeaking = (ply.IsSpeaking and ply:IsSpeaking() == true) or false
    state.voiceSustain = state.voiceSustain or 0
    if rawSpeaking then
        state.voiceSustain = 0.15
    else
        state.voiceSustain = math.max(0, state.voiceSustain - FrameTime())
    end

    local speaking = state.voiceSustain > 0
    if speaking and not (state.voiceWasSpeaking or false) then state.voicePhase = 0 end
    state.voiceWasSpeaking = speaking
    local target = speaking and 1 or 0
    local current = state.voiceMouth or 0
    local rate = speaking and 4.5 or 14
    current = current + (target - current) * math.Clamp(FrameTime() * rate, 0, 1)
    if current < 0.005 then current = 0 end
    state.voiceMouth = current
    local combined = {}
    for _, name in ipairs(CH.FlexControllers or {}) do
        combined[name] = base[name] or 0
    end

    if not speaking then
        state.voicePhase = 0
        if current <= 0 then return combined end
        local baseJaw = combined.jawdrop or 0
        combined.jawdrop = baseJaw
        return combined
    end

    state.voicePhase = (state.voicePhase or 0) + FrameTime() * 1.3
    local primary = 0.5 - 0.5 * math.cos(state.voicePhase)
    local secondary = 0.5 - 0.5 * math.cos(state.voicePhase * 1.5 + 0.6)
    local osc01 = primary * 0.8 + secondary * 0.2
    osc01 = osc01 * osc01 * (3 - 2 * osc01)
    local baseJaw = combined.jawdrop or 0
    combined.jawdrop = Lerp(current, baseJaw, osc01)
    return combined
end

local function colorSig(c, fb)
    c = c or fb
    if not c then return "0" end
    return string.format("%d,%d,%d", c.r or 255, c.g or 255, c.b or 255)
end

VERSE.Hook.AddNS("Characters", "PostPlayerDraw", "VERSE::PostPlayerDraw::Characters::WorldAppearance", function(ply)
    local state = WORLD_APPEARANCE[ply]
    if not state then return end

    -- Guards de rendu — deux niveaux obligatoires :
    -- 1) render.GetRenderTarget() ~= nil → reflet eau / render target custom → restaure teinte et sort.
    -- 2) _inMainRender == false → shadow map / depth prepass (render target nil comme la scène
    --    principale). Sans ce guard, les shadows consomment le token de frame → tête invisible à distance.
    --    On sort silencieusement (sans toucher la teinte) pour que PrePlayerDraw de la passe principale
    --    puisse encore l'appliquer.
    -- 3) lastAppearanceFrame → guard anti-double-exécution dans la même frame principale.
    --    CRITIQUE : sans lui, les SetSubMaterial + DrawModel des tatouages s'accumulent par frame
    --    et épuisent le buffer 64 KB de Source Engine → crash "OUT OF MEMORY: 65536".
    if render.GetRenderTarget() ~= nil then
        -- Reflet/render target : on réinitialise $color2 seulement.
        -- SetPlayerColor reste persistant (couleur de peau).
        resetBodyColor2Only(ply, isSkinMaterialNameBase)
        return
    end
    if not _inMainRender then return end   -- shadow map : on ne touche rien

    local frame = FrameNumber and FrameNumber() or 0
    if state.lastAppearanceFrame == frame then
        -- Anti-double : réinitialise $color2 seulement, SetPlayerColor reste persistant.
        resetBodyColor2Only(ply, isSkinMaterialNameBase)
        return
    end
    state.lastAppearanceFrame = frame

    -- Joueur en mode staff :
    -- • Joueur LOCAL → on cache la tête (vue FPS : elle flotterait devant l'écran).
    -- • Autres joueurs → on ne cache PAS la tête ici : le corps est rendu
    --   transparent par le serveur (alpha=0 / RENDERMODE_TRANSALPHA) et la
    --   tête suit. Cacher la tête via NWBool créait un glitch de synchro réseau
    --   où la tête disparaissait quelques frames avant que le corps ne devienne
    --   transparent (NWBool plus rapide que la propagation du render mode).
    if ply:GetNWBool("VERSE_StaffMode") then
        if ply == LocalPlayer() then
            resetBodyColor2Only(ply, isSkinMaterialNameBase)
            if IsValid(state.headEnt) then state.headEnt:SetNoDraw(true) end
            return
        end
        -- Pour les autres joueurs en staff : reset $color2 seulement,
        -- puis on continue pour dessiner leur tête normalement.
        resetBodyColor2Only(ply, isSkinMaterialNameBase)
    end

    if not IsValid(state.headEnt) then
        -- headEnt invalidé (GC après freeze lourd ou nettoyage externe) :
        -- forcer un rebuild immédiat au prochain PrePlayerDraw.
        state.nextRefreshAt = nil
        WORLD_APPEARANCE[ply] = nil
        return
    end

    if IsValid(state.headEnt) then
        -- Ré-enforcement SetNoDraw : défense contre PAC3 / addons tiers qui
        -- pourraient appeler SetNoDraw(false) et provoquer un double rendu
        -- automatique par le moteur hors de la passe PostPlayerDraw.
        state.headEnt:SetNoDraw(true)

        local skinTint = state.skinColor or DEFAULT_SKIN_TONES[1]
        local hairC = state.hairColor or DEFAULT_HAIR_COLOR
        local eyebrowTint = state.eyebrowColor or hairC
        local eyelashTint = state.eyelashColor or DEFAULT_EYELASH_COLOR
        local eyeTint = state.eyeColor or color_white
        local irisStyle = math.Clamp(math.floor(tonumber(state.irisStyle) or 1), 1, getEyeStyleCount())
        local irisSize = tonumber(state.irisSize) or (CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100)
        local skinSig = colorSig(skinTint, DEFAULT_SKIN_TONES[1])
        if state.appliedSkinSig ~= skinSig then
            setEntitySkinColorRuntime(state.headEnt, skinTint)
            state.appliedSkinSig = skinSig
        end

        -- Dégradé de cheveux (expérimental) : si state.hairGradient = {c1, c2} est
        -- défini, on applique le matériau dégradé au lieu de la couleur unie.
        if istable(state.hairGradient) then
            local g = state.hairGradient
            local gsig = "grad:" .. colorSig(g[1], DEFAULT_HAIR_COLOR) .. ":" .. colorSig(g[2], DEFAULT_HAIR_COLOR)
            if state.appliedHairColorSig ~= gsig then
                -- On ne mémorise le sig QUE si le dégradé a été appliqué (matériau prêt).
                -- Sinon (génération différée hors rendu) on réessaie au frame suivant.
                if setEntityHairGradient(state.headEnt, g[1], g[2]) then
                    state.appliedHairColorSig = gsig
                end
            end
        else
            local hairSig = colorSig(hairC, DEFAULT_HAIR_COLOR)
            if state.appliedHairColorSig ~= hairSig then
                setEntityHairColor(state.headEnt, hairC)
                state.appliedHairColorSig = hairSig
            end
        end

        if IsValid(state.hairEnt) then
            local hairEntSig = colorSig(hairC, DEFAULT_HAIR_COLOR)
            if state.appliedHairEntColorSig ~= hairEntSig then
                setEntityHairColor(state.hairEnt, hairC)
                state.appliedHairEntColorSig = hairEntSig
            end
        end

        local eyebrowSig = colorSig(eyebrowTint, DEFAULT_HAIR_COLOR)
        if state.appliedEyebrowSig ~= eyebrowSig then
            setEntityEyebrowColor(state.headEnt, eyebrowTint)
            state.appliedEyebrowSig = eyebrowSig
        end

        local eyelashSig = colorSig(eyelashTint, DEFAULT_EYELASH_COLOR)
        if state.appliedEyelashSig ~= eyelashSig then
            -- On ne mémorise le sig QUE si l'application a réussi (slot trouvé).
            -- Si le modèle n'était pas encore chargé, setEntityEyelashColor retourne false
            -- et on réessaiera au prochain frame jusqu'à ce que le slot soit disponible.
            if setEntityEyelashColor(state.headEnt, eyelashTint) then
                state.appliedEyelashSig = eyelashSig
            end
        end

        local irisSig = string.format("%d|%d|%s", irisStyle, math.floor(irisSize), colorSig(eyeTint, color_white))
        if state.appliedIrisSig ~= irisSig then
            setEntityIris(state.headEnt, irisStyle, irisSize, eyeTint)
            state.appliedIrisSig = irisSig
        end

        local eyePos = EyePos()
        if eyePos:DistToSqr(ply:GetPos()) <= FLEX_PER_FRAME_MAX_DIST_SQ then
            local flexToApply = applyVoiceMouthFlex(state, ply)
            local newMouth = state.voiceMouth or 0
            if state._lastAppliedMouth ~= newMouth then
                if CH.ApplyFlex then CH.ApplyFlex(state.headEnt, flexToApply) end
                state._lastAppliedMouth = newMouth
            end
        elseif (state._lastAppliedMouth or 0) ~= 0 then
            if CH.ApplyFlex then CH.ApplyFlex(state.headEnt, state.flex or {}) end
            state._lastAppliedMouth = 0
        end

        setWorldEntityTint(ply, skinTint, isSkinMaterialNameBase)

        -- Détection du trou de rendu : si PostPlayerDraw n'a pas fire pour ce joueur
        -- au frame précédent (occlusion / noclip à travers un mur), le moteur a gelé
        -- les bones du joueur côté client → la tête (EF_BONEMERGE) reste coincée à
        -- l'ancienne position. Un dash / double saut défige le problème car ils
        -- forcent un changement d'activité = recomposition complète des bones.
        -- On reproduit ce réveil UNIQUEMENT sur la frame de réapparition (coût nul
        -- en jeu normal : zéro recalcul de bones supplémentaire par frame).
        local _fnum = FrameNumber()
        if state._lastHeadDrawFrame and (_fnum - state._lastHeadDrawFrame) > 1 then
            -- Réveille les bones du joueur parent puis re-merge la tête à neuf.
            ply:InvalidateBoneCache()
            ply:SetupBones()
            state.headEnt:SetParent(nil)
            state.headEnt:SetPos(ply:GetPos())
            state.headEnt:SetAngles(ply:GetAngles())
            state.headEnt:SetParent(ply)
            state.headEnt:RemoveEffects(EF_BONEMERGE)
            state.headEnt:AddEffects(EF_BONEMERGE)
            state.headEnt:SetLocalPos(vector_origin)
            state.headEnt:SetLocalAngles(angle_zero)
        end
        state._lastHeadDrawFrame = _fnum

        state.headEnt:InvalidateBoneCache()
        state.headEnt:SetupBones()
        -- Bounds world-space centrés sur le joueur : plus fiables que SetRenderBounds
        -- (local) que le moteur peut recalculer automatiquement via les bones après
        -- un noclip à travers un mur. SetRenderBoundsWS est absolu et n'est jamais
        -- recalculé automatiquement par Source Engine.
        local _wsPos = ply:GetPos()
        local _wsOff = Vector(200, 200, 300)
        state.headEnt:SetRenderBoundsWS(_wsPos - _wsOff, _wsPos + _wsOff)
        -- Force le blend à 1 pour annuler le fade de distance interne des CSM.
        -- Sans ça, DrawModel() utilise l'alpha de fade calculé par le moteur,
        -- ce qui rend la tête transparente à mi-distance.
        render.SetBlend(1)
        state.headEnt:DrawModel()
        render.SetBlend(1)

        -- Tatouage : dessiné sur headEnt directement — zéro entité CSM supplémentaire.
        if BODY_MARK_ENABLED_CVAR:GetBool() and istable(state.markEnts) then
            local doRender = true
            if ply ~= LocalPlayer() then
                local maxDist = BODY_MARK_DIST_CVAR:GetFloat()
                if maxDist > 0 then
                    if eyePos:DistToSqr(ply:GetPos()) > maxDist * maxDist then
                        doRender = false
                    else
                        local eyeDir = EyeAngles():Forward()
                        local toOwner = (ply:GetPos() - eyePos):GetNormalized()
                        if eyeDir:Dot(toOwner) < BODY_MARK_DOT_THRESHOLD then doRender = false end
                    end
                end
            end
            if doRender then
                local sortedKeys = state.markEnts.__sortedKeys
                if not sortedKeys then
                    sortedKeys = {}
                    for k in pairs(state.markEnts) do
                        if not (isstring(k) and string.sub(k, 1, 2) == "__") then
                            sortedKeys[#sortedKeys + 1] = k
                        end
                    end
                    table.sort(sortedKeys)
                    state.markEnts.__sortedKeys = sortedKeys
                end
                local hiddenMat     = getBodyMarkLayerHiddenMaterial()
                local hiddenMatName = hiddenMat and not hiddenMat:IsError() and ("!" .. hiddenMat:GetName()) or nil
                local drewTattoo = false
                for i = 1, #sortedKeys do
                    local layerData = state.markEnts[sortedKeys[i]]
                    if istable(layerData) and layerData.__isWorldLayer then
                        local faceSlots    = layerData.__faceSlots
                        local nonFaceSlots = layerData.__nonFaceSlots
                        local tatName      = layerData.__tatName
                        local targetEnt    = state.headEnt
                        if faceSlots and tatName and #faceSlots > 0 and hiddenMatName and IsValid(targetEnt) then
                            -- Approche hiddenMat : slots non-cible → matériau caché (invisible via
                            -- vertex alpha + entité alpha=0). Slots cible → matériau tatouage.
                            if nonFaceSlots then
                                for _, s in ipairs(nonFaceSlots) do targetEnt:SetSubMaterial(s, hiddenMatName) end
                            end
                            for _, s in ipairs(faceSlots) do targetEnt:SetSubMaterial(s, tatName) end
                            targetEnt:SetColor(_CH_COL_MARK_HIDE)
                            targetEnt:SetRenderMode(RENDERMODE_TRANSCOLOR)
                            render.DepthRange(0, BODY_MARK_LAYER_DEPTH_MAX - (i - 1) * 0.0001)
                            targetEnt:DrawModel()
                            render.DepthRange(0, 1)
                            -- Restaurer couleur et tous les slots
                            targetEnt:SetColor(_CH_COL_MARK_SHOW)
                            targetEnt:SetRenderMode(RENDERMODE_NORMAL)
                            if nonFaceSlots then
                                for _, s in ipairs(nonFaceSlots) do targetEnt:SetSubMaterial(s, "") end
                            end
                            for _, s in ipairs(faceSlots) do targetEnt:SetSubMaterial(s, "") end
                            drewTattoo = true
                        end
                    end
                end
                if drewTattoo then
                    -- SetSubMaterial("") a effacé TOUS les overrides (peau, cheveux, sourcils, cils, iris).
                    -- Réinitialiser les sigs pour forcer le réapplication au prochain frame,
                    -- et restaurer immédiatement pour que headEnt soit correct entre les frames.
                    state.appliedSkinSig      = nil
                    state.appliedHairColorSig  = nil
                    state.appliedEyebrowSig    = nil
                    state.appliedEyelashSig    = nil
                    state.appliedIrisSig       = nil
                    setEntitySkinColorRuntime(state.headEnt, skinTint)
                    setEntityHairColor(state.headEnt, hairC)
                    setEntityEyebrowColor(state.headEnt, eyebrowTint)
                    setEntityEyelashColor(state.headEnt, eyelashTint)
                    setEntityIris(state.headEnt, irisStyle, irisSize, eyeTint)
                end
            end
        end
    end

    if IsValid(state.accessoryEnt) then
        -- Même protection SetNoDraw que pour headEnt
        state.accessoryEnt:SetNoDraw(true)
        state.accessoryEnt:InvalidateBoneCache()
        state.accessoryEnt:SetupBones()
        state.accessoryEnt:DrawModel()
    end

    if IsValid(state.hairEnt) then
        state.hairEnt:SetNoDraw(true)
        local _wsPos2 = ply:GetPos()
        local _wsOff2 = Vector(200, 200, 300)
        state.hairEnt:SetRenderBoundsWS(_wsPos2 - _wsOff2, _wsPos2 + _wsOff2)
        render.SetBlend(1)
        state.hairEnt:DrawModel()
        render.SetBlend(1)
    end

    -- Réinitialise uniquement $color2 (matériau partagé) à blanc neutre après le rendu.
    -- SetPlayerColor reste persistant : il est maintenu à la couleur de peau par
    -- refreshWorldAppearance et ne doit jamais être remis à blanc ici, sinon le corps
    -- du joueur deviendrait blanc dès qu'il sort de la plage WorldAppearanceDistance.
    resetBodyColor2Only(ply, isSkinMaterialNameBase)

end)

function CH:RequestList()
    netstream.Start(CH.Net.List)
end

function CH:RequestCreate(data)
    netstream.Start(CH.Net.Create, data or {})
end

function CH:RequestDelete(slot)
    slot = tonumber(slot) or 1
    netstream.Start(CH.Net.Delete, slot)
end

function CH:RequestSelect(slot)
    slot = tonumber(slot) or 1
    netstream.Start(CH.Net.Select, slot)
end

function CH:RequestKnown()
    netstream.Start(CH.Net.Known)
end

function CH:RequestIntroduce(targetPly)
    if not IsValid(targetPly) then return end
    netstream.Start(CH.Net.Introduce, targetPly:EntIndex())
end

function CH:RequestIntroduceAnswer(fromPly, accepted)
    if not IsValid(fromPly) then return end
    netstream.Start(CH.Net.IntroduceAnswer, fromPly:EntIndex(), accepted == true)
end

function CH:RequestAdminList()
    netstream.Start(CH.Net.AdminList)
end

function CH:RequestAdminDelete(targetSteamID64, slot)
    targetSteamID64 = tostring(targetSteamID64 or ""):Trim()
    if targetSteamID64 == "" then return end
    slot = tonumber(slot) or 0
    if slot <= 0 then return end
    netstream.Start(CH.Net.AdminDelete, targetSteamID64, slot)
end

netstream.Hook(CH.Net.List, function(slots, list)
    CH.Client.slots = tonumber(slots) or 1
    CH.Client.list = istable(list) and list or {}
    if not CH.Client.selected then CH:CharacterSelect(CH.Client.list) end
end)

netstream.Hook(CH.Net.AdminList, function(list)
    CH.Client.adminList = istable(list) and list or {}
    if IsValid(characterAdminFrame) and isfunction(characterAdminFrame._populateAdminList) then characterAdminFrame:_populateAdminList(CH.Client.adminList) end
end)

netstream.Hook(CH.Net.Selected, function(ok, payload)
    if ok ~= true then
        local code = tostring(payload or "unknown")
        CH.Client.lastError = code
        CH:NotifyError(code, 4)
        if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Characters::ClientSelected", nil, false, code) end
        return
    end

    local isSelected = istable(payload)
    CH.Client.selected = isSelected and payload or nil
    local lp = LocalPlayer()
    if IsValid(lp) and WORLD_APPEARANCE[lp] then
        WORLD_APPEARANCE[lp].nextRefreshAt = nil
    end
    CH.Client.knownNames = {}
    ensureLocalKnownName()
    if CH:AcquaintancesEnabled() then CH:RequestKnown() end
    if isSelected then
        if IsValid(characterSelectFrame) then characterSelectFrame:Close() end
        if IsValid(characterCreateFrame) then characterCreateFrame:Close() end
        if isfunction(CH.StopMenuMusic) then CH:StopMenuMusic() end
    end

    if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Characters::ClientSelected", CH.Client.selected, true, payload) end
end)

netstream.Hook(CH.Net.Known, function(tbl)
    CH.Client.knownNames = istable(tbl) and tbl or {}
    ensureLocalKnownName()
end)

netstream.Hook(CH.Net.KnownUpdate, function(mode, id, name)
    mode = tonumber(mode) or 0
    id = tonumber(id)
    CH.Client.knownNames = CH.Client.knownNames or {}
    if mode == 1 and id then
        name = tostring(name or "")
        if name ~= "" then CH.Client.knownNames[id] = name end
        if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Characters::Introduced", id, name) end
    elseif mode == 2 and id then
        CH.Client.knownNames[id] = nil
        if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Characters::Forgotten", id) end
    end

    ensureLocalKnownName()
end)

-- Présentation à sens unique : A presse N → B apprend le nom de A sans popup.
-- Le hook IntroduceRequest n'est plus utilisé (géré directement côté serveur).
netstream.Hook(CH.Net.IntroduceRequest, function() end)

VERSE.Hook.AddNS("Characters", "InitPostEntity", "VERSE::InitPostEntity::Character", function() timer.Simple(0, function() if CH:ConfigBool("Enabled", true) then CH:RequestList() end end) end)
local __charCtx = CH.__ClientCharacterContext or {}
CH.__ClientCharacterContext = __charCtx
local function syncCharacterContext(entries)
    for i = 1, #entries do
        local entry = entries[i]
        __charCtx[entry.key] = entry.value
    end
end

syncCharacterContext({
    {
        key = "CH",
        value = CH
    },
    {
        key = "R",
        value = R
    },
    {
        key = "Font",
        value = Font
    },
    {
        key = "Language",
        value = Language
    },
    {
        key = "Materials",
        value = Materials
    },
    {
        key = "CHAR_PREVIEW_MDL",
        value = CHAR_PREVIEW_MDL
    },
    {
        key = "CHAR_VIEW_W",
        value = CHAR_VIEW_W
    },
    {
        key = "CHAR_CAM_ANG",
        value = CHAR_CAM_ANG
    },
    {
        key = "CHAR_MDL_POS",
        value = CHAR_MDL_POS
    },
    {
        key = "CHAR_MDL_ANG",
        value = CHAR_MDL_ANG
    },
    {
        key = "CHAR_CAM_FOV",
        value = CHAR_CAM_FOV
    },
    {
        key = "DEFAULT_SKIN_TONES",
        value = DEFAULT_SKIN_TONES
    },
    {
        key = "DEFAULT_HAIR_COLOR",
        value = DEFAULT_HAIR_COLOR
    },
    {
        key = "DEFAULT_EYE_COLOR",
        value = DEFAULT_EYE_COLOR
    },
    {
        key = "FACE_SKIN_RUNTIME_MATERIALS",
        value = FACE_SKIN_RUNTIME_MATERIALS
    },
    {
        key = "FACE_MATERIAL_SLOT_CACHE",
        value = FACE_MATERIAL_SLOT_CACHE
    },
    {
        key = "FACE_EYEBROW_RUNTIME_MATERIALS",
        value = FACE_EYEBROW_RUNTIME_MATERIALS
    },
    {
        key = "FACE_EYE_RUNTIME_MATERIALS",
        value = FACE_EYE_RUNTIME_MATERIALS
    },
    {
        key = "BODY_MARK_LAYER_MATERIALS",
        value = BODY_MARK_LAYER_MATERIALS
    },
    {
        key = "BODY_MARK_LAYER_HIDDEN_MATERIAL",
        value = BODY_MARK_LAYER_HIDDEN_MATERIAL
    },
    {
        key = "BODY_MARK_OFFSET_MIN",
        value = BODY_MARK_OFFSET_MIN
    },
    {
        key = "BODY_MARK_OFFSET_MAX",
        value = BODY_MARK_OFFSET_MAX
    },
    {
        key = "BODY_MARK_DEPTH_MIN",
        value = BODY_MARK_DEPTH_MIN
    },
    {
        key = "BODY_MARK_DEPTH_MAX",
        value = BODY_MARK_DEPTH_MAX
    },
    {
        key = "BODY_MARK_SIZE_MIN",
        value = BODY_MARK_SIZE_MIN
    },
    {
        key = "BODY_MARK_SIZE_MAX",
        value = BODY_MARK_SIZE_MAX
    },
    {
        key = "BODY_MARK_DEFAULT_X",
        value = BODY_MARK_DEFAULT_X
    },
    {
        key = "BODY_MARK_DEFAULT_Y",
        value = BODY_MARK_DEFAULT_Y
    },
    {
        key = "BODY_MARK_DEFAULT_Z",
        value = BODY_MARK_DEFAULT_Z
    },
    {
        key = "BODY_MARK_DEFAULT_ROTATE",
        value = BODY_MARK_DEFAULT_ROTATE
    },
    {
        key = "BODY_MARK_DEFAULT_SIZE",
        value = BODY_MARK_DEFAULT_SIZE
    },
    {
        key = "BODY_MARK_SIZE_SCALE_BASE",
        value = BODY_MARK_SIZE_SCALE_BASE
    },
    {
        key = "BODY_MARK_CENTER_BIAS_X",
        value = BODY_MARK_CENTER_BIAS_X
    },
    {
        key = "BODY_MARK_CENTER_BIAS_Y",
        value = BODY_MARK_CENTER_BIAS_Y
    },
    {
        key = "WORLD_APPEARANCE",
        value = WORLD_APPEARANCE
    },
    {
        key = "WORLD_APPEARANCE_MATERIALS",
        value = WORLD_APPEARANCE_MATERIALS
    },
    {
        key = "getCharacterSelectFrame",
        value = function() return characterSelectFrame end
    },
    {
        key = "setCharacterSelectFrame",
        value = function(v) characterSelectFrame = v end
    },
    {
        key = "getCharacterCreateFrame",
        value = function() return characterCreateFrame end
    },
    {
        key = "setCharacterCreateFrame",
        value = function(v) characterCreateFrame = v end
    },
    {
        key = "getCharacterAdminFrame",
        value = function() return characterAdminFrame end
    },
    {
        key = "setCharacterAdminFrame",
        value = function(v) characterAdminFrame = v end
    },
    {
        key = "computeCamFromModel",
        value = computeCamFromModel
    },
    {
        key = "bindAnimatedCard",
        value = bindAnimatedCard
    },
    {
        key = "ensureLocalKnownName",
        value = ensureLocalKnownName
    },
    {
        key = "cloneAppearanceColor",
        value = cloneAppearanceColor
    },
    {
        key = "parseAppearanceColor",
        value = parseAppearanceColor
    },
    {
        key = "normalizeAppearanceModelPath",
        value = normalizeAppearanceModelPath
    },
    {
        key = "isFaceControlModel",
        value = isFaceControlModel
    },
    {
        key = "getEyebrowStyleCount",
        value = getEyebrowStyleCount
    },
    {
        key = "getEyebrowMaterialPath",
        value = getEyebrowMaterialPath
    },
    {
        key = "getEyeStyleCount",
        value = getEyeStyleCount
    },
    {
        key = "getEyeMaterialPath",
        value = getEyeMaterialPath
    },
    {
        key = "normalizeMaterialPath",
        value = normalizeMaterialPath
    },
    {
        key = "parseResolvedBodyMarks",
        value = parseResolvedBodyMarks
    },
    {
        key = "getBodyMarkDepthMax",
        value = getBodyMarkDepthMax
    },
    {
        key = "isEyeMaterialName",
        value = isEyeMaterialName
    },
    {
        key = "isEyebrowMaterialName",
        value = isEyebrowMaterialName
    },
    {
        key = "isSkinMaterialNameBase",
        value = isSkinMaterialNameBase
    },
    {
        key = "isBodyMarkFaceMaterialName",
        value = isBodyMarkFaceMaterialName
    },
    {
        key = "clearBodyMarkLayerSet",
        value = clearBodyMarkLayerSet
    },
    {
        key = "drawBodyMarkLayerSet",
        value = drawBodyMarkLayerSet
    },
    {
        key = "getBodyMarkLayerHiddenMaterial",
        value = getBodyMarkLayerHiddenMaterial
    },
    {
        key = "resolveBodyMarkTexturePath",
        value = resolveBodyMarkTexturePath
    },
    {
        key = "applyBodyMarkLayerTransform",
        value = applyBodyMarkLayerTransform
    },
    {
        key = "getBodyMarkLayerMaterial",
        value = getBodyMarkLayerMaterial
    },
    {
        key = "ensureBodyMarkLayerEntity",
        value = ensureBodyMarkLayerEntity
    },
    {
        key = "syncBodyMarkLayerSet",
        value = syncBodyMarkLayerSet
    },
    {
        key = "getFaceMaterialSlot",
        value = getFaceMaterialSlot
    },
    {
        key = "shouldSkipFaceSkinTintSlot",
        value = shouldSkipFaceSkinTintSlot
    },
    {
        key = "applyEntityEyebrowMaterial",
        value = applyEntityEyebrowMaterial
    },
    {
        key = "getActiveEyebrowMaterial",
        value = getActiveEyebrowMaterial
    },
    {
        key = "setEyebrowMaterialTint",
        value = setEyebrowMaterialTint
    },
    {
        key = "applyEntityEyeMaterial",
        value = applyEntityEyeMaterial
    },
    {
        key = "getActiveEyeMaterial",
        value = getActiveEyeMaterial
    },
    {
        key = "setEyeMaterialTint",
        value = setEyeMaterialTint
    },
    {
        key = "setEyeMaterialSize",
        value = setEyeMaterialSize
    },
    {
        key = "getMaterialTextureName",
        value = getMaterialTextureName
    },
    {
        key = "getFaceSkinRuntimeMaterial",
        value = getFaceSkinRuntimeMaterial
    },
    {
        key = "setFaceHeadSkinTint",
        value = setFaceHeadSkinTint
    },
    {
        key = "clearFaceHeadSkinTint",
        value = clearFaceHeadSkinTint
    },
    {
        key = "buildWorldSkinPalette",
        value = buildWorldSkinPalette
    },
    {
        key = "getWorldTintMaterials",
        value = getWorldTintMaterials
    },
    {
        key = "setWorldEntityTint",
        value = setWorldEntityTint
    },
    {
        key = "setWorldBodygroup",
        value = setWorldBodygroup
    },
    {
        key = "getPublicCharId",
        value = getPublicCharId
    },
    {
        key = "getWorldAppearanceDistanceSqr",
        value = getWorldAppearanceDistanceSqr
    },
    {
        key = "getWorldAppearanceRefreshInterval",
        value = getWorldAppearanceRefreshInterval
    },
    {
        key = "isCharacterMenuOpen",
        value = isCharacterMenuOpen
    },
    {
        key = "shouldKeepWorldAppearance",
        value = shouldKeepWorldAppearance
    },
    {
        key = "removeWorldAppearance",
        value = removeWorldAppearance
    },
    {
        key = "clearWorldAppearanceStates",
        value = clearWorldAppearanceStates
    },
    {
        key = "spawnWorldAppearancePart",
        value = spawnWorldAppearancePart
    },
    {
        key = "refreshWorldAppearance",
        value = refreshWorldAppearance
    },
})