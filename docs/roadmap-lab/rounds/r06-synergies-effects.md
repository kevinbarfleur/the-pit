# Round 06 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 6/10 — challenge du brouillon v6 (`ROADMAP-draft.md`) et des synthèses
> rounds 1-5. Ce round lit les fichiers du repo en lecture seule, mène des recherches web
> sourcées, et challenge les propositions en accord ou désaccord **avec justification
> mécaniste**.
>
> **Inputs lus** :
> - `BRIEF.md`, `ROADMAP-draft.md` v6, `00-state.md`, `round-05.md`
> - `rounds/r05-synergies-effects.md` (critique précédente, même lentille)
> - `docs/research/effects-synergy-tiers.md` (template T1/T2/T3)
> - `docs/roadmap-lab/competitive/super-auto-pets.md`
>
> **Recherches web menées** :
> - Positional adjacency vs global synergy engagement in autobattlers (diva-portal.org)
> - TFT design pillars + vertical trait learnings (teamfighttactics.leagueoflegends.com)
> - PoE Shock mechanic precise mechanics (poewiki.net/wiki/Shock, mobalytics.gg)
> - Status effect interaction and counterplay design (waywardstrategy.com 2024)
> - DoT weaken/debuff contribution measurement in roguelites (Last Epoch forums, STS2)
> - Shield interaction design and counterplay (gamesense15.substack.com 2025)
>
> **Garde-fous** : lecture seule du repo + web ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers async/déterministe/grimdark/procédural respectés.
> Ne modifie ni le code, ni les tests.

---

## 0. Angle d'attaque de ce round

Les rounds 1-5 ont consolidé et tranché plusieurs sujets majeurs de la lentille :
#S (ciblage choc-D = `dot_family` du poseur + fallback) clos, `--no-weaken` promu P0.5,
`afflictionCount` corrigé (C2), hybride 2-global/4-adjacence proposé comme design
des synergies par type. Ce round concentre son challenge sur **ce qui reste fragile
ou non étayé** dans la roadmap v6 :

1. **Le compteur hybride 2-global/4-adjacence+type est présenté comme la voie naturelle
   du plateau-graphe sigil, mais la recherche TFT officielle révèle une tension structurelle
   non adressée** : les traits verticaux (hauts seuils) avec condition supplémentaire créent
   des "dead zones" de build qui frustrent les joueurs mid-tier. Le round 6 évalue si notre
   hybride évite ce piège ou le reproduit.

2. **Le rôle des boucliers dans l'écosystème DoT est toujours sous-traité.** La roadmap
   v6 a adopté la colonne H (contre-bouclier par famille), mais la DÉCISION #W (burn
   vulnérable aux boucliers = voulu ou accident) reste un litige ouvert depuis le round 5.
   Cette décision a des conséquences directes sur le twist burn-4, le payoff burn-5, et
   le rôle archétypal des tanks. Ce round tranche.

3. **L'écosystème des 12 synergies testées (`tests/synergies.lua`) est un plancher, pas
   un plafond.** La roadmap v6 compte ~18 synergies de type (P1) + 12 existantes = ~30.
   Mais les 12 existantes couvrent uniquement les cas "chaud" (choc+DoT, contagion,
   propagation à la mort) et ne couvrent pas les interactions ADJACENTES INTER-FAMILLE
   qui sont le cœur de notre différenciateur. Ce gap est structurel.

4. **Le bleed-4 = bleedPierceShield est adopté comme candidat orthogonal, mais sa
   relation avec le rôle actif du bleed (ralentir la cadence) crée une tension de design
   non notée dans le brouillon v6** : un archétype bleed qui perce les boucliers ne ralentit
   plus la cadence ennemie en priorité — les deux axes sont orthogonaux MAIS potentiellement
   conflictuels dans le choix du joueur.

5. **La hiérarchie poison > choc est traitée comme une cause à corriger (--poison-frac,
   --no-weaken), mais pas comme une opportunité de design.** L'état "poison dominant"
   peut être transformé en archétype clairement identifié si — et seulement si — les autres
   familles ont des contre-jeux explicites contre le poison. Ce cadrage manque.

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 Litige #S clos (choc-D cible `dot_family` du poseur + fallback) — ACCORD MAINTENU, SOURCE RENFORCÉE

Le round 5 a tranché #S. Ce round le confirme depuis une source primaire nouvelle
et indépendante : PoE Shock (poewiki.net/wiki/Shock, relu ce round) — « Shock normally
does not stack; multiple shocks can exist on the same enemy with independent durations,
but only the strongest will apply its increase to damage taken. »

