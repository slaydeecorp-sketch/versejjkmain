local BT = VERSE.Boutique
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local _ui = BT._ui

-- ─── Couleurs pré-allouées pour Rolls UI (évite Color() par frame) ───────────
local _RL_COL_TOOLTIP_BG      = Color(8,   6,   20,  248)
local _RL_COL_TOOLTIP_OUT     = Color(255, 255, 255, 40)
local _RL_COL_TOOLTIP_TITLE   = Color(255, 215, 80,  255)
local _RL_COL_TOOLTIP_PCT     = Color(155, 215, 155, 255)
local _RL_COL_CONFIRM_BG      = Color(18,  16,  26,  245)
local _RL_COL_CONFIRM_OUT     = Color(171, 82,  255, 180)
local _RL_COL_CONFIRM_OUT2    = Color(171, 82,  255, 55)
local _RL_COL_CONFIRM_TXT     = Color(220, 220, 230, 255)
local _RL_COL_YES_BTN         = Color(171, 82,  255, 0)    -- .a muté
local _RL_COL_NO_BTN_BG       = Color(39,  39,  39,  0)    -- .a muté
local _RL_COL_NO_BTN_OUT      = Color(200, 200, 210, 0)    -- .a muté
local _RL_COL_TAB_SEL_BG      = Color(255, 255, 255, 70)
local _RL_COL_TAB_NORM_BG     = Color(255, 255, 255, 0)    -- .a muté
local _RL_COL_TAB_NORM_OUT    = Color(255, 255, 255, 0)    -- .a muté
local _RL_COL_TAB_NORM_TXT    = Color(220, 220, 225, 255)
local _RL_COL_PURPLE_BTN      = Color(171, 82,  255, 0)    -- .a muté
local _RL_COL_LANCER_TINT     = Color(255, 255, 255, 255)  -- .a muté
local _RL_COL_SKIP_BG         = Color(43,  43,  43,  195)
local _RL_COL_INFO_TXT        = Color(220, 220, 225, 255)
local _RL_COL_ROLLER_BG       = Color(18,  16,  26,  235)
local _RL_COL_ROLLER_OUT      = Color(255, 255, 255, 10)
local _RL_COL_POOL_EMPTY      = Color(130, 130, 150, 255)
local _RL_COL_ROLL_BORDER_DEC = Color(255, 207, 85,  0)    -- .a muté
local _RL_COL_ROLL_BORDER_NRM = Color(12,  161, 232, 200)
local _RL_COL_ROLL_ITEM_BG    = Color(14,  12,  20,  0)    -- .a muté
local _RL_COL_ROLL_EDGE_OUT   = Color(255, 255, 255, 0)    -- .a muté
local _RL_COL_ROLL_ICON       = Color(255, 255, 255, 0)    -- .a muté
local _RL_COL_ROLL_NAME_CTR   = Color(210, 210, 220, 0)    -- .a muté
local _RL_COL_ROLL_NAME_SIDE  = Color(130, 130, 145, 0)    -- .a muté
local _RL_COL_ROLL_FADE       = Color(18,  16,  26,  0)    -- .a muté
local _RL_COL_ROLL_CENTERLINE = Color(255, 255, 255, 35)
local _RL_COL_RESULT_HDR_PRE  = Color(180, 175, 200, 0)    -- .a muté
local _RL_COL_RESULT_HDR_VAL  = Color(255, 255, 255, 0)    -- .a muté
local _RL_COL_RESULT_GLOW     = Color(0,   0,   0,   0)    -- r/g/b + .a muté
local _RL_COL_RESULT_RIEN_BG  = Color(20,  18,  28,  0)    -- .a muté
local _RL_COL_RESULT_OUTLINE  = Color(0,   0,   0,   0)    -- r/g/b + .a muté
local _RL_COL_RESULT_ICON     = Color(255, 255, 255, 0)    -- .a muté
local _RL_COL_COUNTPNL_TXT   = Color(170, 170, 170, 255)
local _RL_COL_BUY_OUT         = Color(255, 255, 255, 22)
local _RL_COL_VIDEO_BG        = Color(0,   0,   0,   255)
local _RL_COL_VIDEO_LOAD_TXT  = Color(160, 160, 160, 255)
local _RL_COL_SKIP_OUT        = Color(180, 180, 180, 255)
local _RL_COL_VOL_BG          = Color(39,  39,  39,  0)    -- .a muté
local _RL_COL_VOL_OUT         = Color(180, 180, 180, 255)
local _RL_COL_VOL_LBL         = Color(180, 180, 180, 255)
local _RL_COL_VOL_TRACK       = Color(80,  80,  80,  220)
local _RL_COL_VOL_PCT         = Color(150, 150, 150, 255)
local _RL_COL_HELP_BG         = Color(0,   0,   0,   0)    -- .a muté
local _RL_COL_HELP_OUT        = Color(255, 255, 255, 0)    -- .a muté
local _RL_COL_GOLD             = Color(232, 172, 40,  255)
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── Tooltip chances de reroll héritage ──────────────────────────────────────
-- Lit BT.RerollPool en direct : toujours synchronisé avec la DB admin.
-- N'affiche que les entrées "gagnantes" (reward_type ~= "nothing").
-- Les pourcentages sont calculés sur le poids TOTAL (rien inclus) = vraies chances.

local function getRerollWinners()
    local heritageTab = nil
    for _, t in ipairs(BT.RollTabs or {}) do
        if t.page == "heritage" then heritageTab = t; break end
    end
    if not heritageTab then return {} end

    local pool = (BT.RerollPool and heritageTab.item_id and BT.RerollPool[heritageTab.item_id]) or {}
    if #pool == 0 then return {} end

    -- Poids total incluant les entrées "nothing" (pour un % exact)
    local totalW = 0
    for _, e in ipairs(pool) do
        totalW = totalW + math.max(1, math.floor(tonumber(e.weight) or 1))
    end
    if totalW <= 0 then return {} end

    -- Uniquement les entrées qui donnent quelque chose (pas "nothing" ni "rien")
    local winners = {}
    for _, e in ipairs(pool) do
        local isNothing = tostring(e.reward_type or "") == "nothing"
        local isRien    = string.lower(tostring(e.name or "")) == "rien"
        if not isNothing and not isRien then
            local w  = math.max(1, math.floor(tonumber(e.weight) or 1))
            local rc = BT:GetRarityColor(e.rarity) or Color(180, 180, 180)
            winners[#winners + 1] = {
                title  = tostring(e.name or "?"),
                color  = rc,
                chance = (w / totalW) * 100,
            }
        end
    end
    return winners
end

