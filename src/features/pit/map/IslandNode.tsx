import { useEffect, useMemo, useRef } from 'react'
import type { CSSProperties } from 'react'
import type { AttachKind } from '../../../pixi/EffectsEngine'
import { useEffects } from '../../../hooks/useEffects'
import { usePitUiStore } from '../../../stores/pitUiStore'
import type { PitNode as PitNodeModel, PitNodeState, PitNodeType } from '../../../game/pit/types'
import {
  CAP_BOTTOM_ANCHOR_CSS,
  CAP_TOP_ANCHOR_CSS,
  ISLAND_H,
  ISLAND_W,
  computeSignpostLayout,
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
export function IslandNode({ node, state, canCommit, style }: IslandNodeProps) {
  const ref = useRef<HTMLButtonElement | null>(null)
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const capZoneRef = useRef<HTMLDivElement | null>(null)
  const engine = useEffects()
  const setHoveredId = usePitUiStore((s) => s.setHoveredId)
  const startZoomIn = usePitUiStore((s) => s.startZoomIn)

  const signpost = useMemo(() => computeSignpostLayout(node.id), [node.id])

  // Draw the bitmap once per (id, type). State changes are handled in CSS.
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d', { alpha: true })
    if (!ctx) return
    ctx.imageSmoothingEnabled = false
    drawIsland(ctx, node.id, node.type)
  }, [node.id, node.type])

  // Hover effect binding — attached to the invisible cap-zone div, not
  // the whole button, so the effect spawns follow the rock's silhouette
  // and don't bleed over the signpost or the gap above the stalactites.
  // Pointer events still listen on the button so the hover triggers
  // cover the full visual.
  //
  // For grass specifically, we switch to the `patch` distribution +
  // compress blade heights so the visual reads as a short isometric
  // patch of grass on the cap's top surface (rather than tall blades
  // growing from a rectangle edge, which is the button-style default).
  const hoverEnabled =
    state !== 'locked' && state !== 'bypassed' && state !== 'current'
  useEffect(() => {
    if (!engine || !hoverEnabled) return
    const btn = ref.current
    const cap = capZoneRef.current
    if (!btn || !cap) return

    const kind = TYPE_HOVER[node.type]
    const attachConfig =
      kind === 'grass'
        ? {
            color: TYPE_COLOR[node.type],
            shape: 'patch' as const,
            heightScale: 0.8,
            countScale: 5,
          }
        : { color: TYPE_COLOR[node.type] }
    const { id, detach } = engine.attachWithHandle(cap, kind, attachConfig)
    engine.setEnabled(id, false)

    const onEnter = () => engine.setEnabled(id, true)
    const onLeave = () => engine.setEnabled(id, false)
    btn.addEventListener('pointerenter', onEnter)
    btn.addEventListener('pointerleave', onLeave)
    btn.addEventListener('focus', onEnter)
    btn.addEventListener('blur', onLeave)
    return () => {
      btn.removeEventListener('pointerenter', onEnter)
      btn.removeEventListener('pointerleave', onLeave)
      btn.removeEventListener('focus', onEnter)
      btn.removeEventListener('blur', onLeave)
      detach()
    }
  }, [engine, hoverEnabled, node.type])

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
  // style, with the top of the rock reading as a slab of ground you
  // could plant a panel into; this zone is that slab. Grass scatters
  // across its area as short blades, reading as a tuft of grass
  // growing on the ground rather than a spray coming off a button's
  // edge. Embers, sparkle, ripple and pulse then all radiate from the
  // centre of this slab, which sits under the signpost.
  const capZoneTopCss = 11 * SCALE // just below the cap's highest pixel
  const capZoneHeightCss = 10 * SCALE // thin slab of visible top surface
  const capZoneLeftCss = 7 * SCALE
  const capZoneWidthCss = 22 * SCALE

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
    </button>
  )
}
