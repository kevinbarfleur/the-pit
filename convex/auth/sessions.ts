import { mutation, query } from '../_generated/server'
import { v } from 'convex/values'

/**
 * Session resolution + logout.
 *
 * Sessions are looked up by SHA-256(token) — the raw token only ever
 * lives in the client's localStorage. The server stores the hash so a
 * DB leak doesn't compromise live sessions.
 */

async function sha256Hex(input: string): Promise<string> {
  const buf = new TextEncoder().encode(input)
  const digest = await crypto.subtle.digest('SHA-256', buf)
  return Array.from(new Uint8Array(digest), (b) =>
    b.toString(16).padStart(2, '0'),
  ).join('')
}

export const getSession = query({
  args: { sessionToken: v.string() },
  handler: async (ctx, { sessionToken }) => {
    const hash = await sha256Hex(sessionToken)
    const session = await ctx.db
      .query('sessions')
      .withIndex('by_token_hash', (q) => q.eq('sessionTokenHash', hash))
      .unique()
    if (!session) return null
    if (session.expiresAt < Date.now()) return null
    const player = await ctx.db.get(session.playerId)
    if (!player) return null
    return {
      playerId: player._id,
      twitchDisplayName: player.twitchDisplayName,
      twitchAvatarUrl: player.twitchAvatarUrl,
    }
  },
})

export const logout = mutation({
  args: { sessionToken: v.string() },
  handler: async (ctx, { sessionToken }) => {
    const hash = await sha256Hex(sessionToken)
    const session = await ctx.db
      .query('sessions')
      .withIndex('by_token_hash', (q) => q.eq('sessionTokenHash', hash))
      .unique()
    if (session) await ctx.db.delete(session._id)
  },
})
