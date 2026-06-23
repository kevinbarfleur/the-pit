# Round 04 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 4/10 — challenge du brouillon v4 (`ROADMAP-draft.md`) et des
> synthèses rounds 1-3 (`round-01.md`, `round-02.md`, `round-03.md`). Ce round lit
> le code frais pour valider ou infirmer les hypothèses du round précédent.
>
> **Inputs lus** :
> - `BRIEF.md`, `ROADMAP-draft.md` v4, `00-state.md`
> - `round-01.md`, `round-02.md`, `round-03.md`
> - `rounds/r01-synergies-effects.md`, `rounds/r02-synergies-effects.md`, `rounds/r03-synergies-effects.md`
> - `src/combat/arena.lua:320-545` (tickDots complet, dischargeShock, shock tick)
> - `src/effects/ops.lua:1-82` (DOT_CAP_MULT, ampDps, ops de base)
> - `src/data/units.lua:1-380` (roster complet, familles T1/T2/T3, choc, boucliers)
> - `src/data/relics.lua:1-80` (pool de reliques complet)
>
> **Recherche web menée** :
> - TFT synergy threshold design (tactics.tools, mobalytics.gg, medium.com/@ZiberBugs)
> - PoE Damage over Time wiki (poewiki.net/wiki/Damage_over_time, poewiki.net/wiki/Poison)
> - StS metrics-driven balance (gamedeveloper.com, gdcvault.com GDC 2019 Giovannetti PDF)
> - Autobattler adjacency vs global synergy (ilogos.biz, ithy.com)
>
> **Garde-fous** : lecture seule du repo + web ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers async/déterministe/grimdark/procédural respectés.
> Ne modifie ni le code, ni les tests.

---

## 0. Angle d'attaque de ce round

Le round 3 a tranché deux questions clés sur cette lentille : **l'axe D (décharge sur le
1er tick DoT)** et **le `dot_family` comme champ porteur du compteur de types**. Ce round
ne re-litigue pas ces décisions — elles sont correctes et bien fondées dans le code.

Il s'attaque à **ce qui reste fragile ou non-résolu après le round 3** :

1. **L'axe D a un bug d'identité non signalé** : avec l'ordre tick `burn→bleed→poison→rot`,
   le choc amplifie TOUJOURS le burn s'il est présent — ce qui crée une synergie implicite
   choc×burn **plus forte que** choc×poison sans que personne ne l'ait nommée ou choisie.
2. **La cause racine de `poison > choc` n'est pas entièrement résolue par l'axe D** :
   le round 3 le note en drapeau P3 mais sous-estime à quel point la propagation à la mort
   est sur-puissante structurellement, pas uniquement paramétriquement.
3. **Le compteur de types GLOBAL (P1) est insuffisant seul** sur le plateau-graphe 3×3 :
   le critère de bascule vers l'adjacence-type (critère P3, variance positionnelle) est
   correct mais déplacé chronologiquement — il doit être évalué AVANT que P1 soit codé,
   pas après.
4. **La relique `plague_communion` telle que codée (v4 §4.2)** — « +5 %/allié de
   l'affliction majoritaire » — crée une inégalité structurelle : poison peut atteindre
   6+ alliés de la famille majoritaire (festering + cap levé), ce qui rend son amplification
   disproportionnée par rapport aux autres familles dont l'axe est moins « go-wide ».
5. **Les boucliers périodiques et le bouclier statique partagent le même pool d'arêtes**
   sur le sigil carré, créant une pression d'adjacence double qui écrase les DoT si mal
   positionnés — interaction non testée et non couverte par le golden.

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 Axe D (décharge sur le 1er tick DoT dans `tickDots`) — ACCORD FORT, NUANCE IMPORTANTE

L'axe D est la bonne décision. Le code le confirme (`arena.lua:520-526`) : le tick du
choc actuel dans `tickDots` n'inflige RIEN — il écoule la durée et dissipe la charge
non-déchargée. L'axe D réécrit ce bloc pour appliquer un `more` au premier tick DoT
présent avant de consommer les stacks. Zéro conflit d'ordre avec `hit()` (confirmé
`arena.lua:330`). C'est architecturalement propre.

**Pourquoi ça tient dans NOS contraintes :**
- Déterministe : l'ordre `burn→bleed→poison→rot` est fixe et documenté. L'ampli touche
  toujours la **première famille présente** dans cet ordre — prévisible par le joueur.
- Async : la décharge est résolue dans la SIM, déjà capturable par le bus (`bus:emit`
  déjà utilisé pour `amped`, `spread` — `ops.lua:67-68`, `arena.lua:378`). Aucun impact
  sur le snapshot.
- Déontologie de code : la réécriture est localisée dans `tickDots`, le seul bloc
  « ouvert » reconnu qui connaît les familles (commentaire `arena.lua:395-396`).

