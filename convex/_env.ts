/**
 * Typed wrapper around `process.env` for Convex actions.
 *
 * Convex's runtime exposes Node's `process` object, but the app
 * tsconfig (which transitively pulls in convex source via
 * `_generated/api.d.ts`) does not load node types. Declaring `process`
 * locally lets convex source compile under both project tsconfigs
 * without leaking node typings into the broader src/ namespace.
 */

declare const process: { env: Record<string, string | undefined> }

export function requireEnv(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`missing convex env var: ${name}`)
  return value
}

export function getEnv(name: string): string | undefined {
  return process.env[name]
}
