VERSE.Boutique = VERSE.Boutique or {}
local BT = VERSE.Boutique
BT.Config = {
    Enabled = true,
    TableAccounts = "verse_boutique_accounts",
    TableItems = "verse_boutique_items",
    TableTransactions = "verse_boutique_transactions",
    TableProducts = "verse_boutique_products",
    TableRarities = "verse_boutique_rarities",
    TableRerollPool = "verse_boutique_reroll_pool",
    TableCreators = "verse_boutique_creators",
    TableCreatorEvents = "verse_boutique_creator_events",
    TableCreatorLinks = "verse_boutique_creator_links",
    TablePackTenue = "verse_boutique_packtenue",
    DefaultCoins = 0,
    MaxCreatorCodeLength = 24,
    CreatorLinkBonus = 100,
    BuyCreditsURL     = "https://verse-jujutsu-kaisen.tebex.io/category/3098926",
    RerollTenuePrice  = 80,   -- coins par reroll (indépendant du prix du pack)
}

BT.Net = {
    RequestSync = "VERSE::Boutique::RequestSync",
    Sync = "VERSE::Boutique::Sync",
    BuyProduct = "VERSE::Boutique::BuyProduct",
    UseOwnedItem = "VERSE::Boutique::UseOwnedItem",
    SaveCreatorCode = "VERSE::Boutique::SaveCreatorCode",
    BuyPackTenue      = "VERSE::Boutique::BuyPackTenue",
    PackTenueResult   = "VERSE::Boutique::PackTenueResult",
    PackTenueSync     = "VERSE::Boutique::PackTenueSync",
    RerollPackTenue   = "VERSE::Boutique::RerollPackTenue",
    RerollTenueResult = "VERSE::Boutique::RerollTenueResult",
    StartOccultRoll = "VERSE::Boutique::StartOccultRoll",
    StartHeritageRoll = "VERSE::Boutique::StartHeritageRoll",
    ResolveHeritageRoll = "VERSE::Boutique::ResolveHeritageRoll",
    RollResult = "VERSE::Boutique::RollResult",
    Admin = {
        RequestData = "VERSE::BA::ReqData",
        DataSync = "VERSE::BA::DataSync",
        SaveProduct = "VERSE::BA::SaveProduct",
        DelProduct = "VERSE::BA::DelProduct",
        SaveRarity = "VERSE::BA::SaveRarity",
        DelRarity = "VERSE::BA::DelRarity",
        GetPlayer = "VERSE::BA::GetPlayer",
        PlayerData = "VERSE::BA::PlayerData",
        ModBalance = "VERSE::BA::ModBalance",
        GiveItem = "VERSE::BA::GiveItem",
        RemoveItem = "VERSE::BA::RemoveItem",
        GetRerollPool = "VERSE::BA::GetRerollPool",
        RerollPoolData = "VERSE::BA::RerollPoolData",
        SavePoolEntry = "VERSE::BA::SavePoolEntry",
        DelPoolEntry = "VERSE::BA::DelPoolEntry",
        SaveCreator = "VERSE::BA::SaveCreator",
        DelCreator = "VERSE::BA::DelCreator",
        GetCreatorStats = "VERSE::BA::GetCreatorStats",
        CreatorStatsData = "VERSE::BA::CreatorStatsData",
        GetCreatorDetails = "VERSE::BA::GetCreatorDetails",
        CreatorDetailsData = "VERSE::BA::CreatorDetailsData",
        ExportCreatorCSV = "VERSE::BA::ExportCreatorCSV",
        CSVExportResult = "VERSE::BA::CSVExportResult",
        SavePackTenue   = "VERSE::BA::SavePackTenue",
        DelPackTenue    = "VERSE::BA::DelPackTenue",
    },
}

BT.Products = BT.Products or {}
BT.Rarities = BT.Rarities or {}
BT.RarityColors = BT.RarityColors or {}
BT.PageProducts = BT.PageProducts or {
    rerolls = {},
    packs = {},
    outfits = {}
}

BT.RollTabs = BT.RollTabs or {}
BT.HomeCards = {
    {
        id = "rerolls",
        kind = "card",
        type = "page",
        page = "rerolls",
        x = 221, y = 226, w = 340, h = 533,
        accent = Color(78, 254, 122),
        char_bg = "acheter_char_background_new",
    },
    {
        id = "packs",
        kind = "card",
        type = "page",
        page = "packs",
        x = 600, y = 227, w = 340, h = 533,
        accent = Color(0, 187, 255),
        char_bg = "packs_char_background_new",
    },
    {
        id = "premium",
        kind = "card",
        type = "url",
        url = "https://verse-jujutsu-kaisen.tebex.io/category/premium",
        x = 979, y = 227, w = 340, h = 533,
        accent = Color(255, 76, 76),
        char_bg = "premium_char_background_new",
    },
    {
        id = "outfits",
        kind = "card",
        type = "page",
        page = "outfits",
        x = 1358, y = 226, w = 340, h = 533,
        accent = Color(255, 207, 85),
        char_bg = "skin_char_background_new",
    },
    {
        id = "owned",
        kind = "banner",
        type = "page",
        page = "owned",
        x = 221, y = 789, w = 1477, h = 189,
        accent = Color(171, 82, 255),
        char_bg = "reroll_char_background_new",
    },
}

