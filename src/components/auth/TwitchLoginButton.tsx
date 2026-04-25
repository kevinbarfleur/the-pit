import { useState } from 'react'
import { useConvex } from 'convex/react'
import { api } from '../../../convex/_generated/api'
import { Button } from '../ui/Button'

/**
 * Connect-with-Twitch CTA.
 *
 * Calls `auth.twitch.getAuthUrl` (which persists a CSRF state and returns
 * the Twitch authorize URL) then navigates the browser there. Twitch
 * redirects back to a Convex HTTP action which finishes the handshake
 * and lands the user on `/auth/complete?token=...`.
 *
 * Visual: `variant="danger"` (drip-pool / blood) — mood narratif
 * "engaging with the pit" (cf. specs/prds/REUSE-INVENTORY.md §1.1),
 * NOT a UX-role choice. Connecting to Twitch = stepping into the descent.
 */
interface TwitchLoginButtonProps {
  className?: string
}

export function TwitchLoginButton({ className }: TwitchLoginButtonProps) {
  const convex = useConvex()
  const [pending, setPending] = useState(false)

  const onClick = async () => {
    if (pending) return
    setPending(true)
    try {
      const { authUrl } = await convex.action(api.auth.twitch.getAuthUrl, {})
      window.location.href = authUrl
    } catch (err) {
      console.error('[TwitchLoginButton] failed to start OAuth', err)
      setPending(false)
    }
  }

  return (
    <Button
      variant="danger"
      size="lg"
      juicy
      onClick={onClick}
      disabled={pending}
      className={className}
    >
      {pending ? 'redirecting…' : 'connect with twitch'}
    </Button>
  )
}
