import { useEffect, useRef } from 'react'
import styles from './DepthGauge.module.css'

interface DepthGaugeProps {
  currentDepth: number
  minDepth: number
  maxDepth: number
  cameraOffset: number
  rowHeight: number
}

/**
 * Depth indicator. Sits **inside the shaft as an overlay** — same
 * area as the islands. A continuous vertical chain falls just left
 * of the leftmost island lane, with a wooden sign hanging in front
 * of every island row carrying that row's number. Reuses the same
 * maillon silhouette and time-driven sway as `ChainsEngine` so the
 * gauge feels like part of the same world.
 *
 * Pixel-art at 3× CSS scale: every native PA pixel is rendered as a
 * `PIXEL_SIZE × PIXEL_SIZE` block, matching the island upscale so
 * chain links read at the same chunk size as the islands.
 */

const PIXEL_SIZE = 3 // matches IslandNode SCALE — 1 native px → 3 CSS px

// Geometry — kept in lockstep with NodeMap.tsx (lane 0 at 32 %) and
// IslandNode (ISLAND_W * SCALE = 36 * 3 = 108 → half = 54).
const ISLAND_LANE_0_PCT = 0.32
const ISLAND_HALF_W_CSS = 54
const ISLAND_GAP_CSS = 36

// Pixel-art constants in PA units; CSS = PA × PIXEL_SIZE.
const MAILLON_PA_SPACING = 5
const MAILLON_PA_W_V = 5
const MAILLON_PA_H_V = 6
const SIGN_PA_W = 22
const SIGN_PA_H = 9
const SIGN_OFFSET_PA = 3

const STEP_CSS = MAILLON_PA_SPACING * PIXEL_SIZE
const SIGN_CSS_W = SIGN_PA_W * PIXEL_SIZE
const SIGN_CSS_H = SIGN_PA_H * PIXEL_SIZE
const SIGN_OFFSET_CSS = SIGN_OFFSET_PA * PIXEL_SIZE

/**
 * Sway is a sum of three sine waves with very different temporal and
 * spatial frequencies. The result reads as a long pendulum disturbance
 * (slow primary), a draft from the depths (medium), and a fine quiver
 * (fast). Spatial frequency on each component makes the wave **travel**
 * down the chain instead of the whole chain flapping in lockstep — that
 * was the "trop calculé" feel before.
 */
const SWAY_W1 = 1.05 // slow temporal freq
const SWAY_K1 = 0.011 // slow spatial freq (per CSS px)
const SWAY_A1 = 1.4 // PA px
const SWAY_W2 = 2.6
const SWAY_K2 = 0.029
const SWAY_A2 = 0.55
const SWAY_PHASE2 = 1.7
const SWAY_W3 = 5.7
const SWAY_K3 = 0.073
const SWAY_A3 = 0.25
const SWAY_PHASE3 = 0.4

const CHAIN_PALETTE = {
  outline: '#0a0a0a',
  core: '#2a2a2a',
  rim: '#3c3c3c',
  shadow: '#141414',
  alpha: 0.9,
}

interface SignPalette {
  body: string
  outline: string
  highlight: string
  shadow: string
  grain: string
  text: string
  ropeOutline: string
  ropeRim: string
}

const SIGN_PALETTE: SignPalette = {
  body: '#6e4a25',
  outline: '#2a1808',
  highlight: '#9a6e3a',
  shadow: '#3a2613',
  grain: '#5a3a1d',
  text: '#1a0e08',
  ropeOutline: '#0a0a0a',
  ropeRim: '#3c3c3c',
}

const SIGN_PALETTE_CURRENT: SignPalette = {
  body: '#8a5a25',
  outline: '#2a1808',
  highlight: '#c08840',
  shadow: '#4a2e13',
  grain: '#6a3a1d',
  text: '#f0d480',
  ropeOutline: '#0a0a0a',
  ropeRim: '#3c3c3c',
}

export function DepthGauge({
  currentDepth,
  cameraOffset,
  rowHeight,
}: DepthGaugeProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const cameraOffsetRef = useRef(cameraOffset)
  cameraOffsetRef.current = cameraOffset
  const currentDepthRef = useRef(currentDepth)
  currentDepthRef.current = currentDepth
  const rowHeightRef = useRef(rowHeight)
  rowHeightRef.current = rowHeight

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d', { alpha: true })
    if (!ctx) return

    let dpr = Math.min(window.devicePixelRatio || 1, 2)
    let cssW = 0
    let cssH = 0

    const resize = () => {
      const rect = canvas.getBoundingClientRect()
      dpr = Math.min(window.devicePixelRatio || 1, 2)
      cssW = rect.width
      cssH = rect.height
      canvas.width = Math.max(1, Math.round(cssW * dpr))
      canvas.height = Math.max(1, Math.round(cssH * dpr))
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      ctx.imageSmoothingEnabled = false
    }
    resize()
    const ro = new ResizeObserver(resize)
    ro.observe(canvas)
    if (canvas.parentElement) ro.observe(canvas.parentElement)

    let raf = 0
    const start = performance.now()
    const tick = () => {
      const time = (performance.now() - start) / 1000
      ctx.clearRect(0, 0, cssW, cssH)

      if (cssW > 0 && cssH > 0) {
        const offset = cameraOffsetRef.current
        const rh = rowHeightRef.current
        const cd = currentDepthRef.current
        const chainX = computeChainX(cssW)

        drawChain(ctx, cssH, offset, time, chainX)
        drawSigns(ctx, cssH, offset, rh, cd, time, chainX)
      }

      raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)

    return () => {
      cancelAnimationFrame(raf)
      ro.disconnect()
    }
  }, [])

  return (
    <aside className={styles.gauge} aria-label="depth gauge" data-pit-chrome>
      <canvas ref={canvasRef} className={styles.canvas} />
    </aside>
  )
}

