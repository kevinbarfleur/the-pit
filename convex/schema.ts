import { defineSchema, defineTable } from 'convex/server'
import { v } from 'convex/values'

/**
 * V3 schema — Twitch OAuth obligatoire.
 *
 * The Pit has no "runs". A player picks up wherever they left off and
 * keeps going deeper, forever. The profile is the only persistent
 * state: where the player currently stands, the deepest point they've
 * reached, and the resources they've accumulated along the way.
 *
 *  - `players`     : one row per Twitch identity. Created on first OAuth login.
 *  - `profiles`    : single source of truth for the descent. 1:1 with players.
 *  - `sessions`    : opaque session tokens (hash only). Issued at OAuth completion.
 *  - `oauthStates` : ephemeral CSRF nonces for the OAuth round-trip.
 */
export default defineSchema({
  players: defineTable({
    twitchUserId: v.string(),
    twitchDisplayName: v.string(),
    twitchAvatarUrl: v.optional(v.string()),
    createdAt: v.number(),
    lastSeenAt: v.number(),
  }).index('by_twitch', ['twitchUserId']),

  profiles: defineTable({
    playerId: v.id('players'),
    currentDepth: v.number(),
    deepestDepth: v.number(),
    seed: v.string(),
    totalGold: v.number(),
    totalScrap: v.number(),
    totalShards: v.number(),
    /** Cap of torch slots. Tunable via passives later. V1 = 5. */
    torchCapacity: v.number(),
    /** Live torch count [0, torchCapacity]. Decremented on retreat
     *  (PRD-05) and on boss death (PRD-08). Refilled at rest nodes
     *  + offline regen. V1 spawns at full.
     *
     *  Optional in the schema so legacy profile rows (created before
     *  PRD-02 added the field) deploy without manual data wipe. The
     *  client coerces `undefined → torchCapacity` at read time. */
    torchCurrent: v.optional(v.number()),
    /** Boss kill counter. Used by App Shell to gate the Leaderboard
     *  tab (PRD-02 progressive disclosure). PRD-08 increments.
     *  Optional for the same legacy-row reason as `torchCurrent`. */
    bossesKilled: v.optional(v.number()),
    updatedAt: v.number(),
  }).index('by_player', ['playerId']),

  sessions: defineTable({
    playerId: v.id('players'),
    sessionTokenHash: v.string(),
    twitchAccessToken: v.string(),
    twitchRefreshToken: v.string(),
    twitchTokenExpiresAt: v.number(),
    expiresAt: v.number(),
    createdAt: v.number(),
  })
    .index('by_token_hash', ['sessionTokenHash'])
    .index('by_player', ['playerId']),

  oauthStates: defineTable({
    state: v.string(),
    expiresAt: v.number(),
  }).index('by_state', ['state']),
})
