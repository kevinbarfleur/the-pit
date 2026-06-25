# The Pit — Rollout du COMMANDEMENT à tout le roster (spec de conception)

> **Date** : 2026-06-25 · **Statut** : SPEC DE DESIGN (zéro code écrit). Pilote l'implémentation.
> **But** : donner à **CHAQUE unité** un `commandBonus` thématique pour qu'aucune carte n'affiche
> plus « Cannot command » (`monstercard.lua:398`). Aujourd'hui **6/84** unités en portent un.
>
> **Méthode (CLAUDE.md §1.a)** : aucune API supposée. Tout ce qui est affirmé sur le moteur a été
> **lu dans le code réel** (refs en §0). Les chiffres sont des **PLACEHOLDERS** d'équilibrage
> (à tuner via `tools/sim.lua` / `runsim.lua`) ; ce sont les **portées / stats / cibles** qui sont
> la décision de design.
>
> **Sources lues ligne-à-ligne** : `src/scenes/build.lua` (handler `aura_stat` K1, `STAT_FIELDS`,
> `resolveTargets`, `bakeAuraStat`, injection `commandBonus` l.1196-1228, 1265-1281), `src/combat/arena.lua`
> (`makeUnit` champs lus l.115-167, ciblage K4, `grant_team`/`teamFlags`, caps l.32-61, 881-884),
> `src/data/relics.lua` (`STAT_FIELD`, `resolveRoleSpec`, `bakeStat`, `R.apply`), `src/effects/ops.lua`
> (`grant_vuln`, `grant_team`, `grant_affliction_if_absent`, caps), `src/data/units.lua` (roster complet),
> `src/render/monstercard.lua` (bandeau « At command »), `src/i18n/en.lua` (clés `command_*`),
> `docs/research/commanders-plan.md` (plan d'implémentation), `docs/research/commanders-and-effect-diversity-brainstorm.md`
> (vision, portée×puissance, forks).

---

## 0. CONTRAT MOTEUR (vérifié — ce qui borne TOUTE la conception)

La forme data d'un `commandBonus` est **strictement** :
```
commandBonus = { trigger = "combat_start", op = <OP>, target? = <TARGET>, params = { ... } }
```
Et **seuls deux `op` sont réellement injectés** quand l'unité est au piédestal (`build.lua:1224, 1272`) :

### 0.1 `op = "aura_stat"` — l'aura build-résolue (le cheval de bataille)
`bakeAuraStat` (`build.lua:1196-1207`) lit `stat`, `target`, `value` et bake `value` (× le LEVEL_MULT
de la source, **sauf `multicast` qui n'est jamais scalé**) sur les slots-cibles.

**Whitelist des `stat`** (`build.lua:1162-1163`, `STAT_FIELDS`) — **les SEULS stats qui résolvent** :

| `stat` | Champ moteur lu | Où c'est consommé en combat | Cap à la lecture |
|---|---|---|---|
| `haste` | `spec.haste` | `arena.lua` timer `* (1-haste)` (l.~670) | **AUCUN** ⚠ |
| `atkInc` | `spec.atkInc` | `hit()` `Stats.increased(atkInc)` (l.420-422) | `ATK_INC_CAP=1.5` |
| `dmgReduce` | `spec.dmgReduce` | `damage()` cause="attack" (l.257) | **AUCUN** ⚠ (additif libre) |
| `regen` | `spec.regenAura` → `u.regen` | tick de soin (l.~530) | **AUCUN** ⚠ |
| `multicast` | `spec.multicast` | boucle de swing `min(multicast,MAX)` (l.777) | `MULTICAST_MAX=3` |
| `lifesteal` | `spec.lifestealAura` | `hit()` soin = frac×dégâts (l.~377) | **AUCUN** ⚠ |
| `statInc` | absorbé dans `hp`/`dmg` au build | bake (`build.lua:1241-1244`) | `STAT_INC_CAP=1.0` |
| `focusWith` | `spec.focusWith` | tie-break ciblage (faible) | n/a |

> **`focusWith`** est spécial-casé (`build.lua:1202-1203`) : `value` ignoré, pose le slot-source comme
> cible-copiée. Utilisable mais effet ténu (l'allié vise la même proie). Cas de niche.

**Whitelist des `target`** (`build.lua:1173-1191`, `resolveTargets`) — **les SEULES portées qui résolvent** :

| `target` | Résout | Note commandant |
|---|---|---|
| `team` | tous les slots du board | ✅ — le commandant ne se cible jamais (hors `placed`) |
| `role:front` | min(depth), tie-break row→slot | ✅ — l'avant-garde du board |
| `role:back` | max(depth) | ✅ |
| `role:center` | nœud à 4 voisins (degré sigil), fallback front | ✅ — dépend de la **forme** du sigil |
| `tier:N` | toutes les unités `rank==N` | ✅ — sélecteur de stratégie |
| `level:N` | toutes les unités `level==N` (duplicatas) | ✅ |
| `neighbors` | **VIDE pour le commandant** (hors graphe, `srcSlot=nil`) | ❌ inutile au piédestal |

### 0.2 `op = "grant_team"` — le drapeau d'équipe (transformatif)
`build.lua:1272` ajoute le `commandBonus grant_team` aux `effects` du commandant → l'arène le pose à
`combat_start` (`ops.lua:278-298`). **Flags réellement lus par le moteur** (vérifié) :

`poisonNoCap`, `poisonDurBonus`, `shockChain`, `burnNoDecay`, `bleedNoExpire`, `plagueAmp`,
`pierceHeal`, `invulnT`, `slowEnemies`, `rotEnemies`, `stripEnemyShield`.

**Tout autre flag = inerte** (il faut un handler `ops.lua grant_team` + un point de consommation arène).

### 0.3 Conséquence de design (la règle d'or de ce doc)
> **Un `commandBonus` qui n'est pas `aura_stat`(stat∈whitelist, target∈whitelist) ou
> `grant_team`(flag∈liste lue) est INERTE.** Le bandeau « At command » l'affichera quand même
> (la carte lit `commandBonus ~= nil` et le i18n `command_desc`, `monstercard.lua:240-242`), donnant
> une **fausse promesse**. → On ne livre un `commandBonus` « hors-whitelist » **que** si on livre aussi
> le trou moteur correspondant (§2). Sinon on reste dans la whitelist.

Cela structure le doc en **deux pools** :
- **Pool A (zéro code)** : `commandBonus` n'utilisant QUE la whitelist actuelle → data + i18n purs.
- **Pool B (gated par un trou moteur)** : `commandBonus` exploitant un nouveau levier (§2) → vagues
  d'implémentation dédiées. **Chaque unité du Pool B a un repli Pool A** (si on ne fait pas le trou,
  on lui donne une aura whitelist équivalente, jamais « Cannot command »).

---

## 1. PRINCIPES D'ÉQUILIBRAGE (le budget portée × puissance, appliqué à 84 unités)

Source : brainstorm §9.1 (« budget = magnitude × nombre de cibles ») + commanders-plan §6.1. **Le danger
n°1 du rollout-à-tout-le-roster** : 84 auras qui s'ajoutent au pool → power-creep si elles convergent.
On répartit par **portée**, **rang**, et **stat** pour qu'AUCUNE ne domine.

### 1.1 Barème par RANG (la magnitude est gatée par la rareté, pas seulement la portée)
Un commandant est **gaté par la possession** (il faut avoir drafté l'unité — leçon TFT, brainstorm §13.1).
Une commune (rank 1) sortira **bien plus souvent** qu'une légendaire (rank 5). Donc :

| Rang | Rôle du commandant | Magnitude type (team) | Magnitude type (conditionnel/mono) |
|---|---|---|---|
| **1** (commune) | « défaut sûr », léger, souvent **conditionnel restrictif** | haste/lifesteal `0.04–0.06` ; atkInc team `0.06–0.08` | tier:1 ou role:* faible |
| **2** | léger-moyen | `0.06–0.08` | conditionnel moyen |
| **3** | moyen, oriente un archétype | `0.08–0.10` | role:* ou tier:N moyen-fort |
| **4** | fort, transformatif possible | `0.10` ou conditionnel fort | role:front fort / grant_team mineur |
| **5** (légendaire) | **transformatif**, définit un build | grant_team / mono-cible fort | role:front `multicast`, grant_team apex |

> **Pourquoi c'est borné malgré 84 auras** : (a) **un seul slot piédestal** → une seule aura active par
> combat (pas de cumul d'auras de commandement entre elles) ; (b) toutes passent par la couche `increased`
> **additive sur la BASE** (jamais `more`/total — règle Atrophy-Aura, brainstorm §13.2) ; (c) les **caps à
> la lecture** (`ATK_INC_CAP=1.5` etc.) bornent même le cumul aura+relique+aura-d'adjacence ; (d) le corps
> du commandant est **nerfé en cadence** (`COMMANDER_CD_MULT=1.5`) → l'aura est la vedette, pas le DPS perso.

### 1.2 Quota de DIVERSITÉ (anti-monoculture — distribution cible sur ~84 unités)
On vise une **répartition lisible** plutôt que « tout le monde +atk team ». Cible approximative :

| Stat / mécanique | Cible | Garde-fou de stacking |
|---|---|---|
| `atkInc` (empower) | ~14 | `ATK_INC_CAP=1.5` borne la somme (aura+relique+maggot_king) |
| `haste` (tempo) | ~12 | **AUCUN cap moteur** → magnitudes **petites** (≤0.10) + signaler combo `whetstone` |
| `dmgReduce` (armure) | ~12 | **AUCUN cap** → magnitudes **petites** (≤0.08) + signaler combo `aegis`/`tide_caller` |
| `lifesteal` (sustain) | ~10 | **AUCUN cap** → ≤0.06 + signaler combo `bait_lantern` ; rot/pierceHeal contrent |
| `regen` (soin/s) | ~8 | **AUCUN cap** → valeurs entières petites (1–3) ; pierceHeal contre |
| `statInc` (brut hp+dmg) | ~10 | `STAT_INC_CAP=1.0` ; **toujours conditionnel** (tier:/level:) jamais team |
| `multicast` (écho) | ~6 | `MULTICAST_MAX=3` ; **role:* uniquement** (jamais team — broken, brainstorm §9.1) |
| `grant_team` (transform) | ~8 | flags existants ; **rang 4-5 only** ; le T3 ne scale que ses stats |
| `focusWith` (focus-fire) | ~2 | effet ténu, niche |
| **Pool B** (nouveaux leviers, §2) | reste | gated par le trou moteur (repli Pool A sinon) |

> **Règle anti-cumul gravée** : **`multicast target=team` est INTERDIT** (broken par construction —
> brainstorm §9.1 : « +1 multicast à toute l'équipe = broken ; à UNE unité = sain »). Tout `multicast`
> commandant est `role:front`/`role:back`/`role:center`. Idem `statInc target=team` interdit (toujours
> conditionnel : tier:/level:).

### 1.3 Le fil thématique (chaque aura DOIT découler de l'identité de l'unité)
Le `commandBonus` se lit comme la « seconde nature » de la créature (brainstorm §8.1). On dérive de
**nom + famille + rôle + passif** :
- Un **tank** (gravewarden, templar, shieldbearer…) → aura **défensive** (dmgReduce / regen / armure team).
- Un **afflicteur** → aura qui **amplifie son école** (atkInc pour plus de frappes-vecteur, ou
  conditionnel) — **PAS** forcément « +poison team » (un afflicteur-commandant veut souvent un enabler
  agnostique qui sert AUSSI les autres, brainstorm §1.2).
- Un **enabler/aura déjà présent** (hookjaw multicast, maggot_king empower, bellows_priest haste) →
  son aura de commandement **généralise** son aura d'adjacence à une portée plus large/forte.
- Un **héros rare** (deep_kraken, ash_maw, festering, pit_maw…) → **transformatif** (grant_team) ou
  conditionnel fort (statInc level:1).

---

## 2. TROUS MOTEUR (Pool B) — ce qu'il faut implémenter, par fichier

> Chaque trou est **gated/golden-safe** (nil = inerte). Tant qu'aucune unité ne le porte au piédestal en
> sim, le golden ne bouge pas (le `commandBonus` ne s'active qu'au build avec un commandant posé).
> **Distinction nette** : « RÉUTILISE l'existant » (Pool A, zéro code) vs « NOUVEAU » (Pool B).

### TROU #1 — `aura_stat` : router les amplis d'AFFLICTION (`poisonInc/burnInc/bleedInc/rotInc`) via la cible team/role
**Pourquoi** : on veut des commandants « mono-école » (ex. « toute ta meute empoisonne plus fort »)
— c'est l'archétype le plus thématique pour les ~15 unités poison, ~13 burn, etc. **Aujourd'hui**, les
amplis d'affliction existent **uniquement** en aura d'adjacence (`aura_poison_dps`/`aura_burn_dps`/
`aura_rot_growth`/`aura_grant_bleed`, `build.lua:1027-1030`), bakés sur un chemin **séparé** de
`bakeAuraStat` → **pas accessibles** comme `commandBonus` (`bakeAuraStat` ne connaît que `STAT_FIELDS`).
- **Ce qui existe** : les champs `poisonInc/burnInc/bleedInc/rotInc` sont **déjà lus** par la pose de DoT
  (`arena.lua:130-131`, `ampDps`/`ops.lua:31`) et bornés (`DOT_CAP_MULT=3`). Le champ `rotGrowth` (enfle)
  existe aussi.
- **Le trou** : étendre `STAT_FIELDS` (`build.lua:1162`) avec `poisonInc, burnInc, bleedInc, rotInc`
  **et** mapper ces stats dans `bakeAuraStat`/`addStat` vers les buffers `poisonInc[slot]`/etc. déjà
  existants (au lieu de `statBuf`). C'est ~6 lignes : `addStat` route déjà vers `statBuf` ; il faut un
  `if stat∈{poisonInc,...} then poisonInc[slot]=... else statBuf...`. **Mirror dans `relics.lua STAT_FIELD`**
  (pour la cohérence aura/relique).
- **Fichiers** : `src/scenes/build.lua` (`STAT_FIELDS` + routage dans `bakeAuraStat`).
  **Optionnel** `src/data/relics.lua` (`STAT_FIELD`) si une relique veut le même.
- **Cap** : `DOT_CAP_MULT=3` borne l'output ; signaler combo `poisonInc team` (commandant) × `kings_bowl`
  (relique poisonInc) × `miasma_acolyte` (aura poisonInc) → 3 sources, mais cap output ×3 tient.
- **Magnitude** : `0.15–0.30` (increased) selon rang (cf. les reliques `relic_affliction_inc` : poison
  conservateur 0.20, burn/bleed/rot 0.18-0.30).

### TROU #2 — `aura_stat stat="vuln"` : une marque de vulnérabilité team/role AU COMBAT_START
**Pourquoi** : la vulnérabilité est « l'exposition que toute compo veut » (brainstorm §5, vague A) —
un commandant qui marque l'ennemi avant la bataille est un archétype d'enabler universel.
- **Ce qui existe** : `vulnInc` est lu par `damage()` (`arena.lua:346-348`), cappé `VULN_INC_CAP=0.5`.
  **MAIS** il n'est posé **que** par l'op `grant_vuln` (on_hit, `ops.lua:348`) **sur la victime frappée**,
  jamais en aura build-résolue, et **jamais sur un allié** (c'est un débuff ennemi).
- **Le trou** : une « aura de vuln » est conceptuellement un **débuff de l'équipe ENNEMIE**, ce qui ne
  rentre PAS dans le modèle `aura_stat` (qui bake sur SES propres slots du board). **Décision** : NE PAS
  forcer `vuln` dans `aura_stat`. À la place, en faire un **`grant_team`** (TROU #2bis) : un flag
  `markEnemiesVuln = 0.12` posé à combat_start qui applique `vulnInc` à toute l'équipe ennemie (calque
  exact de `slowEnemies`/`rotEnemies`, `ops.lua:291-298`). ~5 lignes dans `ops.lua` (handler grant_team)
  + lecture dans `arena.lua:spawn` (boucle ennemis, comme `stripEnemyShield`).
- **Fichiers** : `src/effects/ops.lua` (flag `markEnemiesVuln` dans le handler `grant_team`),
  `src/combat/arena.lua` (`spawn`, après combat_start, applique `vulnInc` aux ennemis, cappé à la lecture).
- **Cap** : `VULN_INC_CAP=0.5` à la lecture (déjà en place) → cumul avec corruptor/seers_mark = `max()`-safe
  côté on_hit, mais l'aura pose en flat ; **signaler** : un flat team-vuln + des marques on_hit s'additionnent
  AVANT le cap → reste ≤0.5 (sûr). Magnitude `0.08–0.12`.

### TROU #3 — `grant_team` : nouveaux flags d'école pour les transforms manquants
**Pourquoi** : on a des transforms pour ash_maw (burnNoDecay), festering (poisonNoCap), slow_bleed
(slowEnemies), pit_maw (rotEnemies). Mais des unités-héros d'autres écoles méritent leur transform de
commandement, et certains flags utiles n'existent pas.
- **Ce qui existe** (réutilisable directement comme `commandBonus`, **Pool A**) : `burnNoDecay`,
  `poisonNoCap`, `slowEnemies`, `rotEnemies`, `bleedNoExpire`, `shockChain`, `plagueAmp`, `pierceHeal`,
  `invulnT`, `stripEnemyShield`, `poisonDurBonus`. **Tout commandant rang 4-5 peut piocher dedans sans
  code.**
- **Le trou** (nouveaux flags souhaitables, optionnels) :
  - `shockDischargeBonus` (la décharge choc tape plus fort) — pour un commandant choc-apex. Lu dans
    `dischargeShock` (`arena.lua:~352`). Repli Pool A : `shockChain=1`.
  - `burnSpreadOnDeath` team (les feux se propagent à la mort) — calque de `spread_burn_on_death` en aura.
    Repli Pool A : `burnNoDecay`.
  - **Décision** : ces flags sont **NICE-TO-HAVE**, pas requis pour « zéro Cannot command ». On les liste
    mais on **n'en dépend pas** : chaque héros a un flag **existant** comme repli (Pool A).
- **Fichiers** (si on les fait) : `src/effects/ops.lua` (handler grant_team), `src/combat/arena.lua`
  (point de consommation). Sinon : **ignorer ce trou**, utiliser les flags existants.

### TROU #4 (déjà identifié plan §1) — `statInc` câblé au bake
**Statut** : C'est le prérequis **déjà spécifié** dans `commanders-plan.md §1` (consommer
`statBuf[slot].statInc` au bake hp/dmg, cappé `STAT_INC_CAP`). **Vérifié dans le code** : `build.lua:1241-1244`
**le fait déjà** (`local si = ... ; local sf = (si>0) and (1+min(STAT_INC_CAP,si)) or 1 ; hp=floor(u.hp*m*sf+...)`).
→ **`statInc` EST câblé** (galvanizer/deep_kraken l'utilisent). **PAS un trou.** Réutilisable librement (Pool A).

### Récap des trous
| Trou | Statut | Effort | Fichiers | Repli Pool A |
|---|---|---|---|---|
| #1 amplis d'affliction en aura_stat team/role | **NOUVEAU** | faible (~6 l.) | `build.lua` (+`relics.lua`) | atkInc team (empower générique) |
| #2 marque de vuln team (grant_team `markEnemiesVuln`) | **NOUVEAU** | faible (~10 l.) | `ops.lua`, `arena.lua` | atkInc team |
| #3 flags grant_team d'école supplémentaires | **NOUVEAU (optionnel)** | faible/flag | `ops.lua`, `arena.lua` | flag existant |
| #4 `statInc` câblé | **DÉJÀ FAIT** (vérifié) | — | — | — |

> **Position recommandée** : faire **#1** (débloque tout l'archétype « mono-école commandant », à plus
> haut rendement thématique pour ~50 afflicteurs) et **#2** (un enabler universel). **#3 = à la demande.**
> Sans aucun trou, **100% du roster reste couvrable en Pool A** (les replis), donc « zéro Cannot command »
> est atteignable **dès la data**, et les trous ne font qu'**enrichir** la diversité.

---

## 3. TABLE COMPLÈTE DES `commandBonus` (84 unités)

> Légende : **Pool** A = whitelist actuelle (zéro code) · B# = nécessite le trou §2 indiqué (repli A noté).
> `value` = PLACEHOLDER. `command_desc` = i18n EN, voix grimdark, **valeurs concrètes, jamais de %**
> (`[[feedback-concrete-values-over-percentages]]`) — sauf quand le moteur EST un % (haste/lifesteal/
> atkInc/dmgReduce : on exprime alors en langage concret « strikes faster », « heals for a sliver », pas
> « +8% »). Les afflictions/écho/statInc s'expriment toujours concrètement.

### 3.0 Les 6 EXISTANTES (référence de style — NE PAS retoucher)
| id | rang | commandBonus | command_desc (en place) |
|---|---|---|---|
| demon | 1 | `aura_stat lifesteal team 0.05` | "Your whole pit heals for 5% of the damage it deals." |
| maggot_king | 3 | `aura_stat multicast role:front 1` | "Your foremost unit strikes twice each swing." |
| bellows_priest | 3 | `aura_stat haste team 0.08` | "Your whole pit strikes 8% faster." |
| galvanizer | 4 | `aura_stat statInc tier:1 0.14` | "Your tier-1 units gain +50% health and damage." |
| siege_breaker | 3 | `grant_team stripEnemyShield 0.5` | "Enemy shields are halved before the first blow." |
| deep_kraken | 5 | `aura_stat statInc level:1 0.15` | "Your unfused beasts gain +40% health and damage." |

> ⚠ Note de cohérence : `galvanizer`/`deep_kraken` `command_desc` disent « +50% / +40% » mais la `value`
> data est 0.14/0.15 (re-tunée). Le i18n est **désynchronisé du chiffre réel** (dette existante). Pour les
> 78 nouvelles, on rédige `command_desc` **sans chiffre exact discutable** OU on garde le chiffre aligné
> sur la `value` au moment de l'implémentation (recommandé : phrase concrète sans % quand possible).

---

### 3.1 LES 6 VANILLE restantes (marauder, templar, skeleton, bandit, witch)
*(demon déjà fait)*

| id | rang/type | passif existant | commandBonus | command_desc (EN) | Pool | rationale |
|---|---|---|---|---|---|---|
| **marauder** | 1 / flesh bruiser | bonus_first +8 / execute <25% +60% | `aura_stat atkInc role:front 0.12` | "Your foremost beast tears with a butcher's weight." | A | Brute → arme l'avant-garde (le carry qui catch). Empower role:front = fort mais 1 cible, cappé ATK_INC_CAP. |
| **templar** | 3 / order tank | dmgReduce aura voisins 0.12 | `aura_stat dmgReduce team 0.08` | "The whole pit takes the blow as one shield." | A | Tank-aura → généralise son armure d'adjacence à toute l'équipe (faible car team, pas de cap → 0.08 prudent). |
| **skeleton** | 1 / bone | thorns 3 | `aura_stat dmgReduce team 0.05` | "Old bone turns the edge of every blade, a little." | A | Commune défensive légère. dmgReduce team 0.05 = défaut sûr (anti-aggro). |
| **bandit** | 1 / flesh (no effect) | — (flavor) | `aura_stat haste team 0.05` | "Cutthroats move quick, and so does the pit." | A | Stat-stick sans identité → donne un tempo léger (la commune « tempo de base »). |
| **witch** | 2 / arcane carry | poison 2dps/3s | `aura_stat poisonInc team 0.18` | "Every venom in the pit bites a third deeper." | **B#1** (repli: `atkInc team 0.07`) | Carry poison → ampli poison d'équipe (mono-école). Repli empower si #1 non fait. |

---

### 3.2 AFFLICTEURS DoT — burn (13 unités)
> Doctrine : varier entre **ampli de sa propre école** (B#1), **enabler agnostique** (haste/atkInc, sert
> AUSSI les autres), et **transform** (rang 4-5, grant_team). Pas 13× « +burn team ».

| id | rang | passif | commandBonus | command_desc (EN) | Pool | rationale |
|---|---|---|---|---|---|---|
| **emberling** | 2 | burn 6/2.5s | `aura_stat burnInc team 0.20` | "The pit's fires gnaw a third hotter." | B#1 (repli atkInc team 0.07) | Burst burn → ampli burn école. |
| **cinder_cur** | 2 | burn 4 refresh | `aura_stat haste team 0.06` | "Quick little fires; the whole pack strikes quicker." | A | Cadence rapide → tempo team (sert tout DoT). |
| **pyre_tender** | 2 | burn 10 front-load | `aura_stat atkInc role:front 0.12` | "Your foremost thing burns with a heavy, opening blow." | A | Front-load lourd → empower l'avant (gros coup). |
| **ash_moth** | 1 | burn 7 decay | `aura_stat haste team 0.04` | "Ash on the wind hurries every blow." | A | Commune éphémère → micro-tempo (défaut sûr rang 1). |
| **pyre_herald** | 2 | burn 6 | `aura_stat burnInc team 0.18` | "Black pyres flare deeper across the pit." | B#1 (repli atkInc team 0.07) | Cultiste feu → ampli burn. |
| **zeal_inquisitor** | 2 | burn 5 + atkInc aura 0.12 | `aura_stat atkInc team 0.07` | "The whole pit strikes with zealous force." | A | A déjà empower d'adjacence → généralise empower à team (faible). |
| **bellows_priest** | 3 | *(déjà commandant)* | — | — | — | — |
| **wildfire_hound** | 4 | burn 5 + spread on death | `grant_team burnNoDecay` | "While it leads, the pit's fires never die down." | A (flag existant) | Propagateur feu → transform everburn (rang 4). |
| **kiln_warden** | 4 | burn 5 extend_if_weaker | `aura_stat burnInc team 0.22` | "The kiln keeps the pit's fires fed and fierce." | B#1 (repli atkInc team 0.10) | Conservation burn → ampli fort burn (rang 4). |
| **soot_acolyte** | 3 | aura burn dps voisins | `aura_stat burnInc team 0.20` | "Soot in every lung; the pit's fires bite deeper." | B#1 (repli atkInc team 0.08) | Aura burn d'adjacence → généralise à team. |
| **skull_colossus** | 5 | burn 4 + heal_on_kill | `aura_stat statInc tier:1 0.30` | "Lesser things swell vast in the colossus's shadow." | A | Légendaire → conditionnel fort tier:1 (couronne les petits). statInc câblé, cappé. |
| **ash_maw** | 5 | burn 6 + burnNoDecay (self team) | `grant_team plagueAmp 0.25` | "Two afflictions at once, and the pit's hunger doubles." | A (flag existant) | Apex burn → transform croisé (2+ afflictions amplifient). Différent de son burnNoDecay de board. |
| **plague_pyre** | 5 | burn 5 + spread+poison on death | `grant_team burnNoDecay` | "Its reign keeps every fire of the pit eternal." | A (flag existant) | Apex burn-poison → everburn team. |

---

### 3.3 AFFLICTEURS DoT — bleed (12 unités)
| id | rang | passif | commandBonus | command_desc (EN) | Pool | rationale |
|---|---|---|---|---|---|---|
| **razorkin** | 2 | bleed 2 slow 0.20 | `aura_stat bleedInc team 0.18` | "Every wound the pit opens bleeds freer." | B#1 (repli atkInc team 0.07) | Bleed standard → ampli bleed école. |
| **gash_fiend** | 2 | bleed 3 slow 0.20 | `aura_stat bleedInc team 0.20` | "The pit's cuts run deep and slow to close." | B#1 (repli atkInc team 0.07) | Bleed un peu fort → ampli bleed. |
| **hookjaw** | 2 | bleed 1 + multicast aura role:front | `aura_stat multicast role:front 1` | "Your foremost beast strikes twice each swing." | A | Déjà multicast d'adjacence → MÊME aura en commandement (mono role:front). ⚠ identique à maggot_king cmd : OK (2 accès, MULTICAST_MAX borne). |
| **leech_thorn** | 3 | bleed 2 + thorns 3 | `aura_stat dmgReduce team 0.06` | "Thorned hide blunts the blows aimed at the pit." | A | Épines → défensif team (varie l'école : pas un ampli bleed). |
| **bloodletter** | 4 | bleed 2 aggravate ×2 | `grant_team bleedNoExpire` | "While it leads, the pit's wounds never close." | A (flag existant) | Bleed-payoff → transform open_wounds (rang 4). |
| **tendon_render** | 4 | bleed slow scales missing hp | `aura_stat bleedInc team 0.22` | "The pit's cuts sever deeper as prey weakens." | B#1 (repli atkInc team 0.10) | Bleed-control → ampli bleed fort. |
| **vein_splitter** | 3 | bleed 4 fast | `aura_stat atkInc role:front 0.12` | "Your foremost cutter opens two veins at once." | A | « Deux entailles » → empower l'avant (plus de frappes-vecteur). |
| **slow_bleed** | 5 | bleed 2 + slowEnemies (self) | `grant_team slowEnemies 0.12` | "Its presence drags the whole enemy line to a crawl." | A (flag existant) | Apex bleed → MÊME transform que son board (cohérent : c'est SON identité team). |
| **wailing_shade** | 2 | bleed 2 slow | `aura_stat regen team 2` | "The spectre's wail knits the pit's wounds shut." | A | Spectre → soin team (varie : sustain, pas bleed). regen sans cap → valeur petite. |
| **byakhee** | 2 | bleed 3 slow | `aura_stat haste team 0.06` | "Wings beat; the whole pit dives quicker." | A | Ailé piqué → tempo team. |
| **gnaw_rat** | 1 | bleed 1 micro | `aura_stat atkInc tier:1 0.10` | "The pit's chaff bites with sudden teeth." | A | Commune → empower conditionnel tier:1 (couronne la piétaille, rang 1 = restrictif). |
| **clot_mender** | 3 | aura grant_bleed voisins | `aura_stat bleedInc team 0.18` | "Old scars split anew across the whole pit." | B#1 (repli `grant_team bleedNoExpire`) | Aura bleed d'adjacence → généralise. Repli = flag bleed existant (pas atkInc, garde le thème). |

---

### 3.4 AFFLICTEURS DoT — poison (15 unités)
> Poison = l'APEX méta (cf. relics : ampli poison conservateur). On **modère** les amplis poison et on
> **varie** plus que les autres écoles (sinon 15 commandants poison-team = monoculture).

| id | rang | passif | commandBonus | command_desc (EN) | Pool | rationale |
|---|---|---|---|---|---|---|
| **spore_tick** | 1 | poison 1 fast | `aura_stat haste team 0.05` | "Spores drift fast; the whole pit strikes faster." | A | Commune poison-cadence → tempo team (PAS ampli poison : évite de gonfler l'apex). |
| **corruptor** | 3 | poison 2 weaken + grant_vuln | `grant_team markEnemiesVuln 0.12` | "The foe festers; every blow lands a little truer." | **B#2** (repli `aura_stat poisonInc team 0.16`) | Marque-vuln on_hit → généralise la marque à TOUTE l'équipe ennemie au combat_start (son thème). |
| **bile_spitter** | 3 | poison 2 weaken 0.10 | `aura_stat poisonInc team 0.18` | "The pit's venom eats a third deeper." | B#1 (repli atkInc team 0.08) | Poison-malus → ampli poison modéré (conservateur, apex). |
| **rot_grub** | 2 | poison 2 long | `aura_stat regen team 2` | "Slow venom keeps; the pit endures and mends." | A | Poison longue durée → sustain team (varie l'école). |
| **plague_bearer** | 4 | poison 2 spread | `grant_team poisonNoCap` | "While it leads, the pit's venom knows no limit." | A (flag existant) | Contagion → transform poisonNoCap (rang 4). |
| **acid_maw** | 3 | poison 2 shieldEat | `grant_team stripEnemyShield 0.4` | "The pit's acid eats the gilded guard ere it stands." | A (flag existant) | Ronge-bouclier → anti-méta (cohérent thème acide). Plus faible que siege_breaker (0.4 vs 0.5). |
| **festering** | 5 | poison + poisonNoCap (self team) | `grant_team plagueAmp 0.25` | "Two plagues at once, and both fester worse." | A (flag existant) | Apex poison → transform croisé (différent de son poisonNoCap de board). |
| **venom_censer** | 5 | poison igniteAt 5 → burn | `aura_stat poisonInc team 0.22` | "The censer's reek deepens every venom in the pit." | B#1 (repli `grant_team poisonDurBonus 60`) | Poison→feu apex → ampli poison fort. Repli = durée poison (flag existant). |
| **chitin_drone** | 2 | poison 2 | `aura_stat atkInc team 0.07` | "The hive strikes as one barbed will." | A | Insecte ruche → empower team (varie). |
| **coil_viper** | 2 | poison 3 + 2nd plaie if absent | `grant_team markEnemiesVuln 0.10` | "Twin fangs leave the foe open to every strike." | **B#2** (repli `aura_stat poisonInc team 0.14`) | « Frappe deux fois la chair saine » → ouvre l'ennemi (vuln team). |
| **web_recluse** | 2 | poison 2 long | `aura_stat dmgReduce team 0.06` | "Webbed shadows blunt the blows aimed at the pit." | A | Arachnide embuscade → défensif team (varie). |
| **ink_horror** | 2 | poison 3 | `aura_stat poisonInc team 0.16` | "Abyssal ink curdles every venom darker." | B#1 (repli atkInc team 0.07) | Encre toxique → ampli poison modéré. |
| **deep_kraken** | 5 | *(déjà commandant)* | — | — | — | — |
| **miasma_acolyte** | 3 | aura poison dps voisins | `aura_stat poisonInc team 0.18` | "The miasma spreads; all the pit's venom bites deeper." | B#1 (repli atkInc team 0.08) | Aura poison d'adjacence → généralise. |
| **rot_hound** | 2 | rot *(voir 3.5 — rot, pas poison)* | — | *(classé pourriture)* | — | — |

---

### 3.5 AFFLICTEURS DoT — rot/pourriture (12 unités)
| id | rang | passif | commandBonus | command_desc (EN) | Pool | rationale |
|---|---|---|---|---|---|---|
| **rot_hound** | 2 | rot base2 growth2 | `aura_stat rotInc team 0.18` | "The pit's rot swells and gnaws a third faster." | B#1 (repli atkInc team 0.07) | Rot standard → ampli rot école. |
| **carrion_pecker** | 1 | rot fast + heal_on_kill | `aura_stat lifesteal team 0.05` | "The pit feeds on its kills, drop by drop." | A | Charognard sustain → vol de vie team (cohérent : se repaît). |
| **maggot_king** | 3 | *(déjà commandant)* | — | — | — | — |
| **necro_leech** | 3 | rot maxHpFrac 0.35 | `aura_stat rotInc team 0.20` | "Flesh sloughs faster wherever the pit treads." | B#1 (repli atkInc team 0.08) | Amputation forte → ampli rot. |
| **patient_worm** | 4 | rot passiveRamp | `aura_stat rotInc team 0.22` | "The pit's rot ripens even where no blow has struck." | B#1 (repli `grant_team rotEnemies`) | Rot-patient → ampli rot fort. Repli = rot team ennemie. |
| **hollow_gut** | 4 | rot amputateHealsMe | `aura_stat lifesteal team 0.06` | "What the pit's rot devours, the pit drinks." | A | Vol de plafond → lifesteal team (cohérent). |
| **blight_spreader** | 4 | rot + spread on death | `grant_team rotEnemies {base1 dur300}` | "Its presence alone rots the enemy line." | A (flag existant) | Propagateur rot → rot team ennemie (cohérent). |
| **marrow_drinker** | 5 | convert bleed→rot | `aura_stat rotInc team 0.22` | "Marrow turns to rot across the whole pit's wake." | B#1 (repli atkInc team 0.10) | Apex rot-croisé → ampli rot fort. |
| **pit_maw** | 5 | rot + rotEnemies (self team) | `grant_team rotEnemies {base1 dur360 capDps8}` | "The Pit itself opens; the enemy line rots where it stands." | A (flag existant, valeur ↑) | Apex rot → MÊME transform que son board, plus fort (c'est SON identité-signature). |
| **wither_bloom** | 5 | rot + slow + weaken | `aura_stat statInc tier:1 0.30` | "Lesser things bloom monstrous in the wither's reach." | A | Apex usure → conditionnel fort tier:1 (varie : pas un 3e ampli rot). |
| **bore_worm** | 2 | rot base2 growth2 | `aura_stat haste team 0.06` | "The borer digs quick; the whole pit follows." | A | Foreur → tempo team (varie). |
| **decay_tender** | 3 | aura rot growth voisins | `aura_stat rotInc team 0.18` | "Decay quickens; the pit's rot swells the faster." | B#1 (repli atkInc team 0.08) | Aura rot d'adjacence → généralise. |

---

### 3.6 AFFLICTEURS DoT — shock/choc (11 unités)
| id | rang | passif | commandBonus | command_desc (EN) | Pool | rationale |
|---|---|---|---|---|---|---|
| **stormcaller** | 2 | shock + grant_vuln | `grant_team markEnemiesVuln 0.10` | "Where the storm looks, the next blow strikes true." | **B#2** (repli `aura_stat haste team 0.06`) | Marque-vuln on_hit → généralise (son thème « là où il regarde, ça frappe »). |
| **live_wire** | 1 | shock fast cap5 | `aura_stat haste team 0.05` | "Live current quickens every twitch in the pit." | A | Commune choc-cadence → tempo team. |
| **thunderhead** | 2 | shock volt6 burst | `aura_stat atkInc role:back 0.14` | "Your rearmost thing strikes with thunder's weight." | A | Carry burst arrière → empower role:back (le DPS protégé). |
| **static_swarm** | 2 | shock cap8 long | `aura_stat regen team 2` | "A steady charge hums through the pit, mending." | A | Choqueur patient → sustain team (combats longs). |
| **galvanizer** | 4 | *(déjà commandant)* | — | — | — | — |
| **stormlord** | 3 | shock add2 volt4 cap8 | `grant_team shockChain 1` | "The storm's mark leaps from foe to foe." | A (flag existant) | Marque une proie → transform forked_tongue (le choc rebondit). |
| **dynamo_priest** | 4 | shock transfer 0.5 | `grant_team shockChain 1` | "Its current arcs across the enemy line." | A (flag existant) | Transfer → chaîne choc team. |
| **arc_warden** | 4 | shock chain 2 | `aura_stat atkInc team 0.08` | "The arc-warden goads the whole pit to strike harder." | A | Déjà chain → varie : empower team (pas un 2e shockChain). |
| **storm_anchor** | 3 | shock persist 0.5 | `aura_stat dmgReduce team 0.06` | "The anchor grounds the pit; blows glance aside." | A | Pression continue → défensif team (varie). |
| **siphon_jelly** | 2 | shock cap5 | `aura_stat lifesteal team 0.05` | "The jelly drinks the spark of every wound." | A | Méduse urticante → lifesteal team (varie). |
| **rust_sentinel** | 4 | shock + bruiser-tank | `aura_stat dmgReduce team 0.08` | "Iron hide turns the pit's wounds aside." | A | Automate tank → défensif team. |

---

### 3.7 TANKS / BOUCLIERS / défensifs (no-DoT, ~14 unités)
> École **défensive** : varier dmgReduce team / regen team / armure de ligne / shield-flavor. NE PAS
> tous les faire « dmgReduce team » (sinon monoculture défensive + risque de gate, cf. tide_caller à 100%).

| id | rang | passif | commandBonus | command_desc (EN) | Pool | rationale |
|---|---|---|---|---|---|---|
| **templar** | 3 | *(classé 3.1 vanille)* | `aura_stat dmgReduce team 0.08` | *(voir 3.1)* | A | — |
| **gravewarden** | 4 | taunt + thorns 4 | `aura_stat dmgReduce role:front 0.20` | "Your foremost wall shrugs off the heaviest blows." | A | Tank-taunt → armure FORTE sur l'avant (1 cible, donc magnitude haute sûre). |
| **shieldbearer** | 2 | shield_aura 6 | `aura_stat dmgReduce team 0.06` | "Shields locked; the pit takes the blow as one." | A | Porte-bouclier → défensif team léger. |
| **aegis_warden** | 4 | shield_aura 10 + taunt + thorns | `aura_stat dmgReduce team 0.08` | "Aegis raised over all; the pit endures." | A | Mur complet → défensif team. |
| **oath_keeper** | 4 | shield_aura 18 | `aura_stat regen team 3` | "The oath sustains; the pit's wounds slowly close." | A | Pilier offensif-défensif → sustain team (varie du dmgReduce). |
| **bulwark_acolyte** | 3 | shield_aura 8 | `aura_stat dmgReduce team 0.06` | "Warded flesh blunts every blow across the pit." | A | Support bouclier → défensif team. |
| **ward_weaver** | 4 | shield_caster périodique | `aura_stat regen team 3` | "Woven wards mend the pit, breath by breath." | A | Caster périodique → sustain team (cohérent : entretien). |
| **barrier_savant** | 4 | aura_shield valueInc/cdr | `aura_stat dmgReduce team 0.08` | "Barriers thicken over all who follow." | A | Renfort bouclier → défensif team. |
| **mirror_ward** | 4 | aura_shield reflect | `aura_stat dmgReduce team 0.08` | "The mirror turns blows back upon the pit's foes." | A | Réflexion → défensif team (thème reflect). |
| **surge_warden** | 4 | aura_shield overcharge | `aura_stat dmgReduce team 0.08` | "Surging wards swell to guard the whole pit." | A | Surcharge → défensif team. |
| **siege_breaker** | 3 | *(déjà commandant)* | — | — | — | — |
| **runestone_golem** | 4 | shield_aura 12 | `aura_stat dmgReduce team 0.08` | "Runed stone wards the pit from harm." | A | Golem-support → défensif team. |
| **gravewarden** | *(ci-dessus)* | — | — | — | — | — |

---

### 3.8 BRUTES / stat-sticks / divers (no-DoT offensif, ~8 unités)
| id | rang | passif | commandBonus | command_desc (EN) | Pool | rationale |
|---|---|---|---|---|---|---|
| **marauder** | 1 | *(classé 3.1)* | `aura_stat atkInc role:front 0.12` | *(voir 3.1)* | A | — |
| **bandit** | 1 | *(classé 3.1)* | `aura_stat haste team 0.05` | *(voir 3.1)* | A | — |
| **skeleton** | 1 | *(classé 3.1)* | `aura_stat dmgReduce team 0.05` | *(voir 3.1)* | A | — |
| **plague_doctor** | 3 | regen + purge poison | `aura_stat regen team 3` | "The doctor's craft mends the whole pit." | A | Contre-DoT/soin → sustain team (cohérent : régénération). |
| **zeal_inquisitor** | 2 | *(classé 3.2 burn)* | `aura_stat atkInc team 0.07` | *(voir 3.2)* | A | — |
| **husk** | 1 | — (stat-stick) | `aura_stat dmgReduce team 0.04` | "Dead weight soaks a little of every blow." | A | Stat-stick → défaut défensif rang 1 (le plus faible). |
| **footman** | 1 | — (stat-stick) | `aura_stat atkInc tier:1 0.10` | "The rank-and-file find their nerve together." | A | Stat-stick → empower conditionnel tier:1 (couronne la piétaille). |
| **mire_thing** | 1 | — (stat-stick) | `aura_stat regen team 1` | "The mire seeps; the pit's wounds slowly fill." | A | Stat-stick → micro-sustain team (le plus faible). |
| **runestone_golem** | 4 | *(classé 3.7)* | — | — | — | — |

---

## 4. NOTES D'ÉQUILIBRAGE — distribution finale & risques

### 4.1 Distribution par STAT (84 unités, ~78 nouvelles + 6 existantes)
| Stat / mécanique | Nb total | dont team | dont conditionnel/role | Pool |
|---|---|---|---|---|
| `haste` | ~10 | ~10 | 0 | A |
| `atkInc` | ~13 | ~7 team / ~4 role / ~2 tier | mix | A |
| `dmgReduce` | ~13 | ~11 team / ~2 role:front | mix | A |
| `lifesteal` | ~6 | ~6 | 0 | A |
| `regen` | ~8 | ~8 | 0 | A |
| `statInc` | ~6 | 0 | ~4 tier:1 / ~2 level:1 | A |
| `multicast` | ~2 | 0 | ~2 role:front | A |
| `poisonInc` | ~7 | ~7 | 0 | **B#1** |
| `burnInc` | ~5 | ~5 | 0 | **B#1** |
| `bleedInc` | ~5 | ~5 | 0 | **B#1** |
| `rotInc` | ~6 | ~6 | 0 | **B#1** |
| `markEnemiesVuln` | ~3 | (ennemis) | — | **B#2** |
| `grant_team` (transforms) | ~12 | — | — | A (flags existants) |
| `focusWith` | 0 | — | — | (réservé, non utilisé v1) |

> **Distribution saine** : aucune stat ne dépasse ~13/84 (15%). Le plus gros bloc (`dmgReduce`/`atkInc`)
> est dilué entre team-faible et role/tier-conditionnel. **Les amplis d'école** (poison/burn/bleed/rot Inc =
> ~23 unités) sont tous **Pool B#1** : si on ne fait pas le trou, ils replient sur `atkInc team`/flags →
> la distribution `atkInc` gonfle mais reste bornée par `ATK_INC_CAP`.

### 4.2 Les 3 risques d'équilibrage MAJEURS à surveiller en sim (par priorité)

**RISQUE #1 — Les stats SANS cap moteur (`haste`, `dmgReduce`, `lifesteal`, `regen`) qui s'empilent
aura-commandant + relique + aura-d'adjacence.**
- `haste` : commandant (bellows_priest/bandit/cinder_cur…) `+0.05-0.08` **×** relique `whetstone +0.15`
  **×** aura `bellows_priest +0.12` → cadence plancher. **Aucun cap à la lecture** (`arena.lua` timer
  `*(1-haste)`). **À tester** : TTK p10, vérifier que le timer ne devient pas ≤0 (un `haste≥1.0` cumulé
  = swing instantané = boucle). **Garde-fou suggéré** : ajouter un `HASTE_CAP=0.40` à la lecture
  (`arena.lua` timer), miroir de `ATK_INC_CAP`. **PRIORITÉ : c'est le seul risque de NON-TERMINAISON.**
- `dmgReduce` : commandant team `+0.06-0.08` **+** `aegis +0.15` **+** `tide_caller +0.04` **+** templar
  aura `+0.12` → `damage()` cause=attack peut tomber vers 0 (mur infranchissable = gate, le scénario
  `tide_caller TANK 100%` déjà observé en relicsim). **Garde-fou suggéré** : `DMG_REDUCE_CAP=0.60` à la
  lecture. **À tester** : matchup all-tank, win% ≤ +2σ.
- `lifesteal`/`regen` : sustain ingérable vs builds sans pénétration de soin. **Contré** par
  rot/`pierceHeal`/`hollow_choir` (existants). **À tester** : combats non-conclus (fuzz props.lua).

**RISQUE #2 — Le combo multicast × afflicteur × ampli (le snowball historique F11), maintenant avec
3 sources possibles.**
- `maggot_king`/`hookjaw` commandant (multicast role:front) **×** `echo_crown` relique (multicast
  role:front) **×** `hookjaw` unité (multicast role:front) = 3 sources → mais `MULTICAST_MAX=3` cappe la
  somme (1+1+1=3). Si l'unité avant est un afflicteur (corruptor) **×** aura ampli (miasma_acolyte) **×**
  commandant ampli-école (B#1 poisonInc team) → double pose ×3 amplifiée. **Garde-fous** :
  `POISON_STACK_CAP=8`, `WEAKEN_CAP=0.40`, `DOT_CAP_MULT=3`, `HIT_DMG_CAP_MULT=7` (chaque sous-coup borné).
  **À tester EN PREMIER** (priorité #1 de commanders-plan §6.3) : `relicsim` Couronne+echo_crown+hookjaw +
  commandant poisonInc team vs poison-tank → **lift < 1,6**, TTK p10 stable. **Le trou #1 (poisonInc team)
  AUGMENTE ce risque** → simuler avant de l'ouvrir.

**RISQUE #3 — La convergence d'archétype (méta forcée) si une stat/portée domine le pool.**
- Avec ~13 `dmgReduce` et ~23 amplis d'école, le risque est qu'**un** archétype de commandant (ex.
  « mono-poison + venom_censer commandant ») soit strictement supérieur → tout le monde le prend (leçon
  TFT Legends, brainstorm §13). **Garde-fou de design** : (a) les amplis d'école sont **gatés par
  possession** (il faut drafter l'unité-hôte) ; (b) **diversité = entropie des archétypes gagnants ≥ 0,90**
  en sim (la sim sort ~0,99) ; (c) si un commandant *force* un archétype → **nerf de PORTÉE** (team→conditionnel)
  ou de magnitude, **jamais** un buff d'accès. **À tester** : matrice `tools/sim.lua` des 84 commandants ×
  bandes EARLY/MID/END → aucun ne dévie >2σ en « présence côté gagnant ».

### 4.3 Pourquoi le rollout-à-tout-le-roster RESTE borné (l'argument)
1. **Un seul slot piédestal** → une seule aura de commandement active par combat. Les 84 auras ne
   s'additionnent jamais entre elles ; elles **remplacent** le choix unique du joueur. Le pool de 84 est
   un **menu**, pas une somme.
2. **Gating par possession** (boutique) : une aura forte (apex transform) exige d'avoir drafté une
   légendaire → rare, et payé par le slot piédestal (l'unité perd l'adjacence du board, trade-off fondateur).
3. **Corps nerfé** (`COMMANDER_CD_MULT=1.5`) : le commandant n'ajoute QUE son aura + un DPS lent ; il ne
   soak rien (intouchable, hors board). Le board ennemi meurt au même rythme.
4. **Couche `increased` additive sur la BASE** + **caps à la lecture** : même le pire cumul
   (aura+relique+adjacence) est borné par axe (`ATK_INC_CAP`/`MULTICAST_MAX`/`DOT_CAP_MULT`/`STAT_INC_CAP`),
   sauf les 4 stats sans cap → **RISQUE #1, à capper avant le rollout** (recommandation ferme).
5. **Golden-safe** : `commandBonus` est `combat_start`, lu **uniquement** quand une unité est au piédestal
   au build → aucune sim golden (qui ne pose pas de commandant) ne bouge.

### 4.4 Recommandation FERME avant rollout
**Ajouter 2 caps de lecture manquants** (`arena.lua`, ~2 lignes chacun, golden-safe car nil/petit reste
sous le cap) **AVANT** d'ouvrir les ~30 commandants qui posent haste/dmgReduce :
- `HASTE_CAP = 0.40` (timer d'attaque) — **anti-non-terminaison** (priorité absolue).
- `DMG_REDUCE_CAP = 0.60` (`damage()` cause=attack) — anti-gate all-tank.
Ces caps **n'apparaissent dans aucun fichier** (vérifié : `haste`/`dmgReduce` sont lus sans `math.min`).
C'est la **dette moteur n°1** que ce rollout révèle.

---

## 5. VAGUES D'IMPLÉMENTATION (déploiement incrémental + testable)

> Convention git-warden : brancher chaque vague depuis `dev`, commit quand `tools/check.sh` vert.
> Chaque vague est **golden-neutre** (data/i18n hors scénario golden ; trous gated). On déploie par
> **complexité croissante** : Pool A (zéro code) d'abord, puis les trous.

| Vague | Contenu | Fichiers | Pré-requis |
|---|---|---|---|
| **V0 — caps manquants (dette révélée)** | `HASTE_CAP=0.40` + `DMG_REDUCE_CAP=0.60` à la lecture. Test props.lua (terminaison sous haste cumulé max). | `src/combat/arena.lua` | — |
| **V1 — Pool A : défensifs + sustain + tempo** | ~30 `commandBonus` (dmgReduce/regen/haste/lifesteal team) + i18n. Tanks, boucliers, stat-sticks, choqueurs sustain. **Zéro code moteur.** | `src/data/units.lua`, `src/i18n/en.lua` | V0 |
| **V2 — Pool A : empower + conditionnels + role** | ~20 `commandBonus` (atkInc team/role, statInc tier:1/level:1, multicast role:front) + i18n. | `src/data/units.lua`, `src/i18n/en.lua` | V1 |
| **V3 — Pool A : transforms (grant_team existants)** | ~12 `commandBonus` grant_team (burnNoDecay/poisonNoCap/slowEnemies/rotEnemies/bleedNoExpire/shockChain/plagueAmp/stripEnemyShield) sur les rangs 4-5 + i18n. | `src/data/units.lua`, `src/i18n/en.lua` | V1 |
| **V4 — TROU #1 : amplis d'école en aura_stat** | Étendre `STAT_FIELDS` (+poisonInc/burnInc/bleedInc/rotInc) + routage `bakeAuraStat`→buffers existants ; basculer les ~23 unités B#1 de leur repli vers leur ampli d'école ; tests auras.lua. | `src/scenes/build.lua` (+`relics.lua`) | V1-V3 |
| **V5 — TROU #2 : marque de vuln team** | Flag `markEnemiesVuln` (ops.lua grant_team) + lecture arena:spawn (ennemis, cappé VULN_INC_CAP) ; basculer corruptor/coil_viper/stormcaller ; tests synergies.lua. | `src/effects/ops.lua`, `src/combat/arena.lua` | V3 |
| **V6 — sim & équilibrage** | Matrice 84 commandants × bandes × reliques ; balayer RISQUE #2 (multicast×afflicteur×poisonInc-team) EN PREMIER ; props.lua commandant-vs-commandant ; tuner un levier à la fois. | `tools/sim.lua`, `tools/runsim.lua`, `tests/props.lua` | V1-V5 |
| **V7 — (optionnel) TROU #3 flags d'école** | `shockDischargeBonus`/`burnSpreadOnDeath` si la sim montre un manque d'identité apex ; sinon SKIP. | `src/effects/ops.lua`, `src/combat/arena.lua` | V6 |

> **Après V1-V3 (zéro/quasi-zéro code), AUCUNE unité n'affiche plus « Cannot command »** — l'objectif de
> l'user est atteint avec de la data pure (les replis Pool A couvrent les ~23 unités B#1). V4-V5 ne font
> qu'**enrichir** la diversité (remplacer un repli générique par l'ampli d'école thématique). V0 est la
> **garde de sécurité** (à faire avant tout, indépendant des commandants).

---

## 6. POINTS D'ATTENTION POUR L'IMPLÉMENTEUR

1. **`command_desc` = `[[feedback-concrete-values-over-percentages]]`** : préférer le langage concret.
   Pour les stats qui SONT un % moteur (haste/atkInc/dmgReduce/lifesteal), formuler en image (« strikes
   faster », « heals for a sliver », « shrugs off the heaviest blows ») plutôt qu'un chiffre fragile.
   Pour statInc/afflictions/écho : valeurs concrètes OK. **Aligner le chiffre du desc sur la `value` data**
   au moment de l'écriture (la dette galvanizer/deep_kraken « +50%/+40% vs 0.14/0.15 » NE DOIT PAS se
   reproduire — soit pas de chiffre, soit chiffre exact).
2. **`command_name` + `command_flavor`** : la carte n'affiche que `command_desc` (`monstercard.lua:241`),
   mais le système prévoit `command_name`/`command_flavor` (cf. les 6 existantes, en place). **Rédiger les
   3 clés** par unité (cohérence + usage UI futur : étiquette de portée au survol du piédestal, plan §4.1).
3. **Anti-doublon de cible role:front multicast** : `maggot_king` ET `hookjaw` portent la même aura
   multicast role:front. C'est **voulu** (2 accès au levier, MULTICAST_MAX=3 borne). Ne pas « dédupliquer ».
4. **Les amplis d'école (B#1) ne touchent PAS le DoT du commandant lui-même** : ils ciblent `team` =
   le board (le commandant est hors `placed`). Cohérent (il commande, il ne se buffe pas).
5. **`grant_team` valeurs sur pit_maw/blight_spreader/acid_maw** : ce sont des **tables** de params
   (`rotEnemies={base,dur,capDps}`, `stripEnemyShield=frac`), pas des booléens. Respecter la forme lue par
   `ops.lua:278-298`. Vérifier que le `commandBonus grant_team` table est bien fusionné dans les effects du
   commandant (`build.lua:1272` fait `cEff[#cEff+1]=cb` → OK, l'arène le pose).
6. **Le piédestal/slot/run-grant** (`commandBonus` injecté seulement au piédestal) est **déjà spécifié**
   dans `commanders-plan.md §3` — ce doc ne le re-spécifie pas. Ce doc ne traite QUE le contenu des 78
   auras + les trous qu'elles révèlent.

---

## 7. RÉCAP EXÉCUTIF

- **Objectif atteignable en data pure** (V1-V3) : les replis Pool A couvrent 100% du roster → **zéro
  « Cannot command »** sans toucher le moteur (hors V0).
- **2 trous moteur** enrichissent la diversité (V4 amplis d'école, V5 marque vuln) — chacun ~6-10 lignes,
  gated, golden-safe, avec repli.
- **1 dette moteur révélée (V0, à faire d'abord)** : `haste`/`dmgReduce` n'ont **aucun cap de lecture** →
  ajouter `HASTE_CAP=0.40` (anti-non-terminaison) + `DMG_REDUCE_CAP=0.60` (anti-gate).
- **Distribution saine** : aucune stat >15% du pool ; un seul slot → les 84 auras sont un menu, pas une
  somme ; caps + couche increased + corps nerfé bornent le power-creep.
- **3 risques sim** : (#1) stacking des stats sans cap [terminaison] ; (#2) multicast×afflicteur×ampli
  [snowball, tester en premier] ; (#3) convergence d'archétype [méta forcée, nerf de portée].
