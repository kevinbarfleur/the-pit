# Codex Explorer Prompt Template

Use this template when spawning a Codex `explorer` for a read-only question in
The Pit.

```text
You are working in /Users/kevinbarfleur/Github/the-pit.

Read first:
- AGENTS.md
- CLAUDE.md
- .codex/agent-routing.md
- .codex/agents/<role>.md
- .claude/agents/<role>.md

Question:
<specific codebase question>

Scope:
- <files/directories to inspect>

Do not edit files.

Return:
- concise answer;
- exact file/line references where possible;
- risks or conflicts with CLAUDE.md;
- recommended next implementation step, if any.
```
