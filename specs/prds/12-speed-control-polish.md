# PRD-12 — Speed Control, Polish & Mobile-Readable

## Goal

Polish final V1 : speed control combat (x1/x2/x4) + auto-skip trivial replays (V1.5) + help docs in-game + mobile-readable + analytics instrumentation. Clôture la V1 en répondant aux convergences agents (R2 mitigation) et permet itération data-driven post-launch.

## Non-goals

- Mobile-playable full (V2 — V1 = mobile-readable seulement, layout responsive, mais pas optimisé pour touch interactions)
- Skip combat trivial complet "first clear" (V1 = jamais skip premier clear V1 ; V1.5 = auto-skip replays triviaux)
- Tutorial vidéo / animations cinétiques onboarding (V2)
- Telemetry / analytics dashboards externes (V1 = data brute en Convex, dashboards V1.5)
- Customisation avancée UI (V2)
- Localisation / i18n (V2 — V1 = anglais + français comme aujourd'hui)

## User stories

- En tant que **joueur**, je clique un bouton "x2" pendant un combat et la simulation tourne 2× plus vite (mêmes ticks logiques, render compressé).
- En tant que **joueur** qui replay un node clear pour farm, le combat skip à l'auto-resolve (V1.5) avec popup résultat.
- En tant que **joueur** confus sur une mécanique, je clique `?` dans Topbar et un panel help docs apparaît avec recherche.
- En tant que **viewer mobile** (Twitch chat surfing), je peux voir mon depth et mes ressources sans interactions complexes.
- En tant que **dev**, je vois dans Convex les distributions de session length, depth crater point, etc.

## Functional spec

### Speed control combat

Bouton dans CombatStage UI :

```
[x1] [x2] [x4]
```

Active state visible. Default : x1.

Implementation :
- Tick rate logique reste 4Hz (déterministe pour Convex validation)
- `x2` = render appelle `tick(0.25)` 2× par frame (50 simulated ticks/sec, donc combat tourne 2× plus vite réellement)
- `x4` = `tick(0.25)` 4× par frame
- Convex validation reste sur le log final (peu importe le speed côté client)

UI :
- Bouton placé en bas du CombatStage, taille modérée
- Hotkeys : `1`, `2`, `4` toggle speed
- Persistance préférence : `profile.combatSpeedDefault: 1 | 2 | 4`

Pas de speed sur premier combat (D001) — onboarding.

Pas de speed sur boss combat first kill — cérémonie.

### Auto-skip trivial (V1.5 — stretch V1)

Si combat avec `heroPower > enemyThreat × 3` (cf. PRD-06 compute) :
- Popup pré-combat avec preview résultat :
  ```
  ┌─────────────────────────────────┐
  │  TRIVIAL FIGHT                  │
  │  Hollow Archer (D008)           │
  │  Auto-resolve: WIN              │
  │  + 14 ◆, draft 3 cards          │
  │                                 │
  │  [Skip] [Engage anyway]         │
  └─────────────────────────────────┘
  ```
- Skip → animation flash 500ms → loot popup
- Engage anyway → combat normal

Toggle setting "Auto-skip trivial : on/off" — default OFF V1, ON V1.5 si feedback positif.

### Help docs in-game

Bouton `?` discret en Topbar (icone book). Click ouvre panel side-drawer :

```
┌──────────────────────────────────────────────┐
│  HELP                            [×]         │
│  ┌────────────────────────────────────────┐  │
│  │  Search...                             │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Topics:                                     │
│   · Getting started                          │
│   · Combat & Focus                           │
│   · Cards & Equipment                        │
│   · Boss & Milestones                        │
│   · Leaderboard                              │
│   · Offline progress                         │
│                                              │
│  Click a topic to read.                      │
└──────────────────────────────────────────────┘
```

Contenu hardcoded markdown V1, registry V1.5.

Topics = ~6-10 entrées V1, chacune ~200-400 mots.

Recherche texte simple V1 (substring match).

### Mobile-readable

Layout V1 :
- Desktop : layout actuel (full UX)
- Mobile (< 768px) : Topbar pills compactes, Menubar bottom, `/pit` map verticale scrollable
- Combat : interactions touch (tap bouton focus, swipe pour speed)
- **Pas de interactions optimisées V1** : juste responsive layout pour viewing/check

CSS approach :
- Media queries `@media (max-width: 768px)`
- Compact mode pour Topbar / Menubar
- Pas de redesign complet V1

### Analytics instrumentation

Convex events tracking (table `analytics_events`) :

```ts
events: {
  playerId: id<'players'>
  eventType: 'session_start' | 'combat_start' | 'combat_end' | 'node_engage' | 'card_drop' | 'boss_kill' | 'retreat' | 'tab_open' | 'tooltip_seen' | 'milestone' | ...
  payload: any  // event-specific data
  timestamp: number
}
```

Events critical V1 :
- `session_start` : login / page load (computed from heartbeat)
- `combat_start`, `combat_end` (with outcome, duration)
- `boss_kill`
- `retreat` (with depth, reason: defeat | manual)
- `card_drop`, `card_equip`, `card_disenchant`, `card_fuse`
- `tab_open`
- `passive_purchase`
- `tooltip_seen`

Instrumentation est **persistante en DB** mais low-priority (no UI dashboard V1). Permet queries ad-hoc.

V1.5 : exposer dashboards Convex/Custom.

Métriques cible (cf. game-loop doc 09) :
- Funnel D0/D1/D7/D30 par cohorte
- Depth distribution (crater points)
- Time-to-first-boss-kill
- Session length
- Retreat / death rates par depth
- Scrap accumulation curves
- Combats où Focus utilisé (R2 audit)
- Floor replay frequency par node (R7 audit)

### Settings panel (V1)

Accessible via icone engrenage dans Topbar :

```
┌───────────────────────────────────┐
│  SETTINGS                  [×]    │
│                                   │
│  Beginner mode      [on  ▼]       │
│  Combat speed       [x1  ▼]       │
│  Auto-skip trivial  [off ▼]       │
│  Sound volume       [▓▓▓░░ 60%]   │
│                                   │
│  Account                          │
│   Twitch login [Connect / Logout] │
│                                   │
│  About                            │
│   Version v0.1.0-alpha            │
│   Built [date]                    │
└───────────────────────────────────┘
```

V1 ship : settings minimal. V1.5 = sound, keybind customization, etc.

## Technical approach

### À créer

- `src/components/pit/SpeedControl.tsx` : 3-button speed switcher
- `src/components/help/HelpDrawer.tsx` : side panel
- `src/components/help/HelpTopics.tsx` : topic registry + content
- `src/game/onboarding/help-content.ts` : markdown content per topic
- `src/components/settings/SettingsDialog.tsx` : settings panel
- `src/components/loot/TrivialSkipDialog.tsx` : popup auto-skip
- `convex/analytics.ts` :
  - `logEvent(playerId, eventType, payload)` mutation
  - schema additions (table `analytics_events`)
- `src/lib/analytics.ts` : client-side helper avec batching (collect events, flush every 5s ou 10 events)
- CSS responsive `src/index.css` ou per-component modules

### Pre-conditions

- PRD-04 combat engine doit supporter `simulatedTicksPerFrame` paramétré (1 / 2 / 4) sans casser la logique — le tick reste à 4Hz logique, juste sub-step compression.

## Data model

Profile additions :

```ts
profiles.combatSpeedDefault: 1 | 2 | 4  // default 1
profiles.autoSkipTrivial: boolean  // default false V1
profiles.beginnerMode: boolean  // default true (cf. PRD-09)
```

New table :

```ts
analytics_events: {
  playerId: id<'players'>
  eventType: string
  payload: any
  timestamp: number
}
```

Index : `(playerId, timestamp)`, `(eventType, timestamp)`.

V1 retention : 30 days (purge older). V2 = data warehouse / S3 export.

## Acceptance criteria

- [ ] Speed x2 / x4 fait tourner combat 2× / 4× plus vite visuellement
- [ ] Combat tick logic reste 4Hz (Convex validation passe identique)
- [ ] Hotkeys 1/2/4 toggles speed instantanément
- [ ] Help drawer ouvre en <300ms, recherche substring fonctionne
- [ ] Settings panel sauvegarde préférences en Convex
- [ ] Mobile (< 768px) : Topbar + Menubar lisibles, map scrollable, combat interactable touch
- [ ] Analytics events logés async sans bloquer UI
- [ ] No event loss visible (batching gère reconnexions transient)
- [ ] First combat (D001) ne montre pas speed control (preserve onboarding)

## Dependencies

- PRD-04 (combat engine — speed compression)
- PRD-06 (predicted threat — auto-skip trivial detection)
- PRD-09 (beginner mode = settings toggle)
- PRD-01 (profile pour persist settings)

## Open questions

- **Q12.1** Auto-skip trivial : ship V1 ou V1.5 ? **Reco V1 : ship**, par défaut OFF, default ON V1.5 si feedback bon.
- **Q12.2** Help docs : 6, 8, ou 10 topics V1 ? **Reco : 6 topics V1** (getting started, combat, cards, boss, leaderboard, offline). Ajout V1.5.
- **Q12.3** Mobile breakpoint : 768px standard ou 1024px (tablet OK desktop) ? **Reco : 768px** strict mobile, 1024+ = desktop layout.
- **Q12.4** Analytics events retention 30j V1 : suffisant ? **Reco V1 : 30j**, V1.5 = export S3 ou warehouse pour analyse longue durée.
- **Q12.5** Speed control disponible sur boss combat ? **Reco V1 : seulement après first kill**. First kill = cérémonie unfaltered.
- **Q12.6** Settings panel : keybinds custom V1 ? **Reco : non**, V1 fixe (D/P/C/X/L/Espace/R), V1.5 = customization.
