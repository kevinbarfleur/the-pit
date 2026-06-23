# Analyse concurrentielle ultra-approfondie — Teamfight Tactics

> **Mandat (BRIEF.md §Analyse concurrentielle)** : pour chaque mécanisme clé de TFT —
> teardown précis → psychologie → maths chiffrées et sourcées → verdict de transférabilité
> à *The Pit* (async snapshots, run court 10 victoires, sim déterministe, grimdark).
> Démonter les analogies paresseuses. Citer toutes les sources.
>
> **Garde-fous absolus** : ce fichier vit sous `docs/roadmap-lab/` ; aucune modification
> du code du jeu. Sources citées par URL pour chaque affirmation chiffrée.

---

## 0. TL;DR exécutif

TFT est une machine à extraction de décisions continues dans un jeu à information partielle
où la compétence consiste à naviguer intelligemment le RNG. Ses mécanismes — odds-gating,
intérêt/banque, augments, carrousel, traits, ranked LP — ont chacun une logique
psychologique et mathématique précise. La plupart des mécanismes *centraux* de TFT sont
**non-transférables directement** à *The Pit*, non par paresse de copie, mais parce que nos
contraintes (async pur, run court 10V, pas de lobby partagé de 8 joueurs en direct) en
invalident les fondements structurels. Les mécanismes *psychologiques sous-jacents*, eux,
sont transférables — mais ils nécessitent une réinterprétation architecture par architecture.

---

## 1. Boucle de jeu — teardown complet

### 1.1 Structure d'une partie

