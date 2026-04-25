import { defineSchema, defineTable } from 'convex/server'
import { v } from 'convex/values'

/**
 * V2 schema — perpetual descent.
 *
 * The Pit has no "runs". A player picks up wherever they left off and
 * keeps going deeper, forever. The profile is the only persistent
 * state: where the player currently stands, the deepest point they've
 * reached, and the resources they've accumulated along the way.
 *
 *  - `players`  : one row per device (UUID stored in localStorage).
 *  - `profiles` : single source of truth for the descent. Mutated as
 *    the player progresses (`updateDepth`) and when rewards land
 *    (later, when combat ships).
 */
export default defineSchema({
  players: defineTable({
    anonId: v.string(),
    displayName: v.string(),
    createdAt: v.number(),
    lastSeenAt: v.number(),
  }).index('by_anon', ['anonId']),

  profiles: defineTable({
    playerId: v.id('players'),
    /** The depth the player currently stands at. Resumes here when
     *  they re-enter the pit. */
    currentDepth: v.number(),
    /** Farthest depth ever reached. Equal to `currentDepth` until
     *  retreat mechanics introduce divergence. */
    deepestDepth: v.number(),
    /** Persistent seed for the procedural map — same descent across
     *  sessions means the same nodes. */
    seed: v.string(),
    totalGold: v.number(),
    totalScrap: v.number(),
    totalShards: v.number(),
    torchCapacity: v.number(),
    updatedAt: v.number(),
  }).index('by_player', ['playerId']),
})
