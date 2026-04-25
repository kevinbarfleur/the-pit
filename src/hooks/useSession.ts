import { useCallback, useEffect, useState } from 'react'
import { useMutation, useQuery } from 'convex/react'
import { api } from '../../convex/_generated/api'
import type { Id } from '../../convex/_generated/dataModel'

export const SESSION_STORAGE_KEY = 'thepit:session'

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
 * The raw session token lives in localStorage (set by `/auth/complete`).
 * On mount we read it and pipe it through `auth.sessions.getSession` —
 * Convex returns the matching player or null (expired/unknown).
 *
 * `status === 'loading'` while the query is in flight; callers should
 * render a neutral skeleton (the AuthGuard does this for the whole app).
 *
 * Trade-off (V1): localStorage instead of HttpOnly cookie. Convex queries
 * travel over WebSocket and don't auto-attach cookies — going cookie-only
 * means a separate auth-aware proxy. localStorage is XSS-vulnerable but
 * acceptable for closed alpha. Tighten in V1.5.
 */
export function useSession(): SessionState {
  const [token, setToken] = useState<string | null>(() => readToken())

  // Re-read storage on cross-tab updates (logout in another tab → here).
  useEffect(() => {
    function onStorage(e: StorageEvent) {
      if (e.key === SESSION_STORAGE_KEY) setToken(readToken())
    }
    window.addEventListener('storage', onStorage)
    return () => window.removeEventListener('storage', onStorage)
  }, [])

  const sessionQuery = useQuery(
    api.auth.sessions.getSession,
    token ? { sessionToken: token } : 'skip',
  )
  const logoutMutation = useMutation(api.auth.sessions.logout)

  const logout = useCallback(async () => {
    const current = readToken()
    if (current) {
      try {
        await logoutMutation({ sessionToken: current })
      } catch (err) {
        console.error('[useSession] logout mutation failed', err)
      }
    }
    try {
      window.localStorage.removeItem(SESSION_STORAGE_KEY)
    } catch (err) {
      console.error('[useSession] localStorage removeItem failed', err)
    }
    setToken(null)
  }, [logoutMutation])

  if (!token) {
    return { status: 'unauthenticated', session: null, logout }
  }
  if (sessionQuery === undefined) {
    return { status: 'loading', session: null, logout }
  }
  if (sessionQuery === null) {
    // Token rejected server-side (expired/revoked). Drop it locally.
    try {
      window.localStorage.removeItem(SESSION_STORAGE_KEY)
    } catch {
      /* noop */
    }
    return { status: 'unauthenticated', session: null, logout }
  }
  return { status: 'authenticated', session: sessionQuery, logout }
}

function readToken(): string | null {
  if (typeof window === 'undefined' || !window.localStorage) return null
  return window.localStorage.getItem(SESSION_STORAGE_KEY)
}
