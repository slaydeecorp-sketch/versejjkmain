local R = VERSE.Responsive
local Materials = VERSE.Materials
local Font = VERSE.Fonts
VERSE.WeaponSelector = VERSE.WeaponSelector or {}
local WS = VERSE.WeaponSelector

local timeout = -math.huge
local Config = {
	CircleSize = 365,
	CircleOutline = 5,
	CirclePosX = 1718,
	CirclePosY = 323,
	SlotSelected = 97,
	SlotOther = 67,
	DefaultIconAlias = "hud_hand_icon",
	DefaultIconW = 28,
	DefaultIconH = 28,
	IconFit = 0.62,
	SlotGap = 12,
	ArcBaseAngle = 180,
	ArcRadiusPad = 0,
	EaseFrequency = 2,
	EaseDamping = 0.75,
	EaseResponse = 0.5,
	Ease2Frequency = 1,
	Ease2Damping = 0.5,
	Ease2Response = 2,
	FontName = "Poppins",
	FontWeight = "Bold",
	FontSize = 20,
	TextShadowOff = -2,
	TextSlotPadding = 20,
	FadeMin = 0.18,
}

local WepIcons = {
	["gmod_camera"] = {
		alias = "hud_camera",
		w = 32,
		h = 28
	},
	["verse_freecam"] = {
		alias = "hud_camera",
		w = 32,
		h = 28
	},
	["yuji_swep"] = {
		alias = "hud_combat_icon",
		w = 47,
		h = 44
	},
}

VERSE.Hook.AddNS("WeaponSelector", "InitPostEntity", "VERSE::InitPostEntity::WeaponSelector", function()
	Materials:SetAlias("hud_big_background", "verse/weapon_selector/big_background")
	Materials:SetAlias("hud_mini_background", "verse/weapon_selector/mini_background")
	Materials:SetAlias("hud_hand_icon", "verse/weapon_selector/hand_icon")
	Materials:SetAlias("hud_combat_icon", "verse/weapon_selector/combat_icon")
	Materials:SetAlias("hud_camera", "verse/weapon_selector/camera")
end)

local easing = VERSE.Sod:new(Config.EaseFrequency, Config.EaseDamping, Config.EaseResponse, Vector(0, 0, 0))
local easing2 = VERSE.Sod:new(Config.Ease2Frequency, Config.Ease2Damping, Config.Ease2Response, Vector(0, 0, 0))
local replacements = {}
for char, lookingLike in pairs({
	a = {"а", "à", "â", "ã", "å"},
	e = {"е", "è", "é", "ê", "ê", "ë"},
	i = {"ì", "í", "î", "ï"},
	o = {"о", "ó", "ò", "ô", "õ"},
	u = {"ù", "ú", "û", "ü"},
	c = {"с", "ç"},
	n = {"ñ"}
}) do
	for _, i in ipairs(lookingLike) do
		replacements[i] = char
	end
end

local function cleanupText(text)
	if not text or text == "" then return "" end
	if string.StartsWith(text, "#") then text = language.GetPhrase(text) end
	return string.upper(string.gsub(text, "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*", replacements))
end

local function SlotSort(a, b)
	return a and b and a.Slot and b.Slot and a.Slot < b.Slot
end

local function CopyVals(src, dest)
	table.Empty(dest)
	for _, v in pairs(src) do
		if not IsValid(v) then continue end
		table.insert(dest, v)
	end
end

local function getCurrentIndex(pPlayer)
	if not IsValid(pPlayer) then return 1 end
	local weaponList = pPlayer:GetWeapons()
	return table.KeyFromValue(weaponList, pPlayer:GetActiveWeapon()) or 1
end

local function fetchLocalPlayer()
	if not isfunction(LocalPlayer) then return end
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	return ply, getCurrentIndex(ply)
end

local pLocalPlayer, nCurrentIndex = fetchLocalPlayer()
local weaponsCache = {}
local function updateWeaponCache()
	weaponsCache = {}
	CopyVals(pLocalPlayer:GetWeapons(), weaponsCache)
	table.sort(weaponsCache, SlotSort)
end

-- ─── Couleurs pré-allouées pour WeaponSelector (évite Color() par frame) ──────
local _WS_COL_CIRCLE_A  = Color(255, 255, 255, 255)   -- .a muté
local _WS_COL_CIRCLE_B  = Color(0x50, 0x50, 0x50, 255) -- .a muté
local _WS_COL_SLOT      = Color(255, 255, 255, 255)   -- .a muté
local _WS_COL_TEXT_SHD  = Color(0,   0,   0,   255)   -- .a muté
local _WS_COL_TEXT      = Color(255, 255, 255, 255)   -- .a muté

