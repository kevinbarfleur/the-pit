# The Pit — Garanties de test (seed/tests.md)

> Lecture seule du repo : tests/synergies.lua, tests/props.lua, tests/golden.lua,
> tests/run.lua, tests/relics.lua. Ce document extrait ce qui est GARANTI par la
> suite de tests existante et les invariants que toute proposition future DOIT respecter.
> Source primaire : fichiers cites ci-dessus, lus en session 2026-06-23.

---

## 1. Invariants de combat (tests/props.lua)

Ces quatre proprietes sont verifiees sur CHAQUE tick de CHAQUE combat du fuzz
(250 combats aleatoires + 1 combat de determinisme explicite, RNG du fuzz seede
sur `20260620`).

| Propriete | Assertion exacte |
|-----------|-----------------|
| PV >= 0 | `u.hp >= 0` pour toute unite, tout tick |
| Bouclier >= 0 | `u.shield >= 0` pour toute unite, tout tick |
| PV <= maxHp | `u.hp <= u.maxHp` (plafond infranchissable) |
| Terminaison | `arena.over` avant `TICK_CAP = 8000` ticks |
| Un seul vainqueur | exactement un camp a des surivivants (`(l>0) ~= (r>0)`) |
| Determinisme | meme build + meme seed -> empreinte event-log identique (cycle de deux runs) |

**Consequence pour les propositions** : tout effet (DoT, relique, synergie) qui
pourrait faire passer les PV sous zero ou le bouclier sous zero, ou rendre maxHp
franchissable, ou bloquer la terminaison, est un bug de regression. Le moteur doit
clamp ou terminer ; c'est a la SIM de le garantir, pas aux tests futurs.

---

## 2. Regression d'empreinte (tests/golden.lua)

