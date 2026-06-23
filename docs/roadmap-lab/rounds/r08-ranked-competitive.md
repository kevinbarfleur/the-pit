# Round 08 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 8/10. Challenge le brouillon v8 (`ROADMAP-draft.md` post-round-7),
> la synthèse `round-07.md` et le document de lentille précédent `rounds/r07-ranked-competitive.md`.
>
> **Sources primaires mobilisées ce round** :
> - ROADMAP-draft.md v8, round-07.md, rounds/r07-ranked-competitive.md, 00-state.md
> - competitive/{tft,marvel-snap,super-auto-pets,the-bazaar,backpack-battles}.md
> - The Bazaar ghost pool explanation : bazaar-builds.net/did-you-know-how-ghosts-work/ (nov. 2024)
> - Bazaar ranked matchmaking patch sept. 2025 : bazaar-builds.net/announcement-future-updates-for-the-bazaar-september-10th-patch/
> - Bazaar ranked feedback Steam : steamcommunity.com/app/1617400/discussions/0/591780152569114689/
> - Backpack Battles ranked Steam discussion (stagnation) : steamcommunity.com/app/2427700/discussions/0/844005624123531216/ (mai 2026)
> - Turnbound async autobattler review : biogamergirl.com/2025/12/turnbound-haunted-inventory-arena-tense.html (déc. 2025)
> - Metaplay async matchmaker docs : docs.metaplay.dev/feature-cookbooks/matchmaking/deep-dive-async-matchmaker
> - SAP Arena Mode wiki : superautopets.wiki.gg/wiki/The_Basics
> - Ranked systems retention : seganerds.com/2026/06/11/why-competitive-rank-systems-keep-players-coming-back-to-online-games/ (juin 2026)
> - Daily challenge + shared seed roguelike : dev.to/yurukusa/5-lines-of-code-that-made-my-roguelike-worth-playing-every-day-3klj (avr. 2026)
> - Leveling vs league rank psychology : yukaichou.com/advanced-gamification/leveling-system-gt85-and-league-rank-gt101/ (2023)
> - MOBA ranked motivation (SDT + social comparison) : nature.com/articles/s41599-024-03934-1 (oct. 2024)
> - Roguelite run structure design : bugnet.io/blog/how-to-design-a-roguelikes-run-structure (juin 2026)
> - Kryptek ranked design deep-dive : kryptekdev.com/2025/02/10/deep-dive-ranked/ (fév. 2025)
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> 32 invariants préservés.

---

## 0. TL;DR du challenge R08

**Cinq angles, tous mécanistes :**

1. **ACCORD FORT — La proposition "Invocations / fantômes" pour S1 est adoptée et correcte :**
   le Bazaar l'a appris à ses dépens (ranked peuplé à 20 % = abandon), le modèle ghost-pool async
   exige une communication honnête dès le lancement. Mais la roadmap S1 manque encore d'un
   **moteur de grind positif** qui distingue ranked de normal pour le joueur solo. Les cosmétiques
   datés et les marques sont des récompenses de fin — il faut un signal en cours de run.

2. **DÉSACCORD PARTIEL — Le daily "unranked + leaderboard journalier" (#BB, acté) résout la
   mauvaise moitié du problème.** Un leaderboard journalier pour un jeu à < 50 joueurs en S1
   est psychologiquement vide (pas de comparaison significative). La vraie valeur du daily n'est
   pas la comparaison — c'est la **seed partagée** (tous les joueurs affrontent les mêmes builds
   ce jour-là). Ce n'est pas dans la spec actuelle et c'est le mécanisme psychologique crucial
   qui fait de la contrainte du jour un outil compétitif réel.

3. **DÉSACCORD MAJEUR — La roadmap traite le ghost pool comme un problème de matchmaking
   (quels ghosts servir) mais jamais comme un problème de REPRÉSENTATIVITÉ META.** Backpack
   Battles (mai 2026) a documenté la même maladie : en ghost pool basé sur win-rate, les ghosts
   disponibles à haut tier sont naturellement **biaisés vers les builds qui ont gagné avec de la
   chance**, pas ceux qui ont gagné par compétence. Le FIFO filtré (`wins_at_capture ≥ 3`) améliore
   ça mais ne l'adresse pas explicitement. C'est un vrai risque d'équité perçue.

4. **LACUNE — La roadmap n'a pas de réponse à la question : "qu'est-ce que l'ascension (10V) dit
   de mon niveau ?"** La grille `+4/+2/+1/0` par résultat de run récompense l'**ascension brute**
   — mais deux joueurs peuvent ascender à 10V contre des ghosts de qualités très différentes selon
   leur pool. Sans la mesure de la **qualité du parcours** (contre qui, avec quels résultats
   intermédiaires), le LP est un proxy bruit élevé.

