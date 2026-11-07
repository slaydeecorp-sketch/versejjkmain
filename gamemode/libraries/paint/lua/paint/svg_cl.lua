local svg = {}
local paint = paint

paint.svg = svg

do
	local sub = string.sub
	local color = Color

	local function fromHex(hex)
		local ind = sub(hex, 1, 1) == '#' and 1 or 0
		local r, g, b, a = hex:sub(1 + ind, 2 + ind), hex:sub(3 + ind, 4 + ind), hex:sub(5 + ind, 6 + ind), hex:sub(7 + ind, 8 + ind)
		r, g, b, a = tonumber(r, 16) or 255, tonumber(g, 16) or 255, tonumber(b, 16) or 255, a ~= '' and tonumber(a, 16) or 255
		return color(r, g, b, a)
	end

	local colors = {
		['black'] = color(0, 0, 0),
		['silver'] = fromHex('#c0c0c0'),
		['gray'] = fromHex('#808080'),
		['white'] = color(255, 255, 255),
		['maroon'] = fromHex('#800000'),
		['red'] = color(255, 0, 0),
		['purple'] = fromHex('#800080'),
		['fuchsia'] = fromHex('#ff00ff'),
		['green'] = color(0, 255, 0),
		['lime'] = fromHex('#00ff00'),
		['olive'] = fromHex('#808000'),
		['yellow'] = fromHex('#ffff00'),
		['navy'] = fromHex('#000080'),
		['blue'] = color(0, 0, 255),
		['teal'] = fromHex('#008080'),
		['aqua'] = fromHex('#00ffff'),
		['aliceblue'] = fromHex('#F0F8FF'),
		['pink'] = fromHex('#FFC0CB')
	}

	colors.fromHex = fromHex
	svg.colors = colors
end

do
	local parsers = {}

	local function addParser(tag, parser)
		parsers[tag] = parser
	end

	local match = string.match
	local sub = string.sub

	local parseColor
	do
		local colors = svg.colors
		local black = Color(0, 0, 0)

		local function parseColorValue(color)
			if colors[color:lower()] then
				return colors[color:lower()]
			elseif sub(color, 1, 1) == '#' then
				return colors.fromHex(color)
			else
				return black
			end
		end

		function parseColor(tag, name)
			return parseColorValue(match(tag, name .. ' ?=["\']([%w%d#().]+)["\']') or '')
		end
	end

	local parseSize
	do
		local tonumber = tonumber
		local function createPercentFunc(val)
			local percent = tonumber(sub(val, 1, -2)) / 100
			return function(height)
				return height * percent
			end
		end

		local function createAbsoluteFunc(val)
			val = tonumber(val) or 0
			return function()
				return val
			end
		end

		local patternSafe = string.PatternSafe

		function parseSize(tag, name, name2)
			name = patternSafe(name)

			if name2 then
				name2 = patternSafe(name2)
			end

			do
				local x = match(tag, name .. ' ?=["\'](.-)["\']')
				local y = match(tag, (name2 or name) .. ' ?=["\'](.-)["\']')

				local xFunc, yFunc
				if x and sub(x, -1, -1) == '%' then
					xFunc = createPercentFunc(x)
				else
					xFunc = createAbsoluteFunc(x)
				end

				if y and sub(y, -1, -1) == '%' then
					yFunc = createPercentFunc(y)
				else
					yFunc = createAbsoluteFunc(y)
				end

				if name2 then
					return function(w, h)
						return xFunc(w), yFunc(h)
					end
				end

				return function(w, h)
					return xFunc( (w + h) / 2 )
				end
			end

		end
	end

	addParser('rect', function(tag)
		local tab = {}

		tab.pos = parseSize(tag, 'x', 'y')
		tab.size = parseSize(tag, 'width', 'height')

		local radiusSize = parseSize(tag, 'rx', 'ry')

		tab.radius = function(w, h)
			local rx, ry = radiusSize(w, h)

			return (rx + ry) / 2
		end

		tab.strokeWidth = parseSize(tag, 'stroke-width')

		do
			tab.fill = parseColor(tag, 'fill')
			tab.stroke = parseColor(tag, 'stroke')
		end

		return tab
	end)

	addParser('circle', function(tag)
		local tab = {}

		tab.pos = parseSize(tag, 'cx', 'cy')
		tab.radius = parseSize(tag, 'r')

		do
			tab.fill = parseColor(tag, 'fill')
			tab.stroke = parseColor(tag, 'stroke')
		end

		tab.strokeWidth = parseSize(tag, 'stroke-width')

		return tab
	end)

	addParser('svg', function(tag)
		local tab = {}

		local x, y, w, h = match(tag, 'viewBox ?=["\'] ?(%d+) (%d+) (%d+) (%d+) ?["\']')

		w = w or match(tag, 'width ?=["\'](%d+)["\']')
		h = h or match(tag, 'height ?=["\'](%d+)["\']')

		x = x or match(tag, 'x ?=["\'](%d+)["\']')
		y = y or match(tag, 'y ?=["\'](%d+)["\']')

		tab.x = tonumber(x)
		tab.y = tonumber(y)
		tab.width = tonumber(w)
		tab.height = tonumber(h)

		return tab
	end)

	svg.parsers = parsers
