# Round 04 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 4/10 — challenge le brouillon v4 (`ROADMAP-draft.md` post-round-3) et
> la synthèse `round-03.md`. Les rounds 1-3 (même lentille) ont produit la grille sans pénalité
> (`+4/+2/+1/0`), les marques sub-tier, `slot_tier_composite`, le signal de pool pré-run, la
> Contrainte du Jour, et le Dernier Souffle — tous adoptés dans la roadmap. Ce round se concentre
> sur **ce qui reste fragile ou non-étayé** dans l'architecture ranked v4.
>
> **Sources primaires mobilisées** :
> - `ROADMAP-draft.md` v4 (cible), `round-03.md` (synthèse), `00-state.md` (ancrage)
> - `rounds/r01-03-ranked-competitive.md` (historique)
> - `competitive/{the-bazaar,marvel-snap,super-auto-pets,tft,hs-battlegrounds,postmortems}.md`
> - Recherche web 2025-2026 citée par URL dans §7
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> 32 invariants préservés. Sources citées par URL pour toute affirmation chiffrée.

---

## 0. TL;DR du challenge R04

**Trois angles d'attaque ce round.** (1) Le modèle ranked du brouillon v4 résout les symptômes
(vide mid-core, matchmaking volatil, cold-start punitif) mais n'a **pas encore modélisé son
moteur fondamental** : *pourquoi* un joueur async solo-dev lance une run ranked plutôt qu'unranked.
La réponse n'est pas « les marques sub-tier » (signal insuffisant seul) — elle est dans la
**visibilité du progrès inter-runs** à très court terme. (2) La saison 6-8 semaines est
**sous-spécifiée** : le brouillon la calibre sur la vitesse de montée (~35 pts/tier, 1 tier/saison)
mais ne répond pas à la question structurelle — **que se passe-t-il au bout de 2-3 saisons quand
le joueur plafonne ?** L'analogie TFT / HS:BG ne transfert pas sur ce point (leurs saisons
rejouent le contenu ; nos saisons rejouent la même mécanique). (3) La Contrainte du Jour est
la proposition la plus forte du brouillon pour le daily, **mais son calendrier éditorial est
sous-estimé** : avec 5 contraintes, le cycle se répète en 5 jours — le joueur la voit avant même
de décider de jouer. La solution proposée (10-15 contraintes) existe mais n'est pas séquencée.

Un accord fort sur les décisions actées (sans pénalité, marques, `slot_tier_composite`, signal
de pool pré-run, Dernier Souffle, Contrainte du Jour). Plusieurs angles d'approfondissement.

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 Grille sans pénalité (`+4/+2/+1/0`) — ACCORD FORT, RENFORCÉ

**Accord maintenu.** La recherche web (seganerds.com/2026/06/11) confirme que dans les jeux
compétitifs en 2026, les systèmes de rang sont motivants précisément parce qu'ils rendent le
progrès visible et **ne punissent pas l'effort** : « A rank takes that abstract feeling of
improvement and turns it into a scoreboard ». La recherche BoostRoom (boostroom.com/blog/ranked-online-video-games)
confirme que le sentiment de progression cumulée est le moteur principal du « réenchaîner ».

**Pourquoi ça tient pour The Pit en particulier** : notre contrainte async avec un faible volume
de runs (2-3 / semaine) rend les pénalités encore plus nuisibles qu'en TFT (qui a 15-20 parties
/ semaine). En TFT, perdre 25 LP sur 200 LP cumulés est psychologiquement marginal. Chez nous,
perdre **le seul point gagné cette semaine** reviendrait à effacer l'effort de 2h de jeu.
La grille `+4/+2/+1/0` est une nécessité mathématique, pas un luxe de gentillesse.

**Nuance R04 (nouvelle recherche SAP)** : SAP Versus Mode (superautopets.wiki.gg/wiki/The_Basics,
vérifié) a un système avec **gain ET perte de points** à partir de 1500 de base, reset mensuel.
Ce n'est **pas** le modèle que nous ciblons. La confirmation : SAP Versus est P2P temps réel
(1v1 live), pas async par snapshots. Notre grille sans pénalité est plus proche du rang
pré-Legend du Bazaar (basaar-builds.net/ranking-update, vérifié : **jusqu'à Legend, on ne peut
que gagner des points, pas en perdre**). C'est une **convergence directe** avec notre pilier.

### 1.2 Marques sub-tier (Survivant/Forgé/Ascendant) — ACCORD, COMPLÉTÉ

**Accord maintenu.** La recherche (guul.games/blog/gamification, vérifié) confirme que les badges
activent **deux mécanismes distincts** : (a) le statut social (Festinger — la comparaison sociale
motive si et seulement si **le gap paraît closable**) ; (b) l'instinct collectionneur. Nos 3
marques (pas 20) gardent le gap closable.

