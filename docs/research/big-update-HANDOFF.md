# BIG UPDATE « Diversité d'effets » — HANDOFF / GUIDE DE CONTINUATION

> **Pour mon successeur (agent ou humain).** Ce document contient **100 % de ce qu'il faut**
> pour reprendre le chantier sans contexte préalable : la mission, le *pourquoi*, les décisions et
> leurs raisons, l'état exact d'avancement, une to-do/checklist détaillée par vague, le *playbook*
> d'exécution, et mes réflexions/pièges. Les specs détaillées par vague vivent déjà dans
> `docs/research/big-update-effects-plan.md` (committé) — ce handoff est la **colle** entre ce plan
> et toi. Lis la §0 puis la §7 (to-do) ; le reste est la profondeur.
>
> Date du handoff : session interrompue volontairement (court de tokens/contexte) **pendant W4**.

> ## ⚡ MISE À JOUR — W4 a ATTERRI (juste après la rédaction de ce doc)
> **W4 (Tank/Removal/Exécution) est DONE, vert, golden-safe, et committé sur `feat/mimicry-axis`.** La
> §7.W4 plus bas (« EN VOL, à finaliser ») est **PÉRIMÉE** — W4 est fait. **Reprendre à W5.**
> - **Intent PROUVÉ** : contre le mur (taunt `gravewarden`+`aegis_warden` + regen `order_marshal`), comp
>   dégâts purs = **0 % win**, comp removal = **100 % win**. Le contre manquant est posé.
> - **Ops livrés** : `percent_hp_strike` (dégâts = `frac × PV max`, **cap ABSOLU `PCT_STRIKE_CAP=14` →
>   ne one-shot JAMAIS**, même un mur à 50000 PV ne prend que +14) ; `strike_highest_hp` (cible le plus
>   gros PV ennemi, **bypass front ET taunt** — le wall-hunter) ; `grant_team{teamExecute}` (équipe « +X
>   aux ennemis sous Y % PV »). **5 unités** (headsman/culler/wallbreaker/siege_titan/reaper_shade) + **2
>   reliques** (reapers_scythe/siege_hammer). Aucune unité golden touchée.
> - **Goldens** : SIM `1176281181` **inchangé** ✅ · GEN re-baseliné **`1055948952 → 2109192272`** (prouvé
>   neutre : les 99 unités pré-W4 foldent à `1055948952`, seuls 5 nouveaux sprites bougent le hash).
> - **Sim N=400** : σ 0,122 · entropie 0,996 · **0 outlier** · part DoT **24,6 %** (le removal dilue le DoT).
> - **2 flags à connaître** : (1) `percent_hp_strike` = **dégâts %-PV** (style Skunk), **PAS amputation des
>   PV max** (ça, c'est le rot) — flaguer si tu voulais un pool-shrink. (2) `strike_highest_hp` **bypasse le
>   taunt** (choix : le wall-hunter DOIT atteindre le mur protégé) ; câblé sur **1 unité** (`culler`),
>   facile à re-gater « taunt-respecting » si tu préfères. Chiffres = placeholders (W9).
> - ⚠️ **Le GEN golden de référence est donc maintenant `2109192272`** (pas `1055948952` comme écrit
>   plus bas en §5/§10 — ces sections datent d'avant l'atterrissage de W4).

---

## 0. TL;DR — à lire en premier

**Ce qu'on fait :** casser la **monoculture DoT (~76 %)** de The Pit (tout le combat est « dégâts dans
le temps » du même registre) en **8-9 axes de synergie orthogonaux**, en s'appuyant sur l'identité
grimdark (infection + mort/engeance + mimétisme) pour **ne ressembler ni à Batomon ni à Super Auto
Pets** (nos deux jeux de référence audités).

**Où on en est :** le **moteur est complet** — les 3 (et seuls) trous moteur structurels sont comblés :
- **W1 Types** ✅ (`type:X` câblé) — committé, **mergé sur `dev` à v0.11**.
- **W2 Mort & Engeance** ✅ (`summon` + 9 tokens sous-êtres + charognards) — committé, **mergé v0.11**.
- **W3 Mimétisme/amplification** ✅ (`repeat_ability` + reliques méta-multiplicatrices) — committé sur
  `feat/mimicry-axis` (`265d869`), **PAS encore poussé/mergé**.
- **W4 Removal/Exécution** 🔄 **EN VOL au moment du handoff** (cf. §7.W4 pour vérifier + committer).

**Ce qu'il reste :** finir/committer W4, puis **W5→W9** (surtout du *contenu* + petits ops localisés),
**plus** le **système de tags/keywords** (spec prête, non implémenté). Détail § 7.

**La règle d'or absolue :** le **golden SIM `1176281181` NE DOIT JAMAIS changer**. Tout ajout est
**append-only / gaté** (les nouveaux ops/cibles sont inertes tant qu'une unité/relique non-golden ne
les utilise pas). Le scénario golden utilise `templar/marauder/skeleton/witch/demon` (combat sans
relique) — **ne JAMAIS toucher ces unités**. Le golden de **génération** (sprites) peut être
re-baseliné **seulement** s'il est prouvé neutre sur le roster existant (cf. §5).

