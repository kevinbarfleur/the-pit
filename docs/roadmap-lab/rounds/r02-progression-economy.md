# Round 02 — Critique adversariale : Progression & Économie

> **Lentille** : Progression & économie — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter. **Round 2 : critique du brouillon v2 + du round 1.**
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v2, intégré round 1) et du rapport
> `rounds/r01-progression-economy.md`. Accords argumentés / désaccords sourcés / propositions
> concrètes, chiffrées, priorisées. Aucune modification du code du jeu.
>
> **Sources primaires relues** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v2, `docs/roadmap-lab/00-state.md`,
>   `docs/roadmap-lab/round-01.md`, `docs/roadmap-lab/rounds/r01-progression-economy.md`,
>   `docs/research/progression-economy-prd.md`, `src/run/state.lua` (lu en intégralité).
> - Concurrence : `competitive/super-auto-pets.md`, `competitive/tft.md`, `competitive/balatro.md`,
>   `competitive/hs-battlegrounds.md`, `competitive/backpack-battles.md`, `competitive/the-bazaar.md`.
> - Sources web nouvelles (citées au fil du texte).

---

## 0. Thèse de ce round

Le brouillon v2 et le rapport r01-progression-economy ont **bien posé le cadre** : or fixe, XP
TFT-style, cost=rank, streaks comme anti-snowball. Là où ce round apporte un regard différent :

1. **La tension XP/reroll est correctement diagnostiquée en round 1, mais le remède proposé
   (verrouillage early XP) est la moins bonne réponse à un vrai problème** — et le code révèle
   qu'une solution est déjà en place, partiellement.
2. **Le freeze gratuit SAP est une analogie paresseuse que le round 1 n'a pas démontée** : le
   mécanisme psychologique de SAP ne transfère pas tel quel à notre contrainte de pool à 83 unités.
3. **Le slot-decline (+3 or) est le levier le plus sous-analysé du brouillon, avec le risque
   le plus concret** de casser l'intention design (rester « tall » = refus systématique).
