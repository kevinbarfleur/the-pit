# R02 — Critique adversariale, lentille RELIQUES (round 2/10)

> **Round** : 2/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Cibles** : `ROADMAP-draft.md` (brouillon #2, integre round 1) + `round-01.md` (synthese).
> **Sources internes verifiees ce round** : `src/data/relics.lua` (21 reliques, lu ligne par
> ligne), `src/combat/arena.lua:243-290` (plagueAmp, secondBreath, invulnT), `src/effects/
> ops.lua:22-32` (DOT_CAP_MULT, BLEED_DPS_CAP, ampDps), `docs/research/relics-design.md`
> (taxonomie, principes, carte archetype→relique).
> **Garde-fou absolu** : lecture seule du repo. Ce fichier n'edite que `docs/roadmap-lab/`.
> Piliers : async snapshots / sim deterministe seedee / DA grimdark / pixel art procedural.
> Sources citees par URL ou fichier+ligne pour chaque affirmation.

---

## 0. TL;DR — challenge cle en 3 phrases

Le brouillon #2 (P1.5) a correctement reclasse la completude des reliques en priorite ante-ranked,
mais il laisse intacte une confusion fondamentale : **sans downside possible (principe #2 de
relics-design.md), la condition d'activation est le SEUL levier qui rende une relique build-defining
— or le brouillon n'exige cette condition que pour deux reliques specifiques, laissant les 17 autres
soit universelles (pick-auto), soit non-verifiees**. Par ailleurs, le brouillon traite la question
choc-amplification comme bloquee par un probleme de "plomberie", alors qu'une lecture attentive de
`arena.lua:249-254` revele que `plagueAmp` (hors-cap, confirme) applique un `more` en dehors du
registre d'ops standard — le meme mecanisme pourrait servir un `shockAmp` sans nouveau op : c'est
une opportunite manquee. Enfin, la garantie de "pertinence de build" (P1.5 §5.4) telle que formulee
dans le brouillon est incassable — je propose un critere operationnel plus strict et moins couteux.

---

## 1. Accords — ce qui tient (avec le POURQUOI pour nos contraintes specifiques)

### 1.1 ACCORD FORT — Reclassement P1.5 : completude AVANT ranked (brouillon §5)

**Ce que le brouillon dit** : les trous d'archetype verifies (wide=`swarm_logic` absent, shield pur,
choc sans ampli mid-tier) doivent etre combles AVANT de construire le ranked.

**Pourquoi ca tient** : le raisonnement du synthese round-01 (§1.9) est mecanique, pas stylistique.
Un ranked mesurant le "skill de build" sur des offres 1-parmi-3 dont 1/3 est toujours morte pour
l'archetype courant ne mesure pas le skill — il mesure la variance de l'offre. C'est documente :
dans TFT, les "dead choices" viennent du desalignement offre/build, pas de la rarete
(teamfighttactics.leagueoflegends.com/en-us/news/game-updates/augments-augmented/ — Riot documente
explicitement que l'augment "Anything goes" (pick-any) est le signe d'un systeme mal calibre).

**Pourquoi ca tient specifiquement pour l'async** : dans un jeu live (TFT), une offre morte peut
etre "attendue" (l'adversaire voit aussi une mauvaise offre). Dans The Pit, chaque offre est
evaluee en solo, sans pression — une offre morte n'est pas une tension, c'est juste du bruit.
L'async amplifie le probleme des dead choices.

**Condition** : le reclassement P1.5 est sain si et seulement si les reliques ajoutees ont elles-
memes un foyer d'archetype verifiable (relics-design.md §1 principe #4). Ajouter `swarm_logic` sans
verifier sa condition de gating (slots ouverts ≥ 5) — comme signale dans r01-relics.md §Q3 — creerait
une relique receivable au round 3 qui est inerte pendant 2-3 rounds de plus. Le brouillon mentionne
ce gating (§5.1 : "gating par slots ouverts (≥5 slots, sinon inerte)") — accord, mais a verifier
que `rollRelicChoices` peut implementer ce filtre sans violer l'invariant #3 (meme seed+wins+compo
→ meme offre, §5.4).

**Source** : teamfighttactics.leagueoflegends.com/en-us/news/game-updates/augments-augmented/ ;
r01-relics.md §Q3 ; relics-design.md §1 principe #4 ; ROADMAP-draft.md §5.1-5.4.

### 1.2 ACCORD — Garantie de pertinence de build (§5.4) — meilleure que "tier A/B"

**Ce que le brouillon dit** : remplacer "≥1 relique de tier ≤ 2" par "≥1 des 3 reliques a son
type-cible present sur le plateau courant".

