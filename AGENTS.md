# The Pit - Codex agent contract

This file is the Codex entrypoint for this repository. It does not replace
`CLAUDE.md`: it tells Codex how to use the existing Claude Code project briefs
and specialist agents.

## Source Order

Before any substantial task, read:

1. `CLAUDE.md`
2. `.codex/agent-routing.md`
3. the relevant `.codex/agents/<role>.md` wrapper
4. the source brief referenced by that wrapper in `.claude/agents/`
5. the local code and docs touched by the task

Priority when documents disagree:

1. the latest explicit user instruction in the active conversation
2. this `AGENTS.md` for Codex-specific orchestration
3. the current `CLAUDE.md` project brief
4. `.claude/agents/*.md` specialist briefs
5. older research docs and implementation notes

If a specialist brief conflicts with a newer explicit decision in `CLAUDE.md`,
follow `CLAUDE.md` and call out the conflict briefly. Known example: relics were
revised in `CLAUDE.md` to be readable, with lures/identification removed.

## Codex Delegation Model

The repository's named specialists live in `.claude/agents/`. Codex does not
load those as native sub-agent types. Instead:

- use `.codex/agents/*.md` as wrappers for those Claude briefs;
- when sub-agent delegation is available and authorized by the active Codex
  policy or by an explicit user request, spawn a Codex `worker` or `explorer`
  with the relevant wrapper and source brief paths in the prompt;
- when delegation is not authorized or not useful, the main Codex agent applies
  the same specialist brief directly.

Do not invent a new role when a local specialist already owns the domain.
Route tasks through `.codex/agent-routing.md`.

## Non-Negotiables

- Verify LÖVE/Lua APIs on primary sources before relying on them.
- Search the existing code first and reuse local systems instead of rebuilding
  weaker duplicates.
- Preserve deterministic simulation boundaries: no render, audio, wall-clock
  time, or global randomness in SIM modules.
- Preserve user work. The worktree may be dirty; never revert changes you did
  not make.
- For UI, feel, audio, and visual work, the result is not done just because it
  compiles. Capture with `--shoot` when possible and judge the image, or state
  clearly that only headless checks ran.
- Validate the smallest meaningful scope first, then `sh tools/check.sh` for a
  finished code increment.

## Git Discipline

Use `.codex/agents/git-warden.md` for branch, commit, merge, tag, changelog, or
release work. In Codex sessions, do not push. Do not commit unless the user has
asked for versioning work or the current task explicitly includes a commit.
