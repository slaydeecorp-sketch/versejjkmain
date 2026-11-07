VERSE.Escape = VERSE.Escape or {}

local ESC = VERSE.Escape

local function CB(id)
    return function()
        if ESC and ESC.HandleButton then
            ESC:HandleButton(id)
        end
    end
end

ESC.Config = {
    Buttons = {
        {
            id = "resume",
            text = "Reprendre",
            color = Color(255, 207, 85),
            icon = "verse/echapmenu/return_game.png",
            iconX = 18, iconY = 20,
            btnBackground = "verse/echapmenu/return_game_btn.png",
            callback = CB("resume"),
        },
        {
            id = "discord",
            text = "Discord",
            color = color_white,
            icon = "verse/echapmenu/discord_icon.png",
            iconX = 24, iconY = 18,
            btnBackground = "verse/echapmenu/discord_icon_btn.png",
            callback = CB("discord"),
        },
        {
            id = "characters",
            text = "Personnages",
            color = color_white,
            icon = "verse/echapmenu/character_icon.png",
            iconX = 19, iconY = 19,
            btnBackground = "verse/echapmenu/character_icon_btn.png",
            callback = CB("characters"),
        },
        {
            id = "wiki",
            text = "Wiki",
            color = color_white,
            icon = "verse/echapmenu/wiki_icon.png",
            iconX = 22, iconY = 22,
            btnBackground = "verse/echapmenu/wiki_icon_btn.png",
            callback = CB("wiki"),
        },
        {
            id = "settings",
            text = "Paramètres",
            color = color_white,
            icon = "verse/echapmenu/settings_icon.png",
            iconX = 19, iconY = 20,
            btnBackground = "verse/echapmenu/settings_icon_btn.png",
            callback = CB("settings"),
        },
        {
            id = "bind",
            text = "Raccourcis",
            color = color_white,
            icon = "verse/echapmenu/settings_icon.png",
            iconX = 19, iconY = 20,
            btnBackground = "verse/echapmenu/settings_icon_btn.png",
            callback = CB("bind"),
        },
        {
            id = "disconnect",
            text = "Déconnexion",
            color = Color(255, 71, 71),
            icon = "verse/echapmenu/disconnect_icon.png",
            iconX = 19, iconY = 21,
            btnBackground = "verse/echapmenu/disconnect_icon_btn.png",
            callback = CB("disconnect"),
        },
    },

    Links = {
        Discord = "https://discord.gg/6AwcH2bm9K",
        Wiki = "https://wiki.verse-community.fr/",
    },
}