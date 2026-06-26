# Codex Agent Layer

This directory adapts The Pit's Claude Code agents for Codex.

The source-of-truth specialist briefs stay in `.claude/agents/`. The files in
`.codex/agents/` are wrappers that tell Codex workers and explorers which Claude
brief to read, how to resolve conflicts, and what validation is expected.

Typical flow:

1. Main Codex reads `AGENTS.md`, `CLAUDE.md`, and `.codex/agent-routing.md`.
2. Main Codex selects the relevant wrapper from `.codex/agents/`.
3. If delegation is authorized, main Codex spawns a `worker` or `explorer` with
   `.codex/prompts/worker-template.md` or `.codex/prompts/explorer-template.md`.
4. The sub-agent reads the wrapper, the linked `.claude/agents/*.md` brief, and
   the touched code before acting.

This avoids duplicating the full agent instructions while keeping Codex-specific
orchestration explicit.
