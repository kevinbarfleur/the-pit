import { useEffect, useMemo, type ReactNode } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Topbar } from '../ui/Topbar'
import { Menubar, type MenubarItem } from '../ui/Menubar'
import { useSession } from '../../hooks/useSession'
import { usePlayerProfile } from '../../hooks/usePlayerProfile'
import styles from './AppShell.module.css'

/**
 * Persistent chrome around every authenticated route. Mounts the
 * Topbar (live profile pills + Twitch avatar) and the Menubar (tabs
 * with progressive disclosure), and routes single-key shortcuts.
 *
 * Tab visibility (cf. PRD-02 §"Menubar progressive disclosure"):
 *  - T+0           : D Pit, C Cards, X Codex
 *  - currentDepth ≥ 1 : + P Passives
 *  - bossesKilled ≥ 1 : + L Leaderboard
 *
 * Keyboard:
 *  - D / P / C / X / L : navigate to the corresponding route (when
 *    the tab is unlocked).
 *  - Escape            : back to /pit from any tab.
 *  - Ignored when the focused element is an input/textarea so we
 *    don't hijack form input.
 */
export type TabKey = 'D' | 'P' | 'C' | 'X' | 'L'

const TAB_ROUTES: Record<TabKey, '/pit' | '/passives' | '/cards' | '/codex' | '/leaderboard'> = {
  D: '/pit',
  P: '/passives',
  C: '/cards',
  X: '/codex',
  L: '/leaderboard',
}

interface AppShellProps {
  active: TabKey
  children: ReactNode
}

export function AppShell({ active, children }: AppShellProps) {
  const { session } = useSession()
  const profile = usePlayerProfile(session?.playerId ?? null)
  const navigate = useNavigate()

  const items = useMemo<MenubarItem[]>(() => {
    const base: MenubarItem[] = [
      { key: 'D', label: 'pit' },
      { key: 'C', label: 'cards' },
      { key: 'X', label: 'codex' },
    ]
    if (!profile) return base
    if (profile.currentDepth >= 1) base.push({ key: 'P', label: 'passives' })
    if (profile.bossesKilled >= 1) base.push({ key: 'L', label: 'leaderboard' })
    return base
  }, [profile])

  const onSelect = (key: string) => {
    const route = TAB_ROUTES[key as TabKey]
    if (!route) return
    void navigate({ to: route })
  }

  useEffect(() => {
    function isTypingTarget(t: EventTarget | null): boolean {
      return (
        t instanceof HTMLInputElement ||
        t instanceof HTMLTextAreaElement ||
        (t instanceof HTMLElement && t.isContentEditable)
      )
    }
    function onKey(e: KeyboardEvent) {
      if (e.metaKey || e.ctrlKey || e.altKey) return
      if (isTypingTarget(e.target)) return
      if (e.key === 'Escape') {
        if (active !== 'D') void navigate({ to: '/pit' })
        return
      }
      const k = e.key.toUpperCase() as TabKey
      const route = TAB_ROUTES[k]
      if (!route) return
      if (!items.some((it) => it.key === k)) return
      e.preventDefault()
      void navigate({ to: route })
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [items, active, navigate])

  const displayName = session?.twitchDisplayName ?? '...'

  return (
    <div className={styles.shell}>
      <Topbar
        title={`the pit · ${displayName.toLowerCase()}`}
        depth={profile ? formatDepth(profile.currentDepth) : '...'}
        torch={
          profile ? `${profile.torchCurrent}/${profile.torchCapacity}` : '...'
        }
        scrap={profile?.totalScrap}
        shards={profile?.totalShards}
        right={
          session?.twitchAvatarUrl ? (
            <img
              className={styles.avatar}
              src={session.twitchAvatarUrl}
              alt=""
              aria-hidden
            />
          ) : null
        }
      />
      <Menubar items={items} active={active} onSelect={onSelect} />
      <main className={styles.body}>{children}</main>
    </div>
  )
}

function formatDepth(depth: number): string {
  return depth.toString().padStart(3, '0')
}
