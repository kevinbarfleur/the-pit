# Batodex Inspiration Data

Retrieved on 2026-06-28 from:

- https://batodex.com/
- https://batodex.com/trinkets
- https://batodex.com/items

This folder stores normalized mechanical reference data so future design passes do not need to scrape Batodex again.

## Files

- `monsters.json` - all 80 Batomon entries, including Mythical.
- `monsters-non-mythical.json` - the current design reference set; use this by default.
- `trinkets.json` - 58 trinket entries.
- `items.json` - 32 item entries.
- `design-taxonomy.json` - compact counts and examples for quick agent context.

## Usage Rule

Do not load the full JSON files by default. Start with `design-taxonomy.json` and only open the full dataset when working directly on creature, trinket, item, level-up, economy, or event inspiration.

Current design weighting for The Pit:

1. Batodex and SAP are the primary references: compact effects, readable triggers, position/support hooks, clear level scaling.
2. Mythical Batomon are preserved but ignored for near-term balance because they are intentionally extreme.
3. The Bazaar is allowed as a secondary spice source for occasional rare or high-tier effects, not as the baseline complexity model.
4. Copy patterns, not exact content or names.
