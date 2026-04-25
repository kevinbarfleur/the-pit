# PRD-01 — Identity & Persistence

## Goal

Tout joueur s'authentifie via **Twitch OAuth** avant tout accès au gameplay. Le profil (depth, scrap, inventory) est lié au `twitchUserId` et persisté Convex. Pas d'accès anonyme V1.

## Non-goals

- Email / password auth (jamais V1)
- Anonymous play / guest mode (banni V1 — décision user)
- Twitch login optionnel / upgrade flow (obsolète — décision user)
- Achievements / badges Twitch (V2)
- Multi-device sync explicite (V1 = 1 compte Twitch = 1 profile, multi-device gratuit via Twitch ID)
- Suppression de compte / RGPD self-service UI (V1 = manuel par ticket)

## User stories

- En tant que **visiteur** sans session Twitch active, j'arrive sur `/`, je vois un écran "Connect with Twitch" et un bouton OAuth.
- En tant que **viewer Twitch déjà loggé sur twitch.tv** dans le même browser, le flow OAuth est rapide (2-3s, prompt consent une fois) et je suis dans le pit.
- En tant que **joueur** qui ferme l'onglet, je retrouve `currentDepth`, scrap et inventory exactement à la réouverture (Twitch session persiste via cookie/refresh token).
- En tant que **streamer**, mon Twitch display name + avatar apparaissent automatiquement au leaderboard.
- En tant que **joueur** sur 2nd device, je login Twitch et retrouve mon profil identique (server-side via Twitch ID).

## Functional spec

### Flow auth obligatoire

- Visite `/` sans session Twitch active → redirect vers `/auth` (écran login).
- `/auth` affiche un bouton dominant "Connect with Twitch" + branding minimal + 1-2 lignes de pitch.
- Click → OAuth flow Twitch (Helix) avec scopes minimum (`openid`, `user:read:email` optionnel).
- Callback Convex action valide token, fetch profile Twitch (`userId`, `displayName`, `avatarUrl`).
- Si `players` row existe pour `twitchUserId` → hydrate. Sinon → crée `players` + `profiles` rows.
- Set session cookie (HttpOnly, Secure, SameSite=Lax) avec session token signé serveur.
- Redirect `/pit`.

### Session

- Session Convex-managed via cookie. Refresh token Twitch stocké server-side (encrypted at rest).
- Frontend ne voit jamais le Twitch access token directement.
- Logout : button accessible dans Settings (PRD-12) → invalide session cookie + redirect `/auth`.

### Profile binding

- Toutes les mutations critiques prennent `playerId` Convex (jamais `twitchUserId` direct côté client — server-side resolved).
- Profil tient : `currentDepth`, `deepestDepth`, `seed`, `totalScrap`, `totalShards`, `torchCurrent`, `torchMax`, `cardsInventory`, `cardsEquipped`, `passivesOwned`, `lastSeenAt`, `totalPlayTimeMs`, `createdAt`, `prestigeLevel` (V1=0).

### Display

Topbar title = `the pit · {twitchDisplayName}` (lowercased).
Avatar Twitch fetched + cached côté client, fallback silhouette si erreur.

### Edge cases

- Token Twitch expiré / révoqué : refresh silencieux server-side. Si fail définitif → logout forcé + retour `/auth`.
- Twitch service down : message "Twitch unavailable, try again" sur `/auth`. Pas de fallback.
- Compte Twitch supprimé : `players` row gardé orphan (privacy — V1 manuel cleanup).

## Technical approach

> **Lire d'abord [`REUSE-INVENTORY.md`](./REUSE-INVENTORY.md) §1, §6, §9.** Tout composant existant doit être étendu, pas dupliqué.

### Réuse existant (chemins exacts)