**NUANCE CRITIQUE non formulée dans le brouillon v4** : voir §2.1 (bug d'identité choc×burn).

### 1.2 `dot_family` comme champ porteur, lint dans `check.sh` — ACCORD FORT

La règle « `dot_family = op du 1er effet DoT non-aura` » est la bonne convention.
Vérification code : `galvanizer` (`units.lua:311`) a `bonus_first + shock` — son
`dot_family` serait `choc` (shock est son DoT principal, bonus_first est une stat).
`leech_thorn` (`units.lua:113`) a `bleed + thorns` — son `dot_family` serait `bleed`
(thorns est défensif). La règle est appliquable ligne à ligne, sans ambiguïté sur les
cas réels du roster.

Le lint `check.sh` (5 lignes luacheck) est un garde-fou nécessaire et suffisant : il
empêche un oubli de renseignement. Coût ~0, impact fort.

### 1.3 Cap ×3 anti-snowball sur l'output, pas sur l'`increased` total — ACCORD avec une vérification de cas limite

La formule `(base + Σflat)(1 + Σincreased) * Π(more)` bornée par `DOT_CAP_MULT = 3`
(`ops.lua:22`) protège contre l'escalade multiplicative. Vérifié `ampDps` (`ops.lua:29-32`)
: `Stats.resolve(base, mods, {max = base * 3})` — le plafond est bien sur l'output.

**Vérification d'un cas limite réel** : `kings_bowl` (`relics.lua:26`) donne
`poisonInc = 0.20`. Une aura `miasma_acolyte` (`units.lua:156`) donne `poisonInc += 0.5`
aux voisins. Palier type poison +20 % (P1 [PH]). Total `increased = 0.20 + 0.50 + 0.20
= 0.90`. `base dps = 2` (witch) → `2 × 1.90 = 3.8 → floor = 3`. Cap = `2 × 3 = 6`.
**Le cap ne sature pas ici** — il entre en jeu à `increased ≥ 2.0` pour `base = 2`.
Conclusion : le cap est une protection réelle, pas un plancher artificiel, et la combinaison
relique B + aura + palier type **reste en-dessous du cap dans les cas communs**. En revanche,
un `more` de palier type non borné séparément (litige #B du brouillon) pourrait multiplier
`3.8 × 1.30 = 4.94` — au-dessus du cap. La spécification « twist = `more` borné séparément »
du brouillon v4 §5.2 est donc **indispensable et correctement identifiée**.

### 1.4 Seuils 2/4 (pas 6) — ACCORD FORT, justification mécaniste réaffirmée

La vraie contrainte n'est pas la taille du plateau vs TFT, mais l'**optimum de diversité**
(r03-synergies-effects.md §1.4, confirmé). Vérification avec le roster actuel : 5 familles
DoT + tank/shield (~11 unités). Sur 9 slots max, un palier-4 d'une famille consomme 4 slots,
laissant 5 pour le reste. Un palier-6 consommerait 6/9 = 67 % de la compo pour une seule
famille → pas de place pour un tank (gravewarden, aggro=40, taunt=true) → front vulnérable
→ ciblage déterministe colonne 1 détruit la carry DoT immédiatement. Le seuil 4 **est déjà
la limite économique du plateau** : on peut tenir 2 familles à 2 (et 5 slots libres) ou 1
famille à 4 (et 5 slots libres). Les seuils 2/4 sont donc intrinsèquement corrects pour ce
roster et ce plateau.

Source confirmée : « a player who commits to one trait sacrifices defensive diversity »
(gangles.ca/2024/07/07/balatro-auto-chess/ — déjà cité r03) reste pertinent. TFT Set 17
(mobalytics.gg/tft/synergies/classes) montre que les traits à seuil 2/4 sont les plus
répandus dans les compos viables parce qu'ils permettent le « flex » (deux traits actifs
simultanément) — exactement notre optimum cible.

### 1.5 Architecture `grant_team` + `teamFlags` pour les paliers — ACCORD TECHNIQUE CONFIRMÉ

`grant_team` posant des `teamFlags` à `combat_start` est la bonne mécanique. Vérifié dans
`units.lua` : `ash_maw` (`l.231-237`), `festering` (`l.261-265`), `pit_maw` (`l.273-278`)
utilisent tous ce pattern. Les paliers de type suivront le même chemin — **0 nouvelle
mécanique moteur**. Les `teamFlags` sont lus conditionnellement dans `tickDots` et `ops.lua`
(exemples : `burnNoDecay` `l.423`, `poisonNoCap` `l.65`) — pattern éprouvé, golden-safe si
le count `dot_family` est 0 quand la build ne contient pas la famille.

---

## 2. DESACCORDS — ce qui est faible, faux ou non étayé, avec vérification dans le code

### 2.1 DESACCORD FORT : L'axe D crée une synergie implicite choc×burn non choisie et non nommée

**Ce que le brouillon v4 ne dit pas** (§3.4, litige #G) : avec l'ordre tick
`burn→bleed→poison→rot` (fixe, `arena.lua:395-530`) et l'axe D qui amplifie le **premier
tick DoT présent**, le choc devient **systématiquement un amplificateur de burn en présence
de burn** — quelle que soit la composition du joueur.

**Pourquoi c'est problématique :**

Scénario typique : un joueur monte un build poison (4 unités poison + 2 choc). Sa cible
reçoit un bleed d'une unité adversaire (via contagion ou rencontre IA). Dès que burn ou
bleed sont présents sur la cible, les stacks de choc amplifient burn/bleed EN PREMIER,
pas poison. La synergie que le joueur perçoit est « j'ai du choc pour amplifier mon poison »
mais ce que fait réellement l'axe D est « le choc amplifie la première affliction posée
dans l'ordre fixe ». La frustration résultante est exactement du type Artifact : « je n'ai
pas compris pourquoi mon combo n'a pas fonctionné » (postmortems §4.4 cité dans le brouillon).

**Ce que le brouillon dit** : « le 1er tick présent est **prédictible** » (§3.4, AXE D) —
ce qui est vrai du point de vue SIM, mais ne devient « lisible par le joueur » que si l'UI
communique quelle famille sera amplifiée. Un joueur qui regarde son plateau (4 unités poison)
n'a aucune raison de savoir qu'un bleed adverse changera la cible de l'amplification.

**Proposition de remède** (§3, P1) : l'axe D doit être **assorti d'un signal UI**
obligatoire : l'événement bus `shock_amplify {source, magnitude, famille}` (déjà proposé
dans le brouillon, §3.4) DOIT être rendu visible en combat (icône/couleur « choc a amplifié
poison », pas juste dans le log JSONL). Sinon l'axe D crée une profondeur invisible — ce
qui est pire qu'une profondeur absente (le joueur ne sait pas ce qu'il rate).

