# 00 — État des lieux ANCRÉ de *The Pit*

> **Rôle de ce document.** Référence canonique du roadmap-lab : l'état du jeu (mécaniques,
> contenu, économie, async) + ce qui est **DÉCIDÉ** + les **INVARIANTS** que **tout round
> doit respecter**. Ce n'est pas un re-dump des seeds : c'est le filtre contre lequel chaque
> proposition se vérifie. En cas de doute, **ce fichier prime sur la mémoire** ; les chiffres
> ici sont **lus dans le code** (session 2026-06-23), pas re-dérivés.
>
> **Sources des trois seeds** (à lire en entier avant d'argumenter) :
> [`seed/mechanics.md`](seed/mechanics.md) (inventaire code), [`seed/decisions.md`](seed/decisions.md)
> (décisions verrouillées + pourquoi + URLs), [`seed/tests.md`](seed/tests.md) (garanties de test).
> **Recherche primaire** : `docs/research/{gd-research-result, combat-model-decision,
> relics-design, effects-dot-families, progression-economy-prd, engine-architecture,
> autobattler-design, payoff-framework, effects-amplification-modifiers,
> effects-balance-counterplay, effects-synergy-tiers, balance-sim-design, love2d-tech}.md`.
>
> **Règle d'or (CLAUDE.md §1)** : ne jamais affirmer une API/un chiffre depuis la mémoire.
> Toute affirmation de design **cite une source** (URL de jeu/article/recherche, ou fichier+ligne).

---

## 0. TL;DR — la barre que tout round doit franchir

Une proposition est recevable **seulement si** :

1. Elle **respecte les 10 décisions définitives** (§1) et **ne viole aucun des 32 invariants
   de test** (§6). Sinon : signaler explicitement le conflit + proposer le changement de test
   AVANT le code (les tests ne se rebaselinent jamais en silence — `seed/tests.md` §2, §6).
2. Elle **survit aux 4 piliers** (§1.1) : async par snapshots / sim déterministe seedée / DA
   grimdark / pixel art 100 % procédural. Une idée qui casse un pilier = **drapeau rouge**.
3. Pour la **concurrence** : verdict de transférabilité **mécaniste** (teardown → psycho →
   maths → verdict), jamais l'analogie « X fait ça, copions » (BRIEF.md §Analyse concurrentielle).
4. Elle **cite ses sources**. Pas de chiffre de cotes/courbe sans URL.

**Boussole de design** (CLAUDE.md §2, gd-research-result.md §2.6) : *simplicité de gestion →
profondeur émergente* (réf SAP/Batomon) ; reliques **lisibles** (StS) ; **égalisateurs, pas de
gates** ; petits nombres. Tout ce qui alourdit la gestion sans payoff de profondeur est suspect.

---

## 1. Les 10 décisions DÉFINITIVES (ne jamais re-débattre)

> Source : `seed/decisions.md` §7. Un round peut **étendre** (contenu, valeurs, UX) mais **pas
> renverser** ces axes. Les renverser = sortir du mandat du lab.

| # | Décision | Pourquoi (source) |
|---|----------|-------------------|
| 1 | **Asynchrone par snapshots** — jamais de PvP temps réel | takeaway archi #1 ; SAP Wikipedia « battle against … AI-generated teams if there are no players » (en.wikipedia.org/wiki/Super_Auto_Pets) ; solo-dev (consensus forums LÖVE) |
| 2 | **Sim déterministe seedée** — firewall SIM/RENDER inviolable ; RNG injecté, jamais `math.random` global | condition nécessaire des snapshots/replays/golden (engine-architecture.md) |
| 3 | **DA grimdark + pixel art 100 % procédural** — zéro asset dessiné | différenciateur ; leçon Balatro/LocalThunk : le thème structure tout (gd-research-result.md §2.6) |
| 4 | **Plateau-graphe 3×3, arêtes explicites, 5 sigils** — ni rangée linéaire, ni Tetris/Backpack | la forme EST le graphe de synergies ; diagonales tuent le puzzle (gd-research-result.md §1.3) |
| 5 | **Vie PAR ENTITÉ** (mort par-combat, build persiste) — vie globale rejetée | fiction grimdark + axe d'exposition front/back = signature (combat-model-decision.md §1-2) |
| 6 | **Ciblage 100 % déterministe** : colonne → taunt → aggro → tie-break haut→bas. Zéro dé | « le dé m'a niqué » → « j'aurais dû counter-placer » (yomi) ; async-vérifiable (combat-model-decision.md §4-6) |
| 7 | **Reliques LISIBLES** (pivot 2026-06) — leurres/identification **retirés** | user : « pas fan des leurres, trop compliqué pour pas grand-chose » ; réf StS (relics-design.md §1) |
| 8 | **4 familles DoT à axes de stacking distincts** — jamais une 5e par analogie sans valider l'axe (source primaire) | 1 axe/famille = identité sans règle neuve (PoE/Last Epoch/D4, effects-dot-families.md §B) |
| 9 | **Économie XP TFT-style** (passive + achetable) — boutique payée HS **rejetée au playtest** | « payer pour monter » = piège (progression-economy-prd.md §3) ; TFT XP (blitz.gg/tft/guides/gold) |
| 10 | **`cost = rank`** — le prix EST le rang ; la complexité vit dans les hauts rangs | New World Order (gamedeveloper.com) ; re-tier Riot Dragonlands (progression-economy-prd.md §4) |

### 1.1 Les 4 piliers (filtre dur)

- **Async snapshots** : on stocke des builds figés (unités + positions + sigil) servis selon
  *progression/rang/version* ; cold-start par IA. Toute mécanique exigeant du live = **hors-budget**.
- **Sim déterministe seedée** : pas de RNG en combat sauf `condition={kind="chance"}` via le RNG
  injecté. Couche SIM (`src/combat`, `src/board`, `src/effects`, `src/run`) **sans `love.*`**.
- **DA grimdark cryptique** : Cthulhu × PoE × Dark Souls. Sale, sanglant.
- **Pixel art procédural** : grilles + palette, bake une fois (`nearest`), zéro draw pixel/frame.

---

## 2. État du contenu (lu dans le code, 2026-06-23)

> Source : `src/data/units.lua`, `src/data/relics.lua`, `src/board/shapes.lua`, `src/gen/`.
> **[PH]** = valeur explicitement marquée `PLACEHOLDER` dans le code (à tuner via `tools/sim.lua`).

### 2.1 Roster — **83 unités** (`U.order` = `U.pool`, `units.lua:453/488`)

`cost = rank`. Répartition par rang (re-tier « complexité dans les hauts rangs » — décision §10) :

| Rang | Coût | Nb | Profil cible (progression-economy-prd.md §4) |
|------|------|----|--------------------------------------------|
| 1 | 1 | **12** | stat-sticks : tape, ou tape + micro-statut (1 dps). Zéro op neuf |
| 2 | 2 | **23** | enabler mono-DoT simple (1 affliction, pas de twist) |
| 3 | 3 | **18** | enabler + 1 petit modificateur |
| 4 | 4 | **20** | twists T2, auras, tanks, choc avancé |
| 5 | 5 | **10** | transforms T3 / règles d'équipe |

**Par affliction/archétype** (seed/mechanics.md §1.2) : burn ~13, bleed ~13, poison ~15, rot ~11,
choc **11**, bouclier-aura 6, bouclier périodique 5, tank/taunt 5, bruiser 3, épines 4, regen **1**,
stat-sticks purs 4.

**Diagnostic d'équilibrage existant** (the-pit-balance-diagnosis, mémoire) : hiérarchie
**poison > tank > … > choc** ; courbe inversée ; variance early. À traiter, pas à re-découvrir.

### 2.2 Reliques — **21 entrées** (`relics.lua`, 21 ids confirmés)

Modèle **lisible** : nom + effet clair (avec chiffre) + flavor. Offre **1-parmi-3 tous les 3
combats** (victoire OU défaite). Tiers gatés par avancée : early(0-1 win)→≤2, mid(2-4)→≤3,
late(5+)→≤4. Decline → **+3 or** (`DECLINE_RELIC_GOLD`). Tirage Fisher-Yates seedé. Pas de doublon.

Taxonomie (vagues 1-4 livrées) : **A** stats plates (4) · **B** amplis d'affliction (4) ·
**C** paliers/payoffs (3) · **D** défensives (3) · **E** transformatives (4) · **F** reliques de
boutique `runOp` (3 : carrion_ledger/black_summons/beggars_lantern). **G — topologie/sigils =
DIFFÉRÉ** (le plus signature ET le plus cher ; chantier dédié, relics-design.md §4).
Toutes les valeurs sont **[PH]** (table complète : seed/mechanics.md §7).

### 2.3 Plateau — **5 sigils, 9 slots constants** (`shapes.lua` : carre/croix/anneau/diamant/ligne)

`Shapes.order = {carre, croix, anneau, diamant, ligne}`. Adjacence **orthogonale** (data, arêtes
explicites). Changer de sigil = **échanger une topologie, jamais de la puissance**. 1 forme = 1
archétype qui l'adore (ne pas égaliser les arêtes). `depth = maxCol - cell.x` (l'exposition est
portée par le sigil). Bascule `[s]` en build.