**Pourquoi cette source renforce la décision #S :** PoE Shock est un amplificateur
**universel** de dégâts reçus (all sources). Notre transposition au choc-D comme
amplificateur **ciblé sur la famille du poseur** n'est pas une trahison de PoE — c'est
une adaptation contextuelle cohérente. PoE peut être universel parce qu'il n'a pas de
système de DoT multi-famille qui crée un risque d'amplification adverse. Nous avons ce
système. Le ciblage par `dot_family` du poseur est la transposition correcte de la
**promesse de design** de PoE Shock (amplifie TON build) dans notre contexte multi-famille.

**Condition nécessaire maintenue** : le signal UI `shock_amplify {source, magnitude, famille}`
reste obligatoire (§3.4 roadmap v6). Sans lui, le ciblage `dot_family` est invisible
= profondeur non attributable = frustration Artifact (postmortems §4.4).

**Aucune raison de rouvrir #S.** Le litige est clos.

### 1.2 `--poison-frac` + `--no-weaken` avant P1 — ACCORD FORT, PRÉCISION SUR LE PÉRIMÈTRE

La promotion des deux mesures en P0.5 est correcte. La recherche STS2 (sts2-calculator.com
2026 : « Poison and Shiv are not competing posters. They are answers to different timing
problems ») illustre un point directement transférable : **poison dominant ≠ poison cassé
si l'on distingue ses axes**.

**Ce que la roadmap v6 fait bien :** elle traite la dominance poison comme possiblement
multi-causale (propagation + weaken). C'est l'approche correcte. La mesure des deux causes
séparément, **avant** de coder les paliers de type, évite d'amplifier un axe dominant
non diagnostiqué — erreur que PoE Wither a commise (source préservée du round 5 :
pathofexile.com/forum/view-thread/3870562).

**Précision sur le périmètre (non formulée dans v6)** : même après correction des deux
causes structurelles, poison conservera son axe de stacking multi-sources (N stacks
indépendants cap 8) qui est **par design** plus riche que le choc (1 axe séquentiel).
La mesure ne vise pas la parité — elle vise que l'écart ne dépasse pas un seuil de
dominance `> +1σ`. Un poison `+0.6σ` au-dessus de la médiane est sain (il est
structurellement riche) ; un poison `+1.5σ` est une méta cassée. La cible n'est pas
l'égalité, c'est la viabilité de toutes les familles face au poison dans un mix.

**Source** : Ludus (ojs.aaai.org/index.php/AAAI/article/view/21550) : méta saine = faible
σ de win-rate + haute entropie = **diversité de builds viables**, pas égalité des win-rates.

### 1.3 Seuils 2/4 sur 9 slots — ACCORD FORT, justification mécaniste étendue

La roadmap v6 (§5.1) justifie les seuils 2/4 par : sur 9 slots, un palier-6 consomme
67 % de la compo = pas de place pour un tank = front exposé. Ce round confirme avec
une source TFT officielle additionnelle.

**Learnings TFT Galaxies (teamfighttactics.leagueoflegends.com/dev/dev-teamfight-tactics-galaxies-learnings,
relu ce round)** : « Cybernetic required an early 3 and then you were locked into 6 or
you weren't playing it... Chrono may as well have been a 2 or 4-piece origin only... » —
les traits à seuil 6 frustrent les joueurs intermédiaires parce qu'ils créent une
**zone morte** entre le palier 2 (faible) et le palier 6 (impossible pendant les
rounds 3-6). Riot a explicitement retravaillé pour rendre « as many traits as possible
viable across all the stages of the game ». Sur 9 slots (vs 8-9 TFT), un palier-6 serait
encore plus contraignant.

**Verdict confirmé** : 2/4 est le bon choix. Il force la **diversité** (2 familles à 2
= 4 slots + 5 libres ; 1 famille à 4 = 4 slots + 5 libres) et correspond à la phase de
montée de slots (3→9) qui est notre courbe naturelle de run.

### 1.4 Architecture `grant_team` / `teamFlags` pour les paliers de type — ACCORD TECHNIQUE FORT

Le pattern est éprouvé (ash_maw, festering, pit_maw). Aucune raison de challenger.
La question que pose ce round (§2.5) est orthogonale : pas sur l'architecture, mais sur
l'**identité des paliers dans notre contexte de cocktails de DoT** — les teamFlags
peuvent-ils entrer en conflit si plusieurs paliers sont actifs simultanément ? La réponse
dans `engine-architecture.md` (hors-scope de ce round) est que les flags s'accumulent ;
il n'y a pas de conflit documenté. Retenu comme question ouverte Q1 plutôt que désaccord.

