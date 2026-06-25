# Batodex — données complètes de *Batomon Showdown*

> Scrap intégral de https://batodex.com (Next.js RSC, dé-référencé à 100 %). **Référence d'addictivité du projet** (cf. CLAUDE.md §2). Données brutes : `monsters.json` (80), `trinkets.json` (58), `items.json` (32).

> Source de vérité = le site. Ce digest est une vue lisible pour le design.


## Vue d'ensemble

| Catégorie | Nombre | Champs clés |
|---|---|---|
| Monstres | 80 | tier, cost, types[], keywords[], levels[1-4], shinyLevels, ability, evolution, rarity |
| Trinkets (≈ reliques) | 58 | tier, description, rarity |
| Items (consommables) | 32 | tier, cost, description, rarity |

### Tier ↔ rareté (mapping 1:1)

| Tier | Rareté | Monstres | Trinkets | Items |
|---|---|---|---|---|
| 1 | Common | 16 | 10 | 7 |
| 2 | Uncommon | 14 | 8 | 8 |
| 3 | Rare | 16 | 13 | 8 |
| 4 | Super Rare | 17 | 10 | 6 |
| 5 | Legendary | 11 | 10 | 3 |
| 6 | Mythical | 6 | 7 | 0 |

### Économie (coût d'achat par tier)

| Tier | Coûts monstres | Coûts items |
|---|---|---|
| 1 | [10, 15] | [0, 5] |
| 2 | [20, 25, 30] | [0, 1, 2, 20] |
| 3 | [25, 30, 35, 40] | [0, 5] |
| 4 | [0, 30, 35, 40, 45, 60] | [0, 5, 10, 30, 40] |
| 5 | [50, 55, 60, 100] | [0, 40, 50] |
| 6 | [80] | [] |

## Vocabulaire mécanique (stats de combat)

Chaque monstre a, **par niveau (1→4)**, un `cooldown`, un `multicast` optionnel, et des stats. Seulement **6 stats** dans tout le jeu :

| Stat | Occurrences | Plage de valeurs (L1→L4 tous monstres) |
|---|---|---|
| **damage** | 180 | 1 → 4500 |
| **burn** | 48 | 1 → 450 |
| **poison** | 44 | 1 → 900 |
| **heal** | 40 | 5 → 2400 |
| **shield** | 36 | 20 → 4800 |
| **shock** | 32 | 1 → 300 |

- **Cooldowns** observés (secondes) : [1, 1.3, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 8, 9, 10, 11, 14, 15]
- **Types** (14) : Fire(12), Bug(11), Toxic(11), Water(10), Rock(9), Grass(9), Dragon(9), Electric(8), Ghost(8), Flying(7), Steel(2), Fighting(1), Curio(1), All(1)
- **Keywords** (3) : Knockout(8), Charge(4), Protect(1)

## Roster monstres (80)

