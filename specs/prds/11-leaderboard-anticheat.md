# PRD-11 — Leaderboard & Anti-cheat

## Goal

Leaderboard tiered (Surface/Shaft/Caverns/Abyss/Deeppit) avec percentile prominent + nearby cohort, et anti-cheat lite (rate limits + anomaly detection) pour préserver crédibilité du seul score = `deepestDepth`.

## Non-goals

- Seasonal soft-reset trimestriel (V2 — architectural ready V1)
- Friend leaderboards / social graph (V1.5)
- Twitch streamer leaderboards intégrés directement (V1.5)
- Daily seed challenge leaderboard (Q15 — V1 si scoped, sinon V2)
- Anti-cheat avancé (server-side combat replay validation deep) — V1 = hash check seulement, V1.5 = full re-sim
- Replay sharing (V2)
- Hardcore mode separate leaderboard (Q14 — V2)

## User stories

- En tant que **joueur**, je vois ma position percentile globale ("Top 17.4%") plus que mon rang absolu.
- En tant que **joueur**, je vois ma cohorte (joueurs ±5 ranks autour de moi) avec pseudonymes/avatars.
- En tant que **joueur D047**, je vois que je suis "Surface tier" et le seuil pour passer "Shaft" (D26+).
- En tant que **joueur**, je peux switch entre "All-time" et "Weekly depth gain" (V1 stretch — V2 sinon).
- En tant que **fair-play player**, je suis convaincu que les scores top sont crédibles (anti-cheat visible).

## Functional spec

### Affichage onglet Leaderboard

Default view : **My Standing** (centré sur le joueur)

```
┌──────────────────────────────────────────────────────────┐
│  LEADERBOARD                                             │
│  [My Standing] [Tiers] [All-time]                        │
│                                                          │
│  YOU                                                     │
│   D047 · Surface tier · Top 17.4%                       │
│   12 floors to Shaft tier (D26+)                         │
│                                                          │
│  NEARBY                                                  │
│   #2,107  D052  zoltrix_dive                            │
│   #2,108  D050  silent_lurker                           │
│   #2,109  D047  YOU                                     │
│   #2,110  D045  brass_monk                              │
│   #2,111  D044  hollow_zara                             │
└──────────────────────────────────────────────────────────┘
```

### Tiers view

Vue des bandes :

```
┌─────────────────────────────────────────────┐
│  TIERS                                      │
│                                             │
│  DEEPPIT (D301+)         92 explorers       │
│  ABYSS (D151–300)         418 explorers     │
│  CAVERNS (D76–150)       2,143 explorers    │
│  SHAFT (D26–75)         12,872 explorers    │
│  SURFACE (D0–25)        43,201 explorers    │
│                                             │
│  YOU: SURFACE (D047)                        │
└─────────────────────────────────────────────┘
```

### All-time view

Top 100 affichés, pagination si plus :

```
┌─────────────────────────────────────────────┐
│  ALL-TIME · DEEPPIT                         │
│                                             │
│  #1   D 871   ironkord       3 weeks ago    │
│  #2   D 854   void_walker    1 week ago     │
│  #3   D 809   thane_jr       4 days ago     │
│  ...                                        │
└─────────────────────────────────────────────┘
```

### Anti-cheat lite V1

3 layers :

**Layer 1 : Authoritative Convex** (cf. PRD-04)
- Tous les depth gains résultent d'un combat win validated par Convex
- Combat seed généré serveur, hash log validé end-of-combat
- Client ne peut jamais set `deepestDepth` directement

**Layer 2 : Rate limits + heartbeat**
- Mutation rate limits : max 1 mutation `validateCombat` par 8s (combat min duration)
- Heartbeat throttle (cf. PRD-10) : 1 par 30s
- Suspicion si > N mutations / window

**Layer 3 : Anomaly detection**
- Server cron (Convex scheduled action) check toutes les heures :
  - Détecte gains depth > 50 en 5 min : flag suspect
  - Détecte combat avg duration < 1s : flag suspect
- Flagged accounts → silent shadow ban (leaderboard hidden, gameplay continues — anti-tip-off)
- Manual review optional V1, automated unban V1.5

### Query patterns

Convex queries efficient :
- `getLeaderboardNearby(playerId, range=5)` : retourne ±5 joueurs autour de player
- `getLeaderboardTop(tier, limit=100)` : top N par tier
- `getTierCounts()` : count par tier (cached 5 min)
- `getMyRank(playerId)` : rang global + percentile

Toutes les queries Convex exclude shadow-banned accounts.

### Tier détermination

Computé from `deepestDepth` :

```ts
function tierForDepth(depth: number): Tier {
  if (depth >= 301) return 'deeppit'
  if (depth >= 151) return 'abyss'
  if (depth >= 76) return 'caverns'
  if (depth >= 26) return 'shaft'
  return 'surface'
}
```

