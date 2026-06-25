# The Pit — Plan maître de la grande mise à jour « diversité » (effets & contenu)

> **Statut** : DOC SOURCE — la *bible de contenu* depuis laquelle on exécute. **DESIGN, zéro code.**
> Consolide et **supersede pour la suite** `effects-overhaul-spec.md` (qui a *posé le moteur agnostique* :
> caps, multicast, vuln, execute, cleave, commandants, murmures — tout livré/gated, golden `1176281181`).
> Ce plan **ne refait pas** ce qui existe : il **branche les axes encore éteints** (types, mort/engeances,
> mimétisme, polarité Y, removal) pour casser la **monoculture DoT (~76 %)** en **8-9 axes orthogonaux**.
>
> **Boussole** (CLAUDE.md §2-3 + `the-pit-vs-batomon-vs-sap.md`) : on n'est **ni un Batomon, ni un SAP**.
> Notre cœur = **le combat comme infection qui se propage**. On **garde** ça, on **emprunte à SAP**
> (mort/réanimation + mimétisme = *thématiquement nôtres*) et **à Batomon** (types + méta-multiplicateurs).
> Tout chiffre = **PLACEHOLDER** à tuner via `tools/sim.lua` / `tools/balancematrix.lua`.
>
> **Règles dures** (vérifiées dans le code, cf. §État) : append-only/gated → golden `1176281181` tient ;
> SIM sans `love.graphics` ; déterministe (RNG seedé `ctx.arena.rng`, jamais `math.random` global) ; tout
> ordre de sim en `ipairs` ; tout texte affiché via i18n (`src/i18n/en.lua`) ; **valeurs concrètes, pas de %**
> (feedback projet : la carte affiche un nombre réel, le moteur garde le multiplicateur).

---

## 0. État vérifié du code (ne pas re-dériver — cité file:line)

Le moteur agnostique de `effects-overhaul-spec.md` est **DÉJÀ LIVRÉ et gated**. Ce plan part de là.

| Brique | État réel | Preuve (file:line) |
|---|---|---|
| Grammaire d'effet | `{trigger, op, params, condition?, target?}`, liste par unité, registre ouvert/fermé | `src/effects/engine.lua:38-48` |
| Triggers (8) | on_attack / on_hit / on_attacked / combat_start / on_low_hp / on_kill / on_death / on_ally_death | `arena.lua:194` (combat_start), `:761-871` (kill/death/ally_death), `:720-760` (low_hp) |
| Ordre de mort FIXE | file `self.deaths` = `{victim,killer}` ; broadcast diféré (1) on_kill (2) on_death (3) on_ally_death, skip morts-de-frame | `arena.lua:836-871` |
| Ops agnostiques | crit, execute, grant_vuln, grant_affliction_if_absent, convert_dot, cleave, heal_on_kill, purge — **tous présents, gated** | `ops.lua:325-461` |
| 5 familles DoT | burn/bleed/poison/rot/shock + 13 croisements (contagion/spread-on-death/convert/aggravate/shield-eat) | `ops.lua:42-323` |
| Empower / Vuln (K2) | `source.atkInc` (sortant) + `target.vulnInc` (entrant) en `increased`, caps durs | `arena.lua:151,367-369`, `hit()` |
| Multicast entier (K3) | bouclé dans `update()`, `MULTICAST_MAX=3`, consommables au 1er sous-coup | `arena.lua:798-802` |
| Commandant (K4) | `isCommander`/`untargetable`, exclu du ciblage AUX 2 endroits, `damage=0`, exclu du décompte, `cdMult` | `arena.lua:255-282,350-354,873-880` |
| **`aura_stat` (K1)** = foyer unique des auras+commandants | bake build-résolu : `neighbors / team / role:front|back|center / tier:N / level:N` | `build.lua:1533-1620` |
| Caps durs (lecture) | ATK_INC 1.5 · VULN_INC 0.5 · MULTICAST 3 · HASTE 0.40 · DMG_REDUCE 0.60 · DOT ×4 · POISON_STACK 8 · WEAKEN 0.40 · HIT ×7 backstop · ROT_NECRO 0.45 | `arena.lua:32-67,902-907` ; `ops.lua:24,30` |
| Reliques (39+9 refonte) | lisibles, team-wide, build-time ; `relic_aura_stat` bake direct ; **blood_banner/seers_mark/echo_crown/gravediggers_due/splitting_maw/…** déjà là, gated | `relics.lua` (tout le fichier) |
| Aggro (P6) | activée, AGGRO_STD=10 ; tank ~40 + `gravewarden`/`aegis_warden` taunt | `arena.lua:35,133` ; `units.lua:451,528` |
| Murmures (caché) | `whispers.lua` data-pure + lint, log 2 canaux, snapshot gratuit | `arena.lua:307-334` |
| Snapshot async | capture/encode/decode/toComp + serve par version/tier + cold-start IA | `src/net/snapshot.lua`, `snapstore.lua` |
| **`window.SPAWN`** (9 tokens engeance) | grubling/spiderling/sporeling/ratling/mote/slimelet/implet/boneling/swarmling (parent + invoque_par) | `docs/generation/generateur-bestiaire.html:476-487` |
| **`IMPOSANCE`** (re-tier) | 1..10 par archétype (spawns = 0) | même fichier `:488-514` |

### Les SEULS trous moteur réels (ce plan les comble)

