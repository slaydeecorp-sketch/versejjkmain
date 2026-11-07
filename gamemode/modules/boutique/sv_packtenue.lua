-- sv_packtenue.lua
-- Gestion serveur des achats de packs de tenues + persistance DB + admin.
-- ─────────────────────────────────────────────────────────────────────────────

local BT = VERSE.Boutique
local DB = VERSE.DB
if not BT or not DB then return end

local function now()
    return math.floor(os.time())
end

local function esc(v)
    return DB:Escape(tostring(v or ""))
end

local function logErr(...)
    if VERSE.Log and VERSE.Log.Error then
        VERSE.Log:Error("[PackTenue]", ...)
    else
        ErrorNoHalt("[PackTenue] " .. table.concat({...}, " ") .. "\n")
    end
end

local function logInfo(...)
    if VERSE.Log and VERSE.Log.Info then
        VERSE.Log:Info("[PackTenue]", ...)
    end
end

-- ─── Table config ─────────────────────────────────────────────────────────────
local function getTable()
    return tostring(BT:GetConfigValue("TablePackTenue", "verse_boutique_packtenue"))
end

-- ─── Weighted random ─────────────────────────────────────────────────────────
local function pickRandomOutfit(pack)
    local outfits = pack and pack.outfits
    if not istable(outfits) or #outfits == 0 then return nil end

    local total = 0
    for _, o in ipairs(outfits) do
        total = total + math.Clamp(math.floor(tonumber(o.weight) or 50), 1, 100)
    end

    local roll = math.random(1, total)
    local acc = 0
    for _, o in ipairs(outfits) do
        acc = acc + math.Clamp(math.floor(tonumber(o.weight) or 50), 1, 100)
        if roll <= acc then return o end
    end
    return outfits[#outfits]
end

-- ─── DB : lecture/écriture ────────────────────────────────────────────────────
local function packFromRow(row)
    if not istable(row) then return nil end
    local ok, data = pcall(util.JSONToTable, tostring(row.data or ""))
    if not ok or not istable(data) then return nil end
    -- Garantir que id est cohérent
    data.id = tostring(row.pack_id or data.id or "")
    if data.id == "" then return nil end
    return data
end

-- La table est créée dans BT:CreateTables() (sv_boutique.lua), appelé via VERSE.DB:OnReady.
-- LoadPackTenuePacks() est appelé depuis le callback de succès de cette création.
function BT:LoadPackTenuePacks(callback)
    local tbl = getTable()
    DB:Query(("SELECT `pack_id`, `data` FROM `%s` ORDER BY `pack_id` ASC"):format(tbl),
    function(rows)
        local packs = {}
        if istable(rows) then
            for _, row in ipairs(rows) do
                local p = packFromRow(row)
                if p then packs[p.id] = p end
            end
        end
        BT.PackTenuePacks = packs
        logInfo("Chargé", tostring(table.Count(packs)), "pack(s) de tenues.")
        if callback then callback() end
    end,
    function(err)
        logErr("LoadPackTenuePacks SELECT:", tostring(err))
        BT.PackTenuePacks = {}
        if callback then callback() end
        return true
    end)
end

function BT:SavePackTenuePackToDB(packData, callback)
    local packId = tostring(packData.id or ""):Trim()
    if packId == "" then
        if callback then callback(false, "empty_id") end
        return
    end

    local ok, json = pcall(util.TableToJSON, packData, false)
    if not ok or not json then
        if callback then callback(false, "json_error") end
        return
    end

    local tbl = getTable()
    local ts = now()
    local q
    if DB:IsMySQL() then
        q = ("INSERT INTO `%s` (`pack_id`, `data`, `updated_at`) VALUES (%s, %s, %d)"
            .. " ON DUPLICATE KEY UPDATE `data`=%s, `updated_at`=%d"):format(
            tbl,
            esc(packId), esc(json), ts,
            esc(json), ts
        )
    else
        q = ("INSERT OR REPLACE INTO `%s` (`pack_id`, `data`, `updated_at`) VALUES (%s, %s, %d)"):format(
            tbl,
            esc(packId), esc(json), ts
        )
    end

    DB:Query(q, function()
        BT.PackTenuePacks[packId] = packData
        if callback then callback(true) end
    end,
    function(err)
        logErr("SavePackTenuePack:", tostring(err))
        if callback then callback(false, tostring(err)) end
        return true
    end)
end

function BT:DeletePackTenuePackFromDB(packId, callback)
    packId = tostring(packId or ""):Trim()
    if packId == "" then
        if callback then callback(false, "empty_id") end
        return
    end
    local tbl = getTable()
    DB:Query(("DELETE FROM `%s` WHERE `pack_id`=%s"):format(tbl, esc(packId)),
    function()
        BT.PackTenuePacks[packId] = nil
        if callback then callback(true) end
    end,
    function(err)
        logErr("DeletePackTenuePack:", tostring(err))
        if callback then callback(false, tostring(err)) end
        return true
    end)
end

-- ─── Broadcast sync ───────────────────────────────────────────────────────────
function BT:BroadcastPackTenueSync()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            netstream.Start(ply, BT.Net.PackTenueSync, BT.PackTenuePacks or {})
        end
    end
end

-- ─── Init : LoadPackTenuePacks est appelé par BT:CreateTables() dans sv_boutique.lua
-- après que VERSE.DB:OnReady a confirmé la connexion et la création de la table.

-- ─── Achat d'un pack ─────────────────────────────────────────────────────────
function BT:PurchasePackTenue(ply, packId, callback)
    if not IsValid(ply) then
        if callback then callback(false, "invalid_player") end
        return
    end

    local steamID = self:GetSteamID(ply)
    if not self:IsValidSteamID(steamID) then
        if callback then callback(false, "invalid_steamid") end
        return
    end

    packId = tostring(packId or ""):Trim()
    local pack = (self.PackTenuePacks or {})[packId]
    if not pack then
        if callback then callback(false, "invalid_pack") end
        return
    end

    local outfit = pickRandomOutfit(pack)
    if not outfit then
        if callback then callback(false, "empty_pack") end
        return
    end

    if not self:AcquireBusy(steamID, "pack_tenue") then
        if callback then callback(false, "busy") end
        return
    end

    local price = math.max(0, math.floor(tonumber(pack.price) or 0))

    self:LoadStateBySteamID(steamID, function(ok, stateOrErr)
        if not ok then
            self:ReleaseBusy(steamID, "pack_tenue")
            if callback then callback(false, stateOrErr) end
            return
        end

        local state = self:SanitizeSyncState(stateOrErr)

        local _ptcc = state.account.creator_code
        if _ptcc and _ptcc ~= "" then
            local _ptcr = self:GetCreator(_ptcc)
            if _ptcr and (_ptcr.buyer_discount or 0) > 0 then
                price = math.max(1, price - math.floor(price * _ptcr.buyer_discount / 100))
            end
        end

        if state.account.coins < price then
            self:ReleaseBusy(steamID, "pack_tenue")
            if callback then callback(false, "not_enough_coins") end
            return
        end

        local outfitId = tostring(outfit.id or ""):Trim()
        if outfitId == "" then
            self:ReleaseBusy(steamID, "pack_tenue")
            if callback then callback(false, "invalid_outfit") end
            return
        end

        -- Résoudre le modèle depuis BT.OutfitItems
        local outfitDef = (BT.OutfitItems or {})[outfitId]
        local outfitModel = tostring((outfitDef and outfitDef.model) or outfit.model or "")
        local outfitName  = tostring((outfitDef and outfitDef.name)  or outfit.name  or outfitId)

        state.account.coins            = state.account.coins - price
        state.account.total_spent      = (state.account.total_spent or 0) + price
        state.account.last_purchase_at = now()
        state.account.updated_at       = state.account.last_purchase_at
        -- Ne pas toucher à state.items : la tenue va dans l'inventaire réel.

        -- Sauvegarder uniquement la mise à jour du compte (débit coins).
        self:PersistState(steamID, state, {}, function(saveOk, saveErr)
            self:ReleaseBusy(steamID, "pack_tenue")

            if not saveOk then
                logErr("PersistState failed for", steamID, ":", tostring(saveErr))
                if callback then callback(false, saveErr) end
                return
            end

            self:SetCachedState(steamID, state)

            self:WriteTransaction(steamID, "pack_tenue", -price, outfitId, {
                pack_id     = pack.id,
                pack_name   = pack.name,
                outfit_id   = outfitId,
                outfit_name = outfitName,
            })

            local _ptcc2 = state.account.creator_code
            if _ptcc2 and _ptcc2 ~= "" then
                self:LogCreatorEvent(_ptcc2, steamID, "pack_tenue", price, packId)
                local _ptcr2 = self:GetCreator(_ptcc2)
                if _ptcr2 and _ptcr2.steamid ~= "" and _ptcr2.payout_rate > 0 then
                    local _payout = math.max(1, math.floor(price * _ptcr2.payout_rate / 100))
                    self:AddCoinsBySteamID(_ptcr2.steamid, _payout, "creator_payout:" .. _ptcr2.code)
                end
            end

            -- Donner la tenue dans l'inventaire réel du joueur.
            if IsValid(ply) and isfunction(ply.AddItem) then
                ply:AddItem(outfitId, 1, nil, function(itemOk, itemErr)
                    if not itemOk then
                        logErr("AddItem échoué pour", steamID, "item", outfitId, ":", tostring(itemErr))
                    end
                end)
            else
                logErr("ply:AddItem indisponible pour", steamID, "item", outfitId)
            end

            -- Sync boutique (mise à jour des coins côté client).
            self:SyncPlayer(ply)

            if callback then callback(true, {
                id    = outfitId,
                name  = outfitName,
                model = outfitModel,
            }) end
        end)
    end)
end

-- ─── Netstream : achat joueur ─────────────────────────────────────────────────
netstream.Hook(BT.Net.BuyPackTenue, function(ply, packId)
    if not IsValid(ply) then return end

    packId = tostring(packId or ""):Trim()
    if packId == "" then return end

    BT:PurchasePackTenue(ply, packId, function(ok, outfitOrErr)
        if not ok then
            local msgs = {
                invalid_pack     = "Pack introuvable.",
                empty_pack       = "Ce pack ne contient aucune tenue.",
                not_enough_coins = "Pas assez de coins.",
                busy             = "Action déjà en cours.",
                invalid_outfit   = "Tenue invalide dans ce pack.",
            }
            local msg = msgs[tostring(outfitOrErr or "")] or ("Erreur: " .. tostring(outfitOrErr))
            if IsValid(ply) and ply.Notify then ply:Notify(msg, NOTIFY_ERROR, 4) end
            netstream.Start(ply, BT.Net.PackTenueResult, false, msg)
            return
        end

        netstream.Start(ply, BT.Net.PackTenueResult, true, {
            id    = tostring(outfitOrErr.id    or ""),
            name  = tostring(outfitOrErr.name  or "Tenue"),
            model = tostring(outfitOrErr.model or ""),
        })
    end)
end)

-- ─── Reroll d'un pack tenue ──────────────────────────────────────────────────
netstream.Hook(BT.Net.RerollPackTenue, function(ply, packId)
    if not IsValid(ply) then return end

    packId = tostring(packId or ""):Trim()
    if packId == "" then return end

    local pack = (BT.PackTenuePacks or {})[packId]
    if not pack then
        netstream.Start(ply, BT.Net.RerollTenueResult, false, "invalid_pack")
        return
    end

    local price   = math.max(0, math.floor(tonumber(pack.price) or 0))
    local steamID = BT:GetSteamID(ply)
    if not BT:IsValidSteamID(steamID) then
        netstream.Start(ply, BT.Net.RerollTenueResult, false, "invalid_steamid")
        return
    end

    if not BT:AcquireBusy(steamID, "reroll_tenue") then
        netstream.Start(ply, BT.Net.RerollTenueResult, false, "busy")
        return
    end

    BT:LoadStateBySteamID(steamID, function(ok, stateOrErr)
        if not ok then
            BT:ReleaseBusy(steamID, "reroll_tenue")
            netstream.Start(ply, BT.Net.RerollTenueResult, false, tostring(stateOrErr))
            return
        end

        local state = BT:SanitizeSyncState(stateOrErr)

        local _rtcc = state.account.creator_code
        if _rtcc and _rtcc ~= "" then
            local _rtcr = BT:GetCreator(_rtcc)
            if _rtcr and (_rtcr.buyer_discount or 0) > 0 then
                price = math.max(1, price - math.floor(price * _rtcr.buyer_discount / 100))
            end
        end

        if state.account.coins < price then
            BT:ReleaseBusy(steamID, "reroll_tenue")
            netstream.Start(ply, BT.Net.RerollTenueResult, false, "not_enough_coins")
            return
        end

        local outfit = pickRandomOutfit(pack)
        if not outfit then
            BT:ReleaseBusy(steamID, "reroll_tenue")
            netstream.Start(ply, BT.Net.RerollTenueResult, false, "empty_pack")
            return
        end

        local outfitId  = tostring(outfit.id or ""):Trim()
        local outfitDef = (BT.OutfitItems or {})[outfitId]
        local outfitModel = tostring((outfitDef and outfitDef.model) or outfit.model or "")
        local outfitName  = tostring((outfitDef and outfitDef.name)  or outfit.name  or outfitId)

        state.account.coins       = state.account.coins - price
        state.account.total_spent = (state.account.total_spent or 0) + price
        state.account.last_purchase_at = now()
        state.account.updated_at       = state.account.last_purchase_at

        BT:PersistState(steamID, state, {}, function(saveOk, saveErr)
            BT:ReleaseBusy(steamID, "reroll_tenue")

            if not saveOk then
                logErr("Reroll PersistState:", steamID, tostring(saveErr))
                netstream.Start(ply, BT.Net.RerollTenueResult, false, tostring(saveErr))
                return
            end

            BT:SetCachedState(steamID, state)
            BT:WriteTransaction(steamID, "reroll_tenue", -price, outfitId, {
                pack_id = pack.id, pack_name = pack.name,
                outfit_id = outfitId, outfit_name = outfitName,
            })

            local _rtcc2 = state.account.creator_code
            if _rtcc2 and _rtcc2 ~= "" then
                BT:LogCreatorEvent(_rtcc2, steamID, "reroll_tenue", price, packId)
                local _rtcr2 = BT:GetCreator(_rtcc2)
                if _rtcr2 and _rtcr2.steamid ~= "" and _rtcr2.payout_rate > 0 then
                    local _payout = math.max(1, math.floor(price * _rtcr2.payout_rate / 100))
                    BT:AddCoinsBySteamID(_rtcr2.steamid, _payout, "creator_payout:" .. _rtcr2.code)
                end
            end

            if IsValid(ply) and isfunction(ply.AddItem) then
                ply:AddItem(outfitId, 1, nil, function(itemOk, itemErr)
                    if not itemOk then
                        logErr("Reroll AddItem échoué:", steamID, outfitId, tostring(itemErr))
                    end
                end)
            end

            BT:SyncPlayer(ply)

            netstream.Start(ply, BT.Net.RerollTenueResult, true, {
                id    = outfitId,
                name  = outfitName,
                model = outfitModel,
            })
        end)
    end)
end)

-- ─── Netstream : admin – sauvegarder un pack ─────────────────────────────────
netstream.Hook(BT.Net.Admin.SavePackTenue, function(ply, packData)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then return end
    if not istable(packData) then return end

    -- Normalisation minimale
    packData.id = tostring(packData.id or ""):Trim()
    if packData.id == "" then return end
    packData.name       = tostring(packData.name or "Pack"):Trim()
    packData.price      = math.max(0, math.floor(tonumber(packData.price) or 0))
    packData.sort_order = math.floor(tonumber(packData.sort_order) or 0)
    packData.icon       = tostring(packData.icon or "")
    packData.chest_img  = tostring(packData.chest_img or ""):Trim()
    local g = tostring(packData.gender or ""):lower():Trim()
    packData.gender     = (g == "male" or g == "female") and g or nil

    -- Normalisation des outfits
    local outfits = {}
    if istable(packData.outfits) then
        for _, o in ipairs(packData.outfits) do
            local oid = tostring(o.id or ""):Trim()
            if oid ~= "" then
                outfits[#outfits + 1] = {
                    id     = oid,
                    weight = math.Clamp(math.floor(tonumber(o.weight) or 50), 1, 100),
                }
            end
        end
    end
    packData.outfits = outfits

    BT:SavePackTenuePackToDB(packData, function(ok, err)
        if not ok then
            if IsValid(ply) and ply.Notify then ply:Notify("Erreur sauvegarde pack: " .. tostring(err), NOTIFY_ERROR, 5) end
            return
        end
        if IsValid(ply) and ply.Notify then ply:Notify("Pack '" .. packData.name .. "' sauvegardé.", NOTIFY_HINT, 4) end
        BT:BroadcastPackTenueSync()
    end)
end)

-- ─── Netstream : admin – supprimer un pack ───────────────────────────────────
netstream.Hook(BT.Net.Admin.DelPackTenue, function(ply, packId)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then return end

    packId = tostring(packId or ""):Trim()
    if packId == "" then return end

    BT:DeletePackTenuePackFromDB(packId, function(ok, err)
        if not ok then
            if IsValid(ply) and ply.Notify then ply:Notify("Erreur suppression pack: " .. tostring(err), NOTIFY_ERROR, 5) end
            return
        end
        if IsValid(ply) and ply.Notify then ply:Notify("Pack '" .. packId .. "' supprimé.", NOTIFY_HINT, 4) end
        BT:BroadcastPackTenueSync()
    end)
end)
