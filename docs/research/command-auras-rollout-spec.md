# Command auras - current compatibility note

Status: active short note. The old rollout plan was removed after landing.

Current state:

- every roster unit has a `commandBonus`;
- tests expect all `Units.order` entries to command;
- command effects are resolved through `UnitResolver.commandBonusFor(id, level)`;
- command tags are contextual and should not appear on normal board cards;
- command level scaling can be authored in `src/data/unit_levels.lua`.

Valid command ops:

- `aura_stat`: build-resolved stat aura;
- `grant_team`: team flag or transform consumed at combat start.

Important constraints:

- commandants are outside the board graph;
- `neighbors` is not a useful command target unless a new rule explicitly
  defines how a pedestal has neighbors;
- commandants are untargetable in combat;
- command effects must remain deterministic and snapshot-safe.

Validation:

```sh
luajit tests/commanders.lua
luajit tests/unit_resolver.lua
luajit tests/effect_audit.lua
sh tools/check.sh
```

For design/balance work, use:

- `../../CLAUDE.md`
- `intensive-simulation-balance-program-HANDOFF.md`
- `src/lab/coherence.lua`
