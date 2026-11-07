VERSE.Animations = VERSE.Animations or {}
local Animations = VERSE.Animations
Animations.Net = {
    RequestPlay = "VERSE::Animations::RequestPlay",
    RequestStop = "VERSE::Animations::RequestStop",
}

Animations.Config = {
    SlotCount = 8,
    RequestCooldown = 0.25,
    StopCooldown = 0.08,
    DataPath = "verse/animation_slots.json",
    MaxSequenceLength = 96,
}

Animations.Config.AvailableAnimations = {
    -- ── EMOTE VERSE JJK ───────────────────────────────────────────────────────
    { name = "Emote 1",  sequence = "f606-jjk-toji-as_cp_170_00_situationoverview_06_r", loop = true, rate = 1 },
    { name = "Emote 2",  sequence = "sit_zen",                                            loop = true, rate = 1 },
    { name = "Emote 3",  sequence = "yc_goden_an_hero_goden_common_sit_idle_01",          loop = true, rate = 1 },
    { name = "Emote 4",  sequence = "yc_klaus_an_hero_klaus_common_sit_idle_01",          loop = true, rate = 1 },
    { name = "Emote 5",  sequence = "yc_anim_an_hero_jack_common_sit_idle_04",            loop = true, rate = 1 },
    { name = "Emote 6",  sequence = "yc_licht_an_hero_licht_common_sit_idle_01",          loop = true, rate = 1 },
    { name = "Emote 7",  sequence = "nue_transition_loop_to_idle",                        loop = true, rate = 1 },
    { name = "Emote 8",  sequence = "yc_heath_an_hero_heath_common_sit_idle_04",          loop = true, rate = 1 },
    { name = "Emote 9",  sequence = "yc_rhya_an_hero_rhya_common_sit_idle_04",            loop = true, rate = 1 },
    { name = "Emote 10", sequence = "yc_luck_an_hero_luck_common_sit_idle_04",            loop = true, rate = 1 },
    { name = "Emote 11", sequence = "yc_finral_an_hero_finral_common_sit_random_idle_01_loop", loop = true, rate = 1 },
    { name = "Emote 12", sequence = "a_p0001_v00_c00_baseguard01_1 retarget",             loop = true, rate = 1 },
    { name = "Emote 13", sequence = "taunt_cheer_base",                                   loop = true, rate = 1 },
    { name = "Emote 14", sequence = "yc_anim_an_hero_jack_arena_retire_loop",             loop = true, rate = 1 },
    { name = "Emote 15", sequence = "yc_asta_an_hero_asta_seq_think_loop",                loop = true, rate = 1 },
    { name = "Emote 16", sequence = "pose_standing_01",                                   loop = true, rate = 1 },
    { name = "Emote 17", sequence = "pose_standing_04",                                   loop = true, rate = 1 },
    { name = "Emote 18", sequence = "taunt_dance_base",                                   loop = true, rate = 1 },
    { name = "Emote 19", sequence = "taunt_muscle_base",                                  loop = true, rate = 1 },
    { name = "Emote 20", sequence = "taunt_robot_base",                                   loop = true, rate = 1 },
    { name = "Emote 21", sequence = "ald_customman_etc_emotion_photosoot_type04_start retarget", loop = true, rate = 1 },
    { name = "Emote 22", sequence = "ald_customman_etc_emotion_d29_pose_start retarget",  loop = true, rate = 1 },
    { name = "Emote 23", sequence = "ald_customman_etc_emotion_gorilla retarget",         loop = true, rate = 1 },
    { name = "Emote 24", sequence = "ald_customman_etc_emotion_dance_type02_loop retarget", loop = true, rate = 1 },
    { name = "Emote 25", sequence = "ald_customman_etc_emotion_photosoot_type02_start retarget", loop = true, rate = 1 },
    { name = "Emote 26", sequence = "ald_customman_etc_emotion_dance_type05 retarget",    loop = true, rate = 1 },
    { name = "Emote 27", sequence = "ald_customman_etc_emotion_frustrate_loop retarget",  loop = true, rate = 1 },
    { name = "Emote 28", sequence = "ald_customman_etc_emotion_cry_type02_start retarget", loop = true, rate = 1 },
    { name = "Emote 29", sequence = "ald_d21_attack_bkick retarget",                      loop = true, rate = 1 },
    { name = "Emote 30", sequence = "ald_customman_etc_emotion_etc_win_type01_loop retarget", loop = true, rate = 1 },
    { name = "Emote 31", sequence = "ald_customman_etc_emotion_wave_type01_loop retarget", loop = true, rate = 1 },
    { name = "Emote 32", sequence = "ald_customman_etc_emotion_attack_hand_windmill retarget", loop = true, rate = 1 },
    { name = "Emote 33", sequence = "a_p1015_v00_c00_atkskl11",                           loop = true, rate = 1 },
    { name = "Emote 34", sequence = "ald_customman_etc_emotion_sports_type04 retarget",   loop = true, rate = 1 },
    { name = "Emote 35", sequence = "ald_customman_etc_emotion_sports_type03_loop retarget", loop = true, rate = 1 },
    { name = "Emote 36", sequence = "ald_customman_etc_emotion_sports_type01_loop retarget", loop = true, rate = 1 },
    { name = "Emote 37", sequence = "ald_customman_etc_emotion_sports_type02_loop retarget", loop = true, rate = 1 },
    { name = "Emote 38", sequence = "ald_customman_lobby_shootwoman_getset_loop retarget", loop = true, rate = 1 },
    { name = "Emote 39", sequence = "a_abdo1",                                            loop = true, rate = 1 },
    { name = "Emote 40", sequence = "gesture_disagree_original",                          loop = true, rate = 1 },
    { name = "Emote 41", sequence = "gesture_bow_original",                               loop = true, rate = 1 },
    { name = "Emote 42", sequence = "anim_pose_orochimaru",                               loop = true, rate = 1 },
    { name = "Emote 43", sequence = "a_pomp2",                                            loop = true,  rate = 1 },
    -- ── EMOTES AJOUTÉS ────────────────────────────────────────────────────────────
    { name = "Bras tendu sur le cote",                    sequence = "tkg_emote5",                                                          loop = true,  rate = 1 },
    { name = "Bras croises dans les manches debout",      sequence = "ev001_zoro_a_010",                                                    loop = true,  rate = 1 },
    { name = "Assis en tailleur bras caches",             sequence = "ev001_zoro_f_010",                                                    loop = true,  rate = 1 },
    { name = "Recule effrayé",                            sequence = "eaufear",                                                             loop = true,  rate = 1 },
    { name = "Accroupi tete baissee",                     sequence = "flammefatigue",                                                       loop = true,  rate = 1 },
    { name = "Plie en deux essoufflee",                   sequence = "filsfatigue",                                                         loop = true,  rate = 1 },
    { name = "Bras ecartes intimidant",                   sequence = "fleche_run_base",                                                     loop = true,  rate = 1 },
    { name = "Regarde autour de soi",                     sequence = "a_p0003_v00_c00_vsbattleed01_0",                                      loop = true,  rate = 1 },
    { name = "Posture basse pret a bondir",               sequence = "a_p0004_v00_c00_basenut01_1_vp",                                      loop = true,  rate = 1 },
    { name = "Main sur le front",                         sequence = "a_p0011_v00_c00_basecharge01_2",                                      loop = true,  rate = 1 },
    { name = "Main levee en signe de paix",               sequence = "a_p0011_v00_c00_vsbattleed01_1_sup",                                  loop = true,  rate = 1 },
    { name = "Position de combat decontractee",           sequence = "ald_customman_etc_emotion_brucestep retarget",                        loop = true,  rate = 1 },
    { name = "Tope-la a deux mains",                      sequence = "ald_customman_etc_emotion_combination_type01 retarget",               loop = false, rate = 1 },
    { name = "S evente avec la main",                     sequence = "ald_customman_etc_emotion_hot_loop retarget",                         loop = true,  rate = 1 },
    { name = "Doigts en ciseaux",                         sequence = "ald_customman_etc_emotion_janken_choki retarget",                     loop = false, rate = 1 },
    { name = "Poing ferme tendu",                         sequence = "ald_customman_etc_emotion_janken_gu retarget",                        loop = false, rate = 1 },
    { name = "Main ouverte a plat",                       sequence = "ald_customman_etc_emotion_janken_pa retarget",                        loop = false, rate = 1 },
    { name = "Tourbillon en garde",                       sequence = "ald_customman_etc_emotion_jiraiya_etc_win_type01_start retarget",     loop = true,  rate = 1 },
    { name = "Dab classique",                             sequence = "ald_customman_etc_emotion_photosoot_type03_start retarget",           loop = false, rate = 1 },
    { name = "Main dans les cheveux de profil",           sequence = "ald_customman_etc_emotion_pose_type01_start retarget",                loop = true,  rate = 1 },
    { name = "Mains sur les hanches",                     sequence = "ald_customman_etc_emotion_pose_type02_start retarget",                loop = true,  rate = 1 },
    { name = "Concentration mains jointes",               sequence = "ald_customman_etc_emotion_pose_type14 retarget",                      loop = false, rate = 1 },
    { name = "Salut de la main",                          sequence = "ald_customman_etc_emotion_sayonara_type01 retarget",                  loop = true,  rate = 1 },
    { name = "Couche a plat ventre",                      sequence = "ald_customman_etc_emotion_sleep_type01_start retarget",               loop = true,  rate = 1 },
    { name = "Hausse les epaules",                        sequence = "ald_customman_etc_emotion_team_fin retarget",                         loop = false, rate = 1 },
    { name = "Secoue la tete negativement",               sequence = "ald_customman_etc_emotion_type01 retarget",                           loop = false, rate = 1 },
    { name = "Saute de joie bras en l air",               sequence = "ald_customman_choji_etc_win_type01_start retarget",                   loop = true,  rate = 1 },
    { name = "Fente avant poing serre",                   sequence = "a_p1012_v00_c90_splmskready01_1",                                    loop = true,  rate = 1 },
    { name = "Pouce leve approbateur",                    sequence = "ald_customman_guy_etc_win_type01_start retarget",                     loop = false, rate = 1 },
    { name = "Poing leve menacant",                       sequence = "ald_customman_guy_etc_win_type02_start retarget",                     loop = false, rate = 1 },
    { name = "Poing serre devant soi",                    sequence = "ald_customman_lobby_attackman_getset_loop retarget",                  loop = true,  rate = 1 },
    { name = "Debout bras le long du corps",              sequence = "ald_customman_lobby_defendman_getset_loop retarget",                  loop = true,  rate = 1 },
    { name = "Bras croises style cool",                   sequence = "ald_customman_lobby_shootman_getset_loop retarget",                   loop = true,  rate = 1 },
    { name = "Bras leves en V de victoire",               sequence = "ald_customman_naruto_etc_win_type02_start retarget",                  loop = false, rate = 1 },
    { name = "Main tendue paume en avant",                sequence = "ald_customman_etc_emotion_d32_start retarget",                        loop = true,  rate = 1 },
    { name = "Applaudissements lents",                    sequence = "sda_emote12",                                                         loop = true,  rate = 1 },
    { name = "Doigt accusateur tendu",                    sequence = "sda_emote14",                                                         loop = true,  rate = 1 },
    { name = "Penche en arriere de rire",                 sequence = "sda_emote15",                                                         loop = true,  rate = 1 },
    { name = "Rire mains sur le ventre",                  sequence = "sda_emote29",                                                         loop = true,  rate = 1 },
    { name = "Esquive laterale fente",                    sequence = "sda_emote33",                                                         loop = true,  rate = 1 },
    { name = "Salutation inclince respectueuse",          sequence = "sda_emote38",                                                         loop = false, rate = 1 },
    { name = "Assis jambes ecartes relax",                sequence = "sda_emote46",                                                         loop = true,  rate = 1 },
    { name = "Agenouille en seiza",                       sequence = "sda_emote47",                                                         loop = true,  rate = 1 },
    { name = "Main qui passe dans les cheveux",           sequence = "sda_emote5",                                                          loop = true,  rate = 1 },
    { name = "Coup d oeil par dessus l epaule",           sequence = "sda_emote9",                                                          loop = true,  rate = 1 },
    { name = "Mains dans les poches style",               sequence = "sda_emote52",                                                         loop = true,  rate = 1 },
}

