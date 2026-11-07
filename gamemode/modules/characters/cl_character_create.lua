local CH = VERSE and VERSE.Characters
local __charCtx = CH and CH.__ClientCharacterContext
if not __charCtx then return end
local __partEnv = setmetatable({}, {
    __index = function(_, key)
        if key == "characterSelectFrame" then return __charCtx.getCharacterSelectFrame and __charCtx.getCharacterSelectFrame() or nil end
        if key == "characterCreateFrame" then return __charCtx.getCharacterCreateFrame and __charCtx.getCharacterCreateFrame() or nil end
        if key == "characterAdminFrame" then return __charCtx.getCharacterAdminFrame and __charCtx.getCharacterAdminFrame() or nil end
        local value = __charCtx[key]
        if value ~= nil then return value end
        return _G[key]
    end,
    __newindex = function(_, key, value)
        if key == "characterSelectFrame" then
            if __charCtx.setCharacterSelectFrame then __charCtx.setCharacterSelectFrame(value) end
            return
        end

        if key == "characterCreateFrame" then
            if __charCtx.setCharacterCreateFrame then __charCtx.setCharacterCreateFrame(value) end
            return
        end

        if key == "characterAdminFrame" then
            if __charCtx.setCharacterAdminFrame then __charCtx.setCharacterAdminFrame(value) end
            return
        end

        __charCtx[key] = value
    end,
})

