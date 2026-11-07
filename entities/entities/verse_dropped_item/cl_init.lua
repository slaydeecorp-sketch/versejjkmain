include("shared.lua")

local BOB_SPEED      = 1.2
local BOB_HEIGHT     = 3
local SPIN_SPEED     = 45
local HOVER_OFFSET   = 15
local BEAM_HEIGHT    = 50
local BEAM_WIDTH     = 2
local GLOW_SIZE      = 50
local ORB_COUNT      = 5
local ORB_RADIUS     = 18
local ORB_SPEED      = 1.5
local LABEL_DIST_SQ  = 360000
local TRANSITION_TIME = 0.6

local matGlow = Material("sprites/light_glow02_add")
local matOrb  = Material("particle/particle_glow_04")

local RARITY_FX = {
    common    = { beam = 0,   glow = 0.4, orbs = false },
    uncommon  = { beam = 0.3, glow = 0.6, orbs = false },
    rare      = { beam = 0.5, glow = 0.8, orbs = true },
    epic      = { beam = 0.7, glow = 1.0, orbs = true },
    legendary = { beam = 1.0, glow = 1.2, orbs = true },
    cursed    = { beam = 1.0, glow = 1.2, orbs = true },
}

function ENT:Initialize()
    self._spawnTime = CurTime()
    self._settled = false
    self._settledTime = 0
    self:SetRenderBounds(Vector(-60, -60, -10), Vector(60, 60, BEAM_HEIGHT + 40))
end

function ENT:Think()
    if not self._settled and self:GetNWBool("Settled", false) then
        self._settled = true
        self._settledTime = CurTime()
    end

    self:SetNextClientThink(CurTime() + 0.1)
    return true
end

function ENT:GetItemColor()
    if self._rarityColor then return self._rarityColor, self._rarityFx end

    local itemId = self:GetItemID()
    if not itemId or itemId == "" then return nil, nil end

    local INV = VERSE and VERSE.Inventory
    if not INV then return nil, nil end

    local rarity = INV:GetItemRarity(itemId)
    local col = INV:GetRarityColor(rarity)
    local fx = RARITY_FX[rarity] or RARITY_FX.common

    self._rarityColor = col
    self._rarityFx = fx
    return col, fx
end

function ENT:Draw()
    local time = CurTime()

    if not self._settled then
        self:DrawModel()
        return
    end

    local transitionFrac = math.Clamp((time - self._settledTime) / TRANSITION_TIME, 0, 1)
    local ease = transitionFrac * (2 - transitionFrac)

    local basePos = self:GetPos()
    local bob = math.sin(time * BOB_SPEED) * BOB_HEIGHT * ease
    local dz = HOVER_OFFSET * ease + bob
    local pos = basePos + Vector(0, 0, dz)

    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), (time * SPIN_SPEED * ease) % 360)

    self:SetRenderOrigin(pos)
    self:SetRenderAngles(ang)
    self:SetupBones()
    self:DrawModel()
    self:SetRenderOrigin()
    self:SetRenderAngles()

    local rc, fx = self:GetItemColor()
    if not rc or not fx then return end

    local r, g, b = rc.r, rc.g, rc.b
    local alpha = ease

    if fx.beam > 0 then
        local bh = BEAM_HEIGHT * fx.beam
        local bAlpha = 20 * fx.beam * alpha
        local bPulse = 1 + math.sin(time * 2) * 0.12
        local bw = BEAM_WIDTH * bPulse
        local bottom = basePos + Vector(0, 0, 2)
        local top = basePos + Vector(0, 0, 2 + bh)

        render.SetMaterial(matGlow)
        render.DrawBeam(bottom, top, bw, 0, 1, Color(r, g, b, bAlpha))
        render.DrawBeam(bottom, top, bw * 4, 0, 1, Color(r, g, b, bAlpha * 0.2))
    end

    local gPulse = 0.7 + math.sin(time * 2.5) * 0.3
    local gs = GLOW_SIZE * fx.glow * gPulse * alpha

    render.SetMaterial(matGlow)
    render.DrawSprite(pos, gs, gs, Color(r, g, b, 40 * alpha))
    render.DrawSprite(pos, gs * 0.25, gs * 0.25, Color(r, g, b, 80 * alpha))

    if fx.orbs then
        render.SetMaterial(matOrb)
        for i = 1, ORB_COUNT do
            local phase = (i / ORB_COUNT) * math.pi * 2
            local t = time * ORB_SPEED + phase
            local ox = math.cos(t) * ORB_RADIUS
            local oy = math.sin(t) * ORB_RADIUS
            local oz = math.sin(t * 1.3 + phase) * 5
            local oPos = pos + Vector(ox, oy, oz)
            local oAlpha = (0.5 + math.sin(t * 2) * 0.5) * alpha
            local oSize = 3 + math.sin(t * 3) * 1.5
            render.DrawSprite(oPos, oSize, oSize, Color(r, g, b, 250 * oAlpha))
        end
    end

    if fx.beam > 0.2 then
        local gndAlpha = 12 * fx.beam * alpha
        local gndSize = 35 * fx.beam
        render.SetMaterial(matGlow)
        render.DrawSprite(basePos + Vector(0, 0, 1), gndSize, gndSize, Color(r, g, b, gndAlpha))
    end

    if ease >= 1 and LocalPlayer():GetPos():DistToSqr(basePos) < LABEL_DIST_SQ then
        self:DrawLabel(pos, rc)
    end
end

function ENT:DrawLabel(floatPos, rc)
    local INV = VERSE and VERSE.Inventory
    local itemId = self:GetItemID()
    local amount = self:GetAmount()

    local name = itemId
    if INV then
        local def = INV:GetItemDef(itemId)
        if def then name = def.name or itemId end
    end

    local text = name
    if amount and amount > 1 then text = text .. " x" .. amount end

    local labelPos = floatPos + Vector(0, 0, 20)
    local ang = (labelPos - EyePos()):Angle()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(labelPos, ang, 0.12)
        local font = "DermaLarge"
        local hintFont = "DermaDefault"
        surface.SetFont(font)
        local tw, th = surface.GetTextSize(text)
        surface.SetFont(hintFont)
        local hw, hh = surface.GetTextSize("[E] Ramasser")

        local px = 14
        local gap = 4
        local totalW = math.max(tw, hw) + px * 2
        local totalH = th + gap + hh + 16
        local bx, by = -totalW * 0.5, -totalH * 0.5

        draw.RoundedBox(6, bx + 2, by + 2, totalW, totalH, Color(0, 0, 0, 80))
        draw.RoundedBox(6, bx, by, totalW, totalH, Color(12, 8, 22, 210))
        draw.RoundedBoxEx(6, bx, by, totalW, 3, Color(rc.r, rc.g, rc.b, 180), true, true, false, false)

        local nameY = by + 8 + th * 0.5
        draw.SimpleText(text, font, 0, nameY, Color(rc.r, rc.g, rc.b, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local hintY = nameY + th * 0.5 + gap + hh * 0.5
        draw.SimpleText("[E] Ramasser", hintFont, 0, hintY, Color(170, 160, 190, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
