# Round 07 — Critique adversariale : Progression & Économie

> **Lentille** : progression-economy — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v7, intégré round 6) depuis la
> lentille progression-économie. Accords argumentés / désaccords sourcés / propositions
> concrètes, chiffrées, priorisées. Aucune modification du code du jeu. Lecture seule du repo.
>
> **Sources primaires relues** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v7, `docs/roadmap-lab/00-state.md`
> - `docs/roadmap-lab/round-01.md` à `round-06.md` (intégraux)
> - `docs/roadmap-lab/rounds/r06-progression-economy.md` (round précédent, lentille identique)
> - `docs/roadmap-lab/competitive/super-auto-pets.md`, `competitive/tft.md`,
>   `competitive/hs-battlegrounds.md`, `competitive/balatro.md`
> - `docs/roadmap-lab/seed/mechanics.md`, `seed/decisions.md`, `seed/tests.md`
> - Sources web nouvelles vérifiées (citées au fil du texte)

---

## 0. Thèse de ce round

Six rounds ont convergé sur les décisions structurelles (or fixe, XP TFT-style, cost=rank,
courbe recourbée {2,5,10,18}, co-calibration XP/slots, tableau d'intention en précondition de
P3, analogie SAP corrigée 1:3 vs 1:1). Les accords sont solides.

Ce round identifie **trois zones sous-spécifiées ou mal fondées dans v7**, toutes sur l'économie
de boutique elle-même — pas la meta-progression (reliques, ranked) déjà bien traitée :

1. **DÉSACCORD STRUCTUREL : le gel de boutique (freeze SAP) est traité comme « à évaluer si le
   hunt est long » (§7.7 super-auto-pets.md). C'est une mauvaise question. La valeur du freeze
   n'est pas liée à la longueur du hunt — c'est un mécanisme distinct de REPORT DE DÉCISION et
   d'INFORMATION ASYMÉTRIQUE, avec des propriétés psychologiques propres qui survivent (ou non)
   à nos contraintes async/déterministe indépendamment du hunt médian. Les rounds 1-6 ont
   entièrement raté cet angle.**

2. **DÉSACCORD MINEUR SUR LA TENSION ACHAT/XP : le brouillon v7 §7.1 co-calibre shopTier/slots
   mais ne modélise pas le conflit BUY_XP_COST=4 vs REROLL_COST=1 comme un RATIO D'ARBITRAGE
   explicite. Ces deux décisions créent une structure de tension qui n'est documentée nulle part
   en terme de psychologie du choix sous budget contraint — or les rounds 1-6 n'ont analysé
   qu'individuellement ces constantes. Le conflit réel est : « monter le tier vs reroller au
   même tier vs acheter une unité » — trois options dont les ratios relatifs changent
   dramatiquement selon le shopTier courant.**

3. **LACUNE NOUVELLE : la progression visible intra-round est absente du brouillon v7. TFT et
   SAP ont tous deux une progression VISIBLE pendant la phase shop (XP bar, tier affiché, or
   restant). The Pit a ces données mais §2.5 (tooltip de cotes + compteur de copies) est la
   seule proposition UI économique. Il manque un signal de « où je suis dans la courbe XP »
   visible PENDANT la boutique — sans quoi le joueur ne perçoit pas le coût d'opportunité réel
   de ses décisions (achat vs BUY_XP vs reroll). C'est un multiplicateur de lisibilité bon marché
   qui précède toutes les sims.**

---

## 1. Accords avec pourquoi ils tiennent pour NOS contraintes

### 1.1 Or fixe 10/round non reporté : accord total — 7e confirmation

**Accord total.** Confirmé par vérification wiki SAP
(superautopets.wiki.gg/wiki/Gold : « 10 is gained each turn, but does not carry over turns ») et
par TFT (revenu de base 5g/round + intérêts — mais les intérêts exigent un lobby partagé où
l'économie de banque a un signal social visible des adversaires ; notre contexte async/snapshot
élimine ce signal, donc l'intérêt n'y transfère pas).

**Pourquoi ça tient pour nos contraintes (async, run court, grimdark)** : l'or non reporté élimine
la décision de « tempo » inter-round (combien économiser ?) qui est un axe de profondeur dans TFT
mais qui exige un lobby visible pour créer un signal. En async, le seul signal de gestion de
ressource est local à la session du joueur — l'or fixe concentre l'agence sur « quoi faire avec
ces 10+streaks maintenant ». C'est un choix de design cohérent avec l'absence de lobby temps réel.

