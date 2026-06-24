# The Pit — Plan d'implémentation des Commandants (LIVE + UI)

> **Statut** : PLAN D'IMPLÉMENTATION autoritaire (document de DESIGN — **zéro code Lua ici**).
> L'user a tranché : **implémentation LIVE complète + UI** (pas juste du design). Ce doc spécifie
> chaque étape jusqu'à des descripteurs data chiffrés, le mapping moteur exact (fichier/fonction),
> et l'ordre de livraison par vagues vertes.
>
> **Sources lues ligne-à-ligne (2026-06-25)** :
> - `docs/research/effects-overhaul-spec.md` §6 (mécanique finale), §6.2.1 (résolution des rôles),
>   §6.4 (changements moteur), §2.6 (champs increased combat-time), §12 Q-snapshot.
> - `docs/research/commanders-and-effect-diversity-brainstorm.md` (genèse, forks A/B/C, §9 portée×puissance,
>   §10 catalogue, §13 ce que la recherche change).
> - `docs/base-game/creature-identity-map.md` (les VISUELS canon — quel monstre a une tête de chef).
> - `docs/research/effects-content-plan.md` §3 (rôles de commandant réservés par archétype : Tambour/Calice/
>   Aïeul/Roi-des-Rats/Couronne/Bris-Siège) + `docs/research/relics-overhaul-plan.md` (§2.0 = le MÊME point dur
>   d'injection, interactions commandant×relique §4).
> - **Code** : `src/combat/arena.lua` (K4 **déjà câblé** : isCommander/untargetable/cdMult/damage=0/décompte
>   filtré/chooseTarget aux 2 endroits + `statInc` baké mais NON LU), `src/scenes/build.lua`
>   (`buildComp` : handler `aura_stat` K1 résout déjà `team/role:*/tier:N/level:N`, bake `statInc`),
>   `src/net/snapshot.lua` (capture/toComp — **ne capture PAS le commandant** = dette), `src/run/state.lua`
>   (capacité de slots = grants timés), `src/data/units.lua` (data pure, pas de champ commander).
>
> **Boussole (CLAUDE.md)** : faisable solo-dev Lua/LÖVE, **déterministe / async-vérifiable / golden-safe**
> (nil = inerte), **l'arène reste SIM-autonome** (l'aura est build-résolue, l'arène ne connaît jamais le
> plateau). Tous les chiffres = **PLACEHOLDERS** à tuner via `tools/sim.lua`. **JUICY** (game feel : piédestal
> distinct + survol qui éclaire la portée + barre de cadence).

---

## 0. Ce qui est DÉJÀ fait (constat de code, pour ne rien réimplémenter)

Le keystone **K4 (slot commandant) est câblé et gated** dans `arena.lua` — VÉRIFIÉ :

| Élément K4 | État | Preuve (arena.lua) |
|---|---|---|
| `isCommander` / `untargetable` posés à `nil` dans makeUnit | ✅ | l.147-148 |
| `chooseTarget` exclut `isCommander` **dans minDepth ET dans la sélection** (§6.4.1) | ✅ | l.211, 217, 222 |
| `damage()` retourne 0 pour un commandant (intouchable, AVANT mutation) | ✅ | l.271 |
| `cdMult` câblé au timer (`* (u.cdMult or 1)`, nil→1) | ✅ | l.670 |
| Décompte de victoire **exclut** `isCommander` (board mort = défaite) | ✅ | l.764 |
| Fatigue frappe les commandants à damage=0 → terminaison OK | ✅ | l.703-718 + l.271 |
| Handler `aura_stat` (K1) résout `team / role:front|back|center / tier:N / level:N` | ✅ | build.lua l.984-1000, tie-break = chooseTarget l.927-944 |
| `aura_stat` bake `statInc` au comp + `makeUnit` le stocke (`spec.statInc`) | ✅ | build.lua l.967-968, 1025 ; arena.lua l.150 |

**Conséquence** : la mécanique de combat du commandant est **déjà 100% jouable** dès qu'une unité porte
`isCommander=true` + `cdMult` + un effet `aura_stat`. Le travail restant est **(1) un trou moteur précis**,
**(2) de la data**, **(3) le slot/piédestal côté scène**, **(4) l'UI**, **(5) le snapshot**.

---

## 1. CÂBLAGE `statInc` — le SEUL prérequis moteur (corrige la dette « baké mais pas lu »)

### 1.1 Le diagnostic exact (pourquoi L'Aïeul et le Roi des Rats sont inertes aujourd'hui)

`statInc` est **baké** par `aura_stat` (build.lua:967-968, 1025) et **stocké** dans `makeUnit`
(arena.lua:150), mais **AUCUN consommateur ne le lit**. Le piège est le même que `relics-overhaul-plan.md`
§2.0 :

