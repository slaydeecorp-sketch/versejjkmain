local S    = VERSE.Staff
local R    = VERSE.Responsive
local Font = VERSE.Fonts

-- ─── Couleurs pré-allouées pour Staff HUDPaint (évite Color() par frame) ─────
-- Bannière
local _ST_COL_BANNER_SPEC    = Color(70,  35,  200, 200)
local _ST_COL_BANNER_STAFF   = Color(200, 30,  30,  200)
local _ST_COL_BANNER_BORD_SP = Color(150, 90,  255, 180)
local _ST_COL_BANNER_BORD_ST = Color(255, 100, 100, 180)
local _ST_COL_BANNER_TXT     = Color(255, 255, 255, 240)
local _ST_COL_HINT_TXT       = Color(200, 200, 210, 150)
-- Liste joueurs (droite)
local _ST_COL_LIST_BG        = Color(6,   5,   15,  210)
local _ST_COL_LIST_BORD      = Color(255, 255, 255, 18)
local _ST_COL_LIST_HDR       = Color(180, 185, 210, 180)
local _ST_COL_LIST_ROW_HOV   = Color(255, 255, 255, 28)
local _ST_COL_LIST_ROW_NORM  = Color(255, 255, 255, 7)
local _ST_COL_LIST_FRZ       = Color(90,  190, 255, 220)
local _ST_COL_LIST_NAME      = Color(215, 220, 240, 220)
local _ST_COL_LIST_WARN      = Color(255, 165, 0,   230)
-- Log d'actions
local _ST_COL_LOG_BG         = Color(0,   0,   0,   0)      -- .a muté
local _ST_COL_LOG_TXT        = Color(215, 215, 235, 0)      -- .a muté
-- ESP bulles (distance > 2000)
local _ST_COL_BUBBLE         = Color(124, 77,  255, 220)
local _ST_COL_BUBBLE_BORD    = Color(200, 160, 255, 255)
-- ESP cartes
local _ST_COL_CARD_BG        = Color(8,   6,   18,  220)
local _ST_COL_CARD_BORD_FRZ  = Color(90,  195, 255, 130)
local _ST_COL_CARD_BORD_NORM = Color(255, 255, 255, 28)
local _ST_COL_HP_BAR         = Color(230, 60,  60,  255)    -- r/g/b mutés
local _ST_COL_NAME_TXT       = Color(255, 255, 255, 230)
local _ST_COL_WARN_TXT       = Color(255, 165, 0,   230)
local _ST_COL_JOB_FRZ        = Color(90,  195, 255, 190)
local _ST_COL_JOB_NORM       = Color(175, 185, 210, 190)
local _ST_COL_STAT_TXT       = Color(215, 220, 230, 210)
local _ST_COL_BAR_BG         = Color(255, 255, 255, 22)
local _ST_COL_MANA_BAR       = Color(60,  200, 255, 255)
local _ST_COL_MONEY_TXT      = Color(255, 215, 80,  210)
local _ST_COL_PLUS_HOV_BG    = Color(255, 80,  80,  200)
local _ST_COL_PLUS_NORM_BG   = Color(255, 255, 255, 35)
local _ST_COL_PLUS_HOV_BORD  = Color(255, 130, 130, 255)
local _ST_COL_PLUS_NORM_BORD = Color(255, 255, 255, 100)
local _ST_COL_PLUS_HOV_TXT   = Color(255, 255, 255, 255)
local _ST_COL_PLUS_NORM_TXT  = Color(255, 255, 255, 200)
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── Fonts pré-cachées pour HUDPaint (évite Font:GetNamed() par frame) ───────
local _ST_FONT_BANNER   = nil  -- "Poppins Bold 22"
local _ST_FONT_HINT     = nil  -- "Poppins Regular 11"
local _ST_FONT_LIST     = nil  -- "Poppins Medium 11"
local _ST_FONT_LIST_B   = nil  -- "Poppins Bold 10"
local _ST_FONT_LOG      = nil  -- "Poppins Regular 11"
local _ST_FONT_NAME     = nil  -- "Poppins SemiBold 13"
local _ST_FONT_JOB      = nil  -- "Poppins Regular 11"
local _ST_FONT_MONEY    = nil  -- "Poppins Medium 11"
local _ST_FONT_STAT     = nil  -- "Poppins Medium 10"
local _ST_FONT_PLUS     = nil  -- "Poppins Bold 16"
local _ST_FONT_WARN     = nil  -- "Poppins Bold 10"
local function _stEnsureFonts()
    if _ST_FONT_BANNER then return end
    _ST_FONT_BANNER = Font:GetNamed("Poppins", "Bold",     22)
    _ST_FONT_HINT   = Font:GetNamed("Poppins", "Regular",  11)
    _ST_FONT_LIST   = Font:GetNamed("Poppins", "Medium",   11)
    _ST_FONT_LIST_B = Font:GetNamed("Poppins", "Bold",     10)
    _ST_FONT_LOG    = Font:GetNamed("Poppins", "Regular",  11)
    _ST_FONT_NAME   = Font:GetNamed("Poppins", "SemiBold", 13)
    _ST_FONT_JOB    = Font:GetNamed("Poppins", "Regular",  11)
    _ST_FONT_MONEY  = Font:GetNamed("Poppins", "Medium",   11)
    _ST_FONT_STAT   = Font:GetNamed("Poppins", "Medium",   10)
    _ST_FONT_PLUS   = Font:GetNamed("Poppins", "Bold",     16)
    _ST_FONT_WARN   = Font:GetNamed("Poppins", "Bold",     10)
