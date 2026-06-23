# Round 05 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 5/10 — challenge le brouillon v5 (`ROADMAP-draft.md` post-round-4) et
> la synthèse `round-04.md`. Les rounds 1-4 ont posé la grille sans pénalité (`+4/+2/+1/0`),
> les marques sub-tier, `slot_tier_composite`, signal pré-run (§6.11), post-combat ranked enrichi,
> Contrainte Permanente de Saison (§8.0), 10+ contraintes compositionnelles. Ce round attaque
> **ce qui reste structurellement non-résolu ou falsement résolu** dans l'architecture ranked v5.
>
> **Règle de méthode (round-04 §5)** : toute proposition sur un mécanisme existant cite la
> ligne de code relue ce round. Ici les mécanismes visés sont architecturaux (ranked = zone
> sans code) ou référencent des structures déjà lues (snapshot §5, state.lua §4).
>
> **Sources primaires mobilisées** :
> - `ROADMAP-draft.md` v5, `round-04.md`, `00-state.md` (ancrage canonique)
> - `rounds/r01-04-ranked-competitive.md` (historique 4 rounds)
> - `competitive/{the-bazaar,super-auto-pets,tft,hs-battlegrounds,marvel-snap,postmortems}.md`
> - Recherche web 2024-2026 citée par URL dans §7
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> 32 invariants préservés. Sources citées par URL pour toute affirmation chiffrée.

---

## 0. TL;DR du challenge R05

**Trois angles d'attaque ce round, tous non-adressés dans les rounds 1-4.**

(1) **L'intégrité async du ranked repose sur une hypothèse non-vérifiée : que les snapshots
servis au joueur sont bien des builds de son tier.** Le brouillon v5 utilise `slot_tier_composite`
comme proxy de matchmaking, mais le snapshot store local (`snapshots.txt`, FIFO 200, `snapstore.lua`)
ne garantit PAS que les builds disponibles dans le pool correspondent au tier demandé. Si le pool
local contient 200 snapshots tous créés en early-game (slots=3, shopTier=1), `serve(version,
tier≤demandé)` peut servir des builds bien inférieurs au tier courant — le joueur perçoit des
victoires faciles ou un ranking "injuste". C'est la vraie faille d'intégrité async, et elle n'a
pas été challengée.

(2) **La grille `+4/+2/+1/0` mesure l'ascension mais NE DIFFÉRENCIE PAS la performance
intra-ascension.** Deux runs qui aboutissent toutes deux à « chute 8-9 victoires » donnent +2 pts
chacune — que le joueur ait dominé ses 8 victoires en 12 rounds ou tremblé jusqu'au round 19.
Dans les autobattlers async (Bazaar, SAP) ce problème est évité parce qu'ils matchent par jour
(pas par run) — chaque ghost remplace celui qu'il a battu, créant une sélection naturelle. Nous
n'avons pas ce mécanisme natif. La grille plate crée une **équité de résultat** (bon pour la
rétention) mais **aucune équité de processus** (mauvais pour la perception de skill).

(3) **Le modèle de Daily Challenge au round 5 a un problème de fairness que l'architecture seed
seule ne résout pas.** La contrainte compositionnelle seedée (famille × sigil × éco) impose un
archétype au joueur. Mais si le pool d'unités burn disponible au tier 1-2 de boutique est plus
faible que le pool poison (hiérarchie poison>choc déjà diagnostiquée), alors « Jour de Brûlure »
vs « Jour de Poison » ne sont PAS des contraintes d'égale difficulté — même avec le même seed.
La recherche sur les daily challenges montre que la fairness perçue dépend de l'équité
**de difficulté**, pas seulement de la reproductibilité (yurukusa.itch.io/spell-cascade,
dev.to/yurukusa, vérifié 2026 : « the seed is authentication, but the experience must feel fair »).

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 Grille sans pénalité (`+4/+2/+1/0`) — ACCORD TRÈS FORT, confirmé par Bazaar post-patch

**Accord maintenu et renforcé.** Le patch Bazaar 6.0.0 (septembre 2025) introduit des rank
points avec gain ET perte pour aider les joueurs à trouver leur rang naturel
(bazaar-builds.net/patch-6-0-0, vérifié) — mais **uniquement pour les nouveaux joueurs**, et
uniquement parce qu'ils ont un backend serveur avec pools mondiaux et vérification de rang réel.
Sans backend, introduire une pénalité sur notre pool local FIFO 200 = punir le joueur pour la
taille limitée du pool, pas pour son skill. La grille `+4/+2/+1/0` reste la seule option
techniquement saine pour v1 local.

