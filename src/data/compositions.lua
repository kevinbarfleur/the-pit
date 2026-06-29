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
--                   missing_clutch (LA pièce-clé retirée -> sous-performe) | wall|baseline|amp (mono) |
--                   murmur (vitrine de murmure caché inspectable en combat).
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

  -- ── SUSTAIN (carré : self-heal LOURD — regen + lifesteal empilés). La CIBLE des reliques anti-soin (Hollow
  -- Choir / everburn / open_wounds) : survit par le SOIN (pas le HP brut) -> percer/dépasser le soin la fait choir. ──
  {
    id = "sustain_carre", archetype = "sustain", variant = "wall", sigil = "carre", boardLevel = 8,
    units = {
      { id = "plague_doctor", slot = 5 }, { id = "plague_doctor", slot = 2 }, -- regen 3 (self-heal)
      { id = "demon", slot = 4 }, { id = "demon", slot = 6 }, { id = "demon", slot = 8 }, -- lifesteal 0.4 (self-heal)
    },
    noteKey = "comp.sustain_carre.note",
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
    id = "rot_bleed_mid", archetype = "rot", variant = "perfect", sigil = "carre", boardLevel = 6,
    units = {
      { id = "clot_mender", slot = 5 },   -- AURA : grant bleed aux voisins (2,4,6)
      { id = "razorkin", slot = 2, level = 2 },
      { id = "gash_fiend", slot = 4, level = 2 },
      { id = "hookjaw", slot = 6 },
      { id = "rot_hound", slot = 1, level = 2 },
      { id = "carrion_pecker", slot = 3 },
    },
    noteKey = "comp.rot_bleed_mid.note",
  },
  {
    id = "rot_bleed_rat_core", archetype = "rot", variant = "perfect", sigil = "carre", boardLevel = 6,
    units = {
      { id = "clot_mender", slot = 5, level = 2 }, -- AURA : grant bleed aux voisins (2,4,6)
      { id = "razorkin", slot = 2, level = 2 },
      { id = "gash_fiend", slot = 4, level = 2 },
      { id = "rot_hound", slot = 6, level = 3 },
      { id = "carrion_pecker", slot = 3, level = 3 },
      { id = "gnaw_rat", slot = 1, level = 3 },
    },
    noteKey = "comp.rot_bleed_rat_core.note",
  },
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

  -- ════════ ÉQUIPES « JOUEUR » (stratégies réalistes, un plan de jeu clair chacune) ════════

  -- VITRINE DE TRANSMISSION : les 4 porteurs de spread + leurs amorces, sur l'anneau (chaîne thématique).
  -- Contre un mur groupé -> on VOIT les arcs (poison/feu/pourriture) sauter de voisin en voisin.
  {
    id = "spread_showcase", archetype = "poison", variant = "perfect", sigil = "anneau", boardLevel = 9,
    units = {
      { id = "plague_bearer", slot = 1 },   -- contagion poison à chaque coup
      { id = "wildfire_hound", slot = 2 },  -- le feu saute aux voisins d'un mort en feu
      { id = "blight_spreader", slot = 3 }, -- la pourriture saute aux voisins d'un mort pourri
      { id = "plague_pyre", slot = 4 },     -- croisé feu->poison à la mort
      { id = "cinder_cur", slot = 5 },      -- amorce le feu (carburant de wildfire/pyre)
      { id = "rot_hound", slot = 6 },       -- amorce la pourriture (carburant de blight)
      { id = "spore_tick", slot = 7 },      -- amorce le poison vite (morts à détoner)
      { id = "venom_censer", slot = 8 },    -- croisé poison->feu : source d'ignition de plus
      { id = "miasma_acolyte", slot = 9 },  -- AURA poison aux voisins (8 et 1 sur l'anneau)
    },
    noteKey = "comp.spread_showcase.note",
  },

  -- MONO-CARRY poison : tous les amplis sur un seul contagieux au cœur de la croix (4 branches le nourrissent).
  {
    id = "poison_amp_croix", archetype = "poison", variant = "perfect", sigil = "croix", boardLevel = 8,
    units = {
      { id = "plague_bearer", slot = 1 },  -- CARRY : centre (voisins 2,4,6,8)
      { id = "miasma_acolyte", slot = 2 }, -- AURA +dps -> buffe le carry
      { id = "festering", slot = 4 },      -- TRANSFORM : poison d'équipe sans cap
      { id = "corruptor", slot = 6 },      -- weaken (anti-stat)
      { id = "acid_maw", slot = 8 },       -- le venin ronge les boucliers
      { id = "spore_tick", slot = 3 },     -- racine de branche : empile vite
      { id = "bile_spitter", slot = 5 },   -- racine : stacks moyens + weaken
    },
    noteKey = "comp.poison_amp_croix.note",
  },

  -- CONDUIT de feu inextinguible (ligne) : ash_maw + bellows + kiln -> les braises ne meurent jamais.
  {
    id = "burn_conduit_ligne", archetype = "burn", variant = "perfect", sigil = "ligne", boardLevel = 8,
    units = {
      { id = "pyre_tender", slot = 1 },    -- grosse brûlure de tête
      { id = "soot_acolyte", slot = 2 },   -- AURA +dps (voisins 1 et 3)
      { id = "cinder_cur", slot = 3 },     -- rallume vite (buffé par l'aura)
      { id = "kiln_warden", slot = 4 },    -- les faibles brûlures PROLONGENT
      { id = "bellows_priest", slot = 5 }, -- anti-décroissance
      { id = "ash_maw", slot = 6 },        -- TRANSFORM : feux d'équipe sans décroissance
      { id = "ash_moth", slot = 7 },       -- feu bon marché, gardé vivant par ash_maw
      { id = "emberling", slot = 8 },      -- burst devenu permanent -> lèche le bouclier
    },
    noteKey = "comp.burn_conduit_ligne.note",
  },

  -- VERROU de tempo (anneau) : on ne court pas aux dégâts, on DÉNIE l'horloge ennemie (slows + punition d'action).
  {
    id = "bleed_lock_anneau", archetype = "bleed", variant = "perfect", sigil = "anneau", boardLevel = 7,
    units = {
      { id = "slow_bleed", slot = 1 },     -- TRANSFORM : ralentit TOUTE l'équipe ennemie au début
      { id = "hookjaw", slot = 2 },        -- gros slow, dégâts minimes = tempo pur
      { id = "bloodletter", slot = 3 },    -- le saignement ÉCLATE quand la cible agit
      { id = "tendon_render", slot = 4 },  -- slow qui scale avec les PV manquants
      { id = "clot_mender", slot = 5 },    -- AURA : les voisins appliquent aussi un bleed
      { id = "gash_fiend", slot = 6 },     -- bleed solide (voisin d'aura)
      { id = "razorkin", slot = 7 },       -- bleed + slow de cadence (ferme l'anneau)
    },
    noteKey = "comp.bleed_lock_anneau.note",
  },

  -- POURRITURE patiente (carré) : perd tôt, gagne tard (ramp passif + auto-soin jusqu'au plafond de PV mangé).
  {
    id = "rot_patient_carre", archetype = "rot", variant = "perfect", sigil = "carre", boardLevel = 9,
    units = {
      { id = "maggot_king", slot = 5 },    -- cap HAUT, payoff long terme (centre)
      { id = "decay_tender", slot = 4 },   -- AURA +growth (voisin de 5)
      { id = "patient_worm", slot = 2 },   -- ramp passif (voisin de 5)
      { id = "necro_leech", slot = 6 },    -- amputation renforcée (voisin de 5)
      { id = "rot_hound", slot = 8 },      -- ampute les PV max (voisin de 5)
      { id = "hollow_gut", slot = 1 },     -- l'amputation SOIGNE le porteur (survie)
      { id = "carrion_pecker", slot = 3 }, -- enfle vite, cap bas (pression early)
      { id = "patient_worm", slot = 7 },   -- 2e moteur de ramp passif
      { id = "wither_bloom", slot = 9 },   -- croisé rot->slow+weaken (gagne du temps)
    },
    noteKey = "comp.rot_patient_carre.note",
  },

  -- MOTEUR d'attrition croisée (diamant) : poison<->feu se nourrissent (censer détone, pyre re-sème le venin).
  {
    id = "cross_venom_pyre", archetype = "poison", variant = "perfect", sigil = "diamant", boardLevel = 9,
    units = {
      { id = "venom_censer", slot = 5 },   -- croisé poison->feu (centre, beaucoup de voisins)
      { id = "plague_pyre", slot = 4 },    -- croisé feu->poison à la mort (voisin de 5)
      { id = "miasma_acolyte", slot = 2 }, -- AURA poison (voisins 1,4,5)
      { id = "spore_tick", slot = 1 },     -- amorce poison (haut)
      { id = "bile_spitter", slot = 6 },   -- poison + weaken (voisin de 5)
      { id = "cinder_cur", slot = 7 },     -- amorce feu (carburant)
      { id = "soot_acolyte", slot = 8 },   -- AURA feu (voisins 5,9)
      { id = "emberling", slot = 9 },      -- payoff feu (bas, buffé par soot)
    },
    noteKey = "comp.cross_venom_pyre.note",
  },

  -- NUKE à condensateur (croix) : on charge UN gros condensateur et on fait sauter une proie marquée.
  {
    id = "shock_nuke_croix", archetype = "shock", variant = "perfect", sigil = "croix", boardLevel = 8,
    units = {
      { id = "thunderhead", slot = 1 },    -- CARRY : charge dense, lourde (centre)
      { id = "galvanizer", slot = 2 },     -- charge puis auto-décharge
      { id = "stormlord", slot = 4 },      -- marque la proie pour les alliés
      { id = "stormcaller", slot = 6 },    -- charge le condensateur
      { id = "static_swarm", slot = 8 },   -- charge régulière, longue durée
      { id = "live_wire", slot = 3 },      -- petite charge rapide (racine)
      { id = "live_wire", slot = 5 },      -- 2e chargeur rapide
    },
    noteKey = "comp.shock_nuke_croix.note",
  },

  -- FORTERESSE à épines (carré) : taunt + boucliers + épines -> l'ennemi se TUE en frappant le mur.
  {
    id = "fortress_thorns_carre", archetype = "shield", variant = "wall", sigil = "carre", boardLevel = 9,
    units = {
      { id = "aegis_warden", slot = 5 },    -- TAUNT + aura bouclier + épines (centre)
      { id = "oath_keeper", slot = 2 },     -- grosse aura bouclier + dégâts (voisin de 5)
      { id = "bulwark_acolyte", slot = 4 }, -- bouclier modeste à TOUS les voisins
      { id = "shieldbearer", slot = 6 },    -- tank cheap + petite aura
      { id = "leech_thorn", slot = 8 },     -- bleed + ÉPINES (réflexion)
      { id = "skeleton", slot = 1 },        -- épines filler (coin)
      { id = "leech_thorn", slot = 3 },     -- 2e réflecteur d'épines (coin)
      { id = "gravewarden", slot = 7 },     -- 2e taunt + épines (ancre un flanc)
      { id = "plague_doctor", slot = 9 },   -- regen = soutien du mur
    },
    noteKey = "comp.fortress_thorns_carre.note",
  },

  -- ESSAIM go-wide (diamant) : pile de petites unités bon marché, 2 auras -> tout le monde se buffe un peu.
  {
    id = "swarm_wide_diamant", archetype = "burn", variant = "baseline", sigil = "diamant", boardLevel = 9,
    units = {
      { id = "ash_moth", slot = 1 },       -- feu bon marché
      { id = "soot_acolyte", slot = 5 },   -- AURA feu (centre, beaucoup de voisins)
      { id = "cinder_cur", slot = 4 },     -- rallume vite (voisin de 5)
      { id = "ash_moth", slot = 6 },       -- feu bon marché (voisin de 5)
      { id = "spore_tick", slot = 2 },     -- amorce poison (largeur)
      { id = "cinder_cur", slot = 7 },     -- feu rapide (voisin de 5)
      { id = "ash_moth", slot = 8 },       -- feu bon marché (voisin de 5)
      { id = "skeleton", slot = 3 },       -- corps cheap à épines
      { id = "carrion_pecker", slot = 9 }, -- pourriture rapide (largeur, chip croisé)
    },
    noteKey = "comp.swarm_wide_diamant.note",
  },

  -- FORTERESSE à boucliers PÉRIODIQUES : ward_weaver re-blinde le centre toutes les 4 s, dopé par 3 renforts
  -- adjacents (valeur+cadence / réflexion+largeur / surcharge). Le mur se re-dresse en boucle, mord, et gonfle.
  {
    id = "ward_fortress_carre", archetype = "shield", variant = "wall", sigil = "carre", boardLevel = 8,
    units = {
      { id = "ward_weaver", slot = 5 },     -- caster périodique (centre, voisins 2,4,6,8)
      { id = "barrier_savant", slot = 2 },  -- renfort : +valeur +cadence
      { id = "mirror_ward", slot = 4 },     -- renfort : réflexion + rayon 2
      { id = "surge_warden", slot = 6 },    -- renfort : surcharge + valeur
      { id = "gravewarden", slot = 8 },     -- taunt blindé en façade
    },
    noteKey = "comp.ward_fortress_carre.note",
  },
  -- SIÈGE : le counter du même lot (siege_breaker dissout les boucliers) -> prouve qu'un mur a sa réponse.
  {
    id = "siege_carre", archetype = "bruiser", variant = "baseline", sigil = "carre", boardLevel = 8,
    units = {
      { id = "siege_breaker", slot = 5 }, { id = "marauder", slot = 4 }, { id = "bandit", slot = 6 },
      { id = "skeleton", slot = 2 }, { id = "demon", slot = 8 },
    },
    noteKey = "comp.siege_carre.note",
  },
  -- CHOC à modificateurs rares : la décharge ARQUE (arc_warden), SAUTE aux voisins (dynamo_priest) et
  -- PERSISTE (storm_anchor) -> une tempête qui se propage et ne s'éteint jamais vraiment.
  {
    id = "shock_arc_carre", archetype = "shock", variant = "amp", sigil = "carre", boardLevel = 8,
    units = {
      { id = "arc_warden", slot = 5 },    -- CHAIN : la décharge arque sur 2 voisins
      { id = "dynamo_priest", slot = 2 }, -- TRANSFER : la charge saute
      { id = "storm_anchor", slot = 4 },  -- PERSIST : la charge ne se vide pas
      { id = "stormcaller", slot = 6 },   -- chargeur de base (alimente la décharge)
      { id = "gravewarden", slot = 8 },   -- taunt : tient le front pendant que ça charge
    },
    noteKey = "comp.shock_arc_carre.note",
  },

  -- ════════ MURMURES (3e couche cachée) : compos de vitrine pour l'inspection Proving Ground ════════
  -- Les murmures restent ABSENTS des cartes/grimoire/tags publics. Ces équipes existent pour WATCH + pause
  -- combat : survoler le porteur montre la ligne cryptique dans le panneau d'influences, tout en conservant
  -- les auras publiques visibles autour.
  {
    id = "whisper_abyss_carre", archetype = "poison", variant = "murmur", sigil = "carre", boardLevel = 8,
    units = {
      { id = "ink_horror", slot = 5, level = 2 },  -- murmure présence : deep_kraken -> atkInc caché
      { id = "deep_kraken", slot = 2 },            -- partenaire + aura poison publique sur le centre
      { id = "corruptor", slot = 4, level = 2 },   -- murmure présence : kraken -> stat cachée
      { id = "miasma_acolyte", slot = 6 },         -- aura poison publique, pour superposer visible/caché
      { id = "spore_tick", slot = 1 },
    },
    noteKey = "comp.whisper_abyss_carre.note",
  },
  {
    id = "whisper_forge_ligne", archetype = "burn", variant = "murmur", sigil = "ligne", boardLevel = 7,
    units = {
      { id = "cinder_cur", slot = 4, level = 2 },  -- murmure adjacency : pyre_tender -> burnInc caché
      { id = "pyre_tender", slot = 5 },
      { id = "soot_acolyte", slot = 3 },           -- murmure famille burn + aura feu publique
      { id = "emberling", slot = 2 },
      { id = "ash_moth", slot = 6 },
      { id = "wildfire_hound", slot = 7 },
    },
    noteKey = "comp.whisper_forge_ligne.note",
  },
  {
    id = "whisper_echo_carre", archetype = "shock", variant = "murmur", sigil = "carre", boardLevel = 8,
    units = {
      { id = "storm_conductor", slot = 5, level = 2 }, -- murmure adjacency : echo_warden -> atkInc caché
      { id = "echo_warden", slot = 4 },
      { id = "mimic_spawn", slot = 2 },                -- murmure présence : echo_flesh -> atkInc caché
      { id = "echo_flesh", slot = 6 },
      { id = "live_wire", slot = 8 },
    },
    noteKey = "comp.whisper_echo_carre.note",
  },
  {
    id = "whisper_patient_carre", archetype = "rot", variant = "murmur", sigil = "carre", boardLevel = 8,
    units = {
      { id = "patient_worm", slot = 5, level = 2 }, -- murmure différé après durée : à voir en pause combat
      { id = "hollow_gut", slot = 4 },              -- murmure seuil PV : discret si l'ennemi le met bas
      { id = "husk", slot = 2, level = 2 },         -- murmure mort alliée : gagne une ligne quand un allié tombe
      { id = "rot_hound", slot = 6 },
      { id = "gnaw_rat", slot = 8 },
    },
    noteKey = "comp.whisper_patient_carre.note",
  },
}

-- ── Matchups FEATURED (la liste de scénarios « j'ai qu'à choisir »). seed FIXE -> match rejouable.
-- Beaucoup sont des COUNTERS DESIGNÉS (asymétriques par construction) : c'est attendu, pas un bug. ──
Compositions.scenarios = {
  { id = "rot_vs_tank",        a = "rot_carre_perfect",      b = "tank_carre",                    seed = 1001, tags = { "vfx" }, noteKey = "scenario.rot_vs_tank.note" },
  { id = "poison_vs_tank",     a = "poison_diamant_perfect", b = "tank_carre",                    seed = 1002, tags = { "spread", "vfx" }, noteKey = "scenario.poison_vs_tank.note" },
  { id = "burn_vs_tank",       a = "burn_ligne_perfect",     b = "tank_carre",                    seed = 1003, tags = { "vfx" }, noteKey = "scenario.burn_vs_tank.note" },
  { id = "poison_clutch_test", a = "poison_diamant_perfect", b = "poison_diamant_missing_clutch", seed = 1004, noteKey = "scenario.poison_clutch_test.note" },
  { id = "poison_minor_test",  a = "poison_diamant_perfect", b = "poison_diamant_missing_minor",  seed = 1005, noteKey = "scenario.poison_minor_test.note" },
  { id = "bruiser_mirror",     a = "bruiser_carre",          b = "bruiser_carre",                 seed = 1006, tags = { "mirror" }, noteKey = "scenario.bruiser_mirror.note" },
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
  { id = "cross_vs_tank",       a = "cross_bleed_rot",       b = "tank_carre",                    seed = 1016, tags = { "cross", "vfx" }, noteKey = "scenario.cross_vs_tank.note" },
  -- choc & bouclier (vitrines du feedback visuel : amplification du choc / absorption des boucliers)
  { id = "shock_vs_tank",       a = "shock_storm_carre",     b = "tank_carre",                    seed = 1018, tags = { "vfx" }, noteKey = "scenario.shock_vs_tank.note" },
  { id = "shock_vs_bruiser",    a = "shock_storm_carre",     b = "bruiser_carre",                 seed = 1020, tags = { "vfx" }, noteKey = "scenario.shock_vs_bruiser.note" },
  { id = "bulwark_vs_bruiser",  a = "bulwark_carre",         b = "bruiser_carre",                 seed = 1019, tags = { "vfx" },                  noteKey = "scenario.bulwark_vs_bruiser.note" },
  -- ── ÉQUIPES « joueur » + vitrine de TRANSMISSION (arcs d'afflictions qui sautent) ──
  { id = "transmission",     a = "spread_showcase",    b = "bruiser_carre",         seed = 1021, tags = { "spread", "cross", "vfx" }, noteKey = "scenario.transmission.note" }, -- bruiser (pas tank) : meurt en pourrissant -> les 3 familles sautent (poison/feu/rot)
  { id = "amp_vs_wall",      a = "poison_amp_croix",   b = "fortress_thorns_carre", seed = 1022, tags = { "tempo" },                 noteKey = "scenario.amp_vs_wall.note" },
  { id = "conduit_vs_swarm", a = "burn_conduit_ligne", b = "swarm_wide_diamant",    seed = 1023, tags = { "vfx" },                   noteKey = "scenario.conduit_vs_swarm.note" },
  { id = "lockdown",         a = "bleed_lock_anneau",  b = "shock_nuke_croix",      seed = 1024, tags = { "tempo" },                 noteKey = "scenario.lockdown.note" },
  { id = "inevitable",       a = "rot_patient_carre",  b = "burn_conduit_ligne",    seed = 1025, tags = { "tempo", "vfx" },         noteKey = "scenario.inevitable.note" },
  { id = "infection_loop",   a = "cross_venom_pyre",   b = "tank_carre",            seed = 1026, tags = { "cross", "spread", "vfx" }, noteKey = "scenario.infection_loop.note" },
  { id = "nuke_vs_fortress", a = "shock_nuke_croix",   b = "fortress_thorns_carre", seed = 1027, tags = { "vfx" },                   noteKey = "scenario.nuke_vs_fortress.note" },
  { id = "plague_mirror",    a = "poison_amp_croix",   b = "spread_showcase",       seed = 1028, tags = { "mirror", "spread" },      noteKey = "scenario.plague_mirror.note" },
  { id = "attrition_clash",  a = "cross_venom_pyre",   b = "rot_patient_carre",     seed = 1029, tags = { "cross", "tempo" },       noteKey = "scenario.attrition_clash.note" },
  { id = "swarm_vs_lock",    a = "swarm_wide_diamant", b = "bleed_lock_anneau",     seed = 1030, tags = { "tempo", "vfx" },         noteKey = "scenario.swarm_vs_lock.note" },
  -- ── Boucliers périodiques (re-cast + réflexion + surcharge) et leur counter (perce-bouclier) ──
  { id = "ward_wall",        a = "ward_fortress_carre", b = "bruiser_carre",        seed = 1031, tags = { "vfx" },                  noteKey = "scenario.ward_wall.note" },
  { id = "breach",           a = "siege_carre",         b = "ward_fortress_carre",  seed = 1032, tags = { "vfx" },                  noteKey = "scenario.breach.note" },
  { id = "arc_storm",        a = "shock_arc_carre",     b = "bruiser_carre",        seed = 1033, tags = { "vfx" },                  noteKey = "scenario.arc_storm.note" },
  -- ── Murmures visibles seulement dans le panneau d'influences combat (pas dans cartes/tags/grimoire) ──
  { id = "whisper_abyss",     a = "whisper_abyss_carre",   b = "tank_carre",         seed = 1041, tags = { "murmur", "vfx" },        noteKey = "scenario.whisper_abyss.note" },
  { id = "whisper_forge",     a = "whisper_forge_ligne",   b = "bruiser_carre",      seed = 1042, tags = { "murmur", "vfx" },        noteKey = "scenario.whisper_forge.note" },
  { id = "whisper_echo",      a = "whisper_echo_carre",    b = "shock_storm_carre",  seed = 1043, tags = { "murmur", "tempo" },      noteKey = "scenario.whisper_echo.note" },
  { id = "whisper_patient",   a = "whisper_patient_carre", b = "bruiser_carre",      seed = 1044, tags = { "murmur", "tempo" },      noteKey = "scenario.whisper_patient.note" },
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
Compositions.archetypes = { "poison", "burn", "bleed", "rot", "tank", "bruiser", "shock", "shield", "sustain" }

-- Tags THÉMATIQUES (facette de filtre transversale du Proving Ground, en plus des archétypes). Ordre =
-- ordre d'affichage des chips. L'intégrité du catalogue vérifie que tout tag de scénario est connu.
Compositions.tags = { "spread", "cross", "tempo", "vfx", "mirror", "murmur" }
Compositions.tagSet = {}
for _, tg in ipairs(Compositions.tags) do Compositions.tagSet[tg] = true end

return Compositions
