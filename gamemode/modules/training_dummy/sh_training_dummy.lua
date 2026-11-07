VERSE.TrainingDummy = VERSE.TrainingDummy or {}
local TD = VERSE.TrainingDummy

TD.Config = {
    TableName   = "verse_training_dummies",
    MaxRange    = 200,    -- distance max pour la commande remove (unités Hammer)
    DefaultName = "Mannequin",
}

TD.Net = {
    Notify = "VERSE::TrainingDummy::Notify",
}
