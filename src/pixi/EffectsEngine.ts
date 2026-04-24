import { Application, Container, Graphics } from 'pixi.js'

/* =========================================================================
 * The Pit — Effects Engine
 * One PIXI.Application, fullscreen pinned, pointer-events none.
 * Hosts every micro-effect of the app: ambient drift, click bursts, shockwave
 * rings, drips, hover auras, attached ripples/pulses/sparkles.
 * =======================================================================*/

export type BurstVariant = 'primary' | 'danger' | 'default' | 'ghost'

export interface BurstOptions {
  x: number
  y: number
  variant?: BurstVariant
}

export interface ShockwaveOptions {
  x: number
  y: number
  color: number
}

export interface DripOptions {
  x: number
  y: number
  color?: number
  speed?: number
  size?: number
}

export type AttachKind =
  | 'aura'
  | 'ripple'
  | 'pulse'
  | 'sparkle'
  | 'drips'
  | 'drip-pool'
  | 'grass'
  | 'embers'
  | 'godray'
  | 'coins'
  | 'spring'

export interface AttachConfig {
  color?: number
  intensity?: number
  /**
   * Grass-specific: how blades are distributed across the attached rect.
   *   - 'edge' (default): blades anchor on the top edge + side tufts,
   *     growing upward. Reads as "grass on the top of a button".
   *   - 'patch': blades scatter randomly across the rect's area,
   *     anchoring on arbitrary (x, y) points. Reads as a top-down
   *     patch of grass on a surface — used by the isometric Pit
   *     islands where grass grows ON the cap rather than AROUND a
   *     rectangle.
   */
  shape?: 'edge' | 'patch'
  /** Multiplier applied to blade target heights. Default 1. */
  heightScale?: number
  /** Multiplier applied to blade count. Default 1. */
  countScale?: number
}

// --------------------- color helpers ---------------------

const COLOR_GREEN = 0x9ae66e
const COLOR_RED = 0xd45a5a
const COLOR_GILD = 0xb58b3a
const COLOR_BONE = 0xd8cfb8
const COLOR_VIOLET = 0x9a7bd4
const COLOR_CYAN = 0x6ec3d4
const COLOR_DIM = 0x6b6b6b

// Ember-specific palette — the ramp a live coal travels through as it cools.
const EMBER_HOT_COLOR = 0xffa030 // incandescent orange at spawn
const EMBER_COOL_COLOR = 0xa23318 // deep cooling red
const EMBER_DEAD_COLOR = 0x1a0a00 // charred, near-black
const EMBER_SMOKE_COLOR = 0x6b6b6b
const EMBER_SPARK_COLOR = 0xfff0c0

const BURST_COLORS: Record<BurstVariant, number> = {
  primary: COLOR_GREEN,
  danger: COLOR_RED,
  default: COLOR_GILD,
  ghost: COLOR_DIM,
}

function lighten(color: number, amount: number): number {
  const r = (color >> 16) & 0xff
  const g = (color >> 8) & 0xff
  const b = color & 0xff
  const lr = Math.min(255, Math.round(r + (255 - r) * amount))
  const lg = Math.min(255, Math.round(g + (255 - g) * amount))
  const lb = Math.min(255, Math.round(b + (255 - b) * amount))
  return (lr << 16) | (lg << 8) | lb
}

function darken(color: number, amount: number): number {
  const r = (color >> 16) & 0xff
  const g = (color >> 8) & 0xff
  const b = color & 0xff
  const dr = Math.max(0, Math.round(r * (1 - amount)))
  const dg = Math.max(0, Math.round(g * (1 - amount)))
  const db = Math.max(0, Math.round(b * (1 - amount)))
  return (dr << 16) | (dg << 8) | db
}

function blendColor(from: number, to: number, t: number): number {
  const tt = Math.max(0, Math.min(1, t))
  const fr = (from >> 16) & 0xff
  const fg = (from >> 8) & 0xff
  const fb = from & 0xff
  const tr = (to >> 16) & 0xff
  const tg = (to >> 8) & 0xff
  const tb = to & 0xff
  const r = Math.round(fr + (tr - fr) * tt)
  const g = Math.round(fg + (tg - fg) * tt)
  const b = Math.round(fb + (tb - fb) * tt)
  return (r << 16) | (g << 8) | b
}

// --------------------- pool structures ---------------------

interface Particle {
  g: Graphics
  vx: number
  vy: number
  gravity: number
  life: number
  maxLife: number
  size: number
  color: number
  trail: boolean
  fadeMode: 'linear' | 'late' | 'ember'
  inUse: boolean
}

interface Ring {
  g: Graphics
  x: number
  y: number
  r: number
  maxR: number
  life: number
  maxLife: number
  color: number
  thickness: number
  inUse: boolean
}

interface Orbit {
  g: Graphics
  // attached effect identifier
  effectId: number
  // orbit data
  angle: number
  angularVel: number
  radiusBase: number
  radiusJitter: number
  phase: number
  size: number
  color: number
  baseAlpha: number
  inUse: boolean
}

const PARTICLE_POOL_SIZE = 320
const RING_POOL_SIZE = 48
const ORBIT_POOL_SIZE = 48

// --------------------- attached effect ---------------------

/**
 * DripState models the liquid that pools at a button's bottom edge during hover.
 *
 * It is a 1D height field: `cells[i]` is the vertical thickness (in px) of the
 * liquid directly below column `i`. Each frame while active we inject random
 * flow at a few indices (simulating overflowing water), spread the energy
 * laterally via diffusion (surface tension), cap the max thickness, and
 * randomly pinch off droplets from tall cells.
 *
 * When the host element stops being hovered, the whole body begins to fall
 * with an accelerating velocity (gravity) while fading — occasional droplets
 * keep breaking off during the fall. Once the body's alpha reaches zero the
 * cells clear and the state is ready for the next hover.
 */
interface DripState {
  // Bottom pool (height field extending downward from button bottom)
  cells: number[]
  cellCount: number
  detachMargin: number[]
  flowAcc: number
  drainAcc: number

  // Top band (height field extending upward above the button top edge)
  topCells: number[]
  topFlowAcc: number

  // Side streams — vertical liquid coating the left/right edges of the button.
  // The "length" is how many px of the edge are currently covered, from the top.
  leftLength: number
  rightLength: number
  leftDropAcc: number
  rightDropAcc: number

  graphic: Graphics
}

/**
 * A tall grass blade. Anchored at an origin on the button's top (or upper
 * side) edge, growing upward with a gentle natural curve. Every frame its
 * segments are recomputed by walking up the blade and applying per-segment
 * wind sway — the whole blade bends like a cantilever, with the top of the
 * blade displaced more than the base (wind effect scales with height²).
 */
interface GrassBlade {
  /**
   * Where on the host rect the blade is anchored.
   *   - 'top' | 'left' | 'right': classic edge-anchored blade. `originFrac`
   *     is the 0..1 position along that edge.
   *   - 'patch': anchored at a (x, y) point inside the rect's area.
   *     `originFrac` is used as the x fraction; `originFracY` is the y.
   *     Used by isometric island surfaces where grass grows ON the
   *     rock's top face rather than AROUND its rectangle.
   */
  side: 'top' | 'left' | 'right' | 'patch'
  originFrac: number // 0..1 along its host edge (x for 'patch')
  originFracY?: number // 0..1 y-fraction, set for 'patch'

  // Static per-blade shape (set once)
  targetHeight: number // total segment count the blade wants to reach
  baseAngle: number // mostly −π/2 with a small horizontal jitter
  naturalCurve: number // constant per-segment angle drift (slight lean)
  thickness: 1 | 2
  color: number
  hasSeed: boolean
  swayAmplitude: number // how strongly this blade bends in wind
  windPhase: number // phase offset so the field is not all in sync

  // Animation state
  currentHeight: number // smoothly interpolated 0..targetHeight
  growRate: number // segments per second while growing
  state: 'growing' | 'idle' | 'retracting' | 'dead'

  // Retract → detach phase: the blade trembles for `detachDelay` seconds
  // (wind-sway amplified) then rips off and becomes a DetachedBlade.
  retractAge: number
  detachDelay: number

  // Scratch, written each frame
  tipX: number
  tipY: number
}

/**
 * A blade that has torn off the field and is now a wind-borne fragment.
 * The shape is frozen at detach time (the segment offsets snapshot include
 * the wind curve in effect at that moment) and the whole body translates +
 * rotates rigidly thereafter.
 */
interface DetachedBlade {
  segments: Array<{ dx: number; dy: number }>
  thickness: 1 | 2
  color: number
  // World-space origin of the base pixel (rotation pivot)
  baseX: number
  baseY: number
  angle: number
  vx: number
  vy: number
  angularVel: number
  life: number
  maxLife: number
}

interface GrassState {
  blades: GrassBlade[]
  detached: DetachedBlade[]
  graphic: Graphics
  windTime: number
  color: number
}

interface EmberEntity {
  g: Graphics
  x: number
  y: number
  vx: number
  vy: number
  life: number
  maxLife: number
  size: number
  phase: number
  pulseSpeed: number
  kind: 'ember' | 'smoke' | 'spark'
  // Trail of previous positions for motion smear (embers only).
  // Captured at a coarse cadence to read as discrete pixel steps rather
  // than a smooth line.
  trailX: number[]
  trailY: number[]
  trailAcc: number
  // Horizontal wobble phase so smoke wisps drift independently.
  wobblePhase: number
  inUse: boolean
}

interface EmberState {
  entities: EmberEntity[]
  spawnAcc: number
  smokeAcc: number
  sparkAcc: number
  color: number
}

interface AttachedEffect {
  id: number
  el: HTMLElement
  kind: AttachKind
  config: Required<AttachConfig>
  // per-tick spawn accumulator / timers
  spawnAcc: number
  cadence: number // seconds between spawns for this kind
  orbitParticles: Orbit[]
  lastRect: DOMRect | null
  // ripple-specific cadence (slower than spawn)
  rippleAcc: number
  // disabled flag (soft-disable without detach, e.g. hover off)
  enabled: boolean
  // drip-pool-specific state (only set for drip-pool)
  drip?: DripState
  // grass-specific state (only set for grass)
  grass?: GrassState
  // embers-specific state (only set for embers)
  embers?: EmberState
  // godray-specific state (only set for godray)
  godray?: GodrayState
  // coins-specific state (only set for coins)
  coins?: CoinState
  // spring-specific state (only set for spring)
  spring?: SpringState
}

/**
 * Godray — rotating pixel-art beams of warm light emanating from the
 * attached element. Used on the Pit's treasure islands: reads as the
 * rock being blessed / haunted by a divine glow, a radically different
 * signal from combat's embers or event's sparkle.
 */
interface GodraySpec {
  /** Base angle of the ray, in radians. */
  angle: number
  /** Peak length in px. Varies per ray so the halo is irregular. */
  length: number
  /** Phase offset so every ray pulses on its own cycle. */
  phase: number
}

interface GodrayState {
  graphic: Graphics
  rays: GodraySpec[]
  rotation: number
  time: number
  color: number
}

/**
 * Coins — gold pips that jet out of the attached element in short arcs
 * with gravity. Used for shop islands: the coin stack keeps spitting
 * coins that loft upward, flip in mid-air, and fall back down. Reads
 * unambiguously as a busy merchant handling money.
 */
interface CoinEntity {
  g: Graphics
  x: number
  y: number
  vx: number
  vy: number
  rotPhase: number
  rotSpeed: number
  age: number
  maxAge: number
  inUse: boolean
}

interface CoinState {
  entities: CoinEntity[]
  spawnAcc: number
  time: number
  color: number
}

