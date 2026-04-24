# 03 — Design System Brief

> **Audience**: `pit-terminal-ux` agent (or any designer picking up the kit).
> **Purpose**: everything needed to produce the V1 design system *before* writing gameplay screens. When an actual component or screen comes up later, we should mostly be *assembling*, not *deciding*.
> **Scope**: visual language, foundations, component catalog (generic + game-specific), screens, states, motion, a11y, iconography, asset pipeline, deliverables.

---

## 1. Project recap (one paragraph for cold start)

The Pit is an idle-roguelite delve game in the browser. Players descend through a procedural node map (combat / elite / event / shop / rest / cache / boss), auto-battle with an 8-card loadout, loot cards that behave like RPG gear, and spend scrap at the Camp on passive upgrades between runs. Offline is capped flavor (8h, 25% rate, no depth); the real progression is active play. Server-authoritative via Convex. Boss V1 = *The Pit Warden*. Tagline: *an idle roguelite where every descent writes your economy*.

---

## 2. Visual direction — "premium terminal"

The target is **not "ASCII game"** and not "Bootstrap-with-monospace". It is what the current generation of terminal-first tools and games has proven: a terminal *is* a legitimate premium UI surface when the craft is there.

### 2.1 Primary references (study these)

**Terminal-native tooling (craft benchmark)**

| Ref | Why it matters |
|---|---|
| **OpenCode** (sst.dev/opencode) | Best-in-class AI CLI chrome — rounded box drawing, selectable highlight, clear hierarchy, warm dark palette, generous breathing room inside tight containers |
| **Warp** | Monospace + modern chrome. Ligatures. Muted palette with a few accents. Buttons feel like buttons without losing the terminal soul |
| **Zed** editor | Monospace-first, but the UI chrome is buttery. Shows that "terminal-inspired" can be premium |
| **Charm Bubble Tea / lip gloss demos** | Go TUI kit — progress bars, spinners, dialogs, lists. The gold standard for "friendly terminal" aesthetics |
| **lazygit / gh-dash / bottom (btm) / k9s** | How dense TUIs handle navigation, status bars, modal help, keyboard-first interaction |
| **superfile** | Terminal file manager with real chrome — proves you can have sidebars, previews, breadcrumbs, drag-like interactions in a TTY aesthetic |
| **glow / Charm gum** | Reading typography in the terminal — line height, margin discipline |

**Terminal-native games (game-feel benchmark)**

| Ref | Why |
|---|---|
| **TinyRogue** | Minimal ASCII tiles, limited palette, everything readable at a glance |
| **Cogmind** | Proves terminal UI can carry a real, juicy combat game. Particles, intents, logs, stats panels coexist without overload |
| **Caves of Qud** | ASCII/sprite hybrid, readable tooltips, dense but navigable inventory |
| **Loop Hero** | ASCII + small sprites, warm sepia palette, *readable* systems |
| **Cultist Simulator** | Typography-as-character, cards-as-verbs. Shows narrative weight of text |
| **Dwarf Fortress (Premium)** | Pixel tiles slotted into a fundamentally text grid — our hybrid template |

### 2.2 What "premium terminal" means for The Pit

Craft signals to hit:
- **Disciplined grid.** Everything aligns on a monospace ch-grid *and* an 8px pixel-grid simultaneously. Nothing floats.
- **Restrained palette.** Seven-ish colors, no gradients on UI chrome. Color carries meaning, not decoration.
- **Box drawing that earns its keep.** A `Frame` is never decorative — it groups, labels, or signals. Corners tell the user what kind of thing they're looking at (single vs double vs round).
- **Generous *negative* space inside tight containers.** Terminal UIs can be dense, but premium ones breathe inside boxes. Target: `1ch` padding horizontal minimum, `0.5lh` vertical.
- **Weight over size.** Hierarchy via weight, dim/bright, brackets, and position — not big fonts. 14px body, 16px for "hero" lines, 20px only for screen titles.
- **One accent per view.** If three things are green on screen at once, none of them are important.
- **Linear/step motion only.** Spring bounces scream "React app". We want `linear`, `steps()`, and short durations (80–160ms).
- **Diegetic chrome.** Buttons that look like `[ Descend ]`. Dropdowns that look like `▾`. Cursors that blink.