**Pourquoi ça tient** : le pool local de 200 snapshots ne garantit pas la représentativité de
tier. Avec pénalité sur un matchmaking imparfait, le joueur perdrait des points pour avoir battu
un build de tier inférieur que le pool lui a donné faute de mieux — signal fallacieux. La
pénalité n'est légitime que si le matchmaking est garanti (backend P4).

### 1.2 `slot_tier_composite` comme proxy de matchmaking — ACCORD DE PRINCIPE, FAILLE NON-NÉGLIGEABLE

**Accord sur le concept, désaccord sur le fait qu'il soit « résolu ».** Voir §2.1 pour la faille.

### 1.3 Séparation pools ranked/unranked — ACCORD TRÈS FORT, NOUVEAU FAIT BAZAAR

**Accord fort.** Le Bazaar (bazaar-builds.net/did-you-know-how-ghosts-work, vérifié, nov. 2024)
confirme : « ghosts from ranked games only appear in ranked matches, and ghosts from normal games
only show up in normal matches. This separation ensures that the competitive balance and integrity
of each game mode are maintained. » Et : « when you play against a ghost — whether you win or lose
— your own ghost takes their place. That means no one else will ever play against the same ghost
you just faced. »

**Transférabilité directe à The Pit** : notre `snapstore.lua` devrait implémenter deux pools
distincts — `ranked_pool` et `unranked_pool` — avec des listes FIFO séparées dans `snapshots.txt`.
Ce n'est pas encore spécifié dans la roadmap ; le brouillon v5 traite le pool comme un seul FIFO.
**C'est un trou de spec.** Les snapshots ranked soumis par un joueur compétent ne doivent pas
« polluer » le cold-start unranked d'un débutant.

**Coût** : data + 1 champ `mode = "ranked" | "unranked"` dans la struct snapshot
(`{version, tier, seed, shape, units}` actuelle, 00-state §5) + 2 FIFO dans le store. IO hors
SIM, 0 invariant. **Zone sans test** → ajouter un test que `serve("ranked")` ne retourne jamais
un snapshot enregistré en mode unranked.

### 1.4 Contrainte Permanente de Saison (§8.0) — ACCORD FORT AVEC PRÉCISION

**Accord fort** sur le principe (teamFlag injecté depuis le seed de saison, identique pour tous,
async-safe). **Précision R05** : le brouillon v5 dit « Saison 3 : "Puits Silencieux — les unités
sans `dot_family` gagnent +1 aggro" ». Ce type de contrainte **favorise les archétypes stat-sticks
(rang-1, les plus nombreux)** et avantage mécaniquement les joueurs qui ont découvert par hasard
les unités sans `dot_family` plutôt que les DoT. C'est une contrainte d'équipe-stats, pas de
méta — elle **ne crée pas un nouvel archétype**, elle en favorise un déjà existant. Le critère
d'une Contrainte Permanente de Saison saine (pour notre format asymétrique) est : **la contrainte
pousse vers un archétype sous-représenté, pas vers l'archétype déjà dominant**. Si la saison
2 est « Brûlure », la saison 3 ne doit pas être « tank » (déjà fort) — elle doit être « choc »
(sous-représenté, pipeline incomplète selon la hiérarchie diagnostiquée). **Critère à ajouter
à la spec §8.0** : pour chaque saison, sélectionner la famille ou l'archétype avec le plus bas
`win_rate_présence` dans `runs/report.json` de la saison précédente.

### 1.5 Signal pré-run (§6.11) — ACCORD FORT, PSYCHOLOGIE VÉRIFIÉE

**Accord fort maintenu.** Le moteur d'incertitude résoluble est établi (seganerds 2026, rounds 1-4).
**Précision R05** : la distance affichée « il vous manque 23 pts » est un signal de **goal
gradient** (Nunes & Drèze 2006). La recherche sur le goal gradient montre qu'il est efficace
**seulement si la distance paraît closable** dans un horizon de jeu perçu (1-3 sessions).
À 23 pts, et avec la grille `+4/+2/+1/0`, la distance = min 6 runs d'ascension (improbable)
ou plus réalistement ~12-18 runs. Pour un joueur à 2-3 runs/semaine, c'est 4-6 semaines —
**au-delà de l'horizon psychologique** (Nunes & Drèze 2006, « The Endowed Progress Effect »,
JCR : l'effet s'efface quand la cible perçue dépasse ~7 étapes). La marque sub-tier (Survivant/
Forgé/Ascendant) est précisément le palier intermédiaire à horizon closable. **Recommandation
R05** : le signal pré-run doit afficher la distance au **prochain palier sub-tier** (pas au
tier suivant), avec un indicateur secondaire de tier. « Prochain grade : Forgé — 4 pts restants »
plutôt que « Prochain tier (Forsaken) : 35 pts — il vous en manque 23 ».

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La faille d'intégrité async de `slot_tier_composite` n'est pas résolue

