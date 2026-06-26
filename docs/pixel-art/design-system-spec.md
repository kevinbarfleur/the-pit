# The Pit — Design System Implementation Bible

Status: technical visual reference, not gameplay source of truth.

> Source files: `design-system-source.html` (1308 lines), `forge-px.js` (widget atoms, ~426 lines), `pit-forge.js` (full renderer, ~900 lines).
> This document is the authoritative implementation reference for porting the designer's web system into Lua/LÖVE.

Gameplay note: this document predates the readable-relic decision. Use its
palette, dimensions, typography, frame algorithms and component anatomy. Ignore
old relic-content assumptions about cryptic/identified states or hidden
identification; `CLAUDE.md` and `docs/research/relics-design.md` win.

---

## 1. SECTION INVENTORY

| # | Title | Intent |
|---|-------|--------|
| I | Couleur | Full palette tokens — grounds, inks, brass/metal, accents, afflictions |
| II | Typographie | 4 voices (Jacquard/Cinzel/Spectral/Space Mono), type scale, before/after comparison |
| III | Iconographie | Type pips (shape per faction), affliction icons (shape + color), sprite niche convention |
| IV | Atomes | All base controls: buttons (5 variants), inputs, select, toggles/checkbox/radio/segmented, slider, chips (type/affliction/status), badges, stat-line readouts, health + cooldown + lives + descent gauges, 3 divider styles |
| V | Molécules | Unit shop cards (4 states), unit detail card, readable relic cards, tooltip, board-graph 3×3, HUD run banner + eco cluster, floating combat numbers, chronicle log, tabs, result banners (Victory/Defeat/Ascension), modal dialog, side settings panel |
| VI | Organismes | Full screen compositions living inside the reliquary band: Main Menu, Build screen, Combat screen, Grimoire, Relic Pick 1-of-3 |

---

## 2. COMPONENT CATALOG

All dimensions from HTML mockup. Colors are CSS custom-property names followed by hex.

### 2.1 — Buttons

**Hierarchy rule**: one PRIMARY (blood red), secondary (stone/brass), eco (compact + gold cost), icon (square), ghost (text only).

#### PRIMARY button (FIGHT / CTA)

| Property | Value |
|----------|-------|
| Font | Space Mono 700, 13px, letter-spacing 0.16em, UPPERCASE |
| Padding | 11px 28px (hover/rest), 12px 28px 10px (pressed = 1px down) |
| Color default | `#f3dcc6` |
| Color hover | `#f7e7d4` |
| Color pressed | `#e9cbb6` |
| Color disabled | `ink-5` = `#3a342f` |
| Bg default | `linear-gradient(180deg, #7a1d16, #4c130f)` |
| Bg hover | `linear-gradient(180deg, #9c281e, #5e1812)` |
| Bg pressed | `linear-gradient(180deg, #43110d, #5a1611)` |
| Bg disabled | `stone-800` = `#16121d` |
| Border | 1px solid `iron` = `#070506` |
| Shadow default | `inset 0 1px 0 rgba(216,70,59,.5), inset 0 -3px 5px rgba(0,0,0,.45), 0 2px 0 rgba(0,0,0,.55)` |
| Shadow hover | adds `0 0 18px rgba(181,48,42,.45)` |
| Shadow pressed | `inset 0 2px 5px rgba(0,0,0,.6)`, translateY(1px) |
| Shadow disabled | `inset 0 0 12px rgba(0,0,0,.4)` |
| text-shadow | `0 1px 0 #000` |

**forge-px.js pixel equivalent**: `drawButton(buf, W, H, press, eyeOpen, glow, seed, label, disabled, eyes, gaze, size, t)` — plate fill + metal frame (TH=3px) + 4 rivets + eye swarm crowd (positioned around the label zone) + bitmapped monospace text in gold.
**pit-forge.js pixel equivalent** (R=4): `drawButton` — same structure but R×4 pixels, `panelFill` (dark panel with vignette + dither) + `metalBorder` (GOLD palette, `cornerPiece` not used here) + 4 rivets + same eye crowd.

#### SECONDARY button (CONTINUE)

| Property | Value |
|----------|-------|
| Font | Space Mono 700, 12px, letter-spacing 0.14em |
| Padding | 10px 24px |
| Color default | `ink-2` = `#c3b89e` |
| Color hover | `ink` = `#ece3ce` |
| Bg default | `linear-gradient(180deg, #1d1826, #141019)` |
| Bg hover | `linear-gradient(180deg, #272031, #1a1622)` |
| Shadow default | `inset 0 1px 0 rgba(216,182,94,.16), inset 0 -2px 4px rgba(0,0,0,.4)` |
| Shadow hover | adds `0 0 12px rgba(144,113,47,.2)` (subtle brass glow) |

#### ECO button (REROLL / LEVEL — with gold cost)

| Property | Value |
|----------|-------|
| Font | Space Mono 700, 11px, letter-spacing 0.12em |
| Padding | 8px 13px |
| Layout | inline-flex, gap 8px, label + diamond icon + number |
| Color | `ink-2` default, `ink` hover |
| Bg | `linear-gradient(180deg, #221709, #170f06)` |
| Border | 1px solid `#4a3514` (brass-dark) |
| Gold icon | 7×7px diamond `rotate(45deg)`, `var(--gold)` = `#cda14c` |
| Cost number | Space Mono 700, same size, `var(--gold)` |
| Disabled label | `LEVEL MAX` — color `ink-5`, bg `#130d07`, border `#2a2012` |

**pit-forge.js**: `drawEcoBtn` — same but pixel bitmapped; cost uses `drawDiamond` at `x1-12R`.

#### ICON button (34×34px square)

| Property | Value |
|----------|-------|
| Size | 34×34px (design), pit-forge uses 12R×12R internal |
| Bg | `linear-gradient(180deg, #1d1826, #141019)` |
| Border | 1px solid `iron` |
| Shadow | `inset 0 1px 0 rgba(216,182,94,.16)` |
| Content | centered glyph (brass-l diamond = sigil, arrow chevrons, gear clip-path) |