**Question ouverte (Q1, nouvelle)** : faut-il que l'axe D amplifie spécifiquement la famille
`dot_family` de l'unité choc (ou de la cible dominante), et non la première dans l'ordre
fixe ? Cela compliquerait l'implémentation (lecture de `unit.dot_family` en combat) mais
rendrait la promesse de design « choc amplifie le DoT de ton choix » réelle. À trancher en
design **avant** la sim.

### 2.2 DESACCORD MODÉRÉ : La cause racine de `poison > choc` est structurelle et l'axe D n'y change presque rien

Le brouillon v4 (§7.1) nomme correctement la cause structurelle : « poison a **3 axes
orthogonaux** auto-suffisants (stacks + weaken + propagation-mort) ; le choc-D n'en a que
**2 séquentiels** ». Mais il le classe comme un **drapeau P3** (après l'implémentation du
choc en P0.5 et des types en P1). C'est trop tard, et la démonstration est insuffisante.

**Preuve par le code (lecture directe `ops.lua` + `units.lua`)** :

1. **L'axe propagation-mort est l'axe dominant de poison.** `spread_on_death` (impliqué
   par `plague_bearer:spread`, `festering:poisonNoCap`) : quand une cible poisonnée meurt,
   ses stacks se propagent à ses voisins (`arena:neighborsOf`, `ops.lua` contagion). Avec
   `festering` actif (`poisonNoCap = true`), une cible peut accumuler >8 stacks, mourir, et
   propager >8 stacks à plusieurs voisins → **cascade auto-amplifiante** que NI le cap ×3
   NI l'axe choc-D ne plafonnent directement (`festering` lève le cap de stacks, pas le cap
   d'output — `poisonNoCap` dans `ops.lua:65`).

2. **La propagation à 100 % des stacks n'est pas indiquée comme intentionnelle** dans le
   code. `plague_bearer` (`units.lua:200-203`) : `spread = { dps = 1, dur = 120 }` — c'est
   un spread à **dps réduit** (50 % du stack source). Mais les transforms T3 (`festering`,
   `venom_censer`) ne capent pas la propagation explicitement. Le drapeau `poisonNoCap`
   lève le cap de *stacks*, pas de propagation. La question du round 3 (Q4 `r03-synergies-
   effects.md §4`) — « `p.frac` ou valeur fixée ? » — reste sans réponse dans le brouillon v4.

3. **L'axe D ne touche pas la propagation.** Il amplifie un tick unique par cible choquée.
   Il n'empêche pas la cascade poison → mort → propagation. Le choc-D résout la lisibilité
   du choc, pas la hiérarchie inter-familles.

**Ce que le brouillon préconise (§7.1, drapeau entropie poison)** : mesurer
`win_rate(poison) vs pool` et si `> +1σ` → levier `contagion` à 50 % des stacks. C'est la
bonne action, **mais la déclasser en P3 est une erreur**. Si poison est structurellement
dominant, les types P1 amplifieront une hiérarchie cassée : un palier poison +20 % sur une
famille déjà +1σ crée une méta résolue avant le ranked (P2). Le problème doit être mesuré
AVANT P1, pas après.

