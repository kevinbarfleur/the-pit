# Round 03 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v3, intégré round 2) depuis la lentille
> **units-power** — distinction des unités, budget de puissance par rang, identité, redondance,
> trous d'archétype. Round 3/10.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` (v3), `00-state.md`, `round-01.md`, `round-02.md`,
> `rounds/r01-units-power.md`, `rounds/r02-units-power.md`, `competitive/*.md` (tous),
> `src/data/units.lua` (intégralité relue ce round), `src/data/relics.lua`.
>
> **Méthode** : désaccord = recherche web menée et citée. Analogie = démonter son mécanisme
> psychologique/mathématique avant d'accepter. Toute affirmation chiffrée porte sa source.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous `docs/roadmap-lab/`.
> Piliers respectés (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural).

---

## 0. TL;DR de ce round

Le brouillon v3 a adopté les deux critiques majeures du round 2 (distinction niche/pool,
audit `dot_family`, reformulation du test choc) et les a bien intégrées dans P0.5. Mon
challenge de ce round porte sur **trois zones non résolues** que les rounds 1 et 2 ont effleurées
mais pas tranchées :

1. **La cible « ≤4 enablers/famille/rang dans U.pool » est juste comme plafond, mais le PLANCHER
   est absent** : il n'y a aujourd'hui qu'**1 unité rot rang-2** dans U.pool après nettoyage
   (`rot_hound` et `bore_worm`), et **2 unités bleed rang-2 saines** si on retire les doublons.
   Une famille avec 1-2 enablers rang-2 est trop fragile pour permettre le ciblage précoce (le
   joueur ne voit jamais la famille). La règle du brouillon corrige la sur-dilution mais crée
   potentiellement une sous-représentation de rot et de bleed early.

2. **Le budget de puissance par rang n'est pas chiffré** : le brouillon fixe la *structure*
   (rang-1 = stat-stick, rang-2 = enabler mono-DoT simple, rang-3 = enabler + 1 modificateur,
   rang-4 = twists, rang-5 = transforms) mais ne dit jamais **quel delta stat (hp, dmg, cd)
   justifie le passage d'un rang au suivant**. Sans cela, l'audit P0.5 ne peut pas détecter les
   unités « sous-coûtées » (trop fortes pour leur rang) ni « sur-coûtées » (trop faibles). Ce
   manque est un VRAI trou d'audit, pas un commentaire cosmétique.

3. **Le litige #G (axe du choc) reste ouvert mais l'axe C (amplificateur PoE-style) a un
   problème de cohérence avec le plateau-graphe 3×3** que ni le round 2 ni le brouillon ne
   pointent : la PoE Shock amplifie le **prochain hit reçu** (source indifférente), mais en
   contexte 3×3 avec ciblage déterministe (colonne avant → taunt → aggro → tie-break), le
   « prochain hit reçu » arrivera TOUJOURS sur la même unité (celle en front). L'axe C résout
   la viabilité déterministe globalement MAIS crée un concentrateur de dégâts sur la
   cible-front qui est déjà la plus ciblée — il peut paradoxalement rendre le tank ennemi
   (haut aggro, en front) encore plus difficile à tuer (charge → frappe par le tank → discharge
   amplifie la frappe SUIVANTE sur le tank → mais le tank est déjà la cible, pas une unité choc).

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — distinction niche/pool avec remèdes opposés (adopté round 2)

Le round 2 a nommé le problème précisément et le brouillon v3 l'a intégré avec la grille à
4 colonnes (niche / type de redondance / remède / `dot_family`). L'accord est total.

**Pourquoi ça tient pour nos contraintes** : le `SHOP_SIZE=5` (`state.lua:34`) combiné à un
pool non filtré de 23 unités rang-2 crée une fréquence d'apparition par unité de :

```
P(unité spécifique rang-2 | boutique rang-2) = 1/23 ≈ 4.3 %/slot
P(au moins 1 slot burn rang-2 sur 5 slots) = 1 - (18/23)^5 ≈ 67 %
```

Avec `SHOP_SIZE=5` et 5 burn rang-2 dans le pool (`units.lua:67-100`), la probabilité de voir
AU MOINS UN burn rang-2 à chaque boutique en T2 est de ~67 %. Sans distinction de niche, ces
apparitions ne génèrent pas de décision — elles génèrent du bruit. L'analogie SAP (10 pets/tier
avec triggers distincts — `superautopets.fandom.com/wiki/Turtle_Pack` : 60 pets sur 6 tiers,
`a327ex.com/posts/super_auto_pets_mechanics`) tient pour nos contraintes **parce que le
mécanisme psychologique est identique** : un choix entre deux unités au même coût ne vaut que
si les conséquences de build sont perceptiblement différentes. Ce n'est pas une analogie
paresseuse — c'est une équivalence de la mécanique de « décision vide ».