**pit-forge.js**: `drawIconBtn(buf,W,H,press,glow,seed,kind,t)` — kind: `'sigil'` (animated glyph), `'left'`/`'right'` (chevron), `'back'`, `'gear'` (bitmap ICON.gear). Sigil uses `glyphPts()` generating a set of wobbling points rendered via `goldText`.

#### GHOST button (REFUSE / ESC back)

| Property | Value |
|----------|-------|
| Font | Space Mono 700, 11px, letter-spacing 0.12em |
| Color default | `ink-3` = `#8d8270` |
| Color hover | `ink` + 1px border-bottom solid `blood` |
| Background | transparent, no border |

---

### 2.2 — Inputs

#### Text field

| State | Bg | Border | Text color |
|-------|-----|--------|-----------|
| default | `#0a0810` | 1px `iron` | `ink-4` (placeholder) |
| focus | `#0c0a12` | 1px `brass` + `0 0 0 1px brass-d` + `0 0 14px rgba(181,48,42,.22)` glow | `ink` |
| disabled | `stone-900` | 1px `iron` | `ink-5` |

- Padding: 10px 12px
- Font: Spectral 14px
- Width: 220px in mockup
- Focus cursor: 2×15px inline-block `blood-l`

#### Search field

Same as text default + leading 13×13px icon (9×9 circle `border 1.5px ink-3` + 5×1.5px diagonal handle). Font: Spectral 14px, color `ink-4`.

#### Number stepper

- Total: `32+48+32 px = 112px`, height 36px
- `−` and `+` buttons: 32×36, `linear-gradient(180deg, #1d1826, #141019)`, no border except inner 1px `iron`
- Center: 48×36, bg `#0a0810`, Space Mono 700 15px `ink`

#### Select / dropdown

Closed:
- Width 248px, `linear-gradient(180deg, #15111d, #100d16)`, border 1px `iron`
- Shadow: `inset 0 1px 0 rgba(216,182,94,.1)`
- Padding 11px 13px, Spectral 14px `ink`
- Chevron: 8×8px borders (right+bottom), `ink-3`, rotated 45°

Open (focused):
- Same width, border 1px `brass`, + `0 0 0 1px brass-d`
- Chevron reversed (right+top, `brass-l`)
- Dropdown bg `#0c0a12`, shadow `0 12px 28px rgba(0,0,0,.6)`
- Each option: 9px 13px padding, Spectral 13.5px `ink-2`, divider 1px `stone-700`
- **Selected item**: `linear-gradient(90deg, rgba(181,48,42,.18), transparent)`, left-border 2px `blood`, trailing 7×7 diamond `blood`

---

### 2.3 — Toggles & Choice controls

#### Toggle switch

| State | Track | Thumb |
|-------|-------|-------|
| ON | `linear-gradient(180deg, #3a0f0c, #5a1611)`, border iron, `0 0 10px rgba(181,48,42,.3)` | `linear-gradient(180deg, #caa64a, #7a5e24)`, right:2px |
| OFF | `#0a0810`, border iron, inset shadow | `linear-gradient(180deg, #5d544a, #3a342f)`, left:2px |

Size: 44×23px track, 17×17px thumb

#### Checkbox

- Unchecked: 18×18px, bg `#0a0810`, border 1px `iron`
- Checked: bg `linear-gradient(180deg, #caa64a, #7a5e24)`, checkmark: 5×9px border-right + border-bottom `#1c150a`, rotated 45°

#### Radio (diamond shape)

- Unchecked: 16×16px rotated 45° diamond, bg `#0a0810`, border 1px `iron`
- Checked: border 1px `brass`, inner 7×7 bg `blood` with `box-shadow: 0 0 6px rgba(181,48,42,.6)`

#### Segmented control

- Inline-flex, border 1px `iron`
- Active segment: PRIMARY button styling (`linear-gradient(180deg, #7a1d16, #4c130f)`, text `#f3dcc6`)
- Inactive: bg `#100d16`, text `ink-3`
- Padding: 8px 17px, Space Mono 700 11px 0.1em

---

### 2.4 — Slider

- Track: height 8px, bg `#0a0810`, border 1px `iron`, `inset 0 1px 3px rgba(0,0,0,.7)`
- Fill (brass/volume): `linear-gradient(180deg, #caa64a, #7a5e24)` from left to thumb
- Fill (blood/speed): `linear-gradient(180deg, #c0392f, #5a1714)`
- Thumb: 14×20px, brass: `linear-gradient(180deg, #caa64a, #6a5020)`, blood: `linear-gradient(180deg, #d8463b, #7a1d16)`, border 1px `iron`, glow shadow
- Label: Space Mono 10px 0.14em `ink-2` left, value Space Mono 700 12px right (`ink` or `blood-l`)
- Width: 300px in mockup

---

### 2.5 — Chips & Labels

#### Type chip (faction)

All chips: `inline-flex`, gap 7px, padding 5px 11px, border 1px (faction-dark), bg (faction-color at 10-14% opacity), Space Mono 10px 0.1em.

| Faction | Shape icon | Icon size | Color | Border |
|---------|-----------|-----------|-------|--------|
| FLESH | 13×5px bar | `#b3493a` | `#cf7a6a` | `#3a120e` |
| ORDER | 13×13px cross clip-path | `#c4a04a` | `#d8b65e` | `#4a3814` |
| BONE | 10×10px rotated diamond | `#b3a07e` | `#cabf9e` | `#473a2c` |
| ARCANE | 14×14px 5-point star clip-path | `#a05a8c` | `#c98bb4` | `#33182c` |
| ABYSS | 11×11px circle | `#8a4a64` | `#c07e98` | `#2a1220` |

**pit-forge.js atom**: `drawTypePip(buf,x,y,fam,t)` — 4R×4R glyph, each shape drawn pixel-exact. Used as 9R×8R block in slot top-left.

#### Affliction chip

Same layout: icon (clip-path shape matching §III) + label in affliction color, border is darkened version of affliction color.

