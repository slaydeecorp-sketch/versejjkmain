local paint = _G.paint
local roundedBoxes = {}

do
	local meshBegin = mesh.Begin
	local meshEnd = mesh.End
	local PRIMITIVE_POLYGON = MATERIAL_POLYGON
	local clamp = math.Clamp
	local halfPi = math.pi / 2
	local sin = math.sin
	local cos = math.cos

	local function fpow(num, power)
		if num > 0 then
			return num ^ power
		else
			return -((-num) ^ power)
		end
	end

	function roundedBoxes.getMeshVertexCount(radius, rightTop, rightBottom, leftBottom, leftTop)
		if radius > 3 then
			local vertsPerEdge = clamp(radius / 2, 3, 24)
			return 10
				+ (rightTop and vertsPerEdge or 0)
				+ (rightBottom and vertsPerEdge or 0)
				+ (leftBottom and vertsPerEdge or 0)
				+ (leftTop and vertsPerEdge or 0)
		else
			return 10
				+ (rightTop and 1 or 0)
				+ (rightBottom and 1 or 0)
				+ (leftBottom and 1 or 0)
				+ (leftTop and 1 or 0)
		end
	end

	local getMeshVertexCount = roundedBoxes.getMeshVertexCount
	local centreTab = {}
	function roundedBoxes.generateSingleMesh(createVertex, mesh, radius, x, y, endX, endY, leftTop, rightTop, rightBottom, leftBottom, colors, u1, v1, u2, v2, curviness)
		local vertsPerEdge = clamp(radius / 2, 3, 24)

		local isRadiusBig = radius > 3

		curviness = 2 / (curviness or 2)

		local w, h = endX - x, endY - y

		if mesh then
			meshBegin(mesh, PRIMITIVE_POLYGON, getMeshVertexCount(radius, rightTop, rightBottom, leftBottom, leftTop))
		end

		local fifthColor = colors[5]
		if fifthColor == nil then
			createVertex((x + endX) * 0.5, (y + endY) * 0.5, 0.5, 0.5, colors, u1, v1, u2, v2)
		else
			centreTab[1], centreTab[2], centreTab[3], centreTab[4] = fifthColor, fifthColor, fifthColor, fifthColor
			createVertex((x + endX) * 0.5, (y + endY) * 0.5, 0.5, 0.5, centreTab, u1, v1, u2, v2)
		end

		createVertex(x + (leftTop and radius or 0), y, (leftTop and radius or 0) / w, 0, colors, u1, v1, u2, v2)

		createVertex( (x + endX) * 0.5, y, 0.5, 0, colors, u1, v1, u2, v2)

		createVertex(endX - (rightTop and radius or 0), y, 1 - (rightTop and radius or 0) / w, 0, colors, u1, v1, u2, v2)

		if rightTop then
			if isRadiusBig then
				local deltaX = endX - radius
				local deltaY = y + radius

				for i = 1, vertsPerEdge - 1 do
					local angle = halfPi * (i / vertsPerEdge)

					local sinn, coss = fpow(sin(angle), curviness), fpow(cos(angle), curviness)

					local newX, newY = deltaX + sinn * radius, deltaY - coss * radius

					createVertex(newX, newY, 1 - (1-sinn) * radius / w, ( 1 - coss) * radius / h, colors, u1, v1, u2, v2 )
				end
			end

			createVertex(endX, y + radius, 1, radius / h, colors, u1, v1, u2, v2)
		end

		createVertex(endX, (y + endY) * 0.5, 1, 0.5, colors, u1, v1, u2, v2)

		createVertex(endX, endY - (rightBottom and radius or 0), 1, 1 - (rightBottom and radius or 0) / h, colors, u1, v1, u2, v2)

		if rightBottom then
			if isRadiusBig then
				local deltaX = endX - radius
				local deltaY = endY - radius

				for i = 1, vertsPerEdge - 1 do
					local angle = halfPi * (i / vertsPerEdge)

					local sinn, coss = fpow(sin(angle), curviness), fpow(cos(angle), curviness)

					local newX, newY = deltaX + coss * radius, deltaY + sinn * radius

					createVertex(newX, newY, 1 - ((1 - coss) * radius) / w, 1 - ( (1 - sinn) * radius ) / h, colors, u1, v1, u2, v2)
				end
			end

			createVertex(endX - radius, endY, 1 - radius / w, 1, colors, u1, v1, u2, v2)
		end

		createVertex( (x + endX) * 0.5, endY, 0.5, 1, colors, u1, v1, u2, v2 )

		createVertex(x + (leftBottom and radius or 0), endY, (leftBottom and radius or 0) / w, 1, colors, u1, v1, u2, v2)

		if leftBottom then
			if isRadiusBig then
				local deltaX = x + radius
				local deltaY = endY - radius

				for i = 1, vertsPerEdge - 1 do
					local angle = halfPi * (i / vertsPerEdge)

					local sinn, coss = fpow(sin(angle), curviness), fpow(cos(angle), curviness)

					local newX, newY = deltaX - sinn * radius, deltaY + coss * radius

					createVertex(newX, newY, (1 - sinn) * radius / w, 1 - (1 - coss) * radius / h, colors, u1, v1, u2, v2)
				end
			end

			createVertex(x, endY - radius, 0, 1 - radius / h, colors, u1, v1, u2, v2)
		end

		createVertex(x, (y + endY) * 0.5, 0, 0.5, colors, u1, v1, u2, v2 )

		createVertex(x, y + (leftTop and radius or 0), 0, (leftTop and radius or 0) / h, colors, u1, v1, u2, v2)

		if leftTop then
			if isRadiusBig then
				local deltaX = x + radius
				local deltaY = y + radius

				for i = 1, vertsPerEdge - 1 do
					local angle = halfPi * (i / vertsPerEdge)

					local sinn, coss = fpow(sin(angle), curviness), fpow(cos(angle), curviness)

					local newX, newY = deltaX - coss * radius, deltaY - sinn * radius

					createVertex(newX, newY, (1 - coss) * radius / w, (1 - sinn) * radius / h, colors, u1, v1, u2, v2)
				end
			end

			createVertex(x + radius, y, radius / w, 0, colors, u1, v1, u2, v2)
		end

		if mesh then
			meshEnd()
		end
	end
