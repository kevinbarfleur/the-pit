import { cronJobs } from 'convex/server'
import { internal } from './_generated/api'

/**
 * Scheduled jobs.
 *
 * Daily cleanup keeps the auth tables bounded: OAuth nonces never decay
 * on their own (they only get consumed when the round-trip completes),
 * and expired sessions hang around with stale Twitch tokens until we
 * drop them.
 */
const crons = cronJobs()

crons.daily(
  'auth: prune expired oauth states',
  { hourUTC: 4, minuteUTC: 0 },
  internal.auth.cleanup.deleteExpiredOauthStates,
)

crons.daily(
  'auth: prune expired sessions',
  { hourUTC: 4, minuteUTC: 5 },
  internal.auth.cleanup.deleteExpiredSessions,
)

export default crons
