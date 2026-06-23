# The Pit — Design System Spec v2 (BUILD + COMBAT focus)

> **Source.** Distilled from the local export `docs/pixel-art/design-system-source.html`
> ("Reliquary · Système Visuel · v1"), the canonical design-system mockup. The 4 originally
> named `.dc.html` files (`The Pit - Design System.dc.html`, `Interface Board.dc.html`,
> `The Pit.dc.html`, `Forge UI.dc.html`) were **NOT** fetched — the DesignSync MCP tool is
> unavailable in this session. The local export is a superset of the named design-system file and
> contains full **BUILD** and **COMBAT** organism mockups, so it stands in for them.
>
> All numbers below are read from the inline CSS of that file (line refs in `()`), not invented.
> Companion doc `design-system-spec.md` (v1 "Implementation Bible") covers the same source with a
> component-catalog framing; this v2 is standalone and prioritizes the two screens the user is
> reworking. Consumer = the main agent re-skinning the LÖVE screens — **values are the point**.

---

## A. DESIGN TOKENS

All custom properties live on one root `<div>` (source line 23). LÖVE uses **floats 0..1** — divide
each channel by 255. Roles come from the Section I swatch captions (lines 88–145).

### A.1 — Grounds (the pit's stone) — flat surfaces, darkest→lightest

| Token | Hex | RGB (0..1) | Role |
|---|---|---|---|
| `--void` | `#050308` | 0.020, 0.012, 0.031 | page/abyss base, deepest black |
| `--stone-900` | `#0b0910` | 0.043, 0.035, 0.063 | panel base |
| `--stone-850` | `#100d16` | 0.063, 0.051, 0.086 | **default surface** (most cards/sections) |
| `--stone-800` | `#16121d` | 0.086, 0.071, 0.114 | raised surface / hatch light |
| `--stone-700` | `#1d1826` | 0.114, 0.094, 0.149 | hover surface / empty-pip fill |
| `--stone-600` | `#272031` | 0.153, 0.125, 0.192 | top stone / big section numerals fill |

### A.2 — Inks (bone & parchment) — text, lightest→dimmest

| Token | Hex | RGB (0..1) | Role |
|---|---|---|---|
| `--ink`   | `#ece3ce` | 0.925, 0.890, 0.808 | **primary text**, values, names |
| `--ink-2` | `#c3b89e` | 0.765, 0.722, 0.620 | body / secondary text |
| `--ink-3` | `#8d8270` | 0.553, 0.510, 0.439 | muted labels, captions |
| `--ink-4` | `#5d544a` | 0.365, 0.329, 0.290 | legend, hints, faint mono |
| `--ink-5` | `#3a342f` | 0.227, 0.204, 0.184 | disabled / "sold" / unencountered |

### A.3 — Iron & brass (the frame, tarnished — never shiny gold)

| Token | Hex | RGB (0..1) | Role |
|---|---|---|---|
| `--iron`    | `#070506` | 0.027, 0.020, 0.024 | **1px borders everywhere**, contour |
| `--brass-d` | `#2a2012` | 0.165, 0.125, 0.071 | dark brass / eco-button border tint |
| `--brass`   | `#5f4a22` | 0.373, 0.290, 0.133 | brass mid (focus rings, faint frames) |
| `--brass-l` | `#90712f` | 0.565, 0.443, 0.184 | lit brass (hover accents, "charging…") |
| `--brass-s` | `#d8b65e` | 0.847, 0.714, 0.369 | rare brass sheen / specular |

### A.4 — Accents (blood, ember, gold) — **blood is the only warm UI accent**

| Token | Hex | RGB (0..1) | Role |
|---|---|---|---|
| `--blood`   | `#b5302a` | 0.710, 0.188, 0.165 | **action / CTA**, active edges, primary buttons |
| `--blood-l` | `#d8463b` | 0.847, 0.275, 0.231 | hover, **HP/damage numbers**, "over-cost" |
| `--blood-d` | `#48120e` | 0.282, 0.071, 0.055 | CTA shadow base, deep red |
| `--ember`   | `#c4663a` | 0.769, 0.400, 0.227 | ambient glow only (pit mouth) |
| `--gold`    | `#cda14c` | 0.804, 0.631, 0.298 | **value / sacred** — gold count, descent, INKED, diamonds |

### A.5 — Afflictions / statuses — teint **+** distinct shape (colorblind-safe)

