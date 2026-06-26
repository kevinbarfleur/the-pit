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
   Remaining additions:
   - turn the tank diagnosis into sim-only candidate variants: rank-1 tank seed,
     stronger shield/taunt payoff, and/or tank rush policy that buys survivable
     filler until tier 2;
   - add a "pair completion over time" metric: pair formed -> merge completed
     rate, not only raw pair/merge purchase counts;
   - model relic access and relic tags in coherence/economy reports;
   - make committed policies smarter about XP/reroll timing after the tank
     candidate tests.
3. Integrate relic tags and relic access into coherence scoring.
4. Expand authored level-ups beyond the initial 6 units before drawing broad
   balance conclusions.
5. Start massive simulation only after the generator can intentionally produce
   coherent, semi-coherent, and incoherent teams.
