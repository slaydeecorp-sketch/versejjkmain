VERSE.Notify = VERSE.Notify or {}
local Notify = VERSE.Notify

NOTIFY_GENERIC = 0
NOTIFY_ERROR = 1
NOTIFY_UNDO = 2
NOTIFY_HINT = 3
NOTIFY_CLEANUP = 4

Notify.MaxType = NOTIFY_CLEANUP
Notify.Net = Notify.Net or {
    Push = "VERSE::Notify::Push",
}

function Notify:ResolveType(t)
    if isstring(t) then
        local gv = _G[t]
        if isnumber(gv) then
            t = gv
        else
            t = tonumber(t)
        end
    end

    t = tonumber(t) or NOTIFY_GENERIC
    if t < 0 or t > self.MaxType then return NOTIFY_GENERIC end
    return t
end

function Notify:RegisterType(typeName)
    local nextId = self.MaxType + 1
    _G["NOTIFY_" .. string.upper(typeName)] = nextId
    self.MaxType = nextId
    return nextId
end

local meta = FindMetaTable("Player")
function meta:Notify(text, ntype, len, soundOrDisable)
    if SERVER then
        Notify:Send(self, text, ntype, len, soundOrDisable)
    else
        Notify:Push(text, ntype, len, soundOrDisable)
    end
end