# Round 06 — Critique adversariale : Progression & Économie

> **Lentille** : progression-economy — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v6, intégré round 5), de tous les
> rapports `rounds/r01-r05-progression-economy.md`, et des synthèses `round-01.md` à `round-05.md`.
> Accords argumentés / désaccords sourcés / propositions concrètes, chiffrées, priorisées.
> Aucune modification du code du jeu. Lecture seule du repo.
>
> **Sources primaires relues** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v6, `docs/roadmap-lab/00-state.md`
> - `round-01.md` à `round-05.md` (intégraux)
> - `rounds/r01-r05-progression-economy.md` (intégraux)
> - `docs/research/progression-economy-prd.md`
> - `src/run/state.lua` via `00-state.md §4`
> - `competitive/super-auto-pets.md`, `competitive/tft.md`, `competitive/hs-battlegrounds.md`,
>   `competitive/the-bazaar.md`, `competitive/balatro.md`, `competitive/backpack-battles.md`
> - Sources web nouvelles (citées au fil du texte)

---

## 0. Thèse de ce round

Les cinq rounds précédents ont **solidement convergé** sur les décisions structurelles (or fixe,
XP TFT-style, cost=rank, courbe recourbée `{2,5,10,18}`, option C slot-decline, pity-signal sans
garantie, daily+tooltip, streak-loss actionnable) et ont **corrigé des bugs latents** (reroll
implicite, streaks dans le budget XP, distribution temporelle des signaux VRR).

Ce round identifie **trois zones que les rounds 1-5 n'ont pas résolu ou ont mal fondé** :

1. **DÉSACCORD STRUCTUREL MAJEUR : le ratio reroll/rang-1 dans The Pit est FONDAMENTALEMENT
   différent de SAP, et toute la discussion des rounds 1-5 sur ce point repose sur une analogie
   incorrecte. Dans SAP, tous les pets coûtent 3 gold et le reroll coûte 1 gold — ratio 1:3.
   Dans The Pit, le rang-1 coûte 1 gold et le reroll coûte 1 gold — ratio 1:1. Les rounds
   1-5 citent SAP pour "défendre" REROLL_COST=1, mais SAP n'a jamais eu le ratio 1:1.
   La décision de trancher en sim (§7.5) est correcte — mais la sim doit tester la BONNE
   question : est-ce que le ratio 1:1 reroll/rang-1 crée une tension ou la détruit ?**

2. **DÉSACCORD MINEUR SUR LA COURBE XP : le critère à 3 tranches de durée de run (rounds 4-5)
   est méthodologiquement solide, mais le brouillon v6 n'a pas résolu une tension cachée entre
   la courbe `{2,5,10,18}` et le `START_SLOTS = 3`. Un joueur avec 3 slots ne peut pas exploiter
   un T5 : le rush XP est inutile jusqu'au slot-grant round 2. La courbe XP et la courbe
   des slots doivent être co-calibrées, pas indépendamment.**

3. **LACUNE DE SPÉCIFICATION : le tableau d'intention des constantes économiques (§7.5, promu
   round 5) est présenté comme une tâche de "documentation P3" — mais c'est en réalité la
   PRÉCONDITION de toute sim P3. Sans ce tableau, les métriques de sim mesurent sans savoir
   quoi elles optimisent. C'est un renversement d'ordre critique.**

---

## 1. Accords avec pourquoi ils tiennent

### 1.1 Or fixe 10/round + streaks anti-snowball : accord total, 6e confirmation

**Accord total.** Six rounds consécutifs sans désaccord sérieux. La confirmation web la plus
récente : la mise à jour SAP wiki (`superautopets.wiki.gg/wiki/Gold`) confirme explicitement
que l'or **ne se reporte pas entre rounds** dans SAP aussi. Notre choix est correct structurellement.

**Pourquoi ça tient pour NOS contraintes** : run async à 10 victoires, pas de lobby social, pas
d'information sur l'état économique adverse → la banque d'or perd ses deux fonctions (stratégie
longue ET signal social du lobby). Bien posé depuis r01 §1.1.

### 1.2 XP TFT-style (passive + achetable) : la structure reste saine malgré la sous-spécification

**Accord sur la structure.** Le code (`state.lua:195`) : XP passive démarre au round 2 (accord
maintenu). Le `BUY_XP_AMOUNT=4 / BUY_XP_COST=4` (ratio 1:1) crée une décision de coût
d'opportunité — pas le ratio lui-même mais son contexte par tier. Bien établi en rounds 3-4.

