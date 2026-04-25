# WORKFLOW — branches & process

> Solo dev avec roadmap sprintée (16 sem / 4 sprints). Le but : `dev` et `main` ne cassent jamais. Toute expérimentation vit dans une branche isolée mergée seulement quand stable.

## Branches

| Branche | Rôle | Push direct ? |
|---|---|---|
| `main` | Production / releases stables. Tag `vX.Y` à chaque alpha/beta publique. | ❌ jamais |
| `dev` | Intégration. Reçoit les sprint branches mergées. État courant = "alpha shippable un jour". | ❌ uniquement via merge depuis `sprint/*` |
| `sprint/sprint-N-<theme>` | Branche longue durée (~4 sem). Forkée depuis `dev` au début du sprint. | ❌ uniquement via merge depuis `prd/*` |
| `prd/sprint-N/XX-<slug>` | Branche courte (heures à quelques jours) par PRD. Forkée depuis la sprint branch. | ✅ commits libres |
| `fix/<slug>` | Hotfix urgent sur `dev` ou `main`. Merge rapide. | ✅ |

**Naming** :
- Sprint : `sprint/sprint-1-foundations`, `sprint/sprint-2-core-loop`, etc.
- PRD : `prd/sprint-1/01-twitch-auth`, `prd/sprint-1/02-app-shell`, `prd/sprint-1/03-hero-equipment`, `prd/sprint-1/04-combat-engine`, `prd/sprint-1/05-map-descent`.

## Cycle d'un sprint

```
                        merge          merge          merge
sprint-1-foundations ──▶  dev  ───────▶ ...  ───────▶ main
       ▲                                  
       │ merge                            
   prd/sprint-1/01-twitch-auth            
   prd/sprint-1/02-app-shell              
   prd/sprint-1/03-hero-equipment         
   prd/sprint-1/04-combat-engine          
   prd/sprint-1/05-map-descent            
```

### Démarrer un sprint

```bash
git checkout dev
git pull --ff-only
git checkout -b sprint/sprint-1-foundations
git push -u origin sprint/sprint-1-foundations
```

### Démarrer un PRD

```bash
git checkout sprint/sprint-1-foundations
git pull --ff-only
git checkout -b prd/sprint-1/01-twitch-auth
# ... implémenter
```

### Finir un PRD

1. Tous les acceptance criteria du PRD sont OK.
2. `bun test` (Vitest) passe.
3. `bun run build` ou `tsc --noEmit` passe (zéro erreur TS).
4. Self-review du diff.
5. Merge dans la sprint branch :
   ```bash
   git checkout sprint/sprint-1-foundations
   git merge --no-ff prd/sprint-1/01-twitch-auth -m "merge: PRD-01 Identity & Persistence"
   git push
   git branch -d prd/sprint-1/01-twitch-auth   # local
   git push origin --delete prd/sprint-1/01-twitch-auth   # remote (optionnel, garde l'histoire si tu veux)
   ```

### Finir un sprint

1. Tous les PRDs du sprint sont mergés dans la sprint branch.
2. Smoke test manuel de l'alpha (browser, scenarios golden path).
3. Merge dans `dev` :
   ```bash
   git checkout dev
   git pull --ff-only
   git merge --no-ff sprint/sprint-1-foundations -m "merge: Sprint 1 Foundations"
   git tag -a v0.1-sprint-1 -m "Sprint 1 foundations: identity, shell, hero, combat, map"
   git push origin dev --tags
   ```

### Release alpha publique

Quand `dev` est prêt à être montré au public :

```bash
git checkout main
git pull --ff-only
git merge --no-ff dev -m "release: alpha v0.X"
git tag -a v0.X -m "Public alpha v0.X"
git push origin main --tags
```

## Conventions

### Commits

Format `type(scope): description courte` en minuscules, sans emoji.

Types : `feat`, `fix`, `refactor`, `style`, `docs`, `test`, `chore`, `perf`, `tweak`, `merge`, `release`.

Scope par défaut : `pit`. Sinon : `auth`, `combat`, `cards`, `ui`, etc.

Exemples (style courant du repo) :
- `feat(pit): event-spring islands — pond + cascading water streams`
- `fix(pit): smaller pond, irregular outline + physical splash particles`
- `refactor(pit): Slay-style chunked path generation with anti-crossing rule`
- `docs(prds): add REUSE-INVENTORY`

### PR / merge messages

Quand on merge sprint → dev, message : `merge: Sprint N <theme>`.
Quand on merge prd → sprint, message : `merge: PRD-XX <title>`.

### Tags

- `vX.Y-sprint-N` à la fin de chaque sprint sur `dev`.
- `vX.Y` sur `main` à chaque release publique.

## Garde-fous

- ❌ Pas de commit direct sur `main` ni `dev`.
- ❌ Pas de `git push --force` sur `main` / `dev` / `sprint/*`. Force-push autorisé uniquement sur `prd/*` solo.
- ❌ Pas de merge sans `--no-ff` sur `dev` / `main` (préserver l'historique du sprint).
- ✅ Toujours `git pull --ff-only` avant de merger pour éviter les surprises.
- ✅ Avant de merger une sprint dans dev : smoke test manuel.

## Hotfix

Si bug critique sur `main` / `dev` :

```bash
git checkout main
git checkout -b fix/<slug>
# ... fix
git checkout main && git merge --no-ff fix/<slug>
git checkout dev && git merge --no-ff fix/<slug>
# si le sprint courant est concerné :
git checkout sprint/sprint-N-* && git merge --no-ff fix/<slug>
```

## Références

- PRDs source de vérité : `specs/prds/00-overview.md` + `REUSE-INVENTORY.md`.
- Sprint roadmap V1 : `brainstorming/game-loop/09-consolidation-after-review.md` §"Sprint roadmap V1".
- Game loop canonical : `brainstorming/game-loop/09-consolidation-after-review.md`.
