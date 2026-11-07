local TD = VERSE.TrainingDummy
if not TD then return end

-- ─── Notifications ───────────────────────────────────────────────────────────
-- Reçoit les messages de feedback admin (place/remove) et les affiche en chat.

netstream.Hook(TD.Net.Notify, function(msg, kind)
    kind = kind or "info"
    local col
    if     kind == "success" then col = Color(100, 220, 100)
    elseif kind == "error"   then col = Color(255, 80,  80)
    else                          col = Color(180, 200, 255)
    end
    chat.AddText(col, "[Mannequin] ", color_white, tostring(msg))
end)
