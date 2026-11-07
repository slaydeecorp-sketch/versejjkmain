VERSE.Log = VERSE.Log or {}

local levels = { debug = 1, info = 2, warn = 3, error = 4 }

local function realmTag()
    if SERVER then return "SV" end
    return "CL"
end

function VERSE.Log:CanPrint(level)
    local cfg = VERSE.Config or {}
    local min = levels[cfg.LogLevel or "info"] or 2
    local cur = levels[level] or 2
    return cur >= min
end

function VERSE.Log:Print(level, ...)
    if not self:CanPrint(level) then return end
    local prefix = ("[VERSE][%s][%s] "):format(realmTag(), (level or "info"):upper())
    MsgC(color_white, prefix)
    MsgN(...)
end

function VERSE.Log:Debug(...) self:Print("debug", ...) end
function VERSE.Log:Info(...) self:Print("info", ...) end
function VERSE.Log:Warn(...) self:Print("warn", ...) end
function VERSE.Log:Error(...) self:Print("error", ...) end