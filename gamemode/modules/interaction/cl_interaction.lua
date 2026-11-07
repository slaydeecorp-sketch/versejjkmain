local IT  = VERSE.Interaction
local CFG = IT.Config

-- ─── État client ──────────────────────────────────────────────────────────────

local _holdTarget   = nil     -- joueur actuellement visé
local _holdStart    = 0

local _menuOpen     = false
local _menuTarget   = nil
local _menuAnim     = 0       -- 0 → 1
local _menuOpenTime = 0
local _menuHovered  = nil     -- id du bouton survolé
local _ownedClicker = false

local _isCarrying   = false   -- on porte quelqu'un
local _isCarried    = false   -- on est porté
local _pendingMoneyTarget = nil

-- ─── Polices ─────────────────────────────────────────────────────────────────

local _fontsReady = false
local function ensureFonts()
    if _fontsReady then return end
    _fontsReady = true
    surface.CreateFont("VERSE_IT_Label", {
        font = "Poppins", size = 17, weight = 700, antialias = true,
    })
    surface.CreateFont("VERSE_IT_Notify", {
        font = "Poppins", size = 19, weight = 600, antialias = true,
    })
    surface.CreateFont("VERSE_IT_Popup", {
        font = "Poppins", size = 20, weight = 700, antialias = true,
    })
    surface.CreateFont("VERSE_IT_PopupSub", {
        font = "Poppins", size = 16, weight = 400, antialias = true,
    })
    surface.CreateFont("VERSE_IT_FouillerTitle", {
        font = "Poppins", size = 18, weight = 700, antialias = true,
    })
    surface.CreateFont("VERSE_IT_ItemBadge", {
        font = "Poppins", size = 12, weight = 600, antialias = true,
    })
end

-- ─── Définition des boutons du menu ──────────────────────────────────────────
--   dx/dy : direction en coordonnées écran (y positif = bas)

local ICONS = {
    { id = "porter",    label = "Porter",             file = "verse/interaction/porter.png",    dx =  0, dy = -1 },
    { id = "fouiller",  label = "Fouiller",           file = "verse/interaction/fouiller.png",  dx =  1, dy =  0 },
    { id = "presenter", label = "Se présenter",       file = "verse/interaction/presenter.png", dx =  0, dy =  1 },
    { id = "argent",    label = "Donner de l'argent", file = "verse/interaction/argent.png",    dx = -1, dy =  0 },
}

-- Pré-cache des materials au chargement (UNE seule fois).
-- Appeler Material() à chaque frame force le rechargement au mipmap bas → icônes floues.
for _, btn in ipairs(ICONS) do
    btn.mat = Material(btn.file, "noclamp smooth")
end

local ICON_R     = 32   -- rayon d'affichage du PNG (px)
local ICON_HIT_R = 26   -- rayon de détection du clic (plus petit : exclut le padding transparent du PNG)
local ICON_DIST  = 140  -- distance centre → bouton (fully open, px)

-- ─── Notifications ────────────────────────────────────────────────────────────

local _notifs = {}
local NOTIF_COLORS = {
    info    = Color(80, 160, 255),
    success = Color(60, 210, 100),
    error   = Color(220, 70,  70),
}

