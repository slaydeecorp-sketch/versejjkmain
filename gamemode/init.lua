AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

if VERSE and VERSE.Flags and VERSE.Flags.AutoInit and not VERSE._didInit then
    VERSE._didInit = true
    VERSE:Init()
end

VERSE.Hook.AddNS("Init", "InitPostEntity", "VERSE::InitPostEntity::Init", function()
    if VERSE.InitPostEntityCalled then return end
    VERSE.InitPostEntityCalled = true

    local ok = xpcall(function()
        local physData = physenv.GetPerformanceSettings()
        physData.MaxVelocity = 2000
        physData.MaxAngularVelocity = 3636
        physenv.SetPerformanceSettings(physData)
    end, debug.traceback)

    if not ok then
        VERSE.Log:Warn("[PhysEnv] tuning failed, continuing")
    end

    RunConsoleCommand("sv_allowcslua", "0")
    RunConsoleCommand("physgun_DampingFactor", "0.9")
    RunConsoleCommand("sv_sticktoground", "0")
    RunConsoleCommand("sv_airaccelerate", "1000")
    RunConsoleCommand("sv_alltalk", "0")
    RunConsoleCommand("mp_show_voice_icons", "0")
    VERSE.Hook.Run("VERSE::ServerPostInit")
end)