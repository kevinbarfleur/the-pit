# R03 — Critique adversariale, lentille RELIQUES (round 3/10)

> **Round** : 3/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Cibles** : `ROADMAP-draft.md` (brouillon #3, integre round 2) + `round-02.md` (synthese).
> **Sources internes verifiees ce round** : `src/data/relics.lua` (21 reliques, lu integralement),
> `src/combat/arena.lua` (plagueAmp, secondBreath, dischargeShock), `src/effects/ops.lua`
> (DOT_CAP_MULT, relic_affliction_inc), `docs/research/relics-design.md` (taxonomie, principes),
> `00-state.md` (32 invariants, etat du jeu), `rounds/r01-relics.md` + `rounds/r02-relics.md`.
> **Garde-fou absolu** : lecture seule du repo. Ce fichier n'edite que `docs/roadmap-lab/`.
> Piliers : async snapshots / sim deterministe seedee / DA grimdark / pixel art procedural.
> Sources citees par URL ou fichier+ligne pour chaque affirmation.

---

## 0. TL;DR — challenge cle en 3 phrases

Le brouillon v3 a reclasse la completude des reliques (P1.5a remonté en parallele) et formalisé
le critere statistique ≥2/archétype — c'est solide et je l'acte. Mais la roadmap commet une
**erreur de sequencement conceptuelle non identifiée** : elle conditionne TOUTES les reliques E
tier-4 sur des seuils alignés sur les paliers de type P1 (`plague_communion → "≥4 unités même
affliction"`), or ces conditions rendent les E **orphelines** jusqu'au round 6+ de run, créant un
**dead range** de 60% du run où les reliques les plus fortes sont inertes — ce n'est pas du
"scope conditionnel", c'est un gate caché. La deuxième lacune majeure : le brouillon n'a PAS
encore résolu comment les **reliques F (runOp) diluent le pool 1-parmi-3** en l'absence du
marchand — or le marchand reste différé (P1.5c, après que le marchand soit codé), ce qui
signifie que les 3 reliques F restent en compétition directe avec les reliques de build pendant
tous les jalons v0.9 à v0.11, une dette que le brouillon reconnaît mais **ne mesure pas**.

---

## 1. Accords — ce qui tient (avec le POURQUOI pour nos contraintes specifiques)

### 1.1 ACCORD FORT — Critere statistique ≥2 reliques/archétype, P<25% (brouillon §4.3)

**Ce que le brouillon dit** : la rule de completude formelle — chaque archétype engage doit
avoir ≥2 reliques pertinentes pour P(aucune sur run) < 25%. Calcul hypergéométrique livré
par r02-relics.md §2.5 : choc = 48%, wide = 100%, bleed/rot ≈ 24%.

**Pourquoi ca tient** : c'est le seul critere opérationnel non-ambigu du brouillon sur les
reliques. Les critères qualitatifs ("archétype non couvert") sont subjectifs — un autre agent
peut argumenter que 1 relique suffit si elle est très forte. Le critère hypergéométrique est
démontrable et ne dépend pas du jugement.

**Ce qui est solide specifiquement pour l'async** : dans un jeu live (TFT), un joueur peut
"attendre" une relique pertinente en adaptant sa stratégie en temps réel. Dans The Pit, le
joueur engage un archétype AU BUILD avant le combat — s'il n'a jamais eu de relique pertinente,
c'est 4-6 combats avec un archétype "orphelin" de son levier de montée en puissance. L'async
amplifie le cout du manque de relique pertinente exactement comme r02-relics.md §1.1 l'a noté.

**Source** : calculs hypergéométriques r02-relics.md §2.5 ; `src/data/relics.lua` (21 reliques,
vérifiés) ; teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-gizmos-gadgets-learnings/
(Riot reconnaît explicitement le problème des "dead choices" dans les augments de Set 6 :
"We are committed to improving power balance and removing dead choices.").

### 1.2 ACCORD FORT — Garantie de pertinence sur B-E seulement (brouillon §4.1)

**Ce que le brouillon dit** : la garantie ne s'applique qu'aux offres B-E. Les A (stats plates)
sont offertes librement.

**Pourquoi ca tient** : la distinction est exactement la bonne pour nos contraintes. Lire
`relics.lua:20-21` : `bloodstone` (`relic_more_dmg mult=0.14`) et `carapace` (`relic_flat_hp
value=8`) sont des stats plates universelles — aucun build ne peut les ignorer. Les forcer dans
la garantie de pertinence reviendrait a exiger que "toute build frappe" (trivial) ou "toute
build a des PV" (trivial). La distinction A/B-E est structurellement correcte.

**Ce qui la rend robuste** : la garantie "si ≥1 B-E dans l'offre, alors ≥1 a son type-cible
présent" permet l'offre "2A + 1B pertinente" qui est une bonne offre — l'agent précédent
(r02-relics.md §2.2) a correctement identifié que c'est plus robuste que le critère "tier ≤2".

**Source** : `src/data/relics.lua` lignes 20-29 (lu ce round) ; r02-relics.md §2.2-A.

### 1.3 ACCORD — Sequencement P1.5a en parallele avec P0/P0.5 (brouillon §4)

**Ce que le brouillon dit** : P1.5a (données pures — garantie B-E + conditionner E tier-4 +
doc règle ≥2) est remonté en parallele de P0 et P0.5. Cost ≈ nul.

**Pourquoi ca tient** : la logique de décorrélation est solide. Les modifications de P1.5a
sont toutes `params` de reliques existantes (data) et l'adaptation du test #3 (ajout du
parametre `compo`) — zéro dépendance moteur. L'erreur de retarder ce chantier après P1
(v0.10) alors qu'il est sans dépendance était claire dans le brouillon v2 et correctement
résolue en v3. Chaque round de jeu avec des E tier-4 non-conditionnées est un round où les
reliques les plus puissantes sont des picks-auto indépendants du build.