end

do
	local meshPosition = mesh.Position
	local meshColor = mesh.Color
	local meshAdvanceVertex = mesh.AdvanceVertex
	local meshTexCoord = mesh.TexCoord
	local bilinearInterpolation = paint.bilinearInterpolation

	local function createVertex(x, y, u, v, colors, u1, v1, u2, v2)
		local leftTop, rightTop, rightBottom, leftBottom = colors[1], colors[2], colors[3], colors[4]
		meshPosition(x, y, 0)
		meshTexCoord(0, u * (u2 - u1) + u1, v * (v2 - v1) + v1)
		meshColor(
			bilinearInterpolation(u, v, leftTop.r, rightTop.r, rightBottom.r, leftBottom.r),
			bilinearInterpolation(u, v, leftTop.g, rightTop.g, rightBottom.g, leftBottom.g),
			bilinearInterpolation(u, v, leftTop.b, rightTop.b, rightBottom.b, leftBottom.b),
			bilinearInterpolation(u, v, leftTop.a, rightTop.a, rightBottom.a, leftBottom.a)
		)

		meshAdvanceVertex()
	end


	local meshConstructor = Mesh
	local meshDraw = FindMetaTable('IMesh').Draw
	local format = string.format
	local setMaterial = render.SetMaterial
	local matrix = Matrix()
	local setField = matrix.SetField
	local pushModelMatrix = cam.PushModelMatrix
	local popModelMatrix = cam.PopModelMatrix
	local generateSingleMesh = roundedBoxes.generateSingleMesh

	local function getId(radius, w, h, corners, colors, u1, v1, u2, v2, curviness)
		local color1, color2, color3, color4, color5 = colors[1], colors[2], colors[3], colors[4], colors[5]

		if color5 == nil then
			return format('%f;%f;%f;%u;%x%x%x%x;%x%x%x%x;%x%x%x%x;%x%x%x%x;%f;%f;%f;%f;%f',
				radius, w, h, corners,
				color1.r, color1.g, color1.b, color1.a,
				color2.r, color2.g, color2.b, color2.a,
				color3.r, color3.g, color3.b, color3.a,
				color4.r, color4.g, color4.b, color4.a,
				u1, v1, u2, v2, curviness
			)
		else
			return format('%f;%f;%f;%u;%x%x%x%x;%x%x%x%x;%x%x%x%x;%x%x%x%x;%x%x%x%x;%f;%f;%f;%f;%f',
				radius, w, h, corners,
				color1.r, color1.g, color1.b, color1.a,
				color2.r, color2.g, color2.b, color2.a,
				color3.r, color3.g, color3.b, color3.a,
				color4.r, color4.g, color4.b, color4.a,
				color5.r, color5.g, color5.b, color5.a,
				u1, v1, u2, v2, curviness
			)
		end

	end

	local cachedRoundedBoxMeshes = {}

	function roundedBoxes.roundedBoxExSingle(radius, x, y, w, h, colors, leftTop, rightTop, rightBottom, leftBottom, material, u1, v1, u2, v2, curviness)
		curviness = curviness or 2
		local id = getId(radius, w, h, (leftTop and 8 or 0) + (rightTop and 4 or 0) + (rightBottom and 2 or 0) + (leftBottom and 1 or 0), colors, u1, v1, u2, v2, curviness)

		local meshObj = cachedRoundedBoxMeshes[id]

		if meshObj == nil then
			meshObj = meshConstructor()
			generateSingleMesh(createVertex, meshObj, radius, 0, 0, w, h, leftTop, rightTop, rightBottom, leftBottom, colors, u1, v1, u2, v2, curviness)

			cachedRoundedBoxMeshes[id] = meshObj
		end

		setField(matrix, 1, 4, x)
		setField(matrix, 2, 4, y)

		pushModelMatrix(matrix, true)
			setMaterial(material)
			meshDraw(meshObj)
		popModelMatrix()
	end

	timer.Create('paint.roundedBoxesGarbageCollector', 30, 0, function()
		for k, v in pairs(cachedRoundedBoxMeshes) do
			v:Destroy()
			cachedRoundedBoxMeshes[k] = nil
		end
	end)
