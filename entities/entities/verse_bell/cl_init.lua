include("shared.lua")

function ENT:Initialize()
    self:SetRenderBounds(Vector(-50, -50, -10), Vector(50, 50, 100))
end

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local rangeSqr = self._rangeSqr
    if not rangeSqr then
        local r = (VERSE and VERSE.Bell and VERSE.Bell.Config and VERSE.Bell.Config.UseRange) or 200
        rangeSqr = r * r
        self._rangeSqr = rangeSqr
    end
    if lp:GetPos():DistToSqr(self:GetPos()) > rangeSqr then return end

    local pos = self:GetPos() + Vector(0, 0, 60)
    local ang = (pos - EyePos()):Angle()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.25)
        local hintFont = (VERSE and VERSE.Fonts and VERSE.Fonts:GetNamed("Poppins", "Bold", 32)) or "DermaLarge"
        local hint = "[E] Interagir"

        surface.SetFont(hintFont)
        local hw, hh = surface.GetTextSize(hint)

        local px = 8
        local totalW = hw + px * 2
        local totalH = hh + 4
        local bx, by = -totalW * 0.5, -totalH * 0.5

        draw.RoundedBox(6, bx, by, totalW, totalH, Color(0, 0, 0, 160))

        draw.SimpleText(hint, hintFont, 0, 0, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
