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

export type AttachKind = 'aura' | 'ripple' | 'pulse' | 'sparkle' | 'drips'

export interface AttachConfig {
  color?: number
  intensity?: number
}

// --------------------- color helpers ---------------------

const COLOR_GREEN = 0x9ae66e
const COLOR_RED = 0xd45a5a
const COLOR_GILD = 0xb58b3a
const COLOR_BONE = 0xd8cfb8
const COLOR_VIOLET = 0x9a7bd4
const COLOR_CYAN = 0x6ec3d4
const COLOR_DIM = 0x6b6b6b

const BURST_COLORS: Record<BurstVariant, number> = {
  primary: COLOR_GREEN,
  danger: COLOR_RED,
  default: COLOR_GILD,
  ghost: COLOR_DIM,
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
  fadeMode: 'linear' | 'late'
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
    this.app.stage.addChild(this.particlesLayer)
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

    this.attached.push(effect)

    return { id, detach: () => this.detach(id) }
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
      if (p.fadeMode === 'late') {
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
      // refresh rect each frame (cheap enough for current scale)
      effect.lastRect = effect.el.getBoundingClientRect()

      if (!effect.enabled) continue

      const rect = effect.lastRect

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
}

const ATTACH_CADENCE: Record<AttachKind, number> = {
  aura: 0, // handled by orbit
  ripple: 0, // handled via rippleAcc in engine
  pulse: 0.42,
  sparkle: 0.8,
  drips: 0.35,
}
