-- src/data/compositions.lua
-- CATALOGUE de COMPOSITIONS (le « dictionnaire » du banc d'essai). DATA pure : aucune dépendance, aucune
-- chaîne d'affichage (seulement des `noteKey` i18n). Une composition = une équipe FIGÉE, posée par SLOT
-- sur un SIGIL nommé (l'adjacence — donc les auras — dépend du couple slot+sigil ; cf. src/board/shapes).
--
-- SCHÉMA d'une compo :
--   { id, archetype, variant, sigil, boardLevel, units = { {id, slot, level?}... }, relics?, noteKey }
--     · slot      : 1..9 (index dans shape.cells). DOIT être <= boardLevel (le plateau ne débloque que
--                   les slots 1..boardLevel, cf. Board:unlock -> index-ordonné).
--     · boardLevel: nb de slots engagés (3..9) = « niveau de board ». Fixé au PLUS GRAND slot utilisé
--                   (toujours >= #units). L'axe board-level (early/mid) s'enrichira en P5.
--     · level     : niveau de l'unité (1..3, duplicatas). Défaut 1.
--     · variant   : perfect | missing_minor (1 pièce redondante -> filler, « pas grave ») |
--                   missing_clutch (LA pièce-clé retirée -> sous-performe) | wall|baseline|amp (mono).
--
-- VARIANTS (axe de fragilité) : `perfect` vs `missing_clutch` ne diffèrent QUE de la pièce CLUTCH (même
-- disposition -> A/B propre : l'écart de win% = la valeur de cette pièce). `missing_minor` ne retire qu'une
-- redondance. C'est le cœur de « le win% seul ne veut rien dire » : une compo parfaite DOIT battre sa
-- version amputée — ce n'est pas un déséquilibre, c'est la récompense d'une gestion parfaite du board.

local Compositions = {}

Compositions.list = {
  -- ── POISON (diamant = go-wide/essaim ; miasma_acolyte@5 buffe 2,3,7,8 ; contagion + détonation) ──
  -- CLUTCH = festering (transform : le poison de l'ÉQUIPE ignore son plafond de stacks -> snowball).
  {
    id = "poison_diamant_perfect", archetype = "poison", variant = "perfect", sigil = "diamant", boardLevel = 9,
    units = {
      { id = "miasma_acolyte", slot = 5 }, -- AURA : +dps aux poisons des voisins (2,3,7,8)
      { id = "spore_tick", slot = 2 }, { id = "bile_spitter", slot = 3 }, -- empileurs rapides + malus
      { id = "plague_bearer", slot = 7 }, { id = "corruptor", slot = 8 }, -- contagion + weaken
      { id = "festering", slot = 1 },     -- CLUTCH : cap-break d'équipe
      { id = "venom_censer", slot = 9 },  -- payoff : détone en flammes au seuil
    },
    noteKey = "comp.poison_diamant_perfect.note",
  },
  {
    id = "poison_diamant_missing_minor", archetype = "poison", variant = "missing_minor", sigil = "diamant", boardLevel = 9,
    units = { -- corruptor (4e source, redondante) -> skeleton : la pression baisse à peine
      { id = "miasma_acolyte", slot = 5 },
      { id = "spore_tick", slot = 2 }, { id = "bile_spitter", slot = 3 },
      { id = "plague_bearer", slot = 7 }, { id = "skeleton", slot = 8 },
      { id = "festering", slot = 1 }, { id = "venom_censer", slot = 9 },
    },
    noteKey = "comp.poison_diamant_missing_minor.note",
  },
  {
    id = "poison_diamant_missing_clutch", archetype = "poison", variant = "missing_clutch", sigil = "diamant", boardLevel = 9,
    units = { -- festering (CLUTCH) -> skeleton : le poison plafonne, plus de snowball -> sous-performe
      { id = "miasma_acolyte", slot = 5 },
      { id = "spore_tick", slot = 2 }, { id = "bile_spitter", slot = 3 },
      { id = "plague_bearer", slot = 7 }, { id = "corruptor", slot = 8 },
      { id = "skeleton", slot = 1 }, { id = "venom_censer", slot = 9 },
    },
    noteKey = "comp.poison_diamant_missing_clutch.note",
  },

  -- ── BURN (ligne = conduit ; soot_acolyte@5 buffe 4,6 ; la propagation-à-la-mort court le long) ──
  -- CLUTCH = ash_maw (transform : les feux de l'ÉQUIPE ne décroissent plus -> dps soutenu).
  {
    id = "burn_ligne_perfect", archetype = "burn", variant = "perfect", sigil = "ligne", boardLevel = 7,
    units = {
      { id = "soot_acolyte", slot = 5 },   -- AURA : +dps aux brûlures des voisins (4,6)
      { id = "pyre_tender", slot = 4 }, { id = "emberling", slot = 6 }, -- front-load + burst
      { id = "bellows_priest", slot = 3 }, -- anti-décroissance
      { id = "wildfire_hound", slot = 7 }, -- propage à la mort
      { id = "ash_maw", slot = 2 },        -- CLUTCH : no-decay d'équipe
    },
    noteKey = "comp.burn_ligne_perfect.note",
  },
  {
    id = "burn_ligne_missing_clutch", archetype = "burn", variant = "missing_clutch", sigil = "ligne", boardLevel = 7,
    units = { -- ash_maw (CLUTCH) -> ash_moth (brûlure qui décroît vite) : les feux s'éteignent trop tôt
      { id = "soot_acolyte", slot = 5 },
      { id = "pyre_tender", slot = 4 }, { id = "emberling", slot = 6 },
      { id = "bellows_priest", slot = 3 }, { id = "wildfire_hound", slot = 7 },
      { id = "ash_moth", slot = 2 },
    },
    noteKey = "comp.burn_ligne_missing_clutch.note",
  },

  -- ── ROT (carré = hiérarchie ; decay_tender@5 buffe 2,4,6,8 ; AMPUTE les PV max = tueur de tanks) ──
  -- CLUTCH = pit_maw (transform : la pourriture rampe sur TOUTE l'équipe ennemie au début).
  {
    id = "rot_carre_perfect", archetype = "rot", variant = "perfect", sigil = "carre", boardLevel = 8,
    units = {
      { id = "decay_tender", slot = 5 },  -- AURA : +growth aux pourritures des voisins (2,4,6,8)
      { id = "rot_hound", slot = 2 }, { id = "necro_leech", slot = 4 }, -- base + amputation forte
      { id = "maggot_king", slot = 6 }, { id = "patient_worm", slot = 8 }, -- cap haut + ramp passif
      { id = "pit_maw", slot = 1 },       -- CLUTCH : rot d'équipe sur tout l'ennemi
    },
    noteKey = "comp.rot_carre_perfect.note",
  },
  {
    id = "rot_carre_missing_clutch", archetype = "rot", variant = "missing_clutch", sigil = "carre", boardLevel = 8,
    units = { -- pit_maw (CLUTCH) -> rot_hound : plus de pression de plafond de vie à l'ouverture
      { id = "decay_tender", slot = 5 },
      { id = "rot_hound", slot = 2 }, { id = "necro_leech", slot = 4 },
      { id = "maggot_king", slot = 6 }, { id = "patient_worm", slot = 8 },
      { id = "rot_hound", slot = 1 },
    },
    noteKey = "comp.rot_carre_missing_clutch.note",
  },

  -- ── BLEED (anneau = boucle ; clot_mender grant bleed à ses 2 voisins ; slow d'équipe = déni de tempo) ──
  {
    id = "bleed_anneau_perfect", archetype = "bleed", variant = "perfect", sigil = "anneau", boardLevel = 9,
    units = {
      { id = "clot_mender", slot = 1 },   -- AURA : les voisins (2,9) appliquent aussi un bleed
      { id = "razorkin", slot = 2 }, { id = "gash_fiend", slot = 9 }, -- bleed + slow
      { id = "hookjaw", slot = 5 },       -- gros slow (contrôle pur)
      { id = "bloodletter", slot = 4 },   -- aggravate (le bleed éclate quand la cible agit)
      { id = "slow_bleed", slot = 7 },    -- CLUTCH : ralentit toute l'équipe ennemie au début
    },
    noteKey = "comp.bleed_anneau_perfect.note",
  },

  -- ── TANK (carré = mur ; gravewarden taunt tire le focus ; templar boucliers ; plague_doctor regen) ──
  -- Le mur anti-DoT (regen + boucliers + épines). La compo que les DoT doivent apprendre à percer.
  {
    id = "tank_carre", archetype = "tank", variant = "wall", sigil = "carre", boardLevel = 8,
    units = {
      { id = "gravewarden", slot = 5 },   -- TAUNT : force le ciblage en façade
      { id = "templar", slot = 4 },       -- bouclier d'aura aux voisins
      { id = "plague_doctor", slot = 6 }, -- regen = contre-DoT
      { id = "skeleton", slot = 2 }, { id = "leech_thorn", slot = 8 }, -- épines
    },
    noteKey = "comp.tank_carre.note",
  },

  -- ── BRUISER (carré = stats brutes, zéro DoT : la compo TÉMOIN / baseline) ──
  {
    id = "bruiser_carre", archetype = "bruiser", variant = "baseline", sigil = "carre", boardLevel = 8,
    units = {
      { id = "marauder", slot = 5 }, { id = "demon", slot = 4 }, -- burst 1re frappe + vol de vie
      { id = "bandit", slot = 6 }, { id = "skeleton", slot = 2 }, { id = "marauder", slot = 8 },
    },
    noteKey = "comp.bruiser_carre.note",
  },

  -- ── SHOCK (carré ; stormcaller amplifie les dégâts-pris ; carry witch protégé derrière le tank) ──
  {
    id = "shock_carre", archetype = "shock", variant = "amp", sigil = "carre", boardLevel = 8,
    units = {
      { id = "gravewarden", slot = 5 },   -- tank/taunt en façade
      { id = "stormcaller", slot = 2 },   -- amplification des dégâts-pris (choc)
      { id = "witch", slot = 8 }, { id = "marauder", slot = 4 }, -- carry poison + burst
    },
    noteKey = "comp.shock_carre.note",
  },

  -- ══ COMPLÉMENT DES JEUX DE VARIANTS (toutes les familles DoT ont perfect/missing_minor/missing_clutch) ══
  {
    id = "burn_ligne_missing_minor", archetype = "burn", variant = "missing_minor", sigil = "ligne", boardLevel = 7,
    units = { -- bellows_priest (anti-decay redondant avec ash_maw) -> ash_moth (filler)
      { id = "soot_acolyte", slot = 5 }, { id = "pyre_tender", slot = 4 }, { id = "emberling", slot = 6 },
      { id = "ash_moth", slot = 3 }, { id = "wildfire_hound", slot = 7 }, { id = "ash_maw", slot = 2 },
    },
    noteKey = "comp.burn_ligne_missing_minor.note",
  },
  {
    id = "bleed_anneau_missing_minor", archetype = "bleed", variant = "missing_minor", sigil = "anneau", boardLevel = 9,
    units = { -- gash_fiend (2e saigneur, redondant) -> skeleton
      { id = "clot_mender", slot = 1 }, { id = "razorkin", slot = 2 }, { id = "skeleton", slot = 9 },
      { id = "hookjaw", slot = 5 }, { id = "bloodletter", slot = 4 }, { id = "slow_bleed", slot = 7 },
    },
    noteKey = "comp.bleed_anneau_missing_minor.note",
  },
  {
    id = "bleed_anneau_missing_clutch", archetype = "bleed", variant = "missing_clutch", sigil = "anneau", boardLevel = 9,
    units = { -- slow_bleed (slow d'équipe = CLUTCH) -> skeleton : plus de déni de tempo global
      { id = "clot_mender", slot = 1 }, { id = "razorkin", slot = 2 }, { id = "gash_fiend", slot = 9 },
      { id = "hookjaw", slot = 5 }, { id = "bloodletter", slot = 4 }, { id = "skeleton", slot = 7 },
    },
    noteKey = "comp.bleed_anneau_missing_clutch.note",
  },
  {
    id = "rot_carre_missing_minor", archetype = "rot", variant = "missing_minor", sigil = "carre", boardLevel = 8,
    units = { -- patient_worm (ramp passif redondant) -> skeleton
      { id = "decay_tender", slot = 5 }, { id = "rot_hound", slot = 2 }, { id = "necro_leech", slot = 4 },
      { id = "maggot_king", slot = 6 }, { id = "skeleton", slot = 8 }, { id = "pit_maw", slot = 1 },
    },
    noteKey = "comp.rot_carre_missing_minor.note",
  },

  -- ══ NIVEAUX DE BOARD (l'axe early/mid : moins de slots, moins d'unités -> matchups d'investissement) ══
  {
    id = "poison_diamant_mid", archetype = "poison", variant = "perfect", sigil = "diamant", boardLevel = 5,
    units = { -- board niveau ~5 (slots 1-5) : le coeur poison sans les premiums de fin de partie
      { id = "miasma_acolyte", slot = 5 }, { id = "spore_tick", slot = 2 }, { id = "bile_spitter", slot = 3 },
      { id = "plague_bearer", slot = 4 }, { id = "festering", slot = 1 },
    },
    noteKey = "comp.poison_diamant_mid.note",
  },
  {
    id = "tank_carre_mid", archetype = "tank", variant = "wall", sigil = "carre", boardLevel = 5,
    units = { -- mur niveau ~5 : taunt + bouclier + regen, sans la 2e ligne d'épines
      { id = "gravewarden", slot = 5 }, { id = "templar", slot = 4 }, { id = "plague_doctor", slot = 2 },
      { id = "skeleton", slot = 1 },
    },
    noteKey = "comp.tank_carre_mid.note",
  },

  -- ══ COMBO CROISÉ (T3 pivot) : bleed -> rot via marrow_drinker (convertit le bleed en pourriture) ══
  {
    id = "cross_bleed_rot", archetype = "rot", variant = "perfect", sigil = "carre", boardLevel = 8,
    units = {
      { id = "clot_mender", slot = 5 },   -- AURA : grant bleed aux voisins (2,4,6,8) = beaucoup de cibles saignantes
      { id = "razorkin", slot = 2 }, { id = "gash_fiend", slot = 4 }, -- enablers bleed
      { id = "marrow_drinker", slot = 6 }, -- PIVOT : convertit le bleed en rot (amputation)
      { id = "hookjaw", slot = 8 },       -- gros slow (tient la cible le temps de la conversion)
    },
    noteKey = "comp.cross_bleed_rot.note",
  },

  -- ══ VARIANTS CLUTCH de tank / bruiser (isolent la valeur d'une pièce non-DoT) ══
  {
    id = "tank_carre_no_taunt", archetype = "tank", variant = "missing_clutch", sigil = "carre", boardLevel = 8,
    units = { -- gravewarden (TAUNT = CLUTCH) -> skeleton : sans taunt, le carry adverse n'est plus forcé en façade
      { id = "skeleton", slot = 5 }, { id = "templar", slot = 4 }, { id = "plague_doctor", slot = 6 },
      { id = "skeleton", slot = 2 }, { id = "leech_thorn", slot = 8 },
    },
    noteKey = "comp.tank_carre_no_taunt.note",
  },
  {
    id = "bruiser_carre_no_sustain", archetype = "bruiser", variant = "missing_clutch", sigil = "carre", boardLevel = 8,
    units = { -- demon (vol de vie = CLUTCH de sustain) -> bandit
      { id = "marauder", slot = 5 }, { id = "bandit", slot = 4 }, { id = "bandit", slot = 6 },
      { id = "skeleton", slot = 2 }, { id = "marauder", slot = 8 },
    },
    noteKey = "comp.bruiser_carre_no_sustain.note",
  },

  -- ── SHOCK (vitrine de la ladder choc : empile l'amplification sur une cible durable, puis un gros
  -- frappeur la punit. gravewarden tient la façade ; stormlord pousse la cible vers le cap d'équipe). ──
  {
    id = "shock_storm_carre", archetype = "shock", variant = "amp", sigil = "carre", boardLevel = 8,
    units = {
      { id = "gravewarden", slot = 5 }, -- TAUNT : tient la façade pendant que l'équipe choque
      { id = "galvanizer", slot = 4 },  -- frappe + empile 2 chocs/coup (auto-synergie)
      { id = "thunderhead", slot = 6 }, -- gros chocs lourds (+12 %/stack)
      { id = "stormlord", slot = 2 },   -- amplificateur : pousse la cible vers le cap (+200 %)
      { id = "marauder", slot = 8 },    -- payoff : gros frappeur qui exploite la cible amplifiée
    },
    noteKey = "comp.shock_storm_carre.note",
  },

  -- ── BOUCLIER (vitrine du contour de bouclier : auras qui se recouvrent -> beaucoup de silhouettes
  -- blindées. bulwark_acolyte@5 couvre 2,4,6,8 ; aegis_warden taunt + épines tient le front). ──
  {
    id = "bulwark_carre", archetype = "shield", variant = "wall", sigil = "carre", boardLevel = 8,
    units = {
      { id = "bulwark_acolyte", slot = 5 }, -- AURA : +8 bouclier à TOUS les voisins (2,4,6,8)
      { id = "aegis_warden", slot = 4 },    -- TAUNT + bouclier aux voisins + épines (mur de front)
      { id = "oath_keeper", slot = 6 },     -- grosse aura (+18) côté front
      { id = "witch", slot = 2 },           -- carry fragile, protégé par les boucliers
      { id = "marauder", slot = 8 },        -- frappeur, protégé lui aussi
    },
    noteKey = "comp.bulwark_carre.note",
  },
}

-- ── Matchups FEATURED (la liste de scénarios « j'ai qu'à choisir »). seed FIXE -> match rejouable.
-- Beaucoup sont des COUNTERS DESIGNÉS (asymétriques par construction) : c'est attendu, pas un bug. ──
Compositions.scenarios = {
  { id = "rot_vs_tank",        a = "rot_carre_perfect",      b = "tank_carre",                    seed = 1001, noteKey = "scenario.rot_vs_tank.note" },
  { id = "poison_vs_tank",     a = "poison_diamant_perfect", b = "tank_carre",                    seed = 1002, noteKey = "scenario.poison_vs_tank.note" },
  { id = "burn_vs_tank",       a = "burn_ligne_perfect",     b = "tank_carre",                    seed = 1003, noteKey = "scenario.burn_vs_tank.note" },
  { id = "poison_clutch_test", a = "poison_diamant_perfect", b = "poison_diamant_missing_clutch", seed = 1004, noteKey = "scenario.poison_clutch_test.note" },
  { id = "poison_minor_test",  a = "poison_diamant_perfect", b = "poison_diamant_missing_minor",  seed = 1005, noteKey = "scenario.poison_minor_test.note" },
  { id = "bruiser_mirror",     a = "bruiser_carre",          b = "bruiser_carre",                 seed = 1006, noteKey = "scenario.bruiser_mirror.note" },
  { id = "bleed_vs_bruiser",   a = "bleed_anneau_perfect",   b = "bruiser_carre",                 seed = 1007, noteKey = "scenario.bleed_vs_bruiser.note" },
  { id = "rot_clutch_test",    a = "rot_carre_perfect",      b = "rot_carre_missing_clutch",      seed = 1008, noteKey = "scenario.rot_clutch_test.note" },
  -- variants complétés
  { id = "burn_minor_test",     a = "burn_ligne_perfect",    b = "burn_ligne_missing_minor",      seed = 1009, noteKey = "scenario.burn_minor_test.note" },
  { id = "bleed_clutch_test",   a = "bleed_anneau_perfect",  b = "bleed_anneau_missing_clutch",   seed = 1010, noteKey = "scenario.bleed_clutch_test.note" },
  { id = "rot_minor_test",      a = "rot_carre_perfect",     b = "rot_carre_missing_minor",       seed = 1011, noteKey = "scenario.rot_minor_test.note" },
  -- AXE NIVEAU DE BOARD (mid vs late, et mid sous-investi vs mur)
  { id = "board_level_poison",  a = "poison_diamant_mid",    b = "poison_diamant_perfect",        seed = 1012, noteKey = "scenario.board_level_poison.note" },
  { id = "board_level_tank",    a = "tank_carre_mid",        b = "tank_carre",                    seed = 1013, noteKey = "scenario.board_level_tank.note" },
  { id = "poison_mid_vs_tank",  a = "poison_diamant_mid",    b = "tank_carre",                    seed = 1017, noteKey = "scenario.poison_mid_vs_tank.note" },
  -- valeur d'une pièce non-DoT (taunt / sustain) + combo croisé
  { id = "tank_taunt_test",     a = "tank_carre",            b = "tank_carre_no_taunt",           seed = 1014, noteKey = "scenario.tank_taunt_test.note" },
  { id = "bruiser_sustain_test", a = "bruiser_carre",        b = "bruiser_carre_no_sustain",      seed = 1015, noteKey = "scenario.bruiser_sustain_test.note" },
  { id = "cross_vs_tank",       a = "cross_bleed_rot",       b = "tank_carre",                    seed = 1016, noteKey = "scenario.cross_vs_tank.note" },
  -- choc & bouclier (vitrines du feedback visuel : amplification du choc / absorption des boucliers)
  { id = "shock_vs_tank",       a = "shock_storm_carre",     b = "tank_carre",                    seed = 1018, noteKey = "scenario.shock_vs_tank.note" },
  { id = "shock_vs_bruiser",    a = "shock_storm_carre",     b = "bruiser_carre",                 seed = 1020, noteKey = "scenario.shock_vs_bruiser.note" },
  { id = "bulwark_vs_bruiser",  a = "bulwark_carre",         b = "bruiser_carre",                 seed = 1019, noteKey = "scenario.bulwark_vs_bruiser.note" },
}

-- ── Index (construits au load ; DATA pure, aucun love/require) ──
Compositions.byId = {}
Compositions.order = {}
Compositions.byArchetype = {}
for _, c in ipairs(Compositions.list) do
  Compositions.byId[c.id] = c
  Compositions.order[#Compositions.order + 1] = c.id
  local bucket = Compositions.byArchetype[c.archetype]
  if not bucket then bucket = {}; Compositions.byArchetype[c.archetype] = bucket end
  bucket[#bucket + 1] = c
end

-- Archétypes connus (l'analyseur d'équilibrage s'en sert ; l'intégrité du catalogue le vérifie).
Compositions.archetypes = { "poison", "burn", "bleed", "rot", "tank", "bruiser", "shock", "shield" }

return Compositions
