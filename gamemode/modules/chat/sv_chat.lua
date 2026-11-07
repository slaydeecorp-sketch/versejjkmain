VERSE.Hook.ClearNS("Chat")

local Chat = VERSE.Chat
local cfg = Chat.Config
local L = VERSE.L
local Log = VERSE.Log

local _oocCooldowns = {}

VERSE.Hook.AddNS("Chat", "PlayerDisconnected", "VERSE::Chat::Cleanup", function(ply)
    if IsValid(ply) then _oocCooldowns[ply:SteamID64()] = nil end
end)

local function getICListeners(speaker, radius)
    local listeners = {}
    local speakerPos = speaker:GetPos()
    local radiusSqr = radius * radius
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and speakerPos:DistToSqr(ply:GetPos()) <= radiusSqr then
            listeners[#listeners + 1] = ply
        end
    end
    return listeners
end

local function truncateText(text)
    local maxLen = cfg.MaxMessageLen or 256
    local ok, charLen = pcall(utf8.len, text)
    local textLen = (ok and charLen) or #text
    if textLen > maxLen then
        local cutByte = utf8.offset(text, maxLen + 1)
        if cutByte then
            text = string.sub(text, 1, cutByte - 1)
        else
            text = string.sub(text, 1, maxLen)
        end
    end
    return text
end

local function sendMessage(listeners, data)
    netstream.Start(listeners, Chat.Net.Message, data)
end

VERSE.Hook.AddNS("Chat", "PlayerSay", "VERSE::Chat::PlayerSay", function(ply, text, teamChat)
    if not IsValid(ply) then return "" end
    if not cfg.Enabled then return end

    text = string.Trim(text)
    if text == "" then return "" end
    text = truncateText(text)

    local rpCh, rpArg = Chat:ParseRPCommand(text)
    if rpCh then
        local timestamp = os.date("%H:%M:%S")
        local nick = ply:Nick()

        if rpCh == Chat.CH_ME then
            local radius = cfg.MERadius or cfg.ICRadius or 600
            sendMessage(getICListeners(ply, radius), {
                channel = Chat.CH_ME,
                sender = ply:SteamID64(),
                name = nick,
                text = rpArg,
                time = timestamp,
            })
            Log:Info("[Chat][ME] " .. nick .. " " .. rpArg)
            return ""

        elseif rpCh == Chat.CH_DO then
            local radius = cfg.DORadius or cfg.ICRadius or 600
            sendMessage(getICListeners(ply, radius), {
                channel = Chat.CH_DO,
                sender = ply:SteamID64(),
                name = nick,
                text = rpArg,
                time = timestamp,
            })
            Log:Info("[Chat][IT] " .. nick .. ": " .. rpArg)
            return ""

        elseif rpCh == Chat.CH_NA then
            local radius = cfg.ICRadius or 600
            sendMessage(getICListeners(ply, radius), {
                channel = Chat.CH_NA,
                sender = ply:SteamID64(),
                name = nick,
                text = rpArg,
                time = timestamp,
            })
            Log:Info("[Chat][NA] " .. nick .. ": " .. rpArg)
            return ""

        elseif rpCh == Chat.CH_LOOC then
            local radius = cfg.LOOCRadius or 300
            sendMessage(getICListeners(ply, radius), {
                channel = Chat.CH_LOOC,
                sender = ply:SteamID64(),
                name = nick,
                text = rpArg,
                time = timestamp,
            })
            Log:Info("[Chat][LOOC] " .. nick .. ": " .. rpArg)
            return ""

        elseif rpCh == Chat.CH_ROLL then
            local result = math.random(1, 100)
            local rollText = L("chat.roll_result", { result = result, max = 100 })
            local radius = cfg.ROLLRadius or cfg.ICRadius or 600
            sendMessage(getICListeners(ply, radius), {
                channel = Chat.CH_ROLL,
                sender = ply:SteamID64(),
                name = nick,
                text = rollText,
                time = timestamp,
            })
            Log:Info("[Chat][ROLL] " .. nick .. ": " .. rollText)
            return ""

        elseif rpCh == Chat.CH_TRY then
            local success = math.random(0, 1) == 1
            local resultText = success and L("chat.try_success") or L("chat.try_fail")
            local radius = cfg.TRYRadius or cfg.ICRadius or 600
            sendMessage(getICListeners(ply, radius), {
                channel = Chat.CH_TRY,
                sender = ply:SteamID64(),
                name = nick,
                text = rpArg,
                extra = resultText,
                success = success,
                time = timestamp,
            })
            Log:Info("[Chat][TRY] " .. nick .. ": " .. rpArg .. " -> " .. resultText)
            return ""

        elseif rpCh == Chat.CH_YELL then
            local radius = cfg.YellRadius or 1200
            sendMessage(getICListeners(ply, radius), {
                channel = Chat.CH_YELL,
                sender = ply:SteamID64(),
                name = nick,
                text = rpArg,
                time = timestamp,
            })
            Log:Info("[Chat][YELL] " .. nick .. ": " .. rpArg)
            return ""

        elseif rpCh == Chat.CH_WHISPER then
            local radius = cfg.WhisperRadius or 150
            sendMessage(getICListeners(ply, radius), {
                channel = Chat.CH_WHISPER,
                sender = ply:SteamID64(),
                name = nick,
                text = rpArg,
                time = timestamp,
            })
            Log:Info("[Chat][WHISPER] " .. nick .. ": " .. rpArg)
            return ""
        end
    end

    if rpCh == Chat.CH_OOC then
        if not cfg.OOCEnabled then
            if isfunction(ply.Notify) then ply:Notify(L("chat.ooc_disabled"), NOTIFY_ERROR, 3) end
            return ""
        end

        local sid = ply:SteamID64()
        local now = CurTime()
        local cooldown = cfg.OOCCooldown or 3
        if (_oocCooldowns[sid] or 0) > now then
            local remaining = math.ceil(_oocCooldowns[sid] - now)
            if isfunction(ply.Notify) then
                ply:Notify(L("chat.ooc_cooldown", { sec = remaining }), NOTIFY_ERROR, 3)
            end
            return ""
        end

        _oocCooldowns[sid] = now + cooldown
        local oocText = rpArg or ""
        if oocText == "" then return "" end
        local timestamp = os.date("%H:%M:%S")
        sendMessage(player.GetAll(), {
            channel = Chat.CH_OOC,
            sender = ply:SteamID64(),
            name = ply:Nick(),
            text = oocText,
            time = timestamp,
        })
        Log:Info("[Chat][OOC] " .. ply:Nick() .. ": " .. oocText)
        return ""
    end

    local radius = cfg.ICRadius or 600
    local listeners = getICListeners(ply, radius)
    local timestamp = os.date("%H:%M:%S")
    sendMessage(listeners, {
        channel = Chat.CH_IC,
        sender = ply:SteamID64(),
        name = ply:Nick(),
        text = text,
        time = timestamp,
    })
    Log:Info("[Chat][IC] " .. ply:Nick() .. ": " .. text)
    return ""
end)

local _sayRL = {}

netstream.Hook(Chat.Net.ClientSay, function(ply, text)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not isstring(text) then return end
    text = string.Trim(text)
    if text == "" then return end

    local sid = ply:SteamID64()
    local now = CurTime()
    if (_sayRL[sid] or 0) > now then return end
    _sayRL[sid] = now + 0.3

    text = truncateText(text)
    local result = hook.Run("PlayerSay", ply, text, false)
    if isstring(result) and result == "" then return end
    if isstring(result) then text = result end
end)

VERSE.Hook.AddNS("Chat", "PlayerDisconnected", "VERSE::Chat::SayRLCleanup", function(ply)
    if IsValid(ply) then _sayRL[ply:SteamID64()] = nil end
end)
