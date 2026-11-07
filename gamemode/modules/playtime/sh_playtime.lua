VERSE.PlayTime = VERSE.PlayTime or {}
local PlayTime = VERSE.PlayTime

PlayTime.Config = PlayTime.Config or {
    Table = "verse_playtime",
    SyncInterval = 10,
    SaveInterval = 60,
    DefaultTotal = 0,
}

function PlayTime.Format(sec)
    sec = tonumber(sec) or 0
    if sec < 0 then sec = 0 end
    local days = math.floor(sec / 86400)
    sec = sec - days * 86400
    local h = math.floor(sec / 3600)
    sec = sec - h * 3600
    local m = math.floor(sec / 60)
    local s = sec - m * 60
    if days > 0 then return ("%dd %02d:%02d:%02d"):format(days, h, m, s) end
    return ("%02d:%02d:%02d"):format(h, m, s)
end