| Token | Hex | RGB (0..1) | Family | Icon shape (clip-path silhouette) |
|---|---|---|---|---|
| `--burn`   | `#e0792e` | 0.878, 0.475, 0.180 | burn   | jagged flame |
| `--bleed`  | `#d8475e` | 0.847, 0.278, 0.369 | bleed  | teardrop (rounded 0/50/50/50, rot 45°) |
| `--poison` | `#93c12f` | 0.576, 0.757, 0.184 | poison | hexagon |
| `--rot`    | `#a86fc4` | 0.659, 0.435, 0.769 | rot    | broken/notched square; also = "cryptic" hue |
| `--shock`  | `#f2d24a` | 0.949, 0.824, 0.290 | shock  | lightning bolt; shock shows `+%` not `−n` |
| `--regen`  | `#7fbf6a` | 0.498, 0.749, 0.416 | regen/heal | up-arrow/cross; `+n` |
| `--shield` | `#6fa8e6` | 0.435, 0.659, 0.902 | shield | pentagon/crest; hatched overlay on HP bars |

> Extra in-context colors seen: **crit** `#ff6a52` (brighter than blood-l, bigger), **thorns**
> `#c2607a` (dusty rose; also used for the **enemy/foe name color** in chronicle & death icons).

### A.6 — Metal gradients (the reliquary frame bevel)

- `--metal` = `linear-gradient(180deg,#15111c 0%,#0e0a14 55%,#070510 100%)` — frame face, tab pills.
- `--metal-r` = `linear-gradient(135deg,#1b1524 0%,#0e0a14 55%,#070510 100%)` — corner cabochons.
- For LÖVE: approximate with a vertical 3-stop fill, or a flat `#0e0a14` mid if gradients are costly.

### A.7 — Typography — 4 voices, strict roles (this is the heart of the redesign)

Google fonts loaded: **Cinzel** (400–900), **Spectral** (300–600 + italics), **Space Mono**
(400/700 + italic), **Silkscreen** (400/700), **Jacquard 24** (single weight). LÖVE has its own
font files; map by role, not by literal family name (see §D.5 for the runtime mapping note).

| Role | Family / weight | Size px | Letter-spacing | Used for |
|---|---|---|---|---|
| **DISPLAY** | Cinzel 900 | 48–88 (banners ~54, type-scale demo 30) | `.04em` | result banners, logo lockup |
| **TITLE** | Cinzel 800 | 22–30 | `.05–.06em` | screen titles (THE GRIMOIRE), section H2 |
| **HEADING** | Cinzel 600–700 | 14–18 | `.02–.05em` | unit/relic names, card titles |
| **BODY** | Spectral 400 | 13–15 | normal | prose, effect descriptions |
| **FLAVOR** | Spectral **italic** 300 | 12–14 | normal | lore / flavor lines |
| **LABEL** | Space Mono **700** | 9–12 | `.10–.18em` (buttons `.16em`) | buttons, chips, HUD captions, tabs |
| **VALUE** | Space Mono **700** | 11–16 | `.02–.04em` | **all numbers**: HP/DMG/CD, gold, `−12`, `+20%`, `6.0s` |
| **CEREMONIAL** | **Jacquard 24** | 50–74 | normal–`.012em` | **rare**: game title "The Pit" + `Victory`/`Defeat`/`Ascension` ONLY |

**Voice rules (the readability fix — §II AVANT/APRÈS, lines 211–227):**
- Cinzel = **engraved** → titles, names, the big destiny words. CAPS + wide tracking. *Never a value or a sentence.*
- Spectral = **handwritten** → readable prose, lore (italic). The only voice that carries sentences.
- Space Mono = **inscribed** → **every label and every value**, tabular figures, unambiguous.
- Jacquard 24 = **ceremonial**, a few words per run; never a label/value/sentence.
- **Silkscreen is the ANTI-PATTERN** (the "AVANT/before" exhibit): chunky pixel caps used for
  *everything* → "squint and re-read". **Do not** use Silkscreen-style for stats or prose. (CLAUDE.md's
  `Theme.ui`/Silkscreen is fine only for short ALL-CAPS labels; content uses the legible voice.)

### A.8 — Spacing, borders, radii, shadows

- **Spacing scale** (observed paddings/gaps): card pad `10–15px`; section pad `22px`; big content pad
  `54–60px`; gaps `8 / 12 / 14 / 18 / 22 / 26px`; section vertical rhythm `margin-top: 64–76px`.
- **Borders:** almost always `1px solid var(--iron)`. Brass `1px` = focus/hover/selected. Blood `1px`
  (+ glow) = active/neighbor/selected-in-board. Frame uses **2px** iron on tab pills & corner cabochons.
- **Radii:** essentially **0** (sharp stone). The only curves are intentional icon shapes (circles,
  teardrops via border-radius) and the locked-slot "arch" (`border-radius:4px 4px 0 0`).
