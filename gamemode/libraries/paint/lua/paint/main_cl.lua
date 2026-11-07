local paint = {}

do
	paint.Z = 0

	function paint.resetZ()
		paint.Z = 0
	end

	function paint.incrementZ()
		paint.Z = paint.Z + 1

		if paint.Z > 16384 then
			paint.resetZ()
		end

		return paint.getZ()
	end

	function paint.getZ()
		return -1 + paint.Z / 8192
	end
end

do
    local tab = {}
    local len = 0
    local setScissorRect = render.SetScissorRect
    local max = math.max
    local min = math.min

    function paint.pushScissorRect(x, y, endX, endY)
        local prev = tab[len]

        if prev then
            x = max(prev[1], x)
            y = max(prev[2], y)
            endX = min(prev[3], endX)
            endY = min(prev[4], endY)
        end

        len = len + 1

        tab[len] = {x, y, endX, endY}
        setScissorRect(x, y, endX, endY, true)
    end

    function paint.popScissorRect()
        tab[len] = nil
        len = max(0, len - 1)

        local newTab = tab[len]

        if newTab then
            setScissorRect(newTab[1], newTab[2], newTab[3], newTab[4], true)
        else
            setScissorRect(0, 0, 0, 0, false)
        end
    end
end

do
	local vector = Vector()
	local paintColoredMaterial = CreateMaterial( "testMaterial" .. SysTime(), "UnlitGeneric", {
	  ["$basetexture"] = "color/white",
	  ["$model"] = 1,
	  ["$translucent"] = 1,
	  ["$vertexalpha"] = 1,
	  ["$vertexcolor"] = 1
	} )

	local recompute = paintColoredMaterial.Recompute
	local setVector = paintColoredMaterial.SetVector
	local setUnpacked = vector.SetUnpacked
	local currentR, currentG, currentB, currentA = 255, 255, 255, 255

	function paint.getColoredMaterial(color)
		local r, g, b, a = color.r, color.g, color.b, color.a

		if currentR ~= r or currentG ~= g or currentB ~= b or currentA ~= a then
			currentR, currentG, currentB, currentA = r, g, b, a
			setUnpacked(vector, r / 255, g / 255, b / 255)
			setVector(paintColoredMaterial, '$color', vector)
			recompute(paintColoredMaterial)
		end

		return paintColoredMaterial
	end
end

do
	local matrix = Matrix()
	local setField = matrix.SetField
	local pushModelMatrix = cam.PushModelMatrix
	local popModelMatrix = cam.PopModelMatrix
	local panelTab = FindMetaTable('Panel')
	local localToScreen = panelTab.LocalToScreen
	local getSize = panelTab.GetSize
	local pushScissorRect = paint.pushScissorRect
	local popScissorRect = paint.popScissorRect
	local setScissorRect = render.SetScissorRect

	function paint.startPanel(panel, pos, boundaries, multiply)
		local x, y = localToScreen(panel, 0, 0)

		if pos or pos == nil then

			setField(matrix, 1, 4, x)
			setField(matrix, 2, 4, y)

			pushModelMatrix(matrix, multiply)
		end

		if boundaries then
			local w, h = getSize(panel)

			pushScissorRect(x, y, x + w, y + h)
		end
	end

	function paint.endPanel(pos, boundaries)
		if pos or pos == nil then
			popModelMatrix()
		end

		if boundaries then
			popScissorRect()
		end
	end

	do
		paint.beginPanel = paint.startPanel
		paint.stopPanel = paint.endPanel
	end

	local getPanelPaintState = surface.GetPanelPaintState

	function paint.startVGUI()
		local state = getPanelPaintState()

		setField(matrix, 1, 4, state.translate_x)
		setField(matrix, 2, 4, state.translate_y)

		pushModelMatrix(matrix, true)

		if state.scissor_enabled then
			setScissorRect(state.scissor_left, state.scissor_top, state.scissor_right, state.scissor_bottom, true)
		end
	end

	function paint.endVGUI()
		popModelMatrix()
		setScissorRect(0, 0, 0, 0, false)
	end

	function paint.bilinearInterpolation(x, y, leftTop, rightTop, rightBottom, leftBottom)
		if leftTop == rightTop and leftTop == rightBottom and leftTop == leftBottom then return leftTop end
		local top = leftTop == rightTop and leftTop or ( (1 - x) * leftTop + x * rightTop)
		local bottom = leftBottom == rightBottom and leftBottom or ((1 - x) * leftBottom + x * rightBottom)
		return (1 - y) * top + y * bottom
	end
end

do
	local meshConstructor = Mesh
	local meshBegin = mesh.Begin
	local meshEnd = mesh.End
	local meshPosition = mesh.Position
	local meshColor = mesh.Color
	local meshTexCoord = mesh.TexCoord
	local meshAdvanceVertex = mesh.AdvanceVertex
	local colorWhite = color_white
	local PRIMITIVE_POLYGON = MATERIAL_POLYGON

	function paint.generatePoly(vertices)
		local len = #vertices

		local iMesh = meshConstructor()

		meshBegin(iMesh, PRIMITIVE_POLYGON, len)
			for i = 1, len do
				local v = vertices[i]

				local color = v.color or colorWhite
				meshPosition(v.x, v.y, 0)
				meshColor(color.r, color.g, color.b, color.a)

				if v.u then
					meshTexCoord(0, v.u, v.v)
				end

				meshAdvanceVertex()
			end
		meshEnd()

		return iMesh
	end

	local defaultMat = Material('vgui/white')
	local renderSetMaterial = render.SetMaterial

	function paint.drawPoly(vertices, material)
		local len = #vertices

		renderSetMaterial(material or defaultMat)

		meshBegin(PRIMITIVE_POLYGON, len)
			for i = 1, len do
				local v = vertices[i]

				local color = v.color or colorWhite
				meshPosition(v.x, v.y, 0)
				meshColor(color.r, color.g, color.b, color.a)

				if v.u then
					meshTexCoord(0, v.u, v.v)
				end

				meshAdvanceVertex()
			end
		meshEnd()
	end
end

do
	local tab = {}

	function paint.getColorTable(len, color)
		for i = 1, len do
			tab[i] = color
		end

		return tab
	end
end

_G.paint = paint