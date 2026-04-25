import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

/**
 * Single source of truth for the client-held session token.
 *
 * Backed by localStorage via Zustand's `persist` middleware so the token
 * survives reloads and propagates across components without a custom
 * event bus. Cross-tab sync is delegated to `persist`'s default behavior:
 * Zustand listens to the `storage` event and refreshes when another tab
 * updates the key.
 *
 * Why a store instead of `useState` + localStorage:
 *  - Multiple `useSession` instances would otherwise drift, since
 *    in-tab writes don't fire the native `storage` event.
 *  - One reactive bus instead of an ad-hoc `'thepit:session-changed'`
 *    custom event.
 *  - Easy to extend (e.g. last-seen timestamp, optimistic display info).
 *
 * Trade-off: still localStorage, still XSS-vulnerable. V1.5 = HttpOnly
 * cookie + auth-aware fetch wrapper. Documented in `useSession.ts`.
 */

interface SessionState {
  token: string | null
  setToken: (token: string) => void
  clearToken: () => void
}

export const useSessionStore = create<SessionState>()(
  persist(
    (set) => ({
      token: null,
      setToken: (token) => set({ token }),
      clearToken: () => set({ token: null }),
    }),
    {
      // Zustand wraps the value in `{ state: { token }, version }`, so
      // we use a distinct key from the legacy raw-string `thepit:session`
      // to avoid JSON parse errors on first load post-migration.
      name: 'thepit:session-store',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({ token: state.token }),
    },
  ),
)
