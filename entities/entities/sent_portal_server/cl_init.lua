include("shared.lua")

local COL_GLOW    = Color(80,  160, 255)
local COL_LABEL   = Color(220, 230, 255)
local COL_HINT    = Color(255, 255, 255, 210)
local COL_HINT_BG = Color(0,   0,   0,   160)
local HINT_DIST   = 160

-- Réception du signal de connexion envoyé par le serveur
net.Receive("VERSE::Portal::Connect", function()
    local ip   = net.ReadString()
    local pass = net.ReadString()
    if pass ~= "" then
        RunConsoleCommand("password", pass)
    end
    RunConsoleCommand("connect", ip)
end)

function ENT:Initialize()
    self._nextGlow = 0
end

function ENT:Draw()
    self:DrawModel()

    local label = self:GetDestLabel()
    if label == "" then return end

    local font   = Font:GetNamed("Poppins", "SemiBold", 22)
    local pos    = self:GetPos() + Vector(0, 0, 55)
    local eyeAng = LocalPlayer():EyeAngles()
    local ang    = Angle(0, eyeAng.y - 90, 90)

    cam.Start3D2D(pos, ang, 0.14)
        draw.SimpleText(label, font, 0, 0, COL_LABEL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

function ENT:Think()
    local now = CurTime()
    if now < self._nextGlow then return end
    self._nextGlow = now + 0.05

    local dlight = DynamicLight(self:EntIndex())
    if dlight then
        local pulse       = math.sin(now * 2.5) * 0.5 + 0.5
        dlight.pos        = self:GetPos()
        dlight.r          = COL_GLOW.r
        dlight.g          = COL_GLOW.g
        dlight.b          = COL_GLOW.b
        dlight.brightness = 1.5 + pulse * 1.0
        dlight.size       = 160 + pulse * 60
        dlight.decay      = 1000
        dlight.dietime    = now + 0.1
    end
end

hook.Add("HUDPaint", "VERSE::Portal::HUDHint", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ent in ipairs(ents.FindByClass("sent_portal_server")) do
        if not IsValid(ent) then continue end
        if ent:GetPos():DistToSqr(lp:GetPos()) > HINT_DIST * HINT_DIST then continue end

        local label = ent:GetDestLabel()
        local txt   = "Appuyez sur [E] pour rejoindre : " .. (label ~= "" and label or "?")
        local font  = Font:GetNamed("Poppins", "Medium", 16)
        local sw    = ScrW()
        local sh    = ScrH()

        surface.SetFont(font)
        local tw = surface.GetTextSize(txt) or 300
        local px = sw * 0.5 - tw * 0.5 - 12
        local py = sh * 0.72

        draw.RoundedBox(6, px, py, tw + 24, 32, COL_HINT_BG)
        draw.SimpleText(txt, font, sw * 0.5, py + 16, COL_HINT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        break
    end
end)
