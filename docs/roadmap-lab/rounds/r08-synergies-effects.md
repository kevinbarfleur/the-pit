# Round 08 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 8/10 — challenge du brouillon v8 (`ROADMAP-draft.md`) et de la
> synthèse `round-07.md`. Lecture seule du repo et du web ; écriture uniquement sous
> `docs/roadmap-lab/`.
>
> **Inputs lus** :
> - `BRIEF.md`, `ROADMAP-draft.md` v8, `00-state.md`, `round-07.md`
> - `rounds/r07-synergies-effects.md` (critique précédente, même lentille)
> - `docs/roadmap-lab/competitive/slay-the-spire.md`, `tft.md`
> - `00-state.md` §3.1/§3.3/§2.1/§6, seed/mechanics.md (via 00-state)
>
> **Recherches web menées** :
> - arxiv.org/abs/2502.10304 — « When 1+1 does not equal 2: Synergy in games »
>   (Kritz & Gaina, FDG 2025) — définition formelle de la synergie
> - keithburgun.net/pick-1-of-3 — couplage lâche vs fort dans les offres 1-parmi-3
> - poewiki.net/wiki/Shock + poe2wiki.net/wiki/Shock — mécanique précise PoE1/PoE2
> - entaltostudios.com — roguelite design essentials (closing move, archetype identity)
> - superautopets.wiki.gg — pool size per tier, visibility dynamics in SAP
> - teamfighttactics.leagueoflegends.com — Inkborn Fables learnings (traits verticaux)
>
> **Garde-fous** : lecture seule du repo + web ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers async/déterministe/grimdark/procédural respectés.
> Ne modifie ni le code, ni les tests.

---

## 0. Angle d'attaque de ce round

Le round 7 a tranché des questions techniques importantes (`shield_caster` actif, cas
dégénéré choc, `famines_math` tri stable, reliques E = amplificateurs). Ce round 8
s'attaque à des **lacunes structurelles plus profondes** que les rounds précédents
ont soit mal posées, soit évitées :

1. **Le modèle « paliers de type global pur 2/4 » crée une promesse qu'il ne peut pas
   tenir seul : donner une IDENTITÉ DE BUILD à partir du round 1.** Les paliers 2/4
   sur 9 slots avec START_SLOTS=3 signifient que le joueur commence sa run avec un
   plateau qui ne peut pas atteindre le palier-2 en round 1. La fenêtre d'identité
   réelle commence au round 3-4 — là où les effets de composition commencent à
   s'auto-amplifier. Cette latence n'est jamais quantifiée dans la roadmap, et le
   « Nom de Build » (§2.4bis) suppose une identité déjà formée.

2. **L'« interaction gap » entre familles est la lacune de profondeur #1 non adressée
   dans tout le roadmap-lab.** Chaque famille DoT est isolée : burn ne parle pas à
   bleed, rot ne parle pas à poison (hormis les interactions T3 croisées ponctuelles
   — `bleed→rot`, `poison→burn à 5 stacks`). Le résultat est que deux builds différents
   (burn-seul vs bleed-seul) ont peu de décisions asymétriques entre eux — ils se
   réduisent à « qui a le plus de DPS ce round ». L'adjacence positionnelle (une aura
   qui buffe le voisin) EST une forme d'interaction locale, mais elle ne crée pas de
   **tension de BUILD** (on ne choisit pas burn vs bleed, on les co-empile si possible).

3. **La hiérarchie poison > tank > choc est traitée comme un problème de puissance à
   mesurer et corriger, mais c'est d'abord un problème de LISIBILITÉ DE COUNTERPLAY.**
   Le choc en axe D dépend de la famille du poseur — ce n'est pas encore lisible sans
   signal UI. Le rot counter les tanks seulement sous condition de placement. Le bleed
   ralentit mais ne supprime pas une cible. Ces subtilités ne sont pas readables en
   jeu — le joueur les découvre par échec, pas par intention.

4. **La pile d'interactions choc-D + `bleedPierceShield` + auras build-résolues a un
   problème de MULTIPLICITÉ D'EFFETS INVISIBLES que la roadmap n'a jamais nommé.**
   Pour un joueur qui n'a pas lu le code, le combat est une boîte noire. La
   métrique `offer_decision_quality` mesure la qualité des offres de reliques — mais
   il n'y a pas d'équivalent pour la **LISIBILITÉ DES EFFETS EN COMBAT** (combien
   d'effets simultanés le joueur peut-il réellement percevoir dans l'animation).

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 Palier de type GLOBAL PUR (2/4), compteur `dot_family` — ACCORD FORT, MAIS PRÉCISION CRITIQUE

La décision est solide. TFT Inkborn Fables a confirmé que les traits à double condition
(nombre + adjacence) créent une « dead-zone » (unité dans le trait perçue comme faible
même à count=3 parce que la condition d'adjacence n'est pas remplie). Sur notre plateau
3×3 à START_SLOTS=3, la dead-zone serait encore plus sévère — le joueur ne peut pas
atteindre count=4 **ET** maintenir une paire adjacente sur un plateau de 3 unités.

Source confirmée (round 7 + relu) : teamfighttactics.leagueoflegends.com/en-au/news/dev/
dev-tft-inkborn-fables-learnings — « big vertical traits MUST have primary stars, which
usually means selfish amounts of power to the champs within the trait. »

