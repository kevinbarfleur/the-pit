# Round 05 — Critique adversariale : Progression & Économie

> **Lentille** : progression-economy — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v5, intégré round 4), de tous les
> rapports précédents `rounds/r01-r04-progression-economy.md`, et de la synthèse `round-04.md`.
> Accords argumentés / désaccords sourcés / propositions concrètes, chiffrées, priorisées.
> Aucune modification du code du jeu.
>
> **Sources primaires relues** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v5, `docs/roadmap-lab/00-state.md`, `round-04.md`
> - `rounds/r01-r04-progression-economy.md` (intégraux)
> - `docs/research/progression-economy-prd.md`, `src/run/state.lua` (via `00-state.md §4`)
> - `competitive/super-auto-pets.md`, `competitive/tft.md`, `competitive/balatro.md`,
>   `competitive/hs-battlegrounds.md`, `competitive/backpack-battles.md`, `competitive/the-bazaar.md`
> - Sources web nouvelles (citées au fil du texte)

---

## 0. Thèse de ce round

Les quatre rounds précédents ont convergé solidement sur les décisions structurelles (or fixe, XP
TFT-style, cost=rank, courbe `{2,5,10,18}`, option C slot-decline, pity-signal sans garantie,
daily avec tooltip). Le round 4 a notamment raffiné le critère de la courbe XP (3 tranches de
durée), promu deux mesures de sim en P0.5, et ajouté le filet pédagogique daily. Ce round
identifie **cinq zones que les rounds 1-4 n'ont pas traitées ou ont mal posées** :

1. **DÉSACCORD PRINCIPAL : `REROLL_COST = 1` est la décision la plus sous-analysée du système.
   À 1 or le reroll, le coût d'opportunité est quasi-nul en early (1/10 du budget), ce qui sabote
   silencieusement la tension "monter-vs-reroll-vs-acheter" que toute l'économie est censée créer.**
   Les 4 rounds précédents ont mesuré la tension autour du BUY XP (4 or) et du slot-decline mais
   n'ont jamais challengé le coût du reroll lui-même. C'est une lacune structurelle.

2. **DÉSACCORD MINEUR : le streak `STREAK_CAP = 3` est présenté comme "anti-snowball" mais
   il crée une asymétrie psychologique sous-analysée entre win-streak et loss-streak** qui peut
   générer un comportement défavorable au fun (le joueur en loss-streak reçoit +3 or mais n'a
   plus de build viable pour en profiter — le bonus arrive trop tard).

3. **DÉSACCORD SUR LA FORMULATION du moteur pré-run (§6.11 du brouillon v5)** : la grille
   `+4/+2/+1/0` affichée avant la run est correcte, mais elle **ne génère pas de tension
   économique dans la phase de build** — c'est un signal de rétention, pas de décision. Il
   manque un lien entre l'état économique actuel du run et le score de run final.

4. **ACCORD NUANCÉ sur la courbe `{2,5,10,18}` et le critère à 3 tranches (round 4, §1.14)** :
   le critère est nettement meilleur que l'ancienne version mais il repose encore sur un budget
   d'or fixe de 10/round sans modéliser l'impact des streaks. Un joueur en loss-streak de 4
   reçoit +3 or/round = 13 or total, soit +30 % de budget, ce qui change radicalement la
   faisabilité du "rush T5".

5. **LACUNE NON TRAITÉE : la tension "acheter vs reroller" est absente en late-game (tier 4-5)
   quand les unités coûtent 4-5 or et que le reroll ne coûte toujours que 1 or** — la décision
   se dégrade en "toujours reroller d'abord" dès le milieu du run. C'est la conséquence directe
   du point 1, mais elle est plus grave en late qu'en early.

---

## 1. Accords avec pourquoi

### 1.1 Or fixe 10/round (non reporté) + streaks : toujours solide, 5e confirmation

**Accord total.** Le point est consolidé depuis le round 1. L'argument additionnel de ce round :
The Bazaar (notre concurrent async le plus direct, Oct. 2025 — `bazaar-builds.net/patch-7-0-0`)
a modifié sa progression économique en oct. 2025 pour la rendre plus linéaire et prédictible
après des plaintes de nouveaux joueurs sur l'opacité de l'income variable. C'est une confirmation
de marché que la simplicité d'income (our `GOLD_PER_ROUND = 10` fixe) est une décision correcte
pour l'onboarding, surtout en async. Source : [The Bazaar Patch 7.0.0 — bazaar-builds.net](https://bazaar-builds.net/patch-7-0-0-level-up-changes-item-changes-more/).