| Monstre | T | Coût | Types | Rareté | CD (L1) | Capacité (L1) |
|---|---|---|---|---|---|---|
| Bumblebolt | 1 | 10 | Bug/Electric | Common | 2.5 |  |
| Dribblet | 1 | 10 | Water | Common | 3.5 | — |
| Guardiant | 1 | 15 | Bug | Common | 3.5 | After you buy a Bug monster, this gains +7 Damage |
| Joltail | 1 | 15 | Electric | Common | 4.5 |  |
| Magmite | 1 | 15 | Fire/Rock | Common | 4.5 |  |
| Mosslug | 1 | 10 | Water/Grass | Common | 5 | *(On Cast)* +20 Damage for this battle |
| Panbud | 1 | 10 | Grass | Common | 5.5 | — |
| Pebbler | 1 | 15 | Rock | Common | 5 | *(On Cast)* +15 Shield for this battle |
| Pipskull | 1 | 15 | Ghost | Common | 4 | Evolve after experiencing Knockout 2 times |
| Ratacomb | 1 | 15 | Ghost | Common | 4 | *(On Knocked Out)* +30 Damage permanently |
| Rattleghast | 1 | 15 | Ghost/Toxic | Common | 6 | *(On Battle Start)* Knockout adjacent allies and gain +4 Poison this battle for each ally Knockout |
| Scorchimp | 1 | 10 | Fire | Common | 5.5 | — |
| Spinarai | 1 | 10 | Bug/Toxic | Common | 2.5 |  |
| Stingarde | 1 | 10 | Bug | Common | 5 | *(On Cast)* Knockout self |
| Velocect | 1 | 15 | Bug/Flying | Common | 3.5 |  |
| Venopuff | 1 | 15 | Toxic | Common | 3.5 |  |
| Berroon | 2 | 20 | Grass | Uncommon | 4 | You can use 1 additional Item per day. |
| Boomagon | 2 | 30 | Dragon | Uncommon | 6 | *(On Cast)* Give the ally to the left +4% Cooldown Speed permanently |
| Brawlmantis | 2 | 30 | Bug/Fighting | Uncommon | 5.5 | *(On Victory)* This and Common allies gain +10 Damage permanently |
| Cinderfly | 2 | 30 | Bug/Fire | Uncommon | 5 | After you buy a Bug monster, this gains +10% Cooldown Speed |
| Craghorn | 2 | 25 | Grass/Rock | Uncommon | 6 | When you use an item, this gains +20 Damage and Shield |
| Electranade | 2 | 25 | Electric | Uncommon | 4.5 | *(On Cast)* Knockout self |
| Frizzly | 2 | 25 | Electric | Uncommon | 7 | *(On Battle Start)* Trigger this |
| Gildshell | 2 | 20 | Bug | Uncommon | 2 | *(On Battle Start)* +20 Sell Value permanently |
| Noxnimbus | 2 | 25 | Toxic | Uncommon | 4 | *(On Cast)* Adjacent Toxic allies gain +2 Poison for this battle |
| Plunderbird | 2 | 30 | Water/Flying | Uncommon | 5 | *(On Cast)* Gain $1 |
| Puffloon | 2 | 30 | Water/Toxic | Uncommon | 10 | Trigger this when adjacent Toxic allies trigger (Except other Puffloon) |
| Pyronade | 2 | 25 | Fire | Uncommon | 4.5 | *(On Cast)* Knockout self |
| Shogapede | 2 | 30 | Bug/Toxic | Uncommon | 5 | After you buy a Bug monster, this gains +10% Cooldown Speed |
| Tortress | 2 | 20 | Rock | Uncommon | 14 | *(On Battle Start)* Trigger this |
| Aristobat | 3 | 25 | Toxic/Flying | Rare | 4 |  |
| Aster | 3 | 40 | Water | Rare | 3 | *(On Battle Start)* Adjacent Water allies gain +20 Heal permanently |
| Cherubble | 3 | 25 | Rock | Rare | 4 | *(On Cast)* Give adjacent allies Protect 1 |
| Cicadence | 3 | 25 | Bug | Rare | 6 | *(On Cast)* Trigger the Bug ally above |
| Dirgefin | 3 | 25 | Ghost/Water | Rare | 9 | *(On Cast)* Knockout all Common allies and enemies |
| Dracana | 3 | 30 | Dragon | Rare | 3 | *(On Cast)* Charge ally to the left by 1 second(s) (Dracana cannot receive charge) |
| Formiqueen | 3 | 25 | Bug | Rare | 4 | *(Ongoing)* Adjacent Common allies have +33% Cooldown Speed |
| Humbolt | 3 | 25 | Electric/Flying | Rare | 4 |  |
| Ignit | 3 | 40 | Fire | Rare | 8 | *(On Victory)* Evolve |
| Ironcore | 3 | 40 | Steel | Rare | 2 | *(On Cast)* Charge adjacent Electric allies by 1 second(s) (Ironcore cannot receive charge) |
| Lignite | 3 | 30 | Fire | Rare | 4 | *(Ongoing)* Has additional Damage equal to 15 times this monster's Burn |
| Magmalith | 3 | 30 | Fire | Rare | 8 | *(On Cast)* Give the ally above +2 Burn permanently |
| Noxalith | 3 | 30 | Toxic | Rare | 8 | *(On Cast)* Give the ally above +2 Poison permanently |
| Stalagrove | 3 | 35 | Grass/Rock | Rare | 5.5 | When you receive shield, this gains Damage for this battle equal to 10% of the amount shielded. |
| Thorntail | 3 | 35 | Grass/Toxic | Rare | 6.5 | When allies inflict Poison, this gains +4 Damage permanently |
| Voltalith | 3 | 30 | Electric | Rare | 8 | *(On Cast)* Give the ally above +2 Shock permanently |
| Aegistruct | 4 | 45 | Rock | Super Rare | 8 | *(On Battle Start)* Gain Shield equal to 1x the Shield of adjacent allies for this battle (Except other Aegistruct) |
| Blazewing | 4 | 35 | Fire/Flying | Super Rare | 5 |  |
| Celestia | 4 | 30 | Dragon | Super Rare | 6.5 | *(On Battle Start)* Disable abilities of all Ongoing monsters in this row |
| Clawnetic | 4 | 45 | Steel | Super Rare | 3 | Whenever an ally inflicts Shock, Charge this by 1 |
| Coalem | 4 | 45 | Fire/Rock | Super Rare | 15 | *(On Battle Start)* Trigger this |
| Dragon Egg | 4 | 0 |  | Super Rare | 10 | Hatches a Legendary Dragon monster in 3 days |
| Dryadell | 4 | 45 | Grass | Super Rare | 6 | *(On Cast)* Trigger the Grass ally above |
| Flarilisk | 4 | 60 | Fire | Super Rare | 8 | *(On Victory)* Evolve |
| Fumungus | 4 | 40 | Grass/Toxic | Super Rare | 3 | *(Ongoing)* Has additional Damage equal to 1x  the Poison on the enemy |
| Prismagon | 4 | 45 | Dragon | Super Rare | 4.5 | *(On Cast)* +5 Damage permanently for each unique type on your team |
| Purple Egg | 4 | 0 |  | Super Rare | 10 | Hatches {monster_name} in {amount} day(s) |
| Pylong | 4 | 40 | Electric | Super Rare | 7 | *(Ongoing)* Ally to the left has +100% Shock |
| Reapra | 4 | 35 | Ghost | Super Rare | 6 | *(On Cast)* Knockout the enemy opposite of this |
| Shelldra | 4 | 40 | Water/Dragon | Super Rare | 4.5 | Every 4 seconds, +1 Multicast for this battle |
| Sirenade | 4 | 40 | Water | Super Rare | 4 | *(On Cast)* Remove 20% of debuffs on your team |
| Wishwash | 4 | 0 | Water | Super Rare | 3.5 | *(On Battle Start)* Gain a random Uncommon trinket permanently |
| Zephyrex | 4 | 60 | Flying | Super Rare | 11 | *(On Cast)* Give the Flying ally to the right +1 Multicast permanently (This monster cannot gain Multicast) |
| Basilord | 5 | 100 | Fire | Legendary | 8 |  |
| Blixie | 5 | 55 | Fire | Legendary | 6 | *(On Cast)* Give the Fire ally to the left {multiplier}this monster's Burn for this battle |
| Cobrex | 5 | 50 | Toxic | Legendary | 15 | Whenever an ally inflicts Poison, Charge this by 1 |
| Draconarch | 5 | 60 | Dragon | Legendary | 5 | *(On Cast)* Activate the On Battle Start abilities of adjacent allies and increase this monster's Cooldown by 6 for this battle |
| Gaiadrasil | 5 | 60 | Grass | Legendary | 9 | *(Ongoing)* Has additional Damage equal to 100% of the total Damage of adjacent allies (Except other Gaiadrasil) |
| Galvanine | 5 | 50 | Electric | Legendary | 8 | *(On Cast)* +50% Cooldown Speed and +2 Shock for this battle |
| Geminiss | 5 | 50 | Rock | Legendary | 10 | *(On Cast)* Give adjacent allies +70% Shield for this battle |
| Onsetra | 5 | 50 | Dragon | Legendary | 4 | Ally to the left apply their Ongoing abilities 1 additional time(s) |
| Saberhorn | 5 | 60 | Dragon | Legendary | 8 | *(On Cast)* Give the ally to the right +1 Multicast and increase this monster's Cooldown by 8 seconds for this battle |
| Stellagon | 5 | 50 | Dragon | Legendary | 6 | *(Ongoing)* Adjacent allies with no abilities have +2 Multicast |
| Torrantler | 5 | 50 | Water | Legendary | 10 | *(On Cast)* Trigger adjacent Water allies (Except other Torrantler) |
| Aerophim | 6 | 80 | Flying | Mythical | 6 | *(On Cast)* Give adjacent allies +1 Multicast permanently and transform them into random monsters of their rarity |
| Cosmivore | 6 | 80 | Ghost | Mythical | 7 | When rerolling the shop, gain 20% of the total stats of the monsters remaining in the shop (excluding Multicast and Cooldown) |
| Goldora | 6 | 80 | Curio | Mythical | 6 | On the first cast, gain 1 random Legendary trinket(s) for each Legendary ally |
| Omnichrome | 6 | 80 | All | Mythical | 5 | *(On Battle Start)* Gain 80% of the stats of the enemy monster with the highest stats permanently (excluding Multicast and Cooldown) |
| Rigalord | 6 | 80 | Ghost | Mythical | 2 | *(On Battle Start)* Spawn exact copies of the Batomon this devoured in empty slots the bottom row. They ONLY trigger when this casts |
| Riglet | 6 | 80 | Ghost | Mythical | 2 | At the start of the next day, devour the ally to the right and evolve into Rigalord |

