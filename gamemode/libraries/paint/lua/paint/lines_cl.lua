local paint = paint
local lines = {}
local batch = {[0] = 0}
local PRIMITIVE_LINES = MATERIAL_LINES
local PRIMITIVE_LINE_STRIP = MATERIAL_LINE_STRIP
local PRIMITIVE_LINE_LOOP = MATERIAL_LINE_LOOP

do
	local meshBegin = mesh.Begin
	local meshEnd = mesh.End
	local meshPosition = mesh.Position
	local meshColor = mesh.Color
	local meshAdvanceVertex = mesh.AdvanceVertex
	local renderSetColorMaterialIgnoreZ = render.SetColorMaterialIgnoreZ

	function lines.drawSingleLine(startX, startY, endX, endY, startColor, endColor)
		if endColor == nil then
			endColor = startColor
		end

		renderSetColorMaterialIgnoreZ()

		meshBegin(PRIMITIVE_LINES, 1)
			meshColor(startColor.r, startColor.g, startColor.b, startColor.a)

			meshPosition(startX, startY, 0)

			meshAdvanceVertex()

			meshColor(endColor.r, endColor.g, endColor.b, endColor.a)

			meshPosition(endX, endY, 0)

			meshAdvanceVertex()
		meshEnd()
	end

	local counts = {
		[PRIMITIVE_LINES] = function(len) return len / 6 end,
		[PRIMITIVE_LINE_STRIP] = function(len) return len / 6 end,
		[PRIMITIVE_LINE_LOOP] = function(len) return len / 6 - 1 end
	}

	function lines.drawBatchedLines(array)
		local primitiveType = array[-1] or PRIMITIVE_LINES

		renderSetColorMaterialIgnoreZ()

		meshBegin(primitiveType, counts[primitiveType](array[0]))
		if primitiveType == PRIMITIVE_LINES then
			for i = 1, array[0], 6 do
				local startX, startY, endX, endY = array[i], array[i + 1], array[i + 3], array[i + 4]
				local startColor, endColor = array[i + 2], array[i + 5]

				meshColor(startColor.r, startColor.g, startColor.b, startColor.a)
				meshPosition(startX, startY, 0)

				meshAdvanceVertex()

				meshColor(endColor.r, endColor.g, endColor.b, endColor.a)
				meshPosition(endX, endY, 0)

				meshAdvanceVertex()
			end
		elseif primitiveType == PRIMITIVE_LINE_STRIP then
			meshPosition(array[1], array[2], 0)

			local startColor = array[3]

			meshColor(startColor.r, startColor.g, startColor.b, startColor.a)

			meshAdvanceVertex()

			for i = 4, array[0], 6 do
				local x, y, color = array[i], array[i + 1], array[i + 2]

				meshPosition(x, y, 0)
				meshColor(color.r, color.g, color.b, color.a)

				meshAdvanceVertex()
			end
		else
			meshPosition(array[1], array[2], 0)

			local startColor = array[3]

			meshColor(startColor.r, startColor.g, startColor.b, startColor.a)

			meshAdvanceVertex()

			for i = 4, array[0] - 3, 6 do
				local x, y, color = array[i], array[i + 1], array[i + 2]

				meshPosition(x, y, 0)

				meshColor(color.r, color.g, color.b, color.a)

				meshAdvanceVertex()
			end
		end
		meshEnd()
	end
end

local batching = false

do
	function lines.startBatching()
		batching = true
		batch[-1] = PRIMITIVE_LINE_STRIP
		batch[0] = 0
	end

	function lines.stopBatching()
		local len = batch[0]

		if batch[-1] == PRIMITIVE_LINE_STRIP and batch[1] == batch[len - 2] and batch[2] == batch[len - 1] and batch[3] == batch[len] then
			batch[-1] = PRIMITIVE_LINE_LOOP
		end

		lines.drawBatchedLines(batch)

		batching = false

		batch = { [0] = 0 }
	end

	function lines.drawBatchedLine(startX, startY, endX, endY, startColor, endColor)
		if endColor == nil then
			endColor = startColor
		end

		local len = batch[0]

		if batch[-1] == PRIMITIVE_LINE_STRIP and batch[0] ~= 0 then
			if startX ~= batch[len - 2] or startY ~= batch[len - 1] or startColor ~= batch[len] then
				batch[-1] = PRIMITIVE_LINES
			end
		end

		batch[len + 1] = startX
		batch[len + 2] = startY
		batch[len + 3] = startColor
		batch[len + 4] = endX
		batch[len + 5] = endY
		batch[len + 6] = endColor
		batch[0] = len + 6
	end
end

do
	local drawSingleLine = lines.drawSingleLine
	local drawBatchedLine = lines.drawBatchedLine

	function lines.drawLine(startX, startY, endX, endY, startColor, endColor)
		if batching then
			drawBatchedLine(startX, startY, endX, endY, startColor, endColor)
		else
			drawSingleLine(startX, startY, endX, endY, startColor, endColor)
		end
	end
end

paint.lines = lines