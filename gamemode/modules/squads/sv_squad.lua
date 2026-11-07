local SQ = VERSE.Squads
for _, v in pairs(SQ.Net) do
    util.AddNetworkString(v)
end

local _sqCooldown = {}
-- Cooldown PAR action (create/leave/rename) au lieu d'un cooldown global partagé :
-- avant, utiliser une action bloquait les deux autres pendant 3s.
-- _sqCooldown[sid] = { create = t, leave = t, rename = t }
local function sqOnCooldown(sid, action, delay)
    local now = CurTime()
    local t = _sqCooldown[sid]
    if not t then t = {} _sqCooldown[sid] = t end
    if (t[action] or 0) + delay > now then return true end
    t[action] = now
    return false
end
SQ._squads = SQ._squads or {}
SQ._playerSquad = SQ._playerSquad or {}
SQ._pendingInvites = SQ._pendingInvites or {}
local function GenerateId()
    return "sq_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

local function BuildMemberList(squad)
    local out = {}
    for _, sid in ipairs(squad.members) do
        local p = player.GetBySteamID(sid)
        out[#out + 1] = {
            steamid = sid,
            name = IsValid(p) and p:Nick() or "Joueur",
            isLeader = sid == squad.leader,
        }
    end
    return out
end

local function SyncToPlayer(squad, ply)
    if not IsValid(ply) or not squad then return end
    netstream.Start(ply, SQ.Net.Sync, {
        id = squad.id,
        name = squad.name,
        leader = squad.leader,
        members = BuildMemberList(squad),
        damageEnabled = squad.damageEnabled,
    })
end

local function SyncSquad(squadId)
    local squad = SQ._squads[squadId]
    if not squad then return end
    for _, sid in ipairs(squad.members) do
        local p = player.GetBySteamID(sid)
        if IsValid(p) then SyncToPlayer(squad, p) end
    end
end

local function RemoveMember(squad, steamId)
    for i, sid in ipairs(squad.members) do
        if sid == steamId then
            table.remove(squad.members, i)
            break
        end
    end

    SQ._playerSquad[steamId] = nil
    local ply = player.GetBySteamID(steamId)
    if IsValid(ply) then
        ply:SetNWString(SQ.NW.SquadId, "")
        ply:SetNWBool(SQ.NW.SquadVoice, false)
        netstream.Start(ply, SQ.Net.Sync, nil)
    end
end

local function InternalDisband(squadId)
    local squad = SQ._squads[squadId]
    if not squad then return end
    for _, sid in ipairs(table.Copy(squad.members)) do
        SQ._playerSquad[sid] = nil
        local ply = player.GetBySteamID(sid)
        if IsValid(ply) then
            ply:SetNWString(SQ.NW.SquadId, "")
            ply:SetNWBool(SQ.NW.SquadVoice, false)
            netstream.Start(ply, SQ.Net.Sync, nil)
        end
    end

    SQ._squads[squadId] = nil
end

function SQ:GetSquad(ply)
    if not IsValid(ply) then return nil end
    local sid = self._playerSquad[ply:SteamID()]
    return sid and self._squads[sid]
end

function SQ:Create(ply)
    if not IsValid(ply) then return nil end
    if self:GetSquad(ply) then return nil end
    local sqId = GenerateId()
    local squad = {
        id = sqId,
        name = "Escouade de " .. ply:Nick(),
        leader = ply:SteamID(),
        members = {ply:SteamID()},
        damageEnabled = false,
    }

    self._squads[sqId] = squad
    self._playerSquad[ply:SteamID()] = sqId
    ply:SetNWString(self.NW.SquadId, sqId)
    ply:SetNWBool(self.NW.SquadMicOn, true)
    ply:SetNWBool(self.NW.SquadListen, true)
    SyncSquad(sqId)
    return squad
end

function SQ:Disband(squadId)
    InternalDisband(squadId)
end

function SQ:Leave(ply)
    if not IsValid(ply) then return end
    local squad = self:GetSquad(ply)
    if not squad then return end
    local steamId = ply:SteamID()
    local wasLeader = squad.leader == steamId
    RemoveMember(squad, steamId)
    if #squad.members == 0 then
        InternalDisband(squad.id)
        return
    end

    if wasLeader then
        squad.leader = squad.members[1]
        local newLdr = player.GetBySteamID(squad.leader)
        if IsValid(newLdr) then newLdr:Notify("Vous êtes maintenant le chef de l'escouade.", NOTIFY_HINT, 5) end
    end

    SyncSquad(squad.id)
end

function SQ:Rename(ply, name)
    if not IsValid(ply) then return end
    name = string.sub(tostring(name or ""):Trim(), 1, self.Config.MaxNameLength)
    if name == "" then return end
    local squad = self:GetSquad(ply)
    if not squad or squad.leader ~= ply:SteamID() then return end
    squad.name = name
    SyncSquad(squad.id)
