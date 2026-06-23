# Round 05 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 5/10 — challenge du brouillon v5 (`ROADMAP-draft.md`) et des synthèses
> rounds 1-4. Ce round lit les fichiers du repo en lecture seule, interroge le web,
> et **challenge point par point** les propositions de la roadmap actuelle.
>
> **Inputs lus** :
> - `BRIEF.md`, `ROADMAP-draft.md` v5, `00-state.md`, `round-04.md`
> - `rounds/r04-synergies-effects.md`
> - `docs/research/effects-synergy-tiers.md`, `docs/research/effects-balance-counterplay.md`
> - `docs/research/effects-dot-families.md` (référencé, non relu en détail ce round)
>
> **Recherche web menée** :
> - Autobattler positional adjacency vs global synergy design (ilogos.biz, bounty-bash.com)
> - TFT trait synergy engagement (tactics.tools, mobalytics.gg, eloking.com)
> - SAP adjacency bonus mechanics (superautopets.wiki.gg, a327ex.com)
> - PoE Shock mechanic stacking design (poewiki.net/wiki/Shock, mobalytics.gg/poe-2)
> - Counterplay PvP game design (Wagar, critpoints.net 2025)
> - Roguelite synergy threshold build identity (entaltostudios.com)
>
> **Garde-fous** : lecture seule du repo + web ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers async/déterministe/grimdark/procédural respectés.
> Ne modifie ni le code, ni les tests.

---

## 0. Angle d'attaque de ce round

Les rounds 1-4 ont consolidé cinq chantiers prioritaires et corrigé deux erreurs critiques
sur le code (plague_communion, feeding_frenzy). Ce round s'attaque à **ce qui reste fragile
dans la roadmap v5 spécifiquement sur la lentille synergies-effects**, après quatre rounds :

1. **Le litige #S (ciblage de l'ampli choc-D) est tranché trop vite** : la roadmap v5 le
   laisse « à décider en P0.5 avec #G », mais la décision a des conséquences structurelles
   sur l'identité du choc qu'il faut trancher ici — pas flotter en litige.
2. **Les synergies par TYPE sont manquantes d'une dimension critique** : le brouillon v5
   propose uniquement « global OU adjacence-type selon `--position-variance` ». Mais il y a
   un troisième design possible — le **compteur hybride à seuil d'adjacence** — qui n'a
   jamais été mis sur la table et qui est plus aligné avec notre plateau-graphe sigil.
3. **La hiérarchie poison > choc n'a qu'une cause mesurée (propagation-à-la-mort) mais deux
   causes structurelles** : la propagation ET le fait que le poison a trois axes indépendants
   (stacks / weaken / spread) là où le choc n'a qu'un axe séquentiel (condenser → décharger).
   L'axe D résout la lisibilité, pas le déséquilibre intrinsèque d'axes.
4. **Les boucliers et l'interaction adjacence×DoT ne sont pas assez challengés** : la
   roadmap v5 traite les boucliers comme un système secondaire, mais ils ont un impact
   structurel sur l'identité du choc-D et sur la viabilité du burn en late.
5. **Les twists de palier 4 ont des candidats incomplets** : le brouillon v5 valide
   burn/rot/poison mais oublie de proposer un twist bleed-4 (et de vérifier qu'il ne vide
   pas les T2 existants via la colonne F).

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 `--poison-frac` promu en P0.5 — ACCORD FORT, avec une précision sur le mécanisme

La promotion de `--poison-frac` de P3 à P0.5 (§3.5 roadmap v5) est correcte et nécessaire.
L'argument code est solide : `spread_*_on_death` propage les stacks aux voisins, et avec
`festering:poisonNoCap` (qui lève le cap de *stacks*, pas le cap d'output), une cascade peut
s'auto-amplifier indépendamment du `DOT_CAP_MULT = 3`.

**Pourquoi ça tient dans NOS contraintes :**
- Déterministe : `frac = p.frac or 1.0` dans l'op `contagion` est un paramètre data.
  Golden inchangé si le défaut reste 1.0. Zéro invariant touché.
- Async : la propagation est résolue dans la SIM, déjà capturable par le bus. Le snapshot
  ne capture pas les effets en cours de combat — aucun impact.
- La prescription « mesurer avant P1 » suit une logique causale correcte : si poison est
  structurellement > +1σ, un palier type poison +20 % amplifie une méta cassée avant le
  ranked. C'est une dépendance séquentielle réelle.

**MAIS précision non formulée dans v5 (§3.5)** : le `frac` à 50 % **ne résout pas**
l'axe de dominance intrinsèque du poison (3 axes vs 1 axe choc). Il réduit la cascade
propagation. Le brouillon v5 semble supposer que `frac=0.5` ramènerait poison à parité
structurelle avec choc — or même avec `frac=0.5` et aucune propagation-à-la-mort,
`poison` garde ses avantages de `weaken` (malus sur la valeur des capacités de la cible)
et de stacking multi-sources indépendant. Voir §2.1.

### 1.2 Signal UI obligatoire famille amplifiée (axe choc-D) — ACCORD FORT

Le signal UI sur `shock_amplify {source, magnitude, famille}` (§3.4 roadmap v5) est
**indispensable et pas optionnel**. L'argument du brouillon v5 tient : sans ce signal,
l'axe D crée une profondeur invisible (le joueur poison dont la cible reçoit un bleed
adverse voit son choc amplifier le bleed sans le savoir — frustation Artifact).

