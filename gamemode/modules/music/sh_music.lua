VERSE.Music = VERSE.Music or {}
local M = VERSE.Music
M.Config = {
    DefaultVolume = 0.5,
    FadeTime = 1.5,
    AreaRadius = 1500,
    AreaRadiusMin = 500,
    AreaRadiusMax = 3000,
    AreaRadiusStep = 250,
    AreaTickRate = 0.5,
}

M.Net = {
    AreaPlay = "VERSE::Music::AreaPlay",
    AreaStop = "VERSE::Music::AreaStop",
    AreaSync = "VERSE::Music::AreaSync",
    TrackList = "VERSE::Music::TrackList",
    AdminRequest = "VERSE::Music::AdminRequest",
    AdminCreate = "VERSE::Music::AdminCreate",
    AdminUpdate = "VERSE::Music::AdminUpdate",
    AdminDelete = "VERSE::Music::AdminDelete",
    AreaResync = "VERSE::Music::AreaResync",
}

M.Config.TableTracks = "verse_ost_tracks"
M.Categories = {
    {
        id = "favorites",
        name = "music.cat_favorites"
    },
    {
        id = "chill",
        name = "music.cat_chill"
    },
    {
        id = "combat",
        name = "music.cat_combat"
    },
    {
        id = "motivation",
        name = "music.cat_motivation"
    },
    {
        id = "tension",
        name = "music.cat_tension"
    },
    {
        id = "sad",
        name = "music.cat_sad"
    },
}

M._SeedTracks = {}
M.Tracks = M.Tracks or table.Copy(M._SeedTracks)
function M:GetTrack(trackId)
    for _, t in ipairs(self.Tracks) do
        if t.id == trackId then return t end
    end
    return nil
end

function M:GetTracksByCategory(catId)
    if catId == "favorites" then return {} end
    local result = {}
    for _, t in ipairs(self.Tracks) do
        if t.category == catId then result[#result + 1] = t end
    end
    return result
end

function M:SearchTracks(query)
    query = string.lower(string.Trim(query or ""))
    if query == "" then return self.Tracks end
    local result = {}
    for _, t in ipairs(self.Tracks) do
        if string.find(string.lower(t.name), query, 1, true) or string.find(string.lower(t.artist or ""), query, 1, true) then result[#result + 1] = t end
    end
    return result
end

function M:FormatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end