### 1.2 ACCORD — audit `dot_family` avant P1 (adopté round 2)

La décision de créer un champ `dot_family` explicite (nil pour les non-DoT) est correcte.
La preuve est dans l'analyse des multi-effets : `wither_bloom` a 3 ops DoT (`rot` + `bleed` +
`poison`, `units.lua:283-285`), et sans règle explicite de famille principale, le compteur de
palier P1 serait non-déterministe selon l'ordre d'itération. La règle adoptée (`dot_family =
op du 1er effet DoT non-aura`) est saine et testable.

**Pourquoi ça tient** : la règle du 1er effet est un invariant robuste dans notre architecture
(array + ipairs — `CLAUDE.md §4 : « Tout ordre de sim en array + ipairs, jamais pairs »`). Elle
est déterministe, rétro-compatible (nil = inerte), et documentable en O(83) lignes.

### 1.3 ACCORD — cible ≤4 enablers/famille/rang dans U.pool

Correct comme plafond. La cartographie complète depuis `units.lua` confirme les surplus :
- burn rang-2 : 5 unités (`emberling`, `cinder_cur`, `pyre_tender`, `pyre_herald`,
  `zeal_inquisitor`) — dont `pyre_herald` (dps=6, dur=170) ≈ `emberling` (dps=6, dur=150)
  et `zeal_inquisitor` (burn via `on_hit`, aggro=15) distingué seulement par le profil aggro
- poison rang-2 : 6 unités (`witch`, `rot_grub`, `chitin_drone`, `coil_viper`, `web_recluse`,
  `ink_horror`) — distinguées uniquement par dps=2-3 et dur=160-300

Ces surplus sont démontrés. La cible ≤4 dans U.pool est appropriée.

### 1.4 ACCORD — test opérationnel du choc en matrice 3 configs (adopté round 2)

Le remplacement du seuil global « >30 % de décharges perdues sur le fuzz 250 » par une
matrice de 3 configurations spécifiques (Config A : tank+choc+ligne N=50 ; Config B :
galvanizer carré N=50 ; Config C : choc pur+anneau N=50) est correctement motivé.

**Pourquoi ça tient** : MegaCrit (Slay the Spire, GDC 2019, 18M runs —
`gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder`)
évalue les cartes dans leur archétype, pas en win-rate brut. Un archétype conditionnel
(choc = condensateur arrière qui exige un tank et un sigil conduit) jugé sur un fuzz
aléatoire de sigils/placements est jugé dans son pire contexte. La matrice reproduit le
raisonnement MegaCrit adapté à nos contraintes (seed fixe `20260623` garantit le
déterminisme — invariant #2).

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD CRITIQUE — La règle « ≤4/famille/rang » n'a pas de PLANCHER : rot et bleed ont un problème de sous-représentation early

**Ce que le brouillon dit** (P0.5 §3.1, ROADMAP-draft §3.1) :
> « Cible : ≤4 enablers par famille par rang dans U.pool (poison rang-2 : 6→3-4 ;
> burn rang-2 : 5→3). »

**Ce qui manque** : le brouillon fixe seulement le plafond. Il ne dit pas combien d'enablers
**minimum** une famille doit avoir par rang pour être visible en boutique.

**Preuve issue du code** :

En appliquant la règle ≤4 aux familles sous-représentées (`units.lua` complet relu) :

| Famille | Rang-2 actuel | Après nettoyage ≤4 | Après nettoyage ≤3 |
|---------|--------------|--------------------|--------------------|
| Burn    | 5            | 4 (retirer 1)      | 3 (retirer 2)      |
| Bleed   | 5            | 4 (retirer 1)      | 3 (retirer 2)      |
| Poison  | 6            | 4 (retirer 2)      | 3-4 (retirer 2-3)  |
| **Rot** | **2**        | **2 (inchangé)**   | **2 (inchangé)**   |
| Choc    | 4            | 4 (inchangé)       | 3 (retirer 1)      |

Rot rang-2 : `rot_hound` (base=1, capDps=10) et `bore_worm` (base=1, capDps=8, dur=210) —
**2 enablers** dont les niches sont réellement distinctes (cap différent, bore_worm est de la
vague v7 `units.lua:390-392`). Après nettoyage des sur-représentées, rot reste à 2 enablers
rang-2, soit la moitié du plancher burn/bleed/poison.

**Quel est le plancher mathématique de visibilité ?** Avec `SHOP_SIZE=5` et un pool rang-2
uniforme (supposons 18 unités après nettoyage au ≤4/famille) :

```
P(voir au moins 1 rot rang-2 | boutique T2) = 1 - (16/18)^5 ≈ 1 - 0.889^5 ≈ 43 %
```

Avec seulement 1 rot rang-2 dans le pool :
```
P(voir rot rang-2 | boutique T2) = 1 - (17/18)^5 ≈ 25 %
```

Un joueur qui veut construire un build rot a 25-43 % de chance de voir ROT dans sa boutique
au tier T2, selon que rot a 1 ou 2 enablers. C'est insuffisant pour que la famille soit
*proposée* comme chemin de build early. Pour comparaison, un pool rot à 4 enablers :
```
P(voir rot rang-2 | boutique T2) = 1 - (14/18)^5 ≈ 78 %
```

SAP résout ce problème par un pool *par tier* de **10 pets dont les probabilités
d'apparition sont ajustées par slot** (5 slots tier-appropriés sur chaque run —
`superautopets.wiki.gg` ; chaque pet T1 = 1/10 chance par slot visible). The Pit n'a pas ce
levier (pool uniforme non filtré, `state.lua:buildShop` sans pondération/unité). **Il faut
donc un plancher de visibilité minimale par famille, pas seulement un plafond anti-dilution.**