- **Shadow / inset recipes** (reuse verbatim for depth):
  - Engraved/recessed surface (hatched niche, input well): `box-shadow: inset 0 0 22px rgba(0,0,0,.6)`
    or `inset 0 2px 6px rgba(0,0,0,.6)`; background often `repeating-linear-gradient(135deg, stone-800 0 6px, stone-900 6px 12px)`.
  - Brass top-light bevel: `inset 0 1px 0 rgba(216,182,94,.1–.4)`.
  - Blood glow (active): `box-shadow: 0 0 6–14px rgba(181,48,42,.4–.7)`.
  - Drop shadow for floating panels: `0 8–26px 20–80px rgba(0,0,0,.45–.75)`.
  - Affliction glow on numbers: `text-shadow: 0 1px 0 #000, 0 0 12px <hue>@.5`.

### A.9 — The reliquary frame ("l'enrobage") — single gold frame, not per-button

The **whole screen** sits in one carved stone band; individual controls are calm. Two frame variants:

1. **Engraved canvas band** (Main Menu / BUILD wrapper, lines 31–37, 939–941): a `<canvas data-frame
   data-ft="N">` painted by `_engrave()` (script lines 1244–1300). It draws, at **1/3 resolution,
   nearest-scaled** (`image-rendering:pixelated`, `const S=3`): stone strips of thickness `T=data-ft`
   (BUILD `8`, hero `10`), an iron outer line (`depth 0`), a lit lip (`depth 1` = `[60,50,68]`/highlight
   `[96,82,108]`), a shadow inner line (`depth T-1`), **incised vein channels** wandering the border
   (4 sine-wandering strands per side; ~half tinted **blood** `BM=[146,46,33]`/`BH=[206,78,56]` with
   occasional drips), and **corner beads** (blood cabochons). Inside: `inset 0 0 0 1px #04030a, inset 0 0
   0 2px rgba(120,20,16,.18)` + a top-down inner **vignette** (`radial-gradient(...transparent 40%, rgba(0,0,0,.45))`)
   so content pools in light. A **centered tab pill** crowns it (the screen name).
2. **Beveled metal frame** (Menu/COMBAT/GRIMOIRE/RELIC, lines 1052–1055): nested boxes
   `iron 2px → var(--metal) 9px (with brass top-light inset) → iron 1px → content`, **four 22×22 corner
   cabochons** (`--metal-r`, 2px iron, a rotated `--blood-d` diamond center) at `±3px`, and the **screen-name
   tab pill** centered on the top edge (`translate(-50%,-52%)`, `--metal` bg, Cinzel 700 11px `.28em`,
   ink `#1c150a`).

For LÖVE, both reduce to: **one ornamented border around the play area + a centered stone/metal tab
bearing the screen name**, with blood used sparingly in the carving and on the cabochons. Ambient life =
a breathing **ember pit-mouth glow** pooled bottom-center (`pit-breathe 6–7s`) + a few flickering motes.

---

## B. SCREEN LAYOUTS — BUILD (primary), GRIMOIRE, RELIC PICK

### B.1 — BUILD ("Interface Board") — the richest screen (source 936–1046)

Wrapper: engraved canvas band (`data-ft="8"`), inner play area **fixed `height:612px`**, bg
`radial-gradient(130% 80% at 50% -12%, #15101c, #0b0712 58%, #080510)` + faint scanlines
(`repeating-linear-gradient(0deg, rgba(255,255,255,.013) 0 2px, transparent 2px 4px)`) + breathing
pit-mouth glow + 3 flicker motes. Centered top tab pill reads **BUILD** (Cinzel 700 11px `.3em`, `#cdbca0`).

Vertical stack (flex column, full height): **HUD bar → Sigil header → Board (flex:1) → Shop+Eco footer.**

**1) Top HUD bar** (line 951) — `linear-gradient(180deg,#1d1710,#120d08)`, bottom `1px iron`, top brass
inset. A single row of cells separated by **`1px iron` vertical rules**. Each cell: `padding:8px 14px`,
caption = Space Mono **8px** `.16em` `--ink-4`, value below. **Order, left→right:**
1. **GOLD** — caption `GOLD`; value Space Mono 700 14px `--gold`, preceded by a 9×9 rotated-45° gold
   diamond coin (`linear-gradient(135deg,#e3c061,#7a5e24)`, 1px iron). e.g. `◆ 24`.
2. **LIVES** — caption `LIVES 3/5`; row of **5 heart pips** 8×11 (`clip-path` heart): filled = `--blood`,
   spent = `--stone-700`. Gap `4px`.
