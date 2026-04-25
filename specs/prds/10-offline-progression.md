# PRD-10 — Offline Progression

## Goal

Permettre au joueur déconnecté d'accumuler **scrap passif** (uniquement scrap, pas de cartes ni de depth) selon cap 8h × 25% rate. Recovery screen au reload qui annonce le gain. Réutilise spec CLAUDE.md et game-loop doc 09 (Q12 confirmé "scrap only").

## Non-goals

- Combat / depth progress offline (banni — active descent > offline)
- Drops cartes offline (V1 = scrap only — Q12)
- Boss kills offline (jamais)
- Offline >8h cap (V1 = 8h max ; V1.5 considère 12h via passive Depth tree)
- Notifications push "your scrap is overflowing" (V1.5 — V1 = passive only)
- Offline boost via micro-transactions (jamais V1)

## User stories

- En tant que **joueur** qui ferme le navigateur 3h, je reviens et je vois "while you were away: +124 ◆ scrap accumulated".
- En tant que **joueur** absent 12h (au-delà du cap), je vois +scrap correspondant à 8h × 25% rate (cap respecté).
- En tant que **joueur** qui dismisse la notif, le scrap est crédité, je continue.
- En tant que **joueur**, l'offline ne fait pas progresser ma depth (mon `currentDepth` reste exact).

## Functional spec

### Compute

À la connexion (login successful, profile fetched) :

```
Δt = now - lastSeenAt
effective_offline_ms = min(Δt, OFFLINE_CAP_MS)  // cap 8h = 8 * 3600 * 1000
scrap_rate_offline = ACTIVE_SCRAP_RATE * 0.25  // 25% of active rate
scrap_earned = (effective_offline_ms / 1000) * scrap_rate_offline
```

`ACTIVE_SCRAP_RATE` = scrap moyen par seconde durant active play, **dérivé statistique** (calculé serveur-side une fois par jour, snapshot par player ou global). V1 simplification : valeur fixe par defaut (ex 0.05 scrap/sec ≈ 180/h active → 45/h offline, soit 360 scrap pour 8h offline cap).

Tuner par data post-launch.

### Recovery screen

Au login successful + offline gain > 0 :

```
┌──────────────────────────────────────────┐
│  WELCOME BACK                            │
│                                          │
│  You were away for 5h 12m.               │
│  + 234 ◆ accumulated                     │
│                                          │
│  [Continue]                              │
└──────────────────────────────────────────┘
```

Animation cumul : counter scrolle de 0 à 234 en 1.5s (satisfaction NGU-style).

Cas edge :
- Δt < 5 min : pas de popup, scrap directement crédité (no-op visuel)
- Δt > 8h : popup mentionne "(capped at 8h)" en small text discret
- Première session : pas de popup (rien à recover)

### Server-side compute

`profiles.lastSeenAt` updaté à chaque mutation critique (heartbeat).

Au login :
- Convex action `claimOffline(playerId)` :
  1. Read `lastSeenAt`
  2. Compute scrap_earned
  3. `profiles.totalScrap += scrap_earned`
  4. `profiles.lastSeenAt = now`
  5. Return { scrapEarned, awayMs }

Atomique (Convex mutation) → pas de double-claim.

### Anti-abuse (lien R10)

- Server-side compute uniquement (client ne peut pas claim plus)
- Heartbeat update `lastSeenAt` toutes les ~30s d'activité (reduce window de spoof)
- Cap 8h respecté serveur-side (clamping)

## Technical approach

### Réuse existant

- `convex/profiles.ts` — pattern mutation `updateDepth` extensible
- `src/hooks/usePlayerProfile.ts` — hook profil

### À créer

- `convex/offline.ts` :
  - `claimOffline(playerId)` mutation atomic
  - constantes `OFFLINE_CAP_MS = 8 * 3600 * 1000`, `OFFLINE_RATE_RATIO = 0.25`
- `src/hooks/useOfflineRecovery.ts` :
  - Au mount : si `lastSeenAt` détecté > 5min ago, trigger `claimOffline`
  - State machine : `idle → claiming → recovered → dismissed`
- `src/components/recovery/RecoveryDialog.tsx` : popup welcome back avec counter animé
- `convex/heartbeat.ts` :
  - `heartbeat(playerId)` mutation appelée toutes ~30s par client actif
  - Updates `profiles.lastSeenAt = now`

### Pre-conditions

- PRD-01 schema doit avoir `lastSeenAt` (déjà mentionné).
- Heartbeat doit être appelé throttled — utiliser `setInterval` côté client avec backoff sur tab hidden.

## Data model

`profiles.lastSeenAt: number` (déjà dans PRD-01 schema).

Pas de stockage du recovery (one-shot, computed dynamic).

V1.5 : telemetry log `offline_claims` table pour analyse des distributions (median offline duration, etc.).

## Acceptance criteria

- [ ] Δt < 5 min : pas de popup, no-op
- [ ] Δt = 1h : popup affiche "+45 ◆" approximativement (selon `ACTIVE_SCRAP_RATE`)
- [ ] Δt = 12h : popup affiche cap "+360 ◆" (capped at 8h)
- [ ] Counter animation cumul fluide en 1.5s
- [ ] Dismiss → scrap visible dans Topbar pills updaté
- [ ] Pas de double-claim possible (test : F5 immédiat → no popup)
- [ ] Compute server-side : client ne peut pas inflate (mutation Convex idempotent)
- [ ] Heartbeat tourne toutes ~30s en active, pas en background tab

## Dependencies

- PRD-01 (profile schema + lastSeenAt)
- PRD-02 (Topbar pills update on scrap change)

## Open questions

- **Q10.1** `ACTIVE_SCRAP_RATE` valeur initiale : quel rate raisonnable ? **Reco V1 : 0.05/sec hardcoded** (180/h active, 45/h offline). Tuner avec data D14.
- **Q10.2** Snapshot par-player du rate (basé sur le rate du joueur les 7 derniers jours) ou global flat ? **Reco V1 : global flat**, V1.5 = per-player adaptive.
- **Q10.3** Offline cap 8h fixed V1, ou extensible via passive Depth tree (12h max V1.5) ? **Reco V1 : fixed 8h** ; V1.5 = passives Depth I (+1h cap), Depth II (+2h cap), etc.
- **Q10.4** Le compteur animation : start à 0 ou continue depuis valeur affichée ? **Reco : start de 0 → cible**, plus satisfying.
- **Q10.5** Visibility tab change : continue de heartbeat ou pause ? **Reco : pause heartbeat sur `visibilitychange:hidden`**, reprend au focus. Économise mutations Convex.
- **Q10.6** Tooltip explicatif onboarding pour offline (premier popup recovery) : "scrap accumulated while you were away (capped at 8h, 25% rate)" ? **Reco : oui, tooltip 1×** au premier recovery seulement.
