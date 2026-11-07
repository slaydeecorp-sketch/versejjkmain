local LVL = VERSE.Leveling
local DB = VERSE.DB
local CH = VERSE.Characters
local Log = VERSE.Log
local L = VERSE.L

if not LVL or not DB then return end

LVL._cache = LVL._cache or {}

-- Constantes déclarées ICI pour être visibles dans toutes les closures du fichier.
-- (Elles étaient auparavant après le hook VERSE::Characters::Loaded, ce qui les
-- rendait nil au moment de la capture → timer inopérant → 0 EXP passif.)
local PASSIVE_EXP_AMOUNT   = 80   -- EXP gagnée par tick
local PASSIVE_EXP_INTERVAL = 600  -- secondes entre chaque tick (10 min)

local cfg = LVL.Config
local PLAYER = FindMetaTable("Player")

function LVL:CreateTables()
    local tbl = cfg.TableName
    local query
    if DB:IsMySQL() then
        query = ([[
            CREATE TABLE IF NOT EXISTS %s (
                char_id INT NOT NULL PRIMARY KEY,
                level INT NOT NULL DEFAULT 1,
                exp INT NOT NULL DEFAULT 0,
                total_exp INT NOT NULL DEFAULT 0,
                created_at INT NOT NULL,
                updated_at INT NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]):format(tbl)
    else
        query = ([[
            CREATE TABLE IF NOT EXISTS %s (
                char_id INTEGER NOT NULL PRIMARY KEY,
                level INTEGER NOT NULL DEFAULT 1,
                exp INTEGER NOT NULL DEFAULT 0,
                total_exp INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );
        ]]):format(tbl)
    end

    DB:Query(query, function()
        Log:Info("[Leveling] Table '" .. tbl .. "' ready.")
    end, function(err)
        Log:Error("[Leveling] CreateTables failed: " .. tostring(err))
        return true
    end)
end

function LVL:LoadCharacter(charId, ply, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(false) end
        return
    end

    local tbl = cfg.TableName
    DB:Query(("SELECT level, exp, total_exp FROM %s WHERE char_id=%d"):format(tbl, charId), function(result)
        local level = 1
        local exp = 0
        local totalExp = 0

        if result and result[1] then
            level = math.max(1, tonumber(result[1].level) or 1)
            exp = math.max(0, tonumber(result[1].exp) or 0)
            totalExp = math.max(0, tonumber(result[1].total_exp) or 0)
        else
            local now = os.time()
            local insertQ
            if DB:IsMySQL() then
                insertQ = ("INSERT IGNORE INTO %s (char_id, level, exp, total_exp, created_at, updated_at) VALUES (%d, 1, 0, 0, %d, %d)"):format(tbl, charId, now, now)
            else
                insertQ = ("INSERT OR IGNORE INTO %s (char_id, level, exp, total_exp, created_at, updated_at) VALUES (%d, 1, 0, 0, %d, %d)"):format(tbl, charId, now, now)
            end
            DB:Query(insertQ)
        end

        LVL._cache[charId] = { level = level, exp = exp, total_exp = totalExp }

        if IsValid(ply) then
            ply:SetNWInt(LVL.NW.Level, level)
            ply:SetNWInt(LVL.NW.EXP, exp)
            Log:Info("[Leveling] Loaded char #" .. charId .. " -> Lv." .. level .. " EXP:" .. exp .. "/" .. LVL:RequiredEXP(level))
        end

        if callback then callback(true, level, exp, totalExp) end
    end, function(err)
        Log:Error("[Leveling] LoadCharacter failed: " .. tostring(err))
        if callback then callback(false) end
        return true
    end)
end

function LVL:SaveCharacter(charId, callback)
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        if callback then callback(false) end
        return
    end

    local cached = self._cache[charId]
    if not cached then
        if callback then callback(false) end
        return
    end

    local tbl = cfg.TableName
    local now = os.time()
    local query

    if DB:IsMySQL() then
        query = ([[
            INSERT INTO %s (char_id, level, exp, total_exp, created_at, updated_at)
            VALUES (%d, %d, %d, %d, %d, %d)
            ON DUPLICATE KEY UPDATE
                level = VALUES(level),
                exp = VALUES(exp),
                total_exp = VALUES(total_exp),
                updated_at = VALUES(updated_at)
        ]]):format(tbl, charId, cached.level, cached.exp, cached.total_exp, now, now)
    else
        query = ([[
            INSERT OR REPLACE INTO %s (char_id, level, exp, total_exp, created_at, updated_at)
            VALUES (%d, %d, %d, %d,
                COALESCE((SELECT created_at FROM %s WHERE char_id=%d), %d),
                %d)
        ]]):format(tbl, charId, cached.level, cached.exp, cached.total_exp, tbl, charId, now, now)
    end

    DB:Query(query, function()
        if callback then callback(true) end
    end, function(err)
        Log:Error("[Leveling] SaveCharacter failed: " .. tostring(err))
        if callback then callback(false) end
        return true
    end)
end

function LVL:SyncToClient(ply)
    if not IsValid(ply) then return end
    local charId = CH and CH:GetSelectedCharID(ply)
    if not charId then return end
    local cached = self._cache[charId]
    if not cached then return end

    ply:SetNWInt(LVL.NW.Level, cached.level)
    ply:SetNWInt(LVL.NW.EXP, cached.exp)
end

function PLAYER:AddEXP(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local charId = CH and CH:GetSelectedCharID(self)
    if not charId then return end

    local cached = LVL._cache[charId]
    if not cached then return end

    cached.exp = cached.exp + amount
    cached.total_exp = cached.total_exp + amount

    local levelsGained = 0
    local maxLevel = cfg.MaxLevel or 100

    while cached.level < maxLevel do
        local required = LVL:RequiredEXP(cached.level)
        if cached.exp < required then break end
        cached.exp = cached.exp - required
        cached.level = cached.level + 1
        levelsGained = levelsGained + 1
    end

    if cached.level >= maxLevel then
        cached.exp = 0
    end

    self:SetNWInt(LVL.NW.Level, cached.level)
    self:SetNWInt(LVL.NW.EXP, cached.exp)

    if levelsGained > 0 then
        local points = (cfg.PointsPerLevel or 1) * levelsGained

        -- Mémoriser les HP actuels AVANT le RecalcStats déclenché par AddSkillTreePoints
        local _self      = self
        local savedHp    = self:Health()
        local savedMaxHp = self:GetMaxHealth()

        if self.AddSkillTreePoints then
            self:AddSkillTreePoints(points)
        end

        -- Re-appliquer les stats de classe avec un délai suffisant pour passer
        -- après tous les RecalcStats / ReapplyStats déclenchés en cascade.
        -- Si les HP ont été abaissés à 100 par un RecalcStats sans job,
        -- on restaure au max de classe ; sinon on préserve les HP actuels.
        timer.Simple(0.5, function()
            if not IsValid(_self) then return end
            if VERSE.Classes and VERSE.Classes.ReapplyStats then
                VERSE.Classes.ReapplyStats(_self)
            else
                -- Fallback : si ReapplyStats n'est pas disponible, restaurer manuellement
                local curMax = _self:GetMaxHealth()
                if curMax <= 100 and savedMaxHp > 100 then
                    _self:SetMaxHealth(savedMaxHp)
                    _self:SetHealth(math.min(savedHp, savedMaxHp))
                end
            end
        end)

        netstream.Start(self, LVL.Net.LevelUp, {
            level = cached.level,
            points = points,
        })

        Log:Info("[Leveling] " .. self:Nick() .. " leveled up to " .. cached.level .. " (+" .. points .. " points)")
    end

    LVL:SaveCharacter(charId)
end

function PLAYER:SetCharLevel(level)
    level = math.Clamp(math.floor(tonumber(level) or 1), 1, cfg.MaxLevel or 100)
    local charId = CH and CH:GetSelectedCharID(self)
    if not charId then return end

    local cached = LVL._cache[charId]
    if not cached then return end

    cached.level = level
    cached.exp = 0

    self:SetNWInt(LVL.NW.Level, cached.level)
    self:SetNWInt(LVL.NW.EXP, cached.exp)
    LVL:SaveCharacter(charId)
end

function PLAYER:SetCharEXP(exp)
    exp = math.max(0, math.floor(tonumber(exp) or 0))
    local charId = CH and CH:GetSelectedCharID(self)
    if not charId then return end

    local cached = LVL._cache[charId]
    if not cached then return end

    cached.exp = exp
    self:SetNWInt(LVL.NW.EXP, cached.exp)
    LVL:SaveCharacter(charId)
end

VERSE.Hook.AddNS("Leveling", "VERSE::Characters::Loaded", "VERSE::Leveling::CharLoaded", function(ply, char)
    if not IsValid(ply) or not char then return end
    local charId = tonumber(char.id)
    if not charId then return end
    LVL:LoadCharacter(charId, ply)

    -- Timer passif individuel : démarre au chargement du personnage,
    -- décalé naturellement selon l'heure de connexion de chaque joueur.
    local timerName = "VERSE::Leveling::PassiveEXP::" .. ply:SteamID()
    timer.Remove(timerName)
    timer.Create(timerName, PASSIVE_EXP_INTERVAL, 0, function()
        if not IsValid(ply) then timer.Remove(timerName) return end
        local cid = CH and CH:GetSelectedCharID(ply)
        if not cid or not LVL._cache[cid] then return end
        ply:AddEXP(PASSIVE_EXP_AMOUNT)
    end)
end)

DB:OnReady(function()
    LVL:CreateTables()
end)

VERSE.Hook.AddNS("Leveling", "PlayerDisconnected", "VERSE::Leveling::Save", function(ply)
    if not IsValid(ply) then return end
    timer.Remove("VERSE::Leveling::PassiveEXP::" .. ply:SteamID())
    local charId = CH and CH:GetSelectedCharID(ply)
    if not charId then return end
    LVL:SaveCharacter(charId)
end)

VERSE.Hook.AddNS("Leveling", "ShutDown", "VERSE::Leveling::ShutdownSave", function()
    for charId, _ in pairs(LVL._cache) do
        LVL:SaveCharacter(charId)
    end
end)

-- (PASSIVE_EXP_AMOUNT et PASSIVE_EXP_INTERVAL sont déclarées en haut du fichier)

local function findPlayer(search)
    search = string.lower(string.Trim(tostring(search or "")))
    if search == "" then return nil end
    for _, ply in ipairs(player.GetAll()) do
        if string.lower(ply:Nick()):find(search, 1, true) or ply:SteamID64() == search then
            return ply
        end
    end
    return nil
end

VERSE.Commands.Add("verse_exp", function(ply, args)
    if not IsValid(ply) then return end
    if not ply:IsDeveloper() then
        if isfunction(ply.Notify) then ply:Notify(L("dev.no_permission", { action = "verse_exp" }), NOTIFY_ERROR, 3) end
        return
    end

    local action = args[1]
    local targetName = args[2]
    local amount = tonumber(args[3])

    if not action or not targetName then
        if isfunction(ply.Notify) then ply:Notify("Usage: verse_exp <give/set/setlevel> <player> <amount>", NOTIFY_HINT, 5) end
        return
    end

    local target = findPlayer(targetName)
    if not IsValid(target) then
        if isfunction(ply.Notify) then ply:Notify("Joueur introuvable: " .. tostring(targetName), NOTIFY_ERROR, 3) end
        return
    end

    if not amount or amount < 0 then
        if isfunction(ply.Notify) then ply:Notify("Montant invalide.", NOTIFY_ERROR, 3) end
        return
    end

    if action == "give" then
        target:AddEXP(amount)
        if isfunction(ply.Notify) then ply:Notify("+" .. amount .. " EXP -> " .. target:Nick(), NOTIFY_HINT, 3) end
    elseif action == "set" then
        target:SetCharEXP(amount)
        if isfunction(ply.Notify) then ply:Notify("EXP set to " .. amount .. " -> " .. target:Nick(), NOTIFY_HINT, 3) end
    elseif action == "setlevel" then
        target:SetCharLevel(amount)
        if isfunction(ply.Notify) then ply:Notify("Level set to " .. amount .. " -> " .. target:Nick(), NOTIFY_HINT, 3) end
    else
        if isfunction(ply.Notify) then ply:Notify("Actions: give, set, setlevel", NOTIFY_HINT, 3) end
    end
end)
