VERSE.Config = VERSE.Config or {
    Debug = true,
    LogLevel = "info",
    FlashlightMode = false,
    Modules = {},
    Access = {
        -- Liste des développeurs définie côté serveur uniquement (sv_config.lua)
        Developers = {},
        StaffGroups = {"admin"},
        StaffPlusGroups = {"superadmin",},
        Rights = {
            user = {
                SpawnMenuOpen = false,
                CanTool = false,
                CanDrive = false,
                Spawn = {
                    prop = false,
                    effect = false,
                    ragdoll = false,
                    swep = false,
                    sent = false,
                    npc = false,
                    vehicle = false,
                },
                AllowedProperties = {}
            },
            staff = {
                SpawnMenuOpen = true,
                CanTool = true,
                CanDrive = true,
                Spawn = {
                    prop = true,
                    effect = true,
                    ragdoll = true,
                    vehicle = true,
                },
                AllowedProperties = {
                    remover = true,
                    ignite = true,
                    extinguish = true,
                }
            },
            staffplus = {
                SpawnMenuOpen = true,
                Spawn = {
                    swep = true,
                    sent = true,
                    npc = true,
                },
                AllowedProperties = {
                    drive = true,
                }
            },
            developer = {
                SpawnMenuOpen = true,
                Spawn = {
                    prop = true,
                    effect = true,
                    ragdoll = true,
                    swep = true,
                    sent = true,
                    npc = true,
                    vehicle = true,
                },
                CanTool = true,
                CanDrive = true,
                AllowedProperties = {
                    remover = true,
                    ignite = true,
                    extinguish = true,
                    drive = true,
                }
            }
        },
        GroupRights = {},
    },
    Rank = {
        PreferSecondary = true,
        FallbackToPrimary = true,
        Lowercase = false,
        Trim = true,
        TreatAsEmpty = {
            [""] = true,
            ["user"] = true,
            [" "] = true,
        },
        SecondaryMethod = "GetSecondaryUserGroup",
        DefaultRank = "user",
    },
    I18N = {
        Default = "fr",
        Fallback = "fr",
        Supported = {"ru", "en", "fr"},
    },
    Particles = {
        Files = {},
        Systems = {},
    },
    Jobs = {
        Enabled = true,
        DefaultJobID = "citizen",
        Persist = true,
        PersistKey = "verse_job_id",
    },
}