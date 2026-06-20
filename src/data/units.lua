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

  -- ══ VAGUE 1 : T1 « enablers » supplémentaires (cf. effects-dot-families.md §H). Ops EXISTANTS, params
  -- variés -> PURE DATA, aucune nouvelle mécanique moteur. `sprite` = visuel de repli. PLACEHOLDERS (P5). ══

  -- BRÛLURE (burst qui décroît, lèche le bouclier) : cadence / front-load / éphémère
  cinder_cur = { -- cadence rapide, petites brûlures qui se rallument souvent
    id = "cinder_cur", sprite = "demon", type = "abyss", cost = 2, hp = 34, dmg = 4, cd = 34,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 4, dur = 120, refresh = true } } },
  },
  pyre_tender = { -- gros coup lent -> grosse brûlure de départ (front-load)
    id = "pyre_tender", sprite = "marauder", type = "flesh", cost = 3, hp = 50, dmg = 7, cd = 72,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 10, dur = 180 } } },
  },
  ash_moth = { -- coût bas, brûlure qui décroît vite (éphémère mais bon marché)
    id = "ash_moth", sprite = "bandit", type = "flesh", cost = 2, hp = 26, dmg = 3, cd = 40,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 7, dur = 120, decayPct = 0.45 } } },
  },

  -- SAIGNEMENT (bas DPS, slow de cadence) : intensité / contrôle pur / épines
  gash_fiend = { -- saignement un peu plus fort, slow standard
    id = "gash_fiend", sprite = "bandit", type = "flesh", cost = 3, hp = 50, dmg = 5, cd = 48,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 3, dur = 240, slowPct = 0.20 } } },
  },
  hookjaw = { -- gros slow, dégâts minimes (pur contrôle de tempo)
    id = "hookjaw", sprite = "marauder", type = "flesh", cost = 3, hp = 58, dmg = 3, cd = 54,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 1, dur = 300, slowPct = 0.30 } } },
  },
  leech_thorn = { -- bleed bas + ÉPINES (punit qui le frappe) : DEUX effets via ops existants
    id = "leech_thorn", sprite = "skeleton", type = "bone", cost = 3, hp = 46, dmg = 4, cd = 50,
    effects = {
      { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 180, slowPct = 0.10 } },
      { trigger = "on_attacked", op = "thorns", params = { value = 3 } },
    },
  },

  -- POISON (N stacks, malus de valeur) : malus de base / longue durée
  bile_spitter = { -- stacks moyens + malus de valeur de base
    id = "bile_spitter", sprite = "witch", type = "arcane", cost = 3, hp = 42, dmg = 5, cd = 56,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, weaken = 0.10 } } },
  },
  rot_grub = { -- stacks LONGUE durée (entretien facile du total) — POISON malgré le nom
    id = "rot_grub", sprite = "demon", type = "abyss", cost = 3, hp = 48, dmg = 4, cd = 58,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 300 } } },
  },

  -- POURRITURE (enfle, ampute les PV max) : cadence / long terme / amputation forte
  carrion_pecker = { -- cadence rapide -> enfle vite (mais cap bas)
    id = "carrion_pecker", sprite = "bandit", type = "flesh", cost = 2, hp = 38, dmg = 4, cd = 38,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 180, capDps = 6, maxHpFrac = 0.10 } } },
  },
  maggot_king = { -- démarrage lent, cap HAUT (récompense le long terme)
    id = "maggot_king", sprite = "skeleton", type = "bone", cost = 4, hp = 70, dmg = 5, cd = 64,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 300, capDps = 12, maxHpFrac = 0.15 } } },
  },
  necro_leech = { -- pourriture + amputation RENFORCÉE des PV max
    id = "necro_leech", sprite = "demon", type = "abyss", cost = 3, hp = 50, dmg = 5, cd = 56,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.35 } } },
  },

  -- ══ VAGUE 2 : AURAS d'adjacence (T1.5 « semeurs »). Build-résolues via le GRAPHE du sigil (buildComp +
  -- board:neighbors), comme shield_aura -> AUCUN op combat (ignorées gracieusement à combat_start). Elles
  -- ne posent PAS le DoT elles-mêmes : elles AMPLIFIENT le voisin qui le pose (la synergie positionnelle). ══
  soot_acolyte = { -- BRÛLURE : +dps aux brûlures des voisins
    id = "soot_acolyte", sprite = "witch", type = "arcane", cost = 3, hp = 36, dmg = 4, cd = 60,
    effects = { { trigger = "combat_start", op = "aura_burn_dps", target = "neighbors", params = { bonus = 2 } } },
  },
  clot_mender = { -- SAIGNEMENT : les voisins appliquent AUSSI un petit bleed
    id = "clot_mender", sprite = "skeleton", type = "bone", cost = 3, hp = 44, dmg = 4, cd = 56,
    effects = { { trigger = "combat_start", op = "aura_grant_bleed", target = "neighbors", params = { dps = 1, dur = 180, slowPct = 0.10 } } },
  },
  miasma_acolyte = { -- POISON : +dps aux stacks de poison des voisins
    id = "miasma_acolyte", sprite = "witch", type = "arcane", cost = 3, hp = 36, dmg = 4, cd = 60,
    effects = { { trigger = "combat_start", op = "aura_poison_dps", target = "neighbors", params = { bonus = 1 } } },
  },
  decay_tender = { -- POURRITURE : +growth aux pourritures des voisins (enflent plus vite)
    id = "decay_tender", sprite = "skeleton", type = "bone", cost = 3, hp = 50, dmg = 4, cd = 60,
    effects = { { trigger = "combat_start", op = "aura_rot_growth", target = "neighbors", params = { bonus = 1 } } },
  },

  -- ══ VAGUE 3 : T2 « twists » (cf. effects-dot-families.md §H). Chacun = l'effet + UNE torsion. Ops
  -- bornés/gated (comportement de base inchangé -> golden stable). corruptor est DÉJÀ le T2 poison-weaken. ══

  -- BRÛLURE T2
  bellows_priest = { -- anti-décroissance : la brûlure décroît bien moins (maintien facilité)
    id = "bellows_priest", sprite = "demon", type = "abyss", cost = 3, hp = 44, dmg = 5, cd = 58,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 6, dur = 180, decayPct = 0.15 } } },
  },
  wildfire_hound = { -- à la mort d'un ennemi en feu, propage la brûlure à ses voisins (proximité champ)
    id = "wildfire_hound", sprite = "demon", type = "abyss", cost = 3, hp = 48, dmg = 5, cd = 54,
    effects = {
      { trigger = "on_hit", op = "burn", params = { dps = 5, dur = 150 } },
      { trigger = "on_death", op = "spread_burn_on_death", params = { frac = 0.7, minDps = 3, dur = 120 } },
    },
  },
  kiln_warden = { -- convertit le surplus : une brûlure plus faible PROLONGE au lieu d'être perdue
    id = "kiln_warden", sprite = "marauder", type = "flesh", cost = 3, hp = 52, dmg = 5, cd = 60,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 5, dur = 180, mode = "extend_if_weaker" } } },
  },

  -- SAIGNEMENT T2
  bloodletter = { -- le saignement ÉCLATE (×2) quand la cible attaque (payoff conditionnel)
    id = "bloodletter", sprite = "bandit", type = "flesh", cost = 3, hp = 48, dmg = 5, cd = 48,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 240, slowPct = 0.20, aggravateMult = 2.0 } } },
  },
  tendon_render = { -- le slow SCALE avec les PV manquants (plus elle saigne, plus elle ralentit)
    id = "tendon_render", sprite = "skeleton", type = "bone", cost = 3, hp = 50, dmg = 4, cd = 50,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 240, slowPct = 0.15, slowScalesMissingHp = true } } },
  },
  vein_splitter = { -- saignement profond et rapide (« deux entailles » ; 2-instances approximé par 1 fort)
    id = "vein_splitter", sprite = "bandit", type = "flesh", cost = 3, hp = 46, dmg = 4, cd = 44,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 4, dur = 180, slowPct = 0.15 } } },
  },

  -- POISON T2 (corruptor = le 3e, déjà présent)
  plague_bearer = { -- CONTAGION : le poison se propage en stack plus faible aux voisins de la cible
    id = "plague_bearer", sprite = "witch", type = "arcane", cost = 3, hp = 40, dmg = 5, cd = 58,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, spread = { dps = 1, dur = 120 } } } },
  },
  acid_maw = { -- le venin RONGE le bouclier (−30 % par pose : dissout l'armure)
    id = "acid_maw", sprite = "demon", type = "abyss", cost = 3, hp = 46, dmg = 5, cd = 56,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, shieldEat = 0.30 } } },
  },

  -- POURRITURE T2
  patient_worm = { -- la pourriture enfle même SANS frapper (ramp passif tant qu'active)
    id = "patient_worm", sprite = "skeleton", type = "bone", cost = 3, hp = 54, dmg = 4, cd = 60,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, passiveRamp = 1, dur = 240, capDps = 10, maxHpFrac = 0.10 } } },
  },
  hollow_gut = { -- l'amputation des PV max NOURRIT le porteur (vol de plafond de vie)
    id = "hollow_gut", sprite = "demon", type = "abyss", cost = 3, hp = 50, dmg = 5, cd = 58,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.20, amputateHealsMe = 0.5 } } },
  },
  blight_spreader = { -- à la mort d'une cible pourrie, la pourriture prend ses voisins (proximité champ)
    id = "blight_spreader", sprite = "skeleton", type = "bone", cost = 3, hp = 52, dmg = 5, cd = 56,
    effects = {
      { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.15 } },
      { trigger = "on_death", op = "spread_rot", params = { base = 2, dur = 240, capDps = 10, maxHpFrac = 0.10 } },
    },
  },
}