end

function SQ:Invite(ply, targetSid)
    if not IsValid(ply) then return end
    targetSid = tostring(targetSid or "")
    local squad = self:GetSquad(ply)
    if not squad then
        ply:Notify("You must create a squad first!", NOTIFY_HINT, 4)
        return
    end
    if #squad.members >= self.Config.MaxMembers then
        ply:Notify("L'escouade est pleine !", NOTIFY_HINT, 4)
        return
    end

    local target = player.GetBySteamID(targetSid)
    if not IsValid(target) then return end
    if not target:IsBot() and target:IsInSquad() then
        ply:Notify(target:Nick() .. " est déjà dans une escouade.", NOTIFY_HINT, 4)
        return
    end

    local old = self._pendingInvites[targetSid]
    if old then timer.Remove(old.timerName) end
    local tName = "VERSE::Squad::Inv::" .. targetSid
    self._pendingInvites[targetSid] = {
        squadId = squad.id,
        timerName = tName
    }

    netstream.Start(target, self.Net.InviteNotify, {
        fromName = ply:Nick(),
        squadName = squad.name,
    })

    timer.Create(tName, self.Config.InviteTimeout, 1, function()
        self._pendingInvites[targetSid] = nil
        local t = player.GetBySteamID(targetSid)
        if IsValid(t) then netstream.Start(t, self.Net.InviteNotify, nil) end
    end)
end

