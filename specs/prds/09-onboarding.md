# PRD-09 — Onboarding

## Goal

Onboarding **non-bloquant**, contextuel, qui amène un joueur post-Twitch-login à comprendre le jeu **en moins de 90 secondes** sans modal tutoriel ni text wall. Mitigation #2 du R5 : sans cela, D1 retention crater.

**Contexte auth** : depuis PRD-01, l'auth Twitch est obligatoire AVANT l'onboarding. Le compteur 90s commence APRÈS le redirect successful vers `/pit` (post-OAuth). La page `/auth` doit elle-même être ultra-épurée (1 CTA "Connect with Twitch", pas de friction).

## Non-goals

- Modal tutoriel intro lourd (anti-pattern, banni)
- Voice over / cutscene
- Onboarding séquentiel obligatoire (anti-pattern)
- Forced first-action sequence (banni — joueur doit explorer librement)
- Walkthrough par segments avec progress bar
- Achievements onboarding (V1.5)

## User stories

- En tant que **visiteur Twitch curieux**, j'arrive sur `/auth`, je clique "Connect with Twitch", je consent OAuth, je land sur `/pit` — un node éclairé pulse → je comprends que je dois cliquer.
- En tant que **nouveau joueur** sans expérience roguelite, je gagne mon premier combat sans difficulté (winnable garanti).
- En tant que **nouveau joueur**, j'ai une carte qui drop et un mini-tooltip discret me dit "this card is now equipped" → je comprends sans modal.
- En tant que **nouveau joueur** qui clique le bouton Focus pour la première fois, un tooltip me dit "Focus consumed → instant trigger" et il disparaît à jamais.

## Functional spec

### Premier launch — UX

T+0 : land sur `/pit`. Map verticale visible. **Un seul node** est mis en évidence à `D001` :
- Pulse animation (subtle, 1.2s loop)
- Tooltip ambient : `click to descend`
- Tous autres nodes dimmed jusqu'à first click

T+0 : la torche affiche `5/5`, les autres pills ressources sont à `0` ou cachées (V1.5). Topbar minimal.

### Premier combat (D001)

**Garanti winnable** : enemy "training rat" weak, hero starting stats peut le battre en ~10s sans crit luck.

Pendant le combat :
- Au start : tooltip "your sword is on auto" pointing à action meter (3s, dismiss au scroll)
- Au premier crit : tooltip "+5 focus" sur orb (2s)
- Au premier full-meter trigger : visual cue + sound

Après victoire : zoom-out + draft loot popup (cf. PRD-07).

### Premier loot (drop 3 cards)

Tooltip discret sur le draft :
- "pick one — this becomes your gear"
- Si joueur survole une carte : preview équipée (ghost on hero stats)

Au accept : tooltip 1.5s "equipped: {card name} — your stats updated". Disparaît permanente.

### Premier event / shop / treasure

- Avant click first event node : tooltip "events offer narrative choices" (1×)
- Avant click first treasure node : "treasure rooms drop loot without combat" (1×)

V1 : ces nodes secondaires sont stubs, mais tooltips s'appliquent quand même (préparent V1.5 fonctionnel).

### Stuck / first retreat

Au premier retreat (death ou volontaire) :
- Tooltip 5s : "you retreated. cards kept, -1 torch. push deeper when ready."

### Discovery — Tabs

Au unlock de tab `[P] Passives` (premier node clear) :
- Tooltip pointing à la nouvelle icone : "spend scrap on permanent upgrades" (5s)
- Auto-dismiss au click ou time

Au unlock `[L] Leaderboard` (premier boss kill) :
- Cérémonie boss inclut déjà la mention (cf. PRD-08)
- Tooltip secondary 3s : "see other descenders"

### "Aha moment" target — <60s

Premier 60s du joueur doit inclure :
1. T+0-10s : land + voir le pit + comprendre où cliquer
2. T+10-25s : premier combat engage
3. T+25-35s : voir damage popup, voir hp descend
4. T+35-45s : combat win
5. T+45-60s : pick first card → voir hero stats update