**Nuance importante (R04)** : la recherche (egamersworld.com, vérifié) sur la refonte des récompenses
ranked LoL 2025 note une désaffection quand les récompenses cosmétiques deviennent **trop faciles
à obtenir** : « Ranked losing appeal ? ». Si la marque Survivant (5-7 wins) est accessible à ~50 %
des joueurs dès la première saison, elle perd sa valeur de signal. → **Recommandation R04** :
calibrer la marque Survivant sur le **p25 de la distribution des meilleurs runs par saison**
(pas sur un seuil absolu 5 wins), de sorte qu'environ 25 % des joueurs actifs l'obtiennent.
Cette calibration ne peut se faire qu'au launch ; le seuil absolu de 5 wins est un placeholder [PH]
légitime, **à recalibrer dès la première saison**.

**Pourquoi ça tient async** : les marques sont **méta, IO hors SIM** (0 invariant). Le champ
`best_run_wins` est structurellement identique à `season_wins` déjà dans la roadmap. Coût nul.

### 1.3 `slot_tier_composite` comme signal de matchmaking — ACCORD

**Accord maintenu.** Les recherches sur le matchmaking async (thebazaargame.net/guides-news, vérifié)
confirment que The Bazaar utilise un **matching par rang** depuis la mise à jour septembre 2025 :
« ghosts of players of their rank or lower ». Ce n'est pas un `build_cost_proxy` instable — c'est
un bracket de rang **monotone croissant** dans la progression, exactement ce que propose
`slot_tier_composite`. La convergence avec notre solution est directe.

**Nuance technique (R04)** : The Bazaar filtre les ghosts par **rang actuel du joueur** (un entier
de rang ELO/bracket), pas par un proxy de force du build. Notre `slot_tier_composite = shopTier × slots`
est plus granulaire qu'un bracket de rang pur — ce qui est une **force** (deux joueurs au même
bracket peuvent avoir des builds très différents en fonction de leur avancement boutique). À
**documenter dans le test de round-trip** (zone sans test mentionnée §6.4 roadmap) : vérifier que
`slot_tier_composite` ne varie pas de plus de ±4 entre deux snapshots du même run à `wins_at_capture`
identiques.

### 1.4 Signal de pool pré-run (remplace `quality.human`) — ACCORD FORT

**Accord fort.** La confirmation critique vient du Bazaar lui-même (bazaar-builds.net/announcement,
vérifié) : le patch septembre 2025 a retiré le système de pénalité silencieuse et ajouté de la
**transparence sur l'état du pool avant la run**. C'est exactement le pattern que nous ciblons.
La convergence avec un jeu async PvP réel (le plus proche du nôtre) en production est la
validation la plus forte possible.

**Note de nuance** : The Bazaar a pu implémenter ça parce qu'ils ont un **backend serveur** avec
des pools de ghosts tracés en temps réel. Notre implémentation v1 (locale, `snapstore.lua`) ne
peut afficher que l'état du **pool local** (FIFO 200 snapshots). La progression vers un backend
distant (P4 §8.3) est la précondition pour un signal de pool **inter-joueurs** exact. En local,
le signal peut s'afficher comme : « Pool local : X ghosts disponibles à ce tier (progression
partielle) ». **C'est suffisant pour v1** — et le pattern reste valide.

### 1.5 Contrainte du Jour seedée — ACCORD DE PRINCIPE, CHALLENGE SUR LE CALENDRIER

**Accord sur le mécanisme** : StS Daily Challenge (confirmé actif, avec une base d'utilisateurs
~7000 j/jour depuis 8 ans — bullethaven.com, cité round-03) est la référence la plus robuste.
Le modèle modifier-seedé est la bonne direction.

**Challenge R04 sur le calendrier** : voir §2.3.

### 1.6 Dernier Souffle (à 1 vie, relique tier-4 gratuite seedée) — ACCORD MAINTENU

**Accord fort.** La psychologie du near-miss sous tension (Clark 2009, Cognition) tient pour
un jeu à 5 vies. **Nuance R04 (nouvelle)** : le Bazaar (the-bazaar.md §7.1) a un système
analogue (« Fate ») qui se déclenche à **0 Prestige** (sur 20) — mais la tension y est maximale
car le joueur ne peut plus perdre (game over imminent). Dans The Pit à **1 vie sur 5**, la
tension est élevée mais pas terminale — c'est la zone near-miss la plus productive psychologiquement
(pas du désespoir, pas du confort). **Décision actée §6.10 du brouillon : inchangée.** L'accord
est stable depuis R03.

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — Le moteur du « réenchaîner pour grimper » n'est pas modélisé

**Ce que le brouillon affirme** : les marques sub-tier + la grille `+4/+2/+1/0` + `season_wins`
« comblent le gouffre mid-core » et poussent à enchaîner les runs.