**Recommandation chiffrée** : dans la sim P0.5, ajouter un flag `--poison-frac` qui teste
`contagion = 0.50` (la moitié des stacks du mort propagés, pas 100 %) sur N=200 combats.
Si `win_rate(poison)` descend de `> +1σ` à `< +0.5σ` → activer le correctif AVANT
d'implémenter les paliers de type. Coût : 1 paramètre data dans `ops.lua` (`frac=p.frac or
1.0` dans l'op contagion), sim headless, 0 invariant. **À planifier en P0.5, pas P3.**

### 2.3 DESACCORD MODÉRÉ : Le critère de bascule global → adjacence-type (litige #D) est déplacé chronologiquement

Le brouillon v4 (§5.2) adopte le compteur **global** en v0.10 et se réserve la bascule
vers l'adjacence-type en v0.12 sur critère `variance(win%) sur permutations positionnelles
> 0.05`. Ce critère (proposé par le round 3, adopté dans r03-synergies-effects.md §2.2)
est mécanistement correct mais **à calculer AVANT P1**, pas après.

**Raison** : les permutations positionnelles exigent un plateau avec des unités placées et
un sigil actif. La variance de win% sur permutations dépend **du nombre d'arêtes actives**
(qui varie selon le sigil) et **de la taille de l'équipe** (4 vs 9 slots). Si on mesure
la variance positionnelle sur les builds T2-T3 (au milieu de P0.5/P1), on dispose déjà
de la donnée nécessaire pour décider le design de P1 AVANT de le coder.

**Ce qui peut être fait dès P0.5 (0 code moteur)** : dans `tools/sim.lua` (existant),
ajouter un flag `--position-variance` qui, pour chaque compo de test, fait tourner les
mêmes unités avec des positions permutées (3 permutations = 3 seeds positionnelles
identiques) et mesure `std_dev(win%)` par permutation. Si `> 0.05` sur les sigils
non-carré (anneau, diamant) → l'adjacence-type mérite d'être intégrée à P1 directement,
pas rétrofittée en v0.12.

**Le risque concret** : si le compteur global est codé en v0.10 et la mesure montre en
v0.12 que la variance positionnelle est forte, **refondre le compteur en v0.12 touche
les tests P1 déjà écrits** (les tests type ×2 paliers de P1 supposent un compteur global).
C'est une dette potentielle évitable.

### 2.4 DESACCORD MODÉRÉ : `plague_communion` scalante (§4.2) crée une inégalité inter-familles

Le brouillon v4 tranche le litige #J vers « scalante » : `+5 % / allié de l'affliction
majoritaire ». C'est bien meilleur qu'un gate, **mais l'implémentation proposée
(majoritaire = nombre d'unités) avantage structurellement poison**.

**Preuve par le code** :
- `festering` (`units.lua:260-266`) : `poisonNoCap = true` + `poisonDurBonus = 60`. Une
  compo 6 poison + festering = 6 unités poison majoritaires → `plagueAmp = 0.05 × 6 = 30%`.
- `ash_maw` (`units.lua:231-237`) : `burnNoDecay = true`. Une compo 6 burn + ash_maw = 6
  unités burn → `plagueAmp = 0.05 × 6 = 30 %`. Même valeur **en théorie**.
- **Mais** : burn range de 12 unités dans le roster (burn T1/T2/T3 inclus), poison de 15,
  bleed de 12, rot de 11. Pas d'inégalité sur la quantité par famille... **si et seulement
  si** le pool boutique est équilibré. Avec le pool actuel (potentiellement 6+ rang-2 poison
  après vague v7), atteindre 6 unités poison est plus facile qu'atteindre 6 rot (rot rang-2
  = 2-3 enablers après nettoyage).
- **Le vrai problème** : « affliction majoritaire » en nombre est différent de « affliction
  dominante en DPS ». Un build 3 poison + 3 burn + 3 rot → `plagueAmp` récompense le
  premier à 3 — souvent poison (famille la plus représentée en pool rank-2). Cela amplifie
  la hiérarchie actuelle au lieu de l'égaliser.

**Remède** : soit (a) formuler `plague_communion` sur la famille qui a le plus d'unités en
**boutique actuelle** (plus de variance) soit (b) **fixer un plafond par famille à 4**
(pas 6) dans `plagueAmp` : `min(4, count) × 5%` = max +20 %, quelque soit la famille.
Option (b) simple à implémenter dans `grant_team` (le paramètre `plagueAmp` devient une
valeur fixed `min(4, count) × 0.05`). Option (b) est **alignée avec le plafond de palier 4
de P1** — cohérence de design.