- `hp` et `dmg` d'un spec sont **calculés au BUILD** dans `buildComp` (build.lua:1019) :
  `hp = floor(u.hp * m + 0.5)`, `dmg = floor(u.dmg * m + 0.5)` où `m = LEVEL_MULT[level]`.
- Le handler `aura_stat` qui résout `statInc` tourne **APRÈS** ce calcul (build.lua:976-1009, le bake hp/dmg
  est l.1011-1031). Donc `statInc` arrive **trop tard** pour modifier `hp`/`dmg` dans la même passe.
- En combat, `arena.lua` lit `spec.dmg`/`spec.hp` **directement** (l.119) et **ne ré-applique jamais**
  `statInc`. Contraste avec `atkInc` (empower) qui **fonctionne** car il est lu *en combat* dans `hit()`
  (l.358-360, `Stats.resolve(ctx.amount, {increased=atkInc})`). `statInc` n'a pas d'équivalent.

### 1.2 Définition précise de `statInc`

`statInc` = un buff **`increased` (additif, sur la base)** appliqué aux stats **`hp` ET `dmg`** d'une
unité ciblée (les deux stats « globales » au sens des commandants conditionnels : « +40 % stats »,
« +50 % PV & dmg »). **Choix gravé** :

- **Stats touchées** : `hp` (et `maxHp`/`maxHp0` qui en dérivent) **+** `dmg`. **PAS** `cd` (la cadence
  est l'axe de `haste`/`cdMult`, ne pas la coupler), **PAS** les valeurs de DoT (les afflictions ont déjà
  leurs propres `*Inc` d'aura ; `statInc` est le buff *brut* « cette unité est plus grosse et frappe plus
  fort », pas un ampli d'affliction).
- **Formule** : `Stats.resolve(base, {Stats.increased(statInc)})` = `base * (1 + statInc)` — strictement la
  même couche que `atkInc`/`vulnInc` (additif, sans tri, déterministe). `statInc` cumulé est **cappé**
  (cf. §1.4).
- **nil = inerte** (golden-safe) : aucune unité golden ne porte `statInc` → empreinte inchangée.

### 1.3 OÙ l'appliquer — décision : **BAKÉ AU BUILD** (pas lu en combat)

Deux options ; on tranche pour **(A) baké au build**, cohérent avec hp/dmg déjà bakés :

- **(A) BAKÉ AU BUILD ✅** — dans `build.lua:buildComp`, **après** que `statBuf` est rempli (l.1009) et **au
  moment** du bake du comp (l.1018-1019), appliquer `statInc` directement à `hp`/`dmg`/`maxHp` du spec :
  ```
  -- dans la boucle de bake du comp (build.lua ~l.1016-1019), après m = LEVEL_MULT[level] :
  local si = (statBuf[p.slot] and statBuf[p.slot].statInc) or 0   -- commandant : +% stats globales (cappé)
  local hpv  = math.floor(u.hp  * m * (1 + math.min(STAT_INC_CAP, si)) + 0.5)
  local dmgv = math.floor(u.dmg * m * (1 + math.min(STAT_INC_CAP, si)) + 0.5)
  -- ... puis hp = hpv, dmg = dmgv dans le comp[#comp+1] = {…}
  ```
  Et on **retire** `statInc = sb and sb.statInc` du comp (l.1025) : il n'a plus besoin de transiter vers
  l'arène, il est déjà absorbé dans `hp`/`dmg`. **Avantage** : zéro changement dans `arena.lua` (firewall
  intact), déterministe par construction (build-résolu, comme les duplicatas), pas de double-lecture.

  > **Détail HP_MULT** : `makeUnit` re-scale `hp` par `self.hpMult` (arena.lua:115) — c'est cumulatif et
  > **correct** (le bouton global de durée s'applique après le buff de commandant, comme pour toute unité).

- **(B) lu en combat** — poser `spec.statInc` et faire `arena.lua` recalculer `dmg`/`maxHp` à `makeUnit`.
  **Rejeté** : touche le firewall SIM, complique `maxHp0` (plancher de nécrose rot), et duplique la logique
  de scaling déjà présente au build. (B) n'apporte rien sur le solo (l'aura est build-statique de toute façon).

**Mapping exact** : `src/scenes/build.lua`, fonction `Build:buildComp`, **boucle de bake du comp**
(l.1011-1031). C'est le SEUL fichier touché. `statBuf[slot].statInc` est déjà rempli par le handler
`aura_stat` (l.967, 1004-1005) → il suffit de le **consommer** au bake au lieu de le faire transiter inerte.

### 1.4 Caps + déterminisme + golden-safe

- **Cap** : ajouter une constante `STAT_INC_CAP = 1.0` (placeholder, +100 % max cumulé) dans `build.lua`,
  appliquée au moment du bake (`math.min(STAT_INC_CAP, si)`). Aligne sur la philosophie `ATK_INC_CAP=1.5` /
  `VULN_INC_CAP=0.5` (cap par-axe à la lecture). Comme `statInc` touche **hp ET dmg**, on le garde plus
  serré (un commandant level:1 + un commandant tier:1 ne s'empilent pas en pratique — 1 seul slot — mais le
  cap protège contre un futur double-source ou une relique).