## Capacités par déclencheur (le vrai design des effets)


### On Cast (28)

- **Mosslug** — +20 Damage for this battle
- **Pebbler** — +15 Shield for this battle
- **Stingarde** — Knockout self
- **Boomagon** — Give the ally to the left +4% Cooldown Speed permanently
- **Electranade** — Knockout self
- **Noxnimbus** — Adjacent Toxic allies gain +2 Poison for this battle
- **Plunderbird** — Gain $1
- **Pyronade** — Knockout self
- **Cherubble** — Give adjacent allies Protect 1
- **Cicadence** — Trigger the Bug ally above
- **Dirgefin** — Knockout all Common allies and enemies
- **Dracana** — Charge ally to the left by 1 second(s) (Dracana cannot receive charge)
- **Ironcore** — Charge adjacent Electric allies by 1 second(s) (Ironcore cannot receive charge)
- **Magmalith** — Give the ally above +2 Burn permanently
- **Noxalith** — Give the ally above +2 Poison permanently
- **Voltalith** — Give the ally above +2 Shock permanently
- **Dryadell** — Trigger the Grass ally above
- **Prismagon** — +5 Damage permanently for each unique type on your team
- **Reapra** — Knockout the enemy opposite of this
- **Sirenade** — Remove 20% of debuffs on your team
- **Zephyrex** — Give the Flying ally to the right +1 Multicast permanently (This monster cannot gain Multicast)
- **Blixie** — Give the Fire ally to the left {multiplier}this monster's Burn for this battle
- **Draconarch** — Activate the On Battle Start abilities of adjacent allies and increase this monster's Cooldown by 6 for this battle
- **Galvanine** — +50% Cooldown Speed and +2 Shock for this battle
- **Geminiss** — Give adjacent allies +70% Shield for this battle
- **Saberhorn** — Give the ally to the right +1 Multicast and increase this monster's Cooldown by 8 seconds for this battle
- **Torrantler** — Trigger adjacent Water allies (Except other Torrantler)
- **Aerophim** — Give adjacent allies +1 Multicast permanently and transform them into random monsters of their rarity