Sizes for icons in chips (from §III clip-paths):
- BURN: 11×13px flame clip-path
- BLEED: 10×12px teardrop `border-radius: 0 50% 50% 50%` rotated 45°
- POISON: 12×12px hexagon clip-path
- ROT: 11×11px L-shaped clip-path
- SHOCK: 11×12px lightning bolt clip-path
- REGEN: 22×22px upward arrow cross clip-path
- SHIELD: 20×23px shield clip-path

**pit-forge.js**: `drawKwChip(buf,W,H,affKey,label,value,t,active)` — pill shape with `pillFill`, bitmap icon from `AFFL[key].bmp` (8-row bitmap), label, optional value right-aligned.

#### Status chip (relic state)

Compact, Space Mono 700 9.5px 0.14em, padding 4px 10px:

| State | Bg | Text | Border |
|-------|-----|------|--------|
| NEW | `blood` fill | `#f3dcc6` | none |
| INKED | transparent | `gold` | 1px `brass` |
| SEALED | transparent | `ink-4` | 1px `ink-5` |
| CRYPTIC | `rgba(168,111,196,.16)` | `rot` = `#a86fc4` | 1px `#4a2c5a` |

---

### 2.6 — Badges

#### Cost badge (gold coin)

- Icon: 11×11px diamond `linear-gradient(135deg, #e3c061, #7a5e24)`, border 1px `iron`, rotate 45°
- Number: Space Mono 700 15px `gold` = `#cda14c`
- Too expensive: icon dark `#3a120e`, border `blood-d`, number `blood-l`

**pit-forge.js atom**: `drawDiamond(buf,cx,cy,r,fill,edge)` — diamond by Manhattan distance.

#### Level pips (duplicates)

- 3 pip slots: each 9×9px diamond rotate 45°
- Filled pip: `gold` with `0 0 5px rgba(205,161,76,.5)`
- Empty pip: bg `#0a0810`, border 1px `brass`
- Label: Space Mono 10px `ink-3`

**pit-forge.js**: `drawLevelPips(buf,W,H,n,t)` — `n` diamonds at 6R+i×9R, pulsing.

#### Rarity scale (R1–R5)

5-segment horizontal bar. Active segment highlighted with gold border + gold pips below. pit-forge.js: `drawRarityScale`.

---

### 2.7 — Stat-line readout

Layout: inline-flex, gap 18px, each: icon + label (Space Mono 10px `ink-3`) + value (Space Mono 700 16px `ink`).

| Stat | Icon |
|------|------|
| HP | 10×10px heart clip-path `blood` |
| DMG | 10×11px sword/drop clip-path `ink-2` |
| CD | 11×11px circle border 2px `brass-l` + 1.5×4px hand `brass-l` |

Modifier readout below divider: Space Mono 700 14px in affliction/regen color + label 11px `ink-3`.

---

### 2.8 — Gauges

#### Health bar

- Height 14px (design) / 16R (pit-forge.js)
- Track: bg `#0a0810`, border 1px `iron`, inset shadow
- HP fill: `linear-gradient(180deg, #c0392f, #5a1714)` (blood-dark to blood-mid)
- **DoT segments**: painted from the front backwards — each fraction shows its affliction color. Shield overlay: diagonal stripe pattern (repeating-linear-gradient 135°, `rgba(111,168,230,.55)` + `.2`) with right border `rgba(111,168,230,.7)`
- Shield: overlap from left edge, striped
- Numeric: `current/max` Space Mono 700 12px `ink`, `+shield` in `shield` color
- Below: affliction chip icons (small)
- pit-forge.js: `drawHealthGauge(buf,W,H,val,segs,accName,t)` — Bayer dither, animated wavefront, segment color from `AFFL` bitmaps below bar

#### Cooldown bar

- Height 8px
- Charging: `linear-gradient(180deg, #d8c270, #8a6e2a)` (muted gold), partial fill
- Ready: `linear-gradient(180deg, #f7e08a, #caa64a)` (bright gold), full fill + `0 0 10px rgba(242,210,74,.4)` box-shadow
- Label: Space Mono 10px; "charging…" in `brass-l`, "READY" in `shock` yellow

#### Lives indicator

5 heart-shaped glyphs (10px×14px, clip-path polygon):
- Active: `blood` fill + `0 0 6px rgba(181,48,42,.5)` glow
- Empty: `stone-700` = `#1d1826`

#### Descent bar (10 wins)

10 equal segments, gap 2-3px:
- Won: `linear-gradient(180deg, #caa64a, #7a5e24)` (brass fill)
- Remaining: `#0a0810` + 1px `stone-700` border

---

### 2.9 — Dividers (3 types)

**Brass diamond divider** (decorative):
- Two lines: `linear-gradient(90deg, transparent, brass, transparent)` — fade to center
- Center: 8×8px diamond `brass-l`, `box-shadow: 0 0 6px rgba(144,113,47,.4)`

**Blood divider** (section break):
- 2px height, `blood-d` = `#48120e`
- `0 0 4px rgba(181,48,42,.4)` glow
- `border-top: 1px iron, border-bottom: 1px iron`

**Text divider** (label between lines):
- Lines: 1px solid `iron`
- Text: Space Mono 10px 0.3em `ink-4`

**pit-forge.js**: `drawDivider(buf,W,H,t)` — animated traveling sparkle on the horizontal line, central diamond pip.

---

### 2.10 — Board slots (6 states)

Slot size: 54×54px (design mockup), 46×46px (molecule view), 54×54px (build screen).

| State | Border | Background |
|-------|--------|-----------|
| empty/unlocked | `#38313f` (muted purple) | `#100a13` |
| occupied + selected | `brass` | diagonal stripe hatch `#2a1f10/#1d1509` |
| neighbor (active edge) | `blood` `#b5302a` + `0 0 9px` glow | `#130d17` |
| drop target (valid) | `#5aa856` green + glow | `#0e1410` |
| locked | `#221c28` (very dim) | `#0a070d`, lock glyph |
| hover (being dragged over) | `brass-s` = `#d8b65e` | brighter hatch |

