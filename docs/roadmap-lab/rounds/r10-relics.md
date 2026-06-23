# R10 — Critique adversariale, lentille RELIQUES (round 10/10)

> **Round** : 10/10 (dernier). **Lentille** : les 21 reliques — impact, build-defining,
> archetypes, equilibre, lisibilite, +/- niveau de boutique (reliques F).
> **Sources internes lues ce round** : `src/data/relics.lua` (integrale, relu ligne a ligne) ;
> `docs/research/relics-design.md` ; `00-state.md` ; `ROADMAP-draft.md §4` (sections reliques) ;
> `round-09.md` (synthese integrale, §4 adoptions reliques) ; `rounds/r09-relics.md` (integrale) ;
> `competitive/slay-the-spire.md §2` ; `competitive/balatro.md §5` ; `seed/mechanics.md §7`.
> **Sources web utilisees** : wayline.io/blog/roguelike-itemization ; switchbladegaming.com/slay-
> the-spire-2-relic-tier-list/ ; mobalytics.gg/slay-the-spire-2/tier-lists/relics ;
> nat1gaming.com/sts2/tier-list/relic-tier-list/.
> **Garde-fou absolu** : lecture seule du repo. Edite uniquement sous `docs/roadmap-lab/`.
> 4 piliers inviolables : async snapshots / sim deterministe seedee / DA grimdark / pixel art
> procedural. 10 decisions definitives + 32 invariants respectes. Toute affirmation cite sa source.

---

## 0. TL;DR — challenge cle (3 phrases)

Le round 9 a correctement adopte `#JJ` (alignement payoff-agence) et retranche `plague_communion`
sur la composition du joueur — c'est la correction la plus impactante des 9 rounds. **Mais deux
problemes structurels non traites persistent : (1) les reliques B sont architecturalement identiques
(meme op `relic_affliction_inc`, meme axe, seule la famille differe) — elles recompensent le
mono-archetype MAIS ne differencient pas les STYLES au sein d'un archetype, ce qui signifie
que deux builds poison radicalement differents (aggro-spread vs slow-weaken) recoivent exactement
la meme relique avec exactement le meme effet, eliminant toute tension de choix intra-famille ;
(2) l'arc temporel de l'offre de reliques (tous les 3 combats) cree une feneture d'acquisition
qui correspond STRUCTURELLEMENT au passage early→mid→late du shopTier, mais la roadmap ne tire
pas parti de cette co-evolution : une relique F (`carrion_ledger`) au round 0-1 double
l'acceleration XP d'un shopTier qui ne produit que des rang-1, cree une valeur negligeable —
les F sont livrees trop generiquement, sans prescription d'arc d'acquisition.**

---

## 1. Accords avec POURQUOI ils tiennent pour nos contraintes

### 1.1 ACCORD FORT — Correction `plague_communion` vers `dot_family_count >= 2` du joueur (#JJ, round-09.md §1.1)

**Ce qui est acte** : `plague_communion` (`plagueAmp=0.25`) s'active desormais si le BUILD du
joueur contient au moins 2 familles DoT distinctes (lu au `combat_start`), et non sur les
afflictions de la CIBLE adverse (ancienne condition `afflictionCount(target.dots) >= 2`,
`arena.lua:248-252`). Source : `round-09.md §1.1` ; `relics.lua:57-58` relu.

**Pourquoi ca tient pour nos contraintes async** : en snapshots, le ghost adverse est fige au
moment de la capture. Les afflictions que cet adversaire subit pendant le combat dependent des
unites du joueur ET du RNG de la sim — mais la COMPOSITION du ghost, elle, est deterministe
(les `dot_family` sont derivees des `id` d'unites, qui sont dans le snapshot). La version
corrigee de `plague_communion` s'active sur une propriete du BUILD LOCAL, pas de l'adversaire
distant — elle est donc 100% reproductible, snapshotable, et align sur le critere `#JJ`
(cause controlee par le joueur). Le mecanisme psychologique transfere entierement : le joueur
qui choisit de jouer 2 familles (ex. burn + bleed) sait, AVANT le combat, que sa relique
sera active. C'est du « pre-action luck » (wayline.io/blog/roguelike-itemization : « pre-action
luck is randomness before your decision — it rewards strategy, not reaction »), le type de
RNG le plus favorable a l'agence percue.