function BT:GetConfigValue(key, default)
    local cfg = self.Config or {}
    local value = cfg[key]
    if value == nil then return default end
    return value
end

function BT:GetAccountTableName()
    return tostring(self:GetConfigValue("TableAccounts", "verse_boutique_accounts"))
end

function BT:GetItemsTableName()
    return tostring(self:GetConfigValue("TableItems", "verse_boutique_items"))
end

function BT:GetDefaultCoins()
    return math.max(0, math.floor(tonumber(self:GetConfigValue("DefaultCoins", 0)) or 0))
end

function BT:GetMaxCreatorCodeLength()
    return math.Clamp(math.floor(tonumber(self:GetConfigValue("MaxCreatorCodeLength", 24)) or 24), 4, 48)
end

function BT:GetTransactionsTableName()
    return tostring(self:GetConfigValue("TableTransactions", "verse_boutique_transactions"))
end

function BT:GetProductsTableName()
    return tostring(self:GetConfigValue("TableProducts", "verse_boutique_products"))
end

function BT:GetRaritiesTableName()
    return tostring(self:GetConfigValue("TableRarities", "verse_boutique_rarities"))
end

function BT:GetRerollPoolTableName()
    return tostring(self:GetConfigValue("TableRerollPool", "verse_boutique_reroll_pool"))
end


function BT:GetCreatorsTableName()
    return tostring(self:GetConfigValue("TableCreators", "verse_boutique_creators"))
end

function BT:GetCreatorEventsTableName()
    return tostring(self:GetConfigValue("TableCreatorEvents", "verse_boutique_creator_events"))
end

function BT:GetCreatorLinksTableName()
    return tostring(self:GetConfigValue("TableCreatorLinks", "verse_boutique_creator_links"))
end