Active edges between adjacent slots: 2×24px bar in `blood` with `0 0 6px rgba(181,48,42,.7)`.

**pit-forge.js**: `drawSlot(buf,W,H,state,unit,t)` — 6 states. Occupied/neighbor: `stripeFill` with faction dark color, `drawTypePip` at top-left, level diamonds at top-right, rivets at corners.

---

### 2.11 — Unit shop card (boutique)

Width: 152px (molecule), 88px (build screen compact). Height varies (molecule: ~181px, compact: ~84px).

**Structure (molecule / full size)**:
- Bg: `linear-gradient(180deg, #15111d, #0d0a13)`, border 1px `iron`, shadow `0 6px 16px rgba(0,0,0,.45)`
- Top sprite niche: height 92px, diagonal hatch pattern, border-bottom 1px `iron`, faction pip at top-left 7px
- Body padding: 10px 11px 11px
- Name: Cinzel 600 14px `ink`
- Cost: diamond icon + Space Mono 700 13px `gold` (or `blood-l` if too expensive)
- Stats: Space Mono 10.5px — `ink-2` label, `ink` value, letter-spacing 0.02em
- Passive chip: inline chip below stats

**States**:
- Buyable: default styling above
- Hover: border `brass` + `0 0 0 1px brass-d` + `0 0 18px rgba(144,113,47,.28)` — lighter hatch
- Too expensive: opacity 0.72, cost in `blood-l` with dark icon
- Sold: 152×181px bg `#080610`, center: 34×34 diamond border `stone-700` rotated 45° opacity 0.4, label Space Mono 10px 0.24em `ink-5` "SOLD"

**pit-forge.js**: `drawShopCard(buf,W,H,state,unit,t)` — uses `frameM` (GOLD if affordable, dimmed metal otherwise), `stripeFill` portrait area, `drawTypePip`, affliction `blit` icons, name + cost stamped.

---

### 2.12 — Unit detail card

Width: 270px (molecule), 256px (build screen).

- Bg: `linear-gradient(180deg, #16121f, #0c0913)`, border 1px `iron`
- Sprite niche: height 120px (molecule) / 80px (compact), level pips (diamonds) top-right
- Name: Cinzel 700, 17px (mol) / 14px (compact), `ink`
- Faction chip: inline (icon + name)
- Stat bar: bg `#0a0810`, border 1px `iron`, padding 9px 11px — Space Mono stats
- Passive name: Space Mono 9.5–11px `gold`
- Prose: Spectral 12–13.5px `ink-2`, line-height 1.45–1.5
- Divider: 1px `iron`
- Flavor: Spectral italic 300 12.5px `ink-4`, line-height 1.5
- Adjacency block: bg `#0b0912`, border 1px `iron`, small icon + Spectral 11.5px `ink-2` per edge

---

### 2.13 — Relic cards

#### Identified relic card (Width: 248px)

- Bg: `linear-gradient(180deg, #1a140e, #0f0a08)`, border 1px `iron`, `inset 0 1px 0 rgba(216,182,94,.16)`
- Top section (padding 20px, text-center, border-bottom 1px `iron`):
  - Status badge top-right: "INKED" — border 1px `brass`, Space Mono 700 8.5px 0.14em `gold`
  - Icon: 46×46px rotated diamond `linear-gradient(135deg, #7a201a, #3a100c)`, border 2px `iron`, `0 0 16px rgba(181,48,42,.4)` glow, inner 12×12px element in affliction color
  - Name: Cinzel 700 18px `ink`, margin-top 14px
- Body (padding 14px 15px 16px):
  - Sublabel: Space Mono 9px 0.16em `ink-4` "KNOWN EFFECT"
  - Effect: Spectral 14px `ink`, values in Space Mono 700 `blood-l`
  - Divider 1px `iron`
  - Flavor: Spectral italic 300 12.5px `ink-3`

**pit-forge.js**: `drawRelicCard(buf,W,H,state,relic,t)` — corner pieces, veins, large diamond icon (9R radius), `goldText` name + divider + effect + flavor. Selected state elevates glow.

#### Cryptic relic card

- Same structure but bg tinted purple `linear-gradient(180deg, #140e18, #0b070d)`, `inset 0 1px 0 rgba(168,111,196,.12)`
- Status badge: bg `rgba(168,111,196,.14)`, border `#4a2c5a`, text `rot`
- Icon: hatch fill `repeating-linear-gradient(135deg, #1c1322 0 4px, #140d1a 4px 8px)`, centered Cinzel 18px `rot` "?"
- Name shows "? ? ?" in `ink-3`
- Prose: Spectral italic 300 13px `ink-3`

---

### 2.14 — Tooltip / Infobulle

Width: 248px. Arrow: 10×10px `#16111c` bg, border-left + border-bottom 1px `iron`, rotate 45°, position left:-6px top:24px.

Content (padding 13–14px 15px):
- Name: Cinzel 700 15px `ink` + faction chip right-aligned
- Stat bar: bg `#0a0810`, border 1px `iron`, padding 7px 9px — Space Mono 11px stats
- Passive name: Space Mono 10.5px 0.06em `gold`
- Passive chip: inline affliction chip
- Prose: Spectral 13px `ink-2`, line-height 1.5

**pit-forge.js**: `drawTooltip(buf,W,H,t,lines)` — mini panel (B=3R), corner pieces, veins, left-aligned text rows with `goldText` or `stampText` depending on `ln.gold`.

---

### 2.15 — HUD Run banner

Full-width bar, `linear-gradient(180deg, #1d1710, #120d08)`, border 1px `iron`, `inset 0 1px 0 rgba(216,182,94,.22)`.

Segments separated by 1px `iron` vertical dividers:

| Segment | Content |
|---------|---------|
| GOLD | label 8px `ink-4`, value: diamond icon 9×9 + Space Mono 700 14px `gold` |
| LIVES | label + count 8px, 5 heart glyphs (8×11px) |
| DESCENT | label + `7/10` in `gold`, 10-segment descent bar |
| ROUND | label + Space Mono 700 14px `ink` |
| STREAK | label + `WIN x3` in `blood-l` (or LOSS in muted) |
| TIER | label + N diamond pips |

