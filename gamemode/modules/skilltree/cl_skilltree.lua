local ST = VERSE.SkillTree
if not ST then return end
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local function lerpFactor(speed)
    return math.Clamp(FrameTime() * speed, 0, 1)
end

local function smooth(current, target, speed)
    return Lerp(lerpFactor(speed or 12), current or 0, target or 0)
end

local CATEGORY_ICON_STYLE = {
    cursed_power = {
        size = 13,
        xPad = 53,
        yOff = 0
    },
    martial = {
        size = 13,
        xPad = 53,
        yOff = 0
    },
    heritage = {
        size = 14,
        w = 14,
        h = 18,
        xPad = 54,
        yOff = 0
    },
    clans = {
        size = 15,
        xPad = 55,
        yOff = 0
    },
    autres = {
        size = 15,
        xPad = 55,
        yOff = 0
    },
}

local SUBTYPE_ICON_STYLE = {
    application = {
        size = 92,
        yOff = 2,
        labelOff = 4
    },
    control = {
        size = 90,
        yOff = 2,
        labelOff = 4
    },
    invocation = {
        size = 88,
        yOff = 3,
        labelOff = 4
    },
    projection = {
        size = 90,
        yOff = 2,
        labelOff = 4
    },
    hand_to_hand = {
        size = 92,
        yOff = 2,
        labelOff = 4
    },
    sword = {
        size = 90,
        yOff = 3,
        labelOff = 4
    },
    black_flash = {
        size = 90,
        yOff = 3,
        labelOff = 4
    },
    heritage_hanami = {
        size = 90,
        yOff = 2,
        labelOff = 4
    },
    heritage_jogo = {
        size = 90,
        yOff = 2,
        labelOff = 4
    },
    innate = {
        size = 74,
        yOff = 12,
        labelOff = 6
    },
    clan_core = {
        size = 76,
        yOff = 10,
        labelOff = 6
    },
    -- Clan Gojo : logo réduit de 20% (90 → 72), recentré pour rester aligné
    -- avec les autres clans (qui restent à 90).
    clan_gojo = {
        size = 72,
        yOff = 11,
        labelOff = 13
    },
    utility = {
        size = 68,
        yOff = 8,
        labelOff = 6
    },
    soul_control = {
        size = 88,
        yOff = 3,
        labelOff = 4
    },
    vessel_form = {
        size = 90,
        yOff = 3,
        labelOff = 4
    },
    reverse_ct = {
        size = 90,
        yOff = 3,
        labelOff = 4
    },
}

VERSE.Hook.AddNS("SkillTree", "InitPostEntity", "VERSE::SkillTree::InitMaterials", function()
    local aliases = (ST.Config and ST.Config.MaterialAliases) or {}
    for alias, path in pairs(aliases) do
        Materials:SetAlias(alias, path)
    end
end)

ST.Client = ST.Client or {
    charId = 0,
    state = nil,
    loadout = nil,
    lastError = nil,
    frame = nil,
    loadoutFrame = nil,
    selectedCategory = nil,
    selectedNode = nil,
    hoveredNode = nil,
    branches = {},
    cursed_rerolls = 0,
}

local function getClientState()
    return ST.Client.state or ST:GetDefaultState()
end

local function getClientLoadout()
    return ST:NormalizeLoadout(ST.Client.loadout, getClientState())
end

function ST:RequestSync()
    netstream.Start(self.Net.Request)
end

function ST:RequestPurchase(nodeId)
    nodeId = tostring(nodeId or "")
    if nodeId == "" then return end
    netstream.Start(self.Net.Purchase, nodeId)
end

function ST:RequestReroll()
    netstream.Start(self.Net.Reroll)
end

function ST:RequestReset()
    netstream.Start(self.Net.Reset)
end

function ST:GetClientNodeRank(nodeId)
    return self:GetNodeRank(getClientState(), nodeId)
end

function ST:GetSelectedCategory()
    local catId = self.Client.selectedCategory
    if catId then
        for i = 1, #self.Tree do
            if self.Tree[i].id == catId then return self.Tree[i] end
        end
    end
    return self.Tree[1]
end

function ST:RebuildFrame()
    local frame = self.Client.frame
    if not IsValid(frame) or not isfunction(frame.RebuildContent) then return end
    frame:RebuildContent()
end

