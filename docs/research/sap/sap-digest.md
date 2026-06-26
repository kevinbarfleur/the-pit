# Super Auto Pets — audit du dataset complet

> Source : dataset communautaire **sapai** (github.com/manny405/sapai, licence MIT), recoupé in-game. Raw : `super-auto-pets-data.json`. SAP = **grand-père du genre**, énorme succès ; game-loop ≠ la nôtre (pas de cooldowns, combat par vagues gauche→droite) mais **grammaire d'effets très instructive**.

> But de l'audit : repérer les mécaniques **signatures/originales** de SAP pour différencier The Pit (éviter le clone de Batomon). Cf. `the-pit-vs-batomon.md`.


## Vue d'ensemble

- **89 pets** (tier {1: 13, 2: 13, 3: 16, 4: 15, 5: 12, 6: 12}, + 8 tokens *Summoned*)
- **17 foods** (système d'items parallèle) · **10 statuses** (effets persistants posés par les foods) · **11 turns**
- baseAttack 1→10, baseHealth 1→12 · combat = équipe de 5, vagues gauche→droite, **pas de cooldowns**

## Ce qui frappe : une grammaire d'effets très large

### Taxonomie de triggers — **21 déclencheurs distincts** (vs 6 Batomon / 8 The Pit)

Couvre **les deux phases** (boutique ET combat) et des triggers **conditionnels à l'état** :

- `Faint` ×17
- `StartOfBattle` ×9
- `EndOfTurn` ×8
- `Sell` ×5
- `EatsShopFood` ×5
- `Summoned` ×5
- `Buy` ×4
- `StartOfTurn` ×4
- `Hurt` ×4
- `LevelUp` ×2
- `BuyFood` ×2
- `BeforeAttack` ×2
- `AfterAttack` ×2
- `EndOfTurnWith3PlusGold` ×2
- `KnockOut` ×2
- `BuyTier1Animal` ×2
- `BuyAfterLoss` ×1
- `EndOfTurnWithLvl3Friend` ×1
- `EndOfTurnWith4OrLessAnimals` ×1
- `PurchaseFood` ×1
- `CastsAbility` ×1

### Effets — **17 types** (vs « 6 stats » Batomon)

- `ModifyStats` ×41
- `DealDamage` ×10
- `SummonPet` ×6
- `GainGold` ×4
- `ApplyStatus` ×4
- `TransferStats` ×3
- `SummonRandomPet` ×2
- `OneOf` ×1
- `GainExperience` ×1
- `AllOf` ×1
- `Swallow` ×1
- `ReduceHealth` ×1
- `DiscountFood` ×1
- `RefillShops` ×1
- `TransferAbility` ×1
- `FoodMultiplier` ×1
- `RepeatAbility` ×1

### Ciblage positionnel/conditionnel — 20 cibles

`Self(13) · RandomFriend(6) · EachFriend(6) · TriggeringEntity(5) · EachShopAnimal(4) · RandomEnemy(4) · FriendBehind(3) · FriendAhead(3) · LeftMostFriend(1) · All(1) · AdjacentAnimals(1) · AdjacentFriends(1) · LowestHealthEnemy(1) · RightMostFriend(1) · Level2And3Friends(1) · DifferentTierAnimals(1) · HighestHealthEnemy(1) · LastEnemy(1) · FirstEnemy(1)`

### Permanence des buffs (signature SAP)

ModifyStats : **37 permanents** vs **4 `untilEndOfBattle`**. La distinction **buff de boutique (permanent, snowball) vs buff de combat (temporaire)** est un pilier de design.

## Mécaniques SIGNATURES (le cœur de l'intérêt)

**1. Économie de Faint / death-rattle** — 17 pets à trigger `Faint` : Ant, Cricket, Flamingo, Hedgehog, Rat, Spider, Badger, Ox, Sheep, Turtle, Deer, Rooster, Eagle, Microbe, Shark, Fly, Mammoth. Mourir DÉCLENCHE l'effet → on *veut* que des unités tombent.

**2. Économie de Summon** — 8 invocateurs (Cricket, Rat, Spider, Sheep, Deer, Rooster, Eagle, Fly) + 8 tokens. Faint+Summon se chaînent : un mur d'invocations, des relances en cascade.

**3. Copie / mimétisme** — Crab, Dodo, Whale, Parrot, Tiger, Butterfly : Crab (« Start of battle: copy 50% of health from most healthy friend ») ; Dodo (« Start of battle: Give 50% Attack to friend ahead. ») ; Whale (« Start of battle: Swallow friend ahead and release it as a level 1 after fainting. ») ; Parrot (« End Turn: Copy ability from pet ahead as lvl. 1 until end of battle. ») ; Tiger (« The friend ahead repeats their ability in battle as if they were level 1. ») ; Butterfly (« Copy stats of the strongest friend (highest attack and health combined). »). Theory-craft : Tiger-stack, Parrot-copy.

**4. Trigger `Hurt`** — Peacock, Blowfish, Camel, Gorilla : « quand blessé, gagne X » → builds tank/retaliate.

**5. Foods → Statuses (couche d'items persistants)** — un aliment pose un **statut** durable (armure, splash, extra-life). Plus profond qu'un consommable one-shot.

**6. Self-leveling découplé** — Chocolate (+1 XP), Caterpillar (gagne de l'XP) : monter de niveau **sans** fusionner 3 copies. Le niveau n'est pas qu'un 3-en-1.

**7. Forçage de combo** — Sleeping Pill (fait *faint* un allié à dessein), Honey/Mushroom (relance), Canned Food (+2/+1 à tout le shop présent ET futur = moteur). On *fabrique* la combo.

## Foods (17) — système d'items parallèle

| Food | Tier | Effet |
|---|---|---|
| Apple | 1 | Give an animal +1/+1. |
| Honey | 1 | Give an animal Honey Bee. |
| Cupcake | 2 | Give an animal +3/+3 until end of battle. |
| Meat Bone | 2 | Give an animal Bone Attack. |
| Sleeping Pill | 2 | Make a friendly animal faint. |
| Garlic | 3 | Give an animal Garlic Armor. |
| Salad Bowl | 3 | Give 2 random animals +1/+1. |
| Canned Food | 4 | Give all current and future shop animals +2/+1. |
| Pear | 4 | Give an animal +2/+2. |
| Chili | 5 | Give an animal Splash Attack. |
| Chocolate | 5 | Give an animal +1 Experience. |
| Sushi | 5 | Give 3 random animals +1/+1. |
| Melon | 6 | Give an animal Melon Armor. |
| Mushroom | 6 | Give an animal Extra Life. |
| Pizza | 6 | Give 2 random animals +2/+2. |
| Steak | 6 | Give an animal Steak Attack. |
| Milk | Summoned | Give an animal +1/2/3 attack and +2/4/6 health (depending on level of Cow). |

## Statuses (10) — effets persistants posés par les foods

| Status | Trigger/Effet | Description |
|---|---|---|
| Weak | WhenDamaged/ModifyDamage | Take 3 extra damage. |
| Coconut Shield | WhenDamaged/ModifyDamage | Ignore damage once. |
| Honey Bee | Faint/SummonPet | Summon a 1/1 Bee after fainting. |
| Bone Attack | WhenAttacking/ModifyDamage | Attack for 5 more damage. |
| Garlic Armor | WhenDamaged/ModifyDamage | Take 2 less damage. |
| Splash Attack | WhenAttacking/SplashDamage | Attack second enemy for 5 damage. |
| Melon Armor | WhenDamaged/ModifyDamage | Take 20 damage less, once. |
| Extra Life | Faint/RespawnPet | Come back as a 1/1 after fainting |
| Steak Attack | WhenAttacking/ModifyDamage | Attack for 20 more damage, once. |
| Poison Attack | WhenAttacking/ModifyDamage | Knock out any animal hit by this. |

## Courbe de progression (turns)

| Turn | Food slots | Animal slots | Lives lost | Tiers dispo | Level-up tier |
|---|---|---|---|---|---|
| 1 | 1 | 3 | 1 | 1 | 2 |
| 2 | 1 | 3 | 1 | 1 | 2 |
| 3 | 2 | 3 | 2 | 2 | 3 |
| 4 | 2 | 3 | 2 | 2 | 3 |
| 5 | 2 | 4 | 3 | 3 | 4 |
| 6 | 2 | 4 | 3 | 3 | 4 |
| 7 | 2 | 4 | 3 | 4 | 5 |
| 8 | 2 | 4 | 3 | 4 | 5 |
| 9 | 2 | 5 | 4 | 5 | 6 |
| 10 | 2 | 5 | 4 | 5 | 6 |
| 11 | 2 | 5 | 5 | 6 | 6 |

## Roster complet (89 pets)

| Pet | Tier | ATK/PV | Trigger | Capacité (niv.1) |
|---|---|---|---|---|
| Ant | 1 | 2/1 | Faint | Faint: Give a random friend +2/+1 |
| Beaver | 1 | 3/2 | Sell | Sell: Give two random friends +1 health |
| Beetle | 1 | 2/3 | EatsShopFood | Eat shop food: Give shop animals +1 health |
| Bluebird | 1 | 2/1 | EndOfTurn | End turn: Give left-most friend +1 attack |
| Cricket | 1 | 1/2 | Faint | Faint: Summon a 1/1 Cricket |
| Duck | 1 | 2/3 | Sell | Sell: Give shop animals +1 Health |
| Fish | 1 | 2/2 | LevelUp | Level-up: Give all friends +1/+1 |
| Horse | 1 | 2/1 | Summoned | Friend summoned: Give it +1 Attack until end of battle |
| Ladybug | 1 | 1/3 | BuyFood | Buy food: Gain +1/+1 until end of battle |
| Mosquito | 1 | 2/2 | StartOfBattle | Start of battle: Deal 1 damage to a random enemy |
| Otter | 1 | 1/2 | Buy | Buy: Give one random friend +1/+1 |
| Pig | 1 | 4/1 | Sell | Sell: Gain an extra 1 gold |
| Sloth | 1 | 1/1 | — | — |
| Bat | 2 | 1/2 | StartOfBattle | Start of battle: Make 1 enemy Weak. |
| Crab | 2 | 3/1 | StartOfBattle | Start of battle: copy 50% of health from most healthy friend |
| Dodo | 2 | 2/3 | StartOfBattle | Start of battle: Give 50% Attack to friend ahead. |
| Dromedary | 2 | 2/4 | StartOfTurn | Start of turn: Give shop animals +1/+1 |
| Elephant | 2 | 3/5 | BeforeAttack | Before Attack: Deal 1 damage to 1 friends behind. |
| Flamingo | 2 | 4/2 | Faint | Faint: Give the two friends behind +1/+1. |
| Hedgehog | 2 | 3/2 | Faint | Faint: Deal 2 damage to all. |
| Peacock | 2 | 2/5 | Hurt | Hurt: Gain 4 attack. |
| Rat | 2 | 4/5 | Faint | Faint: summon one 1/1 Dirty Rat for the opponent that betrays him. |
| Shrimp | 2 | 2/3 | Sell | Friend sold: Give a random friend +1 Health. |
| Spider | 2 | 2/2 | Faint | Faint: Summon a level 1 tier 3 animal as a 2/2 |
| Swan | 2 | 1/3 | StartOfTurn | Start of turn: Gain 1 gold. |
| Tabby Cat | 2 | 5/3 | EatsShopFood | Eats shop food: Give friends +1 Attack until end of battle |
| Dog | 3 | 3/3 | Summoned | Friend summoned: Gain +1 Attack or +1 Health. |
| Badger | 3 | 5/3 | Faint | Faint: Deal Attack damage to adjacent animals |
| Blowfish | 3 | 3/5 | Hurt | Hurt: Deal 2 damage to a random enemy. |
| Caterpillar | 3 | 1/3 | StartOfTurn | Start of turn: Gain 1 Experience. |
| Camel | 3 | 2/6 | Hurt | Hurt: Give friend behind +2/+2 |
| Hatching Chick | 3 | 1/1 | EndOfTurn | End turn: Give +5/+5 to friend ahead until end of battle. |
| Giraffe | 3 | 2/4 | EndOfTurn | End turn: Give friend ahead +1/+1 |
| Kangaroo | 3 | 1/2 | AfterAttack | Friend ahead attacks: Gain +2/+2 |
| Owl | 3 | 5/3 | Sell | Sell: Give a random friend +2/+2 |
| Ox | 3 | 1/3 | Faint | Friend ahead attacks: Gain Melon Armor and +1 attack |
| Puppy | 3 | 1/1 | EndOfTurnWith3PlusGold | End turn: If you have 3 or more gold, gain +2/+2 |
| Rabbit | 3 | 1/2 | EatsShopFood | Pet eats shop food: Give it +1 Health |
| Sheep | 3 | 2/2 | Faint | Faint: Summon two 2/2 Rams |
| Snail | 3 | 2/2 | BuyAfterLoss | Buy: If you lost last battle, give all friends +2/+1 |
| Tropical Fish | 3 | 2/4 | EndOfTurn | End turn: Give adjacent friends +1 Health |
| Turtle | 3 | 1/2 | Faint | Faint: Give friend behind Melon Armor |
| Whale | 4 | 3/8 | StartOfBattle | Start of battle: Swallow friend ahead and release it as a level 1 after fainting. |
| Bison | 4 | 4/4 | EndOfTurnWithLvl3Friend | End turn: Gain +2/+2 if there is at least one Lvl. 3 friend. |
| Buffalo | 4 | 5/5 | Buy | Friend bought: Gain +1/+1 |
| Deer | 4 | 1/1 | Faint | Faint: Summon a 5/5 Bus with Splash Attack |
| Dolphin | 4 | 4/6 | StartOfBattle | Start of battle: Deal 5 damage to the lowest health enemy |
| Hippo | 4 | 4/7 | KnockOut | Knock out: Gain +3/+3. |
| Llama | 4 | 3/6 | EndOfTurnWith4OrLessAnimals | End turn: If you have 4 or less animals, gain +2/+2. |
| Lobster | 4 | 4/5 | Summoned | Friend summoned: Give it +2/+2 when not in battle. |
| Penguin | 4 | 1/2 | EndOfTurn | End turn: Give other Lvl. 2 and 3 friends +1/+1 |
| Rooster | 4 | 5/3 | Faint | Faint: Summon a Chick with 1 health and half the Attack of this. |
| Skunk | 4 | 3/5 | StartOfBattle | Start of battle: Reduce the highest Health enemy by 33%. |
| Squirrel | 4 | 2/5 | StartOfTurn | Start of turn: Discount shop food by 1 gold |
| Worm | 4 | 3/3 | EatsShopFood | Eats shop food: Gain +1/+1 |
| Microbe | 4 | 1/1 | Faint | Faint: Make all animals Weak. |
| Parrot | 4 | 4/3 | EndOfTurn | End Turn: Copy ability from pet ahead as lvl. 1 until end of battle. |
| Monkey | 5 | 1/2 | EndOfTurn | End turn: Give right-most friend +2/+3 |
| Poodle | 5 | 2/2 | EndOfTurn | End turn: Give +1/+1 to different tier animals. |
| Chicken | 5 | 1/2 | BuyTier1Animal | Buy tier 1 animal: Give current and future shop animals +1/+1 |
| Cow | 5 | 4/6 | Buy | Buy: Replace food shop with 2 free milk that gives +1/+2. |
| Crocodile | 5 | 8/4 | StartOfBattle | Start of battle: Deal 8 damage to the last enemy |
| Eagle | 5 | 6/5 | Faint | Faint: Summon one Lvl. 1 tier 6 animal. |
| Goat | 5 | 4/6 | Buy | Friend bought: Gain 1 gold. |
| Rhino | 5 | 5/8 | KnockOut | Knock out: Deal 4 damage to the first enemy. |
| Scorpion | 5 | 1/1 | — | — |
| Seal | 5 | 3/8 | EatsShopFood | Eats shop food: Give 2 random friends +1/+1. |
| Shark | 5 | 4/4 | Faint | Friend faints: Gain +2/+2. |
| Turkey | 5 | 3/4 | Summoned | Friend summoned: Give it +3/+3. |
| Cat | 6 | 4/5 | PurchaseFood | Food with Health and Attack effects are doubled. |
| Boar | 6 | 10/6 | BeforeAttack | Before attack: Gain +2/+2. |
| Dragon | 6 | 6/8 | BuyTier1Animal | Buy tier 1 animal: Give all friends +1/+1. |
| Fly | 6 | 5/5 | Faint | Friend faints: Summon a 5/5 fly in its place (Max 3 times) |
| Gorilla | 6 | 6/9 | Hurt | Hurt: Gain Coconut Shield. Works 1 time per turn. |
| Leopard | 6 | 10/4 | StartOfBattle | Start of battle: Deal 50% Attack damage to a random enemy. |
| Mammoth | 6 | 3/10 | Faint | Faint: Give all friends +2/+2 |
| Octopus | 6 | 8/8 | LevelUp | Level-up: Gain +8/+8. |
| Sauropod | 6 | 4/12 | BuyFood | Buy food: Gain 1 gold. |
| Snake | 6 | 6/6 | AfterAttack | Friend ahead attacks: Deal 5 damage to a random enemy. |
| Tiger | 6 | 4/3 | CastsAbility | The friend ahead repeats their ability in battle as if they were level 1. |
| Tyrannosaurus | 6 | 9/4 | EndOfTurnWith3PlusGold | End turn: If you have 3 or more gold, give all +2/+1 |
| Zombie Cricket | Summoned | ?/? | — | — |
| Bus | Summoned | ?/? | — | — |
| Zombie Fly | Summoned | ?/? | — | — |
| Dirty Rat | Summoned | 1/1 | — | — |
| Chick | Summoned | ?/1 | — | — |
| Ram | Summoned | ?/? | — | — |
| Butterfly | Summoned | 1/1 | Summoned | Copy stats of the strongest friend (highest attack and health combined). |
| Bee | Summoned | 1/1 | — | — |
