local Animations = VERSE.Animations
local R = VERSE.Responsive
local Fonts = VERSE.Fonts
local Materials = VERSE.Materials
local MV = VERSE.ModelView
Animations.ClientSlots = Animations.ClientSlots or {}
Animations.Catalog = Animations.Catalog or {}
Animations.CatalogByName = Animations.CatalogByName or {}
local SLOT_COUNT = Animations.GetSlotCount()
local COL_BG = Color(12, 9, 30, 242)
local COL_BG_INNER = Color(20, 15, 52, 252)
local _AN_COL_COMBO_OPT_SEL    = Color(232, 232, 245, 58)
local _AN_COL_COMBO_OPT_HOV    = Color(255, 255, 255, 14)
local _AN_COL_COMBO_OPT_NONE   = Color(0,   0,   0,  0)
local _AN_COL_BACKDROP_DIAMOND = Color(255, 255, 255, 0)
local _AN_COL_CLOSE_BTN_FILL   = Color(55,  55,  58,  230)
local _AN_COL_MENU_BG          = Color(10,  10,  21,  242)
local _AN_COL_WHEEL_BG         = Color(0,   0,   0,   0)
local _AN_COL_HINT_BG          = Color(10,  9,   18,  220)
local COL_PANEL = Color(58, 49, 96, 188)
local COL_PANEL_HOVER = Color(76, 63, 127, 220)
local COL_SLOT = Color(83, 66, 145, 208)
local COL_SLOT_HOVER = Color(112, 86, 196, 235)
local COL_SLOT_EMPTY = Color(43, 35, 74, 190)
local COL_ACCENT = Color(151, 112, 246)
local COL_ACCENT_SOFT = Color(119, 90, 198)
local COL_TEXT = Color(248, 247, 252)
local COL_MUTED = Color(169, 162, 193)
local COL_BORDER = Color(96, 104, 92, 125)
local COL_WARNING = Color(230, 164, 94)
local COL_SHADOW = Color(0, 0, 0, 135)
local MAT_FLAGS = "smooth noclamp"
local MAT_ICON_FLAGS = "smooth"
local COMBO_UNASSIGNED = "__VERSE_ANIMATION_UNASSIGNED__"
local MAT_ANIM_SETTINGS_BG = "animations_settings_bg"
local MAT_ANIM_SETTINGS_ICON = "animations_settings_icon"
local MAT_WHEEL_WARNING = "animations_wheel_warning"
local SETTINGS_FRAME_W = 621
local SETTINGS_FRAME_H = 797
local SETTINGS_SLOT_FIELD_W = 353
local SETTINGS_SLOT_FIELD_H = 57
local SETTINGS_SLOT_GAP = 15
local SETTINGS_INDEX_W = 25
local SETTINGS_INDEX_H = 30
local SETTINGS_INDEX_GAP = 20
local SETTINGS_TITLE_Y = 84
local SETTINGS_LIST_Y = 170
local SETTINGS_SIDE_MARGIN = 22
local function registerMaterialAliases()
    Materials:SetAlias(MAT_ANIM_SETTINGS_BG, "verse/animation_menu/settings_background")
    Materials:SetAlias(MAT_ANIM_SETTINGS_ICON, "verse/animation_menu/settings_icon")
    Materials:SetAlias(MAT_WHEEL_WARNING, "icon16/error")
end

local function precacheMaterials()
    Materials:Precache({{MAT_ANIM_SETTINGS_BG, MAT_FLAGS}, {MAT_ANIM_SETTINGS_ICON, MAT_FLAGS}, {MAT_WHEEL_WARNING, MAT_ICON_FLAGS},})
end

local function font(variant, size)
    return Fonts:GetNamed("Poppins", variant, size)
end

local function alphaColor(col, alpha)
    return Color(col.r, col.g, col.b, math.Clamp(alpha or col.a or 255, 0, 255))
end

local function blendColor(a, b, t)
    t = math.Clamp(tonumber(t) or 0, 0, 1)
    return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a or 255, b.a or 255))
end

local function trimText(text)
    text = tostring(text or "")
    text = text:gsub("[%c]+", " ")
    text = string.Trim(text)
    return text
end

local function notify(text, notifyType, duration)
    local ply = LocalPlayer()
    if IsValid(ply) and ply.Notify then ply:Notify(text, notifyType or NOTIFY_HINT, duration or 4) end
end