**MAIS** — précision non faite en round 7 : Kritz & Gaina (arxiv.org/abs/2502.10304,
FDG 2025, « When 1+1 does not equal 2: Synergy in games ») définissent formellement la
synergie comme un ensemble d'éléments dont la **valeur mesurée est différente de la
somme des valeurs individuelles**. Leur résultat empirique sur Magic: The Gathering et
League of Legends montre que les synergies les plus puissantes en termes de rétention
sont celles où le joueur peut **mesurer l'écart** (la valeur du set vs la somme des
parties). **Un palier de type global qui donne +20 % à l'équipe est mesuré comme un
buff flat — le joueur ne perçoit pas une synergie, il perçoit un augment.** Pour que
le palier soit vécu comme une vraie synergie, il faut que le **bonus conditionnel soit
observable lors d'un événement distinct** (ex. : quand 2 unités burn sont en plateau,
un ennemi brûlé explose plus fort = l'événement est visible, pas juste +20 % de stat).

**Conséquence pratique** : le brouillon spécifie les paliers comme des `grant_team`
d'inc/more. C'est la bonne architecture. Mais la **formulation UI du palier** doit
pointer un ÉVÉNEMENT, pas un stat : « 2 BRÛLEURS — tes brûlures s'enflamment au
contact » (événement mental lisible) plutôt que « 2 BRÛLEURS — +20 % dégâts brûlure »
(stat abstraite).

### 1.2 Tests inter-famille 2a/2b (`bleedPierceShield` + `shield_caster`) — ACCORD FORT

La décision du round 7 est correcte et la critique r07 (§2.1) est bien fondée. Un
`ward_weaver` niveau-3 régénère 60 bouclier toutes les 4 s (LEVEL_MULT=3 × 20 = 60,
cd=240 ticks @ 60 fps = 4 s) — et `bleedPierceShield` à 1 pt/tick retire 60 pts
de bouclier sur ces 240 ticks si 1 instance de bleed est active. Sur 4 s de combat,
les deux s'annulent exactement. La mécanique n'est pas « inerte » au sens strict avec
une instance — mais avec 0 instance (pas de bleed actif sur la cible à ce tick), le
twist est ZÉRO. Avec 2+ instances, le drain surpasse la regen. **La vraie question est
la distribution du nombre d'instances bleed actives en mid-combat — exactement ce que
le test 2b doit mesurer.**

Ce qui renforce la validité du test : SAP (superautopets.wiki.gg, relu) précise que
les synergies « one-shot » (se déclenchent une fois) vs « continuous » (tiquent en
continu) ont des valeurs très différentes selon la durée de combat. Un drain de 1/tick
est continuous ; une regen de 60/4 s est discontinue — leur rapport dépend du CD de
la regen vs la durée du bleed. **Le test 2b mesure exactement cette interférence.**

### 1.3 Hiérarchie build-definition : Types P1 = CRÉATEURS, Reliques E = COURONNEURS — ACCORD COMPLET