-- ─── Couleurs pré-allouées pour les Paint callbacks (évite Color() par frame) ─
local _IT_COL_POPUP_BG      = Color(14,  14,  14,  235)
local _IT_COL_POPUP_ACCENT  = Color(110, 110, 220, 220)
local _IT_COL_WHITE         = Color(255, 255, 255, 255)
local _IT_COL_GREY          = Color(170, 170, 170, 255)
local _IT_COL_MONEY_BG      = Color(12,  12,  16,  245)
local _IT_COL_MONEY_ACCENT  = Color(210, 175, 40,  255)
local _IT_COL_MONEY_GREY    = Color(150, 150, 150, 255)
local _IT_COL_ENTRY_BG      = Color(28,  28,  34,  255)
local _IT_COL_ENTRY_FOCUS   = Color(210, 175, 40,  200)
local _IT_COL_ENTRY_NOFOCUS = Color(60,  60,  60,  200)
local _IT_COL_ENTRY_GREY    = Color(80,  80,  80,  255)
local _IT_COL_HOLE          = Color(0,   0,   0,   180)
local _IT_COL_ARC_FILL      = Color(255, 255, 255, 200)
local _IT_COL_NOTIF_BG      = Color(38,  18,  58,  0)   -- alpha muté
local _IT_COL_NOTIF_BAR     = Color(0,   0,   0,   0)   -- r/g/b/a mutés
local _IT_COL_NOTIF_TXT     = Color(255, 255, 255, 0)   -- alpha muté
local _IT_COL_CARRY_TXT     = Color(255, 255, 255, 200)
local _IT_COL_LABEL_HOVER   = Color(255, 255, 255, 0)   -- alpha muté
local _IT_COL_LABEL_NOHOVER = Color(210, 210, 210, 0)   -- alpha muté
local _IT_COL_HOVER_GLOW    = Color(255, 255, 255, 22)

local function addNotif(msg, kind)
    _notifs[#_notifs + 1] = {
        msg = tostring(msg), kind = kind or "info",
        start = RealTime(), duration = 4.5,
    }
    -- Limiter à 6 notifs
    if #_notifs > 6 then table.remove(_notifs, 1) end
end

netstream.Hook(IT.Net.Notify, function(msg, kind)
    addNotif(msg, kind)
end)

-- ─── Helpers menu ────────────────────────────────────────────────────────────

local function openMenu(target)
    _menuOpen      = true
    _menuTarget    = target
    _menuAnim      = 0
    _menuOpenTime  = RealTime()
    _menuHovered   = nil
    if not _ownedClicker then
        gui.EnableScreenClicker(true)
        _ownedClicker = true
    end
end

local function closeMenu()
    _menuOpen    = false
    _menuTarget  = nil
    _menuHovered = nil
    if _ownedClicker then
        gui.EnableScreenClicker(false)
        _ownedClicker = false
    end
end

local function getTargetPlayer()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    local tr = util.TraceLine({
        start  = ply:EyePos(),
        endpos = ply:EyePos() + ply:EyeAngles():Forward() * CFG.MaxRange,
        filter = ply,
        mask   = MASK_SHOT_HULL,
    })
    if IsValid(tr.Entity) and tr.Entity:IsPlayer() then
        return tr.Entity
    end
    return nil
end

-- ─── Think : détection maintien E ────────────────────────────────────────────

hook.Add("Think", "VERSE::Interaction::HoldDetect", function()
    if _menuOpen then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- ── Mode portage : maintenir E pour poser / demander à descendre ─────────
    if _isCarrying or _isCarried then
        if input.IsKeyDown(KEY_E) then
            _dropHoldStart = _dropHoldStart or RealTime()
            if RealTime() - _dropHoldStart >= CFG.DropHoldTime then
                _dropHoldStart = nil
                netstream.Start(IT.Net.Request, "drop", 0) -- 0 = target ignoré pour "drop"
            end
        else
            _dropHoldStart = nil
        end
        return
    end

    -- ── Mode normal : maintenir E sur un joueur pour ouvrir le menu ──────────
    if input.IsKeyDown(KEY_E) then
        local target = getTargetPlayer()
        if not IsValid(target) then
            _holdTarget = nil
            _holdStart  = 0
            return
        end
        if target ~= _holdTarget then
            _holdTarget = target
            _holdStart  = RealTime()
        end
        if RealTime() - _holdStart >= CFG.HoldTime then
            openMenu(_holdTarget)
            _holdTarget = nil
            _holdStart  = 0
        end
    else
        _holdTarget = nil
        _holdStart  = 0
    end
end)

-- Fermer le menu via ESC
hook.Add("PlayerBindDown", "VERSE::Interaction::ESC", function(_, bind)
    if _menuOpen and bind == "cancelselect" then closeMenu() end
end)

hook.Add("PlayerDeath", "VERSE::Interaction::DeathClose", function()
    closeMenu()
    if IsValid(_activePopup) then _activePopup:Remove() end
end)

