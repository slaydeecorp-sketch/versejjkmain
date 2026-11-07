require("hook")
local G = _G
local file = file
local IsValid = IsValid
local assert = assert
local error = error
local pairs = pairs
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local CreateConVar = CreateConVar
local rawget = rawget
local setmetatable = setmetatable
local RunStringEx = RunStringEx
local FrameTime = FrameTime
local Color = Color
local len = string.len
local next = next
local type = type
local concommand = concommand
local player = player
local select = select
local net = net
local timer = timer
local string = string
local player = player
local util = util
local math = math
local hook = hook
local ipairs = ipairs
local unpack = unpack
local table = table
local bit = bit
local debug = debug
local _R = debug.getregistry()
CreateConVar("epoe_version", "2.62", FCVAR_NOTIFY)
local epoe_relay_msgall = CreateConVar("epoe_relay_msgall", "0")
module("epoe")
util.AddNetworkString(Tag)
local ift = 1 / FrameTime()
ift = ift > 100 and 100 or ift < 16 and 16 or ift
MSGS_IN_TICK = math.ceil((6 * ift) / (1 / 33))
MSGS_IN_TICK = MSGS_IN_TICK > 50 and 50 or MSGS_IN_TICK < 1 and 1 or MSGS_IN_TICK
local recover_time = FrameTime()
G._Msg = G._Msg or G.Msg
G._MsgC = G._MsgC or G.MsgC
G._MsgN = G._MsgN or G.MsgN
G._print = G._print or G.print
G._MsgAll = G._MsgAll or G.MsgAll
G._ErrorNoHalt = G._ErrorNoHalt or G.ErrorNoHalt
G._Error = G._Error or G.Error
RealMsg = G._Msg
RealMsgC = G._MsgC
RealMsgN = G._MsgN
RealPrint = G._print
RealMsgAll = G._MsgAll
RealErrorNoHalt = G._ErrorNoHalt
RealError = G._Error
Realerror = G.error
Sub = _M.Sub or {}
transmit = false
HasNoSubs = false
function GetTransmit()
	if transmit == false then
		transmit = {}
		local uids = {}
		for k, v in next, player.GetHumans() do
			uids[v:UserID()] = v
		end

		local gotsubs
		for k, v in next, Sub do
			local pl = uids[k]
			if pl then
				table.insert(transmit, pl)
				gotsubs = true
			end
		end

		if gotsubs then
			HasNoSubs = false
		else
			HasNoSubs = true
		end
	end
	return transmit
end

function RevalidateTransmit()
	transmit = false
	GetTransmit()
end

function AddSub(pl)
	if not pl or not pl.IsValid or not pl:IsValid() or not pl:IsPlayer() then return end
	local uid = pl:UserID()
	if Sub[uid] then return end
	Sub[uid] = true
	RevalidateTransmit()
	Transmit(IS_EPOE, "_S", pl)
end

function DelSub(pl, notrans)
	if not pl or not pl.IsValid or not pl:IsValid() or not pl:IsPlayer() then return end
	local uid = pl:UserID()
	if not Sub[uid] then return end
	Sub[uid] = nil
	RevalidateTransmit()
	if notrans then return end
	Transmit(IS_EPOE, "_US", pl)
end

function OnEntityRemoved(pl)
	if pl:IsPlayer() then DelSub(pl, true) end
end

hook.Add('EntityRemoved', TagHuman, OnEntityRemoved)
function CanSubscribe(pl, unsubscribe)
	return pl:IsDeveloper()
end

function OnSubCmd(pl, _, argz)
	if not (pl and pl.IsValid and pl:IsValid()) then return end
	local wantsub = util.tobool(argz[1] or "0")
	if wantsub then
		if CanSubscribe(pl) then
			AddSub(pl)
		else
			Transmit(IS_EPOE, "_NA", pl)
		end
	else
		DelSub(pl)
		CanSubscribe(pl, true)
	end
end

concommand.Add(Tag, OnSubCmd)
function GetSubscribers()
	return Sub
end

InEPOE = true
local Messages = _M.GetTable and _M.GetTable() or FIFO()
function GetTable()
	return Messages
end

function Recover()
	EnableTick()
	Messages:clear()
	InEPOE = false
	local payload = {
		flag = IS_EPOE,
		msg = "Queue reset! (Over " .. tostring(MaxQueue or "unknown") .. " messages pushed triggering safeguards)"
	}

	Messages:push(payload)
