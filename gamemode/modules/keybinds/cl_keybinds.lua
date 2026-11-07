local Binds = {}
Binds.Map = {
    [KEY_I] = "verse_inventory",
    [KEY_F4] = "verse_skilltree",
    [KEY_F6] = "verse_squad",
    [KEY_B] = "verse_skill_loadout",
    [KEY_G] = "verse_skill_next_preset",
    [KEY_F7] = "verse_ost_menu",
    [KEY_F2] = "verse_boutique",
    [KEY_P] = "verse_talkmode",
    [KEY_N] = "verse_introduce_self",
    [KEY_M] = "verse_missive",
    [KEY_K] = "verse_squad_toggle_mic",
    [KEY_L] = "verse_squad_toggle_listen",
    [KEY_F8] = "verse_cinematic",
}

Binds.HoldMap = {
    [KEY_H] = {
        press = "+verse_animations_wheel",
        release = "-verse_animations_wheel"
    },
}

Binds._cooldown = {}
Binds._tracked = {}
Binds._down = {}
local COOLDOWN = 0.2
Binds.CustomResolvers = {
    verse_animations_wheel = {
        get = function() return VERSE.Animations and VERSE.Animations._wheel end,
        close = function(panel)
            local A = VERSE.Animations
            if A and isfunction(A.CloseWheel) then
                A.CloseWheel()
            elseif IsValid(panel) then
                panel:Remove()
            end
        end,
    },
}

local TEXT_ENTRY_CLASSES = {
    ["TextEntry"] = true,
    ["DTextEntry"] = true,
    ["RichText"] = true,
    ["MantleEntry"] = true,
    ["MantleTextbox"] = true,
}

local function isTyping()
    if gui.IsConsoleVisible() then return true end
    local focused = vgui.GetKeyboardFocus()
    if not IsValid(focused) then return false end
    local A = VERSE and VERSE.Animations
    if A and A._wheel and focused == A._wheel then return false end
    local class = focused.ClassName or (focused.GetClassName and focused:GetClassName()) or ""
    if TEXT_ENTRY_CLASSES[class] then return true end
    if focused.GetText and focused.SetText and focused.AllowInput ~= nil then return true end
    return false
end

local function snapshotFrames()
    local set = {}
    local src = VERSE._MantleFrames
    if not src then return set end
    for f in pairs(src) do
        if IsValid(f) then set[f] = true end
    end
    return set
end

local function findNewFrame(before)
    local src = VERSE._MantleFrames
    if not src then return nil end
    local newest, newestOrder = nil, -math.huge
    for f in pairs(src) do
        if IsValid(f) and not before[f] then
            local ord = f._mantleFrameOrder or 0
            if ord > newestOrder then
                newest = f
                newestOrder = ord
            end
        end
    end
    return newest
end

local function runCommandSync(cmd)
    local tbl = concommand.GetTable()
    local fn = tbl and tbl[cmd]
    if isfunction(fn) then
        fn(LocalPlayer(), cmd, {}, "")
        return true
    end

    RunConsoleCommand(cmd)
    return false
end

local function handleBind(button, cmd)
    local now = RealTime()
    if (Binds._cooldown[button] or 0) > now then return end
    Binds._cooldown[button] = now + COOLDOWN
    local resolver = Binds.CustomResolvers[cmd]
    if resolver then
        local panel = resolver.get and resolver.get() or nil
        if IsValid(panel) then
            resolver.close(panel)
            return
        end

        runCommandSync(cmd)
        return
    end

    local tracked = Binds._tracked[button]
    if IsValid(tracked) then
        Binds._tracked[button] = nil
        if isfunction(tracked.Close) then
            tracked:Close()
        else
            tracked:Remove()
        end
        return
    end

    local before = snapshotFrames()
    local ran = runCommandSync(cmd)
    if not ran then return end
    local opened = findNewFrame(before)
    if IsValid(opened) then Binds._tracked[button] = opened end