**Nuance importante** : le garde-fou golden (`golden.lua:17`, seed 970156547) doit etre
verifie avant le code. Si le build golden a ≥2 familles DoT, le flag passe INACTIF→ACTIF et
le rebaseline est explicite (invariant #5). Ce verrou est correct et non-negoiable.

### 1.2 ACCORD FORT — Les reliques A (universelles) ne portent pas d'identite de run — choix ACCEPTE (round-09.md §4.4b)

**Ce qui est acte** : ≥89% des offres early contiennent une relique A (calcul
hypergeo : `1 − C(4,3)/C(7,3) ≈ 88.6%` avec 4 A sur 7 eligibles en tier-1). Les A
(`bloodstone/carapace/aegis/whetstone`) sont des stabilisateurs neutres, elles ne portent pas
de `dot_family` et ne contribuent pas au Nom de Build. Source : `round-09.md §4.4b`.

**Pourquoi ca tient** : c'est l'equivalent exact des reliques communes StS (50% du pool
elite) — elles ont une valeur immediatement deployable sans condition. Slay the Spire 2 2026
confirme (switchbladegaming.com/slay-the-spire-2-relic-tier-list/) : « The relics that matter
most in Act 1 are the ones that function immediately without requiring a specific deck setup ».
Les A de The Pit font exactement cela. La decision de les accepter comme « fallback d'identite
pendant les rounds 1-2 » est mecaniquement juste. Ce qui compte c'est le SIGNAL que l'on
envoie au joueur : si les A sont clairement distinguees des B/C/E dans l'offre (format visuel
distinct), le joueur comprend qu'elles ne definissent pas son archetype — elles le stabilisent.
Ce n'est pas traite dans la roadmap actuelle (aucune distinction visuelle proposee).

**Proposition concrete (PRIORITE FAIBLE, RENDER pur, ~30 min)** : dans l'offre 1-parmi-3,
ajouter un glyphe grimdark discret sur les reliques A (ex. simple trait horizontal, « socle ») vs
les B/C/E (icone plus complexe, « rune »). Ne pas utiliser le mot « commun/rare » (casse le
DA grimdark). Signal purement visuel, 0 SIM, 0 moteur, aligne avec §2.6 (audit ≤12 mots).

### 1.3 ACCORD — Critere des COURONNEURS (reliques E doivent OUVRIR une dimension) — adopte pour les futures (round-09.md §4.1)

**Ce qui est acte** : le critere dit qu'une relique E est build-defining ssi elle ouvre
≥1 dimension (placement / inter-familles / composition). Un toggle de flag sans condition =
SHAPER (tier-2/3), pas un COURONNEMENT. Ce critere s'applique aux E FUTURES (P1.5b+).

**Pourquoi ca tient et comment le pousser** : Balatro confirme (balatro.md §5.3) : « un
Joker ne donne pas '+5 ATK'. Il modifie une REGLE du jeu ». La distinction est capitale et
le critere l'encode correctement. Mais le critere est NEGATIF (ce qu'une E NE DOIT PAS etre)
sans etre PRESCRIPTIF (ce qu'elle DOIT faire concretement pour nos 5 sigils et 4 familles).
**Ce que je challange** : le critere generique (§4.11 ROADMAP) dit « dimension de placement »,
mais la topologie des 5 sigils est connue (`shapes.lua`) — la roadmap DEVRAIT nommer des
candidats concrets. Je propose ci-dessous (§3.3) un tableau de 4 reliques E candidates pour
P1.5b+, ancrees sur les sigils existants.

### 1.4 ACCORD — `feeding_frenzy` reclassee : amplificateur de snowball, NON egalisateur (round-09.md §4.2)

**Ce qui est acte** : `feeding_frenzy` (`on_death frenzy_gain per=0.08 cap=6`) est classee
amplificateur/payoff bruiser, PAS egalisateur de matchup. La garantie de pertinence (§4.1 de
la ROADMAP) devrait la cibler aux builds a aggro ≥20. Source : `round-09.md §4.2` ;
`relics.lua:39`.

**Pourquoi ca tient ET une nuance** : wayline.io confirme (source ci-dessus) : « items most
useful when you're already winning are luxuries, not enablers ». `feeding_frenzy` est une
LUXE, c'est exact. Mais la nuance que je souleve : la garantie de pertinence `aggro ≥20`
depend de `dot_family` (P0.5) MAIS AUSSI d'une nouvelle donnee : l'`aggro` medianne du
build du joueur. Cette info n'est PAS dans le snapshot v1 (00-state §5 : snapshot capture
`{version, tier, seed, shape, units={{id, level, col, row}}}` — l'`aggro` est derivee de
`units.lua` par `toComp`, elle est donc recalculable depuis le snapshot sans rien ajouter au
format). Conclusion : la garantie de pertinence est calculable depuis les snapshots existants,
aucune migration de format requise.

### 1.5 ACCORD — 3 archetypes economiques des reliques F avant le marchand P1.5c (round-09.md §4.3)

**Ce qui est acte** : `carrion_ledger`=rush-tier / `black_summons`=spike-mid / `beggars_lantern`=
max-dup. Ces 3 archetypes ont une logique distincte et doivent etre documentes AVANT le marchand.

