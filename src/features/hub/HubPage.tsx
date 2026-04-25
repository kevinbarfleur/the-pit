import { useCallback, useEffect, useMemo, useRef } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Button, Menubar, Topbar } from '../../components/ui'
import { ChainsProvider } from '../../components/pixi/ChainsProvider'
import { usePlayerIdentity } from '../../hooks/usePlayerIdentity'
import { usePlayerProfile } from '../../hooks/usePlayerProfile'
import { HubChains } from './HubChains'
import { InfoCluster, type ClusterTone } from './InfoCluster'
import styles from './HubPage.module.css'

const CHAINS_HOST_ID = 'hub-chains-host'

const MENU_ITEMS = [
  { key: 'D', label: 'Pit' },
  { key: 'P', label: 'Passives', dim: true },
  { key: 'C', label: 'Cards', dim: true },
  { key: 'X', label: 'Codex', dim: true },
  { key: 'L', label: 'Leaderboard', dim: true },
]

interface ClusterDef {
  key: 'depth' | 'deepest' | 'gold' | 'resources' | 'torch'
  glyph: string
  label: string
  angleDeg: number
  radiusPx: number
  tiltDeg: number
  tone: ClusterTone
}

/**
 * Five info clusters orbiting the central CTA. Placement is a
 * deliberately *imperfect* pentagram — angles avoid the cardinals, no
 * mirror symmetry, radii vary, and each cluster carries a small
 * `tiltDeg` so the runic frames don't read as a clean stamped grid.
 */
const CLUSTERS: readonly ClusterDef[] = [
  { key: 'depth',     glyph: '↓', label: 'Depth',          angleDeg: -52, radiusPx: 340, tiltDeg: -2.5, tone: 'bone' },
  { key: 'deepest',   glyph: '⌇', label: 'Deepest',        angleDeg: 38,  radiusPx: 320, tiltDeg: 1.8,  tone: 'gild' },
  { key: 'gold',      glyph: '◆', label: 'Gold',           angleDeg: -108, radiusPx: 360, tiltDeg: 3.2,  tone: 'amber' },
  { key: 'resources', glyph: '⌗', label: 'Scrap · Shards', angleDeg: 105, radiusPx: 345, tiltDeg: -3.5, tone: 'violet' },
  { key: 'torch',     glyph: '☩', label: 'Torch',          angleDeg: 198, radiusPx: 310, tiltDeg: 2.2,  tone: 'red' },
]

/**
 * Player hub. Topbar + Menubar inherit from the chrome; the body hosts
 * a ritual slot whose centrepiece is the kit's blood-drip CTA. Five
 * runic info containers orbit the button on an imperfect pentagram,
 * each connected to the centre by a live pit chain (same engine, same
 * pixel-art maillons, same pendulum sway). Re-using ChainsEngine here
 * means the hub speaks the same visual language as the descent itself.
 */
export function HubPage() {
  const identity = usePlayerIdentity()
  const profile = usePlayerProfile(identity.playerId)
  const navigate = useNavigate()

  const onDescend = useCallback(() => {
    if (!identity.playerId) return
    void navigate({ to: '/pit' })
  }, [identity.playerId, navigate])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement) return
      if (e.target instanceof HTMLTextAreaElement) return
      if (e.key === 'd' || e.key === 'D') {
        e.preventDefault()
        onDescend()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onDescend])

  // Refs for chain anchoring — the button at the centre (sag origin
  // only; chains never attach to it) and each cluster wrapper for the
  // ring's vertices. Wrappers carry the polar transform so their
  // bounding rect is what we want to measure.
  const buttonRef = useRef<HTMLButtonElement | null>(null)
  const depthRef = useRef<HTMLDivElement | null>(null)
  const deepestRef = useRef<HTMLDivElement | null>(null)
  const goldRef = useRef<HTMLDivElement | null>(null)
  const resourcesRef = useRef<HTMLDivElement | null>(null)
  const torchRef = useRef<HTMLDivElement | null>(null)
  const clusterRefs: Record<ClusterDef['key'], React.RefObject<HTMLDivElement | null>> =
    useMemo(
      () => ({
        depth: depthRef,
        deepest: deepestRef,
        gold: goldRef,
        resources: resourcesRef,
        torch: torchRef,
      }),
      [],
    )

  // Cyclic ring order — clusters sorted by their angular position so
  // consecutive chains form a closed loop with no crossings.
  const ringOrder = useMemo(() => {
    const norm = (a: number) => ((a % 360) + 360) % 360
    return [...CLUSTERS]
      .sort((a, b) => norm(a.angleDeg) - norm(b.angleDeg))
      .map((c) => ({ key: c.key, ref: clusterRefs[c.key] }))
  }, [clusterRefs])

  const displayName = identity.displayName ?? 'descender'
  const currentDepth = profile?.currentDepth ?? 0
  const deepestDepth = profile?.deepestDepth ?? 0
  const totalGold = profile?.totalGold ?? 0
  const totalScrap = profile?.totalScrap ?? 0
  const totalShards = profile?.totalShards ?? 0
  const torchCapacity = profile?.torchCapacity ?? 5

  const clusterValues: Record<ClusterDef['key'], string> = {
    depth: `D${currentDepth.toString().padStart(3, '0')}`,
    deepest: `D${deepestDepth.toString().padStart(3, '0')}`,
    gold: String(totalGold),
    resources: `${totalScrap} · ${totalShards}`,
    torch: `${torchCapacity}/${torchCapacity}`,
  }

  return (
    <main className={styles.page}>
      <Topbar title={`hub · ${displayName.toLowerCase()}`} />
      <Menubar active="D" items={MENU_ITEMS} />
      <div className={styles.body}>
        <div id={CHAINS_HOST_ID} className={styles.chainsHost} aria-hidden="true" />
        <ChainsProvider mountTargetId={CHAINS_HOST_ID}>
          <HubChains ring={ringOrder} />
          <div className={styles.ritualSlot}>
            {CLUSTERS.map((c) => (
              <InfoCluster
                key={c.key}
                ref={clusterRefs[c.key]}
                glyph={c.glyph}
                label={c.label}
                value={clusterValues[c.key]}
                angleDeg={c.angleDeg}
                radiusPx={c.radiusPx}
                tiltDeg={c.tiltDeg}
                tone={c.tone}
              />
            ))}
            <Button
              ref={buttonRef}
              variant="danger"
              size="lg"
              juicy
              disabled={!identity.playerId}
              onClick={onDescend}
              className={styles.cta}
            >
              The Pit
            </Button>
          </div>
        </ChainsProvider>
      </div>
    </main>
  )
}
