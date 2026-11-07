-- vgui/cl_60_packtenue.lua
-- Page "Pack Tenue" de la boutique.
-- Panneau gauche : prévisualisation du modèle avec navigation ← → et drag-to-rotate.
-- Grille de packs (3 par ligne, scroll) à droite.
-- ─────────────────────────────────────────────────────────────────────────────

local BT        = VERSE.Boutique
local R         = VERSE.Responsive
local Font      = VERSE.Fonts
local Materials = VERSE.Materials
local _ui       = BT._ui

-- ─── Références actives ───────────────────────────────────────────────────────
local _activePreview = nil   -- DModelPanel courant

-- ─── État de navigation et rotation (persistant entre navigations) ────────────
local _ps = {
    packId    = nil,  -- détecte le changement de pack → reset index
    index     = 1,    -- index de l'outfit affiché (1-based)
    angle     = 0,    -- angle de rotation courant (degrés)
    dragging  = false,
    lastMouseX = 0,
}

-- ─── Cache matériaux coffre ───────────────────────────────────────────────────
local _chestMatCache = {}
local function getChestMat(src)
    src = tostring(src or ""):Trim()
    if src == "" then return nil end
    if _chestMatCache[src] ~= nil then return _chestMatCache[src] end
    local mats = VERSE.Materials
    if mats and mats._aliases and mats._aliases[src] then
        src = mats._aliases[src]
    end
    local mat = Material(src, "noclamp smooth")
    if mat and not mat:IsError() then
        _chestMatCache[src] = mat
        return mat
    end
    _chestMatCache[src] = false
    return nil
end

local function drawChest(src, x, y, w, h)
    local mat = getChestMat(src)
    if not mat then return end
    surface.SetMaterial(mat)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(x, y, w, h)
end

-- ─── Head + apparence du joueur pour la prévisualisation ─────────────────────
local function parseColorStr(raw, default)
    if not isstring(raw) or raw == "" then return default end
    local p = string.Explode(",", raw)
    local r, g, b = tonumber(p[1]), tonumber(p[2]), tonumber(p[3])
    if not r or not g or not b then return default end
    return Color(r, g, b, tonumber(p[4]) or 255)
end

