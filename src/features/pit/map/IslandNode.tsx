import { useEffect, useMemo, useRef } from 'react'
import type { CSSProperties } from 'react'
import type { AttachKind } from '../../../pixi/EffectsEngine'
import { useEffects } from '../../../hooks/useEffects'
import { useHoverEffect } from '../../../hooks/useHoverEffect'
import { usePitUiStore } from '../../../stores/pitUiStore'
import type { PitNode as PitNodeModel, PitNodeState, PitNodeType } from '../../../game/pit/types'
import {
  CAP_BOTTOM_ANCHOR_CSS,
  CAP_TOP_ANCHOR_CSS,
  ISLAND_H,
  ISLAND_W,
  drawIsland,
} from './drawIsland'
import styles from './IslandNode.module.css'

interface IslandNodeProps {
  node: PitNodeModel
  state: PitNodeState
  canCommit: boolean
  style?: CSSProperties
}

const SCALE = 2

const TYPE_GLYPH: Record<PitNodeType, string> = {
  combat: '⚔',
  elite: '◆',
  boss: '◈',
  event: '~',
  shop: '⌂',
  rest: '☩',
  cache: '◇',
  treasure: '✦',
}

const TYPE_HOVER: Record<PitNodeType, AttachKind> = {
  combat: 'pulse',
  elite: 'embers',
  boss: 'embers',
  event: 'sparkle',
  shop: 'ripple',
  rest: 'grass',
  cache: 'sparkle',
  treasure: 'embers',
}

const TYPE_COLOR: Record<PitNodeType, number> = {
  combat: 0xd45a5a,
  elite: 0xb58b3a,
  boss: 0xd45a5a,
  event: 0x9a7bd4,
  shop: 0x6ec3d4,
  rest: 0x9ae66e,
  cache: 0xd8cfb8,
  treasure: 0xd4a147,
}

/**
 * Floating pixel-art stone island with a sign post planted on top.
 *
 * The stone itself stays neutral-grey (picked from a palette of four
 * tonal variants by id hash). The activity is signalled by a tiny
 * coloured plaque on a stake — that's what makes the map readable
 * without every island turning the viewport into a fruit salad.
 *
 * The current-island marker is a chevron ▼ that floats above the
 * plaque and bobs — replaces the previous green drop-shadow halo,
 * which the user found visually noisy.
 *
 * Chain anchors are exposed via `data-anchor-cap-top-px` and
 * `data-anchor-cap-bottom-px` (CSS pixels, relative to the button's
 * top edge). These are the y-offsets of the cap's top and bottom,
 * respectively — NOT the stalactite tips — so chains tie visually to
 * the island body rather than to its broken dangling edges.
 */
export function IslandNode({ node, state, canCommit, style }: IslandNodeProps) {
  const ref = useRef<HTMLButtonElement | null>(null)
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const engine = useEffects()
  const setHoveredId = usePitUiStore((s) => s.setHoveredId)
  const startZoomIn = usePitUiStore((s) => s.startZoomIn)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d', { alpha: true })
    if (!ctx) return
    ctx.imageSmoothingEnabled = false
    drawIsland(ctx, node.id, node.type)
  }, [node.id, node.type])

  const hoverEnabled =
    state !== 'locked' && state !== 'bypassed' && state !== 'current'
  useHoverEffect(
    ref,
    TYPE_HOVER[node.type],
    { color: TYPE_COLOR[node.type] },
    hoverEnabled,
  )

  const handleClick = () => {
    if (!canCommit) return
    const el = ref.current
    if (!el) return
    const r = el.getBoundingClientRect()
    if (engine) {
      engine.emitBurst({
        x: r.left + r.width / 2,
        y: r.top + r.height / 2,
        variant: node.type === 'rest' ? 'primary' : 'default',
      })
    }
    startZoomIn({
      nodeId: node.id,
      nodeType: node.type,
      rect: { x: r.left, y: r.top, width: r.width, height: r.height },
    })
  }

  const floatDelay = useMemo(() => {
    let h = 0
    for (let i = 0; i < node.id.length; i++) h = (h * 31 + node.id.charCodeAt(i)) | 0
    return ((h >>> 0) % 1000) / 1000
  }, [node.id])

  const w = ISLAND_W * SCALE
  const h = ISLAND_H * SCALE

  return (
    <button
      ref={ref}
      type="button"
      className={styles.island}
      data-state={state}
      data-type={node.type}
      data-island-id={node.id}
      data-anchor-cap-top-px={CAP_TOP_ANCHOR_CSS}
      data-anchor-cap-bottom-px={CAP_BOTTOM_ANCHOR_CSS}
      disabled={!canCommit}
      onMouseEnter={() => setHoveredId(node.id)}
      onMouseLeave={() => setHoveredId(null)}
      onFocus={() => setHoveredId(node.id)}
      onBlur={() => setHoveredId(null)}
      onClick={handleClick}
      style={
        {
          ...style,
          width: `${w}px`,
          height: `${h}px`,
          animationDelay: `-${floatDelay * 2.4}s`,
        } as CSSProperties
      }
      aria-label={`${node.type} at depth ${node.depth}`}
    >
      <canvas
        ref={canvasRef}
        className={styles.canvas}
        width={ISLAND_W}
        height={ISLAND_H}
        style={{ width: `${w}px`, height: `${h}px` }}
      />
      {/* Glyph rendered over the plaque via HTML for crisp VT323. */}
      <span className={styles.glyph}>{TYPE_GLYPH[node.type]}</span>
      {state === 'current' && <span className={styles.currentMarker}>▼</span>}
    </button>
  )
}
