local IT  = VERSE.Interaction
local CFG = IT.Config

-- ─── État serveur ─────────────────────────────────────────────────────────────

IT._pending   = {}        -- [id] = { id, action, requester, target, expires }
IT._carries   = {}        -- [carrierSteamID] = { carrier, carried, _eHoldStart }
IT._pendingId = 0

-- ─── Utilitaires ─────────────────────────────────────────────────────────────

local function newId()
    IT._pendingId = (IT._pendingId + 1) % 999999
    return IT._pendingId
end

local function notify(ply, msg, kind)
    if not IsValid(ply) then return end
    netstream.Start(ply, IT.Net.Notify, msg, kind or "info")
end

local function getCharName(ply)
    if not IsValid(ply) then return "Inconnu" end
    local name = ply:GetNWString("VERSE.CharName", "")
    if name ~= "" then return name end
    if VERSE.Characters and VERSE.Characters.GetSelected then
        local char = VERSE.Characters:GetSelected(ply)
        if istable(char) and char.firstname then
            return (char.firstname or "") .. " " .. (char.lastname or "")
        end
    end
    return ply:Nick()
end

-- ─── Portage ─────────────────────────────────────────────────────────────────

local function stopCarry(carrier)
    if not IsValid(carrier) then return end
    local sid   = carrier:SteamID()
    local carry = IT._carries[sid]
    if not carry then return end

    local carried = carry.carried
    IT._carries[sid] = nil
    timer.Remove("VERSE::Carry::" .. sid)

    if IsValid(carried) then
        carried:SetMoveType(MOVETYPE_WALK)
        carried:SetCollisionGroup(COLLISION_GROUP_PLAYER)
        carried:SetAbsVelocity(Vector(0, 0, 0))
        carried:SetNWBool("VERSE_IsCarried", false)

        -- Arrêter l'animation de portage (netstream → tous les clients)
        carried:StopAnimation()

        -- Poser devant le porteur sur le sol
        local dropPos = IsValid(carrier) and (carrier:GetPos() + carrier:GetForward() * 55) or carried:GetPos()
        local tr = util.TraceLine({
            start  = dropPos + Vector(0, 0, 72),
            endpos  = dropPos - Vector(0, 0, 200),
            filter = function(e) return e ~= carrier and e ~= carried end,
            mask   = MASK_PLAYERSOLID,
        })
        carried:SetPos(tr.Hit and (tr.HitPos + Vector(0, 0, 1)) or dropPos)

        netstream.Start(carrier, IT.Net.CarrySync, false, nil, false)
        netstream.Start(carried, IT.Net.CarrySync, false, nil, false)

        notify(carried, "Vous avez été posé.", "info")
        if IsValid(carrier) then
            notify(carrier, "Vous avez posé " .. getCharName(carried) .. ".", "info")
        end
    end
end

