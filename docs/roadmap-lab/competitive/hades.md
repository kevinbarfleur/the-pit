# Analyse concurrentielle — Hades (Supergiant Games, 2020)

> **Mandat** : BRIEF.md §Analyse concurrentielle — teardown precis de chaque mecanisme →
> psychologie (sourcee) → maths chiffrees et sourcees → verdict de transferabilite a The Pit.
> **Garde-fou** : fichier lecture seule du repo ; ce document vit uniquement sous `docs/roadmap-lab/`.
> **Analogies paresseuses interdites.** Toute affirmation de design cite sa source.

---

## 0. Contexte commercial & pertinence

Hades n'est pas un autobattler : c'est un dungeon-crawler action-roguelite isometrique
a combat en temps reel. La raison de l'analyser n'est donc pas « copions le combat » mais
de dissequer les **mecanismes de retention, de progression, de pacing, et de structure
competitive** qui en ont fait l'un des jeux independants les plus acclamees des annees 2020.

**Chiffres commerciaux** (sources : raijin.gg/app/1145360, levvvel.com/hades-statistics/) :
- ~7,7 M copies vendues sur Steam seul, pic concurrent de 54 240 joueurs
- Revenue Steam estime : 127–304 M$ brut (estimateurs differents) ; net developpeur ~90 M$
- Score Metacritic 93/100 (PC), 98 % positif sur 304 000 avis Steam
- Temps de jeu moyen > 32 h/joueur — indicateur de retention exceptionnel pour un jeu fini

**Lecon preliminaire** : un jeu de 25 $ sans monetisation live, sans daily login, sans gacha,
peut generere un engagement comparable aux titres F2P. Kasavin a explicitement confirme :
*« The game does not have any systems designed to drive repeated engagement, meaning there
aren't daily login bonuses or any of that stuff. We wanted players to keep coming back to
this game only for intrinsic reasons. »* (Vice, 2020 — vice.com/en/article/how-hades-made...)

---

## 1. La boucle principale — anatomie precise

### 1.1 Structure des runs

Une run de Hades traverse 4 biomes (Tartarus → Asphodel → Elysium → Temple of Styx),
chacun conclue par un boss. Depuis les donnees de speedrun et d'analyse (miguelmarinheiro.com,
bayjinger.com/2021/03/24/hades-2020/) :

| Biome | Salles en jeu | Bibliotheque disponible | Couverture par run |
|-------|--------------|------------------------|-------------------|
| Tartarus | 12 | 24 | 50 % |
| Asphodel | 6 | 11 | 54 % |
| Elysium | 8 | 13 | 61 % |
| Styx | variable | variable | — |

- Duree de la premiere salle de Tartarus (biome 1) : **6–8 minutes** (biome entier)
- Duree moyenne d'une salle combat : **~30 secondes**
- Frequence de choix de boon : **toutes les ~40 secondes** en moyenne
- Difficulte progressive : **+25 % par salle** environ, avec pics sur mini-boss et boss
- Premiere clear d'un joueur mediant : **~40 minutes** (speedrun WR : 5 min 57 s IGT)

