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
function CH:FactionSelect(slot)
    local scrw, scrh = 1920, 1080
    local cfg = self:GetConfig()
    local factions = cfg.Factions or {}
    local factionList = {}
    for id, f in pairs(factions) do
        factionList[#factionList + 1] = {
            id = id,
            data = istable(f) and f or {}
        }
    end

    table.sort(factionList, function(a, b) return (a.id or "") < (b.id or "") end)
    local visibleSlots = math.max(1, #factionList)
    local cardW, cardH = 555, 808
    local spacingX = 70
    local cardY = 87
    local totalW = visibleSlots * cardW + (visibleSlots - 1) * spacingX
    local startX = (scrw - totalW) * 0.5
    local factionFrame = vgui.Create("MantleFrame")
    factionFrame:SetSize(R:XY(scrw, scrh))
    factionFrame:Center()
    factionFrame:MakePopup()
    factionFrame:SetDraggable(false)
    factionFrame:LiteMode()
    factionFrame:SetAlphaBackground(false)
    factionFrame:SetClosable(false)
    factionFrame:DisableCloseBtn()
    factionFrame.Paint = function(_, w, h) Materials:Draw(color_white, "character_main_background", 0, 0, w, h) end
    local selectedFaction = nil
    local factionCards = {}
    for i, faction in ipairs(factionList) do
        local fid = faction.id
        local fdat = faction.data
        local bgKey = "character_" .. fid .. "_fraction_background"
        local miniKey = "character_" .. fid .. "_fraction"
        local cx = startX + (i - 1) * (cardW + spacingX)
        local card = vgui.Create("VCFactionCard", factionFrame)
        card:SetSize(R:XY(cardW, cardH))
        card:SetPos(R:XY(cx, cardY))
        card:SetFactionData(fid, fdat.name or fid, bgKey, miniKey)
        card:SetSelected(false)
        card:SetOnChoose(function(_, pickedFactionId)
            if not isstring(pickedFactionId) or pickedFactionId == "" then return end
            selectedFaction = pickedFactionId
            for _, c in ipairs(factionCards) do
                if IsValid(c) and c.SetSelected then c:SetSelected(c == card) end
            end
        end)

        factionCards[i] = card
        bindAnimatedCard(card, R:X(cx), R:Y(cardY), {
            hoverLift = R:Y(10),
            pressDrop = R:Y(5),
            clickDuration = 0.14,
        })
    end

    local btnW, btnH = 316, 64
    local btnX = scrw * 0.5 - btnW * 0.5
    local btnY = scrh - btnH - 60
    local btnValider = vgui.Create("MantleBtn", factionFrame)
    btnValider:SetSize(R:XY(btnW, btnH))
    btnValider:SetPos(R:XY(btnX, btnY))
    btnValider:SetTxt("Valider")
    btnValider:SetFont(Font:GetNamed("Poppins", "Bold", 40))
    btnValider:SetRipple(true)
    btnValider:SetGradient(false)
    btnValider:SetColor(Color(77, 77, 77))
    btnValider:SetColorHover(Color(111, 111, 111))
    btnValider.DoClick = function()
        if not selectedFaction then return end
        factionFrame:Close()
        CH:CharacterCreate(slot, selectedFaction)
    end

    local btnRetourFaction = vgui.Create("MantleBtn", factionFrame)
    btnRetourFaction:SetSize(R:XY(200, 52))
    btnRetourFaction:SetPos(R:XY(30, scrh - 52 - 30))
    btnRetourFaction:SetTxt("Retour")
    btnRetourFaction:SetFont(Font:GetNamed("Poppins", "Bold", 18))
    btnRetourFaction:SetRipple(true)
    btnRetourFaction:SetGradient(false)
    btnRetourFaction:SetColor(Mantle.color.button)
    btnRetourFaction:SetColorHover(Mantle.color.button_hovered)
    btnRetourFaction.DoClick = function()
        factionFrame:Close()
        CH:CharacterSelect(CH.Client.list)
    end
end