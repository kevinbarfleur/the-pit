import { useEffect, type ReactNode } from 'react'
import { useNavigate, useRouterState } from '@tanstack/react-router'
import { useSession } from '../../hooks/useSession'

/**
 * Redirects to `/auth` whenever there's no live session. The `/auth*`
 * and `/kit/*` routes are exempt (login screen + design kit).
 *
 * While the session is resolving (initial cold load with a token in
 * localStorage), we render `null` so the protected screen doesn't
 * flash unauthenticated chrome.
 */
interface AuthGuardProps {
  children: ReactNode
}

const PUBLIC_PREFIXES = ['/auth', '/kit']

function isPublicPath(pathname: string): boolean {
  return PUBLIC_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  )
}

export function AuthGuard({ children }: AuthGuardProps) {
  const { status } = useSession()
  const navigate = useNavigate()
  const pathname = useRouterState({ select: (s) => s.location.pathname })

  const onPublic = isPublicPath(pathname)

  useEffect(() => {
    if (onPublic) return
    if (status === 'unauthenticated') {
      void navigate({ to: '/auth', replace: true })
    }
  }, [status, onPublic, navigate])

  if (onPublic) return <>{children}</>
  if (status === 'loading') return null
  if (status === 'unauthenticated') return null
  return <>{children}</>
}