**Convention de travail :** chaque vague = `love2d-engineer` implémente la section correspondante du
plan → `sh tools/check.sh` vert + golden tenu + `luajit tools/sim.lua` → `git-warden` committe. Routage
spécialistes obligatoire (§8 du CLAUDE.md, rappelé en §8 ici).

---

## 1. La mission & le POURQUOI (ne pas perdre le fil narratif)

### 1.1 Le problème de départ
The Pit est un **autobattler async grimdark** (Lua/LÖVE 11.5, pixel-art procédural). Diagnostic
d'équilibrage (cf. mémoire `the-pit-balance-diagnosis` + `docs/research/effects-overhaul-spec.md`) :
**~75,9 % des dégâts venaient des afflictions DoT** (poison/burn/bleed/rot/shock). Hiérarchie
d'archétypes plate (poison > tank > … > shock), peu de vraie diversité de *build*. Le combat est riche
en *simulation* (13 interactions inter-afflictions) mais l'espace de **theory-crafting** (décisions de
build qui se multiplient) est pauvre.

### 1.2 Le déclencheur
L'user a trouvé la **data de Batomon Showdown** (sa référence d'addictivité, cf. CLAUDE.md §2) sur
`batodex.com`, qu'on a scrapée intégralement. On a **aussi** audité **Super Auto Pets** (le grand-père
du genre) via son dataset + le wiki. Trois jeux entièrement cartographiés **sur data réelle**.