end

do
	local prev1
	local prev2 = {}
	local batch = paint.batch
	local incrementZ = paint.incrementZ
	local color = Color
	local bilinearInterpolation = paint.bilinearInterpolation

	local function createVertex(x, y, u, v, colors)
		if prev1 == nil then
			local z = incrementZ()
			local blendedColor = color(
				(colors[1].r + colors[2].r + colors[3].r + colors[4].r) / 4,
				(colors[1].g + colors[2].g + colors[3].g + colors[4].g) / 4,
				(colors[1].b + colors[2].b + colors[3].b + colors[4].b) / 4,
				(colors[1].a + colors[2].a + colors[3].a + colors[4].a) / 4
			)

			prev1 = {x, y, blendedColor, z}
			return
		end

		local prefferedColor = color(
			bilinearInterpolation(u, v, colors[1].r, colors[2].r, colors[3].r, colors[4].r),
			bilinearInterpolation(u, v, colors[1].g, colors[2].g, colors[3].g, colors[4].g),
			bilinearInterpolation(u, v, colors[1].b, colors[2].b, colors[3].b, colors[4].b),
			bilinearInterpolation(u, v, colors[1].a, colors[2].a, colors[3].a, colors[4].a)
		)
		if prev2 == nil then
			prev2 = {x, y, prefferedColor}
			return
		end

		local batchTable = batch.batchTable

		local len = batchTable[0]
		batchTable[len + 1] = prev1[1]
		batchTable[len + 2] = prev1[2]
		batchTable[len + 3] = prev1[4]
		batchTable[len + 4] = prev1[3]
		batchTable[len + 5] = prev2[1]
		batchTable[len + 6] = prev2[2]
		batchTable[len + 7] = prev2[3]
		batchTable[len + 8] = x
		batchTable[len + 9] = y
		batchTable[len + 10] = prefferedColor
		batchTable[0] = len + 10
		prev2[1] = x
		prev2[2] = y
		prev2[3] = prefferedColor
	end

	local generateSingleMesh = roundedBoxes.generateSingleMesh

	function roundedBoxes.roundedBoxExBatched(radius, x, y, w, h, colors, leftTop, rightTop, rightBottom, leftBottom, curviness)
		prev1 = nil
		prev2 = nil
		generateSingleMesh(createVertex, nil, radius, x, y, x + w, y + h, leftTop, rightTop, rightBottom, leftBottom, colors, 0, 0, 1, 1, curviness)
	end