5. **PROPOSITION NOUVELLE — La Contrainte Permanente de Saison (§8.0) est le bon levier mais
   elle est trop différée (P4-light).** Elle peut être simplifiée à un `teamFlag` trivial (déjà
   implémenté, cf. `grant_team`) et livrée en P2 avec le ranked v1, sans attendre P4. C'est
   le différenciateur saisonnier le moins coûteux et le plus impactant pour la rétention S2.

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 ACCORD FORT — Proposition de valeur ranked S1 = "Invocations du Puits" (§6.5, §3.2 r07)

**Accord maintenu et consolidé ce round.**

**Pourquoi ça tient** : le Bazaar (bazaar-builds.net, sept. 2025) a documenté la même trajectoire
— ranked peuplé trop vite → joueurs bronze contre des builds legend → frustration → abandon.
La correction Bazaar (sept. 2025) : *"Players will only be matched with ghosts of players of
their rank or lower for their PvP fights. This will be a smoother experience for new players."*
C'est **exactement** notre `RANKED_MIN_POOL` + fenêtre de grâce. Mais le Bazaar avait des
**dizaines de milliers** de joueurs lors du lancement et a quand même souffert. Avec un lancement
plus petit, la communication honnête "tes premiers adversaires sont les Invocations" n'est pas un
aveu de faiblesse — c'est la **seule proposition de valeur honnête** en S1.

**Point manquant dans le r07** que je confirme ici : le Bazaar montre aussi qu'une fois que les
joueurs comprennent que le ranked = ghosts, ils restent si la **DA est cohérente avec ça**. Ce
qui tue la rétention, ce n'est pas les ghosts — c'est la **tromperie implicite** que les ghosts
sont présentés comme des humains actifs. Notre formulation "Invocations" préserve l'honnêteté et
la fiction grimdark simultanément.

**Ce qui consolide** (seganerds.com 2026) : *"Competitive rank systems keep working because they
stack several powerful pulls : progress you can see, rewards you can't predict, matches that feel
fair, and a social scoreboard that resets just often enough to stay fresh. Pull any single one of
those out, and the spell weakens."* — "fairness perçue" est la condition #1 ; notre communication
honnête en S1 est un garde-fou contre son effondrement.

### 1.2 ACCORD FORT — Pool ranked SÉPARÉ + `RANKED_MIN_POOL` SOFT=3 / HARD=5 (§6.4)

**Accord maintenu.** La preuve empirique est dans le Bazaar ghost doc (bazaar-builds.net nov. 2024) :
*"ghosts from ranked games only appear in ranked matches, and ghosts from normal games only show up
in normal matches."* La séparation est non-négociable en async — sans ça, les modes se contaminent
(un joueur qui spamme le mode facile injecte des ghosts faibles dans le pool ranked).

