local CH = VERSE.Characters
local DB = VERSE.DB
CH._cache        = CH._cache        or {}
CH._knownCache   = CH._knownCache   or {}
CH._introPending = CH._introPending or {}
CH._busy         = CH._busy         or {}
local function esc(v)
    return DB:Escape(v)
end

local function nowSQL()
    return os.time()
end

local function ensureSet(map, key)
    if not istable(map[key]) then map[key] = {} end
    return map[key]
end

local function introKey(aId, bId)
    return tostring(aId) .. ":" .. tostring(bId)
end

local function cleanupPending()
    local t = CurTime()
    for k, v in pairs(CH._introPending) do
        if not v or (v.expires and v.expires <= t) then CH._introPending[k] = nil end
    end
end

local SKIN_PRESET_FIELDS = {
    {
        name = "skin_tone",
        kind = "number"
    },
    {
        name = "skin_color",
        kind = "string"
    },
    {
        name = "body_style",
        kind = "number"
    },
    {
        name = "body_marks",
        kind = "body_marks"
    },
    {
        name = "head_type",
        kind = "number"
    },
    {
        name = "head_style",
        kind = "number"
    },
    {
        name = "hair_style",
        kind = "number"
    },
    {
        name = "hair_color",
        kind = "string"
    },
    {
        name = "hair_tip_color",
        kind = "string"
    },
    {
        name = "hair_model",
        kind = "number"
    },
    {
        name = "eyebrow_style",
        kind = "number"
    },
    {
        name = "eyebrow_color",
        kind = "string"
    },
    {
        name = "eyelash_color",
        kind = "string"
    },
    {
        name = "iris_style",
        kind = "number"
    },
    {
        name = "iris_size",
        kind = "number"
    },
    {
        name = "eye_color",
        kind = "string"
    },
    {
        name = "flex",
        kind = "flex"
    },
    {
        name = "spirit_accessory",
        kind = "number"
    },
    {
        name = "spirit_accessory_data",
        kind = "spirit_accessory_data"
    },
}

