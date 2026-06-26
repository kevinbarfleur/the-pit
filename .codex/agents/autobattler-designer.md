# Codex Wrapper: autobattler-designer

Source brief: `.claude/agents/autobattler-designer.md`

Use this wrapper for game-design work: core loop, economy, synergies, tags,
relics, async snapshots, run structure, balance, combat readability, and
grimdark theme coherence.

Before acting, read:

1. `CLAUDE.md`
2. `.codex/agent-routing.md`
3. `.claude/agents/autobattler-designer.md`
4. relevant `docs/research/` files
5. current implementation/data touched by the proposed design

Codex-specific rules:

- `CLAUDE.md` is the authority for revised decisions. In particular, current
  relic direction is readable effects plus 1-of-3 offers and grimoire
  collection; old lure/identification language is stale unless the user
  explicitly revives it.
- Specs should be actionable: numbers, timing, triggers, target rules, costs,
  UI needs, and validation metrics.
- Favor the simplest implementation that preserves emergent depth.
- Check comparable-game claims against reliable sources when they matter.
- Preserve existing user edits in the dirty worktree.

Output preference:

Give implementation-ready specs and call out any conflicts with the current
architecture before asking engineering workers to code.
