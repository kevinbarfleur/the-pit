import { useEffect, useMemo, useRef } from 'react'
import type { CSSProperties } from 'react'
import type { AttachConfig, AttachKind } from '../../../pixi/EffectsEngine'
import { useEffects } from '../../../hooks/useEffects'
import { usePitUiStore } from '../../../stores/pitUiStore'
import type { PitRun } from '../../../hooks/usePitRun'
import type { PitNode as PitNodeModel, PitNodeState, PitNodeType } from '../../../game/pit/types'
import { CharacterSprite } from '../../characters/CharacterSprite'
import { MERCHANT } from '../../../game/characters/defs/merchant'
import { NodePopover } from './NodePopover'
import {
  CAP_BOTTOM_ANCHOR_NATIVE,
  CAP_TOP_ANCHOR_NATIVE,
  ISLAND_H,
  ISLAND_W,
  computeCapBounds,
  computeEventVariant,
  computeGroundArea,
  computeSignpostLayout,
  drawIsland,
} from './drawIsland'
import styles from './IslandNode.module.css'

interface IslandNodeProps {
  node: PitNodeModel
  state: PitNodeState
  canCommit: boolean
  run: PitRun
  style?: CSSProperties
}

/** CSS upscale factor on the real Pit map. The island canvas is
 *  ISLAND_W × ISLAND_H native (36 × 56) — at SCALE 3 that's
 *  108 × 168 CSS, which keeps the new pixel-art details (chests,
 *  hoard, signpost variants, pond, cascade) readable while still
 *  fitting under the current ROW_HEIGHT = 200. */
const SCALE = 3

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
  shop: 'coins',
  rest: 'grass',
  cache: 'sparkle',
  treasure: 'godray',
}

const TYPE_COLOR: Record<PitNodeType, number> = {
  combat: 0xd45a5a,
  elite: 0xb58b3a,
  boss: 0xd45a5a,
  event: 0x9a7bd4,
  shop: 0xf0c040,
  rest: 0x9ae66e,
  cache: 0xd8cfb8,
  treasure: 0xf0c050,
}

/**
 * Floating pixel-art stone island with a sign post planted on top.
 *
 * Structure:
 *   <button>
 *     <canvas/>           — bitmap: cap + stalactites + signpost
 *     <div capZone/>      — invisible, sized to the cap only. Used as
 *                           the spawn target for hover effects so
 *                           embers/grass stay inside the rock's
 *                           silhouette rather than covering the whole
 *                           rect (which would include the stalactite
 *                           gap).
 *     <span glyph/>       — HTML overlay positioned over the plaque
 *                           so it follows every signpost variant.
 *     <span currentMarker/> — chevron bobbing above the plaque for the
 *                             player's current island.
 *   </button>
 */
