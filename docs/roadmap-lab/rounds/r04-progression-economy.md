# Round 04 — Critique adversariale : Progression & Économie

> **Lentille** : progression-economy — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v4, intégré round 3) et des
> rapports `rounds/r03-progression-economy.md`, `rounds/r02-progression-economy.md`,
> `rounds/r01-progression-economy.md`, ainsi que de la synthèse `round-03.md`.
> Accords argumentés / désaccords sourcés / propositions concrètes, chiffrées, priorisées.
> Aucune modification du code du jeu.
>
> **Sources primaires relues** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v4, `docs/roadmap-lab/00-state.md`,
>   `docs/roadmap-lab/round-01.md`, `docs/roadmap-lab/round-02.md`, `docs/roadmap-lab/round-03.md`,
>   `docs/roadmap-lab/rounds/r01-progression-economy.md`,
>   `docs/roadmap-lab/rounds/r02-progression-economy.md`,
>   `docs/roadmap-lab/rounds/r03-progression-economy.md`,
>   `docs/research/progression-economy-prd.md`.
> - `src/run/state.lua` (lu pour ancrage des constantes exactes).
> - Concurrence : `competitive/super-auto-pets.md`, `competitive/tft.md`, `competitive/balatro.md`,
>   `competitive/hs-battlegrounds.md`, `competitive/backpack-battles.md`, `competitive/the-bazaar.md`.
> - Sources web nouvelles (citées au fil du texte).

---

## 0. Thèse de ce round

Les trois rounds précédents ont posé les bonnes décisions structurelles (or fixe, XP TFT-style,
cost=rank, slot-decline à mesurer, courbe XP à recourber, pity-signal sans garantie, option C
slot-decline) et ont bien progressé sur la calibration. Ce round apporte un regard sur **cinq
zones encore insuffisamment fondées ou activement affaiblies** par le brouillon v4 :

