local ST = VERSE.SkillTree
if not ST then return end
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Math = VERSE.Math
local Materials = VERSE.Materials
-- ─── Couleurs pré-allouées pour SkillTree Loadout — regroupées en table (1 upvalue au lieu de 40+) ──
local _C = {
    COL_TEXT         = Color(241, 241, 247),
    COL_ACCENT_SOFT  = Color(154, 92,  255),
    COL_SLOT         = Color(92,  96,  108),
    COL_DIVIDER      = Color(58,  60,  70,  180),
    TOP_LEFT_BG      = Color(255, 255, 255, 250),
    BOTTOM_LEFT_BG   = Color(56,  56,  56,  236),
    BOTTOM_LEFT_BG2  = Color(28,  30,  38,  220),
    RIGHT_BG         = Color(255, 255, 255, 250),
    SLOTS_TRAY_BG    = Color(31,  32,  37,  0),
    TAB_BASE         = Color(196, 196, 196, 255),
    TAB_HOVER_BG     = Color(255, 255, 255, 8),
    TAB_DOT          = Color(154, 92,  255, 0),
    PRESET_FILL      = Color(26,  27,  32,  252),
    PRESET_OUT       = Color(58,  78,  112, 185),
    PRESET_TXT       = Color(250, 250, 252, 255),
    ORB_SHADOW       = Color(0,   0,   0,   30),
    ORB_FILL         = Color(88,  90,  96,  0),
    ORB_RING         = Color(154, 92,  255, 0),
    ORB_ICON         = Color(236, 238, 243, 0),
    SLOT_GLOW        = Color(255, 255, 255, 0),
    SLOT_ACCENT_SH   = Color(154, 92,  255, 0),
    SLOT_BG          = Color(86,  88,  96,  0),
    SLOT_INNER       = Color(118, 120, 132, 105),
    SLOT_RING        = Color(154, 92,  255, 0),
    SLOT_CAPTURE     = Color(255, 214, 112, 80),
    SLOT_ICON        = Color(245, 245, 248, 255),
    SLOT_EMPTY_Q     = Color(178, 180, 188, 255),
    SLOT_BIND_CAP    = Color(255, 232, 166, 255),
    SLOT_BIND_NRM    = Color(198, 200, 208, 255),
    LARGE_SHADOW     = Color(0,   0,   0,   24),
    LARGE_BG         = Color(82,  84,  92,  220),
    LARGE_RING       = Color(154, 92,  255, 0),
    LARGE_ICON       = Color(245, 245, 248, 255),
    META_CAT         = Color(184, 186, 194, 255),
    META_SUBTYPE     = Color(235, 236, 242, 255),
    EMPTY_SUB        = Color(184, 186, 194, 255),
    ROW_BG1          = Color(26,  27,  34,  230),
    ROW_BG2          = Color(42,  44,  52,  220),
    SEARCH_BG        = Color(46,  46,  50,  210),
    SEARCH_OUT       = Color(74,  74,  82,  190),
    SEARCH_GLYPH     = Color(216, 216, 222, 255),
    SEARCH_PH        = Color(166, 166, 174, 255),
    SEARCH_HL        = Color(154, 92,  255, 120),
    ABILITY_EMPTY    = Color(184, 186, 194, 255),
}
-- ─────────────────────────────────────────────────────────────────────────────
local FRAME_W = 1470
local FRAME_H = 820
local SLOT_BIND_COOKIE_PREFIX = "verse_skill_slot_bind_"
local function lerpFactor(speed)
    return math.Clamp(FrameTime() * speed, 0, 1)
end

local function smooth(current, target, speed)
    return Lerp(lerpFactor(speed or 12), current or 0, target or 0)
end

local function approach(current, target, halflife)
    return Math and Math.ApproachExp and Math.ApproachExp(current or 0, target or 0, halflife or 0.08, FrameTime()) or smooth(current, target, 12)
end

local function getClientState()
    return ST:NormalizeState(ST.Client and ST.Client.state or nil)
end

local function getClientLoadout()
    return ST:NormalizeLoadout(ST.Client and ST.Client.loadout or nil, getClientState())
end

local function notifyClient(message, notifyType)
    message = tostring(message or "")
    if message == "" then return end
    local ply = LocalPlayer and LocalPlayer() or nil
    if IsValid(ply) and isfunction(ply.Notify) then
        ply:Notify(message, notifyType or NOTIFY_GENERIC, 3.5)
        return
    end

    if notification and isfunction(notification.AddLegacy) then notification.AddLegacy(message, notifyType or NOTIFY_GENERIC, 4) end
end

local function prettifyBindLabel(binding)
    binding = string.upper(tostring(binding or ""))
    if binding == "" then return "UNBOUND" end
    local replacements = {
        MWHEELUP = "WHEEL UP",
        MWHEELDOWN = "WHEEL DOWN",
        MOUSE1 = "M1",
        MOUSE2 = "M2",
        MOUSE3 = "M3",
        MOUSE4 = "M4",
        MOUSE5 = "M5",
        KP_INS = "KP 0",
        KP_END = "KP 1",
        KP_DOWNARROW = "KP 2",
        KP_PGDN = "KP 3",
        KP_LEFTARROW = "KP 4",
        KP_5 = "KP 5",
        KP_RIGHTARROW = "KP 6",
        KP_HOME = "KP 7",
        KP_UPARROW = "KP 8",
        KP_PGUP = "KP 9",
    }
    return replacements[binding] or binding:gsub("_", " ")
end

local function getSlotBindCookieKey(slotIndex)
    return SLOT_BIND_COOKIE_PREFIX .. tostring(math.max(1, math.floor(tonumber(slotIndex) or 1)))
end

local function isMouseBinding(binding)
    binding = string.upper(tostring(binding or ""))
    return string.sub(binding, 1, 5) == "MOUSE"
end

local function isSlotInputSuppressed()
    if gui and isfunction(gui.IsGameUIVisible) and gui.IsGameUIVisible() then return true end
    if vgui and isfunction(vgui.CursorVisible) and vgui.CursorVisible() then return true end
    local focused = vgui and isfunction(vgui.GetKeyboardFocus) and vgui.GetKeyboardFocus() or nil
    return IsValid(focused)
end

local function isWeaponSelectorBlockingSlots()
    local selector = VERSE and VERSE.WeaponSelector or nil
    if not istable(selector) then return false end
    if isfunction(selector.IsOpen) and selector:IsOpen() then return true end
    local suppressUntil = isfunction(selector.GetSkillSlotSuppressUntil) and selector:GetSkillSlotSuppressUntil() or 0
    return (tonumber(suppressUntil) or 0) > RealTime()
end

local function resetSlotKeyStates()
    local states = ST.Client and ST.Client.slotKeyState or nil
    if not istable(states) then return end
    for slotIndex = 1, ST:GetBindSlotCount() do
        states[slotIndex] = false
    end
end