end

do
	local defaultMat = Material('vgui/white')
	local roundedBoxExSingle = roundedBoxes.roundedBoxExSingle
	local roundedBoxExBatched = roundedBoxes.roundedBoxExBatched
	local batch = paint.batch
	local getColorTable = paint.getColorTable

	function roundedBoxes.roundedBoxEx(radius, x, y, w, h, colors, leftTop, rightTop, rightBottom, leftBottom, material, u1, v1, u2, v2, curviness)
		if colors[4] == nil then
			colors = getColorTable(4, colors)
		end

		if u1 == nil then
			u1, v1, u2, v2 = 0, 0, 1, 1
		end

		curviness = curviness or 2

		if radius == 0 then
			leftTop, rightTop, rightBottom, leftBottom = false, false, false, false
		end

		material = material or defaultMat

		if batch.batching then
			roundedBoxExBatched(radius, x, y, w, h, colors, leftTop, rightTop, rightBottom, leftBottom, curviness)
		else
			roundedBoxExSingle(radius, x, y, w, h, colors, leftTop, rightTop, rightBottom, leftBottom, material, u1, v1, u2, v2, curviness)
		end
	end

	local roundedBoxEx = roundedBoxes.roundedBoxEx

	function roundedBoxes.roundedBox(radius, x, y, w, h, colors, material, u1, v1, u2, v2, curviness)
		roundedBoxEx(radius, x, y, w, h, colors, true, true, true, true, material, u1, v1, u2, v2, curviness)
	end

	roundedBoxes.drawRoundedBox = roundedBoxes.roundedBox
	roundedBoxes.drawRoundedBoxEx = roundedBoxes.roundedBoxEx
end

do
	local generateSingleMesh = roundedBoxes.generateSingleMesh
	local createdTable
	local len

	local function createVertex(x, y, u, v, _, u1, v1, u2, v2)
		if createdTable == nil then return end

		len = len + 1
		createdTable[len] = {x = x, y = y, u = u1 + u * (u2 - u1), v = v1 + v * (v2 - v1)}
	end

	local emptyTab = {}

	function roundedBoxes.generateDrawPoly(radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, u1, v1, u2, v2, curviness)
		createdTable = {}
		len = 0
		generateSingleMesh(createVertex, nil, radius, x, y, w, h, leftTop, rightTop, rightBottom, leftBottom, emptyTab, u1, v1, u2, v2, curviness)

		local tab = createdTable

		createdTable = nil
		len = nil
		return tab
	end
end

