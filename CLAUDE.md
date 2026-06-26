# The Pit - brief projet actif

Derniere mise a jour: 2026-06-26.

Ce fichier est la source courte a lire au debut de chaque session. Il remplace
les anciennes syntheses longues qui melangeaient decisions actuelles, recherches
historiques et plans deja livres.

Pour la documentation detaillee, commence par `docs/README.md`. Si une ancienne
note contredit ce fichier ou `docs/research/intensive-simulation-balance-program-HANDOFF.md`,
elle est historique et ne doit pas guider une implementation.

## 1. Vision

The Pit est un autobattler roguelite asynchrone en Lua/LÖVE.

Piliers actuels:

- boucle build -> combat auto -> bilan -> build;
- run courte: 10 victoires avant 5 vies perdues;
- plateau graphe 3x3 avec adjacence orthogonale et sigils/topologies;
- combat deterministe a cooldowns, vie par entite, ciblage front/back lisible;
- profondeur par synergies, positionnement, duplicatas, commandement, reliques,
  murmures caches et economie de run;
- direction artistique grimdark, organique, lisible, avec feedback fort au
  hover/click/drag.

Le jeu doit rester simple a jouer et profond a optimiser. On privilegie des
regles comprehensibles, des tags canoniques, des petits nombres, et des plans
de build que le joueur peut lire sur les cartes.

## 2. Decisions actives

### Relics

Les reliques sont lisibles.

Etat actuel:

- offre 1-parmi-3;
- effet affiche clairement avec valeur;
- flavor et collection Grimoire conserves;
- leurres, identification par observation et fausses pistes retires;
- effets intra-combat ou build-time, pas de handicap permanent sur une run;
- les reliques doivent egaliser ou ouvrir un plan, pas gate un matchup a 100%.

Doc active: `docs/research/relics-design.md`.

### Tags et wording

Les mots mecaniques sont du vocabulaire formel, pas du flavor.

Regles:

- le meme concept utilise toujours le meme mot: `Poison`, `Burn`, `Haste`,
  `Shield`, etc.;
- icon + couleur + nom, jamais couleur seule;
- une carte qui mentionne un tag doit avoir une entree de glossaire Shift
  correspondante;
- les tags issus des murmures restent caches en public;
- les tags de commandement sont contextuels au commandement;
- le systeme s'applique aux monstres et aux reliques.

Code source actuel: `src/core/tags.lua`, `src/ui/card_glossary.lua`,
`src/ui/mechanics_text.lua`, `src/render/monstercard.lua`,
`src/ui/relic_card.lua`.

### Level-ups

Les niveaux ne doivent pas seulement scaler HP/DMG.

Etat actuel:

- `src/core/unit_resolver.lua` est la source de verite niveau -> stats,
  effects, commandBonus;
- `src/data/unit_levels.lua` contient les deltas authored;
- niveau 1 = definition de base;
- niveau 2/3 peuvent changer valeurs d'affliction, shield, auras, commandBonus;
- une partie des creatures low/mid-rank doit gagner un clutch L3 pour soutenir
  les comps reroll.

Programme actif: `docs/research/intensive-simulation-balance-program-HANDOFF.md`.

### Economy

L'economie actuelle est encore un placeholder de tuning.

Constat actif:

- `10 gold + shop size 5 + cost=rank + no bank` rend l'early trop permissif;
- le probleme n'est pas juste trop d'or, mais une pression qui arrive trop tard;
- les variantes a tester en premier sont:
  - `costByRank = {2, 3, 4, 5, 6}` avec revenu fixe;
  - revenu early courbe `6/6/8/8/8/10...` avec `cost=rank`.

Doc active: `docs/audit/2026-06-26-economie-run.md`.

### Balance et simulation

Le simulateur ne doit pas seulement generer des piles aleatoires.

Objectif:

- construire des equipes incoherentes, semi-coherentes et coherentes;
- separer `coherence_score`, investissement economique, accessibilite de run et
  puissance combat;
- tester commandants, reliques, positions, niveaux, murmures et politiques de run;
- produire des rapports diffables et reproductibles.

Code actuel:

- `src/lab/coherence.lua`;
- `tools/coherence_report.lua`;
- `tests/coherence.lua`;
- `runs/report-coherence.json` genere localement.

## 3. Architecture et frontieres