**Pourquoi ça tient pour NOS contraintes** : async total → pas de signal social sur l'état
économique adverse → la banque perd son sens informationnel (argument de r01-r04, toujours valide).

### 1.2 XP TFT-style (passive + achetable) : la structure tient, la calibration est sous P3

**Accord sur la structure.** Le critère à 3 tranches de durée de run du round 4 (§1.14) est une
vraie amélioration sur le critère round 3 (15 rounds fixes). Voir §2.4 pour un désaccord sur la
modélisation des streaks dans ce critère.

**Pourquoi le ratio BUY_XP = 4g/4XP (ratio 1:1) reste sain** (confirmé round 3 §2.2) : à T3,
4 or = 1 unité rang-3 = 1 BUY XP. C'est la tension réelle. Le ratio 1:1 est correct parce que
la décision est de même ordre de grandeur que l'achat d'une unité rank-tier. À T1 la décision
est moins tendue (§2.5 du r04 — non résolu). Les sources TFT confirment que la tension BUY XP
est maximale quand le coût d'opportunité est une unité puissante, pas un reroll.
Source : [TFT Economy Mastery — boosteria.org](https://boosteria.org/guides/tft-economy-mastery).

### 1.3 Courbe recourbée `{2,5,10,18}` : bonne direction, critère à 3 tranches adopté

**Accord sur la direction du round 4 (§1.14).** Le critère raffiné :
- (1) T4 jamais passif à 15 rd
- (2) rush T5 ≥20 % du budget sur run court (10-12 rd)
- (3) rush T5 ≥10 % sur run long (17-19 rd)

est nettement plus robuste que l'ancien critère (15 rounds fixes). La question de savoir si
`{2,5,10,18}` ou `{2,5,10,20}` est le bon palier T5 reste à sim — accord sur la nécessité de
la sim à 3 tranches avant de figer. Voir §2.4 pour le désaccord sur la modélisation des streaks.

### 1.4 Pity-signal = `max(PITY_MIN_ABS=3, 0.5 × médiane)` + progression visuelle implicite

**Accord total avec le round 4 (§1.xx, litige #L').** Le plancher absolu `PITY_MIN_ABS = 3`
est essentiel pour survivre à l'audit de pool (si la médiane tombe à 4 rerolls, le signal
se déclenche à 2 — trop fréquent → perd sa saillance). La progression visuelle implicite
(icône qui s'intensifie sans chiffre) résout le dilemme VRR/signal. Le research MDPI 2025
(cité r04) sur la frontière ~55 tentatives s'applique à des pulls gacha (coût monétaire réel) ;
notre reroll à 1 or est sans danger sur ce seuil car la fréquence de reroll par session est
naturellement bornée par le budget or. Source : [MDPI 2025 — mdpi.com/2078-2489/16/10/890](https://mdpi.com/2078-2489/16/10/890).

### 1.5 Tooltip de run avant la daily + 10+ contraintes compositionnelles

**Accord fort (round 4, §1.14-1.17).** La daily sans contexte = run punitive pour les
joueurs 0-5 wins. L'ordre pédagogique des premières semaines (burn → bleed → …) est une bonne
proposition de Q3 (r04-progression-economy). Ce n'est pas controvertible.

### 1.6 `famines_math` option (a) reformulée (non-anti-growth) préférée à l'option (b) retrait

**Accord avec la nuance du round 4 (§1.3, litige #O).** L'option (a) — « tes 3 unités les plus
fortes ont +30 % dmg / +20 % HP » — préserve le signal tall sans créer de contrainte de
croissance. L'option (b) retrait serait une perte de design (le tall est un archétype sain :
SAP small-deck, StS deck-thinning). La reformulation est la bonne voie.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — `REROLL_COST = 1` : un reroll trop bon marché sabote la tension économique et n'a pas été challengé en 4 rounds

**Claim des rounds 1-4 (implicite, jamais remis en question)** : `REROLL_COST = 1` est donné
comme acquis depuis r01 (cité de l'inventaire `state.lua`) et jamais interrogé. Le round 1 a
même dit « 1 reroll = 1 or → le budget constrainted est dur », sans calculer l'impact réel.

**Le problème : à 1 or le reroll, le coût d'opportunité est quasi-nul en early-game, ce qui
rend le reroll dominant dans toute situation d'incertitude.**

Calcul direct sur `state.lua` (00-state §4.1 : `REROLL_COST = 1`, `GOLD_PER_ROUND = 10`) :
- Round 1, boutique T1 (100 % rang-1, coûts 1 or) : avec 10 or, le joueur peut acheter
  **10 unités rang-1** OU **10 rerolls** OU toute combinaison. Le reroll à 1 or = même prix
  qu'une unité rang-1. La décision est donc « acheter maintenant ou chercher mieux » — et
  chercher mieux n'a presque aucun coût.
- Round 3, boutique T2 (rang-2 à 2 or) : avec 10 or, le joueur peut faire **5 rerolls** avant
  d'acheter une unité rang-2 sans perdre grand-chose. 1 or sacrifié sur 10 = 10 % du budget.
- Round 5, boutique T2-3 (rang-3 à 3 or) : 3 rerolls = 3 or = 1 unité rang-3. La décision
  devient tendue. C'est ici que la tension commencé à être réelle.

**Résultat** : en early (rounds 1-3), le reroll à 1 or crée une tension quasi-nulle — chercher
l'unité voulue est toujours la stratégie dominante. En mid (rounds 4-6), la tension naît enfin.
En late (rounds 7+), avec des unités rang-4/5 (coût 4-5 or), 1 or de reroll = quasi gratuit —
le joueur rerollera systématiquement avant chaque achat. **La tension monter-vs-reroll-vs-acheter
n'existe que pendant une fenêtre narrow (rounds 4-6 environ).**

**Comparaison concurrentielle** :

- **SAP** : reroll = **1 or** (même coût). Mais SAP a des pets à **3 or uniformément** et
  5 slots. À T1-2 SAP (tours 1-4), 1 reroll = 33 % du coût d'un pet. Le reroll est un sacrifice
  réel. Chez nous, rang-1 à 1 or = le reroll ne sacrifie rien par rapport à l'achat.
  Source : [SAP Shop — superautopets.fandom.com/wiki/Shop](https://superautopets.fandom.com/wiki/Shop).

- **TFT** : reroll = **2 or**. Sur 5g/round passif de revenu base, 2 or = 40 % du revenu passif.
  C'est une décision réelle à chaque round. Le double coût de TFT crée une tension permanente
  (boosteria.org : « rolling is expensive ; players agonize over each reroll »).
  Source : [TFT Economy — boosteria.org](https://boosteria.org/guides/tft-economy-mastery).

- **HS:BG** : reroll = **1 or** en tier 1, **2 or** après les premiers rounds, scalant avec la
  progression de taverne. Le reroll scalant = tension croissante naturelle au fil du run.
  (hs-battlegrounds.md §2.3 ; pas de source URL directe dans les fichiers compétitifs).

- **The Bazaar** : modèle d'items, pas de reroll shop classique — non comparable directement.
  Source : [The Bazaar Beginner's Guide — gaming.news 2025](https://gaming.news/article/2025-05-26/the-bazaar-complete-beginners-guide-to-heroes-economy-combat/).

**Ce que ça implique pour The Pit** : avec `cost = rank` (rang-1 = 1 or = 1 reroll), le
reroll est **gratuit sur les unités les moins chères**. Un joueur qui cherche sa 3e copie rang-1
ne sacrifie rien à reroller. Ce n'est pas un problème si le run démarre au rang-1 et monte
rapidement vers des rangs où le coût d'achat dépasse le reroll, **MAIS** la boutique 100 %
rang-1 au tier-1 signifie que les 2-3 premiers rounds (critiques pour le first-impression et
le one-more-run) manquent de tension. Ce n'est pas un hasard si le diagnostic d'équilibrage
(the-pit-balance-diagnosis, mémoire) note une **variance early** problématique.

**Pourquoi ce n'est pas forcément un bug mais une décision à prendre explicitement** :

L'analogie psychologique du reroll pas cher : dans Balatro (référence d'addiction), le joker à
acheter est bon marché (1-2 $) mais le pool entier coûte davantage → tension sur le **choix**,
pas le **prix**. Si The Pit veut une tension sur le prix, le reroll doit coûter davantage ou
le coût doit scaler. Si The Pit veut une tension sur le **choix** uniquement (« quel unité parmi
les 5 visible ? »), le reroll à 1 or est suffisant MAIS alors le design tension repose
entièrement sur la diversité des offres — ce qui signifie que la diversité du pool et la
garantie d'utilité (guarantee de pertinence, §4.1 du brouillon) sont doublement critiques.

**Proposition concrète (§3.1).**

Source : [SAP Shop mechanics — superautopets.fandom.com](https://superautopets.fandom.com/wiki/Shop) ;
[TFT Economy guide — boosteria.org](https://boosteria.org/guides/tft-economy-mastery) ;
calcul direct sur `state.lua` (00-state §4.1).

### 2.2 DÉSACCORD MINEUR — La psychologie du streak loss est asymétrique de façon défavorable

**Claim du brouillon v5 (§6.2, confirmé depuis r01)** : les streaks compensent l'asymétrie et
réduisent le snowball. Le `STREAK_CAP = 3` borne le bonus à +3 or/round.

**Le problème partiel** : la recherche sur la psychologie des streaks (Smashing Magazine 2026,
[smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/))
montre que les loss streaks génèrent une **anxiété de rupture** (compulsion de récupérer) 2,3×
plus forte que l'espoir d'un win streak de même longueur. Dans un autobattler, cette anxiété
est canalisée vers un comportement sain seulement si le joueur a un **moyen actionnable
d'utiliser l'or supplémentaire** pour corriger son build.

Le **bug latent** : un joueur en loss-streak de 4 reçoit +3 or/round (13 or total) mais s'il
est en loss-streak, c'est souvent parce que son build est mal orienté — pas parce qu'il manque
d'or. L'or supplémentaire arrive **trop tard dans le cycle de correction** pour être psycho-
logiquement satisfaisant (il peut reroller plus mais son build reste inadapté). Le bonus de
streak agit comme un filet économique mais pas comme un filet de design.

**Nuance importante** : ce n'est pas un argument pour supprimer les streaks (l'accord de
l'ensemble des rounds reste valide) mais pour **distinguer le streak loss-streak d'avec le
win-streak dans la communication UI**. Actuellement, le streak est présenté comme un seul
mécanisme (+or). La recherche (Smashing Magazine 2026) préconise que les loss-streaks soient
présentés avec un **message actionnable** (« Bonus or : vends une unité pour rééquilibrer ton
approche »), pas seulement un chiffre d'or.

**Ce n'est pas un bug de mécanique, c'est un manque de signal.** La proposition de l'écran
post-combat « pourquoi » (§2.3 du brouillon v5) est le vrai remède ici — le streak-loss doit
pointer vers une décision, pas seulement vers de l'or. Les deux signaux sont complémentaires.

**Source** : [Designing Streak Systems — Smashing Magazine 2026](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/) ;
[Streak Psychology — StreakfortheCash 2025](https://www.streakforthecash.com/casino/the-psychology-behind-betting-streaks) ;
Kahneman & Tversky loss aversion (perte perçue 2,3× plus forte — référence de base).

### 2.3 DÉSACCORD MINEUR — Le moteur pré-run (§6.11) affiche le score de run mais ne lie pas l'état économique courant au score attendu

**Claim du brouillon v5 (§6.11, adopté round 4)** : afficher la grille `+4/+2/+1/0` + la
distance au prochain tier = goal-gradient activé = pull pré-run. C'est correct en tant que
signal de rétention (seganerds.com 2026 cité en round 4).

**Ce qui manque** : la grille montre "si vous ascendez (+10v) → +4 pts" mais **ne dit pas
au joueur quelle décision économique ce run il devrait viser pour y arriver**. En TFT, le
moteur pré-run est enrichi par la sélection d'augments qui oriente le budget (Riot GDC 2022 :
« l'augment définit le plan économique du round suivant »). Chez nous, la grille de score est
**informative mais non directive**.

**Pourquoi ce n'est pas une urgence mais une amélioration** : en v1 local, la grille suffit.
Mais une amélioration simple serait de lier le signal pré-run à l'état du run en cours si le
joueur revient mid-run (vies, tier boutique) : « Votre run en cours : 4 victoires, tier-3. Une
ascension ajouterait +4 pts. Il vous manque 6 victoires. » — 1 ligne d'info contextualisée.
Ce n'est pas du code moteur : RENDER + lecture de `state.lua` (hors SIM).

**Pourquoi je ne propose pas de refonte** : le litige #N (§6.11 du brouillon v5) est bien
positionné ; ce désaccord est une **amélioration incrémentale** qui peut attendre le retour
utilisateur après v0.11. Elle n'est pas bloquante.

**Source** : Riot GDC 2022 (augments) ; [immortalboost.com — TFT LP affichage pré-run](https://immortalboost.com) ;
seganerds.com 2026 (cité round 4).

### 2.4 DÉSACCORD SUR LA PRÉCISION — Le critère à 3 tranches ne modélise pas l'impact des streaks sur la faisabilité du "rush T5"

**Claim du round 4 (§1.14, litige #R)** : critère à 3 tranches (court 10-12 rd, médian 13-16,
long 17-19). Le critère est bon mais il est calculé sur un budget d'or **fixe de 10/round**.

**Le problème** : un joueur en loss-streak de 4 reçoit +3 or/round = **13 or/round** sur les
rounds difficiles. Un run long (17-19 rd) avec 4+ défaites (donc streaks) a un budget total
plus proche de `18 × 10 + 3 × 4 = 192` or que `18 × 10 = 180` or. L'écart est modeste (+6 %)
mais sur la formule "rush T5 ≥10 % du budget", 192 or de budget vs 180 = différence de
1,2 % sur le seuil. Ce n'est pas critique **mais** la sim à 3 tranches doit spécifier si elle
modélise des runs avec streak ou sans streak.

**Cas extrême** : un run "parfait" (10 victoires sans défaite) n'a **aucun streak loss** mais
pourrait avoir un win-streak de 10 = `+3 or × 8 rounds` ≈ +24 or supplémentaires. Budget total
≈ 124 or. Rush T5 = 26 XP à acheter = 26 or = **21 % du budget** (>20 % ✅). Cette version
avec win-streak est plus favorable — le joueur compétent qui win-streak a **plus** de budget
pour rush T5, ce qui est intuitivement correct.

**Ce que ça implique** : le critère du round 4 doit ajouter la clause : « les 3 tranches sont
mesurées sur des runs SANS streak (base), et la robustesse est vérifiée en ajoutant les
bonus streak moyens (win-streak P50, loss-streak P50 sur N=200 seeds). » La variance du
budget réel doit être documentée dans le sim-ticket, pas ignorée.

**Source** : `state.lua` constantes (00-state §4.1 : STREAK_CAP=3, GOLD_PER_ROUND=10) ; calcul
direct.

---

## 3. Propositions priorisées

### 3.1 [PRIORITÉ 1] — Décider explicitement du ratio reroll/rang-1 et documenter la décision de design

**Quoi** : trancher explicitement la question « est-ce voulu que reroll (1 or) = rang-1 (1 or) ? »

**Deux options claires :**

**(a) GARDER `REROLL_COST = 1` — avec compensation par la diversité des offres** :
Si la décision est de garder le reroll à 1 or (identique à SAP), alors le design
accepte que la tension ne vienne pas du prix du reroll mais de **la qualité des 5 offres**.
Dans ce cas, les garanties de pertinence (§4.1 du brouillon) et le pity-signal (§7.3) sont
**encore plus critiques** — ils deviennent les seuls mécanismes qui transforment un reroll
bon marché en décision réelle. Ce choix signifie que le fun de la boutique = diversité des offres,
pas la tension du prix.

**Avantage** : coh?rent avec SAP et le modèle « simple mais profond ». Moins de friction
pour les nouveaux joueurs.

**Risque** : la tension "monter-vs-reroll-vs-acheter" repose entièrement sur le coût d'achat
des unités (2-5 or), pas sur le coût du reroll (1 or). Le reroll devient presque un bouton
"refresh" gratuit. En late-game avec unités rang-4/5, cette asymétrie est particulièrement
visible : un joueur affrontant une unité rare (rang-4, 4 or) peut reroller 4 fois avant d'en
acheter une — sans sacrifier grand-chose.

**(b) SCALER `REROLL_COST` avec le tier de boutique** :
Reroll = max(1, shopTier - 1) : T1→1, T2→1, T3→2, T4→2, T5→3.
Cette approche est **cohérente avec HS:BG** (reroll scalant) et crée une tension croissante
naturelle. En T3, 2 or de reroll = 1 unité rang-2 sacrifiée. La tension "reroll vs acheter"
devient réelle et permanente.

**Avantage** : tension mécanique croissante ; la décision de reroller est toujours proportionnée
au coût des unités disponibles ; naturellement corrélé à la courbe XP.

**Risque** : complexité perçue (le reroll coûte différemment selon le tier) ; peut frustrer
les joueurs en T5 qui cherchent la 3e copie d'une unité rare (3 or de reroll = 60 % du coût
d'une unité rang-5). Mitigation : le pity-signal s'applique toujours pour signaler que la
copie est "proche".

**Proposition concrète** : tester l'option (b) en sim (`tools/sim.lua --reroll-cost-scaling`)
en mesurant le **nombre moyen de rerolls par round** et le **taux de conversion shop vue→achat**
par tier. Si le reroll count par round en T3-4 chute de plus de 40 % avec `REROLL_COST=2`
(sans compenser sur le hit rate des offres), la tension est trop forte → garder l'option (a).
**PRIORITÉ : documenter la décision AVANT P3 (recourbe XP), car le REROLL_COST affecte le
budget réel et donc la courbe XP.**

**Garde-fou** : toute modification de `REROLL_COST` doit :
- Rebaser le golden (invariant #5) — le golden utilise des rerolls dans `headless.lua`.
- Vérifier que `tests/run.lua` (invariants éco) reste vert.
- Être signalé AVANT sim (modification d'une constante `state.lua`).

**0 invariant rompu si la constante est modifiée avec les gardes ci-dessus.**

### 3.2 [PRIORITÉ 2] — Lier le signal streak-loss au post-combat "pourquoi" (RENDER pur, co-priorité §2.3 du brouillon)

**Quoi** : quand l'écran post-combat « pourquoi » est affiché (§2.3 du brouillon v5), si le
joueur est en loss-streak ≥2, ajouter une ligne contextuelle au format grimdark :
« LE PUITS VERSE SON OR DANS TA COUPE — ton architecture de mort mérite d'être repensée. »
+ suggestion actionnable : afficher le slot le plus exposé (colonne front) avec le moins
d'arêtes actives (faiblesse de placement). C'est la **combinaison du signal de streak** (or
supplémentaire) avec le **signal de placement** (§2.7 du brouillon) — deux signaux qui
activent la même décision (rééquilibrer).

**Pourquoi co-priorité** : les deux signaux (streak + post-combat) sont déjà planifiés dans
le brouillon. Les lier = 0 code supplémentaire (lecture de `state.streaks` + lecture du bus).
Coût : 0.5 h. Impact : le loss-streak devient psychologiquement actionnable au lieu d'être
juste un chiffre d'or.

**Garde-fou** : RENDER uniquement, 0 SIM, 0 invariant. Lecture de `state.streaks` (hors SIM,
déjà IO hors bus).

### 3.3 [PRIORITÉ 2] — Ajouter la modélisation des streaks dans le critère sim de la courbe XP (P3)

**Quoi** : dans le ticket sim P3 de la recourbe XP (`--xp-climax`, litige #R), ajouter une
4e clause au critère :

```
(4) Budget or mesuré = GOLD_PER_ROUND × nb_rounds + Σ(streak_bonus par round)
    -- win-streak P50 sur 200 seeds sans streak forcé
    -- loss-streak P50 sur 200 seeds sans streak forcé
    -- variance de budget : std_dev(budget_total) < 30 % du budget moyen
```

Le critère « rush T5 ≥20 % du budget sur run court » doit être vérifié sur le budget **réel**
(avec streaks), pas sur le budget **théorique** (10 or/round × n_rounds). Cette clause est une
ligne de sim, pas de code.

**Pourquoi cette précision compte** : un joueur qui win-streak a +24 or de bonus sur un run
parfait de 10 rounds → budget réel ≈ 124 or vs 100 or théorique → rush T5 = 26 or = 21 %
vs 26 % selon la base de calcul. La différence est de 5 points, ce qui peut décider du seuil
T5 correct (`18` ou `20`).

**Garde-fou** : documentation de sim, 0 code, 0 invariant.

### 3.4 [PRIORITÉ 3] — Documenter la décision reroll dans l'audit des constantes P3 (pas un bug, une décision à exposer)

**Quoi** : dans le document d'audit P3, ajouter une section « Constantes économiques — décisions
explicites » listant les ratios clés et leur intention :

| Constante | Valeur | Intention | Ratio clé |
|---|---|---|---|
| `REROLL_COST` | 1 | Refresh d'offres peu coûteux / tension par l'offre | reroll = rang-1 en T1 (quasi-gratuit) |
| `BUY_XP_COST` | 4 | Décision forte = 1 rang-3 sacrifié en T3 | ratio 1:1 avec rang-4 en T4 |
| `GOLD_PER_ROUND` | 10 | Budget fixe, 3 achats rang-1 max | pas de banque, pas d'intérêt |
| `STREAK_CAP` | 3 | +30 % de budget max par streak | égalisateur, non dominant |
| `SELL_REFUND_FRAC` | 0.5 | Asymétrie de pivot | engagement minimal requis |

Le but de ce tableau est d'exposer les ratios implicites pour que les futurs agents de sim
sachent CE QUE CHAQUE CONSTANTE EST CENSÉE FAIRE avant de la modifier.

**Pourquoi maintenant** : le round 5 révèle que `REROLL_COST = 1` n'a jamais été analysé
comme décision de design (simplement adopté depuis SAP par défaut). Si ce ratio change en P3,
sans documentation de l'intention, une future lentille pourrait reverter la décision pour de
mauvaises raisons.

**Garde-fou** : documentation pure, 0 code, 0 invariant.

---

## 4. Questions ouvertes

### Q1 — Le ratio reroll/rang-1 est-il intentionnel ?

Le code a `REROLL_COST = 1` et `cost = rank` (rang-1 = 1 or). Le reroll coûte exactement le
même prix qu'une unité rang-1. Est-ce voulu ? Aucun des 4 rounds précédents ne l'a demandé.

Si c'est voulu : la tension vient de la **diversité des offres**, pas du prix. Le guarantee de
pertinence (§4.1) et le pity-signal sont alors les mécanismes critiques.

Si ce n'est pas voulu : soit augmenter `REROLL_COST` à 2 (comme TFT), soit scaler avec le tier
(comme HS:BG). La sim décide.

### Q2 — Le streak loss-streak génère-t-il un comportement favorable en sim ?

En sim (`tools/sim.lua`), mesurer si les runs avec loss-streak de 4+ aboutissent à :
(a) Un rééquilibrage du build (changement d'unités mid-run), ce qui suggère que l'or
    supplémentaire est utilisé pour pivoter → streak = outil de récupération. ✅
(b) Un achat d'unités dans le même axe que l'axe perdant → streak = renforcement d'un build
    inadapté. ❌

Si (b) domine, le signal post-combat "pourquoi" (§2.3) est d'autant plus urgent : le joueur
en loss-streak a besoin d'un signal de direction, pas seulement d'or.

### Q3 — Quelle est la fréquence de reroll par round par tier dans la sim actuelle ?

`tools/sim.lua` peut mesurer (en headless) combien de rerolls sont effectués par round et par
tier dans les politiques actuelles. Si la fréquence de reroll est <1 en T1 (joueurs achetant
plus que reroulant) et >3 en T4 (joueurs reroulant systématiquement avant d'acheter), le
scaling de REROLL_COST est justifié. Cette mesure n'a jamais été faite.

### Q4 — La garantie de pertinence des reliques (§4.1) compense-t-elle suffisamment un reroll bon marché ?

Si `REROLL_COST = 1` reste, la garantie de pertinence des reliques (§4.1) et la garantie
d'avoir ≥1 unité de la famille pertinente en boutique (§3.1 de la ROADMAP v5) deviennent
les principaux mécanismes de tension d'offre. Ont-ils été calibrés en tenant compte d'un
reroll quasi-gratuit ? Si non, un joueur peut voir des offres médiocres ET reroller 3-4 fois
sans tension économique. L'audit de pool (P0.5) doit inclure cette interaction.

---

## 5. Synthèse des points clés pour la roadmap

### Ce qui change par rapport aux rounds 1-4 :

1. **`REROLL_COST = 1` doit être décidé explicitement** avant P3. La décision implicite
   (copie de SAP, non challengée) risque de créer une absence de tension en early-game et
   un reroll dominant en late-game. Deux options claires (garder/scaler) avec une sim de
   validation. La décision affecte le budget réel et donc la calibration de la courbe XP.

2. **Le signal streak-loss doit être lié au post-combat "pourquoi"** pour être actionnable
   (pas seulement un chiffre d'or). Coût RENDER quasi-nul, impact psychologique fort.

3. **Le critère sim de la courbe XP (litige #R) doit inclure les streaks** dans le calcul
   du budget réel. La variance de budget avec vs sans streak affecte le seuil T5 (`18` vs `20`).

4. **Documenter les ratios implicites des constantes économiques** (tableau §3.4) avant P3
   pour éviter des modifications non intentionnelles.

### Ce qui reste inchangé et tient :

- Or fixe 10/round (non reporté) : non contesté, 5e confirmation
- `cost = rank` : verrouillé
- Refund 0.5× : engagement garanti
- XP TFT-style (passive + achetable) : correct, calibration sous P3
- Courbe `{2,5,10,18}` en direction : correcte, critère à 3 tranches meilleur
- Déprioritisation reliques F (P1.5a) : accord fort
- Pity = max(3, 0.5×médiane) + progression visuelle : accord fort
- Daily + tooltip + 10+ contraintes compositionnelles : accord fort
- `famines_math` option (a) reformulée : accord
- Moteur pré-run §6.11 : accord (amélioration incrémentale possible en v2)

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` via `docs/roadmap-lab/00-state.md` §4.1 (REROLL_COST=1, GOLD_PER_ROUND=10,
  STREAK_CAP=3, BUY_XP_AMOUNT=4/BUY_XP_COST=4, SELL_REFUND_FRAC=0.5)
- `docs/roadmap-lab/ROADMAP-draft.md` v5 §6.11/§7.1/§4.1 (moteur pré-run, courbe XP, garantie
  pertinence reliques)
- `docs/roadmap-lab/round-04.md` §1.14 (critère 3 tranches litige #R)
- `docs/roadmap-lab/rounds/r01-r04-progression-economy.md` (corpus des 4 rounds précédents)
- `docs/research/progression-economy-prd.md` §3/§7.3 (constantes, pity, intentions de calibrage)
- `docs/roadmap-lab/competitive/super-auto-pets.md` §2.1-2.3 (or fixe, shop, reroll 1 or)
- `docs/roadmap-lab/competitive/tft.md` §1.2 (reroll 2 or, income passif, seuils XP)
- `docs/roadmap-lab/competitive/hs-battlegrounds.md` §2.3 (reroll scalant avec tier)

**Sources web nouvelles (vérifiées)** :
- [The Bazaar Patch 7.0.0 — bazaar-builds.net](https://bazaar-builds.net/patch-7-0-0-level-up-changes-item-changes-more/)
  (migration vers income linéaire après friction onboarding)
- [TFT Economy Mastery — boosteria.org](https://boosteria.org/guides/tft-economy-mastery)
  (reroll 2g = 40 % du revenu passif ; confirmation tension reroll TFT)
- [SAP Shop — superautopets.fandom.com](https://superautopets.fandom.com/wiki/Shop)
  (reroll 1 or, pets 3 or uniformément ; comparaison ratio reroll/achat)
- [TFT XP/Gold — lolchess.gg](https://lolchess.gg/guide/exp)
  (seuils XP cumulés niveau 2-9 : 2, 6, 10, 20, 36, 56, 80, 100 ; confirmés super-linéaires)
- [TFT Leveling Guide — tftcomps.gg](https://tftcomps.gg/news/tft-leveling-guide/)
  (contextualisation de la courbe XP TFT vs The Pit)
- [MDPI 2025 Gacha Addiction — mdpi.com](https://mdpi.com/2078-2489/16/10/890)
  (seuil 55 tentatives compulsion ; confirme pertinence relative pour pity)
- [Designing Streak Systems — Smashing Magazine 2026](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/)
  (loss-streak : anxiété 2,3× plus forte que win-streak de même longueur ; signaux actionnables)
- [Streak Psychology — StreakfortheCash 2025](https://www.streakforthecash.com/casino/the-psychology-behind-betting-streaks)
  (asymétrie psychologique win vs loss streak ; Kahneman & Tversky loss aversion)
- [The Bazaar Complete Beginner's Guide — gaming.news 2025](https://gaming.news/article/2025-05-26/the-bazaar-complete-beginners-guide-to-heroes-economy-combat/)
  (modèle économique Bazaar pour contraste avec The Pit)

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 5. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants non modifiés.
Désaccords sourcés par code + web. Propositions chiffrées ancrant les constantes dans `state.lua`.*
