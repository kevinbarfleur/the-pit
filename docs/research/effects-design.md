# Effects - current design note

Status: active short note. The old multi-document effects proposal was removed
after implementation.

Current effect model:

- effects are data: `{ trigger, op, target?, params }`;
- ops live in `src/effects/ops.lua`;
- combat state lives in `src/combat/arena.lua`;
- derived tags live in `src/core/tags.lua`;
- card wording is generated through mechanics text helpers, not manually
  rewritten prose.

Core families:

- `Poison`: stacking damage plus utility such as weaken/spread.
- `Burn`: high damage over time, propagation/no-decay variants.
- `Bleed`: damage plus attack-speed slow/aggravate variants.
- `Rot`: growth/max-HP pressure.
- `Shock`: charge/discharge and chain variants.
- `Shield`: defensive pool, aura/caster/payoff variants.

Current balance rule:

- the text must tell the same mechanical truth as the op;
- values can be tuned, but naming must stay canonical;
- hidden whispers must not leak into public cards/glossary.

Validation:

```sh
luajit tests/synergies.lua
luajit tests/effect_audit.lua
luajit tests/tags.lua
luajit tools/sim.lua mechanics
```

Mechanic diversity audit:

- `tools/sim.lua mechanics` writes `runs/report-mechanics.json`.
- Current baseline after the Batodex/SAP bridge and redesign-first level-up
  passes: `33/110` units are still simple-affliction at level 1, `0/110` are
  low-variety, `68/110` have authored level ability deltas, and `28/110` have
  level-3 clutch flags.
- `recommendations.redesign_first` should now remain empty. The next creature
  pass should use simulation outcomes, coherence gaps, or economic accessibility
  instead of batch-fixing low-variety cards.

Inspiration rule:

- Start from `docs/inspiration/batodex/design-taxonomy.json` for creature
  effect inspiration; open the full JSON files only when needed.
- Batodex and SAP are the primary references: compact triggers, clear level
  scaling, and one positional/support idea at a time.
- The Bazaar is allowed for occasional rare/high-tier spice, but not as the
  baseline complexity model for the roster.
