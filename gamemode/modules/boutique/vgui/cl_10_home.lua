local BT = VERSE.Boutique
local R = VERSE.Responsive
local Materials = VERSE.Materials
local _ui = BT._ui

local function buildHomeCard(parent, cfg)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(R:X(cfg.x), R:Y(cfg.y))
    btn:SetSize(R:X(cfg.w), R:Y(cfg.h))
    btn:SetText("")
    btn:SetCursor("hand")

    btn._alpha = btn._alpha or 100
    local _cardCol = Color(255, 255, 255, 100)  -- .a muté
    btn.Paint = function(s, pw, ph)
        local target = s:IsHovered() and 240 or 100
        s._alpha = Lerp(FrameTime() * 10, s._alpha or target, target)
        if cfg.char_bg then
            _cardCol.a = math.floor(s._alpha)
            Materials:Draw(_cardCol, cfg.char_bg, 0, 0, pw, ph, "noclamp smooth")
        end
    end

    btn.DoClick = function()
        if cfg.type == "page" then
            BT:SetPage(cfg.page)
        elseif cfg.type == "url" and cfg.url then
            gui.OpenURL(cfg.url)
        end
    end
end

local function buildHomePage(parent)
    for _, cfg in ipairs(BT.HomeCards or {}) do
        buildHomeCard(parent, cfg)
    end
end

_ui.buildHomePage = buildHomePage
