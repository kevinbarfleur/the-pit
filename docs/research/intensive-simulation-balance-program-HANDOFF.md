# Intensive Simulation, Effect Coherence, and Balance Program — HANDOFF

Date: 2026-06-26

Status: active handoff / next-session source of truth for the simulation and
balance program.

Purpose: preserve the recent design discussion before context compaction, and
turn it into an implementation-ready program for level-up effects, semantic
coherence, tag wording, coherent team generation, massive simulation, and
ongoing balance automation.

This document intentionally supersedes older balance notes where it conflicts
with the latest conversation. The old raw research folders were cleaned after
this handoff was written; do not depend on deleted SAP/Batomon/roadmap/base-game
notes for current implementation decisions.

Active companion docs:

- `docs/research/balance-sim-design.md`
- `docs/audit/monster-level-scaling-design.md`
- `docs/audit/2026-06-26-economie-run.md`
- `docs/research/relics-design.md`
- `docs/research/engine-architecture.md`

When in doubt, follow the latest explicit user direction, then this document,
then `CLAUDE.md`, then the active docs indexed by `docs/README.md`.

---

## 0. TL;DR

We need to build a long-term autonomous balance and simulation subsystem for
The Pit.

It must not only run thousands of random combats. It must also understand the
plans the game itself suggests to the player:

- poison teams should naturally want poison appliers, poison amplifiers,
  poison command bonuses, poison relics, and positions that activate them;
- low-rank reroll comps should exist and sometimes be intentionally correct;
- level 3 should not only mean more HP and base attack;
- effects, tags, tooltips, cards, relics, command text, and simulation output
  must all describe the same mechanical truth.

The target system has four pillars:

1. **Effect resolver.** One shared source of truth turns `(unit id, level,
   context)` into the actual stats, effects, command bonus, tags, glossary
   entries, and card text.
2. **Semantic audit.** A linter/checker verifies that wording, tags, colors,
   icons, triggers, and hidden/public mechanics are coherent everywhere.
3. **Intentional composition graph.** The game builds a graph of "this unit
   suggests playing with that unit" and generates teams at 0/25/50/75/100%
   coherence, not only random teams.
4. **Massive deterministic simulation.** Thousands to millions of seeded fights
   and run trajectories test balance, counterplay, level-ups, commandants,
   relics, whispers, sigils, positions, and player-like policies.

The long-term goal is that an agent can keep improving creature effects and
balance for years: research, propose, implement, run simulations, inspect
outliers, update docs, and iterate without constantly asking the user.

---

## 1. What Was Discussed Before This Handoff

This section is intentionally broad. It captures the sequence of decisions that
led here, including UI/tag work because simulation and balance must be coupled
to player comprehension.

### 1.1 Scene Coherence And UI Framing

The user first raised that The Pit lacked coherent scene framing:

- main menu, grimoire, build scene, and combat scene felt disconnected;
- Escape/back/settings behavior was inconsistent;
- some places had back buttons, others did not;
- build and combat lacked clear ways to open settings or return to main menu;
- pressing Escape sometimes felt like it might quit the game rather than open a
  coherent pause/settings layer.

The design direction became:

- establish a consistent scene/settings/back/pause language;
- preserve visual identity and game feel;
- integrate settings into top bars where relevant;
- avoid arbitrary floating controls that do not belong to the current scene.

### 1.2 Main Menu And Grimoire Redesign

The menu was cleaned up:

- settings belongs in the main option list, not as an isolated top-right main
  menu button;
- dev tools such as playground/proving ground/design system belong in compact
  icon tools in the corner;
- dev access must remain but should not pollute the player-facing hierarchy.

The grimoire changed direction:

- no more monster-card hover as the primary detail mode;
- click a monster/relic to pin it;
- detail card lives on the right;
- selected monster can switch level I/II/III;
- Shift opens the contextual glossary for the selected card;
- the glossary must adapt to the selected monster and selected level;
- the same tag/glossary behavior should work anywhere a monster card appears,
  including the grimoire and chronicles.

This matters for balance because the grimoire becomes the place where the player
learns how level-ups change mechanics.

### 1.3 Monster Card And Relic Card Readability

The designer provided standalone HTML redesigns for monster and relic cards.
The user preferred the first, larger, cleaner monster card design:

- abilities grouped by category;
- trigger badge first (`HIT`, `DEATH`, `COMMAND`, etc.);
- then the mechanical effect;
- explanatory line below with tags and values;
- Shift glossary as a polished side modal explaining current tags.

The current implementation moved toward:

- tags with icons and color;
- trigger badges instead of long prose prefixes;
- contextual Shift glossary;
- no ellipsis in glossary text, because truncated explanations cannot be read;
- better spacing and alignment;
- less reliance on lore when lore hurts mechanical clarity.

Important feedback:

- attack/passive names beside triggers may add fatigue and should probably be
  removed or de-emphasized if they do not help comprehension;
- triggers must be visually stronger than plain text;
- line wrapping must align with the effect text, not create uneven left gutters;
- command blocks should not repeat "Command" twice when the tag already says
  Command.

### 1.4 Tag, Keyword, And Wording System

The user was very clear: every mechanical concept must use the same word every
time.

Examples:

- if the mechanic is `Haste`, use `Haste`, not sometimes "quicken", "faster",
  or "speed up";
- if the mechanic is `Poison`, use `Poison`, not flavorful synonyms;
- if a card says something and Shift explains tags, there must be a direct
  link between the words on the card and the glossary entries.

Decisions:

- tags are not just decoration; they are the formal vocabulary of the game;
- every tag mention should have its icon before the word where possible;
- color alone is not sufficient: icon + color + consistent name;
- murmures/whispers are hidden mechanics and their tags must not appear in
  public card text/glossary unless intentionally revealed by a dev-only tool;
- command tags should be contextual: command-related tags appear when the
  entity is evaluated as a commander, not always in normal board context;
- the same system should apply to relics, not only monsters.

Known wording ambiguity discovered:

- `wildfire_hound`-style propagation read as if it might be `On Kill`, but the
  actual behavior is closer to "while this unit is on the field, enemies that
  die while Burning propagate Burn." This needs clearer wording and semantic
  tags such as `ON ENEMY DEATH`, `PROPAGATE`, or a specific global aura wording.

### 1.5 DPS And Duration Discussion

The user questioned whether cards should show full DPS and duration details:

- `Burn 10/s for 3s` may be too much cognitive load;
- maybe all afflictions should have default durations, so cards can say
  `Burn 10` and glossary explains duration;
- however, current design uses intensity and duration as balancing knobs, and
  different units apply the same family at different intensity/duration.

Current tentative direction:

- do not remove duration/DPS blindly;
- first improve card layout and glossary;
- then evaluate whether default durations should be standardized per
  affliction family;
- if standardized, do it deliberately as a game-design pass, not as a UI
  simplification only.

### 1.6 Level-Up Discussion

The user identified a major missing engagement loop:

- in autobattlers, leveling a monster should make its values and sometimes its
  mechanics stronger;
- currently, The Pit mostly scales HP and base attack;
- that is not enough;
- abilities must also scale: affliction damage, shields, thorns, heals, aura
  values, command bonuses, etc.;
- roughly all monsters should gain something meaningful at level 2 and level 3;
- only a subset should have transformative level 3 mechanics.

New detail added in the latest message:

- some low-rank and mid-rank creatures should get **level-3 clutch mechanics**;
- this supports low-level reroll compositions;
- it gives the player a reason not to always level the shop quickly;
- the most interesting version is not just extra stats but a small mechanic
  unlock at level 3;
- this is a known pattern in autobattlers: reroll comps are valid because a
  cheap unit at max level becomes a real plan.

This is now a design requirement.

### 1.7 Massive Simulation Discussion

The user wants a much larger simulator than current tests:

- thousands and thousands of coherent configurations;
- all monster levels;
- all positions;
- commandants;
- whispers;
- relics;
- all effects;
- verify effects apply correctly;
- measure balance;
- detect which teams are strong, weak, broken, or incoherent;
- couple mechanical results with wording/tag coherence.

Important correction from user:

- random combinations are useful but insufficient;
- players naturally aim at the synergies implied by card bonuses;
- therefore the system must generate and score teams based on coherence;
- 100% coherence means a near-perfect realization of a clear plan;
- 0% coherence means a pile of units that do not support each other;
- most players try to move toward 100%, so simulation must focus heavily on
  coherent and semi-coherent teams.

This leads to the concept of a **graph of intentions** and a **coherence
score**, described later.

---

## 2. Current Code Findings That Matter

This section is based on code inspection on 2026-06-26. Re-check before editing
because the worktree is active and dirty.

### 2.1 Current Level Scaling

The current level scaling multiplier is duplicated in several places:

- `src/scenes/build.lua`
- `src/net/snapshot.lua`
- `src/render/monstercard.lua`

The multiplier is:

```lua
LEVEL_MULT = { 1.0, 1.8, 3.0 }
```

It scales HP and base attack in `Build:buildComp`.

It also scales some build-resolved support values because `Build:buildComp`
uses the source unit level when baking certain effects.

### 2.2 What Currently Scales Beyond Stats

The following board mechanics currently receive some level scaling through the
build bake:

- `aura_stat` board effects:
  - `templar`
  - `maggot_king`
  - `hookjaw`
  - `bellows_priest`
  - `zeal_inquisitor`
  - `flesh_warband`
  - `bone_choir`
  - `arcane_seer`
  - `abyss_maw`
  - `order_marshal`
  - `vanguard_drummer`
  - `rear_goad`
  - `spine_column`
  - `tide_caller_v2`
  - `storm_conductor`
  - `echo_warden`
- `shield_aura` board effects:
  - `shieldbearer`
  - `aegis_warden`
  - `oath_keeper`
  - `bulwark_acolyte`
  - `runestone_golem`
- DoT amplifying adjacency:
  - `soot_acolyte`
  - `miasma_acolyte`
  - `decay_tender`
- periodic shield caster:
  - `ward_weaver`
- rainbow type payoff:
  - `prism_horror`

Most command bonuses using `commandBonus.op == "aura_stat"` also scale with the
commander level.

### 2.3 What Does Not Currently Scale Properly

Most ordinary combat abilities do not become level-aware:

- `poison` dps/duration/weaken/spread;
- `burn` dps/duration/decay/propagation;
- `bleed` dps/slow/aggravate;
- `rot` base/growth/cap/max-hp amputation;
- `shock` add/volt/cap/chain/transfer/persist;
- `thorns`;
- `lifesteal`;
- `execute`;
- `percent_hp_strike`;
- `heal_on_kill`;
- `purge`;
- `summon`;
- `scavenge_on_ally_death`;
- `strip_shield`;
- `cleave`;
- `grant_team` flags.

That means a level 3 damage-over-time unit may have much higher base stats but
still applies a level 1 affliction.

### 2.4 Command Bonus Exceptions

Command bonuses that are `aura_stat` scale.

Command bonuses that are `grant_team` do not currently scale by commander
level. Examples:

- `acid_maw`
- `ash_maw`
- `blight_spreader`
- `bloodletter`
- `coil_viper`
- `corruptor`
- `dynamo_priest`
- `festering`
- `pit_maw`
- `plague_bearer`
- `plague_pyre`
- `reaper_shade`
- `siege_breaker`
- `slow_bleed`
- `storm_conductor`
- `stormcaller`
- `stormlord`
- `wallbreaker`
- `wildfire_hound`

Not all of these should necessarily scale numerically. But the system should
explicitly decide what level 2 and level 3 command versions mean.

### 2.5 Known Mismatch: `clot_mender`

`clot_mender` has `aura_grant_bleed` with `dps = 1`.

The readout/mental model can imply this scales with level, but the current bake
stores `grantBleed[slot] = pa` without multiplying `dps` by source level.

This is a concrete example of why the audit must compare:

- displayed text;
- tag/value readouts;
- build-baked combat spec;
- actual combat event log.

### 2.6 Snapshot Debt

`src/net/snapshot.lua` reconstructs HP and damage by level, but does not fully
recreate the build-resolved effect layer.

This means future balance simulation must not rely on raw snapshot
reconstruction as the only truth. It needs a shared resolver that both snapshots
and build scenes can use.

### 2.7 Current Simulator Base

`tools/sim.lua` already does useful work:

- deterministic random build generation;
- combat batches;
- winrate by unit;
- damage by source and cause;
- TTK distribution;
- co-occurrence lift;
- outlier flags;
- murmur frequency channel;
- several scenario modes in `tools/scenarios/`.

Existing scenario modes include:

- `invest`
- `policy`
- `godroll`
- `commander`
- `counter`

This is a good foundation but not enough for the new program because it does
not yet fully model semantic coherence, level-up effects, player-intended
composition construction, and text-vs-mechanic validation.

---

## 3. Design Principles For The New Program

### 3.1 The User-Facing Promise Must Match The Simulation

The player reads cards and forms a plan. The game must honor that plan.

Therefore every effect needs three aligned representations:

1. **Mechanical truth.**
   The data and resolver say exactly what happens.
2. **Player text.**
   Cards, relics, triggers, and glossary use the same words and values.
3. **Observed behavior.**
   Event logs prove the effect fires in the expected context.

If any of these disagree, the design is broken even if combat "works".

### 3.2 Consistent Terms Beat Flavor Synonyms

Flavor is secondary to comprehension.

Use one canonical term for each mechanic:

- `Poison`
- `Burn`
- `Bleed`
- `Rot`
- `Shock`
- `Haste`
- `Shield`
- `Thorns`
- `Propagate`
- `Convert`
- `Command`
- `Multicast` or `Echo` but not both unless one is purely flavor and never
  appears as a mechanical term.

Every term must have a glossary entry if the player needs to understand it.

### 3.3 Hidden Mechanics Stay Hidden

Whispers/murmures are intentionally hidden. They may be logged in dev channels
and simulation reports, but should not leak into public monster/relic tags or
Shift glossary unless a later explicit reveal system is designed.

### 3.4 Context Matters

The same unit can have different visible mechanical context:

- normal board card;
- unit in command slot;
- unit at level I/II/III;
- unit affected by relics;
- unit in grimoire preview;
- unit in chronicle/post-combat inspection.

The tag set and text should adapt to context. For example:

- command tags only show when evaluating the unit as commandant;
- level 3 clutch tags appear only at level 3;
- relic-added public mechanics appear in the effective context;
- hidden whisper tags do not appear in public context.

### 3.5 Coherence Is Not The Same As Power

A composition can be coherent and weak. That means tune the numbers.

A composition can be incoherent and strong. That usually means raw stats,
caps, or unintended interactions are carrying it.

The simulator must report both:

- `coherence_score`
- `power_score`

The interesting quadrants are:

