# Round 10 — Critique adversariale : lentille Ranked & Compétitif (FINAL)

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 10/10 — critique FINALE. Challenge le brouillon post-round-9, la synthèse
> `round-09.md` et le lentille précédent `rounds/r09-ranked-competitive.md`.
>
> **Démarche** : accord = je prouve pourquoi ça tient sous NOS contraintes ;
> désaccord = recherche web propre, source citée, mécanisme démontré.
>
> **Sources primaires mobilisées ce round** :
> - round-09.md, rounds/r09-ranked-competitive.md, ROADMAP-draft.md §6, 00-state.md
> - SAP v0.28/v0.41/v0.44 wiki : superautopets.wiki.gg/wiki/Version_0.28, /Version_0.41, /Version_0.44
> - The Bazaar matchmaking Sept. 2025 : bazaar-builds.net/announcement-future-updates-for-the-bazaar...
> - The Bazaar ghost system : bazaar-builds.net/did-you-know-how-ghosts-work/ (nov. 2024)
> - The Bazaar matchmaking Steam discussion : steamcommunity.com/app/1617400/discussions/0/591780546280023348/
> - Kingdom Clash matchmaking exploits : azurgames.com/blog/the-nuances-of-matchmaking-in-kingdom-clash... (fév. 2025)
> - Matchmaking rigging anatomy : gameanatomy.blog/2025/08/13/matchmaking-rigging/
> - POE 2 seasonal design : game-wisdom.com/general/design-philosophy-behind-poe-2... (mars 2026) + gamedesigning.org/beyond (avr. 2026)
> - Kydagames competitive leaderboards : kydagames.com/blog/designing-competitive-leaderboards-repeat-visits.html (avr. 2026)
> - NerdSip leaderboard psychology (Festinger social comparison) : nerdsip.com/blog/the-science-of-gamification-why-it-works (avr. 2026)
> - GamineAI live service seasons : gamineai.com/blog/live-service-games-events-seasons-and-retention-hooks (mars 2026)
> - EurekAlert / Management Science 2026 (Lichess 5.4M parties) : eurekalert.org/news-releases/1130401
> - Grid Sage Games (mastery roguelikes) : gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes (août 2025)
> - Balatro addictiveness (variable rewards, agency) : armchairarcade.com/perspectives/2026/05 + goombastomp.com/how-balatro-became-one-of-the-most-addictive-roguelikes/ (fév. 2026)
> - Reynad Bazaar interview (async PvP, concede meta) : bazaar-builds.net/reynad-interview (déc. 2024)
> - Cinder matchmaking (arxiv.org/html/2602.17015 — fairness metric) — lu ce round
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> 32 invariants préservés.

---

## 0. TL;DR du challenge R10

**Trois lignes de front, toutes mécanistes :**

