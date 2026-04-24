# A1. Progression Math - P0

## Sources
- Cookie Clicker Wiki, Building: https://cookieclicker.fandom.com/wiki/Building
- OGame Wiki, Formulas: https://ogame.fandom.com/wiki/Formulas
- Melvor Idle Wiki, Skills and progression context: https://wiki.melvoridle.com/w/Skills
- Machinations, How to design idle games: https://machinations.io/articles/idle-games-and-how-to-design-them

## Findings
- Treat the prompt's `cost(n) = base * ratio^n` as the correct base model, but correct the Cookie Clicker reference: the commonly documented building cost multiplier is 1.15 per owned building, not 1.07. A 1.07 ratio can still be useful for very fast early upgrades or low-impact repeatables, but it is too gentle for the primary economy unless production scaling is also shallow.
- OGame uses aggressive exponential costs for mines and infrastructure, while production also scales with level. This matters because the relevant player-facing metric is not cost alone; it is payback time and time-to-next-upgrade. The useful design question is: `nextCost / currentIncomeRate`, not just the ratio.
- Soft walls should stretch decision cadence without creating dead time. A soft wall is acceptable when the player can choose among several productive actions while waiting: switch node type, target a drop, change card loadout, spend torch on a risky branch, or buy a cheaper side upgrade. A hard wall occurs when the best play is simply to close the game until a number is large enough.
- Resource sinks should be sized around bank pressure. Early sinks can cost 40-70% of current savings, because the next decision arrives quickly. Midgame gates can cost 80-95% of current savings if the player has alternative goals. Late gates can exceed visible income only when the player has build/route decisions that substantially change the income rate.
- For a hybrid idle roguelite, the economy curve should be flatter than pure Cookie Clicker and much flatter than NGU-style multiplicative bloat. The player should feel that depth, route quality, and card build matter more than waiting.

## Recommendation for The Pit
- Use three ratios, not one:
  - `1.07-1.10` for tutorial and quality-of-life repeatables.
  - `1.13-1.17` for core base upgrades.
  - `1.22-1.30` only for prestige-like, late, or nonessential sinks.
- Target active time-to-next-upgrade:
  - Tutorial: 10-30 seconds.
  - Early: 30-90 seconds.
  - Early-mid: 2-5 minutes.
  - Mid: 8-20 minutes, but with multiple parallel goals.
  - Late MVP: 30-60 minutes for major gates, never as the only meaningful objective.
- Define each upgrade row with these fields: `id`, `baseCost`, `costRatio`, `maxLevel`, `effectFormula`, `expectedPaybackSeconds`, `unlockDepth`, `sinkType`.
- Balance first against a spreadsheet target of `nextCost / activeIncomePerSecond`. Do not balance from raw cost numbers.
- Use base upgrades to smooth variance from loot. Use card drops to spike power. That separation keeps the idle economy predictable while preserving Delve dopamine.
