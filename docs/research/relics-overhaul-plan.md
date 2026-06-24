# Reliques — plan de refonte 3 paliers + variété + cadence ~8/run

> **Statut** : PLAN DE DESIGN autoritaire (zéro code). Implémente `effects-overhaul-spec.md` §5
> (3 paliers nets + cadence ~8) et donne un foyer aux **verbes agnostiques réservés**
> (`effects-content-plan.md` §3 : `cleave`/`execute`/`heal_on_kill`/`grant_affliction_if_absent`).
> **Conserve** le pool curé de 25 reliques + leurs 25 icônes (`src/data/relics.lua`) : on **reclasse**
> et on **étend**, on ne casse rien.
>
> **Garde-fous NON négociables** (`relics-design.md` §1) : **lisible** (nom + effet clair AVEC le
> chiffre + flavor) ; **team-wide** ; **intra-combat only** (aucune relique ne handicape la suite du run) ;
> **égalisateur** de matchup (incline, **jamais un gate** à 100 %) ; **déterministe** (zéro RNG en combat).
>
> **Sources lues ligne-à-ligne (2026-06-25)** : `src/data/relics.lua` (les 25), `src/effects/ops.lua`
> (tous les new-ops câblés + gated), `src/scenes/build.lua` (`buildComp` K1 `aura_stat` + ordre
> `startCombat`), `src/combat/arena.lua` (lecture `atkInc`/`vulnInc`/`multicast`, caps), `src/run/state.lua`
> (`maxRelicTier`/`rollRelicChoices`/`applyRelics`/`grantRelic`), `main.lua` (host : canaux 1+2),
> `tools/relicsim.lua`/`runsim.lua` (harnais d'équilibrage). Tous les chiffres = **PLACEHOLDERS** à tuner.

---

## 0. Constat de départ (le ressenti « toutes au même tier »)

Le champ `tier` existe déjà (1→4+) mais **n'est pas exposé comme une hiérarchie lisible** : il sert
seulement à `maxRelicTier` (gating par avancée). À l'usage, les 25 reliques se ressentent plates parce que
**la NATURE ne varie pas assez visiblement** — beaucoup sont des amplis (`relic_affliction_inc` ×4) ou des
`grant_team` qui se valent en lecture. Le remède (spec §5.1) : **formaliser 3 paliers de NATURE** (pas de
magnitude), grok-ables d'un coup d'œil, comme les tiers d'unités :

| Palier | Couleur | Nature | Critère DUR |
|---|---|---|---|
| **BAS — Argent** | argent terni | **stat plate universelle** | aucun conditionnel, aucune ligne d'effet neuve ; marche pour TOUTE compo |
| **MOYEN — Or** | or sale | **transformatif léger** : conditionnel / par famille / par position | une condition OU une cible restreinte OU 1 ligne d'effet d'équipe |
| **HAUT — Prismatique** | irisé/huileux | **réécrit une RÈGLE** (= unité T5) | **JAMAIS « +30 % »** : ajoute une ligne absente des bas paliers OU franchit un seuil (cap→no-cap, 1×→2×, mono→chaîne) |

Le critère dur HAUT (Riot Champion Augments) est le test de classement : *« si je peux le réduire à un
nombre plus gros, ce n'est pas un HAUT »*.

---

## 1. RECLASSEMENT des 25 reliques existantes

> Mapping `tier` actuel → palier (spec §5.1) : `tier 1` → **BAS**, `tier 2-3` → **MOYEN**, `tier 4+` →
> **HAUT**. On NE renomme PAS le champ `tier` (utilisé par `maxRelicTier`) ; on **regroupe** pour l'offre,
> la couleur de carte et la cadence. Ci-dessous, le palier **de NATURE** assigné à chacune + verdict.

### 1.a — BAS (Argent) — stats plates universelles

| id | `tier` | op | Effet | Verdict |
|---|---|---|---|---|
| `bloodstone` | 1 | `relic_more_dmg` +14 % | dmg plat team | **BAS confirmé.** Exemplar de palier. |
| `carapace` | 1 | `relic_flat_hp` +8 | PV plat team | **BAS confirmé.** |
| `aegis` | 1 | `relic_dmg_reduce` 15 % | −% subis team | **BAS confirmé.** |
| `whetstone` | 1 | `relic_haste` +15 % | cadence team | **BAS confirmé.** |

**Note** : ces 4 sont le socle « universel tôt » (PRD §5.3) et la base de l'archétype A11 (constructs sans
ampli %, qui empilent du BAS). **Aucun changement.**

### 1.b — MOYEN (Or) — transformatif léger

