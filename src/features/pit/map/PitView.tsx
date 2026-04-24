import { useEffect, useMemo, useRef } from 'react'
import type { PitRun } from '../../../hooks/usePitRun'
import { DepthGauge } from './DepthGauge'
import { NodeDetailPanel } from './NodeDetailPanel'
import { NodeMap } from './NodeMap'
import { PitShaft } from './PitShaft'
import { ChainLayer } from './ChainLayer'
import styles from './PitView.module.css'

/**
 * Map surface of the Pit. Three columns: depth gauge, the shaft itself,
 * and the hover-detail panel. The shaft's inner stack is vertically
 * translated so the player's current node sits at ~55% viewport height,
 * giving the eye more look-ahead than look-back while still showing the
 * cleared ground behind.
 */

export const ROW_HEIGHT = 200
/** Fraction of the viewport where the current node is pinned vertically. */
const CAMERA_ANCHOR_FRAC = 0.55

interface PitViewProps {
  run: PitRun
}

export function PitView({ run }: PitViewProps) {
  const shaftRef = useRef<HTMLDivElement | null>(null)

  const cameraOffset = useCameraOffset(run.currentDepth)

  // Depth range rendered this frame. Read off the run's window.
  const { minDepth, maxDepth } = useMemo(() => {
    let min = Number.POSITIVE_INFINITY
    let max = Number.NEGATIVE_INFINITY
    for (const n of run.window.nodes) {
      if (n.depth < min) min = n.depth
      if (n.depth > max) max = n.depth
    }
    return { minDepth: min, maxDepth: max }
  }, [run.window])

  return (
    <div className={styles.root} id="pit-map-root">
      <PitShaft />
      <DepthGauge
        currentDepth={run.currentDepth}
        minDepth={minDepth}
        maxDepth={maxDepth}
        cameraOffset={cameraOffset}
        rowHeight={ROW_HEIGHT}
      />
      <div className={styles.shaft} ref={shaftRef}>
        <div
          className={styles.shaftInner}
          style={{ transform: `translateY(${cameraOffset}px)` }}
        >
          <ChainLayer
            run={run}
            minDepth={minDepth}
            maxDepth={maxDepth}
            rowHeight={ROW_HEIGHT}
          />
          <NodeMap
            run={run}
            minDepth={minDepth}
            maxDepth={maxDepth}
            rowHeight={ROW_HEIGHT}
          />
        </div>
      </div>
      <NodeDetailPanel run={run} />
    </div>
  )
}

/**
 * Compute the pixel translate needed to pin the current depth at
 * CAMERA_ANCHOR_FRAC of the shaft's height. The shaftInner's origin is
 * (0, minDepth*ROW_HEIGHT); we want currentDepth at anchor.
 */
function useCameraOffset(currentDepth: number): number {
  const ref = useRef<number>(0)
  // Re-sample viewport on resize so pinning stays correct.
  useEffect(() => {
    const update = () => {
      ref.current = computeOffset(currentDepth)
    }
    update()
    window.addEventListener('resize', update)
    return () => window.removeEventListener('resize', update)
  }, [currentDepth])
  return computeOffset(currentDepth)
}

function computeOffset(currentDepth: number): number {
  const vh = typeof window === 'undefined' ? 900 : window.innerHeight
  const anchorPx = vh * CAMERA_ANCHOR_FRAC
  // minDepth*ROW_HEIGHT is the top of the stack; we want currentDepth's
  // centre (currentDepth*ROW_HEIGHT + ROW_HEIGHT/2) at anchorPx.
  const currentCenter = currentDepth * ROW_HEIGHT + ROW_HEIGHT / 2
  return anchorPx - currentCenter
}
