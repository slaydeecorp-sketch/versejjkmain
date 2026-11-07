local W = VERSE.Wallet

W._clientAmount = W._clientAmount or 0

-- ─── Accès client ─────────────────────────────────────────────────────────────

function W:GetAmount()
    return self._clientAmount or 0
end

-- ─── Réception de la sync serveur ─────────────────────────────────────────────

netstream.Hook(W.Net.Sync, function(amount)
    VERSE.Wallet._clientAmount = math.max(0, math.floor(tonumber(amount) or 0))
    -- Notifie les UI qui affichent le portefeuille
    VERSE.Hook.Call("VERSE::Wallet::Updated", VERSE.Wallet._clientAmount)
end)
