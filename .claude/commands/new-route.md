---
description: Scaffold a new TanStack Router file-based route
argument-hint: <path>
---

Create a new TanStack Router route at `src/routes/$ARGUMENTS.tsx`.

Rules:
- Use `createFileRoute('$ARGUMENTS')` — the router plugin will validate the path matches the file location.
- Export `Route` (named export, not default).
- Component wrapper follows the naming `<PascalCase>Page` (e.g. `CampPage`, `DelvePage`).
- Keep the route file thin: fetch/load logic in `loader`, UI in components.
- If the route needs data from Convex, wire it via the loader + `useLoaderData`, not `useQuery` inside the component (keeps the boundary clean).
- Apply the terminal aesthetic (monospace, `bg-pit-ink`, `text-pit-bone`) by default.

After creating the file, run `npm run routes:gen` to regenerate `src/routeTree.gen.ts`.

Report back: the file path, what Convex dependencies it needs (if any), and suggested next steps (components to build, data to load).