- `convex/schema.ts` — étendre `players` (ajouter `twitchUserId`, `twitchDisplayName`, `twitchAvatarUrl`) + ajouter table `sessions`. Garder `profiles` actuel + l'étendre.
- `convex/players.ts` — refactor `getOrCreateByAnonId` → `findByTwitchUserId` + `createFromTwitchProfile` (server-side only).
- `convex/profiles.ts` — `getByPlayer` query, `updateDepth` mutation : conserver, brancher au playerId resolved depuis session.
- `src/hooks/usePlayerProfile.ts` — conserver l'API `(playerId) → Profile | null`. Le `playerId` viendra de `useSession()` au lieu de `useAnonId()`.
- `src/hooks/usePlayerIdentity.ts` — refactor : retire le path anonId, branche sur le hook `useSession` (à créer).
- `src/hooks/useRunLifecycle.ts` / `useDepthSync` — inchangés, ils prennent déjà un `playerId`.
- `src/routes/title.tsx` + `src/routes/title.module.css` — **réutiliser le layout / mood / ASCII art** comme base de `/auth`. Ne pas refaire un écran from scratch.
- `src/components/ui/Button.tsx` — utiliser pour le CTA OAuth. **Variant `danger` (mood "engage with the pit", drip-pool sanglant)** car connecter à Twitch = entrer dans le danger ; cf. `REUSE-INVENTORY.md` §1.1. `juicy={true}`.
- `src/components/ui/{PixelFrame, Pill, Footer, Heraldry, Ribbon}.tsx` — chrome de la page `/auth`.
- `EffectsProvider` / `ChainsProvider` (déjà montés `__root.tsx`) — disponibles dans la page `/auth` aussi (pour ambiance), pas besoin de re-monter.

### À supprimer

- `src/hooks/useAnonId.ts` (obsolète — auth obligatoire override anon).
- Tout call `useAnonId()` dans le code (audit grep avant suppression — `usePlayerIdentity.ts` au minimum, vérifier aussi `useRunLifecycle.ts`).
- Toute logique localStorage UUID liée à l'identité.

### À ajouter

- `convex/auth/twitch.ts` :
  - `startTwitchOAuth()` action — retourne URL d'autorisation Twitch (Helix `/oauth2/authorize`).
  - `completeTwitchOAuth(code, state)` action — exchange code, fetch user (`/helix/users`), find-or-create `players` row, crée `sessions` row, set session cookie.
  - `getSession()` query — retourne session valide ou null (driven par cookie côté serveur).
  - `logout()` mutation — invalide session.
  - Refresh token rotation server-side (cron Convex hourly).
- `convex/middleware/requireAuth.ts` — wrapper toutes les mutations/queries protégées (resolve `playerId` depuis session cookie).
- `src/routes/auth.tsx` (nouveau) — page login dédiée. **Utiliser `<PixelFrame>` + `<Button variant="danger" juicy>` + layout calqué sur `title.tsx`.**
- `src/components/auth/TwitchLoginButton.tsx` — wrapper `<Button variant="danger" juicy>` + icône Twitch + label `Connect with Twitch`. **Pas un nouveau composant bouton from scratch.**
- `src/hooks/useSession.ts` — hook qui expose `{ playerId, twitchDisplayName, twitchAvatarUrl, isAuthenticated, logout() }`.
- `src/components/auth/AuthGuard.tsx` — composant wrapper qui redirect `/auth` si pas de session. Monté dans `__root.tsx` autour des routes protégées.

### Pre-conditions à respecter