| Coherence | Power | Meaning |
| --- | --- | --- |
| High | High | desired build fantasy, tune if too dominant |
| High | Low | good idea under-rewarded |
| Low | High | likely broken stats or unintended interaction |
| Low | Low | harmless random pile |

### 3.6 Low-Rank Reroll Comps Are A Feature

The game should not always reward rushing higher shop tiers.

Some low-rank and mid-rank units should have level 3 clutch mechanics:

- enough to create valid reroll compositions;
- not enough to make every cheap unit mandatory;
- usually a small mechanical unlock, not just a bigger stat number.

Examples of healthy level 3 clutch rewards:

- a rank-1 poison unit applies an extra weak poison to a second target;
- a rank-1 bleed unit gains `on kill: refresh Bleed on a neighbor`;
- a rank-2 shield unit starts also shielding itself;
- a rank-2 aura unit broadens from one neighbor to all adjacent allies;
- a low-rank commandant bonus gains a small extra target rule at level 3;
- a summon unit's token inherits one small tag at level 3.

The goal is to make "I will stay low and triple this unit" an interesting plan.

### 3.7 Transformative Level 3 Is Special

Not every level 3 should rewrite a unit.

Recommended split:

- all units: level 2 and level 3 improve the primary useful knob;
- roughly 15-25% of units: level 3 adds a small transformative mechanic;
- low/mid-rank subset: level 3 clutch mechanics support reroll comps;
- high-rank subset: level 3 can be very rare and powerful but must stay bounded
  by caps.

---

## 4. Proposed Architecture

### 4.1 Shared Effect Resolver

Create a shared pure module, likely under `src/data/` or `src/core/`.

Candidate names:

- `src/data/unit_levels.lua`
- `src/core/unit_resolver.lua`
- `src/core/effect_resolver.lua`

Responsibilities:

```lua
Resolver.statsFor(id, level, opts) -> { hp, dmg, cd, ... }
Resolver.effectsFor(id, level, context) -> effects
Resolver.commandBonusFor(id, level, context) -> commandBonus
Resolver.tagsFor(id, level, context) -> tags
Resolver.cardFactsFor(id, level, context) -> normalized facts for UI/text
```

Contexts:

```lua
{
  mode = "board" | "command" | "grimoire" | "combat" | "simulation",
  includeHidden = false,
  relics = optional,
  whispers = optional,
  position = optional,
  shape = optional,
  team = optional,
}
```

Rules:

- pure Lua, no `love.*`;
- deterministic;
- arrays with `ipairs` for ordered data;
- no global randomness;
- no render/audio dependencies;
- build, snapshot, grimoire, card UI, tests, and simulator must eventually use
  this same module.

### 4.2 Data Shape For Level Abilities

Do not infer all scaling from op names. Author it explicitly.

Possible shape:

```lua
levelAbility = {
  [2] = {
    effects = "override",
    descKey = "unit.witch.ability_l2",
  },
  [3] = {
    effects = "override",
    clutch = true,
    descKey = "unit.witch.ability_l3",
  },
}
```

Alternative shape:

```lua
levels = {
  [1] = { effects = base },
  [2] = { patch = { poison = { dps = 3 } } },
  [3] = { patch = { poison = { dps = 4 } }, add = {...} },
}
```

Important contract:

- level 1 is current behavior unless intentionally migrated;
- level 2 generally improves one primary value;
- level 3 improves further or unlocks a clutch/transform;
- text is generated from facts where possible;
- hand-written text is allowed only when facts cannot express the nuance.

### 4.3 Separate Stat Scaling From Ability Scaling

Keep stat scaling simple:

```lua
STAT_LEVEL_MULT = { 1.0, 1.8, 3.0 }
```

But do not use this raw multiplier as the ability multiplier forever.

Ability scaling should be authored:

- poison dps: 2 -> 3 -> 4;
- burn dps: 6 -> 8 -> 10;
- shield: 6 -> 9 -> 12;
- thorns: 3 -> 5 -> 7;
- aura percent: 12% -> 16% -> 20%;
- heal on kill: 4 -> 6 -> 8;
- percent strike cap: 12 -> 13 -> 14, not 12 -> 22 -> 36.

This is more readable and safer than multiplying every parameter by 1.8/3.0.

### 4.4 Effect Facts

Introduce normalized facts for every effect.

Example:

```lua
{
  source = "witch",
  level = 2,
  trigger = "hit",
  op = "poison",
  tags = { "poison" },
  values = {
    dps = 3,
    duration = 180,
  },
  target = "attack_target",
  public = true,
}
```

Facts should be consumed by:

- card text;
- tag chips;
- Shift glossary;
- semantic audit;
- simulator metadata;
- docs generators;
- replay/chronicle summaries.

### 4.5 Semantic Audit

Add a dev/test tool that verifies coherence across text and mechanics.

Candidate:

```sh
luajit tools/effect_audit.lua
```

Or test:

```sh
luajit tests/effect_audit.lua
```

Checks:

- every public effect fact has at least one visible tag if it needs one;
- every visible tag is backed by a real effect fact;
- no hidden whisper tag appears in public mode;
- no unknown mechanical synonyms appear in card text;
- canonical terms are used consistently;
- trigger names are canonical;
- `0 dps` afflictions are either hidden behind a "utility" wording or flagged;
- command effects are not shown in normal context unless intended;
- level I/II/III card facts differ when the unit has level scaling;
- relic card facts use same tags and glossary system as monster cards;
- card text mentions values that match resolved facts;
- tooltip/glossary has no ellipsis/truncation in its source text.

### 4.6 Event Audit

The simulator should verify not only that a combat ended, but that expected
effects fired.

Example checks:

- a `Poison on hit` unit must emit an affliction application event after a hit;
- a `Propagate on enemy death` unit must only propagate when the correct death
  condition happens;
- a command aura that says `team Haste` must result in team members having
  haste in the built combat spec;
- a level 3 clutch effect must appear in level 3 event traces and not in level 1.

This requires richer event logs than current `tools/eventlog.lua`, or at least
additional event types for effect applications, aura bakes, command grants, and
tag/fact IDs.

---

## 5. Coherence Graph

### 5.1 Why This Exists

Players do not build random piles most of the time.

They read a card and infer:

- "this unit wants poison teammates";
- "this unit wants to stand next to a burn carry";
- "this unit wants to be commandant";
- "this unit wants low-tier allies";
- "this unit wants the center";
- "this relic wants shield units";
- "this level 3 wants rerolling this rank-1 unit."

The simulator must model these psychological invitations.

### 5.2 Unit Intent Profile

Each unit should have a derived or authored intent profile.

Fields:

```lua
{
  produces = { poison = 1.0 },
  consumes = { poisonInc = 1.0, burn = 0.0 },
  amplifies = { poison = 0.5 },
  wants = {
    position = { center = 0.8, front = 0.2 },
    neighbors = { poison_applier = 1.0 },
    command = 0.4,
    level3 = 0.7,
    relics = { poison = 1.0 },
  },
  archetypes = { poison = 1.0, sustain = 0.2 },
}
```

Some of this can be derived from effect facts. Some should be authored for
ambiguous mechanics.

### 5.3 Edge Types

The graph should create directed or weighted edges:

- producer -> amplifier;
- amplifier -> producer;
- commandant -> team archetype;
- relic -> unit archetype;
- position support -> position carry;
- level 3 clutch -> reroll shell;
- counter -> target archetype;
- anti-synergy -> negative edge.

Examples:

- `witch -> miasma_acolyte`: poison applier wants poison amplifier.
- `soot_acolyte -> emberling`: burn amplifier wants burn applier.
- `hookjaw -> front carry`: multicast wants a front unit with meaningful on-hit.
- `maggot_king -> front carry`: front multicast command/aura wants a strong
  primary hitter.
- `wildfire_hound -> burn team`: propagation wants enemies to die with Burn.
- `deep_kraken command -> level 1 units`: command bonus wants level-1 targets.
- `galvanizer command -> tier 1 units`: command bonus wants rank-1 allies.
- `prism_horror -> mixed types`: rainbow payoff wants type diversity.

### 5.4 Coherence Score

Suggested split:

- 30% mechanical tag alignment;
- 20% position/shape activation;
- 20% commandant/relic alignment;
- 15% level plan alignment;
- 10% economy/tier timing plausibility;
- 5% readability/semantic clarity.

Alternative split is fine, but the report must expose sub-scores, not just a
single number.

Example output:

```json
{
  "comp": "poison_diamant_l3_reroll",
  "coherence": 0.86,
  "subscores": {
    "tags": 0.92,
    "position": 0.78,
    "command": 0.88,
    "level_plan": 0.95,
    "economy": 0.74,
    "readability": 0.90
  }
}
```

### 5.5 Coherence Bands

Generate team variants in bands:

- 0-20%: random pile / negative control;
- 20-40%: accidental partial synergy;
- 40-60%: plausible casual build;
- 60-80%: intentional but imperfect build;
- 80-95%: optimized build;
- 95-100%: near-perfect/theorycrafted build.

The simulator should compare power within and across these bands.

Key questions:

- do 80-100% coherent teams generally beat 20-40% teams at comparable
  investment?
- are some 95% teams always dominant?
- are some 95% teams weak despite clear design intent?
- are some 20% teams winning anyway?

---

## 6. Level-Up Design Program

### 6.1 Global Rule

Every monster should improve its gameplay contribution when leveled.

That means:

- stats improve for all units;
- primary ability value improves for all units with abilities;
- support units improve support output;
- commandant units improve command output;
- level 3 may unlock a small additional mechanic for selected units.

Do not let a level 3 unit show the same ability text as level 1 unless the unit
is intentionally a pure stat-stick.

### 6.2 Scaling Knobs By Effect Family

Suggested primary knobs:

| Family | Level knob |
| --- | --- |
| Poison | dps, weaken, spread dps, cap interaction |
| Burn | dps, decay rate, propagation load, shield pressure |
| Bleed | dps, slow percent, aggravate multiplier |
| Rot | base, growth, capDps, maxHpFrac carefully |
| Shock | add, volt, cap, chain/transfer/persist carefully |
| Shield | value, cooldown, target count, reflect |
| Thorns | value |
| Heal/Regen | value |
| Execute | bonus or threshold, not both blindly |
| Percent strike | frac or cap, carefully bounded |
| Summon | token stats, token tag inheritance, death trigger |
| Scavenge | value or cap |
| Aura | value, target count, or shape at level 3 |
| Command | value, target class, or small extra rider |

### 6.3 Low-Rank Reroll Clutch Mechanics

Low-rank level 3 mechanics should support reroll comps.

Good candidates:

- rank 1 and rank 2 units with clear archetype identity;
- units that are understandable early;
- units whose level 3 can anchor a build without requiring rare rank-5 pieces;
- units whose level 3 makes the player say "I can stay low and commit."

Possible patterns:

1. **Extra target at level 3.**
   A simple on-hit affliction also affects a neighbor, a second target, or a
   nearby enemy at reduced value.
2. **Refresh or carry-over.**
   On kill/death, refresh a family affliction.
3. **Small aura broadening.**
   One neighbor becomes all neighbors, or one direction becomes a role target.
4. **Command clutch.**
   A cheap unit's command bonus becomes meaningfully archetype-defining at
   level 3.
5. **Token inheritance.**
   A summon unit's token gains a small tag or stat at level 3.
6. **Counter unlock.**
   A low/mid unit gets a small anti-shield, anti-tank, or anti-regen rider at
   level 3, enabling reroll counter-comps.

Avoid:

- level 3 low-rank mechanics that invalidate high-rank units;
- too many universal statInc level 3s;
- early access to unbounded team-wide transforms;
- hidden mechanics that the player cannot plan around.

### 6.4 Transformative Level 3 Categories

Use a small set of transform categories so they remain readable:

- **Spread.** Affect one extra target or spread on death.
- **Persist.** Affliction no longer decays/refreshes in a narrow context.
- **Broaden.** Aura target changes from one neighbor/direction to a larger but
  still bounded set.
- **Convert.** Converts one family into another under a clear condition.
- **Echo.** Adds a bounded extra hit/copy under a clear condition.
- **Survive.** Shield/heal/self-protection unlock.
- **Finish.** Execute/kill/death payoff unlock.

### 6.5 UI Requirement For Level-Ups

Cards must make level-up changes easy to inspect:

- grimoire level I/II/III selectors;
- Shift glossary adapts to selected level;
- changed numbers should be visibly different;
- level 3 clutch mechanics should be visually marked, but not with noisy
  marketing language;
- no hidden level scaling that is not reflected in card facts.

---

## 7. Massive Simulation Program

### 7.1 Simulation Layers

Build in layers, not one giant script.

Layer 1: **Unit/effect audit**

- no fights;
- read data/resolver;
- verify facts, tags, text, context, level deltas.

Layer 2: **Micro scenarios**

- one effect against a controlled target;
- verify event expectations;
- one unit level 1/2/3 comparisons.

Layer 3: **Pair and trio synergy**

- producer + amplifier;
- commandant + target;
- relic + unit;
- position support + carry;
- low-rank level 3 shell.

Layer 4: **Coherence-band team simulation**

- generate teams at 0-100% coherence;
- compare power by investment and coherence.

Layer 5: **Policy/run simulation**

- simulate actual run choices;
- reroll vs level-up shop;
- archetype commitment;
- relic offers;
- loss recovery.

Layer 6: **God-roll and outlier explorer**

- intentionally construct high-risk intersections;
- search the tail of the power distribution;
- output repro seeds and exact combo signatures.

### 7.2 Configuration Dimensions

The generator must cover:

- unit IDs;
- unit levels 1/2/3;
- rank/tier;
- board shape/sigil;
- board position;
- adjacency and direction;
- commandant and command level;
- relic sets;
- hidden whisper variants in dev simulation;
- enemy archetype/counter field;
- investment score;
- shop/run policy;
- early/mid/late phase.

### 7.3 Reports

Every simulation report should include:

- seed;
- comp IDs and full resolved facts;
- levels;
- shape;
- positions;
- commandant;
- relics;
- whispers dev-only;
- investment score;
- coherence score and sub-scores;
- winrate;
- TTK p10/p50/p90;
- damage by cause;
- effect trigger counts;
- expected effects not observed;
- observed effects not described;
- top outlier pairs/trios;
- recommended action category:
  - buff values;
  - nerf values;
  - clarify text;
  - fix resolver bug;
  - cap interaction;
  - create counter;
  - intentional god-roll, document it.

### 7.4 Reproducibility

Every suspicious result must be reproducible:

- deterministic seed;
- resolved comp JSON;
- combat event log;
- optional chronicle replay;
- minimal reduced scenario if possible.

Property-based/stateful testing tools such as Hypothesis are useful references
because they generate many action sequences and reduce failures to small
counterexamples. We likely implement the idea in Lua rather than adding Python
unless Python becomes useful for analysis tooling.

