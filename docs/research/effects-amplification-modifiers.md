# Effects amplification and stat modifiers

Status: active short note. The old research draft was removed.

Source of truth:

- `src/effects/stats.lua`

Modifier model:

```text
final = (base + sum(flat)) * (1 + sum(increased)) * product(1 + more)
```

Reasons:

- `increased` values are additive and order-independent;
- this keeps the simulation deterministic without sorting;
- caps live at the consuming mechanic, not in arbitrary card prose.

Used by:

- attack modifiers;
- affliction amplifiers such as poison/burn/bleed/rot increases;
- vulnerability and damage reduction;
- build-resolved stat increases.

Validation:

```sh
luajit tests/stats.lua
luajit tests/synergies.lua
```