**Ce qui tient** : la décision de soumettre la courbe à la sim (`--xp-climax`, §7.1) avant de
figer les valeurs, avec le critère à 3 tranches de durée (r04 §3.1, adopté round 4 puis enrichi
des streaks en round 5). Le critère est robuste.

### 1.3 Courbe recourbée `{2,5,10,18}` : direction correcte, calibration sous sim

**Accord fort avec la direction** : les seuils linéaires `{2,5,8,12}` ne créent pas de climax.
Posé en r03 §2.1, confirmé avec preuves TFT (`lolchess.gg/guide/exp` : seuils super-linéaires
niveaux 2-9 : 2, 6, 10, 20, 36, 56, 80, 100 XP cumulées). Le correctif `{2,5,10,18}` est
justifié comme direction mais pas encore validé pour nos durées de run variables.

**Ce qui reste ouvert** : la co-calibration XP/slots (§2.2 ci-dessous, désaccord mineur).

### 1.4 Option C slot-decline (tall vs wide) : accord sur la psychologie, calibration sous sim

**Accord sur le design** : refuser un slot = +1 or + +1 XP passive (trade largeur vs profondeur
de boutique). L'idée de r03 §3.3 est correctement traduite. La décision de **ne pas figer la
valeur `SLOT_DECLINE_XP`** et de la sim avec la nouvelle courbe (r04 §3.2) est la bonne méthode.

**Critique maintenue de r04** : la valeur `+1 XP` n'a pas été re-simulée sur `{2,5,10,18}` —
c'est une simulation à faire avant de graver.

### 1.5 Pity-signal `max(PITY_MIN_ABS=3, 0.5×médiane)` + progression visuelle implicite : accord solide

**Accord fort.** Reformulation r04 §3.3 avec plancher absolu = correcte. Le plancher garantit
que le signal survit même si l'audit de pool réduit la médiane à 4 rerolls (sinon : signal
à 2 rerolls → trop fréquent, perd de la saillance). La cote interne +5%/reroll cappée ×1.5 est
lisible sans être manipulatrice (or in-game, pas monnaie réelle). Bien fondé.

### 1.6 Signal streak-loss lié au post-combat « pourquoi » : accord total (adopté round 5)

