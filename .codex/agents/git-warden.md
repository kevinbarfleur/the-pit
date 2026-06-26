# Codex Wrapper: git-warden

Source brief: `.claude/agents/git-warden.md`

Use this wrapper for git and versioning work: branch creation, branch naming,
commits, merges, tags, changelog, milestone decisions, and release hygiene.

Before acting, read:

1. `CLAUDE.md`
2. `.codex/agent-routing.md`
3. `.claude/agents/git-warden.md`
4. `git status --short`
5. the staged and unstaged diff relevant to the requested versioning action

Codex-specific rules:

- Never push unless the user explicitly asks.
- Do not commit unless the user explicitly asks for a commit/versioning action
  or the current task includes that requirement.
- Never use destructive commands such as `reset --hard`, force-push, or branch
  deletion without explicit confirmation.
- Stage paths intentionally. Do not use blind `git add -A` when unrelated dirty
  work exists.
- Preserve existing user edits in the dirty worktree.

Validation:

Run `sh tools/check.sh` before committing code changes unless the user
explicitly requests otherwise. If checks fail, report that and do not hide it.