-- Roster complet (ordre d'affichage). Les 6 premiers = vanille/v0 ; les suivants = familles de statuts.
U.order = { "marauder", "templar", "skeleton", "bandit", "witch", "demon",
  "spore_tick", "corruptor", "emberling", "razorkin", "rot_hound", "stormcaller", "plague_doctor",
  -- vague 1 (T1 enablers) : burn / bleed / poison / rot
  "cinder_cur", "pyre_tender", "ash_moth",
  "gash_fiend", "hookjaw", "leech_thorn",
  "bile_spitter", "rot_grub",
  "carrion_pecker", "maggot_king", "necro_leech",
  -- vague 2 (auras d'adjacence) : burn / bleed / poison / rot
  "soot_acolyte", "clot_mender", "miasma_acolyte", "decay_tender",
  -- vague 3 (T2 twists) : burn / bleed / poison / rot
  "bellows_priest", "wildfire_hound", "kiln_warden",
  "bloodletter", "tendon_render", "vein_splitter",
  "plague_bearer", "acid_maw",
  "patient_worm", "hollow_gut", "blight_spreader" }

-- Pool d'unités ACHETABLES en boutique (cf. src/run/state.lua). Identique au roster pour l'instant.
U.pool = { "marauder", "templar", "skeleton", "bandit", "witch", "demon",
  "spore_tick", "corruptor", "emberling", "razorkin", "rot_hound", "stormcaller", "plague_doctor",
  "cinder_cur", "pyre_tender", "ash_moth",
  "gash_fiend", "hookjaw", "leech_thorn",
  "bile_spitter", "rot_grub",
  "carrion_pecker", "maggot_king", "necro_leech",
  "soot_acolyte", "clot_mender", "miasma_acolyte", "decay_tender",
  "bellows_priest", "wildfire_hound", "kiln_warden",
  "bloodletter", "tendon_render", "vein_splitter",
  "plague_bearer", "acid_maw",
  "patient_worm", "hollow_gut", "blight_spreader" }

-- Visuel (rig) d'une unité : son propre id, ou un `sprite` de repli (réutilise une créature existante
-- tant que le pixel-art dédié n'existe pas, cf. src/data/creatures.lua).
function U.spriteOf(id) local u = U[id]; return (u and u.sprite) or id end

return U
