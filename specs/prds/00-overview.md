# PRD-00 — Overview & glossaire

## But

Index des PRDs V1 alpha + glossaire de termes partagés. Lire en premier.

## Index des PRDs

| # | PRD | Sprint | État |
|---|---|---|---|
| 01 | Identity & Persistence | 1 | draft |
| 02 | App Shell & Routes | 1 | draft |
| 03 | Hero & Equipment | 1 | draft |
| 04 | Combat Engine | 1 | draft |
| 05 | Map & Descent | 1 | draft |
| 06 | Predicted Depth & Threat | 1-2 | draft |
| 07 | Cards & Loot | 2 | draft |
| 08 | Boss & Milestones | 2 | draft |
| 09 | Onboarding | 2 | draft |
| 10 | Offline Progression | 2 | draft |
| 11 | Leaderboard & Anti-cheat | 3 | draft |
| 12 | Speed Control, Polish, Mobile-Readable | 3-4 | draft |

États : `draft` → `iteration` → `locked`. Implémentation Sprint 1 démarre quand PRD-01..05 `locked`.

## Glossaire

### Concepts gameplay

- **Pit** : l'univers de jeu. Verticalité descendante. Pas de borne basse.
- **Floor** / **Depth** : un palier de profondeur. Indexé `D001`, `D002`, ... Pas de max.
- **Node** : un point d'engagement à une depth donnée (combat, event, shop, rest, treasure, boss).
- **Chunk** : groupe de 20 floors généré ensemble (cf. `src/game/pit/generate.ts`).
- **Descent** : action de cliquer un node sous le current pour avancer.
- **Retreat** : action volontaire ou forcée de remonter d'un floor (perd 1 torche).
- **`currentDepth`** : position actuelle du joueur dans le pit. Peut décroître via retreat.
- **`deepestDepth`** : record de `currentDepth` jamais atteint. Croît seulement.
- **Replay / re-engage** : re-cliquer un node `cleared-replayable` pour le refaire (loot dégradé ×0.4).
- **Threat tier** : niveau de menace d'un node, affiché en étoiles ★. Comparé à hero power.
- **Boss floor** : depth où un boss bloque la progression (D10, D25, D50, D100 V1).
- **Milestone** : palier symbolique (D10, D25, D50, D100) qui déclenche une cérémonie.

### Ressources

- **Scrap** (`◆`) : monnaie soft. Achète passifs. Cumulé. Auto-banked.
- **Shards** (`✦`) : monnaie hard. Drop sur boss + 1% elite. Reroll loot.
- **Torch** (`☩`) : ressource de session. Dépensée au retreat. Cap V1 = 5. Regen 1 par 30min offline.
- **HP** : hit points hero. Reset à 100% au début de chaque combat (V1).
- **Focus** : ressource per-combat (max 100). +5 par crit. Dépense 50 = trigger immédiat carte la plus avancée.

### Technique

- **Twitch OAuth** : authentification **obligatoire** dès `/auth` avant tout accès gameplay (cf. PRD-01). Pas d'anonymous play V1.
- **Convex authoritative** : Convex est source unique de vérité pour tout state critique (combat, depth, scrap, leaderboard).
- **Optimistic UI** : client prédit le résultat localement pour réactivité, écrase si Convex divergent.
- **Tick 4Hz** : combat avance par steps de 250ms. Action meters tickent à ce rythme.
- **Action meter** : float [0,1] par carte/intent. Trigger à 1.0, reset à 0.
- **Intent** : action télégraphée d'un enemy avant trigger (visible 1+ tick à l'avance).

### États de node

- `fresh` : pas encore vu/visible
- `current` : node actif où le joueur se trouve
- `cleared-replayable` : nettoyé, peut être ré-engagé (loot ×0.4 V1)
- `locked` : pas encore atteignable (verrou de boss en amont)
- `bypassed` : skipped via path alternatif

(cf. `src/game/pit/types.ts`)

### Tiers de carte

- **T0 Bone** : commun (60% drop), bone color
- **T1 Iron** : medium (30% drop), gild color
- **T2 Etched** : rare (8% drop), amber color
- **T3 Obsidian** : très rare (1.8% drop), violet color, unique passive
- **T4 Pit-touched** : légendaire (0.2% drop), red color, unique mechanic

### Slots équipement V1

- `mainhand` (1) — weapon
- `body` (1) — armor
- `head` (1) — focus regen / crit modifier
- `charm` (1) — proc passif

V1 : 4 slots. V1.1 : +offhand, +ring, +relic, +charm 2 (passifs débloquent).

### Tiers de leaderboard (R3)

| Tier | Range depth |
|---|---|
| Surface | D0–D25 |
| Shaft | D26–D75 |
| Caverns | D76–D150 |
| Abyss | D151–D300 |
| Deeppit | D301+ |

## Comment lire un PRD

Chaque PRD suit le template :
1. **Goal** — 1 phrase mesurable
2. **Non-goals** — ce qui est hors V1
3. **User stories** — POV joueur
4. **Functional spec** — comportements
5. **Technical approach** — architecture, fichiers
6. **Data model** — Convex schema additions
7. **Acceptance criteria** — tests
8. **Dependencies** — autres PRDs requis
9. **Open questions** — décisions à acter

## Notes

- Chaque PRD cite explicitement les fichiers existants à réutiliser. Pas de réinvention.
- Les questions ouvertes Q14-Q19 (cf. `brainstorming/game-loop/08-open-questions.md`) sont distribuées dans les PRDs concernés.
- Les PRDs ne contiennent **pas** de chiffres de tuning précis (HP, damage, drop rates). Tuning est variable post-V1.
- Une feature mentionnée dans game-loop doc 09 mais absente d'un PRD = bug. Signaler.