-- ─── Popup accepter / refuser ─────────────────────────────────────────────────

local _activePopup = nil

local function showPopup(title, desc, onAccept, onRefuse, timeout)
    if IsValid(_activePopup) then _activePopup:Remove() end
    ensureFonts()

    local w, h = 440, 178
    local frame = vgui.Create("DPanel")
    frame:SetSize(w, h)
    frame:SetPos(ScrW() / 2 - w / 2, ScrH() * 0.68)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)

    frame.Paint = function(self, fw, fh)
        draw.RoundedBox(14, 0, 0, fw, fh, _IT_COL_POPUP_BG)
        draw.RoundedBox(3,  0, 0, fw, 3,  _IT_COL_POPUP_ACCENT)
        draw.SimpleText(title, "VERSE_IT_Popup",    fw / 2, 22, _IT_COL_WHITE, TEXT_ALIGN_CENTER)
        draw.SimpleText(desc,  "VERSE_IT_PopupSub", fw / 2, 54, _IT_COL_GREY, TEXT_ALIGN_CENTER)
    end

    local function mkBtn(text, x, col, hoverCol, cb)
        local btn = vgui.Create("DButton", frame)
        btn:SetText(text)
        btn:SetPos(x, 100)
        btn:SetSize(190, 48)
        btn:SetFont("VERSE_IT_Popup")
        btn:SetTextColor(Color(255, 255, 255))
        btn.Paint = function(self, bw, bh)
            draw.RoundedBox(10, 0, 0, bw, bh, self:IsHovered() and hoverCol or col)
        end
        btn.DoClick = function()
            if IsValid(frame) then frame:Remove() end
            if cb then cb() end
        end
        return btn
    end

    mkBtn("✓  Accepter", 24,  Color(35, 140, 60),  Color(50, 180, 80),  onAccept)
    mkBtn("✗  Refuser",  234, Color(155, 38, 38),  Color(200, 55, 55),  onRefuse)

    -- Barre de progression du timeout
    if timeout then
        local created = RealTime()
        local bar = vgui.Create("DPanel", frame)
        bar:SetPos(0, h - 5)
        bar:SetSize(w, 5)
        bar.Paint = function(self, bw, bh)
            local pct = 1 - math.Clamp((RealTime() - created) / timeout, 0, 1)
            draw.RoundedBox(3, 0, 0, math.floor(bw * pct), bh, _IT_COL_POPUP_ACCENT)
        end
        timer.Simple(timeout, function()
            if IsValid(frame) then
                frame:Remove()
                if onRefuse then onRefuse() end
            end
        end)
    end

    _activePopup = frame
end

-- Recevoir popup du serveur
netstream.Hook(IT.Net.Popup, function(id, action, requesterName)
    local title, desc
    if action == "fouiller" then
        title = "Demande de fouille"
        desc  = requesterName .. " souhaite vous fouiller."
    elseif action == "porter" then
        title = "Demande de portage"
        desc  = requesterName .. " souhaite vous porter."
    else
        return
    end

    showPopup(title, desc,
        function() netstream.Start(IT.Net.Response, id, true)  end,
        function() netstream.Start(IT.Net.Response, id, false) end,
        CFG.PopupTimeout
    )
end)

-- ─── Popup argent ─────────────────────────────────────────────────────────────