### 1.5 Bleed-4 = bleedPierceShield — ACCORD PARTIEL, tension non documentée identifiée

Le candidat orthogonal bleed-4 = `grant_team {bleedPierceShield}` (chaque tick bleed
retire 1 point de bouclier) a été adopté dans la roadmap v6 (§5.2). L'argument est
correct : il ne vide aucun T2 bleed (relus rounds 4-5 : razor_fiend=burst, blood_echo=
cadence, leech_thorn=épines).

**Accord sur l'orthogonalité.** Désaccord sur une tension de design non documentée
dans la roadmap v6. Voir §2.3.

---

## 2. DÉSACCORDS — ce qui est faible, faux ou insuffisamment étayé

### 2.1 DÉSACCORD FORT : Le compteur hybride 2-global/4-adjacence crée une "dead zone" de build identique au problème Cybernetic/Chrono de TFT

**Ce que la roadmap v6 dit** (§5.2) : le design hybride 2-global / 4-global+adjacence
est l'option privilégiée si `--position-variance > 0.05`. Au palier 4 (twist), la
condition d'adjacence s'ajoute au count global : `count(dot_family) ≥ 4` ET `≥1 paire
adjacente`. La mesure `--position-variance` tranche si la condition d'adjacence varie
selon le sigil.

**Pourquoi c'est insuffisant** :

La recherche TFT officielle Galaxies (teamfighttactics.leagueoflegends.com, relu ce round)
documente précisément le problème que l'hybride risque de créer : les traits qui exigent
**deux conditions simultanées** (nombre + autre facteur) créent des états où le joueur
a 3 unités du même type, vise le palier 4, mais n'a pas encore la paire adjacente —
ou a la paire adjacente mais manque la 4e unité. Cet état "presque-là mais bloqué sur
deux axes" est frustrant parce que **les deux conditions ne progressent pas ensemble**.

Dans notre cas : un joueur burn avec 3 unités burn et 0 paire adjacente sur carré (les
4 burn sont dispersés) doit soit :
- Acheter une 4e unité burn (axe count), OU
- Réarranger pour créer une paire adjacente (axe positionnement)

Ces deux actions **consomment des ressources différentes** (or vs slots mentaux). La
frustration n'est pas « je dois choisir » — c'est « je dois satisfaire deux conditions
hétérogènes simultanément pour un seul palier ». TFT a résolu ça en rendant la majorité
des traits à condition unique (le nombre suffit pour tous les paliers).

