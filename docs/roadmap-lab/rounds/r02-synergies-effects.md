# Round 02 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 2/10 — challenger les décisions du brouillon v2 (`ROADMAP-draft.md`)
> et de la synthèse round 1 (`round-01.md`), en m'appuyant sur le code réel (`units.lua`
> lu en entier, `ops.lua`, `arena.lua`) et sur la recherche web sourcée.
>
> **Inputs** : `BRIEF.md`, `ROADMAP-draft.md` v2, `00-state.md`, `round-01.md`,
> `rounds/r01-synergies-effects.md` (round 1 de la même lentille), `docs/research/
> effects-synergy-tiers.md`, `effects-balance-counterplay.md`, `src/data/units.lua`,
> `src/effects/ops.lua`, `src/combat/arena.lua` (lignes 1-120). Sources web vérifiées.
>
> **Garde-fous respectés** : lecture seule du repo ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers respectés. Ne modifie ni le code, ni les tests.

---

## 0. Position de départ

Le round 1 a produit des avancées majeures sur le choc (Litige #D reporté, axe à décider
avant le ladder), sur les twists de type (principe « 1 règle, pas un chiffre » adopté), et
a ouvert le Litige #D (compteur global vs adjacence-type). Le brouillon v2 intègre ces
décisions. Ce round 2 attaque **5 points structurels nouveaux** que le brouillon v2 n'a
pas résolus ou qu'il résout mal sur cette lentille, et valide **4 accords forts** avec
justification mécaniste.

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 Le choc comme axe « amplificateur non-DoT » — ACCORD FORT avec une précision CRITIQUE

Le brouillon v2 (§3.2) cadre le choc comme « condensateur carry arrière » (axe A) ou
« mini-dégât à la pose » (axe B). Le round 1 a imposé de trancher AVANT le ladder.

**Pourquoi l'accord tient dans NOS contraintes, et pourquoi ça éclaire les deux axes :**

La recherche PoE2 (mobalytics.gg/poe-2/guides/shock, poewiki.net/wiki/Shock, sportskeeda.com
sur PoE2 ailments) confirme que Shock dans PoE est explicitement une **Non-Damaging Elemental
Ailment** — elle n'inflige pas de dps, elle augmente les dégâts subis (default +20%, max
+50%). C'est fondamentalement différent de Ignite/Bleed/Poison qui sont des
**Damaging Ailments** (source primaire : www.mmopixel.com/news/poe-2-damage-ailments-guide).

**Cette distinction est capitale pour The Pit.** Nos 4 familles DoT (burn/bleed/poison/rot)
font des dégâts autonomes — le choc dans notre code (`ops.lua` lignes 180-200) fait
**0 dégât à la pose, tout à la décharge**. La vraie asymétrie n'est pas la conditionnalité
(être frappé) : c'est que le choc **potentialise les autres dégâts** plutôt que d'en faire
lui-même. Cette identité n'est pas exploitée dans le design actuel.