local function canTriggerSlotInputForWeapon(weapon)
    -- On ne restreint plus à combat_swep_base : les armes TOOM_JJK et les autres
    -- armes du serveur ont des noms de classe différents mais doivent pouvoir
    -- déclencher les techniques. La validation finale est côté serveur
    -- (weapon:TryUseSkillTreeAbility ou hook d'exécution).
    local ply = LocalPlayer and LocalPlayer() or nil
    return IsValid(ply) and ply:Alive()
end

local function isBindingDown(binding, keyCode)
    if not input or not keyCode or keyCode <= 0 then return false end
    if isMouseBinding(binding) and isfunction(input.IsMouseDown) then return input.IsMouseDown(keyCode) == true end
    if isfunction(input.IsKeyDown) then return input.IsKeyDown(keyCode) == true end
    return false
end

local function wasBindingPressed(binding, keyCode, slotIndex)
    if not input or not keyCode or keyCode <= 0 then return false end
    ST:EnsureClientBindState()
    local pressed = false
    if isfunction(input.WasKeyPressed) and input.WasKeyPressed(keyCode) then pressed = true end
    if not pressed and isMouseBinding(binding) and isfunction(input.WasMousePressed) and input.WasMousePressed(keyCode) then pressed = true end
    local states = ST.Client.slotKeyState or {}
    local isDown = isBindingDown(binding, keyCode)
    local wasDown = states[slotIndex] == true
    states[slotIndex] = isDown
    ST.Client.slotKeyState = states
    if not pressed and isDown and not wasDown then pressed = true end
    return pressed
end

local function getAbilityEntries()
    return ST:GetAvailableAbilitiesForState(getClientState(), false)
end

local function prettifyStatKey(key)
    local fr = {
        mana_cost = "Energie Occulte",
        duration = "Duree",
        cooldown = "Cooldown",
        execution_type = "Type",
        Damage = "Degats",
        MeleeDamage = "Degats de melee",
        AbilityPower = "Puissance occulte",
        CooldownReduction = "Reduction des temps de recharge",
        RunSpeed = "Vitesse de course",
        DamageReduction = "Reduction des degats",
        ManaCostReduction = "Reduction du cout en Energie Occulte",
    }

    if fr[key] then return fr[key] end
    key = tostring(key or "")
    key = key:gsub("(%l)(%u)", "%1 %2")
    key = key:gsub("_", " ")
    return key:gsub("^%l", string.upper)
end

local function isMeaningfulStatValue(value)
    if value == nil then return false end
    if isstring(value) then
        local trimmed = string.Trim(value)
        return trimmed ~= "" and trimmed ~= "---"
    end
    return true
end

local function formatSeconds(value)
    local numeric = tonumber(value)
    if numeric == nil or numeric <= 0 then return nil end
    local rounded = math.Round(numeric, numeric % 1 == 0 and 0 or 1)
    return tostring(rounded) .. " s"
end

local function formatBonusValue(statKey, value)
    local numeric = tonumber(value)
    if numeric == nil then
        if isMeaningfulStatValue(value) then return tostring(value) end
        return nil
    end

    local isPercent = statKey == "CooldownReduction" or statKey == "DamageReduction" or statKey == "ManaCostReduction"
    if isPercent then
        local percent = math.Round(numeric * 100, 1)
        if percent == 0 then return nil end
        local prefix = percent > 0 and "+" or ""
        return prefix .. tostring(percent) .. "%"
    end

    local rounded = math.Round(numeric, numeric % 1 == 0 and 0 or 1)
    if rounded == 0 then return nil end
    local prefix = rounded > 0 and "+" or ""
    return prefix .. tostring(rounded)
end

local function buildAbilityStats(entry)
    if not entry then return {} end
    local abilityData = entry.data or ST:GetAbilityData(entry.id) or {}
    local execution = istable(abilityData.execution) and abilityData.execution or nil
    local buffProfile = execution and tostring(execution.buff_profile or "") or ""
    local combat = VERSE and VERSE.Combat
    local profile = combat and combat.GetBuffProfileData and combat:GetBuffProfileData(buffProfile) or nil
    local stats = {}
    local function addStat(label, value)
        if not isMeaningfulStatValue(value) then return end
        stats[#stats + 1] = {
            label = label,
            value = tostring(value),
        }
    end

    local cooldown = profile and profile.cooldown or nil
    addStat(prettifyStatKey("cooldown"), formatSeconds(cooldown))
    local manaCost = ST:GetAbilityManaCost(entry.id, nil)
    if tonumber(manaCost) and tonumber(manaCost) > 0 then addStat(prettifyStatKey("mana_cost"), tostring(math.floor(tonumber(manaCost)))) end
    addStat(prettifyStatKey("duration"), formatSeconds(profile and profile.duration or nil))
    if execution and tostring(execution.type or "") ~= "" then
        local executionLabel = ST:GetExecutionDisplayName(tostring(execution.type or ""))
        if executionLabel == "" then executionLabel = prettifyStatKey(tostring(execution.type or "")) end
        addStat(prettifyStatKey("execution_type"), executionLabel)
    elseif abilityData.passive == true then
        addStat(prettifyStatKey("execution_type"), "Passive")
    end

    local bonusMap = istable(profile and profile.stats) and profile.stats or nil
    if bonusMap then
        local orderedKeys = {}
        for statKey in pairs(bonusMap) do
            orderedKeys[#orderedKeys + 1] = statKey
        end

        table.sort(orderedKeys, function(a, b) return prettifyStatKey(a) < prettifyStatKey(b) end)
        for index = 1, #orderedKeys do
            local statKey = orderedKeys[index]
            addStat(prettifyStatKey(statKey), formatBonusValue(statKey, bonusMap[statKey]))
        end
    end
    return stats
end

local function getAbilitySourceMap()
    if ST._abilitySourceMap then return ST._abilitySourceMap end
    local sourceMap = {}
    for _, node in pairs(ST:GetNodeMap() or {}) do
        if istable(node.abilities) then
            for index = 1, #node.abilities do
                local abilityId = tostring(node.abilities[index] or "")
                if abilityId ~= "" and not sourceMap[abilityId] then
                    sourceMap[abilityId] = {
                        category_id = tostring(node.category_id or ""),
                        category_title = tostring(node.category_title or ""),
                        category_icon = tostring(node.category_icon or ""),
                        category_color = node.category_color,
                        subtype_id = tostring(node.subtype_id or ""),
                        subtype_title = tostring(node.subtype_title or ""),
                        subtype_icon = tostring(node.subtype_icon or ""),
                        subtype_color = node.subtype_color,
                    }
                end
            end
        end
    end

    ST._abilitySourceMap = sourceMap
    return sourceMap
end

local function getAbilityById(entries, abilityId)
    abilityId = tostring(abilityId or "")
    if abilityId == "" then return nil end
    for _, entry in ipairs(entries) do
        if entry.id == abilityId then return entry end
    end
    return nil
end

local function getAbilityInitials(abilityId)
    local title = tostring(ST:GetAbilityDisplayName(abilityId) or "")
    if title == "" then return "?" end
    local parts = string.Explode(" ", title)
    local chars = {}
    for _, part in ipairs(parts) do
        local ch = string.sub(part, 1, 1)
        if ch and ch ~= "" then chars[#chars + 1] = string.upper(ch) end
        if #chars >= 2 then break end
    end

    if #chars <= 0 then
        local first = string.sub(title, 1, 1)
        return string.upper(first or "?")
    end
    return table.concat(chars, "")
end

local function getAbilityMeta(entryOrAbilityId)
    local abilityId = isstring(entryOrAbilityId) and tostring(entryOrAbilityId or "") or tostring(entryOrAbilityId and entryOrAbilityId.id or "")
    if abilityId == "" then return {} end
    local source = getAbilitySourceMap()[abilityId] or {}
    local category, subtype = ST:GetCategoryForSubtype(source.subtype_id)
    local abilityData = ST:GetAbilityData(abilityId) or {}
    return {
        ability_id = abilityId,
        ability_title = ST:GetAbilityDisplayName(abilityId),
        ability_icon = ST:GetAbilityIcon(abilityId, tostring(source.subtype_icon or (subtype and subtype.icon) or source.category_icon or (category and category.icon) or "")),
        category_id = tostring(source.category_id or (category and category.id) or ""),
        category_title = tostring(source.category_title or (category and category.title) or ""),
        category_icon = tostring(source.category_icon or (category and category.icon) or ""),
        category_color = source.category_color or (category and category.color) or _C.COL_ACCENT_SOFT,
        subtype_id = tostring(source.subtype_id or (subtype and subtype.id) or ""),
        subtype_title = tostring(source.subtype_title or (subtype and subtype.title) or ""),
        subtype_icon = tostring(source.subtype_icon or (subtype and subtype.icon) or ""),
        subtype_color = source.subtype_color or (subtype and subtype.color) or source.category_color or (category and category.color) or _C.COL_ACCENT_SOFT,
        bindable = entryOrAbilityId and entryOrAbilityId.bindable == true or ST:IsAbilityBindable(abilityId, abilityData),
    }
end

local function drawAbilityVisual(abilityId, x, y, w, h, tintColor, fallbackFont)
    local meta = getAbilityMeta(abilityId)
    local iconAlias = tostring(meta.ability_icon or "")
    if iconAlias ~= "" then
        local pad = math.floor(math.min(w, h) * 0.07)
        Materials:Draw(tintColor or color_white, iconAlias, x + pad, y + pad, w - pad * 2, h - pad * 2, "noclamp smooth")
        return true
    end

    draw.SimpleText(getAbilityInitials(abilityId), fallbackFont or Font:GetNamed("Poppins", "SemiBold", 22), x + w * 0.5, y + h * 0.5, tintColor or Color(245, 245, 248), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    return false
end

local function getSelectedAbilityId(entries)
    local selected = tostring(ST.Client and ST.Client.selectedAbilityId or "")
    if selected ~= "" then
        for _, entry in ipairs(entries) do
            if entry.id == selected then return selected end
        end
    end

    if entries[1] then
        ST.Client.selectedAbilityId = entries[1].id
        return entries[1].id
    end

    ST.Client.selectedAbilityId = nil
    return ""
end

local function getSelectedCategoryId(entries)
    local sourceMap = getAbilitySourceMap()
    local selectedCategoryId = tostring(ST.Client and ST.Client.loadoutCategoryId or "")
    if selectedCategoryId ~= "" then return selectedCategoryId end
    local selectedAbilityId = tostring(ST.Client and ST.Client.selectedAbilityId or "")
    local source = sourceMap[selectedAbilityId]
    if source and source.category_id ~= "" then
        ST.Client.loadoutCategoryId = source.category_id
        return source.category_id
    end

    for _, entry in ipairs(entries) do
        local entrySource = sourceMap[entry.id]
        if entrySource and entrySource.category_id ~= "" then
            ST.Client.loadoutCategoryId = entrySource.category_id
            return entrySource.category_id
        end
    end

    local fallback = ST.Tree[1] and ST.Tree[1].id or ""
    ST.Client.loadoutCategoryId = fallback
    return fallback
end

local function getFrameCategoryId(frame, entries)
    local frameCategoryId = tostring(IsValid(frame) and frame._activeCategoryId or "")
    if frameCategoryId ~= "" then
        ST.Client.loadoutCategoryId = frameCategoryId
        return frameCategoryId
    end

    local clientCategoryId = tostring(ST.Client and ST.Client.loadoutCategoryId or "")
    if clientCategoryId ~= "" then
        if IsValid(frame) then frame._activeCategoryId = clientCategoryId end
        return clientCategoryId
    end

    local fallbackCategoryId = getSelectedCategoryId(entries)
    if IsValid(frame) then frame._activeCategoryId = fallbackCategoryId end
    return fallbackCategoryId
end

local function getSearchValue(frame)
    if not IsValid(frame) or not IsValid(frame.searchEntry) then return "" end
    local entry = IsValid(frame.searchEntry.textEntry) and frame.searchEntry.textEntry or frame.searchEntry
    return string.Trim(string.lower(entry:GetValue() or ""))
end

local function getCategoryAbilityIdSet(categoryId)
    categoryId = tostring(categoryId or "")
    if categoryId == "" then return nil end
    local category = ST:GetCategory(categoryId)
    local allowed = {}
    local subtypes = istable(category) and category.subtypes or {}
    for subtypeIndex = 1, #subtypes do
        local nodes = istable(subtypes[subtypeIndex]) and subtypes[subtypeIndex].nodes or {}
        for nodeIndex = 1, #nodes do
            local abilities = istable(nodes[nodeIndex]) and nodes[nodeIndex].abilities or {}
            for abilityIndex = 1, #abilities do
                local abilityId = tostring(abilities[abilityIndex] or "")
                if abilityId ~= "" then allowed[abilityId] = true end
            end
        end
    end
    return allowed
end

local function getVisibleEntries(frame)
    local allEntries = getAbilityEntries()
    local sourceMap = getAbilitySourceMap()
    local selectedCategoryId = getFrameCategoryId(frame, allEntries)
    local allowedAbilityIds = getCategoryAbilityIdSet(selectedCategoryId)
    local searchValue = getSearchValue(frame)
    local isSearching = searchValue ~= ""
    local visible = {}
    for _, entry in ipairs(allEntries) do
        local source = sourceMap[entry.id] or {}
        local matchesCategory = isSearching or selectedCategoryId == "" or (allowedAbilityIds and allowedAbilityIds[entry.id] == true)
        if matchesCategory and isSearching then
            local haystack = string.lower(table.concat({tostring(entry.id or ""), tostring(ST:GetAbilityDisplayName(entry.id) or ""), tostring(ST:GetAbilityDescription(entry.id) or ""), tostring(source.category_title or ""), tostring(source.subtype_title or ""),}, " "))
            if not string.find(haystack, searchValue, 1, true) then matchesCategory = false end
        end

        if matchesCategory then visible[#visible + 1] = entry end
    end
    return allEntries, visible
end

local function resolveVisibleEntries(frame)
    return getVisibleEntries(frame)
end

local function drawRoundedPanel(x, y, w, h, radius, color, outlineColor)
    color = color or Color(255, 255, 255, 0)
    RNDX().Rect(x, y, w, h):Rad(radius):Color(color):Draw()
    if outlineColor then RNDX().Rect(x, y, w, h):Rad(radius):Outline(1):Color(outlineColor):Draw() end
end

local function drawSearchGlyph(x, y, color)
    local ring = R:X(12)
    RNDX().Circle(x, y, ring):Outline(2):Color(color):Draw()
    surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
    surface.DrawLine(x + R:X(5), y + R:Y(5), x + R:X(10), y + R:Y(10))
    surface.DrawLine(x + R:X(5), y + R:Y(6), x + R:X(9), y + R:Y(10))
end

function ST:RequestAssignSlot(presetIndex, slotIndex, abilityId)
    abilityId = tostring(abilityId or "")
    if abilityId == "" then return end
    netstream.Start(self.Net.AssignSlot, tonumber(presetIndex) or 1, tonumber(slotIndex) or 1, abilityId)
end

function ST:RequestClearSlot(presetIndex, slotIndex)
    netstream.Start(self.Net.ClearSlot, tonumber(presetIndex) or 1, tonumber(slotIndex) or 1)
end

function ST:RequestSetActivePreset(presetIndex)
    netstream.Start(self.Net.SetActivePreset, tonumber(presetIndex) or 1)
end

function ST:RequestUseSlot(slotIndex)
    netstream.Start(self.Net.UseSlot, tonumber(slotIndex) or 1)
end

function ST:EnsureClientBindState()
    self.Client = self.Client or {}
    self.Client.internalKeymap = self.Client.internalKeymap or {}
    self.Client.internalKeycodes = self.Client.internalKeycodes or {}
    self.Client.slotKeyState = self.Client.slotKeyState or {}
    self.Client.slotLastUseAt = self.Client.slotLastUseAt or {}
    if self.Client.slotBindingsLoaded then return end
    self.Client.slotBindingsLoaded = true
    if not cookie or not isfunction(cookie.GetString) then return end
    for slotIndex = 1, self:GetBindSlotCount() do
        local raw = cookie.GetString(getSlotBindCookieKey(slotIndex), "")
        local keyCode = math.floor(tonumber(raw) or 0)
        if keyCode > 0 then
            local keyName = isfunction(input.GetKeyName) and input.GetKeyName(keyCode) or nil
            keyName = string.lower(string.Trim(tostring(keyName or "")))
            if keyName ~= "" then
                self.Client.internalKeymap[slotIndex] = keyName
                self.Client.internalKeycodes[slotIndex] = keyCode
            end
        end
    end
end

function ST:GetSlotConsoleCommand(slotIndex)
    slotIndex = math.Clamp(math.floor(tonumber(slotIndex) or 0), 1, self:GetBindSlotCount())
    return "verse_skill_slot_" .. tostring(slotIndex)
end

function ST:GetSlotBindingCode(slotIndex)
    self:EnsureClientBindState()
    local keyCode = self.Client and self.Client.internalKeycodes and self.Client.internalKeycodes[slotIndex] or nil
    keyCode = math.floor(tonumber(keyCode) or 0)
    if keyCode > 0 then return keyCode end
    local keyName = self.Client and self.Client.internalKeymap and self.Client.internalKeymap[slotIndex] or nil
    if isstring(keyName) and keyName ~= "" and input and isfunction(input.GetKeyCode) then
        keyCode = math.floor(tonumber(input.GetKeyCode(keyName)) or 0)
        if keyCode > 0 then
            self.Client.internalKeycodes[slotIndex] = keyCode
            return keyCode
        end
    end
    return nil
end

function ST:PersistSlotBinding(slotIndex)
    if not cookie or not isfunction(cookie.Set) then return end
    cookie.Set(getSlotBindCookieKey(slotIndex), tostring(self:GetSlotBindingCode(slotIndex) or 0))
end

function ST:LookupSlotBinding(slotIndex)
    self:EnsureClientBindState()
    if self.Client and self.Client.internalKeymap and self.Client.internalKeymap[slotIndex] then return self.Client.internalKeymap[slotIndex] end
    if not input or not isfunction(input.LookupBinding) then return nil end
    local binding = input.LookupBinding(self:GetSlotConsoleCommand(slotIndex))
    if not isstring(binding) or binding == "" then return nil end
    return binding
end

function ST:GetSlotBindingLabel(slotIndex)
    return prettifyBindLabel(self:LookupSlotBinding(slotIndex))
end

function ST:BindSlotKey(slotIndex, keyName, keyCode)
    self:EnsureClientBindState()
    slotIndex = math.Clamp(math.floor(tonumber(slotIndex) or 0), 1, self:GetBindSlotCount())
    keyName = string.lower(string.Trim(tostring(keyName or "")))
    keyCode = math.floor(tonumber(keyCode) or 0)
    if keyName == "" and keyCode > 0 and input and isfunction(input.GetKeyName) then
        keyName = string.lower(string.Trim(tostring(input.GetKeyName(keyCode) or "")))
    end
    if keyCode <= 0 and input and isfunction(input.GetKeyCode) then
        keyCode = math.floor(tonumber(input.GetKeyCode(keyName)) or 0)
    end
    if keyName == "" or keyCode <= 0 then return false end
    local reassignedFrom = nil
    for boundSlot, boundKey in pairs(self.Client.internalKeymap or {}) do
        boundSlot = tonumber(boundSlot) or 0
        if boundSlot ~= slotIndex and tostring(boundKey or "") == keyName then
            self.Client.internalKeymap[boundSlot] = nil
            if self.Client.internalKeycodes then self.Client.internalKeycodes[boundSlot] = nil end
            if self.Client.slotKeyState then self.Client.slotKeyState[boundSlot] = false end
            self:PersistSlotBinding(boundSlot)
            reassignedFrom = boundSlot
        end
    end

    self.Client.internalKeymap[slotIndex] = keyName
    self.Client.internalKeycodes[slotIndex] = keyCode
    self.Client.slotKeyState[slotIndex] = false
    self:PersistSlotBinding(slotIndex)
    self:RefreshLoadoutFrame()
    local suffix = reassignedFrom and (" Previous slot: " .. tostring(reassignedFrom) .. ".") or ""
    notifyClient("Slot " .. tostring(slotIndex) .. " bound to " .. prettifyBindLabel(keyName) .. "." .. suffix, NOTIFY_GENERIC)
    return true
end

function ST:ClearSlotBinding(slotIndex)
    self:EnsureClientBindState()
    local hasBind = self.Client and ((self.Client.internalKeymap and self.Client.internalKeymap[slotIndex] ~= nil) or (self.Client.internalKeycodes and self.Client.internalKeycodes[slotIndex] ~= nil))
    if not hasBind then return false end
    self.Client.internalKeymap[slotIndex] = nil
    if self.Client.internalKeycodes then self.Client.internalKeycodes[slotIndex] = nil end
    if self.Client.slotKeyState then self.Client.slotKeyState[slotIndex] = false end
    self:PersistSlotBinding(slotIndex)
    self:RefreshLoadoutFrame()
    notifyClient("Slot " .. tostring(slotIndex) .. " key cleared.", NOTIFY_GENERIC)
    return true
end

function ST:IsCapturingSlotBind(slotIndex)
    local capture = self.Client and self.Client.bindCapture or nil
    return istable(capture) and tonumber(capture.slotIndex) == tonumber(slotIndex)
end

function ST:CancelSlotBindCapture(skipRefresh)
    if self.Client then self.Client.bindCapture = nil end
    if not skipRefresh then self:RefreshLoadoutFrame() end
end

function ST:StartSlotBindCapture(slotIndex)
    if not input or not isfunction(input.StartKeyTrapping) or not isfunction(input.CheckKeyTrapping) then
        notifyClient("Slot key capture is unavailable in this build.", NOTIFY_ERROR)
        return
    end

    slotIndex = math.Clamp(math.floor(tonumber(slotIndex) or 0), 1, self:GetBindSlotCount())
    self.Client = self.Client or {}
    self.Client.bindCapture = {
        slotIndex = slotIndex,
        startedAt = RealTime(),
    }

    input.StartKeyTrapping()
    self:RefreshLoadoutFrame()
    notifyClient("Press a key for slot " .. tostring(slotIndex) .. ". Escape cancels, Backspace/Delete clears.", NOTIFY_GENERIC)
end

function ST:RefreshLoadoutFrame()
    local frame = self.Client and self.Client.loadoutFrame or nil
    if not IsValid(frame) or not isfunction(frame.RefreshData) then return end
    frame:RefreshData()
end

function ST:CloseLoadoutMenu()
    if IsValid(self.Client and self.Client.loadoutFrame or nil) then self.Client.loadoutFrame:Close() end
    if self.Client then self.Client.loadoutFrame = nil end
end

VERSE.Hook.AddNS("SkillTree", "Think", "VERSE::SkillTree::SlotBindCapture", function()
    local capture = ST.Client and ST.Client.bindCapture or nil
    if not istable(capture) then return end
    if not input or not isfunction(input.CheckKeyTrapping) then
        ST:CancelSlotBindCapture(true)
        return
    end

    local keyCode = input.CheckKeyTrapping()
    if not keyCode or keyCode <= 0 then return end
    local slotIndex = math.Clamp(math.floor(tonumber(capture.slotIndex) or 0), 1, ST:GetBindSlotCount())
    if keyCode == KEY_ESCAPE then
        notifyClient("Slot bind cancelled.", NOTIFY_GENERIC)
        ST:CancelSlotBindCapture()
        return
    end

    if keyCode == KEY_BACKSPACE or keyCode == KEY_DELETE then
        local cleared = ST:ClearSlotBinding(slotIndex)
        if not cleared then notifyClient("Slot " .. tostring(slotIndex) .. " has no key bind.", NOTIFY_ERROR) end
        ST:CancelSlotBindCapture()
        return
    end

    local keyName = isfunction(input.GetKeyName) and input.GetKeyName(keyCode) or nil
    if not isstring(keyName) or keyName == "" then
        notifyClient("This key cannot be bound.", NOTIFY_ERROR)
        ST:CancelSlotBindCapture()
        return
    end

    ST:BindSlotKey(slotIndex, keyName, keyCode)
    ST:CancelSlotBindCapture()
end)

VERSE.Hook.AddNS("SkillTree", "Think", "VERSE::SkillTree::SlotBindInput", function()
    ST:EnsureClientBindState()
    if istable(ST.Client and ST.Client.bindCapture or nil) then return end
    if isSlotInputSuppressed() then
        resetSlotKeyStates()
        return
    end
    if isWeaponSelectorBlockingSlots() then
        resetSlotKeyStates()
        return
    end

    local ply = LocalPlayer and LocalPlayer() or nil
    if not IsValid(ply) then return end
    local activeWeapon = isfunction(ply.GetActiveWeapon) and ply:GetActiveWeapon() or nil
    if not canTriggerSlotInputForWeapon(activeWeapon) then
        resetSlotKeyStates()
        return
    end
    local lastUseAt = ST.Client and ST.Client.slotLastUseAt or nil
    for slotIndex = 1, ST:GetBindSlotCount() do
        local binding = ST.Client and ST.Client.internalKeymap and ST.Client.internalKeymap[slotIndex] or nil
        local keyCode = ST:GetSlotBindingCode(slotIndex)
        if isstring(binding) and binding ~= "" and keyCode and keyCode > 0 and wasBindingPressed(binding, keyCode, slotIndex) then
            local now = RealTime()
            local nextAllowed = tonumber(lastUseAt and lastUseAt[slotIndex] or 0) or 0
            if now >= nextAllowed then
                lastUseAt[slotIndex] = now + 0.15
                ST:RequestUseSlot(slotIndex)
            end
        end
    end
end)

function ST:OpenLoadoutMenu()
    if IsValid(self.Client and self.Client.loadoutFrame or nil) then
        self.Client.loadoutFrame:MakePopup()
        self.Client.loadoutFrame:RequestFocus()
        self:RefreshLoadoutFrame()
        self:RequestSync()
        return
    end

    local frame = vgui.Create("MantleFrame")
    local frameW, frameH = R:XY(FRAME_W, FRAME_H)
    local rightW = R:X(489)
    local rightH = R:Y(800)
    local leftW = R:X(960)
    local bottomLeftH = R:Y(174)
    local topLeftH = R:Y(624)
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(false)
    frame:LiteMode()
    frame:SetAlphaBackground(false)
    frame:SetClosable(true)
    frame:DisableCloseBtn()
    frame:SetTitle("")
    frame:SetCenterTitle("")
    frame.allowEscClose = true
    frame.Paint = nil
    frame._activeCategoryId = getSelectedCategoryId(getAbilityEntries())
    local topLeftPanel = vgui.Create("DPanel", frame)
    topLeftPanel:SetSize(leftW, topLeftH)
    topLeftPanel:SetPos(0, 0)
    topLeftPanel.Paint = function(_, w, h) Materials:Draw(_C.TOP_LEFT_BG, "skilltree_sub_left_up_background", 0, 0, w, h) end
    local bottomLeftPanel = vgui.Create("DPanel", frame)
    bottomLeftPanel:SetSize(leftW, bottomLeftH)
    bottomLeftPanel:SetPos(0, topLeftH + R:Y(2))
    bottomLeftPanel.Paint = function(_, w, h) drawRoundedPanel(0, 0, w, h, R:Y(18), _C.BOTTOM_LEFT_BG, _C.BOTTOM_LEFT_BG2) end
    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:SetSize(rightW, rightH)
    rightPanel:SetPos(leftW + R:X(20), 0)
    rightPanel.Paint = function(_, w, h) Materials:Draw(_C.RIGHT_BG, "skilltree_sub_right_background", 0, 0, w, h) end
    local tabsPanel = vgui.Create("DPanel", topLeftPanel)
    tabsPanel:SetPos(R:XY(24, 16))
    tabsPanel:SetSize(topLeftPanel:GetWide() - R:X(48), R:Y(44))
    tabsPanel._activeCategoryId = frame._activeCategoryId
    tabsPanel._buttons = {}
    tabsPanel.Paint = function(pnl, w, h)
        local activeButton = nil
        for buttonIndex = 1, #pnl._buttons do
            local button = pnl._buttons[buttonIndex]
            if IsValid(button) and tostring(button._categoryId or "") == tostring(pnl._activeCategoryId or "") then
                activeButton = button
                break
            end
        end

        if not IsValid(activeButton) then return end
        local accent = activeButton._categoryColor or _C.COL_ACCENT_SOFT
        RNDX().Rect(activeButton:GetX(), h - R:Y(2), activeButton:GetWide(), R:Y(2)):Color(accent):Draw()
    end

    frame.tabsPanel = tabsPanel
    local featureChip = vgui.Create("MantleBtn", topLeftPanel)
    featureChip:SetPos(R:XY(22, 68))
    featureChip:SetSize(R:XY(414, 60))
    featureChip:SetTxt("")
    featureChip:SetRadius(R:Y(12))
    featureChip:SetGradient(false)
    featureChip:SetColor(Color(84, 58, 116))
    featureChip:SetColorHover(Color(104, 72, 142, 120))
    featureChip:SetRipple(false)
    featureChip._meta = nil
    local featureIcon = vgui.Create("DPanel", featureChip)
    featureIcon:SetPos(R:XY(18, 13))
    featureIcon:SetSize(R:XY(34, 34))
    featureIcon.Paint = function(_, w, h)
        local meta = featureChip._meta or {}
        local iconAlias = tostring(meta.subtype_icon or "")
        local accent = meta.subtype_color or _C.COL_ACCENT_SOFT
        drawRoundedPanel(0, 0, w, h, R:Y(8), Color(accent.r, accent.g, accent.b, 120))
        if iconAlias ~= "" then Materials:Draw(color_white, iconAlias, R:X(7), R:Y(7), w - R:X(14), h - R:Y(14), "noclamp smooth") end
    end

    local featureCategoryIcon = vgui.Create("DPanel", featureChip)
    featureCategoryIcon:SetPos(R:XY(70, 31))
    featureCategoryIcon:SetSize(R:XY(16, 16))
    featureCategoryIcon.Paint = function(_, w, h)
        local meta = featureChip._meta or {}
        local iconAlias = tostring(meta.category_icon or "")
        if iconAlias == "" then return end
        Materials:Draw(color_white, iconAlias, 0, 0, w, h, "noclamp smooth")
    end

    local featureLabel = vgui.Create("DLabel", featureChip)
    featureLabel:SetPos(R:XY(70, 6))
    featureLabel:SetSize(featureChip:GetWide() - R:X(90), R:Y(24))
    featureLabel:SetFont(Font:GetNamed("Poppins", "SemiBold", 17))
    featureLabel:SetTextColor(Color(247, 244, 255))
    featureLabel:SetContentAlignment(4)
    featureLabel:SetText("Aucun sous-type")
    featureChip._label = featureLabel
    local featureSubLabel = vgui.Create("DLabel", featureChip)
    featureSubLabel:SetPos(R:XY(92, 28))
    featureSubLabel:SetSize(featureChip:GetWide() - R:X(114), R:Y(20))
    featureSubLabel:SetFont(Font:GetNamed("Poppins", "Medium", 12))
    featureSubLabel:SetTextColor(Color(218, 220, 228))
    featureSubLabel:SetContentAlignment(4)
    featureSubLabel:SetText("")
    featureChip._subLabel = featureSubLabel
    featureChip.DoClick = function()
        if not IsValid(frame) then return end
        frame:RefreshData()
    end

    local abilityArea = vgui.Create("DScrollPanel", topLeftPanel)
    abilityArea:SetPos(R:XY(18, 130))
    abilityArea:SetSize(topLeftPanel:GetWide() - R:X(36), topLeftPanel:GetTall() - R:Y(162))
    abilityArea.Paint = nil
    local searchEntry = vgui.Create("MantleEntry", topLeftPanel)
    searchEntry:SetPos(topLeftPanel:GetWide() - R:X(238), topLeftPanel:GetTall() - R:Y(52))
    searchEntry:SetSize(R:XY(210, 40))
    searchEntry:SetPlaceholder("Recherchez")
    searchEntry:SetFonts(Font:GetNamed("Poppins", "Medium", 14))
    searchEntry:SetPlaceholderColor(Color(166, 166, 174))
    searchEntry:SetTextColor(_C.COL_TEXT)
    searchEntry:SetHighlightColor(Color(_C.COL_ACCENT_SOFT.r, _C.COL_ACCENT_SOFT.g, _C.COL_ACCENT_SOFT.b, 120))
    searchEntry:SetCursorColor(_C.COL_ACCENT_SOFT)
    searchEntry:SetUpdateOnType(true)
    searchEntry:SetOnValueChanged(function() if IsValid(frame) then frame:RefreshData() end end)
    local _searchFontPlaceholder = Font:GetNamed("Poppins", "Medium", 14)
    searchEntry.Paint = function(pnl, w, h)
        pnl._hoverFrac = approach(pnl._hoverFrac, (pnl:IsHovered() or (IsValid(pnl.textEntry) and pnl.textEntry:HasFocus())) and 1 or 0, 0.08)
        -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
        local hf = pnl._hoverFrac or 0
        _C.SEARCH_OUT.r = 74 + math.floor(26 * hf)
        _C.SEARCH_OUT.g = 74 + math.floor(26 * hf)
        _C.SEARCH_OUT.b = 82 + math.floor(24 * hf)
        drawRoundedPanel(0, 0, w, h, R:Y(12), _C.SEARCH_BG, _C.SEARCH_OUT)
        drawSearchGlyph(R:X(18), h * 0.5 - R:Y(1), _C.SEARCH_GLYPH)
    end

    if IsValid(searchEntry.textEntry) then
        local baseOnChange = searchEntry.textEntry.OnChange
        searchEntry.textEntry:DockMargin(R:X(34), 0, R:X(10), 0)
        searchEntry.textEntry:SetTextInset(R:X(6), 0)
        searchEntry.textEntry.OnChange = function(pnl)
            if isfunction(baseOnChange) then baseOnChange(pnl) end
            if IsValid(frame) then frame:RefreshData() end
        end

        searchEntry.textEntry.Paint = function(pnl, w, h)
            local value = pnl:GetValue() or ""
            if value == "" and not pnl:HasFocus() and not pnl:IsEditing() then
                draw.SimpleText(searchEntry.placeholder or "Recherchez", _searchFontPlaceholder, R:X(6), h * 0.5, _C.SEARCH_PH, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                return true
            end

            pnl:DrawTextEntryText(_C.COL_TEXT, _C.SEARCH_HL, _C.COL_ACCENT_SOFT)
            return true
        end
    end

    frame.searchEntry = searchEntry
    local slotsTray = vgui.Create("DPanel", bottomLeftPanel)
    slotsTray:SetPos(0, 0)
    slotsTray:SetSize(bottomLeftPanel:GetWide(), bottomLeftPanel:GetTall())
    slotsTray.Paint = function(_, w, h) drawRoundedPanel(0, 0, w, h, R:Y(18), _C.SLOTS_TRAY_BG) end
    local presetPager = vgui.Create("DButton", frame)
    presetPager:SetSize(R:XY(80, 45))
    presetPager:SetPos(bottomLeftPanel:GetX() + math.floor((bottomLeftPanel:GetWide() - presetPager:GetWide()) * 0.5), frameH - R:Y(45))
    presetPager:SetText("")
    local _presetFont = Font:GetNamed("Poppins", "SemiBold", 26)
    presetPager.Paint = function(pnl, w, h)
        pnl._hoverFrac = smooth(pnl._hoverFrac, pnl:IsHovered() and 1 or 0, 14)
        -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
        _C.PRESET_FILL.r = math.floor(Lerp(pnl._hoverFrac or 0, 26, 34))
        _C.PRESET_FILL.g = math.floor(Lerp(pnl._hoverFrac or 0, 27, 35))
        _C.PRESET_FILL.b = math.floor(Lerp(pnl._hoverFrac or 0, 32, 40))
        _C.PRESET_OUT.r  = 58 + math.floor(18 * (pnl._hoverFrac or 0))
        _C.PRESET_OUT.b  = 112 + math.floor(22 * (pnl._hoverFrac or 0))
        local presetText = tostring(pnl._activePreset or 1)
        local iconW = R:X(19)
        local iconH = R:Y(20)
        local contentGap = R:X(12)
        surface.SetFont(_presetFont)
        local textW = surface.GetTextSize(presetText)
        local contentW = textW + contentGap + iconW
        local contentX = math.floor((w - contentW) * 0.5)
        local textCenterX = contentX + textW * 0.5
        local iconX = contentX + textW + contentGap
        local iconY = math.floor((h - iconH) * 0.5)
        drawRoundedPanel(0, 0, w, h, R:Y(22), _C.PRESET_FILL, _C.PRESET_OUT)
        draw.SimpleText(presetText, _presetFont, textCenterX, h * 0.5 - R:Y(1), _C.PRESET_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        Materials:Draw(color_white, "skilltree_sub_preset_icon", iconX, iconY, iconW, iconH, "noclamp smooth")
    end

    presetPager.DoClick = function(pnl)
        local presetCount = math.max(1, ST:GetPresetCount())
        local nextPreset = ((tonumber(pnl._activePreset) or 1) % presetCount) + 1
        ST:RequestSetActivePreset(nextPreset)
    end

    presetPager.DoRightClick = function(pnl)
        local presetCount = math.max(1, ST:GetPresetCount())
        local currentPreset = tonumber(pnl._activePreset) or 1
        local previousPreset = currentPreset - 1
        if previousPreset < 1 then previousPreset = presetCount end
        ST:RequestSetActivePreset(previousPreset)
    end

    local slotsPanel = vgui.Create("DPanel", slotsTray)
    slotsPanel:SetPos(R:XY(18, 16))
    slotsPanel:SetSize(slotsTray:GetWide() - R:X(36), slotsTray:GetTall() - R:Y(32))
    slotsPanel.Paint = nil
    local divider = vgui.Create("DPanel", rightPanel)
    divider:SetPos(0, R:Y(454))
    divider:SetSize(rightPanel:GetWide(), 1)
    divider.Paint = function(_, w, h) RNDX().Rect(R:X(22), 0, w - R:X(44), h):Color(_C.COL_DIVIDER):Draw() end
    local detailsBody = vgui.Create("DPanel", rightPanel)
    detailsBody:SetPos(0, 0)
    detailsBody:SetSize(rightPanel:GetWide(), rightPanel:GetTall())
    detailsBody.Paint = nil
    do
        local nextTabX = 0
        local tabFont        = Font:GetNamed("Poppins", "Medium",   15)
        local tabFontActive  = Font:GetNamed("Poppins", "SemiBold", 15)
        local tabFontDotIcon = Font:GetNamed("Poppins", "SemiBold", 11)
        surface.SetFont(tabFont)
        for index = 1, #ST.Tree do
            local tabCategory = ST.Tree[index]
            local title = tostring(tabCategory.title or tabCategory.id or "?")
            local textW = surface.GetTextSize(title)
            local buttonW = math.max(R:X(128), textW + R:X(42))
            local tabBtn = vgui.Create("DButton", tabsPanel)
            tabBtn:SetPos(nextTabX, 0)
            tabBtn:SetSize(buttonW, tabsPanel:GetTall())
            tabBtn:SetText("")
            tabBtn:SetCursor("hand")
            tabBtn._categoryId = tostring(tabCategory.id or "")
            tabBtn._categoryTitle = title
            tabBtn._categoryColor = tabCategory.color or _C.COL_ACCENT_SOFT
            tabBtn.Paint = function(pnl, w, h)
                local isActive = tostring(tabsPanel._activeCategoryId or "") == tostring(pnl._categoryId or "")
                pnl._activeFrac = smooth(pnl._activeFrac, isActive and 1 or 0, 12)
                local col = pnl._categoryColor
                -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                _C.TAB_BASE.r = math.floor(Lerp(pnl._activeFrac, 196, col.r))
                _C.TAB_BASE.g = math.floor(Lerp(pnl._activeFrac, 196, col.g))
                _C.TAB_BASE.b = math.floor(Lerp(pnl._activeFrac, 196, col.b))
                if pnl:IsHovered() then RNDX().Rect(0, 0, w, h):Rad(R:Y(10)):Color(_C.TAB_HOVER_BG):Draw() end
                _C.TAB_DOT.r, _C.TAB_DOT.g, _C.TAB_DOT.b, _C.TAB_DOT.a = col.r, col.g, col.b, 28 + math.floor(46 * pnl._activeFrac)
                RNDX().Circle(R:X(12), h * 0.5, R:X(12)):Color(_C.TAB_DOT):Draw()
                draw.SimpleText("T", tabFontDotIcon, R:X(12), h * 0.5, _C.TAB_BASE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(pnl._categoryTitle, isActive and tabFontActive or tabFont, R:X(30), h * 0.5, _C.TAB_BASE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            tabBtn.DoClick = function()
                tabsPanel._activeCategoryId = tostring(tabCategory.id or "")
                frame._activeCategoryId = tostring(tabCategory.id or "")
                ST.Client.loadoutCategoryId = tostring(tabCategory.id or "")
                ST.Client.selectedAbilityId = nil
                if Mantle and Mantle.func and Mantle.func.sound then Mantle.func.sound() end
                if IsValid(frame) then frame:RefreshData() end
            end

            tabsPanel._buttons[#tabsPanel._buttons + 1] = tabBtn
            nextTabX = nextTabX + buttonW + R:X(12)
        end
    end

    function frame:RefreshData()
        local loadout = getClientLoadout()
        local allEntries, visibleEntries = resolveVisibleEntries(self)
        local searchValue = getSearchValue(self)
        local selectedAbilityId = getSelectedAbilityId(visibleEntries)
        local selectedEntry = getAbilityById(visibleEntries, selectedAbilityId)
        local hasAnyEntries = #allEntries > 0
        local hasVisibleEntries = #visibleEntries > 0
        local activePreset = tonumber(loadout.active_preset) or 1
        local slotCount = ST:GetBindSlotCount()
        local selectedMeta = selectedEntry and getAbilityMeta(selectedEntry) or nil
        local detailStats = buildAbilityStats(selectedEntry)
        if selectedMeta then
            featureChip._meta = selectedMeta
            if IsValid(featureChip._label) then featureChip._label:SetText(selectedMeta.subtype_title ~= "" and selectedMeta.subtype_title or selectedMeta.ability_title) end
            if IsValid(featureChip._subLabel) then featureChip._subLabel:SetText(selectedMeta.category_title) end
        else
            featureChip._meta = nil
            if IsValid(featureChip._label) then featureChip._label:SetText("Aucun sous-type") end
            if IsValid(featureChip._subLabel) then featureChip._subLabel:SetText("") end
        end

        tabsPanel:SetVisible(hasAnyEntries)
        featureChip:SetVisible(hasVisibleEntries)
        presetPager._activePreset = activePreset
        local activeCategoryId = getFrameCategoryId(self, allEntries)
        tabsPanel._activeCategoryId = activeCategoryId
        ST.Client.loadoutCategoryId = activeCategoryId
        tabsPanel:InvalidateLayout(true)
        if hasVisibleEntries then
            abilityArea:SetPos(R:XY(18, 130))
            abilityArea:SetSize(topLeftPanel:GetWide() - R:X(36), topLeftPanel:GetTall() - R:Y(162))
        elseif hasAnyEntries then
            abilityArea:SetPos(R:XY(18, 68))
            abilityArea:SetSize(topLeftPanel:GetWide() - R:X(36), topLeftPanel:GetTall() - R:Y(100))
        else
            abilityArea:SetPos(R:XY(18, 20))
            abilityArea:SetSize(topLeftPanel:GetWide() - R:X(36), topLeftPanel:GetTall() - R:Y(52))
        end

        abilityArea:Clear()
        local abilityCanvas = vgui.Create("DPanel", abilityArea)
        abilityCanvas:Dock(TOP)
        abilityCanvas:SetTall(math.max(R:Y(230), math.ceil(math.max(#visibleEntries, 4) / 4) * R:Y(118)))
        abilityCanvas.Paint = function(_, w, h)
            if hasVisibleEntries then return end
            local titleText = searchValue ~= "" and "Aucun resultat" or (hasAnyEntries and "Aucune competence dans cette categorie" or "Aucune competence debloquee")
            local descText = searchValue ~= "" and "Aucune competence ne correspond a votre recherche." or (hasAnyEntries and "Changez de categorie ou debloquez d'autres competences." or "Debloquez une competence dans l'arbre pour la voir ici.")
            draw.SimpleText(titleText, Font:GetNamed("Poppins", "SemiBold", 24), w * 0.5, h * 0.5 - R:Y(12), _C.COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(descText, Font:GetNamed("Poppins", "Medium", 15), w * 0.5, h * 0.5 + R:Y(18), _C.ABILITY_EMPTY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local orbSize = R:Y(76)
        local colGap = R:X(22)
        local entryRowGap = R:Y(22)
        local startX = R:X(10)
        local startY = R:Y(10)
        -- Caches de polices pour orb.Paint et slot.Paint (évite Font:GetNamed par frame)
        local _orbFallbackFont = Font:GetNamed("Poppins", "SemiBold", 22)
        local _slotFontAbility = Font:GetNamed("Poppins", "SemiBold", 28)
        local _slotFontEmpty   = Font:GetNamed("Poppins", "SemiBold", 34)
        local _slotFontBind    = Font:GetNamed("Poppins", "Medium",   16)
        if hasVisibleEntries then
            for entryIndex, entry in ipairs(visibleEntries) do
                local row = math.floor((entryIndex - 1) / 4)
                local col = (entryIndex - 1) % 4
                local x = startX + col * (orbSize + colGap)
                local y = startY + row * (orbSize + entryRowGap)
                local orb = vgui.Create("DButton", abilityCanvas)
                orb:SetPos(x, y)
                orb:SetSize(orbSize, orbSize)
                orb:SetText("")
                orb:SetCursor("hand")
                orb._entry = entry
                orb._selected = entry.id == selectedAbilityId
                if entry.bindable == true then orb:Droppable("VERSE::SkillTree::AbilityOrb") end
                orb.Paint = function(pnl, w, h)
                    pnl._hoverFrac = smooth(pnl._hoverFrac, pnl:IsHovered() and 1 or 0, 16)
                    pnl._selectedFrac = smooth(pnl._selectedFrac, pnl._selected and 1 or 0, 12)
                    local bindable = pnl._entry.bindable == true
                    local accent = bindable and _C.COL_ACCENT_SOFT or _C.COL_SLOT
                    -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                    RNDX().Circle(w * 0.5, h * 0.5, w):Color(_C.ORB_SHADOW):DropShadow(R:X(20), R:X(26)):Draw()
                    _C.ORB_FILL.a = 150 + math.floor(28 * pnl._hoverFrac)
                    RNDX().Circle(w * 0.5, h * 0.5, w):Color(_C.ORB_FILL):Draw()
                    _C.ORB_RING.r, _C.ORB_RING.g, _C.ORB_RING.b = accent.r, accent.g, accent.b
                    _C.ORB_RING.a = 90 + math.floor(150 * pnl._selectedFrac) + math.floor(36 * pnl._hoverFrac)
                    RNDX().Circle(w * 0.5, h * 0.5, w):Outline(pnl._selected and 3 or 2):Color(_C.ORB_RING):Draw()
                    _C.ORB_ICON.a = bindable and 230 or 170
                    drawAbilityVisual(pnl._entry.id, 0, 0, w, h, _C.ORB_ICON, _orbFallbackFont)
                end

                orb.DoClick = function()
                    ST.Client.selectedAbilityId = entry.id
                    if IsValid(frame) then frame:RefreshData() end
                end
            end
        end

        slotsPanel:Clear()
        local slotDiameter = R:Y(106)
        local slotGap = R:X(44)
        local totalSlotsW = slotCount * slotDiameter + math.max(0, slotCount - 1) * slotGap
        if totalSlotsW > slotsPanel:GetWide() then
            slotGap = math.floor((slotsPanel:GetWide() - slotCount * slotDiameter) / math.max(1, slotCount - 1))
            totalSlotsW = slotCount * slotDiameter + math.max(0, slotCount - 1) * slotGap
        end

        local slotStartX = math.floor((slotsPanel:GetWide() - totalSlotsW) * 0.5)
        local slotY = math.floor((slotsPanel:GetTall() - slotDiameter) * 0.5) - R:Y(10)
        for slotIndex = 1, slotCount do
            local currentSlotIndex = slotIndex
            local abilityId = ST:GetBoundAbilityId(loadout, slotIndex, activePreset)
            local slot = vgui.Create("DButton", slotsPanel)
            slot:SetPos(slotStartX + (currentSlotIndex - 1) * (slotDiameter + slotGap), slotY)
            slot:SetSize(slotDiameter, slotDiameter)
            slot:SetText("")
            slot._abilityId = abilityId
            slot._slotIndex = currentSlotIndex
            slot._bindLabel = ST:GetSlotBindingLabel(currentSlotIndex)
            slot._capture = ST:IsCapturingSlotBind(currentSlotIndex)
            slot:SetTooltip("Key: " .. tostring(slot._bindLabel) .. "\nLMB: bind key\nRMB: clear slot\nMMB: clear binding")
            slot:Receiver("VERSE::SkillTree::AbilityOrb", function(_, panels, dropped)
                if not dropped then return end
                local dragged = panels and panels[1] or nil
                if not IsValid(dragged) or not dragged._entry then return end
                ST:RequestAssignSlot(activePreset, currentSlotIndex, dragged._entry.id)
            end)

            slot.Paint = function(pnl, w, h)
                pnl._hoverFrac = smooth(pnl._hoverFrac, pnl:IsHovered() and 1 or 0, 16)
                local hasAbility = pnl._abilityId ~= ""
                local accent = hasAbility and _C.COL_ACCENT_SOFT or _C.COL_SLOT
                -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                _C.SLOT_GLOW.a = 8 + math.floor(4 * pnl._hoverFrac)
                RNDX().Circle(w * 0.5, h * 0.5, w - R:X(4)):Color(_C.SLOT_GLOW):Shadow(R:X(20), R:X(34)):Draw()
                if hasAbility then
                    _C.SLOT_ACCENT_SH.r, _C.SLOT_ACCENT_SH.g, _C.SLOT_ACCENT_SH.b = accent.r, accent.g, accent.b
                    _C.SLOT_ACCENT_SH.a = 14 + math.floor(8 * pnl._hoverFrac)
                    RNDX().Circle(w * 0.5, h * 0.5, w - R:X(8)):Color(_C.SLOT_ACCENT_SH):Shadow(R:X(10), R:X(18)):Draw()
                end
                _C.SLOT_BG.a = hasAbility and 212 or 158
                RNDX().Circle(w * 0.5, h * 0.5, w):Color(_C.SLOT_BG):Draw()
                RNDX().Circle(w * 0.5, h * 0.5, w):Outline(2):Color(_C.SLOT_INNER):Draw()
                _C.SLOT_RING.r, _C.SLOT_RING.g, _C.SLOT_RING.b = accent.r, accent.g, accent.b
                _C.SLOT_RING.a = 92 + math.floor(54 * pnl._hoverFrac)
                RNDX().Circle(w * 0.5, h * 0.5, w):Outline(hasAbility and 3 or 2):Color(_C.SLOT_RING):Draw()
                if pnl._capture then RNDX().Circle(w * 0.5, h * 0.5, w - R:X(6)):Color(_C.SLOT_CAPTURE):DropShadow(R:X(18), R:X(28)):Draw() end
                if hasAbility then
                    drawAbilityVisual(pnl._abilityId, 0, 0, w, h, _C.SLOT_ICON, _slotFontAbility)
                else
                    draw.SimpleText("?", _slotFontEmpty, w * 0.5, h * 0.5, _C.SLOT_EMPTY_Q, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                local bindColor = pnl._capture and _C.SLOT_BIND_CAP or _C.SLOT_BIND_NRM
                draw.SimpleText(pnl._bindLabel, _slotFontBind, w * 0.5, h - R:Y(13), bindColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            slot.OnMousePressed = function(pnl, mouseCode)
                if mouseCode == MOUSE_LEFT and not (input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)) then
                    ST:StartSlotBindCapture(currentSlotIndex)
                    return
                end
                if mouseCode == MOUSE_MIDDLE then
                    ST:ClearSlotBinding(currentSlotIndex)
                    return
                end
                return DButton.OnMousePressed(pnl, mouseCode)
            end

            slot.DoRightClick = function() if abilityId ~= "" then ST:RequestClearSlot(activePreset, currentSlotIndex) end end
        end

        detailsBody:Clear()
        if hasVisibleEntries then
            local _largeOrbFont = Font:GetNamed("Poppins", "SemiBold", 44)
            local largeOrb = vgui.Create("DPanel", detailsBody)
            largeOrb:SetPos(math.floor((detailsBody:GetWide() - R:X(172)) * 0.5), R:Y(46))
            largeOrb:SetSize(R:XY(172, 172))
            largeOrb.Paint = function(_, w, h)
                local accent = selectedEntry and (selectedEntry.bindable and _C.COL_ACCENT_SOFT or _C.COL_SLOT) or _C.COL_SLOT
                -- Mutation des couleurs pré-allouées (évite Color() à chaque frame)
                RNDX().Circle(w * 0.5, h * 0.5 + R:Y(6), w):Color(_C.LARGE_SHADOW):DropShadow(R:X(16), R:X(22)):Draw()
                RNDX().Circle(w * 0.5, h * 0.5, w):Color(_C.LARGE_BG):Draw()
                if selectedEntry then
                    _C.LARGE_RING.r, _C.LARGE_RING.g, _C.LARGE_RING.b, _C.LARGE_RING.a = accent.r, accent.g, accent.b, 210
                    RNDX().Circle(w * 0.5, h * 0.5, w):Outline(3):Color(_C.LARGE_RING):Draw()
                    drawAbilityVisual(selectedEntry.id, 0, 0, w, h, _C.LARGE_ICON, _largeOrbFont)
                end
            end
        else
            local emptyDetails = vgui.Create("DPanel", detailsBody)
            emptyDetails:SetPos(R:X(34), R:Y(88))
            emptyDetails:SetSize(detailsBody:GetWide() - R:X(68), R:Y(96))
            local _emptyDetailsFontTitle = Font:GetNamed("Poppins", "SemiBold", 22)
            local _emptyDetailsFontSub   = Font:GetNamed("Poppins", "Medium",   15)
            emptyDetails.Paint = function(_, w, h)
                draw.SimpleText("Aucune technique disponible", _emptyDetailsFontTitle, w * 0.5, h * 0.5 - R:Y(12), _C.COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Debloquez des competences dans l'arbre pour afficher leurs details ici.", _emptyDetailsFontSub, w * 0.5, h * 0.5 + R:Y(16), _C.EMPTY_SUB, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        local title = vgui.Create("DLabel", detailsBody)
        title:SetPos(R:X(26), R:Y(238))
        title:SetSize(detailsBody:GetWide() - R:X(52), R:Y(42))
        title:SetText(selectedEntry and ST:GetAbilityDisplayName(selectedEntry.id) or "Aucune technique disponible")
        title:SetFont(Font:GetNamed("Poppins", "SemiBold", 24))
        title:SetContentAlignment(5)
        title:SetTextColor(_C.COL_TEXT)
        title:SetVisible(hasVisibleEntries)
        local metaRow = vgui.Create("DPanel", detailsBody)
        metaRow:SetPos(R:X(42), R:Y(282))
        metaRow:SetSize(detailsBody:GetWide() - R:X(84), R:Y(34))
        local _metaRowFontCat     = Font:GetNamed("Poppins", "Medium",   13)
        local _metaRowFontSubtype = Font:GetNamed("Poppins", "SemiBold", 13)
        metaRow.Paint = function(_, w, h)
            if not hasVisibleEntries or not selectedMeta then return end
            local categoryIconSize = R:Y(16)
            local subtypeIconSize = R:Y(18)
            local x = 0
            if selectedMeta.category_icon ~= "" then
                Materials:Draw(color_white, selectedMeta.category_icon, x, math.floor((h - categoryIconSize) * 0.5), categoryIconSize, categoryIconSize, "noclamp smooth")
                x = x + categoryIconSize + R:X(8)
            end

            draw.SimpleText(selectedMeta.category_title, _metaRowFontCat, x, h * 0.5, _C.META_CAT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetFont(_metaRowFontCat)
            x = x + surface.GetTextSize(selectedMeta.category_title) + R:X(16)
            if selectedMeta.subtype_icon ~= "" then
                Materials:Draw(color_white, selectedMeta.subtype_icon, x, math.floor((h - subtypeIconSize) * 0.5), subtypeIconSize, subtypeIconSize, "noclamp smooth")
                x = x + subtypeIconSize + R:X(8)
            end

            draw.SimpleText(selectedMeta.subtype_title, _metaRowFontSubtype, x, h * 0.5, _C.META_SUBTYPE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        metaRow:SetVisible(hasVisibleEntries)
        local desc = vgui.Create("DLabel", detailsBody)
        desc:SetPos(R:X(34), R:Y(326))
        desc:SetSize(detailsBody:GetWide() - R:X(68), R:Y(96))
        desc:SetWrap(true)
        desc:SetAutoStretchVertical(true)
        desc:SetText(selectedEntry and ST:GetAbilityDescription(selectedEntry.id) or "Debloquez une technique dans l'arbre puis selectionnez-la pour voir ses informations ici.")
        desc:SetFont(Font:GetNamed("Poppins", "Medium", 15))
        desc:SetContentAlignment(8)
        desc:SetTextColor(Color(232, 232, 236))
        desc:SetVisible(hasVisibleEntries)
        local sectionTitle = vgui.Create("DLabel", detailsBody)
        sectionTitle:SetPos(0, R:Y(500))
        sectionTitle:SetSize(detailsBody:GetWide(), R:Y(32))
        sectionTitle:SetText("Caracteristiques")
        sectionTitle:SetFont(Font:GetNamed("Poppins", "SemiBold", 22))
        sectionTitle:SetContentAlignment(5)
        sectionTitle:SetTextColor(_C.COL_TEXT)
        sectionTitle:SetVisible(hasVisibleEntries and #detailStats > 0)
        local _rowFontLabel = Font:GetNamed("Poppins", "SemiBold", 15)
        local _rowFontValue = Font:GetNamed("Poppins", "SemiBold", 18)
        for statIndex = 1, #detailStats do
            local stat = detailStats[statIndex]
            local row = vgui.Create("DPanel", detailsBody)
            row:SetPos(R:X(16), R:Y(552 + (statIndex - 1) * 40))
            row:SetSize(detailsBody:GetWide() - R:X(32), R:Y(30))
            row.Paint = function(_, w, h)
                drawRoundedPanel(0, 0, w, h, R:Y(9), _C.ROW_BG1, _C.ROW_BG2)
                draw.SimpleText(stat.label, _rowFontLabel, R:X(18), h * 0.5, _C.COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(stat.value, _rowFontValue, R:X(122), h * 0.5, _C.COL_ACCENT_SOFT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        if hasVisibleEntries and #detailStats <= 0 then
            local emptyStats = vgui.Create("DLabel", detailsBody)
            emptyStats:SetPos(R:X(34), R:Y(548))
            emptyStats:SetSize(detailsBody:GetWide() - R:X(68), R:Y(48))
            emptyStats:SetText("Aucune caracteristique exploitable pour cette technique.")
            emptyStats:SetFont(Font:GetNamed("Poppins", "Medium", 15))
            emptyStats:SetContentAlignment(5)
            emptyStats:SetTextColor(Color(184, 186, 194))
        end
    end

    frame.OnClose = function()
        ST:CancelSlotBindCapture(true)
        if ST.Client then ST.Client.loadoutFrame = nil end
    end

    ST.Client.loadoutFrame = frame
    frame:RefreshData()
    ST:RequestSync()
end

VERSE.Commands.Add("verse_skill_loadout", function() ST:OpenLoadoutMenu() end, nil, "client")
for slotIndex = 1, ST:GetBindSlotCount() do
    VERSE.Commands.Add("verse_skill_slot_" .. tostring(slotIndex), function() ST:RequestUseSlot(slotIndex) end, nil, "client")
end

-- Bascule entre le set 1 et le set 2
VERSE.Commands.Add("verse_skill_next_preset", function()
    -- Lecture directe de ST.Client.loadout : GetLoadoutForPlayer passe par
    -- GetCharacterUID qui peut retourner nil côté client et renvoyer le loadout
    -- par défaut (active_preset=1) à chaque appui → G enverrait toujours "set 2".
    local clientLoadout = ST.Client and ST.Client.loadout
    local current = math.max(1, math.floor(tonumber(clientLoadout and clientLoadout.active_preset) or 1))
    local nextPr  = current == 1 and 2 or 1

    -- Mise à jour optimiste : la prochaine lecture au prochain appui verra nextPr.
    if clientLoadout then
        clientLoadout.active_preset = nextPr
    elseif ST.Client then
        ST.Client.loadout = { active_preset = nextPr }
    end

    ST:RequestSetActivePreset(nextPr)
    notifyClient("Set de techniques : " .. tostring(nextPr), NOTIFY_HINT)
end, nil, "client")
