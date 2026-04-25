import { createFileRoute, redirect } from '@tanstack/react-router'

/**
 * Root path. Authenticated users land directly in the pit; the
 * AuthGuard intercepts unauthenticated visitors before this route's
 * `beforeLoad` even fires, sending them to `/auth`. So in practice
 * `/` is never visible — pure handoff.
 */
export const Route = createFileRoute('/')({
  beforeLoad: () => {
    throw redirect({ to: '/pit', replace: true })
  },
})
