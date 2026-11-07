VERSE.Rank = VERSE.Rank or {}
local R = VERSE.Rank

R.Defaults = R.Defaults or {
    PreferSecondary = true,
    FallbackToPrimary = true,
    Trim = true,
    Lowercase = false,
    SecondaryMethod = "GetSecondaryUserGroup",
    DefaultRank = "user",
    TreatAsEmpty = {
        ["user"] = true,
        [""] = true,
        [" "] = true,
    },
}

local function getCfg()
    local cfg = (VERSE.Config and VERSE.Config.Rank) or {}
    local out = {}
    for k, v in pairs(R.Defaults) do out[k] = v end
    for k, v in pairs(cfg) do out[k] = v end
    out.PreferSecondary = (out.PreferSecondary ~= false)
    out.FallbackToPrimary = (out.FallbackToPrimary ~= false)
    out.Trim = (out.Trim ~= false)
    out.Lowercase = (out.Lowercase == true)
    out.SecondaryMethod = out.SecondaryMethod or "GetSecondaryUserGroup"
    out.DefaultRank = out.DefaultRank or "user"
    out.TreatAsEmpty = out.TreatAsEmpty or {}
    return out
end

local function normalizeRank(rank, cfg)
    if not isstring(rank) then return nil end
    if cfg.Trim then rank = string.Trim(rank) end
    if cfg.Lowercase then rank = string.lower(rank) end
    if rank == "" then return nil end
    if cfg.TreatAsEmpty[rank] then return nil end
    return rank
end

local function getPrimary(ply, cfg)
    if ply.GetUserGroup then
        return normalizeRank(ply:GetUserGroup(), cfg)
    end
    return nil
end

local function getSecondary(ply, cfg)
    if not cfg.PreferSecondary then return nil end

    local m = cfg.SecondaryMethod
    local fn = m and ply[m]
    if isfunction(fn) then
        return normalizeRank(fn(ply), cfg)
    end

    if ply.GetSecondaryUserGroup then
        return normalizeRank(ply:GetSecondaryUserGroup(), cfg)
    end

    return nil
end

function R.Get(ply, opts)
    if not IsValid(ply) then return nil end

    local cfg = getCfg()
    if istable(opts) then
        for k, v in pairs(opts) do cfg[k] = v end
        cfg.TreatAsEmpty = cfg.TreatAsEmpty or {}
    end

    local primary = getPrimary(ply, cfg)
    local secondary = getSecondary(ply, cfg)

    if secondary and secondary ~= primary then
        if VERSE.Hook and VERSE.Hook.Run then
            local override = VERSE.Hook.Run("VERSE.GetRank", ply, secondary, primary, cfg)
            if override ~= nil then return override end
        end
        return secondary
    end

    if cfg.FallbackToPrimary then
        if VERSE.Hook and VERSE.Hook.Run then
            local override = VERSE.Hook.Run("VERSE.GetRank", ply, primary, primary, cfg)
            if override ~= nil then return override end
        end
        if primary ~= nil then return primary end
    end

    return cfg.DefaultRank or "user"
end

function VERSE.GetRank(ply, opts)
    return R.Get(ply, opts)
end

VERSE.Hook.AddNS("Rank", "VERSE.GetRank", "VERSE::GetRank::Rank", function(ply, chosen, primary)
    if chosen == "user" and primary and primary ~= "user" then
        return primary
    end
end)