local function drawRerollTooltip(px, py)
    local winners = getRerollWinners()
    if #winners == 0 then return end

    local pad     = 10
    local lineH   = 18
    local titleH  = 22
    local gapH    = 6
    local dotSize = 7
    local tooltipW = 200
    local tooltipH = math.ceil(pad * 2 + titleH + gapH + #winners * lineH)
    local tx = px
    local ty = py + 6

    RNDX.Draw(10, tx, ty, tooltipW, tooltipH, _RL_COL_TOOLTIP_BG)
    RNDX.DrawOutlined(10, tx, ty, tooltipW, tooltipH, _RL_COL_TOOLTIP_OUT, 1)

    local titleFont = Font:GetNamed("Poppins", "Bold", 13)
    local entryFont = Font:GetNamed("Poppins", "Regular", 11)
    local cy = ty + pad

    draw.SimpleText("Chances de Reroll", titleFont, tx + tooltipW * 0.5, cy + titleH * 0.5,
        _RL_COL_TOOLTIP_TITLE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cy = cy + titleH + gapH

    for _, entry in ipairs(winners) do
        local pctStr = string.format("%.1f%%", entry.chance)
        local ex     = tx + pad + 4
        RNDX.Draw(dotSize * 0.5, ex, cy + (lineH - dotSize) * 0.5, dotSize, dotSize, entry.color)
        draw.SimpleText(entry.title, entryFont, ex + dotSize + 5, cy + lineH * 0.5,
            color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(pctStr, entryFont, tx + tooltipW - pad, cy + lineH * 0.5,
            _RL_COL_TOOLTIP_PCT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        cy = cy + lineH
    end
end

-- ─────────────────────────────────────────────────────────────────────────────

local ROLL_TICK_SOUND = "verse/roll/csgo_ui_crate_item_scroll.wav"
local ROLL_TICK_MIN_INTERVAL = 0.04
local ROLL_OPEN_SOUND = "verse/roll/csgo_ui_crate_open.wav"
local ROLL_DROP_SOUNDS = {
    common = "verse/roll/item_drop_common.wav",
    uncommon = "verse/roll/item_drop_uncommon.wav",
    rare = "verse/roll/item_drop_rare.wav",
    epic = "verse/roll/item_drop_legendary.wav",
    legendary = "verse/roll/item_drop_mythical.wav",
    ancient = "verse/roll/item_drop_ancient.wav",
    immortal = "verse/roll/item_drop_immortal.wav",
    mythic = "verse/roll/item_drop_mythical.wav",
}

local ROLL_DROP_DEFAULT = "verse/roll/item_drop.wav"
do
    util.PrecacheSound(ROLL_TICK_SOUND)
    util.PrecacheSound(ROLL_OPEN_SOUND)
    for _, s in pairs(ROLL_DROP_SOUNDS) do
        util.PrecacheSound(s)
    end

    util.PrecacheSound(ROLL_DROP_DEFAULT)
end

local function playRollTick(spin)
    if not spin then return end
    local now = SysTime()
    if spin._lastTickAt and (now - spin._lastTickAt) < ROLL_TICK_MIN_INTERVAL then return end
    spin._lastTickAt = now
    surface.PlaySound(ROLL_TICK_SOUND)
end

local function playDropSound(result)
    local rarity = tostring(result and result.rarity or "common"):lower()
    local path = ROLL_DROP_SOUNDS[rarity] or ROLL_DROP_DEFAULT
    surface.PlaySound(path)
end

local function updateTickState(spin, iFrac)
    if not spin or not spin.active then return end
    local centerIdx = math.floor(iFrac + 0.5)
    if spin._lastCenterIdx == nil then
        spin._lastCenterIdx = centerIdx
        return
    end

    if centerIdx ~= spin._lastCenterIdx then
        spin._lastCenterIdx = centerIdx
        playRollTick(spin)
    end
end

local function getRollTab(page)
    for _, tab in ipairs(BT.RollTabs or {}) do
        if tab.page == page then return tab end
    end
    return {}
end

local function _entryKey(entry)
    if not entry then return "" end
    return string.lower(tostring(entry.name or entry.id or ""))
end

local function _separateDuplicates(list)
    local n = #list
    if n < 2 then return end
    for pass = 1, 6 do
        local changed = false
        for i = 1, n do
            local nextI = (i % n) + 1
            if _entryKey(list[i]) == _entryKey(list[nextI]) then
                local found = false
                for offset = 2, n - 1 do
                    local j = ((i + offset - 1) % n) + 1
                    if j ~= i and j ~= nextI then
                        local jKey = _entryKey(list[j])
                        local iKey = _entryKey(list[i])
                        local prevJ = ((j - 2) % n) + 1
                        local nextJ = (j % n) + 1
                        local prevKey = _entryKey(list[prevJ])
                        local nextKey = _entryKey(list[nextJ])
                        if jKey ~= iKey and prevKey ~= iKey and nextKey ~= iKey then
                            list[nextI], list[j] = list[j], list[nextI]
                            changed = true
                            found = true
                            break
                        end
                    end
                end

                if not found then
                    for tries = 1, n do
                        local j = math.random(n)
                        if j ~= i and j ~= nextI and _entryKey(list[j]) ~= _entryKey(list[i]) then
                            list[nextI], list[j] = list[j], list[nextI]
                            changed = true
                            break
                        end
                    end
                end
            end
        end

        if not changed then break end
    end
end

local function shufflePool(pool)
    local shuffled = {}
    if not pool then return shuffled end
    for i = 1, #pool do
        shuffled[i] = pool[i]
    end

    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    _separateDuplicates(shuffled)
    return shuffled
end

local function getDisplayPool(spin, rawPool)
    if not rawPool or #rawPool == 0 then return rawPool end
    if not spin then return rawPool end
    if not spin.shuffledPool or #spin.shuffledPool ~= #rawPool then spin.shuffledPool = shufflePool(rawPool) end
    return spin.shuffledPool
end

local function beginOccultRoll()
    if BT._state.rollAnim.occult and BT._state.rollAnim.occult.active then return end
    local tab = getRollTab("power")
    if _ui.getItemCount(tab.item_id or "") <= 0 then
        BT:SetPage("rerolls")
        return
    end

    local startedAt = SysTime()
    BT._state.rollAnim.occult = {
        active = true,
        startedAt = startedAt,
        scrollFrac = 0,
        result = nil,
        resultIdx = nil,
        targetFrac = nil,
        animStartFrac = nil,
        animStartTime = nil,
        animDuration = 5.2,
        navigating = false,
    }

    surface.PlaySound(ROLL_OPEN_SOUND)
    netstream.Start(BT.Net.StartOccultRoll)
    timer.Simple(12, function()
        local spin = BT._state and BT._state.rollAnim and BT._state.rollAnim.occult
        if spin and spin.startedAt == startedAt and spin.active and not spin.result then spin.active = false end
    end)
end

local function doBeginHeritageRoll()
    if BT._state.rollAnim.heritageBusy then return end
    local tab = getRollTab("heritage")
    if _ui.getItemCount(tab.item_id or "") <= 0 then
        LocalPlayer():Notify("Aucun reroll heritage disponible.", NOTIFY_ERROR, 4)
        return
    end

    local startedAt = SysTime()
    BT._state.heritageResolved = false
    BT._state.rollAnim.heritageBusy = true
    BT._state.rollAnim.heritageRequestId = startedAt
    BT._state.rollAnim.heritageVideoShown = false
    BT._state.rollAnim.heritagePendingFlip = false
    BT._state.rollAnim.heritageAnim = {
        active = true,
        startedAt = startedAt,
        scrollFrac = 0,
        result = nil,
        resultIdx = nil,
        targetFrac = nil,
        animStartFrac = nil,
        animStartTime = nil,
        animDuration = 6.5,
        navigating = false,
    }

    if BT._state.page == "heritage" then BT:RebuildContent() end
    surface.PlaySound(ROLL_OPEN_SOUND)
    netstream.Start(BT.Net.StartHeritageRoll)
    timer.Simple(15, function()
        local rollAnim = BT._state and BT._state.rollAnim
        if not rollAnim or rollAnim.heritageRequestId ~= startedAt then return end
        if rollAnim.heritageBusy then
            rollAnim.heritageBusy = false
            rollAnim.heritageRequestId = 0
            rollAnim.heritageAnim = nil
            if BT._state.page == "heritage" then BT:RebuildContent() end
        end
    end)
end

local function openBoutiqueConfirm(title, message, onYes, onNo, yesLabel, noLabel)
    if IsValid(BT._confirmPanel) then BT._confirmPanel:Remove() end
    local parent = BT._frame
    if not IsValid(parent) then return end
    local overlay = vgui.Create("DPanel", parent)
    overlay:SetPos(0, 0)
    overlay:SetSize(R:X(1920), R:Y(1080))
    overlay:MoveToFront()
    overlay:SetMouseInputEnabled(true)
    overlay.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 190)
        surface.DrawRect(0, 0, w, h)
    end

    BT._confirmPanel = overlay
    local panelW = R:X(620)
    local panelH = R:Y(260)
    local panelX = (R:X(1920) - panelW) * 0.5
    local panelY = (R:Y(1080) - panelH) * 0.5
    local panel = vgui.Create("DPanel", overlay)
    panel:SetPos(panelX, panelY)
    panel:SetSize(panelW, panelH)
    local _confirmTitleFont = Font:GetNamed("Poppins", "Bold",   26)
    local _confirmMsgFont   = Font:GetNamed("Poppins", "Medium", 18)
    panel.Paint = function(_, w, h)
        RNDX.Draw(R:Y(18), 0, 0, w, h, _RL_COL_CONFIRM_BG)
        RNDX.DrawOutlined(R:Y(18), 0, 0, w, h, _RL_COL_CONFIRM_OUT, 2)
        RNDX.DrawOutlined(R:Y(18), -R:X(2), -R:Y(2), w + R:X(4), h + R:Y(4), _RL_COL_CONFIRM_OUT2, 1)
        draw.SimpleText(title or "Confirmation", _confirmTitleFont, w * 0.5, R:Y(38), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local lines, _, totalH = VERSE.TextWrap(message or "", _confirmMsgFont, R:Y(26), w - R:X(80))
        local startY = R:Y(100) - totalH * 0.5
        for i, line in ipairs(lines) do
            draw.SimpleText(line, _confirmMsgFont, w * 0.5, startY + (i - 1) * R:Y(26), _RL_COL_CONFIRM_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end

    local bw = R:X(178)
    local bh = R:Y(46)
    local gap = R:X(20)
    local totalBW = bw * 2 + gap
    local bx0 = (panelW - totalBW) * 0.5
    local by = panelH - bh - R:Y(30)
    local yesBtn = vgui.Create("DButton", panel)
    yesBtn:SetPos(bx0, by)
    yesBtn:SetSize(bw, bh)
    yesBtn:SetText("")
    local _yesBtnFont = Font:GetNamed("Poppins", "SemiBold", 20)
    yesBtn.Paint = function(s, w, h)
        _RL_COL_YES_BTN.a = s:IsHovered() and 240 or 210
        RNDX.Draw(R:Y(14), 0, 0, w, h, _RL_COL_YES_BTN)
        draw.SimpleText(yesLabel or "Oui", _yesBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    yesBtn.DoClick = function()
        if IsValid(overlay) then overlay:Remove() end
        BT._confirmPanel = nil
        if isfunction(onYes) then onYes() end
    end

    local noBtn = vgui.Create("DButton", panel)
    noBtn:SetPos(bx0 + bw + gap, by)
    noBtn:SetSize(bw, bh)
    noBtn:SetText("")
    local _noBtnFont = Font:GetNamed("Poppins", "SemiBold", 20)
    noBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        _RL_COL_NO_BTN_BG.a  = hov and 230 or 190
        _RL_COL_NO_BTN_OUT.a = hov and 200 or 150
        RNDX.Draw(R:Y(14), 0, 0, w, h, _RL_COL_NO_BTN_BG)
        RNDX.DrawOutlined(R:Y(14), 0, 0, w, h, _RL_COL_NO_BTN_OUT, 2)
        draw.SimpleText(noLabel or "Non", _noBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    noBtn.DoClick = function()
        if IsValid(overlay) then overlay:Remove() end
        BT._confirmPanel = nil
        if isfunction(onNo) then onNo() end
    end
end

local function beginHeritageRoll()
    if BT._state.rollAnim.heritageBusy then return end
    -- La confirmation se fait APRÈS le résultat (popup "Garder / Obtenir").
    -- Pas besoin de bloquer avant le roll.
    doBeginHeritageRoll()
end

local function buildRollTabs(parent, selectedPage)
    local tabs = BT.RollTabs or {}
    if #tabs == 0 then return end
    local tabW = R:X(353)
    local tabH = R:Y(57)
    local tabGap = R:X(24)
    local totalW = #tabs * tabW + (#tabs - 1) * tabGap
    local startX = R:X(960) - totalW * 0.5
    for i, tab in ipairs(tabs) do
        local isSel = selectedPage == tab.page or selectedPage == tab.page .. "_result"
        local tabX = startX + (i - 1) * (tabW + tabGap)
        local btn = vgui.Create("DButton", parent)
        btn:SetPos(tabX, R:Y(160))
        btn:SetSize(tabW, tabH)
        btn:SetZPos(5)
        btn:SetText("")
        local _sel = isSel
        local _tab = tab
        local selColor = tab.accent_active or Color(181, 181, 181)
        -- Couleurs pré-allouées pour cet onglet
        local _tabSelOut    = Color(selColor.r, selColor.g, selColor.b, 230)
        local _tabSelGlow   = Color(selColor.r, selColor.g, selColor.b, 55)
        local _tabBoldFont  = Font:GetNamed("Poppins", "Bold",     20)
        local _tabSemiFont  = Font:GetNamed("Poppins", "SemiBold", 20)
        btn.Paint = function(s, w, h)
            if _sel then
                RNDX.Draw(R:Y(9), 0, 0, w, h, _RL_COL_TAB_SEL_BG)
                RNDX.DrawOutlined(R:Y(9), 0, 0, w, h, _tabSelOut, 2)
                RNDX.DrawOutlined(R:Y(9), -R:X(2), -R:Y(2), w + R:X(4), h + R:Y(4), _tabSelGlow, 1)
            else
                local hov = s:IsHovered()
                _RL_COL_TAB_NORM_BG.a  = hov and 50 or 28
                _RL_COL_TAB_NORM_OUT.a = hov and 80 or 45
                RNDX.Draw(R:Y(9), 0, 0, w, h, _RL_COL_TAB_NORM_BG)
                RNDX.DrawOutlined(R:Y(9), 0, 0, w, h, _RL_COL_TAB_NORM_OUT, 1)
            end

            local col = _sel and selColor or _RL_COL_TAB_NORM_TXT
            local labelFont = _sel and _tabBoldFont or _tabSemiFont
            local labelW = VERSE.GetTextSize(_tab.label, labelFont)
            local gap = R:X(8)
            local totalLW = gap + labelW
            local startLX = (w - totalLW) * 0.5
            draw.SimpleText(_tab.label, labelFont, startLX + gap, h * 0.5, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function() BT:SetPage(tab.page) end
    end
end

local function buildPurpleButton(parent, y, label, callback, w, h)
    local bw = w or R:X(193)
    local bh = h or R:Y(52)
    local bx = R:X(960) - bw * 0.5
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(bx, R:Y(y))
    btn:SetSize(bw, bh)
    btn:SetText("")
    btn.Paint = function(s, pw, ph)
        _RL_COL_LANCER_TINT.a = s:IsHovered() and 255 or 175
        Materials:Draw(_RL_COL_LANCER_TINT, "lancer_button", 0, 0, pw, ph, "noclamp smooth")
    end

    btn.DoClick = function() if isfunction(callback) then callback() end end
    return btn
end

local function buildSkipButton(parent, y, w, h, isSpinningFn, skipFn)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(R:X(960) - w * 0.5, R:Y(y))
    btn:SetSize(w, h)
    btn:SetText("")
    local _skipFont = Font:GetNamed("Poppins", "Bold", 32)
    btn.Paint = function(s, pw, ph)
        local active = isSpinningFn()
        RNDX.Draw(R:Y(12), 0, 0, pw, ph, _RL_COL_SKIP_BG)

        local txtA = active and 255 or 120
        surface.SetFont(_skipFont)
        local label = "SKIP"
        local tw = surface.GetTextSize(label)
        local iconW = R:X(20)
        local gap = R:X(8)
        local startX = (pw - (tw + gap + iconW)) * 0.5
        local cy = ph * 0.5
        local _skipTxt = Color(255, 255, 255, txtA)
        draw.SimpleText(label, _skipFont, startX, cy, _skipTxt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local ix = startX + tw + gap
        local triW = R:X(13)
        local triH = R:Y(18)
        surface.SetDrawColor(255, 255, 255, txtA)
        draw.NoTexture()
        surface.DrawPoly({
            { x = ix, y = cy - triH * 0.5 },
            { x = ix + triW, y = cy },
            { x = ix, y = cy + triH * 0.5 },
        })
        surface.DrawRect(ix + triW + R:X(3), cy - triH * 0.5, R:X(4), triH)
    end

    btn.DoClick = function() if isSpinningFn() then skipFn() end end
    return btn
end

local function getCurrentBranchTitle(groupId)
    local ST = VERSE.SkillTree
    if not ST then return "Aucun" end
    local branches = istable(ST.Client) and istable(ST.Client.branches) and ST.Client.branches or {}
    local subId = tostring(branches[groupId] or "")
    if subId == "" then return "Aucun" end
    local _, sub = ST:GetCategoryForSubtype(subId)
    return (sub and sub.title) or "Aucun"
end

local function buildRerollBanner(parent, material, w, h, y)
    local pnl = vgui.Create("DPanel", parent)
    pnl:SetSize(w, h)
    pnl:SetPos(R:X(960) - w * 0.5, R:Y(y))
    pnl:SetMouseInputEnabled(false)
    pnl:SetZPos(-1)
    pnl.Paint = function(_, pw, ph)
        Materials:Draw(color_white, material, 0, 0, pw, ph, "noclamp smooth")
    end
    return pnl
end

local function isOccultSpinning()
    local spin = BT._state.rollAnim and BT._state.rollAnim.occult
    return spin and spin.active == true
end

local function isHeritageSpinning()
    if BT._state.rollAnim and BT._state.rollAnim.heritageBusy then return true end
    local spin = BT._state.rollAnim and BT._state.rollAnim.heritageAnim
    return spin and spin.active == true
end

local function skipOccultRoll()
    local spin = BT._state.rollAnim and BT._state.rollAnim.occult
    if not spin or not spin.active then return end
    spin.skip = true
end

local function skipHeritageRoll()
    local spin = BT._state.rollAnim and BT._state.rollAnim.heritageAnim
    if not spin or not spin.active then return end
    spin.skip = true
end

local function buildResultLayout(parent, result, relancerCallback, relancerY)
    local rc = BT:GetRarityColor(result.rarity)
    local name = tostring(result.name or "Résultat inconnu")
    local rar = string.upper(tostring(result.rarity or "commun"))
    local revealTime = SysTime()
    local assetKey = (result.asset and result.asset ~= "") and result.asset or "reroll_result_img"
    local isRien = string.lower(name) == "rien"
    local canvas = vgui.Create("DPanel", parent)
    canvas:SetPos(0, 0)
    canvas:SetSize(R:X(1920), R:Y(1080))
    canvas:SetMouseInputEnabled(false)
    -- Couleurs pré-allouées pour ce résultat (rc est dynamique par rareté)
    local _resGlow    = Color(rc.r, rc.g, rc.b, 0)   -- .a muté
    local _resOutline = Color(rc.r, rc.g, rc.b, 0)   -- .a muté
    local _resRienBg  = Color(20,  18,  28,  0)       -- .a muté
    local _resIcon    = Color(255, 255, 255, 0)        -- .a muté
    local _resHdrPre  = Color(180, 175, 200, 0)        -- .a muté
    local _resHdrVal  = Color(255, 255, 255, 0)        -- .a muté
    local _resRegFont = Font:GetNamed("Poppins", "Regular", 22)
    local _resBldFont = Font:GetNamed("Poppins", "Bold",    22)
    local _resBigFont = Font:GetNamed("Poppins", "Bold",    64)
    canvas.Paint = function(_, w, h)
        local now = SysTime()
        local elapsed = now - revealTime
        local cx = w * 0.5
        local pulse = (math.sin(now * 1.1) + 1) * 0.5
        local hdrT = math.Clamp(elapsed / 0.35, 0, 1)
        local hdrE = 1 - (1 - hdrT) ^ 2
        if hdrT > 0 then
            local offY = math.floor((1 - hdrE) * R:Y(8))
            local hdrY = R:Y(320) - offY
            local prefix = "Vous avez obtenu :  "
            local value = name .. "  -  " .. rar
            local prefixW = VERSE.GetTextSize(prefix, _resRegFont)
            local valueW = VERSE.GetTextSize(value, _resBldFont)
            local startX = math.floor(cx - (prefixW + valueW) * 0.5)
            _resHdrPre.a = math.floor(hdrE * 190)
            _resHdrVal.a = math.floor(hdrE * 255)
            draw.SimpleText(prefix, _resRegFont, startX, hdrY, _resHdrPre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(value, _resBldFont, startX + prefixW, hdrY, _resHdrVal, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local imgT = math.Clamp(elapsed / 0.55, 0, 1)
        local imgEase = 1 - (1 - imgT) ^ 3
        if imgEase <= 0.01 then return end
        local imgSz = R:X(291)
        local imgCX = cx
        local imgCY = R:Y(510)
        local dSz = math.floor(imgSz * (0.90 + imgEase * 0.10))
        local dX = math.floor(imgCX - dSz * 0.5)
        local dY = math.floor(imgCY - dSz * 0.5)
        local dA = math.floor(imgEase * 255)
        local cr = R:Y(18)
        _resGlow.a = math.floor(22 * imgEase)
        RNDX.Draw(cr, dX - R:X(4), dY - R:Y(4), dSz + R:X(8), dSz + R:Y(8), _resGlow)
        if isRien then
            _resRienBg.a = math.floor(210 * imgEase)
            RNDX.Draw(cr, dX, dY, dSz, dSz, _resRienBg)
            _resIcon.a = dA
            draw.SimpleText("Rien", _resBigFont, imgCX, imgCY, _resIcon, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            _resIcon.a = dA
            Materials:Draw(_resIcon, assetKey, dX, dY, dSz, dSz, "noclamp smooth")
        end

        _resOutline.a = math.floor((160 + 95 * pulse) * imgEase)
        RNDX.DrawOutlined(cr, dX, dY, dSz, dSz, _resOutline, 2)
    end

    -- relancerY permet d'aligner le bouton "Relancer" sur le bouton "Skip" de la
    -- page de tirage correspondante (héritage = 920, occulte = 796 par défaut).
    buildPurpleButton(parent, relancerY or 796, "Relancer", relancerCallback)
end

local function buildOccultRollPage(parent)
    local tab = getRollTab("power")
    buildRollTabs(parent, "power")
    local SPIN_IPS = 10.0
    local ANIM_DURATION = 5.2
    local roller = vgui.Create("DPanel", parent)
    roller:SetPos(R:XY(281, 550))
    roller:SetSize(R:XY(1358, 252))
    roller.Paint = function(_, w, h)
        RNDX.Draw(R:Y(16), 0, 0, w, h, _RL_COL_ROLLER_BG)
        RNDX.DrawOutlined(R:Y(16), 0, 0, w, h, _RL_COL_ROLLER_OUT, 1)
        local rawPool = (BT.RerollPool and tab.item_id and BT.RerollPool[tab.item_id]) or {}
        if #rawPool == 0 then return end
        local spin = BT._state.rollAnim.occult
        local pool = getDisplayPool(spin, rawPool)
        local poolSize = #pool
        local now = SysTime()
        local isActive = spin and spin.active
        if isActive then
            if not spin.result then
                spin.scrollFrac = (now - spin.startedAt) * SPIN_IPS
            else
                if not spin.targetFrac then
                    spin.resultIdx = 0
                    for idx, entry in ipairs(pool) do
                        if tostring(entry.id or "") == tostring(spin.result.id or "") then
                            spin.resultIdx = idx - 1
                            break
                        end
                    end

                    local minExtra = poolSize * 5 + poolSize * 0.5
                    local ri = spin.resultIdx
                    local N = math.ceil((spin.scrollFrac + minExtra - ri) / poolSize)
                    local jitter = (math.random() - 0.5) * 0.96
                    spin.targetFrac = ri + N * poolSize + jitter
                    spin.animStartFrac = spin.scrollFrac
                    spin.animStartTime = now
                end

                local t
                if spin.skip then
                    t = 1
                else
                    t = math.Clamp((now - spin.animStartTime) / ANIM_DURATION, 0, 1)
                end

                local ease = 1 - (1 - t) ^ 15
                spin.scrollFrac = spin.animStartFrac + (spin.targetFrac - spin.animStartFrac) * ease
                updateTickState(spin, spin.scrollFrac)
                if t >= 1 then
                    spin.active = false
                    spin.scrollFrac = spin.targetFrac
                    isActive = false
                    BT._state.lastRoll = spin.result
                    if not spin._droppedSfx then
                        spin._droppedSfx = true
                        playDropSound(spin.result)
                    end

                    if not spin.navigating then
                        spin.navigating = true
                        local delay = spin.skip and 0 or 0.7
                        timer.Simple(delay, function() if BT._state.page == "power" then BT:SetPage("occult_result") end end)
                    end
                end
            end
        end

        local scrollFrac = 0
        if spin then
            scrollFrac = spin.scrollFrac or 0
        else
            local lastRoll = BT._state.lastRoll
            if lastRoll and lastRoll.kind == "occult" then
                for idx, entry in ipairs(pool) do
                    if tostring(entry.id or "") == tostring(lastRoll.id or "") then
                        scrollFrac = idx - 1
                        break
                    end
                end
            end
        end

        local baseW = R:X(231)
        local baseH = R:Y(231)
        local gridW = R:X(247)
        local baseY = (h - baseH) * 0.5
        local cx = w * 0.5
        local isDecelerating = spin and spin.active and spin.result ~= nil
        local isDone = spin and not spin.active and spin.result ~= nil
        local borderCol
        if isDecelerating or isDone then
            local pulse = math.abs(math.sin(now * 3.5))
            _RL_COL_ROLL_BORDER_DEC.a = isDecelerating and math.floor(150 + 105 * pulse) or 255
            borderCol = _RL_COL_ROLL_BORDER_DEC
        else
            borderCol = _RL_COL_ROLL_BORDER_NRM
        end

        local _occultNameFontCtr  = Font:GetNamed("Poppins", "SemiBold", 14)
        local _occultNameFontSide = Font:GetNamed("Poppins", "SemiBold", 11)
        local halfVisible = math.ceil(w / gridW / 2) + 2
        local iFrac = scrollFrac
        local iMin = math.floor(iFrac) - halfVisible
        local iMax = math.ceil(iFrac) + halfVisible
        for i = iMin, iMax do
            local poolIdx = i % poolSize
            if poolIdx < 0 then poolIdx = poolIdx + poolSize end
            local entry = pool[poolIdx + 1]
            if entry then
                local dist = math.abs(i - iFrac)
                local dW = baseW
                local dH = baseH
                local dx = math.floor((i - iFrac) * gridW + cx - baseW * 0.5)
                local dy = math.floor(baseY)
                if dx + dW >= -2 and dx <= w + 2 then
                    local alpha = 255
                    local isCenter = dist < 0.5
                    _RL_COL_ROLL_ITEM_BG.a = isCenter and 245 or 220
                    RNDX.Draw(R:Y(14), dx, dy, dW, dH, _RL_COL_ROLL_ITEM_BG)
                    if isCenter then
                        RNDX.DrawOutlined(R:Y(14), dx, dy, dW, dH, borderCol, 2)
                    end

                    local pad = R:Y(14)
                    local textZoneH = R:Y(46)
                    -- Zone image carrée : prend le plus petit côté disponible
                    local availW = dW - pad * 2
                    local availH = dH - textZoneH - pad
                    local iconSq = math.min(availW, availH)
                    local iconX = dx + math.floor((dW - iconSq) * 0.5)
                    local iconY = dy + pad + math.floor((availH - iconSq) * 0.5)
                    local iconPath = (entry.icon and entry.icon ~= "") and entry.icon or (entry.asset and entry.asset ~= "" and entry.asset or nil)
                    if iconPath then
                        _RL_COL_ROLL_ICON.a = math.max(alpha, 0)
                        Materials:Draw(_RL_COL_ROLL_ICON, iconPath, iconX, iconY, iconSq, iconSq, "noclamp smooth")
                    else
                        _ui.drawOccultFallback(entry, iconX, iconY, iconSq, iconSq)
                    end

                    if alpha > 20 then
                        local nameFont = isCenter and _occultNameFontCtr or _occultNameFontSide
                        local nameCol
                        if isCenter then
                            _RL_COL_ROLL_NAME_CTR.a = alpha
                            nameCol = _RL_COL_ROLL_NAME_CTR
                        else
                            _RL_COL_ROLL_NAME_SIDE.a = alpha
                            nameCol = _RL_COL_ROLL_NAME_SIDE
                        end
                        draw.SimpleText(string.upper(tostring(entry.name or "?")), nameFont, dx + dW * 0.5, dy + dH - textZoneH * 0.5, nameCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
        end

        RNDX.Draw(0, math.floor(cx - 1), 0, 2, h, _RL_COL_ROLL_CENTERLINE)
        local arAlpha = isDecelerating and math.floor(120 + 135 * math.abs(math.sin(now * 4))) or 210
        surface.SetDrawColor(225, 140, 255, arAlpha)
        draw.NoTexture()
        surface.DrawPoly({
            {
                x = cx - R:X(13),
                y = R:Y(4)
            },
            {
                x = cx + R:X(13),
                y = R:Y(4)
            },
            {
                x = cx,
                y = R:Y(22)
            },
        })

        surface.DrawPoly({
            {
                x = cx - R:X(13),
                y = h - R:Y(4)
            },
            {
                x = cx + R:X(13),
                y = h - R:Y(4)
            },
            {
                x = cx,
                y = h - R:Y(22)
            },
        })
    end

    buildRerollBanner(parent, "pouvoir_reroll_banner", R:X(827), R:Y(465), 220)

    buildPurpleButton(parent, 805, tab.launch_label or "Lancer", function()
        if not isOccultSpinning() then beginOccultRoll() end
    end, R:X(349), R:Y(81))
    buildSkipButton(parent, 904, R:X(349), R:Y(39), isOccultSpinning, skipOccultRoll)

    local _infoFont = Font:GetNamed("Poppins", "Regular", 24)
    local infoPnl = vgui.Create("DPanel", parent)
    infoPnl:SetPos(0, R:Y(830))
    infoPnl:SetSize(R:X(1920), R:Y(30))
    infoPnl:SetMouseInputEnabled(false)
    infoPnl.Paint = function(_, w, h)
        local count = _ui.getItemCount(tab.item_id or "")
        draw.SimpleText("Reroll restant : " .. tostring(count), _infoFont, R:X(285), h * 0.5, _RL_COL_INFO_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Pouvoir actuel : " .. getCurrentBranchTitle("cursed_power_branch"), _infoFont, R:X(1635), h * 0.5, _RL_COL_INFO_TXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local buyBtn = vgui.Create("DButton", parent)
    buyBtn:SetPos(R:XY(783, 1080 - 40 - 30))
    buyBtn:SetSize(R:XY(353, 40))
    buyBtn:SetText("")
    local _buyBtnFont = Font:GetNamed("Poppins", "Bold", 36)
    buyBtn.Paint = function(s, w, h)
        draw.SimpleText("Acheter des rerolls", _buyBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    buyBtn.DoClick = function() BT:SetPage("rerolls") end
    _ui.createBackButton(parent)
end

local function buildOccultResultPage(parent)
    buildRollTabs(parent, "occult_result")
    buildResultLayout(parent, BT._state.lastRoll or {}, function()
        BT:SetPage("power")
        beginOccultRoll()
    end)

    _ui.createBackButton(parent)
    -- Pas de popup de confirmation pour le pouvoir occulte : il s'applique
    -- directement côté serveur (le popup de remplacement est réservé à l'héritage).
end

local function buildHeritagePage(parent)
    local tab = getRollTab("heritage")
    buildRollTabs(parent, "heritage")
    local SPIN_IPS = 8.0
    local ANIM_DURATION = 6.5
    local heritageSpin = BT._state.rollAnim and BT._state.rollAnim.heritageAnim
    local pendingFlip = BT._state.rollAnim and BT._state.rollAnim.heritagePendingFlip
    local showBanner = not pendingFlip and not (heritageSpin and heritageSpin.active)
    if showBanner and BT._state.rollAnim then
        BT._state.rollAnim.heritageAnim = nil
        BT._state.rollAnim.heritagePendingFlip = false
        heritageSpin = nil
    end

    if pendingFlip and heritageSpin and heritageSpin.result then
        heritageSpin.flipStartedAt = SysTime()
        heritageSpin.navigating = false
        BT._state.rollAnim.heritagePendingFlip = false
        BT._state.rollAnim.heritageVideoShown = true
    end

    if showBanner then
        local bannerW = R:X(1000)
        local bannerH = R:Y(530)
        local bannerX = (R:X(1920) - bannerW) * 0.5
        local bannerY = R:Y(270)
        local banner = vgui.Create("DPanel", parent)
        banner:SetPos(bannerX, bannerY)
        banner:SetSize(bannerW, bannerH)
        banner.Paint = function(_, w, h)
            local asset = tab.hero_img or "revolution_pouvoir_img"
            Materials:Draw(color_white, asset, 0, 0, w, h, "noclamp smooth")
        end

        -- Bouton "!" coin bas-gauche de la bannière
        local btnSize = R:Y(30)
        local helpBtn = vgui.Create("DButton", banner)
        helpBtn:SetText("")
        helpBtn:SetPos(R:X(105), bannerH - btnSize - R:Y(65))
        helpBtn:SetSize(btnSize, btnSize)
        helpBtn:SetCursor("hand")
        local _helpBtnFont = Font:GetNamed("Poppins", "Bold", 16)
        helpBtn.Paint = function(s, w, h)
            s._hoverFrac = Lerp(math.min(FrameTime() * 10, 1), s._hoverFrac or 0, s:IsHovered() and 1 or 0)
            local hf = s._hoverFrac or 0
            _RL_COL_HELP_BG.a  = math.floor(Lerp(hf, 200, 235))
            _RL_COL_HELP_OUT.a = math.floor(Lerp(hf, 70, 160))
            RNDX.Draw(w * 0.5, 0, 0, w, h, _RL_COL_HELP_BG)
            RNDX.DrawOutlined(w * 0.5, 0, 0, w, h, _RL_COL_HELP_OUT, 1)
            draw.SimpleText("!", _helpBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if s:IsHovered() then
                DisableClipping(true)
                drawRerollTooltip(0, h)  -- py = bas du bouton → tooltip en dessous
                DisableClipping(false)
            end
        end
        helpBtn.DoClick = function() end
    end

    local roller = vgui.Create("DPanel", parent)
    roller:SetPos(R:XY(281, 550))
    roller:SetSize(R:XY(1358, 252))
    roller:SetVisible(not showBanner)
    local _heritagePoolEmptyFont = Font:GetNamed("Poppins", "Regular", 16)
    roller.Paint = function(_, w, h)
        RNDX.Draw(R:Y(16), 0, 0, w, h, _RL_COL_ROLLER_BG)
        RNDX.DrawOutlined(R:Y(16), 0, 0, w, h, _RL_COL_ROLLER_OUT, 1)
        local rawPool = (BT.RerollPool and tab.item_id and BT.RerollPool[tab.item_id]) or {}
        if #rawPool == 0 then
            draw.SimpleText("Pool vide", _heritagePoolEmptyFont, w * 0.5, h * 0.5, _RL_COL_POOL_EMPTY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local spin = BT._state.rollAnim.heritageAnim
        local pool = getDisplayPool(spin, rawPool)
        local poolSize = #pool
        local now = SysTime()
        local isActive = spin and spin.active
        if isActive then
            if not spin.result then
                spin.scrollFrac = (now - spin.startedAt) * SPIN_IPS
            else
                if not spin.targetFrac then
                    spin.resultIdx = 0
                    for idx, entry in ipairs(pool) do
                        if tostring(entry.id or "") == tostring(spin.result.id or "") then
                            spin.resultIdx = idx - 1
                            break
                        end
                    end

                    local minExtra = poolSize * 5 + poolSize * 0.5
                    local ri = spin.resultIdx
                    local N = math.ceil((spin.scrollFrac + minExtra - ri) / poolSize)
                    local jitter = (math.random() - 0.5) * 0.96
                    spin.targetFrac = ri + N * poolSize + jitter
                    spin.animStartFrac = spin.scrollFrac
                    spin.animStartTime = now
                end

                local t
                if spin.skip then
                    t = 1
                else
                    t = math.Clamp((now - spin.animStartTime) / ANIM_DURATION, 0, 1)
                end

                -- Phase 1 (0 → 1.5s) : vitesse constante rapide
                -- Phase 2 (1.5s → 6.5s) : décélération progressive ease-out
                -- FRAC1=0.6 et exposant=5 assurent une vitesse continue à la jonction
                local SPLIT = 1.5 / ANIM_DURATION
                local _n = 5
                local FRAC1 = _n * SPLIT / (1 - SPLIT + _n * SPLIT)
                local ease
                if t < SPLIT then
                    ease = (t / SPLIT) * FRAC1
                else
                    local t2 = (t - SPLIT) / (1 - SPLIT)
                    ease = FRAC1 + (1 - FRAC1) * (1 - (1 - t2) ^ _n)
                end
                spin.scrollFrac = spin.animStartFrac + (spin.targetFrac - spin.animStartFrac) * ease
                updateTickState(spin, spin.scrollFrac)
                if t >= 1 then
                    spin.active = false
                    spin.scrollFrac = spin.targetFrac
                    isActive = false
                    BT._state.lastRoll = spin.result
                    if not spin._droppedSfx then
                        spin._droppedSfx = true
                        playDropSound(spin.result)
                    end

                    local videoUrl = (spin.result and spin.result.video_url) or ""
                    if videoUrl ~= "" and not (BT._state.rollAnim and BT._state.rollAnim.heritageVideoShown) then
                        BT:PrecreateVideoPanel(videoUrl)
                    end
                    local videoAlreadyShown = BT._state.rollAnim and BT._state.rollAnim.heritageVideoShown
                    if spin.skip then
                        if not spin.navigating then
                            spin.navigating = true
                            if BT._state.page ~= "heritage" then return end
                            if videoUrl ~= "" and not videoAlreadyShown then
                                BT._state.rollAnim.heritagePendingFlip = false
                                BT:SetPage("heritage_video")
                            else
                                BT:SetPage("heritage_result")
                            end
                        end
                    else
                        if videoUrl ~= "" and not videoAlreadyShown and not spin.navigating then
                            spin.navigating = true
                            BT._state.rollAnim.heritagePendingFlip = true
                            timer.Simple(0.7, function() if BT._state.page == "heritage" then BT:SetPage("heritage_video") end end)
                        else
                            if not spin.flipStartedAt then spin.flipStartedAt = now end
                        end
                    end
                end
            end
        end

        local FLIP_DURATION = 0.55
        local FLIP_STAGGER = 0.09
        if spin and not spin.active and spin.flipStartedAt and not spin.navigating then
            local centerI = math.floor((spin.scrollFrac or 0) + 0.5)
            local halfVisibleCards = math.ceil(w / R:X(220) / 2) + 1
            local maxDelay = halfVisibleCards * FLIP_STAGGER
            if (now - spin.flipStartedAt) >= maxDelay + FLIP_DURATION + 0.8 then
                spin.navigating = true
                local videoUrl = (spin.result and spin.result.video_url) or ""
                local videoAlreadyShown = BT._state.rollAnim and BT._state.rollAnim.heritageVideoShown
                if BT._state.page == "heritage" then
                    if videoUrl ~= "" and not videoAlreadyShown then
                        BT:SetPage("heritage_video")
                    else
                        BT:SetPage("heritage_result")
                    end
                end
            end
        end

        local scrollFrac = spin and (spin.scrollFrac or 0) or 0
        local baseW = R:X(231)
        local baseH = R:Y(231)
        local gridW = R:X(247)
        local baseY = (h - baseH) * 0.5
        local cx = w * 0.5
        local isDecelerating = spin and spin.active and spin.result ~= nil
        local gold = _RL_COL_GOLD
        local halfVisible = math.ceil(w / gridW / 2) + 2
        local iFrac = scrollFrac
        local iMin = math.floor(iFrac) - halfVisible
        local iMax = math.ceil(iFrac) + halfVisible
        local flipCenterI = spin and spin.flipStartedAt and math.floor((spin.scrollFrac or 0) + 0.5) or nil
        for i = iMin, iMax do
            local poolIdx = i % poolSize
            if poolIdx < 0 then poolIdx = poolIdx + poolSize end
            local entry = pool[poolIdx + 1]
            if entry then
                local dist = math.abs(i - iFrac)
                local dW = baseW
                local dH = baseH
                local dx = math.floor((i - iFrac) * gridW + cx - baseW * 0.5)
                local dy = math.floor(baseY)
                if dx + dW >= -2 and dx <= w + 2 then
                    local alpha = 255
                    local isCenter = dist < 0.5
                    local bgA = isCenter and 245 or 220
                    local flipPhase = 1
                    local showRealSide = not (spin and spin.active)
                    local entryIsRien = string.lower(tostring(entry.name or "")) == "rien"
                    if spin and spin.result and not spin.flipStartedAt and not entryIsRien then showRealSide = false end
                    if flipCenterI and not entryIsRien then
                        local cardDist = math.abs(i - flipCenterI)
                        local cardDelay = cardDist * FLIP_STAGGER
                        local ft = math.Clamp((now - spin.flipStartedAt - cardDelay) / FLIP_DURATION, 0, 1)
                        if ft < 0.5 then
                            flipPhase = 1 - ft * 2
                            showRealSide = false
                        else
                            flipPhase = (ft - 0.5) * 2
                            showRealSide = true
                        end
                    elseif spin and spin.active then
                        showRealSide = false
                    elseif entryIsRien then
                        showRealSide = true
                    end

                    local scaledW = math.max(2, math.floor(dW * flipPhase))
                    local scaledX = dx + math.floor((dW - scaledW) * 0.5)
                    _RL_COL_ROLL_ITEM_BG.a = math.max(bgA, 20)
                    RNDX.Draw(R:Y(14), scaledX, dy, scaledW, dH, _RL_COL_ROLL_ITEM_BG)
                    if isCenter then
                        RNDX.DrawOutlined(R:Y(14), scaledX, dy, scaledW, dH, color_white, 2)
                    end

                    if flipPhase >= 0.05 then
                        local pad = R:Y(14)
                        local textZoneH = R:Y(46)
                        -- Zone image carrée : prend le plus petit côté disponible
                        local availW = dW - pad * 2
                        local availH = dH - textZoneH - pad
                        local iconSq = math.min(availW, availH)
                        local iconY = dy + pad + math.floor((availH - iconSq) * 0.5)
                        -- Animation flip : la largeur s'écrase de 0 → iconSq selon flipPhase
                        local iconW = math.floor(iconSq * flipPhase)
                        local iconX = scaledX + math.floor((dW - iconW) * 0.5)
                        local iconSz = iconSq
                        if iconW >= 2 then
                            if not showRealSide and not entryIsRien then
                                local pulse = (math.sin(now * 2.2) + 1) * 0.5
                                local mc_r = math.min(255, 255 + math.floor(pulse * 50))
                                local mc_g = math.min(255, 255 + math.floor(pulse * 30))
                                _RL_COL_ROLL_EDGE_OUT.a = 50
                                RNDX.Draw(R:Y(10), iconX, iconY, iconW, iconSz, _RL_COL_ROLL_EDGE_OUT)
                                -- Use a temp color for the outline (mc has dynamic r/g)
                                local _hFlipOut = Color(mc_r, mc_g, 255, alpha)
                                RNDX.DrawOutlined(R:Y(10), iconX, iconY, iconW, iconSz, _hFlipOut, 2)
                                if flipPhase > 0.4 then
                                    local _hFlipTxt = Color(mc_r, mc_g, 255, alpha)
                                    draw.SimpleText("?", Font:GetNamed("Poppins", "Bold", 54), scaledX + scaledW * 0.5, iconY + iconSz * 0.5, _hFlipTxt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                                    _RL_COL_ROLL_NAME_SIDE.a = alpha
                                    draw.SimpleText("???", Font:GetNamed("Poppins", "Bold", 24), scaledX + scaledW * 0.5, dy + dH - textZoneH * 0.5, _RL_COL_ROLL_NAME_SIDE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                                end
                            else
                                local iconPath = (entry.icon and entry.icon ~= "") and entry.icon or (entry.asset and entry.asset ~= "" and entry.asset or nil)
                                if iconPath then
                                    _RL_COL_ROLL_ICON.a = math.max(alpha, 0)
                                    Materials:Draw(_RL_COL_ROLL_ICON, iconPath, iconX, iconY, iconW, iconSz, "noclamp smooth")
                                else
                                    _ui.drawOccultFallback(entry, iconX, iconY, iconW, iconSz)
                                end

                                if alpha > 20 and flipPhase > 0.4 then
                                    local nameFont = isCenter and Font:GetNamed("Poppins", "SemiBold", 14) or Font:GetNamed("Poppins", "SemiBold", 11)
                                    local nameCol
                                    if isCenter then
                                        _RL_COL_ROLL_NAME_CTR.a = alpha
                                        nameCol = _RL_COL_ROLL_NAME_CTR
                                    else
                                        _RL_COL_ROLL_NAME_SIDE.a = alpha
                                        nameCol = _RL_COL_ROLL_NAME_SIDE
                                    end
                                    draw.SimpleText(string.upper(tostring(entry.name or "?")), nameFont, scaledX + scaledW * 0.5, dy + dH - textZoneH * 0.5, nameCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                                end
                            end
                        end
                    end
                end
            end
        end

        RNDX.Draw(0, math.floor(cx - 1), 0, 2, h, _RL_COL_ROLL_CENTERLINE)
        local arAlpha = isDecelerating and math.floor(120 + 135 * math.abs(math.sin(now * 4))) or 210
        surface.SetDrawColor(gold.r, gold.g, gold.b, arAlpha)
        draw.NoTexture()
        surface.DrawPoly({
            {
                x = cx - R:X(13),
                y = R:Y(4)
            },
            {
                x = cx + R:X(13),
                y = R:Y(4)
            },
            {
                x = cx,
                y = R:Y(22)
            }
        })

        surface.DrawPoly({
            {
                x = cx - R:X(13),
                y = h - R:Y(4)
            },
            {
                x = cx + R:X(13),
                y = h - R:Y(4)
            },
            {
                x = cx,
                y = h - R:Y(22)
            }
        })
    end

    if showBanner then
        buildPurpleButton(parent, 810, tab.launch_label or "Lancer", function()
            if not isHeritageSpinning() then beginHeritageRoll() end
        end, R:X(242), R:Y(56))
    else
        buildRerollBanner(parent, "heritage_reroll_banner", R:X(745), R:Y(419), 220)

        buildPurpleButton(parent, 817, tab.launch_label or "Lancer", function()
            if not isHeritageSpinning() then beginHeritageRoll() end
        end, R:X(242), R:Y(56))
        buildSkipButton(parent, 891, R:X(242), R:Y(39), isHeritageSpinning, skipHeritageRoll)

        local _heritageInfoFont = Font:GetNamed("Poppins", "Regular", 24)
        local infoPnl = vgui.Create("DPanel", parent)
        infoPnl:SetPos(0, R:Y(830))
        infoPnl:SetSize(R:X(1920), R:Y(30))
        infoPnl:SetMouseInputEnabled(false)
        infoPnl.Paint = function(_, w, h)
            local count = _ui.getItemCount(tab.item_id or "")
            draw.SimpleText("Reroll restant : " .. tostring(count), _heritageInfoFont, R:X(285), h * 0.5, _RL_COL_INFO_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Héritage actuel : " .. getCurrentBranchTitle("heritage_branch"), _heritageInfoFont, R:X(1635), h * 0.5, _RL_COL_INFO_TXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local buyBtn = vgui.Create("DButton", parent)
        buyBtn:SetPos(R:XY(783, 1080 - 40 - 30))
        buyBtn:SetSize(R:XY(353, 40))
        buyBtn:SetText("")
        local _buyBtnFont = Font:GetNamed("Poppins", "Bold", 36)
        buyBtn.Paint = function(s, w, h)
            draw.SimpleText("Acheter des rerolls", _buyBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        buyBtn.DoClick = function() BT:SetPage("rerolls") end
    end

    _ui.createBackButton(parent)
end

local function buildHeritageVideoPage(parent)
    local videoUrl = (BT._state.lastRoll and BT._state.lastRoll.video_url) or ""
    if videoUrl == "" then
        BT:SetPage("heritage_result")
        return
    end

    local TIMER_NAME = "VERSE::Heritage::VideoTimeout"
    local function gotoResult()
        timer.Remove(TIMER_NAME)
        if BT._state.page ~= "heritage_video" then return end
        if BT._state.rollAnim then BT._state.rollAnim.heritageVideoShown = true end
        local pending = BT._state.rollAnim and BT._state.rollAnim.heritagePendingFlip
        if pending then
            BT:SetPage("heritage")
        else
            BT:SetPage("heritage_result")
        end
    end

    timer.Create(TIMER_NAME, 300, 1, gotoResult)
    local bg = vgui.Create("DPanel", parent)
    bg:SetPos(0, 0)
    bg:SetSize(R:X(1920), R:Y(1080))
    bg.Paint = function(_, w, h) RNDX.Draw(0, 0, 0, w, h, _RL_COL_VIDEO_BG) end
    bg.OnRemove = function() timer.Remove(TIMER_NAME) end
    local loadLabel = vgui.Create("DPanel", bg)
    loadLabel:SetPos(R:X(760), R:Y(510))
    loadLabel:SetSize(R:X(400), R:Y(60))
    local _loadLabelFont = Font:GetNamed("Poppins", "Medium", 20)
    loadLabel.Paint = function(_, w, h) draw.SimpleText("Chargement de la vidéo...", _loadLabelFont, w * 0.5, h * 0.5, _RL_COL_VIDEO_LOAD_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
    local function onVideoStarted(dur)
        if IsValid(loadLabel) then loadLabel:SetVisible(false) end
        timer.Remove(TIMER_NAME)
        local d = tonumber(dur)
        if d and d > 0 and d < 86400 then timer.Create(TIMER_NAME, d + 1.5, 1, gotoResult) end
        if not timer.Exists(TIMER_NAME) then timer.Create(TIMER_NAME, 1800, 1, gotoResult) end
    end

    local preHtml, preFrame = BT:ConsumePrecreatedVideoPanel(videoUrl)
    local html
    if IsValid(preHtml) then
        html = preHtml
        html:SetParent(bg)
        html:SetMouseInputEnabled(true)
        html:SetKeyboardInputEnabled(false)
        html:SetPos(0, 0)
        html:SetSize(R:X(1920), R:Y(1080))
        if IsValid(preFrame) then preFrame:Remove() end
        html:AddFunction("verseVideo", "started", function(dur) onVideoStarted(dur) end)
        html:AddFunction("verseVideo", "done",    function() gotoResult() end)
        html:AddFunction("verseVideo", "err",     function() gotoResult() end)
        -- Démuet + déclenche "started" si la vidéo a déjà commencé pendant le préchauffage
        html:RunJavascript("try{v.muted=false;v.volume=1;}catch(e){} if(window.__preVideoStarted){try{window.verseVideo.started(window.__preVideoDuration);}catch(e){}}")
        timer.Simple(0.3, function() if IsValid(html) then html:RunJavascript("if(v){v.muted=false;v.volume=1;}") end end)
    else
        html = vgui.Create("DHTML", bg)
        html:SetPos(0, 0)
        html:SetSize(R:X(1920), R:Y(1080))
        html:AddFunction("verseVideo", "started", function(dur) onVideoStarted(dur) end)
        html:AddFunction("verseVideo", "done",    function() gotoResult() end)
        html:AddFunction("verseVideo", "err",     function() gotoResult() end)
        html:SetHTML(BT.BuildVideoHtml(videoUrl))
        timer.Simple(0.5, function() if IsValid(html) then html:RunJavascript("if(v){v.muted=false;v.volume=1;}") end end)
    end
    local skipBtn = vgui.Create("DButton", parent)
    skipBtn:SetPos(R:X(1724), R:Y(1011))
    skipBtn:SetSize(R:X(148), R:Y(41))
    skipBtn:SetText("")
    local _skipBtnFont = Font:GetNamed("Poppins", "Medium", 16)
    skipBtn.Paint = function(s, w, h)
        _RL_COL_SKIP_BG.a = s:IsHovered() and 220 or 180
        RNDX.Draw(R:Y(12), 0, 0, w, h, _RL_COL_SKIP_BG)
        RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, _RL_COL_SKIP_OUT, 2)
        draw.SimpleText("Passer", _skipBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    skipBtn.DoClick = function() gotoResult() end
    local volume = 1.0
    local dragging = false
    local VOL_LABEL_W = R:X(36)
    local VOL_PCT_W = R:X(36)
    local VOL_PAD = R:X(6)
    local function setVolume(val)
        volume = math.Clamp(val, 0, 1)
        if IsValid(html) then html:RunJavascript("if(v){v.volume=" .. string.format("%.3f", volume) .. ";v.muted=" .. (volume < 0.01 and "true" or "false") .. ";}") end
    end

    local volPnl = vgui.Create("DPanel", parent)
    volPnl:SetPos(R:X(1496), R:Y(1011))
    volPnl:SetSize(R:X(214), R:Y(41))
    local _volLblFont = Font:GetNamed("Poppins", "Medium",  14)
    local _volPctFont = Font:GetNamed("Poppins", "Regular", 12)
    volPnl.Paint = function(s, w, h)
        _RL_COL_VOL_BG.a = s:IsHovered() and 220 or 180
        RNDX.Draw(R:Y(12), 0, 0, w, h, _RL_COL_VOL_BG)
        RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, _RL_COL_VOL_OUT, 2)
        draw.SimpleText("Vol", _volLblFont, VOL_LABEL_W * 0.5, h * 0.5, _RL_COL_VOL_LBL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local tx = VOL_LABEL_W + VOL_PAD
        local tw = w - tx - VOL_PCT_W - VOL_PAD
        local ty = h * 0.5
        local th = R:Y(3)
        RNDX.Draw(th, tx, ty - th * 0.5, tw, th, _RL_COL_VOL_TRACK)
        if volume > 0 then RNDX.Draw(th, tx, ty - th * 0.5, tw * volume, th, color_white) end
        local kr = R:Y(7)
        local kx = tx + tw * volume
        RNDX.Draw(kr, kx - kr, ty - kr, kr * 2, kr * 2, color_white)
        draw.SimpleText(math.floor(volume * 100) .. "%", _volPctFont, w - VOL_PCT_W * 0.5, h * 0.5, _RL_COL_VOL_PCT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local function updateFromCursor(s)
        local mx = s:CursorPos()
        local tx = VOL_LABEL_W + VOL_PAD
        local tw = s:GetWide() - tx - VOL_PCT_W - VOL_PAD
        setVolume((mx - tx) / tw)
    end

    volPnl.OnMousePressed = function(s, key)
        if key ~= MOUSE_LEFT then return end
        dragging = true
        updateFromCursor(s)
    end

    volPnl.OnMouseReleased = function(s, key)
        if key ~= MOUSE_LEFT then return end
        dragging = false
    end

    volPnl.OnCursorMoved = function(s, x, y) if dragging then updateFromCursor(s) end end
end

local function buildHeritageResultPage(parent)
    buildRollTabs(parent, "heritage_result")
    local last = BT._state.lastRoll or {}
    -- 920 = même position que le bouton "Skip/Lancer" de la page de tirage héritage,
    -- pour que "Relancer" ne saute pas à un autre endroit après le tirage.
    buildResultLayout(parent, last, function()
        BT:SetPage("heritage")
        beginHeritageRoll()
    end, 920)

    _ui.createBackButton(parent)
    local lastName = tostring(last.name or "")
    local isRien   = string.lower(lastName) == "rien"

    -- Le serveur indique qu'il existe déjà un héritage ET que le résultat n'est pas "rien".
    -- Dans ce cas l'application est différée côté serveur : on montre un popup de choix.
    if lastName ~= "" and not isRien and last.has_existing_heritage == true and not BT._state.heritageResolved then
        BT._state.heritageResolved = true
        timer.Simple(1.0, function()
            if not IsValid(parent) then return end
            if BT._state.page ~= "heritage_result" then return end
            local oldName = tostring(last.existing_branch_name or "???")
            openBoutiqueConfirm(
                "Que voulez-vous faire ?",
                "Vous avez déjà un héritage. Faites votre choix.",
                function()
                    -- Bouton gauche : garder l'ancien
                    netstream.Start(BT.Net.ResolveHeritageRoll, false)
                    LocalPlayer():Notify("Vous avez conservé votre ancien héritage.", NOTIFY_HINT, 4)
                    BT:SetPage("heritage")
                end,
                function()
                    -- Bouton droit : prendre le nouveau
                    netstream.Start(BT.Net.ResolveHeritageRoll, true)
                    BT:SetPage("heritage")
                end,
                "Garder " .. oldName,
                "Obtenir " .. lastName
            )
        end)
    else
        -- Résultat "rien", pas d'héritage existant, ou déjà résolu :
        -- le serveur a appliqué immédiatement (ou rien à faire), pas besoin de choix.
        BT._state.heritageResolved = true
    end
end

_ui.beginOccultRoll = beginOccultRoll
_ui.beginHeritageRoll = beginHeritageRoll
_ui.buildOccultRollPage = buildOccultRollPage
_ui.buildOccultResultPage = buildOccultResultPage
_ui.buildHeritagePage = buildHeritagePage
_ui.buildHeritageVideoPage = buildHeritageVideoPage
_ui.buildHeritageResultPage = buildHeritageResultPage
