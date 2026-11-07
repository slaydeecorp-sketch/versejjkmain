VERSE.Particles = VERSE.Particles or {}

local P = VERSE.Particles

P._pcf = P._pcf or {}
P._systems = P._systems or {}
P._loaded = P._loaded or false
P._didConfig = P._didConfig or false

local function logWarn(msg)
    if VERSE.Log and VERSE.Log.Warn then
        VERSE.Log:Warn(msg)
    else
        MsgC(Color(255, 200, 0), "[VERSE][Particles] ", color_white, msg .. "\n")
    end
end

local function hasAny(t)
    if not t then return false end
    return next(t) ~= nil
end

local function hasAnyList(list)
    return istable(list) and #list > 0
end

function P:RegisterFile(path)
    if not isstring(path) or path == "" then return end
    self._pcf[path] = true
end

function P:RegisterSystem(name)
    if not isstring(name) or name == "" then return end
    self._systems[name] = true
end

function P:Register(data)
    if istable(data.Files) then
        for _, pcf in ipairs(data.Files) do
            self:RegisterFile(pcf)
        end
    end

    if istable(data.Systems) then
        for _, name in ipairs(data.Systems) do
            self:RegisterSystem(name)
        end
    end

    if istable(data.files) then
        for _, pcf in ipairs(data.files) do
            self:RegisterFile(pcf)
        end
    end

    if istable(data.systems) then
        for _, name in ipairs(data.systems) do
            self:RegisterSystem(name)
        end
    end
end

function P:LoadFromConfig(force)
    if self._didConfig and not force then return end
    self._didConfig = true

    local cfg = VERSE.Config and VERSE.Config.Particles
    if not istable(cfg) then return end

    local empty =
        (not hasAnyList(cfg.Files)) and
        (not hasAnyList(cfg.Systems)) and
        (not hasAnyList(cfg.files)) and
        (not hasAnyList(cfg.systems))

    if empty then return end

    self:Register(cfg)
end

function P:Load(force)
    self:LoadFromConfig()

    if self._loaded and not force then return end

    if (not hasAny(self._pcf)) and (not hasAny(self._systems)) then
        return
    end

    self._loaded = true

    if SERVER and hasAny(self._pcf) then
        for path in pairs(self._pcf) do
            local ok, err = pcall(game.AddParticles, path)
            if not ok then
                logWarn("Failed to load PCF: " .. tostring(path) .. " -> " .. tostring(err))
            end
        end
    end

    if PrecacheParticleSystem and hasAny(self._systems) then
        for name in pairs(self._systems) do
            local ok, err = pcall(PrecacheParticleSystem, name)
            if not ok then
                logWarn("Failed to precache particle: " .. tostring(name) .. " -> " .. tostring(err))
            end
        end
    end
end

function P:Reset()
    self._loaded = false
end