Si à T+60s le joueur n'a **pas vu un drop ou un swap stats**, l'onboarding rate.

### Tooltips — règles

- **Non-bloquants** : popup overlay non-modal, semi-opaque
- **Auto-dismiss** : 3-8s (selon longueur texte) OR au scroll OR au click ailleurs
- **One-shot** : chaque tooltip apparaît **une seule fois** dans la vie du compte (persisté Convex)
- **Localisable** : pointer/arrow vers l'élément concerné
- **Cap** : max 5 tooltips dans les 5 premières minutes

### "Beginner mode" toggle (V1)

Settings (icone discret) :
- `Beginner mode: on` (default)  — affiche tooltips + indicateurs (R6 predicted depth visible)
- `Beginner mode: off` — supprime tous tooltips + indicateurs subtils

Default : on V1. V1.5 = adaptive (auto-disable après N hours de jeu).

## Technical approach

### À créer

- `src/components/onboarding/Tooltip.tsx` : tooltip non-bloquant universel
- `src/components/onboarding/OnboardingProvider.tsx` : context + tooltip queue management
- `src/hooks/useOnboardingFlag.ts` : check + set "tooltip seen" flags
- `src/game/onboarding/triggers.ts` : registry des tooltips (`when=`first node click`, `text=...`, `target=...`)
- `convex/onboarding.ts` :
  - `markTooltipSeen(playerId, tooltipId)` mutation
  - profile field `onboardingFlags: string[]`
- `src/components/pit/PulseNodeFX.tsx` : pulse animation pour first node

### Pre-conditions

- PRD-04 combat engine doit garantir premier combat winnable (cf. PRD-04 acceptance "first fight winnable")
- Tooltip system doit être hook-into-able from divers components

## Data model

Profile additions :

```ts
profiles.onboardingFlags: string[]  // ['first_node_seen', 'first_crit', 'first_loot', ...]
profiles.beginnerMode: boolean  // default true
```

## Acceptance criteria

- [ ] T+0 : node D001 pulse, tooltip "click to descend" visible
- [ ] First combat winnable par 95%+ joueurs (training rat HP/dmg balanced pour starting hero)
- [ ] Tooltips apparaissent **une seule fois** par compte (persistance Convex)
- [ ] Aucun tooltip n'apparaît plus de 5 fois dans les 5 premières minutes
- [ ] Aha moment ≤60s (joueur a vu un swap stats)
- [ ] `Beginner mode: off` supprime 100% des tooltips + indicateurs subtils
- [ ] First retreat → tooltip explicatif, joueur ne croit pas avoir perdu
- [ ] Tab unlock animation s'accompagne du bon tooltip
- [ ] Aucun tooltip ne bloque l'input joueur

## Dependencies

- PRD-02 (tab unlock progressive — onboarding s'accroche aux events)
- PRD-04 (first combat winnable garanti)
- PRD-07 (first loot draft → tooltip)

## Open questions

- **Q9.1** Premier ennemi "training rat" : nouveau character def, ou ré-utiliser un existant atténué ? **Reco** : créer `defs/training_rat.ts` dédié, juste pour D001 (HP très bas, damage faible).
- **Q9.2** `Beginner mode: off` accessible où ? Settings dans Topbar / Menubar ? **Reco** : icône engrenage Topbar, pop settings dialog avec quelques toggles.
- **Q9.3** Adaptive auto-disable beginner mode après N heures ? **Reco V1 : non**, V1.5 = oui après 5h jouées.
- **Q9.4** Tooltip system : prebuilt lib (Floating UI ?) ou maison ? **Reco : Floating UI** (déjà couvert par certaines deps probablement, sinon léger 5kb) — anti réinventer positionning math.
- **Q9.5** Premier combat tooltips : peut-on en mettre 2 simultanés (orb focus + meter sword) ? **Reco : non**, queue séquentiellement (dismiss before next).
- **Q9.6** Joueur skip volontairement first node (clique random) — tooltip "click to descend" persiste ou disparaît ? **Reco : persiste 8s puis fade**, on ne force pas.