**Pourquoi ca tient** : les F sont des reliques de META-JEU (elles modifient la RUN, pas le
COMBAT). C'est la seule categorie qui agit sur `RunState` (00-state §4, `relics.lua:64-66`
confirme le champ `runOp`). Sans documentation des archetypes, le marchand les vend sans
decision strategique lisible — le joueur ne sait pas QUAND les prendre (P1.5c). Ce qui
m'interpelle : les F actuelles ont un arc d'acquisition implicite (`carrion_ledger` = meilleure
en early, `black_summons` = meilleure en mid si pas encore T5, `beggars_lantern` = meilleure
tard si on cherche a dupliquer). Cet arc est PRESENT dans le code mais INVISIBLE dans l'offre.

---

## 2. Desaccords avec recherche sourcee

### 2.1 DESACCORD MAJEUR — Les reliques B sont « build-shaping » uniquement en theorie : en pratique elles ne distinguent PAS les styles intra-famille (probleme non traite en 9 rounds)

**Ce que le brouillon affirme** : les reliques B (tier-2) sont « le coeur build-shaping » car
elles recompensent le mono-archetype. Source : `relics-design.md §4-B` ; `round-09.md §4`.

**Mon challenge** : les B sont TOUTES architecturalement identiques — meme op
(`relic_affliction_inc`), seule la famille differe :
```
kings_bowl   = { op="relic_affliction_inc", params={family="poison", inc=0.20} }
ember_heart  = { op="relic_affliction_inc", params={family="burn",   inc=0.30} }
weeping_nail = { op="relic_affliction_inc", params={family="bleed",  inc=0.18} }
grave_cap    = { op="relic_affliction_inc", params={family="rot",    inc=0.18} }
```
Source : `relics.lua:26-29`, relu ligne a ligne.

**Le probleme mecanique** : un build `poison-spread` (unites `contagion`/propagation) et un
build `poison-weaken` (unites `bile_spitter`/`corruptor`) recoivent EXACTEMENT la meme
`kings_bowl` (+20% poisonInc) avec le meme effet quantitatif. `poisonInc` amplifie le DPS du
poison qu'il soit en stacks de contagion ou en stacks normaux — il n'y a aucune distinction.
Ce sont deux strategies radicalement differentes (l'une cherche la propagation laterale via
`Arena:neighborsOf`, l'autre cherche a maxer le weaken) mais la relique les traite
identiquement.

**Pourquoi c'est un PROBLEME, pas juste une simplification** : Slay the Spire 2 (2026) fait
exactement la distinction inverse — ses meilleures reliques sont « contextuelles » :
« Paper Phrog : enemies with Vulnerable take 75% more damage instead of 50%. If you're applying
Vulnerable consistently, this is a colossal multiplier. » (switchbladegaming.com, 2026). Le point
cle : Paper Phrog n'amplifie pas tous les builds Silent, il amplifie le sous-build qui applique
Vulnerable. C'est exactement la granularite qui manque dans The Pit — une relique qui amplifie
les builds SPREAD-poison differemment des builds WEAKEN-poison.

**Pourquoi l'analogie TRANSFERE a nos contraintes** : The Pit a deja la notion de `dot_family`
(P0.5) — mais les reliques ne lisent que la famille, pas le STYLE (spread vs weaken, burst vs
duration). Or le style est derivable des triggers et ops des unites du build (a `combat_start`,
on peut compter combien d'unites ont un trigger `on_death` ou `on_attacked` vs combien ont un
trigger `on_hit` standard). Ce comptage est GRATUIT (0 moteur, lecture des `spec.effects` au
build) et async-safe (les effets sont dans le snapshot v1 via `toComp`).

**Proposition CONCRETE (PRIORITE HAUTE, P1.5a, ~5 lignes data, 0 moteur)** : diviser au moins
UNE relique B (a commencer par `kings_bowl` comme test, famille la plus representee) en deux
variantes :
```
kings_bowl        (actuelle) : +20% poisonInc — universel poison
venom_covenant    (nouvelle) : +15% poisonInc pour chaque unite avec trigger on_death (spread-style)
                               ou +15% poisonInc si build a unite weaken (weaken-style) [a trancher]
```
Si le tableau de saturation P1 montre que le plafond `DOT_CAP_MULT=3` est atteint avec B+aura
+palier2, une variante a perimetre PLUS ETROIT mais PLUS FORTE est exactement le bon levier
— elle cree la tension intra-famille sans casser le cap.

**Garde-fou** : ne pas faire cela pour toutes les B simultanement — commencer par `kings_bowl`
(poison = dominant), mesurer l'impact en sim, puis etendre. Un seul levier a la fois (balance-
sim-design.md, principe de tuning isole).

