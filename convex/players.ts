import { internalMutation, query } from './_generated/server'
import { v } from 'convex/values'

/**
 * Player rows are created server-side only, by the OAuth callback in
 * `convex/auth/twitch.ts`. The client never inserts.
 *
 * `findOrCreateFromTwitch` is idempotent: subsequent OAuth completions for
 * the same `twitchUserId` just refresh the cached display name + avatar +
 * `lastSeenAt`. The first completion also seeds the `profiles` row at
 * depth 0 with a stable map seed (same descent across sessions).
 */
export const findOrCreateFromTwitch = internalMutation({
  args: {
    twitchUserId: v.string(),
    twitchDisplayName: v.string(),
    twitchAvatarUrl: v.optional(v.string()),
  },
  handler: async (ctx, { twitchUserId, twitchDisplayName, twitchAvatarUrl }) => {
    const now = Date.now()
    const existing = await ctx.db
      .query('players')
      .withIndex('by_twitch', (q) => q.eq('twitchUserId', twitchUserId))
      .unique()

    if (existing) {
      await ctx.db.patch(existing._id, {
        twitchDisplayName,
        twitchAvatarUrl,
        lastSeenAt: now,
      })
      return existing._id
    }

    const playerId = await ctx.db.insert('players', {
      twitchUserId,
      twitchDisplayName,
      twitchAvatarUrl,
      createdAt: now,
      lastSeenAt: now,
    })

    // Seed for the procedural map. Stable across sessions so the same
    // descent reveals the same shape every time.
    const seed = twitchUserId.padStart(12, '0').slice(0, 12)

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

    return playerId
  },
})

/**
 * Public read of the player's display info, by id. Used by the topbar
 * after the session resolves to a player.
 */
export const getPublicById = query({
  args: { playerId: v.id('players') },
  handler: async (ctx, { playerId }) => {
    const player = await ctx.db.get(playerId)
    if (!player) return null
    return {
      playerId: player._id,
      twitchDisplayName: player.twitchDisplayName,
      twitchAvatarUrl: player.twitchAvatarUrl,
    }
  },
})
