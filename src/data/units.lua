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
    id = "marauder", type = "flesh", family = "crustace", rank = 1, cost = 1, hp = 60, dmg = 9, cd = 60, aggro = 15, -- MARAUDER / Brutality (bruiser)
    -- GREFFE 9c′ (A6 burst d'exécution) : la pince ACHÈVE le blessé. execute = état PUR (zéro RNG, déterministe) :
    -- sous 25% PV de la cible, +60% dégâts. Remplace l'ancien crit RNG du roster (verbe non-multiplicatif, borné).
    effects = {
      { trigger = "on_attack", op = "bonus_first", params = { value = 8 } },
      { trigger = "on_attack", op = "execute", params = { threshold = 0.25, bonus = 0.60 } },
    },
  },
  templar = {
    id = "templar", type = "order", family = "seraphin", rank = 3, cost = 3, hp = 95, dmg = 12, cd = 82, aggro = 40, -- TEMPLAR / Bulwark (tank)
    -- GREFFE 9c (Armure/T6) : ARMURE-AURA en REMPLACEMENT du shield_aura (7+ porteurs couvrent A9). dmgReduce=0.12
    -- aux voisins -> -12% dégâts d'ATTAQUE subis (lecture damage() cause="attack"). Donne à T6 son ampli agnostique.
    effects = { { trigger = "combat_start", op = "aura_stat", target = "neighbors", params = { stat = "dmgReduce", value = 0.12 } } },
  },
  skeleton = {
    id = "skeleton", type = "bone", family = "mortvivant", rank = 1, cost = 1, hp = 40, dmg = 6, cd = 44, -- SKELETON / Broken Bones
    effects = { { trigger = "on_attacked", op = "thorns", params = { value = 3 } } },
  },
  bandit = {
    id = "bandit", type = "flesh", family = "crustace", rank = 1, cost = 1, hp = 46, dmg = 7, cd = 36, -- BANDIT / Nimble
    effects = {}, -- aucun effet mécanique (flavor)
  },
  witch = {
    id = "witch", type = "arcane", family = "cocon", rank = 2, cost = 2, hp = 36, dmg = 13, cd = 72, aggro = 5, -- WITCH / Venom (carry)
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180 } } },
  },
  demon = {
    -- GREFFE 9c (Leurre/T7) : aggro 25 (soft-leurre — le fanal ATTIRE le focus). 25 < tank 40 (les tanks gardent
    -- la priorité) mais > standard 10 -> le démon tire un peu le focus. Inerte tant que les plateaux se remplissent.
    id = "demon", type = "abyss", family = "abyssal", rank = 1, cost = 1, hp = 64, dmg = 9, cd = 56, aggro = 25, -- DEMON / Leech (bruiser-leurre)
    effects = { { trigger = "on_hit", op = "lifesteal", params = { frac = 0.4 } } },
    -- COMMANDANT (LE CALICE DE SANG) : au piédestal, l'appât nourrit la meute — vol de vie d'équipe. cf. commanders-plan §2.2.
    commandBonus = { trigger = "combat_start", op = "aura_stat", target = "team", params = { stat = "lifesteal", value = 0.05 } },
  },

  -- ── Unités à EFFETS (familles de statuts, cf. docs/research/effects-dot-families.md). Visuel GÉNÉRÉ
  -- procéduralement par `type` (src/gen/creaturegen.lua) ; aucun champ visuel ici. PLACEHOLDERS. ──
  spore_tick = { -- POISON : cadence rapide, petits stacks (empile vite)
    id = "spore_tick", bodyplan = "blob", rank = 1, type = "arcane", family = "spore", cost = 1, hp = 30, dmg = 3, cd = 30, aggro = 5,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 1, dur = 180 } } },
  },
  corruptor = { -- POISON + malus de valeur (anti-stat) + AMPLI MARQUE (vuln-on-hit : la plaie trop fétide)
    id = "corruptor", bodyplan = "cephalopod", rank = 3, type = "abyss", family = "kraken", cost = 3, hp = 46, dmg = 6, cd = 62,
    -- GREFFE 9c (Marque/A2) : grant_vuln pose vulnInc=0.15 (refresh max, NON cumulable), dur=120 FRAMES (~2 s).
    -- Lecture cappée VULN_INC_CAP=0.5 dans damage() -> 2 marques (corruptor+stormcaller) ne snowballent pas.
    effects = {
      { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, weaken = 0.06 } },
      { trigger = "on_hit", op = "grant_vuln", params = { value = 0.15, dur = 120 } },
    },
  },
  emberling = { -- BRÛLURE : burst qui décroît, lèche le bouclier
    id = "emberling", bodyplan = "blob", rank = 2, type = "abyss", family = "demon", cost = 2, hp = 40, dmg = 5, cd = 50,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 6, dur = 150 } } },
  },
  razorkin = { -- SAIGNEMENT : slow de cadence
    id = "razorkin", bodyplan = "humanoid", rank = 2, type = "flesh", family = "bete", cost = 2, hp = 52, dmg = 5, cd = 46,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 240, slowPct = 0.20 } } },
  },
  rot_hound = { -- POURRITURE : enfle, ampute les PV max
    id = "rot_hound", bodyplan = "quadruped", rank = 2, type = "bone", family = "larve", cost = 2, hp = 54, dmg = 5, cd = 56,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.15 } } },
  },
  stormcaller = { -- CHOC : charge un condensateur (décharge stacks × volt) + AMPLI MARQUE (là où il regarde, ça frappe)
    id = "stormcaller", bodyplan = "robe", rank = 2, type = "arcane", family = "oeil", cost = 2, hp = 38, dmg = 6, cd = 58, aggro = 5,
    -- GREFFE 9c (Marque/A2) : 2e accès vuln. value=0.12, dur=90 FRAMES (~1.5 s). max() non-cumulable, cappé 0.5.
    effects = {
      { trigger = "on_hit", op = "shock", params = { add = 1, cap = 6, dur = 150 } },
      { trigger = "on_hit", op = "grant_vuln", params = { value = 0.12, dur = 90 } },
    },
  },
  plague_doctor = { -- CONTRE-DoT : régénération + PURGE BORNÉE (incline le matchup poison, n'efface pas)
    id = "plague_doctor", bodyplan = "robe", rank = 3, type = "order", family = "essaim", cost = 3, hp = 80, dmg = 6, cd = 66, aggro = 40,
    -- GREFFE 9c′ : purge déplacée sur on_low_hp (<50% PV, edge-trigger 1×) et BORNÉE — retire au plus 4 stacks de
    -- POISON (la famille DoT dominante), JAMAIS un reset total. Soft-counter du méta poison, pas un hard-counter binaire.
    effects = {
      { trigger = "combat_start", op = "regen", params = { value = 3 } },
      { trigger = "on_low_hp", op = "purge", params = { threshold = 0.5, family = "poison", maxStacks = 4 } },
    },
  },

  -- ══ VAGUE 1 : T1 « enablers » supplémentaires (cf. effects-dot-families.md §H). Ops EXISTANTS, params
  -- variés -> PURE DATA, aucune nouvelle mécanique moteur. Visuel généré (CreatureGen). PLACEHOLDERS (P5). ══

  -- BRÛLURE (burst qui décroît, lèche le bouclier) : cadence / front-load / éphémère
  cinder_cur = { -- cadence rapide, petites brûlures qui se rallument souvent
    id = "cinder_cur", bodyplan = "quadruped", rank = 2, type = "abyss", family = "culte", cost = 2, hp = 34, dmg = 4, cd = 34,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 4, dur = 120, refresh = true } } },
  },
  pyre_tender = { -- gros coup lent -> grosse brûlure de départ (front-load)
    id = "pyre_tender", bodyplan = "deformed", rank = 2, type = "flesh", family = "echassier", cost = 2, hp = 50, dmg = 7, cd = 72,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 10, dur = 180 } } },
  },
  ash_moth = { -- coût bas, brûlure qui décroît vite (éphémère mais bon marché)
    id = "ash_moth", bodyplan = "eye", rank = 1, type = "flesh", family = "echassier", cost = 1, hp = 26, dmg = 3, cd = 40,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 7, dur = 120, decayPct = 0.45 } } },
  },

  -- SAIGNEMENT (bas DPS, slow de cadence) : intensité / contrôle pur / épines
  gash_fiend = { -- saignement un peu plus fort, slow standard
    id = "gash_fiend", bodyplan = "humanoid", rank = 2, type = "flesh", family = "echassier", cost = 2, hp = 50, dmg = 5, cd = 48,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 3, dur = 240, slowPct = 0.20 } } },
  },
  hookjaw = { -- bleed léger + AMPLI ÉCHO : multicast-aura sur le frappeur de la ligne avant (l'exemple-fondateur)
    id = "hookjaw", bodyplan = "quadruped", rank = 2, type = "flesh", family = "bete", cost = 2, hp = 58, dmg = 3, cd = 54,
    -- GREFFE 9c (Écho/A4) : +1 sous-coup au carry de la ligne avant (role:front). multicast NON scalé par niveau
    -- (entier, cap dur MULTICAST_MAX=3 ; ne couvre QUE la frappe, pas le DoT déjà posé). Aura build-résolue (K1).
    effects = {
      { trigger = "on_hit", op = "bleed", params = { dps = 1, dur = 300, slowPct = 0.30 } },
      { trigger = "combat_start", op = "aura_stat", target = "role:front", params = { stat = "multicast", value = 1 } },
    },
  },
  leech_thorn = { -- bleed bas + ÉPINES (punit qui le frappe) : DEUX effets via ops existants
    id = "leech_thorn", bodyplan = "arachnid", rank = 3, type = "bone", family = "wendigo", cost = 3, hp = 46, dmg = 4, cd = 50,
    effects = {
      { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 180, slowPct = 0.10 } },
      { trigger = "on_attacked", op = "thorns", params = { value = 3 } },
    },
  },

  -- POISON (N stacks, malus de valeur) : malus de base / longue durée
  bile_spitter = { -- stacks moyens + malus de valeur de base
    id = "bile_spitter", bodyplan = "serpent", rank = 3, type = "arcane", family = "plante", cost = 3, hp = 42, dmg = 5, cd = 56,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, weaken = 0.10 } } },
  },
  rot_grub = { -- stacks LONGUE durée (entretien facile du total) — POISON malgré le nom
    id = "rot_grub", bodyplan = "serpent", rank = 2, type = "abyss", family = "hydre", cost = 2, hp = 48, dmg = 4, cd = 58,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 300 } } },
  },

  -- POURRITURE (enfle, ampute les PV max) : cadence / long terme / amputation forte
  carrion_pecker = { -- rot rapide (cap bas) + SOIN-SUR-KILL : le charognard se repaît du cadavre qu'il a fait
    id = "carrion_pecker", bodyplan = "swarm", rank = 1, type = "flesh", family = "colosse", cost = 1, hp = 38, dmg = 4, cd = 38,
    -- GREFFE 9c′ (A10 sustain) : heal_on_kill +4 PV au tueur (broadcast on_kill, borné maxHp). Verbe non-multiplicatif.
    effects = {
      { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 180, capDps = 6, maxHpFrac = 0.10 } },
      { trigger = "on_kill", op = "heal_on_kill", params = { value = 4 } },
    },
  },
  maggot_king = { -- rot (cap HAUT) + AMPLI FORGE : empower-aura (le pantin-tyran ORDONNE aux voisins-frappeurs)
    id = "maggot_king", bodyplan = "swarm", rank = 3, type = "bone", family = "pendu", cost = 3, hp = 70, dmg = 5, cd = 64,
    -- GREFFE 9c (Forge/A3) : atkInc=0.20 aux VOISINS qui FRAPPENT (boost le dégât d'ATTAQUE, PAS le rot du thème).
    -- À placer au centre (4 voisins) entouré de carries d'attaque. Cumul cappé ATK_INC_CAP=1.5 à la lecture.
    effects = {
      { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 300, capDps = 12, maxHpFrac = 0.15 } },
      { trigger = "combat_start", op = "aura_stat", target = "neighbors", params = { stat = "atkInc", value = 0.20 } },
    },
    -- COMMANDANT (LA COURONNE D'ÉCHOS) : mono-cible FORT — l'avant-garde (role:front) re-frappe (+1 multicast,
    -- entier, cappé MULTICAST_MAX=3). Le pantin-tyran rejoue le coup de l'élu. cf. commanders-plan §2.2 (#5).
    commandBonus = { trigger = "combat_start", op = "aura_stat", target = "role:front", params = { stat = "multicast", value = 1 } },
  },
  necro_leech = { -- pourriture + amputation RENFORCÉE des PV max
    id = "necro_leech", bodyplan = "serpent", rank = 3, type = "abyss", family = "ombre", cost = 3, hp = 50, dmg = 5, cd = 56,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.35 } } },
  },

  -- ══ VAGUE 2 : AURAS d'adjacence (T1.5 « semeurs »). Build-résolues via le GRAPHE du sigil (buildComp +
  -- board:neighbors), comme shield_aura -> AUCUN op combat (ignorées gracieusement à combat_start). Elles
  -- ne posent PAS le DoT elles-mêmes : elles AMPLIFIENT le voisin qui le pose (la synergie positionnelle). ══
  soot_acolyte = { -- BRÛLURE : +50% dps (increased) aux brûlures des voisins (cappé ×3 à la lecture)
    id = "soot_acolyte", bodyplan = "robe", rank = 3, type = "arcane", family = "chimere", cost = 3, hp = 46, dmg = 6, cd = 54,
    effects = { { trigger = "combat_start", op = "aura_burn_dps", target = "neighbors", params = { inc = 0.5 } } },
  },
  clot_mender = { -- SAIGNEMENT : les voisins appliquent AUSSI un petit bleed
    id = "clot_mender", bodyplan = "robe", rank = 3, type = "bone", family = "wendigo", cost = 3, hp = 44, dmg = 4, cd = 56,
    effects = { { trigger = "combat_start", op = "aura_grant_bleed", target = "neighbors", params = { dps = 1, dur = 180, slowPct = 0.10 } } },
  },
  miasma_acolyte = { -- POISON : +50% dps (increased) aux stacks de poison des voisins (cappé ×3 ; hérité par le spread)
    id = "miasma_acolyte", bodyplan = "robe", rank = 3, type = "arcane", family = "cocon", cost = 3, hp = 36, dmg = 4, cd = 60,
    effects = { { trigger = "combat_start", op = "aura_poison_dps", target = "neighbors", params = { inc = 0.5 } } },
  },
  decay_tender = { -- POURRITURE : +growth aux pourritures des voisins (enflent plus vite)
    id = "decay_tender", bodyplan = "robe", rank = 3, type = "bone", family = "pendu", cost = 3, hp = 50, dmg = 4, cd = 60,
    effects = { { trigger = "combat_start", op = "aura_rot_growth", target = "neighbors", params = { bonus = 1 } } },
  },

  -- ══ VAGUE 3 : T2 « twists » (cf. effects-dot-families.md §H). Chacun = l'effet + UNE torsion. Ops
  -- bornés/gated (comportement de base inchangé -> golden stable). corruptor est DÉJÀ le T2 poison-weaken. ══

  -- BRÛLURE T2
  bellows_priest = { -- anti-décroissance (brûlure tenace) + AMPLI HÂTE : le soufflet attise (les voisins frappent + vite)
    id = "bellows_priest", bodyplan = "robe", rank = 3, type = "abyss", family = "culte", cost = 3, hp = 44, dmg = 5, cd = 58,
    -- GREFFE 9c (Hâte) : haste=0.12 aux voisins -> cadence d'attaque accélérée (atkTimer × (1-haste)). Cumulatif
    -- additif dans le baker K1, mais le timer reste positif (haste raisonnable) -> pas de boucle de swing.
    effects = {
      { trigger = "on_hit", op = "burn", params = { dps = 6, dur = 180, decayPct = 0.15 } },
      { trigger = "combat_start", op = "aura_stat", target = "neighbors", params = { stat = "haste", value = 0.12 } },
    },
    -- COMMANDANT (LE TAMBOUR DE GUERRE) : équipe-faible — toute la fosse frappe au même souffle (+8% cadence). cf. §2.2 (#1).
    commandBonus = { trigger = "combat_start", op = "aura_stat", target = "team", params = { stat = "haste", value = 0.08 } },
  },
  wildfire_hound = { -- à la mort d'un ennemi en feu, propage la brûlure à ses voisins (proximité champ)
    id = "wildfire_hound", bodyplan = "quadruped", rank = 4, type = "abyss", family = "demon", cost = 4, hp = 48, dmg = 5, cd = 54,
    effects = {
      { trigger = "on_hit", op = "burn", params = { dps = 5, dur = 150 } },
      { trigger = "on_death", op = "spread_burn_on_death", params = { frac = 0.7, minDps = 3, dur = 120 } },
    },
  },
  kiln_warden = { -- convertit le surplus : une brûlure plus faible PROLONGE au lieu d'être perdue
    id = "kiln_warden", bodyplan = "deformed", rank = 4, type = "flesh", family = "colosse", cost = 4, hp = 52, dmg = 5, cd = 60,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 5, dur = 180, mode = "extend_if_weaker" } } },
  },

  -- SAIGNEMENT T2
  bloodletter = { -- le saignement ÉCLATE (×2) quand la cible attaque (payoff conditionnel)
    id = "bloodletter", bodyplan = "humanoid", rank = 4, type = "flesh", family = "echassier", cost = 4, hp = 48, dmg = 5, cd = 48,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 240, slowPct = 0.20, aggravateMult = 2.0 } } },
  },
  tendon_render = { -- le slow SCALE avec les PV manquants (plus elle saigne, plus elle ralentit)
    id = "tendon_render", bodyplan = "arachnid", rank = 4, type = "bone", family = "wendigo", cost = 4, hp = 50, dmg = 4, cd = 50,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 240, slowPct = 0.15, slowScalesMissingHp = true } } },
  },
  vein_splitter = { -- saignement profond et rapide (« deux entailles » ; 2-instances approximé par 1 fort)
    id = "vein_splitter", bodyplan = "humanoid", rank = 3, type = "flesh", family = "bandit", cost = 3, hp = 46, dmg = 4, cd = 44,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 4, dur = 180, slowPct = 0.15 } } },
  },

  -- POISON T2 (corruptor = le 3e, déjà présent)
  plague_bearer = { -- CONTAGION : le poison se propage en stack plus faible aux voisins de la cible
    id = "plague_bearer", bodyplan = "cephalopod", rank = 4, type = "arcane", family = "cocon", cost = 4, hp = 40, dmg = 5, cd = 58,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, spread = { dps = 1, dur = 120 } } } },
  },
  acid_maw = { -- le venin RONGE le bouclier (−30 % par pose : dissout l'armure)
    id = "acid_maw", bodyplan = "cephalopod", rank = 3, type = "abyss", family = "cephalo", cost = 3, hp = 46, dmg = 5, cd = 56,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, shieldEat = 0.30 } } },
  },

  -- POURRITURE T2
  patient_worm = { -- la pourriture enfle même SANS frapper (ramp passif tant qu'active)
    id = "patient_worm", bodyplan = "serpent", rank = 4, type = "bone", family = "pendu", cost = 4, hp = 58, dmg = 4, cd = 52,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, passiveRamp = 1, dur = 240, capDps = 10, maxHpFrac = 0.10 } } },
  },
  hollow_gut = { -- l'amputation des PV max NOURRIT le porteur (vol de plafond de vie)
    id = "hollow_gut", bodyplan = "blob", rank = 4, type = "abyss", family = "gelatine", cost = 4, hp = 50, dmg = 5, cd = 58,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.20, amputateHealsMe = 0.5 } } },
  },
  blight_spreader = { -- à la mort d'une cible pourrie, la pourriture prend ses voisins (proximité champ)
    id = "blight_spreader", bodyplan = "swarm", rank = 4, type = "bone", family = "pendu", cost = 4, hp = 52, dmg = 5, cd = 56,
    effects = {
      { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.15 } },
      { trigger = "on_death", op = "spread_rot", params = { base = 2, dur = 240, capDps = 10, maxHpFrac = 0.10 } },
    },
  },

  -- ══ VAGUE 4 : T3 « transforms / clutch » (cf. effects-dot-families.md §H). 2/famille = 1 FINISHER
  -- (grant_team : change l'archétype de l'équipe) + 1 PIVOT CROISÉ vers une autre famille (enabler->payoff).
  -- Le T3 ne scale QUE ses stats, jamais son seuil (anti double-snowball). PREMIUM (coût 4-5). ══

  -- BRÛLURE T3
  ash_maw = { -- TRANSFORM : tant qu'il vit, les feux de l'ÉQUIPE ne décroissent plus (les braises éternelles)
    id = "ash_maw", bodyplan = "chimera:cephalopod:quadruped", rank = 5, type = "abyss", family = "culte", cost = 5, hp = 70, dmg = 6, cd = 60,
    effects = {
      { trigger = "on_hit", op = "burn", params = { dps = 6, dur = 180 } },
      { trigger = "combat_start", op = "grant_team", params = { burnNoDecay = true } },
    },
  },
  plague_pyre = { -- CROISÉ feu->poison : quand sa brûlure saute à la mort, elle SÈME aussi du venin
    id = "plague_pyre", bodyplan = "chimera:humanoid:tentacles", rank = 5, type = "abyss", family = "culte", cost = 5, hp = 56, dmg = 6, cd = 56,
    effects = {
      { trigger = "on_hit", op = "burn", params = { dps = 5, dur = 150 } },
      { trigger = "on_death", op = "spread_burn_on_death", params = { frac = 0.6, minDps = 3, dur = 120, alsoPoison = { dps = 2, dur = 120 } } },
    },
  },

  -- SAIGNEMENT T3
  slow_bleed = { -- TRANSFORM : au début du combat, RALENTIT toute l'équipe ennemie (la mort par mille coupures)
    id = "slow_bleed", bodyplan = "chimera:humanoid:quadruped", rank = 5, type = "bone", family = "wendigo", cost = 5, hp = 64, dmg = 5, cd = 54,
    effects = {
      { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 240, slowPct = 0.15 } },
      { trigger = "combat_start", op = "grant_team", params = { slowEnemies = 0.12 } },
    },
  },
  marrow_drinker = { -- CROISÉ saignement->pourriture : sur une cible DÉJÀ saignante, convertit le bleed en rot
    id = "marrow_drinker", bodyplan = "cephalopod", rank = 5, type = "abyss", family = "ombre", cost = 5, hp = 54, dmg = 6, cd = 52,
    effects = { { trigger = "on_hit", op = "convert_to_rot", params = { base = 3, growth = 2, dur = 240, capDps = 12, maxHpFrac = 0.15 } } },
  },

  -- POISON T3
  festering = { -- TRANSFORM : le poison de l'ÉQUIPE ignore son cap de stacks ET dure plus longtemps
    id = "festering", bodyplan = "chimera:cephalopod:tentacles", rank = 5, type = "arcane", family = "cauchemar", cost = 5, hp = 50, dmg = 6, cd = 60,
    effects = {
      { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180 } },
      { trigger = "combat_start", op = "grant_team", params = { poisonNoCap = true, poisonDurBonus = 60 } },
    },
  },
  venom_censer = { -- CROISÉ poison->feu : à N stacks de poison, la cible DÉTONE en flammes (accumule puis détonne)
    id = "venom_censer", bodyplan = "chimera:humanoid:tentacles", rank = 5, type = "arcane", family = "cocon", cost = 5, hp = 48, dmg = 6, cd = 58,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, igniteAt = 5, igniteBurst = { dps = 10, dur = 150 } } } },
  },

  -- POURRITURE T3
  pit_maw = { -- TRANSFORM (signature thème) : au début du combat, la pourriture rampe sur TOUTE l'équipe ennemie
    id = "pit_maw", bodyplan = "chimera:cephalopod:quadruped", rank = 5, type = "bone", family = "larve", cost = 5, hp = 76, dmg = 5, cd = 64,
    effects = {
      { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.15 } },
      { trigger = "combat_start", op = "grant_team", params = { rotEnemies = { base = 1, dur = 300, capDps = 8, maxHpFrac = 0.10 } } },
    },
  },
  wither_bloom = { -- CROISÉ rot->slow+malus : pourriture qui RALENTIT et AFFAIBLIT aussi (l'usure totale, anti-stat)
    id = "wither_bloom", bodyplan = "chimera:cephalopod:tentacles", rank = 5, type = "abyss", family = "ombre", cost = 5, hp = 58, dmg = 5, cd = 60,
    effects = {
      { trigger = "on_hit", op = "rot", params = { base = 2, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.15 } },
      { trigger = "on_hit", op = "bleed", params = { dps = 0, dur = 240, slowPct = 0.15 } }, -- pur slow (0 dps)
      { trigger = "on_hit", op = "poison", params = { dps = 0, dur = 240, weaken = 0.10 } }, -- pur malus (0 dps)
    },
  },

  -- ══ ARCHÉTYPE TANK (P6 : aggro activée). Mur de PV à faible dégât qui TIRE LE FOCUS (aggro haute) et,
  -- via taunt, FORCE le ciblage en façade -> protège les carries derrière. Épines = punit le focus. ══
  gravewarden = { -- TANK / TAUNT
    id = "gravewarden", bodyplan = "humanoid", rank = 4, type = "bone", family = "mortvivant", cost = 4, hp = 100, dmg = 3, cd = 84, aggro = 40, taunt = true,
    effects = { { trigger = "on_attacked", op = "thorns", params = { value = 4 } } },
  },

  -- ══ LADDER CHOC (5/3/2 — cf. CLAUDE.md §3). Le choc est un CONDENSATEUR : chaque pose ajoute des stacks ;
  -- au prochain COUP sur la cible, la charge se DÉCHARGE d'un coup (stacks × volt, instance cause="shock",
  -- ignore le bouclier) puis se consume. On joue cadence (add) vs volt (dégâts/stack) vs cap. DATA-ONLY, golden-safe. ══
  live_wire = { -- T1 : cadence rapide, petite charge (empile vite) — chaff semeur de choc
    id = "live_wire", bodyplan = "swarm", rank = 1, type = "arcane", family = "oeil", cost = 1, hp = 28, dmg = 3, cd = 30, aggro = 5,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 1, cap = 5, dur = 120 } } },
  },
  thunderhead = { -- T1 : gros coup lent, charge DENSE (volt fort, peu de stacks) — carry burst
    id = "thunderhead", bodyplan = "eye", rank = 2, type = "arcane", family = "oeil", cost = 2, hp = 40, dmg = 8, cd = 76, aggro = 5,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 1, volt = 6, cap = 4, dur = 180 } } },
  },
  static_swarm = { -- T1 : cap élevé, charge régulière, longue durée — choqueur patient (combats longs)
    id = "static_swarm", bodyplan = "swarm", rank = 2, type = "abyss", family = "abyssal", cost = 2, hp = 44, dmg = 4, cd = 50, aggro = 5,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 1, cap = 8, dur = 240 } } },
  },
  galvanizer = { -- T2 : charge PUIS déclenche sa propre décharge (auto-synergie) — bruiser autonome
    id = "galvanizer", bodyplan = "arachnid", rank = 4, type = "flesh", family = "rongeur", cost = 4, hp = 58, dmg = 11, cd = 64, aggro = 15,
    effects = {
      { trigger = "on_attack", op = "bonus_first", params = { value = 6 } },
      { trigger = "on_hit", op = "shock", params = { add = 2, cap = 6, dur = 180 } },
    },
    -- COMMANDANT (LE ROI DES RATS) : conditionnel tier-1 — la piétaille (rank==1) enfle (+50% PV & dmg, baké, cappé
    -- STAT_INC_CAP). Six gueules, une couronne : la marée du Puits. cf. commanders-plan §2.2 (#4).
    commandBonus = { trigger = "combat_start", op = "aura_stat", target = "tier:1", params = { stat = "statInc", value = 0.50 } },
  },
  stormlord = { -- T2 : add 2 + volt fort + cap max — marque une proie, les alliés font sauter la charge
    id = "stormlord", bodyplan = "eye", rank = 3, type = "arcane", family = "cristal", cost = 3, hp = 50, dmg = 6, cd = 54, aggro = 5,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 2, volt = 4, cap = 8, dur = 240 } } },
  },
  -- MODIFICATEURS RARES du choc (cf. dischargeShock) : la décharge n'est plus un simple « tout d'un coup ».
  dynamo_priest = { -- TRANSFER : à la décharge, la moitié des stacks SAUTE sur un voisin (la charge se propage)
    id = "dynamo_priest", bodyplan = "robe", rank = 4, type = "arcane", family = "oeil", cost = 4, hp = 48, dmg = 5, cd = 58, aggro = 5,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 1, cap = 6, dur = 180, transfer = 0.5 } } },
  },
  arc_warden = { -- CHAIN : la décharge ARQUE vers 2 ennemis proches (60% des dégâts) — nettoyage de ligne
    id = "arc_warden", bodyplan = "arachnid", rank = 4, type = "abyss", family = "abyssal", cost = 4, hp = 52, dmg = 6, cd = 60, aggro = 5,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 1, volt = 4, cap = 6, dur = 180, chain = 2 } } },
  },
  storm_anchor = { -- PERSIST : la charge ne se consume pas entièrement (garde la moitié) — pression continue
    id = "storm_anchor", bodyplan = "eye", rank = 3, type = "arcane", family = "cristal", cost = 3, hp = 56, dmg = 5, cd = 62, aggro = 15,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 2, cap = 8, dur = 240, persist = 0.5 } } },
  },

  -- ══ BOUCLIER (étoffe l'axe défensif : aujourd'hui seul `templar` en porte). `shield_aura` est RÉSOLU AU
  -- BUILD (build.lua) sur les voisins du sigil -> stat `shield` cuite, aucun op combat. Plus de porteurs à
  -- coûts/auras variés = du bouclier visible quasi à chaque partie. DATA-ONLY, golden-safe. ══
  shieldbearer = { -- tank cheap, petite aura : le porte-bouclier de masse (sort souvent en boutique)
    id = "shieldbearer", bodyplan = "humanoid", rank = 2, type = "order", family = "seraphin", cost = 2, hp = 72, dmg = 2, cd = 80, aggro = 40,
    effects = { { trigger = "combat_start", op = "shield_aura", target = "neighbors", params = { value = 6 } } },
  },
  aegis_warden = { -- tank-épines + TAUNT : blinde les voisins ET punit qui le frappe (mur de front complet)
    id = "aegis_warden", bodyplan = "humanoid", rank = 4, type = "bone", family = "mortvivant", cost = 4, hp = 96, dmg = 3, cd = 84, aggro = 40, taunt = true,
    effects = {
      { trigger = "combat_start", op = "shield_aura", target = "neighbors", params = { value = 10 } },
      { trigger = "on_attacked", op = "thorns", params = { value = 4 } },
    },
  },
  oath_keeper = { -- premium offensif-défensif : grosse aura + dégâts corrects (pilier d'équipe)
    id = "oath_keeper", bodyplan = "humanoid", rank = 4, type = "order", family = "templier", cost = 4, hp = 84, dmg = 8, cd = 70, aggro = 15,
    effects = { { trigger = "combat_start", op = "shield_aura", target = "neighbors", params = { value = 18 } } },
  },
  bulwark_acolyte = { -- support fragile : bouclier modeste mais sur TOUS les voisins (max de couverture)
    id = "bulwark_acolyte", bodyplan = "robe", rank = 3, type = "arcane", family = "golem", cost = 3, hp = 40, dmg = 5, cd = 60, aggro = 5,
    effects = { { trigger = "combat_start", op = "shield_aura", target = "neighbors", params = { value = 8 } } },
  },

  -- ══ BOUCLIERS PÉRIODIQUES (framework payoff §3) : le caster RE-blinde ses voisins toutes les N s (vs le
  -- shield_aura one-shot). Les RENFORTS (aura_shield adjacente) = 5 axes lisibles : valeur / cadence /
  -- réflexion / largeur / surcharge. Counter livré dans le même lot (strip_shield). DATA-ONLY. ══
  ward_weaver = { -- BASE : caster périodique (re-bouclier 20 toutes les 4 s aux voisins)
    id = "ward_weaver", bodyplan = "robe", rank = 4, type = "order", family = "seraphin", cost = 4, hp = 80, dmg = 4, cd = 64, aggro = 40,
    effects = { { trigger = "combat_start", op = "shield_caster", target = "neighbors", params = { value = 20, cd = 240 } } },
  },
  barrier_savant = { -- RENFORT : +50% valeur (increased) ET −25% cooldown au caster voisin
    id = "barrier_savant", bodyplan = "robe", rank = 4, type = "order", family = "templier", cost = 4, hp = 46, dmg = 4, cd = 60, aggro = 15,
    effects = { { trigger = "combat_start", op = "aura_shield", target = "neighbors", params = { valueInc = 0.5, cdr = 0.25 } } },
  },
  mirror_ward = { -- RENFORT : RÉFLEXION (40% de l'absorbé mord l'attaquant) + LARGEUR (rayon 2)
    id = "mirror_ward", bodyplan = "robe", rank = 4, type = "order", family = "seraphin", cost = 4, hp = 50, dmg = 5, cd = 58, aggro = 15,
    effects = { { trigger = "combat_start", op = "aura_shield", target = "neighbors", params = { reflect = 0.4, radius = true } } },
  },
  surge_warden = { -- RENFORT : SURCHARGE (les boucliers non-consommés s'accumulent, cap 2×) + valeur
    id = "surge_warden", bodyplan = "robe", rank = 4, type = "order", family = "griffon", cost = 4, hp = 48, dmg = 4, cd = 60, aggro = 15,
    effects = { { trigger = "combat_start", op = "aura_shield", target = "neighbors", params = { overcharge = true, valueInc = 0.5 } } },
  },
  siege_breaker = { -- COUNTER strip-shield + CLEAVE (SEUL hôte cleave v1) : déchire la ligne en travers (profondeur 1)
    id = "siege_breaker", bodyplan = "deformed", rank = 3, type = "flesh", family = "canide", cost = 3, hp = 60, dmg = 8, cd = 52, aggro = 15,
    -- GREFFE 9c′ (A7 cleave de ligne) : la frappe éclabousse 50% sur les VOISINS-champ de la cible (profondeur 1,
    -- AUCUN on_hit secondaire, respecte les boucliers). SEUL porteur de cleave en v1 (arc_warden/kiln_warden différés).
    effects = {
      { trigger = "on_hit", op = "strip_shield", params = { frac = 0.5 } },
      { trigger = "on_hit", op = "cleave", params = { frac = 0.5 } },
    },
    -- COMMANDANT (LA BANNIÈRE DU BRIS-SIÈGE) : anti-méta — au combat_start, les boucliers ennemis ÷2 (grant_team
    -- {stripEnemyShield}, lu dans arena:spawn, C1). La garde dorée s'écaille avant le premier choc. cf. §2.2 (#6).
    commandBonus = { trigger = "combat_start", op = "grant_team", params = { stripEnemyShield = 0.5 } },
  },

  -- ── ROSTER v7 vague 1 : peuple les familles visuelles restées « visuel-only » (champ `family` explicite,
  --    forwardé à creaturegen.cached). Afflictions selon la tendance-pôle. Stats = PLACEHOLDERS (à tuner via sim). ──
  chitin_drone = { -- INSECTE / venin de ruche
    id = "chitin_drone", type = "order", family = "insecte", rank = 2, cost = 2, hp = 38, dmg = 4, cd = 42,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 160 } } },
  },
  bore_worm = { -- ANNÉLIDE / foreur qui digère
    id = "bore_worm", type = "bone", family = "annelide", rank = 2, cost = 2, hp = 58, dmg = 5, cd = 58,
    effects = { { trigger = "on_hit", op = "rot", params = { base = 1, growth = 1, dur = 210, capDps = 8, maxHpFrac = 0.12 } } },
  },
  wailing_shade = { -- SPECTRE / lacération froide
    id = "wailing_shade", type = "bone", family = "spectre", rank = 2, cost = 2, hp = 40, dmg = 6, cd = 52,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 2, dur = 200, slowPct = 0.15 } } },
  },
  pyre_herald = { -- CULTE / bûcher noir
    id = "pyre_herald", type = "abyss", family = "culte", rank = 2, cost = 2, hp = 54, dmg = 7, cd = 64,
    effects = { { trigger = "on_hit", op = "burn", params = { dps = 6, dur = 170 } } },
  },
  byakhee = { -- AILÉ / serres en piqué
    id = "byakhee", type = "abyss", family = "aile", rank = 2, cost = 2, hp = 46, dmg = 8, cd = 50,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 3, dur = 180, slowPct = 0.10 } } },
  },
  zeal_inquisitor = { -- INQUISITEUR / feu sacré + AMPLI FORGE (2e accès empower, early rk-2 : le prêtre exhorte)
    id = "zeal_inquisitor", type = "order", family = "inquisiteur", rank = 2, cost = 2, hp = 64, dmg = 8, cd = 68, aggro = 15,
    -- GREFFE 9c (Forge/A3) : 2e point d'accès empower (rang distinct de maggot_king rk 3). atkInc=0.12 aux
    -- voisins-frappeurs. Cumul cappé ATK_INC_CAP=1.5 à la lecture (deux empowers ne snowballent pas).
    effects = {
      { trigger = "on_hit", op = "burn", params = { dps = 5, dur = 180 } },
      { trigger = "combat_start", op = "aura_stat", target = "neighbors", params = { stat = "atkInc", value = 0.12 } },
    },
  },
  coil_viper = { -- REPTILE / venin de cobra + 2e PLAIE SI ABSENTE (le cobra ouvre une 2e plaie là où la chair est saine)
    id = "coil_viper", type = "flesh", family = "reptile", rank = 2, cost = 2, hp = 46, dmg = 7, cd = 48,
    -- GREFFE 9c′ : grant_affliction_if_absent (ÉVALUÉ AVANT le poison principal) pose un poison faible (1 dps / 120
    -- frames) SI la cible n'en a AUCUN -> sur une cible saine = 2 plaies (faible + principale) ; sur une cible déjà
    -- empoisonnée = inerte (pas de double-stack ; verbe borné, pur état). « Le cobra frappe deux fois la chair saine. »
    effects = {
      { trigger = "on_hit", op = "grant_affliction_if_absent", params = { family = "poison", dps = 1, dur = 120 } },
      { trigger = "on_hit", op = "poison", params = { dps = 3, dur = 160 } },
    },
  },
  web_recluse = { -- ARACHNIDE / morsure recluse
    id = "web_recluse", type = "flesh", family = "arachnide", rank = 2, cost = 2, hp = 40, dmg = 4, cd = 44,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 200 } } },
  },
  siphon_jelly = { -- MÉDUSE / urticant électrique
    id = "siphon_jelly", type = "abyss", family = "meduse", rank = 2, cost = 2, hp = 42, dmg = 5, cd = 50,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 1, cap = 5, dur = 150 } } },
  },
  skull_colossus = { -- CRÂNE COLOSSAL / vestige titanesque + SOIN-SUR-KILL (payoff de combat non-multiplicatif, A11)
    id = "skull_colossus", type = "bone", family = "crane", rank = 5, cost = 5, hp = 92, dmg = 11, cd = 84, aggro = 40,
    -- GREFFE 9c′ (A11 constructs) : heal_on_kill +8 PV au tueur (chaque âme broyée ranime sa braise). Borné maxHp.
    effects = {
      { trigger = "on_hit", op = "burn", params = { dps = 4, dur = 200 } },
      { trigger = "on_kill", op = "heal_on_kill", params = { value = 8 } },
    },
  },
  rust_sentinel = { -- AUTOMATE / noyau électrique (bruiser-tank)
    id = "rust_sentinel", type = "order", family = "automate", rank = 4, cost = 4, hp = 78, dmg = 9, cd = 72, aggro = 20,
    effects = { { trigger = "on_hit", op = "shock", params = { add = 1, cap = 6, dur = 150 } } },
  },
  runestone_golem = { -- GOLEM / pierre runique qui protège (tank-support)
    id = "runestone_golem", type = "arcane", family = "golem", rank = 4, cost = 4, hp = 88, dmg = 10, cd = 80, aggro = 40,
    effects = { { trigger = "combat_start", op = "shield_aura", target = "neighbors", params = { value = 12 } } },
  },
  ink_horror = { -- CÉPHALOPODE / encre toxique abyssale
    id = "ink_horror", type = "abyss", family = "cephalo", rank = 2, cost = 2, hp = 44, dmg = 6, cd = 54,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 3, dur = 170 } } },
  },
  deep_kraken = { -- KRAKEN / léviathan, étreinte venimeuse (légendaire)
    id = "deep_kraken", type = "abyss", family = "kraken", rank = 5, cost = 5, hp = 84, dmg = 12, cd = 78,
    effects = { { trigger = "on_hit", op = "poison", params = { dps = 4, dur = 200 } } },
    -- COMMANDANT (L'AÏEUL) : conditionnel level-1 — ce qui n'a jamais grandi sous sa coupe (level==1, donc tes
    -- plus GROSSES bêtes non-fusionnées) enfle d'un coup (+40% PV & dmg, baké, cappé STAT_INC_CAP). cf. §2.2 (#3).
    commandBonus = { trigger = "combat_start", op = "aura_stat", target = "level:1", params = { stat = "statInc", value = 0.40 } },
  },

  -- ── PLANCHER RANG-1 (PRD progression-economy §4) : stat-sticks « grok-ables ». Zéro op neuf : 3 brutes
  --    sans effet (comble les pôles bone/order/abyss) + 1 micro-saignement (op `bleed` existant). Stats
  --    réglées pour la LOI DES DOUBLONS §4.3 (×3 niveau-3 ≈ une carry mid-tier en brut). PLACEHOLDERS (sim). ──
  husk = { id = "husk", type = "bone", family = "mortvivant", rank = 1, cost = 1, hp = 58, dmg = 4, cd = 72, aggro = 20, effects = {} },
  gnaw_rat = { id = "gnaw_rat", type = "flesh", family = "rongeur", rank = 1, cost = 1, hp = 30, dmg = 5, cd = 34,
    effects = { { trigger = "on_hit", op = "bleed", params = { dps = 1, dur = 150, slowPct = 0.08 } } } },
  footman = { id = "footman", type = "order", family = "automate", rank = 1, cost = 1, hp = 46, dmg = 7, cd = 52, aggro = 10, effects = {} },
  mire_thing = { id = "mire_thing", type = "abyss", family = "gelatine", rank = 1, cost = 1, hp = 50, dmg = 5, cd = 54, effects = {} },
}

