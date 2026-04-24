import { useEffect, useRef } from 'react'
import styles from './ZoomTransition.module.css'

export type ZoomDirection = 'in' | 'out'

interface ZoomTransitionProps {
  /** Viewport rect of the target tile (click rect). Anchors the scale. */
  anchor: { x: number; y: number; width: number; height: number }
  direction: ZoomDirection
  onComplete: () => void
}

/**
 * Stepped-scale zoom on the Pit map. Moves `#pit-map-root` through a
 * discrete sequence of scales with a 140ms dwell per step, giving a
 * chunky pixel-art "drilling in" feel rather than a GPU-smooth pinch.
 *
 * Per CLAUDE.md, interpolation easing is banned — only linear/step. Step
 * is what we use. Also doubles as a pixelation-preserving approach: the
 * GPU never has to resample between two arbitrary sub-pixel scales.
 *
 * Chrome (depth gauge, right panel, shaft walls) is faded by a sibling
 * overlay that absorbs pointer events while the zoom runs.
 */
const SCALE_STEPS = [1, 2, 4, 8, 12] as const
const STEP_MS = 140

export function ZoomTransition({ anchor, direction, onComplete }: ZoomTransitionProps) {
  const doneRef = useRef(false)

  useEffect(() => {
    const root = document.getElementById('pit-map-root')
    if (!root) {
      onComplete()
      return
    }

    const steps = direction === 'in' ? SCALE_STEPS : [...SCALE_STEPS].reverse()
    const maxScale = SCALE_STEPS[SCALE_STEPS.length - 1]
    const anchorCx = anchor.x + anchor.width / 2
    const anchorCy = anchor.y + anchor.height / 2
    const vx = window.innerWidth / 2
    const vy = window.innerHeight / 2
    const tx = vx - anchorCx
    const ty = vy - anchorCy

    // Stash previous transform so we can restore on unmount / interrupt.
    const prevTransform = root.style.transform
    const prevOrigin = root.style.transformOrigin
    root.style.transformOrigin = `${anchorCx}px ${anchorCy}px`

    let cancelled = false
    const timers: number[] = []

    const applyStep = (idx: number) => {
      if (cancelled) return
      const scale = steps[idx]
      // Centering factor: 0 at scale 1 (start), 1 at scale max (end).
      const factor = (scale - 1) / (maxScale - 1)
      root.style.transform = `translate(${tx * factor}px, ${ty * factor}px) scale(${scale})`

      if (idx === steps.length - 1) {
        if (!doneRef.current) {
          doneRef.current = true
          // Small dwell on the final scale before handing control over.
          const last = window.setTimeout(() => {
            if (!cancelled) onComplete()
          }, STEP_MS)
          timers.push(last)
        }
        return
      }
      const t = window.setTimeout(() => applyStep(idx + 1), STEP_MS)
      timers.push(t)
    }

    applyStep(0)

    return () => {
      cancelled = true
      for (const t of timers) window.clearTimeout(t)
      // Only restore on a cancel (unmount before complete).
      if (!doneRef.current) {
        root.style.transform = prevTransform
        root.style.transformOrigin = prevOrigin
      } else if (direction === 'out') {
        // Zoom-out completed: map is back to identity, clean the inline style.
        root.style.transform = prevTransform
        root.style.transformOrigin = prevOrigin
      }
    }
    // anchor is captured at mount; changing it mid-flight would be a bug.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return <div className={styles.overlay} aria-hidden="true" />
}
