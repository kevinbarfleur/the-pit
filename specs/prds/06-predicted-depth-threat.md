# PRD-06 — Predicted Depth & Threat Diagnostic

## Goal

Mitigation #1 du **risque mur opaque (R1)**. Donner au joueur un signal **directionnellement utile** sur (a) la difficulté d'un combat avant engagement, (b) sa progression attendue selon power actuel, et (c) ses options après échec répété.

Sans cela, R1 tue D7 retention. Avec cela, joueur comprend "je suis bloqué, je sais pourquoi, je choisis comment optimiser".

## Non-goals

- Calcul mathématiquement parfait du DPS (V1 = approximations directionnelles)
- Simulation de combat complète pré-engagement (V1 = stats based heuristic)
- Recommandations de build optimisées par AI (V2)
- Predicted depth basé sur game theory deep / metas (V2)
- Indicateurs ouverts à customisation joueur (V1.5)

## User stories

- En tant que **joueur**, avant d'engager un combat, je vois "Threat ★★★ vs You ★★" et j'estime mon risque.
- En tant que **joueur**, je vois "Expected: tough — likely 70% HP loss" pré-combat et je décide d'engager ou de pivoter.
- En tant que **joueur** qui a retreaté 3× au même endroit, je vois un panneau discret "stuck? options: farm D018-D022 · buy passive · swap cards".
- En tant que **joueur**, je consulte un indicateur dans la Topbar/UI me disant "you can sustain to ~D125 with current build".

## Functional spec

### Threat tier ★

Affiché sur chaque node interactable (combat / elite / boss) avant click :
- Comparé à `heroPower` (composite de stats hero, cf. compute ci-dessous)
- 5 niveaux : `★` trivial, `★★` easy, `★★★` matched, `★★★★` hard, `★★★★★` lethal
- Color-coded : trivial=dim, easy=green, matched=neutral, hard=amber, lethal=red

### Hero power compute

Heuristique simple V1 :
```
heroPower = (hero.damage * (1 + hero.critChance)) * 4 / (1 + hero.SPD penalty)
+ hero.hpMax * 0.1
+ hero.block * 50
+ ∑ (charm passive contribution)
```

(détails à tuner — V1 cherche directionalité, pas exactitude)

### Enemy threat compute

```
enemyThreat = enemy.hp * 0.5 + enemy.intent.damage * enemy.intent.spd * 4
* (1 + enemy.specials.length * 0.2)
```

Threat ratio = `enemyThreat / heroPower` → mappe sur les 5 étoiles.

### Pre-combat preview popup

Apparaît au click sur un node combat (avant zoom-in start), 1.5s ou skipable :

```
┌──────────────────────────────────────┐
│  D012 · Hollow Archer                │
│  Threat ★★★ — matched                │
│                                      │
│  Your DPS: ~14/s                     │
│  Enemy HP: 95 (~6.8s to kill)        │
│  Enemy DPS: ~5.5/s                   │
│  Expected: ~30% HP loss              │
│                                      │
│  [Engage] [Cancel]                   │
└──────────────────────────────────────┘
```

V1.5 : skipable par défaut après 1ère utilisation (Skill checkbox "always engage").

### Stuck detector

Tracking côté client + backed Convex :
- Si joueur a `retreats` au même `currentDepth` ≥ 3 dans une session active de 30 min
- Affiche panneau discret en bas à droite (auto-dismiss après 30s, refusable) :

```
┌───────────────────────────────────┐
│  STUCK?                           │
│  options:                         │
│   · farm D008-D011 for cards      │
│   · buy passive Body II (80 ◆)    │
│   · swap your charm slot          │
└───────────────────────────────────┘
```

V1 : actions sont des **suggestions** (textuelles), pas cliquables (V1.5 = clickable).

### Predicted depth indicator

Petit indicateur permanent dans Topbar ou pre-combat preview :
```
sustainable to ~D125
```

Calcul approximatif : depth where `heroPower` reaches threshold of "★★★★ matched" given `enemy.threat(depth)` curve. V1 : simple linear interpolation, **directionnelle pas exacte**.

## Technical approach

### Réuse existant

- `src/game/pit/rewardScale.ts` — pattern de scaling déjà utilisé, à étendre pour threat scaling
- `src/components/ui/Tier.tsx` — composant tier ★ existant (design system)
- `src/components/ui/Pill.tsx` — pour predicted depth pill

### À créer

- `src/game/pit/threat.ts` :
  ```ts
  export function computeHeroPower(hero: HeroStats): number
  export function computeEnemyThreat(enemy: EnemyDef, depth: number): number
  export function threatTier(ratio: number): 1 | 2 | 3 | 4 | 5
  export function predictedSustainableDepth(heroPower: number): number
  ```
- `src/components/pit/ThreatBadge.tsx` : ★★★ badge sur nodes
- `src/components/pit/PreCombatPreview.tsx` : popup pré-combat
- `src/components/pit/StuckDetectorPanel.tsx` : panneau "stuck?"
- `src/hooks/useStuckDetector.ts` : tracking retreats per depth in session window

### Tuning

Compute functions doivent être pure + testables. Suite de tests qui valide :
- Threat tier converge vers `★★★` au depth where build est "matched"
- Predicted depth augmente quand on achète passive
- Stuck detector trigger après 3 retreats même depth

## Data model

Aucun changement Convex schema. Calculs sont dérivés on-the-fly. Tracking retreats per session est client-only (V1 — simple).

V1.5 : ajouter `recentRetreats: { depth, atTimestamp }[]` dans profile pour tracking serveur-side (anti-déconnexion).

## Acceptance criteria

- [ ] Threat tier visible sur chaque node combat/elite/boss avant click
- [ ] Threat tier change en live quand hero équipe une carte
- [ ] Pre-combat preview affiche en <200ms après click node (avant zoom-in start)
- [ ] Pre-combat preview skipable (Espace ou click hors) après 1ère vue
- [ ] Stuck detector apparaît après 3 retreats même `currentDepth` dans <30 min
- [ ] Stuck detector dismissable et n'apparaît pas 2x dans la même session
- [ ] Predicted sustainable depth visible permanent (Topbar ou settings)
- [ ] Tous les compute functions ont tests unitaires (< 1ms)

## Dependencies

- PRD-03 (hero stats — input du compute)
- PRD-04 (combat engine — DPS effective derivation)
- PRD-05 (map navigation — applique threat badge sur nodes)

## Open questions

- **Q6.1** Heuristique threat directionnelle suffisante V1, ou simulation Monte Carlo (1000 combats sim) pour précision ? **Reco V1 : heuristique**, MC en V1.5 si feedback "indicateur trompeur".
- **Q6.2** "Predicted depth" est-il actionable ou juste informatif ? **Reco V1 : informatif** (Pill en Topbar). Actionable V1.5 = bouton "auto-descend to predicted depth".
- **Q6.3** Stuck detector déclencheur : 3 retreats same depth en 30 min, ou aussi trigger sur "5 retreats global session" ? **Reco V1 : same depth uniquement**, plus précis.
- **Q6.4** Stuck detector contenu : suggestions hardcoded ou dynamiques (compute meilleur passive achetable) ? **Reco V1 : 3 suggestions hardcoded** (farm / buy passive / swap), V1.5 = dynamic.
- **Q6.5** Le pre-combat preview est-il toujours montré ou seulement pour nodes "★★★+" ? **Reco V1 : toujours**, mais skipable. Trivial fights = preview rapide visuel.