end

VERSE.Hook.AddNS("Keybinds", "Think", "VERSE::Think::Keybinds", function()
    if isTyping() then
        for key in pairs(Binds.Map) do
            Binds._down[key] = input.IsKeyDown(key)
        end

        for key in pairs(Binds.HoldMap) do
            Binds._down[key] = input.IsKeyDown(key)
        end
        return
    end

    for key, cmd in pairs(Binds.Map) do
        local down = input.IsKeyDown(key)
        if down and not Binds._down[key] then handleBind(key, cmd) end
        Binds._down[key] = down
    end

    for key, pair in pairs(Binds.HoldMap) do
        local down = input.IsKeyDown(key)
        local was = Binds._down[key]
        if down and not was then
            runCommandSync(pair.press)
        elseif not down and was then
            runCommandSync(pair.release)
        end

        Binds._down[key] = down
    end
end)

VERSE.Keybinds = Binds

-- ─── Raccourcis configurables ─────────────────────────────────────────────────

Binds.CustomizableDefs = {
    -- ── Général ───────────────────────────────────────────────────────────────
    { id = "boutique",      label = "Boutique",            cmd = "verse_boutique",            isHold = false },
    { id = "skilltree",     label = "Menu Arbre de compétences", cmd = "verse_skilltree",      isHold = false },
    { id = "missive",       label = "Missives",              cmd = "verse_missive",             isHold = false },
    { id = "introduce",     label = "Se présenter",         cmd = "verse_introduce_self",      isHold = false },
    { id = "talkmode",      label = "Distance de voix",     cmd = "verse_talkmode",            isHold = false },
    { id = "emote",         label = "Page d'emote",         cmd = "verse_animations_wheel",    isHold = true  },
    { id = "ost",           label = "Page OST",             cmd = "verse_ost_menu",            isHold = false },
    { id = "cinematic",     label = "Mode cinématique",     cmd = "verse_cinematic",           isHold = false },
    -- ── Deck de technique ─────────────────────────────────────────────────────
    { isSection = true, label = "Deck de technique" },
    { id = "loadout",       label = "Menu bind technique",  cmd = "verse_skill_loadout",       isHold = false },
    { id = "next_preset",   label = "Changer de set",       cmd = "verse_skill_next_preset",   isHold = false },
    -- ── Squad ─────────────────────────────────────────────────────────────────
    { isSection = true, label = "Squad" },
    { id = "squad",         label = "Menu squad",           cmd = "verse_squad",               isHold = false },
    { id = "squad_mic",     label = "Mute micro",           cmd = "verse_squad_toggle_mic",    isHold = false },
    { id = "squad_listen",  label = "Sourdine squad",       cmd = "verse_squad_toggle_listen", isHold = false },
}

-- Capture les touches PAR DÉFAUT avant tout chargement utilisateur (exécuté une seule fois)
Binds.DefaultKeys = Binds.DefaultKeys or {}
if not next(Binds.DefaultKeys) then
    for _, def in ipairs(Binds.CustomizableDefs) do
        if not def.isSection then
            -- Map
            for key, c in pairs(Binds.Map) do
                if c == def.cmd then Binds.DefaultKeys[def.id] = key break end
            end
            -- HoldMap
            if not Binds.DefaultKeys[def.id] then
                for key, pair in pairs(Binds.HoldMap) do
                    local pc = isstring(pair.press) and pair.press:gsub("^%+", "") or ""
                    if pc == def.cmd then Binds.DefaultKeys[def.id] = key break end
                end
            end
        end
    end
end

-- Retourne le keyCode actuellement lié à une commande
function Binds.GetKeyForCmd(cmd)
    for key, c in pairs(Binds.Map) do
        if c == cmd then return key end
    end
    for key, pair in pairs(Binds.HoldMap) do
        local pressCmd = isstring(pair.press) and pair.press:gsub("^%+", "") or ""
        if pressCmd == cmd then return key end
    end
    return nil