**Ce round** : le FIFO filtré `wins_at_capture ≥ 3` introduit un biais de qualité **utile** (les
builds capturés ont au moins survécu 3 rounds). Confirmation Backpack Battles : les ghosts en pool
sont tirés par win/loss count, ce qui crée une corrélation naturelle avec la progression (steam
discussion 2026 : *"its probably just a snapshot of the build of a player that had the same win/loss
ratio or the same ranking"*). Ce n'est pas parfait mais c'est correct pour une v1 locale.

### 1.3 ACCORD FORT — Grille +4/+2/+1/0 sans pénalité (rounds 1-7, maintenu)

**Accord maintenu.** La mécanique psychologique tient : la peur de la perte (Kahneman-Tversky 1979,
poids 2,3×) sur un pool de ghosts imparfait crée un churn disproportionné. Le modèle `+4/+2/+1/0`
découple le risque de pénalité de la qualité du pool — décision correcte pour un lancement local.

**Ce round** : Kryptek design (kryptekdev.com 2025) confirme empiriquement — leur tentative de
durcir le ranked (pénalités + bans) a déclenché une résistance violente de la communauté core.
Ce n'est pas une résistance irrationnelle : c'est que les joueurs qui jouent le plus sont ceux
qui sentent le plus les imperfections du pool. Les pénalités dans un pool imparfait = punir les
joueurs pour la qualité du matchmaking, pas pour leur performance.

### 1.4 ACCORD FORT — Cosmétique DATÉ de fin de saison + score ranked persistant inter-saisons (§6.3, r07 §3.5)

**Accord maintenu.** Deux mécanismes psychologiques distincts correctement identifiés :
- Cosmétique daté = urgence temporelle (Milkman 2014, Fresh Start Effect) = moteur de clôture
  avant le reset. Correctement ancré.
- Score persistant entre saisons (reset −20 %, pas à 0) = valeur cumulative inter-saisonnière =
  prévient la déception du reset partiel. Correctement documenté r07 §4.6.

**Ce qui reste vrai** : yukaichou.com (2023) — *"Leveling is private progress ; League Rank is
public progress. The two mechanics feel similar but serve opposite psychologies."* Nos cosmétiques
et marques sont **privés** (grimdark solo, pas de social visible). Ça change leur psychologie :
la valeur est **mémorielle**, pas de signalement social. Calibrer les attentes en conséquence
(acté r07 §6.2, maintenu ici).

### 1.5 ACCORD DE PRINCIPE — Contrainte Permanente de Saison §8.0 (différée P4-light)

**Accord sur le CONCEPT.** L'idée d'un `teamFlag` saisonnier seedé par la saison pour renouveler
la méta ranked est élégante, async-safe et dans l'esprit grimdark ("les règles du Puits changent
à chaque saison"). **Désaccord sur le timing** — voir §2.3 ci-dessous.

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD PARTIEL — Daily "unranked + leaderboard journalier" (#BB) résout la mauvaise moitié du problème

**Ce que le brouillon v8 §6.6 + round-07 §4.4 actent** : Daily = UNRANKED avec leaderboard
journalier séparé (score daily ≠ ranked MMR). Modèle StS Daily.

**Mon désaccord partiel** : le leaderboard journalier est **psychologiquement creux en S1** (< 50
joueurs = pas de comparaison significative). Mais la spec actuelle n'identifie pas la vraie valeur
de la Contrainte du Jour, qui est la **seed partagée** : si tous les joueurs ce jour-là affrontent
les mêmes familles de builds (la contrainte "famille X interdite" est la même pour tous), **les
résultats deviennent comparables** — c'est l'insight clé de yurukusa 2026 (dev.to) :

> *"The fix was obvious once I saw it: use the date as the seed. [...] What's different: their
> reaction time, their decision making, their skill execution. That's the game. The 'map' is
> shared. The score is earned."*
> Source : dev.to/yurukusa, avr. 2026

**Dans notre contexte async** : la Contrainte du Jour (famille restreinte) EST une seed
partagée — elle force tous les joueurs à naviguer la même contrainte méta le même jour. C'est
ce qui rend les résultats comparables et le leaderboard journalier meaningful — **même à 10
joueurs**. Avec 10 joueurs qui ont tous joué le Daily avec "poison interdit", les 10 scores
sont directement comparables. C'est radicalement différent du ranked normal où chaque run
affronte un pool différent.

**Ce qui change concrètement** : la spec du Daily (§6.6) devrait **dériver le seed de combat du
joueur du daily depuis la date + la contrainte** (pas juste d'un RNG libre), de sorte que **les
ghosts adverses du Daily soient les mêmes pour tous les joueurs ce jour-là**. C'est
techniquement trivial (le seed de run est `state.rng`, dérivé d'un paramètre injecté) et
psychologiquement transformatif. **SANS ça**, le leaderboard journalier mesure "qui a eu la
meilleure chance de ghosts" — **AVEC ça**, il mesure "qui a le mieux navigué la contrainte
dans les mêmes conditions".

**Coût** : 1 ligne — `daily_seed = hash(date + constraint_family)` injecté dans `state.rng` au
lieu d'un seed aléatoire. Compatible déterminisme (invariants #1-4). Zone sans test → ajouter
test que deux sessions daily du même jour produisent les mêmes adversaires au même round.

**Note de garde-fou** : le daily restant **UNRANKED** (pas de LP) est correct — la valeur est
la comparabilité journalière, pas la montée de rang.

### 2.2 DÉSACCORD MAJEUR — Le ghost pool favorise structurellement les builds "chanceux", pas "compétents"

**Ce que la roadmap traite** : le pool ranked est filtré par `wins_at_capture ≥ 3` et trié par
`slot_tier_composite`. Les ghosts à haut tier sont supposément plus forts.

**Mon désaccord** : le filtre `wins_at_capture ≥ 3` ne distingue pas **compétence de chance**.
Un build poison T2 qui a gagné 3 combats contre des IA faibles sera dans le pool. Un build
ingenieux contre-méta qui a perdu 4-5 (parce que le pool early était défavorable) n'y sera pas.
Le résultat : en ghost pool FIFO, **les builds qui dominent le pool sont ceux qui ont le plus
de wins, pas ceux qui ont le meilleur skill de construction**.

**Preuve empirique exacte** — Backpack Battles (steam 2026, mai) :

> *"You reach a certain point and it's just pairing you up against the best builds pulled from
> thousands of games for each specific round with the best combined skill and luck while you don't
> usually get lucky. [...] The game has no way to parse the actual contents of your build."*
> Source : steamcommunity.com/app/2427700/discussions/0/844005624123531216/

**Ce que ça produit chez nous** : à haut tier (shopTier 4-5), les ghosts du pool local (~200
FIFO) seront **sur-représentés par les familles dominantes** (poison > tank > ... > choc,
balance-diagnosis). Le joueur qui monte en ranked avec un build choc innovant affronte
majoritairement des builds poison "sûrs" — pas parce que c'est la méta de son tier, mais parce
que poison gagne plus souvent en general et remplit donc le pool plus vite.

**Conséquence pour l'équité perçue** : un joueur choc qui perd des LP contre 7 builds poison
d'affilée **ne voit pas son skill testé** — il voit la distribution du pool. C'est exactement
la source de frustration documentée Bazaar ("it is random, there is no matchmaking" — Steam 2025).

**Ce n'est pas un appel à tout recasser.** C'est un appel à **documenter le biais** explicitement :

**(a) A MINIMA (P2, doc 0 code)** : dans la spec §6.4, noter que le pool FIFO est biaisé vers
les familles à win-rate élevé. **L'IA ranked (Encounters puissants, acté §6.4bis r07)** doit
couvrir l'ensemble des familles (pas seulement les Encounters qui ont les meilleurs stats) —
3 Encounters par famille (burn/bleed/poison/rot/choc + tank) dans le cold-start pool, pour
que le joueur choc ne fasse pas face à un pool qui ignore son archétype.

**(b) SIGNAL TRANSPARENT (P2, ~1 h RENDER)** : après le post-combat ranked (§2.3 du brouillon),
ajouter une ligne grimdark : "TU AS AFFRONTÉ [N BURN / M POISON / K CHOC] EN [X] RUNS —
LE PUITS TE FORGE À SON IMAGE". Ce n'est pas un accusé de biais : c'est **rendre visible**
la distribution du pool pour que le joueur attribue ses résultats correctement. Zone sans test
→ test que le compteur de familles adverses est correct sur un golden.

### 2.3 DÉSACCORD — La Contrainte Permanente de Saison (§8.0) est différée trop tard (P4-light → P2)

**Ce que le brouillon v8 §8.0 dit** : `teamFlag` seedé par la saison pour renouveler la méta
ranked. Priorité P4-light (entre P2 et P4). Présenté comme un bonus de rétention S2.

**Mon désaccord** : c'est le mécanisme le **moins coûteux** et **plus impactant** pour la
rétention et la distinction ranked/normal. Il doit entrer avec le ranked v1 (P2), pas après P4.

**Pourquoi le coût est trivial** : `grant_team` est déjà implémenté (`ops.lua:276`). Les
`teamFlags` existants (`burnNoDecay`, `poisonNoCap`, `bleedNoExpire`, `shockChain`, `plagueAmp`...)
sont déjà data-driven et injectés à `combat_start`. Une Contrainte de Saison = 1 `teamFlag`
saisonnier (exemple : `seasonFlag = "bleedSlow2x"` = bleed ralentit 2× cette saison) posé
**dans la spec du ranked, pas dans le snapshot**. Le snapshot n'encode pas le `teamFlag`
saisonnier — il est injecté côté résolution depuis la version de saison. Async-safe (**acté
round 7, §1.7**).

**Pourquoi l'impact est maximal** : yukaichou.com (2023) et SEGA Nerds (2026) sont alignés —
*"a social scoreboard that resets just often enough to stay fresh"* est la 4e condition du ranked
qui hook. Sans différenciateur méta entre S1 et S2, **la S2 est juste un reset de S1** — même
méta, mêmes builds, mêmes ghosts, seul le score change. Le `teamFlag` saisonnier change
**fondamentalement** la méta (bleed est meilleur cette saison → les builds changent → les ghosts
changent) sans changer une ligne de code moteur.

**POE 2** (gamedesigning.org 2026) est la référence correcte ici, pas TFT :
> *"One of the quieter but more powerful design decisions in POE 2 is how thoroughly the meta
> reshapes itself with each new patch. Every league launch comes with extensive balance changes.
> A build that dominated last season may be ordinary now."*

Notre `teamFlag` saisonnier est l'analogue minimal de ce mécanisme — pas une refonte de contenu,
juste **une règle d'équipe** qui change d'une saison à l'autre.

**Proposition concrète** : livrer avec le ranked v1 (P2) une liste de 4 Contraintes de Saison
pré-définies (1 par saison prévue) :
- S1 : `bleedSlow2x` (bleed ralentit la cadence 2× au lieu de 1×) — favorise bleed
- S2 : `burnPropagateAlways` (propagation burn à la mort même sans voisin) — favorise burn
- S3 : `poisonWeakenStack` (chaque stack weaken cumule −10 % supplémentaire) — favorise poison
- S4 : `shockChain` équipe (toutes les unités choc chaînent la décharge) — favorise choc

**0 moteur** (tous ces `teamFlags` sont câblés ou triviaux à câbler) ; **décision data** au démarrage de chaque
saison. Test : les `teamFlags` existants couvrent déjà S1 (`bleedNoExpire` ≈ bleed étendu, à affiner) et S4 (`shockChain`
câblé `ops.lua:276`). Zone sans test → invariant à ajouter : `teamFlag` saisonnier n'altère pas le golden
(golden n'est pas une run ranked).

**Pourquoi P2 et pas P4** : si la S1 se termine sans différenciateur saisonnier, **tous les joueurs S1
reviennent en S2 avec exactement la même connaissance méta**. Il n'y a pas de "fresh start" psychologique
(Milkman 2014) — c'est juste un reset de score. L'effet Fresh Start **exige** une nouvelle couche de
contenu ou de règle pour être ressenti. Sans `teamFlag` saisonnier, la S2 ne hook pas les joueurs S1.

### 2.4 DÉSACCORD PARTIEL — Le signal pré-run (§6.11) est insuffisant comme "moteur du grimper"

**Ce que le brouillon v8 §6.11 dit** : signal pré-run = grille LP + distance sub-tier + signal de pool.
Présente comme "le manquant #1".

**Mon désaccord partiel** : c'est nécessaire mais insuffisant. Le signal pré-run répond à
"combien de LP vais-je gagner ?" — il ne répond pas à "**pourquoi ce run ranked est-il différent
d'un run normal ?**". Cette distinction psychologique est critique :

SEGA Nerds (2026) identifie 4 leviers du ranked qui hookent : (1) progress visible, (2) rewards
imprévisibles, (3) matches qui semblent fair, (4) reset saisonnier. Le signal pré-run couvre (1).
Le `+4/+2/+1/0` couvre (2) partiellement. Mais sans (3) explicite **et** sans (4) avant P4, le
"grind ranked" reste moins motivant que le "run normal" pour le joueur solo.

**Ce qui manque** : un signal d'**identité de run ranked** qui précède la grille LP. Acté r07 §2.3
(0 code, framing), mais la spécification concrète est absente. La DA grimdark résout ça :
- **Run normal** = "UNE DESCENTE DANS LE PUITS" (exploration, liberté)
- **Run ranked** = "UNE ÉPREUVE DU PUITS — TON BUILD Y EST PESÉ" (pression, légitimité)

Ce n'est pas 2 modes identiques avec un LP en plus. Ce sont 2 framings différents pour 2 états
psychologiques différents. La spec doit **l'écrire explicitement** dans i18n avant le code P2.
0 mécanique, 1 clé i18n supplémentaire.

---

## 3. Propositions priorisées

### 3.1 — Daily : seed partagée date+contrainte pour rendre le leaderboard meaningful — PRIORITÉ 1

**Problème** : §2.1 — leaderboard journalier creux sans comparabilité des runs.

**Proposition** : dériver le seed de run du Daily depuis `hash(date_ymd .. constraint_id)` au lieu
d'un seed libre. Tous les joueurs qui jouent le Daily S1 "poison interdit" le 2026-07-15 affrontent
les mêmes ghosts dans le même ordre (seeds de combat déterminés par le seed de run shared).

**Maths** : avec FIFO 200 ghosts + seed partagé → les 10 combats du Daily seraient identiques pour
tous les joueurs du même tier → le leaderboard mesure la compétence, pas la chance de pool.
Même à 10 joueurs, "j'ai monté ce run en 12 rounds de build et X vies restantes" est un score
directement comparable aux 9 autres.

**Comment** : `state.lua:startRound()` → remplacer `self.rng = love.math.newRandomGenerator(...)` par
`self.rng = love.math.newRandomGenerator(daily_seed)` si `mode == "daily"`. `snapstore:serve` garde
le seed de ghost existant (le seed daily contrôle l'ordre de tirage des ghosts du pool, pas le pool
lui-même). **0 invariant touché** (le seed est injecté, conforme pilier #2).

**Zone sans test** → test que deux sessions daily du même jour + même tier produisent la même
séquence de ghosts (golden daily = snapshot des adversaires du jour).

**Priorité HAUTE** : débloque la vraie valeur compétitive du Daily sans coût de pool (les ghosts
restent ceux du FIFO normal — seul l'ordre de tirage est seedé).

### 3.2 — Contrainte Permanente de Saison : livrer en P2 avec 4 teamFlags pré-définis — PRIORITÉ 1

**Problème** : §2.3 — sans différenciateur méta saisonnier, la S2 n'a pas de raison psychologique
de re-hooker les joueurs S1.

**Proposition** : avancer §8.0 de P4-light à P2, livrer avec le ranked v1. 4 `teamFlags` saisonniers
data-définis (liste §2.3 ci-dessus). Injection au démarrage de chaque saison depuis un fichier de config.

**Coût** : 0 moteur ; 1 fichier de config saisonnier (ex. `src/data/season.lua` → `{teamFlag =
"bleedSlow2x", name = "Saison des Saignements", id = 1}`) ; 1 lecture dans `arena.lua:combat_start`
pour injecter le flag (`if S.currentSeason and S.currentSeason.teamFlag then opts.teamFlags[S.currentSeason.teamFlag] = true end`).

**Zone sans test → ajouter** : test que le `teamFlag` saisonnier est bien injecté dans le build ranked
(pas dans un build normal) ET ne modifie pas le golden (le golden n'est pas une run ranked).

**Garde-fou piliers** : le `teamFlag` saisonnier s'applique côté résolution SIM, **pas** dans le
snapshot — le snapshot encode les unités/sigil, pas les flags de résolution. Async-safe car le ghost
qui répond à un joueur ranked S1 est résolu avec les règles S1 (flag lu depuis la saison courante
à la résolution, pas depuis le snapshot figé). Déterministe : `teamFlag = true` est un booléen,
pas du RNG.

### 3.3 — Distribution du pool IA cold-start : 1 build par famille — PRIORITÉ 1 (avant code P2)

**Problème** : §2.2 — pool ranked biaisé vers les familles dominantes. Le cold-start IA
(Encounters puissants, acté §6.4bis r07) doit couvrir toutes les familles.

**Proposition** : spécifier **explicitement** dans §6.4bis que les Encounters IA du cold-start ranked
sont **6 builds** : 1 burn fort + 1 bleed fort + 1 poison fort + 1 rot fort + 1 choc fort + 1 tank.
(6 Encounters de `src/data/encounters.lua`, les plus puissants par famille.)

**Pourquoi c'est critique** : si le cold-start pool IA est 3 builds poison + 2 builds tank (parce
que ce sont les Encounters les mieux calibrés), un joueur choc en S1 ne voit jamais de ghosts choc
à son tier → il ne peut pas évaluer son archétype → il abandonne le choc (biais de sélection par pool).

**Coût** : 0 code (`encounters.lua` existe), 1 décision de curation éditoriale → liste dans §6.4bis.
Zone sans test existante : `snapstore:serveComp` → `aiComp` → test que le cold-start retourne 1 build
par famille (golden store).

### 3.4 — Signal de distribution du pool visible en post-combat ranked — PRIORITÉ 2

**Problème** : §2.2 — joueur ne peut pas distinguer biais du pool de biais de son propre skill.

**Proposition** : dans le post-combat ranked (§2.3 brouillon), après le « pourquoi » (1re mort +
cause), ajouter un segment grimdark :

*"TU AS AFFRONTÉ [N] INVOCATIONS : [K BRÛLEURS / M SAIGNEURS / P DISTILLATEURS / ...]"*

Lecture de `dot_family` sur les snapshots servis ce run (déjà disponible via `toComp`, P0.5).
Renforce l'attribution correcte : "j'ai perdu contre 7 poison → le pool est poison-lourd ce tier" vs
"j'ai perdu contre 2 choc, 3 poison, 2 burn → mon build a un problème générique". Grimdark-cohérent
(le Puits révèle ce qu'il t'a envoyé).

**Coût** : ~1 h RENDER. Lit `ghost_families` comptées pendant les combats du run (IO hors SIM,
0 invariant). Zone sans test → test que le comptage est correct sur le golden (golden run = suite
de combats connue → families attendues).

### 3.5 — Spec explicite du framing identitaire ranked/normal AVANT le code P2 — PRIORITÉ 1 (doc)

**Problème** : §2.4 — manque un framing qui différencie ranked et normal psychologiquement.

**Proposition** : ajouter AVANT le code P2, dans `docs/roadmap-lab/` ou `seed/decisions.md`, un
tableau de framing i18n :

| Moment | Normal | Ranked |
|---|---|---|
| Sélection de mode | "UNE DESCENTE DANS LE PUITS" | "UNE ÉPREUVE DU PUITS" |
| Lancement du run | "LE PUITS ATTEND" | "LE PUITS PÈSE TON BUILD" |
| Victoire run | "TU AS SURVÉCU" | "LE PUITS T'A RECONNU" |
| Défaite run | "LE PUITS T'A CONSUMÉ" | "LE PUITS A JUGÉ TON BUILD INSUFFISANT" |
| Saison active | — | "SAISON DES [NOM] — LES RÈGLES DU PUITS ONT CHANGÉ" |

Coût : 0 code, 5 clés i18n. Doit être **écrit avant** le code du mode ranked (sinon c'est du
cosmétique bolté après coup — la DA doit structurer le code, pas l'inverse).

---

## 4. Démontage des analogies faibles dans la section ranked

### 4.1 — "StS Daily = modèle pour notre Daily" (§6.6, r07 §4.4)

**Analogie partiellement paresseuse.**

StS Daily est un run à **seed partagée** — tous les joueurs voient les MÊMES salles, les MÊMES
reliques, les MÊMES ennemis le même jour. La comparabilité est totale. Le leaderboard journalier
StS est significatif à 50 joueurs parce que le run est littéralement le même pour tout le monde.
Source : slaythespire.gg/daily-run (communauté active sur seeds partagées).

**Notre Daily tel que spécifié actuellement** (contrainte + pool de ghosts libre) n'a pas cette
propriété. Un joueur affronte un ghost poison, un autre affronte un ghost burn — le leaderboard
compare des runs dans des conditions différentes. C'est le modèle StS Daily **sans** la partie
qui le rend fondamentalement différent d'une run normale.

**Ce qui tient** : la contrainte (famille restreinte) = layer de difficulté partagé. Ce qui manque :
le seed partagé des ghosts adverses (§3.1 de ce round). **Sans ce seed, l'analogie avec StS Daily
est paresseuse** : elle copie la forme (contrainte journalière + leaderboard) sans le mécanisme
psychologique qui fait que StS Daily hook (comparabilité directe des expériences).

### 4.2 — "TFT soft reset = rétention inter-saisons" (brouillon §9, rounds 1-7)

**Analogie partiellement correcte, psychologie différente.**

TFT soft reset fonctionne parce que chaque set = **nouveau roster complet + nouvelles synergies**.
Le "fresh start" TFT est accompagné d'une ignorance totale de la méta — personne ne sait quoi
jouer en semaine 1 d'un nouveau set. Cette incertitude équalize les joueurs experienced et casual.
Source : tft.md §4.6 — *"The reset of rank creates a window where even a low-elo player can
'climb fast' during the first weeks before the lobby re-calibrates."*

Notre soft reset (−20 % LP) sans contenu différent n'a pas cette propriété d'égalisation. Les
joueurs S1 qui ont appris que "poison domine" reviennent en S2 avec exactement le même avantage.
**C'est pourquoi le `teamFlag` saisonnier (§3.2) est le prérequis** : il change les règles suffisamment
pour que l'expérience S1 ne soit pas un avantage direct en S2 (l'archétype dominant change).

**Ce qui tient** : la valeur du reset partiel pour les joueurs qui veulent un "nouveau départ" et
la fenêtre d'ascension rapide en début de saison. **Ce qui ne tient pas** : supposer que le reset
seul crée le Fresh Start — sans `teamFlag` saisonnier, c'est un reset de score dans une méta inchangée.

### 4.3 — "MMR caché résout l'injustice perçue" (analogue TFT, r07 §2.1)

**Analogie inapplicable directement.**

TFT MMR caché est un algorithme de calibration continue sur des milliers de parties. Il fonctionne
parce qu'un joueur joue ~100+ parties par set — l'algorithme converge. Immortalboost.com (2026) :
*"the game shows you LP, but the system actually makes its biggest decisions using MMR."*

Notre contexte : un joueur casual joue **6-9 runs par saison de 3 sem.** Un MMR caché n'a pas
le temps de converger sur ce nombre de runs. Ajouter un MMR caché complexifie la mécanique pour
un gain de précision minimal. Le `slot_tier_composite` (proxy simple, monotone croissant) est
suffisant pour le volume de données que nous aurons en S1.

**Ce qui tient** : ne pas exposer un LP "brut" biaisé sans communication sur ses limites
(r07 §2.1) — documenté, maintenu. **Ce qui ne tient pas** : implémenter un MMR caché à la TFT
pour un jeu local à 50-100 joueurs beta. C'est de l'ingénierie prématurée.

---

## 5. Questions ouvertes nouvelles

### 5.1 [NOUVEAU litige #EE] — Le seed partagé du Daily modifie-t-il l'invariant de déterminisme ?

**Position** : le seed partagé daily est injecté dans `state.rng` (conforme au pilier #2 et
à l'invariant #4 : "tout RNG SIM passe par `opts.rng` injecté"). Il n'introduit pas de RNG
global. MAIS il exige que deux sessions daily du même joueur (relance en cours de run) utilisent
le même seed de run → **invariant #2 revisité** : "même seed de run → même suite d'adversaires daily".
C'est voulu — mais à documenter dans `seed/tests.md` §6 comme variante de l'invariant #2 pour
le mode daily.

**À trancher avant le code daily (P2)** : est-ce que le seed daily s'applique au seed de run
ENTIER (shop inclus) ou uniquement aux seeds de combat ? Si le shop est aussi seedé par la date
→ tous les joueurs voient les mêmes offres en boutique daily → run encore plus comparable mais
perd la variance de build → trop restrictif. **Recommandation** : seed daily s'applique
uniquement aux seeds de combat (ordre des ghosts servis), pas au shop (variance build préservée).

### 5.2 [PRÉCISION litige #BB] — Leaderboard journalier : scores comparables SEULEMENT si seed daily implémenté

**Position** : #BB (Daily ranked vs unranked) est clos (recommandation unranked + leaderboard
journalier, r07 §4.4). **Mais** le leaderboard journalier doit être conditionnel à l'implémentation
du seed partagé (§3.1 de ce round). Sans seed partagé, le leaderboard journalier ne peut pas être
présenté comme compétitif — ce serait une analogie paresseuse avec StS Daily.

### 5.3 [MAINTENU litige #A] — Types (P1) vs ranked (P2) : mesure `--meta-convergence`

Maintenu ouvert. L'ajout du `teamFlag` saisonnier (§3.2) change légèrement la dynamique :
si la S1 a un `teamFlag` qui favorise bleed, `--meta-convergence` sur les runs ranked S1 sera
biaisé vers bleed indépendamment de la puissance relative des familles. **Clarification à la spec** :
`--meta-convergence` pour le litige #A doit être mesurée sur les **runs normaux (non ranked)** sans
`teamFlag` saisonnier, pour isoler la convergence méta structurelle de la contrainte saisonnière.

### 5.4 [MAINTENU litige #U] — Contrainte Permanente : famille sous-représentée vs bas win-rate

Maintenu ouvert, lié à §3.2. Si le `teamFlag` S1 favorise bleed (`bleedSlow2x`), la "famille
sous-représentée" (#U) peut changer entre S1 et S2. Le critère de sélection du `teamFlag` saisonnier
doit **croiser** le bilan `--pool-repr` (distribution du pool ranked) pour éviter de choisir un flag
qui sur-représente déjà une famille dominante.

---

## 6. Tableau de synthèse des propositions

| Proposition | Section roadmap | Priorité | Coût |
|---|---|---|---|
| Daily : seed partagé date+contrainte | §6.6 nouveau | **P2 — bloquant leaderboard** | 1 ligne seed injection |
| Contrainte Permanente de Saison (§8.0) → avancer en P2 | §8.0 | **P2 — réorientation calendrier** | 0 moteur, 1 fichier config |
| IA cold-start pool : 1 build par famille (6 Encounters) | §6.4bis | **P2 — spec/curation** | 0 code, décision éditoriale |
| Signal distribution pool en post-combat ranked | §2.3 ranked | **P2** | ~1 h RENDER |
| Framing identitaire ranked/normal (tableau i18n) | §6.11 + i18n | **P1 — avant code P2** | 0 code, 5 clés i18n |
| Test daily seed (même jour = mêmes adversaires) | seed/tests.md | **P2 — zone sans test** | ~30 min test headless |
| Clarification spec litige #EE (seed daily = combat seulement) | §6.6 | **P2 — doc** | 0 code |

---

## 7. Récapitulatif des litiges

| # | Litige | Statut R08 |
|---|---|---|
| **#A** | P1 types vs P2 ranked | Maintenu ; mesure sur runs normaux sans `teamFlag` (précision §5.3) |
| **#BB** | Daily ranked vs unranked | **CLOS** avec condition : unranked + leaderboard journalier, CONDITIONNEL à seed daily partagé (§5.2) |
| **#U** | Saison : bas win-rate vs sous-représentée | Maintenu ; lié au `teamFlag` saisonnier (§5.4) |
| **#Z** | Signal spectre cold-start | CLOS (r07 §4.7 — IA formulation distincte). Maintenu. |
| **#AA** | Seuil VRR boutique | Maintenu (calibration P3). |
| **#EE** | **NOUVEAU** : seed daily = run entier ou combat seulement ? | Ouvert. Recommandation §5.1 : combat seulement (shop libre). |

---

## 8. Index des sources R08

| Affirmation | Source vérifiée |
|---|---|
| Ghost pool Bazaar : séparation ranked/normal stricte depuis lancement | bazaar-builds.net/did-you-know-how-ghosts-work/ (nov. 2024) |
| Bazaar patch sept. 2025 : matchmaking par rang ≤ joueur, soft reset mensuel | bazaar-builds.net/announcement-future-updates (sept. 2025) |
| Bazaar Steam : frustration ranked peuplé (random, pas de matchmaking) | steamcommunity.com/app/1617400/discussions/0/591780152569114689/ |
| Backpack Battles Steam : biais ghost pool vers builds chanceux | steamcommunity.com/app/2427700/discussions/0/844005624123531216/ (mai 2026) |
| Daily roguelite à seed partagée = comparabilité directe des runs | dev.to/yurukusa (avr. 2026) |
| 4 leviers du ranked qui hookent : progress visible, rewards imprévisibles, fairness, reset | seganerds.com (juin 2026) |
| Leveling = progrès privé / League Rank = progrès public, psychologies différentes | yukaichou.com (2023) |
| Seuil de frustration ranked lié à la qualité de matchmaking perçue | steamcommunity.com Bazaar 2025 ; kryptekdev.com 2025 |
| POE 2 : `teamFlag` saisonnier (règles changeantes) = différenciateur S1→S2 | gamedesigning.org (avr. 2026) |
| Turnbound : ghost pool peu varié sans assez de joueurs = meta rote | biogamergirl.com (déc. 2025) |
| Moteurs de motivation ranked (SDT : compétence + autonomie + progrès visible) | nature.com/articles/s41599-024-03934-1 (oct. 2024) |
| SAP Arena Mode : pool de teams asynchrones, même principe FIFO ghost | superautopets.wiki.gg/wiki/The_Basics |
| Metaplay async matchmaker : buckets MMR + fallback descendant = spec valide | docs.metaplay.dev/feature-cookbooks/matchmaking/ |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 8/10.*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés : toutes les propositions sont doc/i18n/config/RENDER ou décisions éditoriales.*
*Zones sans test nouvelles signalées : §3.1 (seed daily = même adversaires même jour) ;*
*§3.2 (teamFlag saisonnier n'altère pas le golden) ; §3.4 (comptage familles adverses sur golden run).*
*1 litige neuf : #EE (scope du seed daily). 1 litige précisé et conditionnel : #BB.*
