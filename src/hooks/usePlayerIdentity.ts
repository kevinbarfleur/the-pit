import type { Id } from '../../convex/_generated/dataModel'
import { useSession } from './useSession'

interface PlayerIdentity {
  playerId: Id<'players'> | null
  displayName: string | null
}

/**
 * Resolves the player identity (Convex `playerId` + display name) for the
 * current session. Twitch OAuth is mandatory (cf. PRD-01) — there is no
 * anonymous path. Returns nulls while the session is still loading or
 * when the user is signed out; the AuthGuard makes the latter impossible
 * for any route past `/auth`.
 */
export function usePlayerIdentity(): PlayerIdentity {
  const { session } = useSession()
  if (!session) return { playerId: null, displayName: null }
  return {
    playerId: session.playerId,
    displayName: session.twitchDisplayName,
  }
}
