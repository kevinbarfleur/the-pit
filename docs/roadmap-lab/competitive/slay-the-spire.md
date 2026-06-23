# Slay the Spire — Analyse ultra-approfondie

> **Mandat** : teardown precis de chaque mecanisme cle → psychologie (pourquoi ca hook) → maths
> chiffrees et sourcees → verdict de transferabilite a *The Pit* (async snapshots, run court
> 10 victoires, sim deterministe seedee, grimdark pixel art procedural). Demolir les analogies
> paresseuses. Chaque affirmation cite sa source.
>
> **Garde-fou** : fichier en lecture seule pour le code du jeu. Redige uniquement sous
> `docs/roadmap-lab/`. Ne modifie pas `src/`, `tests/`, ni aucun autre fichier du repo.
>
> **Date d'analyse** : 2026-06-23. Sources primaires : slaythespire.wiki.gg (wiki officiel),
> foxrow.com (analyse de 18 millions de runs fournie par MegaCrit), sts1.heart-rate.net
> (stats A20H en temps reel), GDC 2019 Anthony Giovannetti (metriques/equilibrage),
> gamedeveloper.com (interviews Giovannetti/Yano), forgottenarbiter.github.io (RNG interne),
> arxiv.org 2025 (analyse de l'incertitude dans les cartes), diva-portal.org (theses sur le RNG
> et la difficulte).

---

## 0. Pourquoi StS (et pas juste « deckbuilder roguelike »)

Slay the Spire n'est pas un jeu a analyser parce qu'il est populaire. Il s'analyse parce qu'il
a **resolu un probleme specifique** : construire un systeme de difficulte, de recompense et de
profondeur *dans un espace de decisions asymetrique solo contre IA* — exactement le probleme de
The Pit, a ceci pres que The Pit est asynchrone. Ce que StS a fait, ce que ca produit, et
pourquoi ca ne copie pas directement : voila le programme.

---

## 1. Mecanisme #1 — Le systeme d'intent (information parfaite)

### 1.1 Teardown precis

Chaque ennemi affiche au-dessus de lui, *avant* le tour du joueur, une icone et un chiffre
precis : attaque (montant exact), blocage, debuff, soin, invulnerabilite. Le joueur sait
**exactement** ce que l'ennemi va faire. Le seul inconnu est le tirage de sa propre main.

Source : l'article de Jeremiah Franczyk (jeremiahgames.com, 2019-03-04) titre « Perfect
Information: The Killer Feature of Slay the Spire and Into the Breach ». L'interview « War
Stories » de Ars Technica (2019-05-02) confirme que ce systeme a remplaces un systeme de
« prochaine action cachee » : les premiers playtesters sur Steam se plaignaient massivement
de l'opacite, la visibilite Twitch etait nulle, le taux de retour negatif etait eleve. MegaCrit
a pivote vers l'information totale.

### 1.2 Psychologie

Franczyk (ibid.) identifie deux effets :
- **Chaque tour devient un micro-puzzle** : avec l'information complete, la question « que
  jouer ? » a une reponse optimale calculable. Ca n'elimine pas la difficulte (le tirage de
  main est aleatoire), ca la rend **attribuable au joueur**.
- **L'echec ne peut pas blamer le systeme** : le joueur savait que l'ennemi allait frapper
  pour 42, il n'a pas bloque assez. Cela convertit la frustration en competence recherchee —
  un mecanisme de retention puissant documente par la litterature sur la « competence growth »
  (Ryan & Deci, Self-Determination Theory ; cite dans diva-portal.org 2021).

L'analyse de socratopia.app (chapitre « mastery ») confirme : StS fonctionne sur un pilier
**maitrise dominant** — courbe d'apprentissage de 200+ heures, entierement diegetique, sans
barriere monetaire. Le systeme d'intent est le moteur de cette maitrise.

### 1.3 Maths

Il n'y a pas de table de probabilites pour l'intent car le systeme est *deterministe* : l'IA
de StS suit des scripts predefinis (patterns cycliques ou conditionnels), pas du RNG pur.
L'attaque affichee est garantie. La seule incertitude est *quelle attaque dans le cycle*
l'ennemi fera au prochain tour — mais c'est deductible du tour precedent. Donnees de run sur
18 millions de parties (foxrow.com, 2020-12) : win-rate global toutes ascensions = 9 %. Les
boss les plus letaux (le Heart : ~51 % de « fatal% » sur Ironclad) sont ceux dont les patterns
sont les plus difficiles a modeliser sans experience — preuve que la maitrise *du script* est
la vraie courbe d'apprentissage, pas la reaction au hasard.

### 1.4 Verdict de transferabilite a The Pit

**Pas applicable en l'etat — mais le principe psychologique l'est entierement.**

*Pourquoi ca ne copie pas* : StS est tour-par-tour, le joueur agit. The Pit est
**full-auto spectateur** : une fois le combat lance, le joueur ne joue aucune carte. L'intent
ennemi en temps reel n'a aucun sens.

