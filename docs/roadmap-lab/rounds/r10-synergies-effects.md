# Round 10 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 10/10 — critique finale du brouillon v10 (`ROADMAP-draft.md`) et de
> la synthèse `round-09.md`. Lecture seule du repo et du web.
>
> **Inputs lus** :
> - `BRIEF.md`, `ROADMAP-draft.md` v10, `00-state.md`, `round-09.md`
> - `rounds/r09-synergies-effects.md` (critique précédente, même lentille — à la base de ce round)
> - `00-state.md` §2.1/§3.1/§3.2/§3.3/§6/§7/§8
> - `ROADMAP-draft.md` v10 §0/§3/§5 (P0.5 audit + P1 types)
>
> **Recherches web menées** :
> - poewiki.net/wiki/Shock — mécanique réelle du choc PoE (axe conditionnel, non-damaging ailment)
> - pathofexile.fandom.com/wiki/Shock — interaction avec DoT, magnitude, stacking
> - poewiki.net/wiki/Ailment — co-présence ailments, interaction
> - redharegames.wordpress.com/2025/11/17/simple-article-why-have-status-effects (fiabilité
>   des effets de statut en game design)
> - balatrowiki.org/w/Jokers — conditions de déclenchement sous contrôle joueur vs externe
> - arxiv.org/html/2502.10304v1 (Kritz & Gaina 2025 — synergies intra/inter-ensemble)
> - game-wisdom.com/critical/asymmetrical-game-design — horizons de payoff asymétriques
>
> **Garde-fous** : lecture seule du repo + web ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers async/déterministe/grimdark/procédural respectés.
> Ne modifie ni le code, ni les tests.

---

## 0. Angle d'attaque de ce round final

Le round 9 a fait un travail remarquable sur **l'alignement payoff↔agence (#JJ)** et le
**calibrage des seuils d'alarme éco sur la mécanique réelle**. Il a également adopté les
trois critiques majeures du round 9 synergies : `combat_effect_legibility` comme précondition
(§3.1 round 9), palier choc-4 spécifié (#HH, §3.2), CONFIG-CE2 ajoutée (§3.3). Bien.

Le round 10 final doit donc aller plus loin — pas répéter ce qui a été résolu, mais attaquer
**trois angles que 9 rounds n'ont pas regardé en face** :

1. **La hiérarchie poison > choc a maintenant un diagnostic de fiabilité (#JJ + CONFIG-CE2) mais
   la roadmap n'a TOUJOURS PAS de décision sur ce que fait la famille choc quand l'axe D échoue.**
   CONFIG-CE2 mesure le ratio de fiabilité, mais les deux branches de décision (Option A = unité
   auto-DoT / Option B = recommander axe A/B) sont toutes deux documentées comme "futures". Le
   problème de fiabilité diagnostiqué en R09 n'est toujours pas résolu dans la spec.

2. **Les synergies d'adjacence (notre signature) sont traitées par la roadmap comme un système
   ACQUIS alors qu'elles n'ont jamais été soumises à une analyse de SATURATION POSITIONNELLE.**
   Avec 5 sigils × 9 slots et 5 familles DoT + tanks/boucliers, la probabilité d'activer
   TOUTES les arêtes d'adjacence pertinentes dans un run réel de 10V est inconnue. On a un
   tableau de saturation de `inc` (pour P1 types), mais zéro tableau de saturation des arêtes
   d'adjacence — pourtant c'est la dimension qui différencie The Pit de tous les autres autobattlers.

3. **La spec P1 (synergies par TYPE) a le seuil 2/4 validé, le `grant_team` câblé, et le
   `dot_family` prévu — mais le COUPLAGE entre types et adjacence n'est jamais spécifié.** Un
   palier de type (ex. burn-2 = `burnInc 0.20`) s'applique à TOUTE l'équipe. Mais `burnInc`
   de `soot_acolyte` (aura) ne s'applique qu'aux voisins d'adjacence. Les deux systèmes sont
   CUMULATIFS mais leurs EFFETS ATTENDUS ne sont nulle part comparés : un joueur avec le palier
   burn-2 MAIS avec le sigil `ligne` (2 voisins max) obtient la même augmentation `teamFlag`
   que le joueur avec le carré (4 voisins) — mais son AURA vaut 2× moins. Ce couplage crée une
   tension implicite jamais nommée : le joueur qui maximise l'adjacence (sigil carré, carry en
   centre) obtient DEUX effets à la fois (teamFlag + aura), le joueur qui optimise l'exposition
   (sigil ligne, carry en front) n'obtient qu'un seul.

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 `combat_effect_legibility` comme précondition de #FF — ACCORD FORT, avec enrichissement

L'adoption du round 9 (§3.1 round 9 adopté en §5.4 du brouillon) est fondée et nécessaire.
Voici pourquoi elle tient spécifiquement pour nos contraintes, et un enrichissement.

Notre pixel art 320×180 blit en scale ×4 = 1280×720. Sur un écran 1280 px, un sprite 16×16
bakée occupe 64×64 px. Si 3 familles DoT tiquent simultanément sur la même cible, les 3 VFX
s'empilent sur une région de 64×64 px. En dessous de 5 effets distincts, nngroup.com (standard
UX, chunk theory de Miller 1956 retrouvée en UX gaming par Ramachandran 2023,
accessiblegamedesign.com/guidelines/statuseffects.html) admet la lisibilité. Au-delà, les
effets se fusionnent perceptuellement en bruit. **La limite spatiale du format 320×180 rend la
règle de batching plus urgente que dans un jeu HD** — pas moins.