**pit-forge.js**: `drawHudPlate(buf,W,H,t,segments)` — stamps label (dim) + value (goldText) with `|` dividers between segments.

---

### 2.16 — Eco cluster (below HUD)

Inline-flex, bg `linear-gradient(180deg, #16121d, #0e0b13)`, border 1px `iron`.

Left: PURSE — diamond icon 13×13 + Space Mono 700 20px `gold`.
Middle: ECO buttons (REROLL 1g, BUY XP 4g) side by side.
Right: PRIMARY FIGHT button.

---

### 2.17 — Floating combat numbers

Centered display on dark arena bg. Scale: BLADE −12 (26px), CRIT −24! (34px + "!" 18px), others −3 to −6 (24px), SHOCK +15% (22px).

| Source | Color | Glow |
|--------|-------|------|
| BLADE | `blood-l` = `#d8463b` | `rgba(216,70,59,.5)` |
| CRIT | `#ff6a52` | `rgba(255,106,82,.7)` |
| BURN | `burn` = `#e0792e` | `rgba(224,121,46,.55)` |
| BLEED | `bleed` = `#d8475e` | `rgba(216,71,94,.5)` |
| POISON | `poison` = `#93c12f` | `rgba(147,193,47,.5)` |
| ROT | `rot` = `#a86fc4` | `rgba(168,111,196,.5)` |
| SHOCK | `shock` = `#f2d24a` | `rgba(242,210,74,.6)` |
| THORNS | `#c2607a` | none |
| HEAL | `regen` = `#7fbf6a` | `rgba(127,191,106,.5)` |
| ABSORB | `shield` = `#6fa8e6` | `rgba(111,168,230,.5)` |

All: Space Mono 700, text-shadow `0 1px 0 #000` + color glow. Source label below: Space Mono 8.5px 0.1em `ink-4`.

---

### 2.18 — Chronicle log

Container: `linear-gradient(180deg, #14101a, #0c0912)`, border 1px `iron`.

Header: bg `#100d16`, title "CHRONICLE" Cinzel 700 13px 0.06em `ink` + segmented ALL/YOU/FOE.

Each row (padding 6px 14px):
- Timestamp: Space Mono 9.5px `ink-5`
- Description: Spectral 13px `ink-2`, unit names in Space Mono 11px 0.04em (`ink` = friendly, `#c2607a` = enemy)
- Value: Space Mono 700 12px in source color (or affliction chip inline)
- Alternate rows: faint affliction-color tint
- Death row: italic `blood-l`, small heart icon

Tabs (ALL/YOU/FOE): same segmented control as atoms.

---

### 2.19 — Result banners (Destiny banners)

All: overlay on darkened arena, Jacquard 24 font, height 170px.

#### VICTORY

- Bg: `radial-gradient(90% 100% at 50% 40%, rgba(150,40,20,.25), #080510 70%)`
- Gold glow halo: `radial-gradient(60% 60% at 50% 45%, rgba(205,161,76,.16), transparent 70%)`
- Subtitle: Space Mono 9px 0.24em `ink-3`
- Title: Jacquard 24 **54px** `gold` with `0 0 26px rgba(205,161,76,.5)`
- Score: Spectral 12.5px `ink-2`
- Hint: Space Mono 9px 0.12em `ink-5`

#### DEFEAT

Same layout, bg blood: `radial-gradient(90% 100% at 50% 40%, rgba(120,20,16,.3), #080308 70%)`, title in `blood-l` with blood glow.

#### ASCENSION

- Border 1px `brass`, `inset 0 0 0 1px rgba(205,161,76,.12)`
- Ember-glow radial bottom
- Subtitle: Spectral italic 12px `ink-3`
- Title: Jacquard 24 **50px** `ink` with gold glow
- Stats: Space Mono 700 12px 0.1em `gold`

**pit-forge.js**: `drawBanner(buf,W,H,word,kind,t)` — word stamped at 2× pixel scale (each bit rendered as 2×2 pixels), pulsing between `defeat` (blood red) and victory (brass). Two horizontal ruling lines at top/bottom.

---

### 2.20 — Modal dialog

- Backdrop: `rgba(4,2,7,.72)` over dimmed scene
- Dialog: 300px wide, `linear-gradient(180deg, #1a1521, #100c16)`, border 1px `iron`, `0 0 0 1px rgba(216,182,94,.1)`, `0 20px 50px rgba(0,0,0,.7)`
- Top accent: 3px height `var(--metal)` gradient
- Title: Cinzel 700 19px 0.04em `ink`
- Body: Spectral 13.5px `ink-3`, line-height 1.5
- Buttons: STAY (secondary) + ABANDON (primary), gap 12px, margin-top 20px

---

### 2.21 — Settings side panel

Width: 248px, slides from right. Bg: `linear-gradient(180deg, #17121e, #0d0a13)`, border-left 1px `iron`, `box-shadow: -18px 0 40px rgba(0,0,0,.6)`.

Header: bg `#100d16`, border-bottom 1px `iron`, title Cinzel 700 14px `ink` + close button ✕ Space Mono 14px `ink-3`.

Content: toggle rows + slider + radio language select.

---

### 2.22 — Tabs

- Tab bar: border-bottom 1px `iron`
- Active: Space Mono 700 11px 0.14em `ink` + 2px `blood` underline `0 0 7px rgba(181,48,42,.6)`
- Inactive: same font but `ink-3`
- Right side: sort control label Space Mono 10px 0.1em `ink-4`

**pit-forge.js**: `drawTab(buf,W,H,active,label,t)` — active uses `goldText` + panel fill + metal border opening bottom; inactive plain stone dark.

---

### 2.23 — Grimoire codex row

