local BT = VERSE.Boutique
local R = VERSE.Responsive
local Font = VERSE.Fonts
local Materials = VERSE.Materials
-- ─── Couleurs Paint pré-allouées ─────────────────────────────────────────────
local _BT_COL_FRAME_BG = Color(255, 255, 255, 255)
Materials:SetAlias("boutique_background", "verse/newboutique/main_background")
Materials:SetAlias("lancer_button", "verse/newboutique/lancer_button")
Materials:SetAlias("heritage_reroll_banner", "verse/newboutique/heritage_reroll_banner")
Materials:SetAlias("pouvoir_reroll_banner", "verse/newboutique/pouvoir_reroll_banner")
Materials:SetAlias("boutique_logo", "verse/boutique/verse_logo_ez")
Materials:SetAlias("reroll_char_bg", "verse/boutique/reroll_char_background")
Materials:SetAlias("acheter_char_bg", "verse/boutique/acheter_char_background")
Materials:SetAlias("packs_char_bg", "verse/boutique/packs_char_background")
Materials:SetAlias("premium_char_bg", "verse/boutique/premium_char_background")
Materials:SetAlias("clover_icon", "verse/boutique/clover_icon")
Materials:SetAlias("reroll_icon_gift", "verse/boutique/reroll_icon_gift")
Materials:SetAlias("packs_icon_img", "verse/boutique/packs_icon")
Materials:SetAlias("premium_icon_img", "verse/boutique/premium_icon")
Materials:SetAlias("chest_h_img", "verse/boutique/chest_h 1")
Materials:SetAlias("chest_f_img", "verse/boutique/chest_f 1")
Materials:SetAlias("revolution_pouvoir_img", "verse/boutique/revolution_pouvoir")
Materials:SetAlias("reroll_result_img", "verse/boutique/reroll_result")
Materials:SetAlias("coins_icon_img", "verse/boutique/coins_icon")
Materials:SetAlias("heritage_result_yuta", "verse/boutique/heritage_result_yuta")
Materials:SetAlias("verse_log", "verse/boutique/verse_log")
Materials:SetAlias("rerolls_main_background", "verse/boutique/rerolls_main_background")
Materials:SetAlias("reroll_char_background_new", "verse/boutique/reroll_char_background_new")
Materials:SetAlias("packs_char_background_new", "verse/boutique/packs_char_background_new")
Materials:SetAlias("premium_char_background_new", "verse/boutique/premium_char_background_new")
Materials:SetAlias("skin_char_background_new", "verse/boutique/skin_char_background_new")
Materials:SetAlias("acheter_char_background_new", "verse/boutique/acheter_char_background_new")
Materials:SetAlias("premium_main_background", "verse/boutique/premium_main_background")
Materials:SetAlias("acheter_main_background", "verse/boutique/acheter_main_background")
Materials:SetAlias("packs_main_background", "verse/boutique/packs_main_background")
Materials:SetAlias("acheter_icon", "verse/boutique/acheter_icon")
Materials:SetAlias("fallback_icon_pass", "verse/boutique/fallback_icon_pass")
Materials:SetAlias("pack_tenue_card_bg", "verse/boutique/rectangle157")
Materials:SetAlias("pack_tenue_left_bg", "verse/boutique/rectangle163")
-- Icônes clan Gojo
Materials:SetAlias("clan_gojo_bleu",        "icone/gojo/bleu")
Materials:SetAlias("clan_gojo_hollowpurple","icone/gojo/hollowpurple")
Materials:SetAlias("clan_gojo_infini",      "icone/gojo/infini")
Materials:SetAlias("clan_gojo_rouge",       "icone/gojo/Rouge")
BT.Client = BT.Client or {}
BT.Client.DefaultState = BT.Client.DefaultState or {
    page = "home",
    selected = {
        rerolls    = "reroll_occult",
        premium    = "premium_azure",
        packs      = "pack_tenue_test",
        pack_tenue = nil,
        owned      = nil,
    },
    quantities = {
        rerolls = 1,
        premium = 1,
        packs = 1,
    },
    account = BT:GetDefaultAccount(""),
    items = {},
    transactions = {},
    lastRoll = nil,
    rollAnim = {
        occult = nil,
        heritageBusy = false,
        heritageRequestId = 0,
        heritageAnim = nil,
    },
}

BT._frame = BT._frame or nil
BT._content = BT._content or nil
BT._creatorEntry = BT._creatorEntry or nil
BT._topbar = BT._topbar or nil
BT._state = BT._state or table.Copy(BT.Client.DefaultState)
BT._ui = BT._ui or {}
function BT:GetCredits()
    return math.max(0, math.floor(tonumber((self._state.account and self._state.account.coins) or 0) or 0))
