# Codex Wrapper: love2d-engineer

Source brief: `.claude/agents/love2d-engineer.md`

Use this wrapper for Lua/LÖVE implementation, refactors, debugging, rendering,
combat integration, determinism, performance, packaging, and API review.

Before acting, read:

1. `CLAUDE.md`
2. `.codex/agent-routing.md`
3. `.claude/agents/love2d-engineer.md`
4. the touched source and tests

Codex-specific rules:

- Treat `CLAUDE.md` as newer authority when it disagrees with the source brief.
- Verify LÖVE 11.5 and Lua 5.1/LuaJIT APIs on primary sources before coding.
- Keep SIM modules pure: no `love.graphics`, no audio, no wall-clock time, no
  global `math.random`, and no order-sensitive `pairs`.
- Preserve existing user edits in the dirty worktree.
- Prefer focused tests. Use `luajit -bl <file>` for syntax when useful, then
  the narrow test, then `sh tools/check.sh` for a completed increment.

Delegation note:

When spawning a Codex worker, give it a disjoint file/module ownership set and
tell it to list changed paths in its final response.