Animations.SkipPatterns = {"walk", "run", "sprint", "idle", "move", "strafe", "turn", "swim", "jump", "land", "fall", "climb", "crouch", "duck", "reload", "attack", "shoot", "fire", "aim", "melee", "throw", "flinch", "damage", "hit", "death", "die", "ragdoll", "vehicle", "drive", "airwalk", "smg", "ar2", "pistol", "shotgun", "physgun", "camera", "slam", "grenade", "passive", "hostage", "fist", "zombie", "knife", "sit_rollercoaster",}
Animations.PreferredPatterns = {"cross", "salute", "wave", "cheer", "clap", "dance", "sit", "chair", "lay", "sleep", "book", "read", "meditate", "pray", "kneel", "bow", "pose", "taunt", "arms", "lean", "laugh", "point",}
local function trimText(text)
    text = tostring(text or "")
    text = text:gsub("[%c]+", " ")
    text = string.Trim(text)
    return text
end

local function normalizeRate(rate)
    rate = tonumber(rate) or 1
    if rate ~= rate or rate <= 0 then rate = 1 end
    return math.max(rate, 0.001)
end

function Animations.SanitizeSequenceName(seqName)
    seqName = trimText(seqName)
    if seqName == "" then return nil end
    local maxLen = tonumber(Animations.Config.MaxSequenceLength) or 96
    if #seqName > maxLen then seqName = string.sub(seqName, 1, maxLen) end
    return seqName ~= "" and seqName or nil