### 2.3 Anti-patterns (explicit "no")

- No rounded CSS corners (`border-radius > 0` is forbidden on chrome). Use `╭╮╰╯` glyphs if you want rounding.
- No gradients. Solid fills only. Opacity steps are OK.
- No drop shadows beyond `0 1px 0 rgba(0,0,0,.4)`-level hairlines.
- No emoji in UI (but Unicode geometric glyphs are the icon language, see §12).
- No spring/bounce/overshoot easings.
- No dark/light toggle — The Pit is always dark (`pit-ink`).
- No more than one typeface family at a time (Monaspace superfamily is fine; no mixing in a serif).
- No skeuomorphic "parchment" or "stone" textures.
- No `shadcn/ui`, no `Radix Themes`, no pre-themed component kits. (Radix *primitives* are OK purely as a11y plumbing behind our chrome.)

---

## 3. Foundations

### 3.1 Color tokens (extends current `@theme`)

The current `src/index.css` already defines the base six; this doc locks roles and adds semantic aliases.

**Palette (raw)**

| Token | Hex | Role |
|---|---|---|
| `--color-pit-ink` | `#0a0a0a` | Primary background |
| `--color-pit-ink-2` | `#111111` | Elevated background (panels on bg) |
| `--color-pit-ink-3` | `#181818` | Highest elevation (modals on panels) |
| `--color-pit-line` | `#2a2a2a` | Box-drawing lines, dividers, inactive borders |
| `--color-pit-line-bright` | `#3a3a3a` | Hover / focused borders |
| `--color-pit-dim` | `#6b6b6b` | Secondary text, placeholders |
| `--color-pit-bone` | `#d8cfb8` | Primary text, active chrome |
| `--color-pit-bone-bright` | `#f2ecd9` | Selected text, active headings |
| `--color-pit-green` | `#9ae66e` | Positive, accent, primary action |
| `--color-pit-amber` | `#d4a147` | Warning, gated, locked |
| `--color-pit-red` | `#d45a5a` | Danger, crit, loss |
| `--color-pit-violet` | `#9a7bd4` | Rare/T0, special |
| `--color-pit-cyan` | `#6ec3d4` | Info, defensive keywords |

**Semantic aliases (derived)**

Add these so components don't reference raw palette:

```css
--color-fg: var(--color-pit-bone);
--color-fg-muted: var(--color-pit-dim);
--color-fg-inverted: var(--color-pit-ink);
--color-bg: var(--color-pit-ink);
--color-bg-raised: var(--color-pit-ink-2);
--color-bg-overlay: var(--color-pit-ink-3);
--color-border: var(--color-pit-line);
--color-border-strong: var(--color-pit-line-bright);
--color-accent: var(--color-pit-green);
--color-warn: var(--color-pit-amber);
--color-danger: var(--color-pit-red);
--color-rare: var(--color-pit-violet);
--color-info: var(--color-pit-cyan);

/* Tier mapping for cards & loot */
--color-tier-3: var(--color-pit-bone);
--color-tier-2: var(--color-pit-green);
--color-tier-1: var(--color-pit-amber);
--color-tier-0: var(--color-pit-violet);
```

**Contrast** — every fg/bg pairing must clear WCAG AA (4.5:1 body, 3:1 large). `pit-dim` on `pit-ink` is the borderline case, use sparingly.

### 3.2 Typography (from D2 research, locked)

```
Splash / screen title    Xenon          24px  Bold
Panel heading / modal    Krypton or     20px  Bold
                         Neon bold
Section subhead          Neon           16px  Medium
Important values / stat  Neon           16px  Medium (tabular)
Body / logs / cards      Neon           14px  Regular
Narrative / event flavor Argon          14–16px Regular italic
Item names (rare/legend) Xenon          variable
Meta / timestamps / kbd  Argon          12px  Regular, opacity 0.6
```

- Line-height: dense tables/logs `1.25–1.35`, paragraphs `1.45–1.6`, buttons `1.2`.
- Letter-spacing: 0 by default; `0.04em` for SMALL CAPS labels only.
- `font-variant-numeric: tabular-nums` on anything showing stats.
- Ligatures: contextual on narrative, **off** in stats tables (breaks alignment).