Compact horizontal row for the grimoire grid:
- Width per cell: ~25% of grimoire content area
- Padding: 13px 13px 14px
- Icon: 30×30px rotated diamond (colored bg + inner element for known entries)
- Name: Cinzel 700 12px `ink`
- Effect: Spectral 11.5px `ink-3`, values in Space Mono 700
- Unencountered collection entries may be dimmed, but encountered relic effects are readable.

**pit-forge.js**: `drawCodexRow(buf,W,H,state,entry,known,t)` — thumbnail portrait (stripeFill or "?" for unknown), name + type+rank below.

---

## 3. SCREEN MOCKUPS

### 3.1 Main Menu

Container: max-width 940px, wrapped in reliquary band frame (see §4).

**Inner structure** (height 474px):
- Background: `radial-gradient(120% 120% at 50% 110%, rgba(196,102,58,.22), #0a0712 55%, #060409 100%)`
- Animated ember glow orb bottom center (CSS animation pit-breathe 7s)
- Top label: Space Mono 10px 0.4em `ink-3` "YOU DESCEND"
- Title: Jacquard 24 **74px** `ink`, `0 2px 0 #000, 0 0 40px rgba(181,48,42,.4)`
- Brass/blood divider line (diamond + fading lines, 90+6+90px)
- Menu items stacked, Cinzel weight varying by hierarchy:
  - **ENTER THE PIT**: Cinzel 700 19px 0.1em `ink`, blood diamond prefix, `0 0 16px rgba(181,48,42,.4)` glow
  - Secondary items (THE GRIMOIRE, PROVING GROUND, etc.): Cinzel 500 15px 0.12em `ink-2`
  - Disabled (ABANDON): Cinzel 500 13px 0.12em `ink-4`
- Footer bar: `42/60 RELICS INSCRIBED` in `gold`, version in `ink-5`

**Reliquary band label**: "MAIN MENU" cartouche, Cinzel 700 11px 0.28em `#1c150a` on metal, centered top.

---

### 3.2 Build Screen

Container: max-width 1060px, data-ft="8" (8px frame). Height: 612px.

**Layout** (flex column):

1. **HUD strip** (border-bottom 1px iron): gold / lives / descent / round / streak / tier segments (compact: 8px labels, 14px values)

2. **Sigil title bar** (padding 9px 18px, border-bottom):
   - Left: sigil icon (13×13px circle border `blood`) + name Cinzel 700 15px 0.08em + description Spectral italic 13px `ink-3`
   - Right: "[S] RESHAPE" hint + 5 mini sigil icon buttons (24×24px each, bg `#100b16`)

3. **Arena + detail panel** (flex-1, center, gap 24px):
   - Board: 214×214px grid with edge lines and 9 slots
   - Detail card: 256px wide (unit info + adjacency block)

4. **Shop + eco footer** (border-top 1px iron, bg `linear-gradient(180deg, #100b14, #0a0710)`, padding 11px 14px):
   - "THE OFFERING" label + divider line
   - 5 shop cards (88×84px compact) in flex row
   - Vertical divider
   - ECO cluster: REROLL + BUY XP + FIGHT

**Screen label cartouche**: "BUILD" Cinzel 700 11px 0.3em `#cdbca0` on stone bg, centered top.

---

### 3.3 Combat Screen

Height 430px, bg `linear-gradient(180deg, #0c0810, #140a0e 55%, #2c0e10 100%)`.

**Ambient decoration**: stalactites top (8 triangles `#080510`), ember glow radial bottom.

**"vs" header**: centered, Spectral italic 13px `ink-3` + Cinzel 700 15px 0.08em `ink-2` enemy name.

**Arena** (inset 60px 40px 70px): two team columns (left = player, right = enemy). Each unit: HP bar (54×8px) above portrait block (54×50px, hatch fill). Floating damage numbers above enemies. Affliction icons below affected units.

**Bottom controls**: `auto-battle in progress…` (Space Mono 9.5px `ink-4`) + speed segmented 1×/2× + hotkey hints.

---

### 3.4 Grimoire

Min-height 430px, bg `radial-gradient(120% 100% at 50% 0%, #16111c, #0b0812 70%)`. Padding 24px 26px.

**Header**: "The Grimoire" Cinzel 700 24px `ink` centered + "42 of 60 inscribed" Spectral italic 13px `ink-3`.

**Tabs**: RELICS (active, blood underline) / BESTIARY + sort control.

**Grid**: 4 columns, gap 12px. Each cell = codex row (30px icon diamond + name + effect).

Unencountered: opacity 0.6, empty diamond placeholder.

---

### 3.5 Relic Pick 1-of-3

Min-height 400px, bg `radial-gradient(110% 120% at 50% 100%, rgba(120,40,140,.18), #0a0712 60%)`. Padding 30px 26px.

**Header**: Spectral italic 12.5px `ink-3` flavor line + Cinzel 700 26px `ink` "A Fragment Surfaces".

**Three relic cards** (212px each, gap 18px): all options readable; center card elevated (translateY -6px) with brass border + `0 0 22px rgba(168,111,196,.2)` purple glow.

**Actions**: PRIMARY "BIND THE FRAGMENT" + ghost "REFUSE +2◆".

**Screen label**: "REWARD" Cinzel 700 11px 0.28em `#1c150a`.

---

## 4. RELIQUARY BAND (pit-forge.js)

The engraved border frame is rendered entirely in `_engrave(cv, W, H, T, seed)` — a pure JS ImageData renderer. The `<canvas data-frame data-ft="N">` attribute controls the border thickness T.

### Architecture

```
_scan() — finds all [data-frame] canvases, attaches ResizeObserver
_paint(cv) — measures host clientWidth/clientHeight, internal scale S=3
           — resolves aw=round(dispW/3), ah=round(dispH/3), T from data-ft (min 5)
           — seed = aw*131 + ah*17 + T*101 + 9
_engrave(cv, W, H, T, seed) — main algorithm
```

### fillStrip — base stone band

Fills 4 strips (top/bottom/left/right) of thickness T pixels each:

