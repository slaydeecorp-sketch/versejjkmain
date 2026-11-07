-- ─────────────────────────────────────────────────────────────────────────────
-- VERSE :: Spell Balancing  (client)
-- Tous les champs de sorts éditables par rang — layout en grille.
-- Accès superadmin uniquement. Concommande : verse_spell_balancing_open
-- ─────────────────────────────────────────────────────────────────────────────

if not CLIENT then return end

TOOM_JJK        = TOOM_JJK or {}
TOOM_JJK.SPELLS = TOOM_JJK.SPELLS or {}

local _SB = TOOM_JJK.SPELLS.Balancing or {}
TOOM_JJK.SPELLS.Balancing = _SB
_SB.Overrides  = _SB.Overrides  or {}
_SB._originals = _SB._originals or {}
_SB.Net = _SB.Net or {
    SetOverride = "VERSE::SpellBalancing::Set",
    ResetRank   = "VERSE::SpellBalancing::ResetRank",
    ResetSpell  = "VERSE::SpellBalancing::ResetSpell",
    ResetAll    = "VERSE::SpellBalancing::ResetAll",
    SyncAll     = "VERSE::SpellBalancing::SyncAll",
    OpenMenu    = "VERSE::SpellBalancing::OpenMenu",
}

-- Fallbacks si sh_ de l'addon n'a pas chargé
if not _SB.ApplyOverrides then
    function _SB:ApplyOverrides()
        local reg = TOOM_JJK.SPELLS.Registered
        if not reg then return end
        for spellId, spell in pairs(reg) do
            if not self._originals[spellId] then
                local orig = { Cost = {}, Cooldown = {}, Upgrades = {} }
                for i = 1, 5 do
                    orig.Cost[i] = spell.Cost and spell.Cost[i]
                    orig.Cooldown[i] = spell.Cooldown and spell.Cooldown[i]
                    orig.Upgrades[i] = {}
                    if spell.Upgrades and spell.Upgrades[i] then
                        for k, v in pairs(spell.Upgrades[i]) do orig.Upgrades[i][k] = v end
                    end
                end
                self._originals[spellId] = orig
            end
        end
        for spellId, orig in pairs(self._originals) do
            local spell = reg[spellId]
            if spell then
                for rank = 1, 5 do
                    if spell.Cost     and orig.Cost[rank]     ~= nil then spell.Cost[rank]     = orig.Cost[rank]     end
                    if spell.Cooldown and orig.Cooldown[rank] ~= nil then spell.Cooldown[rank] = orig.Cooldown[rank] end
                    if spell.Upgrades and spell.Upgrades[rank] and orig.Upgrades[rank] then
                        for k, v in pairs(orig.Upgrades[rank]) do spell.Upgrades[rank][k] = v end
                    end
                end
            end
        end
        for spellId, rankOvs in pairs(self.Overrides) do
            local spell = reg[spellId]
            if spell then
                for rank, data in pairs(rankOvs) do
                    rank = tonumber(rank)
                    if rank and rank >= 1 and rank <= 5 then
                        if data.cost     ~= nil and spell.Cost     then spell.Cost[rank]     = data.cost     end
                        if data.cooldown ~= nil and spell.Cooldown then spell.Cooldown[rank] = data.cooldown end
                        if istable(data.upgrades) and spell.Upgrades and spell.Upgrades[rank] then
                            for k, v in pairs(data.upgrades) do spell.Upgrades[rank][k] = v end
                        end
                    end
                end
            end
        end
    end
end

if not _SB.GetOriginal then
    function _SB:GetOriginal(spellId, rank, field)
        local orig = self._originals[spellId]
        if orig then
            if field == "cost"     then return orig.Cost[rank] end
            if field == "cooldown" then return orig.Cooldown[rank] end
            return orig.Upgrades[rank] and orig.Upgrades[rank][field]
        end
        local spell = TOOM_JJK.SPELLS.Registered and TOOM_JJK.SPELLS.Registered[spellId]
        if not spell then return nil end
        if field == "cost"     then return spell.Cost     and spell.Cost[rank]     end
        if field == "cooldown" then return spell.Cooldown and spell.Cooldown[rank] end
        return spell.Upgrades and spell.Upgrades[rank] and spell.Upgrades[rank][field]
    end
end