end

function BT:GetCreatorCode()
    return tostring((self._state.account and self._state.account.creator_code) or "")
end

function BT:SetStateFromSync(sync)
    if istable(sync.products) then
        self.Products = sync.products
    end
    if istable(sync.rarities) then
        self.Rarities = sync.rarities
        self:RebuildDerivedData()
    end
    if istable(sync.reroll_pool) then
        self.RerollPool = sync.reroll_pool
    end
    if istable(sync.pack_tenue_packs) then
        self.PackTenuePacks = sync.pack_tenue_packs
    end

    self._state.creator_discount = math.min(99, math.max(0, math.floor(tonumber(sync.creator_discount) or 0)))
    sync = self:SanitizeSyncState(sync)
    self._state.account = sync.account or self:GetDefaultAccount("")
    self._state.items = sync.items or {}
    self._state.transactions = sync.transactions or {}
    self._state.lastRoll = sync.account and sync.account.last_roll_payload or nil
    if not self._state.selected.owned then
        local owned = self._ui.ownedProductIds and self._ui.ownedProductIds() or {}
        self._state.selected.owned = owned[1]
    end

    if IsValid(self._creatorEntry) and not self._creatorEntry:HasFocus() then self._creatorEntry:SetText(self:GetCreatorCode()) end
    if IsValid(self._content) then self._content:InvalidateLayout(true) end
end

local SPIN_ALLOWED_PAGES = {
    heritage_video = true,
    heritage_result = true,
    occult_result = true,
}

function BT:IsSpinActive()
    local anim = self._state.rollAnim
    if not anim then return false end
    if anim.occult and anim.occult.active then return true end
    if anim.heritageBusy then return true end
    if anim.heritageAnim and anim.heritageAnim.active then return true end
    return false
end

function BT:SetPage(pageId)
    pageId = tostring(pageId or "home")
    if self:IsSpinActive() and not SPIN_ALLOWED_PAGES[pageId] then return end
    -- Décharge les previews modèle de la page pack tenue quand on la quitte
    if self._state.page == "packs" and pageId ~= "packs" then
        if self._ui and self._ui.destroyPackTenuePreview then
            self._ui.destroyPackTenuePreview()
        end
    end
    self._state.page = pageId
    local isVideo = self._state.page == "heritage_video"
    if istable(self._topbar) then
        for _, elem in ipairs(self._topbar) do
            if IsValid(elem) then elem:SetVisible(not isVideo) end
        end
    end
    self:RebuildContent()
end

function BT:RequestSync()
    netstream.Start(self.Net.RequestSync)
end

function BT:CloseUI()
    if self:IsSpinActive() then return end
    if IsValid(self._frame) then self._frame:Close() end
    self._frame = nil
    self._content = nil
    self._creatorEntry = nil
end

function BT:RebuildContent()
    if not IsValid(self._content) then return end
    self._content:Clear()
    local ui = self._ui
    local page = tostring(self._state.page or "home")
    if page == "home" then
        ui.buildHomePage(self._content)
    elseif page == "rerolls" then
        ui.buildCatalogPage(self._content, "rerolls")
    elseif page == "packs" then
        ui.buildPackTenuePage(self._content)
    elseif page == "outfits" then
        ui.buildCatalogPage(self._content, "outfits")
    elseif page == "owned" then
        ui.buildOwnedPage(self._content)
    elseif page == "power" then
        ui.buildOccultRollPage(self._content)
    elseif page == "occult_result" then
        ui.buildOccultResultPage(self._content)
    elseif page == "heritage" then
        ui.buildHeritagePage(self._content)
    elseif page == "heritage_video" then
        ui.buildHeritageVideoPage(self._content)
    elseif page == "heritage_result" then
        ui.buildHeritageResultPage(self._content)
    else
        ui.buildHomePage(self._content)
    end
end

