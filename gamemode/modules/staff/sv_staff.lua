local S  = VERSE.Staff
local CH = VERSE.Characters
local DB = VERSE.DB

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function isSuperAdmin(ply)
    if not IsValid(ply) then return false end
    -- 1. Vérif GMod native (groupe "superadmin" standard)
    if ply:IsSuperAdmin() then return true end
    -- 2. Check direct sur VERSE.Config (ne dépend pas de l'init de VERSE.Access)
    local cfg = VERSE.Config and VERSE.Config.Access
    if cfg then
        local group = ply:GetUserGroup()
        local plus = cfg.StaffPlusGroups
        if istable(plus) then
            for _, g in ipairs(plus) do
                if g == group then return true end
            end
        end
        local devs = cfg.Developers
        if istable(devs) then
            local sid = ply:SteamID()
            for _, d in ipairs(devs) do
                if d == sid then return true end
            end
        end
    end
    -- 3. Fallback via VERSE.Access (avec cache interne)
    local A = VERSE.Access
    if A and isfunction(A.IsStaffPlus) and A:IsStaffPlus(ply) then return true end
    return false
end

-- Peut entrer en mode staff (superadmin bypass + permission SAM verse_staff)
local function canEnterStaff(ply)
    if isSuperAdmin(ply) then return true end
    return isfunction(ply.HasPermission) and ply:HasPermission("verse_staff")
end

-- Peut effectuer une action spécifique (superadmin bypass + permission SAM dédiée)
local function hasStaffPerm(ply, perm)
    if isSuperAdmin(ply) then return true end
    return isfunction(ply.HasPermission) and ply:HasPermission(perm)
end

-- Wrapper nil-safe pour VERSE.Log:Info (évite crash si le module logger n'est pas encore chargé)
local function staffLog(msg)
    if VERSE.Log then VERSE.Log:Info(msg) end
end

local function getRPName(ply)
    if not IsValid(ply) then return "?" end
    if CH and CH.GetSelected and CH.GetDisplayName then
        local char = CH:GetSelected(ply)
        if istable(char) then
            local n = CH:GetDisplayName(char)
            if n and n ~= "" then return n end
        end
    end
    return ply:Nick()
end

local function getJobName(ply)
    if not IsValid(ply) then return "" end
    local jobId = ply:GetPData("verse_job_id", "")
    if jobId ~= "" and VERSE.Jobs then
        local job = VERSE.Jobs:Get(jobId)
        if job then return tostring(job.name or jobId) end
    end
    return tostring(ply:GetUserGroup())
end

local function getMoney(ply)
    if not IsValid(ply) then return 0 end
    return isfunction(ply.GetMoney) and ply:GetMoney() or 0
end

local function getCharId(ply)
    if not IsValid(ply) then return nil end
    if CH and CH.GetSelected then
        local char = CH:GetSelected(ply)
        if istable(char) then return tonumber(char.id) end
    end
    return nil
end

local function findByUID(uid)
    for _, p in ipairs(player.GetAll()) do
        if p:UserID() == tonumber(uid) then return p end
    end
end

-- ─── Billy's Logs (GAS) helper ────────────────────────────────────────────────

S._GASModule = nil

local function billLog(staff, action)
    if not S._GASModule then return end
    if not (GAS and GAS.Logging) then return end
    GAS.Logging.CurrentLog = {{}}
    GAS.Logging:FormatPlayer(staff)
    GAS.Logging:Highlight(action)
    S._GASModule:LogPhrase("command_used")
end

-- ─── Système de warns ─────────────────────────────────────────────────────────

S._warnCache = S._warnCache or {}  -- [charId] = count

local function getWarnCount(ply)
    local cid = getCharId(ply)
    return cid and (S._warnCache[cid] or 0) or 0
end

local function loadWarns(charId)
    charId = tonumber(charId)
    if not charId or not DB then return end
    DB:Query(("SELECT COUNT(*) as cnt FROM verse_staff_warns WHERE char_id=%d"):format(charId))
        :Next(function(res)
            local row = res.rows and res.rows[1]
            S._warnCache[charId] = math.floor(tonumber(row and row.cnt) or 0)
        end)
        :Catch(function()
            S._warnCache[charId] = 0
        end)
end

local function createWarnTable()
    if not DB then return end
    local q
    if DB:IsMySQL() then
        q = [[CREATE TABLE IF NOT EXISTS verse_staff_warns (
            id         INT NOT NULL AUTO_INCREMENT,
            char_id    INT NOT NULL,
            reason     VARCHAR(512) NOT NULL,
            staff_name VARCHAR(128) NOT NULL,
            created_at INT NOT NULL,
            PRIMARY KEY (id),
            KEY idx_char (char_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
        DB:Query(q, function() end, function(err)
            if VERSE.Log then VERSE.Log:Error("[Staff] warn table: " .. tostring(err)) end
            return true
        end)
    else
        q = [[CREATE TABLE IF NOT EXISTS verse_staff_warns (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            char_id    INTEGER NOT NULL,
            reason     TEXT NOT NULL,
            staff_name TEXT NOT NULL,
            created_at INTEGER NOT NULL
        )]]
        DB:Query(q, function()
            DB:Query([[CREATE INDEX IF NOT EXISTS idx_warns_char ON verse_staff_warns (char_id)]], function() end, function() return true end)
        end, function(err)
            if VERSE.Log then VERSE.Log:Error("[Staff] warn table: " .. tostring(err)) end
            return true
        end)
    end
end

-- ─── Activation / désactivation ───────────────────────────────────────────────

local function applyStaffMode(ply, active)
    if active then
        ply:GodEnable()
        ply:SetRenderMode(RENDERMODE_TRANSALPHA)
        ply:SetColor(Color(255, 255, 255, 0))
        ply:SetMoveType(MOVETYPE_NOCLIP)
        staffLog("[Staff] " .. ply:SteamID() .. " (" .. ply:Nick() .. ") a activé le mode staff ESP")
    else
        ply:GodDisable()
        ply:SetRenderMode(RENDERMODE_NORMAL)
        ply:SetColor(Color(255, 255, 255, 255))
        ply:SetMoveType(MOVETYPE_WALK)
        staffLog("[Staff] " .. ply:SteamID() .. " (" .. ply:Nick() .. ") a désactivé le mode staff ESP")
    end
    ply._staffMode = active
    ply:SetNWBool("VERSE_StaffMode", active)
    netstream.Start(ply, S.Net.Toggle, active)
    pcall(billLog, ply, active and "staff mode ON" or "staff mode OFF")
end

local function toggleStaff(ply)
    if not canEnterStaff(ply) then
        ply:ChatPrint("[Staff] Acces refuse. (groupe: " .. tostring(ply:GetUserGroup()) .. ")")
        return
    end
    applyStaffMode(ply, not ply._staffMode)
end

-- SAM.CanNoClip retourne true en premier et stoppe la chaîne avant qu'on n'arrive.
-- On le supprime et on absorbe sa logique ici.
hook.Remove("PlayerNoClip", "SAM.CanNoClip")
hook.Add("PlayerNoClip", "VERSE::Staff::NoClip", function(ply, desired)
    if canEnterStaff(ply) then
        applyStaffMode(ply, desired)
        return false
    end
    if isfunction(ply.HasPermission) and ply:HasPermission("can_noclip") then
        return true
    end
end)

hook.Add("PlayerSay", "VERSE::Staff::ChatCmd", function(ply, text)
    if string.lower(string.Trim(text)) == "!staff" then
        toggleStaff(ply)
        return ""
    end
end)

-- ─── Envoi périodique des données ESP ─────────────────────────────────────────
-- Cadencé à 2s. Les données par joueur sont pré-calculées une seule fois
-- (O(joueurs)) puis distribuées à chaque staff (évite O(staff × joueurs) GetPData).

timer.Create("VERSE::Staff::DataUpdate", 2, 0, function()
    local allPlayers = player.GetAll()
    local staffList  = {}
    for _, ply in ipairs(allPlayers) do
        if ply._staffMode then staffList[#staffList + 1] = ply end
    end
    if #staffList == 0 then return end

    local maxDist = S.Config.ESPMaxDist or 0

    -- Pré-calculer les données de chaque joueur une seule fois
    local pdata = {}
    for _, target in ipairs(allPlayers) do
        pdata[target] = {
            uid     = target:UserID(),
            name    = getRPName(target),
            job     = getJobName(target),
            hp      = target:Health(),
            maxHp   = math.max(1, target:GetMaxHealth()),
            mana    = isfunction(target.GetMana) and math.floor(target:GetMana()) or 0,
            maxMana = isfunction(target.GetManaMax) and math.max(1, math.floor(target:GetManaMax())) or 100,
            money   = getMoney(target),
            warns   = getWarnCount(target),
            frozen  = target._staffFrozen == true,
        }
    end

    for _, staff in ipairs(staffList) do
        if not IsValid(staff) then continue end
        local staffPos = staff:GetPos()
        local data = {}
        for _, target in ipairs(allPlayers) do
            if maxDist > 0 and staffPos:Distance(target:GetPos()) > maxDist then continue end
            data[#data + 1] = pdata[target]
        end
        netstream.Start(staff, S.Net.Data, data)
    end
end)

-- ─── Handlers netstream ───────────────────────────────────────────────────────

netstream.Hook(S.Net.Kick, function(ply, targetUID, reason)
    if not hasStaffPerm(ply, "can_kick") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    reason = tostring(reason or "Kick par un membre du staff.")
    staffLog("[Staff] " .. ply:Nick() .. " a kick " .. target:Nick() .. " | " .. reason)
    billLog(ply, "kick " .. target:Nick() .. " | " .. reason)
    target:Kick(reason)
end)

netstream.Hook(S.Net.Ban, function(ply, targetUID, minutes, reason)
    if not hasStaffPerm(ply, "can_ban") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    reason  = tostring(reason or "Ban par un membre du staff.")
    minutes = math.max(0, math.floor(tonumber(minutes) or 0))
    -- Ban permanent (minutes=0) réservé aux superadmins
    if minutes == 0 and not isSuperAdmin(ply) then
        minutes = S.Config.MaxBanMinutes or 10080
    end
    staffLog("[Staff] " .. ply:Nick() .. " a ban " .. target:Nick() .. " (" .. minutes .. " min) | " .. reason)
    billLog(ply, "ban " .. target:Nick() .. " (" .. minutes .. "min) | " .. reason)
    target:Ban(minutes, reason)
end)

netstream.Hook(S.Net.Search, function(ply, targetUID)
    if not hasStaffPerm(ply, "verse_search") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    local inv = {}
    local INV = VERSE.Inventory
    if CH and INV then
        local char   = CH:GetSelected(target)
        local charId = char and tonumber(char.id)
        local cache  = charId and INV._cache and INV._cache[charId]
        if cache then
            for slot, entry in pairs(cache) do
                if istable(entry) then
                    local itemDef = INV:GetItem(tostring(entry.item_id or ""))
                    inv[#inv + 1] = {
                        slot   = tonumber(slot),
                        id     = tostring(entry.item_id or ""),
                        name   = itemDef and tostring(itemDef.name or entry.item_id) or tostring(entry.item_id),
                        amount = tonumber(entry.amount) or 1,
                        icon   = itemDef and tostring(itemDef.icon or "") or "",
                    }
                end
            end
        end
    end
    table.sort(inv, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    netstream.Start(ply, S.Net.Inventory, target:UserID(), getRPName(target), inv)
end)

netstream.Hook(S.Net.Teleport, function(ply, targetUID)
    if not hasStaffPerm(ply, "can_goto") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    ply:SetPos(target:GetPos() + Vector(0, 0, 10))
    staffLog("[Staff] " .. ply:Nick() .. " teleporte vers " .. target:Nick())
    billLog(ply, "tp vers " .. target:Nick())
end)

netstream.Hook(S.Net.Bring, function(ply, targetUID)
    if not hasStaffPerm(ply, "can_bring") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    target:SetPos(ply:GetPos() + Vector(0, 0, 10))
    target:Notify("Vous avez ete ramene par le staff.", NOTIFY_HINT, 3)
    staffLog("[Staff] " .. ply:Nick() .. " a ramene " .. target:Nick())
    billLog(ply, "ramene " .. target:Nick())
end)

netstream.Hook(S.Net.Freeze, function(ply, targetUID, freeze)
    if not hasStaffPerm(ply, "can_freeze") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    freeze = freeze and true or false
    if freeze then
        target:SetMoveType(MOVETYPE_NONE)
        target._staffFrozen = true
        target:Notify("Vous avez ete gele par le staff.", NOTIFY_ERROR, 5)
        staffLog("[Staff] " .. ply:Nick() .. " a gele " .. target:Nick())
        billLog(ply, "gele " .. target:Nick())
    else
        target:SetMoveType(MOVETYPE_WALK)
        target._staffFrozen = false
        target:Notify("Vous avez ete degele.", NOTIFY_HINT, 3)
        staffLog("[Staff] " .. ply:Nick() .. " a degele " .. target:Nick())
        billLog(ply, "degele " .. target:Nick())
    end
end)

netstream.Hook(S.Net.Heal, function(ply, targetUID)
    if not hasStaffPerm(ply, "verse_heal") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    target:SetHealth(target:GetMaxHealth())
    target:Notify("Vous avez ete soigne par le staff.", NOTIFY_HINT, 3)
    staffLog("[Staff] " .. ply:Nick() .. " a soigne " .. target:Nick())
    billLog(ply, "soigne " .. target:Nick())
end)

netstream.Hook(S.Net.Warn, function(ply, targetUID, reason)
    if not hasStaffPerm(ply, "verse_warn") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    reason = tostring(reason or "Comportement inapproprie.")
    local charId = getCharId(target)
    if not charId then return end

    billLog(ply, "warn " .. target:Nick() .. " | " .. reason)
    -- FIX: DB:Escape() retourne la valeur sans guillemets → les ajouter explicitement ('%s')
    local q = ("INSERT INTO verse_staff_warns (char_id, reason, staff_name, created_at) VALUES (%d, '%s', '%s', %d)"):format(
        charId, DB:Escape(reason), DB:Escape(ply:Nick()), os.time()
    )
    DB:Query(q, function()
        S._warnCache[charId] = (S._warnCache[charId] or 0) + 1
        target:Notify("Avertissement du staff : " .. reason, NOTIFY_ERROR, 8)
        staffLog("[Staff] " .. ply:Nick() .. " a averti " .. target:Nick() .. " | " .. reason)
    end, function(err)
        if VERSE.Log then VERSE.Log:Error("[Staff] warn insert: " .. tostring(err)) end
        return true
    end)
end)

netstream.Hook(S.Net.GiveMoney, function(ply, targetUID, amount)
    if not hasStaffPerm(ply, "verse_givemoney") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return end
    -- Retrait d'argent réservé aux superadmins
    if amount < 0 and not isSuperAdmin(ply) then return end

    billLog(ply, "givemoney " .. target:Nick() .. " " .. tostring(amount) .. "Y")
    if amount > 0 then
        target:AddMoney(amount, function(ok)
            if not ok then return end
            target:Notify("Le staff vous a donne " .. amount .. " Y.", NOTIFY_HINT, 4)
            staffLog("[Staff] " .. ply:Nick() .. " a donne " .. amount .. " Y a " .. target:Nick())
        end)
    else
        local take = math.abs(amount)
        target:DeductMoney(take, function(ok)
            if ok then
                target:Notify("Le staff a retire " .. take .. " Y.", NOTIFY_ERROR, 4)
                staffLog("[Staff] " .. ply:Nick() .. " a retire " .. take .. " Y a " .. target:Nick())
            else
                ply:Notify("Fonds insuffisants pour ce joueur.", NOTIFY_ERROR, 3)
            end
        end)
    end
end)

-- ─── Set Job ─────────────────────────────────────────────────────────────────

netstream.Hook(S.Net.SetJob, function(ply, targetUID, jobId)
    if not hasStaffPerm(ply, "setclass") then return end
    local target = findByUID(targetUID)
    if not IsValid(target) then return end
    jobId = tostring(jobId or ""):lower()
    if jobId == "" then return end

    if not (VERSE.Jobs and VERSE.Jobs.SetPlayerJob) then
        ply:Notify("Système de jobs indisponible.", NOTIFY_ERROR, 4)
        return
    end

    local job = VERSE.Jobs:Get(jobId)
    if not job then
        ply:Notify("Job inconnu : " .. jobId, NOTIFY_ERROR, 4)
        return
    end

    VERSE.Jobs:SetPlayerJob(target, jobId, { skipWhitelist = true })
    target:Notify("Le staff vous a attribué le job : " .. tostring(job.name or jobId) .. ".", NOTIFY_HINT, 5)
    staffLog("[Staff] " .. ply:Nick() .. " a mis " .. target:Nick() .. " en job '" .. jobId .. "'")
    billLog(ply, "setjob " .. target:Nick() .. " -> " .. tostring(job.name or jobId))
end)

-- ─── Hooks ────────────────────────────────────────────────────────────────────

VERSE.Hook.AddNS("Staff", "VERSE::Characters::Loaded", "VERSE::Staff::WarnLoad", function(ply)
    local cid = getCharId(ply)
    if cid then loadWarns(cid) end
end)

hook.Add("PlayerDisconnected", "VERSE::Staff::Cleanup", function(ply)
    if ply._staffFrozen then
        ply._staffFrozen = false
        if IsValid(ply) then ply:SetMoveType(MOVETYPE_WALK) end
    end
    if ply._staffMode then
        ply._staffMode = false
        if IsValid(ply) then
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetColor(Color(255, 255, 255, 255))
            ply:SetNWBool("VERSE_StaffMode", false)
        end
    end
end)

-- ─── Init DB ──────────────────────────────────────────────────────────────────

if DB and DB.OnReady then
    DB:OnReady(function() createWarnTable() end)
end

-- ─── Billy's Logs module init ─────────────────────────────────────────────────

if GAS and isfunction(GAS_Logging_Init) then
    GAS_Logging_Init(function()
        if not (GAS.Logging and isfunction(GAS.Logging.MODULE)) then return end
        local M = GAS.Logging:MODULE()
        M.Category = "Staff"
        M.Name     = "Actions"
        M.Colour   = Color(255, 80, 80)
        M:Setup(function() end)
        GAS.Logging:AddModule(M)
        S._GASModule = M
    end)
end