**Ce que le brouillon v5 affirme** : `slot_tier_composite = shopTier × slots` sert de proxy de
matchmaking ; `serve(version, tier≤demandé, rng)` pioche dans le pool local. « Résout l'intégrité
async du ranked. »

**Mon désaccord** : le `serve` actuel (`snapstore.lua`, cité 00-state §5 : « pool local 200,
FIFO, `snapshots.txt` via `love.filesystem` ») retourne un snapshot **dont le `tier` est ≤ le
demandé** — mais il n'y a AUCUNE GARANTIE que le pool contient des snapshots au tier demandé.
**Cas concret** : un joueur nouveau fait 5 runs et génère 5 snapshots de tier 1-2. Ces snapshots
peuplent le pool. Un joueur tier 4 (Forsaken) reçoit ces builds de débutant en ranked — il gagne
facilement, gagne +2/+4 pts, monte de tier **non pas par mérite mais parce que son pool local est
pauvre en builds adverses de son niveau**. Inversement, un joueur tout seul sur l'installation
(absence de snaps adverses) tombe sur l'IA cold-start (`aiComp` Encounter, 00-state §5) — correct
— mais perd des points si l'IA est bien calibrée, ou gagne des points si elle est sous-calibrée.

**Preuve code** : `snapstore.lua:serve` (cité 00-state §5) : « `serve(version, tier≤demandé, rng)`
(pioche seedée) ; `serveComp = cold-start garanti` (retombe sur `aiComp` Encounter IA si aucun
snapshot) ». La condition `tier≤demandé` filtre par tier **inférieur ou égal** — ce qui est exact
pour l'XP-gating (on ne peut pas monter plus vite que son propre tier) mais **ne garantit pas
que le build adverse est un pair de tier**.

**La différence Bazaar** : The Bazaar a un pool **global de tous les joueurs** avec matching par
rang depuis le patch 6.0.0 (bazaar-builds.net/patch-6-0-0, vérifié). Avant ce patch (beta),
les joueurs se plaignaient exactement du même problème : « ghosts are too easy / not of my level »
(bazaar-builds.net/did-you-know-how-ghosts-work, commentaires, vérifié). Notre v1 locale FIFO 200
reproduit la beta Bazaar pré-patch — avec le même problème d'intégrité.

**Ce qui manque** : une garantie que le pool ranked contient au moins N snapshots de tier
`[demandé-1, demandé]` avant de faire entrer le joueur en ranked compétitif. Sinon, la grille
`+4/+2/+1/0` **récompense de battre l'IA ou des débutants** — pas du skill ranked.

**Proposition P1** : voir §3.1.

### 2.2 DÉSACCORD STRUCTUREL — La fairness du Daily Challenge dépend de l'équilibre des familles, pas seulement du seed

**Ce que le brouillon v5 dit** : 10+ contraintes compositionnelles seedées (famille × sigil × éco)
+ filet pédagogique tooltip = Daily Challenge équitable.

**Mon désaccord** : la seedification garantit la **reproductibilité** (tout le monde joue la même
contrainte) mais pas l'**équité de difficulté inter-contraintes**. Un « Jour de Brûlure »
(famille burn) et un « Jour de Poison » (famille poison) imposent des expériences de difficulté
structurellement différentes si burn et poison ne sont pas équilibrés — et ils ne le sont pas
(hiérarchie poison>choc>...>burn diagnostiquée, the-pit-balance-diagnosis, mémoire).

**Preuve du problème dans la littérature indie** : le développeur de Spell Cascade (yurukusa.itch.io
/spell-cascade, dev.to/yurukusa, 2026, vérifié) documente exactement ce point après avoir implémenté
un Daily Challenge seedé : « the seed is authentication. [But] what's different: their reaction
time, their decision making, their skill execution. » Les deux joueurs affrontent les mêmes
patterns adverses — la difficulté relative est dans **leur archétype de run, pas le seed**.
Ici notre contrainte IMPOSE un archétype — si cet archétype est sous-calibré (burn est plus faible
que poison structurellement), « Jour de Brûlure » punit plus que « Jour de Poison ».

**Maths** : si `win_rate(burn) = 38 %` et `win_rate(poison) = 58 %` dans `runs/report.json`
(hiérarchie diagnostiquée), alors la variance de progression entre deux joueurs actifs sur 10
jours consécutifs dépend de quelles contraintes tombent sur leurs jours de jeu — pas de leur
skill. Sur 10 jours, un joueur qui a eu 6 jours burn et 4 jours poison = démarrage difficile ;
l'inverse = facile. **L'équité du daily est conditionnelle à l'équilibre des familles (P0.5).**

