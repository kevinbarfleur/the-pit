import { useEffect, useRef } from 'react'
import { useEffects } from '../../../hooks/useEffects'
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
 * discrete sequence of scales with a 120ms dwell per step.
 *
 * Performance notes (iterated on user feedback about lag):
 *  - Scale max capped at 8× to keep the composited surface manageable.
 *  - `EffectsEngine.pauseTicker()` freezes the Pixi stage for the
 *    duration of the animation — no hover effects, no embers, no
 *    sparkle wasting cycles on elements that are scaling out.
 *  - Chrome is kept *present* (React stays mounted) but CSS switches it
 *    to `display: none` via a `data-zoom` attribute on the scene root
 *    so browsers don't paint or layout it while the map scales.
 */
const SCALE_STEPS = [1, 2, 4, 6, 8] as const
const STEP_MS = 120

export function ZoomTransition({ anchor, direction, onComplete }: ZoomTransitionProps) {
  const doneRef = useRef(false)
  const engine = useEffects()

  useEffect(() => {
    const root = document.getElementById('pit-map-root')
    if (!root) {
      onComplete()
      return
    }
    // Freeze the Pixi ticker — nothing on-screen needs its updates
    // while the map is scaling and all the hover effects are offscreen.
    engine?.pauseTicker()

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
      // Resume the ticker in any scenario — zoom done, zoom cancelled, or
      // unmount for any other reason. Always safe.
      engine?.resumeTicker()
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
