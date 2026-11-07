local GMPath = VERSE.Path.GM
local function RunScripts()
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/config/colors.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/func.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/legacy_vgui.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/menu.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/button.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/checkbox.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/color_picker.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/derma_menu.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/entry.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/frame.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/player_selector.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/radialpanel.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/scrollpanel.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/slidebox.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/tabs.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/textbox.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/category.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/combobox.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/table.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/text.lua'))
    Mantle.run_cl(GMPath('libraries/mantle/lua/mantle/core/vgui_elements/hscroll.lua'))
end

local function RunAddons()
    local _, addonsName = file.Find(GMPath('libraries/mantle/lua/mantle_addons/*'), 'LUA')

    for _, addon in ipairs(addonsName) do
        if file.Exists(GMPath('libraries/mantle/lua/mantle_addons/' .. addon .. '/init.lua'), 'LUA') then
            Mantle.run_sh(GMPath('libraries/mantle/lua/mantle_addons/' .. addon .. '/init.lua'))
        end

        if file.Exists(GMPath('libraries/mantle/lua/mantle_addons/' .. addon .. '/lang.lua'), 'LUA') then
            local lang = Mantle.run_sh(GMPath('libraries/mantle/lua/mantle_addons/' .. addon .. '/lang.lua'))
            Mantle.lang.list[addon] = lang
        end
    end

    Mantle.run_sh(GMPath('libraries/mantle/lua/mantle/core/lang.lua'))
end

local function InitLib()
    Mantle = Mantle or {
        lang = { list = {}, default = 'en' },
    }
    Mantle.run_cl = SERVER and AddCSLuaFile or include
    Mantle.run_sv = SERVER and include or function() end
    Mantle.run_sh = function(f)
        local client = Mantle.run_cl(f)
        local server = Mantle.run_sv(f)
        return SERVER and server or client
    end

    RunScripts()
    RunAddons()
end

InitLib()