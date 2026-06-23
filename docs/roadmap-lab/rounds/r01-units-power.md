# Round 01 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` depuis la lentille **units-power** —
> distinction des unités, budget de puissance par rang, identité, redondance, trous d'archétype.
> Round 1/10. Aucun agent précédent à contredire : on attaque le brouillon v0 directement.
>
> **Garde-fou absolu** : lecture seule du repo. Écriture uniquement sous `docs/roadmap-lab/`.
> Aucun chiffre de design affirmé sans source (URL ou fichier+ligne du repo).
>
> **Sources principales lues** :
> `docs/roadmap-lab/00-state.md` · `ROADMAP-draft.md` · `seed/mechanics.md` ·
> `competitive/{tft,hs-battlegrounds,super-auto-pets,backpack-battles,slay-the-spire,balatro,the-bazaar,postmortems}.md` ·
> `src/data/units.lua` (lignes 1-120 lues directement).

---

## 1. Accords avec pourquoi

### 1.1 Le re-tier « complexité dans les hauts rangs » est structurellement sain

Le brouillon (`ROADMAP-draft.md §3.1`) et l'état canonique (`00-state.md §2.1`) posent que
`cost = rank` et que la complexité (twists T2, auras, tanks, transforms T3) monte avec le rang.
**C'est défendable et il faut le garder.**

Pourquoi ça tient pour nos contraintes :

- **TFT** : le pattern « unités simples T1, synergies complexes T4-5 » est documenté dans
  `competitive/tft.md §V4` : *« ne pas dépasser 3 paliers/type, viser 4-5 types »*, et les champions
  T1 TFT sont délibérément des stat-sticks lisibles pour accélérer l'onboarding. Riot a
  re-tiérisé entièrement pour Dragonlands (op.gg, tft.ninja) exactement sur ce principe.
- **SAP** : les pets T1-T2 de Turtle Pack (10 pets/tier, uniforme) sont simples : ils ont 1-2
  triggers basiques. La profondeur apparaît aux T4-T6, confirmé dans `competitive/super-auto-pets.md §2.2`.
- **Pour The Pit async et run court** : un joueur qui entre avec rang-1 et comprend « ça tape »
  en 5 secondes peut se concentrer sur le positionnement et l'économie. Si les rang-1 avaient déjà
  des twists, l'onboarding écraserait l'exécution.

**Accord ferme** : le profil cible de `00-state.md §2.1` (rang-1 = stat-sticks, rang-5 = transforms)
est la bonne architecture. Ne pas revenir là-dessus.

### 1.2 Les 5 familles DoT comme types est la bonne lecture

Le brouillon (`§3.1`) propose que les types soient les familles burn/bleed/poison/rot/choc.
La répartition actuelle (burn ~13, bleed ~13, poison ~15, rot ~11, choc 11) est dans
`00-state.md §2.1` et vérifiée dans `seed/mechanics.md §1.2`. C'est la bonne décision.

Pourquoi ça tient :

- **HS:BG** confirme : *« 4-5 tags suffisent pour un MVP »* (`competitive/hs-battlegrounds.md §4.3`).
  10 tribus HS:BG avec 230 cartes est hors-portée solo dev. 5 familles sur 83 unités = ratio correct.
- **Postmortems** : Underlords est mort avec ~20 alliances pour ~60 héros. Trop de types dilue
  l'identité de build (`competitive/postmortems.md §2.2` : *« alliances trop nombreuses → joueur
  ne sait plus quel archétype il joue »*).
- Le mapping famille → identité de build est **déjà ancré** dans les effets existants : poison =
  weaken, bleed = slow, burn = propagation, rot = amputation PV max, choc = décharge condensateur.
  Les joueurs découvrent l'identité de la famille au T1-2 (stat-sticks + 1 effet) et l'approfondissent
  aux rangs 3-5 (twists, auras, transforms).

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR : le brouillon suppose que les 83 unités ont des identités distinctes sans le démontrer

**Ce que le brouillon dit** (`§6.2`) :
> « Auditer les 83 unités via tools/sim.lua (win% centré sur la moyenne) pour repérer les unités
> plates/redondantes et les retravailler en data. »

**Ce que la lecture directe de `units.lua` révèle** (lignes 58-120) :

Parmi les rang-2 de burn, voici les 3 enablers présents :

