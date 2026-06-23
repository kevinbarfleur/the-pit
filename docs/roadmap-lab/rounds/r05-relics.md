# R05 — Critique adversariale, lentille RELIQUES (round 5/10)

> **Round** : 5/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Cibles** : `ROADMAP-draft.md` (brouillon #5, integre round 4) + `round-04.md` (synthese).
> **Sources internes lues ce round** : `00-state.md` (32 invariants, chiffres, taxonomie),
> `round-04.md` (synthese), `rounds/r04-relics.md`, `ROADMAP-draft.md` §4 (P1.5a) + §7.4 + §10,
> `BRIEF.md` (mandat). Les references au code sont issues des verifications des rounds precedents
> (lignes citees).
> **Garde-fou absolu** : lecture seule du repo. Ce fichier n'edite que `docs/roadmap-lab/`.
> Piliers : async snapshots / sim deterministe seedee / DA grimdark / pixel art procedural.
> Sources citees par URL ou fichier+ligne pour chaque affirmation de design.

---

## 0. TL;DR — challenge cle en 3 phrases

La roadmap v5 a correctement requalifie `plague_communion` (payoff multi-affliction sur la CIBLE,
non un gate roster) et confirme `feeding_frenzy` — deux vraies corrections. **Mais le brouillon
ignore un probleme structurel non resolu : la taxonomie A/B/C/D/E est une classification
formelle, pas une classification de FONCTION TEMPORELLE — quatre reliques actees en P1.5a ont
des fenetres d'offre mismatches avec leur role repondant (shaper-early, shaper-mid, ou payoff-
late), et le brouillon n'a pas de critere pour detecter ni corriger ce probleme avant que le
ranked mesure le skill.** Deuxieme challenge : la roadmap reconnaît que les inc des reliques B
sont calibres sur la hierarchie DEFECTUEUSE actuelle (poison>choc) sans avoir de regles claires
pour les recalibrer APRES l'equilibrage — cette dette circulaire creuse le probleme de balance
au lieu de le fermer.

---

## 1. Accords — ce qui tient (avec le POURQUOI pour nos contraintes)

### 1.1 ACCORD TRES FORT — `plague_communion` conservee telle quelle (correction majeure du round 4)

**Ce que le round 4 a acte** (`round-04.md §1.1`, code `arena.lua:248-252`) : `plague_communion`
est un payoff multi-affliction sur la CIBLE (`afflictionCount(target.dots) >= 2`), pas un gate
sur le roster. La reformulation scalante "+5%/allié de l'affliction majoritaire" des rounds
precedents repondait a une relique inexistante.

**Pourquoi l'accord est fort, et pas juste un desaccord resolu** : la vraie relique est
mecaniquement superieure au design scalante propose. Elle recompense un archetype de jeu
**unique** que rien d'autre ne couvre : meler les familles DoT pour creer un "cocktail" sur
la meme cible. C'est orthogonal au palier de type P1 (qui recompense la profondeur dans UNE
famille) — les deux mecanismes coexistent sans se dupliquer. Un joueur burn-poison peut avoir
`plague_communion` active plus souvent qu'un joueur mono-poison, ce qui cree une DECISION de
build non evidente. C'est exactement le critere de "1 regle modifiee" de LocalThunk
(Rolling Stone 2024 : "every Joker tweaks one rule of the game", balatrogame.fandom.com/wiki/
Guide:General_strategy).

**Pour nos contraintes async** : la condition `afflictionCount(target) >= 2` est deterministe
et reproductible — elle survit parfaitement aux snapshots. Elle ne necessite aucune information
cross-run (elle est evaluee a chaque damage(), pas a combat_start). Les rounds precedents
construisaient une relique scalante qui aurait demande un calcul de `majorite` a combat_start
(potentiellement fragile si la compo change via snapshot v1 sans effets captures — `00-state.md
§5` : "effets aura/relique non captures dans le snapshot v1"). La vraie relique est plus
robuste architecturalement.

**Source** : `round-04.md §1.1` (verification code `arena.lua:248-252`) ;
balatrogame.fandom.com/wiki/Guide:General_strategy (LocalThunk : 1 regle/Joker) ;
`00-state.md §5` (limites snapshot v1).

### 1.2 ACCORD FORT — Garantie de pertinence sur B-E seulement (acte round 2, confirme round 5)

**Ce que la roadmap acte** (`ROADMAP-draft.md §4.1`) : parmi les 3 offres, si ≥1 est de
categorie B-E, alors ≥1 de ces B-E a son type-cible present sur le plateau courant. Les A
sont offertes librement.

**Pourquoi ca tient pour nos contraintes** : en async, le joueur evalue chaque offre en solo
sans la pression d'un adversaire live. Une offre morte (relique B non pertinente pour la compo)
n'est pas une "tension" productive — c'est du bruit cognitif pur. La garantie B-E evite que
l'offre 1-parmi-3 devienne un exercice de "quelle poubelle prendre" sans valeur de decision.

**Ce qui a change depuis r01** : la raison du "non universel" des A est maintenant verifiee.
`bloodstone` (+14% atk, aucune condition) est universellement utile — un build choc ou bleed
profite de la cadence tout autant. `carapace` (+8 HP) est moins universel qu'il n'y parait :
un build tall (famines_math, si conservee) a 3 unites × 8 HP = +24 HP de pool total, marginal
vs +8 HP × 6 unites = +48 HP de pool. Le principe reste solide : A = plancher universel,
B-E = direction de build.

