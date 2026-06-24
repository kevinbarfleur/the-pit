# The Pit — guide projet (CLAUDE.md)

> Autobattler **multijoueur asynchrone**, solo dev, **Lua + LÖVE (Love2D)**, tous les
> visuels **générés procéduralement** (pixel art en grilles + palette, zéro asset dessiné).
> Univers **grimdark cryptique** : Cthulhu × Path of Exile × Dark Souls. On descend *Le Puits*.

Ce fichier est le brief permanent du projet : lis-le au début de chaque session. Les
recherches détaillées vivent dans `docs/research/`, les conventions visuelles dans
`docs/pixel-art/`.

---

## 1. Règles d'or (NON négociables)

### 1.a — Vérifier les API (jamais de mémoire supposée)

**Ne jamais coder/affirmer une API depuis la mémoire supposée. Toujours vérifier sur les
sources primaires** avant d'écrire :
- LÖVE : <https://love2d.org/wiki/Main_Page> (cible **11.5** stable).
- Lua / LuaJIT : <https://www.lua.org/manual/5.1/> (LÖVE embarque LuaJIT ≈ Lua 5.1).
- Pour le code/API : préférer `get_code_context_exa` (Exa MCP). Citer ses sources.

Ce réflexe vaut pour moi **et tous les sous-agents**. Une API non vérifiée = un bug latent.

### 1.b — Le TOP du top, jamais le minimum

Quand l'user demande une feature, il veut **la meilleure version réalisable** avec nos technos —
**pas** la première qui « compile / tourne ». « Ça marche » n'est PAS le standard ; « c'est le
meilleur qu'on puisse faire ici, et c'est vérifié » l'est. **Mieux vaut NE RIEN livrer qu'un truc
bâclé.**

**La qualité est MULTI-DIMENSIONNELLE** — pas seulement technique (perf, robustesse, API vérifiées),
mais aussi **design + visuel + FEELING (game feel)**. The Pit doit être **JUICY** — réf explicites de
l'user : ***Balatro***, ***Tiny Rogue***. Donc, par défaut, penser systématiquement : **impact &
feedback au clic ET au survol** des boutons/cartes (squash/flash/glow/lift — réutiliser le système
`Feel` / juice existant : `src/ui/feel.lua`, `Forge.uiTick`), micro-animations, transitions, punch,
sons/secousses si pertinent. Une feature « correcte » mais **sans jus n'est pas finie**. Avant d'écrire
une feature, dans l'ordre :

1. **Chercher l'existant** (réflexe systématique) : le projet a-t-il déjà un module/asset/convention
   qui fait ça ou s'en approche ? **Réutiliser, s'en inspirer, s'aligner sur la DA établie** —
   ne JAMAIS recréer une version au rabais d'un truc qui existe (ex. un œil = `src/ui/eye.lua` :
   sclère + veines de sang + iris OR à pupille en fente + paupières métal + clignement ; **PAS** un
   blob générique). S'inspirer **du meilleur** de ce qui est déjà là.
2. **Vérifier l'intégration** : est-ce que ça s'imbrique proprement dans ce qui est en cours ? Le
   rendu sera-t-il **à la hauteur du reste** du jeu ? Penser cohérence DA + couplage avant de coder.
3. **Tester au screenshot** : capturer (`--shoot`) **ET juger à l'œil** — propre ? fini ? acceptable ?
   Sinon **itérer AVANT de rendre la main**. Le PC de l'user fait foi (l'export masque les bugs de
   transform). Ne jamais présenter un écran qu'on n'a pas regardé.

