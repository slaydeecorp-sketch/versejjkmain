local T = VERSE.Training
T._clientZones = T._clientZones or {} -- table reçue du serveur

local _TR_COL_ZONE_TXT = Color(255, 255, 255, 255)  -- HUDPaint text

-- ─── Réception de la liste des zones ──────────────────────────────────────────

netstream.Hook(T.Net.Sync, function(data)
    T._clientZones = {}
    if not istable(data) then return end
    for _, z in ipairs(data) do
        if istable(z) and istable(z.pos) then
            T._clientZones[#T._clientZones + 1] = {
                id     = tonumber(z.id) or 0,
                name   = tostring(z.name or "Zone d'entrainement"),
                pos    = Vector(
                    tonumber(z.pos.x) or 0,
                    tonumber(z.pos.y) or 0,
                    tonumber(z.pos.z) or 0
                ),
                radius = math.max(50, tonumber(z.radius) or 500),
            }
        end
    end
end)

-- ─── Détection locale ─────────────────────────────────────────────────────────

local _currentZone = nil  -- zone dans laquelle le joueur local se trouve

-- Mis à jour toutes les 0.5s pour ne pas saturer chaque frame
local _lastCheck = 0
local function updateCurrentZone()
    local now = RealTime()
    if now - _lastCheck < 0.5 then return end
    _lastCheck = now

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        _currentZone = nil
        return
    end

    local pos = ply:GetPos()
    _currentZone = nil
    for _, zone in ipairs(T._clientZones) do
        if zone.pos:Distance(pos) <= zone.radius then
            _currentZone = zone
            return
        end
    end
end

-- ─── Police ───────────────────────────────────────────────────────────────────

local _fontCreated = false
local FONT_NAME = "VERSE_Training_Banner"

local function ensureFont()
    if _fontCreated then return end
    _fontCreated = true
    surface.CreateFont(FONT_NAME, {
        font      = "Poppins",
        size      = 22,
        weight    = 700,
        antialias = true,
        shadow    = false,
    })
end

-- ─── HUD ──────────────────────────────────────────────────────────────────────

hook.Add("HUDPaint", "VERSE::Training::HUD", function()
    updateCurrentZone()
    if not _currentZone then return end

    ensureFont()

    draw.SimpleText(
        "Terrain d'entraînement",
        FONT_NAME,
        ScrW() * 0.5,
        28,
        _TR_COL_ZONE_TXT,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP
    )
end)
