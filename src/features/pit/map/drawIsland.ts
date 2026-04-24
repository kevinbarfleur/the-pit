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

interface Variants {
  cap: CapVariant
  stal: StalVariant
  paletteIdx: number
}

function pickVariants(hash: number): Variants {
  const caps: CapVariant[] = ['round', 'flat', 'tall', 'lumpy']
  const stals: StalVariant[] = ['spread', 'cluster', 'asym', 'sparse']
  return {
    paletteIdx: hash & 0b11,
    cap: caps[(hash >> 4) & 0b11],
    stal: stals[(hash >> 8) & 0b11],
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

/**
 * Continuous signpost layout. Replaces the old 4-bucket variant picker
 * with values derived directly from the node id hash — so tilt, x
 * offset, and y depth all vary across a wide band rather than snapping
 * to four fixed poses. Each piece of the layout samples its own byte
 * of the hash so the three axes are effectively independent.
 *
 *   tiltRise ∈ [-0.4, 0.4)   — px of horizontal shift per row
 *   xJitter  ∈ [-3, 3]       — px offset from the centre
 *   yBase    ∈ [5, 8]        — higher = sits deeper on the cap
 *   plaqueW  ∈ {11, 12, 13}  — slight width variety
 */
export function computeSignpostLayout(id: string): SignpostLayout {
  const hash = hashId(id)
  const tiltUnit = ((hash >> 4) & 0xff) / 256
  const tiltRise = tiltUnit * 0.8 - 0.4
  const xJitter = ((hash >> 12) & 0x07) - 3
  const yBase = 5 + ((hash >> 16) & 0x03)
  const plaqueW = 11 + (((hash >> 20) & 0x03) % 3)
  const plaqueH = 5 + (((hash >> 24) & 0x03) === 0 ? 1 : 0) // occasional taller plaque
  return {
    plaqueCenterX: 18 + xJitter,
    plaqueCenterY: yBase,
    plaqueW,
    plaqueH,
    tiltRise,
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
  const signpost = computeSignpostLayout(id)

  drawCapAndStalactites(ctx, rng, stone, variants.cap, variants.stal)
  drawSignpost(ctx, signpost, plaque)
  // Treasure islands get a whole mini hoard: two small chests flanking
  // a centre pile of coins. All sit on the cap's visible surface below
  // the signpost. The godray hover effect anchors on the bounding box
  // of this hoard so the wash of light feels emitted from the treasure
  // itself.
  if (type === 'treasure') {
    const hoard = treasureHoardLayout()
    drawTreasureChest(ctx, hoard.leftChestX, hoard.rowY)
    drawTreasureChest(ctx, hoard.rightChestX, hoard.rowY)
    drawCoinStack(ctx, hoard.stackX, hoard.stackY)
  }
  if (type === 'shop') {
    const spot = computeIslandSpot(id, 'shop')!
    drawCoinStack(ctx, spot.x, spot.y)
  }
  drawShadow(ctx)
}

/** Static layout of the treasure hoard. Two 7×5 chests and one 6×4
 *  coin stack, packed tightly as one compact mound right under the
 *  signpost. The coin stack sits in front (lower) and the chests
 *  flank it slightly offset upward — reads as a little pile of loot
 *  rather than three separate objects spread across the cap. */
function treasureHoardLayout(): {
  leftChestX: number
  rightChestX: number
  rowY: number
  stackX: number
  stackY: number
} {
  return {
    leftChestX: 14,
    rightChestX: 22,
    rowY: 22,
    stackX: 18,
    stackY: 27,
  }
}

/**
 * Position of the pixel-art "spot" a few islands carry on top of their
 * cap: the treasure chest and the shop coin-stack. Exposed so the
 * React layer can anchor a hover effect exactly on top of it — the
 * hover aura then reads as emanating from the chest / stack rather
 * than from the centre of the island.
 *
 * Returns native-pixel coordinates of the centre of the spot and its
 * dimensions. Callers scale these by the island's CSS SCALE.
 */
export function computeIslandSpot(
  id: string,
  type: PitNodeType,
): { x: number; y: number; w: number; h: number } | null {
  if (type === 'treasure') {
    // Bounding rect of the whole compact mound. Used by godray as
    // its anchor so the halo wraps the pile rather than floating
    // somewhere else on the cap.
    const h = treasureHoardLayout()
    const left = h.leftChestX - 4
    const right = h.rightChestX + 4
    const top = h.rowY - 3
    const bottom = h.stackY + 3
    return {
      x: (left + right) / 2,
      y: (top + bottom) / 2,
      w: right - left,
      h: bottom - top,
    }
  }
  if (type === 'shop') {
    const hash = hashId(id)
    const signpost = computeSignpostLayout(id)
    const onRight = ((hash >> 28) & 1) === 0
    const side = onRight ? 1 : -1
    const cx = Math.round(signpost.plaqueCenterX + side * (signpost.plaqueW / 2 + 3))
    const top = Math.round(signpost.plaqueCenterY + signpost.plaqueH / 2 + 2)
    const W = 6
    const H = 4
    return { x: cx, y: top + Math.floor(H / 2), w: W, h: H }
  }
  return null
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
  // Before drawing, clamp every stalactite so its full width fits within
  // the cap's actual silhouette at its base. The spec positions don't
  // know about the rock's deformation — a stalactite placed at x=31
  // would render fine if the cap were a rectangle but pokes out into
  // empty space when the cap narrows there. We probe a pixel row just
  // above the bottom edge to get the real silhouette span, then either
  // shift the stalactite inward until it fits or drop it.
  const probeY = capBottom - 2
  const row =
    probeY >= 0 && probeY < ISLAND_H
      ? ctx.getImageData(0, probeY, ISLAND_W, 1).data
      : null
  const xIsOpaque = (x: number): boolean => {
    if (!row) return true
    if (x < 0 || x >= ISLAND_W) return false
    return row[x * 4 + 3] > 0
  }
  const fits = (x: number, w: number): boolean => {
    const half = Math.floor(w / 2)
    for (let dx = -half; dx <= half; dx++) {
      if (!xIsOpaque(x + dx)) return false
    }
    return true
  }

  for (const s of specs) {
    if (s.x < 2 || s.x > ISLAND_W - 2) continue
    let x = s.x
    if (!fits(x, s.w)) {
      // Try nudging inward / outward by up to 4 px.
      let placed = false
      for (let offset = 1; offset <= 4 && !placed; offset++) {
        if (fits(x - offset, s.w)) {
          x = x - offset
          placed = true
        } else if (fits(x + offset, s.w)) {
          x = x + offset
          placed = true
        }
      }
      if (!placed) continue
    }
    drawStalactite(ctx, x, capBottom - 1, s.w, s.h, stone)
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
  layout: SignpostLayout,
  plaque: PlaquePalette,
): void {
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

// ---------- treasure chest ----------

/**
 * A tiny pixel-art chest, 7×5 native, planted next to the signpost on
 * the cap's visible top surface. Palette is a warm wood body with a
 * gold strap + lock so it reads unambiguously as loot even at small
 * sizes.
 */
/**
 * Treasure chest, 7×5 native. Full-detail variant used on the
 * treasure hoard — wood body + gold lid strap + keyhole + corner pips.
 */
function drawTreasureChest(ctx: CanvasRenderingContext2D, spotX: number, spotY: number): void {
  const W = 7
  const H = 5
  const x0 = spotX - Math.floor(W / 2)
  const top = spotY - Math.floor(H / 2)
  if (x0 < 1 || x0 + W > ISLAND_W - 1) return
  if (top + H > ISLAND_H - 2) return

  const OUTLINE = '#1e1206'
  const WOOD_DARK = '#4a2810'
  const WOOD_MID = '#6a3c18'
  const WOOD_LIGHT = '#8a5624'
  const GOLD_DARK = '#8a6020'
  const GOLD_MID = '#d4a040'
  const GOLD_LIGHT = '#f4d078'

  for (let dy = 0; dy < H; dy++) {
    for (let dx = 0; dx < W; dx++) {
      const x = x0 + dx
      const y = top + dy
      if (x < 0 || x >= ISLAND_W || y < 0 || y >= ISLAND_H) continue

      let color: string
      const onSideEdge = dx === 0 || dx === W - 1
      const onTopEdge = dy === 0
      const onBotEdge = dy === H - 1
      if (onSideEdge || onTopEdge || onBotEdge) {
        color = OUTLINE
      } else if (dy === 1) {
        color = dx === 1 ? WOOD_DARK : WOOD_LIGHT
      } else if (dy === 2) {
        const isLock = dx === Math.floor(W / 2)
        if (isLock) color = GOLD_DARK
        else color = dx === 1 ? GOLD_DARK : dx === W - 2 ? GOLD_DARK : GOLD_MID
      } else {
        color = dx === 1 ? WOOD_DARK : WOOD_MID
      }
      plot(ctx, x, y, color)
    }
  }
  // Keyhole + gold highlight pips.
  plot(ctx, x0 + Math.floor(W / 2), top + 2, OUTLINE)
  plot(ctx, x0 + 1, top + 2, GOLD_LIGHT)
  plot(ctx, x0 + W - 2, top + 2, GOLD_LIGHT)
}

// ---------- coin stack (shop) ----------

/**
 * A tiny stack of gold coins, 6×4 native, planted next to the sign
 * post on shop islands. Reads unambiguously as "stuff for sale" even
 * before the hover coin-rain kicks in. Shape is a 3-tier stepped
 * pyramid of coins — thin stacks are more legible at this size than
 * tall ones.
 */
function drawCoinStack(ctx: CanvasRenderingContext2D, spotX: number, spotY: number): void {
  const W = 6
  const H = 4
  const x0 = spotX - Math.floor(W / 2)
  const top = spotY - Math.floor(H / 2)
  if (x0 < 1 || x0 + W > ISLAND_W - 1) return
  if (top + H > ISLAND_H - 2) return

  const OUTLINE = '#2a1808'
  const GOLD_DARK = '#8a5a14'
  const GOLD_MID = '#d4a040'
  const GOLD_LIGHT = '#f8e088'

  // Row 0: the topmost coin — 2 wide centred
  // Row 1: 4 wide coin
  // Row 2: 6 wide base coin
  // Row 3: bottom outline + shadow under the stack
  const rows: Array<{ offX: number; w: number }> = [
    { offX: 2, w: 2 }, // top coin
    { offX: 1, w: 4 }, // middle coin
    { offX: 0, w: 6 }, // base coin
  ]

  for (let i = 0; i < rows.length; i++) {
    const { offX, w } = rows[i]
    const y = top + i
    for (let dx = 0; dx < w; dx++) {
      const x = x0 + offX + dx
      let color: string
      if (dx === 0 || dx === w - 1) color = OUTLINE
      else if (dx === 1) color = GOLD_LIGHT
      else if (dx === w - 2) color = GOLD_DARK
      else color = GOLD_MID
      plot(ctx, x, y, color)
    }
  }

  // Bottom outline for the base coin + shadow pip beneath.
  for (let dx = 0; dx < W; dx++) {
    plot(ctx, x0 + dx, top + 3, OUTLINE)
  }
  // Optional specular sparkle on the middle coin.
  plot(ctx, x0 + 2, top + 1, '#ffffff')
}