### 7.5 Useful External Method References

These are not binding, but they validate the methodology:

- Automated playtesting with procedural personas:
  <https://arxiv.org/abs/1802.06881>
- Automatic playtesting for parameter tuning via active learning:
  <https://arxiv.org/abs/1908.01417>
- Beyond static personas / developing personas:
  <https://arxiv.org/abs/2107.11965>
- Planning/model-learning based automated video game testing:
  <https://arxiv.org/html/2402.12393v1>
- Hypothesis stateful testing:
  <https://hypothesis.readthedocs.io/en/latest/stateful.html>

Takeaways for The Pit:

- use synthetic personas/policies, not only random input;
- use active search for parameter tuning after mechanics are fixed;
- use stateful/model-based tests for sequences like buy/reroll/level/place;
- store detailed logs so failures can be replayed and minimized.

---

## 8. Implementation Roadmap

### Phase A — Stabilize Source Of Truth

1. Create shared level/stat/effect resolver.
2. Move `LEVEL_MULT` to one shared module.
3. Update build comp generation to use resolver.
4. Update grimoire/card preview to use resolver.
5. Update snapshot reconstruction path or explicitly route snapshots through
   build/effect resolution.
6. Add tests proving level 1 remains unchanged.

Validation:

- `luajit tests/duplicates.lua`
- `luajit tests/auras.lua`
- `luajit tests/synergies.lua`
- `sh tools/check.sh`

### Phase B — Semantic Audit

1. Add effect facts.
2. Add tag/context audit.
3. Add trigger wording audit.
4. Add level I/II/III delta audit.
5. Add relic fact audit.
6. Add "hidden whispers do not leak" audit.

Validation:

- new `tests/effect_audit.lua`;
- no unknown canonical terms;
- every public fact has a public representation.

### Phase C — Author Level-Up Pass

1. Define level 2 and level 3 value changes for every unit.
2. Select low/mid-rank level 3 clutch units.
3. Select higher-rank transformative level 3 units.
4. Update card facts/text.
5. Update grimoire level selectors.
6. Run micro and synergy tests.

Keep a table with:

- unit id;
- rank;
- base role;
- L2 effect;
- L3 effect;
- clutch/transform flag;
- intended archetype;
- intended comp shell.

### Phase D — Coherence Graph

1. Derive or author intent profiles.
2. Build edge scoring.
3. Generate team candidates by archetype and coherence band.
4. Export JSON reports for inspection.
5. Add tests ensuring canonical known pairings score high.

### Phase E — Massive Simulation

1. Extend `tools/sim.lua` or create `tools/balance_lab.lua`.
2. Add modes:
   - `audit`
   - `micro`
   - `coherence`
   - `reroll`
   - `levelups`
   - `relics`
   - `whispers-dev`
   - `godroll-v2`
3. Run increasing budgets:
   - smoke: 10-50;
   - local dev: 500-2,000;
   - overnight: 50,000+;
   - release audit: as high as practical.
4. Store diffable reports under `runs/`.

### Phase F — Autonomous Iteration Loop

For each balance iteration:

1. Run audits.
2. Run simulations.
3. Identify outliers.
4. Reduce to repro seeds/scenarios.
5. Decide whether issue is wording, bug, missing counter, overtuned value, or
   intended god-roll.
6. Patch smallest meaningful data/code.
7. Re-run targeted tests.
8. Re-run aggregate tests.
9. Update changelog/docs/report.

---

## 9. Important Open Design Questions

These are not blockers for building the infrastructure, but must be answered
as implementation proceeds.

1. Should affliction durations become standardized per family, or should cards
   continue showing per-unit durations?
2. Should the public mechanic be called `Multicast` or `Echo`? Pick one as
   canonical and demote the other to flavor if needed.
3. How many low-rank units should have level 3 clutch mechanics?
4. Should commandant level scaling use normal ability rules or a separate
   command-specific level table?
5. Should `grant_team` command bonuses get numeric level scaling, target
   broadening, or mostly stay binary?
6. How much should low-rank reroll comps compete with high-rank late comps?
7. Should the coherence score be fully derived from facts, partially authored,
   or manually curated per archetype?
8. Which old docs are now stale enough to archive or annotate?

---

## 10. Immediate Next Tasks

Suggested next session order:

1. Build `Resolver` skeleton with level 1 identity behavior.
2. Move `LEVEL_MULT` to shared source.
3. Add a tiny level-up data table for 3-5 units only:
   - one poison applier;
   - one shield unit;
   - one aura unit;
   - one low-rank reroll candidate;
   - one commandant with `grant_team`.
4. Update tests to prove ability values change at level 2/3.
5. Fix or explicitly document `clot_mender` level scaling mismatch.
6. Add first `effect_audit` prototype.
7. Generate first coherence graph for a small subset:
   - poison;
   - burn;
   - shield;
   - low-rank reroll.
8. Only then scale to the full roster.

Do not start by authoring all 110 level tables manually without the resolver
and audit in place. That would create a large amount of unverified data.

---

## 11. Success Definition

This program is successful when:

- every monster has meaningful level-up progression;
- selected low/mid-rank units create valid reroll comps at level 3;
- cards and relics use canonical terms consistently;
- Shift glossary explains exactly the mechanics visible in the current context;
- hidden whispers remain hidden in public UI;
- simulator can generate coherent, semi-coherent, and incoherent teams;
- simulator can distinguish coherence from power;
- reports identify broken combos with reproducible seeds;
- agents can run the loop autonomously: research, implement, simulate, inspect,
  tune, verify, and document.

The final desired behavior is not "all winrates are 50%". The desired behavior
is:

- coherent plans are rewarded;
- counters are readable;
- reroll and level-up decisions are both viable in different contexts;
- god-rolls exist but are bounded and inspectable;
- incoherent piles do not accidentally dominate;
- the text never lies to the player.

---

## 12. Implementation Log

### 2026-06-26 — Phase A seed implemented

The first implementation increment is now in code.

Added:

- `src/data/unit_levels.lua`
- `src/core/unit_resolver.lua`
- `tests/unit_resolver.lua`
- `tests/effect_audit.lua`

Wired:

- `src/scenes/build.lua`
- `src/net/snapshot.lua`
- `src/render/monstercard.lua`
- `tools/check.sh`

Behavior:

- `STAT_LEVEL_MULT = { 1.0, 1.8, 3.0 }` now lives in `UnitResolver`.
- `Resolver.statsFor`, `effectsFor`, `commandBonusFor`, `unitForLevel`, and
  `effectFactsFor` are the first shared source of truth.
- Level 1 remains base behavior.
- Authored level effects are marked and are not multiplied again by legacy
  build-time source-level scaling.
- Build comps and snapshots now materialize level-authored effects for level
  2/3 units so combat does not fall back to raw `Units[id].effects`.
- Monster cards now use `Resolver.unitForLevel`, so card stats/effects change
  with selected level.

Initial authored level-up set:

- `spore_tick`: low-rank poison reroll seed; L3 gains Poison spread.
- `gnaw_rat`: low-rank bleed reroll seed; L3 gains Aggravate.
- `shieldbearer`: explicit Shield progression matching previous legacy level
  scaling.
- `miasma_acolyte`: explicit Poison aura progression matching previous legacy
  level scaling.
- `clot_mender`: fixes the old granted-Bleed mismatch by making grant values
  level-aware.
- `corruptor`: first `grant_team` commandant with level-aware command values.

Validation:

```sh
sh tools/check.sh
```

Result on 2026-06-26: full suite passed.

### 2026-06-26 — Phase D seed implemented

The first intent/coherence graph is now in code.

Added:

- `src/lab/coherence.lua`
- `tests/coherence.lua`
- `tools/coherence_report.lua`

Wired:

- `tools/check.sh`

Behavior:

- The lab derives intent profiles from `UnitResolver.effectFactsFor`; it does
  not parse card prose.
- Profiles expose produced families, amplified families, granted mechanics,
  propagation, transforms, command effects, frontline/tank roles, and authored
  level-up/clutch flags.
- Pair edges currently detect:
  - producer + amplifier plans such as `spore_tick` + `miasma_acolyte`;
  - burn propagation payoffs such as `wildfire_hound` + burn appliers;
  - shield engines such as `ward_weaver` + `barrier_savant`;
  - generic tempo/marker support such as Haste and Vulnerable.
- `scoreTeam` returns a `coherence` score and separate subscores:
  - `tags`;
  - `position`;
  - `command`;
  - `level_plan`;
  - `readability`.
- Position is intentionally separate from tag synergy. A neighbor aura can have
  the correct mechanical pairing but still score worse if the slots are not
  adjacent.
- Economy is also separate from combat power. The report now includes assembly
  gold, low-rank reroll signal, max rank/level, and shop pressure by variant.

Economy audit integrated:

- `docs/audit/2026-06-26-economie-run.md` confirmed the structural issue:
  `10 gold + shop size 5 + cost=rank + no bank` makes tier 1/2 too permissive.
- The coherence report compares three variants without changing gameplay:
  - current `cost=rank / 10 gold`;
  - SAP-like `costByRank = {2, 3, 4, 5, 6}`;
  - curved early income with current costs.

Current report command:

```sh
luajit tools/coherence_report.lua
```

Current report path:

```text
runs/report-coherence.json
```

Current report snapshot:

- roster coverage: 110 units;
- graph edges at level 1: 1441;
- authored level-up units: 6;
- low-rank clutch units: 2;
- poison reroll sample coherence: 0.921;
- burn propagation sample coherence: 0.752;
- low-synergy pile coherence: 0.212;
- current tier-1 full-shop ratio: 0.500;
- SAP-like tier-1 full-shop ratio: 1.000;
- curved-income tier-1 full-shop ratio: 0.833.

Validation:

```sh
luajit tests/coherence.lua
luajit tools/coherence_report.lua
sh tools/check.sh
```

Result on 2026-06-26: full suite passed.

Important interpretation:

- These are not power scores and not win rates.
- This layer answers: "Does this team look like a plan the game itself taught
  the player to build?"
- The next simulation layer must combine `coherence_score`, combat results,
  investment cost, run economy pressure, relic access, and commandant effects.

Next implementation targets:

1. Generate candidate teams by coherence band:
   - 0%;
   - 25%;
   - 50%;
   - 75%;
   - 100%.