**Source** : r02-relics.md §2.6/Prop-C ; ROADMAP-draft.md §1 (séquençage P1.5a).

### 1.4 ACCORD — Migration runOp F vers le marchand (§4 P1.5c), PAS avant

**Ce que le brouillon dit** : les reliques F (`carrion_ledger`, `black_summons`,
`beggars_lantern`) migrent vers le marchand /3 combats en P1.5c, uniquement quand le marchand
est codé.

**Pourquoi ca tient** : l'analogie avec StS est correcte ici. StS a un slot shop fixe (toujours
le 3e slot du marchand) pour les reliques à effet économique — elles ne concurrencent jamais
les reliques de build dans la récompense de combat (slaythespire.wiki.gg/wiki/The_Merchant
vérifié). La structure "marchand = canal dédié des reliques runOp" reproduit le bon principe.

**Ce qui me préoccupe** (voir §2.1) : le "quand le marchand est codé" est conditionnel sur
un chantier différé (P1.5c = après marchand /3 codé, qui est lui-même un TODO en 00-state.md §7).
Si le marchand tarde, les 3 reliques F restent en pool 1-parmi-3. Le brouillon le reconnaît
mais ne chiffre pas le cout de cette dette.

**Source** : slaythespire.wiki.gg/wiki/The_Merchant ; r01-relics.md §2.4 ; ROADMAP-draft §4 P1.5c.

### 1.5 ACCORD — `plagueAmp` hors-cap = voulu, pas un exploit (confirme round 2)

**Ce que les rounds précédents ont résolu** : `arena.lua:252` applique `plagueAmp` via un
`more` après le cap `DOT_CAP_MULT=3`. C'est le patron "more-hors-cap" voulu. r02-relics.md
§1.3 l'a confirmé avec vérification directe.

**Pourquoi je confirme ce round** : la séquence dans `Arena:damage` (invuln → plagueAmp →
dmgReduce → bouclier → hp) est cohérente avec la couche de modificateurs de stats.lua —
le `more` s'applique sur le total APRES les `increased`, ce qui donne un multiplicateur
exponentiel sur un build déjà engagé. C'est le bon design : `plagueAmp` récompense
exponentiellement la spécialisation sans contourner le cap anti-snowball (qui borne les
`increased`, pas les `more`).

**Source** : `src/combat/arena.lua:243-262` (r02-relics.md §1.3) ; `src/effects/stats.lua`
(formule `(base+Σflat)(1+Σinc)·Π(1+more)`).

---

## 2. Désaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DÉSACCORD MAJEUR — Le "dead range" des reliques E conditionnées sur les seuils de type P1

**Claim du brouillon** (§4.2) : conditionner `plague_communion` sur "≥4 unités même affliction"
(aligné sur les paliers de type P1). Option scalante : "+5% de tous les dégâts par allié de
l'affliction majoritaire" (r02-relics.md §2.4).

