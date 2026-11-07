include("shared.lua")

-- ─── Polices ──────────────────────────────────────────────────────────────────

local _fontsReady = false

local function ensureFonts()
    if _fontsReady then return end
    _fontsReady = true
    surface.CreateFont("VMob_Name", {
        font      = "Roboto",
        size      = 48,
        weight    = 700,
        antialias = true,
    })
    surface.CreateFont("VMob_HP", {
        font      = "Roboto",
        size      = 32,
        weight    = 500,
        antialias = true,
    })
end

-- ─── Rendu ────────────────────────────────────────────────────────────────────

function ENT:Draw()
    self:DrawModel()

    if self:GetNWBool("VMobDead", false) then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local myPos = self:GetPos()
    local dist  = ply:GetPos():Distance(myPos)
    if dist > 1500 then return end

    ensureFonts()

    local hp    = self:GetNWFloat("VMobHP",    self.MobMaxHP)
    local maxHP = self:GetNWFloat("VMobMaxHP", self.MobMaxHP)
    local name  = self:GetNWString("VMobName", self.MobName)
    local pct   = math.Clamp(hp / math.max(1, maxHP), 0, 1)

    -- Position du panel : au-dessus de la tête
    local headPos = myPos + Vector(0, 0, self:OBBMaxs().z + 20)

    -- Billboard toujours face à la caméra (méthode EyeAngles standard)
    local ang = ply:EyeAngles()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)

    -- Echelle adaptée à la distance
    local scale = math.Clamp(dist * 0.0009, 0.18, 0.45)

    local barW =  260
    local barH =   22
    local barX = -barW / 2
    local barY =    0

    cam.Start3D2D(headPos, ang, scale)

        -- ── Nom ──────────────────────────────────────────────────────────────
        -- Ombre
        draw.SimpleText(name, "VMob_Name", 1, -50, Color(0, 0, 0, 180),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        -- Texte
        draw.SimpleText(name, "VMob_Name", 0, -50, Color(255, 255, 255, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- ── Barre de vie ──────────────────────────────────────────────────────
        -- Fond
        draw.RoundedBox(4, barX,     barY,     barW,          barH, Color(20, 20, 20, 210))
        -- Remplissage couleur
        if pct > 0 then
            local r = pct > 0.5 and math.floor((1 - pct) * 2 * 255) or 255
            local g = pct > 0.5 and 210                              or math.floor(pct * 2 * 210)
            draw.RoundedBox(4, barX, barY, barW * pct, barH, Color(r, g, 30, 240))
        end
        -- Contour
        draw.RoundedBox(4, barX - 1, barY - 1, barW + 2, barH + 2, Color(0, 0, 0, 0))
        surface.SetDrawColor(60, 60, 60, 200)
        surface.DrawOutlinedRect(barX, barY, barW, barH, 1)

        -- Valeur HP
        draw.SimpleText(math.ceil(hp) .. " / " .. maxHP, "VMob_HP", 0, barY + barH * 0.5,
            Color(255, 255, 255, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    cam.End3D2D()
end
