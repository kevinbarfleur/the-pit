# PRD-08 — Boss & Milestones

## Goal

Boss à profondeurs fixes (D10 et D25 V1) avec cérémonies marquantes (R4 mitigation), drops uniques, et milestones pour ponctuer la perpetual descent. Sans cérémonie, perpetual descent = pas de payoff émotionnel.

## Non-goals

- 5+ boss types différents V1 (V1 = **1 boss visuel** réutilisé : "Pit Warden", scaling à D10 et D25)
- Mini-boss D5 / D17 / D37 (Q17 — V2 sauf décision contraire)
- Multi-phase boss complex avec multiple stages V1 (V1.5 — V1 = 1 boss = 1 phase + intent rotations basique)
- Lore système full / dialogues animés (V1 = drop texte court par milestone)
- Boss enrage timer (V1.5)
- Boss random drops T4 (V1 = boss drop garanti déterministe sur first kill)

## User stories

- En tant que **joueur** descendant, je vois la silhouette de Pit Warden 5 floors avant D10 et le combat est anticipé.
- En tant que **joueur**, je clic le node boss D10 et le combat se lance avec UI distinctive (bigger, glow, intent lourd).
- En tant que **joueur** qui clear D10 first time, je vois une cérémonie : screen flash, animation, "milestone unlocked: Pit Warden Slayer", titre attribué.
- En tant que **joueur**, je récupère un drop boss garanti : T2 ou T3 carte unique "Pit Warden Crown".
- En tant que **joueur**, je peux re-engager D10 plus tard mais boss stats scalent légèrement et drops dégradent (×0.4).

## Functional spec

### Boss V1

**Pit Warden** :
- Sprite : silhouette plus grosse, palette rouge/dark (réuse `templar.ts` ou `demon.ts` adaptés)
- HP : `D10 = 250`, `D25 = 600` (scaling × ~2.4 par tier)
- Intent base : "heavy strike" (damage ×2 vs combat normal, SPD 0.6)
- Multi-intent V1 : 2 intents alternés (heavy strike, defensive stance), rotation visible

### Boss telegraph (lien PRD-05)

- Sprite plus grand sur la map
- Glow effect (réuse `EffectsEngine`)
- Label "the warden waits" sur hover
- Visible 5 floors avant son depth

### Combat boss

Différences vs combat normal :
- HP boss × ~3
- Intent multi-step (rotation visible)
- **Pas de Focus burst trivial** : boss a window "armor phase" tous les ~10 ticks où damage taken = ×0.5
- Durée combat target : 60-120s
- Pas de retreat free : retreat coût torche × 2 sur combat boss (Q3 consolidé)
- Cooldown re-engage boss après défaite : 30 minutes IRL (Q3)

### Cérémonie milestone

À **first kill** d'un boss au depth donné :

1. **Screen flash** + freeze 1.5s
2. **Animation** : sprite boss tombe, fade dramatique
3. **Popup cérémonie** :
   ```
   ┌────────────────────────────────────────┐
   │  PIT WARDEN VANQUISHED                 │
   │  Depth D010                            │
   │                                        │
   │  + 50 ◆ scrap                          │
   │  + 1 ✦ shard                           │
   │  + Pit Warden Crown (T2)               │
   │                                        │
   │  TITLE: WARDEN SLAYER                  │
   │  > "the deeper layers open."           │
   └────────────────────────────────────────┘
   ```
4. **Lore drop** : 2-3 lignes texte (V1 = hardcoded, V1.5 = registry)
5. **Tab unlock** (cf. PRD-02) : Leaderboard apparaît si premier boss kill ever

### Re-engage boss (replay)

Après first kill, boss D10 = `cleared-replayable` :
- Combat boss s'engage normalement
- Drops dégradent : pas de Crown unique (déjà obtenu), juste scrap + chance T2 du pool
- Retreat coût torche × 2 toujours
- Cooldown 30 min après défaite reste en vigueur

### Milestones supplémentaires V1

Sans boss, marqueurs de progression :

| Depth | Milestone |
|---|---|
| D001 (premier node clear) | "First step into the pit" — title : Descender |
| D010 | Pit Warden 1st kill — title : Warden Slayer |
| D025 | Pit Warden 2nd kill — title : Twice-Slayer |
| D050 (V1.5) | Mid-pit boss — V1 = milestone marker |
| D100 (V1.5) | Deeppit milestone marker V1 |

