local A = VERSE.Access

local function getLocalRights()
    local ply = LocalPlayer()
    if not IsValid(ply) then return A:GetRightsForLevel("user") end
    return A:GetRights(ply)
end

do
    local _Add = properties.Add
    if _Add and not properties.__VERSE_AccessWrapped then
        properties.__VERSE_AccessWrapped = true

        properties.Add = function(name, data)
            local r = getLocalRights()
            local allowed = r.AllowedProperties
            if istable(allowed) then
                if allowed[name] == false then return end
                if allowed[name] ~= true then return end
            end
            return _Add(name, data)
        end
    end
end

VERSE.Hook.AddNS("Access", "SpawnMenuOpen", "VERSE::SpawnMenuOpen::Access", function()
    local r = getLocalRights()
    if r.SpawnMenuOpen == false then
        return false
    end
end)

VERSE.Hook.AddNS("Access", "PlayerNoClip", "VERSE::PlayerNoClip::Access", function(ply, desiredState)
    if ply ~= LocalPlayer() then return end
    local r = getLocalRights()
    if not r or r.CanNoclip ~= true then
        return false
    end
end)