3. **DESCENT** — caption `DESCENT 7/10` (the `7/10` in `--gold`); this cell **flexes (`flex:1`)**. Below:
   **10 segments**, gap `2px`, `height:6px`, each `flex:1`; filled = gold gradient `(180deg,#caa64a,#7a5e24)`,
   empty = `#0a0810` + `1px stone-700`.
4. **ROUND** — caption `ROUND`; value Space Mono 700 14px `--ink` (e.g. `4`).
5. **STREAK** — caption `STREAK`; value Space Mono 700 **12px** `--blood-l` (e.g. `WIN x3`).
6. **TIER** — caption `TIER 3/5`; row of **5 diamonds** 8×8 rotated-45°: filled = `--gold`, empty =
   `#0a0810` + `1px brass`. Gap `3px`.

**2) Sigil header row** (line 966) — between HUD and board; `padding:9px 18px 8px`, bottom `1px iron`.
- **Left:** a 13×13 ring glyph (`2px solid --blood`, `border-radius:50%`) + **`RING SIGIL`** (Cinzel 700
  15px `.08em` `--ink`) + **`— chain`** (Spectral italic 13px `--ink-3`). Pattern = `<NAME> SIGIL — <keyword>`.
- **Right = reshape controls:** label **`[S] RESHAPE`** (Space Mono 9px `.1em` `--ink-4`) then **5 icon
  buttons** 24×24, `1px iron`, bg `#100b16`, glyph centered. Each glyph is one **sigil shape** at 10–11px,
  drawn in `--ink-4`: ① hollow square (2px outline) ② cross (plus clip-path) ③ **active = ring** (this one
  is `bg:#1a0e10`, `1px --blood`, blood glow `0 0 8px`, glyph `--blood-l`) ④ diamond (rotated square)
  ⑤ line (13×2 bar). So: **square / cross / ring(active) / diamond / line** = the 5 board topologies; the
  selected one is the blood-lit button.

**3) Board area** (line 972) — flex:1 centered row, `gap:24px`, `padding:6px 20px`. Two columns:
**left = the 3×3 graph (214×214, fixed)**, **right = the persistent inspector (256px, fixed)**.

*Board graph (214×214, line 973):* nine **54×54 cells** at offsets `{0, 80, 160}` on each axis (so 26px
gutters), with **explicit edge segments** drawn as 26×2 / 2×26 bars in the 26px gaps:
- **Neutral edge:** `#322a38`. **Active edge:** `--blood` + glow `0 0 6px` (the 4 edges touching the
  selected center cell are blood).
- **Cell states** (read off the mock — these are the canonical six):
  - *empty unlocked:* flat `#100a13`, `1px #38313f`.
  - *occupied:* hatched `repeating-linear-gradient(135deg,#1d1626 0 4px,#150f1f 4px 8px)`, `1px #38313f`,
    `inset 0 0 8px rgba(0,0,0,.5)`. Holds a **type pip** (top-left, 8–9px, shape+color by faction) and a
    **2px blood "front" bar** along the bottom inset edge (`bottom:3px; left:3px; right:3px`).
  - *occupied + selected (carry/center):* hatched **gold-brown** `(135deg,#2a1f10 0 4px,#1d1509 4px 8px)`,
    `1px --blood`, strong glow `0 0 14px rgba(181,48,42,.5)`.
  - *front-line marker:* the blood bottom-bar present on front-column occupied cells (depth cue).
  - *locked:* `#0a070d`, `1px #221c28`, centered **"arch" glyph** (11×9, `2px #3a3340`, no bottom,
    `border-radius:4px 4px 0 0`) = "LEVEL to open".
  - *(valid drop target — from the §V board legend, line 723):* `#0e1410`, `1px #5aa856` (green),
    glow `0 0 10px rgba(107,199,102,.35)`, optional centered green `+`.

*Persistent inspector panel (256px, line 999):* a column of two stacked cards, `gap:11px`, vertically
centered. **This replaces a hover tooltip — it is always present.**
- **Unit detail card** (line 1000): bg `(180deg,#16121f,#0c0913)`, `1px iron`, brass top inset.
  - *Sprite niche:* `height:80px`, **hatched** `repeating-linear-gradient(135deg,stone-800 0 6px,stone-900 6px 12px)`,
    `inset 0 0 22px rgba(0,0,0,.6)`, bottom `1px iron`. Top-left a type pip (10×10); top-right **level
    diamonds** (7×7, filled gold / empty `1px brass`); bottom-centered mono caption `sprite · <id>`
    (8.5px `--ink-4`). **Never a fake drawing** — a carved niche + label (real sprite renders here in-engine).
  - *Body* (`padding:11px 13px 13px`): name **Cinzel 700 14px** `--ink` (left) + **type badge** (right):
    `2px 7px`, `1px #473a2c`, 7×7 shape pip + faction word (Space Mono 8px `#cabf9e`) — e.g. `◆ BONE`.
  - *Stat bar:* `margin-top:9px`, `padding:7px 10px`, bg `#0a0810`, `1px iron`, gap `12px`. Three
    `LABEL <value>` pairs in Space Mono 9.5px: label `--ink-3`, value `--ink` 700 — **`HP 60  DMG 4  CD 7s`**.
  - *Passive block:* passive **name** Space Mono 9.5px `.04em` **`--gold`** (e.g. `BULWARK OF BONE`), then
    its **description** Spectral 12px `--ink-2` line-height 1.45.