1. **ACCORD FORT sur les fondations ranked (pas-de-pénalité, pool séparé, grille `+4/+2/+1/0`,
   Profondeur du Puits, signal d'élan, Contrainte de Saison)** — les décisions R09 tiennent. Mais
   l'accord cache un problème non adressé en 10 rounds : **la cadence de saison de 3 semaines est
   psychologiquement fausse pour notre contexte run-court.** 3 semaines = 6-9 runs. Ce n'est pas
   un Fresh Start — c'est une session. La ROADMAP cite Milkman 2014 pour justifier des saisons courtes,
   mais Milkman 2014 mesure des landmarks temporels naturels (lundi, Nouvel An) — pas des resets
   arbitraires imposés. La discontinuité perçue exige que le joueur ait eu le temps de s'identifier à sa
   position actuelle pour la ressentir comme une perte puis un renouveau. 6-9 runs ne suffisent pas.

2. **DÉSACCORD MAJEUR sur l'intégrité async — la vulnérabilité du "concede meta" n'est PAS
   adressée.** Le Bazaar Steam (steamcommunity, août 2025) documente que le concede est devenu
   la stratégie optimale : les joueurs réinitialisent jusqu'à obtenir une boutique idéale, sans
   pénalité. Notre snapshot se capture au `startCombat` (build actif), pas au `startRound` (avant
   le reroll). Ce timing-là est une faille d'intégrité silencieuse qui fausse le ranked dès S1.
   La ROADMAP ne la mentionne nulle part en 9 rounds.

3. **LACUNE sur le moteur de grind ranked** : la ROADMAP identifie la Profondeur du Puits, les
   marques et le signal d'élan (R09) comme les trois leviers de motivation de re-queue. Mais ces
   trois leviers sont tous des **SIGNAUX DE POSITION** (où j'en suis). Aucun n'est un **SIGNAL
   D'APPRENTISSAGE** (ce que j'ai appris). La recherche sur la compétence auto-déterminée (Grid
   Sage Games 2025, Kyzrati) montre que dans les roguelikes compétitifs, c'est la **rétroaction
   d'apprentissage post-run** — pas la position sur la ladder — qui déclenche le restart. Nous
   avons le near-miss (§2.3), mais il est formulé comme signal émotionnel, pas comme hypothèse
   testable (« si j'avais X, j'aurais gagné le round 8 »).

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 ACCORD FORT — Pas de pénalité + grille `+4/+2/+1/0` sans floor

**Accord maintenu, renforcé par la trajectoire documentée du Bazaar.**

Le Bazaar (bazaar-builds.net/announcement, sept. 2025) a introduit gain ET perte de rank points
en 2025 — parce qu'il a un pool mondial de centaines de milliers de joueurs, ce qui rend le
calibrage ELO légitime. La ROADMAP R09 §6.2 l'a correctement noté comme contre-référence partielle.

**Pourquoi ça tient pour nous** : notre FIFO 200 LOCAL ne peut pas garantir l'équité d'un
match. Une pénalité sur un pool imparfait ne punit pas le manque de skill — elle punit la
pauvreté du pool. La règle de Kahneman-Tversky (aversion à la perte ×2,3) s'applique à la
friction psychologique, pas au calibrage. Ajouter une pénalité à un pool imparfait = cumuler
les deux frictions. Confirmation externe : le Bazaar lui-même (sept. 2025) a reconnu que même
avec un pool mondial, la pénalité pour les bas ranks créait une friction excessive et a séparé
les nouvelles règles selon le niveau. Source : bazaar-builds.net/announcement-future-updates...

**Ce qui est nouveau ce round** : Kingdom Clash (azurgames.com, fév. 2025) confirme que même
sur des pools de taille décente, le **principal problème d'équité perçue n'est pas la grille de
score mais les EXPLOITS** (concede, revenge farming). Ce n'est pas un argument pour ajouter une
pénalité — c'est un argument pour corriger les failles d'intégrité en amont (cf. §2.1 ci-dessous).

### 1.2 ACCORD FORT — Profondeur du Puits + signal d'élan 3 runs (R09 adoptions)

**Accord maintenu.** Les deux dimensions ajoutées en R09 (#KK + §6.11 enrichi) répondent à
une réalité bien documentée.

Kydagames 2026 est clair :

> *"Common leaderboard mistakes include stagnant top ten rankings and zero-sum mechanics, which
> severely demotivate casual players. Experts recommend using rolling 7-day resets and highlighting
> personal bests alongside competitive ranks to maintain a highly dynamic, encouraging, and balanced
> gaming ecosystem."*
> Source : kydagames.com/blog/designing-competitive-leaderboards-repeat-visits.html

La Profondeur du Puits EST le "personal best alongside competitive rank". Pour le joueur 7-3 répété
qui ne voit jamais une marque (8-9 wins requis), c'est le seul signal de progression disponible.

**Pourquoi ça tient à NOS contraintes async** : c'est une stat de run (rounds_completed), pas un
snapshot. Elle est IO pur hors SIM. Elle ne dépend pas du pool ghost. Elle est déterministe. 0 invariant.

**Nuance nouvelle** : la Profondeur du Puits n'a de valeur que si le joueur a un **contenu bloquant
différent** au round 8 qu'au round 4. Sinon "je suis bloqué au round 8" = "je suis bloqué ici depuis
toujours" = démotivation structurelle. Le prérequis implicite : la progression des adversaires (escalade
des IA, puis des ghosts tier 3+) doit être réelle et lisible. Si `encounters.lua` ne scale pas les IA
après le round 4-5, la Profondeur du Puits mesure un plafond de difficulté, pas un plafond de skill.
**À documenter dans §6.2 comme prérequis de signal.**

### 1.3 ACCORD FORT — Contrainte de Saison avancée à P2 + prérequis "axe résolu" (R09)

**Accord maintenu.** La correction R09 (critère = "axe RÉSOLU + plus grand écart potentiel/réel",
#U re-qualifié) est mécaniquement correcte.

La preuve POE 2 (gamedesigning.org, avr. 2026) est plus précise que la source R09 sur LE mécanisme :

> *"Every league launch comes with extensive balance changes — buffs, nerfs, reworks, and newly
> enabled synergies. A build that dominated last season may be ordinary now. A previously overlooked
> skill combination might be the fastest way through endgame content for the next four months."*

Notre `teamFlag` saisonnier est l'analogue minimal : 0 code moteur (câblé via `grant_team`), mais
il change la méta perçue. Sa valeur repose entièrement sur l'incertitude collective — les joueurs
ne savent pas d'avance si `bleedSlow2x` équipe va surpasser ou non les builds poison habituels.

**Ça tient à NOS contraintes** : le teamFlag est PUR (data à `combat_start`), async-safe (dans le
snapshot dès que P0.5 capture `dot_family`), 0 invariant de SIM. Le coût marginal d'une Contrainte
de Saison = 1 `teamFlag` + 1 clé i18n + 1 doc dans `seed/decisions.md`.

### 1.4 ACCORD PARTIEL — SOFT/HARD pool séparé ranked/unranked + fenêtre de grâce 7 jours

**Accord sur le principe, désaccord sur la calibration de la persistance filtrée.**

Le principe de séparation des pools est non-négociable (The Bazaar l'a fait dès v1, confirmé
bazaar-builds.net/did-you-know-how-ghosts-work). Mais le seuil `wins_at_capture >= 3` comme
filtre de qualité porte une **hypothèse non vérifiée** : que 3 victoires au moment de la capture
garantissent un ghost "légitime". En fait, avec notre économie (or 10/round, boutique seedée par
le RNG du run), un build capturé à win=3 peut être bien plus avancé qu'un build capturé à win=7
si le joueur a eu de la chance tôt. La capture est temporellement liée aux victoires mais
structurellement liée au shop tier et aux reliques obtenues, pas au compte de victoires brut.

**Proposition de correction (doc, 0 code)** : renommer le filtre en `tier_proxy_at_capture >=
slot_tier_composite_threshold` (le même critère de matchmaking §6.4 que la roadmap utilise
déjà pour le serve). Un ghost légitime = un ghost dont le `slot_tier_composite` est au-dessus
d'un seuil minimum (ex. `shopTier >= 2 AND slots_actifs >= 5`), pas un compte de victoires brut.
Les deux s'ajoutent bien : `wins_at_capture >= 3 AND slot_tier_composite >= threshold`. **§6.3
et §6.4bis à enrichir.**

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La vulnérabilité "concede meta" n'est PAS adressée (faille d'intégrité silencieuse)

**Ce que la ROADMAP dit** : le snapshot est capturé lors de `startCombat` (build actif, units +
positions + sigil). L'IO est dans `snapstore.lua:save` (00-state §5). La ROADMAP adresse le ghost
replacement (R09), le pool séparé ranked/unranked, le FIFO filtré, la fenêtre de grâce — mais
**jamais le moment de capture par rapport aux rerolls**.

**Mon désaccord** : la structure actuelle crée un "concede meta" silencieux.

Voici le mécanisme :
1. Le joueur démarre un round ranked.
2. Il voit sa boutique — mauvaise sélection.
3. Il **abandonne la run** (quitte le jeu ou relance). La run n'est pas terminée.
4. Aucun snapshot n'a été capturé (capture = `startCombat`, pas `startRound`).
5. Il recommence une run ranked. Répète jusqu'à obtenir une boutique favorable.

Ce n'est pas de la triche au sens technique — il n'y a pas de manipulation du RNG (le run seed
est tiré du run state, pas global). Mais c'est une asymétrie d'intégrité : le joueur A qui joue
honnêtement affronte des ghosts capturés sur des runs complètes ; le joueur B qui concède
sélectionne effectivement ses runs en faveur des bons départs, car son ghost n'est capturé qu'à
`startCombat` (s'il arrive là-bas). **En ranked, ce comportement BIAISE le pool vers les builds
qui ont eu une bonne boutique R1-2**, pas nécessairement ceux qui ont le mieux géré l'adversité.

**Preuve empirique directe** — Steam Bazaar discussion (steamcommunity.com/app/1617400/discussions,
août 2025) :

> *"One glaring problem is that players can just concede until they get ideal rewards. There is no
> punishment for doing this. So when you lose to a player you have to wonder how many times they
> conceded to get the board they have."*
> *"Like I said in the other thread, the way rank play currently works you kinda HAVE TO concede to win."*

Et Reynad interview (bazaar-builds.net/reynad-interview, déc. 2024) confirme que le Swiss-round
matchmaking (ne pas utiliser le daily-win pour éviter le farming intentionnel de pertes) est
directement lié à ce problème. Ils ont conçu le matchmaking **autour** du concede meta.

**Pourquoi c'est encore plus critique pour nous** :
- Notre sim est **déterministe seedée** : le même run seed → même boutique R1. Si un joueur
  apprend à identifier (même heuristiquement) les offres R1 favorables par leur composition,
  il peut concéder de façon semi-déterministe. Ce n'est pas exploitable dans SAP (RNG non seedé
  de façon lisible par le joueur), mais dans The Pit avec un RNG de run seedé par `rng_state`
  visible en debug, le risque est réel sur le long terme.
- Notre pool est **petit** (FIFO 200). Chaque ghost écarté par un concede = un ghost de moins
  dans le pool pour les autres joueurs.

**Proposition (doc §6.4bis, AVANT code ranked)** :

```
RÈGLE D'INTÉGRITÉ RANKED "ANCRE DE SNAPSHOT" :
  Option A (recommandée, ~5 lignes IO) :
    Capturer le snapshot à startRound (après reroll boutique si reroll payé, pas avant),
    pas seulement à startCombat. Cela garantit que TOUT run ranked qui atteint le premier
    round (même sans achat) génère un ghost. Le concede post-startRound donne un ghost de
    boutique initiale au pool — penalise le concede en alimentant le pool avec des states réels.
    Complément : ne pas capturer si shopTier == 1 AND slots_actifs == START_SLOTS (jour 0
    identique pour tous = ghost peu informatif). Capturer dès le premier achat OU premier
    reroll OU round 2 atteint (whichever comes first).
  Option B (plus légère, 0 moteur) :
    Ajouter un flag `aborted_runs_this_session` ; si > 3, le prochain run ranked est forcé
    (pas d'abandon possible sous peine de ghost forcé). Coût : UX compliqué, grimdark difficile
    à justifier narrativement.
  → RECOMMANDATION : Option A. Zone sans test → test que snapshot capturé au premier achat
    ranked (pas seulement au startCombat). Critère d'intégrité #JJ compatible (cause contrôlée
    par le joueur = ce qu'il achète, pas le concede).
```

**Priorité** : AVANT le code ranked P2. Cette faille ne se résout pas par patch — elle structure
le comportement ranked dès S1.

### 2.2 DÉSACCORD PARTIEL — La cadence de 3 semaines est fausse pour un jeu à run court

**Ce que la ROADMAP dit** (§6.3) : saisons 1-2 à 3 semaines, en citant Fresh Start Effect (Milkman
2014) et Bazaar mensuel. La justification : "Fresh Start court car pas de contenu nouveau".

**Mon désaccord sur le transfert de Milkman 2014 à nos runs** :

Milkman 2014 (Dai, Milkman & Riis, Management Science) mesure la puissance motivationnelle des
**landmarks temporels naturels** — lundi, début de mois, Nouvel An. La propriété clé de ces
landmarks : ils surviennent **indépendamment du comportement du joueur**, à une cadence perçue
comme naturelle. Ils créent une discontinuité dans le récit interne ("nouvelle semaine =
nouveau départ"). **Un reset de saison de jeu compétitif N'EST PAS un landmark naturel** — c'est
un événement arbitraire imposé par le système. Son effet de Fresh Start est conditionnel : il
fonctionne si et seulement si le joueur a eu le temps de s'**identifier** à sa position actuelle
(son tier, sa Profondeur du Puits, ses marques) pour ressentir le reset comme une perte puis
un renouveau.

**La maths de nos 3 semaines** : 2-3 runs/sem = 6-9 runs/saison. Avec notre grille (0 à +4 pts/run),
un joueur peut monter un demi-tier en 3 semaines. Mais cela signifie aussi que 6 runs = 3 fois le
temps de vue des ghosts (FIFO 200, chaque run voit ~10 ghosts = 1/20 du pool). À S1, un joueur ne
se sent pas "établi" à son tier après 6-9 runs. Il commence à peine à percevoir la qualité des
adversaires. **Un reset à 3 semaines interrompt la courbe d'apprentissage, pas une position installée.**

**Preuve comparative** : GamineAI (gamineai.com, mars 2026) :

> *"Most teams start between 6 and 12 weeks [for a season]. Pick a length your content pipeline
> can sustain consistently."*

Et ils précisent pour les jeux compétitifs (4-8 événements majeurs par mois vs casual 15-25) :

> *"Competitive / Shooter: 4-8 major events with continuous ranked seasons."*

Le benchmark Bazaar mensuel cité dans la ROADMAP est également mal transféré : The Bazaar a un
pool mondial + des dizaines de milliers de joueurs = chaque joueur voit des adversaires variés
et monte rapidement. Avec notre pool FIFO 200 LOCAL, 3 semaines = le joueur a potentiellement
rencontré une fraction significative du pool. La **variété perçue du ranked est épuisée** avant
que la saison ne se termine. Le reset n'arrive pas trop tard — il arrive trop tôt.

**Proposition (doc §6.3, pas de code) — cadence révisée** :

```
CADENCE RÉVISÉE (challenger à la ROADMAP v9 §6.3) :
  Saisons 1-2 (pré-P3) : 5 semaines (non 3)
    Pourquoi : 2-3 runs/sem × 5 sem = 10-15 runs = 1 tier complet pour un joueur mid-core
    = accumulation SUFFISANTE pour ressentir une position et le reset comme une vraie discontinuité.
    = Bazaar mensuel (4,3 semaines) est plus proche de ce seuil que de 3 sem.
  Saisons P3+ : 6-8 semaines (maintenus)
  Garde-fou bas : jamais < 4 semaines en run-court (sinon le joueur n'a pas le temps de voir
    sa Profondeur du Puits évoluer — le signal pré-run §6.11 n'a rien à afficher).
  Garde-fou haut : jamais > 10 semaines sans contenu (pool ghost stagne, meta prévisible).
  Source : GamineAI 2026 ; Milkman 2014 relu (landmark naturel ≠ reset arbitraire) ; maths
    propres (10-15 runs/saison = 1 tier complet).
```

**Ce que ça change concrètement** : à 5 semaines, un joueur mid-core (2 runs/sem) fait 10 runs,
monte d'un tier, voit sa Profondeur du Puits atteindre le round 7-8, et rencontre ~50 ghosts
différents (non plus ~30). Le reset à ce moment a une discontinuité perçue réelle.

### 2.3 DÉSACCORD FAIBLE — Le signal pré-run manque la dimension d'apprentissage post-run (signal d'hypothèse)

**Ce que la ROADMAP dit** (§2.3 r09 adopté, §6.11) : signal pré-run = LP + distance au prochain
tier + distance à la marque + signal d'élan 3 runs + record Profondeur du Puits. Ensemble = 5
dimensions de signal. C'est le manquant #1 du ranked (round 4), corrigé.

**Mon désaccord partiel** : ces 5 dimensions sont toutes des SIGNAUX DE POSITION (où j'en suis).
Aucune n'est un SIGNAL D'APPRENTISSAGE (ce que j'aurais pu faire différemment).

**La distinction est mécaniste** — Grid Sage Games (gridsagegames.com, août 2025, Kyzrati) sur les
roguelikes compétitifs :

> *"Players expect challenges and rewards to remain within certain bounds by default, and anything
> that changes the status quo should ideally be telegraphed. Immediate feedback on actions and their
> consequences is important, enabling players to more quickly build that knowledge and afford greater
> agency in the long run."*

Dans un système déterministe (nos combats sont identiques pour la même seed), le near-miss est
déjà présent (§2.3 ROADMAP). Mais le signal near-miss actuel est formulé comme un **signal
émotionnel** ("il s'en est fallu de peu") et non comme une **hypothèse testable** ("l'unité X
au round 7 t'a coûté la victoire parce que son ciblage était défavorable à ta ligne"). Or c'est
la **deuxième formulation** qui déclenche le restart dans un roguelike compétitif — le joueur
revient pour tester si son hypothèse est correcte (Balatro confirme ce mécanisme : armchairarcade
2026, "each run teaches them something new about how the systems interact").

**Nuance importante** : c'est un problème de FORMULATION du near-miss (§2.3), pas de signal
supplémentaire. La ROADMAP décrit le near-miss comme "tu étais si proche" — il faudrait "si tu
avais placé X en front au lieu de Y, la colonne 3 n'aurait pas été exposée au round 8". Ça ne
coûte rien de plus en moteur (l'event-log JSONL est déjà structuré avec source/cause, §3.2
00-state) — c'est une reformulation du signal post-run.

**Proposition (doc §2.3, 0 code) — enrichir la formulation du near-miss** :

```
NEAR-MISS REFORMULÉ COMME HYPOTHÈSE TESTABLE (0 coût additionnel) :
  Format actuel (§2.3) : "TU ÉTAIS SI PROCHE — LE PUITS A ABSORBÉ TON ASCENSION"
  Format proposé : "LE PUITS T'A BRISÉ AU ROUND [N] — [UNITÉ] FACE À [FAMILLE ADVERSAIRE]
    — ESSAIE [UNITÉ ALTERNATIVE AVEC PROFIL ANTI-X] AU PROCHAIN RUN"
  Logique : l'event-log JSONL capture source/cause de la mort ; la famille dominante de
    l'adversaire est connue (snapshot servi) ; le profil des unités by famille est dans units.lua.
    → suggestion = une unité de la même famille que la death-cause dominante mais avec "counter"
    (ex. tank si mort par burn direct, regen si mort par poison DoT lent).
  Ce n'est pas un "tutoriel" — c'est une hypothèse grimdark à tester. "Le Puits révèle sa faille."
  Zone sans test → test que le format ne crash pas si l'event-log est vide (combat non démarré).
  Grimdark-cohérent : le Puits n'aide pas, il révèle — cryptique mais actionnable.
```

---

## 3. Propositions priorisées

### 3.1 PRIORITÉ 0 (AVANT code ranked) — "Ancre de Snapshot" ranked : capturer au premier achat, pas seulement à startCombat

**Problème** : §2.1 — la capture au `startCombat` seul crée un concede meta silencieux.

**Proposition** (doc + ~5 lignes IO `snapstore.lua:save`) :

```
ANCRE DE SNAPSHOT RANKED (integrity guard) :
  Déclencher snapstore.save si :
    (a) mode ranked AND premier achat de run effectué (runState.shopBuys >= 1 pour ce run)
    OU (b) mode ranked AND round 2 atteint (startRound(2) appelé)
    OU (c) mode ranked AND startCombat (comportement actuel — conservé comme fallback)
  Condition d'exclusion : shopTier == START_TIER AND slots_actifs == START_SLOTS AND shopBuys == 0
    (run ranked abandonnée avant tout achat = ghost informatif nul → ne pas polluer le pool)
  Flag : snapstore.lua ajoute `"capture_reason": "first_buy" / "round_2" / "combat"` dans le snapshot
    (debug uniquement, pas dans toComp)
  Impact intégrité :
    - Un concede après le premier achat génère quand même un ghost → le pool reste rempli
    - Le joueur qui concède 3 fois voit ses boutiques R1 contribuer au pool adverse
    - Il n'y a PAS de pénalité directe (cohérent avec le principe sans pénalité §6.2) — mais
      l'avantage du concede est neutralisé (son build R1 alimente le pool de ses futurs adversaires)
    - Grimdark-cohérent : "Le Puits garde trace de chaque descente, même avortée."
```

**Priorité absolue** : à documenter dans §6.4bis AVANT d'écrire une ligne de code ranked.
Zone sans test → ajouter test que `save()` est appelé au premier achat + test que les runs
abandonnées avant achat ne génèrent PAS de ghost (ghost de boutique vide = pas utile).

Source : steamcommunity.com Bazaar (concede meta documenté) ; azurgames.com Kingdom Clash
(exploits asymétriques = confiance détruite) ; gameanatomy.blog/2025/08 (matchmaking rigging).

### 3.2 PRIORITÉ 1 (doc, ~30 min) — Cadence de saison : 5 semaines minimum pour S1-S2

**Problème** : §2.2 — 3 semaines = 6-9 runs = pas assez pour s'identifier à une position et
ressentir le reset comme un renouveau (Milkman 2014 mal transféré).

**Proposition** : modifier §6.3 ROADMAP.

```
CADENCE RÉVISÉE §6.3 :
  S1-S2 (pré-P3) : 5 semaines (non 3)
  Justification : 2-3 runs/sem × 5 sem = 10-15 runs → 1 tier complet pour un joueur mid-core
    → joueur "établi" à sa position avant le reset → discontinuité perçue réelle.
  Nota bene : si pool local faible (< 30 ghosts ranked), une saison de 3 semaines risque que
    certains joueurs aient rencontré TOUT le pool ghost → adversaires répétitifs → ranked perd
    sa valeur de comparaison → 5 semaines donnent le temps au pool de se régénérer.
  Garde-fou bas : 4 semaines minimum (dessous = session, pas saison).
  Garde-fou haut : 10 semaines maximum sans contenu (15 semaines ou + = staleness guarantee).
  Source : GamineAI 2026 (6-12 semaines recommandées) ; Milkman 2014 relu (landmark naturel,
    non arbitraire) ; maths propres (runs/sem × 5 sem = 1 tier).
```

**Conséquence** : le tableau §6.3 devient :

| Saison | Durée | Condition |
|---|---|---|
| Saisons 1-2 (pré-P3) | **5 sem.** | pas de contenu — Fresh Start minimal mais réel (non 3 sem.) |
| Saisons P3+ | **6-8 sem.** | nouveau tuning majeur = mini-refresh |
| Saisons P4+ (reliques G) | **8-10 sem.** | contenu nouveau = durée longue justifiée |

### 3.3 PRIORITÉ 1 (doc, §6.3 + §6.4bis) — Prérequis du filtre de persistance : `tier_proxy`, pas seulement `wins_at_capture`

**Problème** : §1.4 — `wins_at_capture >= 3` comme filtre de qualité ghost est un proxy fragile.

**Proposition** (doc) :

```
FILTRE DE PERSISTANCE ghost ENRICHI (§6.3 + §6.4bis) :
  Critère actuel : wins_at_capture >= 3
  Critère enrichi : wins_at_capture >= 3 AND slot_tier_composite >= MIN_COMPOSITE [PH]
  MIN_COMPOSITE = shopTier × slots_actifs → valeur [PH] ; suggestion : MIN_COMPOSITE >= 6
    (ex. shopTier=2, slots=4 OU shopTier=3, slots=3 — build avec progression visible)
  Garde-fou : si le pool ghost tombe sous RANKED_MIN_POOL SOFT=3 avec ce double critère →
    relaxer temporairement à wins_at_capture >= 2 seulement (priorité : pool non vide).
  Grimdark : "Le Puits ne garde que les ombres qui ont prouvé leur descente."
  Zone sans test → test que les ghosts filtrés respectent les deux critères + test fallback
    si pool < SOFT.
```

### 3.4 PRIORITÉ 2 (doc §2.3, 0 code) — Near-miss reformulé comme hypothèse testable

**Problème** : §2.3 — le signal near-miss actuel est émotionnel, pas actionnable.

**Proposition** (doc + reformulation de la string i18n `combat.near_miss`) :

```
FORMAT NEAR-MISS HYPOTHÈSE (§2.3 enrichi, 0 coût moteur) :
  Condition : victoires >= WIN_TARGET - 2 ET défaite au round N (N > 5)
  Format string (i18n) :
    "[NOM_UNITÉ] A CÉDÉ AU ROUND [N]"
    "FAMILLE DOMINANTE DU PUITS : [FAM_ADVERSAIRE]"
    "ESSAIE [UNITÉ_ANTI_FAM] — [SA MÉCANIQUE EN 3 MOTS]"
  Logique (RENDER, lit bus JSONL) :
    - unit mort en dernier = l'unité mentionnée
    - famille dominante = family la plus représentée dans les stacks DoT au moment de la mort
      (lit l'event-log, déjà structuré source/cause)
    - unité_anti_fam = 1 unité de rang 2-3 avec trigger "counter" sur cette famille
      (précomputable depuis units.lua, table statique [PH])
  Contrainte : JAMAIS prescrire une unité absente du pool actuel de boutique (sinon frustration).
    → suggestion issue de la famille adverse OU type "shield" si famille non reconnue.
  Texte grimdark : sobre, factuel, non condescendant. "Le Puits révèle sa faille."
  Zone sans test → test que le format ne crash pas si event-log vide.
```

Source : gridsagegames.com 2025 (feedback actionnable = moteur de mastery) ; armchairarcade 2026
(Balatro : "each run teaches them something new about how the systems interact").

### 3.5 PRIORITÉ 2 (doc §6.2 prérequis) — Profondeur du Puits : documenter le prérequis de scaling IA

**Problème** : §1.2 — la Profondeur du Puits n'a de valeur que si les adversaires scalent réellement.

**Proposition** (doc §6.2, 0 code) :

```
PRÉREQUIS PROFONDEUR DU PUITS : SCALING IA visible (§6.2 + §6.4 enrichis)
  La Profondeur du Puits est un signal de progression INDIVIDUELLE. Elle n'est motivante que
  si le joueur perçoit une vraie différence de difficulté entre le round 4 et le round 8.
  Prérequis à documenter dans §6.2 AVANT d'implémenter le signal pré-run :
    (a) La courbe d'escalade des adversaires IA (`encounters.lua`) doit être documentée et
        visible (quel tier d'IA à quel round). Aujourd'hui non documentée pour l'escalade.
    (b) Les ghosts ranked servis au round 8+ doivent avoir `slot_tier_composite` >= seuil
        visible (ex. "les fantômes du cercle 8 sont les plus corrompus"). Cette information
        peut être affichée dans le pré-run (signal de menace, 0 mécanique).
    (c) Si la courbe IA est plate (tous les IA ont la même force de round 1 à 10), la Profondeur
        du Puits mesure une limite d'économie (or), pas une limite de skill.
  → Vérification simple : lire `encounters.lua` et vérifier que les builds IA escaladent
    sur les rounds (sinon = dette de contenu à résoudre AVANT d'implémenter §6.2 signal).
```

---

## 4. Démontage des analogies faibles restantes

### 4.1 — "Milkman 2014 justifie des saisons courtes" = analogie mal transférée

**Argument ROADMAP §6.3** : Fresh Start Effect (Dai, Milkman & Riis 2014) → landmarks temporels
proches = plus puissants → saisons 3 semaines.

**Problème du transfert** : Milkman 2014 étudie des landmarks NATURELS (lundi matin, 1er du mois,
anniversaire). Ces landmarks sont puissants parce qu'ils sont **culturellement préexistants** et
perçus comme des points de départ indépendants du comportement de l'individu. Un reset de saison
de jeu compétitif est un landmark **artificiel imposé**. Sa puissance de Fresh Start est
**proportionnelle au sentiment d'avoir quelque chose à recommencer** — ce qui exige une accumulation
préalable. 6-9 runs ne créent pas suffisamment d'attachement à la position actuelle pour que le
reset ressemble à un renouveau plutôt qu'à une interruption.

**Ce que Milkman dit réellement qui NOUS concerne** : les landmarks proches motivent dans le
contexte d'objectifs répétitifs (exercice quotidien, épargne). Dans ce contexte, un "reset" est
efficace parce que la fréquence de l'action est élevée. À 2-3 runs/sem, la fréquence n'est pas
assez haute pour que 3 semaines soit perçue comme une saison vs une session prolongée.

**Conclusion** : retenir Milkman 2014 pour justifier les gardes-fous BAS (ne jamais faire de
saison < 4 semaines), pas pour justifier 3 semaines vs 5.

### 4.2 — "Le Bazaar mensuel = notre benchmark de cadence" = fausse équivalence

**Ce qui différencie The Bazaar** : pool mondial de dizaines de milliers de joueurs = adversaires
non répétitifs. Chaque run voit 10 ghosts uniques parmi des milliers. La variété perçue n'est
pas épuisée après 10 runs. Notre FIFO 200 LOCAL est épuisé en ~20 runs (200 ghosts / 10 par run).
À 5 semaines × 2 runs/sem = 10 runs = pool non encore répété. À 3 semaines = 6 runs = le joueur
a vu ~60 ghosts sur 200 potentiels — mais le pool n'est pas encore régénéré (il dépend de combien
de joueurs ranked sont actifs). Avec un petit lancement, le Bazaar mensuel n'est pas comparable.

**Ce qui reste valide du Bazaar** : leur décision de reset **soft** (non wipé à zéro, top players
ramenés à un tier inférieur, non à Bronze) est correcte et déjà adoptée dans §6.3 (−20 %). Source :
bazaar-builds.net/announcement-future-updates... (sept. 2025).

### 4.3 — "Pool ghost biaisé vers les builds qui ont eu de la chance" = vrai mais sous-adressé

**R08 ranked §3 (Backpack Battles)** avait pointé ce problème : en ghost pool win-rate filtré,
les builds disponibles au high tier sont biaisés vers ceux qui ont gagné avec de la chance.
Le `wins_at_capture >= 3` atténue, pas élimine.

**Ce qui manque** : le Cinder matchmaking (arxiv.org/html/2602.17015, 2026) montre que la
vraie équité d'un pool basé sur skill nécessite de comparer les distributions de skill, pas
juste des proxies discrets. Notre `slot_tier_composite` est un bon proxy mais uni-dimensionnel.

**Non-recommandation pour R10** : implémenter Cinder serait over-engineering pour notre pool de
200 snapshots. Mais documenter dans §6.4 que le `slot_tier_composite` est un PROXY et non une
mesure de skill, et que des améliorations futures (ex. ratio wins/runs capturé dans le snapshot)
renforceraient l'équité.

---

## 5. Questions ouvertes nouvelles (R10)

### 5.1 [NOUVEAU #LL] — Snapshot ancre ranked : Option A (premier achat) vs fallback temporel (round 2)

**Options** :
- Option A (premier achat) : capture au `shopBuys >= 1` — représente l'engagement du joueur dans
  le run. Un joueur qui ouvre le shop mais n'achète pas = pas encore engagé.
- Option B (round 2 atteint) : capture temporelle. Plus simple à implémenter, mais capture des
  builds potentiellement à 0 achat si reroll sans résultat.
- Recommandation : les DEUX conditions en OR (whichever first) — capture dès le premier achat OU
  dès que le round 2 est déclenché.

**Tranchée en P2 avant code.**

### 5.2 [RÉ-OUVERTURE #Y] — FIFO ranked au reset de saison : persistance filtrée suffisante ?

R09 a maintenu #Y ouvert (vidage complet vs persistance filtrée). Avec la proposition 3.1
(capture au premier achat), la fenêtre de grâce 7 jours se remplit PLUS rapidement (chaque
run ranked capturé dès l'achat R1 plutôt qu'à `startCombat`). Cela affaiblit l'argument de
la fenêtre de grâce 7 jours (elle devient plus courte dans la pratique). **À re-trancher en P2
après mesure de la densité du pool avec la nouvelle règle de capture.**

### 5.3 [PRÉCISION #U + #KK] — Profondeur du Puits et escalade IA : prérequis bloquant ou avertissement

Si `encounters.lua` est plat (IA uniform power), la Profondeur du Puits est un signal creux.
**Vérification proposée** (1 grep sur encounters.lua) avant de coder §6.2 signal. Si plat →
corriger l'escalade d'abord, ou reformuler comme "rounds atteints" sans promettre de difficulté
croissante (formulation grimdark : "chaque cercle est plus profond, non plus difficile" — mais
mécaniquement c'est faux si IA plate).

---

## 6. Tableau de synthèse des propositions

| Proposition | Section roadmap | Priorité | Coût estimé |
|---|---|---|---|
| "Ancre de Snapshot" : capturer au premier achat ranked (intégrité) | §6.4bis (nouveau §) | **P0 — AVANT code ranked** | ~5 lignes IO `snapstore.lua`, ~20 lignes test |
| Cadence de saison S1-S2 : 5 sem. (non 3) | §6.3 cadence révisée | **P1 — doc** | 0 code, doc §6.3 |
| Filtre persistance ghost : double critère `wins_at_capture AND tier_proxy` | §6.3 + §6.4bis | **P1 — doc** | 0 code, doc |
| Near-miss reformulé comme hypothèse testable (§2.3) | §2.3 enrichi | **P2 — doc + RENDER** | i18n key + table statique units anti-fam, ~30 lignes |
| Prérequis Profondeur du Puits : vérifier escalade IA (encounters.lua) | §6.2 prérequis | **P2 — doc + 1 grep** | 0 code, grep + doc |

---

## 7. Récapitulatif des litiges ranked — état R10

| # | Litige | Statut R10 |
|---|---|---|
| **#LL** | **NOUVEAU** : Snapshot ancre ranked — premier achat vs round 2 | Ouvert. Recommandation §5.1 : les deux (OR). Prérequis P2. |
| **#KK** | Profondeur du Puits — per-run vs record-saison | **Maintenu CLOS (R09)** : les deux, endroits différents. Enrichi : prérequis escalade IA (§3.5). |
| **#HH** | Palier choc-4 | Maintenu **co-bloquant #GG** (lentille synergies). |
| **#U** | Contrainte de Saison : critère sélection | **Re-qualifié R09** (axe résolu + écart potentiel/réel). Reste ouvert sur le choix précis post-P3. |
| **#Y** | FIFO ranked au reset : persistance filtrée suffisante ? | **Ré-ouvert** : avec la proposition #LL (capture au premier achat), la grâce 7j est affectée → re-trancher en P2 après mesure de densité pool. |
| **#A** | P1 types vs P2 ranked | Maintenu. Précision §5.3 r09 (exclure daily contrainte-famille de `--meta-convergence`). |
| **#V** | Snapshot schema version | Maintenu (lié #Y). |
| **#EE-ranked** | Scope seed daily | CONFIRMÉ (R09). |
| **#GG** | Apex choc axe A/B vs D | Maintenu BLOQUANT (lentille synergies). |
| **#FF** | Interactions inter-familles MID | Maintenu spec à prouver. |
| **#X** | Relique contre-jeu méta | Maintenu P1.5a. |
| **#M** | Relique wide quantité vs arête | Maintenu P1.5b. |
| **#AA** | VRR boutique / pondération hédonique | Maintenu (calibration P3). |

**NEUFS R10** : **#LL** (ancre snapshot ranked — intégrité du concede).
**RÉ-OUVERTS** : **#Y** (impact de #LL sur la persistance filtrée à réévaluer).
**CLOS** : aucun par preuve concluante ce round.

---

## 8. Ce qui s'est amélioré ce round (mesurable)

1. **Une faille d'intégrité silencieuse identifiée et spécifiée** : le "concede meta" (capture
   seulement à `startCombat`) est documenté avec preuve externe (Bazaar Steam août 2025 :
   "kinda HAVE TO concede to win"), mécanisme précisé pour notre contexte seedé déterministe, et
   correction proposée (~5 lignes IO). Ce bug n'était pas dans la ROADMAP en 9 rounds.

2. **Milkman 2014 démontée comme justification de la cadence 3 semaines** : distinction landmark
   naturel vs reset arbitraire, maths propres (6-9 runs = session, pas saison), proposition
   révisée 5 semaines ancrée sur GamineAI 2026 et les données de notre pool FIFO.

3. **Le near-miss complété de sa dimension d'apprentissage** : §2.3 reformulé de signal émotionnel
   en hypothèse testable grimdark (0 moteur supplémentaire, lit l'event-log JSONL déjà structuré).
   Ancré sur Grid Sage Games 2025 (feedback actionnable = moteur de mastery compétitif) et Balatro
   (variable reward + apprentissage par run = moteur de restart).

4. **Prérequis Profondeur du Puits explicité** : le signal #KK n'est motivant que si les
   adversaires scalent réellement. Vérification `encounters.lua` avant code (1 grep).

5. **Double critère filtre ghost** : `wins_at_capture` seul est insuffisant (3 victoires early
   ≠ 3 victoires late structurellement). Enrichi avec `slot_tier_composite >= seuil`.

6. **Analogie Bazaar mensuel démontée** : pool FIFO 200 LOCAL ≠ pool mondial de dizaines de
   milliers → la variété perçue s'épuise à des cadences différentes.

---

## 9. Index des sources R10

| Affirmation | Source vérifiée |
|---|---|
| Concede meta Bazaar documenté par joueurs ("kinda HAVE TO") | steamcommunity.com/app/1617400/discussions/0/591780546280023348/ (août 2025) |
| Ghost replacement Bazaar (your ghost replaces the one you played against) | bazaar-builds.net/did-you-know-how-ghosts-work/ (nov. 2024) |
| Bazaar ranked reset soft + matchmaking par rang (non cross-rank pour newbies) | bazaar-builds.net/announcement-future-updates-for-the-bazaar-september-10th-patch/ (sept. 2025) |
| Kingdom Clash : exploits = confiance détruite ; removal = backlash mais nécessaire | azurgames.com/blog/the-nuances-of-matchmaking-in-kingdom-clash... (fév. 2025) |
| Matchmaking rigging : MMR manipulation par concede, feedback bias | gameanatomy.blog/2025/08/13/matchmaking-rigging/ |
| POE 2 fresh start = 3 conditions : reset + nouvelles règles + incertitude partagée | game-wisdom.com/general/design-philosophy-behind-poe-2... (mars 2026) |
| POE 2 seasonal design : balance changes shift meta each season | gamedesigning.org/beyond/what-makes-poe-2s-seasonal-league-design-so-addictive (avr. 2026) |
| Kydagames : personal best alongside rank = motivation maximale ; rolling resets | kydagames.com/blog/designing-competitive-leaderboards-repeat-visits.html (avr. 2026) |
| NerdSip (Festinger) : upward comparison motivant si gap closable, démotivant si énorme | nerdsip.com/blog/the-science-of-gamification-why-it-works (avr. 2026) |
| GamineAI : saisons 6-12 semaines recommandées ; competitive 4-8 événements majeurs/mois | gamineai.com/blog/live-service-games-events-seasons-and-retention-hooks (mars 2026) |
| EurekAlert / Management Science 2026 : 2 dimensions d'historique → +4-6 % engagement | eurekalert.org/news-releases/1130401 (juin 2026) |
| Grid Sage Games 2025 (Kyzrati) : feedback actionnable = moteur de mastery compétitif | gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes (août 2025) |
| Balatro : variable rewards + chaque run enseigne quelque chose = moteur de restart | armchairarcade.com/perspectives/2026/05/20/balatro-game-review-why-is-it-so-addictive/ (mai 2026) |
| SAP v0.28 : ranked ELO 1v1, async versus distincts d'Arena (jamais ranked) | superautopets.wiki.gg/wiki/Version_0.28 |
| SAP v0.41 : saisons ranked ajoutées juillet 2025 (après coup, non dès v0.28) | superautopets.wiki.gg/wiki/Version_0.41 |
| Reynad Bazaar : Swiss matchmaking conçu pour éviter les pertes intentionnelles | bazaar-builds.net/reynad-interview-insights-on-the-future-of-the-game/ (déc. 2024) |
| Cinder matchmaking : distribution de skill > proxy discret pour l'équité | arxiv.org/html/2602.17015 (2026) |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 10/10 (FINAL).*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés : toutes les propositions sont doc/IO/RENDER ou décisions éditoriales.*
*Zones sans test nouvelles signalées : §3.1 (snapshot au premier achat ranked) ; §3.4 (near-miss hypothèse) ; §3.5 (escalade IA encounters.lua).*
*1 litige neuf : #LL (ancre snapshot ranked). 1 litige ré-ouvert : #Y (impact #LL sur persistance filtrée).*
*2 analogies corrigées : Milkman 2014 (landmark naturel ≠ reset arbitraire) ; Bazaar mensuel (pool mondial ≠ FIFO 200 local).*
