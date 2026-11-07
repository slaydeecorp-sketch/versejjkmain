-- sv_heritage.lua
-- Commandes admin pour attribuer un heritage à un joueur.
--
-- Usage console :
--   verse_heritage <steamid|nom> <hanami|jogo|itadori|todo|yuta>
--   verse_heritage_hanami  <steamid|nom>
--   verse_heritage_jogo    <steamid|nom>
--   verse_heritage_itadori <steamid|nom>
--   verse_heritage_todo    <steamid|nom>
--   verse_heritage_yuta    <steamid|nom>
-- ─────────────────────────────────────────────────────────────────────────────

local function notify(caller, msg, level)
    level = level or NOTIFY_HINT
    if IsValid(caller) and isfunction(caller.Notify) then
        caller:Notify(msg, level, 5)
    else
        print("[Heritage] " .. tostring(msg))
    end
end

local function resolveTarget(raw)
    raw = tostring(raw or ""):Trim()
    if raw == "" then return nil end
    local ST = VERSE and VERSE.SkillTree
    -- Recherche directe par SteamID
    if ST and isfunction(ST.IsValidSteamID) and ST:IsValidSteamID(raw) then
        return ST:FindOnlinePlayerBySteamID(raw)
    end
    -- Recherche par nom (insensible à la casse)
    local search = string.lower(raw)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(tostring(p:Nick() or "")), search, 1, true) then
            return p
        end
    end
    return nil
end

local VALID_HERITAGES = {
    hanami  = "heritage_hanami",
    jogo    = "heritage_jogo",
    itadori = "heritage_itadori",
    todo    = "heritage_todo",
    yuta    = "heritage_yuta",
    finger  = "heritage_finger",
}

-- ─── Commande principale : verse_heritage <joueur> <hanami|jogo> ─────────────
local function cmdHeritage(caller, args)
    if IsValid(caller) and not caller:IsDeveloper() and not caller:IsSuperAdmin() then
        notify(caller, "Permission refusee.", NOTIFY_ERROR)
        return
    end

    local targetArg   = tostring(args[1] or ""):Trim()
    local heritageKey = string.lower(tostring(args[2] or ""):Trim())

    if targetArg == "" or heritageKey == "" then
        notify(caller, "Usage: verse_heritage <steamid|nom> <hanami|jogo|itadori|todo|yuta|finger>", NOTIFY_HINT)
        return
    end

    local subtypeId = VALID_HERITAGES[heritageKey]
    if not subtypeId then
        notify(caller, "Heritage inconnu '" .. heritageKey .. "'. Valides : hanami, jogo, itadori, todo, yuta, finger", NOTIFY_ERROR)
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

        local label = heritageKey:sub(1,1):upper() .. heritageKey:sub(2)
        local suffix = (refund and refund > 0) and (" (remboursement : " .. refund .. " pts)") or ""

        notify(caller, "Heritage '" .. label .. "' attribue a " .. targetPly:Nick() .. suffix, NOTIFY_HINT)

        if IsValid(targetPly) and isfunction(targetPly.Notify) then
            targetPly:Notify("Votre heritage a ete mis a jour : " .. label, NOTIFY_HINT, 5)
        end
    end)
end

VERSE.Commands.Add("verse_heritage", cmdHeritage, nil, "server")

-- ─── Raccourcis dédiés ───────────────────────────────────────────────────────
-- verse_heritage_hanami <joueur>
VERSE.Commands.Add("verse_heritage_hanami", function(caller, args)
    cmdHeritage(caller, { tostring(args[1] or ""), "hanami" })
end, nil, "server")

-- verse_heritage_jogo <joueur>
VERSE.Commands.Add("verse_heritage_jogo", function(caller, args)
    cmdHeritage(caller, { tostring(args[1] or ""), "jogo" })
end, nil, "server")

-- verse_heritage_itadori <joueur>
VERSE.Commands.Add("verse_heritage_itadori", function(caller, args)
    cmdHeritage(caller, { tostring(args[1] or ""), "itadori" })
end, nil, "server")

-- verse_heritage_todo <joueur>
VERSE.Commands.Add("verse_heritage_todo", function(caller, args)
    cmdHeritage(caller, { tostring(args[1] or ""), "todo" })
end, nil, "server")

-- verse_heritage_yuta <joueur>
VERSE.Commands.Add("verse_heritage_yuta", function(caller, args)
    cmdHeritage(caller, { tostring(args[1] or ""), "yuta" })
end, nil, "server")

-- verse_heritage_finger <joueur>
VERSE.Commands.Add("verse_heritage_finger", function(caller, args)
    cmdHeritage(caller, { tostring(args[1] or ""), "finger" })
end, nil, "server")
