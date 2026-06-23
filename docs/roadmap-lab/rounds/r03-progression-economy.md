# Round 03 — Critique adversariale : Progression & Économie

> **Lentille** : Progression & économie — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v3, intégré round 2) et des rapports
> `rounds/r02-progression-economy.md` et `rounds/r01-progression-economy.md`. Accords argumentés
> / désaccords sourcés / propositions concrètes, chiffrées, priorisées. Aucune modification du
> code du jeu.
>
> **Sources primaires relues** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v3, `docs/roadmap-lab/00-state.md`,
>   `docs/roadmap-lab/round-01.md`, `docs/roadmap-lab/round-02.md`,
>   `docs/roadmap-lab/rounds/r01-progression-economy.md`,
>   `docs/roadmap-lab/rounds/r02-progression-economy.md`,
>   `docs/research/progression-economy-prd.md`.
> - Concurrence : `competitive/super-auto-pets.md`, `competitive/tft.md`, `competitive/balatro.md`,
>   `competitive/hs-battlegrounds.md`, `competitive/backpack-battles.md`, `competitive/the-bazaar.md`.
> - Sources web nouvelles (citées au fil du texte).

---

## 0. Thèse de ce round

Les deux rounds précédents ont convergé sur les bonnes décisions structurelles (or fixe, XP
TFT-style, cost=rank, slot-decline à mesurer) et ont corrigé les erreurs factuelles. Ce round
apporte un regard sur **quatre zones encore sous-analysées ou mal fondées** :

1. **La courbe XP est mal calibrée pour un run court de 10 victoires** : les seuils `{2,5,8,12}`
   avec passive 1/round produisent une progression boutique **presque plate** perçue, sans climax
   mid-late. La comparaison avec TFT est paresseuse car les conditions de jeu sont radicalement
   différentes (25+ rounds vs 10-20 combats).
2. **Le ratio `BUY_XP_COST = 4 or / 4 XP` (ratio 1:1) est psychologiquement mal positionné** :
   dans TFT, le ratio est aussi 4g/4XP — mais TFT a des seuils exponentiels (278 XP cumulées
   pour le niveau 9) sur 25+ rounds. Sur notre run court, le ratio 1:1 avec des seuils linéaires
   `{2,5,8,12}` fait que BUY XP est toujours la décision dominante mid-game, ce qui efface la
   tension.
3. **Le slot-decline a été promu en drapeau de sim mais sans borne de décision explicite** : le
   round 2 a bien posé le problème, mais la proposition de remède (réduire SLOT_DECLINE_GOLD à
   1-2 ou borner N refus) n'est pas assez précise. Il existe une troisième option plus élégante
   qui n'a pas été explorée.