local _cachedFontKey, _cachedFontName = nil, nil
local function getFont()
	local fs = R:RS(Config.FontSize)
	local key = tostring(fs)
	if key ~= _cachedFontKey then
		_cachedFontKey = key
		_cachedFontName = Font:GetNamed(Config.FontName, Config.FontWeight, fs)
	end
	return _cachedFontName
end

local function computeDynamicCircleSizePx(baseCircleSize, orbitPad, slotMini, slotBig, gapPx, n)
	if n <= 1 then return baseCircleSize end
	local stepArc = slotMini + gapPx
	local extra = math.max(0, slotBig - slotMini)
	local requiredCirc = (n * stepArc) + extra
	local requiredOrbitR = requiredCirc / (2 * math.pi)
	local requiredRadius = math.max(1, requiredOrbitR - orbitPad)
	local neededCircleSize = requiredRadius * 2
	return math.max(baseCircleSize, neededCircleSize)
end

local function deltaToAngleDeg(delta, orbitPx)
	local theta = (delta * orbitPx.stepPx) / orbitPx.r
	return math.deg(theta)
end

local function getIconForWeapon(wep, slotSz, slotBig)
	local cls = IsValid(wep) and wep:GetClass() or nil
	local spec = (cls and WepIcons[cls]) or nil
	local alias, refW, refH
	if spec then
		alias, refW, refH = spec.alias, spec.w, spec.h
	else
		alias, refW, refH = Config.DefaultIconAlias, Config.DefaultIconW, Config.DefaultIconH
	end

	local w = R:S(refW)
	local h = R:S(refH)
	local slotRatio = (slotBig > 0) and (slotSz / slotBig) or 1
	local maxSide = math.max(w, h)
	local fitMax = slotSz * Config.IconFit
	local fitScale = (maxSide > 0) and math.min(1, fitMax / maxSide) or 1
	local scale = slotRatio * fitScale
	return alias, w * scale, h * scale
end

local playedClosing = false
function WS:ForceClose()
	timeout = -math.huge
	self._suppressSkillSlotsUntil = 0
	playedClosing = false
end

function WS:IsOpen()
	return timeout + 2 >= RealTime()
end

function WS:SuppressSkillSlots(duration)
	duration = math.max(0, tonumber(duration) or 0)
	self._suppressSkillSlotsUntil = math.max(tonumber(self._suppressSkillSlotsUntil) or 0, RealTime() + duration)
end

function WS:GetSkillSlotSuppressUntil()
	return tonumber(self._suppressSkillSlotsUntil) or 0
end

WS:ForceClose()