/**
 * Spring — a continuous flow of water that pours out of an `event-
 * spring` island's pond, runs to the cap's edge, then cascades down
 * past the rock. Drops are spawned at the pond, given an outward
 * velocity along one of a few preset stream directions, and fall
 * under gravity with a short trail. Splash ripples bloom on the pond
 * itself at a slow cadence.
 */
interface SpringDrop {
  g: Graphics
  x: number
  y: number
  vx: number
  vy: number
  age: number
  maxAge: number
  trailX: number[]
  trailY: number[]
  trailAcc: number
  inUse: boolean
}

interface SpringState {
  ripple: Graphics
  drops: SpringDrop[]
  spawnAcc: number
  time: number
  color: number
}

let nextEffectId = 1

// --------------------- engine ---------------------

export class EffectsEngine {
  private app: Application
  private container: HTMLElement
  private particles: Particle[] = []
  private rings: Ring[] = []
  private orbits: Orbit[] = []
  private particlesLayer = new Container()
  private ringsLayer = new Container()
  private orbitLayer = new Container()
  private ambientLayer = new Container()
  private dripLayer = new Container()
  private embersLayer = new Container()
  private ready = false
  private disposed = false

  private ambientParticles: Particle[] = []
  private attached: AttachedEffect[] = []

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
    canvas.style.zIndex = '900'
    canvas.style.imageRendering = 'pixelated'
    this.container.appendChild(canvas)

    this.app.stage.addChild(this.ambientLayer)
    this.app.stage.addChild(this.dripLayer)
    this.app.stage.addChild(this.particlesLayer)
    this.app.stage.addChild(this.embersLayer)
    this.app.stage.addChild(this.orbitLayer)
    this.app.stage.addChild(this.ringsLayer)

    // build pools
    for (let i = 0; i < PARTICLE_POOL_SIZE; i++) {
      const g = new Graphics()
      g.visible = false
      this.particlesLayer.addChild(g)
      this.particles.push({
        g,
        vx: 0,
        vy: 0,
        gravity: 0,
        life: 0,
        maxLife: 0,
        size: 2,
        color: 0xffffff,
        trail: false,
        fadeMode: 'linear',
        inUse: false,
      })
    }

    for (let i = 0; i < RING_POOL_SIZE; i++) {
      const g = new Graphics()
      g.visible = false
      this.ringsLayer.addChild(g)
      this.rings.push({
        g,
        x: 0,
        y: 0,
        r: 0,
        maxR: 0,
        life: 0,
        maxLife: 0,
        color: 0xffffff,
        thickness: 1,
        inUse: false,
      })
    }

    for (let i = 0; i < ORBIT_POOL_SIZE; i++) {
      const g = new Graphics()
      g.visible = false
      this.orbitLayer.addChild(g)
      this.orbits.push({
        g,
        effectId: -1,
        angle: 0,
        angularVel: 0,
        radiusBase: 0,
        radiusJitter: 0,
        phase: 0,
        size: 2,
        color: 0xffffff,
        baseAlpha: 1,
        inUse: false,
      })
    }

    this.app.ticker.add((ticker) => {
      const dt = Math.min(ticker.deltaMS / 1000, 0.1)
      this.tickParticles(dt)
      this.tickRings(dt)
      this.tickAttached(dt)
      this.tickOrbits(dt)
      this.tickAmbient(dt)
    })

