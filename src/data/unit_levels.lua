-- src/data/unit_levels.lua
-- Authored level-up deltas for monster abilities.
--
-- Level 1 is always the base definition in src/data/units.lua. Entries here
-- are cumulative patches applied from level 2 up to the requested level.
-- Keep this file data-only: no requires, no functions, no love.*.

return {
  -- Low-rank tank reroll seed: level 1 establishes a real front-guard
  -- mechanic, while level 3 turns it into a small team wall.
  husk = {
    [2] = {
      effects = {
        [1] = { params = { value = 0.10 } },
      },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { target = "team", params = { value = 0.08 } },
      },
    },
  },

  -- Low-rank poison reroll seed: level 3 gains a small spread rider instead
  -- of just becoming a larger stat stick.
  spore_tick = {
    [2] = {
      effects = {
        [1] = { params = { dps = 2 } },
      },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { dur = 210, spread = { dps = 1, dur = 120 } } },
      },
    },
  },

  -- Low-rank bleed reroll seed: level 3 turns a cheap bleed applier into a
  -- small payoff piece without replacing higher-rank bleed carries.
  gnaw_rat = {
    [2] = {
      effects = {
        [1] = { params = { dps = 2, slowPct = 0.10 } },
      },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { slowPct = 0.12, aggravateMult = 1.5 } },
      },
    },
  },

  -- Preserve the old legacy level-scaled shield outputs, but make them
  -- explicit so cards/audits can read the same values the build uses.
  shieldbearer = {
    [2] = {
      effects = {
        [1] = { params = { value = 11 } },
      },
    },
    [3] = {
      effects = {
        [1] = { params = { value = 18 } },
      },
    },
  },

  -- Preserve the old legacy aura scaling explicitly for the poison amplifier.
  miasma_acolyte = {
    [2] = {
      effects = {
        [1] = { params = { inc = 0.90 } },
      },
    },
    [3] = {
      effects = {
        [1] = { params = { inc = 1.50 } },
      },
    },
  },

  -- Fixes the old mismatch: the card/readout implied the granted bleed grew
  -- with source level, while build bake reused the level-1 params.
  clot_mender = {
    [2] = {
      effects = {
        [1] = { params = { dps = 2, slowPct = 0.12 } },
      },
    },
    [3] = {
      effects = {
        [1] = { params = { dps = 3, dur = 210, slowPct = 0.15 } },
      },
    },
  },

  -- grant_team command bonuses did not have a numeric level story. Start with
  -- the vulnerability commandant because it is simple, visible, and bounded.
  corruptor = {
    [2] = {
      effects = {
        [1] = { params = { dps = 3, weaken = 0.08 } },
        [2] = { params = { value = 0.18, dur = 120 } },
      },
      commandBonus = { params = { markEnemiesVuln = 0.15 } },
    },
    [3] = {
      effects = {
        [1] = { params = { dps = 4, weaken = 0.10 } },
        [2] = { params = { value = 0.20, dur = 150 } },
      },
      commandBonus = { params = { markEnemiesVuln = 0.18 } },
    },
  },
}