4. **La garantie de pertinence des reliques (invariant #3 reformulé) manque un cas dégénéré qui
   crée une dépendance build-circulaire** non traitée.
5. **La daily-score `wins×(10−lives)×(1+xp_spent)` a un bug de conception** : le facteur XP
   mesure l'investissement, pas l'efficience — un joueur qui rush XP sans l'utiliser est récompensé.

---

## 1. Accords avec pourquoi

### 1.1 Or fixe (10/round, non reporté) + streaks comme anti-snowball : oui, et pour les bonnes raisons

**Accord total** avec le brouillon v2 et le round 1. La justification mécaniste tient :

- Run de 10-15 combats → accumulation bancable maximale ≈ 3 rounds × 10 = 30 or → intérêt
  potentiel +3 or (TFT §1.2, `op.gg/tft/game-guide/gold-xp`) = +10 % sur un run entier. Trop
  faible pour justifier la complexité d'une banque, et créateur d'une spirale de mort pour un
  joueur qui part en arrière (debt-hole impossible à remonter sur run court).
- Le streak comme **redistribution** (et non bonus de domination) est correct. `STREAK_CAP=3`
  borne à +3 or/round = +30 % du budget de base sur une série, ce qui aide à rattraper un
  plateau faible sans effacer l'avantage de skill du dominant.
- La **nuance du round 1** (le streak devrait être présenté comme anti-snowball dans l'UI, pas
  seulement comme bonus d'or) est valide et non controversée. La distinction est purement UI.

### 1.2 XP TFT-style (passive + achetable) : la structure tient

**Accord sur la structure**, pas sur la calibration. Le code (`state.lua:195`) confirme que la
passive XP ne démarre qu'au round 2 (`if self.round > 1`), ce qui résout partiellement le
problème de tension early identifié en round 1 : **au round 1, il n'y a pas d'XP passive à
décider de « gaspiller »** — la question se pose seulement à partir du round 2. Ce détail
d'implémentation **corrige l'analyse du round 1 qui supposait le rush possible dès le round 1**.

La véritable tension apparaît au round 2-3 : `BUY_XP_COST=4 or` = exactement 1 unité rang-4
sacrifiée (si disponible en tier-2, 30 % de chance). L'intention de calibrage est saine
(progression-economy-prd.md §3.3 : passif ≈ tier-3 en fin de partie, rush → tier-5 milieu).

### 1.3 cost = rank : accord total

Alignement `cost = rank` est correct pour les raisons que le brouillon cite. La clarté
perceptuelle (prix visible = complexité visible) est directement transférable depuis le modèle
TFT (leçon Dragonlands, progression-economy-prd.md §4.4 : « casser l'axiome plus cher = plus
fort distordu la perception »). Aucun désaccord ici.

### 1.4 Refund 0.5× : accord sur la psychologie du commitment

L'asymétrie engageante (vendre = accepter une perte) est correctement posée. En SAP, la vente
L3 = 3 or sur 18 investis (~17 % de retour) était intentionnellement punitif
(`superautopets.fandom.com/wiki/Shop`). Notre 0.5× est plus généreux (50 %) mais reste sous
le coût, ce qui préserve le commitment sans interdire le pivot.

### 1.5 Décision de différer le verrouillage XP early à la sim (round-01.md §2.1) : accord de méthode

Le synthétiseur du round 1 a **correctement rejeté** le verrouillage early XP comme chantier
actif en faisant reposer la charge de la preuve sur la sim. C'est la bonne méthode. **Ce round
va plus loin** : le code révèle que le verrouillage n'est probablement pas nécessaire (§2.1
ci-dessous), mais la décision par sim reste la bonne démarche.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La « tension XP early » est sur-diagnostiquée, le code la gère déjà partiellement

**Claim du round 1** (r01-progression-economy §2.1) : « en tier-1, BUY XP n'a pas de coût
d'opportunité → le joueur rush l'XP par défaut ».

**Pourquoi c'est partiellement inexact** :

Le code (`state.lua:195`) impose que l'XP passive ne démarre qu'au round 2. Au round 1 :
- Budget = 10 or, no XP passive à « perdre ».
- `BUY_XP_COST = 4` pour 4 XP → passer de tier-1 à tier-2 requiert `XP_TO_LEVEL[1] = 2` XP.
- Donc dès le round 1, acheter 4 XP (4 or) = passer au tier-2, laissant 6 or.
- Avec 6 or : 1 unité rang-2 (2 or) + 4 rerolls = faisable. Ou 2 unités rang-2 (4 or) + 2 rerolls.
- Le coût d'opportunité au round 1 est bien réel : **4 or = 4 rerolls sacrifiés** (ou 1 unité rang-4
  si la boutique en proposait au tier-1, ce qu'elle ne fait pas — tier-1 = 100 % rang-1).

En tier-1, la tension XP n'est pas « sans coût d'opportunité en unités hautes » — elle est
**sans coût en unités hautes** (correct), mais **avec coût en rerolls** (manqué par le round 1)
et **en plateau de départ** (3 slots, on veut les remplir vite). Sacrifier 4 or en XP dès le
round 1 = 4 slots de boutique non-rerollés = risque de manquer un bon rang-1.

**Implication** : la tension existe au round 1, elle est seulement différente de celle des rounds
suivants. Ce n'est pas « sans coût » — c'est « coût différent (rerolls/rangs-1 vs unités hautes) ».

**Source complémentaire** : TFT ne donne pas d'XP passive aux rounds 1-2 non plus (tft.ninja :
« XP passive : +2 XP automatiques à partir du stage 2 »,
https://tft.ninja/guides/game-mechanics/leveling). Notre implémentation est analogue et délibérée
— ce n'est pas une lacune, c'est le modèle de référence.

**Conclusion sur le verrouillage** : le verrouillage early XP proposé en round 1 (§3.1) est un
**remède à un problème possiblement inexistant**. Avant d'envisager de modifier `startRound()`,
la sim doit mesurer le delta tier moyen R3 « rush » vs « passif ». La décision du synthétiseur
(charge de preuve sur la sim, pas de règle ajoutée a priori) est juste et **ce round la renforce**.

### 2.2 DÉSACCORD — Le freeze GRATUIT de SAP est une analogie paresseuse non démontée par le round 1

**Claim du round 1** (r01-progression-economy §2.2 / §3.2) : implémenter le freeze avec coût en
slot « comme SAP », Priorité 2, coût dev 1-2 jours.

**Le problème psychologique de l'analogie** : le freeze SAP est **totalement gratuit**, sans coût
en or ni en slot (`superautopets.fandom.com/wiki/Shop` : « Freezing is completely free of charge »,
`twoaveragegamers.com`). Le round 1 propose « avec coût en slot » — **c'est une version hybride
qu'aucun jeu de référence n'utilise exactement dans ce sens**.

**Pourquoi le freeze gratuit de SAP fonctionne dans SAP** : SAP a 5 pets en boutique + 1-2 food
slots. Coût/pet = 3 or fixe. Pool par tier = 10 pets (~10 % de chance unitaire par slot). Hunt
médian d'un pet spécifique = `1/(5 × 0.10)` ≈ 2 boutiques — c'est **court**. Le freeze ne
corrige pas une frustration de hunt longue ; il corrige le **timing** (je veux cet item maintenant
mais je n'ai pas assez d'or ce round). C'est une décision de **synchronisation temporelle**, pas
de **survie contre un pool dilué**.

**Notre contexte est différent** : 83 unités, pool uniforme par rang. En tier-2, P(rang-2 spécifique
par boutique) = 5 × 0.30 / 23 ≈ 6.5 % (calcul confirmé round 1). Le hunt médian rang-2 ≈ 9 rounds
(~46 boutiques sans reroll). Ce n'est PAS un problème de timing — c'est une **dilution structurelle
du pool**. Le freeze ne résout pas ce problème : une unité gelée d'un round à l'autre n'aide pas
si on met 9 rounds à la voir une première fois. Le freeze résout « j'ai vu l'unité, je n'avais
pas d'or ce round » — pas « je cherche l'unité depuis 9 rounds ».

**La vraie solution à la dilution** est soit le **pity-tracker** (cote qui monte sans voir l'unité
= signal d'escalation vers le joueur + correctif de distribution), soit une **réduction du pool
à 50-60 unités** (« 20 unités intéressantes > 83 plates », BRIEF.md). Le freeze est un
complément utile mais **pas le remède structurel** que le round 1 présente.

**Source de design** : Hearthstone Battlegrounds (`hs-battlegrounds.md §1.1`) gèle **gratuitement
des minions entiers entre rounds** non pour résoudre la dilution mais pour la gestion de timing.
Son pool est plus petit et différencié par taverne tier. Backpack Battles n'a pas de freeze — il
n'en a pas besoin car son pool par rareté/round est beaucoup plus restreint (Wikipedia Backpack
Battles : rareté shift vers le haut en cours de run, pool restreint par round).

**Verdict** : le freeze est **utile** (réduction de friction de timing), mais **secondaire** par
rapport à l'audit du pool (P0.5 §3.1) qui va réduire les redondances paramétriques. Le freeze
avec coût en slot est une innovation de design non testée — ni SAP, ni HS:BG, ni TFT ne font ça
exactement. Ce n'est pas une raison de ne pas l'essayer, mais c'est une raison de le classer
**après** l'audit du pool et le pity-tracker, pas Priorité 2.

**Proposition révisée** (§3.2 ci-dessous).

### 2.3 DÉSACCORD — Le slot-decline est le levier le plus risqué et le moins analysé

**Claim implicite du brouillon v2** (`00-state.md §4.1` : `SLOT_DECLINE_GOLD = 3`) et du round 1
(mentionné comme cible de sim en §Q4, jamais challengé sur le fond) : refuser un slot = +3 or
= +30 % du budget de round = axe « tall » intentionnel.

**Le problème de +30 % de budget** :

Avec `GOLD_PER_ROUND = 10` et `SLOT_DECLINE_GOLD = 3` :
- Refuser un slot au round 2 = 13 or disponibles.
- Refuser systématiquement 4 slots (rounds 2-5) = +12 or d'avantage économique cumulé sur la
  fenêtre d'expansion critique.
- Un joueur « tall » (3-5 unités niveau 3) qui refuse les 6 slots grants = +18 or total cumulé.

Cela crée **deux problèmes distincts** :

**A — Le refus optimal est calculable par anticipation** : un joueur rationnel sait au round 2
s'il vise « tall » ou « wide ». S'il vise tall, chaque slot décliné est systématiquement optimal
(+3 or sans coût). Il n'y a pas de **décision** par slot — c'est une décision de style de jeu
prise une fois, appliquée mécaniquement 6 fois. Ce n'est pas un axe de build dynamique, c'est
une **déclaration d'intention**.

**B — Le cumul +18 or peut casser l'équilibre tall vs wide** : un joueur tall avec +18 or cumulé
peut financer davantage de rerolls ou d'XP que prévu. Si tall devient strictement supérieur à
wide (ce qui se mesure en sim — lift de co-occurrence tall vs win% — cf. `tools/sim.lua`), le
système de grants timés est cassé dans l'autre sens.

**Source de comparaison** : SAP n'a pas de mechanic de refus de case — les 5 slots s'ouvrent
progressivement par round, sans option de refus payant. TFT n'a pas de refus de slot non plus.
Le « decline pour or » est notre innovation — et les innovations non testées ont besoin d'une
borne de décision explicite, pas juste « à simuler ».

**Proposition révisée** (§3.3 ci-dessous).

### 2.4 DÉSACCORD — La daily-score `wins×(10−lives)×(1+xp_spent)` récompense l'investissement, pas l'efficience

**Claim du brouillon v2** (§6.6) : « score DISTINCT du ranked, récompense l'efficience
(ascension propre + économie serrée) ».

**Le problème de la formule proposée** :

`daily = wins × (10 − lives_lost) × (1 + ⌊xp_spent/GOLD_PER_ROUND⌋)`

Le facteur `(1 + ⌊xp_spent/GOLD_PER_ROUND⌋)` récompense avoir *dépensé* de l'XP. Or :

- Un joueur qui rush XP rounds 1-3 (dépense 12 or en XP), mène une run correcte (7 wins,
  2 vies perdues) = `7 × 8 × (1 + 1)` = **112**.
- Un joueur efficient qui n'achète jamais d'XP (passive seule, meilleure décision économique
  selon l'intention du design), fait une run identique = `7 × 8 × (1 + 0)` = **56**.

La formule **punit le joueur qui laisse la passive faire son travail** et récompense le rush
XP — exactement à l'inverse de « l'économie serrée ». Ce n'est pas une mesure d'efficience :
c'est une mesure d'investissement brut en XP.

**Ce que « efficience » devrait mesurer** : minimiser les ressources gaspillées par rapport au
résultat obtenu. La formule correcte serait quelque chose comme
`wins × (10 − lives_lost) × (shopTier_atteint / xp_total_investie)` — mais cela devient
complexe et non affichable en 1 ligne (critère de lisibilité, BRIEF.md §1).

**Alternative concrète** : ne pas mesurer l'efficience XP explicitement — la daily mesure déjà
l'**outcome** (`wins`) et la **propreté** (`10 − lives_lost`). Ajouter un multiplicateur de
**vitesse** (`1 + bonus si ascension avant le round 12`) est plus simple et plus lisible. Si
le run prend 10 rounds (ascension rapide avec peu de rerolls) vs 15 rounds (ascension lente),
la vitesse reflète l'efficience naturellement.

**Proposition révisée** (§3.4 ci-dessous).

### 2.5 DÉSACCORD MINEUR — La garantie de pertinence relique (invariant #3 reformulé) manque un cas dégénéré

**Claim du brouillon v2** (§5.4) : « ≥1 des 3 reliques a son type-cible présent sur le plateau
courant ». Reformule l'invariant #3 en « même seed+wins+compo → même offre ».

**Le problème du bootstrap circulaire au round 3-6** :

La contrainte de pertinence filtre les reliques selon le plateau. Mais au round 3 (premier
marchand potentiel après 3 combats = `combats % 3`, progression-economy-prd §5.1), le plateau
est composé en partie de... ce qu'on a acheté en tier-1 (100 % rang-1). Si le joueur a 3 units
rang-1 burn (le plus commun des ranges), l'offre « ≥1 relique burn pertinente » garantit
systématiquement une relique burn early — ce qui pousse vers le build burn sans que le joueur
n'ait décidé (la garantie façonne la compo autant que la compo façonne la garantie).

Ce n'est pas une objection bloquante — c'est un **risque de boucle de renforcement précoce** qui
réduit la diversité de build au premier marchand. Si tous les joueurs démarrent avec 2-3 rang-1
de la famille la plus commune (burn ou bleed), la garantie de pertinence les confirme dans cet
axe sans alternative visible. Résultat possible : runs early plus homogènes.

**Mitigation naturelle** : l'offre est 1-parmi-3 (pas 3 reliques du type dominant). Si la
contrainte est « ≥1 relique pertinente parmi 3 », les 2 autres peuvent être d'autres types.
La boucle de renforcement est limitée. Mais elle mérite d'être nommée comme risque à mesurer.

**Proposition** : au premier marchand (round ≤ 4), la contrainte de pertinence s'applique avec
une contrainte supplémentaire : si l'offre pertinente est d'un type avec ≥5 unités de ce type
dans le pool rang-1 (les plus fréquentes), vérifier aussi qu'une des 3 reliques propose un
type *non encore présent* sur le plateau. Cela garde la garantie sans enfermer le joueur dans
la famille la plus disponible. Cost dev : 1 condition dans `rollRelicChoices`.

---

## 3. Propositions priorisées

### 3.1 P0 — Sim « tension XP early » AVANT de décider quoi que ce soit sur BUY_XP [PRIORITÉ 0 — BLOQUANTE]

**Quoi** : avant d'implémenter un verrouillage, une XP passive nulle R1-2, ou tout autre
correctif de la tension XP early, lancer `tools/sim.lua` avec deux politiques comparées :

- **Politique A** : « rush XP maximal » — toujours acheter BUY XP si 4 or disponibles et pas
  au MAX_TIER, sans acheter d'unité si le budget est < 4 or restant.
- **Politique B** : « passif pur » — ne jamais acheter BUY XP, tout l'or sur unités/rerolls.

**Mesure cible** : tier moyen atteint à round 5 et round 10, win-rate sur 500 combats.
**Seuil de décision** :
- Si delta tier R5 < 0.5 → pas de déséquilibre perceptible → aucun correctif nécessaire.
- Si delta tier R5 ≥ 1 tier ET win-rate(A) > win-rate(B) + 5 % → un correctif est justifié.
- Si delta OR win-rate, mais pas les deux → surveillance, pas de règle.

**Pourquoi cette priorité** : le code (`state.lua:195`) révèle que l'XP passive ne démarre qu'au
round 2. Le problème identifié en round 1 (« rush dès le round 1 sans coût ») est partiellement
mitigé. Il serait contre-productif d'ajouter une règle à `startRound()` sans preuve que la
sim confirme le déséquilibre.

**Coût** : sim pure, aucune modification de code. 1-2h de dev sim.

### 3.2 P3 — Freeze avec coût en slot : RECLASSER APRÈS l'audit du pool et le pity-tracker [PRIORITÉ ABAISSÉE]

**Reclassement justifié** : le freeze résout un problème de timing, pas la dilution structurelle
d'un pool de 83 unités. La dilution est adressée par :
1. L'audit d'identité (P0.5 §3.1) qui éliminera les doublons paramétriques → réduction du pool.
2. Le pity-tracker (litige #E, roadmap §7.3) qui corrige la distribution perçue.

Le freeze, s'il est implémenté, doit l'être **après** ces deux interventions pour mesurer la
friction résiduelle. Sinon on risque d'accumuler trois remèdes sur le même problème.

**Si implémenté** : le design « freeze avec coût en slot » (pas gratuit comme SAP, pas au prix
en or) est une innovation non testée. La version la plus simple et la moins risquée est le
**freeze GRATUIT** (comme SAP), limité à **1 item par round** (pas toute la boutique). Cela
préserve la pression de décision (on ne peut pas geler 5 items à la fois = zéro pression) tout
en résolvant le timing. La version « coût en slot » est une contrainte supplémentaire dont la
valeur n'est pas démontrée.

**Source** : SAP freeze est gratuit, illimité, et le jeu fonctionne (`superautopets.fandom.com/wiki/Shop`).
Le coût en slot est une innovation non validée. Appliquer le principe de parcimonie.

### 3.3 P3 — Slot-decline : ajouter une borne de décision OU réduire SLOT_DECLINE_GOLD [PRIORITÉ 2]

**Problème identifié** (§2.3) : `SLOT_DECLINE_GOLD = 3` peut rendre le refus systématiquement
optimal pour les builds « tall ». Deux correctifs possibles (à trancher par sim) :

**Option A — Réduire SLOT_DECLINE_GOLD à 1 ou 2** : réduit l'avantage du refus systématique.
- A 1 or : refuser tous les slots = +6 or cumulés sur run (vs +18 actuellement). Plus équilibré,
  moins de pression à déclarer son style early.
- A 2 or : refuser tous les slots = +12 or cumulés. Zone grise.

**Option B — Borner le nombre de refus par run** : un joueur peut refuser au max N=3 slots
(sur 6 offerts). Résout le refus mécanique tout en préservant l'axe « tall » partiel.

**Option C — Déclin par offre individuelle (actuel) mais XP passive obligatoire à chaque
declined slot** : si on refuse un slot, on reçoit l'or MAIS on reçoit aussi 1 XP passive
forcée. Le slot décliné devient de la progression boutique, pas juste de l'or.

**Sim cible** : mesurer le taux optimal de refus par round sur 500 runs avec politiques comparées
(« tout refuser » vs « tout accepter » vs « refuser rounds 2-3 seulement »). Si win-rate(refus
systématique) > win-rate(acceptation systématique) + 5 %, `SLOT_DECLINE_GOLD` est trop élevé.

**Coût** : ajustement de constante (trivial). Décision par sim.

### 3.4 P2 — Daily-score : simplifier la formule vers la VITESSE d'ascension [PRIORITÉ 2]

**Remplacement proposé** de `wins × (10 − lives_lost) × (1 + ⌊xp_spent/GOLD_PER_ROUND⌋)` :

```
daily = wins × (10 − lives_lost) × speed_mult
```

Avec `speed_mult` calculé par tranche de rounds à l'ascension :
- Ascension en ≤ 10 rounds : `speed_mult = 2.0`
- Ascension en 11-13 rounds : `speed_mult = 1.5`
- Ascension en 14+ rounds : `speed_mult = 1.0`
- Chute (quelle que soit la durée) : `speed_mult = 0` (daily = 0 si pas d'ascension)

**Pourquoi** : mesure l'efficience de run (rapidité de construction + propreté de l'ascension)
sans mesurer l'investissement brut en XP. Un joueur qui monte tier-5 passivement et ascend
proprement en 10 rounds est plus efficient qu'un joueur qui rush XP et ascend en 14 rounds.
La formule est **affichable en 1 ligne** (critère Snap/Ben Brode, marvel-snap §7.3).

**Garde-fou** : le `speed_mult` ne s'applique qu'à l'ascension (protection contre le sandbagging).
Chute = daily = 0 évite que la grille daily soit jouée différemment du ranked (sinon chaque run
de daily est optimisée pour le leaderboard éphémère au détriment du gameplay).

**Invariants** : daily = méta IO hors SIM (comme rating ranked). Aucun des 32 invariants touchés.
Le nombre de rounds d'un run est déjà dans `run_state.round` (état existant, `state.lua:120`).

### 3.5 P3 — Mesurer IMMÉDIATEMENT le slot-decline et le hunt médian avant de figer SLOT_DECLINE_GOLD et les cotes [PRIORITÉ 1 — précondition de l'équilibrage]

**Quoi** : deux métriques à ajouter à `tools/sim.lua` (extension, pas refonte) :

**A — Hunt médian par rang et tier** (prévu mais non chiffré dans la roadmap, bloquant
pour figer les cotes) :
```
pour chaque (rang, tier) :
  N_RUNS = 200
  pour chaque run : compte rounds_before_3copies(rang, tier)
  → p10 / p50 / p90 du hunt
```
Seuil de décision : p50 rang-2 en tier-2 > 5 rounds → correctif nécessaire (pity ou pool réduit).

**B — Taux de refus optimal de slot** :
```
politique « tout refuser » vs « tout accepter » vs « refuser 50% au hasard »
→ win-rate + tier-moyen-atteint à round 10
```
Seuil de décision : si politique « tout refuser » domine de +5 %, réduire `SLOT_DECLINE_GOLD`.

**Architecture** : extension de `tools/sim.lua`, zéro modification de la couche SIM, déterministe
(seeds fixés = résultats reproductibles). Aucun invariant de test touché.

---

## 4. Questions ouvertes pour les rounds suivants

### Q1 — La passive XP de 1/round est-elle calibrée pour le run court ?

`XP_TO_LEVEL = {[1]=2, [2]=5, [3]=8, [4]=12}` (state.lua:71). Seuils cumulés : T2=2, T3=7,
T4=15, T5=27. Avec passive 1/round à partir du round 2, un run de 15 rounds donne 14 XP
passives. Résultat : tier 3 atteint au round 8 (7 XP cumulées), tier 4 au round 16 (jamais
si le run finit avant). **Intention correcte** (passif ≈ tier-3, progression-economy-prd §3.3),
mais tier-4 quasi-inaccessible passivement même sur un run de 15 rounds. Acceptable si les
builds tier-4 sont les « carry hauts » — à valider en sim.

### Q2 — Le `PASSIVE_XP_PER_ROUND = 1` crée-t-il une différence perçue entre rounds 2 et 10 ?

Avec XP passive linéaire (1/round), la progression boutique est **linéaire** — elle ne
s'accélère pas en mid-game. TFT a une XP passive constante (2/round) **ET** une courbe de
seuils exponentiels (niveau 9 coûte 278 XP cumulées vs 2 pour niveau 2). La tension aug-
mente naturellement. Chez nous, les seuils `{2, 5, 8, 12}` augmentent linéairement (+3 chacun
environ) avec une passive linéaire → **tension quasi-constante** tout au long du run. Est-ce
suffisant pour créer un climax mid-late ? À mesurer.

### Q3 — La garantie de pertinence relique au round 3 crée-t-elle une boucle de renforcement précoce ?

(Cf. §2.5.) Si les 12 unités rang-1 les plus communes sont concentrées sur 2-3 familles (la
répartition actuelle : burn/bleed/poison dominent les rangs bas, `00-state.md §2.1`), le
premier marchand (round 3-4) va systématiquement proposer une relique de la famille du premier
slot. Ce risque de confirmation précoce n'est pas bloquant mais mérite une mesure sur la
distribution des builds day-1 après implémentation.

### Q4 — La formule daily doit-elle récompenser les chutes propres (7-9 wins sans ascension) ?

Avec la formule `wins × (10−lives_lost) × speed_mult` et `speed_mult = 0` si chute, une
chute 9-1 (9 wins, 1 vie perdue) = daily 0. Or c'est une très bonne run qui n'a pas croisé
un build counter juste avant l'ascension. Un `speed_mult = 0.5` pour les chutes 8-9 wins
permettrait d'éviter que la daily ne punisse les runs presque-parfaites qui ont subi du
malchance de matchmaking. **À trancher** : si la daily est conçue pour l'ascension, 0 est
juste ; si elle récompense le meilleur run du jour, 0.5 pour les quasi-ascensions est plus
équitable.

---

## 5. Synthèse des points clés pour la roadmap

### Ce qui change par rapport au round 1 :

1. **Verrouillage XP early → rejeté** (le code révèle que round 1 = pas d'XP passive, la
   tension existe sous forme différente). La charge de preuve reste sur la sim.

2. **Freeze avec coût en slot → reclassé P3** (pas P2). Le vrai remède à la dilution du pool
   est l'audit d'identité (P0.5) + le pity-tracker. Le freeze gratuit (1 item/round) est la
   version la plus économe à tester si le pool reste large après P0.5.

3. **Slot-decline → à mesurer impérativement avant tout autre équilibrage**. `SLOT_DECLINE_GOLD=3`
   peut rendre le refus systématiquement dominant. C'est le levier le plus sous-analysé de
   l'économie actuelle.

4. **Daily-score → formule à corriger**. `(1+xp_spent)` récompense l'investissement, pas
   l'efficience. Remplacer par `speed_mult` basé sur le nombre de rounds à l'ascension.

5. **Hunt médian → mesure impérative avant de figer les cotes**. La roadmap v2 le liste en
   P3 ; c'est en réalité une **précondition de tout l'équilibrage** (pity-tracker, pool,
   reroll-escalade).

### Ce qui reste inchangé et tient :

- Or fixe + streaks comme anti-snowball : structurellement correct.
- XP TFT-style (passive + achetable, ratio 1:1) : la structure est saine.
- cost = rank : sans débat.
- Refund 0.5× : engagement garanti.
- Garantie de pertinence relique ≥1 parmi 3 : le principe tient, avec le cas dégénéré signalé.

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` (lu intégralement : constantes éco, passive XP round 2+, slot grants timés)
- `docs/roadmap-lab/00-state.md` §4 (constantes, cotes, boucle)
- `docs/roadmap-lab/ROADMAP-draft.md` v2 §5-7 (reliques, ranked, équilibrage)
- `docs/roadmap-lab/round-01.md` §1-3 (accords/rejets, litiges ouverts)
- `docs/roadmap-lab/rounds/r01-progression-economy.md` (intégralité)
- `docs/research/progression-economy-prd.md` §3-7 (PRD verrouillé, intentions de calibrage)
- `docs/roadmap-lab/competitive/super-auto-pets.md` §2.1, §2.3 (or fixe, freeze gratuit)
- `docs/roadmap-lab/competitive/tft.md` §1.2, §1.3, §1.4 (XP passive, cotes, reroll 2g)
- `docs/roadmap-lab/competitive/hs-battlegrounds.md` §1.1 (freeze gratuit, taverne tier)
- `docs/roadmap-lab/competitive/backpack-battles.md` (rareté shift, pas de freeze)
- `docs/roadmap-lab/competitive/the-bazaar.md` §9.1 (or + income, reroll coûteux S1)

**Sources web nouvelles** :
- [TFT Leveling Mechanics — tft.ninja](https://tft.ninja/guides/game-mechanics/leveling)
  (XP passive +2/round à partir du stage 2 — notre no-XP-R1 est le même modèle)
- [TFT Leveling Guide 2025 — immortalboost.com](https://immortalboost.com/blog/teamfight-tactics/leveling/)
  (fast 8 / fast 9 / slow roll = 3 politiques distinctes de tension XP)
- [TFT Economy Mastery — boosteria.org](https://boosteria.org/guides/tft-economy-mastery)
  (plafond psychologique du hunt : ~12 rerolls pour 50 % de chance sur un tier-4 spécifique)
- [Super Auto Pets Shop — superautopets.fandom.com](https://superautopets.fandom.com/wiki/Shop)
  (freeze SAP = **totalement gratuit**, pas de coût en slot)
- [Super Auto Pets Freeze Strategy — youtube.com (Freezing The Shop)](https://www.youtube.com/watch?v=M1BfVvvJru4)
  (freeze = outil de timing, pas de hunt long)
- [Backpack Battles — Wikipedia](https://en.wikipedia.org/wiki/Backpack_Battles)
  (rareté shift progressif, pas de freeze, pool restreint par round)
- [The Bazaar Review — mobalytics.gg](https://mobalytics.gg/news/guides/the-bazaar-review)
  (reroll coûteux en S1 = problème corrigé en S2 ; budget 15g + income)
- [Slay the Spire 2 Gold Economy — sts2front.com](https://sts2front.com/tips/gold-economy-guide/)
  (domination d'une option → séquence prédéterminée, pas tension)
- [When to Level vs Roll — tft.ninja](https://tft.ninja/guides/strategy/when-to-level)
  (confirmation que la tension XP est un axe de skill distinct du roll down)

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 2. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants non modifiés.*
