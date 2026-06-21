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
Compositions.archetypes = { "poison", "burn", "bleed", "rot", "tank", "bruiser", "shock" }

return Compositions