La distinction §4.11 est solide et bien ancrée. Source confirmée : slaythespire.wiki.gg/
wiki/Relics — les boss relics de StS ont un downside explicite qui crée du forced theming ;
les rares non-boss (Dead Branch, Frozen Egg) sont des amplificateurs sans pivot. Nos
reliques E (sans downside, principe relics-design #2) sont effectivement dans le camp des
« rares non-boss » de StS — amplificateurs post-commit, pas pivots.

**Ce qui tient pour NOS contraintes** : dans un run de 10 victoires, l'identité de build
doit être établie avant le round 5 pour que le joueur ait le temps d'en profiter. Les
reliques E apparaissent en tier-4 (post-commit) — soit après 5-7 victoires pour un joueur
mid-core. Si les reliques E ÉTAIENT les créateurs d'identité, le joueur n'aurait que 3-4
rounds pour en profiter. Les types P1 à palier-2 (disponibles dès round 3-4) sont
effectivement les seuls créateurs d'identité au bon horizon.

### 1.4 Exception choc dans le tableau de saturation d'inc — ACCORD FORT

L'exception est nécessaire et correcte. PoE2 Wiki (poe2wiki.net/wiki/Shock, relu) confirme
que shock dans PoE2 « does not stack; only the highest effect applies » — un condensateur
événementiel dont le cap est en stacks (SHOCK_STACK_CAP=8), pas en output (DOT_CAP_MULT=3).
La formule `seuil_inc = (cap/base_min) − 1` est inapplicable sur un axe de stacks événementiels.
Le palier choc-4 ne peut pas être un `more` sur l'output direct — il doit modifier l'axe des stacks,
de l'ampli ou de la condition de décharge. **Cela reste non-challengé.**

### 1.5 `--pool-repr` comme 3e mesure avant `--poison-frac` — ACCORD SUR L'ORDRE STRICT (désaccord avec la synthèse r07)

La synthèse r07 a nuancé l'ordre strict (§5.1) : « l'audit colonne B fait déjà le diagnostic
qualitatif, `--pool-repr` en est la validation quantitative, pas un préalable bloquant
indépendant. » **Ce round challenge cette nuance et plaide pour l'ordre strict.**

Voir §2.1 ci-dessous.

---

## 2. DÉSACCORDS — ce qui est faible, faux ou non-étayé

### 2.1 DÉSACCORD FORT : `--pool-repr` DOIT précéder `--poison-frac` — l'ordre n'est pas interchangeable

**Ce que la synthèse r07 dit** (§5.1) : `--pool-repr` adopté, mais ordre strict rejeté au
profit du « même lot P0.5 ». Position : « l'audit colonne B fait déjà le travail
qualitativement, `--pool-repr` en est la validation quantitative. »

**Pourquoi cet ordre est cassé** :

L'audit colonne B identifie les paires de niche quasi-identiques (params ≤20 %) pour les
retirer. Mais la colonne B ne décide pas COMBIEN d'unités retirer — elle identifie les
REDONDANTES, pas celles EN EXCÉDENT DE REPRÉSENTATION. La différence est mécaniste :

- **Redondance de niche** : `pyre_herald` ≈ `emberling` (burn, mêmes params) → retirer l'une.
- **Excédent de représentation** : poison rang-2 a 6 unités, choc rang-2 en a 2-3. Même si
  on retire `wailing_shade` (doublon niche bleed), poison reste sur-représenté vs choc au
  niveau du pool par rang.

Si on lance `--poison-frac` avec un pool où poison rang-2 = 6 unités et choc rang-2 = 2-3,
la sim mesure : (a) la propagation poison PLUS (b) l'effet de sur-représentation boutique.
Ces deux causes sont confondues dans le win%. `--pool-repr` d'abord → on corrige
l'excédent de représentation → PUIS `--poison-frac` isole la propagation pure.

**Chiffre non contesté** : poison 15 unités, choc 11 unités (00-state §2.1). Si pool rang-2
confirme poison ≈ 6 vs choc ≈ 2-3, P(voir poison en boutique T2) ≈ 2.3× P(choc) à cotes
uniformes — une sur-représentation **antérieure** à toute propagation (SAP : la profondeur
commence par la visibilité boutique, superautopets.wiki.gg : « pool unlocks by tier define
what the player encounters first »).

**Analogie décisive** : si on mesurait `--no-weaken` sur un pool où `chitin_drone` (weaken)
était représenté 3× plus que les autres rang-2, on ne saurait pas si le delta vient du
weaken lui-même ou de sa sur-exposition. Même logique pour `--poison-frac`.

**Conclusion** : l'ordre strict est la seule façon d'**isoler les variables**. La synthèse r07
confond « fait le même travail qualitativement » avec « produit le même résultat
quantitatif ». Ce sont deux instruments distincts sur des causes distinctes.

**Source** : arxiv.org/abs/2502.10304 (Kritz & Gaina 2025) : « measuring synergy requires
isolating the set from individual element contributions » — transférable ici : mesurer la
propagation requiert d'isoler d'abord la représentation de pool. keithburgun.net/pick-1-of-3 :
« the quality of a decision depends on what options are presented » — si le pool poison
présente 2.3× plus d'options, la décision poison n'est pas équitable.

### 2.2 DÉSACCORD FORT (nouveau) : L'« interaction gap » entre familles est la lacune de profondeur non adressée

**Ce que la roadmap dit** : les interactions inter-familles existent via les synergies T3 croisées
(`bleed→rot` consommé, `poison→burn à 5 stacks`, `festering = cap levé équipe`). Les auras
d'adjacence bakent un bonus au voisin. La roadmap P1 ajoute des paliers de type par famille.

**Le problème structurel** :

Les synergies T3 croisées sont des **transformations à seuil haut** (rang-3, conditions
précises). Un joueur qui construit un build bleed-poison voit-il une décision différente d'un
build bleed-seul dans les rounds 1-6 ? Non, parce que les interactions croisées bleed-poison
n'existent qu'à T3 et que les paliers de type sont par FAMILLE SEULE (bleed-4 ou poison-4,
jamais « bleed+poison ensemble »).

Kritz & Gaina (arxiv.org/abs/2502.10304) distinguent deux types de synergie :
- **Intra-ensemble** : les éléments du même type se renforcent (notre palier 2/4 par famille).
- **Inter-ensemble** : deux familles différentes créent un effet que ni l'une ni l'autre n'a
  seule (nos T3 croisées seulement).

Le manque de synergies **inter-ensemble en MID** (rang-2 ou build-level 2-4 rounds, avant les
T3) signifie que le joueur n'a AUCUNE raison mécanique de diversifier ses familles avant mid-game.
Résultat observé : les builds monofamille dominent la méta early (poison 4 ou bleed 4 ou burn 4),
et les seules décisions de diversification sont des décisions d'opportunité boutique (« je prends
ce rot rang-2 parce qu'il est là »), pas des décisions stratégiques.

**L'aura d'adjacence n'est pas une synergie inter-famille** : elle buffe le voisin quelle que
soit sa famille. Un `soot_acolyte` (burn aura) voisin d'un `razorkin` (bleed) buffe bleed — ce
n'est pas une interaction burn/bleed, c'est un buff directionnel quel que soit le type.

**Ce qui manque** : 2 mécaniques inter-familles MID non présentes dans la roadmap :

1. **Amplification directionnelle par duo de familles** : « si une cible a du bleed ET du burn,
   les ticks burn brûlent les stacks bleed (aggravate étendu) ». Ce n'est pas une troisième
   famille, c'est une interaction entre deux existantes. Pas de nouveau moteur : `on_dot_tick`
   existe déjà (`tickDots` dans `arena.lua`), ajouter une vérification de co-présence est
   1-2 lignes de data.

2. **Combos de positionnement croisé** : « une unité burn adjacent à une unité rot voisine d'un
   même ennemi = les cendres du burn empoisonnent la blessure rot ». Ce serait une interaction
   d'ARÊTE SIGIL (positionnelle), pas d'effet global — très cohérent avec « la forme EST le
   champ de bataille ».

Ces deux mécaniques ne violent aucune décision actée : elles n'ajoutent pas de famille, elles
n'utilisent pas de RNG, elles ne cassent pas le déterminisme. Elles utilisent des triggers
existants (`tickDots`, `on_death`, `neighbours`).

**Sans elles**, P1 (types) crée des identités MONOFAMILLE fortes mais laisse un build 2-familles
aussi fort ou plus faible qu'un build 1-famille du même tier de boutique. Le joueur qui
diversifie ne reçoit aucune récompense mécanique avant les T3 — et les T3 sont au round 8+.

**Pourquoi cela tient pour NOS contraintes** : async déterministe → les interactions doivent
être reproductibles (OK : basées sur les stacks présents, pas le RNG) ; grimdark → les
interactions croisées ont une logique thématique forte (le feu calcine la blessure, le poison
aggrave la putréfaction) ; run court 10 victoires → les synergies inter-familles doivent se
déclencher avant le round 7, donc au rang-2 ou en condition de build, pas rang-3.

**Source** : Kritz & Gaina 2025 (inter-set synergies) ; entaltostudios.com « every archetype
must have a reason to branch » (5 Essential Tips, relu) ; SAP (mobilegamereport.com : la
profondeur de SAP est dans les triggers qui « chain » entre families, pas dans la puissance
brute de chaque family seule).

**Priorité** : HAUTE — c'est la lacune de profondeur #1 non adressée en 8 rounds. P1 sans
synergies inter-familles MID = couche de types qui cloisonne les familles au lieu de les faire
résonner.

### 2.3 DÉSACCORD MOYEN : Le « Nom de Build » (§2.4bis) suppose une identité établie trop tôt

**Ce que la roadmap dit** (§2.4bis) : au post-combat, lire `shape` + `dot_family` des unités du
build pour générer un nom grimdark — « ≥4 dot_family=="burn" → BRÛLEUR DU PUITS ». Précondition
P0.5 (`dot_family`). Priorité 1 RENDER.

**Le problème de timing** :

La seuil `≥4 unités d'une famille` sur un plateau de 3 slots (START_SLOTS=3) est
**impossibles en rounds 1-2**. En round 3-4 (3-5 slots), c'est gérable. En round 5+
(5-7 slots), le palier-4 P1 s'active.

Si `≥4 famille` n'est jamais atteint en round 1-4, le joueur voit « ARPENTEUR DU PUITS »
(fallback) pendant les 4 premiers rounds — exactement là où l'identité de run est la plus
fragile (zone 0-5 victoires = churn maximal, §2.3). Ce n'est pas un « nom de build »,
c'est un placeholder. Le signal promis (« ancre le Moment du Run dans l'identité ») n'est
disponible qu'en mid-game.

