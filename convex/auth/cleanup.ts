import { internalMutation } from '../_generated/server'

/**
 * Periodic cleanup of expired auth rows.
 *
 * - `oauthStates` are CSRF nonces for the OAuth round-trip; they live
 *   ~10 min and stay forever once the round-trip completes (or the user
 *   abandons it). Without GC they accumulate indefinitely.
 * - `sessions` carry a 30-day TTL. After that the `getSession` query
 *   already rejects them, but we should still drop the rows (and the
 *   stored Twitch tokens) once they're past expiry.
 *
 * Both mutations are bounded per run (1 000 rows) so a backlog won't
 * blow the Convex 4 MB transaction limit. The cron in `convex/crons.ts`
 * re-fires daily and will drain the backlog over multiple days.
 */

const BATCH_LIMIT = 1000

export const deleteExpiredOauthStates = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now()
    const rows = await ctx.db.query('oauthStates').take(BATCH_LIMIT)
    let deleted = 0
    for (const row of rows) {
      if (row.expiresAt < now) {
        await ctx.db.delete(row._id)
        deleted++
      }
    }
    return { scanned: rows.length, deleted }
  },
})

export const deleteExpiredSessions = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now()
    const rows = await ctx.db.query('sessions').take(BATCH_LIMIT)
    let deleted = 0
    for (const row of rows) {
      if (row.expiresAt < now) {
        await ctx.db.delete(row._id)
        deleted++
      }
    }
    return { scanned: rows.length, deleted }
  },
})