// ---------- chain ----------

/**
 * Compute the chain's resting x in canvas coordinates so the wooden
 * sign always tucks just left of the leftmost island (lane 0 at 32 %).
 * Falls back to a small left margin on extremely narrow viewports.
 */
function computeChainX(canvasWidth: number): number {
  const lane0 = ISLAND_LANE_0_PCT * canvasWidth
  const islandLeftEdge = lane0 - ISLAND_HALF_W_CSS
  const signRight = islandLeftEdge - ISLAND_GAP_CSS
  const signLeft = signRight - SIGN_CSS_W
  const chainX = signLeft - SIGN_OFFSET_CSS
  return Math.max(15, chainX)
}

/**
 * Sway sample for a given y in viewport CSS px. Anchored to depth-space
 * (subtracts cameraOffset) so the travelling wave is bound to the
 * physical chain, not the screen.
 */
function swayAt(y: number, time: number, offset: number): number {
  const dy = y - offset
  const w1 = Math.sin(time * SWAY_W1 + dy * SWAY_K1) * SWAY_A1
  const w2 = Math.sin(time * SWAY_W2 + dy * SWAY_K2 + SWAY_PHASE2) * SWAY_A2
  const w3 = Math.sin(time * SWAY_W3 + dy * SWAY_K3 + SWAY_PHASE3) * SWAY_A3
  return (w1 + w2 + w3) * PIXEL_SIZE
}

function drawChain(
  ctx: CanvasRenderingContext2D,
  h: number,
  offset: number,
  time: number,
  chainX: number,
): void {
  const iStart = Math.floor(-offset / STEP_CSS) - 2
  const iEnd = Math.ceil((h - offset) / STEP_CSS) + 2
  for (let i = iStart; i <= iEnd; i++) {
    const y = i * STEP_CSS + offset
    if (y < -30 || y > h + 30) continue
    const sway = swayAt(y, time, offset)
    const vertical = i % 2 === 0
    drawMaillon(ctx, chainX + sway, y, vertical)
  }
}

/**
 * 5×6 vertical / 6×5 horizontal pixel-art ring drawn as PIXEL_SIZE
 * blocks. Layout mirrors `ChainsEngine.drawMaillon` so the gauge
 * chain reads as the same material as the inter-island chains.
 */
function drawMaillon(
  ctx: CanvasRenderingContext2D,
  cssX: number,
  cssY: number,
  vertical: boolean,
): void {
  const paW = vertical ? MAILLON_PA_W_V : MAILLON_PA_H_V
  const paH = vertical ? MAILLON_PA_H_V : MAILLON_PA_W_V
  const snapX = Math.round(cssX / PIXEL_SIZE) * PIXEL_SIZE
  const snapY = Math.round(cssY / PIXEL_SIZE) * PIXEL_SIZE
  const x0 = snapX - Math.floor(paW / 2) * PIXEL_SIZE
  const y0 = snapY - Math.floor(paH / 2) * PIXEL_SIZE

  ctx.globalAlpha = CHAIN_PALETTE.alpha
  const px = (dx: number, dy: number, color: string) => {
    ctx.fillStyle = color
    ctx.fillRect(x0 + dx * PIXEL_SIZE, y0 + dy * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE)
  }

  if (vertical) {
    px(1, 0, CHAIN_PALETTE.rim)
    px(2, 0, CHAIN_PALETTE.rim)
    px(3, 0, CHAIN_PALETTE.rim)
    px(0, 1, CHAIN_PALETTE.outline)
    px(4, 1, CHAIN_PALETTE.outline)
    px(0, 4, CHAIN_PALETTE.outline)
    px(4, 4, CHAIN_PALETTE.outline)
    px(0, 2, CHAIN_PALETTE.core)
    px(0, 3, CHAIN_PALETTE.core)
    px(4, 2, CHAIN_PALETTE.shadow)
    px(4, 3, CHAIN_PALETTE.shadow)
    px(1, 5, CHAIN_PALETTE.shadow)
    px(2, 5, CHAIN_PALETTE.shadow)
    px(3, 5, CHAIN_PALETTE.shadow)
  } else {
    px(0, 1, CHAIN_PALETTE.rim)
    px(0, 2, CHAIN_PALETTE.rim)
    px(0, 3, CHAIN_PALETTE.rim)
    px(1, 0, CHAIN_PALETTE.outline)
    px(1, 4, CHAIN_PALETTE.outline)
    px(4, 0, CHAIN_PALETTE.outline)
    px(4, 4, CHAIN_PALETTE.outline)
    px(2, 0, CHAIN_PALETTE.core)
    px(3, 0, CHAIN_PALETTE.core)
    px(2, 4, CHAIN_PALETTE.shadow)
    px(3, 4, CHAIN_PALETTE.shadow)
    px(5, 1, CHAIN_PALETTE.shadow)
    px(5, 2, CHAIN_PALETTE.shadow)
    px(5, 3, CHAIN_PALETTE.shadow)
  }
  ctx.globalAlpha = 1
}

