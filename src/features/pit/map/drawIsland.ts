/**
 * Pixel-per-pixel renderer for a floating island. Draws to a 2D canvas
 * context at the island's native internal resolution; the parent scales
 * the canvas up via CSS `image-rendering: pixelated` to blow it back up
 * without smoothing.
 *
 * Rationale: CSS clip-path polygons were rendered with GPU anti-aliasing
 * and produced a lumpy-looking but not pixel-art result (the user's
 * feedback). Drawing pixel-by-pixel with a flat rect() per pixel gives
 * hard edges, intentional dithering, and a palette that matches the
 * game's terminal DNA.
 */

import type { PitNodeType } from '../../../game/pit/types'

/** Internal pixel dimensions of an island sprite. */
export const ISLAND_W = 36
export const ISLAND_H = 52
/** Vertical band above which the top cap lives. Stalactites dangle below. */
const CAP_HEIGHT = 28

export interface IslandPalette {
  outline: string
  shadow: string
  mid: string
  light: string
  rim: string
  stalactite: string
  stalactiteDeep: string
}

/**
 * Five-tone palettes per node type. Outline is always near-black so the
 * silhouette stays crisp against the ink background. The other four
 * tones climb from deep shadow to highlight rim; the rim is the shiny
 * one-pixel beacon at the top-left.
 */
export const TYPE_PALETTE: Record<PitNodeType, IslandPalette> = {
  combat: {
    outline: '#1e0606',
    shadow: '#4a1010',
    mid: '#8a2e2e',
    light: '#b84848',
    rim: '#d07878',
    stalactite: '#3a0e0e',
    stalactiteDeep: '#1a0606',
  },
  elite: {
    outline: '#1c1206',
    shadow: '#5a3e14',
    mid: '#a67a2c',
    light: '#c89a4a',
    rim: '#e8be72',
    stalactite: '#3a2808',
    stalactiteDeep: '#1c1404',
  },
  boss: {
    outline: '#0f0303',
    shadow: '#2a0808',
    mid: '#5a1818',
    light: '#7a2e2e',
    rim: '#9c4848',
    stalactite: '#200606',
    stalactiteDeep: '#0a0202',
  },
  event: {
    outline: '#120822',
    shadow: '#2e1d44',
    mid: '#503380',
    light: '#6e509e',
    rim: '#8e6ec0',
    stalactite: '#1f1236',
    stalactiteDeep: '#0b0718',
  },
  shop: {
    outline: '#08181c',
    shadow: '#154248',
    mid: '#357c86',
    light: '#509ea8',
    rim: '#72c0ca',
    stalactite: '#0f2a30',
    stalactiteDeep: '#061216',
  },
  rest: {
    outline: '#081406',
    shadow: '#173210',
    mid: '#447632',
    light: '#5e9c48',
    rim: '#82c068',
    stalactite: '#0f2208',
    stalactiteDeep: '#060e04',
  },
  cache: {
    outline: '#14130a',
    shadow: '#3a3626',
    mid: '#6b6452',
    light: '#8a8470',
    rim: '#aaa390',
    stalactite: '#26231a',
    stalactiteDeep: '#0e0d08',
  },
  treasure: {
    outline: '#201206',
    shadow: '#5a3a10',
    mid: '#b07624',
    light: '#d4944a',
    rim: '#f0ba70',
    stalactite: '#3a2410',
    stalactiteDeep: '#180e04',
  },
}

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
// Renderer
// ---------------------------------------------------------------------

/**
 * Fill a single 1×1 pixel. Wraps `rect(x, y, 1, 1)` so the calls read
 * as pixel plots rather than one-off draw commands.
 */
function plot(ctx: CanvasRenderingContext2D, x: number, y: number, color: string) {
  ctx.fillStyle = color
  ctx.fillRect(x | 0, y | 0, 1, 1)
}

/**
 * Render an island into `ctx`. The canvas must be sized exactly
 * `ISLAND_W × ISLAND_H`; callers should set `imageSmoothingEnabled =
 * false` before the first draw.
 */