*Ce qui survive* : le **principe d'attributabilite**. Dans The Pit, l'equivalent de l'intent
c'est le **ciblage 100 % deterministe** (decision actee : colonne → taunt → aggro → tie-break,
`arena.lua:chooseTarget`, 00-state.md §3.3). Quand une unite meurt, le joueur peut retracer
pourquoi (elle etait en avant, elle avait moins d'aggro que le tank). Ce n'est pas un
systeme d'intent affiché, c'est un systeme de **predictabilite post-hoc** — le joueur peut
reconstruire la logique. C'est moins puissant que l'intent pre-combat de StS, mais c'est
ce qui existe dans notre contrainte async.

**Adaptation recommandee** : le **combat log structure** (bus d'evenements JSON, deja code en
`src/core/bus.lua`) doit etre lisible en post-combat. Un replay ou une synthese « pourquoi ton
Unite X est morte » convertit la frustration en apprentissage — la meme psychologie qu'intent,
avec un delai.

---

## 2. Mecanisme #2 — Les reliques (build-defining, lisibles, a downside)

### 2.1 Teardown precis

StS distingue cinq tiers de reliques (wiki slaythespire.wiki.gg/wiki/Relics, verifie 2025-07) :

| Tier | Source | Cotes d'obtention (hors coffres) | Exemples |
|------|--------|----------------------------------|---------|
| Commune | elite / coffre / shop | **50 %** | Akabeko (+8 atk 1er tour), Centennial Puzzle, Red Skull |
| Peu commune | elite / coffre / shop | **33 %** | Odd Mushroom, Frozen Egg, Ectoplasm |
| Rare | elite / coffre / shop | **17 %** | Ginger, Dead Branch, Philosopher's Stone |
| Shop | shop uniquement (3e slot toujours) | fixe (1 par shop) | Membership Card (−50 % prix), Chemical X, Strange Spoon |
| Boss | apres chaque boss (choix 1/3) | garanti a chaque boss | Fusion Hammer (+1 energie, forge impossible), Busted Crown (+1 energie, −2 cartes de recompense), Ectoplasm (+1 energie, plus d'or) |

Coffres : cotes differentes (wiki slaythespire.wiki.gg/wiki/Mechanics) :
- Petit coffre : 75 % commun / 25 % peu commun / 0 % rare
- Coffre moyen : 35 % / 50 % / 15 %
- Grand coffre : 0 % / 75 % / 25 %

Les **reliques boss** sont les plus build-defining. Elles donnent generalement +1 energie
(passer de 3 a 4 cartes par tour est une multiplication de throughput de ~33 %) mais imposent
un malus fort. Choix 1-parmi-3 garanti apres chaque boss d'act 1 et 2.

### 2.2 Psychologie

Deux mecanismes psychologiques distincts :

**A — La relique boss comme pivot de build** : le fait que la relique boss ait un **downside
explicite** force le joueur a construire autour de ce downside. Busted Crown (-2 cartes de
recompense) pousse vers un deck petit et efficient. Ectoplasm (plus d'or) pousse vers
l'autonomie du deck sans achat. C'est du **forced theming** — le downside elimine des options
et, paradoxalement, augmente la lisibilite du chemin optimal. Giovannetti cite dans
gamedeveloper.com (2018-02-27) : « Since we are a single player card game, we don't have to
worry about the typical downside of strong combos - where the opponent feels bad because of an
overpowered strategy. » Ce cadre *singleplayer* autorise les reliques a etre tres fortes.

**B — La relique commune/rare comme « lottery ticket »** : la rarete variable (50/33/17 %
pour elite, 75/25/0 pour petit coffre) cree un **renforcement a ratio variable** — le
mecanisme de conditionnement operant le plus persistant decouvert (Skinner, 1938 ; discute dans
socratopia.app chapitre 4). Ce n'est pas du pur hasard : le joueur *sait* qu'il y a 17 %
de chance d'avoir une rare. C'est du « near-miss sous agence » — il peut influencer ses odds
en choisissant de combattre des elites (meilleures cotes).

### 2.3 Maths

Prix des reliques au shop (wiki slaythespire.wiki.gg/wiki/The_Merchant, 2025-08) :
- Relique commune : 143-158 or (≈ 150)
- Relique peu commune : 238-263 or (≈ 250)
- Relique rare : 285-315 or (≈ 300)
- Relique shop : 143-158 or (≈ 150)

Or par combat (wiki slaythespire.wiki.gg/wiki/Gold) :
- Monstre : 10-20 or (moy. 15)
- Elite : 25-35 or (moy. 30)
- Boss : 95-105 or (moy. 100)

Un run typique Act 1 produit ≈ 210 or de combats + 100 boss = 310 or
(calcul KosGames.com, veri : 75 % du temps en combat = ~8 monstres × 15 + ~3 elites × 30 ≈ 210).
Une relique rare coute 300 or — exactement le budget d'un acte entier sans autre depense.
C'est delibere : acheter une rare au shop = ne pas ameliorer son deck cet acte.
La tension **shop vs puissance immédiate** est l'axe economique fondamental.

L'analyse de 1M de runs (diva-portal.org 2021) confirme : les reliques sont parmi les
variables les plus correlees avec la victoire, surpassant les cartes individuelles.

**Reliques boss — budget d'energie** : +1 energie = le joueur peut jouer une carte
supplementaire par tour. Avec 3 combats typiques d'acte 2 + 2 elites + 1 boss, ca represente
des dizaines de cartes supplementaires sur un run. L'upside est colossal ; le downside est
calibre pour compenser exactement.

### 2.4 Verdict de transferabilite a The Pit

**Partiellement transposable — le modele StS a deja informe les decisions du projet.**

Le CLAUDE.md §7 et relics-design.md §1 actent deja le pivot vers les reliques **lisibles**
(nom + effet clair + flavor), en citant StS comme reference. La taxonomie A-G de
relics-design.md reproduit partiellement la structure StS (stats plates / amplis / paliers /
defensives / transformatives).

*Ce qui differe fondamentalement* :

1. **StS n'a pas de downside sur les reliques non-boss.** Toutes les reliques communes/rares
   sont pures upside. Seules les boss-reliques ont un malus. The Pit n'a pas de boss-reliques —
   le moment d'acquisition le plus tendu est le « 1-parmi-3 tous les 3 combats » (run/state.lua).
   Les reliques de The Pit sont toutes upside (relics-design.md §1 principe #2 : « aucune
   relique ne handicape la suite de la partie »). C'est une decision deliberee et coherente
   avec le principe grimdark d'**egalisation** (pas de gate) — a ne pas re-debattre.

2. **StS a un marche avec des prix en or.** The Pit n'a pas de shop de reliques en v1
   (relics-design.md §2). La tension economique d'StS (relique vs deck) n'existe pas ici —
   les reliques sont des recompenses gratuites des combats. Le corollaire : elles doivent
   etre plus moderees en puissance absolue pour que le Grimoire ne devienne pas une
   meta-progression trop forte.

3. **Cotes de rarete** : StS a 50/33/17 pour commun/rare sur elite. The Pit n'a pas encore
   de rarete par tier de relique (tous egalement dans le pool 1-parmi-3 tire par
   `rollRelicChoices`, tiers gates par avancee — 00-state.md §2.2). La progression
   actuelle (early→≤2 / mid→≤3 / late→≤4 tier) reproduit le gating-par-avancee de StS.

**Adaptation recommandee** :
- Le systeme de **reliques shop** de StS (prix fixes, toujours en 3e slot) est transferable
  en v2 : un « marchand » tous les N combats vendant une relique au lieu du tirage normal.
  Cela creerait la tension **relique vs reroll boutique** absente aujourd'hui.
- Le principe du **downside calibre** des boss relics de StS suggere que les reliques de
  categorie E-F (transformatives / globales) de The Pit devraient avoir des contraintes
  implicites — non comme pénalité (rejectee §1 principe #2), mais comme **scope limite** :
  une relique transformative qui s'active sous condition (ex. « Forked Tongue » actif seulement
  si le joueur a au moins 3 unites choc) pousse vers l'archetype sans etre un gate absolu.

---

## 3. Mecanisme #3 — Les cotes de tirage (rare climb, anti-drought)

### 3.1 Teardown precis

Le systeme de distribution de cartes est documnte avec precision dans le code source (analyse
forgottenarbiter.github.io, gaming.stackexchange.com/325773, scribd.com/718620802) :

**Probabilites de tirage de carte (par recompense de combat)** :
- Rare : demarre a **-2 %** (impossible) et augmente de +1 % par carte commune tirée
  (pas par combat, par carte *dans* la recompense). Se remet a -2 % quand une rare est tiree.
- Peu commun : fixe a **37 %** (ne varie pas sauf reliques specifiques).
- Commun : 63 % puis diminue quand la rare monte.

*Note de precision* : ce sont les cotes par carte dans le groupe de 3 proposee, pas par
« recompense ». Sur une recompense de 3 cartes, la probabilite d'avoir au moins une rare
augmente avec le nombre de communes vues depuis la derniere rare.

**Modificateurs contextuels** :
- Elite : +10 % sur la rare (−10 % sur commune) pour cette recompense uniquement.
- Shop : +6 % sur la rare (−6 % sur commune), fixe.
- Boss : toujours **3 rares garanties** (choix 1/3).
- Acension 12 : cartes ameliorees 50 % moins souvent dans les recompenses.

**Potions** (forgottenarbiter.github.io) : probabilite de base 40 %/combat, −10 % si potion
obtenue, +10 % si non obtenue. Moyenne a long terme : 27,3 % par combat (mathematiques.
stackexchange.com, 2026-03, calcul exact via chaine de Markov).

### 3.2 Psychologie

Le mecanisme de « rare climb » (la probabilite monte quand on en voit pas) est un **systeme
anti-secheresse** (drought protection) — analogue au pitye-timer des gacha. Il repond a la
psychologie du « near-miss » : le joueur sait que plus il voit de communes, plus une rare
est proche. Ca cree une **anticipation graduee** sans garantie temporelle precise — le
renforcement variable optimal (variable-ratio schedule) est preserve mais renforce une boucle
cognitive positive au lieu de passive.

Ce n'est pas de la pitye « je garantis quelque chose a N essais ». C'est une *pression
progressive* sur la distribution : la rare arrive au moment ou le joueur attendait — elle
est percue comme « meritee », meme si c'est statistique. Ce decouplage entre perception et
mecanique est l'un des designs les plus subtils de StS.

**Correlation RNG** : forgottenarbiter.github.io montre que les appels aux RNGs de potion
et de carte sont synchronises dans l'ordre d'execution — si la premiere carte d'une
recompense est peu commune, la potion tombe aussi de ce combat. Ce n'est pas intentionnel
(bug-feature) mais renforce l'idee que « les bons RNG viennent ensemble » — un biais cognitif
que le joueur interprete comme un run « chaud ».

### 3.3 Maths resumees

| Source | Cote rare | Cote peu commun | Cote commun |
|--------|----------|-----------------|-------------|
| Combat ordinaire (0 communes vues) | -2 % (impossible) | 37 % | 63 % |
| Combat ordinaire (5 communes vues) | 3 % | 37 % | 60 % |
| Combat ordinaire (moy. sur run) | ~5 % | 37 % | 58 % |
| Elite | ~10 % (base+10) | ~40 % | ~50 % |
| Shop | ~9 % (base+6) | 37 % | 54 % |
| Boss | 100 % (garanti 3 rares) | — | — |

Source : scribd.com/718620802 (reference exhaustive), gaming.stackexchange.com/372745
(code verifie).

### 3.4 Verdict de transferabilite a The Pit

**Transferable dans le principe, inutile dans la structure exacte.**

The Pit n'a pas de recompenses de cartes apres combat. La boutique est le seul canal
d'acquisition, et les cotes sont le **shopTier** (progression-economy-prd.md, 00-state.md §4.3).
La table de cotes actuelle :

| Tier | R1 | R2 | R3 | R4 | R5 |
|------|----|----|----|----|----|
| T1 | 100 | — | — | — | — |
| T2 | 70 | 30 | — | — | — |
| T3 | 44 | 34 | 20 | 2 | — |
| T4 | 25 | 30 | 30 | 13 | 2 |
| T5 | 15 | 20 | 30 | 25 | 10 |

Ce systeme fait deja le bon travail de **gating par avancee** — la profondeur est progressive.
Il n'a pas de « rare climb » intra-run, mais il n'en a pas besoin : les [PH] sur toutes les
valeurs (00-state.md §4.3) permettront de tuner la distribution une fois que `tools/sim.lua`
donnera des metriques de rotation d'unites par archetype.

**Ce qui manque** : un **anti-secheresse pour les reliques**. Aujourd'hui, le pool de reliques
est tire par Fisher-Yates seedé (run/state.lua, 00-state.md §2.2) — pas de drought protection.
Si le joueur ne voit jamais une relique pour son archetype pendant 6 combats, il n'a pas de
garantie que « ca va arriver ». Le systeme de gating (early/mid/late) attenúe sans resoudre.

**Adaptation recommandee** : un **tracker d'archetype** dans le pool de reliques — si le
joueur a un archetype domine (ex. 60 % de ses unites sont poison), augmenter progressivement
le poids des reliques poison dans les 3 offerts. Ce n'est pas tricher ; c'est du drought
protection contextualisé, comme le rare-climb de StS.

---

## 4. Mecanisme #4 — La carte de pathing (risque-recompense spatial)

### 4.1 Teardown precis

Chaque acte de StS est une carte verticale de 17 etages (wiki slaythespire.wiki.gg/
wiki/Map_Generation, 2025). Les regles garanties :
- Etage 1 : tous monstres « easy pool » (premier combat tutoriel mediatise).
- Etage 9 : tous coffres (garanti au milieu de l'acte).
- Etage 15 : tous repos (garanti avant le boss).
- Etages 6+ : elites et repos peuvent apparaitre.

Distribution de type de salle (scribd.com/718620802) :
- Monstre : **53 %** des salles aleatoires
- Evenement (?) : **22 %**
- Repos : **12 %**
- Elite : **8 %**
- Shop : **5 %**

La contrainte d'adjacence (pas de 2 elites consecutifs, pas de 2 repos consecutifs, etc.)
assure de la variete. Le joueur voit la carte complete de l'acte et choisit son chemin
*avant* d'entrer dans chaque salle.

### 4.2 Psychologie

Le pathing est le systeme de **risk/reward spatial** de StS. Aller vers un elite = risquer
des HP pour obtenir une relique. Aller vers un repos = soigner sans gain. Aller vers un « ? »
= variance maximale (evenement bon, neutre ou mauvais).

L'analyse de l'arxiv 2025 (dl.acm.org/doi/full/10.1145/3723498.3723846) sur 1M de runs montre
que **l'entropie de normalisation du chemin pris est significativement plus elevee dans les
runs gagnants** (p-value forte). Les joueurs qui gagnent prennent plus de risques calcules —
surtout vers les elites. En moyenne, un run gagnant prend **1,85 elite par acte** vs
significativement moins dans les runs perdants (diva-portal.org/Slay the Spire ML paths).

Ce mecanisme cree une **dette et anticipation** : le joueur voit la relique elite qui l'attend,
sait que son deck est fragile, et doit evaluer si il « peut se le permettre ». C'est du stress
positif — un challenge qui donne l'impression d'etre juste.

L'interview Giovannetti (gamedeveloper.com, Road to the IGF, 2020-01-22) : « The paths that
the player can take were inspired by FTL. I think it is valuable to have layered decision-making
in a strategy game, and navigating the map adds an extra element of risk/reward and planning to
the game. »

### 4.3 Maths

Budget moyen d'or Act 1 (KosGames.com) : ≈ 210 or de combats + 100 boss = 310 or. Avec
~1-2 elites par acte (1.85 en moyenne winning), un acte gagnant produit typiquement :
6-7 monstres × 15 = 105 + 2 elites × 30 = 60 + 1 boss × 100 = 100, total ≈ 265 or/acte.

A ascension 1+ : le nombre d'elites augmente de ~60 % (wiki MapGeneration), ce qui augmente
a la fois le risque et la production d'or/reliques — un piege intentionnel pour les joueurs
qui montnt en difficulte.

### 4.4 Verdict de transferabilite a The Pit

**Non applicable structurellement — l'equivalent existe deja sous une autre forme.**

The Pit n'a pas de pathing spatial. La progression est lineaire : round → combat → round.
La decision strategique equivalente est **quoi acheter et combien reroller** (tension
or/boutique/reroll, state.lua). Le joueur n'a pas a « choisir son chemin sur une carte ».

Cependant, le **principe psychologique** (risque calcule pour recompense connue) est present
dans :
- Le choix d'acheter une unite de rang eleve (plus chere, peut-etre inutilisable maintenant
  vs la valeur sur le run).
- Le choix de monter de tier boutique maintenant vs garder l'or pour acheter.
- (A venir) le choix de prendre une relique vs decliner pour 3 or.

La decision de **decline pour or** (DECLINE_RELIC_GOLD = 3, 00-state.md §4.1) est un
analogue minimaliste : « je sais ce que cette relique m'apporterait, mais prefere l'or pour
reroller ». C'est un risque/recompense intime, pas spatial.

**Ce qui manque a The Pit** : le pathing de StS cree une **anticipation visible** (le joueur
voit les salles futures). The Pit est opaque sur le futur — le joueur ne sait pas quels
adversaires il affrontera ni quand il verra des reliques. Cela reduit la profondeur de
**planification** au profit de la **reactivity**. Ce n'est pas un defaut, c'est un choix de
design qui aligne avec « simplicite de gestion → profondeur emergente » (CLAUDE.md §2).

Mais si l'on veut ajouter de l'anticipation *sans* carte spatiale : montrer les tiers d'
adversaires des 2-3 prochains rounds (trop facile/intermediaire/difficile) permettrait une
planification de run sans la complexite de la carte StS.

---

## 5. Mecanisme #5 — Ascension (difficulte progressive, meta-competitif)

### 5.1 Teardown precis

Ascension est un mode dans lequel chaque victoire ajoute un modificateur de difficulte.
20 niveaux en tout, cumulatifs (wiki slay-the-spire.fandom.com/wiki/Ascension) :

| Ascension | Modificateur |
|-----------|-------------|
| 1 | +60 % d'elites sur la carte |
| 2 | Ennemis ordinaires plus dangereux |
| 3 | Ennemis elite plus dangereux |
| 4 | Boss plus dangereux |
| 5 | Soins apres boss reduits a 75 % des HP manquants |
| 6 | Debut de run avec 10 % de HP manquants |
| 7 | Boss pauvres : drop 25 % moins d'or |
| 8 | Ennemis renforcé : -5 HP max (Ironclad) |
| 9 | Ennemis ordinaires encore plus dangereux |
| 10 | Debut avec une malediction non-retirable (Ascender's Bane) |
| 11 | 1 slot de potion en moins |
| 12 | Cartes ameliorees 50 % moins frequentes en recompense |
| 13 | Boss drop 25 % moins d'or |
| 14 | HP max reduits |
| 15 | Evenements defavorables, moins d'or |
| 16 | Shop 10 % plus cher |
| 17-19 | Monstres, elites, boss encore plus difficiles |
| 20 | 2 boss differents en fin d'acte 3 |

Chaque niveau d'ascension accorde **+5 % de score** sur les bonus du Daily Climb
(fandom.com/Ascension). Perdre ne reset pas le niveau.

Unlock : battre le run precedent avec *ce personnage* (par personnage, pas global).

### 5.2 Psychologie

Ascension est un **escalier de competence** — chaque marche est un nouveau test de maitrise,
pas une gate de contenu. Le joueur progressif peut toujours rejouer A0 ; ascension ne retire
rien. Ce modele repond a deux besoins psychologiques distincts (Socratopia, chapitre mastery) :

- **Core Drive 2 (accomplissement)** : chaque victoire d'ascension est un benchmark objectif
  et verifiable. « J'ai battu A15 avec Silent » signifie quelque chose de precis.
- **Identite** : l'ascension est par personnage — 4 personnages × 20 niveaux = 80 tiers de
  maitrise possibles. Les joueurs ne « completent » pas StS facilement.

L'absence de **ladder PvP global** dans StS est notee par Socratopia (ibid.) : « Status is
the weakest pillar. There is no global ranked ladder. » Le Daily Climb a des leaderboards,
mais la comunaute de status se construit autour des Discords, subreddits, contenu — pas d'un
MMR central. StS a prouve qu'une boucle de retention tres forte peut fonctionner **sans
ranked PvP**.

Statistiques : foxrow.com (18M de runs) : win-rate global 9 %. Sur les joueurs de
sts1.heart-rate.net (sample de hardcore : 28 joueurs, 93K runs) : win-rate A20H (Ascension 20,
Heart killed) — Ironclad 24,6 %, Silent 21,6 %, Defect 19,2 %, Watcher 29,9 %. Cela valide
que meme les meilleurs joueurs ont ≈ 20-30 % de win-rate sur la difficulte maximale — un
espace d'apprentissage qui ne se « resout » jamais completement.

### 5.3 Maths de difficulte

Les A20 experts (heart-rate.net) ont une win-rate de ~25 % malgre des milliers de runs. La
courbe d'apprentissage de StS est anormalement longue — l'analyse de diva-portal.org 2021
montre que le RNG d'*input* (tirer de la main, shop, carte recompense) est la principale source
de variance, et que meme les tres bons joueurs ne peuvent pas entierement la controler.
Win-rate A0 global (tous joueurs confondus) : ~41 % (foxrow.com, calcul déduit de 9 % global
avec repartition par ascension). Win-rate A20H : ~3 % tous joueurs (karlo-delacruz, github).

### 5.4 Verdict de transferabilite a The Pit

**Partiellement transferable — mais le modele async change la nature du « climb ».**

*Ce qui ne s'applique pas* : un escalier de 20 niveaux de difficulte **solo** n'a pas de sens
dans The Pit. La difficulte du run vient de la progression des adversaires (servir un
snapshot de tier superieur), pas d'un mode separe. Il n'y a pas de personnages multiples a
maitriser (pas de deck-building par personnage).

*Ce qui s'applique directement* :
1. **Perdre ne doit pas reset la progression.** Ascension ne punit pas la perte. The Pit a
   le meme principe : 5 vies, 10 victoires, filet au round 3 (00-state.md §4.2). La
   progression de run est « chaque vie perdue = informaton sur ce qui manque » — pas de reset
   de meta.
2. **Le match par progression, pas par victoires absolues.** StS match les Daily leaderboards
   par seed identique (tous jouent le meme run). The Pit match les ghosts par tier/version
   (snapstore.lua, 00-state.md §5). L'analogie est solide.
3. **La maitrise comme long-terme.** The Pit a le Grimoire (collection cross-run, persistant)
   qui joue le role de l'ascension : « je connais cette relique depuis la run 12, j'ai
   maintenant le bon reflexe ». C'est de la maitrise encodee dans le systeme, pas dans
   l'UI.

**Ce qui manque a The Pit et que StS eclaire** : la **structure de ranked async** est un
blanc total (00-state.md §7 « zone vierge — opportunite #1 »). StS a prouve qu'il n'est pas
necessaire d'avoir un MMR Elo global pour creer de l'engagement competitif : le Daily seede
(meme run pour tout le monde) + leaderboard ephemere (24h) = competition intense sans ladder
permanent. C'est le modele le moins couteux a implementer pour The Pit.

**Adaptation concrete** : une « Descente du Jour » (daily seeded run) — meme seed pour tous
les joueurs actifs ce jour-la, leaderboard ephemere 24h bas sur le score (nombre de rounds
gagnes × tier atteint × efficacite or). Cela cree un contexte competitif sans matchmaking
en temps reel, coherent avec les snapshots async.

---

## 6. Mecanisme #6 — Le deck comme ressource depreciable (card removal, deck thinning)

### 6.1 Teardown precis

Le deck de StS *commence* avec un starter deck (10-12 cartes selon le personnage, dont des
« Strikes » et « Defends » qui sont generalement mediocres). La carte de depart est donc une
**dette** : on a des cartes mauvaises qu'on va eliminer progressivement. Moyens :

- **Card removal au shop** : depart a 75 or, augmente de 25 par utilisation
  (wiki The_Merchant). On peut en utiliser plusieurs dans un run : 75 + 100 + 125 + ... or.
- **Cartes speciales** : certaines cartes exhaustent, d'autres s'eliminent d'elles-memes.
- **Reliques** : Empty Cage retire 2 cartes gratuitement, Peace Pipe permet de retirer au repos.

L'analyse ML (diva-portal.org 2021) et l'analyse 18M runs (foxrow.com) confirment que les
decks **petits** ont globalement de meilleures chances. Plus le deck est petit, plus on
cycler vite et plus on rejoue les bonnes cartes souvent.

### 6.2 Psychologie

Le systeme de card removal cree une tension unique : le joueur *veut* accumuler des cartes
(plus de recompenses = plus d'options) mais accumulation nuit a la vitesse de cycle. Chaque
« non » (skip une carte recompense) est un choix actif difficile. Giovannetti (gamedeveloper.com
2018) : « I know the sheer joy when your deck comes together and feels like a well-oiled Rube
Goldberg machine. »

C'est du **pruning/crafting cognitif** — le joueur donne une identite a son deck en
eliminant le bruit. Psychologiquement, c'est la theorie de « less is more » appliquee a un
inventaire : chaque carte retirée augmente l'identite du deck.

### 6.3 Verdict de transferabilite a The Pit

**Non applicable — mais le principe psychologique a un analogue.**

The Pit n'a pas de deck au sens StS. L'analogue est la **composition de plateau** : le
joueur a 3-9 slots (selon le tier boutique) et un bench. Vendre une unite (drag hors-plateau)
est l'analogue du card removal — liberer un slot pour une meilleure unite.

Le remboursement de revente (`SELL_REFUND_FRAC = 0.5`, 00-state.md §4.1) est deja calibre
pour ne pas etre un exploit : vendre a 50 % interdit le cycle achat-revente. C'est le bon
design. Mais il manque la **tension explicite** de StS : dans StS, on *choisit* de payer pour
un slot meilleur (card removal). Dans The Pit, on vend une unite pour recuperer 50 % de son
cout. La decision est moins douloureuse, donc moins satisfaisante quand elle « paie ».

**Adaptation potentielle** : un mechanic de « sacrifice » (vendre une unite à son prix plein
mais avec une consequence : ex. elle rejoint l'adversaire snapshot ce round) transformerait
une transaction neutre en decision a enjeux. C'est speculatif — a tester uniquement si des
playtests montrent que les ventes manquent de tension.

---

## 7. Mecanisme #7 — La boucle du Daily Climb (seede, competitif, ephemere)

### 7.1 Teardown precis

Le Daily Climb de StS est un run seede, avec un personnage et 3 modificateurs aleatoires
fixes pour 24h (fandom.com/Daily_Challenge). Le score final est soumis au leaderboard global.
La seed est identique pour tous les joueurs — un seul run par compte compte pour le score.

Specificites (ericra.com, guide expert du daily) :
- Toujours Ascension 0, Acte 4 desactive.
- Score maxise par : Champion (elite sans degat, +25/elite), Perfect (boss sans degat, +50),
  Highlander (1 seul exemplaire de chaque carte, +100), nombre d'etages montes (+5/etage).
- Certains mods daily (Hoarder = ramasser un max de cartes) invertissent la strategie de
  thinning — ce sont des variantes qui elevent la rejouabilite.

### 7.2 Psychologie

Le daily seede est le modele competitif le moins couteux a implementer. Il combine :
- **Urgence temporelle** (24h) → Core Drive 6 (urgence, peur de la perte).
- **Niveau joue** (tout le monde a la meme seed) → pas de « j'avais un mauvais run » comme
  excuse. La competition est *pure sur l'execution*.
- **Leaderboard ephemere** → pas de comparaison ecrasante avec des joueurs permanents de
  3000h. Chaque jour repart a zero (logique Yu-kai Chou, yukaichou.com 2026-04-11).

L'ephemere est cle : les leaderboards qui restent ont le « probleme des baleines » (les top
5 sont intouchables, demoralisants pour les nouveaux). Le reset quotidien cree de
l'equite percue — n'importe qui peut etre #1 aujourd'hui.

### 7.3 Verdict de transferabilite a The Pit

**Tres directement transferable — c'est la proposition la plus haute-valeur de StS pour The Pit.**

The Pit a deja les pieces : seed de run deterministe (pilier async, invariant #2 de test),
snapshots serializables, serveur de ghosts. Ce qui manque :

1. **Un format « Daily Pit »** : meme seed de run pour tous les joueurs actifs ce jour, avec
   un leaderboard 24h. La seed determine les offres de boutique, les adversaires ghosts
   rencontres (serveur de snapshots en tier fixe), et les offres de reliques.
   `state.lua:startRun(seed)` supporte deja l'injection de seed.

2. **Un systeme de score** : le score de StS (etages × kills × perfects) a un analogue
   direct — rounds gagnes × efficacite (or depense / tier boutique / unites sacrifiees) +
   bonus de perfection (combat sans perte d'unite). Simple a implementer, spectaculaire a
   afficher.

3. **Seed publique** : dans StS, la seed est visible. Dans The Pit, la seed de run pourrait
   etre affichee (code alpha-numerique, comme StS) pour permettre la discussion communautaire
   (« comment tu as joue le daily du 2026-06-23 ? »).

**Garde-fou : le daily ne require pas de live.** Les adversaires du daily sont des ghosts
preselectionnes au debut du jour a partir du pool de snapshots, pas des matchs en temps reel.
Le daily est 100 % coherent avec le pilier async.

---

## 8. Mecanisme #8 — La meta-progression (unlock de contenu, pas de puissance)

### 8.1 Teardown precis

StS a un systeme de meta-progression post-run : chaque run rate ou gagne ajoute des points
qui debloquent cartes, reliques et personnages (wiki Ascension : « a run ends, it unlocks new
cards »). C'est de la **progression de contenu**, pas de **progression de puissance** — les
nouvelles cartes/reliques agrandissent le pool aleatoire, elles ne rendent pas le joueur plus
fort par defaut.

Giovannetti (Game Design Roundtable #211) : « When a players run ends, it unlocks new cards.
What were the design reasons for this game mechanism ? » — la reponse implique que le debut
des runs doit rester simple pour les nouveaux, l'elargissement progressif du pool etant la
meta-progression.

### 8.2 Psychologie

Ce systeme cree un **FOMO positif** : « je n'ai pas encore vu toutes les reliques ». Chaque
run *explore* l'espace inconnu du pool. C'est la meme psychologie que le Grimoire de The Pit
mais dans le sens inverse : StS revele de nouveau contenu ; The Pit encode la connaissance
dans le Grimoire. Les deux produisent une anticipation du prochain run basee sur la decouverte.

La difference cle : dans StS, les nouveaux ajouts sont *aleatoires dans les runs futurs*. Dans
The Pit, les reliques identifiees sont toujours reconnues au premier coup d'oeil. Le Grimoire
est une base de connaissances, pas un catalogue de debloquage.

### 8.3 Verdict de transferabilite a The Pit

**Partiellement en place — pas a copier directement.**

The Pit a le Grimoire (collection cross-run, src/core/grimoire.lua, 00-state.md §2.2). C'est
un analogue du codex StS. Ce qui n'existe pas encore :
- Un **system de decouverte** pour les unites : le joueur voit-il toutes les 83 unites des
  le premier run ? Si oui, le sentiment de « decouverte » est absent. Si non, comment gater ?
- Le **Bestiaire** du Grimoire (onglet 2, the-pit-ui-da-layer) est une direction mais son
  mecanisme de remplissage n'est pas encore specifie.

**Recommandation** : garder le pool complet visible au shop (la boutique doit etre lisible),
mais ajouter au Grimoire un suivi des **synergies decouvertes** (ex. « tu as vu pour la
premiere fois bleed+rot se convertir » — interaction garantie testee, tests/synergies.lua).
C'est de la meta-progression de *connaissance* plutot que de contenu — coherent avec le
pilier de design du projet (relics-design.md §1, principe : « lisible, pas cryptique »).

---

## 9. Structure competitive et ranked — analyse du modele StS

### 9.1 Ce que StS a (et n'a pas)

StS n'a **pas** de ranked PvP. Il a :
- **Ascension** : ladder de difficulte solo, par personnage, permanent, cumulatif.
- **Daily Climb** : competition seede, leaderboard ephemere 24h.
- **Winstreak** : compteur personnel, non affiche aux autres par defaut.
- **Score** : systeme de scoring multidimensionnel (+5 pts/etage, +50 boss, Champion, Perfect, Ascension × 5 %).

C'est une structure **competitif sans adversaire direct**. La competition se fait contre une
reference partagee (la seed du daily), pas contre un autre joueur en temps reel.

Socratopia (chapitre mastery vs status) : « Status is the weakest pillar [of StS]. There is
no global ranked ladder. Daily Climbs have leaderboards but most players ignore them. »
L'engagement long-terme de StS repose presque entierement sur la **maitrise** — et ca a
fonctionne : 10M+ copies vendues, 77M de runs loggues par MegaCrit.

### 9.2 Pourquoi StS a choisi ce modele

Le solo dev est la contrainte principale (comme The Pit). Un ranked Elo demande :
- Un serveur de matchmaking en temps reel (incompatible avec async).
- Une masse critique de joueurs pour que le matchmaking soit juste.
- Des saisons avec des resets (infrastructure complexe).

StS a court-circuite tout cela : le daily seede + leaderboard ephemere donne 90 % de la
valeur d'un ranked pour 10 % du cout d'implementation.

### 9.3 Verdict de transferabilite a The Pit

**Le modele StS est le blueprint exact pour la structure competitive de The Pit.**

The Pit est mieux positionne que StS pour le competitif parce qu'il a **des adversaires
reels** (les ghosts de vrais joueurs), pas seulement des scores. Un ranked The Pit peut
combiner :

1. **Daily seede** (modele StS exact) : replayabilite quotidienne, leaderboard 24h, seed
   publique. Cout : quasi nul (state.lua supporte deja l'injection de seed).

2. **Matchmaking par tier** (modele snapshot, deja code) : servir un ghost de meme tier.
   C'est du « ranked implicite » — sans MMR explicite, le tier de boutique approche le
   niveau de developpement du run.

3. **Saisons courtes** (optionnel, V2) : reset du Grimoire visuel (les icones redeviennent
   « non vus ») toutes les N semaines, classement de la saison par score cumule. C'est du
   status leverage (Core Drive 2) sans requérir un serveur de matchmaking.

**Ce qu'il faut eviter** : un MMR Elo global. StS l'a evite, ce qui a ete un succes. Un
Elo demande suffisamment de joueurs simultanees pour eviter les queues longues — impossible
en cold-start. Les snapshots async resolvent ce problème (le ghost n'a pas besoin d'etre en
ligne).

---

## 10. Synthese — Tableau de transferabilite

| Mecanisme StS | Equivalent The Pit | Statut | Action |
|---------------|-------------------|--------|--------|
| Intent (information parfaite) | Ciblage deterministe + combat log lisible | **En place (partiel)** | Enrichir le combat log post-battle ; ajouter synthese « pourquoi unit X est morte » |
| Reliques lisibles (effet + downside boss) | Reliques lisibles A-F, tirage 1/3 | **En place** | Ajouter scope conditionnel aux reliques E-F (analogue du downside sans malus) |
| Rare climb (anti-secheresse) | Table de cotes par tier boutique | **Structure en place, valeurs [PH]** | Ajouter drought protection archetype pour les reliques |
| Pathing risque/recompense | Tension achat/reroll/tier boutique | **Conceptuellement present** | Optionnel : montrer 2-3 rounds d'adversaires a venir pour plus de planification |
| Ascension 20 niveaux | 5 vies / 10 victoires / montee en tier snapshot | **En place** | Definir une progression long-terme cross-runs (ex. tier snapshot = « ascension » ) |
| Card removal (pruning) | Vente a 50 % | **En place** | Optionnel : ajouter un mechanic sacrifice si playtests montrent un manque de tension |
| Daily Climb seede | Pas encore code | **A implementer** | Daily seede 24h avec leaderboard score — cout faible, valeur competitve elevee |
| Meta-progression contenu | Grimoire (reliques identifiees) + Bestiaire | **En place (partiel)** | Ajouter tracking des synergies decouvertes au Grimoire |
| Ranked / Ascension solo | Tier de matchmaking snapshot | **Architecture en place** | Definir les « saisons » cross-runs ; pas de MMR Elo en V1 |

---

## 11. Analogies paresseuses a demolir

### « The Pit doit avoir des personnages comme StS »

StS a 4 personnages avec des pools de cartes exclusives. C'est sa structure de contenu
fondamentale — chaque personnage *est* un archetype force. The Pit n'a pas de personnages ;
les archétypes emergent de la composition (unites + reliques + sigil). Copier des personnages
= imposer un archetype fixe → contradiction directe avec « profondeur emergente » (CLAUDE.md §2).

**La vraie lecon** : StS et The Pit ont des mecanismes de **diversite de run** differents.
StS l'obtient via le choix de personnage + seed aleatoire du run. The Pit l'obtient via le
sigil actif + la composition emergente + les reliques. Les deux sont valides dans leur
contexte. Ne pas copier la forme ; copier le principe : s'assurer que chaque run a une
**identite distincte des le premier round**.

### « Copier le budget d'energie de StS »

StS est un jeu de cartes ou l'energie est la ressource par tour. La puissance de « +1 energie »
(boss relic) est calibree sur des dizaines de combats par run avec des ressources finement
graduees. The Pit est un autobattler ou la ressource par tour est l'**or** (10 or/round). Les
echelles sont fondamentalement differentes. Un « +1 energie » en ou de relique aurait un impact
incommensurable (doublement de la boutiuqe un tour) ou nul.

**La vraie lecon** : le budget de puissance de chaque relique doit etre calibre sur *notre*
modele economique, pas celui de StS. `tools/sim.lua` est le seul outil qui donnera un chiffre
juste. Toute valeur par analogie avec StS est un placeholder [PH] jusqu'a validation sim.

### « L'Ascension de StS = le ranked de The Pit »

Ascension est un escalier de *difficulte solo*, pas un ranked PvP. Elle existe parce que StS
n'a aucun adversaire humain. The Pit *a* des adversaires (les ghosts) et un matchmaking par
tier. La vraie analogie de l'Ascension dans The Pit c'est la progression du **tier de snapshot**
— affronter des ghosts de tier superieur quand on gagne. Ce n'est pas un mode separe,
c'est la progression normale du run. Creer une « Ascension The Pit » par-dessus ca serait de
la complexite redondante.

---

## 12. Sources completes (URL verifiees)

| Sujet | Source | URL |
|-------|--------|-----|
| Mecaniques generales | Wiki StS officiel (slaythespire.wiki.gg) | https://slaythespire.wiki.gg/wiki/Mechanics |
| Reliques — rarete, prix, sources | Wiki StS — Relics | https://slaythespire.wiki.gg/wiki/Relics |
| Marchand — prix exactes | Wiki StS — The Merchant | https://slaythespire.wiki.gg/wiki/The_Merchant |
| Or — sources, montants | Wiki StS — Gold | https://slaythespire.wiki.gg/wiki/Gold |
| Cartes de la carte / generation | Wiki StS — Map Generation | https://slaythespire.wiki.gg/wiki/Map_Generation |
| Ascension — niveaux details | Fandom StS — Ascension | https://slay-the-spire.fandom.com/wiki/Ascension |
| Score | Fandom StS — Score | https://slay-the-spire.fandom.com/wiki/Score |
| Daily Challenge | Fandom StS — Daily Challenge | https://slay-the-spire.fandom.com/wiki/Daily_Challenge |
| Cotes de tirage de cartes (formule exact) | Gaming.StackExchange — card distribution | https://gaming.stackexchange.com/questions/372745 |
| Cotes (tableau complet) | StS Comprehensive Reference PDF | https://www.scribd.com/document/718620802/Slay-the-Spire-Reference |
| RNG interne / correlation | ForgottenArbiter Blog | https://forgottenarbiter.github.io/Correlated-Randomness/ |
| Analyse 18M runs (win-rate, boss fatal) | FoxRow — Statistical Analysis | https://foxrow.com/slay-the-spire-statistical-analysis |
| Win-rate A20H (experts) | Heart Rate — StS Statistics | https://sts1.heart-rate.net/ |
| Win-rate Non-A / A20 (tous joueurs) | GitHub karlo-delacruz | https://github.com/karlo-delacruz-ieds/sts_1_winning_percentage |
| GDC 2019 — metriques & equilibrage | GDC Vault (Giovannetti) | https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics |
| Interview data-driven design | Game Developer (gamedeveloper.com) | https://www.gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder |
| Interview Road to IGF | Game Developer (gamedeveloper.com) | https://www.gamedeveloper.com/game-platforms/road-to-the-igf-mega-crit-games-i-slay-the-spire-i- |
| Information parfaite / intent | Jeremiah Games (2019) | https://jeremiahgames.com/2019/03/04/perfect-information-the-killer-feature-of-slay-the-spire-and-into-the-breach/ |
| Analyse de l'incertitude des cartes | arXiv 2025 (ACM FDG) | https://dl.acm.org/doi/full/10.1145/3723498.3723846 |
| ML + pathing | DiVA Portal — ML pathing | https://www.diva-portal.org/smash/get/diva2:1565751/FULLTEXT02 |
| RNG et difficulte (these) | DiVA Portal — these RNG | https://www.diva-portal.org/smash/get/diva2:1563050/FULLTEXT02.pdf |
| Psychologie mastery | Socratopia — chapters 10, 15 | https://www.socratopia.app/library/game-design-en/chapter-15 |
| Variable rewards | Socratopia — chapter 4 | https://www.socratopia.app/library/game-design-en/chapter-4 |
| Guide Daily Climb (expert) | ericra.com | https://ericra.com/writing/spire_daily.html |
| Win-rate discussion (stats A20H) | Marmle blog | https://marmleflagm.github.io/2022/01/31/winrates.html |
| Pathing (cotes par salle) | KosGames.com | https://kosgames.com/slay-the-spire-map-generation-guide-26769/ |
| Psychologie repetition | Jinners on Medium (2026-01) | https://andrewjinman.medium.com/slay-the-spire-and-the-quiet-psychology-of-repetition-88ae7986d14a |
| Leaderboard design | Yu-kai Chou — Leaderboard Design | https://yukaichou.com/gamification-analysis/leaderboard-design-definitive-guide-octalysis/ |

---

*Redige 2026-06-23 par l'agent love2d-engineer sous mandat roadmap-lab. Lecture seule du
code du jeu. Ne modifie que `docs/roadmap-lab/competitive/slay-the-spire.md`.*