end
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── Cache joueurs (évite player.GetAll() dans HUDPaint) ─────────────────────
local _stAllPlayers = {}
local function _stRebuildPlayerList()
    _stAllPlayers = player.GetAll()
end
-- PlayerSpawn : l'entité du nouveau joueur n'est pas encore dans GetAll() au moment
-- exact où le hook se déclenche côté client → on diffère d'une demi-seconde.
hook.Add("PlayerSpawn",        "VERSE::Staff::PlayerCache", function() timer.Simple(0.5, _stRebuildPlayerList) end)
hook.Add("PlayerDisconnected", "VERSE::Staff::PlayerCache", _stRebuildPlayerList)
hook.Add("InitPostEntity",     "VERSE::Staff::PlayerCache", _stRebuildPlayerList)
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── État ─────────────────────────────────────────────────────────────────────

local staffActive  = false
local playerCache  = {}    -- [uid] = { name, job, hp, maxHp, mana, maxMana, money, warns, frozen }
local plusRects    = {}    -- [uid] = {x,y,w,h}  boutons "+" ESP
local listRects    = {}    -- [uid] = {x,y,w,h}  lignes panneau liste
local actionPopup  = nil
local invPopup     = nil
local wasM2Down    = false
local spectateUID  = nil   -- nil = pas de spectate
local staffLog     = {}    -- { {text, t}, ... }
local LOG_MAX      = 8
local LOG_LIFE     = 30    -- secondes avant disparition d'une entrée

-- ─── Log session ──────────────────────────────────────────────────────────────

local function addLog(text)
    table.insert(staffLog, 1, { text = tostring(text), t = RealTime() })
    if #staffLog > LOG_MAX then table.remove(staffLog) end
end

-- ─── Réception réseau ─────────────────────────────────────────────────────────

netstream.Hook(S.Net.Toggle, function(active)
    staffActive = active and true or false
    if not staffActive then
        playerCache = {}
        plusRects   = {}
        listRects   = {}
        spectateUID = nil
        staffLog    = {}
        if IsValid(actionPopup) then actionPopup:Remove() end
        if IsValid(invPopup)    then invPopup:Remove()    end
    end
end)

netstream.Hook(S.Net.Data, function(data)
    if not istable(data) then return end
    -- Resync la liste de joueurs à chaque update serveur (filet de sécurité)
    _stRebuildPlayerList()
    playerCache = {}
    for _, e in ipairs(data) do
        if e.uid then playerCache[e.uid] = e end
    end
end)

-- ─── Spectate ─────────────────────────────────────────────────────────────────

local function getSpectateTarget()
    if not spectateUID then return nil end
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:UserID() == spectateUID then return p end
    end
    spectateUID = nil
    return nil
end

local function stopSpectate()
    if spectateUID then
        addLog("Spectate termine")
        spectateUID = nil
    end
end

VERSE.Hook.AddNS("Staff", "CalcView", "VERSE::Staff::Spectate", function(ply, pos, angles, fov)
    if not staffActive or not spectateUID then return end
    local target = getSpectateTarget()
    if not IsValid(target) or not target:Alive() then stopSpectate() return end
    return { origin = target:EyePos(), angles = target:EyeAngles(), fov = fov }
end)

-- ─── Helpers UI ───────────────────────────────────────────────────────────────

local function closeActionPopup()
    if IsValid(actionPopup) then actionPopup:Remove() end
    actionPopup = nil
end