**Proposition corrective concrète** (voir §3.1) : trancher l'axe choc non pas comme
« condensateur ordinaire » mais comme **amplificateur de combo** — le choc monte les stacks
sur une cible, puis la décharge **amplifie la prochaine source de dégâts** (frappe ou DoT)
plutôt que de faire ses propres dégâts. Cela résout la viabilité en ciblage déterministe
(la décharge bénéficie à n'importe quelle source qui frappe ensuite, même un DoT), colle
au précédent PoE, et différencie le choc des 4 autres familles par son axe « amplificateur »
vs « dégât direct ».

### 1.2 Compteur GLOBAL par défaut (Litige #D) — ACCORD PARTIEL avec nuance

La décision du brouillon v2 (§4.2) : compteur global v0.10, adjacence-type comme évolution
v0.12 si la sim montre du « stack sans pensée positionnelle ».

**Pourquoi l'accord sur le global par défaut tient :**

La recherche sur SAP (a327ex.com/posts/super_auto_pets_mechanics, confirmée) montre que SAP
utilise des triggers POSITIONNELS (« le pet à droite ») et des triggers de TYPE (famille
spécifique) comme deux couches SÉPARÉES — pas un seul compteur d'adjacence-type. Cette
séparation est délibérée : les positionnels (qui buffe qui) créent la tactique de placement,
les types créent la direction de build. Les combiner en un seul compteur d'adjacence-type
crée effectivement le risque d'illisibilité signalé par le round 1.

**Nuance importante non résolue** : la recherche sur TFT Set 1 (teamfighttactics.leagueoflegends.
com/en-us/news/dev/dev-tft-set-1-learnings/) confirme que les traits trop larges
(« Blademaster encompassed too much ») créent des problèmes d'équilibrage, mais TFT utilise
un compteur **global sans adjacence** depuis le Set 1. La décision de lisibilité du brouillon
est donc correcte pour le compteur, mais le **critère de bascule vers l'adjacence-type** (sim
montre « stack sans pensée positionnelle ») est trop vague. Voir §3.4 pour un critère opérationnel.

### 1.3 Auras build-résolues vs propagation combat — ACCORD FORT

Le brouillon v2 et le code (`units.lua` lignes 147-163 : vague 2, auras) confirment la
décision d'archi : auras = build-résolues (graphe du sigil, bakées à `combat_start`) ;
propagation en combat = proximité du champ de bataille (`Arena:neighborsOf`). Cette séparation
tient pour nos contraintes :

- **Async** : une aura baked au build EST dans le snapshot (c'est une stat sur l'unité, pas
  une règle de runtime). La propagation combat RESTE dans la SIM. Les deux restent cohérents
  avec `toComp` (snapshot.lua).
- **Déterminisme** : le graphe d'arêtes du sigil est statique pendant le combat (une fois le
  build figé). Pas de source de RNG. Compatible invariant #1.
- **Ouvert/fermé** : ajouter une aura = +1 op `aura_*` + 1 ligne data. La boucle de combat
  n'est pas touchée.

Source de validation : `effects-synergy-tiers.md` §5.2 — « l'adjacence peut conditionner un
twist, mais pas un T3 câblé sur une case précise ». Les auras de la vague 2 respectent cette
règle (elles posent un modificateur `inc` sur le **voisin**, pas sur la case #4).

### 1.4 Le cap ×3 (`DOT_CAP_MULT=3`) comme borne anti-snowball — ACCORD mais anomalie relevée

Le brouillon v2 confirme que le cap ×3 borne le double-comptage (Litige #B clos partiellement).
Code vérifié : `ops.lua:22` (`DOT_CAP_MULT=3`), `ops.lua:29-31` (formule `Stats.resolve`).

**Accord sur la borne** : les sources d'équilibrage (effects-balance-counterplay.md §1.2,
pathofexile.fandom.com/wiki/Curse sur les caps PoE) confirment que les caps durs sont la vraie
réponse aux amplifications exponentielles. Le cap ×3 couplé à `increased` additif (pas
multiplicatif) = borne saine.

**Anomalie code lue dans `units.lua`** : le champ `type` des unités dans `units.lua` n'est PAS
la famille DoT — c'est un type visuel/thématique (« arcane », « flesh », « bone », « abyss »,
« order »). Exemples : `witch` a `type = "arcane"`, `corruptor` a `type = "abyss"`, mais les
deux posent du poison. `razorkin` a `type = "flesh"` (bleed) mais `skeleton` a aussi `type =
"bone"` (thorns, pas DoT). La famille DoT vit dans l'`op` de l'effet, pas dans `type`. **Le
brouillon v2 (§4.1) suppose que « type d'unité = famille mécanique (burn/bleed/poison/rot/choc) »
mais le code utilise déjà `type` pour autre chose.** Ce conflit est structurel et bloque P1
sans être mentionné nulle part. Voir §2.1 (désaccord fort).