| Sigil | Archétype servi |
|-------|-----------------|
| carré | équilibre générique (centre = 4 voisins = carry) |
| croix | mono-carry extrême (noyau + branches isolées) |
| anneau | chaîne / propagation en boucle |
| diamant | go-wide / essaim |
| ligne | conduit front→back |

### 2.4 Génération procédurale — **primgen v3** (`src/gen/primgen.lua`)

16 archétypes exclusifs / 5 familles (palette + passe `treat`), vrais squelettes, anatomie ancrée,
seed FNV-1a 32 bits sur l'`id` → même unité = même créature partout (déterminisme snapshot).
6 unités vanille au rig dessiné main (`creatures.lua`). **6e famille « Ordre » en attente.**

---

## 3. Moteur de combat & d'effets (état SIM)

> Source : `src/combat/arena.lua`, `src/effects/{ops,engine,stats}.lua`, `src/core/bus.lua`.

- **Effet = donnée** `{trigger, op, params, condition?, target?}`. Triggers : `on_attack`,
  `on_hit`, `on_attacked`, `on_death` (broadcast **différé**), `combat_start`. Ajouter un
  effet/relique = +1 op + 1 ligne de data, **jamais** éditer la boucle (ouvert/fermé).
- **`teamFlags`** posés par `grant_team` à `combat_start` (burnNoDecay, poisonNoCap, bleedNoExpire,
  shockChain, pierceHeal, plagueAmp…) = modifier des règles d'équipe sans toucher la boucle.