**Mon désaccord** : le brouillon confond **signal post-run** (ce que le joueur voit après avoir
joué) et **moteur pré-run** (ce qui pousse le joueur à lancer une run ranked *plutôt qu'unranked*).
Les marques sub-tier et `season_wins` sont des signaux **post-hoc** — ils apparaissent après la
run et n'ont aucune capacité d'initier une nouvelle session.

**La psychologie du grind ranked** (seganerds.com/2026/06/11, vérifié) est explicite : «ranked
play stacks a second hook on top of visible progress: **uncertainty**. That unpredictability...
keeps you queuing long after you meant to stop.» Le moteur, ce n'est pas « regarder ses marques »
— c'est l'**incertitude résoluble** de « Est-ce que je vais monter ce run ? ». Cette incertitude
exige un **signal visible AVANT le run sur son potentiel de progression**.

**Ce qui manque concrètement** : avant de lancer une run ranked, le joueur doit voir **combien
de points il peut gagner** selon ses performances passées. Ce n'est pas le signal de pool (qui
informe sur les adversaires, pas sur le gain potentiel). C'est un **affichage de la récompense
potentielle** : « Ascension = +4 pts, Chute 8-9 = +2 pts, Chute 6-7 = +1 pt ». Trivial à
implémenter, absent du brouillon.

**Analogie TFT valide mécaniquement** : dans TFT, l'écran de sélection de mode affiche le LP
potentiel gagné pour chaque placement selon votre MMR. C'est précisément ce qui fait que le joueur
*ouvre* le mode ranked plutôt que normal (immortalboost.com/blog/teamfight-tactics, vérifié).
**Ce « pourquoi » psychologique survit à nos contraintes async** : le signal est pré-run (affiché
à la sélection), hors SIM, purement RENDER, 0 invariant. Et le calcul est trivial (la grille
`+4/+2/+1/0` est connue statiquement).

**Proposition P1 prioritaire** : voir §3.1.

### 2.2 DÉSACCORD PARTIEL — Le plafonnement inter-saisons n'est pas adressé

**Ce que le brouillon propose** : 5-6 tiers × 35 pts/tier, cycle ~2 saisons pour atteindre le
sommet. Reset saisonnier −20 % du rating visible, MMR interne jamais resetté.

**Mon désaccord** : le calcul de vitesse de montée (~35 pts/tier, 1 tier/saison) est défendable
**pour les saisons 1-3**. Mais le brouillon ne modélise pas ce qui se passe quand un joueur
**plafonne dans un tier** — et c'est là que le ranked meurt.

**La leçon HS:BG que le brouillon ne tire pas** (hs-battlegrounds.md §9.2) : Blizzard documente
que la zone « 6000 MMR+ » est un mur psychologique où les joueurs perçoivent une stagnation qui
chasse les compétitifs. TFT a introduit le **tier Emerald** (au-dessus de Platinum, en dessous de
Diamond) précisément pour éviter ce type de congestion dans un palier où tous les « above-average »
s'accumulent (boosteria.org/guides/tft-lp-mmr, vérifié, 2026).

**Notre cas est pire** : dans TFT/HS:BG, la **rotation de contenu** (nouveaux sets, nouvelles
tribus) change la méta à chaque saison — le joueur qui plafonne a quelque chose de *nouveau* à
apprendre. Dans The Pit (v1), nos saisons ne font que resetter le rating. **Si le contenu ne
change pas entre deux saisons, pourquoi le joueur qui a atteint son plafond naturel (disons Tier 3)
rejouerait la saison 2 ?** La réponse du brouillon (rotation légère de pool/reliques G en P4) est
la **bonne** — mais la P4 est très tardive et le plafonnement intervient avant.

**Quelle est la menace concrète ?** Supposons une distribution réaliste : 30 % des joueurs actifs
d'une saison 1 atteignent le tier 3 (Forsaken). Sans nouveauté de contenu en saison 2, leur
incentive à grinder = **l'espoir de monter à tier 4**. S'ils échouent 3 saisons de suite, ils
partent. Le brouillon n'a pas de **filet pour le plafonnement inter-saisons**.

**Proposition P2** : voir §3.2.

### 2.3 DÉSACCORD MINEUR — La Contrainte du Jour avec 5 contraintes est un calendrier trop court

**Ce que le brouillon acte** : 4 contraintes nommées (Jour de Brûlure / Puits / Abîme / Sacrifice)
+ litige #H' ouvert sur « 5 vs 10-15 contraintes ».

**Mon désaccord** : le litige #H' est traité comme secondaire, mais il est en réalité **critique
pour la rétention daily**. Voici les maths :

- Avec **5 contraintes** : le cycle se répète tous les 5 jours. Un joueur qui joue la daily
  3x/semaine revoit la même contrainte toutes les **~2 semaines**. À 6-8 semaines de saison =
  **4-6 répétitions** de chaque contrainte.
