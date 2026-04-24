import { Application, Graphics } from 'pixi.js'

interface ImpactOptions {
  x: number
  y: number
  color?: string
  count?: number
  spread?: number
}

interface Particle {
  g: Graphics
  vx: number
  vy: number
  life: number
  maxLife: number
  size: number
  inUse: boolean
}

const POOL_SIZE = 64
const GRAVITY = 600
const DEFAULT_COUNT = 12

function hexToNumber(hex: string): number {
  return parseInt(hex.replace('#', ''), 16)
}

export class ImpactLayer {
  private app: Application
  private container: HTMLElement
  private pool: Particle[] = []
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
    canvas.style.zIndex = '900'
    canvas.style.imageRendering = 'pixelated'
    this.container.appendChild(canvas)

    for (let i = 0; i < POOL_SIZE; i++) {
      const g = new Graphics()
      g.visible = false
      this.app.stage.addChild(g)
      this.pool.push({ g, vx: 0, vy: 0, life: 0, maxLife: 0, size: 2, inUse: false })
    }

    this.app.ticker.add((ticker) => {
      const dt = ticker.deltaMS / 1000
      for (const p of this.pool) {
        if (!p.inUse) continue
        p.life -= dt
        if (p.life <= 0) {
          p.inUse = false
          p.g.visible = false
          continue
        }
        p.g.x += p.vx * dt
        p.g.y += p.vy * dt
        p.vy += GRAVITY * dt
        const t = p.life / p.maxLife
        p.g.alpha = t > 0.5 ? 1 : t * 2
      }
    })

    this.ready = true
  }

  emitAt({ x, y, color = '#b58b3a', count = DEFAULT_COUNT, spread = 220 }: ImpactOptions): void {
    if (!this.ready) return
    const colorNum = hexToNumber(color)
    let emitted = 0
    for (const p of this.pool) {
      if (emitted >= count) break
      if (p.inUse) continue
      const angle = Math.random() * Math.PI * 2
      const speed = spread * (0.5 + Math.random() * 0.8)
      p.vx = Math.cos(angle) * speed
      p.vy = Math.sin(angle) * speed - 120
      p.life = 0.3 + Math.random() * 0.25
      p.maxLife = p.life
      p.size = 2 + Math.floor(Math.random() * 2)
      p.g.clear()
      p.g.rect(-p.size / 2, -p.size / 2, p.size, p.size)
      p.g.fill({ color: colorNum })
      p.g.x = x
      p.g.y = y
      p.g.alpha = 1
      p.g.visible = true
      p.inUse = true
      emitted++
    }
  }

  dispose(): void {
    this.disposed = true
    if (this.ready) {
      this.app.destroy(true, { children: true })
    }
  }
}
