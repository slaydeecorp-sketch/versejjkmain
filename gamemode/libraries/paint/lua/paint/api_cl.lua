local api = {}
local paint = paint

local OVERRIDE_SURFACE = false
local OVERRIDE_DRAW = false
local OVERRIDE_CIRCLES = false

do
	local getPanelPaintState = surface.GetPanelPaintState
	local getAlphaMultiplier = surface.GetAlphaMultiplier
	local getTextureNameById = surface.GetTextureNameByID
	local surfaceGetDrawColor = surface.GetDrawColor
	local getDrawColor = function()
		local color = surfaceGetDrawColor()

		color.a = color.a * getAlphaMultiplier()

		return color
	end

	local pushScissorRect = paint.pushScissorRect
	local popScissorRect = paint.popScissorRect

	local surface = {}

	local material = Material

	local vguiWhite = material('vgui/white')
	local renderSetMaterial = render.SetMaterial

	local getMaterial

	if OVERRIDE_SURFACE then

		local currentMaterial

		local oldSetMaterial = _G.surface.OldSetMaterial or _G.surface.SetMaterial
		local oldSetTexture = _G.surface.OldSetTexture or _G.surface.SetTexture

		function surface.SetMaterial(mat)
			currentMaterial = mat
			oldSetMaterial(mat)
		end

		function surface.GetMaterial()
			return currentMaterial or vguiWhite
		end

		function surface.SetTexture(texId)
			currentMaterial = material(getTextureNameById(texId))
			oldSetTexture(texId)
		end

		getMaterial = surface.GetMaterial
		surface.OldSetMaterial = oldSetMaterial
		surface.OldSetTexture = oldSetTexture
	else
		local currentMaterial

		function surface.SetMaterial(mat)
			currentMaterial = mat
		end

		function surface.GetMaterial()
			return currentMaterial or vguiWhite
		end

		getMaterial = surface.GetMaterial
	end

	do
		local drawRect = paint.rects.drawRect

		function surface.DrawRect( x, y, w, h )
			local tab = getPanelPaintState()

			if tab.scissor_enabled then
				pushScissorRect(tab.scissor_left, tab.scissor_top, tab.scissor_right, tab.scissor_bottom)
			end
			drawRect(x + tab.translate_x, y + tab.translate_y, w, h, getDrawColor() )

			if tab.scissor_enabled then
				popScissorRect()
			end
		end

		function surface.DrawTexturedRect(x, y, w, h)
			local tab = getPanelPaintState()

			if tab.scissor_enabled then
				pushScissorRect(tab.scissor_left, tab.scissor_top, tab.scissor_right, tab.scissor_bottom)
			end

			drawRect(x + tab.translate_x, y + tab.translate_y, w, h, getDrawColor(), getMaterial())

			if tab.scissor_enabled then
				popScissorRect()
			end
		end

		function surface.DrawTexturedRectUV(x, y, w, h, u1, v1, u2, v2)
			local tab = getPanelPaintState()

			if tab.scissor_enabled then
				pushScissorRect(tab.scissor_left, tab.scissor_top, tab.scissor_right, tab.scissor_bottom)
			end

			drawRect(x + tab.translate_x, y + tab.translate_y, w, h, getDrawColor(), getMaterial(), u1, v1, u2, v2)

			if tab.scissor_enabled then
				popScissorRect()
			end
		end

		local drawOutline = paint.outlines.drawOutline

		function surface.DrawOutlinedRect(x, y, w, h, thickness)
			thickness = thickness or 1

			local tab = getPanelPaintState()

			if tab.scissor_enabled then
				pushScissorRect(tab.scissor_left, tab.scissor_top, tab.scissor_right, tab.scissor_bottom)
			end

			drawOutline(0, x + tab.translate_x, y + tab.translate_y, w, h, getDrawColor(), getMaterial(), thickness)

			if tab.scissor_enabled then
				popScissorRect()
			end
		end
	end

	do
		local meshBegin = mesh.Begin
		local meshEnd = mesh.End
		local meshPosition = mesh.Position
		local meshColor = mesh.Color
		local meshTexCoord = mesh.TexCoord
		local meshAdvanceVertex = mesh.AdvanceVertex

		local PRIMITIVE_POLYGON = MATERIAL_POLYGON

		function surface.DrawPoly(vertices)
			local tab = getPanelPaintState()

			if tab.scissor_enabled then
				pushScissorRect(tab.scissor_left, tab.scissor_top, tab.scissor_right, tab.scissor_bottom)
			end

			local len = #vertices

			renderSetMaterial(getMaterial())

			local color = getDrawColor()

			local r, g, b, a = color.r, color.g, color.b, color.a

			meshBegin(PRIMITIVE_POLYGON, len)
				for i = 1, len do
					local v = vertices[i]

					meshPosition(v.x, v.y, 0)
					meshColor(r, g, b, a)

					if v.u then
						meshTexCoord(0, v.u, v.v)
					end

					meshAdvanceVertex()
				end
			meshEnd()

			if tab.scissor_enabled then
				popScissorRect()
			end
		end
	end

	do
		local drawLine = paint.lines.drawLine
		function surface.DrawLine(x, y, endX, endY)
			local tab = getPanelPaintState()

			if tab.scissor_enabled then
				pushScissorRect(tab.scissor_left, tab.scissor_top, tab.scissor_right, tab.scissor_bottom)
			end

			local color = getDrawColor()
			drawLine(x, y, endX, endY, color, color)

			if tab.scissor_enabled then
				popScissorRect()
			end
		end
	end

	if OVERRIDE_SURFACE then
		local originalSurface = _G.surface

		for k, v in pairs(surface) do
			originalSurface[k] = v
		end
	end

	api.surface = surface