export function IslandNode({ node, state, canCommit, run, style }: IslandNodeProps) {
  const ref = useRef<HTMLButtonElement | null>(null)
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const capZoneRef = useRef<HTMLDivElement | null>(null)
  const capRectRef = useRef<HTMLDivElement | null>(null)
  const engine = useEffects()
  const setHoveredId = usePitUiStore((s) => s.setHoveredId)
  const startZoomIn = usePitUiStore((s) => s.startZoomIn)
  // Subscribe with a memoised boolean — only this island re-renders
  // when its hover flag flips, not every island in the map.
  const isHovered = usePitUiStore((s) => s.hoveredId === node.id)

  const signpost = useMemo(() => computeSignpostLayout(node.id), [node.id])
  const ground = useMemo(() => computeGroundArea(node.id), [node.id])
  const capBounds = useMemo(() => computeCapBounds(node.id), [node.id])

  // Draw the bitmap once per (id, type). State changes are handled in CSS.
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d', { alpha: true })
    if (!ctx) return
    ctx.imageSmoothingEnabled = false
    drawIsland(ctx, node.id, node.type)
  }, [node.id, node.type])

  // Effect binding — every island runs its hover effect from mount.
  // No more hover gating, no more disable on locked / bypassed / cleared.
  // Player feedback: every animation should be visible from the start.
  useEffect(() => {
    if (!engine) return
    // Shop islands carry the merchant NPC — that's the visual signal,
    // no need to layer the gold/coins shower on top.
    if (node.type === 'shop') return
    const cap = capZoneRef.current
    if (!cap) return

    const isSpring =
      node.type === 'event' && computeEventVariant(node.id) === 'spring'
    const kind: AttachKind = isSpring ? 'spring' : TYPE_HOVER[node.type]
    let attachConfig: AttachConfig
    if (kind === 'grass') {
      attachConfig = {
        color: TYPE_COLOR[node.type],
        shape: 'patch',
        heightScale: 0.8,
        countScale: 5,
      }
    } else if (kind === 'spring') {
      let h = 0
      for (let i = 0; i < node.id.length; i++) h = (h * 31 + node.id.charCodeAt(i)) | 0
      const side: 'left' | 'right' = ((h >> 5) & 1) === 0 ? 'left' : 'right'
      attachConfig = { color: 0x6ec3d4, side }
    } else {
      attachConfig = { color: TYPE_COLOR[node.type] }
    }
    const { id, detach } = engine.attachWithHandle(cap, kind, attachConfig)
    engine.setEnabled(id, true)
    return () => detach()
  }, [engine, node.type, node.id])

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

  // Plaque centre + size in CSS px, for the HTML glyph / chevron overlays.
  const plaqueLeftCss = (signpost.plaqueCenterX - signpost.plaqueW / 2) * SCALE
  const plaqueTopCss = (signpost.plaqueCenterY - signpost.plaqueH / 2) * SCALE
  const plaqueWCss = signpost.plaqueW * SCALE
  const plaqueHCss = signpost.plaqueH * SCALE
  const tiltDeg = (Math.atan(signpost.tiltRise) * 180) / Math.PI

  // Effect anchor zone — the **visible top surface of the cap**, used
  // as a patch-distribution area for grass (and as an origin for other
  // radiating effects). The island is drawn in an isometric-looking
  // capZone == ground area. Single source of truth for prop placement
  // AND effect spawn anchor (see computeGroundArea in drawIsland.ts).
  const capZoneTopCss = ground.top * SCALE
  const capZoneHeightCss = ground.height * SCALE
  const capZoneLeftCss = ground.left * SCALE
  const capZoneWidthCss = ground.width * SCALE

  return (
    <button
      ref={ref}
      type="button"
      className={styles.island}
      data-state={state}
      data-type={node.type}
      data-island-id={node.id}
      data-anchor-cap-top-px={CAP_TOP_ANCHOR_NATIVE * SCALE}
      data-anchor-cap-bottom-px={CAP_BOTTOM_ANCHOR_NATIVE * SCALE}
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
      {/* Invisible cap zone — drives effect spawn area. */}
      <div
        ref={capZoneRef}
        className={styles.capZone}
        style={{
          top: `${capZoneTopCss}px`,
          left: `${capZoneLeftCss}px`,
          width: `${capZoneWidthCss}px`,
          height: `${capZoneHeightCss}px`,
        }}
        aria-hidden="true"
      />
      <div
        ref={capRectRef}
        className={styles.capZone}
        style={{
          top: `${(capBounds.centerY - capBounds.halfHeight) * SCALE}px`,
          left: `${(capBounds.centerX - capBounds.halfWidth) * SCALE}px`,
          width: `${capBounds.halfWidth * 2 * SCALE}px`,
          height: `${capBounds.halfHeight * 2 * SCALE}px`,
        }}
        aria-hidden="true"
      />
      {/* Shop island gets a tiny rigged merchant standing on the cap.
          Offset horizontally from the signpost so the two don't sit
          dead-aligned — the merchant reads as "in front" of the post. */}
      {node.type === 'shop' && (
        <CharacterSprite
          def={MERCHANT}
          width={capZoneWidthCss}
          height={Math.max(48, capZoneHeightCss + 48)}
          scale={3}
          anchorY={0.95}
          className={styles.merchant}
          style={{
            left: `${capZoneLeftCss + 16}px`,
            top: `${capZoneTopCss - 40}px`,
          }}
        />
      )}
      {/* Glyph overlay, positioned over the signpost plaque. Tilt
          follows the signpost's pose so the glyph stays legible
          regardless of the variant. */}
      <span
        className={styles.glyph}
        style={{
          left: `${plaqueLeftCss}px`,
          top: `${plaqueTopCss}px`,
          width: `${plaqueWCss}px`,
          height: `${plaqueHCss}px`,
          transform: `rotate(${tiltDeg.toFixed(1)}deg)`,
        }}
      >
        {TYPE_GLYPH[node.type]}
      </span>
      {state === 'current' && (
        <span
          className={styles.currentMarker}
          style={{
            left: `${(signpost.plaqueCenterX * SCALE) - 6}px`,
            top: `${plaqueTopCss - 12}px`,
          }}
        >
          ▼
        </span>
      )}
      {isHovered && <NodePopover node={node} run={run} />}
    </button>
  )
}