end

do
	local constructors = {}

	local function addConstructor(tag, constructor)
		constructors[tag] = constructor
	end

	do
		local min = math.min
		local roundedBox = paint.roundedBoxes.roundedBox
		local drawOutline = paint.outlines.drawOutline
		addConstructor('rect', function(obj, settings)
			local x, y = obj.pos(settings.w, settings.h)
			local w, h = obj.size(settings.w, settings.h)

			local strokeWidth = obj.strokeWidth(settings.w, settings.h)

			local radiusVal = min(w, h) / 2
			local radius = obj.radius(radiusVal, radiusVal)

			local fill = obj.fill
			local stroke = obj.stroke

			roundedBox(radius, x + settings.x, y + settings.y, w, h, fill)

			if strokeWidth > 0 then
				drawOutline(radius, x + settings.x, y + settings.y, w, h, stroke, nil, strokeWidth)
			end
		end)
	end

	do
		local drawCircle = paint.circles.drawCircle
		local drawOutlinedCircle = paint.circles.drawOutline
		addConstructor('circle', function(obj, settings)
			local x, y = obj.pos(settings.w, settings.h)
			local radius = obj.radius(settings.w, settings.h)

			local fill = obj.fill
			local stroke = obj.stroke

			drawCircle(x + settings.x, y + settings.y, radius, radius, fill, settings.circleVertexCount)

			local strokeWidth = obj.strokeWidth(radius, radius)

			if strokeWidth > 0 then
				drawOutlinedCircle(x + settings.x, y + settings.y, radius, radius, stroke, strokeWidth, settings.circleVertexCount)
			end
		end)
	end

	addConstructor('svg', function(obj, settings)
		settings.w = obj.width or settings.w
		settings.h = obj.height or settings.h

		settings.x = obj.x or settings.x
		settings.y = obj.y or settings.y
	end)

	svg.constructors = constructors
end

do
	local gmatch = string.gmatch
	local match = string.match
	local parsers = svg.parsers

	function svg.parseSVG(svgText)
		local parsingTab = {}
		local index = 0

		for tag in gmatch(svgText, '<(.-)>') do
			local nameOfTag = match(tag, '^(%w+)') or 'undefined'
			if parsers[nameOfTag] then
				local tab = parsers[nameOfTag](tag)
				tab[0] = nameOfTag

				index = index + 1
				parsingTab[index] = tab
			elseif nameOfTag ~= 'undefined' then
				print('[paint] Cant parse <' .. nameOfTag .. '> tag. Not implemented yet')
			end
		end

		return parsingTab
	end

	local startBatching = paint.batch.startBatching
	local stopBatching = paint.batch.stopBatching
	local constructors = svg.constructors

	function svg.generateIMesh(tab, settings)
		settings = settings or {w = 0, h = 0, x = 0, y = 0}
		startBatching()

		for k, v in ipairs(tab) do
			local type = v[0]

			if constructors[type] then
				constructors[type](v, settings)
			else
				print('[paint] Cant construct IMesh from ' .. type .. ' type. Not implemented yet.')
			end
		end

		return stopBatching()
	end
end