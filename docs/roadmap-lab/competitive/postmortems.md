# Postmortems — Dota Underlords · Storybook Brawl · Artifact
## Analyse ultra-approfondie à des fins de transfert vers *The Pit*

> **Mandat** : pour chaque mécanisme clé — teardown précis → psychologie (pourquoi ça hook) →
> maths chiffrées et sourcées → verdict de transférabilité à *The Pit* (async snapshots, run
> court 10 victoires, sim déterministe, grimdark). Démonter les analogies paresseuses.
>
> **Garde-fous** : lecture seule du repo ; écriture **uniquement** sous `docs/roadmap-lab/`.
> Piliers respectés : async par snapshots, sim déterministe seedée, DA grimdark, pixel art procédural.
>
> *Recherche menée le 2026-06-23. Chaque affirmation est sourcée en ligne.*

---

## Table des matières

1. [Prologue — pourquoi étudier des morts](#1-prologue)
2. [Dota Underlords — l'abandon de Valve](#2-dota-underlords)
   - 2.1 Chronologie et chiffres
   - 2.2 Mécanismes clés : alliances, pool partagé, Jail, City Crawl
   - 2.3 Compétitif et ranked
   - 2.4 Psychologie : ce qui hookait, ce qui a craqué
   - 2.5 Verdicts de transférabilité vers *The Pit*
3. [Storybook Brawl — le naufrage FTX](#3-storybook-brawl)
   - 3.1 Chronologie et chiffres
   - 3.2 Mécanismes clés : trésors, sorts, deux rangées, paliers auto
   - 3.3 Modèle économique et mort financière
   - 3.4 Psychologie : communauté, curation, confiance
   - 3.5 Verdicts de transférabilité vers *The Pit*
4. [Artifact — l'overkill de complexité](#4-artifact)
   - 4.1 Chronologie et chiffres
   - 4.2 Mécanismes clés : trois lanes, or, déploiement de héros, initiatives
   - 4.3 Monétisation quadruple
   - 4.4 Psychologie : frustration opaque, absence de feedback
   - 4.5 Verdicts de transférabilité vers *The Pit*
5. [Synthèse transversale — les 9 lois de la mort](#5-synthese)
6. [Anti-patterns à ne PAS copier dans *The Pit*](#6-antipatterns)
7. [Opportunités positives extraites des ruines](#7-opportunites)
8. [Index des sources](#8-sources)

---

## 1. Prologue — pourquoi étudier des morts {#1-prologue}

> « Artifact was supposed to be a slam dunk. » — Win.gg (2019)

Les postmortems valent plus que les success stories parce qu'ils isolent ce qui casse
quand tout le reste est favorable. Underlords avait une marque (Dota), une communauté
d'auto-chess existante, et Valve. Storybook Brawl avait d'ex-designers de Hearthstone, un F2P
sain, et une communauté réelle. Artifact avait Richard Garfield (Magic : the Gathering) et
Valve. Tous ont échoué ou disparu. Le « pourquoi » est exploitable.

**Règle adversariale de ce document** : aucun « X fait ça, copions » n'est recevable.
Chaque mécanisme doit passer le test en 4 couches :
1. *Teardown* : comment ça fonctionne exactement.
2. *Psychologie* : quel mécanisme cognitif/émotionnel est activé.
3. *Maths* : les chiffres réels, sourcés.
4. *Verdict* : le mécanisme psycho survit-il aux contraintes de *The Pit* ? Sinon, quoi
   mettre à la place ?

---

## 2. Dota Underlords — l'abandon de Valve {#2-dota-underlords}

### 2.1 Chronologie et chiffres

| Date | Événement | Chiffres |
|------|-----------|----------|
| Juin 2019 | Open beta | **+200 000 joueurs simultanés** en 2 jours (showmyitems.com, 2026) |
| Sept. 2019 | −75 % du pic | 3 mois après l'open beta (labs.invenglobal.com, 2019) |
| Janv. 2020 | −90 % | < 19 000 joueurs simultanés sur 30 j (gamepressure.com, 2020 ; PCGamer, 2020) |
| Fév. 2020 | Sortie de l'Early Access | Season 1 + City Crawl + Battle Pass 100 récompenses |
| Août 2020 | Dernier patch contenu | « The Update In Which Lifestealer Gets Even Angrier » |
| Déc. 2021 | Seul patch depuis 16 mois | Extension du Battle Pass jusqu'en **2031** — annulation silencieuse de Season 2 |
| 2024–2026 | Game zombie | 500–1 000 joueurs simultanés ; avis application iOS : 3,42/5, sentiment « Frustrated » (marlvel.ai, 2026) |

Source principale : showmyitems.com (2026) — « 97 % of the player base was gone by early 2021. »

**Le chiffre-clé** : −97 % en < 2 ans avec zéro annonce de la part de Valve. Ce n'est pas
un déclin organique — c'est un abandon structurel causé par la structure plate de Valve où «
people drift toward bigger projects » (r/underlords, cité par showmyitems.com, 2026).

### 2.2 Mécanismes clés

#### A. Système d'alliances

**Teardown.** Chaque héros appartient à 1 à 3 alliances (ex. Assassin, Warrior, Mage). Des
paliers d'activation déclenchent un bonus d'équipe. Exemple (source : esportstales.com, 2019) :

| Alliance | Palier 3 | Palier 6 |
|----------|----------|----------|
| Assassin | 15 % crit, 300 % dmg | 25 % crit, 400 % dmg |
| Warrior  | +7 armure équipe | +14 armure équipe |

En Season 1, ~20 alliances coexistaient. Le jeu proposait un roster d'environ 60 héros
répartis en Tier 1–5, chaque héros ayant 2–3 tags d'alliance.

**Maths du pool partagé** (source : esportstales.com oct. 2019 ; dotaunderlords.fandom.com) :

Pool par héros — valeurs finales (patch Apr. 2020) :
- Tier 1 : **30** copies par héros unique
- Tier 2 : **20** copies
- Tier 3 : **18** copies (était 15 avant juin 2020)
- Tier 4 : **12** copies
- Tier 5 : **10** copies

Odds par slot selon le niveau du joueur (patch Aug. 2019) :

| Niveau | T1 | T2 | T3 | T4 | T5 |
|--------|----|----|----|----|-----|
| 1      |100%| 0% | 0% | 0% | 0% |
| 4      | 50%| 35%| 15%| 0% | 0% |
| 7      | 25%| 30%| 35%| 10%| 0% |
| 9      | 20%| 25%| 30%| 20%| 3% |
| 11     | 15%| 20%| 25%| 30%| 10%|

Source : esportstales.com (2019). Le T5 à 10 copies totales implique qu'un seul joueur peut
monter un héros T5 en 3 étoiles (besoin de 9/10 copies).

**Psychologie.** L'alliance = la *promesse* d'un combo. L'activation au palier crée un
objectif local à court terme (« j'ai 5 Warriors, il m'en faut 1 de plus ») et un long terme
(« si je monte en T7, je peux activer Mage 6 »). C'est du *near-miss sous agence* : la
troisième copie manquante crée une tension résolvable par décision (reroll, achat, reposition).

**Problème psychologique identifié** : 20 alliances simultanées = espace de build trop grand
pour être mémorisé par des joueurs occasionnels. Gamedeveloper.com (2021) : « design flaws that
stopped it from becoming the new MOBA [...] haven't fixed the core issues of the original
game. » L'identité de build est diluée — trop d'options = paralysie analytique + sentiment de
subir le shop plutôt que de le construire.

#### B. Pool partagé et contestation

**Teardown.** Le pool est global. Si deux joueurs ciblent le même héros T4 (12 copies pour
8 joueurs), dès que 3 joueurs en veulent 3 copies chacun, le 4e joueur est bloqué.

**Maths de la contestation** (source : zhongjzsb.com, 2020) :

```
P_slot = p_tier × (x / (C_tier − o_tier))
P_shop  = 1 − (1 − P_slot)^5
```

Avec x = copies restantes, o_tier = copies déjà en jeu. À T4 (12 copies) : si 6 copies
sont en jeu, chaque slot T4 à niveau 8 a 15 % × (6/12) = 7,5 % de chance. La P_shop tombe
à ~33 % par reroll — soit 1 chance sur 3. Avec reroll à 2g et ~10g/round, ça épuise
rapidement le budget.

**Psychologie.** La contestation crée de la *frustration légitime* quand elle est invisible
(tu ne sais pas qui conteste). Underlords affichait le nombre de copies d'un héros en jeu,
mais tardivement et de façon peu visible. La frustration de « le RNG m'a niqué » éclipse
le plaisir du « j'ai trouvé ma 3e copie ».

**Verdict partiel (pertinent pour *The Pit*)** : The Pit n'a PAS de pool partagé en temps
réel (async snapshots = adversaires fantômes, pas en live). Ce problème de contestation est
**inexistant** pour nous. C'est un avantage structural fondamental : aucun joueur ne peut
vider notre pool à notre détriment pendant notre run.

#### C. Le mécanisme Jail (rotation quotidienne)

**Teardown.** Underlords retirait quotidiennement un sous-ensemble d'héros du pool disponible
(la « Jail »), créant un méta nouveau chaque 24h. Objectif : forcer la réévaluation des builds
et empêcher la fossilisation des compositions optimales.

**Psychologie.** La Jail exploite deux ressorts : (a) le *FOMO* (ce héros n'est pas en jail
aujourd'hui, mais demain il le sera) et (b) la *compétence évolutive* (le joueur qui lit la
Jail quotidienne mieux que les autres a un edge). Pepijn van Sinderen (2019) note :
« Jail keeps the daily meta game fresh for at least one game per day » mais aussi « I play
less in longer sessions (multiple games) and more frequently for a single game. »

**Problème** : la Jail favorise les joueurs les plus engagés (ceux qui consultent le méta
quotidien) et punit les joueurs casualisés qui se connectent sans l'avoir vérifiée.
Elle fragmente aussi la communauté entre « ceux qui connaissent la Jail du jour » et les
autres, ce qui nuit à l'équité perçue.

**Verdict (The Pit)** : le mécanisme Jail = **rotation de contenu pour compenser le manque de
nouveauté** — un placebo quand le jeu ne peut pas créer de nouveaux sets. Pour nous, c'est
hors-sujet : notre « fraîcheur » vient (a) des sigils mutables (5 formes topologiques) qui
créent un méta structurellement différent selon la forme dominante du moment, (b) des reliques
(offre 1-parmi-3, seedée) qui varient chaque run sans rotation forcée. Nous n'avons pas besoin
d'une Jail.

#### D. City Crawl et le manque de boucle

**Teardown.** City Crawl (Season 1) = carte solo de progression jalonnée de défis PvE (armées
thématiques prédéfinies) et PvP hybrides. Kotaku (2020) : « challenges are at their best when
they go for your brain's jugular and enforce strict limitations on your army. »

**Psychologie.** City Crawl offre de la *progression externalisée* — une carte à conquérir
donne un sentiment de progression cartographique séparé du classement. C'est efficace pour
l'onboarding et la rétention de joueurs qui ne veulent pas de ladder.

**Problème** : City Crawl était perçu comme un mode à part, déconnecté de la boucle ranked
principale. Il n'y a eu qu'une saison. Sa promesse (8 nouveaux Underlords, modes donjons
procéduraux, cinématiques Source Filmmaker) a été annulée sans annonce (showmyitems.com, 2026).
L'effet de déception est amplifié quand la promesse implicite est cassée.

**Verdict (The Pit)** : la *progression externalisée* (quelque chose à débloquer en dehors
du ladder) est une opportunité directe pour *The Pit*. Notre Grimoire (collection persistante
de reliques) remplit exactement cette fonction : méta-progression cross-run, déblocage de
connaissances, sentiment de progression cartographique dans l'obscurité du Puits. Le Grimoire
doit être rendu visible et satisfaisant — c'est notre City Crawl.

### 2.3 Compétitif et ranked

**Système Underlords** : ladder MMR standard avec tiers (Bronze/Silver/Gold/Platinum/Diamond/
Master). Pas de saisons avec réinitialisation notable. L'identité du mode ranked était floue :
le jeu ciblait PC **et** mobile simultanément, créant deux bases de joueurs aux sessions
incompatibles.

**Problème d'identité** (labs.invenglobal.com, 2019) : « From the moment it was created, Dota
Underlords has faced an identity crisis. It simply doesn't know whether it's a mobile game, or
a PC game. » Le board occupait visuellement 40 % de l'écran PC (trop petit pour le PC, trop
long pour le mobile). Les sessions duraient ~25–40 min — acceptable sur PC, bloquant sur
mobile.

**Absence de cadence saisonnière** : il n'y a eu qu'une Season 1 (jamais de Season 2).
La TFT en est aujourd'hui au Set 14+. La cadence est le moteur principal du « one more run »
compétitif : chaque nouveau set réinitialise partiellement le MMR, supprime les compositions
dominantes et instaure une période de découverte. Underlords n'avait pas ça.

**Verdict (The Pit)** : point crucial — notre « saison » naturelle est le **run** lui-même
(10 victoires / 5 défaites). Chaque run est une micro-saison. Mais à l'échelle macro, nous
avons besoin d'un équivalent de « nouveau set » : le changement de sigil actif par la méta
communautaire ou une rotation légère du pool de reliques disponibles suffirait à simuler cet
effet sans développement lourd.

### 2.4 Psychologie : ce qui hookait, ce qui a craqué

**Ce qui hookait (universellement valide)** :
- Le near-miss sous agence : la 3e copie qui manque = tension supportable car résolvable.
- Le puzzle d'activation d'alliance : objectif local clair, feedback immédiat.
- La lisibilité des combats courts (< 30 secondes de simulation visuelle).
- La progression de niveau comme révélateur de nouvelles options.

**Ce qui a craqué (spécifique au contexte 8-joueurs-live)** :
- La contestation du pool en temps réel : la frustration est attribuée au hasard, pas aux
  décisions adverses (« le jeu m'a niqué » au lieu de « l'autre m'a outplayed »).
- L'identité de build diluée par 20+ alliances : pas de moment « aha, c'est mon archétype ».
- L'absence de cadence saisonnière : pas de raison externe de revenir.
- La dépendance à Valve pour le contenu : quand le robinet s'est fermé, il ne restait rien.

**Leçon fondamentale** : un jeu compétitif async sans cadence saisonnière et sans progression
méta visible meurt lentement. Il peut avoir 15 000 joueurs actifs et « Valve left them without
saying a word » (Steam Community, 2025). La taille de la communauté ne suffit pas : l'engagement
a besoin d'une *raison de revenir demain* autre que « c'est un bon jeu ».

### 2.5 Verdicts de transférabilité vers *The Pit*

| Mécanisme Underlords | Survit aux contraintes de *The Pit* ? | Adaptation ou remplacement |
|----------------------|--------------------------------------|---------------------------|
| Pool partagé + contestation live | **Non** — nous sommes async, pas de live 8-joueurs | Notre async supprime ce problème. Bonus : aucun joueur ne peut « voler » nos unités. |
| Odds par niveau (T1→T5) | **Oui — déjà fait** | Nos cotes `ODDS_TABLE` sont calquées sur ce modèle (00-state.md §4.3). Les valeurs [PH] doivent être tuned via `tools/sim.lua`. |
| Alliance = paliers d'activation | **Oui, partiellement** — mais attention à la dilution | Notre système d'adjacence positionelle (pas de comptage de type) est plus lisible. Les synergies par TYPE (still TODO) doivent être introduites prudemment : max 6–8 types actifs simultanément, seuils 2/4, jamais 6+ (trop de complexité). |
| Jail (rotation quotidienne) | **Non** — placebo de fraîcheur | Nos sigils mutables + reliques seedées créent la fraîcheur sans rotation forcée. |
| City Crawl (PvE saisonnier) | **Oui, partiellement** | Notre Grimoire = notre City Crawl. Il doit afficher une progression visible (X reliques identifiées / 21, bestiaire complété). |
| Ladder MMR | **Oui** — mais à adapter à l'async | MMR basé sur le ratio vic/def des snapshots servis, pas sur un classement live. Format de saisons = rotation de pool de reliques disponibles. |
| Cadence saisonnière | **Indispensable** | Sans Season 2, Underlords est mort. Nos « saisons » = runs individuels + rotations périodiques de pool reliques G (sigils, différé). |

**Analogie paresseuse à démonter** : « Underlords avait des alliances à paliers, copions les
synergies de type. » Non. La raison pour laquelle les alliances hookaient n'était pas leur
*existence* mais leur *lisibilité locale* : un objectif clair (3 copies = bonus). Notre
équivalent n'est pas de compter des types : c'est de rendre l'ajout d'une unité adjacent
immédiatement visible (+X % de synergie surlignée). Le mécanisme psychologique à préserver
est le near-miss-sous-agence, pas la mécanique de comptage elle-même.

---

## 3. Storybook Brawl — le naufrage FTX {#3-storybook-brawl}

### 3.1 Chronologie et chiffres

| Date | Événement | Chiffres |
|------|-----------|----------|
| 2020 | Fondation Good Luck Games | Équipe de vétérans MTG/Hearthstone |
| Juin 2021 | Lancement Steam Early Access F2P | Reviews positives |
| Sept. 2021 | Pic de joueurs | ~3 000 joueurs simultanés |
| Mars 2022 | Acquisition par FTX US | $25M ; annonce de blockchain/NFT optionnels |
| 22 mars 2022 | Review bomb immédiate | 600/761 reviews négatives en quelques heures (cointelegraph.com, 2022) |
| Nov. 2022 | Effondrement FTX | Email interne : « game makes very little revenue ($200k total) » |
| 1er mai 2023 | Fermeture serveurs | — |
| 2025+ | Fantômes | Une FTX lawsuit contre les devs ; jeux successeurs (Fairytale Fables, Once Upon a Galaxy) |

Source principale : summitreviews.biz (2025) — analyse éditoriale exhaustive.
Source Bloomberg Law (2023) : confirmation de la fermeture.

**Chiffre le plus brutal** : $200k de revenus totaux pour un jeu acquis $25M. Ratio 125:1.
La communauté était réelle et engagée ; le modèle de revenus était structurellement incapable
de la monétiser.

### 3.2 Mécanismes clés

#### A. Deux rangées (front/back)

**Teardown.** SBB place 7 unités sur un plateau en deux rangées (avant/arrière). Les unités
à l'avant frappent en priorité. La position dans la rangée détermine l'ordre d'attaque (gauche
en premier). Résultat : front = réservé aux tanks/unités durables, back = porteurs/soutiens.
(Source : hsreplay.net, 2022 — « during a battle, your left-most unit will strike first and
will only strike again once all the others have done so as well ».)

**Maths.** 7 slots en 2 rangées → 35 permutations de rangée possibles (sans l'ordre interne),
vs 5! = 120 dans une ligne simple. L'espace de placement est significativement réduit par la
structure front/back, rendant chaque décision plus impactante.

**Psychologie.** La dichotomie front/back est immédiatement lisible même sans lire les règles :
les unités énormes vont devant, les petites derrière. C'est une *affordance visuelle* — le
jeu communique sa règle à travers l'apparence des cartes. Résultat : l'onboarding est accéléré
sans sacrifier la profondeur (car les synergies récompensent les choix de placement précis).

**Verdict (The Pit)** : **déjà implémenté et amélioré**. Notre `depth = maxCol - cell.x`
(front/back dérivé de la forme du sigil) est mécaniquement supérieur à SBB : l'exposition
est portée par la *topologie* du sigil, pas par une règle fixe. Changer de sigil change le
profil front/back sans changer de règle. C'est plus profond que la dichotomie SBB.

**Mise en garde** : SBB avait 7 slots, nous en avons 9. La lisibilité visuelle du front/back
doit être compensée par notre UI (surligner la colonne la plus exposée selon le sigil actif).

#### B. Trésors (récompense du triple)

**Teardown.** Dans SBB, tripler une unité ne donne pas une unité de tier supérieur
(contrairement à HS:BG) mais **1 Trésor choisi parmi 3**, au même tier que l'unité triplée.
Le joueur peut avoir maximum 3 Trésors en simultané. Passer → +2 or.
(Source : hsreplay.net, 2022.)

**Psychologie.** Le Trésor est un *build-definer dérivé de l'investissement*. Il est déclenché
par une action à forte friction (tripler = acheter 3 copies d'une même unité) et récompense
par un choix stratégique (parmi 3 options, une s'adapte à mon build actuel). C'est de la
*maîtrise incrémentale* : le joueur construit sa compréhension du méta en testant quels Trésors
synergisent avec quelles compositions. Le cap à 3 Trésors crée une tension de remplacement
(« dois-je sacrifier ce Trésor existant pour ce nouveau ? »).

**Maths.** Avec 7 tiers d'unités et ~3 Trésors/tier, le pool de Trésors est ~21 Trésors
distincts. Chaque triple ouvre 3 options → 1 sur ~7 options pertinentes pour le build. La
distribution n'était pas publiée officiellement mais les guides communautaires (hsreplay.net,
oct. 2022) indiquent que les Trésors de tier 5+ sont les plus décisifs (« try to triple the
highest tiered units, as those will reward you with the best treasures in the game »).

**Verdict (The Pit)** : **directement analogue à nos reliques, avec des différences importantes**.

*Analogie valide* : le Trésor = récompense d'investissement d'effort (triple) → relique en
The Pit = récompense tous les 3 combats. Le mécanisme psychologique est identique : agence dans
le choix + build-definition.

*Différence critique* : SBB donne le Trésor automatiquement au triple, The Pit offre une
relique tous les 3 combats (victoire OU défaite), indépendamment des triples. Notre modèle est
**moins contingent à l'action en cours** et plus régulier, ce qui réduit la variance de
l'expérience.

*À adapter* : SBB prouvait que le choix parmi 3 est la bonne granularité (ni trop peu, ni
trop). Notre « 1-parmi-3 » est validé par ce précédent. L'UI doit rendre les 3 options
également tentantes pour générer la tension de choix.

#### C. Sorts (one-per-turn)

**Teardown.** Chaque round, la boutique inclut un sort achetable, limité à **1 sort par tour**.
Les sorts ont des effets variés (buff permanent, buff pour le prochain combat, XP bonus, or).
Leur rôle monte en importance quand le plateau est rempli (les unités ne sont plus utiles mais
les sorts le sont encore). (Source : hsreplay.net, 2022.)

**Psychologie.** Les sorts créent un *axe de décision supplémentaire* sans élargir le plateau.
La contrainte « 1/tour » est fondamentale : elle force une priorisation (sort vs unité vs
reroll) et donne de la valeur à chaque or. Sans cette contrainte, les sorts seraient achetés
mécaniquement.

**Verdict (The Pit)** : pas d'équivalent direct. Notre boutique vend des unités (pas de sorts
distincts). **Ce mécanisme n'est pas transférable directement** car il implique un pool de sorts
séparé — coût de design non justifié par le gain. En revanche, le *principe* d'un achat
one-per-turn à effet variable est ce que nos reliques font partiellement (offre 1/3 combats).

#### D. Montée de palier automatique

**Teardown.** Dans SBB, le joueur gagne **1 XP automatiquement par tour** et monte de palier
tous les 3 XP — sans pouvoir s'arrêter à un palier comme dans HS:BG. Le niveau est forcé.
(Source : hsreplay.net, 2022 — « You cannot stay at a specific Tier like Battlegrounds allows. »)

**Psychologie.** La montée automatique est une *boussole de progression visible* : le joueur
sait toujours où il est dans la partie. Elle retire la décision de « vais-je investir en XP
ou en reroll ? » — ce qui *simplifie* le jeu mais réduit aussi un axe de profondeur.

**Verdict (The Pit)** : **choix opposé, délibéré, et plus profond**. Notre XP est partiellement
passive (+1/round dès round 2) ET achetable (`BUY_XP_COST = 4`, ratio 1:1). Ce modèle hybride
TFT conserve la décision d'accélération (« investis-je 4g en XP ou en reroll ? ») qui est
absente de SBB. La décision d'économie de type est un axe de compétence qui discrimine les
bons joueurs — nous avons raison de le garder.

**Mise en garde** : la montée automatique de SBB montrait qu'une progression XP lisible est
importante psychologiquement. Notre UI XP doit être explicitement visible et compréhensible
dès le premier run.

### 3.3 Modèle économique et mort financière

**Le paradoxe SBB** : le jeu avait un modèle F2P sain (cosmétiques + déblocage héros à $1–5
l'unité, cap $30 total), mais ce cap a rendu la monétisation whale structurellement impossible.
Les whales ne peuvent pas dépenser $1000 dans SBB. (summitreviews.biz, 2025 : « the amount
that could be spent on the game was capped at $30. »)

**L'acqui-hire FTX** : Good Luck Games vendu $25M à FTX en mars 2022. Motivations officielles :
explorer blockchain/NFT. Motivations réelles : les devs n'avaient pas d'autre option — le jeu
rapportait $200k total sur 2 ans. La review bomb (600/761 avis négatifs en quelques heures,
cointelegraph.com, 2022) a tué la croissance de joueurs au moment de l'annonce. FTX a coulé
en novembre 2022 et le jeu a fermé en mai 2023.

**Ce que ça enseigne pour *The Pit*** :
- Le modèle F2P pur sans whale est viable pour un solo dev seulement si le coût de maintenance
  est quasi nul. Le coût de serveurs live (8 joueurs simultanés) est beaucoup plus élevé que
  des snapshots statiques servis par fichier.
- **Notre async par snapshots est économiquement supérieur à SBB** : pas de serveur de jeu en
  temps réel à faire tourner, pas de coût variable à l'usage — juste du stockage.
- La dépendance à un financeur externe unique (crypto, investisseur unique) est un risque
  de mort instantanée. Nous sommes solo dev sans dépendances externes — ce n'est pas un
  handicap, c'est une protection.

### 3.4 Psychologie : communauté, curation, confiance

**Ce qui hookait** (summitreviews.biz, 2025) :
- L'accessibilité thématique (fées et princesses → l'obscurité se cache derrière une
  esthétique lumineuse, comme les synergies derrière la simplicité apparente).
- La randomité équilibrée : les compositions dominantes existaient mais n'étaient jamais
  garanties — le hasard du tirage forçait la créativité.
- Une communauté active (Discord en ébullition, streamers, analysts).

**Ce qui a tué** : la trahison de la confiance. La review bomb du 22 mars 2022 est la
démonstration la plus claire disponible dans l'industrie d'un axiome : **une communauté F2P est
une communauté de foi, pas de contrat**. Les joueurs avaient investi leur temps (130h+ pour
certains), et l'annonce de blockchain/NFT était perçue comme une trahison de l'identité du jeu.

**Pour *The Pit*** : notre communauté est, pour l'instant, embryonnaire (solo dev). Mais la
leçon est absolue : **ne jamais introduire de mécanisme monétaire ou technique incompatible
avec les piliers définis en public**. Si nous définissons « pixel art procédural, async, pas de
live » — ne jamais introduire de live. Si nous définissons « grimdark » — ne jamais pivoter
vers un habillage kawaii pour toucher un autre public. La cohérence du pacte avec les joueurs
est non négociable.

### 3.5 Verdicts de transférabilité vers *The Pit*

| Mécanisme SBB | Survit aux contraintes de *The Pit* ? | Adaptation |
|---------------|--------------------------------------|-----------|
| 2 rangées front/back | **Oui — déjà fait, version supérieure** | Notre `depth` dérivé du sigil > dichotomie fixe SBB. Surligner visuellement la colonne front. |
| Trésors (1/triple, choix parmi 3) | **Oui — le mécanisme psychologique** | Notre « 1-parmi-3 reliques / 3 combats » répond au même besoin. Valider que les 3 options sont également tentantes. |
| Sorts one-per-turn | **Non — coût design > gain** | Le principe (décision supplémentaire par round) est absorbé par nos reliques de boutique (runOp : carrion_ledger, black_summons, beggars_lantern). |
| Montée auto de palier | **Non — nous gardons le choix** | Notre XP hybride (passive + achetable) est délibérément plus profond que la montée forcée de SBB. |
| Modèle F2P cosmétiques | **Partiellement** | L'async élimine les coûts serveur live. Notre cosmétique naturel = variations de la génération procédurale (skins de créature via seed différente). |
| Communauté de foi = pilier | **Oui — absolument** | Ne jamais trahir les piliers définis. La consistance thématique grimdark est un engagement, pas une option. |

---

## 4. Artifact — l'overkill de complexité {#4-artifact}

### 4.1 Chronologie et chiffres

| Date | Événement | Chiffres |
|------|-----------|----------|
| Nov. 2018 | Lancement ($20 buy-in + marketplace) | Pic ~60 000 joueurs simultanés |
| 3 sem. après lancement | Début de la chute | Passé sous les 20 000 |
| Mars 2019 | Update « Build Your Legend » (packs gratuits via XP) | Insuffisant |
| Été 2019 | Valve : rework complet, arrêt des updates | Max concurrent : quelques centaines |
| 2019 | Steam reviews | < 50 % positives, récentes « mostly negative » (gamedeveloper.com, 2019) |
| 2020 | Artifact 2.0 bêta fermée | Accès limité, sans succès |
| 2021 | Richard Garfield confirme le divorce avec Valve | Win.gg interview |
| 2026 | Max concurrent | < 200 joueurs (gamedeveloper.com, 2019 — « hundreds ») |

Source : gamedeveloper.com (2019) — analyse de design de 40 min-read, la plus complète disponible.
Source : kotaku.com (2019), win.gg (2019) — interviews Garfield/Elias.

**Chiffre-clé** : passé de ~60 000 joueurs à quelques centaines en 3 mois. Aucun autre échec
dans cette liste n'a une vitesse de chute aussi brutale.

### 4.2 Mécanismes clés

#### A. Les trois lanes

**Teardown.** Artifact = un jeu de cartes Dota 2 à **trois lanes simultanées**, chacune avec
sa propre tour (PV), sa propre main d'or, et ses propres héros. Le joueur joue des cartes dans
une lane, puis l'autre, puis l'autre (round-robin). L'objectif est de détruire 2 tours adverses
ou l'Ancienne (exposée après la première tour tombée). (Source : polygon.com, 2018.)

**Psychologie.** Les 3 lanes sont censées créer de la *profondeur stratégique par multifront* :
gérer plusieurs théâtres d'opération simultanément. C'est le niveau d'abstraction du jeu de go
en cartes, pas du poker. Le problème : chaque lane a sa propre main d'or (pas une globale).
Résultat : on a des cartes dans la main de la lane A qui auraient été parfaites pour la lane C,
sans pouvoir les transférer. Ce RNG localisé crée de la **frustration opaque** — le joueur ne
sait pas si sa défaite vient de sa stratégie ou de la distribution aléatoire des cartes dans
les lanes.

**Verdict (The Pit)** : **ne pas appliquer à *The Pit* sous aucune forme**. Le mécanisme
de multi-front avec information fragmentée par zone est structurellement incompatible avec
l'autobattler parce qu'il *empêche la vision d'ensemble* pendant la phase de build. Notre
plateau 3×3 + un sigil = une seule arène, toute l'information visible = lisibilité totale
pendant la construction. C'est exactement l'opposé d'Artifact.

#### B. Déploiement de héros et initiative

**Teardown.** Au début de chaque round, 1–3 héros Dota arrivent en renfort aléatoirement dans
une lane. L'assignation de la lane est **aléatoire** (non contrôlée par le joueur). L'initiative
(qui agit en premier dans chaque lane) change de lane en lane selon des règles complexes.

**Maths de l'aléatoire de déploiement.** Avec 3 lanes et 3 héros à déployer, le nombre de
distributions possibles est 3^3 = 27 sans contrainte. L'expérience rapportée dans les analyses
(gamedeveloper.com, 2019 ; lesswrong.com, 2019) est qu'un héros mal déployé dans une lane
faible = perte de cette lane sans possibilité de récupération dans les 5–7 premiers tours.

**Psychologie.** Le déploiement aléatoire est le mécanisme le plus cité comme source de
frustration (lesswrong.com, 2019 — Zvi : « I put this before the important real flaws in [the
design] »). La frustration est *non-agentielle* : le joueur ne peut rien faire contre un mauvais
déploiement. Contrairement au pool partagé d'Underlords (où la contestation est visible),
le déploiement de héros est invisible au moment de la décision.

**Verdict (The Pit)** : **leçon directement applicable**. Notre combat est **100 % déterministe**
(décision §6 du projet) : ciblage colonne → taunt → aggro → tie-break haut→bas. Aucune
décision de combat n'est aléatoire. Quand un joueur perd, il peut rejouer le combat et voir
exactement ce qui s'est passé. C'est la réponse architecturale directe à l'erreur d'Artifact.
Le golden-log (`golden.lua:17`) garantit cette propriété.

#### C. L'économie d'or par lane

**Teardown.** Chaque lane a un **pool d'or séparé** pour acheter des items. Des créeps (tours
de PNJ) donnent de l'or à la lane qui les tue — pas globalement. Résultat : l'or peut s'accumuler
dans une lane au détriment d'une autre.

**Problème design** (gamedeveloper.com, 2019) : « Midrange items in Artifact are almost
entirely useless. » Le jeu était trop court (5–7 tours en draft) pour amortir les achats lents.
Les items de départ (3 or, +3 HP) dominent sur les items midrange (7 or, +8 HP) car la partie
est finie avant que le retour sur investissement se matérialise. C'est une *dissonance de
temporalité* entre la courbe d'escalade promise et la durée réelle.

**Verdict (The Pit)** : notre économie par run ne souffre pas de ce problème — le run dure
jusqu'à 10 victoires et les unités persistent entre les rounds. Le problème de temporalité
d'Artifact était lié à la durée d'une *partie individuelle* (5–7 tours). Notre durée de
combat (~17s de fatigue max, `FATIGUE_START=1020`) est calibrée — ni trop courte (pas de
« je n'ai pas eu le temps d'agir »), ni infinie.

#### D. La frustration du « je ne sais pas pourquoi j'ai perdu »

**Teardown.** Ce problème est le plus souvent cité dans les analyses des déserteurs, y compris
de joueurs professionnels (lesswrong.com, 2019 — Zvi cite 4 joueurs pro MTG qui ont abandonné
Artifact parce qu'il était « too complicated »).

**Psychologie.** L'apprentissage par feedback négatif nécessite que la cause de l'échec soit
visible et attribuable à une décision. Si je perds à TFT, je peux identifier : « je n'ai pas
2-star mon carry assez vite » ou « j'ai été contested ». Si je perds à Artifact, la cause peut
être : mauvais déploiement de héros, mauvaise lane de carte, initiative désavantageuse,
modification de hero qui n'a pas eu le temps de payer — tout en même temps.

Citation directe de Garfield (kotaku.com, 2019) : « My perspective was that there were three
problems — the revenue model was poorly received, there weren't enough community tools and
short-term goals in place online like achievements or missions, and, perhaps because of these
things, there was a rating bombing. »

À noter que Garfield lui-même ne liste **pas** la complexité comme cause principale — mais
Zvi (lesswrong.com, 2019) et gamedeveloper.com (2019) la mettent en tête. Ce désaccord
entre le designer et les analystes externes est instructif : le designer voit l'élégance,
les joueurs voient l'opacité.

**Verdict (The Pit)** : notre combat est lisible grâce à :
- La chronologie d'événements émise par le bus (`bus.lua`) : chaque événement est horodaté.
- L'affichage en `arena_draw.lua` des animations par entité.
- Le journal de combat visible (inspiration Backpack Battles, déjà mentionné dans gd-research-result.md).
- Le déterminisme : rejouer le même combat avec le même seed = résultat identique = debug possible.

**Ce qui manque encore** : un écran de résultat post-combat qui explique *pourquoi* le joueur
a perdu (unité ennemie clé, synergie adverse dominante, relique adverse). C'est une dette UX
à traiter.

### 4.3 Monétisation quadruple

**Teardown.** Artifact avait 4 modèles de monétisation simultanément (gamedeveloper.com, 2019 ;
techraptor.net, 2019) :
1. Buy-in $20
2. Packs de cartes payants
3. Commission sur chaque transaction de la marketplace de cartes
4. Entrée payante pour les modes compétitifs avancés

**Psychologie.** La monétisation quadruple déclenche ce que lesswrong.com (2019) appelle la
*signalisation hostile* : même si chaque mécanisme est individuellement défendable (Garfield
disait « ce n'est pas pay-to-win »), leur coexistence signale au joueur que le jeu veut
maximiser l'extraction à chaque point de contact. La perception de « on essaie de me piquer
mon argent à chaque étape » est suffisante pour déclencher l'abandon, même si la réalité est
différente.

Extrait (win.gg, 2019 — interview Garfield) : « You can test the gameplay, but you can't
really test how the revenue model will be taken, how the social structures will form, how media
will pick it [up]. »

**Verdict (The Pit)** : notre modèle n'est pas encore défini mais les enseignements sont clairs :
- Un seul mécanisme de monétisation, lisible, visible dès le départ.
- Jamais de pay-to-win perçu (aucun avantage de gameplay acheté).
- La gratuité d'accès au contenu core est non négociable pour les autobattlers compétitifs.
- Le modèle cosmétique (skins procéduraux via seed alternatif) ou le modèle battle-pass
  (contenu temporel, pas de puissance) sont les seules options compatibles avec nos piliers.

### 4.4 Psychologie : frustration opaque, absence de feedback

**Ce qui hookait (pour les bons joueurs)** :
- La profondeur stratégique du multifront pour les joueurs qui peuvent mémoriser 3 états
  simultanés.
- L'identité de deckbuilding Dota (thème reconnaissable pour une base existante).
- La production value (animations, UI soignée — polygon.com, 2018 : « lively animations and
  effects for each card played »).

**Ce qui a tué** :
- L'absence de boucle de compétence accessible : le jeu était « brilliant for the right
  players » (lesswrong.com, 2019) mais le « right player » représentait 0,1 % du marché
  visé.
- Pas de mode gratuit, pas de progression sans achat.
- Pas de short-term goals (aucun dailies, aucune mission, aucune récompense de connexion).

**Pour *The Pit*** : notre Grimoire est notre boucle de short-term goals — chaque run non
seulement progresse vers 10 victoires mais potentiellement identifie une nouvelle relique.
C'est de la *progression à deux vitesses* (run court + méta-progression longue), le pattern
exact qui manquait à Artifact.

### 4.5 Verdicts de transférabilité vers *The Pit*

| Mécanisme Artifact | Survit aux contraintes de *The Pit* ? | Verdict |
|--------------------|--------------------------------------|---------|
| 3 lanes simultanées | **Jamais** | Incompatible avec la lisibilité et l'async. Notre 3×3 = une seule arène lisible. |
| Déploiement héros aléatoire | **Jamais** | Notre placement est totalement agentiel (drag-drop en phase build). |
| Or fragmenté par zone | **Non** | Notre économie est unifiée (10g/round, simple). |
| Buy-in payant | **Jamais pour un autobattler** | L'accessibilité est la condition de la communauté nécessaire. |
| Monétisation quadruple | **Jamais** | Signal hostile. Un seul mécanisme visible. |
| Production value soignée | **Oui — à notre échelle** | Notre DA grimdark procédural est notre équivalent. La cohérence > le budget. |
| Short-term goals manquants | **Leçon directe** | Grimoire + progression visible = daily hook naturel. |
| Opacité des causes de défaite | **Anti-pattern** | Notre bus d'événements + déterminisme permettent un post-combat lisible. À implémenter. |

---

## 5. Synthèse transversale — les 9 lois de la mort {#5-synthese}

Ces 9 patterns sont vérifiables sur au moins 2 des 3 postmortems.

### Loi 1 : L'abandon éditorial est une mort certaine

Underlords (Valve) et Artifact (Valve) ont tous deux été abandonnés silencieusement par la
même entreprise, pour la même raison : la structure plate de Valve permet aux équipes de se
disperser sans décision formelle. SBB a été tué par la mort de son financeur externe.

**Invariant pour *The Pit*** : l'avantage du solo dev est la cohérence décisionnelle. La
feuille de route est dans ce dossier et dans CLAUDE.md — elle ne disparaît pas quand un
employé quitte le projet. Le risque est de l'ordre opposé : la *frustration solitaire* qui
décourage. La réponse est une feuille de route courte et atteignable (jalons `v0.X`), pas une
vision à 5 ans.

### Loi 2 : La contestation RNG en temps réel est le nœud de frustration majeur

Underlords : pool partagé visible mais non actionnable.
Artifact : déploiement de héros aléatoire.
SBB : randomité du draft + distribution des trésors.

Les trois jeux avaient du RNG qui *précédait* la décision du joueur, rendant les résultats
non-attribuables. La clé psychologique est : le RNG est toléré quand il *précède* la phase de
build (shop) et que le *résultat* du build (combat) est déterministe. La formule est :
**variance en entrée + déterminisme en sortie = frustration évitable**.

**The Pit** applique déjà cette formule :
- Entrée variable : boutique aléatoire (seedée, donc reproductible mais surprise).
- Sortie déterministe : combat golden-safe, même seed = même résultat.

### Loi 3 : La complexité doit être progressive, jamais frontale

Artifact a tué son onboarding avec 3 lanes + or par lane + initiative + modifications dès le
premier tour. Underlords a eu ~20 alliances simultanées dès le départ.

**The Pit** progressivement :
- Démarrage : 3 slots + boutique 5 unités = ~5 unités visibles.
- Progression : slots débloqués (3→9) via leveling.
- Fin de run : 9 slots + sigil complexe + reliques actives.

La complexité est révélée au rythme de l'apprentissage. C'est exact.

### Loi 4 : Sans cadence saisonnière, pas de raison de revenir

Underlords : une seule saison. Artifact : pas de saison. SBB : pas de saison (Early Access
perpétuel). TFT, qui a survécu, est au Set 14+.

La cadence saisonnière n'est pas du contenu pour le contenu — c'est la *raison externe de
revenir*. Elle réinitialise partiellement le MMR (permettant à tout le monde de « recommencer »),
introduit de nouveaux archetypes, et crée un sentiment de narration temporelle (« je jouais
en Set 7, c'est là que j'ai appris à 3-star »).

**Adaptation pour *The Pit*** : notre « saison » naturelle est le run (10 victoires) — c'est
une micro-saison individuelle. Mais à l'échelle communautaire, nous avons besoin d'un
équivalent de set rotation : une **rotation du pool de reliques G (sigils)** constituerait
cela. Elle introduit un nouveau topologie sans changer les règles, crée un méta temporaire,
et donne une raison de revenir après une pause.

### Loi 5 : La monétisation perçue comme extraction = mort de l'onboarding

Artifact ($20 + packs + commission + entrée tournoi). La perception importe plus que la réalité
mathématique (Garfield l'a lui-même admis).

**Pour *The Pit*** : le seul modèle viable est celui où le joueur peut profiter du jeu *core*
sans jamais payer, et où ce qui est payant est clairement *additionnel et cosmétique*. La
progression Grimoire (méta-connaissance) doit rester entièrement gratuite.

### Loi 6 : La lisibilité du « pourquoi j'ai perdu » est fondamentale

Les trois jeux avaient des causes de défaite opaques (multi-front Artifact, RNG Underlords,
RNG SBB). TFT a survécu en partie parce que les replays post-match ont été ajoutés rapidement.

**Pour *The Pit*** : l'écran post-combat doit montrer la différence de puissance (unité la plus
forte adverse, affinité/synergie dominante, relique adverse décisive). C'est à implémenter.

### Loi 7 : L'identité de plateforme doit être unique

Underlords a tenté d'être simultanément un jeu PC et mobile — aucun des deux n'était optimal.
SBB était PC only (avantage). Artifact était PC only mais avec des sessions trop longues (1h+
en tournament).

**Pour *The Pit*** : LÖVE2D est naturellement desktop. Nos sessions de run visent 15–25 min
(10 combats × ~1,5 min/combat + phases build). C'est la durée mobile-tolérable mais
desktop-optimale. Ne pas tenter le port mobile avant que le core soit solide.

### Loi 8 : La communauté F2P est une communauté de confiance contractuelle

SBB : la review bomb du 22 mars 2022 (600/761 négatifs en quelques heures) prouve qu'une
communauté engagée peut se retourner instantanément si elle perçoit une trahison du contrat
implicite.

**Pour *The Pit*** : nos piliers définis publiquement (async, grimdark, procédural) sont des
engagements, pas des options. Changer l'un d'eux sans que la communauté l'accepte serait une
trahison équivalente.

### Loi 9 : La dépendance à une ressource externe unique est suicidaire

Underlords dépendait de Valve pour le contenu. SBB dépendait de FTX pour le financement.
Artifact dépendait de Valve pour l'itération.

**Pour *The Pit*** : notre dépendance externe principale est LÖVE2D — un moteur open source
stable. Notre progression ne dépend que d'un seul dev. C'est un risque de type différent
(burnout solo) mais pas une dépendance externe incontrôlable.

---

## 6. Anti-patterns à ne PAS copier dans *The Pit* {#6-antipatterns}

Ces anti-patterns sont identifiés comme causes directes de mort ou d'échec. Aucun ne doit
être reproduit.

| Anti-pattern | Source | Pourquoi ne pas copier |
|--------------|--------|----------------------|
| Alliances > 8 types actifs simultanément | Underlords (20+ alliances) | Dilution de l'identité de build. Max 6–8 types actifs. |
| Pool partagé en temps réel (8 joueurs) | Underlords | Contestation source de frustration non-agentielle. Notre async l'élimine. |
| RNG de combat non-attribuable | Artifact (déploiement) + SBB | Incompatible avec notre déterminisme. Ne jamais ajouter de `math.random` en SIM. |
| Complexité frontale au premier tour | Artifact (3 lanes dès T1) | Notre progression 3→9 slots est la réponse correcte. |
| Sessions > 45 min | Artifact | Nos combats (~17s) + build phase (2–3 min) visent 15–25 min/run. |
| Monétisation perçue comme extraction | Artifact ($20 + packs + commission) | Un seul mécanisme, cosmétique, clairement séparé du gameplay. |
| Absence de short-term goals | Artifact | Notre Grimoire = daily hook naturel. |
| Dépendance à un seul financeur/éditeur | SBB (FTX) | Modèle financier auto-suffisant ou indépendant. |
| Trahison des piliers fondateurs | SBB (blockchain/NFT) | Nos piliers (async, grimdark, procédural) sont des engagements contractuels. |
| Absence de cadence saisonnière | Underlords, Artifact, SBB | Rotation de pool reliques G = notre équivalent de set rotation. |
| Opacité du post-combat | Les 3 jeux | Post-combat lisible = écran de résultat avec attribution causale. |
| Identité de plateforme duale | Underlords (PC + mobile) | Desktop-first avec sessions 15–25 min. |

---

## 7. Opportunités positives extraites des ruines {#7-opportunites}

Ces mécanismes ont *fonctionné* dans les jeux concernés même s'ils ne les ont pas sauvés.
Leur succès est attribuable à un mécanisme psychologique réel.

### O1. Build-definer via récompense d'investissement (SBB — Trésors)

**Le mécanisme qui marche** : tripler une unité (effort notable) donne un Trésor (reward
surprise parmi 3). L'agence du choix + la surprise de l'offre = tension de décision maximale.

**Adaptation *The Pit*** : notre « 1-parmi-3 reliques / 3 combats » répond exactement à ce
mécanisme. **À améliorer** : l'UI des 3 candidats doit rendre la tension de choix palpable —
chaque option doit sembler « trop bien pour être refusée » pour créer un vrai dilemme.

### O2. Progression externalisée visible (Underlords — City Crawl)

**Le mécanisme qui marche** : une carte à conquérir donne un objectif visible orthogonal
au classement. Les joueurs non-compétitifs s'y attachent ; les joueurs compétitifs la
traversent pour débloquer des récompenses.

**Adaptation *The Pit*** : notre Grimoire est ce mécanisme. **À améliorer** : l'écran Grimoire
(prévu dans `scenes/gallery` ou dédié) doit être spectaculaire — pas un simple inventaire.
La progression (X/21 reliques identifiées, Y/83 créatures observées) doit être visible dès
l'écran d'accueil ou de résultat de run.

### O3. Jail comme anti-stagnation meta (Underlords — mécanisme Jail)

**Le mécanisme qui marche** : forcer une réévaluation quotidienne du méta empêche la
fossilisation des compositions. Les joueurs engagés y voient un avantage cognitif.

**Adaptation *The Pit*** : notre équivalent naturel est le **sigil actif** par run (différent
à chaque run, selon la seed). Le sigil change la topologie = méta différent sans
rotation forcée. **À l'étude** : une rotation périodique des reliques G (sigils) disponibles
dans le pool serait l'équivalent exact de la Jail — à introduire quand les reliques G
seront implémentées.

### O4. Lisibilité du front/back comme affordance (SBB — 2 rangées)

**Le mécanisme qui marche** : l'apparence visuelle des unités (grande/petite, tankée/fragile)
communique leur placement optimal sans explication. L'onboarding est accéléré.

**Adaptation *The Pit*** : nos créatures générées procéduralement ont une *morphologie de
famille* (16 archétypes). La forme doit signaler le rôle : les tanks `gravewarden`-style
doivent être visuellement massifs, les carries fragiles. Le rendu procédural doit transmettre
cette hiérarchie. C'est une priorité pour la passe de DA des créatures.

### O5. Near-miss sous agence comme moteur d'engagement (Underlords — 3e copie)

**Le mécanisme qui marche** : la 3e copie manquante = tension maximale résolvable par décision.
Ce near-miss est supportable parce qu'il y a une action disponible (reroll, acheter, attendre).

**Adaptation *The Pit*** : notre système de duplicatas (3 copies → niveau, cascade) répond
exactement à ce mécanisme. **À améliorer** : le UI des pips dorés (déjà présents) doit être
extrêmement visible. La transition 2→3 copies doit être un moment de jeu célébré (animation,
son).

---

## 8. Index des sources {#8-sources}

Chaque affirmation factuelle ou chiffrée de ce document est couverte par au moins une des
sources suivantes.

| # | Source | URL | Usage principal |
|---|--------|-----|----------------|
| 1 | ShowMyItems — The Story of Dota Underlords (2026) | https://showmyitems.com/the-story-of-dota-underlords | Chronologie Underlords, −97 % players, abandon Valve |
| 2 | Labs Inven Global — Dota Underlords identity crisis (2019) | https://labs.invenglobal.com/articles/8925/ | −75 % en 3 mois, crise d'identité PC/mobile |
| 3 | Esports Tales — Hero pool size and odds Underlords (2019) | https://www.esportstales.com/dota-underlords/hero-pool-size-and-unit-odds-by-level | Tables odds par niveau, pool sizes T1–T5 |
| 4 | Esports Tales — Alliances Underlords (2019) | https://www.esportstales.com/dota-underlords/alliances-hero-units-synergy-list | Paliers alliance, exemples Assassin/Warrior |
| 5 | Dota Underlords Fandom Wiki — Heroes Pool | https://dotaunderlords.fandom.com/wiki/Heroes_Pool | Pool final : T1=30, T2=20, T3=18, T4=12, T5=10 |
| 6 | Dota Underlords Fandom Wiki — May 28 2020 Patch | https://dotaunderlords.fandom.com/wiki/May_28,_2020_Patch | Table odds par niveau (patch mai 2020) |
| 7 | Gamepressure — Underlords −90 % players (2020) | https://www.gamepressure.com/newsroom/dota-underlords-has-lost-90-of-players-dota-2-in-retreat/zb1622 | −90 % chiffre, chronologie 2020 |
| 8 | PCGamer — Underlords −90 % (2020) | https://www.pcgamer.com/dota-underlords-peak-player-count-has-dropped-by-more-than-90-percent/ | Confirmation des chiffres |
| 9 | Gamedeveloper.com — Autochess Market Status and Design Analysis (2021) | https://www.gamedeveloper.com/design/autochess-market-status-and-design-analysis | Fragmentation de genre, défauts design core |
| 10 | Pepijn van Sinderen — Examining the Jail mechanic (2019) | https://vansinderen.com/examining-the-jailbird-mechanic-from-dota-underlords/ | Mécanique Jail, effet méta quotidien |
| 11 | Marlvel.ai — Dota Underlords app report (2026) | https://marlvel.ai/intel-report/games/dota-underlords | Sentiment 3,42/5, statut zombie |
| 12 | MetaTFT — TFT Shop Odds Set 17 | https://www.metatft.com/tables/shop-odds | Tables TFT niveau→odds (1-cost pool: 29, 2-cost: 22, 3-cost: 18, 4-cost: 10, 5-cost: 9) |
| 13 | zhongjzsb.com — Underlords Unit Odds (2020) | https://zhongjzsb.com/posts/baobao-posts/2020-08-14-underlords-unit-odds/ | Formule P_single, calculs contestation |
| 14 | HSReplay — Storybook Brawl vs Battlegrounds Part 1 (2022) | https://articles.hsreplay.net/2022/09/21/storybook-brawl-the-perfect-game-for-battlegrounds-players/ | Front/back, héros, types, trésors Part 1 |
| 15 | HSReplay — Storybook Brawl vs Battlegrounds Part 2 (2022) | https://articles.hsreplay.net/2022/09/23/storybook-brawl-the-perfect-game-for-battlegrounds-players-2/ | Trésors, sorts, montée auto de palier, damage formula |
| 16 | Summit Reviews — The Rise and Fall of Storybook Brawl (2025) | https://summitreviews.biz/article/35/the-rise-and-fall-of-storybook-brawl | Chronologie SBB complète, $25M, $200k revenus, FTX, communauté |
| 17 | CoinTelegraph — Storybook Brawl review bomb (2022) | https://cointelegraph.com/news/crypto-skeptic-gamers-review-bomb-storybook-brawl-after-ftx-buys-it | 600/761 reviews négatives, chronologie mars 2022 |
| 18 | Bloomberg Law — FTX collapse SBB shutdown (2023) | https://news.bloomberglaw.com/crypto/sam-bankman-frieds-favorite-video-game-is-shutting-down | Fermeture serveurs 1er mai 2023 |
| 19 | Gamedeveloper.com — Why Artifact Failed (2019) | https://www.gamedeveloper.com/design/why-artifact-failed | Analyse design 40 min, monétisation quadruple, opacité, 3 lanes |
| 20 | LessWrong — Artifact: What Went Wrong (2019) | https://www.lesswrong.com/posts/6gptwR8jBkzqhWaTY/artifact-what-went-wrong | 10 raisons (Zvi), complexity as primary cause, joueurs pros qui ont abandonné |
| 21 | Kotaku — Artifact Designer Says It Failed (2019) | https://kotaku.com/artifact-designer-says-it-failed-due-to-cards-for-money-1835212145 | Interview Garfield : 3 causes, revenue model, community tools, review bomb |
| 22 | Win.gg — Artifact devs discuss launch (2019) | https://win.gg/news/artifact-devs-discuss-the-launch-fate-and-future-of-artifact/ | Interview Garfield/Elias, « you can't test how the revenue model will be taken » |
| 23 | PCGamer — Richard Garfield on Artifact monetization (2021) | https://www.pcgamer.com/richard-garfield-on-artifacts-failed-monetization-model-we-wanted-to-avoid-manipulating-people/ | « We wanted to avoid manipulating people » |
| 24 | PCGamer — Why Artifact Failed (2019) | https://www.pcgamer.com/why-artifact-failed-and-what-can-valve-do-to-save-it/ | Reynad : cartes excitantes vs équations |
| 25 | Polygon — Artifact Review (2018) | https://www.polygon.com/reviews/2018/11/28/18115031/artifact-review-dota-2-card-game | Description mécanique 3 lanes, impétences animations, 60k players |
| 26 | TechRaptor — Valve Focusing on Larger Artifact Issues (2019) | https://techraptor.net/gaming/news/valve-focusing-on-larger-artifact-issues-not-shipping-updates-in-immediate-future | 15 % reviews récentes positives, abandon update |
| 27 | MGN — Underlords in 2021 | https://mgn.gg/underlords-in-2021-game-review-dota-underlords | Contexte post-abandon, valeur résiduelle |
| 28 | Kotaku — Dota Underlords out of Early Access (2020) | https://kotaku.com/dota-underlords-is-out-of-early-access-and-better-than-1841942153 | City Crawl, Season 1, promesses non tenues |
| 29 | Steam Community — \#SaveDotaUnderlords (2025) | https://steamcommunity.com/app/1046930/discussions/0/5156060518433122154/ | 5496 commentaires, joueurs encore actifs en 2025 |

---

*Document rédigé le 2026-06-23. Lecture seule du repo. Écriture sous `docs/roadmap-lab/` uniquement.*
*Garde-fous respectés : aucune modification de code, aucun test rebaseliné, piliers async/déterministe/grimdark/procédural préservés.*