**Recommandation** : abaisser le seuil pour les early-rounds. Deux options :
- **(a) Seuil progressif** : round≤3 → seuil=2 (même famille) ; round≤6 → seuil=3 ;
  round>6 → seuil=4 (le palier P1 existe). RENDER pur, 0 SIM, lit `state.wins`.
- **(b) Nom à 2 familles co-présentes (early)** : « 2 burn + 2 bleed → ALCHIMISTE DU PUITS »
  dès round 2 (2 familles présentes ≥ 1 unité chacune). Rend la diversification visible dès
  l'early — et récompense mécaniquement la diversité inter-familles (synergie §2.2).

L'option (b) est plus intéressante parce qu'elle aligne le signal d'identité avec l'incitation
à diversifier. Un joueur qui a 1 burn + 1 bleed au round 2 se voit nommer « ALCHIMISTE » →
signal positif pour la diversification, pas négatif. C'est un coût RENDER nul supplémentaire.

**Note** : l'option (b) introduit une ambiguïté si P1 types existe (le nom « ALCHIMISTE »
ne correspond à aucun palier de type). La roadmap (§2.4bis) anticipe déjà cette simplification :
« Se simplifie si P1 (types) est adopté (le nom = palier de type actif au résultat) ». Donc en
post-P1, le nom redevient le palier actif — mais pre-P1, il faut un nom early valide.

**Priorité** : MOYENNE. Ne bloque pas P0. Mais une PRIORITÉ-1 RENDER qui n'affiche un nom
significatif qu'à partir du round 5 manque l'objectif de rétention en zone 0-5 victoires.

### 2.4 DÉSACCORD MOYEN : La latence early du choc (§2.5 r07, §2.5 round 7 adopté comme NOTE) est sous-traitée

**Ce que la roadmap dit** : CONFIG-CE (Choc Early) ajoutée comme « diagnostic de tuning (P3 level),
non bloquant ». Signalé pour ne pas graver un design d'apex choc que le sim contredira.

**Pourquoi ce classement est trop faible** :

L'apex choc (`skull_colossus` réorienté, §3.7) est promu BLOQUANT AVANT P1. Mais si la latence
early du choc (le commit choc en rounds 1-3 sous-performe structurellement) n'est pas corrigée
avant l'introduction de l'apex choc rang-5, le résultat est le suivant :

