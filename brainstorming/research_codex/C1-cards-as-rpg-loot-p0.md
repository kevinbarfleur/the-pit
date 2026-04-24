# C1. Cards as RPG Loot - P0

## Sources
- Slay the Spire Wiki, Card Rewards: https://slay-the-spire.fandom.com/wiki/Card_Rewards
- Slay the Spire Wiki, Cards and rarity: https://slay-the-spire.fandom.com/wiki/Cards
- Darkest Dungeon Wiki, Trinkets: https://darkestdungeon.fandom.com/wiki/Trinkets_%28Darkest_Dungeon%29
- Marvel Snap Help Center, card upgrading: https://marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/34-what-does-upgrading-a-card-do/
- Path of Exile Wiki, Rarity: https://www.poewiki.net/wiki/Rarity

## Findings
- Cards replacing gear is strongest if cards behave like RPG loot, not like a deckbuilder pile. The 8-slot limit is the main design advantage: it creates loadout tension and prevents unlimited accumulation from becoming automatic power.
- Slay the Spire shows that encounter type can shape card reward rarity. For The Pit, trash, elite, boss, and event tables should feel different. If every enemy can drop every card, farming has no identity.
- Darkest Dungeon trinkets are a good model for mixed upside/downside items. A high-rarity card should not always be a strict stat upgrade. It can offer a conditional trigger, archetype payoff, or drawback that creates build definition.
- Marvel Snap separates card collection from card visual upgrading, but the relevant lesson is that duplicates and upgrade currencies can feed progression without changing base card identity too much. For The Pit, duplicate cards should not create deck clutter; they should become shards/XP.
- Existing T3..T0 tiers can map cleanly to loot role:
  - T3: common, reliable, broad-use.
  - T2: uncommon, stat-plus-trigger, archetype hint.
  - T1: rare, build enabler, conditional payoff.
  - T0: unique/legendary, boss or deep-table identity card.

## Recommendation for The Pit
- Use this initial card definition schema:
  - `id`
  - `name`
  - `tier`: T3, T2, T1, T0
  - `tags`: bleed, block, burn, gold, thorns, summon, crit, sustain, etc.
  - `slotRole`: attack, defense, economy, utility, finisher, engine
  - `trigger`: onHit, onKill, onBlock, onNodeStart, onLowHp, passive
  - `scalingStat`: power, depth, gold, missingHp, enemyCount, torchSpent
  - `dropSources`
  - `baseWeight`
  - `maxCopiesEquipped`
  - `dupeShardValue`
  - `upgradeTrackId`
- Drop source mapping:
  - Common trash: T3 and a small T2 chance.
  - Named trash family: T3/T2 cards matching enemy identity.
  - Elite: T2 baseline, meaningful T1 chance.
  - Boss: deterministic first-clear card or T0 unlock, then boss table.
  - Event: off-archetype, cursed, or utility cards.
- Keep T3 usable by giving common cards clean mechanical niches: flat block, first-hit damage, poison starter, gold finder, torch saver, heal drip. Do not let rare cards be only larger numbers.
- Rework any existing card that is strictly `+X% damage` without a condition. It should gain a trigger, tag, drawback, or synergy hook.
- Add duplicate handling in save schema now even if C2 is not final: `ownedCards`, `cardShards`, `cardLevels`, and `firstDropAtDepth`.
