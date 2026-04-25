import { mutation, query } from './_generated/server'
import { v } from 'convex/values'

/**
 * Profile read + write. The hub queries `getByPlayer` for headline
 * stats; the pit scene calls `updateDepth` (throttled client-side) to
 * record progress.
 *
 * `updateDepth` is monotone: it only ever raises `currentDepth` /
 * `deepestDepth`. A future `retreat` mutation will explicitly walk
 * `currentDepth` back; depth-sync alone never can.
 */
export const getByPlayer = query({
  args: { playerId: v.id('players') },
  handler: async (ctx, { playerId }) => {
    return await ctx.db
      .query('profiles')
      .withIndex('by_player', (q) => q.eq('playerId', playerId))
      .unique()
  },
})

export const updateDepth = mutation({
  args: { playerId: v.id('players'), depth: v.number() },
  handler: async (ctx, { playerId, depth }) => {
    const profile = await ctx.db
      .query('profiles')
      .withIndex('by_player', (q) => q.eq('playerId', playerId))
      .unique()
    if (!profile) return
    if (depth <= profile.currentDepth && depth <= profile.deepestDepth) return
    await ctx.db.patch(profile._id, {
      currentDepth: Math.max(profile.currentDepth, depth),
      deepestDepth: Math.max(profile.deepestDepth, depth),
      updatedAt: Date.now(),
    })
  },
})