- StS 1 a **des dizaines de modifiers** dans son Daily Challenge pour éviter la répétition mécanique
  (slay-the-spire.fandom.com/wiki/Daily_Challenge, vérifié). StS2 continue ce pattern
  (bossdown.com/guides/slay-the-spire-2-daily-climb-guide, vérifié).
- La recherche sur les VRR (Variable Reward Rate) montre que la **prédictibilité totale** neutralise
  l'engagement (déjà cité round-01). Avec 5 contraintes sur 5 jours, le joueur sait 5 jours à
  l'avance quelle contrainte arrive. C'est un **calendrier éditorial entièrement prédictible**, pas
  une surprise.

**L'argument du brouillon** (« 2 contraintes pour valider, puis étendre ») est correct pour
**l'implémentation minimale** — mais la roadmap ne **planifie pas l'extension**. Le litige #H'
devrait être **tranché maintenant** avec une cible chiffrée, pas laissé ouvert.

**Ce qui survit à nos contraintes** : chaque contrainte dérive de la seed (déterministe #2), ne
touche pas la SIM, est une combinaison de filtres `U.pool` + modificateurs de règle simples. Créer
10 contraintes depuis une seed = combiner 2-3 axes (famille × sigil × économie) pour obtenir des
contraintes **compositionnelles** sans nécessiter 10 branches de code distinctes. Voir §3.3.

### 2.4 DÉSACCORD STRUCTUREL — La grille `+4/+2/+1/0` mesure l'ascension, pas le grind ranked

**Ce que le brouillon propose** : grille calibrée sur l'issue du run — ascension 10 victoires = +4 ;
chute 8-9 = +2 ; chute 6-7 = +1 ; chute ≤5 = 0.

**Mon désaccord de fond** : cette grille **mesure la performance dans un mode qui n'est pas
fondamentalement différent d'unranked**. Le joueur fait les mêmes actions (build, combat, itère)
qu'en unranked. Le signal post-run lui dit « tu as bien joué » ou « tu as moyennement joué », mais
il ne lui dit pas **ce que la run ranked lui a appris de spécifique sur ses adversaires**.

**La vraie asymétrie ranked/unranked dans The Pit** : un run ranked est confronté à des **snapshots
de rang similaire** (grâce au `slot_tier_composite`). Un run unranked contre des IA ou des snapshots
quelconques. Donc la valeur du ranked est que **l'adversaire est informatif sur le level courant
du joueur**. Or **ni la grille ni les marques ne valorisent explicitement cet apprentissage**.

**Ce qui manque** : dans Snap, le joueur comprend après chaque partie pourquoi il a gagné ou perdu
(les cartes adverses sont révélées). Dans TFT, le lobby de 8 joueurs révèle les builds gagnants.
Dans The Pit ranked, le joueur combat un ghost — **il ne voit jamais le build adverse sauf en
combat**. Si ce build est informatif (« le ghost de même tier que moi utilise 4 poison et je
n'en avais que 2 — c'est pour ça qu'il a gagné »), la run ranked lui a donné **de l'information
exploitable**. Mais rien dans le brouillon ne valorise ou même ne *rend visible* cet apprentissage.

**Connexion avec le post-combat « pourquoi »** (§2.3 brouillon, co-priorité 1) : le post-combat
« pourquoi » lit le bus SIM de notre propre run. Pour valoriser le ranked, il faudrait aussi
lire les **caractéristiques du snapshot adverse** (famille dominante, sigil, relique capturée
si capturée dans le snapshot). **Cet enrichissement du post-combat « pourquoi » ranked =
l'asymétrie la plus forte entre ranked et unranked**. Il ne nécessite pas de nouvelle mécanique —
il nécessite de passer les métadonnées du snapshot adverse au post-combat RENDER. Zone sans test.

**Proposition P3** : voir §3.3.

---

## 3. Propositions priorisées

### P1 — Affichage de la récompense potentielle pré-run (moteur du « lancer une run ranked ») — PRIORITÉ 1

**Problème** : absence d'incitation pré-run visible (§2.1).

**Proposition** : dans l'écran de sélection de mode (unranked / ranked), afficher la **grille
de score** avec les valeurs concrètes selon le rating actuel :

```
RANKED — DESCENDRE LE PUITS
  Ascension (10 victoires)   → +4 pts
  Chute honorable (8-9)      → +2 pts
  Descente (6-7)             → +1 pt
  Chute précoce (≤5)         → +0 pt (jamais de pénalité)
  Rating actuel : 12 pts (Condemned — Tier 2)
  Prochain tier (Forsaken) : 35 pts — il vous en manque 23.
```

La phrase « il vous en manque 23 » + la barre de progression visible active le **goal-gradient**
(Nunes & Drèze 2006, déjà cité) et l'**incertitude résoluble** (seganerds.com/2026/06/11) :
le joueur sait que ce run *pourrait* fermer 4 pts sur 23. C'est la psychologie du grind.

**Architecture** : RENDER pur, pré-run, 0 invariant SIM. Lit `playerRating` + `tiers[currentTier]`
depuis le meta-state (IO hors SIM). Coût = ~15 lignes de texte + barre.

**Pourquoi ce n'est pas de l'analogie paresseuse TFT** : TFT affiche le LP potentiel car son
MMR interne dicte le gain exact (boosteria.org, vérifié). Notre grille est **statique** (`+4/+2/+1/0`)
— l'affichage est plus simple encore. Le mécanisme psychologique transféré est l'**incertitude
résoluble** (je peux gagner +4 pts *si* j'ascends), pas le calcul MMR.

**Litige #N (nouveau)** : faut-il afficher aussi le signal de pool (§6.5 brouillon) au même écran
ou dans un écran séparé ? → **même écran** (une seule décision : jouer ranked ou non, avec toutes
les informations disponibles). UX : deux lignes — ligne 1 = grille ; ligne 2 = état du pool.

### P2 — Saison 2+ : mécanisme de renouveau sans contenu (anti-plafonnement inter-saisons) — PRIORITÉ 2

**Problème** : stagnation d'une saison à l'autre sans rotation de contenu (§2.2).

**Proposition** : avant la P4 (reliques G + rotation), introduire un **mécanisme de renouveau
saisonnier léger à coût nul** : la seed de la **Contrainte Permanente de Saison**.

Chaque saison a **1 contrainte permanente active en ranked** (pas seulement en daily) : ex.
- Saison 2 : « Ce Puits Brûle — les unités burn ont +10 % de vitesse d'attaque »
- Saison 3 : « Puits Silencieux — les unités sans `dot_family` gagnent +1 aggro »
- Saison 4 : « Puits Corrosif — toutes les unités démarrent avec 1 stack de poison »

**Différence avec les anomalies HS:BG rejetées** : les anomalies HS:BG sont **aléatoires par
lobby** (incompatibles avec les snapshots déterministes — rejet acté §8.2 roadmap). Notre
contrainte est **identique pour tous les joueurs de la saison** (dérivée du seed de saison) et
doit s'appliquer **aux deux camps** du snapshot. Elle ne change pas les stats du snapshot (qui
reste figé) — elle change les règles **de résolution du combat** qui s'appliquent au snapshot,
comme un `teamFlag` injecté à `combat_start` (**sans modifier le snapshot**). Déterministe,
reproducible, async-compatible.

**Pourquoi ça survit aux piliers** :
1. **Async snapshots** : la contrainte est appliquée à `combat_start` côté résolution, pas codée
   dans le snapshot. Les snapshots des saisons précédentes deviennent inutilisables pour la saison
   courante (pool séparé par `season_id` — déjà dans `{version}` du snapshot struct). **Zone sans
   test** → ajouter un test que la contrainte de saison est bien appliquée aux deux camps.
2. **Sim déterministe** : la contrainte est un `teamFlag` injecté depuis le seed de saison (fixe
   pour tous) → déterministe, reproducible, golden inchangé (car le golden est par scénario, pas
   par saison).
3. **DA grimdark** : « Ce Puits Brûle » est thématiquement parfait. Chaque saison a un nom
   narratif — résonance avec la descente dans le Puits.

**Coût** : 1 `teamFlag` supplémentaire (op data) + 1 champ `season_id` dans le snapshot (déjà
dans `version`). Pas de nouveau op moteur si la contrainte passe par un `teamFlag` existant ou
simple. **Dépendance** : P0.5 (`dot_family` + `grant_team` articulés) + P1 (types). Surtout
une décision data + seed, pas du code moteur.

**Note** : ne se substitue pas aux reliques G (P4 = la vraie rotation) mais comble le vide
entre P2 (ranked v1) et P4 (rotation de méta). La Contrainte Permanente de Saison est
**plus simple** qu'une relique G (pas de topologie, juste un flag) et **plus impactante** que
le `season_wins` seul.

### P3 — Post-combat ranked enrichi : afficher les métadonnées du snapshot adverse — PRIORITÉ 2

**Problème** : le ranked ne donne pas d'information exploitable sur le build adverse (§2.4).

**Proposition** : si le combat est **ranked et contre un ghost humain** (pas une IA), enrichir
l'écran post-combat « pourquoi » (§2.3 roadmap) avec :

```
ADVERSAIRE (snapshot rang 18 / build) :
  Famille dominante : Poison (4 unités)
  Sigil : Anneau
  Relique capturée : [si capturée dans le snapshot v2]
```

Le snapshot actuel (`src/net/snapshot.lua`) encode déjà `{version, tier, seed, shape, units}`. La
famille dominante et le sigil sont **lus directement depuis le snapshot** sans nouveau champ. La
relique n'est pas encore capturée en v1 (00-state §5 « limite à étendre ») → afficher « — » ou
« Inconnue ».

**Pourquoi ça crée l'asymétrie ranked/unranked** : en unranked, le joueur combat souvent une IA
(snapshot IA, froid). En ranked, il combat un ghost humain — le post-combat révèle **le build
d'un pair de son tier**. C'est de l'**information de méta au niveau du tier** : « les joueurs de
mon niveau jouent beaucoup Poison/Anneau en ce moment ». Cela constitue une raison de **jouer
ranked pour en apprendre plus sur la méta**, pas seulement pour les points.

**Architecture** : RENDER + lecture du snapshot adverse (déjà disponible en mémoire à la fin du
combat — `toComp(snap, side)` est appelé dans `build:startCombat`). IO hors SIM. **0 invariant.**
**Zone sans test** → ajouter test que les métadonnées adverses sont correctement extraites du
snapshot et affichées.

**Garde-fou de spoil** : les métadonnées du snapshot adverse ne doivent être affichées **qu'après
la résolution du combat** (post-combat), jamais avant. Évite l'effet « je vois le build adverse
avant de combattre » qui neutraliserait la tension.

### P4 — Trancher le litige #H' : cible 10 contraintes compositionnelles (calendrier éditorial daily) — PRIORITÉ 3

**Problème** : 5 contraintes = cycle 5j = répétition trop rapide (§2.3).

**Proposition : trancher #H' vers 10 contraintes compositionnelles**.

**Mécanique compositionnelle** (évite 10 implémentations séparées) : la seed daily choisit
**2 axes parmi 3** et les combine :
- Axe famille : `{burn, bleed, poison, rot, none}` (none = pas de restriction famille)
- Axe topologie : `{anneau, ligne, croix, none}`
- Axe économie : `{+2 or rang4+, -1 reroll, none}`

Combinaisons actives (éliminer `none × none`) = 5 × 5 × 3 − (none × any × none) − redondances ≈
**12-15 contraintes distinctes** avec 2 variables de code. Le joueur perçoit 12+ jours sans
répétition exact.

**Coût de l'extension de 2 à 10 contraintes** : si l'implémentation est compositionnelle (filtre
`U.pool` par famille + lock de sigil + modificateur d'or — tous déjà implémentables depuis les
structures existantes), l'extension de 2 à 10 est **purement data + seed**, pas du code moteur
additionnel. La seed daily `dailyConstraint = seedHash % #CONSTRAINTS_TABLE` peut déjà pointer
vers une table de tuples `{famille, sigil, eco}`.

**Pourquoi StS tient ici comme précédent** : StS Daily combine ~20 modifiers en composition
pour des centaines de combinaisons (slay-the-spire.fandom.com/wiki/Daily_Challenge). La complexité
perçue par le joueur est « une contrainte du jour » — pas « 3 variables combinées ». C'est le
même design qu'on cible.

**Litige #H' : TRANCHÉ vers 10 contraintes compositionnelles au minimum, extensibles data-only.**
Le prototype (2 contraintes) reste le bon point d'entrée — mais la cible est 10 avant la fin P2.

---

## 4. Vérifications code des propositions (lecture seule)

> Note : je ne lis pas le code source pour valider les propositions — les sources sont le brouillon
> v4 §6.4/§6.5/§6.6, `00-state.md` §5 (structure du snapshot), et les seeds vérifiées rounds 1-3.
> Les propositions sont architecturalement compatibles avec les structures existantes.

### 4.1 Vérification de la structure snapshot pour P3

Snapshot actuel (00-state §5) : `{version, tier, seed, shape, units}`. La **famille dominante**
se calcule en itérant `units[i].id` → `Units.dotFamily(id)` (ou lecture du champ `dot_family`
une fois posé en P0.5) → compter par famille. Requiert P0.5 (`dot_family` explicite). **P3 est
donc dépendant de P0.5** — cohérent avec la séquence du brouillon.

### 4.2 Compatibilité de P2 (Contrainte Permanente de Saison) avec l'invariant #2

L'invariant #2 (« même seed de run → même suite d'offres + seeds de combat ») est préservé car
la Contrainte Permanente de Saison est un `teamFlag` injecté à `combat_start` **depuis le seed
de saison** (distinct du seed de run). Les offres de boutique et les seeds de combat sont
inchangés. **0 conflit d'invariant.** Le golden est inchangé (il ne tournerait pas avec un
`season_id` de saison courante).