end

function Animations.FormatLabel(seqName)
    seqName = trimText(seqName)
    if seqName == "" then return "Unassigned" end
    seqName = seqName:gsub("^anim_", "")
    seqName = seqName:gsub("^seq_", "")
    seqName = seqName:gsub("^gesture_", "")
    seqName = seqName:gsub("^act_", "")
    seqName = seqName:gsub("_", " ")
    seqName = seqName:gsub("%s+", " ")
    seqName = seqName:gsub("(%d+)", " %1 ")
    seqName = seqName:gsub("%s+", " ")
    seqName = string.Trim(seqName)
    seqName = seqName:gsub("(%a)([%w']*)", function(first, rest) return string.upper(first) .. string.lower(rest) end)
    return seqName ~= "" and seqName or "Unknown"
end

function Animations.IsSequenceCandidate(seqName)
    seqName = string.lower(trimText(seqName))
    if seqName == "" then return false end
    for _, pattern in ipairs(Animations.SkipPatterns or {}) do
        if string.find(seqName, pattern, 1, true) then return false end
    end
    return true
end

function Animations.GetSequenceScore(seqName)
    seqName = string.lower(trimText(seqName))
    if seqName == "" then return -1000 end
    local score = Animations.IsSequenceCandidate(seqName) and 100 or 0
    for _, pattern in ipairs(Animations.PreferredPatterns or {}) do
        if string.find(seqName, pattern, 1, true) then score = score + 40 end
    end

    if string.find(seqName, "loop", 1, true) then score = score + 10 end
    if string.find(seqName, "pose", 1, true) then score = score + 8 end
    if string.find(seqName, "test", 1, true) then score = score - 40 end
    return score
