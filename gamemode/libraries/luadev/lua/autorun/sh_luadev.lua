local GMPath = VERSE.Path.GM
module("luadev", package.seeall)
include(GMPath("libraries/luadev/lua/luadev/luadev_sh.lua"))
if SERVER then include(GMPath("libraries/luadev/lua/luadev/luadev_sv.lua")) end
include(GMPath("libraries/luadev/lua/luadev/luadev.lua"))
if CLIENT then include(GMPath("libraries/luadev/lua/luadev/socketdev.lua")) end
if SERVER then
    AddCSLuaFile(GMPath("libraries/luadev/lua/luadev/luadev_sh.lua"))
    AddCSLuaFile(GMPath("libraries/luadev/lua/luadev/luadev.lua"))
    AddCSLuaFile(GMPath("libraries/luadev/lua/luadev/socketdev.lua"))
end