local function openInputDialog(title, hint, onConfirm)
    local dw, dh = R:X(340), R:Y(160)
    local df = vgui.Create("DFrame")
    df:SetSize(dw, dh)
    df:Center()
    df:SetTitle("")
    df:ShowCloseButton(false)
    df:SetDraggable(false)
    df:MakePopup()

    df.Paint = function(_, w, h)
        RNDX.Draw(R:Y(10), 0, 0, w, h, Color(10, 8, 18, 252))
        RNDX.DrawOutlined(R:Y(10), 0, 0, w, h, Color(255, 80, 80, 160), 1)
        draw.SimpleText(title, Font:GetNamed("Poppins", "SemiBold", 15), w * 0.5, R:Y(18), Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local entry = vgui.Create("DTextEntry", df)
    entry:SetPos(R:X(12), R:Y(38))
    entry:SetSize(dw - R:X(24), R:Y(30))
    entry:SetFont(Font:GetNamed("Poppins", "Regular", 14))
    entry:SetPlaceholderText(hint)
    entry:SetTextColor(color_white)
    entry:SetDrawLanguageID(false)
    entry:RequestFocus()
    entry.Paint = function(s, w, h)
        RNDX.Draw(R:Y(6), 0, 0, w, h, Color(255, 255, 255, 18))
        RNDX.DrawOutlined(R:Y(6), 0, 0, w, h, Color(255, 255, 255, 40), 1)
        s:DrawTextEntryText(color_white, Color(100, 140, 255, 200), Color(255, 255, 255))
    end

    local function confirm()
        local val = string.Trim(entry:GetValue() or "")
        df:Remove()
        onConfirm(val)
    end
    entry.OnEnter = confirm

    local btnY = R:Y(82)
    local btnH = R:Y(34)
    local btnW = (dw - R:X(36)) * 0.5

    local function makeBtn(label, col, x, cb)
        local b = vgui.Create("DButton", df)
        b:SetPos(x, btnY)
        b:SetSize(btnW, btnH)
        b:SetText("")
        b.Paint = function(s, w, h)
            local hov = s:IsHovered()
            RNDX.Draw(R:Y(7), 0, 0, w, h, Color(col.r, col.g, col.b, hov and 80 or 45))
            RNDX.DrawOutlined(R:Y(7), 0, 0, w, h, Color(col.r, col.g, col.b, hov and 200 or 120), 1)
            draw.SimpleText(label, Font:GetNamed("Poppins", "Medium", 14), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = cb
    end

    makeBtn("Confirmer", Color(80, 200, 120), R:X(12), confirm)
    makeBtn("Annuler",   Color(200, 80, 80),  R:X(12) + btnW + R:X(12), function() df:Remove() end)
end

-- ─── Sélecteur de job ────────────────────────────────────────────────────────

local function openJobDialog(uid, playerName)
    local jobList = {}
    if VERSE and VERSE.Jobs and VERSE.Jobs.Registry then
        for id, job in SortedPairsByMemberValue(VERSE.Jobs.Registry, "name") do
            jobList[#jobList + 1] = { id = id, name = tostring(job.name or id) }
        end
    end
    if #jobList == 0 then
        chat.AddText(Color(255, 100, 100), "[Staff] Aucun job disponible.")
        return
    end

    local dw, dh = R:X(340), R:Y(156)
    local df = vgui.Create("DFrame")
    df:SetSize(dw, dh)
    df:Center()
    df:SetTitle("")
    df:ShowCloseButton(false)
    df:SetDraggable(false)
    df:MakePopup()

    df.Paint = function(_, w, h)
        RNDX.Draw(R:Y(10), 0, 0, w, h, Color(10, 8, 18, 252))
        RNDX.DrawOutlined(R:Y(10), 0, 0, w, h, Color(100, 140, 255, 180), 1)
        draw.SimpleText("Job de " .. playerName, Font:GetNamed("Poppins", "SemiBold", 15), w * 0.5, R:Y(18), Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    df.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then df:Remove() end
    end

    local selectedId = jobList[1].id

    local combo = vgui.Create("DComboBox", df)
    combo:SetPos(R:X(12), R:Y(36))
    combo:SetSize(dw - R:X(24), R:Y(28))
    combo:SetValue(jobList[1].name)
    for _, j in ipairs(jobList) do
        combo:AddChoice(j.name, j.id)
    end
    combo.OnSelect = function(_, _, _, data)
        selectedId = data
    end

    local btnY = R:Y(78)
    local btnH = R:Y(34)
    local btnW = (dw - R:X(36)) * 0.5

    local function makeBtn(label, col, x, cb)
        local b = vgui.Create("DButton", df)
        b:SetPos(x, btnY)
        b:SetSize(btnW, btnH)
        b:SetText("")
        b.Paint = function(s, w, h)
            local hov = s:IsHovered()
            RNDX.Draw(R:Y(7), 0, 0, w, h, Color(col.r, col.g, col.b, hov and 80 or 45))
            RNDX.DrawOutlined(R:Y(7), 0, 0, w, h, Color(col.r, col.g, col.b, hov and 200 or 120), 1)
            draw.SimpleText(label, Font:GetNamed("Poppins", "Medium", 14), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = cb
    end

    makeBtn("Confirmer", Color(80, 200, 120), R:X(12), function()
        df:Remove()
        netstream.Start(S.Net.SetJob, uid, selectedId)
        addLog("Job -> " .. selectedId)
    end)
    makeBtn("Annuler", Color(200, 80, 80), R:X(12) + btnW + R:X(12), function() df:Remove() end)
end

-- ─── Popup d'action (2 colonnes × 5 lignes) ──────────────────────────────────

local function openActionPopup(uid, data)
    closeActionPopup()
    local name     = data and tostring(data.name or "Joueur") or "Joueur"
    local isFrozen = data and data.frozen or false

    local btnW  = R:X(138)
    local btnH  = R:Y(34)
    local gap   = R:Y(5)
    local padX  = R:X(10)
    local padY  = R:Y(42)
    local cols  = 2
    local rows  = 6
    local pw    = cols * btnW + (cols + 1) * padX
    local ph    = padY + rows * btnH + (rows - 1) * gap + R:Y(10)

    local px = math.Clamp(ScrW() * 0.5 + R:X(24), 0, ScrW() - pw)
    local py = math.Clamp(ScrH() * 0.5 - ph * 0.5, 0, ScrH() - ph)

    local popup = vgui.Create("DFrame")
    popup:SetPos(px, py)
    popup:SetSize(pw, ph)
    popup:SetTitle("")
    popup:ShowCloseButton(false)
    popup:SetDraggable(false)
    popup:MakePopup()
    actionPopup = popup

    popup.Paint = function(_, w, h)
        RNDX.Draw(R:Y(10), 0, 0, w, h, Color(10, 8, 20, 252))
        RNDX.DrawOutlined(R:Y(10), 0, 0, w, h, Color(255, 80, 80, 180), 1)
        draw.SimpleText(name, Font:GetNamed("Poppins", "SemiBold", 13), w * 0.5, R:Y(18), Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        RNDX.Draw(0, padX, R:Y(33), w - padX * 2, 1, Color(255, 255, 255, 25))
    end
    popup.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then closeActionPopup() end
    end

    local function btn(col, row, label, color, cb)
        local b = vgui.Create("DButton", popup)
        b:SetPos(padX + (col - 1) * (btnW + padX), padY + (row - 1) * (btnH + gap))
        b:SetSize(btnW, btnH)
        b:SetText("")
        b.Paint = function(s, w, h)
            local hov = s:IsHovered()
            RNDX.Draw(R:Y(7), 0, 0, w, h, Color(color.r, color.g, color.b, hov and 75 or 38))
            RNDX.DrawOutlined(R:Y(7), 0, 0, w, h, Color(color.r, color.g, color.b, hov and 210 or 110), 1)
            draw.SimpleText(label, Font:GetNamed("Poppins", "Medium", 12), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = cb
    end

    -- ── Colonne gauche : actions de déplacement / état ──
    btn(1, 1, "TP vers", Color(100, 180, 255), function()
        closeActionPopup()
        netstream.Start(S.Net.Teleport, uid)
        addLog("TP vers " .. name)
    end)

    btn(1, 2, "Ramener", Color(70, 150, 220), function()
        closeActionPopup()
        netstream.Start(S.Net.Bring, uid)
        addLog("Ramene " .. name)
    end)

    btn(1, 3, isFrozen and "Degeler" or "Geler", Color(100, 200, 255), function()
        closeActionPopup()
        netstream.Start(S.Net.Freeze, uid, not isFrozen)
        addLog((isFrozen and "Degele " or "Gele ") .. name)
    end)

    btn(1, 4, "Soigner", Color(70, 200, 120), function()
        closeActionPopup()
        netstream.Start(S.Net.Heal, uid)
        addLog("Soigne " .. name)
    end)

    btn(1, 5, "Spectate", Color(160, 100, 255), function()
        closeActionPopup()
        spectateUID = uid
        addLog("Spectate " .. name)
    end)

    btn(1, 6, "Fouiller inv.", Color(80, 140, 255), function()
        closeActionPopup()
        netstream.Start(S.Net.Search, uid)
    end)

    -- ── Colonne droite : modération / économie ──
    btn(2, 1, "Avertir", Color(255, 175, 0), function()
        closeActionPopup()
        openInputDialog("Raison de l'avertissement", "Entrez une raison...", function(reason)
            if reason == "" then return end
            netstream.Start(S.Net.Warn, uid, reason)
            addLog("Warn " .. name .. " : " .. reason)
        end)
    end)

    btn(2, 2, "Set Job", Color(80, 170, 255), function()
        closeActionPopup()
        openJobDialog(uid, name)
    end)

    btn(2, 3, "Kick", Color(255, 155, 50), function()
        closeActionPopup()
        openInputDialog("Raison du kick", "Entrez une raison...", function(reason)
            netstream.Start(S.Net.Kick, uid, reason)
            addLog("Kick " .. name)
        end)
    end)

    btn(2, 4, "Ban", Color(225, 55, 55), function()
        closeActionPopup()
        openInputDialog("Duree du ban (0 = permanent)", "0", function(dur)
            local minutes = math.max(0, math.floor(tonumber(dur) or 0))
            openInputDialog("Raison du ban", "Entrez une raison...", function(reason)
                netstream.Start(S.Net.Ban, uid, minutes, reason)
                addLog("Ban " .. name)
            end)
        end)
    end)

    btn(2, 5, "Fermer", Color(110, 110, 130), closeActionPopup)
end

-- ─── Viewer inventaire ────────────────────────────────────────────────────────

netstream.Hook(S.Net.Inventory, function(uid, playerName, inv)
    if IsValid(invPopup) then invPopup:Remove() end

    local iw, ih = R:X(500), R:Y(500)
    local frame = vgui.Create("DFrame")
    frame:SetSize(iw, ih)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:MakePopup()
    invPopup = frame

    frame.Paint = function(_, w, h)
        RNDX.Draw(R:Y(12), 0, 0, w, h, Color(10, 8, 20, 250))
        RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, Color(80, 150, 255, 160), 1)
        draw.SimpleText("Inventaire de " .. tostring(playerName), Font:GetNamed("Poppins", "SemiBold", 18), w * 0.5, R:Y(20), Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        RNDX.Draw(0, R:X(12), R:Y(38), w - R:X(24), 1, Color(255, 255, 255, 28))
    end
    frame.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then frame:Remove() end
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(iw - R:X(44), R:Y(8))
    closeBtn:SetSize(R:X(36), R:Y(24))
    closeBtn:SetText("")
    closeBtn.Paint = function(s, w, h)
        RNDX.Draw(R:Y(5), 0, 0, w, h, Color(200, 60, 60, s:IsHovered() and 180 or 80))
        draw.SimpleText("X", Font:GetNamed("Poppins", "Bold", 12), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Remove() end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(R:X(12), R:Y(46))
    scroll:SetSize(iw - R:X(24), ih - R:Y(58))
    local sbar = scroll:GetVBar()
    sbar:SetWide(R:X(4))
    sbar.Paint         = function(_, w, h) RNDX.Draw(R:Y(3), 0, 0, w, h, Color(255, 255, 255, 12)) end
    sbar.btnUp.Paint   = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h) RNDX.Draw(R:Y(3), 0, 0, w, h, Color(80, 150, 255, 130)) end

    if not inv or #inv == 0 then
        local lbl = vgui.Create("DLabel", scroll)
        lbl:SetFont(Font:GetNamed("Poppins", "Regular", 16))
        lbl:SetText("Inventaire vide.")
        lbl:SetTextColor(Color(160, 160, 180))
        lbl:SizeToContents()
        lbl:SetPos((iw - R:X(24) - lbl:GetWide()) * 0.5, R:Y(20))
        return
    end

    local rowH, rowGap = R:Y(36), R:Y(4)
    for i, item in ipairs(inv) do
        local row = vgui.Create("DPanel", scroll)
        row:SetPos(0, (i - 1) * (rowH + rowGap))
        row:SetSize(iw - R:X(40), rowH)
        local iData = item
        row.Paint = function(_, w, h)
            RNDX.Draw(R:Y(5), 0, 0, w, h, (i % 2 == 0) and Color(255, 255, 255, 8) or Color(255, 255, 255, 4))
            local iconS = h - R:Y(8)
            if iData.icon and iData.icon ~= "" then
                VERSE.Materials:Draw(color_white, iData.icon, R:X(6), R:Y(4), iconS, iconS, "noclamp smooth")
            else
                RNDX.Draw(R:Y(4), R:X(6), R:Y(4), iconS, iconS, Color(80, 80, 100, 80))
            end
            draw.SimpleText(tostring(iData.name or iData.id), Font:GetNamed("Poppins", "Medium", 13), R:X(6) + iconS + R:X(8), h * 0.5, Color(220, 225, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("x" .. tostring(iData.amount or 1), Font:GetNamed("Poppins", "SemiBold", 13), w - R:X(10), h * 0.5, Color(150, 200, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end)

-- ─── Think : clic droit ───────────────────────────────────────────────────────

VERSE.Hook.AddNS("Staff", "Think", "VERSE::Staff::Think", function()
    if not staffActive then wasM2Down = false return end

    local m2 = input.IsMouseDown(MOUSE_RIGHT)
    if m2 and not wasM2Down then
        local cx, cy = ScrW() * 0.5, ScrH() * 0.5
        local hit = false

        -- Boutons "+" des cartes ESP
        for uid, rect in pairs(plusRects) do
            if cx >= rect.x and cx <= rect.x + rect.w and cy >= rect.y and cy <= rect.y + rect.h then
                openActionPopup(uid, playerCache[uid])
                hit = true
                break
            end
        end

        -- Lignes du panneau liste joueurs
        if not hit then
            for uid, rect in pairs(listRects) do
                if cx >= rect.x and cx <= rect.x + rect.w and cy >= rect.y and cy <= rect.y + rect.h then
                    openActionPopup(uid, playerCache[uid])
                    hit = true
                    break
                end
            end
        end

        -- Clic droit dans le vide pendant spectate → arrêter spectate
        if not hit and spectateUID then
            stopSpectate()
        end
    end
    wasM2Down = m2
end)

-- ─── HUDPaint ─────────────────────────────────────────────────────────────────

VERSE.Hook.AddNS("Staff", "HUDPaint", "VERSE::Staff::HUDPaint", function()
    if not staffActive then return end

    local sw, sh   = ScrW(), ScrH()
    local cx, cy   = sw * 0.5, sh * 0.5
    local lp       = LocalPlayer()
    local now      = RealTime()

    _stEnsureFonts()

    -- ── Bannière ──────────────────────────────────────────────────────────────
    local bText = spectateUID and ("SPECTATE : " .. (playerCache[spectateUID] and playerCache[spectateUID].name or "?")) or "MODE STAFF"
    surface.SetFont(_ST_FONT_BANNER)
    local tw = surface.GetTextSize(bText)
    local bw, bh = tw + R:X(40), R:Y(36)
    local bx, by = (sw - bw) * 0.5, R:Y(8)
    local bCol  = spectateUID and _ST_COL_BANNER_SPEC  or _ST_COL_BANNER_STAFF
    local bBord = spectateUID and _ST_COL_BANNER_BORD_SP or _ST_COL_BANNER_BORD_ST
    RNDX.Draw(R:Y(8), bx, by, bw, bh, bCol)
    RNDX.DrawOutlined(R:Y(8), bx, by, bw, bh, bBord, 1)
    draw.SimpleText(bText, _ST_FONT_BANNER, sw * 0.5, by + bh * 0.5, _ST_COL_BANNER_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local hintText = spectateUID
        and "Clic droit dans le vide pour arreter le spectate"
        or  "Clic droit sur [+] ou sur la liste pour agir"
    draw.SimpleText(hintText, _ST_FONT_HINT, sw * 0.5, by + bh + R:Y(4), _ST_COL_HINT_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    -- ── Panneau liste joueurs (droite) ────────────────────────────────────────
    local listW    = R:X(215)
    local listX    = sw - listW - R:X(8)
    local rowH     = R:Y(27)
    local rowGap   = R:Y(3)

    local players = {}
    for _, p in ipairs(_stAllPlayers) do
        if IsValid(p) and p ~= lp then table.insert(players, p) end
    end

    local listH = R:Y(26) + #players * (rowH + rowGap) + R:Y(4)
    local listY  = R:Y(58)

    RNDX.Draw(R:Y(8), listX - R:X(3), listY - R:Y(3), listW + R:X(6), listH + R:Y(6), _ST_COL_LIST_BG)
    RNDX.DrawOutlined(R:Y(8), listX - R:X(3), listY - R:Y(3), listW + R:X(6), listH + R:Y(6), _ST_COL_LIST_BORD, 1)
    draw.SimpleText("JOUEURS EN LIGNE", _ST_FONT_LIST_B, listX + listW * 0.5, listY + R:Y(7), _ST_COL_LIST_HDR, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    listRects = {}
    local curY = listY + R:Y(23)

    for _, p in ipairs(players) do
        local uid    = p:UserID()
        local data   = playerCache[uid] or {}
        local frozen = data.frozen or false
        local warns  = data.warns  or 0
        local isOver = (cx >= listX and cx <= listX + listW and cy >= curY and cy <= curY + rowH)

        -- Fond ligne
        RNDX.Draw(R:Y(4), listX, curY, listW, rowH, isOver and _ST_COL_LIST_ROW_HOV or _ST_COL_LIST_ROW_NORM)

        -- Indicateur freeze (bande bleue gauche)
        if frozen then
            RNDX.Draw(0, listX, curY, R:X(3), rowH, _ST_COL_LIST_FRZ)
        end

        -- Nom RP
        local nameStr = tostring(data.name or p:Nick())
        draw.SimpleText(nameStr, _ST_FONT_LIST, listX + R:X(8), curY + rowH * 0.5, _ST_COL_LIST_NAME, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Badge warns
        if warns > 0 then
            draw.SimpleText("W" .. warns, _ST_FONT_LIST_B, listX + listW - R:X(6), curY + rowH * 0.5, _ST_COL_LIST_WARN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        listRects[uid] = { x = listX, y = curY, w = listW, h = rowH }
        curY = curY + rowH + rowGap
    end

    -- ── Log d'actions (bas gauche) ────────────────────────────────────────────
    if #staffLog > 0 then
        local logW = R:X(290)
        local logX = R:X(8)
        local logY = sh - R:Y(8)

        for i, entry in ipairs(staffLog) do
            local age  = now - entry.t
            if age > LOG_LIFE then break end
            local fade = math.Clamp(1 - (age / LOG_LIFE), 0, 1)
            local a    = math.floor(fade * 210)
            logY = logY - R:Y(18)
            _ST_COL_LOG_BG.a  = math.floor(a * 0.4)
            _ST_COL_LOG_TXT.a = a
            RNDX.Draw(R:Y(4), logX, logY - R:Y(1), logW, R:Y(16), _ST_COL_LOG_BG)
            draw.SimpleText(entry.text, _ST_FONT_LOG, logX + R:X(6), logY + R:Y(7), _ST_COL_LOG_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- ── ESP cartes joueurs ────────────────────────────────────────────────────
    plusRects = {}

    local cardW    = R:X(240)
    local cardH    = R:Y(130)
    local barW     = R:X(160)
    local barH     = R:Y(7)
    local plusSize = R:X(24)

    for _, ply in ipairs(_stAllPlayers) do
        if not IsValid(ply) or ply == lp or not ply:Alive() then continue end

        local headPos = ply:GetPos() + Vector(0, 0, 80)
        local sp = headPos:ToScreen()
        if not sp or not sp.visible then continue end
        if sp.x < 0 or sp.x > sw then continue end
        if sp.y < 0 or sp.y > sh then continue end

        -- À plus de 2000 unités : simple bulle violette, pas de carte complète
        local dist3d = lp:GetPos():Distance(ply:GetPos())
        if dist3d > 2000 then
            local bubbleR = R:Y(11)
            RNDX.Draw(bubbleR, sp.x - bubbleR, sp.y - bubbleR, bubbleR * 2, bubbleR * 2, _ST_COL_BUBBLE)
            RNDX.DrawOutlined(bubbleR, sp.x - bubbleR, sp.y - bubbleR, bubbleR * 2, bubbleR * 2, _ST_COL_BUBBLE_BORD, 2)
            continue
        end

        local uid    = ply:UserID()
        local data   = playerCache[uid] or {}
        local frozen = data.frozen or false
        local warns  = data.warns  or 0

        local sx = math.Clamp(sp.x - cardW * 0.5, R:X(4), sw - cardW - R:X(4))
        local sy = math.Clamp(sp.y - cardH - R:Y(8), R:Y(4), sh - cardH - R:Y(4))

        local hp     = tonumber(data.hp)    or ply:Health()
        local maxHp  = tonumber(data.maxHp) or math.max(1, ply:GetMaxHealth())
        local hpFrac = math.Clamp(hp / maxHp, 0, 1)
        -- Mutation de la couleur HP pré-allouée (évite Color() par frame/joueur)
        _ST_COL_HP_BAR.r = math.floor(Lerp(hpFrac, 230, 80))
        _ST_COL_HP_BAR.g = math.floor(Lerp(hpFrac, 60,  210))
        _ST_COL_HP_BAR.b = math.floor(Lerp(hpFrac, 60,  80))

        -- Fond carte + bord (bleu si gelé)
        RNDX.Draw(R:Y(8), sx, sy, cardW, cardH, _ST_COL_CARD_BG)
        RNDX.DrawOutlined(R:Y(8), sx, sy, cardW, cardH, frozen and _ST_COL_CARD_BORD_FRZ or _ST_COL_CARD_BORD_NORM, 1)
        -- Barre HP en haut de carte
        RNDX.Draw(0, sx, sy, math.floor(cardW * hpFrac), R:Y(3), _ST_COL_HP_BAR)

        local padX = R:X(10)
        local curY = sy + R:Y(8)
        local barX = sx + padX

        -- Nom + badge warns
        draw.SimpleText(tostring(data.name or ply:Nick()), _ST_FONT_NAME, barX, curY, _ST_COL_NAME_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if warns > 0 then
            draw.SimpleText("W" .. warns, _ST_FONT_WARN, sx + cardW - plusSize - R:X(14), curY, _ST_COL_WARN_TXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
        curY = curY + R:Y(16)

        -- Job (+ [GELE])
        local jobStr = tostring(data.job or ply:GetUserGroup()) .. (frozen and "  [GELE]" or "")
        draw.SimpleText(jobStr, _ST_FONT_JOB, barX, curY, frozen and _ST_COL_JOB_FRZ or _ST_COL_JOB_NORM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        curY = curY + R:Y(14)

        -- Barre HP
        draw.SimpleText("PV", _ST_FONT_STAT, barX, curY, _ST_COL_HP_BAR, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(hp) .. " / " .. tostring(maxHp), _ST_FONT_STAT, barX + barW, curY, _ST_COL_STAT_TXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        curY = curY + R:Y(13)
        RNDX.Draw(R:Y(3), barX, curY, barW, barH, _ST_COL_BAR_BG)
        RNDX.Draw(R:Y(3), barX, curY, math.floor(barW * hpFrac), barH, _ST_COL_HP_BAR)
        curY = curY + barH + R:Y(7)

        -- Barre Mana
        local mana     = tonumber(data.mana)    or 0
        local maxMana  = tonumber(data.maxMana) or 100
        local manaFrac = math.Clamp(mana / math.max(1, maxMana), 0, 1)
        draw.SimpleText("EO", _ST_FONT_STAT, barX, curY, _ST_COL_MANA_BAR, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(mana) .. " / " .. tostring(maxMana), _ST_FONT_STAT, barX + barW, curY, _ST_COL_STAT_TXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        curY = curY + R:Y(13)
        RNDX.Draw(R:Y(3), barX, curY, barW, barH, _ST_COL_BAR_BG)
        RNDX.Draw(R:Y(3), barX, curY, math.floor(barW * manaFrac), barH, _ST_COL_MANA_BAR)
        curY = curY + barH + R:Y(7)

        -- Argent
        draw.SimpleText(tostring(tonumber(data.money) or 0) .. " Y", _ST_FONT_MONEY, barX, curY, _ST_COL_MONEY_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Bouton "+"
        local plusX = sx + cardW - plusSize - R:X(8)
        local plusY = sy + (cardH - plusSize) * 0.5
        local over  = (cx >= plusX and cx <= plusX + plusSize and cy >= plusY and cy <= plusY + plusSize)
        RNDX.Draw(R:Y(5), plusX, plusY, plusSize, plusSize, over and _ST_COL_PLUS_HOV_BG or _ST_COL_PLUS_NORM_BG)
        RNDX.DrawOutlined(R:Y(5), plusX, plusY, plusSize, plusSize, over and _ST_COL_PLUS_HOV_BORD or _ST_COL_PLUS_NORM_BORD, 1)
        draw.SimpleText("+", _ST_FONT_PLUS, plusX + plusSize * 0.5, plusY + plusSize * 0.5, over and _ST_COL_PLUS_HOV_TXT or _ST_COL_PLUS_NORM_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        plusRects[uid] = { x = plusX, y = plusY, w = plusSize, h = plusSize }

        -- Ligne tête → carte
        surface.SetDrawColor(255, 255, 255, 22)
        surface.DrawLine(sx + cardW * 0.5, sy + cardH, sp.x, sp.y)
    end
end)

-- ─── Masquer le crosshair natif + viewmodel en staff mode ────────────────────

VERSE.Hook.AddNS("Staff", "HUDShouldDraw", "VERSE::Staff::HideHUD", function(name)
    if staffActive and name == "CHudCrosshair" then return false end
end)

-- Cache le viewmodel (objet en main / mains) quand le mode staff est actif.
-- PreDrawViewModel : retourner true = ne pas dessiner le viewmodel ce frame.
VERSE.Hook.AddNS("Staff", "PreDrawViewModel", "VERSE::Staff::HideViewModel", function()
    if staffActive then return true end
end)
