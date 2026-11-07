local BB = VERSE.Barbershop
local CH = VERSE.Characters
local R = VERSE.Responsive
local Font = VERSE.Fonts
local CLR_PANEL_BG = Color(18, 12, 28, 230)
local CLR_ACCENT = Color(180, 120, 230)
local CLR_BACK_BTN = Color(110, 70, 150, 230)
local CLR_SAVE_BTN = Color(170, 100, 220, 230)
local CLR_TEXT_SOFT = Color(200, 190, 225, 220)
local CLR_OK = Color(140, 240, 160)
local CLR_ERR = Color(240, 120, 120)
local DEFAULT_HAIR = Color(62, 44, 30)
local DEFAULT_EYEBROW = Color(55, 40, 28)
local DEFAULT_SKIN = Color(255, 244, 230)
local CHAR_CAM_FOV = 48
local CHAR_MDL_POS = Vector(5000, 5000, -35)
local CHAR_MDL_ANG = Angle(0, 180, 0)
local CHAR_CAM_ANG = Angle(2, 0, 0)
local CAMERA_LERP_RATE = 10
local PREVIEW_HEAD_BONE_CANDIDATES = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Head", "head", "Head", "mixamorig:Head", "bip_head"}
local function computeCamFromModel(mdlPos, mdlAng, dist, height)
    dist = dist or 86
    height = height or 52
    local fwd = Angle(0, mdlAng.y, 0):Forward()
    local camPos = mdlPos + fwd * dist + Vector(0, 0, height)
    local camAng = Angle(3, mdlAng.y + 180, 0)
    return camPos, camAng
end

local function getHeadFocusPositionForEnt(ent)
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

local barbershopFrame = nil
local function closeFrame()
    if IsValid(barbershopFrame) then
        if isfunction(barbershopFrame._cleanup) then pcall(barbershopFrame._cleanup) end
        barbershopFrame:Remove()
    end

    barbershopFrame = nil
end

local function parseColor(s, fallback)
    if IsColor(s) then return Color(s.r, s.g, s.b, s.a or 255) end
    if istable(s) and s.r and s.g and s.b then return Color(s.r, s.g, s.b, s.a or 255) end
    if isstring(s) and s ~= "" then
        local r, g, b, a = string.match(s, "^(%d+),(%d+),(%d+),?(%d*)$")
        if r then return Color(tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 255) end
    end
    return fallback or Color(255, 255, 255)
end

local function colorToString(c)
    if not IsColor(c) then return "" end
    return string.format("%d,%d,%d,%d", c.r or 255, c.g or 255, c.b or 255, c.a or 255)
end

local function rndx(radius, x, y, w, h, col)
    RNDX().Rect(x, y, w, h):Rad(radius):Color(col):Draw()
end

local function spawnMergedPart(parent, mdl)
    if not IsValid(parent) or not isstring(mdl) or mdl == "" then return nil end
    local ent = ClientsideModel(mdl)
    if not IsValid(ent) then return nil end
    ent:SetNoDraw(true)
    ent:SetPos(parent:GetPos())
    ent:SetAngles(parent:GetAngles())
    ent:SetParent(parent)
    ent:AddEffects(EF_BONEMERGE)
    ent:AddEffects(EF_BONEMERGE_FASTCULL)
    ent:AddEffects(EF_PARENT_ANIMATES)
    ent:SetLocalPos(vector_origin)
    ent:SetLocalAngles(angle_zero)
    ent:InvalidateBoneCache()
    ent:SetupBones()
    return ent
end

local function pickIdleSeqName()
    if CH and CH.GetIdlePool then
        local pool = CH:GetIdlePool() or {}
        for _, entry in ipairs(pool) do
            if isstring(entry.Sequence) then return entry.Sequence end
        end
    end
    return "idle_all_01"
end