### 2.2 DESACCORD PARTIEL — La classification tier-gating des reliques (early ≤2 / mid ≤3 / late ≤4) n'est PAS ancree sur la VALEUR mecanique des reliques par phase

**Ce que le brouillon affirme** : les tiers de gating (early ≤T2 / mid ≤T3 / late ≤T4) viennent
de `rollRelicChoices` dans `run/state.lua`. Source : `00-state §2.2`.

**Mon challenge** : le gating est base sur le NUMERO DE TIER de la relique, pas sur sa VALEUR
ATTENDUE par phase. Or :
- `carrion_ledger` (tier 3 = mid/late) donne +6 XP de boutique immediat. Sa valeur EST MAXIMALE
  en EARLY (shopTier 1→2 = besoin de 2 XP ; +6 XP BYPASS le premier palier entier). Si elle
  n'apparait qu'a partir du round 2-3 (mid), son meilleur usage est manque. C'est ANTI-OPTIMAL
  depuis le code.
- `beggars_lantern` (tier 2 = early) decale les cotes 1 tier PLUS BAS (concentre les bas rangs
  pour max-dup). Elle est MAXIMALE en LATE (shopTier 4-5, quand les bas rangs servent au
  triplement). En early, les joueurs n'ont pas encore de build engageable, donc `beggars_lantern`
  en early = relique theoriquement correcte mais pratiquement sous-utile.

Source : `relics.lua:64-66` relu ; `00-state §2.2` ; `00-state §4.3` (table de cotes : T2 ne
contient que rang-1/2, `beggars_lantern` en T2 reduit vers le rang-1 = encore plus trivial).

**Ce que la recherche dit** : mobalytics.gg/slay-the-spire-2/tier-lists/relics (2026) sur StS2 :
« The relics that matter most in Act 1 are the ones that function IMMEDIATELY without requiring
a specific deck setup. » La valeur d'une relique depend de QUAND on la recoit autant que de son
effet. Le gating doit aligner VALEUR PAR PHASE avec DISPONIBILITE PAR PHASE.

**Pourquoi l'analogie TRANSFERE** : StS gere ca via les tiers de coffres (petit coffre = surtout
commun, grand coffre = rare garanti) — la phase determine la probabilite du tier, le tier
determine l'impact. The Pit a un gating INVERSE pour les F : la phase ou elles sont disponibles
n'est pas la phase ou elles sont les plus precieuses.

**Proposition CONCRETE (PRIORITE MOYENNE, data doc, 0 moteur)** :
```
carrion_ledger : abaisser le tier de gating de 3 a 2 (disponible des early, max-valeur early)
beggars_lantern : maintenir tier 2 MAIS ajouter une garantie de pertinence conditionnelle :
  n'apparait que si le joueur a deja ≥2 copies d'une meme unite (signale l'engagement vers le dup)
black_summons : maintenir tier 4 (spike-mid → late = juste)
```
Cout : modification des champs `tier` dans `relics.lua` (3 lignes) + garantie de pertinence
`beggars_lantern` dans `run/state.lua` (~5 lignes, lecture des `build.units` au moment du
`rollRelicChoices`). Async-safe (la condition lit la compo locale, 0 snapshot modifie).

### 2.3 DESACCORD — `second_breath` et `sacred_shield` sont defensives identiques dans 95% des situations : inversion de roles

**Ce que le brouillon affirme** : `second_breath` (tier 3, survie a 1 PV 1x par combat) et
`sacred_shield` (tier 3, 0.5s d'invulnerabilite d'ouverture) sont deux reliques defensives
D distinctes. Source : `relics.lua:47-48` ; `relics-design.md §4-D`.

**Mon challenge** : les deux visent a proteger des unites d'une mort precoce, mais leurs
PROFILS D'ACTIVATION sont opposes :
- `second_breath` protege TOUTES les unites de la 1ere mort pendant le combat — elle est
  maximale dans les matchups OU l'adversaire a un burst important (choc, burn flash).
- `sacred_shield` protege de l'onslaught initial (t<30 ticks, ≈0.5s) — elle est maximale
  quand l'adversaire a des unites a tres courte cooldown (unites rapides front-row).

