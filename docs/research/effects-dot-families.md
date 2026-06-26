# Affliction families - current short reference

Status: active short note. The old research draft was removed.

Canonical public families:

- `Poison`
- `Burn`
- `Bleed`
- `Rot`
- `Shock`

Rules:

- Use the canonical family name every time. Do not write flavorful synonyms in
  mechanical text.
- If a card says a family name, the icon/color/glossary entry must match it.
- A 0-dps affliction must carry clear utility wording, such as slow/weaken.
- Family-specific transforms such as propagate, contagion, conversion or
  aggravate are separate tags and should be visible when they matter.

Code/data:

- `src/effects/ops.lua`
- `src/combat/arena.lua`
- `src/data/units.lua`
- `src/core/tags.lua`
- `src/core/unit_resolver.lua`

Validation:

```sh
luajit tests/dot_family.lua
luajit tests/synergies.lua
luajit tests/effect_audit.lua
```
