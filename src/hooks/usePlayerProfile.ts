import { useQuery } from 'convex/react'
import { api } from '../../convex/_generated/api'
import type { Id } from '../../convex/_generated/dataModel'

export interface PlayerProfile {
  currentDepth: number
  deepestDepth: number
  seed: string
  totalGold: number
  totalScrap: number
  totalShards: number
  torchCapacity: number
}

/**
 * Live-bound profile for a player. Returns `null` while the query is in
 * flight (or when `playerId` is itself `null` — i.e. before identity
 * resolves). The hub renders a zeroed shell during this window.
 */
export function usePlayerProfile(
  playerId: Id<'players'> | null,
): PlayerProfile | null {
  const profile = useQuery(
    api.profiles.getByPlayer,
    playerId ? { playerId } : 'skip',
  )
  if (!profile) return null
  return {
    currentDepth: profile.currentDepth,
    deepestDepth: profile.deepestDepth,
    seed: profile.seed,
    totalGold: profile.totalGold,
    totalScrap: profile.totalScrap,
    totalShards: profile.totalShards,
    torchCapacity: profile.torchCapacity,
  }
}