V1 ship D1, D10, D25 milestones avec cérémonie. D50, D100 = simple banner display only V1.

### Profile tracking

Champs ajoutés au profile :

```ts
profiles.bossesKilled: { bossId: string, depth: number, killedAt: number, attempts: number }[]
profiles.milestonesUnlocked: { milestoneId: string, unlockedAt: number }[]
profiles.titles: string[]  // ['descender', 'warden_slayer', ...]
profiles.activeTitle?: string  // displayed on leaderboard
```

## Technical approach

### Réuse existant

- `src/game/characters/defs/*` — base char defs (templar / demon adaptable pour boss)
- `src/pixi/CharacterEngine.ts` — sprite engine (boss = bigger scale param)
- `src/pixi/EffectsEngine.ts` — effects pour glow + flash
- `src/hooks/useAttachedEffect.ts` — attach glow effect au boss node

### À créer

- `src/game/pit/bosses/types.ts` : `BossDef`, `BossPhase`, `BossIntent`
- `src/game/pit/bosses/data.ts` : registry boss V1 (`pit_warden`)
- `src/game/pit/bosses/scaling.ts` : scaling stats par depth tier
- `src/components/pit/BossNode.tsx` : visual node boss (glow + size + label)
- `src/components/pit/BossCombatStage.tsx` : extends `CombatStage` avec intent rotation + armor windows
- `src/components/milestones/MilestoneCeremony.tsx` : cérémonie animée
- `src/components/milestones/MilestonePopup.tsx` : popup texte cérémonie
- `src/game/pit/milestones/data.ts` : registry milestones V1
- `convex/bosses.ts` :
  - `recordBossKill(playerId, bossId, depth)` mutation
  - `getBossKills(playerId)` query
- `convex/milestones.ts` :
  - `unlockMilestone(playerId, milestoneId)` mutation
  - `getMilestones(playerId)` query

### Pre-conditions

- PRD-04 combat engine doit supporter multi-intent rotations (extension simple — boss a un array d'intents au lieu de 1)
- PRD-04 doit supporter "armor phase" damage modifier (V1 simple : tick range où damage taken modifié)

## Data model

Cf. profile additions ci-dessus. Pas de table dédiée boss — milestones et bossesKilled stockés dans profile (low-volume).

## Acceptance criteria

- [ ] Boss D10 visible distinctement depuis depth D5
- [ ] Combat boss dure 60-120s avec build matched
- [ ] Boss intent rotation visible (2 intents alternés V1)
- [ ] Armor window réduit damage de 50% (1-2 fenêtres par combat)
- [ ] First kill boss D10 déclenche cérémonie + drop Pit Warden Crown garanti
- [ ] Title "Warden Slayer" attribué et visible profile/leaderboard
- [ ] Re-engage boss après first kill : pas de Crown, drops dégradés
- [ ] Cooldown 30 min après défaite respecté côté serveur
- [ ] Milestone D1 (first node clear) déclenche cérémonie atténuée

## Dependencies

- PRD-04 (combat engine + multi-intent support)
- PRD-05 (map node states + boss telegraph)
- PRD-07 (Pit Warden Crown card def in registry)
- PRD-02 (Leaderboard tab unlock on first boss)

## Open questions

- **Q8.1** (Q17) Mini-bosses D5 / D17 / D37 V1 ? **Reco V1 : non**, ship 2 boss V1 (D10, D25) + milestones D1/D10/D25. V1.5 = mini-bosses pour densifier.
- **Q8.2** Pit Warden Crown stats exactes (T2 charm proc) ? À drafter dans `07a-cardlist.md`.
- **Q8.3** Boss death = kick to D9 (back from D10) ou retreat à D8 (-2) ? **Reco V1 : retreat -1 normal** (D9). Pas de pénalité supérieure (Q3 cooldown 30min suffit).
- **Q8.4** Lore drop V1 : 1 paragraphe par milestone hardcoded en TS, ou Convex registry ? **Reco V1 : hardcoded TS**, V1.5 = registry pour facilité d'ajout.
- **Q8.5** Active title sur leaderboard : V1 le joueur peut choisir parmi ses titles, ou auto = dernier obtenu ? **Reco V1 : auto = dernier obtenu**, V1.5 = choisi.
- **Q8.6** Cérémonie skipable (pour replay rapides) ? **Reco V1 : non skipable on first kill**, skipable sur replay (déjà vu).