- **Déterminisme** : `increased` additif, build-résolu → aucune RNG, aucun ordre de tri. Reproductible.
- **Golden-safe** : `si = 0` quand aucun `aura_stat statInc` n'est présent → `hp/dmg` inchangés → empreinte
  golden **inchangée**. Aucune unité du scénario golden ne porte de commandant.
- **`multicast`/`focusWith` non concernés** : ce câblage ne touche QUE `statInc`. Les autres stats d'aura
  (`haste`/`atkInc`/`dmgReduce`/`regen`/`lifesteal`/`multicast`) sont **déjà lues** en combat ou bakées.

### 1.5 Test (à ajouter dans `tests/auras.lua`)

- Poser un commandant `aura_stat {statInc, target=level:1, value=0.40}` + 1 unité level 1 + 1 unité level 2
  → l'unité **level 1** voit `hp`/`dmg` × 1.40 (cappé) dans le comp ; l'unité **level 2** est **inchangée**.
- Idem `target=tier:1` (le Roi des Rats) : seules les unités `rank==1` du comp sont buffées.
- Cap : `statInc` > `STAT_INC_CAP` est tronqué.
- Golden : re-run `tools/check.sh` → golden inchangé (aucune unité golden n'a de commandant).

---

## 2. ROSTER de 6 commandants (ancrés sur un VISUEL canon de chef)

> **Méthode** : chaque commandant = **une unité existante** dont le RENDERS-AS canon
> (`creature-identity-map.md`) est crédible en CHEF (robés/rois/prêtres/hiérophantes/tyrans/léviathans).
> On ajoute à cette unité un **`commandBonus`** (= son aura quand elle commande) — un champ data, exactement
> l'idée fondatrice (« chaque créature porte son bonus de commandement »). Le **budget portée × puissance**
> (spec §6.2) gouverne : team → faible · tier/level (conditionnel) → moyen-fort · role:single → très fort.
> Tous les chiffres = PLACEHOLDERS (§6).

### 2.1 Forme data : le champ `commandBonus`

Chaque unité **éligible commandant** gagne dans `src/data/units.lua` un champ :
```
commandBonus = { trigger = "combat_start", op = "aura_stat", target = <portée>, params = { stat = <stat>, value = <v> } }
```
(même grammaire que `effects`, donc résolu par le handler `aura_stat` **déjà câblé**). Le slot piédestal
(§3) injecte ce descripteur dans la liste d'effets de l'unité **uniquement quand elle est au piédestal** +
pose `isCommander=true`, `untargetable=true`, `cdMult=COMMANDER_CD_MULT`. Hors piédestal, `commandBonus`
est **ignoré** (l'unité combat normalement avec ses `effects` de board).

> **Pourquoi un champ séparé** (`commandBonus`) et pas dans `effects` : sur le board, l'unité garde son kit
> de board (poison, etc.) ; au piédestal, on **ajoute** son aura de commandement (et on ralentit sa cadence).
> Découple les deux identités (troupier ≠ leader, le vrai moteur de profondeur — brainstorm §8.2).

### 2.2 Les 6 commandants (un par groupe, spec §6.3 + content-plan §3, ancrés visuel)

| # | Commandant (unité-hôte) | Visuel canon (chef crédible) | `commandBonus` (portée → puissance) | Mapping | Flavor grimdark canon |
|---|---|---|---|---|---|
| **1** | **Le Tambour de Guerre** = `bellows_priest` | cultiste robé encapuchonné (RENDERS cultist) — le *soufflet* qui donne le rythme | équipe `+8 %` cadence | `aura_stat {stat=haste, target=team, value=0.08}` (lu en combat l.670) | *« Il bat la peau d'un noyé ; sous la cadence, toute la fosse frappe au même souffle. »* |
| **2** | **Le Calice de Sang** = `demon` | anglerfish à fanal (LANTERN-GULLET) — l'appât qui nourrit la meute | équipe `+5 %` vol de vie | `aura_stat {stat=lifesteal, target=team, value=0.05}` (lu dans hit l.377-380) | *« Le fanal promet de la lumière ; ce qu'il rend, c'est ta vie, goutte à goutte, à ceux qui suivent. »* |
| **3** | **L'Aïeul** *(conditionnel level-1)* = `deep_kraken` | léviathan à tentacules+bec — l'ancien des profondeurs | unités **niveau 1** : `+40 %` stats (hp+dmg) | `aura_stat {stat=statInc, target=level:1, value=0.40}` (**§1, baké**) | *« Il est descendu avant les noms. Ce qui n'a jamais grandi sous sa coupe — tes plus grandes choses — enfle d'un coup. »* |
| **4** | **Le Roi des Rats** *(conditionnel tier-1)* = `galvanizer` | nœud de 6 rats à couronne (THE KNOTTED SIX, RENDERS ratking) | unités **tier-1** (`rank==1`) : `+50 %` PV & dmg | `aura_stat {stat=statInc, target=tier:1, value=0.50}` (**§1, baké**) | *« Six gueules, une couronne. La piétaille qu'on jette dans la fosse devient, sous lui, une marée. »* |
| **5** | **La Couronne d'Échos** *(mono-cible fort)* = `maggot_king` | pantin-roi pendu à des fils (THE STRUNG TYRANT, marionette) | la plus **avancée** (role:front) : `+1` multicast | `aura_stat {stat=multicast, target=role:front, value=1}` (entier, K3, cap MULTICAST_MAX=3) | *« Le tyran de bois rejoue chaque coup porté. Devant lui, l'élu frappe deux fois — et ne le sait pas. »* |
| **6** | **La Bannière du Bris-Siège** *(anti-méta)* = `siege_breaker` | loup gris dressé à trouver la couture du mur (WALLBITER) | combat_start : boucliers ennemis `÷2` | `grant_team {stripEnemyShield}` (NOUVEAU drapeau, §2.3) | *« Le mur croit tenir. Sa bannière dit non, et la garde dorée s'écaille avant le premier choc. »* |

**Tous les hôtes sont des unités déjà au roster**, à RENDERS-AS de chef vérifié dans l'identity-map :
`bellows_priest` (cultist robé), `demon` (anglerfish-fanal), `deep_kraken` (léviathan), `galvanizer`
(ratking couronné), `maggot_king` (marionette-tyran), `siege_breaker` (loup wallbiter). Aucun nouveau sprite.

### 2.3 Le seul nouvel op : `stripEnemyShield` (commandant #6)

Les commandants 1-5 utilisent des stats **déjà câblées** (haste/lifesteal/statInc/multicast). Le #6 exige un
**drapeau d'équipe** qui divise par 2 les boucliers ennemis au `combat_start`. Mapping :
- **`grant_team {stripEnemyShield=0.5}`** posé dans `teamFlags[commander.team]` (build-résolu, comme les
  autres `grant_team`, ré-exécuté par l'arène l.180). À `combat_start`, après le spawn, une passe :
  `for each enemy u: u.shield = floor(u.shield * (1 - stripEnemyShield)); u.maxShield idem`.
- **Faisabilité** : `grant_team` existe (`ops.lua`), `teamFlags` existe (arena.lua:169). Il faut **1 bloc de
  ~6 lignes** dans `arena.lua:spawn` (après le combat_start, avant le set des boucliers périodiques l.183) :
  lire `teamFlags[opposing].stripEnemyShield` et l'appliquer aux boucliers initiaux ennemis. Gated
  (nil = inerte → golden-safe). **C'est le seul ajout au firewall SIM** pour les commandants, et il est
  trivial + déterministe.
  > Alternative plus simple si on veut **zéro nouvel op SIM** pour la v1 : remplacer le #6 par un
  > `aura_stat {dmgReduce, target=team, value=0.10}` (« Le Maréchal » — équipe encaisse 10 %). Mais
  > `stripEnemyShield` est le rôle anti-méta réservé (content-plan §3 / brainstorm §10-D) et n'a aucun autre
  > foyer → **le garder**, c'est 6 lignes gated.

### 2.4 Extension du pool (post-v1, signalé non bloquant)

Le brainstorm §10 liste 16 commandants. La v1 = ces **6** (1 par groupe : team-faible ×2, conditionnel ×2,
mono-fort ×1, anti-méta ×1). Étendre = **pure data** (1 `commandBonus` par unité) une fois la boucle validée
en sim. Cibles évidentes (visuels de chef restants) : `ash_maw` (robé couronné → burnNoDecay team =
« Prophète de Cendres »), `oath_keeper` (paladin halo → gros bouclier team), `festering` (poisonNoCap team),
`templar` (roue d'yeux → armure team). **Pas en v1** (1 levier à la fois pour la sim).

---

## 3. SLOT / PIÉDESTAL (intégration, déblocage, condition de défaite)

### 3.1 Le piédestal = un slot HORS GRAPHE de sigil

- **Lisibilité « pas d'adjacence »** : le piédestal est un **emplacement distinct** dessiné à part du
  plateau-graphe 3×3 (un socle/trône sous ou à côté du board), pas une case du graphe. L'unité qui s'y
  trouve **n'a aucun voisin** (elle ne reçoit ni ne donne d'aura d'adjacence) — c'est le trade-off
  fondateur (brainstorm §8.2).
- **Modèle data** : le piédestal est **1 slot logique séparé** dans `Build` (ex. `self.commanderSlot = nil`
  ou un slot d'id réservé hors `board.slots`). Il n'entre PAS dans `board:neighbors`/`board.shape` → l'aura
  build-résolue voit le commandant comme **caster** mais sa cible (`team`/`role:*`/`tier:*`/`level:*`) se
  résout sur le **board** (les unités placées), **jamais** sur lui-même. Le commandant est **exclu** des
  cibles de sa propre aura (il commande, il ne se buffe pas — sauf team-wide trivialement sans effet sur lui
  puisqu'il est intouchable/cosmétique).

### 3.2 Comment l'aura du commandant entre dans `buildComp`

`buildComp` itère `placed` (les unités du board) pour résoudre les auras. **Ajout** : avant cette boucle,
si `self.commanderSlot` est rempli, **injecter** le commandant comme une source d'aura spéciale :
- résoudre son `commandBonus` (descripteur `aura_stat`) sur les **cibles du board** via la même logique
  `resolveRole`/`tier:`/`level:`/`team`/`neighbors` (mais `neighbors` → vide, le commandant n'a pas de
  voisins ; `team` → tout le board ; rôles → résolus sur le board).
- le commandant lui-même est ajouté au `comp` final avec `isCommander=true`, `untargetable=true`,
  `cdMult=COMMANDER_CD_MULT`, ses **effects de board conservés** (kit complet, voie A), une position de
  rendu = le piédestal (hors grille, ex. `depth`/`row` cosmétiques ou un x/y fixe). Il **garde son `dmg`/`cd`**
  (il attaque, voie A) mais sa cadence est ralentie par `cdMult`.

> **Mapping exact** : `src/scenes/build.lua:buildComp`. Une **fonction helper** `resolveCommanderAura(placed,
> b)` qui réutilise `resolveRole`/`byCell`/`addStat` (déjà locaux) en passant le `commandBonus` du
> commandant. Le commandant est `table.insert` dans `comp` à la fin (sa propre aura ne le cible jamais).
> **Zéro couplage arène** : tout est build-résolu, l'arène reçoit un spec `isCommander` ordinaire.

### 3.3 Déblocage opt-in en cours de run (comme les slots)

- **Réutiliser le système de grants de slots** (`run/state.lua` : `pendingSlotGrant`/`acceptSlotGrant`).
  Ajouter un **grant de piédestal** distinct : `pendingCommanderGrant` (bool) + `commanderUnlocked` (bool),
  offert **une fois** à un jalon de run (ex. à la 2e ou 3e victoire — placeholder, à aligner sur la cadence
  des slots). Accepter = `commanderUnlocked = true` (le piédestal apparaît, vide). Refuser =
  `+SLOT_DECLINE_GOLD` or, piédestal jamais débloqué cette run (jeu sans commandant viable — SAP prouve
  qu'un autobattler tient sans héros, brainstork §13.4).
- **Drag-drop** : une fois débloqué, glisser une unité **du board OU du bench vers le piédestal** la promeut
  commandant (elle quitte sa case, le piédestal l'affiche). Glisser le commandant **hors du piédestal** le
  rétrograde (retour au bench/board). **Une seule unité** au piédestal. Réutiliser le système drag-drop
  existant de `build.lua` (le piédestal = une drop-zone supplémentaire).

### 3.4 Condition de défaite + invuln (déjà câblées, à ne pas re-faire)

- **Board mort = défaite même si le commandant vit** : le décompte de victoire **exclut déjà**
  `isCommander` (arena.lua:764). ✅ Le commandant seul ne gagne rien.
- **Invuln/untargetable** : `damage()` retourne 0 (l.271), `chooseTarget` l'exclut (l.211/217/222). ✅
- **Reçoit les buffs team-wide de SA team** (grant_team), pas les afflictions ennemies (intouchable). ✅
- **Fatigue** : le frappe à damage=0, ne le tue pas, mais le board meurt → terminaison garantie (l.703-718).
  À **tester** (props.lua, commandant des 2 côtés, §6).

---

## 4. UI (spec pour ui-artisan)

> Réf DA : kit `.dc.html` re-câblé, plein écran sans cadre carvé, fiche au survol (mémoire UI). Réutiliser
> `src/ui/feel.lua` (juice), `src/ui/eye.lua` (si un œil de commandement), les chips/keywords existants.

### 4.1 Le piédestal (rendu distinct)

- **Un socle/trône** visuellement séparé du plateau (pierre carvée + or terni, DA forge ARPG), placé sous ou
  à gauche du board 3×3. État **vide** = socle creux avec un appel à l'action discret (« couronne une bête »).
  État **rempli** = l'unité-commandant rendue sur le socle, **plus grande / surélevée** (lift), avec un liseré
  doré et **aucun surlignage d'arête** (la lisibilité « pas d'adjacence » est portée par l'absence de lignes
  vers le board).
- **Au survol du piédestal** → **éclairer les unités du board affectées par l'aura** (la portée VISIBLE,
  règle gravée brainstorm §13.3 / spec §6.4.7) : `team` = tout le board pulse ; `level:1` = seules les unités
  level-1 s'illuminent ; `role:front` = la seule unité avant brille. Réutiliser le surlignage de voisins
  existant (`build.lua` surligne déjà les voisins d'aura). Afficher une **étiquette de portée** (« COMMANDE :
  niveau 1 », « COMMANDE : toute la meute », « COMMANDE : l'avant-garde »).

### 4.2 Barre de cadence lente

- Le commandant frappe à `cd * cdMult` (lent, voie A). Afficher une **barre de cadence dédiée** sous le
  piédestal, **lisiblement plus lente** que celle des troupiers (rythme visuel = « il dirige, il ne se bat
  pas comme un troufion », brainstorm §9.2). Optionnel : un battement (le Tambour) synchronisé sur le tick.

### 4.3 « Bonus de commandement » de l'unité survolée (chaque unité porte le sien)

- **Sur la fiche au survol de n'importe quelle unité** (board, bench, boutique), afficher une ligne
  **« Au commandement : <effet de son `commandBonus`> »** (avec le chiffre, lisible — pas de %, valeur
  concrète quand possible, cf. feedback `concrete-values-over-percentages`). Ex. survol de `galvanizer` →
  « Au commandement : tes unités rang-1 ont +50 % PV & dégâts ». Ça **enseigne** le système (l'instinct
  « promeus ta carry » se corrige en lisant que sa carry forte a un `commandBonus` médiocre).
- Si l'unité n'a **pas** de `commandBonus` (toutes ne sont pas chefs en v1, §2.4), afficher « Ne peut pas
  commander » (grisé) — honnête et cohérent avec le sous-set curé (fork F4).

### 4.4 Drag-drop feedback

- Glisser vers le piédestal : le socle **s'illumine** comme drop-zone valide (feel : glow + squash à la
  pose). Une unité non-chef glissée au piédestal = **refus visuel** (shake + retour), pas un crash.

---

## 5. SNAPSHOT (ce qu'il faut encoder ; v1 = solo, dette signalée)

### 5.1 État actuel (dette)

`snapshot.lua` encode `{ version, tier, seed, shape, units=[{id,level,col,row}] }` et `toComp` reconstruit
**uniquement** les unités du board (l.54-73). Il **ne capture ni le commandant ni son aura** → un ghost
servi rejouerait un build **sans son commandant** (build plus faible = divergence async).

### 5.2 Ce qu'il faut encoder (schéma étendu, pour le multi)

- Ajouter un champ **`commander = { id, level }`** au modèle snapshot (`capture`), encodé comme un segment
  supplémentaire dans `encode` (ex. un champ après `shape`), décodé dans `decode`, réinjecté dans `toComp` :
  reconstruire le spec commandant (`isCommander=true`, `untargetable=true`, `cdMult`, `commandBonus`
  résolu sur le board reconstruit via la **même logique de rôle/tier/level** que `buildComp`).
- **Point dur** (= le même que synergie-famille spec §2.5.1 et reliques §Q1) : `toComp` reconstruit les
  stats depuis `Units[id]` + level-mult, **sans** l'aura. Pour qu'un ghost rejoue correctement, `toComp`
  doit **ré-exécuter la résolution d'aura du commandant** sur le board reconstruit (réutiliser la helper
  `resolveCommanderAura` de §3.2, extraite dans un module partagé PUR si nécessaire — `snapshot.lua` est PUR,
  il peut require une logique de résolution de rôle pure).

### 5.3 Décision v1 : **solo seulement, ghost sans commandant** (non bloquant)

Aligné spec §12 Q-snapshot + relics §Q1 : **en v1, le commandant est un effet LOCAL (build courant/solo)**.
Le ghost rejoue ses unités **sans** son commandant (légèrement plus faible, acceptable). Activer la capture
commandant (§5.2) **avant** d'ouvrir les commandants au multi async (= step K-snapshot de la spec §8.3,
qui encode aussi `statBonus` synergie-famille + murmures). **Signalé non-bloquant pour le solo.**

---

## 6. ÉQUILIBRAGE (budget portée×puissance chiffré + combos à border)

### 6.1 Budget portée × puissance (placeholders, à tuner via `tools/sim.lua` §9.2)

| Portée | Puissance autorisée | Commandant | Valeur placeholder |
|---|---|---|---|
| **Équipe** | faible | Tambour (haste team) | `+0.08` |
| **Équipe** | faible | Calice (lifesteal team) | `+0.05` |
| **Conditionnel** (level/tier) | moyen-fort | Aïeul (statInc level:1) | `+0.40` |
| **Conditionnel** (level/tier) | moyen-fort | Roi des Rats (statInc tier:1) | `+0.50` |
| **Mono-cible** (role:front) | très fort | Couronne d'Échos (multicast) | `+1` (entier) |
| **Anti-méta** (combat_start) | situationnel | Bris-Siège (stripEnemyShield) | `÷2` |

**Caps moteur (garde-fous vérifiés)** : `STAT_INC_CAP=1.0` (NOUVEAU, §1.4), `MULTICAST_MAX=3`,
`ATK_INC_CAP=1.5`, `VULN_INC_CAP=0.5`, `HIT_DMG_CAP_MULT=7`. Le `cdMult` commandant = `COMMANDER_CD_MULT`
placeholder **`1.5`** (borne `[1.0, 2.5]`, spec §2.1) — nerf uniforme du corps (voie A : le nerf touche
proportionnellement dégâts bruts ET applications de DoT, brainstorm §9.2).

### 6.2 Commandant × commandant (terminaison)

Déjà couvert par K4 + la fatigue (arena.lua). **Test obligatoire** `tests/props.lua` : fuzz avec un
commandant **des deux côtés** → terminaison garantie (board meurt + fatigue conclut, le commandant
intouchable ne bloque jamais). Spec §6.4.4.

### 6.3 Commandant × relique (combos à surveiller — interactions anticipées)

> Réf `relics-overhaul-plan.md` §4 (mêmes caps). Les commandants et les reliques **partagent les champs**
> (atkInc/multicast/lifesteal/dmgReduce) → ils s'**empilent**, bornés par les caps. À balayer en sim.

| Combo | Risque | Garde-fou | Test |
|---|---|---|---|
| **Couronne d'Échos** (cmd, multicast role:front) × **`echo_crown`** (relique, multicast role:front) × **`hookjaw`** (unité, multicast role:front) | 3 sources multicast sur le carry avant | `MULTICAST_MAX=3` cappe la somme (1+1+1=3 ≤ 3) ; `HIT_DMG_CAP_MULT=7` borne chaque sous-coup | **PRIORITÉ #1** : `relicsim`/`sim` Couronne+echo_crown+hookjaw vs poison-tank ; lift < 1,6, TTK p10 stable |
| **Tambour** (haste team) × **`whetstone`** (relique haste team) | double haste → cadence plancher | plancher `cd*(1+atkSlow)` non franchi ; haste cumulé surveillé (cap conseillé `haste≤0.40` à la lecture) | `sim` : vérifier que la cadence ne devient pas dégénérée (TTK p10) |
| **L'Aïeul** (statInc level:1) × **late-game** | en endgame les top-tier sont quasi jamais niveau 2 → l'Aïeul ne buffe QUE les plus gros monstres, tard | **voulu** (profondeur non-évidente, brainstorm §9.1) ; cappé `STAT_INC_CAP=1.0` | `runsim` bande END : win% ≤ +2σ |
| **Couronne** × **`corruptor`/`miasma_acolyte`** (le pire snowball, spec §6.4 F11) | +1 multicast double la pose de stacks ET de weaken, l'aura voisine amplifie | caps `POISON_STACK_CAP=8`, `WEAKEN_CAP=0.40`, `MULTICAST_MAX=3` tiennent | **à simuler AVANT déploiement** (§9.1 spec) |
| **Calice** (lifesteal team) × **`bait_lantern`** (relique lifesteal team) | double lifesteal → sustain ingérable | lifesteal cumulé borné ; rot/pierceHeal contrent | `relicsim` bande MID/END |

### 6.4 Métrique : un bon commandant **multiplie le board**

Le seuil n'est PAS « le commandant est-il fort perso » mais **« son aura multiplie-t-elle le board »**
(brainstorm §8.2). Métriques `sim.lua` :
- **win% contextualisé par investissement** : un commandant viable si win% ≥ 50 % à coût comparable (spec §9.3).
- **présence côté gagnant** : aucun commandant ne dévie de `>2σ` (drapeau outlier `sim.lua`).
- **lift de co-occurrence** < 1,6 sur chaque paire commandant×(relique/unité-ampli) (détecteur de combo cassé).
- **diversité** : entropie des archétypes gagnants ≥ 0,90 (la sim sort ~0,99). Si un commandant *force* un
  archétype (méta forcée, leçon TFT Legends) → nerf de portée, jamais buff de garantie d'accès.

---

## 7. ORDRE D'IMPLÉMENTATION (vagues vertes)

> Convention git-warden : brancher chaque vague depuis `dev`, commit quand `tools/check.sh` vert.
> **Golden-neutralité** indiquée par vague (aucune unité golden ne porte de commandant → la plupart sont neutres).

| Vague | Contenu | Fichiers | Golden | Dépend |
|---|---|---|---|---|
| **C0 — `statInc` câblé (moteur, gated)** | Consommer `statBuf[slot].statInc` au bake du comp (hp+dmg × (1+statInc) cappé `STAT_INC_CAP`) ; retirer le `statInc` inerte du comp ; test `tests/auras.lua` (level:1 / tier:1 / cap). | `src/scenes/build.lua` | **inchangé** (gated : aucune unité golden n'a `aura_stat statInc`) | — |
| **C1 — `stripEnemyShield` (moteur, gated)** | 1 bloc dans `arena.lua:spawn` lisant `teamFlags[enemy].stripEnemyShield` → boucliers ennemis ÷2 ; gated. | `src/combat/arena.lua`, `src/effects/ops.lua` (grant_team flag) | **inchangé** (gated) | — |
| **C2 — data des 6 commandants** | `commandBonus` sur bellows_priest/demon/deep_kraken/galvanizer/maggot_king/siege_breaker + i18n (noms/flavor canon §2.2) ; `tests/relics.lua`-style smoke des 6 auras. | `src/data/units.lua`, `src/i18n/en.lua` | **inchangé** (data hors golden ; `commandBonus` n'est lu que si l'unité est au piédestal) | C0, C1 |
| **C3 — slot/piédestal + drag-drop + run grant** | `commanderSlot` dans `Build` ; `resolveCommanderAura` dans `buildComp` (injecte l'aura sur le board, ajoute le commandant au comp avec isCommander/cdMult) ; drop-zone piédestal ; `pendingCommanderGrant`/`commanderUnlocked` dans `run/state.lua` (grant à un jalon). | `src/scenes/build.lua`, `src/run/state.lua`, `src/board/board.lua` (si slot hors-graphe) | **inchangé** (pas de commandant dans le scénario golden) | C0-C2 |
| **C4 — UI (ui-artisan)** | Rendu piédestal distinct + lift/liseré ; survol = portée éclairée + étiquette ; barre de cadence lente ; ligne « Au commandement » sur la fiche de chaque unité ; feedback drag-drop. | render UI + `src/ui/feel.lua` | — (render) | C3 |
| **C5 — snapshot (multi, différé)** | Champ `commander={id,level}` dans capture/encode/decode/toComp + ré-exécution de l'aura sur le board reconstruit ; `tests/snapshot.lua`. **v1 = solo (ghost sans commandant)** → cette vague est activée AVANT le multi async, pas avant. | `src/net/snapshot.lua`, `tests/snapshot.lua` | **inchangé** (champ optionnel) | C2, C3 |
| **C6 — sim & équilibrage** | Ajouter les 6 commandants aux bandes EARLY/MID/END × reliques (`tools/sim.lua`/`runsim.lua`) ; balayer §6.3 (combo Couronne+echo_crown+hookjaw EN PREMIER) ; props.lua commandant-vs-commandant (terminaison) ; tuner `cdMult`/valeurs un levier à la fois. | `tools/sim.lua`, `tools/runsim.lua`, `tests/props.lua` | — (analyse) | C2-C4 |

**Golden-neutralité** : **C0, C1, C2, C3, C5 sont golden-neutres** (gated / data hors scénario golden /
champ optionnel). Seul un éventuel ajout d'un commandant au scénario golden imposerait un rebaseline — à
**éviter** (garder les commandants hors du golden, comme les keystones). **C4 (UI)** et **C6 (sim)** ne
touchent pas le golden.

**Ordre = dépendances + sécurité** : C0 (le trou moteur) d'abord et committable seul → débloque L'Aïeul/Roi
des Rats. C1 (un autre trou gated) en parallèle. C2 (data) une fois C0/C1 verts. C3 (le slot, le gros morceau
scène) après la data. C4 (UI) après C3 (besoin du slot fonctionnel). C5 (snapshot) différé au multi. C6 (sim)
valide le tout.

---

## 8. Récap des changements (la liste minimale)

- **1 modif moteur réelle** : câbler `statInc` au bake du comp (`build.lua`, §1) — **le seul prérequis**.
- **1 mini-op gated** : `stripEnemyShield` dans `arena.lua:spawn` (§2.3) — 6 lignes, ou repli sur dmgReduce-team.
- **Data** : 6 `commandBonus` + i18n (§2.2) — pure data.
- **Scène** : slot piédestal hors-graphe + drag-drop + grant de run + `resolveCommanderAura` dans `buildComp`
  (§3) — l'aura reste **build-résolue, zéro couplage arène**.
- **UI** : piédestal distinct, survol éclaire la portée, barre de cadence, ligne « Au commandement » (§4).
- **Snapshot** : `commander={id,level}` (§5) — **différé au multi**, solo non bloquant.
- **Sim** : 6 commandants × bandes × reliques, combo Couronne+echo_crown+hookjaw en premier (§6).

**Tout est golden-safe** (nil = inerte), **déterministe** (auras build-résolues, increased additif, multicast
entier, zéro RNG), et **l'arène reste SIM-autonome** (elle ne connaît jamais le plateau ni le piédestal —
elle reçoit un spec `isCommander` ordinaire qu'elle traite via du code K4 déjà en place).