### 3.3 Spacing scale

Hybrid scale — monospace `ch` for inline alignment, pixel `rem` for block spacing.

```
--space-0: 0;
--space-1: 0.25rem; /* 4px */
--space-2: 0.5rem;  /* 8px — base tick */
--space-3: 0.75rem;
--space-4: 1rem;
--space-5: 1.5rem;
--space-6: 2rem;
--space-8: 3rem;
--space-12: 5rem;
```

Rule: block margins/padding in `rem` (aligned to 8px grid). Inline padding inside a monospace container in `ch` (keeps glyphs aligned).

### 3.4 Radius, borders, elevation

- `--radius-0: 0` — default for all chrome.
- No `border-radius > 0` elsewhere. Rounded feel = `╭╮╰╯` glyphs.
- Borders: `1px solid var(--color-border)` default, `1px solid var(--color-border-strong)` on hover/focus.
- "Elevation" = background shift (`bg` → `bg-raised` → `bg-overlay`) + a `1px` top highlight via `box-shadow: inset 0 1px 0 rgba(255,255,255,0.02)`. Nothing more.
- Modal overlay: `background: rgba(10,10,10,0.75)` + `backdrop-filter: blur(2px)`. Blur subtle.

### 3.5 Motion rules (locked)

| Token | Duration | Easing | Use |
|---|---|---|---|
| `--motion-instant` | `0ms` | — | State flips (hover color) |
| `--motion-short` | `80ms` | `linear` | Hover / press feedback |
| `--motion-base` | `160ms` | `cubic-bezier(.4,0,.2,1)` | Modal open, tab switch |
| `--motion-long` | `280ms` | `linear` | Page route transition |
| `--motion-typewriter` | `16–30 chars/s` | — | Narrative reveal |

No spring. No bounce. No overshoot. No "elastic". Period.

Reduced-motion: honor `prefers-reduced-motion`. Replace all > `--motion-short` animations with instant transitions. CRT/flicker effects fully off.

### 3.6 Z-index scale

```
--z-base: 0;
--z-raised: 10;
--z-sticky: 20;
--z-dropdown: 100;
--z-tooltip: 200;
--z-overlay: 500;
--z-modal: 600;
--z-toast: 700;
--z-debug: 9999;
```

---

## 4. Core UI components (generic kit)

Every component below needs: **API spec**, **all states**, **keyboard behavior**, **a11y notes**, **2+ usage examples**. The specialist expands each into its own sub-doc or Storybook-style gallery entry.

States taxonomy (apply to every interactive component):
`default · hover · focus-visible · active (pressed) · disabled · loading · error · success · selected · dragging · readonly · empty`

### 4.1 Containers / surfaces

| Component | Purpose / notes |
|---|---|
| **Frame** | Box-drawing container with optional title. Variants: `single`, `double`, `round`, `heavy`, `dashed`. Props: `title`, `titleAlign`, `footer`, `status` |
| **Panel** | Non-bordered grouped surface (uses bg-raised). For dense regions without box-drawing |
| **Card** | Semantic card — uses Frame internally. Variants: `default`, `interactive`, `selected`, `locked` |
| **Divider** | Horizontal/vertical. Char variants: `─`, `═`, `┈`, `╍` |
| **Section** | Spaced titled block, no border, used on pages |
| **ScrollArea** | Custom scrollbar (thin, terminal-styled, `▓░` track) |
| **Splitter** | Draggable divider between two panes (for future inventory/preview splits) |

### 4.2 Primary inputs (buttons + form controls)

