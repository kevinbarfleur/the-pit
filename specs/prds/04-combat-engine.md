# PRD-04 — Combat Engine

## Goal

Moteur de combat tick-based 4Hz avec action meters par carte/intent, ressource Focus, et résolution Convex authoritative (anti-cheat). Pierre angulaire du gameplay actif.

## Non-goals

- Combat positionnel (lanes, range, AoE) V1
- Multi-enemy par combat V1 (1 hero vs 1 enemy)
- Status effects complexes V1 (poison ticks, burn DoT, freeze) — V1.5
- Targeting manuel (toujours auto-targeting V1, single enemy)
- Card swap mid-combat — V1.5
- Skip combat (cf. PRD-12 pour speed control)
- Replay system / spectate mode (V2)

## User stories

- En tant que **joueur**, je clique un node combat, le combat démarre automatiquement et je vois le hero engager l'ennemi.
- En tant que **joueur**, je vois les action meters de mes cartes équipées tickter, et chaque trigger fait un hit visible.
- En tant que **joueur**, je vois l'intent de l'ennemi avant qu'il frappe (icone + valeur prévisionnelle).
- En tant que **joueur**, j'appuie `Espace` pour consommer 50 Focus et trigger immédiatement la carte la plus avancée.
- En tant que **joueur**, je gagne du Focus via mes crits (+5/+10 par chain).

## Functional spec

### Tick

- Tick rate fixe : **4Hz** (250ms par tick).
- Combat = sequence de ticks. Chaque tick : `processTick(state, dt=0.25)`.
- Total combat typique : 30-90 ticks (8-22s).

### Hero side

- Pour chaque carte équipée (4 slots), un **action meter** float `[0, 1]`.
- Chaque tick : `meter += spd * dt` (où `spd = card.baseSpd` ; affecté par passives plus tard).
- Trigger à `meter >= 1.0` :
  - Carte type `weapon` (mainhand, head si applicable) : compute damage, apply to enemy
  - Carte type `armor` / `charm` : trigger passif (shield, regen, etc.)
- Reset `meter = 0` après trigger.

### Enemy side

- Enemy a 1+ intents (V1 = 1 intent typique).
- Chaque intent a sa propre action meter, tickte indépendamment.
- Intent visible **N ticks avant trigger** (V1 = visible toujours, valeur affichée).

### Damage compute

- Base : `card.baseDmg + hero.damageBonus`
- Crit roll : random < `hero.critChance` → ×2 damage, +5 Focus, animation distinctive
- Crit chain (2 crits consécutifs sur même target dans 8 ticks) : +10 Focus bonus, "chain" badge
- Apply : `enemy.hp -= damage` (ou shield absorb si shield > 0)

### Focus

- Range `[0, 100]`. Reset 0 au start de combat.
- Sources : +5 par crit, +10 par chain (cumulatif)
- Spend : `Espace` (ou bouton UI) consume 50 Focus → trigger immédiat de la carte avec le **meter le plus avancé** (`max meter < 1`)
- Si Focus < 50, action grisée
- V1.5 : sélection manuelle de la carte à trigger

### Combat end

- **Victoire** : enemy HP ≤ 0 → freeze 500ms → loot popup (PRD-07)
- **Défaite** : hero HP ≤ 0 → animation hero down → -1 torche → retreat -1 floor
- **Retreat manuel** : `R` ou bouton → -1 torche → retreat -1 floor

### Server authoritative (Convex)

- Client tick simule en temps réel (optimistic UI).
- **Combat-end mutation** : client envoie `(seed, combat_log_hash)` → Convex re-run combat avec même seed → valide hash → si match, persists outcome.
- Si mismatch : Convex reject, force resync depuis serveur (rare).

## Technical approach

### Réuse existant

- `src/pixi/CharacterEngine.ts` — sprite animations idle/attack/hurt déjà câblés
- `src/game/characters/defs/*` — 12 enemy defs (HP, sprite, anims) prêts à utiliser
- `src/game/characters/types.ts` — types character

### À créer

