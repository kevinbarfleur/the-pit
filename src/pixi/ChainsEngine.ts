import { Application, Container, Graphics } from 'pixi.js'

/**
 * Dedicated Pixi layer for the pixel-art chains that link the Pit's
 * floating islands. Kept separate from `EffectsEngine`:
 *   - Chains have their own simulation (per-segment pendulum swing).
 *   - They must freeze during zoom transitions without also freezing
 *     button hover effects (and vice versa).
 *   - Their asset pool sizing is different (max ~60 chains vs 320
 *     particles).
 *
 * The engine is declarative: consumers call `syncChains(specs)` each
 * frame with the desired set of chains, keyed by id. The engine pools
 * entities and only allocates graphics lazily.
 */

// --------------------- public API types ---------------------

export type ChainState = 'traversed' | 'active' | 'latent' | 'bypassed'

export interface ChainSpec {
  /** Stable id, e.g. `${fromNodeId}->${toNodeId}`. */
  id: string
  /** Viewport-space anchor of the chain's top end. */
  fromX: number
  fromY: number
  /** Viewport-space anchor of the chain's bottom end. */
  toX: number
  toY: number
  state: ChainState
}

// --------------------- palette ---------------------

const CHAIN_COLOR: Record<ChainState, { dark: number; light: number; alpha: number }> = {
  traversed: { dark: 0x8a6a28, light: 0xd4a147, alpha: 0.92 },
  active: { dark: 0x9c9482, light: 0xe5dec6, alpha: 0.85 },
  latent: { dark: 0x5a5448, light: 0x8a8370, alpha: 0.72 },
  bypassed: { dark: 0x2a2a2a, light: 0x444444, alpha: 0.55 },
}

const SWING_AMPLITUDE_PX: Record<ChainState, number> = {
  traversed: 0.6, // taut: almost no sway
  active: 1.4,
  latent: 2.2,
  bypassed: 3.0, // frayed, leans a lot
}

const POOL_SIZE = 128
/** Approximate px distance along the chain between maillons. */
const MAILLON_SPACING = 9

// --------------------- internal ---------------------

interface ChainEntity {
  id: string
  g: Graphics
  // Last-known target anchors — lerped toward by current each frame so
  // islands bobbing doesn't snap the chain.
  fromX: number
  fromY: number
  toX: number
  toY: number
  curFromX: number
  curFromY: number
  curToX: number
  curToY: number
  state: ChainState
  /** Phase offset per-chain so adjacent chains don't sway in unison. */
  phase: number
  swingTime: number
  inUse: boolean
}

// --------------------- engine ---------------------

export class ChainsEngine {
  private app: Application
  private container: HTMLElement
  private layer = new Container()
  private entities: ChainEntity[] = []
  private byId = new Map<string, ChainEntity>()
  private ready = false
  private disposed = false

  constructor(container: HTMLElement) {
    this.container = container
    this.app = new Application()
  }

  async init(): Promise<void> {
    if (this.ready) return
    await this.app.init({
      resizeTo: window,
      backgroundAlpha: 0,
      antialias: false,
      autoStart: true,
    })
    if (this.disposed) {
      this.app.destroy(true, { children: true })
      return
    }

    const canvas = this.app.canvas
    canvas.style.position = 'fixed'
    canvas.style.inset = '0'
    canvas.style.pointerEvents = 'none'
    // Below the EffectsEngine canvas (zIndex 900) but above the DOM map,
    // so chains draw on top of the shaft background but under sparks.
    canvas.style.zIndex = '800'
    canvas.style.imageRendering = 'pixelated'
    this.container.appendChild(canvas)

    this.app.stage.addChild(this.layer)

    // Pre-allocate entities; they're marked `inUse=false` until claimed.
    for (let i = 0; i < POOL_SIZE; i++) {
      const g = new Graphics()
      g.visible = false
      this.layer.addChild(g)
      this.entities.push({
        id: '',
        g,
        fromX: 0,
        fromY: 0,
        toX: 0,
        toY: 0,
        curFromX: 0,
        curFromY: 0,
        curToX: 0,
        curToY: 0,
        state: 'latent',
        phase: 0,
        swingTime: 0,
        inUse: false,
      })
    }

    this.app.ticker.add((ticker) => {
      const dt = Math.min(ticker.deltaMS / 1000, 0.1)
      this.tick(dt)
    })

    this.ready = true
  }

  dispose(): void {
    this.disposed = true
    if (this.ready) {
      this.app.destroy(true, { children: true })
    }
  }

  /** Pause the ticker. Mirror of `EffectsEngine.pauseTicker()`. */
  pauseTicker(): void {
    if (this.ready) this.app.ticker.stop()
  }

  resumeTicker(): void {
    if (this.ready) this.app.ticker.start()
  }