**Pourquoi ça tient dans NOS contraintes :**
- RENDER pur (écoute du bus), 0 SIM. Pas d'impact snapshot.
- C'est une **condition nécessaire pour que l'axe D soit une décision de build**, pas un
  artefact opaque. Celia Wagar (critpoints.net/2025/05/06 : « Building Counterplay for PvP
  Games ») : les systèmes asymétriques fonctionnent seulement si le joueur peut attribuer
  les résultats à ses choix. Un signal invisible = pas d'apprentissage = pas de contre.
- L'argument est renforcé par le pattern SAP (superautopets.wiki.gg/wiki/List_of_Strategies) :
  l'adjacence dans SAP crée de la valeur **parce que** les effets d'adjacence sont visibles
  et mémorisables. Un amplificateur invisible n'est pas une synergie — c'est du bruit.

### 1.3 `--position-variance` promu en P0.5 — ACCORD AVEC NUANCE

La décision de mesurer la variance positionnelle **avant** de coder les synergies par type
(P1) est correcte méthodologiquement. Elle évite de coder un compteur global en v0.10 et
de découvrir en v0.12 que l'adjacence-type était nécessaire.

**Nuance** : le critère `std_dev(win%) < 0.02 → global ; > 0.05 → adjacence` est binaire.
Voir §2.3 pour une proposition d'alternative hybride qui enrichit les deux cas.

### 1.4 Seuils 2/4 sur 9 slots — ACCORD FORT, justification mécaniste confirmée

La justification est correcte et maintenant ancrée dans le code : un palier-6 sur 9 slots
consomme 67 % de la compo, ne laissant pas de place pour un gravewarden (taunt, aggro=40)
— le front est immédiatement exposé par le ciblage déterministe colonne-avant. Le seuil
4 est **la limite économique du plateau**, pas une analogie TFT copiée.

Source confirmée : TFT Set 17 (mobalytics.gg/tft/synergies/classes) montre que les traits
à seuils 2/4 sont les plus répandus dans les compos viables précisément parce qu'ils
permettent le « flex » (deux traits actifs simultanément). Notre justification mécaniste
est plus forte que l'analogie TFT — elle est endogène à notre plateau.

### 1.5 Architecture `grant_team` / `teamFlags` pour les paliers — ACCORD TECHNIQUE

Le pattern `grant_team` posant des `teamFlags` à `combat_start` est éprouvé (ash_maw,
festering, pit_maw — tous vérifiés rounds précédents). Les paliers de type suivront le
même chemin. 0 nouvelle mécanique moteur. Golden-safe si le count `dot_family` est 0
quand la famille n'est pas présente. Aucune raison de challenger cela.

### 1.6 Twists de palier 4 : garde-fous #1/#2/#3 — ACCORD FORT

Les trois garde-fous (§5.2 roadmap v5) sont corrects :
- **#1** (pas sous-cas T3) : burn 4 = propagation en cours-de-vie ≠ no-decay de ash_maw.
  Distinction réelle et vérifiable dans le code.
- **#2** (pas vider T2) : colonne F de l'audit P0.5 = le bon outil. Source valide :
  effects-synergy-tiers.md §3.1 (le moule T1/T2/T3 distingue enabler vs payoff ; un palier
  4 qui duplique un payoff T2 = redondance, pas profondeur).
- **#3** (twist = `more` borné ou règle hors `Stats.resolve`) : confirmé par le calcul
  (kings_bowl + miasma + palier = 3.8, mais un `more` sur base 4 = 4 × 1.30 = 5.2 > cap 6
  potentiel — dépend du `base`). La specification AVANT le code est indispensable.

---

## 2. DESACCORDS — ce qui est faible, faux ou insuffisamment étayé

### 2.1 DESACCORD FORT : La roadmap v5 traite `--poison-frac` comme si c'était LA cause de `poison > choc`. Il y en a deux, et la seconde n'est pas adressée.

**Ce que le brouillon v5 dit** (§3.5) : mesurer `win_rate(poison)` à frac=1.0 puis
frac=0.5. Si le delta passe de `>+1σ` à `<+0.5σ` → activer frac=0.5 → poison résolu.
**Implicite du raisonnement** : la propagation-à-la-mort est LA cause dominante du
déséquilibre. Une fois corrigée, poison et choc sont sur un pied structurel équivalent.

**Pourquoi c'est insuffisant** :

