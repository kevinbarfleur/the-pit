/**
 * Pixel-per-pixel renderer for a floating stone island.
 *
 * Each island is a combination of four orthogonal variants — cap
 * shape, stalactite pattern, signpost pose, and stone palette — all
 * picked deterministically from the node id. Combined with the
 * per-id deformation rng, this produces 256+ visibly distinct
 * silhouettes across the map.
 *
 * The signpost (stake + plaque) is drawn in the canvas too, with
 * pixel-perfect tilt. The glyph that identifies the node type is
 * rendered as an HTML overlay positioned by `computeSignpostLayout`
 * (so it follows every pose variant without re-drawing the font).
 */

import type { PitNodeType } from '../../../game/pit/types'

/** Internal pixel dimensions. */
export const ISLAND_W = 36
export const ISLAND_H = 56

/** Layout bands (native px, from the canvas top). */
const CAP_Y_TOP_BASE = 10
const CAP_Y_BOTTOM_BASE = 34
/** CSS y-offset (at scale 2) of the chain top anchor. */
export const CAP_TOP_ANCHOR_CSS = CAP_Y_TOP_BASE * 2 + 2
/** CSS y-offset of the chain bottom anchor — glued to the cap's base
 *  (before the stalactites) so chains tie into the body of the rock. */
export const CAP_BOTTOM_ANCHOR_CSS = CAP_Y_BOTTOM_BASE * 2 - 2

// ---------------------------------------------------------------------
// Stone palettes
// ---------------------------------------------------------------------

interface StonePalette {
  outline: string
  shadow: string
  mid: string
  light: string
  rim: string
  stalactite: string
  stalactiteDeep: string
}

const STONE_PALETTES: StonePalette[] = [
  {
    outline: '#0f0f10',
    shadow: '#2e2e30',
    mid: '#585858',
    light: '#7e7e80',
    rim: '#a2a2a4',
    stalactite: '#1b1b1c',
    stalactiteDeep: '#080808',
  },
  {
    outline: '#100d08',
    shadow: '#302820',
    mid: '#5c5446',
    light: '#837864',
    rim: '#a89a80',
    stalactite: '#1e1812',
    stalactiteDeep: '#0a0806',
  },
  {
    outline: '#0c0e12',
    shadow: '#262c33',
    mid: '#4c5460',
    light: '#707a86',
    rim: '#98a2ae',
    stalactite: '#161a1e',
    stalactiteDeep: '#080a0c',
  },
  {
    outline: '#14120a',
    shadow: '#363024',
    mid: '#665e4e',
    light: '#8c8470',
    rim: '#b0a88e',
    stalactite: '#201c10',
    stalactiteDeep: '#0c0a06',
  },
]

// ---------------------------------------------------------------------
// Plaque palettes (the only type-coloured piece)
// ---------------------------------------------------------------------

interface PlaquePalette {
  outline: string
  face: string
  rim: string
}

const PLAQUE_PALETTE: Record<PitNodeType, PlaquePalette> = {
  combat: { outline: '#2a0808', face: '#a03030', rim: '#e87878' },
  elite: { outline: '#281808', face: '#a87a24', rim: '#e4b858' },
  boss: { outline: '#1a0606', face: '#6a1e1e', rim: '#aa4848' },
  event: { outline: '#1a0a2c', face: '#5a3d8a', rim: '#a078c8' },
  shop: { outline: '#0a222a', face: '#3a808c', rim: '#78c0c8' },
  rest: { outline: '#0a1e08', face: '#4a7832', rim: '#8cc068' },
  cache: { outline: '#1a1810', face: '#6a6454', rim: '#a09888' },
  treasure: { outline: '#281808', face: '#b07a28', rim: '#f0b868' },
}

const STAKE_COLOR = '#2c1e0c'
const STAKE_HIGHLIGHT = '#4a3418'

// ---------------------------------------------------------------------
// Stable pseudo-random
// ---------------------------------------------------------------------

function hashId(id: string): number {
  let h = 0x811c9dc5
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i)
    h = Math.imul(h, 0x01000193)
  }
  return h >>> 0
}

function mulberry32(seed: number) {
  let s = seed >>> 0
  return () => {
    s = (s + 0x6d2b79f5) >>> 0
    let t = s
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 0x100000000
  }
}

// ---------------------------------------------------------------------
// Variant selection — 4 orthogonal dimensions, picked from the hash so
// that two islands with the same node id always render identically.
// ---------------------------------------------------------------------

