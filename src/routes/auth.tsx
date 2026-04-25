import { useRef } from 'react'
import { createFileRoute } from '@tanstack/react-router'
import { useAttachedEffect } from '../hooks/useAttachedEffect'
import { TwitchLoginButton } from '../components/auth/TwitchLoginButton'
import styles from './title.module.css'
import authStyles from './auth.module.css'

/**
 * Twitch OAuth landing page. Mandatory gateway before any gameplay
 * route (cf. specs/prds/01-identity-persistence.md).
 *
 * Layout / mood reuses `title.module.css` to stay coherent with the
 * existing splash treatment — same wordmark, same drip effect on the
 * glyphs. `?error=...` query param is rendered as a discreet line
 * above the CTA when present (e.g. cancelled OAuth, invalid state).
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
}

export const Route = createFileRoute('/auth')({
  component: AuthPage,
  validateSearch: (search: Record<string, unknown>): AuthSearch => ({
    error: typeof search.error === 'string' ? search.error : undefined,
  }),
})

function AuthPage() {
  const { error } = Route.useSearch()
  const wordmarkRef = useRef<HTMLPreElement | null>(null)
  useAttachedEffect(wordmarkRef, 'drips')

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
