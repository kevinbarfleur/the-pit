# Codex Worker Prompt Template

Use this template when spawning a Codex `worker` for The Pit.

```text
You are working in /Users/kevinbarfleur/Github/the-pit.

Role wrapper to follow:
- .codex/agents/<role>.md

Source specialist brief to read completely before acting:
- .claude/agents/<role>.md

Project context to read first:
- AGENTS.md
- CLAUDE.md
- .codex/agent-routing.md

Task:
<one concrete objective>

Owned write set:
- <files or directories the worker may edit>

Do not edit:
- <files or directories owned by another worker/main agent>

Important:
- The worktree may already contain user or other-agent edits. Do not revert
  them. If they affect your task, adapt to them.
- Search existing code before implementing.
- Verify relevant LÖVE/Lua APIs on primary sources before relying on them.
- Keep changes scoped to the owned write set.
- Preserve SIM/RENDER/audio determinism boundaries from CLAUDE.md.

Validation expected:
- <focused command>
- <sh tools/check.sh if this is a finished code increment>

Final response:
- summarize the change;
- list changed paths;
- list validation commands and results;
- call out any remaining visual/audio/user-review needs.
```
