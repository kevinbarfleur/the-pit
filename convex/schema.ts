import { defineSchema, defineTable } from 'convex/server'
import { v } from 'convex/values'

export default defineSchema({
  players: defineTable({
    twitchId: v.string(),
    displayName: v.string(),
    createdAt: v.number(),
    lastSeenAt: v.number(),
  }).index('by_twitch', ['twitchId']),

  saves: defineTable({
    playerId: v.id('players'),
    depth: v.number(),
    gold: v.number(),
    updatedAt: v.number(),
  }).index('by_player', ['playerId']),
})