- Le joueur engage choc en early (rounds 1-4, plateau 3-5 slots, peu de DoT actif sur les cibles).
- L'axe D ne se déclenche pas (pas assez de DoT adverse sur la cible).
- Le joueur perçoit le choc comme faible ET la boutique ne lui propose pas d'apex (rang-5 absent).
- Il quitte l'archétype avant mid-game.
- MAINTENANT : l'apex rang-5 est ajouté. Le joueur voit l'apex au shopTier 5 (round 7+) — mais
  il n'engage plus choc (la perception de faiblesse early l'a dissuadé au round 3).

**L'apex choc sans correction de la latence early est un apex qui n'est jamais atteint.**

Pour les contraintes async : un ghost choc tier-4 sans DoT adverse actif en early voit ses
décharges ne rien amplifier → le ghost semble « faible » au snapshot → déconseille l'archétype
dans la méta perçue. La latence early du choc EST un problème de snapshot-perception, pas
seulement de ressenti local.

**Recommandation** : élever CONFIG-CE au niveau de mesure SIMULTANÉ à la décision d'apex choc
(avant P1, pas P3). Le résultat de CONFIG-CE doit précéder la décision de fallback dégâts directs
(si écart > 40 % → 1 unité choc rang-1 avec dégâts non-nuls même sans DoT actif). Ce n'est pas
du P3 — c'est la condition de validité de l'apex choc.

**Source** : 00-state §3.2 (axe D dans tickDots, condition de DoT actif) ; entaltostudios.com :
« a closing move only works if the archetype is already in play by round 6 » ; r07 §2.5 (latence
structurelle early, bien diagnostiquée, mais mal priorisée).

**Priorité** : HAUTE — co-priorité avec la décision d'apex choc (§3.7).

### 2.5 DÉSACCORD FAIBLE mais PRÉCIS : L'invariant #22 (choc-décharge+consommé) peut cacher un cas limite avec `wither_bloom`

**Ce que la roadmap dit** : Option C2 (`afflictionCount` ne compte que les dps réels) — la
correction de `wither_bloom` ne touche pas l'invariant #22 car `dischargeShock` lit
`target.dots.shock.stacks`, pas `afflictionCount` (§3.8, vérif synthé).

**La précision** :

Après C2, `wither_bloom` (rot{base=2} + bleed{dps=0} + poison{dps=0}) compte `afflictionCount=1`.
L'invariant #22 (choc-décharge + consommé) teste que la décharge choc est bien **consommée**
après déclenchement. Le test existant ne couvre pas le cas suivant :

- Une cible a `rot` actif (de `wither_bloom`, dps>0 donc compté par C2), `bleed{dps=0}`,
  `poison{dps=0}`, ET `shock.stacks>0` (de notre build choc).
- L'axe D choc lit `dot_family` du poseur. Si le poseur est choc pur (`dot_family="choc"`),
  le fallback de l'axe D cherche le 1er DoT actif dans l'ordre fixe `burn→bleed→poison→rot`.
- `bleed{dps=0}` est-il « présent » dans l'ordre fixe ? Ou C2 l'exclut-il de la détection ?

Si C2 modifie `afflictionCount` mais **pas** la détection dans `tickDots` de la famille de tick,
alors le fallback de l'axe D sur une cible `wither_bloom` peut encore « voir » le bleed inerte
et l'amplifier pour 0 — résultat : décharge choc consommée sans effet. C'est un edge case de
l'interaction C2 + axe D, non couvert par l'invariant #22 actuel.

**Ce n'est pas une brisure d'invariant** — la décharge est bien consommée. Mais la promesse de
l'axe D (« ton choc amplifie TON DoT ») est silencieusement violée : la décharge s'est produite,
les stacks sont consommés, et le joueur ne voit aucun effet.

**Recommandation** : ajouter un test de l'axe D sur une cible `wither_bloom` post-C2 (cible avec
1 seul dps réel = rot, et 2 familles inertes en dps) + un poseur choc sans famille `rot`. Vérifier
que le fallback saute les familles à dps=0. Test ~10 lignes dans `tests/synergies.lua`. Zone sans
test actuelle (00-state §8).

**Priorité** : FAIBLE. Cas précis, non bloquant P0.5. Signalé pour éviter de graver C2+axe D
sans couvrir cette interaction.

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Imposer l'ordre strict `--pool-repr` AVANT `--poison-frac` [PRIORITÉ HAUTE, tranche le litige #DD]

**Quoi** : dans la spec sim §3.5, remplacer « même lot P0.5, pas d'ordre imposé » par :

```
ORDRE IMPOSÉ P0.5 :
  1. --pool-repr  : alarme si max_famille/min_famille > 1.5 par rang
     → corriger le pool (col B §3.1, retrait enablers POOL redondants)
  2. --poison-frac : mesure la propagation sur un pool REPRÉSENTATIF
  3. --no-weaken   : isole le weaken sur le même pool corrigé
```

**Pourquoi** : les 3 mesures supposent un pool représentatif. Les lancer en parallèle
confond les causes. L'ordre strict garantit que `--poison-frac` mesure la propagation
PURE, pas la propagation + sur-représentation. C'est la condition d'isolabilité des
variables (Kritz & Gaina 2025 : « measuring synergy requires isolating element
contributions »).

**Coût** : doc pur, 0 code. Tranche le litige #DD.

