VERSE.Config.Fonts = {
    Enabled = true,
    Scale = 1,
    AutoRebuildOnScaleChange = true,

    Defaults = {
        antialias = true,
        extended = true,
        additive = false,
        outline = false,
        shadow = false,
        italic = false,
        underline = false,
        strikeout = false,
        blursize = 0,
        scanlines = 0,
    },

    Reference = {
        W = 1920,
        H = 1080,
        Mode = "min",
        ClampMin = 0.75,
        ClampMax = 1.50,
    },

    Families = {
        Montserrat = {
            Medium = { font = "Montserrat Medium", weight = 500, extended = true },
            Regular = { font = "Montserrat", weight = 500, extended = true },
            Bold = { font = "Montserrat", weight = 1000, extended = true },
            Italic = { font = "Montserrat", weight = 500, italic = true, extended = true },
        },

        Gilroy = {
            Medium = { font = "Gilroy Medium", weight = 500, extended = true },
            Regular = { font = "Gilroy", weight = 500, extended = true },
            Bold = { font = "Gilroy Bold", weight = 500, extended = true },
            Italic = { font = "Gilroy", weight = 500, italic = true, extended = true },
        },

        Benzin = {
            ExtraBold = { font = "Benzin-ExtraBold", weight = 500, extended = true },
            Medium = { font = "Benzin-Medium", weight = 500, extended = true },
            Regular = { font = "Benzin-Regular", weight = 500, extended = true },
            Bold = { font = "Benzin-Bold", weight = 500, extended = true },
            Semibold = { font = "Benzin-Semibold", weight = 500, extended = true },
            Italic = { font = "Benzin-Medium", weight = 500, italic = true, extended = true },
        },

        Poppins = {
            Medium = { font = "Poppins Medium", weight = 500, extended = true },
            ItalicBold = { font = "Poppins", weight = 1000, italic = true, extended = true },
            Regular = { font = "Poppins", weight = 500, extended = true },
            Italic = { font = "Poppins", weight = 500, italic = true, extended = true },
            Bold = { font = "Poppins", weight = 1000, extended = true },
            SemiBold = { font = "Poppins SemiBold", weight = 500, extended = true },
        },
    },

    DefaultVariant = "Regular",
}