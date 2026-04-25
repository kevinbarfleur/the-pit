import { useState } from 'react'

const STORAGE_KEY = 'thepit:anonId'

/**
 * Anonymous device identity. Generates a UUID once and persists it in
 * localStorage so subsequent visits resolve to the same Convex `players`
 * row. Twitch auth (when it lands) will piggyback on this id during the
 * first authenticated session.
 *
 * SSR-safe: falls back to a transient UUID when `window` is missing —
 * the hub's queries simply won't hydrate until the browser remounts.
 */
export function useAnonId(): string {
  const [id] = useState<string>(() => {
    if (typeof window === 'undefined' || !window.localStorage) {
      return crypto.randomUUID()
    }
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored) return stored
    const fresh = crypto.randomUUID()
    window.localStorage.setItem(STORAGE_KEY, fresh)
    return fresh
  })
  return id
}
