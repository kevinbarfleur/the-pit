# Codex Wrapper: game-feel-engineer

Source brief: `.claude/agents/game-feel-engineer.md`

Use this wrapper for juice, hover/press/drag feedback, screen shake, hitstop,
number rolls, transitions, modals, level-up/fusion choreography, and the Feel or
Juice layers.

Before acting, read:

1. `CLAUDE.md`
2. `.codex/agent-routing.md`
3. `.claude/agents/game-feel-engineer.md`
4. the Feel Lab files relevant to the task
5. the touched game UI/render files

Codex-specific rules:

- Feedback work co-routes with `.codex/agents/sound-designer.md`.
- If a visible UI surface changes, also use `.codex/agents/ui-artisan.md`.
- Keep game feel render/cosmetic only. Do not mutate SIM state or golden logs.
- Drive feel from wall-clock/render dt, not simulation time.
- Capture with `--shoot` when possible. If visual validation cannot run, state
  exactly which headless checks ran and what remains for in-game review.
- Preserve existing user edits in the dirty worktree.

Delegation note:

For a large interaction feature, split work by write set: e.g. feel engine,
audio cues, and UI surface integration. Do not let multiple workers edit the
same files unless the main agent explicitly integrates the results.