function BT:OpenUI()
    if IsValid(self._frame) then
        self._frame:MakePopup()
        self._frame:RequestFocus()
        self:RequestSync()
        return
    end

    self:RequestSync()
    local frame = vgui.Create("MantleFrame")
    frame:SetSize(R:XY(1920, 1080))
    frame:Center()
    frame:MakePopup()
    frame:RequestFocus()
    frame:SetDraggable(false)
    frame:LiteMode()
    frame:SetAlphaBackground(false)
    frame:SetClosable(true)
    frame:DisableCloseBtn()
    frame.allowEscClose = true
    local _frameTitleFont = Font:GetNamed("Poppins", "Bold", 68)
    frame.Paint = function(_, w, h)
        if BT._state.page == "heritage_video" then return end
        surface.SetDrawColor(15, 7, 38, 255)
        surface.DrawRect(0, 0, w, h)
        Materials:DrawDuplicate(_BT_COL_FRAME_BG, "boutique_background", 0, 0, w, h, "noclamp smooth")
        local logoW = R:X(134)
        local logoH = R:Y(58)
        Materials:Draw(color_white, "verse_log", w * 0.5 - logoW * 0.5, R:Y(4), logoW, logoH, "noclamp smooth")
        draw.SimpleText("BOUTIQUE", _frameTitleFont, w * 0.5, R:Y(56), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local origClose = frame.Close
    frame.Close = function(s, ...)
        if BT:IsSpinActive() then return end
        origClose(s, ...)
    end

    frame.OnRemove = function()
        BT._frame = nil
        BT._content = nil
        BT._creatorEntry = nil
        BT._topbar = {}
    end

    local content = vgui.Create("DPanel", frame)
    content:SetSize(R:XY(1920, 1080))
    content:SetPos(0, 0)
    content.Paint = function() end
    self._frame = frame
    self._content = content
    self:RebuildContent()
    self._topbar = self._ui.buildTopBar(frame)
end

function BT:ToggleUI()
    if IsValid(self._frame) then
        self:CloseUI()
        return
    end

    self:OpenUI()
end

netstream.Hook(BT.Net.Sync, function(sync) BT:SetStateFromSync(sync) end)

netstream.Hook(BT.Net.Admin.DataSync, function(data)
    if not istable(data) then return end
    if istable(data.products) then BT.Products = data.products end
    if istable(data.rarities) then BT.Rarities = data.rarities; BT:RebuildDerivedData() end
    if istable(data.pack_tenue_packs) then BT.PackTenuePacks = data.pack_tenue_packs end
    if BT._ui.onAdminDataSync then BT._ui.onAdminDataSync(data) end
end)

netstream.Hook(BT.Net.Admin.PlayerData, function(data)
    if BT._ui.onAdminPlayerData then BT._ui.onAdminPlayerData(data) end
end)

netstream.Hook(BT.Net.Admin.RerollPoolData, function(rollType, pool)
    if BT._ui.onAdminRerollPoolData then BT._ui.onAdminRerollPoolData(rollType, pool) end
end)
netstream.Hook(BT.Net.Admin.CreatorStatsData, function(stats)
    if BT._ui.onAdminCreatorStats then BT._ui.onAdminCreatorStats(stats) end
end)
netstream.Hook(BT.Net.Admin.CreatorDetailsData, function(details)
    if BT._ui.onAdminCreatorDetails then BT._ui.onAdminCreatorDetails(details) end
end)
netstream.Hook(BT.Net.Admin.CSVExportResult, function(ok, pathOrErr, count)
    if BT._ui.onAdminCSVExportResult then BT._ui.onAdminCSVExportResult(ok, pathOrErr, count) end
end)
netstream.Hook(BT.Net.RollResult, function(kind, payload)
    kind = tostring(kind or "")
    payload = BT:NormalizeLastRoll(payload)
    if not payload then return end
    BT._state.lastRoll = payload
    if kind == "occult" then
        local spin = BT._state.rollAnim.occult or {
            active = true,
            startedAt = SysTime()
        }

        spin.active = true
        spin.result = payload
        spin.finishAt = SysTime() + 1.35
        BT._state.rollAnim.occult = spin
    elseif kind == "heritage" then
        BT._state.rollAnim.heritageBusy = false
        BT._state.rollAnim.heritageRequestId = 0
        local spin = BT._state.rollAnim.heritageAnim
        if spin and spin.active then
            spin.result = payload
        else
            BT:SetPage("heritage_result")
        end
    else
        LocalPlayer():Notify(payload.name, NOTIFY_HINT, 4)
    end
end)

netstream.Hook(BT.Net.PackTenueSync, function(packs)
    if not istable(packs) then return end
    BT.PackTenuePacks = packs
    if BT._state.page == "packs" and IsValid(BT._content) then
        BT:RebuildContent()
    end
    if BT._ui.onPackTenueSync then BT._ui.onPackTenueSync(packs) end
end)

VERSE.Commands.Add("verse_boutique", function() BT:ToggleUI() end, nil, "client")

-- Ouvre la boutique directement sur la page du tirage pouvoir occulte et lance le roll
VERSE.Commands.Add("verse_occult_roll", function()
    if not IsValid(BT._frame) then
        BT:OpenUI()
    end
    BT:SetPage("power")
    timer.Simple(0.05, function()
        if BT._ui and isfunction(BT._ui.beginOccultRoll) then
            BT._ui.beginOccultRoll()
        end
    end)
end, nil, "client")