local function WeaponSelector()
	if not IsValid(pLocalPlayer) then pLocalPlayer, nCurrentIndex = fetchLocalPlayer() end
	if not IsValid(pLocalPlayer) then return end
	updateWeaponCache()
	local n = #weaponsCache
	if n <= 0 then return end
	nCurrentIndex = math.Clamp(nCurrentIndex or 1, 1, n)
	local baseCircleSize = R:S(Config.CircleSize)
	local circleOutline = R:S(Config.CircleOutline)
	local slotBig = R:S(Config.SlotSelected)
	local slotMini = R:S(Config.SlotOther)
	local gapPx = R:S(Config.SlotGap)
	local textPad = R:S(Config.TextSlotPadding)
	local baseX = R:X(Config.CirclePosX)
	local baseY = R:Y(Config.CirclePosY)
	local orbitPad = R:S(Config.ArcRadiusPad)
	local circleSize = computeDynamicCircleSizePx(baseCircleSize, orbitPad, slotMini, slotBig, gapPx, n)
	local offset = circleSize * 0.33
	local alpha = 1
	if timeout ~= 0 and timeout + 2 < RealTime() then
		offset = circleSize / 2
		alpha = 0
		if not playedClosing then playedClosing = true end
	end

	local currentIndex = easing:Update(RealFrameTime(), Vector(nCurrentIndex, offset, alpha))
	local currentIndex2 = easing2:Update(RealFrameTime(), Vector(nCurrentIndex, 0, alpha))
	if currentIndex.z < 0.01 then return end
	if currentIndex.z > 0.99 then playedClosing = false end
	surface.SetAlphaMultiplier(currentIndex.z)
	local cxTL = baseX + currentIndex.y
	local cyTL = baseY
	local cx = cxTL + circleSize * 0.5
	local cy = cyTL + circleSize * 0.5
	local _alphaZ = math.floor(255 * currentIndex.z)
	_WS_COL_CIRCLE_A.a = _alphaZ
	_WS_COL_CIRCLE_B.a = _alphaZ
	RNDX().Circle(cx, cy, circleSize):Color(_WS_COL_CIRCLE_A):Outline(circleOutline):Draw()
	RNDX().Circle(cx, cy, circleSize - circleOutline * 0.8):Color(_WS_COL_CIRCLE_B):Outline(math.max(1, circleOutline * 0.45)):Draw()
	local radius = circleSize * 0.5
	local orbitR = radius + orbitPad
	local orbitPx = {
		r = math.max(orbitR, 1),
		stepPx = slotMini + gapPx,
	}

	local baseAng = Config.ArcBaseAngle
	local sel_sx, sel_sy, sel_slotSz = nil, nil, nil
	for i, wep in ipairs(weaponsCache) do
		if not IsValid(wep) then continue end
		local isSelected = i == nCurrentIndex
		local slotSz = isSelected and slotBig or slotMini
		local bg = isSelected and "hud_big_background" or "hud_mini_background"
		local delta = i - currentIndex.x
		local angDeg = baseAng + deltaToAngleDeg(delta, orbitPx)
		local ang = math.rad(angDeg)
		local sx = cx + orbitR * math.cos(ang)
		local sy = cy + orbitR * math.sin(ang)
		if isSelected then sel_sx, sel_sy, sel_slotSz = sx, sy, slotSz end
		local fade = math.Clamp(1 - (math.abs(delta) * 0.35), Config.FadeMin, 1) * currentIndex2.z
		-- Mutation de la couleur pré-allouée (évite Color() à chaque slot par frame)
		_WS_COL_SLOT.a = isSelected and 255 or math.floor(255 * fade)
		Materials:Draw(_WS_COL_SLOT, bg, sx - slotSz * 0.5, sy - slotSz * 0.5, slotSz, slotSz)
		local iconAlias, iconW, iconH = getIconForWeapon(wep, slotSz, slotBig)
		Materials:Draw(color_white, iconAlias, sx - iconW * 0.5, sy - iconH * 0.5, iconW, iconH)
	end

	if sel_sx and sel_sy and sel_slotSz then
		local fontName = getFont()
		local active = weaponsCache[nCurrentIndex]
		local text = cleanupText(IsValid(active) and (active:GetPrintName() or "Unknown") or "Unknown")
		local _, th = VERSE.GetTextSize(text, fontName)
		local shadow = R:S(Config.TextShadowOff)
		local tx = (sel_sx - sel_slotSz * 0.5) - textPad
		local ty = sel_sy - th * 0.5
		_WS_COL_TEXT_SHD.a = _alphaZ
		_WS_COL_TEXT.a     = _alphaZ
		draw.SimpleText(text, fontName, tx - shadow, ty - shadow, _WS_COL_TEXT_SHD, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText(text, fontName, tx, ty, _WS_COL_TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
end

VERSE.Hook.AddNS("WeaponSelector", "HUDPaint", "VERSE::HUDPaint::WeaponSelector", WeaponSelector)
VERSE.Hook.AddNS("WeaponSelector", "PlayerBindPress", "VERSE::PlayerBindPress::WeaponSelector", function(ply, bind, pressed)
	if timeout > RealTime() then return end
	if bind == "invnext" and pressed then
		local newIndex = math.min((nCurrentIndex or 1) + 1, #weaponsCache)
		if newIndex ~= nCurrentIndex then
			nCurrentIndex = newIndex
			timeout = RealTime() + 0.05
			WS:SuppressSkillSlots(0.25)
		end
		return true
	elseif bind == "invprev" and pressed then
		local newIndex = math.max((nCurrentIndex or 1) - 1, 1)
		if newIndex ~= nCurrentIndex then
			nCurrentIndex = newIndex
			timeout = RealTime() + 0.05
			WS:SuppressSkillSlots(0.25)
		end
		return true
	end

	if timeout + 2 < RealTime() then return end
	if bind == "+attack" then
		local currentWep = weaponsCache[nCurrentIndex or 1]
		if not IsValid(currentWep) then return end
		WS:SuppressSkillSlots(0.25)
		input.SelectWeapon(currentWep)
		timeout = RealTime() - 2
		return true
	end
end)
