VERSE.Freecam = VERSE.Freecam or {}
local F = VERSE.Freecam

local WEAPON_CLASS = "verse_freecam"
local HEAD_BONE = "ValveBiped.Bip01_Head1"

local CFG = {
    FOV = 75,
    DIST_DEFAULT = 100,
    DIST_MIN = 10,
    DIST_MAX = 250,
    PITCH_MIN = -89,
    PITCH_MAX = 89,
    PAD = 4,
}

local HULL_MIN = Vector(-CFG.PAD, -CFG.PAD, -CFG.PAD)
local HULL_MAX = Vector(CFG.PAD, CFG.PAD, CFG.PAD)

F.orbit = F.orbit or nil
F.frozenAng = F.frozenAng or nil
F.dist = F.dist or CFG.DIST_DEFAULT

local function isActive()
    return F.orbit ~= nil
end

local function isHolding(ply)
    if not IsValid(ply) then return false end
    local wep = ply:GetActiveWeapon()
    return IsValid(wep) and wep:GetClass() == WEAPON_CLASS
end

local function begin(ply)
    local eye = ply:EyeAngles()
    F.orbit = Angle(eye.p, eye.y, 0)
    F.frozenAng = Angle(eye.p, eye.y, 0)
    F.dist = CFG.DIST_DEFAULT
end

local function headOrigin(ply)
    local idx = ply:LookupBone(HEAD_BONE)
    if idx then
        local pos = ply:GetBonePosition(idx)
        if pos and pos ~= vector_origin then return pos end
    end
    return ply:EyePos()
end

local function sens()
    local cv = GetConVar("sensitivity")
    return (cv and cv:GetFloat() or 3) / 30
end

VERSE.Hook.AddNS("Freecam", "CreateMove", "VERSE::CreateMove::Freecam", function(cmd)
    local ply = LocalPlayer()
    if not isHolding(ply) then
        F.orbit, F.frozenAng = nil, nil
        return
    end

    if not isActive() then begin(ply) end

    local mx, my = cmd:GetMouseX(), cmd:GetMouseY()
    local s = sens()

    if cmd:KeyDown(IN_ATTACK) then
        F.orbit.p = math.Clamp(F.orbit.p + my * s, CFG.PITCH_MIN, CFG.PITCH_MAX)
        F.orbit.y = F.orbit.y - mx * s
    end

    if cmd:KeyDown(IN_ATTACK2) then
        F.dist = math.Clamp(F.dist + my * s, CFG.DIST_MIN, CFG.DIST_MAX)
    end

    cmd:SetViewAngles(F.frozenAng)
    cmd:SetMouseX(0)
    cmd:SetMouseY(0)
end)

VERSE.Hook.AddNS("Freecam", "CalcView", "VERSE::CalcView::Freecam", function(ply)
    if not (isActive() and isHolding(ply)) then return end

    local origin = headOrigin(ply)
    local desired = origin - F.orbit:Forward() * F.dist
    local tr = util.TraceHull({
        start = origin,
        endpos = desired,
        mins = HULL_MIN,
        maxs = HULL_MAX,
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })

    return {
        origin = tr.Hit and tr.HitPos or desired,
        angles = F.orbit,
        fov = CFG.FOV,
        drawviewer = true,
    }
end)

VERSE.Hook.AddNS("Freecam", "ShouldDrawLocalPlayer", "VERSE::ShouldDrawLocalPlayer::Freecam", function(ply)
    if ply == LocalPlayer() and isActive() and isHolding(ply) then
        return true
    end
end)