end

do
	function RecoverCatastrophe(n)
		EnableTick()
		InEPOE = false
		local payload = {
			flag = IS_EPOE,
			msg = "!!! Catastrophic EPOE error %s. Some messages have been lost! !!!."
		}

		payload.msg = payload.msg:format(tostring(n))
		Messages:push(payload)
	end

	local recover_count = 0
	local recover_count_max = 5
	function InEPOEChecker()
		if InEPOE then
			if not recover_count then return end
			if recover_count > recover_count_max then
				local Q = recover_count
				recover_count = false
				timer.Simple(15, function()
					recover_count_max = recover_count_max + 1
					recover_count = Q
				end)
				return
			end

			recover_count = recover_count + 1
			InEPOE = false
			RecoverCatastrophe(recover_count)
		end
	end

	timer.Create(TagHuman, 0.3, 0, InEPOEChecker)
end

local TickEnabled = false
function EnableTick()
	if TickEnabled then return end
	hook.Add('Tick', TagHuman, OnTick)
	TickEnabled = true
end

local EnableTick = EnableTick
function DisableTick()
	TickEnabled = false
	if not TickEnabled then return end
	hook.Remove('Tick', TagHuman)
end

local DisableTick = DisableTick
function HitMaxQueue()
	if Messages:len() > MaxQueue then
		DisableTick()
		Messages:clear()
		InEPOE = true
		timer.Simple(recover_time, Recover)
		return true
	end
end

function OnMsg(...)
	if InEPOE or HasNoSubs then
		pcall(RealMsg, ...)
	else
		InEPOE = true
		if HitMaxQueue() then return end
		EnableTick()
		local ok, str = pcall(ToStringEx, "", ...)
		if str then PushPayload(IS_MSG, str) end
		pcall(RealMsg, ...)
		InEPOE = false
	end
end

function PushMsgC(color, ...)
	local ok, str = pcall(ToStringEx, "", ...)
	if str then
		local msgc_col = color
		PushPayload(IS_MSGC, str, msgc_col)
	end
end

function OnMsgC(...)
	if InEPOE or HasNoSubs then
		pcall(RealMsgC, ...)
	else
		InEPOE = true
		if HitMaxQueue() then return end
		EnableTick()
		local last_col = col_white
		local vals = {}
		for i = 1, select('#', ...) do
			local v = select(i, ...)
			if IsColor(v) then
				if #vals > 0 then PushMsgC(last_col, unpack(vals)) end
				vals = {}
				last_col = v
			else
				table.insert(vals, v)
			end
		end

		if #vals > 0 then PushMsgC(last_col, unpack(vals)) end
		pcall(RealMsgC, ...)
		InEPOE = false
	end
end

function OnMsgN(...)
	if InEPOE or HasNoSubs then
		pcall(RealMsgN, ...)
	else
		InEPOE = true
		if HitMaxQueue() then return end
		EnableTick()
		local ok, str = pcall(ToStringEx, "", ...)
		if str then PushPayload(IS_MSGN, str) end
		pcall(RealMsgN, ...)
		InEPOE = false
	end
end

function OnPrint(...)
	if InEPOE or HasNoSubs then
		pcall(RealPrint, ...)
	else
		InEPOE = true
		if HitMaxQueue() then return end
		EnableTick()
		local ok, str = pcall(ToStringEx, " ", ...)
		if str then PushPayload(IS_PRINT, str) end
		pcall(RealPrint, ...)
		InEPOE = false
	end
end

function OnMsgAll(...)
	if InEPOE or HasNoSubs then
		pcall(RealMsgAll, ...)
	else
		InEPOE = true
		if HitMaxQueue() then return end
		EnableTick()
		local ok, str = pcall(ToStringEx, " ", ...)
		if str and epoe_relay_msgall:GetBool() then PushPayload(IS_MSG, str) end
		pcall(RealMsgAll, ...)
		InEPOE = false
	end
end

function OnLuaError(str)
	if InEPOE or HasNoSubs then return end
	InEPOE = true
	if HitMaxQueue() then return end
	EnableTick()
	PushPayload(IS_ERROR, tostring(str))
	InEPOE = false
end

function OnClientLuaError(str)
	if InEPOE or HasNoSubs then return end
	InEPOE = true
	if HitMaxQueue() then return end
	EnableTick()
	PushPayload(IS_CERROR, tostring(str))
	InEPOE = false
end

