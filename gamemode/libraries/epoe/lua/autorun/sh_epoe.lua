if epoe then
    if SERVER then
        pcall(function()
            epoe.InEPOE = true
            epoe.DisableTick()
        end)

        epoe = nil
        package.loaded.epoe = nil
    else
        pcall(function()
            epoe.InEPOE = true
            e.GUI:Remove()
        end)
    end
end

local GMPath = VERSE.Path.GM

include(GMPath("libraries/epoe/lua/epoe/shared.lua"))

if SERVER then
    AddCSLuaFile(GMPath("libraries/epoe/lua/autorun/sh_epoe.lua"))
    AddCSLuaFile(GMPath("libraries/epoe/lua/epoe/client.lua"))
    AddCSLuaFile(GMPath("libraries/epoe/lua/epoe/client_ui.lua"))
    AddCSLuaFile(GMPath("libraries/epoe/lua/epoe/client_gui.lua"))
    AddCSLuaFile(GMPath("libraries/epoe/lua/epoe/client_filter.lua"))
    AddCSLuaFile(GMPath("libraries/epoe/lua/epoe/shared.lua"))
    AddCSLuaFile(GMPath("libraries/epoe/lua/epoe/autoplace.lua"))
    include(GMPath("libraries/epoe/lua/epoe/server.lua"))
else
    include(GMPath("libraries/epoe/lua/epoe/client.lua"))
    include(GMPath("libraries/epoe/lua/epoe/client_ui.lua"))
    include(GMPath("libraries/epoe/lua/epoe/client_gui.lua"))
    include(GMPath("libraries/epoe/lua/epoe/autoplace.lua"))
    include(GMPath("libraries/epoe/lua/epoe/client_filter.lua"))
end