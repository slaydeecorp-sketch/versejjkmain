VERSE.Characters = VERSE.Characters or {}
local CH = VERSE.Characters
local Language = VERSE.L
VERSE.Config = VERSE.Config or {}
VERSE.Config.Characters = {
    Enabled = true,
    Slots = 3,
    AllowSelfDelete = {
        default = false,
        admins = {
            superadmin = true,
            admin = true,
        },
        steamids = {},
        access = {
            isdeveloper = function(ply)
                if IsValid(ply) and ply:IsDeveloper() then return true end
                return false
            end,
            isstaffplus = function(ply)
                if IsValid(ply) and ply:IsStaffPlus() then return true end
                return false
            end,
            isstaff = function(ply)
                if IsValid(ply) and ply:IsStaff() then return true end
                return false
            end,
        },
    },
    AllowOtherDelete = {
        default = false,
        admins = {},
        steamids = {},
        access = {
            isdeveloper = function(ply)
                if IsValid(ply) and ply:IsDeveloper() then return true end
                return false
            end,
        },
    },
    SlotPermissions = {
        default = 1,
        admins = {
            superadmin = 3,
            admin = 2,
        },
        steamids = {},
        access = {
            isdeveloper = function(ply)
                if IsValid(ply) and ply:IsDeveloper() then return 3 end
                return 0
            end,
            isstaffplus = function(ply)
                if IsValid(ply) and ply:IsStaffPlus() then return 2 end
                return 0
            end,
            isstaff = function(ply)
                if IsValid(ply) and ply:IsStaff() then return 2 end
                return 0
            end,
        },
    },
    EnableGender = true,
    EnableFaction = true,
    EnableAge = false,
    EnableDescription = false,
    EnableBodyMarks = true,
    EnableOrnaments = false,
    EnableAcquaintances = true,
    AcquaintancesMode = false,
    AcquaintancesTTL = 15,
    ValidateModel = true,
    WorldAppearanceDistance = 3000,  -- ~57m : couvre tout le gameplay visible ; au-delà la tête est imperceptible
    WorldAppearanceRefresh = 0.35,   -- légèrement ralenti : moins de rebuilds par seconde en masse
    DescRequired = true,
    GenderModels = false,
    VarChar = "VERSE::CharID",
    DefaultJob = "classe_4",
    NameMin = 2,
    NameMax = 18,
    DescMin = 10,
    DescMax = 512,
    GenderValues = {
        male = true,
        female = true,
    },
    DefaultGender = "male",
    AgeMin = 16,
    AgeMax = 60,
    DefaultAge = 18,
    HeightMin = 140,
    HeightMax = 180,
    DefaultHeight = 165,
    SkinColorPalette = {Color(255, 244, 230), Color(250, 232, 212), Color(240, 220, 198), Color(230, 205, 180), Color(223, 196, 168), Color(208, 176, 146), Color(192, 156, 126), Color(170, 134, 104), Color(150, 113, 86), Color(128, 94, 72), Color(105, 75, 58), Color(82, 56, 42),},
    NicknameMode = false,
    MenuMusic = "verse/character/ost_fallback.mp3",
    MenuMusicVolume = 0.35,
    Factions = {
        exorcist = {
            name = "EXORCISTES",
            mdl_pos = Vector(7653.938477, 8449.605469, -430.968750),
            mdl_ang = Angle(4.620002, -13.523964, 0.000000),
            cam_dist = 86,
            cam_height = 52,
            cam_fov = 48,
            body_marks = {
                categories = {
                    {
                        id = "scar",
                        name = "Cicatrice",
                        default = 1,
                        options = {
                            {
                                name = "Aucune",
                                material = ""
                            },
                            {
                                name = "Balafre 01",
                                material = "materials/verse/character/tattoos/3.png"
                            },
                            {
                                name = "Balafre 02",
                                material = "materials/verse/character/tattoos/7.png"
                            },
                            {
                                name = "Balafre 03",
                                material = "materials/verse/character/tattoos/9.png"
                            },
                            {
                                name = "Balafre 04",
                                material = "materials/verse/character/tattoos/14.png"
                            },
                            {
                                name = "Balafre 05",
                                material = "materials/verse/character/tattoos/15.png"
                            },
                            {
                                name = "Balafre 06",
                                material = "materials/verse/character/tattoos/16.png"
                            },
                        },
                    },
                    {
                        id = "tattoo",
                        name = "Tatouage",
                        default = 1,
                        options = {
                            {
                                name = "Aucun",
                                material = ""
                            },
                            {
                                name = "Tatouage 01",
                                material = "materials/verse/character/tattoos/1.png"
                            },
                            {
                                name = "Tatouage 02",
                                material = "materials/verse/character/tattoos/2.png"
                            },
                            {
                                name = "Tatouage 03",
                                material = "materials/verse/character/tattoos/4.png"
                            },
                            {
                                name = "Tatouage 04",
                                material = "materials/verse/character/tattoos/5.png"
                            },
                            {
                                name = "Tatouage 05",
                                material = "materials/verse/character/tattoos/6.png"
                            },
                            {
                                name = "Tatouage 06",
                                material = "materials/verse/character/tattoos/8.png"
                            },
                            {
                                name = "Tatouage 07",
                                material = "materials/verse/character/tattoos/10.png"
                            },
                            {
                                name = "Tatouage 08",
                                material = "materials/verse/character/tattoos/11.png"
                            },
                            {
                                name = "Tatouage 09",
                                material = "materials/verse/character/tattoos/12.png"
                            },
                            {
                                name = "Tatouage 10",
                                material = "materials/verse/character/tattoos/13.png"
                            },

                        },
                    },
                },
            },
            gender = {
                male = {
                    head = {"models/verse/head/base_head1.mdl", "models/verse/head/base_head4.mdl", "models/verse/head/base_head6.mdl", "models/verse/head/base_head7.mdl", "models/verse/head/base_head8.mdl", "models/verse/head/base_head9.mdl", "models/verse/head/base_head10.mdl",},
                    body = {"models/kleyyn_jjk/tenues/megumi_2.mdl"},
                },
                female = {
                    head = {"models/verse/head/base_head2.mdl", "models/verse/head/base_head3.mdl", "models/verse/head/base_head5.mdl",},
                    body = {"models/slayde_jjk/tenues/nobara_2.mdl"},
                },
            },
        },
        spirit = {
            name = "FLÉAUX",
            spawn_pos = Vector(12161.766602, 4138.287109, -6218.526367),
            spawn_ang = Angle(13.141928, 9.792789, 0.000000),
            mdl_pos = Vector(7653.938477, 8449.605469, -430.968750),
            mdl_ang = Angle(4.620002, -13.523964, 0.000000),
            cam_dist = 86,
            cam_height = 52,
            cam_fov = 48,
            accessories = {
                {
                    name = "Corne 1",
                    model = "models/slayde_jjk/accs/corne_1.mdl",
                },
                {
                    name = "Corne 2",
                    model = "models/slayde_jjk/accs/corne_2.mdl",
                },
                {
                    name = "Corne 3",
                    model = "models/slayde_jjk/accs/corne_3.mdl",
                },
            },
            body_marks = {
                categories = {
                    {
                        id = "scar",
                        name = "Cicatrice",
                        default = 1,
                        options = {
                            {
                                name = "Aucune",
                                material = ""
                            },
                            {
                                name = "Fissure 01",
                                material = "materials/verse/character/tattoos/3.png"
                            },
                            {
                                name = "Fissure 02",
                                material = "materials/verse/character/tattoos/7.png"
                            },
                            {
                                name = "Fissure 03",
                                material = "materials/verse/character/tattoos/9.png"
                            },
                            {
                                name = "Fissure 04",
                                material = "materials/verse/character/tattoos/14.png"
                            },
                            {
                                name = "Fissure 05",
                                material = "materials/verse/character/tattoos/15.png"
                            },
                            {
                                name = "Fissure 06",
                                material = "materials/verse/character/tattoos/16.png"
                            },
                        },
                    },
                    {
                        id = "tattoo",
                        name = "Tatouage",
                        default = 1,
                        options = {
                            {
                                name = "Aucun",
                                material = ""
                            },
                            {
                                name = "Tatouage 01",
                                material = "materials/verse/character/tattoos/1.png"
                            },
                            {
                                name = "Tatouage 02",
                                material = "materials/verse/character/tattoos/2.png"
                            },
                            {
                                name = "Tatouage 03",
                                material = "materials/verse/character/tattoos/4.png"
                            },
                            {
                                name = "Tatouage 04",
                                material = "materials/verse/character/tattoos/5.png"
                            },
                            {
                                name = "Tatouage 05",
                                material = "materials/verse/character/tattoos/6.png"
                            },
                            {
                                name = "Tatouage 06",
                                material = "materials/verse/character/tattoos/8.png"
                            },
                            {
                                name = "Tatouage 07",
                                material = "materials/verse/character/tattoos/10.png"
                            },
                            {
                                name = "Tatouage 08",
                                material = "materials/verse/character/tattoos/11.png"
                            },
                            {
                                name = "Tatouage 09",
                                material = "materials/verse/character/tattoos/12.png"
                            },
                            {
                                name = "Tatouage 10",
                                material = "materials/verse/character/tattoos/13.png"
                            },

                        },
                    },
                },
            },
            gender = {
                male = {
                    head = {"models/verse/head/base_head1.mdl", "models/verse/head/base_head4.mdl", "models/verse/head/base_head6.mdl", "models/verse/head/base_head7.mdl", "models/verse/head/base_head8.mdl", "models/verse/head/base_head9.mdl", "models/verse/head/base_head10.mdl",},
                    body = {"models/slayde_jjk/tenues/mahoraga2.mdl"},
                },
                female = {
                    head = {"models/verse/head/base_head2.mdl", "models/verse/head/base_head3.mdl", "models/verse/head/base_head5.mdl",},
                    body = {"models/slayde_jjk/tenues/nelliel.mdl"},
                },
            },
        },
    },
}