type CapVariant = 'round' | 'flat' | 'tall' | 'lumpy'
type StalVariant = 'spread' | 'cluster' | 'asym' | 'sparse'
type SignVariant = 'straight' | 'leanLeft' | 'leanRight' | 'pressed'

interface Variants {
  cap: CapVariant
  stal: StalVariant
  sign: SignVariant
  paletteIdx: number
}

function pickVariants(hash: number): Variants {
  const caps: CapVariant[] = ['round', 'flat', 'tall', 'lumpy']
  const stals: StalVariant[] = ['spread', 'cluster', 'asym', 'sparse']
  const signs: SignVariant[] = ['straight', 'leanLeft', 'leanRight', 'pressed']
  return {
    paletteIdx: hash & 0b11,
    cap: caps[(hash >> 4) & 0b11],
    stal: stals[(hash >> 8) & 0b11],
    sign: signs[(hash >> 12) & 0b11],
  }
}

// ---------------------------------------------------------------------
// Signpost layout — exposed to consumers so the HTML glyph and chevron
// overlays can line up with the canvas pixels.
// ---------------------------------------------------------------------

export interface SignpostLayout {
  /** Plaque centre in native pixels. */
  plaqueCenterX: number
  plaqueCenterY: number
  /** Plaque dimensions in native pixels. */
  plaqueW: number
  plaqueH: number
  /** Tilt in rows per row (pixels of horizontal shift per pixel of
   *  vertical descent). 0 = straight; positive = leans right. */
  tiltRise: number
}

export function computeSignpostLayout(id: string): SignpostLayout {
  const variants = pickVariants(hashId(id))
  return signpostLayoutForVariant(variants.sign)
}

function signpostLayoutForVariant(variant: SignVariant): SignpostLayout {
  switch (variant) {
    case 'straight':
      return { plaqueCenterX: 18, plaqueCenterY: 5, plaqueW: 12, plaqueH: 5, tiltRise: 0 }
    case 'leanLeft':
      return { plaqueCenterX: 16, plaqueCenterY: 6, plaqueW: 12, plaqueH: 5, tiltRise: -0.25 }
    case 'leanRight':
      return { plaqueCenterX: 20, plaqueCenterY: 6, plaqueW: 12, plaqueH: 5, tiltRise: 0.25 }
    case 'pressed':
      // Sits lower on the cap, slightly bigger plaque — reads as the sign
      // post being pounded deeper in.
      return { plaqueCenterX: 18, plaqueCenterY: 8, plaqueW: 13, plaqueH: 6, tiltRise: 0 }
  }
}

// ---------------------------------------------------------------------
// Primitives
// ---------------------------------------------------------------------

function plot(ctx: CanvasRenderingContext2D, x: number, y: number, color: string) {
  if (x < 0 || x >= ISLAND_W || y < 0 || y >= ISLAND_H) return
  ctx.fillStyle = color
  ctx.fillRect(x | 0, y | 0, 1, 1)
}

// ---------------------------------------------------------------------
// Renderer
// ---------------------------------------------------------------------

export function drawIsland(
  ctx: CanvasRenderingContext2D,
  id: string,
  type: PitNodeType,
): void {
  ctx.clearRect(0, 0, ISLAND_W, ISLAND_H)
  const hash = hashId(id)
  const rng = mulberry32(hash)
  const variants = pickVariants(hash)
  const stone = STONE_PALETTES[variants.paletteIdx]
  const plaque = PLAQUE_PALETTE[type]

  drawCapAndStalactites(ctx, rng, stone, variants.cap, variants.stal)
  drawSignpost(ctx, variants.sign, plaque)
  drawShadow(ctx)
}

// ---------- cap + stalactites ----------

function capGeometry(variant: CapVariant): {
  radiusBase: number
  aspect: number
  deformAmp: number
  yOffset: number
} {
  switch (variant) {
    case 'round':
      return { radiusBase: ISLAND_W / 2 - 2, aspect: 1, deformAmp: 1.1, yOffset: 0 }
    case 'flat':
      return { radiusBase: ISLAND_W / 2 - 2, aspect: 0.82, deformAmp: 0.9, yOffset: 1 }
    case 'tall':
      return { radiusBase: ISLAND_W / 2 - 4, aspect: 1.25, deformAmp: 1.3, yOffset: -1 }
    case 'lumpy':
      return { radiusBase: ISLAND_W / 2 - 3, aspect: 1.05, deformAmp: 2.2, yOffset: 0 }
  }
}

