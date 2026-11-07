VERSE.CharacterPreview = VERSE.CharacterPreview or {}
local CP = VERSE.CharacterPreview

local DEFAULT_SKIN_PALETTE = {
    Color(255, 244, 230),
    Color(240, 220, 198),
    Color(223, 196, 168),
    Color(192, 156, 126),
    Color(150, 113, 86),
    Color(105, 75, 58),
}
local DEFAULT_SKIN = DEFAULT_SKIN_PALETTE[1]
local DEFAULT_HAIR = Color(62, 44, 30)

function CP.ParseColor(str, fallback)
    if IsColor(str) then return Color(str.r, str.g, str.b, str.a or 255) end
    if istable(str) and str.r and str.g and str.b then
        return Color(tonumber(str.r) or 255, tonumber(str.g) or 255, tonumber(str.b) or 255, tonumber(str.a) or 255)
    end
    if not isstring(str) or str == "" then return fallback end
    local r, g, b, a = string.match(str, "^(%d+),(%d+),(%d+),?(%d*)$")
    if r and g and b then
        return Color(
            math.Clamp(tonumber(r) or 255, 0, 255),
            math.Clamp(tonumber(g) or 255, 0, 255),
            math.Clamp(tonumber(b) or 255, 0, 255),
            math.Clamp(tonumber(a) or 255, 0, 255)
        )
    end
    return fallback
end

function CP.SetBodygroup(ent, value)
    if not IsValid(ent) or not ent.GetNumBodyGroups or not ent.GetBodygroupCount then return end
    if ent:GetNumBodyGroups() <= 0 then return end
    local maxVal = math.max(0, (tonumber(ent:GetBodygroupCount(0)) or 0) - 1)
    local safe = math.Clamp(math.floor(tonumber(value) or 0), 0, maxVal)
    local CH = VERSE.Characters
    if CH and CH.NormalizeBodygroupValue then
        safe = CH:NormalizeBodygroupValue(ent:GetModel(), 0, safe, maxVal)
    end
    ent:SetBodygroup(0, safe)
end

function CP.TintEntity(ent, color, matcher)
    if not IsValid(ent) or not IsColor(color) then return end
    local vec = Vector(color.r / 255, color.g / 255, color.b / 255)
    for idx, matName in ipairs(ent:GetMaterials() or {}) do
        if not matcher or matcher(matName) then
            local mat = Material(matName)
            if mat and not mat:IsError() then mat:SetVector("$color2", vec) end
        end
    end
end

function CP.SpawnMerged(mdl, parentEnt, boneMerge)
    if not isstring(mdl) or mdl == "" or not IsValid(parentEnt) then return nil end
    local ent = ClientsideModel(mdl)
    if not IsValid(ent) then return nil end
    if boneMerge == nil then boneMerge = true end
    ent:SetNoDraw(true)
    ent:SetPos(parentEnt:GetPos())
    ent:SetAngles(parentEnt:GetAngles())
    ent:SetParent(parentEnt)
    if boneMerge then
        ent:AddEffects(EF_BONEMERGE)
        ent:AddEffects(EF_BONEMERGE_FASTCULL)
        ent:AddEffects(EF_PARENT_ANIMATES)
    end
    ent:SetLocalPos(vector_origin)
    ent:SetLocalAngles(angle_zero)
    ent:InvalidateBoneCache()
    ent:SetupBones()
    return ent
end

function CP.GetSkinPalette()
    local CH = VERSE.Characters
    if not CH then return DEFAULT_SKIN_PALETTE end
    if CH.ConfigTable then
        local palette = CH:ConfigTable("SkinColorPalette", nil)
        if istable(palette) and #palette > 0 then
            local out = {}
            for _, entry in ipairs(palette) do
                if IsColor(entry) then
                    table.insert(out, entry)
                elseif istable(entry) then
                    table.insert(out, Color(
                        tonumber(entry.r or entry[1]) or 255,
                        tonumber(entry.g or entry[2]) or 255,
                        tonumber(entry.b or entry[3]) or 255
                    ))
                end
            end
            if #out > 0 then return out end
        end
    end
    return DEFAULT_SKIN_PALETTE
end

