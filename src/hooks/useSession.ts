import { useCallback } from 'react'
import { useMutation, useQuery } from 'convex/react'
import { api } from '../../convex/_generated/api'
import type { Id } from '../../convex/_generated/dataModel'
import { useSessionStore } from '../stores/sessionStore'

export interface Session {
  playerId: Id<'players'>
  twitchDisplayName: string
  twitchAvatarUrl?: string
}

export interface SessionState {
  status: 'loading' | 'authenticated' | 'unauthenticated'
  session: Session | null
  logout: () => Promise<void>
}

/**
 * Resolves the current Twitch-backed session.
 *
 * The raw session token lives in the Zustand `useSessionStore` (persisted
 * to localStorage). We feed it through `auth.sessions.getSession` —
 * Convex returns the matching player or null (expired / unknown / new
 * deployment that wiped the table).
 *
 * `status === 'loading'` while the query is in flight; callers should
 * render a neutral skeleton (the AuthGuard does this for the whole app).
 *
 * Trade-off (V1): localStorage instead of HttpOnly cookie. Convex
 * queries travel over WebSocket and don't auto-attach cookies — going
 * cookie-only means a separate auth-aware proxy. localStorage is
 * XSS-vulnerable but acceptable for closed alpha. Tighten in V1.5.
 */
export function useSession(): SessionState {
  const token = useSessionStore((s) => s.token)
  const clearToken = useSessionStore((s) => s.clearToken)

  const sessionQuery = useQuery(
    api.auth.sessions.getSession,
    token ? { sessionToken: token } : 'skip',
  )
  const logoutMutation = useMutation(api.auth.sessions.logout)

  const logout = useCallback(async () => {
    const current = useSessionStore.getState().token
    if (current) {
      try {
        await logoutMutation({ sessionToken: current })
      } catch (err) {
        console.error('[useSession] logout mutation failed', err)
      }
    }
    clearToken()
  }, [logoutMutation, clearToken])

  if (!token) {
    return { status: 'unauthenticated', session: null, logout }
  }
  if (sessionQuery === undefined) {
    return { status: 'loading', session: null, logout }
  }
  if (sessionQuery === null) {
    // Token rejected server-side (expired/revoked/unknown). Drop it.
    // Defer the mutation to next tick to avoid setting state during a
    // selector run.
    queueMicrotask(() => clearToken())
    return { status: 'unauthenticated', session: null, logout }
  }
  return { status: 'authenticated', session: sessionQuery, logout }
}
