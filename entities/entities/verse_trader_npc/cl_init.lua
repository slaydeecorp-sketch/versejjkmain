include("shared.lua")

local LABEL_DIST_SQ = 360000

function ENT:Initialize()
    self:SetRenderBounds(Vector(-50, -50, -10), Vector(50, 50, 100))
end

function ENT:Draw()
    self:DrawModel()
end
