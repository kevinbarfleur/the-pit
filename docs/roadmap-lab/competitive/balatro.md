# Balatro — Analyse ultra-approfondie (teardown → psychologie → maths → verdict)

> **Auteur** : analyse concurrentielle roadmap-lab, 2026-06-23.
> **Garde-fou** : ce document est en LECTURE SEULE sur le repo. Il n'édite pas le code du jeu.
> Il respecte les 4 piliers : async par snapshots, sim déterministe seedée, DA grimdark, pixel art procédural.
> Toute affirmation de design cite une source (URL ou fichier du repo).

---

## 0. Chiffres de contexte (ne pas ignorer)

Balatro est un jeu de référence obligatoire parce que ses chiffres sont
incontestables :

- **5 millions de copies vendues** au 21 janvier 2025 (1 M supplémentaire après les Game Awards
  2024 seuls) ([The Verge, 2025-01-21](https://www.theverge.com/2025/1/21/24348727/balatro-5-million-copies-the-game-awards))
- **3.5 M vendues en moins d'un an** ([TechRaptor via OpenCritic, 2024-12-12](https://opencritic.com/news/9438/balatro-sales-hit-3-5m-in-less-than-a-year-as-game-awards-near-techraptor))
- **$1 M de chiffre d'affaires dans les 8 premières heures** ([Dexerto, 2024-11-19](https://www.dexerto.com/gaming/balatro-wont-win-tgas-game-of-the-year-award-but-it-should-2983675/))
- **Metacritic 90 / "Universal Acclaim"** 32 critiques PC. 100 % de recommandation OpenCritic.
  ([Metacritic, consulté 2026-06](https://www.metacritic.com/game/balatro/))
- **BAFTA GOTY 2024**. Trois prix aux Game Awards (Best Indie, Best Debut Indie, Best Mobile).
  ([Switchblade Gaming, 2026-03-21](https://www.switchbladegaming.com/strategy-games/balatro-guide/))
- Développé par **une seule personne** (LocalThunk, alias anonyme) en deux ans. Budget inconnu mais
  manifestement < $500 k. ([Rolling Stone, 2024-12-24](https://www.rollingstone.com/culture/rs-gaming/balatro-localthunk-interview-1235214060/))

Ces chiffres signifient : Balatro est une masterclass dont on peut tout extraire, ou tout rejeter.
Ni l'un ni l'autre n'est utile sans le *mécanisme précis* derrière.

---

## 1. Boucle cœur — architecture précise

> Sources : [balatrowiki.org/w/Gameplay_loop](https://balatrowiki.org/w/Gameplay_loop),
> [games.gg — beginners guide](https://games.gg/balatro/guides/balatro-beginners-guide/)

### 1.1 Structure d'un run

```
Run = 8 Antes
  Ante = 3 Blinds : Small Blind → Big Blind → Boss Blind
    Blind = [optionnel : skip → Tag] | [obliger : boss blind]
      Blind active = N mains disponibles, K défausses
        Main = choisir ≤5 cartes → score += Chips × Mult
        Score ≥ cible → Cash Out
          Cash Out = récompense or + intérêts + bonus hand
            → Shop
              Shop = acheter Jokers, consommables, Vouchers, packs
                → Blind Select suivant
Ante 8 Boss Blind battu = WIN (option : Endless Mode)
```

**Durée réelle** : 20–40 minutes par run en mode normal selon le niveau.
([digitaledge.org](https://digitaledge.org/how-balatro-turned-poker-hands-into-the-ultimate-roguelike-addiction/))
Grâce au Skip Blind, les runs peuvent être raccourcies à ~15 min pour les joueurs experts.
([The Gamer — Balatro vs Slay the Spire](https://www.thegamer.com/balatro-vs-slay-the-spire-comparison-which-game-is-better/))

### 1.2 La formule centrale

```
Score = Chips × Mult
```

Formule unique, publique, permanente. Tout le jeu est une optimisation de cette
formule. Aucune exception, aucun système parallèle.

Résolution gauche → droite : d'abord la main de base (hand type + niveau), puis les cartes jouées,
puis les cartes en main, puis les Jokers (left to right).
([kosgames.com — score calculation](https://kosgames.com/balatro-score-calculation-guide-53637/))

Conséquence : l'**ordre des Jokers** est une décision de skill micro qui change le score.
Exemple chiffré : 100 Chips × (+14 Mult) × (×2 Mult) = 2 800 vs 100 Chips × (×2 Mult) × (+14 Mult) = 3 000.
Inverser le xMult avant le +Mult perd 200 points. ([games.gg — beginners guide](https://games.gg/balatro/guides/balatro-beginners-guide/))

### 1.3 Les Jokers

**Pool** : 150 Jokers au total (update 1.0.1o-FULL).
105 disponibles dès le premier run, 45 déverrouillables.
([balatrogame.fandom.com/wiki/Jokers](https://balatrogame.fandom.com/wiki/Jokers))

Raretés et probabilités de tirage en shop/pack :
- Common : 70 % — 61 Jokers
- Uncommon : 25 % — 64 Jokers
- Rare : 5 % — 20 Jokers
- Legendary : 0 (exclusivement depuis The Soul, carte Spectrale, elle-même à 0.3 % dans les packs)
([gameplay.tips — RNG mechanics](https://gameplay.tips/guides/balatro-rng-mechanics-guide.html))

Slots actifs simultanément : **5 par défaut**. Extensible via Voucher (Painting +1) ou certains Jokers.

Catégories fonctionnelles :
- **+Chips** : ajoute à la base de Chips (additif)
- **+Mult** : ajoute au Mult (additif, linéaire)
- **×Mult (xMult)** : multiplie le Mult courant (multiplicatif, **exponentiel si plusieurs**)
- **Scaling** : croît selon condition (temps, actions, argent…)
- **Economy** : génère de l'or passif
- **Retrigger** : rejoue un effet déjà compté
- **Utility** : modifie règles, deck, main size

L'architecture optimale d'un build : `+Chips` (gauche) → `+Mult scaling` → `×Mult` (droite).
([gamobo.wordpress.com — intermediate tips](https://gamobo.wordpress.com/2024/12/01/intermediate-tips-for-balatro/))

---

## 2. Maths chiffrées — escalade, économie, probabilités

### 2.1 Cibles de score par Ante (hardcodées jusqu'à Ante 8)

```lua
-- Source : misc_functions.lua (extrait par la communauté)
-- https://steamcommunity.com/app/2379780/discussions/0/4308327413809320718/
local amounts = {300, 800, 2800, 6000, 11000, 20000, 35000, 50000}
```

| Ante | Small Blind | Big Blind | Boss Blind |
|------|-------------|-----------|------------|
| 1 | 300 | 450 | 600 |
| 2 | 800 | 1 200 | 1 600 |
| 3 | 2 800 | 4 200 | 5 600 |
| 4 | 6 000 | 9 000 | 12 000 |
| 5 | 11 000 | 16 500 | 22 000 |
| 6 | 20 000 | 30 000 | 40 000 |
| 7 | 35 000 | 52 500 | 70 000 |
| 8 | 50 000 | 75 000 | 300 000 (Showdown × 6) |

Small = ×1.0, Big = ×1.5, Boss = ×2.0 de la valeur du tableau.
Le **Showdown Blind d'Ante 8** est une exception : cible ~300 000 (×6 sur la base).

**Rapport de croissance Ante 1→8** : 300 → 50 000 (Boss) = **×166**. Mais le vrai boss, le
Showdown, exige ×1000 le premier Ante. La croissance est *non linéaire intentionnelle* :
plateau à 6–7 avant l'explosion finale.
([mattgreer.dev — score growth](https://www.mattgreer.dev/blog/balatro-score-growth/))

**En Endless Mode** (Ante 9+) :
```
score(ante) = 50000 × (1.6 + (0.75(ante-8))^(1+0.2(ante-8)))^(ante-8)
```
Croissance super-exponentielle proportionnelle à `x^(x²)` où x = ante courant.
([balatrowiki.org/w/Blinds_and_Antes](https://balatrowiki.org/w/Blinds_and_Antes))

**Green Stake et Purple Stake multiplient les cibles** : les deux s'empilent (×4 de la base
en Purple Stake).
([balatrohq.com — gold stake guide](https://balatrohq.com/guides/gold-stake-guide/))

### 2.2 Courbe de scaling des scores joueurs

Types de scaling possibles ([mattgreer.dev](https://www.mattgreer.dev/blog/balatro-score-growth/)) :

- **Linéaire** : `+X chips/round`. `score(t) = base + X·t`. Ne tient pas après Ante 4.
- **Quadratique** : `+X mult/round` combiné à `chips constant`. `score(t) ≈ chips × mult(t)`.
  La plupart des Jokers scaling (Green Joker, Swashbuckler…) sont quadratiques.
- **Exponentiel** : plusieurs xMult simultanés. `score = chips × mult × k1 × k2 × k3…`.
  Exemple : 3 Jokers ×3 chacun → ×27 sur le Mult total.

Conséquence de design : le jeu *force* le pivot quadratique → exponentiel entre Ante 4 et 6.
Les builds "flat +Mult seulement" stagnent → mur → mort. La découverte de ce pivot est
l'arc d'apprentissage central du joueur.

### 2.3 Économie — le système d'intérêt

```
Intérêt/round = min(floor(or_détenu / 5), 5)  [par défaut]
```
Cap par défaut : **$5/round** si l'on détient **≥$25**.
([balatrowiki.org/w/Interest](https://balatrowiki.org/w/Interest))

Sur 24 Blinds (run complète), en maintenant $25 dès Ante 2 : **~$120 gratuits**.
([games.gg — economy guide](https://games.gg/balatro/guides/balatro-economy-guide/))

Vouchers et Jokers d'intérêt (cumulables) :
- **Seed Money** : cap → $10/round (base)
- **Money Tree** : cap → $20/round (upgrade, unlock : 10 rounds de cap maximal)
- **To the Moon** : +$1/round pour chaque tranche de $5 détenue (pas de cap propre)
- Stack maximal "To the Moon" + stack or élevé : jusqu'à **$40/round** passif

Revenus par Blind :
- Small Blind : $3 (nul sur Red Stake+)
- Big Blind : $4
- Boss Blind : $5
- Showdown (Ante 8) : $8
- Hands restantes non jouées : $1/main
([casualgameguides.com](https://casualgameguides.com/walkthroughs/balatro/money-interest-reroll-strategy))

**Reroll** : $5 premier reroll dans un shop, +$1 par reroll supplémentaire *dans le même shop*,
reset au shop suivant. Le Voucher **Reroll Surplus** réduit le premier reroll à $2 (base).

### 2.4 Éditions des Jokers (modificateurs de rareté de rendu)

Probabilité naturelle d'avoir une édition sur un Joker en shop/pack :
- Foil (+50 Chips) : **2 %**
- Holographic (+10 Mult) : **1.4 %**
- Polychrome (×1.5 Mult) : **0.3 %** (le plus puissant, le plus rare)
- Negative (+1 slot Joker) : **0.3 %**
([gameplay.tips — RNG mechanics](https://gameplay.tips/guides/balatro-rng-mechanics-guide.html))

Ces probabilités peuvent être doublées par le Joker "Oops! All 6s" (unlock : 10 000+ chips
en une main).

---

## 3. Psychologie — pourquoi ça hook

### 3.1 Le modèle VRS + agence

La recherche comportementale identifie les **Variable Ratio Schedules (VRS)** comme le renforcement
le plus puissant — le joueur ne sait pas *quand* vient la récompense mais sait qu'elle vient.
([armchairarcade.com, 2026-05-20](https://armchairarcade.com/perspectives/2026/05/20/balatro-game-review-why-is-it-so-addictive/))

Balatro applique le VRS à **trois niveaux imbriqués** :
1. **Main par main** : les cartes tirées sont aléatoires — chaque main peut débloquer un score inattendu.
2. **Shop par shop** : les Jokers disponibles sont aléatoires — chaque ouverture de shop est un tirage.
3. **Run à run** : la combinaison gagnante d'un run ne réapparaît jamais identique.

**La différence clé avec une machine à sous** : dans Balatro, *les décisions du joueur changent
l'outcome*. Le résultat est "luck shaped by strategy" (aléatoire contraint par la stratégie).
([armchairarcade.com](https://armchairarcade.com/perspectives/2026/05/20/balatro-game-review-why-is-it-so-addictive/))
C'est ce qui distingue addiction saine d'addiction destructrice : l'agence maintient l'estime de soi.

### 3.2 Near-miss sous agence

Le near-miss classique (machine à sous : deux cerises et rien) est douloureux *parce que l'on n'a
aucun levier*. Balatro en produit la version saine : le joueur *voit* comment il aurait pu survivre
(mauvais Joker placement, mauvaise main choisie, mauvais pivot). La postmortem est toujours
constructive.
([franklantz.substack.com — Playing Balatro](https://franklantz.substack.com/p/playing-balatro),
[ejaw.net — low-key difficulty](https://ejaw.net/balatro/))

Citation de l'analyse ejaw.net :
> "the RNG in Balatro is generous enough to always give the player something to work with, but
> the interaction space is vast enough that most players are playing sub-optimally without realizing it.
> That gap between perceived skill and actual skill depth is the engine that drives 400-hour playtimes."

### 3.3 Feedback sensoriel comme amplificateur

L'analyse UI de [medium.com/@yyh19971004 (2026-02)](https://medium.com/@yyh19971004/balatro-design-analysis-visual-packaging-and-interactive-feedback-cc6fa6a65370) liste précisément :
- Screen shake + flip d'animation + nombres sautants exponentiels + effets de flammes quand le Mult s'emballe
- Synchronisation pitch de la musique avec la vitesse de défilement des chiffres
- Inertie physique simulée des cartes (magnétisme d'accroche)
- Speed modifier global (le joueur compresse les animations = raccourcit la boucle de feedback positif = plus de dopamine/minute)

Ces éléments transforment une opération mathématique (`Chips × Mult`) en *expérience sensorielle*.
Ils ne *font* pas le gameplay mais en **amplifient la résonance émotionnelle**. Le jeu est identique
sans eux — moins addictif.

### 3.4 Le modèle mental partagé (poker)

Balatro utilise les mains de poker comme base cognitive.
LocalThunk :
> "The poker theme was slapped on top of the game I was already creating mainly as an onboarding tool."
([rogueliker.com interview, 2024-03-07](https://rogueliker.com/balatro-interview/))

L'effet : **toute personne ayant vu du poker à la télévision** sait que Flush > Straight > Three of a Kind.
Elle n'a rien à apprendre sur la hiérarchie. Elle reçoit directement les couches supplémentaires (Jokers).
Coût d'entrée cognitif réduit à zéro. ([ejaw.net](https://ejaw.net/balatro/))

### 3.5 Session length et friction zéro

Run de 20–40 min. "Just one more run" n'est jamais une promesse de 2h.
Friction entre la mort d'un run et le suivant : **zéro** (raccourci R = restart immédiat).
([games.gg — hidden mechanics](https://games.gg/balatro/guides/balatro-hidden-mechanics/))

Pas de lobby, pas d'écran de chargement long, pas de compte à créer, pas de notifications push.
Le jeu ne retient pas *par la culpabilité* mais *par la qualité de l'expérience*.
([armchairarcade.com](https://armchairarcade.com/perspectives/2026/05/20/balatro-game-review-why-is-it-so-addictive/))

### 3.6 Highroll : l'effet "briser le jeu"

Les scores atteignent des milliards. Ce n'est pas un bug, c'est une feature.
LocalThunk (résumé ejaw.net) :
> "Give players a rocket ship, but make them learn to fly it."

La différence entre *breaking the game* (combo puissant trouvé par skill) et *destroying the game*
(trivialisation sans effort) est que dans Balatro **le skill de construction est toujours requis**,
même pour les combos extrêmes. Les cibles de Blind continuent de monter.

---

## 4. Structure compétitive/ranked

### 4.1 Stakes (difficulté croissante, per-deck)

8 Stakes cumulatives. Chaque deck doit débloquer indépendamment les Stakes.
Cela crée un **grind extensif mais clair** : 15 decks × 8 Stakes = 120 runs de victoire théoriques max.

| Stake | Modificateur ajouté |
|-------|---------------------|
| White | Base (aucun) |
| Red | Small Blind = 0 or |
| Green | Score cible scale plus vite |
| Black | 30 % des Jokers shop/packs = Eternal (insécable) |
| Blue | -1 Défausse |
| Purple | Score cible scale encore plus vite (s'empile avec Green) |
| Orange | 30 % des Jokers shop/packs = Perishable (debuffé après 5 rounds) |
| Gold | 30 % des Jokers shop/packs = Rental ($3/round à payer) |
([balatrowiki.org/w/Stakes](https://balatrowiki.org/w/Stakes))

L'important : les Stakes n'ajoutent **pas de contenu** (aucun Joker exclusif) — elles **contraignent
les ressources** et **amplifient les pressions existantes**. Gold Stake accumule *tous* les modificateurs
précédents simultanément.

**Remarque de design** : en Gold Stake, l'économie est serrée (aucune récompense Small Blind),
le scaling est ×4 plus exigeant, un Joker sur trois devient Rental. C'est un test de compréhension
systémique profonde, pas un test de grind.

### 4.2 Seeded runs et leaderboards communautaires

Balatro dispose nativement d'un système de **seeds** : un string alphanumérique détermine tous
les éléments RNG du run (Jokers en shop, contenus des packs, probabilités conditionnelles).
([balatrowiki.org/w/Seed](https://balatrowiki.org/w/Seed))

Seeded runs ne débloquent ni achievements ni unlocks, mais permettent :
- La communauté speedrun : **speedrun.com/Balatro** (578 followers, 1 936 runs, 446 joueurs)
  ([speedrun.com/Balatro](https://www.speedrun.com/Balatro))
- Les défis de seed spécifique ("ce seed, cette difficulty, meilleur temps")
- Les courses communautaires

### 4.3 Balatro Multiplayer (mod communautaire non officiel)

> **Important** : le jeu de base n'a PAS de mode multijoueur. Ce qui suit est un mod.

[balatromp.com](https://balatromp.com/) — mod unofficial avec >3 000 joueurs ranked.

Système MMR :
```
Stone < 250 MMR → Steel 250+ → Gold 320+ → Lucky 460+ → Glass 620+
→ Foil (Top 50) → Holographic (Top 10) → Polychrome (Top 5) → Negative (Top 1)
```
Les noms des rangs utilisent directement les éditions de Jokers — cohérence thématique totale.

**Ranked Queue** : rebalancé (moins RNG-heavy), nouvelles mécaniques pour le compétitif.
**Vanilla Queue** : règles originales, même seed pour tous.
**Smallworld** : 25 % de tout le contenu, Showman toujours actif.

LocalThunk a répondu à ce mod :
> "There's a cool mod if you want that."
Formulation ambiguë mais ni validation officielle ni blocage.

### 4.4 Daily Challenges (non implémentés natifs — via seeds communautaires)

Balatro n'a pas de daily/weekly challenge natif au 2026-06-23.
La communauté organise des courses sur seeds partagés via Discord.
C'est un gap produit identifié : un daily seeded run officiel avec leaderboard mondial
est une feature souhaitée depuis le lancement.

---

## 5. Design des Jokers — le modèle de relic de Balatro

> Source principale pour cette section : interviews LocalThunk
> ([gameinformer.com, 2024-03-21](https://gameinformer.com/interview/2024/03/21/balatro-was-almost-called-joker-poker-and-other-details-from-its-creator)),
> ([rogueliker.com, 2024-03-07](https://rogueliker.com/balatro-interview/))

### 5.1 Contrainte fondatrice

LocalThunk s'est imposé une règle de design absolute :
> "Descriptions can't be more than four lines and 20 words."

Conséquence : chaque Joker doit être *immédiatement compris* à la première lecture, même à
Ante 1. Cela force la simplicité de l'effet unitaire ET permet la complexité d'émergence
par combinaison.

### 5.2 Dual process de création

LocalThunk : parfois l'effet vient d'abord (→ cherche un sujet visuel), parfois le sujet
visuel vient d'abord (→ invente un effet). Les deux directions produisent des Jokers valides.

### 5.3 Un Joker = une règle modifiée, pas un "passif"

Le vocabulaire de Balatro est celui du deckbuilder, pas du RPG. Un Joker ne donne pas "+5 ATK".
Il modifie **une règle du jeu** :
- "Rendre les Straights faisables à 4 cartes au lieu de 5" (Four Fingers)
- "Copycat le Joker de droite" (Blueprint)
- "Les Paires comptent comme des Flush" (Smeared Joker)
- "Chaque King en main donne ×1.5" (Baron)

Cette formulation *en règle* rend chaque Joker **build-defining** plutôt que *stat-bump*.
La distinction est capitale.

### 5.4 Balatro vs Slay the Spire sur le design des reliques

| Dimension | Balatro (Jokers) | Slay the Spire (Reliques) |
|-----------|------------------|--------------------------|
| Acquisition | Shop (achetable, rollable) | Coffres, boss rewards, events (non achetable) |
| Nombre simultané | 5 (expansible) | Illimité (accumulation) |
| Prix | $4–$10 | Gratuit/non-monétaire |
| Vendu/défaussé | Oui (sell value) | Non |
| Découverte | Par pool aléatoire | Par tirage dans pool de boss/coffre |
| Effet taille | Énorme (×Mult) | Moyen (modificateur de règle) |
| Stackabilité | 5 max active + éditions | Illimitée (accumulation run-longue) |

Les deux modèles ont leur pertinence. La différence clé : Balatro force une **économie de slot**
(max 5 actifs) qui crée de vraies décisions de vente. StS est une accumulation.

---

## 6. Analyse adversariale — les faux transferts à démonter

Avant les verdicts de transférabilité, il faut démonter les analogies paresseuses que tout
agent de roadmap pourrait proposer.

### Faux transfert #1 : "Mettre un Chips×Mult dans The Pit"

L'argument paresseux : "Balatro marche avec Chips×Mult, The Pit pourrait scorer en Chips×Mult aussi."

**Pourquoi c'est invalide** : The Pit n'est PAS un jeu de scoring. C'est un autobattler où le
résultat est binaire (victoire/défaite du combat) déterminé par la sim. Introduire un score
de "points" briserait le modèle async-snapshots : un snapshot capture un *build*, pas un *score*.
Le score de Balatro est l'*output* d'un run — dans The Pit l'output d'un run est 10 victoires/5 défaites.
Ces structures sont fondamentalement incompatibles. **Le mécanisme psychologique de Chips×Mult
ne survit pas au changement de genre.**

### Faux transfert #2 : "Jokers = Reliques"

L'argument paresseux : "Les Jokers de Balatro = les Reliques de The Pit, même système."

**Pourquoi c'est trop simple** : Jokers et Reliques partagent le *nom de l'archétype* (modificateur
de build randomisé) mais divergent sur 4 dimensions critiques :
- **Économie** : les Jokers s'achètent avec de l'or (tension constante buy vs reroll vs save). Les
  Reliques de The Pit sont *offertes* (1-parmi-3, aucune tension d'or). Ce n'est pas le même mécanisme
  d'engagement.
- **Vendabilité** : un Joker peut être *vendu* (décision stratégique profonde, surtout pour récupérer
  de l'or). Les Reliques de The Pit ne se vendent pas.
- **Nombre actif** : 5 Jokers max → économie de slot. Reliques de The Pit : accumulation sans cap
  explicite décrit dans le code (une offre tous les 3 combats, cumul).
- **Identification/leurres** : le modèle RÉVISÉ 2026-06 de The Pit *supprime* les leurres (décision
  verrouillée §7 du 00-state.md). La comparaison "Joker mystérieux = Relique cryptique" est obsolète.

**Le mécanisme transférable de Balatro sur les Reliques** est ailleurs : la *lisibilité d'effet +
flavor* (cf. §8.4 ci-dessous). Pas la mécanique d'acquisition.

### Faux transfert #3 : "Implémenter des Stakes/difficultés"

L'argument paresseux : "Balatro a 8 Stakes, The Pit devrait avoir des niveaux de difficulté similaires."

**Ce qui marche dans Balatro** : les Stakes imposent des *contraintes de ressources* (moins d'or,
moins de défausses) qui forcent des builds différents — elles ne rendent pas les ennemis plus forts.

**Ce qui survit dans The Pit** : la même logique fonctionne. Les modèles de saison/rang peuvent
imposer des contraintes (moins de slots de boutique au départ, coût de reroll augmenté, adversaires
de rang plus élevé). Mais le détail d'implémentation est différent parce que :
- The Pit n'a pas de "main de cartes" à gérer
- Les contraintes s'appliquent au *build* et à l'*économie* du run roguelite (`state.lua`)
- Le système de **lives** et **win_target** est déjà le filtre de difficulté principal

### Faux transfert #4 : "Endless Mode = Ascension Mode"

Balatro propose un Endless Mode post-win avec scaling super-exponentiel.
Slay the Spire a le mode Ascension (20 niveaux de difficulté progressive).

**Ce que ces modes ont en commun** : ils répondent au besoin de *compétence growth* (Deci et Ryan,
Self-Determination Theory — la compétence est l'un des 3 besoins fondamentaux). Les joueurs qui
ont "gagné" veulent continuer à progresser.

**Dans The Pit** : les Stakes/rangs async remplissent ce rôle. Grimper dans le tier ranked
contre des builds de plus en plus maîtrisés = Ascension distribuée. Pas besoin de créer un mode
séparé si le système ranked est bien calibré.

---

## 7. Verdicts de transférabilité — mécanisme par mécanisme

### 7.1 Chips × Mult (la formule de score)

**Teardown** : formule unique et publique. Tout découle d'elle. Chips = base, Mult = levier
exponentiel. L'ordre de résolution crée un skill micro.

**Psychologie** : les nombres qui "explosent" = feedback visuel de puissance exponentielle.
Voir un score passer de 1 000 à 1 000 000 en une main crée un highroll mémorable.

**Maths** : `additive + (× multiplicatif) = quadratique à exponentiel`. Le joueur *voit*
la croissance. La transparence de la formule EST le plaisir.

**Verdict** : **NON TRANSFÉRABLE** directement. The Pit est un autobattler; son "score" est
binaire (win/loss). Mais le *principe psychologique* survit : rendre **la puissance lisible et
chiffrée** pour chaque unité/effet. Dans The Pit, c'est déjà présent : stats PV/ATK, infobulles
DoT, stacks poison, modificateurs `resolve(base, mods)`. L'enjeu est de s'assurer que le joueur
*voit* sa croissance de build avant le combat (preview de composition claire, indicateurs d'adjacence).

**Adaptation** : un "score de composition estimé" pré-combat (affiché dans la phase build) qui
montre la puissance brute du build (ex. DPS estimé de l'équipe, résistance estimée) serait l'équivalent
fonctionnel de Chips×Mult pour The Pit. Rend la puissance lisible, encourage l'optimisation.

### 7.2 Escalade de cibles (anti-complacency)

**Teardown** : les Boss Blinds augmentent de ×166 entre Ante 1 et 8. Pas d'exponentielle exacte
— courbe intentionnelle avec paliers et pic final.

**Psychologie** : l'escalade empêche la complaisance. Un build qui gagne facilement au début *doit*
évoluer. L'anti-complacency crée le besoin permanent de "monter d'un cran".

**Maths** : voir §2.1. La courbe Balatro est *non linéaire intentionnelle* : elle permet de
"se reposer" à Ante 5–6 avant l'explosion Ante 8. Ce n'est pas un hasard.

**Verdict** : **TRANSFÉRABLE avec adaptation**. The Pit dispose déjà d'une escalade d'adversaires
(seed d'escalade dans `state.lua`). Le problème actuel diagnostiqué (the-pit-balance-diagnosis) est
la **variance early** : le run peut se terminer trop tôt aléatoirement. La leçon de Balatro est
de rendre les 3–4 premiers rounds *délibérément généreux* pour établir un build fonctionnel, puis
de presser le joueur progressivement. La courbe Balatro 300→800→2800→6000 est délibérément douce
jusqu'à Ante 3. À appliquer : **calibrer l'escalade des adversaires dans The Pit avec des paliers
similaires** (early = build permissif, mid = pression croissante, late = examen du build optimal).

### 7.3 Le modèle économique shop/intérêt

**Teardown** : or frais par round + intérêt sur capital détenu + reroll payant et croissant.
Tension permanente entre "dépenser pour monter" et "conserver pour générer des intérêts".

**Psychologie** : le système d'intérêt force le joueur à *penser à l'or comme ressource secondaire*
(non seulement "budget courant" mais "actif productif"). C'est une profondeur économique rare dans
les jeux casual.

**Maths** : intérêt max $5/round × 24 rounds = $120 passif. Or shop typique : $4–$10/item.
Le retour sur investissement de l'intérêt est énorme si respecté dès Ante 1.

**Verdict** : **PARTIELLEMENT TRANSFÉRABLE**. The Pit a déjà le modèle SAP (or frais/round,
pas de banque, GOLD_PER_ROUND = 10 [PH]). Ce modèle plus simple est *intentionnel et défendu*
(gd-research-result.md §1.6). L'intérêt de Balatro ajoute une *couche de gestion* qui alourdit
la boucle — contraire au pilier "simplicité de gestion → profondeur émergente". **Ne pas copier
le système d'intérêt tel quel.** Mais adopter le principe : un levier économique qui récompense
la *patience*. Dans The Pit, ce levier existe déjà : streaks de victoire (+or). À enrichir
marginalement sans casser la lisibilité SAP.

### 7.4 Reroll du shop

**Teardown** : $5 premier reroll, +$1 ensuite dans le même shop, reset au suivant. Tension
"chercher le Joker parfait vs économiser".

**Psychologie** : le reroll est un "pull de gacha honnête" — on paie pour une chance, on voit
immédiatement le résultat. La dépense est visible et contrôlée (pas de RNG caché sur le coût).

**Verdict** : **DÉJÀ EN PLACE** dans The Pit (`REROLL_COST = 1` [PH]). Le coût de reroll
de The Pit est intentionnellement plus bas (SAP-style) parce que le pool est moins dense.
La leçon de Balatro : **ne pas permettre au reroll de résoudre tous les problèmes** — si le
reroll est trop bon marché, le joueur reroll indéfiniment et le pool de boutique perd sa tension.
Recommandation : surveiller le taux de reroll dans les sims et calibrer le coût en fonction.

### 7.5 Skip Blind → Tags

**Teardown** : on peut sauter Small et Big Blinds contre un Tag (bonus immédiat ou différé : Joker
gratuit, $25 différés, voucher…). La décision est stratégique : or + shop vs Tag valeur.

**Psychologie** : le skip transforme une "corvée" (blind facile à battre) en *décision* (que vaut
ce Tag ?). Réduit la friction des rounds "triviaux" sans les supprimer.

**Verdict** : **NON TRANSFÉRABLE** dans la structure actuelle de The Pit. The Pit n'a pas de
"blinds triviales" — chaque combat est contre un adversaire ghost/IA avec son propre build.
Sauter un combat = sauter la possibilité de dégâts à la défense (vies). Le modèle n'existe pas.
Mais le principe psychologique — *transformer les rounds faciles en décisions intéressantes* —
peut s'appliquer différemment : **proposer un choix avant certains combats** (ex. "adversaire
facile connu vs adversaire mystérieux avec récompense bonus"). C'est une idée de roadmap distincte,
pas un port direct.

### 7.6 Boss Blinds (modificateurs uniques par combat)

**Teardown** : chaque Boss Blind impose une contrainte unique ("les cartes rouges sont débuffées",
"-1 taille de main", "les Jokers sont retournés face cachée"). Oblige à adapter le build *existant*
à une contrainte imprévue.

**Psychologie** : les Boss Blinds créent du *stress légitime* — même un bon build peut être
contre-counté par un boss. L'imprévisibilité force l'adaptabilité et empêche le "pilote automatique".

**Maths** : 40+ Boss Blinds distincts dans le pool. Pas toutes présentes dans un run.
([games.gg — boss blinds](https://games.gg/balatro/guides/balatro-boss-blinds-ante/))

**Verdict** : **TRANSFÉRABLE comme concept, mécanisme différent**. The Pit dispose déjà de
**modificateurs de combat** via le sigil actif (la *forme* du plateau change l'exposition
colonne/front/back). Les "Boss Blinds" de Balatro correspondent aux **adversaires à archétype
spécifique** des `encounters.lua` (équipes IA), pas à des modificateurs de règles globaux. À
considérer : des *rencontres spéciales* à certains jalons du run (combat X = adversaire avec
contrainte : ex. "toutes vos unités en front row sont Bleed au départ", ou "l'adversaire a +1 vie
de bonus") pour simuler la tension Boss Blind. **Vérifier que cela ne brise pas le déterminisme
seed** (contraintes = data, pas code).

### 7.7 Escalade de difficulté via Stakes

**Teardown** : 8 Stakes par deck, cumulatifs. Chaque stake ajoute une contrainte de ressources.

**Psychologie** : la progression per-deck crée une "collection de victoires" à compléter.
Chaque deck + stake = défi unique. 120 combinaisons théoriques → contenu très long sans
créer de contenu neuf.

**Verdict** : **TRANSFÉRABLE comme structure ranked**. Dans The Pit, les rangs async
(progression + rang du snapshot servi) sont l'équivalent fonctionnel. Un joueur de rang
"Adamantine" affronte des builds de rang "Adamantine" — même principe de progression gating.
Les "Stakes" de The Pit pourraient se matérialiser en **modifiers de run par rang** : en
tier 1 les adversaires ont des builds de base ; en tier 4+ les adversaires ont des builds
avec reliques et duplicatas niveau 3. Ces modificateurs ne changent pas le code de combat
(ils changent les snapshots servis) → compatible avec le pilier déterministe.

### 7.8 150 Jokers / pool large

**Teardown** : 150 Jokers avec raretés différentes et 45 débloquables. La taille du pool
assure que deux runs ne sont jamais identiques. Les 45 débloquables créent une méta-progression
de découverte.

**Psychologie** : la "Collection" (voir dans le menu) est un registre de ce qui a été vu.
La découverte d'un nouveau Joker est une récompense en soi. Le fait que 45 soient lockés
force des comportements spécifiques ("je dois faire X pour voir le Joker Y").

**Verdict** : **PARTIELLEMENT TRANSFÉRABLE — le Grimoire est déjà la réponse**. The Pit
a 83 unités et 21 reliques. Le **Grimoire** (`src/core/grimoire.lua`) est exactement l'équivalent
de la Collection de Balatro : registre persistant cross-run. La méta-progression de découverte
est déjà architecturée. Ce qui manque : des *unités lockées à débloquer* (actuellement le
pool est uniforme). Ajouter un système de déblocage d'unités de rang 5 par conditions
spécifiques (ex. "atteindre 10 victoires avec une équipe poison uniquement") serait une
application directe de ce mécanisme. **Mais attention au pilier "simplicité"** : le
déverrouillage doit rester *optionnel pour s'amuser* et *non bloquant pour progresser*.

### 7.9 Seeded runs / replay déterministe

**Teardown** : le système de seeds de Balatro détermine tous les éléments aléatoires d'un run.

**Psychologie** : les seeds permettent la *transmission de challenges* entre joueurs, les courses
synchronisées, la répétition pour l'apprentissage.

**Verdict** : **DÉJÀ IMPLÉMENTÉ — c'est un pilier de The Pit**. La sim déterministe seedée de
The Pit est *plus stricte* que Balatro (pas de `math.random` global, RNG injecté par combat,
golden-log de régression). Les snapshots async sont un cas d'usage de cette propriété.
La leçon compétitive de Balatro : les seeds communautaires génèrent du contenu organique
(challenges "fais mieux que moi sur ce seed"). Potentiel à exploiter dans la structure ranked
de The Pit : un "seed de semaine" distribué, le run le plus court (moins de combats perdus)
dans ce seed = leaderboard. Compatible avec l'async et le déterminisme.

---

## 8. Enseignements clés pour The Pit — synthèse priorisée

Ces enseignements sont listés par ordre de pertinence et de facilité d'implémentation.
Ils ne violent aucun des 4 piliers.

### 8.1 La lisibilité de l'escalade (PRIORITÉ 1 — calibration run)

Balatro rend l'escalade *visible et prévisible* : le joueur sait que la cible va monter,
sait approximativement de combien. Il n'est jamais surpris par une montée abrupte.

**Application The Pit** : afficher la progression d'adversaires dans la phase build ("prochain
combat : Tier 3, spécialiste Burn") et calibrer la courbe d'adversaires avec des paliers
délibérément permissifs en early (rounds 1–3) et progressivement exigeants. La **variance early**
identifiée dans le diagnostic d'équilibrage est l'anti-pattern exact de ce que Balatro évite.

### 8.2 Le skill micro d'ordre (PRIORITÉ 2 — profondeur tactique)

L'ordre des Jokers dans Balatro est un skill micro visible, immédiatement compréhensible,
aux conséquences chiffrées importantes.

**Application The Pit** : le **placement sur le plateau-graphe 3×3** EST le skill micro de The Pit
(adjacence, profondeur de colonne, taunt placement). Ce n'est pas à inventer — c'est déjà l'axe
de design. La leçon : s'assurer que ce skill est **visible et ses conséquences chiffrées** affichées
dans l'UI (surlignage des adjacences actives + indication de l'exposition colonne). L'implémentation
du preview de profondeur (qui sera en front vs back selon le sigil actif) doit être cristalline.

### 8.3 Feedback sensoriel de puissance (PRIORITÉ 3 — UI/VFX)

Les effets visuels de Balatro transforment une formule en expérience. Sans eux le jeu reste
fun mais moins mémorable.

**Application The Pit** : le système VFX afflictions (the-pit-affliction-vfx, mémoire) est en cours.
La leçon Balatro : les *moments de highroll* (unit T3 qui one-shots la moitié de l'équipe adverse,
poison qui cascade sur toute une ligne) doivent être **visuellement distincts** des actions banales.
Un VFX de "combinaison parfaite" (effets multiples qui se déclenchent en chaîne) est l'équivalent
des flammes de Balatro.

### 8.4 Lisibilité des Jokers → Lisibilité des Reliques (PRIORITÉ 4 — design reliques)

La règle de LocalThunk (≤4 lignes, ≤20 mots) est une contrainte de design qui *force* la simplicité
d'effet. Chaque Joker modifie *une règle*.

**Application The Pit** : la décision §7 (reliques lisibles, pivot 2026-06) est alignée. La leçon
complémentaire de Balatro : les reliques les plus mémorables sont celles qui **modifient une règle
du jeu**, pas celles qui "ajoutent +X à Y". Exemples Balatro mémorables :
- Four Fingers : "Flush et Straight possibles à 4 cartes" → ouvre un archétype entier
- Blueprint : "copie le Joker de droite" → crée une mécanique de positionnement

**Reliques de The Pit à viser** : des effets qui *redéfinissent une règle de combat ou de board* —
ex. "les unités adjacentes à un Tank héritent de sa taunt", "les DoT ne se décroissent jamais
en combat", "chaque mort alliée augmente l'aggro de toute l'équipe". Ces reliques créent un
archétype entier, pas juste un buff.

### 8.5 Near-miss sous agence (PRIORITÉ 5 — boucle de retry)

Balatro rend chaque mort *explicable* par le joueur rétrospectivement.

**Application The Pit** : après chaque défaite de combat, afficher un **post-mortem lisible** :
"votre Gravewarden est mort en premier car exposé en front-right avec aggro faible ; l'ennemi
Bleed a priorisé votre carry sans taunt cover." Ce n'est pas une punition — c'est une leçon
émotionnellement safe. Si le joueur *comprend* sa défaite, il revient pour corriger.
Compatible avec le modèle async : le post-mortem est calculé depuis le replay déterministe.

### 8.6 Collection et déblocage progressif (PRIORITÉ 6 — méta-progression)

45 Jokers lockés + Collection visible = raison de revenir même après la "victoire".

**Application The Pit** : le Grimoire est en place. Ajouter des **unités lockées** (peut-être les
T5, débloquées par conditions runs spécifiques) et les rendre visibles dans un écran de collection.
Le joueur qui n'a pas encore vu le "Void-Walker" (ou équivalent) est motivé à tenter d'atteindre
la condition de déblocage. **Garde-fou** : les unités lockées ne doivent pas bloquer un archétype
entier — chaque archétype doit être accessible avec les unités de base.

---

## 9. Ce que Balatro fait que The Pit ne DOIT PAS faire

### 9.1 Score visible vs opacité

LocalThunk a admis un "cursed design problem" : il cache intentionnellement le score pré-main pour
garder le feeling "slot machine". Cela force les joueurs à jouer "à l'instinct".
([gmtk.substack.com — Mark Brown, 2024-04-02](https://gmtk.substack.com/p/balatros-cursed-design-problem))

**Pourquoi The Pit ne doit pas imiter cela** : The Pit est un jeu de *placement et build*, pas de
"hand selection". Cacher le résultat anticipé d'un combat (lequel des deux builds gagne ?) est
exactement ce que le modèle async-snapshot garantit : on *sait* que la sim est déterministe, le
résultat n'est pas aléatoire, il découle du build. L'opacité de Balatro fait partie de son modèle
poker/casino — incompatible avec la promesse grimdark "ton build = ta stratégie = ton résultat".

### 9.2 Session length longue pour les runs difficiles

Les runs Gold Stake de Balatro peuvent dépasser 1h. Le modèle "endless mode" n'a pas de fin.

**Dans The Pit** : 10 victoires = run terminée. La longueur est contrôlée. C'est un choix
supérieur pour le marché mobile/async. Ne pas créer de mode "endless" qui brise cette durée
contrôlée.

### 9.3 L'économie d'intérêt complexe

L'intérêt de Balatro ($1 pour $5 détenus, cap $5/round) ajoute une couche de gestion que les
joueurs casual doivent apprendre. Sur les streams, LocalThunk lui-même admet que beaucoup de
joueurs débutants ne l'exploitent pas pendant des heures.

**Dans The Pit** : or frais/round, pas de banque, SAP-style. Plus simple, plus lisible,
plus accessible pour un jeu mobile-friendly. Ne pas introduire de système d'intérêt.

---

## 10. Verdict final — ce qui est transférable, ce qui ne l'est pas

| Mécanisme Balatro | Transférable | Comment |
|---|---|---|
| Chips × Mult (score visible) | Indirectement | Afficher la puissance du build pre-combat (DPS estimé, résistance) |
| Escalade de cibles calibrée | Oui | Courbe adversaires : early permissif, late exigeant, paliers intentionnels |
| Économie shop + reroll | Partiellement | SAP-style déjà en place ; calibrer le coût reroll anti-spam |
| Skip Blind → Tags | Non (structure) | Remplacer par choix pré-combat optionnel avec bonus |
| Boss Blinds (contraintes imprévues) | Oui (concept) | Encounters spéciaux à jalons, contraintes comme data |
| Stakes par deck | Oui (structure ranked) | Modifiers de run par palier ranked = stakes distribués |
| 150 Jokers / pool large | Partiellement | Grimoire déjà en place ; unités lockées à ajouter progressivement |
| Seeds déterministes | Déjà implémenté | Leaderboard de "seed de semaine" = feature communautaire à exploiter |
| Design Joker = 1 règle modifiée | Oui | Reliques "build-defining" > reliques "stat-bump" |
| Near-miss lisible | Oui | Post-mortem de combat calculé sur replay déterministe |
| Feedback sensoriel (VFX chiffres) | Oui | VFX de highroll combat (chainages DoT, burst) |
| Collection + déblocage progressif | Oui | Unités T5 lockées par conditions + écran Grimoire complet |
| Score opaque pré-main | Non | Contraire à la promesse "build = stratégie = résultat" |
| Endless Mode durée illimitée | Non | The Pit = 10 victoires, durée contrôlée |
| Intérêt sur capital or | Non | SAP-style délibéré, ajout d'intérêt = complexity sans payoff |

---

## Sources

1. [balatrowiki.org/w/Gameplay_loop](https://balatrowiki.org/w/Gameplay_loop)
2. [kosgames.com — score calculation](https://kosgames.com/balatro-score-calculation-guide-53637/)
3. [games.gg — beginners guide](https://games.gg/balatro/guides/balatro-beginners-guide/)
4. [www.switchbladegaming.com — balatro guide](https://www.switchbladegaming.com/strategy-games/balatro-guide/)
5. [ludo.guide/guide/balatro](https://www.ludo.guide/guide/balatro)
6. [games.gg — economy guide](https://games.gg/balatro/guides/balatro-economy-guide/)
7. [games.gg — hidden mechanics](https://games.gg/balatro/guides/balatro-hidden-mechanics/)
8. [gamobo.wordpress.com — intermediate tips](https://gamobo.wordpress.com/2024/12/01/intermediate-tips-for-balatro/)
9. [gameplay.tips — RNG mechanics guide](https://gameplay.tips/guides/balatro-rng-mechanics-guide.html)
10. [balatrogame.fandom.com/wiki/Jokers](https://balatrogame.fandom.com/wiki/Jokers)
11. [steamcommunity.com — ante scaling formula](https://steamcommunity.com/app/2379780/discussions/0/4308327413809320718/)
12. [balatrowiki.org/w/Blinds_and_Antes](https://balatrowiki.org/w/Blinds_and_Antes)
13. [mattgreer.dev — score growth](https://www.mattgreer.dev/blog/balatro-score-growth/)
14. [balatrowiki.org — guide scaling](https://balatrowiki.org/w/Guide:_Scaling)
15. [balatrocalc.com](https://balatrocalc.com/)
16. [games.gg — jokers guide](https://games.gg/balatro/guides/balatro-jokers-guide/)
17. [balatrowiki.org/w/Stakes](https://balatrowiki.org/w/Stakes)
18. [lastwordongaming.com — stakes guide](https://lastwordongaming.com/2024/02/22/balatro-stakes-guide/)
19. [balatrogame.fandom.com/wiki/Stakes](https://balatrogame.fandom.com/wiki/Stakes)
20. [dotesports.com — all balatro stakes](https://dotesports.com/indies/news/all-balatro-stakes-in-unlock-order)
21. [balatrohq.com — gold stake guide](https://balatrohq.com/guides/gold-stake-guide/)
22. [thegamer.com — best stakes ranked](https://www.thegamer.com/balatro-best-stakes-ranked/)
23. [speedrun.com/Balatro](https://www.speedrun.com/Balatro)
24. [balatrowiki.org/w/Seed](https://balatrowiki.org/w/Seed)
25. [balatromp.com — multiplayer mod](https://balatromp.com/)
26. [balatromp.com — ranked matchmaking](https://balatromp.com/docs/ranked-matchmaking/introduction)
27. [gameinformer.com — LocalThunk interview 2024-03-21](https://gameinformer.com/interview/2024/03/21/balatro-was-almost-called-joker-poker-and-other-details-from-its-creator)
28. [toucharcade.com — LocalThunk interview 2024-03-18](https://toucharcade.com/2024/03/18/balatro-interview-mobile-port-localthunk-dlc-plans-updates-new-jokers-demo-feedback/)
29. [playday.one — LocalThunk interview 2024-03-09](https://playday.one/2024/03/09/there-is-a-lot-more-design-to-explore-within-balatro/)
30. [rogueliker.com — LocalThunk interview](https://rogueliker.com/balatro-interview/)
31. [rollingstone.com — LocalThunk 2024-12-24](https://www.rollingstone.com/culture/rs-gaming/balatro-localthunk-interview-1235214060/)
32. [mechanicsofmagic.com — addiction 2026-05-22](https://mechanicsofmagic.com/2026/05/22/critical-play-on-games-of-chance-and-addiction-balatro/)
33. [armchairarcade.com — why so addictive 2026-05-20](https://armchairarcade.com/perspectives/2026/05/20/balatro-game-review-why-is-it-so-addictive/)
34. [mechanicsofmagic.com — frankenstein 2025-05-23](https://mechanicsofmagic.com/2025/05/23/balatro-and-addiction-whos-the-monster-in-frankenstein-really/)
35. [mechanicsofmagic.com — addiction 2024-05-24](https://mechanicsofmagic.com/2024/05/24/what-balatro-taught-me-about-addiction/)
36. [quests.substack.com — play balatro](https://quests.substack.com/p/play-balatro)
37. [medium.com/@yyh19971004 — design analysis 2026-02](https://medium.com/@yyh19971004/balatro-design-analysis-visual-packaging-and-interactive-feedback-cc6fa6a65370)
38. [ejaw.net — low-key difficulty](https://ejaw.net/balatro/)
39. [gmtk.substack.com — cursed design problem](https://gmtk.substack.com/p/balatros-cursed-design-problem)
40. [franklantz.substack.com — playing balatro](https://franklantz.substack.com/p/playing-balatro)
41. [metacritic.com/game/balatro](https://www.metacritic.com/game/balatro/)
42. [tech.yahoo.com — 1 person created balatro](https://tech.yahoo.com/gaming/articles/one-person-created-balatro-best-160000373.html)
43. [theverge.com — 5 million copies](https://www.theverge.com/2025/1/21/24348727/balatro-5-million-copies-the-game-awards)
44. [opencritic.com — 3.5 M copies](https://opencritic.com/news/9438/balatro-sales-hit-3-5m-in-less-than-a-year-as-game-awards-near-techraptor)
45. [dexerto.com — GOTY analysis](https://www.dexerto.com/gaming/balatro-wont-win-tgas-game-of-the-year-award-but-it-should-2983675/)
46. [games.gg — boss blinds guide](https://games.gg/balatro/guides/balatro-boss-blinds-ante/)
47. [casualgameguides.com — money strategy](https://casualgameguides.com/walkthroughs/balatro/money-interest-reroll-strategy)
48. [balatrowiki.org/w/Interest](https://balatrowiki.org/w/Interest)
49. [balatrowiki.org/w/Money](https://balatrowiki.org/w/Money)
50. [digitaledge.org — roguelike addiction](https://digitaledge.org/how-balatro-turned-poker-hands-into-the-ultimate-roguelike-addiction/)
51. [balatrogame.fandom.com/wiki/Tags](https://balatrogame.fandom.com/wiki/Tags)
52. [thegamer.com — balatro vs slay the spire](https://www.thegamer.com/balatro-vs-slay-the-spire-comparison-which-game-is-better/)
53. [glyphshuffle.com — balatro vs slay the spire](https://glyphshuffle.com/blog/balatro-vs-slay-the-spire)
54. [games.gg — how to unlock everything](https://games.gg/balatro/guides/how-to-unlock-everything-balatro/)
55. [balatrohq.com/vouchers](https://balatrohq.com/vouchers/)