- **Ordre de tick fixe** : burn → bleed → poison → rot → choc → regen. Accumulation **entière**
  (golden-safe). Stacks poison = array `ipairs`.
- **Couche modificateurs** (`stats.lua`) : `(base + Σflat)(1 + Σincreased)·Π(1+more)`. `increased`
  additif → commutatif → **déterminisme sans tri**. `mods=nil` → `base` (golden inchangé).
- **Cap payoff global ×3 par axe** : `DOT_CAP_MULT = 3` (`ops.lua:22`) — anti-snowball.
  `BLEED_DPS_CAP = 12` (`ops.lua:28`), `SHOCK_STACK_CAP = 8` (`arena.lua:31`).

### 3.1 Les 6 familles d'effets (axes distincts — décision §8)

| Famille | Axe de stacking | Signature | Ignore bouclier | Source primaire |
|---------|-----------------|-----------|-----------------|-----------------|
| **Burn** | intensité + décroissance | décroît auto (30 %/s) ; propage aux voisins à la mort | **Non** (le feu attaque l'enveloppe) | poewiki.net/wiki/Ignite |
| **Bleed** | intensité + conditionnel (cumul par source) | ralentit la cadence ; burst au swing (aggravate) | Oui | poewiki.net/wiki/Bleeding |
| **Poison** | nombre (N stacks indép., cap 8) | malus sur la **valeur** des capacités (weaken) | Oui | poewiki.net/wiki/Poison + lastepochtools.com |
| **Rot** | durée / accumulation | dps croît ; **ampute les PV max** | Oui | D4 DoT inversé (ezg.com) |
| **Choc** | condensateur (cap 8) | **0 dégât à la pose** ; décharge au prochain coup, ignore bouclier | Oui (à la décharge) | seed/mechanics.md §2.6 |
| **Regen** | soin/tick | contre-DoT | — | unique : plague_doctor |

- **Auras** = build-résolues (graphe du sigil, bakées à `combat_start` ; ex. `shield_aura`,
  `*_inc`). **Propagation en combat** (contagion / mort) = proximité du **champ de bataille**
  (`Arena:neighborsOf`), pour garder l'arène SIM autonome. Décision d'archi actée (CLAUDE.md §7).
- **Boucliers** : `shield_aura` (build, 6 porteurs) + `shield_caster` (périodique, 5) + counters
  (`strip_shield`). Renforts cappés (the-pit-payoff-framework, mémoire).
- **Duplicatas** : 3 copies (même id+niveau) → niveau+1 (cap 3, **cascade**). `LEVEL_MULT =
  {1.0, 1.8, 3.0}`. Niveau 1 = identité (golden-safe). Stats ET auras scalent.

### 3.2 Boucle de combat

Pas de temps fixe (`love.run` surchargée, accumulateur). Par tick : `tickDots` → cooldown→0 =
choisir/reconfirmer cible + frapper (`on_attack` → `damage` → `on_hit` → `on_attacked`) →
`dischargeShock` → morts (`on_death` différé). **Fatigue** : usure globale après `FATIGUE_START =
1020` ticks (~17 s @ 60 fps) pour forcer la conclusion. `HP_MULT = 2` (combats plus longs).

### 3.3 Ciblage (décision §6) — `arena.lua:chooseTarget`

```
1. minDepth = depth le plus bas parmi ennemis vivants   (colonne AVANT)
2. candidats = ennemis à depth == minDepth
3. si un candidat a taunt → candidats = {taunteurs}       (override dur)
4. cible = max aggro ; tie-break row min (haut→bas), puis slot   (zéro dé)
```
**Aggro activée** (v0.8) : standard 10, tank ~40, bruiser ~15, carry ~5 (data). Tank
`gravewarden` (taunt + épines). **Différés** : passifs de ligne (façade=armure / arrière=attaque),
contres de taunt (AoE-colonne / strip / furtivité), ladder choc 5/3/2.

---

## 4. Économie & progression de run (état SIM — `src/run/state.lua`)

> Tous ces chiffres sont **lus dans `state.lua`** et marqués **[PH]** dans le code.

### 4.1 Constantes (state.lua, lignes 26-70)

| Constante | Valeur | Rôle |
|-----------|--------|------|
| `GOLD_PER_ROUND` | **10** | or FRAIS/round (SAP : **pas de banque**) |
| `REROLL_COST` | **1** | reroll boutique |
| `SHOP_SIZE` | **5** | offres/boutique (toujours 5) |
| `START_LIVES` | **5** | vies initiales |
| `WIN_TARGET` | **10** | victoires → ascension |
| `START_SLOTS` / `MAX_SLOTS` | **3 / 9** | cases ouvertes / capacité max |
| `MAX_GRANTS` | **6** | offres de slot (3→9), rounds 2-7 |
| `START_TIER` / `MAX_TIER` | **1 / 5** | niveau de boutique |
| `BUY_XP_AMOUNT` / `BUY_XP_COST` | **4 / 4** | XP achetée (ratio 1:1) |
| `STREAK_CAP` | **3** | bonus d'or max/série |
| `SLOT_DECLINE_GOLD` / `DECLINE_RELIC_GOLD` | **3 / 3** | or par refus |
| `SELL_REFUND_FRAC` | **0.5** | remboursement revente (< coût = pas d'exploit) |

### 4.2 Boucle

`startRound()` : or frais + bonus streak → reroll boutique → offre de slot si round ∈ {2-7} → XP
passive +1/round dès le round 2. `resolve(win)` : maj vies/wins/streaks (pas d'or ici). **Filet SAP**
(anti-tilt) : début round 3, +1 vie si déjà perdu une vie.

### 4.3 Boutique XP-gating (décision §9) — odds-gating, **pas slot-gating**

5 offres toujours ; monter le tier change la **distribution**. Seuils XP **[PH]** : T1→T2=2,
T2→T3=5, T3→T4=8, T4→T5=12. Cotes **[PH]** :

| Tier | R1 | R2 | R3 | R4 | R5 |
|------|----|----|----|----|----|
| 1 | 100| – | – | – | – |
| 2 | 70 | 30 | – | – | – |
| 3 | 44 | 34 | 20 | 2 | – |
| 4 | 25 | 30 | 30 | 13 | 2 |
| 5 | 15 | 20 | 30 | 25 | 10 |

Slots = **axe séparé** des cotes (grants timés ; accept=+1 / decline=+3 or). « Slots via or » =
**rejeté** (piège playtest). Réf : progression-economy-prd.md §3 ; TFT XP (blitz.gg/tft/guides/gold).

---

## 5. Async par snapshots (pilier #1 — `src/net/`)

> Source : `src/net/snapshot.lua`, `src/net/snapstore.lua`.

- **Snapshot** : `{version, tier, seed, shape, units={{id, level, col, row}}}`. Encodage **sûr**
  (tabulé, jamais `load()` d'une string externe). `toComp(s, side)` = pur (stats scalées
  `LEVEL_MULT`, positions miroir via `Place.pos`, ids inconnus ignorés silencieusement).
- **Store** : pool local 200 (FIFO, `snapshots.txt` via `love.filesystem`). `save` (le build
  devient un ghost) ; `serve(version, tier≤demandé, rng)` (pioche seedée) ; **`serveComp` =
  cold-start garanti** (retombe sur `aiComp` Encounter IA si aucun snapshot). IO **hors SIM**.
- **Déterminisme** : seed de combat tiré du RNG du run (`nextCombatSeed`) → même run+actions =
  même combat (replay). Snapshots sérialisables = adversaires cross-session.
- **Limites v1 (à étendre, pas un bug)** : effets aura/relique **non capturés** dans le snapshot
  (v1 = effets de base) ; pas de matchmaking rang ; pas de backend distant.

---

## 6. Invariants de test — **les 32 garde-fous ABSOLUS**

> Source : `seed/tests.md` §6. Une proposition qui en viole un **exige de modifier le test
> AVANT le code, explicitement**. Un rebaseline silencieux = régression.

**Déterminisme (pilier async)** — 1-5 :
1. Même build + seed → empreinte event-log identique (props.lua).
2. Même seed de run → même suite d'offres + seeds de combat (run.lua).
3. Même seed + wins → même offre de reliques (run.lua + relics.lua).
4. Tout RNG SIM passe par `opts.rng` injecté, jamais `math.random` global.
5. **Golden `970156547`** (confirmé `golden.lua:17`) ne diverge que si VOULU + rebaseline explicite.

**Physique de combat** — 6-10 :
6. `u.hp` ∈ `[0, u.maxHp]` (jamais <0, jamais >maxHp). 7. `u.shield ≥ 0`.
8. Terminaison avant `TICK_CAP = 8000`. 9. Exactement **un** camp survivant.
10. Le golden conclut avant `FATIGUE_START` (=1020, confirmé `arena.lua:58`).

**Run** — 11-17 :
11. `gold ≥ 0`. 12. `lives ∈ [0, 5]`. 13. `slots ∈ [3, 9]`. 14. `#shop == 5` (toujours).
15. `shopTier ∈ [1, 5]`. 16. `shopXp ≥ 0` et `< xpToNext()` après cascade.
17. `xpToNext() == nil` **ssi** `shopTier ≥ MAX_TIER`.

**Modèle relique** — 18-21 :
18. `grantRelic(id)` ne stocke que `{id=id}` (pas de candidats/identification — modèle lisible).
19. Pas de doublon (2e `grantRelic` → false). 20. Reliques `runOp` ne touchent **aucune** stat de
combat. 21. `applyRelics` ne crash pas quelle que soit la liste.

**Synergies (12 contrats d'interaction)** — 22-32 : choc-décharge+consommé · poison multi-sources ·
weaken réduit l'output · bleed ralentit la cadence · regen atténue un DoT · contagion au hit ·
propagation à la mort (dans `on_death`, pas le hit) · aggravate borné `floor(dps*mult)` · shieldEat
au-delà de l'absorption · bleed→rot (consommé) · poison→burn à 5 stacks · festering = cap levé équipe.

**Fuzz couvrant** : 250 combats (seed `20260620`) + 60 runs × 80 actions. Cotes vérifiées
statistiquement (T1=100 % rang 1 ; T5 conforme ±6 pts ; shift −1).

---

## 7. Ce qui RESTE OUVERT (à implémenter/concevoir — **ne pas re-débattre l'acquis**)

> Source : `seed/decisions.md` §6, CLAUDE.md §7. C'est le **terrain de jeu du lab** : prioriser,
> chiffrer, séquencer — pas re-litiger les décisions.

**Économie / méta** (progression-economy-prd, Lots restants) : XP boutique UI+state · marchand
/3 combats · reward level-up borné (1 relique/round, drapeau `relicFromLevelThisRound`) · reliques
±niveau boutique · **passe d'équilibrage auto-itérée** (un levier à la fois via `tools/sim.lua`).

**Contenu / mécaniques différés** : passifs de ligne (façade/arrière) · contres de taunt
(AoE-colonne / strip / furtivité) · **ladder choc 5/3/2** (1 seule unité choc aujourd'hui) ·
**reliques G** (topologie/sigils, chantier dédié) · **6e famille « Ordre »** (gen créatures).

**Synergies par TYPE** (encore un TODO majeur, CLAUDE.md §3 / BRIEF.md) : aujourd'hui seulement
**adjacence positionnelle** ; les synergies par **type** restent à concevoir.

**UI / UX** : infobulle 3 candidats reliques · écran Grimoire (codex 2 onglets existant côté DA :
the-pit-ui-da-layer, mémoire) · effets aura/relique dans le snapshot (v1 = base).

**Compétitif / ranked (zone vierge — opportunité #1 du lab)** : MMR/ladder, format de saisons,
récompenses, intégrité async, anti-snowball perçu. **Rien de codé** ; structure entièrement à
concevoir (BRIEF.md §Compétitif). C'est *le* moteur du « réenchaîner pour grimper ».

### 7.1 Dettes connues (état observé, non-interprété)

Profils d'exposition des sigils non réglés (anneau = exposition en file) · toutes valeurs [PH] à
tuner · boutique sans **raretés/cotes-par-unité** (pool uniforme par rang) · quelques **T3
simplifiés** (ash_maw sans spread-on-death équipe ; pit_maw = rot équipe ennemie ; wither_bloom à
0-dps proxies) · **choc apex faible** (hiérarchie poison>…>choc, the-pit-balance-diagnosis).

---

## 8. Zones SANS garde-fou de test (une proposition qui les touche DOIT ajouter un test)

> Source : `seed/tests.md` §7. Pas de filet de sécurité existant ici.

Effets aura/relique **dans les snapshots** (structure testée, pas l'effet) · passifs de ligne ·
contres de taunt · distribution du pool choc (ladder) · rendu (`arena_draw`, scènes — normal) ·
persistance fichier Grimoire (IO réel ; seul l'in-memory est testé) · écran Grimoire / UI 3
candidats · **profils d'exposition des sigils non-carré** (le golden ne couvre que le carré).

---

## 9. Index des sources (où chercher le « pourquoi »)

| Sujet | Fichier autoritaire |
|-------|---------------------|
| Vision, piliers, boucle | CLAUDE.md §2-3 ; gd-research-result.md |
| Modèle de combat (vie/entité, ciblage) | combat-model-decision.md |
| Familles DoT (axes, sources PoE/LE/D4) | effects-dot-families.md ; effects-design.md |
| Amplification / modificateurs / payoff | effects-amplification-modifiers.md ; payoff-framework.md |
| Synergies / tiers / counterplay | effects-synergy-tiers.md ; effects-balance-counterplay.md |
| Économie / progression / re-tier | progression-economy-prd.md |
| Reliques (pivot lisible, taxonomie) | relics-design.md |
| Architecture moteur (effets, bus, déterminisme) | engine-architecture.md |
| Banc d'essai / simulation | balance-sim-design.md ; `tools/sim.lua` |
| Décisions LÖVE 11.5 (rendu, RNG) | love2d-tech.md |
| **Inventaire code chiffré** | **seed/mechanics.md** |
| **Décisions verrouillées + URLs** | **seed/decisions.md** |
| **Garanties de test** | **seed/tests.md** |

---

*Ancré le 2026-06-23. Chiffres lus dans : `units.lua` (83 unités), `relics.lua` (21 reliques),
`shapes.lua` (5 sigils), `state.lua` (constantes éco), `arena.lua` (FATIGUE_START=1020, HP_MULT=2,
SHOCK_STACK_CAP=8), `ops.lua` (DOT_CAP_MULT=3, BLEED_DPS_CAP=12), `golden.lua` (970156547).
Ne pas modifier sans relire les sources. **Lecture seule du repo : ce lab n'édite que sous
`docs/roadmap-lab/`.**
*
