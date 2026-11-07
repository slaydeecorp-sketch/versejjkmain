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
function CH:OpenAdminPanel()
    if IsValid(characterAdminFrame) then characterAdminFrame:Remove() end
    if not self:ConfigBool("Enabled", true) then return end
    if not (self.CanAccessAdminCharacters and self:CanAccessAdminCharacters(LocalPlayer())) then
        self:NotifyError("no_access", 4)
        return
    end

    local GAP = R:RS(8)
    local BHEIGHT = R:RS(38)
    local BTN_W = R:RS(220)
    characterAdminFrame = vgui.Create("MantleFrame")
    characterAdminFrame:SetSize(R:XY(1440, 860))
    characterAdminFrame:Center()
    characterAdminFrame:MakePopup()
    characterAdminFrame:SetTitle("Characters")
    characterAdminFrame:SetCenterTitle("Characters")
    characterAdminFrame.OnRemove = function(s) if characterAdminFrame == s then characterAdminFrame = nil end end
    local actionRow = vgui.Create("DPanel", characterAdminFrame)
    actionRow:Dock(BOTTOM)
    actionRow:SetTall(BHEIGHT)
    actionRow.Paint = nil
    local searchEntry = vgui.Create("MantleEntry", characterAdminFrame)
    searchEntry:Dock(TOP)
    searchEntry:SetTall(R:RS(52))
    searchEntry:DockMargin(0, 0, 0, GAP)
    searchEntry:SetTitle("Search")
    searchEntry:SetPlaceholder("Name / SteamID64 / Faction / Job")
    if searchEntry.SetUpdateOnType then searchEntry:SetUpdateOnType(true) end
    local btnDelete = vgui.Create("MantleBtn", actionRow)
    btnDelete:Dock(RIGHT)
    btnDelete:SetWide(BTN_W)
    btnDelete:SetTxt("Delete")
    btnDelete:SetColor(Color(170, 70, 70))
    local btnInventory = vgui.Create("MantleBtn", actionRow)
    btnInventory:Dock(RIGHT)
    btnInventory:SetWide(BTN_W)
    btnInventory:DockMargin(0, 0, GAP, 0)
    btnInventory:SetTxt("Inventaire")
    btnInventory:SetColor(Color(80, 120, 180))
    local btnRefresh = vgui.Create("MantleBtn", actionRow)
    btnRefresh:Dock(LEFT)
    btnRefresh:SetWide(BTN_W)
    btnRefresh:SetTxt("Refresh")
    btnRefresh:SetColor(Mantle.color.theme)
    local aTable = vgui.Create("MantleTable", characterAdminFrame)
    aTable:Dock(FILL)
    aTable:DockMargin(0, 0, 0, GAP)
    aTable:AddColumn("ID", R:RS(80), nil, true)
    aTable:AddColumn("SteamID64", R:RS(220), nil, true)
    aTable:AddColumn("Slot", R:RS(80), nil, true)
    aTable:AddColumn("Name", R:RS(220), nil, true)
    aTable:AddColumn("Faction", R:RS(180), nil, true)
    aTable:AddColumn("Gender", R:RS(140), nil, true)
    aTable:AddColumn("Job", R:RS(180), nil, true)
    local function resolveAdminFactionName(factionId)
        factionId = tostring(factionId or ""):Trim()
        if factionId == "" then return "-" end
        local factionCfg = CH:FactionsEnabled() and CH:GetConfig("Factions", factionId) or nil
        if istable(factionCfg) and tostring(factionCfg.name or "") ~= "" then return tostring(factionCfg.name) end
        return string.upper(factionId)
    end

    local function resolveAdminGenderName(genderId)
        genderId = tostring(genderId or ""):Trim()
        if genderId == "female" then return Language("character.gender_female") end
        if genderId == "male" then return Language("character.gender_male") end
        if genderId == "" then return "-" end
        return genderId
    end

    local function getAdminSearchTerm()
        if not IsValid(searchEntry) or not searchEntry.GetValue then return "" end
        return string.lower(tostring(searchEntry:GetValue() or ""):Trim())
    end

    local function matchesAdminSearch(char, displayName, factionName, genderName, jobId, searchTerm)
        if searchTerm == "" then return true end
        local haystack = {tostring(char.id or ""), tostring(char.steamid64 or ""), tostring(char.slot or ""), tostring(displayName or ""), tostring(factionName or ""), tostring(genderName or ""), tostring(jobId or ""), tostring(char.firstname or ""), tostring(char.lastname or ""), tostring(char.nickname or ""), tostring(char.faction or ""), tostring(char.gender or ""),}
        for i = 1, #haystack do
            local value = string.lower(string.Trim(haystack[i]))
            if value ~= "" and string.find(value, searchTerm, 1, true) then return true end
        end
        return false
    end

    characterAdminFrame._populateAdminList = function(selfFrame, list)
        if not IsValid(aTable) then return end
        aTable:Clear()
        list = istable(list) and list or {}
        local searchTerm = getAdminSearchTerm()
        for _, char in ipairs(list) do
            local displayName = CH.GetDisplayName and CH:GetDisplayName(char) or (tostring(char.firstname or "") .. " " .. tostring(char.lastname or "")):Trim()
            if displayName == "" then displayName = "-" end
            local factionName = resolveAdminFactionName(char.faction)
            local genderName = resolveAdminGenderName(char.gender)
            local jobId = tostring(char.job_id or "-")
            if not matchesAdminSearch(char, displayName, factionName, genderName, jobId, searchTerm) then continue end
            aTable:AddItem(tonumber(char.id) or 0, tostring(char.steamid64 or "0"), tonumber(char.slot) or 0, displayName, factionName, genderName, jobId)
        end
    end

    searchEntry.OnValueChange = function() if IsValid(characterAdminFrame) and isfunction(characterAdminFrame._populateAdminList) then characterAdminFrame:_populateAdminList(CH.Client.adminList) end end
    btnRefresh.DoClick = function() CH:RequestAdminList() end
    btnInventory.DoClick = function()
        local row = IsValid(aTable) and aTable:GetSelectedRow() or nil
        if not row then
            if IsValid(characterAdminFrame) then characterAdminFrame:Notify("Select a character row first.", 3) end
            return
        end
        local charId = tonumber(row[1]) or 0
        local charName = tostring(row[4] or "?")
        if charId <= 0 then return end
        local INV = VERSE.Inventory
        if INV and INV.OpenAdminInventory then
            INV:OpenAdminInventory(charId, charName)
        end
    end
    btnDelete.DoClick = function()
        local row = IsValid(aTable) and aTable:GetSelectedRow() or nil
        if not row then
            if IsValid(characterAdminFrame) then characterAdminFrame:Notify("Select a character row first.", 3) end
            return
        end

        local targetSteamID64 = tostring(row[2] or ""):Trim()
        local slot = tonumber(row[3]) or 0
        if targetSteamID64 == "" or slot <= 0 then
            if IsValid(characterAdminFrame) then characterAdminFrame:Notify("Select a character row first.", 3) end
            return
        end

        local localSID64 = IsValid(LocalPlayer()) and LocalPlayer():SteamID64() or "0"
        local canDeleteTarget = false
        if targetSteamID64 == localSID64 then
            canDeleteTarget = CH.CanDeleteOwnCharacters and CH:CanDeleteOwnCharacters(LocalPlayer())
        else
            canDeleteTarget = CH.CanDeleteOtherCharacters and CH:CanDeleteOtherCharacters(LocalPlayer())
        end

        if not canDeleteTarget then
            CH:NotifyError("no_access", 4)
            return
        end

        local deleteName = tostring(row[4] or "-")
        Derma_Query(string.format("Delete %s (slot %d)?", deleteName, slot), "Delete", "Delete", function() CH:RequestAdminDelete(targetSteamID64, slot) end, "Cancel", function() end)
    end

    characterAdminFrame:_populateAdminList(CH.Client.adminList)
    CH:RequestAdminList()
end

VERSE.Commands.Add("verse_characters", function()
    if not CH:ConfigBool("Enabled", true) then return end
    CH.Client.selected = nil
    if IsValid(characterCreateFrame) then characterCreateFrame:Close() end
    if IsValid(characterAdminFrame) then characterAdminFrame:Close() end
    if IsValid(characterSelectFrame) then characterSelectFrame:Close() end
    CH:RequestList()
end, nil, "client")

VERSE.Commands.Add("verse_characters_admin", function()
    if not CH:ConfigBool("Enabled", true) then return end
    if IsValid(characterCreateFrame) then characterCreateFrame:Close() end
    if IsValid(characterSelectFrame) then characterSelectFrame:Close() end
    CH:OpenAdminPanel()
end, nil, "client")