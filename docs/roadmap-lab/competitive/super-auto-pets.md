# Super Auto Pets — Analyse ultra-approfondie (teardown → psychologie → maths → verdict)

> **Gardien de lecture** : ce fichier n'édite aucun code du jeu. Toute référence à The Pit est
> un **verdict de transférabilité** — pas une instruction d'implémentation. Les chiffres SAP
> sont sourcés ; les verdicts d'adaptation respectent les 4 piliers (async snapshots / sim
> déterministe seedée / DA grimdark / pixel art procédural) et les 10 décisions définitives
> (`docs/roadmap-lab/00-state.md §1`).
>
> Sources primaires : `superautopets.wiki.gg`, `superautopets.fandom.com`,
> `en.wikipedia.org/wiki/Super_Auto_Pets`, notes de patch officielles (v0.28, v0.40, v0.41,
> v0.44), analyses `a327ex.com/posts/super_auto_pets_mechanics`,
> `twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/`,
> `threadreaderapp.com/thread/1523357117805072385.html` (Fabian Fischer / Ludokultur),
> `mobilegamereport.com/articles/super-auto-pets-depth-vs-casual-2026`.

---

## 0. TL;DR de synthèse (lire avant tout)

Super Auto Pets n'est pas notre référence parce qu'il est "simple". Il est notre référence
parce qu'il a résolu **trois problèmes structurels** que The Pit doit aussi résoudre :

1. **Comment fabriquer du multijoueur sans serveur temps réel** — la réponse est les snapshots
   async (pilier identique).
2. **Comment rendre un autobattler jouable "whenever"** — supprimer le timer et les obligations
   sociales ; la boucle 10-victoires / N-défaites.
3. **Comment créer de la profondeur émergente sans complexité de règles** — trigger/effect
   orthogonal sur 5 slots linéaires.