Un scenario canonique FIGE (plateau carre 9 slots, 5 unites : templar/marauder/
skeleton/witch/demon, encounter #2, seed `424242`) produit l'empreinte `970156547`.

Deux gardes-fous independants :

1. **Empreinte stable** : tout changement comportemental (timing, degats, effets)
   fait diverger l'empreinte. On le detecte immediatement.
2. **Garde Fatigue** : le scenario DOIT conclure avant `Arena.FATIGUE_START`. Si
   ce seuil est franchi, l'empreinte n'est plus golden-safe et le test echoue.

**Consequence** : toute modification de `arena.lua`, `effects/engine.lua`,
`effects/ops.lua`, `effects/stats.lua`, `board/shapes.lua` ou `data/units.lua`
qui change le deroulement du combat DOIT rebaseliner explicitement `EXPECTED`
dans golden.lua. Un rebaseline silencieux sans changement voulu = regression.

La valeur courante `970156547` a ete mise a jour le 2026-06-21 lors du passage
`HP_MULT=2` (PV multiplies par 2, combats plus longs, mais toujours avant Fatigue).

---

## 3. Interactions d'effets garanties (tests/synergies.lua)

Les 12 synergies ci-dessous sont testees en combat reel (pas en isolation) avec
RNG seede. Chacune est une garantie que l'interaction EXISTE et produit le
resultat attendu.

### Vague 1-2 : familles en interaction (T1)

| # | Synergie | Ce qui est garanti |
|---|----------|--------------------|
| 1 | Choc-decharge-allie | frapper une cible chargee (shock.stacks×volt) inflige PLUS que sur cible saine ; le condensateur est consomme (nil apres decharge) |
| 2 | Poison multi-sources | deux unites empilent sur la meme cible ; 3 stacks de 2 sources s'accumulent |
| 3 | Weaken reduit l'output | un attaquant empoisonne (weaken 0.3) inflige moins que le meme sain |
| 4 | Bleed ralentit la cadence | une unite saignante (slowPct 0.5) attaque moins de fois sur une fenetre identique |
| 5 | Regen contre DoT | regen=2 attenue la perte nette face a poison dps=3 (perte totale strictement inferieure) |

### Vague 3 : twists T2

| # | Synergie | Ce qui est garanti |
|---|----------|--------------------|
| 6 | Contagion (plague_bearer) | hit sur t0 -> t0 ET t1 (voisin sur le champ de bataille) recoivent 1 stack de poison |
| 7 | Propagation a la mort (wildfire_hound) | la propagation se fait DANS le drain `on_death` (pas pendant le hit) : le voisin n'est pas en feu avant `update()`, il l'est apres |
| 8 | Aggravate (bleed burst au swing) | l'attaquant saignant (aggravateMult=2.0) perd >= `floor(dps*mult)` PV lorsqu'il frappe |
| 9 | ShieldEat (acid_maw) | le bouclier de la cible descend EN DESSOUS de `bouclier0 - am.dmg` (le venin ronge au-dela de l'absorption) |

### Vague 4 : transforms T3 et croisements

| # | Synergie | Ce qui est garanti |
|---|----------|--------------------|
| 10 | Bleed -> Rot (marrow_drinker) | frapper une cible saignante : le bleed est CONSOMME (nil) et la cible recoit rot |
| 11 | Poison -> Burn a 5 stacks (venom_censer) | au tick suivant 5 stacks poses, la cible s'enflamme (dots.burn non nil) |
| 12 | Festering : cap leve (equipe) | avec festering dans l'equipe, spore_tick peut accumuler 12 stacks (> cap par defaut de 8) |

**Consequence** : toute refactorisation de `arena:hit`, `arena:tickDots`,
`arena:damage`, `arena:neighborsOf`, `arena:update` ou d'un op d'effet DOIT
conserver ces 12 comportements. Les tests synergies.lua constituent le contrat
d'interaction du moteur d'effets.

---

## 4. Invariants de run (tests/run.lua)

### 4.1 Etat initial (reproductible par seed)

| Champ | Valeur garantie |
|-------|----------------|
| `r.gold` | `RunState.GOLD_PER_ROUND` |
| `r.lives` | `RunState.START_LIVES` (5) |
| `r.wins` | 0 |
| `r.losses` | 0 |
| `r.round` | 1 |
| `r.slots` | `RunState.START_SLOTS` (3) |
| `r.pendingSlotGrant` | false |
| `#r.shop` | `RunState.SHOP_SIZE` (5 offres) |
| `r.relicFromLevelThisRound` | false |
| `r.shopTier` | `RunState.START_TIER` (1) |
| `r.shopXp` | 0 |
| `r.shopOddsShift` | 0 |

### 4.2 Invariants durs (fuzz 60 runs x 80 actions, jamais violes)

```
r.gold >= 0
r.lives dans [0, RunState.START_LIVES]
r.slots dans [RunState.START_SLOTS, RunState.MAX_SLOTS]
r.slotGrantsResolved <= RunState.MAX_GRANTS
#r.shop == RunState.SHOP_SIZE (toujours 5 offres)
r.shopTier dans [RunState.START_TIER, RunState.MAX_TIER]
r.shopXp >= 0
r:xpToNext() == nil ssi r.shopTier >= RunState.MAX_TIER
r.shopXp < r:xpToNext() (cascade toujours resolue, jamais de trop-plein residuel)
```

### 4.3 Economie SAP (or FRAIS chaque round, pas de report)

- `r:startRound()` : l'or est REMIS a `GOLD_PER_ROUND` (+ bonus de streak), pas accumule.
- Streak 3 victoires -> +2 or au round suivant (verifie explicitement).
- `r:reroll()` deduit `RunState.REROLL_COST` ; echoue si `gold < REROLL_COST`.
- `r:buy(i)` deduit `offer.cost` ; echoue si `gold < offer.cost` ou offre deja vendue.

### 4.4 Slots : grants times (rounds 2..7)

- Round 1 : aucune offre (`canGrant() == false`).
- Rounds 2..7 : une offre par round (accept -> +1 slot / decline -> +`SLOT_DECLINE_GOLD` or).
- Plafond : 6 grants -> au plus `MAX_SLOTS` (9) si tout accepte.
- `slotGrantsResolved` plafonne a `MAX_GRANTS`.
- `canGrant()` revient false au-dela du plafond.

### 4.5 Leveling de boutique (XP + tier)

- XP passive : +1 par round a partir du round 2 (cumul = round - 1).
- `r:buyXp()` deduit `BUY_XP_COST`, ajoute `BUY_XP_AMOUNT` (4 XP), cascade les tiers.
- Seuils `XP_TO_LEVEL[t]` : T1=2, T2=5 (verifies explicitement).
- Cascade : un gros gain d'XP traverse plusieurs tiers d'un coup ; `shopXp` reste < seuil courant apres cascade.
- Tier max (5) : `buyXp` renvoie false, `addShopXp` n'accumule plus, `shopXp` reste 0.
- `shopOddsShift` : decalage de cotes, clamp a 1 (jamais d'index nil), tier reel inchange.
- `raiseShopTier(n)` : +n, clampe a `MAX_TIER` ; `shopXp` remis a 0 au tier max.

### 4.6 Cotes de boutique (statistique, seed fixe)

- Tier 1 + shift 0 : 100% rang 1 (verifie sur 40 rolls x 5 offres = 200 offres).
- Tier 5 : distribution conforme a `RunState.ODDS[5]`, tolerance +/-6 pts de % (sur 2000 offres, seed `20260623`).
- `shopOddsShift = -1` avec tier 3 -> offres selon `ODDS[2]` (aucun rang >= 3, verifie sur 2000 offres).

### 4.7 Determinisme du run

- Meme seed -> meme suite d'ids de boutique sur plusieurs rolls + meme seed de combat.
- `r:nextCombatSeed()` : appels successifs donnent des seeds distincts mais reproductibles.
- `r:startRound()` : remet `relicFromLevelThisRound = false` (au plus 1 relique de level-up par round).

### 4.8 Boucle de run

- 10 victoires avant 5 defaites -> `isOver() == "win"`.
- 5 defaites avant 10 victoires -> `isOver() == "lose"`.
- Filet SAP : si perte au round <= 2, le round 3 rend +1 vie (via `startRound`). Sans perte, pas de cadeau.

### 4.9 Reliques dans la run (invariants run.lua §reliques)

- `maxRelicTier()` : early (0-1 wins) -> 2, mid (2-4 wins) -> 3, late (5+ wins) -> 4.
- `rollRelicChoices(3)` : 3 ids tous de tier <= plafond (quand assez de candidats).
- Fallback : si < 3 candidats sous le plafond (possede presque tout), on elargit a TOUTES les non possedees ; l'offre reste a 3 ; au moins 1 id de tier > plafond apparait.
- Determinisme : meme seed + memes wins -> memes ids d'offre (snapshot/replay garanti).
- `declineRelic()` : +`DECLINE_RELIC_GOLD` or, aucune relique ajoutee.

---

## 5. Invariants des reliques (tests/relics.lua)

### 5.1 Modele lisible (post-revision 2026-06)

- `grantRelic(id)` : stocke `{id=id}` uniquement — **aucun champ `candidates` ni `identified`**.
- Pas de doublon : `grantRelic(id)` une seconde fois -> false, aucun doublon.

### 5.2 Ops de combat (appliques via `applyRelics(comp)`)

| Relique | Op | Effet garanti |
|---------|----|---------------|
| bloodstone | more_dmg | +14% dmg (calibre ; bandit 10->11, witch 13->15) |
| carapace | flat_hp | +8 max HP (calibre ; bandit 46->54) |
| kings_bowl | affliction_inc | +0.20 poisonInc ADDITIF sur chaque spec (s'ajoute a une aura existante) |
| aegis | dmg_reduce | pose `dmgReduce = 0.15` (lu par `Arena:damage` cause=attack) |
| famines_math | conditionnel | <= 3 unites : +30% dmg / +20% hp ; > 3 unites : inerte |
| hollow_choir | grant_team | ajoute `{op="grant_team", params={pierceHeal=...}}` aux effets |
| feeding_frenzy | on_death | ajoute `{op="frenzy_gain"}` aux effets |
| whetstone | haste | pose `haste = 0.15` |
| second_breath | survie | pose `secondBreath = true` |
| sacred_shield | grant_team | ajoute `{op="grant_team", params={invulnT=...}}` |
| thornguard | on_attacked | ajoute `{op="thorns"}` |
| forked_tongue | transformative | grant_team `{shockChain=...}` |
| everburn | transformative | grant_team `{burnNoDecay=...}` |
| open_wounds | transformative | grant_team `{bleedNoExpire=...}` |
| plague_communion | transformative | grant_team `{plagueAmp=...}` |

### 5.3 Reliques de boutique (runOp, sans op combat)

Trois reliques ont un champ `runOp` et **aucun champ `op`** :

| id | runOp | tier | Effet sur le run |
|----|-------|------|-----------------|
| carrion_ledger | shop_xp | 3 | +6 XP -> cascade tiers (tier 1->2 avec 4 XP residuelle) |
| black_summons | shop_tier_up | 4 | +1 tier immediat, clampe a MAX_TIER |
| beggars_lantern | shop_tier_down | 2 | `shopOddsShift = -1` (tier reel inchange) |

**Guarantee d'innocuite** : `applyRelics(comp)` avec ces reliques dans r.relics ne crash pas et ne modifie AUCUNE stat de combat ni n'ajoute d'effets de combat.

### 5.4 Offre seedee et tierage

- `rollRelicChoices(3)` : meme seed -> memes ids (rejouable, snapshot-safe).
- Early (0 win) : toutes les reliques offertes sont de tier <= 2 (quand assez de candidats).
- Late (5 wins) : plafond tier 4, toutes les reliques offertes sont dans le plafond.
- Fallback identique a 4.9 ci-dessus.

### 5.5 Grimoire (collection meta cross-run)

- `Grimoire.isKnown(id)` : false au depart (apres `wipe()`).
- `Grimoire.learn(id)` : true la premiere fois, false si deja connu (idempotent).
- `Grimoire.isKnown(id)` : true apres learn.
- Persistance cross-run : le Grimoire survit aux runs (seule `wipe()` efface).

---

## 6. Synthese — ce qu'une proposition NE PEUT PAS violer

Les invariants ci-dessous sont les GARDE-FOUS ABSOLUS. Une feature, un effet, une
relique, un sigil ou une mecanique qui violerait l'un d'eux necessite une modification
des tests AVANT la modification du code, et ce changement doit etre explicitement
valide (pas silencieux).

### Detrminisme et reproductibilite (pilier async-snapshot)

1. Meme build + meme seed de combat -> event-log a empreinte identique (props.lua).
2. Meme seed de run -> meme suite d'offres de boutique, memes seeds de combat (run.lua).
3. Meme seed + memes wins -> meme offre de reliques (run.lua + relics.lua).
4. Tout RNG de la SIM doit passer par le generator seede injecte (`opts.rng`), jamais `math.random` global.
5. Le golden `970156547` ne doit diverger que si le changement est voulu et rebiseline explicitement.

### Physique de combat

6. `u.hp` : jamais < 0, jamais > `u.maxHp` (props.lua).
7. `u.shield` : jamais < 0 (props.lua).
8. Terminaison garantie avant `TICK_CAP = 8000` ticks (props.lua).
9. Exactement un camp survivant a la fin (props.lua).
10. Le golden conclut avant `Arena.FATIGUE_START` (golden.lua).

### Invariants de run

11. `gold >= 0` (run.lua fuzz).
12. `lives` dans `[0, START_LIVES]` (run.lua fuzz).
13. `slots` dans `[START_SLOTS, MAX_SLOTS]` (run.lua fuzz).
14. `#shop == SHOP_SIZE` (toujours 5 offres, run.lua fuzz).
15. `shopTier` dans `[START_TIER, MAX_TIER]` (run.lua fuzz).
16. `shopXp >= 0` et `shopXp < xpToNext()` apres toute cascade (run.lua fuzz).
17. `xpToNext() == nil` ssi `shopTier >= MAX_TIER` (run.lua fuzz).

### Modele relique

18. `grantRelic(id)` ne stocke que `{id=id}` — pas de candidats/identification (relics.lua).
19. Pas de doublon : `grantRelic(id)` deux fois -> false la seconde fois (relics.lua).
20. Les reliques `runOp` (carrion_ledger / black_summons / beggars_lantern) ne modifient aucune stat de combat (relics.lua).
21. `applyRelics` est idempotent sur la structure de la compo : elle ne crash pas quelle que soit la liste des reliques possedees (relics.lua).

### Synergies garanties (12 contrats d'interaction)

22. Choc : decharge par un allie, condensateur consomme (synergies.lua #1).
23. Poison : accumulation multi-sources, weaken cumulatif (synergies.lua #2, #3).
24. Bleed : ralentit la cadence d'attaque (synergies.lua #4).
25. Regen : attenuation nette d'un DoT (synergies.lua #5).
26. Contagion : propagation au voisin au hit (synergies.lua #6).
27. Propagation a la mort : dans le drain on_death, pas dans le hit (synergies.lua #7).
28. Aggravate : burst au swing, borne par `floor(dps*mult)` (synergies.lua #8).
29. ShieldEat : erosion au-dela de l'absorption simple (synergies.lua #9).
30. Bleed->Rot : conversion (bleed consomme, rot pose) (synergies.lua #10).
31. Poison->Burn a 5 stacks : detonation au tick (synergies.lua #11).
32. Festering : cap leve pour toute l'equipe (synergies.lua #12).

---

## 7. Ce que les tests n'attestent PAS (zones sans garde-fou actuel)

Les points suivants NE sont PAS couverts par les cinq fichiers lus. Une proposition
les touchant n'a pas de filet de securite existant et devrait ajouter un test.

- Effets aura/relique dans les snapshots (snapshot.lua teste la structure, pas l'effet
  des reliques sur la compo capturee).
- Passifs de ligne (facade=armure / arriere=attaque) : aucun test de cette mecanique.
- Contres de taunt (AoE-colonne / strip / furtivite) : non testes.
- Ladder choc etendu (5/3/2) : 1 seule unite choc dans le roster, synergy testee
  mais pas la distribution de pool.
- Rendu (`arena_draw.lua`, scene `build.lua`, `combat.lua`) : aucun test headless
  du rendu (normal, c'est un module RENDER).
- Grimoire persistance fichier (IO reel) : seul le comportement en memoire est teste.
- Ecran Grimoire / UI reliques (3 candidats) : non couverts.
- Profils d'exposition des sigils par forme (anneau, etc.) : le golden couvre le
  carre, les autres formes ne sont pas goldenes.

---

*Sources : tests/synergies.lua, tests/props.lua, tests/golden.lua, tests/run.lua,
tests/relics.lua — lus en session 2026-06-23. Ne pas modifier ce document sans
relire les fichiers sources. Ne pas modifier les fichiers sources du jeu sans
verifier que les garanties de cette section restent satisfaites.*