---

## 2. DESACCORDS — ce qui est faible, manquant ou faux, avec recherche sourcée

### 2.1 DESACCORD FORT : Le brouillon ignore que `type` est déjà pris — il faut décider `family` vs `type`

Le brouillon v2 (§4.1) : « type d'unité = famille mécanique (burn/bleed/poison/rot/choc) ».
Code réel (`units.lua` lignes 31-400, lu entier) : le champ `type` dans chaque entrée unité
EST DÉJÀ UN CHAMP VISUEL/THÉMATIQUE, pas un identifiant de famille DoT.

**Preuves tirées du code :**
- `stormcaller` (choc) : `type = "arcane"` — mais `arcane` est aussi le type de `witch`
  (poison), `spore_tick` (poison), `miasma_acolyte` (aura poison), `festering` (T3 poison).
- `razorkin` (bleed) et `marauder` (aucun DoT) partagent `type = "flesh"`.
- `gravewarden` (tank taunt épines, pas de DoT) et `maggot_king` (rot) partagent `type =
  "bone"`.

**Le vrai axe de famille est l'op** : `op = "poison"`, `op = "burn"`, etc. Ce champ existe
dans `effects[i].op` mais n'est pas un champ de premier niveau sur l'unité. **Pour les
synergies de type P1, il faudra soit (a) ajouter un champ `family` explicite sur chaque
unité (`family = "poison"`), soit (b) inférer la famille depuis le premier op de type DoT.**

**Note** : `units.lua` contient déjà un champ `family` sur certaines unités de la vague 7
(lignes 383-400 : `chitin_drone`, `bore_worm`, `wailing_shade`, `pyre_herald` avec
`family = "insecte"/"annelide"/"spectre"/"culte"`). Ce champ `family` est utilisé par
`creaturegen.cached` pour le rendu visuel — DIFFÉRENT d'une famille mécanique DoT.

**Conséquence roadmap P1** : avant de coder les synergies de type, il faut décider quel
champ porte l'identité de famille DoT sur une unité. Le brouillon v2 ne le dit pas, mais
c'est la première décision d'implémentation. Trois options :
- **Option A** : ajouter `dot_family = "poison"` (champ dédié, sans collision) sur chaque
  unité DoT ; les stat-sticks et les non-DoT n'ont pas ce champ → pas de type = pas de palier.
- **Option B** : inférer depuis `effects[1].op` pour les unités mono-famille (burn, bleed,
  etc.) ; la multi-famille (wither_bloom = rot+bleed+poison) serait « polyvalente » sans palier
  de type.
- **Option C** : accepter que le palier de type ne couvre que les familles DoT (5 types) +
  confirmer que tank/shield/bruiser n'ont pas de type — ce qui résout implicitement Litige #F
  (6e type non-DoT = aucun).

