-- src/data/units.lua
-- Stats de base + EFFETS (data pure) par créature. Source de vérité unique pour le combat ET la
-- phase de build. Séparé de creatures.lua (qui ne contient que le visuel/rig).
--
-- Couche DATA : ce fichier ne require RIEN de chez nous (pas même le moteur d'effets) — il ne
-- déclare que des descripteurs. Le moteur (src/effects/) les interprète.
--
-- TEXTE AFFICHÉ : plus aucune chaîne d'affichage ici. Noms/passifs/types vivent dans les LOCALES
-- (src/i18n/en.lua : clés `unit.<id>.name|passive_name|passive_desc`, `type.<key>`). units.lua reste
-- du PUR mécanique (id, type-clé, cost, stats, effects). Ajouter une langue = un fichier locale, zéro refacto.
--
-- MODÈLE D'EFFET (cf. docs/research/engine-architecture.md §6) — un effet = donnée :
--   { trigger = <quand>, op = <quoi>, params = <payload>, condition? = <garde>, target? = <cible> }
-- Une unité tient une LISTE `effects` (donc plusieurs effets empilables : passif, relique, aura...).
--   passive = { name, desc } reste pour l'AFFICHAGE (infobulle) ; effects = la mécanique.
--
-- Triggers utilisés v0.2 :
--   on_attack    -> avant le calcul des dégâts (peut modifier ctx.amount)   ex. bonus_first
--   on_hit       -> après dégâts infligés (lit ctx.dealt / applique à la victime) ex. lifesteal, poison
--   on_attacked  -> le défenseur réagit quand il est frappé               ex. thorns
--   combat_start -> résolu au BUILD via l'adjacence du plateau            ex. shield_aura (neighbors)

-- CIBLAGE (cf. docs/research/combat-model-decision.md) : on PEUT ajouter par unité une stat
-- `aggro` (défaut 0 = INERTE ; plus haut = se fait focus en priorité dans sa colonne -> archétype
-- tank) et un flag `taunt` (override dur, plutôt via reliques). Câblés dans le ciblage déterministe,
-- VOLONTAIREMENT non équilibrés pour l'instant (on tune quand les plateaux se remplissent).
--
-- ÉCONOMIE (cf. src/run/state.lua) : `cost` = prix d'achat en boutique. PLACEHOLDERS d'équilibrage
-- (chaff a 2, standard a 3, tank premium a 4) ; raretés/cotes-par-niveau différées (besoin de tiers).
local U = {
  marauder = {
    id = "marauder", type = "flesh", cost = 3, hp = 60, dmg = 9, cd = 60, -- MARAUDER / Brutality
    effects = { { trigger = "on_attack", op = "bonus_first", params = { value = 8 } } },
  },
  templar = {
    id = "templar", type = "order", cost = 4, hp = 95, dmg = 12, cd = 82, -- TEMPLAR / Bulwark
    effects = { { trigger = "combat_start", op = "shield_aura", target = "neighbors", params = { value = 14 } } },
  },
  skeleton = {
    id = "skeleton", type = "bone", cost = 2, hp = 40, dmg = 6, cd = 44, -- SKELETON / Broken Bones
    effects = { { trigger = "on_attacked", op = "thorns", params = { value = 3 } } },
  },
  bandit = {
    id = "bandit", type = "flesh", cost = 2, hp = 46, dmg = 7, cd = 36, -- BANDIT / Nimble
    effects = {}, -- aucun effet mécanique (flavor)
  },
  witch = {
    id = "witch", type = "arcane", cost = 3, hp = 36, dmg = 13, cd = 72, -- WITCH / Venom
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180 } } },
  },
  demon = {
    id = "demon", type = "abyss", cost = 3, hp = 72, dmg = 10, cd = 56, -- DEMON / Leech
    effects = { { trigger = "on_hit", op = "lifesteal", params = { frac = 0.5 } } },
  },

  -- ── Unités à EFFETS (familles de statuts, cf. docs/research/effects-dot-families.md). Le champ
  -- `sprite` RÉUTILISE une créature existante tant que le pixel-art dédié n'existe pas. PLACEHOLDERS. ──
  spore_tick = { -- POISON : cadence rapide, petits stacks (empile vite)
    id = "spore_tick", sprite = "witch", type = "arcane", cost = 2, hp = 30, dmg = 3, cd = 30,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 1, dur = 180 } } },
  },
  corruptor = { -- POISON + malus de valeur (anti-stat)
    id = "corruptor", sprite = "demon", type = "abyss", cost = 3, hp = 46, dmg = 6, cd = 62,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, weaken = 0.06 } } },
  },
  emberling = { -- BRÛLURE : burst qui décroît, lèche le bouclier
    id = "emberling", sprite = "demon", type = "abyss", cost = 2, hp = 40, dmg = 5, cd = 50,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 6, dur = 150 } } },
  },
  razorkin = { -- SAIGNEMENT : slow de cadence
    id = "razorkin", sprite = "bandit", type = "flesh", cost = 3, hp = 52, dmg = 5, cd = 46,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 240, slowPct = 0.20 } } },
  },
  rot_hound = { -- POURRITURE : enfle, ampute les PV max
    id = "rot_hound", sprite = "skeleton", type = "bone", cost = 3, hp = 54, dmg = 5, cd = 56,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.15 } } },
  },
  stormcaller = { -- CHOC : amplifie les dégâts-pris de la cible
    id = "stormcaller", sprite = "witch", type = "arcane", cost = 3, hp = 38, dmg = 6, cd = 58,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 1, perStack = 0.07, cap = 8, dur = 150 } } },
  },
  plague_doctor = { -- CONTRE-DoT : régénération (le contre livré avec les familles)
    id = "plague_doctor", sprite = "templar", type = "order", cost = 4, hp = 80, dmg = 6, cd = 66,
    effects = { { trigger = "combat_start", op = "regen", params = { value = 3 } } },
  },
}

-- Roster complet (ordre d'affichage). Les 6 premiers = vanille/v0 ; les suivants = familles de statuts.
U.order = { "marauder", "templar", "skeleton", "bandit", "witch", "demon",
  "spore_tick", "corruptor", "emberling", "razorkin", "rot_hound", "stormcaller", "plague_doctor" }

-- Pool d'unités ACHETABLES en boutique (cf. src/run/state.lua). Identique au roster pour l'instant.
U.pool = { "marauder", "templar", "skeleton", "bandit", "witch", "demon",
  "spore_tick", "corruptor", "emberling", "razorkin", "rot_hound", "stormcaller", "plague_doctor" }

-- Visuel (rig) d'une unité : son propre id, ou un `sprite` de repli (réutilise une créature existante
-- tant que le pixel-art dédié n'existe pas, cf. src/data/creatures.lua).
function U.spriteOf(id) local u = U[id]; return (u and u.sprite) or id end

return U
