local jobRegistry = {}
local R = VERSE.Responsive
local Font = VERSE.Fonts
local CLR_DANGER = Color(200, 60, 60)
local CLR_SUCCESS = Color(55, 175, 95)
local _JOB_COL_SECTION_BORD = Color(255, 255, 255, 14)  -- Paint outline
netstream.Hook("VERSE::Jobs::Sync", function(id, extras, stats)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    ply.Job = {
        id = id ~= "" and id or nil,
        extras = extras or {},
        stats = stats or {},
    }
end)

netstream.Hook("VERSE::Jobs::RegistrySync", function(registry)
    jobRegistry = registry or {}
    local p = VERSE.Jobs._Panel
    if IsValid(p) then p:RefreshJobs() end
end)

netstream.Hook("VERSE::Jobs::WhitelistSync", function(whitelist)
    jobWhitelist = whitelist or {}
    local p = VERSE.Jobs._Panel
    if IsValid(p) then p:RefreshWhitelist() end
end)

local function reqRegistry()
    netstream.Start("VERSE::Jobs::Request", "registry")
end

local function isDev()
    local p = LocalPlayer()
    return IsValid(p) and p:IsDeveloper()
end

local function isStaff()
    local p = LocalPlayer()
    return IsValid(p) and (p:IsDeveloper() or p:IsStaff())
end