**Pourquoi la condition gate est un problème structurel** :

La relique est disponible à partir de 5+ wins (tier 4, offre late). Mais regardons à quel moment
le joueur peut avoir "≥4 unités de même affliction" :

- Slots disponibles : `START_SLOTS=3`, `MAX_GRANTS=6` sur rounds 2-7.
- À round 5 (2-4 wins), le joueur a ouvert ≈3-4 slots supplémentaires = 6-7 slots.
- `plague_communion` est offerte à partir de 5+ wins (late), donc round 6+ minimum.
- À round 6-7 : 7-8 slots ouverts. Pour avoir 4 unités poison, il faut que ≥4/7 slots = 57%
  de la compo soit poison. C'est réaliste pour un build MONO-engagé mais non pour une compo
  mixte (synergies d'adjacence peuvent nécessiter des unités hors-famille).

**Le problème** : une relique conditionnée à "≥4 unités même affliction" est une relique
qui récompense le mono-commit maximum à son meilleur — mais qui est **INERTE** pour tout
joueur qui n'est pas déjà mono-commité avant d'avoir la relique. Ce n'est pas du "scope
conditionnel" à la StS — c'est un gate fonctionnel déguisé.

**La différence avec StS** (que r02-relics.md §2.4 a commencé à pointer) : dans StS, un
boss-relic avec downside (Busted Crown : -2 récompenses de carte) est du "forced theming"
parce que le JOUEUR DOIT construire autour du malus, qui est actif IMMEDIATEMENT. Une
condition NEUTRE de présence ("≥4 unités poison") peut être ignorée confortablement :
le joueur prend la relique même avec 2 unités poison et la garde même si elle ne se déclenche
jamais. Ce n'est pas de l'engagement — c'est du **bruit dans l'inventaire**.

**Le vrai risque** : un joueur poison prend `plague_communion` à round 6 avec 3 unités
poison (n'atteint pas le seuil de 4), puis la garde passivement sans changer son build.
La relique est inerte. Il ne "construit vers" la condition — il attend de l'atteindre
naturellement ou non. C'est psychologiquement identique à une relique ordinaire (non-build-
defining) jusqu'au moment hypothétique où le seuil est atteint.

**Ce qui fonctionne mieux : l'option scalante est la bonne réponse**

L'option "+5% par allié de l'affliction majoritaire" (r02-relics.md §2.4, Prop-B) résout le
dead range exactement. Avec 2 unités poison : +10%. Avec 4 : +20%. Avec 6 : +30%. Le joueur
ressent immédiatement la valeur ET est incité à pousser plus loin. C'est le "endowed progress
effect" de Nunes & Drèze 2006 (cité dans ROADMAP-draft §5.2) : donner une valeur dès le début
de la progression accélère l'effort vers l'objectif.

**Mais le brouillon laisse ce choix en "litige §Q2"** — non tranché pour P1.5a. C'est une
erreur de priorisation : si P1.5a est censé conditionner TOUTES les E tier-4 dès maintenant,
il faut trancher entre "condition gate" (dead range) et "condition scalante" (engagement immédiat)
AVANT de les implémenter.

**Recommandation concrete** : pour P1.5a, adopter systématiquement l'option scalante pour
toutes les E tier-4, sauf celles déjà build-defining sur leur seul mécanisme (everburn,
open_wounds). Formuler en ≤8 mots (contrainte §2.5 du brouillon).

| Relique | Condition gate (actuelle) | Option scalante (proposée) | ≤8 mots ? |
|---------|--------------------------|---------------------------|------------|
| `plague_communion` | ≥4 unités même affliction | +5% dmg/allié affliction majoritaire | "Affliction partagée : +5% dégâts par allié" (7 mots) ✅ |
| `second_breath` | ≤4 unités ou front-row | Survie proportionnelle : chaque unité a X% de chance (1 + Y/taille_equipe) | trop complexe — garder simple |
| `forked_tongue` | ≥2 unités choc | Choc rebondit ; N rebonds = MIN(stacks_choc/2, 3) | "Rebondit N fois selon stacks" ✅ |

**Source** : Nunes & Drèze 2006, "The Endowed Progress Effect" (Journal of Consumer Research) ;
r02-relics.md §2.4 ; slaythespire.wiki.gg/wiki/Relics (downside = contrainte ACTIVE, pas
condition PASSIVE).

### 2.2 DÉSACCORD — La dilution par les reliques F n'est pas chiffrée et le brouillon la minimise

**Claim du brouillon** (§4 P1.5c) : les reliques F migrent vers le marchand "quand il est
codé". Délai reconnu mais non mesuré.

**Le problème de coût réel** :

Sur un run de 10 victoires (ascension) avec offre 1-parmi-3 tous les 3 combats, le joueur
voit ~3-4 offres de reliques (⌈10/3⌉ = 4 si chaque combat compte, moins si on alterne win/loss).
Avec 21 reliques dont 3 F (soit 14.3% du pool), la probabilité qu'une F apparaisse dans une
offre 1-parmi-3 est :

P(au moins 1 F parmi 3 offres) = 1 - C(18,3)/C(21,3) = 1 - (816/1330) ≈ **0.39**

Donc sur ~4 offres de reliques par run, le joueur verra en moyenne 1-2 offres contaminées
par une relique F. C'est une offre "gaspillée" de slot de build-shaping sur 3-4 = 25-33%
des offres.

**Mais la dilution est plus perverse que ca** : une relique F dans une offre 1-parmi-3 ne
prend pas seulement un slot — elle change la psychologie de la décision. Le joueur voit
`black_summons` (+1 tier boutique, tier 4) et doit évaluer : "est-ce que ce +1 tier vaut
plus que les 2 reliques de build qui m'auraient été proposées à la place ?" C'est une
décision d'un type radicalement différent (économie du run vs build de combat) dans le
même cadre d'offre. C'est du **bruit cognitif** dans un moment censé être de la
**décision de build pure**.

**Ce que le brouillon ne calcule pas** : l'impact sur la cohérence décisionnelle de l'offre.
StS a séparé les reliques shop (slot fixe du marchand) des reliques de build (récompenses
elite/boss) précisément pour ne jamais mélanger les deux types de décisions dans le même
contexte. Source : slaythespire.wiki.gg/wiki/The_Merchant (3e slot toujours une relique shop,
"allows players to reliably get shop relics without competing for them with build relics").

**Ce qui est actionnable sans attendre le marchand** : une règle simple dans
`rollRelicChoices` (invariant #3 à adapter, comme le brouillon le note déjà pour la compo) :
"si un F est tiré ET un B/C/D est disponible, remplacer le F par un B/C/D". Les F ne
disparaissent pas du pool — elles sont juste déprioritisées quand des alternatives de build
existent. Cela ne nécessite pas le marchand.

**Garde-fou** : cette règle doit être seedée de manière déterministe (comme le Fisher-Yates
actuel). Si la graine permet le F ET que la règle le remplace, le remplacement doit être
un tir supplémentaire seedé du même RNG de run (pas un tir indépendant). Test #3 adapté AVANT.

**Source** : calcul de probabilité ce round (hypergéométrique, base 21 reliques dont 3 F) ;
slaythespire.wiki.gg/wiki/The_Merchant ; r01-relics.md §2.4.

### 2.3 DÉSACCORD PARTIEL — Le brouillon laisse "swarm_logic" (wide) comme une simple case à cocher P1.5b sans valider son archétype

**Claim du brouillon** (§4 P1.5b) : livrer `swarm_logic` (wide, gating ≥5 slots).

**Le problème** : `swarm_logic` est mentionnée depuis r01-relics.md (P0 §3.1) comme une
relique "à ajouter" parce qu'elle existe dans `relics-design.md §5`. Mais elle n'a jamais
été challengée sur ses méchaniques précises. Ce round, en relisant `relics-design.md §5` :

"Swarm Logic | récompense le large" — c'est TOUT ce qui est dit.

r01-relics.md §P0 propose une formulation candidate : "Si l'équipe a ≥ 6 unités : chaque
unité gagne +1 PV et +X% dmg par unité au-dessus de 5". C'est une condition gate (≥6 unités)
avec un effet proportionnel (par unité au-dessus de 5). Elle souffre du même dead range que
plague_communion : inerte jusqu'à slot 6 ouvert (round 4-5 minimum), puis soudainement active.

**Le vrai gap de swarm_logic** : quel est l'ARCHÉTYPE "wide" dans The Pit ? Le sigil diamant
est décrit comme "go-wide / essaim" (CLAUDE.md §3, tableau sigils). Mais il y a un problème
de cohérence : les synergies d'adjacence (le voisin buffe) favorisent les TOPOLOGIES DENSES
(beaucoup d'arêtes actives), pas nécessairement le nombre d'unités. Le sigil carré (4 voisins
pour le centre) est potentiellement plus favorable aux synergies d'adjacence que le diamant
qui a des bords isolés.

**Conséquence** : `swarm_logic` récompense la présence de beaucoup d'unités (≥5-6 slots)
mais ne récompense pas SPÉCIFIQUEMENT le sigil diamant. C'est une relique de QUANTITÉ, pas
de TOPOLOGIE. Si les reliques G (P4) sont censées récompenser les topologies, `swarm_logic`
empiète sur leur territoire conceptuel sans la garantie de la cohérence sigil-archétype.

**Alternative proposée** : reformuler `swarm_logic` comme une relique d'ADJACENCE plutôt
que de QUANTITÉ. Exemple : "Chaque arête d'adjacence active au build donne +X% à l'attaque
des deux unités concernées". Cela récompense spécifiquement les sigils denses (diamant,
carré) et s'intègre au système de synergies d'adjacence — cohérent avec le pilier
"le graphe EST les synergies" (CLAUDE.md §2).

**Condition de gating naturelle** : au lieu de "≥5 slots", la condition devient implicite
(les premiers slots = peu d'arêtes = faible bonus ; les 9 slots avec sigil dense = beaucoup
d'arêtes = bonus fort). Déterministe, pas de gate binaire.

**Source** : `docs/research/relics-design.md §5` (swarm_logic = "récompense le large", vague) ;
CLAUDE.md §2 (décision #4 : "la forme EST le graphe de synergies") ; r01-relics.md §Q3
(gating swarm_logic par slots — questionné mais non résolu) ; 00-state.md §2.3 (tableau sigils).

### 2.4 DÉSACCORD — Le brouillon confond deux mécanismes de `second_breath` dans sa conditionnement

**Claim du brouillon** (§4.2) : conditionner `second_breath` → scope (≤4 unités ou front-row).

**Analyse code directe** : `second_breath` dans `relics.lua:47` est `{ op = "relic_second_breath" }`.
Dans `R.apply` (lignes 97-98) : `spec.secondBreath = true`. Dans `Arena:damage`, le check
`u.secondBreath` permet à l'unité de survivre une fois à 1 PV.

**Le problème de la condition proposée** : "≤4 unités OU front-row" crée deux conditions
orthogonales dans la même relique — soit c'est une relique "tall" (≤4 unités), soit c'est
une relique "front-positioning". Ce n'est pas une condition "scope" — c'est deux RELIQUES
différentes fusionnées en une seule condition.

**Pourquoi c'est une analogie StS mal transférée** : dans StS, le scope conditionnel d'une
boss-relic force UN archétype (Busted Crown → petit deck EFFICIENT). "≤4 unités OU front-row"
force... quoi ? Un joueur tall avec 4 unités en front-row ? Un joueur wide avec ses 4
premières unités toutes en front ? La condition est trop flexible pour créer un archétype.

**Alternative proposée** : plutôt que de conditionner `second_breath`, l'interrogation
fondamentale est : FAUT-IL qu'une relique tier-3 défensive soit build-defining ? Dans StS,
les reliques défensives communes (Akabeko, Orichalcum) sont universelles — elles ne shapent
pas le build, elles l'améliorent. L'erreur du brouillon est d'appliquer le principe
"tier-4 = build-defining" à une relique défensive qui a été correctement placée en tier-3.

**Recommandation** : ne pas conditionner `second_breath`. C'est une relique défensive
universelle de tier-3, analogue aux reliques communes universelles de StS. Son tier (3, pas 4)
est déjà un guard-rail. La conditionner créerait de la fausse complexité sans gain d'identité.
Si elle s'avère trop puissante via sim, la réponse est de monter le tier (4) ou de réduire
les PV de survie (0.5 PV au lieu de 1 PV), pas d'ajouter une condition incohérente.

**Source** : `src/data/relics.lua:47` ; `R.apply` ligne 97-98 ; slaythespire.wiki.gg/wiki/Relics
(reliques communes universelles StS : Akabeko, Orichalcum — universelles, non conditionnées) ;
00-state.md §2.2 (gating par tier : tier-3 = mid, pas late).

### 2.5 DÉSACCORD — La validité du modele "ampli d'affliction inc=0.18-0.30" par famille n'est pas challengée

**Observation non adressée dans les rounds précédents** : les 4 reliques B sont des
`relic_affliction_inc` avec des `inc` différents selon la "puissance" présumée de l'archétype :

| Relique | Famille | inc | Justification dans le code |
|---------|---------|-----|---------------------------|
| `kings_bowl` | poison (apex) | 0.20 | "APEX -> ampli CONSERVATEUR" |
| `ember_heart` | burn (faible) | 0.30 | "familles faibles -> ampli plus généreux" |
| `weeping_nail` | bleed | 0.18 | "calibrage" (commentaire code) |
| `grave_cap` | rot | 0.18 | "calibrage" (commentaire code) |

**Le problème structurel** : la logique "famille forte → ampli plus faible" est correcte EN
PRINCIPE (les reliques B ne doivent pas être des compensations de balance mais des récompenses
du commit). Mais cette logique ASSUME que poison est l'apex et burn est faible — ce qui est
le diagnostic ACTUEL (the-pit-balance-diagnosis, mémoire) mais est lui-même un problème à
résoudre (pas un état à figer dans les reliques).

Si bleed est rééquilibré via P3 (sim, tuning), est-ce que `weeping_nail` à 0.18 reste
approprié ? Si poison est nerfé, est-ce que `kings_bowl` à 0.20 devient trop faible ?

**Conséquence** : les inc des reliques B sont des PLACEHOLDERS calibrés sur la hiérarchie
ACTUELLE des archétypes — mais la hiérarchie actuelle EST le problème d'équilibrage à résoudre.
En fixant les reliques B AVANT l'équilibrage des familles (P3), on crée une dépendance circulaire :
les reliques calibrent sur une hiérarchie défectueuse, puis l'équilibrage doit tenir compte des
reliques qui ont renforcé cette hiérarchie.

**Ce n'est pas un blocage** — les reliques B peuvent rester en [PH] et les inc peuvent être
ajustés en P3 via sim. Mais le brouillon ne mentionne pas cette dépendance dans le séquençage.
La passe de qualité des reliques (§7.4) est mentionnée "après P1.5b", mais l'ajustement des
inc des reliques B existantes en fonction de la hiérarchie post-équilibrage n'est pas listé
comme un livrable de P3.

**Recommandation** : ajouter dans les drapeaux P3 (§7.1) : "audit des inc des reliques B
après rééquilibrage des familles DoT — vérifier que les inc reflètent la NOUVELLE hiérarchie
post-équilibrage, pas la hiérarchie défectueuse actuelle."

**Source** : `src/data/relics.lua:27-29` (commentaires inc, lus ce round) ; the-pit-balance-
diagnosis (hiérarchie poison>tank>...>choc, mémoire) ; ROADMAP-draft §7.1 (drapeaux P3 —
hiérarchie choc non mentionnée pour les reliques B).

---

## 3. Propositions priorisées

### Prop-A — Adopter l'option scalante MAINTENANT pour P1.5a (PRIORITE 1)

**Quoi** : dans P1.5a (data pure, // P0/P0.5), ne pas implémenter les conditions gate sur
les E tier-4. Implémenter directement l'option scalante :

- `plague_communion` → "+5% dégâts équipe par allié de l'affliction majoritaire"
  (formulation : chaque unit en compo partageant la famille la plus représentée
  contribue +0.05 au multiplicateur `plagueAmp`). **7 mots, ≤8 ✅**
  Implémentation : `plagueAmp = 0.05 × count(units[family == majorite])` calculé à
  `combat_start` (via `grant_team` avec le count de la compo).
- `forked_tongue` → garder le `shockChain` actuel **mais calibrer le N de rebonds**
  selon le count d'unités choc dans la compo (1 choc = 1 rebond, 3+ choc = 2 rebonds).
  **Garde-fou** : le count est calculé à `combat_start` (deterministe, snapshot-safe).
- `second_breath` → NE PAS CONDITIONNER (voir §2.4). Garder en tier-3 universel.

**Cout** : params data uniquement. Modifier test #18-21. Spécifier le calcul de `majorite`
(simple itération sur la compo, aucun nouveau op).

**Source** : §2.1 de ce round ; Nunes & Drèze 2006 (endowed progress effect) ;
r02-relics.md §2.4 (option scalante plague_communion identifiée mais non tranchée).

### Prop-B — Reformuler swarm_logic comme relique d'ADJACENCE plutôt que de QUANTITÉ (PRIORITE 2)

**Quoi** : en P1.5b, livrer `swarm_logic` non pas comme "≥6 unités → bonus" mais comme
"chaque arête active au build donne +X% atk aux deux unités concernées". Lecture des arêtes
depuis `shapes.lua` (le sigil actif expose déjà les arêtes explicites au build). Calculer
à `R.apply` (build-time) en itérant sur `shapes[build.shape].edges`.

**Interet** : cohérence avec le pilier "la forme EST le graphe de synergies" (CLAUDE.md §2).
Récompense spécifiquement les sigils denses (diamant, carré, anneau) sans gate binaire.
S'inscrit naturellement dans la logique du surlignage d'adjacence (P0 §2.1).

**Garde-fou** : le calcul doit être à `R.apply` (build-time, avant le combat), pas à
`combat_start` — sinon il sort du firewall SIM/RENDER (la boucle ne doit pas lire les
formes de plateau en combat). Pas de nouvel op moteur, juste un calcul de count dans
`R.apply`. **Deterministe** (le shape est dans le snapshot, arêtes explicites dans shapes.lua).

**Valeur cible** : `inc = X × count(arêtes actives)`. X [PH], à calibrer via sim (cible
win% comparable aux archétypes DoT sur sigil diamant). Aucun invariant — les reliques B-E
sont hors du golden (#5 par design gated).

**Source** : `src/board/shapes.lua` (arêtes explicites, lu dans 00-state.md §2.3) ;
CLAUDE.md §2 (décision #4 sur la topologie) ; §2.3 de ce round.

### Prop-C — Ajouter une règle de déprioritisation des F dans le pool AVANT le marchand (PRIORITE 2)

**Quoi** : dans `rollRelicChoices`, si le tirage Fisher-Yates produit une F ET qu'au moins
une relique B-E est disponible dans le pool courant, effectuer un retir seedé additionnel
pour remplacer la F par une B-E. Les F restent dans le pool mais ne "gagnent" contre les
B-E que si le pool B-E est épuisé pour la progression actuelle.

**Cout** : ~10 lignes dans `state.lua:rollRelicChoices`. Adapter test #3 (invariant reformulé
à "meme seed+wins+compo+pool_state → meme offre"). Aucun invariant SIM.

**Garde-fou** : la déprioritisation doit rester seedée et déterministe (le remplacement est
tiré du meme RNG de run, pas un RNG indépendant). Quand le marchand est codé (P1.5c), cette
règle disparaît et les F migrent directement dans le canal marchand.

**Source** : §2.2 de ce round ; r01-relics.md §2.4 (proposition P1 séparation canal F) ;
r02-relics.md §2.6 (scission P1.5 en micro-lots) ; 00-state.md §6 invariants.

### Prop-D — Ajouter "audit inc des reliques B post-rééquilibrage" dans les drapeaux P3 (PRIORITE 3)

**Quoi** : dans le séquençage P3 (§7.1), ajouter le drapeau : "après tuning des familles
DoT, ré-évaluer les inc des reliques B existantes (kings_bowl/ember_heart/weeping_nail/
grave_cap) pour vérifier qu'ils reflètent la NOUVELLE hiérarchie, pas la hiérarchie
défectueuse actuelle (poison>tank>...>choc)."

**Cout** : doc/planning uniquement. Pas de code en P3 avant la mesure.

**Cible** : le principe "famille forte → inc plus faible" reste valide; les valeurs [PH]
changent selon ce que la sim produit.

**Source** : §2.5 de ce round ; `src/data/relics.lua:27-29` (commentaires inc).

---

## 4. Questions ouvertes

1. **Nature du `majorite` pour plague_communion scalante** : si la compo a 3 poison et
   3 bleed, quel est la famille "majoritaire" ? Option A : la plus représentée en nombre
   (tie-break : premier dans l'ordre); Option B : la plus représentée EN PUISSANCE (dps
   total). L'option A est déterministe et simple. L'option B est plus juste mais requiert
   un calcul plus lourd et une définition de "puissance" à combat_start. Recommandation :
   Option A (simple, déterministe, snapshottable).

2. **Adéquation de forked_tongue avec l'axe choc (litige #G)** : si l'axe C (choc =
   amplificateur du prochain hit, PoE Shock) est retenu, `forked_tongue` ("choc rebondit sur
   1 ennemi") change de signification — le rebond devient une amplification propagée, pas
   une décharge propagée. La formulation de la relique doit rester cohérente avec l'axe
   tranché en P0.5. NE PAS graver la formulation de `forked_tongue` avant que #G soit résolu.

3. **Seuil P(aucune relique) pour bleed/rot à 24% ⚠️** : le critère ≥2 reliques/archétype
   pour P<25% est à la limite pour bleed (weeping_nail seule mid-tier + open_wounds late =
   2 reliques, mais open_wounds est tier-4 = disponible uniquement en late). Si un joueur
   bleed n'a pas encore 5+ wins, open_wounds ne peut pas être offertes. La règle "≥2 reliques
   dans le pool late" est vérifiée, mais la règle "≥1 relique mid + ≥1 relique late" n'est pas
   vérifiée. Vérifier les seuils de gating des reliques bleed/rot dans `rollRelicChoices` pour
   s'assurer qu'une relique bleed est accessible dès mid-game.

4. **Interaction plague_communion scalante avec le palier de type P1** : si P1 donne "+20%
   à l'effet du type" pour 2 unités du même type, et que plague_communion donne "+5% par
   allié de l'affliction majoritaire" (soit +25% pour 5 unités), le combo 5 poison + palier
   2/4 + plague_communion + kings_bowl crée un multiplicateur inc total important. La nature
   stats du twist de type (litige #B : more ? increased ?) interagit directement ici. À
   modéliser via sim AVANT de figer les valeurs scalantes de plague_communion.

5. **Timing d'activation de la déprioritisation F (Prop-C)** : faut-il déprioritiser les F
   dès le round 1 (très early, quand elles sont les plus problématiques car le joueur n'a pas
   encore de build établi) ou seulement en late (quand l'offre de build-shaping a plus de
   valeur) ? La déprioritisation totale dès le début semble correcte — les runOp ne sont jamais
   le bon choix si une relique B-E adaptée est disponible.

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| Reliques communes StS universelles (Akabeko, Orichalcum) | slaythespire.wiki.gg/wiki/Relics |
| StS slot marchand séparé (3e slot = shop-only) | slaythespire.wiki.gg/wiki/The_Merchant |
| TFT dead choices dans les augments (Set 6) | teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-gizmos-gadgets-learnings/ |
| StS 2 design : scope conditionnel build-defining | switchbladegaming.com/strategy-games/slay-the-spire-2-relic-tier-list/ ; pixelnitro.com/slay-the-spire-2-relics-spreadsheet-guide (2026) |
| Endowed progress effect (Hull 1932 ; Nunes & Drèze 2006) | ROADMAP-draft §5.2 (goal-gradient cité) ; original : Nunes & Drèze 2006, JCR |
| 21 reliques — ops, tiers, inc | `src/data/relics.lua` (lecture directe ce round) |
| plague_communion via plagueAmp (more, hors-cap, confirmé) | `src/combat/arena.lua:243-262` ; 00-state.md §3 |
| second_breath via spec.secondBreath | `src/data/relics.lua:47` ; `R.apply` lignes 97-98 |
| Arêtes explicites sigils (shapes.lua) | `src/board/shapes.lua` (référencé via 00-state.md §2.3) |
| Gating offre reliques (early/mid/late) | `00-state.md §2.2` ; `src/run/state.lua` |
| Invariants #3, #18-21 | `seed/tests.md §6` ; 00-state.md §6 |
| Hiérarchie poison>...>choc (diagnostic équilibrage) | the-pit-balance-diagnosis (mémoire) ; 00-state.md §7.1 |
| Calcul probabilistique dilution F | calcul hypergéométrique ce round (§2.2) |
| Pilier "la forme EST le graphe de synergies" | CLAUDE.md §2 (décision #4) |

---

*Rédigé le 2026-06-23 par l'agent lentille-reliques, round 3/10. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. Sources citées par URL ou fichier+ligne.
Code vérifié ce round : `src/data/relics.lua` (21 reliques, ops, inc, tiers — lu intégralement),
`src/data/relics.lua:47 + R.apply:97-98` (second_breath = spec.secondBreath = true, universel).
Rounds précédents lus : r01-relics.md, r02-relics.md, round-01.md, round-02.md, ROADMAP-draft.md.*
