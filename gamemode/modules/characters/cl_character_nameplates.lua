local CH = VERSE.Characters
local Font = VERSE.Fonts
local NAMEPLATE_MAX_DIST = 300
local NAMEPLATE_FADE_NEAR = 200
local NAMEPLATE_Z_OFFSET = 15
local STRANGER_TEXT = "????"
local SHOW_LOCAL_NAMEPLATE = true

-- Cache de police et de couleurs pour éviter des allocations à chaque frame.
local _npFont = nil
local _colStranger = Color(180, 180, 200, 255)
local _colKnown    = Color(255, 255, 255, 255)
local _colOutline  = Color(0,   0,   0,   255)

-- Cache de bone id par joueur : { [entIndex] = { model=..., boneId=... } }
local _headBoneCache = {}

-- Cache de la liste des joueurs (évite player.GetAll() dans le hook de rendu)
local _playerCache = {}
hook.Add("PlayerInitialSpawn", "VERSE::Nameplates::CacheAdd", function(ply)
    _playerCache[ply] = true
end)
hook.Add("PlayerDisconnected", "VERSE::Nameplates::CacheRemove", function(ply)
    _playerCache[ply] = nil
end)

local function getCachedHeadBoneId(ply)
    local idx   = ply:EntIndex()
    local model = ply:GetModel()
    local cached = _headBoneCache[idx]
    if cached and cached.model == model then return cached.boneId end
    local bid = ply:LookupBone("ValveBiped.Bip01_Head1")
    _headBoneCache[idx] = { model = model, boneId = bid or false }
    return bid or false
end
CH.Introduce = CH.Introduce or {}
local API = CH.Introduce
API.StrangerText = STRANGER_TEXT
function API.GetCharId(ply)
    if not IsValid(ply) or not ply.GetPublicInt then return 0 end
    local key = CH:ConfigString("VarChar", "VERSE::CharID")
    return math.max(0, tonumber(ply:GetPublicInt(key, 0)) or 0)
end

function API.GetKnownNames()
    return (CH.Client and CH.Client.knownNames) or {}
end

function API.GetKnownName(charId)
    charId = tonumber(charId) or 0
    if charId <= 0 then return nil end
    local known = API.GetKnownNames()
    local name = known[charId]
    if name and name ~= "" then return name end
    return nil
end

function API.KnowsChar(charId)
    return API.GetKnownName(charId) ~= nil
end

function API.KnowsPlayer(ply)
    return API.KnowsChar(API.GetCharId(ply))
end

function API.IsStranger(ply)
    local charId = API.GetCharId(ply)
    if charId <= 0 then return false end
    if ply == LocalPlayer() then return false end
    return not API.KnowsChar(charId)
end

function API.GetDisplayName(ply, strangerOverride)
    local charId = API.GetCharId(ply)
    if charId <= 0 then return nil end
    if ply == LocalPlayer() then
        local sel = CH.Client and CH.Client.selected
        if istable(sel) then
            if sel.first_name and sel.first_name ~= "" then return sel.first_name end
            if sel.name and sel.name ~= "" then return sel.name end
        end
        return strangerOverride or STRANGER_TEXT
    end

    local name = API.GetKnownName(charId)
    if name then return name end
    return strangerOverride or STRANGER_TEXT
end

function API.GetFirstName(ply)
    local display = API.GetDisplayName(ply, "")
    if not display or display == "" then return nil end
    local first = string.match(display, "^(%S+)")
    return first or display
end

function API.FindNearestPlayer(maxDist, dotThreshold)
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    maxDist = maxDist or 300
    dotThreshold = dotThreshold or 0.92
    local tr = lp:GetEyeTrace()
    if tr and IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity ~= lp and (lp:GetPos():Distance(tr.Entity:GetPos()) <= maxDist) then return tr.Entity end
    local bestPly, bestDot = nil, dotThreshold
    local eye = lp:EyePos()
    local fwd = lp:GetAimVector()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply ~= lp and ply:Alive() then
            local dir = ply:GetPos() - eye
            local dist = dir:Length()
            if dist > 4 and dist < maxDist then
                dir:Normalize()
                local dot = dir:Dot(fwd)
                if dot > bestDot then
                    bestDot = dot
                    bestPly = ply
                end
            end
        end
    end
    return bestPly
end

function API.IntroduceToLookAt(maxDist)
    local target = API.FindNearestPlayer(maxDist or 300)
    if not IsValid(target) then return nil, "no_target" end
    if isfunction(CH.RequestIntroduce) then CH:RequestIntroduce(target) end
    return target
end