| Component | Purpose / notes |
|---|---|
| **Button** | Variants: `primary` (accent bg), `default` (bordered), `ghost` (text only), `danger`, `subtle`, `link`. Sizes: `sm`, `md`, `lg`. Loading spinner inline. Chrome example: `[ Descend ]` |
| **IconButton** | Square, icon-only (glyph-based). Tooltip required. |
| **Toggle / Switch** | `[ON ] / [OFF]` or `[◉○○] / [○○◉]` terminal style |
| **Checkbox** | `[x]` / `[ ]` explicit ASCII. `[-]` for indeterminate |
| **Radio** | `(o)` / `( )` |
| **TextInput** | Single-line. With/without leading glyph, clear button, inline validation |
| **NumberInput** | Spinner controls as glyphs `▲▼`. Step, min, max. Uses tabular nums |
| **PasswordInput** | Masked with ability to reveal |
| **SearchInput** | With `⌕` leading glyph and `⌫` clear |
| **Textarea** | Multi-line, autosize, char count |
| **Select (native)** | Dropdown styled to match, custom caret `▾` |
| **Combobox** | Searchable select with keyboard nav |
| **Multiselect** | Tag-based selection inside input |
| **Slider** | Horizontal, tick marks, label. ASCII variant `▸━━━●━━━` |
| **RangeSlider** | Two-handle |
| **Segmented control** | `[ All | Owned | Equipped ]` |
| **TagInput** | Add/remove chips |
| **KbdInput** | Record a key/chord (for keybinding settings) |
| **FilePicker** | (Future — import/export save) |

### 4.3 Display / data

