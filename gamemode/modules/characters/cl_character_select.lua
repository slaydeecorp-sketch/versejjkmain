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
CH._menuMusicChannel = CH._menuMusicChannel or nil
local function stopMenuMusic()
    if IsValid(CH._menuMusicChannel) then CH._menuMusicChannel:Stop() end
    CH._menuMusicChannel = nil
end

local function startMenuMusic()
    if IsValid(CH._menuMusicChannel) then return end
    local relPath = CH.ConfigString and CH:ConfigString("MenuMusic", "verse/character/menu_music.mp3") or "verse/character/menu_music.mp3"
    if not isstring(relPath) or relPath == "" then return end
    sound.PlayFile("sound/" .. relPath, "noblock noplay", function(channel, errId, errStr)
        if not IsValid(channel) then
            if VERSE.Log and VERSE.Log.Warn then VERSE.Log:Warn("[CharacterMenu] Music load failed:", tostring(errStr)) end
            return
        end

        if not IsValid(characterSelectFrame) and not IsValid(characterCreateFrame) then
            channel:Stop()
            return
        end

        stopMenuMusic()
        CH._menuMusicChannel = channel
        local cfgVol = tonumber(CH.GetConfig and CH:GetConfig("MenuMusicVolume")) or 0.35
        channel:SetVolume(math.Clamp(cfgVol, 0, 1))
        channel:EnableLooping(true)
        channel:Play()
    end)
end

