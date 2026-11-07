VERSE.Hook.AddNS("I18N", "Initialize", "VERSE::Initialize::I18N", function()
    local cfg = (VERSE.Config and VERSE.Config.I18N) or {}
    VERSE.I18N.Setup(cfg.Default, cfg.Fallback)
end)

function VERSE.I18N.SetPlayerLang(ply, lang)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    lang = string.lower(tostring(lang or ""))
    lang = string.match(lang, "^[a-z]+") or lang
    if lang == "" then return end
    ply:SetPrivateString("verse_lang", lang)
end

VERSE.Commands.Add("verse_lang", function(ply, args)
    if not IsValid(ply) then return end
    local lang = args[1]
    if not lang then return end
    VERSE.I18N.SetPlayerLang(ply, lang)
end, nil, "server")