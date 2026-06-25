-- src/lab/bands.lua
-- BANDES de stade (EARLY / MID / END) pour le HARNAIS D'ÉQUILIBRAGE DE MASSE (tools/balancematrix.lua).
-- Chaque bande = un petit jeu de COMPOS REPRÉSENTATIVES du stade (le « build joueur » typique à ce moment du
-- Puits) + un CHAMP D'ADVERSAIRES représentatif (mirror + counters + un set d'opposants). C'est la matrice
-- « bande × relique × commandant » que l'user veut balayer pour JUGER l'équilibre.
--
-- DATA pure (require Units pour les rangs ; aucun love, aucun RunState, aucun Build). Le format d'une compo
-- est CELUI du catalogue (src/data/compositions) : { id, archetype, sigil, boardLevel, units = {{id,slot,level?}} }
-- -> directement consommable par Compbuild.toComp / Compcost.of. Sigils GELÉS -> toutes sur "carre".
--
-- POURQUOI des compos PARAMÉTRIQUES (et pas juste le catalogue) : le catalogue est riche mais pas « banded »
-- proprement (mélange de boardLevel/niveaux). On veut un contrôle NET de l'axe d'investissement par stade :
--   EARLY : stat-sticks rank-1/2, 3-4 unités, niveau 1, AUCUNE relique de base.
--   MID   : enablers rank-3 + auras, 5-6 unités, quelques DOUBLONS niveau 2.
--   END   : carries rank-5 amplifiés, 9 unités, doublons niveau 2-3, le cœur multicast.
-- On RÉUTILISE les ids du roster réel (par rang, cf. Units) -> les bandes suivent le contenu, pas une copie.
--
-- GÉOMÉTRIE du carré (sigils gelés) : slots 1-3 = rangée haut (y=0), 4-6 = milieu (y=1), 7-9 = bas (y=2) ;
-- x = (slot-1)%3 ; depth = maxC - x -> col 2 (slots 3,6,9) = FRONT, col 0 (slots 1,4,7) = BACK. On place les
-- tanks/façade au front (col 2) et les carries au back (col 0), comme un vrai plateau.

local Bands = {}

-- Slots du carré par colonne (front=col2 -> back=col0). Sert à placer façade/carry au bon endroit.
Bands.FRONT = { 3, 6, 9 } -- col 2 (depth 0)
Bands.MID_COL = { 2, 5, 8 } -- col 1 (depth 1)
Bands.BACK = { 1, 4, 7 } -- col 0 (depth 2)

-- ⚠️ CONTRAINTE de slots : Board:unlock(boardLevel) ouvre les slots 1..boardLevel DANS L'ORDRE D'INDEX (carré).
-- Toute unité posée sur un slot > boardLevel est SILENCIEUSEMENT ignorée par buildComp -> on respecte
-- STRICTEMENT slot <= boardLevel ci-dessous (le smoke test de tests/lab.lua le vérifie : declared == placed).
-- Sur les slots 1..n : col(slot) = (slot-1)%3 -> slot 3,6,9 = FRONT (depth 0) ; slot 1,4,7 = BACK (depth 2).

-- ── EARLY — stat-sticks rank-1/2, 3-4 unités, niveau 1, reliques BAS seulement (appliquées par le runner) ──
-- Deux saveurs : brutes pures (témoin sans DoT) + un early « afflictions » (les premiers poseurs cheap).
local EARLY = {
  {
    id = "early_bruisers", archetype = "bruiser", variant = "early", sigil = "carre", boardLevel = 4, band = "early",
    units = { -- 3 brutes rang-1 + 1 rang-2 : la masse de chair sans synergie (le squelette de toute run)
      { id = "footman", slot = 3 }, { id = "marauder", slot = 2 }, -- 3 = front, 2 = mid
      { id = "skeleton", slot = 1 }, { id = "bandit", slot = 4 },  -- 1,4 = back
    },
  },
  {
    id = "early_affliction", archetype = "poison", variant = "early", sigil = "carre", boardLevel = 4, band = "early",
    units = { -- premiers poseurs cheap (rank 1-2) : on commence à empiler des stacks, sans ampli
      { id = "demon", slot = 3 }, { id = "spore_tick", slot = 2 }, -- demon (leurre) au front
      { id = "gnaw_rat", slot = 1 }, { id = "witch", slot = 4 },   -- carry witch au back
    },
  },
}