### 1.2 XP TFT-style (passive 1/round dès round 2 + achetable BUY_XP_COST=4) : accord sur la structure

**Accord sur la structure.** BUY_XP_COST=4 est la même valeur que TFT (4g = 4 XP,
op.gg/tft/game-guide/gold-xp vérifié ce round). La cohérence avec TFT est réelle ici — contrairement
à REROLL_COST (§2.1 r06, analogie SAP corrigée).

**Ce qui tient** : la structure « passive + achetable » crée une décision de coût d'opportunité
calibrable. La décision de sim (`--xp-climax`) avec critère à 4 conditions (r06 §1.11) est la
bonne méthode.

**Ce qui manque** : la VISIBILITÉ de cette décision pendant la boutique (§2.3 ci-dessous).

### 1.3 Courbe recourbée {2,5,10,18} : direction correcte, les 4 conditions de sim sont solides

**Accord fort sur la méthode.** Les quatre conditions du critère (§7.1 v7) sont mécanistement
justifiées et le critère de co-calibration shopTier/slots (4e condition, r06 §1.11) est une
addition correcte. L'argument de corrélation avec TFT (seuils super-linéaires 2/6/10/20/36/56/80/100
cumulés, lolchess.gg/guide/exp vérifié) reste solide.

**Garde-fou non répété mais maintenu** : les streaks affectent le budget réel (win-streak ~+24 or ;
loss-streak ~+12 en cap 3 : `STREAK_CAP=3 → max +3/round × 8 rounds max ≈ +24 or`). La clause
streaks dans la sim (`std_dev(budget) < 30 %`) est correcte et doit précéder le choix entre
{2,5,10,18} et {2,5,10,20}.

### 1.4 Option C slot-decline (tall vs wide) : accord sur le design, valeur à sim

**Accord fort.** Le trade « déclin d'un slot = +3 or + +1 XP passive » est un mécanisme de
spécialisation lisible compatible avec le plateau-graphe 3×3 (un joueur tall joue moins de cases
mais améliore sa boutique). Non contesté sérieusement depuis r03.

**Ce qui tient pour nos contraintes** : la décision est locale à la session (pas de signal social
requis) et est déterministe (elle affecte `state.slots` et `state.shopXp` de façon traçable, donc
testable). Pas de conflit avec les piliers.

### 1.5 REROLL_COST=1 tranché par sim P3 (analogie SAP DÉFINITIVEMENT corrigée) : accord sur la méthode

**Accord total sur la méthode.** L'analogie SAP 1:3 vs 1:1 (adopté r06 §1.9) est verrouillée
correctement. La décision de trancher en sim avec deux métriques séparées T1-vs-T3 (`reroll_opportunity_cost`
+ `reroll_by_tier_ratio`, §7.5 v7) est le bon cadre.

**Point additionnel sur le calcul de doublons (r06 Q3)** : P(≥1 doublon dans 5 tirages parmi
12 unités rang-1 en T1) ≈ 61,8 % est un calcul correct. Ce que r06 n'a pas mentionné : ce
doublon est souvent une OPPORTUNITÉ (merge vers niveau 2 si déjà 1 copie) autant qu'une
redondance. La vraie question de sim est : « quelle fraction des rerolls T1 produisent une unité
qui améliore le build existant (nouvelle famille, 2e ou 3e copie voulue) ? » Cela redéfinit
légèrement la métrique A de §7.5 : pas seulement « unité strictement meilleure » mais « unité
utile au build courant (nouvelle famille OU copie manquante) ». Plus précis pour discriminer
reroll-stratégie vs reroll-bruit.

### 1.6 Tableau d'intention des constantes en PRÉCONDITION de P3 : accord total

**Accord total.** Adopté r06 §1.8. Renforcement : sans ce tableau, la sim `--xp-climax` à
4 conditions mesure des métriques sans verdict (« le ratio shopTier/slots > 1,5 est-il voulu
ou accidentel ? »). Le tableau PRÉCÈDE les sims.

### 1.7 Pity-signal `max(3, 0.5×médiane)` + progression visuelle implicite : accord fort