function drawCapAndStalactites(
  ctx: CanvasRenderingContext2D,
  rng: () => number,
  stone: StonePalette,
  capVariant: CapVariant,
  stalVariant: StalVariant,
): void {
  const geom = capGeometry(capVariant)
  const DEFORM_BUCKETS = 16
  const deform: number[] = []
  for (let i = 0; i < DEFORM_BUCKETS; i++) deform.push((rng() * 2 - 1) * geom.deformAmp)

  const capTop = CAP_Y_TOP_BASE + geom.yOffset
  const capBottom = CAP_Y_BOTTOM_BASE + geom.yOffset
  const capH = capBottom - capTop
  const cx = ISLAND_W / 2
  const cy = capTop + capH / 2

  for (let y = capTop; y < capBottom + 2; y++) {
    for (let x = 0; x < ISLAND_W; x++) {
      const dx = x - cx + 0.5
      const dyRaw = y - cy + 0.5
      const dy = dyRaw / geom.aspect
      const dist = Math.sqrt(dx * dx + dy * dy)
      const angle = Math.atan2(dyRaw, dx)
      const bucket =
        (Math.floor(((angle + Math.PI) / (Math.PI * 2)) * DEFORM_BUCKETS) +
          DEFORM_BUCKETS) %
        DEFORM_BUCKETS
      const r = geom.radiusBase + deform[bucket]
      if (dist > r) continue

      const vFactor = (y - (cy - r * geom.aspect)) / (2 * r * geom.aspect)
      const leftBias = dx < 0
      let color: string
      if (dist >= r - 1) {
        color = stone.outline
      } else if (vFactor < 0.16 && leftBias) {
        color = stone.rim
      } else if (vFactor < 0.38) {
        color = stone.light
      } else if (vFactor < 0.72) {
        color = stone.mid
      } else {
        color = stone.shadow
      }

      const checker = (x + y) % 2 === 0
      if (vFactor > 0.38 && vFactor < 0.46 && checker) color = stone.light
      else if (vFactor > 0.72 && vFactor < 0.8 && checker) color = stone.mid

      plot(ctx, x, y, color)
    }
  }

  // Outline sweep
  const outlineSliceY = capTop
  const outlineSliceH = Math.min(ISLAND_H - outlineSliceY, capH + 4)
  const img = ctx.getImageData(0, outlineSliceY, ISLAND_W, outlineSliceH)
  const data = img.data
  const idxAt = (x: number, y: number) => (y * ISLAND_W + x) * 4
  const empty = (x: number, y: number) =>
    x < 0 || y < 0 || x >= ISLAND_W || y >= outlineSliceH || data[idxAt(x, y) + 3] === 0
  for (let y = 0; y < outlineSliceH; y++) {
    for (let x = 0; x < ISLAND_W; x++) {
      if (data[idxAt(x, y) + 3] === 0) continue
      if (empty(x - 1, y) || empty(x + 1, y) || empty(x, y - 1) || empty(x, y + 1)) {
        plot(ctx, x, outlineSliceY + y, stone.outline)
      }
    }
  }

  drawStalactites(ctx, rng, stone, stalVariant, capBottom)
}

function drawStalactites(
  ctx: CanvasRenderingContext2D,
  rng: () => number,
  stone: StonePalette,
  variant: StalVariant,
  capBottom: number,
): void {
  interface Spec {
    x: number
    w: number
    h: number
  }
  const specs: Spec[] = []
  switch (variant) {
    case 'spread': {
      const count = 4 + Math.floor(rng() * 2)
      for (let i = 0; i < count; i++) {
        const laneStart = 5 + (i * (ISLAND_W - 10)) / count
        const laneSpan = (ISLAND_W - 10) / count
        const x = Math.floor(laneStart + rng() * laneSpan)
        const centerFactor = 1 - Math.abs(x - ISLAND_W / 2) / (ISLAND_W / 2)
        specs.push({
          x,
          w: 3 + Math.floor(rng() * 2),
          h: 6 + Math.floor(centerFactor * 8 + rng() * 4),
        })
      }
      break
    }
    case 'cluster': {
      const cx = ISLAND_W / 2 + Math.floor(rng() * 3 - 1)
      specs.push({ x: cx, w: 5, h: 14 + Math.floor(rng() * 4) })
      specs.push({ x: cx - 4 + Math.floor(rng() * 2), w: 3, h: 6 + Math.floor(rng() * 3) })
      specs.push({ x: cx + 4 - Math.floor(rng() * 2), w: 3, h: 6 + Math.floor(rng() * 3) })
      break
    }
    case 'asym': {
      const side = rng() < 0.5 ? -1 : 1
      const count = 3 + Math.floor(rng() * 2)
      const base = ISLAND_W / 2 + side * 4
      for (let i = 0; i < count; i++) {
        const x = Math.floor(base + side * i * 3 + (rng() * 2 - 1))
        specs.push({
          x,
          w: 3 + Math.floor(rng() * 2),
          h: 6 + Math.floor(rng() * 7) + (i === 0 ? 4 : 0),
        })
      }
      break
    }
    case 'sparse': {
      specs.push({
        x: ISLAND_W / 2 - 4 + Math.floor(rng() * 3),
        w: 3,
        h: 4 + Math.floor(rng() * 4),
      })
      specs.push({
        x: ISLAND_W / 2 + 4 - Math.floor(rng() * 3),
        w: 3,
        h: 4 + Math.floor(rng() * 4),
      })
      break
    }
  }
  for (const s of specs) {
    if (s.x < 2 || s.x > ISLAND_W - 2) continue
    drawStalactite(ctx, s.x, capBottom - 1, s.w, s.h, stone)
  }
}