-- ── MID — enablers rank-3 + auras d'adjacence, 5-6 unités, doublons niveau 2, reliques BAS+MOYEN, commandants ──
local MID = {
  {
    id = "mid_poison", archetype = "poison", variant = "mid", sigil = "carre", boardLevel = 6, band = "mid",
    units = { -- aura miasma au centre (slot 5 = voisins 2,4,6,8 -> ici 2,4,6) ; spore_tick niveau 2 (doublon)
      { id = "miasma_acolyte", slot = 5 }, -- AURA poison aux voisins
      { id = "spore_tick", slot = 2, level = 2 }, { id = "bile_spitter", slot = 4 },
      { id = "corruptor", slot = 6 }, { id = "witch", slot = 1 }, { id = "demon", slot = 3 },
    },
  },
  {
    id = "mid_tank", archetype = "tank", variant = "mid", sigil = "carre", boardLevel = 6, band = "mid",
    units = { -- mur mid : taunt + bouclier d'aura + regen (la défense de mi-parcours)
      { id = "gravewarden", slot = 6 }, -- taunt en façade (front, col 2)
      { id = "templar", slot = 5 }, { id = "plague_doctor", slot = 4 },
      { id = "leech_thorn", slot = 3 }, { id = "skeleton", slot = 2, level = 2 }, { id = "footman", slot = 1 },
    },
  },
  {
    id = "mid_shock", archetype = "shock", variant = "mid", sigil = "carre", boardLevel = 6, band = "mid",
    units = { -- amplificateur de choc derrière un taunt + carry frappeur (mid value)
      { id = "gravewarden", slot = 6 }, { id = "stormcaller", slot = 2 },
      { id = "thunderhead", slot = 4 }, { id = "marauder", slot = 5 },
      { id = "static_swarm", slot = 3 }, { id = "witch", slot = 1 },
    },
  },
}

-- ── END — carries rank-5 amplifiés, 9 unités, doublons niveau 2-3, multicast, tous paliers ──
local END = {
  {
    id = "end_poison", archetype = "poison", variant = "end", sigil = "carre", boardLevel = 9, band = "end",
    units = { -- plateau plein : aura + cap-break (festering) + détonateur + carry kraken rank-5, doublons niv2
      { id = "miasma_acolyte", slot = 5 }, -- AURA poison
      { id = "spore_tick", slot = 2, level = 2 }, { id = "bile_spitter", slot = 4 },
      { id = "corruptor", slot = 8 }, { id = "plague_bearer", slot = 1 },
      { id = "festering", slot = 7 },     -- cap-break d'équipe (rank 5)
      { id = "venom_censer", slot = 3 },  -- détonateur (rank 5)
      { id = "deep_kraken", slot = 9 },   -- carry rank-5
      { id = "witch", slot = 6, level = 2 },
    },
  },
  {
    id = "end_rot", archetype = "rot", variant = "end", sigil = "carre", boardLevel = 9, band = "end",
    units = { -- pourriture late : aura growth + amputation + transform d'équipe + colosse rank-5
      { id = "decay_tender", slot = 5 }, -- AURA growth
      { id = "rot_hound", slot = 2, level = 2 }, { id = "necro_leech", slot = 4 },
      { id = "maggot_king", slot = 6 }, { id = "patient_worm", slot = 8 },
      { id = "pit_maw", slot = 1 },       -- transform : rot d'équipe (rank 5)
      { id = "marrow_drinker", slot = 7 }, -- pivot bleed->rot (rank 5)
      { id = "skull_colossus", slot = 3 }, -- carry rank-5 (front)
      { id = "hollow_gut", slot = 9 },
    },
  },
  {
    id = "end_shock_multicast", archetype = "shock", variant = "end", sigil = "carre", boardLevel = 9, band = "end",
    units = { -- vitrine MULTICAST : hookjaw au front (porte multicast role:front), amplis de choc, gros frappeurs
      { id = "gravewarden", slot = 5 },   -- taunt central
      { id = "hookjaw", slot = 3 },        -- FRONT : porte multicast role:front (cible des reliques/cmd echo)
      { id = "stormlord", slot = 2 },      -- amplificateur (pousse au cap)
      { id = "thunderhead", slot = 4 }, { id = "galvanizer", slot = 8 },
      { id = "marauder", slot = 6, level = 2 }, -- payoff frappeur, doublon niv2
      { id = "static_swarm", slot = 1 }, { id = "stormcaller", slot = 7 },
      { id = "skull_colossus", slot = 9 }, -- carry rank-5
    },
  },
}

Bands.list = { early = EARLY, mid = MID, end_ = END }
Bands.order = { "early", "mid", "end_" }
Bands.label = { early = "EARLY", mid = "MID", end_ = "END" }

-- Index plat de toutes les compos de bande (id -> compo), pour le runner et les tests.
Bands.byId = {}
for _, band in pairs(Bands.list) do
  for _, c in ipairs(band) do Bands.byId[c.id] = c end
end

-- ── CHAMP D'ADVERSAIRES par bande (déterministe ; les compos statiques viennent du catalogue + des bandes).
-- mirror = la compo elle-même (relancée) ; counters = compos d'archétype opposé ; opponents = un set fixe.
-- Le runner AJOUTE des opposants OppGen scalés au stade (procéduraux, seedés) -> couverture procédurale + figée.
-- Référence les ids du CATALOGUE (Compositions) ET des bandes (Bands.byId) ; le runner résout les deux. ──
Bands.field = {
  -- EARLY : on s'affronte entre petits builds + un mur mid sous-dimensionné (l'early ne perce pas encore).
  early = { "early_bruisers", "early_affliction", "tank_carre_mid", "poison_diamant_mid" },
  -- MID : le cœur du jeu — DoT mid vs murs vs choc, + les counters d'archétype.
  mid = { "mid_poison", "mid_tank", "mid_shock", "bruiser_carre", "tank_carre", "sustain_carre" },
  -- END : tout le monde est armé — carries amplifiés, transforms, murs complets.
  end_ = { "end_poison", "end_rot", "end_shock_multicast", "tank_carre", "fortress_thorns_carre",
    "poison_diamant_perfect", "bulwark_carre" },
}

return Bands
