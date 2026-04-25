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
  /**
   * Optional slack ratio (> 1). When set, the chain is simulated with
   * Verlet integration: a string of point masses linked by distance
   * constraints, with both endpoints pinned to (fromX/Y) and (toX/Y).
   * `slack` controls the rope's resting length:
   *
   *   1.0   = taut (no sag)
   *   1.15  = 15 % longer than the chord — gentle catenary curve
   *   1.30  = 30 % longer — pronounced droop
   *
   * Gravity pulls the unpinned nodes downward (+Y screen) and the
   * relaxation pass keeps adjacent nodes at a fixed segment length.
   * Result: a physically plausible catenary that hangs correctly
   * regardless of the anchors' relative height — the canonical
   * approach for 2D rope/chain simulation in games (Worms, Cut the
   * Rope, etc.). When omitted or ≤ 1, the engine falls back to its
   * default lateral pendulum sway used by the pit's vertical chains.
   */
  slack?: number
  /**
   * Per-chain multiplier on the engine's gravity (default 1). Values
   * < 1 keep the chain closer to its analytical equilibrium sag —
   * useful when a chain's anchor geometry exposes the simulator's
   * inherent overshoot. 0 = no gravity at all (chain freezes at its
   * init pose, still reactive to pointer impulses).
   */
  gravityScale?: number
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

/**
 * Single neutral palette used for every state. We're keeping all
 * chains visually uniform for now — discreet dark grey, just enough
 * relief to read as a metal ring without competing with the islands.
 * State-driven recolouring will come back once the design is settled.
 */
const NEUTRAL_PALETTE: ChainPalette = {
  outline: 0x0a0a0a,
  core: 0x2a2a2a,
  rim: 0x3c3c3c,
  shadow: 0x141414,
  alpha: 0.85,
}

const CHAIN_COLOR: Record<ChainState, ChainPalette> = {
  traversed: NEUTRAL_PALETTE,
  active: NEUTRAL_PALETTE,
  latent: NEUTRAL_PALETTE,
  bypassed: NEUTRAL_PALETTE,
}

const SWING_AMPLITUDE_PX: Record<ChainState, number> = {
  traversed: 1.0,
  active: 1.0,
  latent: 1.0,
  bypassed: 1.0,
}

// ----- Verlet rope tuning -----
//
// Standard 2D-rope parameters drawn from common game-dev references
// (Verlet rope simulation tutorials by toqoz.fyi, cedarcantab, etc.):
//
//   - Gravity: tuned in pixels/second². Real-world g (~980 cm/s²) is
//     too gentle for screen distances; ~1600 reads as a metal chain.
//   - Damping: ≈ 0.985 — drains residual oscillation after a few
//     swings without making the rope feel sluggish.
//   - Iterations: 12 — enough relaxation passes that segments stay
//     visibly equal-length on a 30-50 node chain.
//   - Init sag: a 10 % parabolic sag at allocation time so the rope
//     drops into place gracefully instead of snapping from a straight
//     chord on the first frame.
// Gravity dropped from 1600 → 600 px/s²: with such a small slack (~ 1 %)
// the chain has very little vertical room to fall, and a strong gravity
// keeps overshooting the analytical equilibrium each frame, which reads
// as a permanently bigger sag than the maths predict. 600 px/s² gives
// the simulator time to converge cleanly inside the constraint passes.
const VERLET_GRAVITY_PX_S2 = 600
const VERLET_DAMPING = 0.985
const VERLET_ITERATIONS = 12
const MIN_NODES = 4
// When `setPointer` accumulates a delta, only impulses involving a
// real change (> 0.5px since the last consumed delta) reach the
// simulation. Tiny mouse jitter on a stationary cursor doesn't keep
// nudging the rope.

// Pointer interaction. We DON'T apply a static repulsive force from
// the cursor's position — that reads as the user dragging the chain
// around, which the design rejects. Instead, we react only to the
// *delta* (velocity) of the cursor between frames: when the cursor
// moves, nodes within `POINTER_RADIUS` are nudged in the same
// direction, scaled by `POINTER_GAIN` and a linear distance falloff.
// The resulting feel is a localised gust of air — the chain reacts to
// motion passing through it, but ignores a stationary cursor.
const POINTER_RADIUS = 60
const POINTER_GAIN = 0.15

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
  // Verlet-rope state. Populated when `slack > 1`; otherwise the
  // chain is rendered straight with the default pendulum sway and
  // these fields stay empty.
  slack: number
  gravityScale: number
  nodes: VerletNode[]
  targetSegLen: number
  inited: boolean
}