end

do
	local getPanelPaintState = surface.GetPanelPaintState
	local pushScissorRect = paint.pushScissorRect
	local popScissorRect = paint.popScissorRect

	local draw = {}

	local drawSimpleRoundedBox = paint.roundedBoxes.drawSimpleRoundedBox
	local drawSimpleRoundedBoxEx = paint.roundedBoxes.drawSimpleRoundedBoxEx

	function draw.RoundedBox(radius, x, y, w, h, colors)
		local tab = getPanelPaintState()

		if tab.scissor_enabled then
			pushScissorRect(tab.scissor_left, tab.scissor_top, tab.scissor_right, tab.scissor_bottom)
		end

		drawSimpleRoundedBox(radius, x, y, w, h, colors)

		if tab.scissor_enabled then
			popScissorRect()
		end
	end

	function draw.RoundedBoxEx(radius, x, y, w, h, colors, topLeft, topRight, bottomLeft, bottomRight)
		local tab = getPanelPaintState()

		if tab.scissor_enabled then
			pushScissorRect(tab.scissor_left, tab.scissor_top, tab.scissor_right, tab.scissor_bottom)
		end

		drawSimpleRoundedBoxEx(radius, x, y, w, h, colors, topLeft, topRight, bottomRight, bottomLeft)

		if tab.scissor_enabled then
			popScissorRect()
		end
	end

	if OVERRIDE_DRAW then
		local originalDraw = _G.draw
		for k, v in pairs(draw) do
			originalDraw[k] = v
		end
	end

	api.draw = draw
end

do
	local new = {}

	for k, v in pairs(new) do
		paint[k] = v
	end

	api.new = new
end