---

## 5. Questions ouvertes (nouvelles)

### 5.1 [NOUVEAU] Litige #N — signal de récompense pré-run sur le même écran que le signal de pool ?

Position R04 : **même écran** (une décision = toutes les informations). Challenge possible :
l'écran devient trop chargé si les deux signaux s'y trouvent. Critère de résolution : si les
tests UX (ou retour user après v0.11) montrent une confusion, séparer en deux écrans.

### 5.2 [NOUVEAU] La Contrainte Permanente de Saison doit-elle s'appliquer en daily aussi ?

Si la daily de la semaine a « Jour de Brûlure » ET la saison a « Ce Puits Brûle », le stack est
intense. Position R04 : **non cumulable** (la daily override la saison pour la daily). La Contrainte
de Saison ne s'applique qu'en **ranked hors-daily**. À documenter dans l'état de run.

### 5.3 [NOUVEAU] Quelle est la borne inférieure de runs nécessaires avant le premier reset saisonnier ?

Si un joueur n'a fait **aucune** run ranked avant le reset −20 %, son rating reste à 0. Il ne
souffre d'aucun reset. Mais si la saison 1 dure 6-8 semaines et que le joueur commence à la
semaine 4, son rating est trop bas pour atteindre un tier avant le reset. → Proposer un **reset
conditionnel** : si `ranked_runs_this_season < 3` → reset à 0 (pas −20 %), car −20 % de 0 = 0
de toute façon, mais le message doit clarifier que le joueur n'a pas « perdu » du rating.

