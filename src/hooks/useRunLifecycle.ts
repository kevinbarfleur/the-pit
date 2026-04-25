import { useCallback, useEffect, useRef } from 'react'
import { useMutation } from 'convex/react'
import { api } from '../../convex/_generated/api'
import type { Id } from '../../convex/_generated/dataModel'

/**
 * Pushes the player's local current depth back to Convex.
 *
 * The pit is a perpetual descent — there is no run to start or end.
 * This hook just observes `currentDepth` and persists it on the profile
 * at most once per `THROTTLE_MS`, with a trailing-edge fire so the
 * latest depth lands even if the player stops moving.
 *
 * The mutation is monotone server-side, so re-sends with stale values
 * are safely ignored.
 */

const THROTTLE_MS = 1000

export function useDepthSync(
  playerId: Id<'players'> | null,
  currentDepth: number,
): void {
  const updateDepth = useMutation(api.profiles.updateDepth)
  const lastSentRef = useRef<number>(-1)
  const lastSendAtRef = useRef<number>(0)
  const trailingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const send = useCallback(
    (depth: number) => {
      if (!playerId) return
      if (depth <= lastSentRef.current) return
      lastSentRef.current = depth
      lastSendAtRef.current = Date.now()
      void updateDepth({ playerId, depth }).catch((err) => {
        console.error('[useDepthSync] updateDepth failed', err)
      })
    },
    [playerId, updateDepth],
  )

  useEffect(() => {
    if (!playerId) return
    if (currentDepth <= lastSentRef.current) return

    const sinceLast = Date.now() - lastSendAtRef.current
    if (sinceLast >= THROTTLE_MS) {
      send(currentDepth)
      return
    }

    if (trailingTimerRef.current) clearTimeout(trailingTimerRef.current)
    const wait = THROTTLE_MS - sinceLast
    trailingTimerRef.current = setTimeout(() => {
      trailingTimerRef.current = null
      send(currentDepth)
    }, wait)

    return () => {
      if (trailingTimerRef.current) {
        clearTimeout(trailingTimerRef.current)
        trailingTimerRef.current = null
      }
    }
  }, [playerId, currentDepth, send])
}