**Pourquoi ca tient** : c'est la bonne direction. Les reliques A (stats plates) de The Pit NE SONT
PAS universelles comme les "cheap trinkets" de HS:BG : `carapace` (+8 HP) n'est pas utile pour un
build tall (3 unites × 8 HP = +24 HP de pool, marginal) ; `whetstone` (+15% cadence) n'est pas
utile pour un build bleed ou le slow EST la synergie. La garantie par tier est defectueuse.

**MAIS (voir §2.2)** : la formulation operationnelle du brouillon a un probleme de robustesse
que je conteste ci-dessous.

**Source** : hs-battlegrounds.md §8.3 ; relics.lua (lecture directe, valeurs) ; ROADMAP-draft §5.4.

### 1.3 ACCORD — `plagueAmp` hors-cap = voulu, pas un exploit (confirme)

**Ce que le round-01 a tranche** (§2.5) : `arena.lua:252` applique `plagueAmp` via un `more`
**apres** le cap `DOT_CAP_MULT = 3` de `ops.lua:22`. Le synthese a raison : c'est un comportement
voulu de la couche stats (`(base+Σflat)(1+Σinc)·Π(1+more)`), comme documente dans `00-state.md §3`.

**Ce round confirme** : la verification directe de `arena.lua:243-290` (lu ce round) montre que
`plagueAmp` s'applique en ligne 252, AVANT le calcul de `raw` (l.260) mais APRES les checks
`invulnT` et `dmgReduce`. C'est une sequence : invuln → plagueAmp → dmgReduce → bouclier → hp.
Aucun emballement non controle puisque `afflictionCount >= 2` gate dur (et la relique n'est
servie qu'en late, tier 4).

**Implication pour ce round** : le meme pattern `more` applique directement dans `Arena:damage`
peut servir pour un `shockAmp` — voir §2.3 ci-dessous. Ce n'est pas un probleme, c'est un patron
d'implementation reutilisable.

**Source** : `src/combat/arena.lua:243-262` (lecture directe ce round).

### 1.4 ACCORD — Migration runOp vers le marchand, pas de bricolage (§5.3)

**Ce que le brouillon dit** : les 3 reliques F (`carrion_ledger`, `black_summons`, `beggars_lantern`)
migrent vers le marchand /3 combats quand il sera code ; pas de separation intermediaire dans
`rollRelicChoices`.

**Pourquoi ca tient** : la dette transitoire (les F dans le pool 1-parmi-3) est **acceptable** si le
marchand est en P1.5 ou P2, pas si c'est P4. Dans StS, le slot shop fixe (3e slot = relique shop)
existe precisement pour ne pas concurrencer les reliques de build
(slaythespire.wiki.gg/wiki/The_Merchant — le 3e slot est toujours une relique de shop). Mais StS
n'a pas le "canal marchand tous les 3 combats" que nous avons en cours de developpement. Si le
marchand /3 combats arrive en P1.5-P2, alors les runOp y migrent au meme moment — zero dette.
Si le marchand est reporte a P4, alors la F diluent l'offre pendant P1-P3, ce qui est un vrai
probleme.

**Condition a surveiller** : le marchand /3 combats doit etre dans le meme jalon que la garantie
de pertinence de build (P1.5). Sinon — dette cumulee non negligeable.

**Source** : slaythespire.wiki.gg/wiki/The_Merchant ; ROADMAP-draft §5.3 ; 00-state.md §7.

---

## 2. Desaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DESACCORD MAJEUR — La condition d'activation n'est pas requise systematiquement

**Claim du brouillon** (§5.5) : conditionner seulement `plague_communion` et `second_breath` pour
les rendre build-defining.

**Pourquoi c'est insuffisant — preuve dans le code** :

Lire `relics.lua` ligne par ligne revele que 6 des 21 reliques sont actuellement sans condition
d'activation ou de scope archetype :

| Relique | Op | Condition actuelle | Build-defining ? |
|---------|-----|-------------------|-----------------|
| `bloodstone` | +14% atk | AUCUNE | Pick-auto (toute compo frappe) |
| `carapace` | +8 HP plat | AUCUNE | Pick-auto (tout le monde a des HP) |
| `aegis` | -15% dmg subi | AUCUNE | Pick-auto (defensive universelle) |
| `whetstone` | +15% cadence | AUCUNE | Pick-auto (toute compo attaque) |
| `plague_communion` | +25% si 2+ afflictions | TRES FAIBLE | 83 unites = 5 familles DoT = la condition est la norme |
| `second_breath` | survive 1x a 1PV | AUCUNE | Pick-auto defensif |

Les reliques A (bloodstone/carapace/aegis/whetstone) sont deliberement des "stats plates" (relics-
design.md §4-A : "universelles"). Ce n'est PAS un probleme si leur role EST d'etre des "planchers"
que tout build peut prendre sans honte. **L'ERREUR du brouillon est de supposer qu'une relique de
tier 1 doit etre build-defining.** Ce n'est pas le modele de StS :

Dans StS, les reliques COMMUNES (50% de chance sur elite) sont des buffs universels (Akabeko : +8
force au 1er tour, universel). Ce sont les reliques BOSS qui sont build-defining grace au downside.
La taxonomie StS est claire : commun = universel ; boss = build-defining avec downside.
(slaythespire.wiki.gg/wiki/Relics, verifie 2025)

**Le probleme de design de The Pit n'est donc PAS que les reliques A sont pick-auto — c'est qu'il
n'y a PAS de distinction de NIVEAU DE BUILD-DEFINITION par tier.** Un tier 4 devrait toujours etre
build-defining (conditionnel + archetype), un tier 1 peut etre universel. Aujourd'hui :
- `bloodstone` (tier 1) = universel → CORRECT
- `whetstone` (tier 1) = universel → CORRECT
- `plague_communion` (tier 4) = quasi-universel → INCORRECT
- `second_breath` (tier 4) = universel → INCORRECT

**Consequence operationnelle** : le brouillon limite sa passe de conditionnement a §5.5 avec
seulement 2 reliques ciblees. Il manque `forked_tongue` : "le choc rebondit sur 1 ennemi" (tier 4)
est potentiellement actif meme pour une compo sans choc si le choc ennemi rebondit. La condition
"actif seulement si le joueur a ≥ 2 unites choc" est manquante.

**Source** : slaythespire.wiki.gg/wiki/Relics (Akabeko, reliques communes vs boss) ;
`src/data/relics.lua` (lecture directe, tiers et conditions) ; relics-design.md §1 principe #4 ;
ROADMAP-draft §5.5 (brouillon conditionne seulement 2 reliques).

### 2.2 DESACCORD — La garantie de pertinence de build (§5.4) est mal formulee

**Claim du brouillon** (§5.4) : "≥1 des 3 reliques a son type-cible (affliction/archetype) present
sur le plateau courant". Cette formulation est necessaire mais pas suffisante, ET elle cree un
probleme d'implementation plus subtil que le brouillon ne reconnait.

**Probleme A — "type-cible present" est ambigu pour les reliques A/D** : `carapace` (HP), `aegis`
(defense), `whetstone` (cadence) n'ont pas de "type-cible" archetype. Pour ces reliques, la garantie
devient triviale (toujours "presente") — ce qui revient au meme bug que la garantie de tier. La
formulation ne distingue pas les reliques universelles (A) des reliques engagees (B-E).

**Solution plus robuste** : la garantie doit s'appliquer aux reliques B-E uniquement, pas aux A.
Reformulation : "parmi les 3 offres, si au moins 1 est de categorie B-E, alors au moins 1 de ces
B-E a son type-cible present sur le plateau". Les reliques A peuvent etre offertes librement.
Cela permet d'avoir 2 reliques A + 1 relique B pertinente = offre valide, sans forcer que les 2
reliques A soient "pertinentes" (elles sont par definition universelles).

**Probleme B — invariant #3 et seed** : le brouillon signale correctement que l'invariant #3 doit
etre reformule ("meme seed+wins+compo → meme offre"). Mais il ne precise pas que ce changement
implique une **modification de la signature de `rollRelicChoices`** dans `state.lua` — qui doit
recevoir la composition comme parametre additionnel. Ce n'est pas trivial si la composition est
dans `BuildState` (hors `RunState`). La separation SIM/RENDER/IO doit etre preservee : la compo
doit etre passee comme donnee pure, pas lue depuis un etat global.

**Garde-fou test** : la modification de `rollRelicChoices(n, compo)` change la signature de la
fonction testee dans `tests/relics.lua`. Le test doit etre adapte AVANT le code (invariant #3,
marque "a modifier" dans le brouillon — mais le brouillon ne specifie pas la nature exacte du
changement de signature).

**Source** : `src/run/state.lua` (rollRelicChoices, signature actuelle) ; ROADMAP-draft §5.4 ;
seed/tests.md §6 invariant #3.

### 2.3 DESACCORD PARTIEL — L'amplificateur de choc est "bloque par la plomberie" — FAUX

**Claim du brouillon** (§5.2) : "ajouter un levier relique choc mid-tier. MAIS : l'op
`relic_affliction_inc` cible un dps continu (*Inc) — le choc est un condensateur (volt-based),
pas un dps. → verifier en code s'il faut un op dedie `relic_shock_inc { volt_mult }`."

**Pourquoi le brouillon surestime le probleme de plomberie** :

La verification directe de `arena.lua:243-262` (ce round) montre que `plagueAmp` applique un
multiplicateur `more` directement dans `Arena:damage` via les `teamFlags`. Ce patron N'UTILISE PAS
`relic_affliction_inc` — il utilise `relic_add_effect + grant_team + teamFlag`. Le meme patron
est deja utilise pour 4 des 5 reliques E (forked_tongue, everburn, open_wounds, plague_communion).

Pour un amplificateur de choc, le meme patron fonctionne :
```lua
-- Candidat conceptuel (a verifier avec la plomberie choc)
shock_conduit = { id = "shock_conduit", op = "relic_add_effect", tier = 3,
  params = { effect = { trigger = "combat_start", op = "grant_team",
    params = { shockAmp = 0.30 } } } }
```
Il suffit alors que `arena.lua` lise `shockAmp` dans `teamFlags` au moment de la decharge choc
(la section `dischargeShock` dans la boucle de combat) — exactement comme `plagueAmp` est lu
dans `Arena:damage`. Ce n'est PAS un nouveau op au sens moteur : c'est un nouveau `teamFlag`
lu par un point d'extension existant.

**Condition** : verifier que `dischargeShock` dans `arena.lua` est bien un point d'extension
accessible via `teamFlags`. Si oui, l'amplificateur de choc est a **2 lignes de data + 1 lecture
de flag** — pas un "probleme de plomberie bloquant".

**Reste un risque** : si `dischargeShock` ne lit pas `teamFlags`, il faut l'etendre. Ce n'est
pas "zero ligne de code" mais c'est 3-5 lignes dans un point isole, pas un refactor de la boucle
(le moteur est ouvert/ferme, decision moteur #2 — engine-architecture.md).

**Recommandation** : retirer le label "bloque par verification technique" du brouillon §5.2 et
remplacer par "verifier la disponibilite du point d'extension `dischargeShock`/`teamFlags` avant
de classifier comme data-only ou +5 lignes". La plomberie est moins bloquante que le brouillon
le dit.

**Source** : `src/combat/arena.lua:243-262` (lecture directe, pattern plagueAmp) ;
`src/effects/ops.lua:248` (grant_team) ; engine-architecture.md §ouvert/ferme ;
ROADMAP-draft §5.2.

### 2.4 DESACCORD — L'analogie StS sur le scope conditionnel (§5.5) est partiellement paresseuse

**Claim du brouillon** (§5.5) : "StS boss-reliques avec scope conditionnel a la place du downside
(§2.2) — nos reliques n'ont PAS de downside par decision #7, donc le scope est le seul levier
build-defining (relics §2.2/§P3). SANS downside, une tier 4 doit etre conditionnelle a un
archetype."

**Ce qui est juste** : la logique du levier unique est correcte. Sans downside (principe #2), la
condition d'activation est le seul mecanisme build-defining disponible. La conclusion est valide.

**Ce qui est paresseux** : le brouillon adopte la terminologie de StS ("scope conditionnel") sans
tester si le **mecanisme psychologique** transfere. Dans StS, le downside des boss-reliques cree
du "forced theming" — le joueur DOIT construire autour du malus (Busted Crown = petit deck
efficient ou rien). Une condition d'activation dans The Pit n'a pas cet effet coercitif : le
joueur peut prendre `plague_communion` (conditionnelle : "≥4 unites de meme affliction") SANS
chercher a satisfaire la condition, et se retrouver avec une relique inerte. Ce n'est pas du
"forced theming" — c'est du "passive gating" qui ressemble a du build-defining sans l'etre.

**La distinction cle** : chez StS, le downside est NEGATIF et impo→se une contrainte de deck qu'on
ne peut pas ignorer. Chez The Pit, la condition est NEUTRE — la relique est juste inerte si la
condition n'est pas satisfaite. Psychologiquement, "inerte si condition absente" n'incite pas a
construire vers la condition — il incite a choisir une autre relique. Ce n'est pas le meme
mecanisme.

**Solution alternative (non mentionnee dans le brouillon)** : plutot que condition d'activation
GATE, envisager des conditions SCALANTES : "chaque unite de type X donne +Y% a la relique". Cela
transforme la relique en incentive progressif plutot qu'en gate binaire. Exemple pour
`plague_communion` : "+5% de tous les degats par unite partageant l'affliction majoritaire" (1-5
unites = 5-25%) — le joueur prend la relique meme avec 1 unite de l'affliction, et la valeur
croit avec l'engagement. Ce modele est plus proche du compteur de type (P1, §4 du brouillon) que
du scope conditionnel de StS.

**Source** : slaythespire.wiki.gg/wiki/Relics (Busted Crown, Ectoplasm — forced theming par
downside) ; gamedeveloper.com/design/how-i-slay-the-spire-s-devs-use-data (Giovannetti : le
downside elimine des options) ; ROADMAP-draft §5.5.

### 2.5 DESACCORD — Le nombre de reliques (21) n'est pas challenge sur sa suffisance statistique

**Ce que le brouillon ne fait pas** : il ne calcule jamais si 21 reliques dans un pool sont
*suffisants* pour garantir qu'un joueur engage une famille specifique voit en moyenne au moins
1 relique pertinente sur son run.

**Calcul manquant** (maths, ce round) :

Un run The Pit = 10 victoires → reliques offertes tous les 3 combats (sans defaite). En scenario
ascension parfaite (10 victoires + 0 defaite + defaites comptent aussi comme relic triggers), on
a **⌈10/3⌉ = 4 offres** en 10 rounds si on offre a toute fin de combat, ou **3-4 offres** selon
le rythme de la formule exacte de `rollRelicChoices`. Avec 21 reliques, 6 tiers (F=3, A=4, B=4,
C=3, D=3, E=4) gatees par progression, et une distribution approximative :

- round 1 (0-1 win) : pool accessible = A (4 reliques) + pas de B ni plus = max 4 reliques
- round 4 (2-4 wins) : pool accessible = A (4) + B (4) + C premiere (0-1) + D (0-1) ≈ 9 reliques
- round 7 (5+ wins) : pool accessible = A (4) + B (4) + C (3) + D (3) + E (4) = 18 reliques
  (F non offerts en 1-parmi-3 apres migration vers marchand)

Sur 18 reliques late avec 4-5 familles DoT + bouclier + tank + choc + wide, la probabilite qu'une
offre 1-parmi-3 contienne au moins 1 relique pertinente pour la famille dominante du joueur est :

Si la famille dominante a N reliques dans le pool de 18 :
- burn (ember_heart + everburn + hollow_choir = 3 reliques potentielles) :
  P(au moins 1 en 3 picks) = 1 - C(15,3)/C(18,3) = 1 - (455/816) ≈ **0.44**
- poison (kings_bowl + plague_communion + feeding_frenzy = 3 en late) :
  meme calcul ≈ 0.44
- choc (forked_tongue + 0 mid-tier actuellement = 1 relique) :
  P(au moins 1 en 3) = 3/18 = **0.167**

**Conclusion** : avec le pool actuel (21), la probabilite d'avoir au moins 1 relique pertinente
pour l'archetype choc en late est seulement 16.7% par offre. Sur 3-4 offres sur le run, la
probabilite de ne jamais voir de relique choc est : `(1-0.167)^3 ≈ 0.58`. **Le joueur choc n'a
statistiquement pas de relique pertinente dans plus de la moitie de ses runs.** C'est structurel,
pas un probleme de calibration.

Pour burn (3 reliques) : P(aucune en 4 offres) = `(1-0.44)^4 ≈ 0.10` — acceptable.
Pour choc (1 relique) : **P(aucune en 4 offres) = `(1-0.167)^4 ≈ 0.48` — problematique.**

**Ce calcul prouve que la proposition P4 de r01-relics.md (amplificateur choc mid-tier) est une
necessite statistique, pas un beau-avoir.** Avec 2 reliques choc (1 mid + 1 late), P(aucune
en 4 offres) ≈ `(1-0.30)^4 ≈ 0.24` — acceptable. **Le seuil operationnel est : au moins 2
reliques pertinentes par archetype engage.**

**Ce critere de suffisance statistique (≥2 reliques/archetype pour P(aucune sur run) < 25%)
est absent du brouillon et doit etre ajoute comme regle de completude pour P1.5.**

**Source** : calculs directs (hypergeometrique, ce round) bases sur les 21 reliques de
`src/data/relics.lua` et le modele de gating de `00-state.md §2.2` ; r01-relics.md §Q5.

### 2.6 DESACCORD — L'ordre de priorite dans P1.5 est mal etabli

**Claim du brouillon** (§5) : priorite 1 = completer les archetypes (swarm_logic, shield pur,
choc mid) ; priorite 2 = amplificateur choc (plomberie) ; priorite 2 = runOp→marchand ;
priorite 1 = garantie de pertinence ; priorite 3 = conditionner les E.

**Critique de l'ordre** : le brouillon melange 3 types de travaux qui ont des dependances
differentes et des couts differents :

| Travail | Cout | Dependance | Priorite correcte |
|---------|------|------------|-------------------|
| Garantie pertinence (§5.4) | Faible (data+test) | Aucune (mais implique compo en sig.) | 1 |
| Conditionner E tier 4 (§5.5) | Tres faible (params data) | Aucune | 1 (parallelise avec 5.4) |
| Completer archetypes (§5.1) | Faible (data) | Axe choc decide (P0.5) | 2 (apres P0.5) |
| Amplificateur choc (§5.2) | Faible-moyen (teamFlag) | Axe choc decide (P0.5) | 2 (meme batch) |
| RunOp→marchand (§5.3) | Moyen (marchand code) | Marchand /3 combats | 3 (conditionne) |

**Recommandation** : scinder P1.5 en deux micro-lots :
- **P1.5a** (data pure, zero dependance) : garantie pertinence + conditionnement E tier 4. Peut se
  faire pendant P0 (RENDER) et P0.5 (axe choc). Cout : quelques heures.
- **P1.5b** (apres P0.5) : completer archetypes (swarm_logic + shield + choc mid) + verif
  plomberie shockAmp. Bloque sur la decision d'axe choc (P0.5 §3.2 du brouillon).
- **P1.5c** (conditionne marchand code) : runOp→marchand.

Ce decoupage permet de commencer P1.5a en parallele de P0 (RENDER), sans attendre P0.5.

**Source** : ROADMAP-draft §5 (ordre) ; ROADMAP-draft §5.2 (dependance plomberie/axe choc) ;
ROADMAP-draft §2 (P0 granularite de cout : §2.1-2.3 = RENDER pur, parallelisable).

---

## 3. Propositions priorisees — ce que la lentille reliques recommande au brouillon

### Prop-A — Ajouter un critere de suffisance statistique pour la completude (PRIORITE 1)

**Quoi** : formaliser la regle de completude reliques : "chaque archetype engage (familles DoT +
tank/shield + choc + wide) doit avoir au moins 2 reliques pertinentes dans le pool accessible
en mid/late, pour que P(aucune relique de l'archetype sur un run complet) < 25%."

Actuellement violee par : choc (1 relique, P=48%), wide (0 relique swarm_logic, P=100%).
Respectee par : burn (3 reliques, P=10%), poison (3 reliques, P=10%), bleed (2 reliques, P=24%
— limite), rot (2 reliques grave_cap + hollow_choir partial, P≈24%).

**Application concrete** : pour P1.5b, le minimum necessaire est :
- choc : ajouter 1 relique mid-tier (shock_conduit, ~tier 3, teamFlag shockAmp)
- wide : livrer swarm_logic (en attente depuis relics-design.md §5)
- shield pur : facultatif si un des amplis bleed/rot couvre l'archetype bouclier par biais

**Cout** : calcul de distribution = aucun (fait ce round). Data ajoutee = 2-3 entrees dans
`relics.lua`. Tests : 1 test de comptage reliques par archetype (sans golden).

**Source** : calcul hypergeometrique ce round (§2.5) ; r01-relics.md §Q5 ; relics-design.md §5.

### Prop-B — Distinguer explicitement universelles (A) vs build-defining (B-E) dans les regles de conditionnement (PRIORITE 1)

**Quoi** : acteR que les reliques tier 1 (A = stats plates) sont deliberement universelles (pas
de condition d'archetype a exiger d'elles) et que la garantie de pertinence de build (P1.5 §5.4)
s'applique uniquement aux offres B-E. Reformuler §5.4 et §5.5 en consequence.

Cela implique de conditionner TOUTES les reliques E tier 4 (pas seulement plague_communion et
second_breath) :
- `plague_communion` : condition renforcee (ex. "≥4 unites meme affliction" → aligne sur paliers
  de type P1)
- `second_breath` : scope conditionnel ("≤4 unites ou front-row only")
- `forked_tongue` : condition d'activation ("≥2 unites choc dans la compo") — manquante dans le
  brouillon
- `everburn` et `open_wounds` : deja build-defining pour burn/bleed respectivement → pas besoin de
  modifier

**Alternative scalante pour plague_communion** (cf. §2.4 de ce round) : "+5% de tous les degats
par unite de l'affliction majoritaire" au lieu d'un gate binaire. Plus proche du compteur de type
(P1) — moins de dead range entre 1 et 4 unites.

**Cout** : data-only (params) ; mise a jour tests/relics.lua (#18-21). Pas de nouvel op.

**Source** : slaythespire.wiki.gg/wiki/Relics (universelles vs boss-defining) ; §2.1/§2.4 de ce
round ; relics-design.md §4-A/§4-E.

### Prop-C — Scinder P1.5 en micro-lots decouples (PRIORITE 2 — sequencage)

**Quoi** : reorganiser P1.5 comme propose en §2.6 :
- P1.5a (data, parallelise avec P0) : garantie pertinence reformulee (Prop-B) + conditionnement
  E tier 4 (Prop-B). Delai : 0.
- P1.5b (apres P0.5 axe choc) : swarm_logic + shock_conduit + verification dischargeShock.
- P1.5c (apres marchand code) : runOp→marchand.

**Pourquoi** : P1.5a est un lot de quelques heures (params data + test) qu'on retarde
injustement en le mettant apres P0.5 dans le sequencage actuel. Le cout du sequencage incorrect
est la dilution des offres de build pendant P0-P0.5 (2-3 jalons) alors qu'on pourrait l'eviter.

**Garde-fou** : P1.5a ne touche aucun invariant sauf #3 si la garantie de pertinence est mise
en place (modifier test #3 AVANT le code, invariant marque dans le brouillon).

**Source** : ROADMAP-draft §2 (granularite P0) ; §2.6 de ce round.

### Prop-D — Ajouter un comptage de reliques par archetype dans `tools/sim.lua` (PRIORITE 2)

**Quoi** : enrichir les metriques de `tools/sim.lua` (deja existant avec lift de co-occurrence)
d'un comptage "reliques recues par archetype" sur N runs : quelle fraction des runs d'un archetype
choc voit ≥1 relique choc, ≥2, etc. Cela donne la mesure directe de la suffisance statistique
(Prop-A) sans raisonnement analytique.

**Pourquoi** : les calculs de §2.5 (hypergeometrique) sont des approximations qui ignorent le
gating par avancee, le Fisher-Yates seede et les offres ratees (decline). La sim donne la reponse
exacte sur le pool et le comportement reel de `rollRelicChoices`.

**Cout** : 1 metric supplementaire dans `tools/sim.lua` (lecture du log de reliques par run).
Hors golden (lecture seule du log, pas de sim de combat). Aucun invariant.

**Source** : tools/sim.lua (deja existant) ; ROADMAP-draft §7.1 (drapeaux sim) ; §2.5 de ce
round.

### Prop-E — Verifier et documenter le patron `dischargeShock + teamFlags` AVANT P1.5b (PRIORITE 3)

**Quoi** : avant d'implementer shock_conduit (P1.5b), lire `arena.lua` section `dischargeShock`
et verifier si `teamFlags` est accessible a ce point. Si oui : shock_conduit = data-only. Si non :
+5 lignes dans un point isole. Documenter le resultat dans `docs/roadmap-lab/` (pas dans le code).

**Cout** : 30 minutes de lecture de code. Aucun invariant. Aucun code modifie.

**Garde-fou** : ne pas implémenter sans verification (principe CLAUDE.md §1 : verifier les APIs).

**Source** : `src/combat/arena.lua` ; engine-architecture.md §ouvert/ferme ; §2.3 de ce round.

---

## 4. Questions ouvertes

1. **Completude statistique vs completude qualitative** : le brouillon cible les archetypes "non
   couverts" (wide=0, shield=0, choc=1). Prop-A ajoute un critere quantitatif (≥2 reliques par
   archetype, P<25%). Ces deux criteres sont-ils orthogonaux ou suffit-il d'un seul ? Recommendation
   de ce round : le critere quantitatif EST le critere de completude — pas besoin du qualitatif
   comme regle separee.

2. **Condition scalante vs gate binaire pour plague_communion** : la reformulation scalante (§2.4 :
   "+5% par unite de l'affliction majoritaire") est-elle conforme a l'exigence "≤8 mots" du brouillon
   (§2.5 du brouillon : audit textes)? "Chaque allie de meme affliction : +5% degats equipe" = 7 mots.
   Oui, conforme. A valider sim.

3. **swarm_logic et gating par slots** : le brouillon mentionne le gating "≥5 slots ouverts".
   L'invariant #13 (`slots ∈ [3, 9]`) est respecte. Mais le gating par slots est-il implementable
   dans `rollRelicChoices` de facon deterministe ? Il faut que `slots_open` soit un champ de
   `RunState` accessible au tirage — a verifier dans `state.lua` avant P1.5b.

4. **Shield pur vs redundance avec tank/taunt** : r01-relics.md §P0 propose une relique d'ampli de
   bouclier. Mais le brouillon §P0.5 §3.3 note que "regen = 1 unite → singleton intentionnel ou
   ladder?". La meme question s'applique au shield : est-ce un archetype assez distinct pour meriter
   sa propre relique, ou le shield est-il un bonus complementaire dans un archetype tank/bleed ? A
   decider avant de l'ajouter (sinon remplissage).

5. **Litige #B (double-comptage type × reliques B × auras)** : la Prop-B ci-dessus (conditionner
   les E sur "≥4 unites meme affliction") s'aligne sur les paliers de type (P1). Est-ce qu'un joueur
   avec 4 unites burn, le palier burn 4 (twist P1), ember_heart (relique B) ET soot_acolyte en aura
   cree un combo excessif ? Le cap ×3 borne les `increased`, mais le twist de palier 4 est une "regle
   modifiee" (pas un increased) — sa nature exacte dans la couche stats n'est pas encore specifiee.
   A clarifier avant de figer les paliers de type (P1).

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| Reliques communes StS = universelles ; boss = build-defining avec downside | slaythespire.wiki.gg/wiki/Relics ; slay-the-spire.md §2.1/§2.2 |
| StS 2 : relic design "risk and weird synergy", conditionnelle | switchbladegaming.com/strategy-games/slay-the-spire-2-relic-tier-list/ ; pixelnitro.com/slay-the-spire-2-relics-spreadsheet-guide (2026) |
| TFT augments "pick-any" = signal de mauvais calibrage | teamfighttactics.leagueoflegends.com/en-us/news/game-updates/augments-augmented/ |
| Roguelike item orthogonality ("tout bon item a un desavantage potentiel") | gamedeveloper.com/design/roguelike-item-orthogonality |
| Roguelike item/monster design revisited | gamedeveloper.com/design/roguelike-item-and-monster-design-revisited |
| StS Giovannetti : forced theming par downside | gamedeveloper.com/design/how-i-slay-the-spire-s-devs-use-data ; slay-the-spire.md §2.2 |
| 21 reliques (liste, tiers, ops) | `src/data/relics.lua` (lecture directe, ce round) |
| plagueAmp hors-cap, patron more dans Arena:damage | `src/combat/arena.lua:243-262` (lecture directe, ce round) |
| DOT_CAP_MULT=3, BLEED_DPS_CAP, ampDps | `src/effects/ops.lua:22-32` (lecture directe, ce round) |
| Taxonomie reliques A-G, principes, carte archetype→relique | `docs/research/relics-design.md §1/§4/§5` |
| Calculs hypergeometriques P(aucune relique archetype sur run) | Calcul direct ce round (§2.5) |
| Invariant #3 (seed+wins→offre), #18-21 (reliques) | seed/tests.md §6 ; 00-state.md §6 |
| Gating offre reliques (early/mid/late) | `00-state.md §2.2` |
| rollRelicChoices, RunState | `src/run/state.lua` |
| Complétude : `swarm_logic` absent, pas de relique B choc | `src/data/relics.lua` (grep verifie round-01 §1.9) |
| Marchand /3 combats (non encore code) | `00-state.md §7` |
| StS slot shop separe (3e slot = relique shop) | slaythespire.wiki.gg/wiki/The_Merchant ; slay-the-spire.md §2.1 |

---

## 6. Impact sur le sequencage (vue diff vs brouillon #2)

```
BROUILLON #2 §5 (P1.5) :
  → 5.1 completer archetypes (wide/shield/choc)    PRIORITE 1
  → 5.2 ampli choc (bloque plomberie)              PRIORITE 2
  → 5.3 runOp→marchand                             PRIORITE 2
  → 5.4 garantie pertinence build                  PRIORITE 1
  → 5.5 conditionner E tier 4 (2 reliques)         PRIORITE 3

APRES ROUND 2 (lentille reliques) — scission en micro-lots :
  P1.5a (MAINTENANT, data pure, parallelise P0/P0.5) :
    → garantie pertinence B-E seulement (reformulee §2.2)  [PRIORITE 1, stat seule, test #3 adapte]
    → conditionner TOUTES les E tier 4 (pas 2 seulement)  [PRIORITE 1, params, tests #18-21]
    → documenter regle ≥2 reliques/archetype (Prop-A)     [PRIORITE 1, doc only]
  P1.5b (APRES P0.5, axe choc decide) :
    → livrer swarm_logic (wide, gating slots verif)        [PRIORITE 2]
    → livrer shock_conduit (choc mid, verif dischargeShock)[PRIORITE 2]
    → shield pur si decide archetype distinct (§Q4)        [PRIORITE 3]
  P1.5c (APRES marchand code) :
    → runOp→marchand (migrer F hors offre 1-parmi-3)       [PRIORITE 3]
  Metrics P3 :
    → enrichir tools/sim.lua comptage reliques/archetype   [PRIORITE 2]
```

---

*Redige le 2026-06-23 par l'agent lentille-reliques, round 2/10. Lecture seule du repo de jeu.
N'edite que sous `docs/roadmap-lab/`. Piliers respectes. Sources citees par URL ou fichier+ligne.
Code verifie ce round : `src/data/relics.lua` (21 reliques, tiers, ops), `src/combat/arena.lua:
243-290` (plagueAmp, secondBreath, invulnT, sequence de damage()), `src/effects/ops.lua:22-32`
(DOT_CAP_MULT, ampDps, spreadValue), `docs/research/relics-design.md` (principes, taxonomie).*
