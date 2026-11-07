VERSE.ModelView = VERSE.ModelView or {}
local MV = VERSE.ModelView
MV._items = MV._items or {}
local DEFAULT_HEAD = {
    enabled = false,
    bone = "ValveBiped.Bip01_Head1",
    distance = 13,
    upOffset = 2,
    sideOffset = 0,
    fov = 28,
    round = 10,
}

local HEAD_BONE_CANDIDATES = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Head", "head", "Head", "mixamorig:Head", "bip_head"}
local DEFAULT_SKIN_PALETTE = {Color(255, 244, 230), Color(240, 220, 198), Color(223, 196, 168), Color(192, 156, 126), Color(150, 113, 86), Color(105, 75, 58),}
local DEFAULT_HAIR_COLOR = Color(62, 44, 30)
local DEFAULT_EYE_COLOR = Color(255, 255, 255)
local FACE_MATERIAL_SLOT_CACHE = {}
local FACE_EYEBROW_RUNTIME_MATERIALS = {}
local FACE_EYE_RUNTIME_MATERIALS = {}
local function clamp_round(w, h, r)
    return math.max(0, math.min(r or 0, math.floor(math.min(w, h) / 2)))
end

local function LerpVectorFast(t, a, b)
    return Vector(Lerp(t, a.x, b.x), Lerp(t, a.y, b.y), Lerp(t, a.z, b.z))
end

local function LerpAngleFast(t, a, b)
    return Angle(Lerp(t, a.p, b.p), Lerp(t, a.y, b.y), Lerp(t, a.r, b.r))
end

local CP = VERSE.CharacterPreview
local function clone_color_safe(value, fallback)
    if IsColor(value) then return Color(value.r, value.g, value.b, value.a or 255) end
    if istable(value) and value.r and value.g and value.b then return Color(tonumber(value.r) or 255, tonumber(value.g) or 255, tonumber(value.b) or 255, tonumber(value.a) or 255) end
    local fb = fallback or color_white
    return Color(fb.r, fb.g, fb.b, fb.a or 255)
end

local function parse_color_string(value, fallback)
    if CP and CP.ParseColor then return CP.ParseColor(value, fallback or DEFAULT_HAIR_COLOR) end
    if IsColor(value) or (istable(value) and value.r and value.g and value.b) then return clone_color_safe(value, fallback) end
    if isstring(value) and value ~= "" then
        local r, g, b, a = string.match(value, "^(%d+),(%d+),(%d+),?(%d*)$")
        if r and g and b then return Color(math.Clamp(tonumber(r) or 255, 0, 255), math.Clamp(tonumber(g) or 255, 0, 255), math.Clamp(tonumber(b) or 255, 0, 255), math.Clamp(tonumber(a) or 255, 0, 255)) end
    end
    return clone_color_safe(fallback or DEFAULT_HAIR_COLOR, DEFAULT_HAIR_COLOR)
end

local function normalize_appearance_model_path(mdl)
    mdl = string.Trim(tostring(mdl or ""))
    if mdl == "" then return "" end
    return string.lower(string.gsub(mdl, "\\", "/"))
end

local function is_face_control_model(mdl)
    local characters = VERSE.Characters
    if characters and characters.HasFaceMaterialControls then return characters:HasFaceMaterialControls(mdl) end
    local path = normalize_appearance_model_path(mdl)
    return path == "models/verse/head/base_head1.mdl" or path == "models/verse/head/base_head10.mdl"
end

