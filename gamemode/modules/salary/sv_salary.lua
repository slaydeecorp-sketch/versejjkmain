local CFG = VERSE.Salary.Config
local CH  = VERSE.Characters

-- ─── Versement du salaire pour un joueur ─────────────────────────────────────

local function paySalary(ply)
    if not IsValid(ply) then return end

    ply:AddMoney(CFG.Amount, function(ok)
        if not ok then return end
        ply:Notify(
            "Salaire verse : +" .. CFG.Amount .. " Y",
            NOTIFY_HINT,
            CFG.NotifDuration
        )
    end)
end

-- ─── Timer individuel : démarre au chargement du personnage ──────────────────

VERSE.Hook.AddNS("Salary", "VERSE::Characters::Loaded", "VERSE::Salary::StartTimer", function(ply, char)
    if not IsValid(ply) or not istable(char) then return end

    local timerName = "VERSE::Salary::Tick::" .. ply:SteamID()
    timer.Remove(timerName)
    timer.Create(timerName, CFG.Interval, 0, function()
        if not IsValid(ply) then timer.Remove(timerName) return end
        -- Vérifie qu'un personnage est toujours sélectionné
        if CH and CH.GetSelected then
            local c = CH:GetSelected(ply)
            if not istable(c) then return end
        end
        paySalary(ply)
    end)
end)

-- ─── Nettoyage à la déconnexion ───────────────────────────────────────────────

hook.Add("PlayerDisconnected", "VERSE::Salary::StopTimer", function(ply)
    timer.Remove("VERSE::Salary::Tick::" .. ply:SteamID())
end)
