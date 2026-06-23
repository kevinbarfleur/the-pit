# PRD — Progression, paliers de boutique & cadence des reliques

> **Statut : DESIGN VERROUILLÉ (2026-06-23), implémentation à venir.**
> Objectif : donner à une partie un **flot de progression** (early simple → late synergies), absent
> aujourd'hui. Trois leviers entremêlés : (1) **niveau de boutique** qui révèle les rangs
> progressivement, (2) **re-tier du roster par complexité** (New World Order) + plancher rank-1,
> (3) **reliques plus fréquentes & bornées**. Les doublons (déjà faits) sont le 4ᵉ pilier porteur.
>
> Sources de recherche : voir §9. Code de référence vérifié : `src/run/state.lua`, `src/scenes/build.lua`,
> `src/data/units.lua`, `src/data/relics.lua`, `main.lua` (host).

## Journal de décisions
- **2026-06-23** — PRD créé. Décisions user : boutique **payée** (remise auto HS) ; reliques **±niveau
  de boutique** ; **loi de puissance des doublons** (rank-1 lvl-3 ≈ rank-3/4 lvl-1 en stats brutes) ;
  re-tier **complet** (arbitré) ; seuil « 2+ afflictions » → **offres de reliques tiérées par avancée**
  (arbitré) ; level-up→relique **borné 1/round** (user 2026-06-23) ; `cost = rank` confirmé (coûts libres à rebalancer).
- **2026-06-23 (soir, post-playtest)** — Lots 0-3 livrés (verts, golden 970156547, non-committés cf. choix B).
  **Modèle boutique révisé** suite playtest : HS « payer pour monter » → **XP TFT-style** (XP **passive** +
  **achetable**, barre d'XP, tooltip cotes ; intention : passif ≈ tier 3 en fin de partie). Suite : refinement
  XP (state+UI), puis reliques (Lots 4-6).

---

## 1. Problème (état des lieux, 79 unités — chiffré)

| Constat | Donnée | Conséquence |
|---|---|---|
| **Pas de plancher** | 0 unité rank-1 / coût-1 | Rien qui « tape juste » à proposer en early |
| **Bourrelet** | **54 % du roster au coût 3** | Tout au même palier perçu |
| **Monoculture** | **~78 % posent un DoT** | L'archétype « brute basique » n'existe pas (1 unité) |
| **Complexité ⊥ coût** | T2 « twists » massés au coût 3 (le plus fréquent) | Le palier commun est le plus alambiqué |
| **Boutique plate** | tirage **uniforme** dans tout le pool (`state.lua:roll`) | On voit un transform coût-5 dès le round 1 → submergé |
| **`rank` inerte** | 1-5 = purement cosmétique (cadre/glow/pips) | Mais **présent sur chaque unité** → hook gratuit pour les cotes |
| **Reliques rares** | octroi à chaque **3ᵉ victoire** (`main.lua:finishCombat`) → **3/run** | Aucune densité de choix build-shaping |

→ **Cause racine** : un roster **plat en complexité** servi **uniformément**. Gater par tier sans
re-tiérer ne ferait que cacher le bourrelet derrière une porte.

---

## 2. Objectifs / Non-objectifs

**Objectifs**
- Un **arc de partie lisible** : combats 1-2 = brutes qui tapent ; ~70 % = synergies avancées, on ne
  voit quasi plus les rank-1.
- Un **arbitrage économique** réel (monter le shop vs reroll vs acheter), sans spirale de la mort.
- Une **densité de reliques** qui récompense la progression (level-up) et le temps (marchand), bornée.
- Un **archétype « low-tier max doublon »** viable (loi de puissance des doublons + relique -1 niveau).

**Non-objectifs (hors scope ici)**
- Intérêts/banque d'or (reste V2, modèle SAP).
- Re-coupler les slots à l'or (= l'ancien piège ; les slots restent en grants timés).
- Matchmaking par rang, backend distant, capture des effets aura/relique dans le snapshot.
- Refonte du moteur de combat (déterminisme/firewall **inchangés** ; tout ceci est data + run + UI).

