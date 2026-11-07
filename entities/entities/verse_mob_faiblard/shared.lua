ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Fléaux Faiblard"
ENT.Spawnable = false
ENT.AdminOnly = false

-- ─── Config du mob ────────────────────────────────────────────────────────────

ENT.ModelPath  = "models/jjkf606mob/cn_110.mdl"
ENT.MobName    = "Fléaux Faiblard"
ENT.MobMaxHP   = 200
ENT.MobDamage  = 25
ENT.MobSpeed   = 220   -- unités/s ≈ vitesse de course joueur (~220 u/s)
ENT.MobXP      = 50

-- ─── Hitbox ───────────────────────────────────────────────────────────────────
-- BBox centrée sur l'origine de l'entité (Z symétrique autour de 0).
-- Cela permet à ents.FindInSphere (utilisé par TCS) de trouver le mob
-- car la recherche se fait depuis le centre de l'entité, pas depuis son sol.
-- → Ajuste MobHalfHeight selon la hauteur réelle lue dans la console au spawn
--   (ligne "[MOB] OBBMaxs"). Exemple : si OBBMaxs.z = 38, HalfHeight = 19.
ENT.MobHalfHeight = 24   -- demi-hauteur du mob en unités (total = 48 u)
ENT.MobHalfWidth  = 14   -- demi-largeur/profondeur

ENT.MobBBoxMins = Vector(-ENT.MobHalfWidth, -ENT.MobHalfWidth, -ENT.MobHalfHeight)
ENT.MobBBoxMaxs = Vector( ENT.MobHalfWidth,  ENT.MobHalfWidth,  ENT.MobHalfHeight)

-- ─── Portées ──────────────────────────────────────────────────────────────────

ENT.AggroRange   = 600  -- distance de détection (unités Hammer)
ENT.AttackRange  = 75   -- distance corps à corps
ENT.LoseRange    = 1300 -- distance à partir de laquelle le mob abandonne la cible

-- ─── Timing ───────────────────────────────────────────────────────────────────

ENT.AttackCooldown    = 1.8   -- secondes entre chaque attaque
ENT.AttackDmgFrame    = 0.65  -- seconde dans l'animation où les dégâts sont appliqués
ENT.AttackTotalTime   = 1.5   -- durée totale de l'animation d'attaque
ENT.StaggerDuration   = 0.75  -- durée du stagger
ENT.DeathRemoveDelay  = 5.0   -- secondes avant suppression après la mort

-- ─── Animations ───────────────────────────────────────────────────────────────

ENT.AnimIdle   = "as_cn_110_00_idle_01"
ENT.AnimRun    = "as_cn_110_00_run_01"
ENT.AnimAttack = "as_cn_110_00_attacka_01_01"
ENT.AnimDeath  = "as_cn_110_00_downgroundfd_01"
ENT.AnimHit    = "as_cn_110_00_damagestaggerf_01"
