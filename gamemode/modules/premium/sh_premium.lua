-- ─── Premium subscription ────────────────────────────────────────────────────
-- Trois paliers d'abonnement payant (Tebex).
-- Server : cache steamid64 → { expires_at, tier }, chargé depuis DB.
-- Client : lit le NWInt VERSE::Premium (0 = aucun, 1/2/3 = palier).
-- ─────────────────────────────────────────────────────────────────────────────

VERSE.Premium = VERSE.Premium or {}
local PR = VERSE.Premium

-- NWInt key : 0 = pas premium, 1/2/3 = palier actif.
PR.NW = "VERSE::Premium"

-- ─── Configuration des paliers ────────────────────────────────────────────────
-- duration_secs : durée de l'abonnement en secondes.
-- coins         : points boutique versés à l'activation / renouvellement.
-- extra_slots   : slots de personnage supplémentaires par rapport à la base.
-- exp_mult      : multiplicateur d'EXP (1.5 = +50 %).

PR.Tiers = {
    [1] = {
        name         = "Premium I",
        duration_secs = 30 * 24 * 3600,   -- 1 mois
        exp_mult     = 1.5,
        extra_slots  = 1,
        coins        = 1250,
    },
    [2] = {
        name         = "Premium II",
        duration_secs = 90 * 24 * 3600,   -- 3 mois
        exp_mult     = 1.5,
        extra_slots  = 1,
        coins        = 3750,
    },
    [3] = {
        name         = "Premium III",
        duration_secs = 180 * 24 * 3600,  -- 6 mois
        exp_mult     = 1.5,
        extra_slots  = 1,
        coins        = 8000,
    },
}

-- ─── Helpers partagés ────────────────────────────────────────────────────────

-- Retourne le numéro de palier actif (1/2/3) ou 0 si pas premium.
-- Utilisable depuis les deux realms.
function PR:GetTier(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    if SERVER then
        local entry = self._cache and self._cache[ply:SteamID64()]
        if not istable(entry) then return 0 end
        if entry.expires_at <= os.time() then return 0 end
        return entry.tier or 0
    end
    -- CLIENT
    return ply:GetNWInt(self.NW, 0)
end

-- Retourne true si le joueur a un abonnement actif (quel que soit le palier).
function PR:HasPremium(ply)
    return self:GetTier(ply) > 0
end

-- Retourne la config du palier du joueur, ou nil.
function PR:GetTierConfig(ply)
    return self.Tiers[self:GetTier(ply)]
end

-- Retourne le multiplicateur EXP du joueur (1 si pas premium).
function PR:GetEXPMult(ply)
    local cfg = self:GetTierConfig(ply)
    return cfg and cfg.exp_mult or 1
end

-- Retourne le nombre de slots de personnage supplémentaires du joueur.
function PR:GetExtraSlots(ply)
    local cfg = self:GetTierConfig(ply)
    return cfg and cfg.extra_slots or 0
end
