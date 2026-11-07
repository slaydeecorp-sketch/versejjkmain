local paint = paint
local rects = {}

do
	local meshBegin = mesh.Begin
	local meshEnd = mesh.End
	local meshPosition = mesh.Position
	local meshColor = mesh.Color
	local meshTexCoord = mesh.TexCoord
	local meshAdvanceVertex = mesh.AdvanceVertex
	local PRIMITIVE_QUADS = MATERIAL_QUADS
	local function unpackColor(color) return color.r, color.g, color.b, color.a end

	function rects.generateRectMesh(mesh, startX, startY, endX, endY, colors, u1, v1, u2, v2, skew, topSize)
		local startTopX = startX + (skew or 0)
		local endTopX = topSize and topSize > 0 and startTopX + topSize or endX + (skew or 0)

		meshBegin(mesh, PRIMITIVE_QUADS, 1)
			meshPosition(startX, endY, 0)
			meshColor(unpackColor(colors[4]))
			meshTexCoord(0, u1, v2)
			meshAdvanceVertex()

			meshPosition(startTopX, startY, 0)
			meshColor(unpackColor(colors[1]))
			meshTexCoord(0, u1, v1)
			meshAdvanceVertex()

			meshPosition(endTopX, startY, 0)
			meshColor(unpackColor(colors[2]))
			meshTexCoord(0, u2, v1)
			meshAdvanceVertex()

			meshPosition(endX, endY, 0)
			meshColor(unpackColor(colors[3]))
			meshTexCoord(0, u2, v2)
			meshAdvanceVertex()
		meshEnd()
	end

	local mat = Material('vgui/white')
	local renderSetMaterial = render.SetMaterial

	function rects.drawBatchedRects(array)
		renderSetMaterial(mat)
		meshBegin(PRIMITIVE_QUADS, array[0] / 8)
			for i = 1, array[0], 8 do
				local x, y, endX, endY = array[i], array[i + 1], array[i + 2], array[i + 3]
				local color1, color2, color3, color4 = array[i + 4], array[i + 5], array[i + 6], array[i + 7]

				meshPosition(x, endY, 0)
				meshColor(color4.r, color4.g, color4.b, color4.a)

				meshAdvanceVertex()

				meshPosition(x, y, 0)
				meshColor(color1.r, color1.g, color1.b, color1.a)

				meshAdvanceVertex()

				meshPosition(endX, y, 0)
				meshColor(color2.r, color2.g, color2.b, color2.a)

				meshAdvanceVertex()

				meshPosition(endX, endY, 0)
				meshColor(color3.r, color3.g, color3.b, color3.a)

				meshAdvanceVertex()
			end
		meshEnd()
	end
end

do
	local incrementZ = paint.incrementZ
	local batch = paint.batch

	function rects.drawBatchedRect(startX, startY, endX, endY, colors)
		local tab = batch.batchTable
		local len = tab[0]
		local z = incrementZ()

		tab[len + 1] = startX
		tab[len + 2] = endY
		tab[len + 3] = z
		tab[len + 4] = colors[4]

		tab[len + 5] = startX
		tab[len + 6] = startY
		tab[len + 7] = colors[1]

		tab[len + 8] = endX
		tab[len + 9] = startY
		tab[len + 10] = colors[2]

		tab[len + 11] = startX
		tab[len + 12] = endY
		tab[len + 13] = z
		tab[len + 14] = colors[4]

		tab[len + 15] = endX
		tab[len + 16] = startY
		tab[len + 17] = colors[2]

		tab[len + 18] = endX
		tab[len + 19] = endY
		tab[len + 20] = colors[3]

		tab[0] = len + 20
	end
end

do
	local cachedRectMeshes = {}
	local defaultMat = Material('vgui/white')

	local format = string.format

	local meshConstructor = Mesh
	local meshDraw = FindMetaTable('IMesh').Draw
	local renderSetMaterial = render.SetMaterial
	local generateRectMesh = rects.generateRectMesh

	local function getId(x, y, w, h, color1, color2, color3, color4, u1, v1, u2, v2, skew, topSize)
		return format('%f;%f;%f;%f;%x%x%x%x;%x%x%x%x;%x%x%x%x;%x%x%x%x;%f;%f;%f;%f;%f;%f',
			x, y, w, h,
			color1.r, color1.g, color1.b, color1.a,
			color2.r, color2.g, color2.b, color2.a,
			color3.r, color3.g, color3.b, color3.a,
			color4.r, color4.g, color4.b, color4.a,
			u1, v1, u2, v2, skew, topSize
		)
	end

	function rects.drawSingleRect(x, y, w, h, colors, material, u1, v1, u2, v2, skew, topSize)
		skew, topSize = skew or 0, topSize or 0

		local id = getId(x, y, w, h, colors[1], colors[2], colors[3], colors[4], u1, v1, u2, v2, skew, topSize)

		local mesh = cachedRectMeshes[id]
		if mesh == nil then
			mesh = meshConstructor()

			generateRectMesh(mesh, x, y, x + w, y + h, colors, u1, v1, u2, v2, skew, topSize)

			cachedRectMeshes[id] = mesh
		end

		renderSetMaterial(material or defaultMat)
		meshDraw(mesh)
	end

	timer.Create('paint.rectMeshGarbageCollector', 60, 0, function()
		for k, v in pairs(cachedRectMeshes) do
			cachedRectMeshes[k] = nil
			v:Destroy()
		end
	end)
end

do
	function rects.startBatching()
		rects.batching = {
			[0] = 0
		}
		rects.isBatching = true
	end

	local drawBatchedRects = rects.drawBatchedRects

	function rects.stopBatching()
		rects.isBatching = false

		drawBatchedRects(rects.batching)
	end

	function rects.drawQuadBatchedRect(x, y, w, h, colors)
		local tab = rects.batching
		local len = tab[0]
		tab[len + 1] = x
		tab[len + 2] = y
		tab[len + 3] = x + w
		tab[len + 4] = y + h
		tab[len + 5] = colors[1]
		tab[len + 6] = colors[2]
		tab[len + 7] = colors[3]
		tab[len + 8] = colors[4]
		tab[0] = len + 8
	end
end

do
	local drawSingleRect = rects.drawSingleRect
	local drawBatchedRect = rects.drawBatchedRect
	local drawQuadBatchedRect = rects.drawQuadBatchedRect
	local batch = paint.batch
	local getColorTable = paint.getColorTable

	function rects.drawRect(x, y, w, h, colors, material, u1, v1, u2, v2, skew, topSize)
		if colors[4] == nil then
			colors = getColorTable(4, colors)
		end

		if u1 == nil then
			u1, v1 = 0, 0
			u2, v2 = 1, 1
		end

		if batch.batching then
			drawBatchedRect(x, y, x + w, y + h, colors)
		else
			if rects.isBatching then
				drawQuadBatchedRect(x, y, w, h, colors)
			else
				drawSingleRect(x, y, w, h, colors, material, u1, v1, u2, v2, skew, topSize)
			end
		end
	end
end

_G.paint.rects = rects