```
dp = min(x, W-1-x, y, H-1-y)   // depth from edge
if dp === 0        → IRON  [3,2,7]   // outer outline
if dp === T-1      → SHAD  [2,1,5]   // inner shadow
if dp === 1        → LIP   [60,50,68] (or LIPH [96,82,108] 16% chance)
else               → noise between STONE0[13,10,18] / STONE1[22,17,30] / STONE2[6,4,11]
                     using ((x*7+y*13)^...) hash modulo 13 or 5
```

### edge() — incised vein channels (the key algorithm)

Called 4 times (top, bottom, left, right edges). For each edge of length `len`:

4 sinusoidal "streams" (K=4), each defined by:
- `b` = base depth (1.6 to T-3.2, evenly spaced)
- `a` = amplitude (0.9–2.5)
- `f` = frequency (0.085–0.215)
- `p` = phase offset
- `blood` = boolean (50% chance)
- `ds` = deterministic seed offset

Per pixel `t` along edge:
```
u = b + a*sin(t*f + p) + 0.5*sin(t*f*0.43 + p*1.7)
u = clamp(u, 1, T-3)

p = map(t, u)    // maps to actual (x,y) on the edge face
```

The pixel at `p` is set to a transparent/blood color:
- If blood: `BH=[206,78,56]` (6%), `BM=[146,46,33]` (24%), `BL=[82,22,17]` (rest)
- If not blood: `TR=[1,0,3]` (nearly black — carved stone channel)

Adjacent pixel +1 deep: `BD=[36,9,9]` (dark blood) or `BL`.

Drip extension (6% probability): 1–3 pixels extending inward from the channel.

`occ[]` bit array prevents overwrite (first vein wins).

### Corner beads

4 corner positions at (Tc, Tc) etc. where Tc = max(3, T/2):
```
Diamond bead ~5×5: SHAD outer → BM inner → BH center
3-pixel blood drip extending inward from center
```

### Palette summary

| Name | RGB | Use |
|------|-----|-----|
| IRON | [3,2,7] | Outermost pixel |
| STONE0 | [13,10,18] | Base stone fill |
| STONE1 | [22,17,30] | Stone grain lighter |
| STONE2 | [6,4,11] | Stone grain darker |
| LIP | [60,50,68] | Inner stone lip |
| LIPH | [96,82,108] | Lip highlight (16%) |
| SHAD | [2,1,5] | Shadow |
| TR | [1,0,3] | Carved channel (non-blood) |
| BD | [36,9,9] | Blood deep |
| BL | [82,22,17] | Blood mid |
| BM | [146,46,33] | Blood hot |
| BH | [206,78,56] | Blood bright |

### data-ft parameterization

`data-ft="N"` sets thickness T (min 5). Examples in HTML:
- `data-ft="10"` — main design doc outer frame (widest)
- `data-ft="8"` — Build screen (slightly thinner)

All other screens use the smaller frame wrapper: `background:var(--iron); padding:2px` outer + `var(--metal); padding:9px` middle band (brass gradient with 4 corner metal pieces 22×22px) + `background:var(--iron); padding:1px` inner.

### Difference from forge-px.js `frame()`

| | forge-px.js `frame()` | pit-forge.js `_engrave()` |
|---|---|---|
| Renderer | pixel buffer (Buf class) | ImageData direct |
| Palette | METAL (brass: deep/mid/base/hi/spec) | Stone (grey/purple-dark) + blood |
| Effect | Beveled gold frame with highlight/shadow | Incised stone with carved veins + blood |
| Corner | Rivet pixel (4px) | Blood bead |
| Scale | PX=4 (art pixel in display pixels) | S=3 internal decimation then CSS |
| Use | Widget borders inside screens | Screen container border |

The `forge-px.js` frame is the **inner** golden bevel wrapping individual widgets; `pit-forge.js _engrave()` is the **outer** full-screen stone border that holds everything.

---

## 5. CROSS-REFERENCE — Design Components → Lua Modules

| Design Component | Existing Lua Module | Notes |
|-----------------|---------------------|-------|
| Token colors + fonts | `src/ui/theme.lua` | Already has palette, needs brass/stone tokens verified; Jacquard → display voice |
| Rect/text/divider/pip/bar | `src/ui/draw.lua` | Draw.rect, Draw.text, Draw.divider, Draw.pip, Draw.bar — covers most atoms |
| Frame (bevel + gilded + states) | `src/ui/frame.lua` | Frame.draw — maps to forge-px.js `frame()` atom |
| Keyword pastille chips | `src/ui/chip.lua` | Maps to §2.5 type/affliction chips |
| Affliction registry | `src/ui/keywords.lua` | Maps to §III icon shapes + §2.5 affliction chips |
| Baked widgets | `src/ui/forge.lua` | uiButton → PRIMARY/SECONDARY; uiCard → shop card; uiPlate → HUD plate; uiSocket → slot; valueTag → badges; label → text; diamondAt → cost icon; coinAt → gold display |
| Row/column layout | `src/ui/layout.lua` | HUD strip, eco cluster |
| Frozen rig | `src/render/minirig.lua` | Unit portrait in cards (replaces hatch placeholder) |
| TCG unit card | `src/render/monstercard.lua` | Maps to detail card §2.12 |
| HP bar | `src/render/healthbar.lua` | Maps to §2.8 health gauge (needs DoT segments + shield overlay) |
| Combat chronicle | `src/render/chronicle_draw.lua` + `chronicle_overlay.lua` | Maps to §2.18 chronicle |
| Affliction VFX | `src/render/affliction_fx.lua` + `affliction_icons.lua` | Maps to floating numbers §2.17 + icons |

### NEW components to create

