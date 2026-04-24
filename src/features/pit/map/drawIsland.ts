/**
 * Pixel-per-pixel renderer for a floating island.
 *
 * Composition (bottom-up):
 *   - Stalactites that dangle from the cap's underside.
 *   - The stone cap itself — an irregular disc in a neutral rock palette.
 *   - A little **stake** planted into the cap's top.
 *   - A **plaque** on the stake, tinted by the node type — this is the
 *     piece that communicates what's on the island (combat / shop /
 *     boss / …). The glyph sits on the plaque.
 *
 * Rationale: colouring the whole island by type made it hard to read as
 * a piece of floating earth. Stone stays stone; the activity shows up
 * on a sign post stuck in it, the way you'd flag a campsite on a map.
 * Future: palette varies by biome — for now the stone swaps between
 * four subtly different grey tones picked by the id hash.
 */

import type { PitNodeType } from '../../../game/pit/types'

/** Internal pixel dimensions. */
export const ISLAND_W = 36
export const ISLAND_H = 56

/** Native-pixel bands of the composition, measured from the canvas top. */
const PLAQUE_Y_TOP = 0
const PLAQUE_Y_BOTTOM = 5
const STAKE_Y_TOP = 5
const STAKE_Y_BOTTOM = 9
const CAP_Y_TOP = 9
const CAP_Y_BOTTOM = 34
/** CSS y-offset (in upscaled pixels, scale 2) of the chain's top anchor. */
export const CAP_TOP_ANCHOR_CSS = CAP_Y_TOP * 2 + 2
/** CSS y-offset of the chain's bottom anchor — glued to the cap's base,
 *  *before* the stalactites, so chains look tied to the body of the
 *  rock rather than to its broken dangling edges. */
export const CAP_BOTTOM_ANCHOR_CSS = CAP_Y_BOTTOM * 2 - 2

// ---------------------------------------------------------------------
// Stone palettes — the island body.
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
  // Cool grey — the default, close to ink
  {
    outline: '#0f0f10',
    shadow: '#2e2e30',
    mid: '#585858',
    light: '#7e7e80',
    rim: '#a2a2a4',
    stalactite: '#1b1b1c',
    stalactiteDeep: '#080808',
  },
  // Warm stone
  {
    outline: '#100d08',
    shadow: '#302820',
    mid: '#5c5446',
    light: '#837864',
    rim: '#a89a80',
    stalactite: '#1e1812',
    stalactiteDeep: '#0a0806',
  },
  // Slate — bluish
  {
    outline: '#0c0e12',
    shadow: '#262c33',
    mid: '#4c5460',
    light: '#707a86',
    rim: '#98a2ae',
    stalactite: '#161a1e',
    stalactiteDeep: '#080a0c',
  },
  // Bone — pale earth
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
// Plaque palettes — the sign post on top.
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

/** Wood colour for the stake — same for every island. */
const STAKE_COLOR = '#2c1e0c'
const STAKE_HIGHLIGHT = '#4a3418'

// ---------------------------------------------------------------------
// Stable pseudo-random (duplicated from generate.ts on purpose — keeps
// this module dependency-free on the hot path).
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
// Primitives
// ---------------------------------------------------------------------

function plot(ctx: CanvasRenderingContext2D, x: number, y: number, color: string) {
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
  const rng = mulberry32(hashId(id))

  // Rotate through stone palettes deterministically. Stays in-bounds
  // and produces visible-but-subtle tonal variety across the map.
  const stone = STONE_PALETTES[hashId(id) % STONE_PALETTES.length]
  const plaque = PLAQUE_PALETTE[type]

  drawCapAndStalactites(ctx, rng, stone)
  drawStake(ctx)
  drawPlaque(ctx, plaque)
  drawShadow(ctx)
}

// ---------- cap + stalactites ----------