### On Battle Start (11)

- **Rattleghast** — Knockout adjacent allies and gain +4 Poison this battle for each ally Knockout
- **Frizzly** — Trigger this
- **Gildshell** — +20 Sell Value permanently
- **Tortress** — Trigger this
- **Aster** — Adjacent Water allies gain +20 Heal permanently
- **Aegistruct** — Gain Shield equal to 1x the Shield of adjacent allies for this battle (Except other Aegistruct)
- **Celestia** — Disable abilities of all Ongoing monsters in this row
- **Coalem** — Trigger this
- **Wishwash** — Gain a random Uncommon trinket permanently
- **Omnichrome** — Gain 80% of the stats of the enemy monster with the highest stats permanently (excluding Multicast and Cooldown)
- **Rigalord** — Spawn exact copies of the Batomon this devoured in empty slots the bottom row. They ONLY trigger when this casts

### Ongoing (6)

- **Formiqueen** — Adjacent Common allies have +33% Cooldown Speed
- **Lignite** — Has additional Damage equal to 15 times this monster's Burn
- **Fumungus** — Has additional Damage equal to 1x  the Poison on the enemy
- **Pylong** — Ally to the left has +100% Shock
- **Gaiadrasil** — Has additional Damage equal to 100% of the total Damage of adjacent allies (Except other Gaiadrasil)
- **Stellagon** — Adjacent allies with no abilities have +2 Multicast

