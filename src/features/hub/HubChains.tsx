import { useEffect } from 'react'
import type { RefObject } from 'react'
import { useChains } from '../../hooks/useChains'
import type { ChainSpec } from '../../pixi/ChainsEngine'

interface RingEntry {
  key: string
  ref: RefObject<HTMLElement | null>
}

interface HubChainsProps {
  /** Ring entries IN ANGULAR ORDER. The hub draws one chain between
   *  each consecutive pair (and one closing the ring) so the five
   *  clusters end up garlanded in a circle. */
  ring: readonly RingEntry[]
}

/**
 * Visual sag target in pixels — how far the midpoint of every chain
 * should droop below the chord at rest. Kept tiny on purpose: the
 * design wants a chain that reads as "almost taut, but you can see
 * the gravity bending it", not a hanging rope. Held *constant in px*
 * (rather than as a percentage of the chord) so a 600 px chain
 * doesn't sag 4× more than a 200 px chain — they all hang by roughly
 * the same visual amount.
 */
const TARGET_SAG_PX = 6

/**
 * The chain spanning the top of the ring keeps Verlet physics — it
 * still pends and reacts to the cursor — but with a smaller target
 * sag AND a fraction of the engine's gravity, so the simulator
 * actually settles near the analytical equilibrium instead of
 * overshooting it (Verlet at full gravity always droops a bit lower
 * than its theoretical sag because constraint passes can't fully
 * cancel the velocity built up between integration and relaxation).
 */
const TOP_SAG_PX = 4
const TOP_GRAVITY_SCALE = 0.3

/**
 * Convert a target visual sag (px) into the rope-length slack ratio
 * that produces it for a given chord length. Derived from the
 * short-span catenary approximation:
 *
 *   sag ≈ sqrt( 3 × chord × (arcLen − chord) / 8 )
 *
 * solved for `arcLen / chord`:
 *
 *   slack = 1 + (8/3) × sag² / chord²
 */
function slackForSag(chord: number, sagPx: number): number {
  if (chord < 1) return 1
  return 1 + ((8 / 3) * sagPx * sagPx) / (chord * chord)
}

/**
 * Bridges the hub's DOM layout to the same `ChainsEngine` the pit uses.
 * Each frame we measure the bounding rect of every ring entry and feed
 * `engine.syncChains` a fresh spec list — one chain between consecutive
 * neighbours, closing the loop. The engine simulates each chain with
 * Verlet integration (gravity + distance constraints + pinned ends),
 * so the rope hangs in a real catenary curve regardless of the
 * anchors' relative position.
 *
 * RAF loop: the chain anchors depend on layout rects (the polar
 * transform happens entirely in CSS), so a frame-by-frame sweep keeps
 * the chains glued to the cluster positions through resize and reflow.
 */
export function HubChains({ ring }: HubChainsProps) {
  const engine = useChains()

  // Pointer tracking — feed the engine the cursor position so the
  // Verlet ropes can react locally when the user hovers a chain.
  // Using window-level listeners (not attached to a specific DOM node)
  // is the simplest way to handle the chain canvas being a sibling
  // overlay rather than a parent of the cursor.
  useEffect(() => {
    if (!engine) return
    const onMove = (e: MouseEvent) => engine.setPointer(e.clientX, e.clientY)
    const onLeave = () => engine.setPointer(null, null)
    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseleave', onLeave)
    document.addEventListener('mouseleave', onLeave)
    return () => {
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseleave', onLeave)
      document.removeEventListener('mouseleave', onLeave)
      engine.setPointer(null, null)
    }
  }, [engine])

  useEffect(() => {
    if (!engine) return
    let rafId = 0

    const tick = () => {
      const points: Array<{ key: string; x: number; y: number }> = []
      for (const { key, ref } of ring) {
        const r = ref.current?.getBoundingClientRect()
        if (!r) continue
        points.push({
          key,
          x: r.left + r.width / 2,
          y: r.top + r.height / 2,
        })
      }

      const specs: ChainSpec[] = []
      if (points.length >= 2) {
        // Identify the topmost chain (smallest midpoint Y) so we can
        // give it a tighter sag than the rest.
        let topIdx = 0
        let smallestMidY = Infinity
        for (let i = 0; i < points.length; i++) {
          const a = points[i]!
          const b = points[(i + 1) % points.length]!
          const midY = (a.y + b.y) / 2
          if (midY < smallestMidY) {
            smallestMidY = midY
            topIdx = i
          }
        }

        for (let i = 0; i < points.length; i++) {
          const a = points[i]!
          const b = points[(i + 1) % points.length]!
          const dx = b.x - a.x
          const dy = b.y - a.y
          const chord = Math.sqrt(dx * dx + dy * dy)
          // Top chain pends less than the others but still under
          // Verlet so it reacts to the cursor like every other link.
          const isTop = i === topIdx
          const sagPx = isTop ? TOP_SAG_PX : TARGET_SAG_PX
          const slack = slackForSag(chord, sagPx)
          specs.push({
            id: `hub-ring-${a.key}-${b.key}`,
            fromX: a.x,
            fromY: a.y,
            toX: b.x,
            toY: b.y,
            state: 'active',
            slack,
            gravityScale: isTop ? TOP_GRAVITY_SCALE : 1,
          })
        }
      }
      engine.syncChains(specs)
      rafId = requestAnimationFrame(tick)
    }

    rafId = requestAnimationFrame(tick)
    return () => {
      cancelAnimationFrame(rafId)
      // Drop the chains we own so they don't bleed into other scenes.
      engine.syncChains([])
    }
  }, [engine, ring])

  return null
}
