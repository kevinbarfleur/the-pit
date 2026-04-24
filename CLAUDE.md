# The Pit — Claude Code context

> An idle-roguelite delve game. OGame meets Melvor Idle meets PoE Delve, in a terminal UI.

## Read this first

Before touching anything, skim:
- `README.md` — stack, scripts, layout
- `brainstorming/02-game-loop.md` — macro/micro loops, MVP must-ship
- `brainstorming/01-research-needs.md` — research priorities (P0/P1/P2)
- **`brainstorming/research_codex/00-p0-decision-index.md`** — locked P0 decisions from researcher #1

If a design decision is listed in the index → **follow it**. Don't re-litigate. If the topic is outside the index → ask user or spawn the relevant agent.

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

1. **Active Delve is the core.** Offline = flavor (8h cap, 25% rate, no depth, no boss, no rare/T0 first drops). If a design tempts you to make progression happen offline, push back.
2. **Server-authoritative.** The client sends intents. The server resolves. No `localStorage.setItem('gold', 1e9)` should ever work.
3. **Deterministic simulation.** 4Hz fixed tick, `pure-rand` multi-streams, integer/basis-point math. Same seed + same actions → identical snapshot.
4. **Terminal UI.** Hybrid — DOM/React for most, Pixi for combat. Monospace, box-drawing, limited palette, 14px body floor.
5. **One boss for now.** Depth over breadth. Working name: The Pit Warden.
6. **Decorrelated from Le Collecteur de Doses.** Same universe, different project. Don't import Collecteur code.

## P0 decisions (locked) — from `brainstorming/research_codex/`

| Question | Decision |
|---|---|
| **Prestige V1** | No. Schema hooks only: `seasonStats`, `legacyBonuses`, `resetCount = 0` |
| **Descent resource** | Yes — `torch`. Gates deep active runs, not casual check-ins |
| **Card upgrade path** | Store duplicates as `shards` from day 1. Fuse-to-level ships later without migration |
| **Terminal aesthetic** | Hybrid — DOM/React for UI, Pixi for combat. ASCII containers + 32/48px sprites |
| **Offline** | Cap 8h, rate 25% of active baseline. Common shards only. No depth/boss/rare/T0 first drops |
| **Tick frequency** | **4Hz** (250ms). No 10Hz. Render at rAF. No Convex writes per tick |
| **Boss identity** | Original — working name `The Pit Warden` or `The First Auditor`. No borrowed PoE names |
| **RNG library** | `pure-rand` (pure, immutable). Multi-stream: `combatRng`, `lootRng`, `mapRng`, `eventRng` |
| **Integer math** | Basis points (10000 = 100%) for all durable probabilities and meters |
| **Tagline** | *An idle roguelite where every descent writes your economy* |

Full context in `brainstorming/research_codex/00-p0-decision-index.md` and the per-item notes.

## Still open (ask user / spawn agents)

- Exact cost ratios per category (A1 frames the ranges: 1.07-1.10 / 1.13-1.17 / 1.22-1.30)
- Starter deck composition (8 T3 cards, TBD)
- Sound / audio direction (E3, P2)
- Co-op / async social features (F3, P2)
- CRT phosphor intensity (D6, P1)
- Saison 1 boss kit (once Pit Warden is drafted)

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

### Tests (non-negotiable for gameplay code)

RPG affix systems bug in **interactions**, not single effects. We use a layered strategy:

| Layer | Tool | Where |
|---|---|---|
| Unit (happy path + edges) | Vitest | Every pure function in `src/game/` |
| **Property-based** | **fast-check** | Every formula with > 2 inputs. Every keyword interaction. |
| Invariant (full sim) | Vitest | Engine rules (HP ≥ 0, meter ∈ [0, 10000], resources conserved) |
| Fuzz | fast-check 10k+ | Nightly / pre-release |
| Snapshot | Vitest | Reference scenarios (boss fight, run to D10) |
| Re-simulation | Vitest | Client/server parity |
| Regression | Vitest | Every bug → red test first, then fix |

