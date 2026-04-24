# The Pit — Claude Code context

> An idle-roguelite delve game. OGame meets Melvor Idle meets PoE Delve, in a terminal UI.

## Read this first

Before touching anything, skim:
- `README.md` — stack, scripts, layout
- `brainstorming/02-game-loop.md` — macro/micro loops, MVP must-ship
- `brainstorming/01-research-needs.md` — open questions classified P0/P1/P2

If a design question is open in `01-research-needs.md`, **don't guess** — ask the user or spawn the `pit-idle-designer` agent to research it.

## Stack (locked)

- **React 19** + **Vite 7** + **TypeScript** — SPA, no SSR
- **TanStack Router** (file-based, codegen at build) + **TanStack Query**
- **Zustand** — local UI state (not game state — that lives on Convex)
- **PixiJS v8** — combat / delve map rendering (imperative, not `@pixi/react`)
- **Motion** — React UI animations
- **Convex** (deployment `aware-goose-251`, eu-west-1) — auth, state, mutations, actions, cron
- **Tailwind v4** — via `@tailwindcss/vite`, everything in `src/index.css` (no config file)
- **Monaspace / JetBrains Mono** — monospace-first terminal aesthetic
- **Vitest** + **Playwright** — unit + e2e

**Do not add** Zustand state that should be on Convex. **Do not introduce** SSR. **Do not install** an additional UI kit (shadcn, Radix) without asking — we're building the terminal kit ourselves.

## Design pillars (locked)

1. **Active Delve is the core.** Offline = flavor (capped, 50% rate). If a design tempts you to make progression happen offline, push back.
2. **Server-authoritative.** The client asks Convex "I want to open node X". The server resolves. No `localStorage.setItem('gold', 1e9)` should ever work.
3. **Terminal UI.** Monospace, box-drawing, limited palette, subtle CRT hints. Think Loop Hero × Warp.dev × Caves of Qud, not Bootstrap.
4. **One boss for now.** Depth over breadth.
5. **Decorrelated from Le Collecteur de Doses.** Same universe, different project. Don't import Collecteur code.

## Open questions (don't decide alone)

See `brainstorming/01-research-needs.md` "Open questions" section. When work touches one, flag it in the PR/commit and ask the user. Current blockers:

- Prestige yes/no
- Descent resource (torches) yes/no
- Card upgrade path (fuse vs +level)
- Pixel sprites yes/no
- Offline cap & rate exact values
- Tick frequency
- Boss identity

## Directory layout

```
src/
  routes/           TanStack Router file-based. Add route = create file.
                    Regenerate tree: npm run routes:gen
  game/             Pure game logic (engine, RNG, formulas). No React, no Convex imports here.
  components/       React components. Keep them small. Pixi mounts via imperative ref.
  stores/           Zustand — UI state ONLY (modals, animation triggers, etc.)
  pixi/             PixiJS renderers. One class per renderer.
  lib/              Generic utilities.

convex/
  schema.ts         Single source of truth for DB shape. Indexes over filters.
  _generated/       Auto, do not edit, gitignored.
  <domain>.ts       Mutations/queries/actions grouped by domain (players.ts, saves.ts...).

brainstorming/
  01-research-needs.md
  02-game-loop.md
  research/         Research notes (one file per P0 item). Format: see 01's tail.
```

## Conventions

### React
- Function components only.
- No default exports except when required by TanStack Router (route files).
- Prefer colocated files: `Foo.tsx`, `Foo.test.tsx`, `Foo.module.css` if needed.
- No prop-drilling past 2 levels — lift to Zustand or a route context.
- Errors/loading: rely on TanStack Router's `pendingComponent` / `errorComponent`, don't hand-roll.

### Convex
- **Queries** for reads (reactive, cheap). **Mutations** for writes (transactional). **Actions** for anything with side effects (offline simulation, external APIs).
- Validate all arguments with `v.*` — no `v.any()` outside prototyping.
- Use indexes; never `.filter()` a full table scan in prod code.
- Server-authoritative: the client passes **intent**, the server resolves + returns the diff.

### TypeScript
- `strict: true`, `noUnusedLocals`, `noUnusedParameters` are on.
- `erasableSyntaxOnly: true` — no enums (use `as const` unions), no parameter properties.
- `verbatimModuleSyntax: true` — use `import type` where applicable.
- `any` needs a comment explaining why.

### Styles
- Tailwind v4 utility-first. Custom tokens live in `@theme {}` in `src/index.css`.
- Component-specific layout rules: inline Tailwind. Truly reusable tokens: theme variables.
- No global selectors except `html/body/#root`.

### Terminal aesthetic
- Monospace is the default. If you reach for a proportional font, justify it.
- Box-drawing characters (`─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼ ═ ║ ╔ ╗ ╚ ╝`) for containers over borders, when it fits.
- Palette tokens live in `@theme`. Stick to `pit-ink`, `pit-bone`, `pit-dim`, `pit-green`, `pit-amber`, `pit-red`, `pit-violet`. Adding a color = ask.
- Animations: prefer linear/step easings for UI, stay away from springs and bounces. That's the "wrong app" vibe.

### Tests
- Unit test pure game logic in `src/game/`. Don't unit test React render trees.
- Playwright for critical flows only (login, first delve, camp shop). Not for every component.

### Commits
- Present-tense, imperative, lowercase: `feat: add depth scaling formula`, `fix(convex): validate delve intent`.
- Keep subject <72 chars. Wrap body at 80.
- No "WIP" on main.

## Workflow

1. **Design question touching an open item** → spawn `pit-idle-designer` to research, write a note to `brainstorming/research/`, flag for user review.
2. **New gameplay feature** → write pure logic in `src/game/` first, test it, then wire UI.
3. **New Convex table or mutation** → update `convex/schema.ts`, add the mutation, regenerate types (`npm run convex:dev` does this live).
4. **New route** → create file in `src/routes/`, `npm run routes:gen` generates the tree (dev server does this automatically).
5. **Before commit** → `npm run typecheck && npm test && npm run build`. Don't skip.

## When to defer to agents

- **Economy / progression math** → `pit-idle-designer`
- **Combat engine, determinism, RNG** → `pit-combat-engineer`
- **Delve map procgen, node variety** → `pit-delve-cartographer`
- **Terminal UI, typography, palette** → `pit-terminal-ux`
- **Convex schema, server-authoritative patterns, anti-cheat** → `pit-convex-architect`
- **Loot tables, drop rates, pity** → `pit-loot-tuner`

Each agent is in `.claude/agents/`. Spawn with `Agent(subagent_type: "pit-*")`.

## Research skill

Use `/research-note <topic>` to scaffold a new research note in `brainstorming/research/`. Fill it with findings (Exa MCP preferred for web research — see global CLAUDE.md).

## Do not

- Do not re-enable SSR.
- Do not add Tailwind plugins or a config file — v4 config is in CSS.
- Do not install a component library.
- Do not write game state to `localStorage` (dev-only scratch pads are fine).
- Do not read the Collecteur codebase for ideas without asking; they're different projects.
- Do not add emojis to source or commits unless the user asks.