end

local function findCustomDef(id)
    for _, d in ipairs(Binds.CustomizableDefs) do
        if d.id == id then return d end
    end
end

local function applyBindInternal(def, newKey)
    if not def or not newKey or newKey <= 0 then return end
    -- Retire l'ancienne touche de cette commande
    local oldKey = Binds.GetKeyForCmd(def.cmd)
    if oldKey then
        if def.isHold then Binds.HoldMap[oldKey] = nil
        else               Binds.Map[oldKey]     = nil end
    end
    -- Retire toute action perso déjà présente sur la nouvelle touche
    for _, d in ipairs(Binds.CustomizableDefs) do
        if d.isHold then
            local pair = Binds.HoldMap[newKey]
            if pair then
                local pc = isstring(pair.press) and pair.press:gsub("^%+", "") or ""
                if pc == d.cmd then Binds.HoldMap[newKey] = nil end
            end
        else
            if Binds.Map[newKey] == d.cmd then Binds.Map[newKey] = nil end
        end
    end
    -- Applique
    if def.isHold then
        Binds.HoldMap[newKey] = { press = "+"..def.cmd, release = "-"..def.cmd }
    else
        Binds.Map[newKey] = def.cmd
    end
end

local SAVE_PATH = "verse/keybinds.json"

function Binds.SaveUserBinds()
    local data = {}
    for _, def in ipairs(Binds.CustomizableDefs) do
        local key = Binds.GetKeyForCmd(def.cmd)
        if key then data[def.id] = key end
    end
    if not file.IsDir("verse", "DATA") then file.CreateDir("verse") end
    file.Write(SAVE_PATH, util.TableToJSON(data, true))
end

function Binds.LoadUserBinds()
    local data = {}
    if file.Exists(SAVE_PATH, "DATA") then
        local raw = file.Read(SAVE_PATH, "DATA")
        if raw and raw ~= "" then
            local ok, parsed = pcall(util.JSONToTable, raw)
            if ok and istable(parsed) then data = parsed end
        end
    end
    for _, def in ipairs(Binds.CustomizableDefs) do
        local k = tonumber(data[def.id])
        if k and k > 0 then
            applyBindInternal(def, k)
        end
        -- Fallback : si toujours aucune touche, applique la valeur par défaut du Map
        if not Binds.GetKeyForCmd(def.cmd) then
            local defaultKey = Binds.DefaultKeys[def.id]
            if defaultKey then applyBindInternal(def, defaultKey) end
        end
    end
end

function Binds.ApplyUserBind(defId, newKey)
    local def = findCustomDef(defId)
    if not def then return end
    applyBindInternal(def, newKey)
    Binds.SaveUserBinds()
end

-- Remet toutes les touches configurables à leurs valeurs d'origine
function Binds.ResetUserBinds()
    for _, def in ipairs(Binds.CustomizableDefs) do
        if not def.isSection then
            local defaultKey = Binds.DefaultKeys[def.id]
            if defaultKey then
                applyBindInternal(def, defaultKey)
            end
        end
    end
    -- Efface la sauvegarde (table vide = pas de surcharge)
    if not file.IsDir("verse", "DATA") then file.CreateDir("verse") end
    file.Write(SAVE_PATH, util.TableToJSON({}, true))
end

hook.Add("InitPostEntity", "VERSE::Keybinds::LoadUserBinds", function()
    Binds.LoadUserBinds()
end)

-- ─── UI : menu de configuration des touches ───────────────────────────────────

local _bindFrame  = nil
local _captureId  = nil

local function keyDisplayName(keyCode)
    if not keyCode then return "—" end
    local n = input.GetKeyName(keyCode)
    return (n and n ~= "") and string.upper(n) or "?"
end