do
	local meshConstructor = Mesh
	local PRIMITIVE_POLYGON = MATERIAL_POLYGON
	local meshBegin = mesh.Begin
	local meshEnd = mesh.End
	local meshPosition = mesh.Position
	local meshTexCoord = mesh.TexCoord
	local meshColor = mesh.Color
	local meshAdvanceVertex = mesh.AdvanceVertex

	function roundedBoxes.generateSimpleRoundedBox(radius, x, y, w, h, colors, leftTop, rightTop, rightBottom, leftBottom)
		local iMesh = meshConstructor()

		local color1, color2, color3, color4 = colors[1], colors[2], colors[3], colors[4]

		local color1R, color1G, color1B, color1A = color1.r, color1.g, color1.b, color1.a
		local color2R, color2G, color2B, color2A = color2.r, color2.g, color2.b, color2.a
		local color3R, color3G, color3B, color3A = color3.r, color3.g, color3.b, color3.a
		local color4R, color4G, color4B, color4A = color4.r, color4.g, color4.b, color4.a

		local halfW = w / 2
		local halfH = h / 2

		local radiusW, radiusH = halfW / radius, halfH / radius

		meshBegin(iMesh, PRIMITIVE_POLYGON, 10)
			meshPosition(x + halfW, y + halfH, 0)
			meshColor(
				(color1R + color2R + color3R + color4R) * 0.25,
				(color1G + color2G + color3G + color4G) * 0.25,
				(color1B + color2B + color3B + color4B) * 0.25,
				(color1A + color2A + color3A + color4A) * 0.25
			)
			meshTexCoord(0, radiusW, radiusH)
			meshAdvanceVertex()

			meshPosition(x, y, 0)
			meshColor(
				color1R, color1G, color1B, color1A
			)
			meshTexCoord(0, leftTop and 0 or radiusW, leftTop and 0 or radiusH)
			meshAdvanceVertex()

			meshPosition(x + halfW, y, 0)
			meshColor(
				(color1R + color2R) * 0.5,
				(color1G + color2G) * 0.5,
				(color1B + color2B) * 0.5,
				(color1A + color2A) * 0.5
			)
			meshTexCoord(0, radiusW, 0)
			meshAdvanceVertex()

			meshPosition(x + w, y, 0)
			meshColor(
				color2R, color2G, color2B, color2A
			)
			meshTexCoord(0, rightTop and 0 or radiusW, rightTop and 0 or radiusH)
			meshAdvanceVertex()

			meshPosition(x + w, y + halfH, 0)
			meshColor(
				(color3R + color2R) * 0.5,
				(color3G + color2G) * 0.5,
				(color3B + color2B) * 0.5,
				(color3A + color2A) * 0.5
			)
			meshTexCoord(0, 0, radiusH)
			meshAdvanceVertex()

			meshPosition(x + w, y + w, 0)
			meshColor(
				color3R, color3G, color3B, color3A
			)
			meshTexCoord(0, rightBottom and 0 or radiusW, rightBottom and 0 or radiusH)
			meshAdvanceVertex()

			meshPosition(x + halfW, y + w, 0)
			meshColor(
				(color3R + color4R) * 0.5,
				(color3G + color4G) * 0.5,
				(color3B + color4B) * 0.5,
				(color3A + color4A) * 0.5
			)
			meshTexCoord(0, radiusW, 0)
			meshAdvanceVertex()

			meshPosition(x, y + w, 0)
			meshColor(
				color4R, color4G, color4B, color4A
			)
			meshTexCoord(0, leftBottom and 0 or radiusW, leftBottom and 0 or radiusH)
			meshAdvanceVertex()

			meshPosition(x, y + halfW, 0)
			meshColor(
				(color1R + color4R) * 0.5,
				(color1G + color4G) * 0.5,
				(color1B + color4B) * 0.5,
				(color1A + color4A) * 0.5
			)
			meshTexCoord(0, 0, radiusH)
			meshAdvanceVertex()

			meshPosition(x, y, 0)
			meshColor(
				color1R, color1G, color1B, color1A
			)
			meshTexCoord(0, leftTop and 0 or radiusW, leftTop and 0 or radiusH)
			meshAdvanceVertex()
		meshEnd()

		return iMesh
	end

	local function getClampedTexture(name)
		if file.Exists('paint/' .. name .. '.vmt', 'DATA') then
			return Material('../data/paint/' .. name)
		end

		file.CreateDir('paint/' .. string.GetPathFromFilename(name))

		local vtfData = file.Open('materials/' .. name .. '.vtf', 'rb', 'MOD')
		local newVtf = file.Open('paint/' .. name .. '.vtf', 'wb', 'DATA')

		newVtf:Write(vtfData:Read(20))
		newVtf:WriteULong(bit.bor(vtfData:ReadULong(), 4, 8))
		newVtf:Write(vtfData:Read(vtfData:Size() - 24))
		newVtf:Flush()

		vtfData:Close()
		newVtf:Close()

		file.Write('paint/' .. name .. '.vmt',
			string.format([[
				"UnlitGeneric"
				{
					"$basetexture" "../data/paint/%s"
					"$ignorez" "1"
					"$vertexcolor" "1"
					"$vertexalpha" "1"
					"$nolod" "1"
				}]], name)
		)

		return Material('../data/paint/' .. name)
	end

	local texCorner8 = getClampedTexture( 'gui/corner8')
	local texCorner16 = getClampedTexture( 'gui/corner16')
	local texCorner32 = getClampedTexture( 'gui/corner32')
	local texCorner64 = getClampedTexture( 'gui/corner64')
	local texCorner512 = getClampedTexture( 'gui/corner512')
	local generateSimpleRoundedBox = roundedBoxes.generateSimpleRoundedBox
	local cachedSimpleRoundedBoxMeshes = {}
	local matrix = Matrix()
	local setField = matrix.SetField
	local pushModelMatrix = cam.PushModelMatrix
	local popModelMatrix = cam.PopModelMatrix
	local meshDraw = FindMetaTable('IMesh').Draw
	local setMaterial = render.SetMaterial
	local format = string.format

	local function getId(radius, w, h, color1, color2, color3, color4, corners)
		return format('%f;%f;%f;%x%x%x%x;%x%x%x%x;%x%x%x%x;%x%x%x%x;%u', radius, w, h,
			color1.r, color1.g, color1.b, color1.a,
			color2.r, color2.g, color2.b, color2.a,
			color3.r, color3.g, color3.b, color3.a,
			color4.r, color4.g, color4.b, color4.a,
			corners
		)
	end

	local getColorTable = paint.getColorTable

	function roundedBoxes.drawSimpleRoundedBoxEx(radius, x, y, w, h, colors, leftTop, rightTop, rightBottom, leftBottom)
		if colors[4] == nil then
			colors = getColorTable(4, colors)
		end

		local id = getId(radius, w, h, colors[1], colors[2], colors[3], colors[4], (leftTop and 8 or 0) + (rightTop and 4 or 0) + (rightBottom and 2 or 0) + (leftBottom and 1 or 0) )

		local meshObj = cachedSimpleRoundedBoxMeshes[id]

		if meshObj == nil then
			meshObj = generateSimpleRoundedBox(radius, 0, 0, w, h, colors, leftTop, rightTop, rightBottom, leftBottom)
			cachedSimpleRoundedBoxMeshes[id] = meshObj
		end

		setField(matrix, 1, 4, x)
		setField(matrix, 2, 4, y)

		local material = texCorner8
		if radius > 64 then material = texCorner512
		elseif radius > 32 then material = texCorner64
		elseif radius > 16 then material = texCorner32
		elseif radius > 8 then material = texCorner16 end

		pushModelMatrix(matrix, true)
			setMaterial(material)
			meshDraw(meshObj)
		popModelMatrix()
	end

	local drawSimpleRoundedBoxEx = roundedBoxes.drawSimpleRoundedBoxEx

	function roundedBoxes.drawSimpleRoundedBox(radius, x, y, w, h, colors)
		drawSimpleRoundedBoxEx(radius, x, y ,w, h, colors, true, true, true, true)
	end

	timer.Create('paint.simpleRoundedBoxesGarbageCollector', 60, 0, function()
		for k, v in pairs(cachedSimpleRoundedBoxMeshes) do
			v:Destroy()
			cachedSimpleRoundedBoxMeshes[k] = nil
		end
	end)
end

_G.paint.roundedBoxes = roundedBoxes