| id | `tier` | op | Nature transformative | Verdict |
|---|---|---|---|---|
| `kings_bowl` | 2 | `relic_affliction_inc` poison +20 % | **par famille** (poison) | **MOYEN confirmé.** Sert A1 (saturation). |
| `ember_heart` | 2 | `relic_affliction_inc` burn +30 % | par famille (burn) | **MOYEN confirmé.** |
| `weeping_nail` | 2 | `relic_affliction_inc` bleed +18 % | par famille (bleed) | **MOYEN confirmé.** |
| `grave_cap` | 2 | `relic_affliction_inc` rot +18 % | par famille (rot) | **MOYEN confirmé.** |
| `thornguard` | 2 | `relic_add_effect` thorns 2 team | ligne d'effet (épines) | **MOYEN confirmé.** Soutient A8 tank. |
| `famines_math` | 3 | `relic_few_units` ≤3 → +dmg/+hp | **conditionnel** (taille d'équipe) | **MOYEN confirmé.** Le « tall » (spec §5.2). |
| `beggars_lantern` | 2 | `runOp shop_tier_down` | (run-level, densité doublons) | **MOYEN confirmé.** A11. |
| `tithe_bowl` | 2 | `eco onWin 2` | (éco) | **MOYEN** (éco). Hors combat. |
| `paupers_boon` | 2 | `eco perRound 3` | (éco) | **MOYEN** (éco). |
| `grave_robbers_cut` | 2 | `eco sellFrac 1.0` | (éco) | **MOYEN** (éco). |

**Reclassements / signalements MOYEN :**
- **`carrion_ledger`** (`tier 3`, `runOp shop_xp +6`) et **`usurers_ledger`** (`tier 3`, intérêts) sont
  rangés `tier 3` mais ce sont des reliques **éco/run**, pas des transformatives de combat. → **MOYEN de
  nature** (elles ne réécrivent aucune règle de combat). Le `tier 3` reste pour le gating, mais la **carte
  doit être colorée Or**, pas Prismatique (sinon confusion : un joueur croit toucher un build-definer).
- **`hollow_choir`** (`tier 3`, `pierceHeal 0.40`) est **limite HAUT** : c'est une *ligne d'effet absente
  des bas paliers* (afflictions percent les soins = nouveau verbe d'équipe). → **classé HAUT de nature**
  malgré son `tier 3`. C'est le seul `tier 3` qui mérite le Prismatique (anti-sustain = règle, pas +%).

### 1.c — HAUT (Prismatique) — réécrit une règle

| id | `tier` | op | Règle réécrite | Verdict |
|---|---|---|---|---|
| `famines_math` (déjà MOYEN) | — | — | — | (conditionnel, pas une règle → reste MOYEN) |
| `hollow_choir` | 3 | `grant_team pierceHeal` | afflictions percent les soins | **HAUT** (cf. 1.b note). |
| `feeding_frenzy` | 3 | `on_death frenzy_gain` | kill → renforce (snowball borné) | **HAUT confirmé.** Payoff bruiser. |
| `sacred_shield` | 3 | `grant_team invulnT` | invuln d'ouverture | **HAUT confirmé.** |
| `second_breath` | 3 | `relic_second_breath` | survie 1× à 1 PV | **HAUT confirmé.** Franchit un seuil (mort→survie). |
| `forked_tongue` | 4 | `grant_team shockChain` | le choc rebondit (mono→chaîne) | **HAUT confirmé.** Finisher A2-shock. |
| `everburn` | 4 | `grant_team burnNoDecay` | feux ne décroissent plus | **HAUT confirmé.** |
| `open_wounds` | 4 | `grant_team bleedNoExpire` | saignements éternels | **HAUT confirmé.** |
| `plague_communion` | 4 | `grant_team plagueAmp` | 2+ afflictions → +25 % tout | **HAUT confirmé.** A5/multi-DoT. |
| `black_summons` | 4 | `runOp shop_tier_up` | +1 tier de boutique | **HAUT** (run-level). Carte Prismatique OK (rush late). |

### 1.d — Verdict de reclassement : doublons / mal-placés (la critique thématique)

| Problème | Détail | Action |
|---|---|---|
| **4 amplis-famille quasi-jumeaux** | `kings_bowl/ember_heart/weeping_nail/grave_cap` = même op `relic_affliction_inc`, seul `family`+`inc` changent | **PAS un doublon mécanique** (chacun sert SA famille). Mais ils saturent le palier MOYEN visuellement. → **Garder les 4** mais les compter comme **1 slot d'offre logique** : `rollRelicChoices` ne devrait jamais proposer **2 amplis-famille dans le même trio** (sinon « toutes pareilles »). Voir §3.5. |
| **`shock` sans ampli-famille** | Pas de `relic_affliction_inc{shock}` (le choc n'a pas de `*Inc` lu) | **Voulu** (le choc s'amplifie par vuln/empower, pas par `shockInc`). `forked_tongue` (HAUT) couvre le shock. **Pas d'ampli-famille shock** → on ne le crée pas. |
| **3 éco redondantes au palier MOYEN** | `tithe_bowl`/`paupers_boon`/`grave_robbers_cut` = trois leviers d'or proches | **Garder** (chacune a un foyer : onWin / perRound / sell). Mais **ne jamais proposer 2 éco dans le même trio** (même garde que les amplis-famille, §3.5). |
| **`carrion_ledger`/`usurers_ledger` mal colorées** | `tier 3` les peint Prismatique alors qu'elles sont éco | **Re-colorer Or** (cf. 1.b). Le palier de NATURE prime sur le `tier` numérique pour l'UI. |

**Conclusion du reclassement** : 4 BAS · 14 MOYEN · 7 HAUT (les `tier`-numériques restent pour le gating ;
la **couleur de carte** suit le palier de nature). Aucune relique supprimée, aucune icône perdue.

---

## 2. NOUVELLES reliques (pool final ~33)

> Cible : **~33 reliques** pour soutenir ~8/run de variété sans répétition. On ajoute **8 nouvelles**
> (les 3 signature spec + 5 foyers de verbes réservés + 2 archétypes sous-servis). **Chaque nouvelle est
> vérifiée contre les 25 existantes pour zéro doublon.**

### 2.0 ⚠ POINT DUR D'IMPLÉMENTATION (à graver avant de coder les nouvelles)

`startCombat` (`build.lua:1072-1076`) fait **`buildLeftComp()` PUIS `applyRelics(left)`**. Or `buildComp`
résout les auras `aura_stat` (K1) et **bake** `spec.atkInc`/`spec.multicast`/`spec.dmgReduce`/… *avant*
que `applyRelics` ne tourne. `arena.lua` lit ces champs **comme champs directs du spec** (`spec.atkInc`
l.143, `spec.multicast` l.145), et ne ré-exécute **PAS** `aura_stat` à `combat_start` (seuls
`regen`/`shield_aura`/`grant_team` y passent).

**Conséquence** : une relique signature qui injecterait `{combat_start, aura_stat, …}` via
`relic_add_effect` serait **INERTE** (l'effet est ajouté à `spec.effects` mais plus personne ne le résout
en champ). La spec §5.2 dit « `relic_add_effect {aura_stat …}` » — **c'est faux pour le code actuel**.

**Le mapping moteur CORRECT** = **1 nouvel op `R.apply` : `relic_aura_stat`** qui **bake directement le
champ combat-time sur les specs** de la compo (exactement comme `buildComp` le fait, mais team-wide ou
par rôle, résolu sur `comp` au lieu du graphe). Concrètement, dans `R.apply` :

```
elseif op == "relic_aura_stat" then  -- BAKE direct (post-buildComp), team-wide ou par rôle
  -- p = { stat="atkInc"/"multicast"/"dmgReduce"/"haste"/"lifesteal", target="team"/"role:front"/"role:back", value }
  -- target=team    : pour chaque spec de comp, spec[stat] = (spec[stat] or 0) + value   (multicast = max entier)
  -- target=role:X  : résoudre le rôle sur comp (depth = spec.depth ; front=min depth, tie-break row asc/slot asc),
  --                  baker sur CETTE seule unité (spec.atkInc/spec.multicast/…)
```

Le rôle se résout sur le `comp` (chaque spec porte déjà `depth`/`row`/`slot` posés par `buildComp`,
l.1020) avec le **tie-break identique à `chooseTarget`** (row asc, slot asc — spec §6.2.1). `target=team`
= boucle `ipairs`. **`grant_vuln`** (Marque du Voyant) est différent : ce n'est PAS un champ build-time
mais un **op `on_hit`** → là, `relic_add_effect {on_hit, grant_vuln, …}` **fonctionne** (l'effet est
injecté dans `spec.effects`, lu par `Effects.run(u, "on_hit", …)` en combat).

**Récap des 3 chemins d'injection relique :**
1. **Champ build-time** (atkInc/multicast/dmgReduce/haste/lifesteal) → **nouvel op `relic_aura_stat`**
   (bake direct sur comp). *(Bannière de Sang, Couronne d'Échos.)*
2. **Op `on_hit`/`on_attack`/`on_kill`** (grant_vuln/cleave/execute/heal_on_kill/grant_affliction_if_absent)
   → **`relic_add_effect {trigger, op, params}` existant** (injecté dans `spec.effects`, lu en combat). ✅
3. **Drapeau d'équipe** (grant_team) → **`relic_add_effect {combat_start, grant_team, …}` existant**.
   `combat_start grant_team` **EST** ré-exécuté par l'arène (l.180). ✅

Donc : **les reliques d'op `on_hit` et de `grant_team` marchent déjà**. Seules les reliques de **champ
build-time** (empower/multicast team) exigent le **nouvel op `relic_aura_stat`** (≈15 lignes, gated,
golden-safe).

### 2.1 — Les 3 signature (spec §5.2)

| id | Palier | Mapping moteur (corrigé §2.0) | Effet (carte, lisible) | Flavor | Icône |
|---|---|---|---|---|---|
| **`blood_banner`** | MOYEN | `op=relic_aura_stat` `{stat=atkInc, target=team, value=0.10}` (champ build-time) | « Toute ta meute frappe pour +10 % de plus. » | *« On hisse une peau d'homme au-dessus de la fosse ; en dessous, tout le monde frappe plus fort. »* | **À créer** (bannière de peau cloutée, hampe d'os) |
| **`seers_mark`** | MOYEN | `relic_add_effect {on_hit, grant_vuln, {value=0.15, dur=120}}` (op on_hit existant ✅) | « Tes coups marquent : la cible prend +15 % de TOUT pendant ~2 s. » | *« Il a vu trop loin, et maintenant ses yeux te montrent à tout ce qui mord. »* | **À créer** (œil ouvert au creux d'une main, iris fendu) |
| **`echo_crown`** | HAUT | `op=relic_aura_stat` `{stat=multicast, target=role:front, value=1}` (champ build-time, entier) | « Ton unité la plus avancée frappe **deux fois** par coup. » | *« La couronne se souvient de chaque coup porté, et le redonne, encore, encore. »* | **À créer** (diadème noir à dents redoublées, reflets doubles) |

**Notes d'équilibrage signature** (caps moteur, vérifiés `arena.lua:38-41`) :
- `blood_banner` : `atkInc` cappé `ATK_INC_CAP=1.5` à la lecture → empilable avec un empower-unité
  (maggot_king/zeal_inquisitor) **sans explosion** (la somme est cappée). Sur la BASE, jamais le total.
- `echo_crown` : `multicast` cappé `MULTICAST_MAX=3` ; **non scalé par niveau**. Cumul avec `hookjaw`
  (autre source multicast role:front) → la somme est cappée à 3. Voir §4 (cas de surveillance #1).
- `seers_mark` : `grant_vuln` pose en **`max()`** (`ops.lua:350`), **non additif**, cappé
  `VULN_INC_CAP=0.5`. Cumul avec corruptor/stormcaller (autres marques) = **la plus forte gagne**, jamais
  la somme → **sûr par construction**.

### 2.2 — Foyers des verbes RÉSERVÉS (`effects-content-plan.md` §3)

Ces 4 verbes n'ont **aucun ou très peu** de porteur-unité (réservés reliques/commandants). Les reliques
leur donnent un foyer team-wide.

| id | Palier | Verbe | Mapping moteur | Effet (carte) | Flavor | Icône |
|---|---|---|---|---|---|---|
| **`carrion_feast`** | MOYEN | `heal_on_kill` | `relic_add_effect {on_kill, heal_on_kill, {value=5}}` ✅ | « Chaque ennemi tué rend 5 PV au tueur. » | *« La fosse ne gaspille rien. Ce qui tombe nourrit ce qui tient encore debout. »* | **À créer** (gueule qui avale un crâne) |
| **`gravediggers_due`** | HAUT | `execute` (team) | `relic_add_effect {on_attack, execute, {threshold=0.25, bonus=0.50}}` ✅ | « Tes coups achèvent : +50 % sur tout ennemi sous 25 % PV. » | *« Sous le quart, tu n'es plus une proie ; tu es une dette qu'on solde. »* | **À créer** (faux ébréchée sur tas d'os) |
| **`splitting_maw`** | HAUT | `cleave` (team) | `relic_add_effect {on_hit, cleave, {frac=0.40}}` ✅ ⚠ voir §4 | « Tes frappes éclaboussent les voisins de la cible (40 % du coup). » | *« Une bouche n'a jamais suffi. Elle mord, et la rangée entière saigne. »* | **À créer** (mâchoire éclatée en éventail) |
| **`second_plague`** | MOYEN | `grant_affliction_if_absent` | `relic_add_effect {on_hit, grant_affliction_if_absent, {family=poison, dps=1, dur=120}}` ✅ | « Tes coups posent un venin léger là où il n'y en a pas encore. » | *« Une plaie en appelle une seconde, et la seconde n'attend pas la première. »* | **À créer** (deux plaies suintantes jumelles) |

**Pourquoi ces paliers** : `carrion_feast`/`second_plague` = MOYEN (conditionnels, bornés, n'ouvrent pas
de seuil). `gravediggers_due`/`splitting_maw` = HAUT (ils **ajoutent une ligne d'effet absente** =
critère dur HAUT : un execute team-wide ou un cleave team-wide changent *comment* l'équipe tue, pas un
nombre).

### 2.3 — Reliques pour les archétypes SOUS-SERVIS

La carte des 11 archétypes (`effects-content-plan.md` §3) est couverte par les unités, mais certains axes
n'ont **aucune relique dédiée**. On comble les deux plus sous-servis :

| id | Palier | Archétype servi | Mapping moteur | Effet (carte) | Flavor | Icône |
|---|---|---|---|---|---|---|
| **`tide_caller`** | MOYEN | **A9 bouclier-périodique** (aucune relique avant) | `relic_aura_stat {stat=dmgReduce, target=team, value=0.08}` (champ build-time) | « Toute ta congrégation encaisse 8 % de moins. » | *« Le mur se souvient d'avoir été un saint ; il endure encore par habitude. »* | **À créer** (vitrail brisé en forme d'aile) |
| **`bait_lantern`** | MOYEN | **A10 leurre/sustain** (aucune relique avant) | `relic_aura_stat {stat=lifesteal, target=team, value=0.05}` (champ build-time) | « Chaque coup de ton équipe lui rend 5 % des dégâts en PV. » | *« Allume le fanal, et laisse la faim faire le reste. Ce qui s'approche, on le boit. »* | **À créer** (lanterne abyssale, fil de chair) |

**Couverture finale par archétype** (les 11 + sous-servis) :

| Archétype | Relique(s) de soutien |
|---|---|
| A1 Saturation (DoT empilé) | `kings_bowl`/`ember_heart`/`weeping_nail`/`grave_cap`, `everburn`, `open_wounds`, `plague_communion` |
| A2 Marque (vuln) | **`seers_mark`** (NOUVEAU), `plague_communion` |
| A3 Forge (empower) | **`blood_banner`** (NOUVEAU) |
| A4 Écho (multicast) | **`echo_crown`** (NOUVEAU) |
| A5 Spread (propagation) | `everburn`, `plague_communion`, **`splitting_maw`** (NOUVEAU, frappe large) |
| A6 Burst d'exécution | **`gravediggers_due`** (NOUVEAU), `bloodstone`, `whetstone` |
| A7 Cleave de ligne | **`splitting_maw`** (NOUVEAU) |
| A8 Tank/Taunt | `carapace`, `aegis`, `thornguard`, `second_breath`, `sacred_shield` |
| A9 Bouclier-périodique | **`tide_caller`** (NOUVEAU), `aegis` |
| A10 Leurre/Sustain | **`bait_lantern`** (NOUVEAU), **`carrion_feast`** (NOUVEAU, heal-on-kill) |
| A11 Constructs/wide | `bloodstone`/`carapace`/`aegis`/`whetstone` (empilés), `beggars_lantern`, `famines_math`, `feeding_frenzy` |

**Shock (A2-shock)** : `forked_tongue` (chaîne) + `seers_mark`/`echo_crown` (la marque/l'écho amplifient
la décharge). Pas de relique shock-`*Inc` (voulu, §1.d).

### 2.4 — Anti-doublon : vérification contre les 25

Chaque nouvelle a été passée contre le pool : `blood_banner` (empower team) ≠ `bloodstone` (dmg **plat**,
pas `increased` cappé ; empower est lu en combat par K2, distinct) ; `seers_mark` (vuln entrant) n'a
**aucun** équivalent (aucune relique vuln existante) ; `echo_crown` (multicast) idem ; `carrion_feast`
(heal-on-kill) ≠ `feeding_frenzy` (snowball dmg au kill, pas de soin) ; `gravediggers_due` (execute)
unique ; `splitting_maw` (cleave) unique ; `second_plague` (grant-if-absent) ≠ les amplis-famille (pose
une affliction, ne l'amplifie pas) ; `tide_caller` (dmgReduce **team**) ≠ `aegis` (dmgReduce aussi mais
**BAS/universel** ; `tide_caller` est l'ancrage A9 thématique — à départager en sim, voir §4 #5) ;
`bait_lantern` (lifesteal team) unique. **Aucun doublon mécanique.** Seul point à surveiller :
`tide_caller` vs `aegis` (même stat) — voir §4.

---

## 3. CADENCE ~8 reliques/run (spec §5.3)

> Objectif user : passer de ~4-5 à **~8/run**. Modèle TFT : mixer 3 canaux, ne pas tout donner au même
> jalon. **Canaux 1 et 2 EXISTENT** dans le host ; **canal 3 est le travail neuf.**

### 3.1 — État du code (vérifié)

- **Canal 1 (marchand)** : `main.lua:120-123` — `if (wins+losses) % 3 == 0` → `relicpick` 1-parmi-3.
  Refuser → `declineRelic` (+or). ✅
- **Canal 2 (level-up)** : `host.offerLevelUpRelic` (`main.lua:134`) + `state.relicFromLevelThisRound`
  (borné 1/round). ✅
- **Gating par avancée** : `RunState:maxRelicTier` (`state.lua:353`) — `wins<2 → tier≤2 (BAS)` ;
  `wins<5 → tier≤3 (MOYEN)` ; `wins≥5 → tier≤4 (HAUT)`. ✅ Aligne early=BAS / mid=MOYEN / late=HAUT.
- **Canal 3 (jalon de palier)** : **ABSENT.** C'est le hook à ajouter.

### 3.2 — Chiffrage des 3 canaux (cible ~8)

| Canal | Cadence | Déclencheur (code) | Rendement/run | Calcul |
|---|---|---|---|---|
| **1. Marchand** | tous les **3 combats** (win OU défaite) | `main.lua:120` `(wins+losses) % 3 == 0` | **~3-4** | Run = ~10 victoires + ~0-4 défaites = ~10-14 combats → `floor(12/3)` ≈ **4** jalons marchand. Decline→or absorbe le surplus. |
| **2. Level-up** | **1 max/round** | `offerLevelUpRelic` + `relicFromLevelThisRound` | **~2-3** | Une run a ~10-14 rounds ; un build qui fusionne déclenche ~2-3 level-ups effectifs (pas chaque round). |
| **3. Jalon de palier** (NOUVEAU) | à la **3e ET 6e victoire** | nouveau hook `finishCombat` (§3.3) | **+2** | 2 cérémonies garanties, tier≥MOYEN. |

**Somme = ~3-4 + ~2-3 + 2 = 7-9 → moyenne ~8.** ✅ Le `declineRelic→+or` (`state.lua:387`) absorbe le
surplus sans inflation (relique non prise = or).

### 3.3 — Canal 3 : jalon 3e/6e victoire (la spec à implémenter)

Hook dans `host.finishCombat` (`main.lua:105`), **avant** le test marchand `% 3` :

```
-- CANAL 3 — jalon de palier (cérémonie de boss à la 3e et 6e victoire) :
if win and (host.run.wins == 3 or host.run.wins == 6) then
  local choices = host.run:rollRelicChoices(3, { minTier = "MOYEN" })  -- forcé tier ≥ MOYEN
  if #choices > 0 then
    host.run._milestoneRelic = true   -- marque pour l'anti double-comptage (§3.4)
    host.goto("relicpick", { choices = choices, milestone = true }); return
  end
end
-- ... puis le test marchand existant (% 3) ...
```

`rollRelicChoices` gagne un param `minTier` (filtre **plancher**, en plus du plafond `maxRelicTier`) :
le jalon ne propose jamais que du BAS (sinon une cérémonie sert 3 stat-sticks = anti-climax). À la 6e
victoire, `maxRelicTier` vaut déjà 4 (HAUT) → le jalon peut servir du Prismatique = vrai payoff late.

### 3.4 — Anti double-comptage (gravé, spec §5.3)

À la 3e victoire, `wins=3` ET `(wins+losses) % 3` peut valoir 0 → **collision** marchand + jalon. **Règle**
: le jalon de palier (canal 3) a **priorité**, et il **consomme le créneau marchand** de ce combat (on ne
sert qu'**UN** écran `relicpick`). Le `return` après le `goto` du jalon (§3.3) garantit qu'on ne tombe pas
dans le test `% 3`. **Test `tests/run.lua`** : simuler 10 victoires d'affilée → asserter exactement **2**
jalons + le bon compte de marchands (pas de double à w3/w6), et que `_milestoneRelic` route correctement.

### 3.5 — Garde de diversité de trio (résout « toutes pareilles »)

`rollRelicChoices(3)` doit éviter de servir **2 reliques de la même CLASSE** dans un trio (sinon ressenti
plat). Classes : `ampli-famille` (les 4 `*_inc`), `éco` (les 4 `eco`), `run-shop` (xp/tier), `stat-plate`
(BAS), `transformative` (HAUT). Règle simple : **au plus 1 relique par classe `ampli-famille` et 1 par
classe `éco` par trio**. Le reste du pool étant varié, ça suffit. Petit ajout à `rollRelicChoices` (filtre
post-tirage, déterministe). Sans casser le fallback (si le pool capé est petit, on relâche la contrainte).

---

## 4. LISTE DE SURVEILLANCE ÉQUILIBRAGE (à tester AVANT déploiement)

> Le vrai risque n'est pas une relique seule (toutes inclinent, bornées par les caps moteur) mais
> **l'empilement de ~8 reliques**. À balayer via `tools/relicsim.lua` (matchup-maison) + `tools/runsim.lua`
> (matrice + politiques), **un levier à la fois**.

| # | Empilement dangereux | Pourquoi | Garde-fou moteur (vérifié) | Test |
|---|---|---|---|---|
| **1** | `echo_crown` × `hookjaw` (2 sources multicast role:front) | double pose de multicast sur le carry avant | `MULTICAST_MAX=3` non-scalé : `1 (crown) + 1 (hookjaw)` = 2 ≤ 3, mais sur un **maggot_king** voisin l'empower s'ajoute → swing fort. Le `HIT_DMG_CAP_MULT=7` borne CHAQUE sous-coup. | **PRIORITÉ #1** : `relicsim` `echo_crown`+hookjaw vs poison-tank ; lift < 1,6, TTK p10 stable. |
| **2** | `blood_banner` × `maggot_king`/`zeal_inquisitor` (empower team + empower aura) | deux couches d'`atkInc` sur les mêmes frappeurs | `ATK_INC_CAP=1.5` cappe la **somme** à la lecture (`arena.lua:359`), sur la BASE | `relicsim` `blood_banner` vs tank avec un empower-unité présent. |
| **3** | `seers_mark` × corruptor/stormcaller (3 sources vuln) | redondance de marque | `grant_vuln` = **`max()`** non additif (`ops.lua:350`), cappé `VULN_INC_CAP=0.5` → **la plus forte gagne, jamais la somme** = SÛR | Smoke `tests/synergies.lua` : 3 marques sur 1 cible → `vulnInc == max`, pas `Σ`. |
| **4** | `splitting_maw` × `echo_crown` (cleave × multicast) | un coup multicast×3 sur un porteur cleave = 3 cleaves | cleave = **profondeur 1, AUCUN on_hit secondaire** (`ops.lua:415`), `ignoreShield=false`. Multicast re-frappe → 3 cleaves possibles, mais chacun borné. | **BLOQUANT** : `tests/synergies.lua` cleave×multicast (morts simultanées, ordre §2.4.1) doit être **vert** avant de livrer `splitting_maw`. Sinon différer cette relique. |
| **5** | `tide_caller` × `aegis` × bloc bouclier (3 couches dmgReduce/shield) | empilement défensif → combats non-conclus ? | `dmgReduce` n'agit que sur `cause=attack` ; pas de cap **cumulé** explicite team-wide → **risque** | `runsim` : win% bloc tank (A8+A9) **≤ +2σ** ; vérifier terminaison (fatigue ~17 s conclut). Si dérive : capper `dmgReduce` cumulé à 0.60. |
| **6** | **8 reliques empilées (le vrai cas)** | matrice relique×relique non testée | les caps par-axe tiennent, mais les **croisements** (vuln × empower × multicast × cleave) composent | **Matrice relique×relique** : nouveau mode `relicsim` ou `runsim` qui sweep des **paires** de reliques sur le matchup-maison de chaque archétype → flag toute paire qui pousse un mirror > ~85 % (= GATE). |
| **7** | `gravediggers_due` × `bait_lantern`/A10 (execute mange le leurre) | execute sur low-hp = anti-synergie avec le sustain | voulu (anti-synergie de draft, `effects-content-plan.md` §3 collision 4) | pas un bug — vérifier que ça **incline** (Δwin), pas que ça **gate**. |

**Seuils d'équilibre** (réutiliser `effects-overhaul-spec.md §9.3 / relics-design.md §1.3`) : une relique
**incline** (Δwin > 0, mirror < ~85 %) ; **jamais un gate** (mirror ~100 % ou counter effacé = à nerf).
`relicsim` est déjà câblé pour le matchup-maison (mirror vs counter) — **ajouter les 8 nouvelles à `CASES`**.

---

## 5. ORDRE D'IMPLÉMENTATION (vagues, chacune verte sur `tools/check.sh`)

> Convention git-warden : brancher chaque vague depuis `dev`, commit quand `check.sh` vert. Golden SIM
> **inchangé** sauf rebaseline explicite (la plupart des étapes sont golden-neutres : les reliques ne
> touchent pas le scénario golden).

| Vague | Contenu | Fichiers | Golden | Dépend |
|---|---|---|---|---|
| **V0 — Reclassement (data/UI, golden-neutre)** | Mapper les 25 → 3 paliers de NATURE (§1) ; ajouter un champ `band = "low"/"mid"/"high"` sur chaque relique (ou table de mapping) ; re-colorer les cartes (Argent/Or/Prismatique) ; re-colorer `carrion_ledger`/`usurers_ledger` en Or. | `src/data/relics.lua`, `src/scenes/relicpick.lua` (couleur), i18n inchangé | **inchangé** (data + render) | — |
| **V1 — Op `relic_aura_stat` (moteur, gated)** | **1 nouvel op `R.apply`** qui bake `spec.atkInc/multicast/dmgReduce/haste/lifesteal` team-wide ou par rôle (§2.0). Résolution de rôle sur `comp` (tie-break = chooseTarget). Gated (aucune relique ne l'utilise encore → golden inchangé). | `src/data/relics.lua` (`R.apply`) | **inchangé** (gated) | — |
| **V2 — Reliques MOYEN nouvelles** | `blood_banner` (relic_aura_stat), `seers_mark` (relic_add_effect on_hit), `carrion_feast` (on_kill), `second_plague` (on_hit grant-if-absent), `tide_caller` (relic_aura_stat), `bait_lantern` (relic_aura_stat) + i18n (name/effect/flavor) + flags icônes. | `relics.lua`, `src/i18n/en.lua`, `tests/relics.lua` | inchangé (reliques hors golden) | V1 |
| **V3 — Reliques HAUT nouvelles** | `echo_crown` (relic_aura_stat multicast role:front), `gravediggers_due` (on_attack execute), `splitting_maw` (on_hit cleave — **après** que `tests/synergies.lua` cleave×multicast soit vert, §4 #4) + i18n + icônes. | `relics.lua`, `src/i18n/en.lua`, `tests/synergies.lua`, `tests/relics.lua` | inchangé | V1, V2 |
| **V4 — Canal 3 + gating + garde de trio** | Hook `finishCombat` jalon w3/w6 ; param `minTier` + filtre de trio dans `rollRelicChoices` ; anti double-comptage (§3.4). Tests cadence + non-doublon. | `main.lua` (host), `src/run/state.lua`, `tests/run.lua` | inchangé (routage host, hors SIM) | — (parallèle à V1-V3) |
| **V5 — Sim de la cadence + matrice** | `relicsim` : ajouter les 8 nouvelles à `CASES`. `runsim` : nouveau mode **matrice relique×relique** (paires sur matchup-maison). Mesurer cadence réelle (~8) via `runsim` politiques (compter les `relicpick` servis/run). Tuner un levier à la fois. | `tools/relicsim.lua`, `tools/runsim.lua` | — (analyse) | V2, V3, V4 |
| **V6 — Icônes (pixel-art)** | 8 icônes neuves (asset-forge / pixel-art-master), DA alignée sur les 25 existantes (réf `src/scenes/relicons.lua`). | (assets) | — | V2, V3 |

**Ordre = sécurité** : V0 (golden-neutre) committable tout de suite. V1 (op gated) committable seul. Les
reliques (V2/V3) ne touchent jamais le golden. V4 est indépendant (cadence) → parallélisable. V5 valide
**après** que le contenu existe. V6 (icônes) en parallèle, non bloquant pour la logique.

---

## 6. Récap pool final (33 reliques)

- **BAS (4)** : `bloodstone`, `carapace`, `aegis`, `whetstone`.
- **MOYEN (16)** : `kings_bowl`, `ember_heart`, `weeping_nail`, `grave_cap`, `thornguard`, `famines_math`,
  `beggars_lantern`, `tithe_bowl`, `paupers_boon`, `grave_robbers_cut`, `carrion_ledger`, `usurers_ledger`
  + **NOUVELLES** : `blood_banner`, `seers_mark`, `carrion_feast`, `second_plague`, `tide_caller`,
  `bait_lantern`. *(= 18 ; ajuster gating si trop chargé.)*
- **HAUT (9-11)** : `hollow_choir`, `feeding_frenzy`, `sacred_shield`, `second_breath`, `forked_tongue`,
  `everburn`, `open_wounds`, `plague_communion`, `black_summons` + **NOUVELLES** : `echo_crown`,
  `gravediggers_due`, `splitting_maw`.

**Total = 25 conservées + 8 neuves = 33.** Couvre les 11 archétypes, donne un foyer aux 4 verbes réservés,
et soutient une cadence ~8/run avec 3 paliers nets et lisibles.

---

## 7. Questions ouvertes (défaut proposé)

| # | Question | Défaut |
|---|---|---|
| Q1 | `relic_aura_stat` `target=role:front` se résout sur `comp` post-buildComp — mais `applyRelics` tourne dans `startCombat` côté JOUEUR uniquement. Les **ghosts** (snapshots) capturent-ils les reliques ? | **Non en v1** (dette `snapshot.lua` connue). Les reliques restent **solo/build-courant** ; un ghost rejoue ses unités SANS ses reliques (comme les auras synergie-famille, spec §2.5.1). À encoder dans le schéma snapshot plus tard. **Signalé, non bloquant solo.** |
| Q2 | Faut-il un 4e canal (achat à l'or) ? | **Non** (relics-design.md §2 : pas d'achat en v1, les reliques ne concurrencent pas les unités). Les 3 canaux suffisent pour ~8. |
| Q3 | `splitting_maw` (cleave team-wide) est-il trop fort vs `siege_breaker` (seul hôte cleave unité) ? | **À départager en sim** (V5). Si le cleave team domine, le **réserver HAUT late-only** (déjà le cas) suffit ; sinon réduire `frac` 0.40→0.30. |
| Q4 | `tide_caller` (dmgReduce team) vs `aegis` (dmgReduce BAS) — redondance de stat ? | **Garder les deux** : `aegis` = BAS universel (15 %), `tide_caller` = MOYEN thématique A9 (8 % + ancrage bouclier). Si la sim montre que `tide_caller` n'apporte rien au-delà d'`aegis`, le **re-thématiser en `regen` team** (autre stat) plutôt que le supprimer. |
| Q5 | `minTier="MOYEN"` au jalon w3 alors que `maxRelicTier` vaut 3 à w3 (mid) — cohérent ? | **Oui** : plancher MOYEN + plafond MOYEN à w3 → le jalon sert exactement du transformatif (pas de BAS, pas de HAUT trop tôt). À w6, plafond=HAUT → vrai payoff. Aligné anti-snowball PRD §5.4. |