**Source** : calculs hypergéométriques analogues au raisonnement de `relics.lua` adopté pour
les reliques (round 2 §1.5 : « ≥2 reliques/archétype pour P<25 % de ne pas voir »). Le même
raisonnement s'applique aux unités : une famille dont P(voir 1 enabler/boutique) < 40 % n'est
pas un chemin de build — c'est un archétype caché.

**Proposition concrète (§3.1 enrichi)** : l'audit P0.5 doit spécifier un **double critère** :
- Plafond : ≤4 enablers/famille/rang dans U.pool (adopté)
- **Plancher : ≥2 enablers/famille au rang-2 ET ≥2 au rang-3** pour que chaque famille
  atteigne P(visible/boutique) ≥ 40 %. Si une famille a 1 enabler au rang-2 après
  nettoyage → soit en créer un 2e avec niche distincte (axe différent), soit la compenser
  par un rang-1 fort ET un rang-3 early (signal alternatif). Rot est le seul cas critique
  identifié (2 enablers rang-2 déjà existants → inchangé, mais à surveiller).

---

### 2.2 DÉSACCORD MODÉRÉ — Le budget de puissance par rang n'est nulle part chiffré dans P0.5 : l'audit est incomplet

**Ce que le brouillon dit** (P0.5 §3.1, structure de l'audit) :
> « Tableau 5×5 — 4 colonnes : niche / type de redondance / remède / `dot_family` »

**Ce qui manque** : aucune colonne « cohérence budget » — c'est-à-dire une vérification que
les stats (hp, dmg, cd) d'une unité sont appropriées à son rang. Sans cela, l'audit identifie
les problèmes *qualitatifs* (même niche) mais pas les problèmes *quantitatifs* (unité trop
forte/faible pour son coût).

**Preuve issue du code** (mesure directe depuis `units.lua`) :

Calculons le **DPS de base** (dmg/cd) par rang, pour les unités burn rang-2 :

| Unité | rang | dmg | cd | DPS base |
|-------|------|-----|-----|---------|
| emberling | 2 | 5 | 50 | 0.100 |
| cinder_cur | 2 | 4 | 34 | 0.118 |
| pyre_tender | 2 | 7 | 72 | 0.097 |
| pyre_herald | 2 | 7 | 64 | 0.109 |
| zeal_inquisitor | 2 | 8 | 68 | 0.118 |

Comparaison rang-3 burn (`bellows_priest`, dmg=6, cd=54) : DPS base = 0.111.
Comparaison rang-1 burn (`ash_moth`, dmg=3, cd=40) : DPS base = 0.075.

`zeal_inquisitor` (rang-2, cost=2) a DPS = 0.118 — **supérieur à `bellows_priest` rang-3** (0.111).
`cinder_cur` (rang-2) = 0.118 — idem. C'est une anomalie de budget : un enabler rang-2 ne
devrait pas dépasser le DPS de base d'un twist rang-3.

**Ce n'est pas un bug d'équilibrage trivial** : ces unités ont des HP inférieurs (34 pour
cinder_cur, 40 pour emberling), ce qui compense partiellement. Mais le profil stat (fragile +
DPS élevé) d'un rang-2 peut être mécaniquement identique à celui d'un rang-3 avec HP différent.
Si on ne spécifie pas la formule de budget, l'audit P0.5 ne peut pas distinguer « c'est voulu »
de « c'est un placeholder ».

**Source** : GhostCrawler (ex-lead designer Riot/Blizzard) sur le power budget :
> « Putting 40 points into every stat creates a bland champion with no strengths or weaknesses.
> A champion should have 40 points total — sharp strengths and sharp weaknesses. »
(`askghostcrawler.tumblr.com`, 2017, archivé via web.archive.org)

Cette règle s'applique **entre les rangs** : un rang-2 doit avoir un budget total perceptiblement
inférieur à un rang-3 (coût = rang = budget). Si le DPS de base d'un rang-2 dépasse celui d'un
rang-3, la contrainte de coût ne reflète plus la contrainte de puissance. Le système
`cost = rank` (décision §10) ne tient que si le **budget réel correspond au coût**.

**Proposition concrète** : ajouter une **5e colonne à l'audit P0.5** : « cohérence budget —
DPS base (dmg/cd), HP, hp×dmg/cd (EHP×DPS proxy) — dans la plage [rang-1, rang-2, rang-3]
attendue ? ». Seuil indicatif : DPS base rang-2 < DPS base médian rang-3 (sinon over-statted
pour le coût). Coût : calcul tableur, 0 ligne de code.

---

### 2.3 DÉSACCORD FORT (NEW) — L'axe C du choc (amplificateur) a un problème de logique sur le plateau 3×3 qui n'est pas adressé dans le brouillon

**Ce que le brouillon dit** (P0.5 §3.3, litige #G) :
> « Axe C — amplificateur du prochain hit reçu : chaque stack → la cible prend +N % des
> dégâts de la prochaine source (frappe OU tick DoT). Résout viabilité déterministe
> (profite à n'importe quelle source même si l'unité choc est morte), la hiérarchie
> (choc amplifie poison/burn au lieu d'en être concurrent), et la niche. »

**Ce qui est partiellement faux ou insuffisant** : l'axe C résout le problème de la
viabilité déterministe au niveau *global* (une unité choc morte voit sa charge transférée
en buff actif sur la cible), mais introduit un **problème de concentration** dans le
contexte du ciblage déterministe.

**Mécanisme de concentration** :

Sur un plateau carré (forme par défaut), le ciblage déterministe suit :
1. Colonne avant (depth le plus bas = maxCol - cell.x)
2. Override taunt
3. Aggro max
4. Tie-break haut→bas

Résultat : **toutes les unités attaquent la même cible en front**, jusqu'à sa mort, puis
la suivante. Avec l'axe C (choc = +N % dégâts de la prochaine source) :

- L'unité choc applique N stacks de choc sur la cible-front
- La cible-front est aussi celle que TOUS les alliés attaquent
- La décharge amplifie le **prochain hit** sur cette cible, qui vient naturellement de l'unité
  alliée avec le cd le plus bas
- **Paradoxe** : si la cible est un tank adverse (aggro élevée, en front), l'amplification
  profite au tank adverse (absorbe plus de dégâts → renforce sa survie) sauf si le prochain
  hit tué le tank — ce qui n'est pas garanti

Plus précisément : l'axe C résout la viabilité quand la cible meurt vite (DoT + discharge +
amplification = burst accéléré). Mais contre des compos tank (aggro élevée + HP élevés +
shield), le burst amplifié consomme le bouclier mais n'est pas calibré pour dépasser la
régénération ou les boucliers périodiques. **L'axe C est donc fort contre les squishies
(compos glass-canon) mais potentiellement neutre contre les tanks** — ce qui est l'inverse
de l'axe attendu d'un archétype « supporte les autres DPS ».

**Source PoE vérifiée** : `poewiki.net/wiki/Shock` confirme que le PoE Shock est un
*Non-Damaging Ailment* qui amplifie les **dégâts subis** (pas seulement le prochain hit),
avec un maximum de +50 % (`max effect = 50% increased damage taken`). **MAIS PoE Shock a
un mécanisme clé absent du draft de l'axe C** : dans PoE, Shock amplifie **tout** le dégât
reçu pendant sa durée (duration = 2s base), pas un seul hit. Un seul choc PoE = buff
persistant de X% sur une fenêtre temporelle. Si The Pit implémente Shock comme
« 1 stack = amplifie 1 hit », le mécanisme est beaucoup plus faible que PoE car un combat
peut durer 1020 ticks (~17s) avec des dizaines de hits.

**Ce que l'axe C devrait préciser pour être comparable à PoE** :
- Version A (fidèle à PoE) : N stacks = +N% dégâts sur **toute la durée restante** du choc
  (dégâts continus amplifiés, pas juste 1 hit). Plus fort, plus cohérent avec PoE, mais
  touche **tous** les hits (DoT compris) → change plus radicalement la boucle de combat.
- Version B (brouillon) : N stacks = amplifie le **prochain hit uniquement**, puis stacks
  consommés. C'est un burst conditionnel, plus lisible, mais très différent de PoE.

**Le litige #G devrait distinguer ces deux sous-versions** avant de tester en sim.

**Proposition concrète** (enrichissement du litige #G) : avant de trancher axe A/B/C,
ajouter au litige #G la question de la **portée temporelle de l'ampli** :
- C-bis : durée (amplifie tous les hits sur N ticks, comme PoE Shock)
- C-ponctuel : 1 hit (version brouillon actuelle)
Et tester en Config D : choc + tank adverse + DoT poison, N=50, pour mesurer si l'axe C
amplifie le burst sur un tank résistant ou perd son effet (ce que la matrice 3 configs actuelle
ne couvre pas — elle ne teste pas le scénario adversaire le plus résistant).

---

### 2.4 DÉSACCORD LÉGER — Les rang-5 (T3 transforms) ont des identités floues non adressées par le plan actuel

**Ce que le brouillon dit** (00-state §7.1) :
> « Quelques T3 simplifiés (ash_maw sans spread-on-death équipe ; pit_maw = rot équipe ennemie ;
> wither_bloom à 0-dps proxies) »

**Ce qui manque** : le plan P0.5 audite rang-2 (dilution de pool) mais **ne mentionne pas
explicitement les rang-5**. Or l'audit de l'audit de rang-5 révèle un problème distinct :

Cartographie des rang-5 (`units.lua:232-290`) :

| Unité | Famille principale | Niche déclarée | Problème |
|-------|--------------------|-----------------|----|
| ash_maw | burn | burnNoDecay équipe (T3 transform) | Proxy de `ash_maw` = pas de spread-on-death. Niche OK si non-dupliqué |
| plague_pyre | burn | burn → propagate à la mort | Niche distincte d'ash_maw — OK |
| slow_bleed | bleed | bleed équipe + slow accrue | Unique — OK |
| marrow_drinker | rot | convert_to_rot (op nouveau) | Transform pur — OK |
| festering | poison | poisonNoCap + igniteAt=5 | Pivot croisé poison→burn — OK |
| venom_censer | poison | +team bonus_first+poison | Effect inédit — OK |
| pit_maw | rot | rot sur équipe ennemie | Proxy d'un passif d'équipe, lisibilité faible |
| wither_bloom | rot | rot+bleed(0 dps)+poison(0 dps) | **3 ops à 0 dps** = effets de statut sans DPS propre, lisibilité faible |
| skull_colossus | burn (v7) | burn faible (dps=4) + tank (aggro=40, hp=92) | Profil tank-burn rang-5 : burn dps=4 < ash_maw rang-5. Redondance de *rang* ? |
| deep_kraken | poison (v7) | poison fort (dps=4) + très haute aggro | Profil carry-poison rang-5 : distinct mais dps modest |

**Le problème** : `skull_colossus` et `deep_kraken` (vague v7) sont des rang-5 qui semblent
être des stat-sticks améliorés (tank + effet simple) plutôt que des transforms. Or rang-5 =
coût = 5 = la décision la plus chère. Un rang-5 qui ne fait qu'appliquer burn/poison + avoir
de hauts stats est perçu comme « le même archétype en plus gros » — pas comme un
transform (décision §10 : rang-5 = transforms T3 / règles d'équipe).

**Source** : Slay the Spire GDC 2019 (gamedeveloper.com) — Giovannetti sur les cartes rares :
> « La première erreur est trop de cartes qui font la même chose avec des nombres différents. »
Ces 10 unités rang-5 dont 2 sont des stat-amplifications sans règle nouvelle violent ce principe.

**Proposition concrète** : l'audit P0.5 doit inclure une **ligne rang-5 dédiée** dans le tableau
pour identifier les rang-5 « stat-stick » (skull_colossus, deep_kraken) et décider : soit
leur ajouter une règle modifiée (transform), soit les rétrograder au rang-4 (coût-4) et libérer
2 slots rang-5 pour de vraies transforms. Coût = data/doc.

---

### 2.5 DÉSACCORD LÉGER — La vague v7 n'est pas traitée comme une cohorte cohérente dans le plan P0.5

**Ce que le brouillon dit** (P0.5 §3.1) :
> « Audit NICHE vs POOL — retirer du pool boutique les doublons sans niche distincte. »

**Ce qui est insuffisant** : la vague v7 (`units.lua:383-440`, commentaire « peuple les familles
visuelles restées visuel-only ») a été créée pour la **génération procédurale** (champ `family`
explicite pour `creaturegen.cached`), pas pour l'équilibre du pool boutique. Ces 14 unités ont
été ajoutées dans un contexte créatif (diversité visuelle) et se retrouvent dans U.pool par
défaut (U.pool = U.order). Leur logique de création est différente des vagues 1-4.

**Problème** : l'audit P0.5 traite chaque unité individuellement (grille 83 lignes). La vague v7
devrait être traitée comme une **décision de cohorte** : est-ce que ces 14 unités ont leur
place dans le pool boutique, ou sont-elles des unités de roster (pour encounters IA et galerie)
attendant d'être portées en pool boutique quand leurs niches sont affinées ?

**Preuve** : les vague v7 rang-2 (`chitin_drone`, `bore_worm`, `wailing_shade`, `pyre_herald`,
`byakhee`, `zeal_inquisitor`, `coil_viper`, `web_recluse`, `siphon_jelly`, `ink_horror` —
10 unités rang-2) ont toutes `effects[1].op` standard (poison/rot/bleed/burn/shock simple),
sans modificateur (pas de `refresh`, pas de `weaken`, pas de `slowScalesMissingHp`, etc.). Ce
sont des enablers purs sans axe de twist — le profil rang-1 ou early rang-2.

**Preuve de la décision existante** : `units.lua:487` documente explicitement « Identique au
roster pour l'instant. » — l'autheur savait que la séparation était à faire.

**Proposition concrète** : l'audit P0.5 doit traiter la vague v7 comme une **question de
cohorte** : « Parmi les 14 unités v7, lesquelles ont une niche suffisamment distincte pour le
pool boutique day-1 (v0.9) ? » Celles qui n'en ont pas → retrait de U.pool (reste dans U.order
pour encounters IA). Cette décision PRÉCÈDE le nettoyage ligne à ligne — c'est le filtre de
premier niveau.

---

## 3. Propositions priorisées

### P-A (URGENT, data/doc, 0 code) — Enrichir l'audit P0.5 avec double critère plafond/plancher

**Quoi** : la grille à 4 colonnes du brouillon devient une grille à **5 colonnes** :
1. Niche en ≤10 mots
2. Type de redondance (NICHE / POOL / Sain)
3. Remède (niche → différencier axe ; pool → retrait U.pool)
4. `dot_family` inférée
5. **[NOUVEAU] Budget stat : DPS base (dmg/cd) + HP dans la plage rang ? (Oui/Over/Under)**

Et une **règle de plancher** : ≥2 enablers/famille au rang-2 ET rang-3 pour que P(visible/boutique
T2) ≥ 40 % (calcul hypergéométrique, analogue au critère reliques §4.3). Rot rang-2 est OK (2
enablers sains), bleed rang-2 nécessite de ne pas descendre sous 2 après nettoyage.

**Coût** : calcul tableur, 0 ligne de code. **Délai** : inclus dans P0.5 sans décalage.

---

### P-B (AVANT P1, data) — Décision de cohorte pour la vague v7 : boutique ou roster-only ?

**Quoi** : avant de compléter l'audit ligne à ligne, **décider collectivement** des 14 unités
v7 : sont-elles `pool boutique day-1` (si niche distincte ET budget cohérent) ou `roster-only`
(encounters IA, galerie, snap future) ?

**Critère proposé** : une unité v7 reste dans U.pool si ET SEULEMENT SI :
(a) sa niche est NON-DUPLIQUÉE dans sa famille×rang (grille audit) ET
(b) son budget stat est dans la plage ≤ médian rang-N (colonne 5 de l'audit P-A).

**Estimation** : sur 10 unités v7 rang-2, il y en a probablement 4-6 à retirer du pool (les
doublons de niche dans burn/poison/bleed). Rot (bore_worm) et choc (siphon_jelly) sont candidats
au maintien (niches distinctes, non-dupliquées dans leur famille).

**Coût** : éditorial, 0 op, max 1 PR data.

---

### P-C (ENRICHISSEMENT litige #G) — Distinguer axe C-durée vs C-ponctuel et ajouter Config D au test

**Quoi** : le litige #G (axe choc) doit trancher non seulement A/B/C mais aussi, si C retenu,
**C-durée** (amplifie tous les hits sur N ticks, fidèle à PoE) vs **C-ponctuel** (1 hit
consommé, version brouillon). Et ajouter une **Config D** à la matrice de sim :
- Config D : choc pur (3 unités) + adversaire tank (gravewarden aggro=40 + shield_aura) + sigil
  carré, seed `20260623`, N=50. → Mesure : win% choc vs défense tank. **Si win% < moy−2σ →
  l'axe C ne résout pas le problème tank, l'analogie PoE ne transfère pas entièrement.**

**Pourquoi** : la PoE Shock amplifie **toute la durée**, pas 1 hit. Si on veut l'identité PoE
(amplificateur de coopération), il faut C-durée — mais C-durée touche aussi les DoT tick (burn,
bleed, poison ticks sont des hits en vue de la boucle de combat), ce qui peut créer un double-
comptage non prévu avec les caps. Config D mesure si le scénario adverse le plus résistant
(tank + shield) est gérable.

**Coût** : sim headless, ~1h, 0 invariant. Test d'axe = données pour décider, pas gravure.

---

### P-D (APRÈS P0.5, avant P1) — Audit rang-5 spécifique : stat-sticks vs transforms

**Quoi** : liste des 10 rang-5 avec décision : transform réelle (règle modifiée) / stat-amplification
(budget à raffiner) / à rétrograder rang-4. `skull_colossus` et `deep_kraken` (v7) sont les
candidats prioritaires à cette décision.

**Coût** : doc, 0 code. **Priorité** : après P0.5 audit complet, avant de coder les twists de
palier P1 (sinon les rang-5 pollueront les seuils de types).

---

## 4. Questions ouvertes

**Q1 — Plancher de représentation : combien de familles acceptent 1 seul enabler rang-2 ?**
La règle ≥2/famille/rang est une proposition ce round. Y a-t-il des familles où 1 enabler
rang-2 est **intentionnellement la rareté** (rot = rare et puissant dès rang-1) ? Si c'est
voulu, le plancher doit être documenté comme tel dans l'audit, pas comblé par réflexe.
→ Décision design, 0 code.

**Q2 — Les unités shield/tank (11 unités sans dot_family) : leur budget de puissance est-il
cohérent avec leur rôle ?** La question du 6e type (litige #F, orienté « aucun ») n'adresse
pas la cohérence de budget entre les 11 unités shield/tank. `runestone_golem` (rang-4, v7) a
hp=88, dmg=10, cd=80 → DPS base=0.125, HP=88 = profil carry mid-tier. Mais son effet est
`shield_aura` (value=12) — profil support. C'est une anomalie de budget : un support avec DPS
de carry. À vérifier dans l'audit.

**Q3 — `galvanizer` (rang-4, aggro=15) est la seule unité choc à auto-décharge.** Si l'axe
C (amplificateur) est retenu et remplace la décharge autonome, `galvanizer` perd son identité
unique (`bonus_first+shock` → charge+décharge en 1 unité). Son axe B (auto-décharge) devient
soit un sous-cas de C, soit une relique distincte. Question : l'axe C rend-il `galvanizer`
redondant ou complémentaire ? À préciser avant la décision #G.

**Q4 — Le ratio rang-2/rang-3 est-il équilibré après nettoyage ?** Après nettoyage pool
(≤4/famille/rang) : rang-2 ≈ 14-16 unités, rang-3 ≈ 18 unités (dont 4 auras). Rang-3 sera
plus dense que rang-2 en pool, ce qui est contra-intuitif (rang-3 devrait être moins fréquent
en boutique early). À vérifier via les cotes du brouillon (00-state §4.3) : les cotes T2 (70%
R1 / 30% R2) limitent déjà l'exposition rang-3 early — OK structurellement. Mais post-T3, la
densité rang-3 peut créer du bruit. À mesurer.

---

## 5. Synthèse pour le round suivant

Le brouillon v3 a correctement posé la structure de P0.5 (audit NICHE/POOL, `dot_family`,
reformulation test choc). Les 3 corrections prioritaires de ce round :

1. **Ajouter un PLANCHER à la règle ≤4/famille/rang** (§2.1) : ≥2 enablers/famille au rang-2
   pour que P(visible/boutique) ≥ 40 %. Sans plancher, le nettoyage crée des familles invisibles
   en early. Rot est OK mais doit être surveillé.

2. **Ajouter une colonne « cohérence budget stat » à l'audit P0.5** (§2.2) : le DPS de base
   (dmg/cd) doit décroître du rang-3 au rang-2 au rang-1. Plusieurs rang-2 (cinder_cur, zeal_inquisitor)
   dépassent le DPS de base de bellows_priest rang-3 — anomalie à qualifier (voulu = placeholder
   ou à corriger). Sans cet audit quantitatif, P0.5 ne peut pas garantir que cost=rank tient.

3. **Enrichir le litige #G avec la question C-durée vs C-ponctuel et une Config D** (§2.3) :
   l'analogie PoE Shock amplifie la durée (tous les hits pendant la durée), pas 1 hit. Le brouillon
   sous-spécifie l'axe C. Config D (adversaire tank+shield) teste le cas où l'amplification ne
   résout pas la résistance.

Ces trois corrections sont data/doc ou sim headless — 0 ligne de code moteur, 0 invariant.

---

## 6. Index des sources

**Internes (lecture seule du repo)** :
- `src/data/units.lua` (intégralité relue ce round — cartographie rang×famille×DPS calculée)
- `src/data/relics.lua` (reliques confirmées : 21, forked_tongue seul levier choc tier-4)
- `docs/roadmap-lab/00-state.md` (32 invariants, constantes, répartition roster)
- `docs/roadmap-lab/ROADMAP-draft.md` (v3, intégré round 2)
- `docs/roadmap-lab/round-01.md`, `round-02.md` (synthèses)
- `docs/roadmap-lab/rounds/r01-units-power.md`, `r02-units-power.md` (lentilles précédentes)
- `src/run/state.lua` (SHOP_SIZE=5, GOLD_PER_ROUND=10)

**Sources web vérifiées ce round** :
- [poewiki.net/wiki/Shock](https://www.poewiki.net/wiki/Shock) — PoE Shock =
  Non-Damaging Ailment, max +50 % increased damage taken, amplifie sur la **durée**
  (pas 1 hit), vérifié 2026-06. Fonde §2.3 (distinction C-durée vs C-ponctuel).
- [superautopets.fandom.com/wiki/Turtle_Pack](https://superautopets.fandom.com/wiki/Turtle_Pack)
  — Turtle Pack = 60 pets sur 6 tiers = ~10/tier (confirmation du benchmark SAP).
  Fonde §1.1 (calcul de visibilité P(famille/boutique)).
- [superautopets.wiki.gg/wiki/Pets](https://superautopets.wiki.gg/wiki/Pets) — pool pets
  par tier et odds d'apparition par slot.
- [gamedeveloper.com — Giovannetti GDC 2019](https://www.gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder)
  — StS : « la 1re erreur = trop de cartes qui font la même chose avec des chiffres différents ».
  Fonde §2.4 (rang-5 stat-sticks).
- [askghostcrawler.tumblr.com — GhostCrawler power budget, 2017](https://www.tumblr.com/askghostcrawler/162636873978/)
  — budget de puissance : sharp strengths/weaknesses > 40 pts partout. Fonde §2.2 (budget rang).
- [esportstales.com — TFT pool sizes Set 17](https://www.esportstales.com/teamfight-tactics/champion-pool-size-and-draw-chances)
  — pool TFT : 1-cost=30, 2-cost=25, 3-cost=20, 4-cost=12, 5-cost=10 copies par champion.
  Fonde §1.1 (comparaison avec ratio The Pit).

**Compétitifs lus ce round** : `competitive/super-auto-pets.md`, `competitive/tft.md`,
`competitive/slay-the-spire.md`, `competitive/postmortems.md`, `competitive/backpack-battles.md`.

---

*Round 03 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu
(`units.lua` intégralité + `relics.lua`). N'édite que sous `docs/roadmap-lab/`.
Piliers respectés (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural).
32 invariants non touchés. 0 modification du code du jeu.*