if not _SB.GetUpgradeKeys then
    function _SB:GetUpgradeKeys(spellId)
        local spell = TOOM_JJK.SPELLS.Registered and TOOM_JJK.SPELLS.Registered[spellId]
        if not spell or not spell.Upgrades then return {} end
        local keys = {}
        for _, upg in ipairs(spell.Upgrades) do
            if istable(upg) then
                for k in pairs(upg) do
                    local found = false
                    for _, ek in ipairs(keys) do if ek == k then found = true break end end
                    if not found then keys[#keys + 1] = k end
                end
            end
        end
        table.sort(keys)
        return keys
    end
end

if not _SB.BuildSpellList then
    function _SB:BuildSpellList()
        local reg = TOOM_JJK.SPELLS.Registered
        if not reg then return {} end
        local list = {}
        for id, spell in pairs(reg) do
            list[#list + 1] = { id = id, name = spell.Name or id, category = spell.Category, order = spell.Order or 999, keys = self:GetUpgradeKeys(id) }
        end
        table.sort(list, function(a, b)
            local ca, cb = tostring(a.category or ""), tostring(b.category or "")
            if ca ~= cb then return ca < cb end
            if a.order ~= b.order then return a.order < b.order end
            return a.name < b.name
        end)
        return list
    end
end

if not _SB.GetFieldLabel then
    local FL = {
        damage="Dégâts", secondDamage="Dégâts (2e)", damageByTick="Dégâts/tick",
        damageBySlash="Dégâts/slash", finalBlowDamage="Coup de grâce", bleedDamage="Dégâts saignement",
        detonationDamage="Dégâts détonation", venomDamage="Dégâts poison", passThroughDamage="Dégâts traversée",
        chargeEndDamage="Dégâts fin charge", spearDamage="Dégâts lance", finalBlow="Coup final",
        healAmount="Soin", healCoef="Coef. soin",
        duration="Durée (s)", maxDuration="Durée max (s)", chargeDuration="Durée charge (s)",
        maxChargeDuration="Charge max (s)", bleedDuration="Saignement (s)", venomDuration="Poison (s)",
        slowDuration="Ralent. (s)", stunTime="Étourdissement (s)", stunDuration="Étourdissement (s)",
        confusionDuration="Confusion (s)", spearStunTime="Étourdi. lance (s)", flashDuration="Flash (s)",
        maxFlyTime="Vol max (s)", spearPendingTime="Attente lance (s)", tickRate="Taux tick (s)", tickDelay="Délai tick (s)",
        propulsionForce="Force propulsion", jumpForce="Force saut", dashDistance="Distance dash",
        maxRange="Portée max", radius="Rayon", roundAm="Arrondi",
        speed="Vitesse", spearSpeed="Vitesse lance",
        resistance="Résistance", slow="Ralentissement", slowAmount="Intensité ralent.",
        manaDrain="Drain mana", damageBoost="Boost dégâts", damageCoef="Coef. dégâts",
        attackSpeedBoost="Boost vit. attaque", speedBoost="Boost vitesse", speedCoef="Coef. vitesse",
        number="Nb projectiles",
    }
    function _SB:GetFieldLabel(key) return FL[key] or key end
end

local SB   = TOOM_JJK.SPELLS.Balancing
local NET  = SB.Net
local R    = VERSE.Responsive
local Font = VERSE.Fonts

-- ─── Helpers visuels ─────────────────────────────────────────────────────────

local function lerpF(s) return math.Clamp(FrameTime() * s, 0, 1) end
local function smooth(c, t, s) return Lerp(lerpF(s or 12), c or 0, t or 0) end

local COL_BG      = Color(6,  8,  14, 252)
local COL_BG2     = Color(12, 15, 25, 255)
local COL_HEADER  = Color(14, 18, 30, 255)
local COL_BORDER  = Color(255, 255, 255, 18)
local COL_ACCENT  = Color(100, 60, 230)
local COL_WARN    = Color(220, 100, 60)
local COL_OK      = Color(60,  200, 120)
local COL_TEXT    = Color(210, 215, 230)
local COL_MUTED   = Color(120, 128, 148)
local COL_MOD     = Color(255, 200, 60)
local COL_MANA    = Color(50,  160, 255)
local COL_CD      = Color(255, 165, 40)
local COL_UPG     = Color(180, 100, 255)
-- ─── Couleurs Paint pré-allouées ─────────────────────────────────────────────
local _SPB_COL_SHADOW           = Color(0,   0,   0,   120)
local _SPB_COL_ACCENT_TITLE     = Color(COL_ACCENT.r, COL_ACCENT.g + 40, COL_ACCENT.b + 20, 240)
local _SPB_COL_SBAR_BG          = Color(20,  22,  35,  200)
local _SPB_COL_SBAR_GRIP        = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 140)
local _SPB_COL_CLOSE_WARN       = Color(COL_WARN.r,   COL_WARN.g,   COL_WARN.b,   0)     -- .a muté
local _SPB_COL_CLOSE_X          = Color(220, 220, 230, 200)                                -- .a muté
local _SPB_COL_SRCH_SEL         = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 180)
local _SPB_COL_INP_BG           = Color(18,  22,  38,  220)
local _SPB_COL_INP_OUT          = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 30)    -- .a muté
local _SPB_COL_INP_SEL          = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 200)
local _SPB_COL_ROW_EVEN         = Color(12,  15,  26,  180)
local _SPB_COL_ROW_ODD          = Color(8,   11,  20,  180)

