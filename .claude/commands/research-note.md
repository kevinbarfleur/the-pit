---
description: Scaffold a research note in brainstorming/research/ for an open question
argument-hint: <slug>
---

Create a new research note at `brainstorming/research/$ARGUMENTS.md`.

1. First, check `brainstorming/01-research-needs.md` to find the matching research item. If the slug doesn't correspond to an item, ask the user which item it maps to.

2. Use Exa MCP tools for research:
   - `mcp__exa__web_search_exa` for general design questions
   - `mcp__exa__get_code_context_exa` for technical API/library questions
   - `mcp__exa__deep_search_exa` for deeper synthesis

3. Write the note with this structure:

```markdown
# <Title>

> Item: <A1 / B3 / etc. from 01-research-needs.md>
> Priority: <P0 / P1 / P2>
> Date: <YYYY-MM-DD>

## Question

<The specific question this note is answering.>

## Sources

- [Source 1](url) — short description
- [Source 2](url) — short description

## Findings

### Finding 1
<1-2 paragraphs>

### Finding 2
<1-2 paragraphs>

## Comparison table

| System / Game | Approach | Outcome |
|---|---|---|
| ... | ... | ... |

## Recommendation for The Pit

<Concrete proposal with numbers. What do we do, with what values, and why.>

## Risks & open sub-questions

- <Risk 1>
- <Sub-question to answer later>
```

4. After writing, report back: the file path, 3 bullet takeaways, and whether this resolves the open question or needs user input.
