local BB = VERSE.Barbershop
local CH = VERSE.Characters
local DB = VERSE.DB
local function esc(v)
    return DB:Escape(tostring(v))
end
local _bbSaveCD = {}

function BB:OpenForPlayer(ply, npcEnt)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local char = CH:GetSelected(ply)
    local factionId = tostring(char.faction or "")
    local appearance = CH.GetAppearanceData and CH:GetAppearanceData(char, ply:GetModel()) or nil
    local heightVal = tonumber(char.height) or 170
    local modelScale = (CH.GetHeightScale and CH:GetHeightScale(heightVal)) or 1
    local payload = {
        char_id = tonumber(char.id) or 0,
        faction = factionId,
        gender = tostring(char.gender or "male"),
        hair_style = char.hair_style or 0,
        hair_model = char.hair_model or 0,
        hair_color = char.hair_color or "",
        hair_tip_color = char.hair_tip_color or "",
        eyebrow_style = char.eyebrow_style or 1,
        eyebrow_color = char.eyebrow_color or "",
        eyelash_color = char.eyelash_color or "",
        body_marks = char.body_marks or {},
        body_model = (appearance and appearance.body_model) or ply:GetModel(),
        head_model = (appearance and appearance.head_model) or "",
        body_style = char.body_style or 0,
        skin_color = (appearance and appearance.skin_color) or char.skin_color or "",
        iris_style = char.iris_style or 1,
        iris_size = char.iris_size or 100,
        eye_color = char.eye_color or "",
        flex = char.flex or {},
        model_scale = modelScale,
        height      = heightVal,
        skin_tone   = tonumber(char.skin_tone) or 1,
        npc_ent = IsValid(npcEnt) and npcEnt:EntIndex() or 0,
    }

    netstream.Start(ply, BB.Net.Open, payload)
end

local function withinDistance(ply, npcIdx)
    if not npcIdx or npcIdx <= 0 then return true end
    local ent = Entity(npcIdx)
    if not IsValid(ent) then return false end
    return ply:GetPos():Distance(ent:GetPos()) <= BB.MaxInteractionDistance
end

netstream.Hook(BB.Net.Save, function(ply, data)
    if not IsValid(ply) or not istable(data) then return end
    if not CH then return end
    local _now = CurTime()
    local _sid = ply:SteamID()
    if (_bbSaveCD[_sid] or 0) + 5 > _now then return end
    _bbSaveCD[_sid] = _now
    local char = CH:GetSelected(ply)
    if not istable(char) then
        netstream.Start(ply, BB.Net.Result, false, "no_character")
        return
    end

    if not withinDistance(ply, tonumber(data.npc_ent)) then
        netstream.Start(ply, BB.Net.Result, false, "too_far")
        return
    end

    local charId = tonumber(char.id)
    if not charId or charId <= 0 then
        netstream.Start(ply, BB.Net.Result, false, "bad_character")
        return
    end

    local minH = (CH.ConfigInt and CH:ConfigInt("HeightMin", 140)) or 140
    local maxH = (CH.ConfigInt and CH:ConfigInt("HeightMax", 220)) or 220
    local newHeight = math.Clamp(math.floor(tonumber(data.height) or char.height or 170), minH, maxH)

    local hairStyle = math.Clamp(math.floor(tonumber(data.hair_style) or char.hair_style or 0), 0, CH.GetHairStyleCount and CH:GetHairStyleCount() or 999)
    local hairModel = math.Clamp(math.floor(tonumber(data.hair_model) or char.hair_model or 0), 0, #(CH.HairModels or {}))
    local hairColor = tostring(data.hair_color or char.hair_color or "")
    local hairTipColor = tostring(data.hair_tip_color or char.hair_tip_color or "")
    local eyebrowStyle = math.max(1, math.floor(tonumber(data.eyebrow_style) or char.eyebrow_style or 1))
    if CH.GetEyebrowStyleCount then eyebrowStyle = math.Clamp(eyebrowStyle, 1, CH:GetEyebrowStyleCount()) end
    local eyebrowColor = tostring(data.eyebrow_color or char.eyebrow_color or "")
    local eyelashColor = tostring(data.eyelash_color or char.eyelash_color or "")
    local bodyMarks = data.body_marks
    if CH.NormalizeBodyMarksData then bodyMarks = CH:NormalizeBodyMarksData(char.faction, bodyMarks) end
    char.height = newHeight
    char.hair_style = hairStyle
    char.hair_model = hairModel
    char.hair_color = hairColor
    char.hair_tip_color = hairTipColor
    char.eyebrow_style = eyebrowStyle
    char.eyebrow_color = eyebrowColor
    char.eyelash_color = eyelashColor
    char.body_marks = bodyMarks
    local presetPayload = {
        skin_tone = char.skin_tone,
        skin_color = char.skin_color,
        body_style = char.body_style,
        body_marks = bodyMarks,
        head_type = char.head_type,
        head_style = char.head_style,
        hair_style = hairStyle,
        hair_model = hairModel,
        hair_color = hairColor,
        hair_tip_color = hairTipColor,
        eyebrow_style = eyebrowStyle,
        eyebrow_color = eyebrowColor,
        eyelash_color = eyelashColor,
        iris_style = char.iris_style,
        iris_size = char.iris_size,
        eye_color = char.eye_color,
        flex = char.flex,
        spirit_accessory = char.spirit_accessory,
        spirit_accessory_data = char.spirit_accessory_data,
    }

    local presetJSON = util.TableToJSON(presetPayload, false)

    -- Sécurité : cap à 32 Ko pour éviter l'injection de données massives
    if #presetJSON > 32768 then
        VERSE.Log:Error("[Barbershop] Payload trop grand (" .. #presetJSON .. " octets) pour char #" .. charId .. " (" .. ply:Nick() .. ")")
        if IsValid(ply) then netstream.Start(ply, BB.Net.Result, false, "data_too_large") end
        return
    end

    local now = os.time()
    local q = ("UPDATE verse_characters SET height=%d, presets_skin=%s, updated_at=%d WHERE id=%d"):format(newHeight, esc(presetJSON), now, charId)
    DB:Query(q):Next(function()
        if IsValid(ply) and CH.ApplyPlayerAppearance then CH:ApplyPlayerAppearance(ply, char) end
        if IsValid(ply) then netstream.Start(ply, BB.Net.Result, true) end
    end):Catch(function(err)
        VERSE.Log:Error("[Barbershop] UPDATE error: " .. tostring(err))
        if IsValid(ply) then netstream.Start(ply, BB.Net.Result, false, "db_error") end
    end)
end)