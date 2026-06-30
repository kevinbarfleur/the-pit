# Documentation active

Derniere mise a jour: 2026-06-26.

Ce dossier a ete nettoye parce que plusieurs anciennes recherches contenaient
encore des decisions retirees: reliques cryptiques, leurres, identification par
observation, slots lineaires, chiffres de roster anciens, plans de rollout deja
livres.

## Ordre de lecture

Pour une session agent:

1. `../CLAUDE.md`
2. `../AGENTS.md`
3. `.codex/agent-routing.md`
4. ce fichier
5. le code concerne
6. la note active specifique si necessaire

## Sources de verite actives

- `audit/README.md` - audit projet recent et roadmap de consolidation.
- `research/intensive-simulation-balance-program-HANDOFF.md` - programme actif
  de simulation, level-ups, coherence et balance.
- `audit/2026-06-26-economie-run.md` - diagnostic actif de l'economie.
- `research/relics-design.md` - modele actuel des reliques lisibles.
- `research/combat-model-decision.md` - modele de combat/ciblage.
- `research/engine-architecture.md` - frontieres SIM/RENDER/DATA.
- `research/love2d-tech.md` - notes techniques LÖVE/Lua.
- `research/balance-sim-design.md` - principes de lecture des rapports de
  simulation.
- `research/pve-bossrush-scoring-loop.md` - boucle PvE, abominations,
  bossrush post-win et scoring.
- `research/run-events-reward-loop.md` - events de run, recompenses
  explicites, garde-fous sur les mutations.
- `research/playtest-v1-finalization-roadmap.md` - roadmap de transfert du
  chantier final V1 jouable, economie live, PVE bossrush et validations.
- `inspiration/batodex/README.md` - donnees mecaniques Batodex normalisees
  pour inspiration creature/trinket/item, a charger seulement quand necessaire.

## References techniques conservees

Ces fichiers existent parce que le code ou les tests s'y referent encore comme
contrat technique. Ils ne remplacent pas `CLAUDE.md`.

- `research/effects-design.md`
- `research/effects-dot-families.md`
- `research/effects-amplification-modifiers.md`
- `research/payoff-framework.md`
- `research/murmures-plan.md`
- `research/command-auras-rollout-spec.md`
- `research/commanders-plan.md`
- `pixel-art/design-system-source.html`
- `pixel-art/design-system-spec.md`
- `pixel-art/pit-forge.js`
- `generation/generateur-bestiaire.html`
- `generation/generateur-reliques.html`
- `generation/generateur-icones-tags.html`
- `generation/generateur-abominations.html`

Quand une reference technique parait contredire le code actuel, le code et les
tests gagnent.

## Supprime

Ont ete retires du dossier actif:

- anciens brainstorms et handoffs de features deja livres;
- anciens datasets comparatifs SAP/Batomon;
- exports designer ponctuels et fichiers pour designer;
- presentation/deep-dive obsoletes;
- anciens plans base-game et generation-recipes non utilises;
- specs UX qui parlaient encore de reliques cryptiques.

Ces suppressions sont volontaires: l'objectif est d'eviter qu'un agent charge
des milliers de lignes historiques et prenne une mauvaise decision.
