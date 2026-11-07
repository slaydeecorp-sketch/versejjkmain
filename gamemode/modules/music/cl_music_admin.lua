local M = VERSE.Music
if not M then return end
local R = VERSE.Responsive
local Materials = VERSE.Materials
local Font = VERSE.Fonts
local L = VERSE.L
Materials:SetAlias("ost_admin_background", "verse/traders/main_background")
M._adminFrame = nil
M._adminSelectedTrack = nil
hook.Add("VERSE::Music::TracksUpdated", "VERSE::Music::AdminRefresh", function() if IsValid(M._adminFrame) then hook.Run("VERSE::Music::AdminRefreshList") end end)
local CLR_SIDE_BG = Color(30, 28, 40, 180)
local CLR_SIDE_OUTLINE = Color(80, 75, 110)
local CLR_RIGHT_BG = Color(55, 40, 100, 160)
local CLR_RIGHT_OUTLINE = Color(100, 80, 160)
local CLR_ROW_BG = Color(45, 42, 60, 180)
local CLR_ROW_HOVER = Color(60, 55, 80, 200)
local CLR_ROW_SELECTED = Color(80, 60, 140, 220)
local CLR_CLOSE_BG = Color(50, 50, 50)
local CLR_GREEN = Color(50, 130, 80)
local CLR_GREEN_H = Color(60, 150, 95)
local CLR_RED = Color(160, 50, 50)
local CLR_RED_H = Color(185, 60, 60)
local CLR_PURPLE = Color(122, 64, 255)
local CLR_PURPLE_H = Color(140, 80, 255)
-- ─── Couleurs Paint pré-allouées ─────────────────────────────────────────────
local _MA_COL_FRAME_OUT         = Color(50,  50,  50,  255)
local _MA_COL_FRAME_BG          = Color(255, 255, 255, 235)   -- .a muté via DrawDuplicate
local _MA_COL_CLOSE_HOV         = Color(60,  60,  60,  225)
local _MA_COL_CLOSE_X_DIM       = Color(255, 255, 255, 180)
local _MA_COL_ROW_NAME          = Color(190, 150, 255, 255)
local _MA_COL_ROW_SUB           = Color(180, 180, 195, 255)
local function cleanVal(v)
    v = tostring(v or "")
    v = string.Trim(v)
    v = string.Trim(v, '"')
    v = string.Trim(v, "'")
    return v
end

local function generateTrackId(name)
    local id = string.lower(string.Trim(name or ""))
    id = string.gsub(id, "[^%w_%-]", "_")
    id = string.gsub(id, "_+", "_")
    id = string.Trim(id, "_")
    if id == "" then id = "track_" .. os.time() end
    return id
end

