local BT = VERSE.Boutique
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
local _ui = BT._ui

-- ─── Couleurs pré-allouées pour TopBar UI (évite Color() par frame) ──────────
local _TB_COL_CODE_ENTRY_BG   = Color(255, 255, 255, 25)
local _TB_COL_CODE_ENTRY_OUT  = Color(255, 238, 82,  255)
local _TB_COL_CODE_PLACEHOLDER = Color(120, 120, 120, 255)
local _TB_COL_CODE_SEL        = Color(255, 238, 82,  80)
local _TB_COL_CREDITS_BG      = Color(255, 255, 255, 25)
local _TB_COL_CREDITS_OUT     = Color(171, 82,  255, 255)
local _TB_COL_ADMIN_BG        = Color(255, 80,  80,  0)   -- .a muté
local _TB_COL_ADMIN_OUT       = Color(255, 80,  80,  0)   -- .a muté
local _TB_COL_ADMIN_TXT       = Color(255, 100, 100, 255)
-- ─────────────────────────────────────────────────────────────────────────────

local function buildTopBar(frame)
    local elems = {}

    local codeLabel = vgui.Create("DButton", frame)
    codeLabel:SetPos(R:XY(40, 46))
    codeLabel:SetSize(R:XY(224, 35))
    codeLabel:SetText("")
    local _codeLabelFont = Font:GetNamed("Poppins", "SemiBold", 26)
    codeLabel.Paint = function(s, w, h)
        draw.SimpleText("Code", _codeLabelFont, 0, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    elems[#elems + 1] = codeLabel

    local codeEntry = vgui.Create("MantleEntry", frame)
    codeEntry:SetPos(R:XY(40, 81))
    codeEntry:SetSize(R:XY(224, 38))
    codeEntry:SetPlaceholder("Entrez le code...")
    codeEntry:SetFonts(Font:GetNamed("Poppins", "Regular", 16), Font:GetNamed("Poppins", "Regular", 16))
    codeEntry:SetTextColor(color_white)
    codeEntry:SetPlaceholderColor(Color(120, 120, 120))
    codeEntry:SetHighlightColor(Color(255, 238, 82, 80))
    codeEntry:SetCursorColor(color_white)
    codeEntry:SetValue(BT:GetCreatorCode())
    local _codeEntryFont = Font:GetNamed("Poppins", "Regular", 16)
    codeEntry.textEntry.Paint = function(s, w, h)
        RNDX.Draw(R:Y(10), 0, 0, w, h, _TB_COL_CODE_ENTRY_BG)
        RNDX.DrawOutlined(R:Y(10), 0, 0, w, h, _TB_COL_CODE_ENTRY_OUT, 2)
        local val = codeEntry:GetValue() or ""
        if val == "" and not s:HasFocus() then
            draw.SimpleText("Entrez le code...", _codeEntryFont, R:X(11), h * 0.5, _TB_COL_CODE_PLACEHOLDER, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return true
        end
        s:DrawTextEntryText(color_white, _TB_COL_CODE_SEL, color_white)
        return true
    end
    elems[#elems + 1] = codeEntry

    local function submitCode()
        local val = tostring(codeEntry:GetValue() or ""):Trim()
        if val == "" then return end
        netstream.Start(BT.Net.SaveCreatorCode, val)
    end

    codeEntry:SetOnEnter(function() submitCode() end)
    BT._creatorEntry = codeEntry.textEntry
    codeLabel.DoClick = function() submitCode() end

    local credits = vgui.Create("DPanel", frame)
    credits:SetPos(R:XY(1660, 29))
    credits:SetSize(R:XY(224, 80))
    local _creditsFont  = Font:GetNamed("Poppins", "SemiBold", 26)
    local _buyCoinsFont = Font:GetNamed("Poppins", "Medium",   16)
    credits.Paint = function(_, w, h)
        local coinSz = R:Y(32)
        Materials:Draw(color_white, "coins_icon_img", R:X(121), 0, coinSz, coinSz, "noclamp smooth")
        draw.SimpleText(tostring(BT:GetCredits()), _creditsFont, R:X(164), R:Y(7), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local btnY = R:Y(42)
        local btnH = R:Y(38)
        RNDX.Draw(R:Y(10), 0, btnY, w, btnH, _TB_COL_CREDITS_BG)
        RNDX.DrawOutlined(R:Y(10), 0, btnY, w, btnH, _TB_COL_CREDITS_OUT, 2)
        local iconSz = R:Y(14)
        Materials:Draw(color_white, "acheter_icon", R:X(22), btnY + R:Y(12), iconSz, iconSz, "noclamp smooth")
        draw.SimpleText("Acheter des coins", _buyCoinsFont, w * 0.5, btnY + btnH * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    elems[#elems + 1] = credits

    local creditsBtn = vgui.Create("DButton", credits)
    creditsBtn:Dock(FILL)
    creditsBtn:SetText("")
    creditsBtn.Paint = function() end
    creditsBtn.DoClick = function()
        local url = tostring((BT.Config and BT.Config.BuyCreditsURL) or "")
        if url ~= "" then gui.OpenURL(url) end
    end

    if LocalPlayer():IsDeveloper() then
        local adminBtn = vgui.Create("DButton", frame)
        adminBtn:SetPos(R:XY(1660 - 200, 72))
        adminBtn:SetSize(R:XY(160, 38))
        adminBtn:SetText("")
        adminBtn:SetCursor("hand")
        adminBtn._hoverFrac = 0
        local _adminBtnFont = Font:GetNamed("Poppins", "SemiBold", 16)
        adminBtn.Paint = function(s, w, h)
            s._hoverFrac = Lerp(FrameTime() * 12, s._hoverFrac, s:IsHovered() and 1 or 0)
            _TB_COL_ADMIN_BG.a  = math.floor(25 + 20 * s._hoverFrac)
            _TB_COL_ADMIN_OUT.a = math.floor(180 + 75 * s._hoverFrac)
            RNDX.Draw(R:Y(10), 0, 0, w, h, _TB_COL_ADMIN_BG)
            RNDX.DrawOutlined(R:Y(10), 0, 0, w, h, _TB_COL_ADMIN_OUT, 2)
            draw.SimpleText("Admin Panel", _adminBtnFont, w * 0.5, h * 0.5, _TB_COL_ADMIN_TXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        adminBtn.DoClick = function()
            BT:CloseUI()
            BT:OpenAdminUI()
        end
        elems[#elems + 1] = adminBtn
    end

    return elems
end

_ui.buildTopBar = buildTopBar