local function makeSectionLabel(parent, text, gap)
    local lbl = vgui.Create("DPanel", parent)
    lbl:Dock(TOP)
    lbl:SetTall(R:RS(20))
    lbl:DockMargin(0, 0, 0, R:RS(4))
    lbl.Paint = function(s, w, h)
        local c = Mantle.color.theme
        draw.SimpleText(text, Font:GetNamed("Poppins", "Regular", 18), 0, h * 0.5, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(c.r, c.g, c.b, 60)
        local tx = select(1, surface.GetTextSize(text)) + R:RS(6)
        surface.DrawLine(tx, h * 0.5, w, h * 0.5)
    end
    return lbl
end

local function mantleConfirm(title, text, onYes)
    local GAP = R:RS(8)
    local f = vgui.Create("MantleFrame")
    f:SetSize(R:RS(340), R:RS(150))
    f:Center()
    f:SetTitle(title)
    f:SetDraggable(false)
    f:ShowAnimation()
    f:MakePopup()
    f:DockPadding(GAP, GAP, GAP, GAP)
    local btnRow = vgui.Create("DPanel", f)
    btnRow:Dock(BOTTOM)
    btnRow:SetTall(R:RS(36))
    btnRow.Paint = nil
    local btnYes = vgui.Create("MantleBtn", btnRow)
    btnYes:Dock(LEFT)
    btnYes:SetWide(R:RS(130))
    btnYes:SetTxt(VERSE.L("jobs.confirm_delete_yes"))
    btnYes:SetColor(CLR_DANGER)
    btnYes.DoClick = function()
        f:Remove()
        onYes()
    end

    local btnNo = vgui.Create("MantleBtn", btnRow)
    btnNo:Dock(FILL)
    btnNo:DockMargin(GAP, 0, 0, 0)
    btnNo:SetTxt(VERSE.L("jobs.confirm_delete_no"))
    btnNo.DoClick = function() f:Remove() end
    local lbl = vgui.Create("DLabel", f)
    lbl:Dock(FILL)
    lbl:DockMargin(0, 0, 0, GAP)
    lbl:SetText(text)
    lbl:SetWrap(true)
    lbl:SetContentAlignment(5)
end

local function buildModelList(parent, gap, bheight)
    local SECTION_H = R:RS(130)
    local ROW_H = R:RS(24)
    local ROW_GAP = R:RS(3)
    local TITLE_H = R:RS(22)
    local BTN_ADD_W = R:RS(88)
    local models = {}
    local section = vgui.Create("DPanel", parent)
    section:Dock(TOP)
    section:SetTall(SECTION_H)
    section:DockMargin(0, 0, 0, gap)
    section.Paint = function(s, w, h)
        RNDX.Draw(R:RS(6), 0, 0, w, h, Mantle.color.panel[1])
        RNDX.DrawOutlined(R:RS(6), 0, 0, w, h, _JOB_COL_SECTION_BORD)
    end

    local header = vgui.Create("DPanel", section)
    header:Dock(TOP)
    header:SetTall(TITLE_H)
    header:DockMargin(gap / 2, R:RS(4), gap / 2, 0)
    header.Paint = function(s, w, h)
        draw.SimpleText(VERSE.L("jobs.field_models"), Font:GetNamed("Poppins", "Regular", 18), 0, h * 0.5, Mantle.color.gray, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(Mantle.color.theme.r, Mantle.color.theme.g, Mantle.color.theme.b, 40)
        local tx = select(1, surface.GetTextSize(VERSE.L("jobs.field_models"))) + R:RS(6)
        surface.DrawLine(tx, h * 0.5, w, h * 0.5)
    end

    local addRow = vgui.Create("DPanel", section)
    addRow:Dock(BOTTOM)
    addRow:SetTall(bheight)
    addRow:DockMargin(gap / 2, R:RS(3), gap / 2, R:RS(4))
    addRow.Paint = nil
    local eNewModel = vgui.Create("MantleEntry", addRow)
    eNewModel:Dock(FILL)
    eNewModel:DockMargin(0, 0, gap, 0)
    eNewModel:SetPlaceholder(VERSE.L("jobs.placeholder_model_add"))
    local btnAdd = vgui.Create("MantleBtn", addRow)
    btnAdd:Dock(RIGHT)
    btnAdd:SetWide(BTN_ADD_W)
    btnAdd:SetTxt(VERSE.L("jobs.btn_add_model"))
    btnAdd:SetColor(Mantle.color.theme)
    local scroll = vgui.Create("DScrollPanel", section)
    scroll:Dock(FILL)
    scroll:DockMargin(gap / 2, 0, gap / 2, 0)
    local canvas = scroll:GetCanvas()
    local sbar = scroll:GetVBar()
    sbar:SetWide(R:RS(4))
    sbar.Paint = function(_, w, h) RNDX.Draw(R:RS(2), 0, 0, w, h, Mantle.color.panel[2]) end
    sbar.btnUp.Paint = nil
    sbar.btnDown.Paint = nil
    sbar.btnGrip.Paint = function(_, w, h) RNDX.Draw(R:RS(2), 0, 0, w, h, Mantle.color.theme) end
    local lblEmpty = vgui.Create("DLabel", canvas)
    lblEmpty:SetFont(Font:GetNamed("Poppins", "Regular", 18))
    lblEmpty:SetText(VERSE.L("jobs.models_empty"))
    lblEmpty:SetTextColor(Mantle.color.gray)
    lblEmpty:SizeToContents()
    lblEmpty:SetVisible(true)
    local function updateEmpty()
        lblEmpty:SetVisible(#models == 0)
    end

    local function addModelRow(mdl)
        lblEmpty:SetVisible(false)
        local row = vgui.Create("DPanel", canvas)
        row:Dock(TOP)
        row:SetTall(ROW_H)
        row:DockMargin(0, 0, 0, ROW_GAP)
        row._model = mdl
        row.Paint = function(s, w, h)
            RNDX.Draw(R:RS(4), 0, 0, w, h, Mantle.color.panel[2])
            draw.SimpleText(s._model or "", Font:GetNamed("Poppins", "Regular", 18), R:RS(7), h * 0.5, Mantle.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local btnRm = vgui.Create("MantleBtn", row)
        btnRm:Dock(RIGHT)
        btnRm:SetWide(R:RS(22))
        btnRm:DockMargin(R:RS(2), R:RS(2), R:RS(2), R:RS(2))
        btnRm:SetTxt("×")
        btnRm:SetColor(CLR_DANGER)
        btnRm.DoClick = function()
            for i, m in ipairs(models) do
                if m == mdl then
                    table.remove(models, i)
                    break
                end
            end

            row:Remove()
            updateEmpty()
        end
    end

    btnAdd.DoClick = function()
        local val = eNewModel:GetValue():Trim()
        if val == "" then return end
        for _, m in ipairs(models) do
            if m == val then return end
        end

        models[#models + 1] = val
        addModelRow(val)
        eNewModel:SetValue("")
    end

    eNewModel:SetOnEnter(btnAdd.DoClick)
    return section, {
        getModels = function() return table.Copy(models) end,
        setModels = function(mlist)
            models = {}
            for _, c in ipairs(canvas:GetChildren()) do
                if c ~= lblEmpty then c:Remove() end
            end

            if isstring(mlist) and mlist ~= "" then
                models[1] = mlist
                addModelRow(mlist)
            elseif istable(mlist) then
                for _, m in ipairs(mlist) do
                    if isstring(m) and m ~= "" then
                        models[#models + 1] = m
                        addModelRow(m)
                    end
                end
            end

            updateEmpty()
        end,
        clearModels = function()
            models = {}
            for _, c in ipairs(canvas:GetChildren()) do
                if c ~= lblEmpty then c:Remove() end
            end

            updateEmpty()
        end,
    }
end

local function buildJobsTab(parent)
    local GAP = R:RS(8)
    local LWIDTH = R:RS(290)
    local BHEIGHT = R:RS(36)
    local leftCol = vgui.Create("DPanel", parent)
    leftCol:Dock(LEFT)
    leftCol:SetWide(LWIDTH)
    leftCol:DockMargin(0, 0, GAP, 0)
    leftCol.Paint = nil
    local btnRow = vgui.Create("DPanel", leftCol)
    btnRow:Dock(BOTTOM)
    btnRow:SetTall(BHEIGHT)
    btnRow.Paint = nil
    local jTable = vgui.Create("MantleTable", leftCol)
    jTable:Dock(FILL)
    jTable:DockMargin(0, 0, 0, GAP)
    jTable:AddColumn(VERSE.L("jobs.col_id"), R:RS(80), nil, true)
    jTable:AddColumn(VERSE.L("jobs.col_name"), R:RS(110), nil, true)
    jTable:AddColumn(VERSE.L("jobs.col_wl"), R:RS(30), nil, true)
    jTable:AddColumn(VERSE.L("jobs.col_type"), R:RS(50), nil, true)
    local selectedID = nil
    jTable:SetAction(function(row) selectedID = row[1] end)
    local rightCol = vgui.Create("DPanel", parent)
    rightCol:Dock(FILL)
    rightCol.Paint = nil
    local btnClearForm = vgui.Create("MantleBtn", rightCol)
    btnClearForm:Dock(BOTTOM)
    btnClearForm:SetTall(BHEIGHT)
    btnClearForm:SetTxt(VERSE.L("jobs.btn_clear"))
    local btnSave = vgui.Create("MantleBtn", rightCol)
    btnSave:Dock(BOTTOM)
    btnSave:SetTall(BHEIGHT)
    btnSave:DockMargin(0, 0, 0, GAP)
    btnSave:SetTxt(VERSE.L("jobs.btn_save"))
    btnSave:SetColor(Mantle.color.theme)
    local subTabs = vgui.Create("MantleTabs", rightCol)
    subTabs:Dock(FILL)
    subTabs:DockMargin(0, 0, 0, GAP)
    local mainPanel = vgui.Create("DPanel")
    mainPanel.Paint = nil
    local mainScroll = vgui.Create("DScrollPanel", mainPanel)
    mainScroll:Dock(FILL)
    local msbar = mainScroll:GetVBar()
    msbar:SetWide(R:RS(4))
    msbar.Paint = function(_, w, h) RNDX.Draw(R:RS(2), 0, 0, w, h, Mantle.color.panel[2]) end
    msbar.btnUp.Paint = nil
    msbar.btnDown.Paint = nil
    msbar.btnGrip.Paint = function(_, w, h) RNDX.Draw(R:RS(2), 0, 0, w, h, Mantle.color.theme) end
    local mainContent = mainScroll:GetCanvas()
    local editing = false
    makeSectionLabel(mainContent, "ID / Название", GAP)
    local eID = vgui.Create("MantleEntry", mainContent)
    eID:Dock(TOP)
    eID:SetTall(R:RS(52))
    eID:DockMargin(0, 0, 0, GAP)
    eID:SetTitle(VERSE.L("jobs.field_job_id"))
    eID:SetPlaceholder(VERSE.L("jobs.placeholder_job_id"))
    local eName = vgui.Create("MantleEntry", mainContent)
    eName:Dock(TOP)
    eName:SetTall(R:RS(52))
    eName:DockMargin(0, 0, 0, GAP)
    eName:SetTitle(VERSE.L("jobs.field_name"))
    eName:SetPlaceholder(VERSE.L("jobs.placeholder_name"))
    makeSectionLabel(mainContent, VERSE.L("jobs.field_models"), GAP)
    local _, modelCtrl = buildModelList(mainContent, GAP, BHEIGHT)
    makeSectionLabel(mainContent, "Экипировка / Статы", GAP)
    local eLoadout = vgui.Create("MantleEntry", mainContent)
    eLoadout:Dock(TOP)
    eLoadout:SetTall(R:RS(52))
    eLoadout:DockMargin(0, 0, 0, GAP)
    eLoadout:SetTitle(VERSE.L("jobs.field_loadout"))
    eLoadout:SetPlaceholder(VERSE.L("jobs.placeholder_loadout"))
    local statsRow = vgui.Create("DPanel", mainContent)
    statsRow:Dock(TOP)
    statsRow:SetTall(R:RS(52))
    statsRow:DockMargin(0, 0, 0, GAP)
    statsRow.Paint = nil
    local eHP = vgui.Create("MantleEntry", statsRow)
    local eArmor = vgui.Create("MantleEntry", statsRow)
    eHP:SetTitle(VERSE.L("jobs.field_hp"))
    eHP:SetPlaceholder("100")
    eHP:SetNumeric(true)
    eArmor:SetTitle(VERSE.L("jobs.field_armor"))
    eArmor:SetPlaceholder("0")
    eArmor:SetNumeric(true)

    statsRow.PerformLayout = function(self, w, h)
        local hw = math.floor((w - GAP) / 2)
        eHP:SetPos(0, 0)
        eHP:SetSize(hw, h)
        eArmor:SetPos(hw + GAP, 0)
        eArmor:SetSize(w - hw - GAP, h)
    end

    local speedRow = vgui.Create("DPanel", mainContent)
    speedRow:Dock(TOP)
    speedRow:SetTall(R:RS(52))
    speedRow:DockMargin(0, 0, 0, GAP)
    speedRow.Paint = nil
    local eWalkSpeed = vgui.Create("MantleEntry", speedRow)
    local eRunSpeed  = vgui.Create("MantleEntry", speedRow)
    local eJumpPower = vgui.Create("MantleEntry", speedRow)
    eWalkSpeed:SetTitle(VERSE.L("jobs.field_walk_speed"))
    eWalkSpeed:SetPlaceholder("200")
    eWalkSpeed:SetNumeric(true)
    eRunSpeed:SetTitle(VERSE.L("jobs.field_run_speed"))
    eRunSpeed:SetPlaceholder("400")
    eRunSpeed:SetNumeric(true)
    eJumpPower:SetTitle(VERSE.L("jobs.field_jump_power"))
    eJumpPower:SetPlaceholder("200")
    eJumpPower:SetNumeric(true)
    speedRow.PerformLayout = function(self, w, h)
        local tw = math.floor((w - GAP * 2) / 3)
        eWalkSpeed:SetPos(0, 0)
        eWalkSpeed:SetSize(tw, h)
        eRunSpeed:SetPos(tw + GAP, 0)
        eRunSpeed:SetSize(tw, h)
        eJumpPower:SetPos(tw * 2 + GAP * 2, 0)
        eJumpPower:SetSize(w - tw * 2 - GAP * 2, h)
    end

    local chkRespawn = vgui.Create("MantleCheckBox", mainContent)
    chkRespawn:Dock(TOP)
    chkRespawn:SetTall(R:RS(32))
    chkRespawn:DockMargin(0, 0, 0, GAP)
    chkRespawn:SetTxt(VERSE.L("jobs.field_respawn"))
    subTabs:AddTab(VERSE.L("jobs.subtab_main"), mainPanel)
    local spawnPanel = vgui.Create("DPanel")
    spawnPanel.Paint = nil
    local function parseVec(str)
        str = str:Trim():gsub("^[Vv]ector%s*%(", ""):gsub("%)%s*$", "")
        local nums = {}
        for n in str:gmatch("-?%d+%.?%d*") do
            nums[#nums + 1] = tonumber(n)
        end

        if #nums >= 3 then return nums[1], nums[2], nums[3] end
        return nil
    end

    makeSectionLabel(spawnPanel, "Точки спавна", GAP)
    local eMin = vgui.Create("MantleEntry", spawnPanel)
    eMin:Dock(TOP)
    eMin:SetTall(R:RS(52))
    eMin:DockMargin(0, 0, 0, GAP)
    eMin:SetTitle(VERSE.L("jobs.spawn_min"))
    eMin:SetPlaceholder("x, y, z")
    local eMax = vgui.Create("MantleEntry", spawnPanel)
    eMax:Dock(TOP)
    eMax:SetTall(R:RS(52))
    eMax:DockMargin(0, 0, 0, GAP)
    eMax:SetTitle(VERSE.L("jobs.spawn_max"))
    eMax:SetPlaceholder("x, y, z")
    local btnCopySpawn = vgui.Create("MantleBtn", spawnPanel)
    btnCopySpawn:Dock(TOP)
    btnCopySpawn:SetTall(BHEIGHT)
    btnCopySpawn:DockMargin(0, 0, 0, GAP)
    btnCopySpawn:SetTxt(VERSE.L("jobs.spawn_copy_from"))
    btnCopySpawn.DoClick = function()
        local sorted = {}
        for _, job in pairs(jobRegistry) do
            if job.spawn and job.spawn.min and job.spawn.max then sorted[#sorted + 1] = job end
        end

        table.sort(sorted, function(a, b) return (a.id or "") < (b.id or "") end)
        local menu = Mantle.ui.derma_menu()
        if #sorted == 0 then
            menu:AddOption(VERSE.L("jobs.spawn_copy_none"))
        else
            for _, job in ipairs(sorted) do
                local sp = job.spawn
                menu:AddOption(job.name or job.id, function()
                    eMin:SetValue(string.format("%.1f, %.1f, %.1f", sp.min.x or 0, sp.min.y or 0, sp.min.z or 0))
                    eMax:SetValue(string.format("%.1f, %.1f, %.1f", sp.max.x or 0, sp.max.y or 0, sp.max.z or 0))
                end)
            end
        end
    end

    local btnClearSpawn = vgui.Create("MantleBtn", spawnPanel)
    btnClearSpawn:Dock(TOP)
    btnClearSpawn:SetTall(BHEIGHT)
    btnClearSpawn:DockMargin(0, 0, 0, GAP)
    btnClearSpawn:SetTxt(VERSE.L("jobs.spawn_clear"))
    btnClearSpawn:SetColor(CLR_DANGER)
    btnClearSpawn.DoClick = function()
        eMin:SetValue("")
        eMax:SetValue("")
    end

    subTabs:AddTab(VERSE.L("jobs.subtab_spawn"), spawnPanel)
    local function formData()
        local loadout = {}
        for wep in eLoadout:GetValue():gmatch("[^,]+") do
            local w = wep:Trim()
            if w ~= "" then loadout[#loadout + 1] = w end
        end

        local mnx, mny, mnz = parseVec(eMin:GetValue())
        local mxx, mxy, mxz = parseVec(eMax:GetValue())
        local spawnData = nil
        if mnx and mxx then
            spawnData = {
                min = {
                    x = mnx,
                    y = mny,
                    z = mnz
                },
                max = {
                    x = mxx,
                    y = mxy,
                    z = mxz
                },
            }
        end

        local mdlList = modelCtrl.getModels()
        local mdlVal = (#mdlList == 1) and mdlList[1] or mdlList
        return {
            name = eName:GetValue():Trim(),
            model = mdlVal,
            loadout = loadout,
            stats = {
                health    = tonumber(eHP:GetValue()) or 100,
                armor     = tonumber(eArmor:GetValue()) or 0,
                walkspeed = tonumber(eWalkSpeed:GetValue()) or 200,
                runspeed  = tonumber(eRunSpeed:GetValue()) or 400,
                jumppower = tonumber(eJumpPower:GetValue()) or 200,
            },
            extras = {},
            dynamic = true,
            respawn = chkRespawn:GetBool(),
            spawn = spawnData,
        }
    end

    local function formFill(job)
        eID:SetValue(job.id or "")
        eName:SetValue(job.name or "")
        modelCtrl.setModels(job.model)
        eLoadout:SetValue(table.concat(job.loadout or {}, ", "))
        eHP:SetValue(tostring((job.stats or {}).health or 100))
        eArmor:SetValue(tostring((job.stats or {}).armor or 0))
        eWalkSpeed:SetValue(tostring((job.stats or {}).walkspeed or 200))
        eRunSpeed:SetValue(tostring((job.stats or {}).runspeed or 400))
        eJumpPower:SetValue(tostring((job.stats or {}).jumppower or 200))
        chkRespawn:SetValue(job.respawn == true)
        local sp = job.spawn
        if sp and sp.min and sp.max then
            eMin:SetValue(string.format("%.1f, %.1f, %.1f", sp.min.x or 0, sp.min.y or 0, sp.min.z or 0))
            eMax:SetValue(string.format("%.1f, %.1f, %.1f", sp.max.x or 0, sp.max.y or 0, sp.max.z or 0))
        else
            eMin:SetValue("")
            eMax:SetValue("")
        end
    end

    local function formClear()
        eID:SetValue("")
        eName:SetValue("")
        modelCtrl.clearModels()
        eLoadout:SetValue("")
        eHP:SetValue("100")
        eArmor:SetValue("0")
        eWalkSpeed:SetValue("200")
        eRunSpeed:SetValue("400")
        eJumpPower:SetValue("200")
        chkRespawn:SetValue(false)
        eMin:SetValue("")
        eMax:SetValue("")
        editing = false
    end

    btnSave.DoClick = function()
        local id = eID:GetValue():Trim()
        if id == "" then return end
        local data = formData()
        if editing then
            netstream.Start("VERSE::Jobs::Edit", id, data)
        else
            netstream.Start("VERSE::Jobs::Create", id, data)
        end

        formClear()
    end

    btnClearForm.DoClick = formClear
    local bw = math.floor((LWIDTH - GAP * 2) / 3)
    local btnNew = vgui.Create("MantleBtn", btnRow)
    btnNew:Dock(LEFT)
    btnNew:SetWide(bw)
    btnNew:DockMargin(0, 0, GAP, 0)
    btnNew:SetTxt(VERSE.L("jobs.btn_create"))
    btnNew.DoClick = formClear
    local btnEdit = vgui.Create("MantleBtn", btnRow)
    btnEdit:Dock(LEFT)
    btnEdit:SetWide(bw)
    btnEdit:DockMargin(0, 0, GAP, 0)
    btnEdit:SetTxt(VERSE.L("jobs.btn_edit"))
    btnEdit:SetColor(CLR_SUCCESS)
    btnEdit.DoClick = function()
        if not selectedID then return end
        local job = jobRegistry[selectedID]
        if not job then return end
        editing = true
        formFill(job)
    end

    local btnDel = vgui.Create("MantleBtn", btnRow)
    btnDel:Dock(FILL)
    btnDel:SetTxt(VERSE.L("jobs.btn_delete"))
    btnDel:SetColor(CLR_DANGER)
    btnDel.DoClick = function()
        if not selectedID then return end
        mantleConfirm(VERSE.L("jobs.confirm_delete_title"), VERSE.L("jobs.confirm_delete_text", {
            id = selectedID
        }), function() netstream.Start("VERSE::Jobs::Delete", selectedID) end)
    end

    local function refreshList()
        jTable:Clear()
        local sorted = {}
        for _, job in pairs(jobRegistry) do
            sorted[#sorted + 1] = job
        end

        table.sort(sorted, function(a, b) return (a.id or "") < (b.id or "") end)
        for _, job in ipairs(sorted) do
            jTable:AddItem(job.id, job.name or job.id, job.whitelisted and VERSE.L("jobs.wl_yes") or VERSE.L("jobs.wl_no"), job.dynamic and VERSE.L("jobs.type_dynamic") or VERSE.L("jobs.type_static"))
        end
    end

    function parent:RefreshJobs()
        refreshList()
    end

    function parent:RefreshWhitelist()
    end
end

local function buildAssignTab(parent)
    local GAP = R:RS(8)
    local BHEIGHT = R:RS(36)
    local topBar = vgui.Create("DPanel", parent)
    topBar:Dock(TOP)
    topBar:SetTall(BHEIGHT)
    topBar:DockMargin(0, 0, 0, GAP)
    topBar.Paint = nil
    local btnAssign = vgui.Create("MantleBtn", topBar)
    btnAssign:Dock(FILL)
    btnAssign:SetTxt(VERSE.L("jobs.btn_assign"))
    btnAssign:SetColor(Mantle.color.theme)
    local divider = vgui.Create("DPanel", parent)
    divider:Dock(TOP)
    divider:SetTall(R:RS(1))
    divider:DockMargin(0, 0, 0, GAP)
    divider.Paint = function(_, w, h)
        surface.SetDrawColor(Mantle.color.theme.r, Mantle.color.theme.g, Mantle.color.theme.b, 50)
        surface.DrawRect(0, 0, w, h)
    end

    local leftCol = vgui.Create("DPanel", parent)
    leftCol:Dock(LEFT)
    leftCol:SetWide(R:RS(380))
    leftCol:DockMargin(0, 0, GAP, 0)
    leftCol.Paint = nil
    makeSectionLabel(leftCol, "Игроки", GAP)
    local pTable = vgui.Create("MantleTable", leftCol)
    pTable:Dock(FILL)
    pTable:AddColumn(VERSE.L("jobs.col_nick"), R:RS(130), nil, true)
    pTable:AddColumn(VERSE.L("jobs.col_steamid"), R:RS(140), nil, true)
    pTable:AddColumn(VERSE.L("jobs.col_current_job"), R:RS(90), nil, true)
    local rightCol = vgui.Create("DPanel", parent)
    rightCol:Dock(FILL)
    rightCol.Paint = nil
    makeSectionLabel(rightCol, "Профессии", GAP)
    local jTable = vgui.Create("MantleTable", rightCol)
    jTable:Dock(FILL)
    jTable:AddColumn(VERSE.L("jobs.col_id"), R:RS(110), nil, true)
    jTable:AddColumn(VERSE.L("jobs.col_name"), R:RS(150), nil, true)
    jTable:AddColumn(VERSE.L("jobs.col_wl"), R:RS(30), nil, true)
    local selectedSID = nil
    local selectedJob = nil
    pTable:SetAction(function(row) selectedSID = row[2] end)
    jTable:SetAction(function(row) selectedJob = row[1] end)
    btnAssign.DoClick = function()
        if not selectedSID then
            VERSE.Notify:Push(VERSE.L("jobs.notify_no_player"), NOTIFY_ERROR, 3)
            return
        end

        if not selectedJob then
            VERSE.Notify:Push(VERSE.L("jobs.notify_no_job"), NOTIFY_ERROR, 3)
            return
        end

        local jobData = jobRegistry[selectedJob]
        local jobName = (jobData and (jobData.name or selectedJob)) or selectedJob
        netstream.Start("VERSE::Jobs::SetPlayer", selectedSID, selectedJob, {})
        VERSE.Notify:Push(VERSE.L("jobs.notify_assign_sent", {
            job = jobName
        }), NOTIFY_HINT, 3)
    end

    local function refreshPlayers()
        pTable:Clear()
        for _, p in ipairs(player.GetAll()) do
            local jobID = p:GetPublicString("VERSE::JobID", "")
            local jobData = jobRegistry[jobID]
            local jobName = (jobData and (jobData.name or jobID)) or jobID
            pTable:AddItem(p:Nick(), p:SteamID(), jobName)
        end
    end

    local function refreshJobs()
        jTable:Clear()
        local sorted = {}
        for _, job in pairs(jobRegistry) do
            sorted[#sorted + 1] = job
        end

        table.sort(sorted, function(a, b) return (a.id or "") < (b.id or "") end)
        for _, job in ipairs(sorted) do
            jTable:AddItem(job.id, job.name or job.id, job.whitelisted and VERSE.L("jobs.wl_yes") or VERSE.L("jobs.wl_no"))
        end
    end

    refreshPlayers()
    function parent:RefreshJobs()
        refreshJobs()
        refreshPlayers()
    end
end

local function openPanel()
    if IsValid(VERSE.Jobs._Panel) then VERSE.Jobs._Panel:Remove() end
    local PW = R:RS(880)
    local PH = R:RS(600)
    local frame = vgui.Create("MantleFrame")
    frame:SetSize(PW, PH)
    frame:Center()
    frame:SetTitle(VERSE.L("jobs.panel_title"))
    frame:SetDraggable(true)
    frame:ShowAnimation()
    frame:MakePopup()
    frame.OnClose = function() VERSE.Jobs._Panel = nil end
    VERSE.Jobs._Panel = frame
    local tabs = vgui.Create("MantleTabs", frame)
    tabs:Dock(FILL)
    local allPanels = {}
    local function addTab(name, buildFn)
        local p = vgui.Create("DPanel")
        p:DockPadding(R:RS(8), R:RS(8), R:RS(8), R:RS(8))
        p.Paint = nil
        buildFn(p)
        tabs:AddTab(name, p)
        allPanels[#allPanels + 1] = p
    end

    if isDev() then addTab(VERSE.L("jobs.tab_jobs"), buildJobsTab) end
    if isStaff() then addTab(VERSE.L("jobs.tab_assign"), buildAssignTab) end
    function frame:RefreshJobs()
        for _, t in ipairs(allPanels) do
            if t.RefreshJobs then t:RefreshJobs() end
        end
    end

    function frame:RefreshWhitelist()
        for _, t in ipairs(allPanels) do
            if t.RefreshWhitelist then t:RefreshWhitelist() end
        end
    end

    reqRegistry()
end

VERSE.Commands.Add("verse_jobs", function()
    if not isStaff() then return end
    openPanel()
end)