function M:OpenAdminPanel()
    if IsValid(self._adminFrame) then self._adminFrame:Remove() end
    netstream.Start(M.Net.AdminRequest)
    local frameW = R:X(1010)
    local frameH = R:Y(797)
    local fTitle = Font:GetNamed("Poppins", "SemiBold", 42)
    local fRow = Font:GetNamed("Poppins", "SemiBold", 20)
    local fRowSub = Font:GetNamed("Poppins", "Regular", 16)
    local fSection = Font:GetNamed("Poppins", "SemiBold", 24)
    local fClose = Font:GetNamed("Poppins", "Bold", 22)
    local fEntry = Font:GetNamed("Poppins", "Medium", 18)
    local fEntryTitle = Font:GetNamed("Poppins", "Regular", 16)
    local fLabel = Font:GetNamed("Poppins", "Regular", 17)
    local frame = vgui.Create("MantleFrame")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("")
    frame:SetAlphaBackground(false)
    frame:DisableCloseBtn()
    self._adminFrame = frame
    self._adminSelectedTrack = nil
    frame.Paint = function(_, w, h)
        Materials:DrawDuplicate(_MA_COL_FRAME_BG, "ost_admin_background", 0, 0, w, h)
        RNDX.DrawOutlined(R:Y(15), R:X(28), R:Y(14), R:X(963), R:Y(755), _MA_COL_FRAME_OUT, 3)
        draw.SimpleText(L("music.admin_title"), fTitle, w / 2, R:Y(60), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local btnClose = vgui.Create("DButton", frame)
    btnClose:SetSize(R:X(42), R:Y(42))
    btnClose:SetPos(R:X(1010 - 42 - 52), R:Y(34))
    btnClose:SetText("")
    btnClose.Paint = function(s, w, h)
        local hov = s:IsHovered()
        RNDX.Draw(R:Y(21), 0, 0, w, h, hov and _MA_COL_CLOSE_HOV or CLR_CLOSE_BG)
        draw.SimpleText("X", fClose, w / 2, h / 2, hov and color_white or _MA_COL_CLOSE_X_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btnClose.DoClick = function() if IsValid(frame) then frame:Remove() end end
    local contentX = R:X(50)
    local contentY = R:Y(111)
    local contentH = R:Y(625)
    local sideW = R:X(340)
    local rightX = contentX + sideW + R:X(25)
    local rightW = frameW - rightX - R:X(50)
    local sidePanel = vgui.Create("DPanel", frame)
    sidePanel:SetPos(contentX, contentY)
    sidePanel:SetSize(sideW, contentH)
    sidePanel.Paint = function(_, w, h)
        RNDX.Draw(R:Y(12), 0, 0, w, h, CLR_SIDE_BG)
        RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, CLR_SIDE_OUTLINE, 1)
    end

    local btnAdd = vgui.Create("MantleBtn", sidePanel)
    btnAdd:SetSize(sideW - R:X(20), R:Y(42))
    btnAdd:SetPos(R:X(10), R:Y(10))
    btnAdd:SetTxt("+ " .. L("music.admin_add"))
    btnAdd:SetColor(CLR_GREEN)
    btnAdd:SetColorHover(CLR_GREEN_H)
    btnAdd:SetRadius(R:Y(8))
    btnAdd:SetGradient(false)
    btnAdd:SetRipple(true)
    btnAdd.DoClick = function()
        self._adminSelectedTrack = {
            isNew = true,
            track_id = "",
            name = "",
            artist = "",
            path = "",
            category = "chill",
        }

        hook.Run("VERSE::Music::AdminTrackSelected")
    end

    local trackScroll = vgui.Create("MantleScrollPanel", sidePanel)
    trackScroll:SetPos(R:X(10), R:Y(62))
    trackScroll:SetSize(sideW - R:X(20), contentH - R:Y(72))
    local function refreshTrackList()
        trackScroll:Clear()
        local tracks = M.Tracks or {}
        local btnW = sideW - R:X(20)
        local btnH = R:Y(60)
        for _, tr in ipairs(tracks) do
            local btn = vgui.Create("DButton")
            btn:SetSize(btnW, btnH)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, R:Y(6))
            btn:SetText("")
            btn:SetCursor("hand")
            -- Résoudre catName une seule fois à la création du bouton
            local _btnCatName = tr.category or ""
            for _, cat in ipairs(M.Categories) do
                if cat.id == tr.category then
                    _btnCatName = L(cat.name)
                    break
                end
            end
            local _btnSubText = (tr.artist or "") .. " • " .. _btnCatName
            btn.Paint = function(s, w, h)
                local sel = self._adminSelectedTrack and self._adminSelectedTrack.dbId == tr.dbId and not self._adminSelectedTrack.isNew
                local hov = s:IsHovered()
                local bg = sel and CLR_ROW_SELECTED or (hov and CLR_ROW_HOVER or CLR_ROW_BG)
                RNDX.Draw(R:Y(8), 0, 0, w, h, bg)
                draw.SimpleText(tr.name or tr.id, fRow, R:X(12), R:Y(10), _MA_COL_ROW_NAME, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(_btnSubText, fRowSub, R:X(12), R:Y(32), _MA_COL_ROW_SUB, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            btn.DoClick = function()
                self._adminSelectedTrack = table.Copy(tr)
                self._adminSelectedTrack.isNew = false
                hook.Run("VERSE::Music::AdminTrackSelected")
            end

            trackScroll:AddItem(btn)
        end
    end

    refreshTrackList()
    hook.Add("VERSE::Music::AdminRefreshList", "VERSE::Music::AdminRefreshScroll", function()
        if not IsValid(trackScroll) then return end
        refreshTrackList()
    end)

    hook.Add("VERSE::Music::TracksUpdated", "VERSE::Music::AdminAutoRefresh", function()
        if not IsValid(trackScroll) then return end
        refreshTrackList()
    end)

    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:SetPos(rightX, contentY)
    rightPanel:SetSize(rightW, contentH)
    rightPanel.Paint = function(_, w, h)
        RNDX.Draw(R:Y(12), 0, 0, w, h, CLR_RIGHT_BG)
        RNDX.DrawOutlined(R:Y(12), 0, 0, w, h, CLR_RIGHT_OUTLINE, 1)
    end

    local formContainer = vgui.Create("DPanel", rightPanel)
    formContainer:SetPos(R:X(25), R:Y(20))
    formContainer:SetSize(rightW - R:X(50), contentH - R:Y(40))
    formContainer.Paint = function() end
    local fields = {}
    local function buildForm()
        formContainer:Clear()
        fields = {}
        local tr = self._adminSelectedTrack
        if not tr then
            local noSel = vgui.Create("MantleText", formContainer)
            noSel:SetPos(0, R:Y(40))
            noSel:SetSize(formContainer:GetWide(), R:Y(30))
            noSel:SetFont(fSection)
            noSel:SetText(L("music.admin_select_track"))
            noSel:SetColor(Color(180, 180, 195))
            noSel:SetAlign(TEXT_ALIGN_CENTER)
            return
        end

        local fw = formContainer:GetWide()
        local halfW = (fw - R:X(15)) / 2
        local nameEntry = vgui.Create("MantleEntry", formContainer)
        nameEntry:SetPos(0, 0)
        nameEntry:SetSize(fw, R:Y(55))
        nameEntry:SetTitle(L("music.admin_name"))
        nameEntry:SetPlaceholder("Nom du track...")
        nameEntry:SetValue(cleanVal(tr.name or ""))
        nameEntry:SetFonts(fEntry, fEntryTitle)
        nameEntry:SetTextColor(color_white)
        fields.name = nameEntry
        local artistEntry = vgui.Create("MantleEntry", formContainer)
        artistEntry:SetPos(0, R:Y(70))
        artistEntry:SetSize(halfW, R:Y(55))
        artistEntry:SetTitle(L("music.admin_artist"))
        artistEntry:SetPlaceholder("Artiste...")
        artistEntry:SetValue(cleanVal(tr.artist or ""))
        artistEntry:SetFonts(fEntry, fEntryTitle)
        artistEntry:SetTextColor(color_white)
        fields.artist = artistEntry
        local catLabel = vgui.Create("DLabel", formContainer)
        catLabel:SetPos(halfW + R:X(15), R:Y(70))
        catLabel:SetSize(halfW, R:Y(16))
        catLabel:SetFont(fEntryTitle)
        catLabel:SetText(L("music.admin_category"))
        catLabel:SetTextColor(Color(200, 200, 215))
        local catCombo = vgui.Create("MantleComboBox", formContainer)
        catCombo:SetPos(halfW + R:X(15), R:Y(88))
        catCombo:SetSize(halfW, R:Y(36))
        catCombo:SetPlaceholder(L("music.admin_category"))
        catCombo:SetFonts(fEntry, fEntry, fEntryTitle)
        local selectedCat = cleanVal(tr.category or "chill")
        local selectedText = nil
        for _, cat in ipairs(M.Categories) do
            if cat.id ~= "favorites" then
                catCombo:AddChoice(L(cat.name), cat.id)
                if cat.id == selectedCat then selectedText = L(cat.name) end
            end
        end

        if selectedText then catCombo:SetSelected(selectedText, selectedCat) end
        fields.catCombo = catCombo
        local pathEntry = vgui.Create("MantleEntry", formContainer)
        pathEntry:SetPos(0, R:Y(140))
        pathEntry:SetSize(fw, R:Y(55))
        pathEntry:SetTitle(L("music.admin_path"))
        pathEntry:SetPlaceholder("sound/verse/ost/track.mp3")
        pathEntry:SetValue(cleanVal(tr.path or ""))
        pathEntry:SetFonts(fEntry, fEntryTitle)
        pathEntry:SetTextColor(color_white)
        fields.path = pathEntry
        local btnY = R:Y(215)
        local btnW = R:X(150)
        local btnH = R:Y(40)
        local btnGap = R:X(12)
        local btnSave = vgui.Create("MantleBtn", formContainer)
        btnSave:SetPos(0, btnY)
        btnSave:SetSize(btnW, btnH)
        btnSave:SetTxt(L("music.admin_save"))
        btnSave:SetColor(CLR_PURPLE)
        btnSave:SetColorHover(CLR_PURPLE_H)
        btnSave:SetRadius(R:Y(8))
        btnSave:SetGradient(false)
        btnSave:SetRipple(true)
        btnSave.DoClick = function()
            local catId = catCombo:GetSelectedData()
            local name = cleanVal(nameEntry:GetValue())
            local artist = cleanVal(artistEntry:GetValue())
            local path = cleanVal(pathEntry:GetValue())
            local data = {
                name = name,
                artist = artist,
                path = path,
                category = catId or "chill",
            }

            if tr.isNew then
                data.track_id = generateTrackId(name)
                if data.name == "" or data.path == "" then return end
                netstream.Start(M.Net.AdminCreate, data)
                self._adminSelectedTrack = nil
                hook.Run("VERSE::Music::AdminTrackSelected")
            else
                data.dbId = tr.dbId
                if not data.dbId then return end
                netstream.Start(M.Net.AdminUpdate, data)
            end
        end

        if not tr.isNew then
            local btnDelete = vgui.Create("MantleBtn", formContainer)
            btnDelete:SetPos(btnW + btnGap, btnY)
            btnDelete:SetSize(btnW, btnH)
            btnDelete:SetTxt(L("music.admin_delete"))
            btnDelete:SetColor(CLR_RED)
            btnDelete:SetColorHover(CLR_RED_H)
            btnDelete:SetRadius(R:Y(8))
            btnDelete:SetGradient(false)
            btnDelete:SetRipple(true)
            btnDelete.DoClick = function()
                if not tr.dbId then return end
                netstream.Start(M.Net.AdminDelete, tr.dbId)
                self._adminSelectedTrack = nil
                hook.Run("VERSE::Music::AdminTrackSelected")
            end
        end

    end

    buildForm()
    hook.Add("VERSE::Music::AdminTrackSelected", "VERSE::Music::AdminBuildForm", function()
        if not IsValid(formContainer) then return end
        buildForm()
    end)

    local oldRemove = frame.Remove
    frame.Remove = function(s)
        hook.Remove("VERSE::Music::AdminRefreshList", "VERSE::Music::AdminRefreshScroll")
        hook.Remove("VERSE::Music::TracksUpdated", "VERSE::Music::AdminAutoRefresh")
        hook.Remove("VERSE::Music::AdminTrackSelected", "VERSE::Music::AdminBuildForm")
        oldRemove(s)
    end
end

VERSE.Commands.Add("verse_ost_admin", function(ply) M:OpenAdminPanel() end, "staff", "client")