    this.seedAmbient()
    this.ready = true
  }

  dispose(): void {
    this.disposed = true
    if (this.ready) {
      this.app.destroy(true, { children: true })
    }
  }

  /**
   * Freeze every effect update. Meant for moments where the screen is
   * transforming heavily (zoom transition) and re-rendering the Pixi
   * stage alongside a scaled DOM becomes expensive.
   */
  pauseTicker(): void {
    if (this.ready) this.app.ticker.stop()
  }

  /**
   * Resume the effect ticker after a `pauseTicker()` call. Safe to call
   * if the ticker is already running.
   */
  resumeTicker(): void {
    if (this.ready) this.app.ticker.start()
  }

  // =====================================================================
  // Triggered effects — click/event driven
  // =====================================================================

  emitBurst({ x, y, variant = 'default' }: BurstOptions): void {
    if (!this.ready) return
    const color = BURST_COLORS[variant]

    const recipe = BURST_RECIPES[variant]
    const count = recipe.count
    let emitted = 0
    for (const p of this.particles) {
      if (emitted >= count) break
      if (p.inUse) continue
      const angle = recipe.upwardBias
        ? -Math.PI / 2 + (Math.random() - 0.5) * recipe.spreadAngle
        : Math.random() * Math.PI * 2
      const speed = recipe.speedMin + Math.random() * (recipe.speedMax - recipe.speedMin)
      p.vx = Math.cos(angle) * speed
      p.vy = Math.sin(angle) * speed
      p.gravity = recipe.gravity
      p.life = recipe.lifeMin + Math.random() * (recipe.lifeMax - recipe.lifeMin)
      p.maxLife = p.life
      p.size = recipe.sizeMin + Math.floor(Math.random() * (recipe.sizeMax - recipe.sizeMin + 1))
      p.color = color
      p.trail = false
      p.fadeMode = recipe.fadeMode
      this.drawParticle(p)
      p.g.x = x
      p.g.y = y
      p.g.alpha = 1
      p.g.visible = true
      p.inUse = true
      emitted++
    }

    // always pair burst with a shockwave ring
    this.emitShockwave({ x, y, color })
  }

  emitShockwave({ x, y, color }: ShockwaveOptions): void {
    if (!this.ready) return
    for (const r of this.rings) {
      if (r.inUse) continue
      r.x = x
      r.y = y
      r.r = 2
      r.maxR = 28
      r.life = 0.22
      r.maxLife = r.life
      r.color = color
      r.thickness = 1
      r.g.visible = true
      r.inUse = true
      this.drawRing(r)
      return
    }
  }

  emitDrip({ x, y, color = COLOR_BONE, speed = 40, size = 2 }: DripOptions): void {
    if (!this.ready) return
    for (const p of this.particles) {
      if (p.inUse) continue
      p.vx = (Math.random() - 0.5) * 6
      p.vy = speed
      p.gravity = 180
      p.life = 1.2 + Math.random() * 0.8
      p.maxLife = p.life
      p.size = size
      p.color = color
      p.trail = false
      p.fadeMode = 'late'
      this.drawParticle(p)
      p.g.x = x
      p.g.y = y
      p.g.alpha = 1
      p.g.visible = true
      p.inUse = true
      return
    }
  }

  // =====================================================================
  // Attached effects — tied to a DOM element
  // =====================================================================

  attach(el: HTMLElement, kind: AttachKind, config: AttachConfig = {}): () => void {
    return this.attachWithHandle(el, kind, config).detach
  }

  attachWithHandle(
    el: HTMLElement,
    kind: AttachKind,
    config: AttachConfig = {},
  ): { id: number; detach: () => void } {
    const id = nextEffectId++
    const resolved: Required<AttachConfig> = {
      color: config.color ?? DEFAULT_ATTACH_COLOR[kind],
      intensity: config.intensity ?? 1,
      shape: config.shape ?? 'edge',
      heightScale: config.heightScale ?? 1,
      countScale: config.countScale ?? 1,
    }
    const cadence = ATTACH_CADENCE[kind]
    const effect: AttachedEffect = {
      id,
      el,
      kind,
      config: resolved,
      spawnAcc: Math.random() * cadence,
      cadence,
      orbitParticles: [],
      lastRect: null,
      rippleAcc: Math.random() * 1.2,
      enabled: kind !== 'aura', // aura is opt-in via setEnabled
    }

    if (kind === 'aura') {
      this.initOrbit(effect)
    }

    if (kind === 'drip-pool') {
      this.initDripPool(effect)
    }

    if (kind === 'grass') {
      this.initGrass(effect)
    }

    if (kind === 'embers') {
      this.initEmbers(effect)
    }

    if (kind === 'godray') {
      this.initGodray(effect)
    }

    if (kind === 'coins') {
      this.initCoins(effect)
    }

    if (kind === 'spring') {
      this.initSpring(effect)
    }

    this.attached.push(effect)

    return { id, detach: () => this.detach(id) }
  }

  private initDripPool(effect: AttachedEffect): void {
    const graphic = new Graphics()
    this.dripLayer.addChild(graphic)
    const cellCount = 28
    effect.drip = {
      cells: new Array(cellCount).fill(0),
      cellCount,
      detachMargin: new Array(cellCount).fill(0).map(() => Math.random() * 3),
      flowAcc: 0,
      drainAcc: 0,
      topCells: new Array(cellCount).fill(0),
      topFlowAcc: 0,
      leftLength: 0,
      rightLength: 0,
      leftDropAcc: 0,
      rightDropAcc: 0,
      graphic,
    }
  }

  detach(id: number): void {
    const idx = this.attached.findIndex((e) => e.id === id)
    if (idx < 0) return
    const effect = this.attached[idx]
    // release orbit particles
    for (const o of effect.orbitParticles) {
      o.inUse = false
      o.effectId = -1
      o.g.visible = false
    }
    if (effect.drip) {
      effect.drip.graphic.destroy()
      effect.drip = undefined
    }
    if (effect.grass) {
      effect.grass.graphic.destroy()
      effect.grass = undefined
    }
    if (effect.embers) {
      for (const en of effect.embers.entities) en.g.destroy()
      effect.embers = undefined
    }
    if (effect.godray) {
      effect.godray.graphic.destroy()
      effect.godray = undefined
    }
    if (effect.coins) {
      for (const c of effect.coins.entities) c.g.destroy()
      effect.coins = undefined
    }
    if (effect.spring) {
      effect.spring.ripple.destroy()
      for (const d of effect.spring.drops) d.g.destroy()
      effect.spring = undefined
    }
    this.attached.splice(idx, 1)
  }

  setEnabled(id: number, enabled: boolean): void {
    const effect = this.attached.find((e) => e.id === id)
    if (!effect) return
    effect.enabled = enabled
    if (effect.kind === 'aura') {
      for (const o of effect.orbitParticles) {
        o.g.visible = enabled && o.inUse
      }
    }
  }

  // =====================================================================
  // Internal tickers
  // =====================================================================

  private tickParticles(dt: number): void {
    for (const p of this.particles) {
      if (!p.inUse) continue
      p.life -= dt
      if (p.life <= 0) {
        p.inUse = false
        p.g.visible = false
        continue
      }
      p.g.x += p.vx * dt
      p.g.y += p.vy * dt
      p.vy += p.gravity * dt
      const t = p.life / p.maxLife
      if (p.fadeMode === 'ember') {
        // fade-in during first 20%, hold, fade-out during last 30%
        const fadeIn = Math.min(1, (1 - t) / 0.2)
        const fadeOut = t > 0.3 ? 1 : t / 0.3
        p.g.alpha = Math.min(fadeIn, fadeOut)
      } else if (p.fadeMode === 'late') {
        p.g.alpha = t > 0.3 ? 1 : t / 0.3
      } else {
        p.g.alpha = t > 0.5 ? 1 : t * 2
      }
    }
  }

  private tickRings(dt: number): void {
    for (const r of this.rings) {
      if (!r.inUse) continue
      r.life -= dt
      if (r.life <= 0) {
        r.inUse = false
        r.g.visible = false
        continue
      }
      const t = 1 - r.life / r.maxLife
      r.r = 2 + (r.maxR - 2) * t
      r.g.alpha = r.life / r.maxLife
      this.drawRing(r)
    }
  }

  private tickOrbits(dt: number): void {
    for (const o of this.orbits) {
      if (!o.inUse) continue
      const effect = this.attached.find((e) => e.id === o.effectId)
      if (!effect || !effect.lastRect) {
        o.g.visible = false
        continue
      }
      o.angle += o.angularVel * dt
      o.phase += dt
      const rect = effect.lastRect
      const cx = rect.left + rect.width / 2
      const cy = rect.top + rect.height / 2
      const pulse = 1 + Math.sin(o.phase * 2.8) * 0.08
      const radius = o.radiusBase * pulse + Math.sin(o.phase * 1.5 + o.angle) * o.radiusJitter
      o.g.x = cx + Math.cos(o.angle) * radius
      o.g.y = cy + Math.sin(o.angle) * radius * 0.55 // squash into near-horizontal orbit
      o.g.alpha = effect.enabled ? o.baseAlpha * (0.5 + 0.5 * Math.sin(o.phase * 3)) : 0
      o.g.visible = effect.enabled
    }
  }

  private tickAttached(dt: number): void {
    for (const effect of this.attached) {
      if (!effect.el.isConnected) {
        // element gone — mark for detach next frame
        this.detach(effect.id)
        continue
      }
      // refresh rect each frame (cheap enough for current scale; also
      // lets attached effects follow the host element during scroll/resize)
      effect.lastRect = effect.el.getBoundingClientRect()
      const rect = effect.lastRect

      // drip-pool, grass and embers all tick regardless of enabled state:
      // they have drain/retract/fade-out phases that run when enabled=false,
      // and must follow the button across scrolls during that outro.
      if (effect.kind === 'drip-pool') {
        this.tickDripPool(effect, rect, dt)
        continue
      }
      if (effect.kind === 'grass') {
        this.tickGrass(effect, rect, dt)
        continue
      }
      if (effect.kind === 'embers') {
        this.tickEmbers(effect, rect, dt)
        continue
      }
      if (effect.kind === 'godray') {
        this.tickGodray(effect, rect, dt)
        continue
      }
      if (effect.kind === 'coins') {
        this.tickCoins(effect, rect, dt)
        continue
      }
      if (effect.kind === 'spring') {
        this.tickSpring(effect, rect, dt)
        continue
      }

      if (!effect.enabled) continue

      switch (effect.kind) {
        case 'sparkle': {
          effect.spawnAcc += dt
          while (effect.spawnAcc >= effect.cadence) {
            effect.spawnAcc -= effect.cadence
            this.spawnSparkleParticle(effect, rect)
          }
          break
        }
        case 'pulse': {
          effect.spawnAcc += dt
          while (effect.spawnAcc >= effect.cadence) {
            effect.spawnAcc -= effect.cadence
            this.spawnPulseParticle(effect, rect)
          }
          break
        }
        case 'ripple': {
          effect.rippleAcc += dt
          if (effect.rippleAcc >= 1.4) {
            effect.rippleAcc = 0
            this.spawnRipple(effect, rect)
          }
          break
        }
        case 'drips': {
          effect.spawnAcc += dt
          while (effect.spawnAcc >= effect.cadence) {
            effect.spawnAcc -= effect.cadence
            this.spawnTitleDrip(effect, rect)
          }
          break
        }
        case 'aura': {
          // orbit logic handled in tickOrbits via lastRect
          break
        }
      }
    }
  }

  private tickDripPool(effect: AttachedEffect, rect: DOMRect, dt: number): void {
    const s = effect.drip
    if (!s) return
    const color = effect.config.color

    // Edge taper — the leftmost and rightmost cells can hold less liquid,
    // which breaks the rectangular profile at the button's side edges.
    const taper = 4
    const maxCenter = 14
    const cellMax = (i: number): number => {
      if (i < taper) return 2 + i * 3
      if (i >= s.cellCount - taper) return 2 + (s.cellCount - 1 - i) * 3
      return maxCenter
    }

    // Lateral diffusion always runs — gives surface-tension smoothing whether
    // the body is filling or draining. Kept low so bumps remain visible.
    const k = 0.1
    const next = s.cells.slice()
    for (let i = 0; i < s.cellCount; i++) {
      const left = i > 0 ? s.cells[i - 1] : s.cells[i]
      const right = i < s.cellCount - 1 ? s.cells[i + 1] : s.cells[i]
      next[i] = s.cells[i] + k * (left + right - 2 * s.cells[i])
    }
    s.cells = next

    if (effect.enabled) {
      // ---------- ACTIVE: flow injection + gentle center-bias growth ----------
      s.flowAcc += dt
      if (s.flowAcc >= 0.05) {
        s.flowAcc = 0
        const injections = 2 + Math.floor(Math.random() * 3)
        for (let j = 0; j < injections; j++) {
          // Bias injections toward the center — edges only get flow from
          // diffusion, which combined with the taper keeps a rounded profile.
          const bias = Math.sin(Math.random() * Math.PI)
          const i = Math.max(
            0,
            Math.min(s.cellCount - 1, Math.floor((0.15 + bias * 0.7) * s.cellCount)),
          )
          const amount = 0.4 + Math.random() * 1.6
          s.cells[i] += amount
          if (i > 0) s.cells[i - 1] += amount * 0.3
          if (i < s.cellCount - 1) s.cells[i + 1] += amount * 0.3
        }
      }

      // Gentle center-weighted growth so runoff naturally hangs lowest in the
      // middle — kept low so the top surface isn't forced flat.
      const half = s.cellCount / 2
      for (let i = 0; i < s.cellCount; i++) {
        const centerDist = Math.abs(i - half) / half
        s.cells[i] += (1 - centerDist) * 0.35 * dt
      }

      // Active pinch-off: tall cells shed droplets probabilistically. Each
      // droplet actually removes mass from the source cell — the dripping
      // is what bounds the steady-state thickness, not an arbitrary cap.
      for (let i = 0; i < s.cellCount; i++) {
        const threshold = 7 + s.detachMargin[i]
        if (s.cells[i] > threshold) {
          const prob = (s.cells[i] - threshold) * dt * 2.2
          if (Math.random() < prob) {
            this.spawnLiquidDroplet(effect, rect, i, s.cells[i])
            s.cells[i] = Math.max(0, s.cells[i] - 4.5)
            s.detachMargin[i] = Math.random() * 3
          }
        }
      }
    } else {
      // ---------- DRAIN: no flow, aggressive droplet shedding + slow shrink ----------
      // Pinch droplets from the tallest available cell several times per second.
      // Each pinch removes ~3 units from its cell, so the body visibly loses
      // volume with every droplet that leaves it.
      s.drainAcc += dt
      while (s.drainAcc >= 0.045) {
        s.drainAcc -= 0.045
        let best = -1
        let bestH = 1.2
        // Sample a few candidates and drip from the tallest — preserves the
        // dispersed look while making sure we always target "real" liquid.
        for (let t = 0; t < 5; t++) {
          const i = Math.floor(Math.random() * s.cellCount)
          if (s.cells[i] > bestH) {
            best = i
            bestH = s.cells[i]
          }
        }
        if (best >= 0) {
          this.spawnLiquidDroplet(effect, rect, best, s.cells[best])
          s.cells[best] = Math.max(0, s.cells[best] - 3)
        }
      }
      // Passive shrinkage — the thin residue keeps retreating back into the
      // button edge rather than lingering forever.
      for (let i = 0; i < s.cellCount; i++) {
        s.cells[i] = Math.max(0, s.cells[i] - 4.5 * dt)
      }
    }

    // Enforce per-cell max (edge taper + global cap).
    for (let i = 0; i < s.cellCount; i++) {
      const m = cellMax(i)
      if (s.cells[i] > m) s.cells[i] = m
      if (s.cells[i] < 0) s.cells[i] = 0
    }

    // =========================================================
    // TOP BAND — thin liquid strip above the button's top edge
    // =========================================================
    const topMax = 3.2

    // Diffusion (lighter than the bottom's)
    const topK = 0.15
    const topNext = s.topCells.slice()
    for (let i = 0; i < s.cellCount; i++) {
      const left = i > 0 ? s.topCells[i - 1] : s.topCells[i]
      const right = i < s.cellCount - 1 ? s.topCells[i + 1] : s.topCells[i]
      topNext[i] = s.topCells[i] + topK * (left + right - 2 * s.topCells[i])
    }
    s.topCells = topNext

    if (effect.enabled) {
      // Uniform pour + small random ripple so the strip isn't a perfect line
      for (let i = 0; i < s.cellCount; i++) {
        s.topCells[i] += (2.2 + Math.random() * 1.4) * dt
      }
      s.topFlowAcc += dt
      if (s.topFlowAcc >= 0.1) {
        s.topFlowAcc = 0
        const i = Math.floor(Math.random() * s.cellCount)
        s.topCells[i] += 0.4 + Math.random() * 0.5
      }
    } else {
      for (let i = 0; i < s.cellCount; i++) {
        s.topCells[i] = Math.max(0, s.topCells[i] - 5 * dt)
      }
    }

    // Edge taper on top band too (subtle)
    for (let i = 0; i < s.cellCount; i++) {
      let topM = topMax
      if (i < 2) topM = Math.min(topMax, 0.6 + i * 1.2)
      if (i >= s.cellCount - 2) topM = Math.min(topMax, 0.6 + (s.cellCount - 1 - i) * 1.2)
      if (s.topCells[i] > topM) s.topCells[i] = topM
      if (s.topCells[i] < 0) s.topCells[i] = 0
    }

    // =========================================================
    // SIDE STREAMS — liquid cascading down the left & right edges
    // =========================================================
    const sideGrow = 160 // px/s
    const sideRetreat = 240 // px/s
    const sideMax = Math.max(0, rect.height - 2)

    if (effect.enabled) {
      s.leftLength = Math.min(sideMax, s.leftLength + sideGrow * dt)
      s.rightLength = Math.min(sideMax, s.rightLength + sideGrow * dt)

      // Once the stream has reached ~70% of the side, it "overflows" into
      // the bottom pool at that corner. Edge-tapered bottom cells can still
      // fill to their caps (~2..5 px) and the diffusion step carries mass
      // inward.
      if (s.leftLength > sideMax * 0.7) {
        s.cells[0] += 3 * dt
        if (s.cellCount > 1) s.cells[1] += 2 * dt
      }
      if (s.rightLength > sideMax * 0.7) {
        s.cells[s.cellCount - 1] += 3 * dt
        if (s.cellCount > 1) s.cells[s.cellCount - 2] += 2 * dt
      }

      // Side droplets: small pixels spraying outward from the stream's
      // leading tip every ~250ms once the stream is long enough to see.
      s.leftDropAcc += dt
      if (s.leftLength > 10 && s.leftDropAcc >= 0.22) {
        s.leftDropAcc = 0
        this.spawnSideDroplet(effect, rect, 'left')
      }
      s.rightDropAcc += dt
      if (s.rightLength > 10 && s.rightDropAcc >= 0.22) {
        s.rightDropAcc = 0
        this.spawnSideDroplet(effect, rect, 'right')
      }
    } else {
      s.leftLength = Math.max(0, s.leftLength - sideRetreat * dt)
      s.rightLength = Math.max(0, s.rightLength - sideRetreat * dt)
    }

    // =========================================================
    // DRAW — a single Graphics rebuilt from scratch each frame
    // =========================================================
    s.graphic.clear()
    const hasBody = s.cells.some((c) => c > 0.15)
    const hasTop = s.topCells.some((c) => c > 0.15)
    const hasSides = s.leftLength > 0.3 || s.rightLength > 0.3
    if (!hasBody && !hasTop && !hasSides) return

    const cellWidth = rect.width / s.cellCount
    const baseY = rect.bottom
    const topY = rect.top

    // ---- BOTTOM POOL ----
    if (hasBody) {
      // Body pass
      for (let i = 0; i < s.cellCount; i++) {
        const h = s.cells[i]
        if (h < 0.2) continue
        const x = rect.left + i * cellWidth
        const w = cellWidth + 0.6
        s.graphic.rect(Math.round(x), Math.round(baseY), Math.max(1, Math.round(w)), Math.max(1, Math.round(h)))
      }
      s.graphic.fill({ color, alpha: 0.92 })

      // Bottom specular
      let anySpec = false
      for (let i = 0; i < s.cellCount; i++) {
        if (s.cells[i] < 1) continue
        const x = rect.left + i * cellWidth
        const w = cellWidth + 0.6
        s.graphic.rect(Math.round(x), Math.round(baseY), Math.max(1, Math.round(w)), 1)
        anySpec = true
      }
      if (anySpec) s.graphic.fill({ color: lighten(color, 0.42), alpha: 0.88 })
    }

    // ---- TOP BAND ----
    if (hasTop) {
      for (let i = 0; i < s.cellCount; i++) {
        const h = s.topCells[i]
        if (h < 0.2) continue
        const x = rect.left + i * cellWidth
        const w = cellWidth + 0.6
        const yTop = topY - Math.max(1, Math.round(h))
        s.graphic.rect(Math.round(x), yTop, Math.max(1, Math.round(w)), Math.max(1, Math.round(h)))
      }
      s.graphic.fill({ color, alpha: 0.88 })

      // Specular row on top surface (the wet shine facing the sky)
      let anyTopSpec = false
      for (let i = 0; i < s.cellCount; i++) {
        const h = s.topCells[i]
        if (h < 1) continue
        const x = rect.left + i * cellWidth
        const w = cellWidth + 0.6
        const yTop = topY - Math.max(1, Math.round(h))
        s.graphic.rect(Math.round(x), yTop, Math.max(1, Math.round(w)), 1)
        anyTopSpec = true
      }
      if (anyTopSpec) s.graphic.fill({ color: lighten(color, 0.42), alpha: 0.85 })
    }

    // ---- SIDE STREAMS ----
    if (hasSides) {
      if (s.leftLength > 0.3) {
        s.graphic.rect(
          Math.round(rect.left - 1),
          Math.round(rect.top),
          2,
          Math.max(1, Math.round(s.leftLength)),
        )
      }
      if (s.rightLength > 0.3) {
        s.graphic.rect(
          Math.round(rect.right - 1),
          Math.round(rect.top),
          2,
          Math.max(1, Math.round(s.rightLength)),
        )
      }
      s.graphic.fill({ color, alpha: 0.9 })

      // 1px bright edge on each stream (the outer lip "catches light")
      if (s.leftLength > 2) {
        s.graphic.rect(
          Math.round(rect.left - 1),
          Math.round(rect.top),
          1,
          Math.max(1, Math.round(s.leftLength)),
        )
      }
      if (s.rightLength > 2) {
        s.graphic.rect(
          Math.round(rect.right),
          Math.round(rect.top),
          1,
          Math.max(1, Math.round(s.rightLength)),
        )
      }
      if (s.leftLength > 2 || s.rightLength > 2) {
        s.graphic.fill({ color: lighten(color, 0.42), alpha: 0.7 })
      }
    }
  }

  private spawnSideDroplet(effect: AttachedEffect, rect: DOMRect, side: 'left' | 'right'): void {
    const p = this.pickFreeParticle()
    if (!p) return
    const s = effect.drip
    if (!s) return
    const length = side === 'left' ? s.leftLength : s.rightLength
    const edgeX = side === 'left' ? rect.left - 1 : rect.right + 1
    // spawn somewhere between the middle and tip of the stream
    const alongY = rect.top + length * (0.5 + Math.random() * 0.5)
    p.vx = (side === 'left' ? -1 : 1) * (2 + Math.random() * 4)
    p.vy = 30 + Math.random() * 30
    p.gravity = 620
    p.life = 0.7 + Math.random() * 0.4
    p.maxLife = p.life
    p.size = Math.random() < 0.3 ? 2 : 1
    p.color = effect.config.color
    p.fadeMode = 'late'
    this.drawParticle(p)
    p.g.x = edgeX
    p.g.y = alongY
    p.g.alpha = 1
    p.g.visible = true
    p.inUse = true
  }

  private spawnLiquidDroplet(
    effect: AttachedEffect,
    rect: DOMRect,
    cellIndex: number,
    thickness: number,
  ): void {
    const p = this.pickFreeParticle()
    if (!p) return
    const s = effect.drip
    if (!s) return
    const cellWidth = rect.width / s.cellCount
    const cx = rect.left + cellIndex * cellWidth + cellWidth / 2
    const jitterX = (Math.random() - 0.5) * cellWidth * 0.8
    const x = cx + jitterX
    const y = rect.bottom + thickness
    p.vx = (Math.random() - 0.5) * 6
    p.vy = 20 + Math.random() * 40
    p.gravity = 600
    p.life = 0.8 + Math.random() * 0.5
    p.maxLife = p.life
    // Big thick cells drop bigger globs
    p.size = thickness > 9 ? (Math.random() < 0.55 ? 2 : 3) : Math.random() < 0.45 ? 2 : 1
    p.color = effect.config.color
    p.fadeMode = 'late'
    this.drawParticle(p)
    p.g.x = x
    p.g.y = y
    p.g.alpha = 1
    p.g.visible = true
    p.inUse = true
  }

  // =========================================================
  // GRASS — tall grass blades growing upward from the button's
  //          top edge and upper corners, bending in the wind.
  // =========================================================
  private initGrass(effect: AttachedEffect): void {
    const graphic = new Graphics()
    this.dripLayer.addChild(graphic)
    const blades: GrassBlade[] = []
    const baseColor = effect.config.color

    const darker = darken(baseColor, 0.24)
    const lighter = lighten(baseColor, 0.22)

    const pickColor = () => {
      const r = Math.random()
      if (r < 0.22) return darker
      if (r < 0.48) return lighter
      return baseColor
    }

    const heightScale = effect.config.heightScale
    const countScale = effect.config.countScale

    if (effect.config.shape === 'patch') {
      // Area distribution: blades scatter randomly across the rect. We
      // reject any (fx, fy) outside an irregular ellipse inscribed in
      // the rect. The ellipse is a circle in *normalised* coords (so
      // it naturally takes the rect's own aspect — wide rects produce
      // wide ovals, flat rects produce flat ovals). Angle-dependent
      // noise keeps the boundary organic.
      const targetCount = Math.max(20, Math.round(60 * countScale))
      let placed = 0
      let attempts = 0
      const attemptCap = targetCount * 6
      while (placed < targetCount && attempts < attemptCap) {
        attempts++
        const fx = Math.random()
        const fy = Math.random()
        const dx = fx - 0.5
        const dy = fy - 0.5
        const angle = Math.atan2(dy, dx)
        // Normalised-circle rejection (no aspect weighting): the rect
        // already carries the desired screen shape from the caller.
        const boundary = 0.235 + 0.035 * Math.sin(angle * 5)
        const distSq = dx * dx + dy * dy
        if (distSq > boundary) continue
        blades.push(this.buildBlade('patch', fx, pickColor(), heightScale, fy))
        placed++
      }
    } else {
      // Classic edge distribution — used by buttons.
      const topCount = Math.max(4, Math.round(34 * countScale))
      for (let i = 0; i < topCount; i++) {
        blades.push(
          this.buildBlade(
            'top',
            (i + 0.5) / topCount + (Math.random() - 0.5) * 0.035,
            pickColor(),
            heightScale,
          ),
        )
      }
      const sideCount = Math.max(1, Math.round(5 * countScale))
      for (let i = 0; i < sideCount; i++) {
        const base = (i + 0.5) / sideCount
        const frac = base * 0.3
        blades.push(this.buildBlade('left', frac, pickColor(), heightScale))
        blades.push(this.buildBlade('right', frac, pickColor(), heightScale))
      }
    }

    effect.grass = {
      blades,
      detached: [],
      graphic,
      windTime: Math.random() * Math.PI * 2,
      color: baseColor,
    }
  }

  private buildBlade(
    side: GrassBlade['side'],
    originFrac: number,
    color: number,
    heightScale: number = 1,
    originFracY?: number,
  ): GrassBlade {
    // Height distribution must come before the angle so 'patch' blades
    // can lean more when they are ground-cover height.
    const r = Math.random()
    let rawHeight: number
    if (side === 'patch') {
      // Three tiers so a patch reads as a carpet, not a thin scatter:
      //   65% ground cover (2..4 px)  — short, dense, the tapis
      //   25% medium    (5..8 px)   — regular blades that pop out
      //   10% tall accent (9..12 px) — a few spikes standing proud
      const tier = Math.random()
      if (tier < 0.65) rawHeight = 2 + Math.floor(Math.random() * 3)
      else if (tier < 0.9) rawHeight = 5 + Math.floor(Math.random() * 4)
      else rawHeight = 9 + Math.floor(Math.random() * 4)
    } else if (side !== 'top') {
      rawHeight = 3 + Math.floor(Math.random() * 7)
    } else if (r < 0.32) rawHeight = 3 + Math.floor(Math.random() * 4)
    else if (r < 0.8) rawHeight = 7 + Math.floor(Math.random() * 8)
    else rawHeight = 15 + Math.floor(Math.random() * 8)
    const targetHeight = Math.max(1, Math.round(rawHeight * heightScale))

    // Most blades point straight up; side tufts lean slightly outward first
    // then the wind + natural curve carry them up. Patch ground-cover
    // leans much more (low grass sprouts at angles); patch accents stand
    // up straighter.
    let baseAngle = -Math.PI / 2
    if (side === 'left') baseAngle += -0.25 + (Math.random() - 0.5) * 0.35
    else if (side === 'right') baseAngle += 0.25 + (Math.random() - 0.5) * 0.35
    else if (side === 'patch') {
      const lean = rawHeight <= 4 ? 0.65 : 0.28
      baseAngle += (Math.random() - 0.5) * lean
    } else baseAngle += (Math.random() - 0.5) * 0.4

    const naturalCurve = (Math.random() - 0.5) * 0.035

    // Taller blades sway more; shorter barely move. Wind amplitude is scaled
    // again by height² in the tick so the base stays anchored.
    const swayAmplitude = 0.18 + Math.random() * 0.22
    const windPhase = Math.random() * Math.PI * 2

    const thickness: 1 | 2 = Math.random() < 0.14 && targetHeight >= 8 ? 2 : 1
    const hasSeed = targetHeight >= 8 && Math.random() < 0.35

    return {
      side,
      originFrac: Math.min(0.98, Math.max(0.02, originFrac)),
      originFracY:
        originFracY === undefined
          ? undefined
          : Math.min(0.98, Math.max(0.02, originFracY)),
      targetHeight,
      baseAngle,
      naturalCurve,
      thickness,
      color,
      hasSeed,
      swayAmplitude,
      windPhase,
      currentHeight: 0,
      growRate: 22 + Math.random() * 18, // segments per second — quick sprout-in
      state: 'growing',
      retractAge: 0,
      detachDelay: 0,
      tipX: 0,
      tipY: 0,
    }
  }

  private tickGrass(effect: AttachedEffect, rect: DOMRect, dt: number): void {
    const state = effect.grass
    if (!state) return

    // Advance the wind clock regardless of hover — grass keeps swaying even
    // as it retracts, and detached fragments are blown by the same wind.
    state.windTime += dt
    const gustSlow = Math.sin(state.windTime * 0.9)
    const gustFast = Math.sin(state.windTime * 2.15 + 1.3)

    // ---- Detached fragment physics ---------------------------------------
    // Reverse iterate so splice during the loop is safe.
    for (let i = state.detached.length - 1; i >= 0; i--) {
      const d = state.detached[i]
      d.life -= dt
      if (d.life <= 0) {
        state.detached.splice(i, 1)
        continue
      }
      // Wind carries the fragment laterally (same gusts as the grass field),
      // gravity pulls it down slowly, drag damps motion + rotation over time.
      d.vx += (gustSlow * 55 + gustFast * 22) * dt
      d.vy += 22 * dt
      d.vx *= 0.988
      d.vy *= 0.995
      d.angularVel *= 0.99
      d.baseX += d.vx * dt
      d.baseY += d.vy * dt
      d.angle += d.angularVel * dt
    }

    // ---- Living blade state updates + detach on retract timeout ---------
    for (const b of state.blades) {
      if (effect.enabled) {
        if (b.state === 'retracting' || b.state === 'dead') {
          b.state = 'growing'
          b.retractAge = 0
        }
        if (b.state === 'growing') {
          b.currentHeight = Math.min(b.targetHeight, b.currentHeight + b.growRate * dt)
          if (b.currentHeight >= b.targetHeight) b.state = 'idle'
        }
      } else {
        if (b.state === 'growing' || b.state === 'idle') {
          b.state = 'retracting'
          b.retractAge = 0
          // Short blades rip off first (lighter; wind catches them faster)
          const lengthFactor = 1 - Math.min(1, b.targetHeight / 22)
          b.detachDelay = 0.08 + lengthFactor * 0.25 + Math.random() * 0.3
        }
        if (b.state === 'retracting') {
          b.retractAge += dt
          if (b.retractAge >= b.detachDelay && b.currentHeight > 0.6) {
            // Snapshot the blade's current shape (with amplified sway at the
            // moment of detach) and spawn it as a wind-borne fragment.
            const drawn = Math.floor(b.currentHeight)
            const origin = this.resolveGrassOrigin(b, rect)
            const segs: Array<{ dx: number; dy: number }> = []
            const retractFactor = 1 + 2.2 // matches render amplification at detach time
            let angle = b.baseAngle
            let dx = 0
            let dy = 0
            for (let i = 0; i < drawn; i++) {
              angle += b.naturalCurve
              const hFactor = (i + 1) / b.targetHeight
              const hSq = hFactor * hFactor
              const sway =
                (gustSlow * 0.55 +
                  gustFast * 0.25 +
                  Math.sin(state.windTime * 1.6 + b.windPhase) * 0.35) *
                b.swayAmplitude *
                hSq *
                retractFactor
              const displayAngle = angle + sway
              dx += Math.cos(displayAngle)
              dy += Math.sin(displayAngle)
              segs.push({ dx, dy })
            }

            // Initial velocity reflects the tip's current motion + wind push
            const last = segs[drawn - 1]
            const prev = drawn > 1 ? segs[drawn - 2] : { dx: 0, dy: 0 }
            const tipDX = last.dx - prev.dx
            const tipDY = last.dy - prev.dy
            const windPush = gustSlow * 60 + gustFast * 25
            const totalLife = 1.6 + Math.random() * 0.9
            state.detached.push({
              segments: segs,
              thickness: b.thickness,
              color: b.color,
              baseX: origin.x,
              baseY: origin.y,
              angle: 0,
              vx: tipDX * 22 + windPush * 0.7 + (Math.random() - 0.5) * 14,
              vy: tipDY * 12 - 10 - Math.random() * 12,
              angularVel: (Math.random() - 0.5) * Math.PI * 1.3,
              life: totalLife,
              maxLife: totalLife,
            })

            b.state = 'dead'
            b.currentHeight = 0
          }
        }
      }
    }

    state.graphic.clear()

    // ---- Living blade render pass (grouped by colour) -------------------
    const byColor = new Map<number, GrassBlade[]>()
    for (const b of state.blades) {
      if (b.currentHeight <= 0.1) continue
      const bucket = byColor.get(b.color)
      if (bucket) bucket.push(b)
      else byColor.set(b.color, [b])
    }

    for (const [col, blades] of byColor) {
      for (const b of blades) {
        const drawn = Math.floor(b.currentHeight)
        if (drawn <= 0) continue
        const origin = this.resolveGrassOrigin(b, rect)
        // Amplify sway during the tremble phase — blade thrashes as it
        // weakens, selling the "about to tear off" moment.
        const retractFactor =
          b.state === 'retracting' && b.detachDelay > 0
            ? 1 + Math.min(1, b.retractAge / b.detachDelay) * 2.2
            : 1
        let angle = b.baseAngle
        let dx = 0
        let dy = 0
        for (let i = 0; i < drawn; i++) {
          angle += b.naturalCurve
          const hFactor = (i + 1) / b.targetHeight
          const hSq = hFactor * hFactor
          const sway =
            (gustSlow * 0.55 +
              gustFast * 0.25 +
              Math.sin(state.windTime * 1.6 + b.windPhase) * 0.35) *
            b.swayAmplitude *
            hSq *
            retractFactor
          dx += Math.cos(angle + sway)
          dy += Math.sin(angle + sway)
          const px = Math.round(origin.x + dx)
          const py = Math.round(origin.y + dy)
          if (b.thickness === 2) state.graphic.rect(px - 1, py - 1, 2, 2)
          else state.graphic.rect(px, py, 1, 1)
          if (i === drawn - 1) {
            b.tipX = px
            b.tipY = py
          }
        }
      }
      state.graphic.fill({ color: col, alpha: 0.94 })
    }

    // ---- Seed tips (on grown idle blades) --------------------------------
    let anySeed = false
    for (const b of state.blades) {
      if (!b.hasSeed || b.state !== 'idle') continue
      if (b.currentHeight < b.targetHeight - 0.5) continue
      state.graphic.rect(b.tipX - 1, b.tipY - 1, 2, 2)
      anySeed = true
    }
    if (anySeed) state.graphic.fill({ color: 0xcce873, alpha: 0.95 })

    // ---- Detached fragments render (rotated, dried, faded) --------------
    // Each fragment gets its own fill: life-dependent alpha + colour blend
    // from the blade's living colour toward a dry brown.
    const DRY = 0x8a7034
    for (const d of state.detached) {
      const t = d.life / d.maxLife
      const alpha = t > 0.5 ? 0.9 : t * 1.8 * 0.9
      const color = blendColor(d.color, DRY, 1 - t)
      const cosA = Math.cos(d.angle)
      const sinA = Math.sin(d.angle)
      for (const seg of d.segments) {
        const rx = seg.dx * cosA - seg.dy * sinA
        const ry = seg.dx * sinA + seg.dy * cosA
        const px = Math.round(d.baseX + rx)
        const py = Math.round(d.baseY + ry)
        if (d.thickness === 2) state.graphic.rect(px - 1, py - 1, 2, 2)
        else state.graphic.rect(px, py, 1, 1)
      }
      state.graphic.fill({ color, alpha })
    }
  }

  private resolveGrassOrigin(b: GrassBlade, rect: DOMRect): { x: number; y: number } {
    if (b.side === 'top') return { x: rect.left + rect.width * b.originFrac, y: rect.top }
    if (b.side === 'left') return { x: rect.left, y: rect.top + rect.height * b.originFrac }
    if (b.side === 'right') return { x: rect.right, y: rect.top + rect.height * b.originFrac }
    // 'patch': origin is an arbitrary (x, y) inside the rect.
    return {
      x: rect.left + rect.width * b.originFrac,
      y: rect.top + rect.height * (b.originFracY ?? 0.5),
    }
  }

  // =========================================================
  // EMBERS — smoke billows off the top, live embers spiral up
  //   the flanks with a cooling color ramp (bright orange →
  //   amber → deep red → carbon) and motion-smear trails, and
  //   occasional sparks pop out of the seams. Dying embers
  //   sometimes crackle into 2–3 sparks. The button itself
  //   stays unlit — the heat is carried by what's around it.
  // =========================================================
  private initEmbers(effect: AttachedEffect): void {
    const count = 96
    const entities: EmberEntity[] = []
    for (let i = 0; i < count; i++) {
      const g = new Graphics()
      g.visible = false
      this.embersLayer.addChild(g)
      entities.push({
        g,
        x: 0,
        y: 0,
        vx: 0,
        vy: 0,
        life: 0,
        maxLife: 0,
        size: 1,
        phase: 0,
        pulseSpeed: 5,
        kind: 'ember',
        trailX: [0, 0, 0],
        trailY: [0, 0, 0],
        trailAcc: 0,
        wobblePhase: 0,
        inUse: false,
      })
    }
    effect.embers = {
      entities,
      spawnAcc: 0,
      smokeAcc: 0,
      sparkAcc: 0,
      color: effect.config.color,
    }
  }

  private tickEmbers(effect: AttachedEffect, rect: DOMRect, dt: number): void {
    const s = effect.embers
    if (!s) return

    // --- Spawn (only while hovered) ---
    if (effect.enabled) {
      s.spawnAcc += dt
      while (s.spawnAcc >= 0.035) {
        s.spawnAcc -= 0.035
        this.spawnEmberEntity(s, rect, 'ember')
      }
      s.smokeAcc += dt
      while (s.smokeAcc >= 0.09) {
        s.smokeAcc -= 0.09
        this.spawnEmberEntity(s, rect, 'smoke')
      }
      s.sparkAcc += dt
      while (s.sparkAcc >= 0.22) {
        s.sparkAcc -= 0.22
        this.spawnEmberEntity(s, rect, 'spark')
      }
    }

    // --- Update physics for all live entities ---
    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2
    const marginW = rect.width / 2 + 6
    const marginH = rect.height / 2 + 6

    for (const e of s.entities) {
      if (!e.inUse) continue
      e.life -= dt
      if (e.life <= 0) {
        // Crackle: a dying ember has a small chance to pop 2–3 sparks.
        if (e.kind === 'ember' && Math.random() < 0.22) {
          const popCount = 2 + Math.floor(Math.random() * 2)
          for (let i = 0; i < popCount; i++) {
            this.spawnSparkAt(s, e.x, e.y)
          }
        }
        e.inUse = false
        e.g.visible = false
        continue
      }

      // Button repulsion: softest along the sides, strongest deep inside —
      // guides the flow around the button rather than through it.
      const dx = e.x - cx
      const dy = e.y - cy
      const insideX = Math.max(0, 1 - Math.abs(dx) / marginW)
      const insideY = Math.max(0, 1 - Math.abs(dy) / marginH)
      const inside = insideX * insideY
      if (inside > 0.02) {
        const dirSign = dx >= 0 ? 1 : -1
        e.vx += dirSign * 360 * inside * dt
        e.vy -= 55 * inside * dt
      }

      if (e.kind === 'smoke') {
        // Smoke rises continuously, drifts with a sinusoidal wobble, and
        // expands slightly over its life. No net gravity — it's a buoyant
        // gas column.
        e.wobblePhase += dt * 2.1
        e.vx += Math.sin(e.wobblePhase) * 14 * dt
        e.vx *= 0.98
        e.vy += -6 * dt // slight continuous lift
        // Above the button — converge gently so the column reads tight, not
        // a diffuse cloud.
        if (e.y < rect.top - 2) {
          const pull = (cx - e.x) * 0.35
          e.vx += pull * dt * 0.08
        }
      } else if (e.kind === 'spark') {
        // Very light, very fast, near-ballistic short arcs.
        e.vy += 14 * dt
        e.vx *= 0.9
      } else {
        // Ember: buoyant rise with mild gravity and drag. Captures a trail
        // every ~45ms for the motion-smear effect.
        e.vy += 20 * dt
        e.vx *= 0.94
        e.trailAcc += dt
        if (e.trailAcc >= 0.045) {
          e.trailAcc -= 0.045
          // shift trail: [0] is most recent previous position
          e.trailX[2] = e.trailX[1]
          e.trailY[2] = e.trailY[1]
          e.trailX[1] = e.trailX[0]
          e.trailY[1] = e.trailY[0]
          e.trailX[0] = e.x
          e.trailY[0] = e.y
        }
        if (e.y < rect.top - 4) {
          const pull = (cx - e.x) * 1.0
          e.vx += pull * dt * 0.11
        }
      }

      e.x += e.vx * dt
      e.y += e.vy * dt
      e.phase += dt

      // --- Render ---
      e.g.clear()
      e.g.x = Math.round(e.x)
      e.g.y = Math.round(e.y)

      const t = e.life / e.maxLife // 1 → fresh, 0 → dying
      const fadeIn = Math.min(1, (1 - t) / 0.15)
      const fadeOut = t > 0.3 ? 1 : t / 0.3

      if (e.kind === 'smoke') {
        // Smoke grows a bit as it rises (1 → 1.4× its spawn size)
        const grown = Math.max(1, Math.round(e.size * (1 + (1 - t) * 0.4)))
        // Irregular shape: two slightly offset rectangles so it doesn't
        // read as a perfect square.
        const offY = Math.round(Math.sin(e.wobblePhase * 1.3) * 0.5)
        e.g.rect(-grown / 2, -grown / 2 + offY, grown, grown)
        e.g.fill({ color: EMBER_SMOKE_COLOR, alpha: 0.9 })
        e.g.rect(-grown / 2 + 1, -grown / 2 - 1 + offY, Math.max(1, grown - 2), 1)
        e.g.fill({ color: 0x8a8a8a, alpha: 0.7 })
        e.g.alpha = Math.min(fadeIn, fadeOut) * 0.35
      } else if (e.kind === 'spark') {
        e.g.rect(-0.5, -0.5, 1, 1)
        e.g.fill({ color: EMBER_SPARK_COLOR })
        // Bright, short-lived — no fadeIn, sharp decay.
        e.g.alpha = Math.min(1, fadeOut * 1.2)
      } else {
        // Ember: color cools as it ages.
        //   age 0.0–0.4 : bright orange (hot core)
        //   age 0.4–0.75: amber
        //   age 0.75–1.0: deep red → carbon
        const age = 1 - t // 0 → just spawned
        let coreColor: number
        if (age < 0.35) {
          coreColor = blendColor(EMBER_HOT_COLOR, s.color, age / 0.35)
        } else if (age < 0.7) {
          coreColor = blendColor(s.color, EMBER_COOL_COLOR, (age - 0.35) / 0.35)
        } else {
          coreColor = blendColor(EMBER_COOL_COLOR, EMBER_DEAD_COLOR, (age - 0.7) / 0.3)
        }
        // Very gentle scintillation — avoids a blinking feel while keeping
        // the core visually alive.
        const glow = 0.88 + 0.12 * Math.sin(e.phase * e.pulseSpeed)

        // Trail: render oldest → newest so the newest sits on top.
        for (let i = 2; i >= 0; i--) {
          const tx = e.trailX[i] - e.x
          const ty = e.trailY[i] - e.y
          if (tx === 0 && ty === 0) continue
          const trailAlpha = (0.35 - i * 0.09) * glow * fadeOut
          if (trailAlpha <= 0) continue
          // Trail fragments darken progressively — the heat is behind the head.
          const trailColor = blendColor(coreColor, EMBER_DEAD_COLOR, 0.2 + i * 0.2)
          e.g.rect(Math.round(tx) - 0.5, Math.round(ty) - 0.5, 1, 1)
          e.g.fill({ color: trailColor, alpha: trailAlpha })
        }

        // Core with a tiny brighter pixel on top to sell the incandescence.
        e.g.rect(-e.size / 2, -e.size / 2, e.size, e.size)
        e.g.fill({ color: coreColor, alpha: 1 })
        if (age < 0.55 && e.size >= 2) {
          e.g.rect(-e.size / 2, -e.size / 2, 1, 1)
          e.g.fill({ color: lighten(coreColor, 0.4), alpha: 0.9 })
        }
        e.g.alpha = Math.min(fadeIn, fadeOut) * glow
      }

      e.g.visible = true
    }
  }

  private spawnEmberEntity(s: EmberState, rect: DOMRect, kind: 'ember' | 'smoke' | 'spark'): void {
    const e = s.entities.find((en) => !en.inUse)
    if (!e) return

    const cx = rect.left + rect.width / 2
    let x: number, y: number, vx: number, vy: number

    if (kind === 'smoke') {
      // Smoke rises from the top edge of the button (and slightly above it).
      x = rect.left + (0.1 + Math.random() * 0.8) * rect.width
      y = rect.top - 2 - Math.random() * 4
      vx = (Math.random() - 0.5) * 16
      vy = -(20 + Math.random() * 26)
    } else if (kind === 'spark') {
      // Sparks emerge from the seams — sides or top edge — close to the button.
      const edge = Math.random()
      if (edge < 0.4) {
        x = rect.left - 1 - Math.random() * 3
        y = rect.top + rect.height * (0.2 + Math.random() * 0.7)
        vx = -(6 + Math.random() * 20)
      } else if (edge < 0.8) {
        x = rect.right + 1 + Math.random() * 3
        y = rect.top + rect.height * (0.2 + Math.random() * 0.7)
        vx = 6 + Math.random() * 20
      } else {
        x = rect.left + (0.2 + Math.random() * 0.6) * rect.width
        y = rect.top - 1 - Math.random() * 3
        vx = (Math.random() - 0.5) * 40
      }
      vy = -(60 + Math.random() * 70)
    } else {
      // Ember: side flanks + below center, same routing as before.
      const zone = Math.random()
      if (zone < 0.4) {
        x = rect.left - 2 - Math.random() * 11
        y = rect.bottom + Math.random() * 8 - Math.random() * rect.height * 0.4
        vx = -(2 + Math.random() * 7)
        vy = -(22 + Math.random() * 38)
      } else if (zone < 0.8) {
        x = rect.right + 2 + Math.random() * 11
        y = rect.bottom + Math.random() * 8 - Math.random() * rect.height * 0.4
        vx = 2 + Math.random() * 7
        vy = -(22 + Math.random() * 38)
      } else {
        x = rect.left + (0.15 + Math.random() * 0.7) * rect.width
        y = rect.bottom + 3 + Math.random() * 10
        vx = (x < cx ? -1 : 1) * (7 + Math.random() * 10)
        vy = -(18 + Math.random() * 28)
      }
    }

    e.x = x
    e.y = y
    e.vx = vx
    e.vy = vy
    if (kind === 'smoke') {
      e.life = 1.9 + Math.random() * 1.1
      e.size = 3 + (Math.random() < 0.4 ? 1 : 0)
    } else if (kind === 'spark') {
      e.life = 0.3 + Math.random() * 0.25
      e.size = 1
    } else {
      e.life = 1.0 + Math.random() * 0.9
      e.size = Math.random() < 0.22 ? 3 : Math.random() < 0.5 ? 2 : 1
    }
    e.maxLife = e.life
    e.kind = kind
    e.phase = Math.random() * Math.PI * 2
    e.pulseSpeed = 4 + Math.random() * 3
    e.wobblePhase = Math.random() * Math.PI * 2
    // Seed trail at spawn point so the first rendered frame doesn't show
    // a trail racing in from the origin (0,0).
    e.trailX[0] = x
    e.trailX[1] = x
    e.trailX[2] = x
    e.trailY[0] = y
    e.trailY[1] = y
    e.trailY[2] = y
    e.trailAcc = 0
    e.inUse = true

    e.g.clear()
    e.g.alpha = 0
    e.g.visible = true
  }

  private spawnSparkAt(s: EmberState, x: number, y: number): void {
    const e = s.entities.find((en) => !en.inUse)
    if (!e) return
    const angle = Math.random() * Math.PI * 2
    const speed = 25 + Math.random() * 35
    e.x = x
    e.y = y
    e.vx = Math.cos(angle) * speed
    e.vy = Math.sin(angle) * speed - 20
    e.kind = 'spark'
    e.size = 1
    e.life = 0.25 + Math.random() * 0.25
    e.maxLife = e.life
    e.phase = 0
    e.wobblePhase = 0
    e.trailX[0] = x
    e.trailX[1] = x
    e.trailX[2] = x
    e.trailY[0] = y
    e.trailY[1] = y
    e.trailY[2] = y
    e.trailAcc = 0
    e.inUse = true
    e.g.clear()
    e.g.alpha = 0
    e.g.visible = true
  }

  private tickAmbient(dt: number): void {
    for (const p of this.ambientParticles) {
      if (!p.inUse) continue
      p.life -= dt
      if (p.life <= 0) {
        // respawn
        this.seedAmbientParticle(p)
        continue
      }
      p.g.x += p.vx * dt
      p.g.y += p.vy * dt
      const t = p.life / p.maxLife
      // fade in first 15%, fade out last 30%
      const fadeIn = Math.min(1, (1 - t) / 0.15)
      const fadeOut = t < 0.3 ? t / 0.3 : 1
      p.g.alpha = Math.min(fadeIn, fadeOut) * 0.22
    }
  }

  private seedAmbient(): void {
    const w = this.app.screen.width
    const h = this.app.screen.height
    const count = 10
    for (let i = 0; i < count; i++) {
      const g = new Graphics()
      this.ambientLayer.addChild(g)
      const p: Particle = {
        g,
        vx: 0,
        vy: 0,
        gravity: 0,
        life: 0,
        maxLife: 1,
        size: 1,
        color: 0xd8cfb8,
        trail: false,
        fadeMode: 'late',
        inUse: true,
      }
      this.ambientParticles.push(p)
      // offset initial positions to avoid all spawning at once
      p.g.x = Math.random() * w
      p.g.y = Math.random() * h
      this.seedAmbientParticle(p, true)
    }
  }

  private seedAmbientParticle(p: Particle, keepPos = false): void {
    const w = this.app.screen.width
    const h = this.app.screen.height
    if (!keepPos) {
      p.g.x = Math.random() * w
      p.g.y = h + Math.random() * 40 // spawn below visible
    }
    p.vx = (Math.random() - 0.5) * 12
    p.vy = -(6 + Math.random() * 18)
    p.gravity = 0
    p.life = 12 + Math.random() * 14
    p.maxLife = p.life
    p.size = Math.random() < 0.2 ? 2 : 1
    p.color = Math.random() < 0.25 ? COLOR_GILD : COLOR_BONE
    p.g.clear()
    p.g.rect(0, 0, p.size, p.size)
    p.g.fill({ color: p.color })
    p.g.alpha = 0
    p.g.visible = true
  }

  private spawnSparkleParticle(effect: AttachedEffect, rect: DOMRect): void {
    const p = this.pickFreeParticle()
    if (!p) return
    // spawn along the card perimeter
    const edge = Math.floor(Math.random() * 4)
    let x = rect.left + Math.random() * rect.width
    let y = rect.top + Math.random() * rect.height
    switch (edge) {
      case 0:
        y = rect.top
        break
      case 1:
        y = rect.bottom
        break
      case 2:
        x = rect.left
        break
      case 3:
        x = rect.right
        break
    }
    p.vx = (Math.random() - 0.5) * 8
    p.vy = -(8 + Math.random() * 14)
    p.gravity = 12
    p.life = 0.9 + Math.random() * 0.6
    p.maxLife = p.life
    p.size = 1 + (Math.random() < 0.3 ? 1 : 0)
    p.color = effect.config.color
    p.fadeMode = 'late'
    this.drawParticle(p)
    p.g.x = x
    p.g.y = y
    p.g.alpha = 1
    p.g.visible = true
    p.inUse = true
  }

  private spawnPulseParticle(effect: AttachedEffect, rect: DOMRect): void {
    const p = this.pickFreeParticle()
    if (!p) return
    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2
    const angle = Math.random() * Math.PI * 2
    const speed = 12 + Math.random() * 16
    p.vx = Math.cos(angle) * speed
    p.vy = Math.sin(angle) * speed - 4
    p.gravity = 0
    p.life = 0.45 + Math.random() * 0.25
    p.maxLife = p.life
    p.size = 2
    p.color = effect.config.color
    p.fadeMode = 'linear'
    this.drawParticle(p)
    const r = Math.max(rect.width, rect.height) / 2
    p.g.x = cx + Math.cos(angle) * r * 0.4
    p.g.y = cy + Math.sin(angle) * r * 0.4
    p.g.alpha = 0.9
    p.g.visible = true
    p.inUse = true
  }

  private spawnRipple(effect: AttachedEffect, rect: DOMRect): void {
    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2
    for (const r of this.rings) {
      if (r.inUse) continue
      r.x = cx
      r.y = cy
      r.r = Math.min(rect.width, rect.height) / 2 - 2
      r.maxR = Math.min(rect.width, rect.height) / 2 + 18
      r.life = 0.8
      r.maxLife = r.life
      r.color = effect.config.color
      r.thickness = 1
      r.g.visible = true
      r.inUse = true
      this.drawRing(r)
      return
    }
  }

  private spawnTitleDrip(effect: AttachedEffect, rect: DOMRect): void {
    // spawn near the bottom-ish of the title, random X within bounds
    const x = rect.left + Math.random() * rect.width
    const y = rect.top + rect.height * (0.5 + Math.random() * 0.45)
    this.emitDrip({ x, y, color: effect.config.color, speed: 30 + Math.random() * 40 })
  }

  private initOrbit(effect: AttachedEffect): void {
    const count = 6
    let assigned = 0
    for (const o of this.orbits) {
      if (assigned >= count) break
      if (o.inUse) continue
      o.inUse = true
      o.effectId = effect.id
      o.angle = (assigned / count) * Math.PI * 2
      o.angularVel = 1.1
      o.radiusBase = 20
      o.radiusJitter = 2
      o.phase = Math.random() * Math.PI * 2
      o.size = 2
      o.color = effect.config.color
      o.baseAlpha = 0.7
      o.g.clear()
      o.g.rect(-1, -1, o.size, o.size)
      o.g.fill({ color: o.color })
      o.g.visible = false
      effect.orbitParticles.push(o)
      assigned++
    }
  }

  private pickFreeParticle(): Particle | null {
    for (const p of this.particles) {
      if (!p.inUse) return p
    }
    return null
  }

  private drawParticle(p: Particle): void {
    p.g.clear()
    p.g.rect(-p.size / 2, -p.size / 2, p.size, p.size)
    p.g.fill({ color: p.color })
  }

  private drawRing(r: Ring): void {
    r.g.clear()
    r.g.circle(0, 0, r.r)
    r.g.stroke({ color: r.color, width: r.thickness, alpha: 1 })
    r.g.x = r.x
    r.g.y = r.y
  }

  // =====================================================================
  // GODRAY — pixel-art rotating beams of divine gold light. Used on
  // treasure islands. Each "ray" is rendered as a row of discrete
  // square pixels stepping outward from a centre, fading with distance
  // and pulsing on its own phase. Sim-driven (no spawn cadence).
  // =====================================================================
  private initGodray(effect: AttachedEffect): void {
    const graphic = new Graphics()
    this.ambientLayer.addChild(graphic)
    const rayCount = 22
    const rays: GodraySpec[] = []
    for (let i = 0; i < rayCount; i++) {
      // Small per-ray angle jitter + length jitter so the radiation
      // doesn't read as a perfect sunburst — we want a scattered,
      // dusty pixel-art glow, not a wheel.
      const baseAngle = (i / rayCount) * Math.PI * 2
      const angleJitter = (Math.random() - 0.5) * 0.25
      rays.push({
        angle: baseAngle + angleJitter,
        length: 20 + Math.random() * 24, // 20..44 px
        phase: Math.random() * Math.PI * 2,
      })
    }
    effect.godray = {
      graphic,
      rays,
      rotation: 0,
      time: 0,
      color: effect.config.color,
    }
  }

  private tickGodray(effect: AttachedEffect, rect: DOMRect, dt: number): void {
    const s = effect.godray
    if (!s) return
    s.time += dt
    s.rotation += dt * 0.32

    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2
    const g = s.graphic
    g.clear()

    const colorLight = lighten(s.color, 0.55)
    const colorMid = lighten(s.color, 0.2)
    const colorDark = darken(s.color, 0.15)

    // Soft halo, built from 6 concentric *ellipses* instead of rects so
    // the shape reads as a glow rather than a stacked square. Each
    // layer contributes a small alpha (0.04) and the layers are sized
    // from outside-in; the composition fades smoothly from a hot
    // centre to transparent edges without the painted-rectangle
    // artefact the previous version produced.
    //
    // The ellipse is wider than it is tall (×1.6) — the hoard layout
    // is horizontal, so a flatter pool of light matches the silhouette
    // of what's actually glowing.
    const spotHalf = Math.max(22, Math.max(rect.width, rect.height) * 0.9)
    const haloBreathe = 0.88 + 0.12 * Math.sin(s.time * 2.1)
    const rings = 6
    for (let i = 0; i < rings; i++) {
      // Outer ring largest and faintest; inner ring smallest and
      // brightest. Accumulated alpha at the centre is ~6 × 0.04 = 0.24.
      const t = i / rings
      const rx = spotHalf * (1 - t * 0.85) * haloBreathe
      const ry = rx / 1.6
      const color = i < 2 ? colorLight : i < 4 ? colorMid : s.color
      g.ellipse(cx, cy, rx, ry)
      g.fill({ color, alpha: 0.04 })
    }

    // A small extra-bright hot core right on the hoard centre so the
    // glow always has a well-defined source.
    const core = 0.7 + 0.3 * Math.sin(s.time * 3)
    g.ellipse(cx, cy, 10 * core + 4, 7 * core + 3)
    g.fill({ color: colorLight, alpha: 0.18 })

    // Rays — diffused and pixel-art dusty. Each pip gets a perpendicular
    // jitter of up to ±1 px so beams don't read as precise sunbursts
    // but as scattered pixel dust. Alpha is halved compared to the
    // previous pass so they blend into the halo rather than pop out.
    const innerSkip = Math.max(5, Math.round(spotHalf * 0.7))
    const rayScale = Math.max(1, spotHalf / 30)
    for (const ray of s.rays) {
      const a = ray.angle + s.rotation
      const pulse = 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(s.time * 3.2 + ray.phase))
      const len = ray.length * pulse * rayScale
      const dx = Math.cos(a)
      const dy = Math.sin(a)
      // Perpendicular unit for jitter.
      const px = -dy
      const py = dx

      const steps = Math.max(10, Math.round(len))
      for (let i = innerSkip; i < innerSkip + steps; i++) {
        const t = (i - innerSkip) / steps
        const r = i
        // Subpixel jitter that's stable across frames for this (ray, i)
        // via a noise derived from the ray phase — avoids frame-to-
        // frame shimmer while still looking scattered.
        const jitterSeed = Math.sin(ray.phase * 17 + i * 2.3)
        const jitter = Math.round(jitterSeed * 1.2)
        const x = Math.round(cx + dx * r + px * jitter)
        const y = Math.round(cy + dy * r + py * jitter)
        const size = t < 0.22 ? 2 : 1
        const alpha = Math.pow(1 - t, 1.5) * pulse * 0.55
        if (alpha < 0.05) continue
        const color = t < 0.3 ? colorLight : t < 0.7 ? s.color : colorDark
        g.rect(x - size / 2, y - size / 2, size, size)
        g.fill({ color, alpha })
      }
    }

    // Dust motes — a few single-pixel twinkles tightly clustered on
    // the halo's mid-band (not spraying wide) so they read as dust
    // kicked up from the hoard rather than sparkles floating off into
    // the cap.
    const moteCount = 10
    for (let m = 0; m < moteCount; m++) {
      const moteSeed = m * 0.618
      const moteAngle = moteSeed * Math.PI * 2 + s.time * 0.25
      const moteR = spotHalf * (0.55 + 0.3 * ((moteSeed * 7) % 1))
      const twinkle = 0.5 + 0.5 * Math.sin(s.time * 4 + moteSeed * 9)
      if (twinkle < 0.3) continue
      const mx = Math.round(cx + Math.cos(moteAngle) * moteR)
      const my = Math.round(cy + Math.sin(moteAngle) * moteR * 0.55)
      g.rect(mx, my, 1, 1)
      g.fill({ color: colorLight, alpha: twinkle * 0.55 })
    }
  }

  // =====================================================================
  // COINS — gold pips orbit the attached element on an ellipse (isometric
  // top-down), each bobbing slightly on its own phase. Simple, evocative,
  // signals "shop" at a glance.
  // =====================================================================
  private initCoins(effect: AttachedEffect): void {
    const poolSize = 32
    const entities: CoinEntity[] = []
    for (let i = 0; i < poolSize; i++) {
      const g = new Graphics()
      g.visible = false
      this.ambientLayer.addChild(g)
      entities.push({
        g,
        x: 0,
        y: 0,
        vx: 0,
        vy: 0,
        rotPhase: 0,
        rotSpeed: 0,
        age: 0,
        maxAge: 0,
        inUse: false,
      })
    }
    effect.coins = {
      entities,
      spawnAcc: 0,
      time: 0,
      color: effect.config.color,
    }
  }

  private tickCoins(effect: AttachedEffect, rect: DOMRect, dt: number): void {
    const s = effect.coins
    if (!s) return
    s.time += dt

    // Spawn a new coin every ~120ms while the effect is enabled.
    if (effect.enabled) {
      s.spawnAcc += dt
      const cadence = 0.12
      while (s.spawnAcc >= cadence) {
        s.spawnAcc -= cadence
        this.spawnCoinFromStack(s, rect)
      }
    }

    const gravity = 220 // px/s²
    const colorLight = lighten(s.color, 0.5)
    const colorMid = lighten(s.color, 0.1)
    const colorDark = darken(s.color, 0.4)

    for (const c of s.entities) {
      if (!c.inUse) continue
      c.age += dt
      if (c.age >= c.maxAge) {
        c.inUse = false
        c.g.visible = false
        continue
      }

      // Physics step.
      c.vy += gravity * dt
      c.vx *= 0.995
      c.x += c.vx * dt
      c.y += c.vy * dt
      c.rotPhase += c.rotSpeed * dt

      // Render — coin width oscillates with rotPhase so the coin reads
      // as a spinning disc: 4 px (full face) → 2 px → 1 px (edge-on)
      // → 2 px → 4 px …
      const spin = Math.abs(Math.cos(c.rotPhase))
      const w = spin > 0.75 ? 4 : spin > 0.35 ? 3 : spin > 0.1 ? 2 : 1
      const h = 4
      const offX = -Math.floor(w / 2)
      const offY = -Math.floor(h / 2)
      c.g.clear()
      c.g.rect(offX, offY, w, h)
      c.g.fill({ color: colorDark })
      if (w > 2) {
        c.g.rect(offX + 1, offY + 1, w - 2, h - 2)
        c.g.fill({ color: colorMid })
      }
      c.g.rect(offX + 1, offY + 1, Math.max(1, w - 2), 1)
      c.g.fill({ color: s.color })
      c.g.rect(offX + 1, offY + 1, 1, 1)
      c.g.fill({ color: colorLight })
      if (w >= 4) {
        c.g.rect(offX + 2, offY + 1, 1, 1)
        c.g.fill({ color: 0xffffff })
      }
      c.g.x = Math.round(c.x)
      c.g.y = Math.round(c.y)

      // Fade in over first 12% of life, out over last 25%.
      const t = c.age / c.maxAge
      const fadeIn = Math.min(1, t / 0.12)
      const fadeOut = t > 0.75 ? 1 - (t - 0.75) / 0.25 : 1
      c.g.alpha = fadeIn * fadeOut
      c.g.visible = true
    }
  }

  private spawnCoinFromStack(s: CoinState, rect: DOMRect): void {
    const c = s.entities.find((e) => !e.inUse)
    if (!c) return
    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height * 0.35
    const horiz = (Math.random() - 0.5) * 2
    c.x = cx
    c.y = cy
    c.vx = horiz * (25 + Math.random() * 30)
    c.vy = -(60 + Math.random() * 45)
    c.rotPhase = Math.random() * Math.PI * 2
    c.rotSpeed = 10 + Math.random() * 6
    c.age = 0
    c.maxAge = 1.0 + Math.random() * 0.5
    c.inUse = true
    c.g.visible = true
  }

  // =====================================================================
  // SPRING — water drops pour out of an island's pond, run to the
  // cap's edge, then fall as cascades. Continuous, never-ending. Used
  // for `event-spring` islands.
  // =====================================================================
  private initSpring(effect: AttachedEffect): void {
    const ripple = new Graphics()
    this.dripLayer.addChild(ripple)
    const poolSize = 64
    const drops: SpringDrop[] = []
    for (let i = 0; i < poolSize; i++) {
      const g = new Graphics()
      g.visible = false
      this.dripLayer.addChild(g)
      drops.push({
        g,
        x: 0,
        y: 0,
        vx: 0,
        vy: 0,
        age: 0,
        maxAge: 0,
        trailX: [0, 0, 0],
        trailY: [0, 0, 0],
        trailAcc: 0,
        inUse: false,
      })
    }
    effect.spring = {
      ripple,
      drops,
      spawnAcc: 0,
      time: 0,
      color: effect.config.color,
    }
  }

  private tickSpring(effect: AttachedEffect, rect: DOMRect, dt: number): void {
    const s = effect.spring
    if (!s) return
    s.time += dt

    // --- Spawn cadence: a steady stream of droplets coming out of
    // the pond. 35 ms gap → ~28 drops/s, four pre-set angular streams
    // (left, front-left, front-right, right) so the flow reads as
    // "rivers off the cap" rather than random spray.
    if (effect.enabled) {
      s.spawnAcc += dt
      const cadence = 0.04
      while (s.spawnAcc >= cadence) {
        s.spawnAcc -= cadence
        this.spawnSpringDrop(s, rect)
      }
    }

    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2

    // --- Pond ripples — slow concentric breathing centred on the pond,
    // continuously running so the water reads as alive even if all
    // drops are mid-air. Two rings, brightest in the centre.
    s.ripple.clear()
    const colorLight = lighten(s.color, 0.45)
    const colorDark = darken(s.color, 0.25)
    const phase1 = (s.time * 0.9) % 1
    const phase2 = ((s.time * 0.9 + 0.5) % 1)
    drawRipple(s.ripple, cx, cy, phase1, s.color, colorLight)
    drawRipple(s.ripple, cx, cy, phase2, s.color, colorLight)

    // --- Drops physics + render.
    const gravity = 200
    for (const d of s.drops) {
      if (!d.inUse) continue
      d.age += dt
      if (d.age >= d.maxAge) {
        d.inUse = false
        d.g.visible = false
        continue
      }
      // Phase 1 — flowing across the cap (small downward accel only).
      // Phase 2 — falling off the edge (full gravity + slight drag).
      const offEdge = d.age > 0.45
      d.vy += (offEdge ? gravity : 30) * dt
      d.vx *= 0.995
      d.x += d.vx * dt
      d.y += d.vy * dt
      // Trail — capture position every 35 ms.
      d.trailAcc += dt
      if (d.trailAcc >= 0.035) {
        d.trailAcc -= 0.035
        d.trailX[2] = d.trailX[1]
        d.trailY[2] = d.trailY[1]
        d.trailX[1] = d.trailX[0]
        d.trailY[1] = d.trailY[0]
        d.trailX[0] = d.x
        d.trailY[0] = d.y
      }
      // Render.
      d.g.clear()
      // Trail (3 stale positions, fading).
      for (let i = 2; i >= 0; i--) {
        const tx = d.trailX[i]
        const ty = d.trailY[i]
        if (tx === 0 && ty === 0) continue
        const trailAlpha = 0.32 - i * 0.09
        if (trailAlpha <= 0) continue
        d.g.rect(Math.round(tx) - cx - 0.5, Math.round(ty) - cy - 0.5, 1, 1)
        d.g.fill({ color: colorDark, alpha: trailAlpha })
      }
      // Head — 1 px bright cyan.
      d.g.rect(Math.round(d.x) - cx - 0.5, Math.round(d.y) - cy - 0.5, 1, 1)
      d.g.fill({ color: colorLight })
      d.g.x = cx
      d.g.y = cy
      d.g.alpha = 1
      d.g.visible = true
    }
  }

  private spawnSpringDrop(s: SpringState, rect: DOMRect): void {
    const d = s.drops.find((x) => !x.inUse)
    if (!d) return
    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2
    // 4 stream directions, biased toward the front of the cap so most
    // water visibly cascades down past the lower edge of the rock.
    //   −0.6π → front-left (down + left)
    //   −0.4π → front-right (down + right)
    //   −0.95π → far left (slight down)
    //    0.95π → far right (slight down)
    //
    // Note: in screen coords +Y is down, so vy > 0 means going forward
    // off the cap front. The streams have positive vx for right,
    // negative for left, and a small vy to start so they roll outward.
    const streamPick = Math.floor(Math.random() * 4)
    let vx: number, vy: number
    switch (streamPick) {
      case 0: // front-left
        vx = -22 - Math.random() * 8
        vy = 8 + Math.random() * 4
        break
      case 1: // front-right
        vx = 22 + Math.random() * 8
        vy = 8 + Math.random() * 4
        break
      case 2: // far left
        vx = -28 - Math.random() * 6
        vy = -2 + Math.random() * 6
        break
      case 3: // far right
      default:
        vx = 28 + Math.random() * 6
        vy = -2 + Math.random() * 6
        break
    }
    // Spawn jitter inside the pond rim (radius ≈ 4 px in screen).
    const jitterAngle = Math.random() * Math.PI * 2
    const jitterR = Math.random() * 2.5
    d.x = cx + Math.cos(jitterAngle) * jitterR
    d.y = cy + Math.sin(jitterAngle) * jitterR * 0.5
    d.vx = vx
    d.vy = vy
    d.age = 0
    d.maxAge = 1.6 + Math.random() * 0.6
    // Seed trail so first frame doesn't streak from (0, 0).
    for (let i = 0; i < 3; i++) {
      d.trailX[i] = d.x
      d.trailY[i] = d.y
    }
    d.trailAcc = 0
    d.inUse = true
    d.g.visible = true
  }
}