**Conséquence** : le filet pédagogique tooltip (§1.15 round-04, adopté) est nécessaire mais
insuffisant — il informe sur les unités à utiliser, pas sur le fait que la contrainte est plus
dure que la veille. **Le Daily Challenge ne devrait pas imposer une famille dont le win_rate
structurel est < 0.8 × médiane des familles** avant que l'équilibrage (P3) ne la redresse.

**Proposition P2** : voir §3.2.

### 2.3 DÉSACCORD PARTIEL — Le post-combat ranked enrichi (§2.3 v5) dépend de P0.5 mais crée une dette cachée de version snapshot

**Ce que le brouillon v5 dit** : le post-combat ranked enrichi lit « famille dominante = compter
`dot_family` sur `units[]` » directement depuis le snapshot (`{version, tier, seed, shape, units}`).
La dépendance à P0.5 est signalée (champ `dot_family` nécessaire).

**Mon désaccord** : cette dépendance crée une **dette de version snapshot non gérée**. Si le
champ `dot_family` est ajouté aux unités en P0.5 (modification de `units.lua`), les snapshots
**déjà stockés** dans `snapshots.txt` ont des `units` sans `dot_family`. Quand le post-combat
essaie de calculer la famille dominante sur un snapshot v1 (sans `dot_family`), il obtient soit
une erreur, soit une famille `nil` — ce qui affiche une métadonnée vide ou cassée en ranked.

**Preuve structurelle** : `snapshot.lua:toComp(s, side)` (cité 00-state §5) : « ids inconnus
ignorés silencieusement ». Le silencing des inconnues est une bonne pratique pour les unitées
inconnues, mais le champ `dot_family` n'est **pas un id d'unité** — c'est un champ de stat
déduit. Si `Units.dotFamily(id)` est appelé sur un id qui existait avant P0.5 (sans le champ
écrit dans le snapshot), le résultat est déduit à la demande depuis `units.lua` actuel — ce qui
est correct **pour les unités dont le champ existe maintenant**. Mais si entre P0.5 et P2
(ranked) l'unité elle-même est modifiée (cohorte v7 auditée, unités pool-only retirées), un
snapshot de tier 3 qui référence une unité devenue roster-only renvoie `nil` family.

**Ce qui manque** : un **champ `snapshot_version`** distinct du `version` actuel (qui semble
gérer la version de patch du jeu, 00-state §5) pour tracker la **version de schéma du snapshot**
et permettre une migration silencieuse. Sans ça, chaque évolution du schéma snapshot (P0.5 :
`dot_family`, reliques en v2 : `relics[]`) crée une dette de migration non-gérée.

**Proposition P3** : voir §3.3.

### 2.4 DÉSACCORD MINEUR — La Contrainte du Jour peut entrer en conflit avec le ciblage de la sim `--meta-convergence`

