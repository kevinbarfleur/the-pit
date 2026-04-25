import { mutation } from './_generated/server'
import { v } from 'convex/values'

/**
 * Resolve (or bootstrap) the player row + profile for a given anonId.
 *
 * Idempotent: subsequent calls just bump `lastSeenAt`. The first call
 * creates the player + a fresh `profiles` row at depth 0 with a stable
 * seed, so the procedural pit graph is consistent across sessions.
 */
export const getOrCreateByAnonId = mutation({
  args: { anonId: v.string() },
  handler: async (ctx, { anonId }) => {
    const now = Date.now()
    const existing = await ctx.db
      .query('players')
      .withIndex('by_anon', (q) => q.eq('anonId', anonId))
      .unique()

    if (existing) {
      await ctx.db.patch(existing._id, { lastSeenAt: now })
      return { playerId: existing._id, displayName: existing.displayName }
    }

    const suffix = anonId.replace(/-/g, '').slice(0, 4).toUpperCase()
    const displayName = `Descender ${suffix}`

    const playerId = await ctx.db.insert('players', {
      anonId,
      displayName,
      createdAt: now,
      lastSeenAt: now,
    })

    // Seed for the procedural map. Stable across sessions so the same
    // descent reveals the same shape every time.
    const seed = anonId.replace(/-/g, '').slice(0, 12)

    await ctx.db.insert('profiles', {
      playerId,
      currentDepth: 0,
      deepestDepth: 0,
      seed,
      totalGold: 0,
      totalScrap: 0,
      totalShards: 0,
      torchCapacity: 5,
      updatedAt: now,
    })

    return { playerId, displayName }
  },
})
