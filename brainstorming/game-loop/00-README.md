# Game-loop brainstorm

> Documents de simulation de la boucle de gameplay, **avant** spec d'implémentation alpha. Le but : aligner sur ce que ressent le joueur — pas sur le code à écrire.

## État

| # | Doc | État |
|---|---|---|
| 01 | First session (0→10 min) | draft |
| 02 | Typical session (J+2) | draft |
| 03 | Grind session (farm un floor) | draft |
| 04 | Macro progression (1h / 5h / 20h) | draft |
| 05 | Combat loop (tick-by-tick) | draft |
| 06 | Loot & cards | draft |
| 07 | Frictions & risks (mon analyse) | iteration (re-gradé post-review) |
| 08 | Open questions | iteration (recos révisées) |
| **09** | **Consolidation post-review** | **consolidation — source de vérité** |

États : `draft` → `iteration` → `consolidation` → `locked`. Le doc 09 intègre les retours de 2 agents externes ; lire en dernier mais c'est le **canonical** post-review.

## Ordre de lecture

Les docs 01→04 zooment progressivement (de l'instant T au méta long-terme). Les docs 05→06 zooment sur les sous-systèmes critiques. Le 07 est mon take critique (re-gradé). Le 08 capture les questions ouvertes (recos révisées). Le **09 est la consolidation finale** post-review et tient lieu de référence pour les specs implémentation à venir.

Lecture conseillée : 01 → 05 → 06 → 02 → 03 → 04 → 07 → 08 → **09**.

## Principes acquis (rappel)

- **Perpetual descent** : pas de "run", pas de longueur. Tu es toujours dans le pit, à une profondeur.
- **Leaderboard = profondeur max atteinte**. C'est le seul "score".
- **Floors replayable** : un node clear reste re-engageable (loot dégradé, ou cooldown).
- **Active descent = core**, offline = flavor (cap 8h @ 25%).
- **Tick 4Hz** pour le combat (engine + serveur).
- **Pas de prestige V1**.
- **Browser-only**, terminal-first aesthetic, 2D sprite art.

## Hors scope de ce brainstorming

- Specs API / schéma data précis
- Tuning numérique (HP, damage, scrap rates)
- Wireframes UI détaillés
- Lore / narratif

Tout ça vient après alignment sur la boucle.