Ce réflexe vaut pour moi **et tous les sous-agents** (donner les références de l'existant dans
chaque brief d'agent). Voir aussi [[feedback-top-quality-never-minimum]].

---

## 2. Vision & piliers de design

1. **Simplicité de gestion → profondeur émergente.** La référence d'addictivité du créateur
   est *Batomon Showdown* (SAP en habits de Pokémon Showdown) : pas de timer, gestion d'équipe
   simple. On vise le modèle le plus *simple à implémenter* qui garde une grande rejouabilité.
2. **Reliques (signature du jeu).** Effets **lisibles** : nom évocateur + effet clair (avec le
   chiffre) + flavor d'ambiance. **Révise (2026-06)** l'ancien modèle cryptique à déduire — leurres
   et identification **retirés** (décision user : « pas fan des leurres, trop compliqué pour pas
   grand-chose »). On garde l'ambiance + l'offre **1-parmi-3** (tous les 3 combats) + le **Grimoire =
   collection** persistante au niveau du compte (méta-progression). Garde-fous : **team-wide**,
   **intra-combat only** (aucune relique ne handicape la suite de la partie), **égalisateur** de
   matchup (jamais un gate). Détail : `docs/research/relics-design.md`.
3. **Multijoueur asynchrone par snapshots ("ghosts").** On n'affronte JAMAIS un joueur en
   direct : on stocke des **snapshots figés** de builds réels, servis à d'autres selon
   *progression + rang + version*. Cold-start résolu par des **équipes IA**. Aucune netcode
   temps réel, jouable hors-ligne. C'est le takeaway architectural #1.
4. **Direction artistique = différenciateur.** Sale, sanglant, cryptique. Le thème + quelques
   subtilités suffisent à rendre un genre connu original.

---

## 3. Blueprint de gameplay (synthèse de cohérence)

> Source autoritaire : `docs/research/gd-research-result.md` (brainstorm GD approfondi, 2026-06,
> qui **révise** le blueprint v0) ; synthèse v0 : `docs/research/autobattler-design.md`.
> **Décisions actées (2026-06)** : plateau-graphe 3×3 mutable (et non plus slots linéaires) ;
> **modèle de combat = vie PAR ENTITÉ + ciblage déterministe (colonne→taunt→aggro→tie-break) +
> exposition portée par le sigil** (cf. `docs/research/combat-model-decision.md`).

| Système | Choix retenu | Pourquoi |
|---|---|---|
| Boucle | phase **boutique/build** → **combat auto** (spectateur), répété | standard du genre |
| Plateau | **plateau-graphe 3×3 (9 slots)**, adjacence **orthogonale**, défini en **arêtes explicites** (data, pas code) | la *forme du plateau EST le graphe de synergies* ; centre = 4 voisins = case carry. **PAS** une rangée linéaire (trop pauvre), **PAS** une grille Tetris/Backpack (trop coûteuse) |
| Grille mutable (signature) | **reliques-sigils** redessinent la topologie en **gardant 9 slots** (croix/anneau/diamant/ligne) ; 1 forme = 1 archétype | géométrie **non-euclidienne** = thème lovecraftien ET mécanique fusionnés ; on échange une topologie, pas de la puissance |
| Combat | **cooldowns auto-résolus** (timer→0 = l'entité agit), déterministe + RNG seedé, petits nombres (1–12 s), Fatigue ~17 s | modèle SAP ; **PAS** la timeline temps réel, **PAS** la grille hex TFT |
| Vie & mort | **vie PAR ENTITÉ** : les unités **meurent par combat**, mais le **build persiste sur le run** ; l'**identité est protégée au niveau RUN** (5 vies / 10 victoires), pas au combat | **décision 2026-06** (cf. `combat-model-decision.md`). **PAS** la vie globale Bazaar/Backpack (« monstres immortels » sonne faux en grimdark + supprime l'axe d'exposition). La mort par-combat ≠ build détruit (modèle SAP/TFT) |
| Ciblage | **100% déterministe, zéro dé** (rejouable/async-vérifiable) : colonne **avant** ennemie (`depth` dérivé de la **forme du sigil** = `maxCol - cell.x`) → override **taunt** → **aggro** la plus haute → tie-break **haut→bas**. **L'exposition est portée par le sigil** (« la forme EST aussi le champ de bataille ») | survit à tout changement de forme ; convertit la frustration RNG en skill de placement ; **aggro câblée mais inerte** (on tune quand les plateaux se remplissent) |
| Synergies | **adjacence positionnelle** (le voisin buffe : shock, multicast, bouclier, poison) + bonus par **type** | profondeur sans règle nouvelle ; UI surligne les voisins |
| Duplicatas | **3 copies → niveau (max 3)** ; stats ET buffs d'adjacence scalent | moteur économique TFT, profondeur/effort maximal |
| Leveling | **= déblocage progressif des slots** (on démarre à 2–3, pas 9) | résout la lisibilité du combat ET donne son sens à l'éco de niveau |
| Économie | **or fixe/round + reroll + streaks** ; intérêts/augments en V2 | squelette SAP, le plus simple à équilibrer |
| Reliques | **lisibles** : effet affiché (nom + effet clair + flavor) ; offre **1-parmi-3** tous les 3 combats → **Grimoire = collection** persistante. Team-wide, intra-combat, **égalisateur** de matchup | pilier #2 (révisé 2026-06, cf. `docs/research/relics-design.md`) |
| Multi | **snapshots async** (unités + positions + **sigil actif**) + équipes IA + tag de version ; match par **palier** | pilier #3 |
| Run | **10 victoires avant ~5 défaites** ; vie rendue au tour 3 si perte précoce | convergence SAP/Backpack/Bazaar/Batomon |

Système **couplé** (le prendre en bloc) : 3×3 + adjacence + grille mutable + front/back +
duplicatas + leveling-déblocage s'imbriquent (cf. `gd-research-result.md` §1.10). À **éviter** :
timeline temps réel sur slots, grille 2D Tetris (rotation/recettes), trop de RNG en combat,
égaliser les arêtes de toutes les formes (viser « 1 forme = 1 archétype qui l'aime »).

---

## 4. Décisions techniques (vérifiées)

> Détail + signatures + sources : `docs/research/love2d-tech.md`.

- **Cible LÖVE 11.5.** Couleurs en **floats 0..1** (pas 0..255). `vsync` = nombre.
- **Pas de scene graph** → le rig PixiJS se porte sur la **matrix stack**
  `push → translate → rotate → scale → translate(-pivot) → draw → [enfants] → pop`.
- **Bake, ne jamais dessiner pixel par pixel par frame.** Chaque part = une `Image` bakée une
  fois (`ImageData:setPixel`) filtrée **`nearest`**, puis transformée. Jamais des milliers de
  `rectangle()` par frame.
- **Combat déterministe** = boucle à **pas de temps fixe** (`love.run` surchargée, accumulateur)
  + **RNG seedé INJECTÉ** (`love.math.newRandomGenerator`, passé via `opts.seed`/`opts.rng`), jamais
  `math.random` global pour la sim. Même seed → bataille identique (snapshots async, replays, golden-logs).
- **Système d'effets découplé** (data + registre d'ops + bus ; détail : `docs/research/engine-architecture.md`).
  Un effet = donnée `{trigger, op, params, condition?, target?}` ; ajouter une relique/effet =
  enregistrer un op + une ligne de data, **jamais éditer la boucle de combat** (ouvert/fermé). Couche SIM
  (`src/combat`, `src/board`, `src/effects`) **sans `love.*`** ; tout ordre de sim en **array + `ipairs`**,
  jamais `pairs`. Vérif locale : `sh tools/check.sh` (garde RNG + headless + luacheck si présent).
- **Rendu pixel-perfect** : monde → **canvas virtuel basse réso** (320×180) → blit en **scale
  entier** (×4 = 1280×720), letterbox. Texte d'UI dessiné en **résolution native** (net).
- **Dépendances minimales.** Pour l'instant : **zéro lib externe**. Si besoin plus tard :
  `rxi/classic` (OOP), `hump.timer`/`hump.gamestate`. **Éviter `anim8`** (frame-based, inadapté
  au rigging procédural).
- **Internationalisation (i18n).** Tout le texte affiché passe par `src/core/i18n.lua` (`t(key, vars)`,
  interpolation `{name}`, fallback `en`). Les données (`units`/`shapes`/`encounters`) ne portent que des
  **clés/ids mécaniques** ; les chaînes vivent dans `src/i18n/<code>.lua`. Jeu en **anglais** par défaut ;
  ajouter une langue = **un fichier locale**, zéro refacto. Couverture testée (`tests/i18n.lua`).

---

## 5. Architecture du dépôt

```
conf.lua                  config LÖVE (exécutée avant les modules)
main.lua                  point d'entrée + love.run pas-fixe + canvas virtuel + HUD + host (run + scènes)
src/
  core/
    palette.lua           caractère -> couleur RGBA (floats), palette "Wraeclast"
    sprite.lua            bake grille+palette -> Image nearest (une fois)
    rig.lua               MOTEUR de rigging (build/update/draw + transforms monde)
    bus.lua               bus d'événements DÉTERMINISTE (array+ipairs) pour la couche SIM
    i18n.lua              INTERNATIONALISATION : t(key,vars) + locale courante + fallback en (texte = locales)
    grimoire.lua          GRIMOIRE : codex PERSISTANT des reliques identifiées (méta cross-run ; IO hors SIM)
  i18n/
    en.lua                locale ANGLAISE (défaut/fallback) : TOUTES les chaînes affichées (clé -> texte)
  data/
    creatures.lua         définitions data-only des créatures (grilles/pivots/rig/anims)
    units.lua             stats + EFFETS (descripteurs data) + coût/pool par créature ; combat/build/boutique
    encounters.lua        équipes adverses pré-construites (IA de seed du cold-start)
    relics.lua            RELIQUES CRYPTIQUES (pilier #2) : effet réel + 2 leurres ; apply(comp) au build
  gen/
    creaturegen.lua       GÉNÉRATION procédurale de créatures (déterministe par id) + factions/masks/ramps/details
  combat/
    arena.lua             MOTEUR de combat SIM PUR (zéro love.graphics) : cooldown, hooks d'effets, émet des événements
    place.lua             (col,row) -> position de combat (front/back par colonne)
  effects/
    engine.lua            REGISTRE d'effets : run(porteur, trigger, ctx) + register(op) ouvert/fermé
    ops.lua               ops : bonus_first/lifesteal/thorns + familles burn/bleed/poison/rot/choc/regen
    stats.lua             COUCHE DE MODIFICATEURS (SIM) : resolve(base, mods) flat/increased/more + clamp
  board/
    shapes.lua            formes de plateau = GRAPHES explicites (cases + arêtes), 9 slots
    board.lua             plateau-graphe : slots, adjacence, sigils, déblocage progressif
  run/
    state.lua             ÉTAT DE RUN roguelite, SIM PUR : or/vies/victoires/niveau/boutique + RELIQUES (candidats seedés/identification)
  net/
    snapshot.lua          SNAPSHOT async (pilier #3) : capture/encode sûr/decode/toComp (PUR, sérialisable)
    snapstore.lua         STORE de snapshots : pool persistant + serve par version/tier + cold-start IA (IO hors SIM)
  render/
    arena_draw.lua        RENDER du combat : rigs/anims + love.graphics ; lit la SIM + écoute le bus
  fx/
    background.lua        décor d'ambiance (statique baké + dynamique)
  scenes/
    build.lua             phase BUILD : plateau + BOUTIQUE (achat/reroll/niveau) + drag-drop + infobulles + COMBAT
    combat.lua            phase COMBAT : SIM (arena) + RENDER (arena_draw) ; résultat -> host.finishCombat
    runover.lua           écran de FIN DE RUN (ascension 10 victoires / chute 0 vie) -> nouvelle run
    gallery.lua           écran GALERIE [g] : revue visuelle des entités (générées vs dessinées main)
tests/
  mock_love.lua           mock LÖVE partagé (graphics stub + RNG seedé) pour headless/sims
  headless.lua            smoke + déterminisme + passifs + e2e souris/boutique (mock LÖVE, vraie logique)
  i18n.lua                i18n : interpolation + fallback + COUVERTURE (toute clé de données traduite)
  stats.lua               couche de modificateurs : formule flat/increased/more + commutativité + clamp
  run.lua                 invariants + déterminisme de l'ÉCONOMIE de run (achat/reroll/niveau/streaks/vies)
  auras.lua               AURAS d'adjacence build-résolues (bake du bonus sur le voisin via le graphe du sigil)
  synergies.lua           INTERACTIONS inter-effets en combat (12 : familles + contagion/propagation/aggravate + croisés T3)
  props.lua               invariants + fuzz (PV>=0, terminaison, 1 vainqueur, déterminisme)
  golden.lua              golden-log de régression (empreinte event-log d'un scénario figé)
  duplicatas.lua          DUPLICATAS : fusion 3->niveau + scaling + cascade (niveau 1 = identité, golden-safe)
  relics.lua              RELIQUES : 1-parmi-3 seedé + identification -> Grimoire + méta-progression
  snapshot.lua            SNAPSHOTS : round-trip sûr + toComp + serve version/tier + cold-start IA
  gen.lua                 GÉNÉRATEUR de créatures : déterminisme + validation + smoke rendu + distinction
tools/
  check.sh                garde RNG SIM + firewall + headless + run + props + golden + luacheck
  eventlog.lua            logger d'événements (s'abonne au bus) -> JSONL + empreinte
  sim.lua                 BATCH SIM d'équilibrage : N combats -> stats par unité/effet -> runs/report.json
.luacheckrc               config luacheck : interdit les globals accidentels (anti-spaghetti)
docs/
  research/               rapports de recherche (game design + technique LÖVE)
  pixel-art/              conventions du moteur de rig + pipeline procédural
```

**Convention modules** : un fichier = une table retournée ; `require("src.core.rig")`.
**Convention rig** : parts nommées `head/torso/armBack/armFront/weapon/legs/tail`. Une part
absente est ignorée (pas de crash). Ajouter une créature = pure data.

---

## 6. Lancer & tester

```sh
love .                    # lance la boucle build -> combat (nécessite LÖVE 11.5)
sh tools/check.sh         # SUITE complète : gardes + headless + props + golden (+ luacheck)
luajit tools/sim.lua 400  # batch d'équilibrage : 400 combats -> stats -> runs/report.json
```
Boucle : **build** (achète une unité à la **boutique** en la glissant sur une case ; **REROLL** re-tire,
**NIVEAU** débloque un slot ; glisse case→case pour déplacer/échanger, hors-plateau pour **vendre** ;
survol = infos/passif ; `s` change de sigil ; bouton **COMBAT**) → **combat** auto (spectateur) →
bandeau VICTOIRE/DEFAITE → round suivant (or/boutique renouvelés, **plateau conservé**) jusqu'à
**10 victoires** (ascension) ou **5 défaites** (chute) → écran de fin → nouvelle run. `echap` quitte.

---

## 7. État actuel & feuille de route

**Fait (v0)** : rendu pixel-perfect, moteur de rig (6 créatures), décor d'ambiance, smoke test.
**Fondation plateau** : plateau-graphe 3×3 (arêtes explicites) + 5 sigils (carré/croix/anneau/diamant/ligne).
**Boucle build↔combat (v0.1)** : phase build **drag-drop** (bench → cases) + **infobulles** stats/passifs
+ swap sigil + déblocage slots + bouton **COMBAT** → combat **auto** (équipe vs IA de seed) avec
**front/back par colonne** + bandeau résultat → retour build. Souris vérifiée (love2d.org/wiki).

**Fondation moteur (v0.3)** — cœur d'ingénierie posé (réf complète : `docs/research/engine-architecture.md`) :
- **Déterminisme** : RNG seedé injecté par combat ; test « même seed → bataille identique ». ⟹ snapshots/replays.
- **Système d'effets découplé** : data + **registre d'ops** + **bus d'événements** ; 6 passifs en descripteurs
  (`{trigger, op, params}`), plus aucun `if passive.kind == …` ; aura d'adjacence = data lue au build.
- **Firewall SIM/RENDER** : `arena.lua` est SIM pure (zéro `love.graphics`) et émet des événements ;
  `src/render/arena_draw.lua` possède rigs/anims et écoute le bus. Garde grep dans `tools/check.sh`.
- **Harnais de test** : `headless` (smoke + déterminisme + e2e souris), `props` (invariants + fuzz),
  `golden` (régression event-log). **Event-log JSONL** structuré (attribution source/cause).
- **Batch sim d'équilibrage** : `tools/sim.lua` (N combats → win-rate/unité, dégâts/effet, TTK,
  σ/entropie de santé méta → `runs/report.json`, reproductible).

**Modèle de combat acté (v0.4)** — cf. `docs/research/combat-model-decision.md` :
- **Vie par entité** (mort par-combat, build persiste ; identité protégée au run, pas au combat).
- **Ciblage 100% déterministe** (`arena.lua:chooseTarget`) : colonne avant (`depth = maxCol - cell.x`,
  dérivé de la forme) → **taunt** → **aggro** la plus haute → tie-break **haut→bas**. Remplace l'ancien
  `nearestEnemy` euclidien (la dette de ciblage est **résolue**). Test des 4 couches dans `headless`.
- **Exposition portée par le sigil** (« la forme EST aussi le champ de bataille »). **Aggro câblée mais
  inerte** (égale partout ; on tune quand les plateaux se remplissent).

**Boucle run roguelite actée & codée (v0.5)** — étape gameplay #1 livrée (réf : `gd-research-result.md` §1.6-1.7) :
- **`src/run/state.lua`** : état de run **SIM PUR** (zéro `love.graphics`, sous le firewall) et **seedé** —
  or/vies/victoires/niveau/streaks/boutique. Le seed de combat est tiré du RNG du run ⟹ **replay au niveau run**.
- **Économie SAP** : or FIXE/round (pas de banque), **boutique** 5 offres aléatoires à acheter (drag offre→case),
  **reroll** payant, **leveling PAYANT = déblocage des slots** (3→9), **vente** (drag hors-plateau).
- **Run** : 5 vies / 10 victoires ; +1 vie au round 3 si perte précoce (filet SAP) ; escalade d'adversaire/round ;
  écran de fin (ascension/chute) → nouvelle run. Plateau **persistant** entre rounds (`host.finishCombat`).
- **Tests** : `tests/run.lua` (invariants éco + déterminisme + fuzz 60×80) ; e2e boutique + routing dans `headless`.
- **Chiffres = placeholders** (or 10, achat 2-4, reroll 1, niveau 5+, streak +1/+2/+3) à tuner via `tools/sim.lua`.

**Système d'effets v1 — fondations + 1ères familles (v0.6)** — cf. `docs/research/effects-design.md` (synthèse des 4 recherches) :
- **Couche de modificateurs** (`src/effects/stats.lua`) : `resolve(base, mods)` = `(base+Σflat)(1+Σinc)·Π(1+more)` ;
  `increased` additifs → **déterministe sans tri** ; socle du malus de poison / choc / aggro modifiable. `mods=nil`→base.
- **Moteur de statuts généralisé** (`arena:tickDots`) : `u.dots` {burn, bleed, **poison=[stacks]**, rot, choc} + regen,
  **ordre fixe** déterministe, accumulation entière. `damage()` amplifie le choc + ampute les PV max (rot) ; `hit()`
  applique le **malus de valeur** (poison). **6 familles** ; ajouter une famille = +1 bloc de tick + 1 op de pose.
- **7 unités à effets** jouables (poison×2 dont weaken / burn / bleed+slow / rot+amputation / choc / **contre regen**) ;
  visuel réutilisé via le champ **`sprite`** (`Units.spriteOf`) en attendant le pixel-art dédié. **13 unités en boutique**.
  Tests des 6 familles (`headless`) + `stats` ; golden rebaseliné (843214188) ; sim saine (σ 0,056, entropie 0,999).
- **Métriques sim (P3) — FAIT** : `tools/sim.lua` ajoute dégâts par cause + **part des altérations** (DoT vs frappe),
  distribution TTK (p10/p50/p90), **`lift` de co-occurrence (détecteur de combos cassés)** et **drapeaux d'outliers**
  (écart à la moyenne du champ en σ, pas une bande absolue : le win% « présence côté gagnant » se centre sur la moyenne).
- **Pool P4 — FAIT (4 familles DoT complètes, 47 unités)** : burn/bleed/poison/rot chacune à **5 T1 (dont 1 aura) /
  3 T2 / 2 T3** (cf. `effects-dot-families.md §H`), livrées par **vagues** (enablers → auras → twists → transforms),
  chaque vague verte + committée. **Décision d'archi (voisinage)** : **auras** build-résolues (graphe du sigil, comme
  `shield_aura`) ; **propagation en combat** (contagion / mort) = **proximité du champ de bataille** (`Arena:neighborsOf`)
  pour garder l'arène **SIM autonome**. Nouveau trigger `on_death` (broadcast **différé**, ctx dédié) + détonation au
  seuil (`on_tick`) ; `grant_team` (transforms d'équipe via `teamFlags`). Tout **gated** → golden inchangé (843214188).
- **Tests d'interaction** (`synergies.lua`, 12 synergies) : choc/poison-multi/weaken/bleed/regen (familles) + contagion /
  propagation-à-la-mort / aggravate / shieldEat (T2) + bleed→rot / poison→feu / festering-sans-cap (T3 croisés).
- **Simplifications T3 assumées** (placeholders, à enrichir) : Ash-Maw = no-decay d'équipe (sans spread-on-death) ;
  Pit-Maw = rot sur l'équipe ennemie (au lieu de « tous les DoT amputent ») ; Vein-Splitter = 1 bleed fort (2-instances
  approximé) ; Wither-Bloom = rot + bleed(0 dps→slow) + poison(0 dps→malus). Le **choc** garde 1 unité (ladder différée).
