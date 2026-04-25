/**
 * Pure helpers for the auth subsystem. Extracted so they're testable
 * without spinning up a Convex action context, and so the same hash
 * function is used in both `getSession` (lookup) and `persistSession`
 * (insert) — a divergence here would silently invalidate every session.
 */

/** SHA-256 of a UTF-8 string, returned as lowercase hex. */
export async function sha256Hex(input: string): Promise<string> {
  const buf = new TextEncoder().encode(input)
  const digest = await crypto.subtle.digest('SHA-256', buf)
  return Array.from(new Uint8Array(digest), (b) =>
    b.toString(16).padStart(2, '0'),
  ).join('')
}

/** Cryptographically-random hex token (default 32 bytes = 64 hex chars). */
export function randomToken(byteLen = 32): string {
  const bytes = new Uint8Array(byteLen)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
}

/**
 * Stable map seed for a Twitch identity. Hashing instead of slicing the
 * Twitch ID gives uniform entropy and avoids a leading run of zeros for
 * users with small numeric IDs.
 *
 * Returns the first 12 hex chars (~48 bits, plenty for `pure-rand` seed).
 */
export async function makeSeed(twitchUserId: string): Promise<string> {
  const hash = await sha256Hex(`thepit:seed:${twitchUserId}`)
  return hash.slice(0, 12)
}
