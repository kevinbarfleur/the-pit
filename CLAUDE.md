# The Pit — guide projet (CLAUDE.md)

> Autobattler **multijoueur asynchrone**, solo dev, **Lua + LÖVE (Love2D)**, tous les
> visuels **générés procéduralement** (pixel art en grilles + palette, zéro asset dessiné).
> Univers **grimdark cryptique** : Cthulhu × Path of Exile × Dark Souls. On descend *Le Puits*.

Ce fichier est le brief permanent du projet : lis-le au début de chaque session. Les
recherches détaillées vivent dans `docs/research/`, les conventions visuelles dans
`docs/pixel-art/`.

---

## 1. Règle d'or (NON négociable)

**Ne jamais coder/affirmer une API depuis la mémoire supposée. Toujours vérifier sur les
sources primaires** avant d'écrire :
- LÖVE : <https://love2d.org/wiki/Main_Page> (cible **11.5** stable).
- Lua / LuaJIT : <https://www.lua.org/manual/5.1/> (LÖVE embarque LuaJIT ≈ Lua 5.1).
- Pour le code/API : préférer `get_code_context_exa` (Exa MCP). Citer ses sources.

Ce réflexe vaut pour moi **et tous les sous-agents**. Une API non vérifiée = un bug latent.

---

## 2. Vision & piliers de design

1. **Simplicité de gestion → profondeur émergente.** La référence d'addictivité du créateur
   est *Batomon Showdown* (SAP en habits de Pokémon Showdown) : pas de timer, gestion d'équipe
   simple. On vise le modèle le plus *simple à implémenter* qui garde une grande rejouabilité.
2. **Reliques cryptiques (signature du jeu).** Contrairement aux autobattlers où l'effet est
   écrit, nos reliques se **découvrent**. Pattern retenu : **1-parmi-3** (l'infobulle montre 3
   effets candidats ; le vrai se révèle à l'usage/observation ; candidats randomisés par run ;
   une fois identifiée, la relique devient **lore lisible de façon permanente** au niveau du
   compte = *connaissance comme méta-progression*). Évite le piège "ID aléatoire = frustration".
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
| Reliques | **cryptiques** : déduire → observer en combat → **verrouiller dans le Grimoire** (codex persistant cross-run, anti-brute-force façon Obra Dinn) ; effets **contextuels** | pilier #2 ; le 1-parmi-3 = les fragments candidats à confirmer |
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
  data/
    creatures.lua         définitions data-only des créatures (grilles/pivots/rig/anims)
    units.lua             stats + EFFETS (descripteurs data) + coût/pool par créature ; combat/build/boutique
    encounters.lua        équipes adverses pré-construites (IA de seed du cold-start)
  combat/
    arena.lua             MOTEUR de combat SIM PUR (zéro love.graphics) : cooldown, hooks d'effets, émet des événements
    place.lua             (col,row) -> position de combat (front/back par colonne)
  effects/
    engine.lua            REGISTRE d'effets : run(porteur, trigger, ctx) + register(op) ouvert/fermé
    ops.lua               ops de base (bonus_first/lifesteal/poison/thorns) ; shield_aura résolu au build
  board/
    shapes.lua            formes de plateau = GRAPHES explicites (cases + arêtes), 9 slots
    board.lua             plateau-graphe : slots, adjacence, sigils, déblocage progressif
  run/
    state.lua             ÉTAT DE RUN roguelite, SIM PUR : or/vies/victoires/niveau/boutique seedés (éco)
  render/
    arena_draw.lua        RENDER du combat : rigs/anims + love.graphics ; lit la SIM + écoute le bus
  fx/
    background.lua        décor d'ambiance (statique baké + dynamique)
  scenes/
    build.lua             phase BUILD : plateau + BOUTIQUE (achat/reroll/niveau) + drag-drop + infobulles + COMBAT
    combat.lua            phase COMBAT : SIM (arena) + RENDER (arena_draw) ; résultat -> host.finishCombat
    runover.lua           écran de FIN DE RUN (ascension 10 victoires / chute 0 vie) -> nouvelle run
tests/
  mock_love.lua           mock LÖVE partagé (graphics stub + RNG seedé) pour headless/sims
  headless.lua            smoke + déterminisme + passifs + e2e souris/boutique (mock LÖVE, vraie logique)
  run.lua                 invariants + déterminisme de l'ÉCONOMIE de run (achat/reroll/niveau/streaks/vies)
  props.lua               invariants + fuzz (PV>=0, terminaison, 1 vainqueur, déterminisme)
  golden.lua              golden-log de régression (empreinte event-log d'un scénario figé)
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

**Prochaines étapes moteur** (à faire quand un contenu l'exige — cf. `engine-architecture.md` §12) :
- **Valeurs d'aggro + archétype tank** + **passifs de ligne** (façade=armure / arrière=attaque) — quand
  les plateaux se remplissent. **Reliques de taunt** + contres (AoE/strip/furtivité) en parallèle.
- **Buckets de modifiers** (flat/increased/more/clamp) — au 1er modificateur en % de stat.
- **Attaque-entité** (pierce/chain/fork + budget anti-boucle) — à la 1re relique de projectile.
- **Work-queue d'effets** (budget 256) — au 1er effet qui en déclenche un autre (chaîne).
- **Fatigue** (~17 s) — si le fuzz révèle des combats non-conclus (aucun à ce jour sur 250).

**Prochaines étapes gameplay** (cf. `gd-research-result.md` §Étapes) :
1. ~~**Économie + run roguelite**~~ — **FAIT (v0.5)** : or/tour, reroll, leveling = déblocage de slots, streaks, 5 vies, 10 victoires.
2. **Duplicatas** (3 copies → niveau, stats + buffs scalent) + plus de **synergies d'adjacence** par type. **← prochaine**
3. **Reliques cryptiques** + **Grimoire** persistant (verrouillage façon Obra Dinn) ; sigils via reliques.
4. Backend **snapshots** (unités + positions + **sigil** + **seed**) + équipes IA + tag de version. Pas de timer.
5. Porter **props** et **biomes** depuis les références PixiJS (cf. `docs/pixel-art/`).

> Dette connue : profils d'exposition des sigils non réglés (les formes à `cell.x` flottant comme
> l'anneau donnent une exposition en file ; à ajuster par forme) ; valeurs de passifs, d'aggro **et
> d'économie** (or/coûts/streaks) = placeholders d'équilibrage (à tuner via `tools/sim.lua`) ; boutique
> sans **raretés/cotes-par-niveau** (pool uniforme) et **duplicatas non fusionnés** (étape #2) ;
> snapshots toujours remplacés par l'**IA de seed** (étape #4).
> *Résolu* : ciblage déterministe (était euclidien) ; split SIM/RENDER (le rendu n'est plus dans `arena.lua`) ;
> boucle run roguelite (était « manque éco/run »).

---

## 8. Agents du projet

- **love2d-engineer** — implémente/maintient le code Lua/LÖVE. Vérifie *toujours* les APIs.
- **autobattler-designer** — game design, mécaniques, async-snapshots, reliques cryptiques.
- **pixel-art-master** (global) — création/animation pixel art, rigging, biomes, palettes.

Lancer plusieurs agents en parallèle pour du travail indépendant.