function BT:RebuildDerivedData()
    self.RarityColors = {}
    for _, r in ipairs(self.Rarities or {}) do
        self.RarityColors[tostring(r.id or "")] = Color(tonumber(r.color_r) or 160, tonumber(r.color_g) or 160, tonumber(r.color_b) or 160)
    end

    self.PageProducts = {
        rerolls = {},
        packs = {},
        outfits = {}
    }

    local sorted = {}
    for _, p in pairs(self.Products or {}) do
        if (tonumber(p.enabled) or 1) ~= 0 then sorted[#sorted + 1] = p end
    end

    table.sort(sorted, function(a, b) return (tonumber(a.sort_order) or 0) < (tonumber(b.sort_order) or 0) end)
    for _, p in ipairs(sorted) do
        local cat = tostring(p.category or "")
        if self.PageProducts[cat] then self.PageProducts[cat][#self.PageProducts[cat] + 1] = p.id end
    end

    local rollModeMap = {
        open_occult_page = {
            page = "power",
            label = "Pouvoir occulte",
            accent = Color(98, 176, 255),
            hero = "revolution_pouvoir_img"
        },
        open_heritage_page = {
            page = "heritage",
            label = "Héritage",
            accent = Color(255, 76, 76),
            hero = "revolution_pouvoir_img"
        },
    }

    local addedModes = {}
    self.RollTabs = {}
    for _, p in ipairs(sorted) do
        local info = rollModeMap[tostring(p.use_mode or "")]
        if info and not addedModes[p.use_mode] then
            addedModes[p.use_mode] = true
            local customBanner = tostring(p.banner_image or "")
            self.RollTabs[#self.RollTabs + 1] = {
                page = info.page,
                label = (p.name and p.name ~= "") and p.name or info.label,
                accent_active = p.accent or info.accent,
                item_id = p.id,
                hero_img = (customBanner ~= "" and customBanner) or info.hero,
                hero_is_path = customBanner ~= "",
                launch_label = (p.use_text ~= "" and p.use_text) or "Lancer",
                video_url = tostring(p.video_url or ""),
            }
        end
    end

    table.sort(self.RollTabs, function(a, b)
        local ord = {
            power = 1,
            heritage = 2
        }
        return (ord[a.page] or 9) < (ord[b.page] or 9)
    end)
end

function BT:NormalizeCreatorCode(code)
    code = tostring(code or ""):Trim()
    code = string.sub(code, 1, self:GetMaxCreatorCodeLength())
    if code == "" then return "" end
    -- Whitelist stricte : uniquement caractères alphanumériques, tiret, underscore
    code = string.gsub(code, "[^%w%-_]", "")
    if code == "" then return "" end
    -- Défense en profondeur : rejet si path traversal détecté après normalisation
    if string.find(code, "%.%.", 1, true) or string.find(code, "/", 1, true) or string.find(code, "\\", 1, true) then return "" end
    return string.upper(code)
end

function BT:IsValidSteamID(steamID)
    steamID = tostring(steamID or ""):Trim()
    if steamID == "" then return false end
    return string.match(steamID, "^STEAM_%d:%d:%d+$") ~= nil
end

function BT:GetProduct(productId)
    productId = tostring(productId or "")
    if productId == "" then return nil end
    return self.Products and self.Products[productId] or nil
end

function BT:GetPageProductList(pageId)
    pageId = tostring(pageId or "")
    local raw = self.PageProducts and self.PageProducts[pageId] or nil
    if not istable(raw) then return {} end
    local out = {}
    for i = 1, #raw do
        local product = self:GetProduct(raw[i])
        if product then out[#out + 1] = product end
    end
    return out
end

function BT:GetRarityColor(rarity)
    rarity = tostring(rarity or "common")
    local colors = self.RarityColors or {}
    return colors[rarity] or colors.common or color_white
end

function BT:GetDefaultAccount(steamID)
    return {
        steamid = tostring(steamID or ""),
        coins = self:GetDefaultCoins(),
        creator_code = "",
        total_spent = 0,
        last_roll_type = "",
        last_roll_payload = nil,
        last_purchase_at = 0,
        created_at = 0,
        updated_at = 0,
    }
end

function BT:NormalizeLastRoll(data)
    if not istable(data) then return nil end
    local out = {
        id = tostring(data.id or ""),
        name = tostring(data.name or ""),
        rarity = tostring(data.rarity or "common"),
        kind = tostring(data.kind or ""),
        asset = tostring(data.asset or ""),
        video_url = tostring(data.video_url or ""),
        at = math.floor(tonumber(data.at) or 0),
        -- Champs héritage : conservés pour le popup de choix post-roll
        has_existing_heritage = data.has_existing_heritage == true,
        existing_branch_name  = tostring(data.existing_branch_name or ""),
    }

    if out.id == "" and out.name == "" then return nil end
    return out
end

function BT:NormalizeAccount(raw, steamID)
    local out = self:GetDefaultAccount(steamID or raw and raw.steamid or "")
    if not istable(raw) then return out end
    out.steamid = tostring(raw.steamid or out.steamid or "")
    out.coins = math.max(0, math.floor(tonumber(raw.coins) or out.coins))
    out.creator_code = self:NormalizeCreatorCode(raw.creator_code or out.creator_code)
    out.total_spent = math.max(0, math.floor(tonumber(raw.total_spent) or out.total_spent))
    out.last_roll_type = tostring(raw.last_roll_type or out.last_roll_type or "")
    out.last_roll_payload = self:NormalizeLastRoll(raw.last_roll_payload)
    out.last_purchase_at = math.max(0, math.floor(tonumber(raw.last_purchase_at) or out.last_purchase_at))
    out.created_at = math.max(0, math.floor(tonumber(raw.created_at) or out.created_at))
    out.updated_at = math.max(0, math.floor(tonumber(raw.updated_at) or out.updated_at))
    return out
end

function BT:NormalizeItems(raw)
    local out = {}
    if not istable(raw) then return out end
    for itemId, amount in pairs(raw) do
        itemId = tostring(itemId or "")
        amount = math.max(0, math.floor(tonumber(amount) or 0))
        if itemId ~= "" and amount > 0 then out[itemId] = amount end
    end
    return out
end

function BT:NormalizeTransaction(raw)
    if not istable(raw) then return nil end
    local payload = raw.payload
    if type(payload) == "string" and payload ~= "" then
        local ok, decoded = pcall(util.JSONToTable, payload)
        payload = (ok and istable(decoded)) and decoded or {}
    elseif not istable(payload) then
        payload = {}
    end
    return {
        id = math.floor(tonumber(raw.id) or 0),
        tx_type = tostring(raw.tx_type or ""),
        item_id = tostring(raw.item_id or ""),
        coins_delta = math.floor(tonumber(raw.coins_delta) or 0),
        payload = payload,
        created_at = math.floor(tonumber(raw.created_at) or 0),
    }
end

function BT:NormalizeTransactions(raw)
    local out = {}
    if not istable(raw) then return out end
    for i = 1, #raw do
        local tx = self:NormalizeTransaction(raw[i])
        if tx and tx.tx_type ~= "" then out[#out + 1] = tx end
    end
    return out
end

function BT:SanitizeSyncState(state)
    state = istable(state) and state or {}
    return {
        account = self:NormalizeAccount(state.account or {}, state.account and state.account.steamid or ""),
        items = self:NormalizeItems(state.items or {}),
        transactions = self:NormalizeTransactions(state.transactions or {}),
    }
end