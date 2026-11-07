VERSE.Hook.AddNS("I18N", "InitPostEntity", "VERSE::InitPostEntity::I18N", function()
    local cfg = (VERSE.Config and VERSE.Config.I18N) or {}
    VERSE.I18N.Setup(cfg.Default, cfg.Fallback)
end)

VERSE.Hook.AddNS("I18N", "Initialize", "VERSE::Initialize::I18N::Client", function()
    local cfg = (VERSE.Config and VERSE.Config.I18N) or {}
    VERSE.I18N.Setup(cfg.Default, cfg.Fallback)
end)