4. **Le pity-tracker (litige #E) a été déclaré secondaire après l'audit de pool sans preuve
   que l'audit seul suffira** : la mathématique de dilution est correcte, mais le pity-tracker
   résout un problème psychologique **distinct** du problème de pool — même sur un pool réduit
   à 50-60 unités, le hunt reste psychologiquement frustrant sans signal d'escalation.

---

## 1. Accords avec pourquoi

### 1.1 Or fixe + streaks anti-snowball : oui, les maths tiennent pour le RUN COURT

**Accord total**, et l'argument est maintenant encore plus solide qu'en round 1.

Sur un run de 10-20 combats avec `GOLD_PER_ROUND = 10`, une banque avec intérêt TFT-style
générerait au maximum ~3 rounds × 10g × 10 % = +3g d'intérêt sur toute la partie dans le
meilleur cas de conservation. Cela ne crée pas un axe stratégique — cela crée une charge
cognitive sans payoff. Confirmation par le teardown TFT (`competitive/tft.md §1.2`) : TFT
a un revenu passif VARIABLE (2g→5g selon le round) ET l'intérêt sur 50g stockés = +5g, sur
un jeu de 25+ rounds avec économie bancable. Nos conditions ne permettent pas ce transfert.

Les streaks comme redistributeur (`STREAK_CAP = 3`) restent l'anti-snowball correct et
transférable (psychologie de « l'égalisateur », pas du « bonus de domination »).

**Pourquoi ça tient pour NOS contraintes** : run async à 10 victoires = pas de lobby en temps
réel = pas d'information sur le niveau d'or des adversaires = aucun avantage signal de la banque
(une des fonctions cachées de l'intérêt TFT est social — détecter quand les autres économisent).
Source : [TFT Economy Mastery — boosteria.org](https://boosteria.org/guides/tft-economy-mastery).

### 1.2 `cost = rank` : accord total, la lisibilité est non-négociable

La décision est correcte et bien fondée. Le prix visible = complexité visible = décision à
information complète. Aucune nuance à ajouter, la décision est verrouillée (00-state §1, #10).

### 1.3 Refund 0.5× : oui, l'asymétrie engageante est correcte

Accord maintenu. La vente = accepter une perte = commitment psychologique réel. SAP confirme
le mécanisme (L3 = 3g sur 18 investis ≈ 17 %) — notre 0.5× est plus généreux mais préserve
l'asymétrie. Source : [`superautopets.fandom.com/wiki/Shop`](https://superautopets.fandom.com/wiki/Shop).

### 1.4 Décision de mesurer le slot-decline PAR SIM avant de figer : accord de méthode

Le round 2 (`r02-progression-economy §2.3`) a correctement élevé ce point en précondition
mesurée. La méthode est bonne. Ce round propose cependant une option de remède plus précise
(voir §3.3).

### 1.5 Formule daily corrigée vers `wins × (10 − lives) × speed_mult` : accord fort

La correction du round 2 est bien fondée sur 3 convergences. Le bug `×(1+xp_spent)` était
réel : récompenser l'investissement brut en XP plutôt que l'efficience inverse l'intention du
design. La formule `speed_mult` (2.0/1.5/1.0/0 selon la vitesse) mesure correctement l'efficience
naturelle (rapidité de construction + propreté). Accord sans réserve.

La sous-question du litige #H (chute 8-9 wins → `speed_mult = 0` ou `0.5`) est ouverte et
légitime. Ce round pencherait pour **`0.5` pour les chutes 8-9 wins seulement** : une chute
à 9 wins signifie que le joueur a traversé 18+ combats gagnants — punir à zéro ce profil envoie
le mauvais signal psychologique (« même un très bon run raté vaut rien »).

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La courbe XP est mal calibrée pour un run court : les seuils `{2,5,8,12}` avec passive 1/round produisent une tension presque plate, sans climax

**Claim du brouillon v3 / PRD** (`progression-economy-prd.md §3.3`) : « un joueur passif
atteint ~tier 3 en fin de partie ; un joueur qui rush atteint tier 5 vers le milieu. Passive =
plancher montant, achat = accès au sommet ».

**Le problème — les maths ne produisent pas l'intention** :

Avec `XP_TO_LEVEL = {[1]=2, [2]=5, [3]=8, [4]=12}` et `PASSIVE_XP_PER_ROUND = 1` (à partir
du round 2) :
- Seuils **cumulés** : T2=2, T3=7, T4=15, T5=27 XP.
- Sur un run de 15 rounds (10 victoires + 5 rounds) : XP passive totale = 14 XP (rounds 2-15).
- Résultat passif sur 15 rounds : T4 atteint au round 16 (15 XP) → **T4 JAMAIS atteint en run
  normal**. T3 atteint au round 8 (7 XP). T2 atteint au round 3 (2 XP).
- Résultat passif sur 10 rounds (run très court) : 9 XP → milieu de T3.

L'**intention** est « passif ≈ tier 3 en fin de partie ». La **réalité** : passif atteint T3
autour du round 8 et reste bloqué au seuil de T4 jusqu'à la fin. Le tier 4 est quasi-inaccessible
sans achat actif d'XP, et le tier 5 est réservé aux joueurs qui RUSH les premiers rounds.

**Conséquence de design** : la tension « monter vs reroll vs acheter » est faussement plate au
milieu du run. En T3 (rounds 8-12), BUY XP coûte 4 or pour progresser vers T4 (qui requiert
`15 - XP_actuelle` ≈ 8-10 XP nettes après passive). Un achat de 4 XP = 4 or pour avancer de
~moitié vers T4. C'est une décision RÉELLE — mais elle n'a pas de signal de progression visible
sans la barre d'XP UI.

**Plus grave** : les seuils `{2,5,8,12}` croissent de +3 à chaque palier (linéaire). Or la
passive est aussi linéaire (1/round). Les deux progressent au même rythme → **la tension
perçue est CONSTANTE**, il n'y a pas de climax économique mid-late où la décision d'acheter
de l'XP devient soudainement beaucoup plus coûteuse ou payante.

**Comparaison TFT (anti-analogie à démonter)** : TFT a des seuils exponentiels (niveau 9 =
278 XP cumulées, source : [lolchess.gg/guide/exp](https://lolchess.gg/guide/exp?hl=en-US))
et un revenu passif de **2 XP/round** (pas 1) sur 25+ rounds. La tension TFT crée un climax
réel en « Fast 9 » car les paliers tardifs exigent un engagement économique massif qui crée
une vraie tension (dépenser 30g pour 8 niveaux = énorme sacrifice). Sur notre run court avec
seuils linéaires `{2,5,8,12}`, la tension équivalente n'existe pas — c'est 4 or pour 4 XP,
tout le temps, jusqu'au bout.

**Ce qui manque** : un palier de seuil qui monte plus vite que la passive — un **coût marginal
croissant** sur les derniers tiers. Si T4→T5 coûtait 20 XP (au lieu de 12) avec passive 1/round,
l'écart entre passif (plafonnant à T3) et rush (atteignant T5 mid-game) serait plus dramatique et
la décision d'investir en XP en mid-game serait clairement coûteuse.

**Proposition concrète** (§3.1 ci-dessous).

Source de design comparatif : [TFT Leveling Mechanics — lolchess.gg](https://lolchess.gg/guide/exp?hl=en-US)
(seuils cumulés TFT niveaux 2-9 : 2, 6, 10, 20, 36, 56, 80, 100 XP — exponentiels sur les
derniers niveaux) ; [TFT Economy Mastery — boosteria.org](https://boosteria.org/guides/tft-economy-mastery)
(tension Fast 8 vs Fast 9 = climax économique car niveaux tardifs très coûteux).

### 2.2 DÉSACCORD — Le ratio `BUY_XP_COST = 4 / BUY_XP_AMOUNT = 4` (1:1) est neutre là où il devrait créer une TENSION

**Claim implicite du PRD et du brouillon** : le ratio 1:1 est le même que TFT (4g=4XP) donc
valide. L'analogie est paresseuse.

**Pourquoi le ratio 1:1 TFT ne transfère pas** :

Dans TFT, 4g=4XP est une décision coûteuse en mid-game car :
1. L'**intérêt** fait que 4g non dépensés = +0.4g de plus/round en moyenne (subtilement).
2. Les **seuils exponentiels** font que 4 XP valent plus à un bas niveau (T2→T3 coûte 8 XP
   totales) qu'à un haut niveau (T8→T9 coûte 100 XP totales). Le coût marginal de 4 XP augmente.
3. Le jeu dure 25+ rounds, donc la passive s'accumule et rend l'achat MOINS urgent en début.

Chez nous, avec des seuils linéaires et pas d'intérêt, 4g=4XP a la MÊME valeur perçue au
round 3 qu'au round 12. C'est une décision plate. La tension vient uniquement du coût d'opportunité
(4g = 4 rerolls = 1 unité rang-4), pas de la valeur croissante de l'XP elle-même.

**Ce que ça implique** : la formulation du PRD « le ratio 1:1 est le sel » est incorrecte — le
sel est le **coût d'opportunité pur**, pas le ratio. Ce n'est pas la même psychologie. La décision
d'acheter de l'XP TFT est stratégique (timing, adaptation à la méta). La nôtre est une décision
de **taux de conversion** plate entre deux axes comparables (XP vs rerolls).

**Proposition concrète** : voir §3.1. Un ratio variable (coût d'achat XP PLUS ÉLEVÉ en mid-game)
ou une réduction du `BUY_XP_AMOUNT` (acheter 3 XP pour 4g au lieu de 4) créerait une vraie
asymétrie — mais cela nécessite une sim. Ce n'est pas un blocage, c'est un levier à calibrer.

**Source** : [TFT Fast 8 vs Fast 9 — goboost.gg](https://goboost.gg/blog/tft-economy-masterclass-fast-8-vs-fast-9-strategies-pre-april-15/)
(la tension vient de l'exposition à des économies différentes, pas du ratio brut XP/g) ;
[TFT Standard Leveling — mobalytics.gg](https://mobalytics.gg/tft/guides/standard-leveling-strategy)
(la décision de monter = adaptation au contexte, pas automatisme).

### 2.3 DÉSACCORD MINEUR — Le slot-decline a un troisième remède non exploré, plus élégant

**Claim du round 2** (`r02-progression-economy §3.3`) : options A (réduire SLOT_DECLINE_GOLD
à 1-2) ou B (borner N refus/run). Correct mais incomplet.

**Option C non explorée — le slot décliné BASCULE en XP passive gratuite** :

Si décliner un slot octroie `+1 XP passive gratuite` (au lieu ou en plus de +3 or), le refus
d'un slot feed directement la progression boutique du joueur. Conséquences :
- Un joueur « tall » qui refuse tous les slots reçoit +6 XP gratuites sur le run (rounds 2-7) →
  atteint T3 plus tôt, avec moins d'achat d'XP actif.
- La décision de décliner devient un **trade « slots vs boutique tier »** (largeur vs
  profondeur de catalogue), ce qui EST le bon design.
- Cela **découple** l'or du slot-decline (le levier de casse est l'accumulation d'or, pas l'XP).

Cette option est plus **cohérente avec la thématique du run** (descendre le Puits = progresser
en profondeur, pas en largeur = archétype de build valide ET récompensé différemment de « wide »).

**Vérification nécessaire** : +6 XP gratuites sur run ≈ +6 rounds d'avance sur la passive.
Un joueur « tall » (refus systématique) vs « wide » (acceptation systématique) : diff d'XP
= 6 XP → tier T4 atteint au round 10 (vs 16 en passif pur). **Ce n'est pas trivial** — cela
compense le désavantage slots. Sim nécessaire (política « tout refuser » vs « tout accepter »
avec l'option C active).

**Garde-fou** : `SLOT_DECLINE_GOLD` peut être conservé à 3 or mais réduit à 1 or + 1 XP passif
(somme plus faible en or, plus riche en progression). Modification de constantes uniquement.
Aucun invariant touché.

### 2.4 DÉSACCORD — Le pity-tracker résout un problème PSYCHOLOGIQUE distinct de la dilution de pool

**Claim du round 2** (`r02-progression-economy §3.2`) : le freeze et le pity sont secondaires
après l'audit de pool (P0.5 §3.1). « La dilution est désormais adressée en amont » par l'audit.

**Pourquoi c'est incomplet — la dilution et la frustration de hunt sont deux problèmes distincts** :

La dilution de pool est un **problème mathématique** (P(unité spécifique) trop faible).
La frustration de hunt est un **problème psychologique** (manque de signal d'escalation vers le
joueur). Ces deux problèmes sont indépendants et coexistent même après réduction du pool.

Même si l'audit ramène le pool rang-2 à ≤4 enablers/famille/rang (de 6 à 4 pour poison rang-2),
P(unité rang-2 spécifique par boutique en tier-2) = 5 × 0.30 / 16 ≈ **9.4 %** (au lieu de 6.5 %).
Hunt médian pour 3 copies ≈ 32 boutiques (au lieu de 46). C'est mieux, mais toujours ~6-7 rounds
sans garantie. Le joueur voit 20 unités différentes défiler sans voir celle qu'il cherche et ne sait
pas si c'est « normal » ou « malchance exceptionnelle ».

**La psychologie de la frustration de hunt** : ce n'est pas la probabilité qui frustre — c'est
l'**absence de signal de progression**. Sans pity, chaque reroll à vide est perçu comme un
recommencement (not an advance). Le joueur rationalise « j'ai pas de chance » plutôt que
« je progresse vers la garantie ». La recherche sur les pity systems montre que l'effet
psychologique clé est la **transformation du sentiment de hasard pur en sentiment de progression
vers l'inévitable** — même si la probabilité per-roll est identique.

Source : [Pity System analysis — mwm.ai](https://mwm.ai/glossary/pity-system) (« the pity system
transforms random outcomes into a sense of progress ») ; [Gambling Mechanics in Gacha Games —
Uniwriter.ai](https://www.uniwriter.ai/psychology/gambling-mechanics-in-gacha-games-their-detrimental-effects-and-potential-mitigation-measures/)
(la perception de proximité = plus important que la probabilité réelle).

**Caveat important** : le pity-tracker a une face sombre — il est associé aux mécanismes de
gacha P2W dans la littérature (réf. ci-dessus). Dans notre cas, il s'applique à des unités en
boutique payées en or in-game, pas en monnaie réelle. Le principe psychologique est transférable
(signal de progression vers l'inévitable), mais doit être nommé clairement comme « garantie de
progression par effort », pas comme « manipulation de la perception ».

**Dans notre cas, un pity-tracker est déontologiquement sain** car : (a) aucune monnaie réelle
n'est impliquée ; (b) l'or vient du gameplay, pas de l'achat ; (c) il corrige une frustration
réelle de pool uniforme, pas une frustration artificielle. **La distinction est cruciale.**

**Verdict** : le pity-tracker n'est PAS secondaire après l'audit de pool — il est
**complémentaire et orthogonal**. Audit de pool = réduit la durée médiane de hunt. Pity-tracker
= transforme la psychologie du hunt quelle que soit sa durée. Les deux sont nécessaires.

**Proposition concrète** (§3.4 ci-dessous).

---

## 3. Propositions priorisées

### 3.1 P3 — Courber les seuils XP pour créer un vrai climax économique mid-late [PRIORITÉ 1 — correctif de calibration]

**Quoi** : réviser `XP_TO_LEVEL` pour des seuils à **coût marginal croissant** sur les tiers tardifs.

**Proposition concrète [PH, à valider sim]** :
```
XP_TO_LEVEL = { [1]=2, [2]=5, [3]=10, [4]=18 }
-- Cumulé : T2=2, T3=7, T4=17, T5=35
-- vs. actuel : T2=2, T3=7, T4=15, T5=27
```

Avec cette courbe et passive 1/round (runs 15 rounds) :
- T4 atteint au round 18 en passif pur → **jamais passif** (intention correcte : passif ≈ T3).
- T3 atteint au round 8 (inchangé).
- Rush maximal T1-T5 : ~35 XP = ~9 achats × 4g = 36 or investis (≈ 3-4 rounds de budget total
  sacrifié, décision VRAIMENT coûteuse).

**Pourquoi les seuils actuels sont insuffisants** : `XP_TO_LEVEL[4] = 12` est trop proche de
`XP_TO_LEVEL[3] = 8` (ratio 1.5). Dans TFT, le ratio entre palier 3 et 9 est ×50. Notre ×2
entre T3 et T5 actuel ne crée pas de climax. Le nouveau ratio ×2.5 entre T3 et T4 (5→10) est
plus proche d'une progression sentie.

**Garde-fou** : changement de constante uniquement (`state.lua`). Aucun invariant touché. La
cascade XP (trop-plein reporté) reste fonctionnelle. Tester via `tools/sim.lua` :
- Politique A « passif pur » : tier atteint à chaque round.
- Politique B « rush maximal » : tier atteint + win-rate.
- Critère : T4 jamais atteint passif (intention) ET rush T5 coûte ≥25 % du budget total du run.

**Source de design** : [TFT XP Seuils — lolchess.gg](https://lolchess.gg/guide/exp?hl=en-US)
(croissance super-linéaire des paliers tardifs = leçon de design clé) ; progression-economy-prd.md §3.3
(intention explicite « passif ≈ T3 », actuel = pas garanti par les maths).

### 3.2 P3 — Asymétrie de coût BUY XP selon le tier courant [OPTIONNEL — à étudier APRÈS sim 3.1]

**Quoi** : une fois les seuils corrigés (§3.1), évaluer si un `BUY_XP_COST` VARIABLE ajoute de la
tension ou de la confusion. Deux formulations possibles :

**Option A — Coût d'achat croissant** : `BUY_XP_COST = 3 or` en T1-T2, `4 or` en T3, `5 or`
en T4 (T4 achat = décision très coûteuse, rare). Psychologie : le coût marginal augmente juste
quand les seuils augmentent → double effet de frein.

**Option B — Quantité décroissante** : `BUY_XP_AMOUNT = 4` en T1-T2, `3` en T3, `2` en T4.
4g = moins de XP à mesure qu'on monte → même effet psychologique, mais plus lisible (l'efficience
de l'achat diminue visiblement).

**Pourquoi OPTIONNEL** : c'est une innovation de design non testée dans les références. SAP
n'a pas d'XP de boutique du tout. TFT a un coût fixe (4g=4XP tout le jeu). Ajouter de la
complexité sur un levier déjà sous-documenté dans l'UI = risque de lisibilité.

**Recommandation** : ne pas activer avant d'avoir mesuré l'effet des seuils seuls (§3.1).
Si la sim montre que les seuils corrigés suffisent à créer la tension, ne pas ajouter ce mécanisme.

### 3.3 P3 — Slot-decline avec option C : XP passive + or réduit [PRIORITÉ 2 — à tester en sim]

**Quoi** : modifier `SLOT_DECLINE_GOLD` et ajouter un `SLOT_DECLINE_XP = 1`.

**Proposition concrète** : décliner un slot = `+1 or` (au lieu de `+3 or`) + `+1 XP passive`.

**Maths** : refuser tous les slots (rounds 2-7) = `+6 or cumulés` (vs `+18 actuels`) + `+6 XP
passives` (= avancer de ~6 rounds sur la courbe boutique). Impact net sur l'accès au tier :
si les seuils sont corrigés (§3.1), `+6 XP` = avancer de T2 à ~T3-T4 sans achat. L'avantage
est en PROFONDEUR DE CATALOGUE, pas en or à dépenser. Cela aligne l'archétype « tall » avec
une boutique de qualité supérieure plutôt qu'un surplus d'or.

**Sim cible** : comparer « tout refuser avec option C » vs « tout accepter » :
- Si win-rate(refus) > win-rate(acceptation) + 5 % → option C trop forte → réduire `SLOT_DECLINE_XP`.
- Si indifférent → option C est un bon design neutre.
- Si acceptation domine → l'or seul ne compense pas les slots → slot-decline psychologiquement
  inintéressant → remonter l'or.

**Garde-fou** : modification de constantes. L'ajout de `SLOT_DECLINE_XP` dans `state.lua:startRound`
est trivial (si decline, `self.shopXp += SLOT_DECLINE_XP`). Aucun invariant touché.

### 3.4 P3 — Pity-tracker seed-dérivé, COMPLÉMENTAIRE à l'audit de pool [PRIORITÉ 2 — pas secondaire]

**Quoi** : implémenter un pity-tracker pour les 3e copies d'unités cherchées.

**Conception concrète (déterministe, compatible sim déterministe)** :
- Le pity-tracker est attaché à l'**unité cherchée** (son `id`), pas à un compteur global.
- Il incrémente quand la boutique ne propose PAS l'unité (0→N), et se réinitialise quand elle est
  achetée (ou la 3e copie obtenue).
- À partir de `PITY_START = 8` rerolls vides, la probabilité de voir l'unité augmente de +5 %
  par reroll supplémentaire, cappée à ×2 (double probabilité max).
- **Le pity est seed-dérivé** : le compteur de pity doit être intégré dans le RNG seedé du run
  (pas une accumulation de rerolls réels, qui n'est pas déterministe cross-session). Implémentation :
  `pity[id] = f(run_seed, round, nb_rerolls_depuis_derniere_vue)` — **ce point est critique** et
  était déjà signalé dans le brouillon v3 §7.3.

**Pourquoi COMPLÉMENTAIRE (pas secondaire)** : même après l'audit de pool (≤4 enablers/famille/rang),
le hunt médian rang-2 en T2 reste ~32 boutiques (≈6-7 rounds). Le pity s'active à partir du 8e
reroll sans voir l'unité — **précisément dans la zone de frustration** (après 8 rerolls vides sur
une unité cherchée, un joueur rationnel commence à abandonner la poursuite). Signal au bon moment.

**Validation : 2 mesures sim nécessaires avant d'activer** :
1. Hunt médian après audit de pool (§P0.5) : si p50 rang-2 en T2 < 5 rerolls → pity inutile.
2. Distribution des runs avec/sans pity sur 200 seeds → impact sur le win-rate et le moment
   de l'ascension.

**Garde-fou contre la gacha-fication** : pity visible dans l'UI (barre de pity, ou compteur
« vu X fois sans la 3e copie »). Transparency = l'opposé de la manipulation. La progression
VERS la garantie doit être perçue par le joueur comme une progression de compétence (persévérance),
pas comme une loterie qui finit par payer.

Source : [mwm.ai Pity System](https://mwm.ai/glossary/pity-system) (transformation du hasard
en progression perçue) ; brouillon v3 §7.3 (seed-dérivé mentionné mais pas encore conçu).

---

## 4. Questions ouvertes pour les rounds suivants

### Q1 — Les seuils XP corrigés créent-ils un vrai climax sans rendre les tiers tardifs inaccessibles ?

L'intention est que T4 reste accessible avec un investissement actif mais significatif (≥15-20 or
investis sur la run). Si les seuils corrigés rendent T4 inaccessible même en rushant modérément,
les unités rang-4 deviennent trop rares pour un build standard. **Seuil de décision** : p50 des
runs avec politique XP-moyenne (ni passif pur, ni rush) doit atteindre T3 en fin de run et voir
occasionnellement T4. Sim obligatoire avant de graver.

### Q2 — Le `PASSIVE_XP_PER_ROUND = 1` doit-il escalader en mid-game (par ex. +2 en round 8+) ?

La passive plate (1/round) produit une progression linéaire. Une escalation de la passive en
mid-late game (+1 en rounds 2-6, +2 en rounds 7+) créerait un sentiment de « la boutique évolue
naturellement » sans action du joueur — ce qui renforce la narration « descente du Puits » (on
va plus profond = la boutique devient plus riche automatiquement). **Risque** : trop genereux en
late → T5 accessible passivement → XP achetée inutile. À mesurer.

### Q3 — L'option C du slot-decline crée-t-elle une asymétrie « tall vs wide » psychologiquement lisible ?

Le design intendu est que refuser des slots = choix de profondeur (boutique avancée) plutôt que
largeur (9 cases). L'option C encode cela mécaniquement (XP au lieu d'or). Mais est-ce **lisible**
en une ligne dans l'UI ? « Refuser : +1 or +1 XP boutique » — un joueur débutant comprend-il que
« XP boutique » = accès à de meilleures unités ? Le libellé UI est critique.

### Q4 — La garantie de pertinence relique au round ≤4 (risque de boucle circulaire) est-elle mesurable
avant l'implémentation de P1.5a ?

Le round 2 a identifié ce risque (`round-02.md §1.7`) : au 1er marchand (round 3-4), le plateau
est souvent du rang-1 de la famille la plus commune → la garantie confirme le joueur dans son
premier axe. La mitigation proposée (si ≥5 unités du type au rang-1, proposer aussi 1 type non-
présent) est correcte mais **non vérifiée par sim**. Avant d'activer P1.5a, mesurer sur 200 seeds
la distribution des familles au round 3 : si >70 % des joueurs ont une famille dominante à 3-5
unités → le risque est réel. Si < 40 % → mitigation inutile.

---

## 5. Synthèse des points clés pour la roadmap

### Ce qui change par rapport aux rounds 1 et 2 :

1. **Seuils XP à corriger AVANT de calibrer les cotes** : les seuils linéaires `{2,5,8,12}`
   ne produisent pas l'intention (passif ≈ T3) et ne créent pas de climax économique. Correction :
   `{2,5,10,18}` [PH] avec validation sim. **Ce chantier est distinct du P3 équilibrage** — c'est
   un correctif de calibration qui doit passer avant de figer les cotes par rang.

2. **Le ratio BUY_XP 1:1 est neutre, pas tendu** : la tension vient du coût d'opportunité
   (4or = 4 rerolls), pas du ratio lui-même. L'analogie TFT est paresseuse (conditions de jeu
   radicalement différentes). À surveiller en sim après correction des seuils.

3. **Slot-decline : option C plus élégante** (XP + or réduit) crée un trade « largeur vs
   profondeur de boutique » qui encode l'intention design mieux que les options A (réduire or)
   ou B (borner refus) seules.

4. **Pity-tracker : NOT secondaire, COMPLÉMENTAIRE à l'audit de pool** — résout un problème
   psychologique distinct (signal d'escalation vers l'inévitable). Doit être conçu comme seed-
   dérivé (non lié à une accumulation de rerolls réels). À valider sim APRÈS audit de pool.

### Ce qui reste inchangé et tient :

- Or fixe + streaks anti-snowball : structurellement correct, maths prouvées pour run court.
- `cost = rank` : non négociable, verrouillé.
- Refund 0.5× : engagement garanti, psychologie correcte.
- Formule daily `wins × (10 − lives) × speed_mult` : correction round 2 solide. Chute 8-9 →
  `speed_mult = 0.5` recommandé (contre `= 0`).
- P1.5a (garantie de pertinence B-E + conditionner toutes E tier-4 + règle ≥2 reliques/archétype) :
  data-pure, pas de dépendance, doit rester remonté en // P0.

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` (constantes éco, passive XP round 2+, seuils XP_TO_LEVEL)
- `docs/roadmap-lab/00-state.md` §4 (constantes, cotes, boucle)
- `docs/roadmap-lab/ROADMAP-draft.md` v3 §2-7 (chantiers P0-P3)
- `docs/roadmap-lab/round-01.md`, `round-02.md` (synthèses précédentes)
- `docs/roadmap-lab/rounds/r01-progression-economy.md`, `r02-progression-economy.md`
- `docs/research/progression-economy-prd.md` §3 (PRD verrouillé, intentions de calibrage)
- `competitive/tft.md` §1.2 (seuils XP, or passif, intérêt)
- `competitive/super-auto-pets.md` §1.1 (or fixe, freeze, mécanique pets)

**Sources web nouvelles** :
- [TFT XP Seuils Cumulés — lolchess.gg/guide/exp](https://lolchess.gg/guide/exp?hl=en-US)
  (T2=2, T3=6, T4=10, T5=20, T6=36, T7=56, T8=80, T9=100 XP cumulées → super-linéaires)
- [TFT Leveling Mechanics — tft.ninja](https://tft.ninja/guides/game-mechanics/leveling)
  (XP passive = 2/round à partir du stage 2 ; notre 1/round = différent)
- [TFT Economy Mastery — boosteria.org](https://boosteria.org/guides/tft-economy-mastery)
  (tension Fast 8 vs Fast 9 = climax économique par seuils tardifs, pas par ratio brut)
- [TFT Fast 8 vs Fast 9 — goboost.gg](https://goboost.gg/blog/tft-economy-masterclass-fast-8-vs-fast-9-strategies-pre-april-15/)
  (décision de level = adaptation contextuelle, pas automatisme de ratio)
- [TFT Standard Leveling — mobalytics.gg](https://mobalytics.gg/tft/guides/standard-leveling-strategy)
  (la tension XP crée des archétypes de jeu distincts = Fast 8, Fast 9, slow roll)
- [Pity System Analysis — mwm.ai](https://mwm.ai/glossary/pity-system)
  (transformation du sentiment de hasard pur en progression vers l'inévitable)
- [Gambling Mechanics in Gacha — Uniwriter.ai](https://www.uniwriter.ai/psychology/gambling-mechanics-in-gacha-games-their-detrimental-effects-and-potential-mitigation-measures/)
  (effets psychologiques des pity systems — face sombre applicable au gacha payant, pas à l'or in-game)
- [Backpack Battles Game Mechanics — backpackbattles.wiki.gg](https://backpackbattles.wiki.gg/wiki/Game_Mechanics)
  (pas d'XP/leveling boutique — la tension est entièrement dans l'or et les items) ; confirmation
  que l'absence d'XP boutique dans Backpack est un choix volontaire, pas une lacune
- [Super Auto Pets Experience — superautopets.fandom.com](https://superautopets.fandom.com/wiki/Experience)
  (XP dans SAP = leveling des pets, pas de la boutique — autre mécanisme)
- [GDC Vault — Slay the Spire: Metrics Driven Design](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics)
  (évaluation par archétype, pas win-rate brut — applicable à l'audit des politiques XP)

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 3. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants non modifiés.*