local function startCarry(carrier, carried)
    local sid = carrier:SteamID()

    -- Stopper carry existant
    if IT._carries[sid] then stopCarry(carrier) end

    -- Vérifier que la cible n'est pas déjà portée
    for _, c in pairs(IT._carries) do
        if c.carried == carried then
            notify(carrier, "Ce joueur est déjà porté par quelqu'un.", "error")
            return
        end
    end

    IT._carries[sid] = { carrier = carrier, carried = carried, _eHoldStart = nil }

    carried:SetMoveType(MOVETYPE_NONE)
    carried:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    carried:SetAbsVelocity(Vector(0, 0, 0))
    carried:SetNWBool("VERSE_IsCarried", true)

    -- true = actif | otherPly | isCarrier
    netstream.Start(carrier, IT.Net.CarrySync, true, carried, true)
    netstream.Start(carried, IT.Net.CarrySync, true, carrier, false)

    notify(carrier, "Vous portez " .. getCharName(carried) .. ". Maintenez E pour le poser.", "info")

    -- Lance l'animation de portage sur tous les clients via le système VERSE
    local CARRY_SEQ = "as_cp_090_00_tagcombodamage_cp_190_08_01"
    carried:PlayAnimation(CARRY_SEQ, { loop = true, rate = 1 })

    -- Timer de mise à jour de position (10 Hz : suffisant et 2× moins de SetPos
    -- réseau qu'à 20 Hz ; imperceptible visuellement pour un joueur porté).
    timer.Create("VERSE::Carry::" .. sid, 0.1, 0, function()
        if not IsValid(carrier) or not IsValid(carried) then
            stopCarry(carrier)
            return
        end
        local ang   = carrier:GetAngles()
        local right = ang:Right()
        right.z = 0
        if right:LengthSqr() > 0.01 then right:Normalize() end
        -- Position sur l'épaule droite du porteur
        local carryPos = carrier:GetPos() + right * 16 + Vector(0, 0, 60)
        local carryAng = Angle(0, ang.y, 0)
        carried:SetPos(carryPos)
        carried:SetAngles(carryAng)
        carried:SetAbsVelocity(Vector(0, 0, 0))
    end)
end

-- ─── Handler : demande d'interaction ─────────────────────────────────────────

netstream.Hook(IT.Net.Request, function(ply, action, targetEntIndex)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    -- Reconvertir l'EntIndex en entité
    local target = Entity(tonumber(targetEntIndex) or 0)

    -- "drop" ne nécessite pas de cible valide
    if action == "drop" then
        local sid = ply:SteamID()
        if IT._carries[sid] then
            stopCarry(ply)
        else
            for _, carry in pairs(IT._carries) do
                if carry.carried == ply then
                    stopCarry(carry.carrier)
                    break
                end
            end
        end
        return
    end

    if not IsValid(target) or not target:IsPlayer() then return end
    if ply == target then return end

    if ply:GetPos():Distance(target:GetPos()) > CFG.MaxRange then
        notify(ply, "Ce joueur est trop loin.", "error")
        return
    end

    -- ── Se présenter (immédiat) ───────────────────────────────────────────────
    if action == "presenter" then
        local CH   = VERSE.Characters
        local char = CH and isfunction(CH.GetSelected) and CH:GetSelected(ply)
        local name = getCharName(ply)
        local desc = istable(char) and tostring(char.description or "") or ""

        -- ChatPrint : toujours visible, garantit que la cible voit quelque chose
        target:ChatPrint("━━━━━━━━━━━━━━━━━━━━━━━━")
        target:ChatPrint("✦ " .. name .. " se présente à vous.")
        if desc ~= "" then
            target:ChatPrint("  « " .. desc .. " »")
        end
        target:ChatPrint("━━━━━━━━━━━━━━━━━━━━━━━━")

        -- Feedback au présentateur
        ply:ChatPrint("✦ Vous vous êtes présenté à " .. getCharName(target) .. ".")

        if VERSE.Log then VERSE.Log:Info("[Interaction] " .. ply:Nick() .. " se présente à " .. target:Nick()) end
        return
    end

    -- ── Porter ───────────────────────────────────────────────────────────────
    if action == "porter" then
        -- Si la cible est blessée (pain) → portage automatique sans popup
        if target._inPain then
            startCarry(ply, target)
            if VERSE.Log then VERSE.Log:Info("[Interaction] " .. ply:Nick() .. " porte (auto-pain) " .. target:Nick()) end
            return
        end

        -- Sinon : popup normal avec accord de la cible
        for _, p in pairs(IT._pending) do
            if p.target == target then
                notify(ply, "Ce joueur a déjà une demande en attente.", "error")
                return
            end
        end

        local id = newId()
        IT._pending[id] = {
            id        = id,
            action    = action,
            requester = ply,
            target    = target,
            expires   = CurTime() + CFG.PopupTimeout,
        }

        netstream.Start(target, IT.Net.Popup, id, action, getCharName(ply))
        notify(ply, "Demande envoyée à " .. getCharName(target) .. "...", "info")

        timer.Simple(CFG.PopupTimeout, function()
            if IT._pending[id] then
                IT._pending[id] = nil
                notify(ply, getCharName(target) .. " n'a pas répondu.", "error")
            end
        end)
        return
    end

    -- ── Fouiller (popup requis) ───────────────────────────────────────────────
    if action == "fouiller" then
        for _, p in pairs(IT._pending) do
            if p.target == target then
                notify(ply, "Ce joueur a déjà une demande en attente.", "error")
                return
            end
        end

        local id = newId()
        IT._pending[id] = {
            id        = id,
            action    = action,
            requester = ply,
            target    = target,
            expires   = CurTime() + CFG.PopupTimeout,
        }

        netstream.Start(target, IT.Net.Popup, id, action, getCharName(ply))
        notify(ply, "Demande envoyée à " .. getCharName(target) .. "...", "info")

        timer.Simple(CFG.PopupTimeout, function()
            if IT._pending[id] then
                IT._pending[id] = nil
                notify(ply, getCharName(target) .. " n'a pas répondu.", "error")
            end
        end)
    end
end)

-- ─── Handler : réponse au popup ───────────────────────────────────────────────

netstream.Hook(IT.Net.Response, function(ply, id, accepted)
    id = math.floor(tonumber(id) or 0)
    local pending = IT._pending[id]
    if not pending then return end
    if pending.target ~= ply then return end  -- seule la cible peut répondre

    IT._pending[id] = nil

    local requester = pending.requester
    if not IsValid(requester) then return end

    if not accepted then
        notify(requester, getCharName(ply) .. " a refusé votre demande.", "error")
        return
    end

    -- ── Fouiller ─────────────────────────────────────────────────────────────
    if pending.action == "fouiller" then
        local charName = getCharName(ply)
        local INV      = VERSE.Inventory
        local targetCharId = INV and isfunction(INV.GetCharacterUID) and INV:GetCharacterUID(ply)

        if targetCharId and INV._cache then
            local inv = INV._cache[targetCharId] or {}
            netstream.Start(requester, IT.Net.FouillerInventory, charName, inv)
        else
            -- Fallback si pas d'inventaire chargé
            notify(requester, "Inventaire de " .. charName .. " inaccessible.", "error")
        end

        notify(ply, getCharName(requester) .. " vous a fouillé.", "info")
        if VERSE.Log then VERSE.Log:Info("[Interaction] " .. requester:Nick() .. " fouille " .. ply:Nick()) end

    -- ── Porter ───────────────────────────────────────────────────────────────
    elseif pending.action == "porter" then
        if requester:GetPos():Distance(ply:GetPos()) > CFG.MaxRange * 1.3 then
            notify(requester, getCharName(ply) .. " est trop loin pour être porté.", "error")
            return
        end
        startCarry(requester, ply)
        if VERSE.Log then VERSE.Log:Info("[Interaction] " .. requester:Nick() .. " porte " .. ply:Nick()) end
    end
end)

-- ─── Handler : don d'argent ───────────────────────────────────────────────────

netstream.Hook(IT.Net.MoneyGive, function(ply, targetEntIndex, amount)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local target = Entity(tonumber(targetEntIndex) or 0)
    if not IsValid(target) or not target:IsPlayer() then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if amount > 1000000 then return end

    if ply:GetPos():Distance(target:GetPos()) > CFG.MaxRange then
        notify(ply, "Ce joueur est trop loin.", "error")
        return
    end

    if not isfunction(ply.DeductMoney) or not isfunction(ply.AddMoney) then
        notify(ply, "Système monétaire indisponible.", "error")
        return
    end

    ply:DeductMoney(amount, function(ok)
        if not ok then
            notify(ply, "Vous n'avez pas assez d'argent.", "error")
            return
        end
        if IsValid(target) and isfunction(target.AddMoney) then
            target:AddMoney(amount)
        end
        notify(ply,    "Vous avez donné " .. amount .. " ¥ à " .. getCharName(target) .. ".", "success")
        notify(target, getCharName(ply) .. " vous a donné " .. amount .. " ¥.", "success")
        if VERSE.Log then VERSE.Log:Info("[Interaction] " .. ply:Nick() .. " donne " .. amount .. " ¥ à " .. target:Nick()) end
    end)
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

local function cleanupPlayer(ply)
    -- Stopper si porteur
    if IsValid(ply) and IT._carries[ply:SteamID()] then
        stopCarry(ply)
    end
    -- Stopper si porté
    for sid, carry in pairs(IT._carries) do
        if carry.carried == ply then
            stopCarry(carry.carrier)
            break
        end
    end
    -- Supprimer les pending
    if IsValid(ply) then
        for id, p in pairs(IT._pending) do
            if p.requester == ply or p.target == ply then
                IT._pending[id] = nil
            end
        end
    end
end

hook.Add("PlayerDisconnected",    "VERSE::Interaction::Cleanup",      cleanupPlayer)
hook.Add("PlayerDeath",           "VERSE::Interaction::CleanupDeath", cleanupPlayer)
hook.Add("PlayerEnteredVehicle",  "VERSE::Interaction::CleanupVehicle", cleanupPlayer)