local CAT_COLS = {}
local function getCatColor(cat)
    if not cat then return COL_MUTED end
    if not CAT_COLS[cat] then
        -- Couleur basée sur le hash de la valeur numérique
        local h = (tonumber(cat) or 0) * 137
        CAT_COLS[cat] = HSVToColor((h % 360), 0.6, 0.85)
    end
    return CAT_COLS[cat]
end

local function getCatName(cat)
    if cat == (SPELL_STYLE   or -1) then return "Technique Occulte" end
    if cat == (SPELL_WEAPON  or -2) then return "Arme Martiale" end
    if cat == (SPELL_HERITAGE or -3) then return "Héritage / Clan" end
    return "Autre"
end

local function fmtNum(v)
    if v == nil then return "—" end
    -- Affichage compact : entier si pas de décimale
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return string.format("%.2f", v)
end

-- ─── Fenêtre principale ───────────────────────────────────────────────────────

local _frame = nil

local function openMenu()
    if not IsValid(LocalPlayer()) then return end
    if not LocalPlayer():IsSuperAdmin() and not (LocalPlayer().IsDeveloper and LocalPlayer():IsDeveloper()) then
        notification.AddLegacy("Accès refusé.", NOTIFY_ERROR, 3)
        return
    end
    if IsValid(_frame) then _frame:Remove() end

    local scrW, scrH = ScrW(), ScrH()
    local FW = math.min(R:X(1340), scrW - R:X(40))
    local FH = math.min(R:Y(860),  scrH - R:Y(40))
    local frame = vgui.Create("DFrame")
    frame:SetSize(FW, FH)
    frame:SetPos(math.floor((scrW - FW) * .5), math.floor((scrH - FH) * .5))
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:SetSizable(true)
    frame:SetDeleteOnClose(true)
    frame:MakePopup()
    _frame = frame

    for _, c in ipairs(frame:GetChildren()) do
        if c.ClassName == "DLabel" or c.ClassName == "DImageButton" then c:SetVisible(false) end
    end

    local fTitle  = Font:GetNamed("Poppins", "Bold",     24)
    local fSpell  = Font:GetNamed("Poppins", "SemiBold", 18)
    local fField  = Font:GetNamed("Poppins", "Medium",   16)
    local fVal    = Font:GetNamed("Poppins", "Regular",  16)
    local fBtn    = Font:GetNamed("Poppins", "SemiBold", 15)
    local fBadge  = Font:GetNamed("Poppins", "Medium",   13)
    local fSearch = Font:GetNamed("Poppins", "Regular",  17)
    local fRank   = Font:GetNamed("Poppins", "Bold",     15)

    local PAD = R:X(14)

    frame.Paint = function(_, w, h)
        RNDX().Rect(0,0,w,h):Rad(R:Y(12)):Color(_SPB_COL_SHADOW):DropShadow(R:X(24),R:X(36)):Draw()
        RNDX().Rect(0,0,w,h):Rad(R:Y(12)):Color(COL_BG):Draw()
        RNDX().Rect(0,0,w,h):Rad(R:Y(12)):Outline(1):Color(COL_BORDER):Draw()
    end

    -- ── Topbar ──
    local TOPBAR = R:Y(50)
    local topBar = vgui.Create("DPanel", frame)
    topBar:SetPos(0, 0); topBar:SetSize(FW, TOPBAR)
    topBar.Paint = function(_, w, h)
        RNDX().Rect(0,0,w,h):Rad(R:Y(12)):Color(COL_HEADER):Draw()
        surface.SetDrawColor(255,255,255,16); surface.DrawRect(PAD, h-1, w-PAD*2, 1)
        draw.SimpleText("⚡  Équilibrage des Sorts — Tous les Champs", fTitle,
            PAD+R:X(6), h*.5, _SPB_COL_ACCENT_TITLE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local btnX = vgui.Create("DButton", topBar)
    btnX:SetSize(R:X(30), R:Y(30)); btnX:SetPos(FW-R:X(42), math.floor((TOPBAR-R:Y(30))*.5))
    btnX:SetText(""); btnX._h=0
    btnX.Think = function(p) p._h = smooth(p._h, p:IsHovered() and 1 or 0, 14) end
    btnX.Paint = function(p, w, h)
        _SPB_COL_CLOSE_WARN.a = math.floor(180 * p._h)
        _SPB_COL_CLOSE_X.a    = 200 + math.floor(55 * p._h)
        RNDX().Rect(0,0,w,h):Rad(R:Y(6)):Color(_SPB_COL_CLOSE_WARN):Draw()
        draw.SimpleText("✕", fBtn, w*.5, h*.5, _SPB_COL_CLOSE_X, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnX.DoClick = function() frame:Close() end

    -- ── Barre de recherche ──
    local SBH = R:Y(34)
    local sPnl = vgui.Create("DPanel", frame)
    sPnl:SetPos(PAD, TOPBAR+R:Y(8)); sPnl:SetSize(FW-PAD*2, SBH)
    sPnl.Paint = function(_, w, h)
        RNDX().Rect(0,0,w,h):Rad(R:Y(7)):Color(COL_BG2):Draw()
        RNDX().Rect(0,0,w,h):Rad(R:Y(7)):Outline(1):Color(COL_BORDER):Draw()
    end
    local sEnt = vgui.Create("DTextEntry", sPnl)
    sEnt:SetPos(R:X(30), math.floor((SBH-R:Y(20))*.5)); sEnt:SetSize(FW-PAD*2-R:X(40), R:Y(20))
    sEnt:SetFont(fSearch); sEnt:SetPlaceholderText("Rechercher un sort..."); sEnt:SetPlaceholderColor(COL_MUTED); sEnt:SetTextColor(COL_TEXT)
    sEnt.Paint = function(p, w, h) p:DrawTextEntryText(COL_TEXT, _SPB_COL_SRCH_SEL, COL_TEXT) end

    -- ── ScrollPanel ──
    local BOTTOM_H = R:Y(50)
    local listY    = TOPBAR + SBH + R:Y(16)
    local listH    = FH - listY - BOTTOM_H - R:Y(8)

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(PAD, listY); scroll:SetSize(FW-PAD*2, listH)
    local sbar = scroll:GetVBar(); sbar:SetWide(R:X(5))
    sbar.Paint         = function(_, w, h) RNDX().Rect(0,0,w,h):Rad(R:Y(2)):Color(_SPB_COL_SBAR_BG):Draw() end
    sbar.btnUp.Paint   = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h) RNDX().Rect(0,0,w,h):Rad(R:Y(2)):Color(_SPB_COL_SBAR_GRIP):Draw() end

    local rowCont = vgui.Create("DPanel", scroll)
    rowCont:SetSize(FW-PAD*2-R:X(8), 1); rowCont.Paint = function() end

    -- Dimensions de la grille
    local AW       = FW - PAD*2 - R:X(8)
    local FIELD_W  = R:X(148)   -- colonne nom de champ
    local RANK_W   = math.floor((AW - FIELD_W - R:X(4)) / 5)
    local SPELL_H  = R:Y(32)    -- hauteur en-tête sort
    local COL_H    = R:Y(22)    -- hauteur en-tête colonnes rangs
    local ROW_H    = R:Y(27)    -- hauteur ligne champ
    local BTN_H    = R:Y(30)    -- hauteur ligne boutons Apply/Reset
    local SEC_PAD  = R:Y(8)
    local INP_H    = R:Y(18)
    local INP_PAD  = math.floor((ROW_H - INP_H) * .5)

    -- Inputs référencés pour refresh réseau
    -- refs[spellId][rank][field] = DTextEntry
    local refs = {}
    local collapsed = {}  -- [spellId] = bool (true = replié)

    local function makeSmallBtn(parent, x, y, w, h, txt, col, cb)
        col = col or COL_ACCENT
        local b = vgui.Create("DButton", parent)
        b:SetPos(x, y); b:SetSize(w, h); b:SetText(""); b._h=0
        local _sbFill    = Color(col.r, col.g, col.b, 140)
        local _sbOutline = Color(col.r, col.g, col.b, 80)
        local _sbTxt     = Color(255, 255, 255, 220)
        b.Think = function(p) p._h=smooth(p._h, p:IsHovered() and 1 or 0, 14) end
        b.Paint = function(p, pw, ph)
            local hv=p._h
            _sbFill.a    = math.floor(140 + 90*hv)
            RNDX().Rect(0,0,pw,ph):Rad(R:Y(4)):Color(_sbFill):Draw()
            _sbOutline.a = math.floor(80 + 130*hv)
            RNDX().Rect(0,0,pw,ph):Rad(R:Y(4)):Outline(1):Color(_sbOutline):Draw()
            _sbTxt.a     = 220 + math.floor(35*hv)
            draw.SimpleText(txt, fBtn, pw*.5, ph*.5, _sbTxt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = cb
        return b
    end

    local function makeInput(parent, x, y, w, h, initVal, col)
        col = col or COL_ACCENT
        -- Pré-allouer les couleurs Paint pour ce champ (évite Color() par frame)
        local _inpBgOut = Color(col.r, col.g, col.b, 30)   -- .a muté
        local _inpSel   = Color(col.r, col.g, col.b, 200)
        local bg = vgui.Create("DPanel", parent)
        bg:SetPos(x, y); bg:SetSize(w, h); bg._f=0
        bg.Paint = function(p, pw, ph)
            _inpBgOut.a = math.floor(30 + 160 * p._f)
            RNDX().Rect(0,0,pw,ph):Rad(R:Y(3)):Color(_SPB_COL_INP_BG):Draw()
            RNDX().Rect(0,0,pw,ph):Rad(R:Y(3)):Outline(1):Color(_inpBgOut):Draw()
        end
        local e = vgui.Create("DTextEntry", bg)
        e:SetPos(R:X(3), math.floor((h-R:Y(14))*.5)); e:SetSize(w-R:X(6), R:Y(14))
        e:SetFont(fVal); e:SetText(tostring(initVal or "")); e:SetNumeric(true)
        e:SetTextColor(COL_TEXT)
        e.Paint = function(p, pw, ph) p:DrawTextEntryText(COL_TEXT, _inpSel, COL_TEXT) end
        e.OnGetFocus  = function() bg._f=1 end
        e.OnLoseFocus = function() bg._f=0 end
        return e
    end

    -- Construit toutes les sections de sort selon le filtre
    local function rebuild(filter)
        filter = (filter or ""):lower():Trim()
        for _, c in ipairs(rowCont:GetChildren()) do c:Remove() end
        refs = {}

        local spells = SB:BuildSpellList()
        local visible = {}
        for _, sd in ipairs(spells) do
            local nm = sd.name:lower()
            local cn = getCatName(sd.category):lower()
            if filter=="" or nm:find(filter,1,true) or cn:find(filter,1,true) then
                visible[#visible+1] = sd
            end
        end

        -- Calcule la hauteur totale
        local function sectionH(sd)
            if collapsed[sd.id] then return SPELL_H + SEC_PAD end
            local nFields = 2 + #sd.keys  -- cost + cooldown + upgrades
            return SPELL_H + COL_H + nFields * ROW_H + BTN_H + SEC_PAD
        end
        local totalH = 0
        for _, sd in ipairs(visible) do totalH = totalH + sectionH(sd) end
        rowCont:SetSize(AW, math.max(totalH, R:Y(60)))

        local cy = 0
        for _, sd in ipairs(visible) do
            local spellId  = sd.id
            local catCol   = getCatColor(sd.category)
            local isCollapsed = collapsed[spellId]
            refs[spellId]  = refs[spellId] or {}
            -- Couleurs pré-allouées par ligne (catCol fixe pour ce sort)
            local _hdrBg     = Color(catCol.r, catCol.g, catCol.b, 22)
            local _hdrOut    = Color(catCol.r, catCol.g, catCol.b, 55)
            local _hdrIcon   = Color(catCol.r, catCol.g, catCol.b, 200)
            local _hdrBadgeBg= Color(catCol.r, catCol.g, catCol.b, 40)

            -- ── En-tête du sort ──
            local hdr = vgui.Create("DPanel", rowCont)
            hdr:SetPos(0, cy); hdr:SetSize(AW, SPELL_H)
            hdr.Paint = function(_, w, h)
                RNDX().Rect(0,0,w,h):Rad(R:Y(5)):Color(_hdrBg):Draw()
                RNDX().Rect(0,0,w,h):Rad(R:Y(5)):Outline(1):Color(_hdrOut):Draw()
                -- Indicateur override
                local hasOv = SB.Overrides[spellId] and next(SB.Overrides[spellId])
                if hasOv then RNDX().Rect(0,0,R:X(3),h):Color(COL_MOD):Draw() end
                -- Icone collapse
                local icon = isCollapsed and "▶" or "▼"
                draw.SimpleText(icon, fBadge, R:X(10), h*.5, _hdrIcon, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(sd.name, fSpell, R:X(24), h*.5, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                -- Badge catégorie
                local cn = getCatName(sd.category)
                surface.SetFont(fBadge); local tw = surface.GetTextSize(cn)
                local bx = w - R:X(116) - tw - R:X(18)
                RNDX().Rect(bx-R:X(5), math.floor((h-R:Y(16))*.5), tw+R:X(10), R:Y(16)):Rad(R:Y(3)):Color(_hdrBadgeBg):Draw()
                draw.SimpleText(cn, fBadge, bx, h*.5, _hdrIcon, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            -- Bouton toggle collapse
            local btnToggle = vgui.Create("DButton", hdr)
            btnToggle:SetPos(0, 0); btnToggle:SetSize(AW - R:X(115), SPELL_H); btnToggle:SetText("")
            btnToggle.Paint = function() end
            btnToggle.DoClick = function()
                collapsed[spellId] = not collapsed[spellId]
                rebuild(sEnt:GetValue())
            end

            -- Bouton Reset sort
            makeSmallBtn(hdr, AW - R:X(110), math.floor((SPELL_H-R:Y(20))*.5), R:X(110), R:Y(20), "↺ Reset sort", COL_WARN,
                function()
                    netstream.Start(NET.ResetSpell, spellId)
                    if refs[spellId] then
                        for rank = 1, 5 do
                            local rankRefs = refs[spellId][rank]
                            if rankRefs then
                                for field, ent in pairs(rankRefs) do
                                    if IsValid(ent) then
                                        ent:SetText(fmtNum(SB:GetOriginal(spellId, rank, field)))
                                    end
                                end
                            end
                        end
                    end
                end
            )

            cy = cy + SPELL_H

            if not isCollapsed then
                -- ── En-tête colonnes Rang 1..5 ──
                local colHdr = vgui.Create("DPanel", rowCont)
                colHdr:SetPos(0, cy); colHdr:SetSize(AW, COL_H)
                colHdr.Paint = function(_, w, h)
                    surface.SetDrawColor(255,255,255,10); surface.DrawRect(0,0,w,h)
                end
                -- Nom champ (vide pour l'en-tête)
                for rank = 1, 5 do
                    local x = FIELD_W + (rank-1)*RANK_W
                    local lbl = vgui.Create("DLabel", colHdr)
                    lbl:SetPos(x, 0); lbl:SetSize(RANK_W, COL_H)
                    lbl:SetText("Rang " .. rank); lbl:SetFont(fRank)
                    lbl:SetTextColor(Color(catCol.r, catCol.g, catCol.b, 200))
                    lbl:SetContentAlignment(5)
                end
                cy = cy + COL_H

                -- ── Lignes de champs ──
                -- Ordre : cost, cooldown, puis upgrade keys
                local fieldOrder = { "cost", "cooldown" }
                for _, k in ipairs(sd.keys) do fieldOrder[#fieldOrder+1] = k end

                for fi, field in ipairs(fieldOrder) do
                    local isEven = (fi % 2 == 0)
                    local fieldCol = field == "cost" and COL_MANA or field == "cooldown" and COL_CD or COL_UPG
                    local label    = field == "cost" and "✦ Coût Mana" or field == "cooldown" and "⏱ Cooldown (s)" or SB:GetFieldLabel(field)

                    local rowPnl = vgui.Create("DPanel", rowCont)
                    rowPnl:SetPos(0, cy); rowPnl:SetSize(AW, ROW_H)
                    local _rowBg = isEven and _SPB_COL_ROW_EVEN or _SPB_COL_ROW_ODD
                    rowPnl.Paint = function(_, w, h)
                        RNDX().Rect(0,0,w,h):Color(_rowBg):Draw()
                        surface.SetDrawColor(255,255,255,6); surface.DrawRect(0,h-1,w,1)
                    end

                    -- Label champ
                    local fldLbl = vgui.Create("DLabel", rowPnl)
                    fldLbl:SetPos(R:X(6), 0); fldLbl:SetSize(FIELD_W - R:X(8), ROW_H)
                    fldLbl:SetText(label); fldLbl:SetFont(fField)
                    fldLbl:SetTextColor(Color(fieldCol.r, fieldCol.g, fieldCol.b, 210))
                    fldLbl:SetContentAlignment(4)

                    -- 5 cellules (une par rang)
                    for rank = 1, 5 do
                        local x       = FIELD_W + (rank-1)*RANK_W
                        local origV   = SB:GetOriginal(spellId, rank, field)
                        local ov      = SB.Overrides[spellId] and SB.Overrides[spellId][rank]
                        local curV    = field == "cost"     and (ov and ov.cost     or origV)
                                     or field == "cooldown" and (ov and ov.cooldown or origV)
                                     or (ov and ov.upgrades and ov.upgrades[field] or origV)

                        -- Valeur originale (mini affichage)
                        local origLbl = vgui.Create("DLabel", rowPnl)
                        origLbl:SetPos(x + R:X(2), 0)
                        origLbl:SetSize(R:X(34), ROW_H)
                        origLbl:SetText(fmtNum(origV))
                        origLbl:SetFont(fVal)
                        origLbl:SetTextColor(COL_MUTED)
                        origLbl:SetContentAlignment(6)

                        -- Input
                        local inp = makeInput(rowPnl, x + R:X(38), INP_PAD, RANK_W - R:X(42), INP_H, fmtNum(curV), fieldCol)
                        refs[spellId] = refs[spellId] or {}
                        refs[spellId][rank] = refs[spellId][rank] or {}
                        refs[spellId][rank][field] = inp
                    end

                    cy = cy + ROW_H
                end

                -- ── Ligne boutons Apply / Reset par rang ──
                local btnRow = vgui.Create("DPanel", rowCont)
                btnRow:SetPos(0, cy); btnRow:SetSize(AW, BTN_H)
                btnRow.Paint = function(_, w, h)
                    surface.SetDrawColor(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 12)
                    surface.DrawRect(0, 0, w, h)
                end

                for rank = 1, 5 do
                    local x    = FIELD_W + (rank-1)*RANK_W
                    local btnW = math.floor((RANK_W - R:X(8)) * .5)
                    local btnY = math.floor((BTN_H - R:Y(22)) * .5)

                    makeSmallBtn(btnRow, x+R:X(2), btnY, btnW, R:Y(22), "✔", COL_OK, function()
                        -- Collecte toutes les valeurs du rang
                        local rankRefs = refs[spellId] and refs[spellId][rank]
                        if not rankRefs then return end
                        local data = { upgrades = {} }
                        for field2, ent in pairs(rankRefs) do
                            local v = tonumber(ent:GetValue())
                            if v ~= nil then
                                if field2 == "cost"     then data.cost     = v
                                elseif field2 == "cooldown" then data.cooldown = v
                                else data.upgrades[field2] = v
                                end
                            end
                        end
                        if not next(data.upgrades) then data.upgrades = nil end
                        netstream.Start(NET.SetOverride, spellId, rank, data)
                    end)

                    makeSmallBtn(btnRow, x+R:X(4)+btnW, btnY, btnW, R:Y(22), "↺", COL_WARN, function()
                        netstream.Start(NET.ResetRank, spellId, rank)
                        local rankRefs = refs[spellId] and refs[spellId][rank]
                        if rankRefs then
                            for field2, ent in pairs(rankRefs) do
                                if IsValid(ent) then ent:SetText(fmtNum(SB:GetOriginal(spellId, rank, field2))) end
                            end
                        end
                    end)
                end

                cy = cy + BTN_H
            end

            cy = cy + SEC_PAD
        end

        rowCont:SizeToChildren(false, true)
    end

    rebuild("")
    sEnt.OnChange = function(p) rebuild(p:GetValue()) end

    -- ── Barre du bas ──
    local bot = vgui.Create("DPanel", frame)
    bot:SetPos(0, FH-BOTTOM_H); bot:SetSize(FW, BOTTOM_H)
    bot.Paint = function(_, w, h)
        surface.SetDrawColor(255,255,255,16); surface.DrawRect(PAD, 0, w-PAD*2, 1)
        RNDX().Rect(0,1,w,h-1):Rad(R:Y(10)):Color(COL_HEADER):Draw()
    end

    local cntLbl = vgui.Create("DLabel", bot)
    cntLbl:SetPos(PAD+R:X(6), 0); cntLbl:SetSize(R:X(380), BOTTOM_H)
    cntLbl:SetFont(fVal); cntLbl:SetContentAlignment(4)
    cntLbl.Think = function(p)
        local ns, nr = 0, 0
        for _, ov in pairs(SB.Overrides) do ns=ns+1; for _ in pairs(ov) do nr=nr+1 end end
        p:SetText(nr>0 and (tostring(nr).." rang(s) modifié(s) sur "..tostring(ns).." sort(s)") or "Aucun override actif")
        p:SetTextColor(nr>0 and COL_MOD or COL_MUTED)
    end

    local BW1, BW2 = R:X(210), R:X(110)
    local bY = math.floor((BOTTOM_H-R:Y(32))*.5)
    makeSmallBtn(bot, FW-PAD-BW2-BW1-R:X(10), bY, BW1, R:Y(32), "⚠ Tout réinitialiser", COL_WARN, function()
        Derma_Query("Supprimer TOUS les overrides de sorts ?", "Confirmation",
            "Confirmer", function() netstream.Start(NET.ResetAll) end,
            "Annuler",   function() end)
    end)
    makeSmallBtn(bot, FW-PAD-BW2, bY, BW2, R:Y(32), "Fermer", Color(60,65,90), function() frame:Close() end)

    -- Refresh depuis réseau
    function frame:RefreshOverrides()
        for spellId, rankRefs in pairs(refs) do
            for rank, fieldRefs in pairs(rankRefs) do
                local ov = SB.Overrides[spellId] and SB.Overrides[spellId][rank]
                for field, ent in pairs(fieldRefs) do
                    if IsValid(ent) then
                        local val = field == "cost"     and (ov and ov.cost     or SB:GetOriginal(spellId, rank, field))
                               or   field == "cooldown" and (ov and ov.cooldown or SB:GetOriginal(spellId, rank, field))
                               or   (ov and ov.upgrades and ov.upgrades[field]  or SB:GetOriginal(spellId, rank, field))
                        ent:SetText(fmtNum(val))
                    end
                end
            end
        end
    end

    _frame = frame
end

-- ─── Netstream ───────────────────────────────────────────────────────────────

netstream.Hook(NET.SyncAll, function(packed)
    SB.Overrides = {}
    if istable(packed) then
        for spellId, rankOvs in pairs(packed) do
            if istable(rankOvs) then
                SB.Overrides[tostring(spellId)] = {}
                for rank, data in pairs(rankOvs) do
                    rank = tonumber(rank)
                    if rank and istable(data) then
                        local upgs = nil
                        if istable(data.upgrades) then
                            upgs = {}
                            for k, v in pairs(data.upgrades) do
                                local n = tonumber(v)
                                if n ~= nil then upgs[k] = n end
                            end
                            if not next(upgs) then upgs = nil end
                        end
                        SB.Overrides[tostring(spellId)][rank] = {
                            cost     = tonumber(data.cost),
                            cooldown = tonumber(data.cooldown),
                            upgrades = upgs,
                        }
                    end
                end
            end
        end
    end
    SB:ApplyOverrides()
    if IsValid(_frame) and isfunction(_frame.RefreshOverrides) then
        _frame:RefreshOverrides()
    end
end)

netstream.Hook(NET.OpenMenu, function()
    openMenu()
end)

-- ─── Concommande ─────────────────────────────────────────────────────────────

concommand.Add("verse_spell_balancing_open", function()
    netstream.Start(NET.OpenMenu)
end)
