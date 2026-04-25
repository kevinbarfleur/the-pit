import { Application, Container } from 'pixi.js'
import { useEffect, useRef } from 'react'
import {
  createCharacter,
  disposeCharacter,
  updateCharacter,
} from '../../pixi/CharacterEngine'
import { CHARACTER_PALETTE } from '../../game/characters/palette'
import type { CharacterDef } from '../../game/characters/types'

interface CharacterSpriteProps {
  def: CharacterDef
  /** CSS pixel size of the host. */
  width: number
  height: number
  /** Pixel-art upscale factor inside the canvas. */
  scale: number
  /** Vertical anchor as a fraction of `height` (0 = top, 1 = bottom). */
  anchorY?: number
  className?: string
  /** Optional inline style merged onto the host (positioning, etc). */
  style?: React.CSSProperties
}

/**
 * Mounts a single rigged character in its own Pixi Application,
 * sized to a CSS box. Used as the standalone "render this NPC here"
 * primitive — a shop island's merchant, a node's quest-giver, etc.
 *
 * One Pixi context per sprite. Cheap enough for the handful that fit
 * on the visible map at once; if it ever bites, swap for a shared
 * pool keyed by visible slots.
 */
export function CharacterSprite({
  def,
  width,
  height,
  scale,
  anchorY = 0.95,
  className,
  style,
}: CharacterSpriteProps) {
  const hostRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    const host = hostRef.current
    if (!host) return
    const app = new Application()
    let cancelled = false
    let cleanup: (() => void) | null = null

    void app
      .init({
        width,
        height,
        background: 0x000000,
        backgroundAlpha: 0,
        antialias: false,
        roundPixels: true,
        resolution: 1,
        autoDensity: false,
      })
      .then(() => {
        if (cancelled) {
          app.destroy(true, { children: true })
          return
        }
        host.appendChild(app.canvas)
        app.canvas.style.imageRendering = 'pixelated'
        app.canvas.style.width = `${width}px`
        app.canvas.style.height = `${height}px`

        const char = createCharacter(def, CHARACTER_PALETTE)
        const root = char.root as Container
        root.scale.set(scale)
        char.baseX = width / 2
        char.baseY = Math.round(height * anchorY)
        root.x = char.baseX
        root.y = char.baseY
        app.stage.addChild(root)

        let t = 0
        const tickFn = (tk: { deltaTime: number }) => {
          const dt = tk.deltaTime
          t += dt
          updateCharacter(char, t, dt)
        }
        app.ticker.add(tickFn)

        cleanup = () => {
          app.ticker.remove(tickFn)
          disposeCharacter(char)
          app.destroy(true, { children: true })
        }
      })

    return () => {
      cancelled = true
      if (cleanup) cleanup()
    }
  }, [def, width, height, scale, anchorY])

  return (
    <div
      ref={hostRef}
      className={className}
      style={{
        width: `${width}px`,
        height: `${height}px`,
        pointerEvents: 'none',
        ...style,
      }}
      aria-hidden="true"
    />
  )
}