Poison a **trois axes de valeur indépendants** :
1. **Stacking multi-sources** (N stacks indépendants, cap 8 normale ou illimité avec
   festering) — chaque source ajoute une contribution propre.
2. **Weaken** : malus sur la *valeur* des capacités de la cible. Cet axe est **unique à
   poison** (aucune autre famille ne réduit l'output ennemi de cette façon).
3. **Propagation-à-la-mort** (spread) — l'axe ciblé par `--poison-frac`.

Choc a **un axe séquentiel** : condenser (stacks sans effet) → décharger (burst sur un
tick DoT). Sa valeur est entièrement **différée et conditionnelle** à la présence d'un
DoT sur la cible. C'est un **amplificateur parasite**, pas une source de dégâts autonome.

Même avec `frac=0.5`, poison conserve les axes 1 et 2 entiers. Si la hiérarchie vient
principalement de l'axe weaken (malus output ennemi = avantage défensif non mesuré par
`win_rate(dégâts)` bruts), `--poison-frac` ne le détecte pas.

**Ce que le brouillon ne prescrit pas mais devrait** : mesurer la **contribution de
`weaken` séparément** dans la sim. Ajouter une config `--no-weaken` (désactiver l'op
weaken, N=200) et comparer `win_rate(poison)` avec et sans weaken. Si la différence est
`> 0.3σ`, l'axe weaken est une **seconde cause indépendante** de la dominance poison,
non adressée par le `frac`.

**Pourquoi c'est important avant P1** : si le palier poison-4 (twist) amplifie un axe
weaken non mesuré, le drapeau de sim peut valider `--poison-frac=0.5` (propagation
corrigée, `<+0.5σ`) mais la méta reste cassée parce que weaken+stacking reste `>+0.8σ`
sur les builds avec `chitin_drone` (weaken enabler). Le twist P1 amplifierait alors
un axe **déjà structurellement dominant** non détecté.

**Source** : PoE « the additive nature of Wither stacking was so dominant that it crowded
out other approaches... only measurable by isolating the debuff contribution » (pathofexile.com/forum/view-thread/3870562 — vérification : PoE Wither = debuff
d'affaiblissement qui s'accumule et dominait le late-game avant d'être plafonné à 15
charges). Notre weaken est structurellement analogue à Wither : un malus cumulatif sur
l'output ennemi, non capé séparément des stacks poison.

**Recommandation chiffrée** : ajouter `--no-weaken` aux **4 configs de sim choc-D** déjà
prévues (§3.4 roadmap v5). Coût : ~5 lignes dans `tools/sim.lua` (flag désactive l'op
weaken). Mesure : `win_rate(poison) avec vs sans weaken` sur N=200 seeds aléatoires.
Seuil d'alarme : delta > 0.3σ → **weaken est une seconde cause à corriger avant P1**.

### 2.2 DESACCORD MODÉRÉ : Le litige #S (ordre fixe vs `dot_family` du poseur) est flottant alors qu'il a une réponse correcte par le design

**Ce que le brouillon v5 dit** (§3.4, litige #S) : l'axe D doit-il amplifier la famille
de l'ordre fixe (première présente : burn > bleed > poison > rot) ou la `dot_family` du
poseur de choc ? « À trancher avant la spec de l'axe D. »

**L'argument pour l'ordre fixe** (v5) : simplicité d'implémentation, pas de lecture de
`unit.dot_family` à la décharge.

**Pourquoi l'ordre fixe est une mauvaise réponse de design**, sourcée :

Dans PoE, Shock amplifie **tous les dégâts reçus** (toutes sources) — c'est ce qui en
fait un amplificateur universel d'équipe. (poewiki.net/wiki/Shock : « causes the target
to take 20% increased damage from all sources »). Transposer directement : notre choc-D
amplifie le **premier tick dans l'ordre fixe** = implicitement burn-first = **la famille
qui absorbe les boucliers** (burn non ignoreShield, confirmé arena.lua:432). C'est la
famille la **moins efficace contre les tanks** qui est amplifiée en premier par défaut.

L'intention de design du choc-D est « condenser l'énergie, libérer une rafale ». Si un
joueur joue 4 choc + 4 poison, il construit autour du poison. L'ordre fixe amplifie le
bleed adverse ou le burn adverse en priorité — **l'opposé de la promesse**. C'est le
bug d'identité décrit dans r04-synergies §2.1.

**La solution correcte pour nos contraintes** :

L'axe D doit amplifier la **première famille `dot_family` identique à celle du poseur
de choc**. Si la cible n'a pas la famille du poseur, descendre dans l'ordre fixe (fallback).
Algorithme :
```
dot_family_shock = source.dot_family  -- déterminé au build, stable
for ordre_fixe in {burn, bleed, poison, rot} do
  if dots[ordre_fixe] présent sur cible then
    if ordre_fixe == dot_family_shock then
      amplifier ordre_fixe → break
    end
    -- sinon mémoriser comme fallback
  end
end
if aucun match → amplifier le premier fallback disponible
```

