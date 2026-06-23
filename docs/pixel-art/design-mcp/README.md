# design-mcp/ — raw design reference

**Intended source:** the user's claude.ai/design project `5dfa15b4-13af-4fad-b876-82559af188de`,
files `The Pit - Design System.dc.html`, `Interface Board.dc.html`, `The Pit.dc.html`, `Forge UI.dc.html`,
fetched via the **DesignSync MCP** (`get_file`).

**What actually happened (2026-06-23):** the DesignSync MCP server was **not connected** to the
extraction session — `ToolSearch` found no `DesignSync` / `get_file` tool (only claude.ai
Supabase/Vercel/Notion/Slack/Gmail/Calendar/Drive + Exa + Chrome DevTools). The four `.dc.html`
files therefore **could not be fetched fresh**.

**Substitute used:** a previously-saved export of the canonical design-system document was already
on disk at `../design-system-source.html` and is a **superset** of the four target files — it holds
Sections I–VI (Color / Typography / Iconography / Atoms / Molecules / Organisms) **plus** the full
organism mockups for **BUILD, COMBAT, GRIMOIRE, RELIC PICK** (`data-screen-label` blocks). All design
tokens are inline (no base64). That file is mirrored here as
`The Pit - Design System (local export).dc.html` for raw grep/reference.

The distilled spec derived from it lives at `../design-system-spec-v2.md`
(and the earlier pass at `../design-system-spec.md`).