- Toutes les routes hors `/auth` sont guardées par `AuthGuard`.
- Toutes les mutations Convex critiques utilisent `requireAuth` middleware → resolve `playerId` depuis session cookie, jamais depuis client params.
- `twitchUserId` côté serveur uniquement, jamais exposé au client (le client n'a besoin que de `playerId` Convex + display info).

## Data model

Schema Convex modif (`convex/schema.ts`) :

```ts
players: {
  twitchUserId: string  // REQUIRED — primary external identity
  twitchDisplayName: string
  twitchAvatarUrl?: string
  createdAt: number
  lastSeenAt: number
}

sessions: {
  playerId: id<'players'>
  sessionTokenHash: string  // SHA256 of cookie value
  twitchAccessTokenEnc: string  // encrypted at rest
  twitchRefreshTokenEnc: string
  expiresAt: number
  createdAt: number
}

profiles: {
  playerId: id<'players'>
  // Depth
  currentDepth: number  // 0 = surface
  deepestDepth: number
  seed: string  // map gen seed
  // Resources
  totalScrap: number
  totalShards: number
  torchCurrent: number  // 0..torchMax
  torchMax: number  // V1 = 5
  // Inventory
  cardsInventory: Card[]  // cf. PRD-07 schema
  cardsEquipped: { mainhand?: CardId; body?: CardId; head?: CardId; charm?: CardId }
  // Progression
  passivesOwned: PassiveId[]
  // Telemetry
  totalPlayTimeMs: number
  updatedAt: number
}
```

`Card` et `PassiveId` détaillés dans PRD-07 et PRD-12.

## Acceptance criteria

- [ ] Visite `/` sans session → redirect `/auth` en <300ms.
- [ ] OAuth Twitch flow complet : <8s avec viewer déjà loggé sur twitch.tv (1 prompt consent only).
- [ ] Premier login : profile créé en <500ms après callback, redirect `/pit`.
- [ ] Refresh F5 : session conservée via cookie, pas de re-login requis.
- [ ] Logout : invalide session, redirect `/auth`, profil données préservées Convex.
- [ ] 2 devices avec même Twitch : voient le même profil (Convex live query).
- [ ] Token expiré : refresh silencieux server-side. Si fail définitif → logout + redirect `/auth` propre.
- [ ] Mutations critiques utilisent `playerId` resolved server-side via session cookie, jamais via params client.
- [ ] `twitchUserId` jamais exposé au client.
- [ ] Twitch service down : message d'erreur sur `/auth`, pas de crash app.

## Dependencies

Aucun. PRD foundation. **Bloquant pour tous les autres PRDs** (auth requise pour tout).

## Open questions

- **Q1.1** Twitch scopes V1 : `openid` minimum suffit-il ? **Reco : `openid` only V1**, no email needed (cf. R5 — minimiser friction consent screen). Email V1.5 si feature qui le requiert.
- **Q1.2** Q18 prestige V1.5 ou V2 ? Si V1.5, schema profile doit prévoir `prestigeLevel: number` dès V1 (zéro coût). **Reco : ajouter le champ V1, valeur 0**.
- **Q1.3** Rate limit Twitch logins par IP (anti-abuse leaderboard farm via multi-account R10) ? **Reco V1 : non**, mais schema sessions prévoit IP tracking pour V1.5.
- **Q1.4** Sessions multi-device illimitées ou cap (ex max 5 sessions actives par player) ? **Reco V1 : illimité**, monitor abuse.
- **Q1.5** Auth flow sur mobile-readable (cf. PRD-12) : Twitch OAuth fonctionne ? **Reco** : oui, OAuth standard fonctionne mobile. Test à valider.
- **Q1.6** Cookie domain : single domain V1 (the-pit.app) ou support sub-domains (api.the-pit.app, etc.) ? **Reco V1 : single domain**.

## Impact retention (R5 onboarding)

**Trade-off acté** : auth obligatoire ajoute friction (~5-15s OAuth + consent screen) → risque +5-10% bounce rate D1 vs anonymous flow.

**Mitigation** :
- Page `/auth` ultra-épurée (pas de pitch long, juste "Connect with Twitch" CTA + 1 ligne de teasing)
- Si viewer déjà sur Twitch, OAuth express (pas de prompt si déjà consent passé)
- Onboarding (PRD-09) reste "zéro tutoriel modal" post-login pour minimiser friction supplémentaire