export function drawIsland(
  ctx: CanvasRenderingContext2D,
  id: string,
  type: PitNodeType,
): void {
  const palette = TYPE_PALETTE[type]
  const rng = mulberry32(hashId(id))

  ctx.clearRect(0, 0, ISLAND_W, ISLAND_H)

  // Pre-compute a deformation offset per angular bucket so the cap's
  // radius wobbles smoothly around its circumference.
  const DEFORM_BUCKETS = 16
  const deform: number[] = []
  for (let i = 0; i < DEFORM_BUCKETS; i++) {
    deform.push(rng() * 2.4 - 1.2)
  }
  const baseRadius = ISLAND_W / 2 - 2
  const cx = ISLAND_W / 2
  const cy = CAP_HEIGHT / 2 + 2

  // --- 1) Top cap --------------------------------------------------
  for (let y = 0; y < CAP_HEIGHT + 4; y++) {
    for (let x = 0; x < ISLAND_W; x++) {
      const dx = x - cx + 0.5
      const dy = y - cy + 0.5
      const dist = Math.sqrt(dx * dx + dy * dy)
      // Pick the deformation bucket by angle.
      const angle = Math.atan2(dy, dx)
      const bucket =
        (Math.floor(((angle + Math.PI) / (Math.PI * 2)) * DEFORM_BUCKETS) +
          DEFORM_BUCKETS) %
        DEFORM_BUCKETS
      const r = baseRadius + deform[bucket]

      if (dist > r) continue

      // Determine shading: vertical gradient (top = light, bottom = shadow)
      // with a highlight bias toward the top-left quadrant.
      const vFactor = (y - (cy - r)) / (2 * r) // 0 at top, 1 at bottom
      const leftBias = dx < 0 ? 1 : 0

      let color: string
      if (dist >= r - 1) {
        color = palette.outline
      } else if (vFactor < 0.18 && leftBias) {
        color = palette.rim
      } else if (vFactor < 0.4) {
        color = palette.light
      } else if (vFactor < 0.72) {
        color = palette.mid
      } else {
        color = palette.shadow
      }

      // Dithered transitions: on the shadow/mid + mid/light boundaries,
      // scatter a checkerboard of the neighbouring tone so the gradient
      // reads as hand-placed pixels rather than CSS gradients.
      const checker = (x + y) % 2 === 0
      if (vFactor > 0.4 && vFactor < 0.48 && checker) color = palette.light
      else if (vFactor > 0.72 && vFactor < 0.8 && checker) color = palette.mid

      plot(ctx, x, y, color)
    }
  }

  // --- 2) A crisp outline band — replace any non-outline pixel that
  // touches transparent on one of its 4 sides with the outline colour.
  // Drawn after the cap so the dithered band doesn't leave gaps.
  const img = ctx.getImageData(0, 0, ISLAND_W, CAP_HEIGHT + 4)
  const data = img.data
  const cap_h = CAP_HEIGHT + 4
  const idx = (x: number, y: number) => (y * ISLAND_W + x) * 4
  const isTransparent = (x: number, y: number) =>
    x < 0 || y < 0 || x >= ISLAND_W || y >= cap_h || data[idx(x, y) + 3] === 0
  for (let y = 0; y < cap_h; y++) {
    for (let x = 0; x < ISLAND_W; x++) {
      if (data[idx(x, y) + 3] === 0) continue
      if (
        isTransparent(x - 1, y) ||
        isTransparent(x + 1, y) ||
        isTransparent(x, y - 1) ||
        isTransparent(x, y + 1)
      ) {
        plot(ctx, x, y, palette.outline)
      }
    }
  }

  // --- 3) Stalactites ---------------------------------------------
  const stalCount = 3 + Math.floor(rng() * 3) // 3..5
  const occupied: number[] = []
  for (let i = 0; i < stalCount; i++) {
    // Distribute across the cap's bottom, nudging toward centre.
    const laneStart = 6 + (i * (ISLAND_W - 12)) / stalCount
    const laneSpan = (ISLAND_W - 12) / stalCount
    const anchorX = Math.floor(laneStart + rng() * laneSpan)
    // Skip if too close to a previous stalactite.
    if (occupied.some((o) => Math.abs(o - anchorX) < 3)) continue
    occupied.push(anchorX)

    const width = 3 + Math.floor(rng() * 3) // 3..5 px
    // Centre-bias the height.
    const centerFactor = 1 - Math.abs(anchorX - cx) / (ISLAND_W / 2)
    const height = Math.floor(6 + centerFactor * 10 + rng() * 4) // 6..20 px
    const topY = CAP_HEIGHT - 1 + (rng() < 0.5 ? 0 : 1)

    drawStalactite(ctx, anchorX, topY, width, height, palette)
  }

  // --- 4) Drop shadow puddle under the whole island.
  // Placed right at the bottom of the canvas; rendered as a 2-pixel
  // dithered band so the island feels moored above it.
  const shadowY = ISLAND_H - 3
  for (let x = 4; x < ISLAND_W - 4; x++) {
    const spread = (ISLAND_W - 8) / 2
    const off = Math.abs(x - cx) / spread // 0 centre, 1 edge
    if (off > 0.95) continue
    const edgeChecker = off > 0.7 && (x + shadowY) % 2 === 1
    if (edgeChecker) continue
    plot(ctx, x, shadowY, '#000000')
    if (off < 0.5) plot(ctx, x, shadowY + 1, '#000000')
  }
}

function drawStalactite(
  ctx: CanvasRenderingContext2D,
  anchorX: number,
  topY: number,
  width: number,
  height: number,
  palette: IslandPalette,
): void {
  // Trapezoid that narrows toward the bottom. At each row y, the
  // effective width shrinks by `narrow` from the top.
  for (let dy = 0; dy < height; dy++) {
    const y = topY + dy
    if (y >= ISLAND_H) break
    const progress = dy / (height - 1 || 1)
    // Width shrinks non-linearly so the tip is a single pixel.
    const shrink = Math.min(width - 1, Math.floor(progress * width))
    const thisW = Math.max(1, width - shrink)
    const startX = anchorX - Math.floor(thisW / 2)
    for (let dx = 0; dx < thisW; dx++) {
      const x = startX + dx
      if (x < 0 || x >= ISLAND_W) continue
      // Left edge + tip = outline, right edge = deep shadow, middle = stalactite.
      let color: string
      if (dx === 0 || dy === height - 1) color = palette.outline
      else if (dx === thisW - 1) color = palette.stalactiteDeep
      else color = palette.stalactite
      plot(ctx, x, y, color)
    }
  }
}