// ---------- signs ----------

function drawSigns(
  ctx: CanvasRenderingContext2D,
  h: number,
  offset: number,
  rowHeight: number,
  currentDepth: number,
  time: number,
  chainX: number,
): void {
  const dStart = Math.floor(-offset / rowHeight) - 1
  const dEnd = Math.ceil((h - offset) / rowHeight) + 1
  for (let d = dStart; d <= dEnd; d++) {
    if (d < 0) continue
    const y = d * rowHeight + offset + rowHeight / 2
    if (y < -SIGN_CSS_H || y > h + SIGN_CSS_H) continue
    const sway = swayAt(y, time, offset)
    drawSign(ctx, chainX + sway, y, d, d === currentDepth)
  }
}

/**
 * Wooden plate hung off the chain on its right-hand side. Anchored at
 * (anchorX, anchorY); anchor is the chain attachment point — the sign
 * extends right and is centred vertically on the row.
 */
function drawSign(
  ctx: CanvasRenderingContext2D,
  anchorX: number,
  anchorY: number,
  depth: number,
  isCurrent: boolean,
): void {
  const palette = isCurrent ? SIGN_PALETTE_CURRENT : SIGN_PALETTE
  const left = Math.round((anchorX + SIGN_OFFSET_CSS) / PIXEL_SIZE) * PIXEL_SIZE
  const top = Math.round((anchorY - SIGN_CSS_H / 2) / PIXEL_SIZE) * PIXEL_SIZE
  const w = SIGN_CSS_W
  const h = SIGN_CSS_H
  const P = PIXEL_SIZE

  // Connector — short pixel-art beam from chain right edge to sign left.
  const beamStartX = Math.round(anchorX / P) * P + 2 * P
  const beamY = Math.round(anchorY / P) * P
  const beamEndX = left
  const beamLen = beamEndX - beamStartX
  if (beamLen > 0) {
    ctx.fillStyle = palette.ropeOutline
    ctx.fillRect(beamStartX, beamY - P, beamLen, P)
    ctx.fillRect(beamStartX, beamY + P, beamLen, P)
    ctx.fillStyle = palette.ropeRim
    ctx.fillRect(beamStartX, beamY, beamLen, P)
  }

  // Wood body.
  ctx.fillStyle = palette.body
  ctx.fillRect(left, top, w, h)

  // Outline.
  ctx.fillStyle = palette.outline
  ctx.fillRect(left, top, w, P)
  ctx.fillRect(left, top + h - P, w, P)
  ctx.fillRect(left, top, P, h)
  ctx.fillRect(left + w - P, top, P, h)

  // Highlight (top + left inner).
  ctx.fillStyle = palette.highlight
  ctx.fillRect(left + P, top + P, w - 2 * P, P)
  ctx.fillRect(left + P, top + P, P, h - 2 * P)

  // Shadow (bottom + right inner).
  ctx.fillStyle = palette.shadow
  ctx.fillRect(left + P, top + h - 2 * P, w - 2 * P, P)
  ctx.fillRect(left + w - 2 * P, top + P, P, h - 2 * P)

  // Grain — single horizontal streak across the middle.
  ctx.fillStyle = palette.grain
  ctx.fillRect(left + 3 * P, top + 4 * P, w - 6 * P, P)

  // Nail heads in the four corners.
  ctx.fillStyle = palette.outline
  ctx.fillRect(left + 2 * P, top + 2 * P, P, P)
  ctx.fillRect(left + w - 3 * P, top + 2 * P, P, P)
  ctx.fillRect(left + 2 * P, top + h - 3 * P, P, P)
  ctx.fillRect(left + w - 3 * P, top + h - 3 * P, P, P)

  // Depth label — VT323 reads as crisp pixel-art at this size.
  ctx.fillStyle = palette.text
  ctx.font = '20px "VT323", ui-monospace, monospace'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillText(
    `D${String(depth).padStart(3, '0')}`,
    left + w / 2,
    top + h / 2 + 1,
  )
}