- **Adjacency card** (line 1009): bg `#0b0912`, `1px iron`, `padding:10px 12px`. Header **`ADJACENCY · N
  LINKS`** (Space Mono 8.5px `.18em` `--ink-3`). Then **one row per link**, `gap:7px` column: a small
  **colored bullet** (8–9px, shape+color matching the source affliction/role) + a Spectral 11.5px `--ink-2`
  sentence; embedded values switch to Space Mono `--ink` 700 (e.g. `Shield aura → +14`). Bullets seen:
  blood square (taunt/front), poison hexagon (neighbour venom), shield pentagon (aura).

**4) Shop + Eco footer** (line 1021) — top `1px iron`, bg `(180deg,#100b14,#0a0710)`, `padding:11px 14px`,
flex row `gap:12px`, a `1px iron` vertical rule between shop and eco.
- **THE OFFERING (shop), `flex:1`:** header row = caption **`THE OFFERING`** (Space Mono 9px `.2em`
  `--ink-3`) + a `1px iron` rule filling the rest. Below: a row of **shop cards**, `gap:8px`.
  - *Card* (88px wide): bg `(180deg,#15111d,#0d0a13)`, `1px iron`. **Art chip** `height:46px` hatched +
    bottom `1px iron`, with a type pip top-left (8×8). **Footer** `padding:6px 7px`: name **Cinzel 600
    10px** `--ink` (left) + **cost** Space Mono 700 10px `--gold` with a 6×6 gold diamond (right).
  - *Selected/hover card:* `1px --blood-l`, glow `0 0 10px rgba(181,48,42,.28)`, art chip uses lighter
    hatch (`stone-700/stone-800`).
  - *Over-cost card:* cost shown in `--blood-l` with a dark-red diamond (`#3a120e`, `1px blood-d`).
  - *Sold slot:* 88×84, `#080610`, `1px iron`, `inset 0 2px 12px rgba(0,0,0,.7)`, centered **`SOLD`**
    (Space Mono 8px `.2em` `--ink-5`).
- **Eco cluster (right):** column, `gap:7px`, centered. Top row = two **ECO buttons** `gap:7px`:
  - **`REROLL ◆1`** and **`BUY XP ◆4`** — Space Mono 700 9.5px `.08em` `--ink-2`, `padding:7px 10px`,
    bg `(180deg,#221709,#170f06)`, `1px #4a3514` (brass-tinted), the `◆N` cost in `--gold`.
  - Below, the **FIGHT** CTA (the one loud button): Space Mono 700 **13px** `.18em` `#f3dcc6`,
    `padding:12px 30px`, bg `linear-gradient(180deg,#7a1d16,#4c130f)`, `1px iron`,
    `box-shadow: inset 0 1px 0 rgba(216,70,59,.5), inset 0 -3px 5px rgba(0,0,0,.45), 0 0 16px rgba(181,48,42,.3)`,
    `text-shadow:0 1px 0 #000`. **This is the only blood-filled button on the screen.**

> FIGHT button **states** (atoms, lines 316–319): *default* `(#7a1d16→#4c130f)`; *hover* lighter
> `(#9c281e→#5e1812)` + outer glow `0 0 18px rgba(181,48,42,.45)`; *pressed* darker + `translateY(1px)`
> + inset shadow; *disabled* `--stone-800` fill, `--ink-5` text, no glow.

### B.2 — GRIMOIRE (source 1109–1142) — metal-framed codex

Metal frame, tab **THE GRIMOIRE**. Centered header: Cinzel 700 24px `The Grimoire` + Spectral italic
13px subtitle `42 of 60 inscribed — deduce to ink them permanent`. Below, a **tab strip** (`1px iron`
bottom): **RELICS** (active: blood 2px underline + glow) / **BESTIARY** (`--ink-3`), with a right-aligned
**`RARITY R1 ▸ R5 · SORT: RARITY ▾`** (Space Mono 9.5px `--ink-4`). Body = **4-column grid**, `gap:12px`,
of relic rows:
- *Inked relic row:* bg `(180deg,#1a140e,#100b08)`, `1px iron`, `padding:13px`, flex `gap:11px`. A **30×30
  rotated-45° gem** tinted to its affliction (e.g. blood→`(135deg,#7a201a,#3a100c)`, burn, bleed, bone) with
  a small bright core; then name (Cinzel 700 12px `--ink`) + effect (Spectral 11.5px `--ink-3`, value in
  Space Mono colored to family).
