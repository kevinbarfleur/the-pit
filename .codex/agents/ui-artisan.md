# Codex Wrapper: ui-artisan

Source brief: `.claude/agents/ui-artisan.md`

Use this wrapper for UI components and interface integration: frame system,
buttons, panels, cards, tooltips, keyword chips, HUD, build/shop/combat chrome,
relic UI, and codex/grimoire screens.

Before acting, read:

1. `CLAUDE.md`
2. `.codex/agent-routing.md`
3. `.claude/agents/ui-artisan.md`
4. relevant `src/ui/` modules and scene call sites
5. relevant docs in `docs/research/` or `docs/pixel-art/`

Codex-specific rules:

- Preserve the stone/rune UI language and existing theme helpers.
- Do not create duplicate UI systems when `Frame`, `Draw`, `Theme`, `Chip`, or
  `Keywords` can be extended.
- All displayed text must use i18n.
- UI is render-side; do not mutate SIM modules for presentation work.
- Interaction UI co-routes with `game-feel-engineer.md` and `sound-designer.md`.
- Capture with `--shoot` when possible and inspect the result before calling a
  visual task done.
- Preserve existing user edits in the dirty worktree.

Validation:

Run focused Lua syntax/test checks and `sh tools/check.sh` for finished work. If
visual validation is blocked, leave concrete launch/check instructions.