function CP.ApplyIdleAnimation(ent)
    if not IsValid(ent) then return end
    local CH = VERSE.Characters
    if not CH or not CH.GetIdlePool then return end
    local pool = CH:GetIdlePool()
    if not istable(pool) then return end
    for _, entry in ipairs(pool) do
        local seq = ent:LookupSequence(entry.Sequence or "")
        if seq and seq >= 0 then
            ent:ResetSequence(seq)
            ent:SetCycle(0)
            return
        end
    end
end

CP.DEFAULT_SKIN_PALETTE = DEFAULT_SKIN_PALETTE
CP.DEFAULT_SKIN = DEFAULT_SKIN
CP.DEFAULT_HAIR = DEFAULT_HAIR

local parseColor = CP.ParseColor
local setBodygroup = CP.SetBodygroup
local tintEntity = CP.TintEntity
local spawnMerged = CP.SpawnMerged
local getSkinPalette = CP.GetSkinPalette

function CP:ReadAppearance(ply)
    if not IsValid(ply) then return {} end
    local CH = VERSE.Characters
    local nw = CH and CH.AppearanceNW or {}

    local bodyMdl = ply:GetModel() or ""
    local headMdl = (ply.GetPublicString and nw.HeadModel and ply:GetPublicString(nw.HeadModel, "")) or ""

    local bodyStyle = (ply.GetPublicInt and nw.BodyStyle and ply:GetPublicInt(nw.BodyStyle, 0)) or 0
    local headStyle = (ply.GetPublicInt and nw.HeadStyle and ply:GetPublicInt(nw.HeadStyle, 0)) or 0
    local hairStyle = (ply.GetPublicInt and nw.HairStyle and ply:GetPublicInt(nw.HairStyle, 0)) or 0

    local skinToneIdx = (ply.GetPublicInt and nw.SkinTone and ply:GetPublicInt(nw.SkinTone, 1)) or 1
    local skinColorStr = (ply.GetPublicString and nw.SkinColor and ply:GetPublicString(nw.SkinColor, "")) or ""
    local hairColorStr = (ply.GetPublicString and nw.HairColor and ply:GetPublicString(nw.HairColor, "")) or ""
    local hairTipColorStr = (ply.GetPublicString and nw.HairTipColor and ply:GetPublicString(nw.HairTipColor, "")) or ""
    local heightVal = (ply.GetPublicInt and nw.Height and ply:GetPublicInt(nw.Height, 170)) or 170

    local palette = getSkinPalette()
    local skinIdx = math.Clamp(math.floor(tonumber(skinToneIdx) or 1), 1, #palette)
    local skinColor = palette[skinIdx] or DEFAULT_SKIN
    if skinColorStr ~= "" then
        skinColor = parseColor(skinColorStr, skinColor)
    end

    local hairColor = parseColor(hairColorStr, DEFAULT_HAIR)
    -- Dégradé : couleur de pointes (nil = pas de dégradé, couleur unie).
    local hairTipColor = (hairTipColorStr ~= "") and parseColor(hairTipColorStr, hairColor) or nil
    local modelScale = (CH and CH.GetHeightScale) and CH:GetHeightScale(heightVal) or 1

    local eyebrowStyle = (ply.GetPublicInt and nw.EyebrowStyle and ply:GetPublicInt(nw.EyebrowStyle, 1)) or 1
    local eyebrowColorStr = (ply.GetPublicString and nw.EyebrowColor and ply:GetPublicString(nw.EyebrowColor, "")) or ""
    local eyebrowColor = parseColor(eyebrowColorStr, hairColor)
    local irisStyle = (ply.GetPublicInt and nw.IrisStyle and ply:GetPublicInt(nw.IrisStyle, 1)) or 1
    local defaultIrisSize = (CH and CH.GetDefaultIrisSize) and CH:GetDefaultIrisSize() or 100
    local irisSize = (ply.GetPublicInt and nw.IrisSize and ply:GetPublicInt(nw.IrisSize, defaultIrisSize)) or defaultIrisSize
    local eyeColorStr = (ply.GetPublicString and nw.EyeColor and ply:GetPublicString(nw.EyeColor, "")) or ""
    local eyeColor = parseColor(eyeColorStr, Color(255, 255, 255))
    local bodyMarksJson = (ply.GetPublicString and nw.BodyMarks and ply:GetPublicString(nw.BodyMarks, "")) or ""
    local flexJson = (ply.GetPublicString and nw.Flex and ply:GetPublicString(nw.Flex, "")) or ""
    local flex = (CH and CH.NormalizeFlexTable) and CH:NormalizeFlexTable(flexJson) or {}

    return {
        bodyModel = bodyMdl,
        headModel = headMdl,
        bodyStyle = bodyStyle,
        headStyle = headStyle,
        hairStyle = hairStyle,
        skinColor = skinColor,
        hairColor = hairColor,
        hairTipColor = hairTipColor,
        modelScale = modelScale,
        height = heightVal,
        eyebrowStyle = eyebrowStyle,
        eyebrowColor = eyebrowColor,
        irisStyle = irisStyle,
        irisSize = irisSize,
        eyeColor = eyeColor,
        bodyMarksJson = bodyMarksJson,
        flex = flex,
    }
end

function CP:SetupPanel(parent)
    local mdl = vgui.Create("DModelPanel", parent)
    mdl:SetAnimated(true)
    mdl:SetMouseInputEnabled(false)
    mdl:SetKeyboardInputEnabled(false)
    mdl:SetPaintBackground(false)
    mdl:SetAmbientLight(Color(255, 255, 255))
    mdl:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
    mdl:SetDirectionalLight(BOX_FRONT, Color(220, 220, 220))
    mdl:SetDirectionalLight(BOX_RIGHT, Color(180, 180, 180))
    return mdl
end

function CP:AutoCamera(mdl, opts)
    opts = opts or {}
    local root = mdl.Entity
    if not IsValid(root) then return end
    local mins, maxs = root:GetRenderBounds()
    local center = (mins + maxs) * 0.5
    local height = math.max(1, maxs.z - mins.z)
    local radius = math.max(maxs.x - mins.x, maxs.y - mins.y, height)
    mdl:SetFOV(opts.fov or 28)
    mdl:SetLookAt(opts.lookOffset or (center + Vector(0, 0, height * 0.1)))
    mdl:SetCamPos(opts.camOffset or (center + Vector(radius * 1.45, radius * 0.12, height * 0.42)))
end

function CP:CreateFromAppearance(parent, app, opts)
    opts = opts or {}
    if not app or not app.bodyModel or app.bodyModel == "" then return nil end

    local mdl = self:SetupPanel(parent)

    mdl:SetModel(app.bodyModel)
    local root = mdl.Entity
    if not IsValid(root) then return mdl end

    root:SetAngles(Angle(0, 0, 0))
    root:SetPos(Vector(0, 0, 0))
    root:SetModelScale(app.modelScale or 1, 0)
    setBodygroup(root, app.bodyStyle)

    if opts.idle ~= false then
        CP.ApplyIdleAnimation(root)
    end

    mdl._headEnt = spawnMerged(app.headModel, root)
    do
        local CHmod = VERSE.Characters
        if CHmod and CHmod.HideBuiltInHeadBodygroups and IsValid(mdl._headEnt) then
            CHmod.HideBuiltInHeadBodygroups(root)
        end
    end
    if IsValid(mdl._headEnt) then
        setBodygroup(mdl._headEnt, app.headStyle)
        if mdl._headEnt.GetNumBodyGroups and mdl._headEnt:GetNumBodyGroups() > 1 and mdl._headEnt.SetBodygroup then
            local hairVal = math.max(0, math.floor(tonumber(app.hairStyle) or 0))
            local maxHair = 0
            if mdl._headEnt.GetBodygroupCount then maxHair = math.max(0, (tonumber(mdl._headEnt:GetBodygroupCount(1)) or 0) - 1) end
            mdl._headEnt:SetBodygroup(1, math.Clamp(hairVal, 0, maxHair))
        end
        mdl._headEnt:SetModelScale(app.modelScale or 1, 0)
    end

    mdl._cpSkinColor = app.skinColor or DEFAULT_SKIN
    mdl._cpHairColor = app.hairColor or DEFAULT_HAIR
    mdl._cpHairTipColor = IsColor(app.hairTipColor) and app.hairTipColor or nil
    mdl._cpEyebrowStyle = tonumber(app.eyebrowStyle) or 1
    mdl._cpEyebrowColor = app.eyebrowColor or mdl._cpHairColor
    mdl._cpIrisStyle = tonumber(app.irisStyle) or 1
    mdl._cpIrisSize = tonumber(app.irisSize) or 100
    mdl._cpEyeColor = app.eyeColor or Color(255, 255, 255)
    mdl._cpFlex = istable(app.flex) and app.flex or {}
    mdl._cpApp = app

    self:AutoCamera(mdl, opts)

    local skinMatcher = opts.skinMatcher or nil
    mdl.PreDrawModel = function(s, ent)
        if not IsValid(ent) then return end
        tintEntity(ent, s._cpSkinColor, skinMatcher)
    end

    mdl.LayoutEntity = function(s, ent)
        if not IsValid(ent) then return end
        ent:SetAngles(Angle(0, 0, 0))
        ent:FrameAdvance(FrameTime())
        ent:InvalidateBoneCache()
        ent:SetupBones()
        if IsValid(s._headEnt) then
            s._headEnt:InvalidateBoneCache()
            s._headEnt:SetupBones()
        end
    end

    mdl.PostDrawModel = function(s)
        local CHmod = VERSE.Characters
        if IsValid(s._headEnt) then
            if CHmod and CHmod.SetEntitySkinColorRuntime then
                CHmod.SetEntitySkinColorRuntime(s._headEnt, s._cpSkinColor or DEFAULT_SKIN)
            else
                tintEntity(s._headEnt, s._cpSkinColor, skinMatcher)
            end
            if CHmod and CHmod.SetEntityIris then CHmod.SetEntityIris(s._headEnt, s._cpIrisStyle or 1, s._cpIrisSize or 100, s._cpEyeColor or color_white) end
            if IsColor(s._cpHairTipColor) and CHmod and CHmod.SetEntityHairGradient then
                -- Dégradé : racines = _cpHairColor (haut), pointes = _cpHairTipColor (bas).
                -- SetEntityHairGradient(ent, c1=bas/pointes, c2=haut/racines).
                CHmod.SetEntityHairGradient(s._headEnt, s._cpHairTipColor, s._cpHairColor or DEFAULT_HAIR)
            elseif CHmod and CHmod.SetEntityHairColor then
                CHmod.SetEntityHairColor(s._headEnt, s._cpHairColor or DEFAULT_HAIR)
            end
            if CHmod and CHmod.SetEntityEyebrowColor then CHmod.SetEntityEyebrowColor(s._headEnt, s._cpEyebrowColor or s._cpHairColor or DEFAULT_HAIR) end
            if CHmod and CHmod.ApplyFlex and s._cpFlex then CHmod.ApplyFlex(s._headEnt, s._cpFlex) end
            s._headEnt:DrawModel()
        end
        if IsValid(s.Entity) then
            tintEntity(s.Entity, color_white, skinMatcher)
        end
    end

    mdl.OnRemove = function(s)
        if IsValid(s._headEnt) then s._headEnt:Remove() end
        s._headEnt = nil
    end

    return mdl
end

function CP:Create(parent, ply, opts)
    ply = ply or LocalPlayer()
    if not IsValid(ply) then return nil end
    local app = self:ReadAppearance(ply)
    return self:CreateFromAppearance(parent, app, opts)
end

function CP:CreateSized(parent, x, y, w, h, ply, opts)
    local mdl = self:Create(parent, ply, opts)
    if IsValid(mdl) then
        mdl:SetPos(x, y)
        mdl:SetSize(w, h)
    end
    return mdl
end

function CP:CreateSimple(parent, modelPath, opts)
    opts = opts or {}
    if not isstring(modelPath) or modelPath == "" then return nil end

    local mdl = self:SetupPanel(parent)
    mdl:SetModel(modelPath)
    local root = mdl.Entity
    if not IsValid(root) then return mdl end

    root:SetAngles(Angle(0, 0, 0))
    root:SetPos(Vector(0, 0, 0))

    if opts.idle ~= false then
        CP.ApplyIdleAnimation(root)
    end

    self:AutoCamera(mdl, opts)

    mdl.LayoutEntity = function(s, ent)
        if not IsValid(ent) then return end
        ent:SetAngles(Angle(0, 0, 0))
        ent:FrameAdvance(FrameTime())
    end

    return mdl
end
