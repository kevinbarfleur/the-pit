# PRD-02 — App Shell & Routes

## Goal

Restructurer les routes pour que `/` charge **directement le pit** (pas d'écran hub intermédiaire) **après auth Twitch** (cf. PRD-01). Topbar + Menubar = chrome persistant partagé entre tous les onglets. Progressive disclosure des onglets selon état joueur (via boss kills).

## Non-goals

- Conserver le hub écran existant (`src/features/hub/`) — supprimé
- Mobile responsive complet (V1 = desktop, mobile-readable seulement, cf. PRD-12)
- Route `/title` ou splash animé — supprimé sauf si nécessaire au branding (à trancher Q2.1)
- Onglets `/passives` et `/codex` fonctionnels V1 — stubs UI uniquement (vraie implémentation V1.5)
- Navigation profonde dans les onglets (sub-routes) — V1 = un seul niveau

## User stories

- En tant que **visiteur**, je land sur `/` et je vois le pit immédiatement, sans écran intermédiaire.
- En tant que **joueur**, je clique `[P] Passives` dans la menubar et je vois l'écran passifs sans rechargement complet (chrome persistant).
- En tant que **joueur**, je vois mes ressources (scrap/shards/torch + depth) en permanence dans la Topbar, peu importe l'onglet actif.
- En tant que **nouveau joueur**, l'onglet `[L] Leaderboard` apparaît seulement après mon premier boss D10 (progressive disclosure, R5 onboarding).

## Functional spec

### Routes

| Path | Auth | Tab key | Content | État V1 |
|---|---|---|---|---|
| `/auth` | public | — | Twitch OAuth login screen (cf. PRD-01) | full V1 |
| `/` | required | redirige `/pit` si sessionnée, sinon `/auth` | — | redirect |
| `/pit` | required | D | Map + node engagement + combat | full V1 |
| `/passives` | required | P | Camp passives (4 trees stub V1) | stub V1 |
| `/cards` | required | C | Inventory + equip + fuse/disenchant | full V1 |
| `/codex` | required | X | Bestiaire + lore | stub V1 |
| `/leaderboard` | required | L | Tiered leaderboard | full V1 |

Toutes routes `required` sont guardées par `<AuthGuard>` (PRD-01) — redirect `/auth` si pas de session.

Routes `/kit/*` (design system) **inchangées et publiques**. Route `/title` supprimée si non utilisée. Route `/ilots` (existante, nature inconnue) à auditer pour suppression (si inutilisée).

### Topbar persistante

Affiche en permanence :
- Title : `the pit · {twitchDisplayName}` (lowercased — toujours Twitch puisque auth obligatoire)
- Avatar Twitch en thumbnail à côté du nom (clic = settings panel cf. PRD-12, contient logout)
- Pills :
  - `D{currentDepth}` (ex `D047`)
  - `{totalScrap} ◆`
  - `{totalShards} ✦`
  - `{torchCurrent}/{torchMax} ☩`

Pills clickable **non-interactives V1** (display only). V1.5 = tooltip sur hover.

### Menubar progressive disclosure

V1 visibilité :
- T+0 : `[D] Pit`, `[C] Cards`, `[X] Codex`
- Après 1er node clear : `[P] Passives` apparaît avec animation discrète "unlocked"
- Après 1er boss D10 : `[L] Leaderboard` apparaît avec animation "you're on the board"

Tabs verrouillés affichés en dim avec `(at DN)` suffix dans help docs (PRD-12), pas dans la menubar elle-même.

### Keyboard shortcuts

- `D` / `P` / `C` / `X` / `L` : navigate vers la route correspondante
- Disabled si tab non encore débloqué
- `Escape` : revient à `/pit` depuis n'importe quel onglet

## Technical approach

> **Lire d'abord [`REUSE-INVENTORY.md`](./REUSE-INVENTORY.md) §1, §3, §6, §8.**

### Réuse existant (chemins exacts)

**UI atoms** (utiliser tels quels) :
- `src/components/ui/Topbar.tsx` + `Topbar.module.css` — chrome existant, prop `pills` déjà supportée. Réutiliser sans le réécrire.
- `src/components/ui/Menubar.tsx` + `Menubar.module.css` — `MenubarItem` supporte déjà `dim?: boolean` ; ajouter `hidden?: boolean` si manquant pour la progressive disclosure (édit minimal, pas un nouveau composant).
- `src/components/ui/Pill.tsx` — pour les pills de la Topbar (D047, scrap, shards, torch).
- `src/components/ui/Footer.tsx` — chrome bottom si présent.
- `src/components/ui/Button.tsx` — n'importe quel CTA dans les routes. **Choisir le `variant` selon le mood narratif de l'action** (cf. `REUSE-INVENTORY.md` §1.1) ; pas selon "primary = action principale".
- `src/components/ui/{PixelFrame, Card, Panel, PanelTitle, Divider, Row, Heraldry, Ribbon, Kbd}.tsx` — pour structurer les pages stub (`/passives`, `/codex`).

**Routes & providers** :
- `src/routes/__root.tsx` — point d'entrée TanStack Router. Y monter `<AuthGuard>` (PRD-01) + `EffectsProvider` + `ChainsProvider` (déjà présents probablement, vérifier avant de modifier).
- `src/routes/title.tsx` + `.module.css` — **recyclé pour `/auth`** (cf. PRD-01). Ne pas créer un écran auth from scratch.
- `src/routes/pit.tsx` — déjà monte `PitScene`. Conserver. Wrapper dans `<AppShell active="D">`.
- `src/routes/kit/*` — inchangé, public.

**Features hub** (statut révisé) :
- `src/features/hub/HubPage.tsx` + `HubChains.tsx` + `InfoCluster.tsx` — **NE PAS supprimer**. Les conserver comme :
  1. Composants utilisables sur `/auth` (HubChains pour ambiance ; InfoCluster pour stats joueur après login).
  2. Base potentielle d'un écran « post-login splash » V1.5 si besoin de cérémonie au retour de session.
  Si non utilisés au end of Sprint 1, les laisser dormants (pas de coût).
- `src/features/hub/HubPage.tsx` ne doit **plus être la landing page** par défaut (`/` redirige `/pit` après auth, ou `/auth` sinon).

**Hooks** :
- `src/hooks/usePlayerProfile.ts` — alimente Topbar pills via Convex live query.
- `src/hooks/useSession.ts` (PRD-01, à créer) — alimente Topbar avatar + display name.

### À retirer du flow par défaut (sans supprimer le code)

- `src/routes/index.tsx` — refactor en redirect : si session valide → `/pit`, sinon `/auth`. Ne pas afficher de hub écran intermédiaire.
- `src/routes/ilots.tsx` — auditer (Q2.2). Si inutilisé en runtime, marquer en route debug `/kit/ilots` ou supprimer après validation user.

### À créer

- `src/routes/passives.tsx` : stub V1 (4 trees vides + scrap counter). Réutiliser `<Card>` + `<Tier>` + `<Pill>` + `<Button variant="default" juicy>` (mood embers = ambient, neutre).
- `src/routes/cards.tsx` : full V1 (cf. PRD-07).
- `src/routes/codex.tsx` : stub V1. Réutiliser `<Card>` + Bestiary slice (`src/features/characters/CharacterSprite.tsx`) si pertinent.
- `src/routes/leaderboard.tsx` : full V1 (cf. PRD-11). Réutiliser `<Tier>` pour les bandes (Surface/Shaft/Caverns…).
- `src/components/layout/AppShell.tsx` : wrapper Topbar + Menubar partagé entre routes. **Doit composer Topbar + Menubar existants, pas en réécrire.**
- `src/components/layout/TabUnlockGate.tsx` : helper qui calcule `unlockedTabs` depuis profile.

### Pattern d'usage

Chaque route enveloppe son contenu dans `<AppShell>` :

```tsx
<AppShell active="D">
  <PitScene />
</AppShell>
```

`AppShell` lit `usePlayerProfile`, calcule `unlockedTabs` selon état, passe à Menubar.

## Data model

Aucune modif Convex. Tab unlock est dérivable de profile :
- `[P]` débloqué si `currentDepth >= 1` (au moins 1 node clear)
- `[L]` débloqué si `bossesKilled.length >= 1` (cf. PRD-08 schema)

## Acceptance criteria

- [ ] `/` redirige vers `/pit` sans flash
- [ ] Pills Topbar update en live quand profile change (Convex live query)
- [ ] Tab `[P]` invisible avant 1er node clear, apparaît avec fade-in subtil
- [ ] Tab `[L]` invisible avant 1er boss kill, apparaît animé
- [ ] Hotkey `D/P/C/X/L` navigate sans rechargement de chrome
- [ ] `Escape` ramène à `/pit` depuis tout onglet
- [ ] Aucun rechargement de Topbar/Menubar entre changements de routes (chrome persistant)
- [ ] Pas de régression sur `/kit/*`

## Dependencies

- PRD-01 (profile data pour Topbar pills + tab unlock logic)

## Open questions

- **Q2.1** Garder route `/title` (page pré-launch ?) ou supprimer ? **Reco : supprimer si non liée** depuis ailleurs. Auditer.
- **Q2.2** Route `/ilots` : actuellement existe. À supprimer si inutilisée. Auditer.
- **Q2.3** Animation d'apparition d'un nouveau tab unlock : intensité ? **Reco : fade-in subtil + pulse 1.5s sur l'icône**.
- **Q2.4** `/passives` stub V1 : show 4 trees vides + scrap counter, ou minimal "Coming soon" ? **Reco : 4 trees + counter, "buy" disabled** — donne signal de progression incoming sans fonctionnalité.
