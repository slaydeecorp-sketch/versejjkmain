local function isFallSound(name)
    if not isstring(name) or name == "" then return false end
    local lower = string.lower(name)
    if string.find(lower, "fallpain", 1, true) then return true end
    if string.find(lower, "falldamage", 1, true) then return true end
    if string.find(lower, "fallgib", 1, true) then return true end
    return false
end

hook.Add("EntityEmitSound", "VERSE::Combat::BlockFallSound", function(data)
    if isFallSound(data.SoundName) or isFallSound(data.OriginalSoundName) then return false end
end)