2. Expand the economy/run report. First implementation exists:
   - `src/run/economy.lua`;
   - `tools/sim.lua economy [N]`;
   - `runs/report-economy.json`;
   - `force_level_fast` policy now exercises XP buying.
   It already emits:
   - `full_shop_afford_rate` / `early_full_shop_afford_rate`;
   - true `desired_buy_all_rate`, plus `desired_gold_afford_rate` and
     `desired_slot_limited_rate`;
   - `virtual_bench` rates for hypothetical extra reserve capacities `0/2/4/6`
     above the real board+bench capacity; cap `0` is the current gameplay
     model;
   - `gold_leftover_wasted` via `avg_leftover_gold`;
   - `gold_pressure`;
   - `spend_split`;
   - `reroll_rate_by_tier`;
   - `xp_buy_rate_by_tier`;
   - `sells_per_run` / `sell_gold_per_run`;
   - `bench_sells_per_run`, `board_sells_per_run`;
   - `pair_buys_per_run`, `merge_buys_per_run`;
   - cohorts `legacy_all`, `broad_naive`, `broad_prune`, `broad_plan`,
     `committed`, `committed_plan`;
   - `archetype_commitment_rate`;
   - `avg_archetype_commit_round`;
   - per-archetype split: `plan_formed_runs`, `plan_unformed_runs`,
     `avg_wins_given_plan`, `avg_wins_without_plan`,
     `completion_given_plan`, `completion_without_plan`.
   Latest N=20 learning:
   - the first pass missed the existing build-scene bench; `Rundriver` now uses
     `Build:autoBuy`, so purchases go board -> real bench -> merge if full;
   - `sap_cost` still creates the clearest economic pressure:
     full-shop affordability drops from `89.0%` baseline to `62.5%`;
   - `early_curve` barely changes full-shop affordability (`87.8%`) while
     `cost=rank` remains active;
   - with the real bench wired, desired-offer buy-all rises to `21.9%`
     baseline and `18.9%` sap_cost, and average wins rise materially;
   - adding four extra virtual reserve slots would raise desired-offer buy-all
     to about `50%`, but a large space limit remains, so the problem is also
     policy selectivity / sell / merge intelligence, not only bench size;
   - committed archetype policies can usually buy their wanted pieces with the
     real bench, while greedy/econ/tall policies remain very space-sensitive;
   - tank is still the outlier: no rank-1 tank, late commitment, weak outcomes.
   Latest N=20 learning after adding `_prune` broad policies:
   - `Rundriver:sellBench` now models the player selling reserves and records
     sale metrics;
   - `Policies.analysisSet` keeps the legacy 9 policies and adds
     `greedy_prune`, `econ_prune`, `tall_dense_prune`;
   - in `baseline`, broad naive policies average `7.38` wins, `7.7%`
     desired-offer buy-all, and `92.3%` space-limited desired rounds;
   - in `baseline`, broad prune policies average `8.03` wins, `12.8%`
     desired-offer buy-all, `87.2%` space-limited desired rounds, and sell
     `28.6` bench units/run;
   - in `sap_cost`, broad pruning raises desired-offer buy-all from `8.4%` to
     `14.7%`, but space limitation remains `85.3%`;
   - conclusion: bench pruning fixes a player-policy naivety and especially
     helps tall/econ, but it does not justify a bench-size change by itself.
     The next pass needs smarter pair planning / board prioritization before a
     gameplay economy change is locked.
   Per-archetype learning from the same N=20:
   - `tank` in baseline forms the plan only `7/20` times, around round `5.57`,
     and averages only `1.43` wins even when formed;
   - `tank` in `sap_cost` forms only `5/20` times and averages `0` wins even
     when formed;
   - this is not a bench-space issue. Tank needs either a rank-1 seed, a
     smarter survivable rush policy, or actual mechanical power in the tank
     shell before it can be evaluated as a healthy archetype.
   Latest N=20 learning after adding paired seeds and `_plan` policies:
   - `tools/scenarios/economy.lua` and `tools/scenarios/policy.lua` now use
     paired world seeds per run/profile. Policies start from the same run seed
     and diverge through their own actions, which makes policy comparisons less
     noisy.
   - `Rundriver` records `benchSells`, `boardSells`, `pairBuys`, and
     `mergeBuys`; `buy` counts whether a purchase creates a second copy or
     completes a level-up merge.
   - `Policies.analysisSet` now has 19 policies: legacy 9, `_prune` broad
     policies, `_plan` broad policies, and `_plan` committed archetype policies.
     Later autonomy pass extends the current set to 20 by adding
     `committed_cross_bleed_rot_plan`, a target+support policy for a specific
     rot/bleed endpoint.
   - `_plan` policies score offers by immediate merge, pair creation, rank/cost
     and plan membership. They sell bench singletons only for high-value offers
     and can sell one weak board unit when the board stays above a survival
     floor and the offer is clearly better.
   - in paired `baseline`, broad naive averages `7.35` wins, `8.2%`
     desired-offer buy-all, `91.8%` space-limited desired rounds, `4.0`
     pair buys/run, and `3.7` merge buys/run;
   - in paired `baseline`, broad prune averages `7.92` wins, `11.2%`
     desired-offer buy-all, `88.8%` space-limited rounds, `26.6` sells/run,
     `6.9` pair buys/run, and `6.0` merge buys/run;
   - in paired `baseline`, broad plan averages `8.78` wins, `21.7%`
     completion, `14.6%` desired-offer buy-all, `85.4%` space-limited rounds,
     only `17.3` sells/run, `0.62` board sells/run, `7.8` pair buys/run, and
     `6.4` merge buys/run;
   - in paired `sap_cost`, broad plan improves desired-offer buy-all to
     `17.2%` versus `11.8%` prune and `8.7%` naive, while selling less than
     prune (`13.3` vs `19.9` sells/run);
   - global `sap_cost` still creates the strongest economy pressure
     (`66.8%` full-shop affordability vs `94.6%` baseline) but drops average
     wins while weak shells remain unresolved;
   - `tank` is unchanged by planning: baseline tank forms only `2/20` plans,
     round `6`, completion `0%`, `0.95` wins average; `sap_cost` tank forms
     `3/20` plans and averages `0.05` wins. This is an accessibility/power
     defect in the tank shell, not a reserve-management defect.
   Latest N=20 learning after adding `tools/sim.lua tank [N]`:
   - `src/lab/rundriver.lua` now supports lab-only `compMutator`,
     `leftMutator`, and `rightMutator` overlays. These let us test pacing and
     candidate balance changes without mutating live roster data.
   - `tools/scenarios/tank.lua` crosses six tank hypotheses with five pacing
     profiles and writes `runs/report-tank.json`:
     `current_plan`, `survival_shell`, `husk_seed`, `demon_seed`,
     `current_power_plus`, `husk_seed_power_plus` x
     `live_hp2_cd1`, `hp2_cd2`, `hp2_cd3`, `hp2_cd4`, `hp3_cd2`.
   - Current tank remains weak: live pacing, current policy, `0%` completion,
     `0.90` wins average, `25%` plan commitment, `25%` actual final tank
     commitment.
   - A broad survivable filler shell is very strong (`55%` completion and
     `9.55` wins at live pacing), but it is not actually tank:
     actual final tank commitment is `0%`. This is a useful negative result.
     Robust low-rank fillers can save runs, but they do not create a readable
     tank identity.
   - `husk` as a simulated rank-1 tank seed forms the policy plan often
     (`90%`) but wins `0.00` at live pacing and never reaches actual tank
     final commitment. Husk is not a viable seed without real tank mechanics.
   - `demon` as a simulated seed is more promising (`3.95` wins live,
     `6.00` wins at `hp2_cd4`) but still has low actual tank final commitment
     (`15-30%`). It behaves like a strong bruiser seed, not a clean tank seed.
   - A simple sim-only tank payoff overlay (`+15%` tank HP, `+0.06`
     damage-reduction, +shield payoff) does not fix access. It only applies
     after real tanks are found, so it cannot solve the missing rank-1 entry
     point by itself.
   - Conclusion: the next roster design pass should add or convert a true
     low-rank tank identity with an explicit defensive mechanic, then retest.
     Merely telling the policy to buy robust bodies produces a different
     archetype, not tank.
   Pacing learning from the same report:
   - External reference: Riot's TFT patch notes explicitly treat combat pacing
     as a live balance target. Patch 15.3 says the set was continuing a goal
     of slowing combat pacing and nerfed units/items/artifacts accordingly:
     https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/teamfight-tactics-patch-15-3-notes/
     This is not a direct target duration for The Pit, but it validates making
     fight duration a first-class simulation metric.
   - Live baseline already has early current-tank fights around `9.81s` average
     with `10%` of early fights under `5s`. The issue is not universal early
     shortness in this narrow tank probe, but it may still appear in bursty
     non-tank matchups and must be measured globally.
   - `cooldown x2` roughly doubles current-tank pacing (`17.19s` early average)
     and removes early under-5s fights, but it triggers fatigue in about `51%`
     of current-tank fights. This is a candidate only if fatigue timing is also
     retuned.
   - `cooldown x3/x4` pushes most fights into fatigue (`~89-94%` current tank
     fatigue touch rate). A blind global `cd x4` would be too blunt unless
     the fatigue/overtime model is moved later and DoT/shield cadence is
     rebalanced around it.
   - Recommended next step: add duration reporting to a global policy/meta
     scenario, then test `cd x1.5` and `cd x2` with a later fatigue threshold
     before any live roster-wide cooldown change.
   Latest N=10 global pacing learning after adding `tools/sim.lua pacing [N]`:
   - `tools/scenarios/common.lua` now owns shared duration helpers
     (`durationSet`, `addRoundDuration`, `finishDurationSet`) and the lab
     cooldown mutator. `Rundriver` forwards an optional lab-only
     `fatigue = { start, base, ramp }` profile into `Match.run`.
   - The new `pacing` scenario crosses the full `Policies.analysisSet` with:
     live `hp2/cd1/fatigue17`, `cd1.5/fatigue17`, `cd2/fatigue17`,
     `cd1.5/fatigue24`, and `cd2/fatigue24`.
   - Preliminary N=10 results:
     - live: completion `7.9%`, avg wins `5.29`, early avg `9.91s`,
       early under-5s `11.6%`, p50 `9.13s`, p90 `14.63s`, fatigue `5.3%`;
     - `cd1.5/fatigue17`: early avg `12.52s`, under-5s `7.4%`, p50
       `12.25s`, p90 `20.08s`, but fatigue jumps to `21.6%`;
     - `cd2/fatigue17`: early avg `16.34s`, under-5s `4.2%`, p50 `16.23s`,
       p90 `24.48s`, but fatigue is too high at `45.6%`;
     - `cd1.5/fatigue24`: strongest preliminary candidate: completion
       `18.9%`, avg wins `5.77`, early avg `13.59s`, under-5s `6.8%`,
       p50 `12.33s`, p90 `20.45s`, fatigue only `4.8%`;
     - `cd2/fatigue24`: early avg `16.65s`, p50 `16.03s`, p90 `25.90s`,
       fatigue `14.4%`; it may be too slow or too fatigue-sensitive.
   - Interpretation: do not test `cd x4` further as a first live candidate.
     The next serious sweep should center around `cd x1.35` to `x1.65` with
     fatigue around `22-26s`, and should be rerun at higher N after the tank
     rank-1 identity pass.
   Latest implementation update after the first tank rank-1 identity pass:
   - `husk` is now a live rank-1 tank seed, not only a simulated probe:
     `aggro = 40`, combat-start `dmgReduce` on `role:front`, L2 strengthens
     the value, and L3 turns it into a small team wall.
   - This fixes tank access in the run driver: `current_plan` live pacing now
     forms the policy plan and strict tank final board in about `75%` of N=20
     runs. It still has `0%` completion and only `0.90` average wins, so the
     remaining defect is not access alone.
   - `tools/scenarios/tank.lua` now reports three separate final-board readings:
     `shell%` = tested plan final commit, `tank%` = strict majority-tank board,
     and `anchor%` = at least one tank on the front column. This matters
     because a healthy tank comp should usually mean "frontline anchor plus
     damage payload", not "every slot is a tank".
   - New `payload_shell` result at N=20, live pacing: `55%` completion,
     `9.50` average wins, `100%` shell final commit, `0%` strict tank commit,
     and `60%` front-tank anchor. Interpretation: tank + payload is powerful,
     but the current policy is mostly buying a strong mixed shell, not a
     readable tank archetype yet.
   - `demon_seed` remains a strong bruiser-ish tank-adjacent line
     (`7.40` avg wins live, `85%` strict tank final commit), but it is not the
     clean low-rank wall fantasy by itself.
   - Design implication: do not solve tank by demanding majority-tank boards.
     Define tank archetype health as `anchor present + payload protected +
     defensive mechanics matter`. The next pass should add/report explicit
     protected-payload metrics and then tune husk/tank supports around that.
   Latest tooling update:
   - `tools/sim.lua sweep [N]` now crosses economy profiles, pacing profiles,
     and policy filters in one deterministic grid. It writes
     `runs/report-sweep.json` plus the `sweep` block in `runs/report-ref.json`.
   - Environment controls:
     - `PIT_POLICIES=greedy_plan,committed_tank_plan`
     - `PIT_ECON_PROFILES=baseline,sap_cost,early_curve`
       (or sweep-specific alias `PIT_SWEEP_ECONOMIES=...`)
     - `PIT_BENCH_CAPS=0,2,4,6`
     - `PIT_PACE_IDS=live_hp2_cd1_f17,hp2_cd15_f24`
       (or sweep-specific alias `PIT_SWEEP_PACES=...`)
     - `PIT_PACE_PROFILES=id:hpMult:cdMult:fatigueStart[:fatigueBase[:fatigueRamp]],...`
       (or sweep-specific alias `PIT_SWEEP_PACE_PROFILES=...`)
     - `PIT_TANK_VARIANTS=current_plan,payload_shell`
     - `PIT_COMMANDER_MODE=ignore|decline|auto`
   - `PIT_COMMANDER_MODE` defaults to `ignore` to preserve historical
     baselines. Use `auto` for runs that should model the commander pedestal:
     it accepts the pedestal and moves the best existing `commandBonus` carrier
     from bench first, then board; if none exists, it declines for gold.
   - Economy reports now include an approximate merge funnel:
     `pair_buys_per_run`, `merge_buys_per_run`, and `merge_per_pair_buy`,
     globally and by shop tier. This is not yet a per-unit pair lifecycle, but
     it is enough to detect profiles that buy pairs without converting them.
   - `sweep` and `economy` also report commander placements and relic picks per
     run, so commandants/relic access can be included in balance passes without
     separate instrumentation.
   Long batch, commandants enabled (`PIT_SCEN_OUT=runs/long-2026-06-27`,
   `PIT_COMMANDER_MODE=auto`):
   - `tools/sim.lua pacing 50`: best pacing compromise is currently
     `hp2_cd15_f24`: completion `15.8%`, avg wins `6.20`, early avg `12.77s`,
     early under-5s `7.9%`, p50 `11.73s`, p90 `19.40s`, fatigue `2.8%`.
     `hp2_cd2_f24` is slower (early `15.88s`, p50 `14.48s`) but fatigue is
     much higher (`10.8%`) without better avg wins in the global pacing report.
     Live has too many short early fights (`17.4%` under `5s`).
   - `tools/sim.lua sweep 30`: `hp2_cd2_f24` often gives the highest completion
     in the integrated grid (`baseline` `16.8%`, `early_curve` `17.9%`), but it
     carries around `11%` fatigue. Treat it as a stress candidate, not the first
     live pacing candidate. `hp2_cd15_f24` is the safer candidate.
   - Economy interaction in the sweep is not solved by `sap_cost` alone:
     `sap_cost + hp2_cd15_f24` averages `5.52` wins and `8.6%` completion,
     below `baseline + hp2_cd15_f24` at `5.93` wins and `12.3%` completion in
     this batch. The stricter economy should not be locked before weak shells
     and policy timing improve.
   - `tools/sim.lua tank 50`: strict tank lines remain weak even after live
     `husk` (`current_plan` live: `0%` completion, `1.64` avg wins; `husk_seed`
     live: `0%`, `1.54`). `payload_shell` live is strong (`64%` completion,
     `9.62` avg wins, `100%` shell final commit), but only `52%` front-tank
     anchor and `0%` strict majority-tank. This confirms that the next tank
     work must define and improve "protected payload" rather than add more pure
     tank mass.
   - Follow-up tank placement probe: `tools/scenarios/tank.lua` now includes
     `protected_payload_rate` (`prot%`) and `payload_arranged`, a lab-only
     variant that swaps a tank into the front column when possible. In N=50
     targeted runs with `PIT_COMMANDER_MODE=auto`, `payload_arranged` raises
     protected payload from `52%` to `96%` live and `94%` at `cd1.5/f24`, while
     win outcomes stay close to `payload_shell` (`~9.64-9.70` wins). Learning:
     placement fixes readability/protection but the payload shell is already
     powerful; the next design problem is making the tank identity meaningful
     and not just a broad good-stuff shell.
   - `tools/sim.lua economy 30` with commandants enabled now records
     per-unit pair/merge events. `sap_cost_tiered_reroll` is the most promising
     economy pressure candidate in this batch: completion `12.3%`, avg wins
     `5.61`, full-shop afford `67.9%`, gold pressure `0.52`, leftover `6.85`.
     It produces more pressure without dropping wins like plain `sap_cost`.
   - Unit merge watchlists are now available under
     `profiles.<id>.unit_merge_watch` and `by_unit_merge`. Baseline N=30 flags
     units such as `emberling`, `byakhee`, `vanguard_drummer`, `arcane_seer`,
     and `rat_warren` as pair-heavy but merge-poor in this sample. These are
     not automatic nerf/buff decisions; they are targets for reroll-policy and
     roster-access investigation.
   New update (`runs/long-2026-06-27b`, commandants enabled where relevant):
   - `economy` and `sweep` now include true pair lifecycle metrics:
     `merge_lifecycle.resolve_rate`, `avg_rounds_to_merge`, unresolved pair
     counts, and per-unit watchlists. This replaces the old raw
     `merge_per_pair_buy` as the first signal to read.
   - `tools/sim.lua coherence [N]` is now a scenario mode. It bins fixed and
     generated teams by semantic coherence, then measures win-rate, combat
     length, and cost against representative band fields. Outliers include
     full unit/slot/level lists so generated failures are reproducible.
   - `src/lab/coherence.lua` now reads economy profiles from
     `src/run/economy.lua`; the real profile ids are `baseline`, `sap_cost`,
     `early_curve`, `tiered_reroll`, and `sap_cost_tiered_reroll`. Legacy
     aliases (`current`, `sap_like`, `curved_income`) still resolve, but new
     reports should use the run profile ids.
   - Tank coherence was corrected: `guard_frontline`, `sustain_wall`, and
     `frontline_wall` edges make readable defensive shells visible to the
     semantic model. This fixed a false low-coherence reading on `mid_tank`
     without changing gameplay.
   - `coherence N=36`, `PIT_COHERENCE_MATCHES=8`: coherence/winrate
     correlation is only `0.075`. Buckets: `00_25` wins `57.8%`, `25_50`
     `39.2%`, `50_75` `58.5%`. Interpretation: power is still too weakly tied
     to readable plans. Many low-coherence strong outliers are expensive
     endgame piles, so inspect `cheap_strong` and `high_coherence_weak` before
     making roster decisions.
   - Cheap strong examples from the coherence report: `mid_tank` (`100%`
     winrate in this field), generated mixed mid piles, `gen_focused_mid_shock`,
     `gen_focused_mid_burn`, `gen_focused_mid_bleed`, and `mid_shock`.
     High-coherence weak examples include `cross_bleed_rot`, `rot_carre_perfect`,
     `shock_nuke_croix`, `burn_ligne_perfect`, and `bleed_lock_anneau`.
     Immediate design read: mid defensive/good-stuff shells are over-rewarded,
     while several readable DoT/cross-tag showcase comps are under-rewarded.
   - `economy N=40`, profiles `baseline`, `early_curve`,
     `sap_cost_tiered_reroll`: `sap_cost_tiered_reroll` is still the best
     pressure candidate in this slice. It reaches completion `10.1%`, avg wins
     `5.41`, full-shop afford `69.1%`, gold pressure `0.52`, leftover `8.01`.
     Baseline has higher avg wins (`5.75`) but lower pressure and much more
     affordance (`93.7%` full-shop afford). `early_curve` underperforms here
     (`4.5%` completion, `5.26` wins).
   - `sweep N=20`, same economies, live pacing vs `hp2_cd15_f24`: the safer
     pacing candidate remains `hp2_cd15_f24`. Baseline improves from `7.4%`
     completion live to `11.1%` with `cd1.5/f24`; `sap_cost_tiered_reroll`
     improves from `5.8%` to `8.2%`. Fatigue stays low (`~2-3%`) in this grid.
   Relic coherence follow-up:
   - `src/lab/coherence.lua` now derives lightweight semantic profiles for
     relics. Relic ops such as affliction amplification, aura stats, haste,
     few-units bonuses, rainbow/type-mix bonuses, thorns, cleave, execute,
     percent-HP strike, and relic-added effects can now create explicit
     `relicEdges` against matching units.
   - `scoreTeam(..., { relics = { ... } })` now returns `subscores.relic` and
     `relicEdges`. The relic score adds only a small bonus to final coherence;
     it is meant to validate "this relic supports this plan", not to hide a bad
     unit graph.
   - `tools/sim.lua coherence [N]` creates matching relic variants for fixed
     authored candidates by default. Disable this with
     `PIT_COHERENCE_RELIC_VARIANTS=0` when comparing pure unit/commandant
     coherence. Compact rows now include selected relic ids.
   - Smoke reading after the relic pass: a small `coherence 1` run produces
     65 candidates, includes rows such as `mid_tank__tide_caller`,
     `end_poison__kings_bowl`, and `end_shock_multicast__forked_tongue`, and
     keeps the scenario deterministic. This is not a balance verdict yet; it
     confirms the report can now separate "readable plan without relic" from
     "readable plan with matching relic".
   Level-fit follow-up:
   - `tools/sim.lua coherence [N]` now also generates deterministic
     `__leveled` variants for fixed catalogue/band candidates. This prevents a
     common false read where a clean endgame plan is marked weak simply because
     the authored catalogue version has every unit at level 1.
   - The report now includes `level_fit` and `underleveled` per row, plus
     bucket/stage `avg_level_fit`. `high_coherence_weak` excludes clearly
     underleveled rows; those move to
     `underleveled_high_coherence_weak`. Disable this expansion with
     `PIT_COHERENCE_LEVEL_VARIANTS=0` for old-style comparisons.
   - New filtered read (`runs/long-2026-06-27e/relics-leveled-filtered`,
     `coherence N=36`, matches `8`): candidates `228`, correlation `0.189`,
     buckets `00_25` win `54.8%`, `25_50` win `45.5%`, `50_75` win `61.0%`,
     `75_100` win `47.0%`. The important change is interpretability:
     actionable `high_coherence_weak` falls to `3` rows instead of being filled
     by raw level-1 endgame catalogue comps.
   - Current true high-coherence weak targets after filtering:
     `cross_bleed_rot__leveled`, `cross_bleed_rot__leveled__grave_cap`, and
     `tank_carre_mid__leveled__tide_caller`. The first two point at a likely
     bleed->rot conversion/payoff weakness; the third says a small mid tank
     shell with a matching relic is readable but still not strongly rewarded.
   - `low_coherence_strong` remains large (`25` rows), mostly generated mixed
     piles with high investment or efficient midgame good-stuff. This is now
     the bigger systemic signal: raw stats/high-rank piles can beat readable
     plans too often.
   Marrow/board-fit follow-up:
   - `marrow_drinker` now has the documented level-aware conversion scaling:
     L2 `base 4 / growth 3 / cap 14`, L3 `base 5 / growth 4 / cap 16`.
   - Leveled fixed candidates now prioritize high-rank/level-authored pivots
     before central slot convenience. Example: `cross_bleed_rot__leveled` puts
     `marrow_drinker` at L3 instead of always putting the central aura at L3.
   - The report now includes `board_fit` and `underfilled` per row, plus
     bucket/stage `avg_board_fit`. Rows that are coherent and weak but do not
     fill enough of their declared board move to
     `underfilled_high_coherence_weak`.
   - New filtered read (`runs/long-2026-06-27g/fit-filtered`, `coherence N=36`,
     matches `8`): correlation `0.200`, `high_coherence_weak` is now only `1`
     row, `underfilled_high_coherence_weak` has `2` rows, and
     `underleveled_high_coherence_weak` has `20` rows. The only true readable
     weak row left is `tank_carre_mid__leveled__tide_caller`; `cross_bleed_rot`
     should not be judged until a filled-board variant exists.
   Outlier watchlist follow-up:
   - `tools/sim.lua coherence` now writes `outlier_unit_frequency` for
     `high_coherence_weak`, `low_coherence_strong`, `cheap_strong`, and
     `expensive_weak`. Each row reports count, average level, average winrate,
     stages, and archetypes.
   - New read (`runs/long-2026-06-27h/unit-frequency`, same settings): the
     `cheap_strong` midgame watchlist is led by `gravewarden`, `leech_thorn`,
     `thunderhead`, `skeleton`, `marauder`, `witch`, and `stormcaller`. This
     points at efficient midgame good-stuff/tank-shock shells rather than one
     isolated offender.
   - `low_coherence_strong` is led by `marauder`, `demon`, `brood_mother`,
     `skeleton`, and `mimic_spawn`. This says high-stat/bruiser/summon/copy
     packages can win without looking like a readable affliction plan. The next
     design pass should either classify that as a real "bruiser/summon/copy"
     plan in coherence, or reduce the raw efficiency if it remains too generic.
   Summon/mimicry and mid-field follow-up:
   - The coherence graph now creates edges for `summon` + faint payoff,
     summon-line stacking, `repeat_ability` + on-hit carriers, and
     `amplify_auras` + aura-style units. This moves some summon/mimicry winners
     out of the lowest coherence bucket and raises graph coverage from `2257`
     to `2433` level-1 edges.
   - `src/lab/bands.lua` now includes `mid_rot` and the mid field includes it
     as an intended mid-caliber anti-wall probe. This removes the lone
     `high_coherence_weak` row from the coherence report, but does not by
     itself solve mid-tank dominance.
   - `rot_hound`, `decay_tender`, and `necro_leech` now have the documented
     level-aware rot scaling. Batch
     `runs/long-2026-06-27k/rot-level-midfield` still shows `mid_tank` at
     `100%` winrate in the representative field while `mid_rot` remains around
     `42.9%` (`59.4%` for the leveled variant). Learning: the tank problem is
     not only "rot levels were missing"; the midgame likely needs either a
     stronger explicit anti-wall piece/composition or a direct efficiency pass
     on the wall package.
   Economy/pacing follow-up:
   - `runs/long-2026-06-27l/post-rot-economy`, `economy 30`, commander auto:
     baseline remains stronger in this slice (`8.1%` completion, `5.58` avg
     wins, `93.8%` full-shop afford). `sap_cost_tiered_reroll` creates real
     pressure (`67.8%` afford, pressure ratio `1.02`) but falls to `4.7%`
     completion and `5.21` avg wins. Do not promote it as default yet.
   - `runs/long-2026-06-27l/post-rot-sweep`, `sweep 12`: `hp2_cd15_f24`
     remains the safer pacing candidate for baseline (`8.3%` completion,
     `6.05` wins, p50 combat `11.52s`, fatigue `2.5%`). The heavier
     `hp2_cd2_f24` creates more readable-length fights and better baseline
     completion (`13.2%`, `6.20` wins, p50 `15.22s`) but fatigue jumps to
     `13.0%`. Treat it as an exploratory upper bound, not a default.
   Fill-variant follow-up:
   - `tools/sim.lua coherence` now creates optional `__filled` variants
     (`PIT_COHERENCE_FILL_VARIANTS=0` disables them) for underfilled fixed
     nuclei. The report includes `filled_resolutions`, which compares a weak
     underfilled nucleus against its best filled + adequately leveled version.
   - `runs/long-2026-06-27m/fill-variants`, `coherence 12`, shows why this
     matters: `cross_bleed_rot` raw stays dead (`0%` winrate, `board_fit 0.625`)
     and the leveled-but-underfilled row only reaches `28.6%`; the filled +
     leveled version reaches `85.7%`. This reframes it as a viable late
     invested rot/bleed nucleus, not simply a bad idea.
   - Cost caveat: the successful filled version costs `96` gold-equivalent in
     the current comp-cost model (`cost_score 0.809`) and uses
     `pit_maw`, `wither_bloom`, and `blight_spreader` as fillers. It is a
     late-game endpoint; economy simulations still need to prove whether a
     player can reach it naturally.
   Plan-access follow-up:
   - `tools/sim.lua economy` now reports `plan_access` for default critical
     targets and optional `PIT_PLAN_TARGET_SPECS` entries. It measures final
     board unit coverage, level coverage, complete rate, final-gold ratio,
     peak board/held coverage, first `25/50/75/100%` level-coverage rounds,
     losses before/after each threshold, and combat winrate by board coverage
     band against a target plan.
   - A custom target spec for the filled rot/bleed endpoint
     (`cross_bleed_rot_filled=pit_maw:2+razorkin+gash_fiend+clot_mender+marrow_drinker:3+wither_bloom:2+blight_spreader:2+hookjaw`)
     confirms the access problem. In
     `runs/long-2026-06-27n/plan-access-targeted-v5`, `committed_rot_plan`
     reaches `0%` of the target units because the broad rot policy ignores the
     bleed enablers. The new `committed_cross_bleed_rot_plan` now secures a
     body before XP, keeps rot/bleed support units for tempo, and reaches about
     `22.5%` unit coverage and `13.8%` level coverage in baseline, with
     `8.75` average wins, but still never completes the endpoint.
   - Learning: the endpoint is combat-viable when force-built, but not naturally
     accessible under current shop/economy/policy pressure. The next useful
     work is not a direct buff to `cross_bleed_rot`; it is better target-aware
     reroll/XP timing and/or cheaper stepping-stone units that let the player
     progress toward the endpoint without dying.
   - Trajectory update: `runs/long-2026-06-27n/plan-trajectory-v1` shows the
     same endpoint almost never enters a real transition state. Under baseline,
     `committed_cross_bleed_rot_plan` reaches held `25%` level coverage in only
     `6.7%` of runs and never reaches `50%`; under `sap_cost_tiered_reroll`,
     held `25%` improves to `30%`, but board `25%` is still only `6.7%`, and
     `50%` remains `0%`. The tier breakdown points to space pressure rather
     than gold: baseline tier 4 desired offers are `91.5%` slot-limited while
     still gold-affordable, and tier 5 is `100%` slot-limited.
   - Oracle update: each `plan_access` target now carries a forced-combat
     `oracle` with cost, coherence/subscores, tested PvE rounds, winrate, and
     duration. In `runs/long-2026-06-27n/plan-oracle-v1`,
     `cross_bleed_rot_filled` has `0.552` coherence and costs `96`
     gold-equivalent. It wins forced fights at rounds 8 and 10 (`100%` vs
     `gorge_pack`/`drowned_legion`) but loses at rounds 12 and 14 (`0%` vs
     `pit_sovereign`), for `50%` total forced winrate over the oracle window.
     This means the target is both poorly accessible and not a complete
     late-endpoint without additional commander/relic/scaling support.
   - Acquisition-funnel update: `plan_access.acquisition_funnel` now reports
     target offers, gold affordability, playable-space rate, buys, pair/merge
     buys, sells, first-seen rounds, and per-unit miss reasons. In
     `runs/long-2026-06-27n/acquisition-funnel-v3`, baseline +
     `committed_cross_bleed_rot_plan` sees only `39.6%` of distinct target
     units per run (`3.17/8`), buys `3.87` target pieces/run, has no gold issue
     (`100%` gold-affordable), almost no policy misses (`0.1/run`), and no
     target sells. The blockers are space (`2.0` missed-space offers/run) and
     rare piece access: `pit_maw` seen in only `10%` of runs, `marrow_drinker`
     `6.7%`, `wither_bloom` `16.7%`, and `blight_spreader` `16.7%`.
     Interpretation: this cannot be a natural endpoint in the current economy
     unless it gets stepping-stone versions, support from commander/relic
     access, better odds/tier timing, or a simpler target definition.
   - Stepping-stone target: `rot_bleed_mid` was added to the composition
     catalog and to default economy plan targets. The env-only probe
     `runs/long-2026-06-27n/stepping-target-v1` showed this 6-slot, no-rank-5
     plan is much more teachable: `25%` held level coverage in `93.3%` of
     baseline runs, `50%` in `40%` (`60%` under `sap_cost_tiered_reroll`),
     target-unit seen rate `71.7%`, and cost `24` gold-equivalent. Its oracle
     still falls off at rounds 8/10 (`58.3%` forced winrate overall), so it is
     a midgame bridge, not a finisher. The late `cross_bleed_rot_filled` target
     should be treated as an evolved version that needs commander/relic/scaling
     support.
   - Support-access update: `plan_access.support_access` now records focused vs
     generic relic and commander support. `Rundriver` emits `relic_offer`,
     `relic_pick`, `commander_window`, and `commander_place` events when
     `recordEvents=true`; economy reports classify each support through
     `Coherence.scoreTeam`. In
     `runs/long-2026-06-27n/support-access-v1`, baseline +
     `committed_cross_bleed_rot_plan` sees focused support for `rot_bleed_mid`
     in `80%` of runs and uses it in `55%`; under
     `sap_cost_tiered_reroll`, this falls to `50%` seen / `20%` used. Relevant
     focused relics were `grave_cap`, `weeping_nail`, `link_cable`,
     `plague_communion`; focused commanders surfaced as `gash_fiend`,
     `razorkin`, `necro_leech`, and `rot_hound`. Interpretation: support exists
     but current relic/commander choice is not target-aware enough.
   - Rot/bleed L3 update: `carrion_pecker` now has authored L2/L3 rot/heal
     scaling, while `rot_hound` and `clot_mender` are marked as L3 clutch
     pieces with command scaling to `0.26`. In
     `runs/long-2026-06-27n/rot-bleed-l3-v1`, no new
     `carrion_pecker`/`rot_hound`/`clot_mender` L3 appeared in `cheap_strong`.
     The env target
   `rot_bleed_bridge_late=clot_mender:2+razorkin:2+gash_fiend:2+hookjaw+rot_hound:3+carrion_pecker:3+marrow_drinker:2+necro_leech:2`
   costs `74` gold-equivalent, has `0.663` coherence, wins force-build at
   rounds 8/10, but still loses rounds 12/14 (`50%` oracle). Run access is
   still the larger blocker: baseline held `50%` coverage is only `2.5%`
   (`20%` under `sap_cost_tiered_reroll`), and `marrow_drinker` was seen in
   only `7.5%` of baseline runs and bought `0/run` because it was not
   playable when offered. Interpretation: the L3 bridge is safe, but late
   rot/bleed still needs target-aware space management or a lower-rank late
   pivot.
   - Target-aware policy update: `committed_unit_set_plan` now separates exact
     core targets from support fillers, picks relics and commanders against
     the target's coherence graph, and can sell support fillers to buy core
     pieces. Batch
     `runs/long-2026-06-27n/target-aware-policy-v1` shows this fixes the
     decision-quality problem: baseline target-offer buy-rate improves from
     `81.2%` to `92.9%`, held `50%` coverage from `2.5%` to `27.5%`, and
     focused support used/run from `47.5%` to `85%` with no missed focused
     relic/commander opportunities. SAP also improves held `50%` from `20%`
     to `37.5%`, but keeps lower wins. Remaining blocker: `marrow_drinker`
     remains too rare (`15%` seen in baseline, `12.5%` under SAP), so late
     rot/bleed still needs better XP/reroll timing, a lower-rank pivot, or an
     alternate endpoint that is not pinned to one rank-5 unit.
   - XP/tier-policy probe: two diagnostic variants were added. The brute
     `committed_cross_bleed_rot_late_plan` rushes rank 5; the staged
     `committed_cross_bleed_rot_staged_plan` stays rank 3 early, then targets
     rank 4 at round 7 and rank 5 at round 10. In
     `runs/long-2026-06-27n/staged-tier-policy-v1`, brute late access sees
     `marrow_drinker` much more often (`60%` baseline) but collapses the plan
     (`7.4` wins, held `50%` only `2.5%`). Staged is healthier but still not
     better than the current target-aware plan: baseline wins/completion stay
     `8.5`/`10%`, `marrow_drinker` seen rises to `32.5%`, but held `50%` is
     `25%` versus the current plan's `27.5%`; SAP staged is also worse than
     current SAP. Learning: the issue is not simply "get to rank 5 sooner".
     The late bridge needs a lower-rank pivot, an alternate endpoint, or
     XP/reroll decisions gated by actual target coverage.
   - Lower-rank pivot update: `rot_bleed_rat_core` was added to the composition
     catalog and to default economy plan targets. It uses
     `carrion_pecker:3+rot_hound:3+gnaw_rat:3+clot_mender:2+razorkin:2+gash_fiend:2`
     as a clean low-rank reroll endpoint. Batch
     `runs/long-2026-06-27n/socrates-pivots-v1` shows it is the best tested
     no-`marrow_drinker` target: cost `57`, max rank `3`, oracle forced
     winrate `100%`, baseline held `50%` coverage `60%` under the current
     target-aware policy (`65%` under staged), and SAP held `50%` `75%`.
     Rank-4 alternatives (`rot_bleed_rank4_lock`, `rot_core_r4_spread`) stay at
     `50%` oracle and much lower held `50%`. Learning: rot/bleed should expose
     a real low-rank reroll endpoint, while the old rank-5 conversion can
     remain an optional premium evolution rather than the main late bridge.
   - Rat-core coherence check: `runs/long-2026-06-27n/rat-core-coherence-v1`
     confirms the catalog `rot_bleed_rat_core` row is coherent and strong
     (`coherence 0.754`, forced-panel `winrate 100%`, `gold 57`,
     `cost_score 0.657`; `grave_cap` raises coherence to `0.812`). It is not
     flagged as `cheap_strong`, so do not immediately nerf the endpoint just
     because it wins the forced panel. The active red flags are still cheaper
     midgame boards, especially tank/shock entries around `17-27` gold and
     `rot_bleed_mid__leveled` (`30` gold, `100%` in this panel). Next balance
     work should distinguish "expensive coherent payoff" from "cheap mid board
     overperforming under its cost".
   - Cost-model correction: `Compcost` now returns `rankPressure` and uses it
     as an access floor for `score`; coherence rows also expose
     `weighted_score`, `rank_pressure`, and `foe_breakdown`. This fixed a major
     read error: rank-4/5 boards were previously flagged as cheap because the
     score mostly read raw gold. In
     `runs/long-2026-06-27n/rank-pressure-coherence-v2`, `cheap_strong` drops
     from `37` to `7`. The remaining cheap-strong rows are now mostly genuine
     low/mid-rank candidates (`rot_bleed_mid__leveled`, `rot_bleed_mid`, some
     generated bleed/bruiser/poison boards), while tank/shock rank-4 access
     false positives leave the list.
   - Duplicate-pressure correction: ablation of `rot_bleed_mid__leveled` showed
     the `75% -> 100%` jump is mostly caused by adding a fourth L2
     (`clot_mender` at center) to an already leveled mid board; reverting the
     L2 aura values alone did not fix it. `Compcost` now returns
     `duplicatePressure` and uses it as another access floor for `score`, and
     coherence rows expose `duplicate_pressure`. This should reduce false
     "cheap" reads on boards that require many duplicated copies before we
     reach for data nerfs. In
     `runs/long-2026-06-27n/duplicate-pressure-coherence-v1`, `cheap_strong`
     drops from `7` to `5`; `rot_bleed_mid__leveled` leaves the cheap list at
     `cost_score 0.50`, while base `rot_bleed_mid` remains a watch item
     (`75%` winrate, but still loses to `mid_tank` and `cross_venom_pyre`).
   - XP coverage-gate update: `committed_unit_set_plan` now supports
     `xpCoverageGate`, which can let a policy reach a base shop rank and then
     block further XP buys until real target coverage reaches unit/level
     thresholds. Economy reports expose `xp_gate_blocks_per_run`,
     `xp_gate_block_round_rate`, `avg_xp_gate_unit_coverage`, and
     `avg_xp_gate_level_coverage`. In
     `runs/long-2026-06-27n/coverage-gated-xp-v2`,
     `committed_cross_bleed_rot_coverage_plan` cuts baseline XP from the staged
     plan's `5.0/run` to `2.5/run`, with about `4.675` XP-gate blocks/run, but
     does not materially improve the old rank-5 target. Interpretation: late
     cross rot/bleed is not just an XP timing issue; `marrow_drinker` remains
     too rare/late for the core endpoint.
   - Rat-core target policy update:
     `committed_rot_bleed_rat_core_plan` directly targets
     `clot_mender:2+razorkin:2+gash_fiend:2+rot_hound:3+carrion_pecker:3+gnaw_rat:3`.
     In `coverage-gated-xp-v2`, baseline improves to `8.225` wins, `80%` held
     `50%` rat-core coverage, and `0.633` final held level coverage. SAP-cost
     reaches `92.5%` held `50%`. Interpretation: use rat-core as the active
     rot/bleed reroll baseline; keep rank-5 conversion as premium evolution
     unless a later economy/pass makes it reliably reachable.
   - Pair-lifecycle diagnostic update: `Rundriver` sell events now include the
     sold unit level, and `merge_lifecycle` reports `sold_before_merge` plus
     `sold_before_merge_rate` globally, by unit, and in the watch list. This is
     an event-level diagnostic, not exact per-copy identity: it counts later
     sales compatible with a formed pair before its matching merge. Batch
     `runs/long-2026-06-27n/pair-loss-rat-core-v1` shows
     `sold_before_merge_rate = 0` across the targeted policies. Learning:
     unresolved pairs in the committed rot/bleed plans are not mainly caused by
     destructive resale after pair formation. The bigger issue is trajectory
     pressure: committed plans resolve only about `49-60%` of pairs, while
     `greedy_stats` resolves about `85-93%`; rat-core reaches held `50%`
     coverage often (`75-92.5%` depending economy under its dedicated policy)
     but held `75%` remains low (`0-15%`) and full completion stays `0`.
     Therefore the next lever is better space/reroll targeting and stage
     thresholds, not just "never sell pairs".
   - Rat-core support-gate update: a pure strict rat-core policy was tested and
     rejected. With heavy reroll (`rat-core-strict-policy-v1`) it improved
     held `75%` coverage but spent about `33-37` rerolls/run and lost tempo;
     with the standard reroll cap (`rat-core-strict-policy-v2`) it collapsed
     wins because the board lacked enough early support. The retained candidate
     is `committed_rot_bleed_rat_core_gated_plan`: it allows rot/bleed supports
     early, then stops buying them once held rat-core level coverage reaches
     `50%` unless the board still has fewer than `4` bodies. In
     `runs/long-2026-06-27n/rat-core-gated-policy-v1`, baseline wins/completion
     match the current rat-core plan (`8.267`, `11.7%`) while space misses fall
     `2.32 -> 2.05`, avg final held level coverage rises `0.631 -> 0.642`, and
     held `75%` improves `10% -> 15%`. SAP and tiered variants show the same
     direction: small or neutral win changes, better coverage, fewer space
     misses. Learning: the right lever is not removing supports, but staging
     them so they stop competing with the core after the run has committed.
   - Cost-aware outlier update: duplicate-pressure density was raised so
     multi-L2 mid boards are no longer underpriced (`three L2 in six slots`
     reads about `0.50` instead of `0.425`, while one L2 remains at the
     `0.30` floor). Coherence rows now expose `win_cost_delta`, and
     `low_coherence_strong` requires a positive cost-adjusted overperformance
     (`>= 0.10`) instead of flagging expensive stat boards that merely win at
     high investment. In `runs/long-2026-06-27n/coherence-cost-aware-outliers-v1`,
     `rot_bleed_mid` leaves `cheap_strong`, `low_coh strong` drops `3 -> 0`,
     and the remaining `cheap_strong` rows are only generated band variants
     (`mid_poison__leveled`, `mid_rot__leveled`) with moderate deltas around
     `0.21` and clear losses into `mid_tank`, `mid_shock`, and
     `cross_venom_pyre`.
   - Fine pacing sweep update:
     `runs/long-2026-06-27n/pacing-fine-candidates-v1` crossed
     `baseline/sap_cost/early_curve`, six focused policies, and cooldown/fatigue
     profiles around the previous candidate range. The best first live
     candidate is `cd1.5_f26` (`hp x2`, cooldown x1.5, fatigue at 26s):
     baseline early avg `14.87s`, p50 `11.97s`, p90 `19.42s`, fatigue `1.8%`,
     wins `8.47`; SAP early avg `14.96s`, p90 `19.40s`, fatigue `1.5%`; early
     curve early avg `14.70s`, fatigue `2.5%`. `cd1.35_f24` is the conservative
     alternative (early around `13-14s`, fatigue `1.5-2.5%`), while `cd1.65`
     starts pushing p90 above `21s` and should remain a stress candidate. Do
     not jump to the old suggested `cd x4`: prior tank/pacing runs already
     showed it overuses fatigue.
   - Pacing scoring and live application update:
     `Common.durationFit(duration)` now scores fight duration against the
     current target envelope: early average `13-16s`, all-fight p50 `11-14s`,
     p90 `<=22s`, fatigue-touch `<=5%`, and early under-5s `<=6%`. `pacing`
     and `sweep` reports expose both `duration_fit` diagnostics and direct
     `duration_fit_score` fields. `sweep` also writes `recommendations` with
     `selection_score = duration_fit_score + bounded wins/completion deltas vs
     live`, so long batches can be read without hand-sorting cells.
   - Broad pacing confirmation:
     `runs/long-2026-06-27n/pacing-fit-broad-v1` crossed all analysis policies
     at N=30 over `baseline/sap_cost/early_curve` and focused pace candidates.
     Live pacing is confirmed too short (`baseline`: fit `0.626`, early avg
     `10.04s`, p50 `9.53s`, fatigue `6.5%`; `early_curve`: fit `0.546`, early
     avg `9.24s`). `cd1.5_f24` is the best baseline/early-curve compromise
     (`baseline` fit `0.987`, wins `6.25`, completion `11.3%`, early `13.88s`,
     p50 `12.8s`, fatigue `4.9%`; `early_curve` fit `0.982`, wins `6.06`,
     completion `10.8%`). `cd1.5_f26` is slightly better under `sap_cost`
     (`fit 0.961`, wins `6.04`, completion `8.8%`, fatigue `3.2%`) and reduces
     fatigue in baseline (`2.6%`) while keeping early/p50 in target. `cd1.65`
     improves some win counts but is more fragile: baseline p90 reaches `23.4s`
     and fatigue `6.1%`, so keep it as a stress candidate, not the live default.
   - Live pacing implementation:
     `src/run/pacing.lua` is now the source of truth for live combat pacing and
     player-facing cooldown display. The active `live` profile is
     `live_hp2_cd15_f26` (`hp x2`, cooldown x1.5, fatigue at `1560` ticks /
     `26s`). `Combat.new`/`restart` use this profile, while unit data remains
     authored at base cooldown. Monster cards, the gallery, and shield-caster
     mechanic text use `Pacing.formatCooldown(...)`, so displayed CD matches the
     real live combat cadence. `PIT_LIVE_PACE=legacy` can temporarily switch
     the app back to `hp x2 / cooldown x1 / fatigue17` for comparison. The
     simulation tools remain explicitly parameterized: `Rundriver` and
     `Match.run` accept `cooldownMult`, and `pacing`/`sweep`/`tank` pass it as
     an arena option instead of mutating specs.
   - Real bench-capacity sweep:
     `Build`/`Rundriver` now accept lab-only `benchSize` while live remains at
     `4` slots. `tools/sim.lua economy` accepts `PIT_BENCH_SIZES=4,6,8` and
     writes separate profile keys such as `baseline_bench6`, so reports can
     compare true reserve capacity instead of only the old virtual
     `PIT_BENCH_CAPS` affordability diagnostic. In
     `runs/long-2026-06-27n/bench-real-v1` (all analysis policies, N=20),
     larger benches do what expected on access (`baseline` desired-buy-all
     `35.7% -> 42.7% -> 50.8%` and slot-limit `63.5% -> 56.6% -> 48.2%` for
     bench `4/6/8`), but they do not automatically improve wins or completion
     (`6.47/8.2%`, `6.27/10.4%`, `6.32/6.4%`). Learning: reserve capacity is
     a real acquisition lever, but it must be paired with better policy/staging;
     otherwise it can dilute deployed tempo.
   - Rat-core reroll-policy breakthrough:
     Two additional analysis policies were added for the current reroll target:
     `committed_rot_bleed_rat_core_no_xp_plan` and
     `committed_rot_bleed_rat_core_deep_reroll_plan`. They buy no XP manually
     and rely on passive shop-tier progression; the deep-reroll variant raises
     the per-round reroll cap to `5`. In
     `runs/long-2026-06-27n/bench-rat-policy-v1` (baseline, N=80), deep-reroll
     is the first strong rat-core policy: bench4 reaches `50%` completion,
     `9.50` avg wins, `11.66` pair buys/run, `9.11` merges/run, and
     `78.1%` merge-per-pair. Bench6 remains strong but lower (`46.25%`,
     `9.43` wins), while bench8 drops (`28.75%`, `9.25` wins) despite higher
     held-level coverage. Learning: this comp wants aggressive reroll tempo
     more than extra bench size. The best current hypothesis is live bench4
     plus explicit reroll archetype support, not a blind reserve-size increase.
   - Shop-XP parameterization and slow-tier probe:
     `Economy` now exposes simulation-tunable `passiveShopXpPerRound`,
     `passiveShopXpByRound`, `buyXpAmount`, and `xpToLevel`; `RunState` still
     exports the live defaults but reads these values through the resolved
     economy profile. A new analysis profile, `slow_shop_xp`, uses thresholds
     `{3,6,9,12}` so passive tier 3 arrives around round 10 instead of round 8.
     The UI BUY XP button also reads `run:currentBuyXpCost()` so lab/custom
     profiles cannot display the wrong price. In
     `runs/long-2026-06-27n/shop-xp-global-v1` (all policies, N=30),
     `slow_shop_xp` improves merge conversion (`71.7% -> 74.7%`) and slightly
     improves gold affordability, but lowers completion (`13.3% -> 7.3%`),
     wins (`6.71 -> 6.09`), and relic picks (`2.01 -> 1.77`). In the focused
     rat-core run `runs/long-2026-06-27n/shop-xp-rat-core-v1` (N=80), it again
     improves desired access (`69.3% -> 72.0%`) and merge conversion
     (`69.1% -> 73.1%`) but slightly lowers wins/completion (`8.63/21.6% ->
     8.41/18.1%`). The strongest deep-reroll policy stays basically stable
   (`50%` completion baseline vs `48.75%` slow XP) while resolving more pairs
   (`78.1% -> 84.3%`). Learning: slower shop tiers are useful as a diagnostic
   and may help low-rank reroll access, but they are not a live economy
   recommendation alone because they delay high-rank support and reduce run
   conversion. Prefer targeted reroll policy/support changes before changing
   the default shop XP curve.
   - Exact merge-copy lifecycle:
     `Rundriver` now assigns a lab-only `copyId` to every bought/placed unit and
     `Build` emits optional merge-observer events when `checkMerges` or
     full-board catalyst merges resolve. Economy reports can now expose
     `exact_pairs`, `exact_resolved`, and `exact_resolve_rate`, matching a pair
     to the real copies that merged instead of only matching by unit id, level,
     and later round. A micro rat-core run produced `34` exact pairs with
     `85.3%` exact resolution; this unlocks the next pass: distinguish pairs
     that failed because the third copy never appeared, because one exact copy
     was sold, or because board/bench tempo crowded them out.
   - Exact merge terminal causes:
     the next pass is now implemented. `Rundriver` exposes `finalCopies`
     (`copyId`, id, level, board/bench slot), and `Common.addMergeLifecycle`
     classifies unresolved exact pairs into `terminal_causes`:
     `sold_exact_copy`, `held_to_run_end`, `crowded_out`, `no_third_copy`, and
     `unknown`, with counts and rates globally, by unit, and in the watch list.
     This is still a diagnostic layer only; it does not mutate run behavior.
   - Terminal-cause first read:
     `runs/long-2026-06-27o/terminal-causes`, N=8 over baseline/early_curve/
     sap_cost and reroll/rat-core/broad policies, showed the unresolved pairs
     are overwhelmingly retained rather than thrown away:
     baseline `444` pairs / `130` unresolved / `70.7%` resolve, early_curve
     `448` / `100` / `77.7%`, sap_cost `427` / `117` / `72.6%`; in all three
     profiles unresolved terminal causes were `100% held_to_run_end`, `0%`
     sold, `0%` crowded out. Current read: the active reroll problem is mostly
     third-copy arrival/timing and shop odds, not players selling exact pair
     pieces. Watch units include `wailing_shade`, `gash_fiend`, `hookjaw`,
     `rot_hound`, and `bore_worm` depending on economy profile.
   - Third-copy access diagnostic:
     `merge_lifecycle` now also exposes `third_copy_access` for unresolved
     exact pairs: `never_offered`, `offered_policy_skipped`,
     `offered_space_blocked`, `offered_gold_blocked`, and `unknown`, globally,
     by unit, and in the watch list. This is an offer-window diagnostic: reroll
     events currently record the new shop but not the exact gold after every
     intermediate action, so affordability for mid-round rerolls is a
     conservative approximation. In
     `runs/long-2026-06-27o/third-copy-access` (N=8 over baseline/
     early_curve/sap_cost and reroll/rat-core/broad policies), most unresolved
     pairs simply never saw a later third copy: baseline `119/130` unresolved
     (`91.5%`), early_curve `93/100` (`93.0%`), sap_cost `99/117`
     (`84.6%`). Policy-skipped offers are secondary (`8.5%`, `7.0%`,
     `15.4%` respectively); space and gold blocks were `0%` in this panel.
     Current read: the next live knobs should be shop odds, targeted reroll
     support, or freeze/hold mechanics for pair-completion windows, not raw
     gold affordability or anti-sell policy fixes.
   - Pair-completion support experiment:
     the lab now has opt-in economy profiles that apply a run-driver-only shop
     support rule after rolls: if the player holds exactly two level-1 copies
     of a unit and no current shop offer completes that pair, the driver can
     replace one unfrozen offer with the missing third copy. Profiles added:
     `pair_completion_light`, `pair_completion_delayed`,
     `sap_cost_pair_completion`, and `sap_cost_pair_completion_delayed`.
     The delayed variants wait for two missed shop windows before injecting the
     pair-completion offer. This is not live gameplay yet; it is a balance-lab
     probe for pity/shop targeting. `tools/scenarios/economy.lua` now uses the
     same world seed for every profile in a bench/run pair, so profile
     comparisons are paired instead of being partially seed-noisy.
   - Pair-completion first read:
     `runs/long-2026-06-27p/pair-completion-paired-n30` (N=30, baseline/
     pair-completion/SAP-cost profiles, same policies) showed the support does
     exactly solve the level-up access problem but does not automatically
     improve run completion. Baseline moved from `75.9%` merge resolution to
     `93.8%` with `pair_completion_light` and `91.9%` with delayed support;
     SAP-cost moved from `74.2%` to `94.2%`/`92.6%`. Average wins rose slightly
     (`8.44 -> 8.57` baseline-light, `8.18 -> 8.37` SAP-light), but completion
     stayed flat/slightly lower (`19.5% -> 18.1%`, `11.4% -> 11.0%`). Current
     read: pair-completion support is promising for making level-ups feel
     attainable, but by itself it can overfeed duplicate investment and should
     be paired with better policy/tuning around when a level-up is worth more
     than board stabilization. Do not ship this as a raw always-on rule yet.
   - Level-up coverage audit:
     added `tools/levelup_report.lua`, a deterministic headless report that
     writes `runs/report-levelups.json` and lists authored level-up coverage,
     clutch/transformative flags, coverage by rank, and priority candidates for
     the next authored deltas. First read: only `12/110` monsters currently
     have authored ability level-ups; low/mid rank coverage is `11/75`; only
     `6` units are marked level-3 clutch and `0` are marked transformative.
     Rank coverage is very uneven: rank 1 `4/12`, rank 2 `2/32`, rank 3
     `5/31`, rank 4 `0/25`, rank 5 `1/10`. Top low-rank candidates that still
     need authored progression include `ash_moth`, `demon`, `live_wire`,
     `marauder`, and `skeleton`, followed by rank-2 plan pieces like
     `bore_worm`, `byakhee`, `chitin_drone`, and `cinder_cur`. Current read:
     before final economy conclusions, expand level-up deltas enough that
     low-rank reroll and mid-rank bridge comps have real L2/L3 hooks.
   - First low-rank level-up expansion:
     expanded `src/data/unit_levels.lua` with conservative authored deltas for
     `marauder`, `skeleton`, `demon`, `ash_moth`, `live_wire`, `cinder_cur`,
     `bore_worm`, `byakhee`, and `chitin_drone`. These changes only use
     existing mechanics/params already understood by the resolver and cards:
     first-hit/execute values, thorns, lifesteal, burn, shock, rot, bleed,
     poison, and command aura values. Level-up coverage is now `21/110`;
     low/mid coverage is `20/75`; level-3 clutch coverage is now `12`, up from
     `6`. Rank 1 is now mostly covered (`9/12`), while rank 2+ still needs a
     lot of work. Targeted audits passed (`tests/effect_audit.lua`,
     `tests/unit_resolver.lua`, `tests/coherence.lua`, and
     `tools/levelup_report.lua`). A short economy smoke after the pass,
     `runs/long-2026-06-27q/levelup-reroll-pass-n24`, did not show a gross
     regression: baseline `25.0%` completion / `8.63` avg wins / `79.3%`
     merge resolution; pair-completion profiles still mainly act as merge
     accelerators (`94-95%` merge resolution) without becoming an obvious
     completion buff. Current read: continue expanding rank-2/rank-3 bridge
     progressions, then rerun larger panels before live economy decisions.
   - Rank-2 bridge level-up expansion:
     added L2/L3 ability deltas for the visible bridge pieces that appear in
     reference plans: `emberling`, `pyre_tender`, `razorkin`, `gash_fiend`,
     `hookjaw`, `coil_viper`, `stormcaller`, `thunderhead`, `static_swarm`,
     `flesh_warband`, `bone_choir`, `arcane_seer`, `abyss_maw`,
     `order_marshal`, `vanguard_drummer`, and `rear_goad`. This lifts authored
     coverage to `37/110`, low/mid coverage to `36/75`, rank-2 coverage to
     `22/32`, and L3 clutch coverage to `17`. The pass intentionally uses only
     existing resolver/card params: DoT dps/duration, slow, shock cap/volt,
     vulnerability marks, type/position auras, regen, haste, and command aura
     values. Targeted audits passed (`tests/unit_resolver.lua`,
     `tests/effect_audit.lua`, `tests/coherence.lua`,
     `tools/levelup_report.lua`).
   - Rank-2 economy smoke:
     `runs/long-2026-06-27r/rank2-levelup-pass-n16` crossed four economy
     profiles with targeted broad/committed policies after the rank-2 pass. It
     is not N-to-N comparable with earlier wider panels, but it did not show an
     immediate completion spike: baseline `13.2%` completion / `6.94` avg wins
     / `71.3%` merge resolution; pair-completion-light `13.2%` / `7.22` /
     `92.0%`; pair-completion-delayed `12.5%` / `7.13` / `89.8%`; `sap_cost`
     `9.7%` / `6.59` / `68.0%`. Current read: level-up value is now more
     legible for rank-2 bridge pieces, but economy/access still controls
     whether those levels appear in real runs.
   - PvE bossrush/scoring prototype:
     the user added `docs/generation/generateur-abominations.html`, a seeded
     visual generator for ten abomination families. The lab now has a pure data
     bridge for these designs: each abomination is represented as one huge boss
     plus three killable generals. The generals stand in front of the boss and
     block the existing deterministic targeting; once every non-boss right-side
     unit and summon is dead, a scoring window starts and the lab counts damage
     dealt to the boss. This models the desired endgame fantasy: after a winning
     run, the player should be able to test the build against thematic PvE
     abominations, clear the support threats, then chase a satisfying damage
     score on an enormous target.
   - Bossrush implementation shape:
     `src/data/abominations.lua` holds the lab catalogue, `src/lab/bossrush.lua`
     runs deterministic bossrush fights without render/audio/wall-clock state,
     and `tools/sim.lua bossrush` writes `report-bossrush.json` with clear rate,
     survival rate, full scoring-window rate, boss kill rate, average boss
     damage, score damage, score DPS, and score damage by cause. Environment
     filters are `PIT_BOSSRUSH_COMPS` and `PIT_ABOMINATIONS`, so future sweeps
     can isolate a single boss family, archetype, or policy.
   - Bossrush first read:
     in `runs/long-2026-06-27n/bossrush-prototype-v5` with twenty seeds per
     comp/boss, `poison_diamant_perfect` dominates current PvE scoring
     (`100%` clear/survival/full-window, `701.3` average score damage,
     `35.06` score DPS). `cross_venom_pyre` is second (`98.5%` clear, `76.5%`
     full-window, `480.1` score damage). Shock, burn, bleed, and rot can clear
     some bosses but score far lower; tank/shield boards sometimes survive but
     do not produce a full scoring window; brute bruiser fails the mode. Boss
     side tuning is now in a readable range after reducing Leviathan, Kraken,
     Brasier, and Ruche.
   - Bossrush boss-family read:
     `kraken` and `brasier` are the cleanest current scoring bosses (`66.7%`
     and `40%` full-window respectively), while `idole` and `ossuaire` often
     let teams clear but punish the transition into scoring (`66.7%`/`65%`
     clear but only `26.7%`/`15.6%` full-window). `ruche` moved from a hard wall
     to a real swarm/cleave check (`43.3%` clear, `13%` full-window): poison
     converts it fully, cross gets a narrow score window, shock/ward can clear
     without surviving the score phase. `devoreur`, `floraison`, `leviathan`,
     `regard`, and `vermine` sit in the hard-but-readable band.
   - Bossrush balance warning:
     the current endpoint heavily favors poison/cross sustained DPS. That is
     acceptable as a first endgame-scoring prototype, but not as a final boss
     meta: future boss/relic work should add boss families that test poison
     ramp, cleanse/anti-stack, burst windows, shield stripping, and cleave
     separately so "best PvE score" does not collapse into one affliction.
     `tools/sim.lua bossrush` now writes a `recommendations` section; in v5 it
     raises `dominant_scoring_archetype` for `poison_diamant_perfect`
     (`1.46x` the second score) and a `post_clear_attrition_boss` watch on
     `ossuaire`.
   - PvE design learning:
     bossrush creates a new axis that PvP win rate cannot measure. A build can
     win normal rounds, survive long fights, or generate a boss score, and those
     are not the same thing. This is useful for endgame retention because it
     gives completed builds another payoff surface without forcing the normal
     PvP loop to become a DPS-meter game. The next product step is not only more
     balance data: it is a juicy score presentation layer, with sequential
     damage events, count-up, pitch-rising audio, shake/juice proportional to
     score bursts, and boss-specific visual reactions. Keep the simulation pure;
     put the Balatro-like feedback in the live presentation layer.
   - Bossrush connected to real run access:
     the catalogue-only bossrush panel is now paired with a run-connected mode,
     `tools/sim.lua bossrush_run`. `Rundriver` exposes `finalSupportedBoard`
     so the postgame fight can use the actual final board plus acquired relics
     and placed commander. This matters because a perfect catalogue composition
     can look powerful while being unreachable under the current economy, and a
     weaker-looking broad policy can become the better postgame line simply
     because it enters bossrush more often.
   - Bossrush-run report shape:
     `tools/sim.lua bossrush_run [N]` runs policy/economy trajectories first,
     then sends eligible final boards into abominations. It reports
     `completion`, `entry_rate`, `score_damage_per_run`,
     `score_damage_per_entry`, `clear_rate`, `full_score_window_rate`,
     `by_economy`, `by_policy`, `by_boss`, an `economy_policy` matrix, ranked
     lines, samples with relics/commander, and recommendations. Env controls:
     `PIT_BOSSRUSH_RUN_ECONOMIES`, `PIT_POLICIES`, `PIT_ABOMINATIONS`,
     `PIT_BOSSRUSH_RUN_ELIGIBILITY=completed|all`,
     `PIT_BOSSRUSH_SCORE_SECONDS`, `PIT_BOSSRUSH_HP_MULT`, and
     `PIT_BOSSRUSH_CD_MULT`.
   - First run-connected read:
     a small N=5 panel in `runs/long-2026-06-27o/bossrush-run-smoke` crossed
     `baseline`, `sap_cost`, and `early_curve` against four abominations and
     nine policies. The strongest score-per-run came from broad plans under
     `early_curve`: `greedy_plan` (`60%` completion/entry,
     `5700.4` score/run, `9500.7` score/entry) and `econ_plan` (`60%`
     completion/entry, `5502.6` score/run). `baseline` broad plans entered
     less often but still scored when they completed. `sap_cost` had zero
     postgame entries in this tiny panel, so its stricter economy currently
     reads as an access wall for bossrush rather than a scoring verdict.
     Interpretation: do not tune PvE score from catalogue comps alone; keep
     completion/entry rate and economy pressure in the same report.
   - Rank-2 post-win scoring smoke:
     after the rank-2 level-up pass, a small connected panel
     `runs/long-2026-06-27s/rank2-levelup-bossrush-run-n6` crossed
     `baseline`, `pair_completion_light`, and `early_curve` across four
     abominations and six policies. The top score-per-run lines were still
     broad `early_curve` plans (`greedy_plan` `50%` entry, `4607.7`
     score/run; `econ_plan` `50%` entry, `4479.2` score/run), mainly because
     they entered bossrush more often. The report raised only the
     `low_postgame_entry_rate` watch (`13.9%` overall entry). Current read:
     PvE score remains access-gated; do not over-tune boss HP or affliction
     counters until economy/policy reachability is measured on larger paired
     panels.
   - Expanded rank-2 bossrush-run read:
     `runs/long-2026-06-27t/bossrush-run-rank2-n18` crossed `baseline`,
     `pair_completion_light`, `pair_completion_delayed`, and `early_curve`
     with nine broad/committed policies against four abominations. Overall
     entry was still low (`12.5%`), while boss clear was `100%`, survival
     `99.4%`, and full scoring-window rate `89.5%`. The top line was
     `pair_completion_light` + `greedy_plan` (`27.8%` entry, `2934.3`
     score/run, `10563.4` score/entry), followed by baseline broad plans.
     By economy, `pair_completion_light` had the best score/run (`983.2`)
     mostly by improving final-board quality, not by massively improving entry;
     baseline entered slightly more often (`14.2%` vs `13.0%`) but scored less
     per entry. Current read: pair-completion support remains promising as a
     final-board quality lever, but the postgame loop is still too access-gated
     to tune boss families from score/ranking alone.
   - Active memory guard:
     bossrush/scoring is a new payoff layer, not the whole balance project. The
     next passes must still keep the older open axes in view: economy pressure,
     shop XP/tier timing, bench/board pressure, exact pair lifecycle, level-up
     power scaling, relic and commander access, pacing/TTK, wording/tag
     coherence, and generated coherent/semi-coherent/incoherent teams.
   - Relic/commander access report update:
     `tools/scenarios/economy.lua` now keeps the full
     `plan_access.support_access` detail but also writes a compact
     `support_summary` for each target and `plan_support_watch` for each
     economy/profile. The summary exposes focused support seen/used rates,
     offer-to-pick gaps, focused relic and commander access, valid win-delta
     comparisons only when both support/no-support groups exist, and top
     focused relics/commanders by actual run access. This closes the previous
     gap where relic support existed in coherence scoring but was too buried in
     the economy report to guide tuning quickly.
   - Support-summary read:
     `runs/long-2026-06-27u/support-summary-cmd-n16` crossed `baseline`,
     `pair_completion_light`, `pair_completion_delayed`, and `early_curve`
     with commandants enabled, five broad/committed policies, and the
     `rot_bleed_rat_core`, `cross_bleed_rot`, and `rot_bleed_mid` targets.
     Pair-completion light was the best tested line (`21.2%` completion,
     `8.85` avg wins, `94.4%` merge resolution), followed by delayed
     pair-completion (`20.0%`, `8.66`, `92.7%`) and baseline (`18.8%`,
     `8.45`, `74.7%`). Early curve stayed lower (`15.0%`, `8.14`, `71.0%`).
     Focused support is now measurable: across the tracked plans, support was
     seen in about `62.5-66.3%` of runs and used in `46.3-51.3%`; relic
     offer-to-pick gaps remain `13.8-17.5%`. Commandant support appeared and
     was placed in `18.8%` of baseline/pair-completion runs, with no placement
     gap; the top focused commanders were `gash_fiend`, `clot_mender`, and
     `razorkin`, while the top focused relics were `grave_cap`,
     `weeping_nail`, and `plague_communion`.
   - Support-summary interpretation:
     exact target completion is still `0%` for these three plan targets even
     when overall run completion improves. `rot_bleed_rat_core` reaches only
     about `0.29-0.30` final level coverage in baseline/pair-completion, and
     `cross_bleed_rot` about `0.19-0.20`. The next issue is therefore not just
     "was support offered"; it is "did the policy convert offered support and
     pair completion into the intended final board". Current minimal next
     levers: target-aware relic picks, commander choice scoring against the
     committed target, and a stricter late-board replacement policy that keeps
     the reroll core while selling temporary support at the right time.
   - Target-prioritized pair support:
     `src/lab/rundriver.lua` now lets a policy reorder pair-completion
     candidates before generic economy support replaces a shop slot. Committed
     plan policies use this to prioritize target units, with higher-rank target
     pairs first so scarce bridge pieces like `clot_mender`, `gash_fiend`, and
     `razorkin` are not starved by abundant rank-1 pairs. In
     `runs/long-2026-06-27u/rat-reroll-target-priority-n24`, the change nudged
     target acquisition upward under `pair_completion_light`:
     `rot_bleed_rat_core` aggregate level coverage moved to about `0.652`,
     final held coverage to about `0.744`, merge resolution to `91.9%`, and
     missed-space pressure down to `1.88` target offers/run. It still did not
     produce stable exact board completion; one line reached held completion
     without board completion. Current read: priority is worth keeping because
     it matches how a player forces a plan, but the next missing feature is
     late-board deployment/replacement, not more raw pair access.
   - Late-board deployment pass:
     `Rundriver` now exposes deterministic bench/board moves for lab policies:
     `moveBenchToBoard` and `moveBoardToBench` mirror the live drag/swap model
     without render, audio, wall-clock state, or random input. Committed target
     policies now run a conservative deploy step after buying/rerolling: target
     units sitting on the bench fill empty board slots first, then may swap over
     non-core level-1 temporary units. The economy report exposes
     `board_deploys_per_run` and `board_swaps_per_run` so future panels can
     distinguish "owned but never placed" from "not actually assembled".
   - Deployment read:
     `runs/long-2026-06-27u/rat-reroll-deploy-n24` repeated the previous
     `rot_bleed_rat_core` comparison across `baseline`,
     `pair_completion_light`, and `pair_completion_delayed`. Relative to
     `rat-reroll-target-priority-n24`, the target deployment rule raised final
     board level coverage for the gated policy from `0.564 -> 0.669` in
     baseline, `0.592 -> 0.711` in delayed pair completion, and
     `0.642 -> 0.744` in light pair completion. The best current line is
     `pair_completion_light + committed_rot_bleed_rat_core_gated_plan`:
     `4.17%` exact board completion, `8.33%` exact held completion,
     `0.744` final board level coverage, `0.783` final held level coverage,
     `2.71` board deploys/run, and `2.38` board swaps/run.
   - Deployment interpretation:
     this confirms a real policy bug was present: supported pieces were often
     owned before they were actually deployed. The remaining gap is now smaller
     and more specific. Some "held complete but board incomplete" cases are not
     just an idle-bench bug; they look like unresolved level/copy pressure or
     board-capacity pressure where extra target levels exist as bench copies but
     cannot become a legal final board without another merge or another slot.
     The next lever should therefore inspect terminal merge causes and slot
     timing before blindly adding more shop support.
   - Connected bossrush smoke after deployment:
     a tiny post-win panel,
     `runs/long-2026-06-27u/rat-reroll-deploy-bossrush-run-completed-n6`,
     crossed `pair_completion_light` with the gated and deep-reroll
     `rot_bleed_rat_core` policies against `kraken`, `brasier`, `ruche`, and
     `ossuaire`. `committed_rot_bleed_rat_core_deep_reroll_plan` reached
     `50%` normal-run completion/entry and scored `4887.0` damage/run
     (`9774.0` per entry, `100%` clear/full-window). The gated policy had
     `0%` post-win entry in this small sample. This keeps the earlier bossrush
     lesson intact: current PvE scoring is still primarily access-gated by run
     completion and final-board quality, not by boss-side tuning.
   - Target-specific merge lifecycle:
     the economy report now writes `target_merge_lifecycle` inside each
     `plan_access.<target>` row. This filters pair/merge lifecycle metrics to
     the actual units of the tracked plan, instead of mixing target copies with
     temporary support pairs. This matters because the global lifecycle can
     show high `offered_policy_skipped` from non-core pairs, while the target
     funnel itself is already buying almost every relevant offer.
   - Target merge read:
     `runs/long-2026-06-27u/rat-reroll-target-merge-n24` reproduces the
     deployment panel with the new filtered lifecycle. On the best current
     `pair_completion_light + committed_rot_bleed_rat_core_gated_plan` line,
     target pairs resolve at `94.79%`; only `10` target pairs remain
     unresolved across 24 runs. Of those unresolved target pairs, `70%` never
     saw the third copy again after the pair existed and `30%` were offered but
     skipped by policy. This confirms the remaining blocker is mostly
     third-copy availability/timing for target copies, with a smaller
     target-priority edge case, not generic support access.
   - Pair-support density profiles:
     `src/run/economy.lua` now has opt-in lab profiles
     `pair_completion_dense` and `pair_completion_dense_delayed`, both allowing
     up to two pair-completion shop replacements per round. They are not in
     `Economy.order`, so they do not change the default scenario grid or live
     economy; they exist to isolate "third-copy odds/timing" from normal
     economy pressure.
   - Bench-size vs pair-density read:
     `runs/long-2026-06-27u/rat-reroll-bench-density-n16` crossed
     `pair_completion_light`/`pair_completion_dense` with bench sizes 4 and 6
     for the `rot_bleed_rat_core` gated/deep-reroll policies. Bench size 6 is
     the stronger lever in this small panel: completion moved from `31.2%` to
     `46.9%` at the profile aggregate level, and `deep_reroll` went
     `56.25% -> 75%` completion. Dense pair support improved target-pair
     resolution (`deep_reroll` bench6 `94.47% -> 97.97%`; aggregate merge
     `90.1% -> 95.1%`) but did not improve completion beyond the bench6 result.
     The gated policy still only reached `6.25%` exact board completion and
     `18.75%` run completion under bench6. Current read: extra reserve space is
     probably a real run-access lever; denser pair pity is useful for diagnosis
     but not obviously a live tuning knob yet.
   Remaining additions:
   - use `rot_bleed_rat_core` as the baseline reroll target for the next
     balance pass, but investigate cheap mid-board outliers before nerfing it;
   - revisit protected payload placement and the remaining cheap mid-board
     outliers now that XP/reroll timing has a measurable coverage gate;
   - use terminal-cause reporting to decide whether reroll help should come
     from shop odds, targeted offers, freeze/lock, or bench policy rather than
     assuming all unresolved pairs are a bench-space issue;
   - keep expanding bossrush-run from a small smoke panel to longer paired
     economy/policy sweeps, but only as one axis among economy, combat, and
     accessibility;
   - run events reward layer:
     the first experimental model now lives in `src/data/run_events.lua` and is
     documented in `docs/research/run-events-reward-loop.md`. It keeps the
     win-3/win-6 relic milestones intact. By default the lab also keeps the
     every-3-combats merchant as a relic offer for comparability; with
     `runEvents=true` or scenario env `PIT_RUN_EVENTS=1`, that same merchant
     window becomes a deterministic thematic event. Active reward kinds are
     relic, unit, gold, shop XP, and shop tier. Units can be level 1 or rare
     level 2, never level 3. Monster mutations are intentionally not active yet
     because they need a first-class instance model before they can be safe for
     merges, snapshots, combat, and UI.
3. Use the new `plan_support_watch` rows in the next economy/bossrush panels to
   separate "support never offered", "support offered but not picked", and
   "support picked but plan still inaccessible".
4. Expand authored level-ups beyond the initial 37 units before drawing broad
   balance conclusions.
5. Start massive simulation only after the generator can intentionally produce
   coherent, semi-coherent, and incoherent teams.
