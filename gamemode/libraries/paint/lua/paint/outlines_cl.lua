local paint = paint

local outlines = {}

do
	local meshPosition = mesh.Position
	local meshColor = mesh.Color
	local meshTexCoord = mesh.TexCoord
	local meshAdvanceVertex = mesh.AdvanceVertex
	local isFirst = true
	local prevU
	local isInside
	local cornerness = 1
	local outlineLeft = 0
	local outlineRight = 0
	local outlineTop = 0
	local outlineBottom = 0
	local atan2 = math.atan2

	local function createVertex(x, y, u, v, colors)
		if isFirst then
			isFirst = false
			return
		end

		local texU = 1 - (atan2( (1 - v) - 0.5, u - 0.5) / (2 * math.pi) + 0.5)

		if prevU and prevU > texU then
			texU = texU + 1
		else
			prevU = texU
		end


		local newX, newY

		if u < 0.5 then
			newX = x - outlineLeft * (((1 - u) - 0.5) * 2) ^ cornerness
		elseif u ~= 0.5 then
			newX = x + outlineRight * ((u - 0.5) * 2) ^ cornerness
		else
			newX = x
		end

		if v < 0.5 then
			newY = y - outlineTop * (((1 - v) - 0.5) * 2) ^ cornerness
		elseif v ~= 0.5 then
			newY = y + outlineBottom * ((v - 0.5) * 2) ^ cornerness
		else
			newY = y
		end

		if isInside then
			meshPosition(newX, newY, 0)
			meshColor(colors[2].r, colors[2].g, colors[2].b, colors[2].a)
			meshTexCoord(0, texU, 0.02)
			meshAdvanceVertex()

			meshPosition(x, y, 0)
			meshColor(colors[1].r, colors[1].g, colors[1].b, colors[1].a)
			meshTexCoord(0, texU, 1)
			meshAdvanceVertex()
		else
			meshPosition(x, y, 0)
			meshColor(colors[1].r, colors[1].g, colors[1].b, colors[1].a)
			meshTexCoord(0, texU, 1)
			meshAdvanceVertex()

			meshPosition(newX, newY, 0)
			meshColor(colors[2].r, colors[2].g, colors[2].b, colors[2].a)
			meshTexCoord(0, texU, 0.02)
			meshAdvanceVertex()
		end
	end

	local generateSingleMesh = paint.roundedBoxes.generateSingleMesh

	local meshBegin = mesh.Begin
	local meshEnd = mesh.End


	local PRIMITIVE_TRIANGLE_STRIP = MATERIAL_TRIANGLE_STRIP
	local getMeshVertexCount = paint.roundedBoxes.getMeshVertexCount

	function outlines.generateOutlineSingle(mesh, radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, l, t, r, b, curviness, inside, cornernessArg)
		isInside = inside or false
		outlineTop, outlineRight, outlineBottom, outlineLeft = t or 0, r or 0, b or 0, l or 0
		curviness = curviness or 2
		cornerness = cornernessArg or 1

		isFirst = true
		prevU = nil

		meshBegin(mesh, PRIMITIVE_TRIANGLE_STRIP, getMeshVertexCount(radius, rightTop, rightBottom, leftBottom, leftTop) * 2)
			generateSingleMesh(createVertex, nil, radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, 0, 0, 1, 1, curviness)
		meshEnd()
	end
end

do
	local cachedOutlinedMeshes = {}
	local format = string.format
	local function getId(radius, w, h, corners, color1, color2, l, t, r, b, curviness, inside, cornerness)
		return format('%f;%f;%f;%u;%x%x%x%x;%x%x%x%x;%f;%f;%f;%f;%f;%u;%f',
			radius, w, h, corners,
			color1.r, color1.g, color1.b, color1.a,
			color2.r, color2.g, color2.b, color2.a,
			l, t, r, b, curviness or 2, inside and 1 or 0, cornerness
		)
	end

	local pushModelMatrix = cam.PushModelMatrix
	local popModelMatrix = cam.PopModelMatrix
	local meshConstructor = Mesh
	local generateOutlineSingle = outlines.generateOutlineSingle
	local matrix = Matrix()
	local setField = matrix.SetField
	local setMaterial = render.SetMaterial
	local defaultMat = Material('vgui/white')
	local meshDraw = FindMetaTable('IMesh').Draw

	function outlines.drawOutlineSingle(radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, material, l, t, r, b, curviness, inside, cornerness)
		curviness = curviness or 2
		inside = inside or false
		cornerness = cornerness or 1


		local id = getId(radius, w, h, (leftTop and 8 or 0) + (rightTop and 4 or 0) + (rightBottom and 2 or 0) + (leftBottom and 1 or 0), colors[1], colors[2], l, t, r, b, curviness, inside, cornerness)

		local meshObj = cachedOutlinedMeshes[id]

		if meshObj == nil then
			meshObj = meshConstructor()
			generateOutlineSingle(meshObj, radius, 0, 0, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, l, t, r, b, curviness, inside, cornerness)

			cachedOutlinedMeshes[id] = meshObj
		end

		setField(matrix, 1, 4, x)
		setField(matrix, 2, 4, y)

		pushModelMatrix(matrix, true)
			setMaterial(material or defaultMat)
			meshDraw(meshObj)
		popModelMatrix()
	end

	timer.Create('paint.outlinesGarbageCollector', 15, 0, function()
		for k, v in pairs(cachedOutlinedMeshes) do
			v:Destroy()
			cachedOutlinedMeshes[k] = nil
		end
	end)