| Component | Priority | Notes |
|-----------|----------|-------|
| Engraved stone border (`ui/reliquary.lua`) | HIGH | Port `_engrave()` algorithm: canvas-equivalent in LÖVE using `ImageData:setPixel`, baked once per screen size change |
| Board graph renderer (`ui/board_view.lua`) | HIGH | Slots + edges + 6 slot states; currently handled in `scenes/build.lua` inline |
| Floating damage numbers (`ui/floatnum.lua`) | MED | Colored + glow per source type |
| Result banner (`ui/banner.lua`) | MED | Jacquard font + double-line rules + overlay |
| Relic card (`ui/relic_card.lua`) | MED | Readable effect + flavor; diamond icon |
| Codex grid row (`ui/codex_row.lua`) | MED | Grimoire 4-col grid entry |
| Modal dialog (`ui/modal.lua`) | LOW | Centered overlay with STAY/ABANDON |
| Settings side panel (`ui/settings_panel.lua`) | LOW | Slide-in from right |
| Sigil icon buttons (5 shapes) | LOW | Extend `ui/forge.lua` drawIconBtn or chip |
| Tab bar (`ui/tabs.lua`) | MED | Active blood-underline vs inactive |
| Slider control (`ui/slider.lua`) | LOW | Brass/blood fill, brass thumb |
| Descent progress bar (10 segs) | MED | Extend `ui/draw.lua` or `healthbar.lua` |

### Existing to re-skin

| Module | Change needed |
|--------|-------------|
| `src/ui/forge.lua` uiButton | PRIMARY styling: blood gradient fill + inset shadows; ensure glow on hover |
| `src/render/healthbar.lua` | Add DoT segment painting from front; add shield diag-stripe overlay |
| `src/render/monstercard.lua` | Align to 270px layout, ensure flavor line, adjacency block |
| `src/ui/chip.lua` | Add pill shape support for affliction chips; add "status" chip variant |

---

## 6. DELTA

### 6a — Font mapping (CLAUDE.md runtime fonts vs. design system roles)

| Design role | Font from §II | CLAUDE.md current token | Size from §II scale |
|-------------|--------------|------------------------|---------------------|
| displayBig (title screen, banners) | Jacquard 24 | `display` (Jacquard) | 50–88px (design: 74px menu, 54px banner) |
| display (sub-ceremonial) | Jacquard 24 | `display` | 30–50px |
| title / screen titles | Cinzel 800 | `title` (Cinzel 800) | 22–30px |
| heading / unit names / cards | Cinzel 700 | `heading` (Cinzel 700) | 15–18px |
| subhead / secondary nav | Cinzel 600 | `subhead` (Cinzel 600) | 13–15px |
| body / prose / descriptions | Spectral 400 | `body` (Spectral 400) | 13–15px |
| bodyMed / effect text emphasis | Spectral 500 | `bodyMed` (Spectral 500) | 13–14px |
| bodyLight / secondary prose | Spectral 300 | `bodyLight` (Spectral 300) | 13–14px |
| flavor / lore italic | Spectral 300 italic | `flavor` (Spectral 300 italic) | 12–14px |
| label / buttons / chips | Space Mono 700 | `label` (SpaceMono 700) | 10–13px |
| labelSmall / hints | Space Mono 400 | `labelSmall` (SpaceMono 400) | 9–10px |
| value / all numbers | Space Mono 700 | `value` (SpaceMono 700) | 11–16px |

**Critical rule from §II**: Jacquard is used for *at most a few words per run* — title, Victory, Defeat, Ascension. Never for stat values or prose. Space Mono for all numbers (tabular, unambiguous). Spectral for all flowing prose.

### 6b — Surprising decisions flagged from §IV+ and pit-forge.js

1. **The reliquary border is NOT a static image or CSS box-shadow.** It is a pixel-level procedural algorithm that re-renders when the host element resizes (ResizeObserver). This means in LÖVE we must re-bake the border `ImageData` whenever the window/canvas size changes. Performance: only the border strip (T pixels wide) is recomputed; the content area is untouched. **Lua port: bake to a `love.image.newImageData` once, stamp via nearest-filter sprite.**

2. **Blood veins are seeded per-frame-instance, not global.** The seed is derived from `aw*131 + ah*17 + T*101 + 9`, meaning different-sized frames get different vein patterns. This is intentional — every container looks slightly different.

3. **Superseded relic-content note.** The original mockup hid the 1-of-3 relic effects, but the current game design shows readable effects immediately. Keep the layout/elevation treatment, not the hidden-identification rule.

4. **Shop cards have no rarity visual yet** — the mockup shows uniform brass treatment for affordable, dimmed grey for too-expensive. Rarity tiers (R1–R5) are captured in the codex row only. This aligns with the CLAUDE.md note "boutique sans raretés/cotes-par-niveau (pool uniforme)".

5. **Board slot "neighbor" state uses blood border + blood-tinted bg, NOT a buff highlight.** The red glow on adjacent cells when one is selected communicates "adjacency synergy active", which is the core mechanic. Drop-target (valid placement) uses GREEN border — the only green in the entire palette.

6. **The BUILD screen is the densest layout** — it packs HUD + sigil controls + 214×214 board + 256px side panel + 5-card shop + eco cluster into one viewport. The designer resolved this by keeping the board centered and the shop at the bottom, making the board the visual focal point.

7. **Floating combat numbers use the exact affliction color** (not a desaturated version) with a matching glow. CRIT uses a special brighter orange (`#ff6a52`) not in the main palette, which is intentional — it's the only value that "bleeds" out of the standard palette to signal exceptional impact.

8. **pit-forge.js has `drawScrollList` + `drawScrollbar`** which are not in the HTML design doc at all. These are extra components for the Grimoire list view. The scrollbar uses a `metalBorder`-framed thumb (panelFill + metalBorder). This must be implemented in LÖVE alongside the existing scissor-clip pattern (`Draw.scissor`).

9. **`drawSigil(buf,W,H,press,glow,seed,t,kind)`** exists in pit-forge.js (kind 0–3: cross, diamond, star, grid). These are the sigil selector icons in the build screen header. They generate animated point-clouds (`glyphPts`) rendered via `goldText` — creating a "living glyph" effect. The sigil kind maps to the board shapes (0=cross, 1=diamond, 2=star, 3=grid/line).

10. **`drawHudPlate` uses `stampText` for labels (dim color) and `goldText` for values** — this implements the exact §II before/after contrast: label in near-invisible tone, value in bright gold that pops. All HUD numbers are goldText with a 0.3 glow.