Source : PoE resist-the-lazy-approach — « les amplis plafonnés par archétype évitent que la
famille dominante absorbe les multiplicateurs universels »
(poewiki.net/wiki/Damage_over_time §Amplification, vérifié).

### 2.5 DESACCORD FAIBLE MAIS PRÉCIS : La hiérarchie burn/bleed vs poison/rot dans l'axe D est un enjeu de feel, pas juste de balance

Le round 3 (r03-synergies-effects.md §2.5) note que poison a 3 axes orthogonaux, choc 2
séquentiels. Il ne nomme pas l'asymétrie symétrique entre burn et bleed vs poison et rot.

**Vérification code** :
- Burn : ignore le bouclier **non** (`arena.lua:430-433` : `self:damage(u, n, { cause =
  "burn" })` — pas d'`ignoreShield`). Burn lèche le bouclier en premier.
- Bleed, Poison, Rot : ignorent le bouclier (`ignoreShield = true`, confirmé `arena.lua:
  442`, `466`, `498`).

L'axe D, s'il amplifie le burn en présence de burn, amplifie un DoT **bloqué par les
boucliers**. En présence de tanks avec `shield_aura` ou `shield_caster`, l'ampli choc-D
est partiellement ou totalement absorbée par le bouclier (comme la décharge actuelle
axe A/B, confirmé `arena.lua:349` — `ignoreShield=true` sur la décharge mais pas sur
burn en tickDots). C'est précisément ce que la Config D (sim P0.5) doit tester, et le
brouillon l'a bien intégré (§3.4). Mais il y a une subtilité non formulée : si le choc
amplifie un tick de burn sur une cible bouclée, **une partie de l'ampli est perdue** dans
le bouclier (burn n'ignore pas le bouclier). En revanche, si le choc amplifie bleed/poison/
rot, l'ampli est entièrement infligée (ignore le bouclier). Cela crée un **feel différent**
selon la composition ennemie, que la sim doit capturer.

**Recommandation** : dans la Config D (choc vs tank/bouclier), mesurer séparément :
- win% quand l'ampli D touche un **tick burn** (bouclier absorbe partiellement)
- win% quand l'ampli D touche un **tick bleed/poison/rot** (bouclier ignoré)

Ce n'est pas 0 code — c'est une métrique de sim supplémentaire (~2 lignes dans
`tools/sim.lua`). Permet de décider si l'ordre tick `burn→bleed→...` crée un désavantage
tactique voulu ou accidentel contre les défenses bouclier.

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Signal UI obligatoire pour l'axe D : quelle famille est amplifiée [HAUTE PRIORITÉ, P0.5]

**Quoi** : lors de l'émission de `shock_amplify {source, magnitude, famille}` dans `tickDots`
(axe D), `arena_draw.lua` doit afficher un **indicateur de la famille amplifiée** pendant le
combat — par exemple une couleur ou un icône sur l'unité choquée : jaune=burn, rouge=bleed,
vert=poison, brun=rot. Ce n'est pas de la décoration — c'est la condition nécessaire pour
que « choc amplifie le DoT » soit une décision de build compréhensible, pas un effet opaque.

**Pourquoi AVANT la sim** : si on mesure la Config A/B/D sans cet indicateur, on obtient
des win% corrects mais on ne peut pas diagnostiquer si les pertes viennent de l'axe ou de la
famille amplifiée par accident (§2.1). L'indicateur UI est le lien entre la sim et la
compréhension du joueur.

**Garde-fou** : RENDER uniquement (`arena_draw.lua`), écoute du bus, 0 SIM. Zone sans test
existant → ajouter un test que `shock_amplify` est émis avec la bonne famille sur un golden
connu (couvert par le rebaseline du golden P0.5).

**Source design** : « la lisibilité de l'échec retient les joueurs 0-5 wins plus que la
célébration de la victoire » (round-03.md §1.10, retention §2.4) — le même principe
s'applique à la compréhension en combat.

### P2 — Mesurer l'entropie poison AVANT P1, pas en précondition P3 [HAUTE PRIORITÉ, P0.5]

**Quoi** : dans `tools/sim.lua`, ajouter un flag `--poison-frac <f>` qui teste l'op
`contagion` (propagation à la mort) avec `frac = f` (défaut actuel = 1.0 = 100 % des stacks
propagés). Mesurer sur N=200 : `win_rate(poison)` vs `win_rate(pool moyen)`. Si le delta
est `> +1σ` à `frac=1.0` et `< +0.5σ` à `frac=0.5` → activer le correctif **avant P1**.

**Chiffre concret** : `frac=0.5` = 50 % des stacks propagés = 4 stacks propagés si la
cible avait 8 stacks (cap normal). Sur un combat avec `festering` (cap levé), cela passe
de « propagation illimitée » à « propagation bornée à 50 % de l'illimité ». C'est le levier
data le plus simple et le plus chirurgical pour corriger la cause structurelle.

**Pourquoi AVANT P1** : si les types P1 sont implémentés sur une hiérarchie cassée (poison
dominant), le drapeau `--meta-convergence` (§7.1 roadmap v4) risque de déclencher le
séquençage types-d'abord (#A) mais en amplifiant une méta déjà résolue. On élimine la
variable de confusion.

**Garde-fou** : paramètre data dans `ops.lua` (`frac = p.frac or 1.0` dans la contagion).
Uniquement dans la sim headless (N=200, seed fixe). Commit du paramètre uniquement si la
sim le valide. **Golden inchangé si la valeur par défaut est 1.0** (comportement actuel
préservé).

### P3 — Mesurer la variance positionnelle (critère litige #D) dès P0.5, pas P3 [PRIORITÉ MOYENNE, P0.5]

**Quoi** : dans `tools/sim.lua`, ajouter `--position-variance` : pour chaque compo de test,
permuter les positions des unités (3 permutations distinctes par build, seed fixe) et
mesurer `std_dev(win%)` sur les permutations. Si `> 0.05` sur les sigils anneau/diamant
→ l'adjacence-type mérite d'être intégrée à P1 directement (pas rétrofittée en v0.12).

**Chiffre cible** : si `std_dev(win%) < 0.02` sur 3 sigils → le compteur global est
suffisant. Si `> 0.05` sur ≥1 sigil (vraisemblablement anneau ou ligne où la séquence
linéaire crée des adjacences naturelles par famille) → planifier le compteur adjacence-type
directement dans P1.

**Coût** : `tools/sim.lua` supporte déjà la configuration de builds et de sigils
(headless). Les permutations positionnelles = changer `units={{id,level,col,row}}` en
3 variantes. ~20 lignes de code sim.

**Impact** : évite potentiellement une refonte du compteur entre v0.10 et v0.12.

### P4 — Plafonner `plague_communion` à 4 unités de la famille majoritaire (alignement palier P1) [PRIORITÉ MOYENNE, P1.5a]

**Quoi** : dans `R.apply` (`relics.lua`), `plague_communion` calcule `plagueAmp = min(4,
count(famille_majoritaire)) × 0.05` au lieu de `count(famille_majoritaire) × 0.05`. Cap à
+20 % (comme le palier 4 d'un type P1 [PH]), quelle que soit la famille.

**Pourquoi** : alignement avec le design général « palier 4 = bonus de type » — la
relique ne doit pas récompenser au-delà de l'engagement de palier. `famines_math` a un
seuil dur à 3 unités (`max = 3`). `feeding_frenzy` a un cap à 6 kills (`cap = 6`). La
cohérence de bornage entre reliques E est un principe non écrit que `plague_communion` viole.

**Garde-fou** : data-only (relics.lua `params`). Aucun invariant touché. **Golden inchangé**
(plague_communion n'est pas dans le golden build actuel sauf si gated). Valeur à sim avant
commit (relics Q4 existant).

### P5 — Métriques d'ampli burn vs non-burn dans la Config D de la sim choc [PRIORITÉ BASSE, P0.5]

**Quoi** : dans la sim de la Config D (choc vs tank+bouclier), mesurer séparément le tick
amplifié selon que la famille amplifiée est burn (partiellement absorbé par le bouclier) ou
non-burn (ignore le bouclier). Métrique additionnelle `ampli_net_burn` vs `ampli_net_dot`.

**Coût** : ~2 lignes dans `tools/sim.lua` (comptage conditionnel sur l'événement
`shock_amplify.famille`). Aucune modification de la SIM.

**Impact** : permet de décider si la hiérarchie implicite `burn_ampli < dotignoreshield_ampli`
dans l'axe D est un contre gameplay voulu (avoir un shield-tank neutralise partiellement le
choc même en axe D) ou un bug de feel.

---

## 4. QUESTIONS OUVERTES (non résolues par ce round)

### Q1 : L'axe D doit-il cibler la famille `dot_family` du poseur de choc, ou la première présente dans l'ordre fixe ?

Si on veut que « choc amplifie le poison de ton build » soit vrai, il faut lire
`unit.dot_family` à la décharge et amplifier uniquement la famille correspondante. Cela
**rompt le déterminisme simple de l'ordre fixe** (le tick amplifié dépend de qui a posé
le choc) mais crée une promesse de design cohérente. La question est : préférer la
**prévisibilité de l'ordre fixe** (mais synergies parfois surprenantes) ou la **lisibilité
du design** (la famille du poseur est amplifiée, mais l'implémentation est plus complexe) ?
À trancher avant la spec de l'axe D.

### Q2 : `festering` + propagation à la mort = peut-on borner la propagation séparément du cap de stacks ?

`festering` lève `poisonNoCap` (cap de stacks) ET donne `poisonDurBonus = 60`. La
propagation à la mort (`spread_on_death`) est dans `ops.lua` comme un paramètre `frac` de
l'op. Est-ce que borner `frac = 0.5` dans l'op `contagion` suffit, ou faut-il aussi borner
la propagation des unités T3 séparément ? Les transforms T3 sont les seules unités avec
`poisonNoCap` — si on borne la propagation à 50 % des stacks (y compris les stacks >8 de
`festering`), le gameplay T3 reste distinctif (stacks illimités) mais la propagation devient
proportionnelle (50 % de 12 stacks = 6, versus 50 % de 8 = 4). La T3 garde son identité
sans dominer via la cascade.

### Q3 : Le bouclier périodique (`ward_weaver`, `barrier_savant`) est-il un contre du choc ou un anti-synergy accidentel ?

En axe D, le choc amplifie le premier tick DoT. Si le DoT amplifié est bleed/poison/rot
(ignore le bouclier), le bouclier périodique n'est PAS un contre du choc. **Mais** si le
DoT amplifié est burn (ne ignore pas le bouclier), le bouclier absorbe une partie de
l'ampli. Un build tank-bouclier + burn adverse crée un contre partiel de l'axe D. Est-ce
voulu ? La décision design précède la sim.

### Q4 : Les twists de palier 4 (P1) pour burn et bleed — comment éviter de vider les T2 existants ?

- `burn 4 = propagation en cours-de-vie` (brouillon §5.2) — `wildfire_hound` propage
  à la MORT (`units.lua:177`). La propagation en cours-de-vie est distincte → OK.
- `rot 4 = amputation sur HP final` — `necro_leech` a `maxHpFrac=0.35` (forte amputation).
  Que signifie « amputation sur HP final » vs `necro_leech` ? Si c'est une amplification
  de `maxHpFrac` pour l'équipe → vide potentiellement `necro_leech`. À vérifier en colonne
  F de l'audit P0.5 (brouillon §3.1).
- `poison 4 = axe autre que le slow` — le brouillon le note déjà (§5.2). Candidat : la
  propagation *active* (non à la mort) à 1 voisin au dépassement d'un seuil de stacks. Non-
  clone de `plague_bearer` (qui propage au hit, pas à seuil).

Ces spécifications doivent être produites AVANT le code P1, pas en même temps.

---

## 5. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée | Priorité |
|---|---|---|---|---|
| Axe D crée synergie choc×burn implicite (ordre fixe tick) | **FORTE** | Feel trompeur pour build poison, lisibilité en combat | Signal UI famille amplifiée ; Q1 sur ciblage famille | P0.5 |
| Cause racine `poison > pool` = structurelle, classée P3 trop tard | **FORTE** | Types P1 sur hiérarchie cassée = méta résolue | `--poison-frac 0.5` en sim P0.5, correctif avant P1 | P0.5 |
| Critère variance positionnelle (litige #D) déplacé en P3 | **MODÉRÉE** | Refonte compteur possible entre v0.10 et v0.12 | Mesurer `--position-variance` en P0.5 avant spec P1 | P0.5 |
| `plague_communion` scalante avantage poison (famille plus go-wide) | **MODÉRÉE** | Ampli inégale inter-familles = renforce hiérarchie | Cap `min(4, count) × 5%` — aligné palier P1 | P1.5a |
| Axe D sur burn (non-ignoreShield) vs non-burn (ignoreShield) : feel différent | **FAIBLE** | Désavantage non voulu contre build bouclier-burn | Métrique séparée burn vs dot dans Config D | P0.5 |

---

## 6. Ce qui N'EST PAS un désaccord (confirmations sourcées)

Ces points du brouillon v4 sur la lentille synergies-effects sont **corrects et ne méritent
pas d'être re-challengés** :

- **Axe C retiré** (réordonne `hit()`, vérifié `arena.lua:330`) — confirmé ce round.
- **Lint `dot_family` dans `check.sh`** — nécessaire et suffisant.
- **Seuils 2/4 sur 9 slots** — mécanistement fondé, pas une analogie TFT (confirmé §1.4).
- **Config D dans sim P0.5** (choc vs tank+bouclier) — correcte, intégrée.
- **`second_breath` non conditionné** — l'audit code (`relics.lua:47`, `R.apply:97-98`)
  confirme que c'est une relique universelle tier-3 ; ne pas la conditionner est correct.
- **Déprioritisation des reliques F** (dès maintenant, pas en attente du marchand) — la
  math hypergéométrique tient (`P(≥1 F parmi 3) ≈ 39 %`, confirmé §1.2 par calcul direct).
- **Plafond et plancher pour l'audit d'identité** (double critère ≤4 ET ≥2/famille) — la
  logique de visibilité (`P(famille visible/boutique T2) ≥ 40 %`) est solide.

---

## Index des sources

**Sources web vérifiées ce round :**

- TFT Set 17 synergies — seuils 2/4 dominants dans les compos viables, flex builds :
  [mobalytics.gg/tft/synergies/classes](https://mobalytics.gg/tft/synergies/classes)
- TFT design analysis (ZiberBugs Medium) — analyse des systèmes de synergie TFT :
  [medium.com/@ZiberBugs/game-design-analysis-teamfight-tactics-bc6eb5aafeff](https://medium.com/@ZiberBugs/game-design-analysis-teamfight-tactics-bc6eb5aafeff)
- PoE Damage over Time — bucket `increased`, cap, amplification :
  [poewiki.net/wiki/Damage_over_time](https://www.poewiki.net/wiki/Damage_over_time)
- PoE Poison — stacking, propagation, orthogonalité :
  [poewiki.net/wiki/Poison](https://www.poewiki.net/wiki/Poison)
- StS GDC 2019 Giovannetti — metrics-driven design, combos et synergies, 1 erreur =
  « trop de cartes pareilles » :
  [media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf)
- Balatro & auto-chess (gangles.ca) — diversité défensive, optimum de diversité :
  [gangles.ca/2024/07/07/balatro-auto-chess/](https://gangles.ca/2024/07/07/balatro-auto-chess/)
- Autobattler adjacency vs global synergy (ilogos.biz) :
  [ilogos.biz/auto-battler-game-development-guide/](https://ilogos.biz/auto-battler-game-development-guide/)
- StS Vulnerable — amplificateur séquentiel (précédent de l'axe D) :
  [slaythespire.wiki.gg/wiki/Vulnerable](https://slaythespire.wiki.gg/wiki/Vulnerable)

**Sources internes (code lu ce round, lecture seule) :**

- `src/combat/arena.lua:320-545` — ordre exact `hit()`, `tickDots` complet (burn/bleed/
  poison/rot/shock/regen), `dischargeShock`, `healPierceOn`. Confirmé :
  - `burn` dans `tickDots` : `self:damage(u, n, { cause = "burn" })` — **pas d'`ignoreShield`**
    (burn est absorbé par le bouclier ; `arena.lua:432`).
  - `bleed`, `poison`, `rot` : `{ ignoreShield = true }` (ignorent le bouclier ; lignes
    442, 466, 498).
  - `shock` dans `tickDots` : n'inflige rien (`l.520-526`), écoule la durée seulement.
    L'axe D s'insère ici proprement.
- `src/effects/ops.lua:1-82` — `DOT_CAP_MULT=3`, `BLEED_DPS_CAP=12`, `ampDps` (borne l'output).
  `poisonNoCap` lève le cap de **stacks**, pas l'output total. La cascade propagation×stacks
  illimités reste non bornée indirectement.
- `src/data/units.lua:60-380` — familles complètes T1/T2/T3, ladder choc (10 unités,
  `l.299-335`), boucliers statiques et périodiques (`l.339-380`). Confirmé : `galvanizer`
  a `bonus_first + shock` → `dot_family = choc` (règle applicable).
- `src/data/relics.lua:1-80` — `plague_communion` (`l.57-58`) : `plagueAmp = 0.25` fixe
  (pas scalant). **Note : le brouillon v4 §4.2 propose de le rendre scalant** mais le code
  actuel ne l'est PAS encore — la proposition est dans le roadmap, pas dans le repo. Aucune
  confusion : c'est un TODO P1.5a, pas une dette cachée.

**Sources rounds précédents conservées :**

- r03-synergies-effects.md (lentille round 3) : axe D proposé, critère #D corrigé, garde-
  fou twist ≠ T2.
- round-03.md §1.1/1.2/1.3 (synthèse round 3) : adoptions confirmées ce round par le code.
- r01-synergies-effects.md §1.4, r02-synergies-effects.md §2.1 : seuils 2/4 et hiérarchie
  poison, confirmés mais approfondis ce round.

---

*Round 04 rédigé le 2026-06-23. Lecture seule du repo (code cité avec lignes). N'édite que
sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants préservés (toute modif axe D
implique rebaseline golden — signalé §2.1 ; correctif `frac` contagion = paramètre data,
golden inchangé si défaut 1.0 préservé). Litiges enrichis : Q1 (famille ciblée par axe D :
ordre fixe vs dot_family du poseur) ; Q2 (borner propagation T3 séparément du cap de stacks) ;
Q3 (bouclier vs axe D : counter voulu ou accidentel) ; Q4 (twists palier 4 vs T2 existants,
audit colonne F). Nouvelles propositions priorisées : P1 signal UI famille amplifiée (P0.5) ;
P2 `--poison-frac` en sim P0.5 (précondition P1 reclassée) ; P3 `--position-variance` en
P0.5 (critère #D avancé) ; P4 cap `plague_communion` à 4 (P1.5a) ; P5 métriques burn vs
non-burn dans Config D (P0.5).*
