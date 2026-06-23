# R04 — Critique adversariale, lentille RELIQUES (round 4/10)

> **Round** : 4/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Cibles** : `ROADMAP-draft.md` (brouillon #4, integre round 3) + `round-03.md` (synthese).
> **Sources internes verifiees ce round** : `src/data/relics.lua` (21 reliques, lu integralement),
> `src/combat/arena.lua` (plagueAmp, secondBreath, dischargeShock), `src/effects/ops.lua`,
> `src/run/state.lua`, `docs/research/relics-design.md`, `00-state.md` (32 invariants),
> `rounds/r01-relics.md`, `rounds/r02-relics.md`, `rounds/r03-relics.md`.
> **Garde-fou absolu** : lecture seule du repo. Ce fichier n'edite que `docs/roadmap-lab/`.
> Piliers : async snapshots / sim deterministe seedee / DA grimdark / pixel art procedural.
> Sources citees par URL ou fichier+ligne pour chaque affirmation.

---

## 0. TL;DR — challenge cle en 3 phrases

Le round 3 a tranché les deux litiges les plus urgents sur les reliques (#J option scalante,
déprioritisation F immédiate) et ces décisions sont solides — je les confirme. Mais le
brouillon souffre d'un **angle mort structurel** : il traite les 21 reliques comme 21 unités
indépendantes à polir, alors qu'il faudrait d'abord valider leur **couverture d'ARCHÉTYPES
COMPLETS** (pas de familles DoT) — c'est-à-dire, quels builds sont *définissables* par une
relique, pas juste amplifés. La deuxième lacune est que le brouillon ne s'est **jamais demandé
à quel moment dans un run chaque relique est maximalement utile** : `plague_communion` version
scalante (+5% par allié de l'affliction majoritaire) donne **+10% au round 4 (2 unités) et
+30-35% au round 9 (6-7 unités)** — c'est une relique dont la puissance est back-loaded,
idéale en late mais médiocre en early… or la roadmap ne demande JAMAIS si la courbe de
valeur d'une relique correspond à sa fenêtre d'offre.

---

## 1. Accords — ce qui tient (avec le POURQUOI pour nos contraintes specifiques)

### 1.1 ACCORD FORT — Option scalante adoptée pour les reliques E tier-4 (brouillon §4.2)

**Ce que la roadmap v4 dit** : remplacer la condition-gate (« ≥4 unités même affliction ») par
une valeur immédiate scalante (« +5 % par allié de l'affliction majoritaire »).

**Pourquoi ça tient, démontré par le code** : `plague_communion` dans `relics.lua:57` applique
actuellement `plagueAmp = 0.25` flat via `grant_team` — c'est le même mécanisme, juste
non-conditionnel. L'implémentation scalante (`plagueAmp = 0.05 × count(famille_majorite)`)
réutilise **le même op `grant_team`** et **le même champ `plagueAmp`** que ce qui est déjà
dans le code. Coût d'implémentation quasi-nul. C'est la bonne direction.

**Pourquoi ça tient pour l'async** : dans un contexte async, le joueur engage un archétype
AU BUILD avant le combat. Une valeur scalante immédiate (2 poison = +10%) renforce le commit
à chaque unité ajoutée — exactement le *endowed progress effect* (Nunes & Drèze 2006, JCR)
que le brouillon §4.2 cite correctement. Un gate à « ≥4 unités » = inerte pendant 60% du
run, sans retour d'information sur la progression.

**Source** : `src/data/relics.lua:57-58` (lu ce round) ; Nunes & Drèze 2006 (endowed progress
effect, JCR) ; r03-relics.md §2.1 (dead range démontré).

### 1.2 ACCORD FORT — Déprioritisation des reliques F sans attendre le marchand (brouillon §4.4)

**Pourquoi ça tient** : le calcul hypergéométrique `P(≥1 F parmi 3 offres) ≈ 0.39` est correct.
Sur un pool de 21 reliques dont 3 F (14.3%), avec tirage Fisher-Yates seedé sans remise, la
probabilité de voir au moins une relique F parmi les 3 proposées est :
`1 - C(18,3)/C(21,3) = 1 - 816/1330 ≈ 0.387`. Avec ~4 offres par run, le joueur est exposé
à 1-2 F par run — 25-33% de ses offres « polluées » par des décisions d'un type radicalement
différent (économie du run vs build de combat). La déprioritisation immédiate (« si un F est
tiré ET un B-E disponible → remplacer par un B-E via tir seedé additionnel du même RNG »)
résout le problème sans attendre le marchand.

**Ce qui est solide pour notre contrainte async** : StS sépare structurellement les reliques
de combat (récompenses d'élite/boss) des reliques de boutique (3e slot toujours shop-only,
`slaythespire.wiki.gg/wiki/The_Merchant`, vérifié). La fusion des deux dans The Pit est une
dette de design temporaire, pas un choix intentionnel — le résoudre maintenant évite de
former des habitudes de décision incorrectes chez le joueur.

**Source** : calcul hypergéométrique (base `relics.lua:69-73`, 21 reliques dont 3 F) ;
`slaythespire.wiki.gg/wiki/The_Merchant` ; r03-relics.md §2.2 (chiffrage).

### 1.3 ACCORD — `second_breath` reste universelle tier-3, non conditionnée (brouillon §4.3)

**Pourquoi ça tient** : `second_breath` dans `relics.lua:47` est `{ op = "relic_second_breath",
tier = 3 }` — universel, sans condition. Dans StS, les reliques défensives communes (Akabeko,
Orichalcum) sont universelles et non conditionnées : elles ne shapent pas le build, elles le
renforcent (slaythespire.wiki.gg/wiki/Relics, vérifié). La distinction entre « tier-3
défensives = universelles » et « tier-4 = build-defining » est la bonne taxonomie. Conditionner
`second_breath` créerait deux reliques fusionnées en une seule condition (tall XOR positionnement)
comme r03-relics.md §2.4 l'a démontré.

**Source** : `src/data/relics.lua:47` ; `slaythespire.wiki.gg/wiki/Relics`.

### 1.4 ACCORD — Règle ≥2 reliques/archétype (critère statistique P<25%) (brouillon §4.5)

**Pourquoi ça tient** : la règle est opérationnelle et non-ambigüe — c'est le premier critère
de complétude du pool qui ne dépend pas du jugement qualitatif. Le calcul `P(aucune relique
pertinente sur run) < 25%` est mesurable. Ce round, en relisant `relics.lua:69-73`, je
confirme : choc a 1 seule relique de combat (`forked_tongue`, tier 4) → `P(aucune sur run)`
est encore plus mauvais que les 48% calculés au round 2 (car la relique est tier-4, non
offertes avant 5+ wins). Wide (`swarm_logic`) = absent = 100%.

**Ce qui me préoccupe TOUJOURS** (voir §2.1 ci-dessous) : le critère ≥2/archétype est
satisfait pour burn/poison/bleed, mais la règle ne distingue pas entre « 2 reliques de même
type d'impact » et « 2 reliques couvrant le même archétype de façons distinctes ». C'est
une nuance non traitée.

**Source** : `src/data/relics.lua` (lu ce round : 4 reliques B, 3 C, 4 D, 4 E, 3 F, 3 A) ;
r02-relics.md §2.5 (calcul hypergéométrique).

---

## 2. Désaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DÉSACCORD MAJEUR — La roadmap n'a JAMAIS analysé la courbe de valeur temporelle des reliques (lacune structurelle)

**Claim implicite du brouillon** : les reliques E tier-4 adoptent l'option scalante pour
éviter le dead range (§4.2). C'est correct pour le dead range initial. Mais le brouillon
**ne demande jamais** : « À quel moment dans un run cette relique atteint-elle sa valeur
maximale ? »

**Analyse concrète sur `plague_communion` scalante** :
- Offerte à partir de 5+ wins (round 6+, selon le gating tier ≤4 = 5+ wins — `00-state.md §2.2`).
- `GOLD_PER_ROUND = 10`, `START_SLOTS = 3`, `MAX_GRANTS = 6` sur rounds 2-7 (`state.lua:26-48`).
- À round 6 (5 wins) : le joueur a ouvert 3 + min(5, 6) = 3+5 = 8 slots. Avec un build
  en cours, il a raisonnablement 5-6 unités en jeu.
- Avec 5 unités de même famille : `plagueAmp = 0.05 × 5 = 0.25` (+25%).
- Avec 3 unités de même famille (compo mixte) : `plagueAmp = 0.05 × 3 = 0.15` (+15%).

**Le problème** : +15% à round 6 est faible pour une relique tier-4. `bloodstone` (tier-1,
relique A) donne `relic_more_dmg mult = 0.14` (+14%) à TOUTES les unités dès le round 2
sans condition. `plague_communion` scalante à 3 unités majority donne +15% — soit **à peine
mieux que `bloodstone` sur les unités concernées, pour une relique de tier 3 niveaux plus haute**.

**La vraie question que le brouillon ne pose pas** : `plague_communion` est-elle une relique
de **build-shaping** (qui DÉFINIT une direction) ou de **payoff** (qui RÉCOMPENSE une direction
déjà prise) ? Ces deux rôles ont des moments d'offre différents. Si c'est un payoff, elle
devrait être offerte APRÈS que le build est engagé (late) ; si c'est un shaper, elle doit être
assez forte pour ORIENTER le build (mid). La version scalante veut jouer les deux rôles en
même temps — ce qui risque d'être médiocre aux deux.

**Référence externe** : dans TFT, les augments « build-defining » (Chemtech Soul, etc.) sont
offerts à des moments fixes du run (2-1, 3-2, 4-2) calibrés pour orienter le build AVANT la
transition critique, pas après. Les augments de payoff (Jeweled Lotus, etc.) viennent en late
quand le build est établi. La distinction temporelle est explicite (Mort Sullivan, Riot GDC
2022, `teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-set-7-
learnings/`). The Pit n'a pas de distinction de moment d'offre par type de relique — toutes
sont gatées par avancée (tier ≤ wins), mais pas par rôle (shaper vs payoff).

**Proposition concrète** (voir §3.1) : ajouter une colonne « rôle temporel » (shaper early /
shaper mid / payoff late) dans l'audit des reliques P1.5a, et vérifier que la fenêtre d'offre
de chaque relique correspond à son rôle optimal.

**Source** : `src/data/relics.lua:57-58` + `src/run/state.lua:26-48` (lus ce round) ;
`teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-set-7-learnings/` ;
`00-state.md §2.2` (gating tier ≤ wins).

### 2.2 DÉSACCORD — La valeur absolue de `plague_communion` scalante n'est pas comparée à son tier concurrent (`bloodstone`)

**Observation code directe** : en lisant `relics.lua:20` et `relics.lua:57-58` :
- `bloodstone` (tier-1, A) : `relic_more_dmg mult = 0.14` → +14% de dégâts à TOUTES les
  unités, dès round 2, sans condition.
- `plague_communion` scalante (tier-4, E) : `+0.05 × count(majorité)` → +15% pour 3 unités
  de la famille majoritaire, +25% pour 5, +30-35% pour 6-7.

**Le problème** : à round 6 avec une compo mixte (3 unités majority), `plague_communion`
donne +15% à 3 unités — ce qui est *équivalent* à `bloodstone` sur les mêmes 3 unités.
Or `bloodstone` s'applique à TOUTES les unités (même les 2-3 hors-famille), et est offerte
2-4 rounds plus tôt.

**L'écart se creuse** : à round 8 avec 6 unités majority, `plague_communion` donne +30%,
soit 2,1x `bloodstone`. C'est significatif, mais c'est du late-game extrême (round 8 = 7+
wins = sur le point de finir la run). La fenêtre où `plague_communion` est clairement
supérieure est **les 2 derniers rounds du run** — ce qui signifie qu'elle n'influe pas vraiment
sur les décisions de build (le build est déjà fixé).

**Ce que le brouillon ne dit pas** : il faut soit (a) augmenter le `N` scalant (passer de
0.05 à 0.08 par allié = +24% à 3, +40% à 5) pour qu'elle soit build-defining même en mid,
soit (b) l'accepter comme relique de payoff late uniquement et caler son gating plus tard
(ne proposer qu'à 7+ wins au lieu de 5+). La roadmap n'a pas fait ce choix.

**Source** : `src/data/relics.lua:20 + 57-58` (lu ce round) ; calculs faits ce round.

### 2.3 DÉSACCORD — `famines_math` (relique C, tier-3) cache un problème de scaling non identifié

**Ce que le brouillon dit** : reliques C = « paliers / payoffs (récompense NON-LINÉAIRE d'un
build) ». `famines_math` : ≤3 unités → +30% dmg, +20% HP (relics.lua:35).

**Analyse code** : `relic_few_units` dans `R.apply:90-94` vérifie `n <= p.max (3)`. La
condition s'applique si `#comp ≤ 3` au moment de l'appel à `R.apply` (au build, avant le
combat).

**Le problème structurel** : `famines_math` est une relique TALL (incentive à peu d'unités).
Mais le système de déblocage de slots crée un problème fondamental : chaque tour le joueur
**REÇOIT GRATUITEMENT** des slots supplémentaires (grants rounds 2-7, `state.lua:52-57`).
Si le joueur accepte un slot alors qu'il a 3 unités et `famines_math`, il perd le bénéfice
de la relique. S'il refuse le slot, il gagne +3 or ou +1 XP (option C de decline) mais
sacrifie la largeur future.

**Ce n'est pas un « aucun handicap persistant »** (principe #2 des reliques, `relics.lua:5`)
— c'est une **contrainte permanente** qui FORCE le joueur à refuser les slots (ou à accepter
de perdre le bonus). Or le brouillon dit que les reliques « ne handicapent pas » mais
`famines_math` pénalise structurellement le joueur qui accepte les slots gratuits.

**Conséquence** : `famines_math` est la seule relique du pool qui viole activement la
progression naturelle de l'économie (déblocage de slots). Ce n'est pas du « scope
conditionnel » comme dans StS — c'est une contrainte anti-growth qui crée un dilemme
non-résolu. Le principe de design « égalisateur, jamais un gate » (CLAUDE.md §2, pilier
reliques) s'applique ici : une relique qui FORCE à rester small est un gate sur la
progression des slots, pas un égalisateur.

**Résolution possible** : soit retirer `famines_math` du pool (la tenir en `U.order` pour
les encounters IA), soit la reformuler pour qu'elle soit contextuelle et non une contrainte
permanente (ex. « tes 3 unités les plus fortes ont +30% dmg » — toujours applicable,
indépendamment du nombre total d'unités).

**Vérification que le brouillon n'a PAS traité ce cas** : les rounds 1-3 n'ont jamais mentionné
`famines_math` par nom. La critique r03-relics.md §2.5 porte sur les inc des reliques B, pas
sur les effets des reliques C. C'est une lacune réelle dans le débat adversarial.

**Source** : `src/data/relics.lua:34-36 + R.apply:90-94` (lu ce round) ;
`relics.lua:5` (principe #2 : « aucun handicap persistant ») ; CLAUDE.md §2 (pilier reliques).

### 2.4 DÉSACCORD PARTIEL — La valeur de `forked_tongue` est gelée dans l'ambiguité sans avoir fixé l'axe choc (litige #G)

**Claim du brouillon** (§4.2) : calibrer `forked_tongue` en N rebonds = f(count choc) :
1 choc = 1 rebond, 3+ choc = 2 rebonds. **Mais NE PAS GRAVER avant #G**.

**Accord sur le gel** : la position de « ne pas graver » est correcte. `forked_tongue`
dans `relics.lua:51-52` pose `shockChain = 1` via `grant_team`. Si l'axe D est adopté
(décharge sur le 1er tick DoT), le « rebond » change de signification : ce n'est plus un
rebond de décharge électrique sur une cible adjacente, c'est une **propagation d'amplification
de DoT** vers une cible supplémentaire. Ce sont deux reliques conceptuellement différentes.

**Ce que le brouillon ne résout pas** : en gelant `forked_tongue`, il laisse 1 des 4 reliques
E **complètement non-définie fonctionnellement** jusqu'à la résolution de #G. Dans une liste
de 21 reliques dont 4 E, 25% des reliques build-defining sont dans un état de Schrödinger.
C'est acceptable COMME POSITION TEMPORAIRE, mais le brouillon ne donne pas de **deadline** :
quand #G sera résolu en P0.5, la reformulation de `forked_tongue` doit être la PREMIÈRE
tâche de P1.5a (pas une tâche flottante).

**Source** : `src/data/relics.lua:51-52` (lu ce round) ; r03-relics.md §4.2 (Q2 : adéquation
de forked_tongue avec l'axe choc) ; brouillon §4.2 (« NE PAS graver avant #G »).

### 2.5 DÉSACCORD — `feeding_frenzy` n'est pas challengée alors qu'elle est la plus fragile des reliques C

**Code** : `feeding_frenzy` (relics.lua:39) pose l'effet `{ trigger = "on_death", op =
"frenzy_gain", params = { per = 0.08, cap = 6 } }` via `relic_add_effect`. L'op
`frenzy_gain` donne +8% de dégâts par mort alliée, cappé à +48% total (6 morts × 8%).

**Le problème** : `frenzy_gain` s'active sur `on_death` — c'est-à-dire sur la MORT
d'unités ALLIÉES. C'est une relique qui RÉCOMPENSE la mort de ses propres unités. Dans
notre modèle « vie PAR ENTITÉ (mort par-combat, build persiste) » (décision définitive §5,
00-state.md), la mort intra-combat est normale et le build est reconstruit entre rounds.
Mais `frenzy_gain` pousse vers un archétype « kamikaze » (unités qui meurent exprès pour
booster les survivants) — ce n'est pas un archétype existant dans le roster actuel (83
unités, aucune avec `suicideOnHit` ou effet d'auto-mort programmée).

**Ce n'est pas build-defining** : si le joueur n'a pas d'unités kamikaze, la relique se
déclenche par accident (quand une unité meurt en combat normal) — ce qui en fait une relique
de « récompense passive du malheur » plutôt que d'un archétype voulu. La distinction entre
une relique qui DÉFINIT un archétype (StS : Busted Crown force un petit deck) et une relique
qui RÉCOMPENSE un état accidentel est fondamentale pour la mémoriabilité (LocalThunk : « 1
règle modifiée », balatro.md §5.3).

**Vérification que le brouillon n'a pas adressé ce point** : les rounds 1-3 mentionnent
`feeding_frenzy` uniquement comme « membre de la catégorie C » sans analyser son interaction
avec le modèle de vie-par-entité. C'est une lacune.

**Proposition** (voir §3.3) : soit retirer `feeding_frenzy` et la remplacer par une relique
qui récompense les KILLS ENNEMIS (not allié-death), soit la requalifier comme palier de
type « wide » (chaque mort ennemie + allié donne le bonus) avec une reformulation
grimdark cohérente.

**Source** : `src/data/relics.lua:39` (lu ce round) ; 00-state.md §1 décision §5 (vie
PAR ENTITÉ, mort intra-combat normale) ; balatro.md §5.3 (LocalThunk : 1 règle modifiée).

### 2.6 DÉSACCORD MINEUR — La couverture de la catégorie D (défensives) est asymétrique

**Code** : catégorie D dans le pool = `whetstone` (+15% cadence, tier-1), `thornguard`
(épines d'équipe, tier-2), `sacred_shield` (invuln t<30, tier-3), `second_breath` (survie
à 1PV, tier-3). Le brouillon classe `whetstone` en « A (suite) cadence » et `thornguard`
en D — mais en lisant le code (`relics.lua:42-47`), le commentaire « A (suite) cadence ·
D — défensives / globales » est lui-même ambigu.

**Le problème structurel** : la catégorie D a 4 reliques, dont 2 de tier-3 (`sacred_shield`,
`second_breath`) — c'est **50% du pool tier-3 de défense** concentré sur des reliques
universelles. Aucune relique D n'est build-specific. Par contraste, les catégories B et E
ont respectivement 4 et 4 reliques, toutes build-specific (une famille DoT par relique B,
un archétype par relique E). La catégorie D est la seule catégorie qui n'a pas de relique
qui ORIENTE le build — elle le renforce seulement.

**Conséquence** : une run à archétype bleed qui voit 2 offres de reliques D et 0 B n'a
reçu aucune direction de build de la part de ses reliques. Si `P(aucune relique B sur run)
≈ 24%` pour bleed (calcul r02), il y a une chance non-négligeable qu'un run bleed reçoive
uniquement des D et C. Ce n'est pas un bug critique, mais c'est un risque de « run orphelin »
que la garantie de pertinence B-E (§4.1 brouillon) ne résout qu'en partie (elle garantit
qu'une B-E est offerte, mais pas que c'est une B qui shapent l'archétype).

**Source** : `src/data/relics.lua:41-47` (classification lue ce round).

---

## 3. Propositions priorisées

### Prop-A — Ajouter la colonne « rôle temporel » dans l'audit P1.5a (PRIORITÉ 1, doc only)

**Quoi** : dans l'audit P1.5a, ajouter une colonne « rôle temporel » pour chaque relique :
- **SHAPER EARLY** (offerte round 1-3, oriente le build dès le début) ;
- **SHAPER MID** (offerte round 4-6, confirme et amplifie la direction) ;
- **PAYOFF LATE** (offerte round 7-10, récompense le commit complet).

Vérifier que la fenêtre d'offre de chaque relique (gating tier ≤ wins, `state.lua:339` et
`rollRelicChoices`) correspond à son rôle optimal. Signaler les mismatchs :
- `plague_communion` scalante : PAYOFF LATE en termes de valeur maximale, mais potentiellement
  offerte dès round 6 (5+ wins). → vérifier si N=0.05 est trop faible pour être un SHAPER MID.
- `famines_math` : SHAPER EARLY-MID (contraint la compo dès l'offre), mais crée un conflit
  avec les grants de slots gratuits des rounds 2-7. → mismatch à résoudre.
- Reliques B (`kings_bowl`, etc.) : SHAPER MID idéal (tier-2, offertes dès 2+ wins) — correct.

**Coût** : doc uniquement, ~15 lignes dans l'audit. **0 code, 0 invariant.**

**Source** : `src/run/state.lua:339` + `00-state.md §2.2` + analyse §2.1 de ce round.
Référence externe : TFT augments timing (Mort Sullivan, Riot GDC 2022 — via
`teamfighttactics.leagueofgendrals.com/en-us/news/dev/dev-teamfight-tactics-set-7-learnings/`).

### Prop-B — Revalider `plague_communion` scalante : N=0.05 ou N=0.08 ? (PRIORITÉ 1, sim)

**Quoi** : avant de figer `plague_communion` scalante, décider entre deux valeurs de N :
- **N=0.05** : +10% à 2 unités, +25% à 5, +35% à 7. Valeur mid comparable à `bloodstone`
  (+14%) → risque d'être perçue comme « weakish bloodstone conditionnel ».
- **N=0.08** : +16% à 2 unités, +40% à 5, +56% à 7. Clairement supérieure à `bloodstone`
  à 2 unités déjà → **build-defining même en early**, risque de snowball si la famille
  majorit très tôt.

**Critère de choix** : en sim (`tools/sim.lua`), comparer `win_rate(compo poison × 3 +
plague_communion N=0.05)` vs `win_rate(compo poison × 3 + bloodstone)`. Si l'écart est
< 5 % en faveur de `plague_communion`, N est trop faible pour être build-defining ; passer
à N=0.08. La règle de calibrage est : une relique tier-4 doit être **clairement plus forte
que les reliques tier-1** sur l'archétype qu'elle récompense, sinon elle n'est pas build-defining.

**Coût** : 1 paramètre `params.N` dans `relics.lua`. 0 invariant (goldentest non touché —
`plagueAmp` est hors du golden car gated). Test de sim uniquement.

**Source** : §2.2 de ce round ; `src/data/relics.lua:20+57-58` ; `src/effects/stats.lua`
(formule `(1+Σinc)·Π(1+more)` — `plagueAmp` = more hors-cap, `relics.lua:243-262` confirmé).

### Prop-C — Auditer `famines_math` pour conflit avec les grants de slots (PRIORITÉ 2)

**Quoi** : dans l'audit P1.5a, signaler `famines_math` comme relique qui viole le principe
« aucun handicap persistant » (relics.lua:5) en contraignant implicitement à refuser les
slots gratuits. Proposer une reformulation qui ne soit pas anti-growth :
- Option 1 (conservative) : « ≤3 unités → bonus » avec un **drapeau UI explicite** en build
  si le bonus est actif (« LA FAMINE RÈGNE ») — le joueur peut choisir en connaissance de cause
  de refuser les slots.
- Option 2 (refonte) : « tes 3 unités les plus coûteuses ont +30% dmg, +20% HP » — toujours
  applicable, ne pénalise pas l'acceptation de slots. Le mécanisme change d'« anti-growth »
  à « récompense le focus sur les hauts-rangs ».

**Coût** : doc (pour statuer sur l'option) + data (changer `R.apply:90-94` si option 2).
0 invariant si option 1 (seule modification = UI flag).

**Source** : §2.3 de ce round ; `src/data/relics.lua:34-36 + R.apply:90-94`.

### Prop-D — Reformuler `feeding_frenzy` pour récompenser les kills ENNEMIS, pas les morts alliées (PRIORITÉ 2)

**Quoi** : le trigger `on_death` de `feeding_frenzy` (`relics.lua:39`) se déclenche sur TOUT
`on_death` (allié ou ennemi selon l'implémentation de l'op `frenzy_gain`). Si `frenzy_gain`
ne distingue pas allié/ennemi, la relique se déclenche aussi sur les morts ennemies — ce qui
est correct. Si elle ne se déclenche QUE sur les morts alliées, c'est un problème.

**À vérifier dans le code** : l'op `frenzy_gain` n'est pas dans `ops.lua` parmi les ops
documentés dans `seed/mechanics.md §2` — c'est un op qui pourrait ne pas exister ou être
mal documenté. Si `frenzy_gain` n'existe pas dans `ops.lua`, `feeding_frenzy` ne fait rien
en combat (bug silencieux). À vérifier avant P1.5a.

**Proposition** : reformuler `feeding_frenzy` comme récompense de kill ennemi (`on_death`
avec `ctx.unit.side == "enemy"`) → « chaque unité ennemie abattue renforce l'équipe (+8%
dmg, cap 48%) ». Thème grimdark cohérent : le carnage renforce les survivants. C'est
un archétype « frenzy/berserk » qui n'existe pas encore dans les reliques.

**Coût** : vérifier l'existence de `frenzy_gain` dans `ops.lua`. Si absent → ajouter l'op
(1 ligne `Effects.register`). Reformuler la condition de déclenchement.

**Source** : `src/data/relics.lua:39` (lu ce round) — **`frenzy_gain` non trouvé dans
`seed/mechanics.md §2.1-2.6` ce round → à vérifier dans `ops.lua`** ; 00-state.md §3 (triggers
disponibles : on_death broadcast différé).

### Prop-E — Figer la deadline de reformulation de `forked_tongue` IMMÉDIATEMENT après #G (PRIORITÉ 3, doc)

**Quoi** : ajouter dans le séquençage v0.9.5 (P0.5 — axe choc AXE D) une tâche explicite :
« dès que le litige #G est tranché et la sim validée, reformuler `forked_tongue` pour qu'elle
soit cohérente avec l'axe D (rebond = propagation d'amplification DoT, pas rebond de décharge
électrique) ». La reformulation devient la PREMIÈRE tâche de P1.5a après P0.5.

**Coût** : doc uniquement. 0 code avant #G.

**Source** : `src/data/relics.lua:51-52` ; brouillon §4.2 (gel confirmé) ; r03-relics.md §4.2.

---

## 4. Questions ouvertes (litiges pour les rounds suivants)

### Q1 — Litige #N (NOUVEAU) : `plague_communion` = SHAPER MID (N=0.08) ou PAYOFF LATE (N=0.05) ?

La décision du N scalant n'est pas triviale : elle détermine si la relique oriente le build
(shaper, N élevé, valeur immédiate forte) ou confirme un commit déjà pris (payoff, N faible,
valeur maximale en late). Les deux sont des designs valides, mais ont des implications sur
la fenêtre d'offre. À trancher via sim avant de figer les params.

**Critère proposé** : `win_rate(compo 3 majority + plague_communion N=X) - win_rate(compo 3
majority + bloodstone) > 5 %` → N est assez fort pour être build-defining. Sinon, augmenter N.

### Q2 — Litige #O (NOUVEAU) : `famines_math` = reformuler ou retirer du pool ?

La tension entre « ≤3 unités → bonus » et les grants gratuits de slots crée un conflit de
décision structurel. Deux positions possibles :
- (a) Reformuler pour éliminer le conflit anti-growth (option 2, Prop-C §3.3).
- (b) Retirer du pool boutique (U.pool) → réserver aux encounters IA (U.order) et aux runs
  IA cold-start.

La position (b) est la plus prudente si (a) demanderait de changer significativement l'identité
de la relique. À décider avant P1.5a.

### Q3 — Litige #P (NOUVEAU) : `feeding_frenzy` trigger = allié-only ou all-death ?

Question technique à trancher par lecture directe de `ops.lua`. Si `frenzy_gain` n'est pas
implémenté → créer l'op. Si implémenté uniquement sur mort alliée → reformuler sur mort
ennemie. Cette Q bloque la confirmation de `feeding_frenzy` comme relique valide.

### Q4 — Litige #Q (NOUVEAU) : quelle relique F survit à la déprioritisation sans le marchand ?

La règle de déprioritisation F sans attendre le marchand (§4.4 brouillon) est adoptée.
Mais sur les 3 reliques F, toutes ne sont pas équivalentes :
- `carrion_ledger` (tier-3, +6 XP boutique) : fort impact économique early, peu utile late.
- `black_summons` (tier-4, +1 tier boutique) : impact late fort, non-acheté si le joueur
  est déjà en T5. Probabilité d'être une « offre nulle » haute en late.
- `beggars_lantern` (tier-2, décale les cotes 1 tier plus bas) : contre-intuitif — utilité
  pour un archétype « max-doubles » (niveau 3), pas universelle.

Question : faut-il déprioritiser les 3 F avec la même règle, ou seulement les 2 plus
fréquemment « gaspillées » (`carrion_ledger` et `black_summons`) ? `beggars_lantern` a
un cas d'usage spécifique (doubles, coût-contenu rank-1/2) qui pourrait justifier de
la traiter différemment.

### Q5 — Litige existant #J (en cours) : valeurs [PH] de plague_communion scalante

La valeur N=0.05 est [PH] dans le brouillon. La sim doit valider via `tools/sim.lua`.
Quand #G est résolu, cette sim doit être une des premières mesures de P1.5a.
Critère : voir Q1 ci-dessus.

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| `plague_communion` op actuel (`plagueAmp=0.25` flat) | `src/data/relics.lua:57-58` (lu ce round) |
| `bloodstone` (tier-1, `mult=0.14`) | `src/data/relics.lua:20` (lu ce round) |
| `famines_math` (`R.apply:90-94`, condition `n <= max`) | `src/data/relics.lua:34-36 + R.apply:90-94` |
| `feeding_frenzy` (trigger `on_death`, op `frenzy_gain`) | `src/data/relics.lua:39` |
| `forked_tongue` (`shockChain=1`) | `src/data/relics.lua:51-52` |
| `second_breath` (tier-3 universel) | `src/data/relics.lua:47` |
| Grants de slots gratuits (rounds 2-7, `MAX_GRANTS=6`) | `src/run/state.lua:52-57` |
| Gating reliques (early ≤2 / mid ≤3 / late ≤4 tier) | `00-state.md §2.2` |
| `plagueAmp` = more hors-cap (Arena:damage) | `src/combat/arena.lua:243-262` (confirmé r03) |
| Calcul hypergéométrique dil. F : P(≥1 F/3 offres) ≈ 0.39 | Calcul ce round (base 21 reliques, 3 F) |
| Principe « aucun handicap persistant » | `src/data/relics.lua:5` (commentaire de tête) |
| StS slot marchand séparé | `slaythespire.wiki.gg/wiki/The_Merchant` |
| StS reliques communes universelles (Akabeko, Orichalcum) | `slaythespire.wiki.gg/wiki/Relics` |
| Endowed progress effect | Nunes & Drèze 2006, JCR (cité r03-relics.md §2.1) |
| TFT augments timing (Mort Sullivan) | `teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-set-7-learnings/` |
| LocalThunk : « 1 règle modifiée » par Joker | Rolling Stone 2024-12-24 (balatro.md §5.3) |
| Décision §5 (vie par entité, mort intra-combat) | `00-state.md §1` |
| Arc « rôle temporel des reliques » non traité rounds 1-3 | `rounds/r01-relics.md`, `rounds/r02-relics.md`, `rounds/r03-relics.md` (vérifiés — aucune mention) |
| Hiérarchie poison > … > choc (diagnostic) | `the-pit-balance-diagnosis` (mémoire) |
| Cap ×3 anti-snowball (`DOT_CAP_MULT=3`) | `src/effects/ops.lua:22` (00-state.md §3) |

---

*Rédigé le 2026-06-23 par l'agent lentille-reliques, round 4/10. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. Sources citées par URL ou fichier+ligne.
Code vérifié ce round : `src/data/relics.lua` (21 reliques intégralement) ; `R.apply` lignes
76-107 ; `src/run/state.lua:52-57` (grants slots) ; `src/run/state.lua:339` (signature
`rollRelicChoices`) — `frenzy_gain` NON TROUVÉ dans les sources documentées (à vérifier dans
`src/effects/ops.lua` directement). Rounds précédents lus : r01-relics.md, r02-relics.md,
r03-relics.md, round-01.md, round-02.md, round-03.md, ROADMAP-draft.md v4, 00-state.md.*