CH.IdlePool = {
    {
        Sequence = "f606-jjk-mai-as_cp_170_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-gojo2-as_cp_051_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-itadori-as_cp_010_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-geto3-as_cp_190_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-kasumi-as_cp_210_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-inumaki-as_cp_070_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-hanami-as_cp_150_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-muta-as_cp_220_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-panda-as_cp_080_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-mahito-as_cp_250_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-nobito-as_cp_270_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-toji-as_cp_170_00_characterselect_idle_01",
        Weight = 1
    },
    {
        Sequence = "f606-jjk-megumi-as_cp_030_00_characterselect_idle_01",
        Weight = 1
    },
}

CH.Net = {
    List = "VERSE::Characters::List",
    Selected = "VERSE::Characters::Selected",
    Create = "VERSE::Characters::Create",
    Select = "VERSE::Characters::Select",
    Delete = "VERSE::Characters::Delete",
    Known = "VERSE::Characters::Known",
    Introduce = "VERSE::Characters::Introduce",
    KnownUpdate = "VERSE::Characters::KnownUpdate",
    IntroduceRequest = "VERSE::Characters::IntroduceRequest",
    IntroduceAnswer = "VERSE::Characters::IntroduceAnswer",
    AdminList = "VERSE::Characters::AdminList",
    AdminDelete = "VERSE::Characters::AdminDelete",
}

CH.AppearanceNW = {
    Faction = "VERSE::Char::Faction",
    HeadModel = "VERSE::Char::HeadModel",
    Height = "VERSE::Char::Height",
    SkinTone = "VERSE::Char::SkinTone",
    SkinColor = "VERSE::Char::SkinColor",
    BodyStyle = "VERSE::Char::BodyStyle",
    BodyMarks = "VERSE::Char::BodyMarks",
    SpiritAccessory = "VERSE::Char::SpiritAccessory",
    SpiritAccessoryX = "VERSE::Char::SpiritAccessoryX",
    SpiritAccessoryY = "VERSE::Char::SpiritAccessoryY",
    SpiritAccessoryZ = "VERSE::Char::SpiritAccessoryZ",
    SpiritAccessorySize = "VERSE::Char::SpiritAccessorySize",
    SpiritAccessorySizeX = "VERSE::Char::SpiritAccessorySizeX",
    SpiritAccessorySizeY = "VERSE::Char::SpiritAccessorySizeY",
    SpiritAccessoryRotate = "VERSE::Char::SpiritAccessoryRotate",
    HeadStyle = "VERSE::Char::HeadStyle",
    HairStyle = "VERSE::Char::HairStyle",
    HairModel = "VERSE::Char::HairModel",
    HairColor = "VERSE::Char::HairColor",
    HairTipColor = "VERSE::Char::HairTipColor",
    EyebrowStyle = "VERSE::Char::EyebrowStyle",
    EyebrowColor = "VERSE::Char::EyebrowColor",
    EyelashColor = "VERSE::Char::EyelashColor",
    IrisStyle = "VERSE::Char::IrisStyle",
    IrisSize = "VERSE::Char::IrisSize",
    EyeColor = "VERSE::Char::EyeColor",
    HeadType = "VERSE::Char::HeadType",
    Flex = "VERSE::Char::Flex",
}


CH.FlexControllers = CH.FlexControllers or {"nose1", "nose2", "jawdrop", "jaw1", "jaw2", "eyes", "mouth", "mouth2",}
function CH:NormalizeFlexTable(raw)
    local out = {}
    if isstring(raw) and raw ~= "" then
        local parsed = util.JSONToTable(raw)
        if istable(parsed) then raw = parsed end
    end

    if not istable(raw) then return out end
    for _, name in ipairs(self.FlexControllers or {}) do
        local v = tonumber(raw[name])
        if v then out[name] = math.Clamp(v, 0, 1) end
    end
    return out
end

function CH:SerializeFlexTable(raw)
    local normalized = self:NormalizeFlexTable(raw)
    if not istable(normalized) or next(normalized) == nil then return nil end
    return util.TableToJSON(normalized, false)
end

local function _charactersCfg()
    VERSE.Config = VERSE.Config or {}
    VERSE.Config.Characters = VERSE.Config.Characters or {}
    return VERSE.Config.Characters