netstream.Hook(BB.Net.Open, function(payload)
    if not istable(payload) then return end
    closeFrame()
    local cfg = CH and CH:GetConfig() or {}
    local factionCfg = istable(cfg.Factions) and cfg.Factions[payload.faction] or nil
    local categories = CH and CH.GetBodyMarkCategories and CH:GetBodyMarkCategories(payload.faction) or {}
    local state = {
        npc_ent = tonumber(payload.npc_ent) or 0,
        height = tonumber(payload.height) or 170,
        hair_style = tonumber(payload.hair_style) or 0,
        hair_model = tonumber(payload.hair_model) or 0,
        hair_color = parseColor(payload.hair_color, DEFAULT_HAIR),
        hair_tip_color = parseColor(payload.hair_tip_color, Color(170, 60, 220, 255)),
        hair_gradient = isstring(payload.hair_tip_color) and payload.hair_tip_color ~= "",
        eyebrow_style = tonumber(payload.eyebrow_style) or 1,
        eyebrow_color = parseColor(payload.eyebrow_color, DEFAULT_EYEBROW),
        eyebrow_linked = false,
        eyelash_color = parseColor(payload.eyelash_color, Color(0, 0, 0, 255)),
        body_marks = istable(payload.body_marks) and table.Copy(payload.body_marks) or {},
        body_marks_enabled = {},
        camera_focus = "body",
    }

    -- Résout la couleur de peau : skin_color explicite (faction spirit) sinon palette skin_tone
    local function resolveSkinColor()
        local sc = payload.skin_color
        if isstring(sc) and sc ~= "" then return parseColor(sc, DEFAULT_SKIN) end
        local idx = math.max(1, math.floor(tonumber(payload.skin_tone) or 1))
        local cfg = VERSE.Config and VERSE.Config.Characters
        local pal = istable(cfg) and cfg.SkinColorPalette or {}
        return pal[math.Clamp(idx, 1, math.max(1, #pal))] or DEFAULT_SKIN
    end

    if (payload.eyebrow_color or "") == "" or colorToString(state.eyebrow_color) == colorToString(state.hair_color) then
        state.eyebrow_linked = true
        state.eyebrow_color = Color(state.hair_color.r, state.hair_color.g, state.hair_color.b, 255)
    end

    for _, cat in ipairs(categories) do
        local ex = state.body_marks[cat.id]
        state.body_marks_enabled[cat.id] = (ex and ex.style and ex.style > 1) or false
    end

    local scrw, scrh = ScrW(), ScrH()
    barbershopFrame = vgui.Create("MantleFrame")
    barbershopFrame:SetSize(scrw, scrh)
    barbershopFrame:Center()
    barbershopFrame:SetDraggable(false)
    if barbershopFrame.LiteMode then barbershopFrame:LiteMode() end
    if barbershopFrame.SetAlphaBackground then barbershopFrame:SetAlphaBackground(false) end
    if barbershopFrame.SetClosable then barbershopFrame:SetClosable(false) end
    if barbershopFrame.DisableCloseBtn then barbershopFrame:DisableCloseBtn() end
    barbershopFrame:MakePopup()
    barbershopFrame.Paint = function(_, pw, ph)
        surface.SetDrawColor(8, 4, 14, 240)
        surface.DrawRect(0, 0, pw, ph)
    end

    local previewW = math.floor(scrw * 0.58)
    local previewH = scrh
    local ctx = CH and CH.__ClientCharacterContext or nil
    local syncBodyMarks = ctx and ctx.syncBodyMarkLayerSet
    local drawBodyMarks = ctx and ctx.drawBodyMarkLayerSet
    local preview = {
        csm = nil,
        headCSM = nil,
        hairCSM = nil,
        markEnts = {},
    }

    local viewPanel = vgui.Create("DModelPanel", barbershopFrame)
    viewPanel:SetPos(0, 0)
    viewPanel:SetSize(previewW, previewH)
    viewPanel:SetMouseInputEnabled(true)
    if viewPanel.SetPaintBackground then viewPanel:SetPaintBackground(false) end
    viewPanel:SetAnimated(true)
    viewPanel:SetAmbientLight(Color(78, 72, 96))
    viewPanel:SetDirectionalLight(BOX_FRONT, Color(218, 210, 226))
    viewPanel:SetDirectionalLight(BOX_RIGHT, Color(132, 128, 168))
    viewPanel:SetDirectionalLight(BOX_LEFT, Color(88, 76, 124))
    viewPanel:SetDirectionalLight(BOX_TOP, Color(188, 176, 208))
    viewPanel:SetDirectionalLight(BOX_BOTTOM, Color(44, 38, 60))
    local baseCamFov = (factionCfg and factionCfg.cam_fov) or CHAR_CAM_FOV
    local mdlPos = (factionCfg and factionCfg.mdl_pos) or CHAR_MDL_POS
    local baseMdlAng = (factionCfg and factionCfg.mdl_ang) or CHAR_MDL_ANG
    local camDist = (factionCfg and factionCfg.cam_dist) or 86
    local camHeight = (factionCfg and factionCfg.cam_height) or 52
    local yawOffset = 0
    local baseCamPos, baseCamAng
    if factionCfg and factionCfg.cam_pos then
        baseCamPos = factionCfg.cam_pos
        baseCamAng = factionCfg.cam_ang or CHAR_CAM_ANG
    else
        baseCamPos, baseCamAng = computeCamFromModel(mdlPos, baseMdlAng, camDist, camHeight)
    end

    local bodyModel = payload.body_model or LocalPlayer():GetModel()
    viewPanel:SetModel(bodyModel)
    preview.csm = viewPanel.Entity
    if IsValid(preview.csm) then
        preview.csm:SetNoDraw(false)
        if preview.csm.SetIK then preview.csm:SetIK(false) end
        preview.csm:SetPos(mdlPos)
        preview.csm:SetAngles(baseMdlAng)
        local idleName = pickIdleSeqName()
        local si = preview.csm:LookupSequence(idleName)
        if si and si >= 0 then preview.csm:ResetSequence(si) end
        preview.csm:SetCycle(0)
        preview.csm:SetupBones()
        local modelScale = tonumber(payload.model_scale) or 1
        preview.csm:SetModelScale(modelScale, 0)
        local headModel = payload.head_model or ""
        if headModel ~= "" then preview.headCSM = spawnMergedPart(preview.csm, headModel) end
        if IsValid(preview.headCSM) then preview.headCSM:SetModelScale(modelScale, 0) end
        local initHairMdlIdx = tonumber(payload.hair_model) or 0
        local initHairMdls = (CH and CH.HairModels) or {}
        if initHairMdlIdx > 0 and isstring(initHairMdls[initHairMdlIdx]) then
            preview.hairCSM = spawnMergedPart(preview.csm, initHairMdls[initHairMdlIdx])
        end
    end

    if CH and CH.HideBuiltInHeadBodygroups and IsValid(preview.headCSM) and IsValid(preview.csm) then CH.HideBuiltInHeadBodygroups(preview.csm) end
    local function applyBodygroups()
        if IsValid(preview.csm) then
            local bs = tonumber(payload.body_style) or 0
            if preview.csm.GetNumBodyGroups and preview.csm:GetNumBodyGroups() > 0 then preview.csm:SetBodygroup(0, bs) end
        end

        if IsValid(preview.headCSM) then
            preview.headCSM:SetBodygroup(0, tonumber(payload.head_style) or 0)
            if preview.headCSM.GetBodygroupCount and (preview.headCSM:GetBodygroupCount(1) or 0) > 0 then preview.headCSM:SetBodygroup(1, state.hair_style) end
        end
    end

    applyBodygroups()
    local camPos, camAng, camFov = baseCamPos, baseCamAng, baseCamFov
    local camTargetPos, camTargetAng, camTargetFov = baseCamPos, baseCamAng, baseCamFov
    local function refreshCameraTarget()
        camTargetPos = baseCamPos
        camTargetAng = baseCamAng
        camTargetFov = baseCamFov
        local focus = state.camera_focus or "body"
        if focus == "body" then return end
        local focusPos = getHeadFocusPositionForEnt(preview.csm)
        if not isvector(focusPos) then return end
        local viewBasis = Angle(0, baseMdlAng.y, 0)
        local fwd = viewBasis:Forward()
        local up = viewBasis:Up()
        local isHeadFocus = focus == "hair" or focus == "head"
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
    end

    refreshCameraTarget()
    camPos, camAng, camFov = camTargetPos, camTargetAng, camTargetFov
    local function resyncMarks()
        if not syncBodyMarks or not IsValid(preview.headCSM) then return end
        if not CH or not CH.GetResolvedBodyMarks then return end
        local filtered = {}
        for id, e in pairs(state.body_marks or {}) do
            if state.body_marks_enabled[id] then filtered[id] = e end
        end

        local resolved = CH:GetResolvedBodyMarks(payload.faction, filtered)
        preview.markEnts = syncBodyMarks(preview.headCSM, preview.markEnts, resolved, "barbershop_preview")
    end

    resyncMarks()
    viewPanel.LayoutEntity = function(_, ent)
        if not IsValid(ent) then return end
        ent:FrameAdvance(FrameTime())
        ent:SetPos(mdlPos)
        ent:SetAngles(Angle(baseMdlAng.p, baseMdlAng.y + yawOffset, baseMdlAng.r))
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
        viewPanel:SetFOV(camFov)
        viewPanel:SetCamPos(camPos)
        viewPanel:SetLookAt(camPos + (camAng:Forward() * 256))
    end

    viewPanel.PreDrawModel = function(_, ent)
        if not IsValid(ent) then return end
        if CH and CH.SetEntitySkinColorRuntime then CH.SetEntitySkinColorRuntime(ent, resolveSkinColor()) end
    end

    viewPanel.PostDrawModel = function(s)
        if IsValid(preview.headCSM) then
            if CH and CH.SetEntitySkinColorRuntime then CH.SetEntitySkinColorRuntime(preview.headCSM, resolveSkinColor()) end
            if state.hair_gradient and CH and CH.SetEntityHairGradient then
                CH.SetEntityHairGradient(preview.headCSM, state.hair_tip_color, state.hair_color)
            elseif CH and CH.SetEntityHairColor then
                CH.SetEntityHairColor(preview.headCSM, state.hair_color)
            end
            if CH and CH.SetEntityEyebrowColor then CH.SetEntityEyebrowColor(preview.headCSM, state.eyebrow_color) end
            if CH and CH.SetEntityEyelashColor then CH.SetEntityEyelashColor(preview.headCSM, state.eyelash_color or Color(0, 0, 0, 255)) end
            if CH and CH.SetEntityIris then CH.SetEntityIris(preview.headCSM, tonumber(payload.iris_style) or 1, tonumber(payload.iris_size) or 100, parseColor(payload.eye_color, color_white)) end
            if CH and CH.ApplyFlex and payload.flex then CH.ApplyFlex(preview.headCSM, payload.flex) end
            preview.headCSM:DrawModel()
            if drawBodyMarks and preview.markEnts then drawBodyMarks(preview.markEnts) end
        end

        if IsValid(preview.hairCSM) then
            if state.hair_gradient and CH and CH.SetEntityHairGradient then
                CH.SetEntityHairGradient(preview.hairCSM, state.hair_tip_color, state.hair_color)
            elseif CH and CH.SetEntityHairColor then
                CH.SetEntityHairColor(preview.hairCSM, state.hair_color)
            end
            preview.hairCSM:DrawModel()
        end
    end

    viewPanel.OnMousePressed = function(s, mcode)
        if mcode ~= MOUSE_LEFT or not IsValid(preview.csm) then return end
        s._dragRotate = true
        s._dragStartX = s:CursorPos()
        s._dragStartYaw = yawOffset
        s:MouseCapture(true)
    end

    viewPanel.OnMouseReleased = function(s, mcode)
        if mcode ~= MOUSE_LEFT or not s._dragRotate then return end
        s._dragRotate = false
        s:MouseCapture(false)
    end

    viewPanel.OnCursorMoved = function(s, x, _)
        if not s._dragRotate or not IsValid(preview.csm) then return end
        local startX = tonumber(s._dragStartX) or x
        local startYaw = tonumber(s._dragStartYaw) or 0
        yawOffset = startYaw + ((x - startX) * 0.35)
        preview.csm:SetAngles(Angle(baseMdlAng.p, baseMdlAng.y + yawOffset, baseMdlAng.r))
    end

    barbershopFrame._cleanup = function()
        if preview.markEnts then
            for key, ent in pairs(preview.markEnts) do
                if TypeID(ent) == TYPE_ENTITY and IsValid(ent) then ent:Remove() end
                preview.markEnts[key] = nil
            end
        end

        if IsValid(preview.headCSM) then preview.headCSM:Remove() end
        preview.headCSM = nil
        if IsValid(preview.hairCSM) then preview.hairCSM:Remove() end
        preview.hairCSM = nil
    end

    local function onAppearanceChanged(focus)
        if focus then state.camera_focus = focus end
        refreshCameraTarget()
        applyBodygroups()
        resyncMarks()
    end

    local rightW = math.floor(scrw * 0.36)
    local rightX = scrw - rightW - math.floor(scrw * 0.02)
    local rightY = math.floor(scrh * 0.05)
    local rightH = math.floor(scrh * 0.90)
    local rightPanel = vgui.Create("DPanel", barbershopFrame)
    rightPanel:SetPos(rightX, rightY)
    rightPanel:SetSize(rightW, rightH)
    rightPanel.Paint = function(_, pw, ph) rndx(R:Y(14), 0, 0, pw, ph, CLR_PANEL_BG) end
    local headerH = R:Y(100)
    local header = vgui.Create("DPanel", rightPanel)
    header:SetPos(0, 0)
    header:SetSize(rightW, headerH)
    header.Paint = function(_, pw, ph)
        draw.SimpleText("BARBERSHOP", Font:GetNamed("Poppins", "Bold", 42), R:X(32), R:Y(24), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Édition de l'apparence", Font:GetNamed("Poppins", "Medium", 18), R:X(34), R:Y(70), CLR_TEXT_SOFT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local footerH = R:Y(80)
    local footerPad = R:X(24)
    local footer = vgui.Create("DPanel", rightPanel)
    footer:SetPos(0, rightH - footerH)
    footer:SetSize(rightW, footerH)
    footer.Paint = function() end
    local backBtn = vgui.Create("MantleBtn", footer)
    backBtn:SetSize(math.floor((rightW - footerPad * 3) * 0.45), R:Y(48))
    backBtn:SetPos(footerPad, (footerH - R:Y(48)) * 0.5)
    if backBtn.SetTxt then backBtn:SetTxt("Retour") end
    if backBtn.SetRadius then backBtn:SetRadius(R:Y(10)) end
    if backBtn.SetColor then backBtn:SetColor(CLR_BACK_BTN) end
    if backBtn.SetColorHover then backBtn:SetColorHover(Color(140, 90, 190, 240)) end
    backBtn.DoClick = closeFrame
    local saveBtn = vgui.Create("MantleBtn", footer)
    saveBtn:SetSize(math.floor((rightW - footerPad * 3) * 0.45), R:Y(48))
    saveBtn:SetPos(rightW - footerPad - saveBtn:GetWide(), (footerH - R:Y(48)) * 0.5)
    if saveBtn.SetTxt then saveBtn:SetTxt("Enregistrer") end
    if saveBtn.SetRadius then saveBtn:SetRadius(R:Y(10)) end
    if saveBtn.SetColor then saveBtn:SetColor(CLR_SAVE_BTN) end
    if saveBtn.SetColorHover then saveBtn:SetColorHover(Color(210, 140, 240, 245)) end
    saveBtn.DoClick = function()
        local marksPayload = {}
        for id, e in pairs(state.body_marks) do
            if state.body_marks_enabled[id] then
                marksPayload[id] = e
            else
                marksPayload[id] = {
                    style = 1,
                    x = 0,
                    y = 0,
                    size = 24,
                    rotate = 0,
                    opacity = 100,
                    color = ""
                }
            end
        end

        netstream.Start(BB.Net.Save, {
            npc_ent = state.npc_ent,
            height = state.height,
            hair_style = state.hair_style,
            hair_model = state.hair_model,
            hair_color = colorToString(state.hair_color),
            hair_tip_color = state.hair_gradient and colorToString(state.hair_tip_color) or "",
            eyebrow_style = state.eyebrow_style,
            eyebrow_color = colorToString(state.eyebrow_color),
            eyelash_color = colorToString(state.eyelash_color or Color(0, 0, 0, 255)),
            body_marks = marksPayload,
        })
    end

    local scroll = vgui.Create("DScrollPanel", rightPanel)
    scroll:SetPos(R:X(28), headerH)
    scroll:SetSize(rightW - R:X(56), rightH - headerH - footerH - R:Y(16))
    local sbar = scroll:GetVBar()
    if IsValid(sbar) then
        sbar:SetWide(R:X(5))
        local _sbarCol = Color(40, 28, 60, 160)
        sbar.Paint = function(_, pw, ph) rndx(R:Y(3), 0, 0, pw, ph, _sbarCol) end
        sbar.btnGrip.Paint = function(_, pw, ph) rndx(R:Y(3), 0, 0, pw, ph, CLR_ACCENT) end
        sbar.btnUp.Paint = function() end
        sbar.btnDown.Paint = function() end
    end

    local function addSectionLabel(text)
        local lbl = vgui.Create("DLabel", scroll)
        lbl:Dock(TOP)
        lbl:DockMargin(0, R:Y(18), 0, R:Y(8))
        lbl:SetTall(R:Y(34))
        lbl:SetText(text)
        lbl:SetFont(Font:GetNamed("Poppins", "Bold", 24))
        lbl:SetTextColor(color_white)
    end

    local function addSlider(label, minV, maxV, init, onChange)
        local sld = vgui.Create("MantleSlideBox", scroll)
        sld:Dock(TOP)
        sld:DockMargin(0, R:Y(6), 0, R:Y(14))
        sld:SetTall(R:Y(76))
        if sld.SetText then sld:SetText(label) end
        if sld.SetRange then sld:SetRange(minV, maxV, 0) end
        if sld.SetValue then sld:SetValue(tonumber(init) or minV, true) end
        sld.OnValueChanged = function(_, v) if onChange then onChange(math.floor(v)) end end
        return sld
    end

    local function addCheckbox(label, init, onChange)
        local cb = vgui.Create("MantleCheckBox", scroll)
        cb:Dock(TOP)
        cb:DockMargin(0, R:Y(4), 0, R:Y(6))
        cb:SetTall(R:Y(36))
        if cb.SetTxt then cb:SetTxt(label) end
        if cb.SetValue then cb:SetValue(init and true or false) end
        cb.OnChange = function(_, v) if onChange then onChange(v) end end
        return cb
    end

    local function addColorButton(label, initColor, onChange)
        local btn = vgui.Create("MantleBtn", scroll)
        btn:Dock(TOP)
        btn:DockMargin(0, R:Y(4), 0, R:Y(8))
        btn:SetTall(R:Y(44))
        if btn.SetTxt then btn:SetTxt(label) end
        if btn.SetRadius then btn:SetRadius(R:Y(8)) end
        btn._col = initColor or Color(255, 255, 255)
        if btn.SetColor then btn:SetColor(Color(40, 28, 60, 220)) end
        if btn.SetColorHover then btn:SetColorHover(Color(60, 40, 90, 240)) end
        local basePaint = btn.Paint
        btn.Paint = function(s, pw, ph)
            if basePaint then basePaint(s, pw, ph) end
            rndx(R:Y(4), pw - R:X(60), R:Y(10), R:X(48), ph - R:Y(20), s._col)
        end

        btn.DoClick = function(s)
            if Mantle and Mantle.ui and Mantle.ui.color_picker then
                Mantle.ui.color_picker(function(nc)
                    s._col = Color(nc.r, nc.g, nc.b, 255)
                    if onChange then onChange(s._col) end
                end, s._col)
            end
        end
        return btn
    end

    -- ─── Silhouette ──────────────────────────────────────────────────────────────
    addSectionLabel("Silhouette")
    local heightMin = (CH and CH.ConfigInt and CH:ConfigInt("HeightMin", 140)) or 140
    local heightMax = (CH and CH.ConfigInt and CH:ConfigInt("HeightMax", 220)) or 220
    addSlider("Taille (cm)", heightMin, heightMax, state.height, function(v)
        state.height = v
        if IsValid(preview.csm) then
            local scale = (CH and CH.GetHeightScale and CH:GetHeightScale(v)) or 1
            preview.csm:SetModelScale(scale, 0)
            if IsValid(preview.headCSM) then preview.headCSM:SetModelScale(scale, 0) end
        end
    end)

    addSectionLabel("Cheveux")
    local hairMax = 0
    if IsValid(preview.headCSM) and preview.headCSM.GetBodygroupCount then
        hairMax = math.max(0, (tonumber(preview.headCSM:GetBodygroupCount(1)) or 1) - 1)
    end
    if hairMax <= 0 then hairMax = 10 end

    local eyebrowColorBtn = nil
    local function updateEyebrowColorBtnVisual()
        if not IsValid(eyebrowColorBtn) then return end
        eyebrowColorBtn._col = Color(state.eyebrow_color.r, state.eyebrow_color.g, state.eyebrow_color.b, 255)
    end

    local function setEyebrowLinked(on, refresh)
        state.eyebrow_linked = on and true or false
        if state.eyebrow_linked then
            state.eyebrow_color = Color(state.hair_color.r, state.hair_color.g, state.hair_color.b, 255)
            updateEyebrowColorBtnVisual()
            if IsValid(eyebrowColorBtn) then eyebrowColorBtn:SetVisible(false) end
        else
            if IsValid(eyebrowColorBtn) then eyebrowColorBtn:SetVisible(true) end
        end

        if IsValid(scroll) then scroll:InvalidateLayout(true) end
        if refresh then onAppearanceChanged("face") end
    end

    addSlider("Style des cheveux", 0, hairMax, state.hair_style, function(v)
        state.hair_style = v
        onAppearanceChanged("hair")
    end)

    local _hairMdls = (CH and CH.HairModels) or {}
    if #_hairMdls > 0 then
        addSlider("Modèle de coupe (0 = aucun)", 0, #_hairMdls, state.hair_model, function(v)
            state.hair_model = v
            if IsValid(preview.hairCSM) then preview.hairCSM:Remove(); preview.hairCSM = nil end
            if v > 0 and isstring(_hairMdls[v]) and IsValid(preview.csm) then
                preview.hairCSM = spawnMergedPart(preview.csm, _hairMdls[v])
            end
            onAppearanceChanged("hair")
        end)
    end

    addColorButton("Couleur des cheveux", state.hair_color, function(c)
        state.hair_color = c
        if state.eyebrow_linked then
            state.eyebrow_color = Color(c.r, c.g, c.b, 255)
            updateEyebrowColorBtnVisual()
        end

        onAppearanceChanged("hair")
    end)

    -- Dégradé : case à cocher + couleur des pointes (racines = couleur des cheveux ci-dessus).
    local hairTipBtn = nil
    local function setHairGradient(on, refresh)
        state.hair_gradient = on and true or false
        if IsValid(hairTipBtn) then hairTipBtn:SetVisible(state.hair_gradient) end
        if IsValid(scroll) then scroll:InvalidateLayout(true) end
        if refresh then onAppearanceChanged("hair") end
    end

    addCheckbox("Dégradé de cheveux", state.hair_gradient, function(on) setHairGradient(on, true) end)

    hairTipBtn = addColorButton("Couleur des pointes", state.hair_tip_color, function(c)
        state.hair_tip_color = c
        state.hair_gradient = true
        onAppearanceChanged("hair")
    end)
    if not state.hair_gradient and IsValid(hairTipBtn) then hairTipBtn:SetVisible(false) end

    addSectionLabel("Sourcils")
    local ebMax = (CH and CH.GetEyebrowStyleCount and CH:GetEyebrowStyleCount()) or 1
    if ebMax > 1 then
        addSlider("Style des sourcils", 1, ebMax, state.eyebrow_style, function(v)
            state.eyebrow_style = v
            onAppearanceChanged("face")
        end)
    end

    eyebrowColorBtn = addColorButton("Couleur des sourcils", state.eyebrow_color, function(c)
        state.eyebrow_color = c
        onAppearanceChanged("face")
    end)

    addCheckbox("Assortir à la couleur des cheveux", state.eyebrow_linked, function(on) setEyebrowLinked(on, true) end)

    addSectionLabel("Cils")
    addColorButton("Couleur des cils", state.eyelash_color or Color(0, 0, 0, 255), function(c)
        state.eyelash_color = c
        onAppearanceChanged("face")
    end)
    if state.eyebrow_linked and IsValid(eyebrowColorBtn) then eyebrowColorBtn:SetVisible(false) end
    if #categories > 0 then
        addSectionLabel("Marques")
        for idx, cat in ipairs(categories) do
            local entry = state.body_marks[cat.id] or {
                style = cat.default or 1,
                x = 0,
                y = 0,
                size = 24,
                rotate = 0,
                opacity = 100,
                color = ""
            }

            state.body_marks[cat.id] = entry
            local function setField(k, v)
                entry[k] = v
                state.body_marks[cat.id] = entry
            end

            local catName = cat.name or cat.id
            local catControls = {}
            local function setCatControlsVisible(vis)
                for _, c in ipairs(catControls) do
                    if IsValid(c) then c:SetVisible(vis) end
                end

                if IsValid(scroll) then scroll:InvalidateLayout(true) end
            end

            addCheckbox("Activer " .. tostring(idx) .. " (" .. catName .. ")", state.body_marks_enabled[cat.id], function(on)
                state.body_marks_enabled[cat.id] = on
                if on and entry.style <= 1 and #(cat.options or {}) > 1 then setField("style", 2) end
                setCatControlsVisible(on)
                onAppearanceChanged("marks")
            end)

            local maxStyle = math.max(1, #(cat.options or {}))
            table.insert(catControls, addSlider(catName, 1, maxStyle, entry.style or 1, function(v)
                setField("style", v)
                onAppearanceChanged("marks")
            end))

            table.insert(catControls, addSlider(catName .. " Haut/Bas", -300, 300, entry.y or 0, function(v)
                setField("y", v)
                onAppearanceChanged("marks")
            end))

            table.insert(catControls, addSlider(catName .. " Gauche/Droite", -300, 300, entry.x or 0, function(v)
                setField("x", v)
                onAppearanceChanged("marks")
            end))

            table.insert(catControls, addSlider(catName .. " Taille", -50, 50, entry.size or 24, function(v)
                setField("size", v)
                setField("size_x", v)
                setField("size_y", v)
                onAppearanceChanged("marks")
            end))

            table.insert(catControls, addSlider(catName .. " Rotation", 0, 360, entry.rotate or 0, function(v)
                setField("rotate", v)
                onAppearanceChanged("marks")
            end))

            table.insert(catControls, addSlider(catName .. " Opacité", 0, 100, entry.opacity or 100, function(v)
                setField("opacity", v)
                onAppearanceChanged("marks")
            end))

            table.insert(catControls, addColorButton("Couleur " .. tostring(idx), parseColor(entry.color, Color(0, 0, 0)), function(c)
                setField("color", string.format("%d,%d,%d", c.r, c.g, c.b))
                onAppearanceChanged("marks")
            end))

            setCatControlsVisible(state.body_marks_enabled[cat.id] == true)
        end
    end
end)

netstream.Hook(BB.Net.Result, function(ok, err)
    if ok then
        chat.AddText(CLR_OK, "[Barbershop] Apparence enregistrée.")
        closeFrame()
    else
        chat.AddText(CLR_ERR, "[Barbershop] Erreur : " .. tostring(err or "unknown"))
    end
end)