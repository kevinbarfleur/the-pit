import { useEffect } from 'react'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { SESSION_STORAGE_KEY } from '../hooks/useSession'

/**
 * OAuth handoff page. The Convex HTTP callback redirects here with
 * `?token=<sessionToken>`. We persist it to localStorage and bounce to
 * `/pit` immediately. This route is only ever a stopover; users never
 * see it for more than a frame.
 */

interface AuthCompleteSearch {
  token?: string
  error?: string
}

export const Route = createFileRoute('/auth/complete')({
  component: AuthCompletePage,
  validateSearch: (search: Record<string, unknown>): AuthCompleteSearch => ({
    token: typeof search.token === 'string' ? search.token : undefined,
    error: typeof search.error === 'string' ? search.error : undefined,
  }),
})

function AuthCompletePage() {
  const { token, error } = Route.useSearch()
  const navigate = useNavigate()

  useEffect(() => {
    if (error || !token) {
      void navigate({
        to: '/auth',
        search: { error: error ?? 'missing-token' },
        replace: true,
      })
      return
    }
    try {
      window.localStorage.setItem(SESSION_STORAGE_KEY, token)
    } catch (err) {
      console.error('[auth.complete] failed to persist session', err)
    }
    void navigate({ to: '/pit', replace: true })
  }, [token, error, navigate])

  return null
}