end

function CH:GetConfig(...)
    local c = _charactersCfg()
    local n = select("#", ...)
    if n == 0 then return c end
    local a1 = select(1, ...)
    if istable(a1) then
        local path = a1
        local default = (n >= 2) and select(2, ...) or nil
        local t = c
        for i = 1, #path do
            if not istable(t) then return default end
            t = t[path[i]]
            if t == nil then return default end
        end
        return t
    end

    local default = nil
    local pathCount = n
    if n >= 2 then
        local firstValue = (isstring(a1) or isnumber(a1)) and c[a1] or nil
        local last = select(n, ...)
        if n == 2 and not istable(firstValue) then
            default = select(2, ...)
            pathCount = 1
        elseif not (isstring(last) or isnumber(last)) then
            default = last
            pathCount = n - 1
        end
    end

    local t = c
    for i = 1, pathCount do
        local k = select(i, ...)
        if not (isstring(k) or isnumber(k)) then return default end
        if not istable(t) then return default end
        t = t[k]
        if t == nil then return default end
    end
    return t
end

function CH:ConfigBool(key, default)
    if default == nil then default = false end
    local v = self:GetConfig(key, default)
    if isbool(v) then return v end
    if isnumber(v) then return v ~= 0 end
    if isstring(v) then
        local normalized = string.lower(string.Trim(v))
        if normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on" then return true end
        if normalized == "false" or normalized == "0" or normalized == "no" or normalized == "off" or normalized == "" then return false end
    end
    return default == true
end

function CH:ConfigInt(key, default, minv, maxv)
    local v = tonumber(self:GetConfig(key, default))
    if v == nil then v = tonumber(default) end
    if v == nil then return default end
    v = math.floor(v)
    if minv ~= nil and v < minv then v = minv end
    if maxv ~= nil and v > maxv then v = maxv end
    return v
end

function CH:ConfigString(key, default)
    local v = self:GetConfig(key, default)
    if v == nil then return default end
    return tostring(v)
end

function CH:ConfigTable(key, default)
    local v = self:GetConfig(key, default)
    if istable(v) then return v end
    return default or {}
end

function CH:GetIdlePool()
    local pool = self.IdlePool
    if not istable(pool) or #pool == 0 then
        return {
            {
                Sequence = "idle_all_01",
                Weight = 1
            },
        }
    end
    return pool
end

function CH:GetHeightScale(height)
    local minH = self:ConfigInt("HeightMin", 140, 50, 400)
    local maxH = self:ConfigInt("HeightMax", 220, minH, 400)
    local defH = self:ConfigInt("DefaultHeight", 165, minH, maxH)
    local rawH = tonumber(height) or defH
    rawH = math.Clamp(rawH, minH, maxH)
    if defH <= 0 then return 1 end
    return math.Clamp(rawH / defH, 0.5, 2)
end

local function clampSlotBonus(value, maxSlots)
    maxSlots = math.max(1, math.floor(tonumber(maxSlots) or 1))
    if value == true then return maxSlots end
    if value == false then return 0 end
    value = tonumber(value)
    if not value then return 0 end
    return math.Clamp(math.floor(value), 0, maxSlots)
end

local function resolveAccessRule(rule, ply, fallback)
    if isfunction(rule) then
        local ok, result = pcall(rule, ply)
        if ok then return result end
        if VERSE.Log and VERSE.Log.Error then VERSE.Log:Error("[Characters] permission resolver failed: " .. tostring(result)) end
        return fallback
    end
    return rule
end

