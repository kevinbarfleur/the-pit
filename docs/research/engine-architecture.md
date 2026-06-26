# Architecture moteur active - The Pit

Derniere mise a jour: 2026-06-26.

Ce document remplace l'ancien audit long d'architecture. Les anciens passages
qui parlaient d'un bug RNG global actif, de modules `NEW`, ou de phases a livrer
sont historiques: le code actuel a deja separe simulation et presentation.

## §1. Etat courant

The Pit est organise autour de trois frontieres:

- `SIM`: `src/combat`, `src/board`, `src/effects`, `src/run`;
- `PRESENTATION`: `src/render`, `src/ui`, `src/fx`, `src/audio`;
- `DATA/TOOLS`: `src/data`, `src/gen`, `src/i18n`, `src/net`, `src/lab`,
  `tools`, `tests`.

Le contrat important n'est pas que chaque fichier soit petit. Le contrat est que
la simulation reste deterministe, que le rendu/audio ne mute jamais la simulation,
et que les chiffres de tuning puissent etre testes par outils.

## §2. Determinisme

Regles actives:

- pas de `math.random` global en simulation;
- RNG seede injecte ou construit depuis un seed explicite;
- pas de dependance au temps mur dans les regles;
- arrays + `ipairs` quand l'ordre influence un resultat;
- tie-breaks explicites pour ciblage, mort, effets et logs;
- pas de `love.graphics`, audio, UI ou particles dans `SIM`.

`src/combat/arena.lua` respecte actuellement ce contrat: les timers d'attaque
utilisent `self.rng:random()`, et l'arene emet des events que la presentation
consomme.

## §3. Boucle moteur

`main.lua` pilote un pas fixe 1/60 avec accumulateur et limite de rattrapage.

Lecture:

- la simulation avance par ticks discrets;
- le rendu peut interpoler/animer au temps presentation;
- le game feel, les sons et les transitions restent cosmetiques;
- tout comportement qui change l'issue d'un combat doit passer par la SIM.

## §4. Firewall SIM/RENDER

La direction des dependances doit rester simple:

```text
main/scenes -> sim + render/ui/audio
render/ui/audio -> lecture et events, jamais mutation sim
sim -> data/effects/bus, jamais render/ui/audio
data -> tables pures autant que possible
```

Exemples actuels:

- `src/combat/arena.lua` resout le combat et emet les events;
- `src/render/arena_draw.lua` lit l'arene et joue impacts, nombres, trails;
- `src/render/healthbar.lua` lit HP/shield/dots sans muter;
- `tools/eventlog.lua` ecoute le bus pour les rapports/tests.

## §5. Data et tuning

Les gros leviers encore enfouis dans le code doivent progressivement sortir vers
des tables de donnees:

- economie: or, XP, shop odds, prix par rang, slots, cadence reliques;
- combat: caps, fatigue, status tuning, Haste, reduction de degats;
- contenu: effets de niveau, reliques, tags, textes canoniques.

La regle pratique: si un chiffre doit etre balaye par simulation, il doit etre
lisible depuis un module data ou un resolver partage.

## §6. Effets composables

Le modele d'effet actif reste:

```lua
{ trigger = "...", op = "...", target = "...", params = { ... } }
```

Principes:

- les unites, reliques, murmures et level-ups doivent converger vers ce modele;
- les ops vivent dans `src/effects/ops.lua` et modules associes;
- les resolvers preparent les specs avant combat;
- les cartes et glossaires doivent decrire la meme verite mecanique que la SIM.

### §6.3 Event bus

Le bus transporte les faits de simulation vers presentation, logs et chroniques.

Bon usage:

- events de frappe, degats, mort, shield, spread, amplification;
- pas de dependance rendu dans l'emission;
- payloads stables et serialisables quand ils servent a un test ou replay;
- nouveaux events autorises si le combat reste identique sans listener.

## §7. Fichiers a risque

Zones a surveiller:

- `src/scenes/build.lua`: scene tres large, a extraire par layout/shop/board;
- `src/run/state.lua`: economie et cadence a deplacer vers data;
- `src/combat/arena.lua`: coeur lisible, mais tuning a isoler;
- `src/i18n/en.lua`: textes de cartes et flavor a garder coherents avec tags;
- `src/data/units.lua`: source dense des effets, a auditer avec les outils.

Eviter les refactors massifs abstraits. Extraire seulement quand cela retire un
risque reel ou permet de brancher les simulations.

## §8. Tests et outillage

Validation standard:

```sh
sh tools/check.sh
```

Tests/outils importants:

- `tests/headless.lua`, golden logs, fuzz combat;
- `tests/coherence.lua`;
- `tools/runsim.lua`, `tools/balancematrix.lua`;
- `tools/coherence_report.lua`;
- `love . --shoot=all --shoot-size=1280x720` pour les changements visuels.

### §8.7 LÖVE/mock boundary

Les tests headless utilisent un mock LÖVE. C'est utile pour verifier les contrats
de modules, mais toute API LÖVE nouvelle ou subtile doit etre verifiee sur les
sources primaires LÖVE 11.5 et, si elle touche au rendu, validee avec une capture
ou un lancement reel.

## §9. Sources actives

- `CLAUDE.md`;
- `docs/audit/2026-06-26-architecture-technique.md`;
- `docs/research/love2d-tech.md`;
- `docs/research/intensive-simulation-balance-program-HANDOFF.md`;
- le code courant.
