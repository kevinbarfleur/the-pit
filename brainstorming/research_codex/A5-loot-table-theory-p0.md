# A5. Loot Table Theory - P0

## Sources
- Slay the Spire Wiki, Card Rewards: https://slay-the-spire.fandom.com/wiki/Card_Rewards
- Genshin Impact pity explanation: https://game8.co/games/Genshin-Impact/archives/305937
- Diablo Wiki, Smart Loot: https://www.diablowiki.net/Smart_loot
- Path of Exile Wiki, Rarity and magic find: https://www.poewiki.net/wiki/Rarity
- Hades Wiki, Chamber Reward: https://hades.fandom.com/wiki/Chamber_Reward

## Findings
- Rarity must manage both excitement and trust. Players accept rare drops being rare if the game gives visible short-term rewards, some targeted farming paths, and protection from extreme dry streaks.
- Slay the Spire is a useful card-loot reference because reward rarity depends on encounter type, and rare card appearance is adjusted by recent history. That is closer to The Pit than a pure ARPG table because the reward is a build object, not just a stat stick.
- Gacha-style hard pity is effective but can feel transactional if exposed too bluntly. For The Pit, pity should be diegetic or hidden behind phrasing such as `the pit grows restless` rather than a visible `7/8 rare pity` meter, unless the game leans into mechanical transparency.
- Diablo-style smart loot is valuable because an 8-slot card inventory makes irrelevant drops especially painful. Smart loot should bias toward the player's current archetype but must preserve discovery. A 100% smart table creates solved builds; a 50-70% bias keeps surprises alive.
- Magic find should not multiply top-tier chances without caps. It should add extra rolls, increase lower-tier quantity, or slightly shift weights with diminishing returns. Otherwise, the optimal economy becomes stacking magic find instead of making risky delve choices.

## Recommendation for The Pit
- Initial schema:
  - `lootTableId`
  - `sourceType`: trash, elite, boss, event, chest, shop
  - `depthMin`, `depthMax`
  - `cardId` or `tagPool`
  - `tier`: T3, T2, T1, T0
  - `baseWeight`
  - `smartTags`
  - `pityGroup`
  - `firstCopyProtected`
  - `dupePolicy`
- Initial rarity weights by source:
  - Trash: T3 78%, T2 21%, T1 1%, T0 0%.
  - Elite: T3 45%, T2 42%, T1 12%, T0 1% if eligible.
  - Boss: T2 45%, T1 45%, T0 10% or deterministic first-clear unique.
  - Event: custom table, not global table.
- Pity mechanics:
  - Track pity separately for `eliteRare`, `bossUnique`, and `archetypeKeyCard`.
  - After 6 elite rewards without T1+, increase T1 weight sharply; after 8, guarantee T1 or better.
  - Boss first clear should guarantee a named card or unlock, then move to weighted repeats.
- Smart loot:
  - 60% current build tags.
  - 30% adjacent synergy tags.
  - 10% wild/off-archetype.
- Magic find:
  - Use diminishing formula: `effectiveMF = mf / (100 + mf)`.
  - Let it add extra common/uncommon shards and modestly improve T1 odds. Do not let it create uncapped T0 farming.