Coût additionnel : 1 lookup de `source.dot_family` dans `tickDots` (déjà disponible via
le `source` de l'op, si `dot_family` est posé en P0.5). **0 nouvelle structure de données,
0 invariant**. Signal UI communique la famille effective amplifiée (déjà prévu).

**Pourquoi c'est compatible avec NOS contraintes** :
- Déterministe : `dot_family` est une donnée statique du build (posée à `combat_start`,
  pas en combat). La résolution est déterministe.
- Async : pas d'impact snapshot (les `dot_family` ne sont pas capturés dans le snapshot
  v1 — mais quand ils le seront, ils sont des données build stables, golden-safe).
- Le fallback « premier disponible dans l'ordre fixe » préserve la lisibilité pour les
  builds sans affiliation (stat-sticks choc).

**Recommandation** : trancher #S vers « ciblage par `dot_family` du poseur + fallback ordre
fixe » dans la roadmap v5. Ce n'est pas plus complexe que l'ordre fixe pur — c'est l'ordre
fixe amélioré par une **vérification de priorité**. Retirer le statut de « litige » : c'est
une décision de design avec une réponse correcte selon la promesse exprimée.

### 2.3 DESACCORD MODÉRÉ : Le brouillon v5 ne propose que deux designs pour les synergies par type (global / adjacence-type). Il en existe un troisième plus aligné avec notre plateau-graphe.

**Ce que le brouillon v5 dit** (§5.2) : compteur **GLOBAL** par défaut en v0.10 ; bascule
vers **adjacence-type** si `--position-variance > 0.05`. Decision conditionnelle à la sim.

**Pourquoi c'est incomplet** :

La recherche sur les autobattlers confirme que les systèmes les plus engageants combinent
les deux layers (positional adjacency + global synergy) plutôt que de choisir l'un ou
l'autre (ilogos.biz : « modern autobattlers tend to combine both positional adjacency
mechanics and global trait/synergy bonuses creating layered strategic depth through
multiple decision layers »).