CH.DBColumns = CH.DBColumns or {"steamid64", "slot", "firstname", "lastname", "nickname", "description", "job_id", "faction", "model", "gender", "age", "height", "presets_skin", "created_at", "updated_at",}
local function ensureDBColumn(name)
    for i = 1, #CH.DBColumns do
        if CH.DBColumns[i] == name then return end
    end

    CH.DBColumns[#CH.DBColumns + 1] = name
end

local function removeDBColumn(name)
    for i = #CH.DBColumns, 1, -1 do
        if CH.DBColumns[i] == name then table.remove(CH.DBColumns, i) end
    end
end

ensureDBColumn("height")
for i = 1, #SKIN_PRESET_FIELDS do
    removeDBColumn(SKIN_PRESET_FIELDS[i].name)
end

ensureDBColumn("presets_skin")
local function sqlValue(v)
    if v == nil then return "NULL" end
    local t = type(v)
    if t == "boolean" then return v and "1" or "0" end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "NULL" end
        return tostring(v)
    end
    return esc(tostring(v))
end

local function buildInsert(tableName, columns, dataMap)
    local colParts, valParts = {}, {}
    for i = 1, #columns do
        local col = columns[i]
        colParts[#colParts + 1] = col
        valParts[#valParts + 1] = sqlValue(dataMap[col])
    end
    return ("INSERT INTO %s (%s) VALUES (%s)"):format(tableName, table.concat(colParts, ","), table.concat(valParts, ","))
end

function CH:GetSteamID64(ply)
    return (IsValid(ply) and ply.SteamID64 and ply:SteamID64()) or "0"
end

function CH:GetSelected(ply)
    return IsValid(ply) and ply._Char or nil
end

function CH:GetSelectedCharID(ply)
    local ch = self:GetSelected(ply)
    return (istable(ch) and tonumber(ch.id)) or nil
end

function CH:SetSelected(ply, char)
    if not IsValid(ply) then return end
    ply._Char = char
end

local function cleanText(s)
    s = tostring(s or "")
    s = string.Trim(s)
    s = s:gsub("[%c]", "")
    return s
end

local function clampInt(v, minv, maxv)
    v = tonumber(v)
    if not v then return nil end
    v = math.floor(v)
    if minv ~= nil and v < minv then v = minv end
    if maxv ~= nil and v > maxv then v = maxv end
    return v
end

local function normalizeColorString(v)
    local r, g, b, a
    if IsColor and IsColor(v) then
        r, g, b, a = v.r, v.g, v.b, v.a
    elseif istable(v) and v.r and v.g and v.b then
        r, g, b, a = v.r, v.g, v.b, v.a
    elseif isstring(v) and v ~= "" then
        local mR, mG, mB, mA = string.match(v, "^(%d+),(%d+),(%d+),?(%d*)$")
        r, g, b, a = mR, mG, mB, mA
    end

    r = clampInt(r, 0, 255)
    g = clampInt(g, 0, 255)
    b = clampInt(b, 0, 255)
    a = clampInt(a, 0, 255)
    if not r or not g or not b then return nil end
    if a == nil then a = 255 end
    return ("%d,%d,%d,%d"):format(r, g, b, a)
end

local function encodeSkinPreset(faction, source)
    source = istable(source) and source or {}
    local payload = {}
    for i = 1, #SKIN_PRESET_FIELDS do
        local field = SKIN_PRESET_FIELDS[i]
        local value = source[field.name]
        if field.kind == "number" then
            value = value ~= nil and tonumber(value) or nil
        elseif field.kind == "string" then
            value = value ~= nil and tostring(value) or nil
        elseif field.kind == "body_marks" and CH.NormalizeBodyMarksData then
            value = CH:NormalizeBodyMarksData(faction, value)
            if not istable(value) or next(value) == nil then value = nil end
        elseif field.kind == "flex" and CH.NormalizeFlexTable then
            value = CH:NormalizeFlexTable(value)
            if not istable(value) or next(value) == nil then value = nil end
        elseif field.kind == "spirit_accessory_data" and CH.NormalizeSpiritAccessoryTransform then
            value = CH:NormalizeSpiritAccessoryTransform(faction, source.spirit_accessory, value)
            if CH.NormalizeSpiritAccessory and CH:NormalizeSpiritAccessory(faction, source.spirit_accessory) <= 0 then value = nil end
        end

        if value ~= nil then payload[field.name] = value end
    end

    if next(payload) == nil then return nil end
    return util.TableToJSON(payload, false)
end

local function decodeSkinPreset(raw)
    if raw == nil then return nil end
    raw = tostring(raw)
    if raw == "" then return nil end
    local decoded = util.JSONToTable(raw)
    if not istable(decoded) then return nil end
    return decoded
end

local function applySkinPreset(row)
    local preset = decodeSkinPreset(row.presets_skin)
    for i = 1, #SKIN_PRESET_FIELDS do
        local field = SKIN_PRESET_FIELDS[i]
        local value = (preset and preset[field.name] ~= nil) and preset[field.name] or row[field.name]
        if field.kind == "number" then
            row[field.name] = value ~= nil and tonumber(value) or nil
        elseif field.kind == "string" then
            row[field.name] = value ~= nil and tostring(value) or nil
        elseif field.kind == "body_marks" then
            row[field.name] = CH.NormalizeBodyMarksData and CH:NormalizeBodyMarksData(row.faction, value) or {}
        elseif field.kind == "flex" then
            row[field.name] = CH.NormalizeFlexTable and CH:NormalizeFlexTable(value) or {}
        elseif field.kind == "spirit_accessory_data" then
            row[field.name] = CH.NormalizeSpiritAccessoryTransform and CH:NormalizeSpiritAccessoryTransform(row.faction, row.spirit_accessory, value) or nil
        end
    end
end

function CH:ValidateCreateData(ply, data)
    data = istable(data) and data or {}
    local c = self:GetConfig()
    local slots = self:GetSlots(ply)
    local slot = tonumber(data.slot)
    if not slot or slot < 1 or slot > slots then return false, "bad_slot" end
    local descMax = self:ConfigInt("DescMax", 512, 0, 8192)
    local descMin = self:ConfigInt("DescMin", 0, 0, descMax)
    local descReq = self:ConfigBool("DescRequired", false)
    local desc = ""
    if self:ConfigBool("EnableDescription", true) then
        desc = cleanText(data.description)
        if descReq and desc == "" then return false, "bad_description_empty" end
        if descMin > 0 and desc ~= "" and #desc < descMin then return false, "bad_description_short" end
        if #desc > descMax then return false, "bad_description_long" end
    end

    local nameMin = self:ConfigInt("NameMin", 2, 1, 64)
    local nameMax = self:ConfigInt("NameMax", 18, nameMin, 64)
    local nickname, firstname, lastname
    if self:ConfigBool("NicknameMode", true) then
        nickname = cleanText(data.nickname)
        if nickname == "" then return false, "bad_nickname_empty" end
        if #nickname < nameMin then return false, "bad_nickname_short" end
        if #nickname > nameMax then return false, "bad_nickname_long" end
        firstname, lastname = nickname, ""
    else
        firstname = cleanText(data.firstname)
        lastname = cleanText(data.lastname)
        if firstname == "" then return false, "bad_firstname_empty" end
        if #firstname < nameMin then return false, "bad_firstname_short" end
        if #firstname > nameMax then return false, "bad_firstname_long" end
        if lastname == "" then return false, "bad_lastname_empty" end
        if #lastname < nameMin then return false, "bad_lastname_short" end
        if #lastname > nameMax then return false, "bad_lastname_long" end
    end

    local jobId = tostring(data.job_id or c.DefaultJob or "citizen")
    if not (VERSE.Jobs.Get == VERSE.Jobs.Get and VERSE.Jobs:Get(jobId)) then return false, "bad_job" end
    local faction
    if self:FactionsEnabled() then
        local fId = tostring(data.faction or "")
        local f = self:GetConfig("Factions", fId)
        if fId == "" or not istable(f) then return false, "bad_faction" end
        if istable(f.allowedJobs) and not f.allowedJobs[jobId] then return false, "job_not_allowed" end
        faction = fId
    else
        faction = nil
    end

    local model
    if isstring(data.model) and data.model ~= "" then
        model = data.model
        if self:ConfigBool("ValidateModel", true) and not util.IsValidModel(model) then return false, "bad_model" end
    end

    local gender
    if self:GenderEnabled() then
        local gv = self:GetGenderValues()
        gender = tostring(data.gender or c.DefaultGender or "male")
        if not gv[gender] then gender = gv.male and "male" or (gv.female and "female" or nil) end
        if not gender or not gv[gender] then return false, "bad_gender" end
    else
        gender = nil
    end

    local age
    if self:ConfigBool("EnableAge", false) then
        local minA = self:ConfigInt("AgeMin", 0, 0, 200)
        local maxA = self:ConfigInt("AgeMax", 120, minA, 200)
        local defA = self:ConfigInt("DefaultAge", 18, minA, maxA)
        age = clampInt(data.age or defA, minA, maxA)
        if not age or age < minA or age > maxA then return false, "bad_age" end
    end

    local minH = self:ConfigInt("HeightMin", 140, 50, 400)
    local maxH = self:ConfigInt("HeightMax", 220, minH, 400)
    local defH = self:ConfigInt("DefaultHeight", 165, minH, maxH)
    local height = clampInt(data.height, minH, maxH)
    if height == nil then height = defH end
    if not height or height < minH or height > maxH then return false, "bad_height" end
    local paletteCount = #self:ConfigTable("SkinColorPalette", {})
    if paletteCount <= 0 then paletteCount = 1 end
    local skinTone = clampInt(data.skin_tone, 1, paletteCount)
    if skinTone == nil then skinTone = 1 end
    local skinColor = normalizeColorString(data.skin_color)
    if faction ~= "spirit" then skinColor = nil end
    local bodyStyle = clampInt(data.body_style, 0, 255)
    if bodyStyle == nil then bodyStyle = 0 end
    local bodyMarks = self.NormalizeBodyMarksData and self:NormalizeBodyMarksData(faction, data.body_marks) or {}
    local headType = clampInt(data.head_type, 1, 64) or 1
    local headStyle = clampInt(data.head_style, 0, 255)
    if headStyle == nil then headStyle = 0 end
    local headModel = ""
    if faction and self.GetFactionGenderData and self.GetPreferredAppearanceModel then
        local factionCfg = self:GetConfig("Factions", faction)
        local gdata = istable(factionCfg) and self:GetFactionGenderData(factionCfg, gender) or nil
        headModel = (gdata and self:GetPreferredAppearanceModel(gdata.head, headType)) or (gdata and self:GetPreferredAppearanceModel(gdata.head, 1)) or ""
    end

    if self.NormalizeBodygroupValue then headStyle = self:NormalizeBodygroupValue(headModel, 0, headStyle, 255) end
    local eyebrowStyle = clampInt(data.eyebrow_style, 1, self.GetEyebrowStyleCount and self:GetEyebrowStyleCount() or 1)
    if eyebrowStyle == nil then eyebrowStyle = 1 end
    local irisStyle = clampInt(data.iris_style, 1, self.GetEyeStyleCount and self:GetEyeStyleCount() or 1)
    if irisStyle == nil then irisStyle = 1 end
    local defaultIrisSize = self.GetDefaultIrisSize and self:GetDefaultIrisSize() or 100
    local irisSize = tonumber(data.iris_size)
    if self.NormalizeIrisSize then
        irisSize = self:NormalizeIrisSize(irisSize or defaultIrisSize)
    else
        irisSize = math.Clamp(math.floor(irisSize or defaultIrisSize), 40, 200)
    end

    local eyebrowColor = normalizeColorString(data.eyebrow_color)
    local eyelashColor = normalizeColorString(data.eyelash_color)
    local eyeColor = normalizeColorString(data.eye_color)
    local flexTable = self.NormalizeFlexTable and self:NormalizeFlexTable(data.flex) or {}
    local hairStyle = clampInt(data.hair_style, 0, 255)
    if hairStyle == nil then hairStyle = 0 end
    local hairModel = math.Clamp(math.floor(tonumber(data.hair_model) or 0), 0, #(CH.HairModels or {}))
    local hairColor = normalizeColorString(data.hair_color)
    -- Dégradé de cheveux (optionnel) : couleur des pointes. Chaîne vide = pas de dégradé.
    local hairTipColor = normalizeColorString(data.hair_tip_color) or ""
    local spiritAccessory = (self.NormalizeSpiritAccessory and self:NormalizeSpiritAccessory(faction, data.spirit_accessory)) or 0
    local spiritAccessoryData = (self.NormalizeSpiritAccessoryTransform and self:NormalizeSpiritAccessoryTransform(faction, spiritAccessory, data.spirit_accessory_data)) or nil
    return true, {
        slot = slot,
        nickname = nickname,
        firstname = firstname,
        lastname = lastname,
        description = desc,
        job_id = jobId,
        faction = faction,
        model = model,
        gender = gender,
        age = age,
        height = height,
        skin_tone = skinTone,
        skin_color = skinColor,
        body_style = bodyStyle,
        body_marks = bodyMarks,
        head_type = headType,
        head_style = headStyle,
        hair_style = hairStyle,
        hair_model = hairModel,
        hair_color = hairColor,
        hair_tip_color = hairTipColor,
        eyebrow_style = eyebrowStyle,
        eyebrow_color = eyebrowColor,
        eyelash_color = eyelashColor,
        iris_style = irisStyle,
        iris_size = irisSize,
        eye_color = eyeColor,
        flex = flexTable,
        spirit_accessory = spiritAccessory,
        spirit_accessory_data = spiritAccessoryData,
    }
end

function CH:CreateTables()
    local isMy = DB:IsMySQL()
    local q = [[
        CREATE TABLE IF NOT EXISTS verse_characters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            steamid64 VARCHAR(32) NOT NULL,
            slot INTEGER NOT NULL,
            firstname VARCHAR(32) NOT NULL,
            lastname VARCHAR(32) NOT NULL,
            nickname VARCHAR(32),
            description TEXT NOT NULL,
            job_id VARCHAR(64) NOT NULL,
            faction VARCHAR(64),
            model VARCHAR(256),
            gender VARCHAR(16),
            age INTEGER,
            height INTEGER,
            presets_skin TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
    ]]
    if isMy then q = [[
            CREATE TABLE IF NOT EXISTS verse_characters (
                id INT NOT NULL AUTO_INCREMENT,
                steamid64 VARCHAR(32) NOT NULL,
                slot INT NOT NULL,
                firstname VARCHAR(32) NOT NULL,
                lastname VARCHAR(32) NOT NULL,
                nickname VARCHAR(32) NULL,
                description TEXT NOT NULL,
                job_id VARCHAR(64) NOT NULL,
                faction VARCHAR(64) NULL,
                model VARCHAR(256) NULL,
                gender VARCHAR(16) NULL,
                age INT NULL,
                height INT NULL,
                presets_skin TEXT NULL,
                created_at INT NOT NULL,
                updated_at INT NOT NULL,
                PRIMARY KEY (id),
                UNIQUE KEY uq_owner_slot (steamid64, slot)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]] end
    local qKnown = [[
        CREATE TABLE IF NOT EXISTS verse_character_known (
            owner_char_id INTEGER NOT NULL,
            known_char_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL
        )
    ]]
    if isMy then qKnown = [[
            CREATE TABLE IF NOT EXISTS verse_character_known (
                owner_char_id INT NOT NULL,
                known_char_id INT NOT NULL,
                created_at INT NOT NULL,
                PRIMARY KEY (owner_char_id, known_char_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]] end
    local function logSchemaError(tag, err)
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error(("[Characters] %s: %s"):format(tostring(tag), tostring(err))) end
    end

    local function isDuplicateColumnError(err, column)
        err = string.lower(tostring(err or ""))
        column = string.lower(tostring(column or ""))
        return string.find(err, "duplicate column", 1, true) ~= nil and string.find(err, column, 1, true) ~= nil
    end

    local function ensureCharacterColumn(name, sqlType)
        local alter = ("ALTER TABLE verse_characters ADD COLUMN %s %s"):format(name, sqlType)
        DB:Query(alter, function() end, function(err)
            if isDuplicateColumnError(err, name) then return true end
            logSchemaError("schema migrate " .. tostring(name), err)
            return true
        end)
    end

    DB:Query(q, function()
        ensureCharacterColumn("height", isMy and "INT NULL" or "INTEGER")
        ensureCharacterColumn("presets_skin", "TEXT")
        ensureCharacterColumn("eyelash_color", isMy and "VARCHAR(24) NOT NULL DEFAULT ''" or "TEXT NOT NULL DEFAULT ''")
    end, function(err)
        logSchemaError("create verse_characters", err)
        return true
    end)

    DB:Query(qKnown, function() end, function(err)
        logSchemaError("create verse_character_known", err)
        return true
    end)

    if not isMy then
        DB:Query("CREATE UNIQUE INDEX IF NOT EXISTS idx_verse_char_owner_slot ON verse_characters(steamid64, slot)")
        DB:Query("CREATE UNIQUE INDEX IF NOT EXISTS idx_known_pair ON verse_character_known(owner_char_id, known_char_id)")
        DB:Query("CREATE INDEX IF NOT EXISTS idx_known_owner ON verse_character_known(owner_char_id)")
        DB:Query("CREATE INDEX IF NOT EXISTS idx_known_known ON verse_character_known(known_char_id)")
    end
end

local function toCharRow(row)
    if not row then return nil end
    row.id = tonumber(row.id)
    row.slot = row.slot ~= nil and tonumber(row.slot) or nil
    row.nickname = row.nickname ~= nil and tostring(row.nickname) or nil
    row.age = row.age ~= nil and tonumber(row.age) or nil
    row.height = row.height ~= nil and tonumber(row.height) or nil
    row.presets_skin = row.presets_skin ~= nil and tostring(row.presets_skin) or nil
    applySkinPreset(row)
    row.spirit_accessory = row.spirit_accessory ~= nil and tonumber(row.spirit_accessory) or 0
    if CH.NormalizeSpiritAccessoryTransform then row.spirit_accessory_data = CH:NormalizeSpiritAccessoryTransform(row.faction, row.spirit_accessory, row.spirit_accessory_data) end
    row.created_at = tonumber(row.created_at) or 0
    row.updated_at = tonumber(row.updated_at) or 0
    return row
end

function CH:LoadAllCharacters(ply)
    if not IsValid(ply) then return VERSE.Promise.Resolve({}) end
    local sid = self:GetSteamID64(ply)
    local q = ("SELECT * FROM verse_characters WHERE steamid64=%s ORDER BY slot ASC"):format(esc(sid))
    return DB:Query(q):Next(function(res)
        local rows = res.rows or {}
        local map = {}
        for _, r in ipairs(rows) do
            local row = toCharRow(r)
            if row and row.slot then map[row.slot] = row end
        end

        CH._cache[sid] = map
        return map
    end)
end

function CH:LoadCharacterByOwnerSlot(ownerSteamID64, slot, cb)
    ownerSteamID64 = tostring(ownerSteamID64 or ""):Trim()
    slot = tonumber(slot)
    if ownerSteamID64 == "" or ownerSteamID64 == "0" then
        if cb then cb(false, "bad_target") end
        return
    end

    if not slot or slot < 1 or slot > 63 then
        if cb then cb(false, "bad_slot") end
        return
    end

    local q = ("SELECT * FROM verse_characters WHERE steamid64=%s AND slot=%d LIMIT 1"):format(esc(ownerSteamID64), slot)
    DB:Query(q):Next(function(res)
        local rows = res.rows or {}
        local char = toCharRow(rows[1])
        if not char then
            if cb then cb(false, "no_character") end
            return
        end

        if cb then cb(true, char) end
    end):Catch(function(err)
        VERSE.Log:Error("[Characters] LoadCharacterByOwnerSlot DB error: " .. tostring(err))
        if cb then cb(false, "db_error") end
    end)
end

function CH:SendList(ply)
    if not IsValid(ply) then return end
    local sid = self:GetSteamID64(ply)
    local map = CH._cache[sid] or {}
    local slots = self:GetSlots(ply)
    local out = {}
    for s = 1, slots do
        local ch = map[s]
        if ch then
            -- Récupère le modèle de la tenue équipée depuis le cache inventaire
            local equippedModel = nil
            local INV = VERSE and VERSE.Inventory
            if INV and INV._cache and INV.EquipSlotNames then
                local invCache = INV._cache[tonumber(ch.id)]
                if istable(invCache) then
                    for slotId, _ in pairs(INV.EquipSlotNames) do
                        local itemData = invCache[slotId]
                        if itemData then
                            local def = INV:GetItemDef(itemData.item_id)
                            if def and isstring(def.equip_model) and def.equip_model ~= "" then
                                equippedModel = def.equip_model
                                break
                            end
                        end
                    end
                end
            end

            out[s] = {
                id = ch.id,
                slot = ch.slot,
                firstname = ch.firstname,
                lastname = ch.lastname,
                nickname = ch.nickname,
                description = ch.description,
                job_id = ch.job_id,
                faction = ch.faction,
                model = ch.model,
                equipped_model = equippedModel,
                gender = ch.gender,
                age = ch.age,
                height = ch.height,
                skin_tone = ch.skin_tone,
                skin_color = ch.skin_color,
                body_style = ch.body_style,
                body_marks = ch.body_marks,
                head_type = ch.head_type,
                head_style = ch.head_style,
                hair_style = ch.hair_style,
                hair_color = ch.hair_color,
                hair_tip_color = ch.hair_tip_color,
                eyebrow_style = ch.eyebrow_style,
                eyebrow_color = ch.eyebrow_color,
                eyelash_color = ch.eyelash_color,
                iris_style = ch.iris_style,
                iris_size = ch.iris_size,
                eye_color = ch.eye_color,
                flex = ch.flex,
                spirit_accessory = ch.spirit_accessory,
                spirit_accessory_data = ch.spirit_accessory_data,
                level = (VERSE.Leveling and VERSE.Leveling._cache and VERSE.Leveling._cache[ch.id] and VERSE.Leveling._cache[ch.id].level) or 1,
            }
        end
    end

    netstream.Start(ply, CH.Net.List, slots, out)
end

function CH:SendAdminList(ply, cb)
    if not IsValid(ply) then
        if cb then cb(false, "bad_player") end
        return
    end

    if not self:CanAccessAdminCharacters(ply) then
        if cb then cb(false, "no_access") end
        return
    end

    local q = "SELECT id, steamid64, slot, firstname, lastname, nickname, job_id, faction, gender, created_at, updated_at FROM verse_characters ORDER BY steamid64 ASC, slot ASC"
    DB:Query(q):Next(function(res)
        local out = {}
        for _, r in ipairs(res.rows or {}) do
            local row = toCharRow(r)
            if row then
                out[#out + 1] = {
                    id = tonumber(row.id) or 0,
                    steamid64 = tostring(r.steamid64 or "0"),
                    slot = tonumber(row.slot) or 0,
                    firstname = tostring(r.firstname or ""),
                    lastname = tostring(r.lastname or ""),
                    nickname = row.nickname,
                    job_id = tostring(r.job_id or ""),
                    faction = tostring(r.faction or ""),
                    gender = tostring(r.gender or ""),
                    created_at = tonumber(row.created_at) or 0,
                    updated_at = tonumber(row.updated_at) or 0,
                }
            end
        end

        netstream.Start(ply, CH.Net.AdminList, out)
        if cb then cb(true, out) end
    end):Catch(function(err)
        VERSE.Log:Error("[Characters] Admin list DB error: " .. tostring(err))
        if cb then cb(false, "db_error") end
    end)
end

function CH:LoadKnowns(charId)
    charId = tonumber(charId)
    if not charId then return VERSE.Promise.Resolve({}) end
    if not self:AcquaintancesEnabled() then return VERSE.Promise.Resolve(nil) end
    local q = ("SELECT known_char_id FROM verse_character_known WHERE owner_char_id=%d"):format(charId)
    return DB:Query(q):Next(function(res)
        local rows = res.rows or {}
        local set = {}
        for _, r in ipairs(rows) do
            local kid = tonumber(r.known_char_id)
            if kid then set[kid] = true end
        end

        CH._knownCache[charId] = set
        return set
    end)
end

function CH:KnowsChar(ownerCharId, targetCharId)
    if not self:AcquaintancesEnabled() then return true end
    ownerCharId = tonumber(ownerCharId)
    targetCharId = tonumber(targetCharId)
    if not ownerCharId or not targetCharId then return false end
    if ownerCharId == targetCharId then return true end
    local set = CH._knownCache[ownerCharId]
    return (istable(set) and set[targetCharId] == true) or false
end

local function insertKnownPair(ownerId, knownId)
    ownerId = tonumber(ownerId)
    knownId = tonumber(knownId)
    if not ownerId or not knownId or ownerId == knownId then return end
    local t = nowSQL()
    if DB:IsMySQL() then
        DB:Query(("INSERT IGNORE INTO verse_character_known (owner_char_id, known_char_id, created_at) VALUES (%d, %d, %d)"):format(ownerId, knownId, t))
    else
        DB:Query(("INSERT OR IGNORE INTO verse_character_known (owner_char_id, known_char_id, created_at) VALUES (%d, %d, %d)"):format(ownerId, knownId, t))
    end

    local set = ensureSet(CH._knownCache, ownerId)
    set[knownId] = true
end

local function applyKnownOneWay(ownerId, knownId, ownerPly, knownName)
    insertKnownPair(ownerId, knownId)
    if IsValid(ownerPly) then netstream.Start(ownerPly, CH.Net.KnownUpdate, 1, knownId, knownName or "") end
end

local function applyKnownTwoWay(aId, bId, aPly, bPly, aName, bName)
    insertKnownPair(aId, bId)
    insertKnownPair(bId, aId)
    if IsValid(aPly) then netstream.Start(aPly, CH.Net.KnownUpdate, 1, bId, bName or "") end
    if IsValid(bPly) then netstream.Start(bPly, CH.Net.KnownUpdate, 1, aId, aName or "") end
end

local function broadcastForgetChar(charId)
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then netstream.Start(p, CH.Net.KnownUpdate, 2, charId) end
    end
end

local function setEntityBodygroup(ent, groupId, value)
    if not IsValid(ent) or not ent.GetNumBodyGroups or not ent.GetBodygroupCount then return end
    groupId = tonumber(groupId) or 0
    if ent:GetNumBodyGroups() <= groupId then return end
    local count = tonumber(ent:GetBodygroupCount(groupId)) or 0
    local maxValue = math.max(0, count - 1)
    ent:SetBodygroup(groupId, math.Clamp(math.floor(tonumber(value) or 0), 0, maxValue))
end

local function normalizeSubMaterialPath(path)
    path = string.lower(string.Trim(tostring(path or "")))
    if path == "" then return "" end
    path = string.gsub(path, "\\", "/")
    if string.sub(path, 1, 1) == "!" then path = string.sub(path, 2) end
    return path
end

local function clearLegacyBodyMarkSubMaterials(ent)
    if not IsValid(ent) or not ent.SetSubMaterial then return end
    for slot = 0, 63 do
        local subMat = (ent.GetSubMaterial and ent:GetSubMaterial(slot)) or ""
        local normalized = normalizeSubMaterialPath(subMat)
        if normalized ~= "" then
            local isLegacyTattoo = string.find(normalized, "verse/character/tattoos/", 1, true) ~= nil or string.find(normalized, "verse__char__body_mark_layer__", 1, true) ~= nil
            if isLegacyTattoo then ent:SetSubMaterial(slot, "") end
        end
    end
end

function CH:ClearPlayerAppearance(ply)
    if not IsValid(ply) then return end
    if ply.SetModelScale then ply:SetModelScale(1, 0) end
    clearLegacyBodyMarkSubMaterials(ply)
    if self.ClearAllConfiguredBodyMarkSlots then self:ClearAllConfiguredBodyMarkSlots(ply) end
    local nw = self.AppearanceNW or {}
    if nw.Faction then ply:SetPublicString(nw.Faction, "") end
    if nw.HeadModel then ply:SetPublicString(nw.HeadModel, "") end
    if nw.Height then ply:SetPublicInt(nw.Height, self:ConfigInt("DefaultHeight", 165, 50, 400)) end
    if nw.SkinTone then ply:SetPublicInt(nw.SkinTone, 1) end
    if nw.SkinColor then ply:SetPublicString(nw.SkinColor, "") end
    if nw.BodyStyle then ply:SetPublicInt(nw.BodyStyle, 0) end
    if nw.BodyMarks then ply:SetPublicString(nw.BodyMarks, "") end
    if nw.SpiritAccessory then ply:SetPublicInt(nw.SpiritAccessory, 0) end
    if nw.SpiritAccessoryX then ply:SetPublicInt(nw.SpiritAccessoryX, 0) end
    if nw.SpiritAccessoryY then ply:SetPublicInt(nw.SpiritAccessoryY, 0) end
    if nw.SpiritAccessoryZ then ply:SetPublicInt(nw.SpiritAccessoryZ, 0) end
    if nw.SpiritAccessorySize then ply:SetPublicInt(nw.SpiritAccessorySize, 24) end
    if nw.SpiritAccessorySizeX then ply:SetPublicInt(nw.SpiritAccessorySizeX, 24) end
    if nw.SpiritAccessorySizeY then ply:SetPublicInt(nw.SpiritAccessorySizeY, 24) end
    if nw.SpiritAccessoryRotate then ply:SetPublicInt(nw.SpiritAccessoryRotate, 0) end
    if nw.HeadStyle then ply:SetPublicInt(nw.HeadStyle, 0) end
    if nw.HairStyle then ply:SetPublicInt(nw.HairStyle, 0) end
    if nw.HairModel then ply:SetPublicInt(nw.HairModel, 0) end
    if nw.HairColor then ply:SetPublicString(nw.HairColor, "") end
    if nw.HairTipColor then ply:SetPublicString(nw.HairTipColor, "") end
    if nw.EyebrowStyle then ply:SetPublicInt(nw.EyebrowStyle, 1) end
    if nw.EyebrowColor then ply:SetPublicString(nw.EyebrowColor, "") end
    if nw.EyelashColor then ply:SetPublicString(nw.EyelashColor, "") end
    if nw.IrisStyle then ply:SetPublicInt(nw.IrisStyle, 1) end
    if nw.IrisSize then ply:SetPublicInt(nw.IrisSize, self.GetDefaultIrisSize and self:GetDefaultIrisSize() or 100) end
    if nw.EyeColor then ply:SetPublicString(nw.EyeColor, "") end
end

function CH:ApplyPlayerAppearance(ply, char)
    if not IsValid(ply) or not istable(char) then
        self:ClearPlayerAppearance(ply)
        return nil
    end

    local job = (VERSE.Jobs.Get and VERSE.Jobs:Get(ply:GetJobID())) or nil
    local mdl = self:ResolveModel(char, job, char.gender)

    -- Si une tenue est équipée, elle prend la priorité sur le modèle du personnage
    local equippedOutfit = ply.Job and ply.Job.custom and isstring(ply.Job.custom.model) and ply.Job.custom.model ~= "" and ply.Job.custom.model
    if equippedOutfit and util.IsValidModel(equippedOutfit) then
        mdl = equippedOutfit
    end

    if mdl and util.IsValidModel(mdl) then
        ply:SetModel(mdl)
        if ply.Job then ply.Job.resolvedModel = mdl end
    end

    clearLegacyBodyMarkSubMaterials(ply)
    local heightValue = tonumber(char.height)
    if not heightValue then heightValue = self:ConfigInt("DefaultHeight", 165, 50, 400) end
    local modelScale = self.GetHeightScale and self:GetHeightScale(heightValue) or 1
    if ply.SetModelScale then ply:SetModelScale(modelScale, 0) end
    setEntityBodygroup(ply, 0, char.body_style)
    local appearance = self.GetAppearanceData and self:GetAppearanceData(char, mdl) or nil
    if not appearance then
        self:ClearPlayerAppearance(ply)
        return mdl
    end

    local nw = self.AppearanceNW or {}
    if nw.Faction then ply:SetPublicString(nw.Faction, tostring(char.faction or "")) end
    if nw.HeadModel then ply:SetPublicString(nw.HeadModel, tostring(appearance.head_model or "")) end
    if nw.Height then ply:SetPublicInt(nw.Height, math.floor(heightValue)) end
    if nw.SkinTone then ply:SetPublicInt(nw.SkinTone, tonumber(appearance.skin_tone) or 1) end
    if nw.SkinColor then ply:SetPublicString(nw.SkinColor, tostring(appearance.skin_color or "")) end
    if nw.BodyStyle then ply:SetPublicInt(nw.BodyStyle, tonumber(appearance.body_style) or 0) end
    if nw.BodyMarks then ply:SetPublicString(nw.BodyMarks, tostring(appearance.body_marks_json or "")) end
    if nw.SpiritAccessory then ply:SetPublicInt(nw.SpiritAccessory, tonumber(appearance.spirit_accessory) or 0) end
    local spiritAccessoryData = istable(appearance.spirit_accessory_data) and appearance.spirit_accessory_data or {}
    if nw.SpiritAccessoryX then ply:SetPublicInt(nw.SpiritAccessoryX, tonumber(spiritAccessoryData.x) or 0) end
    if nw.SpiritAccessoryY then ply:SetPublicInt(nw.SpiritAccessoryY, tonumber(spiritAccessoryData.y) or 0) end
    if nw.SpiritAccessoryZ then ply:SetPublicInt(nw.SpiritAccessoryZ, tonumber(spiritAccessoryData.z) or 0) end
    if nw.SpiritAccessorySize then ply:SetPublicInt(nw.SpiritAccessorySize, tonumber(spiritAccessoryData.size) or 24) end
    if nw.SpiritAccessorySizeX then ply:SetPublicInt(nw.SpiritAccessorySizeX, tonumber(spiritAccessoryData.size_x or spiritAccessoryData.size) or 24) end
    if nw.SpiritAccessorySizeY then ply:SetPublicInt(nw.SpiritAccessorySizeY, tonumber(spiritAccessoryData.size_y or spiritAccessoryData.size) or 24) end
    if nw.SpiritAccessoryRotate then ply:SetPublicInt(nw.SpiritAccessoryRotate, tonumber(spiritAccessoryData.rotate) or 0) end
    if nw.HeadStyle then ply:SetPublicInt(nw.HeadStyle, tonumber(appearance.head_style) or 0) end
    if nw.HairStyle then ply:SetPublicInt(nw.HairStyle, tonumber(appearance.hair_style) or 0) end
    if nw.HairModel then ply:SetPublicInt(nw.HairModel, tonumber(appearance.hair_model) or 0) end
    if nw.HairColor then ply:SetPublicString(nw.HairColor, tostring(appearance.hair_color or "")) end
    if nw.HairTipColor then ply:SetPublicString(nw.HairTipColor, tostring(appearance.hair_tip_color or "")) end
    if nw.EyebrowStyle then ply:SetPublicInt(nw.EyebrowStyle, tonumber(appearance.eyebrow_style) or 1) end
    if nw.EyebrowColor then ply:SetPublicString(nw.EyebrowColor, tostring(appearance.eyebrow_color or "")) end
    if nw.EyelashColor then ply:SetPublicString(nw.EyelashColor, tostring(appearance.eyelash_color or "")) end
    if nw.IrisStyle then ply:SetPublicInt(nw.IrisStyle, tonumber(appearance.iris_style) or 1) end
    if nw.IrisSize then ply:SetPublicInt(nw.IrisSize, tonumber(appearance.iris_size) or (self.GetDefaultIrisSize and self:GetDefaultIrisSize() or 100)) end
    if nw.EyeColor then ply:SetPublicString(nw.EyeColor, tostring(appearance.eye_color or "")) end
    if nw.HeadType then ply:SetPublicInt(nw.HeadType, tonumber(appearance.head_type) or 1) end
    if nw.Flex then ply:SetPublicString(nw.Flex, tostring(appearance.flex_json or "")) end
    return mdl
end

function CH:LoadCharacter(ply, char)
    if not IsValid(ply) or not istable(char) then return false end
    if not (VERSE.Jobs and VERSE.Jobs.SetPlayerJob) then return false end
    if (not istable(char.body_marks) or next(char.body_marks) == nil) and isstring(char.presets_skin) and char.presets_skin ~= "" then
        local preset = util.JSONToTable(char.presets_skin)
        if istable(preset) and preset.body_marks ~= nil then
            char.body_marks = (self.NormalizeBodyMarksData and self:NormalizeBodyMarksData(char.faction, preset.body_marks)) or preset.body_marks
        end
    end
    self:SetSelected(ply, char)

    -- Bloque toute écriture DB dans VERSE::OnChanged::Jobs pendant le chargement.
    -- Sans ce flag, le hook sv_classes écrase le job_id en DB du personnage
    -- précédemment sélectionné avec le job du personnage entrant.
    -- Le pcall garantit que __loadingChar est toujours remis à nil même si
    -- SetPlayerJob lève une exception (évite un blocage permanent des writes DB).
    ply.__loadingChar = true
    local callOk, callErr = pcall(function()
        local ok = VERSE.Jobs:SetPlayerJob(ply, char.job_id, {
            noPersist = true,
            skipWhitelist = true
        })

        if not ok then
            local def = self:ConfigString("DefaultJob", "classe_4")
            VERSE.Jobs:SetPlayerJob(ply, def, {
                noPersist = true,
                skipWhitelist = true
            })
        end
    end)
    ply.__loadingChar = nil

    if not callOk then
        if VERSE.Log and VERSE.Log.Error then
            VERSE.Log:Error("[Characters] LoadCharacter SetPlayerJob exception: " .. tostring(callErr))
        end
    end

    self:ApplyPlayerAppearance(ply, char)
    ply:SetPublicInt(self:ConfigString("VarChar", "VERSE::CharID"), tonumber(char.id) or 0)
    if self:AcquaintancesEnabled() and char.id then self:LoadKnowns(tonumber(char.id)) end
    netstream.Start(ply, CH.Net.Selected, true, {
        id = char.id,
        slot = char.slot,
        firstname = char.firstname,
        lastname = char.lastname,
        nickname = char.nickname,
        description = char.description,
        job_id = char.job_id,
        faction = char.faction,
        model = char.model,
        gender = char.gender,
        age = char.age,
        height = char.height,
        skin_tone = char.skin_tone,
        skin_color = char.skin_color,
        body_style = char.body_style,
        body_marks = char.body_marks,
        head_type = char.head_type,
        head_style = char.head_style,
        hair_style = char.hair_style,
        hair_color = char.hair_color,
        hair_tip_color = char.hair_tip_color,
        eyebrow_style = char.eyebrow_style,
        eyebrow_color = char.eyebrow_color,
        eyelash_color = char.eyelash_color,
        iris_style = char.iris_style,
        iris_size = char.iris_size,
        eye_color = char.eye_color,
        flex = char.flex,
        spirit_accessory = char.spirit_accessory,
        spirit_accessory_data = char.spirit_accessory_data,
    })

    if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Characters::Loaded", ply, char) end
    return true
end

function CH:CreateCharacter(ply, data, cb)
    if not IsValid(ply) then
        if cb then cb(false, "bad_player") end
        return
    end

    local ok, res = self:ValidateCreateData(ply, data)
    if not ok then
        if cb then cb(false, res) end
        return
    end

    local sid = self:GetSteamID64(ply)
    local cache = CH._cache[sid] or {}
    if cache[res.slot] then
        if cb then cb(false, "slot_taken") end
        return
    end

    local t = nowSQL()
    -- Job de départ selon la faction :
    -- les Fléaux (spirit) commencent en Vermine, les autres en Classe 4.
    if tostring(res.faction or "") == "spirit" then
        res.job_id = "vermine"
    else
        res.job_id = "classe_4"
    end
    local row = {
        steamid64 = sid,
        slot = tonumber(res.slot),
        firstname = res.firstname,
        lastname = res.lastname,
        nickname = res.nickname,
        description = res.description,
        job_id = res.job_id,
        faction = res.faction,
        model = res.model,
        gender = res.gender,
        age = (res.age ~= nil) and tonumber(res.age) or nil,
        height = (res.height ~= nil) and tonumber(res.height) or nil,
        presets_skin = encodeSkinPreset(res.faction, res),
        created_at = t,
        updated_at = t,
    }

    local q = buildInsert("verse_characters", self.DBColumns, row)
    DB:Query(q):Next(function() return CH:LoadAllCharacters(ply) end):Next(function()
        CH:SendList(ply)
        local charSlot = tonumber(res.slot)
        local charData = CH._cache[sid] and CH._cache[sid][charSlot]
        local charId = charData and tonumber(charData.id)
        -- Argent de départ via le système Wallet (plus d'item money dans l'inventaire)
        if charId and VERSE.Wallet then
            local startMoney = (VERSE.Inventory and VERSE.Inventory.Config and VERSE.Inventory.Config.StartingMoney) or 500
            if startMoney > 0 then
                VERSE.Wallet:SetAmount(charId, startMoney)
            end
        end

        -- Donne 1 ticket reroll "Pouvoir Occulte" gratuit à la création du personnage.
        local BT_ = VERSE and VERSE.Boutique
        if BT_ and BT_.Products and BT_.AdminModifyItem then
            local occultItemId = nil
            for _, p in pairs(BT_.Products) do
                if p.use_mode == "open_occult_page" then
                    occultItemId = p.id
                    break
                end
            end
            if occultItemId and sid and sid ~= "" then
                BT_:AdminModifyItem(sid, occultItemId, 1, function(ok, err)
                    if not ok then
                        VERSE.Log:Warn("[Characters] Echec attribution reroll occulte gratuit pour " .. tostring(sid) .. " : " .. tostring(err))
                    end
                end)
            end
        end

        if cb then cb(true) end
    end):Catch(function(err)
        VERSE.Log:Error("[Characters] CreateCharacter DB error: " .. tostring(err))
        if cb then cb(false, "db_error") end
    end)
end

local function cleanupCharFromKnownCaches(charId)
    CH._knownCache[charId] = nil
    for ownerId, set in pairs(CH._knownCache) do
        if istable(set) and set[charId] then set[charId] = nil end
    end
end

function CH:DeleteSlot(ply, slot, cb)
    if not IsValid(ply) then
        if cb then cb(false, "bad_player") end
        return
    end

    if not self:CanDeleteOwnCharacters(ply) then
        if cb then cb(false, "no_access") end
        return
    end

    slot = tonumber(slot)
    local slots = self:GetSlots(ply)
    if not slot or slot < 1 or slot > slots then
        if cb then cb(false, "bad_slot") end
        return
    end

    local sid = self:GetSteamID64(ply)
    local map = CH._cache[sid] or {}
    local char = map[slot]
    if not char then
        if cb then cb(false, "no_character") end
        return
    end

    local selected = self:GetSelected(ply)
    if selected and tonumber(selected.slot) == slot then
        self:SetSelected(ply, nil)
        ply:SetPublicInt(self:ConfigString("VarChar", "VERSE::CharID"), 0)
        self:ClearPlayerAppearance(ply)
        netstream.Start(ply, CH.Net.Selected, false, "no_character")
    end

    local charId = tonumber(char.id)
    if not charId or charId <= 0 then
        if cb then cb(false, "bad_character") end
        return
    end

    local qDelChar = ("DELETE FROM verse_characters WHERE steamid64=%s AND slot=%d"):format(esc(sid), slot)
    DB:Query(qDelChar):Next(function()
        if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Characters::Deleted", charId, sid, slot, ply) end
        if CH:AcquaintancesEnabled() then
            DB:Query(("DELETE FROM verse_character_known WHERE owner_char_id=%d OR known_char_id=%d"):format(charId, charId))
            cleanupCharFromKnownCaches(charId)
            broadcastForgetChar(charId)
        end
        return CH:LoadAllCharacters(ply)
    end):Next(function()
        CH:SendList(ply)
        if cb then cb(true) end
    end):Catch(function(err)
        VERSE.Log:Error("[Characters] DeleteSlot DB error: " .. tostring(err))
        if cb then cb(false, "db_error") end
    end)
end

function CH:DeleteOtherSlot(ply, targetSteamID64, slot, cb)
    if not IsValid(ply) then
        if cb then cb(false, "bad_player") end
        return
    end

    if not self:CanDeleteOtherCharacters(ply) then
        if cb then cb(false, "no_access") end
        return
    end

    targetSteamID64 = tostring(targetSteamID64 or ""):Trim()
    if targetSteamID64 == "" or targetSteamID64 == "0" then
        if cb then cb(false, "bad_target") end
        return
    end

    slot = tonumber(slot)
    if not slot or slot < 1 or slot > 63 then
        if cb then cb(false, "bad_slot") end
        return
    end

    local qFind = ("SELECT id FROM verse_characters WHERE steamid64=%s AND slot=%d"):format(esc(targetSteamID64), slot)
    DB:Query(qFind):Next(function(res)
        local rows = res.rows or {}
        local targetCharId = rows[1] and tonumber(rows[1].id) or nil
        if not targetCharId or targetCharId <= 0 then
            if cb then cb(false, "no_character") end
            return
        end

        local qDel = ("DELETE FROM verse_characters WHERE steamid64=%s AND slot=%d"):format(esc(targetSteamID64), slot)
        DB:Query(qDel):Next(function()
            if VERSE.Hook and VERSE.Hook.Run then VERSE.Hook.Run("VERSE::Characters::Deleted", targetCharId, targetSteamID64, slot, ply) end
            if CH:AcquaintancesEnabled() then
                DB:Query(("DELETE FROM verse_character_known WHERE owner_char_id=%d OR known_char_id=%d"):format(targetCharId, targetCharId))
                cleanupCharFromKnownCaches(targetCharId)
                broadcastForgetChar(targetCharId)
            end

            local targetPly = player.GetBySteamID64(targetSteamID64)
            if IsValid(targetPly) then
                local selected = CH:GetSelected(targetPly)
                if selected and tonumber(selected.slot) == slot then
                    CH:SetSelected(targetPly, nil)
                    targetPly:SetPublicInt(self:ConfigString("VarChar", "VERSE::CharID"), 0)
                    CH:ClearPlayerAppearance(targetPly)
                    netstream.Start(targetPly, CH.Net.Selected, false, "no_character")
                end

                CH:LoadAllCharacters(targetPly):Next(function() CH:SendList(targetPly) end)
            else
                CH._cache[targetSteamID64] = nil
            end

            CH:LoadAllCharacters(ply):Next(function()
                CH:SendList(ply)
                if cb then cb(true) end
            end)
        end):Catch(function(err)
            VERSE.Log:Error("[Characters] DeleteOtherSlot DB error: " .. tostring(err))
            if cb then cb(false, "db_error") end
        end)
    end):Catch(function(err)
        VERSE.Log:Error("[Characters] DeleteOtherSlot find error: " .. tostring(err))
        if cb then cb(false, "db_error") end
    end)
end

local function applyCharacterSelectionToPlayer(ply, char)
    if not IsValid(ply) or not istable(char) then return false, "bad_player" end
    local ok = CH:LoadCharacter(ply, char)
    if not ok then return false, "load_failed" end
    ply:Freeze(false)
    -- Toujours respawner : FactionSpawn téléporte au spawn de faction.
    -- L'optimisation "même perso = pas de respawn" causait des spawns en zone
    -- de création quand le joueur revenait au menu de sélection.
    ply.__ccSkipRestore = true
    ply:Spawn()
    return true
end

function CH:SelectSlot(ply, slot, cb)
    if not IsValid(ply) then
        if cb then cb(false, "bad_player") end
        return
    end

    slot = tonumber(slot)
    local slots = self:GetSlots(ply)
    if not slot or slot < 1 or slot > slots then
        if cb then cb(false, "bad_slot") end
        return
    end

    local sid = self:GetSteamID64(ply)
    local map = CH._cache[sid] or {}
    local char = map[slot]
    if not char then
        if cb then cb(false, "no_character") end
        return
    end

    local ok, err = applyCharacterSelectionToPlayer(ply, char)
    if cb then cb(ok, err) end
end

function CH:Introduce(ply, targetPly, cb)
    if not self:AcquaintancesEnabled() then
        if cb then cb(false, "known_disabled") end
        return
    end

    if not IsValid(ply) or not IsValid(targetPly) or ply == targetPly then
        if cb then cb(false, "bad_target") end
        return
    end

    local aId = self:GetSelectedCharID(ply)
    local bId = self:GetSelectedCharID(targetPly)
    if not aId or not bId then
        if cb then cb(false, "no_character") end
        return
    end

    -- Sens unique : A se présente → la cible (B) apprend le nom de A.
    -- Si B connaît déjà A, rien à faire.
    local bKnowsA = self:KnowsChar(bId, aId)
    if bKnowsA then
        if cb then cb(true) end
        return
    end

    local aChar = self:GetSelected(ply)
    local aName = self:GetDisplayName(aChar or {})
    -- B reçoit immédiatement le nom de A, sans popup ni validation.
    applyKnownOneWay(bId, aId, targetPly, aName)
    if cb then cb(true) end
end

netstream.Hook(CH.Net.List, function(ply)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end
    CH:LoadAllCharacters(ply):Next(function() CH:SendList(ply) end)
end)

netstream.Hook(CH.Net.AdminList, function(ply)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end
    CH:SendAdminList(ply, function(success, error)
        if success then return end
        netstream.Start(ply, CH.Net.Selected, false, tostring(error or "unknown"))
    end)
end)

netstream.Hook(CH.Net.Create, function(ply, data)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end

    local sid = ply:SteamID()
    if CH._busy[sid] then return end
    CH._busy[sid] = true

    data = istable(data) and data or {}
    CH:CreateCharacter(ply, data, function(success, error)
        CH._busy[sid] = nil
        if success then return end
        netstream.Start(ply, CH.Net.Selected, false, tostring(error or "unknown"))
    end)
end)

netstream.Hook(CH.Net.Delete, function(ply, slot)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end
    CH:DeleteSlot(ply, slot, function(success, error)
        if success then return end
        netstream.Start(ply, CH.Net.Selected, false, tostring(error or "unknown"))
    end)
end)

netstream.Hook(CH.Net.AdminDelete, function(ply, targetSteamID64, slot)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end
    targetSteamID64 = tostring(targetSteamID64 or ""):Trim()
    slot = tonumber(slot)
    if targetSteamID64 == "" or not slot then
        netstream.Start(ply, CH.Net.Selected, false, "bad_target")
        return
    end

    local onDone = function(success, error)
        if not success then
            netstream.Start(ply, CH.Net.Selected, false, tostring(error or "unknown"))
            return
        end

        CH:SendAdminList(ply, function(ok, listError)
            if ok then return end
            netstream.Start(ply, CH.Net.Selected, false, tostring(listError or "unknown"))
        end)
    end

    if targetSteamID64 == CH:GetSteamID64(ply) then
        CH:DeleteSlot(ply, slot, onDone)
        return
    end

    CH:DeleteOtherSlot(ply, targetSteamID64, slot, onDone)
end)

netstream.Hook(CH.Net.Select, function(ply, slot)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end
    CH:SelectSlot(ply, slot, function(success, error)
        if success then return end
        netstream.Start(ply, CH.Net.Selected, false, tostring(error or "unknown"))
    end)
end)

netstream.Hook(CH.Net.Introduce, function(ply, targetEntIndex)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end
    if not CH:AcquaintancesEnabled() then return end
    local target = Entity(tonumber(targetEntIndex) or -1)
    if not IsValid(target) or not target:IsPlayer() then return end
    CH:Introduce(ply, target)
end)

netstream.Hook(CH.Net.Known, function(ply)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end
    local charId = CH:GetSelectedCharID(ply)
    if not charId or not CH:AcquaintancesEnabled() then
        netstream.Start(ply, CH.Net.Known, {})
        return
    end

    CH:LoadKnowns(charId):Next(function(set)
        set = set or {}
        local ids = {}
        for id, ok in pairs(set) do
            if ok then ids[#ids + 1] = tonumber(id) end
        end

        if #ids == 0 then
            netstream.Start(ply, CH.Net.Known, {})
            return
        end

        local q = ("SELECT id, firstname, lastname, nickname FROM verse_characters WHERE id IN (%s)"):format(table.concat(ids, ","))
        DB:Query(q):Next(function(res)
            local out = {}
            for _, r in ipairs(res.rows or {}) do
                local id = tonumber(r.id)
                if id then
                    out[id] = CH:GetDisplayName({
                        firstname = r.firstname,
                        lastname = r.lastname,
                        nickname = r.nickname,
                    })
                end
            end

            netstream.Start(ply, CH.Net.Known, out)
        end)
    end)
end)

local function resolveIntroducePair(fromPly, toPly)
    if not IsValid(fromPly) or not IsValid(toPly) then return nil, "bad_players" end
    if fromPly == toPly then return nil, "same_player" end
    local aId = CH:GetSelectedCharID(fromPly)
    local bId = CH:GetSelectedCharID(toPly)
    if not aId or not bId then return nil, "no_character" end
    return {
        aId = aId,
        bId = bId,
        aChar = CH:GetSelected(fromPly),
        bChar = CH:GetSelected(toPly),
        aName = CH:GetDisplayName(CH:GetSelected(fromPly) or {}),
        bName = CH:GetDisplayName(CH:GetSelected(toPly) or {}),
    }
end

function CH:HasPendingIntroduce(fromPly, toPly)
    local info = resolveIntroducePair(fromPly, toPly)
    if not info then return false end
    cleanupPending()
    local pending = self._introPending[introKey(info.aId, info.bId)]
    if not pending then return false end
    if pending.expires and pending.expires <= CurTime() then return false end
    return pending.from_charid == info.aId and pending.to_charid == info.bId
end

function CH:AcceptIntroduce(fromPly, toPly)
    if not self:AcquaintancesEnabled() then return false, "known_disabled" end
    local info, err = resolveIntroducePair(fromPly, toPly)
    if not info then return false, err end
    cleanupPending()
    local key = introKey(info.aId, info.bId)
    self._introPending[key] = nil
    applyKnownTwoWay(info.aId, info.bId, fromPly, toPly, info.aName, info.bName)
    return true
end

function CH:RejectIntroduce(fromPly, toPly)
    local info = resolveIntroducePair(fromPly, toPly)
    if not info then return false end
    self._introPending[introKey(info.aId, info.bId)] = nil
    return true
end

function CH:ForceIntroduce(aPly, bPly)
    if not self:AcquaintancesEnabled() then return false, "known_disabled" end
    local info, err = resolveIntroducePair(aPly, bPly)
    if not info then return false, err end
    applyKnownTwoWay(info.aId, info.bId, aPly, bPly, info.aName, info.bName)
    return true
end

function CH:ForceOneWayIntroduce(ownerPly, targetPly)
    if not self:AcquaintancesEnabled() then return false, "known_disabled" end
    local info, err = resolveIntroducePair(ownerPly, targetPly)
    if not info then return false, err end
    applyKnownOneWay(info.aId, info.bId, ownerPly, info.bName)
    return true
end

function CH:ForgetKnown(ownerPly, targetPly, twoWay)
    if not IsValid(ownerPly) or not IsValid(targetPly) then return false, "bad_players" end
    local aId = self:GetSelectedCharID(ownerPly)
    local bId = self:GetSelectedCharID(targetPly)
    if not aId or not bId then return false, "no_character" end
    local tbl = "verse_character_known"
    DB:Query(("DELETE FROM %s WHERE owner_char_id=%d AND known_char_id=%d"):format(tbl, aId, bId))
    local set = self._knownCache[aId]
    if set then set[bId] = nil end
    if IsValid(ownerPly) then netstream.Start(ownerPly, CH.Net.KnownUpdate, 2, bId) end
    if twoWay then
        DB:Query(("DELETE FROM %s WHERE owner_char_id=%d AND known_char_id=%d"):format(tbl, bId, aId))
        local setB = self._knownCache[bId]
        if setB then setB[aId] = nil end
        if IsValid(targetPly) then netstream.Start(targetPly, CH.Net.KnownUpdate, 2, aId) end
    end
    return true
end

netstream.Hook(CH.Net.IntroduceAnswer, function(ply, fromEntIndex, accepted)
    if not IsValid(ply) then return end
    if not CH:ConfigBool("Enabled", true) then return end
    if not CH:AcquaintancesEnabled() then return end
    if not CH:AcquaintancesMode() then return end
    cleanupPending()
    local fromPly = Entity(tonumber(fromEntIndex) or -1)
    accepted = accepted == true
    if not IsValid(fromPly) or not fromPly:IsPlayer() then return end
    if fromPly == ply then return end
    local aId = CH:GetSelectedCharID(fromPly)
    local bId = CH:GetSelectedCharID(ply)
    if not aId or not bId then return end
    local key = introKey(aId, bId)
    local pending = CH._introPending[key]
    if not pending then return end
    if pending.expires <= CurTime() then
        CH._introPending[key] = nil
        return
    end

    if pending.from_sid64 ~= fromPly:SteamID64() then
        CH._introPending[key] = nil
        return
    end

    if pending.to_sid64 ~= ply:SteamID64() then
        CH._introPending[key] = nil
        return
    end

    if pending.from_charid ~= aId or pending.to_charid ~= bId then
        CH._introPending[key] = nil
        return
    end

    CH._introPending[key] = nil
    if not accepted then return end
    local aChar = CH:GetSelected(fromPly)
    local bChar = CH:GetSelected(ply)
    local aName = CH:GetDisplayName(aChar or {})
    local bName = CH:GetDisplayName(bChar or {})
    applyKnownTwoWay(aId, bId, fromPly, ply, aName, bName)
end)

-- Forward-déclaration de la zone de création (valeurs assignées plus bas).
-- Permet aux hooks de spawn ci-dessous de pré-téléporter les nouveaux joueurs
-- à la zone de création, pour que leur client charge la géométrie du monde à
-- cet endroit (sinon : pas de fond 3D lors de la création d'un premier perso).
local _CC_ZONE_POS, _CC_ZONE_ANG

VERSE.Hook.AddNS("Characters", "PlayerInitialSpawn", "VERSE::PlayerInitialSpawn::Characters", function(ply)
    if not CH:ConfigBool("Enabled", true) then return end
    if not IsValid(ply) then return end
    ply:Freeze(true)
    ply:SetPublicInt(CH:ConfigString("VarChar", "VERSE::CharID"), 0)
    CH:ClearPlayerAppearance(ply)
    DB:OnReady():Next(function()
        if not IsValid(ply) then return end
        return CH:LoadAllCharacters(ply)
    end):Next(function()
        if not IsValid(ply) then return end
        CH:SendList(ply)
    end)
end)

DB:OnReady():Next(function() CH:CreateTables() end)
VERSE.Hook.AddNS("Characters", "PlayerSpawn", "VERSE::PlayerSpawn::Characters", function(ply)
    if not CH:ConfigBool("Enabled", true) then return end
    if not IsValid(ply) then return end
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        local selected = CH:GetSelected(ply)
        if not istable(selected) then
            CH:ClearPlayerAppearance(ply)
            -- Pas de perso sélectionné → le joueur va à l'écran de sélection/création.
            -- On le pré-téléporte à la zone de création + freeze, pour que son client
            -- charge la géométrie du monde à cet endroit. Sans ça, créer un premier
            -- perso juste après connexion affiche un fond noir (PVS pas chargé).
            if _CC_ZONE_POS then
                ply:SetPos(_CC_ZONE_POS)
                if _CC_ZONE_ANG then ply:SetAngles(_CC_ZONE_ANG) end
                ply:Freeze(true)
            end
            return
        end

        CH:ApplyPlayerAppearance(ply, selected)
    end)
end)

-- Faction spawn : téléporte les joueurs Fléaux (spirit) à leur point de spawn dédié.
VERSE.Hook.AddNS("Characters", "PlayerSpawn", "VERSE::PlayerSpawn::FactionSpawn", function(ply)
    if not CH:ConfigBool("Enabled", true) then return end
    if not IsValid(ply) then return end
    local selected = CH:GetSelected(ply)
    if not istable(selected) then return end
    local factionId = tostring(selected.faction or "")
    if factionId == "" then return end
    local factionCfg = CH:GetConfig("Factions", factionId)
    if not istable(factionCfg) then return end
    local pos = factionCfg.spawn_pos
    local ang = factionCfg.spawn_ang
    if not isvector(pos) then return end
    -- Légère variation aléatoire pour éviter que les joueurs se superposent.
    local spread = 80
    local finalPos = Vector(
        pos.x + math.Rand(-spread, spread),
        pos.y + math.Rand(-spread, spread),
        pos.z
    )
    local finalAng = isangle(ang) and ang or nil
    -- Différé au tick suivant : GMod replace le joueur sur un info_player_start
    -- après le hook PlayerSpawn, ce qui annulerait un SetPos immédiat.
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        ply:SetPos(finalPos)
        if finalAng then ply:SetEyeAngles(finalAng) end
    end)
end)

local function findForceSlotTarget(rawTarget, fallbackPly)
    rawTarget = tostring(rawTarget or ""):Trim()
    if rawTarget == "" then return IsValid(fallbackPly) and fallbackPly or nil end
    local exactName = nil
    local partialName = nil
    local lowered = string.lower(rawTarget)
    for _, targetPly in ipairs(player.GetAll()) do
        if not IsValid(targetPly) then continue end
        if tostring(targetPly:SteamID64() or "") == rawTarget then return targetPly end
        if tostring(targetPly:SteamID() or "") == rawTarget then return targetPly end
        if tostring(targetPly:UserID() or "") == rawTarget then return targetPly end
        if tostring(targetPly:EntIndex() or "") == rawTarget then return targetPly end
        local nick = tostring(targetPly:Nick() or "")
        if string.lower(nick) == lowered then exactName = exactName or targetPly end
        if not partialName and string.find(string.lower(nick), lowered, 1, true) then partialName = targetPly end
    end
    return exactName or partialName
end

local function sendForceSlotFeedback(actorPly, text)
    text = "[Characters] " .. tostring(text or "unknown")
    if IsValid(actorPly) then actorPly:ChatPrint(text) end
    MsgN(text)
end

VERSE.Commands.Add("verse_characters_force_slot", function(ply, args)
    if not CH:ConfigBool("Enabled", true) then
        sendForceSlotFeedback(ply, "characters system disabled")
        return
    end

    local ownerSteamID64 = tostring(args[1] or ""):Trim()
    local slot = tonumber(args[2])
    local targetPly = findForceSlotTarget(args[3], ply)
    if ownerSteamID64 == "" or not slot then
        sendForceSlotFeedback(ply, "usage: verse_characters_force_slot <owner_steamid64> <slot> [target]")
        return
    end

    if not IsValid(targetPly) then
        sendForceSlotFeedback(ply, "target player not found")
        return
    end

    CH:LoadCharacterByOwnerSlot(ownerSteamID64, slot, function(success, payload)
        if not success then
            sendForceSlotFeedback(ply, "failed to load character: " .. tostring(payload or "unknown"))
            return
        end

        local ok, err = applyCharacterSelectionToPlayer(targetPly, payload)
        if not ok then
            sendForceSlotFeedback(ply, "failed to apply character: " .. tostring(err or "unknown"))
            return
        end

        local targetInfo = ("%s [%s]"):format(tostring(targetPly:Nick() or "unknown"), tostring(targetPly:SteamID64() or "0"))
        sendForceSlotFeedback(ply, ("forced slot %d from %s onto %s"):format(tonumber(payload.slot) or slot, ownerSteamID64, targetInfo))
    end)
end, "developer", "server")

-- ─── Character Creator — zone de téléportation ───────────────────────────────
-- Le client envoie verse_cc_enter quand le créateur s'ouvre → on téléporte le
-- joueur dans la scène 3D et on le fige.  verse_cc_exit le remet à sa position
-- d'avant et le libère.

-- ─── Character Creator — zone de téléportation (optimisé 128 joueurs) ────────
-- SetPreventTransmit empêche la transmission réseau du joueur en création
-- aux autres clients → 0 update de position broadcast, 0 entité côté client.
-- Scalable jusqu'à 128 joueurs simultanés sans surcharge réseau.

-- Assignation des valeurs forward-déclarées plus haut (pas de 'local' ici).
_CC_ZONE_POS = Vector(10320.0, 4933.0, 11508.906250)
_CC_ZONE_ANG = Angle(0, -178.061422, 0)

local _ccSaved    = {}   -- [SteamID] = { pos, ang }
local _ccPlayers  = {}   -- [SteamID] = ply  (index des joueurs en création)
local _ccCooldown = {}   -- [SteamID] = CurTime() du dernier appel (rate-limit 2s)

-- Cache ply pour tous les autres clients (réseau + rendu)
local function ccHide(ply)
    local sid = ply:SteamID()
    _ccPlayers[sid] = ply
    for _, other in ipairs(player.GetAll()) do
        if other ~= ply then
            ply:SetPreventTransmit(other, true)   -- ply disparaît du réseau de other
        end
    end
end

-- Rend ply visible à nouveau pour tous
local function ccShow(ply)
    local sid = ply:SteamID()
    _ccPlayers[sid] = nil
    for _, other in ipairs(player.GetAll()) do
        if other ~= ply then
            ply:SetPreventTransmit(other, false)
        end
    end
end

-- Quand un nouveau joueur rejoint, les joueurs en création lui sont déjà inconnus
-- (SetPreventTransmit ne s'applique qu'aux clients déjà connectés).
-- On le met à jour pour qu'il ne les reçoive pas non plus.
hook.Add("PlayerInitialSpawn", "VERSE::CC::HideFromNewPlayer", function(newPly)
    for _, ccPly in pairs(_ccPlayers) do
        if IsValid(ccPly) then
            ccPly:SetPreventTransmit(newPly, true)
        end
    end
end)

util.AddNetworkString("verse_cc_enter")
util.AddNetworkString("verse_cc_exit")

net.Receive("verse_cc_enter", function(_, ply)
    if not IsValid(ply) then return end
    local now = CurTime()
    local sid = ply:SteamID()
    if (_ccCooldown[sid] or 0) + 2 > now then return end
    _ccCooldown[sid] = now
    if _ccSaved[sid] then return end  -- déjà en création, ignore
    -- Nettoie un éventuel flag de skip-restore laissé par une sélection précédente.
    -- Sans ça, annuler la création restait coincé à la zone de création (le flag
    -- d'une sélection antérieure faisait sauter la restauration de position).
    ply.__ccSkipRestore = nil
    _ccSaved[sid] = { pos = ply:GetPos(), ang = ply:GetAngles(), col = ply:GetCollisionGroup() }
    ply:SetPos(_CC_ZONE_POS)
    ply:SetAngles(_CC_ZONE_ANG)
    ply:Freeze(true)
    -- Tous les joueurs en création sont au MÊME point → on désactive la collision
    -- joueur↔joueur pour qu'ils ne se superposent pas / ne se grimpent pas dessus.
    -- COLLISION_GROUP_IN_VEHICLE garde la collision avec le monde (reste au sol)
    -- mais les joueurs se traversent. Effet "instance" sans téléport multiple.
    ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    ccHide(ply)
end)

net.Receive("verse_cc_exit", function(_, ply)
    if not IsValid(ply) then return end
    local now = CurTime()
    local sid = ply:SteamID()
    if (_ccCooldown[sid] or 0) + 2 > now then return end
    _ccCooldown[sid] = now
    local saved = _ccSaved[sid]
    if not saved then return end
    _ccSaved[sid] = nil
    ply:Freeze(false)
    -- Restaure la collision joueur normale.
    ply:SetCollisionGroup(saved.col or COLLISION_GROUP_PLAYER)
    ccShow(ply)
    -- Si le joueur vient de changer de personnage, ne pas restaurer l'ancienne
    -- position : le hook FactionSpawn a déjà (ou va) téléporter au spawn de faction.
    if ply.__ccSkipRestore then
        ply.__ccSkipRestore = nil
        return
    end
    ply:SetPos(saved.pos)
    ply:SetAngles(saved.ang)
end)

hook.Add("PlayerDisconnected", "VERSE::CC::SavedCleanup", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    if _ccSaved[sid] then
        _ccSaved[sid] = nil
        _ccPlayers[sid] = nil
        ply:Freeze(false)
        -- Pas besoin de ccShow : le joueur déconnecte, les transmits sont nettoyés auto
    end
    _ccCooldown[sid] = nil
end)