setfenv(1, __partEnv)
function CH:CharacterCreate(slot, preselectedFaction)
    if IsValid(characterCreateFrame) then
        if isfunction(characterCreateFrame._cleanupPreview) then
            local ok, err = pcall(characterCreateFrame._cleanupPreview)
            if not ok and VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[Characters] preview cleanup failed: " .. tostring(err)) end
        end

        characterCreateFrame:Remove()
    end

    if not self:ConfigBool("Enabled", true) then return end
    clearWorldAppearanceStates()
    if isfunction(CH.StartMenuMusic) then CH:StartMenuMusic() end
    local scrw, scrh = 1920, 1080
    local cfg = self:GetConfig()
    slot = tonumber(slot) or 1
    characterCreateFrame = vgui.Create("MantleFrame")
    characterCreateFrame:SetSize(R:XY(scrw, scrh))
    characterCreateFrame:Center()
    characterCreateFrame:MakePopup()
    characterCreateFrame:SetDraggable(false)
    characterCreateFrame:LiteMode()
    characterCreateFrame:SetAlphaBackground(false)
    characterCreateFrame:SetClosable(false)
    characterCreateFrame:DisableCloseBtn()
    characterCreateFrame:Notify(Language("character.create_character_title"), 5)

    -- Téléporte le joueur physiquement dans la scène 3D de création
    net.Start("verse_cc_enter")
    net.SendToServer()

    -- ─── Caméra fixe 3D background ───────────────────────────────────────────────
    local _CC_POS = Vector(10185.425781, 4898.315430, 11516.524414)
    local _CC_ANG = Angle(2.046866, 1.938578, 0.004769)
    local _ccActive = true   -- flag pour nettoyer proprement depuis cleanupPreview

    -- Forward-références pour que le hook RenderScene puisse accéder à preview et
    -- _worldCharPos qui sont déclarés plus loin dans la même fonction.
    -- (En Lua les closures capturent le slot upvalue, pas la valeur au moment de
    --  la déclaration — les assignments sans 'local' plus bas utilisent ce slot.)
    local preview
    local _worldCharPos
    local _ccCamMode      = "body"  -- "body" | "face" | "head"  (forward-ref pour RenderScene)
    local _inCCRender     = false   -- true uniquement pendant render.RenderView → déclenche PostDrawOpaqueRenderables
    local _ccFaceZoom     = 60      -- distance caméra ↔ visage, modifiable par drag vertical (25..120)
    local _ccFaceCharShift = 18    -- rotation caméra vers la droite (degrés) → visage décalé à gauche du cadre

    -- RenderScene remplace ENTIÈREMENT le rendu 3D (plus fiable que CalcView).
    -- On active temporairement le NoDraw=false des CSMs pour qu'ils soient
    -- inclus dans render.RenderView → le personnage est dans la scène avec
    -- depth-test correct → plus de "flottement".
    VERSE.Hook.Add("RenderScene", "VERSE::CharCreate::RenderScene", function()
        if not _ccActive or not IsValid(characterCreateFrame) then
            VERSE.Hook.Remove("RenderScene", "VERSE::CharCreate::RenderScene")
            return
        end

        -- DynamicLight sur le personnage (avant le rendu)
        local _dlightPos = (IsValid(LocalPlayer()) and LocalPlayer():GetPos()) or _worldCharPos
        if _dlightPos then
            local dlight = DynamicLight(127)
            if dlight then
                dlight.pos        = _dlightPos + Vector(0, 0, 90)
                dlight.r          = 245
                dlight.g          = 235
                dlight.b          = 215
                dlight.brightness = 2
                dlight.Decay      = 1000
                dlight.Size       = 400
                dlight.DieTime    = CurTime() + 0.1
            end
        end

        -- Cache tous les joueurs (+ le LocalPlayer réel) d'un seul appel player.GetAll()
        -- Bien plus efficace que PrePlayerDraw (pas de pcall × N par frame).
        -- Grâce à SetPreventTransmit côté serveur, les autres joueurs en création
        -- n'existent même pas comme entités ici → la liste est quasi vide.
        local csm    = preview and preview.csm
        local headC  = preview and preview.headCSM
        local accC   = preview and preview.accessoryCSM
        local allPlys = player.GetAll()
        local plyNoDrawBefore = {}
        for _, p in ipairs(allPlys) do
            local wasND = bit.band(p:GetEffects(), EF_NODRAW) ~= 0
            plyNoDrawBefore[p] = wasND
            if not wasND then p:SetNoDraw(true) end
        end
        if IsValid(csm)   then csm:SetNoDraw(false)   end
        if IsValid(headC) then headC:SetNoDraw(false)  end
        if IsValid(accC)  then accC:SetNoDraw(false)   end
        -- (les markEnts sont des tables Lua __isWorldLayer, pas des entités ;
        --  elles sont dessinées par PostDrawOpaqueRenderables pendant render.RenderView)

        -- Caméra dynamique : zoom visage en mode "face"/"head", vue corps sinon
        -- Corps : même position/angle que la caméra principale, juste Z abaissé
        local bodyOrigin = Vector(_CC_POS.x, _CC_POS.y, _CC_POS.z - 15)
        local rvOrigin, rvAngles, rvFov = bodyOrigin, _CC_ANG, 60
        if _ccCamMode == "face" or _ccCamMode == "head" then
            -- Priorité : os de la tête du CSM (suit la taille réelle du modèle)
            local headPos
            local csmEnt = preview and preview.csm
            if IsValid(csmEnt) then
                local boneId = csmEnt:LookupBone("ValveBiped.Bip01_Head1")
                if boneId then
                    local bp = csmEnt:GetBonePosition(boneId)
                    if isvector(bp) and bp ~= vector_origin then headPos = bp end
                end
            end
            -- Fallback : EyePos du LocalPlayer (hauteur des yeux du vrai modèle)
            if not headPos then
                local lp = LocalPlayer()
                headPos = IsValid(lp) and lp:EyePos() or (_worldCharPos + Vector(0,0,64))
            end
            -- Direction horizontale pure vers la caméra (évite l'angle de vue oblique)
            local towardCam = Vector(_CC_POS.x - headPos.x, _CC_POS.y - headPos.y, 0):GetNormalized()
            -- _ccFaceZoom : distance contrôlée par drag vertical (défaut 60 pour face, 85 pour head)
            rvOrigin = headPos + towardCam * _ccFaceZoom
            -- Angle de base centré sur la tête, puis rotation yaw vers la droite
            -- → la tête reste dans le cadre mais décalée vers la gauche de l'écran
            rvAngles = (headPos - rvOrigin):Angle()
            rvAngles.y = rvAngles.y - _ccFaceCharShift
            rvFov = 60
        end

        _inCCRender = true
        render.RenderView({
            origin     = rvOrigin,
            angles     = rvAngles,
            fov        = rvFov,
            x          = 0,
            y          = 0,
            w          = ScrW(),
            h          = ScrH(),
            drawviewer = false,
            drawhud    = false,
        })
        _inCCRender = false

        -- Restaure tout
        if IsValid(csm)   then csm:SetNoDraw(true)   end
        if IsValid(headC) then headC:SetNoDraw(true)  end
        if IsValid(accC)  then accC:SetNoDraw(true)   end
        for _, p in ipairs(allPlys) do
            if IsValid(p) and not plyNoDrawBefore[p] then p:SetNoDraw(false) end
        end

        return true  -- supprime le rendu de scène standard
    end, 9999)

    -- Filet de sécurité : PrePlayerDraw bloque explicitement le rendu de TOUS les
    -- joueurs (y compris LocalPlayer dont SetNoDraw est parfois ignoré par GMod
    -- à l'intérieur d'un render.RenderView). Très peu coûteux : juste un check bool.
    hook.Add("PrePlayerDraw", "VERSE::CharCreate::HidePlayers", function()
        if not _ccActive then
            hook.Remove("PrePlayerDraw", "VERSE::CharCreate::HidePlayers")
            return
        end
        return true
    end)

    -- Masque les bras viewmodel (c_arms) du PM de base pendant la création.
    hook.Add("PreDrawViewModel", "VERSE::CharCreate::HideViewModel", function()
        if not _ccActive then
            hook.Remove("PreDrawViewModel", "VERSE::CharCreate::HideViewModel")
            return
        end
        return true
    end)

    -- Tatouages (body marks) — dessinés pendant render.RenderView via PostDrawOpaqueRenderables.
    -- Les markEnts sont des tables Lua __isWorldLayer (pas des entités GMod), donc on ne peut
    -- pas les rendre via SetNoDraw. drawBodyMarkLayerSet() les traite en appelant headCSM:DrawModel()
    -- avec des submaterials temporaires, ce qui fonctionne dans n'importe quel contexte 3D.
    hook.Add("PostDrawOpaqueRenderables", "VERSE::CharCreate::DrawBodyMarks", function()
        if not _inCCRender then return end
        local mEnts = preview and preview.markEnts
        if not istable(mEnts) then return end
        local hCSM  = preview and preview.headCSM
        if not IsValid(hCSM) then return end
        -- Réinitialise le dédoublonnage de frame : le hook peut être appelé
        -- plusieurs fois par frame si render.RenderView est invoqué plusieurs fois.
        mEnts.__lastDrawFrame = nil
        drawBodyMarkLayerSet(mEnts)
    end)

    -- Masque le HUD et les notifications pendant la création de personnage
    hook.Add("HUDShouldDraw", "VERSE::CharCreate::HideHUD", function(name)
        if not _ccActive or not IsValid(characterCreateFrame) then
            hook.Remove("HUDShouldDraw", "VERSE::CharCreate::HideHUD")
            return
        end
        return false
    end)

    characterCreateFrame.Paint = function(s, w, h)
        -- Voile sombre sur le monde 3D pour lisibilité
        surface.SetDrawColor(5, 4, 12, 150)
        surface.DrawRect(0, 0, w, h)
        -- Le rendu 3D du personnage est dans viewPanel.Paint (défini après 'preview')
    end
    local minH = self:ConfigInt("HeightMin", 140, 50, 400)
    local maxH = self:ConfigInt("HeightMax", 200, minH, 400)
    local defH = self:ConfigInt("DefaultHeight", 165, minH, maxH)
    local currentPreviewHeight = defH
    local factionCombo = nil
    local lockedFaction = preselectedFaction and preselectedFaction or nil
    local lockedFactionCfg = lockedFaction and (cfg.Factions or {})[lockedFaction] or nil
    local appearanceState = {
        bodyType = 1,
        headType = 1,
        skinTone = 1,
        skinColor = Color(DEFAULT_SKIN_TONES[1].r, DEFAULT_SKIN_TONES[1].g, DEFAULT_SKIN_TONES[1].b, DEFAULT_SKIN_TONES[1].a),
        bodyStyle = 0,
        headStyle = 0,
        eyebrowStyle = 1,
        irisStyle = 1,
        irisSize = CH.NormalizeIrisSize and CH:NormalizeIrisSize(CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100) or 100,
        hairStyle = 0,
        spiritAccessory = 0,
        spiritAccessoryData = {
            x = BODY_MARK_DEFAULT_X,
            y = BODY_MARK_DEFAULT_Y,
            z = 0,
            size = BODY_MARK_DEFAULT_SIZE,
        },
        bodyMarks = {},
        hairColor = Color(DEFAULT_HAIR_COLOR.r, DEFAULT_HAIR_COLOR.g, DEFAULT_HAIR_COLOR.b, DEFAULT_HAIR_COLOR.a),
        hairGradientEnabled = false,
        hairTipColor = Color(170, 60, 220, 255),
        eyebrowColor = Color(DEFAULT_HAIR_COLOR.r, DEFAULT_HAIR_COLOR.g, DEFAULT_HAIR_COLOR.b, DEFAULT_HAIR_COLOR.a),
        eyebrowColorLinked = true,
        eyelashColor = Color(0, 0, 0, 255),
        eyeColor = Color(DEFAULT_EYE_COLOR.r, DEFAULT_EYE_COLOR.g, DEFAULT_EYE_COLOR.b, DEFAULT_EYE_COLOR.a),
        flex = {},
        bodyMarksEnabled = {},
        bodyMarksStretch = {},
    }

    local bodyTypeSlider, bodyStyleSlider, headStyleSlider, headTypeSlider, eyebrowStyleSlider, irisStyleSlider, irisSizeSlider, skinToneSlider = nil, nil, nil, nil, nil, nil, nil, nil
    local spiritAccessorySlider = nil
    local spiritAccessoryXSlider = nil
    local spiritAccessoryYSlider = nil
    local spiritAccessoryZSlider = nil
    local spiritAccessorySizeSlider = nil
    local bodyMarkSliders = {}
    local bodyMarksSectionTitle = nil
    local spiritAccessorySectionTitle = nil
    local hairStylePicker = nil
    local irisStylePicker = nil
    local irisPreviewMaterials = {}
    local skinTonePicker = nil
    local hairColorPicker = nil
    local hairGradientToggle = nil
    local hairTipColorPicker = nil
    local eyebrowColorPicker = nil
    local eyebrowColorLinkToggle = nil
    local eyelashColorPicker = nil
    local eyeColorPicker = nil
    local currentBodyModel = nil
    local currentHeadModel = nil
    function cloneColor(colorValue, fallback)
        if IsColor(colorValue) then return Color(colorValue.r, colorValue.g, colorValue.b, colorValue.a or 255) end
        local fb = fallback or color_white
        return Color(fb.r, fb.g, fb.b, fb.a or 255)
    end

    function getCharacterLabel(name, fallback)
        local key = "character." .. tostring(name or "")
        local translated = Language(key)
        if not isstring(translated) or translated == key then return fallback end
        return translated
    end

    function buildSkinPalette()
        local configured = self:ConfigTable("SkinColorPalette", nil)
        if not istable(configured) or #configured == 0 then return DEFAULT_SKIN_TONES end
        local out = {}
        for _, colorValue in ipairs(configured) do
            if IsColor(colorValue) then
                out[#out + 1] = Color(colorValue.r, colorValue.g, colorValue.b, colorValue.a or 255)
            elseif istable(colorValue) and colorValue.r and colorValue.g and colorValue.b then
                out[#out + 1] = Color(tonumber(colorValue.r) or 255, tonumber(colorValue.g) or 255, tonumber(colorValue.b) or 255, tonumber(colorValue.a) or 255)
            end
        end

        if #out == 0 then return DEFAULT_SKIN_TONES end
        return out
    end

    local getActiveFactionId = nil
    local skinPalette = buildSkinPalette()
    function getNearestSkinToneIndex(colorValue)
        local sample = cloneColor(colorValue, DEFAULT_SKIN_TONES[1])
        local bestIndex = 1
        local bestDist = math.huge
        for idx, paletteColor in ipairs(skinPalette) do
            local dr = sample.r - paletteColor.r
            local dg = sample.g - paletteColor.g
            local db = sample.b - paletteColor.b
            local dist = dr * dr + dg * dg + db * db
            if dist < bestDist then
                bestDist = dist
                bestIndex = idx
            end
        end
        return bestIndex
    end

    function factionUsesSkinTonePicker()
        return tostring(getActiveFactionId() or "") == "spirit"
    end

    function pickIdleSeq()
        local idlePool = self.GetIdlePool and self:GetIdlePool() or nil
        if not istable(idlePool) or #idlePool == 0 then return nil end
        local total = 0
        for _, e in ipairs(idlePool) do
            total = total + (e.Weight or 1)
        end

        local r = math.random() * total
        local acc = 0
        for _, e in ipairs(idlePool) do
            acc = acc + (e.Weight or 1)
            if r <= acc then return e.Sequence end
        end
        return idlePool[1].Sequence
    end

    getActiveFactionId = function()
        if lockedFaction then return lockedFaction end
        if IsValid(factionCombo) and factionCombo.GetSelectedData then return factionCombo:GetSelectedData() end
        return nil
    end

    function getActiveFactionCfg()
        local factionId = getActiveFactionId()
        if not isstring(factionId) or factionId == "" then return nil end
        local factions = cfg.Factions or {}
        local data = factions[factionId]
        if not istable(data) then return nil end
        return data
    end

    function getActiveBodyMarkCategories()
        if not self.GetBodyMarkCategories then return {} end
        return self:GetBodyMarkCategories(getActiveFactionId())
    end

    function getActiveSpiritAccessoryOptions()
        if not self.GetSpiritAccessoryOptions then return {} end
        return self:GetSpiritAccessoryOptions(getActiveFactionId())
    end

    function hasBodyMarkMaterial(category, categoryState)
        if not istable(category) then return false end
        local options = istable(category.options) and category.options or {}
        if #options <= 0 then return false end
        local defaultStyle = category.default or 1
        local style = math.Clamp(math.floor(tonumber(categoryState and categoryState.style) or defaultStyle), 1, math.max(1, #options))
        local option = options[style]
        return istable(option) and string.Trim(tostring(option.material or "")) ~= ""
    end

    -- ─── Position du personnage dans le monde 3D (position fixe donnée manuellement) ─
    _worldCharPos = Vector(10320.0, 4933.0, 11508.906250)  -- assigne le slot forward-déclaré

    local camFov = CHAR_CAM_FOV
    local baseCamFov = CHAR_CAM_FOV
    local mdlPos = _worldCharPos                          -- position monde réelle
    local baseMdlAng = Angle(0, _CC_ANG.y + 180, 0)      -- fait face à la caméra
    local mdlAng = Angle(baseMdlAng.p, baseMdlAng.y, baseMdlAng.r)
    local previewYawOffset = 0
    local camZNear = 4
    local baseCamPos, baseCamAng = computeCamFromModel(mdlPos, baseMdlAng, 86, 52)
    local camPos, camAng = baseCamPos, baseCamAng
    local camTargetPos, camTargetAng = baseCamPos, baseCamAng
    local camTargetFov = CHAR_CAM_FOV
    local camTargetZNear = camZNear
    local previewCameraMode = "body"
    local CAMERA_LERP_RATE = 10
    function snapPreviewCameraToTarget()
        camPos = camTargetPos
        camAng = camTargetAng
        camFov = camTargetFov
        camZNear = camTargetZNear
    end

    function rebuildPreviewModelAngle()
        mdlAng = Angle(baseMdlAng.p, baseMdlAng.y + previewYawOffset, baseMdlAng.r)
    end

    function updatePreviewCamera()
        local factionCfg = getActiveFactionCfg()
        baseCamFov = (factionCfg and factionCfg.cam_fov) or CHAR_CAM_FOV
        mdlPos = (factionCfg and factionCfg.mdl_pos) or CHAR_MDL_POS
        baseMdlAng = (factionCfg and factionCfg.mdl_ang) or CHAR_MDL_ANG
        rebuildPreviewModelAngle()
        if factionCfg and factionCfg.cam_pos then
            baseCamPos = factionCfg.cam_pos
            baseCamAng = factionCfg.cam_ang or CHAR_CAM_ANG
            camFov = baseCamFov
            camPos = baseCamPos
            camAng = baseCamAng
            camTargetPos = baseCamPos
            camTargetAng = baseCamAng
            camTargetFov = baseCamFov
            camTargetZNear = 4
            return
        end

        local dist = (factionCfg and factionCfg.cam_dist) or 86
        local height = (factionCfg and factionCfg.cam_height) or 52
        baseCamPos, baseCamAng = computeCamFromModel(mdlPos, baseMdlAng, dist, height)
        camFov = baseCamFov
        camPos = baseCamPos
        camAng = baseCamAng
        camTargetPos = baseCamPos
        camTargetAng = baseCamAng
        camTargetFov = baseCamFov
        camTargetZNear = 4
    end

    preview = {  -- assigne le slot forward-déclaré (pas de 'local' ici)
        csm = nil,
        headCSM = nil,
        accessoryCSM = nil,
        accessoryModel = nil,
        bodyMarks = nil,
        markEnts = nil,
        skinColor = nil,
        hairColor = nil,
        hairTipColor = nil,
        eyebrowColor = nil,
        irisStyle = nil,
        irisSize = nil,
        eyeColor = nil,
    }

    function syncPreviewModelTransform()
        -- Utilise la position réelle du joueur téléporté (sol exact, pas de flottement)
        local ply = LocalPlayer()
        mdlPos    = (IsValid(ply) and ply:GetPos()) or _worldCharPos
        baseMdlAng = Angle(0, _CC_ANG.y + 180, 0)
        rebuildPreviewModelAngle()
        if not IsValid(preview.csm) then return end
        preview.csm:SetPos(mdlPos)
        preview.csm:SetAngles(mdlAng)
        preview.csm:InvalidateBoneCache()
        preview.csm:SetupBones()
        if IsValid(preview.headCSM) then
            preview.headCSM:InvalidateBoneCache()
            preview.headCSM:SetupBones()
        end

        if IsValid(preview.accessoryCSM) then
            preview.accessoryCSM:InvalidateBoneCache()
            preview.accessoryCSM:SetupBones()
        end
    end

    local viewPanel = nil
    local refreshPreviewCameraView = function() end
    function setPreviewYawOffset(value)
        previewYawOffset = math.Clamp(tonumber(value) or 0, -160, 160)
        rebuildPreviewModelAngle()
        syncPreviewModelTransform()
        refreshPreviewCameraView()
    end

    local PREVIEW_HEAD_BONE_CANDIDATES = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Head", "head", "Head", "mixamorig:Head", "bip_head"}
    function getHeadFocusPositionForEnt(ent)
        if not IsValid(ent) then return nil end
        for _, boneName in ipairs(PREVIEW_HEAD_BONE_CANDIDATES) do
            local boneId = ent:LookupBone(boneName)
            if boneId then
                local matrix = ent:GetBoneMatrix(boneId)
                if matrix then
                    local pos = matrix:GetTranslation()
                    if isvector(pos) then return pos end
                end

                local pos = select(1, ent:GetBonePosition(boneId))
                if isvector(pos) then return pos end
            end
        end

        local mins, maxs = ent:GetRenderBounds()
        return ent:GetPos() + ((mins + maxs) * 0.5) + Vector(0, 0, math.max(6, (maxs.z - mins.z) * 0.3))
    end

    function getPreviewHeadFocusPosition()
        if not IsValid(preview.csm) then return nil end
        return getHeadFocusPositionForEnt(preview.csm)
    end

    refreshPreviewCameraView = function(snapToTarget)
        camTargetFov = baseCamFov
        camTargetPos = baseCamPos
        camTargetAng = baseCamAng
        camTargetZNear = 4
        if previewCameraMode ~= "body" then
            local focusPos = getPreviewHeadFocusPosition()
            if isvector(focusPos) then
                local viewBasis = Angle(0, baseMdlAng.y, 0)
                local fwd = viewBasis:Forward()
                local up = viewBasis:Up()
                local isHeadFocus = previewCameraMode == "head"
                local targetLift = isHeadFocus and 1.1 or 1.35
                local targetForward = isHeadFocus and 2.5 or 3.25
                local camDrop = isHeadFocus and 0.1 or 0.2
                local dist = isHeadFocus and 56 or 50
                local focusFov = isHeadFocus and 28 or 24
                local target = focusPos + (up * targetLift) + (fwd * targetForward)
                local nextCamPos = target + (fwd * dist) - (up * camDrop)
                camTargetPos = nextCamPos
                camTargetAng = (target - nextCamPos):Angle()
                camTargetFov = math.min(baseCamFov, focusFov)
                camTargetZNear = isHeadFocus and 2.5 or 2
            end
        end

        if snapToTarget == true then snapPreviewCameraToTarget() end
        if IsValid(viewPanel) then
            viewPanel:SetFOV(camFov)
            viewPanel:SetCamPos(camPos)
            viewPanel:SetLookAt(camPos + (camAng:Forward() * 256))
        end
    end

    function setPreviewCameraFocus(mode)
        if mode == "face" or mode == "head" then
            -- Reset du zoom uniquement si on CHANGE de mode (pas de reset si même mode répété
            -- par les sliders, pour que le zoom utilisateur soit préservé).
            if _ccCamMode ~= mode then
                _ccFaceZoom = (mode == "face") and 60 or 85
            end
            previewCameraMode = mode
            _ccCamMode = mode          -- active le zoom visage dans RenderScene
        else
            previewCameraMode = "body"
            -- Ne remet en vue corps que si on est à la step 1,
            -- sinon la step courante garde son zoom visage (évite le dezoom brutal).
            -- Guard : currentStep peut être nil si le slider appelle cette fonction
            -- pendant son initialisation, avant que setCurrentStep ait été appelé.
            if (currentStep or 0) <= 1 then
                _ccCamMode = "body"
            end
        end

        refreshPreviewCameraView(false)
    end

    function isSkinMaterial(matName)
        return isSkinMaterialNameBase(matName)
    end

    function setEntityTint(ent, color, matcher)
        if not IsValid(ent) or not IsColor(color) then return end
        local vec = Vector(color.r / 255, color.g / 255, color.b / 255)
        for idx, matName in ipairs(ent:GetMaterials() or {}) do
            local slotIndex = idx - 1
            if not matcher or (matcher(matName) and not (matcher == isSkinMaterial and shouldSkipFaceSkinTintSlot(ent, slotIndex))) then
                local mat = Material(matName)
                if mat and not mat:IsError() then mat:SetVector("$color2", vec) end
            end
        end
    end

    function setEntitySkinTint(ent, color)
        setEntityTint(ent, color, isSkinMaterial)
    end

    function setEntityEyeTint(ent, color)
        if IsValid(ent) and CH.SetEntityEyeColor then
            CH.SetEntityEyeColor(ent, color)
            return
        end

        setEntityTint(ent, color, isEyeMaterialName)
    end

    function clearPreviewTint()
        setEntitySkinTint(preview.csm, color_white)
        if IsValid(preview.headCSM) and isFaceControlModel(preview.headCSM:GetModel()) then
            clearFaceHeadSkinTint(preview.headCSM)
        else
            setEntitySkinTint(preview.headCSM, color_white)
        end

        setEyebrowMaterialTint(appearanceState.eyebrowStyle, color_white)
        setEyeMaterialTint(preview.irisStyle or appearanceState.irisStyle or 1, color_white)
        setEyeMaterialSize(preview.headCSM, preview.irisStyle or appearanceState.irisStyle or 1, CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100)
        setEntityEyeTint(preview.headCSM, color_white)
    end

    function applyPreviewTint()
        if IsColor(preview.skinColor) then
            setEntitySkinTint(preview.csm, preview.skinColor)
            if IsValid(preview.headCSM) and isFaceControlModel(preview.headCSM:GetModel()) then
                setFaceHeadSkinTint(preview.headCSM, preview.skinColor)
            else
                setEntitySkinTint(preview.headCSM, preview.skinColor)
            end
        end

        if appearanceState.hairGradientEnabled and IsColor(preview.hairColor) and IsColor(preview.hairTipColor) and CH.SetEntityHairGradient then
            -- Dégradé : racines = preview.hairColor (haut), pointes = preview.hairTipColor (bas).
            -- SetEntityHairGradient(ent, c1=bas/pointes, c2=haut/racines).
            CH.SetEntityHairGradient(preview.headCSM, preview.hairTipColor, preview.hairColor)
        elseif IsColor(preview.hairColor) and CH.SetEntityHairColor then
            CH.SetEntityHairColor(preview.headCSM, preview.hairColor)
        end
        if IsColor(preview.eyebrowColor) then setEyebrowMaterialTint(appearanceState.eyebrowStyle, preview.eyebrowColor) end
        if IsColor(preview.eyeColor) then
            if IsValid(preview.headCSM) and isFaceControlModel(preview.headCSM:GetModel()) then
                applyEntityEyeMaterial(preview.headCSM, preview.irisStyle or appearanceState.irisStyle or 1)
                setEyeMaterialTint(preview.irisStyle or appearanceState.irisStyle or 1, color_white)
                setEyeMaterialSize(preview.headCSM, preview.irisStyle or appearanceState.irisStyle or 1, preview.irisSize or appearanceState.irisSize or (CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100))
            else
                setEntityEyeTint(preview.headCSM, preview.eyeColor)
            end
        end
    end

    function syncPreviewAppearanceTint()
        if IsValid(preview.headCSM) then
            applyEntityEyebrowMaterial(preview.headCSM, appearanceState.eyebrowStyle)
            applyEntityEyeMaterial(preview.headCSM, preview.irisStyle or appearanceState.irisStyle or 1)
        end

        applyPreviewTint()
    end

    function getBodygroupMax(ent, groupId)
        if not IsValid(ent) then return 0 end
        groupId = tonumber(groupId) or 0
        if not ent.GetNumBodyGroups or ent:GetNumBodyGroups() <= groupId then return 0 end
        if not ent.GetBodygroupCount then return 0 end
        local count = tonumber(ent:GetBodygroupCount(groupId)) or 0
        return math.max(0, count - 1)
    end

    function getBodygroupSliderBounds(ent, groupId)
        local minValue = 0
        local maxValue = getBodygroupMax(ent, groupId)
        if IsValid(ent) and CH.GetAllowedBodygroupValues then
            local allowed = CH:GetAllowedBodygroupValues(ent:GetModel(), groupId, maxValue)
            if istable(allowed) and #allowed > 0 then
                minValue = tonumber(allowed[1]) or minValue
                maxValue = tonumber(allowed[#allowed]) or maxValue
            end
        end
        return minValue, maxValue
    end

    function normalizeBodygroupForEnt(ent, groupId, value)
        local maxValue = getBodygroupMax(ent, groupId)
        local safeValue = math.Clamp(math.floor(tonumber(value) or 0), 0, maxValue)
        if IsValid(ent) and CH.NormalizeBodygroupValue then return CH:NormalizeBodygroupValue(ent:GetModel(), groupId, safeValue, maxValue) end
        return safeValue
    end

    function applyPreviewBodygroups()
        local bodyMax = getBodygroupMax(preview.csm, 0)
        local headMax = getBodygroupMax(preview.headCSM, 0)
        local hairMax = getBodygroupMax(preview.headCSM, 1)
        appearanceState.bodyStyle = math.Clamp(tonumber(appearanceState.bodyStyle) or 0, 0, bodyMax)
        appearanceState.headStyle = normalizeBodygroupForEnt(preview.headCSM, 0, appearanceState.headStyle)
        appearanceState.hairStyle = math.Clamp(tonumber(appearanceState.hairStyle) or 0, 0, math.max(0, hairMax))
        if IsValid(preview.csm) and bodyMax >= 0 then preview.csm:SetBodygroup(0, appearanceState.bodyStyle) end
        if IsValid(preview.headCSM) and headMax >= 0 then preview.headCSM:SetBodygroup(0, appearanceState.headStyle) end
        if IsValid(preview.headCSM) and hairMax >= 0 then preview.headCSM:SetBodygroup(1, appearanceState.hairStyle) end
        preview.markEnts = syncBodyMarkLayerSet(preview.headCSM, preview.markEnts, preview.bodyMarks, "charcreate")
    end


    function applyPreviewBodyMarks()
        if self.NormalizeBodyMarksData then
            appearanceState.bodyMarks = self:NormalizeBodyMarksData(getActiveFactionId(), appearanceState.bodyMarks)
        else
            appearanceState.bodyMarks = {}
        end

        preview.bodyMarks = (self.GetResolvedBodyMarks and self:GetResolvedBodyMarks(getActiveFactionId(), appearanceState.bodyMarks)) or {}
        preview.markEnts = syncBodyMarkLayerSet(preview.headCSM, preview.markEnts, preview.bodyMarks, "charcreate")

        -- Réapplique les couleurs cheveux/sourcils/cils après la sync des marques.
        -- syncBodyMarkLayerSet réinitialise les sous-matériaux du headCSM ; sans cette
        -- restauration, appliquer un tatouage ou une cicatrice faisait passer les
        -- cheveux, sourcils et cils en BLANC.
        if IsValid(preview.headCSM) then
            applyPreviewHairColor()
            applyPreviewEyebrowColor()
            applyPreviewEyebrowColor_v2(appearanceState.eyebrowColorLinked and appearanceState.hairColor or appearanceState.eyebrowColor)
            applyPreviewEyelashColor(appearanceState.eyelashColor)
        end
    end

    function normalizeSpiritAccessoryTransformState()
        if self.NormalizeSpiritAccessoryTransform then
            appearanceState.spiritAccessoryData = self:NormalizeSpiritAccessoryTransform(getActiveFactionId(), appearanceState.spiritAccessory, appearanceState.spiritAccessoryData)
            return
        end

        local entry = istable(appearanceState.spiritAccessoryData) and appearanceState.spiritAccessoryData or {}
        appearanceState.spiritAccessoryData = {
            x = math.Clamp(math.floor(tonumber(entry.x) or BODY_MARK_DEFAULT_X), BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX),
            y = math.Clamp(math.floor(tonumber(entry.y) or BODY_MARK_DEFAULT_Y), BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX),
            z = math.Clamp(math.floor(tonumber(entry.z) or 0), BODY_MARK_DEPTH_MIN, BODY_MARK_DEPTH_MAX),
            size = math.Clamp(math.floor(tonumber(entry.size) or BODY_MARK_DEFAULT_SIZE), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX),
        }
    end

    function applyPreviewSpiritAccessory()
        if self.NormalizeSpiritAccessory then
            appearanceState.spiritAccessory = self:NormalizeSpiritAccessory(getActiveFactionId(), appearanceState.spiritAccessory)
        else
            appearanceState.spiritAccessory = math.max(0, math.floor(tonumber(appearanceState.spiritAccessory) or 0))
        end

        normalizeSpiritAccessoryTransformState()
        local accessoryModel = ""
        if self.ResolveSpiritAccessoryModel then accessoryModel = tostring(self:ResolveSpiritAccessoryModel(getActiveFactionId(), appearanceState.spiritAccessory) or "") end
        if accessoryModel == "" or not IsValid(preview.headCSM) then
            if IsValid(preview.accessoryCSM) then preview.accessoryCSM:Remove() end
            preview.accessoryCSM = nil
            preview.accessoryModel = ""
            return
        end

        preview.accessoryCSM = spawnMergedPart(preview.headCSM, accessoryModel, preview.accessoryCSM, {
            boneMerge = false
        })

        preview.accessoryModel = accessoryModel
        if IsValid(preview.accessoryCSM) then
            local scale = self.GetHeightScale and self:GetHeightScale(currentPreviewHeight) or 1
            if self.ApplySpiritAccessoryClientTransform then
                self:ApplySpiritAccessoryClientTransform(preview.accessoryCSM, scale, appearanceState.spiritAccessoryData)
            else
                preview.accessoryCSM:SetModelScale(scale, 0)
            end
        end
    end

    function applyPreviewSkinTone()
        local maxIndex = math.max(1, #skinPalette)
        appearanceState.skinTone = math.Clamp(tonumber(appearanceState.skinTone) or 1, 1, maxIndex)
        local color
        if factionUsesSkinTonePicker() then
            color = cloneColor(appearanceState.skinColor, skinPalette[appearanceState.skinTone] or DEFAULT_SKIN_TONES[1])
        else
            color = skinPalette[appearanceState.skinTone] or DEFAULT_SKIN_TONES[1]
            appearanceState.skinColor = cloneColor(color, DEFAULT_SKIN_TONES[1])
        end

        preview.skinColor = cloneColor(color, DEFAULT_SKIN_TONES[1])
        syncPreviewAppearanceTint()
    end

    function applyPreviewHairColor()
        appearanceState.hairColor = cloneColor(appearanceState.hairColor, DEFAULT_HAIR_COLOR)
        appearanceState.hairTipColor = cloneColor(appearanceState.hairTipColor, appearanceState.hairColor)
        preview.hairColor = cloneColor(appearanceState.hairColor, DEFAULT_HAIR_COLOR)
        preview.hairTipColor = cloneColor(appearanceState.hairTipColor, appearanceState.hairColor)
        syncPreviewAppearanceTint()
    end

    function headUsesFaceMaterialControls()
        return IsValid(preview.headCSM) and isFaceControlModel(preview.headCSM:GetModel())
    end

    function applyPreviewEyeStyle()
        appearanceState.irisStyle = math.Clamp(math.floor(tonumber(appearanceState.irisStyle) or 1), 1, getEyeStyleCount())
        preview.irisStyle = appearanceState.irisStyle
        applyEntityEyeMaterial(preview.headCSM, appearanceState.irisStyle)
        syncPreviewAppearanceTint()
    end

    function applyPreviewEyeSize()
        if CH.NormalizeIrisSize then
            appearanceState.irisSize = CH:NormalizeIrisSize(appearanceState.irisSize)
        else
            appearanceState.irisSize = math.Clamp(math.floor(tonumber(appearanceState.irisSize) or 100), 60, 140)
        end

        preview.irisSize = appearanceState.irisSize
        setEyeMaterialSize(preview.headCSM, preview.irisStyle or appearanceState.irisStyle or 1, appearanceState.irisSize)
        syncPreviewAppearanceTint()
    end

    function applyPreviewEyeColor()
        appearanceState.eyeColor = cloneColor(appearanceState.eyeColor, DEFAULT_EYE_COLOR)
        preview.eyeColor = cloneColor(appearanceState.eyeColor, DEFAULT_EYE_COLOR)
        syncPreviewAppearanceTint()
    end

    function applyPreviewFlex()
        if not IsValid(preview.headCSM) or not CH.ApplyFlex then return end
        appearanceState.flex = CH.NormalizeFlexTable and CH:NormalizeFlexTable(appearanceState.flex) or appearanceState.flex
        CH.ApplyFlex(preview.headCSM, appearanceState.flex)
    end

    function applyPreviewEyebrowColor_v2(color)
        if not IsValid(preview.headCSM) or not CH.SetEntityEyebrowColor then return end
        CH.SetEntityEyebrowColor(preview.headCSM, color or appearanceState.eyebrowColor)
    end

    function applyPreviewEyebrowColor()
        local colorValue
        if appearanceState.eyebrowColorLinked ~= false then
            colorValue = cloneColor(appearanceState.hairColor, DEFAULT_HAIR_COLOR)
        else
            appearanceState.eyebrowColor = cloneColor(appearanceState.eyebrowColor, DEFAULT_HAIR_COLOR)
            colorValue = cloneColor(appearanceState.eyebrowColor, DEFAULT_HAIR_COLOR)
        end

        preview.eyebrowColor = cloneColor(colorValue, DEFAULT_HAIR_COLOR)
        syncPreviewAppearanceTint()
    end

    function applyPreviewEyebrowStyle()
        appearanceState.eyebrowStyle = math.Clamp(math.floor(tonumber(appearanceState.eyebrowStyle) or 1), 1, getEyebrowStyleCount())
        applyEntityEyebrowMaterial(preview.headCSM, appearanceState.eyebrowStyle)
        syncPreviewAppearanceTint()
    end

    function applyPreviewEyelashColor(color)
        if not IsValid(preview.headCSM) or not CH.SetEntityEyelashColor then return end
        CH.SetEntityEyelashColor(preview.headCSM, color or appearanceState.eyelashColor or Color(0, 0, 0, 255))
    end

    function getIrisPreviewMaterial(style)
        style = math.Clamp(math.floor(tonumber(style) or 1), 1, getEyeStyleCount())
        local sourceMat = getActiveEyeMaterial and getActiveEyeMaterial(style) or nil
        if not sourceMat or sourceMat:IsError() then
            local eyePath = getEyeMaterialPath(style)
            if isstring(eyePath) and eyePath ~= "" then sourceMat = Material(eyePath) end
        end

        if not sourceMat or sourceMat:IsError() then return nil end
        local baseTexture = (getMaterialTextureName and getMaterialTextureName(sourceMat, "$basetexture")) or nil
        if not isstring(baseTexture) or baseTexture == "" then
            local eyePath = getEyeMaterialPath(style)
            baseTexture = isstring(eyePath) and eyePath or ""
        end

        baseTexture = string.Trim(tostring(baseTexture or ""))
        if baseTexture == "" then return nil end
        local cacheKey = string.lower(baseTexture)
        local cached = irisPreviewMaterials[cacheKey]
        if cached and not cached:IsError() then return cached end
        local matName = "verse__char__iris_preview_" .. string.gsub(cacheKey, "[^%w_]", "_")
        local previewMat = Material(matName)
        if not (previewMat and not previewMat:IsError()) then
            previewMat = CreateMaterial(matName, "UnlitGeneric", {
                ["$basetexture"] = baseTexture,
                ["$translucent"] = "1",
                ["$vertexalpha"] = "1",
                ["$vertexcolor"] = "1",
            })
        end

        if previewMat and not previewMat:IsError() then
            irisPreviewMaterials[cacheKey] = previewMat
            return previewMat
        end
        return nil
    end

    function setSliderValueSafe(slider, minValue, maxValue, value)
        if not IsValid(slider) then return end
        minValue = tonumber(minValue) or 0
        maxValue = tonumber(maxValue) or minValue
        if maxValue < minValue then maxValue = minValue end
        slider:SetRange(minValue, maxValue, 0)
        slider:SetValue(math.Clamp(tonumber(value) or minValue, minValue, maxValue), true)
    end

    function setAppearanceRowVisible(row, visible, baseTall, baseBottom)
        if not IsValid(row) then return end
        if visible then
            row:SetVisible(true)
            row:SetTall(baseTall or row._baseTall or row:GetTall())
            row:DockMargin(0, 0, 0, baseBottom or row._baseBottom or 0)
        else
            row:SetVisible(false)
            row:SetTall(0)
            row:DockMargin(0, 0, 0, 0)
        end

        local parent = row:GetParent()
        if IsValid(parent) then parent:InvalidateLayout(true) end
    end

    function isAppearanceControlVisible(control)
        if not IsValid(control) then return false end
        local row = control._ownerRow
        return IsValid(row) and row:IsVisible() and row:GetTall() > 0
    end

    function setAppearanceControlVisible(control, visible)
        if not IsValid(control) then return end
        local row = control._ownerRow
        setAppearanceRowVisible(row, visible, control._baseTall, control._baseBottom)
    end

    function setSectionTitleVisible(sectionTitle, visible)
        setAppearanceRowVisible(sectionTitle, visible)
    end

    function setAppearanceSliderState(slider, minValue, maxValue, value)
        if not IsValid(slider) then return end
        local minN = tonumber(minValue) or 0
        local maxN = tonumber(maxValue) or minN
        local visible = maxN > minN
        setAppearanceControlVisible(slider, visible)
        if visible then setSliderValueSafe(slider, minN, maxN, value) end
    end

    local refreshHairStylePreviewGrid = function() end
    local refreshIrisStylePreviewGrid = function() end
    local refreshAppearanceControls = function() end
    function applyPreviewScale(height)
        local scale = self.GetHeightScale and self:GetHeightScale(height) or 1
        if IsValid(preview.csm) then preview.csm:SetModelScale(scale, 0) end
        if IsValid(preview.headCSM) then preview.headCSM:SetModelScale(scale, 0) end
        if IsValid(preview.accessoryCSM) then
            if self.ApplySpiritAccessoryClientTransform then
                self:ApplySpiritAccessoryClientTransform(preview.accessoryCSM, scale, appearanceState.spiritAccessoryData)
            else
                preview.accessoryCSM:SetModelScale(scale, 0)
            end
        end

        preview.markEnts = syncBodyMarkLayerSet(preview.headCSM, preview.markEnts, preview.bodyMarks, "charcreate")
    end

    function spawnMergedPart(parent, mdl, reuseEnt, options)
        if not IsValid(parent) then return nil end
        if not isstring(mdl) or mdl == "" then return nil end
        options = istable(options) and options or {}
        local useBoneMerge = options.boneMerge ~= false
        local ent = reuseEnt
        if IsValid(ent) then
            ent:SetModel(mdl)
        else
            ent = ClientsideModel(mdl)
        end

        if not IsValid(ent) then return nil end
        ent:SetPos(parent:GetPos())
        ent:SetAngles(parent:GetAngles())
        ent:SetNoDraw(true)
        ent:SetParent(parent)
        ent:RemoveEffects(EF_BONEMERGE)
        ent:RemoveEffects(EF_BONEMERGE_FASTCULL)
        ent:RemoveEffects(EF_PARENT_ANIMATES)
        if useBoneMerge then
            ent:AddEffects(EF_BONEMERGE)
            ent:AddEffects(EF_BONEMERGE_FASTCULL)
            ent:AddEffects(EF_PARENT_ANIMATES)
        end

        ent:SetLocalPos(Vector(0, 0, 0))
        ent:SetLocalAngles(Angle(0, 0, 0))
        ent:InvalidateBoneCache()
        ent:SetupBones()
        return ent
    end

    function pickPreviewEntry(entry, preferredIndex)
        if not entry then return nil end
        if isstring(entry) and entry ~= "" then return entry, 1, 1 end
        if istable(entry) and #entry > 0 then
            local count = #entry
            local index = math.Clamp(math.floor(tonumber(preferredIndex) or 1), 1, count)
            return entry[index], index, count
        end
        return nil, nil, 0
    end

    function getPreviewChoiceCount(kind, gender)
        local factionCfg = getActiveFactionCfg()
        if not factionCfg or not self.GetFactionGenderData then return 1 end
        local gdata = self:GetFactionGenderData(factionCfg, gender)
        if not gdata then return 1 end
        local entry = gdata[kind]
        if isstring(entry) and entry ~= "" then return 1 end
        if istable(entry) and #entry > 0 then return #entry end
        return 1
    end

    local cleanedUp = false
    function cleanupPreview()
        if cleanedUp then return end
        cleanedUp = true
        -- Remet le joueur à sa position d'origine et le dégèle
        net.Start("verse_cc_exit")
        net.SendToServer()
        VERSE.Hook.RemoveNS("Character", "Think", "VERSE::Think::CharCreate")
        _ccActive = false   -- désactive RenderScene / HideHUD / HidePlayers proprement
        VERSE.Hook.RemoveNS("Character", "PreRender", "VERSE::CharCreate::RenderView")
        VERSE.Hook.Remove("RenderScene",        "VERSE::CharCreate::RenderScene")
        hook.Remove("PrePlayerDraw",            "VERSE::CharCreate::HidePlayers")
        hook.Remove("PreDrawViewModel",         "VERSE::CharCreate::HideViewModel")
        hook.Remove("PostDrawOpaqueRenderables", "VERSE::CharCreate::DrawBodyMarks")
        hook.Remove("HUDShouldDraw",            "VERSE::CharCreate::HideHUD")
        clearPreviewTint()
        preview.skinColor = nil
        preview.hairColor = nil
        preview.eyebrowColor = nil
        preview.irisStyle = nil
        preview.eyeColor = nil
        preview.markEnts = clearBodyMarkLayerSet(preview.markEnts)
        if IsValid(preview.accessoryCSM) then preview.accessoryCSM:Remove() end
        if IsValid(preview.headCSM) then preview.headCSM:Remove() end
        if IsValid(preview.csm) and (not IsValid(viewPanel) or preview.csm ~= viewPanel.Entity) then preview.csm:Remove() end
        preview.headCSM = nil
        preview.csm = nil
        preview.accessoryCSM = nil
        preview.accessoryModel = nil
        preview.bodyMarks = nil
        preview.markEnts = nil
    end

    function buildPreviewCSM(gender)
        clearPreviewTint()
        if IsValid(preview.accessoryCSM) then preview.accessoryCSM:Remove() end
        if IsValid(preview.headCSM) then preview.headCSM:Remove() end
        if IsValid(preview.csm) and (not IsValid(viewPanel) or preview.csm ~= viewPanel.Entity) then preview.csm:Remove() end
        preview.markEnts = clearBodyMarkLayerSet(preview.markEnts)
        preview.headCSM = nil
        preview.csm = nil
        preview.accessoryCSM = nil
        preview.accessoryModel = nil
        preview.bodyMarks = nil
        preview.markEnts = nil
        preview.skinColor = nil
        preview.hairColor = nil
        preview.eyebrowColor = nil
        preview.irisStyle = nil
        preview.eyeColor = nil
        currentBodyModel = nil
        currentHeadModel = nil
        updatePreviewCamera()
        local bodyMdl = CHAR_PREVIEW_MDL
        local headMdl = nil
        local factionCfg = getActiveFactionCfg()
        if factionCfg then
            local gdata = self.GetFactionGenderData and self:GetFactionGenderData(factionCfg, gender) or nil
            if gdata then
                local chosenBodyMdl, chosenBodyIndex = pickPreviewEntry(gdata.body, appearanceState.bodyType)
                if chosenBodyMdl then
                    bodyMdl = chosenBodyMdl
                    selectedBodyMdl = chosenBodyMdl
                end

                appearanceState.bodyType = tonumber(chosenBodyIndex) or 1
                local chosenHeadMdl, chosenHeadIndex = pickPreviewEntry(gdata.head, appearanceState.headType)
                headMdl = chosenHeadMdl or nil
                appearanceState.headType = tonumber(chosenHeadIndex) or 1
            end
        end

        currentBodyModel = bodyMdl
        currentHeadModel = headMdl
        if not IsValid(viewPanel) then return end
        viewPanel:SetModel(bodyMdl)
        preview.csm = viewPanel.Entity
        if not IsValid(preview.csm) then return end
        preview.csm:SetNoDraw(true)   -- rendu manuel via cam.Start3D() dans viewPanel.Paint
        if preview.csm.SetIK then preview.csm:SetIK(false) end
        syncPreviewModelTransform()
        local idleSeq = pickIdleSeq()
        if idleSeq then
            local si = preview.csm:LookupSequence(idleSeq)
            if si and si >= 0 then preview.csm:ResetSequence(si) end
        end

        preview.csm:SetCycle(0)
        preview.csm:SetupBones()
        if headMdl then preview.headCSM = spawnMergedPart(preview.csm, headMdl) end
        -- headCSM reste en NoDraw(true), dessiné manuellement dans cam.Start3D()
        if IsValid(preview.headCSM) and CH.HideBuiltInHeadBodygroups then CH.HideBuiltInHeadBodygroups(preview.csm) end
        applyPreviewSpiritAccessory()
        applyPreviewBodygroups()
        applyPreviewSkinTone()
        applyPreviewBodyMarks()
        applyPreviewHairColor()
        applyPreviewEyebrowStyle()
        applyPreviewEyebrowColor()
        applyPreviewEyeStyle()
        applyPreviewEyeSize()
        applyPreviewEyeColor()
        applyPreviewFlex()
        applyPreviewEyebrowColor_v2(appearanceState.eyebrowColorLinked and appearanceState.hairColor or appearanceState.eyebrowColor)
        applyPreviewEyelashColor(appearanceState.eyelashColor)
        applyPreviewScale(currentPreviewHeight)
        refreshPreviewCameraView(true)
        refreshAppearanceControls()
    end

    viewPanel = vgui.Create("DModelPanel", characterCreateFrame)
    viewPanel:SetPos(0, 0)
    viewPanel:SetSize(R:X(CHAR_VIEW_W), R:Y(scrh))
    viewPanel:SetMouseInputEnabled(true)
    if viewPanel.SetPaintBackground then viewPanel:SetPaintBackground(false) end
    viewPanel:SetAnimated(true)
    viewPanel:SetAmbientLight(Color(78, 72, 96))
    viewPanel:SetDirectionalLight(BOX_FRONT, Color(218, 210, 226))
    viewPanel:SetDirectionalLight(BOX_RIGHT, Color(132, 128, 168))
    viewPanel:SetDirectionalLight(BOX_LEFT, Color(88, 76, 124))
    viewPanel:SetDirectionalLight(BOX_TOP, Color(188, 176, 208))
    viewPanel:SetDirectionalLight(BOX_BOTTOM, Color(44, 38, 60))
    viewPanel.LayoutEntity = function(_, ent)
        if not IsValid(ent) then return end
        ent:FrameAdvance(FrameTime())
        syncPreviewModelTransform()
        ent:InvalidateBoneCache()
        ent:SetupBones()
        if IsValid(preview.headCSM) then
            preview.headCSM:InvalidateBoneCache()
            preview.headCSM:SetupBones()
        end

        local lerpFrac = math.Clamp(1 - math.exp(-FrameTime() * CAMERA_LERP_RATE), 0, 1)
        camPos = LerpVector(lerpFrac, camPos, camTargetPos)
        camAng = LerpAngle(lerpFrac, camAng, camTargetAng)
        camFov = Lerp(lerpFrac, camFov, camTargetFov)
        camZNear = Lerp(lerpFrac, camZNear, camTargetZNear)
        viewPanel:SetFOV(camFov)
        viewPanel:SetCamPos(camPos)
        viewPanel:SetLookAt(camPos + (camAng:Forward() * 256))
    end

    -- ─── Override du Paint DModelPanel ────────────────────────────────────────────
    -- Le rendu 3D du personnage est fait dans RenderScene (render.RenderView avec
    -- NoDraw toggle) → le personnage est correctement placé sur le sol du monde.
    -- viewPanel.Paint gère uniquement l'animation et les effets d'apparence.
    viewPanel.Paint = function(self, w, h)
        if not IsValid(self.Entity) then return end

        -- Anime le modèle + maintient position/apparence
        self:LayoutEntity(self.Entity)
        syncPreviewAppearanceTint()
        if IsValid(preview.headCSM) then
            if CH.ApplyFlex and appearanceState.flex then CH.ApplyFlex(preview.headCSM, appearanceState.flex) end
            if CH.SetEntityEyebrowColor then CH.SetEntityEyebrowColor(preview.headCSM, appearanceState.eyebrowColorLinked and appearanceState.hairColor or appearanceState.eyebrowColor) end
            if CH.SetEntityEyelashColor then CH.SetEntityEyelashColor(preview.headCSM, appearanceState.eyelashColor or Color(0, 0, 0, 255)) end
            preview.markEnts = syncBodyMarkLayerSet(preview.headCSM, preview.markEnts, preview.bodyMarks or {}, "charcreate")
        end
        -- Le DrawModel est géré par RenderScene via SetNoDraw(false/true) autour de render.RenderView
    end

    viewPanel.PreDrawModel  = nil
    viewPanel.PostDrawModel = nil

    viewPanel.OnMousePressed = function(s, mcode)
        if mcode ~= MOUSE_LEFT or not IsValid(preview.csm) then return end
        s._dragRotate = true
        s._dragStartX   = select(1, s:CursorPos())
        s._dragStartY   = select(2, s:CursorPos())
        s._dragStartYaw = previewYawOffset
        s._dragStartZoom = _ccFaceZoom
        s:MouseCapture(true)
    end

    viewPanel.OnMouseReleased = function(s, mcode)
        if mcode ~= MOUSE_LEFT or not s._dragRotate then return end
        s._dragRotate = false
        s:MouseCapture(false)
    end

    viewPanel.OnCursorMoved = function(s, x, y)
        if not s._dragRotate then return end
        local dragStartX   = tonumber(s._dragStartX)   or x
        local dragStartY   = tonumber(s._dragStartY)   or y
        local dragStartYaw = tonumber(s._dragStartYaw) or previewYawOffset
        -- Rotation horizontale (gauche/droite) — active dans tous les modes
        setPreviewYawOffset(dragStartYaw + ((x - dragStartX) * 0.35))
        -- Zoom vertical (haut = zoom avant, bas = zoom arrière) — uniquement en mode visage/tête
        if _ccCamMode == "face" or _ccCamMode == "head" then
            local dragStartZoom = tonumber(s._dragStartZoom) or _ccFaceZoom
            _ccFaceZoom = math.Clamp(dragStartZoom + (y - dragStartY) * 0.3, 25, 120)
        end
    end

    local rightPanel = vgui.Create("DPanel", characterCreateFrame)
    rightPanel:SetPos(R:X(CHAR_VIEW_W), 0)
    rightPanel:SetSize(R:X(scrw - CHAR_VIEW_W), R:Y(scrh))
    local cardWidth = 737
    local cardHeight = 970
    local cardLeft = 0
    local totalSteps = 3
    local currentStep = 1
    local activeStepBody = nil
    local stepBodies = {}
    local primaryAction = nil
    local secondaryAction = nil
    local clrField = Color(255, 255, 255, 18)
    local clrFieldHover = Color(255, 255, 255, 24)
    local clrAccent = Color(128, 89, 179)
    local clrAccentHover = Color(148, 106, 204)
    local clrGhost = Color(104, 100, 112, 190)
    local clrGhostHover = Color(124, 120, 136, 220)
    local clrCardOutline = Color(255, 255, 255, 25)
    local clrFooterCancel = Color(132, 93, 191)
    local clrFooterCancelHover = Color(148, 108, 206)
    local clrFooterProceedFill = Color(255, 255, 255, 14)
    local clrFooterProceedFillHover = Color(255, 255, 255, 20)
    local clrFooterProceedOutline = Color(255, 255, 255, 22)
    local clrFooterProceedShine = Color(255, 255, 255, 10)
    local clrHairTileBase = Color(8, 8, 14, 190)
    local clrHairTileHover = Color(255, 255, 255, 8)
    local clrHairTileOutline = Color(255, 255, 255, 10)
    local clrHairTileOutlineActive = Color(clrAccent.r, clrAccent.g, clrAccent.b, 170)
    local clrEntryBase = Color(12, 10, 18, 96)
    local clrEntryFill = Color(255, 255, 255, 14)
    local clrEntryFillHover = Color(255, 255, 255, 18)
    local clrEntryOutline = Color(255, 255, 255, 6)
    local clrEntryOutlineFocus = Color(clrAccent.r, clrAccent.g, clrAccent.b, 84)
    local clrEntryPlaceholder = Color(177, 169, 186, 175)
    local clrSliderTrack = Color(clrAccent.r, clrAccent.g, clrAccent.b, 150)
    local clrSliderFill = Color(clrAccent.r, clrAccent.g, clrAccent.b)
    local clrSliderFillDrag = Color(clrAccentHover.r, clrAccentHover.g, clrAccentHover.b, 125)
    local clrSliderTick = Color(255, 255, 255, 60)
    local clrBodyMarkPadBase = Color(6, 6, 12, 170)
    local clrBodyMarkPadOutline = Color(255, 255, 255, 18)
    local clrBodyMarkPadAxis = Color(255, 255, 255, 62)
    local clrBodyMarkPadCursor = Color(clrAccent.r, clrAccent.g, clrAccent.b, 240)
    local clrBodyMarkPadValue = Color(255, 255, 255, 210)
    local radiusEntry = R:X(15)
    local radiusButton = R:X(9)
    local radiusColorOuter = R:X(8)
    local radiusColorInner = R:X(6)
    local fontHeaderTitle = Font:GetNamed("Poppins", "Bold", 38)
    local fontHeaderSubtitle = Font:GetNamed("Poppins", "Medium", 34)
    local fontSectionTitle = Font:GetNamed("Poppins", "Bold", 36)
    local fontFieldLabel = Font:GetNamed("Poppins", "SemiBold", 22)
    local fontFieldValue = Font:GetNamed("Poppins", "Medium", 21)
    local fontSliderTitle = Font:GetNamed("Poppins", "Bold", 24)
    local fontSliderValue = Font:GetNamed("Poppins", "Bold", 18)
    local fontSliderMinMax = Font:GetNamed("Poppins", "SemiBold", 14)
    local fontButtonText = Font:GetNamed("Poppins", "Bold", 26)
    rightPanel.Paint = function() end
    function getSelectedFactionLabel()
        if lockedFactionCfg and isstring(lockedFactionCfg.name) and lockedFactionCfg.name ~= "" then return tostring(lockedFactionCfg.name) end
        local factionCfg = getActiveFactionCfg()
        if factionCfg and isstring(factionCfg.name) and factionCfg.name ~= "" then return tostring(factionCfg.name) end
        return ""
    end

    function getStepTitle()
        if currentStep == 1 then
            local title = "Nouveau personnage"
            local factionLabel = getSelectedFactionLabel()
            if factionLabel ~= "" then title = title .. " - " .. factionLabel end
            return title
        elseif currentStep == 2 then
            return "Visage"
        end
        return "Corps"
    end

    function getStepSubtitle()
        if currentStep == 1 then return ("Slot %d"):format(slot) end
        return ""
    end

    function usesCompactStepHeader()
        return currentStep > 1
    end

    local card = vgui.Create("DPanel", rightPanel)
    card:SetPos(R:XY(cardLeft, 55))
    card:SetSize(R:XY(cardWidth, cardHeight))
    card.Paint = function(_, w, h)
        Materials:Draw(Color(255, 255, 255, 30), "character_right_panel", 0, 0, w, h)
        RNDX().Rect(0, 0, w, h):Rad(R:X(26)):Color(18, 12, 28, 210):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:X(26)):Color(clrCardOutline):Outline(1):Draw()
    end

    -- ─── Bouton toggle musique (coin haut-gauche du panel) ───────────────────
    local _musicMuted   = false
    local _musicBtnFont = Font:GetNamed("Poppins", "Regular", 18)
    local _musicBtn     = vgui.Create("DButton", card)
    _musicBtn:SetSize(R:XY(36, 36))
    _musicBtn:SetPos(R:X(16), R:Y(16))
    _musicBtn:SetText("")
    _musicBtn:SetCursor("hand")
    _musicBtn.Paint = function(s, w, h)
        local a = s:IsHovered() and 220 or 130
        surface.SetDrawColor(255, 255, 255, math.floor(a * 0.15))
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("♫", _musicBtnFont, w * 0.5, h * 0.5,
            Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if _musicMuted then
            surface.SetDrawColor(255, 80, 80, a)
            surface.DrawLine(4, 4, w - 4, h - 4)
        end
    end
    _musicBtn.DoClick = function()
        _musicMuted = not _musicMuted
        local ch = CH._menuMusicChannel
        if IsValid(ch) then
            if _musicMuted then
                ch:SetVolume(0)
            else
                local vol = tonumber(CH.GetConfig and CH:GetConfig("MenuMusicVolume")) or 0.35
                ch:SetVolume(math.Clamp(vol, 0, 1))
            end
        end
    end

    local header = vgui.Create("DPanel", card)
    header:Dock(TOP)
    header:DockMargin(R:X(100), R:Y(88), R:X(99), 0)
    header:SetTall(R:Y(92))
    header.Paint = function(_, w, h)
        if usesCompactStepHeader() then
            draw.SimpleText(getStepTitle(), fontSectionTitle, 0, 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            return
        end

        local subtitle = getStepSubtitle()
        local titleY = (subtitle ~= "") and R:Y(2) or math.floor(h * 0.5)
        local titleAlignY = (subtitle ~= "") and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER
        draw.SimpleText(getStepTitle(), fontHeaderTitle, w * 0.5, titleY, color_white, TEXT_ALIGN_CENTER, titleAlignY)
        if subtitle ~= "" then draw.SimpleText(subtitle, fontHeaderSubtitle, w * 0.5, h - R:Y(2), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM) end
    end

    local footer = vgui.Create("DPanel", card)
    footer:Dock(BOTTOM)
    footer:DockMargin(R:X(111), 0, R:X(110), R:Y(79))
    footer:SetTall(R:Y(56))
    footer.Paint = nil
    local contentHost = vgui.Create("DPanel", card)
    contentHost:Dock(FILL)
    contentHost:DockMargin(R:X(100), R:Y(24), R:X(99), R:Y(20))
    contentHost.Paint = nil
    contentHost.PerformLayout = function(_, w, h)
        for _, panel in ipairs(stepBodies) do
            if IsValid(panel) then
                panel:SetPos(0, 0)
                panel:SetSize(w, h)
            end
        end
    end

    function updateCardStepLayout()
        if not IsValid(header) or not IsValid(contentHost) then return end
        if usesCompactStepHeader() then
            header:DockMargin(R:X(100), R:Y(70), R:X(99), 0)
            header:SetTall(R:Y(42))
            contentHost:DockMargin(R:X(100), R:Y(10), R:X(99), R:Y(20))
        else
            header:DockMargin(R:X(100), R:Y(88), R:X(99), 0)
            header:SetTall(R:Y(92))
            contentHost:DockMargin(R:X(100), R:Y(24), R:X(99), R:Y(20))
        end
    end

    updateCardStepLayout()
    function styleStepScrollbar(scrollPanel)
        if not IsValid(scrollPanel) then return end
        local vbar = scrollPanel:GetVBar()
        if not IsValid(vbar) then return end
        vbar:SetWide(R:X(4))
        if IsValid(vbar.btnUp) then
            vbar.btnUp:SetTall(0)
            vbar.btnUp.Paint = function() end
        end

        if IsValid(vbar.btnDown) then
            vbar.btnDown:SetTall(0)
            vbar.btnDown.Paint = function() end
        end

        if IsValid(vbar.btnGrip) then
            local _gripCol = Color(clrAccent.r, clrAccent.g, clrAccent.b, 130)
            vbar.btnGrip.Paint = function(_, w, h) RNDX().Rect(0, 0, w, h):Rad(math.floor(w * 0.5)):Color(_gripCol):Draw() end
        end
    end

    function createStepBody(index)
        local scroll = vgui.Create("DScrollPanel", contentHost)
        scroll:SetPos(0, 0)
        scroll:SetSize(contentHost:GetWide(), contentHost:GetTall())
        scroll:SetVisible(false)
        scroll.Paint = nil
        styleStepScrollbar(scroll)
        stepBodies[index] = scroll
        return scroll
    end

    for stepIndex = 1, totalSteps do
        createStepBody(stepIndex)
    end

    function setStepBody(index)
        activeStepBody = stepBodies[math.Clamp(math.floor(tonumber(index) or 1), 1, totalSteps)]
    end

    local updateStepButtons = function() end
    function setCurrentStep(index)
        currentStep = math.Clamp(math.floor(tonumber(index) or 1), 1, totalSteps)
        -- Step 1 = vue corps, step 2+ = zoom visage permanent
        _ccCamMode = (currentStep >= 2) and "face" or "body"
        updateCardStepLayout()
        for stepIndex, panel in ipairs(stepBodies) do
            local visible = stepIndex == currentStep
            if IsValid(panel) then
                panel:SetVisible(visible)
                if visible then
                    local vbar = panel:GetVBar()
                    if IsValid(vbar) and vbar.SetScroll then vbar:SetScroll(0) end
                end
            end
        end

        if IsValid(card) then card:InvalidateLayout(true) end
        if IsValid(contentHost) then contentHost:InvalidateLayout(true) end
        if IsValid(header) then header:InvalidateLayout(true) end
        if isfunction(updateStepButtons) then updateStepButtons() end
    end

    function addRow(h, bottom)
        local parent = activeStepBody
        if not IsValid(parent) then parent = stepBodies[1] end
        local p = vgui.Create("DPanel", parent)
        p:Dock(TOP)
        p:DockMargin(0, 0, 0, R:Y(bottom or 12))
        p:SetTall(R:Y(h))
        p.Paint = nil
        return p
    end

    function beginStep(index)
        setStepBody(index)
    end

    function addSectionTitle(text)
        local p = addRow(38, 18)
        p._baseTall = R:Y(38)
        p._baseBottom = R:Y(18)
        p.Paint = function(_, _, h) draw.SimpleText(text, fontSectionTitle, 0, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        return p
    end

    function addComboField(title, placeholder)
        local row = addRow(92, 14)
        row.Paint = function() draw.SimpleText(title, fontFieldLabel, R:X(22), 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
        local combo = vgui.Create("MantleComboBox", row)
        combo:Dock(BOTTOM)
        combo:DockMargin(R:X(22), 0, R:X(22), 0)
        combo:SetTall(R:Y(69))
        combo:SetPlaceholder(placeholder)
        combo:SetFonts(fontFieldValue, fontFieldValue, fontFieldValue)
        return combo
    end

    function addEntryField(title, placeholder)
        local row = addRow(88, 14)
        local entryTall = R:Y(64)
        local insetX = R:X(22)
        local textInsetX = R:X(22)
        surface.SetFont(fontFieldValue)
        local _, textHeight = surface.GetTextSize("Hg")
        local textInsetY = math.max(0, math.floor((entryTall - textHeight) * 0.5))
        row.Paint = function(_, _, _) draw.SimpleText(title, fontFieldLabel, insetX, R:Y(2), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
        local entry = vgui.Create("MantleEntry", row)
        entry:Dock(BOTTOM)
        entry:DockMargin(insetX, 0, insetX, R:Y(1))
        entry:SetTall(entryTall)
        entry:SetPlaceholder(placeholder)
        entry:SetFonts(fontFieldValue, fontFieldLabel)
        entry:SetAllowNonAscii(true)
        if entry.SetPlaceholderColor then entry:SetPlaceholderColor(clrEntryPlaceholder) end
        if entry.SetTextColor then entry:SetTextColor(color_white) end
        if entry.SetHighlightColor then entry:SetHighlightColor(Color(clrAccent.r, clrAccent.g, clrAccent.b, 120)) end
        if entry.SetCursorColor then entry:SetCursorColor(clrAccent) end
        entry.Paint = function() end
        if IsValid(entry.textEntry) then
            if entry.textEntry.SetTextInset then entry.textEntry:SetTextInset(textInsetX, textInsetY) end
            entry.textEntry.Paint = function(s, w, h)
                local fontText = entry.fontText or fontFieldValue
                local value = entry:GetValue() or ""
                local isFocused = s:HasFocus() or s:IsEditing()
                local fillColor = isFocused and clrEntryFillHover or clrEntryFill
                local outlineColor = isFocused and clrEntryOutlineFocus or clrEntryOutline
                local placeholderColor = entry._placeholderCol or clrEntryPlaceholder
                local textColor = entry._textCol or color_white
                local highlightColor = entry._highlightCol or Color(clrAccent.r, clrAccent.g, clrAccent.b, 120)
                local cursorColor = entry._cursorCol or clrAccent
                RNDX().Rect(0, 0, w, h):Rad(radiusEntry):Color(clrEntryBase):Draw()
                RNDX().Rect(0, 0, w, h):Rad(radiusEntry):Color(fillColor):Draw()
                RNDX().Rect(0, 0, w, h):Rad(radiusEntry):Color(outlineColor):Outline(1):Draw()
                if s.SetFontInternal then s:SetFontInternal(fontText) end
                if s.SetFont then s:SetFont(fontText) end
                if value == "" and not isFocused then
                    draw.SimpleText(entry.placeholder or "", fontText, textInsetX, textInsetY + (textHeight * 0.5), placeholderColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    return true
                end

                s:DrawTextEntryText(textColor, highlightColor, cursorColor)
                return true
            end
        end
        return entry
    end

    function addSectionGap()
        addRow(4, 4)
    end

    function formatCreatorSliderValue(val, decimals)
        if tonumber(decimals) and tonumber(decimals) > 0 then return string.format("%." .. tostring(math.floor(tonumber(decimals) or 0)) .. "f", tonumber(val) or 0) end
        return tostring(math.Round(tonumber(val) or 0))
    end

    function styleCreatorSlider(slider)
        if not IsValid(slider) then return slider end
        slider._creatorLabelX = R:X(2)
        slider._creatorLabelY = R:Y(2)
        slider._creatorTrackPadL = R:X(14)
        slider._creatorTrackPadR = R:X(14)
        slider._creatorTrackY = R:Y(47)
        slider._creatorTrackH = math.max(2, R:Y(6))
        slider._creatorValueGap = R:Y(3)
        slider._creatorValueH = R:Y(20)
        slider._creatorMinMaxY = slider._creatorTrackY - R:Y(12)
        slider._creatorTickY = slider._creatorTrackY + slider._creatorTrackH + R:Y(5)
        slider._creatorTickH = R:Y(7)
        slider._creatorTickW = math.max(1, R:X(2))
        slider._creatorSmoothCenter = slider._creatorTrackPadL
        slider.UpdateSliderByCursorPos = function(s, absX)
            local w = s:GetWide()
            local barStart = s._creatorTrackPadL or 0
            local barEnd = w - (s._creatorTrackPadR or 0)
            local barW = math.max(1, barEnd - barStart)
            local localX = absX - barStart
            local progress = math.Clamp(localX / barW, 0, 1)
            local newValue = s.min_value + progress * (s.max_value - s.min_value)
            if (s.decimals or 0) > 0 then
                newValue = tonumber(string.format("%." .. tostring(math.floor(s.decimals or 0)) .. "f", newValue)) or newValue
            else
                newValue = math.Round(newValue)
            end

            s:SetValue(newValue)
        end

        slider.Paint = function(s, w, h)
            local ft = FrameTime()
            local barStart = s._creatorTrackPadL or 0
            local barEnd = w - (s._creatorTrackPadR or 0)
            local barW = math.max(1, barEnd - barStart)
            local barY = s._creatorTrackY or 0
            local barH = s._creatorTrackH or 1
            local barRad = barH * 0.5
            local denom = (s.max_value or 0) - (s.min_value or 0)
            local progress = denom == 0 and 0 or ((s.value or 0) - (s.min_value or 0)) / denom
            progress = math.Clamp(progress, 0, 1)
            local targetCenter = barStart + (barW * progress)
            s._creatorSmoothCenter = Mantle.func.approachExp(s._creatorSmoothCenter or targetCenter, targetCenter, 18, ft)
            local fillColor = s.dragging and clrSliderFillDrag or clrSliderFill
            local valueText = formatCreatorSliderValue(s.value, s.decimals)
            surface.SetFont(s.fontValue or fontSliderValue)
            local valueTextW = surface.GetTextSize(valueText)
            local pillW = math.max(R:X(38), valueTextW + R:X(14))
            local pillH = s._creatorValueH or R:Y(22)
            local pillX = math.Clamp((s._creatorSmoothCenter or targetCenter) - (pillW * 0.5), barStart, barEnd - pillW)
            local pillY = barY - (s._creatorValueGap or 0) - pillH
            draw.SimpleText(s.text or "", s.fontTitle or fontSliderTitle, s._creatorLabelX or 0, s._creatorLabelY or 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(s.min_value or 0), s.fontMinMax or fontSliderMinMax, barStart, s._creatorMinMaxY or 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(s.max_value or 0), s.fontMinMax or fontSliderMinMax, barEnd, s._creatorMinMaxY or 0, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            RNDX().Rect(barStart, barY, barW, barH):Rad(barRad):Color(clrSliderTrack):Draw()
            RNDX().Rect(barStart, barY, math.max(barH, (s._creatorSmoothCenter or targetCenter) - barStart), barH):Rad(barRad):Color(fillColor):Draw()
            RNDX().Rect(pillX, pillY, pillW, pillH):Rad(pillH * 0.5):Color(fillColor):Draw()
            draw.SimpleText(valueText, s.fontValue or fontSliderValue, pillX + (pillW * 0.5), pillY + (pillH * 0.5), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            RNDX().Rect(barStart, s._creatorTickY or 0, s._creatorTickW or 1, s._creatorTickH or 1):Rad((s._creatorTickW or 1) * 0.5):Color(clrSliderTick):Draw()
            RNDX().Rect(barEnd - (s._creatorTickW or 1), s._creatorTickY or 0, s._creatorTickW or 1, s._creatorTickH or 1):Rad((s._creatorTickW or 1) * 0.5):Color(clrSliderTick):Draw()
        end
        return slider
    end

    local genderValues = self:GetGenderValues()
    local selectedGender = genderValues.male and "male" or tostring(cfg.DefaultGender or "male")
    if not genderValues[selectedGender] then
        if genderValues.male then
            selectedGender = "male"
        elseif genderValues.female then
            selectedGender = "female"
        end
    end

    local refreshGenderBtns = function() end
    function forceFactionPreviewGender()
        if genderValues.male then
            selectedGender = "male"
        elseif not genderValues[selectedGender] and genderValues.female then
            selectedGender = "female"
        end
    end

    beginStep(1)
    if self:FactionsEnabled() and not lockedFaction then
        factionCombo = addComboField(Language("character.faction"), Language("character.faction_placeholder"))
        local factions = {}
        for id, f in pairs(cfg.Factions or {}) do
            if istable(f) then
                factions[#factions + 1] = {
                    id = id,
                    name = tostring(f.name or id)
                }
            end
        end

        table.sort(factions, function(a, b) return a.name:lower() < b.name:lower() end)
        for _, item in ipairs(factions) do
            factionCombo:AddChoice(item.name, item.id)
        end

        factionCombo.OnSelect = function(_, _, _)
            forceFactionPreviewGender()
            refreshGenderBtns()
            setPreviewCameraFocus("body")
            buildPreviewCSM(selectedGender)
        end

        if factions[1] then factionCombo:SetSelected(factions[1].name, factions[1].id) end
    end

    local nicknameEntry, first, last, ageSlider, heightSlider = nil, nil, nil, nil, nil
    if self:ConfigBool("NicknameMode", true) then
        nicknameEntry = addEntryField(Language("character.nickname"), Language("character.nickname_placeholder"))
    else
        last = addEntryField(Language("character.lastname"), Language("character.lastname_placeholder"))
        first = addEntryField(Language("character.firstname"), Language("character.firstname_placeholder"))
    end

    if self:GenderEnabled() then
        local rowGender = addRow(76, 16)
        rowGender.Paint = function(_, _, _) draw.SimpleText(Language("character.gender_placeholder"), fontFieldLabel, R:X(22), 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
        local genderWrap = vgui.Create("DPanel", rowGender)
        genderWrap:SetSize(R:XY(250, 42))
        genderWrap.Paint = nil
        rowGender.PerformLayout = function(_, w, h) genderWrap:SetPos(R:X(22), h - genderWrap:GetTall()) end
        local genderButtons = {}
        local allowed = {}
        if genderValues.male then
            allowed[#allowed + 1] = {
                id = "male",
                text = Language("character.gender_male")
            }
        end

        if genderValues.female then
            allowed[#allowed + 1] = {
                id = "female",
                text = Language("character.gender_female")
            }
        end

        genderWrap.PerformLayout = function(_, w, h)
            local count = #genderButtons
            if count == 0 then return end
            local gap = R:X(16)
            local totalGap = gap * math.max(count - 1, 0)
            local bw = math.floor((w - totalGap) / count)
            local x = 0
            for i = 1, count do
                local item = genderButtons[i]
                item.btn:SetPos(x, 0)
                item.btn:SetSize(bw, h)
                x = x + bw + gap
            end
        end

        local activeGenderColors = {
            male = {
                base = Color(75, 105, 227),
                hover = Color(96, 127, 247),
            },
            female = {
                base = Color(198, 114, 244),
                hover = Color(217, 136, 255),
            },
        }

        function refreshGenderBtns()
            for _, item in ipairs(genderButtons) do
                if selectedGender == item.id then
                    local pal = activeGenderColors[item.id] or activeGenderColors.female
                    item.btn:SetColor(pal.base)
                    item.btn:SetColorHover(pal.hover)
                else
                    item.btn:SetColor(clrGhost)
                    item.btn:SetColorHover(clrGhostHover)
                end
            end
        end

        for _, opt in ipairs(allowed) do
            local btn = vgui.Create("MantleBtn", genderWrap)
            btn:SetTxt("")
            btn:SetFont(Font:GetNamed("Poppins", "Bold", 20))
            btn:SetRadius(radiusButton)
            if opt.id == "male" then
                btn:SetIcon(Materials:Get("character_male_icon"), R:X(26), R:Y(26))
            else
                btn:SetIcon(Materials:Get("character_female_icon"), R:X(19), R:Y(26))
            end

            btn:SetRipple(true)
            btn:SetGradient(false)
            btn.DoClick = function()
                selectedGender = opt.id
                refreshGenderBtns()
                setPreviewCameraFocus("body")
                buildPreviewCSM(opt.id)
            end

            genderButtons[#genderButtons + 1] = {
                id = opt.id,
                btn = btn
            }
        end

        refreshGenderBtns()
    end

    buildPreviewCSM(selectedGender)
    if self:ConfigBool("EnableAge", false) then
        local rowAge = addRow(77, 18)
        local wrap = vgui.Create("DPanel", rowAge)
        wrap:Dock(FILL)
        wrap.Paint = nil
        ageSlider = vgui.Create("MantleSlideBox", wrap)
        ageSlider:Dock(FILL)
        ageSlider:SetText(Language("character.age"))
        local minA = self:ConfigInt("AgeMin", 16, 0, 200)
        local maxA = self:ConfigInt("AgeMax", 60, minA, 200)
        local defA = self:ConfigInt("DefaultAge", 18, minA, maxA)
        ageSlider:SetRange(minA, maxA, 0)
        ageSlider:SetValue(defA, true)
        ageSlider:SetFonts(fontSliderTitle, fontSliderValue, fontSliderMinMax)
        styleCreatorSlider(ageSlider)
    end

    local rowHeight = addRow(77, 18)
    local wrapHeight = vgui.Create("DPanel", rowHeight)
    wrapHeight:Dock(FILL)
    wrapHeight.Paint = nil
    heightSlider = vgui.Create("MantleSlideBox", wrapHeight)
    heightSlider:Dock(FILL)
    heightSlider:SetText(Language("character.height"))
    heightSlider:SetRange(minH, maxH, 0)
    heightSlider:SetValue(defH, true)
    heightSlider:SetFonts(fontSliderTitle, fontSliderValue, fontSliderMinMax)
    styleCreatorSlider(heightSlider)
    heightSlider.OnValueChanged = function(_, value)
        currentPreviewHeight = tonumber(value) or defH
        applyPreviewScale(currentPreviewHeight)
        setPreviewCameraFocus("body")
    end

    function addAppearanceSlider(label, minValue, maxValue, currentValue, onChanged)
        local baseTall = R:Y(77)
        local baseBottom = R:Y(18)
        local row = addRow(77, 18)
        local wrap = vgui.Create("DPanel", row)
        wrap:Dock(FILL)
        wrap:DockMargin(0, R:Y(2), 0, 0)
        wrap.Paint = nil
        local slider = vgui.Create("MantleSlideBox", wrap)
        slider:Dock(FILL)
        slider:SetText(label)
        slider:SetRange(minValue, maxValue, 0)
        slider:SetValue(currentValue, true)
        slider:SetFonts(fontSliderTitle, fontSliderValue, fontSliderMinMax)
        styleCreatorSlider(slider)
        slider.OnValueChanged = function(_, value) if onChanged then onChanged(math.Round(tonumber(value) or minValue)) end end
        slider._ownerRow = row
        slider._baseTall = baseTall
        slider._baseBottom = baseBottom
        return slider
    end

    function addAppearanceBodyMarkTransformControl(positionLabel, sizeLabel, onPositionChanged, onSizeChanged)
        local baseTall = R:Y(188)
        local baseBottom = R:Y(14)
        local row = addRow(188, 14)
        local host = vgui.Create("VCMarkTransform", row)
        host:Dock(FILL)
        if host.SetPositionCallback then host:SetPositionCallback(onPositionChanged) end
        if host.SetSizeCallback then host:SetSizeCallback(onSizeChanged) end
        if host.SetPositionText then host:SetPositionText(positionLabel) end
        if host.SetSizeText then host:SetSizeText(sizeLabel) end
        if host.SetPositionAxisLabels then host:SetPositionAxisLabels("X", "Y") end
        if host.SetSizeAxisLabels then host:SetSizeAxisLabels("Largeur", "Hauteur") end
        if host.SetPositionRange then host:SetPositionRange(BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX) end
        if host.SetSizeRange then host:SetSizeRange(BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX) end
        if host.SetPadFonts then host:SetPadFonts(fontFieldLabel, fontSliderMinMax) end
        if host.SetPadTheme then
            host:SetPadTheme({
                base = clrBodyMarkPadBase,
                outline = clrBodyMarkPadOutline,
                axis = clrBodyMarkPadAxis,
                cursor = clrBodyMarkPadCursor,
                value = clrBodyMarkPadValue,
            })
        end

        if host.SetValues then host:SetValues(BODY_MARK_DEFAULT_X, BODY_MARK_DEFAULT_Y, BODY_MARK_DEFAULT_SIZE, BODY_MARK_DEFAULT_SIZE, true) end
        host._ownerRow = row
        host._baseTall = baseTall
        host._baseBottom = baseBottom
        return host
    end

    function addAppearanceHairStylePicker(label)
        local topInset = R:Y(34)
        local tileW = R:X(92)
        local tileH = R:Y(102)
        local gapX = R:X(8)
        local gapY = R:Y(10)
        local row = addRow(topInset + tileH, 14)
        row.Paint = function() draw.SimpleText(label, fontFieldLabel, 0, 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
        local host = vgui.Create("DPanel", row)
        host:Dock(FILL)
        host:DockMargin(0, topInset, 0, 0)
        host.Paint = nil
        local grid = vgui.Create("DIconLayout", host)
        grid:Dock(FILL)
        grid:SetSpaceX(gapX)
        grid:SetSpaceY(gapY)
        host._grid = grid
        host._cols = 5
        host._tileW = tileW
        host._tileH = tileH
        host._gapY = gapY
        host._topInset = topInset
        host._ownerRow = row
        host._baseTall = row:GetTall()
        host._baseBottom = R:Y(14)
        host._tiles = {}
        return host
    end

    function addAppearanceIrisStylePicker(label)
        local host = addAppearanceHairStylePicker(label)
        if not IsValid(host) then return host end
        host._cols = 5
        host._tileW = R:X(92)
        host._tileH = R:Y(102)
        host._gapY = R:Y(10)
        host._baseBottom = R:Y(14)
        return host
    end

    refreshHairStylePreviewGrid = function()
        if not IsValid(hairStylePicker) then return end
        local hairMax = getBodygroupMax(preview.headCSM, 1)
        local hairOptionCount = (IsValid(preview.headCSM) and isstring(currentBodyModel) and currentBodyModel ~= "" and isstring(currentHeadModel) and currentHeadModel ~= "" and hairMax >= 0) and (hairMax + 1) or 0
        local visible = hairOptionCount > 1
        setAppearanceControlVisible(hairStylePicker, visible)
        if not visible then return end
        local cols = math.max(1, math.floor(tonumber(hairStylePicker._cols) or 5))
        local totalTileCount = hairOptionCount
        local rows = math.max(1, math.ceil(totalTileCount / cols))
        local totalTall = (hairStylePicker._topInset or 0) + (rows * (hairStylePicker._tileH or 0)) + (math.max(0, rows - 1) * (hairStylePicker._gapY or 0))
        hairStylePicker._baseTall = totalTall
        if IsValid(hairStylePicker._ownerRow) then
            hairStylePicker._ownerRow:SetTall(totalTall)
            hairStylePicker._ownerRow:DockMargin(0, 0, 0, hairStylePicker._baseBottom or 0)
        end

        local modelKey = table.concat({tostring(currentBodyModel or ""), tostring(currentHeadModel or ""), tostring(hairOptionCount)}, "\31")
        local thumbTextureFilter = (render.PushFilterMin and render.PushFilterMag and render.PopFilterMin and render.PopFilterMag and TEXFILTER and (TEXFILTER.ANISOTROPIC or TEXFILTER.LINEAR)) or nil
        if hairStylePicker._modelKey ~= modelKey then
            hairStylePicker._modelKey = modelKey
            if IsValid(hairStylePicker._grid) then hairStylePicker._grid:Clear() end
            hairStylePicker._tiles = {}
            for styleIndex = 0, hairOptionCount - 1 do
                local tile = vgui.Create("VCHairTile", hairStylePicker._grid)
                tile:SetSize(hairStylePicker._tileW or R:X(92), hairStylePicker._tileH or R:Y(102))
                if tile.SetStyleIndex then tile:SetStyleIndex(styleIndex) end
                if tile.SetPalette then tile:SetPalette(clrHairTileBase, clrHairTileHover, clrHairTileOutline, clrHairTileOutlineActive) end
                if tile.SetSelectedResolver then tile:SetSelectedResolver(function(s) return appearanceState.hairStyle == (s._safeStyleIndex or s._styleIndex) end) end
                if tile.SetOnSelect then
                    tile:SetOnSelect(function(s, safeStyle)
                        local nextStyle = safeStyle or normalizeBodygroupForEnt(preview.headCSM, 1, s._styleIndex)
                        if appearanceState.hairStyle == nextStyle then return end
                        appearanceState.hairStyle = nextStyle
                        applyPreviewBodygroups()
                        setPreviewCameraFocus("head")
                        refreshAppearanceControls()
                    end)
                else
                    tile.DoClick = function(s)
                        local nextStyle = s._safeStyleIndex or normalizeBodygroupForEnt(preview.headCSM, 1, s._styleIndex)
                        if appearanceState.hairStyle == nextStyle then return end
                        appearanceState.hairStyle = nextStyle
                        applyPreviewBodygroups()
                        setPreviewCameraFocus("head")
                        refreshAppearanceControls()
                    end
                end

                local thumb = vgui.Create("DModelPanel", tile)
                thumb:Dock(FILL)
                thumb:DockMargin(R:X(2), R:Y(2), R:X(2), R:Y(2))
                thumb._usesHeadRoot = isstring(currentHeadModel) and currentHeadModel ~= ""
                local tileRootModel = thumb._usesHeadRoot and currentHeadModel or currentBodyModel
                thumb:SetModel(tileRootModel)
                thumb:SetAnimated(false)
                thumb:SetMouseInputEnabled(false)
                thumb:SetKeyboardInputEnabled(false)
                thumb:SetPaintBackground(false)
                thumb:SetAmbientLight(Color(255, 255, 255))
                thumb:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
                thumb:SetDirectionalLight(BOX_FRONT, Color(230, 230, 230))
                thumb:SetDirectionalLight(BOX_RIGHT, Color(180, 180, 180))
                local baseThumbPaint = thumb.Paint or function() end
                thumb.Paint = function(s, w, h)
                    if not thumbTextureFilter then return baseThumbPaint(s, w, h) end
                    render.PushFilterMin(thumbTextureFilter)
                    render.PushFilterMag(thumbTextureFilter)
                    baseThumbPaint(s, w, h)
                    render.PopFilterMag()
                    render.PopFilterMin()
                end

                if IsValid(thumb.Entity) then
                    thumb.Entity:SetAngles(angle_zero)
                    thumb.Entity:SetPos(vector_origin)
                    if thumb.Entity.SetIK then thumb.Entity:SetIK(false) end
                    if thumb.Entity.ResetSequence then thumb.Entity:ResetSequence(0) end
                    if thumb.Entity.SetPlaybackRate then thumb.Entity:SetPlaybackRate(0) end
                    thumb.Entity:SetCycle(0)
                end

                if (not thumb._usesHeadRoot) and IsValid(thumb.Entity) and isstring(currentHeadModel) and currentHeadModel ~= "" then thumb._headEnt = spawnMergedPart(thumb.Entity, currentHeadModel) end
                local headEntForHair = thumb._usesHeadRoot and thumb.Entity or thumb._headEnt
                if IsValid(headEntForHair) and headEntForHair.SetBodygroup then pcall(headEntForHair.SetBodygroup, headEntForHair, 1, styleIndex) end
                thumb.LayoutEntity = function() end
                thumb.PreDrawModel = function() end
                thumb.PostDrawModel = function(s)
                    local headEnt = s._headEnt
                    if IsValid(headEnt) then headEnt:DrawModel() end
                end

                thumb.OnRemove = function(s)
                    if IsValid(s._headEnt) then s._headEnt:Remove() end
                    s._headEnt = nil
                end

                tile._preview = thumb
                hairStylePicker._tiles[#hairStylePicker._tiles + 1] = tile
            end

        end

        local skinColor = cloneColor(preview.skinColor or appearanceState.skinColor or (skinPalette[math.Clamp(math.floor(tonumber(appearanceState.skinTone) or 1), 1, math.max(1, #skinPalette))] or DEFAULT_SKIN_TONES[1]), DEFAULT_SKIN_TONES[1])
        local hairColor = cloneColor(preview.hairColor or appearanceState.hairColor, DEFAULT_HAIR_COLOR)
        local eyebrowColor = (appearanceState.eyebrowColorLinked ~= false) and cloneColor(hairColor, DEFAULT_HAIR_COLOR) or cloneColor(appearanceState.eyebrowColor, DEFAULT_HAIR_COLOR)
        local irisStyle = math.Clamp(math.floor(tonumber(appearanceState.irisStyle) or 1), 1, getEyeStyleCount())
        local irisSize = CH.NormalizeIrisSize and CH:NormalizeIrisSize(appearanceState.irisSize) or math.Clamp(math.floor(tonumber(appearanceState.irisSize) or 100), 60, 140)
        local eyeColor = cloneColor(appearanceState.eyeColor, DEFAULT_EYE_COLOR)
        for _, tile in ipairs(hairStylePicker._tiles or {}) do
            local thumb = tile._preview
            if IsValid(thumb) and IsValid(thumb.Entity) then
                local rootEnt = thumb.Entity
                local headEnt = IsValid(thumb._headEnt) and thumb._headEnt or rootEnt
                local safeBodyStyle = thumb._usesHeadRoot and nil or math.Clamp(tonumber(appearanceState.bodyStyle) or 0, 0, getBodygroupMax(rootEnt, 0))
                local prevEyebrowStyle = thumb._eyebrowStyle
                local prevIrisStyle = thumb._irisStyle
                local prevIrisSize = thumb._irisSize
                local prevSkinSig = thumb._skinSig
                local prevHairSig = thumb._hairSig
                local prevEyebrowSig = thumb._eyebrowSig
                local now = RealTime()
                thumb._skinColor = cloneColor(skinColor, DEFAULT_SKIN_TONES[1])
                thumb._hairColor = cloneColor(hairColor, DEFAULT_HAIR_COLOR)
                thumb._eyebrowColor = cloneColor(eyebrowColor, DEFAULT_HAIR_COLOR)
                thumb._eyebrowStyle = appearanceState.eyebrowStyle
                thumb._irisStyle = irisStyle
                thumb._irisSize = irisSize
                thumb._eyeColor = cloneColor(eyeColor, DEFAULT_EYE_COLOR)
                thumb._skinSig = string.format("%d,%d,%d,%d", thumb._skinColor.r or 255, thumb._skinColor.g or 255, thumb._skinColor.b or 255, thumb._skinColor.a or 255)
                thumb._hairSig = string.format("%d,%d,%d,%d", thumb._hairColor.r or 255, thumb._hairColor.g or 255, thumb._hairColor.b or 255, thumb._hairColor.a or 255)
                thumb._eyebrowSig = string.format("%d,%d,%d,%d", thumb._eyebrowColor.r or 255, thumb._eyebrowColor.g or 255, thumb._eyebrowColor.b or 255, thumb._eyebrowColor.a or 255)
                local poseDirty = false
                if safeBodyStyle ~= nil and thumb._safeBodyStyle ~= safeBodyStyle then
                    rootEnt:SetBodygroup(0, safeBodyStyle)
                    thumb._safeBodyStyle = safeBodyStyle
                    poseDirty = true
                elseif safeBodyStyle == nil then
                    thumb._safeBodyStyle = nil
                end

                local safeHeadStyle = normalizeBodygroupForEnt(headEnt, 0, appearanceState.headStyle)
                if thumb._safeHeadStyle ~= safeHeadStyle then
                    headEnt:SetBodygroup(0, safeHeadStyle)
                    thumb._safeHeadStyle = safeHeadStyle
                    poseDirty = true
                end

                if IsValid(headEnt) and headEnt.GetBodygroupCount and headEnt:GetBodygroupCount(1) then
                    local hairMax = math.max(0, (tonumber(headEnt:GetBodygroupCount(1)) or 0) - 1)
                    local safeHairStyle = math.Clamp(tonumber(tile._styleIndex) or 0, 0, hairMax)
                    if thumb._safeHairStyle ~= safeHairStyle then
                        headEnt:SetBodygroup(1, safeHairStyle)
                        thumb._safeHairStyle = safeHairStyle
                        poseDirty = true
                    end

                    local resolvedTileStyle = thumb._safeHairStyle or safeHairStyle
                    if tile.SetSafeStyleIndex then
                        tile:SetSafeStyleIndex(resolvedTileStyle)
                    else
                        tile._safeStyleIndex = resolvedTileStyle
                    end
                else
                    thumb._safeHairStyle = nil
                    if tile.SetSafeStyleIndex then
                        tile:SetSafeStyleIndex(tile._styleIndex)
                    else
                        tile._safeStyleIndex = tile._styleIndex
                    end
                end

                local colorDirty = (prevSkinSig ~= thumb._skinSig) or (prevHairSig ~= thumb._hairSig) or (prevEyebrowSig ~= thumb._eyebrowSig)
                local styleDirty = (prevEyebrowStyle ~= thumb._eyebrowStyle) or (prevIrisStyle ~= thumb._irisStyle)
                local irisSizeDirty = prevIrisSize ~= thumb._irisSize
                local isPriorityTile = tile:IsHovered() or appearanceState.hairStyle == (tile._safeStyleIndex or tile._styleIndex)
                local refreshDue = isPriorityTile or styleDirty or irisSizeDirty or poseDirty or colorDirty or (not thumb._tileVisualReady) or (now >= (thumb._nextPassiveRefreshAt or 0))
                if refreshDue then
                    if IsValid(headEnt) and styleDirty then
                        applyEntityEyebrowMaterial(headEnt, thumb._eyebrowStyle)
                        applyEntityEyeMaterial(headEnt, thumb._irisStyle)
                    end

                    setEyebrowMaterialTint(thumb._eyebrowStyle or 1, thumb._eyebrowColor or DEFAULT_HAIR_COLOR)
                    setEyeMaterialTint(thumb._irisStyle or 1, color_white)
                    setEyeMaterialSize(headEnt, thumb._irisStyle or 1, thumb._irisSize or (CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100))
                    if thumb._usesHeadRoot then
                        if isFaceControlModel(rootEnt:GetModel()) then
                            setFaceHeadSkinTint(rootEnt, thumb._skinColor or DEFAULT_SKIN_TONES[1])
                        else
                            setEntitySkinTint(rootEnt, thumb._skinColor or DEFAULT_SKIN_TONES[1])
                        end
                    else
                        setEntitySkinTint(rootEnt, thumb._skinColor or DEFAULT_SKIN_TONES[1])
                        if IsValid(headEnt) then
                            if isFaceControlModel(headEnt:GetModel()) then
                                setFaceHeadSkinTint(headEnt, thumb._skinColor or DEFAULT_SKIN_TONES[1])
                            else
                                setEntitySkinTint(headEnt, thumb._skinColor or DEFAULT_SKIN_TONES[1])
                            end
                        end
                    end

                    if CH.SetEntityHairColor and IsValid(headEnt) then CH.SetEntityHairColor(headEnt, thumb._hairColor or DEFAULT_HAIR_COLOR) end
                end

                if (poseDirty or not thumb._tilePoseReady) and refreshDue then
                    rootEnt:SetAngles(angle_zero)
                    rootEnt:SetCycle(0)
                    rootEnt:InvalidateBoneCache()
                    rootEnt:SetupBones()
                    if IsValid(headEnt) then
                        headEnt:InvalidateBoneCache()
                        headEnt:SetupBones()
                    end

                    local focus = getHeadFocusPositionForEnt(rootEnt)
                    local mins, maxs = headEnt:GetRenderBounds()

                    local center = (mins + maxs) * 0.5
                    local height = math.max(1, maxs.z - mins.z)
                    local radius = math.max(maxs.x - mins.x, maxs.y - mins.y, height)
                    local viewFocus = isvector(focus) and focus or (center + Vector(0, 0, height * 0.08))
                    local camDistance = math.Clamp(radius * 1.22, 20, 38)
                    thumb:SetFOV(22)
                    thumb:SetLookAt(viewFocus + Vector(0, 0, 0))
                    thumb:SetCamPos(viewFocus + Vector(camDistance, 0, 2.25))
                    thumb._tilePoseReady = true
                end

                if refreshDue then
                    thumb._tileVisualReady = true
                    thumb._nextPassiveRefreshAt = isPriorityTile and now or (now + 0.15)
                end

            end
        end

        local parent = hairStylePicker._ownerRow and hairStylePicker._ownerRow:GetParent() or nil
        if IsValid(parent) then parent:InvalidateLayout(true) end
    end

    refreshIrisStylePreviewGrid = function()
        if not IsValid(irisStylePicker) then return false end
        local eyeStyleCount = getEyeStyleCount()
        local visible = eyeStyleCount > 1
        setAppearanceControlVisible(irisStylePicker, visible)
        if not visible then return false end
        local cols = math.max(1, math.floor(tonumber(irisStylePicker._cols) or 5))
        local rows = math.max(1, math.ceil(eyeStyleCount / cols))
        local totalTall = (irisStylePicker._topInset or 0) + (rows * (irisStylePicker._tileH or 0)) + (math.max(0, rows - 1) * (irisStylePicker._gapY or 0))
        irisStylePicker._baseTall = totalTall
        if IsValid(irisStylePicker._ownerRow) then
            irisStylePicker._ownerRow:SetTall(totalTall)
            irisStylePicker._ownerRow:DockMargin(0, 0, 0, irisStylePicker._baseBottom or 0)
        end

        local modelKey = tostring(eyeStyleCount)
        if irisStylePicker._modelKey ~= modelKey then
            irisStylePicker._modelKey = modelKey
            if IsValid(irisStylePicker._grid) then irisStylePicker._grid:Clear() end
            irisStylePicker._tiles = {}
            for styleIndex = 1, eyeStyleCount do
                local tile = vgui.Create("VCHairTile", irisStylePicker._grid)
                tile:SetSize(irisStylePicker._tileW or R:X(92), irisStylePicker._tileH or R:Y(102))
                if tile.SetStyleIndex then tile:SetStyleIndex(styleIndex) end
                if tile.SetPalette then tile:SetPalette(clrHairTileBase, clrHairTileHover, clrHairTileOutline, clrHairTileOutlineActive) end
                if tile.SetSelectedResolver then tile:SetSelectedResolver(function(s) return appearanceState.irisStyle == (s._safeStyleIndex or s._styleIndex) end) end
                if tile.SetOnSelect then
                    tile:SetOnSelect(function(s, safeStyle)
                        local nextStyle = math.Clamp(math.floor(tonumber(safeStyle) or tonumber(s._styleIndex) or 1), 1, getEyeStyleCount())
                        if appearanceState.irisStyle == nextStyle then return end
                        appearanceState.irisStyle = nextStyle
                        applyPreviewEyeStyle()
                        applyPreviewEyeSize()
                        setPreviewCameraFocus("face")
                        refreshAppearanceControls()
                    end)
                else
                    tile.DoClick = function(s)
                        local nextStyle = math.Clamp(math.floor(tonumber(s._safeStyleIndex) or tonumber(s._styleIndex) or 1), 1, getEyeStyleCount())
                        if appearanceState.irisStyle == nextStyle then return end
                        appearanceState.irisStyle = nextStyle
                        applyPreviewEyeStyle()
                        applyPreviewEyeSize()
                        setPreviewCameraFocus("face")
                        refreshAppearanceControls()
                    end
                end

                tile._eyeMaterial = getIrisPreviewMaterial(styleIndex)
                local eyePanel = vgui.Create("DPanel", tile)
                eyePanel:Dock(FILL)
                eyePanel:DockMargin(R:X(6), R:Y(8), R:X(6), R:Y(8))
                eyePanel:SetMouseInputEnabled(false)
                eyePanel.Paint = function(_, w, h)
                    local mat = tile._eyeMaterial
                    if not mat then return end
                    local irisSize = math.max(16, math.floor(math.min(w, h) * 0.86))
                    local irisX = math.floor((w - irisSize) * 0.5)
                    local irisY = math.floor((h - irisSize) * 0.5)
                    local clr = tile._eyeColor or color_white
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(clr.r, clr.g, clr.b, 255)
                    surface.DrawTexturedRectUV(irisX, irisY, irisSize, irisSize, 0.04, 0.04, 0.96, 0.96)
                end
                tile._preview = eyePanel

                irisStylePicker._tiles[#irisStylePicker._tiles + 1] = tile
            end
        end

        do
            local hairColor = cloneColor(preview.hairColor or appearanceState.hairColor, DEFAULT_HAIR_COLOR)
            local skinColor = cloneColor(preview.skinColor or appearanceState.skinColor or (skinPalette[math.Clamp(math.floor(tonumber(appearanceState.skinTone) or 1), 1, math.max(1, #skinPalette))] or DEFAULT_SKIN_TONES[1]), DEFAULT_SKIN_TONES[1])
            local hairSig = string.format("%d,%d,%d,%d", hairColor.r or 255, hairColor.g or 255, hairColor.b or 255, hairColor.a or 255)
            local skinSig = string.format("%d,%d,%d,%d", skinColor.r or 255, skinColor.g or 255, skinColor.b or 255, skinColor.a or 255)
            local hairStyle = math.max(0, math.floor(tonumber(appearanceState.hairStyle) or 0))
            local headStyle = math.max(0, math.floor(tonumber(appearanceState.headStyle) or 0))
            local irisSizePct = math.Clamp(math.floor(tonumber(appearanceState.irisSize) or 100), 40, 200)
            local eyeColor = cloneColor(appearanceState.eyeColor, DEFAULT_EYE_COLOR)
            local eyeSig = string.format("%d,%d,%d", eyeColor.r or 255, eyeColor.g or 255, eyeColor.b or 255)
            for _, tile in ipairs(irisStylePicker._tiles or {}) do
                local thumb = tile._preview
                if IsValid(thumb) and IsValid(thumb.Entity) then
                    local ent = thumb.Entity
                    if tile._appliedHairStyle ~= hairStyle and ent.SetBodygroup then
                        pcall(ent.SetBodygroup, ent, 1, hairStyle)
                        tile._appliedHairStyle = hairStyle
                    end

                    if tile._appliedHeadStyle ~= headStyle and ent.SetBodygroup then
                        pcall(ent.SetBodygroup, ent, 0, headStyle)
                        tile._appliedHeadStyle = headStyle
                    end

                    if tile._appliedHairSig ~= hairSig and CH.SetEntityHairColor then
                        CH.SetEntityHairColor(ent, hairColor)
                        tile._appliedHairSig = hairSig
                    end

                    if tile._appliedSkinSig ~= skinSig and setEntitySkinTint then
                        setEntitySkinTint(ent, skinColor)
                        tile._appliedSkinSig = skinSig
                    end

                    local tileStyle = tonumber(tile._irisStyleIndex) or 1
                    local irisSig = string.format("%d|%d|%s", tileStyle, irisSizePct, eyeSig)
                    if tile._appliedIrisSig ~= irisSig and CH.SetEntityIris then
                        CH.SetEntityIris(ent, tileStyle, irisSizePct, eyeColor)
                        tile._appliedIrisSig = irisSig
                    end
                elseif IsValid(thumb) and tile._eyeMaterial then
                    tile._eyeColor = eyeColor
                end
            end
        end

        local parent = irisStylePicker._ownerRow and irisStylePicker._ownerRow:GetParent() or nil
        if IsValid(parent) then parent:InvalidateLayout(true) end
        return true
    end

    function addAppearanceColorField(label, initialColor, onPicked, onOpen)
        local row = addRow(75, 14)
        row.Paint = function(_, _, _) draw.SimpleText(label, fontFieldLabel, 0, 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
        local btn = vgui.Create("DButton", row)
        btn:Dock(BOTTOM)
        btn:SetTall(R:Y(41))
        btn:SetText("")
        btn._pickerColor = cloneColor(initialColor, color_white)
        btn.Paint = function(s, w, h)
            RNDX().Rect(0, 0, w, h):Rad(radiusColorOuter):Color(s:IsHovered() and clrFieldHover or clrField):Draw()
            RNDX().Rect(R:X(4), R:Y(4), w - R:X(8), h - R:Y(8)):Rad(radiusColorInner):Color(s._pickerColor or color_white):Draw()
        end

        btn.DoClick = function(s)
            if onOpen then onOpen() end
            Mantle.ui.color_picker(function(colorValue)
                s._pickerColor = cloneColor(colorValue, s._pickerColor)
                if onPicked then onPicked(s._pickerColor) end
            end, s._pickerColor)
        end

        btn._ownerRow = row
        btn._baseTall = R:Y(75)
        btn._baseBottom = R:Y(14)
        return btn
    end

    function addAppearanceCheckbox(label, currentValue, onChanged)
        local row = addRow(38, 8)
        local checkbox = vgui.Create("MantleCheckBox", row)
        checkbox:Dock(FILL)
        checkbox:SetTxt(label)
        checkbox:SetValue(currentValue == true)
        checkbox.OnChange = function(_, newValue) if onChanged then onChanged(newValue == true) end end
        checkbox._ownerRow = row
        checkbox._baseTall = R:Y(38)
        checkbox._baseBottom = R:Y(8)
        return checkbox
    end

    beginStep(3)
    bodyTypeSlider = addAppearanceSlider(Language("character.body_type"), 1, getPreviewChoiceCount("body", selectedGender), appearanceState.bodyType, function(value)
        appearanceState.bodyType = value
        setPreviewCameraFocus("body")
        buildPreviewCSM(selectedGender)
    end)

    bodyStyleSlider = addAppearanceSlider(Language("character.body_style"), 0, getBodygroupMax(preview.csm, 0), appearanceState.bodyStyle, function(value)
        appearanceState.bodyStyle = value
        applyPreviewBodygroups()
        setPreviewCameraFocus("body")
        refreshAppearanceControls()
    end)

    bodyMarksSectionTitle = addSectionTitle("Marques")
    function updateBodyMarkValue(categoryIndex, field, value, minValue, maxValue, fallback)
        local categories = getActiveBodyMarkCategories()
        local category = categories[categoryIndex]
        if not category then return end
        if self.NormalizeBodyMarksData then
            appearanceState.bodyMarks = self:NormalizeBodyMarksData(getActiveFactionId(), appearanceState.bodyMarks)
        else
            appearanceState.bodyMarks = {}
        end

        local entry = appearanceState.bodyMarks[category.id] or {}
        local previousStyle = math.floor(tonumber(entry.style) or category.default or 1)
        local nextValue = math.floor(tonumber(value) or fallback or 0)
        if minValue ~= nil then nextValue = math.max(minValue, nextValue) end
        if maxValue ~= nil then nextValue = math.min(maxValue, nextValue) end
        entry[field] = nextValue
        if field == "size" then
            entry.size_x = nextValue
            entry.size_y = nextValue
        elseif field == "size_x" or field == "size_y" then
            local safeSizeX = math.floor(tonumber(entry.size_x) or tonumber(entry.size) or BODY_MARK_DEFAULT_SIZE)
            local safeSizeY = math.floor(tonumber(entry.size_y) or tonumber(entry.size) or BODY_MARK_DEFAULT_SIZE)
            entry.size = math.Clamp(math.floor((safeSizeX + safeSizeY) * 0.5), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
        end

        if field == "style" and previousStyle ~= nextValue then
            entry.x = BODY_MARK_DEFAULT_X
            entry.y = BODY_MARK_DEFAULT_Y
            entry.rotate = BODY_MARK_DEFAULT_ROTATE
            entry.opacity = 100
            entry.size = BODY_MARK_DEFAULT_SIZE
            entry.size_x = BODY_MARK_DEFAULT_SIZE
            entry.size_y = BODY_MARK_DEFAULT_SIZE
        end

        appearanceState.bodyMarks[category.id] = entry
        applyPreviewBodyMarks()
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end

    function updateBodyMarkColor(categoryIndex, color)
        local categories = getActiveBodyMarkCategories()
        local category = categories[categoryIndex]
        if not category then return end
        if self.NormalizeBodyMarksData then
            appearanceState.bodyMarks = self:NormalizeBodyMarksData(getActiveFactionId(), appearanceState.bodyMarks)
        else
            appearanceState.bodyMarks = {}
        end

        local entry = appearanceState.bodyMarks[category.id] or {}
        if IsColor(color) then
            entry.color = string.format("%d,%d,%d", math.Clamp(math.floor(tonumber(color.r) or 255), 0, 255), math.Clamp(math.floor(tonumber(color.g) or 255), 0, 255), math.Clamp(math.floor(tonumber(color.b) or 255), 0, 255))
        else
            entry.color = ""
        end

        appearanceState.bodyMarks[category.id] = entry
        applyPreviewBodyMarks()
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end

    function updateBodyMarkPairValues(categoryIndex, fieldX, valueX, minX, maxX, fallbackX, fieldY, valueY, minY, maxY, fallbackY)
        local categories = getActiveBodyMarkCategories()
        local category = categories[categoryIndex]
        if not category then return end
        if self.NormalizeBodyMarksData then
            appearanceState.bodyMarks = self:NormalizeBodyMarksData(getActiveFactionId(), appearanceState.bodyMarks)
        else
            appearanceState.bodyMarks = {}
        end

        local entry = appearanceState.bodyMarks[category.id] or {}
        local nextX = math.floor(tonumber(valueX) or fallbackX or 0)
        local nextY = math.floor(tonumber(valueY) or fallbackY or 0)
        if minX ~= nil then nextX = math.max(minX, nextX) end
        if maxX ~= nil then nextX = math.min(maxX, nextX) end
        if minY ~= nil then nextY = math.max(minY, nextY) end
        if maxY ~= nil then nextY = math.min(maxY, nextY) end
        entry[fieldX] = nextX
        entry[fieldY] = nextY
        if (fieldX == "size_x" and fieldY == "size_y") or (fieldX == "size_y" and fieldY == "size_x") then entry.size = math.Clamp(math.floor((nextX + nextY) * 0.5), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX) end
        appearanceState.bodyMarks[category.id] = entry
        applyPreviewBodyMarks()
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end

    function updateSpiritAccessoryValue(field, value, minValue, maxValue, fallback)
        normalizeSpiritAccessoryTransformState()
        local entry = istable(appearanceState.spiritAccessoryData) and appearanceState.spiritAccessoryData or {}
        local nextValue = math.floor(tonumber(value) or fallback or 0)
        if minValue ~= nil then nextValue = math.max(minValue, nextValue) end
        if maxValue ~= nil then nextValue = math.min(maxValue, nextValue) end
        entry[field] = nextValue
        appearanceState.spiritAccessoryData = entry
        applyPreviewSpiritAccessory()
        setPreviewCameraFocus("head")
        refreshAppearanceControls()
    end

    local bodyMarkControlCount = 0
    if istable(cfg.Factions) and self.GetBodyMarkCategories then
        for _, factionCfg in pairs(cfg.Factions) do
            bodyMarkControlCount = math.max(bodyMarkControlCount, #(self:GetBodyMarkCategories(factionCfg) or {}))
        end
    end

    bodyMarkControlCount = math.max(bodyMarkControlCount, #getActiveBodyMarkCategories())
    for bodyMarkIndex = 1, bodyMarkControlCount do
        local controls = {}
        controls.enabled = addAppearanceCheckbox("Activer " .. tostring(bodyMarkIndex), false, function(value)
            local categories = getActiveBodyMarkCategories()
            local category = categories[bodyMarkIndex]
            if not category then return end
            appearanceState.bodyMarksEnabled = appearanceState.bodyMarksEnabled or {}
            appearanceState.bodyMarksEnabled[category.id] = value == true
            if value ~= true then
                updateBodyMarkValue(bodyMarkIndex, "style", 1, 1, math.max(1, #(category.options or {})), 1)
            else
                local current = (appearanceState.bodyMarks[category.id] or {}).style or 1
                if current <= 1 and #(category.options or {}) > 1 then updateBodyMarkValue(bodyMarkIndex, "style", 2, 1, #category.options, 1) end
                local entry = appearanceState.bodyMarks[category.id] or {}
                if not isstring(entry.color) or entry.color == "" then
                    entry.color = "0,0,0"
                    appearanceState.bodyMarks[category.id] = entry
                    applyPreviewBodyMarks()
                end
            end

            refreshAppearanceControls()
        end)

        controls.style = addAppearanceSlider("Marque " .. tostring(bodyMarkIndex), 1, 1, 1, function(value)
            local categories = getActiveBodyMarkCategories()
            local category = categories[bodyMarkIndex]
            local maxStyle = category and math.max(1, #(category.options or {})) or 1
            updateBodyMarkValue(bodyMarkIndex, "style", value, 1, maxStyle, 1)
        end)

        controls.posY = addAppearanceSlider("Marque " .. tostring(bodyMarkIndex) .. " Haut/Bas", BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, BODY_MARK_DEFAULT_Y, function(value) updateBodyMarkValue(bodyMarkIndex, "y", value, BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, BODY_MARK_DEFAULT_Y) end)
        controls.posX = addAppearanceSlider("Marque " .. tostring(bodyMarkIndex) .. " Gauche/Droite", BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, BODY_MARK_DEFAULT_X, function(value) updateBodyMarkValue(bodyMarkIndex, "x", value, BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, BODY_MARK_DEFAULT_X) end)
        controls.size = addAppearanceSlider("Marque " .. tostring(bodyMarkIndex) .. " Taille", BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, BODY_MARK_DEFAULT_SIZE, function(value) updateBodyMarkValue(bodyMarkIndex, "size", value, BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, BODY_MARK_DEFAULT_SIZE) end)
        controls.stretch = addAppearanceCheckbox("Étirer " .. tostring(bodyMarkIndex), false, function(value)
            local categories = getActiveBodyMarkCategories()
            local category = categories[bodyMarkIndex]
            if not category then return end
            appearanceState.bodyMarksStretch = appearanceState.bodyMarksStretch or {}
            appearanceState.bodyMarksStretch[category.id] = value == true
            if value == true then
                local entry = appearanceState.bodyMarks[category.id] or {}
                local currentSize = math.Clamp(math.floor(tonumber(entry.size) or BODY_MARK_DEFAULT_SIZE), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
                entry.size_x = currentSize
                entry.size_y = currentSize
                appearanceState.bodyMarks[category.id] = entry
                applyPreviewBodyMarks()
            end
            refreshAppearanceControls()
        end)
        controls.sizeX = addAppearanceSlider("Marque " .. tostring(bodyMarkIndex) .. " Largeur", BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, BODY_MARK_DEFAULT_SIZE, function(value)
            local categories = getActiveBodyMarkCategories()
            local category = categories[bodyMarkIndex]
            if not category then return end
            local entry = appearanceState.bodyMarks[category.id] or {}
            local nextX = math.Clamp(math.floor(tonumber(value) or BODY_MARK_DEFAULT_SIZE), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
            local nextY = math.Clamp(math.floor(tonumber(entry.size_y) or tonumber(entry.size) or BODY_MARK_DEFAULT_SIZE), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
            entry.size_x = nextX
            entry.size_y = nextY
            entry.size = math.Clamp(math.floor((nextX + nextY) * 0.5), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
            appearanceState.bodyMarks[category.id] = entry
            applyPreviewBodyMarks()
            setPreviewCameraFocus("face")
        end)
        controls.sizeY = addAppearanceSlider("Marque " .. tostring(bodyMarkIndex) .. " Hauteur", BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, BODY_MARK_DEFAULT_SIZE, function(value)
            local categories = getActiveBodyMarkCategories()
            local category = categories[bodyMarkIndex]
            if not category then return end
            local entry = appearanceState.bodyMarks[category.id] or {}
            local nextX = math.Clamp(math.floor(tonumber(entry.size_x) or tonumber(entry.size) or BODY_MARK_DEFAULT_SIZE), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
            local nextY = math.Clamp(math.floor(tonumber(value) or BODY_MARK_DEFAULT_SIZE), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
            entry.size_x = nextX
            entry.size_y = nextY
            entry.size = math.Clamp(math.floor((nextX + nextY) * 0.5), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX)
            appearanceState.bodyMarks[category.id] = entry
            applyPreviewBodyMarks()
            setPreviewCameraFocus("face")
        end)
        controls.rotate = addAppearanceSlider("Marque " .. tostring(bodyMarkIndex) .. " Rotation", 0, 360, BODY_MARK_DEFAULT_ROTATE, function(value) updateBodyMarkValue(bodyMarkIndex, "rotate", value, 0, 360, BODY_MARK_DEFAULT_ROTATE) end)
        controls.opacity = addAppearanceSlider("Marque " .. tostring(bodyMarkIndex) .. " Opacité", 0, 100, 100, function(value) updateBodyMarkValue(bodyMarkIndex, "opacity", value, 0, 100, 100) end)
        controls.color = addAppearanceColorField("Couleur " .. tostring(bodyMarkIndex), Color(0, 0, 0), function(colorValue) updateBodyMarkColor(bodyMarkIndex, colorValue) end, function() setPreviewCameraFocus("face") end)
        bodyMarkSliders[bodyMarkIndex] = controls
    end

    spiritAccessorySectionTitle = addSectionTitle("Ornements")
    spiritAccessorySlider = addAppearanceSlider("Ornement", 0, 1, 0, function(value)
        appearanceState.spiritAccessory = value
        applyPreviewSpiritAccessory()
        setPreviewCameraFocus("head")
        refreshAppearanceControls()
    end)

    spiritAccessoryXSlider = addAppearanceSlider("Ornement X", BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, BODY_MARK_DEFAULT_X, function(value) updateSpiritAccessoryValue("x", value, BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, BODY_MARK_DEFAULT_X) end)
    spiritAccessoryYSlider = addAppearanceSlider("Ornement Y", BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, BODY_MARK_DEFAULT_Y, function(value) updateSpiritAccessoryValue("y", value, BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, BODY_MARK_DEFAULT_Y) end)
    spiritAccessoryZSlider = addAppearanceSlider("Ornement Z", BODY_MARK_DEPTH_MIN, BODY_MARK_DEPTH_MAX, 0, function(value) updateSpiritAccessoryValue("z", value, BODY_MARK_DEPTH_MIN, BODY_MARK_DEPTH_MAX, 0) end)
    spiritAccessorySizeSlider = addAppearanceSlider("Ornement Size", BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, BODY_MARK_DEFAULT_SIZE, function(value) updateSpiritAccessoryValue("size", value, BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, BODY_MARK_DEFAULT_SIZE) end)
    beginStep(2)
    headTypeSlider = addAppearanceSlider("Type de tête", 1, math.max(1, getPreviewChoiceCount("head", selectedGender)), appearanceState.headType, function(value)
        appearanceState.headType = math.Clamp(math.floor(tonumber(value) or 1), 1, math.max(1, getPreviewChoiceCount("head", selectedGender)))
        buildPreviewCSM(selectedGender)
        setPreviewCameraFocus("head")
        refreshAppearanceControls()
    end)

    do
        local headMin, headMax = getBodygroupSliderBounds(preview.headCSM, 0)
        headStyleSlider = addAppearanceSlider(Language("character.head_style"), headMin, headMax, appearanceState.headStyle, function(value)
            appearanceState.headStyle = normalizeBodygroupForEnt(preview.headCSM, 0, value)
            applyPreviewBodygroups()
            applyPreviewEyebrowStyle()
            applyPreviewEyebrowColor()
            applyPreviewEyeStyle()
            applyPreviewEyeSize()
            applyPreviewEyeColor()
            setPreviewCameraFocus("head")
            refreshAppearanceControls()
        end)
    end

    hairStylePicker = addAppearanceHairStylePicker(Language("character.hair_style"))
    hairColorPicker = addAppearanceColorField(Language("character.hair_color"), appearanceState.hairColor, function(colorValue)
        appearanceState.hairColor = cloneColor(colorValue, DEFAULT_HAIR_COLOR)
        applyPreviewHairColor()
        if appearanceState.eyebrowColorLinked then applyPreviewEyebrowColor_v2(appearanceState.hairColor) end
        setPreviewCameraFocus("head")
        refreshAppearanceControls()
    end, function() setPreviewCameraFocus("head") end)

    -- Dégradé de cheveux : case à cocher + 2e sélecteur (couleur des pointes).
    -- La couleur cheveux ci-dessus sert de racines, ce 2e sélecteur de pointes.
    hairGradientToggle = addAppearanceCheckbox(getCharacterLabel("hair_gradient", "Dégradé de cheveux"), appearanceState.hairGradientEnabled, function(value)
        appearanceState.hairGradientEnabled = value == true
        if appearanceState.hairGradientEnabled then
            appearanceState.hairTipColor = cloneColor(appearanceState.hairTipColor, appearanceState.hairColor)
        end
        applyPreviewHairColor()
        setPreviewCameraFocus("head")
        refreshAppearanceControls()
    end)

    hairTipColorPicker = addAppearanceColorField(getCharacterLabel("hair_tip_color", "Couleur des pointes"), appearanceState.hairTipColor, function(colorValue)
        appearanceState.hairTipColor = cloneColor(colorValue, DEFAULT_HAIR_COLOR)
        appearanceState.hairGradientEnabled = true
        applyPreviewHairColor()
        setPreviewCameraFocus("head")
        refreshAppearanceControls()
    end, function() setPreviewCameraFocus("head") end)

    eyebrowStyleSlider = addAppearanceSlider(getCharacterLabel("eyebrow_style", "Eyebrows"), 1, getEyebrowStyleCount(), appearanceState.eyebrowStyle, function(value)
        appearanceState.eyebrowStyle = value
        applyPreviewEyebrowStyle()
        applyPreviewEyebrowColor()
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end)

    eyebrowColorLinkToggle = addAppearanceCheckbox(getCharacterLabel("eyebrow_color_link", "Assortir la couleur des sourcils aux cheveux"), appearanceState.eyebrowColorLinked, function(value)
        if value ~= true and appearanceState.eyebrowColorLinked == true then appearanceState.eyebrowColor = cloneColor(appearanceState.hairColor, DEFAULT_HAIR_COLOR) end
        appearanceState.eyebrowColorLinked = value == true
        applyPreviewEyebrowColor()
        applyPreviewEyebrowColor_v2(appearanceState.eyebrowColorLinked and appearanceState.hairColor or appearanceState.eyebrowColor)
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end)

    eyebrowColorPicker = addAppearanceColorField(getCharacterLabel("eyebrow_color", "Brow Color"), appearanceState.eyebrowColor, function(colorValue)
        appearanceState.eyebrowColor = cloneColor(colorValue, DEFAULT_HAIR_COLOR)
        appearanceState.eyebrowColorLinked = false
        applyPreviewEyebrowColor()
        applyPreviewEyebrowColor_v2(appearanceState.eyebrowColor)
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end, function() setPreviewCameraFocus("face") end)

    eyelashColorPicker = addAppearanceColorField(getCharacterLabel("eyelash_color", "Couleur des cils"), appearanceState.eyelashColor or Color(0, 0, 0, 255), function(colorValue)
        appearanceState.eyelashColor = cloneColor(colorValue, Color(0, 0, 0, 255))
        applyPreviewEyelashColor(appearanceState.eyelashColor)
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end, function() setPreviewCameraFocus("face") end)

    irisStylePicker = addAppearanceIrisStylePicker(getCharacterLabel("iris_style", "Iris"))
    irisStyleSlider = addAppearanceSlider(getCharacterLabel("iris_style", "Iris"), 1, getEyeStyleCount(), appearanceState.irisStyle, function(value)
        appearanceState.irisStyle = value
        applyPreviewEyeStyle()
        applyPreviewEyeSize()
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end)

    irisSizeSlider = addAppearanceSlider(getCharacterLabel("iris_size", "Iris Size"), CH.GetIrisSizeMin and CH:GetIrisSizeMin() or 60, CH.GetIrisSizeMax and CH:GetIrisSizeMax() or 140, appearanceState.irisSize, function(value)
        appearanceState.irisSize = value
        applyPreviewEyeSize()
        setPreviewCameraFocus("face")
        refreshAppearanceControls()
    end)

    -- Eye Color picker supprime (masque, couleur par defaut conservee)

    addSectionTitle(Language("character.flex_section") ~= "character.flex_section" and Language("character.flex_section") or "Morphologie du visage")
    for _, flexName in ipairs(CH.FlexControllers or {}) do
        local label = (CH.FlexLabels and CH.FlexLabels[flexName]) or flexName
        local initial = math.Clamp(math.floor((tonumber((appearanceState.flex or {})[flexName]) or 0) * 100 + 0.5), 0, 100)
        addAppearanceSlider(label, 0, 100, initial, function(value)
            appearanceState.flex = appearanceState.flex or {}
            appearanceState.flex[flexName] = math.Clamp((tonumber(value) or 0) / 100, 0, 1)
            applyPreviewFlex()
            setPreviewCameraFocus("face")
        end)
    end

    beginStep(1)
    addSectionGap()
    addSectionTitle("Personnalisation")
    skinToneSlider = addAppearanceSlider(Language("character.skin_tone"), 1, math.max(1, #skinPalette), appearanceState.skinTone, function(value)
        appearanceState.skinTone = value
        applyPreviewSkinTone()
        setPreviewCameraFocus("body")
        refreshAppearanceControls()
    end)

    skinTonePicker = addAppearanceColorField(Language("character.skin_tone"), skinPalette[appearanceState.skinTone] or DEFAULT_SKIN_TONES[1], function(colorValue)
        appearanceState.skinColor = cloneColor(colorValue, DEFAULT_SKIN_TONES[1])
        appearanceState.skinTone = getNearestSkinToneIndex(colorValue)
        applyPreviewSkinTone()
        setPreviewCameraFocus("body")
        refreshAppearanceControls()
    end, function() setPreviewCameraFocus("body") end)

    refreshAppearanceControls = function()
        setAppearanceControlVisible(bodyTypeSlider, false)
        setAppearanceControlVisible(bodyStyleSlider, false)
        setAppearanceSliderState(headTypeSlider, 1, math.max(1, getPreviewChoiceCount("head", selectedGender)), appearanceState.headType or 1)
        if self.NormalizeBodyMarksData then appearanceState.bodyMarks = self:NormalizeBodyMarksData(getActiveFactionId(), appearanceState.bodyMarks) end
        local bodyMarkCategories = getActiveBodyMarkCategories()
        for bodyMarkIndex, controls in ipairs(bodyMarkSliders) do
            local category = bodyMarkCategories[bodyMarkIndex]
            if category then
                local categoryState = appearanceState.bodyMarks[category.id] or {}
                local categoryName = tostring(category.name or ("Marque " .. tostring(bodyMarkIndex)))
                appearanceState.bodyMarksEnabled = appearanceState.bodyMarksEnabled or {}
                local enabled = appearanceState.bodyMarksEnabled[category.id] == true
                local hasMaterial = enabled and hasBodyMarkMaterial(category, categoryState)
                if IsValid(controls.enabled) then
                    setAppearanceControlVisible(controls.enabled, true)
                    if controls.enabled.SetText then controls.enabled:SetText("Activer " .. categoryName) end
                    if controls.enabled.SetValue then controls.enabled:SetValue(enabled) end
                end

                if IsValid(controls.style) and controls.style.SetText then controls.style:SetText(categoryName) end
                if IsValid(controls.posY) and controls.posY.SetText then controls.posY:SetText(categoryName .. " Haut/Bas") end
                if IsValid(controls.posX) and controls.posX.SetText then controls.posX:SetText(categoryName .. " Gauche/Droite") end
                if IsValid(controls.size) and controls.size.SetText then controls.size:SetText(categoryName .. " Taille") end
                if IsValid(controls.rotate) and controls.rotate.SetText then controls.rotate:SetText(categoryName .. " Rotation") end
                if IsValid(controls.opacity) and controls.opacity.SetText then controls.opacity:SetText(categoryName .. " Opacité") end
                if IsValid(controls.stretch) and controls.stretch.SetText then controls.stretch:SetText("Étirer " .. categoryName) end
                if IsValid(controls.sizeX) and controls.sizeX.SetText then controls.sizeX:SetText(categoryName .. " Largeur") end
                if IsValid(controls.sizeY) and controls.sizeY.SetText then controls.sizeY:SetText(categoryName .. " Hauteur") end
                setAppearanceSliderState(controls.style, 1, math.max(1, #(category.options or {})), categoryState.style or category.default or 1)
                if IsValid(controls.style) then setAppearanceControlVisible(controls.style, enabled) end
                local stretching = istable(appearanceState.bodyMarksStretch) and appearanceState.bodyMarksStretch[category.id] == true
                if hasMaterial then
                    setSliderValueSafe(controls.posY, BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, categoryState.y or BODY_MARK_DEFAULT_Y)
                    setSliderValueSafe(controls.posX, BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, categoryState.x or BODY_MARK_DEFAULT_X)
                    setSliderValueSafe(controls.size, BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, categoryState.size or BODY_MARK_DEFAULT_SIZE)
                    setSliderValueSafe(controls.sizeX, BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, math.Clamp(math.floor(tonumber(categoryState.size_x) or tonumber(categoryState.size) or BODY_MARK_DEFAULT_SIZE), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX))
                    setSliderValueSafe(controls.sizeY, BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, math.Clamp(math.floor(tonumber(categoryState.size_y) or tonumber(categoryState.size) or BODY_MARK_DEFAULT_SIZE), BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX))
                    setSliderValueSafe(controls.rotate, 0, 360, categoryState.rotate or BODY_MARK_DEFAULT_ROTATE)
                    setSliderValueSafe(controls.opacity, 0, 100, categoryState.opacity or 100)
                    if IsValid(controls.stretch) and controls.stretch.SetValue then controls.stretch:SetValue(stretching) end
                end

                setAppearanceControlVisible(controls.posY, enabled and hasMaterial)
                setAppearanceControlVisible(controls.posX, enabled and hasMaterial)
                setAppearanceControlVisible(controls.size, enabled and hasMaterial and not stretching)
                setAppearanceControlVisible(controls.stretch, enabled and hasMaterial)
                setAppearanceControlVisible(controls.sizeX, enabled and hasMaterial and stretching)
                setAppearanceControlVisible(controls.sizeY, enabled and hasMaterial and stretching)
                setAppearanceControlVisible(controls.rotate, enabled and hasMaterial)
                setAppearanceControlVisible(controls.opacity, enabled and hasMaterial)
                if IsValid(controls.color) then
                    setAppearanceControlVisible(controls.color, enabled and hasMaterial)
                    local r, g, bl = 0, 0, 0
                    if isstring(categoryState.color) and categoryState.color ~= "" then
                        local rr, gg, bb = string.match(categoryState.color, "^(%d+),(%d+),(%d+)$")
                        if rr then r, g, bl = tonumber(rr) or 0, tonumber(gg) or 0, tonumber(bb) or 0 end
                    end

                    controls.color._pickerColor = Color(r, g, bl)
                end
            else
                for _, control in pairs(controls) do
                    if IsValid(control) and control.SetText then control:SetText("") end
                    setAppearanceControlVisible(control, false)
                end
            end
        end

        local hasVisibleBodyMarkControls = false
        for _, controls in ipairs(bodyMarkSliders) do
            if isAppearanceControlVisible(controls.enabled) or isAppearanceControlVisible(controls.style) or isAppearanceControlVisible(controls.posX) or isAppearanceControlVisible(controls.posY) or isAppearanceControlVisible(controls.size) or isAppearanceControlVisible(controls.stretch) or isAppearanceControlVisible(controls.sizeX) or isAppearanceControlVisible(controls.sizeY) or isAppearanceControlVisible(controls.rotate) or isAppearanceControlVisible(controls.opacity) or isAppearanceControlVisible(controls.color) then
                hasVisibleBodyMarkControls = true
                break
            end
        end

        setSectionTitleVisible(bodyMarksSectionTitle, hasVisibleBodyMarkControls)
        local spiritOptions = getActiveSpiritAccessoryOptions()
        local useSpiritAccessory = tostring(getActiveFactionId() or "") == "spirit" and #spiritOptions > 0
        if self.NormalizeSpiritAccessory then
            appearanceState.spiritAccessory = self:NormalizeSpiritAccessory(getActiveFactionId(), appearanceState.spiritAccessory)
        else
            appearanceState.spiritAccessory = math.max(0, math.floor(tonumber(appearanceState.spiritAccessory) or 0))
        end

        normalizeSpiritAccessoryTransformState()
        setAppearanceControlVisible(spiritAccessorySlider, useSpiritAccessory)
        if useSpiritAccessory then
            if IsValid(spiritAccessorySlider) and spiritAccessorySlider.SetText then spiritAccessorySlider:SetText("Ornement Spirit") end
            setSliderValueSafe(spiritAccessorySlider, 0, #spiritOptions, appearanceState.spiritAccessory)
        end

        local accessoryModel = (self.ResolveSpiritAccessoryModel and self:ResolveSpiritAccessoryModel(getActiveFactionId(), appearanceState.spiritAccessory)) or ""
        local hasSpiritAccessory = useSpiritAccessory and isstring(accessoryModel) and accessoryModel ~= ""
        local spiritAccessoryState = appearanceState.spiritAccessoryData or {}
        setAppearanceControlVisible(spiritAccessoryXSlider, hasSpiritAccessory)
        setAppearanceControlVisible(spiritAccessoryYSlider, hasSpiritAccessory)
        setAppearanceControlVisible(spiritAccessoryZSlider, hasSpiritAccessory)
        setAppearanceControlVisible(spiritAccessorySizeSlider, hasSpiritAccessory)
        if hasSpiritAccessory then
            setSliderValueSafe(spiritAccessoryXSlider, BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, spiritAccessoryState.x or BODY_MARK_DEFAULT_X)
            setSliderValueSafe(spiritAccessoryYSlider, BODY_MARK_OFFSET_MIN, BODY_MARK_OFFSET_MAX, spiritAccessoryState.y or BODY_MARK_DEFAULT_Y)
            setSliderValueSafe(spiritAccessoryZSlider, BODY_MARK_DEPTH_MIN, BODY_MARK_DEPTH_MAX, spiritAccessoryState.z or 0)
            setSliderValueSafe(spiritAccessorySizeSlider, BODY_MARK_SIZE_MIN, BODY_MARK_SIZE_MAX, spiritAccessoryState.size or BODY_MARK_DEFAULT_SIZE)
        end

        local hasVisibleSpiritAccessoryControls = isAppearanceControlVisible(spiritAccessorySlider) or isAppearanceControlVisible(spiritAccessoryXSlider) or isAppearanceControlVisible(spiritAccessoryYSlider) or isAppearanceControlVisible(spiritAccessoryZSlider) or isAppearanceControlVisible(spiritAccessorySizeSlider)
        setSectionTitleVisible(spiritAccessorySectionTitle, hasVisibleSpiritAccessoryControls)
        local hasVisibleBodyStepControls = isAppearanceControlVisible(bodyTypeSlider) or isAppearanceControlVisible(bodyStyleSlider) or hasVisibleBodyMarkControls or hasVisibleSpiritAccessoryControls
        local desiredTotalSteps = hasVisibleBodyStepControls and 3 or 2
        if totalSteps ~= desiredTotalSteps then
            totalSteps = desiredTotalSteps
            if currentStep > totalSteps then
                setCurrentStep(totalSteps)
            elseif isfunction(updateStepButtons) then
                updateStepButtons()
            end
        end

        do
            local headMin, headMax = getBodygroupSliderBounds(preview.headCSM, 0)
            setAppearanceSliderState(headStyleSlider, headMin, headMax, appearanceState.headStyle)
        end

        refreshHairStylePreviewGrid()
        local useSkinPicker = factionUsesSkinTonePicker()
        setAppearanceControlVisible(skinToneSlider, not useSkinPicker)
        setAppearanceControlVisible(skinTonePicker, useSkinPicker)
        if not useSkinPicker then setAppearanceSliderState(skinToneSlider, 1, math.max(1, #skinPalette), appearanceState.skinTone) end
        local useFaceControls = headUsesFaceMaterialControls()
        setAppearanceControlVisible(eyebrowStyleSlider, useFaceControls)
        setAppearanceControlVisible(eyebrowColorLinkToggle, true)
        setAppearanceControlVisible(eyebrowColorPicker, appearanceState.eyebrowColorLinked ~= true)
        setAppearanceControlVisible(irisSizeSlider, true)
        setAppearanceSliderState(irisSizeSlider, CH.GetIrisSizeMin and CH:GetIrisSizeMin() or 60, CH.GetIrisSizeMax and CH:GetIrisSizeMax() or 140, appearanceState.irisSize or 100)
        if useFaceControls then setAppearanceSliderState(eyebrowStyleSlider, 1, getEyebrowStyleCount(), appearanceState.eyebrowStyle) end
        local hasIrisPreview = refreshIrisStylePreviewGrid()
        setAppearanceControlVisible(irisStyleSlider, not hasIrisPreview)
        if not hasIrisPreview then setAppearanceSliderState(irisStyleSlider, 1, getEyeStyleCount(), appearanceState.irisStyle) end
        if IsValid(skinTonePicker) then skinTonePicker._pickerColor = cloneColor(appearanceState.skinColor, DEFAULT_SKIN_TONES[1]) end
        if IsValid(hairColorPicker) then hairColorPicker._pickerColor = cloneColor(appearanceState.hairColor, DEFAULT_HAIR_COLOR) end
        setAppearanceControlVisible(hairGradientToggle, true)
        setAppearanceControlVisible(hairTipColorPicker, appearanceState.hairGradientEnabled == true)
        if IsValid(hairGradientToggle) then hairGradientToggle:SetValue(appearanceState.hairGradientEnabled == true) end
        if IsValid(hairTipColorPicker) then hairTipColorPicker._pickerColor = cloneColor(appearanceState.hairTipColor, appearanceState.hairColor) end
        if IsValid(eyebrowColorPicker) then eyebrowColorPicker._pickerColor = cloneColor(appearanceState.eyebrowColor, DEFAULT_HAIR_COLOR) end
        if IsValid(eyebrowColorLinkToggle) then eyebrowColorLinkToggle:SetValue(appearanceState.eyebrowColorLinked == true) end
    end

    refreshAppearanceControls()
    local desc = nil
    if self:ConfigBool("EnableDescription", true) then
        beginStep(3)
        desc = addEntryField(Language("character.description"), Language("character.description_placeholder"))
        desc:SetValue("")
    end

    -- Couleurs pré-allouées pour les boutons du footer (évite Color() par frame)
    local _clrFooterFill    = Color(clrFooterProceedFill.r, clrFooterProceedFill.g, clrFooterProceedFill.b, clrFooterProceedFill.a)  -- .a muté
    local _clrFooterCancel  = Color(clrFooterCancel.r, clrFooterCancel.g, clrFooterCancel.b, 255)  -- r/g/b mutés

    function styleFooterActionButton(btn, isPrimary)
        if not IsValid(btn) then return btn end
        local radius = R:X(24)
        btn:SetTall(R:Y(56))
        btn:SetRadius(radius)
        btn:SetRipple(false)
        btn:SetGradient(false)
        btn.Paint = function(s, w, h)
            local hoverLerp = s._footerHoverLerp or 0
            local target = (s:IsHovered() or s:IsDown() or s.Depressed) and 1 or 0
            hoverLerp = Lerp(FrameTime() * 10, hoverLerp, target)
            s._footerHoverLerp = hoverLerp
            if isPrimary then
                _clrFooterFill.a = math.floor(Lerp(hoverLerp, clrFooterProceedFill.a, clrFooterProceedFillHover.a))
                RNDX().Rect(0, 0, w, h):Rad(radius):Color(_clrFooterFill):Draw()
                RNDX().Rect(0, 0, w, h):Rad(radius):Color(clrFooterProceedOutline):Outline(1):Draw()
                RNDX().Rect(R:X(1), R:Y(1), w - R:X(2), math.max(1, math.floor(h * 0.48))):Rad(radius):Color(clrFooterProceedShine):Draw()
            else
                _clrFooterCancel.r = math.floor(Lerp(hoverLerp, clrFooterCancel.r, clrFooterCancelHover.r))
                _clrFooterCancel.g = math.floor(Lerp(hoverLerp, clrFooterCancel.g, clrFooterCancelHover.g))
                _clrFooterCancel.b = math.floor(Lerp(hoverLerp, clrFooterCancel.b, clrFooterCancelHover.b))
                RNDX().Rect(0, 0, w, h):Rad(radius):Color(_clrFooterCancel):Draw()
            end

            draw.SimpleText(s.text or "", s.font or fontButtonText, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return btn
    end

    secondaryAction = vgui.Create("MantleBtn", footer)
    secondaryAction:SetSize(R:XY(245, 56))
    secondaryAction:SetPos(0, 0)
    secondaryAction:SetFont(fontButtonText)
    secondaryAction:SetColor(clrFooterCancel)
    secondaryAction:SetColorHover(clrFooterCancelHover)
    styleFooterActionButton(secondaryAction, false)
    function closeToPreviousMenu()
        characterCreateFrame:Close()
        if lockedFaction then
            CH:FactionSelect(slot)
        else
            CH:RequestList()
        end
    end

    primaryAction = vgui.Create("MantleBtn", footer)
    primaryAction:SetSize(R:XY(245, 56))
    primaryAction:SetFont(fontButtonText)
    primaryAction:SetColor(clrFooterProceedFill)
    primaryAction:SetColorHover(clrFooterProceedFillHover)
    styleFooterActionButton(primaryAction, true)
    footer.PerformLayout = function(s, w, h)
        if IsValid(secondaryAction) then secondaryAction:SetPos(0, 0) end
        if IsValid(primaryAction) then primaryAction:SetPos(math.max(0, w - primaryAction:GetWide()), 0) end
    end

    function requestCreateCharacter()
        local data = {
            slot = slot,
            job_id = cfg.DefaultJob or "citizen",
        }

        if CH:ConfigBool("EnableDescription", true) and IsValid(desc) then data.description = desc:GetValue() end
        if CH:ConfigBool("NicknameMode", true) then
            data.nickname = IsValid(nicknameEntry) and nicknameEntry:GetValue() or ""
        else
            data.firstname = IsValid(first) and first:GetValue() or ""
            data.lastname = IsValid(last) and last:GetValue() or ""
        end

        if CH:GenderEnabled() then data.gender = selectedGender end
        if CH:FactionsEnabled() then
            local fid = lockedFaction
            if not fid and IsValid(factionCombo) and factionCombo.GetSelectedData then fid = factionCombo:GetSelectedData() end
            data.faction = fid
        end

        if isstring(currentBodyModel) and currentBodyModel ~= "" then data.model = currentBodyModel end
        if CH:ConfigBool("EnableAge", false) and IsValid(ageSlider) then data.age = ageSlider:GetValue() end
        if IsValid(heightSlider) then data.height = heightSlider:GetValue() end
        data.skin_tone = appearanceState.skinTone
        if factionUsesSkinTonePicker() then
            local skinColor = cloneColor(appearanceState.skinColor, DEFAULT_SKIN_TONES[1])
            data.skin_color = ("%d,%d,%d,%d"):format(math.Clamp(math.floor(tonumber(skinColor.r) or 255), 0, 255), math.Clamp(math.floor(tonumber(skinColor.g) or 255), 0, 255), math.Clamp(math.floor(tonumber(skinColor.b) or 255), 0, 255), math.Clamp(math.floor(tonumber(skinColor.a) or 255), 0, 255))
        end

        data.body_style = appearanceState.bodyStyle
        if self.NormalizeBodyMarksData then data.body_marks = self:NormalizeBodyMarksData(data.faction, appearanceState.bodyMarks) end
        if self.NormalizeSpiritAccessory then data.spirit_accessory = self:NormalizeSpiritAccessory(data.faction, appearanceState.spiritAccessory) end
        if self.NormalizeSpiritAccessoryTransform then data.spirit_accessory_data = self:NormalizeSpiritAccessoryTransform(data.faction, data.spirit_accessory, appearanceState.spiritAccessoryData) end
        data.head_type = appearanceState.headType
        data.head_style = appearanceState.headStyle
        data.eyebrow_style = appearanceState.eyebrowStyle
        if appearanceState.eyebrowColorLinked ~= true then data.eyebrow_color = ("%d,%d,%d,%d"):format(math.Clamp(math.floor(tonumber(appearanceState.eyebrowColor.r) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.eyebrowColor.g) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.eyebrowColor.b) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.eyebrowColor.a) or 255), 0, 255)) end
        data.iris_style = appearanceState.irisStyle
        data.iris_size = appearanceState.irisSize
        if CH.NormalizeFlexTable then data.flex = CH:NormalizeFlexTable(appearanceState.flex) end
        data.hair_style = appearanceState.hairStyle
        data.hair_color = ("%d,%d,%d,%d"):format(math.Clamp(math.floor(tonumber(appearanceState.hairColor.r) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.hairColor.g) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.hairColor.b) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.hairColor.a) or 255), 0, 255))
        -- Dégradé : on n'envoie une couleur de pointes que si la case est cochée.
        -- Chaîne vide côté serveur = pas de dégradé (couleur unie).
        if appearanceState.hairGradientEnabled and IsColor(appearanceState.hairTipColor) then
            local tc = appearanceState.hairTipColor
            data.hair_tip_color = ("%d,%d,%d,%d"):format(math.Clamp(math.floor(tonumber(tc.r) or 255), 0, 255), math.Clamp(math.floor(tonumber(tc.g) or 255), 0, 255), math.Clamp(math.floor(tonumber(tc.b) or 255), 0, 255), math.Clamp(math.floor(tonumber(tc.a) or 255), 0, 255))
        else
            data.hair_tip_color = ""
        end
        data.eye_color = ("%d,%d,%d,%d"):format(math.Clamp(math.floor(tonumber(appearanceState.eyeColor.r) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.eyeColor.g) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.eyeColor.b) or 255), 0, 255), math.Clamp(math.floor(tonumber(appearanceState.eyeColor.a) or 255), 0, 255))
        local el = appearanceState.eyelashColor or Color(0, 0, 0, 255)
        data.eyelash_color = ("%d,%d,%d,%d"):format(math.Clamp(math.floor(tonumber(el.r) or 0), 0, 255), math.Clamp(math.floor(tonumber(el.g) or 0), 0, 255), math.Clamp(math.floor(tonumber(el.b) or 0), 0, 255), math.Clamp(math.floor(tonumber(el.a) or 255), 0, 255))
        CH:RequestCreate(data)
    end

    updateStepButtons = function()
        if IsValid(secondaryAction) then secondaryAction:SetTxt((currentStep > 1) and "Retour" or "Annuler") end
        if IsValid(primaryAction) then primaryAction:SetTxt((currentStep >= totalSteps) and "Terminer" or "Suivant") end
    end

    secondaryAction.DoClick = function()
        if currentStep > 1 then
            setCurrentStep(currentStep - 1)
            return
        end

        closeToPreviousMenu()
    end

    primaryAction.DoClick = function()
        if currentStep < totalSteps then
            setCurrentStep(currentStep + 1)
            return
        end

        requestCreateCharacter()
    end

    setCurrentStep(1)
    characterCreateFrame._cleanupPreview = cleanupPreview
    characterCreateFrame.OnClose = cleanupPreview
    characterCreateFrame.OnRemove = cleanupPreview
end