Les mécanismes SAP qui ne survivent **pas** à nos contraintes (run de 12+ turns vs 10 victoires,
boutique à prix fixe, streak d'or) sont identifiés et **remplacés** par des équivalents déjà
présents ou planifiés dans The Pit. On ne copie pas SAP ; on comprend pourquoi il fonctionne
pour vérifier que nos propres solutions répondent aux mêmes besoins psychologiques.

---

## 1. Boucle cœur : teardown précis

### 1.1 La structure en deux phases

SAP = une alternance stricte **shop phase → battle phase**, répétée jusqu'à 10 victoires ou
perte de toutes les vies. Aucune phase de transition, aucun tableau intermédiaire. La boucle
est **binaire** : build ou spectateur.

**Shop phase :**
- Durée : **illimitée** en Arena (pas de timer). Timer de 90 s en Versus 8 joueurs
  (v0.29 — `superautopets.wiki.gg/wiki/Version_0.29`).
- Or : **10 or fixe/round**, non reporté d'un round à l'autre. Pas de banque, pas d'intérêt.
  (`superautopets.wiki.gg/wiki/Gold` : "10 is gained each turn, but does not carry over turns").
- Boutique : **3 à 6 slots pets + 1 à 2 slots food**, selon le tier du round. Reroll = **1 or**.
  Freeze gratuit (items gardés jusqu'au prochain reroll ou round).
- Prix : **tous les pets = 3 or**, tous les foods = **3 or** sauf Sleeping Pill = **1 or**.
  (`The Basics, superautopets.wiki.gg` : "A player can buy a Pet for three Gold").
- Vente : **1 or par niveau** du pet (L1 = 1 or, L2 = 2 or, L3 = 3 or).
- Leveling : **fusion 3 copies** du même pet → niveau supérieur. Max niveau 3. Effet bonus :
  apparition immédiate d'un pet du tier suivant dans la boutique.

**Battle phase :**
- Résolution **100 % automatique**, zéro input.
- Ordre d'attaque : **rightmost pet** du joueur frappe le **leftmost pet** de l'adversaire.
  L'ordre entre pets du même camp = par valeur d'attaque décroissante (initiale, pas modifiée
  par les buffs temporaires).
  (`twoaveragegamers.com` : "The animal with the highest attack stat will trigger its ability
  in battle first").
- Résolution : les pets faintent (hp → 0), le suivant avance. Fin = un camp sans surviving pets.
- Résultat : victoire → +1 trophée ; défaite → -1 vie ; draw → rien.

**Cold-start & fallback IA :**
- Si aucun autre joueur n'est au même turn, le système sert une **équipe IA générée**.
  (`en.wikipedia.org/wiki/Super_Auto_Pets` : "Players battle against either other players'
  teams, or AI-generated teams, if there are no players at that turn").

### 1.2 Objectif et condition de victoire

- **Win** : 10 trophées (10 victoires).
- **Loss** : 0 vies restantes.
- Vies initiales : **5 en Normal**, **7 en Easy**, **5 en Hard**.
  (`The Basics, superautopets.wiki.gg/wiki/The_Basics`).
- **Filet anti-tilt** : au round 3, si le joueur a déjà perdu une vie, il en regagne une.
  ("On turn 3, if a player has lost a life point in the previous 2 turns, they regain one life
  point" — `en.wikipedia.org/wiki/Super_Auto_Pets`).

---

## 2. Économie : les maths chiffrées

### 2.1 Budget or par round

| Action | Coût |
|--------|------|
| Or disponible/round | **+10** (fixe, non reporté) |
| Acheter un pet | **3 or** |
| Acheter de la food (sauf Sleeping Pill) | **3 or** |
| Sleeping Pill | **1 or** |
| Reroll boutique | **1 or** |
| Vendre un pet L1/L2/L3 | **+1/+2/+3 or** |

**Budget type d'un round** : avec 10 or, on peut acheter **3 pets** (9 or), ou **2 pets + 2
rerolls** (8 or), ou **1 pet + 1 food + 2 rerolls** (8 or). La contrainte est dure : on ne peut
jamais tout acheter en une seule vue de boutique. (`twoaveragegamers.com` : "You can't carry
over any gold between rounds so you should make sure to take full advantage").

**Absence totale de mécanisme de streak d'or** : contrairement à TFT (qui donne +1/+2/+3 or en
streak, `tft.ninja/guides/strategy/win-streaking`), SAP Arena **n'a pas de bonus d'or par
victoire ou défaite consécutive**. L'or est strictement fixe. Toute asymétrie économique doit
être construite via des **pets à capacité économique** (Swan : +1/2/3 or au début du tour ;
Hamster : +1 or par reroll ; Goat : +1 or par achat d'ami ; Weasel : +1/2/3 or au faint ; etc.)
— `superautopets.wiki.gg/wiki/Gold`.

**Pourquoi l'absence de streak d'or est un choix fort** : dans TFT, le streak d'or crée un
deuxième axe de décision économique (jouer pour le streak ou sacrifier du tempo) et une source
de snowball asymétrique. SAP refuse cette complexité pour rester dans l'identité "chill" et
garantir que chaque joueur part exactement du même point d'or chaque round. La profondeur
économique de SAP passe entièrement par les **pets à capacité économique** et le **gel de
boutique**.

### 2.2 Escalade de tiers (gating des rangs de pets)

SAP divise ses pets en **6 tiers**. L'accès s'ouvre automatiquement tous les 2 turns :

| Turn | Tiers accessibles |
|------|-------------------|
| 1-2 | Tier 1 seulement |
| 3-4 | Tiers 1-2 |
| 5-6 | Tiers 1-3 |
| 7-8 | Tiers 1-4 |
| 9-10 | Tiers 1-5 |
| 11+ | Tiers 1-6 (max) |

(`The Basics, superautopets.wiki.gg` : "the shop tier upgrades on every odd-numbered turn").
Formule : tier X accessible au turn `2X - 1`.

**Accès anticipé** : levelup d'un pet → apparition **immédiate** d'un pet du tier suivant dans
la boutique. C'est l'unique moyen d'accéder à un tier avant son turn naturel.
(`twoaveragegamers.com` : "leveling up your pets on odd-numbered turns gives you a power spike
since you'll get a bonus pet from the newly unlocked Tier").

### 2.3 Table de cotes (Turtle Pack, pack de base)

SAP tire ses pets avec une **probabilité uniforme par pet dans les tiers accessibles**. La cote
d'apparition d'un pet spécifique par slot de boutique dépend du nombre de pets dans le pool :
Turtle Pack = **60 pets** répartis sur 6 tiers. (`en.wikipedia.org/wiki/Super_Auto_Pets` :
"This pack includes 60 pets and 16 food items").

Tiers Turtle Pack (environ 10 pets/tier sur 6 tiers = 60 total) :

| Turn | Cote par pet/slot (T1) | Cote shop entier (T1) |
|------|------------------------|----------------------|
| 1-2 | **10,0 %** | **27,1 %** |
| 3-4 | 5,0 % | 14,3 % |
| 5-6 | 3,3 % | 12,7 % |
| 7-8 | 2,5 % | 9,6 % |
| 9-10 | 2,0 % | 9,6 % |
| 11+ | 1,7 % | 8,1 % |

(`superautopets.fandom.com/wiki/Roll_Chances` : table complète vérifiée).

**Lecture** : à T1-2, la cote de voir un pet Tier 1 spécifique est 10 % par slot. Quand le pool
grandit (Tiers 2+ ajoutés), la dilution réduit mécaniquement les cotes. Ce n'est **pas** un
système de probabilités séparées par tier (à la TFT) — c'est un tirage **uniforme dans tout
le pool accessible**. Conséquence : en late game (T11+), un pet T6 est aussi probable qu'un
pet T1 dans un slot donné. La rareté perçue des hauts tiers est une **illusion arithmétique
due à la dilution**, pas un système de probabilité explicite.

**Maths de pool complet (T11+, Turtle Pack)** : 60 pets dans le pool, 5 slots de shop.
Probabilité de voir un pet spécifique dans au moins un slot : `1 - (59/60)^5 ≈ 7,9 %`.
Conforme aux 8,1 % de la table (écart dû à l'échantillonnage sans remise).

### 2.4 Fusion et leveling : maths

**3 copies → niveau 2** (via fusion ou chocolate). **3 nouvelles copies → niveau 3** (cap).
Stats à la fusion : **+1 sur la plus haute des deux** pour chaque stat (attaque et santé).
(`twoaveragegamers.com` : "the game will add +1 to the higher of both the health and attack
stat").

**Coût de montée au niveau 3** : 3 copies à 3 or chacune = **9 or** pour L2, puis 3 nouvelles
copies = **9 or** pour L3. Total : **18 or** pour un L3 pur (sans food). Valeur de vente L3 :
**3 or** (refund de 3/18 = 17 % de l'investissement). C'est délibérément bas pour punir les
pivots tardifs et inciter à s'engager.

---

## 3. Snapshot async : teardown technique

### 3.1 Le mécanisme exact

SAP Arena sélectionne pour chaque round un adversaire depuis **une base de plateaux d'autres
joueurs au même turn**. La résolution du combat se fait **localement** sur le client ; le
snapshot adverse ne répond pas, ne réagit pas, ne voit jamais le résultat.
(`The Basics, superautopets.wiki.gg` : "the game selects an opponent from a database of teams
created by other players on the same turn and matches them against the player's team").

**Caractéristiques du snapshot SAP :**
- Clé de matching : **numéro de turn** (progression).
- Granularité : le plateau entier à la fin du build (5 pets max + positions + levels).
- Un même snapshot peut servir à **plusieurs adversaires**.
- Le résultat du combat ne modifie **jamais** le snapshot adversaire.
- Si aucun snapshot disponible → **équipe IA** générée comme fallback.

### 3.2 Différence importante : pas de rang en Arena

En Arena Mode, le matching est **uniquement par turn** — il n'y a pas de MMR. N'importe qui
au même turn peut vous être envoyé. Le rang (ELO) n'existe qu'en **Versus Mode** (ajouté en
v0.28, septembre 2023 — `superautopets.wiki.gg/wiki/Version_0.28`).

**Conséquence** : la variance est haute. Un débutant peut affronter un build expert au même
turn. C'est un choix délibéré de SAP pour l'aspect "chill/casual" d'Arena. La compétitivité
est déportée en Versus.

### 3.3 Async Versus (v0.28+)

Ajouté en v0.28 (3 septembre 2023) : possibilité de jouer plusieurs matches Versus en
**simultané** avec des timers allant de **2 minutes à 3 jours** par turn.
(`superautopets.wiki.gg/wiki/Version_0.28` : "Asynchronous versus matches means that you
will be able to play multiple versus matches at the same time, with turn timers ranging from
2 minutes to 3 days").

---

## 4. Structure compétitive / Ranked

### 4.1 Versus Mode — deux formats

SAP sépare strictement le casual (Arena) du compétitif (Versus) :

| Mode | Format | Timer | Vies | Matchmaking |
|------|--------|-------|------|-------------|
| Arena | async, turn-based | Aucun | 5 (Normal) | Par turn uniquement |
| Versus 1v1 | async ou real-time | 2 min à 3 jours | 6 | ELO |
| Versus 8j | real-time | 90 s/turn | 6 | Lobby |

### 4.2 ELO / Ranked

**Démarrage** : ELO 1500 (Wikipedia) ou 1000 (notes de patch v0.28) — les deux sources
diffèrent légèrement selon la version. Score ajusté après chaque partie selon le score de
l'adversaire (Elo classique). (`en.wikipedia.org/wiki/Super_Auto_Pets` : "Every player starts
out with a score of 1500 and will either lose or gain points upon loss or win").

**Restrictions** :
- Ranked = **standard packs uniquement** (Turtle, Puppy, Star, Golden, Danger). Weekly et
  Custom packs exclus. Motif : "not balanced for competitive play"
  (`superautopets.wiki.gg/wiki/Version_0.28`).
- Un **seul rang partagé** entre tous les packs standard (décision simplificatrice initiale
  documentée par les devs).

**Saisons** : ajoutées en **v0.41** (21 juillet 2025).
(`superautopets.wiki.gg/wiki/Version_0.41` : "Added seasons for versus"). Leaderboard weekly
pack réinitialisé chaque semaine ; leaderboard des autres packs permanent.

**Decay** : au-dessus de 1800 ELO, perte de **10 pts/jour** après 7 jours d'inactivité.
(`superautopets.wiki.gg/wiki/Version_history` : "+1800 rank players loses 10/day after
7 inactive days").

**Leaderboard 8-player** : ajouté séparément en v0.44 (décembre 2025).
(`superautopets.wiki.gg/wiki/Version_0.44`).

### 4.3 Pack compétitif vs méta mouvante

SAP a résolu le problème de la staleness de méta **sans invalidation de contenu** via le
**Weekly Pack** : chaque lundi, un nouveau sous-ensemble aléatoire de tous les pets disponibles
(9 pets/tier). Leaderboard de Weekly remis à zéro chaque lundi.
(`superautopets.wiki.gg/wiki/Weekly_Pack` : "The Weekly Pack refreshes its contents every
Monday at 12:00 am UTC").

Le résultat : chaque semaine = une nouvelle méta à résoudre depuis zéro. Les vieux packs ne
deviennent pas obsolètes ; le Weekly crée en revanche un **environnement rotatif** où le skill
de "lecture de pool" compte plus que la mémorisation de la méta fixe.
(Ludokultur / Fabian Fischer, twitter thread archivé : "On top of that every weekly brings a
new meta... shuffling the content weekly prevents that").

---

## 5. Psychologie : pourquoi ça hook

### 5.1 La structure fondamentale : agence sous contrainte temporelle

Le hook central de SAP n'est pas le combat automatique — c'est la **phase de build**. Le joueur
exerce une **agence réelle** (quoi acheter, dans quel ordre, gel ou pas, vendre pour pivoter)
dans une **fenêtre de ressources strictement contrainte** (10 or fixe, ~3 achats possibles).
Cette combinaison déclenche un mécanisme connu : le **choix sous contrainte produit plus
d'engagement que le choix libre** (Self-Determination Theory, Deci & Ryan — les décisions
perçues comme "libres mais bornées" maximisent l'engagement intrinsèque).

(`mobilegamereport.com` : "The other half of Super Auto Pets' depth is economic... This is
the same tempo problem that makes Clash Royale strategically interesting").

Le combat automatique est une **récompense différée vérifiable** : on décide, puis on observe
la conséquence. Le gap entre la décision et l'observation est court (~30 s de combat) mais
suffisant pour créer de l'anticipation. Dopamine = pic à l'anticipation du résultat, pas au
résultat lui-même (Berridge & Robinson 2016, cadre "wanting vs liking" — référencé dans
`dl.digra.org/...neuroscience-dopamine`).

### 5.2 Variabilité des builds : "near-miss" sous agence

SAP ne génère pas de near-miss au sens du gambling (résultat aléatoire habillé en presque-victoire).
Il génère une structure psychologiquement plus saine : le **near-miss attribué à la décision**.

Exemple canonique : le joueur manque sa 3e copie d'un pet pour atteindre le niveau 2. Il a vu
2 copies, il savait que la 3e était dans le pool, il a rerollé mais ne l'a pas trouvée. La
prochaine run, il rerollera différemment — ou earlier. Cette attributabilité causale redirige
la frustration vers une **hypothèse d'amélioration**, pas vers le hasard pur.
(`chipsandtruths.com/scholar/loss-chasing-near-misses/` : "A near-miss recasts a loss as
near-success... irritation can be its own engine"). Chez SAP, l'irritation produit "je ferai
mieux la prochaine run" plutôt que "le jeu est truqué".

### 5.3 L'async comme suppresseur de friction sociale

Le timer absent en Arena transforme SAP en jeu "whenever" (Fabian Fischer, @Ludokultur) :
- Pas de lobby à attendre.
- Pas de "contrat social de 30 minutes" avec d'autres joueurs en direct.
- Possibilité de s'arrêter à n'importe quel round et reprendre des heures plus tard.
- L'état de partie est persisté : "No need to remember what you 'were going for'".

Ce n'est pas seulement du confort — c'est une **réduction du coût d'entrée à chaque session**.
En psychologie comportementale, la friction est un inhibiteur de comportement (Fogg Behavior
Model). Supprimer le timer élimine la plus grande friction du genre (l'obligation de terminer
une session).

### 5.4 La découverte combinatoire comme moteur de retour

60 pets (Turtle Pack) × 5 positions × niveaux 1-3 = espace de builds théoriquement immense.
En pratique la plupart des builds convergent vers quelques archetypes, mais chaque run explore
un angle différent. L'explication de `a327ex.com` est précise : "The first ~10-20 hours of
SAP feeling alien to me... until it all started connecting." — la courbe d'apprentissage est
elle-même un moteur de rétention. Chaque semaine de jeu révèle des interactions inconnues.

### 5.5 La boucle 10-victoires : gestion des anticipations

10 victoires = objectif court, clair, atteignable en **10-20 minutes** selon les sources
(`games-genie.com` : "Most arena runs and versus matches finish in 10-20 minutes"). Ce format
crée un arc complet avec un début, un milieu et une fin. Chaque run est un histoire fermée.

Contraste avec TFT (30-45 min/partie) : TFT engage le sunk cost effect (on ne peut pas
s'arrêter "à mi-partie") ; SAP permet d'arrêter après n'importe quel round sans perdre un
investissement significatif. Cette **absence de sunk cost** paradoxalement augmente le taux de
démarrage d'une nouvelle partie.

### 5.6 La méta "forever" : Weekly Pack comme générateur de nouveauté

(Voir §4.3) Chaque lundi, une nouvelle méta = un moteur de curiosité régulier. La structure
Weekly est mathématiquement une **variable reward à cadence prévisible** : on sait que ça
change le lundi (prévisible = pas du gambling), mais ce qui change est imprévisible (curiosité
= reward variable). Cette combinaison est documentée comme optimale pour la rétention long terme
(GDC Vault — Intrinsic and Extrinsic Motivation).

---

## 6. Analyse critique : ce que SAP NE fait pas

### 6.1 Pas de streak d'or (force ou faiblesse ?)

L'absence de streak économique est une **simplification délibérée** de SAP. Dans TFT, la
streak d'or crée un "rich get richer" dynamique que les joueurs avancés exploitent. SAP choisit
l'égalité d'or au détriment de la profondeur économique. Conséquence : la profondeur économique
de SAP passe **entièrement par les pets à capacité économique** (Swan, Goat, Hamster) —
ce qui enrichit le contenu mais ne crée pas d'axe de méta-stratégie économique.

**Critique** : ce choix limite la profondeur de la phase économique pour les joueurs avancés.
SAP lui-même a partiellement comblé ce gap avec des pets économiques, mais c'est contourner
le problème plutôt que le résoudre.

### 6.2 Pas de positionnement 2D (force structurelle)

5 slots linéaires = positionnement de gauche à droite uniquement. L'adjacence n'existe que
dans la position "avant/derrière". La richesse positionnelle est donc limitée aux interactions
"le pet à droite" / "le pet à gauche". SAP compense avec des triggers event-based
(`on_faint`, `on_attack`, `friend_summoned`, `start_of_battle`) qui n'utilisent PAS la position
mais l'événement — ce qui crée une diversité de déclencheurs sans nécessiter de grille 2D.

**Critique pertinente pour The Pit** : The Pit a résolu ce problème différemment et mieux
avec le plateau-graphe 3×3 + adjacence orthogonale + sigils mutables. Le plateau de The Pit
est strictement plus riche positionellement que SAP — c'est un avantage compétitif assumé.

### 6.3 Pas de familles d'effets cross-synergiques

SAP ne possède pas de système d'affliction multi-famille du type poison/burn/bleed/rot/choc.
Les pets SAP ont des triggers discrets et des effets discrets — il n'existe pas d'axe
"amplification de statut cross-famille". La profondeur vient de la **composition de triggers**,
pas de la **composition d'effets de statut**.

C'est un design différent, pas inférieur. Mais c'est une zone où The Pit est structurellement
plus profond par design.

---

## 7. Verdicts de transférabilité à The Pit

> Filtrage par les 4 piliers et les 10 décisions définitives (`00-state.md §1`).

### 7.1 MÉCANISME : Or fixe/round, non reporté

**SAP** : 10 or/round, pas de banque, pas d'intérêt.
**Psychologie** : élimine la décision de gestion de trésorerie inter-round (TFT : "combien
j'économise ?"), concentre l'agence sur *quoi acheter maintenant*. Réduit la charge cognitive
sans réduire la profondeur de décision.
**Maths SAP** : 10 or / 3 or par pet = 3,3 achats max/round. Contrainte dure.

**VERDICT : DÉJÀ FAIT, IDENTIQUE.** The Pit utilise `GOLD_PER_ROUND = 10`, non reporté
(`src/run/state.lua`). Le mécanisme est adopté tel quel. Les streaks d'or du Pit
(`STREAK_CAP = 3`, +1/+2/+3 selon la série) constituent un ajout délibéré au-delà de SAP —
ils sont un axe de profondeur économique qui compense l'absence de SAP. Ce choix est valide
et fondé (décision §9 du `00-state.md` : "or fixe/tour, reroll, leveling = déblocage de
slots, streaks").

### 7.2 MÉCANISME : Gating de contenu par tiers progressifs

**SAP** : tiers 1-6 débloqués automatiquement tous les 2 turns. Pas d'achat requis, juste du
temps. Pool uniforme au sein des tiers accessibles.
**Psychologie** : révélation progressive du contenu = courbe d'apprentissage naturelle +
montée de puissance progressive lisible. Chaque 2 turns = un "ooh nouveau tier" de dopamine.
Le teaser d'un tier supérieur via levelup crée un pull forward.
**Maths** : turn 11 = tous les tiers accessibles. Dans The Pit (run de 10-15 rounds max),
l'équivalent serait accessible naturellement au milieu de la run.

**VERDICT : DÉJÀ ADAPTÉ, ENRICHI.** The Pit utilise un système XP TFT-style
(`BUY_XP_AMOUNT = 4, BUY_XP_COST = 4` — `state.lua`) avec XP passive + achetable. La table
de cotes (`00-state.md §4.3`) est différente de SAP (probabilités par rang, pas pool uniforme)
et plus sophistiquée. Le gating par cotes (pas par slots) est la décision §9. Le mécanisme
psychologique — révélation progressive du contenu — est entièrement transféré.

**Point de vigilance** : SAP débloque un tier ennemi toutes les 2 turns. Dans The Pit, la
progression est par XP. Il faut s'assurer que le rythme perçu de "montée en puissance" est
aussi lisible et régulier que dans SAP. Risque : une boutique tier-5 accessible dès le round 2
via rush XP peut casser la courbe de lisibilité. Le PRD (`progression-economy-prd.md §3.1`)
l'a pris en compte : "un joueur passif atteint ~tier 3 en fin de partie".

### 7.3 MÉCANISME : Async par snapshots (le plus critique)

**SAP** : snapshot = plateau figé (pets + positions + niveaux) matché par turn. Résolution
locale. Fallback IA si pool vide.
**Psychologie** : l'adversaire async est perçu comme un "vrai joueur" sans les frictions du
live (attente, timer, obligations sociales). La variété des adversaires est infinie par
construction. La "peur" de l'adversaire inconnu crée de l'anticipation sans "learned
helplessness" (parce que le résultat est attribuable à son propre build).
**Architecture SAP** : simple table avec
`{snapshot_blob, turn_bucket, version}`. Aucun netcode temps réel.

**VERDICT : DÉJÀ FAIT, COMPATIBLE, SUPÉRIEUR POTENTIEL.**
The Pit a implémenté le pattern exact (`src/net/snapshot.lua`, `src/net/snapstore.lua`) avec
en plus : matching par version **ET** tier, encodage safe (pas de `load()` externe), seed de
déterminisme, `toComp()` pour la conversion positionnelle. Le cold-start IA est garanti
(`snapstore.lua:serveComp` → `aiComp` si vide).

**Limite v1 connue** : les effets aura/relique ne sont pas capturés dans le snapshot. Le
snapshot v1 = unités de base seulement. SAP a le même problème (les buffs temporaires de
combat ne persistent pas dans le snapshot). C'est une limite acceptable en v1.

**Différence clé** : SAP matche par **turn number** (pas de MMR en Arena). The Pit matche par
**tier** (progression dans le run), ce qui est strictement meilleur car plus représentatif de
la puissance réelle du build. Ce n'est pas une analogie paresseuse — c'est une amélioration
du mécanisme.

**Danger à surveiller** : SAP Arena n'a pas de MMR, ce qui génère de la variance haute
(débutants vs experts au même turn). Si The Pit veut éviter ce problème, le matchmaking par
tier doit être suffisamment granulaire. La zone ranked sera traitée séparément.

### 7.4 MÉCANISME : Fusion 3 copies → niveau supérieur (duplicatas)

**SAP** : 3 copies du même pet → niveau +1 (max L3). +1 stat sur la plus haute des deux lors
de la fusion. Valeur de vente = niveau.
**Psychologie** : crée une "quête de complétion" (3e copie) qui est une variable reward
intégrée au run. La 3e copie est toujours potentiellement dans le prochain reroll — c'est le
"one more roll" de SAP. Par ailleurs, le niveau 3 est un signal visuel fort (animations, stats)
qui récompense le commitment.
**Maths** : coût total L3 pur = 18 or. Avec 10 or/round, monter un pet en L3 = 2 rounds de
budget complet.

**VERDICT : DÉJÀ FAIT, PLUS RICHE.** The Pit a les duplicatas (`tests/duplicatas.lua`,
`LEVEL_MULT = {1.0, 1.8, 3.0}`) avec cascade (3 L1 → L2 peut déclencher une 2e fusion si
déjà 2 L2). La multiplicité `1.8/3.0` est non-linéaire (vs SAP qui est +1/+1 flat), ce qui
crée une récompense plus forte au L3. Les auras scalent aussi avec le niveau — ce que SAP ne
fait pas (ses auras adjacentes sont au niveau de l'ability, pas des stats propres). The Pit
est strictement plus riche ici.

**Point de vigilance** : dans SAP, la 3e copie est facilement traçable car le pool est uniforme
(10 pets/tier). Dans The Pit (83 unités sur 5 rangs, pool uniforme non-encore), la probabilité
de trouver une 3e copie peut être frustrantement basse. Quand les cotes par rank seront
implémentées, il faudra vérifier que le "hunt de la 3e copie" reste accessible sans être
trivial. Recommandation : `tools/sim.lua` batch sur le temps médian pour atteindre L2 et L3
par rang.

### 7.5 MÉCANISME : Run court (10 victoires)

**SAP** : 10 trophées / 5 vies. Durée estimée 10-20 minutes.
**Psychologie** : arc complet fermé. Début-milieu-fin. L'objectif est toujours visible
(trophées / vies = deux jauges simples). La "one more run" est facilitée par la brièveté et
la **complétude narrative** de chaque partie.
**Maths** : dans le pire cas (5 défaites dont une récupérée au round 3), un run peut durer
jusqu'à ~15 turns. Dans le meilleur cas (10 victoires consécutives), ~10 turns.

**VERDICT : IDENTIQUE, DÉJÀ DÉCIDÉ.** The Pit utilise `WIN_TARGET = 10`, `START_LIVES = 5`,
filet identique au round 3. Le design est le même par décision explicite (décision §1 du
`00-state.md`). La durée de run est compatible avec l'async (pas de timer, le joueur s'arrête
quand il veut entre les rounds).

### 7.6 MÉCANISME : Tiering de la boutique — odds-gating vs slot-gating

**SAP** : pool uniforme au sein des tiers accessibles. Pas de probabilités différenciées par
tier — tous les pets d'un tier ont la même chance. Ce modèle est **plus simple** que TFT
(qui a des probabilités différenciées par coût).
**Psychologie** : la clarté des règles de pool ("au turn 5, je peux voir T1/T2/T3 à part
égale") réduit la frustration et permet de planifier. L'opacité des probabilités est une source
de friction identifiée dans les jeux de draft.

**VERDICT : ADAPTÉ DIFFÉREMMENT, JUSTIFIÉ.**
The Pit utilise des probabilités différenciées par rang (`00-state.md §4.3`), calquées sur TFT
plutôt que SAP. C'est plus sophistiqué et justifié par la re-tiérisation du roster (rang-1 =
simples / rang-5 = complexes). La décision §9 et §10 du `00-state.md` ("XP TFT-style" +
"cost = rank") fondent ce choix.

**Danger de complexité** : si les cotes ne sont pas affichées dans l'UI, le joueur ne sait pas
ce qu'il cherche en rerollant. SAP échappe au problème car son pool est uniforme et lisible.
The Pit devra implémenter le **tooltip de cotes** documenté dans le PRD (`progression-economy-prd.md §3.1`).

### 7.7 MÉCANISME : Gel de boutique (freeze)

**SAP** : n'importe quel item de boutique peut être gelé pour le conserver au prochain round,
sans coût. Les items gelés occupent un slot de boutique.
**Psychologie** : le gel transforme le "je ne peux pas l'avoir maintenant mais je ne veux pas
le perdre" en une vraie décision de gestion. C'est de la **temporalité prolongée** — le joueur
engage des ressources mentales (slot de boutique + slot cognitif) pour un futur hypothétique.
C'est un mécanisme d'anticipation fort.
**Maths SAP** : un slot gelé = un slot de boutique sacrifié. Sur 5-6 slots, geler 2 items
réduit les nouvelles offres de 33-40 %. Le coût est réel.

**VERDICT : NON IMPLÉMENTÉ, DÉCISION À PRENDRE.**
The Pit n'a pas de gel de boutique (`src/scenes/build.lua`, boutique = 5 offres regénérées au
reroll). Le mécanisme n'est pas incompatible avec l'architecture (un tableau `frozen[]` dans
l'état de boutique suffirait). Mais il n'est pas dans la roadmap actuelle.

**Recommandation conditionnelle** : le gel est précieux si le pool d'unités est grand et le
temps de hunt de la 3e copie est long. À réévaluer après les cotes et la simulation de
"hunt médian". Si le temps médian pour trouver une 3e copie est > 3 rounds de rerolls, le gel
devient utile. Si les cotes rendent le hunt naturellement rapide, le gel est superflu.

### 7.8 MÉCANISME : Weekly Pack / méta rotative

**SAP** : pool différent chaque semaine = nouvelle méta à résoudre. Leaderboard remis à zéro
chaque lundi pour le Weekly.
**Psychologie** : moteur de curiosité et de "FOMO compétitif" régulier. La semaine est une
fenêtre de compétition ouverte à tous (même les nouveaux joueurs partent de 0 chaque lundi).
**Architecture** : côté backend, le Weekly Pack = sélection de 9 pets/tier depuis la liste
complète, publiée en configuration de serveur. Aucun nouveau code de jeu.

**VERDICT : NON APPLICABLE EN L'ÉTAT, PRINCIPE À EXTRAIRE.**
The Pit est mono-pack (un seul roster, 83 unités). Il n'y a pas de structure multi-pack.
Néanmoins, le **principe de la méta rotative** est transférable via une autre voie :
les **sigils** (5 formes existantes, reliques G différées). Si chaque semaine un sigil est
"suggéré" ou favorisé (bonus de Grimoire, event de run), la méta strategique tourne sans
changer le contenu.

Plus fondamentalement, SAP Weekly résout un problème que The Pit n'a pas encore : un roster
trop large pour être mémorisé. Avec 83 unités + reliques + sigils, The Pit approche déjà la
complexité qui justifie une rotation. À planifier en V2 si le roster dépasse ~120 unités.

### 7.9 MÉCANISME : Ranked ELO / compétitif (zone vierge pour The Pit)

**SAP** : ELO ~1000-1500 de départ, ajustement Elo classique après chaque partie Versus.
Ranked = standard packs seulement. Saisons ajoutées en v0.41. Decay à +1800 ELO.
**Psychologie** : le rang visible est un **extrinsic motivator** qui fonctionne si et seulement
si (1) la progression est attribuable au skill (pas au luck), (2) la montée est visible et
récompensée. SAP a mis 2 ans à implémenter ça (v0.28 = septembre 2023, soit 2 ans après le
lancement en 2021). Raison documentée : "arena should be kept as casual as possible and
8-player versus is too chaotic" (`superautopets.wiki.gg/wiki/Version_0.28`).

**Problème fondamental de l'ELO dans un jeu async** : SAP l'a résolu en séparant Arena
(casual/async) et Versus (ranked). Mais en Versus, le joueur affronte le même adversaire pendant
TOUT le run (pas un adversaire différent par round). Ce n'est pas le même modèle que The Pit.

**VERDICT : À CONCEVOIR, DIFFÉREMMENT DE SAP.**
The Pit (async par snapshots, adversaire différent par round, run de 10 victoires) ne peut pas
copier le ranked SAP Versus 1v1. Le rang dans The Pit doit être associé à la **performance
sur un run complet**, pas à un duel. Les pistes valides :

- **ELO de run** : chaque run complétée (gagné ou perdu) donne un score ELO basé sur
  `(victoires / défaites) × (tier moyen des adversaires vaincus)`. Simple, async-compatible,
  déterministe.
- **Ladder de runs** : leaderboard hebdomadaire du nombre de runs parfaites (10v/0d), runs
  "ascension" (score composite), etc.
- **Paliers de rang** (Bronze/Argent/Or/etc.) : gating du matchmaking des snapshots par rang,
  pour que les joueurs haut-rang affrontent des builds haut-rang (et non des builds T1 random).

La zone vierge identifiée dans `00-state.md §7` est documentée : "Compétitif / ranked (zone
vierge — opportunité #1 du lab)". SAP prouve qu'on peut avoir 2 ans de succès sans ranked
(lancé en 2021, ranked en 2023). Priorité : d'abord consolider le fun du run, ensuite la couche
compétitive.

---

## 8. Analogies paresseuses à démolir

> Ces raccourcis circulent dans les documents de référence. Ils sont faux ou dangereux.

### 8.1 "SAP n'a pas de positionnement, donc le positionnement est optionnel"

**Faux.** SAP a un positionnement fort (l'ordre linéaire, droite-gauche), il est juste moins
riche que le 2D. Les synergies SAP sont profondément positionnelles (l'ability se déclenche
sur "le pet à droite" / "les 2 pets devant"). SAP prouve que le positionnement linéaire suffit
pour son design. The Pit a un design différent (plateau-graphe 3×3, adjacence orthogonale,
sigils) qui est plus riche par intention — c'est un différenciateur, pas une complexité excessive.

### 8.2 "SAP a de l'or fixe, donc les streaks d'or sont inutiles"

**Faux.** SAP n'a pas de streaks d'or parce que c'est cohérent avec son identité "chill" et
son modèle économique simple. The Pit a des streaks (`STREAK_CAP = 3`) parce que c'est décidé
(`state.lua`) et documenté. La décision est valide ; elle ajoute un axe économique absent de
SAP. L'analogie "SAP n'en a pas donc on n'en a pas besoin" est un argument d'autorité sans
fondement mécanique.

### 8.3 "SAP est notre référence donc il faut lui ressembler"

**Faux cadrage.** SAP est notre référence pour les **mécanismes qu'il a prouvés** :
async-snapshots, run 10-victoires, or fixe, fusion 3 copies, gating progressif de contenu.
Pour les mécanismes que The Pit dépasse (positionnement 2D, familles d'afflictions, sigils
mutables, reliques lisibles), SAP n'est pas la référence — ce sont nos propres décisions de
design validées par le blueprint (gd-research-result.md, combat-model-decision.md,
effects-dot-families.md).

### 8.4 "Le ranked SAP = ELO Elo, donc notre ranked = ELO Elo"

**Non transférable directement.** SAP Versus = duel run-vs-run contre le même adversaire (one
run = one match). The Pit = un run contre N adversaires différents. L'ELO classique s'applique
à des duels bipartis ; il ne s'applique pas directement à "un run de 10 combats contre 10
snapshots distincts". Un modèle ELO adapté (basé sur la composition win/loss du run) ou un
système de points de saison est plus approprié.

---

## 9. Synthèse — tableau de transférabilité

| Mécanisme SAP | Transférable ? | Statut dans The Pit | Notes |
|---|---|---|---|
| Or fixe/round, non reporté | Oui | FAIT (`GOLD_PER_ROUND=10`) | Enrichi avec streaks |
| Gating de contenu par tiers | Oui | FAIT (XP TFT-style, cotes par rang) | Plus sophistiqué que SAP |
| Async par snapshots | Oui, pilier | FAIT (`src/net/`) | Matching par tier, meilleur que SAP |
| Fusion 3 copies → niveau | Oui | FAIT (`LEVEL_MULT`, cascade) | Plus riche (auras scalen) |
| Run 10 victoires / 5 vies | Oui, pilier | FAIT (identique) | Filet round-3 identique |
| Filet anti-tilt round 3 | Oui | FAIT | Identique |
| Pas de timer (Arena mode) | Oui, pilier | FAIT (async) | Fondateur de l'identité |
| Reroll à l'or | Oui | FAIT (`REROLL_COST=1`) | Identique |
| Gel de boutique (freeze) | Partiel | NON FAIT | À réévaluer après sim hunt |
| Weekly Pack / méta rotative | Principe oui | NON FAIT | V2 si roster >120 unités |
| ELO ranked / compétitif | Adapter | NON FAIT | Nécessite modèle propre (run-based) |
| Pool uniforme par tier | Non | ADAPTÉ (cotes diff. par rang) | TFT-style, plus sophistiqué |
| Positionnement linéaire | Dépassé | DÉPASSÉ (3×3 + sigils) | Avantage compétitif The Pit |
| Triggers event-based par pet | Oui (structure) | FAIT (trigger/op/params) | Identique architecturalement |
| Aucune synergie cross-famille | Non applicable | Non applicable | The Pit a afflictions cross-famille |

---

## 10. Recommandations prioritaires

Classées par impact attendu sur "fun + addictif + compétitif", en respectant le mandat du lab.
**Ces recommandations n'impliquent aucune modification du code** — elles pointent vers des
chantiers à prioriser dans la roadmap finale.

### 10.1 Priorité 1 — Tooltip de cotes (clarté économique)

**Problème** : The Pit a un système de cotes par rang (plus sophistiqué que SAP) mais si
l'UI ne les montre pas, le joueur ne sait pas ce qu'il cherche en rerollant. SAP échappe à
ce problème car son pool est lisiblement uniforme.
**Leçon SAP** : la lisibilité du pool est aussi importante que les probabilités elles-mêmes.
**Action** : implémenter le tooltip de cotes du PRD (`progression-economy-prd.md §3.1`)
avant d'implémenter le gating lui-même. Un joueur qui comprend les cotes fait des décisions
éclairées ; un joueur qui ne les comprend pas subit l'aléatoire.

### 10.2 Priorité 2 — Hunt de la 3e copie (calibrage de la friction économique)

**Problème** : avec 83 unités, la probabilité de trouver la 3e copie d'une unité spécifique
est basse. Si le hunt est trop long, le mécanisme de duplicata perd son pouvoir de "quête
de complétion" (qui est central chez SAP).
**Leçon SAP** : avec 10 pets/tier et pool uniforme, la 3e copie d'un T1 est réaliste en 3-4
rerolls. Avec 83 unités et cotes différenciées, The Pit doit vérifier que le même feeling
est possible.
**Action** : utiliser `tools/sim.lua` pour mesurer le temps médian (en rerolls) pour
trouver une 3e copie d'une unité rank-1, rank-3 et rank-5. Si >5 rerolls en médiane pour
un rank-3, les cotes sont trop diluées ou un mécanisme de "pity" doit être ajouté.

### 10.3 Priorité 3 — Modèle ranked propre (design à concevoir)

**Problème** : la zone vierge compétitive la plus importante.
**Leçon SAP** : ne pas se précipiter (SAP a attendu 2 ans). Mais une fois décidé, la
séparation casual/compétitif est critique (Arena = casual chez SAP). Chez The Pit, le
modèle naturel est un **rang de run** (score composite basé sur le résultat du run entier,
pas d'un combat unique). Un leaderboard de saison hebdomadaire calé sur la semaine UTC
(comme le Weekly SAP) est une architecture éprouvée.
**Action** : concevoir le modèle de rang dans un document dédié
(`docs/roadmap-lab/competitive/ranked-model.md`), en répondant à : comment calculer le
rang d'un run ? Comment gater les snapshots par rang ? Comment resetter les saisons ?

### 10.4 Priorité 4 — Cohérence de la lisibilité du snapshot (anti-frustration)

**Problème** : en v1, les effets aura/relique ne sont pas dans le snapshot. Un joueur peut
perdre contre un adversaire ghost sans comprendre pourquoi (si la relique de l'adversaire
fait une différence). SAP a ce même problème (les buffs temporaires de build ne sont pas
visibles dans le ghost).
**Leçon SAP** : SAP n'a pas résolu ça — les joueurs se plaignent d'outcomes incompréhensibles
contre des ghosts. Ne pas copier cette frustration.
**Action** : en v2, capturer les reliques dans le snapshot et les afficher pendant le replay.

---

## Sources

- `superautopets.wiki.gg/wiki/Gold` — économie or
- `superautopets.wiki.gg/wiki/The_Basics` — boucle fondamentale, modes
- `superautopets.wiki.gg/wiki/Pets` — roster, levels, stats
- `superautopets.fandom.com/wiki/Roll_Chances` — table de cotes Turtle Pack
- `superautopets.fandom.com/wiki/Pets` — total 252 pets (fandom, version antérieure)
- `superautopets.wiki.gg/wiki/Version_0.28` — ajout ranked ELO (sept. 2023)
- `superautopets.wiki.gg/wiki/Version_0.29` — timer 90 s 8-player
- `superautopets.wiki.gg/wiki/Version_0.40` — cross-pack balance Versus
- `superautopets.wiki.gg/wiki/Version_0.41` — saisons Versus (juil. 2025)
- `superautopets.wiki.gg/wiki/Version_0.44` — leaderboard 8-player, difficultés (déc. 2025)
- `superautopets.wiki.gg/wiki/Version_history` — timeline complète 0.28→0.48, decay ELO
- `superautopets.wiki.gg/wiki/Weekly_Pack` — rotation hebdomadaire
- `en.wikipedia.org/wiki/Super_Auto_Pets` — généralités, ELO 1500, packs, IA fallback
- `store.steampowered.com/news/app/1714040/view/3689065475857403445` — notes de patch v0.28
- `twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/` — maths de fusion,
  cotes, coûts
- `twoaveragegamers.com/super-auto-pets-win-more-consistently-with-this-ultimate-guide/` —
  guide vétéran
- `a327ex.com/posts/super_auto_pets_mechanics` — analyse systémique triggers/effects
- `threadreaderapp.com/thread/1523357117805072385.html` — Fabian Fischer (@Ludokultur) :
  "whenever & forever" design analysis
- `mobilegamereport.com/articles/super-auto-pets-depth-vs-casual-2026` — depth & agency
- `tft.ninja/guides/strategy/win-streaking` — streak TFT pour contraste (SAP n'a pas de streak)
- `dl.digra.org/.../neuroscience-dopamine` — neurosciences : wanting vs liking, dopamine
- `chipsandtruths.com/scholar/loss-chasing-near-misses/` — near-miss psychology
- `gdcvault.com/play/1015985/Intrinsic-and-Extrinsic-Player-Motivation` — GDC : motivation
  intrinsèque/extrinsèque et retention
- Sources projet The Pit : `docs/roadmap-lab/00-state.md`, `docs/research/autobattler-design.md`,
  `docs/research/gd-research-result.md`, `docs/research/progression-economy-prd.md`,
  `docs/research/relics-design.md`, `src/run/state.lua` (constantes économiques)

---

*Rédigé 2026-06-23. Lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.*