**Impact** : si `--pool-repr` révèle que poison rang-2 est sur-représenté (>1.5× choc),
corriger avant `--poison-frac` → le résultat de `--poison-frac` est propre. Sinon
le levier `frac=0.5` est sous-calibré (corrige la propagation d'un poison AUSSI
sur-représenté → trop d'affaiblissement).

### P2 — Ajouter 2 interactions inter-familles MID dans la spec P1 [PRIORITÉ HAUTE, lacune de profondeur #1]

**Quoi** : dans le chantier P1 (§5), documenter 2 interactions inter-familles MID à
spécifier en // des paliers de type :

**Interaction A — Aggravation croisée par co-présence** (dans `tickDots`) :
```
Si cible a DEUX familles DoT actives (dps>0) au moment d'un tick :
  la famille du 2nd tick se déclenche avec un `more` de +X% sur ce tick.
  X = petit (ex. 10-15%), cap = 1× l'incident (PAS de cascade).
  Déterministe : condition sur les stacks, pas RNG.
  0 nouveau trigger : lit les dots déjà dans tickDots.
  GOLDEN : introduit un bonus conditionnel → rebaseline si la config golden
  contient une co-présence (à vérifier avant commit).
```

**Interaction B — Contagion de famille voisine au kill** (dans `on_death`) :
```
Si une unité meurt avec 2+ familles DoT actives (dps>0) :
  la famille la PLUS FORTE (nb stacks ou dps) se propage aux voisins
  de combat (Arena:neighborsOf) à X% de son intensité.
  X = petit (15-20%), 0 nouvelle règle d'équipe, 1 ligne dans on_death.
  DISTINCTE de la propagation poison actuelle (qui propage ALL stacks à 1.0×).
```

Ces 2 interactions rendent la diversification MID mécaniquement rentable. Elles
utilisent des triggers existants, 0 nouveau moteur. La priorité dans P1 les place
AVANT les twists T2/T3 (qui sont des renforts monofamille).

**Pourquoi** : sans interactions inter-familles MID, le joueur n'a aucune raison de
mélanger les familles avant les T3 rang-3 croisées. P1 crée des identités MONOFAMILLE
fortes → renforce la dominance de poison (déjà sur-représenté). Les interactions inter-
familles MID créent des décisions stratégiques de BUILD, pas juste de boutique.

**Source** : Kritz & Gaina 2025 (inter-set synergies) ; SAP (triggers qui chaînent entre
teams) ; Notre `on_death` déjà câblé pour la propagation poison (`spread_*_on_death`).

**Coût** : doc (spec dans §5) + ~5-10 lignes data/moteur. Conditionné par P0.5 (`dot_family`).

### P3 — Seuil progressif pour le « Nom de Build » (§2.4bis) [PRIORITÉ MOYENNE, précondition zone 0-5 wins]

**Quoi** : dans §2.4bis, remplacer le seuil fixe `≥4` par :

```
round ≤ state.wins+2 ≤ 3  (slots 3-5) :
  → nom si ≥2 unités de même famille OU ≥2 familles différentes présentes
  → « [FAM] NAISSANT » (≥2 même famille) ou « ALCHIMISTE NAISSANT » (2 familles)
round state.wins+2 ∈ [4,6] (slots 5-7) :
  → seuil=3 ; nom complet sans « NAISSANT »
round state.wins+2 ≥ 7   (slots 7-9) :
  → seuil=4 (palier P1 actif, nom = palier actif)
```

**Précondition** : `state.wins` lu depuis `state` (hors SIM, déjà exporté). RENDER pur.

**Pourquoi** : le « Nom de Build » est priorité-1 pour ancrer l'identité en zone 0-5 wins.
Un fallback « ARPENTEUR DU PUITS » pendant les 4 premiers rounds manque cet objectif.

### P4 — Élever CONFIG-CE (latence early choc) au même lot que la décision d'apex choc [PRIORITÉ HAUTE]

**Quoi** : dans §3.7 (apex choc rang-5), ajouter au critère de validation :

```
PRÉCONDITION APEX CHOC :
  Avant de coder skull_colossus → shockChain, lancer CONFIG-CE :
  {1 galvanizer T4 choc + 1 burn-poseur rang-2 + 1 stat-stick rang-1}
  vs IA round-2, N=30, seed 20260620.
  burst_DPS_eq réel vs théorique. Si écart > 40% :
    → corriger 1 unité choc rang-1 avec fallback dégâts directs (stat-stick)
    AVANT de coder l'apex (sinon l'apex n'est jamais atteint).
```

**Coût** : ~15 lignes sim. Non bloquant si l'écart < 40% (pas de fallback nécessaire).

### P5 — Ajouter test edge-case axe D + C2 (`wither_bloom` + choc sans dot_family rot) [PRIORITÉ FAIBLE]

**Quoi** : dans `tests/synergies.lua`, test 13 :

```
-- Test 13 : axe D sur cible wither_bloom post-C2
-- Cible : wither_bloom (rot actif, bleed+poison dps=0)
-- Poseur choc : galvanizer (dot_family="choc", pas de famille rot)
-- Fallback axe D : cherche 1er dps>0 dans ordre burn→bleed→poison→rot
--   → doit atteindre rot (le seul dps>0) et amplifier ce tick
-- → vérifier que shock.stacks consommés ET amplitude > 0 (pas 0 sur bleed/poison inertes)
```

**Coût** : ~15 lignes, zone sans test (00-state §8), 0 moteur.

---

## 4. QUESTIONS OUVERTES

### Q1 : Quelle est la distribution de `dot_family` par rang dans le pool après la cohorte v7 ?

La roadmap documente poison 15 unités / choc 11 totaux (00-state §2.1), mais la répartition
par RANG n'est jamais détaillée. Si choc rang-2 = 2-3 unités et poison rang-2 = 5-6 unités,
la latence early du choc est un problème de VISIBILITÉ (pas d'unités visibles en boutique
T2) autant que de mécanique. `--pool-repr` par rang tranchera cela — mais la décision de
corriger ou non le pool par rang devrait être spécifiée dans la cohorte v7 §3.2 avant P0.5.

### Q2 : L'interaction Burn-absorbé-par-bouclier change-t-elle si le `shield_caster` est un voisin du build ?

Dans l'axe D (choc amplifie la famille du poseur), si le poseur est burn et que la cible a
un bouclier actif, le tick burn amplifié est absorbé par le bouclier (burn=absorbed,
`arena.lua:432`). La mécanique est correcte (burn vulnérable aux boucliers = #W intentionnel),
mais le signal de l'axe D dans l'UI doit-il afficher « AMPLIFIÉ (absorbé) » ou « AMPLIFIÉ »
tout court ? Si l'amplification est silencieuse parce qu'absorbée, le joueur perçoit que
l'axe D ne fonctionne pas sur son burn build face à un tank — frustration Artifact.

### Q3 : Faut-il une MÉTRIQUE de LISIBILITÉ des effets simultanés en combat (nombre d'effets visibles par frame) ?

Le brouillon a `offer_decision_quality` (qualité de décision des offres reliques). Mais il
n'y a pas d'équivalent pour la lisibilité du combat. Avec `bleedPierceShield` + axe D +
auras build-résolues + regen + propagation au kill + boucliers périodiques, un frame de
combat peut avoir 8-12 effets simultanés. Combien en sont visibles dans le rendu pixel art
320×180 ? Si > 5 → le joueur ne peut pas attribuer les effets → frustration opaque.
La `arena_draw.lua` est la seule couche pouvant mesurer cela, mais rien dans la roadmap
ne le spécifie.

### Q4 : La décision de litige #CC (`wither_bloom` post-C2) ne doit-elle pas être tranchée AVANT P1, pas P1.5b ?

`wither_bloom` est la seule unité rang-5 avec 3 familles. En P1, les paliers de type comptent
`dot_family` (la famille du 1er effet DoT non-aura). Pour `wither_bloom`, si C2 fait que
`afflictionCount=1` (rot seul), le palier-2 rot s'active avec 2 unités rot — dont `wither_bloom`
mais pour le palier-4 rot, `wither_bloom` ne contribue qu'une fois (son `dot_family=rot`, pas 3).
La question est : est-ce que le rôle voulu de `wither_bloom` (proxy multi-affliction) est
compatible avec le design des paliers de type AVANT qu'on code P1 ? Si on décide de reconcevoir
`wither_bloom` en bleed/poison à dps>0, la spec P1 change (3 familles actives → contribue à
plusieurs paliers). Si on l'accepte comme rot-T3, P1 est simple. La décision doit précéder P1.

---

## 5. CE QUI N'EST PAS UN DÉSACCORD

- **Axe D du choc (`dot_family` du poseur + fallback ordre fixe)** : correct, non re-challengé.
- **`bleedPierceShield` 1 pt/tick + test 2b avec `shield_caster` actif** : adopté, accord.
- **Exception choc dans le tableau de saturation d'inc** : correct, non re-challengé.
- **`afflictionCount` Option C2** : code-vérifié, correct. Garde-fou invariant #22 confirmé
  (avec la nuance Q1 du présent round — test edge-case à ajouter).
- **Seuils 2/4 sur 9 slots maximum** : accord fort. Start avec START_SLOTS=3 ne casse pas les
  paliers (ils se déclenchent en mid, pas en early — la **précision est que c'est une feature,
  pas un bug**, tant que la zone early 0-3 rounds a un signal d'identité alternatif = §3/P3 ici).
- **`ward_weaver` scale par LEVEL_MULT** : confirmé (00-state §3.1 + r07 §2.1/code-vérifié).
- **Décision #D close (global pur)** : non re-challengée, la dead-zone TFT Galaxies est solide.

---

## 6. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée | Priorité |
|---|---|---|---|---|
| `--pool-repr` DOIT précéder `--poison-frac` (isolation des variables) | **FORTE** | `--poison-frac` mesure propagation + sur-représentation confondues → levier mal calibré | Imposer ordre strict §3.5, trancher litige #DD | HAUTE (P0.5) |
| « Interaction gap » inter-familles MID non adressée | **FORTE** | P1 types cloisonne les familles → builds monofamille dominants, diversification non récompensée | Spec 2 interactions inter-familles MID dans §5 P1 | HAUTE (P1) |
| Nom de Build seuil ≥4 = vide en zone 0-3 rounds | **MOYENNE** | Signal identité manque en zone 0-5 wins, la plus critique pour churn | Seuil progressif §2.4bis | MOYENNE (P0) |
| Latence early choc = CONFIG-CE sous-priorisée (P3 vs précondition apex) | **FORTE** | Apex choc rang-5 ajouté sans corriger la latence = apex jamais atteint | CONFIG-CE co-prioritaire à la décision apex §3.7 | HAUTE (P0.5) |
| Edge-case axe D + C2 sur cible wither_bloom (décharge silencieuse) | **FAIBLE** | Décharge choc consommée sans effet visible = frustration opaque | Test 13 dans synergies.lua | FAIBLE |
| Burn amplifié par axe D absorbé par bouclier = signal UI ambigu | **MOYENNE** | Le joueur perçoit l'axe D comme broken vs tanks | Spec UI « AMPLIFIÉ (absorbé) » dans §3.4 | MOYENNE |

---

## 7. Index des sources

**Web vérifié ce round :**

- Kritz & Gaina 2025 — « When 1+1 does not equal 2: Synergy in games » (FDG 2025) :
  [arxiv.org/abs/2502.10304](https://arxiv.org/abs/2502.10304)
  [arxiv.org/html/2502.10304v1](https://arxiv.org/html/2502.10304v1)
- Keith Burgun — « Pick 1 of 3 is a missed game design opportunity » (couplage lâche vs fort) :
  [keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity](http://keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity/)
- PoE2 Wiki — Shock (seul le plus fort s'applique, condensateur événementiel) :
  [poe2wiki.net/wiki/Shock](https://www.poe2wiki.net/wiki/Shock)
- PoE Wiki — Shock (PoE1, all sources boost damage taken) :
  [poewiki.net/wiki/Shock](https://www.poewiki.net/wiki/Shock)
- Entalto Studios — 5 Essential Tips to Make Your Roguelite Game Work :
  [entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/)
- TFT Inkborn Fables learnings — vertical traits, primary stars :
  [teamfighttactics.leagueoflegends.com/en-au/news/dev/dev-tft-inkborn-fables-learnings/](https://teamfighttactics.leagueoflegends.com/en-au/news/dev/dev-tft-inkborn-fables-learnings/)
- Super Auto Pets Wiki — pool tiers, unlock sequencing :
  [superautopets.wiki.gg/wiki/Pets](https://superautopets.wiki.gg/wiki/Pets)

**Sources internes (références actives, lecture seule) :**

- `00-state.md` §2.1 (roster 83 unités, 5 familles DoT) ; §3.1 (caps, boucliers, auras) ;
  §3.3 (axe D choc, fallback ordre fixe) ; §6 (32 invariants, zones sans test §8)
- `ROADMAP-draft.md` v8 §2.4bis (Nom de Build), §3.3 (dot_family), §3.4 (axe D),
  §3.5 (mesures sim P0.5), §3.7 (apex choc), §3.8 (C2), §4.11 (hiérarchie reliques),
  §5.1 (types = familles, paliers 2/4)
- `round-07.md` §1.1-2.1 (bleedPierceShield, exception choc, famines_math, apex choc)
- `rounds/r07-synergies-effects.md` §2.1-2.3 (critiques P-1 à P-3)
- `docs/roadmap-lab/competitive/slay-the-spire.md` §2 (reliques lisibles vs boss relics)

---

## 8. Récapitulatif des demandes de modification de specs

| Item | Position ce round | Priorité | Où dans la roadmap |
|---|---|---|---|
| Imposer ordre strict `--pool-repr` avant `--poison-frac` | **REQUIERT MODIFICATION** §3.5 | HAUTE | P0.5 (#DD tranché) |
| Spec 2 interactions inter-familles MID (aggravation croisée + contagion kill) | **REQUIERT ADDITION** §5 P1 | HAUTE | P1 |
| Seuil progressif Nom de Build (≥2 en early, ≥3 mid, ≥4 late) | **REQUIERT MODIFICATION** §2.4bis | MOYENNE | P0 |
| CONFIG-CE co-prioritaire à l'apex choc §3.7 | **REQUIERT ADDITION** §3.7 | HAUTE | P0.5 |
| Test 13 edge-case axe D + C2 + wither_bloom | **REQUIERT ADDITION** tests/synergies.lua | FAIBLE | P0.5 |
| Spec UI « AMPLIFIÉ (absorbé) » axe D vs bouclier | **REQUIERT ADDITION** §3.4 | MOYENNE | P0.5 |
| Question #CC tranchée AVANT P1 (wither_bloom multi-famille) | **REQUIERT DÉCISION** §3.8/§5 | MOYENNE | avant P1 |

**2 litiges neufs ce round :**
- **#EE** : seuil Nom de Build progressif vs seuil fixe ≥4 (§2.4bis).
- **#FF** : interactions inter-familles MID dans P1 = nécessaires ou prématurées ?
  (Le lab a 2 rounds restants pour trancher : si on ne les ajoute pas à P1, le build
  monofamille sera la méta par défaut du ranked S1.)

**1 litige précédent tranché (position de ce round) :**
- **#DD** : `--pool-repr` AVANT `--poison-frac` — **ordre strict REQUIS** (§2.1 ce round).
  Rouvert depuis la nuance r07 §5.1.

---

*Round 08 rédigé le 2026-06-23. Lecture seule du repo. N'édite que sous
`docs/roadmap-lab/`. Piliers respectés. 32 invariants préservés. Pas de
décisions inversées — 3 compléments de spec prioritaires (ordre sim, interactions
MID, CONFIG-CE apex) + 1 nouveau litige structurel (#FF interactions inter-familles).
Sources web citées : Kritz & Gaina 2025 (arxiv), Keith Burgun, PoE2 Wiki, TFT Inkborn,
SAP Wiki, Entalto Studios.*