- `src/game/pit/combat/types.ts` :
  ```ts
  interface CombatState {
    seed: string
    tick: number
    hero: { hp: number, focus: number, meters: Record<Slot, number> }
    enemy: { defId: EnemyDefId, hp: number, intentMeter: number }
    log: CombatEvent[]
  }
  ```
- `src/game/pit/combat/engine.ts` : `tick(state, hero, enemy, dt) → state'`. Pure function, déterministe.
- `src/game/pit/combat/damage.ts` : pure functions damage compute + crit roll
- `src/game/pit/combat/rng.ts` : seeded RNG (mulberry32 ou xorshift) pour reproductibilité
- `src/components/pit/CombatStage.tsx` : composant React qui drive le RAF loop, render hero/enemy sprites
- `src/components/pit/MeterBar.tsx` : barre meter visuelle
- `src/components/pit/IntentDisplay.tsx` : affiche intent enemy
- `src/components/pit/FocusOrb.tsx` : orb Focus UI
- `convex/combat.ts` :
  - `validateCombat(playerId, seed, combatLogHash)` mutation
  - Re-run pure engine côté serveur, compare hash, persists outcome (cf. PRD-07 pour loot)

### RAF loop

`CombatStage` :
- `useEffect` lance `requestAnimationFrame`
- Accumulator pattern : `accumulator += dt; while(accumulator >= 0.25) { tick(); accumulator -= 0.25; }`
- Render entre ticks par interpolation lissée (option V1.5)
- `cancelAnimationFrame` au unmount

### Anti-cheat (lien R10)

- Combat seed généré par Convex au début (`startCombat` mutation retourne seed)
- Client ne peut pas choisir le seed
- Combat log hash = SHA256 du log d'événements (`tick → action → outcome`)
- Convex re-simule avec même seed, hash, compare. ~1ms par combat à valider serveur.

## Data model

Aucune table dédiée combat (V1 ephemeral). `validateCombat` mutation prend :
- `playerId`
- `nodeId`
- `seed` (que Convex a généré au `startCombat`)
- `combatLogHash`

Persists : `lastCombatAt`, `combatsWon`, `combatsLost` dans profile (telemetry).

## Acceptance criteria

- [ ] Combat démarre en <300ms après click sur node
- [ ] Tick rate = 4Hz exactement (mesurable via console.log timing)
- [ ] Action meter visuel update fluide (interpolated entre ticks)
- [ ] Damage display "popup numbers" sur hit, distinctif sur crit
- [ ] Focus orb update en live, action `Espace` consomme 50 si dispo
- [ ] Hero/enemy HP bars update en temps réel
- [ ] Intent enemy visible avant trigger (au moins 1 tick d'avance V1)
- [ ] Combat end → mutation Convex validée, profile updaté
- [ ] Combat seed reproductible : même seed → même log
- [ ] Combat trivial (player power >> enemy) résout en <8s
- [ ] Combat tendu (~même power) ~15-25s

## Dependencies

- PRD-03 (hero stats + equipment)
- PRD-01 (Convex schema players + profiles)

## Open questions

- **Q4.1** RNG seed strategy : Convex génère 1 seed par combat ou 1 seed global par player + tick offset ? **Reco : per-combat seed** retourné par `startCombat`. Plus propre.
- **Q4.2** Hash algo combat log : SHA256 (sécurité) ou xxhash (perf) ? **Reco : SHA256 V1**, audit perf si latency > 50ms.
- **Q4.3** Replay buffer pour debug / share ? **Hors V1**, mais log-event format doit être suffisant pour reconstruire (V2 share replay).
- **Q4.4** Combat tick = 4Hz strict, ou rate adaptive (e.g. 8Hz si combat trivial pour speed up — cf. PRD-12) ? **Reco** : tick reste 4Hz logique, **speed control** = render plus rapide (×2/×4 = compress 2/4 ticks par frame). Tick rate logique unchanged simplifie validation Convex.
- **Q4.5** Animations sprite ↔ tick events : sync exact ou lag visuel ? **Reco** : trigger anim lance au tick exact, anim dure plusieurs frames (1-2 ticks), pas de blocage du tick suivant.
- **Q4.6** Multiple ennemis sur boss (V1) ? **Reco V1 : non**, boss = 1 entité avec multi-intents.