  /**
   * Declarative sync: supply the chains the UI wants alive this frame.
   * Entities present last frame but absent this frame are released to
   * the pool (their Graphics get hidden). New ids claim a free slot.
   */
  syncChains(specs: ChainSpec[]): void {
    if (!this.ready) return
    const nextIds = new Set<string>()
    for (const spec of specs) {
      nextIds.add(spec.id)
      let e: ChainEntity | null | undefined = this.byId.get(spec.id)
      if (!e) {
        e = this.claim(spec.id)
        if (!e) continue // pool full
        // Seed current positions to avoid a snap-in from (0,0).
        e.curFromX = spec.fromX
        e.curFromY = spec.fromY
        e.curToX = spec.toX
        e.curToY = spec.toY
      }
      e.fromX = spec.fromX
      e.fromY = spec.fromY
      e.toX = spec.toX
      e.toY = spec.toY
      e.state = spec.state
    }
    // Release old chains not in the new spec list.
    for (const e of this.entities) {
      if (!e.inUse) continue
      if (nextIds.has(e.id)) continue
      this.release(e)
    }
  }

  // ----- internal -----

  private claim(id: string): ChainEntity | null {
    const e = this.entities.find((x) => !x.inUse)
    if (!e) return null
    e.id = id
    e.inUse = true
    e.phase = (hashIdToUnit(id) * Math.PI * 2) | 0
    e.swingTime = hashIdToUnit(id + '#t') * 10
    e.g.visible = true
    this.byId.set(id, e)
    return e
  }

  private release(e: ChainEntity): void {
    e.inUse = false
    e.g.visible = false
    e.g.clear()
    this.byId.delete(e.id)
    e.id = ''
  }

  private tick(dt: number): void {
    for (const e of this.entities) {
      if (!e.inUse) continue

      // Lerp current anchors toward target — 14× dt feels snappy without
      // popping when islands bob a couple of pixels.
      const k = Math.min(1, dt * 14)
      e.curFromX += (e.fromX - e.curFromX) * k
      e.curFromY += (e.fromY - e.curFromY) * k
      e.curToX += (e.toX - e.curToX) * k
      e.curToY += (e.toY - e.curToY) * k

      e.swingTime += dt
      this.renderChain(e)
    }
  }

  private renderChain(e: ChainEntity): void {
    const g = e.g
    g.clear()

    const dx = e.curToX - e.curFromX
    const dy = e.curToY - e.curFromY
    const length = Math.sqrt(dx * dx + dy * dy)
    if (length < 2) return

    // Perpendicular unit vector for swing offsets.
    const perpX = -dy / length
    const perpY = dx / length

    const palette = CHAIN_COLOR[e.state]
    const amp = SWING_AMPLITUDE_PX[e.state]
    // Primary sway: single-pendulum sine with max at midpoint.
    const sway = Math.sin(e.swingTime * 1.4 + e.phase) * amp

    // Segment count — always odd so there's a clean midpoint maillon.
    let segmentCount = Math.max(3, Math.round(length / MAILLON_SPACING))
    if (segmentCount % 2 === 0) segmentCount += 1

    for (let i = 0; i < segmentCount; i++) {
      const t = i / (segmentCount - 1)
      // Cap the swing at the midpoint and taper to 0 at both ends —
      // anchors are glued to the islands, rope bulges in between.
      const taper = Math.sin(t * Math.PI)
      const offset = sway * taper
      const x = e.curFromX + dx * t + perpX * offset
      const y = e.curFromY + dy * t + perpY * offset

      // Alternate orientation: even indices vertical, odd horizontal.
      // That's the defining "chain" silhouette — two linked rings, one
      // on its side, one upright.
      const vertical = i % 2 === 0
      drawMaillon(g, x, y, vertical, palette.dark, palette.light, palette.alpha)
    }
  }
}

// --------------------- helpers ---------------------

function hashIdToUnit(id: string): number {
  let h = 0x811c9dc5
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i)
    h = Math.imul(h, 0x01000193)
  }
  return ((h >>> 8) & 0xffffff) / 0x1000000
}

/**
 * Draw a single chain link (maillon). A 5×7 or 7×5 pixel shape: a ring
 * drawn as a dark outer rectangle with a 1-px lighter highlight on one
 * edge, centred on (x, y).
 */
function drawMaillon(
  g: Graphics,
  x: number,
  y: number,
  vertical: boolean,
  dark: number,
  light: number,
  alpha: number,
): void {
  const w = vertical ? 5 : 7
  const h = vertical ? 7 : 5
  const halfW = w / 2
  const halfH = h / 2
  const cx = Math.round(x)
  const cy = Math.round(y)

  // Outer body
  g.rect(cx - halfW, cy - halfH, w, h)
  g.fill({ color: dark, alpha })
  // Inner hole — one-pixel hollow so it reads as a ring rather than a
  // solid block. Draw a transparent-ish inner cutout via a darker fill
  // (doesn't break the flat z-order since the same Graphics is used).
  g.rect(cx - halfW + 1, cy - halfH + 1, w - 2, h - 2)
  g.fill({ color: 0x000000, alpha: 0.55 })
  // Highlight on the upper-left edge — one pixel of light to sell the
  // metallic sheen.
  g.rect(cx - halfW, cy - halfH, 1, 1)
  g.fill({ color: light, alpha: Math.min(1, alpha + 0.05) })
  g.rect(cx - halfW + 1, cy - halfH, 1, 1)
  g.fill({ color: light, alpha: Math.min(1, alpha + 0.05) })
}