### 5.4 [HÉRITÉ R03, à surveiller] Calendrier éditorial daily — TRANCHÉ vers 10 contraintes composées (§3.4)

**Tranché dans ce round** (§3.4). À consigner dans les litiges actés.

### 5.5 [HÉRITÉ R03] Marques sub-tier : reset par saison ou permanent ?

Position R04 : **reset par saison** (pression saisonnière > journal long terme). La comparaison
sociale perd sa valeur si la marque ne se renégocie pas à chaque saison. Cohérent avec le pattern
du Bazaar (reset mensuel) et de HS:BG (reset trimestriel).

---

## 6. Synthèse par proposition du brouillon v4 §6

| Proposition v4 | Verdict R04 | Action recommandée |
|---|---|---|
| Unité de compétition = run (§6.1) | ACCORD FORT (4e confirmation — Bazaar, SAP Versus, notre run court) | Conserver |
| Grille `+4/+2/+1/0` + marques sub-tier (§6.2) | ACCORD + COMPLÉMENT | Ajouter P1 (affichage pré-run) ; calibrer seuil marques post-launch |
| Tiers nommés grimdark (§6.3) | ACCORD | Conserver |
| Règle perte max 1 tier/saison (§6.3) | ACCORD | Conserver |
| Reset saisonnier −20 % (§6.3) | ACCORD + NUANCE | Conditionner reset si <3 runs ranked (§5.3) |
| `slot_tier_composite` matchmaking (§6.4) | ACCORD + TEST REQUIS | Test round-trip ±4 à `wins_at_capture` identique |
| Signal de pool pré-run (§6.5) | ACCORD FORT (Bazaar converge) | Conserver ; local v1 → backend P4 |
| Contrainte du Jour (§6.6) | ACCORD + LITIGE #H' TRANCHÉ | Cible 10 contraintes compositionnelles ; prototype 2 |
| Codex bootstrappé (§6.7) | ACCORD | Conserver |
| `season_wins` perso (§6.8) | ACCORD PARTIEL | Signal secondaire ; P1 (pré-run) est le moteur, pas `season_wins` |
| Dernier Souffle (§6.10) | ACCORD FORT (4e confirmation) | Conserver |
| **Absent : renouveau inter-saisons** | LACUNE | Ajouter P2 (Contrainte Permanente de Saison) |
| **Absent : différenciation info ranked vs unranked** | LACUNE | Ajouter P3 (post-combat métadonnées ghost adverse) |