### Display name leaderboard

Auth obligatoire (cf. PRD-01) → tous les joueurs ont un Twitch display name + avatar.

- Affichage : `{twitchDisplayName}` + avatar thumbnail
- Hover sur le nom : link to twitch.tv/{login} (V1.5)
- Pas de "anonymous descender" V1 — tous les joueurs sont identifiés Twitch.

### Architectural readiness — Seasons (V2)

Schema prévoit dès V1 :

```ts
profiles.deepestDepth: number  // all-time
profiles.deepestDepthSeason?: number  // current season — V1 = unused, V2 = active
profiles.seasonId?: string  // active season ID — V1 = null
```

Permet de greffer seasons en V2 sans rebuild.

### Predicted Depth interaction (lien PRD-06)

Player view affiche aussi `predicted sustainable depth` à côté de `deepestDepth` :
```
You: D047 (sustainable to ~D125)
```

Donne hope visuel + connection avec R1 mitigation.

## Technical approach

### À créer

- `convex/leaderboard.ts` :
  - Queries : `getNearby`, `getTop`, `getTierCounts`, `getMyRank`
  - Index Convex : `profiles` indexed par `deepestDepth desc`
- `convex/anomaly.ts` :
  - Cron action `runAnomalyDetection()` (every hour)
  - `flagSuspect(playerId, reason)` mutation
  - profile field `shadowBanned: boolean` + `shadowBanReason?: string`
- `src/routes/leaderboard.tsx` : full route, vue tabs (My Standing / Tiers / All-time)
- `src/components/leaderboard/MyStanding.tsx`
- `src/components/leaderboard/TiersView.tsx`
- `src/components/leaderboard/AllTimeList.tsx`
- `src/game/pit/leaderboard/tiers.ts` : `tierForDepth`, `tierThresholds`, `tierName`

### Pre-conditions

- PRD-01 schema `deepestDepth` existant
- PRD-08 cérémonie boss déclenche tab unlock leaderboard

## Data model

Profile additions :

```ts
profiles.shadowBanned: boolean
profiles.shadowBanReason?: string
profiles.deepestDepthSeason?: number  // V1 unused, V2 active
profiles.seasonId?: string  // V1 = null
```

Index :

```
profiles by ['deepestDepth desc'] excluding shadowBanned
profiles by ['deepestDepthSeason desc', seasonId]
```

## Acceptance criteria

- [ ] Onglet Leaderboard charge en <1s pour 50K joueurs (test perf)
- [ ] My Standing default vue : nearby ±5 + percentile + tier name
- [ ] Tier badges visuellement distinctifs
- [ ] Twitch logged : display name + avatar visible. Anonymous : pseudonyme stable.
- [ ] Anomaly detection trigger dans <1h après comportement suspect
- [ ] Shadow-banned accounts invisible dans leaderboard (n'impacte pas leur gameplay)
- [ ] Architecture supporte ajout `seasonId` sans schema migration breaking V2
- [ ] Mutation `validateCombat` rate-limited (max 1 / 8s par player)

## Dependencies

- PRD-01 (profile + identity)
- PRD-04 (combat validation = anti-cheat layer)
- PRD-05 (depth tracking)
- PRD-08 (tab unlock on first boss)

## Open questions

- **Q11.1** (Q15) Daily seed challenge V1 ou V2 ? **Reco V1 : non**, complexité scope. V2 oui (donne dimension compétitive + drives engagement).
- **Q11.2** Stretch V1 : "Weekly depth gain" leaderboard secondaire (gain cette semaine) ? **Reco V1 : non**, V2 = oui (mitigates R3 + R12).
- **Q11.3** Anomaly detection thresholds exacts : `+50 depth en 5min`, `combat <1s avg`. À tuner par data. **Reco** : valeurs initiales conservatrices, monitor false-positives.
- **Q11.4** Shadow ban appel : silencieux (player ne sait pas) ou notif "review pending" ? **Reco V1 : silencieux** (anti-tip-off), V2 = appeals UI.
- **Q11.5** (Q19) Seasons V2 confirmé : trimestrielles ? Reset complet ou softer ? **Reco V2 : trimestrielles + soft reset** (depth seasonal reset à 0, all-time conservé).
- **Q11.6** Hardcore mode (Q14) : leaderboard séparé ? **Reco V2** : oui — flag `hardcore: boolean` au profile, leaderboard split.
- **Q11.7** ~~Pseudonymes anonymous~~ Obsolète — auth Twitch obligatoire (cf. PRD-01).
- **Q11.8** Filter du leaderboard par streamer (montrer uniquement viewers de tel streamer) ? **Reco V1.5** — feature compelling pour Twitch integration mais hors scope V1.
