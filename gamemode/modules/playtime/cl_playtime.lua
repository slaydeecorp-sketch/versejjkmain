local PlayTime = VERSE.PlayTime

PlayTime.Client = PlayTime.Client or {
    TotalSeconds = 0,
    SessionSeconds = 0,
}

net.Receive("VERSE::PlayTime::Sync", function()
    local total = net.ReadUInt(32)
    local session = net.ReadUInt(32)

    PlayTime.Client.TotalSeconds = tonumber(total) or 0
    PlayTime.Client.SessionSeconds = tonumber(session) or 0

    if hook and hook.Run then
        hook.Run("VERSE.PlayTimeSync", total, session)
    end
end)

function PlayTime:GetTotalSeconds()
    return tonumber(self.Client.TotalSeconds) or 0
end

function PlayTime:GetSessionSeconds()
    return tonumber(self.Client.SessionSeconds) or 0
end

function PlayTime:GetCurrentTotalSeconds()
    return self:GetTotalSeconds() + self:GetSessionSeconds()
end