**Accord fort.** Le lien entre loss-streak ≥2 et le signal post-combat actionnable (slot le plus
exposé, pas juste de l'or) est une amélioration coût-quasi-nul avec impact psychologique fort
(Kahneman-Tversky asymétrie 2.3× perte vs gain, cité r05 §2.2). Adopté round 5 §1.7, aucune
contestation. Maintenu.

### 1.7 Déprioritiser les reliques F avant le marchand : accord solide (4e confirmation)

**Accord total.** La contamination de ~38.7% des offres reliques par des runOp (r04 §4.6) est
un problème documenté. La déprio immédiate dans `rollRelicChoices` (si F tiré ET ≥1 B-E
disponible → remplacer) est de la data pure sans dépendance. Non contesté depuis r04.

### 1.8 Tableau d'intention des constantes économiques : accord sur la nécessité, contestation sur l'ordre

**Accord sur la nécessité.** Le tableau de r05 §3.4 (REROLL_COST / BUY_XP_COST / GOLD_PER_ROUND /
STREAK_CAP / SELL_REFUND_FRAC avec leurs intentions) est une bonne idée. **Désaccord sur
l'ordre** (§3.3 ci-dessous) : le placer en P3 est trop tard — c'est un prérequis de la sim.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — L'analogie SAP pour REROLL_COST=1 est structurellement incorrecte depuis r01

**Claim des rounds 1-5 (implicite, jamais mis en question de façon exhaustive)** : le reroll à
1 gold est "cohérent avec SAP". Les rounds 1-5 citent SAP pour contextualiser, parfois pour
valider.

**Le problème fondamental de l'analogie :**

La vérification du SAP wiki (`superautopets.wiki.gg/wiki/Gold`, `superautopets.fandom.com/wiki/Shop`)
et du guide de référence (`twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/`)
confirme : **dans SAP, TOUS les pets coûtent 3 gold uniformément, et le reroll coûte 1 gold.**
Ratio reroll/achat = **1:3**.

Dans The Pit, avec `cost = rank` :
- Rang-1 = **1 gold** = le même prix qu'un reroll → ratio reroll/rang-1 = **1:1**
- Rang-2 = 2 gold → ratio reroll/rang-2 = **1:2**
- Rang-3 = 3 gold → ratio reroll/rang-3 = **1:3** (identique à SAP)
- Rang-4 = 4 gold → ratio reroll/rang-4 = **1:4**
- Rang-5 = 5 gold → ratio reroll/rang-5 = **1:5**

**Conclusion mathématique directe** : The Pit a le ratio reroll/achat le PLUS favorable en
early (rang-1, T1 = 100% rang-1), équivalent à SAP en mid (rang-3), et le PLUS défavorable
en late (rang-5). **SAP n'a JAMAIS eu le ratio 1:1** — c'est un avantage unique au rang-1 de
The Pit qui n'a pas d'équivalent dans la référence citée.

**Ce que ça change pour la discussion :**

Les rounds 1-5 ont débattu de REROLL_COST avec deux cadres :
1. "SAP fait 1 gold donc c'est acceptable" → **l'argument ne tient pas** (SAP = 1:3, pas 1:1)
2. "La tension vient de la qualité des offres, pas du prix" → **ce cadre est valide**

La proposition de r05 §7.5 de trancher en sim est correcte mais **la question de sim est mal
formulée**. Il ne s'agit pas seulement de "garder=1 vs scaler", il s'agit de savoir si le ratio
1:1 reroll/rang-1 en T1 (les 2-3 premiers rounds critiques pour le first impression) crée ou
détruit la tension.

**Calcul explicite du problème T1 :**

Budget T1 = 10 gold. Boutique = 100% rang-1 (coût 1 gold/unité). Options :
- Acheter 10 unités rang-1 = 10 gold (table rase)
- Reroller 10 fois = 10 gold (chercher la composition optimale sans rien acheter)
- Mix 5 achats + 5 rerolls = 10 gold

**Le reroller est strictement gratuit par rapport à l'achat** : reroller puis acheter la même
unité coûte 1+1 = 2 gold (une unité + un reroll pour voir si mieux existe). Sans reroll, 1 gold
= 1 unité. Le coût d'opportunité du reroll est ZERO au rang-1 si on cherche une unité rang-1
que la boutique propose déjà (reroller = chercher une meilleure option sans valeur garantie).

**Mais voici la nuance que les rounds 1-5 ont manquée :** le problème n'est pas que le reroll
est "trop bon marché" dans l'absolu — c'est que le ratio 1:1 crée un comportement optimal
DIFFÉRENT de celui anticipé. Un joueur rationnel en T1 devrait :
1. Observer les 5 offres initiales
2. Si aucune ne correspond à sa stratégie → reroller à 1 gold (= sacrifier un rang-1 en
   valeur d'achat, décision réelle)
3. Si une correspond → acheter

**À T1, le reroll n'est pas "gratuit" — c'est un sacrifice de 1 rang-1 pour chercher mieux.**
C'est une décision réelle mais plus faible que ce que TFT impose (2 gold = 40% du revenu
passif, boosteria.org vérifié r05). La question n'est donc pas "corriger" le ratio mais
**valider que la tension est perceptible dès T1 avec 5 offres** et un pool de 12 unités rang-1.

**Proposition concrète** : la sim `--reroll-cost-scaling` doit mesurer SÉPARÉMENT la fréquence
de reroll et la qualité des décisions en T1 (rang-1 uniquement) vs T3-4 (où le ratio devient
plus défavorable au reroll). Le pivot décisionnel entre "reroller" et "acheter" est différent
selon le tier : en T1, la décision est "chercher ou se contenter" ; en T3, la décision est
"chercher ou investir en puissance". Ces deux décisions méritent d'être mesurées séparément.

**Source** : `superautopets.wiki.gg/wiki/Gold` (tous pets = 3 gold, reroll = 1 gold, ratio 1:3) ;
`superautopets.fandom.com/wiki/Shop` (confirmé) ; `twoaveragegamers.com` (confirmé) ;
`state.lua:27` via `00-state.md §4.1` (REROLL_COST=1) ; `state.lua:34` (cost=rank) ;
`boosteria.org/guides/tft-economy-mastery` (TFT reroll=2g=40% revenu passif).

### 2.2 DÉSACCORD MINEUR — La courbe XP et la courbe des slots ne sont pas co-calibrées

**Claim implicite du brouillon v6 (§7.1, hérité r03-r05)** : la courbe XP `{2,5,10,18}` est
une décision indépendante du slot-grant schedule. Le critère à 3 tranches mesure le rush XP
de manière neutre vis-à-vis des slots.

**Le problème :** avec `START_SLOTS = 3` et `MAX_SLOTS = 9`, les slots s'ouvrent aux rounds
2-7 (`SLOT_GRANT_ROUNDS`, `00-state §4.1`). Un joueur avec 3 slots en T1 n'a aucune utilité
à être en T3+ de boutique — il ne peut pas placer les unités supplémentaires.

**Conséquence non mesurée :**

- Un joueur qui rush XP en rounds 1-2 (passe T1→T3 via 2 achats de BUY_XP à 4 gold = 8 gold)
  se retrouve en T3 au round 3 avec... 3 slots actifs.
- Il voit potentiellement des unités rang-3 (probabilité T3 : 20%, `00-state §4.3`) mais n'a
  que 3 emplacements. L'avantage de être en T3 est dilué.
- À l'inverse, un joueur qui accepte les slots grants (rounds 2-7 = 6 slots supplémentaires)
  mais achète des unités rang-1 passe en T2 à round 3 (2 XP passives) et voit ses slots
  s'ouvrir naturellement.

**La question de sim manquante :** est-ce que la valeur d'être en tier N est corrélée au
nombre de slots actifs ? Si oui, le critère "rush T5 ≥20% du budget" est incomplet — il
faut aussi mesurer "rush T5 avec seulement 3-5 slots actifs vs rush T5 avec 7-9 slots".

**Cas dégénéré révélateur :** un joueur qui refuse tous les slots (option C, max de 6 refus)
arrive en round 7 avec toujours 3 slots. S'il a rushe en parallèle à T4-5, il a une boutique
très puissante mais ne peut mettre en jeu que 3 unités. Le ratio "boutique power vs slots actifs"
devient déséquilibré — soit le rush XP est gaspillé (slots insuffisants), soit les slots refusés
sont gaspillés (pas de boutique pour les remplir).

**Ce n'est pas un argument pour rejeter ni la courbe XP ni l'option C slot-decline** — c'est
un argument pour **les co-calibrer** : la sim doit mesurer le ratio `shopTier / slots_actifs`
à chaque round pour détecter les déséquilibres inter-stratégies.

**Proposition concrète** : ajouter une 4e condition au critère de sim §7.1 :
```
(4) ratio_boutique_slots : mesurer shopTier moyen / slots_actifs_moyen par round pour
    chaque politique (rush_XP, option_C_refus, mixed). Si shopTier/slots > 1.5 pour
    une politique → déséquilibre structurel (l'avantage du tier est dilué par le manque de slots).
```

Ce ratio est calculable à partir des données de sim existantes (runs.lua enregistre le tier et
les slots par round). Coût : 3-4 lignes de métriques dans `tools/sim.lua`.

**Source** : `state.lua:43-55` via `00-state §4.1` (START_SLOTS=3, MAX_SLOTS=9, SLOT_GRANT_ROUNDS
rounds 2-7) ; `00-state §4.3` (cotes par tier, T3=20% rang-3) ; r02 §2.3 (slot-decline mal analysé).

### 2.3 DÉSACCORD SUR L'ORDRE — Le tableau d'intention des constantes est une PRÉCONDITION de la sim, pas un livrable P3

**Claim du brouillon v6 (§7.5, fin de section P3)** : le tableau d'intention des constantes
économiques (REROLL_COST / BUY_XP / GOLD_PER_ROUND / STREAK_CAP / SELL_REFUND_FRAC) est une
"documentation P3 à produire avant de tuner". En pratique, ce livrable arrive APRÈS les sims.

**Le problème logique :**

Un tableau d'intention des constantes dit : "cette constante est censée faire X". La sim mesure
"est-ce que cette constante fait X ?". Si le tableau n'existe pas avant la sim, on mesure sans
savoir quoi optimiser. Concrètement :

- Si `REROLL_COST=1` est "intentionnellement identique à l'achat rang-1 pour réduire la friction
  early" → la sim valide si cette friction est bien réduite sans détruire la tension mid.
- Si `REROLL_COST=1` est "copié de SAP par défaut sans intention explicite" (ce que les rounds
  1-5 ont révélé) → la sim ne peut pas valider une intention absente.

**La raison pour laquelle ce tableau est urgent :**

Les 5 rounds ont révélé que `REROLL_COST=1` n'a jamais été décidé intentionnellement (r05 §2.1).
`SLOT_DECLINE_GOLD=3` a été fixé arbitrairement sans analyse (r02 §2.3). `STREAK_CAP=3` n'a pas
été challengé sur ses implications psychologiques (r05 §2.2). Aucune de ces constantes n'a d'intention
documentée dans le code (`state.lua`) ou dans le PRD.

**Sans ce tableau, les sims P3 mesureront des comportements mais ne pourront pas trancher si
le comportement observé est voulu ou accidentel.** Ce n'est pas de la documentation — c'est
un socle décisionnel.

**Proposition concrète** : promouvoir ce tableau en **précondition de toute sim P3**, à rédiger
comme première tâche de P3 (avant `--xp-climax`). Format :

| Constante | Valeur actuelle | INTENTION DE DESIGN | Comportement attendu en sim | Signal d'alarme |
|---|---|---|---|---|
| `REROLL_COST` | 1 | TBD (garder tension faible vs scaler) | voir §7.5 | rerolls T3-4 > achat T3-4 → scaler |
| `BUY_XP_COST` | 4 | Décision réelle = 1 rang-4 sacrifié en T4 | tension max en T3-T4 | achat XP dominant en T1-2 → verrouillage |
| `GOLD_PER_ROUND` | 10 | Budget contraint sans banque | max 3 achats rang-1 | plainte de pauvreté systémique |
| `STREAK_CAP` | 3 | Égalisateur anti-snowball | +30% budget max en loss-streak | refus de jouer en loss-streak → tension excessive |
| `SELL_REFUND_FRAC` | 0.5 | Asymétrie engageante, coût de pivot | pivots tardifs rares | pivot rate > 30% en late → friction trop haute |
| `SLOT_DECLINE_GOLD` | 3 | Trade tall/wide (avec option C XP) | refus optimal < 60% des runs | refus systématique > 70% → trop avantageux |

**Ce tableau est l'ancre qui empêche de "tuner sans savoir quoi optimiser".** Il fait partie du
même esprit que `seed/decisions.md` pour le code moteur. Il doit précéder P3.

**Source** : r05 §3.4 (tableau proposé mais sans ordre clair) ; r02 §2.3 (slot-decline non analysé
depuis le début) ; principe "define the goal before measuring" (Machinations.io 2025,
`machinations.io/articles/balancing-f2p-economies-simulating-player-personas-and-progression-curves-with-machinations`) ;
progression-economy-prd §3 (intentions partielles, mais sans tableau explicite de ratios).

---

## 3. Propositions priorisées

### 3.1 [PRIORITÉ 0 — PRÉCONDITION] Rédiger le tableau d'intention des constantes AVANT d'écrire les sims P3

**Quoi** : créer une section `docs/roadmap-lab/seed/eco-decisions.md` (distinct de
`seed/decisions.md` qui couvre les décisions moteur) contenant :
- Le tableau de §2.3 ci-dessus pour chaque constante économique de `state.lua`
- Pour chaque constante : valeur actuelle + **intention de design tranchée** + comportement
  attendu en sim + signal d'alarme

**Pourquoi P0 et pas P3** : les sims `--reroll-cost-scaling` et `--xp-climax` mesurent une
"vérité vs intention". Sans intention documentée, les sims produisent des chiffres sans verdict.
**C'est 2-3h de travail éditorial, pas de code.**

**Décisions à trancher en rédigeant le tableau** :
1. Est-ce voulu que reroll (1 gold) = rang-1 (1 gold) en T1 ? Si oui : la tension vient des
   5 offres initiales. Si non : scaler.
2. Est-ce voulu que décliner un slot = +3 gold (+30% du budget) ? Si oui : le tall est fortement
   subventionné. Si non : option C (réduire or + ajouter XP).
3. Est-ce voulu que STREAK_CAP=3 donne +30% max de budget ? Si oui : documenter que c'est
   l'égalisateur principal (pas les cotes). Si non : calibrer le cap.

**Garde-fou** : document uniquement, 0 code, 0 invariant. **LECTURE SEULE du repo de jeu.**

### 3.2 [PRIORITÉ 1] Reformuler la question de sim REROLL_COST pour distinguer T1 (ratio 1:1) de T3+ (ratio 1:3 et au-delà)

**Quoi** : le drapeau `--reroll-cost-scaling` (§7.5) mesure actuellement "rerolls/round +
conversion vue→achat par tier". Ajouter deux métriques séparées :

```
-- Métrique A : "reroll_opportunity_cost" = P(reroll améliore l'offre) par tier
-- Mesure : sur N boutiques tier-1, combien de fois le reroll produit une unité
-- strictement meilleure que la meilleure unité déjà visible ?
-- Seuil : si P(amélioration) < 30% en T1 → le reroll est du bruit → REROLL_COST=1 peut rester
-- Seuil : si P(amélioration) > 60% en T1 → le reroll est dominant → envisager REROLL_COST=2

-- Métrique B : "reroll_by_tier_ratio" = (rerolls effectués) / (or total disponible) par tier
-- Si ratio T1 > 0.20 ET ratio T3 < 0.05 → asymétrie structurelle T1 vs T3 → scaler REROLL_COST
-- Si ratio T1 ≈ ratio T3 → le comportement est homogène → garder REROLL_COST=1
```

**Pourquoi c'est plus précis** : le vrai problème identifié est que le ratio 1:1 en T1 peut
rendre le reroll dominant **précisément là où la tension devrait commencer à s'établir**. Les
métriques actuelles (rerolls/round, conversion) ne capturent pas si le reroll est utilisé par
stratégie ou par défaut.

**Coût** : ~5-10 lignes de métriques dans `tools/sim.lua`. Pas de modification de la boucle.

**Garde-fou** : sim headless, 0 invariant, 0 code moteur.

### 3.3 [PRIORITÉ 2] Ajouter la co-calibration XP/slots au critère de sim `--xp-climax`

**Quoi** : ajouter la 4e condition au critère de sim de la courbe XP (§7.1) :

```
(4) co-calibration boutique/slots :
    pour chaque politique × durée de run :
    -- mesurer shopTier_moyen / slots_actifs_moyen par round
    -- cible : ratio < 1.5 à tout round (pas de déséquilibre "boutique forte + slots limités")
    -- si ratio > 1.5 pour la politique "rush_XP" → la valeur d'être en T3+ est diluée
       par les slots insuffisants → calibrer ensemble (ou limiter le rush aux rounds post-grant)
```

**Pourquoi cette métrique est manquante** : le critère actuel mesure "rush T5 coûte ≥20% du
budget" sans vérifier si T5 est **utilisable** à ce moment du run. Un T5 à round 3 avec 3 slots
est sous-utilisé (20% de chance de voir un rang-5 → difficile de remplir 3 slots avec des rang-5).

**Coût** : 3-4 lignes de métriques. Les données shopTier et slots sont déjà dans le run_state
(`state.lua:shopTier + slots`), donc traçables sans nouveau code.

**Garde-fou** : sim pure, 0 code moteur, 0 invariant.

### 3.4 [PRIORITÉ 3] Documenter explicitement que le ratio SAP reroll/achat n'est pas 1:1

**Quoi** : dans `docs/roadmap-lab/seed/eco-decisions.md` (§3.1), ajouter une note dans la
section REROLL_COST :

```
NOTE ANALOGIE SAP — CORRIGÉE ROUND 6 :
SAP : tous pets = 3 gold, reroll = 1 gold → ratio reroll/achat = 1:3 (jamais 1:1)
The Pit rang-1 : rang-1 = 1 gold, reroll = 1 gold → ratio reroll/rang-1 = 1:1 (UNIQUE)
→ L'argument "SAP fait 1 gold donc acceptable" ne s'applique qu'aux rangs 3+ où le ratio
  devient ≥1:3. En T1 (100% rang-1), The Pit n'a PAS d'équivalent dans la littérature citée.
→ La décision REROLL_COST=1 en T1 est ORIGINALE et DOIT être validée empiriquement.
```

**Pourquoi** : corriger une analogie incorrecte utilisée depuis r01. Ce n'est pas un argument
pour changer REROLL_COST — c'est un argument pour ne plus citer SAP comme justification en T1.

**Coût** : documentation pure, 2-3 lignes.

---

## 4. Questions ouvertes

### Q1 — Un ratio reroll/rang-1 de 1:1 est-il psychologiquement problématique ou fonctionnel ?

La question centrale non résolue. La réponse dépend de si la boutique T1 avec 5 offres de
rang-1 (pool de 12 unités) produit des offres suffisamment diversifiées pour que le "chercher
mieux" soit une vraie stratégie. Si les 5 offres T1 sont souvent identiques ou redondantes
(doublons de la même famille) → le reroll à 1:1 est stratégique (chercher la diversité).
Si les 5 offres T1 sont déjà diversifiées → le reroll est redondant (chercher ne rapporte rien).

À mesurer avec la métrique A de §3.2 : `P(reroll améliore l'offre)` en T1 sur N=200 boutiques.

### Q2 — La co-calibration XP/slots révèle-t-elle une incompatibilité entre rush XP et option C slot-decline ?

Si un joueur qui rush XP (passe T3-4 en rounds 1-3) ET refuse les slots (option C) → il a une
boutique puissante mais peu de slots. Est-ce un archétype viable (tall + boutique profonde) ou
un gaspillage structurel ?

La métrique de §3.3 `shopTier/slots_actifs` mesurerait cet effet. Si le ratio est > 1.5 pour
la combinaison (rush_XP + option_C), les deux systèmes se contredisent plutôt que de se
compléter → signal d'incompatibilité.

### Q3 — Les 5 offres de boutique (SHOP_SIZE=5) sont-elles suffisantes avec un pool de 12 unités rang-1 pour éviter les doublons ?

`SHOP_SIZE=5` + 12 unités rang-1 → P(doublon dans la boutique en T1) = ?

Calcul direct : tirage sans remise de 5 dans 12. P(aucun doublon) = C(12,5)/12^5 (approximation
grossière) ≈ 792/248832 ≈ 0.32%. En pratique (tirage avec remise) : P(≥1 doublon dans 5 tirages
parmi 12) = 1 - (12×11×10×9×8)/(12^5) = 1 - 95040/248832 ≈ 61.8% de chance d'avoir un doublon
dans la boutique T1. **Cela signifie que dans ~62% des boutiques T1, au moins 2 slots montrent
la même unité** → le reroll peut effectivement chercher la diversité (la même unité deux fois
est soit une opportunité de merge, soit du gaspillage de slot selon la stratégie).

Cette statistique justifie partiellement un reroll à 1 gold en T1 : si la boutique a un doublon
non voulu, reroller pour 1 gold = 1 rang-1 sacrifié est une décision raisonnable.

**Mais cela signifie aussi que le reroll en T1 est souvent utilisé pour "ne pas voir le même
rang-1 deux fois" plutôt que pour "chercher une unité spécifique"** — un comportement correct
mais mécanique qui peut diminuer la profondeur perçue.

À mesurer en sim : distribution des motifs de reroll en T1 (doublon évitement vs recherche
spécifique).

### Q4 — Le tableau d'intention doit-il être validé par l'utilisateur avant les sims P3 ?

Les rounds 1-5 ont révélé que plusieurs constantes (`REROLL_COST`, `SLOT_DECLINE_GOLD`) n'ont
pas d'intention documentée dans le code. Le tableau de §3.1 peut être rédigé par un agent, mais
les décisions tranchées (ex. "est-ce voulu que reroll=rang-1 en T1?") sont des choix de design
qui appartiennent à l'utilisateur, pas à la sim.

Recommandation : le tableau est rédigé avec des intentions proposées (marquées [TBD]) et soumis
à l'utilisateur pour validation avant de lancer les sims P3. Sans cette validation, les sims
mesurent vis-à-vis d'une intention hypothétique, pas décidée.

---

## 5. Synthèse des points clés pour la roadmap

### Ce qui change par rapport aux rounds 1-5 :

1. **L'analogie SAP pour REROLL_COST=1 est corrigée** : SAP a un ratio reroll/achat de 1:3,
   pas 1:1. The Pit a un ratio 1:1 uniquement au rang-1 en T1. La décision doit être justifiée
   par ses propres mérites (psychologie de la tension en T1 avec 12 unités rang-1), pas par
   analogie avec SAP.

2. **La co-calibration XP/slots est identifiée comme manquante** : les simulations `--xp-climax`
   doivent mesurer le ratio `shopTier/slots_actifs` pour détecter les stratégies qui créent
   un déséquilibre boutique-forte/slots-insuffisants.

3. **Le tableau d'intention des constantes est une PRÉCONDITION, pas un livrable P3** : sans
   intention documentée, les sims mesurent sans verdict possible. À rédiger avant P3.

### Ce qui reste inchangé et tient (6e confirmation globale) :

- Or fixe 10/round (non reporté) : correct, 6e confirmation sans contestation sérieuse
- XP TFT-style (passive + achetable, ratio 1:1) : structure saine
- Courbe `{2,5,10,18}` comme direction : correcte, calibration sous sim
- REROLL_COST=1 : décision à trancher en sim (§7.5), ni confirmé ni rejeté
- Formule daily `wins × (10−lives) × speed_mult` : saine (correction r02)
- Pity = `max(3, 0.5×médiane)` + progression visuelle implicite : accord fort
- Signal streak-loss lié au post-combat actionnable : adopté r05 §1.7
- Option C slot-decline (`+1 or + +1 XP passive`) : design correct, valeur à sim
- Déprio reliques F : accord fort, non contesté
- Tooltip de run avant daily : accord fort (r04 §3.4)

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` via `docs/roadmap-lab/00-state.md §4.1`
  (REROLL_COST=1, GOLD_PER_ROUND=10, START_SLOTS=3, MAX_SLOTS=9, SLOT_GRANT_ROUNDS rounds 2-7,
  BUY_XP_AMOUNT=4/COST=4, STREAK_CAP=3, SELL_REFUND_FRAC=0.5)
- `docs/roadmap-lab/ROADMAP-draft.md` v6 §7.1/§7.5 (drapeaux sim, courbe XP, REROLL_COST)
- `docs/roadmap-lab/round-01.md` à `round-05.md` (synthèses précédentes)
- `docs/roadmap-lab/rounds/r01-r05-progression-economy.md` (corpus des 5 rounds précédents)
- `docs/research/progression-economy-prd.md` §3 (PRD, intentions de calibrage)

**Sources web (vérifiées) :**
- [Super Auto Pets Gold Wiki — superautopets.wiki.gg/wiki/Gold](https://superautopets.wiki.gg/wiki/Gold)
  (OR = 10/round non reporté ; reroll = 1 gold ; pets = 3 gold fixe → ratio reroll/achat = 1:3)
- [Super Auto Pets Shop Fandom — superautopets.fandom.com/wiki/Shop](https://superautopets.fandom.com/wiki/Shop)
  (reroll = 1 gold, pets = 3 gold, confirmé)
- [Ultimate Guide SAP — twoaveragegamers.com](https://www.twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/)
  (pets 3 gold, reroll 1 gold — ratio 1:3, jamais 1:1 ; gold = 10/round, non reporté)
- [TFT Economy Guide — boosteria.org](https://boosteria.org/guides/tft-economy-guide-interest-level-timers-rolling-windows)
  (rolling windows = décision stratégique ; "roll when it has a clear purpose" ; l'agonise sur
  chaque reroll vient de la tension réelle → confirme que le ratio doit créer une décision)
- [Balancing F2P Economies — machinations.io](https://machinations.io/articles/balancing-f2p-economies-simulating-player-personas-and-progression-curves-with-machinations)
  (principe : définir les objectifs avant de mesurer = "the simulation confirmed the system is
  balanced" seulement parce que les objectifs de balance étaient préalablement définis)
- [TFT XP Seuils — lolchess.gg/guide/exp](https://lolchess.gg/guide/exp?hl=en)
  (seuils cumulés T2-T9 : 2, 6, 10, 20, 36, 56, 80, 100 — super-linéaires ; passive = 2/round)
- [SAP Mechanics Analysis — a327ex.com](https://a327ex.com/posts/super_auto_pets_mechanics)
  (« une des mécaniques les plus transferables » des shop rerolling games ; confirme que le ratio
  reroll/achat est une décision de design centrale)
- [SAP First Round Teams — brooklyndistance.com](https://www.brooklyndistance.com/SuperAutoPetsFirstRound)
  (maths de boutique SAP : déterminisme + Nash equilibria montrent que la tension vient de la
  composabilité des triggers, pas du prix brut des unités — argument pour que la tension vienne
  de la diversité des offres en T1 même avec reroll à 1 gold)

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 6. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants non modifiés.
Désaccords sourcés par code + web. Propositions chiffrées ancrant les constantes dans state.lua.*