- **Reste** (cf. tâches P5-P6) : **équilibrage auto-itéré** (tests d'envergure : gros N → `lift` + drapeaux → tuner un
  levier à la fois) ; activer l'**aggro** ; (option) étendre le **ladder choc** à 5/3/2.

**Prochaines étapes moteur** (à faire quand un contenu l'exige — cf. `engine-architecture.md` §12) :
- ~~**Valeurs d'aggro + archétype tank**~~ — **FAIT (P6/v0.8)** : `AGGRO_STD=10`, tank ~40 / bruiser ~15 / carry ~5 (data) ;
  unité tank `gravewarden` (**taunt** + épines). Reste : **passifs de ligne** (façade=armure / arrière=attaque), **contres**
  de taunt (AoE-colonne / strip / furtivité), **ladder choc** à 5/3/2.
- **Buckets de modifiers** (flat/increased/more/clamp) — au 1er modificateur en % de stat.
- **Attaque-entité** (pierce/chain/fork + budget anti-boucle) — à la 1re relique de projectile.
- **Work-queue d'effets** (budget 256) — au 1er effet qui en déclenche un autre (chaîne).
- **Fatigue** (~17 s) — si le fuzz révèle des combats non-conclus (aucun à ce jour sur 250).

**Prochaines étapes gameplay** (cf. `gd-research-result.md` §Étapes) :
1. ~~**Économie + run roguelite**~~ — **FAIT (v0.5)** : or/tour, reroll, leveling = déblocage de slots, streaks, 5 vies, 10 victoires.
2. ~~**Duplicatas**~~ — **FAIT (v0.8)** : 3 copies (même id+niveau) → niveau+1 (cap 3, **cascade**) ; stats ET auras scalent (`LEVEL_MULT {1,1.8,3}`). Fusion à l'achat (`build:checkMerges`) ; **niveau 1 = identité** (golden/sim inchangés). Pips dorés. Reste : synergies d'adjacence par **type**.
3. ~~**Reliques cryptiques + Grimoire**~~ — **FAIT (v0.8)** : **1-parmi-3** (vrai + 2 leurres **entrecroisés**), candidats **seedés/run**, effet réel au build, identification par **observation** → **Grimoire** persistant (`src/core/grimoire.lua`, méta cross-run : relique apprise = identifiée d'emblée). Reste (UI) : infobulle des 3 candidats + **écran Grimoire** ; sigils via reliques.
4. ~~**Snapshots async**~~ — **FAIT (v0.8)** : `src/net/snapshot.lua` (capture/encode **sûr**/decode/toComp) + `snapstore.lua` (pool persistant + **serve par version/tier** + **cold-start IA garanti**). `build:startCombat` sert un **ghost** ou l'IA (pick seedé). Reste : effets aura/relique dans le snapshot (v1 = effets de base), matchmaking rang, backend distant.
5. Porter **props** et **biomes** depuis les références PixiJS (cf. `docs/pixel-art/`). Génération procédurale de **créatures** déjà en place (`src/gen/`, écran galerie `[g]`, chantier parallèle).

> Dette connue : profils d'exposition des sigils non réglés (les formes à `cell.x` flottant comme
> l'anneau donnent une exposition en file ; à ajuster par forme) ; valeurs de passifs/aggro/reliques **et
> d'économie** (or/coûts/streaks) = placeholders d'équilibrage (à tuner via `tools/sim.lua`) ; boutique
> sans **raretés/cotes-par-niveau** (pool uniforme) ; **ladder choc non étendu** (1 unité) ; quelques **T3
> simplifiés** (placeholders) ; **UI reliques** (3 candidats + écran Grimoire) et **effets aura/relique
> non capturés dans le snapshot** (v1 = effets de base) à faire ; **passifs de ligne** + **contres de taunt**
> différés.
> *Résolu* : ciblage déterministe (était euclidien) ; split SIM/RENDER ; boucle run roguelite ; **métriques
> sim P3** ; **pool d'effets P4** (4 familles DoT 5/3/2 + auras + propagation + transforms) ; **P5 équilibré**
> (σ 0,033) ; **P6 aggro activée** (tank + taunt) ; **duplicatas** (3→niveau) ; **reliques cryptiques + Grimoire**
> (pilier #2) ; **snapshots async** (pilier #3, ghosts + cold-start IA) ; **scaffolding `sprite` retiré** (CreatureGen).

---

## 8. Agents du projet

- **love2d-engineer** — implémente/maintient le code Lua/LÖVE. Vérifie *toujours* les APIs.
- **autobattler-designer** — game design, mécaniques, async-snapshots, reliques cryptiques.
- **pixel-art-master** (global) — création/animation pixel art, rigging, biomes, palettes.
- **git-warden** — versionnement : branches (`main`/`dev`/`<type>/<slug>`), commits conventionnels,
  jalons taggés. Branche un nouveau chantier depuis `dev`, commit quand `check.sh` est vert.

Lancer plusieurs agents en parallèle pour du travail indépendant.

**Modèle de branches** : `main` (stable, jalons `vX.Y` taggés, jamais de commit direct) · `dev`
(intégration, les features y fusionnent quand vert) · `<type>/<slug>` (`feat/`,`fix/`,`refactor/`,
`docs/`,`chore/`,`test/`,`perf/`). Push uniquement sur demande. Détail : `.claude/agents/git-warden.md`.
