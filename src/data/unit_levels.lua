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

  -- Low-rank rot seed: level-ups make the tank-counter identity show up
  -- before the late-game rot package is complete.
  rot_hound = {
    [2] = {
      effects = {
        [1] = { params = { base = 3, growth = 3, capDps = 12 } },
      },
      commandBonus = { params = { value = 0.22 } },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { base = 4, growth = 4, capDps = 14, maxHpFrac = 0.20, passiveRamp = 1 } },
      },
      commandBonus = { params = { value = 0.26 } },
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
      commandBonus = { params = { value = 0.22 } },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { dps = 3, dur = 240, slowPct = 0.15 } },
      },
      commandBonus = { params = { value = 0.26 } },
    },
  },

  -- Low-rank rot reroll bridge: the fast, low-cap opener should remain
  -- relevant long enough to bridge into the bleed->rot package.
  carrion_pecker = {
    [2] = {
      effects = {
        [1] = { params = { base = 3, capDps = 7, maxHpFrac = 0.12 } },
        [2] = { params = { value = 5 } },
      },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { base = 3, growth = 3, dur = 210, capDps = 8, maxHpFrac = 0.14, passiveRamp = 1 } },
        [2] = { params = { value = 6 } },
      },
    },
  },

  decay_tender = {
    [2] = {
      effects = {
        [1] = { params = { bonus = 2 } },
      },
    },
    [3] = {
      effects = {
        [1] = { params = { bonus = 3 } },
      },
    },
  },

  necro_leech = {
    [2] = {
      effects = {
        [1] = { params = { base = 3, growth = 3, maxHpFrac = 0.40 } },
      },
    },
    [3] = {
      effects = {
        [1] = { params = { base = 4, growth = 4, maxHpFrac = 0.45 } },
      },
    },
  },

  -- Cross-family payoff: when a player levels the bleed->rot pivot, the
  -- conversion must become a real late-game reward instead of only a stat stick.
  marrow_drinker = {
    [2] = {
      effects = {
        [1] = { params = { base = 4, growth = 3, capDps = 14 } },
      },
    },
    [3] = {
      effects = {
        [1] = { params = { base = 5, growth = 4, capDps = 16 } },
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

  -- Low-rank bruiser reroll: keeps the "first bite + execute" identity, but
  -- makes a level-3 marauder a real cheap finisher instead of a pure stat bag.
  marauder = {
    [2] = {
      effects = {
        [1] = { params = { value = 10 } },
        [2] = { params = { threshold = 0.27, bonus = 0.70 } },
      },
      commandBonus = { params = { value = 0.14 } },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { value = 13 } },
        [2] = { params = { threshold = 0.30, bonus = 0.80 } },
      },
      commandBonus = { params = { value = 0.16 } },
    },
  },

  -- Low-rank thorns reroll: a cheap skeleton wall should become a deliberate
  -- anti-fast-attack plan at level 3 without invalidating real tanks.
  skeleton = {
    [2] = {
      effects = {
        [1] = { params = { value = 4 } },
      },
      commandBonus = { params = { value = 0.06 } },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { value = 6 } },
      },
      commandBonus = { params = { value = 0.08 } },
    },
  },

  -- Low-rank sustain reroll: the demon's lure/sustain identity should scale
  -- as a clutch bruiser when tripled, not only through HP.
  demon = {
    [2] = {
      effects = {
        [1] = { params = { frac = 0.45 } },
      },
      commandBonus = { params = { value = 0.06 } },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { frac = 0.55 } },
      },
      commandBonus = { params = { value = 0.08 } },
    },
  },

  -- Low-rank burn reroll: ash_moth remains fragile, but a level-3 copy keeps
  -- its ember alive long enough to support early burn boards.
  ash_moth = {
    [2] = {
      effects = {
        [1] = { params = { dps = 8, dur = 135, decayPct = 0.40 } },
      },
      commandBonus = { params = { value = 0.05 } },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { dps = 9, dur = 150, decayPct = 0.35 } },
      },
      commandBonus = { params = { value = 0.06 } },
    },
  },

  -- Low-rank shock reroll: live_wire is the fast stacker; level 3 turns it
  -- into a meaningful shock opener without granting rare chain/transfer.
  live_wire = {
    [2] = {
      effects = {
        [1] = { params = { cap = 6, dur = 150 } },
      },
      commandBonus = { params = { value = 0.06 } },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { add = 2, cap = 7, dur = 180 } },
      },
      commandBonus = { params = { value = 0.07 } },
    },
  },

  cinder_cur = {
    [2] = {
      effects = {
        [1] = { params = { dps = 5, dur = 135 } },
      },
      commandBonus = { params = { value = 0.07 } },
    },
    [3] = {
      effects = {
        [1] = { params = { dps = 6, dur = 150 } },
      },
      commandBonus = { params = { value = 0.08 } },
    },
  },

  bore_worm = {
    [2] = {
      effects = {
        [1] = { params = { base = 3, growth = 2, capDps = 9 } },
      },
      commandBonus = { params = { value = 0.07 } },
    },
    [3] = {
      clutch = true,
      effects = {
        [1] = { params = { base = 3, growth = 3, dur = 240, capDps = 11, maxHpFrac = 0.14 } },
      },
      commandBonus = { params = { value = 0.08 } },
    },
  },

  byakhee = {
    [2] = {
      effects = {
        [1] = { params = { dps = 4, dur = 200, slowPct = 0.12 } },
      },
      commandBonus = { params = { value = 0.07 } },
    },
    [3] = {
      effects = {
        [1] = { params = { dps = 5, dur = 210, slowPct = 0.15 } },
      },
      commandBonus = { params = { value = 0.08 } },
    },
  },

  chitin_drone = {
    [2] = {
      effects = {
        [1] = { params = { dps = 3, dur = 180 } },
      },
      commandBonus = { params = { value = 0.08 } },
    },
    [3] = {
      effects = {
        [1] = { params = { dps = 3, dur = 210, weaken = 0.05 } },
      },
      commandBonus = { params = { value = 0.09 } },
    },
  },
}