function API.IntroduceTo(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false, "bad_target" end
    if isfunction(CH.RequestIntroduce) then CH:RequestIntroduce(ply) end
    return true
end

local function resolveCharId(ply)
    return API.GetCharId(ply)
end

local function resolveNameplateText(ply)
    local charId = resolveCharId(ply)
    if charId <= 0 then return nil end
    local lp = LocalPlayer()
    if ply == lp then
        local sel = CH.Client and CH.Client.selected
        if istable(sel) and sel.first_name and sel.first_name ~= "" then return sel.first_name end
        if istable(sel) and sel.name and sel.name ~= "" then return sel.name end
        return nil
    end

    local known = CH.Client and CH.Client.knownNames
    if istable(known) then
        local name = known[charId]
        if name and name ~= "" then return name end
    end
    return STRANGER_TEXT
end

local function getHeadWorldPos(ply)
    if not IsValid(ply) then return nil end
    -- LookupBone mis en cache par joueur+modèle pour éviter un appel à chaque frame.
    local headBone = getCachedHeadBoneId(ply)
    if headBone then
        local mat = ply:GetBoneMatrix(headBone)
        if mat then
            local pos = mat:GetTranslation()
            return pos + Vector(0, 0, NAMEPLATE_Z_OFFSET)
        end
    end

    local obb = ply:OBBMaxs()
    return ply:GetPos() + Vector(0, 0, (obb and obb.z or 72) + NAMEPLATE_Z_OFFSET)
end

VERSE.Hook.AddNS("Characters", "PostDrawTranslucentRenderables", "VERSE::PostDrawTranslucentRenderables::CharacterNameplates", function(_, _, skybox)
    if skybox then return end
    if not CH:AcquaintancesEnabled() then return end
    if VERSE.Cinematic and VERSE.Cinematic:IsHUDHidden() then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    -- Initialisation unique de la police (évite Font:GetNamed à chaque frame).
    if not _npFont then _npFont = Font:GetNamed("Poppins", "SemiBold", 36) end
    local viewPos = EyePos()
    local maxSqr = NAMEPLATE_MAX_DIST * NAMEPLATE_MAX_DIST
    local fadeSqr = NAMEPLATE_FADE_NEAR * NAMEPLATE_FADE_NEAR
    cam.IgnoreZ(true)
    -- On itère player.GetAll() (fiable) plutôt que _playerCache, qui dependait de
    -- PlayerInitialSpawn cote client : ce cache restait vide apres un hot-reload du
    -- Lua client ou pour les joueurs deja presents → plus aucun nom affiche.
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive()
        and not ply:GetNWBool("VERSE_StaffMode", false)
        and (SHOW_LOCAL_NAMEPLATE or ply ~= lp) then
            local plyPos = ply:GetPos()
            local distSqr = viewPos:DistToSqr(plyPos)
            if distSqr <= maxSqr then
                local text = resolveNameplateText(ply)
                if text then
                    local headPos = getHeadWorldPos(ply)
                    if headPos then
                        local alpha = 255
                        if distSqr > fadeSqr then
                            local t = (distSqr - fadeSqr) / (maxSqr - fadeSqr)
                            alpha = math.floor(math.Clamp(1 - t, 0, 1) * 255)
                        end

                        if alpha > 2 then
                            local ang = (headPos - viewPos):Angle()
                            local dist = math.sqrt(distSqr)
                            local scale = math.Clamp(0.09 + dist / 4200, 0.09, 0.22)
                            cam.Start3D2D(headPos, Angle(0, ang.y - 90, 90), scale)
                            -- Réutilisation des objets Color en mutant uniquement .a
                            -- → zéro allocation par frame.
                            local col = text == STRANGER_TEXT and _colStranger or _colKnown
                            col.a = alpha
                            _colOutline.a = alpha
                            draw.SimpleTextOutlined(text, _npFont, 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, _colOutline)
                            cam.End3D2D()
                        end
                    end
                end
            end
        end
    end

    cam.IgnoreZ(false)
end)

VERSE.Commands.Add("verse_introduce_self", function()
    if not CH:AcquaintancesEnabled() then
        LocalPlayer():Notify("Le système de connaissances est désactivé.", NOTIFY_ERROR, 3)
        return
    end

    local target = API.FindNearestPlayer(300)
    if not IsValid(target) then
        LocalPlayer():Notify("Personne à présenter (regardez un joueur à moins de 3m).", NOTIFY_ERROR, 4)
        return
    end

    CH:RequestIntroduce(target)
    LocalPlayer():Notify("Vous vous êtes présenté. Votre nom lui est désormais révélé.", NOTIFY_HINT, 3)
end, nil, "client")