CH.StartMenuMusic = startMenuMusic
CH.StopMenuMusic = stopMenuMusic
function CH:CharacterSelect(characters)
    if IsValid(characterSelectFrame) then characterSelectFrame:Remove() end
    if not self:ConfigBool("Enabled", true) then return end
    clearWorldAppearanceStates()
    startMenuMusic()
    local scrw, scrh = 1920, 1080
    local cfg = self:GetConfig()
    local maxSlots = CH.Client.slots or 1
    characters = characters or {}
    local highestOccupied = 0
    local firstEmpty = nil
    for i = 1, maxSlots do
        if characters[i] then
            highestOccupied = i
        elseif firstEmpty == nil then
            firstEmpty = i
        end
    end

    local visibleSlots = math.max(highestOccupied, firstEmpty or 1)
    visibleSlots = math.max(1, math.min(visibleSlots, maxSlots))
    characterSelectFrame = vgui.Create("MantleFrame")
    characterSelectFrame:SetSize(R:XY(scrw, scrh))
    characterSelectFrame:Center()
    characterSelectFrame:MakePopup()
    characterSelectFrame:SetDraggable(false)
    characterSelectFrame:LiteMode()
    characterSelectFrame:SetAlphaBackground(false)
    characterSelectFrame:SetClosable(false)
    characterSelectFrame:DisableCloseBtn()
    characterSelectFrame:Notify(Language("character.select_character_title"), 5)
    characterSelectFrame.Paint = function(s, w, h)
        Materials:Draw(color_white, "character_main_background", 0, 0, w, h)
        Materials:Draw(color_white, "character_logo_verse", w * .5 - R:X(197 / 2), R:Y(33), R:X(193), R:Y(85))
    end

    local function pickCardEntry(entry, index)
        if isstring(entry) and entry ~= "" then return entry end
        if istable(entry) and #entry > 0 then
            local i = math.max(1, math.floor(tonumber(index) or 1))
            if i > #entry then i = 1 end
            return entry[i]
        end
        return nil
    end

    local function buildSelectSkinPalette()
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

    local skinPalette = buildSelectSkinPalette()
    local function parseStoredColor(value, fallback)
        if IsColor(value) then return Color(value.r, value.g, value.b, value.a or 255) end
        if istable(value) and value.r and value.g and value.b then return Color(tonumber(value.r) or 255, tonumber(value.g) or 255, tonumber(value.b) or 255, tonumber(value.a) or 255) end
        if isstring(value) and value ~= "" then
            local r, g, b, a = string.match(value, "^(%d+),(%d+),(%d+),?(%d*)$")
            if r and g and b then return Color(math.Clamp(tonumber(r) or 255, 0, 255), math.Clamp(tonumber(g) or 255, 0, 255), math.Clamp(tonumber(b) or 255, 0, 255), math.Clamp(tonumber(a) or 255, 0, 255)) end
        end
        return Color(fallback.r, fallback.g, fallback.b, fallback.a or 255)
    end

    local function isSkinMaterialName(matName)
        return isSkinMaterialNameBase(matName)
    end

    local CP = VERSE.CharacterPreview
    local function setSelectEntityTint(ent, color, matcher)
        if not IsValid(ent) or not IsColor(color) then return end
        local vec = Vector(color.r / 255, color.g / 255, color.b / 255)
        for idx, matName in ipairs(ent:GetMaterials() or {}) do
            local slotIndex = idx - 1
            if not matcher or (matcher(matName) and not (matcher == isSkinMaterialName and shouldSkipFaceSkinTintSlot(ent, slotIndex))) then
                local mat = Material(matName)
                if mat and not mat:IsError() then mat:SetVector("$color2", vec) end
            end
        end
    end

    local setSelectBodygroup = CP and CP.SetBodygroup or function() end
    local applySelectIdle = CP and CP.ApplyIdleAnimation or function() end
    local function buildCharacterCardPreview(parent, ch)
        if not istable(ch) then return nil end
        local function resolvePreviewModel(mdl)
            if not isstring(mdl) or mdl == "" then return nil end
            return mdl
        end

        local factionCfg = (self:FactionsEnabled() and isstring(ch.faction) and cfg.Factions and cfg.Factions[ch.faction]) or nil
        local gender = tostring(ch.gender or cfg.DefaultGender or "male")
        local gdata = (factionCfg and self.GetFactionGenderData) and self:GetFactionGenderData(factionCfg, gender) or nil
        -- Modèle de base (pour le calcul de caméra), tenue équipée si disponible (pour l'affichage)
        local baseMdl = resolvePreviewModel((isstring(ch.model) and ch.model ~= "") and ch.model or nil)
        local equippedMdl = resolvePreviewModel((isstring(ch.equipped_model) and ch.equipped_model ~= "") and ch.equipped_model or nil)
        local headTypeIdx = math.max(1, math.floor(tonumber(ch.head_type) or 1))
        local headMdl = resolvePreviewModel(gdata and pickCardEntry(gdata.head, headTypeIdx) or nil)
        local accessoryMdl = self.ResolveSpiritAccessoryModel and resolvePreviewModel(self:ResolveSpiritAccessoryModel(ch.faction, ch.spirit_accessory)) or nil
        local accessoryData = (self.NormalizeSpiritAccessoryTransform and self:NormalizeSpiritAccessoryTransform(ch.faction, ch.spirit_accessory, ch.spirit_accessory_data)) or nil
        if not baseMdl then baseMdl = resolvePreviewModel(gdata and (pickCardEntry(gdata.body) or pickCardEntry(gdata.model)) or nil) or CHAR_PREVIEW_MDL end
        local skinIndex = math.Clamp(math.floor(tonumber(ch.skin_tone) or 1), 1, math.max(1, #skinPalette))
        local skinColor = skinPalette[skinIndex] or DEFAULT_SKIN_TONES[1]
        if tostring(ch.faction or "") == "spirit" and isstring(ch.skin_color) and ch.skin_color ~= "" then skinColor = parseStoredColor(ch.skin_color, skinColor) end
        local hairColor = parseStoredColor(ch.hair_color, DEFAULT_HAIR_COLOR)
        local modelScale = self.GetHeightScale and self:GetHeightScale(ch.height) or 1
        local app = {
            -- On passe toujours le modèle de base pour que AutoCamera calcule
            -- la bonne position de caméra (bounds du modèle humanoid standard)
            bodyModel = baseMdl,
            headModel = headMdl,
            bodyStyle = ch.body_style,
            headStyle = ch.head_style,
            hairStyle = ch.hair_style,
            skinColor = skinColor,
            hairColor = hairColor,
            modelScale = modelScale,
        }

        local preview = CP:CreateFromAppearance(parent, app)
        if not IsValid(preview) then return nil end
        preview:SetSize(R:XY(438, 520))
        preview:SetPos(R:XY(44, 150))
        local root = preview.Entity
        if IsValid(root) and CH.HideBuiltInHeadBodygroups and IsValid(preview._headEnt) then CH.HideBuiltInHeadBodygroups(root) end

        -- Après que la caméra est calculée sur le modèle de base, on switche
        -- l'entité sur le modèle de tenue équipée pour l'affichage
        if equippedMdl and IsValid(root) then
            root:SetModel(equippedMdl)
            root:SetModelScale(modelScale, 0)
            -- Réappliquer l'animation idle (SetModel la remet en T-pose)
            applySelectIdle(root)
        end
        preview._accessoryEnt = CP.SpawnMerged(accessoryMdl, IsValid(preview._headEnt) and preview._headEnt or root, false)
        if IsValid(preview._accessoryEnt) then
            if self.ApplySpiritAccessoryClientTransform then
                self:ApplySpiritAccessoryClientTransform(preview._accessoryEnt, modelScale, accessoryData)
            else
                preview._accessoryEnt:SetModelScale(modelScale, 0)
            end
        end

        local eyebrowColor = parseStoredColor(ch.eyebrow_color, hairColor)
        local eyeColor = parseStoredColor(ch.eye_color, DEFAULT_EYE_COLOR)
        preview._skinColor = skinColor
        preview._hairColor = hairColor
        -- Dégradé de cheveux : si une couleur de pointes est enregistrée (chaîne non
        -- vide), on prépare le dégradé racines(hairColor) → pointes(tipColor).
        if isstring(ch.hair_tip_color) and ch.hair_tip_color ~= "" then
            preview._hairTipColor = parseStoredColor(ch.hair_tip_color, hairColor)
        else
            preview._hairTipColor = nil
        end
        preview._eyebrowStyle = math.Clamp(math.floor(tonumber(ch.eyebrow_style) or 1), 1, getEyebrowStyleCount())
        preview._eyebrowColor = eyebrowColor
        preview._irisStyle = math.Clamp(math.floor(tonumber(ch.iris_style) or 1), 1, getEyeStyleCount())
        local defaultIrisSize = CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100
        preview._irisSize = CH.NormalizeIrisSize and CH:NormalizeIrisSize(tonumber(ch.iris_size) or defaultIrisSize) or math.Clamp(math.floor(tonumber(ch.iris_size) or defaultIrisSize), 40, 200)
        preview._eyeColor = eyeColor
        preview._flex = (CH.NormalizeFlexTable and CH:NormalizeFlexTable(ch.flex)) or {}
        preview._accessoryData = accessoryData
        preview._bodyMarks = (self.GetResolvedBodyMarks and self:GetResolvedBodyMarks(ch.faction, ch.body_marks)) or {}
        preview._markEnts = {}
        preview._markEnts = syncBodyMarkLayerSet(preview._headEnt, preview._markEnts, preview._bodyMarks, "select_" .. tostring(ch.id or "card"))
        preview.PreDrawModel = function(s, ent)
            if not IsValid(ent) then return end
            setSelectEntityTint(ent, s._skinColor or DEFAULT_SKIN_TONES[1], isSkinMaterialName)
        end

        preview.LayoutEntity = function(s, ent)
            if not IsValid(ent) then return end
            ent:SetAngles(Angle(0, 0, 0))
            ent:FrameAdvance(FrameTime())
            ent:InvalidateBoneCache()
            ent:SetupBones()
            if IsValid(s._headEnt) then
                s._headEnt:InvalidateBoneCache()
                s._headEnt:SetupBones()
            end

            if IsValid(s._accessoryEnt) then
                if self.ApplySpiritAccessoryClientTransform then self:ApplySpiritAccessoryClientTransform(s._accessoryEnt, modelScale, s._accessoryData) end
                s._accessoryEnt:InvalidateBoneCache()
                s._accessoryEnt:SetupBones()
            end
        end

        preview.PostDrawModel = function(s)
            if IsValid(s._headEnt) then
                if IsColor(s._hairTipColor) and CH.SetEntityHairGradient then
                    -- Dégradé : racines = _hairColor (haut), pointes = _hairTipColor (bas).
                    -- SetEntityHairGradient(ent, c1=bas/pointes, c2=haut/racines).
                    CH.SetEntityHairGradient(s._headEnt, s._hairTipColor, s._hairColor or DEFAULT_HAIR_COLOR)
                elseif CH.SetEntityHairColor then
                    CH.SetEntityHairColor(s._headEnt, s._hairColor or DEFAULT_HAIR_COLOR)
                end
                if CH.SetEntityEyebrowColor then
                    CH.SetEntityEyebrowColor(s._headEnt, s._eyebrowColor or s._hairColor or DEFAULT_HAIR_COLOR)
                else
                    applyEntityEyebrowMaterial(s._headEnt, s._eyebrowStyle or 1)
                    setEyebrowMaterialTint(s._eyebrowStyle or 1, s._eyebrowColor or s._hairColor or DEFAULT_HAIR_COLOR)
                end
                if CH.SetEntityIris then
                    CH.SetEntityIris(s._headEnt, s._irisStyle or 1, s._irisSize or (CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100), s._eyeColor or color_white)
                else
                    applyEntityEyeMaterial(s._headEnt, s._irisStyle or 1)
                    setEyeMaterialTint(s._irisStyle or 1, color_white)
                    setEyeMaterialSize(s._headEnt, s._irisStyle or 1, s._irisSize or (CH.GetDefaultIrisSize and CH:GetDefaultIrisSize() or 100))
                end
                if CH.SetEntitySkinColorRuntime then
                    CH.SetEntitySkinColorRuntime(s._headEnt, s._skinColor or DEFAULT_SKIN_TONES[1])
                else
                    setSelectEntityTint(s._headEnt, s._skinColor or DEFAULT_SKIN_TONES[1], isSkinMaterialName)
                end

                if CH.ApplyFlex and s._flex then CH.ApplyFlex(s._headEnt, s._flex) end
                s._headEnt:DrawModel()
                setEyebrowMaterialTint(s._eyebrowStyle or 1, color_white)
                setEyeMaterialTint(s._irisStyle or 1, color_white)
                drawBodyMarkLayerSet(s._markEnts)
            end

            if IsValid(s._accessoryEnt) then s._accessoryEnt:DrawModel() end
            setSelectEntityTint(root, color_white, isSkinMaterialName)
        end

        local baseOnRemove = preview.OnRemove
        preview.OnRemove = function(s)
            s._markEnts = clearBodyMarkLayerSet(s._markEnts)
            if IsValid(s._accessoryEnt) then s._accessoryEnt:Remove() end
            s._accessoryEnt = nil
            s._markEnts = nil
            if baseOnRemove then baseOnRemove(s) end
        end
        return preview
    end

    local gridWrap = vgui.Create("DPanel", characterSelectFrame)
    gridWrap:Dock(FILL)
    gridWrap:DockMargin(0, R:Y(20), 0, R:Y(20))
    gridWrap.Paint = nil
    local cardW, cardH = 527, 790
    local spacingX, spacingY = 70, 70
    local maxCols = math.Clamp(math.floor((scrw + spacingX) / (cardW + spacingX)), 1, 4)
    local cols = math.min(maxCols, visibleSlots)
    local rows = math.ceil(visibleSlots / cols)
    local totalW = cols * cardW + (cols - 1) * spacingX
    local totalH = rows * cardH + (rows - 1) * spacingY
    local startX = (scrw - totalW) / 2
    local startY = (scrh - totalH) / 2
    local allowSelfDelete = self.CanDeleteOwnCharacters and self:CanDeleteOwnCharacters(LocalPlayer())
    for slot = 1, visibleSlots do
        local ch = characters[slot]
        local idx = slot - 1
        local col = idx % cols
        local row = math.floor(idx / cols)
        local x = startX + col * (cardW + spacingX)
        local y = startY + row * (cardH + spacingY)
        local card = vgui.Create("VCSlotCard", gridWrap)
        card:SetSize(R:XY(cardW, cardH))
        card:SetPos(R:XY(x, y))
        local factionCfg = (ch and self:FactionsEnabled() and isstring(ch.faction) and cfg.Factions and cfg.Factions[ch.faction]) or nil
        local factionName = factionCfg and tostring(factionCfg.name or ch.faction or "") or tostring((ch and ch.faction) or "")
        local displayName = ch and self:GetDisplayName(ch) or ""
        local ply = LocalPlayer()
        local levelValue = math.max(1, math.floor(tonumber(
            (ch and ch.level and ch.level > 0 and ch.level) or 1
        ) or 1))
        local levelText = ("Niveau %d"):format(levelValue)
        local bgKey = (ch and isstring(ch.faction) and ch.faction ~= "") and ("character_" .. ch.faction .. "_fraction_background") or "character_create_char_back"
        card:SetSlot(slot)
        card:SetCharacter(ch)
        card:SetTextData(factionName, displayName, levelText)
        card:SetBackgroundMaterial(bgKey)
        card:SetActionHandlers(function(playSlot, _)
            CH:RequestSelect(playSlot)
            if IsValid(characterSelectFrame) then characterSelectFrame:Notify(Language("character.select_character"), 3) end
        end, function(createSlot)
            if IsValid(characterSelectFrame) then characterSelectFrame:Close() end
            if CH.FactionsEnabled and CH:FactionsEnabled() then
                CH:FactionSelect(createSlot)
            else
                CH:CharacterCreate(createSlot)
            end
        end, function(deleteSlot) CH:RequestDelete(deleteSlot) end)

        card:SetDeleteEnabled(ch and allowSelfDelete or false)
        if ch then
            local preview = buildCharacterCardPreview(card, ch)
            if IsValid(preview) then preview:SetZPos(32767) end
        end

        bindAnimatedCard(card, R:X(x), R:Y(y), {
            hoverLift = R:Y(10),
            pressDrop = R:Y(5),
            clickDuration = 0.12,
        })
    end
end