# Commanders - current implementation note

Status: active short note. The old implementation plan was removed after the
feature landed.

Current implementation:

- commander pedestal is a run/build feature;
- a commander is injected as an untargetable comp spec;
- command bonuses are data on units: `commandBonus = { trigger, op, target?,
  params }`;
- build/snapshot code must use `UnitResolver.commandBonusFor(id, level)`;
- command score is measured by `src/lab/coherence.lua`.

Current design:

- every unit can command;
- command text should be clear and not duplicate the `COMMAND` tag;
- command tags are only public in command context;
- command effects should reinforce a readable plan, not become a hidden global
  stat soup.

Relevant tests:

```sh
luajit tests/commanders.lua
luajit tests/coherence.lua
luajit tests/unit_resolver.lua
```