-- ══ FAMILLE DoT DÉCLARATIVE (M2/2.4 — « type » des synergies P1 + segmentation Grimoire). Porteur explicite,
-- 1 entrée par unité QUI POSE/AMPLIFIE un DoT (5 familles : brûlure/saignement/poison/pourriture/choc). Les
-- 20 unités sans DoT (tanks/boucliers/épines/brutes) sont volontairement ABSENTES (`dot_family` = nil : elles
-- ne comptent dans aucun type). DATA PURE, NON lue par la SIM -> golden-neutre. La famille = la famille
-- DOMMAGEABLE PRIMAIRE : les ops 0-dps (slow/weaken) et les `grant_team` ne la changent pas (ex. wither_bloom
-- = rot, ses bleed/poison à 0 dps sont utilitaires). Couverture + cohérence (op RÉEL vs famille déclarée)
-- garanties par tests/dot_family.lua (lint dans check.sh). ⚠ pièges : `rot_grub` est POISON (op), pas rot
-- (nom) ; les 4 auras (soot/clot/miasma/decay) portent leur famille mais ne sont PAS des poseurs actifs
-- (exclues du plancher rang). Audit complet : docs/roadmap-lab/audit/identity-audit.md.
U.dotFamily = {
  -- BRÛLURE (13)
  emberling = "burn", cinder_cur = "burn", pyre_tender = "burn", ash_moth = "burn", bellows_priest = "burn",
  wildfire_hound = "burn", kiln_warden = "burn", ash_maw = "burn", plague_pyre = "burn", pyre_herald = "burn",
  zeal_inquisitor = "burn", skull_colossus = "burn", soot_acolyte = "burn",
  -- SAIGNEMENT (12)
  razorkin = "bleed", gash_fiend = "bleed", hookjaw = "bleed", leech_thorn = "bleed", bloodletter = "bleed",
  tendon_render = "bleed", vein_splitter = "bleed", slow_bleed = "bleed", wailing_shade = "bleed",
  byakhee = "bleed", gnaw_rat = "bleed", clot_mender = "bleed",
  -- POISON (15)
  witch = "poison", spore_tick = "poison", corruptor = "poison", bile_spitter = "poison", rot_grub = "poison",
  plague_bearer = "poison", acid_maw = "poison", festering = "poison", venom_censer = "poison",
  chitin_drone = "poison", coil_viper = "poison", web_recluse = "poison", ink_horror = "poison",
  deep_kraken = "poison", miasma_acolyte = "poison",
  -- POURRITURE (12)
  rot_hound = "rot", carrion_pecker = "rot", maggot_king = "rot", necro_leech = "rot", patient_worm = "rot",
  hollow_gut = "rot", blight_spreader = "rot", marrow_drinker = "rot", pit_maw = "rot", wither_bloom = "rot",
  bore_worm = "rot", decay_tender = "rot",
  -- CHOC (11)
  stormcaller = "shock", live_wire = "shock", thunderhead = "shock", static_swarm = "shock",
  galvanizer = "shock", stormlord = "shock", dynamo_priest = "shock", arc_warden = "shock",
  storm_anchor = "shock", siphon_jelly = "shock", rust_sentinel = "shock",
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
  "patient_worm", "hollow_gut", "blight_spreader",
  -- vague 4 (T3 transforms/croisés) : burn / bleed / poison / rot
  "ash_maw", "plague_pyre",
  "slow_bleed", "marrow_drinker",
  "festering", "venom_censer",
  "pit_maw", "wither_bloom",
  -- archétype tank (P6)
  "gravewarden",
  -- ladder choc (5) + bouclier (4)
  "live_wire", "thunderhead", "static_swarm", "galvanizer", "stormlord",
  "dynamo_priest", "arc_warden", "storm_anchor",
  "shieldbearer", "aegis_warden", "oath_keeper", "bulwark_acolyte",
  -- boucliers périodiques (caster + renforts + counter)
  "ward_weaver", "barrier_savant", "mirror_ward", "surge_warden", "siege_breaker",
  -- vague v7 : familles visuelles peuplées
  "chitin_drone", "bore_worm", "wailing_shade", "pyre_herald", "byakhee", "zeal_inquisitor",
  "coil_viper", "web_recluse", "siphon_jelly", "skull_colossus", "rust_sentinel",
  "runestone_golem", "ink_horror", "deep_kraken",
  -- plancher rang-1 (PRD progression-economy)
  "husk", "gnaw_rat", "footman", "mire_thing" }

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
  "patient_worm", "hollow_gut", "blight_spreader",
  "ash_maw", "plague_pyre",
  "slow_bleed", "marrow_drinker",
  "festering", "venom_censer",
  "pit_maw", "wither_bloom",
  "gravewarden",
  "live_wire", "thunderhead", "static_swarm", "galvanizer", "stormlord",
  "dynamo_priest", "arc_warden", "storm_anchor",
  "shieldbearer", "aegis_warden", "oath_keeper", "bulwark_acolyte",
  "ward_weaver", "barrier_savant", "mirror_ward", "surge_warden", "siege_breaker",
  "chitin_drone", "bore_worm", "wailing_shade", "pyre_herald", "byakhee", "zeal_inquisitor",
  "coil_viper", "web_recluse", "siphon_jelly", "skull_colossus", "rust_sentinel",
  "runestone_golem", "ink_horror", "deep_kraken",
  -- plancher rang-1 (PRD progression-economy)
  "husk", "gnaw_rat", "footman", "mire_thing" }

-- Visuel : les 6 vanille ont un rig DESSINÉ main (src/data/creatures.lua) ; toutes les autres unités
-- sont GÉNÉRÉES procéduralement (src/gen/creaturegen.lua, déterministe par id), résolu côté rendu
-- (build.lua + arena_draw.lua). units.lua ne porte donc plus aucun champ visuel : pur mécanique.

return U
