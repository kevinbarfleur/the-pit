import { useEffect, useMemo, useRef } from 'react'
import type { CSSProperties } from 'react'
import type { AttachConfig, AttachKind } from '../../../pixi/EffectsEngine'
import { useEffects } from '../../../hooks/useEffects'
import type { PitNodeType } from '../../../game/pit/types'
import {
  ISLAND_H,
  ISLAND_W,
  computeEventVariant,
  computeGroundArea,
  computeSignpostLayout,
  drawIsland,
} from './drawIsland'
import styles from './IslandPreview.module.css'

interface IslandPreviewProps {
  /** Stable id — different ids yield different cap / stalactite / pose
   *  variants. Use the same id across renders to keep the sprite stable. */
  id: string
  type: PitNodeType
  /** CSS upscale factor. Default 3 for the preview page — bigger than
   *  the map's 2 so hover effects are easier to evaluate. */
  scale?: number
  /** When true, the hover effect fires immediately on mount instead of
   *  waiting for pointerenter. The preview page uses this so every
   *  island's effect is visible at a glance. */
  effectAlwaysOn?: boolean
  /** When set, forces a specific event sub-variant on the preview
   *  irrespective of the id hash. Use this from the demo page to
   *  reliably show e.g. the spring variant. */
  forceEventVariant?: 'plain' | 'spring'
}

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
  shop: 0xf0c040, // gold coins, not cyan
  rest: 0x9ae66e,
  cache: 0xd8cfb8,
  treasure: 0xf0c050, // radiant gold
}

/**
 * Standalone island renderer used by the /ilots preview page. Renders
 * exactly the same canvas sprite as `IslandNode` but decouples from the
 * run-state store (no hover dispatch, no commit, no chevron). Lets us
 * iterate on effect placement and pose variance in isolation.
 */
export function IslandPreview({
  id,
  type,
  scale = 3,
  effectAlwaysOn = true,
  forceEventVariant,
}: IslandPreviewProps) {
  const rootRef = useRef<HTMLDivElement | null>(null)
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const capZoneRef = useRef<HTMLDivElement | null>(null)
  const engine = useEffects()

  const signpost = useMemo(() => computeSignpostLayout(id), [id])
  const ground = useMemo(() => computeGroundArea(id), [id])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d', { alpha: true })
    if (!ctx) return
    ctx.imageSmoothingEnabled = false
    drawIsland(ctx, id, type, forceEventVariant)
  }, [id, type, forceEventVariant])

  useEffect(() => {
    if (!engine) return
    const root = rootRef.current
    const cap = capZoneRef.current
    if (!root || !cap) return

    // event-spring islands override the default sparkle with the
    // continuous water-flow effect.
    const eventVariant = forceEventVariant ?? computeEventVariant(id)
    const isSpring = type === 'event' && eventVariant === 'spring'
    const kind: AttachKind = isSpring ? 'spring' : TYPE_HOVER[type]
    const color = isSpring ? 0x6ec3d4 : TYPE_COLOR[type]
    let config: AttachConfig
    if (kind === 'grass') {
      config = { color, shape: 'patch', heightScale: 1, countScale: 8 }
    } else if (kind === 'spring') {
      // Pick the cascade side from the id hash so identical previews
      // stay deterministic. Bit 5 of the hash gives a 50/50 split.
      let h = 0
      for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) | 0
      const side: 'left' | 'right' = ((h >> 5) & 1) === 0 ? 'left' : 'right'
      config = { color, side }
    } else {
      config = { color }
    }
    // Spring attaches to the whole island root so its top sheet covers
    // the cap and its side stream can cascade past the bottom; every
    // other effect still anchors on the ground area (capZone) so
    // grass/embers/etc. only spawn on the placeable surface.
    const attachTarget = kind === 'spring' ? root : cap
    const { id: effectId, detach } = engine.attachWithHandle(attachTarget, kind, config)
    engine.setEnabled(effectId, effectAlwaysOn)

    // Always also react to hover so interactive toggling still works
    // when `effectAlwaysOn` is false — useful if we add an "effects only
    // on hover" switch to the preview page later.
    const onEnter = () => engine.setEnabled(effectId, true)
    const onLeave = () => engine.setEnabled(effectId, effectAlwaysOn)
    root.addEventListener('pointerenter', onEnter)
    root.addEventListener('pointerleave', onLeave)

    return () => {
      root.removeEventListener('pointerenter', onEnter)
      root.removeEventListener('pointerleave', onLeave)
      detach()
    }
  }, [engine, type, effectAlwaysOn])

  const w = ISLAND_W * scale
  const h = ISLAND_H * scale

  // capZone == ground area. Single source of truth for prop placement
  // AND effect spawn anchor (see computeGroundArea in drawIsland.ts).
  const capZoneTopCss = ground.top * scale
  const capZoneHeightCss = ground.height * scale
  const capZoneLeftCss = ground.left * scale
  const capZoneWidthCss = ground.width * scale

  // Plaque centre in CSS px for the glyph overlay.
  const plaqueLeftCss = (signpost.plaqueCenterX - signpost.plaqueW / 2) * scale
  const plaqueTopCss = (signpost.plaqueCenterY - signpost.plaqueH / 2) * scale
  const plaqueWCss = signpost.plaqueW * scale
  const plaqueHCss = signpost.plaqueH * scale
  const tiltDeg = (Math.atan(signpost.tiltRise) * 180) / Math.PI

  return (
    <div
      ref={rootRef}
      className={styles.island}
      data-type={type}
      data-island-id={id}
      style={{ width: `${w}px`, height: `${h}px` } as CSSProperties}
    >
      <canvas
        ref={canvasRef}
        className={styles.canvas}
        width={ISLAND_W}
        height={ISLAND_H}
        style={{ width: `${w}px`, height: `${h}px` }}
      />
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
      <span
        className={styles.glyph}
        style={{
          left: `${plaqueLeftCss}px`,
          top: `${plaqueTopCss}px`,
          width: `${plaqueWCss}px`,
          height: `${plaqueHCss}px`,
          transform: `rotate(${tiltDeg.toFixed(1)}deg)`,
          fontSize: `${Math.round(scale * 6)}px`,
        }}
      >
        {TYPE_GLYPH[type]}
      </span>
    </div>
  )
}
