# Round 03 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 3/10 — challenge du brouillon v3 (`ROADMAP-draft.md`) et des synthèses
> rounds 1-2 (`round-01.md`, `round-02.md`). Approfondissement adversarial sur les décisions
> actées et les litiges ouverts sur cette lentille.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` v3, `00-state.md`, `round-01.md`, `round-02.md`,
> `rounds/r01-synergies-effects.md`, `rounds/r02-synergies-effects.md`, `src/effects/ops.lua`
> (lignes 180-201 : op shock), `src/combat/arena.lua` (lignes 330-390 : dischargeShock),
> `docs/research/effects-synergy-tiers.md`, `docs/research/effects-balance-counterplay.md`.
>
> **Recherche web menée** : PoE Shock mechanics (poewiki.net/wiki/Shock) ; autobattler synergy
> threshold design ; TFT trait design (teamfighttactics.leagueoflegends.com).
>
> **Garde-fous respectés** : lecture seule du repo + web ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers async/déterministe/grimdark/procédural respectés. Ne modifie ni
> le code, ni les tests.

---

## 0. Position de départ et angle d'attaque

Les rounds 1-2 ont réglé les trois erreurs factuelles majeures sur la lentille
synergies-effects (`type` déjà pris, ladder choc existant, `dot_family` absent). La roadmap
v3 a intégré ces corrections. Ce round s'attaque aux **décisions qui semblent résolues mais
qui sont encore fragiles ou mal étayées mécanistement** :

1. **L'axe C du choc (amplificateur)** : adopté comme « litige fort #G » — mais le cas PoE
   est UNE MAUVAISE ANALOGIE pour nos contraintes. Le détail compte.
2. **Compteur global vs adjacence-type (litige #D)** : le critère opérationnel proposé est
   trop favorable au global — et laisse de côté la question plus profonde.
3. **Les twists de palier 4** : le garde-fou « ≠ sous-cas d'un T3 » est INSUFFISANT — le
   vrai danger est un twist qui VIDE la niche de son T2.
4. **La hiérarchie poison > choc** : le diagnostic est juste, le traitement proposé (axe +
   ladder) manque la vraie cause racine — qui est structurelle, pas paramétrique.
5. **Les boucliers périodiques** : le round 2 les reporte en P3. C'est trop tard étant donné
   leur interaction avec l'axe choc ampli (litige #G + bouclier = interaction non testée).

---

## 1. ACCORDS — ce qui tient avec le pourquoi ancré dans NOS contraintes

### 1.1 `dot_family` comme champ dédié, orthogonal à `type` et `family` — ACCORD FORT

La décision P0.5 d'ajouter `dot_family` comme champ de premier niveau (`nil` pour les non-DoT)
est correcte et la seule option saine. J'avais lu le code : `stormcaller` a `type="arcane"` tout
comme `witch` (poison). Un compteur qui lirait `type` pour distinguer les archétypes DoT serait
aveugle à la sémantique réelle.

**Pourquoi ça tient dans NOS contraintes :**

- **Déterminisme** : `dot_family` est un champ statique de la data, lu une fois au build. Zéro
  RNG, compatible invariant #1.
- **Async** : le snapshot capture déjà `{id, level, col, row}` par unité. `dot_family` est
  inféré de `id` (la data est statique), donc le snapshot n'a pas à changer. `toComp` reste
  pur.
- **Règle multi-famille** : `dot_family = op du 1er effet DoT non-aura` est une convention
  stable. `wither_bloom` → rot (rot+bleed+poison, le rot est le DoT principal). C'est
  documentable en ~20 lignes dans l'audit P0.5. Un compteur de palier lit `unit.dot_family`
  (une valeur scalaire), pas `effects[i].op` (un tableau d'ops), ce qui évite les faux-positifs.

**Nuance valide mais non bloquante** : la règle multi-famille crée un cas-limite pour les
futures unités conçues APRÈS P1 — un designer pourrait oublier de renseigner `dot_family`, ou
le renseigner « wrong » (ex. `galvanizer` a `bonus_first+shock` : son `dot_family` devrait être
`choc` même si `bonus_first` n'est pas un DoT). → Solution : **règle automatique de lint dans
`tools/check.sh`** : « toute unité avec un op DoT dans ses effets DOIT avoir `dot_family`
non-nil ». Coût ~5 lignes de luacheck. **Proposé en P0.5 comme garde-fou.**

### 1.2 Cap ×3 (`DOT_CAP_MULT=3`) comme borne anti-snowball — ACCORD PARTIEL + NUANCE CRITIQUE

Le cap ×3 est architecturalement sain (stacking additif `increased`, cap dur en absolu).
La recherche PoE confirme l'approche bucket : les `increased` s'additionnent dans un même
pool, le `more` (multiplicatif) reste rare (poewiki.net/wiki/Damage). La même source confirme
que les amplificateurs s'additionnent entre eux (Shock + Wither sur la même cible = `increased
damage taken` additif, source : poewiki.net/wiki/Shock).

**La nuance non formulée dans le brouillon** : le cap ×3 (`DOT_CAP_MULT=3`) est un cap sur le
*résultat final du tick*, pas un cap sur l'accumulation des stacks. L'ordre est :

1. Stacks/intensité s'accumulent librement (poison jusqu'à 8 stacks, bleed dps jusqu'à cap=12).
2. `Stats.resolve(base, mods)` applique `(base + flat)(1+inc)*(1+more)`.
3. `DOT_CAP_MULT` est le plafond sur l'output.

Ce qui n'est **pas borné** : le *nombre de sources* qui alimentent le pool `increased`. Si le
palier de type (P1) ajoute `+20% increased burn` ET qu'une relique B ajoute `+30%` ET qu'une
aura d'adjacence ajoute `+15%`, la somme est `+65% increased` → output = `base × 1.65`. Si
`base = cap/1.65 = 14.5`, le résultat est `24` — au-dessus du cap `DOT_CAP_MULT × base = 3×base`.
**Le cap n'est pas appliqué sur le `increased` total, mais sur l'output.** Cela signifie que
le cap est bien anti-snowball (il empêche l'output d'être absurde), mais la *valeur de base* de
l'unité détermine si le cap entre en jeu.

**Impact sur les twists de palier 4 (litige #B)** : si le twist n'est PAS dans `increased` mais
dans `more` (une règle modifiée qui change l'axe de l'effet), il échappe AU CAP. C'est la raison
pour laquelle le brouillon v3 §5.2 note que « la nature stats du twist n'est pas spécifiée ».
→ **Critique actée : le twist de palier 4 DOIT être spécifié comme `more` ET borné séparément,
ou comme une règle qui ne passe PAS par `Stats.resolve`.** Sinon le cap ×3 ne protège pas.

### 1.3 Auras build-résolues vs propagation combat — ACCORD FORT, nuance sur les boucliers

La séparation architecturale est correcte et survit aux contraintes async (aura baked = stat sur
l'unité, capturée dans le build ; propagation combat = SIM autonome). Accord complet avec le
round 2 sur ce point.

**Exception boucliers périodiques (voir §2.4)** : les boucliers périodiques (`shield_caster`)
ne sont PAS des auras — ils reposent sur un trigger combat. Ce sous-type a une interaction
non couverte par la décision d'archi aura vs propagation. Ce n'est pas un problème d'archi
(la décision reste bonne) mais un problème de **test de couverture**.

### 1.4 Seuils 2/4 (pas 2/4/6) — ACCORD avec une précision sur le POURQUOI réel

Le brouillon justifie les seuils 2/4 par la taille du plateau (9 slots < 28 hexagones TFT).
C'est exact mais sous-spécifié. La vraie raison mécaniste est **l'optimum de diversité sous
contrainte de slot** :

Avec 5 familles DoT, 9 slots max et un palier à 4 : un joueur peut activer 2 paliers à 4
(8 unités) et garder 1 slot pour un enabler transversal (tank/tank-or-bouclier). Si le palier
était à 6, activer 2 familles coûterait 12 slots > 9 → **impossible** : le seuil 6 force à
ne jouer qu'une famille → zéro tension de composition. Le seuil 4 **force un optimum réel** :
le joueur choisit entre 1 famille à palier 4 (4 slots alloués à la famille + 5 divers) ou 2
familles à palier 2 (2+2+5 divers). Ce choix est la **décision de build centrale** de P1.

**Source** : gangles.ca/2024/07/07/balatro-auto-chess/ — « a player who commits to one trait
sacrifices defensive diversity ». TFT Set 17 (mobalytics.gg/tft/synergies/origins) confirme
que les traits à seuil 2/4 restent dominants parce qu'ils permettent des « flex builds » (deux
traits activés simultanément).

---

## 2. DESACCORDS — ce qui est faible, faux, ou non étayé par la mécanique profonde

### 2.1 DESACCORD FORT : L'axe C du choc (amplificateur PoE) est une MAUVAISE ANALOGIE — et ça change tout

Le brouillon v3 (§3.3, litige #G) présente l'axe C comme la solution naturelle au choc, calquée
sur PoE Shock = « Non-Damaging Ailment ». La synthèse round 2 (§2.1) adopte l'analogie PoE
comme fondement de l'axe C. **Cette analogie tient en surface mais échoue au niveau mécaniste
profond — et les conséquences pour The Pit sont exactement inverses de ce que le brouillon croit.**

**Ce que PoE Shock fait RÉELLEMENT (source : poewiki.net/wiki/Shock, vérifié)** :

- Shock = ailment NON-endommagant posé par un hit de lightning.
- Effet : la cible prend +N% de dégâts accrus de **toutes sources** (`increased damage taken`
  additif avec les autres modificateurs de `damage taken` comme Wither).
- **Cap par instance : 50% par défaut** (modifiable via "increased Effect of Shock").
- **Ne stacke PAS en intensité** : plusieurs shocks sur la même cible, seul le plus fort
  s'applique. Le stacking est en DURÉE, pas en puissance.
- La valeur N est déterminée par la magnitude du hit ayant causé le shock (plus le hit est
  gros, plus le shock est fort, jusqu'à 50%).

**Pourquoi l'analogie échoue pour The Pit :**

1. **PoE Shock ne stacke pas** — notre choc stacke jusqu'à 8 (`SHOCK_STACK_CAP=8`). Si on
   adopte l'axe C « +N% par stack », on crée un amplificateur **qui s'accumule**, ce que PoE
   évite délibérément. L'amplificateur PoE est une valeur unique par source (le hit le plus
   fort). Notre version serait fondamentalement différente.

2. **PoE Shock s'applique à TOUT dégât reçu, simultanément** — dans nos cooldowns fixes, la
   décharge devrait s'appliquer à la **prochaine source de dégât** (frappe OU tick DoT). Mais
   « prochaine source » dans un système à cooldowns est une notion temporellement ordonnée et
   deterministe, donc cela revient à un amplificateur *par hit* — pas *par tour*. Le résultat :
   l'amplificateur bénéficie à la **première source qui frappe après la pose**, pas à toutes
   les sources. C'est un amplificateur **à usage unique par décharge**, pas une aura
   d'amplification permanente comme PoE.

3. **Le problème de « qui profite »** : dans PoE, Shock profite à **tous** les hits du joueur
   simultanément. Dans The Pit (ciblage déterministe, une unité cible à la fois), si le choc
   amplifie « la prochaine frappe reçue », cela amplifie **UNE SEULE frappe** de **UNE SEULE
   unité** (la prochaine à attaquer cette cible dans l'ordre de cooldowns). Ce n'est pas un
   amplificateur d'équipe — c'est un **power boost conditionnel sur le timing de frappe**.

**Ce que l'axe C crée vraiment dans notre moteur** :

- Un stack de choc = promesse que le prochain hit sur cette cible fait +N%.
- La valeur de l'amplificateur = `stacks × N%`.
- **Interaction critique avec `dischargeShock`** : le code actuel (arena.lua:342-390) fait
  `burst = stacks × volt` = dégâts propres, puis consomme les stacks. L'axe C remplacerait le
  burst par un multiplicateur appliqué au hit *déclencheur* de la décharge. Mais le hit est
  déjà calculé et appliqué AVANT `dischargeShock` (`arena.lua:330` → `hit()` → `dischargeShock()`).
  **La séquence actuelle ne permet pas à la décharge d'amplifier le hit qui l'a déclenchée** —
  elle se produit APRÈS. Il faudrait réordonner : d'abord calculer si la cible est choquée,
  amplifier le hit, PUIS consommer les stacks. Ce n'est pas une réécriture mineure de
  `dischargeShock` — c'est un **changement de l'ordre d'appel dans `hit()`**.

**Conséquence pour la roadmap** : l'axe C est présenté comme « réécrit `dischargeShock`,
rebaseline golden ». C'est sous-estimé. Le changement touche aussi `hit()` et l'ordre des
phases de combat, ce qui affecte les 12 invariants de synergie (#22-32) dont plusieurs
dépendent de l'ordre `on_attack → damage → on_hit → on_attacked → dischargeShock`. La note
dans le brouillon (§3.3) dit « +5 lignes dans un point isolé » — ce n'est pas exact au vu du
code lu.

**Ma proposition alternative : un AXE D (décharge différée sur le tick suivant)**

Plutôt que d'amplifier le hit déclencheur (problème d'ordre), la décharge amplifie le
**prochain tick de DoT sur la cible**. Séquence : choc posé → tick DoT suivant sur cette cible
→ avant de calculer ce tick, vérifier si la cible est choquée → si oui, appliquer un `more`
multiplicatif au tick ET consommer les stacks. Avantages :

- La décharge est dans `tickDots` (arena.lua:392+), APRÈS le cycle frappe → donc zéro conflit
  d'ordre avec `hit()`.
- Crée une VRAIE synergie choc × DoT (le choc amplifie le **premier tick** de tout DoT sur la
  cible, puis se consomme) → identité lisible : « charger la cible, puis le poison explose ».
- Le stacking (8 stacks max) détermine l'amplitude de l'amplification → `more = 1 + stacks×N`.
- Déterministe : l'ordre des ticks est fixe (`burn→bleed→poison→rot→choc→regen`), le premier
  tick non-choc sur une cible choquée est toujours burn si burn est présent, sinon bleed, etc.
- Golden : change le comportement choc → rebaseline golden explicite.

Source du précédent mécanique : Slay the Spire, « Vulnerable » (slaythespire.wiki.gg/wiki/Vulnerable)
= le debuff qui amplifie la PROCHAINE attaque reçue, pas toutes — notre axe D est structurellement
identique mais sur les DoT ticks plutôt que les frappes.

**Ce désaccord est FORT** : adopter l'axe C tel que formulé sans résoudre le problème d'ordre
dans `hit()` crée une dette cachée. L'axe D mérite d'être ajouté à la matrice de décision du
litige #G.

### 2.2 DESACCORD MODÉRÉ : Le critère opérationnel du litige #D (global vs adjacence-type) est biaisé vers le global — et ignore la question de VALEUR marginale

Le brouillon v3 (§5.2, litige #D) propose comme critère : « sim — si `stddev(position des
unités du type) > 2.0` ET win% > 0.55 pour compos à palier activé → adjacence-type justifiée.
Sinon global. Défaut global v0.10 ».

**Problème 1 : Le critère mesure la CORRÉLATION, pas la CAUSALITÉ**

Un `stddev > 2.0` sur la position des unités du même type ET un win% élevé signifie que les
joueurs gagnent EN ÉPARPILLANT leurs unités du même type. Cela ne prouve pas que l'adjacence-type
serait mieux — cela prouve que le compteur global permet de **disperser les unités et quand même
activer le palier**. Ce n'est pas un échec du global, c'est son fonctionnement prévu. Le critère
conclut « l'adjacence-type est justifiée » quand il devrait conclure « le global fonctionne avec
de la diversité positionnelle ».

**Problème 2 : La vraie question n'est pas posée**

La vraie question pour le litige #D est : **le compteur global crée-t-il une décision de
placement ?** Non par définition — il récompense la COMPOSITION (nombre d'unités du type) sans
contraindre le placement. L'adjacence-type crée une décision orthogonale : « où je place ces
unités » en plus de « combien ». Ce sont deux couches de décision différentes.

Le risque du brouillon : adopter le global par défaut puis « basculer vers l'adjacence si la sim
montre X » revient à **laisser de côté une couche de profondeur** pendant une version entière
(v0.10 → v0.12) sans mesurer si cette profondeur aurait été appréciée.

**Ce que le round 1 avait raison de proposer (§2.4)** : les synergies d'adjacence et les
synergies de type ont des couches de décision DIFFÉRENTES. The Pit a un plateau-graphe 3×3 avec
des arêtes explicites — c'est sa **signature**. Laisser le compteur de type entièrement séparé
de l'adjacence est une occasion manquée de faire résonner les deux systèmes.

**Ma proposition d'un critère alternatif (opérationnel, mesurable)** :

Mesurer en sim (seed `20260623`, N=200 par config) :

| Config | Mesure | Seuil de décision |
|--------|--------|-------------------|
| Compos avec ≥2 unités mêmes type, carré (4 arêtes/slot central) | `% de paliers où les unités sont adjacentes` | < 30 % → joueurs n'utilisent pas l'adjacence → global suffisant |
| Compos avec ≥4 unités mêmes type, sigil diamant (go-wide) | `win% vs compos sans palier` | if delta < 0.05 → le palier 4 ne vaut pas le coût de composition |
| Permutation positionnelle (same units, different positions) | `variance win% sur permutations` | > 0.05 → la position COMPTE → adjacence-type enrichit |

Ce critère mesure si la **position** affecte le win% quand le compteur est activé — c'est la
vraie question. Si elle n'affecte pas, le global est suffisant. Si elle affecte, l'adjacence-type
amplifie la profondeur existante.

**Source** : DIVA-portal auto chess balance (diva-portal.org — recherche sur les synergies et le
placement dans les autobattlers) confirme que la séparation position/composition crée deux axes de
skill distincts. La question est de savoir si on veut les deux.

### 2.3 DESACCORD MODÉRÉ : Le garde-fou anti-clone T3 est INSUFFISANT — il faut aussi interdire le VIDE de niche T2

Le brouillon v3 (§5.2, garde-fou twist) interdit le twist de palier 4 qui est « un sous-cas d'un
T3 existant ». Exemple : burn 4 no-decay = clone d'ash_maw. C'est correct.

**Ce qui manque : le twist qui VIDE la niche de son T2**

Le T2 (TWIST) a une niche précise dans la pyramide T1/T2/T3 : il ajoute **une interaction qui
crée un payoff local** sans changer les règles de base. Si le twist de palier 4 rend le T2
obsolète (en le faisant systématiquement), il vide le design de mid-game.

Exemples concrets à vérifier dans le roster :

- `poison 4 = weaken affecte la cadence` (proposé §5.2) — `chitin_drone` (T2 poison, vague 2)
  fait déjà `on_attack: poison + slow` (bleed slow). Si le palier 4 poison donne un slow
  systématique, `chitin_drone` perd son identité « l'enabler qui slow aussi ».
- `bleed 4 = aggravate renforcé` (round 1 P1-B §3) — `razor_fiend` (T2 bleed aggravate,
  `effects-dot-families.md §H`) est déjà l'unité d'aggravate. Un palier 4 qui aggravate
  l'équipe entière rend `razor_fiend` redondant.

**La règle à ajouter** : un twist de palier 4 ne doit PAS reproduire le mécanisme clé d'un T2
de la même famille. La vérification = ligne par ligne de l'audit P0.5 (`dot_family` + niche T2).

**Source** : effects-synergy-tiers.md §3.1 — pièges T2 : « 2 finishers même famille → meta
résolue ». Par extension : un palier global qui finisher avant le T2 = meta résolue avant d'avoir
les T2.

### 2.4 DESACCORD MODÉRÉ-FORT : Boucliers périodiques en P3 = TROP TARD au vu de l'interaction avec l'axe choc ampli

Le round 2 (§2.6) a rétrogradé les boucliers périodiques en P3 (drapeau `timing-shield`). La
justification : « observation juste, mais pas un blocage de P1 ». Le brouillon v3 (§7.1, drapeaux)
liste « timing-shield (métrique de sim) » comme drapeau P3.

**Pourquoi c'est problématique si l'axe C ou D du choc est retenu :**

Le choc dans l'axe C/D amplifie les dégâts reçus par la cible. Si la cible est un
`barrier_savant` (bouclier périodique toutes les 4 s), l'amplification du choc est absorbée par
le bouclier. L'interaction choc + bouclier périodique devient : « l'amplification est inutile si
elle arrive pendant une fenêtre de bouclier ». Cela crée un counter **implicite** (pas conçu, pas
testé) du choc amplificateur par les builds boucliers périodiques.

Ce n'est pas nécessairement mauvais — un counter naturel est bienvenu. Mais si c'est découvert en
P3 (après implémentation de l'axe choc en P0.5 et des types en P1), il sera difficile de savoir
si la faiblesse relative du choc (s'il reste faible en ranked) vient de l'axe ou du counter
implicite bouclier.

**Proposition** : intégrer la mesure `timing-shield` dans la sim des **3 configs choc P0.5** (§3.3
de la roadmap v3). C'est le même test étendu d'une config :

- **Config D (NOUVEAU)** : choc pur (axe C ou D) vs compo `ward_weaver × 3` (bouclier
  périodique maximum), sigil carré, N=50 → si win% choc < moyenne - 1σ → le bouclier périodique
  est un counter implicite → décider si c'est voulu.

Coût : ~0 (même harness que les 3 configs existantes). Évite une dette d'équilibrage.

### 2.5 DÉSACCORD FAIBLE MAIS STRUCTUREL : La hiérarchie poison > choc est un symptôme, pas la cause

Le brouillon (§3.1, §7.1) diagnostique la hiérarchie `poison > tank > … > choc` et propose
comme levier : axe choc + ladder des 10 unités existantes + sim. C'est la bonne direction, mais
le traitement est **paramétrique** (tuner les valeurs) là où la cause est **structurelle**.

**La vraie cause racine** (que ni le round 1 ni le round 2 n'ont nommée explicitement) :

Le poison est la famille la plus forte parce qu'il a trois axes de stacking orthogonaux qui
se renforcent mutuellement sans interaction de l'adversaire :
1. **Stacks** (jusqu'à 8, chacun à dps indépendant).
2. **Weaken** (malus sur la valeur des capacités → réduit les soins, les boucliers, etc.).
3. **Propagation à la mort** (contagion + mort → pool d'intérêt composé).

Ces trois axes font du poison un archétype **auto-suffisant** : il se déploie (T1), se multiplie
(T2 contagion), et s'autonomise (T3 propagation mort). Aucune autre famille n'a ces trois axes.

Le choc, même avec l'axe C/D, n'en a que deux :
1. **Condensateur** (stacks).
2. **Amplification** (du hit/tick suivant).

Et ces deux axes sont **séquentiels, pas orthogonaux** : l'amplification ne se produit que si
le condensateur s'est chargé ET qu'un hit/tick suit. Le poison agit même si personne ne le
touche.

**Conséquence** : la hiérarchie ne se réglera pas uniquement par l'axe et les paramètres. Il
faut soit (a) réduire la puissance des axes orthogonaux du poison (toucher à la propagation ou
au weaken) — risqué car change des invariants existants — soit (b) donner au choc un axe
qui ne dépend pas du comportement d'une autre unité. L'axe D (amplification du tick DoT)
est plus proche de (b) que l'axe C (amplifie le hit déclencheur = dépend d'une frappe).

**Recommandation chiffrée** : avant de tuner les paramètres du choc, mesurer **le taux de
victoire du poison en run par rapport à l'archétype moyen**. S'il dépasse `win_rate_moyen + 1σ`
de façon persistante après les correctifs choc, le poison est sur-puissant structurellement, pas
le choc sous-puissant. Levier : réduire les stacks de propagation (de 100% des stacks du mort à
50%) dans l'op `contagion`. Coût : 1 paramètre data, sim avant commit.

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Ajouter l'axe D à la matrice de décision du litige #G [HAUTE PRIORITÉ, P0.5]

**Quoi** : le litige #G dans le brouillon v3 propose A/B/C. Ajouter **l'axe D : décharge sur le
premier tick DoT de la cible** comme 4e candidat à la matrice sim des 3 configs (qui devient 4
configs). L'axe D résout le problème d'ordre dans `hit()` (§2.1) que l'axe C ignore.

**Spec minimale de l'axe D** :
- Dans `tickDots` (arena.lua:392+), avant de calculer le tick d'une famille sur une cible `u`,
  vérifier si `u.dots.shock` existe ET `u.dots.shock.stacks > 0`.
- Si oui, appliquer un `more` multiplicatif au tick calculé : `tick_amplifié = tick × (1 + stacks × N)`.
- Consommer les stacks (`u.dots.shock = nil`).
- Émettre un événement bus `shock_amplify` avec source, magnitude, famille amplifiée.
- `N` = à chiffrer en sim [PH, suggéré 0.05 → palier 8 stacks = +40% max — cap humain lisible].

**Avantage déterminisme** : `tickDots` est l'endroit où les effects DoT sont déjà calculés dans
un ordre FIXE (burn→bleed→poison→rot). La décharge amplifie donc toujours la **première famille
présente** dans l'ordre fixe, ce qui est prédictible par le joueur (« si j'ai du burn ET du choc,
le premier tick de burn est amplifié »).

**Test requis** : ajouter à la matrice 3 configs choc (§3.3 roadmap v3) une **Config D** : choc
pur (axe D), puis burn T1, sigil carré, N=50. Mesurer win% + tick amplifié moyen. Rebaseline
golden après décision (comme pour l'axe C).

**Chiffre de calibrage cible** : win% choc dans [0.45, 0.55] sur la config optimale (gravewarden
+ 3 choc col3 + burn enabler, sigil ligne). Ajuster `N` jusqu'à convergence.

### P2 — Ajouter la règle « le twist de palier 4 ne vide pas la niche de son T2 » à l'audit P0.5 [HAUTE PRIORITÉ, P0.5/P1]

**Quoi** : dans l'audit d'identité P0.5 (§3.1 roadmap v3), ajouter une **colonne E** à la grille
à 4 colonnes : **(E) conflit twist-T2** = « si le palier 4 de ce type implémente le mécanisme
clé de ce T2, signaler NICHE VIDÉE ». Vérifier pour les 5 familles × T2 existants avant de
figer les twists.

**Exemples à vérifier** :
- `poison 4 = slow cadence` vs T2 poison qui slow déjà → NICHE VIDÉE si le T2 est uniquement
  connu pour ce slow.
- `bleed 4 = aggravate renforcé équipe` vs T2 bleed aggravate → NICHE VIDÉE.
- `rot 4 = amputation HP final` vs T2 rot qui s'approche déjà de l'amputation → OK si le
  timing est distinct.

Coût : ~10 lignes de plus dans l'audit P0.5. Zéro code moteur.

### P3 — Config D (choc vs bouclier périodique) dans la sim P0.5 [PRIORITÉ MOYENNE, P0.5]

**Quoi** : ajouter la Config D (§2.4) à la matrice sim choc : `ward_weaver × 3` vs choc pur
(axe D), N=50. Décider si le bouclier périodique est un counter voulu ou accidentel du choc.
Si counter voulu → documenter dans l'audit (« bouclier = hard counter du choc = décision
de build »). Si accidentel → ajuster le timing de recharge du bouclier.

Coût : ~0 (même harness sim). Évite un drapeau P3 de timing-shield qui arriverait après
l'implémentation.

### P4 — Mesurer l'entropie relative de famille (poison vs pool moyen) AVANT de tuner [PRIORITÉ MOYENNE, P3 remonté en précondition]

**Quoi** : avant de tuner le choc, lancer la sim N=400 en isolant le win_rate de chaque famille
vs le pool moyen. Si `win_rate(poison) > win_rate_pool + 1σ`, le problème est le poison, pas le
choc. Levier : paramètre de propagation (`contagion = 50% des stacks du mort`, pas 100%).

**Critère de décision** : si le delta σ poison vs pool se réduit à < 0.5σ après le correctif
propagation → l'équilibre inter-famille est atteint. Sinon → chercher le 2e levier.

Coût : `tools/sim.lua` existant + 1 paramètre data. **À mesurer AVANT tout autre tuning de
familles en P3** (sinon on tune dans l'aveugle).

---

## 4. QUESTIONS OUVERTES (non résolues par ce round)

### Q1 : L'axe D (décharge sur tick DoT) — quelle famille est amplifiée si plusieurs DoT sont actifs simultanément ?

Avec l'ordre tick `burn→bleed→poison→rot`, la décharge amplifie toujours la première famille
présente. C'est prédictible mais crée une **hiérarchie implicite** : une cible avec burn + choc
est plus facile à exploiter qu'une cible avec rot + choc (burn tick arrive en 1er). Est-ce voulu
(le placement des unités burn en front avant les unités rot pour profiter du choc amplifié) ou
est-ce une asymétrie non intentionnelle ?

### Q2 : Le twist de palier 4 choc — si l'axe retenu est D (DoT), quel twist est orthogonal à l'identité amplificateur ?

Si choc = amplificateur DoT (axe D), le palier 4 choc = « 2 choc suffisent pour activer
l'amplification ET l'amplification touche 2 ticks consécutifs (pas seulement 1) ». Mais cela
change la nature du palier : c'est une règle sur la **durée** de l'amplification. À vérifier
que ce n'est pas un clone de `storm_anchor` (persist = fraction des stacks conservés).

### Q3 : Quid des boucliers périodiques comme archétype à part entière ?

Le round 2 (§2.6) les identifie comme un archétype sans relique (P(aucune relique shield sur run)
non calculé). Si le choc amplifie les ticks DoT qui ignorent les boucliers (bleed, poison, rot
ignorent les boucliers — 00-state.md §3.1), le choc + DoT BYPASS les boucliers périodiques. Cela
signifie que l'argument « bouclier périodique counter le choc » (§2.4) ne tient que pour le choc
axe A/B (burst qui est bloqué par un bouclier — vérifier : `ignoreShield = true` dans
`dischargeShock` arena.lua:349 → le burst actuel IGNORE le bouclier). En axe C/D, la question
est différente : l'amplification du DoT ignore le bouclier (les DoT l'ignorent déjà). Le counter
bouclier du choc **dépend de l'axe retenu**.

### Q4 : Poison — la propagation à 100% des stacks est-elle une décision intentionnelle ou un placeholder ?

Le round 1 §2.5 mentionne la contre-synergie de type potentielle. La propagation du poison à la
mort transmet 100% des stacks au voisin. Dans `ops.lua` (contagion, op `spread_on_death`),
est-ce un paramètre `p.frac` ou une valeur fixée ? Si c'est une constante, c'est un levier
d'équilibrage sous-exploité (réduire à `p.frac = 0.5` = 50% des stacks propagés = réduction
immédiate de la puissance de la famille sans toucher à son axe).

---

## 5. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée | Round |
|----------|----------|----------------|--------------------|-------|
| Axe C choc : problème d'ordre dans `hit()` non nommé ; analogie PoE inexacte sur le stacking | **FORTE** | Litige #G mal posé si axe C seul | Ajouter axe D à la matrice, sim 4 configs | P0.5 |
| Critère litige #D biaisé vers global — mesure corrélation, pas causalité | **MODÉRÉE** | Profondeur adjacence ignorée 1 version | Remplacer par critère variance positionnelle | P1 |
| Garde-fou twist insuffisant : interdit clone T3, pas vide de niche T2 | **MODÉRÉE** | Twists vidant les T2 = mid-game aplati | Ajouter colonne E à l'audit P0.5 | P0.5 |
| Boucliers périodiques en P3 trop tard : interaction non testée avec choc ampli | **MODÉRÉE** | Dette d'équilibrage post-P0.5 | Config D dans sim choc | P0.5 |
| Hiérarchie poison > choc = cause structurelle (axes orthogonaux), pas paramétrique | **MODÉRÉE** | Tuning choc sans régler le poison = illusion | Mesurer δσ poison avant tout tuning | P3 précondition |
| Cap ×3 ne protège pas si le twist est `more` hors-cap | **FAIBLE mais précis** | Combo 4-type + twist + relique potentiellement hors-cap | Spécifier la nature du twist avant P1 | P0.5 doc |

---

## Index des sources

**Sources web vérifiées ce round :**

- PoE Shock — Non-Damaging Ailment, cap 50%, additive avec Wither, no-stack en intensité :
  [poewiki.net/wiki/Shock](https://www.poewiki.net/wiki/Shock)
- PoE2 Shock — mécanique amplificateur, `increased damage taken` :
  [mobalytics.gg/poe-2/guides/shock](https://mobalytics.gg/poe-2/guides/shock)
- PoE2 Damage-taken additive stacking :
  [mobalytics.gg/poe-2/guides/damage-defence-calc-order](https://mobalytics.gg/poe-2/guides/damage-defence-calc-order)
- TFT Set 17 traits (seuils 2/4 dominants, flex builds) :
  [mobalytics.gg/tft/synergies/origins](https://mobalytics.gg/tft/synergies/origins)
- Balatro & auto-chess (diversité défensive, seuils de synergies) :
  [gangles.ca/2024/07/07/balatro-auto-chess](https://gangles.ca/2024/07/07/balatro-auto-chess/)
- StS Vulnerable (amplificateur séquentiel sur prochaine attaque) :
  [slaythespire.wiki.gg/wiki/Vulnerable](https://slaythespire.wiki.gg/wiki/Vulnerable)
- DIVA-portal auto chess balance (séparation position/composition) :
  [diva-portal.org/smash/get/diva2:1980319/FULLTEXT02.pdf](https://www.diva-portal.org/smash/get/diva2:1980319/FULLTEXT02.pdf)

**Sources internes (code lu ce round) :**

- `src/effects/ops.lua:180-201` — op `shock` : 0 dégâts à la pose, stocke `stacks/volt/remaining`
  sur `v.dots.shock`, modificateurs rares (transfer/chain/persist).
- `src/combat/arena.lua:330-390` — `hit()` : ordre exact `damage → on_hit → on_attacked →
  dischargeShock` ; `dischargeShock` : `burst = stacks × volt`, `ignoreShield = true`,
  consommation totale (ou `persist` = fraction). **Prouve que l'axe C ne peut pas amplifier
  le hit déclencheur sans réordonner `hit()`.**
- `docs/research/effects-synergy-tiers.md §3.1` — pièges T2 (clone finisher, duplication
  mécanique).
- `docs/research/effects-balance-counterplay.md §1.4` — PoE Vulnerable = stack en durée, cap dur.
- `docs/roadmap-lab/00-state.md §3.1` — ordre tick burn→bleed→poison→rot→choc→regen.

---

*Round 03 rédigé le 2026-06-23. Lecture seule du repo (code cité avec lignes). N'édite que sous
`docs/roadmap-lab/`. Piliers respectés. 32 invariants préservés (toute modif choc impliquerait
un rebaseline golden explicite — non silencieux, signalé §P1). Litiges enrichis : #G (axe D
ajouté), #D (critère alternatif), #B (nature du twist hors-cap). Nouveaux garde-fous : vide de
niche T2, Config D boucliers × choc, précondition mesure δσ poison.*
