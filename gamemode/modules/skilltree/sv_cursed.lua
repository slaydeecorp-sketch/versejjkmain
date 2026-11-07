-- sv_cursed.lua
-- Commandes admin pour attribuer un pouvoir maudit à un joueur.
--
-- Usage console :
--   verse_cursed <steamid|nom> <application|invocation|projection|controle>
--   verse_cursed_controle  <steamid|nom>
-- ─────────────────────────────────────────────────────────────────────────────

local function notify(caller, msg, level)
    level = level or NOTIFY_HINT
    if IsValid(caller) and isfunction(caller.Notify) then
        caller:Notify(msg, level, 5)
    else
        print("[Cursed] " .. tostring(msg))
    end
end

local function resolveTarget(raw)
    raw = tostring(raw or ""):Trim()
    if raw == "" then return nil end
    local ST = VERSE and VERSE.SkillTree
    if ST and isfunction(ST.IsValidSteamID) and ST:IsValidSteamID(raw) then
        return ST:FindOnlinePlayerBySteamID(raw)
    end
    local search = string.lower(raw)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(tostring(p:Nick() or "")), search, 1, true) then
            return p
        end
    end
    return nil
end

local VALID_CURSED = {
    application = "cursed_application",
    invocation  = "cursed_invocation",
    projection  = "cursed_projection",
    controle    = "cursed_controle",
}

-- ─── Commande principale : verse_cursed <joueur> <application|invocation|...> ─
local function cmdCursed(caller, args)
    if IsValid(caller) and not caller:IsDeveloper() and not caller:IsSuperAdmin() then
        notify(caller, "Permission refusee.", NOTIFY_ERROR)
        return
    end

    local targetArg = tostring(args[1] or ""):Trim()
    local cursedKey = string.lower(tostring(args[2] or ""):Trim())

    if targetArg == "" or cursedKey == "" then
        notify(caller, "Usage: verse_cursed <steamid|nom> <application|invocation|projection|controle>", NOTIFY_HINT)
        return
    end

    local subtypeId = VALID_CURSED[cursedKey]
    if not subtypeId then
        notify(caller, "Pouvoir maudit inconnu '" .. cursedKey .. "'. Valides : application, invocation, projection, controle", NOTIFY_ERROR)
        return
    end

    local targetPly = resolveTarget(targetArg)
    if not IsValid(targetPly) then
        notify(caller, "Joueur introuvable ou hors ligne : " .. targetArg, NOTIFY_ERROR)
        return
    end

    local ST = VERSE and VERSE.SkillTree
    if not ST or not isfunction(ST.AdminSetBranch) then
        notify(caller, "VERSE.SkillTree indisponible.", NOTIFY_ERROR)
        return
    end

    ST:AdminSetBranch(targetPly, subtypeId, function(ok, _, refund)
        if not ok then
            notify(caller, "Erreur lors de l'attribution de '" .. subtypeId .. "' a " .. targetPly:Nick(), NOTIFY_ERROR)
            return
        end

        local label = cursedKey:sub(1,1):upper() .. cursedKey:sub(2)
        local suffix = (refund and refund > 0) and (" (remboursement : " .. refund .. " pts)") or ""

        notify(caller, "Pouvoir maudit '" .. label .. "' attribue a " .. targetPly:Nick() .. suffix, NOTIFY_HINT)

        if IsValid(targetPly) and isfunction(targetPly.Notify) then
            targetPly:Notify("Votre pouvoir maudit a ete mis a jour : " .. label, NOTIFY_HINT, 5)
        end
    end)
end

VERSE.Commands.Add("verse_cursed", cmdCursed, nil, "server")

-- ─── Raccourcis dédiés ───────────────────────────────────────────────────────
VERSE.Commands.Add("verse_cursed_application", function(caller, args)
    cmdCursed(caller, { tostring(args[1] or ""), "application" })
end, nil, "server")

VERSE.Commands.Add("verse_cursed_invocation", function(caller, args)
    cmdCursed(caller, { tostring(args[1] or ""), "invocation" })
end, nil, "server")

VERSE.Commands.Add("verse_cursed_projection", function(caller, args)
    cmdCursed(caller, { tostring(args[1] or ""), "projection" })
end, nil, "server")

VERSE.Commands.Add("verse_cursed_controle", function(caller, args)
    cmdCursed(caller, { tostring(args[1] or ""), "controle" })
end, nil, "server")

-- ─── Donner un ticket de reroll Pouvoir Maudit ───────────────────────────────
-- verse_give_cursed_reroll <joueur> [montant]
VERSE.Commands.Add("verse_give_cursed_reroll", function(caller, args)
    if IsValid(caller) and not caller:IsDeveloper() and not caller:IsSuperAdmin() then
        notify(caller, "Permission refusee.", NOTIFY_ERROR)
        return
    end

    local targetArg = tostring(args[1] or ""):Trim()
    local amount    = math.max(1, math.floor(tonumber(args[2] or 1) or 1))

    if targetArg == "" then
        notify(caller, "Usage: verse_give_cursed_reroll <steamid|nom> [montant]", NOTIFY_HINT)
        return
    end

    local targetPly = resolveTarget(targetArg)
    if not IsValid(targetPly) then
        notify(caller, "Joueur introuvable ou hors ligne : " .. targetArg, NOTIFY_ERROR)
        return
    end

    local ST = VERSE and VERSE.SkillTree
    if not ST or not isfunction(ST.AdminGiveCursedReroll) then
        notify(caller, "VERSE.SkillTree indisponible.", NOTIFY_ERROR)
        return
    end

    ST:AdminGiveCursedReroll(targetPly, amount, function(ok, resultOrErr)
        if not ok then
            notify(caller, "Erreur : " .. tostring(resultOrErr), NOTIFY_ERROR)
            return
        end
        notify(caller, amount .. " ticket(s) reroll pouvoir maudit donne(s) a " .. targetPly:Nick() .. " (total : " .. tostring(resultOrErr) .. ")", NOTIFY_HINT)
        if IsValid(targetPly) and isfunction(targetPly.Notify) then
            targetPly:Notify("Vous avez recu " .. amount .. " ticket(s) de reroll Pouvoir Maudit.", NOTIFY_HINT, 5)
        end
    end)
end, nil, "server")
