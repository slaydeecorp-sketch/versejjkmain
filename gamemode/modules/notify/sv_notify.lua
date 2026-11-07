local Notify = VERSE.Notify

function Notify:Send(ply, text, ntype, len, soundOrDisable)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local t = self:ResolveType(ntype)
    local du = tonumber(len) or 5
    local st = type(soundOrDisable)
    local disableSound = (st == "boolean") and soundOrDisable or false
    local customSound = (st == "string") and soundOrDisable or nil
    netstream.Start(ply, Notify.Net.Push, tostring(text or ""), t, du, disableSound == true, (customSound ~= nil and customSound ~= "") and tostring(customSound) or nil)
end