| Unité | Paramètre central | Différence mécanique |
|-------|------------------|----------------------|
| `emberling` | `dps=6, dur=150` | burn standard |
| `cinder_cur` | `dps=4, dur=120, refresh=true` | burn refresh (rallume) |
| `pyre_tender` | `dps=10, dur=180` | burn front-load gros coup lent |

**Le problème** : du point de vue d'un joueur en build, `emberling` et `pyre_tender` se jouent
de manière *presque identique* — les deux posent une brûlure unique, la seule différence est
l'intensité et la durée. Le flag `refresh=true` de `cinder_cur` est réel mais **invisible sans
infobulle** (la décision de lisibilité des reliques s'applique aussi ici).

De même pour le saignement rang-2 : `razorkin (dps=2, slow=20%)`, `gash_fiend (dps=3, slow=20%)`,
`hookjaw (dps=1, slow=30%, dur=300)`. Ce sont des variations de paramètres, pas des variations
d'*identité*. **La distinction entre razorkin et gash_fiend est quasi-nulle** — l'un est +1 dps
en échange de statistiques légèrement différentes.

**Ce que la recherche sur le design de roster enseigne** :

SAP a résolu la redondance non pas en gardant 83 pets mais en donnant à chaque pet une
**niche mécanique différenciée** clairement lisible (`competitive/super-auto-pets.md §3.2` :
*« chaque pet T1 SAP a un trigger unique, pas juste des stats différentes »*). TFT a la même
discipline : les champions d'un même trait ont des *roles* distincts (carry/support/tank) même
avec le même tag (`tft.md §2.1`).

**Balatro** est le cas extrême : 150 Jokers avec des identités si distinctes que les joueurs
les mémorisent par leur *règle modifiée*, pas par leurs stats. LocalThunk dans *Rolling Stone*
(2024-12-24) : *« Chaque Joker modifie une règle différente »* — ce n'est pas 150 Jokers avec
+X Mult différents, c'est 150 effets qualitativement distincts.
Source : [Rolling Stone LocalThunk interview](https://www.rollingstone.com/culture/rs-gaming/balatro-localthunk-interview-1235214060/)

**Le vrai diagnostic manquant au brouillon** : la redondance n'est pas un problème de win% —
c'est un problème de mémorabilité et de décision identique répétée. Deux unités dont les seules
différences sont `dps=2` vs `dps=3` ne créent pas deux décisions différentes en build. Elles
créent la même décision (« prendre le bleed rang-2 ») avec un échelon de puissance.

**Proposition concrète** : avant d'auditer via sim, il faut auditer par **identité de niche** :
chaque unité d'une même famille et d'un même rang doit répondre à une question différente.
Dans la famille burn rang-2, les 3 questions pourraient être :
- « Je veux du burst rapide » → ash_moth (T1, éphémère)
- « Je veux un relanceur régulier » → cinder_cur (refresh)
- « Je veux front-load sur frappe lente » → pyre_tender

**Mais** : ash_moth est rang-1, pas rang-2. La répartition actuelle ne respecte pas encore cette
grille de niches. La lecture de units.lua (lignes 91-120) montre emberling au rang-2 sans
différence de niche claire avec cinder_cur rang-2.

---

### 2.2 DÉSACCORD MODÉRÉ : le budget de puissance rang-1 est trop dispersé et fragilise l'identité early

**Ce que le brouillon dit** (`§3.1`) : les rang-1 sont des stat-sticks. C'est la décision.

**Ce que la lecture révèle** : parmi les 12 unités rang-1, on a :
- 4 stat-sticks purs (bandit, husk, footman, mire_thing — aucun effet)
- `marauder` : `bonus_first` (spike de dégâts premier coup)
- `skeleton` : `thorns` (3 dégâts en retour)
- `demon` : `lifesteal` (40 % de soin)
- `ash_moth` : `burn dps=7` qui décroît vite
- `spore_tick` : `poison dps=1`
- `live_wire` : choc (lu dans seed/mechanics.md — non visible dans les lignes lues)
- `gnaw_rat` et `carrion_pecker` : à vérifier

**Le problème de budget** : `demon` (lifesteal 40 %) au rang-1 est une unité qui autosoigne
massivement dans les combats longs. `ash_moth` (burn dps=7 éphémère) est une unité qui inflige
du burst. Ce sont des niches T2-T3 au rang-1. Le risque identifié dans `tft.md §V1` :

> *« Tease de rang N+1 à 2% dès le niveau N... »* — la surprise d'une unité rang-1 plus
> puissante que prévu crée du high-roll qui déstabilise la courbe de progression early.

**Source additionnelle** : l'analyse de SAP dans `competitive/super-auto-pets.md §2.2` note que
les T1 SAP ont volontairement des effets *simples et immédiats* (pas de gestion de ressources).
`lifesteal 40%` est un effet de *gestion de ressources* (le soin est une ressource secondaire) ;
c'est un profil T2-T3 dans la taxonomie SAP.

**Ce qui est en accord** : les stat-sticks purs (bandit, husk, footman, mire_thing) sont des
rang-1 sains. `skeleton` (thorns 3) est lisible et simple.

**Ce qui est à challenger** : `demon` (lifesteal 40 %) et `ash_moth` (burn 7 éphémère) ont des
niches qui suggèrent rang-2. Le diagnostic « variance early » de `the-pit-balance-diagnosis`
(mémoire) pourrait être en partie causé par ces rang-1 à niche trop forte.

---

### 2.3 DÉSACCORD CRITIQUE : la hiérarchie poison > tank > … > choc n'est pas adressée architecturalement, seulement via le ladder choc

**Ce que le brouillon dit** (`§6.1`) :
> « Hiérarchie poison > tank > … > choc : remonter l'apex du choc. Le ladder choc 5/3/2
> (1 seule unité choc aujourd'hui) est le levier de contenu direct. »

**Le problème** : traiter la faiblesse du choc uniquement par l'ajout de contenu (ladder 5/3/2)
est une réponse de surface. La faiblesse du choc est **architecturale** : son axe de stacking
(condensateur, 0 dégâts à la pose, décharge au prochain coup) est fondamentalement plus lent
à « payer » que les autres familles sur un run court.

**Démontage de l'analogie paresseuse** : le brouillon suggère implicitement « plus d'unités
choc = choc plus fort ». Mais TFT et Balatro prouvent le contraire : ajouter des unités à un
archétype faible sans changer le *mécanisme* crée un pool dilué mais pas un archétype viable.

Référence : dans Balatro, les Jokers basés sur des conditions rares (ex. « si vous avez 0
discard… ») ont été systématiquement re-designés par LocalThunk non pas en en ajoutant d'autres,
mais en changeant la condition de déclenchement pour qu'elle soit *atteignable plus tôt*.
Source : [Balatro wiki — design notes LocalThunk Reddit 2024-02-28](https://balatrogame.fandom.com/wiki/Jokers)

**Ce que le choc devrait faire sur notre run court (10 victoires)** : le condensateur à 0 dégâts
à la pose signifie que le payoff du choc n'arrive qu'après le 1er coup + les stacks accumulés.
Sur un run de 10 victoires avec des combats de ~17 secondes (FATIGUE_START = 1020 ticks @ 60 fps,
`arena.lua:58`), si le premier combat dure 5 secondes et que la cible meurt, les stacks choc
accumulés sont perdus. La **sélectivité de la cible** est l'anti-pattern structurel du choc
contre notre ciblage déterministe (la cible change si elle meurt).

**Proposition concrète** : avant d'ajouter 5/3/2 unités choc, challenger le mécanisme :
- **Option A** : conserver le mécanisme et accepter que le choc soit l'archétype « combo long »
  nécessitant un tank en front pour que la cible survive assez longtemps. C'est un archétype
  *légitime* si et seulement si le placement+sigil permet de le soutenir (anneau ou ligne = meilleur
  pour maintenir une cible vivante longtemps). L'archétype « choc sur survivance » est cohérent
  avec le thème grimdark et le plateau-graphe.
- **Option B** : ajouter à la décharge un effet « stacks transférés à la cible suivante »
  (propagation partielle), ce qui résout le problème de perte de stacks à la mort de la cible.
  Cela exige 1 nouvel op ou une extension de l'op existant (hors budget de ce lab, mais à noter).
- **Recommandation** : valider l'Option A via sim AVANT d'ajouter du contenu. Mesurer le win%
  choc avec et sans tank en front, avec anneau vs carré. Si le win% choc avec tank-en-ligne >
  moyenne de 1σ, l'archétype est viable et manque seulement de contenu. Si < moyenne même avec
  tank, la mécanique doit changer.

---

### 2.4 DÉSACCORD MODÉRÉ : le 6e type structurel (tank/bouclier) est sous-spécifié et risque d'être un fourre-tout

**Ce que le brouillon dit** (`§3.1`) :
> « Un 6e type structurel pour les non-DoT (tank/bouclier/bruiser → 'Carrion' ou 'Bulwark' [PH nom]).
> 5-6 types maximum. »

**Le problème** : regrouper tank + bouclier + bruiser dans un seul type crée une identité floue.
En l'état du roster (`seed/mechanics.md §1.2`) :
- Tank/taunt : 5 unités
- Bouclier aura : 6 unités
- Bouclier périodique : 5 unités
- Bruiser : 3 unités
- Épines : 4 unités

Ces 5 archétypes ont des *niveaux d'agence* radicalement différents : le tank attire les attaques
(aggro/taunt), le bouclier absorbe les dégâts (mitigation), le bruiser frappe fort (offensif pur).
Les regrouper dans un seul type « Bulwark » avec un palier 2/4 qui donne « +20 % de ce que le
type fait » est non-opérationnel parce que le type ne fait pas *une* chose.

**Référence TFT** : les traits TFT qui ont échoué en termes d'identité sont précisément ceux qui
regroupaient des effets hétérogènes sous un nom commun. Le document officiel Riot sur Gizmos &
Gadgets learnings note : *« un trait ne peut pas avoir un bonus qui n'a pas d'identité claire »*.
Source : [Riot learnings Gizmos & Gadgets](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-gizmos-gadgets-learnings/)
(cité dans `competitive/tft.md §2.2`)

**HS:BG** a résolu ce problème en donnant des synergies spécifiques par tribu, pas génériques par
catégorie. « Etre un Mech » donne un bonus Mech, pas un bonus « défensif » (`hs-battlegrounds.md §4.1`).

**Proposition concrète** : plutôt qu'un 6e type, séparer les synergies de mitigation en
deux directions nettement distinctes :
- **Type « Carapace »** (bouclier aura + périodique) : le palier 4 renforce le mécanisme de bouclier.
- **Type « Brute »** (tank/taunt + bruiser + épines) : le palier 4 renforce le mécanisme de front-line.

Cela donne 7 types (5 DoT + Carapace + Brute), soit 2 de plus que le brouillon. **Risque** : au-delà
de 6-7 types, la dilution de l'identité est documentée (Underlords postmortem, `postmortems.md §2.4`).
Mais 7 types sur 83 unités est plus sain que 6 types dont un est un fourre-tout.

**Alternative minimaliste** : garder 6 types mais ne placer dans le 6e que les **tanks/taunt**
(5 unités), avec un palier 2 = +aggro équipe, palier 4 = taunt se transfère au voisin à la mort.
Bouclier et bruiser n'ont pas de type dédié et tirent partie de l'adjacence positionnelle déjà
existante (un tank adjacent à un carry poison = synergie organique sans nouveau type). C'est
la solution la plus simple à implémenter et la plus cohérente avec la boussole « simplicité → profondeur ».

---

### 2.5 DÉSACCORD DE SÉQUENCEMENT : la clarté des identités d'unités doit précéder les synergies par TYPE (contredit l'ordre P0→P1 du brouillon)

**Ce que le brouillon dit** : P0 = lisibilité/feedback (§2), P1 = synergies par type (§3).

**Ce que je propose** : entre P0 et P1, il y a une étape implicite que le brouillon saute —
**l'audit et la correction de l'identité des unités existantes**. Si les unités d'un même rang
et d'une même famille sont interchangeables dans le build, ajouter un palier de type (2 burn
→ +20 % burn) amplifie le problème plutôt que de le résoudre : le joueur choisira n'importe
lesquelles des 3 unités burn rang-2 pour atteindre le palier, sans décision identitaire.

**Référence** : StS n'a pas de système de types, mais ses cartes ont des identités si distinctes
que chaque carte a un nom mémorable et une règle unique. GDC 2019 Giovannetti : *« La première
erreur est d'avoir trop de cartes qui font la même chose avec des nombres différents »*.
Source : [gamedeveloper.com — Giovannetti GDC interview](https://www.gamedeveloper.com/design/what-makes-slay-the-spire-s-combat-the-best-design-in-deckbuilding-games)

**Argument asymétrique** : l'audit d'identité des unités coûte peu (c'est de la data, pas du
moteur) et débloque tout le reste. Les synergies de type avec des unités identitaires = fun.
Les synergies de type avec des unités interchangeables = inflation numérique sans décision.

**Ordre proposé** :
- **P0a** : lisibilité/feedback (§2 du brouillon) — inchangé.
- **P0b** (NEW, intercalé) : audit d'identité des unités — pour chaque famille, chaque rang
  doit avoir au maximum 2-3 unités, chacune avec une **niche fonctionnelle nominée** (1 phrase :
  « l'enabler de base », « le relanceur », « le front-load »). Les doublons sans niche distincte
  sont soit retirés du pool soit fusionnés avec une niche différente.
- **P1** : synergies par type (§3 du brouillon).

---

## 3. Propositions priorisées

### P-A (URGENT, avant tout contenu) : Audit d'identité des unités — une niche par slot

**Quoi** : pour chaque famille (burn/bleed/poison/rot/choc) et chaque rang (1-5), lister les
unités, nommer leur niche en 1 phrase, identifier les doublons. Livrable = tableau dans
`docs/roadmap-lab/` (pas de code).

**Chiffré** : 5 familles × 5 rangs = 25 cases de l'audit. En tenant compte des unités cross-famille
(tank, bouclier, bruiser), ~30 cases. Chaque case contient ≤ 3 unités avec une niche nommée.
Les unités sans niche distincte sont marquées « candidat à la refonte data ».

**Pourquoi avant P1** : une synergie de type `burn(2) → +20%` sur des unités burn rang-2 toutes
interchangeables ne crée aucune décision de build. Elle crée un seuil numérique atteint avec
n'importe quelle combinaison de 2 burn. L'identité des unités est la **condition préalable** à
la lisibilité des synergies de type.

**Source** : principe SAP (un trigger unique par pet, `super-auto-pets.md §3.2`) + Balatro (une
règle modifiée par Joker, `balatro.md §5.3`) + StS GDC 2019 Giovannetti (anti-doublon).

**Coût** : pur design data, 0 ligne de code, 0 invariant touché.

---

### P-B (AVANT LE LADDER CHOC) : Sim choc avec composition ciblée

**Quoi** : avant d'ajouter 5/3/2 unités choc, lancer `tools/sim.lua` avec des builds choc+tank
(gravewarden en front) sur sigil anneau (survie cible plus longue = plus de stacks accumulés).
Mesurer le win% vs poison build et vs tank build.

**Hypothèse testable** : si `win%(choc+tank, anneau)` > moyenne globale ± 1σ, le choc est viable
avec positionnement optimal → manque de contenu (ajouter le ladder). Si < moyenne même avec
setup optimal → la mécanique doit changer (Option B du §2.3).

**Chiffré** : `tools/sim.lua 200` (200 combats par configuration) × 3 configurations = ~30 secondes
de calcul. Livrable : un report JSON dans `runs/` avec le diagnostic.

**Invariants** : aucun touché (sim headless, pas de modification de code). Test existant dans
`tests/props.lua` (fuzz 250 combats) peut être étendu pour ce cas précis.

---

### P-C (PARALLÈLE À P1) : Définir les niches de types structurels avant de coder les paliers

**Quoi** : trancher la question « 1 type structurel ou 2 » (§2.4) par un document de décision
`docs/roadmap-lab/` (pas de code). Puis coder. Pas l'inverse.

**Options** :
1. Un seul 6e type « Taunt » (5 unités tanks uniquement, niche claire) — le plus simple.
2. Deux types « Carapace » + « Brute » (7 types, plus riche, plus cher à implémenter et tester).
3. Pas de 6e type structurel : les non-DoT obtiennent leur profondeur uniquement via l'adjacence
   positionnelle et les reliques (bouclier/tank comme support transversal, pas comme famille).

**Recommandation** : option 1 pour v0.9-0.10, option 2 si l'équilibrage sim montre que les
non-DoT ont systématiquement besoin d'un palier de type pour équilibrer face aux DoT.

---

### P-D (BASSE PRIORITÉ, après P3 du brouillon) : Investiguer le profil rang-1 de `demon`

**Quoi** : vérifier via sim si `demon` (lifesteal 40 %, rang-1) génère une asymétrie de win%
rang-1 supérieure à 1σ de la moyenne. Si oui : ajuster le paramètre (frac = 0.25 ?) ou remonter
au rang-2.

**Pourquoi basse priorité** : la variance early (`the-pit-balance-diagnosis`) a plusieurs causes
potentielles. Isoler `demon` spécifiquement n'est utile qu'une fois les leviers prioritaires
(identité des unités, choc, synergies par type) en place. Un seul levier à la fois (principe
`tools/sim.lua` documenté dans `ROADMAP-draft.md §6.1`).

---

## 4. Questions ouvertes

1. **Niche rang-2 burn** : `emberling` et `cinder_cur` ont-ils une niche assez distincte ?
   La différence `dps=6, dur=150` vs `dps=4, dur=120, refresh=true` est-elle lisible pour un
   joueur sans infobulle détaillée ? → Audit P-A répondra.

2. **Seuils de type sur 3 slots** : le brouillon propose des paliers 2/4. Avec START_SLOTS=3,
   le palier 2 est atteignable dès le début. Le palier 4 = presque la moitié du board max. Est-ce
   que `2 unités du même type` sur 3 slots (67 % de saturation) est un constraint trop dur en
   early ou au contraire un objectif motivant ? → À débattre au round 2 (lentille synergies).

3. **Le regen (1 seule unité `plague_doctor`)** : c'est le trou d'archétype le plus béant.
   1 unité pour un archétype = pas un archétype, c'est une exception. Faut-il compléter regen
   en 5/3/2 comme le choc, ou le garder comme contre-DoT singleton ? Si singleton, cela implique
   qu'il n'y a pas de « build regen » → cohérent avec le design (regen = correcteur, pas pilier).
   → À valider par décision design, pas par sim.

4. **Trous d'archétype non-identifiés** : le brouillon ne liste pas les trous d'archétype
   explicitement. Candidats observés à l'audit : (a) AoE (frappe multiple) = 0 unité identifiée
   dans les lignes lues, (b) heal-on-kill (drain de vie à la mort = soins massifs late) = 0
   unité, (c) « propagation de buff à la mort » (différent de la propagation DoT existante) = 0.
   Ces trous sont-ils intentionnels (hors-scope v0) ou des opportunités de v1 ?

5. **Le double comptage inc% (Litige #B du brouillon)** : palier de type burn(2) → +20% burn +
   aura soot_acolyte (burnInc) + relique B (ampli affliction) = triple inc. Le cap ×3
   (`DOT_CAP_MULT=3`) protège contre le snowball, mais le cumul des stacks actifs (trois sources
   d'inc) compresse le headroom entre un build mono-burn optimisé et un build généraliste. À
   simuler via `tools/sim.lua` lift de co-occurrence AVANT de fixer les valeurs [PH] des paliers.

---

## 5. Synthèse pour les rounds suivants

Les 83 unités actuelles contiennent **trop de variations paramétriques** (même op, params légèrement
différents) et **pas assez de variations de niche** (triggers/ops distincts par rang et famille).
Le brouillon traite ce problème comme un problème d'équilibrage sim (win%), alors que c'est d'abord
un problème de design identitaire. L'audit P-A est la précondition à tout le reste de la lentille
units-power : sans niches nommées, les synergies de type amplifient des décisions sans distinction,
le ladder choc dilue un pool déjà faible, et le 6e type structurel risque d'être un fourre-tout.

**Séquence recommandée issue de ce round** :
```
P-A : audit identité (data, doc) → P-B : sim choc ciblée → P0b (intercalé dans P0) →
P-C : décision type structurel → puis P1 du brouillon (synergies par type).
```

---

*Round 01 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu.
Sources : `docs/roadmap-lab/00-state.md`, `ROADMAP-draft.md`, `seed/mechanics.md`,
`src/data/units.lua`, `competitive/{tft,hs-battlegrounds,super-auto-pets,balatro,postmortems,
slay-the-spire,backpack-battles,the-bazaar}.md`. URLs externes citées dans le corps.*