Source : *miguelmarinheiro.com/2024/11/24/hades-small-analysis/*,
*bayjinger.com/2021/03/24/hades-2020/*

### 1.2 Anatomie d'un run : les couches de decision

```
RUN
 ├─ Keepsake pre-run (1 artefact equipe → controle du 1er dieu OU bonus de survie)
 ├─ BIOME x 4
 │   ├─ Salle combat (30 s) → reward (3 choix de porte avec icone de recompense)
 │   │   ├─ Boon dieu (le plus recherche → shape du build)
 │   │   ├─ Marteau Daedalus (upgrade arme, change fondamentalement le moveset)
 │   │   ├─ Pom of Power (niveau un boon existant)
 │   │   ├─ Or, Centaur Heart (PV max), Nectar, Gemmes
 │   │   └─ (meta) : Chthonic Keys, Darkness
 │   ├─ Mid-shop (salle obligatoire ~milieu de biome → achat avec oboles)
 │   ├─ Chaos Gate (optionnel : debuff temporaire → boon chaos unique)
 │   └─ Boss fight → bounty (Diamond/Titan Blood/Ambrosia) si Heat actif
 └─ Mort → retour House of Hades
     ├─ Dialogue NPC (new lines chaque run)
     ├─ Mirror of Night (spend Darkness → upgrades permanentes)
     └─ Nouvelle run
```

---

## 2. Mecanisme #1 : Le systeme de Boons

### 2.1 Teardown precis

Les boons sont les **power-ups temporaires en run** octroyees par les dieux olympiens.
Structure du systeme :

**Pool de boons** (source : hades.fandom.com/wiki/Boons, bayjinger.com) :
- **8 dieux standards** : Aphrodite, Ares, Artemis, Athena, Dionysus, Demeter, Poseidon, Zeus
- **2 dieux speciaux** : Hermes (boons generiques), Chaos (boons de Chaos Gates)
- **~150 boons standards** au total
- **28 Duo Boons** (C(8,2) = 28 ; une combinaison pour chaque paire de dieux)
- Chaque dieu a au moins **1 Legendary Boon** (exige des prerequis dans son pool)

**Slots de boon** (source : hades.fandom.com/wiki/Boons) :
- Attack, Special, Cast, Dash, Call : **1 boon par slot** (le nouveau remplace l'ancien)
- Boons de passifs : pas de limite de slot, peuvent s'accumuler

**Rarites** (4 niveaux) :
- Common (blanc) → Rare (bleu) → Epic (violet) → Heroic (rouge)
- Heroic accessible via : exchange d'un Epic boon, Ambrosia Delight d'Eurydice,
  ou Rare Crop de Demeter (qui convertit 1–3 boons en Common, puis +1 rarete par salle)
- Les salles mini-boss et les Erebus gates offrent de meilleurs odds de rarete

**Leveling des boons** (source : steamcommunity.com/sharedfiles/filedetails/?id=2658113414) :
La formule de diminution est approximativement :
```
level 1→2 : +80 % de la valeur de base (pour les boons Attack/Special les plus forts)
level 2→3 : +60 %
level 3→4 : +40 %
level 4→5 : +30 %
level 5→6 : +20 %
level 6+  : +10 % par niveau (plancher lineaire)
```
La rarete et le niveau sont **orthogonaux** : une rarete Rare ajoute une valeur fixe par tier
(independamment du niveau). Par exemple Heartbreak Strike : +15–25 de %, indifferent au niveau.

**Couple boon × Pom of Power** :
- Pom standard : +1 niveau au choix parmi 3 (prix shop : 100 oboles)
- Pom de Styx : +2 niveaux
- Pom Slice : +1 niveau aleatoire (prix : 50 oboles)
- Les premiers 2–3 niveaux donnent les effets les plus importants → diminution ensuite

### 2.2 Duo Boons : la mecanique de payoff

Condition : posseder **au moins 1 boon qualifiant** de **chacun** des 2 dieux paires.
Le duo peut etre offert par l'un ou l'autre dieu. Prerequis variables selon le duo
(certains exigent un type specifique : Attack boon d'un dieu + n'importe quoi de l'autre).

Exemple de duo influential : **Exclusive Access** (Dionysus + Poseidon) → tous les boons
trouves sont desormais Epic minimum pour la rest du run. Build-defining majeur.

Chances d'obtenir un duo augmentees par : keepsakes de dieu, Mirror talent *Gods' Legacy*
(+1 % par rang, max +10 %), Refreshing Nectar d'Eurydice, Yarn of Ariadne (Well of Charon).

Source : *hades.fandom.com/wiki/Duo_Boons*, *orlp.github.io/hades-boons/duo_boons.html*,
*hadesguides.com/hades/guides/legendary-duo-boons*

### 2.3 Psychologie

**Variable-ratio reinforcement** (source : socratopia.app/library/game-design-en/chapter-4) :
Skinner a decouvert en 1938 que le schedule de renforcement a ratio variable est le plus
persistant jamais observe. Hades l'applique sans monetisation : chaque salle offre 1–3
portes avec recompenses differentes → le joueur ne sait **jamais** ce qui vient. C'est
la meme structure que les slot machines, mais l'agentivite est reelle (connaissance du
systeme → decisions informees).

**Near-miss sous agence** : la cle du « one more run » dans Hades n'est pas un near-miss
accidentel (comme les slots) mais un near-miss **subi avec agence** — le joueur comprend
**pourquoi** il a presque reussi et ce qu'il aurait du faire differemment. Kasavin confirme :
*« every run counts — the player is accruing knowledge about how the world functions. »*
(Vice, 2020)

**Anticipation de duo** : une fois le player a un boon de Zeus et un de Poseidon, chaque
salle devient un pari conscient pour Sea Storm. L'anticipation active le meme circuit que
l'attente d'une recompense certaine, mais avec l'incertitude du timing. Cela prolonge
l'engagement sans frustration car le joueur a **controle** (il peut forcer via keepsake).

**Competence growth** (source : itch.io/blog/774695/to-hell-and-back-again) : la structure
en loops de Hades — boon choice toutes les 40 s — cree une cadence reguliere de micro-decisions
qui font sentir le joueur de plus en plus competent au fur et a mesure des runs.

### 2.4 Maths du pool

Le systeme de distribution des boons n'est pas simplement aleatoire : il respecte la formule
de MetaProgressRatio (source : hades.fandom.com/wiki/Chamber_Reward) :

```
metaProgressChance = targetRatio + 10 × (targetRatio - currentRatio)
```
Avec `targetRatio` different par biome (Tartarus ~0,45 ; Asphodel ~0,4 etc).
Si le ratio d'acces aux meta-recompenses (Darkness, Keys, Gems) est trop bas, la prochaine
salle sera plus probable de donner une meta-recompense. Cela garantit une distribution
**reguliere** entre meta (permanente) et run (temporaire). **C'est une balance garantie,
pas un RNG pur.**

### 2.5 Verdict de transferabilite a The Pit

**Ce qui survit** : le principe de **choix 1-parmi-N a chaque etape** (nos reliques toutes
les 3 combats) est deja present et solide. La rotation de 3 candidats est directement
analogue. Le ratio variable d'anticipation est enclenche.

**Ce qui ne survit pas directement** : la frecuence de decision. Hades offre un choix de
boon toutes les 40 secondes. Nos runs sont structurellement differentes : phase de build
(boutique, drag-drop) + combat auto (spectateur). L'equivalent est la **boutique entre
rounds** — chaque round est notre « salle ». La frequence de choix impactants est donc
environ 1 par round (boutique), soit environ 15–20 fois par run complete. Plus rare que
Hades, mais structurellement identique.

**Analogie paresseuse a demontir** : « ajoutons des boons mid-combat » — hors-budget et
contre-pilier (sim deterministe ; le combat est en spectateur, pas joueur-actif).

**Adaptation recommandee** : le principe psychologique *valide* est la construction
anticipative de synergies. Dans The Pit, cela correspond a l'**anticipation de l'aura
d'adjacence** (je pose ma creature au centre pour recevoir les buffs de ses 4 voisins) et
a l'**anticipation de la relique** (je construis un build poison en sachant qu'une relique
ampli-poison peut apparaitre tous les 3 combats). Ce qui nous manque par rapport a Hades :
un signal explicite du « payoff a venir » (le duo boon visible dans le pool de god). Ajouter
une UI qui montre « vous etes a 1 relique de l'offre suivante » ou un compte de combats restants
avant la prochaine offre de relique est notre analogue direct — pas d'implementation boon mid-run.

---

## 3. Mecanisme #2 : Le Mirror of Night (meta-progression permanente)

### 3.1 Teardown precis

Le Mirror of Night est la couche de **progression permanente cross-run** de Hades.
Source : hades.fandom.com/wiki/Mirror_of_Night, soloplayguide.com/games/hades/miscellaneous/mirror-of-night

**Structure** : 12 slots, chacun avec 2 versions (rouge et verte — alternees debloquees
apres dialogue avec Nyx, exige min. 300 Darkness collectees). Un seul actif a la fois.
Debloquage progressif via Chthonic Keys :

| Cout Chthonic Keys | Talents debloquees |
|--------------------|--------------------|
| 0 (4 gratuits) | Shadow/Fiery Presence, Chthonic Vitality/Dark Regen, Death/Stubborn Defiance, Greater/Ruthless Reflex |
| 5 | Boiling Blood/Abyssal Blood, Infernal/Stygian Soul |
| 10 | Deep/Golden Touch, Thick Skin/High Confidence |
| 20 | Privileged/Family Favorite, Olympian Favor/Dark Foresight |
| 30 | Gods' Pride/Gods' Legacy, Fated Authority/Fated Persuasion |
| **Total : 130 Chthonic Keys** | pour tous les debloquages |

**Cout en Darkness pour maxer tout** :
- Talents rouges seuls : ~18 800 Darkness
- Talents verts : ~16 565 Darkness
- Total (sans Fated Authority/Persuasion) : ~35 365 Darkness

**Talents les plus impactants pour le run** (source : hadesguides.com/hades/guides/mirror-of-night) :
- Death Defiance (3 rangs) : 1 revive par rang, restaure 50 % HP (cout total : 1 530 D)
- Stubborn Defiance (alternatif) : 1 revive par salle (30 % HP)
- Gods' Legacy : +1 % chance Duo/Legendary par rang (max +10 %, cout : 2 500 D total)
- Gods' Pride : +1 % rarete des boons (max +10 %, cout : 1 500 D total)
- Fated Authority : reroll la recompense d'une salle (1 de par rang, max 8 des ; cout TRES eleve)
- Fated Persuasion : reroll les offres de boon/Well (1 de par rang, max 4 des ; cout : 41 000 D)

### 3.2 Psychologie

**Courbe d'investissement lente mais reguliere** (source : machinations.io/articles/what-deconstructing...) :
La simulation de Machinations sur 1000 runs montre une courbe en S d'amelioration — les
premiers runs sont difficiles (wall de la premiere salle de Tartarus), puis un decrochage
rapide une fois les premiers death-defiance et upgrades passes. Chaque run echoue fait
sentir le progres (Darkness accumulee, Keys, nouveau talent). C'est le modele *investment
delay* : l'amelioration prend du temps, ce qui force des runs supplementaires.

**Cout d'opportunite vs agence** : la decision de dépenser les 130 Chthonic Keys dans l'ordre
ideal cree un sous-jeu de gestion de ressources rares. La limite de Fated Authority/Persuasion
(tres couteux) cree un sentiment de puissance rare lorsqu'il est utilise — *l'objet precieux
qu'on tient en reserve*.

**Structure duale rouge/verte** : le fait que chaque talent ait 2 versions mutuellement
exclusives cree des decisions d'**identite de build** permanentes, pas juste de cout. « Je
suis un joueur Death Defiance ou Stubborn Defiance ? » Cette question perdure cross-runs et
cree une identite de playstyle persistante.

### 3.3 Maths clef

La spirale de progression peut etre modelisee : un run moyen donne environ 100–200 Darkness
(tres variable, 45 % des rooms en Tartarus donnent meta-recompenses). Pour maxer le mirror
complet a 35 365 D : ~180–360 runs. Ce volume est **intentionnel** — Hades est concu pour
200 h de jeu median.

### 3.4 Verdict de transferabilite a The Pit

**Ce qui survit** : la **meta-progression permanente** est notre Grimoire (reliques apprises
cross-run) + les futurs systemes de compte (synergies par TYPE non encore implemente).
Le principe mecanique est valide : chaque run echec contribue a la resource permanente.

**Ce qui ne survit pas directement** : Hades a une meta-progression tres dense (130 keys,
35 000 Darkness, 12 slots, 24 variants) car son jeu vise 200 h. Notre run cible est de
**10 victoires** — un run individuel a 10–20 min (Batomon-style), completion de la meta en
quelques heures. Une meta-progression aussi profonde n'a pas sa place dans ce modele.

**Adaptation recommandee** : notre Grimoire est notre mirror — mais **lisible et concis**.
L'analogie psychologique valide est : chaque relique apprise dans le Grimoire est un
*permanent unlock* qui reduit la friction future (je reconnais la relique, je sais son effet,
j'optimise ma decision de take/skip plus vite). Ce n'est pas un bufing de stats mais un
**buff de decision-making** — ce qui respecte notre pilier « sim deterministe ». A ne pas
confondre avec la meta-progression TFT (deblocage de cosmetics), ni avec la meta Hades
(deblocage de puissance brute).

**Signal d'alarme** : ajouter des stats permanentes cross-run (ex. +5 % de PV de base
apres 10 runs) tuerait le determinisme et l'integrite des snapshots async. La meta doit
rester **connaissance** (Grimoire), pas **puissance** (incompatible avec pilier #2).

---

## 4. Mecanisme #3 : Pact of Punishment / Heat (structure competitive)

### 4.1 Teardown precis

Le Pact of Punishment est le systeme d'**endgame et de structure competitive** de Hades.
Deverrouille apres la 1ere victoire (ou disponible depuis le debut en Hell Mode).
Source : hades.fandom.com/wiki/Pact_of_Punishment, truetrophies.com/game/Hades/walkthrough/7

**15 conditions disponibles** (certaines multi-rangs), chacune augmente la **Heat** :

| Condition (selection) | Rangs | Heat | Effet |
|-----------------------|-------|------|-------|
| Hard Labor | 5 | 1/rang (5 total) | +20 % degats ennemis/rang (max +100 %) |
| Lasting Consequences | 4 | 1/rang (4 total) | -25 % soins/rang (max : zero soin) |
| Jury Summons | 3 | 1/rang (3 total) | +20 % ennemis/rang (max +60 %) |
| Extreme Measures | 4 | 1+2+3+4 (10 total) | modifie les boss fights (nouvelles phases) |
| Calisthenics Program | 2 | 1/rang (2 total) | +15 % HP ennemis/rang (max +30 %) |
| Routine Inspection | 4 | 2/rang (8 total) | desactive 3 talents Mirror/rang (max -12 talents) |
| Forced Overtime | 2 | 3/rang (6 total) | +20 % vitesse ennemis et attaques/rang (+40 %) |
| Tight Deadline | 3 | 1+2+3 (6 total) | timer de 9/7/5 min par biome |
| Benefits Package | 2 | 2+3 (5 total) | elite ennemis avec perks additionnels |
| Damage Control | 2 | 1/rang (2 total) | ennemis ont 1–2 shield (ignore hits initiaux) |
| **Max total Heat** | — | **~63** | all conditions max |

**Economies de la Heat** :
- Les **bounties** (Titan Blood, Diamond, Ambrosia) sont gagnees par boss **a chaque palier
  de Heat** (1 par boss par Heat). Rewards en progression : +1 Heat = nouvelle serie de bounties.
- Le palier est **suivi par arme** : la Heat 3 sur l'epee ne debloque pas les bounties Heat 3
  sur la lance. 6 armes x 20 paliers de bounties = 120 runs incentivees minimum.
- **Seuils cosmetics** : Heat 8, 16, 32 → statues de Skelly (cosmetics pures). Heat 32 est
  considere par Kasavin comme le vrai « fin de jeu » difficile.
- Infernal Gates debloquees a Heat 5, 10, 15 (contenu Erebus bonus).

**Configurations mathematiques** (source : jbsiraudin.github.io/blog/permutations-pact-of-punishment-hades) :
A une Heat donnee k avec n conditions disponibles, le nombre d'arrangements est
C(n+k-1, k-1) — le coefficient binomial. A Heat 10 avec 15 conditions : 1001 configurations.
A Heat 32 : des milliers de configurations valides.

### 4.2 Psychologie

**Autonomie de difficulte personnalisee** (source : polydin.com/hades-game-design/) :
La Heat 16 est un challenge accessible avec de la perseverance. La Heat 32 est « vraiment
douloureuse » selon Kasavin — pas d'achievement officiel pour elle, pour ne pas frustrer les
completionnistes. Ce design **valide des identites differentes** : le casual qui joue a Heat 0
pour l'histoire, le joueur mid-core qui vise Heat 16, et le hardcore qui tente Heat 32+.

**Illusion de complexite, realite de lisibilite** : le binomial a Heat 10 donne 1001
configurations, mais le joueur le percoit comme « 10 points a repartir sur 5–6 curseurs » —
bien en dessous de 10 dans sa tete. Cela cree l'impression d'une profondeur infinie tout en
restant psychologiquement genable. (Source : jbsiraudin.github.io)

**Boucle de collection par arme** : tracker la Heat par arme cree un **systeme de collection**
addictif (completionniste) separe de la ladder de competence. Meme un joueur qui stagne a Heat
3 peut progresser en essayant une nouvelle arme — cela **dissout les murs de competence** en
proposant des axes alternatifs.

**Competitivite communautaire** : les speedrun leaderboards de Hades (speedrun.com/hades)
operent en categorie *Any Heat* (aucun palier requis) et *32 Heat* / *50 Heat* (modes experts).
8 764 runs soumis, 1 886 joueurs. La communaute a invente ses propres categories (Loyalty Card,
Champion, Fresh File) quand les metas officielles se sont stabilisees. Cela prouve que la
structure de Heat est suffisamment riche pour generer des sous-communautes competitives
emergentes.

### 4.3 Verdict de transferabilite a The Pit

**Ce qui survit a nos contraintes** : le principe d'**escalade de difficulte personnalisee
avec economie de collection** est completement transferable. Dans notre contexte async, les
snaphosts sont servis par *tier*. Un systeme de paliers de rank (0 → 5) avec des rewards
deblocables a chaque palier (cosmetics, nouvelles reliques debloquees dans le pool, nouveau
biome) repliquerait ce mecanisme.

**Ce qui ne survit pas** : le suivi de Heat par arme (6 armes x 20 paliers). The Pit n'a
pas d'arme — on a des **sigils** (5) et des **familles DoT** (5). L'analogie naturelle est
de tracker le **rank par sigil** ou par **archetype de build**, ce qui encouragerait a
experimenter differentes topologies plutot que de coller a la croix-carry.

**Point critique pour le ranked async** : Hades n'a pas de MMR. Sa « competitivite » est
**communautaire et volontaire** (speedrun leaderboard externe). Pour The Pit qui vise un
ranked async enclenche, la Heat de Hades donne la structure mais pas le matchmaking. Ce
qu'on prend : l'idee d'un **Palier de Descente** (analogue de la Heat), avec rewards de
collection tangibles a chaque palier, et une categorisation des snaphosts (builds) par palier
— ce qui **est** notre systeme de `serve(version, tier)` dans `snapstore.lua`. La Heat
valide l'architecture snapshot-par-tier qu'on a deja.

---

## 5. Mecanisme #4 : Keepsakes & agency de build (controle du RNG)

### 5.1 Teardown precis

Les Keepsakes sont des **artefacts equipes avant la run** qui modifient la distribution des
boons. Obtenus en donnant du Nectar aux personnages (1 Nectar = 1 Keepsake). Chaque dieu
olympien donne un Keepsake qui garantit la prochaine boon de ce dieu + ameliore les chances
de rarete (+10/15/20 % selon le rang du Keepsake).
Source : hades.fandom.com/wiki/Keepsakes, polygon.com/hades-guide/22661390

**Rangs des Keepsakes** (source : hades.fandom.com/wiki/Keepsakes) :
- Rang 1 (depart) : 0 encounters
- Rang 2 : 25 encounters
- Rang 3 : 50 encounters

**Capacite de swap** : apres l'achat de la mise a jour *Keepsake Collection, Regional* chez
le House Contractor (10 gemmes), le joueur peut changer de Keepsake entre chaque biome
(une fois par passage de biome). Ce swap cree un **meta-jeu de gestion de keepsake** :
« je prends le Keepsake d'Artemis pour garantir un boon crit en Tartarus, puis je switche
sur le Keepsake de Dionysus pour le Duo en Asphodel. »

**Nextar economie** :
- Nectar rate pendant les runs, preserve a la mort
- 149 Nectar total necessaires pour maxer toutes les relations
- Aussi utilise pour upgrades au Wretched Broker

### 5.2 Psychologie

**Reduction de variance percue sans suppression du RNG** : le Keepsake ne garantit pas
le bon boon — il garantit le *dieu*. Le joueur fait encore face a 5–10 boons de ce dieu
dont seulement 3 lui sont offerts, parmi lesquels certains sont off-build. Mais cette
couche de controle transforme le ressenti de « chance aveugle » en « je joue bien ».
C'est la distinction entre **RNG brut** (stressant) et **RNG encadre par l'agentivite**
(stimulant). (Source : polydin.com/hades-game-design/)

**Investissement social comme mecanique** : Nectar → Keepsake couple la relation narrative
(j'aime ce personnage) a l'optimisation (son keepsake est fort pour mon build). Cela cree
un lien emotionnel/mecanique rare : *« I started saving my Nectar specifically for Achilles,
not because his Keepsake was the strongest option, but because I had read about him in the
PJO series. »* (mechanicsofmagic.com, 2026)

### 5.3 Verdict de transferabilite a The Pit

**Ce qui survit** : l'idee de **reduire la variance percue** sans la supprimer est exactement
ce que fait notre systeme de **Fisher-Yates seede** pour les offres de reliques. Le joueur
sait que les candidats varient par palier de victoires (early/mid/late gates) — ce n'est pas
du RNG aveugle.

**Ce qui ne survit pas** : le Keepsake de Hades est du controle de **run en cours** (live).
Nos runs sont async — le joueur ne prend pas de decision pendant le combat. La seule analogie
est le **build pre-combat** (choix de sigil, placement des unites) qui **est** notre keepsake :
une decision pre-run qui modifie la topologie et les synergies.

**Systeme absent chez nous** : nous n'avons pas d'equivalent du **swap de keepsake entre
biomes** — une mini-decision de meta-gestion pendant la run. Equivalent The Pit : pouvoir
changer de sigil **entre rounds** (deja disponible via `[s]`) est notre seule flexibilite
mid-run equivalente. Bien que nous ne puissions pas ajouter de keepsake live, un systeme
de **preparation pre-run** (equiper une relique differente en debut de round) serait
envisageable — mais uniquement si il reste deterministe et pre-committed (pas de decision
mid-combat).

---

## 6. Mecanisme #5 : God Mode — accessibilite comme courbe adaptative

### 6.1 Teardown precis

God Mode : damage resistance permanente, +20 % de base, +2 % apres chaque mort (cap 80 %).
Source : hades.fandom.com/wiki/God_Mode, inverse.com/gaming/hades-god-mode-interview

- Peut etre active/desactive a n'importe quel moment **sans penalite** de contenu
- Les runs God Mode ont leurs records separes (mais les achievements sont conserves)
- Le % acquis est maintenu meme si God Mode est desactive
- Concu en 2019 apres des tests internes

Kasavin : *« God Mode reinforces our belief that the way to approach difficulty settings
may need to be proprietary to the game. It's not a one size fits all solution. »*
(Inverse, 2021)

### 6.2 Psychologie

**Mastery elusive rendue accessible par gradient** : sans God Mode, Hades exige entre 10
et 50 runs pour la premiere victoire selon la competence. Avec God Mode, c'est plus court —
mais le joueur **continue a jouer** car les 2 % par mort sont imperceptibles en temps reel,
mais accumulent une progression tangible. C'est un *gradient de difficulte implicite* : le
jeu s'adapte au joueur sans jamais changer le challenge lui-meme.

**Absence de honte** : pas d'achievement bloque, pas de contenu manque. Cela respecte
le principe selon lequel **l'accessibilite n'est pas une facilite** mais un acces aux
experiences.

### 6.3 Verdict de transferabilite a The Pit

**Ce qui survit** : l'idee d'un **gradient d'accessibilite sans gate de contenu**. Notre
equivalent est deja partiellement present : le filet SAP (+1 vie si premiere perte avant
round 3) cree un filet identique. Notre *God Mode* naturel est le **Pact of Punishment
inversé** — plutot qu'augmenter la difficulte, permettre des paliers de facilite qui ne
bloquent pas le contenu.

**Ce qui ne survit pas** : God Mode de Hades est un malus de degats — adapte a un combat
en temps reel ou le skill du joueur compte chaque frame. Dans The Pit, le combat est **100 %
spec-base** (autobattler deterministe). Le joueur ne peut pas « jouer mieux » dans un combat
deja engage. Notre accessibilite doit passer par le **build** (boutique moins chere, plus
d'offres) et pas par le combat.

**Adaptation recommandee** : un mode « Pit Mitigate » (non-officiel, opt-in) qui reduirait
le cout des rerolls ou augmenterait le gold de base pour les joueurs qui stagnent apres N
defaites consecutives. Garder le determinisme du combat intact — seule la boutique change.

---

## 7. Mecanisme #6 : Narrative loop / personnages NPCs

### 7.1 Teardown precis

Hades a 22 000 lignes de dialogue voicees, scriptes pour reagir au contexte du run
(HP bas a la rencontre d'un boss, nombre de morts, reliques transportees, etc.)
Source : gdcvault.com/play/1026975/Breathing-Life-into-Greek-Myth

Le systeme de narratif conditionnel (Kasavin, GDC Podcast ep 16) :
*« we developed a system that analyses what happens in the game and sees whether it matches
a huge list of events that Greg himself has written. »*

**Chaque mort = nouveau contenu** : les NPCs ont des lignes uniques par run. Nouveau dialogue
debloque a chaque retour, crea un sentiment de progression narrative permanente meme sans
progression de combat.

### 7.2 Psychologie

**Mort desinstitutionnalisee** : Kasavin : *« We wondered, could we make the moment of death
something players almost look forward to, rather than dread? »* (Vice, 2020) Resultat : le
retour au hub est **la recompense** du run echoue, pas la punition. C'est un renversement
psychologique fondamental du genre roguelike.

**Ludonarrative harmony** (source : mkremins.github.io/publications/Hades_FDG2021.pdf) :
Le personnage de Zagreus ne peut litteralement pas mourir — il revient au House of Hades.
La mort narrative du protagoniste est absente : la boucle roguelike est *diegetiquement
justified*. Le joueur ne perd pas — Zagreus essaie a nouveau. Cette coherence fiction/mechanique
reduit la frustration de mort de facon radicale.

**Theorie de la dette narrative** : chaque run cree une « dette » de resolution narrative
(qu'est-ce que Hades va dire cette fois ? Athena m'a envoye un message, que dit-elle ?)
qui tire le joueur vers la prochaine run sans que la mécanique soit manipulatrice.

### 7.3 Verdict de transferabilite a The Pit

**Ce qui survit** : le principe de **mort re-frame** est compatible avec notre univers
grimdark. Dans The Pit, une defaite n'est pas un echec mais une *descente plus profonde*.
L'humilite de The Pit (les entites qu'on invoque pour se battre disparaissent, mais la
connaissance persiste) peut etre thematise : le Grimoire grandit a chaque run, les
reliques apprises survivent. C'est notre version du narrative unlock apres mort.

**Ce qui ne survit pas** : 22 000 lignes de dialogue voice-acted sont hors-budget pour un
solo dev. Notre DA « cryptique » ne necessite pas de dialogue vocal — elle necessite de la
**coherence thematique visuelle** (pixel art procédural, palette grimdark, noms evocateurs).
Notre equivalent du dialogue post-mort est : le flavor text des reliques dans le Grimoire
(« vous avez appris ceci en tombant »), les icons visuels du bestiaire, et l'ecran de fin
de run avec les stats narratives (« entites perdues : 5 / reliques acquises : 2 »).

---

## 8. Structure competitive de Hades — analyse detaillee

### 8.1 Ce qui existe dans Hades

Hades **n'a pas de MMR natif**. Sa structure competitive emergente :

1. **Speedrun leaderboard** (speedrun.com/hades) :
   - Categories : Any Heat (IGT), All Weapons (RTA), 32 Heat, 40 Heat, 50 Heat
   - 8 764 runs soumis, 1 886 joueurs actifs (au 23 juin 2026)
   - Category *Unseeded* (prouver un run sans connaissance de seed) vs *Seeded* (route planned)
   - Meta stabilisee : Adamant Rail (Eris) dominant sur Any Heat, WR ~5 min 57 s IGT
   - Communaute a invente de nouvelles categories quand la meta s'est stabilisee

2. **Heat ladder** (intrinsique au jeu) :
   - Tracking par joueur/arme/palier (20 Heat par arme, 6 armes = 120 runs incentivees)
   - Recompense tangible (Titan Blood, Diamond, Ambrosia) a chaque palier
   - Cosmetiques exclu aux seuils 8, 16, 32

3. **Leaderboards communautaires** (mentionnes dans bayjinger.com) :
   - Heat leaderboards speculatifs sur des formats non-officiels

**Ce que Hades NE fait PAS** :
- Pas de saisons de ranked
- Pas de MMR/ELO
- Pas de matchmaking entre joueurs (single-player pur)
- Pas de classement communautaire in-game

### 8.2 Psychologie du competitive sans MMR

L'engagement « compétitif » dans Hades repose sur **l'adversaire intérieur** : le joueur
se bat contre sa performance passee, son best time, son record de Heat. C'est de la
competitivite intrinsèque, pas extrinsèque. Cela fonctionne car :

1. **L'ennemi est constant** (les boss sont toujours les memes ; la difficulte est predictible)
2. **La progression est visible** (les Darkness/Keys s'accumulent ; le best time est affiche)
3. **Le plafond de skill est obscur** (un joueur a 100 h pense etre bon ; a 200 h il decouvre
   des nouvelles couches de profondeur)

Ce « competitive sans leaderboard » echoue au niveau de The Pit car notre loop vise
explicitement le **ranked async** et l'envie de « grimper ». On ne peut pas se contenter
du competitive intrinsèque.

### 8.3 Verdict de transferabilite — ranked async de The Pit

**Ce que Hades enseigne** sur la structure competitive transferable :

**1. La Heat comme structure de paliers → notre Rang de Descente**
Les paliers de Heat sont une structure de progression **verticale** avec rewards tangibles
a chaque palier. Dans The Pit :
- Palier 0 (Silver Pit) → Palier 5 (Void Abyss) analogue aux Heat 0–32
- Chaque palier debloquerait un pool de snapshots plus difficiles (builds IA plus evolues)
  et des rewards de collection (cosmetics procéduraux, nouvelles reliques dans le pool)
- Le tier de `snapstore.lua` (`serve(version, tier)`) est **l'implementation directe** de
  ce mecanisme — c'est deja prevu architecturalement

**2. Le tracking par arme → notre tracking par archetype/sigil**
Plutot qu'une seule progression globale, tracker : « combien de victoires avec le sigil
anneau ? » ou « combien de victoires avec un build choc ? » cree des incitations a
l'experimentation similaires au tracking par arme de Hades.

**3. L'absence de MMR n'empeche pas la retention**
Hades prouve qu'un jeu tres rejoue n'a pas besoin d'ELO pour creer de l'engagement.
Pour The Pit, le MMR est utile pour le matchmaking de snapshots (ne pas servir un ghost
T5 a un joueur T1), mais pas comme leaderboard visible principal. Le competitive visible
peut etre une **table de gloire locale** (meilleur run, plus longue serie de victoires)
plutot qu'un ELO global — plus simple a implementer et moins stressant.

---

## 9. Postmortem — les limites et failles de Hades

### 9.1 Failles de design connues

1. **Le boon unique dominant** : l'exemple de Divine Dash d'Athena, *« Athena's Divine Dash
   boon is generally considered the strongest boon in the game »* (polydin.com). Sa prevalence
   dans les speedruns (cree une deflection de tous les projectiles a chaque dash) cree un
   meta solved. Dans The Pit, l'equivalent serait une relique ou un archetype dominant —
   notre syst d'outlier detection dans `tools/sim.lua` (lift de co-occurrence) doit capturer ca.

2. **Combat a un bouton** : Hades a ete critique pour etre *« a bit of a one button game »*
   (daarongames.substack.com). Notre sim auto-resolue n'a pas ce probleme — le joueur ne
   button-mashe pas — mais il peut y avoir un equivalents : des builds qui se jouent « en
   pilote automatique » sans decision. Le risque dans The Pit est qu'un build poison domine
   a tel point qu'on ne fait que spammer poison sans penser au placement.

3. **Scaling de la difficulte non-lineaire** : a Heat 32, Kasavin reconnait que le jeu
   devient difficile au point de ne pas meriter d'achievement. Le scaling de Heat n'est pas
   doux — certaines conditions (Lasting Consequences rank 4 = zero soin) sont asymetriquement
   difficiles. Dans The Pit, le scaling des adversaires IA par tier doit etre plus graduel.

4. **La meta speedrun stabilisee** : le WR d'Any Heat est a 5 min 57 s depuis 2020,
   dominant par une arme (Eris Rail). La communaute s'en est adaptee en inventant des
   categories. Dans un autobattler async, la meta se stabilise sur les builds — notre
   contremesure est le versionnement de snapshots (`version` dans le snapshot) qui permite
   de « rotater les sets » comme TFT.

---

## 10. Synthese — les 7 transferts prioritaires pour The Pit

En reseau psychologique/mecanique, de ce que Hades fait et comment s'adapte a nos piliers :

| # | Mecanisme Hades | Psychologie source | Contrainte The Pit | Adaptation precise |
|---|-----------------|---------------------|-------------------|-------------------|
| 1 | Choix de boon toutes les 40 s | Variable-ratio reward, competence growth | Run = phases build/combat separees | Compter les rounds avant la prochaine relique ; signal UI visible du compte (ex. « relique dans 2 rounds »). Analogie directe aux Duo boon prerequisites visibles. |
| 2 | Duo boon = payoff anticipe | Anticipation sous agence | Pas de boon mid-combat | **Synergies par TYPE visibles en boutique** : surligner « si tu ajoutes ce burn a cote de ce bleed, tu actives [Interaction nom] ». Le payoff anticipe existe deja dans nos synergies — il manque le **signal UI** |
| 3 | Mirror of Night progressif | Investment delay, competence grow | Runs courts, no power-carry | Grimoire lisible post-run comme notre miroir : chaque relique apprise = unlock de connaissance. Pas de stat carry. Garder le meta-progression « connaissance », jamais « puissance ». |
| 4 | Heat / Pact of Punishment | Escalade personnalisee, collection | Async snapshots servis par tier | **Palier de Descente** 0→5 avec rewards tangibles par palier. Architecture `snapstore.serve(version, tier)` valide et deja implementee. |
| 5 | Keepsake = controle de distribution | RNG encadre percu comme agence | Pas de decision mid-run | Swap de sigil pre-round comme notre keepsake. **Ajouter la possibility d'equiper une relique differente au debut de chaque round** (pre-committed, sync avec snapshot) |
| 6 | God Mode = gradient d'accessibilite | Mastery elusive, accessible | Combat deterministe (pas de skill actif) | Reduce-friction-run pour joueurs en serie de defaites : +2 or/round apres 3 defaites consecutives (filet SAP + analogue God Mode). |
| 7 | Mort re-framee (house de hades) | Ludonarrative harmony | DA grimdark = descente, pas punition | Ecran post-run : « Round N descente : vous avez perdu X entites, appris Y reliques, la fosse vous attend ». Flavor text grimdark qui re-frame la defaite comme progression mythique. |

---

## 11. Analogies paresseuses a rejeter explicitement

Ces analogies ont ete identifiees comme paresseuses ou hors-contrainte :

| Analogie paresseuse | Pourquoi la rejeter | Quoi a la place |
|--------------------|---------------------|-----------------|
| « Ajoutons des boons mid-combat comme Hades » | Combat auto deterministe, spectateur — le joueur ne prend pas de decision pendant le combat. Violerait le firewall SIM/RENDER. | Les reliques sont nos boons pre-combat. La frequence de 3 combats par offre est notre cadence de payoff. Ajuster la cadence si c'est trop rare. |
| « Copions le keepsake system pour lier narration/mecanique » | Notre DA n'a pas de NPCs voicees. Le link narration/mecanique de Hades exige des lignes contextuelles par situation — hors-budget solo dev. | Flavor text des reliques dans le Grimoire comme substitut narratif. Icons et nombres lisibles suffisent pour l'invest mecanique. |
| « Implemenons un ELO/MMR comme les jeux competitifs » | Hades lui-meme n'a pas d'ELO et maintient 200 h de retention. Un ELO visible augmente le stress d'un format court. | Matchmaking de snapshots par tier (deja code). Leaderboard local « meilleur run de la semaine » optionnel. |
| « La mort reset tout comme Hades » | Dans Hades la mort est un reset complet sauf meta. Nos reliques sont permanentes intra-run ; la mort = fin de run → on recommence. Le build NE SE RESETS PAS a la mort — les unites meurent par combat, le build persiste. C'est notre differenciateur. | Garder notre « vie par entite » (decision #5). La mort d'une unite dans un combat n'est pas un reset — c'est de l'exposition strategique. |
| « Implementons une narrative loop comme Hades » | Hades a une equipe narrative dédiée + 22 000 lignes voicees + studio de 20 personnes. Hors-budget, hors-scope solo dev. | La grimdark procedural art + noms evocateurs + flavor text concis des reliques suffisent a l'ambiance. Les noms d'unites et des reliques portent la fiction. |

---

## 12. Sources

| Source | URL | Mecanisme cite |
|--------|-----|----------------|
| Hades Wiki — Chamber Reward | hades.fandom.com/wiki/Chamber_Reward | MetaProgressRatio formule |
| Hades Wiki — Boons | hades.fandom.com/wiki/Boons | Rarites, slots, echanges |
| Hades Wiki — Mirror of Night | hades.fandom.com/wiki/Mirror_of_Night | Tous les talents, couts |
| Hades Wiki — Pact of Punishment | hades.fandom.com/wiki/Pact_of_Punishment | Heat, conditions, bounties |
| Hades Wiki — Keepsakes | hades.fandom.com/wiki/Keepsakes | Keepsake ranks, swap |
| Hades Wiki — God Mode | hades.fandom.com/wiki/God_Mode | 20 % + 2 %/mort, cap 80 % |
| Hades Wiki — Duo Boons | hades.fandom.com/wiki/Duo_Boons | 28 duos, prerequis |
| Raijin.gg — Hades | raijin.gg/app/1145360/Hades | 7,7 M copies, 304 K avis |
| Levvvel — Hades statistics | levvvel.com/hades-statistics/ | Peak 54 240 concurrent |
| Vice — Kasavin interview | vice.com/en/article/how-hades-made... | « every run counts », God Mode |
| Inverse — God Mode | inverse.com/gaming/hades-god-mode-interview | 20 %+2 %/mort, Kasavin |
| Polydin — Hades Game Design | polydin.com/hades-game-design/ | Heat 16/32, Divine Dash meta |
| Miguel Marinheiro — Hades Analysis | miguelmarinheiro.com/2024/11/24/hades-small-analysis/ | 30 s/salle, 40 s/boon, 25 %/salle |
| Bayjinger — Hades 2020 | bayjinger.com/2021/03/24/hades-2020/ | Biome structure, 14 salles Tartarus |
| JB Siraudin — Permutations Pact | jbsiraudin.github.io/blog/permutations-pact-of-punishment-hades | C(n+k-1,k-1), binome |
| JB Siraudin — Arrangements Hades | jbsiraudin.github.io/blog/arrangements-hell-hades | 50/54/61 % coverage par biome |
| GDC Podcast — Kasavin Ep 16 | gamedeveloper.com/design/roguelikes-and-narrative-design-with... | « narrative roguelike », every run |
| Steam Guide — Pom Power | steamcommunity.com/sharedfiles/filedetails/?id=2658113414 | Formule diminution boon +80/60/40/30/20/10 % |
| TrueTrophies — Pact of Punishment | truetrophies.com/game/Hades/walkthrough/7 | Table complete Heat/conditions |
| RPGSite — Heat Guide | rpgsite.net/feature/10287-hades-pact-of-punishment-heat-modifiers... | Systeme de bounties par arme |
| Speedrun.com — Hades | speedrun.com/hades | 8 764 runs, 1 886 joueurs, WR |
| Speedrun.com — Routed Runs | speedrun.com/hades/guides/jxpkj | Categories Seeded/Unseeded |
| Socratopia — Variable Ratio | socratopia.app/library/game-design-en/chapter-4 | Skinner, roguelikes, variable ratio |
| Itch.io — Loops & Arcs | itch.io/blog/774695/to-hell-and-back-again | Narrative loop, runs cycles |
| Academic — FDG2021 | mkremins.github.io/publications/Hades_FDG2021.pdf | Ludonarrative harmony, theatricality |
| Medium — UX of Hades | medium.com/@isaperucho/the-ux-of-hades-e60cfe489265 | Novelty, control, quick rewards |
| Machinations.io — Hades model | machinations.io/articles/what-deconstructing-supergiants-hades-taught-me | Simulation courbe en S, 8 M heures |
| Orlan P — Duo Boons tool | orlp.github.io/hades-boons/duo_boons.html | Prerequis complets duos |
| Haar on Games — Boon Design | daarongames.substack.com/p/hades-vs-hades-ii-boon-design | Critique Hades II vs I, identite dieu |
| Access-Ability — God Mode | access-ability.uk/2022/04/25/hades-god-mode-is-a-great-approach... | God Mode + Pact of Punishment interplay |
| Mechanics of Magic — Critical Play | mechanicsofmagic.com/2026/05/11/critical-play-hades-2/ | Nectar/keepsake, « caring = getting better » |
| SoloPlayGuide — Mirror of Night | soloplayguide.com/games/hades/miscellaneous/mirror-of-night | Table complete talents + couts |
| Hadesguides — Pact | hadesguides.com/hades/guides/pact-of-punishment | Progression Heat par arme, strategie |
| Hadesguides — Mirror | hadesguides.com/hades/guides/mirror-of-night | Strategie d'ordre d'achat |
| Hadesguides — Duo/Legendary | hadesguides.com/hades/guides/legendary-duo-boons | Strategie de chasse Duo |
| Kotaku — Level Design | kotaku.com/hades-level-design-is-less-random-than-it-seems-1845254545 | Philosophie level design Gorinstein |
| Kotaku — Endgame | kotaku.com/everything-you-need-to-know-about-hades-endgame-1845239105 | Pact of Punishment detail |
| Academic — Frustration study | ar5iv.labs.arxiv.org/html/2401.14878 | Near-miss & frustration tolerance |

---

*Redige le 2026-06-23. Lecture seule du repo. Ce fichier vit dans `docs/roadmap-lab/competitive/`.
Ne jamais modifier le code du jeu a partir de ce document.*
