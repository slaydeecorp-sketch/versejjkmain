include("shared.lua")
local Font = VERSE.Fonts
local LABEL_DIST_SQ = 360000
local COL_BG_SHADOW = Color(0, 0, 0, 80)

ENT.LabelBgColor = Color(16, 16, 20, 220)
ENT.LabelAccentColor = Color(180, 180, 200, 230)
ENT.LabelTitleColor = Color(220, 220, 230, 240)
ENT.LabelHintColor = Color(200, 200, 210, 170)

function ENT:Initialize()
    self:SetRenderBounds(Vector(-50, -50, -10), Vector(50, 50, 100))
end

function ENT:Draw()
    self:DrawModel()
    if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > LABEL_DIST_SQ then return end
    self:DrawLabel()
end

function ENT:DrawLabel()
    local name = self:GetNPCName() or self.DefaultNPCName or "NPC"
    local hintText = self.HintText or "[E] Interagir"
    local pos = self:GetPos() + Vector(0, 0, 80)
    local ang = (pos - EyePos()):Angle()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    local nameFont = Font:GetNamed("Poppins", "Bold", 26)
    local hintFont = Font:GetNamed("Poppins", "Medium", 18)

    cam.Start3D2D(pos, ang, 0.12)
        local tw, th = VERSE.GetTextSize(name, nameFont)
        local hw, hh = VERSE.GetTextSize(hintText, hintFont)
        local px, gap = 14, 4
        local totalW = math.max(tw, hw) + px * 2
        local totalH = th + gap + hh + 16
        local bx, by = -totalW * 0.5, -totalH * 0.5

        RNDX().Rect(bx + 2, by + 2, totalW, totalH):Rad(6):Color(COL_BG_SHADOW):Draw()
        RNDX().Rect(bx, by, totalW, totalH):Rad(6):Color(self.LabelBgColor):Draw()
        RNDX().Rect(bx, by, totalW, 3):Rad(2):Color(self.LabelAccentColor):Draw()

        local nameY = by + 8 + th * 0.5
        draw.SimpleText(name, nameFont, 0, nameY, self.LabelTitleColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local hintY = nameY + th * 0.5 + gap + hh * 0.5
        draw.SimpleText(hintText, hintFont, 0, hintY, self.LabelHintColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