### On Victory (3)

- **Brawlmantis** — This and Common allies gain +10 Damage permanently
- **Ignit** — Evolve
- **Flarilisk** — Evolve

### On Knocked Out (1)

- **Ratacomb** — +30 Damage permanently

### Passif (no trigger) (18)

- **Guardiant** — After you buy a Bug monster, this gains +7 Damage
- **Pipskull** — Evolve after experiencing Knockout 2 times
- **Berroon** — You can use 1 additional Item per day.
- **Cinderfly** — After you buy a Bug monster, this gains +10% Cooldown Speed
- **Craghorn** — When you use an item, this gains +20 Damage and Shield
- **Puffloon** — Trigger this when adjacent Toxic allies trigger (Except other Puffloon)
- **Shogapede** — After you buy a Bug monster, this gains +10% Cooldown Speed
- **Stalagrove** — When you receive shield, this gains Damage for this battle equal to 10% of the amount shielded.
- **Thorntail** — When allies inflict Poison, this gains +4 Damage permanently
- **Clawnetic** — Whenever an ally inflicts Shock, Charge this by 1
- **Dragon Egg** — Hatches a Legendary Dragon monster in 3 days
- **Purple Egg** — Hatches {monster_name} in {amount} day(s)
- **Shelldra** — Every 4 seconds, +1 Multicast for this battle
- **Cobrex** — Whenever an ally inflicts Poison, Charge this by 1
- **Onsetra** — Ally to the left apply their Ongoing abilities 1 additional time(s)
- **Cosmivore** — When rerolling the shop, gain 20% of the total stats of the monsters remaining in the shop (excluding Multicast and Cooldown)
- **Goldora** — On the first cast, gain 1 random Legendary trinket(s) for each Legendary ally
- **Riglet** — At the start of the next day, devour the ally to the right and evolve into Rigalord

## Évolutions

- **Dribblet** → `emperooze` (déclencheur **level**, niveau 3)
- **Panbud** → `bambudo` (déclencheur **level**, niveau 3)
- **Scorchimp** → `sunsage` (déclencheur **level**, niveau 3)
- **Ignit** → `flarilisk` (déclencheur **victory**)
- **Flarilisk** → `basilord` (déclencheur **victory**)

## Trinkets — 58 (≈ nos reliques)

