import type { Id } from '../_generated/dataModel'
import type { QueryCtx, MutationCtx } from '../_generated/server'
import { sha256Hex } from './_helpers'

/**
 * Server-side guard for queries / mutations that need an authenticated
 * player. Resolves the session from a `sessionToken` arg (passed by the
 * client from `useSessionStore`), validates expiry, and returns the
 * `playerId`.
 *
 * Throws `'unauthenticated'` for missing / unknown / expired tokens —
 * the client surface (Convex Errors API) propagates this to the caller
 * which should drop the local token and redirect to `/auth`.
 *
 * Usage from a mutation (PRD-04 combat will need this):
 *
 *   export const validateCombat = mutation({
 *     args: { sessionToken: v.string(), seed: v.string(), hash: v.string() },
 *     handler: async (ctx, { sessionToken, seed, hash }) => {
 *       const playerId = await requireAuth(ctx, sessionToken)
 *       // ... ctx.db actions scoped to playerId
 *     },
 *   })
 *
 * Not wired into any existing query/mutation yet (PRD-01 surfaces are
 * intentionally permissive: `getSession` is itself the auth check, and
 * `players.findOrCreateFromTwitch` is `internalMutation`-only). Lives
 * here ready for PRD-04+.
 */
export async function requireAuth(
  ctx: QueryCtx | MutationCtx,
  sessionToken: string,
): Promise<Id<'players'>> {
  if (!sessionToken) throw new Error('unauthenticated')
  const hash = await sha256Hex(sessionToken)
  const session = await ctx.db
    .query('sessions')
    .withIndex('by_token_hash', (q) => q.eq('sessionTokenHash', hash))
    .unique()
  if (!session) throw new Error('unauthenticated')
  if (session.expiresAt < Date.now()) throw new Error('unauthenticated')
  return session.playerId
}
