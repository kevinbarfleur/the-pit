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

/**
 * Per-state palette. Each state gets four tones so a maillon reads as
 * a proper pixel-art ring: outline, core fill, rim highlight, and
 * recessed shadow.
 */
interface ChainPalette {
  outline: number
  core: number
  rim: number
  shadow: number
  alpha: number
}

const CHAIN_COLOR: Record<ChainState, ChainPalette> = {
  traversed: {
    outline: 0x1e1608,
    core: 0x8a6828,
    rim: 0xe4c070,
    shadow: 0x4a3614,
    alpha: 0.95,
  },
  active: {
    outline: 0x1a1a14,
    core: 0xa09880,
    rim: 0xe8e2c8,
    shadow: 0x5a5448,
    alpha: 0.92,
  },
  latent: {
    outline: 0x141410,
    core: 0x6a6456,
    rim: 0x9a9380,
    shadow: 0x3a362a,
    alpha: 0.82,
  },
  bypassed: {
    outline: 0x0a0a0a,
    core: 0x3a3a3a,
    rim: 0x565656,
    shadow: 0x1e1e1e,
    alpha: 0.55,
  },
}

const SWING_AMPLITUDE_PX: Record<ChainState, number> = {
  traversed: 0.3, // taut gild chain — almost no sway
  active: 0.8,
  latent: 1.4,
  bypassed: 2.2, // frayed, leans a lot
}

const POOL_SIZE = 128
/** Px along the chain between consecutive maillons. Tight so they
 *  interlock visually rather than reading as dotted beads. */
const MAILLON_SPACING = 5
const MAILLON_W_V = 5
const MAILLON_H_V = 6

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
    // `absolute` instead of `fixed` so the canvas can be layered inside
    // a DOM stacking context controlled by the consumer (e.g. the Pit
    // scene's chains-host div). The host is itself positioned to cover
    // the viewport, so the rendered area matches `resizeTo: window`.
    canvas.style.position = 'absolute'
    canvas.style.inset = '0'
    canvas.style.pointerEvents = 'none'
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
    const sway = Math.sin(e.swingTime * 1.4 + e.phase) * amp

    // Always odd for a clean midpoint maillon.
    let segmentCount = Math.max(3, Math.round(length / MAILLON_SPACING))
    if (segmentCount % 2 === 0) segmentCount += 1

    for (let i = 0; i < segmentCount; i++) {
      const t = i / (segmentCount - 1)
      const taper = Math.sin(t * Math.PI)
      const offset = sway * taper
      const x = e.curFromX + dx * t + perpX * offset
      const y = e.curFromY + dy * t + perpY * offset
      // Alternate vertical/horizontal — the defining silhouette of a
      // chain: every other ring is on its side.
      const vertical = i % 2 === 0
      drawMaillon(g, x, y, vertical, palette)
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
 * Draw a single chain link (maillon) as a pixel-art ring centred on
 * (x, y). Each maillon is plotted pixel-by-pixel via 1×1 rects so the
 * shape reads as a discrete metal ring rather than a smudged blob.
 *
 * Vertical orientation (5×6):
 *   . X X X .
 *   X . . . X
 *   X . . . X
 *   X . . . X
 *   X . . . X
 *   . X X X .
 * where the top-row pixels get the `rim` highlight, the left column
 * gets `core`, the right + bottom get `shadow`, and the outer corners
 * fall on `outline`.
 *
 * Horizontal orientation is the 90° transpose (6×5).
 */
function drawMaillon(
  g: Graphics,
  x: number,
  y: number,
  vertical: boolean,
  palette: ChainPalette,
): void {
  const w = vertical ? MAILLON_W_V : MAILLON_H_V
  const h = vertical ? MAILLON_H_V : MAILLON_W_V
  const cx = Math.round(x) - Math.floor(w / 2)
  const cy = Math.round(y) - Math.floor(h / 2)

  const px = (dx: number, dy: number, color: number) => {
    g.rect(cx + dx, cy + dy, 1, 1)
    g.fill({ color, alpha: palette.alpha })
  }

  if (vertical) {
    // Top rim — bright highlight
    px(1, 0, palette.rim)
    px(2, 0, palette.rim)
    px(3, 0, palette.rim)
    // Outer corners (outline)
    px(0, 1, palette.outline)
    px(4, 1, palette.outline)
    px(0, 4, palette.outline)
    px(4, 4, palette.outline)
    // Left wall — core
    px(0, 2, palette.core)
    px(0, 3, palette.core)
    // Right wall — shadow
    px(4, 2, palette.shadow)
    px(4, 3, palette.shadow)
    // Bottom rim — shadow
    px(1, 5, palette.shadow)
    px(2, 5, palette.shadow)
    px(3, 5, palette.shadow)
  } else {
    // Horizontal (rotated 90°)
    // Top rim (left column when rotated)
    px(0, 1, palette.rim)
    px(0, 2, palette.rim)
    px(0, 3, palette.rim)
    // Outer corners
    px(1, 0, palette.outline)
    px(1, 4, palette.outline)
    px(4, 0, palette.outline)
    px(4, 4, palette.outline)
    // Top wall — core
    px(2, 0, palette.core)
    px(3, 0, palette.core)
    // Bottom wall — shadow
    px(2, 4, palette.shadow)
    px(3, 4, palette.shadow)
    // Right rim — shadow
    px(5, 1, palette.shadow)
    px(5, 2, palette.shadow)
    px(5, 3, palette.shadow)
  }
}