| Trinket | T | Rareté | Effet |
|---|---|---|---|
| Gold Nugget | 1 | Common | At the start of each day, gain $3 |
| Gold Trophy | 1 | Common | On Victory / Gain $8 |
| Mini Duplicator | 1 | Common | Gain an additional copy of the next trinket you get |
| Power Pouch | 1 | Common | When you buy an item, give your monsters +2 Damage |
| Quick Bell | 1 | Common | Monsters in your shop gain +5% Cooldown Speed |
| Rainbow Berry | 1 | Common | Your monsters have +4 Damage for each unique type on your team |
| Shady Contract | 1 | Common | Lower the shop rank 1. At the start of each day, gain $5 |
| Training Weights | 1 | Common | +100 HP |
| Treasure Map | 1 | Common | Your next Trinket gift choices are 1 rarity tier higher |
| Wood Sword | 1 | Common | Your monsters have +5 Damage |
| Bug Net | 2 | Uncommon | Bug monsters in the shop cost 3 less |
| Fire Orb | 2 | Uncommon | Your Fire monsters have +3 Burn |
| Market License | 2 | Uncommon | Increase shop rank by 1 |
| Membership Card | 2 | Uncommon | When you buy an item, +1 free rerolls |
| Piggy Bank | 2 | Uncommon | Gain +$1 for each $10 you have at the end of each round |
| Poison Orb | 2 | Uncommon | Your Toxic monsters have +3 Poison |
| Power Band | 2 | Uncommon | Give the first monster you buy each day +20 Damage |
| Power Crown | 2 | Uncommon | Your top middle monster has +20 Damage |
| Ancient Plume | 3 | Rare | On Battle Start / If you only have 1 monster, give it +1 Multicast permanently and destroy this |
| Gold Bar | 3 | Rare | At the start of each day, gain $10 |
| Hero's Sword | 3 | Rare | Your monsters have +12 Damage |
| Link Cable | 3 | Rare | Your monsters' abilities that affect adjacent allies now affect all allies |
| Mega Duplicator | 3 | Rare | Gain 2 additional copies of the next trinket you get |
| Meteorite | 3 | Rare | On Battle Start / Your monsters with no abilities gain +20 Damage permanently |
| Power Bell | 3 | Rare | Monsters in your shop have +25 Damage |
| Sapphire Amulet | 3 | Rare | You receive 25% more Heal |
| Silver Watch | 3 | Rare | When a monster levels up, it gains +15% Cooldown Speed |
| Speed Crest | 3 | Rare | Your monsters in the rightmost column have +20% Cooldown Speed |
| Terrarium | 3 | Rare | Your Bug monsters have 20% Damage |
| Topaz Amulet | 3 | Rare | You receive 25% more Shield |
| Warhorn | 3 | Rare | On Battle Start / Your monsters gain +10 Damage permanently |
| Blitz Bell | 4 | Super Rare | Monsters in your shop gain +30% Cooldown Speed |
| Echo Bell | 4 | Super Rare | When you buy items that cost 1 or less, use it an additional time. |
| Haste Crown | 4 | Super Rare | Your top middle monster has +30% Cooldown Speed |
| Haste Orb | 4 | Super Rare | Your monsters have +15% Cooldown Speed |
| Mysterious Charm | 4 | Super Rare | +25% HP |
| Mysterious Mask | 4 | Super Rare | Choose a trainer and gain their ability |
| Razor Beak | 4 | Super Rare | Your Flying monsters have +1 Multicast |
| Repeater Charm | 4 | Super Rare | Your monsters' On Battle Start abilities activate an additional time |
| Upgrade Disc | 4 | Super Rare | When you buy a monster, level it up and destroy this |
| VIP Pass | 4 | Super Rare | Your shop no longer stocks anything Common or Uncommon |
| Barbell | 5 | Legendary | +5000 HP |
| Dryad's Charm | 5 | Legendary | +30% HP |
| Fancy Sword | 5 | Legendary | Your monsters have +10 Damage for each trinket you have |
| Gold-o-matic | 5 | Legendary | At the start of each day, gain $30 |
| Metronome | 5 | Legendary | When your monster cast, they gain +10 Damage for this battle |
| Mighty Bell | 5 | Legendary | Monsters in your shop have +200 Damage |
| Mysterious Gem | 5 | Legendary | Your monsters have +20% Damage |
| Research Notes | 5 | Legendary | Legendary monsters are much more likely to appear in your shop |
| Winged Crown | 5 | Legendary | Your top middle monster has +1 Multicast |
| Zenith Stone | 5 | Legendary | When your monsters gain stats, they gain +80% more (except Multicast) |
| Excalibur | 6 | Mythical | Your monsters have +350 Damage |
| Holy Grail | 6 | Mythical | On Victory / Gain $100 |
| Master Crown | 6 | Mythical | Your top middle monster has +80% stats (except Cooldown and Multicast) |
| Mega Upgrade Disc | 6 | Mythical | The next monster to reach level 3 is leveled up again, then destroy this |
| Mystic Incense | 6 | Mythical | A Mythical monster will appear in your next shop |
| Rainbow Pearl | 6 | Mythical | All monsters in your shop are SHINY |
| Ultra Duplicator | 6 | Mythical | Whenever you gain a trinket, gain an additional copy |