-- headEnt : entité tête (cheveux, peau visage, pupilles)
-- bodyEnt : entité corps/tenue (peau bras, mains, cou)
local function applyPlayerAppearance(headEnt, bodyEnt)
    local CH  = VERSE.Characters
    if not CH then return end
    local sel = CH.Client and CH.Client.selected
    if not istable(sel) then return end

    -- Couleur de peau (tête + corps)
    if CH.SetEntitySkinColorRuntime then
        local col = parseColorStr(isstring(sel.skin_color) and sel.skin_color or "", nil)
        if not col then
            local idx = math.max(1, math.floor(tonumber(sel.skin_tone) or 1))
            local cfg = VERSE.Config and VERSE.Config.Characters
            local pal = cfg and cfg.SkinColorPalette or {}
            col = pal[math.Clamp(idx, 1, math.max(1, #pal))] or Color(255, 244, 230)
        end
        if IsValid(headEnt) then CH.SetEntitySkinColorRuntime(headEnt, col) end
        if IsValid(bodyEnt) then CH.SetEntitySkinColorRuntime(bodyEnt, col) end
    end

    -- Couleur de cheveux (tête uniquement)
    if CH.SetEntityHairColor and IsValid(headEnt) then
        local col = parseColorStr(isstring(sel.hair_color) and sel.hair_color or "", Color(50, 50, 50))
        CH.SetEntityHairColor(headEnt, col)
    end

    -- Pupilles : style + taille + couleur (tête uniquement)
    if CH.SetEntityIris and IsValid(headEnt) then
        local style = math.max(1, math.floor(tonumber(sel.iris_style) or 1))
        local size  = math.Clamp(math.floor(tonumber(sel.iris_size) or 100), 40, 200)
        local col   = parseColorStr(isstring(sel.eye_color) and sel.eye_color or "", Color(255, 255, 255))
        CH.SetEntityIris(headEnt, style, size, col)
    end
end

local function getPlayerHeadModel()
    local CH = VERSE.Characters
    if not CH then return nil end
    local sel = CH.Client and CH.Client.selected
    if not istable(sel) then return nil end
    local cfg = VERSE.Config and VERSE.Config.Characters
    if not cfg then return nil end
    local factionCfg = cfg.Factions and isstring(sel.faction) and cfg.Factions[sel.faction] or nil
    if not factionCfg then return nil end
    local gender = tostring(sel.gender or "male")
    local gdata = CH.GetFactionGenderData and CH:GetFactionGenderData(factionCfg, gender) or nil
    if not gdata or not gdata.head then return nil end
    local idx = math.max(1, math.floor(tonumber(sel.head_type) or 1))
    if istable(gdata.head) then return gdata.head[idx] or gdata.head[1] or nil end
    if isstring(gdata.head) then return gdata.head end
    return nil
end

local function spawnHeadCSM(bodyEnt, headMdl)
    if not IsValid(bodyEnt) or not isstring(headMdl) or headMdl == "" then return nil end
    local ent = ClientsideModel(headMdl)
    if not IsValid(ent) then return nil end
    ent:SetPos(bodyEnt:GetPos())
    ent:SetAngles(bodyEnt:GetAngles())
    ent:SetNoDraw(true)
    ent:SetParent(bodyEnt)
    ent:RemoveEffects(EF_BONEMERGE)
    ent:RemoveEffects(EF_BONEMERGE_FASTCULL)
    ent:RemoveEffects(EF_PARENT_ANIMATES)
    ent:AddEffects(EF_BONEMERGE)
    ent:AddEffects(EF_BONEMERGE_FASTCULL)
    ent:AddEffects(EF_PARENT_ANIMATES)
    ent:SetLocalPos(Vector(0, 0, 0))
    ent:SetLocalAngles(Angle(0, 0, 0))
    ent:InvalidateBoneCache()
    ent:SetupBones()
    -- Applique les bodygroups tete et cheveux du joueur
    local sel = VERSE.Characters and VERSE.Characters.Client and VERSE.Characters.Client.selected
    if istable(sel) then
        local headStyle = tonumber(sel.head_style) or 0
        local hairStyle = tonumber(sel.hair_style) or 0
        if headStyle > 0 then ent:SetBodygroup(0, headStyle) end
        if hairStyle > 0 then ent:SetBodygroup(1, hairStyle) end
    end
    return ent
end

-- ─── Cleanup ─────────────────────────────────────────────────────────────────
local function destroyPreview()
    if IsValid(_activePreview) then _activePreview:Remove() end
    _activePreview = nil
    _ps.dragging   = false
end

-- ─── Helpers pack ─────────────────────────────────────────────────────────────
local function getPackList()
    local packs = BT.PackTenuePacks or {}
    local list  = {}
    for _, p in pairs(packs) do list[#list + 1] = p end
    table.sort(list, function(a, b)
        return (tonumber(a.sort_order) or 0) < (tonumber(b.sort_order) or 0)
    end)
    return list
end

local function getSelectedPack()
    local id    = BT._state.selected.pack_tenue
    local packs = BT.PackTenuePacks or {}
    if id and packs[id] then return packs[id] end
    return getPackList()[1]
end

local function setSelectedPack(packId)
    BT._state.selected.pack_tenue = packId
    BT:RebuildContent()
end

local function getOutfitName(outfit)
    if not outfit then return "?" end
    local def = (BT.OutfitItems or {})[tostring(outfit.id or "")]
    return (def and def.name) or tostring(outfit.id or "?")
end

local function getOutfitModel(outfit)
    if not outfit then return "" end
    local def = (BT.OutfitItems or {})[tostring(outfit.id or "")]
    return tostring((def and def.model) or outfit.model or "")
end

-- ─── Constantes couleur (pré-allouées — jamais recréées dans Paint) ──────────
local _PT_COL_CARD_SEL_OUT     = Color(0,   187, 255, 255)
local _PT_COL_CARD_HOV_OUT     = Color(255, 255, 255, 100)
local _PT_COL_CARD_PRICE       = Color(225, 225, 225, 255)
local _PT_COL_GENDER_MALE      = Color(100, 180, 255, 255)
local _PT_COL_GENDER_FEMALE    = Color(255, 140, 200, 255)
local _PT_COL_GENDER_FILL_M    = Color(100, 180, 255, 55)
local _PT_COL_GENDER_FILL_F    = Color(255, 140, 200, 55)
local _PT_COL_TT_BG            = Color(8,   6,   20,  248)
local _PT_COL_TT_OUT           = Color(255, 255, 255, 40)
local _PT_COL_TT_TITLE         = Color(255, 215, 80,  255)
local _PT_COL_TT_PCT           = Color(155, 215, 155, 255)
local _PT_COL_HELP_BG          = Color(0,   0,   0,   180)  -- .a muté
local _PT_COL_HELP_OUT         = Color(255, 255, 255, 100)   -- .a muté
local _PT_COL_NAV_BG           = Color(255, 255, 255, 22)    -- .a muté
local _PT_COL_NAV_OUT          = Color(255, 255, 255, 50)    -- .a muté
local _PT_COL_NAV_TXT_BRIGHT   = Color(255, 255, 255, 255)
local _PT_COL_NAV_TXT_DIM      = Color(200, 200, 200, 255)
local _PT_COL_INFO_COUNTER     = Color(160, 160, 185, 255)
local _PT_COL_DOT_ACTIVE       = Color(0,   187, 255, 255)
local _PT_COL_DOT_INACTIVE     = Color(255, 255, 255, 60)
local _PT_COL_RES_BG           = Color(12,  8,   30,  240)
local _PT_COL_RES_OUT          = Color(0,   187, 255, 255)
local _PT_COL_RES_NAME         = Color(0,   187, 255, 255)
local _PT_COL_RES_BTN          = Color(0,   187, 255, 160)  -- .a muté
local _PT_COL_OVL_DARK         = Color(0,   0,   0,   160)
local _PT_COL_OVL_FLASH        = Color(255, 255, 255, 0)    -- .a muté
local _PT_COL_MACH_BG          = Color(8,   4,   22,  245)
local _PT_COL_MACH_OUT         = Color(138, 80,  255, 160)
local _PT_COL_MACH_TITLE       = Color(160, 120, 255, 255)
local _PT_COL_MACH_CTR_FILL    = Color(138, 80,  255, 18)
local _PT_COL_SLOT_BG_CTR      = Color(18,  12,  38,  220)  -- (isC)
local _PT_COL_SLOT_BG_SIDE     = Color(18,  12,  38,  150)
local _PT_COL_SLOT_OUT_CTR     = Color(255, 255, 255, 60)   -- (isC)
local _PT_COL_SLOT_OUT_SIDE    = Color(255, 255, 255, 20)
local _PT_COL_STATUS_REVEAL    = Color(200, 160, 255, 255)
local _PT_COL_STATUS_SPIN      = Color(140, 120, 180, 255)
local _PT_COL_CLOSE_BG         = Color(55,  35,  100, 140)  -- .a muté
local _PT_COL_CLOSE_OUT        = Color(138, 80,  255, 90)   -- .a muté
local _PT_COL_CLOSE_TXT        = Color(210, 190, 255, 255)
local _PT_COL_DIVIDER          = Color(255, 255, 255, 255)
local _PT_COL_VBAR_BG          = Color(20,  15,  35,  200)
local _PT_COL_VBAR_GRIP        = Color(138, 80,  255, 255)
local _PT_COL_BUY_BG           = Color(100, 45,  175, 180)  -- .a muté
local _PT_COL_BUY_OUT          = Color(160, 90,  255, 110)  -- .a muté
local _PT_COL_BUY_BUSY_TXT     = Color(160, 140, 200, 255)
local _PT_COL_BUY_PRICE        = Color(255, 210, 80,  255)

-- ─── Constantes de grille ─────────────────────────────────────────────────────
local COLS     = 3
local CARD_W   = 342
local CARD_H   = 342
local COL_STEP = 377
local ROW_STEP = 369
local GRID_X   = 666
local GRID_Y   = 220
local GRID_W   = 1230
local GRID_H   = 840
local CARD_OX  = 758 - GRID_X
local CARD_OY  = 235 - GRID_Y

-- ─── Carte de pack ───────────────────────────────────────────────────────────
local function buildPackCard(parent, pack)
    local btn = vgui.Create("DButton", parent)
    btn:SetSize(R:X(CARD_W), R:Y(CARD_H))
    btn:SetText("")

    local _cardNameFont  = Font:GetNamed("Poppins", "SemiBold", 20)
    local _cardPriceFont = Font:GetNamed("Poppins", "Medium",   15)
    local _cardGenderFont = Font:GetNamed("Poppins", "Bold",    15)

    btn.Paint = function(s, w, h)
        local sel     = getSelectedPack()
        local selected = sel and sel.id == pack.id
        local hovered  = s:IsHovered()

        Materials:Draw(color_white, "pack_tenue_card_bg", 0, 0, w, h, "noclamp smooth")

        if selected then
            RNDX.DrawOutlined(R:Y(16), 0, 0, w, h, _PT_COL_CARD_SEL_OUT, 3)
        elseif hovered then
            RNDX.DrawOutlined(R:Y(16), 0, 0, w, h, _PT_COL_CARD_HOV_OUT, 2)
        end

        local chestSrc = (pack.chest_img and pack.chest_img ~= "") and pack.chest_img
                      or (pack.icon     and pack.icon     ~= "") and pack.icon
                      or nil
        if chestSrc then
            -- Zone image = tout sauf les deux lignes de texte en bas (~90px)
            local textZone = R:Y(90)
            local iw = w * 0.75
            local ih = iw
            local ix = (w - iw) * 0.5
            local iy = ((h - textZone) - ih) * 0.5
            drawChest(chestSrc, ix, iy, iw, ih)
        end

        draw.SimpleText(pack.name,
            _cardNameFont,
            w * 0.5, h - R:Y(64), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.SimpleText(tostring(pack.price) .. " coins",
            _cardPriceFont,
            w * 0.5, h - R:Y(34), _PT_COL_CARD_PRICE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Icône genre (haut-droite) si défini sur le pack
        local gender = tostring(pack.gender or "")
        if gender == "male" or gender == "female" then
            local gIcon      = gender == "male" and "♂" or "♀"
            local gColor     = gender == "male" and _PT_COL_GENDER_MALE   or _PT_COL_GENDER_FEMALE
            local gColorFill = gender == "male" and _PT_COL_GENDER_FILL_M or _PT_COL_GENDER_FILL_F
            local gr     = R:Y(13)
            local gx     = w - R:X(14) - gr * 2
            local gy     = R:Y(12)
            draw.RoundedBox(gr, gx, gy, gr * 2, gr * 2, gColorFill)
            draw.SimpleText(gIcon,
                _cardGenderFont,
                gx + gr, gy + gr, gColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    btn.DoClick = function() setSelectedPack(pack.id) end
    return btn
end

-- ─── Chargement d'un modèle dans le container ─────────────────────────────────
local function loadModelInto(container, outfit)
    container:Clear()
    if IsValid(_activePreview) then _activePreview:Remove() end
    _activePreview = nil
    _ps.dragging   = false

    local mdlPath = getOutfitModel(outfit)
    if mdlPath == "" then return end

    local mdl = vgui.Create("DModelPanel", container)
    mdl:SetPos(0, 0)
    mdl:SetSize(container:GetWide(), container:GetTall())
    mdl:SetPaintBackground(false)
    mdl:SetAnimated(true)
    mdl:SetModel(mdlPath)
    mdl:SetMouseInputEnabled(true)

    local ent = mdl:GetEntity()
    local headEnt  = nil
    local camReady = false
    local FOV      = 26
    mdl:SetFOV(FOV)

    if IsValid(ent) then
        -- Fusion de la tête du joueur sur la tenue
        local headMdl = getPlayerHeadModel()
        if headMdl then
            headEnt = spawnHeadCSM(ent, headMdl)
            local CH = VERSE.Characters
            if IsValid(headEnt) and CH and CH.HideBuiltInHeadBodygroups then
                CH.HideBuiltInHeadBodygroups(ent)
            end
        end
    end

    -- Rotation : auto quand libre, pilotée par la souris si drag.
    -- La caméra est repositionnée une seule fois dès que les bounds
    -- du modèle sont non-nulles (évite le zoom au chargement).
    mdl.LayoutEntity = function(_, e)
        if IsValid(e) then
            if not camReady then
                local mn, mx = e:GetRenderBounds()
                local sz     = mx - mn
                if sz:Length() > 1 then
                    local center = (mn + mx) * 0.5
                    local radius = math.max(sz.x, sz.y, sz.z) * 0.5
                    local dist   = (radius / math.tan(math.rad(FOV * 0.5))) * 1.05
                    local lookAt = center + Vector(0, 0, 8)
                    mdl:SetLookAt(lookAt)
                    mdl:SetCamPos(lookAt + Vector(dist, dist * 0.04, dist * 0.04))
                    camReady = true
                end
            end
            if not _ps.dragging then
                _ps.angle = (_ps.angle + FrameTime() * 26) % 360
            end
            e:SetAngles(Angle(0, _ps.angle, 0))
        end
        if IsValid(headEnt) then
            headEnt:InvalidateBoneCache()
            headEnt:SetupBones()
        end
    end

    -- Rendu de la tête après le corps.
    -- Appliqué chaque frame tant que les matériaux sont chargés :
    -- garantit que cheveux/peau/pupilles s'appliquent même si le cache
    -- interne de cl_character n'était pas encore prêt au 1er frame.
    mdl.PostDrawModel = function()
        local bodyEnt = mdl:GetEntity()
        local headReady = IsValid(headEnt) and #(headEnt:GetMaterials() or {}) > 0
        local bodyReady = IsValid(bodyEnt) and #(bodyEnt:GetMaterials() or {}) > 0
        if headReady or bodyReady then
            applyPlayerAppearance(headReady and headEnt or nil, bodyReady and bodyEnt or nil)
        end
        if IsValid(headEnt) then headEnt:DrawModel() end
    end

    -- Drag-to-rotate
    mdl.OnMousePressed = function(s, mc)
        if mc == MOUSE_LEFT then
            _ps.dragging   = true
            _ps.lastMouseX = gui.MouseX()
            s:MouseCapture(true)
        end
    end
    mdl.OnMouseReleased = function(s, mc)
        if mc == MOUSE_LEFT then
            _ps.dragging = false
            s:MouseCapture(false)
        end
    end
    mdl.Think = function()
        if _ps.dragging then
            local mx    = gui.MouseX()
            local delta = mx - _ps.lastMouseX
            _ps.lastMouseX = mx
            _ps.angle = (_ps.angle + delta * 1.3) % 360
        end
    end

    mdl.OnRemove = function()
        if IsValid(headEnt) then headEnt:Remove() end
        headEnt = nil
        if _activePreview == mdl then _activePreview = nil end
        _ps.dragging = false
    end

    _activePreview = mdl
end

-- ─── Panneau gauche ───────────────────────────────────────────────────────────
local function buildLeftPanel(parent, pack)
    local PW = R:X(449)
    local PH = R:Y(650)

    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(R:XY(120, 226))
    panel:SetSize(PW, PH)

    local _leftNoneFont = Font:GetNamed("Poppins", "SemiBold", 22)
    local _leftNameFont = Font:GetNamed("Poppins", "SemiBold", 30)
    panel.Paint = function(_, w, h)
        Materials:Draw(color_white, "pack_tenue_left_bg", 0, 0, w, h, "noclamp smooth")
        if not pack then
            draw.SimpleText("Aucun pack disponible",
                _leftNoneFont,
                w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        -- Nom du pack (haut)
        draw.SimpleText(pack.name,
            _leftNameFont,
            w * 0.5, R:Y(34), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    end

    if not pack then return panel end

    -- Reset de l'index si on change de pack
    if _ps.packId ~= pack.id then
        _ps.packId = pack.id
        _ps.index  = 1
        _ps.angle  = 0
    end

    local outfits = pack.outfits or {}
    local total   = #outfits
    if total == 0 then return panel end
    _ps.index = math.Clamp(_ps.index, 1, total)

    -- ── Bouton "!" chances de tirage (coin haut-droite) ───────────────────────
    local helpBtnSize = R:Y(26)
    local helpPad     = R:X(10)
    local helpBtn     = vgui.Create("DButton", panel)
    helpBtn:SetText("")
    helpBtn:SetPos(PW - helpBtnSize - helpPad, helpPad)
    helpBtn:SetSize(helpBtnSize, helpBtnSize)
    helpBtn:SetCursor("hand")

    local function getOutfitChances()
        local totalW = 0
        for _, o in ipairs(outfits) do
            totalW = totalW + math.Clamp(math.floor(tonumber(o.weight) or 50), 1, 100)
        end
        if totalW <= 0 then return {} end
        local chances = {}
        for _, o in ipairs(outfits) do
            local w = math.Clamp(math.floor(tonumber(o.weight) or 50), 1, 100)
            chances[#chances + 1] = {
                name   = getOutfitName(o),
                chance = (w / totalW) * 100,
            }
        end
        return chances
    end

    local _ttTitleFont = Font:GetNamed("Poppins", "Bold",    13)
    local _ttEntryFont = Font:GetNamed("Poppins", "Regular", 11)
    local function drawTenueTooltip()
        local chances = getOutfitChances()
        if #chances == 0 then return end

        local pad      = 10
        local lineH    = 18
        local titleH   = 22
        local gapH     = 6
        local tooltipW = 220
        local tooltipH = math.ceil(pad * 2 + titleH + gapH + #chances * lineH)

        local bx, by = helpBtn:GetPos()
        local tx = bx + helpBtn:GetWide() - tooltipW
        local ty = by + helpBtn:GetTall() + 4

        RNDX.Draw(10, tx, ty, tooltipW, tooltipH, _PT_COL_TT_BG)
        RNDX.DrawOutlined(10, tx, ty, tooltipW, tooltipH, _PT_COL_TT_OUT, 1)

        local cy = ty + pad

        draw.SimpleText("Chances de Tirage", _ttTitleFont, tx + tooltipW * 0.5, cy + titleH * 0.5,
            _PT_COL_TT_TITLE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cy = cy + titleH + gapH

        for _, entry in ipairs(chances) do
            local pctStr = string.format("%.1f%%", entry.chance)
            draw.SimpleText(entry.name, _ttEntryFont, tx + pad, cy + lineH * 0.5,
                color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(pctStr, _ttEntryFont, tx + tooltipW - pad, cy + lineH * 0.5,
                _PT_COL_TT_PCT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            cy = cy + lineH
        end
    end

    local _helpBtnFont = Font:GetNamed("Poppins", "Bold", math.floor(helpBtnSize * 0.6))
    helpBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        _PT_COL_HELP_BG.a  = hov and 210 or 180
        _PT_COL_HELP_OUT.a = hov and 180 or 100
        RNDX.Draw(w * 0.5, 0, 0, w, h, _PT_COL_HELP_BG)
        RNDX.DrawOutlined(w * 0.5, 0, 0, w, h, _PT_COL_HELP_OUT, 1)
        draw.SimpleText("!", _helpBtnFont,
            w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if hov then
            DisableClipping(true)
            drawTenueTooltip()
            DisableClipping(false)
        end
    end

    -- ── Container du DModelPanel ──────────────────────────────────────────────
    local MDL_Y = R:Y(58)
    local MDL_H = R:Y(490)
    local modelCtn = vgui.Create("DPanel", panel)
    modelCtn:SetPos(R:X(10), MDL_Y)
    modelCtn:SetSize(PW - R:X(20), MDL_H)
    modelCtn.Paint = function() end

    -- Charge le modèle de l'outfit courant
    loadModelInto(modelCtn, outfits[_ps.index])

    -- ── Barre de navigation ───────────────────────────────────────────────────
    local NAV_Y  = MDL_Y + MDL_H + R:Y(18)
    local NAV_H  = R:Y(40)
    local BTNW   = R:X(40)
    local PAD    = R:X(14)

    -- Bouton ‹ (précédent)
    local _navArrowFont = Font:GetNamed("Poppins", "Bold", 24)
    local prevBtn = vgui.Create("DButton", panel)
    prevBtn:SetPos(PAD, NAV_Y)
    prevBtn:SetSize(BTNW, NAV_H)
    prevBtn:SetText("")
    prevBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        _PT_COL_NAV_BG.a  = hov and 50 or 22
        _PT_COL_NAV_OUT.a = hov and 120 or 50
        RNDX.Draw(R:Y(8), 0, 0, w, h, _PT_COL_NAV_BG)
        RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, _PT_COL_NAV_OUT)
        draw.SimpleText("‹", _navArrowFont,
            w * 0.5, h * 0.5, hov and _PT_COL_NAV_TXT_BRIGHT or _PT_COL_NAV_TXT_DIM,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    prevBtn.DoClick = function()
        if total <= 1 then return end
        _ps.index = ((_ps.index - 2) % total) + 1
        loadModelInto(modelCtn, outfits[_ps.index])
    end

    -- Zone centrale : nom de la tenue + compteur
    local _infoNameFont    = Font:GetNamed("Poppins", "SemiBold", 15)
    local _infoCounterFont = Font:GetNamed("Poppins", "Regular",  12)
    local infoW = PW - PAD * 2 - BTNW * 2 - R:X(8)
    local infoPanel = vgui.Create("DPanel", panel)
    infoPanel:SetPos(PAD + BTNW + R:X(4), NAV_Y)
    infoPanel:SetSize(infoW, NAV_H)
    infoPanel.Paint = function(_, w, h)
        local outfit  = outfits[_ps.index]
        local name    = getOutfitName(outfit)
        local counter = tostring(_ps.index) .. " / " .. tostring(total)
        draw.SimpleText(name,
            _infoNameFont,
            w * 0.5, h * 0.38, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(counter,
            _infoCounterFont,
            w * 0.5, h * 0.76, _PT_COL_INFO_COUNTER, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Bouton › (suivant)
    local nextBtn = vgui.Create("DButton", panel)
    nextBtn:SetPos(PW - PAD - BTNW, NAV_Y)
    nextBtn:SetSize(BTNW, NAV_H)
    nextBtn:SetText("")
    nextBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        _PT_COL_NAV_BG.a  = hov and 50 or 22
        _PT_COL_NAV_OUT.a = hov and 120 or 50
        RNDX.Draw(R:Y(8), 0, 0, w, h, _PT_COL_NAV_BG)
        RNDX.DrawOutlined(R:Y(8), 0, 0, w, h, _PT_COL_NAV_OUT)
        draw.SimpleText("›", _navArrowFont,
            w * 0.5, h * 0.5, hov and _PT_COL_NAV_TXT_BRIGHT or _PT_COL_NAV_TXT_DIM,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    nextBtn.DoClick = function()
        if total <= 1 then return end
        _ps.index = (_ps.index % total) + 1
        loadModelInto(modelCtn, outfits[_ps.index])
    end

    -- Indicateurs de page (petits points)
    if total > 1 then
        local dotPanel = vgui.Create("DPanel", panel)
        dotPanel:SetPos(0, NAV_Y + NAV_H + R:Y(6))
        dotPanel:SetSize(PW, R:Y(10))
        dotPanel.Paint = function(_, w, h)
            local DOT_R   = R:Y(4)
            local DOT_GAP = R:Y(7)
            local dotsTotalW = total * (DOT_R * 2) + (total - 1) * DOT_GAP
            local dx = (w - dotsTotalW) * 0.5
            for i = 1, total do
                local col = (i == _ps.index) and _PT_COL_DOT_ACTIVE or _PT_COL_DOT_INACTIVE
                draw.RoundedBox(DOT_R, dx, (h - DOT_R * 2) * 0.5, DOT_R * 2, DOT_R * 2, col)
                dx = dx + DOT_R * 2 + DOT_GAP
            end
        end
    end

    return panel
end

-- ─── Popup résultat d'achat ───────────────────────────────────────────────────
local function showResult(outfitData)
    if not IsValid(BT._frame) then return end

    local overlay = vgui.Create("DPanel", BT._frame)
    overlay:SetSize(R:XY(520, 420))
    overlay:SetPos(
        R:X(1920) * 0.5 - R:X(260),
        R:Y(1080) * 0.5 - R:Y(210))
    overlay:MakePopup()
    overlay:SetKeyboardInputEnabled(false)

    local _resTitleFont = Font:GetNamed("Poppins", "Bold",    34)
    local _resNameFont  = Font:GetNamed("Poppins", "SemiBold", 26)
    overlay.Paint = function(_, w, h)
        RNDX.Draw(R:Y(20), 0, 0, w, h, _PT_COL_RES_BG)
        RNDX.DrawOutlined(R:Y(20), 0, 0, w, h, _PT_COL_RES_OUT, 2)
        draw.SimpleText("Tenue obtenue !",
            _resTitleFont,
            w * 0.5, R:Y(46), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(outfitData.name or "?"),
            _resNameFont,
            w * 0.5, R:Y(92), _PT_COL_RES_NAME, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local mdlPath = tostring(outfitData.model or "")
    if mdlPath ~= "" then
        local mdl = vgui.Create("DModelPanel", overlay)
        mdl:SetPos(R:XY(60, 115))
        mdl:SetSize(R:X(400), R:Y(220))
        mdl:SetPaintBackground(false)
        mdl:SetAnimated(true)
        mdl:SetModel(mdlPath)
        local ent = mdl:GetEntity()
        local resultHeadEnt = nil
        if IsValid(ent) then
            local fov = 30
            mdl:SetFOV(fov)
            local mn, mx = ent:GetRenderBounds()
            local center  = (mn + mx) * 0.5
            local sz      = mx - mn
            local radius  = math.max(sz.x, sz.y, sz.z) * 0.5
            local dist    = (radius / math.tan(math.rad(fov * 0.5))) * 1.2
            local lookAt  = center + Vector(0, 0, 8)
            mdl:SetLookAt(lookAt)
            mdl:SetCamPos(lookAt + Vector(dist, 0, 0))
            local headMdl = getPlayerHeadModel()
            if headMdl then
                resultHeadEnt = spawnHeadCSM(ent, headMdl)
                local CH = VERSE.Characters
                if IsValid(resultHeadEnt) and CH and CH.HideBuiltInHeadBodygroups then
                    CH.HideBuiltInHeadBodygroups(ent)
                end
            end
        end
        local resultAngle = 0
        mdl.LayoutEntity = function(_, e)
            if IsValid(e) then
                resultAngle = (resultAngle + FrameTime() * 30) % 360
                e:SetAngles(Angle(0, resultAngle, 0))
            end
            if IsValid(resultHeadEnt) then
                resultHeadEnt:InvalidateBoneCache()
                resultHeadEnt:SetupBones()
            end
        end
        mdl.PostDrawModel = function()
            local bodyEnt = mdl:GetEntity()
            local headReady = IsValid(resultHeadEnt) and #(resultHeadEnt:GetMaterials() or {}) > 0
            local bodyReady = IsValid(bodyEnt) and #(bodyEnt:GetMaterials() or {}) > 0
            if headReady or bodyReady then
                applyPlayerAppearance(headReady and resultHeadEnt or nil, bodyReady and bodyEnt or nil)
            end
            if IsValid(resultHeadEnt) then resultHeadEnt:DrawModel() end
        end
        mdl.OnRemove = function()
            if IsValid(resultHeadEnt) then resultHeadEnt:Remove() end
            resultHeadEnt = nil
        end
    end

    local _resBtnFont = Font:GetNamed("Poppins", "Bold", 20)
    local btn = vgui.Create("DButton", overlay)
    btn:SetPos(R:XY(165, 360))
    btn:SetSize(R:XY(190, 42))
    btn:SetText("")
    btn.Paint = function(s, w, h)
        _PT_COL_RES_BTN.a = s:IsHovered() and 210 or 160
        RNDX.Draw(R:Y(10), 0, 0, w, h, _PT_COL_RES_BTN)
        draw.SimpleText("OK", _resBtnFont,
            w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        if IsValid(overlay) then overlay:Remove() end
    end
end

-- ─── Slot Machine ─────────────────────────────────────────────────────────────
-- showSlotMachine(pack, winnerData)
-- Lance l'animation de slot machine sur BT._frame, puis affiche le résultat.
local function showSlotMachine(pack, winnerData)
    if not IsValid(BT._frame) then return end

    -- ── Constantes layout ────────────────────────────────────────────────────
    local NUM   = 5          -- panneaux visibles (impair, centre = slot 3)
    local CTR   = 3          -- index du slot central (1-based)
    local SW    = R:X(160)   -- largeur d'un slot
    local SH    = R:Y(260)   -- hauteur d'un slot
    local GAP   = R:X(12)
    local STEP  = SW + GAP   -- pas horizontal entre slots
    local MH    = R:Y(480)   -- hauteur totale de la machine
    local MW    = NUM * SW + (NUM - 1) * GAP + R:X(120)

    local outfits = pack.outfits or {}
    local N       = #outfits
    if N == 0 then return end

    -- Résolution de l'index gagnant dans la liste outfits
    local winnerIdx = 0
    for i, o in ipairs(outfits) do
        if tostring(o.id) == tostring(winnerData.id) then
            winnerIdx = i - 1  -- 0-based
            break
        end
    end

    -- ── Overlay sombre sur toute la boutique ──────────────────────────────────
    local ow, oh = BT._frame:GetSize()
    local overlay = vgui.Create("DPanel", BT._frame)
    overlay:SetSize(ow, oh)
    overlay:SetPos(0, 0)
    overlay:MakePopup()
    overlay:SetKeyboardInputEnabled(false)
    overlay._flashAlpha = 0
    overlay._revealT    = 0

    overlay.Paint = function(s, w, h)
        -- Fond assombri
        draw.RoundedBox(0, 0, 0, w, h, _PT_COL_OVL_DARK)
        -- Flash blanc au moment du reveal
        if s._flashAlpha > 1 then
            _PT_COL_OVL_FLASH.a = math.floor(s._flashAlpha)
            draw.RoundedBox(0, 0, 0, w, h, _PT_COL_OVL_FLASH)
        end
    end

    -- ── Panel machine (centré) ────────────────────────────────────────────────
    local machine = vgui.Create("DPanel", overlay)
    machine:SetSize(MW, MH)
    machine:SetPos((ow - MW) * 0.5, (oh - MH) * 0.5)

    local _machTitleFont = Font:GetNamed("Poppins", "Bold", 28)
    machine.Paint = function(s, w, h)
        RNDX.Draw(R:Y(18), 0, 0, w, h, _PT_COL_MACH_BG)
        RNDX.DrawOutlined(R:Y(18), 0, 0, w, h, _PT_COL_MACH_OUT, 2)

        -- Titre
        draw.SimpleText("✦  REROLL  ✦",
            _machTitleFont,
            w * 0.5, R:Y(34), _PT_COL_MACH_TITLE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Lignes de sélection (encadrent le slot central)
        local cx = (w - MW + R:X(120)) * 0.5 + (CTR - 1) * STEP
        local sy = (MH - SH) * 0.5 - R:Y(4)
        local sh2 = SH + R:Y(8)
        surface.SetDrawColor(138, 80, 255, 200)
        surface.DrawRect(cx - R:X(2),       sy, R:X(2), sh2)
        surface.DrawRect(cx + SW + R:X(1),  sy, R:X(2), sh2)
        -- Fond central légèrement illuminé
        draw.RoundedBox(R:Y(12), cx, sy, SW, sh2, _PT_COL_MACH_CTR_FILL)
    end

    -- ── Création des DModelPanel (positions fixes, content change) ────────────
    local slotsX = R:X(60)  -- marge gauche dans machine
    local slotsY = (MH - SH) * 0.5

    local slots = {}  -- { panel, mdl, curIdx }

    local function setupSlotCamera(mdlPanel)
        local ent = mdlPanel:GetEntity()
        if not IsValid(ent) then return end
        local fov    = 26
        mdlPanel:SetFOV(fov)
        local mn, mx = ent:GetRenderBounds()
        local center = (mn + mx) * 0.5
        local sz     = mx - mn
        local radius = math.max(sz.x, sz.y, sz.z) * 0.5
        local dist   = (radius / math.tan(math.rad(fov * 0.5))) * 1.08
        local lookAt = center + Vector(0, 0, 6)
        mdlPanel:SetLookAt(lookAt)
        mdlPanel:SetCamPos(lookAt + Vector(dist, dist * 0.05, 0))
    end

    local function setSlotModel(slot, oIdx)
        local o = outfits[(oIdx % N) + 1]
        if slot.curIdx == oIdx then return end
        slot.curIdx = oIdx
        local mdlPath = getOutfitModel(o)
        if mdlPath == "" then return end
        slot.mdl:SetModel(mdlPath)
        setupSlotCamera(slot.mdl)
        slot.mdl.LayoutEntity = function(_, e)
            if IsValid(e) then e:SetAngles(Angle(0, CurTime() * 35, 0)) end
        end
    end

    for i = 1, NUM do
        local px = slotsX + (i - 1) * STEP
        local isC = (i == CTR)

        local _slotBgCol  = isC and _PT_COL_SLOT_BG_CTR  or _PT_COL_SLOT_BG_SIDE
        local _slotOutCol = isC and _PT_COL_SLOT_OUT_CTR or _PT_COL_SLOT_OUT_SIDE
        local sp = vgui.Create("DPanel", machine)
        sp:SetPos(px, slotsY)
        sp:SetSize(SW, SH)
        sp.Paint = function(s, w, h)
            RNDX.Draw(R:Y(10), 0, 0, w, h, _slotBgCol)
            RNDX.DrawOutlined(R:Y(10), 0, 0, w, h, _slotOutCol, 1)
        end

        local mp = vgui.Create("DModelPanel", sp)
        mp:SetSize(SW, SH)
        mp:SetPos(0, 0)
        mp:SetPaintBackground(false)
        mp:SetAnimated(true)

        slots[i] = { panel = sp, mdl = mp, curIdx = -999 }
        setSlotModel(slots[i], i - CTR)   -- position initiale centrée sur 0
    end

    -- ── État animation ────────────────────────────────────────────────────────
    -- pos : position float dans l'espace "index" (entier = un outfit centré)
    -- frac = pos % 1 : décalage horizontal courant
    local anim = {
        pos         = 0,
        speed       = 0,
        phase       = "spinup",   -- spinup → spin → decel → reveal → done
        spinTime    = 0,
        decStartPos = 0,
        decStartSpd = 0,
        targetPos   = 0,
        revealDone  = false,
    }

    -- Pré-calcul du targetPos : entier ≥ pos + 1.5*N tel que targetPos%N == winnerIdx
    local function computeTarget(curPos)
        local minT = curPos + N * 1.5
        local t    = math.ceil(minT)
        while (t % N) ~= winnerIdx do t = t + 1 end
        return t
    end

    -- Bouton fermer (visible uniquement après reveal)
    local closeW, closeH = R:X(220), R:Y(38)
    local closeBtn = vgui.Create("DButton", machine)
    closeBtn:SetSize(closeW, closeH)
    closeBtn:SetPos((MW - closeW) * 0.5, MH - R:Y(12) - closeH)

    -- Texte de statut (nom tenue) — au-dessus du bouton fermer
    local statusLabel = vgui.Create("DPanel", machine)
    statusLabel:SetSize(MW - R:X(40), R:Y(28))
    statusLabel:SetPos(R:X(20), MH - R:Y(12) - closeH - R:Y(6) - R:Y(28))
    local _statusRevealFont = Font:GetNamed("Poppins", "Bold",    17)
    local _statusSpinFont   = Font:GetNamed("Poppins", "Regular", 14)
    statusLabel.Paint = function(s, w, h)
        local txt = anim.phase == "reveal" and _statusRevealFont or _statusSpinFont
        local label = anim.phase == "reveal"
            and ("✦  " .. tostring(winnerData.name or "Tenue") .. "  ✦")
            or  "Tirage en cours…"
        local col = anim.phase == "reveal" and _PT_COL_STATUS_REVEAL or _PT_COL_STATUS_SPIN
        draw.SimpleText(label, txt, w * 0.5, h * 0.5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    local _closeBtnFont = Font:GetNamed("Poppins", "Medium", 15)
    closeBtn:SetText("")
    closeBtn:SetVisible(false)
    closeBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        _PT_COL_CLOSE_BG.a  = hov and 220 or 140
        _PT_COL_CLOSE_OUT.a = hov and 200 or 90
        RNDX.Draw(R:Y(9), 0, 0, w, h, _PT_COL_CLOSE_BG)
        RNDX.DrawOutlined(R:Y(9), 0, 0, w, h, _PT_COL_CLOSE_OUT, 1)
        draw.SimpleText("Fermer", _closeBtnFont,
            w * 0.5, h * 0.5, _PT_COL_CLOSE_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function()
        if IsValid(overlay) then overlay:Remove() end
        BT:RebuildContent()
    end

    -- ── Think : moteur de l'animation ────────────────────────────────────────
    local MAX_SPEED = 14   -- modèles/seconde à pleine vitesse
    local SPINUP_T  = 0.6  -- durée du spin-up

    machine.Think = function()
        if anim.phase == "done" then return end
        local dt = FrameTime()

        -- 1) Spin-up
        if anim.phase == "spinup" then
            anim.spinTime = anim.spinTime + dt
            local t = math.Clamp(anim.spinTime / SPINUP_T, 0, 1)
            anim.speed = MAX_SPEED * (t * t)
            anim.pos   = anim.pos + anim.speed * dt
            if anim.spinTime >= SPINUP_T then
                anim.phase = "spin"
                anim.spinTime = 0
            end

        -- 2) Spin constant
        elseif anim.phase == "spin" then
            anim.spinTime = anim.spinTime + dt
            anim.speed    = MAX_SPEED
            anim.pos      = anim.pos + anim.speed * dt
            if anim.spinTime >= 2.2 then
                anim.phase      = "decel"
                anim.decStartPos = anim.pos
                anim.decStartSpd = anim.speed
                anim.targetPos  = computeTarget(anim.pos)
            end

        -- 3) Décélération (ease-out quadratique + snap sous seuil)
        elseif anim.phase == "decel" then
            local totalDist = anim.targetPos - anim.decStartPos
            local done      = anim.pos - anim.decStartPos
            local progress  = math.Clamp(done / totalDist, 0, 1)
            local eased     = 1 - (1 - progress) * (1 - progress)  -- ease-out quad
            anim.speed      = anim.decStartSpd * (1 - eased)
            anim.pos        = anim.pos + anim.speed * dt

            -- Snap dès que la vitesse devient imperceptible ou qu'on a dépassé la cible
            if anim.speed < 1.2 or anim.pos >= anim.targetPos then
                anim.pos   = anim.targetPos
                anim.speed = 0
                anim.phase = "reveal"
                -- Flash + affichage bouton fermer après délai
                overlay._flashAlpha = 180
                timer.Simple(0.9, function()
                    if IsValid(closeBtn) then closeBtn:SetVisible(true) end
                end)
            end

        -- 4) Reveal : fade du flash
        elseif anim.phase == "reveal" then
            overlay._flashAlpha = math.max(0, overlay._flashAlpha - 255 * dt * 1.8)
        end

        -- ── Mise à jour des positions et modèles ─────────────────────────────
        local iPos = math.floor(anim.pos)
        local frac = anim.pos - iPos   -- 0→1 : décalage vers le prochain slot

        for i = 1, NUM do
            local slot   = slots[i]
            local offset = i - CTR                         -- -2,-1,0,+1,+2
            local oIdx   = iPos + offset                   -- index absolu
            setSlotModel(slot, oIdx)

            -- Position horizontale : glisse vers la gauche avec frac
            local px = slotsX + (i - 1) * STEP - frac * STEP
            slot.panel:SetPos(px, slotsY)

            slot.panel:SetVisible(true)
        end
    end

    -- ── Clic sur l'overlay pour fermer après reveal ───────────────────────────
    overlay.OnMousePressed = function(s)
        if anim.phase == "reveal" and IsValid(closeBtn) and closeBtn:IsVisible() then
            closeBtn:DoClick()
        end
    end
end

-- ─── Page principale ─────────────────────────────────────────────────────────
local function buildPackTenuePage(parent)
    destroyPreview()

    local packList = getPackList()
    local selected = getSelectedPack()

    buildLeftPanel(parent, selected)

    -- Diviseur vertical
    local divider = vgui.Create("DPanel", parent)
    divider:SetPos(R:XY(661, 235))
    divider:SetSize(R:XY(5, 715))
    divider.Paint = function(_, w, h)
        RNDX.Draw(R:Y(8), 0, 0, w, h, _PT_COL_DIVIDER)
    end

    -- Grille scrollable
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:SetPos(R:X(GRID_X), R:Y(GRID_Y))
    scroll:SetSize(R:X(GRID_W), R:Y(GRID_H))

    local vbar = scroll:GetVBar()
    vbar:SetWide(R:X(4))
    function vbar:Paint(w, h)
        draw.RoundedBox(w, w / 2, 0, w, h, _PT_COL_VBAR_BG)
    end
    function vbar.btnUp:Paint()   end
    function vbar.btnDown:Paint() end
    function vbar.btnGrip:Paint(w, h)
        draw.RoundedBox(w, w / 2, 0, w, h, _PT_COL_VBAR_GRIP)
    end

    for i, pack in ipairs(packList) do
        local col  = (i - 1) % COLS
        local row  = math.floor((i - 1) / COLS)
        local card = buildPackCard(scroll, pack)
        card:SetPos(
            R:X(CARD_OX) + col * R:X(COL_STEP),
            R:Y(CARD_OY) + row * R:Y(ROW_STEP))
    end

    if selected then
        local packPrice = tostring(selected.price or 0) .. " Points"
        -- Bouton Acheter : à l'intérieur du panel, en bas (PH=680, panel à Y=226)
        local rrW, rrH = R:X(340), R:Y(44)
        local rrX = R:X(120) + (R:X(449) - rrW) * 0.5   -- centré horizontalement
        local rrY = R:Y(226) + R:Y(650) - rrH + R:Y(60)   -- légèrement sous le panel
        local rrBtn = vgui.Create("DButton", parent)
        rrBtn:SetSize(rrW, rrH)
        rrBtn:SetPos(rrX, rrY)
        rrBtn:SetText("")
        rrBtn._busy = false
        local _rrLabelFont = Font:GetNamed("Poppins", "Bold",   17)
        local _rrPriceFont = Font:GetNamed("Poppins", "Medium", 14)
        local _rrBusyFont  = Font:GetNamed("Poppins", "Medium", 15)
        rrBtn.Paint = function(s, w, h)
            local hov = s:IsHovered() and not s._busy
            _PT_COL_BUY_BG.a  = s._busy and 70 or (hov and 230 or 180)
            _PT_COL_BUY_OUT.a = hov and 220 or 110
            RNDX.Draw(R:Y(11), 0, 0, w, h, _PT_COL_BUY_BG)
            RNDX.DrawOutlined(R:Y(11), 0, 0, w, h, _PT_COL_BUY_OUT, 2)
            if s._busy then
                draw.SimpleText("Tirage en cours…",
                    _rrBusyFont,
                    w * 0.5, h * 0.5, _PT_COL_BUY_BUSY_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                return
            end
            local lw = VERSE.GetTextSize("Acheter", _rrLabelFont)
            local pw = VERSE.GetTextSize(packPrice, _rrPriceFont)
            local gap = R:X(10)
            local tx  = (w - lw - gap - pw) * 0.5
            draw.SimpleText("Acheter", _rrLabelFont, tx,            h * 0.5,
                color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(packPrice, _rrPriceFont, tx + lw + gap, h * 0.5,
                _PT_COL_BUY_PRICE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        rrBtn.DoClick = function(s)
            if s._busy then return end
            local sel = getSelectedPack()
            if not sel then return end
            s._busy = true
            netstream.Start(BT.Net.RerollPackTenue, sel.id)
        end
    end

    _ui.createBackButton(parent)

    -- Cleanup à la fermeture de la page
    local cleanup = vgui.Create("DPanel", parent)
    cleanup:SetSize(0, 0)
    cleanup.OnRemove = function() destroyPreview() end
end

-- ─── Netstream : résultat reroll ─────────────────────────────────────────────
netstream.Hook(BT.Net.RerollTenueResult, function(success, data)
    if not success then
        local msgs = {
            not_enough_coins = "Pas assez de coins pour reroll.",
            busy             = "Action déjà en cours.",
            invalid_pack     = "Pack introuvable.",
            empty_pack       = "Aucune tenue dans ce pack.",
        }
        local msg = msgs[tostring(data or "")] or ("Erreur: " .. tostring(data or ""))
        if VERSE.Notify then VERSE.Notify(msg, NOTIFY_ERROR, 4) end
        BT:RebuildContent()   -- réinitialise le bouton Reroll
        return
    end

    -- Lancer la slot machine avec le résultat
    local pack = getSelectedPack()
    if pack then
        showSlotMachine(pack, data)
    end
end)

-- ─── Netstream résultat ───────────────────────────────────────────────────────
netstream.Hook(BT.Net.PackTenueResult, function(success, data)
    if not success then return end
    if not istable(data) then return end
    showResult(data)
end)

-- ─── Export ──────────────────────────────────────────────────────────────────
_ui.buildPackTenuePage      = buildPackTenuePage
_ui.destroyPackTenuePreview = destroyPreview
