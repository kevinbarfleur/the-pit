import { useEffect, useMemo } from 'react'
import type { PitNode, PitNodeState } from '../../../game/pit/types'
import type { PitRun } from '../../../hooks/usePitRun'
import { useChains } from '../../../hooks/useChains'
import { usePitUiStore } from '../../../stores/pitUiStore'
import type { ChainSpec, ChainState } from '../../../pixi/ChainsEngine'

interface ChainLayerProps {
  run: PitRun
  minDepth: number
  maxDepth: number
  rowHeight: number
}

/**
 * Drives the Pixi `ChainsEngine` from the Pit graph. For every downlink
 * in the visible window it computes viewport-space anchor coordinates
 * by reading the island buttons' DOMRects (they expose data-island-id +
 * data-anchor-top/bottom, populated by `IslandNode`), classifies the
 * chain's state, and calls `engine.syncChains(specs)`.
 *
 * Sync runs on every animation frame so the chains follow:
 *   - island float bob (the IslandNode animates its transform),
 *   - camera translate (shaftInner transform),
 *   - page resize / scroll.
 *
 * Rendering is handled entirely by the engine; this component mounts no
 * DOM of its own.
 */
export function ChainLayer({ run }: ChainLayerProps) {
  const engine = useChains()
  const scene = usePitUiStore((s) => s.scene)

  // Pre-compute the static list of (from, to) node pairs we need to
  // render. This is the only thing that changes when the graph changes;
  // the per-frame loop just reads positions and state.
  const pairs = useMemo(() => collectLinkPairs(run), [run.window])

  useEffect(() => {
    if (!engine) return
    // Freeze chain sim during the zoom transition — anchor reads would
    // be meaningless while the map is scaling up.
    if (scene === 'zooming-in' || scene === 'in-node' || scene === 'zooming-out') {
      engine.pauseTicker()
      // Clear any visible chains so none remain when the room mounts.
      engine.syncChains([])
      return
    }
    engine.resumeTicker()

    let running = true
    const push = () => {
      if (!running) return
      const specs: ChainSpec[] = []
      for (const pair of pairs) {
        const fromEl = document.querySelector<HTMLElement>(`[data-island-id="${cssEscape(pair.fromId)}"]`)
        const toEl = document.querySelector<HTMLElement>(`[data-island-id="${cssEscape(pair.toId)}"]`)
        if (!fromEl || !toEl) continue
        const fromRect = fromEl.getBoundingClientRect()
        const toRect = toEl.getBoundingClientRect()
        // Anchors are y-offsets (CSS px) from the button's top to the
        // cap's base (bottom) / top. Chains tie into the body of the
        // rock — never into the tip of the dangling stalactites, which
        // looked detached.
        const fromAnchorY = Number(fromEl.dataset.anchorCapBottomPx ?? fromRect.height)
        const toAnchorY = Number(toEl.dataset.anchorCapTopPx ?? 0)
        specs.push({
          id: `${pair.fromId}->${pair.toId}`,
          fromX: fromRect.left + fromRect.width / 2,
          fromY: fromRect.top + fromAnchorY,
          toX: toRect.left + toRect.width / 2,
          toY: toRect.top + toAnchorY,
          state: pair.state(run),
        })
      }
      engine.syncChains(specs)
      raf = requestAnimationFrame(push)
    }
    let raf = requestAnimationFrame(push)
    return () => {
      running = false
      cancelAnimationFrame(raf)
      engine.syncChains([])
    }
  }, [engine, pairs, run, scene])

  return null
}

// -----------------------------------------------------------------------
// Internal
// -----------------------------------------------------------------------

interface LinkPair {
  fromId: string
  toId: string
  /** Closure that re-classifies the chain state from current run state. */
  state: (run: PitRun) => ChainState
}

function collectLinkPairs(run: PitRun): LinkPair[] {
  const out: LinkPair[] = []
  for (const from of run.window.nodes) {
    for (const toId of from.linksDown) {
      const to = run.window.byId.get(toId)
      if (!to) continue
      out.push({
        fromId: from.id,
        toId: to.id,
        state: (r) => classify(from, to, r),
      })
    }
  }
  return out
}

function classify(from: PitNode, to: PitNode, run: PitRun): ChainState {
  const path = run.state.path
  const fromIdx = path.indexOf(from.id)
  const toIdx = path.indexOf(to.id)
  if (fromIdx !== -1 && toIdx !== -1 && toIdx === fromIdx + 1) return 'traversed'
  const toState: PitNodeState = run.nodeState(to)
  const fromState: PitNodeState = run.nodeState(from)
  if (fromState === 'current' || toState === 'current') return 'active'
  if (fromState === 'bypassed' || toState === 'bypassed') return 'bypassed'
  return 'latent'
}

/** Minimal CSS.escape replacement — the node ids (e.g. "50:1") contain
 *  a colon which breaks attribute selectors if unescaped. */
function cssEscape(s: string): string {
  if (typeof CSS !== 'undefined' && typeof CSS.escape === 'function') return CSS.escape(s)
  return s.replace(/([^\w-])/g, '\\$1')
}