**Source** : `ROADMAP-draft.md §4.1` ; `round-02.md §1.2` ; `src/data/relics.lua:20-21`
(bloodstone, carapace — valeurs verifiees rounds precedents).

### 1.3 ACCORD — Regles ≥2 reliques/archetype et P(aucune sur run) < 25% (critere statistique etabli)

**Ce que la roadmap etablit** (`ROADMAP-draft.md §4.8`) : chaque archetype engage doit avoir
≥2 reliques pertinentes pour P(aucune sur run) < 25%. Calcul hypergéométrique documente depuis
r02-relics.md §2.5.

**Pourquoi ca tient et comment l'affiner** : le critere est necessaire et non-ambigu. Il prouve
que choc (1 relique, P≈48%) et wide (0 relique swarm_logic, P=100%) sont des archétypes
"orphelins" structurellement. Pour burn, poison, bleed (P≈10-24%), le critere est satisfait.

**MAIS la precision manque un axe** (voir §2.2 ci-dessous) : le critere compte toutes les
reliques du pool sans distinguer celles accessibles selon le gating par avancee. Une relique
tier-4 n'est pas disponible avant 5+ wins — si les 2 reliques d'un archetype sont toutes les
deux tier-4, le critere P<25% peut etre satisfait en late mais viole en early/mid. Ce round,
je propose un critere affine (cf. §3.1).

**Source** : `ROADMAP-draft.md §4.8` ; r02-relics.md §2.5 (calcul hypergeometrique) ;
`00-state.md §2.2` (gating tier ≤ wins).

### 1.4 ACCORD — Deprioritiser les reliques F AVANT le marchand (brouillon §4.6)

**Ce que la roadmap acte** : dans `rollRelicChoices`, si un F est tire ET un B-E disponible,
remplacer le F par un B-E (tir seede additionnel). Calcul de contamination : P(≥1 F en 3) ≈
0.387, soit 25-33% des offres contaminées.

