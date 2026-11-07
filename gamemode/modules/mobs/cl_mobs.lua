-- ─── Popup XP flottant ────────────────────────────────────────────────────────

local _popups = {}

local _fontCreated = false
local FONT_XP = "VERSE_Mobs_XPPopup"
-- Couleurs pré-allouées pour le rendu des popups XP (évite Color() par frame)
local _XP_COL_SHADOW = Color(0,   0,   0,   0)    -- .a muté
local _XP_COL_TEXT   = Color(255, 220, 60,  255)  -- .a muté

local function ensureFont()
    if _fontCreated then return end
    _fontCreated = true
    surface.CreateFont(FONT_XP, {
        font      = "Poppins",
        size      = 26,
        weight    = 700,
        antialias = true,
        shadow    = true,
    })
end

netstream.Hook(VERSE.Mobs.Net.XPGain, function(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    _popups[#_popups + 1] = {
        text     = "+" .. amount .. " EXP",
        start    = RealTime(),
        duration = 2.2,
        -- Position : centre écran légèrement au-dessus du milieu
        x        = ScrW() * 0.5 + math.random(-40, 40),
        y        = ScrH() * 0.45,
    }
end)

hook.Add("HUDPaint", "VERSE::Mobs::XPPopup", function()
    if #_popups == 0 then return end
    ensureFont()

    local now = RealTime()
    local i = 1
    while i <= #_popups do
        local p = _popups[i]
        local elapsed  = now - p.start
        local progress = elapsed / p.duration -- 0 → 1

        if progress >= 1 then
            table.remove(_popups, i)
        else
            -- Fade out sur les 40% finaux
            local alpha = progress > 0.6
                and math.floor(255 * (1 - (progress - 0.6) / 0.4))
                or  255
            -- Monte doucement
            local y = p.y - elapsed * 45

            -- Ombre (mutation de .a uniquement)
            _XP_COL_SHADOW.a = math.floor(alpha * 0.6)
            draw.SimpleText(p.text, FONT_XP, p.x + 1, y + 1,
                _XP_COL_SHADOW, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            -- Texte doré (mutation de .a uniquement)
            _XP_COL_TEXT.a = alpha
            draw.SimpleText(p.text, FONT_XP, p.x, y,
                _XP_COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            i = i + 1
        end
    end
end)
