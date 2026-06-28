-- src/data/run_events.lua
-- RUN EVENTS : couche d'acquisition thematique qui peut remplacer le marchand
-- pur "1 relique parmi 3" sur les jalons tous les 3 combats.
--
-- Contrat design :
--   * le texte peut etre cryptique, mais la recompense materialisee est toujours
--     explicite pour le joueur ;
--   * pas plus de 8 events actifs tant que l'equilibrage n'a pas mesure leur
--     impact sur la boucle economie/TTK/power spikes ;
--   * les mutations de monstres sont une extension future : elles demandent un
--     modele d'instance persistant propre (fusion, snapshot, combat, UI).

local E = {}

E.MAX_ACTIVE = 8

E.events = {
  hollow_carcass = {
    id = "hollow_carcass",
    minCombats = 3,
    choices = {
      { id = "cut_the_sigil", reward = { kind = "relic" } },
      { id = "drag_the_survivor", reward = { kind = "unit", rankMin = 1, rankMax = 1, level = 2 } },
      { id = "strip_the_teeth", reward = { kind = "gold", amount = 5 } },
    },
  },

  sealed_brood = {
    id = "sealed_brood",
    minCombats = 3,
    choices = {
      { id = "crack_the_warm_egg", reward = { kind = "unit", rankMin = 1, rankMax = 2, level = 1 } },
      { id = "take_the_twin", reward = { kind = "unit", rankMin = 1, rankMax = 1, level = 2 } },
      { id = "boil_the_shell", reward = { kind = "relic" } },
    },
  },

  drowned_bazaar = {
    id = "drowned_bazaar",
    minCombats = 3,
    choices = {
      { id = "buy_the_fragment", reward = { kind = "relic" } },
      { id = "pocket_the_change", reward = { kind = "gold", amount = 6 } },
      { id = "read_the_tide_marks", reward = { kind = "relic" } },
    },
  },

  bone_choir = {
    id = "bone_choir",
    minWins = 2,
    choices = {
      { id = "answer_the_hymn", reward = { kind = "relic", minTier = "mid" } },
      { id = "seat_a_chorister", reward = { kind = "unit", rankMin = 2, rankMax = 3, level = 1 } },
      { id = "break_the_conductor", reward = { kind = "gold", amount = 7 } },
    },
  },

  fossil_gate = {
    id = "fossil_gate",
    minWins = 2,
    choices = {
      { id = "force_the_hinge", reward = { kind = "shop_tier_up", amount = 1 } },
      { id = "copy_the_glyphs", reward = { kind = "relic" } },
      { id = "pluck_the_lock", reward = { kind = "relic" } },
    },
  },

  wounded_thing = {
    id = "wounded_thing",
    minCombats = 3,
    choices = {
      { id = "bind_its_chain", reward = { kind = "relic" } },
      { id = "feed_it_blood", reward = { kind = "unit", rankMin = 1, rankMax = 1, level = 2 } },
      { id = "harvest_the_chain", reward = { kind = "relic" } },
    },
  },

  ashen_well = {
    id = "ashen_well",
    minCombats = 6,
    choices = {
      { id = "lower_the_hook", reward = { kind = "relic", minTier = "mid" } },
      { id = "drink_the_heat", reward = { kind = "shop_xp", amount = 5 } },
      { id = "sell_the_ashes", reward = { kind = "gold", amount = 8 } },
    },
  },

  pale_auction = {
    id = "pale_auction",
    minWins = 4,
    choices = {
      { id = "raise_the_paddle", reward = { kind = "relic", minTier = "mid" } },
      { id = "take_the_caged_lot", reward = { kind = "unit", rankMin = 2, rankMax = 3, level = 2 } },
      { id = "steal_the_bid_book", reward = { kind = "gold", amount = 9 } },
    },
  },
}

E.order = {
  "hollow_carcass",
  "sealed_brood",
  "drowned_bazaar",
  "bone_choir",
  "fossil_gate",
  "wounded_thing",
  "ashen_well",
  "pale_auction",
}

return E
