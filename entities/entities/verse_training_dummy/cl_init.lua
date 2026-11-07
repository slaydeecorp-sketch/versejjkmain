include("shared.lua")

-- ─── Polices ──────────────────────────────────────────────────────────────────

local _fontsReady = false

local function ensureFonts()
    if _fontsReady then return end
    _fontsReady = true
    surface.CreateFont("VDummy_Name", {
        font      = "Poppins",
        size      = 44,
        weight    = 700,
        antialias = true,
        shadow    = true,
    })
end

-- ─── Rendu ────────────────────────────────────────────────────────────────────

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local myPos = self:GetPos()
    local dist  = ply:GetPos():Distance(myPos)
    if dist > 1200 then return end

    ensureFonts()

    local name = self:GetNWString("VDummyName", self.DummyName)

    -- Position au-dessus du modèle
    local headPos = myPos + Vector(0, 0, self:OBBMaxs().z + 24)

    -- Billboard toujours face à la caméra (méthode EyeAngles standard)
    local ang = ply:EyeAngles()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)

    local scale = math.Clamp(dist * 0.0009, 0.18, 0.42)

    cam.Start3D2D(headPos, ang, scale)

        -- Ombre
        draw.SimpleText(name, "VDummy_Name", 1, 1,  Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        -- Texte principal (couleur dorée / sable — thème médiéval)
        draw.SimpleText(name, "VDummy_Name", 0, 0, Color(255, 210, 100, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    cam.End3D2D()
end
