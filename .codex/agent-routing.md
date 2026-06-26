# Agent Routing

Use this table to decide which local specialist brief applies. The specialist
briefs are wrapped in `.codex/agents/` and sourced from `.claude/agents/`.

| Task surface | Required wrapper(s) | Notes |
| --- | --- | --- |
| Lua/LÖVE engine, render pipeline, sim integration, determinism, perf | `love2d-engineer.md` | Verify LÖVE/Lua APIs before coding. |
| UI components, buttons, cards, panels, HUD, tooltips, chrome | `ui-artisan.md` | Owns `src/ui/`; preserve stone/rune visual language. |
| Hover, press, drag, juice, transitions, hitstop, shake, fusion choreography | `game-feel-engineer.md` | Co-route with `sound-designer.md`; add `ui-artisan.md` when a visible surface changes. |
| Audio, SFX, ambience, audible cues | `sound-designer.md` | Co-route with `game-feel-engineer.md` for interaction feedback. |
| Procedural creatures, body-plans, masks, rarity, generated visuals | `asset-forge.md` | Owns `src/gen/`; preserve deterministic seeds and append-only RNG order. |
| Core loop, economy, synergies, relics, async snapshots, balance | `autobattler-designer.md` | Use current `CLAUDE.md` as authority when older design docs disagree. |
| Branches, commits, merges, tags, changelog, release/versioning decisions | `git-warden.md` | No push unless explicitly requested by the user. |

## Co-Routing Rules

- Any interaction feedback means movement plus sound: use
  `game-feel-engineer.md` and `sound-designer.md` together.
- Any interaction touching a UI surface also uses `ui-artisan.md`.
- Any game-facing feature with visible presentation should consider
  `game-feel-engineer.md` even when the primary owner is `love2d-engineer.md`.
- If a task spans implementation and design uncertainty, ask
  `autobattler-designer.md` for the spec first, then route implementation.
- If a task touches disjoint files, workers may run in parallel. Give each
  worker a clear write set and remind them not to revert others' changes.

## Codex Sub-Agent Prompt Requirements

Every delegated prompt should include:

- the role wrapper path;
- the source `.claude/agents/<role>.md` path;
- the exact task objective;
- owned files or modules;
- files/modules that must not be edited;
- validation commands expected;
- a reminder that the worktree may contain user edits and must not be reverted.

For read-only investigation, use `explorer`. For bounded code/docs edits, use
`worker`.