Le plateau-graphe 3×3 de The Pit a une propriété unique : le **sigil redéfinit la
topologie** (les arêtes d'adjacence changent selon la forme). Cela crée une opportunité
pour un troisième design :

**Le compteur HYBRIDE à seuil d'activation** :
- Le **palier 2** du type est un **compteur global** (2 unités de la famille n'importe
  où sur le plateau = bonus actif). Lisible, immédiat, accessible en early quand le
  plateau est peu peuplé.
- Le **palier 4** (twist) est un **compteur global + condition d'adjacence** : 4 unités
  de la famille ET au moins **une paire adjacente** (au sens des arêtes du sigil actif).
  L'adjacence **débloque** le twist, pas le palier.

**Pourquoi c'est supérieur dans nos contraintes** :
1. **Lecture du palier 2** : un joueur early (3-4 slots, boutique T2) comprend « 2 du
   même type = bonus ». Pas de confusion sur les arêtes. Compatible avec la carte de
   risque (§2.2 roadmap v5) qui surligne déjà les arêtes.
2. **Profondeur du palier 4** : la condition d'adjacence pour le twist crée une **décision
   de placement non-triviale** (dois-je sacrifier un slot de front pour coller deux
   unités burn adjacentes sur le sigil anneau ?). C'est exactement la valeur du
   plateau-graphe — la topologie est une décision, pas un décor.
3. **La variance positionnelle mesurée par `--position-variance`** s'applique
   **exclusivement au twist** (palier 4). Le palier 2 est global et n'est pas influencé
   par le sigil → la mesure est plus informative (elle teste si la condition d'adjacence
   du twist varie selon le sigil, pas si le compteur global l'est).
4. **Un archétype de sigil** : l'anneau (archétype « propagation en chaîne ») active
   plus naturellement les adjacences. Le carré (équilibre générique) a des adjacences
   plus diverses. Le twist adjacence+type donne au sigil un sens **mécanique** au-delà
   du visuel. C'est la fusion annoncée dans CLAUDE.md §3 : « la forme EST le graphe
   de synergies ».

**Limite** : le compteur hybride est plus complexe à tester (le test de palier 4 doit
vérifier l'état des arêtes actives, pas juste le count). Ajouter 2 invariants : (a) si
count(type) ≥ 4 ET ≥1 paire adjacente → `teamFlag` palier posé ; (b) si count(type) ≥ 4
MAIS aucune paire adjacente → palier 2 actif seulement, twist absent.

**Recommandation** : substituer au litige global/adjacence le **design hybride 2-global /
4-global+adjacence** dans la roadmap v5. La mesure `--position-variance` reste utile pour
calibrer **la condition d'adjacence du twist** (sur quel sigil la condition est-elle
naturellement activable ? → gating organique par sigil, non-explicit).

**Source** : SAP (superautopets.wiki.gg/wiki/The_Basics) : le positionnement est une
couche de décision **additionnelle** à la sélection d'équipe, pas alternative. L'adjacence
y crée de la valeur par son **interaction visible** avec des effets spécifiques (not a
shared multiplier). Notre hybride applique le même principe au palier 4 seulement.

### 2.4 DESACCORD FAIBLE MAIS PRÉCIS : Le twist bleed-4 n'est pas spécifié dans le brouillon v5 (§5.2)

**Ce que le brouillon v5 liste** : burn-4 (propagation en cours-de-vie), rot-4 (amputation
HP final), poison-4 (axe autre que slow). **Bleed-4 est absent.**

**Les T2 bleed existants** (à croiser en colonne F) :
- `blood_echo` (rang-3) : buff de cadence aux alliés via hit-bleed sur la cible. Axe
  de buffe d'équipe.
- `razor_fiend` (rang-3) : aggravate (burst bleed). Axe de burst conditionnel.
- `leech_thorn` (rang-3) : bleed + épines. Axe défensif/lifesteal hybride.

**Le twist bleed-4 doit être** : une règle qui n'est **pas** un burst bleed (vide
razor_fiend), **pas** un buffe de cadence (vide blood_echo), **pas** des épines (axe
défensif, leech_thorn). Candidat orthogonal (non proposé dans la roadmap) :

**Bleed-4 = « Décomposition » : chaque tick bleed retire 1 stack de bouclier** — le
bleed ronge le bouclier progressivement. Logique grimdark (le sang corrode l'armure) ;
orthogonal aux T2 existants ; crée un counter explicite aux 11 unités shield/tank sans
les invalider (un seul tick par tick bleed — lent, pas instantané). C'est une règle
d'équipe (`grant_team {bleedPierceShield = true}`) qui modifie `damage()` dans `tickDots`
pour bleed (ajouter `ignoreShield = bleedPierceShield` quand actif). **0 axe T2 vidé.**

**Pourquoi l'absence dans la roadmap est problématique** : si le twist bleed-4 n'est pas
spécifié avant P1, le développeur devra l'inventer pendant le code — sans avoir vérifié
la colonne F (§3.1). Le risque de vider un T2 en dernière minute est réel et évitable.

**Recommandation** : ajouter **bleed-4 = bleedPierceShield** comme candidat orthogonal
dans la spec des twists P1 (§5.2). Vérifier en colonne F : aucun T2 bleed actuel n'a
cet axe de « pénétration graduelle du bouclier ». À valider en Config D de la sim.

### 2.5 DESACCORD FAIBLE : Le rôle des boucliers dans l'écosystème des DoT est sous-traité dans les synergies

**Ce que le brouillon v5 dit des boucliers** : ils sont mentionnés dans la Config D (choc
vs tank+bouclier) et dans les 11 unités shield/tank comme « enablers transversaux ». Mais
le brouillon v5 ne répond pas à la question systémique : **quelle famille a un counter
naturel aux boucliers, et est-ce suffisant ?**

**État actuel** (00-state §3.1) :
- Burn : **non** ignoreShield → absorbé par le bouclier. Counter naturel : aucun contre
  les boucliers statiques.
- Bleed, Poison, Rot : `ignoreShield = true` → ignorent les boucliers. Ils rendent les
  tanks partiellement inutiles (15 unités shield/tank = ~18 % du pool).
- Choc : en axe D, amplifie un tick DoT → bleed/poison/rot ignorent les boucliers, donc
  l'ampli est effective. Burn non.
- `strip_shield` existe (`ops.lua`) comme op dédié.

**Le problème** : les 3 familles qui ignorent les boucliers (bleed, poison, rot) rendent
l'investissement dans les 11 tanks/shields partiellement inutile contre elles — pas du
counterplay, de l'annulation. Le résultat : le « late game archétype tank » n'est viable
que contre burn ET choc (via l'axe D avec tick burn), pas contre les 3 autres familles.

**Ce n'est pas du counterplay symétrique** (rock-paper-scissors) — c'est une asymétrie qui
favorise les DoT-ignoreShield dans un meta où les boucliers sont nombreux. Wagar (critpoints.net
2025) : « counterplay functions when all options have measurable responses — when some
options have no response, the system isn't counterplay, it's dominance ».

**Recommandation** : dans l'audit P0.5 (§3.1), ajouter une **colonne H « contre-bouclier »**
à la grille 6-colonnes :
- Burn : aucun — vuln. (marqué rouge, contre voulu ?)
- Bleed, Poison, Rot : `ignoreShield` — passe toujours (marqué vert — trop dominant ?)
- Choc-D : amplifie le tick ; si premier tick = burn → ampli partiellement absorbée ;
  si tick = bleed/poison/rot → totalement effective (marqué mixte).

Décision design à documenter : est-ce que **burn vulnerabilité aux boucliers est un
contre voulu** (les tanks countern burn = archétype burn go-wide fragile contre défenses)
ou un accident de code ? Si voulu → le documenter comme contre explicite dans les types P1
(burn-4 donne `grant_team {burnIgnoreShield = true}` = supprimer la vulnerabilité = payoff
du commit burn-4). Si accidentel → corriger maintenant.

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Ajouter `--no-weaken` à la suite de sim P0.5 pour mesurer la seconde cause de `poison > choc` [HAUTE PRIORITÉ, P0.5]

**Quoi** : dans `tools/sim.lua`, ajouter `--no-weaken` (désactive l'op `weaken` dans les
effets poison — ex. `chitin_drone`). Mesurer `win_rate(poison)` avec/sans weaken sur N=200
seeds aléatoires (même pool que `--poison-frac`). Comparer le delta.

**Seuil d'alarme** : si `delta(win_rate) > 0.3σ` entre avec-weaken et sans-weaken →
**weaken est une seconde cause de dominance** à corriger avant P1. Levier : réduire le
malus de weaken de N % → sim até `delta < 0.2σ`.

**Coût** : ~5 lignes dans `tools/sim.lua` (flag conditionnel sur l'op weaken). 0 invariant.
Golden inchangé (le golden build actuel n'inclut pas de build poison complet).

**Pourquoi prioritaire** : si on corrige `--poison-frac` mais pas weaken, et qu'on code
P1 sur cette base, les paliers type poison amplifient toujours une famille structurellement
dominante sur l'axe weaken. La correction est chirurgicale et bon marché — la rater est
coûteuse (refonte de paliers après P1).

**Source** : PoE Wither/stacking (pathofexile.com/forum/view-thread/3870562 — plafonner
le debuff d'affaiblissement pour ne pas dominer structurellement les autres approches).

### P2 — Trancher le litige #S vers « ciblage par `dot_family` du poseur + fallback ordre fixe » [HAUTE PRIORITÉ, P0.5]

**Quoi** : dans la spec de l'axe D (§3.4 roadmap v5), remplacer « À trancher avant la spec »
par la décision tranchée : l'axe D amplifie la **famille `dot_family` du poseur de choc** si
elle est présente sur la cible ; sinon fallback sur le premier tick de l'ordre fixe.

**Implémentation** : dans `tickDots`, à l'insertion de l'axe D :
```lua
local family = source and source.dot_family  -- lire la famille du poseur de choc
local target_dot = nil
-- 1. chercher la famille du poseur sur la cible
if family and u.dots[family] and u.dots[family].stacks > 0 then
  target_dot = family
end
-- 2. fallback : premier disponible dans l'ordre fixe
if not target_dot then
  for _, f in ipairs({"burn","bleed","poison","rot"}) do
    if u.dots[f] and (f == "burn" and u.dots.burn > 0 or u.dots[f].stacks > 0) then
      target_dot = f ; break
    end
  end
end
-- 3. amplifier target_dot si trouvé
if target_dot then ... end
```
Coût : lecture d'un champ `dot_family` statique. 0 invariant moteur.

**Gain** : la promesse de design est vraie. Un joueur poison-choc amplifie le poison de
sa cible. Un joueur burn-choc amplifie le burn. Le signal UI (§3.4) est alors informatif
ET attendu, pas surprenant.

### P3 — Substituer au design global/adjacence le compteur HYBRIDE 2-global / 4-global+adjacence [PRIORITÉ MOYENNE, P1]

**Quoi** : remplacer le litige #D (global vs adjacence-type) par une décision tranchée :

- **Palier 2** = compteur global (`count(dot_family) >= 2` n'importe où sur le plateau).
  Bonus team `+20 % [PH]` de la famille. Immédiat, lisible, early-game.
- **Palier 4 (twist)** = compteur global ET condition d'adjacence (au sens du sigil actif) :
  `count(dot_family) >= 4` ET `exists edge in shapes[shape].edges where
  units[edge.a].dot_family == type AND units[edge.b].dot_family == type`.
  Twist = règle `more` bornée (§5.2 garde-fou #3).

**Calibration par `--position-variance`** : la sim mesure sur quel sigil la condition
d'adjacence est naturellement activable (anneau : très facile ; ligne : moyen ; carré :
facile ; croix : difficile ; diamant : variable). → gating organique : le sigil anneau
active plus naturellement les twists adjacence-type → archétype « propagation en chaîne +
type » est plus facile sur l'anneau. C'est la fusion type × sigil sans créer de règles
explicites.

**Tests à ajouter** : invariant (a) count=4 ET adjacence → twist actif ; (b) count=4 MAIS
aucune paire adjacente → twist absent.

**Source** : ilogos.biz « modern autobattlers combine both positional adjacency AND global
synergy... layered strategic depth » ; SAP adjacency « creates value through visible
interaction with specific effects, not as a shared multiplier ».

### P4 — Spécifier bleed-4 = bleedPierceShield et l'ajouter à la spec P1 [PRIORITÉ MOYENNE, avant P1]

**Quoi** : ajouter à §5.2 roadmap v5 le candidat **bleed-4 = « Décomposition » : chaque
tick bleed retire 1 point de bouclier** (teamFlag `bleedPierceShield`). Vérifier en colonne
F de l'audit P0.5 qu'aucun T2 bleed actuel n'a cet axe.

**Gain** : complète la liste des twists par famille (burn, bleed, rot, poison sont tous
spécifiés). Évite l'improvisation en cours de code P1. Crée un counter bouclier **lent et
prévisible** (archétype bleed = « saigner lentement jusqu'à traverser l'armure »).

**Sim** : Config D (choc vs tank+bouclier) peut couvrir ce cas aussi : ajouter une
configuration bleed-4-actif vs `ward_weaver` (shield périodique). Mesurer TTK.

**Source** : effets-synergy-tiers.md §4 (twist = enabler + 1 interaction qui consomme/
exploite une condition) ; la condition ici = « bouclier présent sur la cible » ; l'action
= « consommer 1 point de bouclier ».

### P5 — Documenter la colonne H « contre-bouclier » dans l'audit P0.5 [PRIORITÉ BASSE]

**Quoi** : dans la grille 6-colonnes d'audit (§3.1 roadmap v5), ajouter une **colonne H**
(7e colonne) : « counter au bouclier » — Aucun / IgnoreShield / Partiel.

| Famille | Colonne H |
|---|---|
| Burn | Aucun (absorbé) |
| Bleed | IgnoreShield (toujours) |
| Poison | IgnoreShield (toujours) |
| Rot | IgnoreShield (toujours) |
| Choc-D | Partiel (si premier tick = burn → absorbé partiellement) |

Décision design annexée : burn vulnérabilité aux boucliers = **contre voulu** (à documenter)
ou **accidentel** (à corriger). Si voulu → burn-4 twist = `burnIgnoreShield = true` (payoff
du commit burn). Si accidentel → corriger burn dans `tickDots`.

**Coût** : documentation uniquement. 0 code. Décision editoriale.

---

## 4. QUESTIONS OUVERTES

### Q1 : Le weaken est-il un axe balancé par rapport à son coût en slots ?

`chitin_drone` (rang-2, `op=poison, weaken`) pose le weaken sur la cible. C'est une unité
rang-2 (coût=2) qui réduit l'output ennemi ET pose des stacks poison. C'est
fonctionnellement **une enabler double** (axe stacking ET axe weaken) dans un slot rang-2.
Est-ce un outlier de valeur par rapport aux autres rang-2 ? L'audit P0.5 colonne E doit
répondre.

### Q2 : Le compteur hybride (P3 ci-dessus) est-il compatible avec les transforms T3 qui posent des teamFlags ?

Les T3 comme `festering` (`poisonNoCap`) et `ash_maw` (`burnNoDecay`) posent des
teamFlags. Le twist palier-4 poisserait aussi un teamFlag (`bleedPierceShield`, etc.). Un
build T3 + palier-4 actif a deux teamFlags simultanés. Est-ce qu'ils peuvent entrer en
conflit (ex. `poisonNoCap` du T3 festering + twist palier-4 poison) ? À vérifier que les
teamFlags s'accumulent correctement dans `combat_start` sans collision.

### Q3 : Le sigil croix (mono-carry extrême) active-t-il naturellement le twist adjacence-type ?

La croix a un noyau central + branches isolées (00-state §2.3). Les branches sont
**non-adjacentes entre elles** (sauf via le noyau). Pour activer le twist 4-global+adjacence
sur le sigil croix, les 4 unités du même type doivent être soit toutes dans le noyau+branches
adjacentes au noyau, soit 2 branches adjacentes au noyau. En pratique, le sigil croix
**active difficilement** le twist adjacence — ce qui en ferait un sigil naturallement hostile
aux twists de type. Est-ce cohérent avec « 1 forme = 1 archétype » ?

### Q4 : Les auras build-résolues scalent-elles avec les paliers de type ?

`shield_aura` scale avec le niveau via `LEVEL_MULT` (00-state §3.1). Si le palier-2
du type poison donne `+20 % poisonInc` en teamFlag, et qu'une aura `miasma_acolyte`
donne `+0.5 poisonInc` aux voisins, les deux s'accumulent en `increased` (additifs,
déterministe). Mais si le palier-4 donne un `more` (twist), le cumul `increased_total ×
more` peut sortir du cap. C'est le litige #B. La question ici : est-ce que les auras
de niveau 3 (multiplié ×3.0 par `LEVEL_MULT`) + palier-4 `more` est un cas de dépassement
de cap documenté dans la spec des twists ?

---

## 5. CE QUI N'EST PAS UN DÉSACCORD

- **`dot_family` comme champ porteur + lint** : confirmé correct (r04, non réver-ifiable
  ce round sans code source direct, mais stable dans l'ancrage).
- **Cap ×3 anti-snowball sur l'output** : formule confirmée par les rounds précédents.
  Non re-challengé.
- **Déprioritisation reliques F** (drapeau hypergéométrique) : hors-lentille ce round.
- **Le choc-D dans `tickDots`, 0 conflit avec `hit()`** : confirmé rounds 3-4.
- **`forked_tongue` deadline post-#G** : la relique choc est à définir après l'axe D.
  La logique tient.

---

## 6. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée | Priorité |
|---|---|---|---|---|
| `--poison-frac` seul ne mesure pas l'axe weaken (2ème cause de dominance) | **FORTE** | Types P1 amplifient weaken non mesuré = méta cassée | Ajouter `--no-weaken` aux 4 configs sim | P0.5 |
| Litige #S flottant : ordre fixe vs `dot_family` poseur (réponse existe) | **FORTE** | Promesse de design fausse si ordre fixe pur | Trancher vers `dot_family` + fallback | P0.5 |
| Design global/adjacence binaire : compteur hybride absent | **MODÉRÉE** | Sigil non exploité dans les types ; profondeur manquée | Hybride 2-global / 4-global+adjacence | P1 |
| Twist bleed-4 non spécifié dans v5 §5.2 | **MODÉRÉE** | Risque de vider un T2 en cours de code P1 | Spécifier bleedPierceShield avant P1 | avant P1 |
| Boucliers : asymétrie DoT ignoreShield non documentée comme décision design | **FAIBLE** | Contre-bouclier de burn voulu ou accidentel ? | Colonne H dans l'audit P0.5 | P0.5 doc |

---

## Index des sources

**Web vérifié ce round :**

- PoE Shock — amplifie tous les dégâts de la cible, ne stacke pas (seul le plus fort s'applique) :
  [poewiki.net/wiki/Shock](https://www.poewiki.net/wiki/Shock)
- PoE Wither/debuff — plafonner le debuff d'affaiblissement pour éviter la dominance structurelle :
  [pathofexile.com/forum/view-thread/3870562](https://www.pathofexile.com/forum/view-thread/3870562)
- TFT Set 17 synergies seuils 2/4 (flex builds dominants) :
  [mobalytics.gg/tft/synergies/classes](https://mobalytics.gg/tft/synergies/classes)
- SAP positionnement — l'adjacence crée de la valeur par interaction visible, pas multiplicateur :
  [superautopets.wiki.gg/wiki/The_Basics](https://superautopets.wiki.gg/wiki/The_Basics)
  [superautopets.wiki.gg/wiki/List_of_Strategies](https://superautopets.wiki.gg/wiki/List_of_Strategies)
- Autobattler combinant adjacence positionnelle + synergies globales :
  [ilogos.biz/auto-battler-game-development-guide/](https://ilogos.biz/auto-battler-game-development-guide/)
- Celia Wagar — Counterplay PvP : le counterplay exige des réponses mesurables pour tous les options :
  [critpoints.net/2025/05/06/building-counterplay-for-pvp-games/](https://critpoints.net/2025/05/06/building-counterplay-for-pvp-games/)
- Roguelite transparency : si les synergies sont opaques, le joueur ne peut pas expérimenter :
  [entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/)
- PoE 2 Shock explained (amplificateur universel, toutes sources) :
  [mobalytics.gg/poe-2/guides/shock](https://mobalytics.gg/poe-2/guides/shock)

**Sources internes (références actives, lecture seule) :**

- `00-state.md` §3.1 (familles DoT, ignoreShield, teamFlags)
- `docs/research/effects-synergy-tiers.md` §1.1/§3 (moule T1/T2/T3, twist vs transform)
- `docs/research/effects-balance-counterplay.md` §1.4/§1.5 (stacking DoT, counterplay déterministe)
- `ROADMAP-draft.md` v5 §3.4/§3.5/§5.2 (axe D, poison-frac, types)
- `round-04.md` §1.1/§1.4/§1.5 (corrections code, promos P0.5)

**Sources rounds précédents conservées :**

- r04-synergies-effects.md §2.1 (bug d'identité choc×burn, ordre fixe)
- r03-synergies-effects.md §2.2 (critère variance positionnelle, litige #D)
- r01-synergies-effects.md §1.4, r02-synergies-effects.md §2.1 (seuils 2/4 confirmés)

---

*Round 05 rédigé le 2026-06-23. Lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
Piliers respectés. 32 invariants préservés. Litiges tranchés ce round : **#S** (ciblage
axe-D → `dot_family` poseur + fallback). Litiges enrichis : **#D** (global vs adjacence →
hybride 2-global / 4-global+adjacence proposé). Critiques nouvelles : **weaken comme 2e
cause de dominance poison** (non mesurée dans v5) ; **bleed-4 manquant dans spec twists** ;
**asymétrie bouclier non documentée comme décision design**. Aucune modification du code ou
des tests.*