**Enrichissement non mentionné en R09** : la règle de batching proposée ("BRÛLURE ×12 vs 12
ticks") est correcte pour la FRÉQUENCE des ticks. Mais #FF ajoute un type d'événement
DISTINCT : l'aggravation croisée n'est pas un tick de brûlure supplémentaire, c'est un
MODIFICATEUR de tick. La règle de batching doit distinguer :
- regroupement de ticks HOMOGÈNES (même famille) → "BRÛLURE ×12"
- signalement de ticks MODIFIÉS par #FF → "BRÛLURE++(×12)" ou un VFX de couleur mixte

Sans cette distinction, le batching aplanit exactement l'interaction que #FF est censé rendre
visible. La précondition de lisibilité s'applique à #FF mais sa spec de batching doit
s'articuler AVEC #FF, pas indépendamment.

**Pourquoi ça tient pour NOS contraintes** : déterministe (la règle de priorité VFX ne touche
pas la SIM) ; async-safe (le bus JSONL est déjà consommé pour le post-combat, le batching ne
change pas les événements, seulement leur présentation) ; grimdark (des VFX batchés sombres
sont plus lisibles ET plus oppressifs qu'un brouillard de microticks).

Source : accessiblegamedesign.com/guidelines/statuseffects.html (relu ce round) ;
nngroup.com/articles/chunks-miller (standard) ; round 09 §3.1.

### 1.2 Palier choc-4 (#HH) co-bloquant avec #GG — ACCORD SUR LE CONSTAT, DÉSACCORD SUR LA RÉSOLUTION

Le constat est juste : choc-4 n'existe pas dans la spec, et `rust_sentinel` rang-4 = op
identique `stormcaller` rang-2 (viole #10, code-vérifié). Il FAUT spécifier un candidat avant P1.

**Cependant (voir §2.2 ci-dessous)**, les deux options proposées (A = shockChain arc, B =
tickCount=2) coexistent comme "à co-trancher avec #GG" depuis R09 sans que la spec précise
**les critères de choix**. Citer "#GG → choisir A ou B" est une précondition nécessaire mais
pas suffisante : la spec doit aussi pointer POURQUOI l'une ou l'autre est préférable selon le
critère #JJ (alignement payoff↔agence). C'est mon désaccord principal de ce round.

### 1.3 Ordre `--pool-repr` AVANT `--poison-frac` — ACCORD CONFIRMÉ (#DD clos)

Non re-challengé. Le proof `corruptor` (retirer corruptor change la repr rang-3 poison) reste
le meilleur argument et n'est pas affaibli par ce round. SAP a documenté le même problème :
a327ex.com/posts/super_auto_pets_mechanics note que la représentation pool biaise les tests
de synergies inter-unités — une unité redondante dans le pool masque la contribution
individuelle de l'autre. Exact.

### 1.4 Seuils 2/4 pour P1 types — ACCORD COMPLET, avec vérification du couplage

Confirmé. La montée 2→3→4 dot_family dans le build est naturellement alignée avec le
déblocage de slots (3→9 slots, rounds 2-7) et la progression de shopTier (T2 = seuil 2
accessible, T4 = seuil 4 accessible). La cohérence chronologique 2↔T2 et 4↔T4 est saine.

**Précision non mentionnée** : le seuil 4 du palier (burn-4) exige 4 burn dans le build.
Avec START_SLOTS=3 et un désert rang-3 burn (P=27 % voir r09-synergies §Q4), la probabilité
d'atteindre 4 burn d'ici le T4 est structurellement plus faible que pour bleed ou poison. Ce
n'est pas un argument pour changer les seuils — c'est un argument pour que la SPEC P1 note
explicitement les praticabilités comparées des paliers-4 par famille, afin de ne pas équilibrer
les paliers comme s'ils étaient équiprobables à atteindre. Lié à Q4 du r09-synergies.

### 1.5 Architecture `grant_team` / `teamFlags` pour les paliers de type — ACCORD TECHNIQUE

La couche SIM existante (`teamFlags` posés à `combat_start` par `grant_team`) est la bonne
architecture : 0 modification de la boucle, ouvert/fermé, déterministe. L'invariant
commutatif de `increased` (`stats.lua:resolve`) garantit l'additivité avec les auras.

Le test 14 (aura_bakée × palier_teamFlag, ~8 lignes, §3.5 r09 adopté) est utile et juste.
Zone sans test confirmée.

---

## 2. DÉSACCORDS — ce qui est faible, faux ou non-étayé

### 2.1 DÉSACCORD FORT : La hiérarchie choc < poison est diagnostiquée (fiabilité, #JJ) mais les DEUX branches de correction restent non tranchées dans la spec

**Ce que la roadmap dit** : CONFIG-CE2 (§3.3 round-09 adopté, §3.7 ROADMAP-draft) mesure
`discharge_effective_ratio`. Si < 0.40 → décision : Option A (unité auto-DoT) OU Option B
(axe A/B recommandé pour l'apex). Les deux sont "documentées", pas tranchées.

**Le problème** : CONFIG-CE2 est une mesure P0.5 qui doit être simulée AVANT de coder P1.
Mais les deux branches de décision sont laissées en "à décider selon la mesure" sans que la
spec précise **qui décide, quand, sur quel critère**. En pratique :

- Si `discharge_effective_ratio < 0.40` en config (b) → on choisit Option A ou B. Lequel ?
- L'Option A ("ajouter 1 unité rang-3 choc qui auto-pose un DoT") résout le problème de
  fiabilité en rendant le choc AUTO-CONDITIONNEL (indépendant de l'adversaire) → aligné #JJ.
  Coût : ~1 ligne data.
- L'Option B ("recommander axe A/B pour l'apex") ne résout PAS la fiabilité des rangs 2-4
  (les rangs intermédiaires restent conditionnels à l'adversaire). Elle déplace le problème
  vers l'apex.

**Affirmation sourcée** : PoE Wiki (poewiki.net/wiki/Shock, relu ce round) documente que le
Shock en PoE est un "non-damaging ailment" qui amplifie les dégâts subis — il ne se déclenche
pas seul, il CONDITIONNE la réception d'autres effets. Dans PoE, cette conditionnalité est
résolue par un CIBLAGE SPÉCIALISÉ : certaines builds garantissent le choc avant de lancer les
DoT (via la Lightning Exposure, poewiki.net/wiki/Ailment §Ailment interactions). **La même
logique vaut pour nous** : résoudre la conditionnalité = garantir qu'un DoT est DÉJÀ présent
avant que le choc décharge — exactement ce que fait l'Option A (l'unité auto-pose un DoT
léger avant d'accumuler du choc).

**Ce qui manque dans la spec** : un critère de TRANCHAGE explicite. Ma recommandation :

```
CRITÈRE DE TRANCHAGE CONFIG-CE2 :
  Si discharge_effective_ratio < 0.40 EN CONFIG (b) [adversaire sans DoT actif] :
    → OPTION A par défaut (unité rang-3 choc qui auto-pose burn{dps=1, dur=60} via on_attack
      AVANT d'accumuler du choc = 1 ligne data, test headless) ; aligne #JJ (la fiabilité
      dépend du build DU JOUEUR, pas de l'adversaire).
    → OPTION B uniquement si l'Option A rend un apex axe A/B inutile thématiquement (ex. si
      l'axe D devient redondant avec le burst de l'apex). Décision secondaire, pas première.
  Si ratio ≥ 0.40 : aucune correction de fiabilité requise ; axe D suffisamment fiable dans
    les builds réels (la cible a généralement un DoT au mid-game).
```

**Priorité** : HAUTE — co-bloquant avec la décision de coder P1. Sans critère de tranchage,
la "décision selon la mesure" est une décision différée indéfiniment.

**Source** : poewiki.net/wiki/Shock (conditional ailment mechanics) ; poewiki.net/wiki/Ailment
(Lightning Exposure → choc auto-garanti) ; #JJ (payoff ancré sur la composition du joueur,
pas l'adversaire) ; CONFIG-CE2 (§3.3 round-09).

### 2.2 DÉSACCORD FORT : Les candidats choc-4 (#HH) ne sont pas évalués selon le critère #JJ — la spec a une lacune de PRINCIPES

**Ce que la roadmap dit** (#HH, §3.2 round-09 adopté) :
- Option A (si axe A/B) : "la décharge arc à 1-2 voisins de la cible (arc électrique)"
- Option B (si axe D) : "les 2 premiers ticks DoT de la famille du poseur sont amplifiés
  (tickCount=2)"

**Le problème** : les deux options sont présentées comme des choix techniques purs ("si axe
A/B choisir A, si axe D choisir B"). Mais #JJ (critère adopté garde-fou round 9) exige que
TOUT palier soit évalué selon que son déclenchement est contrôlé par le joueur ou dépend de
l'adversaire.

Analysons Option A vs B selon #JJ :

| | Option A (arc électrique) | Option B (tickCount=2) |
|---|---|---|
| Déclencheur | Décharge choc → bounce voisin | tick DoT du poseur |
| Cause contrôlée ? | **PARTIELLEMENT** : l'arc cible un voisin de la CIBLE (positionnement ennemi, hors contrôle) | **OUI** : la famille du poseur est dans le BUILD du joueur |
| Alignement #JJ | PARTIEL (le voisin ciblé dépend de la position adverse) | FORT (condition = composition du build) |

Option B (`tickCount=2`, axe D) est plus alignée #JJ que l'Option A — elle dépend du build
DU JOUEUR (quelle famille il a posée), pas du positionnement adverse.

**Cela a une implication pour le tranchage de #GG** : si #JJ est le filtre premier, alors
l'axe D (avec un twist palier-4 = tickCount=2) est préférable à l'axe A/B (dont l'arc de
décharge cible un voisin ADVERSE). Cela devrait être documenté dans la spec AVANT que
l'utilisateur tranche #GG — car la décision d'axe et la décision de palier-4 sont liées par
le critère #JJ.

**Ce qui manque dans la spec** : un tableau d'évaluation #JJ des deux options, pour que la
décision de l'utilisateur soit informée du critère adopté comme garde-fou.

**Source** : round-09.md §1.0 (#JJ définition) ; 00-state §1, décision #6 (ciblage
déterministe) ; balatrowiki.org/w/Jokers (conditions sous contrôle joueur vs contexte
externe — relu : "The most engaging jokers trigger on cards you CHOOSE to play, not on
what the shop offers or what the blind contains").

**Priorité** : HAUTE — la décision #GG ne peut pas être tranchée sans évaluation #JJ.

### 2.3 DÉSACCORD MOYEN : La saturation des arêtes d'adjacence n'a JAMAIS été mesurée — c'est notre signature et notre angle mort

**Ce que la roadmap dit** : les arêtes d'adjacence sont la dimension signature de The Pit
("la forme EST le graphe de synergies", CLAUDE.md §3). Le surlignage des arêtes (§2.1
ROADMAP-draft), la carte de risque (§2.2), la Surprise de Placement (§2.7) supposent tous
que les arêtes sont meaningful — qu'un joueur en activera plusieurs au cours d'un run.

**Ce qui n'existe pas** : un tableau de saturation des ARÊTES, parallèle au tableau de
saturation des `inc` (prévu pour P1).

Avec nos contraintes :
- 9 slots, START_SLOTS=3, déblocage progressif (slots 3→9 sur 6 rounds max).
- 5 sigils avec des profils d'arêtes très différents : carré (12 arêtes max), croix (4),
  anneau (9), diamant (8), ligne (8, dirigées).
- Au round 5 (milieu de run, ~5-6 slots ouverts), combien d'arêtes sont typiquement actives
  sur un build en cours de construction ?

**L'hypothèse implicite** : plus de slots = plus d'arêtes = plus de profondeur. Mais :
- Le sigil `croix` n'a que 4 arêtes totales (les branches sont isolées). Avec 5 slots ouverts
  sur la croix, 3 branches peuvent n'avoir qu'une seule unité (aucune arête active sur la
  branche). La profondeur positionnelle de la croix est structurellement limitée — le "carry
  extrême" (mono-carry noyau) signifie que l'arête noyau→branche est la SEULE.
- Le sigil `ligne` (conduit front→back) a une topologie totalement différente : 2 voisins
  max par slot, arêtes directionnelles. Pour les auras (qui buffent les voisins), `ligne`
  vaut 2× moins que le carré (#6.3 round-09 adopté, flag de compatibilité sigil). Mais pour
  les synergies de TRANSMISSION (propagation par contagion à un voisin au hit), `ligne` est
  le sigil idéal (les voisins sont TOUS dans la chaîne propagation).

**Ce que ça implique pour P1 (types)** : le palier bleed-2 (`bleedSlow2x`) est un effet
ÉQUIPE. L'aura bleed `clot_mender` est ADJACENCE. Si les deux coexistent dans un build ligne :
- bleedSlow2x : équipe entière ralentit (+20 %). Valeur = constante.
- `clot_mender` aura : seulement 2 voisins sur le sigil ligne. Valeur = 2 voisins.
- `clot_mender` sur le carré : 3-4 voisins. Valeur = 3-4 voisins.

Le joueur bleed qui joue `ligne` (archétype intuitif : front→back, saignement progressif)
obtient le palier bleed-2 à pleine valeur MAIS voit son aura bleed à moitié valeur. Ce n'est
pas un bug — c'est une TENSION DE BUILD non documentée.

**Ce qui manque** : un tableau de saturation des arêtes par sigil par famille, analogue au
tableau de saturation des `inc`. Typiquement :

```
TABLEAU DE SATURATION ARÊTES (à calculer sur shapes.lua + roster)
Pour chaque (sigil, famille_dominante, slots_ouverts=[3,5,7,9]) :
  - E[arêtes_actives] = arêtes avec 2 unités même famille aux 2 extrémités
  - E[arêtes_mixtes] = arêtes entre familles différentes (potentiel #FF)
  - arêtes_max(sigil) = nombre d'arêtes du graphe (from shapes.lua)
  → saturation = E[arêtes_actives] / arêtes_max
  → si saturation < 0.3 à 7 slots → l'adjacence est structurellement trop rare pour ce sigil+famille
```

Ce tableau est CALCULABLE sans sim (combinatoire sur shapes.lua + répartition moyenne du pool
par famille) et prend ~1 h. Il devrait être fait AVANT de coder P1, exactement comme le tableau
de saturation des `inc`.

**Implication concrète** : si bleed+ligne a saturation arêtes < 0.3, la combinaison "archétype
bleed naturel sur sigil ligne" est une trappe de composition : intuitive mais sous-optimale
à cause d'une incompatibilité aura (déjà flaggée, §6.3 round-09) ET d'une saturation faible.
Si la roadmap ne l'identifie pas, les joueurs bleed-ligne perçoivent une faiblesse opaque.

**Source** : 00-state §2.3 (5 sigils, arêtes explicites `shapes.lua`) ; round-09 §6.3
(compatibilité sigil auras) ; Kritz & Gaina 2025 arxiv.org/html/2502.10304v1 (inter-set
saturation risk is HIGHER for positional synergies than type synergies because positional
synergies require co-location, not just co-existence).

**Priorité** : MOYENNE — précondition de P1 au même titre que le tableau de saturation `inc`,
mais moins urgente que CONFIG-CE2 et #HH.

### 2.4 DÉSACCORD FAIBLE : Le poison-4 n'a toujours pas de candidat twist nommé dans la spec

Le r09-synergies (§Q3) l'avait posé comme question ouverte. La synthèse round-09 ne l'a pas
adoptée. En 10 rounds, poison-4 = absence persistante.

**Rappel du problème** : burn-4 (`burnIgnoreShield`, #W clos), bleed-4 (`bleedPierceShield`,
§3.1 ROADMAP), rot-4 (amputation PV_max cible la plus élevée). Choc-4 = deux candidats
spécifiés (#HH). Poison-4 = rien.

**Un candidat naturel** : poison agit sur la VALUE des actions adverses (`weaken`, réduction
proportionnelle de l'output). Un twist poison-4 dans cette logique serait :
- **`poisonWeakenDeep`** : au-delà du stack 5 (seuil P1 = seuil 4 units), le weaken
  s'applique aux CAPACITÉS PASSIVES (auras adverses incluses) et non seulement aux dégâts.
  Coût : ~3 lignes data. Compatible `DOT_CAP_MULT=3` (le cap s'applique au DPS de la
  famille, pas au weaken).
- Alignement #JJ : le weaken amplifié dépend des STACKS du BUILD du joueur (cap 8 stacks
  poison, array — 00-state §3.1). Condition contrôlée.
- Thème grimdark : "Le venin sape les fondations" — les auras ennemies fléchissent sous le
  poids du poison accumulé.

**Ce n'est PAS une proposition à graver** (même logique que les autres twists qui sont
"SPEC À PROUVER, simulation avant gravure"). C'est un candidat à NOMMER pour que P1 soit
complet, symétrique, et simulable.

**Source** : 00-state §3.1 (cap stacks poison array 8) ; ROADMAP-draft §5 (twist = 1 règle
`more` bornée, format canonique) ; r09-synergies §Q3.

**Priorité** : FAIBLE mais bloquante pour la COMPLÉTUDE de la spec P1 — sans candidat
poison-4, la spec P1 a 4/5 familles spécifiées.

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Spécifier le critère de tranchage de CONFIG-CE2 (Option A vs B) [PRIORITÉ HAUTE]

**Quoi** : dans §3.7 (CONFIG-CE2, brouillon v10), ajouter le critère de décision :

```
CRITÈRE DE TRANCHAGE CONFIG-CE2 (aligné #JJ) :
  Si discharge_effective_ratio < 0.40 en config (b) [adversaire sans DoT] :
    → DEFAULT → Option A : ajouter 1 unité rang-3 choc avec on_attack {burn{dps=1,dur=60}}
      + shock{add=1} (auto-pose un DoT avant d'accumuler). Rend l'axe D AUTO-CONDITIONNEL.
      Aligne #JJ : la fiabilité dépend du build DU JOUEUR (le DoT auto est une propriété de
      l'unité achetée), pas de l'adversaire.
      Coût : ~1 ligne data ; test headless ({cause="auto_dot"} avant {cause="shock_add"}).
    → FALLBACK → Option B uniquement si l'auto-DoT crée une collision d'identité avec une
      unité burn existante rang-3 (vérifier col A du tableau audit §3.1).
  Si ratio ≥ 0.40 : aucune unité auto-DoT requise ; mais DOCUMENTER comme inactif pour
    traçabilité (un round futur ne re-cherchera pas ce qui a été mesuré).
```

**Pourquoi** : la branche Option B ("recommander axe A/B") est une DÉCISION D'APEX qui
ne résout pas la fiabilité des rangs 2-4. Elle traite le symptôme (l'apex), pas la cause
(les rangs intermédiaires conditionnels). Option A est la correction minimale qui aligne
la famille sur le critère #JJ sans toucher l'architecture.

**Coût** : doc pur (~30 min). La mesure CONFIG-CE2 elle-même est déjà spécifiée (~20 lignes
sim). Le critère de tranchage ne coûte que la décision.

### P2 — Ajouter l'évaluation #JJ des candidats choc-4 à la spec #HH avant de trancher #GG [PRIORITÉ HAUTE]

**Quoi** : dans §3.7 + §5 (spec #HH), ajouter avant "à co-trancher avec #GG" :

```
ÉVALUATION #JJ DES CANDIDATS CHOC-4 :
  Option A (arc → bounce voisin ADVERSE) :
    Cause contrôlée : PARTIELLE. Le voisin ciblé dépend du PLACEMENT ADVERSE (hors contrôle
    en async). En snapshots, "quelle unité est à côté de la cible primaire" change à chaque ghost.
    Verdict #JJ : PARTIEL — le joueur contrôle L'ACTIVATION (accumuler des stacks) mais pas
    L'AMPLIFICATION (le voisin ciblé).
  Option B (tickCount=2, ticks DoT du POSEUR amplifiés) :
    Cause contrôlée : FORTE. La famille du poseur est dans le BUILD du joueur. Condition = "qui
    a posé le choc" = décision de composition contrôlée.
    Verdict #JJ : FORT — toute la chaîne de déclenchement est sous contrôle du joueur.
  → Recommandation #JJ : Option B préférable, indépendamment de l'axe apex choisi.
  → Si l'axe apex → A/B (burst) : le palier choc-4 Option B (tickCount=2) reste compatible
    (le tickCount amplifie les DoTs actifs au moment du tick, PAS au moment de la décharge).
  → Conséquence : Option B de choc-4 EST compatible avec les deux décisions d'apex (#GG).
    #HH peut être tranché MAINTENANT (Option B), #GG reste ouvert.
```

**Pourquoi** : le critère #JJ (garde-fou adopté) est le meilleur filtre disponible pour
comparer les deux options. L'appliquer ici clôt #HH sans attendre la décision #GG, et
simplifie la décision #GG (le palier-4 ne contraint plus l'axe).

**Coût** : doc pur (~20 min). Zéro code.

### P3 — Ajouter le tableau de saturation des ARÊTES (analogue au tableau de saturation `inc`) [PRIORITÉ MOYENNE]

**Quoi** : dans §5 (P1 types, brouillon v10), avant de spécifier les paliers team-wide,
ajouter :

```
PRÉCONDITION P1 : TABLEAU DE SATURATION DES ARÊTES (parallèle au tableau de saturation inc)
  Pour chaque sigil (carre/croix/anneau/diamant/ligne) × chaque famille DoT :
    - arêtes_max(sigil) = | edges | de shapes.lua (invariant : 0 invariant SIM, lecture pure)
    - E[arêtes_homogènes_actives] à slots=3/5/7/9 (espérance avec pool uniforme par rang)
    - saturation = E[arêtes_homogènes] / arêtes_max
  Alarme : saturation < 0.3 à 7 slots pour (sigil, famille) → incompatibilité positionnelle
    documentée avant de prescrire une AURA de cette famille sur ce sigil en P1.
  Décision : si (bleed, ligne) < 0.3 → le palier bleed-4 ne peut pas prescrire clot_mender
    (aura bleed) comme arme principale sur le sigil ligne → ajouter une note dans la spec P1.
```

**Pourquoi** : la signature de The Pit (le graphe de synergies = la forme du plateau) ne
peut pas être ignorée au moment où on ajoute des synergies de TYPE. Les deux systèmes
interagissent. Connaître les saturations d'arêtes évite de créer des prescriptions P1
incompatibles avec l'archétype positionnel naturel d'une famille.

**Coût** : calcul combinatoire sur shapes.lua (~1 h, sans sim). Ne touche pas le code.

### P4 — Nommer un candidat poison-4 dans la spec P1 [PRIORITÉ FAIBLE mais COMPLÉTUDE]

**Quoi** : dans §5 (P1 types, brouillon v10), compléter le tableau des twists :

```
PALIER POISON-4 CANDIDAT (SPEC À PROUVER, simuler avant gravure) :
  poisonWeakenDeep : si ≥4 unités dot_family=="poison" dans le build →
    teamFlag {poisonWeakenPassif=true} activé au combat_start →
    le weaken s'applique à l'INT des passives adverses (auras "combat_start") avec un
    coefficient réduit (ex. 30 % de la magnitude weaken normale).
  Coût : ~5 lignes data + 1 op {on_hit: weaken_passif, factor=0.30}.
  Alignement #JJ : condition = composition du BUILD (4 poison), cause contrôlée.
  Garde-fou : weaken_passif ne s'applique PAS aux teamFlags de TYPE adverses (seulement aux
    auras build-résolues) → évite d'entrer dans une boucle d'interactions entre P1 des deux camps.
  Simulation : mesurer P90/P10 d'une compo poison-4 vs compo aura-lourde adverse.
```

**Pourquoi** : P1 doit être spécifiable SYMÉTRIQUEMENT pour les 5 familles. Un `[TBD]` pour
poison-4 laisse ouverte une spec qu'on devra fermer au début de l'implémentation — autant
la fermer maintenant pendant qu'on est en mode spec.

**Coût** : doc pur (~30 min). Simulation = P1 sim standard.

---

## 4. QUESTIONS OUVERTES

### Q1 : Le critère #JJ s'applique-t-il aux synergies d'ADJACENCE elles-mêmes, ou seulement aux payoffs actifs ?

Les synergies d'adjacence (l'aura buffe le voisin) sont build-résolues (bakées à combat_start
via shapes.lua). Leur condition de déclenchement = "avoir placé 2 unités côte à côte" =
décision de PLACEMENT contrôlée par le joueur. Verdict #JJ : FORT.

Mais les synergies de PROPAGATION au combat (`Arena:neighborsOf`, propagation au kill ou au
hit) ciblent les voisins de la CIBLE (la position adverse). En async, le joueur ne contrôle
pas la disposition adverse. Ce sont des synergies dont la condition de propagation est
PARTIELLEMENT hors contrôle. #JJ s'applique-t-il à ces propagations ?

La réponse de la roadmap actuelle (burn propage aux voisins à la mort, on_death différé,
00-state §3.1) ne distingue pas les deux : "propagation en combat = proximité du champ de
bataille (Arena:neighborsOf), SIM autonome". Ce choix est pragmatique mais crée une tension
avec #JJ. À documenter dans §10 (liste des garde-fous) plutôt qu'à modifier (le mécanisme
est acté et cohérent — on note juste la limite #JJ de la propagation combative).

### Q2 : La directionnalité de #FF (#II) peut-elle être tranchée maintenant par le critère #JJ ?

Option A (directionnelle, ordre fixe) : "burn amplifie rot mais rot n'amplifie pas burn".
- Condition #JJ pour le joueur burn : son burn active le more sur rot adverse → la condition
  dépend de la PRÉSENCE de rot adverse, hors contrôle. #JJ : PARTIEL.
- Condition #JJ pour le joueur rot : son rot n'active rien → le more croisé est mort pour lui.

Option B (symétrique, 2 passes) : les 2 familles co-présentes s'amplifient mutuellement.
- La condition = avoir posé les 2 familles dans son BUILD → #JJ : FORT.

Le critère #JJ favorise Option B. Mais Option B exige ~5 lignes SIM + rebaseline golden
potentielle (invariant #5). C'est la seule modification SIM de toute la spec #FF.

**Recommandation** : appliquer #JJ → Option B. Documenter la rebaseline potential comme
garde-fou explicite (le golden doit être relu avant le code, pas après). C'est une décision
qui peut clore #II maintenant.

### Q3 : La précondition de lisibilité (avg_events/tick) devrait-elle être mesurée AVANT le test 14 aura×palier ou après ?

Le test 14 vérifie l'additivité `increased` en SIM headless (0 VFX). La mesure
`combat_effect_legibility` porte sur le RENDER (bus JSONL → arène en train de combattre).
Les deux sont indépendants. Réponse : mesurer après — le test 14 peut être codé maintenant
(zone sans test, P1), la métrique de lisibilité est une précondition du RENDER de #FF,
pas du test d'architecture SIM.

### Q4 : Comment la saturation des arêtes interagit-elle avec le système de boucliers ?

Les boucliers (`shield_aura`, 6 porteurs) sont des auras d'ADJACENCE (build-résolues). Leur
valeur dépend donc aussi de la saturation des arêtes. Un porteur de bouclier sur le sigil
`croix` (4 arêtes max) ne protège que son noyau (1 voisin si isolé, 2 si en centre). Ce
n'est pas un problème, c'est une décision de placement que la carte de risque (§2.2) doit
rendre visible. Le tableau de saturation des arêtes (P3 ci-dessus) devrait inclure une
colonne "saturation_shield" pour les 6 porteurs.

---

## 5. ACCORDS NON RE-CHALLENGÉS

- **Compteur de type GLOBAL PUR (#D clos round 6)** : accord ferme, non re-challengé.
- **Burn-vulnérabilité-bouclier = intentionnel (#W clos round 6)** : accord ferme.
- **`bleedPierceShield` twist bleed-4 + tests 2a/2b** : adopté r07, non re-challengé.
- **`famines_math` tri stable (clé secondaire `id`)** : code-vérifié r07.
- **12 synergies de base (tests/synergies.lua, invariants #22-32)** : plancher sain.
- **`DOT_CAP_MULT=3` anti-snowball** : cap essentiel pour rendre les interactions #FF safe
  (confirmé par Kritz & Gaina 2025 : caps réduisent la saturation inter-ensemble).
- **Architecture `grant_team` / `teamFlags`** : technique juste.
- **Axe D choc (`dot_family` du poseur + fallback ordre fixe)** : correct en PRINCIPE,
  problème de fiabilité isolé par CONFIG-CE2 (adopté).
- **Seuils 2/4 sur 9 slots** : accord fort.
- **`plague_communion` re-tranché (#J final)** : `dot_family_count ≥ 2 du BUILD` —
  aligné #JJ, accord complet.

---

## 6. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée | Priorité |
|---|---|---|---|---|
| CONFIG-CE2 sans critère de tranchage (Option A vs B) | **FORTE** | La mesure existe, la décision n'est pas liée — reste bloquée | Ajouter critère #JJ : Option A par défaut (auto-DoT, condition contrôlée) | HAUTE |
| Candidats #HH non évalués selon #JJ — Option B supérieure mais non documentée | **FORTE** | #GG non tranchable sans évaluation #JJ de choc-4 ; Option B clôt #HH maintenant | Tableau #JJ des deux options → trancher Option B, libérer #GG | HAUTE |
| Tableau de saturation des ARÊTES absent (signature The Pit jamais mesurée) | **MOYENNE** | P1 peut créer des prescriptions incompatibles avec l'archi positionnelle | Calculer saturation arêtes par sigil × famille avant de figer spec P1 | MOYENNE |
| Poison-4 sans candidat twist nommé (spec P1 à 4/5 familles) | **FAIBLE** | Spec asymétrique ; P1 incomplet au codage | Nommer `poisonWeakenDeep` comme SPEC À PROUVER | FAIBLE |
| Batching #FF doit distinguer ticks HOMOGÈNES vs ticks MODIFIÉS par #FF | **FAIBLE** | Sans distinction, le batching aplanit exactement ce que #FF ajoute | Enrichir la spec de batching §5.4 d'une colonne "type de signal" | FAIBLE |

**Litiges pouvant être clos par ce round** :
- **#II (directionnalité #FF)** : Option B (symétrique 2 passes) favorisée par #JJ →
  recommandation de clôture, à décision user.
- **#HH (palier choc-4)** : Option B (tickCount=2) aligne #JJ et est compatible avec les
  deux axes de #GG → peut être tranché MAINTENANT, indépendamment de #GG.

**Litiges restant ouverts** : #GG (apex choc axe A/B vs D), #FF (spec à prouver,
préconditions actées), #U (cible Contrainte de Saison), #B (saturation inc + interactions).

---

## 7. Index des sources

**Web vérifié ce round :**

- PoE Wiki — Shock (non-damaging ailment, conditionnal DoT amplification, stacking) :
  [poewiki.net/wiki/Shock](https://www.poewiki.net/wiki/Shocked)
- PoE Wiki — Ailment (interactions, Lightning Exposure comme solution auto-conditionnelle) :
  [poewiki.net/wiki/Ailment](https://www.poewiki.net/wiki/Ailment)
- Mobalytics PoE 2 — Shock Explained (increased damage taken additive, non-stacking) :
  [mobalytics.gg/poe-2/guides/shock](https://mobalytics.gg/poe-2/guides/shock)
- Red Hare Games — Why have Status Effects (fiabilité = engagement ; unreliable effects = frustration) :
  [redharegames.wordpress.com/2025/11/17/simple-article-why-have-status-effects-in-games/](https://redharegames.wordpress.com/2025/11/17/simple-article-why-have-status-effects-in-games/)
- Balatro Wiki — Jokers (conditions sous contrôle joueur vs contexte externe) :
  [balatrowiki.org/w/Jokers](https://balatrowiki.org/w/Jokers)
- Kritz & Gaina 2025 — "When 1+1 does not equal 2: Synergy in games" (intra/inter-ensemble,
  saturation risk, caps anti-saturation) :
  [arxiv.org/html/2502.10304v1](https://arxiv.org/html/2502.10304v1)
- Accessible Game Design — Status Effects Guidelines (priorité d'affichage, simultanéité) :
  [accessiblegamedesign.com/guidelines/statuseffects.html](https://www.accessiblegamedesign.com/guidelines/statuseffects.html)
- Game Wisdom — Asymmetrical Game Design (payoff horizon asymétrique = perte early) :
  [game-wisdom.com/critical/asymmetrical-game-design](https://game-wisdom.com/critical/asymmetrical-game-design)

**Sources internes (références actives, lecture seule) :**

- `00-state.md` §2.1/§3.1/§3.2/§3.3/§7/§8
- `ROADMAP-draft.md` v10 §0 (diff R09) / §3.7 (CONFIG-CE2) / §5 (P1 types)
- `round-09.md` §1.0 (#JJ) / §3.2 (#HH) / §3.3 (CONFIG-CE2) / §3.4 (#II)
- `rounds/r09-synergies-effects.md` §2.3 (fiabilité choc) / §2.4 (directionnalité #FF) /
  §Q3 (poison-4 absent)

---

## 8. Récapitulatif des demandes de modification de specs

| Item | Position ce round | Priorité | Où dans la roadmap |
|---|---|---|---|
| Critère de tranchage CONFIG-CE2 (Option A par défaut, #JJ) | **REQUIERT ADDITION** §3.7 | HAUTE | avant P0.5 |
| Évaluation #JJ des options #HH choc-4 → Option B recommandée → #HH clôturable | **REQUIERT ADDITION** §3.7 + §5 | HAUTE | avant P1 |
| Tableau de saturation des arêtes (sigil × famille × slots) | **REQUIERT ADDITION** §5 préconditions | MOYENNE | avant spec P1 |
| Candidat poison-4 `poisonWeakenDeep` (SPEC À PROUVER) | **REQUIERT ADDITION** §5 tableau twists | FAIBLE | avant codage P1 |
| Spec de batching §5.4 : distinguer ticks homogènes vs ticks modifiés (#FF) | **REQUIERT PRÉCISION** §5.4 | FAIBLE | avant codage #FF |
| Directionnalité #FF (#II) → Option B (symétrique) favorisée par #JJ → clôturable | **REQUIERT DÉCISION** §5 spec #FF | FAIBLE | avant test #FF |

---

*Round 10 rédigé le 2026-06-23. Round FINAL (10/10). Lecture seule du repo. N'édite que sous
`docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe seedée / DA grimdark /
pixel art procédural). 32 invariants préservés. Désaccords principaux : (1) CONFIG-CE2 sans critère
de tranchage — Option A par défaut (#JJ) ; (2) candidats #HH non filtrés par #JJ — Option B clôt
#HH maintenant ; (3) saturation des ARÊTES jamais mesurée (angle mort de 10 rounds sur la
SIGNATURE du jeu). 2 litiges pouvant être clos (#HH, #II via #JJ). 0 modification du code, 0
modification des tests. Destiné à alimenter la ROADMAP.md finale.*