**Rules**:
- **fast-check for any formula with > 2 inputs.** Humans don't think of edge cases; property tests do.
- Don't unit test React render trees.
- Playwright for critical flows only (login, first delve, camp shop).
- A bug found = a test written first. Then the fix.
- Every `skip()` needs a GitHub issue + dated TODO.

Always spawn **`pit-test-engineer`** when adding game logic. It writes the test plan *before* the code.

### Commits
- Present-tense, imperative, lowercase: `feat(combat): add keyword interaction table`, `fix(convex): reject mutations with stale stateVersion`.
- Scope is optional but useful: `combat`, `delve`, `convex`, `ux`, `rng`, `loot`, etc.
- Keep subject <72 chars. Wrap body at 80.
- No "WIP" on dev or main. No `--amend` after push unless branch is personal.
- No `--no-verify` without explicit user approval.

## Branch workflow (locked)

```
main      ← stable only. PRs from dev only. Tagged releases.
 └── dev  ← integration. Default branch for all new work today.
      ├── feature/<slug>    e.g. feature/delve-map-renderer
      ├── fix/<slug>        e.g. fix/combat-tick-drift
      └── refactor/<slug>   e.g. refactor/rng-streams
```

**Rules**:
- **Never commit to `main` directly.** Even a one-line fix goes through dev → main.
- **Pre-MVP phase**: we work mostly on `dev`. Feature branches once we split gameplay by domain.
- **Feature branches are short-lived** (< 5 days ideally). Split if longer.
- **Merge dev → main** only when dev is clean: 0 skip, 0 URGENT TODO, typecheck + test + build + Playwright smoke pass.
- Prefer rebase on personal branches, merge-commits into dev/main for traceability.

When in doubt, spawn **`pit-workflow-orchestrator`** — it has the exact procedures and checklists.

## Workflow (per task)

1. **Design question touching a P0 decision** → follow the decision. Don't re-litigate.
2. **Design question in "Still open"** → ask user or spawn the relevant `pit-*` agent to research. Output goes to `brainstorming/research/`.
3. **New gameplay feature** → spawn `pit-test-engineer` for the plan, write pure logic in `src/game/` with tests, then wire UI.
4. **New Convex table/mutation** → update `convex/schema.ts`, add the mutation with `actionId`/`stateVersion` guards, `npm run convex:dev` regenerates types.
5. **New route** → `/new-route <path>` or create manually, then `npm run routes:gen`.
6. **Before commit** → `npm run typecheck && npm test && npm run build`. Non-negotiable.
7. **PR** → `feature/*` → `dev`. Use the workflow orchestrator's PR template.

## When to defer to agents

- **Economy / progression math** → `pit-idle-designer`
- **Combat engine, determinism, RNG** → `pit-combat-engineer`
- **Delve map procgen, node variety** → `pit-delve-cartographer`
- **Terminal UI, typography, palette** → `pit-terminal-ux`
- **Convex schema, server-authoritative patterns, anti-cheat** → `pit-convex-architect`
- **Loot tables, drop rates, pity** → `pit-loot-tuner`
- **Test strategy, property-based, affix interactions** → `pit-test-engineer`
- **Git workflow, branches, PRs, releases** → `pit-workflow-orchestrator`

Each agent is in `.claude/agents/`. Spawn with `Agent(subagent_type: "pit-*")`.

Convex-specific skills (from `npx convex ai-files install`) live in `.agents/skills/` — read `AGENTS.md` for the convex guardrails.

## Research

Researcher #1 (Codex pass) delivered the P0 batch in `brainstorming/research_codex/`. Treat those notes as authoritative for the decisions listed above. A researcher #2 pass is expected to refine P1 items.

Use `/research-note <slug>` to scaffold a new note in `brainstorming/research/`. Fill it with findings (Exa MCP preferred — see global CLAUDE.md).

## Do not

- Do not re-enable SSR.
- Do not add Tailwind plugins or a config file — v4 config is in CSS.
- Do not install a component library.
- Do not write game state to `localStorage` (dev-only scratch pads are fine).
- Do not read the Collecteur codebase for ideas without asking; they're different projects.
- Do not add emojis to source or commits unless the user asks.