/** Draw a single concentric ripple ring expanding from (cx, cy). */
function drawRipple(
  g: Graphics,
  cx: number,
  cy: number,
  phase: number,
  color: number,
  colorLight: number,
): void {
  // Phase 0..1: ring grows from r=2 to r=10, alpha fades out.
  const r = 2 + phase * 8
  const alpha = (1 - phase) * 0.5
  if (alpha < 0.02) return
  // Build a ring as 16 sample points (poor-man's stroke at low res).
  const segments = 18
  for (let i = 0; i < segments; i++) {
    const a = (i / segments) * Math.PI * 2
    const x = Math.round(cx + Math.cos(a) * r)
    const y = Math.round(cy + Math.sin(a) * r * 0.45) // ellipse aspect
    g.rect(x, y, 1, 1)
    g.fill({ color: i % 3 === 0 ? colorLight : color, alpha })
  }
}

// =====================================================================
// Recipes
// =====================================================================

interface BurstRecipe {
  count: number
  speedMin: number
  speedMax: number
  gravity: number
  lifeMin: number
  lifeMax: number
  sizeMin: number
  sizeMax: number
  upwardBias: boolean
  spreadAngle: number
  fadeMode: 'linear' | 'late'
}

const BURST_RECIPES: Record<BurstVariant, BurstRecipe> = {
  primary: {
    // sparks
    count: 14,
    speedMin: 150,
    speedMax: 280,
    gravity: 420,
    lifeMin: 0.28,
    lifeMax: 0.45,
    sizeMin: 1,
    sizeMax: 2,
    upwardBias: true,
    spreadAngle: Math.PI * 1.4,
    fadeMode: 'linear',
  },
  danger: {
    // heavy blood droplets
    count: 9,
    speedMin: 80,
    speedMax: 180,
    gravity: 700,
    lifeMin: 0.45,
    lifeMax: 0.7,
    sizeMin: 2,
    sizeMax: 4,
    upwardBias: true,
    spreadAngle: Math.PI * 1.1,
    fadeMode: 'late',
  },
  default: {
    // coin dust
    count: 10,
    speedMin: 100,
    speedMax: 200,
    gravity: 380,
    lifeMin: 0.35,
    lifeMax: 0.55,
    sizeMin: 1,
    sizeMax: 2,
    upwardBias: false,
    spreadAngle: Math.PI * 2,
    fadeMode: 'linear',
  },
  ghost: {
    // smoke puff
    count: 6,
    speedMin: 40,
    speedMax: 90,
    gravity: -40, // rises
    lifeMin: 0.35,
    lifeMax: 0.6,
    sizeMin: 2,
    sizeMax: 3,
    upwardBias: true,
    spreadAngle: Math.PI * 0.6,
    fadeMode: 'late',
  },
}

const DEFAULT_ATTACH_COLOR: Record<AttachKind, number> = {
  aura: COLOR_GREEN,
  ripple: COLOR_CYAN,
  pulse: COLOR_RED,
  sparkle: COLOR_VIOLET,
  drips: COLOR_BONE,
  'drip-pool': COLOR_RED,
  grass: COLOR_GREEN,
  embers: 0xd4a147,
  godray: 0xf0c050, // radiant gold
  coins: 0xf0c040, // coin gold
  spring: 0x6ec3d4, // pond cyan
}

const ATTACH_CADENCE: Record<AttachKind, number> = {
  aura: 0,
  ripple: 0,
  pulse: 0.42,
  sparkle: 0.8,
  drips: 0.35,
  'drip-pool': 0,
  grass: 0,
  embers: 0.055,
  godray: 0, // fully sim-driven, no per-tick spawn
  coins: 0, // fully sim-driven
  spring: 0, // fully sim-driven
}