1. **La courbe XP `{2,5,10,18}` adoptée comme correctif de calibration (litige #K) est
   sous-spécifiée sur un point critique : elle repose sur un budget de run de 15 rounds,
   mais la durée réelle d'un run est variable (10-20 combats) et cet écart change radicalement
   si la courbe est saine ou trop raide.** Les rounds 1-3 n'ont pas chiffré l'impact de la
   variance de durée de run sur la tension XP.
2. **L'option C du slot-decline (`+1 or + +1 XP passive`) est adoptée (round 3, §7.1 drapeau P3)
   sans démontage de sa psychologie sous-jacente.** Le bénéfice XP de l'option C crée une
   interaction non testée avec la courbe recorbée `{2,5,10,18}` : sur la nouvelle courbe, `+6 XP`
   gratuites (refus de tous les slots) ne valent plus la même chose qu'avec `{2,5,8,12}`.
3. **Le pity-signal adopté (round 3, §7.3 `#E/#L`) est partiellement mal fondé sur la psychologie :
   la démarche « signal sans garantie » est juste en principe, mais le seuil proposé (50-60 % du
   hunt médian) est trop tardif selon la littérature récente.** Le seuil de « compulsion » documenté
   est ~55 tentatives, et non pas la médiane d'un hunt de 12 rerolls.
4. **La Contrainte du Jour (daily) adoptée a un gap de rétention non adressé : elle force le joueur
   à jouer un archétype contraint, mais n'encadre pas la lisibilité de cet archétype pour un joueur
   qui ne maîtrise pas encore la famille imposée.** Un « Jour de Brûlure » pour un joueur sans
   connaissance des synergies burn = une run punitive sans compréhension, l'inverse de l'intention.
5. **La formule de tension « or = 4 rerolls = 1 unité rang-4 » (coût d'opportunité pur) n'est PAS
   calibrée pour toute la durée du run.** En tier-1 (boutique 100 % rang-1), il n'y a pas d'unité
   rang-4 disponible : le coût d'opportunité est mal positionné en early-game. Ce biais de formulation
   fausse la lecture de la tension early.

---

## 1. Accords avec pourquoi

### 1.1 Or fixe + streaks : oui, les maths tiennent, et la 4e confirmation confirme

**Accord total**, convergence de 4 rounds consécutifs sans contestation sérieuse.

The Bazaar (notre concurrent le plus proche en async PvP) a migré d'un système d'income variable
(S1 : 15 or de départ + 7 income, reroll 2-4 or selon le marchand — [mobalytics.gg day guide](https://mobalytics.gg/the-bazaar/guides/day-guide)) vers un modèle plus SAP-like en S2 où le revenu
est plus lisible. La migration de Bazaar **confirme** que la complexité d'income variable nuit à
l'onboarding dans un jeu async. Notre `GOLD_PER_ROUND = 10` fixe est la décision correcte.

**Pourquoi ça tient pour NOS contraintes** : run async à 10 victoires sans lobby temps réel = le
joueur n'a aucune information sur le niveau économique adverse → la banque perd sa fonction stratégique
sociale (dans TFT, économiser est lisible parce qu'on voit les adversaires sur le carrousel). Source :
`competitive/tft.md §1.2` (l'intérêt TFT est ancré dans l'information partagée du lobby).

### 1.2 XP TFT-style (passive + achetable) : la structure tient, la calibration reste à faire

**Accord sur la structure.** Les rounds 1-3 ont bien identifié que la structure est saine ; les
valeurs sont [PH]. **Accord spécifique sur la courbe recourbée** (#K) : `{2,5,10,18}` vs `{2,5,8,12}`
est justifié. Voir §2.1 pour le challenge de la sous-spécification.

**Accord sur la passive XP à partir du round 2 uniquement.** Le code confirme (`state.lua:68` :
`PASSIVE_XP_PER_ROUND = 1` + `if self.round > 1` dans `startRound`) que le round 1 est intentionnellement sans XP passive. C'est la décision correcte pour éviter le rush d'XP avant toute décision d'unité.

**Accord sur BUY_XP_AMOUNT = 4 / BUY_XP_COST = 4 (ratio 1:1) comme tension d'opportunité** : le
ratio 1:1 crée une décision pure de coût d'opportunité (4g = 4 rerolls = 1 unité rang-4). La
tension ne vient pas du ratio lui-même mais du contexte du round. Cette distinction est correcte.

### 1.3 SLOT_DECLINE_GOLD à mesurer avant de figer : accord total

**Accord avec le drapeau de sim P3.** La décision de mesurer le slot-decline AVANT de le figer
est la bonne méthode. L'option C (`+1 or + +1 XP passive`) est élégante en principe. Voir §2.2
pour le challenge sur l'interaction avec la courbe recourbée.

### 1.4 Pity-signal complémentaire à l'audit de pool : accord sur le principe

**Accord fort** : le pity résout un problème psychologique distinct de la dilution. La distinction
« signal sans garantie explicite » (#L) est bien fondée : une garantie explicite neutralise le VRR
(Skinner/Hopson) et réduit l'affect positif à la découverte (ScienceDirect 2025, MDPI 2025,
confirmé par nos recherches web — `mdpi.com/2078-2489/16/10/890`). Voir §2.3 pour le challenge
sur le seuil de déclenchement.

### 1.5 Déprioritisation des reliques F maintenant (P1.5a, round 3) : accord fort

**Accord avec la décision round 3** : les 3 reliques F (runOp) contaminent ~39 % des offres
de relique. La déprioritisation dans `rollRelicChoices` (si F tiré ET ≥1 B-E disponible → remplacer)
est actionnable maintenant, data-pure, sans dépendance. Cette décision est bien fondée et n'a pas
été contestée en round 3. Rien à challenger ici.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La courbe `{2,5,10,18}` est adoptée sans vérifier sa robustesse à la VARIANCE de durée de run

**Claim du brouillon v4 (§7.1 drapeau `--xp-climax`, adopté du round 3)** : les seuils
`{2,5,10,18}` (cumulé T5=35) créent un climax mid-late. Critère : « T4 jamais atteint passif ET
rush T5 coûte ≥25 % du budget du run ».

**Le problème : la durée de run est une VARIABLE, pas un point fixe de 15 rounds.**

Avec `WIN_TARGET = 10` et `START_LIVES = 5`, la durée de run varie de **10 combats minimum** (10
victoires sans défaite) à **19 combats maximum** (10 victoires + 9 défaites, dont une vie récupérée
au round 3). Le round 3 a calculé sur une durée de **15 rounds** (hypothèse médiane). Vérification
pour les deux extrêmes :

**Extrême court — run parfaite, 10 rounds :**
- XP passive cumulée (rounds 2-10) = **9 XP**.
- Avec `{2,5,10,18}` (cumulé T5=35) : T2 atteint (2) ✅, T3 atteint (7) ✅, T4 = 17 XP requises
  → **non atteint passif** ✅. Mais la run se termine à 9 XP = milieu T3 seulement.
- Rush T5 sur 10 rounds : 35 XP − 9 passives = **26 XP à acheter** = 26 or en BUY XP. Sur un
  budget total run de 10 × 10 = 100 or : 26 % → à peine au seuil de la règle « ≥25 % ».
- **Mais sur un run parfait de 10 rounds**, le joueur n'a aucun « round perdu » = pas de streak de
  défaite = pas de bonus streak → budget or réel ≈ 100 or. Rush T5 = impossible sans sacrifier tous
  les rerolls/achats. **La contrainte est trop dure sur run court.**

**Extrême long — run difficile, 19 rounds :**
- XP passive cumulée (rounds 2-19) = **18 XP**.
- Avec `{2,5,10,18}` : T4 = 17 XP → **T4 atteint passif au round 18** ✅ (intention préservée).
  T5 = 35 XP → jamais passif ✅.
- Rush T5 sur 19 rounds : 35 − 18 = **17 XP à acheter** = 17 or. Sur budget ≈ 19 × 10 + streaks
  ≈ 200-210 or : **≈8-9 % du budget** → **beaucoup trop peu** pour être une décision significative.

**Résultat** : la courbe `{2,5,10,18}` est sensible à la durée de run. Elle est :
- **Trop raide** sur les runs courtes et propres (10-12 rounds) : rush T5 = quasi-impossible ou
  très coûteux, ce qui punit le joueur compétent (qui ascend vite).
- **Trop douce** sur les runs longues (16-19 rounds) : le rush T5 ne coûte que ~8 % du budget →
  pas une décision difficile.

**Ce que ça implique** : le critère « rush T5 ≥25 % du budget » est mesuré sur un run médian de
15 rounds mais n'est satisfait uniformément NI pour les runs courtes NI pour les runs longues. La
tension est inconsistante selon le profil de run.

**Anti-analogie TFT à enfoncer plus loin (sources web vérifiées)** : TFT niveau 2 à 9 = seuils
cumulés 2, 6, 10, 20, 36, 56, 80, 100 XP ([lolchess.gg/guide/exp](https://lolchess.gg/guide/exp?hl=en))
avec passive 2 XP/round sur 25+ rounds. Sur 30 rounds, XP passive = 60 XP → T7 atteint passivement
(56 XP). La tension TFT sur les niveaux 8-9 (80-100 XP cumulées) vient du fait qu'ils requièrent
des dizaines de rounds supplémentaires ou des achats massifs. L'invariance de la tension TFT est
obtenue parce que **TFT a une durée de partie elle aussi variable (20-35 rounds)** — mais les
seuils sont calibrés pour que la tension soit maximale sur le **milieu de la distribution**, pas sur
les extrêmes. Notre calibration doit faire de même.

**Proposition concrète (§3.1).**

**Source** : [lolchess.gg/guide/exp](https://lolchess.gg/guide/exp?hl=en) (seuils TFT cumulés,
vérifiés : niveau 9 = 100 XP cumulées, non-exponentiel sur les derniers niveaux comme dit dans
r03 — c'est super-linéaire mais pas exponentiel — le terme « exponentiel » du round 3 est
légèrement exagéré) ; [op.gg TFT game-guide](https://op.gg/tft/game-guide/gold-xp) (passive 2
XP/round, confirmé).

### 2.2 DÉSACCORD MINEUR — L'option C du slot-decline est adoptée sans re-calculer l'impact sur la courbe recourbée

**Claim du brouillon v4 (§7.1 drapeau slot-decline + option C)** : décliner = `+1 or + +1 XP
passive`. « Un joueur tall (refus systématique) : +6 XP gratuites sur le run. »

**Le problème : +6 XP avec `{2,5,10,18}` ne vaut PAS la même chose qu'avec `{2,5,8,12}`.**

Avec l'ancienne courbe `{2,5,8,12}` (cumul T5=27) : +6 XP gratuites sur 15 rounds représentent
6/27 = **22 % du chemin vers T5**. C'est significatif.

Avec la nouvelle courbe `{2,5,10,18}` (cumul T5=35) : +6 XP gratuites représentent 6/35 = **17 %
du chemin vers T5**. Moins fort, mais le changement de structure est plus nuancé :
- Sur un run court (10 rounds), sans option C : 9 XP passives → T3 seulement.
  Avec option C (refus systématique) : 9 + 6 = 15 XP → **T3 atteint presque, seuil T4 = 17** →
  1 seul achat de BUY XP (4 or = 4 XP) suffit pour atteindre T4. L'option C rend T4 beaucoup
  plus accessible sur les runs courtes.
- Sur un run long (19 rounds), sans option C : 18 XP → T4 atteint passif (17 XP). Avec option C :
  18 + 6 = 24 XP → T4 atteint bien avant la fin, et seuil T5 = 35 - 24 = **11 XP restantes** →
  3 achats BUY XP (12 or). Sur un budget de ~200 or, c'est trivial.

**Résultat** : sur les runs longues, l'option C rend le rush T5 trop accessible pour l'archétype
« tall ». La propriété « décliner = trade largeur/profondeur » est bonne en design, mais la
quantification `+1 XP passive` doit être recalibrée sur la courbe `{2,5,10,18}`, et **non maintenue
identique à ce qu'elle était conçue pour l'ancienne courbe**.

**Note** : ce n'est pas une raison de rejeter l'option C, mais de la re-calibrer avec la sim.
Le drapeau de sim doit spécifier : « option C = refus systématique vs acceptation systématique,
sur les distributions de durée de run (10-19 rounds), avec la courbe `{2,5,10,18}` et SLOT_DECLINE_XP
à trouver entre 0.5 et 1.5 XP par refus. » La valeur `+1 XP` n'est pas un chiffre à adopter
mécaniquement — c'est un placeholder à trouver.

**Source** : calcul direct depuis `state.lua:50` (`SLOT_GRANT_ROUNDS = { [2]=true, ..., [7]=true }`
= 6 offres) + constantes du 00-state §4.1.

### 2.3 DÉSACCORD SUR LE SEUIL DU PITY-SIGNAL — 50-60 % du hunt médian est trop tardif selon la littérature récente

**Claim du brouillon v4 (§7.3)** : le signal pity se déclenche « à partir du **6-7e reroll** sans
voir l'unité (≈ 50-60 % du hunt médian rang-3 T3 ~12) ».

**Le problème : la littérature récente sur les pity systems fixe le seuil de compulsion à ~55
tentatives, pas à la médiane du hunt.** Ces deux métriques sont orthogonales.

La recherche MDPI 2025 (citée par le round 3, `mdpi.com/2078-2489/16/10/890`) identifie **~55
tentatives** comme le seuil critique entre « engagement » et « compulsion » dans les systèmes de
tirage. Ce seuil est une frontière **absolue** (nombre de tentatives), pas relative (% du hunt
médian). Pour notre cas :

- Hunt médian rang-3 en T3 : ~12 rerolls (selon la calibration indiquée en §7.3). Déclenchement
  du signal à 50-60 % = 6-7 rerolls → **ce seuil est correct dans l'absolu** (bien en-dessous de 55
  tentatives). La proposition du brouillon est techniquement saine sur ce point.
- MAIS : le seuil 50-60 % de la médiane suppose que la médiane est connue et stable. Si l'audit
  de pool (P0.5) réduit le pool et que la médiane tombe à 5 rerolls, le signal se déclencherait
  à 2-3 rerolls → **trop tôt**, ce qui réduit la valeur du signal (le joueur le voit presque
  toujours, il perd de la saillance).
- À l'inverse, si le pool se révèle plus dilué que prévu (médiane 20 rerolls pour un rang rare),
  le seuil 50-60 % = 10-12 rerolls → **encore sous 55 absolus** ✅, mais potentiellement trop
  loin dans la frustration pour les runs courtes.

**Ce qui manque** : le seuil doit être défini comme `max(N_rerolls_fixes, fraction × médiane)`,
avec `N_rerolls_fixes` comme plancher absolu (exemple : 3 rerolls sans voir l'unité = signal
toujours déclenché minimum) et la fraction comme adaptation au hunt réel. La formulation actuelle
(fraction seule) est incomplète.

**Deuxième problème** : le brouillon v4 adopte la formulation « signal grimdark sans chiffre »
(`« L'ombre de cette créature est proche »`) mais n'encadre pas l'UI. Dans les jeux de gacha
modernes, un soft-pity implicite (sans chiffre affiché) est **psychologiquement moins efficace**
qu'un signal avec une progression visible ([Gacha System Analysis — dl.acm.org](https://dl.acm.org/doi/pdf/10.1145/3579438) : « players need to perceive progress toward
the guarantee »). La tension entre « ne pas afficher le chiffre » (VRR) et « ne pas afficher la
progression » (frustration) n'est pas résolue par le seul flavor text.

**Proposition concrète (§3.3).**

**Source** : MDPI 2025 (cité — Inherent Addiction Mechanisms) `mdpi.com/2078-2489/16/10/890` ;
ACM SIGCHI 2023 `dl.acm.org/doi/pdf/10.1145/3579438` (Gacha Game Analysis) ; Round 3 §7.3
(seuil proposé).

### 2.4 DÉSACCORD — La Contrainte du Jour punit les joueurs qui ne maîtrisent pas l'archétype imposé, sans filet pédagogique

**Claim du brouillon v4 (§6.6, litige #H tranché round 3)** : la Contrainte du Jour impose une
restriction mécanique active toute la run daily. Exemple : « Jour de Brûlure : seules les unités
`dot_family=burn` proposées en boutique. »

**Le problème : la contrainte EST la différenciation (argument correct), mais elle présuppose
que le joueur connaît l'archétype imposé.**

La Contrainte du Jour StS (source fondatrice du round 3) impose des modifiers à un joueur qui
connaît déjà les cartes de base. StS a ~100 cartes avec une boucle de combat familière ; les
modifiers modifient une expérience connue. The Pit a un archétype burn avec 13 unités sur 5
rangs, des synergies d'adjacence, et des reliques spécifiques — c'est une **chaîne de
connaissances** (unités burn → placement → reliques burn → propagation-à-la-mort) que le joueur
doit maîtriser pour jouer la daily burn de façon compétente. Un nouveau joueur confronté à une
daily burn contrainte est privé de sa liberté d'exploration sans avoir les outils pour réussir
la contrainte.

**Conséquence** : pour les joueurs 0-5 wins (la zone churn identifiée en round 3), une daily
contrainte = une session punitive supplémentaire. Cela entre en contradiction directe avec la
décision de reclasser le post-combat « pourquoi » en co-priorité 1 (pour aider précisément ces
joueurs).

**Ce qui manque** : la Contrainte du Jour doit être accompagnée d'un **bootstrapping minimal**
de l'archétype imposé. Deux options :
- **(a) Amorce de build** : au début d'une daily contrainte, le plateau démarre avec 1-2 unités
  de la famille imposée pré-placées (découplé du choix du joueur, comme un « starter deck »
  imposé). Coût dev faible (simple : placer des unités sur le plateau au démarrage).
- **(b) Tooltip de run** : avant la daily, afficher « Archétype de la journée : BURN — unités de
  feu qui propagent leurs flammes aux voisins à la mort ». 2-3 mots de contexte = onboarding
  du jour. Coût : quasi nul (RENDER, texte statique par contrainte).

La version (b) est préférable en première implémentation : elle préserve l'agence du joueur
(il choisit quelles unités burn acheter) tout en lui donnant le contexte minimal pour que la
contrainte soit un puzzle, pas une punition aveugle.

**Source** : StS Daily Challenge — [slay-the-spire.fandom.com/wiki/Daily_Challenge](https://slay-the-spire.fandom.com/wiki/Daily_Challenge) (confirme
que les modifiers de StS affectent une expérience de base familière) ; Juul « Fear of Failing »
(cité round 3 — attribuer l'échec à une décision compréhensible, pas à l'opacité du système).
**Note** : ce n'est PAS un désaccord sur le concept de Contrainte du Jour (l'argument du round 3
est solide) ; c'est un désaccord sur l'implémentation minimale qui doit inclure un filet
pédagogique.

### 2.5 DÉSACCORD MINEUR — La formulation « 4g = 4 rerolls = 1 unité rang-4 » comme tension d'opportunité est FAUSSE en early-game

**Claim implicite du brouillon v4 et du PRD (§7.1, §3.1)** : le coût d'opportunité de l'achat
d'XP (4 or) est ancré sur « 4 or = 1 unité rang-4 ». Cette formulation est utilisée pour
justifier que la décision BUY XP est réelle et coûteuse.

**Le problème : en tier-1 (boutique 100 % rang-1, 12 unités), il n'y a pas d'unité rang-4
disponible.** Un joueur en tier-1 ne « sacrifie pas une unité rang-4 » en achetant de l'XP :
il sacrifie **4 rerolls** ou **2 unités rang-1 + 2 rerolls**. Ce n'est pas du tout la même
décision psychologique.

- En tier-1 : le coût d'opportunité de BUY XP est « 2 unités rang-1 sacrifiées » ou « 4 chances
  supplémentaires de voir ma 3e copie rang-1 ». C'est une décision d'**accélération** vs
  **consolidation** dans l'archétype rang-1.
- En tier-2 : un rang-2 coûte 2 or (cost=rank). 4 or = 2 unités rang-2 = une vraie décision
  douloureuse.
- En tier-3 : un rang-3 coûte 3 or. 4 or = 1 unité rang-3 + 1 reroll.
- En tier-4 : un rang-4 coûte 4 or. 4 or = 1 unité rang-4. C'est ici que la formulation est correcte.

**Ce que ça implique** : la tension BUY XP est asymétrique selon le tier actuel. En early (tier-1
à tier-2), le coût d'opportunité est faible et la décision BUY XP est relativement facile → le
joueur a tendance à « accélérer » l'XP naturellement. En mid (tier-3 à tier-4), le coût est
maximal en proportion (1 rang-3 ou 1 rang-4 sacrifié). En late (tier-4 à tier-5), le coût est
de 18 XP nettes (soit 4-5 achats) → la décision est majeure mais survient tardivement.

**Ce n'est pas une erreur bloquante** — c'est une sous-spécification dans la narration du brouillon
qui pourrait induire une mauvaise calibration des valeurs. La sim (`tools/sim.lua --xp-climax`) doit
mesurer le delta de décision par tier-actuel, pas seulement par round.

**Source** : `src/run/state.lua:69-70` (BUY_XP_AMOUNT = 4, BUY_XP_COST = 4 ; unité rang-4 coûte
4 or par `cost=rank`) ; `src/data/units.lua` (cost=rank confirmé).

---

## 3. Propositions priorisées

### 3.1 P3 (PRÉCONDITION) — Ajouter la variance de durée de run au critère de la courbe XP [PRIORITÉ 1]

**Quoi** : raffiner le critère de sim pour la courbe `{2,5,10,18}` pour y intégrer la variance.

**Critère amélioré (remplace le critère simple du brouillon v4 §7.1)** :

La courbe est saine **si et seulement si** :
1. **T4 jamais atteint passif sur un run à 15 rounds** (critère d'intention — inchangé).
2. **Rush T5 coûte ≥20 % du budget sur un run COURT (10-12 rounds)** — pour que même les runs
   propres aient une décision réelle d'investissement en XP.
3. **Rush T5 coûte ≥10 % du budget sur un run LONG (17-19 rounds)** — la décision reste présente
   même pour les runs difficiles, même si moins coûteuse.
4. **Option C (slot-decline) :** mesurer séparément le delta XP sur les runs courtes vs longues.
   Si `SLOT_DECLINE_XP = 1` donne un avantage >10 % de win-rate sur les runs longues → réduire
   à 0.5 XP.

**Implémentation sim** : 3 politiques `(passif_pur, rush_maximal, option_C_refus)` × 3 tranches de
durée `(court 10-12, médian 13-16, long 17-19)` = 9 configurations, N=100 seeds chacune.

**Garde-fou** : changement de constantes uniquement. Aucun invariant.

### 3.2 P3 — Re-calibrer `SLOT_DECLINE_XP` explicitement sur la nouvelle courbe, pas sur l'ancienne [PRIORITÉ 1]

**Quoi** : le drapeau de sim slot-decline doit comparer les deux paramètres `SLOT_DECLINE_XP ∈
{0, 0.5, 1, 1.5}` avec la courbe `{2,5,10,18}` (et non avec les seuils actuels `{2,5,8,12}`).

**Cible** : trouver le `SLOT_DECLINE_XP` qui (a) rend l'option C significativement différente de
l'option « tout accepter » (le trade tall/wide est réel), (b) ne rend pas le refus systématique
dominant sur les runs longues.

**Pas de valeur recommandée** sans sim : la logique de la valeur `1` (adoptée implicitement dans
le brouillon v4 §7.1) n'est pas démontrée sur la nouvelle courbe.

**Garde-fou** : constante dans `state.lua`. Aucun invariant.

### 3.3 P3 — Reformuler le seuil du pity-signal en `max(3, fraction × médiane)` [PRIORITÉ 2]

**Quoi** : remplacer la définition « 50-60 % du hunt médian » par un seuil composite :

```
pity_trigger = max(PITY_MIN_ABS, floor(PITY_FRAC × hunt_median[rang][tier]))
-- PITY_MIN_ABS [PH] = 3  (signal même si hunt médian = 4 rerolls)
-- PITY_FRAC [PH] = 0.50  (fraction de la médiane)
-- hunt_median[rang][tier] = mesuré en sim après audit de pool
```

**Pourquoi** : le plancher absolu (`PITY_MIN_ABS = 3`) garantit que le signal existe même si
le pool est très réduit après l'audit P0.5. Le plafond implicite (fraction de la médiane) garantit
que le signal n'est pas trivial (déclenché à chaque run). La formule est déterministe et seedée
(dérivée du compteur de rerolls du run).

**Sur l'UI** : conserver le flavor grimdark (« L'ombre de cette créature est proche »), mais
ajouter un **indicateur de progression implicite** : l'icône de l'unité cherchée dans la boutique
devient progressivement plus lumineuse/intense à chaque reroll sans la voir. Pas de chiffre affiché,
mais une progression **visuelle** qui rend la progression vers la garantie perceptible sans la
rendre explicite. C'est l'équilibre VRR / signal d'escalation.

**Source** : ACM SIGCHI 2023 (Gacha Analysis) `dl.acm.org/doi/pdf/10.1145/3579438` ; MDPI 2025
`mdpi.com/2078-2489/16/10/890` ; progression-economy-prd §7.3 (seed-dérivé mentionné).

### 3.4 P2 — Ajouter un tooltip de run à la Contrainte du Jour avant de la lancer [PRIORITÉ 2]

**Quoi** : avant la confirmation d'une daily, afficher un panneau de contexte (1 écran, texte court)
présentant la contrainte du jour :
- Titre : « JOUR DE BRÛLURE »
- Corps : « Seules les créatures de la famille Brûlure seront dans ta boutique. Elles propagent
  leurs flammes aux voisins à la mort. »
- Optionnellement : 2-3 icônes des unités burn rang-1 disponibles dans la boutique du jour.

**Pourquoi AVANT d'accepter la daily** : la contrainte StS est présentée avant que le run ne commence
(interface Daily Challenge liste les modifiers). Nous devons faire de même. Un joueur qui démarre
la daily sans contexte et perd au bout de 3 combats ne reviendra pas.

**Coût** : UI pure, 0 mécanique. 1 écran ou tooltip = 1-2h de dev. À inclure dès la première
implémentation de la daily (v0.11), pas en V2.

**Garde-fou** : RENDER uniquement, 0 invariant.

### 3.5 P0 — Documenter la formulation correcte du coût d'opportunité BUY XP par tier dans l'audit P0 [PRIORITÉ 3]

**Quoi** : dans le document d'audit P0 (lisibilité), ajouter un tableau explicite du coût
d'opportunité BUY XP par tier de boutique actuel :

| Tier boutique | 4 or = BUY XP correspond à... | Tension perçue |
|---|---|---|
| T1 | 2 unités rang-1 + 0 reroll OU 4 rerolls | Faible — les unités rang-1 sont abondantes |
| T2 | 2 unités rang-2 OU 1 rang-2 + 2 rerolls | Modérée — sacrifice réel |
| T3 | 1 unité rang-3 + 1 reroll | Forte — tension réelle |
| T4 | 1 unité rang-4 | Maximale — décision douloureuse |
| T5 | 1 unité rang-5 coûtant 5g (soit 1 unité rang-4 + 1g de reroll) | Très forte, rarement considérée |

Ce tableau est une **documentation de design**, pas du code. Il calibre les attentes des tests.

**Pourquoi P0** : si la sim mesure la tension sans ce référentiel, les chiffres sont difficiles
à interpréter (« le joueur achète de l'XP à T1 parce que ça coûte peu, pas parce que la décision
est bonne »). Le tableau clarifie l'analyse post-sim.

---

## 4. Questions ouvertes

### Q1 — La courbe `{2,5,10,18}` doit-elle avoir un seuil `T5 = 18` ou un seuil différent selon la vision « passif ≈ T3 » et la durée de run médiane ?

Si la durée médiane de run est 14 rounds (médiane entre 10 et 19), le passif cumule 13 XP → T3
atteint (7 XP) ✅ mais T4 (17 XP) non atteint ✅. C'est cohérent. Mais le seuil T4→T5 = 18 sur
la courbe `{2,5,10,18}` implique un cumul total T5 = 2+5+10+18 = 35 XP. Sur 14 rounds passifs :
13 XP → 13/35 = 37 % vers T5 seulement. Rush T5 = 22 XP à acheter = 5-6 achats de BUY XP = 20-24
or. Sur un budget de 140 or (médiane) : 14-17 %. Trop faible pour la règle ≥25 % du critère du
round 3. **Le seuil T5 = 18 est peut-être insuffisamment élevé.** À sim.

### Q2 — La passive XP à partir du round 2 uniquement : faut-il une passive escalante (round 7+ = +2 XP/round) ?

Le round 3 a ouvert cette question (Q2 de r03-progression-economy) et la synthèse round-03.md §2.4
l'a « tempérée » (ne pas activer avant sim). Ce round maintient ce report, mais signale que si le
critère de run courte (Q1 ci-dessus) révèle un problème, une passive escalante en late pourrait
compenser sans toucher aux seuils. À mesurer en même temps que la courbe.

### Q3 — La daily Contrainte du Jour doit-elle avoir sa propre progression pédagogique (tutoriel progressif des familles) ?

Si la progression journalière des contraintes suit un ordre pédagogique (burn → bleed → poison → rot
→ choc) les premières semaines du jeu, le joueur apprend les familles dans l'ordre et la daily
devient une courbe d'apprentissage déguisée. Cela implique un calendrier éditorial initial (les 5
premières semaines = 1 famille/semaine), ensuite les contraintes rotent librement. À documenter
dans le ticket implémentation daily.

### Q4 — Y a-t-il un risque de circularité entre la Contrainte du Jour et la garantie de pertinence des reliques ?

Si la daily impose « burn seulement en boutique » (côté unités) et que la garantie de pertinence
force ≥1 relique burn pertinente, le joueur reçoit un signal redondant (famille burn confirmée deux
fois : boutique + relique). Ce n'est pas un défaut en soi, mais un signal de lisibilité. À vérifier
lors du prototype.

---

## 5. Synthèse des points clés pour la roadmap

### Ce qui change par rapport aux rounds 1-3 :

1. **Critère de la courbe XP `{2,5,10,18}` à raffiner** : le critère du round 3 (« T4 jamais passif
   ET rush T5 ≥25 % du budget ») n'est pas robuste à la variance de durée de run. Ajouter les cas
   court (10-12 rounds) et long (17-19 rounds) dans la sim. Pas une raison de rejeter la courbe —
   une raison de la tester plus rigoureusement.

2. **`SLOT_DECLINE_XP` à sim avec la nouvelle courbe** : la valeur `+1 XP` implicitement adoptée
   n'est pas validée sur `{2,5,10,18}`. Elle doit être sim-vérifiée dans la plage `[0.5, 1.5]`.

3. **Seuil pity-signal à reformuler en `max(N_abs, fraction × médiane)`** : le plancher absolu
   évite que le signal disparaisse après l'audit de pool. La progression visuelle implicite
   (intensité de l'icône) résout le dilemme VRR/signal.

4. **Tooltip de run pour la Contrainte du Jour = implémentation minimale OBLIGATOIRE dès v0.11** :
   sans filet pédagogique, la daily est punitive pour les joueurs 0-5 wins. Coût quasi nul.

5. **Reformulation du coût d'opportunité BUY XP dans le document de calibration** : distinguer le
   coût d'opportunité par tier actuel (pas seulement « 1 unité rang-4 »).

### Ce qui reste inchangé et tient :

- Or fixe + streaks anti-snowball : non contesté, 4e confirmation.
- `cost = rank` : verrouillé.
- Refund 0.5× : engagement garanti.
- Courbe XP recourbée `{2,5,10,18}` vs `{2,5,8,12}` : correcte en direction, à affiner par les
  critères ci-dessus.
- Déprioritisation des reliques F maintenant (P1.5a) : accord fort, non contesté.
- Pity = signal sans garantie explicite : accord fort, seuil à reformuler.
- Daily = Contrainte du Jour (option c) : accord fort, à compléter avec le tooltip de run.
- Option C slot-decline (tall-vs-wide) : accord fort sur le principe, valeur `SLOT_DECLINE_XP` à sim.

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` (constantes éco : GOLD_PER_ROUND=10, XP_TO_LEVEL={2,5,8,12}, PASSIVE_XP_PER_ROUND=1,
  BUY_XP=4/4, SLOT_GRANT_ROUNDS rounds 2-7, SLOT_DECLINE_GOLD=3)
- `docs/roadmap-lab/00-state.md` §4 (constantes, cotes, boucle)
- `docs/roadmap-lab/ROADMAP-draft.md` v4 §7 (P3, drapeaux sim, courbe XP, slot-decline option C)
- `docs/roadmap-lab/round-01.md`, `round-02.md`, `round-03.md` (synthèses précédentes)
- `docs/roadmap-lab/rounds/r01-progression-economy.md` à `r03-progression-economy.md`
- `docs/research/progression-economy-prd.md` §3 (PRD verrouillé, intentions de calibrage)
- `docs/roadmap-lab/competitive/tft.md` §1.2-1.3 (seuils XP TFT, passive 2/round, intérêt)
- `docs/roadmap-lab/competitive/super-auto-pets.md` §2.1-2.3 (or fixe, tiering boutique par turn)

**Sources web nouvelles (vérifiées)** :
- [TFT XP Seuils — lolchess.gg/guide/exp](https://lolchess.gg/guide/exp?hl=en) (seuils cumulés
  niveau 2-9 : 2, 6, 10, 20, 36, 56, 80, 100 XP — super-linéaires, pas exponentiels ;
  la passive = 2 XP/round confirmée)
- [TFT Gold & XP — op.gg/tft/game-guide/gold-xp](https://op.gg/tft/game-guide/gold-xp)
  (économie TFT : income variable 2g→5g selon stage, intérêt sur banque)
- [The Bazaar Economy — mobalytics.gg/the-bazaar/guides/day-guide](https://mobalytics.gg/the-bazaar/guides/day-guide)
  (starting economy 15 or + 7 income ; reroll 2-4 or selon rareté marchand ; confirme la complexité
  de l'income variable comme friction d'onboarding)
- [MDPI 2025 Gacha Addiction — mdpi.com/2078-2489/16/10/890](https://mdpi.com/2078-2489/16/10/890)
  (pity design : seuil ~55 tentatives entre engagement et compulsion ; soft pity vs hard pity ;
  confirme que le signal de progression vers la garantie est nécessaire même sans chiffre affiché)
- [Gacha Game Analysis — dl.acm.org/doi/pdf/10.1145/3579438](https://dl.acm.org/doi/pdf/10.1145/3579438)
  (ACM SIGCHI 2023 : les joueurs ont besoin de percevoir la progression vers la garantie pour que
  le pity soit efficace psychologiquement — confirme le besoin d'un signal visuel)
- [StS Daily Challenge — slay-the-spire.fandom.com/wiki/Daily_Challenge](https://slay-the-spire.fandom.com/wiki/Daily_Challenge)
  (modifiers affichés avant le démarrage du run ; confirms que la Contrainte du Jour doit être
  présentée avant, pas pendant)
- [Balatro Economy — games.gg/balatro/guides/balatro-economy-guide](https://games.gg/balatro/guides/balatro-economy-guide/)
  (intérêt Balatro : 1$/5$ stocké, cap 5$/round sur ~24 blinds → ~120$ gratuits ; pas directement
  transférable mais confirme que l'intérêt a besoin d'une durée de jeu longue pour être significatif)
- [Endowed Progress Effect — gamedeveloper.com](https://www.gamedeveloper.com/game-platforms/the-psychology-of-games-the-endowed-progress-effect-and-game-quests)
  (reconfirme que l'endowed progress effect nécessite une avancée visible de 10-25 % de l'objectif
  total — pertinent pour le pity et pour la courbe XP)

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 4. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants non modifiés.
Désaccords sourcés par code + web. Propositions chiffrées ancrant les constantes dans state.lua.*
