VERSE.Chat = VERSE.Chat or {}
local Chat = VERSE.Chat
Chat.CH_ALL = 1
Chat.CH_IC = 2
Chat.CH_OOC = 3
Chat.CH_ME = 4
Chat.CH_DO = 5
Chat.CH_LOOC = 6
Chat.CH_ROLL = 7
Chat.CH_TRY = 8
Chat.CH_YELL = 9
Chat.CH_WHISPER = 10
Chat.CH_ROLEPLAY = 11
Chat.CH_NA = 12
Chat.ChannelNames = {
    [Chat.CH_ALL] = "chat.ch_all",
    [Chat.CH_IC] = "chat.ch_ic",
    [Chat.CH_OOC] = "chat.ch_ooc",
    [Chat.CH_ME] = "chat.ch_me",
    [Chat.CH_DO] = "chat.ch_do",
    [Chat.CH_LOOC] = "chat.ch_looc",
    [Chat.CH_ROLL] = "chat.ch_roll",
    [Chat.CH_TRY] = "chat.ch_try",
    [Chat.CH_YELL] = "chat.ch_yell",
    [Chat.CH_WHISPER] = "chat.ch_whisper",
    [Chat.CH_ROLEPLAY] = "chat.ch_roleplay",
}

Chat.Config = {
    Enabled = true,
    ICRadius = 600,
    YellRadius = 1200,
    WhisperRadius = 150,
    LOOCRadius = 300,
    OOCEnabled = true,
    OOCCooldown = 3,
    MaxMessageLen = 1024,
    MessageLifetime = 15,
    MaxHistory = 128,
    AutoScroll = true,
    FontName = "Poppins",
    FontWeight = "Regular",
    FontSize = 24,
    ChatW = 621,
    ChatH = 373,
    ChatX = 30,
    ChatY = 1080 - 373 - 430,
    SoundEnabled = true,
    SoundVolume = 50,
    ShowTimestamps = true,
    MERadius = 600,
    DORadius = 600,
    ROLLRadius = 600,
    TRYRadius = 600,
    OOCGlobal = true,
    LOOCGlobal = false,
    ICCooldown = 0,
    MECooldown = 0,
    YellCooldown = 2,
    WhisperCooldown = 0,
}

Chat.Net = {
    Message = "VERSE::Chat::Message",
    ClientSay = "VERSE::Chat::ClientSay",
}

Chat.TryFailColor = Color(255, 100, 100)
Chat.TAB_ALL = "ALL"
Chat.TAB_IC = "IC"
Chat.TAB_OOC = "OOC"
Chat.Tabs = {Chat.TAB_ALL, Chat.TAB_IC, Chat.TAB_OOC}
Chat.Pill = {
    [Chat.CH_IC] = {
        label = "IC",
        tab = Chat.TAB_IC,
        bg = Color(50, 50, 55),
        text = Color(200, 200, 200),
        msg = Color(230, 230, 230),
    },
    [Chat.CH_OOC] = {
        label = "OOC",
        tab = Chat.TAB_OOC,
        bg = Color(55, 50, 70),
        text = Color(200, 192, 255),
        msg = Color(200, 192, 255),
    },
    [Chat.CH_ME] = {
        label = "ME",
        tab = Chat.TAB_IC,
        bg = Color(70, 50, 20),
        text = Color(255, 180, 80),
        msg = Color(255, 165, 50),
    },
    [Chat.CH_DO] = {
        label = "IT",
        tab = Chat.TAB_IC,
        bg = Color(70, 65, 20),
        text = Color(255, 230, 80),
        msg = Color(255, 220, 50),
    },
    [Chat.CH_NA] = {
        label = "NA",
        tab = Chat.TAB_IC,
        bg = Color(70, 25, 25),
        text = Color(255, 120, 120),
        msg = Color(255, 80, 80),
    },
    [Chat.CH_LOOC] = {
        label = "LOOC",
        tab = Chat.TAB_OOC,
        bg = Color(55, 55, 35),
        text = Color(220, 220, 150),
        msg = Color(200, 200, 120),
    },
    [Chat.CH_ROLL] = {
        label = "ROLL",
        tab = Chat.TAB_IC,
        bg = Color(30, 60, 30),
        text = Color(130, 240, 130),
        msg = Color(100, 220, 100),
    },
    [Chat.CH_TRY] = {
        label = "TRY",
        tab = Chat.TAB_IC,
        bg = Color(30, 65, 30),
        text = Color(130, 255, 130),
        msg = Color(100, 255, 100),
    },
    [Chat.CH_YELL] = {
        label = "YELL",
        tab = Chat.TAB_IC,
        bg = Color(70, 25, 25),
        text = Color(255, 120, 120),
        msg = Color(255, 80, 80),
    },
    [Chat.CH_WHISPER] = {
        label = "WHISPER",
        tab = Chat.TAB_IC,
        bg = Color(50, 50, 50),
        text = Color(200, 200, 200),
        msg = Color(180, 180, 180),
    },
    [Chat.CH_ROLEPLAY] = {
        label = "ROLEPLAY",
        tab = Chat.TAB_IC,
        bg = Color(233, 143, 65),
        text = Color(200, 200, 200),
        msg = Color(180, 180, 180),
    },
}