- *Cryptic row:* bg `(180deg,#140e18,#0b070d)`; gem = hatched `(135deg,#1c1322 0 4px,#140d1a)` with a `?`
  (Cinzel `--rot` @.7); title `? ? ?` (Cinzel 700 `.1em` `--ink-3`), subtitle `cryptic` (Spectral italic
  `--ink-5`).
- *Rare/keystone row:* `1px --brass` + glow `0 0 12px rgba(144,113,47,.2)`; gold gem.
- *Unencountered row:* `opacity:.6`, empty `#0a0810` gem with `1px stone-700`, label `UNENCOUNTERED`
  (Space Mono 10px `--ink-5`).

### B.3 — RELIC PICK 1-of-3 (source 1145–1170) — metal frame, tab **REWARD**

Bg `radial-gradient(110% 120% at 50% 100%, rgba(120,40,140,.18), #0a0712 60%)`. Centered header: Spectral
italic 12.5px `the victory loosens something below` + Cinzel 700 26px **`A Fragment Surfaces`**. Then **3
cards** (`width:212px`, `gap:18px`, centered):
- Side cards: bg `(180deg,#140e18,#0b070d)`, `1px iron`. **50×50 rotated cryptic gem** (hatched `+ ?`),
  title `? ? ?` (Cinzel 700 16px `.16em` `--ink-3`), tag `EFFECT UNKNOWN` (Space Mono 8.5px `--ink-5`),
  flavor (Spectral italic 12px `--ink-4`).
- **Center card = highlighted:** `translateY(-6px)`, `1px --brass`, glow `0 0 22px rgba(168,111,196,.2)`,
  gem `(135deg,#4a2c5a,#1c1322)` `2px brass` glowing, tag `REVEALS IN USE` in `--rot`.
- Footer actions: **`BIND THE FRAGMENT`** (blood CTA, Space Mono 700 12px `.16em`) + **`REFUSE +2◆`**
  (ghost button, `--ink-3`, the `+2◆` reward in `--gold`).

---

## C. COMBAT SCREEN (source 1049–1106) — **EXISTS** · the user's priority

> A full COMBAT organism mockup **is present** in `design-system-source.html` (`data-screen-label="Organisme
> · COMBAT"`, lines 1050–1105). It depicts the auto-resolved spectacle: a metal-framed cave arena with
> two facing teams, per-unit HP/shield bars + status pips, floating damage numbers, a `vs` title, and a
> bottom control strip (speed toggle + chronicle/replay hints). Below are its exact specs; combine with the
> §C.2 molecules (combat numbers, chronicle, result banners) which are authored to compose with it.

### C.1 — Arena frame & scene

- **Frame:** the beveled metal frame (iron 2px → `--metal` 9px → iron 1px → content), four corner
  cabochons, centered top tab pill **COMBAT** (Cinzel 700 11px `.28em`, `#1c150a`). Wrapper `max-width:940px`.