Frontieres non negociables:

- SIM: deterministe, seedee, array/ipairs quand l'ordre compte, aucune dependance
  rendu/audio/temps mur;
- PRESENTATION: UI, render, audio, juice, transitions; aucun impact sur la sim;
- DATA/TUNING: chiffres et contenus lisibles, exportables, testables.

Modules principaux:

- `src/combat`, `src/board`, `src/effects`, `src/run`: simulation/regles;
- `src/render`, `src/ui`, `src/fx`, `src/audio`: presentation;
- `src/data`, `src/gen`, `src/i18n`, `src/net`, `src/lab`: contenu, generation,
  snapshots, outils de balance.

Verification locale standard:

```sh
sh tools/check.sh
```

Pour une modification visuelle, il faut aussi capturer et regarder le resultat
quand c'est possible:

```sh
love . --shoot=all --shoot-size=1280x720
```

## 4. Qualite UI, feel et audio

The Pit doit avoir du feedback immediat, pas seulement une logique correcte.

Regles:

- hover/click/drag ont du mouvement, de la lumiere, et quand pertinent du son;
- feedback pointer-down immediat, action possiblement differee courtement;
- les boutons/cartes/modales reutilisent les composants existants;
- ne pas inventer un style local si le design system fournit deja une primitive;
- verifier les captures avant de declarer une UI terminee.

Docs utiles:

- `docs/audit/2026-06-26-ui-feel-audio.md`;
- `docs/pixel-art/design-system-source.html`;
- `docs/pixel-art/design-system-spec.md`.

## 5. Documentation active

Lire en priorite:

1. `CLAUDE.md`;
2. `AGENTS.md`;
3. `.codex/agent-routing.md`;
4. le wrapper `.codex/agents/<role>.md` pertinent;
5. `docs/README.md`;
6. le code touche.

Docs projet actives:

- `docs/audit/README.md`;
- `docs/research/intensive-simulation-balance-program-HANDOFF.md`;
- `docs/research/relics-design.md`;
- `docs/research/combat-model-decision.md`;
- `docs/research/engine-architecture.md`;
- `docs/research/love2d-tech.md`;
- `docs/research/balance-sim-design.md`;
- `docs/audit/2026-06-26-economie-run.md`;
- `docs/audit/2026-06-26-roadmap.md`;
- `docs/audit/2026-06-26-synthese.md`.

Les anciens brainstorms, exports HTML, datasets de recherche comparative et
plans de rollout livres ne sont pas des sources de verite.

## 6. API et implementation

Ne jamais coder une API LÖVE/Lua depuis la memoire.

Sources primaires:

- LÖVE 11.5: https://love2d.org/wiki/Main_Page
- Lua 5.1 / LuaJIT: https://www.lua.org/manual/5.1/

Regles:

- chercher l'existant avant d'ajouter une abstraction;
- reutiliser les modules locaux;
- garder les changements scopes;
- ne pas reintroduire `math.random` global en SIM;
- ne pas faire dependance combat -> render/ui/lab;
- ne pas muter la simulation depuis le rendu, l'audio ou le feel.

## 7. Agents locaux

Routage via `.codex/agent-routing.md`.

Roles:

- `love2d-engineer`: Lua/LÖVE, moteur, sim, perf, rendu technique;
- `ui-artisan`: composants UI, cartes, panels, tooltips, chrome;
- `game-feel-engineer`: hover, click, drag, transitions, shake, hitstop;
- `sound-designer`: SFX, ambience, cues;
- `asset-forge`: creatures, body-plans, sprites proceduraux, reliques visuelles;
- `autobattler-designer`: economie, synergies, reliques, balance, simulation;
- `git-warden`: branches, commits, merges, tags, release.

Dans Codex, ces roles sont des briefs, pas des agents natifs obligatoires. Lire
le wrapper et appliquer le brief directement si la delegation n'est pas utile.

## 8. Git et validation

Le worktree peut etre sale. Ne jamais revert une modification que tu n'as pas
faite.

Ne commit/push que sur demande explicite.

Definition de fini:

- code ou docs alignes avec les sources actives;
- tests pertinents passes;
- `sh tools/check.sh` pour un increment fini;
- screenshot inspecte pour les changements UI/visuels;
- docs de handoff mises a jour quand le changement modifie la source de verite.