local _defaultPill = {
    label = "IC",
    tab = Chat.TAB_IC,
    bg = Color(50, 50, 55),
    text = Color(200, 200, 200),
    msg = Color(230, 230, 230),
}

function Chat:ChannelMatchesTab(channel, activeTab)
    if activeTab == self.TAB_ALL then return true end
    local pill = self.Pill[channel] or _defaultPill
    return pill.tab == activeTab
end

function Chat:GetChannelTab(channel)
    return (self.Pill[channel] or _defaultPill).tab
end

function Chat:GetPill(channel)
    return self.Pill[channel] or _defaultPill
end

function Chat:GetPillLabel(channel)
    return (self.Pill[channel] or _defaultPill).label
end

function Chat:GetPillBgColor(channel)
    return (self.Pill[channel] or _defaultPill).bg
end

function Chat:GetPillTextColor(channel)
    return (self.Pill[channel] or _defaultPill).text
end

function Chat:GetChannelColor(channel, success)
    if channel == Chat.CH_TRY and success == false then return self.TryFailColor end
    return (self.Pill[channel] or _defaultPill).msg
end

function Chat:Cfg(key)
    return self.Config[key]
end

function Chat:ParseRPCommand(text)
    local lower = string.lower(text)
    local cmds = {
        {
            prefix = "/me ",
            ch = self.CH_ME
        },
        {
            prefix = "/it ",
            ch = self.CH_DO
        },
        {
            prefix = "/na ",
            ch = self.CH_NA
        },
        {
            prefix = "/looc ",
            ch = self.CH_LOOC
        },
        {
            prefix = "/l ",
            ch = self.CH_LOOC
        },
        {
            prefix = "/roll",
            ch = self.CH_ROLL,
            noArg = true
        },
        {
            prefix = "/try ",
            ch = self.CH_TRY
        },
        {
            prefix = "/yell ",
            ch = self.CH_YELL
        },
        {
            prefix = "/y ",
            ch = self.CH_YELL
        },
        {
            prefix = "/whisper ",
            ch = self.CH_WHISPER
        },
        {
            prefix = "/w ",
            ch = self.CH_WHISPER
        },
        {
            prefix = "/ooc ",
            ch = self.CH_OOC
        },
        {
            prefix = "// ",
            ch = self.CH_OOC
        },
    }

    for _, cmd in ipairs(cmds) do
        if string.sub(lower, 1, #cmd.prefix) == cmd.prefix then
            if cmd.noArg then return cmd.ch, "" end
            local arg = string.Trim(string.sub(text, #cmd.prefix + 1))
            if arg ~= "" then return cmd.ch, arg end
            return nil
        end
    end
    return nil
end

function Chat:ParseFormatting(text)
    if not text or text == "" then
        return {
            {
                text = text or "",
                style = "regular"
            }
        }
    end

    local segments = {}
    local pos = 1
    local len = #text
    while pos <= len do
        if string.sub(text, pos, pos + 1) == "**" then
            local endPos = string.find(text, "**", pos + 2, true)
            if endPos then
                local inner = string.sub(text, pos + 2, endPos - 1)
                if inner ~= "" then
                    segments[#segments + 1] = {
                        text = inner,
                        style = "italic"
                    }
                end

                pos = endPos + 2
            else
                segments[#segments + 1] = {
                    text = "**",
                    style = "regular"
                }

                pos = pos + 2
            end
        elseif string.sub(text, pos, pos) == "*" then
            local endPos = string.find(text, "*", pos + 1, true)
            if endPos and string.sub(text, endPos, endPos + 1) ~= "**" then
                local inner = string.sub(text, pos + 1, endPos - 1)
                if inner ~= "" then
                    segments[#segments + 1] = {
                        text = inner,
                        style = "bold"
                    }
                end

                pos = endPos + 1
            else
                segments[#segments + 1] = {
                    text = "*",
                    style = "regular"
                }

                pos = pos + 1
            end
        else
            local nextStar = string.find(text, "*", pos, true)
            local plainEnd = nextStar and (nextStar - 1) or len
            local plain = string.sub(text, pos, plainEnd)
            if plain ~= "" then
                segments[#segments + 1] = {
                    text = plain,
                    style = "regular"
                }
            end

            pos = plainEnd + 1
        end
    end

    if #segments == 0 then
        segments[#segments + 1] = {
            text = text,
            style = "regular"
        }
    end
    return segments
end