local function showMoneyPopup(target)
    if not IsValid(target) then return end
    ensureFonts()

    local w, h = 380, 170
    -- DFrame pour garantir le focus clavier sur le DTextEntry
    local frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:SetPos(ScrW() / 2 - w / 2, ScrH() * 0.36)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetKeyboardInputEnabled(true)
    frame:MakePopup()

    frame.Paint = function(self, fw, fh)
        draw.RoundedBox(14, 0, 0, fw, fh, _IT_COL_MONEY_BG)
        draw.RoundedBox(14, 0, 0, fw, 3,  _IT_COL_MONEY_ACCENT)
        draw.SimpleText("Donner de l'argent", "VERSE_IT_Popup", fw / 2, 22,
            _IT_COL_WHITE, TEXT_ALIGN_CENTER)
        draw.SimpleText("à " .. (IsValid(target) and target:Nick() or "?"),
            "VERSE_IT_PopupSub", fw / 2, 50, _IT_COL_MONEY_GREY, TEXT_ALIGN_CENTER)
    end

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(20, 68)
    entry:SetSize(w - 40, 40)
    entry:SetFont("VERSE_IT_Popup")
    entry:SetPlaceholderText("Montant en ¥")
    entry:SetNumeric(true)
    entry:SetTextColor(Color(255, 255, 255))
    entry:SetCursorColor(Color(210, 175, 40))
    entry:SetHighlightColor(Color(210, 175, 40, 80))
    entry.Paint = function(self, ew, eh)
        draw.RoundedBox(8, 0, 0, ew, eh, _IT_COL_ENTRY_BG)
        draw.RoundedBox(8, 0, eh - 2, ew, 2, self:HasFocus() and _IT_COL_ENTRY_FOCUS or _IT_COL_ENTRY_NOFOCUS)
        self:DrawTextEntryText(_IT_COL_WHITE, _IT_COL_MONEY_ACCENT, _IT_COL_WHITE)
        if self:GetValue() == "" and not self:HasFocus() then
            draw.SimpleText("Montant en ¥", "VERSE_IT_PopupSub", 10, eh/2,
                _IT_COL_ENTRY_GREY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Focus après un tick pour éviter les conflits avec closeMenu()
    timer.Simple(0.05, function()
        if IsValid(entry) then entry:RequestFocus() end
    end)

    local function doGive()
        local amount = math.floor(tonumber(entry:GetValue()) or 0)
        if amount <= 0 then return end
        if IsValid(frame) then frame:Remove() end
        netstream.Start(IT.Net.MoneyGive, IsValid(target) and target:EntIndex() or 0, amount)
    end

    entry.OnEnter = function() doGive() end

    local function mkBtn(text, x, bgCol, hoverCol, cb)
        local btn = vgui.Create("DButton", frame)
        btn:SetText(text)
        btn:SetPos(x, 122)
        btn:SetSize(165, 38)
        btn:SetFont("VERSE_IT_Popup")
        btn:SetTextColor(Color(255, 255, 255))
        btn.Paint = function(self, bw, bh)
            draw.RoundedBox(10, 0, 0, bw, bh, self:IsHovered() and hoverCol or bgCol)
        end
        btn.DoClick = cb
        return btn
    end

    mkBtn("¥  Donner",  20,  Color(145, 115, 15), Color(200, 165, 30), doGive)
    mkBtn("✗  Annuler", 195, Color(42, 42, 50),   Color(70, 70, 80),
        function() if IsValid(frame) then frame:Remove() end end)
end

-- ─── Animation du joueur porté ────────────────────────────────────────────────
-- Le système principal : le serveur appelle carried:PlayAnimation() qui envoie un
-- netstream à tous les clients → Anims.SequenceState est rempli → CalcMainActivity
-- (priorité 100 du système VERSE) retourne ACT_IDLE + seqId automatiquement.
--
-- Ce hook CalcMainActivity est un FALLBACK pour les rares cas où l'animation VERSE
-- est stoppée par un autre système mais VERSE_IsCarried est encore true.

local CARRY_ANIM = "as_cp_090_00_tagcombodamage_cp_190_08_01"
local _carrySeqCache = {}

local function getCarrySeq(ply)
    local mdl = ply:GetModel()
    if _carrySeqCache[mdl] == nil then
        local s = ply:LookupSequence(CARRY_ANIM)
        _carrySeqCache[mdl] = (s and s >= 0) and s or false
    end
    return _carrySeqCache[mdl]
end

-- Priorité 90 : s'exécute juste après le système VERSE (priorité 100),
-- mais avant le hook sprint (priorité 0 par défaut).
hook.Add("CalcMainActivity", "VERSE::Interaction::CarriedAnim", function(ply)
    if not ply:GetNWBool("VERSE_IsCarried", false) then return end
    -- Si le système VERSE a déjà un SequenceState pour ce joueur, il gère tout
    local state = VERSE.Anims and VERSE.Anims.SequenceState and VERSE.Anims.SequenceState[ply]
    if state then return end  -- laisser le système VERSE s'en occuper
    -- Fallback : forcer la séquence manuellement
    local seq = getCarrySeq(ply)
    if seq then
        return ACT_INVALID, seq
    end
end, 90)

-- ─── Sync portage ────────────────────────────────────────────────────────────

netstream.Hook(IT.Net.CarrySync, function(active, otherPly, isCarrier)
    _isCarrying = false
    _isCarried  = false
    if active then
        if isCarrier then
            _isCarrying = true
        else
            _isCarried = true
        end
    end
end)

-- ─── Panel inventaire (fouille) ───────────────────────────────────────────────

netstream.Hook(IT.Net.FouillerInventory, function(charName, rawInv)
    local INV = VERSE.Inventory
    if not INV then return end

    local inv   = INV:NormalizeInventory(rawInv or {})
    local slots = {}
    for _, data in pairs(inv) do
        if data and data.item_id then slots[#slots + 1] = data end
    end
    table.sort(slots, function(a, b) return (a.slot_index or 0) < (b.slot_index or 0) end)

    ensureFonts()

    -- ── Constantes layout ────────────────────────────────────────────────────
    local SLOT_S    = 72      -- taille d'un slot (carré)
    local SLOT_GAP  = 8       -- espace entre slots
    local COLS      = 6
    local ROWS_MAX  = 4       -- max lignes visibles avant scroll
    local PAD       = 14      -- marge gauche/droite/bas
    local HEADER_H  = 52
    local FOOTER_H  = 34
    local SCROLL_W  = 8       -- largeur scrollbar

    local rows      = math.max(1, math.ceil(math.max(#slots, 1) / COLS))
    local visRows   = math.min(rows, ROWS_MAX)

    local gridW  = COLS * SLOT_S + (COLS - 1) * SLOT_GAP
    local w      = gridW + PAD * 2 + SCROLL_W
    local gridH  = rows * SLOT_S + (rows - 1) * SLOT_GAP
    local visGridH = visRows * SLOT_S + (visRows - 1) * SLOT_GAP
    local h      = HEADER_H + PAD + visGridH + PAD + FOOTER_H

    -- ── Fenêtre principale ───────────────────────────────────────────────────
    local frame = vgui.Create("DPanel")
    frame:SetSize(w, h)
    frame:Center()
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)

    -- Drag depuis le header
    local _drag, _dragOX, _dragOY = false, 0, 0
    frame.OnMousePressed = function(self, mbtn)
        if mbtn ~= MOUSE_LEFT then return end
        local lx, ly = self:CursorPos()
        if ly <= HEADER_H then
            _drag   = true
            _dragOX = lx
            _dragOY = ly
        end
    end
    frame.OnMouseReleased = function() _drag = false end
    frame.Think = function(self)
        if _drag then
            local mx, my = gui.MousePos()
            self:SetPos(mx - _dragOX, my - _dragOY)
        end
    end

    -- Hover info : mis à jour par les slots
    local _hovName = nil
    local _hovQty  = 1

    -- Paint du cadre principal
    frame.Paint = function(self, fw, fh)
        -- Fond principal
        draw.RoundedBox(12, 0, 0, fw, fh, Color(14, 14, 18, 252))
        -- Bordure subtile
        surface.SetDrawColor(50, 50, 68, 200)
        surface.DrawOutlinedRect(0, 0, fw, fh, 1)

        -- Header
        draw.RoundedBoxEx(12, 0, 0, fw, HEADER_H, Color(20, 20, 28, 255), true, true, false, false)
        -- Accent line header (bas)
        draw.RoundedBox(2, 12, HEADER_H - 3, fw - 24, 2, Color(90, 90, 210, 200))

        -- Titre header
        surface.SetFont("VERSE_IT_FouillerTitle")
        surface.SetTextColor(255, 255, 255, 230)
        surface.SetTextPos(18, math.floor(HEADER_H / 2) - 10)
        surface.DrawText("Inventaire")
        local tw = surface.GetTextSize("Inventaire")
        surface.SetTextColor(110, 110, 200, 220)
        surface.SetTextPos(18 + tw + 7, math.floor(HEADER_H / 2) - 10)
        surface.DrawText("— " .. tostring(charName))

        -- Footer
        local footerY = fh - FOOTER_H
        surface.SetDrawColor(38, 38, 52, 200)
        surface.DrawRect(0, footerY, fw, 1)
        draw.RoundedBoxEx(12, 0, footerY, fw, FOOTER_H, Color(18, 18, 24, 240), false, false, true, true)

        if _hovName then
            local qty = _hovQty > 1 and ("  ×" .. _hovQty) or ""
            draw.SimpleText(_hovName .. qty, "VERSE_IT_PopupSub",
                fw / 2, footerY + FOOTER_H / 2,
                Color(200, 200, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("Survolez un objet pour voir son nom", "VERSE_IT_PopupSub",
                fw / 2, footerY + FOOTER_H / 2,
                Color(50, 50, 70, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Bouton fermer
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetText("✕")
    closeBtn:SetFont("VERSE_IT_Label")
    closeBtn:SetPos(w - 38, 11)
    closeBtn:SetSize(26, 30)
    closeBtn:SetTextColor(Color(120, 120, 145))
    closeBtn.Paint = function(self, bw, bh)
        if self:IsHovered() then
            draw.RoundedBox(6, 0, 0, bw, bh, Color(90, 25, 25, 200))
            self:SetTextColor(Color(255, 90, 90))
        else
            self:SetTextColor(Color(100, 100, 125))
        end
    end
    closeBtn.DoClick = function()
        if IsValid(frame) then frame:Remove() end
    end

    -- ── Zone scrollable pour la grille ───────────────────────────────────────
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(PAD, HEADER_H + PAD)
    scroll:SetSize(gridW + SCROLL_W, visGridH)

    -- Style de la scrollbar
    local sbar = scroll:GetVBar()
    sbar:SetWide(SCROLL_W - 2)
    sbar.Paint = function(self, sw, sh)
        draw.RoundedBox(4, 0, 0, sw, sh, Color(20, 20, 28, 200))
    end
    sbar.btnUp.Paint   = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(self, sw, sh)
        draw.RoundedBox(4, 1, 0, sw - 2, sh, Color(70, 70, 110, 220))
    end

    local grid = vgui.Create("DPanel", scroll)
    grid:SetSize(gridW, gridH)
    grid.Paint = function() end

    -- ── Slots ────────────────────────────────────────────────────────────────
    local displayCount = math.max(#slots, 1)

    for i = 1, displayCount do
        local data = slots[i]
        local col  = (i - 1) % COLS
        local row  = math.floor((i - 1) / COLS)
        local sx   = col * (SLOT_S + SLOT_GAP)
        local sy   = row * (SLOT_S + SLOT_GAP)

        local slotP = vgui.Create("DPanel", grid)
        slotP:SetPos(sx, sy)
        slotP:SetSize(SLOT_S, SLOT_S)

        if data then
            local def  = INV:GetItemDef(data.item_id)
            local name = def and (def.name or data.item_id) or tostring(data.item_id)
            local qty  = math.floor(tonumber(data.amount) or 1)
            local icon = def and def.icon or nil
            local mat  = nil

            if icon then
                local m = (VERSE.Materials and VERSE.Materials:Get(icon))
                    or Material("verse/items/" .. icon .. ".png", "noclamp smooth")
                if m and not m:IsError() then mat = m end
            end

            slotP.Paint = function(self, sw, sh)
                local hov = self:IsHovered()

                -- Fond + bordure
                draw.RoundedBox(8, 0, 0, sw, sh,
                    hov and Color(40, 40, 58, 250) or Color(22, 22, 30, 230))
                surface.SetDrawColor(
                    hov and 80 or 38,
                    hov and 80 or 38,
                    hov and 115 or 52,
                    hov and 220 or 160)
                surface.DrawOutlinedRect(0, 0, sw, sh, 1)

                -- Icône
                if mat then
                    local p = 9
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255, hov and 255 or 220)
                    surface.DrawTexturedRect(p, p, sw - p * 2, sw - p * 2)
                end

                -- Badge quantité (coin bas-droit)
                if qty > 1 then
                    local bw, bh = 28, 15
                    draw.RoundedBox(4, sw - bw - 2, sh - bh - 2, bw, bh, Color(0, 0, 0, 210))
                    draw.SimpleText("×" .. qty, "VERSE_IT_ItemBadge",
                        sw - bw / 2 - 2, sh - bh / 2 - 2,
                        Color(215, 215, 215, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            slotP.OnCursorEntered = function()
                _hovName = name
                _hovQty  = qty
            end
            slotP.OnCursorExited = function()
                if _hovName == name then
                    _hovName = nil
                    _hovQty  = 1
                end
            end
        else
            -- Slot vide (padding visuel)
            slotP.Paint = function(self, sw, sh)
                draw.RoundedBox(8, 0, 0, sw, sh, Color(16, 16, 22, 160))
                surface.SetDrawColor(32, 32, 44, 120)
                surface.DrawOutlinedRect(0, 0, sw, sh, 1)
            end
        end
    end

    -- Message inventaire vide
    if #slots == 0 then
        local lbl = vgui.Create("DLabel", grid)
        lbl:SetText("Inventaire vide.")
        lbl:SetFont("VERSE_IT_PopupSub")
        lbl:SetTextColor(Color(80, 80, 100))
        lbl:SizeToContents()
        lbl:SetPos(gridW / 2 - lbl:GetWide() / 2, SLOT_S / 2 - 8)
    end
end)

-- ─── HUDPaint ─────────────────────────────────────────────────────────────────

hook.Add("HUDPaint", "VERSE::Interaction::HUD", function()
    ensureFonts()
    local sw, sh = ScrW(), ScrH()
    local cx, cy = sw * 0.5, sh * 0.5

    -- ── Indicateur de charge (maintien E) ────────────────────────────────────
    if not _menuOpen and IsValid(_holdTarget) and _holdStart > 0 then
        local progress = math.Clamp((RealTime() - _holdStart) / CFG.HoldTime, 0, 1)
        if progress > 0 then
            local outerR = 32
            local innerR = 20
            local segs   = 48
            local count  = math.max(2, math.floor(segs * progress) + 1)

            -- Arc extérieur (remplissage)
            local poly = { { x = cx, y = cy } }
            for i = 0, count do
                local a = math.rad(-90 + 360 * i / segs)
                poly[#poly + 1] = { x = cx + math.cos(a) * outerR, y = cy + math.sin(a) * outerR }
            end
            surface.SetDrawColor(255, 255, 255, 200)
            draw.NoTexture()
            surface.DrawPoly(poly)

            -- Trou central (effet anneau)
            draw.RoundedBox(innerR, cx - innerR, cy - innerR, innerR * 2, innerR * 2, _IT_COL_HOLE)
        end
        return
    end

    -- ── Menu radial ──────────────────────────────────────────────────────────
    if _menuOpen then
        if not IsValid(_menuTarget) then closeMenu() return end

        _menuAnim = math.min(_menuAnim + FrameTime() / 0.22, 1)
        local e   = 1 - (1 - _menuAnim) ^ 3   -- ease-out cubique

        local mx, my = gui.MousePos()
        _menuHovered = nil

        for _, btn in ipairs(ICONS) do
            local bx = cx + btn.dx * ICON_DIST * e
            local by = cy + btn.dy * ICON_DIST * e

            local ddx  = bx - mx
            local ddy  = by - my
            local dist = ddx * ddx + ddy * ddy
            local hovered = dist <= ICON_HIT_R * ICON_HIT_R and e >= 0.55

            if hovered then _menuHovered = btn.id end

            local alpha = math.floor(255 * e)

            -- Lueur blanche subtile au survol
            if hovered then
                local gr = ICON_HIT_R + 8
                draw.RoundedBox(gr, bx - gr, by - gr, gr * 2, gr * 2, _IT_COL_HOVER_GLOW)
            end

            -- Icône PNG sans fond, légèrement plus grande au survol
            if btn.mat and not btn.mat:IsError() then
                local is = hovered and math.floor(ICON_R * 2.18) or ICON_R * 2
                surface.SetMaterial(btn.mat)
                surface.SetDrawColor(255, 255, 255, alpha)
                surface.DrawTexturedRect(bx - is / 2, by - is / 2, is, is)
            end

            -- Label sous l'icône (mutation de .a sur les couleurs pré-allouées)
            if hovered then
                _IT_COL_LABEL_HOVER.a = alpha
                draw.SimpleText(btn.label, "VERSE_IT_Label", bx, by + ICON_R + 9,
                    _IT_COL_LABEL_HOVER, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            else
                _IT_COL_LABEL_NOHOVER.a = math.floor(200 * e)
                draw.SimpleText(btn.label, "VERSE_IT_Label", bx, by + ICON_R + 9,
                    _IT_COL_LABEL_NOHOVER, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        end
    end

    -- ── Notifications (coin supérieur droit) ─────────────────────────────────
    local now    = RealTime()
    local notifX = sw - 24
    local notifY = sh * 0.24
    local i      = 1

    while i <= #_notifs do
        local n       = _notifs[i]
        local elapsed = now - n.start
        local prog    = elapsed / n.duration

        if prog >= 1 then
            table.remove(_notifs, i)
        else
            local alpha = prog > 0.75 and math.floor(255 * (1 - (prog - 0.75) / 0.25)) or 255
            local col   = NOTIF_COLORS[n.kind] or NOTIF_COLORS.info
            local tw    = 330

            -- Fond (mutation de .a uniquement)
            _IT_COL_NOTIF_BG.a = math.floor(220 * alpha / 255)
            draw.RoundedBox(8, notifX - tw, notifY, tw, 38, _IT_COL_NOTIF_BG)
            -- Barre colorée gauche (mutation r/g/b/a)
            _IT_COL_NOTIF_BAR.r, _IT_COL_NOTIF_BAR.g, _IT_COL_NOTIF_BAR.b, _IT_COL_NOTIF_BAR.a = col.r, col.g, col.b, alpha
            draw.RoundedBox(4, notifX - tw, notifY, 4, 38, _IT_COL_NOTIF_BAR)
            -- Texte (mutation de .a)
            _IT_COL_NOTIF_TXT.a = alpha
            draw.SimpleText(n.msg, "VERSE_IT_Notify", notifX - tw + 16, notifY + 19,
                _IT_COL_NOTIF_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            notifY = notifY + 48
            i = i + 1
        end
    end

    -- ── Indicateur porteur (maintien E) ─────────────────────────────────────
    if _isCarrying then
        draw.SimpleText("Maintenez E pour poser le joueur",
            "VERSE_IT_Label", cx, sh * 0.88, _IT_COL_CARRY_TXT,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- ─── Clic sur un bouton du menu ───────────────────────────────────────────────

hook.Add("GUIMousePressed", "VERSE::Interaction::MenuClick", function(mbtn)
    if not _menuOpen then return end
    if mbtn ~= MOUSE_LEFT then return end

    local action = _menuHovered
    local target = _menuTarget
    closeMenu()

    if not action or not IsValid(target) then return end

    if action == "argent" then
        showMoneyPopup(target)
    elseif action == "presenter" then
        -- Utilise le système de connaissances existant (même que touche N)
        local CH = VERSE.Characters
        if CH and isfunction(CH.RequestIntroduce) then
            CH:RequestIntroduce(target)
        end
    else
        -- Envoyer l'EntIndex car netstream ne sérialise pas les entités
        netstream.Start(IT.Net.Request, action, IsValid(target) and target:EntIndex() or 0)
    end
end)

-- Clic hors des boutons → ferme le menu
hook.Add("GUIMousePressed", "VERSE::Interaction::MenuOutsideClick", function(mbtn)
    if not _menuOpen then return end
    if mbtn == MOUSE_RIGHT then closeMenu() end
end)