function drawCapAndStalactites(
  ctx: CanvasRenderingContext2D,
  rng: () => number,
  stone: StonePalette,
): void {
  const DEFORM_BUCKETS = 16
  const deform: number[] = []
  for (let i = 0; i < DEFORM_BUCKETS; i++) deform.push(rng() * 2.2 - 1.1)

  const capH = CAP_Y_BOTTOM - CAP_Y_TOP
  const baseRadius = ISLAND_W / 2 - 2
  const cx = ISLAND_W / 2
  const cy = CAP_Y_TOP + capH / 2

  // --- cap body ---
  for (let y = CAP_Y_TOP; y < CAP_Y_BOTTOM + 2; y++) {
    for (let x = 0; x < ISLAND_W; x++) {
      const dx = x - cx + 0.5
      const dy = y - cy + 0.5
      const dist = Math.sqrt(dx * dx + dy * dy)
      const angle = Math.atan2(dy, dx)
      const bucket =
        (Math.floor(((angle + Math.PI) / (Math.PI * 2)) * DEFORM_BUCKETS) +
          DEFORM_BUCKETS) %
        DEFORM_BUCKETS
      const r = baseRadius + deform[bucket]
      if (dist > r) continue

      const vFactor = (y - (cy - r)) / (2 * r)
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

  // Outline sweep — any non-outline pixel adjacent to transparent gets
  // the outline tone. Keeps the silhouette crisp after the dithering.
  const img = ctx.getImageData(0, CAP_Y_TOP, ISLAND_W, capH + 4)
  const data = img.data
  const slabH = capH + 4
  const idxAt = (x: number, y: number) => (y * ISLAND_W + x) * 4
  const empty = (x: number, y: number) =>
    x < 0 || y < 0 || x >= ISLAND_W || y >= slabH || data[idxAt(x, y) + 3] === 0
  for (let y = 0; y < slabH; y++) {
    for (let x = 0; x < ISLAND_W; x++) {
      if (data[idxAt(x, y) + 3] === 0) continue
      if (empty(x - 1, y) || empty(x + 1, y) || empty(x, y - 1) || empty(x, y + 1)) {
        plot(ctx, x, CAP_Y_TOP + y, stone.outline)
      }
    }
  }

  // --- stalactites ---
  const count = 3 + Math.floor(rng() * 3)
  const placed: number[] = []
  for (let i = 0; i < count; i++) {
    const laneStart = 6 + (i * (ISLAND_W - 12)) / count
    const laneSpan = (ISLAND_W - 12) / count
    const anchorX = Math.floor(laneStart + rng() * laneSpan)
    if (placed.some((p) => Math.abs(p - anchorX) < 3)) continue
    placed.push(anchorX)

    const width = 3 + Math.floor(rng() * 3)
    const centerFactor = 1 - Math.abs(anchorX - cx) / (ISLAND_W / 2)
    const height = Math.floor(6 + centerFactor * 10 + rng() * 4)
    const topY = CAP_Y_BOTTOM - 1 + (rng() < 0.5 ? 0 : 1)
    drawStalactite(ctx, anchorX, topY, width, height, stone)
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

// ---------- stake ----------

function drawStake(ctx: CanvasRenderingContext2D): void {
  const cx = ISLAND_W / 2
  // 2 px wide stake, 4 px tall, centred, with a 1-px highlight down the
  // left edge so it reads as a round wooden post rather than a flat rect.
  for (let y = STAKE_Y_TOP; y < STAKE_Y_BOTTOM; y++) {
    plot(ctx, cx - 1, y, STAKE_HIGHLIGHT)
    plot(ctx, cx, y, STAKE_COLOR)
  }
}

// ---------- plaque ----------

function drawPlaque(ctx: CanvasRenderingContext2D, plaque: PlaquePalette): void {
  // 12×5 rectangle centred horizontally, anchored to the top of the
  // canvas. Outline on every edge, rim on the top edge as a highlight,
  // face colour fills the interior.
  const w = 12
  const h = PLAQUE_Y_BOTTOM - PLAQUE_Y_TOP
  const x0 = Math.floor((ISLAND_W - w) / 2)
  const y0 = PLAQUE_Y_TOP
  for (let dy = 0; dy < h; dy++) {
    for (let dx = 0; dx < w; dx++) {
      const x = x0 + dx
      const y = y0 + dy
      let color: string
      if (dx === 0 || dx === w - 1 || dy === h - 1) color = plaque.outline
      else if (dy === 0) color = plaque.rim
      else color = plaque.face
      plot(ctx, x, y, color)
    }
  }
  // Two small "nails" — outline dots on the top-left and top-right of
  // the face, selling the attached-to-the-stake feel.
  plot(ctx, x0 + 2, y0 + 1, plaque.outline)
  plot(ctx, x0 + w - 3, y0 + 1, plaque.outline)
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