end

do
	local generateSingleMesh = paint.roundedBoxes.generateSingleMesh

	local outlineL, outlineT, outlineR, outlineB
	local first
	local prevX, prevY, prevU, prevV
	local z
	local batch = paint.batch

	local function createVertex(x, y, u, v, colors)
		if first then
			first = false
			return
		elseif first == false then
			prevX, prevY, prevU, prevV = x, y, u, v
			first = nil
			return
		end

		local batchTable = batch.batchTable
		local len = batchTable[0]

		local color1, color2 = colors[1], colors[2]

		batchTable[len + 1] = prevX
		batchTable[len + 2] = prevY
		batchTable[len + 3] = z
		batchTable[len + 4] = color1

		do
			if prevU < 0.5 then
				prevX = prevX - outlineL * ((1 - prevU) - 0.5) * 2
			elseif prevU ~= 0.5 then
				prevX = prevX + outlineR * (prevU - 0.5) * 2
			end

			if prevV < 0.5 then
				prevY = prevY - outlineT * ((1 - prevV) - 0.5) * 2
			elseif prevV ~= 0.5 then
				prevY = prevY + outlineB * (prevV - 0.5) * 2
			end
		end

		batchTable[len + 5] = prevX
		batchTable[len + 6] = prevY
		batchTable[len + 7] = color2

		batchTable[len + 8] = x
		batchTable[len + 9] = y
		batchTable[len + 10] = color1

		batchTable[len + 11] = x
		batchTable[len + 12] = y
		batchTable[len + 13] = z
		batchTable[len + 14] = color1

		batchTable[len + 15] = prevX
		batchTable[len + 16] = prevY
		batchTable[len + 17] = color2

		prevX, prevY, prevU, prevV = x, y, u, v
		do
			if u < 0.5 then
				x = x - outlineL * (((1 - u) - 0.5) * 2)
			elseif u ~= 0.5 then
				x = x + outlineR * (u - 0.5) * 2
			end

			if v < 0.5 then
				y = y - outlineT * ((1 - v) - 0.5) * 2
			elseif v ~= 0.5 then
				y = y + outlineB * (v - 0.5) * 2
			end
		end

		batchTable[len + 18] = x
		batchTable[len + 19] = y
		batchTable[len + 20] = color2

		batchTable[0] = len + 20
	end

	local incrementZ = paint.incrementZ

	function outlines.drawOutlineBatched(radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, _, l, t, r, b, curviness)
		outlineL, outlineT, outlineR, outlineB = l, t, r, b
		first = true
		curviness = curviness or 2

		z = incrementZ()
		generateSingleMesh(createVertex, nil, radius, x, y, x + w, y + h, leftTop, rightTop, rightBottom, leftBottom, colors, 0, 0, 1, 1, curviness)
	end
end

do
	local batch = paint.batch
	local drawOutlineSingle = outlines.drawOutlineSingle
	local drawOutlineBatched = outlines.drawOutlineBatched
	local getColorTable = paint.getColorTable

	function outlines.drawOutlineEx(radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, material, l, t, r, b, curviness, inside, cornerness)
		if colors[2] == nil then
			colors = getColorTable(2, colors)
		end

		if radius == 0 then
			leftTop, rightTop, rightBottom, leftBottom = false, false, false, false
		end

		if t == nil then
			t, r, b = l, l, l
		elseif r == nil then
			r, b = l, t
		end

		inside = inside or false
		curviness = curviness or 2
		cornerness = cornerness or 1

		if batch.batching then
			drawOutlineBatched(radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, material, l, t, r, b, curviness)
		else
			drawOutlineSingle(radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, material, l, t, r, b, curviness, inside, cornerness)
		end
	end

	local drawOutlineEx = outlines.drawOutlineEx

	function outlines.drawOutline(radius, x, y, w, h, colors, material, l, t, r, b, curviness, inside, cornerness)
		drawOutlineEx(radius, x, y, w, h, true, true, true, true, colors, material, l, t, r, b, curviness, inside, cornerness)
	end
end