1. **Pas d'op `summon`** → axe **Mort & Engeance** impossible aujourd'hui (le token n'a pas de pont vers la sim).
2. **Pas d'op `repeat_ability`** → axe **Mimétisme** absent.
3. **`aura_stat target="type:X"` PAS câblé** : `build.lua:1600-1619 resolveTargets` gère
   `neighbors/team/role/tier/level` mais **pas `type:`** → axe **Type-identité** inerte (le `type` des
   83 unités est cosmétique, cf. `units.lua` champ `type=`). **Trou le moins cher** (1 branche `ipairs`).

Tout le reste est **data + i18n** sur des ops/handlers existants.

---

## 1. Cible de diversité (la métrique et les parts visées)

### 1.1 La métrique (déjà calculée par `tools/sim.lua`)

- **DoT-share** : part des **dégâts de combat** issus d'altérations (vs frappe directe) — aujourd'hui le
  proxy de la monoculture. La campagne précédente a ramené le **roster** « DoT-pur » à ~85 % par greffes,
  mais l'**identité d'archétype jouée** reste DoT-centrée (le `dot_family` couvre 63/83 unités,
  `units.lua:725-747`).
- **Entropie de Shannon des archétypes gagnants** : cible ≥ **0,90** (la sim sort 0,864 aujourd'hui,
  SUMMARY §3 — le rot contre-spécialiste plombe).
- **`lift` de co-occurrence** < **1,6** (détecteur de combo cassé).
- **Drapeaux d'outliers** : aucune unité/relique/commandant ne dévie > **2σ** de la moyenne du champ.

### 1.2 La cible : passer de 1 axe profond à 8-9 axes équilibrés

On ne mesure pas seulement le DoT-share : on vise une **distribution de l'archétype-définissant du board**
(quel axe porte la victoire). Cible **part de présence côté gagnant** par axe (placeholder, à valider sim) :

| Axe | Aujourd'hui (estim.) | **Cible** | Levier de ce plan |
|---|---|---|---|
| 1. Afflictions & transmission | **~76 %** | **~28 %** | garder le cœur, **cesser d'être le seul** |
| 2. Type-identité (mono / rainbow) | 0 % | **~12 %** | câbler `type:X` (trou #3) |
| 3. Mort & Engeance (summon/faint) | ~2 % (on_death spread) | **~12 %** | op `summon` (trou #1) |
| 4. Mimétisme / méta-multiplicateurs | ~1 % | **~10 %** | op `repeat_ability` (trou #2) + reliques |
| 5. Position / polarité directionnelle | ~5 % (adjacence) | **~10 %** | `target=ahead/behind/above/below` |
| 6. Fréquence (multicast / hâte) | ~6 % | **~8 %** | sources sous cap-3 (déjà là) |
| 7. Tank / Removal / Exécution | ~6 % | **~10 %** | donner du SENS aux caps (execute existe) |
| 8. Économie / tempo | ~3 % (reliques éco) | **~5 %** | Freeze boutique (option) |
| 9. Commandants & Murmures | ~5 % | **~5 %** | exploiter pour l'identité d'équipe |

**Seuil de réussite** : entropie ≥ 0,90 **ET** aucun axe > ~30 % de présence côté gagnant **ET** chaque
axe a ≥ 1 archétype viable (win% ≥ 50 % à coût comparable). Cible d'archétypes **14-18 viables et distincts**
(cf. `effects-overhaul-spec §9.3`).

> **Garde-fou identité (assumé, SUMMARY §3)** : le **rot** restera un **contre-spécialiste** (fort vs murs,
> faible vs burst). On ne le « méta-présente » pas en le dénaturant ; la diversité vient d'**ouvrir d'autres
> axes**, pas d'aplatir le rot.

---

## 2. Plan par AXE (ops moteur · ~N unités · ~N reliques · synergies · golden-safety)

> Convention : `[NEW-OP]` = à `register` dans `ops.lua` ; `[NEW-TARGET]` = branche dans
> `build.lua:resolveTargets` ; `[EXISTING]` = déjà là, on ne fait que de la data. **Tous gated** (aucune
> unité du scénario golden ne porte l'effet → empreinte inchangée jusqu'à rebaseline contrôlée par vague).

---

### AXE 1 — Afflictions & transmission (HAVE — le cœur ; on l'amincit, on ne le coupe pas)

**Ops** : aucun nouveau. **Action** : **re-distribuer**, pas ajouter. Le roster a 63/83 unités DoT
(`units.lua:725-747`). On **convertit ~12-15 unités DoT redondantes** vers les axes 2-7 (re-map d'effet
sur le même sprite, comme la campagne précédente l'a fait pour 15 greffes). On **garde 5-6 unités/famille**
(5 familles → ~28 unités DoT), assez pour les archétypes Plague/Pyre/Bleed/Rot/Storm.

- **Unités** : 0 nouvelles ; **~12-15 re-mappées sortantes** (deviennent des hôtes des axes 2-7).
- **Reliques** : 0 nouvelles (les 4 amplis `kings_bowl/ember_heart/weeping_nail/grave_cap` + transformatives
  `everburn/open_wounds/plague_communion/forked_tongue` suffisent).
- **Synergies clés** : contagion (`plague_bearer`), spread-on-death (`wildfire_hound`/`blight_spreader`),
  convert (`marrow_drinker`), aggravate (`bloodletter`), festering. **Inchangées.**
- **Golden-safety** : re-map = **rebaseline contrôlée par vague** (et seulement si une unité du scénario
  golden change). Tant qu'on re-mappe des unités **hors** scénario golden → empreinte inchangée.

---

### AXE 2 — Type-identité (Batomon — le levier #1, coût quasi nul)

> **Le moteur est à un `if` près.** `aura_stat` sait cibler par sous-ensemble (tier/level) ; il manque la
> branche `type:X`. Les 5 types `flesh/bone/arcane/abyss/order` existent comme champ data.

- **Ops / targets** :
  - `[NEW-TARGET]` **`type:X`** dans `build.lua:resolveTargets` (≈ la branche `tier:N` : itère `placed`,
    `byCell`, `Units[q.id].type == X`). **+** miroir dans `relics.lua:resolveRoleSpec`/`R.apply` (un
    `relic_aura_stat target="type:flesh"`) **+** dans `arena.lua:spawn` si un grant_team doit lire le type.
  - **Rainbow** = `[NEW-OP]` léger **`aura_per_unique_type`** : au build, compte les types **distincts** du
    board → bake `+flat dmg/hp` (Prismagon/Rainbow-Berry de Batomon). Build-résolu, déterministe.
- **Unités (~6 nouvelles + ~4 re-mappées)** — 1 « primary star » mono-type par type + 1 rainbow-payoff :
  - **`flesh_warband`** (mono-flesh) : `{combat_start, aura_stat, target="type:flesh", {stat="atkInc", value=0.10}}`
    — *« la meute saigne ensemble ».*
  - **`bone_choir`** (mono-bone) : `{combat_start, aura_stat, target="type:bone", {stat="dmgReduce", value=0.08}}`
    — *« os sur os, rien ne passe ».*
  - **`arcane_seer`** (mono-arcane) : `{combat_start, aura_stat, target="type:arcane", {stat="haste", value=0.08}}`.
  - **`abyss_maw`** (mono-abyss) : `{combat_start, aura_stat, target="type:abyss", {stat="poisonInc", value=0.15}}`
    (croise l'axe 1 : commandant Toxique-de-type).
  - **`order_marshal`** (mono-order) : `{combat_start, aura_stat, target="type:order", {stat="regen", value=2}}`.
  - **`prism_horror`** (rainbow) : `{combat_start, aura_per_unique_type, {dmgPerType=2, hpPerType=4}}`
    — *« chaque chair étrangère le nourrit ».*
- **Reliques (~3 nouvelles)** — calque Batomon Orb, gating par type (le gating **n'existe pas** chez nous) :
  - **Sang-de-Meute** (mid) : `relic_aura_stat {stat="atkInc", target="type:flesh", value=0.08}`.
  - **Orbe-de-Bile** (mid) : `relic_aura_stat {stat="poisonInc", target="type:abyss", value=0.12}`.
  - **Spectre-Prismatique** (high) : `relic_add_effect`/build → `aura_per_unique_type {dmgPerType=3}`
    (le payoff rainbow team-wide ; *réécrit* « plus tu mélanges, plus tu frappes »).
- **Synergies clés** : mono-type = empile les amplis same-type (commandant + relique + unité) ; rainbow =
  punit l'empilage et récompense le toolbox (axe 7 removal aime le rainbow). **Deux stratégies opposées
  lisibles** (la colonne vertébrale d'identité qui manque).
- **Golden-safety** : `type:X` est une branche **inerte** tant qu'aucun spec ne la cible. `aura_per_unique_type`
  est gated (aucune unité golden ne le porte). Caps existants (ATK_INC 1.5, etc.) bornent l'empilage.
  **Aucune RNG.**

---

### AXE 3 — Mort & Engeance (SAP — NOUVEAU, le fit thème maximal)

> *La greffe signature.* Vie-par-entité est déjà notre modèle (les unités meurent par combat). On a
> `on_death`/`on_kill`/`on_ally_death` (`arena.lua:836-871`) et **9 tokens `SPAWN`** prêts. Il manque
> l'op `summon` et la **règle de placement** (la grande question ouverte).

- **Ops** :
  - `[NEW-OP]` **`summon {token, count, atk?, hp?, cd?}`** (trigger `on_death`) : à la mort du porteur,
    **insère N unités-token** dans `self.units` du **camp du mort**, au **placement déterministe** (§6).
    Le token lit `window.SPAWN[token].parent` → `creaturegen.cached` pour le visuel (hérite des anims du
    parent), stats faibles (imposance 0). **Anti-boucle** : `count` borné + **gouverneur « N fois/combat »**
    (compteur `u._summonsLeft` posé au build, décrémenté ; cf. §6).
  - `[NEW-OP]` **`scavenge_on_ally_death {stat, value, cap}`** (trigger `on_ally_death`) : **stats only**
    (gagne `+atk`/`+hp` quand un allié tombe — le « Shark/Mammoth » SAP). Cumul cappé. *Déjà conforme à
    l'ordre §2.4.1 : on_ally_death est stats-only par contrat.*
  - `[EXISTING]` **`heal_on_kill`** (`ops.lua:433`) sert déjà l'attrition inversée.
- **Unités (~7 nouvelles)** — invocateurs + faint-payoff, **par tokens existants** :
  - **`brood_mother`** (abyss, invoque `spiderling`) : `{on_death, summon, {token="spiderling", count=2}}`
    — *« le ventre crève, mille pattes courent ».*
  - **`larval_host`** (bone, invoque `grubling`) : `{on_death, summon, {token="grubling", count=2}}`.
  - **`spore_sac`** (arcane, invoque `sporeling`) : `{on_hit, poison,…}` **+** `{on_death, summon, {token="sporeling", count=2}}`
    (croise l'axe 1 : meurt en répandant la spore **vivante**).
  - **`rat_warren`** (flesh, invoque `ratling`) : `{on_death, summon, {token="ratling", count=3}}`
    — la marée du Puits.
  - **`carrion_choir`** (faint-payoff) : `{on_ally_death, scavenge_on_ally_death, {stat="dmg", value=2, cap=8}}`
    — *« plus la fosse se vide, plus il enfle ».*
  - **`bone_harvest`** (faint-payoff, bone) : `{on_ally_death, scavenge_on_ally_death, {stat="hp", value=3, cap=12}}`.
  - **`pit_shepherd`** (engeance-carry, abyss) : `{on_death, summon, {token="boneling", count=2}}` **+** une
    petite aura de type (croise l'axe 2).
- **Reliques (~3 nouvelles)** :
  - **Couvée-Noire** (mid) : `relic_add_effect {on_death, summon, {token="boneling", count=1}}` team-wide
    (chaque mort alliée laisse un os qui se relève — borné par le gouverneur).
  - **Pilule-du-Sommeil** (mid, **sacrifice**) : `runOp` sur le RUN — **sacrifie l'unité la plus faible**
    au combat_start pour déclencher sa mort (le « Sleeping Pill » SAP). *Fabrique* le combo death-payoff.
    **Build-state / déterministe** (résolu avant le combat, snapshot-safe).
  - **Charnier-Sans-Fin** (high) : `grant_team {summonCapBonus=2}` — relève le plafond « N fois/combat »
    (réécrit une règle, late).
- **Synergies clés** :
  - **Charnier/Reanimator** : invocateurs + `carrion_choir` (faint-payoff) + `heal_on_kill` →
    le board se **renouvelle** et **enfle** à mesure qu'il meurt (l'attrition inversée).
  - **Engeance × type** (axe 2) : les tokens héritent du `parent` → un board mono-bone qui invoque des
    `boneling` reste mono-bone → les amplis same-type touchent **aussi les engeances**.
  - **Engeance × spread** (axe 1) : `spore_sac` meurt → spore vivante **+** contagion → double payoff.
- **Golden-safety** : `summon` **insère** dans `self.units` → **doit tenir hors du scénario golden** (toute
  unité golden qui invoque ⇒ rebaseline ; on les place hors golden). **Déterminisme** : insertion en **fin**
  de `self.units` (array, `ipairs`), placement **pur** (§6), **aucune RNG** dans le choix de slot. Le
  broadcast `on_death` traite déjà les morts en file figée — l'insertion se fait **après** le broadcast de la
  frame (pas de ré-entrance). **Terminaison** : `count` borné + gouverneur + cap de board (9+commandant) →
  pas d'invocation infinie (à prouver par `tests/props.lua` fuzz, cf. §4).

---

### AXE 4 — Mimétisme / amplification (SAP+Batomon — NOUVEAU, theory-craft pur)

> Le pattern **Tiger** : une unité = **fonction d'une autre**. Tombe direct dans notre bus d'effets. Thème
> « mimétisme eldritch » (une chose qui imite une autre) = très Cthulhu.

- **Ops** :
  - `[NEW-OP]` **`repeat_ability {who, level?}`** : **re-exécute les effets `on_hit` du voisin** (champ
    `who="ahead"/"neighbors"`) au niveau du copieur. **Contrat dur (anti-aliasing)** : NE rappelle PAS
    `hit()` (le `ctx` est réutilisé → aliasing, cf. `effects-overhaul-spec §2.0.3`). À la place, **résolu
    au combat_start comme une aura** : `repeat_ability` **copie les descripteurs `on_hit` du voisin dans la
    liste d'effets du copieur** (build-résolu via le graphe, `build.lua`), **profondeur 1** (on ne copie pas
    un effet déjà copié → flag `viaCopy`). Déterministe, zéro RNG, pas de ré-entrance.
  - `[NEW-OP]` (méta-multiplicateur) **`amplify_auras {frac}`** = le **Zenith-Stone** : au build, **+frac**
    sur les valeurs d'aura déjà bakées par le porteur/l'équipe (relit `statBuf`, ré-applique en `increased`,
    cappé). Build-résolu, déterministe.
- **Unités (~3 nouvelles)** :
  - **`mimic_spawn`** (abyss) : `{combat_start, repeat_ability, {who="ahead"}}` — *« il devient ce qu'il
    dévore ».* À placer **derrière** un carry on_hit.
  - **`echo_flesh`** (flesh) : `{combat_start, repeat_ability, {who="neighbors"}}` (copie le **plus fort**
    voisin on_hit ; tie-break déterministe slot asc).
  - **`hollow_crown`** (arcane, méta) : `{combat_start, amplify_auras, {frac=0.20}}` — *« toutes les
    voix résonnent plus fort autour de lui ».* (le Zenith-Stone incarné en unité).
- **Reliques (~3 nouvelles, les méta-multiplicateurs)** — *la combinatoire « broken » qu'on n'a pas* :
  - **Pierre-du-Zénith** (high) : `relic_aura_stat` méta → `amplify_auras {frac=0.15}` team-wide
    (Batomon Zenith Stone : « +X à tout gain d'aura »). **Sous les caps** (ATK_INC 1.5 plafonne).
  - **Câble-de-Liaison** (high) : **Link-Cable** — les effets `target="neighbors"` deviennent
    `target="column"`/`team`. Build-résolu : au bake, **élargit la portée** des auras d'adjacence.
    *Réécrit une règle de portée.*
  - **Double-Langue** (high) : **Onsetra** — l'unité `role:back` voit ses effets `combat_start`
    **appliqués 2×** (le « cast 2× » de l'allié de gauche). Build-résolu, borné.
- **Synergies clés** :
  - **Echo × affliction** (axe 1) : `mimic_spawn` derrière `corruptor` → **double** la pose de poison **et**
    de vuln → snowball **borné** par POISON_STACK 8 / VULN_INC 0.5.
  - **Zénith × type** (axe 2) : Pierre-du-Zénith amplifie les auras de type → mono-type devient explosif
    (mais cappé).
  - **Câble-de-Liaison × empower** : `maggot_king` (empower neighbors) → empower **colonne entière**.
- **Golden-safety** : `repeat_ability`/`amplify_auras` sont **build-résolus** (comme `aura_stat`) → l'arène
  ne change pas, **golden inchangé** tant qu'aucune unité golden ne les porte. **Profondeur 1** (`viaCopy`)
  + caps → pas d'explosion. **Aucune RNG.** Le **budget work-queue 256** (roadmap moteur) n'est PAS requis
  (build-résolu, pas de chaîne combat-time).

---

### AXE 5 — Position / polarité directionnelle (NOUVEAU, version riche de SAP)

> SAP rend ses buffs **directionnels** (Dodo veut être *derrière*, Flamingo *devant*) → on ne peut pas
> satisfaire les deux → le placement **est** le puzzle. Notre graphe 3×3 est une version plus riche. On a
> déjà `role:front/back/center` ; il manque le **relatif au porteur** (ahead/behind/above/below).

- **Ops / targets** :
  - `[NEW-TARGET]` **`ahead/behind/above/below`** dans `build.lua:resolveTargets`, **relatifs à la cellule
    (x,y) du porteur** (cf. `cells[i]={x,y}`, `shapes.lua:22`) :
    - **ahead** = même `y`, `x` immédiatement plus grand (vers le front) ; **behind** = `x` plus petit.
    - **above** = même `x`, `y-1` ; **below** = `y+1`.
    - **Couplage exposition (clé)** : ahead/behind sont sur l'axe **X = depth** (front/back, **exposition-couplé**) ;
      above/below sur l'axe **Y = rows** (tie-break ciblage, **exposition-neutre**). → un buff `behind`
      (carry protégé) vs un buff `ahead` (s'expose) = vrai dilemme.
  - Build-résolu depuis (x,y) → **déterministe, golden-safe**.
- **Unités (~4 nouvelles + ~3 re-mappées)** :
  - **`vanguard_drummer`** : `{combat_start, aura_stat, target="behind", {stat="atkInc", value=0.15}}`
    — *buff le carry **derrière** moi* (je veux être devant lui).
  - **`rear_goad`** : `{combat_start, aura_stat, target="ahead", {stat="haste", value=0.12}}`
    — *presse celui **devant*** (je veux être derrière lui). **Polarité opposée** au précédent.
  - **`spine_column`** : `{combat_start, aura_stat, target="above", {stat="dmgReduce", value=0.12}}` **+**
    `target="below"` (protège la **colonne** verticale, exposition-neutre).
  - **`tide_caller_v2`** : `{combat_start, aura_stat, target="ahead", {stat="multicast", value=1}}`
    (l'écho directionnel — pousse la frappe de celui devant).
- **Reliques (~2 nouvelles)** :
  - **Étendard-d'Arrière** (mid) : `relic_aura_stat {stat="atkInc", target="behind", value=0.10}` (équipe).
  - **Lance-de-Front** (mid) : `relic_aura_stat {stat="dmgReduce", target="ahead", value=0.10}`.
- **Synergies clés** : la **tension de placement** — `vanguard_drummer` (buff behind) **devant** un carry,
  `rear_goad` (buff ahead) **derrière** un autre → on **ne peut pas** mettre les deux buffs sur le même
  porteur → le board est un puzzle d'orientation. Croise l'axe 6 (multicast directionnel).
- **Golden-safety** : nouvelles branches `resolveTargets` **inertes** tant qu'aucun spec ne les cible.
  Build-résolu, `ipairs`, **aucune RNG**. Caps existants bornent.

---

### AXE 6 — Fréquence (HAVE — multicast/hâte ; on étoffe sous le cap-3)

> Déjà câblé (`MULTICAST_MAX=3`, `HASTE_CAP=0.40`) ; le **choc scale avec la fréquence** (décharge ×
> stacks). Batomon en fait un pilier via **beaucoup de sources** ; nous en avons peu. On en ajoute
> **prudemment** (le cap-3 protège).

- **Ops** : aucun nouveau (`aura_stat {stat="multicast"|"haste"}` suffit).
- **Unités (~2 nouvelles)** :
  - **`storm_conductor`** (arcane) : `{combat_start, aura_stat, target="neighbors", {stat="haste", value=0.10}}`
    **+** un petit `shock` (auto-synergie fréquence×choc).
  - **`echo_warden`** (abyss) : `{combat_start, aura_stat, target="role:center", {stat="multicast", value=1}}`
    (multicast au nœud central — récompense le placement carry).
- **Reliques** : 0 nouvelles (`echo_crown`, `whetstone` couvrent ; les méta-multiplicateurs de l'axe 4
  amplifient la fréquence indirectement).
- **Synergies clés** : multicast × empower × vuln = **3 multiplicateurs composés** (le cas dur à border,
  `effects-overhaul-spec §9.1`) — **sous chaque cap** (ATK 1.5 / VULN 0.5 / MULTI 3). multicast × choc =
  décharge multipliée (consommée 1×/sous-coup, contrat `arena.lua:798`).
- **Golden-safety** : data sur ops existants, gated. Le cap-3 + HASTE 0.40 garantissent la **terminaison**
  (timer d'attaque jamais ≤ 0, `arena.lua:781`).

---

### AXE 7 — Tank / Removal / Exécution (NOUVEAU emphasis — donne du SENS aux caps)

> **L'insight SAP du cap → endgame de removal.** On a déjà les caps (lecture) ; il manque l'**endgame qui
> les rend stratégiques** : quand les deux boards sont cappés, on **ne peut plus out-stat** → la victoire
> appartient au **removal %-PV / exécution / ciblage chirurgical**. `execute` existe (`ops.lua:338`) ; on
> en fait un **axe**.

- **Ops** :
  - `[EXISTING]` **`execute`** (`ops.lua:338`, on_attack, état pur, zéro RNG) — déjà sur `marauder` + relique
    `gravediggers_due`. On **multiplie les hôtes**.
  - `[NEW-OP]` **`percent_hp_strike {frac, cap}`** (on_attack) : retire `frac` des **PV max** de la cible
    (le « Skunk −33 % » SAP), **borné en valeur absolue** (`cap`) pour ne pas one-shot. État pur, déterministe.
  - `[NEW-OP]` (anti-tank ciblé) **`strike_highest_hp {bonus}`** : tie-break de ciblage qui **vise le PV max
    le plus haut** (le tueur de murs). Résolu dans `chooseTarget` comme override léger (faible, documenté).
- **Unités (~5 nouvelles + ~2 re-mappées)** :
  - **`headsman`** (bone) : `{on_attack, execute, {threshold=0.30, bonus=0.80}}` — *le bourreau du Puits*.
  - **`culler`** (flesh) : `{on_attack, percent_hp_strike, {frac=0.10, cap=12}}` — grignote les gros PV.
  - **`wallbreaker`** (abyss) : `{on_hit, strip_shield,…}` **+** `{on_attack, percent_hp_strike,…}` (anti-mur).
  - **`siege_titan`** (order, **tank-removal hybride**) : gros PV + taunt **+** `percent_hp_strike` (le mur
    qui perce les murs).
  - **`reaper_shade`** (abyss) : `{combat_start, aura_stat, target="team", {stat="execImbue"}}` — *aura* qui
    donne un petit execute à toute l'équipe (un `[NEW-OP]` `grant_team {teamExecute={threshold,bonus}}` lu
    dans `hit()`, additif borné).
- **Reliques (~2 nouvelles)** :
  - **Faux-du-Moissonneur** (high) : `grant_team {teamExecute={threshold=0.25, bonus=0.40}}` — toute
    l'équipe achève les blessés (réécrit la fin de partie).
  - **Marteau-de-Siège** (mid) : `relic_add_effect {on_attack, percent_hp_strike, {frac=0.08, cap=10}}`.
- **Synergies clés** : **Wall&Execute** — un mur (axe tank) qui **tient** pendant que le removal **perce**
  les gros PV adverses ; **counter du late-cap** (vs un board all-stat cappé, le removal %-PV ignore les
  PV bruts). Croise l'axe 2 (rainbow toolbox aime un removal flexible).
- **Golden-safety** : `percent_hp_strike`/`strike_highest_hp`/`teamExecute` **gated** ; **état pur, zéro
  RNG** (on_attack mute `ctx.amount` AVANT damage, conforme `§2.0.2`). `cap` absolu + HIT ×7 backstop
  empêchent le one-shot. **Le commandant est `untargetable`** → jamais d'execute sur lui (`arena.lua:354`).

---

### AXE 8 — Économie / tempo (HAVE — léger ; option Freeze)

> Le plus mince comme *axe de build* (l'éco sert le build, elle n'**est** pas un build). On a or fixe,
> reroll, level=slot, streaks, reliques éco (`relics.lua` section G). **Option** : ajouter **Freeze**
> (verrouiller une offre boutique d'un tour à l'autre) = planification cross-turn cheap et forte.

- **Ops** : aucun moteur de combat. **`shop_freeze`** = **runOp** (RunState), hors SIM.
- **Unités** : 0 (l'éco passe par reliques/boutique).
- **Reliques (~1 nouvelle, optionnelle)** :
  - **Sceau-de-Givre** (low/mid) : `runOp` — **Freeze 1 offre** par round (la garde pour le revenu plein).
- **Synergies clés** : Freeze + reliques éco (`usurers_ledger` intérêt) → *fabriquer* un build cible (garder
  l'unité-clé jusqu'à pouvoir l'acheter) au lieu de l'espérer. Sert **tous** les autres axes (forçage de
  combo, cf. l'insight Batomon « items pour FORCER un build »).
- **Golden-safety** : **hors SIM** (RunState, `tests/run.lua`) → **golden combat inchangé** par construction.

---

### AXE 9 — Commandants & Murmures (HAVE — ours ; on exploite pour l'identité d'équipe)

> Déjà livré (`arena.lua:255-334`, 83 commandBonus + murmures cachés). On ne refait rien ; on **exploite**
> le commandant comme **porteur d'identité d'axe** (un commandant Toxique → l'équipe gagne du poison = lie
> commandant ↔ type ↔ affliction).

- **Ops** : 0 nouveaux. Les commandBonus existants couvrent (cf. `units.lua` chaque `commandBonus`).
- **Action** : **2-3 commandants** re-thématisés pour porter un **axe** :
  - un commandant **Type** : `{combat_start, aura_stat, target="type:abyss", {stat="poisonInc", value=0.18}}`
    (sur une unité abyss existante) — *« la marée toxique obéit ».*
  - un commandant **Engeance** : `grant_team {summonCapBonus=1}` (relève le plafond d'invocation de l'équipe).
  - un commandant **Removal** : `grant_team {teamExecute={threshold=0.20, bonus=0.30}}`.
- **Murmures** : restent **du spice caché** (plafond ~stat plate / one-shot, log cryptique). On ajoute
  2-3 murmures liés aux **nouveaux lore** (engeance/mimétisme) — **non build-defining**.
- **Golden-safety** : commandant = aura **build-résolue** (l'arène ne connaît pas le plateau → zéro
  couplage) ; murmures gated + log RENDER-only. **Snapshot du commandant + synergie-famille = différé**
  (SUMMARY §4 : effet **LOCAL solo** tant que le schéma snapshot ne les encode pas — à faire **avant** le
  multi async).

---

## 3. Palette d'ARCHÉTYPES cross-axes (les builds concrets à viser)

> Chaque archétype = **intersection d'axes** (le produit cartésien qui fait la profondeur). 14-18 cibles.
> Les unités/reliques entre `[ ]` sont celles (existantes + nouvelles de ce plan) qui l'activent.

| # | Archétype | Axes croisés | Pièces maîtresses |
|---|---|---|---|
| 1 | **Charnier / Reanimator** | 3 (mort) × 6 (renouvellement) | `[brood_mother, rat_warren, carrion_choir, heal_on_kill, Couvée-Noire, Charnier-Sans-Fin]` |
| 2 | **Nécromancie d'os** | 3 (engeance) × 2 (type bone) | `[larval_host(→boneling), bone_choir, bone_harvest, Orbe-de-Bile, mono-bone amps]` |
| 3 | **Écho / Mimétisme** | 4 (copie) × 1 (affliction) | `[mimic_spawn, echo_flesh, corruptor, festering, Pierre-du-Zénith]` |
| 4 | **Mur & Exécution (Wall&Execute)** | 7 (removal) × tank | `[gravewarden, siege_titan, headsman, culler, Faux-du-Moissonneur, Marteau-de-Siège]` |
| 5 | **Toolbox Arc-en-ciel** | 2 (rainbow) × 7 (removal flexible) | `[prism_horror, Spectre-Prismatique, headsman, 1 unité/type]` |
| 6 | **Peste qui se propage** | 1 (contagion) × 3 (spore vivante) | `[plague_bearer, spore_sac(→sporeling), venom_censer, plague_communion]` |
| 7 | **Mono-Toxique** | 2 (type abyss) × 1 (poison) × 9 (commandant) | `[abyss_maw, ink_horror, deep_kraken, commandant Toxique, Orbe-de-Bile, kings_bowl]` |
| 8 | **Forge d'Échos (fréquence)** | 6 (multicast/hâte) × 4 (méta) | `[hookjaw, maggot_king, echo_warden, echo_crown, Pierre-du-Zénith, storm_conductor]` |
| 9 | **Orage (choc × fréquence)** | 1 (choc) × 6 (fréquence) | `[stormlord, dynamo_priest, arc_warden, storm_conductor, forked_tongue]` |
| 10 | **Phalange directionnelle** | 5 (polarité) × tank | `[vanguard_drummer, rear_goad, spine_column, Étendard-d'Arrière, Lance-de-Front]` |
| 11 | **Bûcher (burn front-load)** | 1 (burn) × 7 (execute des blessés) | `[pyre_tender, kiln_warden, ash_maw, everburn, headsman]` |
| 12 | **Saignée d'attrition** | 1 (bleed) × 5 (buff behind carry) | `[bloodletter, tendon_render, slow_bleed, vanguard_drummer, open_wounds]` |
| 13 | **Rot anti-mur** (contre-spé assumé) | 1 (rot) × 7 (percent-HP) | `[necro_leech, pit_maw, patient_worm, culler, grave_cap]` |
| 14 | **Sacrifice-combo** | 3 (mort, sacrifice) × 4 (méta) | `[Pilule-du-Sommeil, carrion_choir, brood_mother, amplify_auras]` |
| 15 | **Empire mono-Order (mur regen)** | 2 (type order) × tank | `[order_marshal, oath_keeper, ward_weaver, mono-order amps]` |
| 16 | **Rush boutique (forçage)** | 8 (éco/Freeze) × n'importe quel axe | `[Sceau-de-Givre, usurers_ledger, black_summons]` |

---

## 4. Liste moteur consolidée (chaque op/trigger/target + note golden-safety)

> **Règle dure** : re-frapper au niveau `update()` ; nouveaux triggers différés = ctx dédié ; **aucune RNG
> dans `damage()`** ; SIM sans `love.graphics` ; `ipairs` partout. Tout **gated** (nil=inerte) → golden
> `1176281181` tient jusqu'à rebaseline **contrôlée par vague**.

### 4.1 Nouveaux TARGETS (dans `build.lua:resolveTargets` + miroir `relics.lua`)

| Target | Mécanique | Golden-safety |
|---|---|---|
| **`type:X`** | itère `placed`, `Units[q.id].type == X` (≈ branche `tier:N`) | inerte tant qu'aucun spec ne le cible ; build-résolu, `ipairs`, zéro RNG |
| **`ahead` / `behind`** | relatif (x,y) du porteur sur l'axe X (depth) | idem ; **exposition-couplé** (assumé) |
| **`above` / `below`** | relatif (x,y) sur l'axe Y (rows) | idem ; **exposition-neutre** |
| **`column` / `row`** (option, pour Link-Cable) | tous les slots de même x / même y | idem ; sert le méta-multiplicateur de portée |

### 4.2 Nouveaux OPS (dans `ops.lua`)

| Op | Trigger | Mécanique | Golden-safety / déterminisme |
|---|---|---|---|
| **`summon`** | on_death | insère N tokens `SPAWN` dans `self.units` (camp du mort), placement déterministe §6, gouverneur `_summonsLeft` | **hors golden** (insertion change la sim) ; insertion **après** broadcast de frame ; placement **pur**, **zéro RNG** ; count borné + gouverneur → terminaison (props.lua) |
| **`scavenge_on_ally_death`** | on_ally_death | **stats only** (+atk/+hp, cap) | conforme ordre §2.4.1 (ally_death = stats-only) ; gated ; `ipairs` |
| **`repeat_ability`** | combat_start (build-résolu) | copie les descripteurs `on_hit` du voisin (`who=ahead/neighbors`), **profondeur 1** (`viaCopy`) | build-résolu (comme aura_stat) → arène inchangée ; pas de ré-entrance `hit()` ; zéro RNG |
| **`amplify_auras`** | combat_start (build-résolu) | +frac sur les valeurs d'aura déjà bakées (relit statBuf, `increased`, cappé) | build-résolu ; gated ; caps bornent ; zéro RNG |
| **`aura_per_unique_type`** | combat_start (build-résolu) | compte les types distincts du board → +flat dmg/hp | build-résolu ; déterministe ; gated |
| **`percent_hp_strike`** | on_attack | retire `frac` des PV max (cap absolu) ; mute `ctx.amount` AVANT damage | état pur, **zéro RNG** ; cap + HIT ×7 backstop = pas de one-shot ; commandant untargetable |
| **`strike_highest_hp`** | (ciblage) | tie-break léger vers le PV max le plus haut, dans `chooseTarget` | pure fonction d'état ; documenté **faible** ; zéro RNG |
| **`grant_team {teamExecute}`** | combat_start | drapeau lu dans `hit()` : petit execute d'équipe | gated (flag nil) ; état pur ; additif borné |
| **`grant_team {summonCapBonus}`** | combat_start | relève `_summonsLeft` de l'équipe | gated ; borné |
| **`grant_team {summonsLost?}` / Link-Cable / Onsetra** | combat_start (build) | élargit la portée / double un combat_start `role:back` | build-résolu ; borné ; gated |

### 4.3 Triggers / runOps

- **Triggers** : aucun nouveau (on_death/on_kill/on_ally_death/combat_start/on_attack suffisent). Le
  contrat d'ordre §2.4.1 (`arena.lua:836-871`) **couvre déjà** summon (on_death) et scavenge (on_ally_death).
- **runOps (hors SIM, RunState)** : `summon`-**sacrifice** (Pilule-du-Sommeil) ; `shop_freeze`
  (Sceau-de-Givre). **Golden combat inchangé** (RunState, pas l'arène).

### 4.4 Travail moteur d'intégration (au-delà des ops)

- **`summon`** : un **pont token→spec** (lire `window.SPAWN` côté Lua : porter la table `SPAWN`/`IMPOSANCE`
  dans `src/data/` en data pure, ou un `src/data/spawns.lua` dérivé). Le token a un id, un `parent` (pour
  `creaturegen.cached` → visuel + anims), des stats faibles. **Data pure, golden-neutre** tant qu'inutilisé.
- **Snapshot** : `summon`/`repeat_ability`/type-auras sont **build-résolus** → un ghost les rejoue
  **gratuitement** (comme les murmures) **SAUF** si l'effet dépend d'un état non-encodé (synergie-famille,
  commandant). **Décision** : encoder le **commandant + statBonus** dans le schéma snapshot **avant** le
  multi async (dette connue, SUMMARY §4) ; jusque-là ces effets sont **LOCAUX solo**.
- **Work-queue (budget 256)** : **NON requise** — tout le nouveau combat-time (`percent_hp_strike`,
  `summon`) est **profondeur 1 / borné** ; le reste est build-résolu. (Le seul cas combat-chaîné resterait
  multicast×cleave, déjà borné par MULTICAST_MAX×profondeur-1.)

---

## 5. Rollout séquencé (vagues, dépendances, leverage × thème × réutilisation)

> Chaque vague : **indépendamment verte** (`sh tools/check.sh`) + **golden-safe** (gated ou rebaseline
> contrôlée). Ordre = leverage × fit thème × réutilisation. **Chaque vague committée** (git-warden,
> `feat/big-update-effects` depuis `dev`).

| Vague | Contenu | Pré-requis moteur | Pourquoi cet ordre | Golden |
|---|---|---|---|---|
| **W0 — Filets** | étendre `tools/sim.lua` : **part par AXE** (pas juste DoT-share) + drapeaux par axe ; baseliner l'état actuel | — | mesurer AVANT de bouger ; sinon on tune à l'aveugle | inchangé |
| **W1 — Types** (axe 2) | `[NEW-TARGET] type:X` + `aura_per_unique_type` ; 6 unités mono/rainbow + 3 reliques ; câbler `type` (cosmétique→actif) | branche `resolveTargets` (trivial) | **leverage max / coût min** (moteur à un `if` près) ; pose l'identité de build manquante | gated → inchangé (unités hors golden) |
| **W2 — Engeances** (axe 3) | op `summon` + pont `SPAWN`→spec + `scavenge_on_ally_death` ; 7 invocateurs/faint-payoff + 3 reliques (dont sacrifice) | op + pont token ; placement §6 | **fit thème maximal** ; `on_death`/tokens déjà prêts ; débloque l'attrition inversée | **hors golden** (insertion) → placer les invocateurs hors scénario golden ; props.lua terminaison |
| **W3 — Méta-multiplicateurs & Mimétisme** (axe 4) | ops `repeat_ability`/`amplify_auras` ; 3 unités + 3 reliques (Zénith/Link-Cable/Onsetra) | build-résolu (comme aura_stat) | crée la combinatoire « broken » (sous caps) ; valide pilier #2 (amplificateurs) | build-résolu → inchangé tant que hors golden |
| **W4 — Removal/Exécution** (axe 7) | ops `percent_hp_strike`/`strike_highest_hp`/`teamExecute` ; 5 unités + 2 reliques | ops on_attack (état pur) | donne **du sens aux caps** (le late-game cap→removal) ; counter du mur regen (constat SUMMARY §3) | gated → inchangé |
| **W5 — Polarité directionnelle** (axe 5) | `[NEW-TARGET] ahead/behind/above/below` ; 4 unités + 2 reliques | branches `resolveTargets` | densifie la position **sans nouvelle techno** ; tension de placement | gated → inchangé |
| **W6 — Fréquence + Commandants/Murmures d'axe** (axes 6, 9) | 2 unités fréquence ; 2-3 commandants re-thématisés (type/engeance/removal) ; 2-3 murmures neufs | — (ops existants) | étoffe sous cap-3 ; lie commandant↔axe | gated → inchangé |
| **W7 — Re-distribution DoT** (axe 1) | re-mapper ~12-15 unités DoT redondantes vers W1-W5 ; rééquilibrer | toutes les vagues | **casse la monoculture** une fois les autres axes prêts à absorber | **rebaseline contrôlée** (si une unité golden change) |
| **W8 — Éco/Freeze** (axe 8, option) | Sceau-de-Givre + `shop_freeze` runOp | RunState | forçage de combo ; hors SIM | golden combat inchangé |
| **W9 — Équilibrage de masse** | `tools/balancematrix.lua` : bandes EARLY/MID/END × reliques × commandants × **axes** ; tuner **un levier à la fois** | tout | déclarer « équilibré » par les seuils §6 | golden stable final |

**Recommandation affinée** (vs la suggestion d'origine *types→engeances→méta*) : **types d'abord** (coût
quasi nul, débloque l'identité), **engeances ensuite** (fit thème, prépare le terrain mort), **PUIS removal
en W4 AVANT la polarité** — parce que le **constat d'équilibrage actuel** (SUMMARY §3) est qu'aucune compo
ne contre le **mur regen+taunt+purge** ; le **removal** est le **counter manquant**, donc plus prioritaire
que la polarité pour la santé du méta. La re-distribution DoT (W7) vient **après** que les autres axes
peuvent absorber les unités converties.

---

## 6. Garde-fous d'équilibrage (caps, la bascule cap→removal, la soupape temp/perm, le gouverneur lisible)

### 6.1 Les caps (déjà en place, à respecter)

ATK_INC 1.5 · VULN_INC 0.5 · MULTICAST 3 · HASTE 0.40 · DMG_REDUCE 0.60 · DOT ×4 · POISON_STACK 8 ·
WEAKEN 0.40 · SHOCK_STACK 8 · ROT_NECRO 0.45 · **HIT ×7 backstop** (`arena.lua:32-67`). **Tout nouvel
empower/vuln/execute passe SOUS ces caps** (additif `increased`, sur la base). Les méta-multiplicateurs
(axe 4) **amplifient mais restent cappés** (un Zénith-Stone +15 % d'aura ne franchit pas ATK_INC 1.5).

### 6.2 La bascule cap → removal (l'insight central)

Quand les deux boards sont **cappés** (fin de partie), on **ne peut plus out-stat** → la victoire passe au
**removal %-PV / exécution / placement**. **C'est voulu** : `percent_hp_strike` (axe 7) ignore les PV
bruts, `strike_highest_hp` chasse le mur, `execute` achève. → *« les gros chiffres cèdent au placement/au
ciblage malin »*. **Validation** : la sim doit montrer qu'un board **all-stat cappé** perd contre un board
**removal** à coût égal (sinon le removal est sous-tuné).

### 6.3 La soupape temporaire vs permanent

Suivre SAP : les effets **les plus bruyants** = **intra-combat** (« ce combat seulement ») — déjà notre
règle relique (`relics-design`). **Les engeances (axe 3) ne survivent PAS au combat** (tokens détruits en
fin de combat ; le **build** persiste, pas les invoqués). `scavenge`/`frenzy` = **intra-combat** (reset au
spawn). Le **summon-sacrifice** (Pilule) est build-state mais **borné** (1 unité, la plus faible).

### 6.4 Le gouverneur lisible « N fois / combat »

**Uniforme et affiché** (texte de carte) sur tout effet multi-déclenché : `summon` (« relève 2 fois par
combat »), `scavenge` (cap de stacks), `repeat_ability` (profondeur 1). C'est le frein **lisible au joueur**
de SAP (Fly « max 3 fois »). Implémenté par compteurs `_summonsLeft`/`cap` posés au build. **Anti-boucle**
de l'axe mort.

### 6.5 La question OUVERTE clé : la règle de placement des engeances (§ décision requise)

> **C'est LA décision de design à trancher avant W2.** Quand un porteur meurt et invoque N tokens, **où**
> vont-ils sur le board de combat ? Le `slot` (x,y) gouverne le ciblage (depth/row) → ce choix **change le
> combat**. Trois options, avec recommandation :

| Option | Règle | Pour | Contre |
|---|---|---|---|
| **A — Slot du parent (recommandée)** | le token **occupe le slot libéré** par le mort (même x,y → même depth/row) | lisible (« ça pousse là où c'est mort »), déterministe trivial, le token **prend la place** dans la ligne (continuité de front) ; **thématiquement parfait** (l'engeance jaillit du cadavre) | si N>1, les tokens 2..N ont besoin d'un slot de débordement |
| **B — Slot libre le plus proche** | cherche le slot vide le plus proche (tie-break depth puis row) | gère N>1 proprement | moins lisible ; « le plus proche » demande une métrique déterministe stable |
| **C — Débordement perdu** | au-delà du slot parent, les tokens en trop sont **perdus** | borne dure le nombre d'unités sur le board (anti-snowball) ; trivial | « gâche » une partie de l'effet (peut frustrer) |

**Recommandation : A + C combinés** — le **1er token** prend le **slot du parent** (continuité de front,
ciblage cohérent) ; les tokens **2..N** prennent les **slots libres adjacents** (ordre déterministe : voisins
du graphe par index asc) **et au-delà sont perdus** (C). Ça donne : lisibilité (A), gestion de N>1 (voisins),
**borne dure** (C : le board ne dépasse jamais sa capacité + commandant). **Déterministe, zéro RNG, golden-safe**
(hors golden). **À confirmer par toi** (cf. §7 Q1).

### 6.6 Validation via `tools/sim.lua` / `balancematrix.lua`

- **Avant chaque commit de vague** : win% contextualisé par coût (viable si ≥ 50 % à coût comparable) ;
  **part par axe** (W0) ; `lift` < 1,6 ; aucun outlier > 2σ ; entropie ≥ 0,90.
- **Cas durs obligatoires** (`tests/synergies.lua` + `tests/props.lua`) : multicast×empower×vuln (3
  multiplicateurs) ; **summon×fatigue** (terminaison) ; **summon×scavenge** (attrition inversée non-infinie) ;
  repeat_ability×corruptor (double pose bornée) ; percent_hp_strike×tank (le mur tient-il ?) ;
  type-amp×Zénith (empilage sous cap).
- **Principe** : **un levier à la fois**, bas tier faible / haut tier fort, re-balayer après chaque tune.

---

## 7. Questions ouvertes (à trancher — défaut raisonnable proposé)

| # | Question | Défaut proposé |
|---|---|---|
| **Q1 — Placement engeance** (la clé, §6.5) | slot du parent / plus proche / débordement perdu ? | **A+C** : 1er token = slot parent, 2..N = voisins libres, surplus perdu. Lisible + borné + déterministe. |
| **Q2 — Tokens & type** (axe 2×3) | les engeances héritent-elles du `type` du parent (→ comptent dans les amps de type) ? | **Oui** : le token hérite `type=parent.type` → un board mono-bone reste mono-bone (cohérent, renforce l'axe 2). |
| **Q3 — `repeat_ability` portée** | copie on_hit seulement, ou tous les triggers ? | **on_hit seulement** (le Tiger SAP), profondeur 1 — borne la combinatoire, évite de copier des auras/summon. |
| **Q4 — `type:X` & rainbow** | rainbow compte sur le board **ou** sur l'équipe vivante en combat ? | **Au build (board)** : déterministe, snapshot-gratuit (comme les auras). Pas de recompute combat-time. |
| **Q5 — Cap d'invocation** | combien de summons/combat par défaut ? | **2** (gouverneur lisible) ; relevé à 4 par relique high (Charnier-Sans-Fin). |
| **Q6 — Snapshot des nouveaux effets** | encoder commandant/type/summon dans le schéma maintenant ou différer ? | **Différer** (effets LOCAUX solo, cf. SUMMARY §4) ; encoder **avant** d'ouvrir le multi async (dette tracée). |
| **Q7 — DoT cible exacte** | 28 % de part-axe DoT, ou plus haut (c'est notre signature) ? | **~28 %** côté présence-gagnant, MAIS le DoT reste **le plus gros axe seul** (signature préservée, juste plus le seul). |
| **Q8 — `percent_hp_strike` vs PV max** | retire des PV max ou des PV courants ? | **PV max** (le Skunk SAP, anti-mur franc) ; **cap absolu** pour ne pas one-shot un carry. |

---

## 8. Annexe — sources

- **Études internes** (source de vérité, lues en code juin 2026) : `the-pit-vs-batomon-vs-sap.md`,
  `batomon/the-pit-vs-batomon.md`, `sap/sap-digest.md`, `batomon/batodex-digest.md`,
  `effects-overhaul-spec.md` (moteur agnostique livré), `effects-overhaul-SUMMARY.md` (verdict d'équilibrage).
- **Code vérifié** (file:line dans §0) : `engine.lua`, `ops.lua`, `arena.lua`, `build.lua`, `relics.lua`,
  `shapes.lua`, `board.lua`, `units.lua` ; **`generateur-bestiaire.html`** (`SPAWN`/`IMPOSANCE`).
- **SAP design (sourcé)** : a327ex.com/posts/super_auto_pets_mechanics (composabilité Trigger×Effect×Target) ;
  superautopets.wiki.gg (Faint/Summon/Tiger/Skunk/Buffalo) ; twoaveragegamers (cap→removal). SAP est
  patch-volatile : **mécaniques stables**, tier-lists datées.
- **Batomon** : batodex.com (types câblés, Zenith Stone/Link Cable/Onsetra, Prismagon/Rainbow Berry).
- Toutes les **structures** (faint-economy, mimétisme, type-identité, méta-multiplicateurs, cap→removal,
  polarité directionnelle) sont **stables** ; les **chiffres** de ce plan sont des **placeholders** à tuner.