local function wrapText(text, font, maxW)
    surface.SetFont(font)
    local out, cur = {}, ""
    for _, word in ipairs(string.Explode(" ", text)) do
        local candidate = cur == "" and word or (cur .. " " .. word)
        if surface.GetTextSize(candidate) > maxW and cur ~= "" then
            out[#out + 1] = cur
            cur = word
        else
            cur = candidate
        end
    end
    if cur ~= "" then out[#out + 1] = cur end
    return out
end

-- Coupe le texte en lignes d'au plus maxChars caractères (mots préservés).
-- utf8.len pour compter les caractères visibles (accents = 1 caractère, pas 2 octets).
local function wrapTextChars(text, maxChars)
    local out, cur = {}, ""
    for _, word in ipairs(string.Explode(" ", text)) do
        local candidate = cur == "" and word or (cur .. " " .. word)
        local len = utf8.len(candidate) or #candidate
        if len > maxChars and cur ~= "" then
            out[#out + 1] = cur
            cur = word
        else
            cur = candidate
        end
    end
    if cur ~= "" then out[#out + 1] = cur end
    return out
end

local function prettifyStatKey(key)
    local fr = {
        Health = "Sante",
        Armor = "Armure",
        Mana = "Energie Occulte",
        ManaRegen = "Regeneration d'Energie Occulte",
        ManaCostReduction = "Reduction du cout en Energie Occulte",
        Damage = "Degats",
        MeleeDamage = "Degats de melee",
        AbilityPower = "Puissance occulte",
        CooldownReduction = "Reduction des temps de recharge",
        HealthRegen = "Regeneration de sante",
        RunSpeed = "Vitesse de course",
        WalkSpeed = "Vitesse de marche",
        JumpPower = "Puissance de saut",
        DamageReduction = "Reduction des degats",
    }
    if fr[key] then return fr[key] end
    key = tostring(key or "")
    key = key:gsub("(%l)(%u)", "%1 %2")
    key = key:gsub("_", " ")
    return key:gsub("^%l", string.upper)
end

local getNodeStatus

local function buildTooltipData(node, rank, state)
    local data = {
        title       = tostring(node.title or node.id),
        desc        = tostring(node.description or ""),
        typeStr     = tostring(node.node_type or "stat"),
        typeLabel   = "Statistique",
        rank        = rank,
        maxRank     = node.maxRank or 1,
        cost        = node.cost or 1,
        available   = math.max(0, math.floor(tonumber((state and state.available_points) or 0) or 0)),
        effectLines = {},
        passiveLines = {},
        abilityLines = {},
        reqLines    = {},
        statusText  = "",
        statusLevel = "warn",
    }

    if data.typeStr == "passive" then
        data.typeLabel = "Passif"
    elseif data.typeStr == "ability" then
        data.typeLabel = "Technique"
    end

    local status, _, _, canBuy = getNodeStatus(node, state or getClientState())
    if status == "maxed" then
        data.statusText = "Rang maximum atteint"
        data.statusLevel = "ok"
    elseif canBuy then
        data.statusText = ""
        data.statusLevel = "ok"
    elseif data.available < data.cost then
        data.statusText = "Points de competence insuffisants"
        data.statusLevel = "warn"
    else
        data.statusText = "Conditions d'acces non remplies"
        data.statusLevel = "bad"
    end

    local effects = node.stat_effects or node.effects
    if istable(effects) and table.Count(effects) > 0 then
        local parts = {}
        for k, v in pairs(effects) do
            local n = tonumber(v)
            if n then parts[#parts + 1] = {label = k, val = n} end
        end
        table.sort(parts, function(a, b) return a.label < b.label end)
        for _, p in ipairs(parts) do
            data.effectLines[#data.effectLines + 1] = {
                text = (p.val >= 0 and "+" or "") .. tostring(p.val) .. " " .. prettifyStatKey(p.label),
                positive = p.val >= 0,
            }
        end
    end

    if istable(node.passive_buffs) and #node.passive_buffs > 0 then
        for _, pid in ipairs(node.passive_buffs) do
            local pd = ST.Passives and ST.Passives[tostring(pid)]
            data.passiveLines[#data.passiveLines + 1] = tostring((pd and pd.title) or pid)
        end
    end

    if istable(node.abilities) and #node.abilities > 0 then
        for _, aid in ipairs(node.abilities) do
            aid = tostring(aid)
            local ad = ST.Abilities and ST.Abilities[aid]
            local line = tostring((ad and ad.title) or aid)
            local manaCost = ST.GetAbilityManaCost and ST:GetAbilityManaCost(aid, nil) or nil
            if manaCost ~= nil and tonumber(manaCost) and tonumber(manaCost) > 0 then
                line = line .. " (" .. tostring(math.floor(tonumber(manaCost) + 0.5)) .. " EO)"
            end
            data.abilityLines[#data.abilityLines + 1] = line
        end
    end

    if istable(node.requires) and #node.requires > 0 then
        for _, req in ipairs(node.requires) do
            local reqId = tostring(req.id or "")
            local reqNeed = math.max(1, math.floor(tonumber(req.rank) or 1))
            local reqHave = ST:GetNodeRank(state or getClientState(), reqId)
            local reqNode = ST:GetNode(reqId)
            data.reqLines[#data.reqLines + 1] = {
                text = tostring((reqNode and reqNode.title) or reqId) .. " " .. tostring(reqHave) .. "/" .. tostring(reqNeed),
                ok = reqHave >= reqNeed,
            }
        end
    end

    return data
end

-- ─── Couleurs pré-allouées pour SkillTree — regroupées en table (1 upvalue au lieu de 50+) ──
local _C = {
    COL_TEXT         = Color(210, 217, 228),
    FRAME_BG         = Color(255, 255, 255, 225),
    TIP_SHADOW       = Color(0,   0,   0,   0),
    TIP_BG           = Color(4,   6,   12,  0),
    TIP_OUTLINE      = Color(140, 100, 220, 0),
    TIP_INNER        = Color(255, 255, 255, 0),
    TIP_ACCENT       = Color(140, 100, 220, 0),
    TIP_TITLE        = Color(244, 248, 255, 0),
    TIP_BADGE_BG     = Color(140, 100, 220, 0),
    TIP_BADGE_OUT    = Color(140, 100, 220, 0),
    TIP_BADGE_TXT    = Color(250, 242, 225, 0),
    TIP_DESC         = Color(194, 203, 220, 0),
    TIP_TYPE_DEF     = Color(100, 120, 160, 0),
    TIP_CHIP_COST    = Color(168, 85,  247, 0),
    TIP_CHIP_AVAIL   = Color(80,  170, 255, 0),
    TIP_CHIP_BG      = Color(80,  150, 220, 0),
    TIP_CHIP_OUT     = Color(80,  150, 220, 0),
    TIP_CHIP_TXT     = Color(242, 246, 255, 0),
    TIP_STATUS_OK    = Color(105, 236, 145, 0),
    TIP_STATUS_BAD   = Color(255, 120, 120, 0),
    TIP_STATUS_WRN   = Color(255, 194, 96,  0),
    TIP_DIVIDER      = Color(130, 145, 170, 0),
    TIP_SECTION      = Color(156, 168, 188, 0),
    TIP_EFF_POS      = Color(110, 235, 140, 0),
    TIP_EFF_NEG      = Color(214, 220, 236, 0),
    TIP_PASSIVE      = Color(228, 206, 255, 0),
    TIP_ABILITY      = Color(255, 214, 128, 0),
    TIP_REQ_OK       = Color(105, 236, 145, 0),
    TIP_REQ_WARN     = Color(255, 194, 96,  0),
    TAB_TEXT         = Color(178, 186, 200, 0),
    TAB_ICON         = Color(178, 186, 200, 0),
    TAB_UNDERLINE    = Color(140, 100, 220, 0),
    SEG              = Color(140, 100, 220, 0),
    NODE_DARK_SHD    = Color(0,   0,   0,   0),
    NODE_GLOW        = Color(140, 100, 220, 0),
    NODE_BG          = Color(140, 100, 220, 0),
    NODE_RING        = Color(140, 100, 220, 0),
    NODE_ICON        = Color(255, 255, 255, 0),
    NODE_BADGE_BG    = Color(0,   0,   0,   200),
    NODE_BADGE_MAX   = Color(80,  220, 130, 0),
    NODE_BADGE_SC    = Color(140, 100, 220, 0),
    NODE_BADGE_TXT   = Color(228, 234, 245, 0),
    NODE_LABEL       = Color(228, 234, 245, 0),
    BADGE_BG         = Color(140, 100, 220, 0),
    BADGE_OUT        = Color(140, 100, 220, 0),
    BADGE_TXT        = Color(140, 100, 220, 0),
    ICON             = Color(140, 100, 220, 255),
    ROLL_BG          = Color(140, 100, 220, 200),
    ROLL_OUT         = Color(140, 100, 220, 180),
    ROLL_TXT         = Color(255, 255, 255, 230),
    NH_ICON          = Color(140, 100, 220, 120),
    NH_TITLE         = Color(220, 220, 230, 255),
    NH_SUB           = Color(150, 150, 170, 255),
    RESET_HOVER      = Color(190, 140, 255, 255),
    RESET_NORMAL     = Color(130, 80,  220, 255),
    UPG_BG           = Color(140, 100, 220, 0),
    UPG_OUT          = Color(140, 100, 220, 160),
    UPG_TXT          = Color(255, 255, 255, 230),
    FOOTER_PTS       = Color(168, 85,  247, 255),
    LOADOUT_BG       = Color(20,  16,  30,  220),
    LOADOUT_OUT      = Color(130, 92,  220, 0),
    LOADOUT_TITLE    = Color(244, 240, 255, 255),
    LOADOUT_PRESET   = Color(182, 160, 235, 255),
}
-- ─────────────────────────────────────────────────────────────────────────────

local function getSubtypeIconAlias(sub)
    local icon = tostring(sub and (sub.icon or sub.icon_alias or sub.icon_material) or "")
    if icon ~= "" then return icon end
    local sid = tostring(sub and sub.id or "")
    local map = (ST.Config and ST.Config.SubtypeIconById) or {}
    return map[sid] or "skilltree_sub_application_icon"
end

local function getCategoryIconAlias(cat)
    local icon = tostring(cat and (cat.icon or cat.icon_alias or cat.icon_material) or "")
    if icon ~= "" then return icon end
    local cid = tostring(cat and cat.id or "")
    local map = (ST.Config and ST.Config.CategoryIconById) or {}
    return map[cid] or "skilltree_category_other_icon"
end

local function mergeIconStyle(base, override)
    local style = table.Copy(base)
    if not istable(override) then return style end
    for key, value in pairs(override) do
        if isnumber(value) then
            style[key] = value
        end
    end
    return style
end

local function getCategoryIconStyle(cat)
    local cid = tostring(cat and cat.id or "")
    local base = CATEGORY_ICON_STYLE[cid] or {
        size = 14,
        xPad = 54,
        yOff = 0
    }
    return mergeIconStyle(base, cat and cat.icon_style)
end

local SUBTYPE_ICON_EXTRA_YOFF = 38   -- descend tous les logos de branche (max ~42 sinon
                                     -- le badge "Pouvoir assigné" sort de la zone BRANCH_H)

local function getSubtypeIconStyle(sub)
    local sid = tostring(sub and sub.id or "")
    local base = SUBTYPE_ICON_STYLE[sid] or {
        size = 90,
        yOff = 2,
        labelOff = 4
    }
    local style = mergeIconStyle(base, sub and sub.icon_style)
    -- Descend tous les logos d'un même offset. mergeIconStyle renvoie une copie → sûr.
    style.yOff = (tonumber(style.yOff) or 0) + SUBTYPE_ICON_EXTRA_YOFF
    return style
end

getNodeStatus = function(node, state)
    local rank = ST:GetNodeRank(state, node.id)
    local maxRank = node.maxRank or 1
    local canBuy = ST:CanUnlockNode(state, node.id)
    -- Verification verrou de branche cote client (via node map qui contient subtype_id)
    local branchLocked = false
    local fullNode = ST:GetNode(node.id)
    local subtypeId = fullNode and fullNode.subtype_id
    if subtypeId then
        local clientBranches = ST.Client.branches or {}
        local clientMeta = { branches = clientBranches }
        branchLocked = ST:IsSubtypeLockedByMeta(subtypeId, clientMeta)
    end
    local status = "locked"
    if rank >= maxRank then
        status = "maxed"
    elseif rank > 0 then
        status = "partial"
    elseif branchLocked then
        status = "locked"
    elseif canBuy then
        status = "ready"
    end
    return status, rank, maxRank, (canBuy and not branchLocked)
end

function ST:OpenMenu()
    if IsValid(self.Client.frame) then
        self.Client.frame:MakePopup()
        self.Client.frame:SetVisible(true)
        if isfunction(self.Client.frame.QueueRebuild) then
            self.Client.frame:QueueRebuild(0)
        else
            self:RebuildFrame()
        end
        return
    end

    local frame = vgui.Create("MantleFrame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:MakePopup()
    frame:SetDraggable(false)
    frame:LiteMode()
    frame:SetAlphaBackground(false)
    frame:SetClosable(true)
    frame:DisableCloseBtn()
    frame:SetTitle("")
    frame:SetCenterTitle("")
    frame.Paint = function(s, pw, ph)
        Materials:DrawDuplicate(_C.FRAME_BG, "skilltree_main_background", 0, 0, pw, ph, "noclamp smooth")
        Materials:DrawDuplicate(_C.FRAME_BG, "skilltree_main_background", 0, 0, pw, ph, "noclamp smooth")
    end

    local content = vgui.Create("DPanel", frame)
    content:SetPos(0, 0)
    content:SetSize(ScrW(), ScrH())
    content.Paint = nil
    frame._rebuildToken = 0
    function frame:QueueRebuild(delay)
        self._rebuildToken = (self._rebuildToken or 0) + 1
        local token = self._rebuildToken
        timer.Simple(delay or 0, function()
            if not IsValid(self) then return end
            if token ~= self._rebuildToken then return end
            if not isfunction(self.RebuildContent) then return end
            self:RebuildContent()
        end)
    end

    function frame:OnSizeChanged(w, h)
        if IsValid(content) then content:SetSize(w, h) end
        self:QueueRebuild(0)
    end

    function frame:RebuildContent()
        local fw, fh = frame:GetSize()
        content:SetSize(fw, fh)
        content:Clear()
        local state = ST:NormalizeState(getClientState())
        local category = ST:GetSelectedCategory()
        if not istable(category) then return end
        -- Pour la categorie clan : n'afficher que le subtype du clan du joueur.
        local subtypes = category.subtypes or {}
        if category.id == "technique_clan" then
            local clanSubtypeId = ST:GetPlayerClanSubtypeId(LocalPlayer())
            if clanSubtypeId then
                local filtered = {}
                for _, sub in ipairs(subtypes) do
                    if sub.id == clanSubtypeId then
                        filtered[#filtered + 1] = sub
                    end
                end
                subtypes = filtered
            else
                subtypes = {}
            end
        end
        -- Pour la categorie heritage : n'afficher que le sous-type obtenu via reroll.
        local _noHeritage = false
        if category.id == "heritage" then
            local heritageSubtypeId = ST:GetPlayerHeritageSubtypeId()
            if heritageSubtypeId then
                local filtered = {}
                for _, sub in ipairs(subtypes) do
                    if sub.id == heritageSubtypeId then
                        filtered[#filtered + 1] = sub
                    end
                end
                subtypes = filtered
            else
                subtypes = {}
                _noHeritage = true
            end
        end

        -- Pour la catégorie cursed_powers : si le joueur n'a pas encore de branche
        -- ET qu'il lui reste un ticket de tirage (cursed_rerolls > 0), afficher
        -- uniquement le bouton de tirage et masquer l'arbre (encore vide).
        local _noCursedPower = false
        if category.id == "cursed_powers" then
            local branches = ST.Client.branches or {}
            local hasBranch = tostring(branches["cursed_power_branch"] or "") ~= ""
            if not hasBranch then
                subtypes = {}
                _noCursedPower = true
            end
        end
        local catColor = category.color or Color(140, 150, 170)
        local fontTitle = Font:GetNamed("Poppins", "SemiBold", 30)
        local fontLink = Font:GetNamed("Poppins", "Medium", 22)
        local fontTab = Font:GetNamed("Poppins", "Medium", 20)
        local fontTabActive = Font:GetNamed("Poppins", "SemiBold", 22)
        local fontBranch = Font:GetNamed("Poppins", "SemiBold", 25)
        local fontNodeQuestion = Font:GetNamed("Poppins", "Bold", 30)
        local fontPoints = Font:GetNamed("Poppins", "SemiBold", 64)
        local fontFooter = Font:GetNamed("Poppins", "SemiBold", 24)
        content.Paint = nil

        local titleLbl = vgui.Create("DLabel", content)
        titleLbl:SetPos(R:X(48), R:Y(38))
        titleLbl:SetSize(R:X(620), R:Y(30))
        titleLbl:SetText("Reinitialisation des points de competence")
        titleLbl:SetFont(fontTitle)
        titleLbl:SetTextColor(_C.COL_TEXT)
        titleLbl:SetContentAlignment(4)
        local resetBtn = vgui.Create("DButton", content)
        resetBtn:SetPos(R:X(48), R:Y(69))
        resetBtn:SetSize(R:X(260), R:Y(20))
        resetBtn:SetText("")
        resetBtn.Paint = function(pnl, w, h)
            local col = pnl:IsHovered() and _C.RESET_HOVER or _C.RESET_NORMAL
            local iconS = R:Y(12)
            Materials:Draw(col, "skilltree_reset_link_icon", 0, math.floor(h * 0.5 - iconS * 0.5), iconS, iconS, "noclamp smooth")
            draw.SimpleText("Acheter des reinitialisations", fontLink, iconS + R:X(7), h * 0.5, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        resetBtn.DoClick = function()
            -- Tout le monde (admin inclus) est envoyé à la boutique, page reset & reroll.
            local BTq = VERSE.Boutique
            if not BTq then return end
            if IsValid(ST.Client.frame) then ST.Client.frame:Close() end
            BTq:OpenUI()
            BTq:SetPage("rerolls")
        end

        local fontTipTitle = Font:GetNamed("Poppins", "SemiBold", 23)
        local fontTipDesc  = Font:GetNamed("Poppins", "Medium",   18)
        local fontTipLabel = Font:GetNamed("Poppins", "Medium",   15)
        local fontTipStat  = Font:GetNamed("Poppins", "SemiBold", 17)
        local TIP_W     = R:X(420)
        local TIP_PAD_X = R:X(16)
        local TIP_PAD_Y = R:Y(14)
        local TIP_LINE  = R:Y(24)
        local NODE_TYPE_COL = {
            stat    = Color(80,  150, 220),
            passive = Color(168, 85,  247),
            ability = Color(220, 160, 60),
        }
        local function computeTipHeight(data)
            local y = TIP_PAD_Y + R:Y(22)
            if data._descLines then
                y = y + #data._descLines * TIP_LINE
            elseif data.desc ~= "" then
                y = y + TIP_LINE
            end
            y = y + R:Y(10) + R:Y(18) + R:Y(10)
            y = y + R:Y(14) + R:Y(8)
            if #data.effectLines > 0 then y = y + R:Y(13) + R:Y(5) + #data.effectLines * TIP_LINE + R:Y(8) end
            if #data.passiveLines > 0 then y = y + R:Y(13) + R:Y(5) + #data.passiveLines * TIP_LINE + R:Y(8) end
            if #data.reqLines > 0 then y = y + R:Y(13) + R:Y(5) + #data.reqLines * TIP_LINE + R:Y(8) end
            return y + TIP_PAD_Y
        end
        local tooltipPnl = vgui.Create("DPanel", content)
        tooltipPnl:SetSize(TIP_W, R:Y(80))
        tooltipPnl:SetPos(-9999, -9999)
        tooltipPnl:SetZPos(2000)
        tooltipPnl:SetMouseInputEnabled(false)
        tooltipPnl._alpha = 0
        tooltipPnl._data  = nil
        tooltipPnl._sc    = Color(140, 100, 220)
        tooltipPnl.Think = function(pnl)
            pnl._alpha = smooth(pnl._alpha, pnl._data ~= nil and 1 or 0, 16)
            if pnl._alpha < 0.005 then pnl:SetPos(-9999, -9999) return end
            local mx, my = input.GetCursorPos()
            local offX, offY = R:X(14), R:Y(10)
            local tx, ty = mx + offX, my + offY
            local pw, ph = pnl:GetSize()
            if tx + pw > fw then tx = mx - pw - offX end
            if ty + ph > fh then ty = my - ph - offY end
            pnl:SetPos(tx, ty)
        end
        tooltipPnl.Paint = function(pnl, w, h)
            local a = pnl._alpha
            if a < 0.005 or not pnl._data then return end
            local data = pnl._data
            local sc   = pnl._sc
            local ia   = math.floor(a * 255)
            -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
            _C.TIP_SHADOW.a = math.floor(120 * a)
            RNDX().Rect(0, 0, w, h):Rad(R:Y(10)):Color(_C.TIP_SHADOW):DropShadow(R:X(22), R:X(30)):Draw()
            _C.TIP_BG.a = math.floor(248 * a)
            RNDX().Rect(0, 0, w, h):Rad(R:Y(10)):Color(_C.TIP_BG):Draw()
            _C.TIP_OUTLINE.r, _C.TIP_OUTLINE.g, _C.TIP_OUTLINE.b, _C.TIP_OUTLINE.a = sc.r, sc.g, sc.b, math.floor(150 * a)
            RNDX().Rect(0, 0, w, h):Rad(R:Y(10)):Outline(2):Color(_C.TIP_OUTLINE):Draw()
            _C.TIP_INNER.a = math.floor(18 * a)
            RNDX().Rect(R:X(2), R:Y(2), w - R:X(4), h - R:Y(4)):Rad(R:Y(8)):Outline(1):Color(_C.TIP_INNER):Draw()
            _C.TIP_ACCENT.r, _C.TIP_ACCENT.g, _C.TIP_ACCENT.b, _C.TIP_ACCENT.a = sc.r, sc.g, sc.b, math.floor(230 * a)
            RNDX().Rect(0, R:Y(8), R:X(4), h - R:Y(16)):Rad(R:Y(2)):Color(_C.TIP_ACCENT):Draw()
            local y = TIP_PAD_Y
            local rankStr = tostring(data.rank) .. " / " .. tostring(data.maxRank)
            local badgeW, badgeH = R:X(62), R:Y(22)
            local badgeX = w - TIP_PAD_X - badgeW
            _C.TIP_TITLE.a = ia
            draw.SimpleText(data.title, fontTipTitle, TIP_PAD_X + R:X(4), y, _C.TIP_TITLE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            _C.TIP_BADGE_BG.r,  _C.TIP_BADGE_BG.g,  _C.TIP_BADGE_BG.b,  _C.TIP_BADGE_BG.a  = sc.r, sc.g, sc.b, math.floor(55  * a)
            _C.TIP_BADGE_OUT.r, _C.TIP_BADGE_OUT.g, _C.TIP_BADGE_OUT.b, _C.TIP_BADGE_OUT.a = sc.r, sc.g, sc.b, math.floor(170 * a)
            RNDX().Rect(badgeX, y + R:Y(1), badgeW, badgeH):Rad(R:Y(5)):Color(_C.TIP_BADGE_BG):Draw()
            RNDX().Rect(badgeX, y + R:Y(1), badgeW, badgeH):Rad(R:Y(5)):Outline(1):Color(_C.TIP_BADGE_OUT):Draw()
            _C.TIP_BADGE_TXT.a = ia
            draw.SimpleText(rankStr, fontTipLabel, badgeX + badgeW * 0.5, y + badgeH * 0.5 + R:Y(1), _C.TIP_BADGE_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            y = y + R:Y(25)
            _C.TIP_DESC.a = ia
            if data._descLines then
                for _, line in ipairs(data._descLines) do
                    draw.SimpleText(line, fontTipDesc, TIP_PAD_X + R:X(4), y, _C.TIP_DESC, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    y = y + TIP_LINE
                end
            elseif data.desc ~= "" then
                draw.SimpleText(data.desc, fontTipDesc, TIP_PAD_X + R:X(4), y, _C.TIP_DESC, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                y = y + TIP_LINE
            end
            y = y + R:Y(10)
            local typeCol = NODE_TYPE_COL[data.typeStr] or _C.TIP_TYPE_DEF
            local chips = {
                {text = string.upper(data.typeLabel),             col = typeCol},
                {text = tostring(data.cost) .. " PT",             col = _C.TIP_CHIP_COST},
            }
            local chipH = R:Y(22)
            local chipX = TIP_PAD_X + R:X(4)
            _C.TIP_CHIP_TXT.a = ia
            for _, chip in ipairs(chips) do
                local cc = chip.col
                surface.SetFont(fontTipLabel)
                local cw = surface.GetTextSize(chip.text) + R:X(20)
                _C.TIP_CHIP_BG.r,  _C.TIP_CHIP_BG.g,  _C.TIP_CHIP_BG.b,  _C.TIP_CHIP_BG.a  = cc.r, cc.g, cc.b, math.floor(48  * a)
                _C.TIP_CHIP_OUT.r, _C.TIP_CHIP_OUT.g, _C.TIP_CHIP_OUT.b, _C.TIP_CHIP_OUT.a = cc.r, cc.g, cc.b, math.floor(140 * a)
                RNDX().Rect(chipX, y, cw, chipH):Rad(R:Y(5)):Color(_C.TIP_CHIP_BG):Draw()
                RNDX().Rect(chipX, y, cw, chipH):Rad(R:Y(5)):Outline(1):Color(_C.TIP_CHIP_OUT):Draw()
                draw.SimpleText(chip.text, fontTipLabel, chipX + cw * 0.5, y + chipH * 0.5, _C.TIP_CHIP_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                chipX = chipX + cw + R:X(6)
            end
            y = y + chipH + R:Y(10)
            local statusCol
            if data.statusLevel == "ok" then
                _C.TIP_STATUS_OK.a = ia
                statusCol = _C.TIP_STATUS_OK
            elseif data.statusLevel == "bad" then
                _C.TIP_STATUS_BAD.a = ia
                statusCol = _C.TIP_STATUS_BAD
            else
                _C.TIP_STATUS_WRN.a = ia
                statusCol = _C.TIP_STATUS_WRN
            end
            if data.statusText ~= "" then
                draw.SimpleText(data.statusText, fontTipLabel, TIP_PAD_X + R:X(4), y, statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                y = y + R:Y(14) + R:Y(8)
            end
            _C.TIP_DIVIDER.a = math.floor(76 * a)
            RNDX().Rect(TIP_PAD_X + R:X(4), y - R:Y(4), w - TIP_PAD_X * 2 - R:X(8), 1):Color(_C.TIP_DIVIDER):Draw()
            _C.TIP_SECTION.a = ia
            _C.TIP_EFF_POS.a = ia
            _C.TIP_EFF_NEG.a = ia
            if #data.effectLines > 0 then
                draw.SimpleText("EFFETS", fontTipLabel, TIP_PAD_X + R:X(4), y, _C.TIP_SECTION, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                y = y + R:Y(13) + R:Y(5)
                for _, line in ipairs(data.effectLines) do
                    draw.SimpleText(line.text, fontTipStat, TIP_PAD_X + R:X(4), y, line.positive and _C.TIP_EFF_POS or _C.TIP_EFF_NEG, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    y = y + TIP_LINE
                end
                y = y + R:Y(8)
            end

            if #data.passiveLines > 0 then
                draw.SimpleText("PASSIFS", fontTipLabel, TIP_PAD_X + R:X(4), y, _C.TIP_SECTION, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                y = y + R:Y(13) + R:Y(5)
                _C.TIP_PASSIVE.a = ia
                for _, line in ipairs(data.passiveLines) do
                    draw.SimpleText(line, fontTipStat, TIP_PAD_X + R:X(4), y, _C.TIP_PASSIVE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    y = y + TIP_LINE
                end
                y = y + R:Y(8)
            end


            if #data.reqLines > 0 then
                draw.SimpleText("CONDITIONS", fontTipLabel, TIP_PAD_X + R:X(4), y, _C.TIP_SECTION, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                y = y + R:Y(13) + R:Y(5)
                _C.TIP_REQ_OK.a   = ia
                _C.TIP_REQ_WARN.a = ia
                for _, line in ipairs(data.reqLines) do
                    draw.SimpleText((line.ok and "[OK] " or "[A FAIRE] ") .. line.text, fontTipStat, TIP_PAD_X + R:X(4), y, line.ok and _C.TIP_REQ_OK or _C.TIP_REQ_WARN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    y = y + TIP_LINE
                end
            end
        end

        local TAB_W = R:X(176)
        local TAB_H = R:Y(34)
        local TAB_GAP = R:X(12)
        -- Filtrer les onglets : masquer "technique_clan" si le joueur n'a pas de clan.
        local visibleTabs = {}
        local playerHasClan = ST:GetPlayerClanSubtypeId(LocalPlayer()) ~= nil
        for _, cat in ipairs(ST.Tree) do
            if cat.id ~= "technique_clan" or playerHasClan then
                visibleTabs[#visibleTabs + 1] = cat
            end
        end
        -- Si l'onglet selectionne n'est plus visible (ex: perte de clan), revenir au premier.
        if ST.Client.selectedCategory == "technique_clan" and not playerHasClan then
            ST.Client.selectedCategory = visibleTabs[1] and visibleTabs[1].id or nil
        end
        local totalTabs = #visibleTabs
        local totalTabW = totalTabs * TAB_W + (totalTabs - 1) * TAB_GAP
        local tabsX = math.floor((fw - totalTabW) * 0.5)
        for ti = 1, totalTabs do
            local cat = visibleTabs[ti]
            local cc = istable(cat) and cat.color or Color(120, 130, 150)
            local isActive = cat.id == (ST.Client.selectedCategory or (ST.Tree[1] and ST.Tree[1].id))
            local tab = vgui.Create("DButton", content)
            tab:SetPos(tabsX + (ti - 1) * (TAB_W + TAB_GAP), R:Y(48))
            tab:SetSize(TAB_W, TAB_H)
            tab:SetText("")
            tab._active = isActive
            tab._cc = cc
            tab._icon = getCategoryIconAlias(cat)
            tab._iconStyle = getCategoryIconStyle(cat)
            tab.Paint = function(pnl, w, h)
                pnl._activeFrac = smooth(pnl._activeFrac, pnl._active and 1 or 0, 10)
                pnl._hoverFrac = smooth(pnl._hoverFrac, pnl:IsHovered() and 1 or 0, 16)
                local txtA = math.floor(Lerp(pnl._activeFrac, 95 + pnl._hoverFrac * 60, 255))
                -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                _C.TAB_TEXT.r = math.floor(Lerp(pnl._activeFrac, 178 + pnl._hoverFrac * 20, pnl._cc.r))
                _C.TAB_TEXT.g = math.floor(Lerp(pnl._activeFrac, 186 + pnl._hoverFrac * 20, pnl._cc.g))
                _C.TAB_TEXT.b = math.floor(Lerp(pnl._activeFrac, 200 + pnl._hoverFrac * 20, pnl._cc.b))
                _C.TAB_TEXT.a = txtA
                local fnt = (pnl._activeFrac > 0.5) and fontTabActive or fontTab
                local iconW = R:X(pnl._iconStyle.w or pnl._iconStyle.size)
                local iconH = R:Y(pnl._iconStyle.h or pnl._iconStyle.size)
                local leftX = math.floor(w * 0.5 - R:X(pnl._iconStyle.xPad))
                _C.TAB_ICON.r, _C.TAB_ICON.g, _C.TAB_ICON.b = _C.TAB_TEXT.r, _C.TAB_TEXT.g, _C.TAB_TEXT.b
                _C.TAB_ICON.a = math.min(255, txtA + 10)
                Materials:Draw(_C.TAB_ICON, pnl._icon, leftX, math.floor(h * 0.5 - iconH * 0.5) + R:Y(pnl._iconStyle.yOff), iconW, iconH, "noclamp smooth")
                draw.SimpleText(tostring(cat.title or cat.id), fnt, leftX + iconW + R:X(8), h * 0.5, _C.TAB_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if pnl._activeFrac > 0.02 then
                    _C.TAB_UNDERLINE.r, _C.TAB_UNDERLINE.g, _C.TAB_UNDERLINE.b = pnl._cc.r, pnl._cc.g, pnl._cc.b
                    _C.TAB_UNDERLINE.a = math.floor(220 * pnl._activeFrac)
                    RNDX().Rect(0, h - R:Y(2), w, R:Y(2)):Color(_C.TAB_UNDERLINE):Draw()
                end
            end

            tab.DoClick = function()
                ST.Client.selectedCategory = cat.id
                ST.Client.selectedNode = nil
                ST.Client.hoveredNode = nil
                frame:RebuildContent()
            end
        end

        local FOOTER_H = R:Y(184)
        local TREE_X = R:X(48)
        local TREE_Y = R:Y(108)
        local TREE_W = fw - R:X(96)
        local TREE_H = fh - TREE_Y - FOOTER_H - R:Y(16)
        local treePanel = vgui.Create("DPanel", content)
        treePanel:SetPos(TREE_X, TREE_Y)
        treePanel:SetSize(TREE_W, TREE_H)
        treePanel.Paint = nil

        -- Message "pas d'heritage" si le joueur n'a pas encore de branche Heritage.
        if _noHeritage then
            local fontMsg     = Font:GetNamed("Poppins", "SemiBold", 26)
            local fontSubMsg  = Font:GetNamed("Poppins", "Medium",   17)
            local catColor    = category.color or Color(167, 111, 255)
            treePanel.Paint = function(_, w, h)
                -- Icone point d'interrogation (mutation de la couleur pré-allouée)
                _C.NH_ICON.r, _C.NH_ICON.g, _C.NH_ICON.b = catColor.r, catColor.g, catColor.b
                draw.SimpleText("?", Font:GetNamed("Poppins", "Bold", 64),
                    w * 0.5, h * 0.5 - R:Y(52),
                    _C.NH_ICON,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                -- Titre
                draw.SimpleText("Vous n'avez pas d'heritage",
                    fontMsg, w * 0.5, h * 0.5 - R:Y(6),
                    _C.NH_TITLE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                -- Sous-titre
                draw.SimpleText("Obtenez un heritage via le Reroll Heritage dans la Boutique.",
                    fontSubMsg, w * 0.5, h * 0.5 + R:Y(26),
                    _C.NH_SUB, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- Pouvoir Occulte non encore tiré : affiche un bouton si un ticket est disponible.
        if _noCursedPower then
            local catColor   = category.color or Color(140, 80, 255)
            local fontMsg    = Font:GetNamed("Poppins", "SemiBold", 26)
            local fontSubMsg = Font:GetNamed("Poppins", "Medium",   17)
            local fontBtn    = Font:GetNamed("Poppins", "Bold",     18)

            treePanel.Paint = function(_, w, h)
                local rerolls = ST.Client.cursed_rerolls or 0
                -- Icône "?" centré (mutation de la couleur pré-allouée)
                _C.NH_ICON.r, _C.NH_ICON.g, _C.NH_ICON.b = catColor.r, catColor.g, catColor.b
                draw.SimpleText("?", Font:GetNamed("Poppins", "Bold", 64),
                    w * 0.5, h * 0.5 - R:Y(82),
                    _C.NH_ICON,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                -- Titre
                local titre = rerolls > 0 and "Votre Pouvoir Occulte n'est pas encore attribue."
                                           or "Vous n'avez pas de ticket de tirage."
                draw.SimpleText(titre, fontMsg, w * 0.5, h * 0.5 - R:Y(32),
                    _C.NH_TITLE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                -- Sous-titre
                local sub = rerolls > 0
                    and ("Tirage disponible : " .. tostring(rerolls) .. " ticket(s). Cliquez sur le bouton ci-dessous.")
                    or  "Demandez a un administrateur de vous attribuer votre pouvoir."
                draw.SimpleText(sub, fontSubMsg, w * 0.5, h * 0.5 + R:Y(2),
                    _C.NH_SUB, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            -- Bouton de tirage (visible uniquement si tickets > 0)
            local btnW = R:X(320)
            local btnH = R:Y(46)
            local rollBtn = vgui.Create("DButton", treePanel)
            rollBtn:SetPos(math.floor((TREE_W - btnW) * 0.5), math.floor(TREE_H * 0.5) + R:Y(42))
            rollBtn:SetSize(btnW, btnH)
            rollBtn:SetText("")
            rollBtn.Think = function(pnl)
                pnl:SetVisible((ST.Client.cursed_rerolls or 0) > 0)
            end
            rollBtn.Paint = function(pnl, w, h)
                if not pnl:IsVisible() then return end
                local hover = smooth(pnl._hoverFrac, pnl:IsHovered() and 1 or 0, 14)
                pnl._hoverFrac = hover
                local r = catColor.r + math.floor(30 * hover)
                local g = catColor.g + math.floor(10 * hover)
                local b = catColor.b + math.floor(30 * hover)
                -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                _C.ROLL_BG.r, _C.ROLL_BG.g, _C.ROLL_BG.b, _C.ROLL_BG.a = r, g, b, 200 + math.floor(40 * hover)
                _C.ROLL_OUT.r, _C.ROLL_OUT.g, _C.ROLL_OUT.b = r, g, b
                RNDX().Rect(0, 0, w, h):Rad(R:Y(10)):Color(_C.ROLL_BG):Draw()
                RNDX().Rect(0, 0, w, h):Rad(R:Y(10)):Outline(1):Color(_C.ROLL_OUT):Draw()
                draw.SimpleText("✦  TIRER MON POUVOIR OCCULTE", fontBtn, w * 0.5, h * 0.5,
                    _C.ROLL_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            rollBtn.DoClick = function()
                notification.AddLegacy("Tirage en cours...", NOTIFY_HINT, 3)
                ST:RequestReroll()
            end
        end

        if not _noHeritage and not _noCursedPower then
        local BRANCH_H = R:Y(200)
        local GRID_TOP = R:Y(14)
        local GRID_BOT = TREE_H - BRANCH_H
        local GRID_H = GRID_BOT - GRID_TOP
        local numCols = math.max(1, #subtypes)
        local maxNodes = 1
        for _, sub in ipairs(subtypes) do
            maxNodes = math.max(maxNodes, istable(sub.nodes) and #sub.nodes or 0)
        end

        local ROW_H = math.max(1, math.floor(GRID_H / maxNodes))
        local colW = math.floor(TREE_W / numCols)
        local nodeD = math.floor(math.min(colW * 0.20, ROW_H * 0.72, R:X(62)) * 1.15)
        nodeD = math.max(8, nodeD)
        local nodeRadius = math.floor(nodeD * 0.5)
        local nodeLabelFont = nodeD <= R:X(22) and Font:GetNamed("Poppins", "Bold", 16) or fontNodeQuestion
        local function colCX(ci)
            return math.floor((ci - 0.5) * colW)
        end

        -- rowCY inversé : ri=1 (premier skill) en bas, ri=maxNodes (dernier) en haut.
        -- L'icône de branche reste en bas (GRID_BOT), le skill de rang A est tout en haut.
        local function rowCY(ri)
            return GRID_TOP + math.floor((maxNodes - ri + 0.5) * ROW_H)
        end

        local segments = {}
        for ci, sub in ipairs(subtypes) do
            local nodes = istable(sub.nodes) and sub.nodes or {}
            local sc = sub.color or catColor
            for ri = 1, #nodes - 1 do
                -- Avec rowCY inversé : rowCY(ri) > rowCY(ri+1) (ri en bas, ri+1 au-dessus).
                -- y1 = bord haut du nœud inférieur, y2 = bord bas du nœud supérieur → segment vertical.
                segments[#segments + 1] = {
                    x = colCX(ci),
                    y1 = rowCY(ri + 1) + nodeRadius,
                    y2 = rowCY(ri) - nodeRadius,
                    r = sc.r,
                    g = sc.g,
                    b = sc.b,
                }
            end
        end

        treePanel.Paint = function(_, w, h)
            for _, seg in ipairs(segments) do
                local alpha = math.floor(78 + 58 * math.sin(CurTime() * 2.0 + seg.x * 0.012))
                -- Mutation de la couleur pré-allouée (évite Color() par segment par frame)
                _C.SEG.r, _C.SEG.g, _C.SEG.b, _C.SEG.a = seg.r, seg.g, seg.b, alpha
                RNDX().Rect(seg.x, seg.y1, 1, seg.y2 - seg.y1):Color(_C.SEG):Draw()
            end
        end

        for ci, sub in ipairs(subtypes) do
            local nodes = istable(sub.nodes) and sub.nodes or {}
            local sc = sub.color or catColor
            local cx = colCX(ci)
            local iconStyle = getSubtypeIconStyle(sub)
            local iconW = R:X(iconStyle.w or iconStyle.size)
            local iconH = R:Y(iconStyle.h or iconStyle.size)
            local iconPnl = vgui.Create("DPanel", treePanel)
            iconPnl:SetPos(cx - math.floor(iconW * 0.5), GRID_BOT + R:Y(iconStyle.yOff))
            iconPnl:SetSize(iconW, iconH)
            iconPnl._alias = getSubtypeIconAlias(sub)
            iconPnl._sc = sc
            iconPnl.Paint = function(_, w, h)
                _C.ICON.r, _C.ICON.g, _C.ICON.b = iconPnl._sc.r, iconPnl._sc.g, iconPnl._sc.b
                Materials:Draw(_C.ICON, iconPnl._alias, 0, 0, w, h, "noclamp smooth")
            end
            local lblW = colW - R:X(8)
            local lblPnl = vgui.Create("DPanel", treePanel)
            lblPnl:SetPos(cx - math.floor(lblW * 0.5), GRID_BOT + R:Y(iconStyle.yOff) + iconH + R:Y(iconStyle.labelOff))
            lblPnl:SetSize(lblW, R:Y(24))
            lblPnl._sc = sc
            lblPnl._text = string.upper(tostring(sub.title or sub.id))
            lblPnl.Paint = function(_, w, h) draw.SimpleText(lblPnl._text, fontBranch, w * 0.5, h * 0.5, lblPnl._sc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end

            -- ── Badge ASSIGNÉ pour les branches reroll-only ──────────────────────
            do
                local subGroup = ST:GetExclusiveGroupForSubtype(sub.id)
                if subGroup and ST:IsRerollGroup(subGroup.id) then
                    local rbW = math.min(math.floor(colW * 0.85), R:X(560))
                    local rbH = R:Y(36)
                    local rbX = cx - math.floor(rbW * 0.5)
                    local rbY = GRID_BOT + R:Y(iconStyle.yOff) + iconH + R:Y(iconStyle.labelOff) + R:Y(26)
                    local groupId = subGroup.id
                    local subId   = sub.id

                    -- Badge ASSIGNÉ (visible si cette branche est celle choisie)
                    -- Le reroll se fait désormais exclusivement via la boutique.
                    local assignedBadge = vgui.Create("DPanel", treePanel)
                    assignedBadge:SetPos(rbX, rbY)
                    assignedBadge:SetSize(rbW, rbH)
                    assignedBadge.Think = function(pnl)
                        local cb = ST.Client.branches or {}
                        pnl:SetVisible(tostring(cb[groupId] or "") == subId)
                    end
                    local _assignedBadgeFont = Font:GetNamed("Poppins", "Bold", 16)
                    assignedBadge.Paint = function(pnl, w, h)
                        if not pnl:IsVisible() then return end
                        -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                        _C.BADGE_BG.r,  _C.BADGE_BG.g,  _C.BADGE_BG.b,  _C.BADGE_BG.a  = sc.r, sc.g, sc.b, 28
                        _C.BADGE_OUT.r, _C.BADGE_OUT.g, _C.BADGE_OUT.b, _C.BADGE_OUT.a = sc.r, sc.g, sc.b, 110
                        _C.BADGE_TXT.r, _C.BADGE_TXT.g, _C.BADGE_TXT.b, _C.BADGE_TXT.a = sc.r, sc.g, sc.b, 230
                        RNDX().Rect(0, 0, w, h):Rad(R:Y(5)):Color(_C.BADGE_BG):Draw()
                        RNDX().Rect(0, 0, w, h):Rad(R:Y(5)):Outline(1):Color(_C.BADGE_OUT):Draw()
                        draw.SimpleText("✓  POUVOIR ASSIGNÉ", _assignedBadgeFont, w * 0.5, h * 0.5, _C.BADGE_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
            -- ─────────────────────────────────────────────────────────────────────

            for ri, node in ipairs(nodes) do
                local btn = vgui.Create("DButton", treePanel)
                btn:SetPos(cx - nodeRadius, rowCY(ri) - nodeRadius)
                btn:SetSize(nodeD, nodeD)
                btn:SetText("")
                btn:SetCursor("hand")
                btn._nid = node.id
                btn._sc = sc
                btn._node = node

                -- Pre-calcul de l'icone de l'ability liee a ce noeud
                do
                    local iconAlias = nil
                    for _, aId in ipairs(node.abilities or {}) do
                        local aData = ST.Abilities and ST.Abilities[tostring(aId)]
                        if istable(aData) and aData.icon and aData.icon ~= "" then
                            iconAlias = tostring(aData.icon)
                            break
                        end
                    end
                    btn._abilityIconAlias = iconAlias
                end

                local _nodeBadgeFont = Font:GetNamed("Poppins", "Bold", 18)
                btn.Paint = function(pnl, w, h)
                    local status, rank, maxR = getNodeStatus(pnl._node, state)
                    local r, g, b = pnl._sc.r, pnl._sc.g, pnl._sc.b
                    local tgt = (status == "maxed" and 1) or (status == "partial" and 0.6) or (status == "ready" and 0.25) or 0
                    pnl._stateFrac = smooth(pnl._stateFrac, tgt, 8)
                    pnl._hoverFrac = smooth(pnl._hoverFrac, pnl:IsHovered() and 1 or 0, 18)
                    local bgA = math.floor(Lerp(pnl._stateFrac, 18, 155) + pnl._hoverFrac * 16)
                    local bR = math.min(255, math.floor(r * 0.14 + pnl._stateFrac * r * 0.24 + pnl._hoverFrac * 18))
                    local bG = math.min(255, math.floor(g * 0.14 + pnl._stateFrac * g * 0.24 + pnl._hoverFrac * 18))
                    local bB = math.min(255, math.floor(b * 0.14 + pnl._stateFrac * b * 0.24 + pnl._hoverFrac * 18))
                    local selected = ST.Client.selectedNode == pnl._nid
                    local pulse = selected and (0.78 + 0.22 * math.sin(CurTime() * 5.5)) or 1
                    local ringA = math.floor((status == "locked" and 68 or (status == "ready" and 150 or 215)) * pulse)
                    local ringW = selected and (3 + math.floor(2 * pulse)) or (status == "locked" and 1 or 2)
                    local shadowBoost = (selected and 1.16 or 1) + pnl._hoverFrac * 0.22
                    local spread = math.floor(w * (0.52 + pnl._hoverFrac * 0.06))
                    local intensity = math.floor(spread * (1.42 + pnl._stateFrac * 0.2))
                    local darkA = math.floor((20 + 28 * pnl._stateFrac) * shadowBoost)
                    local glowA = math.floor((32 + 52 * pnl._stateFrac) * shadowBoost)
                    -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                    _C.NODE_DARK_SHD.a = math.min(72, darkA)
                    RNDX().Circle(w * 0.5, h * 0.5 + R:Y(1), w):Color(_C.NODE_DARK_SHD):DropShadow(math.floor(spread * 0.82), math.floor(intensity * 1.12)):Draw()
                    _C.NODE_GLOW.r, _C.NODE_GLOW.g, _C.NODE_GLOW.b, _C.NODE_GLOW.a = r, g, b, math.min(120, glowA)
                    RNDX().Circle(w * 0.5, h * 0.5, w):Color(_C.NODE_GLOW):DropShadow(spread, intensity):Draw()
                    _C.NODE_BG.r, _C.NODE_BG.g, _C.NODE_BG.b, _C.NODE_BG.a = bR, bG, bB, bgA
                    RNDX().Circle(w * 0.5, h * 0.5, w):Color(_C.NODE_BG):Draw()
                    _C.NODE_RING.r, _C.NODE_RING.g, _C.NODE_RING.b, _C.NODE_RING.a = r, g, b, ringA
                    RNDX().Circle(w * 0.5, h * 0.5, w):Outline(ringW):Color(_C.NODE_RING):Draw()
                    local txtA = status == "locked" and 88 or 210
                    -- Affichage de l'icone du sort si disponible
                    if pnl._abilityIconAlias then
                        local iconSize = math.floor(w * 0.88)
                        local iconX = math.floor(w * 0.5 - iconSize * 0.5)
                        local iconY = math.floor(h * 0.5 - iconSize * 0.5)
                        local iconA = status == "locked" and 55 or math.floor(txtA * (0.85 + pnl._stateFrac * 0.15))
                        _C.NODE_ICON.a = iconA
                        Materials:Draw(_C.NODE_ICON, pnl._abilityIconAlias, iconX, iconY, iconSize, iconSize, "noclamp smooth")
                        -- Badge rang en bas a droite
                        if rank > 0 then
                            local rankStr = rank .. "/" .. maxR
                            local badgeW, badgeH = R:X(42), R:Y(21)
                            local bx = w - badgeW - R:X(1)
                            local by = h - badgeH - R:Y(1)
                            RNDX().Rect(bx, by, badgeW, badgeH):Rad(R:Y(4)):Color(_C.NODE_BADGE_BG):Draw()
                            if status == "maxed" then
                                _C.NODE_BADGE_MAX.a = txtA
                                draw.SimpleText(rankStr, _nodeBadgeFont, bx + badgeW * 0.5, by + badgeH * 0.5, _C.NODE_BADGE_MAX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                            else
                                _C.NODE_BADGE_SC.r, _C.NODE_BADGE_SC.g, _C.NODE_BADGE_SC.b, _C.NODE_BADGE_SC.a = r, g, b, txtA
                                draw.SimpleText(rankStr, _nodeBadgeFont, bx + badgeW * 0.5, by + badgeH * 0.5, _C.NODE_BADGE_SC, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                            end
                        end
                    else
                        -- Fallback : texte rang ou "?"
                        local label = rank > 0 and (rank .. "/" .. maxR) or "?"
                        _C.NODE_LABEL.a = txtA
                        draw.SimpleText(label, nodeLabelFont, w * 0.5, h * 0.5 + R:Y(1), _C.NODE_LABEL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end

                btn.OnCursorEntered = function()
                    ST.Client.hoveredNode = btn._nid
                    local d = buildTooltipData(btn._node, ST:GetClientNodeRank(btn._nid), state)
                    if d.desc ~= "" then d._descLines = wrapTextChars(d.desc, 58) end
                    tooltipPnl._data = d
                    tooltipPnl._sc   = btn._sc
                    tooltipPnl:SetSize(TIP_W, computeTipHeight(d))
                end
                btn.OnCursorExited = function()
                    if ST.Client.hoveredNode == btn._nid then ST.Client.hoveredNode = nil end
                    tooltipPnl._data = nil
                end
                btn.DoClick = function(pnl)
                    ST.Client.selectedNode = pnl._nid
                    local rank = ST:GetClientNodeRank(pnl._nid)
                    if rank < (pnl._node.maxRank or 1) then ST:RequestPurchase(pnl._nid) end
                end

                -- Bouton "Ameliorer" qui apparait sous le noeud quand il peut etre upgrade
                local nodeX = cx - nodeRadius
                local nodeY = rowCY(ri) - nodeRadius
                local upgBtn = vgui.Create("DButton", treePanel)
                upgBtn:SetSize(nodeD + R:X(8), R:Y(28))
                upgBtn:SetPos(nodeX - R:X(4), nodeY + nodeD + R:Y(4))
                upgBtn:SetText("")
                upgBtn._nid = node.id
                upgBtn._node = node
                upgBtn._sc = sc
                upgBtn.Think = function(pnl)
                    local rank = ST:GetClientNodeRank(pnl._nid)
                    local maxR = pnl._node.maxRank or 1
                    local avail = (state and state.available_points) or 0
                    pnl:SetVisible(rank > 0 and rank < maxR and avail >= (pnl._node.cost or 1))
                end
                local _upgBtnFont = Font:GetNamed("Poppins", "SemiBold", 15)
                upgBtn.Paint = function(pnl, w, h)
                    local sc2 = pnl._sc
                    local hover = smooth(pnl._upgHover, pnl:IsHovered() and 1 or 0, 16)
                    pnl._upgHover = hover
                    -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                    _C.UPG_BG.r  = math.min(255, math.floor(sc2.r * 0.6 + hover * 60))
                    _C.UPG_BG.g  = math.min(255, math.floor(sc2.g * 0.6 + hover * 20))
                    _C.UPG_BG.b  = math.min(255, math.floor(sc2.b * 0.6 + hover * 20))
                    _C.UPG_BG.a  = math.floor(190 + hover * 55)
                    _C.UPG_OUT.r, _C.UPG_OUT.g, _C.UPG_OUT.b = sc2.r, sc2.g, sc2.b
                    RNDX().Rect(0, 0, w, h):Rad(R:Y(4)):Color(_C.UPG_BG):Draw()
                    RNDX().Rect(0, 0, w, h):Rad(R:Y(4)):Outline(1):Color(_C.UPG_OUT):Draw()
                    draw.SimpleText("▲ AMELIORER", _upgBtnFont, w * 0.5, h * 0.5, _C.UPG_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                upgBtn.DoClick = function(pnl)
                    ST:RequestPurchase(pnl._nid)
                end
            end
        end
        end -- if not _noHeritage and not _noCursedPower

        local footerPnl = vgui.Create("DPanel", content)
        footerPnl:SetPos(0, fh - FOOTER_H - R:Y(16))
        footerPnl:SetSize(fw, FOOTER_H)
        footerPnl.Paint = function(_, w, h)
            local availPts = state.available_points or 0
            draw.SimpleText(tostring(availPts), fontPoints, w * 0.5, h * 0.34, _C.FOOTER_PTS, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("points de competence disponibles.", fontFooter, w * 0.5, h * 0.74, _C.COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local _loadoutFontTitle  = Font:GetNamed("Poppins", "SemiBold", 18)
        local _loadoutFontPreset = Font:GetNamed("Poppins", "Medium",   15)
        local loadoutBtn = vgui.Create("DButton", content)
        loadoutBtn:SetSize(R:X(256), R:Y(42))
        loadoutBtn:SetPos(fw - R:X(308), fh - FOOTER_H + R:Y(16))
        loadoutBtn:SetText("")
        loadoutBtn._loadout = getClientLoadout()
        loadoutBtn.Paint = function(pnl, w, h)
            local hover = smooth(pnl._hoverFrac, pnl:IsHovered() and 1 or 0, 14)
            pnl._hoverFrac = hover
            -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
            _C.LOADOUT_OUT.r = 130 + math.floor(28 * hover)
            _C.LOADOUT_OUT.g =  92 + math.floor(18 * hover)
            _C.LOADOUT_OUT.b = 220 + math.floor(26 * hover)
            _C.LOADOUT_OUT.a = 185
            RNDX().Rect(0, 0, w, h):Rad(R:Y(8)):Color(_C.LOADOUT_BG):Draw()
            RNDX().Rect(0, 0, w, h):Rad(R:Y(8)):Outline(1):Color(_C.LOADOUT_OUT):Draw()
            draw.SimpleText("Techniques et binds", _loadoutFontTitle, R:X(18), h * 0.5, _C.LOADOUT_TITLE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Preset " .. tostring((pnl._loadout and pnl._loadout.active_preset) or 1), _loadoutFontPreset, w - R:X(18), h * 0.5, _C.LOADOUT_PRESET, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        loadoutBtn.DoClick = function()
            if ST.OpenLoadoutMenu then
                ST:OpenLoadoutMenu()
            end
        end

        local defaultNode = ST.Client.selectedNode and ST:GetNode(ST.Client.selectedNode) and ST.Client.selectedNode or nil
        if not defaultNode and subtypes[1] and istable(subtypes[1].nodes) and subtypes[1].nodes[1] then defaultNode = subtypes[1].nodes[1].id end
        ST.Client.selectedNode = defaultNode
    end

    frame.OnClose = function() ST.Client.frame = nil end
    ST.Client.frame = frame
    frame:QueueRebuild(0)
    frame:QueueRebuild(0.15)
    ST:RequestSync()
end

netstream.Hook(ST.Net.Sync, function(charId, state, loadout, branches, cursedRerolls)
    ST.Client.charId = tonumber(charId) or 0
    ST.Client.state = ST:NormalizeState(state)
    ST.Client.loadout = ST:NormalizeLoadout(loadout, ST.Client.state)
    ST.Client.branches = istable(branches) and branches or {}
    ST.Client.cursed_rerolls = math.max(0, math.floor(tonumber(cursedRerolls) or 0))
    ST.Client.lastError = nil
    ST:RebuildFrame()
    if ST.RefreshLoadoutFrame then ST:RefreshLoadoutFrame() end
end)

netstream.Hook(ST.Net.Error, function(code)
    ST.Client.lastError = tostring(code or "unknown")
    if ST.Client.lastError == "no_character" then
        ST.Client.charId = 0
        ST.Client.state = ST:GetDefaultState()
        ST.Client.loadout = ST:GetDefaultLoadout()
        ST:RebuildFrame()
        if ST.RefreshLoadoutFrame then ST:RefreshLoadoutFrame() end
    end
end)

VERSE.Hook.AddNS("SkillTree", "VERSE::Characters::ClientSelected", "VERSE::SkillTree::SelectedChanged", function(selected)
    if istable(selected) then
        ST:RequestSync()
        return
    end

    ST.Client.charId = 0
    ST.Client.state = ST:GetDefaultState()
    ST.Client.loadout = ST:GetDefaultLoadout()
    ST:RebuildFrame()
    if ST.RefreshLoadoutFrame then ST:RefreshLoadoutFrame() end
end)

VERSE.Commands.Add("verse_skilltree", function() ST:OpenMenu() end, nil, "client")