do
	local meshConstructor = Mesh
	local meshBegin = mesh.Begin
	local meshEnd = mesh.End

	local meshPosition = mesh.Position
	local meshColor = mesh.Color
	local meshAdvanceVertex = mesh.AdvanceVertex

	local PRIMITIVE_TRIANGLE_STRIP = MATERIAL_TRIANGLE_STRIP

	function outlines.generateBoxOutline(x, y, endX, endY, colors, outlineL, outlineT, outlineR, outlineB)
		local meshObj = meshConstructor()

		local innerR, innerG, innerB, innerA = colors[1].r, colors[1].g, colors[1].b, colors[1].a
		local outerR, outerG, outerB, outerA = colors[2].r, colors[2].g, colors[2].b, colors[2].a

		meshBegin(meshObj, PRIMITIVE_TRIANGLE_STRIP, 17)
			meshPosition(x, y, 0)
			meshColor(innerR, innerG, innerB, innerA)
			meshAdvanceVertex()

			meshPosition(x, y - outlineT, 0)
			meshColor(outerR, outerG, outerB, outerA)
			meshAdvanceVertex()

			meshPosition(endX, y, 0)
			meshColor(innerR, innerG, innerB, innerA)
			meshAdvanceVertex()

			meshPosition(endX, y - outlineT, 0)
			meshColor(outerR, outerG, outerB, outerA)
			meshAdvanceVertex()

			meshPosition(endX, y, 0)
			meshColor(innerR, innerG, innerB, innerA)
			meshAdvanceVertex()

			meshPosition(endX + outlineR, y, 0)
			meshColor(outerR, outerG, outerB, outerA)
			meshAdvanceVertex()

			meshPosition(endX, endY, 0)
			meshColor(innerR, innerG, innerB, innerA)
			meshAdvanceVertex()

			meshPosition(endX + outlineR, endY, 0)
			meshColor(outerR, outerG, outerB, outerA)
			meshAdvanceVertex()

			meshPosition(endX, endY, 0)
			meshColor(innerR, innerB, innerB, innerA)
			meshAdvanceVertex()

			meshPosition(endX, endY + outlineB, 0)
			meshColor(outerR, outerB, outerB, outerA)
			meshAdvanceVertex()

			meshPosition(x, endY, 0)
			meshColor(innerR, innerG, innerB, innerA)
			meshAdvanceVertex()

			meshPosition(x, endY + outlineB, 0)
			meshColor(outerR, outerG, outerB, outerA)
			meshAdvanceVertex()

			meshPosition(x, endY, 0)
			meshColor(innerR, innerG, innerB, innerA)
			meshAdvanceVertex()

			meshPosition(x - outlineL, endY, 0)
			meshColor(outerR, outerG, outerB, outerA)
			meshAdvanceVertex()

			meshPosition(x, y, 0)
			meshColor(innerR, innerG, innerB, innerA)
			meshAdvanceVertex()

			meshPosition(x - outlineL, y, 0)
			meshColor(outerR, outerG, outerB, outerA)
			meshAdvanceVertex()

			meshPosition(x, y - outlineL, 0)
			meshColor(outerR, outerG, outerB, outerA)
			meshAdvanceVertex()
		meshEnd()

		return meshObj
	end

	local format = string.format

	local function getId(w, h, color1, color2, outlineL, outlineT, outlineR, outlineB)
		return format('%f;%f;%x%x%x%x;%x%x%x%x;%f;%f;%f;%f',
			w, h,
			color1.r, color1.g, color1.b, color1.a,
			color2.r, color2.g, color2.b, color2.a,
			outlineL, outlineT, outlineR, outlineB
		)
	end

	local generateBoxOutline = outlines.generateBoxOutline
	local cachedBoxOutlineMeshes = {}
	local camPushModelMatrix = cam.PushModelMatrix
	local camPopModelMatrix = cam.PopModelMatrix
	local matrix = Matrix()
	local setField = matrix.SetField
	local meshDraw = FindMetaTable('IMesh').Draw
	local defaultMat = Material('vgui/white')
	local renderSetMaterial = render.SetMaterial
	local getColorTable = paint.getColorTable

	function outlines.drawBoxOutline(x, y, w, h, colors, outlineL, outlineT, outlineR, outlineB)
		if colors[2] == nil then
			colors = getColorTable(2, colors)
		end

		if outlineT == nil then
			outlineT, outlineR, outlineB = outlineL, outlineL, outlineL
		elseif outlineR == nil then
			outlineR, outlineB = outlineL, outlineT
		end

		local id = getId(w, h, colors[1], colors[2], outlineL, outlineT, outlineR, outlineB)

		local mesh = cachedBoxOutlineMeshes[id]

		if mesh == nil then
			mesh = generateBoxOutline(0, 0, w, h, colors, outlineL, outlineT, outlineR, outlineB)
			cachedBoxOutlineMeshes[id] = mesh
		end

		setField(matrix, 1, 4, x)
		setField(matrix, 2, 4, y)

		renderSetMaterial(defaultMat)

		camPushModelMatrix(matrix, true)
			meshDraw(mesh)
		camPopModelMatrix()
	end

	timer.Create('paint.cachedBoxOutlineGarbageCollector', 60, 0, function()
		for k, v in pairs(cachedBoxOutlineMeshes) do
			v:Destroy()
			cachedBoxOutlineMeshes[k] = nil
		end
	end)
end

_G.paint.outlines = outlines