function SQ:AcceptInvite(ply)
    if not IsValid(ply) then return end
    local steamId = ply:SteamID()
    local inv = self._pendingInvites[steamId]
    if not inv then return end
    timer.Remove(inv.timerName)
    self._pendingInvites[steamId] = nil
    local squad = self._squads[inv.squadId]
    if not squad then return end
    if ply:IsInSquad() or #squad.members >= self.Config.MaxMembers then
        ply:Notify("Impossible de rejoindre l'escouade.", NOTIFY_HINT, 4)
        return
    end

    squad.members[#squad.members + 1] = steamId
    self._playerSquad[steamId] = squad.id
    ply:SetNWString(self.NW.SquadId, squad.id)
    ply:SetNWBool(self.NW.SquadMicOn, true)
    ply:SetNWBool(self.NW.SquadListen, true)
    SyncSquad(squad.id)
end

function SQ:DeclineInvite(ply)
    if not IsValid(ply) then return end
    local steamId = ply:SteamID()
    local inv = self._pendingInvites[steamId]
    if not inv then return end
    timer.Remove(inv.timerName)
    self._pendingInvites[steamId] = nil
end

function SQ:Kick(ply, targetSid)
    if not IsValid(ply) then return end
    targetSid = tostring(targetSid or "")
    local squad = self:GetSquad(ply)
    if not squad or squad.leader ~= ply:SteamID() then return end
    if targetSid == ply:SteamID() then return end
    local inSquad = false
    for _, sid in ipairs(squad.members) do
        if sid == targetSid then
            inSquad = true
            break
        end
    end

    if not inSquad then return end
    RemoveMember(squad, targetSid)
    SyncSquad(squad.id)
    local target = player.GetBySteamID(targetSid)
    if IsValid(target) then target:Notify("Vous avez été expulsé de l'escouade.", NOTIFY_HINT, 5) end
end

function SQ:ToggleDamage(ply)
    if not IsValid(ply) then return end
    local squad = self:GetSquad(ply)
    if not squad or squad.leader ~= ply:SteamID() then return end
    squad.damageEnabled = not squad.damageEnabled
    SyncSquad(squad.id)
    local msg = squad.damageEnabled and "Dégâts entre membres ACTIVÉS !" or "Dégâts entre membres DÉSACTIVÉS !"
    for _, sid in ipairs(squad.members) do
        local p = player.GetBySteamID(sid)
        if IsValid(p) then p:Notify(msg, NOTIFY_HINT, 5) end
    end
end

function SQ:ToggleVoice(ply)
    if not IsValid(ply) then return end
    if not self:GetSquad(ply) then return end
    ply:SetNWBool(self.NW.SquadVoice, not ply:GetNWBool(self.NW.SquadVoice, false))
end

function SQ:SetMicOn(ply, on)
    if not IsValid(ply) then return end
    ply:SetNWBool(self.NW.SquadMicOn, on == true)
end

function SQ:SetListenOn(ply, on)
    if not IsValid(ply) then return end
    ply:SetNWBool(self.NW.SquadListen, on == true)
end

function SQ:ToggleMic(ply)
    if not IsValid(ply) then return end
    local cur = ply:GetNWBool(self.NW.SquadMicOn, true)
    ply:SetNWBool(self.NW.SquadMicOn, not cur)
end

function SQ:ToggleListen(ply)
    if not IsValid(ply) then return end
    local cur = ply:GetNWBool(self.NW.SquadListen, true)
    ply:SetNWBool(self.NW.SquadListen, not cur)
end

function SQ:GetNearby(ply)
    if not IsValid(ply) then return {} end
    local nearby = {}
    for _, p in ipairs(player.GetAll()) do
        if p ~= ply and IsValid(p) and ply:GetPos():Distance(p:GetPos()) <= self.Config.InviteRadius then
            nearby[#nearby + 1] = {
                steamid = p:SteamID(),
                name = p:Nick(),
                inSquad = p:IsInSquad(),
            }
        end
    end
    return nearby
end

netstream.Hook(SQ.Net.Create, function(ply)
    local sid = ply:SteamID()
    if sqOnCooldown(sid, "create", 3) then return end
    SQ:Create(ply)
end)
netstream.Hook(SQ.Net.Leave, function(ply)
    local sid = ply:SteamID()
    if sqOnCooldown(sid, "leave", 3) then return end
    SQ:Leave(ply)
end)
netstream.Hook(SQ.Net.Rename, function(ply, name)
    local sid = ply:SteamID()
    if sqOnCooldown(sid, "rename", 3) then return end
    name = string.gsub(tostring(name or ""), "%c", "")
    if name == "" then return end
    SQ:Rename(ply, name)
end)
netstream.Hook(SQ.Net.ToggleDmg, function(ply) SQ:ToggleDamage(ply) end)
netstream.Hook(SQ.Net.ToggleVoice, function(ply) SQ:ToggleVoice(ply) end)
netstream.Hook(SQ.Net.ToggleMic, function(ply) SQ:ToggleMic(ply) end)
netstream.Hook(SQ.Net.ToggleListen, function(ply) SQ:ToggleListen(ply) end)
netstream.Hook(SQ.Net.Kick, function(ply, targetSid) SQ:Kick(ply, targetSid) end)
netstream.Hook(SQ.Net.Invite, function(ply, targetSid) SQ:Invite(ply, targetSid) end)
netstream.Hook(SQ.Net.InviteRes, function(ply, accept)
    if accept then
        SQ:AcceptInvite(ply)
    else
        SQ:DeclineInvite(ply)
    end
end)

netstream.Hook(SQ.Net.NearbyReq, function(ply) netstream.Start(ply, SQ.Net.NearbyList, SQ:GetNearby(ply)) end)
VERSE.Hook.AddNS("Squad", "EntityTakeDamage", "VERSE::Squad::DamageFilter", function(ent, dmgInfo)
    if not ent:IsPlayer() then return end
    local attacker = dmgInfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == ent then return end
    local aSid = attacker:GetSquadId()
    if aSid == "" or aSid ~= ent:GetSquadId() then return end
    local squad = SQ._squads[aSid]
    if squad and not squad.damageEnabled then dmgInfo:SetDamage(0) end
end)

-- Identifiant distinct de "VERSE::PlayerCanHearPlayersVoice::Voice" (sv_voice.lua)
-- pour éviter l'écrasement. Ce hook tourne EN PREMIER (squads < voice alphabétiquement
-- → seq plus bas → priorité d'exécution plus haute dans VERSE.Hook.Call).
-- Il gère uniquement les cas squad et retourne nil sinon, laissant sv_voice gérer le reste.
VERSE.Hook.AddNS("Squad", "PlayerCanHearPlayersVoice", "VERSE::PlayerCanHearPlayersVoice::Squad", function(listener, speaker)
    if not (IsValid(listener) and IsValid(speaker)) then return end
    if not (listener:IsPlayer() and speaker:IsPlayer()) then return end

    local speakerSquad = speaker:GetSquadId()
    local listenerSquad = listener:GetSquadId()
    local sameSquad = speakerSquad ~= "" and speakerSquad == listenerSquad

    -- Membres de la même squad : bypass total de la distance de voix
    if sameSquad then
        if not speaker:IsSquadMicOn() then return false, false end
        if not listener:IsSquadListenOn() then return false, false end
        return true, false   -- entend sans limite de distance, non-spatial
    end

    -- Le speaker est en mode voix squad uniquement : les non-squad ne peuvent pas entendre
    if speaker:HasSquadVoice() then
        return false, false
    end

    -- Cas non-squad : laisser sv_voice.lua gérer (return nil = hook suivant)
end)

VERSE.Hook.AddNS("Squad", "PlayerDisconnected", "VERSE::Squad::PlayerDisconnected", function(ply)
    _sqCooldown[ply:SteamID()] = nil
    SQ:Leave(ply)
end)