interface VerletNode {
  x: number
  y: number
  /** Previous-step position; Verlet derives velocity from `pos − prev`. */
  ox: number
  oy: number
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
  // Pointer state. The simulation only consumes the delta between
  // consecutive `setPointer` calls (`pointerDxAccum` / `DyAccum`), so
  // a stationary cursor produces zero force. The position itself is
  // kept to anchor the influence radius around the cursor.
  private pointerActive = false
  private pointerHasPrev = false
  private pointerX = 0
  private pointerY = 0
  private pointerPrevX = 0
  private pointerPrevY = 0
  private pointerDxAccum = 0
  private pointerDyAccum = 0

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
        slack: 0,
        gravityScale: 1,
        nodes: [],
        targetSegLen: 0,
        inited: false,
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
   * Inform the engine of the cursor's viewport-space position. Each
   * call accumulates the delta since the previous call as a one-shot
   * impulse — when the simulation reads it, nearby Verlet nodes are
   * nudged in the cursor's *direction of motion*. Stationary cursors
   * therefore produce no impulse, regardless of how close they are to
   * a chain. `null` clears the state and aborts any pending impulse.
   */
  setPointer(x: number | null, y: number | null): void {
    if (x === null || y === null) {
      this.pointerActive = false
      this.pointerHasPrev = false
      this.pointerDxAccum = 0
      this.pointerDyAccum = 0
      return
    }
    if (this.pointerHasPrev) {
      this.pointerDxAccum += x - this.pointerPrevX
      this.pointerDyAccum += y - this.pointerPrevY
    }
    this.pointerPrevX = x
    this.pointerPrevY = y
    this.pointerHasPrev = true
    this.pointerActive = true
    this.pointerX = x
    this.pointerY = y
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
      const newSlack = spec.slack && spec.slack > 1 ? spec.slack : 0
      // Wipe the simulation state when the slack mode flips (taut ↔
      // slack) OR when the slack value changes more than a sliver.
      // Without this, switching from a generous slack to a tighter
      // one would keep the old, deeply-sagging node positions — the
      // node-count check inside `simulateVerlet` only triggers on a
      // *count* change, not an arc-length change.
      const slackModeFlipped = (newSlack > 0) !== (e.slack > 0)
      const slackShifted = Math.abs(newSlack - e.slack) > 0.001
      if (slackModeFlipped || slackShifted) {
        e.nodes = []
        e.inited = false
      }
      e.slack = newSlack
      e.gravityScale = spec.gravityScale ?? 1
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
    e.slack = 0
    e.gravityScale = 1
    e.nodes = []
    e.inited = false
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

      if (e.slack > 0) {
        this.simulateVerlet(e, dt)
      }
      this.renderChain(e)
    }