**Pourquoi ca tient** : le calcul est correct et la solution est architecturalement propre.
Elle n'attend pas le marchand (evenement different). La contamination des offres par des
decisions d'economie-de-run vs decisions-de-build cree un bruit cognitif que le joueur ne peut
pas neutraliser (pas de "sauter" l'offre F, juste la refuser contre +3 or). StS regle cela
avec un slot marchand separe (slaythespire.wiki.gg/wiki/The_Merchant).

**Condition preservee** : la deprioritisation est seedee et deterministe — invariant #3
survivant si le remplacement tire du meme RNG de run (`round-03.md §2.2/Prop-C`).

**Source** : `ROADMAP-draft.md §4.6` ; r03-relics.md §2.2 (cout chiffre contamination F) ;
slaythespire.wiki.gg/wiki/The_Merchant (slot marchand separe).

### 1.5 ACCORD — `second_breath` reste universelle tier-3 (non conditionnee)

**Ce que le brouillon acte** (`ROADMAP-draft.md §4.4`) : ne pas conditionner `second_breath`.
Tier-3 defensif universel.

**Pourquoi ca tient** : r03-relics.md §2.4 a correctement demonte l'analogie "conditionner
comme une boss-relic StS". Dans StS, le downside d'une boss-relic est NEGATIF et IMMEDIAT —
il contraint le joueur meme si la condition n'est pas remplie. Une condition NEUTRE ("≤4 unites
OU front-row") n'a aucun effet coercitif : le joueur prend `second_breath` meme sans satisfaire
la condition. La conclusion du round 3 est juste : son tier (3, pas 4) est le garde-fou
naturel. Si elle s'avere trop forte → monter au tier 4 ou reduire l'effet.

**Confirmation externe** : dans Slay the Spire 2 (2026, pixelnitro.com), les reliques
defensives universelles restent dans la couche "les bonnes reliques s'ameliorent en toute
situation" — elles ne sont pas conditionnees. C'est le modele correct pour les defensives
non-build-defining.

**Source** : r03-relics.md §2.4 ; `ROADMAP-draft.md §4.4` ; pixelnitro.com/slay-the-spire-2-
relics-spreadsheet-guide-to-all-items-new-mechanics-and-beta-meta-2026/ (STS2 2026 : reliques
defensives universelles comme couche de plancher).

---

## 2. Desaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DESACCORD MAJEUR — La colonne "role temporel" est listee comme "doc only" mais elle detecte un bug de design structure non resolu

**Claim du brouillon** (`ROADMAP-draft.md §4.7`, litige #P) : ajouter une colonne "role
temporel" (SHAPER-EARLY / SHAPER-MID / PAYOFF-LATE) dans l'audit P1.5a pour signaler les
"mismatchs" fenetre/role. Priorite : doc, 0 code.

**Pourquoi l'accord est insuffisant** : identifier les mismatchs sans les corriger dans le
meme jalon est une dette half-cooked. Voici les mismatchs que la colonne revelarait
NECESSAIREMENT sur les 21 reliques actuelles (bases sur le gating `00-state.md §2.2` et les
effets de `src/data/relics.lua`) :

**Mismatch 1 — `forked_tongue` (tier-4, E) : SHAPER-MID piege en LATE**
`forked_tongue` (`shockChain=1`) est offerte a partir de 5+ wins. Mais c'est une relique qui
ORIENTE le build vers le choc (shaper) — elle devrait etre disponible avant que le joueur ait
"gaspille" 5-6 combats en build choc sans levier. Une relique shaper en late = arrive quand le
build est deja engage ailleurs. La solution n'est pas de descendre son tier (le choc est un axe
avance) mais de garantir qu'une AUTRE relique choc est accessible en mid. Ce mismatch CONFIRME
que la dette "ladder choc 5/3/2" (`00-state.md §7`) a une COMPOSANTE RELIQUES, pas seulement
une composante unites.

**Mismatch 2 — `famines_math` (tier-3, C) : SHAPER-EARLY en conflit avec les grants de slots**
Documente au round 4 (`round-04.md §1.3`) comme litige #O. La relique est un shaper des le
round 3 (offerte mid-early selon les wins) mais cree un conflit permanent avec les grants de
slots des rounds 2-7. Ce n'est pas un mismatch temporel strictement parle — c'est un conflit
d'incentives avec l'economie de run. La resolution (#O a trancher) est separee du mismatch,
mais le mismatch le revele.

**Mismatch 3 — `grave_cap` / `open_wounds` (tier-4, E pour open_wounds) : PAYOFF-LATE pour ROT**
`grave_cap` (B, tier-2, inc rot) est accessible en mid. `open_wounds` (E, tier-4, bleedNoExpire)
est late. La rot a `grave_cap` en mid pour l'amplifier, mais son payoff-late (`open_wounds` est
pour le bleed) — la ROT n'a PAS de relique payoff-late. Si le joueur rot engage, son arc
relique se termine en mid (grave_cap) sans culmination late. Cela cree un run rot qui "stagne"
apres le mid. Ce manque est distinct du critere ≥2/archétype (qui ne distingue pas early/mid/late).

**Pourquoi ca compte pour nos contraintes async** : dans le contexte async, le joueur n'a pas
de "course live" contre un adversaire pour adapter son archétype en cours de partie. Il engage
un archétype AU BUILD et le maintient. Un arc relique incomplet (shaper sans payoff, ou payoff
sans shaper) cree un run qui a un "ceiling psychologique visible" — le joueur sait qu'il ne
peut pas aller plus loin dans cet archétype via les reliques. C'est exactement le plafond de
connaissance premature (cf. ROADMAP-draft §6.7 : plafond de connaissance →
`season_wins ≥ 50 ET Grimoire ≥ 25/30`).

**Conclusion** : la colonne "role temporel" doit etre ACTIONNABLE en P1.5a, pas seulement
documentaire. Identifier un mismatch sans le corriger = savoir qu'il y a un bug de design sans
le fixer. La correction peut etre aussi simple que (a) recategoriser la fenetre d'offre dans
`rollRelicChoices` (e.g. permettre `forked_tongue` a partir de 3+ wins si le build a ≥1 unite
choc) ou (b) confirmer que le mismatch est acceptable (et documenter pourquoi).

**Source** : r04-relics.md §2.1 (Prop-A, rôle temporel doc) ; ROADMAP-draft §4.7 (litige #P) ;
`00-state.md §2.2` (gating tier ≤ wins) ; TFT augments timing : les shaper-augments sont
offerts a 2-1/3-2 (bunnymuffins.lol/augment-guide-for-set-13/ — Set 13 guide cite la
distinction entre augments "directionnels" early et "payoffs" late comme cle de la
decision d'augment).

### 2.2 DESACCORD — Le critere ≥2/archetype est globalement correct mais aveugle aux distributions temporelles

**Claim du brouillon** (`ROADMAP-draft.md §4.8`) : critere ≥2 reliques pertinentes par
archetype, P(aucune sur run) < 25%.

**Insuffisance non identifiee** : le critere compte les reliques dans le POOL TOTAL, mais le
gating par avancee cree des distributions temporelles differentes. Voici le calcul precis
(basé sur `00-state.md §2.2` : early ≤2 wins = tier≤2 ; mid 2-4 = tier≤3 ; late 5+ = tier≤4) :

| Archétype | Relique mid (tier≤3) | Relique late (tier-4) | Critique |
|-----------|---------------------|----------------------|---------|
| Burn | ember_heart (B/T2) + everburn (E/T4) | oui | OK : mid + late |
| Bleed | weeping_nail (B/T2) + open_wounds (E/T4) | oui | Limite : mid + late |
| Poison | kings_bowl (B/T2) + plague_communion (E/T4) | oui | OK |
| Rot | grave_cap (B/T2) | **AUCUNE relique tier-4 rot** | ❌ Pas de payoff-late rot |
| Choc | **AUCUNE relique tier≤3 choc** + forked_tongue (E/T4) | oui | ❌ Pas de shaper-mid choc |
| Wide | **ABSENT** | **ABSENT** | ❌ Pas de relique wide du tout |

**Ce que ca signifie** : le critere ≥2/archétype (brouillon §4.8) masque que rot n'a pas de
payoff-late ET que choc n'a pas de shaper-mid. Avec seulement ces 2 reliques par archetype, P
est satisfait globalement, mais l'ARC temporel est incomplet.

**Pour l'async** : un joueur rot s'engage en early/mid sur un archétype qui n'a pas de relique
late. Son run rot "plafonne" en mid sans levier late de montee en puissance. Il voit ses
adversaires (ghosts T3-T4) qui ont pris des reliques late fortes sur d'autres archétypes — et
il n'a rien d'equivalent. Ce desequilibre n'est pas visible dans le critere P<25%.

**Proposition d'affinage** (voir §3.2) : reformuler le critere en ≥1 relique accessible en
mid (tier≤3) ET ≥1 relique accessible en late (tier-4) par archétype engage.

**Source** : `00-state.md §2.2` (gating) + `src/data/relics.lua` (tiers des 21 reliques,
verifies rounds precedents) ; TFT Set 13 guide bunnymuffins.lol/augment-guide-for-set-13/
(distinction directionnels early vs payoffs late = cle de la decision).

### 2.3 DESACCORD — La dette des inc des reliques B est une boucle fermee non identifiee dans le sequencement

**Claim du brouillon** (`ROADMAP-draft.md §7.1`) : "audit des inc des reliques B apres
reeequilibrage des familles DoT". Reconnu comme une precision de P3.

**Pourquoi c'est insuffisant — le probleme est circulaire** :

Les inc des reliques B sont calibres sur la hierarchie ACTUELLE (poison>tank>...>choc) :
- `kings_bowl` (poison) : inc = 0.20 — "APEX → ampli CONSERVATEUR" (commentaire code)
- `ember_heart` (burn) : inc = 0.30 — "familles faibles → ampli plus genereux"
- `weeping_nail` (bleed) / `grave_cap` (rot) : inc = 0.18 — "calibrage"

Le round 3 (r03-relics.md §2.5) a correctement identifie le probleme. Ce round je le pousse
plus loin : la boucle est REFERMEE dans le sequencement actuel.

Le sequencement acte est :
1. P0.5 : `--poison-frac` (mesure la cause structurelle de poison>choc)
2. P1 : types (paliers DoT par famille)
3. P3 : reeequilibrage + "audit inc des reliques B post-reeequilibrage"

Le probleme : si la P3 est le moment du reeequilibrage des familles DoT ET du recalibrage des
inc des reliques B, alors entre P1 et P3 (soit v0.10 a v0.12), le systeme de types (paliers)
est codé et mesure AVEC des inc de reliques B calibres sur la hierarchie DEFECTUEUSE. Les types
amplifient cette hierarchie (burn +30% d'inc via ember_heart + palier type = 50% vs poison
+20% d'inc via kings_bowl + palier type = 40%). L'équilibrage P3 devra ensuite corriger une
metastase doublement ancree.

**Pourquoi ce n'est pas un simple resequencement** : la solution n'est pas de coder le
recalibrage des reliques B AVANT P1 — leurs valeurs de cible dependent de l'état FINAL des
familles DoT (apres axe choc, apres types), qu'on n'a pas encore. La solution est de :
(a) **marquer explicitement tous les inc des reliques B comme [PH] dans le doc P1.5a**
(actuellement, le P1.5a ne mentionne pas cette dette sur les B existantes) ; et
(b) **bloquer la finalisation des valeurs de palier de type (P1) JUSQU'A ce que
`--poison-frac` donne la hierarchie saine** (condition P0.5, deja en place), ce qui
permet de calibrer le twist de type sur une base non defectueuse.

Le brouillon a (b) correct en principe (types P1 conditionnes par `--poison-frac` en P0.5) mais
n'a pas (a) : les reliques B existantes ne sont pas marquees comme [PH] dans le plan P1.5a.

**Source** : r03-relics.md §2.5 (boucle circulaire identifiee) ; `src/data/relics.lua:27-29`
(commentaires inc verifies rounds precedents) ; `ROADMAP-draft.md §7.1` (audit inc B en P3).

### 2.4 DESACCORD PARTIEL — `forked_tongue` reformulee "premiere tache de P1.5a apres P0.5" mais sa spec est incomplète

**Claim du brouillon** (`ROADMAP-draft.md §4` fin) : `forked_tongue` — une fois #G tranche
en P0.5, la reformulation est "la PREMIERE tache de P1.5a". Deadline acte.

**Ce qui est incomplet** : la reformulation de `forked_tongue` en axe D pose un probleme de
CIBLE CONCRETE non resolu. L'axe D (decharge sur le 1er tick DoT) a deux interpretations pour
`forked_tongue` (shockChain=1) :

- **Interpretation A** : le `shock_amplify` (burst sur le 1er tick DoT d'une cible) est propage
  a une 2e cible adjacente ("le choc rebondit au sens DoT"). Mais sur quelle cible ? La
  "prochaine cible en front" (logique de ciblage) ou "un voisin aleatoire" (ce qui violerait
  le determinisme, pilier #2) ?
- **Interpretation B** : a chaque decharge de choc, les stacks se divisent entre la cible
  principale ET une cible secondaire (share du burst). Deterministe mais necessite de decider
  comment les stacks se partagent.

Le litige #S (`round-04.md §3` litiges, litige #S) — ciblage de l'ampli choc-D : ordre fixe
vs `dot_family` du poseur — a un impact DIRECT sur `forked_tongue` : si l'axe D amplifie la
famille `dot_family` du poseur, une unite choc avec `dot_family = choc` amplifie TOUJOURS les
ticks de choc de la cible (si elle en a). Mais `forked_tongue` avec shockChain n'a pas de
`dot_family` propre — elle amplifie le choc ENTRE cibles. Avant que #S soit tranche, la spec
de `forked_tongue` est fondamentalement incertaine.

**Conclusion** : la deadline "premiere tache de P1.5a post-#G" est correcte, mais la tache
reelle n'est pas "reformuler", c'est "specifier EN DETAIL la semantique de forked_tongue dans
l'axe D retenu + tester en sim 4-configs (Config B de §3.4 du brouillon : galvanizer
auto-decharge viabilite)". Sans cette spec, la reformulation produit du code fragile.

**Source** : `ROADMAP-draft.md §3.4` (sim 4-configs + litige #S) ; `round-04.md §3` (litiges
actifs) ; `src/data/relics.lua:51-52` (`forked_tongue` shockChain=1, verifies rounds
precedents).

### 2.5 DESACCORD PARTIEL — `swarm_logic` (wide) laissee en "scalante quantité" (P1.5b) alors que la question de coherence sigil est toujours ouverte

**Claim du brouillon** (`ROADMAP-draft.md §8.1`, note) : "`swarm_logic` (wide) reste une
relique de QUANTITE scalante en P1.5b ; la version 'par arête' est une relique G candidate".

**Ce que le round 3 a propose** (r03-relics.md §2.3 / Prop-B) : reformuler `swarm_logic` comme
relique d'ADJACENCE (chaque arete active = +X% atk) plutot que de QUANTITE (≥6 unites).

**Pourquoi le brouillon tranche ici est defensible mais non-argumente** : le brouillon scinde
"swarm_logic scalante quantite (P1.5b)" et "relique G adjacence (P4)" sans justification
explicite de la distinction. Le risque identifie par r03 est valide : une relique de QUANTITE
sur le wide ne recompense pas specifiquement la topologie dense (diamant/anneau) — elle
recompense le nombre d'unites. Or le pilier "la forme EST le graphe de synergies" (CLAUDE.md
§2, decision #4) implique que les reliques qui renforcent un archetype de plateau DEVRAIENT
etre cohérentes avec la topologie du sigil.

**Cependant** : l'argument pour scinder est acceptable SI (a) `swarm_logic` scalante est
explicitement documentee comme "non-topologique intentionnelle — complementaire aux synergies
d'adjacence" ET (b) son effet ne cree pas de redondance avec le systeme d'adjacence positionnelle
deja existant (les auras bakees au build depuis les aretes, CLAUDE.md §7). Si `swarm_logic`
donne "+X% atk par unite supplementaire" et que les auras donnent deja "+X% dmg par voisin",
deux mecánismes de "recompenser les gros builds" coexistent — qui est le levier de decision ?

**Ce round, je maintiens que cette question n'est pas resolue dans le brouillon.** La distinction
"quantite vs adjacence" reste un litige design non tranche qui devrait etre acte en P1.5b au
moment de specifier `swarm_logic`, pas reporte a P4.

**Source** : r03-relics.md §2.3/Prop-B ; CLAUDE.md §2 (decision #4 : "la forme EST le graphe
de synergies") ; `ROADMAP-draft.md §8.1` (scission swarm_logic/relique-G sans argumentation).

### 2.6 NOUVEAU — L'absence d'une relique de CONTRE-JEU global (meta-game relic) est un angle mort structurel

**Ce que les rounds 1-5 n'ont pas adresse** : le pool de 21 reliques couvre cinq familles DoT
(amplificateurs B), trois payoffs conditionnels (C), quatre defensifs (D), quatre transformatifs
(E) et trois économiques (F). Aucune relique n'offre un levier de CONTRE-JEU direct.

**En quoi est-ce un probleme** : dans le contexte async par snapshots, le joueur affronte des
builds figés dont il voit le residu APRES combat (post-combat "pourquoi" du brouillon P0 §2.3).
Il sait qu'il a perdu contre un ghost poison avec 4 stacks de contagion. Mais aucune relique ne
lui permet de REPENDRE contre ce type de build dans le run suivant :
- Pas de relique "purge N stacks de DoT a combat_start"
- Pas de relique "immunité temporaire aux afflictions pour X ticks"
- Pas de relique "les unites qui meurent sans avoir ete empoisonnees font X% de bonus"

Dans StS, certaines reliques communes servent explicitement de "counter tools" :
- Odd Mushroom (contre les ennemis qui gagnent de la force)
- Red Skull (counter aux builds qui ne frappent pas en debut de combat)
(slaythespire.wiki.gg/wiki/Relics — reliques de counter situationnel)

Dans un jeu async, l'equivalent est une relique qui reduit LA MENACE STRUCTURELLE des builds
populaires (les ghosts au tier courant). Ce n'est pas un "contre-build" au sens live — c'est
un signal "j'ai vu que mon tier est plein de poison, je prends cette relique pour la run
suivante". C'est un levier META qui renforce le sentiment de skill cross-run.

**Ce n'est pas une proposition d'implémenter un nouveau type de relique massivement**. Une
seule relique de ce type (ex. "tes unites gagnent +X% resistance aux DoT pour chaque famille
dont elles ont ete victimes en combat precedent" — lue du log post-combat) suffit pour
l'archetype "chasseur de meta". Elle serait tier-3 ou tier-4 pour eviter d'etre systematique.

**Contrainte de design** : elle doit etre build-resolue ou calculée a `combat_start` depuis
des donnees de l'etat de run (log post-combat), jamais depuis un etat de combat live (firewall
SIM/RENDER, decision #2). Et elle doit survivre au snapshot (le ghost adverse ne "connait" pas
le log post-combat de la run courante).

**Source** : slaythespire.wiki.gg/wiki/Relics (counter tools situationnels) ; `00-state.md §5`
(snapshot = build + positions + sigil, log post-combat hors snapshot = source valide pour une
relique de run-context) ; thematique grimdark : "ceux qui ont survecu au Puits savent quels
poisons y circulent" — cohérent DA.

---

## 3. Propositions priorisees

### Prop-A — Reclassifier les 21 reliques selon arc temporel (shaper-mid/payoff-late) ET corriger les mismatchs en P1.5a, pas juste documenter (PRIORITE 1, doc + data)

**Quoi** : dans P1.5a, pour chaque relique, documenter :
- **Rôle** : UNIVERSEL (A-D universels) / SHAPER-EARLY (rare, oriente dans les 3 premiers rounds) /
  SHAPER-MID (oriente le build une fois etabli, tier≤3) / PAYOFF-LATE (recompense l'engagement,
  tier-4).
- **Fenetre d'offre reelle** (basee sur le gating `state.lua:339`, verifiable) : "offertes a
  partir de X wins selon le tier".
- **Mismatch detecte** (fenetre d'offre ≠ role optimal) → action a prendre.

Actions concretes sur les mismatchs identifies :
1. **`forked_tongue` (tier-4, SHAPER-MID deplace en LATE)** : ajouter une condition de gating
   conditionnel — "offertes a partir de 3 wins SI le build a ≥1 unite choc". Cela respecte le
   Fisher-Yates seede (verif `state.lua` si le filtre est implementable deterministement) +
   preserve le gating progressif.
2. **ROT sans payoff-late** : planifier en P1.5b une relique rot tier-4 (payoff-late) ou
   declarer le mismatch "acceptable" (rot = archetype mid-game voulu) et le documenter comme
   decision de design.
3. **CHOC sans shaper-mid** : ce point est DEJA dans les livrables de P1.5b (ampli choc
   mid-tier — brouillon §P1.5b, `shock_conduit`). La Prop-A ne cree pas de nouveau travail,
   elle CONFIRME que la dette de P1.5b a une dimension temporelle precise.

**Cout** : doc P1.5a (~20 lignes) + verif code de `rollRelicChoices` pour le gating conditionnel
de `forked_tongue`. 0 invariant si le gating est data-only (champ `minBuiltChoc` dans la
definition de relique, verifie a `rollRelicChoices`). Adapter test #3 si le gating est conditionnel
(invariant #3 reformule en "meme seed+wins+compo → meme offre").

**Source** : §2.1 de ce round ; r04-relics.md §2.1/Prop-A ; bunnymuffins.lol/augment-guide-
for-set-13/ (TFT distinction "directionnels early" vs "payoffs late" = standard de la decision
d'augment).

### Prop-B — Raffiner le critere ≥2/archetype en "≥1 mid (tier≤3) ET ≥1 late (tier-4)" (PRIORITE 1, doc)

**Quoi** : reformuler la regle de completude de `ROADMAP-draft.md §4.8` :
- Actuel : "chaque archétype engage a ≥2 reliques, P(aucune sur run) < 25%"
- Affine : "chaque archétype engage a ≥1 relique tier≤3 (shaper-mid accessible) ET ≥1 relique
  tier-4 (payoff-late). P<25% calculé sur le pool tier≤3 separément."

Conséquences directes :
- **Rot** : ❌ pas de payoff-late → a corriger en P1.5b (ou declarer mismatch accepte).
- **Choc** : ❌ pas de shaper-mid → `shock_conduit` de P1.5b resout exactement ca.
- **Wide** : ❌ pas de relique du tout → `swarm_logic` de P1.5b est la solution.
- Burn/Bleed/Poison : ✅ 1 mid + 1 late chacun.

**Cout** : reformulation doc P1.5a, 0 code. Mesurable via sim `tools/sim.lua` (comptage par
tier × archétype, extension de la metrique reliques/archétype de r02-relics.md §Prop-D).

**Source** : §2.2 de ce round ; `00-state.md §2.2` (gating tier ≤ wins) ; r02-relics.md §2.5
(calcul hypergeometrique de base).

### Prop-C — Marquer explicitement les inc des reliques B comme [PH-DEPENDANT] dans P1.5a et bloquer leur finalisation a APRES `--poison-frac` (PRIORITE 2, doc)

**Quoi** : dans P1.5a, ajouter une note sur les 4 reliques B existantes
(`kings_bowl/ember_heart/weeping_nail/grave_cap`) :

> "[PH-DEPENDANT : ces inc sont calibres sur la hierarchie DEFECTUEUSE actuelle (poison>choc).
> Ils seront reajustes APRES mesure de `--poison-frac` (P0.5) + reeequilibrage des familles
> DoT (P3). Ne pas les finaliser avant ces etapes.]"

Cette note est distincte des [PH] generaux — elle indique une DEPENDANCE CAUSALE, pas juste
une valeur a tuner. L'effet concret : quand le devs sera en P1 (types), il saura que `kings_bowl
inc=0.20` n'est pas final et ne construira pas les twists de palier en supposant que la
hierarchie B-est-calibree.

**Cout** : doc uniquement, 0 code, 0 invariant.

**Source** : r03-relics.md §2.5 (boucle circulaire identifiee) ; `ROADMAP-draft.md §7.1` (audit
inc B mentionne mais pas marque comme dependant) ; §2.3 de ce round.

### Prop-D — Specifier la semantique de `forked_tongue` dans l'axe D AVANT la reformulation (PRIORITE 1, doc)

**Quoi** : dans P0.5 (litige #G tranche), AVANT de coder la reformulation de `forked_tongue`,
documenter dans `docs/roadmap-lab/` :

1. "Le 'rebond' de `forked_tongue` avec l'axe D signifie : [CHOISIR UNE OPTION]"
   - **Option A** : quand le tick DoT amplifie se produit sur la cible principale, DUPLIQUER
     l'amplification sur la cible front-line suivante (selon le ciblage deterministe colonne→taunt→aggro).
     Deterministe, zero RNG, 0 nouveau mecánisme.
   - **Option B** : au moment de la decharge choc, si la cible a ≥2 familles DoT actives,
     les stacks choc se partagent entre elle et sa voisine (caseIndex suivant selon
     `Arena:neighborsOf`). Plus thematique (le choc "saute") mais necessite de decider
     le split (50/50 ? ou 60/40 par aggro ?).
2. Documenter l'impact de #S sur ce choix.

**Cout** : doc ~10 lignes, 0 code. Bloque `forked_tongue` reformulee (justifie la deadline
"premiere tache P1.5a post-#G"). Aucun invariant avant le code.

**Source** : §2.4 de ce round ; `ROADMAP-draft.md §3.4` (axe D, sim 4-configs) ; `round-04.md
§3` (litige #S).

### Prop-E — Envisager 1 relique de "contre-jeu meta" (tier-3 ou tier-4) pour l'archetype chasseur-de-meta (PRIORITE 3, design)

**Quoi** : dans P3 (apres equilibrage et types), envisager une relique tier-3 qui lit le
contexte de run post-combat :

Candidat design : `war_scar` ("Chaque affliction dont l'equipe a ete victime en combat precedent
renforce vos unites de +2% HP". Lu depuis le log post-combat de `bus.lua` JSONL — c'est une
stat de build, calculable a `R.apply` depuis un champ stocke dans le RunState, hors SIM.)

Alternatives plus simples :
- "Si l'adversaire precedent etait un build poison : +X% resistance aux stacks de poison de
  votre equipe pour le prochain combat" (version simple, 1 seul trigger).

**Contraintes de design** :
- Build-resolu a `combat_start` depuis `RunState` (hors SIM, conforme firewall).
- Deterministe (calculee depuis l'etat de run seede, pas un RNG independant).
- Lisible en ≤12 mots.
- Ne touche pas le snapshot (le ghost ne sait pas ce qu'on a subi avant).

**Cout** : design a preciser avant P3 (0 code maintenant). Un champ `previousCombatAfflictions`
dans RunState est la seule addition SIM (~2 lignes a `resolve(win)` dans `state.lua`). Pas
d'invariant de test existant viole.

**Source** : §2.6 de ce round ; slaythespire.wiki.gg/wiki/Relics (counter tools situationnels
StS) ; CLAUDE.md §3 ("grimdark" = "ceux qui survivent au Puits savent quels poisons y circulent").

---

## 4. Questions ouvertes (litiges pour les rounds suivants)

### Q1 — Litige #P affine : l'arc temporel de la rot est-il un bug ou un design voulu ?

La rot sans relique payoff-late est un mismatch documenté ce round. Mais la rot est aussi la
famille la plus "lente" mechaniquement (amputation PV max, accumulation durée) — elle est
conçue pour etre un investissement early-mid dont l'effet culmine organiquement sans relique
late. Est-ce intentionnel ou est-ce que cela freine l'engagement des joueurs rot en late-game ?

**Critere de reponse** : en sim, comparer `win_rate(build rot + grave_cap)` a `win_rate(build
burn + ember_heart + everburn)` sur rounds 7-10. Si l'ecart depasse +1σ en faveur de burn,
le manque de payoff-late rot est un probleme d'equilibrage. Si l'ecart est < 0.5σ, le mismatch
est acceptable.

### Q2 — Litige #O (#famines_math) : reformulee ou retiree du pool ?

Acte au round 4, non tranche dans le brouillon v5. La decision affecte l'audit P1.5a (et la
colonne "role temporel"). Ce round confirme le conflit anti-growth (slots gratuits rounds 2-7 +
condition ≤3 unites = anti-incentive), et penche vers l'option (a) reformulee :
"tes 3 unites les plus couteuses ont +30% dmg / +20% HP" — toujours applicable, non anti-growth.
Mais la decision reste au developpeur. Identifier la DEADLINE pour cette decision : P1.5a
(avant d'implementer la garantie B-E, car `famines_math` est une C et sa semantique affecte
comment un joueur reagit a une offre C).

### Q3 — Litige #swarm_logic (quantite vs adjacence) : non tranche en P1.5b

La distinction conceptuelle entre "recompenser le nombre d'unites" (quantité) et "recompenser
la topologie dense" (adjacence) n'est pas resolue dans le brouillon. Avant de specifier
`swarm_logic` en P1.5b, decider : est-ce une relique de CORPS (nombre d'unites) ou de
GRAPHE (aretes actives) ? Cette decision determine si elle empiete sur les reliques G ou les
complement.

### Q4 — Litige newborn : 1 relique de "contre-jeu meta" (Prop-E) est-elle compatible avec l'identite grimdark ?

La DA grimdark "cryptique" (Cthulhu × PoE × Dark Souls) assume-t-elle que le joueur subit le
Puits sans agentivite cross-run, ou qu'il APPREND du Puits pour mieux y descendre ? Si c'est
le second modele (ce que le Grimoire et le post-combat "pourquoi" impliquent), une relique de
contre-jeu meta EST coherente. Si le Puits doit rester "impenetrable", elle ne l'est pas.
**Trancher AVANT Prop-E.**

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| `plague_communion` = payoff multi-affliction sur la CIBLE (verification) | `round-04.md §1.1` ; `src/combat/arena.lua:248-252` (verifies round 4) |
| Reliques defensives universelles StS2 2026 | pixelnitro.com/slay-the-spire-2-relics-spreadsheet-guide-to-all-items-new-mechanics-and-beta-meta-2026/ |
| Gating reliques par avancee (tier ≤ wins) | `00-state.md §2.2` ; `src/run/state.lua:339` (signature rollRelicChoices) |
| Calculs hypergeometriques P(aucune relique) | r02-relics.md §2.5 + calculs directs ce round |
| TFT augments : directionnels early vs payoffs late | bunnymuffins.lol/augment-guide-for-set-13/ (Set 13 guide : distinction temporelle des augments) |
| StS counter tools situationnels | slaythespire.wiki.gg/wiki/Relics (Odd Mushroom, Red Skull) |
| Contamination F dans le pool 1-parmi-3 | r03-relics.md §2.2 (calcul hypergéométrique P≈0.39) |
| Reliques B inc calibres sur hierarchie defectueuse | r03-relics.md §2.5 ; `src/data/relics.lua:27-29` (commentaires inc, verifies round 3) |
| Litige #S : ciblage ampli choc-D | `round-04.md §3` ; ROADMAP-draft §3.4 |
| Litige #O : famines_math anti-growth | `round-04.md §1.3` ; `src/data/relics.lua:34-35` (verifies round 4) |
| Pilier "la forme EST le graphe de synergies" | CLAUDE.md §2 (decision #4) |
| Slay the Spire 2 "relic value is no longer universal" | pixelnitro.com/slay-the-spire-2-relics-spreadsheet-guide-to-all-items-new-mechanics-and-beta-meta-2026/ |
| LocalThunk : "1 regle/Joker" | balatrogame.fandom.com/wiki/Guide:General_strategy |
| Snapshot v1 : effets aura/relique non captures | `00-state.md §5` |
| Tiers des 21 reliques (classification A-F) | `00-state.md §2.2` + r01-relics.md/r02-relics.md (verifications) |
| Invariant #3 (seed+wins+compo → meme offre) | `seed/tests.md §6` ; `00-state.md §6` |
| StS slot marchand separe | slaythespire.wiki.gg/wiki/The_Merchant |

---

*Redige le 2026-06-23 par l'agent lentille-reliques, round 5/10. Lecture seule du repo de jeu.
N'edite que sous `docs/roadmap-lab/`. Piliers respectes : async snapshots / sim deterministe
seedee / DA grimdark / pixel art procedural. Sources citees par URL ou fichier+ligne.
Rounds precedents lus : r01-relics.md, r02-relics.md, r03-relics.md, r04-relics.md,
round-01.md, round-02.md, round-03.md, round-04.md, ROADMAP-draft.md §4+§7+§8+§10,
00-state.md, BRIEF.md.*

Sources consultées ce round :
- [Slay the Spire 2 Relics 2026 (PixelNitro)](https://pixelnitro.com/slay-the-spire-2-relics-spreadsheet-guide-to-all-items-new-mechanics-and-beta-meta-2026/)
- [TFT Set 13 Augment Guide (BunnyMuffins)](https://bunnymuffins.lol/augment-guide-for-set-13/)
- [Balatro Strategy Guide General (Fandom Wiki)](https://balatrogame.fandom.com/wiki/Guide:General_strategy)
- [StS Relics Wiki](https://slaythespire.wiki.gg/wiki/Relics)
- [StS The Merchant Wiki](https://slaythespire.wiki.gg/wiki/The_Merchant)