function OnLuaErrorNoHalt(...)
	if InEPOE or HasNoSubs then
		pcall(RealErrorNoHalt, ...)
	else
		InEPOE = true
		if HitMaxQueue() then return end
		EnableTick()
		local ok, str = pcall(ToStringEx, " ", ...)
		if str then PushPayload(IS_ERROR, str:gsub("\n$", ""), false) end
		pcall(RealErrorNoHalt, ...)
		InEPOE = false
	end
end

function OnError(...)
	if InEPOE or HasNoSubs then
		pcall(RealError, ...)
	else
		InEPOE = true
		if HitMaxQueue() then return end
		EnableTick()
		local ok, str = pcall(ToStringEx, " ", ...)
		if str then PushPayload(IS_ERROR, str:gsub("\n$", ""), false) end
		pcall(RealError, ...)
		InEPOE = false
	end
end

local api = rawget(_M, "api") or {}
function api.Msg(...)
	if HitMaxQueue() then return end
	EnableTick()
	local ok, str = pcall(ToStringEx, "", ...)
	if str then PushPayload(IS_MSG, str) end
end

local function PushMsgC(color, ...)
	local ok, str = pcall(ToStringEx, "", ...)
	if str then
		local msgc_col = color
		PushPayload(IS_MSGC, str, msgc_col)
	end
end

function api.MsgC(...)
	if HitMaxQueue() then return end
	EnableTick()
	local last_col = col_white
	local vals = {}
	for i = 1, select('#', ...) do
		local v = select(i, ...)
		if IsColor(v) then
			if #vals > 0 then PushMsgC(last_col, unpack(vals)) end
			vals = {}
			last_col = v
		else
			table.insert(vals, v)
		end
	end

	if #vals > 0 then PushMsgC(last_col, unpack(vals)) end
end

function api.MsgN(...)
	if HitMaxQueue() then return end
	EnableTick()
	local ok, str = pcall(ToStringEx, "", ...)
	if str then PushPayload(IS_MSGN, str) end
end

function api.print(...)
	if HitMaxQueue() then return end
	EnableTick()
	local ok, str = pcall(ToStringEx, " ", ...)
	if str then PushPayload(IS_PRINT, str) end
end

function api.MsgAll(...)
	if HitMaxQueue() then return end
	EnableTick()
	local ok, str = pcall(ToStringEx, " ", ...)
	if str and epoe_relay_msgall:GetBool() then PushPayload(IS_MSG, str) end
end

function api.ClientLuaError(str)
	if HitMaxQueue() then return end
	EnableTick()
	PushPayload(IS_CERROR, tostring(str))
end

function api.ErrorNoHalt(...)
	if HitMaxQueue() then return end
	EnableTick()
	local ok, str = pcall(ToStringEx, " ", ...)
	if str then PushPayload(IS_ERROR, str:gsub("\n$", ""), false) end
end

function api.error(...)
	if HitMaxQueue() then return end
	EnableTick()
	local ok, str = pcall(ToStringEx, " ", ...)
	if str then PushPayload(IS_ERROR, str:gsub("\n$", ""), false) end
end

for k, v in next, api do
	G['E' .. k] = v
end

_M.api = api
function SamePayload(a, b)
	if a == b then return true end
	if not a or not b then return false end
	return a.flag == b.flag and a.msg == b.msg
end

function DoPush(payload)
	Messages:push(payload)
end

function PushPayload(flags, text, msgc_col)
	local txt, i = true, 1
	local size = 190
	local textlen = #text
	local first = true
	while txt and txt ~= "" do
		txt = text:sub(i, i + size - 1)
		i = i + size
		if txt ~= "" or first then
			local curflags = flags
			if textlen >= i then curflags = bit.bor(flags, IS_SEQ) end
			local payload = {
				flag = curflags,
				msg = txt
			}

			if msgc_col then payload.msgc_col = msgc_col end
			DoPush(payload)
		end

		first = false
		if i > 63 * 1024 then
			EnableTick()
			Messages:clear()
			InEPOE = false
			Messages:push{
				flag = IS_EPOE,
				msg = "Cancelling messages, too many iterations."
			}
			return
		end
	end
end

function Transmit(flags, msg, targets, msgc_col)
	net.Start(Tag)
	net.WriteUInt(flags, 8)
	if HasMsgCParams(flags) then
		msgc_col = msgc_col and IsColor(msgc_col) and msgc_col or col_error
		net.WriteUInt(msgc_col.r, 8)
		net.WriteUInt(msgc_col.g, 8)
		net.WriteUInt(msgc_col.b, 8)
	end

	net.WriteString(msg)
	net.Send(targets == true and GetTransmit() or targets)
