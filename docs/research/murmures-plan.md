# Murmures - hidden affinity layer

Status: active short note. The old long plan was removed.

Murmures are a hidden spice layer, not public build text.

Rules:

- `src/data/whispers.lua` stays declarative: no functions, no RNG, no `love.*`;
- resolver logic lives in `src/effects/whispers_ops.lua`;
- whispers may appear in oblique combat/chronicle feedback;
- whisper tags must not appear in public card tags/glossary unless a dev/debug
  context explicitly asks for hidden data;
- whispers should not become build-defining or required for coherence scoring.

Validation:

```sh
luajit tests/murmures.lua
luajit tests/effect_audit.lua
sh tools/check.sh
```