---

## 3. Pilier 1 — Niveau de boutique (révélation par rang)

### 3.1 Modèle : **XP de boutique (TFT-style) — passive + achetable** *(révisé 2026-06-23, playtest)*
- La boutique a un **niveau 1→5** et une **barre d'XP** vers le suivant. On gagne de l'XP de DEUX façons :
  **passive** (un peu à chaque round → évolution garantie même sans investir) **et achetée** (dépenser de
  l'or → monter plus vite, rusher les hauts rangs).
- **Pourquoi la passive** (demande user) : sans elle, un joueur qui n'achète jamais d'XP resterait tier 1
  toute la partie (bizarre). Avec elle, l'évolution est garantie ; l'achat n'est qu'une **accélération**.
- **Intention de calibrage** : un joueur **passif** atteint **~tier 3 en fin de partie** (pas tier 5) ; un
  joueur qui **rush** l'XP atteint **tier 5 vers le milieu**. Passive = plancher montant, achat = accès au sommet.
- **Odds-gating, pas slot-gating** (l'ancien piège slot ne revient pas). Offres = **5** quel que soit le
  niveau (TFT) — monter change la **distribution** (§3.2), pas le nb de cartes. **Tease** rang `N+1` à ~2-5 %.
- **UI** : barre d'XP + niveau courant, bouton **BUY XP** ; **tooltip au survol** = cotes par rang du niveau
  courant (« à ce niveau, % de chance de chaque tier d'unité »).

### 3.2 Table de cotes (placeholder, calibrer via sim)
% de chance par slot de boutique de tirer une unité de chaque rang :

| Tier | rank 1 | rank 2 | rank 3 | rank 4 | rank 5 |
|---|---|---|---|---|---|
| **1** | 100 | – | – | – | – |
| **2** | 70 | 30 | – | – | – |
| **3** | 44 | 34 | 20 | 2 | – |
| **4** | 25 | 30 | 30 | 13 | 2 |
| **5** | 15 | 20 | 30 | 25 | 10 |

### 3.3 Économie d'XP (placeholders, calibrer via sim — Lot 7)
- **XP passive** : `+PASSIVE_XP_PER_ROUND` (≈ **1**) à chaque `startRound`.
- **XP achetée** : bouton BUY XP = `BUY_XP_AMOUNT` (≈ **4**) XP pour `BUY_XP_COST` (≈ **4** or) — ratio 1:1.
- **Seuils** `XP_TO_LEVEL[tier]` (XP pour passer DE tier i à i+1) ≈ `{ [1]=2, [2]=5, [3]=8, [4]=12 }`
  (cumulé : T2=2, T3=7, T4=15, T5=27). Trop-plein **reporté** (cascade possible).
- **Vérif d'intention** : passive seule (1/round) → ~tier 3 en fin de partie (T4 trop tard) ✓ ; rush
  (≈10 or/round en XP) → tier 5 en ~3-4 rounds ✓. **L'arbitrage XP-vs-unités-vs-reroll = le sel.**
- Au **niveau MAX**, l'XP n'accumule plus (barre pleine/masquée).

### 3.4 Reliques ±niveau de boutique *(nouveau, demandé)*
Nouvel op relique agissant sur le **`RunState`** (appliqué **au grant**, pas au build de combat) :
- **`shop_tier_up` (+1)** — « rush » : tier +1 immédiat. Relique **mi/tard** (offre-tier ≥ 3),
  **jamais offerte sur les ~2 premiers combats** (garde-fou anti-snowball « saute-la-synergie »).
- **`shop_tier_down` (-1, persistant)** — « densité » : décale les cotes **d'un tier vers le bas**
  (plus de rangs bas) tout en restant au tier payé → moteur à doublons (concentre les triples rank-1).

### 3.5 Slots — **inchangés**
Grants timés (`SLOT_GRANT_ROUNDS`, accept = +1 / decline = +or) **conservés tels quels**. Le niveau de
boutique est un **axe séparé** (cotes), découplé de la capacité (slots).

---

## 4. Pilier 2 — Re-tier du roster par complexité (New World Order)

**Principe (MTG « New World Order », repris par Riot) :** la complexité vit dans les **hauts rangs** ;
les communes sont des **stat-sticks grok-ables**. **Front-loader le NOMBRE** vers les bas rangs
(« une échelle a besoin de barreaux »).

### 4.1 Distribution cible (~83 unités, front-loadée) — calibrée sur les comparables
Comparables au **tier le plus bas** (par roster jouable) : **Super Auto Pets ~10-11** (réf du créateur,
coût plat + tier débloqué par tour), TFT 13, HS Battlegrounds ~16, Dota Underlords ~13 → genre = **~10-16
(~17-22 %)**. Cible **rank-1 ≈ 12** (ancrée SAP), pas 6-7 (boutique tier-1 trop répétitive) ni ~20 (excès).

| Rang | Actuel | **Cible** | Profil de complexité |
|---|---|---|---|
| **1** | 2 | **~12** | stat-sticks : « tape, ou tape + **micro-statut** (1 dps) ». **Zéro op neuf.** |
| 2 | ~11 | ~23 | enabler mono-DoT **simple** (1 affliction, pas de twist) |
| 3 | ~43 | ~18 | enabler + **1 petit modificateur** (éclate le bourrelet) |
| 4 | ~16 | ~20 | T2 twists, auras, tanks, choc avancé |
| 5 | 9 | ~10 | T3 transforms / règles d'équipe (déjà corrects) |

→ **Rank-1 = 8 existants promus** (la def « tape + petit burn » couvre les enablers à micro-chiffres :
`bandit, skeleton, marauder, demon, spore_tick, ash_moth, live_wire, carrion_pecker`) **+ ~4 neufs**
(micro-saignement, mur +PV, 2 brutes comblant les pôles `order`/`abyss`). Surtout du **re-labelling** des
79 par complexité. `rank` devient la **source de vérité** des cotes (pas `cost`).

### 4.2 Alignement `cost` ↔ `rank`
**`cost = rank`** (1:1) : rank-1 → 1 g … rank-5 → 5 g. Simplifie l'éco et la lecture (le prix EST le
rang). Beaucoup d'unités changent de coût (rebalance assumée).

### 4.3 Loi de puissance des doublons *(règle de design, demandée)*
> **Un rank-1 niveau 3 doit rivaliser, EN STATS BRUTES, avec un rank-3/4 niveau 1.** Le haut-tier garde
> son avantage **d'effet/utilité** (aura, transform, contagion), pas de stats.

- `LEVEL_MULT = {1.0, 1.8, 3.0}` (déjà en place) — un stat-stick rank-1 (ex. 32 PV / 6 dmg) niveau 3
  monte à ~96 PV / 18 dmg ≈ un rank-3/4 de base **en brut**, mais sans son effet. **Sain et voulu.**
- **Implication** : les stats de base des rank-1 doivent être réglées pour que `×3` = vraie carry
  (sinon « rester bas + tripler » est mort). À valider en `tools/sim.lua`.
- Légitime l'archétype **« wide-low, triple tout »** (synergie avec la relique -1 niveau).

### 4.4 Garde-fou de lisibilité
**Aucune relique/synergie ne doit faire qu'un rank-1 *surclasse le rôle* d'un rank-5** (Riot Dragonlands :
casser l'axiome « plus cher = plus fort » a « distordu la perception, les joueurs perdaient en se croyant
plus forts »). Stats brutes rivales = OK ; voler l'**identité d'effet** du haut-tier = interdit.

---

## 5. Pilier 3 — Reliques : cadence & bornage

### 5.1 Marchand tous les 3 combats *(victoire OU défaite)*
- Remplace le trigger actuel `wins % 3` par **`(combats joués) % 3`** → ~5-6 visites/run (vs 3).
- Écran `relicpick` **1-parmi-3** déjà codé ; ajouter **refuser → +or** (réutilise exactement le pattern
  accept/decline des grants de slot).
- Recherche : ce rythme est *« pile dans la bande saine »* (entre Hades trop fréquent et TFT 3/game).

### 5.2 Récompense au level-up d'unité *(Batomon, bornée — 1/round)*
- **Tout level-up** (fusion 3→niveau, cascade incluse) ouvre un choix **1-parmi-3**, mais **1 récompense
  max par round** (drapeau `relicFromLevelThisRound`, reset à `startRound`). Décision user (2026-06-23).
- **Borne l'exploit** acheter→fusionner→revendre : on ne farme qu'**1 relique/round** quoi qu'il arrive,
  et chaque trio coûte ~3-6 g → fair (TFT a dû patcher le reset buy/sell des Headliners, 14.2).

### 5.3 Offres de reliques **tiérées par avancée de run**
- Early (combats 1-4) : reliques **tier 1-2** (stats simples, universelles : `bloodstone`, `carapace`,
  `aegis`, `whetstone`).
- Tard : reliques **tier 3-4** (conditionnelles / build-definers : `plague_communion` « 2+ afflictions »,
  `everburn`, `forked_tongue`…). → le seuil « 2+ afflictions » arrive **quand tu as déjà 2+ afflictions**.
- Calque des **tiers d'augments TFT par stage** (Silver early → Prismatic late). Résout « universel vs
  late-spec » sans choisir : **universel tôt, conditionnel tard**.
- Toujours **3 choix + reroll/skip** ; une relique **engage un axe** (poison/saignement/choc), pas des
  stats génériques pures.

### 5.4 Garde-fous (recherche §9, pièges)
- Reliques **« saute-la-synergie » et +niveau-boutique OFF les ~2-3 premiers combats** (anti-snowball ;
  TFT a cappé ses augments « +1 trait » après désastre).
- Garder la rareté **atteignable** en fin de run (sinon on arrête de la chasser — Riot Set 1).

---

## 6. Pilier 4 — Doublons (DÉJÀ FAIT — référence)

`build.lua:checkMerges` : 3 copies (même `id`+`level`) → niveau+1 **auto à la pose**, **cascade**, **cap
3**, stats ×`{1.0, 1.8, 3.0}`. **On n'y touche pas.** Seul lien : la **loi de puissance §4.3** (régler les
stats de base rank-1) + la **récompense level-up §5.2**. *(Option cosmétique : merge au clic depuis le
bench sans poser — non prioritaire.)*

---

## 7. Intégration économique (synthèse des flux)

| Ressource | Source | Puits |
|---|---|---|
| **Or** | 10/round fixe + streak (cap 3) + decline-slot (+3) + **decline-relique (+N)** | unités (cost=rank) · reroll (1, +escalade?) · **montée de tier (4-10, remise auto)** |
| **Tier boutique** | montée payée · relique +1 | relique -1 (densité) |
| **Slots** | grants timés (rounds 2-7) | — (inchangé) |
| **Reliques** | marchand /3 combats · level-up (1/round) | (collection Grimoire, cross-run) |

*Option anti-spam* : reroll **1 g → 2 g** après 4 rerolls/round (Backpack) — à évaluer si le fuzz montre
du churn dégénéré. Le revenu fixe le borne déjà.

---

## 8. Plan d'implémentation (lots, chacun vert sur `tools/check.sh`)

> Convention git-warden : brancher chaque lot depuis `dev` (`feat/<slug>`), commit quand `check.sh` vert.
> i18n : clés d'unité dans **`src/i18n/en.lua`** (`unit.<id>.{name,passive_name,passive_desc}`) — couverture
> testée par `tests/i18n.lua` sur `Units.order`. Golden SIM (970156547) **doit rester inchangé** sauf
> rebaseline explicite (le re-tier est data neutre pour la SIM).

- **Lot 0 — Re-rank data.** `rank` sur les **79** (incl. 6 vanille), par complexité ; `cost = rank`.
  Test **DUR** : `for id in Units.order → assert Units[id].rank`. Golden neutre. *(SIM inchangée.)*
- **Lot 1 — Plancher rank-1.** Écrire ~17 stat-sticks (data + i18n) ; ajouter à `order`/`pool`.
  Couverture i18n. Régler les stats base pour la **loi §4.3** (1ᵉʳ passage sim).
- **Lot 2 — Niveau de boutique (RunState).** `shopTier`, `tierUpCost` (+remise auto), `roll()` lit la
  **table de cotes par rang**. Tests `tests/run.lua` : distribution par tier, remise, déterminisme, fuzz.
- **Lot 3 — UI boutique (`build.lua`).** Indicateur de tier + bouton **MONTER** (coût + remise) ; loger
  dans la colonne COMBAT/REROLL ou l'orbe. (RENDER, golden neutre.)
- **Lot 4 — Marchand /3 combats.** Trigger `combats % 3` (main.lua host) ; `relicpick` decline→or.
  Offres **tiérées par avancée** (§5.3). Tests routing.
- **Lot 5 — Récompense level-up bornée.** Drapeau `relicFromLevelThisRound` (reset à `startRound`) ;
  `build` détecte une fusion → si non-consommé ce round, route `relicpick`. Tests éco + cap 1/round.
- **Lot 6 — Reliques ±niveau + nouvelles.** Op `shop_tier_up/down` (applique au RunState au grant) ;
  2-3 reliques neuves (+i18n) ; gating early (§5.4). Tests `tests/relics.lua`.
- **Lot 7 — Passe d'équilibrage.** `tools/sim.lua` : régler cotes, coût de montée, stats rank-1, vérifier
  la **loi §4.3** (low-tier lvl3 ≈ mid-tier lvl1) et l'absence de snowball. Tuner **un levier à la fois**.

---

## 9. Risques & questions ouvertes
- **R1 — Boutique payée + run court** : si monter est trop cher, personne ne dépasse tier 2. *Mitig.* :
  remise auto agressive + coûts bas ; valider que tier 4-5 est atteint vers 70 % de la run.
- **R2 — Loi des doublons trop forte** : un rank-1 lvl-3 qui *surclasse* (pas juste rivalise) casse la
  lisibilité (§4.4). *Mitig.* : sim, plafonner si besoin.
- **R3 — Level-up reward** : cap **1/round** (décidé). Surveiller au fuzz que ce n'est pas trop généreux
  (sinon resserrer à « premières-fois de run »).
- **R4 — Re-tier = gros diff data** : beaucoup de coûts changent → re-tuning. Fait par lots + sim.
- **Q ouverte** : faut-il un **reroll escaladant** (1→2 g) ? (décidé au fuzz du Lot 2/7.)

---

## 10. Références (recherche 2026-06-23)
- Cotes boutique & tailles de pool TFT : metatft.com/tables/shop-odds · XP/leveling : LoL Wiki (TFT XP),
  blitz.gg/tft/guides/gold
- Tiers de taverne HS Battlegrounds (coût de montée + remise auto) : hearthstone.wiki.gg/Battlegrounds/Tavern_Tier
- Complexité par rareté (New World Order) : gamedeveloper.com « Card Games — A Simple Design is a Good
  Design » ; « ladders need rungs » : fischerdesign.medium.com (Artifact vs Auto Chess)
- Riot dev blogs (complexité haut-rang, augments par stage, +1-trait cappé, axiome « plus cher = plus
  fort ») : teamfighttactics.leagueoflegends.com/news/dev/ (Set 1, Dragonlands, Runeterra Reforged,
  Inkborn Fables, Magic n' Mayhem, Design Pillars)
- Boucle d'addiction / near-miss sous agence : Clark 2009 (Neuron) ; psycho roguelikes : polygon.com
- Augments/boons/Backpack : Hades (miguelmarinheiro.com) ; Backpack Battles wiki (rareté par round, skills
  aux niveaux 4/10) ; anti-snowball : sirlin.net (Slippery Slope), waywardstrategy.com