**Source** : poewiki.net/wiki/Ailment (PoE distingue les ailments par leur op de base, pas par
le type de l'unité porteuse). Cette décision doit apparaître AVANT le code du compteur de type.
C'est un trou dans la roadmap v2.

### 2.2 DESACCORD FORT : L'identité du choc dans le brouillon est ENCORE mal posée

Le brouillon v2 (§3.2) présente deux axes candidats : (A) « condensateur carry arrière » et
(B) « mini-dégât à la pose ». Le round 1 a dit « décider avant le ladder » mais n'a pas tranché.

**Le problème plus profond, non posé dans le brouillon :**

La recherche PoE2 (mobalytics.gg/poe-2/guides/shock, poewiki.net/wiki/Shock) confirme que dans
PoE le Shock est une ailment NON-endommagante (« Non-Damaging Elemental Ailment »). Son rôle
est de **rendre la cible plus vulnérable aux dégâts des AUTRES sources**. Cela n'est PAS le
rôle actuel du choc dans The Pit, où la décharge fait ses propres dégâts (`stacks × volt`,
cause `"shock"`, `arena.lua` confirmation ligne ~300, `dischargeShock`). Les deux axes du
brouillon restent dans ce paradigme « choc = dégât propre ».

**L'axe C non proposé, qui résout la viabilité en ciblage déterministe :**
Le choc comme **amplificateur du prochain dégât reçu** — chaque stack de choc augmente les
dégâts de la prochaine source qui frappe la cible (qu'il s'agisse d'une frappe ou d'un tick
de DoT). La décharge n'est plus un dégât autonome mais un **multiplicateur d'explosion**. Cela
résout le problème de l'unité morte avant décharge : la décharge se produit DÈS que la
cible est touchée (même si elle survit peu longtemps), pas « sur la prochaine frappe de
l'unité choc spécifiquement ». La cible choquée prend plus de dégâts de N'IMPORTE QUELLE
source.

**Pourquoi l'axe C survivrait à nos contraintes :**
- **Déterministe** : la décharge au prochain hit (toute source confondue) reste deterministe
  — l'ordre des hits est deterministe (cooldowns fixes, ciblage deterministe).
- **Async-vérifiable** : aucun RNG. Le snapshot capture les unités avec leurs stats ; si le
  choc est modélisé comme un état sur la cible (stack → amplification du prochain hit), c'est
  purement une stat de la cible, snapshottable.
- **Compatible avec les DoT** : si la décharge amplifie le tick de poison suivant, le choc
  crée une synergie avec les 4 autres familles (« choque d'abord, le poison explose plus fort »).
  C'est une interaction croisée lisible, pas un T3 exotique.
- **Résout la hiérarchie** : choc n'est plus un DoT concurrent de poison/burn — il les
  amplifie. Sa niche devient « faire exploser les autres familles ».

**Impact roadmap** : l'axe C change le verdict sur le litige #D et sur les twists de palier 4
choc. Si choc = amplificateur, le palier 4 choc serait « les stacks de choc amplifient aussi
les DoT adjacents ». C'est la décision la plus structurelle de P0.5.

Source : poewiki.net/wiki/Shock (« Shock is a non-damaging elemental ailment that makes the
target take increased damage ») ; mobalytics.gg/poe-2/guides/shock.

### 2.3 DESACCORD MODÉRÉ : La liste des units ladder choc (`units.lua` vague 5) est déjà codée — le brouillon ne le sait pas

Le brouillon v2 (§3.2) parle de « ladder choc 5/3/2 différé en P3 » comme d'un chantier
FUTUR. En lisant `units.lua` lignes 296-334, le **ladder choc est DÉJÀ entièrement codé** :
`live_wire`, `thunderhead`, `static_swarm` (T1×3), `galvanizer`, `stormlord` (T2×2),
`dynamo_priest`, `arc_warden`, `storm_anchor` (modificateurs), plus `stormcaller`
(l'unité originale) = **9 unités choc** dans le code, avec des archétypes distincts
(cadence rapide / volt dense / persistant / transfer / chain).

**Ce n'est pas une dette** — c'est un chantier livré qui attend la décision d'axe.

**Conséquence pour la roadmap** : la décision d'axe choc (P0.5 §3.2) n'est pas un prérequis
« avant de créer des unités » (elles existent) mais un prérequis **avant d'en valider les
paramètres et de les sortir du placeholder**. La formulation du brouillon est à corriger : le
chantier P0.5 choc = « décider l'axe + valider les 9 unités existantes via sim », pas « créer
11 nouvelles unités ».

**Test opérationnel enrichi** (round 1 proposait « taux de décharge après mort de la cible
> 30 %) : avec 9 unités disponibles, on peut maintenant lancer `tools/sim.lua` avec des
compos choc pures (e.g. `live_wire + thunderhead + galvanizer + gravewarden`) sur les 5 sigils
et mesurer directement :
1. win% choc pure vs poison pure (cible : dans [0.40, 0.60]).
2. taux de décharge « gaspillée » (cible encharged avant mort de la cible > 30 % = axe cassé).
3. lift de co-occurrence `(stormcaller, galvanizer)` (identifier si les combinaisons ont du
   headroom).

**Cette information est disponible MAINTENANT dans le code, pas après P3.**

### 2.4 DESACCORD MODÉRÉ : Le twist de palier 4 « burn 4 = pas de décroissance en front-column » n'est pas un twist — c'est un clone de ash_maw

Le brouillon v2 (§4.2) propose comme twist candidat burn 4 : « les brûlures ne décroissent
pas en 1 tour chez les ennemis en front-column ». Le code montre que `ash_maw` (`units.lua`
ligne 231) pose déjà `grant_team { burnNoDecay = true }` = feux de l'équipe entière sans
décroissance.

**Le problème** : si le palier 4 de type burn = « feux sans décroissance en front », et que
ash_maw (rank 5, T3) fait la même chose pour toute l'équipe, on a **deux mécaniques qui font
la même chose à des portées différentes**. Ce n'est pas un twist — c'est un préfixe de
puissance du T3. Le principe MTG NWO (effects-synergy-tiers.md §3.1 : « higher you are in
comprehension/board complexity, the higher the rarity ») interdit d'avoir un T2-twist qui
soit un sous-cas direct du T3.

**Ce que le twist burn 4 devrait faire** : il doit être **orthogonal** à ash_maw, pas un
sous-cas. Options :
- « burn 4 = les brûlures se PROPAGENT immédiatement à la cible adjacente la plus proche
  à leur application (portée 1, pas à la mort) » — c'est la propagation en cours-de-vie,
  différente de la propagation à la mort (wildfire_hound) et du no-decay (ash_maw).
- « burn 4 = chaque frappe avec une unité burn sur une cible déjà en feu RALLUME la brûlure
  au maximum de son intensité d'origine (refresh-max) » — c'est le twist de refresh conditionnel
  (pattern T2-5 de effects-synergy-tiers.md §4.A).

**Source** : effects-synergy-tiers.md §3.1 tableau T2-TWIST, piège (d) : « 2 finishers même
famille → meta résolue ». Un twist qui est un sous-cas du finisher = duplication mécanique.

### 2.5 DESACCORD FAIBLE mais important : les boucliers périodiques (vague 5 `units.lua`) ne sont pas couverts dans le roadmap v2

Le code (`units.lua` lignes 359-380) contient 5 porteurs de boucliers périodiques
(`ward_weaver`, `barrier_savant`, `mirror_ward`, `surge_warden`, `siege_breaker`) avec des
axes lisibles (valeur / renfort / réflexion / surcharge / contre). Ces unités existent.

Le brouillon v2 ne mentionne les boucliers qu'en deux endroits :
- P1.5 §5.1 (b) : « relique shield-pur, amplifier les auras de bouclier ».
- §4.1 note sur le 6e type non-DoT.

**Ce qui manque** : le brouillon ne pose pas la question **des boucliers périodiques comme un
archétype distinct des boucliers d'aura build-résolus**. Le bouclier périodique a un profil
d'interaction radicalement différent :
- **Build-aura** (`shield_aura`) : le bouclier est posé une fois au combat, sert d'absorption
  pasive. Simple, prévisible, contre = `strip_shield` ou bypass poison.
- **Périodique** (`shield_caster`) : le caster re-bouclier ses voisins toutes les N secondes.
  Le contre doit intervenir ENTRE deux recharges (timing window). Le `strip_shield` existant
  (op dans `ops.lua` ligne 104) retire une fraction, mais si le caster rebouclier toutes les
  4 s et que le strip ne se déclenche qu'on_hit, un adversaire lent aura toujours du bouclier.

**Ce problème n'est pas dans le roadmap** et pourtant il y a déjà 5 unités qui créent ce
timing. C'est une lacune d'analyse : les 12 contrats de synergie (#22-32) ne couvrent pas les
interactions bouclier-périodique × vitesse de frappe adverse.

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Trancher l'axe choc : adopter l'axe C « amplificateur de dégâts reçus » [HAUTE PRIORITÉ, P0.5]

**Quoi** : reformuler le choc non comme « dégât propre à la décharge » mais comme
**amplification du prochain hit reçu** (toutes sources confondues, frappe ou tick DoT).
Chaque stack = +N% aux dégâts du prochain hit sur cette cible. La décharge se produit sur
le premier hit suivant (not on attacker's next hit, mais on cible's next hit reçu).

**Avantages mécaniques** :
1. Résout la viabilité en ciblage déterministe : même si une unité choc ne peut plus frapper
   (morte), la cible choquée reste amplifiée pour les autres frappes de l'équipe.
2. Crée une synergie naturelle avec les 4 familles DoT (choc + rot = le tick suivant fait
   plus de dégâts) — new interaction layer sans nouveau op.
3. Différencie le choc des 4 DoT par son identité « amplificateur » vs « dégât direct ».
4. Compatible avec les 9 unités choc existantes (modif op `shock`, pas moteur).

**Chiffrer via sim** :
- Sur 400 combats : compo `live_wire + stormlord + galvanizer + gravewarden` (tank pour
  survivre, choc pour charger, puis frappe lourde pour exploser).
- Mesurer win% vs poison pure, vs burn pure, vs mixte.
- Viser [0.45, 0.55] après tuning de la magnitude `+N% per stack`.

**Coût** : modification de `arena.lua:dischargeShock` (remap dégâts → amplification) + 1
champ `shocked_amp` sur la cible + l'op shock reste data-only. Invariants #1-5 (déterminisme)
préservés (pas de RNG ajouté). Golden devra être rebasé (le choc fait plus/moins de dégâts).
**Signaler explicitement : modif golden = changement intentionnel, pas régression.**

**Source** : poewiki.net/wiki/Shock (identité amplificateur non-endommagante confirmée).

### P2 — Ajouter le champ `dot_family` (distinct de `type`) avant tout code de type P1 [HAUTE PRIORITÉ, avant P1]

**Quoi** : décider le champ porteur de l'identité de famille DoT sur les unités. Recommandation :
**Option A** : ajouter `dot_family = "poison"/"burn"/"bleed"/"rot"/"shock"` (ou `nil` pour
les non-DoT) comme champ de premier niveau dans `units.lua`. C'est un champ data-only,
rétro-compatible (nil = pas de type = pas de palier), lisible dans les infobulles, et il
n'entre pas en collision avec `type` (visuel) ni `family` (rendu procédural).

**Coût** : data-only (ajouter le champ à ~50 unités DoT). Aucun moteur, aucun invariant.
L'implémentation du compteur (P1) lit `unit.dot_family` au lieu d'inférer depuis les ops.

**Pourquoi avant P1** : le compteur de palier de type a besoin d'un champ stable pour compter.
Sans ce champ, le code de P1 inférera depuis les ops (fragile : wither_bloom a 3 ops DoT
différents) ou utilisera `type` (collision avec le thème visuel). Ce n'est pas de la
sur-ingénierie — c'est la décision de la prochaine ligne de code.

### P3 — Reformuler P0.5 choc : « valider les 9 unités existantes » pas « créer le ladder » [PRIORITÉ CORRECTRICE, P0.5]

**Quoi** : corriger la formulation du brouillon v2 §3.2 — le ladder choc (9 unités) EST dans
le code. La décision d'axe doit être suivie d'une **validation sim des 9 unités existantes**
(pas d'une création de contenu). Le chantier P0.5 choc = :
1. Décider l'axe (A/B/C proposé ci-dessus).
2. Modifier l'op `shock` et `dischargeShock` pour l'axe retenu (si C : changement op).
3. Sim 400+ combats avec les 9 unités choc existantes + ajustement des params (`volt`,
   `add`, `cap`) via `tools/sim.lua`.
4. Rebaseline golden si le comportement choc change.

**Coût** : plus court que prévu (pas de création de 11 unités). Débloque P3 équilibrage choc.

### P4 — Critère opérationnel pour Litige #D (adjacence-type vs global) [PRIORITÉ DÉCISION, P1]

**Quoi** : le brouillon v2 dit « sim montre du stack sans pensée positionnelle → passer à
adjacence-type ». Ce critère est trop vague. Critère opérationnel proposé :

**Mesurer** sur 400 combats, pour les compos avec ≥1 palier de type activé (global count ≥ 2) :
- **Metric A** : distribution des positions des unités du même type sur le plateau. Si
  `stddev(position)` est haute (unités du type éparpillées) MAIS que le win% reste élevé → le
  palier global n'encourage pas le placement groupé → adjacence-type serait plus riche.
- **Metric B** : frequency de palier type atteint à `slots_used < 9/2` (palier 2 atteint
  avec seulement 3-4 slots = trop facile, aucune pression de build) → seuil 2 trop bas.

**Seuil de décision** : si `stddev(position) > 2.0` (dispersion sur 3×3) pour les compos à
palier activé AND win% > 0.55, l'adjacence-type est justifiée. Sinon, global suffit.
Cette mesure est faisable avec `tools/sim.lua` (log des positions des unités).

**Source** : effects-balance-counterplay.md §3.4 (co-occurrence et diversité de compos).

---

## 4. QUESTIONS OUVERTES (non résolues, à trancher en round 3+)

### Q1 : Axe choc C — la décharge amplifie-t-elle uniquement la prochaine frappe, ou TOUS les dégâts pendant 1 tick ?

Si la décharge = amplification du prochain single-hit : risque de ne valoir que pour les
grosses frappes (thunderhead : 1 frappe = 1 explosion). Si la décharge = amplification de
tous les dégâts du prochain tick (frappes + DoT tick simultané) : plus de valeur pour les
archétypes DoT mais plus complexe à implémenter (timer de tick).

### Q2 : Litige #F (6e type) — si choc devient amplificateur, a-t-il encore besoin d'un palier de type ?

Si le choc n'est plus un DoT concurrent mais un support (amplificateur des autres), son
palier de type « 4 choc → +X% amplification » a moins de sens. Le palier choc pourrait plutôt
conditionner l'archétype : « 2 choc → l'amplification affecte aussi les DoT tick, pas seulement
les frappes ». Cela résout aussi une partie du Litige #F : les non-DoT (tank/shield) restent
sans type, le choc garde sa présence dans les types mais avec une identité d'amplificateur.

### Q3 : Les boucliers périodiques ont-ils besoin d'un counter de timing ?

Le `strip_shield` actuel retire un % de bouclier au `on_hit`. Le bouclier périodique recharge
toutes les 4 s. Si l'adversaire frappe lentement (cd > 240 ticks), le bouclier est toujours
plein. Faut-il un counter de timing (e.g. « pierce_shield ignore les boucliers posés il y a
moins de N ticks ») ou une rule « strip retire le bouclier ET impose un cooldown sur la
prochaine recharge » ? Cette question n'est pas dans le roadmap v2 et concerne les 5 unités
de la vague 5.

### Q4 : Le champ `dot_family` sur wither_bloom (rot + bleed + poison) — quel type pour le palier ?

`wither_bloom` (T3 rot) pose 3 DoT à 0 dps (rot réel + bleed pur slow + poison pur weaken).
Si on ajoute `dot_family = "rot"` (le DoT principal), c'est logique mais les 2 ops secondaires
ne bénéficient pas du palier bleed ou poison. Si `dot_family = nil` (polyvalent sans palier),
wither_bloom sort de la dynamique de type. Cette ambiguïté structurelle doit être résolue avant
de coder le compteur.

---

## 5. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée |
|----------|----------|----------------|--------------------|
| Collision champ `type` (visuel) vs type DoT mécanique — manque dans roadmap | **FORTE** | Bloque P1 (code) | Ajouter `dot_family` avant P1 code |
| Axe choc : axe C (amplificateur) non proposé — brouillon ne résout pas la viabilité | **FORTE** | Bloque P0.5+P3 | Adopter axe C + sim 9 unités existantes |
| Ladder choc déjà codé (9 unités) — brouillon le présente comme « à créer » | **MODÉRÉE** | Reformuler P0.5 | Corriger formulation + sim dès maintenant |
| Twist burn 4 = sous-cas de ash_maw T3 — duplication mécanique | **MODÉRÉE** | Déséquilibre P1 | Twist burn 4 orthogonal à ash_maw |
| Boucliers périodiques : archétype non couvert dans le roadmap | **FAIBLE** | Gap P3 | Ajouter métrique sim timing-shield |
| Litige #D critère trop vague | **FAIBLE** | Retard bascule | Critère opérationnel sim (§3.4 ci-dessus) |

---

## Index des sources

**Sources web vérifiées ce round :**
- PoE2 Shock (Non-Damaging Ailment, default +20%, max +50%) : https://mobalytics.gg/poe-2/guides/shock
- PoE2 Ailments classification (Damaging vs Non-Damaging) : https://www.mmopixel.com/news/poe-2-damage-ailments-guide-poison-bleeding-and-ignite-ailments-explained
- PoE Wiki Shock (additive with other increased damage taken, non-stacking by default) : https://www.poewiki.net/wiki/Shock
- PoE2 vs Shock vs Electrocute : https://www.sportskeeda.com/mmo/path-exile-2-shock-vs-electrocute-ailment-explained
- TFT Set 1 learnings (traits trop larges, Blademaster) : https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings/
- SAP positional triggers : https://a327ex.com/posts/super_auto_pets_mechanics
- Balatro & auto chess (power curve, types séparés du positionnement) : https://gangles.ca/2024/07/07/balatro-auto-chess/
- Dota Auto Chess synergies (count-based, pas adjacency) : https://guides.gamepressure.com/dota-auto-chess/guide.asp?ID=48463
- DIVA-portal auto chess balance (synergy count mechanics) : https://www.diva-portal.org/smash/get/diva2:1980319/FULLTEXT02.pdf

**Sources internes (code lu ce round) :**
- `src/data/units.lua` lignes 1-430 (roster complet : champ `type` visuel confirmé distinct de
  famille DoT ; ladder choc 9 unités confirmé lignes 296-334 ; vague 2 auras 147-163 ;
  vague 5 boucliers périodiques 359-380).
- `src/effects/ops.lua` (op `shock` lignes 180-200 : 0 dégât à la pose, décharge dans
  `dischargeShock`).
- `src/combat/arena.lua` lignes 1-120 (constantes SHOCK_STACK_CAP=8, HP_MULT=2, FATIGUE_START).
- `docs/roadmap-lab/00-state.md` (état canonique, 32 invariants).
- `docs/research/effects-synergy-tiers.md` §3.1, §4.A, §5.2 (template T1/T2/T3, pièges,
  adjacence).
- `docs/research/effects-balance-counterplay.md` §2.6 (règle de processus counterplay),
  §3.4 (co-occurrence).

---

*Round 02 rédigé le 2026-06-23. Lecture seule du repo (code cité avec lignes). N'édite que
sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants préservés (toute modif choc
impliquerait un rebaseline golden explicite — non silencieux). Litiges ouverts #D/#F/#A2
enrichis par ce round ; nouveaux trous identifiés (`dot_family`, boucliers périodiques timing,
axe C choc).*