local function splitTokens(text)
    local out = {}
    for token in string.gmatch(string.lower(trimText(text)), "%S+") do
        out[#out + 1] = token
    end
    return out
end

local function drawChevronDown(x, y, size, col)
    size = math.max(size or 10, 4)
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    draw.NoTexture()
    surface.DrawPoly({
        {
            x = x - size,
            y = y - size * 0.35
        },
        {
            x = x + size,
            y = y - size * 0.35
        },
        {
            x = x,
            y = y + size * 0.45
        },
    })
end

local function drawPlusCentered(x, y, size, thickness, col)
    size = math.max(math.floor(tonumber(size) or 0), 8)
    thickness = math.max(math.floor(tonumber(thickness) or 0), 2)
    col = col or color_white
    local halfSize = math.floor(size * 0.5)
    local halfThick = math.floor(thickness * 0.5)
    local drawX = math.floor(x)
    local drawY = math.floor(y)
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    surface.DrawRect(drawX - halfThick, drawY - halfSize, thickness, size)
    surface.DrawRect(drawX - halfSize, drawY - halfThick, size, thickness)
end

local function drawMaterialRect(matOrPath, x, y, w, h, col, flags)
    if not matOrPath then return end
    Materials:Draw(col or color_white, matOrPath, x, y, w, h, flags)
end

local function drawBackdrop(x, y, w, h, radius)
    radius = radius or R:RS(28)
    RNDX().Rect(x, y, w, h):Rad(radius):Color(COL_SHADOW):Shadow(11, 28):Draw()
    RNDX().Rect(x, y, w, h):Rad(radius):Color(COL_BG):Draw()
    RNDX().Rect(x + R:RS(8), y + R:RS(8), w - R:RS(16), h - R:RS(16)):Rad(math.max(radius - R:RS(8), 12)):Color(COL_BG_INNER):Draw()
    local step = R:RS(154)
    local diamond = R:RS(84)
    for row = -1, math.ceil(h / step) + 1 do
        for col = -1, math.ceil(w / step) + 1 do
            local rx = x + col * step + ((row % 2 == 0) and step * 0.2 or -step * 0.2)
            local ry = y + row * step - step * 0.1
            local alpha = ((row + col) % 2 == 0) and 16 or 8
            _AN_COL_BACKDROP_DIAMOND.a = alpha
            RNDX().Rect(rx, ry, diamond, diamond):Rad(R:RS(12)):Rotation(45):Color(_AN_COL_BACKDROP_DIAMOND):Draw()
        end
    end

    RNDX().Rect(x + R:RS(20), y + R:RS(20), w - R:RS(40), h - R:RS(40)):Rad(math.max(radius - R:RS(16), 10)):Outline(2):Color(COL_BORDER):Draw()
end

local function buildCatalog()
    local out = {}
    for _, entry in ipairs(Animations.GetConfiguredAnimations() or {}) do
        out[#out + 1] = table.Copy(entry)
    end
    return out
end

function Animations.LoadSlots()
    local dataPath = Animations.Config.DataPath
    local raw = file.Read(dataPath, "DATA")
    local decoded = raw and util.JSONToTable(raw) or nil
    local stored = decoded
    if istable(decoded) and istable(decoded.slots) then stored = decoded.slots end
    for i = 1, SLOT_COUNT do
        local sequence = istable(stored) and Animations.SanitizeSequenceName(stored[i]) or nil
        Animations.ClientSlots[i] = sequence or false
    end

    Animations._slotsLoaded = true
end

function Animations.SaveSlots()
    if not Animations._slotsLoaded then return end
    local out = {}
    for i = 1, SLOT_COUNT do
        out[i] = Animations.ClientSlots[i] or ""
    end

    file.CreateDir("verse")
    file.Write(Animations.Config.DataPath, util.TableToJSON({
        slots = out,
    }, true))
end

function Animations.RefreshCatalog(force)
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    local model = ply:GetModel() or ""
    if not force and Animations._catalogModel == model and istable(Animations.Catalog) and #Animations.Catalog > 0 then return #Animations.Catalog > 0 end
    Animations.Catalog = buildCatalog()
    Animations.CatalogByName = {}
    for _, entry in ipairs(Animations.Catalog) do
        Animations.CatalogByName[entry.key] = entry
    end

    Animations._catalogModel = model
    Animations._catalogAt = CurTime()
    if not Animations._slotsLoaded then Animations.LoadSlots() end
    Animations.EnsureDefaultSlots()
    return #Animations.Catalog > 0
end

function Animations.GetEntry(sequence)
    sequence = Animations.SanitizeSequenceName(sequence)
    if not sequence then return nil end
    return Animations.CatalogByName[string.lower(sequence)]
end

function Animations.GetDefaultSequences()
    local defaults = {}
    local seen = {}
    for _, entry in ipairs(Animations.Catalog or {}) do
        if not entry.candidate then continue end
        defaults[#defaults + 1] = entry.name
        seen[entry.key] = true
        if #defaults >= SLOT_COUNT then return defaults end
    end

    for _, entry in ipairs(Animations.Catalog or {}) do
        if seen[entry.key] then continue end
        defaults[#defaults + 1] = entry.name
        if #defaults >= SLOT_COUNT then break end
    end
    return defaults
end

function Animations.EnsureDefaultSlots()
    if not Animations._slotsLoaded then return end
    if not istable(Animations.Catalog) or #Animations.Catalog == 0 then return end
    local allEmpty = true
    for i = 1, SLOT_COUNT do
        if Animations.ClientSlots[i] then
            allEmpty = false
            break
        end
    end

    if not allEmpty then return end
    local defaults = Animations.GetDefaultSequences()
    for i = 1, SLOT_COUNT do
        Animations.ClientSlots[i] = defaults[i] or false
    end

    Animations.SaveSlots()
end

function Animations.GetSlotSequence(slot)
    slot = math.Clamp(math.floor(tonumber(slot) or 1), 1, SLOT_COUNT)
    return Animations.ClientSlots[slot] or false
end

function Animations.SetSlotSequence(slot, sequence)
    slot = math.Clamp(math.floor(tonumber(slot) or 1), 1, SLOT_COUNT)
    sequence = Animations.SanitizeSequenceName(sequence)
    Animations.ClientSlots[slot] = sequence or false
    Animations.SaveSlots()
end

function Animations.GetSlotInfo(slot)
    local sequence = Animations.GetSlotSequence(slot)
    if not sequence then
        return {
            assigned = false,
            sequence = false,
            label = "Unassigned",
            missing = false,
        }
    end

    local entry = Animations.GetEntry(sequence)
    local available = false
    local ply = LocalPlayer()
    if IsValid(ply) and ply.LookupSequence then available = (ply:LookupSequence(sequence) or -1) >= 0 end
    return {
        assigned = true,
        sequence = sequence,
        label = entry and entry.label or Animations.FormatLabel(sequence),
        missing = not available,
        entry = entry,
        configured = entry ~= nil,
        loop = entry and entry.loop == true or false,
        rate = entry and entry.rate or 1,
    }
end

function Animations.GetActiveSlot()
    local anims = VERSE.Anims
    if not anims or not anims.GetSequenceState then return nil end
    local state = anims.GetSequenceState(LocalPlayer())
    if not state or not state.seqName then return nil end
    local target = string.lower(state.seqName)
    for i = 1, SLOT_COUNT do
        local sequence = Animations.ClientSlots[i]
        if sequence and string.lower(sequence) == target then return i end
    end
end

function Animations.GetFilteredCatalog(query)
    local tokens = splitTokens(query)
    if #tokens == 0 then return Animations.Catalog end
    local results = {}
    for _, entry in ipairs(Animations.Catalog or {}) do
        local haystack = string.lower((entry.label or "") .. " " .. (entry.sequence or entry.name or ""))
        local ok = true
        for _, token in ipairs(tokens) do
            if not string.find(haystack, token, 1, true) then
                ok = false
                break
            end
        end

        if ok then results[#results + 1] = entry end
    end
    return results
end

function Animations.RequestPlay(sequence)
    sequence = Animations.SanitizeSequenceName(sequence)
    if not sequence then return false end
    netstream.Start(Animations.Net.RequestPlay, sequence)
    return true
end

function Animations.RequestStop()
    netstream.Start(Animations.Net.RequestStop)
end

function Animations.PlaySlot(slot)
    local info = Animations.GetSlotInfo(slot)
    if not info.assigned then
        notify("This slot is empty. Assign an animation first.", NOTIFY_HINT, 4)
        return false
    end

    if info.configured == false then
        notify("This animation is no longer present in Animations.Config.AvailableAnimations.", NOTIFY_ERROR, 4)
        return false
    end

    if info.missing then
        notify("This animation is not available for the current model.", NOTIFY_ERROR, 4)
        return false
    end
    return Animations.RequestPlay(info.sequence)
end

function Animations.ClosePicker()
    local fr = Animations._pickerFrame
    if not IsValid(fr) then
        Animations._pickerFrame = nil
        return
    end

    fr:SetVisible(false)
    fr:SetMouseInputEnabled(false)
    fr:SetKeyboardInputEnabled(false)
    if IsValid(Animations._settingsFrame) then
        Animations._settingsFrame:MakePopup()
        Animations._settingsFrame:RequestFocus()
    end
end

function Animations.CloseSettings()
    Animations.ClosePicker()
    if IsValid(Animations._settingsFrame) then Animations._settingsFrame:Close() end
    Animations._settingsFrame = nil
end

local function createCloseButton(parent)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetSize(R:RX(56), R:RY(56))
    btn.Paint = function(s, w, h)
        local hovered = s:IsHovered() and 1 or 0
        local fill = blendColor(_AN_COL_CLOSE_BTN_FILL, COL_ACCENT_SOFT, hovered * 0.35)
        RNDX().Rect(0, 0, w, h):Rad(h * 0.5):Color(fill):Draw()
        draw.SimpleText("x", font("Bold", 28), w * 0.5, h * 0.5 - 1, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

local function styleAnimationCombo(combo)
    combo:SetFonts(font("SemiBold", 20), font("Regular", 18), font("Italic", 20))
    combo.btn.Paint = function(s, w, h)
        local hovered = (s:IsHovered() or combo.opened) and 1 or 0
        combo._hoverFrac = Lerp(FrameTime() * 14, combo._hoverFrac or 0, hovered)
        local info = Animations.GetSlotInfo(combo._slot or 1)
        local fill = info.assigned and COL_PANEL or COL_SLOT_EMPTY
        if info.missing then
            fill = blendColor(fill, COL_WARNING, 0.18)
        elseif combo._hoverFrac > 0 then
            fill = blendColor(fill, COL_PANEL_HOVER, combo._hoverFrac * 0.75)
        end

        RNDX().Rect(0, 0, w, h):Rad(R:RS(10)):Color(fill):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:RS(10)):Outline(2):Color(info.missing and alphaColor(COL_WARNING, 180) or alphaColor(COL_BORDER, 120)):Draw()
        local hasSelection = combo.selected ~= nil and combo.selected ~= ""
        local text = hasSelection and combo.selected or (combo.placeholder or "")
        local textFont = hasSelection and font("SemiBold", 20) or font("Italic", 20)
        local textColor = info.missing and COL_WARNING or (hasSelection and COL_TEXT or COL_MUTED)
        draw.SimpleText(text, textFont, R:RX(18), h * 0.5, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        drawChevronDown(w - R:RX(18), h * 0.5 + 1, R:RS(6), alphaColor(COL_TEXT, 220))
    end

    combo.OpenMenu = function(self)
        if IsValid(self.menu) then self.menu:CloseMenu() end
        local itemTall = R:RY(40)
        local itemGap = R:RY(4)
        local menuPad = R:RX(4)
        local visibleCount = math.min(10, math.max(#(self.choices or {}), 1))
        local x, y = self:LocalToScreen(0, self:GetTall() + R:RY(8))
        local menu = vgui.Create("MantleDermaMenu")
        menu:SetParent(nil)
        menu:SetPos(x, y)
        menu._disableBlur = true
        menu.Paint = function(_, w, h)
            RNDX().Rect(0, 0, w, h):Rad(R:RS(10)):Color(_AN_COL_MENU_BG):Draw()
            RNDX().Rect(0, 0, w, h):Rad(R:RS(10)):Outline(1):Color(alphaColor(COL_BORDER, 145)):Draw()
        end

        local selectedData = self:GetSelectedData()
        local function isSelected(choiceData)
            if choiceData == COMBO_UNASSIGNED then return selectedData == nil and (self:GetValue() == nil or self:GetValue() == "") end
            return selectedData == choiceData
        end

        local menuW = self:GetWide()
        local scroll = vgui.Create("MantleScrollPanel", menu)
        scroll:SetPos(menuPad, menuPad)
        scroll:SetSize(menuW - menuPad * 2, (itemTall * visibleCount) + (itemGap * math.max(visibleCount - 1, 0)))
        scroll:DisableVBarPadding()
        local canvas = scroll:GetCanvas()
        local rowY = 0

        for index, choice in ipairs(self.choices or {}) do
            local function onClick()
                if choice.data == COMBO_UNASSIGNED then
                    self.selected = nil
                    self.selectedData = nil
                    if IsValid(menu) then menu:CloseMenu() end
                    if self.OnSelect then self.OnSelect(index, choice.text, nil) end
                    Mantle.func.sound()
                    return
                end

                self.selected = choice.text
                self.selectedData = choice.data
                if IsValid(menu) then menu:CloseMenu() end
                if self.OnSelect then self.OnSelect(index, choice.text, choice.data) end
                Mantle.func.sound()
            end

            local opt = vgui.Create("DButton", canvas)
            opt:SetText("")
            opt:SetPos(0, rowY)
            opt:SetSize(scroll:GetWide() - R:RX(10), itemTall)
            opt.DoClick = onClick
            opt.Paint = function(pnl, w, h)
                local hovered = pnl:IsHovered() and 1 or 0
                local selected = isSelected(choice.data)
                local fill = selected and _AN_COL_COMBO_OPT_SEL or _AN_COL_COMBO_OPT_NONE
                if hovered > 0 and not selected then fill = _AN_COL_COMBO_OPT_HOV end
                if fill.a > 0 then RNDX().Rect(0, 0, w, h):Rad(R:RS(8)):Color(fill):Draw() end
                draw.SimpleText(choice.text, font("Regular", 18), R:RX(16), h * 0.5, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            rowY = rowY + itemTall + itemGap
        end

        canvas:SetTall(math.max(rowY - itemGap, itemTall))
        scroll:InvalidateLayout(true)
        menu:SetSize(menuW, scroll:GetTall() + menuPad * 2)
        Mantle.func.ClampMenuPosition(menu)
        menu._targetX, menu._targetY = menu:GetPos()
        menu:MakePopup()
        menu:SetKeyboardInputEnabled(false)
        self.menu = menu
        self.opened = true
        menu.OnRemove = function() if IsValid(self) then self.opened = false end end
    end
end

local function populateAnimationCombo(combo, slot)
    combo:CloseMenu()
    combo.choices = {}
    combo.selected = nil
    combo.selectedData = nil
    combo._slot = slot
    combo:SetPlaceholder("Animation " .. tostring(slot))
    combo:AddChoice("Unassigned", COMBO_UNASSIGNED)
    for _, entry in ipairs(Animations.Catalog or {}) do
        combo:AddChoice(entry.label, entry.sequence or entry.name)
    end

    local info = Animations.GetSlotInfo(slot)
    if info.assigned then combo:SetSelected(info.label, info.sequence) end
end

local function createPickerResultButton(parent, scrollW)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetSize(scrollW - R:RX(10), R:RY(58))
    btn:SetVisible(false)
    btn.DoClick = function(s)
        local picker = s._pickerFrame
        if not IsValid(picker) then return end
        local targetSlot = math.Clamp(math.floor(tonumber(picker._slot) or 1), 1, SLOT_COUNT)
        if s._action == "clear" then
            Animations.SetSlotSequence(targetSlot, nil)
            Animations.ClosePicker()
            return
        end

        if s._action == "assign" and s._sequence then
            Animations.SetSlotSequence(targetSlot, s._sequence)
            Animations.ClosePicker()
        end
    end

    btn.Paint = function(s, w, h)
        local hovered = s:IsHovered() and 1 or 0
        local selected = s._selected == true
        local fill = COL_PANEL
        if selected then
            fill = blendColor(COL_PANEL, COL_ACCENT, 0.42)
        elseif hovered > 0 then
            fill = blendColor(COL_PANEL, COL_PANEL_HOVER, hovered)
        end

        RNDX().Rect(0, 0, w, h):Rad(R:RS(12)):Color(fill):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:RS(12)):Outline(2):Color(selected and alphaColor(COL_ACCENT, 200) or alphaColor(COL_BORDER, 120)):Draw()
        draw.SimpleText(s._title or "", font("SemiBold", 20), R:RX(18), h * 0.5 - R:RY(8), COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if s._subtitle and s._subtitle ~= "" then draw.SimpleText(s._subtitle, font("Regular", 14), R:RX(18), h * 0.5 + R:RY(12), COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    return btn
end

local function ensurePickerButtons(fr, count)
    fr._resultButtons = fr._resultButtons or {}
    for i = #fr._resultButtons + 1, count do
        fr._resultButtons[i] = createPickerResultButton(fr._scroll:GetCanvas(), fr._scrollW)
        fr._resultButtons[i]._pickerFrame = fr
    end
    return fr._resultButtons
end

local function configurePickerButton(fr, index, y, title, subtitle, selected, action, sequence)
    local btn = ensurePickerButtons(fr, index)[index]
    btn:SetPos(0, y)
    btn:SetSize(fr._scrollW - R:RX(10), R:RY(58))
    btn:SetVisible(true)
    btn._title = title
    btn._subtitle = subtitle
    btn._selected = selected == true
    btn._action = action
    btn._sequence = sequence
end

local function refreshPickerSelection(fr)
    local current = Animations.GetSlotSequence(fr._slot)
    for _, btn in ipairs(fr._resultButtons or {}) do
        if not btn:IsVisible() then continue end
        if btn._action == "clear" then
            btn._selected = current == false
        elseif btn._action == "assign" then
            btn._selected = current == btn._sequence
        else
            btn._selected = false
        end
    end
end

local function rebuildPickerResults(fr)
    local current = Animations.GetSlotSequence(fr._slot)
    local results = Animations.GetFilteredCatalog(fr._search:GetValue())
    fr._results = results
    local rowH = R:RY(58)
    local gap = R:RY(10)
    local y = 0
    local index = 1
    configurePickerButton(fr, index, y, "Unassigned", "Clear this slot", current == false, "clear")
    y = y + rowH + gap
    index = index + 1
    if #results == 0 then
        local emptyTitle = (#(Animations.Catalog or {}) > 0) and "Nothing found" or "No animations configured"
        local emptySubtitle = (#(Animations.Catalog or {}) > 0) and "Try another search query" or "Add entries in Animations.Config.AvailableAnimations"
        configurePickerButton(fr, index, y, emptyTitle, emptySubtitle, false, "noop")
        y = y + rowH + gap
        index = index + 1
    else
        for _, entry in ipairs(results) do
            local subtitle = entry.sequence or entry.name
            configurePickerButton(fr, index, y, entry.label, subtitle, current == entry.name, "assign", entry.name)
            y = y + rowH + gap
            index = index + 1
        end
    end

    local buttons = ensurePickerButtons(fr, index - 1)
    for i = index, #buttons do
        buttons[i]:SetVisible(false)
        buttons[i]._selected = false
        buttons[i]._action = nil
        buttons[i]._sequence = nil
    end

    fr._scroll:GetCanvas():SetTall(y)
    fr._scroll:InvalidateLayout(true)
    fr._catalogModel = Animations._catalogModel
    fr._lastQuery = fr._search:GetValue()
end

local function createPickerFrame()
    local fw = math.min(R:RX(760), ScrW() - R:RX(60))
    local fh = math.min(R:RY(720), ScrH() - R:RY(60))
    local fr = vgui.Create("MantleFrame")
    fr:SetSize(fw, fh)
    fr:Center()
    fr:MakePopup()
    fr:SetDraggable(false)
    fr:LiteMode()
    fr:SetAlphaBackground(false)
    fr:DisableCloseBtn()
    fr.Paint = function() end
    local oldClose = fr.OnClose
    fr.OnClose = function(s)
        oldClose(s)
        if Animations._pickerFrame == s then Animations._pickerFrame = nil end
    end

    local body = vgui.Create("EditablePanel", fr)
    body:SetPos(0, 0)
    body:SetSize(fw, fh)
    body.Paint = function(s, w, h)
        drawBackdrop(0, 0, w, h, R:RS(26))
        draw.SimpleText("SELECT ANIMATION", font("Bold", 40), w * 0.5, R:RY(72), COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Slot " .. tostring(fr._slot or 1), font("Regular", 18), w * 0.5, R:RY(110), COL_MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local countText = string.format("%d available", #(fr._results or {}))
        draw.SimpleText(countText, font("Regular", 16), w - R:RX(44), R:RY(150), COL_MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local close = createCloseButton(body)
    close.DoClick = function() Animations.ClosePicker() end
    local search = vgui.Create("DTextEntry", body)
    search:SetPos(R:RX(42), R:RY(138))
    search:SetSize(fw - R:RX(84), R:RY(54))
    search:SetFont(font("Regular", 22))
    search:SetTextColor(COL_TEXT)
    search:SetDrawLanguageID(false)
    search.Paint = function(s, w, h)
        local focused = s:HasFocus()
        RNDX().Rect(0, 0, w, h):Rad(R:RS(14)):Color(focused and blendColor(COL_PANEL, COL_ACCENT, 0.10) or COL_PANEL):Draw()
        RNDX().Rect(0, 0, w, h):Rad(R:RS(14)):Outline(2):Color(focused and alphaColor(COL_ACCENT, 180) or alphaColor(COL_BORDER, 140)):Draw()
        s:DrawTextEntryText(COL_TEXT, COL_ACCENT, COL_TEXT)
        if s:GetValue() == "" then draw.SimpleText("Search by display name or sequence", font("Italic", 18), R:RX(18), h * 0.5, COL_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end

    local scroll = vgui.Create("MantleScrollPanel", body)
    local scrollW = fw - R:RX(84)
    scroll:SetPos(R:RX(42), R:RY(214))
    scroll:SetSize(scrollW, fh - R:RY(254))
    scroll:DisableVBarPadding()
    fr._body = body
    fr._close = close
    fr._search = search
    fr._scroll = scroll
    fr._scrollW = scrollW
    fr._resultButtons = {}
    fr.PerformLayout = function(s, w, h)
        if IsValid(body) then
            body:SetPos(0, 0)
            body:SetSize(w, h)
        end

        if IsValid(close) then close:SetPos(w - close:GetWide() - R:RX(20), R:RY(20)) end
    end

    search.OnChange = function() rebuildPickerResults(fr) end
    return fr
end

function Animations.OpenPicker(slot)
    slot = math.Clamp(math.floor(tonumber(slot) or 1), 1, SLOT_COUNT)
    Animations.RefreshCatalog(false)
    local fr = Animations._pickerFrame
    if not IsValid(fr) then
        fr = createPickerFrame()
        Animations._pickerFrame = fr
    end

    fr._slot = slot
    fr:SetVisible(true)
    fr:SetMouseInputEnabled(true)
    fr:SetKeyboardInputEnabled(true)
    fr:MakePopup()
    fr:RequestFocus()
    if fr._catalogModel ~= Animations._catalogModel or fr._lastQuery ~= (fr._search:GetValue() or "") then
        rebuildPickerResults(fr)
    else
        refreshPickerSelection(fr)
    end

    timer.Simple(0, function()
        if IsValid(fr._search) then fr._search:RequestFocus() end
        if IsValid(fr) then fr:InvalidateLayout(true) end
    end)
end

function Animations.OpenSettings()
    Animations.CloseWheel()
    Animations.RefreshCatalog(false)
    if IsValid(Animations._settingsFrame) then
        Animations._settingsFrame:MakePopup()
        Animations._settingsFrame:RequestFocus()
        Animations._settingsFrame:InvalidateLayout(true)
        return
    end

    local fw = math.min(R:RX(SETTINGS_FRAME_W), ScrW() - R:RX(40))
    local fh = math.min(R:RY(SETTINGS_FRAME_H), ScrH() - R:RY(40))
    local fr = vgui.Create("MantleFrame")
    fr:SetSize(fw, fh)
    fr:Center()
    fr:MakePopup()
    fr:SetDraggable(false)
    fr:LiteMode()
    fr:SetAlphaBackground(false)
    fr:DisableCloseBtn()
    fr.Paint = function() end
    local oldClose = fr.OnClose
    fr.OnClose = function(s)
        oldClose(s)
        if Animations._settingsFrame == s then Animations._settingsFrame = nil end
    end

    local body = vgui.Create("EditablePanel", fr)
    body:SetPos(0, 0)
    body:SetSize(fw, fh)
    body.Paint = function(s, w, h)
        drawMaterialRect(MAT_ANIM_SETTINGS_BG, 0, 0, w, h, color_white, MAT_FLAGS)
        RNDX().Rect(0, 0, w, h):Rad(R:RS(22)):Outline(2):Color(alphaColor(COL_BORDER, 116)):Draw()
        draw.SimpleText("ANIMATIONS", font("Bold", 54), w * 0.5, R:RY(SETTINGS_TITLE_Y), COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local close = createCloseButton(body)
    close.DoClick = function() fr:Close() end
    local rowFieldW = R:RX(SETTINGS_SLOT_FIELD_W)
    local rowFieldH = R:RY(SETTINGS_SLOT_FIELD_H)
    local rowGap = R:RY(SETTINGS_SLOT_GAP)
    local indexW = R:RX(SETTINGS_INDEX_W)
    local indexH = R:RY(SETTINGS_INDEX_H)
    local indexGap = R:RX(SETTINGS_INDEX_GAP)
    local rowBlockW = indexW + indexGap + rowFieldW
    local listW = rowBlockW + R:RX(12)
    local rowsTall = (rowFieldH * SLOT_COUNT) + (rowGap * math.max(SLOT_COUNT - 1, 0))
    local scroll = vgui.Create("MantleScrollPanel", body)
    scroll:SetPos(math.floor((fw - listW) * 0.5), R:RY(SETTINGS_LIST_Y))
    scroll:SetSize(listW, math.min(fh - R:RY(SETTINGS_LIST_Y) - R:RY(24), rowsTall + R:RY(8)))
    scroll:DisableVBarPadding()
    local buildRows
    buildRows = function()
        local canvas = scroll:GetCanvas()
        for _, child in ipairs(canvas:GetChildren()) do
            child:Remove()
        end

        local y = 0
        local rowH = rowFieldH
        local gap = rowGap
        for i = 1, SLOT_COUNT do
            local slotIndex = i
            local row = vgui.Create("EditablePanel", canvas)
            row:SetPos(0, y)
            row:SetSize(rowBlockW, rowH)
            local fieldX = indexW + indexGap
            local fieldW = rowFieldW
            local fieldH = rowFieldH
            row.Paint = function(s, w, h)
                local indexY = math.floor((h - indexH) * 0.5)
                RNDX().Rect(0, indexY, indexW, indexH):Rad(R:RS(6)):Color(COL_ACCENT):Draw()
                draw.SimpleText(tostring(slotIndex), font("SemiBold", 20), indexW * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            local combo = vgui.Create("MantleComboBox", row)
            combo:SetPos(fieldX, 0)
            combo:SetSize(fieldW, fieldH)
            styleAnimationCombo(combo)
            populateAnimationCombo(combo, slotIndex)
            combo.OnSelect = function(_, text, data)
                if data then
                    Animations.SetSlotSequence(slotIndex, data)
                    combo:SetSelected(text, data)
                else
                    Animations.SetSlotSequence(slotIndex, nil)
                    combo.selected = nil
                    combo.selectedData = nil
                end
            end

            y = y + rowH + gap
        end

        canvas:SetTall(y)
        scroll:InvalidateLayout(true)
    end

    buildRows()
    fr._body = body
    fr._close = close
    fr._scroll = scroll
    fr.PerformLayout = function(s, w, h)
        if IsValid(body) then
            body:SetPos(0, 0)
            body:SetSize(w, h)
        end

        if IsValid(close) then close:SetPos(w - close:GetWide() - R:RX(SETTINGS_SIDE_MARGIN), R:RY(SETTINGS_SIDE_MARGIN)) end
        if IsValid(scroll) then
            local layoutListW = rowBlockW + R:RX(12)
            local layoutListX = math.floor((w - layoutListW) * 0.5)
            local layoutListY = R:RY(SETTINGS_LIST_Y)
            local layoutListH = math.min(h - layoutListY - R:RY(24), rowsTall + R:RY(8))
            scroll:SetPos(layoutListX, layoutListY)
            scroll:SetSize(layoutListW, layoutListH)
        end
    end

    Animations._settingsFrame = fr
end

local MAT_WHEEL_GEAR = MAT_ANIM_SETTINGS_ICON
local WHEEL_ACTIVE = Color(186, 146, 255, 230)
local WHEEL_CENTER = Color(6, 4, 20, 250)
local WHEEL_CENTER_HOVER = Color(16, 12, 40, 252)

local WHEEL_DIAMETER = 640
local WHEEL_CENTER_BUTTON = 211
local WHEEL_CENTER_ICON_W = 64
local WHEEL_CENTER_ICON_H = 69
local WHEEL_SLOT_W = 220
local WHEEL_SLOT_H = 200
local WHEEL_SLOT_GAP = 5
local WHEEL_CENTER_GAP = 40
local TAU = math.pi * 2
local WHEEL_OFFSET_RAD = -math.pi * 0.5
local WHEEL_PREVIEW_PREFIX = "VERSE::Animations::WheelPreview::"
local PANEL = {}
local function getScreenCursorPos()
    local mx, my
    if input.GetCursorPos then
        mx, my = input.GetCursorPos()
    else
        mx, my = gui.MousePos()
    end

    mx = tonumber(mx) or 0
    my = tonumber(my) or 0
    return mx, my
end

local function normalizeRad(angle)
    angle = tonumber(angle) or 0
    while angle < 0 do
        angle = angle + TAU
    end

    while angle >= TAU do
        angle = angle - TAU
    end
    return angle
end

local function getWheelSectorIndex(angle)
    local rel = normalizeRad(angle - WHEEL_OFFSET_RAD)
    local per = TAU / SLOT_COUNT
    return (math.floor(rel / per) % SLOT_COUNT) + 1
end

local function getWheelSegmentRadians(slot, gapRad)
    local per = TAU / SLOT_COUNT
    local startRad = WHEEL_OFFSET_RAD + ((slot - 1) * per) + (gapRad or 0)
    local endRad = WHEEL_OFFSET_RAD + (slot * per) - (gapRad or 0)
    return startRad, endRad
end

local function getWheelMidpoint(slot, innerRadius, outerRadius, frac)
    local per = TAU / SLOT_COUNT
    local mid = WHEEL_OFFSET_RAD + ((slot - 0.5) * per)
    local dist = innerRadius + (outerRadius - innerRadius) * (frac or 0.56)
    return mid, dist
end

local function buildAnnularSegmentVertices(cx, cy, innerRadius, outerRadius, startRad, endRad)
    local arcLength = math.max((endRad - startRad) * outerRadius, 1)
    local steps = math.max(10, math.ceil(arcLength / 12))
    local vertices = {}
    for i = 0, steps do
        local frac = i / steps
        local ang = startRad + ((endRad - startRad) * frac)
        vertices[#vertices + 1] = {
            x = cx + math.cos(ang) * outerRadius,
            y = cy + math.sin(ang) * outerRadius,
        }
    end

    for i = steps, 0, -1 do
        local frac = i / steps
        local ang = startRad + ((endRad - startRad) * frac)
        vertices[#vertices + 1] = {
            x = cx + math.cos(ang) * innerRadius,
            y = cy + math.sin(ang) * innerRadius,
        }
    end
    return vertices
end

local function drawPolygon(vertices, col)
    if not istable(vertices) or #vertices < 3 then return end
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    draw.NoTexture()
    surface.DrawPoly(vertices)
end

local function drawPolygonOutline(vertices, col)
    if not istable(vertices) or #vertices < 2 then return end
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    for i = 1, #vertices do
        local a = vertices[i]
        local b = vertices[(i % #vertices) + 1]
        surface.DrawLine(a.x, a.y, b.x, b.y)
    end
end

local function drawMaterialCentered(matOrPath, x, y, w, h, col, rot, flags)
    if not matOrPath then return end
    if rot and rot ~= 0 then
        Materials:DrawRotated(col or color_white, matOrPath, x, y, w, h, rot, flags)
        return
    end

    Materials:Draw(col or color_white, matOrPath, x - w * 0.5, y - h * 0.5, w, h, flags)
end

local function getWheelIcon(info)
    if info.missing then return MAT_WHEEL_WARNING end
    return false
end

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetDrawOnTop(true)
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self.openTime = SysTime()
    self.alphaFrac = 0
    self.wheelDiameter = math.min(R:RX(WHEEL_DIAMETER), R:RY(WHEEL_DIAMETER))
    self.centerDiameter = math.min(R:RX(WHEEL_CENTER_BUTTON), R:RY(WHEEL_CENTER_BUTTON))
    self.centerRadius = self.centerDiameter * 0.5
    self.centerGap = math.min(R:RX(WHEEL_CENTER_GAP), R:RY(WHEEL_CENTER_GAP))
    self.slotWidth = math.min(R:RX(WHEEL_SLOT_W), R:RY(WHEEL_SLOT_W))
    self.slotDepth = math.min(R:RX(WHEEL_SLOT_H), R:RY(WHEEL_SLOT_H))
    self.ringInnerRadius = self.centerRadius + self.centerGap
    self.outerRadius = math.min(self.wheelDiameter * 0.5, self.ringInnerRadius + self.slotDepth)
    self.segmentGapRad = (math.min(R:RX(WHEEL_SLOT_GAP), R:RY(WHEEL_SLOT_GAP)) / math.max(self.outerRadius, 1)) * 0.5
    self.outerGrace = R:RS(22)
    self.hoveredSlot = nil
    self.hoverIntent = "close"
    self._slotHoverFrac = {}
    self._settingsHoverFrac = 0
    self._keyCooldown = {}
    self._armed = false
    self._previewIds = {}
    self._previewNonce = tostring(math.floor(SysTime() * 1000000))
    self._restoreCursorX, self._restoreCursorY = getScreenCursorPos()
    if self._restoreCursorX <= 0 and self._restoreCursorY <= 0 then self._restoreCursorX, self._restoreCursorY = self:GetCenter() end
    timer.Simple(0, function()
        if not (IsValid(self) and input.SetCursorPos) then return end
        local cx, cy = self:GetCenter()
        input.SetCursorPos(cx, cy)
    end)

    timer.Simple(0, function() if IsValid(self) then self:BuildSlotPreviews() end end)
end

function PANEL:GetCenter()
    return ScrW() * 0.5, ScrH() * 0.5
end

function PANEL:GetCursorMetrics()
    local mx, my = getScreenCursorPos()
    if mx <= 0 and my <= 0 then mx, my = self:CursorPos() end
    local cx, cy = self:GetCenter()
    local dx, dy = mx - cx, my - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)
    if angle < 0 then angle = angle + TAU end
    return mx, my, cx, cy, dx, dy, dist, angle
end

function PANEL:ResolveHoverIntent()
    local _, _, _, _, _, _, dist, angle = self:GetCursorMetrics()
    if dist <= self.centerRadius then return "settings", nil, dist end
    if dist < self.ringInnerRadius then return "close", nil, dist end
    if dist <= (self.outerRadius + self.outerGrace) then return "slot", getWheelSectorIndex(angle), dist end
    return "close", nil, dist
end

function PANEL:GetSelectionIntent()
    local intent, slot = self:ResolveHoverIntent()
    if intent == "slot" then return intent, slot end
    if not self._armed then return "close" end
    return intent, slot
end

function PANEL:OpenSettings()
    self:Remove()
    timer.Simple(0, function() Animations.OpenSettings() end)
end

function PANEL:GetPreviewId(slot)
    slot = math.Clamp(math.floor(tonumber(slot) or 1), 1, SLOT_COUNT)
    self._previewIds[slot] = self._previewIds[slot] or (WHEEL_PREVIEW_PREFIX .. self._previewNonce .. "::" .. tostring(slot))
    return self._previewIds[slot]
end

function PANEL:ConfigureSlotPreview(slot)
    if not MV then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local id = self:GetPreviewId(slot)
    local info = Animations.GetSlotInfo(slot)
    if not info.assigned then
        MV.Remove(id)
        self._previewIds[slot] = nil
        return
    end

    local previewSeq = (not info.missing and info.sequence) or "idle_all_01"
    local previewAng = Angle(0, 160, 0)
    local previewLoop = info.entry and info.entry.loop == true or false
    local previewRate = (info.entry and info.entry.rate) or 1
    MV.Ensure(id, {
        lighting = true,
        spin = 0,
    })

    MV.SetCircle(id, true)
    MV.SetFromPlayer(id, ply)
    MV.SetHeadMode(id, false)
    MV.SetAnchorOrigin(id, true)
    MV.SetAngles(id, previewAng)
    MV.SetFOV(id, 24)
    MV.SetAnimation(id, previewSeq, {
        rate = previewRate,
        loop = previewLoop,
    })

    MV.FitFullBody(id, {
        padding = 1.18,
        fov = 24,
        ang = previewAng,
    })

    MV.ClearBackground(id)
end

function PANEL:BuildSlotPreviews()
    if not MV then return end
    for slot = 1, SLOT_COUNT do
        self:ConfigureSlotPreview(slot)
    end
end

function PANEL:DrawSlotPreview(slot, x, y, size)
    if not MV then return end
    local info = Animations.GetSlotInfo(slot)
    if not info.assigned then return end
    local id = self:GetPreviewId(slot)
    MV.SetCircleRect(id, math.floor(x - size * 0.5), math.floor(y - size * 0.5), math.floor(size))
    MV.Draw(id)
end

function PANEL:ClearSlotPreviews()
    if not MV then return end
    for _, id in pairs(self._previewIds or {}) do
        MV.Remove(id)
    end

    self._previewIds = {}
end

function PANEL:SelectSlot(slot)
    if not slot then return end
    if not Animations.PlaySlot(slot) then
        local info = Animations.GetSlotInfo(slot)
        if not info.assigned then self:OpenSettings() end
        return
    end

    self:Remove()
end

function PANEL:CommitSelection()
    local intent, slot = self:GetSelectionIntent()
    if intent == "settings" then
        self:OpenSettings()
        return true
    end

    if intent == "slot" and slot then
        self:SelectSlot(slot)
        return true
    end

    self:Remove()
    return false
end

function PANEL:Think()
    self.alphaFrac = math.min(1, (SysTime() - self.openTime) / 0.16)
    self.hoverIntent, self.hoveredSlot = self:ResolveHoverIntent()
    local _, _, _, _, _, _, dist = self:GetCursorMetrics()
    if dist > (self.centerRadius + R:RS(18)) then self._armed = true end
    for i = 1, SLOT_COUNT do
        local target = (self.hoverIntent == "slot" and self.hoveredSlot == i) and 1 or 0
        self._slotHoverFrac[i] = Lerp(FrameTime() * 14, self._slotHoverFrac[i] or 0, target)
    end

    self._settingsHoverFrac = Lerp(FrameTime() * 14, self._settingsHoverFrac or 0, self.hoverIntent == "settings" and 1 or 0)
    if gui.IsGameUIVisible() then
        self:Remove()
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        self:Remove()
        return
    end

    if input.IsKeyDown(KEY_ESCAPE) then
        self:Remove()
        return
    end

    for i = 1, SLOT_COUNT do
        local key = KEY_1 + (i - 1)
        if input.IsKeyDown(key) then
            local nextAt = self._keyCooldown[key] or 0
            if CurTime() >= nextAt then
                self._keyCooldown[key] = CurTime() + 0.2
                self:SelectSlot(i)
            end
        end
    end
end

function PANEL:OnMousePressed(code)
    if code == MOUSE_RIGHT then
        self:OpenSettings()
        return
    end

    if code == MOUSE_LEFT then
        if self.hoverIntent == "settings" then
            self:OpenSettings()
            return
        end

        if self.hoverIntent == "slot" and self.hoveredSlot then
            self:SelectSlot(self.hoveredSlot)
            return
        end

        self:CommitSelection()
    end
end

function PANEL:Paint(w, h)
    local alphaMul = math.Clamp(self.alphaFrac, 0, 1)
    local cx, cy = self:GetCenter()
    local centerD = self.centerRadius * 2
    local gapRad = self.segmentGapRad or 0
    local activeSlot = Animations.GetActiveSlot()
    _AN_COL_WHEEL_BG.a = math.floor(150 * alphaMul)
    RNDX().Rect(0, 0, w, h):Color(_AN_COL_WHEEL_BG):Draw()
    for i = 1, SLOT_COUNT do
        local info = Animations.GetSlotInfo(i)
        local hover = self._slotHoverFrac[i] or 0
        local isActive = activeSlot == i
        local fill = info.assigned and COL_SLOT or COL_SLOT_EMPTY
        if info.missing then fill = blendColor(fill, COL_WARNING, 0.20) end
        if isActive then fill = blendColor(fill, WHEEL_ACTIVE, 0.30) end
        if hover > 0 then fill = blendColor(fill, COL_SLOT_HOVER, hover * 0.82) end
        local startRad, endRad = getWheelSegmentRadians(i, gapRad)
        local vertices = buildAnnularSegmentVertices(cx, cy, self.ringInnerRadius, self.outerRadius, startRad, endRad)
        drawPolygon(vertices, alphaColor(fill, math.floor((fill.a or 255) * alphaMul)))
        drawPolygonOutline(vertices, alphaColor(isActive and WHEEL_ACTIVE or COL_BORDER, math.floor((hover > 0 and 190 or 124) * alphaMul)))
        local mid, iconDist = getWheelMidpoint(i, self.ringInnerRadius, self.outerRadius, 0.57)
        local ix = cx + math.cos(mid) * iconDist
        local iy = cy + math.sin(mid) * iconDist
        local previewBase = math.min(self.slotWidth * 0.53, self.slotDepth * 0.64)
        local previewSize = previewBase * (1 + hover * 0.07)
        if info.assigned then
            self:DrawSlotPreview(i, ix, iy, previewSize)
        else
            drawPlusCentered(ix, iy, math.floor(math.min(self.slotWidth, self.slotDepth) * (0.26 + hover * 0.02)), math.max(4, math.floor(math.min(self.slotWidth, self.slotDepth) * 0.045)), alphaColor(COL_TEXT, math.floor((218 + hover * 28) * alphaMul)))
        end

        local iconMat = getWheelIcon(info)
        if iconMat then
            local overlaySize = R:RS(24)
            drawMaterialCentered(iconMat, ix, iy + previewSize * 0.34, overlaySize, overlaySize, alphaColor(COL_TEXT, math.floor(235 * alphaMul)), 0, MAT_ICON_FLAGS)
        end
    end

    local centerFill = blendColor(WHEEL_CENTER, WHEEL_CENTER_HOVER, self._settingsHoverFrac * 0.9)
    RNDX().Circle(cx, cy, centerD):Color(alphaColor(centerFill, math.floor((centerFill.a or 250) * alphaMul))):Draw()
    RNDX().Circle(cx, cy, centerD):Outline(2):Color(alphaColor(blendColor(COL_BORDER, COL_TEXT, self._settingsHoverFrac * 0.18), math.floor((136 + self._settingsHoverFrac * 70) * alphaMul))):Draw()
    drawMaterialCentered(MAT_WHEEL_GEAR, cx, cy, R:RX(WHEEL_CENTER_ICON_W) * (1 + self._settingsHoverFrac * 0.06), R:RY(WHEEL_CENTER_ICON_H) * (1 + self._settingsHoverFrac * 0.06), alphaColor(COL_TEXT, math.floor(255 * alphaMul)), 0, MAT_FLAGS)
    local hintTitle = "Animations Wheel"
    local hintText = "Release on a slot. Click the center for settings."
    if self.hoverIntent == "settings" then
        hintTitle = "Open Settings"
        hintText = "Click the center or right click to edit animation slots."
    elseif self.hoverIntent == "slot" and self.hoveredSlot then
        local info = Animations.GetSlotInfo(self.hoveredSlot)
        hintTitle = "Slot " .. tostring(self.hoveredSlot) .. "  -  " .. info.label
        if info.assigned then
            hintText = info.missing and "Unavailable on the current model." or info.sequence
        else
            hintText = "Empty slot. Release to open the settings menu."
        end
    elseif activeSlot then
        local activeInfo = Animations.GetSlotInfo(activeSlot)
        hintTitle = "Active  -  " .. activeInfo.label
        hintText = "Release on another slot to switch animation."
    end

    local hintW = math.min(R:RX(520), ScrW() - R:RX(80))
    local hintH = R:RY(70)
    local hintX = cx - hintW * 0.5
    local hintY = math.min(h - hintH - R:RY(28), cy + self.outerRadius + R:RY(26))
    _AN_COL_HINT_BG.a = math.floor(220 * alphaMul)
    RNDX().Rect(hintX, hintY, hintW, hintH):Rad(R:RS(20)):Color(_AN_COL_HINT_BG):Draw()
    RNDX().Rect(hintX, hintY, hintW, hintH):Rad(R:RS(20)):Outline(2):Color(alphaColor(COL_BORDER, math.floor(124 * alphaMul))):Draw()
    draw.SimpleText(hintTitle, font("SemiBold", 22), cx, hintY + R:RY(24), alphaColor(COL_TEXT, math.floor(250 * alphaMul)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(hintText, font("Regular", 15), cx, hintY + R:RY(48), alphaColor(COL_MUTED, math.floor(220 * alphaMul)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:OnRemove()
    self:ClearSlotPreviews()
    local restoreX = math.Clamp(math.floor(tonumber(self._restoreCursorX) or (ScrW() * 0.5)), 0, ScrW())
    local restoreY = math.Clamp(math.floor(tonumber(self._restoreCursorY) or (ScrH() * 0.5)), 0, ScrH())
    timer.Simple(0, function() if input.SetCursorPos then input.SetCursorPos(restoreX, restoreY) end end)
    if Animations._wheel == self then Animations._wheel = nil end
end

vgui.Register("VERSEAnimationWheel", PANEL, "EditablePanel")
function Animations.CloseWheel()
    if IsValid(Animations._wheel) then Animations._wheel:Remove() end
    Animations._wheel = nil
end

function Animations.CloseWheelAndCommit()
    if IsValid(Animations._wheel) then return Animations._wheel:CommitSelection() end
    Animations._wheel = nil
    return false
end

function Animations.OpenWheel()
    local ply = LocalPlayer()
    if not (IsValid(ply) and ply:Alive()) then return end
    if gui.IsGameUIVisible() then return end
    if IsValid(Animations._settingsFrame) then return end
    Animations.RefreshCatalog(false)
    local anyAssigned = false
    for i = 1, SLOT_COUNT do
        if Animations.ClientSlots[i] then
            anyAssigned = true
            break
        end
    end

    if not anyAssigned then
        notify("All slots are empty. Configure animations first.", NOTIFY_HINT, 4)
        Animations.OpenSettings()
        return
    end

    Animations.CloseWheel()
    Animations._wheel = vgui.Create("VERSEAnimationWheel")
end

registerMaterialAliases()
VERSE.Hook.AddNS("Animations", "InitPostEntity", "VERSE::InitPostEntity::Animations", function()
    registerMaterialAliases()
    precacheMaterials()
    Animations.LoadSlots()
    timer.Simple(1, function()
        if not IsValid(LocalPlayer()) then return end
        Animations.RefreshCatalog(true)
    end)
end)

VERSE.Commands.Add("verse_animations", function() Animations.OpenWheel() end, nil, "client")
VERSE.Commands.Add("verse_animations_menu", function() Animations.OpenSettings() end, nil, "client")
VERSE.Commands.Add("verse_animations_stop", function() Animations.RequestStop() end, nil, "client")
VERSE.Commands.Add("+verse_animations_wheel", function() Animations.OpenWheel() end, nil, "client")
VERSE.Commands.Add("-verse_animations_wheel", function() Animations.CloseWheelAndCommit() end, nil, "client")
VERSE.Commands.Add("verse_animations_wheel", function()
    if IsValid(Animations._wheel) then
        Animations.CloseWheelAndCommit()
    else
        Animations.OpenWheel()
    end
end, nil, "client")