| Component | Purpose / notes |
|---|---|
| **Label** | Form label. Required marker `*` in amber |
| **Helper text** | Below input, dim |
| **Badge** | Small status chip: `RARE`, `T0`, `DEAD`, `LOCKED` |
| **Chip** | Removable tag (larger than badge) |
| **Kbd** | `<Esc>`, `<Enter>` styled with monospace frame |
| **Code** | Inline `` `code` `` |
| **Stat** | Label + value pair, aligned. Variants: `inline`, `stacked`, `big` |
| **StatRow / StatBlock** | Grouped stats (ATK/DEF/HP/SPD/PWR) |
| **Bar** | Horizontal progress. Variants: `ascii` (`[████░░░░]`), `block` (`▉▊▋▌▍▎`), `smooth` (CSS). Color by context (HP=green, torch=amber, meter=cyan) |
| **SegmentedBar** | Boss health chunks — one segment per phase |
| **Meter** | Similar to Bar but semantic (action meter bps) |
| **Gauge** | Circular/arc variant for drama (optional, P2) |
| **Ring** | Radial progress glyph (`◔◑◕●`) |
| **Avatar** | User twitch pic in a `[ ]` frame |
| **Breadcrumb** | `Camp > Deck > Edit` |
| **Tabs** | Top-tabs with underline on active, vertical variant for side panels |
| **Tooltip** | Hover, keyboard-triggerable, delayed 300ms |
| **Popover** | Persistent until dismissed, pointed arrow glyph |
| **Log** | Scrolling timestamped list. Variants per event type, color-coded. Auto-scroll with pause-on-hover |
| **Table** | Sortable, filterable, stickyheader, monospace-aligned columns. Row selection modes |
| **List** | Virtualized for big inventories (cards) |
| **Tree** | For nested data (passive tree nav) |
| **KeyValueGrid** | Two-column dense info |
| **DescriptionList** | `<dl>` styled for specs (name/desc pairs) |
| **Pagination** | `< 1 2 3 ... 12 >` |
| **Empty state** | Illustrated (ASCII art) + CTA |
| **Skeleton** | Loading placeholder, animated with `▒▓░` shimmer |
| **Spinner** | `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` braille or `|/-\` simple |
| **ProgressBar** (generic, non-game) | For form submit, file upload future |

### 4.4 Feedback

| Component | Purpose |
|---|---|
| **Toast** | Transient notification, top-right. Variants: success/warn/error/info. Typewriter in OK |
| **Alert / Banner** | Persistent inline alert |
| **Dialog / Modal** | Blocking. Double-border Frame variant |
| **Drawer / Sheet** | Slide-in from right (future settings, inventory compare) |
| **ConfirmationDialog** | "Retreat? You will lose 50% in-run inventory." |
| **ErrorBoundary** | Full-screen fallback with ASCII frown |
| **Notification stack** | Manages multiple toasts, max 3 visible |

### 4.5 Navigation

| Component | Purpose |
|---|---|
| **CommandPalette** | `⌘K` — fuzzy search over routes + actions. Terminal-native feel |
| **Menubar** | Top nav for Camp: `[D] Delve  [P] Passives  [C] Cards ...` |
| **SideNav** | Persistent left nav (future nested menus) |
| **TabBar** | Top tabs across sub-sections |
| **ContextMenu** | Right-click menu (future, for card inventory ops) |
| **MenuItem / Separator** | Primitives for menus |

### 4.6 Overlays & portals

| Component | Purpose |
|---|---|
| **Portal** | Primitive for rendering outside DOM flow |
| **FocusTrap** | For modals |
| **Overlay** | Scrim + click-outside-to-close |

### 4.7 Utility

| Component | Purpose |
|---|---|
| **VisuallyHidden** | For screen-reader-only text |
| **Box / Stack / Inline / Grid** | Layout primitives (maybe, or pure Tailwind) |
| **ClickOutside** | Hook/component primitive |
| **KbdHandler** | Global/local keyboard map declaration |
| **LiveRegion** | ARIA live region for log announcements |

---

## 5. Game-specific components

These are built on top of the generic kit. A separate specialist may design these, but the vocabulary lives here so the design system is ready.

### 5.1 Cards & deck

| Component | Purpose |
|---|---|
| **PitCard** | The core card. Preview size (in deck grid) and detail size (in modal). Shows: name, tier, tags, stats, keywords, trigger, flavor, slot role |
| **CardSlot** | Slot in the 8-slot loadout. Shows what's equipped or empty state. Types: mainhand, offhand, body, charm×2, focus, tactical, minor |
| **Loadout** | Full 8-slot visualization, body-silhouette or grid layout |
| **CardPreview** | Small card variant for reward lists |
| **CardStack** | Stacked multiple copies (for duplicates/shards) |
| **DeckGrid** | Inventory view — sortable, filterable, virtualized |
| **KeywordBadge** | One per keyword. Tooltip with full description |
| **TagChip** | For card tags (bleed, block, burn, gold, thorns, etc.) |
| **RarityBadge** | `T3 T2 T1 T0` chip with color |
| **ScalingStatIndicator** | Shows what a card scales with (`↑ missingHp`, `↑ depth`) |
| **CardDetail** | Full detail modal — stats, all keywords, override description, lore |

### 5.2 Delve map

| Component | Purpose |
|---|---|
| **DelveMap** | Full map renderer. Vertical scroll. Displays 2–3 upcoming rows. Seeded — layout is deterministic |
| **DelveRow** | One row of 2–3 node choices |
| **DelveNode** | Single node. Icon (by type), primary reward preview, danger rating, torch cost, pity pip if advancing |
| **DelveEdge** | Connection line between rows. Box-drawing (`│╲╱╳`) or subtle SVG |
| **CurrentMarker** | Visual marker for player's current position |
| **DepthGauge** | Sidebar showing depth `D012`, total torch, max depth record |
| **PathPreview** | Hover-tracing — highlights visible future branches |
| **BossBanner** | At boss rows, a double-framed warning `╔══ BOSS — THE PIT WARDEN ══╗` |

### 5.3 Combat

Combat mixes DOM (chrome) + PixiJS (arena). Both are part of the system.

**DOM (chrome):**

| Component | Purpose |
|---|---|
| **CombatLayout** | 3-column: player loadout | arena | enemy intents & log |
| **HealthBar** | Player/enemy HP. Shows current/max, damage trail |
| **ActionMeter** | 0–10000 bps bar per actor |
| **IntentBadge** | Enemy telegraph — "attacks 47", "buffs", "dodges" |
| **KeywordStack** | Active buffs/debuffs on a unit, sorted by magnitude |
| **CombatLog** | Timestamped events, color-coded per type |
| **DamageNumber** | (DOM variant for sidebar list of recent hits) |
| **BossHealthBar** | Multi-segmented, one chunk per phase |
| **CombatToolbar** | Focus button, retreat, speed toggle (1×/2×/4×), pause |
| **FocusGauge** | Current Focus resource |

**PixiJS (arena):**

| Element | Purpose |
|---|---|
| **BattlefieldScene** | Main Pixi Application |
| **ActorSprite** | 32×32 or 48×48 enemy/player sprite |
| **DamageNumberLayer** | Pooled floating numbers (Pop → Float → Sink) |
| **HitFlash** | Overlay flash on damaged target |
| **AttackVFX** | Per attack-style (slash/thrust/smash/bolt) |
| **ScreenShake** | Scaled by crit/boss hit |
| **ParticleLayer** | Pooled particles (burn, poison, sparks) |

### 5.4 Camp hub

| Component | Purpose |
|---|---|
| **CampScreen** | The main hub layout |
| **PassiveTree** | Node-graph visualization of upgrades. Could be Pixi for dense trees, or DOM/SVG for small |
| **PassiveNode** | Single upgrade — cost, current/max level, effect |
| **ShopGrid** | Offers in the shop |
| **ShopItem** | One purchasable item (card, consumable, reroll) |
| **CurrencyBar** | Gold, scrap, shards, torch displayed top-right |
| **CodexEntry** | Encyclopedia entry (keywords, enemies, cards, lore) |
| **Codex** | Full codex navigation |

### 5.5 Events, rest, boss

| Component | Purpose |
|---|---|
| **EventPanel** | Narrative event with 2–4 choices. Typewriter reveal |
| **EventChoice** | One option with risk/reward preview |
| **RestMenu** | Heal, upgrade card, remove curse, swap card |
| **BossIntroSplash** | Full-screen intro on boss node entry |
| **BossPhaseTransition** | Mid-combat phase change visual |
| **LootReveal** | Post-combat drop animation. Variants per rarity (T0 has glyph rain + delay) |
| **RewardChoice** | Pick 1 of N (Slay-the-Spire reward screen) |

### 5.6 Meta screens

| Component | Purpose |
|---|---|
| **TitleScreen** | Splash with tagline and `[ Press any key ]` |
| **TwitchLoginButton** | Auth entry point |
| **WelcomeBackModal** | Offline gains summary |
| **RunResult** | Post-death / retreat screen. Stats, loot kept, new records |
| **Leaderboard** | Max-depth ranking, server-derived |
| **LeaderboardRow** | Avatar, handle, depth, time |
| **Settings** | Audio, reduced motion, accessibility, account |
| **Keybindings** | Editable map of shortcuts |

---

## 6. Screen inventory (every wireframe we'll need)

Each needs an ASCII wireframe + a list of components used + keyboard map.

| # | Screen | Priority | Notes |
|---|---|---|---|
| 1 | Title / splash | V1 | Minimal, logo ASCII |
| 2 | Auth (Twitch login) | V1 | Single CTA |
| 3 | Camp hub | V1 | Primary between-run screen |
| 4 | Passive tree | V1 | Biggest UI challenge |
| 5 | Deck manager | V1 | List + card detail split |
| 6 | Shop (camp) | V1 | Simple grid |
| 7 | Delve map | V1 | Node graph + current marker |
| 8 | Combat | V1 | Mixed DOM + Pixi |
| 9 | Event dialog | V1 | Narrative + choices |
| 10 | Rest node | V1 | Menu |
| 11 | Shop (in-delve) | V1 | Grid variant |
| 12 | Loot reveal / reward choice | V1 | Post-combat |
| 13 | Welcome back | V1 | Modal |
| 14 | Run result (death/retreat) | V1 | Stats + claim |
| 15 | Leaderboard | V1 | Table |
| 16 | Settings | V1 | Simple form |
| 17 | Codex | P1 | Nav + article |
| 18 | Keybindings | P1 | Editable list |
| 19 | Onboarding / tutorial | P1 | Inline hints, no modal |
| 20 | Error / 404 | V1 | ASCII frown + home CTA |

---

## 7. Interaction patterns

- **Keyboard-first.** Every screen navigable without a mouse. `Tab` order explicit, `Esc` always backs out, `Enter` always confirms. Letter shortcuts (`[D]elve`) on the Camp.
- **Hover is free, click is committed.** Hover never mutates state. Everything destructive has a confirm.
- **No modal-within-modal.** Max one overlay at a time. If you need a second, redesign.
- **Optimistic UI for reversible actions only** (equip preview, navigation highlight). Never for server-authoritative results (loot drop, gold gain).
- **Logs are sources of truth for "what happened."** The welcome-back modal duplicates the log — but the log persists.
- **Speed controls on auto-combat.** `1×`, `2×`, `4×`, `pause`. Same hotkey as CLI REPLs (`space`, `.`).
- **Drag and drop optional.** Keyboard equivalent must always work. If DnD is added (card equip), fallback is `Equip → select slot`.

---

## 8. Iconography

Strategy: **Unicode geometric + custom pixel icons**. No emoji, no raster icon library.

### 8.1 Glyph vocabulary (reuse consistently)

| Glyph | Meaning |
|---|---|
| `◆ ◇` | Rare card / item |
| `◈` | Boss / unique |
| `● ○` | Filled / empty slot |
| `▲ ▼` | Increase / decrease |
| `▸ ▾` | Disclosure (collapsed / expanded) |
| `✓ ✗` | Success / fail |
| `✸ ✦` | Special action, focus |
| `⚔` | Combat node — used sparingly, not quite terminal-native |
| `♦ ♥ ♣ ♠` | Suits (cards) — avoid, too playing-card |
| `⌕` | Search |
| `⌫` | Clear / delete |
| `⏻` | Power / exit |
| `⏵ ⏸ ⏹ ⏩` | Play / pause / stop / fast-forward |
| `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` | Braille spinner |
| `→ ← ↑ ↓` | Directions |
| `─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼` | Box drawing — single |
| `═ ║ ╔ ╗ ╚ ╝ ╠ ╣ ╦ ╩ ╬` | Box drawing — double |
| `╭ ╮ ╯ ╰` | Rounded corners |

### 8.2 Pixel icons (custom, when glyph insufficient)

Format: 16×16 or 24×24, single-color + transparent. Drawn in Aseprite. One icon sheet per domain:
- `nodes.png` — combat/elite/event/shop/rest/cache/boss node icons
- `keywords.png` — one per keyword
- `resources.png` — gold, scrap, torch, shard, focus, HP

Style constraints: flat, 1px silhouette, no anti-aliasing. Colors from palette only.

---

## 9. Responsive & performance

- **Desktop-first.** Min 1024px width. Graceful scale to 2560px.
- **No mobile V1** — the box-drawing aesthetic breaks at phone width. Show a "desktop only" notice on narrow screens.
- **Target 60fps.** CSS `transform` and `opacity` for motion. No `width/height` animations.
- **Pixi Application size** reused, not recreated on route change.
- **Font loading**: Monaspace via `@font-face` with `font-display: swap`. Fallback stack always readable even pre-load.
- **Bundle**: component kit should lazy-load per-route. Combat chunk separate from Camp chunk.

---

## 10. Accessibility

- **WCAG AA minimum** (contrast, focus visible, keyboard).
- **Focus ring** = `outline: 2px solid var(--color-accent)` + `outline-offset: 2px`. Always visible on `:focus-visible`.
- **Semantic HTML** where possible (`<button>`, `<input>`, `<dialog>`). Custom only when needed.
- **ARIA** on composite widgets (tabs, combobox, dialog).
- **Screen reader announcements** for combat log events via `aria-live="polite"`.
- **Reduced motion**: honor `prefers-reduced-motion: reduce`. Typewriter becomes instant. CRT effects off.
- **Color-blind safe**: never use color as the only signal. Add glyph or text. Test palette with Sim Daltonism.
- **User font-size respect**: root font-size in `rem`, user's browser zoom works.
- **No autoplay audio**. All sound gated behind explicit play gesture.

---

## 11. Asset pipeline

### 11.1 Fonts

- Monaspace: download the GitHub package, self-host (`public/fonts/`). Subset latin+box-drawing.
- JetBrains Mono: same pattern, fallback.
- Font loading via `@font-face` in `src/index.css`, `font-display: swap`.

### 11.2 Pixel art

- **Tool**: Aseprite (source files in `design/aseprite/`, exported to `public/sprites/`).
- **Spritesheets**: one per domain. JSON metadata for frame coords.
- **Loader**: PixiJS `Spritesheet`.
- **Resolution**: sprites drawn at `1×`, displayed at `2×` or `3×` via `image-rendering: pixelated`.

### 11.3 Sound (future)

- Format: OGG. Lazy-loaded per screen.
- Tool: Howler.js (P2 when we get to audio).

---

## 12. Constraints / anti-goals

- No component library (shadcn, Radix themes, MUI, Chakra). Radix **primitives** only for a11y plumbing, not styling.
- No i18n V1. Copy in English. Hooks for i18n later (use keys not strings in long-form copy).
- No Tailwind plugins. v4's `@theme` is enough.
- No CSS-in-JS (styled-components, emotion). Tailwind utilities + CSS modules when needed.
- No animation framework beyond Motion. No GSAP, no anime.js.
- No icon lib (lucide, phosphor). Unicode + pixel custom.
- No "brand gradient" or "hero image". Chrome only.
- No mobile V1.

---

## 13. Deliverables from the design system agent

1. **`src/components/ui/` kit** — all generic components coded, typed, with default styles.
2. **`src/components/game/` components** — game-specific built on top.
3. **A gallery route** (`/kit` or `/design-system`) — in-app browser of every component, every state, every variant. Terminal-native "Storybook". Not Storybook proper (too much infra for V1).
4. **`src/index.css`** fully populated with tokens and `@theme`.
5. **Per-component API spec** — co-located `Foo.md` beside each component file, with props table, state matrix, a11y notes.
6. **Wireframes for all V1 screens** — ASCII in `brainstorming/screens/XX-<slug>.md` before coding them.
7. **Unit + visual snapshot tests** per component (see `pit-test-engineer`).
8. **A11y audit** — tooling via `@axe-core/react` in dev, manual sweep with keyboard and screen reader.
9. **Motion inventory** — a doc listing every animation and its `--motion-*` token.
10. **Asset drop** — initial pixel icons for node types, keywords, resources.

---

## 14. Process for the specialist

1. Read this brief end to end.
2. Study the reference tools/games (§2.1) — 30 min minimum.
3. Draft a tokens PR on `feature/design-tokens` (`src/index.css` fully locked).
4. Build the gallery route scaffold with one sample per category.
5. Build components **in this order**:
   1. Layout primitives (Frame, Panel, Divider, Stack)
   2. Typography & display (Stat, Badge, Kbd, Code, Log)
   3. Buttons & basic inputs (Button, TextInput, NumberInput, Select)
   4. Feedback (Toast, Dialog, Alert)
   5. Navigation (Tabs, Menubar, CommandPalette)
   6. Data (Table, List, Tree)
   7. Game-specific (PitCard, DelveNode, HealthBar, CombatLog)
6. Each component = its own PR `feature/component-<name>` → dev.
7. Once the kit passes the smoke test (gallery fully populated, a11y clean, no TODOs), we open the wireframing pass.

---

## 15. Success criteria

The design system is "good enough to build gameplay on" when:

- [ ] A new screen can be assembled from existing components in < 1 hour.
- [ ] All components pass a11y checks (keyboard, focus, contrast, aria).
- [ ] All V1 screens have ASCII wireframes.
- [ ] A stranger shown the gallery can guess the game genre in under 10 seconds.
- [ ] The gallery runs at 60fps in Chrome and Safari.
- [ ] Bundle size for the kit alone stays under 60KB gzipped.
- [ ] No design decision is made at gameplay-build time. Everything deferred to "ask the kit".

---

## 16. Open questions for the user before kicking off

Resolved V1 (no need to ask):
- Palette — locked (§3.1)
- Typography roles — locked (§3.2)
- Motion philosophy — locked (§3.5)
- Anti-patterns — locked (§2.3)

Still needs user input before the specialist starts:
1. **Logo / wordmark** — do we have a `THE PIT` ASCII splash drafted, or does the specialist propose?
2. **Pixel art** — does the user want to draw the icons / enemy sprites themselves, commission, or should we use placeholder "□" blocks until art arrives?
3. **CRT intensity** — subtle scanline overlay at 5% opacity OK? Fully togglable? Or off by default and only as an Easter-egg setting?
4. **Soundscape direction** — ambient drones / chiptune / silence for V1? (Can defer — no audio in V1 is acceptable.)
5. **Gallery route name** — `/kit`, `/design-system`, `/sandbox`?
6. **Accent count** — we locked "one accent per view" but the tier colors break this. Is it OK that card-heavy screens show multiple tier colors simultaneously? (Recommend: yes, tier color ≠ semantic accent, they're part of the content.)

---

*End of brief. The specialist should treat anything here as authoritative unless explicitly overridden by the user or a later research note.*