function Binds.OpenBindMenu()
    if IsValid(_bindFrame) then _bindFrame:Remove() end
    _captureId = nil

    local R    = VERSE.Responsive
    local Font = VERSE.Fonts

    local FW, FH = R:X(780), R:Y(910)
    local fr = vgui.Create("MantleFrame")
    _bindFrame = fr
    fr:SetSize(FW, FH)
    fr:Center()
    fr:MakePopup()
    fr:SetDraggable(false)
    fr:LiteMode()
    fr:SetAlphaBackground(false)
    fr:SetClosable(false)
    fr:DisableCloseBtn()

    -- ─── Couleurs pré-allouées pour Keybinds UI (évite Color() par frame) ────────
    local _KB_COL_FRAME_BG    = Color(10,  6,   26,  252)
    local _KB_COL_FRAME_BORD  = Color(138, 80,  255, 110)
    local _KB_COL_HDR_TXT     = Color(140, 120, 200, 255)
    local _KB_COL_CLOSE_BG    = Color(200, 50,  50,  0)    -- .a muté
    local _KB_COL_RESET_BG    = Color(55,  35,  100, 0)    -- .a muté
    local _KB_COL_RESET_BORD  = Color(200, 80,  80,  0)    -- .a muté
    local _KB_COL_RESET_TXT   = Color(255, 180, 180, 255)
    local _KB_COL_SBAR_BG     = Color(20,  15,  35,  200)
    local _KB_COL_SBAR_GRIP   = Color(138, 80,  255, 255)
    local _KB_COL_ROW_LBL     = Color(160, 130, 255, 255)
    local _KB_COL_ROW_CAP_BG  = Color(75,  28,  158, 180)
    local _KB_COL_ROW_NORM_BG = Color(255, 255, 255, 9)
    local _KB_COL_ROW_CAP_OUT = Color(138, 80,  255, 210)
    local _KB_COL_ROW_KEY_TXT = Color(185, 165, 255, 255)
    local _KB_COL_PILL_BG     = Color(75,  45,  140, 210)
    local _KB_COL_PILL_OUT    = Color(138, 80,  255, 130)
    local _KB_COL_EDIT_BG     = Color(55,  35,  100, 0)    -- .a muté
    local _KB_COL_EDIT_OUT    = Color(138, 80,  255, 0)    -- .a muté
    local _KB_COL_EDIT_TXT    = Color(210, 190, 255, 255)
    -- ─────────────────────────────────────────────────────────────────────────────

    -- ── Fond, titre & légende ──────────────────────────────────────────────────
    local _frTitleFont = Font:GetNamed("Poppins", "Bold",   34)
    local _frHdrFont   = Font:GetNamed("Poppins", "Medium", 13)
    fr.Paint = function(s, w, h)
        RNDX.Draw(R:Y(22), 0, 0, w, h, _KB_COL_FRAME_BG)
        RNDX.DrawOutlined(R:Y(22), 0, 0, w, h, _KB_COL_FRAME_BORD, 2)
        draw.SimpleText("Raccourcis clavier", _frTitleFont, w * 0.5, R:Y(44), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(138, 80, 255, 55)
        surface.DrawRect(R:X(40), R:Y(72), w - R:X(80), 1)
        draw.SimpleText("Action", _frHdrFont, R:X(50),      R:Y(82), _KB_COL_HDR_TXT, TEXT_ALIGN_LEFT,   TEXT_ALIGN_TOP)
        draw.SimpleText("Touche", _frHdrFont, w - R:X(225), R:Y(82), _KB_COL_HDR_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- ── Bouton fermer ──────────────────────────────────────────────────────────
    local closeBtn = vgui.Create("DButton", fr)
    closeBtn:SetSize(R:XY(34, 34))
    closeBtn:SetPos(FW - R:X(50), R:Y(16))
    closeBtn:SetText("")
    local _closeBtnFont = Font:GetNamed("Poppins", "Bold", 17)
    closeBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        _KB_COL_CLOSE_BG.a = hov and 200 or 90
        RNDX.Draw(R:Y(7), 0, 0, w, h, _KB_COL_CLOSE_BG)
        draw.SimpleText("✕", _closeBtnFont, w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() fr:Remove() end

    -- ── Bouton "Par défaut" (bas du frame, fixe) ──────────────────────────────
    local resetW = R:X(200)
    local resetH = R:Y(38)
    local resetBtn = vgui.Create("DButton", fr)
    resetBtn:SetSize(resetW, resetH)
    resetBtn:SetPos((FW - resetW) * 0.5, FH - resetH - R:Y(14))
    resetBtn:SetText("")
    local _resetBtnFont = Font:GetNamed("Poppins", "Medium", 15)
    resetBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        _KB_COL_RESET_BG.a   = hov and 220 or 110
        _KB_COL_RESET_BORD.a = hov and 220 or 120
        RNDX.Draw(R:Y(9), 0, 0, w, h, _KB_COL_RESET_BG)
        RNDX.DrawOutlined(R:Y(9), 0, 0, w, h, _KB_COL_RESET_BORD, 1)
        draw.SimpleText("↺  Par défaut", _resetBtnFont, w * 0.5, h * 0.5, _KB_COL_RESET_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    resetBtn.DoClick = function()
        if _captureId then return end
        Binds.ResetUserBinds()
        -- Rouvre le menu pour rafraîchir l'affichage des touches
        Binds.OpenBindMenu()
    end

    -- ── Zone scrollable ────────────────────────────────────────────────────────
    local scroll = vgui.Create("DScrollPanel", fr)
    scroll:SetPos(R:X(20), R:Y(98))
    scroll:SetSize(FW - R:X(40), FH - R:Y(164))
    scroll.Paint = function() end

    local vbar = scroll:GetVBar()
    vbar:SetWide(R:X(4))
    function vbar:Paint(w, h)
        draw.RoundedBox(w, w / 2, 0, w, h, _KB_COL_SBAR_BG)
    end
    function vbar.btnUp:Paint()   end
    function vbar.btnDown:Paint() end
    function vbar.btnGrip:Paint(w, h)
        draw.RoundedBox(w, w / 2, 0, w, h, _KB_COL_SBAR_GRIP)
    end

    -- ── Construction des lignes (bind rows + section headers) ─────────────────
    local ROW_H   = R:Y(72)
    local ROW_GAP = R:Y(8)
    local SEC_H   = R:Y(46)   -- hauteur d'un séparateur de section
    local SEC_GAP = R:Y(6)
    local ROW_W   = FW - R:X(60)   -- largeur disponible dans le scroll (hors scrollbar)
    local curY    = R:Y(4)

    for _, def in ipairs(Binds.CustomizableDefs) do

        if def.isSection then
            -- ── Séparateur de section ──────────────────────────────────────────
            local secLabel = def.label
            local sec = vgui.Create("DPanel", scroll)
            sec:SetPos(0, curY)
            sec:SetSize(ROW_W, SEC_H)
            local _secFont = Font:GetNamed("Poppins", "Bold", 18)
            sec.Paint = function(s, w, h)
                local tw = VERSE.GetTextSize(secLabel, _secFont)
                surface.SetDrawColor(138, 80, 255, 70)
                surface.DrawRect(0, h * 0.5, R:X(16), 1)
                draw.SimpleText(secLabel, _secFont,
                    R:X(24), h * 0.5, _KB_COL_ROW_LBL, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local lx = R:X(24) + tw + R:X(10)
                surface.SetDrawColor(138, 80, 255, 70)
                surface.DrawRect(lx, h * 0.5, w - lx, 1)
            end
            curY = curY + SEC_H + SEC_GAP

        else
            -- ── Ligne de bind ──────────────────────────────────────────────────
            local row = vgui.Create("DPanel", scroll)
            row:SetPos(0, curY)
            row:SetSize(ROW_W, ROW_H)

            local _rowLabelFont   = Font:GetNamed("Poppins", "SemiBold", 19)
            local _rowCapHintFont = Font:GetNamed("Poppins", "Italic",   14)
            local _rowKeyFont     = Font:GetNamed("Poppins", "Bold",     17)
            row.Paint = function(s, w, h)
                local capturing = (_captureId == def.id)
                RNDX.Draw(R:Y(12), 0, 0, w, h, capturing and _KB_COL_ROW_CAP_BG or _KB_COL_ROW_NORM_BG)
                if capturing then
                    RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, _KB_COL_ROW_CAP_OUT, 2)
                end
                draw.SimpleText(def.label, _rowLabelFont, R:X(18), h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                if capturing then
                    draw.SimpleText("Appuyez sur une touche…  (Échap pour annuler)",
                        _rowCapHintFont, w - R:X(18), h * 0.5, _KB_COL_ROW_KEY_TXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                else
                    local keyName = keyDisplayName(Binds.GetKeyForCmd(def.cmd))
                    local pillW   = R:X(96)
                    local pillH   = R:Y(36)
                    local pillX   = w - R:X(28) - R:X(118) - pillW
                    local pillY   = (h - pillH) * 0.5
                    RNDX.Draw(R:Y(9), pillX, pillY, pillW, pillH, _KB_COL_PILL_BG)
                    RNDX.DrawOutlined(R:Y(9), pillX, pillY, pillW, pillH, _KB_COL_PILL_OUT, 1)
                    draw.SimpleText(keyName, _rowKeyFont, pillX + pillW * 0.5, pillY + pillH * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            -- Bouton Modifier
            local modW = R:X(108)
            local modH = R:Y(36)
            local modBtn = vgui.Create("DButton", row)
            modBtn:SetSize(modW, modH)
            modBtn:SetPos(ROW_W - R:X(18) - modW, (ROW_H - modH) * 0.5)
            modBtn:SetText("")
            local _modBtnFont = Font:GetNamed("Poppins", "Medium", 14)
            modBtn.Paint = function(s, w, h)
                if _captureId == def.id then return end
                local hov = s:IsHovered()
                _KB_COL_EDIT_BG.a  = hov and 220 or 110
                _KB_COL_EDIT_OUT.a = hov and 210 or 80
                RNDX.Draw(R:Y(9), 0, 0, w, h, _KB_COL_EDIT_BG)
                RNDX.DrawOutlined(R:Y(9), 0, 0, w, h, _KB_COL_EDIT_OUT, 1)
                draw.SimpleText("Modifier",
                    _modBtnFont,
                    w * 0.5, h * 0.5, _KB_COL_EDIT_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            modBtn.DoClick = function()
                if _captureId then return end
                _captureId = def.id
            end

            curY = curY + ROW_H + ROW_GAP
        end
    end

    -- ── Capture clavier (Think) ────────────────────────────────────────────────
    local HOOK_ID = "VERSE::BindMenu::KeyCapture"
    local _prevDn = {}

    hook.Add("Think", HOOK_ID, function()
        if not IsValid(fr) then
            hook.Remove("Think", HOOK_ID)
            _captureId = nil
            return
        end
        if not _captureId then
            table.Empty(_prevDn)
            return
        end
        for k = 1, 106 do
            local dn = input.IsKeyDown(k)
            if dn and not _prevDn[k] then
                if k == KEY_ESCAPE then
                    _captureId = nil
                else
                    Binds.ApplyUserBind(_captureId, k)
                    _captureId = nil
                end
                table.Empty(_prevDn)
                return
            end
            _prevDn[k] = dn
        end
    end)

    fr.OnRemove = function()
        hook.Remove("Think", HOOK_ID)
        _captureId = nil
        if _bindFrame == fr then _bindFrame = nil end
    end
end