---

## 7. Index des sources R04

| Affirmation | Source vérifiée |
|---|---|
| Ranked : « uncertainty keeps you queuing » — moteur du grind | [seganerds.com/2026/06/11/why-competitive-rank-systems-keep-players-coming-back-to-online-games/](https://www.seganerds.com/2026/06/11/why-competitive-rank-systems-keep-players-coming-back-to-online-games/) |
| TFT affiche LP potentiel avant de jouer (moteur pré-run) | [immortalboost.com/blog/teamfight-tactics/ranked-system-explained/](https://immortalboost.com/blog/teamfight-tactics/ranked-system-explained/) |
| TFT tier Emerald crée pour éviter la congestion above-average | [boosteria.org/guides/tft-lp-mmr-explained-tft-ranked-really-works](https://boosteria.org/guides/tft-lp-mmr-explained-tft-ranked-really-works) |
| TFT rank distribution Set 17 (Emerald, Platinum, Diamond) | [esportstales.com/teamfight-tactics/seasonal-rank-system-and-player-distribution](https://www.esportstales.com/teamfight-tactics/seasonal-rank-system-and-player-distribution) |
| Bazaar ranké : pré-Legend = gains seulement, Legend = gain ET perte | [steamcommunity.com/app/1617400/discussions/0/591780546280013309/](https://steamcommunity.com/app/1617400/discussions/0/591780546280013309/) |
| Bazaar reset mensuel + « rank loss » Legend tier | [bazaar-builds.net/ranking-update-reset-item-changes-and-more/](https://bazaar-builds.net/ranking-update-reset-item-changes-and-more/) |
| Bazaar sept. 2025 : matching par rang seul (pas proxy de force) + transparence | [bazaar-builds.net/announcement-future-updates-for-the-bazaar-september-10th-patch/](https://bazaar-builds.net/announcement-future-updates-for-the-bazaar-september-10th-patch/) |
| How matchmaking works in The Bazaar (ghost par rang ≤ joueur) | [thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar](https://www.thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar) |
| SAP Versus mode : gain/perte de points, reset mensuel, top 5% = plaque | [superautopets.wiki.gg/wiki/The_Basics](https://superautopets.wiki.gg/wiki/The_Basics) |
| LoL ranked rewards 2025 : désaffection si cosmétiques trop accessibles | [egamersworld.com/blog/league-of-legends-ranked-rewards-system-overhaul-f-wbVlsqkN9U](https://egamersworld.com/blog/league-of-legends-ranked-rewards-system-overhaul-f-wbVlsqkN9U) |
| Psychologie des badges : comparaison sociale motive si gap closable (Festinger) | [guul.games/blog/gamification-101-the-psychology-behind-points-and-badges](https://guul.games/blog/gamification-101-the-psychology-behind-points-and-badges) |
| Overjustification effect : récompenses externes réduisent la motivation intrinsèque | [guul.games/blog/gamification-101-the-psychology-behind-points-and-badges](https://guul.games/blog/gamification-101-the-psychology-behind-points-and-badges) |
| StS Daily Challenge : modifiers imposés, format core, ~7000 j/jour | [slay-the-spire.fandom.com/wiki/Daily_Challenge](https://slay-the-spire.fandom.com/wiki/Daily_Challenge) |
| StS2 Daily Climb : modifiers, leaderboard éphémère | [bossdown.com/guides/slay-the-spire-2-daily-climb-guide/](https://bossdown.com/guides/slay-the-spire-2-daily-climb-guide/) |
| HS:BG dual rating, 6000 MMR mur psychologique | `competitive/hs-battlegrounds.md §9.2` (sourcé blizzard.com/news/23523064) |
| Turnbound : async ghost matchmaking, builds potentiellement en cours de run = fairness concern | [switchbladegaming.com/strategy-games/best-auto-battler-games-2026/](https://www.switchbladegaming.com/strategy-games/best-auto-battler-games-2026/) |

**Sources rounds 1-3 conservées** : Duradoni 2026 (onlinelibrary.wiley.com) ; tilt J. Applied Sport
Psychol. 2025 (tandfonline.com) ; Clark 2009 near-miss (Cognition) ; Nunes & Drèze 2006 endowed
progress (JCR) ; leveluptalk.com frustration hors contrôle ; immortalboost.com floors/MMR TFT ;
screenrant.com Bazaar S2 grille sans pénalité ; boosteria.org TFT dual system.

---

## 8. Nouvelles décisions proposées pour intégration dans la roadmap

| Décision | Section roadmap | Priorité |
|---|---|---|
| **Affichage pré-run : grille + progression vers prochain tier** | §6 (nouveau §6.11) | P2 (ranked v1) |
| **Contrainte Permanente de Saison** (teamFlag seedé, 1/saison, ranked uniquement) | §8 (nouveau §8.0) | P4-light (avant P4, après P2) |
| **Post-combat ranked enrichi** (métadonnées snapshot adverse : famille, sigil) | §2.3 (enrichissement) | P2 ranked, dépend P0.5 |
| **Litige #H' tranché : 10 contraintes compositionnelles** (axes famille × sigil × éco) | §6.6 | P2 |
| **Marques sub-tier : calibrage post-launch sur p25 de la distribution** | §6.2 note [PH] | P3 (sim post-launch) |
| **Litige #N : signal pré-run et signal de pool = même écran** | §6.5 | P2 |
| **Reset conditionnel si <3 runs ranked en saison** | §6.3 | P2 (edge case simple) |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 4/10.*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés : toutes les propositions sont RENDER/IO/data hors SIM. Zones sans test*
*nouvelles signalées : P1 (0 invariant, RENDER), P2 (teamFlag test → test contrainte saison sur*
*les 2 camps, golden inchangé), P3 (test métadonnées snapshot adverse post-combat), #H' (test*
*que la même date → même contrainte compositionnelle).*