### 1.3 La thèse (le cœur intellectuel)
> **Profondeur de theory-crafting = (nombre d'axes orthogonaux qui se MULTIPLIENT) × (effets qui
> amplifient d'autres effets) × (lisibilité).** Pas le nombre de mécaniques.

- **The Pit** est profond **dans le combat** (afflictions + transmission) mais **pauvre dans la couche
  build** (types inertes, sigils gelés, peu de méta-multiplicateurs, pas de mort-économie, pas de
  mimétisme, combat-only).
- **Batomon** est profond **dans la couche build** : type-identité × position × fréquence × éco ×
  méta-multiplicateurs, + moteurs *cross-phase* (boutique↔combat).
- **SAP** est profond dans la **grammaire d'effets** (Trigger×Effect×Target, 21 triggers), l'**économie
  Mort/Invocation**, la **polarité positionnelle**, et la bascule **cap → removal** (un cap dur termine
  la course au scaling → l'endgame appartient au removal %/placement). **SAP n'a AUCUN DoT** → nos
  afflictions sont *précisément* ce qui nous différencie de lui.

### 1.4 Le but & le plan anti-clone
**Garder** notre cœur unique (combat = infection qui se propage) + déterminisme/async + commandants +
sigils mutables (dormants). **Emprunter à SAP** (original *vs* Batomon, et thématiquement nôtre) :
mort/réanimation→**engeances**, mimétisme, polarité directionnelle, la bascule cap→removal. **Emprunter
à Batomon** (profondeur pas chère) : câbler les types, méta-multiplicateurs. **Résultat visé :** ~8-9
axes croisés où chaque unité/relique vit sur plusieurs axes → la combinatoire explose. Phrase-résumé qui
n'est ni Batomon ni SAP :
> *Un autobattler grimdark async où le combat est une infection qui se propage, où l'on sacrifie et
> réanime ses unités sur un plateau non-euclidien mutable, et où les gros chiffres finissent par céder
> à l'exécution et au placement.*

---

## 2. Les DOCUMENTS DE RÉFLEXION (lis-les, ils contiennent le détail)

Tous committés sous `docs/research/` (sauf mention) :

| Document | Quoi / pourquoi il compte |
|---|---|
| **`big-update-effects-plan.md`** | ⭐ **LA BIBLE.** Plan de contenu de la MAJ : la distribution-cible des axes, **par axe** les ops moteur + ~N unités (avec descripteurs `{trigger,op,params,target}`) + ~N reliques + combos + golden-safety ; la **palette de 16 archétypes** cross-axes ; le **rollout séquencé W0→W9** ; les garde-fous d'équilibrage. **C'est la source pour chaque vague.** |
| **`the-pit-vs-batomon-vs-sap.md`** | L'étude maître à trois : où vit la profondeur de chacun, le tableau comparatif, le plan anti-clone, les 8-9 axes, le quadrant signature. Le *pourquoi* stratégique. |
| `batomon/the-pit-vs-batomon.md` | Comparaison 2-way détaillée axe par axe (Batomon). |
| `batomon/batodex-digest.md` + `batomon/{monsters,trinkets,items}.json` | Data Batomon complète (80 monstres / 58 trinkets / 32 items) — vue lisible + brute. |
| `sap/sap-digest.md` + `sap/super-auto-pets-data.json` | Data SAP complète (89 pets / 17 foods / 10 statuses) — mécaniques signatures + brut. |
| **`tag-keyword-system-spec.md`** | ⭐ Spec du **système de tags/keywords** (mots-clés colorés + pop-up Shift glossaire). **Non implémenté.** Voir §7.TAGS. |
| `effects-overhaul-spec.md` (+ `effects-overhaul-SUMMARY.md` si présent) | La spec d'overhaul *antérieure* (le diagnostic DoT, les keystones moteur déjà livrés). Le `big-update-effects-plan.md` la **consolide** ; lis-la pour le diagnostic de fond. |
| `generation/generateur-bestiaire.html` (⚠️ **modifié non committé**, c'est le prototype ACTIF de l'user) | Le générateur HTML : **`window.SPAWN`** (mapping parent→token engeance) + **`IMPOSANCE`** (0=token) + les **9 archétypes sous-êtres** (déjà portés en Lua en W2). Source de body-plans pour de futurs sprites. **NE PAS committer** (l'user y travaille). |

Mémoires projet pertinentes (dans le store de mémoire) : `the-pit-effects-overhaul`,
`the-pit-balance-diagnosis`, `the-pit-payoff-framework`, `the-pit-commanders-effect-diversity`,
`the-pit-command-auras-campaign`, `the-pit-design-blueprint`, `the-pit-engine-architecture`.

---

## 3. DÉCISIONS PRISES & leurs RAISONS (pour ne pas les re-litiger)

1. **8-9 axes de synergie** (la cible) : Afflictions/transmission (notre cœur, à garder mais
   *décentrer*) · Type-identité (mono/rainbow) · **Mort & Engeance** · **Mimétisme/amplification** ·
   **Position/polarité directionnelle** · Fréquence (multicast/hâte) · **Tank/Removal/Exécution** ·
   Éco/tempo · Commandants/Whispers. **Raison :** orthogonalité = profondeur (§1.3).

2. **Engeances > « réanimation »** (décision USER). Au lieu de relever le même mort (déjà-vu, sonne
   D&D), une unité **enfante du moindre** (cocon→larves, broodmother→spiderlings). **Plus original,
   plus Cthulhu, plus *nous*.** L'user a construit le backbone : `window.SPAWN` (parent→token) +
   `IMPOSANCE` 0 + 9 archétypes « sous-êtres » dans le générateur HTML.

3. **Placement des engeances = 1 token dans la case du parent** (décision USER, via AskUserQuestion). Le
   modèle **1-pour-1** le plus simple/lisible (pas de remplissage d'adjacence, pas d'overflow). La
   *nuée* vient du **nombre d'invocateurs**, pas du multi-spawn. *Enrichissement futur possible :*
   multi-spawn (le plan avait recommandé « case parent + adjacents », l'user a préféré plus simple).

4. **Effets directionnels = 4 cardinaux + adjacent** (`ahead/behind/above/below` + `neighbors`). **L'idée
   clé qui les rend non-redondants :** notre géométrie de ciblage les sépare —
   - **devant/derrière (X = colonnes = profondeur)** est **couplé à l'EXPOSITION** (le devant se fait
     taper en premier ; `depth = maxCol - x`). Buffer « l'unité devant » = buffer l'exposé → tension/risque.
   - **haut/bas (Y = rangées)** est **NEUTRE en exposition** (même colonne = même profondeur = même
     priorité de ciblage). Synergie *sûre* sans changer qui se fait viser.
   → deux saveurs stratégiques distinctes. **Raison de le faire :** on est 2D, SAP n'a que devant/derrière
   parce qu'il est 1D ; n'utiliser que devant/derrière jetterait la moitié du plateau. **(C'est W5.)**

5. **`repeat_ability` (Tiger) = `on_hit` only, depth-1, pas de repeat-de-repeat.** Implémenté
   **build-résolu** (copie les descripteurs `on_hit` du voisin dans le comp du mime), PAS un op combat-time
   (évite la ré-entrance). **Raison :** borner durement la combinatoire (combat toujours terminant).

6. **Méta-multiplicateurs : amplifient les sorties d'aura MAIS les caps restent le plafond final.** Un
   `atkInc` ampli à 1,61 est lu à **1,5** (le cap mord). Le **multicast n'est JAMAIS amplifié** (seuil
   entier → double-snowball interdit). `AMPLIFY_FRAC_CAP = 0.50`. **Raison :** l'ampli doit *sentir*
   fort sans casser une borne. C'est ce qui crée la combinatoire « broken » sainement.

7. **`percent_hp_strike` (W4) = % des PV MAX, plafonné en ABSOLU → ne one-shot JAMAIS.** **Raison :**
   c'est l'anti-mur (fait mal aux gros tanks) ET la bascule **cap→removal** (donne du sens à nos caps :
   « les gros chiffres cèdent au ciblage ») SANS devenir un one-shot. (cf. SAP Skunk/Panther.)

8. **Discipline golden (NON négociable).** SIM golden `1176281181` figé. Tout est append-only/gaté.
   Gen golden re-baseliné **uniquement** prouvé-neutre (le fold sur le roster existant doit rester
   byte-identique ; seuls les nouveaux sprites décalent l'empreinte). Les **tokens** (sous-êtres) ne sont
   PAS dans `Units.order` donc n'entrent même pas dans le fold gen.

9. **Lisibilité d'abord** (préférence USER forte) : valeurs concrètes (pas de %), polices lisibles pour
   le contenu, anticiper le débordement (scroll/clip), specs ASCII pour le designer. Le **système de
   tags** (§7.TAGS) est la grosse pièce « lisibilité » encore à faire — il rend toute cette diversité
   *compréhensible au joueur*.

---

## 4. ROLLOUT — état d'avancement (la carte)

Cible de distribution (casser le 76 % DoT), depuis `big-update-effects-plan.md` :

| Axe | Avant | Cible | Vague | État |
|---|---|---|---|---|
| Afflictions/transmission | ~76 % | ~28 % | (redistrib. W7) | cœur conservé |
| Type-identité | 0 % | ~12 % | **W1** | ✅ committé, mergé v0.11 |
| Mort & Engeance | ~2 % | ~12 % | **W2** | ✅ committé, mergé v0.11 (+ sprites sous-êtres) |
| Mimétisme / méta-mult | ~1 % | ~10 % | **W3** | ✅ committé `265d869` (`feat/mimicry-axis`, non poussé) |
| Tank/Removal/Exécution | ~6 % | ~10 % | **W4** | 🔄 **EN VOL** (vérifier — §7.W4) |
| Position/polarité directionnelle | ~5 % | ~10 % | **W5** | ⬜ TODO |
| Fréquence + Commandants | ~6/5 % | ~8/5 % | **W6** | ⬜ TODO |
| Redistribution DoT | (de 76 %) | → ~28 % | **W7** | ⬜ TODO (en dernier) |
| Éco/tempo (Freeze) | ~3 % | ~5 % | **W8** | ⬜ TODO |
| Équilibrage de masse | — | — | **W9** | ⬜ TODO (un levier à la fois, `sim.lua`) |
| **Système de tags/keywords** | — | — | (transverse) | ⬜ **SPEC PRÊTE, non implémenté** |

**Ordre de rollout** (affiné par le designer) : W0 filets → **W1 → W2 → W3 → W4** (Removal remonté car
*rien ne contre aujourd'hui le mur regen+taunt+purge*) **→ W5 → W6 → W7 (redistrib DoT en dernier) →
W8 → W9 (équilibrage masse).** Chaque vague : verte + golden tenu + committée.

---

## 5. ÉTAT DU MOTEUR (ce qui est construit) — référence technique

**Les 3 trous moteur sont comblés** (c'étaient les *seuls* vrais chantiers moteur de la MAJ) :
- **`type:X`** (W1) — `src/scenes/build.lua` `resolveTargets` (branche `type:`) + miroir `relics.lua`
  `R.apply`. + op `aura_per_unique_type` (rainbow, `RAINBOW_TYPE_CAP=5`).
- **`summon`** (W2) — `src/effects/ops.lua` (op `summon`, trigger self-death) + `src/combat/arena.lua`
  (`makeToken`/`queueSummon`/`flushSummons` : insertion **différée** après la boucle de mort, jamais de
  mutation mid-`ipairs` ; passe self-death dédiée). Tokens **terminaux** (n'invoquent pas). Bridge data :
  `src/data/spawn.lua` (`Spawn.tokens`, 9 tokens, `family="sousetres"` + arch homonyme, **PAS dans
  `Units.pool/order`**). + op `scavenge_on_ally_death` (charognards, trigger `on_ally_death`).
- **`repeat_ability`** (W3) — `src/scenes/build.lua` (build-résolu, `REPEAT_DEPTH_MAX=1`, `who="ahead"`
  ou `who="neighbors"`, flag `viaCopy`). + op `amplify_auras` (unité + relique, `AMPLIFY_FRAC_CAP=0.50`).

**Moteur agnostique déjà livré (avant la MAJ, gaté) :** `aura_stat` (cibles
`neighbors/team/role:front|back|center/tier:N/level:N/type:X`), `multicast`, `grant_vuln`/empower,
slot **commandant** (intouchable, `isCommander`), les **83 commandBonus** (auras de commandement),
**whispers** (23 unités cachées), **snapshots** async, **13 interactions inter-afflictions**
(contagion/propagation-à-la-mort/conversion/aggravate/shield-eat/weaken…), ops `execute`/`crit`/`cleave`/
`heal_on_kill`/`purge`/`thorns`/`strip_shield`/`grant_team`/`frenzy_gain`/`spread_*_on_death`.

**Les CAPS (le plafond de lecture en combat — `src/combat/arena.lua`) :** `ATK_INC_CAP=1.5` ·
`DOT_CAP_MULT=4` · `MULTICAST_MAX=3` · `DMG_REDUCE_CAP=0.60` · `HASTE_CAP=0.40` · `VULN_INC_CAP=0.5`.
Build/relics : `AMPLIFY_FRAC_CAP=0.50` · `RAINBOW_TYPE_CAP=5` · `REPEAT_DEPTH_MAX=1` · (W4 ajoute un cap
absolu pour `percent_hp_strike`). **Philosophie : on amplifie la valeur brute, le cap clamp au read.**

**Les GOLDENS (à vérifier dans les fichiers de test, ne pas supposer) :**
- **SIM : `1176281181`** (`tests/golden.lua`) — **DOIT rester figé** à travers toutes les vagues.
- **GEN : `1055948952`** (`tests/gen.lua`, après W3). Historique : `1150543352` (avant) → `541702824`
  (W1) → `3256988032` (W2 ; sous-êtres l'ont laissé inchangé) → `1055948952` (W3). Re-baseline **autorisé
  pour du contenu neuf** *si prouvé neutre* (fold sur le roster existant inchangé).

**Types (5)** : `flesh/bone/arcane/abyss/order`. **5 familles DoT** : burn/bleed/poison/rot/shock.
**Roster** : ~83 unités de base + les unités ajoutées par vague (W1 : 6, W2 : 7, W3 : 3 + 9 tokens).

---

## 6. ÉTAT GIT, FLUX DE BRANCHES & CONTRAINTES PERMANENTES

**Git au moment du handoff :**
- `dev` = `main` = `origin/dev` = `origin/main` = **`6a78f71` (tag `v0.11`)** — contient W1 + W2 +
  particules + un commit UI de l'user. C'est la base à jour.
- **`feat/mimicry-axis`** (branche de rollout courante) — basée sur dev v0.11, contient **W3 (`265d869`)**
  + **W4 (en vol, à committer)**. **NON poussée** (pas d'upstream).
- `feat/types-axis` — l'ancienne branche de rollout (W1+W2+particules), **déjà mergée dans dev** (stale).

**Flux de branches (le pattern observé) :** j'implémente une (ou plusieurs) vague(s) sur une branche
`feat/<slug>` depuis `dev` → je committe via git-warden quand vert → **l'USER pousse/PR/merge vers dev
lui-même** (il l'a fait pour `feat/types-axis`→dev→main→tag v0.11). Donc : **committer oui, pousser
UNIQUEMENT sur demande explicite.** La branche de rollout **accumule** plusieurs vagues (comme
types-axis avait W1+W2) ; l'user PR le lot quand il veut.

**CONTRAINTES PERMANENTES (verbatim, à respecter absolument) :**
- **Golden SIM `1176281181` doit tenir** — append-only/gaté ; ne jamais toucher les unités du scénario
  golden (`templar/marauder/skeleton/witch/demon`).
- **Vérifier les API** sur sources primaires (love2d.org/wiki **11.5** ; lua 5.1) — *jamais* de mémoire
  (règle d'or §1.a). Préférer `get_code_context_exa`.
- **Pousser UNIQUEMENT sur demande explicite.** Committer aux jalons verts via **git-warden**.
- **Stager par chemins EXPLICITES, JAMAIS `git add -A`/`.`**
- **Valider au screenshot** ce qui est visuel (« le PC de l'user fait foi » ; l'export `--shoot` masque
  les bugs de transform). Tout dessiner dans `Draw.begin/finish`.
- **Valeurs concrètes, pas de %** (sauf conventions `increased`-style existantes). Police lisible pour le
  contenu. Anticiper le débordement (scroll/clip). Cartes au survol, pas de cadre carvé, **pas de gros
  rewrites à l'aveugle** (incrémental + validé screenshot).
- **Répondre en FRANÇAIS** à l'user.
- **Firewall SIM/RENDER** : `src/combat|board|effects|run|net` + la résolution au build = **zéro
  `love.graphics`**. Déterminisme : RNG seedé, `ipairs` (jamais `pairs`) pour tout ordre de sim.
- **Fichiers SACRO-SAINTS à NE JAMAIS committer/toucher** (untracked ou prototype actif de l'user) :
  `feel-lab/` · `docs/creatures-for-designer.json` · `docs/relics-for-designer.json` ·
  `docs/generation/generateur-bestiaire.html` (modifié, prototype ACTIF) · `.codex/` · `AGENTS.md`.

---

## 7. ⭐ TO-DO / CHECKLIST DÉTAILLÉE (le cœur du handoff)

> Pour CHAQUE item : **lire la section correspondante de `big-update-effects-plan.md`** (specs complètes),
> puis briefer **love2d-engineer** (cf. §8 playbook), valider, committer via git-warden. Tout golden-safe.

### 🔄 W4 — Tank / Removal / Exécution — **EN VOL, à finaliser**
**État :** lancé chez `love2d-engineer` (branche `feat/mimicry-axis`) au moment du handoff. **Premier
geste du successeur :**
1. **Vérifier le résultat** : `git -C <repo> status` et `git log --oneline -3` sur `feat/mimicry-axis`.
   Si le W4 n'est **pas** committé mais l'arbre a des changements → lire le rapport de l'agent (tâche
   `adb52313cd60086e0` si encore résoluble, sinon juger les diffs), faire tourner `sh tools/check.sh`
   (doit être **vert**, golden SIM `1176281181` **inchangé**), `luajit tools/sim.lua 200`, puis
   **committer via git-warden** (`feat(effects): tank/removal/execution axis (Wave 4)`, chemins
   explicites, exclure les sacro-saints).
2. **Ce que W4 doit contenir** (si à refaire/compléter) : op **`percent_hp_strike`** (% PV **max**,
   **cap absolu → jamais de one-shot**) ; **`strike_highest_hp`** (cible le plus gros PV ennemi, pattern
   Skunk/Panther) ; relique **team-execute** (« +X dégâts aux ennemis sous Y % PV »). + quelques unités
   removal + relique(s). **Validation-clé :** la sim doit montrer le **win-rate du mur tank/regen
   *baisser* vers la moyenne** (= le contre manquant enfin posé, pas une régression).
**Pourquoi :** donner du sens à nos caps (bascule cap→removal) + punir le mur regen+taunt+purge.

### ⬜ W5 — Position / polarité directionnelle
**Quoi :** câbler les cibles **`ahead/behind/above/below`** dans `resolveTargets`
(`src/scenes/build.lua`, là où `type:X`/`tier:N` sont déjà gérés) ; dérivées de la case `(x,y)` sur le
graphe du plateau (front/back = X/`depth`, haut/bas = Y/rangées). Puis ~quelques unités/reliques à effets
directionnels (tanks qui buffent « l'unité derrière », supports « au-dessus/en-dessous », etc.).
**Pourquoi/attendu :** densifier l'axe position (on est 2D), avec la dualité **exposé (devant/derrière)
vs neutre (haut/bas)** (cf. §3.4). **Golden-safe** : nouvelles cibles inertes tant que non utilisées par
de la data non-golden. *Fallback* : pas de voisin dans la direction → effet nul (convention « part
absente = ignorée »). Interaction sigils (plus tard) : sur la ligne seul devant/derrière existe, etc.

### ⬜ W6 — Fréquence + Commandants
**Quoi :** **fréquence** = data sur le multicast/hâte existants (cap multicast 3, `HASTE_CAP 0.40`) — pas
d'op neuf, du contenu qui empile la fréquence (le choc scale avec). **Commandants** = re-thématiser 2-3
commandBonus en *porteurs d'axe* (ex. un commandant Toxic qui donne du poison à l'équipe — rejoint l'axe
type). **Note différée de W1 :** « commandant de **type** » (`commandBonus target="type:X"`) n'est PAS
autorisé pour le commandant (hors-graphe, ne résout pas un set de type relatif au plateau) — étendre le
chemin commandant à `type:` est invasif (risque golden) ; **à faire ici** si voulu, prudemment.

### ⬜ W7 — Redistribution DoT (en DERNIER avant l'équilibrage)
**Quoi :** une fois les autres axes capables d'absorber, **re-tiérer/déplacer ~12-15 unités DoT** vers
les nouveaux axes pour faire **descendre la part DoT de ~76 % → ~28 %**. **Pourquoi en dernier :** ne
retirer du DoT que quand il y a où le mettre. **Attention golden** : ne pas toucher les unités du
scénario golden.

### ⬜ W8 — Éco / tempo (Freeze)
**Quoi :** **Freeze** en boutique (verrouiller une offre d'un tour à l'autre) — un **`runOp`** côté
`src/run/state.lua` (hors SIM), pas un effet de combat. **Pourquoi/attendu :** outil de planification
cross-turn (emprunté à SAP) ; ouvre un peu l'axe éco. Petit chantier.

### ⬜ W9 — Équilibrage de masse
**Quoi :** **tous les chiffres des vagues sont des PLACEHOLDERS.** Passe d'équilibrage finale via
`luajit tools/sim.lua <N>` (gros N) → lire `runs/report.json` (win-rate/unité, σ, entropie, part DoT,
`lift` de co-occurrence = détecteur de combos cassés, drapeaux d'outliers). **Un levier à la fois.**
**Flags connus à raboter :** les **unités-mimes de W3 tirent haut** (~70 % à N=400 — `echo_flesh`/
`mimic_spawn` ; `hollow_crown` ~61 %) sans être outliers (champ large) → probablement raboter coût/stats.
Idem surveiller W4 (removal trop fort ?) et tout nouvel ajout.

### ⬜ TAGS — Système de keywords (transverse, SPEC PRÊTE)
**Spec :** `docs/research/tag-keyword-system-spec.md`. **Domaine UI → agent `ui-artisan`** (+ part data
moteur via `love2d-engineer`). **Quoi :** chaque mécanique = un **mot-clé coloré** dans les tooltips, +
une **pop-up Shift** à droite de la carte qui liste/explique tous les tags d'une unité.
- **~70 % existe déjà** : `src/ui/keywords.lua` (registre, mais afflictions-only) ; `src/ui/chip.lua` ;
  `src/ui/theme.lua` (`Theme.c` = couleurs, à réutiliser) ; `src/render/monstercard.lua` (le tooltip,
  **renvoie déjà sa boîte** = ancrage de la pop-up). **Généraliser, pas reconstruire.**
- **Data-model recommandé :** nouveau `src/core/tags.lua` (pur, sous firewall, read-only) — `Tags.forUnit`
  = union des tags (effets ∪ commandant ∪ type ∪ taunt ∪ aura ∪ directionnel ∪ whisper), dérivés de
  l'`op`+params → **zéro réécriture de la data unité**. Coloration via tokens `[poison]` dans l'i18n.
- **Taxonomie :** 33 tags / 6 groupes (+5 types). Les tags des nouveaux axes (Engeance/Faint/Mimétisme/
  directionnels) sont **déclarés mais inertes** → s'allument quand l'op arrive.
- **Pop-up Shift :** `love.keyboard.isDown("lshift","rshift")` (vérifié 11.5), panneau collé à droite,
  scroll-clip si débordement, tout dans `Draw.begin/finish`. Nouveau `src/ui/tagglossary.lua`.
- **Juice/son** de la pop-up = co-invoquer **game-feel-engineer + sound-designer** au moment de l'implé.
- **Golden-safe** (RENDER/data-additive, ne touche pas la SIM).

### ⬜ Pistes différées / dette connue (à garder en tête)
- **Link-Cable (W3)** implémenté comme **ampli d'aura** (`dotOnly`), **pas** la réécriture de topologie
  littérale (« adjacence→colonne ») — celle-ci exigerait de rendre `buildComp` *relic-aware* (invasif,
  risque la séparation golden/tests). À élargir plus tard si désiré (threader `run.relics` dans buildComp).
- **Multi-spawn engeances** (le plan recommandait « parent + adjacents » ; l'user a choisi 1-token) —
  enrichissement possible.
- **Sigils GELÉS** (`Board.SIGILS_PAUSED=true`, carré only) — les rallumer est un axe *signature* dormant
  (le plan le mentionne ; lié à l'axe directionnel W5). Hors-scope des vagues actuelles sauf décision user.
- **Effets cross-phase** (boutique↔combat, façon Batomon) — non fait ; reste build-state donc
  snapshot-déterministe si ajouté. Idée du plan, pas priorisée.

---

## 8. PLAYBOOK D'EXÉCUTION (comment faire une vague proprement)

**Routage spécialistes (CLAUDE.md §8 — NON négociable) :**
- **Code Lua/LÖVE** (ops, sim, build-resolution, data unités/reliques, tests) → **`love2d-engineer`**.
- **Sprites / générateur** (`src/gen/primgen.lua`, nouveaux body-plans, port d'archétypes) → **`asset-forge`**.
- **Design / nouvelles mécaniques** (si une vague est sous-spécifiée) → **`autobattler-designer`**.
- **UI / composants / tooltips / la pop-up tags** → **`ui-artisan`**.
- **Git** (branches, commits, merges, décisions « où ça va ») → **`git-warden`**.
- **Game feel / juice / son** dès qu'une interaction est en jeu → **`game-feel-engineer` + `sound-designer`** (co-invoqués).
- Ne jamais improviser hors-domaine ; donner aux agents les références de l'existant.

**Le cycle d'une vague :**
1. **Lire** la section de la vague dans `big-update-effects-plan.md` (specs autoritaires).
2. **Briefer `love2d-engineer`** : pointer la section du plan, donner l'état moteur (§5 ici), les
   constantes/caps, la branche (`feat/mimicry-axis` — rester dessus, **ne pas committer**, l'agent
   confirme `git branch --show-current`), les contraintes (verify API, firewall, déterminisme, golden
   inerte, i18n valeurs concrètes). Demander : implé + tests + i18n, **`sh tools/check.sh` vert**,
   **golden SIM inchangé** (`luajit tests/golden.lua`), **sim avant/après** (`luajit tools/sim.lua 200`),
   et un **rapport** (fichiers+lignes, l'op + son bornage, deltas sim, flags). **Implémenter fidèlement la
   spec, flaguer l'ambiguïté plutôt qu'improviser** (préférence user forte).
3. **Sprites** : si la vague ajoute des unités, elles peuvent **réutiliser des combos `family/arch`
   primgen prouvés** (gen golden re-baseline neutre). Si un *nouvel* archétype est requis → `asset-forge`
   (port depuis le générateur HTML, validé screenshot, gen golden prouvé-neutre).
4. **Au vert** : `git-warden` committe sur `feat/mimicry-axis` (chemins explicites, exclure sacro-saints,
   message conventionnel + footer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`,
   **pas de push** sauf demande).
5. **Reporter à l'user** (en français) : l'axe livré, les chiffres sim, les flags honnêtes, et l'offrir
   de continuer / pousser / playtester.

**Vérifs systématiques de fin de vague :** `check.sh` vert · golden SIM `1176281181` inchangé · gen
golden inchangé OU prouvé-neutre (flaguer le nouveau hash) · sim saine (entropie ≥0,90, 0 outlier idéal,
part DoT qui descend) · firewall respecté · i18n couvert.

---

## 9. MES RÉFLEXIONS / PIÈGES / NOTES (le tacite qui aide)

- **Le moteur est le plus dur, et il est FAIT.** Les 3 ops structurels (type:X/summon/repeat_ability)
  sont les seuls vrais gaps. W4-W9 = surtout du contenu + 2-3 petits ops (`percent_hp_strike`, cibles
  directionnelles, Freeze runOp). Ne pas sur-ingénier le reste.
- **« Build-résolu » > « op combat-time » quand c'est possible.** W1 (type/rainbow), W3 (repeat/amplify)
  sont résolus **au build** (dans `src/scenes/build.lua`, `combat_start`/post-pass), pas en combat. Ça
  garde l'arène autonome, déterministe, snapshot-friendly, et **golden-inerte**. Préférer ce pattern.
- **Le golden SIM ne bouge pas parce que** rien de neuf ne touche les 5 unités du scénario (combat sans
  relique). Tant que tu ajoutes des unités/reliques *à côté* et que tu ne modifies pas ces 5, il tient.
- **Le golden GEN bouge pour de nouveaux sprites** — c'est normal et autorisé *si prouvé neutre* (le fold
  sur les unités existantes reste identique). Les agents l'ont prouvé à chaque vague ; exige cette preuve.
- **Les caps sont la sécurité.** Tout ce qui amplifie (rainbow, méta-mult, removal) doit rester sous un
  cap de lecture. Si un agent propose un effet « non cappé », c'est un drapeau rouge.
- **Les chiffres sont tous des placeholders** jusqu'à W9. Ne pas s'angoisser qu'une unité tire à 70 % en
  cours de route — c'est noté pour l'équilibrage final. Mais *flaguer* (honnêteté).
- **Pièges git résolus (pour mémoire) :** l'entremêlement `build.lua → require("src.ui.particles")`
  (module non committé) a rendu `feat/types-axis` cassée-en-checkout-propre un temps → résolu en
  committant le transplant particules. **Leçon :** quand un `build.lua` committé `require` un module,
  s'assurer que le module est committé aussi, sinon la branche n'est pas auto-cohérente.
- **L'user pilote le merge.** Il fait ses PR lui-même vers dev. Ne pas merger/pousser sans demande.
  Committer sur la branche de rollout et **lui rendre la main**.
- **L'user valide le visuel sur SON PC** (`[g]` galerie pour les créatures). Les agents valident via le
  vrai chemin de génération (rendu→ASCII) en proxy, mais le blessing final est à l'user.
- **Ton réflexe à garder :** chercher l'existant avant de créer (le projet a souvent déjà le module/
  convention) ; le TOP du top, jamais le minimum ; tester au screenshot ; flaguer plutôt qu'improviser.

---

## 10. ANNEXE — démarrage rapide du successeur

```sh
# 1. Se situer
git -C /Users/kevinbarfleur/Github/the-pit status
git -C /Users/kevinbarfleur/Github/the-pit log --oneline --graph --all -15
git -C /Users/kevinbarfleur/Github/the-pit branch --show-current   # attendu : feat/mimicry-axis

# 2. Vérifier la santé + les goldens
sh tools/check.sh                 # doit être VERT
luajit tools/golden.lua           # SIM golden attendu : 1176281181
luajit tools/sim.lua 200          # santé d'équilibrage -> runs/report.json

# 3. Reprendre : finaliser W4 (cf. §7.W4), puis W5 -> W9 + le système de tags (cf. §7).
#    Pattern : lire big-update-effects-plan.md -> brief love2d-engineer -> check/golden/sim -> git-warden.
```

**Fichiers moteur clés :** `src/effects/ops.lua` (ops) · `src/effects/engine.lua` (registre/triggers) ·
`src/combat/arena.lua` (sim, caps, ciblage, summon) · `src/scenes/build.lua` (résolution au build :
auras, type, rainbow, repeat, amplify) · `src/data/units.lua` (unités) · `src/data/relics.lua` (reliques)
· `src/data/spawn.lua` (tokens engeance) · `src/gen/primgen.lua` (sprites) · `src/i18n/en_ext.lua`
(strings additives). **Tests :** `tests/{headless,synergies,auras,relics,gen,golden,props,primgen}.lua`.

**Branche de rollout :** `feat/mimicry-axis` (W3 `265d869` + W4). **Base :** `dev`=`v0.11`=`6a78f71`.
**Goldens :** SIM `1176281181` (figé) · GEN `1055948952` (après W3, re-baseline-si-neutre).

---

*Fin du handoff. Tout ce qui précède + les docs `docs/research/` référencés = 100 % du contexte pour
reprendre. Bon courage — le plus dur (le moteur) est fait ; le reste est du contenu discipliné.*