end

function Animations.GetSlotCount()
    return math.max(tonumber(Animations.Config.SlotCount) or 8, 1)
end

function Animations.NormalizeConfiguredAnimation(raw, index)
    local sequence
    local label
    local loop = false
    local rate = 1
    if isstring(raw) then
        sequence = raw
    elseif istable(raw) then
        label = raw.label or raw.name or raw.title or raw.display or raw[1]
        sequence = raw.sequence or raw.seq or raw.anim or raw.animation or raw[2] or raw[1]
        if istable(raw.opts) then
            if raw.opts.loop ~= nil then loop = raw.opts.loop == true end
            if raw.opts.rate ~= nil then rate = normalizeRate(raw.opts.rate) end
        end

        if raw.loop ~= nil then loop = raw.loop == true end
        if raw.rate ~= nil then rate = normalizeRate(raw.rate) end
    end

    sequence = Animations.SanitizeSequenceName(sequence)
    if not sequence then return nil end
    label = trimText(label)
    if label == "" then label = Animations.FormatLabel(sequence) end
    return {
        name = sequence,
        sequence = sequence,
        key = string.lower(sequence),
        label = label,
        candidate = true,
        order = math.floor(tonumber(index) or 0),
        loop = loop,
        rate = rate,
        opts = {
            loop = loop,
            rate = rate,
        },
    }
end

function Animations.GetConfiguredAnimations()
    local list = {}
    local byKey = {}
    local seen = {}
    for index, raw in ipairs(Animations.Config.AvailableAnimations or {}) do
        local entry = Animations.NormalizeConfiguredAnimation(raw, index)
        if not entry then continue end
        if seen[entry.key] then continue end
        seen[entry.key] = true
        list[#list + 1] = entry
        byKey[entry.key] = entry
    end

    Animations._ConfiguredAnimations = list
    Animations._ConfiguredAnimationsByKey = byKey
    return list
end

function Animations.GetConfiguredEntry(sequence)
    sequence = Animations.SanitizeSequenceName(sequence)
    if not sequence then return nil end
    if not istable(Animations._ConfiguredAnimationsByKey) then Animations.GetConfiguredAnimations() end
    return Animations._ConfiguredAnimationsByKey[string.lower(sequence)]
end