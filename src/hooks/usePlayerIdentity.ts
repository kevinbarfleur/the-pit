import { useEffect, useState } from 'react'
import { useMutation } from 'convex/react'
import { api } from '../../convex/_generated/api'
import type { Id } from '../../convex/_generated/dataModel'
import { useAnonId } from './useAnonId'

interface PlayerIdentity {
  playerId: Id<'players'> | null
  displayName: string | null
}

/**
 * Resolves the player identity (Convex `playerId` + display name) for the
 * current device. On mount, fires `getOrCreateByAnonId` once and caches
 * the result. While the round-trip is in flight, returns nulls — callers
 * should render a "loading…" state.
 *
 * The mutation is idempotent (it just bumps `lastSeenAt` for existing
 * rows), so accidental double-fires from React strict-mode are harmless.
 */
export function usePlayerIdentity(): PlayerIdentity {
  const anonId = useAnonId()
  const getOrCreate = useMutation(api.players.getOrCreateByAnonId)
  const [identity, setIdentity] = useState<PlayerIdentity>({
    playerId: null,
    displayName: null,
  })

  useEffect(() => {
    let cancelled = false
    getOrCreate({ anonId })
      .then((result) => {
        if (cancelled) return
        setIdentity({
          playerId: result.playerId,
          displayName: result.displayName,
        })
      })
      .catch((err) => {
        console.error('[usePlayerIdentity] getOrCreateByAnonId failed', err)
      })
    return () => {
      cancelled = true
    }
  }, [anonId, getOrCreate])

  return identity
}