    // Pointer impulse is a one-shot delta — every chain has now had a
    // chance to consume it. Wipe so the next frame only reacts to new
    // motion, not the cumulative history.
    this.pointerDxAccum = 0
    this.pointerDyAccum = 0
  }

  /**
   * One step of Verlet-rope simulation. Standard algorithm:
   *
   *   1. For each unpinned node: pos += (pos − oldPos) × damping +
   *      gravity × dt². Velocity is implicit in the position delta.
   *   2. Pin the two endpoints to the chain's anchors (curFrom/curTo).
   *   3. Iterate constraint relaxation: for each adjacent pair, push
   *      them apart or together so their distance equals
   *      `targetSegLen`. After ~12 iterations the segments are visibly
   *      uniform on a 30-50 node chain.
   *
   * Reference: https://toqoz.fyi/game-rope.html — the canonical
   * write-up of this technique for 2D ropes/chains.
   */
  private simulateVerlet(e: ChainEntity, dt: number): void {
    const dx = e.curToX - e.curFromX
    const dy = e.curToY - e.curFromY
    const chord = Math.sqrt(dx * dx + dy * dy)
    if (chord < 2) return

    const arcLen = chord * e.slack
    const desiredCount = Math.max(MIN_NODES, Math.round(arcLen / MAILLON_SPACING))

    // (Re)allocate when the desired node count has shifted (e.g. anchors
    // moved enough to need more/fewer maillons). Initial layout puts
    // the nodes on the analytical equilibrium sag for the current
    // slack — derived from the small-span catenary approximation
    // `sag ≈ chord × √(3·(slack−1)/8)` — so the simulation drops into
    // a stable state on frame one instead of oscillating into place.
    if (!e.inited || e.nodes.length !== desiredCount) {
      e.nodes = new Array(desiredCount)
      const slackOver = Math.max(0, e.slack - 1)
      const initSag = chord * Math.sqrt((3 * slackOver) / 8)
      for (let i = 0; i < desiredCount; i++) {
        const t = i / (desiredCount - 1)
        const x = e.curFromX + dx * t
        const y = e.curFromY + dy * t + initSag * 4 * t * (1 - t)
        e.nodes[i] = { x, y, ox: x, oy: y }
      }
      e.inited = true
    }
    e.targetSegLen = arcLen / (e.nodes.length - 1)

    // 1. Verlet integration on every interior node. Endpoints are
    //    handled by the pin step below.
    const dtSq = dt * dt
    const gravity = VERLET_GRAVITY_PX_S2 * dtSq * e.gravityScale
    const damping = VERLET_DAMPING
    const lastIdx = e.nodes.length - 1
    for (let i = 1; i < lastIdx; i++) {
      const n = e.nodes[i]!
      const vx = (n.x - n.ox) * damping
      const vy = (n.y - n.oy) * damping
      n.ox = n.x
      n.oy = n.y
      n.x += vx
      n.y += vy + gravity
    }

    // 1b. Pointer interaction — apply the cursor's frame-to-frame
    //     delta as a one-shot impulse, scaled by a linear distance
    //     falloff around the cursor. Modifying `pos` (not `ox/oy`)
    //     means the displacement is interpreted as added velocity by
    //     Verlet, so the rope swings back naturally after the gust.
    //     The delta is accumulated in `setPointer` and zeroed by
    //     `tick()` after every chain has had a chance to consume it.
    if (
      this.pointerActive &&
      (this.pointerDxAccum !== 0 || this.pointerDyAccum !== 0)
    ) {
      const px = this.pointerX
      const py = this.pointerY
      const dxImp = this.pointerDxAccum
      const dyImp = this.pointerDyAccum
      const r = POINTER_RADIUS
      const r2 = r * r
      const gain = POINTER_GAIN
      for (let i = 1; i < lastIdx; i++) {
        const n = e.nodes[i]!
        const rdx = n.x - px
        const rdy = n.y - py
        const d2 = rdx * rdx + rdy * rdy
        if (d2 >= r2) continue
        const falloff = 1 - Math.sqrt(d2) / r
        n.x += dxImp * gain * falloff
        n.y += dyImp * gain * falloff
      }
    }

    // 2. Pin endpoints to the (lerped) anchor positions. Setting old =
    //    current zeroes the implicit velocity at the pin point so the
    //    chain doesn't keep "remembering" anchor motion.
    const head = e.nodes[0]!
    head.x = e.curFromX
    head.y = e.curFromY
    head.ox = e.curFromX
    head.oy = e.curFromY
    const tail = e.nodes[lastIdx]!
    tail.x = e.curToX
    tail.y = e.curToY
    tail.ox = e.curToX
    tail.oy = e.curToY

    // 3. Constraint relaxation — for each adjacent pair, slide them
    //    along their connecting line until their distance matches
    //    `targetSegLen`. Endpoints are pinned, so when an endpoint is
    //    one of the pair, the entire correction goes onto the other
    //    node (a-fixed and b-fixed branches).
    for (let it = 0; it < VERLET_ITERATIONS; it++) {
      for (let i = 0; i < lastIdx; i++) {
        const a = e.nodes[i]!
        const b = e.nodes[i + 1]!
        const ddx = b.x - a.x
        const ddy = b.y - a.y
        const d = Math.sqrt(ddx * ddx + ddy * ddy)
        if (d < 0.0001) continue
        const diff = (e.targetSegLen - d) / d
        const offX = ddx * 0.5 * diff
        const offY = ddy * 0.5 * diff
        const aFixed = i === 0
        const bFixed = i + 1 === lastIdx
        if (aFixed && bFixed) continue
        if (aFixed) {
          b.x += offX * 2
          b.y += offY * 2
        } else if (bFixed) {
          a.x -= offX * 2
          a.y -= offY * 2
        } else {
          a.x -= offX
          a.y -= offY
          b.x += offX
          b.y += offY
        }
      }
    }
  }

  private renderChain(e: ChainEntity): void {
    const g = e.g
    g.clear()

    const dx = e.curToX - e.curFromX
    const dy = e.curToY - e.curFromY
    const length = Math.sqrt(dx * dx + dy * dy)
    if (length < 2) return

    const palette = CHAIN_COLOR[e.state]

    // Always odd for a clean midpoint maillon.
    let segmentCount = Math.max(3, Math.round(length / MAILLON_SPACING))
    if (segmentCount % 2 === 0) segmentCount += 1

    if (e.slack > 0 && e.nodes.length > 0) {
      // Verlet-rope mode — render one maillon per simulated node. The
      // alternating vertical/horizontal pattern follows the same pixel
      // grammar as the static chains: every other ring is on its side.
      for (let i = 0; i < e.nodes.length; i++) {
        const n = e.nodes[i]!
        const vertical = i % 2 === 0
        drawMaillon(g, n.x, n.y, vertical, palette)
      }
      return
    }

    // Default mode — lateral pendulum swing (used by the pit's
    // vertical chains between islands).
    const perpX = -dy / length
    const perpY = dx / length
    const amp = SWING_AMPLITUDE_PX[e.state]
    const sway = Math.sin(e.swingTime * 1.4 + e.phase) * amp

    for (let i = 0; i < segmentCount; i++) {
      const t = i / (segmentCount - 1)
      const taper = Math.sin(t * Math.PI)
      const offset = sway * taper
      const x = e.curFromX + dx * t + perpX * offset
      const y = e.curFromY + dy * t + perpY * offset
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
    px(0, 1, palette.rim)
    px(0, 2, palette.rim)
    px(0, 3, palette.rim)
    px(1, 0, palette.outline)
    px(1, 4, palette.outline)
    px(4, 0, palette.outline)
    px(4, 4, palette.outline)
    px(2, 0, palette.core)
    px(3, 0, palette.core)
    px(2, 4, palette.shadow)
    px(3, 4, palette.shadow)
    px(5, 1, palette.shadow)
    px(5, 2, palette.shadow)
    px(5, 3, palette.shadow)
  }
}