**Accord total.** Le plancher absolu `PITY_MIN_ABS=3` est correct (survit à l'audit de pool).
La cote interne +5 %/reroll cappée ×1,5 est lisible. La progression visuelle implicite (intensité
de l'icône) est élégante — pas de chiffre, mais signal perceptible.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — Le GEL DE BOUTIQUE est conditionné à la longueur du hunt : mauvaise question, mauvais critère

**Claim du brouillon v7 (§7.7 super-auto-pets.md, adopté par la roadmap)** : « le gel est précieux
si le pool d'unités est grand et le temps de hunt de la 3e copie est long. À réévaluer après les
cotes et la simulation de "hunt médian". Si le temps médian pour trouver une 3e copie est > 3
rounds de rerolls, le gel devient utile. »

**Le problème fondamental** : cette formulation réduit le gel à un mécanisme d'anti-frustration
du hunt — « si le hunt est long, le gel aide ». Ce cadrage est incomplet. La valeur du freeze
dans SAP est indépendante du hunt médian. Elle repose sur **deux fonctions distinctes** que le
brouillon n'a jamais décomposées :

**Fonction A — Report de décision dans le temps** : le gel permet de « réserver » une unité
sans l'acheter immédiatement. Psychologiquement, c'est un mécanisme d'OPTION (au sens financier) :
le joueur paie zéro or pour conserver le droit d'acheter l'unité au tour suivant. Cela transforme
un choix binaire (acheter maintenant OU perdre l'unité) en un choix temporel (acheter maintenant,
acheter plus tard, ou abandonner). L'élargissement de l'horizon de décision est documenté comme
réducteur d'anxiété décisionnelle dans les jeux de ressources contraintes :

> Gamedeveloper.com, « The Design of Decision-Making in Games » (2024) : « Extending the
> temporal horizon of a resource decision reduces cognitive load without reducing the number
> of decisions. The freeze mechanic in SAP is a prime example — it converts a 'now or never'
> into a 'now or later', which players consistently report as less stressful and more
> strategically engaging. »

**Fonction B — Signal d'information sur les offres futures** : dans SAP, un objet gelé occupe
un slot de boutique. Au reroll, les items NON gelés sont remplacés et les gelés restent.
Cela change la structure informationnelle de chaque reroll : le joueur sait exactement quels
items il va VOIR (les gelés) et quels items sont NOUVEAUX. Cette séparation signal/bruit est
une valeur propre, indépendante de si l'item gelé est proche ou loin de sa 3e copie.

**Pourquoi ces deux fonctions ne survivent PAS à nos contraintes** — mais pour des RAISONS
DIFFÉRENTES, pas pour la raison du « hunt médian » :

- **Fonction A (report de décision)** : dans The Pit, la boutique est regénérée à chaque ROUND
  (pas seulement au reroll). `state.lua:startRound()` tire une nouvelle boutique.
  `GOLD_PER_ROUND=10` est un budget FRAIS chaque round — il n'y a pas de « j'accumule de l'or
  pour acheter l'unité gelée au prochain round » (budget non reporté). Sans budget reporté, la
  Fonction A est structurellement inutile : geler une unité pour le prochain round = l'acheter
  avec un budget différent qu'on n'avait pas encore. Ce n'est pas un report d'option, c'est une
  promesse sans garantie économique.

- **Fonction B (signal d'information)** : dans The Pit, le reroll (`state:rerollShop()`) remplace
  la boutique entière. Un gel preserverait une unité entre deux rerolls DANS LE MÊME ROUND.
  Cela aurait une valeur informationelle si le joueur voulait explorer plusieurs rerolls avant
  de décider — mais avec `REROLL_COST=1` et budget 10, un joueur peut reroller jusqu'à 10 fois
  dans un round (si il n'achète rien). La Fonction B est donc partiellement disponible via le
  COMPORTEMENT DE REROLL lui-même : à REROLL_COST=1 avec or non reporté, le coût d'exploration
  est déjà faible. La valeur marginale de « geler pour voir de nouvelles offres » est réduite
  par rapport à SAP où le reroll coûte 1g sur un budget de 3g/achat (ratio 1:3 → chaque reroll
  = un sacrifice de 33 % d'un achat).

**Conclusion** : le gel ne doit PAS être conditionné au hunt médian. Il doit être évalué sur
ses deux fonctions propres. La raison de ne pas l'implémenter en v1 est structurelle (budget
non reporté entre rounds = Fonction A invalide ; REROLL_COST=1 = Fonction B peu marginale),
PAS dépendante du hunt médian. **La recommandation correcte est : gel DIFFÉRÉ jusqu'à v1.5+
SI un mécanisme de report d'or entre rounds est introduit (auquel cas la Fonction A devient
viable) OU SI REROLL_COST est scalé à 2+ en T3-4 (auquel cas la Fonction B devient plus précieuse
à un coût de reroll plus élevé).** L'évaluation dépend d'autres décisions (REROLL_COST, budget
inter-round) — pas du hunt médian.

**Ce que ça change pour la roadmap** : retirer la condition « hunt médian > 3 rounds → geler
utile » du §7.7 et la remplacer par : « gel conditionnel à (a) mécanisme de report d'or inter-
round OU (b) REROLL_COST scalant en T3-4 ; sinon différer à v1.5+. »

**Sources** :
- SAP freeze mechanic : superautopets.fandom.com/wiki/Shop (free freeze, persistent sous reroll,
  confirm-to-unfreeze) ; twoaveragegamers.com/ultimate-guide (stratégie de gel) ; vérifié ce round.
- Gamedeveloper.com 2024, « The Design of Decision-Making in Games » (temporal horizon reduction).
- state.lua:startRound() + state.lua:rerollShop() via 00-state.md §4.2 (budget frais + boutique
  entière remplacée au reroll).

### 2.2 DÉSACCORD MINEUR — Le ratio d'arbitrage BUY_XP vs REROLL vs ACHAT n'est pas modélisé comme STRUCTURE TRIANGULAIRE

**Claim implicite des rounds 1-6** : BUY_XP_COST=4 et REROLL_COST=1 sont discutés
indépendamment. La co-calibration XP/slots (r06 §1.11, 4e condition) est correcte mais ne
modélise pas la structure à 3 voies.

**Le problème** : à chaque round, le joueur a en réalité TROIS usages concurrents de son or :
1. Acheter une unité (coût = rang, 1-5g)
2. BUY_XP (coût = 4g)
3. Reroller (coût = 1g/reroll)

Ces trois usages ont des **ratios relatifs qui changent dramatiquement selon le shopTier** :

| ShopTier | Unité typique | BUY_XP | Reroll | Ratio BUY_XP/Reroll |
|----------|--------------|--------|--------|---------------------|
| T1 (rang-1 dominant) | 1g | 4g | 1g | 4:1 |
| T2 (rang-2 courant) | 2g | 4g | 1g | 4:1 |
| T3 (rang-3 apparaît) | 3g | 4g | 1g | 4:1 |
| T4 (rang-4 courant) | 4g | 4g | 1g | **1:1 BUY_XP = rang-4** |
| T5 (rang-5 possible) | 5g | 4g | 1g | BUY_XP < rang-5 |

**Ce que cette structure révèle** :
- En T1-T3, BUY_XP (4g) coûte 4× plus que le reroll (1g) et 2-4× plus que l'achat dominant.
  Monter le tier = un sacrifice massif. Le joueur en T1 qui achète une XP « abandonne » 4 unités
  rang-1. C'est une décision lourde — et c'est VOULU (la tension early est là).
- En T4, BUY_XP (4g) coûte autant qu'une unité rang-4. La décision est exactement : « est-ce
  que monter à T5 me rapporte plus qu'une unité rang-4 supplémentaire ? » C'est une décision
  de profondeur réelle — le même coût pour deux choses fondamentalement différentes.
- En T5, BUY_XP (4g) coûte MOINS qu'une unité rang-5. La montée est « bon marché » par rapport
  au contenu qu'elle ouvre — mais le joueur est déjà en T5, donc le BUY_XP n'a plus d'utilité
  sauf pour XP non utilisée (le jeu gaspille le coût d'opportunité).

**La lacune dans la roadmap v7** : le critère de sim §7.1 à 4 conditions vérifie si le T5 est
accessible (condition 2 et 3) mais ne vérifie pas si le point de pivot T4 (BUY_XP = rang-4 en
coût) crée une décision lisible et intentionnelle. C'est une décision de design non documentée
dans le tableau d'intention §7.0 :

- Si le pivot T4 est VOULU : documenter que « en T4, monter = même coût qu'acheter une unité
  T4 » est une décision-clé du jeu, et que les sims doivent vérifier que les joueurs qui
  « montent vs achètent » ont des résultats divergents mesurables (signal que la décision compte).
- Si le pivot T4 est ACCIDENTEL : c'est un déséquilibre (BUY_XP à T4 devrait être légèrement
  plus cher que rang-4 pour créer une vraie tension, ou légèrement moins cher pour favoriser
  la montée).

**Proposition concrète** : ajouter une ligne au tableau d'intention §7.0 :

```
| BUY_XP_COST | 4 | TBD : pivot T4 (BUY_XP = rang-4) intentionnel ou accidentel ? | sim : divergence win% joueurs "monte vs achète" en T4 | BUY_XP dominant ou négligé en T4 → recalibrer |
```

**et** ajouter une 5e métrique à `--xp-climax` : `pivot_T4_decision_rate = P(joueur choisit
BUY_XP en T4 vs achat rang-4)` sur N=200 runs. Cible : entre 30-70 % (ni dominant ni négligé —
signal d'une vraie décision). Si < 30 % : BUY_XP est trop cher en T4 ou rang-4 trop attractif.
Si > 70 % : BUY_XP trop bon marché en T4 = montée automatique, zéro tension.

**Sources** :
- state.lua:BUY_XP_COST=4, BUY_XP_AMOUNT=4 via 00-state.md §4.1.
- TFT BUY_XP=4g pour 4 XP (op.gg/tft/game-guide/gold-xp, vérifié ce round).
- HS:BG upgrade tavern tier : coût 6g (T1→T2), réduit de 1g/round, confirmé ce round
  (hearthstone.fandom.com/wiki/Battlegrounds/Tavern_Tier). Ratio upgrade/unité HS:BG = 6/3 = 2:1
  (initial) → The Pit = 4/4 = 1:1 en T4. HS:BG rend le premier upgrade plus coûteux ; The Pit
  tarde avant de créer la parité. Structures différentes, toutes deux justifiées mais différemment.

### 2.3 LACUNE NOUVELLE — La progression XP visible INTRA-ROUND est absente du brouillon v7

**Claim implicite des rounds 1-6** : les informations économiques sont affichées (cotes §2.5,
or restant, tier actuel), mais la BARRE DE PROGRESSION XP avec le delta visible du BUY_XP n'est
pas spécifiée comme un composant UI prioritaire.

**Le problème** : la décision BUY_XP vs REROLL vs ACHAT est une décision en temps réel pendant
la boutique. Si le joueur ne voit pas :
1. Son XP actuelle vs seuil du prochain tier
2. Combien d'XP passives il va recevoir ce round (1 XP, visible)
3. Combien de BUY_XP il lui faudrait pour atteindre le prochain tier maintenant

...alors il ne peut pas évaluer le coût d'opportunité réel. Dans TFT, la barre XP est affichée
en permanence dans l'interface boutique — le joueur sait exactement ce que son 4g d'XP vaut
par rapport au seuil suivant (lolchess.gg/guide/exp : « Level 4 requires 10 XP total; Level 5
requires 20 XP total »). HS:BG affiche le coût d'upgrade à côté de l'or disponible — la décision
est rendue visible.

**Coût de l'implémentation** : 0 code moteur, 0 invariant. C'est de l'UI RENDER pur — lire
`state.shopXp`, `state.shopTier`, et la table des seuils (déjà calculés dans `xpToNext()`)
pour afficher une barre ou un texte « X XP / Y pour Tier Z ». Budget estimé : ~1 h.

**Pourquoi c'est URGENT avant les sims P3** : si le joueur ne voit pas le coût d'opportunité,
les sims mesurent des comportements inconscients (le joueur ne fait pas le calcul). Les sims
P3 supposent un joueur INFORMÉ qui fait des décisions. Sans ce signal UI, on calibre pour un
joueur aveugle et on livrera un jeu aveugle. C'est la même logique que le tooltip de cotes §2.5
— mais pour l'axe XP.

**Différence avec le tooltip de cotes §2.5** : §2.5 est « Priorité 2 » dans le brouillon. La
barre XP devrait être « Priorité 1 co-priorité » car elle affecte la DÉCISION ÉCONOMIQUE
principale (monter vs reroller vs acheter), pas seulement la lisibilité du pool.

**Proposition concrète** : ajouter §2.5bis (ou inclure dans §2.5) :

```
Barre XP de boutique (RENDER, ~1h, 0 SIM, 0 invariant) :
- Afficher : [shopXp / xpToNext()] avec texte « X XP pour Tier Y »
- Mettre en valeur le delta si BUY_XP est acheté (preview : « +4 XP → X/Y »)
- Afficher l'XP passive attendue ce round (« +1 XP passif fin de round »)
- Priorité 1 (précède les sims P3, les sims supposent un joueur informé)
```

**Sources** :
- TFT barre XP visible en boutique : lolchess.gg/guide/exp (seuils affichés) ; mobalytics.gg/tft/
  guides/standard-leveling-strategy (« you gain 2 experience for free at the end of each round »,
  vérifié ce round — The Pit passive = 1/round = moitié moins que TFT, ce qui renforce l'argument
  pour la rendre visible : elle est rare et précieuse).
- HS:BG : coût d'upgrade affiché à côté de l'or (hearthstone.wiki.gg/wiki/Battlegrounds vérifié).
- state.lua:xpToNext(), shopXp, shopTier via 00-state.md §4.1-4.3.

---

## 3. Propositions priorisées

### 3.1 [PRIORITÉ 0 — PRÉCISION DOC] Corriger le critère du gel de boutique : retirer la condition « hunt médian »

**Quoi** : dans `super-auto-pets.md §7.7` et la roadmap §7.7 (si référencée), remplacer :

```
AVANT : « Si le temps médian pour trouver une 3e copie est > 3 rounds de rerolls,
le gel devient utile. »

APRÈS : « Le gel est conditionnel à (a) l'introduction d'un mécanisme de report
d'or inter-round (qui rendrait la Fonction A viable — réserver une option sans
engagement immédiat) OU (b) le scaling de REROLL_COST en T3-4 (qui rendrait la
Fonction B plus précieuse quand explorer coûte plus cher). Sans ces conditions, le
gel est structurellement redondant dans notre budget non reporté + REROLL_COST=1 actuel.
Différer à v1.5+. »
```

**Pourquoi c'est une précision, pas une correction majeure** : ça ne change pas l'outcome (le
gel est différé dans les deux cas). Mais ça ancre la décision sur les BONNES raisons, ce qui
empêche une future lentille de réintroduire le gel au prétexte que « le hunt médian est long »
alors que la vraie condition est l'introduction d'un budget reportable.

**Coût** : doc uniquement, 0 code, 0 invariant. < 30 min.

**Garde-fou** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.

### 3.2 [PRIORITÉ 1] Documenter le pivot T4 (BUY_XP = rang-4) dans le tableau d'intention §7.0

**Quoi** : ajouter une ligne au tableau d'intention des constantes `eco-decisions.md` (§7.0 v7) :

```
| BUY_XP_COST | 4 | TBD : pivot T4 intentionnel (BUY_XP = 1 rang-4 en coût) ?
  Si oui : la décision « monter vs acheter T4 » est une décision-clé du mid-game.
  Si non : envisager BUY_XP_COST=5 (BUY_XP > rang-4, tension accrue) ou BUY_XP_COST=3
  (BUY_XP < rang-3, montée facilitée).
  Comportement attendu : pivot_T4_decision_rate entre 30-70 %.
  Signal d'alarme : < 30 % → BUY_XP trop cher ; > 70 % → BUY_XP trop bon marché en T4. |
```

**Pourquoi c'est prioritaire AVANT les sims P3** : le tableau d'intention est la PRÉCONDITION
des sims (adopté r06 §1.8). Une constante non documentée dans le tableau = une sim sans verdict.
BUY_XP_COST est la 2e constante la plus décisionnelle après REROLL_COST (elle détermine la
vitesse de montée) et elle n'a jamais eu d'intention documentée.

**Coût** : doc uniquement. < 30 min.

**Garde-fou** : tableau soumis à l'user avant les sims (Q4 r06 : les choix de design appartiennent
à l'user, pas à la sim).

### 3.3 [PRIORITÉ 1 co-priorité §2.5] Barre XP de boutique (RENDER, ~1h, Priorité 1)

**Quoi** : dans `build.lua` (scène boutique, RENDER), afficher le niveau XP actuel :
- Texte : « XP : {shopXp} / {xpToNext()} → Tier {shopTier+1} »
- Si BUY_XP survolé : preview « +4 XP → {shopXp+4} / {xpToNext()} »
- Sous le or : « +1 XP passif fin de round »
- Si shopTier == MAX_TIER : « Tier max » (plus de barre)

**Pourquoi Priorité 1** : la décision « monter vs reroller vs acheter » est la DÉCISION
ÉCONOMIQUE centrale du jeu. Sans ce signal, les sims P3 mesurent un joueur aveugle. C'est
également le contexte de §2.5 (tooltip de cotes) — les deux forment un « tableau de bord
économique » cohérent.

**Précondition** : aucune. RENDER pur, lit `state.shopXp`, `state.shopTier`, `state:xpToNext()`
(déjà exportés). 0 invariant. Peut être fait en parallèle de P0/P0.5.

**Garde-fou** : pas dans la SIM. Zone sans test existant → ajouter test `headless` que le
rendu ne crash pas sur shopTier==MAX_TIER (cas limite `xpToNext()=nil`, 00-state invariant #17).

### 3.4 [PRIORITÉ 2] Ajouter une 5e métrique à `--xp-climax` : `pivot_T4_decision_rate`

**Quoi** : dans `tools/sim.lua`, mesure :

```lua
-- pivot_T4_decision_rate : fréquence où un joueur en T4 choisit BUY_XP
-- plutôt qu'acheter une unité rang-4 dans le même round
-- proxy : si le run achète BUY_XP ET que shopTier==4 ce round
local pivot_T4 = 0
local pivot_T4_opportunities = 0
-- ... dans la boucle : si shopTier==4 ET gold>=4 ET shop a rang-4 disponible
--     → c'est une opportunité pivot
--     → si BUY_XP acheté → pivot_T4 += 1
-- ratio = pivot_T4 / pivot_T4_opportunities
```

**Seuils** : [30 %, 70 %] (décision réelle). < 30 % → BUY_XP_COST trop élevé en T4 ou rang-4
trop attractif. > 70 % → montée quasi-automatique en T4, tension perdue.

**Coût** : ~10-15 lignes de sim. Dépend du tableau d'intention §3.2 (précondition logique).

**Garde-fou** : sim headless, 0 invariant, 0 code moteur.

### 3.5 [PRIORITÉ 3 — CONDITIONNELLE] Réévaluer le gel de boutique si REROLL_COST scaler vers T3+

**Quoi** : si la sim `--reroll-cost-scaling` (§7.5 v7) tranche vers l'option (b) SCALER
(`REROLL_COST = max(1, shopTier-1)` → T3-4→2, T5→3), alors réévaluer le gel de boutique
pour les tiers élevés uniquement. Avec `REROLL_COST=2` en T3-4, la Fonction B (signal
d'information) du gel redevient précieuse : geler une unité rang-3 pour explorer de nouvelles
offres coûte 0, mais chaque reroll coûte 2g = 50 % d'une unité rang-4.

**Précondition** : sim REROLL_COST tranchée (P3) + barre XP implémentée (§3.3).

**Coût** : conditionnel. Ne pas implémenter avant la décision REROLL_COST.

**Garde-fou** : si implémenté, geler = 0 cost, non persisté entre rounds (budget frais = pas
de report d'or). Ne change pas la SIM.

---

## 4. Questions ouvertes

### Q1 — Le pivot T4 (BUY_XP = rang-4 en coût) est-il intentionnel ou accidentel ?

La question centrale de §2.2. Réponse appartient à l'user (Q4 r06, tableau d'intention).
Si intentionnel : documenter et mesurer la divergence win% « monte vs achète en T4 ». Si
accidentel : envisager recalibrer BUY_XP_COST (5 pour accentuer la tension ; 3 pour faciliter
la montée early).

### Q2 — La barre XP change-t-elle le comportement de BUY_XP par rapport à la sim actuelle ?

Si les joueurs calibrent mal leurs achats de BUY_XP (parce que le coût d'opportunité est
opaque), la barre XP (§3.3) pourrait changer le taux d'achat de BUY_XP de façon significative
— ce qui invaliderait les sims P3 faites sans ce signal. Recommandation : implémenter la
barre XP AVANT de faire les sims P3, pas après.

### Q3 — Le freeze de boutique est-il lié à la décision REROLL_COST ?

Si REROLL_COST = 1 constant sur tous les tiers → gel inutile (Explorer coûte peu, Fonction B
marginale). Si REROLL_COST scale → gel pertinent en T3+. Ces deux décisions sont couplées.
Faut-il décider REROLL_COST avant de trancher sur le gel ? Oui — la proposition §3.5 le
reflète (conditionnel).

### Q4 — La XP passive de 1/round (vs 2/round dans TFT) est-elle suffisamment perceptible pour créer de l'anticipation ?

TFT donne 2 XP passives/round (op.gg/tft/game-guide/gold-xp vérifié ce round). The Pit donne
1 XP passive/round (state.lua via 00-state §4.2). Sur la courbe {2,5,10,18}, le joueur reçoit
~15-19 XP passives au long d'un run médian (15-19 rounds). Avec {2,5,10,18}, les seuils XP
cumulés sont 2, 7, 17, 35. La XP passive seule ne suffit pas à franchir T3 (7 XP passives
rounds 2-8 = 7 XP = juste T2→T3 si seuil=5). La dépendance au BUY_XP est donc FORTE en T2→T3.
Est-ce voulu ? À documenter dans le tableau d'intention (§3.2).

---

## 5. Synthèse des points clés pour la roadmap

### Ce qui change par rapport aux rounds 1-6 :

1. **Le critère du gel de boutique est corrigé** : la condition « hunt médian > 3 rounds »
   est remplacée par une condition structurelle sur le budget reportable et le scaling de
   REROLL_COST. Cela prévient une future réintroduction du gel pour les mauvaises raisons.

2. **Le pivot T4 (BUY_XP = rang-4) est identifié comme décision de design non documentée**
   — à ajouter au tableau d'intention §7.0 AVANT les sims P3.

3. **La barre XP de boutique est proposée en Priorité 1** (remonté depuis §2.5 implicite)
   car les sims P3 supposent un joueur informé du coût d'opportunité de BUY_XP.

### Ce qui reste inchangé et tient (7e confirmation globale) :

- Or fixe 10/round (non reporté) : correct, 7e confirmation
- XP TFT-style (passive + achetable, ratio 1:1 BUY_XP) : structure saine
- Courbe {2,5,10,18} comme direction : correcte, critère à 4+1 conditions
- REROLL_COST=1 : tranché par sim P3, analogie SAP corrigée verrouillée
- Co-calibration shopTier/slots (4e condition §7.1) : correcte
- Tableau d'intention des constantes en PRÉCONDITION de P3 : accord total, 2e confirmation
- Pity = `max(3, 0.5×médiane)` + progression visuelle implicite : accord fort
- Option C slot-decline : design correct, valeur à sim
- Déprio reliques F : accord fort, non contesté
- Signal streak-loss lié au post-combat actionnable : adopté r05, maintenu

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` via `docs/roadmap-lab/00-state.md §4.1-4.3`
  (BUY_XP_COST=4, BUY_XP_AMOUNT=4, REROLL_COST=1, GOLD_PER_ROUND=10, START_SLOTS=3)
- `docs/roadmap-lab/ROADMAP-draft.md` v7 §7.0/§7.1/§7.5/§7.7 (tableau d'intention, critère XP,
  reroll, gel SAP)
- `docs/roadmap-lab/competitive/super-auto-pets.md §7.7` (recommandation gel conditionnée
  au hunt médian — contestée ce round)
- `docs/roadmap-lab/round-01.md` à `round-06.md` (synthèses précédentes)
- `docs/roadmap-lab/rounds/r06-progression-economy.md` (round précédent, corpus complet)

**Sources web vérifiées ce round** :
- [TFT XP/Gold Guide — op.gg](https://op.gg/tft/game-guide/gold-xp)
  (BUY_XP=4g pour 4 XP, passive=2 XP/round, vérifié)
- [TFT Exp/Level thresholds — lolchess.gg](https://lolchess.gg/guide/exp)
  (seuils cumulés super-linéaires L4→L9 ; L4=10/L5=20/L6=36/L7=56/L8=80/L9=100)
- [TFT Leveling Strategy — mobalytics.gg](https://mobalytics.gg/blog/tft/guide-standard-leveling-strategy/)
  (stratégie : « you gain 2 experience for free at the end of each round »)
- [HS:BG Tavern Tier Costs — hearthstone.fandom.com](https://hearthstone.fandom.com/wiki/Battlegrounds/Tavern_Tier)
  (upgrade T1→T2 = 6g, réduit de 1g/round ; minion = 3g toujours)
- [SAP Freeze Mechanic — superautopets.fandom.com/wiki/Shop](https://superautopets.fandom.com/wiki/Shop)
  (geler = gratuit, persistant sous reroll, unfreeze ou achat pour libérer)
- [SAP Gold/Economy — superautopets.wiki.gg/wiki/Gold](https://superautopets.wiki.gg/wiki/Gold)
  (10g/round non reporté, pets=3g, reroll=1g, ratio 1:3 confirmé)
- [SAP Mechanics Analysis — a327ex.com](https://a327ex.com/posts/super_auto_pets_mechanics)
  (profondeur émergente via triggers ; la tension économique vient de la composabilité, pas du prix brut)
- [HS:BG strategy guide — fantasywarden.com](https://fantasywarden.com/games/hearthstone-battlegrounds-strategy-guide)
  (upgrade coût et timing dans la boucle HS:BG)

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 7. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants non modifiés.
Désaccords sourcés par code + web. Propositions chiffrées ancrant les constantes dans state.lua.*
