include("shared.lua")

ENT.LabelBgColor = Color(24, 14, 30, 230)
ENT.LabelAccentColor = Color(200, 120, 220, 230)
ENT.LabelTitleColor = Color(230, 180, 240, 240)
ENT.LabelHintColor = Color(210, 180, 220, 170)

function ENT:Draw()
    self:DrawModel()
end