local function getMappedSlotBonus(map, ply, maxSlots, ...)
    if not istable(map) then return 0 end
    local candidates = {}
    for i = 1, select("#", ...) do
        local raw = tostring(select(i, ...) or ""):Trim()
        if raw ~= "" then candidates[#candidates + 1] = string.lower(raw) end
    end

    if #candidates == 0 then return 0 end
    local best = 0
    for key, value in pairs(map) do
        local normalizedKey = string.lower(tostring(key or ""):Trim())
        if normalizedKey ~= "" then
            for i = 1, #candidates do
                if normalizedKey == candidates[i] then
                    best = math.max(best, clampSlotBonus(resolveAccessRule(value, ply, 0), maxSlots))
                    break
                end
            end
        end
    end
    return best
end

local function getDynamicSlotBonus(accessMap, ply, maxSlots)
    if not istable(accessMap) or not IsValid(ply) then return 0 end
    local best = 0
    for _, rule in pairs(accessMap) do
        best = math.max(best, clampSlotBonus(resolveAccessRule(rule, ply, 0), maxSlots))
    end
    return best
end

local function resolveDeleteGrant(value)
    if value == true then return true end
    if tonumber(value) then return tonumber(value) > 0 end
    return false
end

local function getMappedDeleteAccess(map, ply, ...)
    if not istable(map) then return false end
    local candidates = {}
    for i = 1, select("#", ...) do
        local raw = tostring(select(i, ...) or ""):Trim()
        if raw ~= "" then candidates[#candidates + 1] = string.lower(raw) end
    end

    if #candidates == 0 then return false end
    for key, value in pairs(map) do
        local normalizedKey = string.lower(tostring(key or ""):Trim())
        if normalizedKey ~= "" then
            for i = 1, #candidates do
                if normalizedKey == candidates[i] then
                    if resolveDeleteGrant(resolveAccessRule(value, ply, false)) then return true end
                    break
                end
            end
        end
    end
    return false
end

local function getDynamicDeleteAccess(accessMap, ply)
    if not istable(accessMap) or not IsValid(ply) then return false end
    for _, rule in pairs(accessMap) do
        if resolveDeleteGrant(resolveAccessRule(rule, ply, false)) then return true end
    end
    return false
end

function CH:GetGrantedSlots(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    local maxSlots = self:ConfigInt("Slots", 1, 1, 63)
    local rules = self:GetConfig("SlotPermissions", {})
    if not istable(rules) then return 0 end
    local slots = clampSlotBonus(resolveAccessRule(rules.default, ply, 1), maxSlots)
    slots = math.max(slots, getMappedSlotBonus(rules.admins, ply, maxSlots, (ply.GetUserGroup and ply:GetUserGroup()) or ""))
    slots = math.max(slots, getMappedSlotBonus(rules.steamids, ply, maxSlots, (ply.SteamID and ply:SteamID()) or "", (ply.SteamID64 and ply:SteamID64()) or ""))
    slots = math.max(slots, getDynamicSlotBonus(rules.access, ply, maxSlots))
    return math.Clamp(slots, 1, maxSlots)
end

function CH:GetExtraSlots(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    local maxSlots = self:ConfigInt("Slots", 1, 1, 63)
    local rules = self:GetConfig("SlotPermissions", {})
    local baseSlots = clampSlotBonus(istable(rules) and resolveAccessRule(rules.default, ply, 1) or 1, maxSlots)
    local grantedSlots = self:GetGrantedSlots(ply)
    return math.max(0, grantedSlots - baseSlots)
end

function CH:GetSlots(ply)
    local maxSlots = self:ConfigInt("Slots", 1, 1, 63)
    if not IsValid(ply) then return maxSlots end
    local grantedSlots = self:GetGrantedSlots(ply)
    if grantedSlots <= 0 then return maxSlots end
    return math.Clamp(grantedSlots, 1, maxSlots)
end

function CH:CanDeleteOwnCharacters(ply)
    local rules = self:GetConfig("AllowSelfDelete", true)
    if rules == true or rules == false then return rules == true end
    if not istable(rules) then return false end
    local allowed = rules.default == true
    if not IsValid(ply) or not ply:IsPlayer() then return allowed end
    if not allowed then allowed = getMappedDeleteAccess(rules.admins, ply, (ply.GetUserGroup and ply:GetUserGroup()) or "") or getMappedDeleteAccess(rules.steamids, ply, (ply.SteamID and ply:SteamID()) or "", (ply.SteamID64 and ply:SteamID64()) or "") or getDynamicDeleteAccess(rules.access, ply) end
    return allowed
end

function CH:CanDeleteOtherCharacters(ply)
    local rules = self:GetConfig("AllowOtherDelete", nil)
    if rules == nil then return IsValid(ply) and ply:IsPlayer() and ply:IsDeveloper() end
    if rules == true or rules == false then return rules == true end
    if not istable(rules) then return false end
    local allowed = rules.default == true
    if not IsValid(ply) or not ply:IsPlayer() then return allowed end
    if not allowed then allowed = getMappedDeleteAccess(rules.admins, ply, (ply.GetUserGroup and ply:GetUserGroup()) or "") or getMappedDeleteAccess(rules.steamids, ply, (ply.SteamID and ply:SteamID()) or "", (ply.SteamID64 and ply:SteamID64()) or "") or getDynamicDeleteAccess(rules.access, ply) end
    return allowed
end

function CH:CanAccessAdminCharacters(ply)
    return self:CanDeleteOwnCharacters(ply) or self:CanDeleteOtherCharacters(ply)
end

function CH:FactionsEnabled()
    if not self:ConfigBool("EnableFaction", false) then return false end
    local factions = self:GetConfig("Factions")
    if not istable(factions) then return false end
    return next(factions) ~= nil
end

function CH:AcquaintancesEnabled()
    return self:ConfigBool("EnableAcquaintances", false)
end

function CH:AcquaintancesMode()
    return self:ConfigBool("AcquaintancesMode", false)
end

function CH:GetUnknownName()
    return Language("character.name_unknown")
end

function CH:GetGenderValues()
    local c = self:GetConfig()
    local gv = c.GenderValues
    if not istable(gv) then
        gv = {
            male = true,
            female = true
        }
    end
    return {
        male = gv.male == true,
        female = gv.female == true,
    }
end

function CH:GenderEnabled()
    if not self:ConfigBool("EnableGender", false) then return false end
    local gv = self:GetGenderValues()
    return (gv.male == true) or (gv.female == true)
end

function CH:GetDisplayName(char)
    if not istable(char) then return "" end
    if self:ConfigBool("NicknameMode", true) then
        local nick = tostring(char.nickname or ""):Trim()
        if nick ~= "" then return nick end
    end
    return (tostring(char.firstname or "") .. " " .. tostring(char.lastname or "")):Trim()
end

CH.AppearanceBodygroupSkips = CH.AppearanceBodygroupSkips or {}
local function normalizeAppearanceModelPath(mdl)
    mdl = tostring(mdl or ""):Trim()
    if mdl == "" then return "" end
    return string.lower(string.gsub(mdl, "\\", "/"))
end

local function normalizeBodyMarkId(value, fallback)
    local text = string.lower(string.Trim(tostring(value or fallback or "")))
    text = string.gsub(text, "[^%w_%-]", "_")
    text = string.gsub(text, "_+", "_")
    text = string.gsub(text, "^_+", "")
    text = string.gsub(text, "_+$", "")
    if text == "" then text = string.lower(string.Trim(tostring(fallback or "mark"))) end
    if text == "" then text = "mark" end
    return text
end

local function normalizeBodyMarkMaterialPath(path)
    path = string.Trim(tostring(path or ""))
    if path == "" then return "" end
    path = string.gsub(path, "\\", "/")
    path = string.gsub(path, "^materials/", "")
    return path
end

local function parseBodyMarksPayload(raw)
    if istable(raw) then return raw end
    if not isstring(raw) or raw == "" then return nil end
    local parsed = util.JSONToTable(raw)
    if istable(parsed) then return parsed end
    return nil
end

CH.BODY_MARK_OFFSET_MIN = CH.BODY_MARK_OFFSET_MIN or -300
CH.BODY_MARK_OFFSET_MAX = CH.BODY_MARK_OFFSET_MAX or 300
CH.BODY_MARK_DEPTH_MIN = CH.BODY_MARK_DEPTH_MIN or -200
CH.BODY_MARK_DEPTH_MAX = CH.BODY_MARK_DEPTH_MAX or 200
CH.BODY_MARK_SIZE_MIN = CH.BODY_MARK_SIZE_MIN or -50
CH.BODY_MARK_SIZE_MAX = CH.BODY_MARK_SIZE_MAX or 50
CH.BODY_MARK_DEFAULT_X = CH.BODY_MARK_DEFAULT_X or 0
CH.BODY_MARK_DEFAULT_Y = CH.BODY_MARK_DEFAULT_Y or 0
CH.BODY_MARK_DEFAULT_Z = CH.BODY_MARK_DEFAULT_Z or -5
CH.BODY_MARK_DEFAULT_ROT = CH.BODY_MARK_DEFAULT_ROT or 0
CH.BODY_MARK_DEFAULT_SIZE = CH.BODY_MARK_DEFAULT_SIZE or 24
local function clampBodyMarkNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    value = math.floor(value)
    if minValue ~= nil and value < minValue then value = minValue end
    if maxValue ~= nil and value > maxValue then value = maxValue end
    return value
end

local function collectBodyMarkSlots(categories)
    local slots = {}
    for _, category in ipairs(categories or {}) do
        local categorySlot = tonumber(category.slot)
        if categorySlot ~= nil then slots[categorySlot] = true end
        for _, option in ipairs(category.options or {}) do
            local optionSlot = tonumber(option.slot)
            if optionSlot ~= nil then slots[optionSlot] = true end
        end
    end
    return slots
end

function CH:GetFactionBodyMarkConfig(factionOrId)
    local faction = factionOrId
    if isstring(factionOrId) then faction = self:GetConfig("Factions", factionOrId) end
    if not istable(faction) then return nil end
    local marks = faction.body_marks
    if not istable(marks) then return nil end
    return marks
end

function CH:GetBodyMarkCategories(factionOrId)
    if not self:ConfigBool("EnableBodyMarks", true) then return {} end
    local marksCfg = self:GetFactionBodyMarkConfig(factionOrId)
    if not istable(marksCfg) then return {} end
    local rawCategories = marksCfg.categories
    if not istable(rawCategories) then return {} end
    local fallbackSlot = tonumber(marksCfg.slot)
    local out = {}
    for index, rawCategory in ipairs(rawCategories) do
        if istable(rawCategory) then
            local categoryId = normalizeBodyMarkId(rawCategory.id, "mark_" .. tostring(index))
            local rawOptions = istable(rawCategory.options) and rawCategory.options or {}
            if #rawOptions == 0 then
                rawOptions = {
                    {
                        name = "None",
                        material = ""
                    }
                }
            end

            local categorySlot = tonumber(rawCategory.slot)
            local options = {}
            for optionIndex, rawOption in ipairs(rawOptions) do
                local option = istable(rawOption) and rawOption or {}
                options[#options + 1] = {
                    name = tostring(option.name or ("Option " .. tostring(optionIndex))),
                    material = normalizeBodyMarkMaterialPath(option.material or option.path or ""),
                    slot = tonumber(option.slot) or categorySlot or fallbackSlot,
                }
            end

            out[#out + 1] = {
                id = categoryId,
                name = tostring(rawCategory.name or categoryId),
                slot = categorySlot or fallbackSlot,
                default = clampBodyMarkNumber(rawCategory.default, 1, #options, 1) or 1,
                options = options,
            }
        end
    end
    return out
end

function CH:GetSpiritAccessoryOptions(factionOrId)
    if not self:ConfigBool("EnableOrnaments", true) then return {} end
    local faction = factionOrId
    local factionId = factionOrId
    if isstring(factionOrId) then
        faction = self:GetConfig("Factions", factionOrId)
    elseif istable(factionOrId) then
        factionId = tostring(factionOrId.id or "")
    end

    if not istable(faction) then return {} end
    factionId = tostring(factionId or "")
    if factionId == "" then
        for key, factionCfg in pairs(self:GetConfig("Factions", {})) do
            if factionCfg == faction then
                factionId = tostring(key or "")
                break
            end
        end
    end

    if factionId ~= "spirit" then return {} end
    local raw = faction.accessories
    if not istable(raw) then return {} end
    local out = {}
    for i = 1, #raw do
        local option = istable(raw[i]) and raw[i] or {}
        local modelPath = string.Trim(tostring(option.model or option.path or ""))
        if modelPath ~= "" then
            out[#out + 1] = {
                name = tostring(option.name or ("Accessory " .. tostring(i))),
                model = modelPath,
            }
        end
    end
    return out
end

function CH:NormalizeSpiritAccessory(factionOrId, value)
    local options = self:GetSpiritAccessoryOptions(factionOrId)
    if #options <= 0 then return 0 end
    local maxIndex = math.max(0, #options)
    return math.Clamp(math.floor(tonumber(value) or 0), 0, maxIndex)
end

function CH:ResolveSpiritAccessoryModel(factionOrId, value)
    local index = self:NormalizeSpiritAccessory(factionOrId, value)
    if index <= 0 then return "" end
    local options = self:GetSpiritAccessoryOptions(factionOrId)
    local entry = options[index]
    if not istable(entry) then return "" end
    return tostring(entry.model or "")
end

function CH:NormalizeSpiritAccessoryTransform(factionOrId, accessoryValue, raw)
    local defaultX = 0
    local defaultY = 0
    local defaultZ = 0
    local defaultSize = 24
    local accessoryIndex = self:NormalizeSpiritAccessory(factionOrId, accessoryValue)
    if accessoryIndex <= 0 then
        return {
            x = defaultX,
            y = defaultY,
            z = defaultZ,
            size = defaultSize,
        }
    end

    raw = parseBodyMarksPayload(raw) or {}
    if not istable(raw) then raw = {} end
    local legacySize = clampBodyMarkNumber(raw.size, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, defaultSize) or defaultSize
    local sizeX = clampBodyMarkNumber(raw.size_x or raw.width, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, legacySize) or legacySize
    local sizeY = clampBodyMarkNumber(raw.size_y or raw.height, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, legacySize) or legacySize
    local sizeAverage = math.Clamp(math.floor((sizeX + sizeY) * 0.5), CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX)
    return {
        x = clampBodyMarkNumber(raw.x, CH.BODY_MARK_OFFSET_MIN, CH.BODY_MARK_OFFSET_MAX, defaultX) or defaultX,
        y = clampBodyMarkNumber(raw.y, CH.BODY_MARK_OFFSET_MIN, CH.BODY_MARK_OFFSET_MAX, defaultY) or defaultY,
        z = clampBodyMarkNumber(raw.z, CH.BODY_MARK_DEPTH_MIN, CH.BODY_MARK_DEPTH_MAX, defaultZ) or defaultZ,
        size = clampBodyMarkNumber(raw.size, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, sizeAverage) or sizeAverage,
    }
end

function CH:NormalizeBodyMarksData(factionOrId, raw)
    local defaultX = 0
    local defaultY = 0
    local defaultRotate = 0
    local defaultOpacity = 100
    local defaultSize = 24
    local categories = self:GetBodyMarkCategories(factionOrId)
    if #categories <= 0 then return {} end
    raw = parseBodyMarksPayload(raw) or {}
    local out = {}
    for index, category in ipairs(categories) do
        local entry = raw[category.id]
        if entry == nil then entry = raw[index] end
        if isnumber(entry) then
            entry = {
                style = entry
            }
        end

        entry = istable(entry) and entry or {}
        local legacySize = clampBodyMarkNumber(entry.size, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, defaultSize) or defaultSize
        local sizeX = clampBodyMarkNumber(entry.size_x or entry.width, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, legacySize) or legacySize
        local sizeY = clampBodyMarkNumber(entry.size_y or entry.height, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, legacySize) or legacySize
        local sizeAverage = math.Clamp(math.floor((sizeX + sizeY) * 0.5), CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX)
        local colorStr = ""
        local rawColor = entry.color
        if IsColor(rawColor) then
            colorStr = string.format("%d,%d,%d", math.Clamp(math.floor(tonumber(rawColor.r) or 255), 0, 255), math.Clamp(math.floor(tonumber(rawColor.g) or 255), 0, 255), math.Clamp(math.floor(tonumber(rawColor.b) or 255), 0, 255))
        elseif istable(rawColor) and rawColor.r and rawColor.g and rawColor.b then
            colorStr = string.format("%d,%d,%d", math.Clamp(math.floor(tonumber(rawColor.r) or 255), 0, 255), math.Clamp(math.floor(tonumber(rawColor.g) or 255), 0, 255), math.Clamp(math.floor(tonumber(rawColor.b) or 255), 0, 255))
        elseif isstring(rawColor) and rawColor ~= "" then
            local r, g, b = string.match(rawColor, "^(%d+),(%d+),(%d+)$")
            if r then colorStr = r .. "," .. g .. "," .. b end
        end

        out[category.id] = {
            style = clampBodyMarkNumber(entry.style or entry.index or entry.option, 1, math.max(1, #category.options), category.default) or category.default,
            x = clampBodyMarkNumber(entry.x, CH.BODY_MARK_OFFSET_MIN, CH.BODY_MARK_OFFSET_MAX, defaultX) or defaultX,
            y = clampBodyMarkNumber(entry.y, CH.BODY_MARK_OFFSET_MIN, CH.BODY_MARK_OFFSET_MAX, defaultY) or defaultY,
            rotate = clampBodyMarkNumber(entry.rotate, 0, 360, defaultRotate) or defaultRotate,
            opacity = clampBodyMarkNumber(entry.opacity, 0, 100, defaultOpacity) or defaultOpacity,
            size = clampBodyMarkNumber(entry.size, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, sizeAverage) or sizeAverage,
            size_x = sizeX,
            size_y = sizeY,
            color = colorStr,
        }
    end
    return out
end

function CH:SerializeBodyMarksData(factionOrId, raw)
    local normalized = self:NormalizeBodyMarksData(factionOrId, raw)
    if not istable(normalized) or next(normalized) == nil then return nil end
    return util.TableToJSON(normalized, false)
end

function CH:GetResolvedBodyMarks(factionOrId, raw)
    local defaultX = 0
    local defaultY = 0
    local defaultRotate = 0
    local defaultOpacity = 100
    local defaultSize = 24
    local categories = self:GetBodyMarkCategories(factionOrId)
    if #categories <= 0 then return {} end
    local normalized = self:NormalizeBodyMarksData(factionOrId, raw)
    local out = {}
    for _, category in ipairs(categories) do
        local selection = normalized[category.id] or {}
        local optionIndex = clampBodyMarkNumber(selection.style, 1, math.max(1, #category.options), category.default) or category.default
        local option = category.options[optionIndex]
        local resolvedSizeX = clampBodyMarkNumber(selection.size_x, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, selection.size or defaultSize) or (selection.size or defaultSize)
        local resolvedSizeY = clampBodyMarkNumber(selection.size_y, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, selection.size or defaultSize) or (selection.size or defaultSize)
        local resolvedSize = clampBodyMarkNumber(selection.size, CH.BODY_MARK_SIZE_MIN, CH.BODY_MARK_SIZE_MAX, math.floor((resolvedSizeX + resolvedSizeY) * 0.5)) or math.floor((resolvedSizeX + resolvedSizeY) * 0.5)
        out[category.id] = {
            id = category.id,
            name = category.name,
            material = option and tostring(option.material or "") or "",
            style = optionIndex,
            x = selection.x or defaultX,
            y = selection.y or defaultY,
            rotate = selection.rotate or defaultRotate,
            opacity = selection.opacity or defaultOpacity,
            size = resolvedSize,
            size_x = resolvedSizeX,
            size_y = resolvedSizeY,
            color = tostring(selection.color or ""),
        }
    end
    return out
end

function CH:SerializeResolvedBodyMarks(factionOrId, raw)
    local resolved = self:GetResolvedBodyMarks(factionOrId, raw)
    if not istable(resolved) or next(resolved) == nil then return nil end
    return util.TableToJSON(resolved, false)
end

function CH:ClearAllConfiguredBodyMarkSlots(ent)
    if not IsValid(ent) or not ent.SetSubMaterial then return end
    local modelPath = (ent.GetModel and ent:GetModel()) or ""
    if not (self.HasFaceMaterialControls and self:HasFaceMaterialControls(modelPath)) then return end
    local factions = self:GetConfig("Factions", {})
    if not istable(factions) then return end
    local slots = {}
    for _, factionCfg in pairs(factions) do
        local categories = self:GetBodyMarkCategories(factionCfg)
        for slot in pairs(collectBodyMarkSlots(categories)) do
            slots[slot] = true
        end
    end

    for slot in pairs(slots) do
        ent:SetSubMaterial(slot, "")
    end
end

function CH:ApplyBodyMarksToEntity(ent, factionOrId, raw)
    if not IsValid(ent) or not ent.SetSubMaterial then return end
    local modelPath = (ent.GetModel and ent:GetModel()) or ""
    if not (self.HasFaceMaterialControls and self:HasFaceMaterialControls(modelPath)) then return end
    local categories = self:GetBodyMarkCategories(factionOrId)
    self:ClearAllConfiguredBodyMarkSlots(ent)
    if #categories <= 0 then return end
    local normalized = self:NormalizeBodyMarksData(factionOrId, raw)
    for _, category in ipairs(categories) do
        local selection = normalized[category.id] or {}
        local optionIndex = clampBodyMarkNumber(selection.style, 1, math.max(1, #category.options), category.default) or category.default
        local option = category.options[optionIndex]
        local slot = (option and tonumber(option.slot)) or tonumber(category.slot)
        local material = option and tostring(option.material or "") or ""
        if slot ~= nil and material ~= "" then ent:SetSubMaterial(slot, material) end
    end
end

CH.FaceMaterialModels = CH.FaceMaterialModels or {}
CH.FaceMaterialSlots = CH.FaceMaterialSlots or {}
CH.FaceEyebrowMaterials = CH.FaceEyebrowMaterials or {}
local function buildFaceEyeMaterials(baseList)
    local out = {}
    local seen = {}
    local function add(path)
        path = string.Trim(string.lower(tostring(path or "")))
        if path == "" then return end
        path = string.gsub(path, "\\", "/")
        path = string.gsub(path, "%.vmt$", "")
        path = string.gsub(path, "%.vtf$", "")
        if string.sub(path, 1, 10) == "materials/" then path = string.sub(path, 11) end
        if seen[path] then return end
        seen[path] = true
        out[#out + 1] = path
    end

    for _, path in ipairs(baseList or {}) do
        add(path)
    end

    if file and file.Find then
        local files = file.Find("materials/verse/head/verse_pupils*.vmt", "GAME")
        if istable(files) and #files > 0 then
            table.sort(files, function(a, b)
                local function sortKey(name)
                    name = string.lower(tostring(name or ""))
                    if name == "verse_pupils.vmt" then return 0, 0, name end
                    local variant = string.match(name, "^verse_pupils(%d+)%.vmt$")
                    if variant then return 1, tonumber(variant) or math.huge, name end
                    return 2, math.huge, name
                end

                local pa, va, na = sortKey(a)
                local pb, vb, nb = sortKey(b)
                if pa ~= pb then return pa < pb end
                if va ~= vb then return va < vb end
                return na < nb
            end)

            for _, fileName in ipairs(files) do
                local matName = string.gsub(string.lower(fileName), "%.vmt$", "")
                add("verse/head/" .. matName)
            end
        end
    end
    return out
end

local function buildDefaultFaceEyeMaterials()
    local out = {"verse/head/verse_pupils"}
    for variant = 2, 55 do
        out[#out + 1] = ("verse/head/verse_pupils%d"):format(variant)
    end
    return out
end

CH.FaceEyeMaterials = buildFaceEyeMaterials(CH.FaceEyeMaterials or buildDefaultFaceEyeMaterials())
CH.FaceDefaultEyeColor = CH.FaceDefaultEyeColor or "255,255,255,255"
CH.FaceDefaultIrisSize = CH.FaceDefaultIrisSize or 100
CH.FaceIrisSizeMin = CH.FaceIrisSizeMin or 60
CH.FaceIrisSizeMax = CH.FaceIrisSizeMax or 140
function CH:HasFaceMaterialControls(mdl)
    local path = normalizeAppearanceModelPath(mdl)
    if path == "" then return false end
    return self.FaceMaterialModels and self.FaceMaterialModels[path] == true or false
end

function CH:GetIrisSizeMin()
    return math.Clamp(math.floor(tonumber(self.FaceIrisSizeMin) or 60), 10, 400)
end

function CH:GetIrisSizeMax()
    local minSize = self:GetIrisSizeMin()
    return math.Clamp(math.floor(tonumber(self.FaceIrisSizeMax) or 140), minSize, 600)
end

function CH:GetDefaultIrisSize()
    local minSize = self:GetIrisSizeMin()
    local maxSize = self:GetIrisSizeMax()
    return math.Clamp(math.floor(tonumber(self.FaceDefaultIrisSize) or 100), minSize, maxSize)
end

function CH:NormalizeIrisSize(value)
    local minSize = self:GetIrisSizeMin()
    local maxSize = self:GetIrisSizeMax()
    local normalized = math.floor(tonumber(value) or self:GetDefaultIrisSize())
    return math.Clamp(normalized, minSize, maxSize)
end

function CH:GetEyebrowStyleCount()
    local materials = self.FaceEyebrowMaterials
    if not istable(materials) or #materials <= 0 then return 1 end
    return #materials
end

function CH:GetEyeStyleCount()
    local materials = self.FaceEyeMaterials
    if not istable(materials) or #materials <= 0 then return 1 end
    return #materials
end

function CH:GetFaceMaterialSlot(mdl, slotName)
    local path = normalizeAppearanceModelPath(mdl)
    if path == "" then return nil end
    slotName = string.lower(tostring(slotName or ""))
    if slotName == "" then return nil end
    local byModel = self.FaceMaterialSlots and self.FaceMaterialSlots[path] or nil
    if not istable(byModel) then return nil end
    local slotIndex = byModel[slotName]
    if slotIndex == nil then return nil end
    if istable(slotIndex) then
        for _, candidate in ipairs(slotIndex) do
            candidate = tonumber(candidate)
            if candidate ~= nil then return math.max(0, math.floor(candidate)) end
        end
        return nil
    end
    return math.max(0, math.floor(tonumber(slotIndex) or 0))
end

function CH:GetEyebrowMaterialPath(style)
    local materials = self.FaceEyebrowMaterials
    if not istable(materials) or #materials <= 0 then return "" end
    local index = math.Clamp(math.floor(tonumber(style) or 1), 1, #materials)
    return tostring(materials[index] or materials[1] or "")
end

function CH:GetEyeMaterialPath(style)
    local materials = self.FaceEyeMaterials
    if not istable(materials) or #materials <= 0 then return "" end
    local index = math.Clamp(math.floor(tonumber(style) or 1), 1, #materials)
    return tostring(materials[index] or materials[1] or "")
end

function CH:GetSkippedBodygroupValues(mdl, groupId)
    local path = normalizeAppearanceModelPath(mdl)
    if path == "" then return nil end
    local byModel = self.AppearanceBodygroupSkips and self.AppearanceBodygroupSkips[path] or nil
    if not istable(byModel) then return nil end
    return byModel[tonumber(groupId) or 0]
end

function CH:GetAllowedBodygroupValues(mdl, groupId, maxValue)
    maxValue = math.max(0, math.floor(tonumber(maxValue) or 0))
    local skipped = self:GetSkippedBodygroupValues(mdl, groupId)
    local allowed = {}
    for value = 0, maxValue do
        if not (istable(skipped) and skipped[value]) then allowed[#allowed + 1] = value end
    end

    if #allowed == 0 then allowed[1] = 0 end
    return allowed
end

function CH:NormalizeBodygroupValue(mdl, groupId, value, maxValue)
    local requested = math.max(0, math.floor(tonumber(value) or 0))
    local allowed = self:GetAllowedBodygroupValues(mdl, groupId, maxValue)
    local fallback = allowed[1] or 0
    for i = 1, #allowed do
        if allowed[i] == requested then return requested end
        if allowed[i] > requested then return allowed[i] end
        fallback = allowed[i]
    end
    return fallback
end

function CH:BodygroupActualToDisplayValue(mdl, groupId, value, maxValue)
    local actual = self:NormalizeBodygroupValue(mdl, groupId, value, maxValue)
    local allowed = self:GetAllowedBodygroupValues(mdl, groupId, maxValue)
    for idx = 1, #allowed do
        if allowed[idx] == actual then return idx - 1 end
    end
    return 0
end

function CH:BodygroupDisplayToActualValue(mdl, groupId, displayValue, maxValue)
    local allowed = self:GetAllowedBodygroupValues(mdl, groupId, maxValue)
    local idx = math.Clamp(math.floor(tonumber(displayValue) or 0) + 1, 1, #allowed)
    return allowed[idx] or 0
end

local function pickGenderEntry(entry, gender)
    if not entry then return nil end
    if isstring(entry) and entry ~= "" then return entry end
    if istable(entry) and #entry > 0 then return entry[math.random(#entry)] end
    if istable(entry) and gender and entry[gender] ~= nil then return pickGenderEntry(entry[gender], nil) end
    return nil
end

local function pickAppearanceEntry(entry, preferredIndex)
    if not entry then return nil end
    if isstring(entry) and entry ~= "" then return entry end
    if istable(entry) and #entry > 0 then
        local count = #entry
        local index = math.Clamp(math.floor(tonumber(preferredIndex) or 1), 1, count)
        return entry[index]
    end
    return nil
end

function CH:GetPreferredAppearanceModel(entry, preferredIndex)
    return pickAppearanceEntry(entry, preferredIndex)
end

function CH:GetFactionGenderData(factionOrId, gender)
    local f = factionOrId
    if isstring(factionOrId) then f = self:GetConfig("Factions", factionOrId) end
    if not istable(f) then return nil end
    gender = tostring(gender or self:ConfigString("DefaultGender", "male"))
    local gmap = istable(f.gender) and f.gender or nil
    local slot = gmap and (gmap[gender] or gmap.male or gmap.female) or nil
    local out = {}
    if istable(slot) then
        out.head = slot.head
        out.body = slot.body
        out.model = slot.model
        out.models = slot.models
    end

    if out.head == nil then out.head = (gender == "female") and (f.head_female or f.head_male) or (f.head_male or f.head_female) end
    if out.body == nil then out.body = (gender == "female") and (f.bodies_female or f.bodies_male) or (f.bodies_male or f.bodies_female) end
    if out.model == nil then out.model = (gender == "female") and (f.model_female or f.model_male) or (f.model_male or f.model_female) end
    if out.models == nil and istable(f.models_by_gender) then out.models = f.models_by_gender[gender] or f.models_by_gender.male or f.models_by_gender.female end
    return out
end

function CH:GetAppearanceData(char, resolvedBodyModel)
    if not istable(char) then return nil end
    local cfg = self:GetConfig()
    local gender = tostring(char.gender or cfg.DefaultGender or "male")
    local factionCfg = (self:FactionsEnabled() and isstring(char.faction) and self:GetConfig("Factions", char.faction)) or nil
    local gdata = (factionCfg and self.GetFactionGenderData) and self:GetFactionGenderData(factionCfg, gender) or nil
    local bodyModel = (isstring(resolvedBodyModel) and resolvedBodyModel ~= "") and resolvedBodyModel or nil
    if not bodyModel then bodyModel = (isstring(char.model) and char.model ~= "") and char.model or nil end
    if not bodyModel and gdata then bodyModel = pickAppearanceEntry(gdata.body, 1) or pickAppearanceEntry(gdata.model, 1) end
    local headType = math.max(1, math.floor(tonumber(char.head_type) or 1))
    local headModel = (gdata and pickAppearanceEntry(gdata.head, headType)) or ""
    local headStyle = math.max(0, math.floor(tonumber(char.head_style) or 0))
    headStyle = self:NormalizeBodygroupValue(headModel, 0, headStyle, 255)
    local skinColor = (tostring(char.faction or "") == "spirit") and tostring(char.skin_color or "") or ""
    local eyebrowStyle = math.Clamp(math.floor(tonumber(char.eyebrow_style) or 1), 1, self:GetEyebrowStyleCount())
    local irisStyle = math.Clamp(math.floor(tonumber(char.iris_style) or 1), 1, self:GetEyeStyleCount())
    local irisSize = self:GetDefaultIrisSize()
    if self.NormalizeIrisSize then
        irisSize = self:NormalizeIrisSize(tonumber(char.iris_size) or irisSize)
    else
        irisSize = math.Clamp(math.floor(tonumber(char.iris_size) or irisSize), 40, 200)
    end

    local eyebrowColor = tostring(char.eyebrow_color or "")
    local eyeColor = tostring(char.eye_color or "")
    local flexTable = self.NormalizeFlexTable and self:NormalizeFlexTable(char.flex) or {}
    local flexJson = self.SerializeFlexTable and self:SerializeFlexTable(flexTable) or ""
    if not isstring(flexJson) then flexJson = "" end
    local rawBodyMarks = char.body_marks
    if (not istable(rawBodyMarks) or next(rawBodyMarks) == nil) and isstring(char.presets_skin) and char.presets_skin ~= "" then
        local preset = util.JSONToTable(char.presets_skin)
        if istable(preset) and preset.body_marks ~= nil then rawBodyMarks = preset.body_marks end
    end
    local bodyMarks = self:NormalizeBodyMarksData(char.faction, rawBodyMarks)
    local spiritAccessory = self:NormalizeSpiritAccessory(char.faction, char.spirit_accessory)
    local spiritAccessoryData = self:NormalizeSpiritAccessoryTransform(char.faction, spiritAccessory, char.spirit_accessory_data)
    return {
        body_model = bodyModel or "",
        head_model = headModel,
        head_type = headType,
        skin_tone = math.max(1, math.floor(tonumber(char.skin_tone) or 1)),
        skin_color = skinColor,
        body_style = math.max(0, math.floor(tonumber(char.body_style) or 0)),
        body_marks = bodyMarks,
        body_marks_json = self:SerializeResolvedBodyMarks(char.faction, bodyMarks) or "",
        head_style = headStyle,
        hair_style = math.max(0, math.floor(tonumber(char.hair_style) or 0)),
        hair_color = tostring(char.hair_color or ""),
        hair_tip_color = tostring(char.hair_tip_color or ""),
        eyebrow_style = eyebrowStyle,
        eyebrow_color = eyebrowColor,
        eyelash_color = tostring(char.eyelash_color or ""),
        iris_style = irisStyle,
        iris_size = irisSize,
        eye_color = eyeColor,
        flex = flexTable,
        flex_json = flexJson,
        spirit_accessory = spiritAccessory,
        spirit_accessory_data = spiritAccessoryData,
    }
end

function CH:ResolveModel(char, job, gender)
    local useGender = self:ConfigBool("GenderModels", false)
    if char and isstring(char.model) and char.model ~= "" then return char.model end
    if self:FactionsEnabled() and char and isstring(char.faction) then
        local f = self:GetConfig("Factions", char.faction)
        if istable(f) then
            local jobId = job and job.id or nil
            local gdata = useGender and self:GetFactionGenderData(f, gender) or nil
            if gdata and istable(gdata.models) and jobId and gdata.models[jobId] ~= nil then
                local m = pickGenderEntry(gdata.models[jobId], nil)
                if m then return m end
            end

            if gdata and gdata.model ~= nil then
                local m = pickGenderEntry(gdata.model, nil)
                if m then return m end
            end

            if istable(f.models) and jobId and f.models[jobId] ~= nil then
                if useGender then
                    local m = pickGenderEntry(f.models[jobId], gender)
                    if m then return m end
                else
                    local raw = f.models[jobId]
                    local m = pickGenderEntry(raw, nil)
                    if m then return m end
                end
            end

            if f.model ~= nil then
                if useGender then
                    local m = pickGenderEntry(f.model, gender)
                    if m then return m end
                else
                    local m = pickGenderEntry(f.model, nil)
                    if m then return m end
                end
            end
        end
    end

    if job and job.model ~= nil then
        if useGender then
            local m = pickGenderEntry(job.model, gender)
            if m then return m end
        else
            local m = pickGenderEntry(job.model, nil)
            if m then return m end
        end
    end
    return nil
end

function CH:GetName(viewerPly, targetPly)
    if not IsValid(targetPly) then return "" end
    if SERVER then
        local targetChar = self.GetSelected and self:GetSelected(targetPly) or nil
        if istable(targetChar) then
            local dn = self:GetDisplayName(targetChar)
            if dn ~= "" then return dn end
        end
        return targetPly:SteamNick()
    end

    if CLIENT and targetPly == LocalPlayer() then
        local selected = CH.Client and CH.Client.selected or nil
        if istable(selected) then
            local ownName = self:GetDisplayName(selected)
            if ownName ~= "" then return ownName end
        end
    end

    if not self:AcquaintancesEnabled() then
        local id = targetPly:CharID()
        if id and CH.Client and CH.Client.knownNames and CH.Client.knownNames[id] then
            local nm = tostring(CH.Client.knownNames[id] or "")
            if nm ~= "" then return nm end
        end
        return targetPly:SteamNick()
    end

    if CLIENT then
        local id = targetPly:CharID()
        if not id then return targetPly:SteamNick() end
        local knownNames = (CH.Client and CH.Client.knownNames) or {}
        local nm = tostring(knownNames[id] or "")
        if nm ~= "" then return nm end
        return self:GetUnknownName()
    end
    return targetPly:SteamNick()
end

local meta = FindMetaTable("Player")
meta._realNick = meta._realNick or meta.Nick
function meta:SteamNick()
    if not IsValid(self) then return "" end
    return meta._realNick(self) or ""
end

function meta:CharID()
    if SERVER then
        local ch = self._Char
        return (istable(ch) and tonumber(ch.id)) or nil
    end

    local id = self:GetPublicInt(CH:ConfigString("VarChar", "VERSE::CharID"), 0)
    return (id > 0) and id or nil
end

function meta:Nick(viewerPly)
    return CH:GetName(viewerPly, self)
end

function meta:Name(viewerPly)
    return CH:GetName(viewerPly, self)
end