## Items — 32 (consommables de boutique)

| Item | T | Coût | Rareté | Effet |
|---|---|---|---|---|
| Basic Bait | 1 | 0$ | Common | Lower the shop rank |
| Cake | 1 | 0$ | Common | Give 2 random monsters +5 Damage |
| Coupon | 1 | 0$ | Common | Reduce the cost of monsters in your shop by 5 |
| Fake Coin | 1 | 0$ | Common | Gain 1 free reroll |
| Gray Chip | 1 | 0$ | Common | If you win the next battle, gain $5 |
| Green Stone | 1 | 0$ | Common | Transform a random Common monster into a Uncommon monster |
| Voucher | 1 | 5$ | Common | Get a random monster from the current shop |
| Apex Bait | 2 | 20$ | Uncommon | Rank up the shop |
| Blue Stone | 2 | 0$ | Uncommon | Transform a random Uncommon monster into a Rare monster |
| Gray Ticket | 2 | 0$ | Uncommon | Reroll a shop with all Common monsters |
| Green Chip | 2 | 2$ | Uncommon | If you win the next battle, gain $10 |
| Green Ticket | 2 | 0$ | Uncommon | Reroll a shop with all Uncommon monsters |
| Nana Berry | 2 | 1$ | Uncommon | Give the bottom right monster +5% Cooldown Speed. You can use 1 more item(s) today |
| Pom Berry | 2 | 1$ | Uncommon | Give the bottom right monster +8 Damage. You can use 1 more item(s) today |
| Red Coin | 2 | 0$ | Uncommon | +$20 and lose 1 life |
| Battery Pack | 3 | 0$ | Rare | Give your Electric monsters +1 Shock |
| Black Sludge | 3 | 0$ | Rare | Give your Toxic monsters +1 Poison |
| Blue Chip | 3 | 5$ | Rare | If you win the next battle, gain $20 |
| Blue Ticket | 3 | 0$ | Rare | Reroll a shop with all Rare monsters |
| Hot Pepper | 3 | 0$ | Rare | Give your Fire monsters +1 Burn |
| Mystic Pearl | 3 | 0$ | Rare | Give your Water monsters +10 Heal |
| Purple Stone | 3 | 0$ | Rare | Transform a random Rare monster into a Super Rare monster |
| Shiny Pebble | 3 | 0$ | Rare | Give your Rock monsters +20 Shield |
| Focus Pill | 4 | 0$ | Super Rare | Your monsters with no abilities gain +25% Cooldown Speed |
| Lootbox | 4 | 30$ | Super Rare | Get a random Legendary monster |
| Purple Chip | 4 | 10$ | Super Rare | If you win the next battle, gain $40 |
| Purple Gift | 4 | 40$ | Super Rare | Gain a random Super Rare trinket |
| Purple Ticket | 4 | 0$ | Super Rare | Reroll a shop with all Super Rare monsters |
| Tote Bag | 4 | 5$ | Super Rare | You can use 2 more item(s) today |
| Golden Gift | 5 | 50$ | Legendary | Gain a random Legendary trinket |
| Golden Ticket | 5 | 0$ | Legendary | Reroll a shop with all Legendary monsters |
| Rare Candy | 5 | 40$ | Legendary | Level up a random level 1 monster |