do
	local circles = {}

	local CIRCLE_FILLED = 0
	local CIRCLE_OUTLINED = 1
	local CIRCLE_BLURRED = 2
	local circleClass = {}

	do
		circleClass.__index = circleClass
		circleClass.m_X = 0
		circleClass.m_Y = 0
		circleClass.m_Dirty = false
		circleClass.m_Radius = 0
		circleClass.m_Rotation = 0
		circleClass.m_Color = color_white
		circleClass.m_Material = Material('vgui/white')
		circleClass.m_Type = CIRCLE_FILLED
		circleClass.m_StartAngle = 0
		circleClass.m_EndAngle = 360
		circleClass.m_Distance = 10
		circleClass.m_VertexCount = 24

		local tonumber = tonumber

		function circleClass:SetPos(x, y)
			x = tonumber(x) or self.m_X
			y = tonumber(y) or self.m_Y

			self.m_X = x
			self.m_Y = y
		end

		function circleClass:SetAngles(s, e)
			s = tonumber(s) or self.m_StartAngle
			e = tonumber(e) or self.m_EndAngle

			self.m_StartAngle = s
			self.m_EndAngle = e
		end

		function circleClass:GetPos()
			return self.m_X, self.m_Y
		end

		function circleClass:Rotate(rotation)
			self.m_Rotation = self.m_Rotation + (tonumber(rotation) or 0)
		end

		function circleClass:Translate(x, y)
			self.m_X = self.m_X + x
			self.m_Y = self.m_Y + y
		end

		do

			local drawCircle = paint.circles.drawCircle
			local drawOutlinedCircle = paint.circles.drawOutline

			local drawRoundedBox = paint.roundedBoxes.roundedBox
			local getBlurMaterial = paint.blur.getBlurMaterial

			local getPanelPaintState = surface.GetPanelPaintState

			local scrW, scrH = ScrW, ScrH

			local setScissorRect = render.SetScissorRect

			function circleClass:__call()
				local state = getPanelPaintState()

				if state.scissor_enabled then
					setScissorRect(state.scissor_left, state.scissor_top, state.scissor_right, state.scissor_bottom, true)
				end

				if self.m_Type == CIRCLE_OUTLINED then
					drawOutlinedCircle(self.m_X, self.m_Y, self.m_Radius, self.m_Radius, self.m_Color, self.m_OutlineWidth, self.m_VertexCount, self.m_StartAngle + self.m_Rotation, self.m_EndAngle + self.m_Rotation, self.m_Material, 0, 1, 2)
				elseif self.m_Type == CIRCLE_BLURRED then

					local material = getBlurMaterial('paintCircles', 0)
					local x, y = self.m_X - self.m_Radius / 2 + state.translate_x, self.m_Y - self.m_Radius / 2 + state.translate_y

					drawRoundedBox(self.m_Radius / 2, x, y, self.m_Radius, self.m_Radius, self.m_Color, material, x / scrW(), y / scrH(), (x+self.m_Radius) / scrW(), (y+self.m_Radius) / scrH() )
				else
					drawCircle(self.m_X + state.translate_x, self.m_Y + state.translate_y, self.m_Radius, self.m_Radius, self.m_Color, self.m_VertexCount, self.m_StartAngle + self.m_Rotation, self.m_EndAngle + self.m_Rotation, self.m_Material)
				end

				if state.scissor_enabled then
					setScissorRect(0, 0, 0, 0, false)
				end
			end
		end

		AccessorFunc(circleClass, 'm_X', 'X', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_Y', 'Y', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_Type', 'Type', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_Radius', 'Radius', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_StartAngle', 'StartAngle', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_EndAngle', 'EndAngle', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_Rotation', 'Rotation', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_Distance', 'Distance', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_VertexCount', 'VertexCount', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_BlurLayers', 'BlurLayers', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_BlurDensity', 'BlurDensity', FORCE_NUMBER)
		AccessorFunc(circleClass, 'm_Dirty', 'Dirty', FORCE_BOOL)
		AccessorFunc(circleClass, 'm_Color', 'Color')
		AccessorFunc(circleClass, 'm_Material', 'Material')
		AccessorFunc(circleClass, 'm_OutlineWidth', 'OutlineWidth', FORCE_NUMBER)

		function circleClass:SetMaterial(material)
			if isbool(material) then return end
			self.m_Material = material
		end
	end

	function circles.New(type, radius, x, y, blurLayers, blurDensity)
		local circle = setmetatable({}, circleClass)

		circle:SetType(type)
		circle:SetRadius(radius)
		circle:SetX(x)
		circle:SetY(y)

		if type == CIRCLE_OUTLINED then
			circle:SetOutlineWidth(tonumber(blurLayers) or 0)
		elseif type == CIRCLE_BLURRED then
			circle:SetBlurLayers(blurLayers)
			circle:SetBlurDensity(blurDensity)
		end

		return circle
	end

	circles.CIRCLE_FILLED = CIRCLE_FILLED
	circles.CIRCLE_OUTLINED = CIRCLE_OUTLINED
	circles.CIRCLE_BLURRED = CIRCLE_BLURRED

	api.circles = circles

	if OVERRIDE_CIRCLES then
		_G.CIRCLE_FILLED = CIRCLE_FILLED
		_G.CIRCLE_OUTLINED = CIRCLE_OUTLINED
		_G.CIRCLE_BLURRED = CIRCLE_BLURRED

		RegisterMetaTable('Circles', circles)
	end
end

paint.api = api