function drawStalactite(
  ctx: CanvasRenderingContext2D,
  anchorX: number,
  topY: number,
  width: number,
  height: number,
  stone: StonePalette,
): void {
  for (let dy = 0; dy < height; dy++) {
    const y = topY + dy
    if (y >= ISLAND_H) break
    const progress = dy / (height - 1 || 1)
    const shrink = Math.min(width - 1, Math.floor(progress * width))
    const thisW = Math.max(1, width - shrink)
    const startX = anchorX - Math.floor(thisW / 2)
    for (let dx = 0; dx < thisW; dx++) {
      const x = startX + dx
      if (x < 0 || x >= ISLAND_W) continue
      let color: string
      if (dx === 0 || dy === height - 1) color = stone.outline
      else if (dx === thisW - 1) color = stone.stalactiteDeep
      else color = stone.stalactite
      plot(ctx, x, y, color)
    }
  }
}

// ---------- signpost ----------

function drawSignpost(
  ctx: CanvasRenderingContext2D,
  variant: SignVariant,
  plaque: PlaquePalette,
): void {
  const layout = signpostLayoutForVariant(variant)
  const { plaqueCenterX, plaqueCenterY, plaqueW, plaqueH, tiltRise } = layout

  // Stake: from just below the plaque down into the cap, tilt-aligned.
  const stakeTopY = plaqueCenterY + Math.floor(plaqueH / 2)
  const stakeBottomY = stakeTopY + 5
  for (let y = stakeTopY; y < stakeBottomY; y++) {
    const rowFromPlaque = y - plaqueCenterY
    const offsetX = Math.round(rowFromPlaque * tiltRise)
    plot(ctx, plaqueCenterX - 1 + offsetX, y, STAKE_HIGHLIGHT)
    plot(ctx, plaqueCenterX + offsetX, y, STAKE_COLOR)
  }

  // Plaque: rectangle with tilt per-row.
  const halfW = Math.floor(plaqueW / 2)
  for (let dy = 0; dy < plaqueH; dy++) {
    const rowOffsetX = Math.round((dy - plaqueH / 2 + 0.5) * tiltRise)
    for (let dx = 0; dx < plaqueW; dx++) {
      const x = plaqueCenterX - halfW + dx + rowOffsetX
      const y = plaqueCenterY - Math.floor(plaqueH / 2) + dy
      let color: string
      if (dx === 0 || dx === plaqueW - 1 || dy === plaqueH - 1) color = plaque.outline
      else if (dy === 0) color = plaque.rim
      else color = plaque.face
      plot(ctx, x, y, color)
    }
  }
  // Two nails on the face.
  const nailY = plaqueCenterY - Math.floor(plaqueH / 2) + 1
  const nailRowOffset = Math.round((1 - plaqueH / 2 + 0.5) * tiltRise)
  plot(ctx, plaqueCenterX - halfW + 2 + nailRowOffset, nailY, plaque.outline)
  plot(ctx, plaqueCenterX + halfW - 3 + nailRowOffset, nailY, plaque.outline)
}

// ---------- drop shadow ----------

function drawShadow(ctx: CanvasRenderingContext2D): void {
  const cx = ISLAND_W / 2
  const shadowY = ISLAND_H - 2
  for (let x = 4; x < ISLAND_W - 4; x++) {
    const off = Math.abs(x - cx) / (ISLAND_W / 2 - 4)
    if (off > 0.95) continue
    if (off > 0.65 && (x + shadowY) % 2 === 1) continue
    plot(ctx, x, shadowY, '#000000')
    if (off < 0.45) plot(ctx, x, shadowY + 1, '#000000')
  }
}