**Ce que la `--position-variance` ne mesure pas** : elle mesure si la position IMPACTE
le win-rate, pas si la condition d'adjacence au palier 4 crée une EXPÉRIENCE de
frustration. Un joueur peut être en état frustrant (3 unités + 0 adjacence) sans que
ça apparaisse dans les statistiques de win-rate (il finit quand même par avoir les 4
unités et réarranges — le twist s'active, il gagne ou perd).

**La signature du plateau-graphe est déjà capturée par les AURAS d'adjacence.** Les
auras build-résolues (shield_aura, miasma_acolyte, etc.) SONT la mécanique positionnelle
différenciatrice. Le palier de type n'a pas besoin de dupliquer cette couche. Un compteur
**global pur** aux deux seuils (2 et 4) est non seulement plus lisible — il est aussi
**plus spécifique à NOS contraintes** : nos auras d'adjacence représentent DÉJÀ la
profondeur positionnelle du type (un burn posé à côté d'un autre burn déclenche les auras
cross-burn). Un palier de type global = « combien de burn tu as » ; les auras = « où tu
les places ». Ce sont deux couches **orthogonales et cumulatives**, pas redondantes.

**Source** : TFT Galaxies learnings (ci-dessus) + diva-portal.org (étude qualitative 2025 :
« testers reported greater enjoyment due to goal-oriented gameplay, e.g. rerolling shop
or getting stronger units later on. This sense of 'gambling' when rerolling for synergies
suggests that the trait system not only adds strategic depth but also emotionally engages »)
— l'engagement vient du COUNT VISIBLE progressant vers le seuil, pas de la condition
d'adjacence cachée dans le count.

**Recommandation** : **trancher #D vers GLOBAL PUR pour les deux paliers (2 et 4)**.
La condition d'adjacence au palier 4 est une **complexité ajoutée sans payoff de profondeur
mesurable** (les auras couvrent déjà l'axe positionnement). La mesure `--position-variance`
reste utile pour CALIBRER les auras existantes, pas pour décider d'un hybride.

Cette recommandation entre en conflit avec la décision du round 5 qui maintenait le litige
#D « ouvert avec hybride comme option privilégiée si variance > 0.05 ». Ce round propose
de la TRANCHER vers le global. Voir Q2 pour la question de validation.

### 2.2 DÉSACCORD MOYEN : La décision #W (burn vulnérable aux boucliers = voulu ou accident) est un litige ouvert depuis le round 5 — ce round la TRANCHE

**Ce que la roadmap v6 dit** (§3.1, colonne H) : burn = « Aucun » counter aux boucliers
(absorbé par le bouclier). Décision #W notée comme litige ouvert : « burn-vuln-bouclier
voulu (payoff burn-4 = `burnIgnoreShield`) ou accident ? » — « À trancher à la spec
burn-4 ».

**Pourquoi ce litige devrait être tranché ICI, pas en P1** :

La décision #W n'est pas une question de spec du twist burn-4 — c'est une question de
**rôle archétypal du burn** dans l'écosystème des tanks. Si burn est vulnérable aux
boucliers par design, alors :
- Les 11 unités shield/tank constituent un **counter dur au burn** (burn fort = tank fort)
- L'archétype burn go-wide (spread à mort, faible HP front) est mécaniquement **fragile
  contre les défenses** = archétype punitif mais explosif
- Le twist burn-4 = `burnIgnoreShield` est le **keystone de commit** (je sacrifie la
  sécurité pour percer les boucliers) = identité forte

Si burn est vulnérable par ACCIDENT, le jeu possède une asymétrie invisible qui
punit les joueurs burn sans explication. L'écosystème des boucliers n'est pas de la
profondeur — c'est du noise.

**Verdict : VOULU, pas accident.** Argument mécaniste :

1. **Burn est la famille de damage-over-time qui DÉCROÎT automatiquement** (30%/s —
   00-state §3.1). C'est la famille la plus forte au DÉBUT du combat (haute intensité),
   la plus faible à la FIN (décroissance). Si burn ignorait les boucliers dès le départ,
   son profil temporel + l'absence de counter défensif le rendrait trivial à exploiter
   en early.

2. **Burn se propage à la mort** (aux voisins). La propagation est déjà une forme
   d'ignore-bouclier implicite : elle saute par-dessus les tanks pour toucher les carries
   derrière. Ajouter `burnIgnoreShield` de base doublerait l'avantage AoE de burn.

3. **La vulnérabilité aux boucliers = le COÛT de la propagation.** Burn est la famille
   avec le meilleur axe de spread ; en échange, elle est la seule inefficace contre
   les tanks. C'est un rock-paper-scissors propre : burn > carries, tank > burn, les
   autres familles percent les tanks via `ignoreShield`. Ce n'est pas une asymétrie
   invisible — c'est un système.

4. **Source Wayward Strategy 2024** (waywardstrategy.com/2024/03/20, relu ce round) :
   « counterplay functions when all options have measurable responses — when some options
   have no response, the system isn't counterplay, it's dominance ». Si burn ignore les
   boucliers, les tanks n'ont PAS de réponse au burn → dominance. Avec la vulnérabilité
   actuelle, le tank répond mécaniquement au burn (absorbe le damage) = counterplay sain.

**Action concrète** : FERMER le litige #W en actant que la vulnérabilité burn/bouclier
est **intentionnelle**. Conséquence : le twist burn-4 = `burnIgnoreShield` est un
**keystone de payoff** (commit total burn → contourne la défense) = identité forte
et lisible. À documenter dans la colonne H et dans la spec burn-4.

Cette décision RENFORCE l'identité des tanks : tanks = counter dur au burn, faible face
aux autres DoT (qui `ignoreShield`). C'est une identité claire et enseignable.

### 2.3 DÉSACCORD MOYEN : Le twist bleed-4 = bleedPierceShield crée une tension avec l'identité primaire du bleed (ralentir la cadence) — non documentée dans v6

**Ce que la roadmap v6 dit** (§5.2) : bleed-4 = « Décomposition » — `grant_team
{bleedPierceShield}` — chaque tick bleed retire 1 point de bouclier. Candidat adopté
depuis le round 5. Orthogonal aux T2 existants (razor_fiend=burst, blood_echo=cadence,
leech_thorn=épines).

**La tension non documentée** :

L'identité primaire du bleed est le **ralentissement de la cadence** ennemie (le bleed
ralentit les attaques adverses — 00-state §3.1, invariant synergies #22-32). C'est son
avantage défensif : ma cible saigne, elle frappe moins vite, mon tank survit plus longtemps.

Le twist bleed-4 = `bleedPierceShield` positionne bleed comme **counter-tank offensif**
(je perce les boucliers progressivement). Ces deux identités sont **orthogonales** mais
créent un problème de signal au joueur :

- Le joueur bleed au round 4-6 (3-4 slots, bleed établi) voit son bleed ralentir les
  ennemis → il valorise bleed pour sa défensive. Sa **lecture implicite** de bleed = outil
  de survie.
- Au round 8, il obtient bleed-4 (palier twist) → le bleed devient soudain un outil
  offensif contre les boucliers. La **bascule d'identité** n'est pas préparée par le
  chemin d'apprentissage.

Ce n'est pas un problème insurmontable, mais c'est un **besoin de signal UI explicite**
que la roadmap v6 ne mentionne pas : le palier bleed-2 devrait surligner l'axe cadence
(« tes cibles frappent plus lentement ») ET l'axe future (« au palier 4, tu perceras les
boucliers »). Sans ce signal, la bascule d'identité au palier 4 surprise le joueur.

**Note de design** : la tension n'invalide pas le candidat bleed-4 — elle demande une
exigence UI additionnelle. Candidat maintenu, mais avec le flag « signal UI palier-2 →
palier-4 obligatoire avant P1 ».

### 2.4 DÉSACCORD FAIBLE MAIS PRÉCIS : Les 12 synergies existantes ne couvrent pas les interactions ADJACENTES INTER-FAMILLE — gap structurel dans le chemin vers les synergies par TYPE

**Ce que la roadmap v6 dit** (§6.7, Grimoire Chapitre I) : 12 synergies dans
`tests/synergies.lua` = base du Grimoire Chapitre I (afflictions). Chapitre II = ~18
synergies de type (P1). Total ~30 synergies documentées.

**Le gap** : les 12 synergies actuelles couvrent les interactions INTRA-FAMILLE (choc-D
amplifie son propre DoT, contagion, propagation à la mort) et quelques INTER-FAMILLE
(bleed→rot consommé, poison→burn à 5 stacks, festering=cap levé équipe). Elles ne
couvrent PAS les interactions **adjacentes positionnelles inter-famille** — par exemple :
- Une unité burn ADJACENTE à une unité bleed : y a-t-il une interaction doublée ?
- Une unité poison avec aura `miasma_acolyte` (+50% poison aux voisins) ADJACENTE
  à une unité choc (statut choc appliqué, axe D) — l'amplification choc-D touchera-t-elle
  le tick poison amplifié par l'aura, ou le tick poison de base ?

Ces interactions **existent déjà dans le code** (les auras sont bakées au build,
`tickDots` s'exécute après les auras) mais elles **ne sont pas testées** comme synergies
nommées dans `tests/synergies.lua`. Ce sont des zones sans garde-fou de test (00-state §8).

**Pourquoi c'est important avant P1** : si les paliers de type ajoutent des teamFlags
(burn-2 → `burnIncTeam`, etc.) SANS tester leur interaction avec les auras adjacentes
existantes, on risque un cas de surcharge multiplicative non détecté. La colonne H
(`--position-variance`) mesure la VARIANCE de win-rate par sigil, pas les **cas-limites
d'interaction aura×type×adjacence** qui sont deterministes mais non couverts par le fuzz.

**Recommandation** : avant P1, ajouter 2-3 synergies au `tests/synergies.lua` :
1. Aura `miasma_acolyte` + palier poison-2 `poisonIncTeam` + tick cible : valider que
   l'accumulated ne dépasse pas le cap ×3.
2. Aura `shield_aura` (voisin) + twist bleed-4 `bleedPierceShield` : valider que le
   tick bleed retire 1 pt bouclier ET que l'aura se reconstruit correctement.
3. Choc-D axe `dot_family` + aura d'amplification (post `miasma`) : valider que l'ampli
   choc touche le tick aura-amplifié et non un tick fantôme.

**Coût** : ~3 tests dans `tests/synergies.lua`, 0 code moteur. Précondition de P1.

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Trancher #D vers GLOBAL PUR (2 et 4 sans condition d'adjacence) [HAUTE PRIORITÉ, P0.5]

**Quoi** : dans la spec §5.2 de la roadmap v6, remplacer « compteur hybride 2-global /
4-global+adjacence si `--position-variance > 0.05` » par :

- **Palier 2** = `count(dot_family) ≥ 2` n'importe où sur le plateau → bonus team.
- **Palier 4 (twist)** = `count(dot_family) ≥ 4` n'importe où sur le plateau → twist.
- **Les auras d'adjacence** représentent DÉJÀ la couche positionnelle du type (build-résolues,
  graphe du sigil). Pas de condition d'adjacence supplémentaire au palier 4.

**Pourquoi prioritaire** : la complexité hybride n'apporte pas de profondeur supplémentaire
PERÇUE (voir §2.1). Elle crée une dead zone de build documentée par TFT (Galaxies learnings).
La `--position-variance` peut être réorientée vers calibrer les auras existantes.

**Gain** : 2 invariants de test en moins (count=4+paire vs count=4 sans paire) ;
design plus lisible ; compatibilité avec le sigil croix (Q3 du round 5 était : croix
active difficilement l'adjacence-type → hostile aux types ; avec le global pur, aucun
sigil n'est hostile aux paliers de type).

**Source** : TFT Galaxies learnings (teamfighttactics.leagueoflegends.com, relu ce round)
+ diva-portal.org (engagement = count visible progressant vers seuil).

### P2 — Fermer le litige #W : burn vulnérable aux boucliers = INTENTIONNEL [HAUTE PRIORITÉ, avant spec burn-4]

**Quoi** : dans la doc P0.5 (§3.1, colonne H), acter :

```
Burn : AUCUN counter aux boucliers (absorbé) — INTENTIONNEL
  → burn = counter carry/faible-HP ; counter par tank = voulu (coût de la propagation)
  → twist burn-4 = burnIgnoreShield (keystone : commit burn → perce les boucliers)
```

**Conséquences directes** :
1. La spec burn-4 est débloquée (plus de litige à trancher « à la spec burn-4 »).
2. L'archétype tank est renforcé : counter dur au burn = identité claire.
3. Le Grimoire peut documenter la relation burn-tank dans le Chapitre I (synergies de
   contre existantes, pas de type).

**Source** : Wayward Strategy 2024 (waywardstrategy.com, relu ce round — counterplay
requires measurable responses for all options) + analyse mécaniste interne (§2.2).

### P3 — Ajouter 3 synergies adjacentes inter-famille à `tests/synergies.lua` avant P1 [PRIORITÉ MOYENNE, précondition P1]

**Quoi** : 3 cas de test nommés couvrant les interactions aura×palier-type×adjacence
qui ne sont pas encore testées (§2.4).

**Pourquoi avant P1** : le palier de type pose un teamFlag à `combat_start` APRÈS le
bake des auras d'adjacence. L'interaction ordre-de-résolution n'est pas testée. Si le
teamFlag `poisonIncTeam` (+20%) est appliqué AVANT que `miasma_acolyte` (+50% voisin)
ne soit bakée, l'accumulated peut diverger du cap ×3. Même si le code résout correctement,
l'invariant doit exister.

**Coût** : ~3 lignes de test + 1 scénario de build fixé (seed connue). 0 code moteur.

### P4 — Documenter la tension bleed-4 et le besoin de signal UI palier-2→palier-4 [PRIORITÉ BASSE, avant P1]

**Quoi** : dans la doc spec des twists (§5.2), ajouter sous bleed-4 :

```
NOTE DE DESIGN bleed-4 (bleedPierceShield) :
L'identité primaire du bleed au palier 2 = ralentir la cadence ennemie (défensif).
L'identité au palier 4 = percer les boucliers (offensif). La bascule d'identité
DOIT être anticipée par un signal UI au palier 2 :
"Au palier 4, ton bleed ronge les boucliers ennemis."
Sinon la bascule d'identité au palier 4 surprend le joueur et casse la lisibilité.
```

**Source** : Slay the Spire design (MegaCrit 2024 — synergy signaling : visual and
mechanical cues highlight potential combos).

### P5 — Proposition de cadrage POSITIF de la hiérarchie poison : counter-jeu inter-famille explicite [PRIORITÉ BASSE, doc P0.5]

**Quoi** : dans la colonne I de l'audit (contre quoi optimal), documenter les
**counter-jeux au poison** :

```
Counter au poison en positionnement : unités à cooldown court (bleed slow cadence
réduit l'accumulation de stacks en ralentissant les hits, PAS les ticks DoT — à
vérifier en sim) ; tank/taunt absorbe les hits (pas les ticks poison qui ignorent
les boucliers, mais réduit les sources de stacks si les hits appliquent le poison) ;
regen = seul counter-actif (plague_doctor).
```

**Pourquoi** : la hiérarchie poison > X est traitée comme un problème à corriger.
Le cadrage alternatif : poison est la famille de DoT la plus PROFONDE (3 axes) et
mérite d'être countrée activement plutôt que nerfée. Si les counters au poison
(regen, slow-cadence qui réduit l'application, tank qui filtre les hits) sont
LISIBLES et ACCESSIBLES, la dominance poison devient un ARCHÉTYPE à battre plutôt
qu'une anomalie. Cela transforme `--poison-frac` et `--no-weaken` de corrections
en DIAGNOSTICS d'équilibre entre un archétype riche et ses counters.

**Source** : Silent (Slay the Spire) — poison dominant mais countered par des builds
block-heavy qui réduisent l'accumulation (sts2-calculator.com 2026, relu ce round).
Le dominant STS est une référence de méta SAINE (poison dominant mais vaincu par
des counters accessibles).

---

## 4. QUESTIONS OUVERTES

### Q1 : Les teamFlags de paliers de type peuvent-ils entrer en conflit avec des transforms T3 qui posent les mêmes teamFlags ?

`festering` (`poisonNoCap`) et un palier poison-4 pourraient tous les deux poser des
flags poison. Si `festering` est présent ET le palier poison-4 est actif simultanément,
est-ce que les deux flags coexistent sans collision dans `teamFlags` de l'arène ?
L'architecture `grant_team` accumule les flags (00-state §3.1), mais la spec du palier
poison-4 (le twist) n'est pas encore définie — si le twist utilise le même flag
(`poisonNoCap`) que `festering`, il y a conflit de nommage.

**Précondition** : la spec des twists de palier 4 doit NOMMER ses teamFlags de sorte
qu'ils soient **distincts** des flags T3 existants. Exemple : `poisonIncTeam` (palier
type) ≠ `poisonNoCap` (festering T3). À vérifier avant P1.

### Q2 : La mesure `--position-variance` reste-t-elle utile si le design est global pur ?

Si #D est tranché vers global pur (P1 ci-dessus), `--position-variance` ne sert plus
à décider global vs adjacence. Mais la mesure reste utile pour :
- Calibrer si les AURAS d'adjacence existantes génèrent suffisamment de variance positionnelle
  pour que le plateau-graphe sigil soit un différenciateur réel (et pas seulement
  un décor topologique).
- Valider si le sigil anneau génère plus de variance positionnelle que le sigil carré
  (le plateau-graphe a 5 formes ; si la variance est homogène → les formes ne
  différencient pas le gameplay → problème de design sigil indépendant des types).

**Recommandation** : maintenir `--position-variance` mais reformuler son objectif :
« mesurer si les auras d'adjacence existantes créent une variance positionnelle
significative par sigil ». Si variance < 0.02 sur TOUS les sigils → les auras sont
trop faibles → les amplifier (non les paliers de type).

### Q3 : Le bleed ralentissant la cadence réduit-il L'APPLICATION de poison par les hits ennemis sur nos unités ?

L'identité bleed = ralentir la cadence **ennemie**. Si l'ennemi applique du poison
à nos unités via ses hits, le ralentissement de sa cadence réduit la fréquence
d'application de son poison. C'est une **synergie défensive inter-famille non documentée**
(bleed + poison adverse = synergie défensive contre le poison ennemi). Ce serait une
interaction intéressante à tester en sim (match bleed vs poison-enemy : le bleed réduit-il
la fréquence des stacks poison adverses sur nos unités ?) et à documenter dans la colonne I.

---

## 5. CE QUI N'EST PAS UN DÉSACCORD

- **Cap ×3 anti-snowball `DOT_CAP_MULT = 3`** : confirmé correct aux rounds précédents.
  Non re-challengé.
- **Architecture `dot_family` comme champ porteur + lint** : correcte et éprouvée.
- **Option C2 (`afflictionCount` ne compte que les dps réels)** : correction code-vérifiée
  au round 5, maintenue.
- **`--position-variance` promu P0.5** : maintenu, mais avec objectif reformulé (Q2).
- **Twist burn-4 = propagation EN COURS DE VIE (≠ propagation-à-la-mort)** : orthogonal
  confirmé ; non re-challengé.

---

## 6. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée | Priorité |
|---|---|---|---|---|
| Compteur hybride crée dead-zone de build (TFT Galaxies confirmé) | **FORTE** | Design P1 amplifie la frustration mid-tier au lieu de la résoudre | Trancher #D vers global pur — fermer litige | P0.5 → P1 |
| Litige #W ouvert = spec burn-4 bloquée + archétype tank ambigu | **FORTE** | Spec P1.5b bloquée, identité tank floue | Trancher #W : burn-vuln-bouclier = intentionnel | avant spec P1.5a |
| Synergies adjacentes inter-famille non testées (gap P1) | **MODÉRÉE** | Interaction aura×palier-type = zone sans garde-fou de test | Ajouter 3 synergies `tests/synergies.lua` avant P1 | précondition P1 |
| Tension identité bleed-4 (défensif→offensif) non documentée | **FAIBLE** | Signal UI manquant pour la bascule d'identité au palier 4 | Doc + flag UI signal palier-2→4 | avant P1 spec |
| Hiérarchie poison cadrée comme bug seulement, pas comme archétype | **FAIBLE** | Counter-jeux au poison non lisibles = frustration résiduelle après correction | Doc counters au poison dans colonne I | P0.5 doc |

---

## 7. Index des sources

**Web vérifié ce round :**

- PoE Shock — ne stacke pas, seul le plus fort s'applique (amplitude universelle) :
  [poewiki.net/wiki/Shock](https://www.poewiki.net/wiki/Shock)
- PoE Shock PoE2 — amplificateur universel, magnitude basée sur le dégât relatif :
  [mobalytics.gg/poe-2/guides/shock](https://mobalytics.gg/poe-2/guides/shock)
- TFT design pillars — mastery growth, trait synergy engagement :
  [teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-design-pillars-of-tft/](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-design-pillars-of-tft/)
- TFT Galaxies learnings — traits à double condition (dead zones) :
  [teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-galaxies-learnings/](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-galaxies-learnings/)
- TFT Magic n' Mayhem learnings — champion augments et condition d'activation :
  [teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-tft-magic-n-mayhem-learnings/](https://teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-tft-magic-n-mayhem-learnings/)
- Auto-chess trait + augment engagement study (diva-portal.org) :
  [diva-portal.org/smash/get/diva2:1980319/FULLTEXT02.pdf](https://www.diva-portal.org/smash/get/diva2:1980319/FULLTEXT02.pdf)
- Wayward Strategy 2024 — status effects et counterplay (réponses mesurables) :
  [waywardstrategy.com/2024/03/20/mind-control-stun-and-fire-oh-my-a-discussion-about-status-effects-in-real-time-strategy-games/](https://waywardstrategy.com/2024/03/20/mind-control-stun-and-fire-oh-my-a-discussion-about-status-effects-in-real-time-strategy-games/)
- STS2 — poison vs shiv, archétypes distincts (timing problem, pas style) :
  [sts2-calculator.com/blog/silent-poison-vs-shiv-the-split-that-actually-decides-the-run](https://sts2-calculator.com/blog/silent-poison-vs-shiv-the-split-that-actually-decides-the-run)
- Ludus equilibrage autobattler (faible σ / haute entropie = méta saine) :
  [ojs.aaai.org/index.php/AAAI/article/view/21550](https://ojs.aaai.org/index.php/AAAI/article/view/21550)

**Sources internes (références actives, lecture seule) :**

- `00-state.md` §3.1 (familles DoT, ignoreShield, teamFlags, aggro)
- `docs/research/effects-synergy-tiers.md` §3/§4 (template T1/T2/T3, counterplay)
- `ROADMAP-draft.md` v6 §3.1/§3.4/§3.5/§5.2 (audit 9-col, axe D, synergies par type)
- `round-05.md` §1.3/§1.11/§1.12/§3.4/§4 (litiges, adoptions, rejets)
- `rounds/r05-synergies-effects.md` §2.3/§2.4/§2.5 (hybride P3, bleed-4, boucliers)

**Sources rounds précédents conservées :**

- r04-synergies-effects.md §2.1 (bug d'identité choc, ordre fixe)
- r03-synergies-effects.md §2.2 (critère variance positionnelle, litige #D)
- r01-synergies-effects.md §1.4, r02-synergies-effects.md §2.1 (seuils 2/4)

---

## 8. Récapitulatif des demandes de fermeture de litiges

| Litige | Position ce round | Argument |
|---|---|---|
| **#D** (global vs hybride) | **TRANCHER vers GLOBAL PUR** | Dead zones TFT + auras couvrent déjà l'axe positionnement |
| **#W** (burn vuln-bouclier intentionnel ?) | **TRANCHER vers INTENTIONNEL** | Counterplay sain + coût de la propagation + twist burn-4 comme keystone |
| **#S** | Déjà clos round 5. Non re-ouvert. | PoE Shock confirmé (poewiki.net) |

---

*Round 06 rédigé le 2026-06-23. Lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
Piliers respectés. 32 invariants préservés. Litiges proposés à trancher ce round : **#D** (global pur
recommandé, contre le hybride du round 5) ; **#W** (burn-vuln-bouclier = intentionnel). Nouvelle
proposition : 3 tests inter-famille adjacence avant P1. Recherches web menées et sourcées.
Aucune modification du code ou des tests.*