Un lobby TFT = **8 joueurs humains** en temps réel, durée **30–40 minutes** en standard
([1v9.gg](https://1v9.gg/blog/how-long-is-a-tft-game), [CompetitiveTFT/X](https://x.com/CompetitiveTFT/status/1140646056977453058)),
10–15 minutes en Hyper Roll ([esports.gg](https://esports.gg/news/teamfight-tactics/everything-you-need-to-know-about-tft-hyper-roll/)).

```
[Phase de préparation ~30s]
  → Acheter unités (boutique 5 slots)
  → Positionner sur grille 28 hexagones
  → Combiner items (9 composants de base)
  → Acheter XP ou reroll
[Combat auto ~3min]
  → Spectateur ; résolu déterministement
  → Perdant → dégâts au joueur
  → Éliminé quand HP = 0
  → Vainqueur = dernier debout
[Carrousel (fin de chaque stage)]
  → Île centrale partagée
  → Ordre de pick : HP le plus bas d'abord
  → 1 unité + 1 item = équipement gratuit
```

**Stages** : chaque stage = 3 à 5 rounds (dont 1 PvE "creep round"). Un round = 1 préparation
+ 1 combat. La partie se finit quand 1 joueur survit.

### 1.2 Économie — teardown mathématique complet

**Or passif par round** (source : [op.gg TFT gold-xp](https://op.gg/tft/game-guide/gold-xp)) :
```
Rounds 1-2 : +2g
Round 1-3  : +2g
Round 1-4  : +3g
Round 2-1  : +4g
Round 2-2+ : +5g (base définitif)
+ Win PvP  : +1g par victoire
```

**Intérêt** (source : [op.gg](https://op.gg/tft/game-guide/gold-xp)) :
```
0-9g   stocké → +0g intérêt
10-19g stocké → +1g
20-29g stocké → +2g
30-39g stocké → +3g
40-49g stocké → +4g
50g+   stocké → +5g (plafond)
```
L'intérêt se calcule sur l'or STOCKÉ avant le revenu passif — incitation à économiser.

**Streaks** (source : [op.gg](https://op.gg/tft/game-guide/gold-xp)) :
```
2-3 win streak  : +1g
4 win streak    : +1g (même palier)
5 win streak    : +2g
6+ win streak   : +3g
2+ loss streak  : +1g
5 loss streak   : +2g
6+ loss streak  : +3g
```
→ Les streaks récompensent la *consistance* (gagner OU perdre de façon cohérente), pas la
domination. Un joueur qui accepte de perdre pour maximiser son loss-streak obtient de l'or
supplémentaire — tension intentionnelle avec l'objectif de victoire.

**Reroll** : 2g par reroll (1g en mode Hyper Roll).

**Vente d'unité** : valeur dépend du tier/étoile ; généralement inférieure au coût d'achat
(pas d'exploit de revente).

**Plafond pratique** : un joueur en "econ greedy" vise 50g stacked pour +5g d'intérêt/round,
soit environ +10g de revenu total/round à pleine cadence
([mobalytics.gg economy](https://mobalytics.gg/tft/guides/how-to-manage-your-economy-in-teamfight-tactics-three-strategies)).

### 1.3 XP et niveau de boutique — teardown mathématique

Source primaire : [tft.ninja/leveling](https://tft.ninja/guides/game-mechanics/leveling)

**XP requise par niveau** :
```
Niveau 2 : 2  XP (cumul : 2)
Niveau 3 : 6  XP (cumul : 8)
Niveau 4 : 10 XP (cumul : 18)
Niveau 5 : 20 XP (cumul : 38)
Niveau 6 : 36 XP (cumul : 74)
Niveau 7 : 48 XP (cumul : 122)
Niveau 8 : 72 XP (cumul : 194)
Niveau 9 : 84 XP (cumul : 278)
Niveau 10: 100 XP (cumul : 378)
```

**XP passive** : +2 XP automatiques à chaque début de round (à partir du stage 2).

**XP achetée** : 4g = 4 XP à tout moment en phase de préparation (ratio 1:1).

→ **Un joueur passif (0g dépensé en XP)** reçoit ~2 XP/round. Une partie standard = environ
25 rounds → ~50 XP passifs. Il atteint donc niveau **6** passivement (cumul 74 → environ
niveau 6 en fin de partie si on considère la cadence réelle de ~2 XP/round × ~35 rounds ≈
70 XP, soit juste sous le niveau 7).

→ **Stratégie "fast 9"** : dépenser toute l'or disponible en XP dès possible. Coût total
niveau 9 = 278 XP cumulés. 278 XP - ~50 passifs = ~228 XP achetés = ~228g en XP seulement.
Impossibles sans économie solide — d'où la tension avec le reroll et l'achat d'unités.

### 1.4 Cotes du shop — teardown mathématique

Source primaire : [esportstales.com/tft](https://www.esportstales.com/teamfight-tactics/champion-pool-size-and-draw-chances)
(Set 17, les valeurs varient légèrement entre sets)

**Pool par tier** (nombre d'unités total) :
```
Tier 1 (1-cost) : 30 exemplaires par champion
Tier 2 (2-cost) : 25 exemplaires par champion
Tier 3 (3-cost) : 18 exemplaires par champion
Tier 4 (4-cost) : 10 exemplaires par champion
Tier 5 (5-cost) :  9 exemplaires par champion
```
Le pool est **partagé** entre tous les joueurs — scarcité dynamique. Si 3 joueurs rushent
le même champion tier-4, les 30 exemplaires s'épuisent, les cotes s'effondrent.

**Odds par niveau du joueur (boutique 5 slots, Set 17)** :

| Niveau | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|--------|--------|--------|--------|--------|--------|
| 1      | 100%   | 0%     | 0%     | 0%     | 0%     |
| 2      | 100%   | 0%     | 0%     | 0%     | 0%     |
| 3      | 75%    | 25%    | 0%     | 0%     | 0%     |
| 4      | 55%    | 30%    | 15%    | 0%     | 0%     |
| 5      | 45%    | 33%    | 20%    | 2%     | 0%     |
| 6      | 30%    | 40%    | 25%    | 5%     | 0%     |
| 7      | 19%    | 30%    | 40%    | 10%    | 1%     |
| 8      | 17%    | 24%    | 32%    | 24%    | 3%     |
| 9      | 15%    | 18%    | 25%    | 30%    | 12%    |
| 10     | 5%     | 10%    | 20%    | 40%    | 25%    |
| 11     | 1%     | 2%     | 12%    | 50%    | 35%    |

**Conséquences mathématiques critiques** :
- Chaque slot de la boutique est un tirage indépendant selon ces probabilités.
- 5 slots → espérance par reroll d'une unité tier-4 spécifique au niveau 9 = 5 × 0.30 / Nc
  où Nc = nombre de champions tier-4 (≈18 en Set 17) = 5 × 0.30 / 18 ≈ **8.3 %** par reroll.
  → Environ **12 rerolls** (24g) pour 50% de chance de hit. Plafond psychologique du désespoir.
- Rareté tier-5 au niveau 7 (1%) : espérance de hit spécifique = 5 × 0.01 / 13 ≈ 0.38%/reroll
  → **264 rerolls** pour 50% de chance. Impraticable sans contrainte économique forte.

**"3-star" (3 étoiles)** : combine 3 exemplaires 2-star du même champion, soit 9 exemplaires
1-star totaux. Sur 30 exemplaires totaux d'un champion tier-1, un 3-star consomme 30% du pool
entier — vecteur de conflit inter-joueurs visible.

---

## 2. Mécanismes clés — teardown individuel

### 2.1 Le système de traits (synergies)

**Structure** : chaque champion appartient à 1–3 traits (origin + class). Aligner N champions
du même trait active un bonus de palier (2/4/6/8 selon le trait).

Exemples de paliers : "Avoir 3 Bruisers → +150 HP à toute l'équipe ; 6 Bruisers → +350 HP"
([dexerto.com synergy guide](https://www.dexerto.com/league-of-legends/teamfight-tactics-champion-synergy-guide-origins-classes-737400/)).

**Psychologie** : les traits créent des **objectifs intermédiaires lisibles** (compteur de
traits visible en permanence à gauche de l'écran). Chaque achat rapproche ou éloigne d'un
palier visible — mécanisme d'anticipation du reward (psychologie des progrès : Amabile &
Kramer 2011, "The Progress Principle"). L'effet de "near-palier" (5 sur 6 requis) est un
near-miss sous agence — le joueur *sait* ce qu'il lui manque et peut agir dessus.

**Interaction avec le pool** : si d'autres joueurs prennent les mêmes champions de trait,
la fenêtre de palier se ferme. Tension sociale sans communication directe.

**Mécanique des Emblems (Spatula)** : l'outil Spatula combiné avec un item crée un Emblem
qui ajoute un trait supplémentaire à une unité — permet des synergies impossibles autrement,
crée des builds "off-meta" qui surprennent
([pcgamesn.com items](https://www.pcgamesn.com/teamfight-tactics/tft-recipes-item-combinations)).

### 2.2 Le système d'augments

**Mécanique** : 3 moments fixes par partie (stages 2-1, 3-2, 4-2). À chaque moment, le
joueur choisit 1 augment parmi 3 proposés. L'augment est permanent (pas de perte possible).

**Raretés et distribution** (source : [tftodds.com/augments](https://tftodds.com/augments/augments-distribution), Set 16) :

| Round  | Silver | Gold | Prismatic |
|--------|--------|------|-----------|
| 2-1    | 28%    | 62%  | 10%       |
| 3-2    | 35%    | 45%  | 20%       |
| 4-2    | 6%     | 74%  | 20%       |

Note : ces % décrivent la distribution par slot individuel ; les 3 slots de l'offre ne sont
pas indépendants (des règles internes évitent 3 silver identiques au même niveau). Source :
[wiki augment TFT](https://wiki.leagueoflegends.com/en-us/TFT:Augment).

**Philosophie de design officielle** (Riot, [gizmos-gadgets-hextech-augments](https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/gizmos-gadgets-set-mechanic-overview-hextech-augments/)) :
- "Certains augments brisent des règles, d'autres en créent de nouvelles"
- Objectif : "réinventer votre partie à plusieurs reprises"
- Résultat design : le même champion jouable dans des builds radicalement différents selon
  les augments choisis — **identité de build post-augment**

**Psychologie** : les augments résolvent deux problèmes distincts :
1. **Choix différenciateur à information complète** : contrairement au shop (info partielle
   sur les drops), l'offre d'augments est entièrement visible — le joueur *voit* ses 3 options.
   La décision est de pur arbitrage synergique, pas de gestion d'incertitude. → Satisfaction
   de compétence (*competence*, Self-Determination Theory, Deci & Ryan 1985).
2. **Variance d'archétype entre parties** : même si le joueur joue la même composition,
   ses augments la rendent unique. Réduction de la fatigue de répétition (un problème que
   TFT adresse consciemment via les sets et les augments).

**Learnings de Riot** ([dev learnings gizmos-gadgets](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-gizmos-gadgets-learnings/)) :
- Puissance de palier inconsistante entre traits → frustration ("Bruiser Heart" ≠ "Innovator
  Heart" malgré même tier) → les augments ne fonctionnent que si la *hiérarchie de pouvoir
  perçue* est justifiable. Un augment "gold" qui perd à un "silver" = rupture de confiance.
- "Dead choices" (options clairement inférieures) = pire scénario — joueur frustré, pas
  stimulé. Un vrai choix difficile vaut mieux que 2 + 1 déchet.

### 2.3 Le carrousel (Shared Draft)

**Mécanique** : après le round 3 de chaque stage, tous les joueurs sont téléportés sur une
île centrale. 8 unités (+1 item each) circulent en boucle. Le joueur avec le **moins de HP
choisit en premier** ; ordre ascendant de HP. Le dernier choix va au joueur le plus fort.
([wiki carousel TFT](https://wiki.leagueoflegends.com/en-us/TFT:Carousel))

**Psychologie** : double fonction de design :
1. **Mécanisme anti-snowball** : le joueur qui perd le plus choisit le meilleur item.
   Redistribution des ressources structurelle sans "comeback mechanic" arbitraire.
2. **Tension mécanique** : rare moment de compétence "réflexive" dans un jeu de
   planification. Le timing de pick, la décision de prendre l'unité vs l'item, la lecture
   de ce que les adversaires veulent — tout dans 5–10 secondes.
   Source : [design pillars TFT](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-design-pillars-of-tft/)

**Note significative** : le carrousel a été **retiré en Set 17** et revient en Set 18
([tftactics.gg set-update](https://tftactics.gg/set-update/)) — preuve que même Riot
considère ce mécanisme remplaçable, pas fondamental.

### 2.4 Le système d'items

**Structure** : 9 composants de base (B.F. Sword, Recurve Bow, Needlessly Large Rod, Chain
Vest, Giant's Belt, Negatron Cloak, Sparring Gloves, Tear of the Goddess, Spatula). Deux
composants → 1 item complet. Un champion peut porter max 3 items. Items irréversibles (pas
de démontage).
([pcgamesn items](https://www.pcgamesn.com/teamfight-tactics/tft-recipes-item-combinations),
[bluestacks items](https://www.bluestacks.com/blog/game-guides/teamfight-tactics/tft-items-guide-en.html))

**Types additionnels** : Radiant (version améliorée des complets), Artifacts (effet rare
unique), Support (buff équipe).

**Psychologie** : les items créent un axe d'investissement *à long terme* dans une partie
par essence à court terme. Un carry bien équipé représente 15–20 minutes de décisions
d'allocation. Le risque de perdre le carry (unité morte en combat) amplifie l'enjeu
émotionnel de chaque round.

Le **goulot d'items** (finir les "composants orphelins" qui ne s'assemblent pas comme prévu)
est une source de frustration documentée — tension entre le build imaginé et le possible.

### 2.5 Les dégâts aux joueurs — teardown mathématique

**HP de départ** : 100 HP ([theglobalgaming.com](https://theglobalgaming.com/lol/how-does-damage-work-in-tft)).

**Formule** : Dégâts = Base Stage + Unités survivantes (1 par unité, indépendant de l'étoile)
([lolchess.gg/damage](https://lolchess.gg/guide/damage))

**Table des dommages de base par stage** :
```
Stage 3 : 5 dégâts base
Stage 4 : 8 dégâts base
Stage 5 : 10 dégâts base
Stage 6 : 12 dégâts base
Stage 7 : 17 dégâts base
```

**Implications** :
- Un stage 6 loss avec 9 unités survivantes = 12 + 9 = 21 HP perdus.
- Avec 100 HP de départ, un joueur peut perdre ~4–5 combats late-game avant d'être éliminé.
- La **scalabilité des dégâts par stage** signifie que "tenir" early (perdre des petits HP)
  pour mieux investir économiquement est une stratégie viable — les early losses coûtent
  peu relativement. Cette asymétrie est calculée pour encourager la diversité stratégique.

**Hyper Roll** : 20 HP de départ, dégâts flat par stage (pas d'unités). Complètement différent
— partie en 10–15 min, pression permanente.
([esports.gg hyper roll](https://esports.gg/news/teamfight-tactics/everything-you-need-to-know-about-tft-hyper-roll/))

### 2.6 Le scouting

**Mécanique** : cliquer sur le portrait d'un adversaire révèle son board + bench + gold.
Information disponible à tout moment pendant la phase de préparation.
([thegamer.com scouting](https://www.thegamer.com/teamfight-tactics-scout-system-explained-guide/))

**Psychologie** : crée une **information partielle structurée** — vous pouvez tout savoir
si vous investissez du temps et de l'attention. Contrainte d'attention (pas de temps illimité
en préparation) → décision de ce qu'il vaut la peine de savoir.

Impact compétitif : connaître les unités tier-4 que prennent les adversaires permet de savoir
si le pool est "free" (personne ne conteste) ou "contested" (éviter). Séparation documentée
entre joueurs high-elo (scouting systématique) et low-elo (focus personnel uniquement).
([boosteria scouting](https://boosteria.org/guides/tft-scouting-guide-read-lobby-pivot-without-panic))

---

## 3. Système ranked — teardown complet

### 3.1 Structure

9 tiers : Iron, Bronze, Silver, Gold, Platinum, Emerald, Diamond, Master, Grandmaster,
Challenger. ([esportstales.com rank distribution](https://www.esportstales.com/teamfight-tactics/seasonal-rank-system-and-player-distribution))

**Distribution de la playerbase (mai 2026, Set 17)** :
```
Iron       : 4.1%
Bronze     : 8.6%
Silver     : 19.0%
Gold       : 25.0%
Platinum   : 24.0%
Emerald    : 13.0%
Diamond    :  5.9%
Master     :  0.16%
Grandmaster:  0.13%
Challenger :  0.07%
```
~50% des joueurs en Gold/Platinum — le "milieu de la courbe de compétence perçue".

### 3.2 LP et MMR

**Gains/pertes approximatifs** (source : [immortalboost ranked system](https://immortalboost.com/blog/teamfight-tactics/ranked-system-explained/)) :
```
1ère place : +40 à +56 LP
2ème place : +20 à +30 LP
3ème place : +5  à +15 LP
4ème place : +1  à +10 LP (légèrement positif ou nul)
5ème place : -10 à -18 LP
6ème place : -20 à -28 LP
7ème place : -30 à -40 LP
8ème place : -40 à -50 LP
```

**Top-4 = gain, bottom-4 = perte** — la frontière psychologique est 4/8, pas 1/2. Cela
redéfinit "gagner" : finir 4ème n'est pas une défaite, c'est un résultat neutre positif.
Réduit la frustration d'élimination précoce (la plupart des joueurs "visent le top-4").

**MMR caché** : le MMR est le vrai levier. Si MMR > rang visible → gains amplifiés, pertes
réduites (calibration vers le haut). Inverse si surranké.

**Promotions** : pas de séries. 100 LP = promotion immédiate à la division suivante.
Pas de rétrogradation de tier (Iron→Master) — une fois Gold, jamais Silver.

**Decay haute élite** :
```
Master       : -50 LP par tick d'inactivité
Grandmaster  : -150 LP
Challenger   : -250 LP
```
Challenger/Grandmaster = population-cappé (cutoffs recalculés toutes les 24h).

**Reset de set** : soft reset. Tous redémergent Iron II → Silver IV selon rang précédent.
5 matchs provisoires sans perte de LP. ([boosteria.org LP/MMR](https://boosteria.org/guides/tft-lp-mmr-explained-tft-ranked-really-works))

### 3.3 Cadence des sets

Sets de ~4 mois chacun (8 patches par set). Set 17 (Space Gods) : fin prévue 29 juillet 2026,
Set 18 en simultané. Chaque set = nouveau roster complet, nouvelles synergies, nouveaux augments.
([seasontimer.live](https://seasontimer.live/tft/), [1v9.gg seasons](https://1v9.gg/blog/teamfight-tactics-tft-all-seasons-start-end-dates))

---

## 4. Psychologie — pourquoi ça hook (mécanismes sourçables)

### 4.1 Variable ratio reinforcement (VRR)

Le shop rolling est structurellement identique à un slot machine sous agence apparente :
dépenser 2g = tirage d'une distribution probabiliste dont le résultat est imprévisible mais
dont la distribution est *connaissable* (les cotes sont publiques). C'est un **VRR avec
agence calculable** — le joueur *peut* calculer ses odds, mais cette information ne réduit
pas l'urgence du prochain tirage.

Source théorique : le VRR est le schedule de renforcement le plus résistant à l'extinction
(Skinner 1938, validé par des décennies de recherche sur les jeux de hasard). La résistance à
l'extinction explique pourquoi les joueurs continuent à roller "juste encore un peu".
([practicalpie.com VRR](https://practicalpie.com/variable-ratio-reinforcement/))

**La différence cruciale avec le pur hasard** : TFT ajoute de la **compétence perçue** (lire
le pool, savoir quand roller, connaître les odds). Quand on hit l'unité voulue, on attribue
le succès à sa compétence de timing, pas au hasard — même si c'est statistiquement équivalent.
Cela augmente la satisfaction (Self-Determination Theory : besoin de compétence satisfait)
et blâme le malchance pour les échecs (locus de contrôle externe préservé).

### 4.2 Near-miss sous agence

Lorsqu'un joueur a 8 exemplaires sur 9 nécessaires pour un 3-star, chaque reroll est un
near-miss potentiel. Neuroscientiellement, les near-miss activent les mêmes circuits de
récompense que les victoires réelles (Sescousse et al., 2010, [PMC2658737](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2658737/)).

Dans TFT, le near-miss est **sous agence** (le joueur peut dépenser plus de gold pour
augmenter ses chances) — contrairement au pur hasard, il y a une *action disponible* qui
donne l'impression que le succès est contrôlable. Cela amplifie le désir de continuer
([psychologyofgames.com](https://www.psychologyofgames.com/2016/09/the-near-miss-effect-and-game-rewards/)).

### 4.3 Progress Principle (traits comme objectifs intermédiaires)

Les compteurs de traits (3/6 Bruisers, 2/4 Assassins) créent des **progrès visibles et lisibles
en permanence**. Chaque achat est un micro-progrès visible. La recherche d'Amabile & Kramer
(2011, *Harvard Business Review*) montre que le sentiment de progression est le moteur
motivationnel #1 en contexte de tâche complexe — plus que les récompenses extrinsèques.

### 4.4 Information partielle + lecture adverse = compétence émergente

Le scouting crée une asymétrie d'information que la compétence réduit. Le joueur expert
sait que l'unité tier-4 est free parce qu'il a vérifié les 7 autres boards. Ce savoir
génère une **compétence légitime** (pas du RNG brut) et crée le sentiment que le résultat
est mérité.

Conséquence psychologique : quand ça marche, c'est la compétence ; quand ça échoue, c'est
le RNG adversaire. Attribution asymétrique qui préserve l'estime de soi.

### 4.5 Dopamine de "payoff visuel"

La description du "perfect carry" de la Medium analysis ([ZiberBugs](https://medium.com/@ZiberBugs/game-design-analysis-teamfight-tactics-bc6eb5aafeff)) :
"construire ce champion carry parfait — top rank, triple-item, augmenté, synergisé — et
regarder il démolir les formations ennemies". C'est le **moment de payoff spectaculaire**
après 30 minutes de planification invisible. Le combat auto permet ce moment : le joueur
*observe* son oeuvre fonctionner (ou non) sans avoir à la contrôler.

La psychologie de ce moment est proche du "flow" (Csikszentmihalyi, 1990) : difficulté
adaptée à la compétence, feedback immédiat, objectif clair. Sauf que TFT le compresse en
spectateur — vous regardez, pas vous agissez. Satisfaction plus proche de l'observation
d'un jardin bien planté que du jeu actif.

### 4.6 FOMO et reset de set (rétention à long terme)

Chaque nouveau set efface le progrès méta-connaissance tout en préservant le rang (soft
reset). Le joueur expert doit ré-apprendre les synergies, mais part d'un avantage de rang.
Le joueur casual voit un nouveau jeu — novelty seeking satisfait.

Le reset de rang (tout le monde repart quasi de zéro) crée une fenêtre où **même un joueur
low-elo peut "grimper vite" pendant les premières semaines** avant que le lobby se re-calibre.
FOMO de la fenêtre d'opportunité du reset : puissant moteur de re-engagement.
([esportstales.com seasons](https://www.esportstales.com/teamfight-tactics/seasonal-rank-system-and-player-distribution))

### 4.7 Tension loss-streak vs win-streak

La critique de la Medium analysis : le système de bonus de loss-streak crée une **incitation
perverse à perdre** ([ZiberBugs](https://medium.com/@ZiberBugs/game-design-analysis-teamfight-tactics-bc6eb5aafeff)).
Objectivement juste — un joueur qui loss-streak intentionnellement reçoit +3g/round après
6 défaites. Mais la pratique experte ("econ greedy") consiste à sacrifier les early rounds
pour investir en économie, et non à vouloir perdre pour les gold. La tension est *fonctionnelle*,
pas perverse : elle justifie de ne pas over-investir early au détriment de l'éco.

---

## 5. Structure compétitive et ranked — pourquoi ça donne envie de grimper

### 5.1 Le top-4 comme objectif accessible

TFT a résolu le problème du "most games end in 7/8 defeats" en repositionnant la victoire
comme "finir dans la moitié haute". 4/8 = succès. Cela maintient la motivation même pour
les joueurs qui ne visent pas la 1ère place. Chaque partie est potentiellement "positive"
pour 50% des joueurs.

### 5.2 Sans demotion inter-tiers

"Une fois Gold, jamais Silver" ([wecoach.gg ranked](https://wecoach.gg/blog/article/tft-ranks-distribution-and-how-the-ranking-system-works)).
Cela réduit la **peur de la perte** (loss aversion, Kahneman & Tversky 1979) qui est le
frein #1 à l'engagement ranked. Les joueurs peuvent "expérimenter" une composition sans
risquer de rétrogradation catastrophique. La progression devient plus linéaire perceptuellement.

### 5.3 5 matchs provisoires = filet d'onboarding ranked

Les 5 premiers matchs du set = sans perte de LP. Le nouveau set est une invitation explicite
à "try" sans punition précoce. Abaisse la barrière d'entrée au ranked sans diluer la
signification du rang une fois les matchs provisoires passés.

### 5.4 Le set rotation = "scarcité temporelle"

Chaque set a une fin annoncée. Le rang obtenu pendant ce set aura une valeur symbolique
permanente (capsule de récompense, badge cosmétique). Horizon temporel limité = FOMO
légitime = urgence de jouer *maintenant*. Compare au modèle de Marvel Snap (saisons mensuelles,
récompenses exclusives par saison).

---

## 6. Postmortems — ce que les échecs enseignent

### 6.1 Dota Underlords (2019–2021)

**Déclin documenté** : pic à 202 000 joueurs concurrent au lancement (juin 2019), puis
chute de 75% en 3 mois ([invenglobal.com Underlords](https://www.invenglobal.com/articles/8925/dota-underlords-is-rapidly-losing-players-if-the-game-wants-to-succeed-it-must-solve-its-identity-crisis)).

**Causes identifiées** :
1. **Identity crisis PC/mobile** : voulait cibler les 10-minute sessions mobile, alienait
   la base PC (parties trop longues sur mobile, UI illisible sur petit écran).
2. **Absence d'identité propre** : Underlords commença comme clone de Dota Auto Chess sans
   réel différenciateur. La mécanique des "Underlords" (héros uniques surpuissants, une par
   partie) arriva trop tard et fut jugée "horrible".
3. **Patches destructeurs** : des changements radicaux de drop rates implémentés sur la
   base de posts Reddit aléatoires déstabilisèrent le gameplay ([vieesports.com](https://vieesports.com/what-even-happened-to-dota-underlords/)).
4. **Competition brand asymétrique** : Valve vs Riot. TFT bénéficiait de la base LoL
   (33M joueurs mensuels en septembre 2019 selon Wikipedia) et du streaming Twitch LoL.

**Leçon** : un autobattler sans **différenciateur clair + identité de thème forte** est
une commodité. Le thème n'est pas cosmétique — c'est ce qui justifie l'existence du jeu
face aux concurrents ([gd-research-result.md §2.6](../../research/gd-research-result.md)).

### 6.2 Storybook Brawl (2020–2023)

**Cause primaire** : acquisition par FTX en mars 2022 pour intégration NFT → backlash
immédiat de la communauté (reviews Steam passent de "Very Positive" à "Overwhelmingly
Negative") → faillite FTX → serveurs fermés mai 2023.
([Wikipedia Storybook Brawl](https://en.wikipedia.org/wiki/Storybook_Brawl))

**Cause secondaire** : le jeu n'avait jamais quitté l'Early Access — pas de "version finale"
consensuelle même avant la crise FTX.

**Leçon** : trahir la confiance de la playerbase sur le modèle économique = rupture
immédiate et irréparable. La communauté d'un autobattler niche est petite et vocale.

---

## 7. Verdicts de transférabilité vers *The Pit*

### Principe de lecture

Un mécanisme TFT est **transférable** si :
- Son mécanisme psychologique/mathématique *sous-jacent* survit à nos contraintes :
  **async pur** (zéro lobby partagé en direct), **run court** (10V avant ~5 défaites ≈
  15–25 combats max), **sim déterministe seedée**, **grimdark procédural**.
- Il ne viole pas les **10 décisions définitives** (00-state.md §1).

Je démonte ici les analogies paresseuses l'une après l'autre.

---

### V1. Odds-gating par niveau de boutique

**TFT** : 5 slots boutique toujours, monter de niveau change la *distribution* (non le
nombre de slots). Tease de rang N+1 à 2% dès le niveau N. Pool partagé entre 8 joueurs.

**Le mécanisme psychologique sous-jacent** : révélation progressive de contenu selon
l'investissement/progression ; chaque niveau-boutique est un échelon de découverte. La
rareté perçue des hauts tiers est fonctionnelle (ils sont *vraiment* rares aux bas niveaux).

**Survie aux contraintes de The Pit ?**
- Async/pas de lobby : le pool n'est pas partagé en direct → **pas de scarcité dynamique
  inter-joueurs en temps réel**. L'axe de contestation ("ce champion est pris par 3 autres
  joueurs") disparaît entièrement. C'est une perte majeure.
- Run court (10V) : nos cotes actuelles (00-state.md §4.3) sont inspirées directement de
  TFT. La table de cotes est déjà implémentée et validée design.
- Déterminisme : le tirage boutique est seedé dans `state.lua` → compatible.

**Verdict : DÉJÀ IMPLÉMENTÉ et valide.** Les cotes TFT-style sont notre modèle actuel.
La perte de scarcité dynamique inter-joueurs est **acceptable** en async — elle est remplacée
par une rareté *absolue* (pool limité par niveau de boutique). Ce n'est pas la même
expérience, mais c'est fonctionnel.

**Adaptation à faire** : dans TFT, la scarcité dynamique (pool épuisé) est visible via le
scouting. En The Pit async, cette info n'existe pas. Compenser éventuellement par une
rareté plus forte des haut-rangs dans nos placeholders (nos cotes tier-5 actuelles à 10%
au niveau max sont déjà restrictives).

**Risque d'analogie paresseuse** : "copier les cotes TFT exactement" sans tenir compte
que TFT a un pool *dynamique* (8 joueurs vident les copies) alors que nous avons un pool
*statique* par run. Nos cotes devraient peut-être être plus agressives côté rareté tardive
puisqu'on ne bénéficie pas de la pression de contestation qui compresse les hit-rates.

---

### V2. XP passive + achetable (odds-gating par investissement)

**TFT** : 2 XP/round passif + 4g = 4 XP actif. Table exponentielle (2→6→10→20→36→48→72→84→100
XP par niveau). Niveau max 10 ou 11 selon le set.

**Le mécanisme psychologique** : *arbitrage avec trade-off visible*. Dépenser en XP =
renoncer à roller/acheter des unités. La décision crée un **moment de tension stratégique
réel** à chaque round. C'est un choix de "chemin" (niveau + rares vs niveau bas + copies
stacked).

**Survie aux contraintes de The Pit ?**
- Run court (10–25 combats) : dans TFT, la partie dure ~25 rounds. Avec 2 XP/round passif,
  on accumule ~50 XP passifs → niveau 6 environ. Notre run cible ~15–25 combats avec des
  seuils XP différents (nos seuils : T1→T2=2, T2→T3=5, T3→T4=8, T4→T5=12, cumul=27).
  À 1 XP passif/round sur 20 rounds = 20 XP passifs → tier 4 (~niveau 4 de boutique).
  Intention validée (progression-economy-prd.md §3.3).
- Déterminisme : XP passive est déterministe (même seed = même progression passif).

**Verdict : DÉJÀ IMPLÉMENTÉ (placeholders). Le mécanisme tient.** Notre calibrage est
plus comprimé (seuils plus bas, XP/round plus petite) parce que notre run est plus court.

**Attention au ratio actuel** : notre `BUY_XP_COST = 4` pour `BUY_XP_AMOUNT = 4` (ratio
1:1) est identique à TFT. Mais notre `GOLD_PER_ROUND = 10` est fixe (pas d'intérêt, pas
de banque — modèle SAP). Dans TFT, le joueur peut accumuler 50g+ et gagner +5g/round en
intérêt. Nous n'avons pas cela. Donc 4g en XP sur 10g disponibles = **40% du budget
disponible** contre une fraction pour TFT. Le ratio est plus contraignant chez nous —
surveiller via `tools/sim.lua` pour éviter le "XP ou rien" forcé.

---

### V3. Intérêt et banque d'or

**TFT** : intérêt +1g par tranche de 10g stockée, plafonné à +5g/round. Encourage à ne pas
tout dépenser — décision de "saving vs rolling".

**Le mécanisme psychologique** : crée un **axe stratégique entre impatience et planification**
(Temporal Discounting en économie comportementale). Le joueur patient est récompensé.
Génère des "eco builds" viables (perdre early pour dominer late).

**Survie aux contraintes de The Pit ?**
**NON — pour des raisons structurelles documentées.**

Notre modèle est SAP-style : `GOLD_PER_ROUND = 10`, non conservé entre rounds (état FRAIS).
C'est une décision actée (progression-economy-prd.md §2, non-objectifs) et la décision #9
(00-state.md §1) rejette la boutique payée HS. L'intérêt TFT et la boutique HS font partie
du *même* cluster d'écueils : ils créent une spirale de la mort pour les joueurs qui ne
connaissent pas le méta-stratégique optimal.

**Mécanisme psychologique de l'intérêt survivrait-il au run court ?**
Mathématiquement : avec 10V comme cible et ~20 combats total, une stratégie "econ greedy"
qui sacrifie 5 combats early pour banquer doit récupérer les avantages perdus sur les 15
restants. Le window est trop court pour l'intérêt d'avoir du sens. Dans TFT (25+ rounds),
la fenêtre de "récupération" post-econ est suffisante.

**Verdict : NON TRANSFÉRABLE. Garder le modèle SAP (or frais/round).** Ce n'est pas une
faiblesse — c'est une simplification intentionnelle qui élimine la spirale de la mort et
rend l'équilibrage plus prévisible via `tools/sim.lua`.

**Ce qui peut remplacer l'intérêt** : notre système de *streaks* (+1/+2/+3 gold/round) joue
un rôle analogue — récompense la consistance sans créer de banque optimale. Plus simple,
moins punissant pour les débutants.

---

### V4. Traits / synergies de type

**TFT** : chaque champion a 1–3 traits. Aligner 2/4/6/8 d'un même trait active un palier
de bonus. Compteur visible en permanence.

**Le mécanisme psychologique** : **objectifs intermédiaires lisibles + Progress Principle**.
Le compteur de trait est un progrès visible et mesurable. Near-miss de palier = motivation.

**Survie aux contraintes de The Pit ?**
- Async : les traits fonctionnent par-build, pas par interaction en direct → pas de
  contrainte async. Chaque run a ses propres build-objectives.
- Run court : les paliers de trait doivent être atteignables dans ~15–25 combats. Si un
  palier demande 6 unités du même type et que le shop prend 10 rounds pour les fournir,
  c'est trop serré.
- Déterminisme : les synergies de type seraient des bonus de build passifs → déterministes.

**Verdict : TRANSFÉRABLE et même ATTENDU** (00-state.md §7 : "synergies par TYPE = encore
un TODO majeur"). Notre adjacence positionnelle (le voisin buffe) est déjà en place. Les
synergies par **type** sont le chainon manquant.

**Comment adapter précisément** :
- Plutôt que des paliers rigides (2/4/6), préférer des **bonus graduels par type** alignés
  sur nos 9 slots max (pas 28 hexagones). Exemples : "2 Burn → +20% dégâts de brûlure à
  toute l'équipe ; 4 Burn → les brûlures se propagent au voisin adjacent à la mort".
- Ne pas dépasser 3 paliers/type (notre roster cible 4–5 types distincts).
- Le compteur de type = **UI sur le plateau** surlignant les voisins du même type (déjà
  mentionné dans gd-research-result.md §synergies).
- Attention : nos 83 unités sont réparties sur 4 familles DoT + tank/shield + bruiser. Les
  paliers de type doivent rester **atteignables à 3 slots** (notre démarrage) sans nécessiter
  le plateau full 9.

**Risque d'analogie paresseuse** : "copy TFT trait system" = 2/4/6 paliers supposant
8–28 slots. Nous avons 9 slots max. Nos paliers devront être calibrés pour 2/4 (et
éventuellement 6 pour les fins de partie). Ne jamais viser des synergies qui exigent
plus de 6 sur 9 slots d'un même type — trop contraignant sur le positionnement.

---

### V5. Augments

**TFT** : 3 moments de choix 1-parmi-3 en cours de partie (stages 2-1, 3-2, 4-2).
Permanents. 3 raretés (silver/gold/prismatic). Modifient les règles ou amplifient un build.

**Le mécanisme psychologique** :
1. Choix *à information complète* (voir les 3 options) → satisfaction de compétence pure.
2. Variance d'archétype entre parties → anti-lassitude.
3. Point de pivot narratif : "ma partie change maintenant" — sentiment d'histoire.

**Survie aux contraintes de The Pit ?**
- Async : les augments TFT n'exigent pas de temps réel → compatible.
- Run court : 3 augments sur ~20 combats = 1 choix tous les ~7 combats. Notre modèle de
  reliques (1-parmi-3 tous les 3 combats = potentiellement ~5–7 reliques/run) est *plus
  dense* en choix.
- Déterminisme : le tirage de reliques est seedé dans `state.lua` → compatible.

**Verdict : NOTRE SYSTÈME DE RELIQUES EST L'ÉQUIVALENT ET IL EST DÉJÀ IMPLÉMENTÉ.**
Nos reliques (vague 1-4, 21 entrées, taxonomie A-F) correspondent exactement à ce
mécanisme. La différence : nos reliques sont **plus fréquentes** (1 tous les 3 combats
vs 3 par partie en TFT), **lisibles** (pas d'identification à déduire — décision 2026-06,
00-state.md §1 décision #7), et **gatées par avancement** (tier selon wins).

**Ce que TFT enseigne sur nos reliques** :
- Éviter les "dead choices" (options clairement inférieures dans le lot de 3). Un lot où
  2 reliques sont clairement dominantes selon le build courant du joueur = bonne offre.
  Un lot où 1 seule est pertinente = choix factice. → Vérifier nos relics-design.md §3
  pour l'algorithme de tirage (diversité forcée par catégorie ?).
- La balance *intra-tier* est critique : deux reliques "mid" ne doivent pas avoir des
  puissances perçues trop disparates. Notre diagnostic (the-pit-relics, mémoire) note des
  "placeholders forts" — c'est exactement le problème de "Heart Augment" identifié par Riot.

**Risque d'analogie paresseuse** : "ajouter des augments TFT" en plus de nos reliques.
Mauvaise idée — multiplication de systèmes similaires, confusion UI. Nos reliques SONT
nos augments. Augmenter la densité de reliques (déjà plus élevée que TFT) ou améliorer
leur impact build-defining est la bonne direction.

---

### V6. Carrousel (Shared Draft)

**TFT** : après chaque stage, redistribution de ressources aux joueurs les plus faibles en HP.
Mécanisme anti-snowball ET de tension mécanique momentanée.

**Le mécanisme psychologique** : perceived fairness (les "losers" récupèrent quelque chose)
+ micro-moment de skill expression (choisir vite, lire les adversaires).

**Survie aux contraintes de The Pit ?**
**NON TRANSFÉRABLE — contrainte structurelle dure.**

Le carrousel exige **8 joueurs simultanés qui interagissent en direct** sur le même lobby.
C'est le pilier #1 violé immédiatement : async par snapshots, zéro PvP temps réel.

**Le mécanisme sous-jacent (anti-snowball) est-il transférable autrement ?**
OUI — et nous avons déjà l'équivalent fonctionnel :
- **Filet SAP** : +1 vie au round 3 si perte précoce (state.lua) — anti-tilt direct.
- **Offers de slot en grants timés** (rounds 2-7, pas liés à l'or) — tout le monde débute
  avec 3 slots et débloquer jusqu'à 9 est garanti par progression, pas par performance.
- **Loss-streak bonus** (+1/+2/+3g selon défaites consécutives) — or supplémentaire pour
  les joueurs qui perdent, mécanisme analogue à la priorité de carrousel.

**Adaptation créative possible** : un "Pit Drop" — tous les N combats, le joueur reçoit
une offre spéciale (unité à coût réduit, relique bonus) dont la qualité est **inversement
proportionnelle à ses victoires récentes**. Anti-snowball intégré sans temps réel. À
évaluer vs complexité ajoutée.

---

### V7. Items TFT (composants combinés)

**TFT** : 9 composants de base → 45+ items complets (combinaisons de 2). Champion porte
max 3 items. Items irréversibles. Source de profondeur massive et de frustration (composants
orphelins).

**Le mécanisme psychologique** : artisanat / crafting (gathering + construction dans la
taxonomie de Bartle). L'investissement croissant dans un item crée du sunk cost (le champion
bien équipé = ressource émotionnellement chargée).

**Survie aux contraintes de The Pit ?**
**NON TRANSFÉRABLE en tant que système d'items séparé.**

Notre architecture n'inclut pas de système d'items dédié, et l'en ajouter serait une
refonte majeure hors scope (violation du garde-fou "run court + simplicité → profondeur
émergente"). Notre équivalent *fonctionnel* est le système de **doublons/niveaux** (3
copies → niveau+1, multiplicateur 1.0/1.8/3.0) qui crée le même investissement cumulatif
dans une unité, sans la complexité d'un inventaire.

**Ce que TFT enseigne sur nos doublons** : le "carry bien équipé" de TFT est notre
"unité niveau 3". Le soin apporté à protéger ce carry (placement, taunt, sigil) est
l'équivalent de la décision d'itemisation TFT. Psychologiquement équivalent — enjeu
émotionnel sur une ressource construite au fil du temps.

**Risque d'analogie paresseuse** : "ajouter des items comme TFT pour de la profondeur".
Non — notre profondeur vient de la topologie du plateau (sigils) + effets DoT + reliques.
Ajouter un layer d'items serait une dette de complexité massive avec peu de payoff
incremental étant donné ce que le système de doublons offre déjà.

---

### V8. Système ranked / LP

**TFT** : LP visible, MMR caché, top-4 = gain, bottom-4 = perte. Pas de demotion inter-tier.
5 matchs provisoires. Reset de set. Distribution : 50% des joueurs en Gold/Platinum.

**Le mécanisme psychologique** : sentiment de progression mesurable + protection contre
la catastrophe (pas de rétrogradation de tier). Horizon temporel clair (fin de set).

**Survie aux contraintes de The Pit ?**
**PARTIELLEMENT TRANSFÉRABLE — avec adaptations importantes.**

Notre modèle async est fondamentalement différent : pas de lobby partagé en direct, pas
de "placement 1–8 par partie". Un run se termine par ascension (10V) ou chute (5 défaites).
Le "résultat" à ranker n'est pas un placement mais une *performance de run*.

**Métriques de run rankables** :
- **Victoires à l'ascension** : 10V = ascension réussie → +LP. Plus vite atteint → bonus.
- **Profondeur avant chute** : 9V-4D vs 3V-5D. Le score du run (wave + kills + damage dealt)
  peut devenir le "placement TFT" de notre système.
- **Matchmaking par tier** : `snapstore.lua` filtre déjà les adversaires par `tier ≤
  demandé` — fondation du matchmaking async.

**Adaptation à concevoir** :
- Un run = une "partie" unitaire. Le LP gagné par run dépend du résultat (ascension = gain
  fort ; chute précoce = perte ; chute tardive = perte modérée).
- Pas de "bottom-4 = certain loss" — mais "chute à 3V-5D" = résultat plus pénalisant que
  "chute à 8V-5D". Le nombre de victoires avant la chute module le LP perdu.
- L'asymétrie top-4/bottom-4 de TFT se traduit chez nous : **ascension (10V) = top-4** ;
  **chute précoce (< 5V) = bottom-4** ; résultats intermédiaires = neutre ou légère perte.

**Sans demotion inter-tier** : adopter le même principe — une fois Diamond, jamais Platinum.
Cela réduit la peur de la perte et encourage l'expérimentation de builds.

**Reset de set** : nous n'avons pas de "sets" mais nous pouvons avoir des **saisons de
plusieurs semaines**. Un soft reset de MMR en début de saison recrée la "fenêtre
d'opportunité" qui motive le re-engagement.

**Ce que TFT valide** : notre structure compétitive est une zone vierge (00-state.md §7).
Le modèle LP/MMR de TFT est la référence la plus adaptée à notre architecture async —
non pas en copiant la mécanique 1-8 placement, mais en gardant le **principe de progression
non-punitive** (pas de demotion inter-tier) et **l'horizon temporel limité** (saisons).

---

### V9. Hyper Roll (mode alternatif)

**TFT Hyper Roll** : 20 HP, pas d'intérêt, niveau auto par stage (tous les joueurs =
même niveau), 10–15 minutes. Ranked séparé (5 tiers : Grey→Hyper).
([wiki.leagueoflegends.com Hyper Roll](https://wiki.leagueoflegends.com/en-us/TFT:Hyper_Roll))

**Le mécanisme psychologique** : même boucle de TFT mais en "fast forward". Accessibilité
pour les sessions courtes. Ranked séparé = ladder distinct, double motivation de grind.

**Survie aux contraintes de The Pit ?**
**NON PERTINENT — notre run est déjà "Hyper Roll".**

Notre run de ~15–25 combats (10V avant ~5D) est structurellement comparable à une partie
Hyper Roll en durée. Nous n'avons pas besoin d'un mode alternatif accéléré — notre mode
standard est déjà "rapide" par design.

**Ce que Hyper Roll enseigne** : l'existence d'un mode 15-min prouve qu'il existe une
audience pour les sessions courtes dans le genre autobattler. *The Pit* cible nativement
cette audience. Avantage comparatif structurel.

---

### V10. Scouting

**TFT** : lecture des boards adverses pour identifier les unités "free" vs "contested".

**Non transférable — contrainte structurelle.**

Le scouting TFT exige des adversaires *en direct* dont le board évolue en temps réel.
En async par snapshots, les adversaires sont figés au moment de la capture. Il n'y a pas
de lobby partagé où "3 autres joueurs ont déjà pris 6 exemplaires de Jarvan IV".

**Ce qui survit** : la logique de *décision sous information partielle*. Nous ne savons
pas quels adversaires seront servis (leurs snapshots sont tirés au sort par `snapstore:serve`).
La décision de build se fait sans connaissance des builds ennemis → information partielle
différente de TFT (pas de scarcité dynamique, mais surprise tactique à chaque combat).

**Adaptation créative** : un **"Intel pré-combat"** (avant le combat, révéler la composition
ennemie 5 secondes) créerait un mini-moment de lecture adverse compatible avec l'async.
Coût de développement faible (snapshot déjà sérialisé), valeur stratégique réelle (permettre
un dernier ajustement de positionnement).

---

## 8. Tableau synthèse des verdicts

| Mécanisme TFT | Verdict | Adapter / Remplacer par |
|---|---|---|
| Odds-gating boutique | **DÉJÀ FAIT** | Nos cotes actuelles (00-state §4.3) |
| XP passive+achetable | **DÉJÀ FAIT** | Notre système XP (progression-economy-prd §3) |
| Intérêt/banque d'or | **NON** (run trop court, spirale) | Streaks + or frais/round (modèle SAP) |
| Traits/synergies de type | **OUI** (TODO majeur) | Synergies par type, paliers 2/4 sur 9 slots |
| Augments | **DÉJÀ FAIT** (nos reliques) | Densifier l'impact build-defining des reliques |
| Carrousel (anti-snowball) | **NON** (exige live) | Filet SAP + loss-streak bonus + "Pit Drop" conceptuel |
| Items combinables | **NON** (complexité excessive) | Notre système de doublons/niveaux |
| Ranked LP/MMR | **OUI (adapter)** | LP par résultat de run, pas placement 1-8 |
| Hyper Roll mode | **NON PERTINENT** | Notre run standard EST le Hyper Roll |
| Scouting | **NON** (exige live) | "Intel pré-combat" (reveal snapshot) en option |
| Reset de set/saisons | **OUI** | Saisons trimestrielles + soft reset MMR |
| Top-4 win condition | **OUI (adapter)** | Run ascendant (10V) = "top-4" ; chute tardive = neutre |
| No-demotion inter-tier | **OUI** | Adopter directement dans notre ranked |

---

## 9. Priorités pour *The Pit* (dérivées de cette analyse)

Ces priorités découlent *uniquement* de ce qui n'est pas encore implémenté et dont la
transférabilité est validée ci-dessus. Elles ne redéfinissent pas les décisions actées.

**P1 (manque critique) : Synergies par TYPE**
- Psychologie TFT : Progress Principle, near-miss de palier, objectifs intermédiaires.
- Notre gap : adjacence positionnelle existe (voisin buffe) ; synergies par type = TODO.
- Ce qu'elles apportent : axe de "build direction" lisible pendant le shop (pas seulement
  "quel effect est bon" mais "est-ce que j'accumule vers un palier type ?").
- Format recommandé : 2 paliers par type (2 unités / 4 unités), bonus graduel (pas saut
  brutal). Compteur visible sur le plateau.

**P2 (manque critique) : Structure compétitive / Ranked**
- Psychologie TFT : progression mesurable + protection perte + horizon temporel.
- Notre gap : rien de codé sur la structure ranked (00-state §7 : "zone vierge #1").
- Ce qu'elles apportent : moteur de "réenchaîner pour grimper" (BRIEF.md).
- Format recommandé : LP par résultat de run (ascension = +LP fort ; chute précoce = -LP ;
  chute tardive = -LP modéré) ; pas de demotion inter-tier ; saisons trimestrielles soft-reset.

**P3 (amélioration) : Équilibrage reliques (dead choices)**
- Leçon TFT : "Heart Augment" de puissance inégale malgré même tier = rupture de confiance.
- Notre situation : reliques marquées [PH], diagnostic "placeholders forts" (the-pit-relics).
- Ce qu'apporte l'équilibre : chaque offre 1-parmi-3 doit avoir **au moins 2 options
  légitimement attractives** selon le build courant. Une option "évidente" + deux déchet =
  choix factice, frustration.
- Outil : `tools/sim.lua` → lift de co-occurrence relique/victoire → identifier les reliques
  surpuissantes ET les reliques sous-choisies.

**P4 (amélioration UI) : Intel pré-combat**
- Analogie scouting TFT adaptée à l'async.
- Cout faible (snapshot déjà sérialisé), valeur stratégique réelle.
- Format : 3–5 secondes de reveal du snapshot ennemi avant le combat → fenêtre de repositionnement.

---

## 10. Postmortem de la logique TFT — ce qui ne tient pas chez nous

**Analogie paresseuse #1 : "TFT a de l'intérêt/banque, ajoutons-le"**
Réfutée en §V3. L'intérêt TFT est calibré pour des parties de 25+ rounds. Notre run de
~20 combats rend la fenêtre de récupération insuffisante. L'intérêt créerait une spirale
punitive pour les débutants — exactement l'écueil documenté dans progression-economy-prd §3.

**Analogie paresseuse #2 : "TFT a 28 hexagones et du positionnement riche, faisons une
grille plus grande"**
Réfutée par décision §4 (00-state.md). Notre plateau 3×3 + sigils est le différenciateur.
28 hexagones → coût de positionnement cognitif × 3 → contraire à "simplicité de gestion
→ profondeur émergente". TFT lui-même n'est pas "simple à gérer" — sa profondeur vient
d'un système d'items + positionnement + traits complexe. Ce n'est pas notre cible.

**Analogie paresseuse #3 : "TFT a des carrousels, ajoutons un mécanisme de partage entre
runs"**
Réfutée en §V6. Le carrousel exige 8 joueurs en direct. Notre équivalent async (loss-streak
bonus + filet SAP) remplit la même fonction psychologique sans briser le pilier async.

**Analogie paresseuse #4 : "TFT a un pool partagé, gérons la scarcité inter-joueurs"**
Non transférable structurellement (§V1). La scarcité dynamique inter-joueurs de TFT est la
conséquence directe des lobbies partagés en temps réel. En async, le pool n'est pas partagé
entre adversaires concurrents dans la même session. Notre rareté vient de la distribution
de cotes par niveau de boutique, pas de la compétition inter-joueurs.

---

## Sources citées

- [esportstales.com — Pool size & shop odds TFT Set 17](https://www.esportstales.com/teamfight-tactics/champion-pool-size-and-draw-chances)
- [tft.ninja — XP table par niveau (leveling)](https://tft.ninja/guides/game-mechanics/leveling)
- [op.gg — Gold income & XP TFT Season 17](https://op.gg/tft/game-guide/gold-xp)
- [lolchess.gg — Player damage formula](https://lolchess.gg/guide/damage)
- [wiki.leagueoflegends.com — TFT:Gold (gold income rules)](https://wiki.leagueoflegends.com/en-us/TFT:Gold)
- [wiki.leagueoflegends.com — TFT:Augment (augment mechanics)](https://wiki.leagueoflegends.com/en-us/TFT:Augment)
- [wiki.leagueoflegends.com — TFT:Carousel](https://wiki.leagueoflegends.com/en-us/TFT:Carousel)
- [wiki.leagueoflegends.com — TFT:Hyper Roll](https://wiki.leagueoflegends.com/en-us/TFT:Hyper_Roll)
- [tftodds.com — Augment distribution table Set 16](https://tftodds.com/augments/augments-distribution)
- [teamfighttactics.leagueoflegends.com — Design Pillars of TFT (officiel Riot)](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-design-pillars-of-tft/)
- [teamfighttactics.leagueoflegends.com — Hextech Augments overview (officiel Riot)](https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/gizmos-gadgets-set-mechanic-overview-hextech-augments/)
- [teamfighttactics.leagueoflegends.com — Gizmos & Gadgets Learnings (officiel Riot)](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-gizmos-gadgets-learnings/)
- [esportstales.com — Rank distribution TFT May 2026](https://www.esportstales.com/teamfight-tactics/seasonal-rank-system-and-player-distribution)
- [immortalboost.com — Ranked system TFT 2026 (LP gains/losses)](https://immortalboost.com/blog/teamfight-tactics/ranked-system-explained/)
- [boosteria.org — LP/MMR TFT explained](https://boosteria.org/guides/tft-lp-mmr-explained-tft-ranked-really-works)
- [wecoach.gg — Ranked distribution & rules](https://wecoach.gg/blog/article/tft-ranks-distribution-and-how-the-ranking-system-works)
- [seasontimer.live — TFT Set 17 end date](https://seasontimer.live/tft/)
- [1v9.gg — TFT seasons start/end dates](https://1v9.gg/blog/teamfight-tactics-tft-all-seasons-start-end-dates)
- [mobalytics.gg — Economy strategies TFT](https://mobalytics.gg/tft/guides/how-to-manage-your-economy-in-teamfight-tactics-three-strategies)
- [mobalytics.gg — Standard leveling strategy](https://mobalytics.gg/tft/guides/standard-leveling-strategy)
- [thegamer.com — Scouting guide TFT](https://www.thegamer.com/teamfight-tactics-scout-system-explained-guide/)
- [boosteria.org — Scouting guide](https://boosteria.org/guides/tft-scouting-guide-read-lobby-pivot-without-panic)
- [1v9.gg — Game length TFT](https://1v9.gg/blog/how-long-is-a-tft-game)
- [x.com/CompetitiveTFT — Average game time 27-35 min](https://x.com/CompetitiveTFT/status/1140646056977453058)
- [esports.gg — Hyper Roll guide](https://esports.gg/news/teamfight-tactics/everything-you-need-to-know-about-tft-hyper-roll/)
- [theglobalgaming.com — TFT damage mechanics](https://theglobalgaming.com/lol/how-does-damage-work-in-tft)
- [en.wikipedia.org — Teamfight Tactics](https://en.wikipedia.org/wiki/Teamfight_Tactics)
- [medium.com/@ZiberBugs — Game Design Analysis TFT](https://medium.com/@ZiberBugs/game-design-analysis-teamfight-tactics-bc6eb5aafeff)
- [invenglobal.com — Dota Underlords identity crisis](https://www.invenglobal.com/articles/8925/dota-underlords-is-rapidly-losing-players-if-the-game-wants-to-succeed-it-must-solve-its-identity-crisis)
- [vieesports.com — What happened to Dota Underlords](https://vieesports.com/what-even-happened-to-dota-underlords/)
- [en.wikipedia.org — Storybook Brawl](https://en.wikipedia.org/wiki/Storybook_Brawl)
- [psychologyofgames.com — Near-miss effect and game rewards](https://www.psychologyofgames.com/2016/09/the-near-miss-effect-and-game-rewards/)
- [ncbi.nlm.nih.gov PMC2658737 — Near-misses recruit win-related brain circuitry (Sescousse et al. 2010)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2658737/)
- [practicalpie.com — Variable Ratio Reinforcement](https://practicalpie.com/variable-ratio-reinforcement/)
- [dexerto.com — TFT synergy guide traits/origins](https://www.dexerto.com/league-of-legends/teamfight-tactics-champion-synergy-guide-origins-classes-737400/)
- [pcgamesn.com — TFT item recipes guide](https://www.pcgamesn.com/teamfight-tactics/tft-recipes-item-combinations)
- [dotesports.com — TFT pool sizes and rolling odds Set 14](https://dotesports.com/tft/news/teamfight-tactics-champion-pool-rolling-chances)
- [gd-research-result.md (interne)](../../research/gd-research-result.md)
- [combat-model-decision.md (interne)](../../research/combat-model-decision.md)
- [progression-economy-prd.md (interne)](../../research/progression-economy-prd.md)
- [relics-design.md (interne)](../../research/relics-design.md)
- [autobattler-design.md (interne)](../../research/autobattler-design.md)

---

*Rédigé le 2026-06-23 dans le cadre du roadmap-lab adversarial. Source canonique du contenu
TFT : sources primaires web citées ci-dessus (vérifiées ce jour). Ne pas modifier sans
relire les sources. Ce document est en lecture seule du repo de jeu — écriture uniquement
sous `docs/roadmap-lab/`.*
