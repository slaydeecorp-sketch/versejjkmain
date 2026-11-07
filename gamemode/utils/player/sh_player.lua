local loadQueue = {}

VERSE.Hook.AddNS("PlayerFullLoad", "PlayerInitialSpawn", "VERSE::PlayerInitialSpawn::PlayerFullLoad", function(ply)
    loadQueue[ply] = true
end)

VERSE.Hook.AddNS("PlayerFullLoad", "PlayerDisconnected", "VERSE::PlayerDisconnected::PlayerFullLoad", function(ply)
    loadQueue[ply] = nil
end)

VERSE.Hook.AddNS("PlayerFullLoad", "SetupMove", "VERSE::SetupMove::PlayerFullLoad", function(ply, _, cmd)
    if not loadQueue[ply] then return end
    if not IsValid(ply) then loadQueue[ply] = nil return end
    if cmd:IsForced() then return end
    loadQueue[ply] = nil
    VERSE.Hook.Call("PlayerFullLoad", ply)
end)