- **Arena field:** `height:430px`, bg **vertical gradient** `linear-gradient(180deg,#0c0810 0%,#140a0e 55%,#2c0e10
  100%)` — i.e. it **reddens toward the bottom** (you fight over the pit's mouth). `overflow:hidden`.
- **Ambience:** a row of **stalactites** across the top (`clip-path:polygon(0 0,100% 0,50% 100%)`, widths
  9–16px, heights 16–42px, `#080510`, `opacity:.7`, `justify-content:space-around`); a strong **pit-mouth
  glow** bottom-center (`radial-gradient(...rgba(181,48,42,.4)...)`, `pit-breathe 6s`).
- **`vs` title** (line 1063): top-centered, `top:16px`. `vs ` in Spectral italic 13px `--ink-3` + the
  enemy team name **`DROWNED CHOIR`** in Cinzel 700 15px `.08em` `--ink-2`.

### C.2 — Combatants & arena layout (line 1066)

The fight area is `position:absolute; inset:60px 40px 70px` (so it clears the vs-title and bottom strip),
a flex row **space-between** with the **left (your) team on the left, right (enemy) team on the right**,
each team a 2-column cluster (front/back) of vertically stacked unit tokens, column `gap:22px`.

**Per-unit token** (the canonical combat unit):
- **HP bar** above the body: `width:54px`, `height:8px`, bg `#0a0810`, `1px iron`, `margin-bottom:5px`.
  Fill = **left-anchored** red `linear-gradient(180deg,#c0392f,#5a1714)` whose width = HP% (mock uses
  `inset:0 26% 0 0` → 74%). **Multi-segment** when statuses present (drawn as additional absolutely-positioned
  inset layers, left-anchored, in the §A.5 family colors): e.g. a green poison band, and a **shield overlay**
  = hatched blue `repeating-linear-gradient(135deg, rgba(111,168,230,.55) 0 3px, rgba(111,168,230,.2) 3px 6px)`
  on the left portion. (Matches the gauge molecule, lines 515–519.)
- **Body token:** `~54×50` (carry/featured ~58×54), `1px iron`, hatched fill. **Your units** read warm-grey
  `repeating-linear-gradient(135deg,stone-700 0 5px,stone-800 5px 10px)`; **enemy units** read **cold-blue**
  `(135deg,#1a2230 0 5px,#121826 5px 10px)` — team is encoded by **hatch hue** (warm vs cold), not by a
  colored frame. A **featured/buffed** unit gets `1px --brass` + glow `0 0 10px rgba(144,113,47,.3)`.
- **Status pips:** a centered row **below** the body (`gap:3px`, `margin-top:4px`), each a 9–11px
  affliction glyph in its family color (e.g. a burn flame). (Mirrors the chip/affliction shapes, §A.5.)
- **Floating damage number:** absolutely positioned **above** the token (`top:-24..-26px`, centered),
  Space Mono 700, **color = cause** (§A.5/§C.3), with `text-shadow:0 0 10–12px <hue>@.6`. Mock shows a
  blood **`−12`** (20px) and a burn **`−6`** (16px) — bigger = bigger hit.

### C.3 — Floating combat numbers (molecule, lines 759–777) — one color per cause

Used both as the floating numbers above and in the chronicle. Space Mono 700, `text-shadow:0 1px 0 #000, 0
0 12px <hue>@.5`:

| Cause | Color | Example | Size |
|---|---|---|---|
| BLADE (physical) | `--blood-l` | `−12` | 26px |
| **CRIT** | `#ff6a52` | `−24!` (the `!` smaller) | 34px (loudest) |
| BURN | `--burn` | `−6` | 24px |
| BLEED | `--bleed` | `−3` | 24px |
| POISON | `--poison` | `−3` | 24px |
| ROT | `--rot` | `−5` | 24px |
| SHOCK | `--shock` | `+15%` (a debuff %, not `−n`) | 22px |
| THORNS | `#c2607a` | `−3` | 22px |
| HEAL | `--regen` | `+5` | 24px |
| ABSORB/shield | `--shield` | `⛒0` | 22px |

### C.4 — Bottom control strip (line 1091)

`position:absolute; bottom:0`, full width, `padding:11px 16px`, top border `1px rgba(216,182,94,.1)`, bg
fades up from `rgba(8,4,10,.6)`. **Left:** status text `auto-battle in progress…` (Space Mono 9.5px `.12em`
`--ink-4`). **Right:** a **speed segmented toggle** (`1px iron` group): `1×` (inactive, `#100d16`,
`--ink-3`) | **`2×`** (active = blood fill `(180deg,#7a1d16,#4c130f)`, `#f3dcc6`), each `padding:5px 11px`
Space Mono 700 9px — then a hint **`[c] chronicle · [r] replay`** (Space Mono 9px `--ink-4`).

### C.5 — Result / destiny banners (molecule, lines 814–842) — overlay on dimmed scene

Shown over a darkened arena. Each `~height:170px`, `1px iron` (Ascension `1px --brass`), centered column,
the big word in **Jacquard 24** (the ceremonial voice):
- **VICTORY:** bg `radial-gradient(90% 100% at 50% 40%, rgba(150,40,20,.25), #080510)` + inner gold halo.
  Eyebrow `RIGHT PREVAILS` (Space Mono 9px `.24em` `--ink-3`); **`Victory`** Jacquard **54px** `--gold`,
  `text-shadow:0 0 26px rgba(205,161,76,.5)`; line Spectral 12.5px `Your blades struck down 4.`; hint
  `[click] build · [r] replay` (Space Mono 9px `--ink-5`).
- **DEFEAT:** bg redder `rgba(120,20,16,.3)…#080308`; **`Defeat`** Jacquard 54px **`--blood-l`**, red glow;
  eyebrow `LEFT PREVAILS`; line e.g. `Cut down by venom (3).`.
- **ASCENSION** (run win, wider `flex:1.3`): bg `radial-gradient(...rgba(196,102,58,.3)...)` + `1px --brass`
  + gold halo. Eyebrow Spectral italic `the pit gives you up, this once`; **`Ascension`** Jacquard 50px
  `--ink`, gold glow; stat line Space Mono 700 12px `--gold` `7 WINS · 2 LOSSES · 11 ROUNDS`; hint `[click]
  descend again`.

### C.6 — Chronicle log (molecule, lines 780–796) — the readable combat journal

Panel bg `(180deg,#14101a,#0c0912)`, `1px iron`. Header row (`padding:11px 14px`, bottom `1px iron`, bg
`#100d16`): title **`CHRONICLE`** (Cinzel 700 13px `.06em` `--ink`) + a **segmented filter** `ALL`(active,
blood) / `YOU` / `FOE` (Space Mono 700 9px). Each log line (`padding:6px 14px`, flex baseline `gap:10px`):
**timestamp** (`flex:0 0 34px`, Space Mono 9.5px `--ink-5`, e.g. `6.2s`) · **event** (Spectral 13px `--ink-2`,
with unit names inlined as Space Mono 11px — **your units `--ink`, enemy units `#c2607a`**) · **right-aligned
value/pip** (Space Mono 700, cause-colored — e.g. `−12`, or `◇×2` poison). Faint per-family row tint
(`rgba(<hue>,…,.04)`). **Death line:** italic `--blood-l`, e.g. `BANDIT falls` + a faded heart icon.

---

## D. DELTAS — what makes it "clean / pure / composed" (richer than a minimal build)

1. **Persistent inspector panel, not a hover tooltip.** BUILD devotes a fixed **256px right column**
   (unit-detail card + adjacency card) that is *always* showing the selected unit — sprite niche, name,
   type badge, `HP/DMG/CD` stat bar, gold-named passive + description, and **`ADJACENCY · N LINKS`** with
   one colored-bullet sentence per active edge. (A hover tooltip molecule still exists, lines 671–685, for
   the shop, but the board uses the panel.) This is the single biggest "rigor" upgrade.
2. **Full diegetic top HUD bar** — a 6-cell engraved band (GOLD ◆ / LIVES heart-pips / **DESCENT** 10-seg
   bar / ROUND / STREAK / **TIER** diamonds) separated by iron rules, instead of a few loose counters.
3. **Sigil reshape controls** — a named header (`<NAME> SIGIL — <keyword>`) + **5 shape-glyph buttons**
   (square/cross/ring/diamond/line), the active one blood-lit, surfacing the mutable-topology mechanic.
4. **"THE OFFERING" framing** — the shop is a labelled rite (caption + rule + uniform 88px cards with art
   niche, Cinzel name, gold ◆ cost, selected/over-cost/SOLD states), not a bare row of buttons.
5. **One reliquary frame, calm interior.** Gold/brass ornament lives *only* on the screen's border
   (engraved canvas band or metal bevel) + corner cabochons + a centered name tab. **Buttons are stone;**
   exactly **one blood CTA** (FIGHT) shouts per screen. "L'or encadre le jeu, pas chaque bouton."
6. **The readability rule, enforced** — Cinzel engraves **names/titles**, Space Mono inscribes **every
   value & label** (tabular), Spectral writes **prose/lore**, Jacquard 24 is reserved for **The Pit** +
   `Victory/Defeat/Ascension`. **Silkscreen-for-everything is the explicit anti-pattern** (the "AVANT"
   exhibit) — never set stats or sentences in chunky pixel caps.
7. **Affliction = hue + shape, always doubled** — every status/type carries both a color and a distinct
   silhouette (flame/teardrop/hexagon/broken-square/bolt/crest), so the board, bars, pips, chronicle and
   floating numbers stay legible (and colorblind-safe) without reading text.
8. **Information never rides on color alone; surfaces are quiet; blood is the sole warm accent.** The mood
   is desaturated black stone, bone-colored ink, tarnished brass framing, generous breathing room
   (`64–76px` between sections, padded niches), and ember light pooling at the bottom of every scene — so
   the eye lands on the one red thing that matters.

### D.5 — Runtime font note (for the LÖVE re-skin)

These are *web* font families; the engine ships its own. Map by **role** (CLAUDE.md / v1 spec §6a): the
ceremonial Jacquard/blackletter, the engraved Cinzel-style display, the Spectral-style serif for prose,
and a mono for all values/labels (the project's `Theme.read` legible face for content, `Theme.ui` only for
short caps labels). The exact hexes, sizes, letter-spacing, layouts and state recipes above are
font-independent and should be matched verbatim.