**Ce que le brouillon v5 dit** : le test `--meta-convergence` (litige #A, critère : `< 8 runs
pour ≥ 2 sigils` → types d'abord) décide si P1 (types) ou P2 (ranked) est prioritaire. Ce critère
est mesuré sur la méta **libre** (non contrainte).

**Mon désaccord** : si la Contrainte du Jour est active lors de la mesure de `--meta-convergence`,
la convergence observée sera celle des joueurs sous contrainte — pas la convergence naturelle de
la méta libre. Si « Jour de Brûlure » impose burn pendant 2 jours de la semaine de mesure,
`rang_convergence(burn) < 8 runs` **artificiellement** (burn est forcé, pas élu naturellement).
La sim d'équilibrage `tools/sim.lua` tourne sans contrainte journalière (elle est headless, hors
Daily), mais la **méta réelle des joueurs** sera influencée par les contraintes actives. Le critère
#A doit donc être mesuré **sur les runs unranked libres uniquement** (sans contrainte du jour).

**C'est une précision de spec**, pas un désaccord fort — le critère est juste, la condition de
mesure est incomplète. Coût : 0 code moteur, 1 ligne de spec dans le critère.

---

## 3. Propositions priorisées

### P1 — Garantie minimale de pool ranked (intégrité async) — PRIORITÉ 1

**Problème** : pool FIFO local ne garantit pas des adversaires de tier comparable (§2.1).

**Proposition** : avant d'afficher le mode ranked comme disponible, vérifier **`ranked_pool_size
(tier=demandé)` ≥ RANKED_MIN_POOL (= 5 par défaut)**. Si le seuil n'est pas atteint :

```
RANKED INDISPONIBLE
Le Puits ne reconnaît pas encore tes pairs.
[Joue 3 runs unranked pour alimenter le pool]  →  [rejoue en ranked]
```

Ce n'est pas une pénalité — c'est une **condition préalable de fairness**. Le joueur comprend
qu'il nourrit le pool pour lui-même et pour les autres. Grimdark : « Le Puits exige des témoins
avant de juger. »

**Implémentation** :
- Ajouter `mode = "ranked" | "unranked"` à la struct snapshot (00-state §5 : `{version, tier,
  seed, shape, units}` → + `mode`). IO hors SIM, 0 invariant de combat.
- `snapstore:countRankedByTier(tier)` → entier. `save(snap, mode)` range dans la bonne liste.
- `serve` ranked : si `countRankedByTier(tier) < RANKED_MIN_POOL` → afficher « indisponible »
  dans l'écran §6.11 (moteur pré-run).
- **Fallback cold-start maintenu** : si le pool est sous le seuil mais le joueur accepte le mode
  ranked (option avancée), `serveComp` tombe sur l'IA Encounter — mais RENDER le signale
  explicitement : « Adversaire : IA (pool insuffisant — résultat non compté ». Résultat non
  comptabilisé en points ranked.
- **`RANKED_MIN_POOL = 5`** : valeur conservative. 5 snapshots × `max_tier=5` = 25 runs minimum
  pour alimenter le pool tous tiers. Solo dev = cold-start par IA le temps que la base de
  joueurs grossisse. **[PH]** à ajuster.

**Coût** : struct snapshot +1 champ (rétrocompatible : anciens snapshots = `mode = nil` → traités
comme `"unranked"`) ; store +1 liste FIFO ; écran ranked +1 condition d'affichage. RENDER + IO.
**Zone sans test** → ajouter un test que `serve("ranked", tier=3)` ne retourne jamais un snapshot
`mode="unranked"` ni un snapshot de `tier < 3-1`.

### P2 — Condition préalable de fairness du Daily Challenge : gater les contraintes par famille équilibrée — PRIORITÉ 2

**Problème** : imposer une famille avec win_rate structurel < 0.8 × médiane = challenge injuste
pour les joueurs dont c'est le seul jour de jeu de la semaine (§2.2).

**Proposition** : avant d'activer une famille comme contrainte Daily, vérifier dans
`runs/report.json` (produit par `tools/sim.lua`) que `win_rate(famille) ≥ 0.8 × median_win_rate
(toutes familles)`. Si la condition n'est pas remplie → la famille est remplacée par `none` (pas
de restriction famille) dans le tuple compositionnelle `{famille, sigil, éco}`. Le sigil et l'éco
restent actifs.

**Exemple concret** : si `win_rate(burn) = 38 %` et médiane = 48 % → 38 % < 0.8 × 48 % = 38.4 %
→ « Jour de Brûlure » devient « Jour de l'Anneau » (contrainte sigil seule). Le joueur n'est pas
pénalisé par un archétype non calibré.

**Ce n'est PAS une analogie paresseuse avec d'autres jeux** : le « pourquoi psychologique » est
que la **fairness perçue d'un challenge quotidien requiert que la difficulté ne dépende pas de la
loterie d'archétype**. Source : l'expérience Spell Cascade (yurukusa.itch.io, dev.to/yurukusa, 2026)
documentée en §0 : la reproductibilité du seed ne suffit pas — la difficulté intrinsèque de
l'archétype imposé est la variable dominante.

**Dépendance** : `tools/sim.lua` doit produire un `win_rate_by_family` dans `report.json` (c'est
le cas si la sim identifie `dot_family` par unité — dépend de P0.5). Jusqu'à P0.5, les contraintes
compositionnelles sont limitées à axe sigil + axe éco (pas de famille imposée). **C'est de la
discipline de déploiement**, pas un frein à l'implémentation du moteur Daily.

**Coût** : 1 lookup dans `report.json` à la génération de la contrainte quotidienne (IO, hors SIM).
0 mécanique. 0 invariant.

### P3 — `snapshot_schema_version` : découpler la version de schéma de la version de patch — PRIORITÉ 3

**Problème** : chaque évolution du schéma snapshot (P0.5 : `dot_family`, reliques en v2 :
`relics[]`) crée une dette de migration non-gérée dans le pool local (§2.3).

**Proposition** : ajouter un champ `sv` (schema version) distinct du champ `version` (patch) à
la struct snapshot :

```
{version, sv=1, tier, seed, shape, units, mode}
```

`sv=1` = schéma actuel. Quand P0.5 ajoute `dot_family` → `sv=2`. `toComp` et le post-combat
ranked listent le schéma du snap reçu et adaptent la déduction :

- `sv=1` (sans `dot_family`) → déduire depuis `Units.dotFamily(id)` appelé dynamiquement sur
  l'id (comportement actuel, rétrocompatible).
- `sv=2` → lire `unit.dot_family` directement.

Quand reliques capturées en v2 → `sv=3`. Migration silencieuse pour chaque version.

**Pourquoi ce n'est pas prématuré** : les snapshots persistés dans `snapshots.txt` (FIFO 200) ont
une durée de vie potentielle de plusieurs saisons. Le pool ranked en particulier **accumule des
builds** qui devront être lus par du code futur. Sans versioning de schéma, chaque évolution
(P0.5 → P2 → P4 reliques G) exige une migration manuelle ou une purge du pool. La purge est
acceptable une fois ; elle est inacceptable si elle efface le pool ranked d'un joueur établi entre
deux patches.

**Coût** : +1 champ `sv=1` (constante dans le code de capture) ; `toComp` + post-combat ranked
lisent `snap.sv or 1` (backward-safe). Test : round-trip avec `sv=1` doit toujours passer.
0 invariant de combat. **Zone sans test** → ajouter un test de round-trip avec snap `sv=1`
(sans `dot_family`) et snap `sv=2` (avec) ; vérifier que `toComp` produit le même résultat pour
un id connu dans les deux cas.

### P4 — Critère sub-tier plutôt que tier pour le signal pré-run — PRIORITÉ 2 (UX affinement)

**Problème** : afficher « il vous manque 23 pts pour le prochain tier » dépasse l'horizon
psychologique de goal gradient pour les joueurs à 2-3 runs/semaine (§1.5).

**Proposition** : le signal pré-run (§6.11) affiche **deux niveaux** :
- (Primaire) Distance au **prochain grade sub-tier** : « PROCHAIN GRADE : Forgé — 4 pts »
- (Secondaire, plus petit) Progression dans le tier : « Tier 2 — Condemned (12/35 pts) »

La marque sub-tier est l'horizon à court terme (1-3 runs) ; le tier est l'horizon à moyen terme
(1 saison). Les deux sont affichés — mais l'horizon court est l'appel à l'action.

**Source mécaniste** : Nunes & Drèze 2006 (« The Endowed Progress Effect », JCR) : le goal
gradient est efficace si la distance perçue à la cible est < 7 étapes. À `+4/+2/+1/0`, atteindre
un grade sub-tier prend 1-3 runs (selon la performance) — dans l'horizon. Atteindre le tier
suivant prend 8-17 runs — hors horizon. Montrer les deux permet au joueur de choisir son horizon
de motivation.

**Coût** : RENDER pur, ~3 lignes de texte supplémentaires dans l'écran §6.11. 0 invariant.

---

## 4. Faux litige à écarter

### 4.1 « Il faudrait un score intra-run pour différencier les performances à même résultat »

Plusieurs rounds précédents ont effleuré cette idée (comparer deux runs terminées 8-9 victoires).
**Je l'écarte formellement ce round** :

- **Argument psychologique contre** : StS Ascension (le score intra-run le plus influent du genre)
  a **abandonné le classement par score** précisément parce qu'il pousse à optimiser le score
  plutôt que le build. Dans notre système de placement déterministe (grille `+4/+2/+1/0`),
  ajouter un score intra-run crée deux objectifs incompatibles : gagner (prendre des risques) vs
  optimiser le score (jouer safe). Ce conflit est documenté dans les postmortems de Dota Underlords
  (postmortems.md §3.2A : « le ranking mixte skill/speed » a fragmenté la communication de valeur).
- **Argument technique contre** : mesurer le « score de run » dans notre système déterministe
  async = mesurer face à des ghosts de tier variable (pool FIFO imparfait) → le score n'est pas
  comparable inter-runs sans garantie de matchmaking. C'est circulaire : le score sera fiable
  quand le matchmaking sera fiable, et quand le matchmaking sera fiable (P4 backend), on aura
  une base de joueurs suffisante pour que la grille seule fonctionne.
- **Verdict** : ne pas ajouter de score intra-run. La grille plate est une qualité, pas un défaut.

---

## 5. Questions ouvertes (nouvelles)

### 5.1 [NOUVEAU litige #T] — Seuil `RANKED_MIN_POOL` : 5 ou plus ?

**Position R05** : `RANKED_MIN_POOL = 5` est conservative pour un solo dev early. Si la base de
joueurs est <20 joueurs (bêta fermée), 5 snapshots by tier implique 25 runs de seeding total —
potentiellement >1 semaine de jeu. Trop long = le mode ranked est inaccessible trop longtemps.
→ Alternative : `RANKED_MIN_POOL = 3`, avec une mention explicite « expérience ranked limitée »
si 3 ≤ pool < 5 (ghost aléatoire dans le tier, pas garanti pair). **À trancher selon la taille
de la bêta.**

### 5.2 [NOUVEAU litige #U] — Contrainte de Saison : critère de sélection de la famille ciblée

**Position R05** : prendre la famille avec le plus bas `win_rate_présence` dans la saison
précédente. **Critique possible** : si choc est la famille la plus faible (hiérarchie diagnostiquée),
imposer une Contrainte Permanente Saison « Choc » amplifie la frustration de l'archétype le plus
difficile. Alternative : cibler la famille la **plus sous-représentée en pool boutique** (pas la
plus faible en win-rate) — ce qui signifie « la famille que les joueurs jouent peu, pas celle qui
perd le plus ». Ces deux critères sont différents. **À trancher avant la spec §8.0.**

### 5.3 [HÉRITÉ R04, #N — PRÉCISÉ] Pool ranked + récompense pré-run : même écran avec condition de disponibilité

**Précision R05** : l'écran §6.11 + §6.5 (signal pré-run + signal de pool) doit maintenant
intégrer le **gate `RANKED_MIN_POOL`** de P1. Si le pool ranked est insuffisant, l'écran affiche
la raison et la progression vers le seuil : « 3/5 builds de ton niveau stockés. Joue 2 runs
unranked. » C'est cohérent avec le signal de pool, pas un écran séparé.

### 5.4 [HÉRITÉ R04, #R — non affecté] Courbe XP robuste à la variance de durée de run

Non affectée par ce round. Reste P3 avec le critère à 3 tranches (10-12/13-16/17-19 rounds).

### 5.5 [NOUVEAU] Timezone du Daily Challenge pour un jeu local-first

Le problème de timezone est bien documenté par le développeur Spell Cascade (dev.to/yurukusa,
2026, vérifié) : « local midnight means players in different timezones play 'different days'.
An argument for UTC midnight. But UTC midnight is 9am JST. » Notre jeu est local-first (pas de
backend en v1) → le seed daily est `date_locale × prime`. La seed locale est par définition
différente selon le fuseau. Pour v1 local, **accepter la date locale** (même comportement que SAP
Arena, Spell Cascade) et documenter la limitation. La date UTC viendra avec le backend P4.
**Ce n'est pas un litige critique pour le ranked** (le ranked n'est pas lié au Daily) — mais c'est
un point de documentation de la spec Daily à ne pas omettre.

---

## 6. Synthèse des propositions du brouillon v5 (§6)

| Proposition v5 | Verdict R05 | Action recommandée |
|---|---|---|
| Grille `+4/+2/+1/0` (§6.2) | ACCORD TRÈS FORT | Conserver. Pénalité seulement au backend P4. |
| Marques sub-tier (§6.2) | ACCORD | Conserver. Le critère p25 reste [PH] post-launch. |
| `slot_tier_composite` matchmaking (§6.4) | ACCORD + FAILLE | Ajouter P1 (pool ranked séparé + `RANKED_MIN_POOL`). |
| Signal de pool pré-run (§6.5) | ACCORD FORT | Enrichir avec condition de disponibilité (P1 + litige #T). |
| Signal pré-run + récompense (§6.11) | ACCORD + AFFINEMENT | Afficher sub-tier en primaire (P4 de ce round). |
| Contrainte du Jour (§6.6) | ACCORD + CONDITION | Gater les familles par win_rate ≥ 0.8 × médiane (P2). |
| Pool ranked ≠ pool unranked | TROU DE SPEC | Ajouter `mode = "ranked"/"unranked"` à struct snapshot (P1). |
| Post-combat ranked enrichi (§2.3) | ACCORD + DETTE | Ajouter `sv` (P3) pour migration schéma snapshot. |
| Contrainte Permanente de Saison (§8.0) | ACCORD + CRITÈRE | Sélectionner famille sous-représentée (litige #U). |
| 10+ contraintes compositionnelles | ACCORD + CONDITION | Familles non-équilibrées → axe sigil/éco seul (P2). |
| Reset conditionnel <3 runs ranked | ACCORD (inchangé) | Conserver tel quel. |

---

## 7. Index des sources R05

| Affirmation | Source vérifiée |
|---|---|
| Bazaar ghost pool séparé ranked/unranked (intégrité) | [bazaar-builds.net/did-you-know-how-ghosts-work/](https://bazaar-builds.net/did-you-know-how-ghosts-work/) |
| Bazaar patch 6.0.0 : rank points gain ET perte pour les nouveaux joueurs | [bazaar-builds.net/patch-6-0-0-reduced-power-level-of-stelle-scaling-items-more/](https://bazaar-builds.net/patch-6-0-0-reduced-power-level-of-stelle-scaling-items-more/) |
| Bazaar matchmaking : rang seul (pas proxy build), ghosts de rang ≤ joueur | `bazaar-builds.net/patch-6-0-0` (§Matchmaking Changes) |
| Spell Cascade daily challenge : seed = reproductibilité, pas équité de difficulté | [dev.to/yurukusa/5-lines-of-code-that-made-my-roguelike-worth-playing-every-day-3klj](https://dev.to/yurukusa/5-lines-of-code-that-made-my-roguelike-worth-playing-every-day-3klj) |
| Indie daily challenge sans serveur : seed + itch comments + streak localStorage | [dev.to/yurukusa/your-indie-game-doesnt-need-a-leaderboard-server-heres-what-i-built-instead-j4n](https://dev.to/yurukusa/your-indie-game-doesnt-need-a-leaderboard-server-heres-what-i-built-instead-j4n) |
| Goal gradient : efficace si distance < ~7 étapes (Nunes & Drèze 2006) | Nunes & Drèze, « The Endowed Progress Effect », Journal of Consumer Research, 2006 |
| Dota Underlords : ranking mixte = fragmentation de valeur (postmortem) | `docs/roadmap-lab/competitive/postmortems.md §3.2A` |
| Bazaar matchmaking : matching par jour, ghost remplace celui battu | `competitive/the-bazaar.md §1` (sourcé bazaar-builds.net) |
| Bazaar : pool global cross-joueurs depuis patch 6.0 | [bazaar-builds.net/patch-6-0-0](https://bazaar-builds.net/patch-6-0-0-reduced-power-level-of-stelle-scaling-items-more/) |
| Leaderboard roguelike : fixed variable nécessaire | [dev.to/yurukusa/5-lines-of-code-that-made-my-roguelike-worth-playing-every-day-3klj](https://dev.to/yurukusa/5-lines-of-code-that-made-my-roguelike-worth-playing-every-day-3klj) |

**Sources rounds 1-4 conservées** : seganerds.com 2026 (incertitude résoluble) ; immortalboost.com
(TFT LP pré-run) ; boosteria.org (TFT tier Emerald) ; Nunes & Drèze 2006 (goal gradient) ; Clark
2009 (near-miss) ; screenrant.com Bazaar S2 sans pénalité ; steamcommunity 1617400 (Bazaar Legend
perte/gain) ; egamersworld.com LoL ranked rewards 2025 ; guul.games gamification badges.

---

## 8. Nouvelles décisions proposées pour intégration dans la roadmap

| Décision | Section roadmap | Priorité |
|---|---|---|
| **Pool ranked séparé du pool unranked** (`mode` dans struct snapshot) | §5 (snapshot) + §6.4 | P2 (ranked v1, précondition) |
| **`RANKED_MIN_POOL = 5` [PH]** : ranked indisponible si pool insuffisant | §6.4 + §6.11 | P2 (ranked v1) |
| **Fallback ranked cold-start explicite** : résultat non compté si IA faute de pool | §6.4 | P2 |
| **Condition de fairness Daily** : famille imposée ssi `win_rate ≥ 0.8 × médiane` | §6.6 | après P0.5 (dépend de sim) |
| **Signal pré-run en deux niveaux** : sub-tier primaire / tier secondaire | §6.11 | P2 |
| **`snapshot_schema_version` (`sv`)** : découple schéma de version patch | §5 (snapshot) | P0.5 (avant le champ `dot_family`) |
| **Critère Contrainte de Saison** : famille avec le plus bas win_rate ou plus sous-représentée | §8.0 | P4-light (spec avant l'impl) |
| **Contrainte Daily familles ≠ avant équilibrage** : axe sigil/éco uniquement si famille non calibrée | §6.6 | Spec P2 |
| **Timezone Daily** : date locale acceptable en v1, UTC au backend P4 | §6.6 (note) | Documentation |
| **Test pool ranked séparé** : `serve("ranked")` ≠ retourne jamais snapshot unranked | tests (zone sans test) | P2 |
| **Test snapshot `sv=1` et `sv=2`** : round-trip + `toComp` cohérent | tests (zone sans test) | P0.5 |
| **Litige #T** : seuil `RANKED_MIN_POOL` = 3 (bêta fermée) vs 5 (early access) | open | À trancher selon taille bêta |
| **Litige #U** : critère Contrainte de Saison = win_rate bas vs sous-représentation boutique | open | P4-light spec |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 5/10.*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés : toutes les propositions sont RENDER/IO/data hors SIM.*
*Zones sans test nouvelles signalées : P1 (`serve("ranked")` ≠ unranked ; pool ranked séparé) ;*
*P3 (round-trip snapshot `sv=1` + `sv=2` cohérent) ; P2 (contrainte daily = condition win_rate).*
*Sources web vérifiées : bazaar-builds.net, dev.to/yurukusa (2026), Nunes & Drèze 2006.*
