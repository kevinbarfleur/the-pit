import { useMemo } from 'react'
import { MAX_COLUMNS, type PitNode, type PitNodeState } from '../../../game/pit/types'
import type { PitRun } from '../../../hooks/usePitRun'
import styles from './ChainLayer.module.css'

interface ChainLayerProps {
  run: PitRun
  minDepth: number
  maxDepth: number
  rowHeight: number
}

/**
 * V1 chains — a lightweight SVG pass that renders each downlink as a
 * vertical dashed "chain" segment tinted by its traversal state. This is
 * the stopgap until `ChainsEngine.ts` implements pixel-art maillons with
 * pendulum swing and tension animations on commit. The geometry math is
 * already in the final coordinate system (column % → lane centre, depth
 * row → y offset) so upgrading to Pixi later is a drop-in swap.
 */
export function ChainLayer({ run, minDepth, maxDepth, rowHeight }: ChainLayerProps) {
  const links = useMemo(() => computeLinks(run, minDepth, maxDepth), [run, minDepth, maxDepth])
  const totalHeight = (maxDepth - minDepth + 1) * rowHeight

  return (
    <svg
      className={styles.svg}
      preserveAspectRatio="none"
      viewBox={`0 ${minDepth * rowHeight} 100 ${totalHeight}`}
      aria-hidden="true"
    >
      {links.map((l, i) => (
        <line
          key={i}
          className={styles.chain}
          data-state={l.state}
          x1={l.x1}
          y1={l.y1}
          x2={l.x2}
          y2={l.y2}
        />
      ))}
    </svg>
  )
}

interface Link {
  x1: number
  y1: number
  x2: number
  y2: number
  state: 'traversed' | 'active' | 'latent' | 'bypassed'
}

function laneCenterPercent(column: number): number {
  const laneWidth = 100 / MAX_COLUMNS
  return column * laneWidth + laneWidth / 2
}

function computeLinks(run: PitRun, minDepth: number, maxDepth: number): Link[] {
  const links: Link[] = []
  for (let d = minDepth; d <= maxDepth; d++) {
    const row = run.window.byDepth.get(d)
    if (!row) continue
    for (const from of row) {
      for (const toId of from.linksDown) {
        const to = run.window.byId.get(toId)
        if (!to) continue
        const fromState = run.nodeState(from)
        const toState = run.nodeState(to)
        const state = classifyLink(fromState, toState, run, from, to)
        links.push({
          x1: laneCenterPercent(from.column),
          y1: from.depth * 140 + 70,
          x2: laneCenterPercent(to.column),
          y2: to.depth * 140 + 70,
          state,
        })
      }
    }
  }
  return links
}

function classifyLink(
  fromState: PitNodeState,
  toState: PitNodeState,
  run: PitRun,
  from: PitNode,
  to: PitNode,
): Link['state'] {
  // Both ends traversed, and the path actually contains them in order.
  const path = run.state.path
  const fromIdx = path.indexOf(from.id)
  const toIdx = path.indexOf(to.id)
  if (fromIdx !== -1 && toIdx !== -1 && toIdx === fromIdx + 1) return 'traversed'
  if (fromState === 'current') return 'active'
  if (toState === 'current') return 'active'
  if (fromState === 'bypassed' || toState === 'bypassed') return 'bypassed'
  return 'latent'
}