local function get_eyebrow_material_path(style)
    local characters = VERSE.Characters
    if characters and characters.GetEyebrowMaterialPath then return characters:GetEyebrowMaterialPath(style) end
    local materials = characters and characters.FaceEyebrowMaterials or nil
    if not istable(materials) or #materials <= 0 then return "" end
    local index = math.Clamp(math.floor(tonumber(style) or 1), 1, #materials)
    return tostring(materials[index] or materials[1] or "")
end

local function get_eye_material_path(style)
    local characters = VERSE.Characters
    if characters and characters.GetEyeMaterialPath then return characters:GetEyeMaterialPath(style) end
    local materials = characters and characters.FaceEyeMaterials or nil
    if not istable(materials) or #materials <= 0 then return "" end
    local index = math.Clamp(math.floor(tonumber(style) or 1), 1, #materials)
    return tostring(materials[index] or materials[1] or "")
end

local function normalize_material_path(matName)
    matName = string.Trim(tostring(matName or ""))
    if matName == "" then return "" end
    matName = string.lower(tostring(matName or ""))
    matName = string.gsub(matName, "\\", "/")
    matName = string.gsub(matName, "%.vmt$", "")
    matName = string.gsub(matName, "%.vtf$", "")
    if string.sub(matName, 1, 10) == "materials/" then matName = string.sub(matName, 11) end
    return matName
end

local function normalize_material_path_raw(matName)
    matName = string.Trim(tostring(matName or ""))
    if matName == "" then return "" end
    matName = string.gsub(matName, "\\", "/")
    matName = string.gsub(matName, "%.vmt$", "")
    matName = string.gsub(matName, "%.vtf$", "")
    if string.sub(string.lower(matName), 1, 10) == "materials/" then matName = string.sub(matName, 11) end
    return matName
end

local FACE_MATERIAL_CLASS_CACHE = {}
local function classify_face_material_kind(matName)
    local rawName = normalize_material_path_raw(matName)
    local normalizedName = normalize_material_path(rawName)
    if normalizedName == "" then return false, false end
    local cached = FACE_MATERIAL_CLASS_CACHE[normalizedName]
    if cached then return cached.isEye, cached.isEyebrow end
    local isEye = string.find(normalizedName, "/eyes", 1, true) ~= nil or string.find(normalizedName, "eyes", 1, true) ~= nil
    local isEyebrow = string.find(normalizedName, "/eyebrow", 1, true) ~= nil or string.find(normalizedName, "eyebrow", 1, true) ~= nil
    if not isEye or not isEyebrow then
        local mat = Material(rawName)
        if (not mat or mat:IsError()) and rawName ~= normalizedName then mat = Material(normalizedName) end
        if mat and not mat:IsError() and mat.GetTexture then
            local baseTex = mat:GetTexture("$basetexture")
            local baseTexName = baseTex and baseTex.GetName and normalize_material_path(baseTex:GetName()) or ""
            if baseTexName ~= "" then
                if not isEye then isEye = string.find(baseTexName, "/eyes", 1, true) ~= nil or string.find(baseTexName, "eyes", 1, true) ~= nil end
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

local function is_eye_material(matName)
    local isEye = classify_face_material_kind(matName)
    return isEye == true
end

local function is_eyebrow_material(matName)
    local _, isEyebrow = classify_face_material_kind(matName)
    return isEyebrow == true
end

local function is_skin_material(matName)
    matName = normalize_material_path(matName)
    if matName == "" then return false end
    if is_eye_material(matName) or is_eyebrow_material(matName) then return false end
    if string.find(matName, "slayde_jjk/face/", 1, true) ~= nil then return true end
    if string.find(matName, "slayde_jjk/base/peau_", 1, true) ~= nil then return true end
    if string.find(matName, "peau", 1, true) ~= nil then return true end
    if string.match(matName, "^face_%d+$") ~= nil then return true end
    if string.find(matName, "_skin", 1, true) ~= nil then return true end
    return false
end

local function set_entity_tint(ent, color, matcher)
    if CP and CP.TintEntity then return CP.TintEntity(ent, color, matcher) end
    if not IsValid(ent) or not IsColor(color) then return end
    local vec = Vector(color.r / 255, color.g / 255, color.b / 255)
    for _, matName in ipairs(ent:GetMaterials() or {}) do
        if not matcher or matcher(matName) then
            local mat = Material(matName)
            if mat and not mat:IsError() then mat:SetVector("$color2", vec) end
        end
    end
end

local function get_face_material_slot(ent, slotKey, matcher)
    if not IsValid(ent) then return nil end
    local characters = VERSE.Characters
    local modelPath = ent:GetModel()
    local normalizedModelPath = normalize_appearance_model_path(modelPath)
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

    local byModel = characters and characters.FaceMaterialSlots and characters.FaceMaterialSlots[normalizedModelPath] or nil
    local rawSlot = istable(byModel) and byModel[slotKey] or nil
    if istable(rawSlot) then
        for _, candidate in ipairs(rawSlot) do
            pushConfiguredSlot(candidate)
        end
    else
        pushConfiguredSlot(rawSlot)
    end

    if #configuredSlots <= 0 and characters and characters.GetFaceMaterialSlot then pushConfiguredSlot(characters:GetFaceMaterialSlot(modelPath, slotKey)) end
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

local reset_face_feature_tint
local function set_face_skin_tint(ent, color)
    if not IsValid(ent) or not IsColor(color) then return end
    local vec = Vector(color.r / 255, color.g / 255, color.b / 255)
    local eyeSlot = get_face_material_slot(ent, "eyes", is_eye_material)
    local eyebrowSlot = get_face_material_slot(ent, "eyebrow", is_eyebrow_material)
    for idx, matName in ipairs(ent:GetMaterials() or {}) do
        local slotIndex = idx - 1
        if slotIndex ~= eyeSlot and slotIndex ~= eyebrowSlot and is_skin_material(matName) then
            local mat = Material(matName)
            if mat and not mat:IsError() then mat:SetVector("$color2", vec) end
        end
    end

    reset_face_feature_tint(ent)
end

local function set_face_slot_direct_tint(ent, slotKey, matcher, color)
    if not IsValid(ent) or not IsColor(color) then return end
    local slotIndex = get_face_material_slot(ent, slotKey, matcher)
    if slotIndex == nil then return end
    local materials = ent.GetMaterials and ent:GetMaterials() or nil
    local matName = istable(materials) and materials[slotIndex + 1] or nil
    if not isstring(matName) or matName == "" then return end
    local rawName = normalize_material_path_raw(matName)
    local normalizedName = normalize_material_path(rawName)
    local mat = Material(rawName)
    if (not mat or mat:IsError()) and rawName ~= normalizedName then mat = Material(normalizedName) end
    if not mat or mat:IsError() then return end
    mat:SetVector("$color2", Vector(color.r / 255, color.g / 255, color.b / 255))
end

reset_face_feature_tint = function(ent)
    if not IsValid(ent) or not is_face_control_model(ent:GetModel()) then return end
    set_face_slot_direct_tint(ent, "eyes", is_eye_material, color_white)
    set_face_slot_direct_tint(ent, "eyebrow", is_eyebrow_material, color_white)
end

local function apply_eyebrow_material(ent, style)
    if not IsValid(ent) or not ent.SetSubMaterial or not is_face_control_model(ent:GetModel()) then return end
    local slotIndex = get_face_material_slot(ent, "eyebrow", is_eyebrow_material)
    if slotIndex == nil then return end
    local characters = VERSE.Characters
    local maxStyle = (characters and characters.GetEyebrowStyleCount and characters:GetEyebrowStyleCount()) or 1
    style = math.Clamp(math.floor(tonumber(style) or 1), 1, maxStyle)
    if style <= 1 then
        ent:SetSubMaterial(slotIndex, "")
        return
    end

    local texturePath = get_eyebrow_material_path(style)
    if texturePath == "" then
        ent:SetSubMaterial(slotIndex, "")
        return
    end

    local runtimeMat = FACE_EYEBROW_RUNTIME_MATERIALS[style]
    if not runtimeMat then
        local runtimeName = ("verse__modelview__eyebrow_variant_%d"):format(style)
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

local function get_active_eyebrow_material(style)
    local characters = VERSE.Characters
    local maxStyle = (characters and characters.GetEyebrowStyleCount and characters:GetEyebrowStyleCount()) or 1
    style = math.Clamp(math.floor(tonumber(style) or 1), 1, maxStyle)
    if style <= 1 then
        local mat = Material("slayde_jjk/face/eyebrow")
        if mat and not mat:IsError() then return mat end
        return nil
    end

    local runtimeMat = FACE_EYEBROW_RUNTIME_MATERIALS[style]
    if runtimeMat and not runtimeMat:IsError() then return runtimeMat end
    return nil
end

local function set_eyebrow_tint(style, color)
    if not IsColor(color) then return end
    local mat = get_active_eyebrow_material(style)
    if not mat then return end
    mat:SetVector("$color2", Vector(color.r / 255, color.g / 255, color.b / 255))
end

local function apply_eye_material(ent, style)
    if not IsValid(ent) or not ent.SetSubMaterial or not is_face_control_model(ent:GetModel()) then return end
    local slotIndex = get_face_material_slot(ent, "eyes", is_eye_material)
    if slotIndex == nil then return end
    local characters = VERSE.Characters
    local maxStyle = (characters and characters.GetEyeStyleCount and characters:GetEyeStyleCount()) or 1
    style = math.Clamp(math.floor(tonumber(style) or 1), 1, maxStyle)
    if style <= 1 then
        ent:SetSubMaterial(slotIndex, "")
        return
    end

    local texturePath = get_eye_material_path(style)
    if texturePath == "" then
        ent:SetSubMaterial(slotIndex, "")
        return
    end

    local runtimeMat = FACE_EYE_RUNTIME_MATERIALS[style]
    if not runtimeMat then
        local runtimeName = ("verse__modelview__eye_variant_%d"):format(style)
        runtimeMat = CreateMaterial(runtimeName, "VertexLitGeneric", {
            ["$model"] = 1,
            ["$basetexture"] = texturePath,
            ["$lightwarptexture"] = "slayde_jjk/shared/lightwarpshader",
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1,
            ["$color2"] = "[1 1 1]",
        })

        FACE_EYE_RUNTIME_MATERIALS[style] = runtimeMat
    end

    if runtimeMat and not runtimeMat:IsError() then
        runtimeMat:SetVector("$color2", Vector(1, 1, 1))
        ent:SetSubMaterial(slotIndex, "!" .. runtimeMat:GetName())
    else
        ent:SetSubMaterial(slotIndex, "")
    end
end

local function apply_entity_bodygroups(ent, bodygroups)
    if not IsValid(ent) or not istable(bodygroups) then return end
    if not ent.GetNumBodyGroups or not ent.GetBodygroupCount then return end
    for rawGroup, rawValue in pairs(bodygroups) do
        local groupId = tonumber(rawGroup) or 0
        if ent:GetNumBodyGroups() > groupId then
            local count = tonumber(ent:GetBodygroupCount(groupId)) or 0
            local maxValue = math.max(0, count - 1)
            local safeValue = math.Clamp(math.floor(tonumber(rawValue) or 0), 0, maxValue)
            local characters = VERSE.Characters
            if characters and characters.NormalizeBodygroupValue then safeValue = characters:NormalizeBodygroupValue(ent:GetModel(), groupId, safeValue, maxValue) end
            ent:SetBodygroup(groupId, safeValue)
        end
    end
end

local function build_skin_palette()
    if CP and CP.GetSkinPalette then return CP.GetSkinPalette() end
    local cfg = VERSE.Config and VERSE.Config.Characters or nil
    local configured = cfg and cfg.SkinColorPalette or nil
    if not istable(configured) or #configured == 0 then return DEFAULT_SKIN_PALETTE end
    local out = {}
    for _, colorValue in ipairs(configured) do
        if IsColor(colorValue) then
            out[#out + 1] = Color(colorValue.r, colorValue.g, colorValue.b, colorValue.a or 255)
        elseif istable(colorValue) and colorValue.r and colorValue.g and colorValue.b then
            out[#out + 1] = Color(tonumber(colorValue.r) or 255, tonumber(colorValue.g) or 255, tonumber(colorValue.b) or 255, tonumber(colorValue.a) or 255)
        end
    end

    if #out == 0 then return DEFAULT_SKIN_PALETTE end
    return out
end

local function clear_attachment_models(item)
    if IsValid(item.headEnt) then item.headEnt:Remove() end
    if IsValid(item.hairEnt) then item.hairEnt:Remove() end
    item.headEnt = nil
    item.hairEnt = nil
    item._appearanceSig = nil
end

local function ensure_attachment_model(parent, current, mdl)
    if not IsValid(parent) then
        if IsValid(current) then current:Remove() end
        return nil
    end

    if not isstring(mdl) or mdl == "" then
        if IsValid(current) then current:Remove() end
        return nil
    end

    local ent = current
    local needsRebuild = (not IsValid(ent)) or (ent:GetModel() ~= mdl)
    if needsRebuild then
        if IsValid(ent) then ent:Remove() end
        ent = ClientsideModel(mdl, RENDER_GROUP_OPAQUE_ENTITY)
    end

    if not IsValid(ent) then return nil end
    ent:SetNoDraw(true)
    ent:SetPos(parent:GetPos())
    ent:SetAngles(parent:GetAngles())
    ent:SetParent(parent)
    ent:AddEffects(EF_BONEMERGE)
    ent:AddEffects(EF_PARENT_ANIMATES)
    ent:SetLocalPos(vector_origin)
    ent:SetLocalAngles(angle_zero)
    ent:InvalidateBoneCache()
    ent:SetupBones()
    return ent
end

local function sync_appearance_models(item)
    if not IsValid(item.ent) then
        clear_attachment_models(item)
        return
    end

    local appearance = item.appearance
    if not istable(appearance) then
        clear_attachment_models(item)
        return
    end

    local headModel = tostring(appearance.headModel or "")
    local hairModel = tostring(appearance.hairModel or "")
    local signature = table.concat({headModel, hairModel}, "\31")
    item.headEnt = ensure_attachment_model(item.ent, item.headEnt, headModel)
    item.hairEnt = ensure_attachment_model(IsValid(item.headEnt) and item.headEnt or item.ent, item.hairEnt, hairModel)
    item._appearanceSig = signature
    apply_entity_bodygroups(item.headEnt, appearance.headBodygroups)
    apply_entity_bodygroups(item.hairEnt, appearance.hairBodygroups)
end

local function resolve_preview_sequence(ent, sequence)
    if not IsValid(ent) then return -1 end
    if isnumber(sequence) then return math.max(math.floor(sequence), 0) end
    sequence = string.Trim(tostring(sequence or ""))
    if sequence ~= "" then
        local seqId = ent:LookupSequence(sequence)
        if seqId and seqId > -1 then return seqId end
    end

    local fallback = ent:LookupSequence("idle_all_01")
    if fallback and fallback > -1 then return fallback end
    return 0
end

local function apply_item_animation(item, forceReset)
    if not IsValid(item.ent) then return end
    local anim = item.animation or {}
    local rate = math.max(tonumber(anim.rate) or 0, 0)
    local loop = anim.loop ~= false
    local startCycle = math.Clamp(tonumber(anim.startCycle) or 0, 0, 1)
    local seqId = resolve_preview_sequence(item.ent, anim.sequence)
    if forceReset or item._animSeqId ~= seqId or item._animRate ~= rate or item._animLoop ~= loop or item._animStartCycle ~= startCycle then
        item._animSeqId = seqId
        item._animRate = rate
        item._animLoop = loop
        item._animStartCycle = startCycle
        item._animDuration = math.max(tonumber(item.ent:SequenceDuration(seqId)) or 0, 0.01)
        item._animStartedAt = CurTime() - ((item._animDuration * startCycle) / math.max(rate, 0.001))
        item.ent:ResetSequence(seqId)
        item.ent:SetCycle(startCycle)
        item.ent:SetPlaybackRate(rate)
    end

    if rate <= 0 then
        item.ent:SetCycle(startCycle)
        item.ent:SetPlaybackRate(0)
        return
    end

    local duration = math.max(item._animDuration or 0.01, 0.01)
    local cycle = startCycle + (((CurTime() - (item._animStartedAt or CurTime())) * rate) / duration)
    if loop then
        cycle = cycle % 1
    else
        cycle = math.Clamp(cycle, 0, 0.999)
    end

    item.ent:SetCycle(cycle)
    item.ent:SetPlaybackRate(rate)
    if item.ent.FrameAdvance then item.ent:FrameAdvance(FrameTime() * rate) end
end

local function ensure_csmodel(item, mdl)
    if IsValid(item.ent) and item._mdl == mdl then
        if item.skin ~= nil then item.ent:SetSkin(item.skin) end
        apply_entity_bodygroups(item.ent, item.bodygroups)
        sync_appearance_models(item)
        apply_item_animation(item, false)
        return
    end

    clear_attachment_models(item)
    if IsValid(item.ent) then item.ent:Remove() end
    item._mdl = mdl
    item.ent = ClientsideModel(mdl, RENDER_GROUP_OPAQUE_ENTITY)
    if not IsValid(item.ent) then return end
    item.ent:SetNoDraw(true)
    if item.skin ~= nil then item.ent:SetSkin(item.skin) end
    apply_entity_bodygroups(item.ent, item.bodygroups)
    item._headBoneId = nil
    item._headLocal = nil
    sync_appearance_models(item)
    apply_item_animation(item, true)
end

local function resolve_head_bone(item)
    if item._headBoneId then return item._headBoneId end
    if not IsValid(item.ent) then return nil end
    local id = item.ent:LookupBone(item.head.bone or "")
    if id then
        item._headBoneId = id
        return id
    end

    for _, name in ipairs(HEAD_BONE_CANDIDATES) do
        id = item.ent:LookupBone(name)
        if id then
            item._headBoneId = id
            return id
        end
    end
    return nil
end

local function UpdateHeadAnchor(item)
    if not IsValid(item.ent) or item._headLocal then return end
    local id = resolve_head_bone(item)
    if not id then return end
    item.ent:SetPos(vector_origin)
    item.ent:SetAngles(angle_zero)
    item.ent:SetupBones()
    local m = item.ent:GetBoneMatrix(id)
    if m then
        item._headLocal = m:GetTranslation()
    else
        local pos = item.ent:GetBonePosition(id)
        if pos then item._headLocal = pos end
    end
end

local function ensure_item(id)
    local item = MV._items[id]
    if not item then item = MV.Create(id) end
    item.head = item.head or table.Copy(DEFAULT_HEAD)
    item.bg = item.bg or {
        mode = "none",
        color = Color(0, 0, 0, 0),
        material = nil
    }

    item.shape = item.shape or "rect"
    return item
end

local function MaskShape(item, drawInside)
    local x, y, w, h = item.x, item.y, item.w, item.h
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
    if item.shape == "circle" then
        local d = math.min(w, h)
        local cx = x + w * 0.5
        local cy = y + h * 0.5
        RNDX.DrawCircle(cx, cy, d, color_white)
    else
        local r = clamp_round(w, h, item.round)
        RNDX.Draw(r, x, y, w, h, color_white)
    end

    render.OverrideColorWriteEnable(false)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    drawInside()
    render.SetStencilEnable(false)
end

function MV.Create(id, opts)
    if MV._items[id] then return MV._items[id] end
    local t = {
        id = id,
        x = 0,
        y = 0,
        w = 150,
        h = 200,
        shape = "rect",
        round = 0,
        fov = 28,
        camPos = Vector(35, 0, 60),
        lookAt = Vector(0, 0, 60),
        ang = Angle(0, 180, 0),
        spin = 0,
        lighting = true,
        model = "models/player/kleiner.mdl",
        scale = 1,
        skin = nil,
        bodygroups = nil,
        appearance = {
            headModel = "",
            hairModel = "",
            skinColor = nil,
            hairColor = nil,
            irisStyle = 1,
            headBodygroups = nil,
            hairBodygroups = nil,
        },
        animation = {
            sequence = "idle_all_01",
            rate = 0,
            loop = true,
            startCycle = 0,
        },
        _mdl = nil,
        ent = nil,
        headEnt = nil,
        hairEnt = nil,
        head = table.Copy(DEFAULT_HEAD),
        _camPosSmooth = nil,
        _camAngSmooth = nil,
        anchorOrigin = false,
        _obb = nil,
        bg = {
            mode = "none",
            color = Color(0, 0, 0, 0),
            material = nil
        },
    }

    MV._items[id] = t
    if opts then MV.Update(id, opts) end
    return t
end

function MV.Ensure(id, opts)
    return MV.Create(id, opts)
end

function MV.Update(id, opts)
    local item = ensure_item(id)
    opts = opts or {}
    for k, v in pairs(opts) do
        if k ~= "head" and k ~= "bg" and k ~= "appearance" then item[k] = v end
    end

    if istable(opts.head) then
        item.head = item.head or table.Copy(DEFAULT_HEAD)
        for hk, hv in pairs(opts.head) do
            item.head[hk] = hv
        end
    end

    if istable(opts.bg) then
        item.bg = item.bg or {
            mode = "none",
            color = Color(0, 0, 0, 0),
            material = nil
        }

        if opts.bg.mode ~= nil then item.bg.mode = opts.bg.mode end
        if opts.bg.color ~= nil then item.bg.color = opts.bg.color end
        if opts.bg.material ~= nil then item.bg.material = opts.bg.material end
    end

    if opts.appearance == false then
        item.appearance = {
            headModel = "",
            hairModel = "",
            skinColor = nil,
            hairColor = nil,
            irisStyle = 1,
            headBodygroups = nil,
            hairBodygroups = nil,
        }
    elseif istable(opts.appearance) then
        item.appearance = item.appearance or {}
        for ak, av in pairs(opts.appearance) do
            item.appearance[ak] = av
        end
    end

    if opts.animation == false then
        item.animation = {
            sequence = "idle_all_01",
            rate = 0,
            loop = true,
            startCycle = 0,
        }
    elseif istable(opts.animation) then
        item.animation = item.animation or {}
        for ak, av in pairs(opts.animation) do
            item.animation[ak] = av
        end
    end

    if item.model then ensure_csmodel(item, item.model) end
    return item
end

function MV.SetShape(id, shape)
    shape = (shape == "circle") and "circle" or "rect"
    return MV.Update(id, {
        shape = shape
    })
end

function MV.SetCircle(id, enabled)
    return MV.SetShape(id, enabled and "circle" or "rect")
end

function MV.SetRect(id, x, y, w, h)
    return MV.Update(id, {
        x = x,
        y = y,
        w = w,
        h = h
    })
end

function MV.SetCircleRect(id, x, y, size)
    return MV.Update(id, {
        x = x,
        y = y,
        w = size,
        h = size,
        shape = "circle",
        round = 0
    })
end

function MV.SetRound(id, r)
    return MV.Update(id, {
        round = r
    })
end

function MV.SetFOV(id, fov)
    return MV.Update(id, {
        fov = fov
    })
end

function MV.SetCam(id, pos, look)
    return MV.Update(id, {
        camPos = pos,
        lookAt = look
    })
end

function MV.SetAngles(id, ang)
    return MV.Update(id, {
        ang = ang
    })
end

function MV.SetSpin(id, dps)
    return MV.Update(id, {
        spin = dps or 0
    })
end

function MV.SetModel(id, mdl, skin, bodygroups)
    return MV.Update(id, {
        model = mdl,
        skin = skin,
        bodygroups = bodygroups
    })
end

function MV.SetAppearance(id, opts)
    return MV.Update(id, {
        appearance = opts or {}
    })
end

function MV.ClearAppearance(id)
    return MV.Update(id, {
        appearance = false
    })
end

function MV.SetFromPlayer(id, ply)
    ply = ply or LocalPlayer()
    if not IsValid(ply) then return end
    local mdl = ply:GetModel() or "models/player/kleiner.mdl"
    local skin = ply:GetSkin() or 0
    local bg = {}
    local n = ply:GetNumBodyGroups() or 0
    for i = 0, n - 1 do
        bg[i] = ply:GetBodygroup(i) or 0
    end

    local appearance = {
        headModel = "",
        hairModel = "",
        skinColor = nil,
        hairColor = nil,
        eyeColor = nil,
        eyebrowStyle = 1,
        irisStyle = 1,
        eyebrowColor = nil,
        headBodygroups = nil,
        hairBodygroups = nil,
    }

    local characters = VERSE.Characters
    local nw = characters and characters.AppearanceNW or nil
    local modelScale = 1
    if CP and CP.ReadAppearance then
        local cpApp = CP:ReadAppearance(ply)
        appearance.headModel = cpApp.headModel or ""
        appearance.hairModel = ""
        appearance.skinColor = cpApp.skinColor
        appearance.hairColor = cpApp.hairColor
        appearance.headBodygroups = {
            [0] = cpApp.headStyle or 0,
            [1] = cpApp.hairStyle or 0,
        }

        appearance.hairBodygroups = {}

        modelScale = cpApp.modelScale or 1
    end

    if nw and ply.GetPublicString and ply.GetPublicInt then
        appearance.eyeColor = parse_color_string((nw.EyeColor and ply:GetPublicString(nw.EyeColor, "")) or "", DEFAULT_EYE_COLOR)
        appearance.eyebrowStyle = nw.EyebrowStyle and ply:GetPublicInt(nw.EyebrowStyle, 1) or 1
        appearance.irisStyle = nw.IrisStyle and ply:GetPublicInt(nw.IrisStyle, 1) or 1
        appearance.eyebrowColor = parse_color_string((nw.EyebrowColor and ply:GetPublicString(nw.EyebrowColor, "")) or "", appearance.hairColor or DEFAULT_HAIR_COLOR)
    end
    return MV.Update(id, {
        model = mdl,
        scale = modelScale,
        skin = skin,
        bodygroups = bg,
        appearance = appearance,
    })
end

function MV.SetAnimation(id, sequence, opts)
    opts = opts or {}
    return MV.Update(id, {
        animation = {
            sequence = sequence or "idle_all_01",
            rate = tonumber(opts.rate) or 1,
            loop = opts.loop ~= false,
            startCycle = tonumber(opts.startCycle) or 0,
        }
    })
end

function MV.ClearAnimation(id)
    return MV.Update(id, {
        animation = false,
    })
end

function MV.SetBackground(id, mode, opt)
    local item = ensure_item(id)
    opt = opt or {}
    item.bg.mode = mode or "none"
    item.bg.color = opt.color or item.bg.color or Color(0, 0, 0, 0)
    item.bg.material = opt.material or item.bg.material
    return item
end

function MV.SetBgColor(id, col)
    return MV.SetBackground(id, "color", {
        color = col
    })
end

function MV.SetBgMaterial(id, mat)
    return MV.SetBackground(id, "material", {
        material = mat
    })
end

function MV.ClearBackground(id)
    return MV.SetBackground(id, "none")
end

function MV.SetHeadMode(id, enabled)
    local item = ensure_item(id)
    item.head.enabled = not not enabled
    item._headLocal = nil
    item._headBoneId = nil
    return item
end

function MV.SetHeadOptions(id, opts)
    local item = ensure_item(id)
    for k, v in pairs(opts or {}) do
        item.head[k] = v
    end

    item._headLocal = nil
    item._headBoneId = nil
    return item
end

function MV.PresetHead(id, x, y)
    MV.Ensure(id)
    MV.SetRect(id, x, y, 128, 134)
    MV.SetRound(id, DEFAULT_HEAD.round)
    MV.SetFOV(id, 28)
    MV.SetAngles(id, Angle(0, 180, 0))
    MV.SetHeadMode(id, true)
    MV.SetHeadOptions(id, {
        distance = 13,
        upOffset = 2,
        sideOffset = 0
    })

    MV.ClearBackground(id)
    return MV._items[id]
end

local function draw_item(item)
    if not IsValid(item.ent) then return end
    sync_appearance_models(item)
    apply_item_animation(item, false)
    local modelScale = tonumber(item.scale) or 1
    item.ent:SetModelScale(modelScale, 0)
    if IsValid(item.headEnt) then item.headEnt:SetModelScale(modelScale, 0) end
    if IsValid(item.hairEnt) then item.hairEnt:SetModelScale(modelScale, 0) end
    local x, y = item.x, item.y
    local w, h = item.w, item.h
    if item.spin ~= 0 then item.ang.y = item.ang.y + (item.spin * FrameTime()) end
    local camPos, camAng, fov = item.camPos, item.ang, item.fov
    local lookAt = item.lookAt
    if item.head.enabled then
        UpdateHeadAnchor(item)
        if item._headLocal then
            item.ent:SetAngles(angle_zero)
            item.ent:SetPos(lookAt - item._headLocal)
            local fwd, right, up = item.ang:Forward(), item.ang:Right(), item.ang:Up()
            camPos = lookAt + (-fwd * item.head.distance) + (right * item.head.sideOffset) + (up * item.head.upOffset)
            camAng = (lookAt - camPos):Angle()
            if (item.head.fov or 0) > 0 then fov = item.head.fov end
        end
    else
        item.ent:SetAngles(angle_zero)
        if item.anchorOrigin then
            item.ent:SetPos(vector_origin)
        else
            item.ent:SetPos(lookAt)
        end
    end

    local smooth = 0.15
    item._camPosSmooth = item._camPosSmooth and LerpVectorFast(smooth, item._camPosSmooth, camPos) or camPos
    item._camAngSmooth = item._camAngSmooth and LerpAngleFast(smooth, item._camAngSmooth, camAng) or camAng
    MaskShape(item, function()
        if item.bg and item.bg.mode ~= "none" then
            if item.bg.mode == "color" and item.bg.color then
                if item.shape == "circle" then
                    local d = math.min(w, h)
                    local cx, cy = x + w * 0.5, y + h * 0.5
                    RNDX.DrawCircle(cx, cy, d, item.bg.color)
                else
                    local r = clamp_round(w, h, item.round)
                    RNDX.Draw(r, x, y, w, h, item.bg.color)
                end
            elseif item.bg.mode == "material" and item.bg.material then
                if item.shape == "circle" then
                    RNDX.DrawMaterial(0, x, y, w, h, color_white, item.bg.material)
                else
                    local r = clamp_round(w, h, item.round)
                    RNDX.DrawMaterial(r, x, y, w, h, color_white, item.bg.material)
                end
            end
        end

        cam.Start3D(item._camPosSmooth, item._camAngSmooth, fov, x, y, w, h)
        if item.lighting then
            render.SuppressEngineLighting(true)
            render.ResetModelLighting(0.35, 0.35, 0.35)
            for i = 0, 6 do
                render.SetModelLighting(i, 0.35, 0.35, 0.35)
            end
        end

        item.ent:SetupBones()
        local appearance = item.appearance or {}
        local skinColor = appearance.skinColor and clone_color_safe(appearance.skinColor, DEFAULT_SKIN_PALETTE[1]) or nil
        local hairColor = appearance.hairColor and parse_color_string(appearance.hairColor, DEFAULT_HAIR_COLOR) or nil
        local eyebrowColor = appearance.eyebrowColor and parse_color_string(appearance.eyebrowColor, hairColor or DEFAULT_HAIR_COLOR) or hairColor
        local eyeColor = appearance.eyeColor and parse_color_string(appearance.eyeColor, DEFAULT_EYE_COLOR) or nil
        apply_entity_bodygroups(item.ent, item.bodygroups)
        if skinColor then set_entity_tint(item.ent, skinColor, is_skin_material) end
        item.ent:DrawModel()
        if skinColor then set_entity_tint(item.ent, color_white, is_skin_material) end
        if IsValid(item.headEnt) then
            local useFaceControls = is_face_control_model(item.headEnt:GetModel())
            apply_entity_bodygroups(item.headEnt, appearance.headBodygroups)
            item.headEnt:SetupBones()
            apply_eyebrow_material(item.headEnt, appearance.eyebrowStyle or 1)
            if useFaceControls then apply_eye_material(item.headEnt, appearance.irisStyle or 1) end
            if eyebrowColor then set_eyebrow_tint(appearance.eyebrowStyle or 1, eyebrowColor) end
            if skinColor then
                if useFaceControls then
                    set_face_skin_tint(item.headEnt, skinColor)
                else
                    set_entity_tint(item.headEnt, skinColor, is_skin_material)
                end
            end

            if eyeColor and not useFaceControls then set_entity_tint(item.headEnt, eyeColor, is_eye_material) end
            item.headEnt:DrawModel()
            if eyebrowColor then set_eyebrow_tint(appearance.eyebrowStyle or 1, color_white) end
            if eyeColor and not useFaceControls then set_entity_tint(item.headEnt, color_white, is_eye_material) end
            if skinColor then
                if useFaceControls then
                    set_face_skin_tint(item.headEnt, color_white)
                else
                    set_entity_tint(item.headEnt, color_white, is_skin_material)
                end
            end
        end

        if IsValid(item.hairEnt) then
            apply_entity_bodygroups(item.hairEnt, appearance.hairBodygroups)
            item.hairEnt:SetupBones()
            if hairColor then set_entity_tint(item.hairEnt, hairColor) end
            item.hairEnt:DrawModel()
            if hairColor then set_entity_tint(item.hairEnt, color_white) end
        end

        if item.lighting then render.SuppressEngineLighting(false) end
        cam.End3D()
    end)
end

function MV.Draw(id)
    local it = MV._items[id]
    if not it then return end
    draw_item(it)
end

function MV.DrawAll()
    for _, it in pairs(MV._items) do
        draw_item(it)
    end
end

function MV.Remove(id)
    local item = MV._items[id]
    if not item then return end
    clear_attachment_models(item)
    if IsValid(item.ent) then item.ent:Remove() end
    MV._items[id] = nil
end

local function compute_obb(item)
    if not IsValid(item.ent) then return nil end
    item.ent:SetAngles(angle_zero)
    item.ent:SetPos(vector_origin)
    item.ent:SetupBones()
    local mins, maxs = item.ent:GetRenderBounds()
    if not mins or not maxs then return nil end
    if IsValid(item.headEnt) and item.headEnt.GetRenderBounds then
        item.headEnt:SetupBones()
        local headMins, headMaxs = item.headEnt:GetRenderBounds()
        mins = Vector(math.min(mins.x, headMins.x), math.min(mins.y, headMins.y), math.min(mins.z, headMins.z))
        maxs = Vector(math.max(maxs.x, headMaxs.x), math.max(maxs.y, headMaxs.y), math.max(maxs.z, headMaxs.z))
    end

    if IsValid(item.hairEnt) and item.hairEnt.GetRenderBounds then
        item.hairEnt:SetupBones()
        local hairMins, hairMaxs = item.hairEnt:GetRenderBounds()
        mins = Vector(math.min(mins.x, hairMins.x), math.min(mins.y, hairMins.y), math.min(mins.z, hairMins.z))
        maxs = Vector(math.max(maxs.x, hairMaxs.x), math.max(maxs.y, hairMaxs.y), math.max(maxs.z, hairMaxs.z))
    end

    local center = (mins + maxs) * 0.5
    local height = maxs.z - mins.z
    local radius = (maxs - mins):Length() * 0.5
    return {
        mins = mins,
        maxs = maxs,
        center = center,
        height = height,
        radius = radius,
    }
end

function MV.SetAnchorOrigin(id, enabled)
    return MV.Update(id, {
        anchorOrigin = not not enabled
    })
end

function MV.FitFullBody(id, opts)
    local item = ensure_item(id)
    opts = opts or {}
    if item.model then ensure_csmodel(item, item.model) end
    if not IsValid(item.ent) then return item end
    item.anchorOrigin = true
    item.head.enabled = false
    item._obb = compute_obb(item)
    if not item._obb then return item end
    local obb = item._obb
    local center = obb.center
    local height = math.max(obb.height, 1)
    local pad = tonumber(opts.padding) or 1.08
    local fov = tonumber(opts.fov) or item.fov or 30
    item.fov = fov
    local vfov = math.rad(fov)
    local halfH = (height * 0.5) * pad
    local dist = halfH / math.tan(vfov * 0.5)
    local ang = opts.ang or item.ang or Angle(0, 180, 0)
    item.ang = ang
    local fwd = ang:Forward()
    local up = ang:Up()
    local look = center + up * (height * 0.02)
    local camera = look + (-fwd * dist) + (up * (height * 0.02))
    item.lookAt = look
    item.camPos = camera
    return item
end

VERSE.Hook.AddNS("ModelPanel", "ShutDown", "VERSE::ShutDown::ModelPanel", function()
    for _, it in pairs(MV._items) do
        clear_attachment_models(it)
        if IsValid(it.ent) then it.ent:Remove() end
    end

    MV._items = {}
end)