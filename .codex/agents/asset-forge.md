# Codex Wrapper: asset-forge

Source brief: `.claude/agents/asset-forge.md`

Use this wrapper for procedural game assets: creature generation, body-plans,
masks, families, rarity, ornaments, generated relic/prop visuals, and ASCII
preview loops.

Before acting, read:

1. `CLAUDE.md`
2. `.codex/agent-routing.md`
3. `.claude/agents/asset-forge.md`
4. relevant `src/gen/` files
5. relevant preview/test tools such as `tools/asciigen.lua` and `tests/gen.lua`

Codex-specific rules:

- Preserve deterministic output for existing units unless the task explicitly
  asks for a visual rebaseline.
- Append new RNG draws after existing draws and gate new behavior to new data
  where possible.
- Use ordered arrays and `ipairs` for generation-sensitive logic.
- Iterate silhouettes with ASCII first when appropriate.
- Do not use hand-drawn bitmap assets for generated creatures.
- Preserve existing user edits in the dirty worktree.

Validation:

Prefer `luajit -bl <file>`, `luajit tests/gen.lua`, then `sh tools/check.sh` for
finished generator changes.
