import { useEffect, useRef } from 'react'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useAttachedEffect } from '../hooks/useAttachedEffect'
import { useSession } from '../hooks/useSession'
import { useSessionStore } from '../stores/sessionStore'
import { TwitchLoginButton } from '../components/auth/TwitchLoginButton'
import styles from './title.module.css'
import authStyles from './auth.module.css'

/**
 * Twitch OAuth landing page. Mandatory gateway before any gameplay
 * route (cf. specs/prds/01-identity-persistence.md).
 *
 * Two responsibilities, same route:
 *  1. **Login screen** — when there's no session and no incoming
 *     handoff, show the wordmark + "Connect with Twitch" CTA.
 *  2. **OAuth handoff** — when Convex's HTTP callback redirects here
 *     with `?token=<sessionToken>`, persist the token to localStorage,
 *     fire `notifySessionChanged()`, and navigate to `/pit`.
 *
 * Layout reuses `title.module.css` for visual coherence with the
 * existing splash treatment (same wordmark, same drip effect).
 * `?error=...` is surfaced as a discreet failure line.
 */

const PIT_ASCII = String.raw`
 ████████╗ ██╗  ██╗ ███████╗    ██████╗  ██╗ ████████╗
 ╚══██╔══╝ ██║  ██║ ██╔════╝    ██╔══██╗ ██║ ╚══██╔══╝
    ██║    ███████║ █████╗      ██████╔╝ ██║    ██║
    ██║    ██╔══██║ ██╔══╝      ██╔═══╝  ██║    ██║
    ██║    ██║  ██║ ███████╗    ██║      ██║    ██║
    ╚═╝    ╚═╝  ╚═╝ ╚══════╝    ╚═╝      ╚═╝    ╚═╝
    ▓▒      ▓▒  ▓▒   ▓▒          ▓▒      ▓▒     ▓▒
    ▓▒      ▒    ▒   ▓▒          ▓▒       ▒     ▓▒
    ▓▒      ▒        ▓▒          ▓▒       ▒     ▓▒
    ▒       ░        ▒                    ░      ▒
    ▒                                             ░
    ░
`

interface AuthSearch {
  error?: string
  token?: string
}

export const Route = createFileRoute('/auth')({
  component: AuthPage,
  validateSearch: (search: Record<string, unknown>): AuthSearch => ({
    error: typeof search.error === 'string' ? search.error : undefined,
    token: typeof search.token === 'string' ? search.token : undefined,
  }),
})

function AuthPage() {
  const { error, token } = Route.useSearch()
  const wordmarkRef = useRef<HTMLPreElement | null>(null)
  useAttachedEffect(wordmarkRef, 'drips')

  const { status } = useSession()
  const setToken = useSessionStore((s) => s.setToken)
  const navigate = useNavigate()

  // Handoff path: Convex callback redirects here with ?token=...
  // Persist + redirect /pit immediately. Runs before the "already
  // authenticated" branch so a fresh login always wins.
  useEffect(() => {
    if (!token) return
    setToken(token)
    void navigate({ to: '/pit', replace: true })
  }, [token, setToken, navigate])

  // Already-authenticated path: skip the login screen entirely.
  // AuthGuard treats /auth as public, so it never auto-routes us — we
  // do it ourselves here.
  useEffect(() => {
    if (token) return
    if (status === 'authenticated') {
      void navigate({ to: '/pit', replace: true })
    }
  }, [token, status, navigate])

  if (token) return null

  return (
    <main className={styles.page}>
      <div className={styles.body}>
        <pre ref={wordmarkRef} className={styles.wordmark}>
          {PIT_ASCII}
        </pre>
        <div className={styles.tagline}>"every descent writes your economy"</div>
        <div className={authStyles.cta}>
          <TwitchLoginButton />
        </div>
        {error ? (
          <div className={authStyles.error}>
            login failed · {humanizeError(error)}
          </div>
        ) : (
          <div className={authStyles.hint}>twitch identity required to descend</div>
        )}
      </div>
    </main>
  )
}

function humanizeError(code: string): string {
  switch (code) {
    case 'access_denied':
      return 'consent declined'
    case 'invalid-state':
      return 'session expired, retry'
    case 'missing-params':
      return 'callback misformatted'
    case 'user-empty':
      return 'twitch returned no user'
    default:
      if (code.startsWith('token-exchange-'))
        return `twitch token exchange ${code.slice('token-exchange-'.length)}`
      if (code.startsWith('user-fetch-'))
        return `twitch user fetch ${code.slice('user-fetch-'.length)}`
      return code
  }
}