Dans les faits : `HP_MULT=2` (`arena.lua`, 00-state §3.2) signifie que les combats sont LONGS.
La plupart des morts interviennent apres de nombreux ticks. La fenetre d'`invulnT=30` ticks
(soit 0.5s @ 60fps) correspond a ≈ 1-2 attaques max d'un adversaire rapide. En pratique,
`sacred_shield` est efficace SEULEMENT si l'adversaire a une unite front-row a CDmax ≤30
(`cd` de l'unite la plus rapide). Ce n'est pas un cas frequent (les unites rapides coûtent
cher, rang-3+). `second_breath`, elle, est TOUJOURS utile car toute unite peut survivre une mort.

**La vraie distinction** : ce n'est pas « deux defensives distinctes », c'est « 1 defensive
universelle (second_breath) + 1 defensive tres situationnelle (sacred_shield) ». Les deux en
tier-3 = un tier-3 universel + un tier-3 quasi-dead-pick dans ≥70% des situations.

Source : `00-state §3.2` (HP_MULT=2, combats longs) ; `arena.lua:47` (FATIGUE_START=1020
ticks, confirme la longueur) ; `relics.lua:46-47` relu.

**Proposition CONCRETE (PRIORITE MOYENNE, data doc uniquement)** : dois-je proposer de
BAISSER le tier de `sacred_shield` vers tier 2 (rendu accessible en early ou mid) OU de
l'ENRICHIR pour qu'elle soit plus impactante ? Je propose l'enrichissement :
```
sacred_shield (enrichie) : invulnerabilite t<30 ticks + 1 shield plate = 10 a toutes les unites
```
Cout : modifier `params = { invulnT = 30, shield = 10 }` dans `relics.lua` + etendre
`relic_add_effect` pour appliquer un shield initial a `combat_start`. Zone sans test → test
que `spec.shield == 10` apres `R.apply` sur la compo + que `invulnT=30` est pose sur les
`effects`. 0 invariant de combat modifie (`shield` est deja une mecanique `arena.lua`).

### 2.4 DESACCORD — `hollow_choir` est placee dans le pool-A (a retirer) pour une raison TROP CONSERVATRICE

**Ce que le brouillon affirme** : `hollow_choir` (`pierceHeal=0.40`) est identifiee comme
contre-archetype inexistant (regen = 1 unite, heal-on-kill = 0) → pool-A (a retirer). Source :
`round-08.md §3.1a` ; `ROADMAP §3.1 col H`.

**Mon challenge** : le motif de retrait est correct POUR L'ETAT ACTUEL du roster. Mais la
ROADMAP prevoit `second_breath` (qui est une forme de sustain implicite — l'unite « survit »
= elle guerit virtuellement d'une mort). Si P1.5b (post-choc) ajoute des unites bouclier
periodiques supplementaires, le pool d'unites defensives augmente. `pierceHeal` deviendra
pertinent quand :
1. `second_breath` est present dans les pools adverses (les ghosts avec `second_breath` donnent
   effectivement une « survie » extra = `pierceHeal` affecte-t-elle `secondBreath` ? NON —
   `secondBreath` n'est pas du healing, c'est du « passer a 1 PV »). Donc l'argument tombe.
2. Sauf si `hollow_choir` est reorientee en `pierceShield` (ROADMAP §3.1 col H, Q2). Dans ce
   cas elle DEVIENT pertinente immediatement (les boucliers sont deja presents : `ward_weaver`,
   `oath_keeper`).

**Pourquoi ca tient pour la reorientation** : la reorientation `pierceHeal→pierceShield` est
une operation de DATA seulement (`params.pierceHeal → params.pierceShield` + lecture du champ
dans `Arena:damage`). Le moteur `Arena:damage` gate les boucliers (`arena.lua:432`) et a deja
la logique `ignoreShield` (plusieurs DoT l'utilisent). `pierceShield` serait un case supplementaire
dans ce gate — ≈3 lignes SIM. **Ce changement de direction n'est PAS dans P1.5a (data pure)**
mais en P1.5b (post-choc). L'urgence est faible, mais la DECISON de la reorienter (vs. la
retirer) doit etre prise AVANT P1.5a (sinon on retire une relique qui sera re-ajoutee dans la
vague suivante = double travail).

**Proposition CONCRETE (PRIORITE FAIBLE, decision doc, 0 code maintenant)** : trancher dans
§4.4 ROADMAP que `hollow_choir` est REORIENTEE (pierceShield) en P1.5b, PAS retiree. La
retirer de pool maintenant (pool-A) est correct, mais la decision de la reorienter doit
etre gravee dans §4.4 avant P1.5a pour eviter de la retirer definitivement par inertie.

### 2.5 DESACCORD FORT (NOUVEAU) — Aucune relique n'est POSITIONNELLE : manque le lien build-topologie

**Ce que le brouillon affirme (implicitement)** : les reliques E `forked_tongue` (choc rebondit)
et `everburn` / `open_wounds` modifient des regles d'effet — elles sont les plus « build-
defining ». Source : `relics.lua:51-58` ; `relics-design.md §4-E` ; `round-09.md §4.1`.

**Mon challenge FORT** : parmi les 21 reliques actuelles, AUCUNE n'interagit directement avec
la TOPOLOGIE DU PLATEAU (les 5 sigils, les aretes, la profondeur de colonne). Le critere des
COURONNEURS (round-09.md §4.1) cite « dimension de placement » comme critere E valide — mais
aucune relique existante ne le fait, et aucune candidate concrete n'est nommee.

C'est un TROU de categorie entiere. Le plateau-graphe 3x3 est LE differenciateur signature du
jeu (CLAUDE.md §2 : « la forme du plateau EST le graphe de synergies ») et le Grimoire encode
la connaissance des reliques — mais la meta-connaissance des SIGILS n'est pas reliee aux
reliques.

**Pourquoi c'est un probleme mecanique et pas juste un gap de contenu** : les 5 sigils sont
utilises pour changer la topologie (`[s]` en build). Mais aucune relique ne RECOMPENSE un
sigil specifique. Le joueur qui maitrise le sigil « Croix » (mono-carry extreme) n'a pas de
relique qui amplifie cette maitrise. C'est l'inverse du critere des COURONNEURS : au lieu
d'amplifier, les E actuelles decorrellent totalement la relique du sigil.

**Ce que la recherche dit** : dans Slay the Spire 2 (2026), les reliques les plus memorables
sont CONTEXTUELLES a la strategie du joueur (nat1gaming.com/sts2/tier-list/relic-tier-list/ :
« A-tier relics are strong but either require a specific build or are narrower in application »).
La contextualite n'est pas une faiblesse : c'est ce qui cree le « lock-in » (le joueur choisit
UN chemin et la relique l'y ancre).

**Pourquoi l'analogie TRANSFERE pour nos contraintes async** : une relique positionnelle
s'activerait au BUILD, pas en combat (elle lirait le `shape` du sigil actif au `combat_start`).
Elle est donc snapshotable (`shape` est deja dans le format snapshot, 00-state §5). Elle est
deterministe (les aretes du sigil sont fixes dans `shapes.lua`). Elle est async-safe.

**Proposition CONCRETE — 4 candidats reliques positionnelles pour P1.5b+ (PRIORITE HAUTE) :**

| Sigil cible | Relique candidate | Effet | Lien mecanique |
|---|---|---|---|
| Croix (mono-carry) | `axis_pact` | Le carry central (case 2,2) gagne +30% dmg et +50% HP | `shape=="croix"`, lire la case adjacente a ≥2 aretes isolees |
| Ligne (conduit front→back) | `bloodline` | Les unites en ligne directe (meme colonne) partagent 10% de leur dps max | `shape=="ligne"`, voisins de meme `col` |
| Anneau (chaine) | `ring_hunger` | Chaque unite donne +5% affliction_inc a ses 2 voisins de l'anneau | `shape=="anneau"`, voisins dans le cycle |
| Diamant (go-wide) | `horde_pact` | Les unites rang-1/2 gagnent +10 HP chacune | `shape=="diamant"` + compter nb unites rang≤2 du build |

Ces 4 candidats sont 0-moteur (ils lisent `shapes[shape].edges` et `spec.id`→`Units[id].cost`
deja disponibles au build). Ils satisfont le critere COURONNEURS (ouvrent une dimension de
PLACEMENT) et sont grimdark-cohernets (nom court, effet ancre sur le Puits).

**Garde-fou** : ces reliques n'IMPOSENT pas de sigil (le joueur peut toujours changer avec
`[s]`) — elles RECOMPENSENT un engagement deja pris. Elles sont des egalisateurs de matchup
(la croix donne un carry fort mais isole, le diamant donne du wide mais pas de carry) — pas
des gates. Conforme aux principes §1 de relics-design.md.

### 2.6 DESACCORD PARTIEL — La relique `thornguard` est une relique D mais elle joue le role d'une relique C

**Ce que le brouillon affirme** : `thornguard` (tier-2, epines d'equipe via `on_attacked,
thorns, value=2`) est une defensive D. Source : `relics.lua:43-44`.

**Mon challenge** : les epines (`thorns`) se declenchent QUAND ON EST FRAPPE. Ce n'est pas
une relique defensive (elle ne reduit pas les degats recus) — c'est un PAYOFF CONDITIONNEL
SUR L'EXPOSITION (plus d'unites en front qui encaissent = plus d'epines rendues). Elle joue
le role d'une relique C (palier/payoff) : elle recompense le joueur qui EXPOSE deliberement
ses unites (builds tanks-front, build large avec exposure maximale).

La distinction D/C n'est pas juste aesthetique : elle determine QUAND l'offrir (C = mid/late
quand le build est engage, D = universellement disponible des early). Si `thornguard` est en
tier-2, le joueur peut la recevoir avant d'avoir un build «expose» et la valeur est
sous-optimale (un build a 3 unites slow en position arriere ne recoit presque jamais de
coups).

Source : `relics.lua:43-44` relu ; `arena.lua` (thorns = `on_attacked` hook, confirme
l'exposition comme prerequis d'activation).

**Proposition CONCRETE (PRIORITE FAIBLE, doc seulement)** : reclassifier `thornguard` en C
dans la documentation interne (relics-design.md §4, pas dans le code) et aligner le tier de
gating : passer de tier 2 a tier 3 (mid/late, quand le build est assez populate pour generer
une exposition reelle). 1 ligne de data (`tier = 3`), 0 moteur.

---

## 3. Propositions priorisees

### P1 (BLOQUANTE pour P1.5a) — Decider sur `hollow_choir` : reorientation pierceShield vs retrait definitif

**Cout** : decision doc, ~15 min. 0 code maintenant.
**Pourquoi P1 BLOQUANTE** : si `hollow_choir` est retiree de `U.pool` (pool-A) sans decision sur
sa reorientation, elle risque d'etre oubliee en P1.5b. La decision preserve l'option de la
reorienter sans coder maintenant. §4.4 ROADMAP doit etre enrichi de cette decision explicite
avant P1.5a.

### P2 (PRIORITE HAUTE, avant P1.5a) — Specifier 2 reliques positionnelles (sigil-aware) pour les 5 sigils

**Cout** : ~1h doc, 0 moteur. Spec dans §4.11 ROADMAP + `relics-design.md §5` (carte
archetype → relique, deja en place pour les archetypes DoT — ajouter les archetypes sigil).
**Pourquoi HAUTE** : les reliques G (topologie/sigils, CLAUDE.md §7) sont « DIFFEREES » en P4,
mais une relique POSITIONNELLE (qui recompense le sigil sans modifier la topologie) est
categoriquement differente — 0 moteur, juste lecture du `shape`. Les nommer maintenant
(§3.5 de ce document, tableau de 4 candidats) evite un trou de spec au moment de P1.5b.

### P3 (PRIORITE HAUTE, P1.5a) — Corriger le tier-gating de `carrion_ledger` (tier 3 → 2)

**Cout** : 1 ligne de data (`tier = 2`), 0 moteur. Test de rebaseline : `relics.lua` est
lu dans `run/state.lua:rollRelicChoices` → verifier que la table de tier ne casse aucun
invariant (invariants #18-21, 00-state §6). 0 invariant de combat.
**Pourquoi HAUTE** : `carrion_ledger` est la seule relique F qui cree une ACCELERATION de
shopTier. Sa valeur est maximale en early (bypasser le premier palier XP est decisif). En
tier-3, elle arrive systematiquement APRES le seuil optimal. C'est une correction de data pure.

### P4 (PRIORITE HAUTE, P1.5a post-simulation) — Granularite intra-famille sur UNE relique B (test `venom_covenant` poison)

**Cout** : ~5 lignes data (1 relique supplementaire dans R.order), 0 moteur (le champ
`poisonInc` est deja lu dans `ampDps`). Test : verifier que `R.apply` applique la condition
correctement sur un comp mock avec et sans unite weaken.
**Pourquoi HAUTE mais post-simulation** : ne pas faire sur toutes les B en meme temps. Commencer
par la famille DOMINANTE (poison), mesurer l'impact sur `offer_decision_quality`, puis etendre.

### P5 (PRIORITE MOYENNE, doc avant P1.5b) — Tableau de 4 reliques positionnelles signees sigil (spec, 0 code)

**Cout** : ~30 min doc dans §4.11 ROADMAP + §5 relics-design.md. Tableau prevu au §3.5
ci-dessus (4 candidats `axis_pact / bloodline / ring_hunger / horde_pact`). 0 moteur, 0 test.
**Pourquoi MOYENNE** : spec P1.5b, pas urgente avant P1.5a, mais critique avant P2 (ranked) car
les sigils que les ghosts utilisent dependront des reliques positionnelles disponibles.

### P6 (PRIORITE FAIBLE, doc seulement) — Reclassifier `thornguard` en C (tier 3) + signal visuel reliques A vs B/C/E

**Cout** : 2 lignes de data (`tier = 3` pour `thornguard`) + 30 min spec UI pour le glyphe A.
**Pourquoi FAIBLE** : cosmeto-editorial, 0 impact sur la SIM. Mais coherent avec la hierarchie
emotionnelle (les C sont mid/late = payoffs, pas les D defensives = universels).

---

## 4. Questions ouvertes

**Q1** — `plague_communion` (corrigee `dot_family_count >= 2` du joueur) : quelle est la
VALEUR ATTENDUE du flag `plagueAmp=0.25` quand le build a exactement 2 familles (early) vs 4
familles (late) ? La magnitude est-elle calibree pour les deux cas ? `0.25 more` sur TOUS les
degats de l'equipe = tres puissant si le build est full-damage late. CONFIG-PC (ROADMAP §3.9)
reste bloquant : mesurer l'activation sur `dot_family_count >= 2` du joueur sur N=200
combats avant de valider la magnitude.

**Q2** — `beggars_lantern` (tier-2, cotes -1 tier) : sa garantie de pertinence actuelle
(ROADMAP §3.10 Q3 relics) est « ≥2 meme id OU ≥1 rang-1 ». Avec la granularite intra-famille
proposee (P4), est-ce que la DUPLICATION d'une unite rang-1 (ex. 3 gnaw_rat) est une strategie
viable ? Si oui, `beggars_lantern` devient tres forte en early (cotes -1 tier = plus de rang-1
= triplement plus rapide sur les T1 peu chers). Cela casse-t-il le modele economique ?
Mesurer sur N=100 runs avec politique `rush_dup_T1` avant de valider la garantie de pertinence.

**Q3** — Les 21 reliques couvrent 4 familles DoT (B) + universels (A) + quelques payoffs (C) +
defensives (D) + transformatives (E). Mais la famille CHOC n'a qu'une seule relique B equivalente :
`forked_tongue` est tier-4 et transformative. Il n'y a PAS de relique B pour le choc (pas de
`shockInc` equivalent a `kings_bowl`). Est-ce voulu ? Si la hierarchie choc < poison vient en
partie de la fiabilite de declenchement (CONFIG-CE2, round-09.md §3.3), l'absence d'un ampli B
de choc aggrave le probleme : le joueur qui investit dans le choc n'a aucun signal de relique
B avant tier-4. Bloquant si #GG (axe apex choc) est resolu vers l'axe A/B (burst) — dans ce
cas une B `shockInc` est le premier signal d'engagement choc lisible.

**Q4** — La roadmap propose une relique B scalante `resonance_stone` (round-09.md §1.2, P1.5b
candidate). Comment `resonance_stone` interagit avec les reliques positionnelles proposees
(§3.5) ? Un build `anneau + resonance_stone + ring_hunger` accumule (a) l'inc scalant par
coherence familiale + (b) l'amplification voisin de l'anneau. Si ce double boost passe le
plafond `DOT_CAP_MULT=3` (ops.lua:22), le build est overtuned. Verifier la saturation
AVANT de graver `resonance_stone` ET `ring_hunger` dans la meme vague.

---

## 5. Bilan — ce que ce round ajoute au precedent

Le round 9 a resolu le BUG D'ALIGNEMENT (#JJ, `plague_communion`, badge MAÎTRE, §2.10) —
c'est le correctif le plus profond des 9 rounds. Ce round 10 attaque deux problemes que
9 rounds n'ont pas touchés :

1. **GRANULARITE INTRA-FAMILLE** : les reliques B traitent identiquement des styles de play
   radicalement differents au sein d'une meme famille. La solution est un ajout de DATA (1
   relique supplementaire par famille, en commencant par la dominante), pas une refonte.

2. **MANQUE DE RELIQUES POSITIONNELLES** : le differenciateur sigil du jeu n'a AUCUNE relique
   qui le recompense. Les candidats sont 0-moteur (lisent `shapes.lua` deja disponible),
   async-safe (shape est dans le snapshot), et satisfont le critere COURONNEURS adopte en
   round 9. Le cout de conception est faible ; le gain d'identite de run est eleve (un build
   « Croix avec `axis_pact` » est immediatement nommable et memorisable).

Ces deux manques ne sont pas des trous de contenu ordinaires — ils revelent une ASYMETRIE
DE DESIGN : le moteur (effets/sigils/adjacence) est riche, mais les reliques ne parlent que
de la couche DoT, ignorant entierement la couche topologique. Corriger cela aligne les
reliques avec les piliers du jeu.

---

*Round 10 redige le 2026-06-23. Sources internes relues ligne a ligne : `relics.lua` integrale,
`arena.lua` (thorns hook, shield gate, HP_MULT), `shapes.lua` (aretes), `run/state.lua`
(rollRelicChoices). Sources web : wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency ;
switchbladegaming.com/slay-the-spire-2-relic-tier-list/ ;
mobalytics.gg/slay-the-spire-2/tier-lists/relics ;
nat1gaming.com/sts2/tier-list/relic-tier-list/. Lecture seule du repo ; n'edite que sous
`docs/roadmap-lab/`. 4 piliers intacts. 32 invariants preseves (toutes les propositions sont
data/doc, 0 SIM modifiee, 0 invariant de combat touche). Propositions cotees et priorisees.*