end

function DoTransmit()
	local payload = Messages:pop()
	if payload == nil then return true end
	local flags = payload.flag or 0
	assert(flags >= 0)
	assert(flags <= 255)
	local msg = payload.msg or "EPOE ERROR"
	local msgc_col = payload.msgc_col
	Transmit(flags, msg, true, msgc_col)
end

function OnTick()
	if InEPOE then return end
	InEPOE = true
	if HasNoSubs then
		Messages:clear()
	elseif not HitMaxQueue() and Messages:len() > 0 then
		for i = 1, MSGS_IN_TICK do
			if DoTransmit() then
				DisableTick()
				break
			end
		end
	end

	InEPOE = false
end

function Initialize()
	InEPOE = true
	G.Msg = OnMsg
	G.MsgC = OnMsgC
	G.MsgN = OnMsgN
	G.print = OnPrint
	G.MsgAll = OnMsgAll
	G.ErrorNoHalt = OnLuaErrorNoHalt
	G.Error = OnError
	local module_loaded = false
	local luaerror2_loaded = false
	if luaerror2_loaded then
		luaerror2_loaded = false
		hook.Add("LuaError", TagHuman, function()
			luaerror2_loaded = true
			return true
		end)

		RunStringEx("if_you_see_this__remove_luaerror2()", "EPOE")
		hook.Remove("LuaError", TagHuman)
	end

	if not module_loaded and luaerror2_loaded then
		module_loaded = true
		local inhook = false
		hook.Add("LuaError", TagHuman, function(runtime, srcfile, srcline, err, stack)
			if inhook then return end
			inhook = true
			local stackinfo = {}
			for level, info in ipairs(stack or {}) do
				local msg
				if info.what == "C" then
					msg = "C"
				else
					msg = tostring(info.short_src) .. ':' .. tostring(info.currentline) .. ' \t(' .. tostring(info.name or "") .. ')'
				end

				if msg then table.insert(stackinfo, level .. (level > 9 and ' ' or '  ') .. msg) end
			end

			err = err .. (#stackinfo > 0 and '\n\t' .. table.concat(stackinfo, "\n\t") .. '\n' or "")
			OnLuaError(err)
			inhook = false
		end)

		local preverror
		hook.Add("ClientLuaError", TagHuman, function(pl, err)
			if err and err:sub(1, 9) == "\n[ERROR] " then
				err = err:sub(10, -1)
			elseif err then
				err = err:gsub("^\n", '')
			end

			err = err and err:gsub("\n$", '')
			if preverror == err then
				OnClientLuaError(tostring(pl) .. ' DUPLICATE ERROR')
			else
				OnClientLuaError(tostring(pl) .. ' ERROR: ' .. tostring(err))
				preverror = err
			end
		end)
	end

	InEPOE = false
	if module_loaded then
		if luaerror2_loaded then
			G.print"[EPOE] Tested and operational! (Using LuaError2)"
		else
			G.print"[EPOE] Tested and operational! (Using EngineSpew)"
		end
	elseif not file.Exists("cfg/epoe_block_registryhack.cfg", 'MOD') and debug.getregistry and debug.getregistry() and type(_R[1]) == "function" then
		local function RelayRegistry(err)
			OnLuaError(err)
		end

		if type(_R[1]) == "function" then
			EPOE_REGISTRY_1_ORIG = EPOE_REGISTRY_1_ORIG or _R[1]
			G.print"[EPOE WARNING] Loaded, but EngineSpew/LuaError2 are not working! \n\t Error viewing will use a hacky system! \n\t In addition, clientside errors cannot be shown! \n\t Disable by creating the following file: cfg/epoe_block_registryhack.cfg"
			_R[1] = function(...)
				if InEPOE then return end
				InEPOE = true
				local err = table.concat{...}
				InEPOE = false
				local ok, err = pcall(RelayRegistry, debug.traceback(err, 2))
				InEPOE = true
				if not ok then RealPrint(err) end
				InEPOE = false
				return EPOE_REGISTRY_1_ORIG(...)
			end
		else
			G.print"[EPOE WARNING] Loaded, but EngineSpew/LuaError2 are not working! ERRORS CANNOT BE SHOWN!"
		end
	end
end

Initialize()