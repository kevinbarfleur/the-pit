import { Application, Container, Graphics, Text } from 'pixi.js'
import { useEffect, useRef, useState } from 'react'
import {
  ATTACK_DURATION,
  HURT_DURATION,
  createCharacter,
  disposeCharacter,
  triggerState,
  updateCharacter,
} from '../../pixi/CharacterEngine'
import { CHARACTER_PALETTE } from '../../game/characters/palette'
import { MARAUDER } from '../../game/characters/defs/marauder'
import { WITCH } from '../../game/characters/defs/witch'
import { SKELETON } from '../../game/characters/defs/skeleton'
import { SPECTRE } from '../../game/characters/defs/spectre'
import { MERCHANT } from '../../game/characters/defs/merchant'
import { BANDIT } from '../../game/characters/defs/bandit'
import { TEMPLAR } from '../../game/characters/defs/templar'
import { DEMON } from '../../game/characters/defs/demon'
import { ZOMBIE } from '../../game/characters/defs/zombie'
import { CRAB } from '../../game/characters/defs/crab'
import { ARCHER } from '../../game/characters/defs/archer'
import { DUMMY } from '../../game/characters/defs/dummy'
import type {
  CharacterDef,
  CharacterInstance,
  CharacterState,
} from '../../game/characters/types'
import styles from './Bestiary.module.css'

/**
 * Bestiary kit page. Renders all rigged characters in a 2-row grid,
 * each paired with a training pell to anchor the strike direction.
 * Buttons trigger idle / attack / hurt across the whole roster
 * (cascaded by 80 ms so the animations read as a wave). A bones
 * overlay reveals the rig.
 */

const CHARACTERS: readonly CharacterDef[] = [
  MARAUDER,
  WITCH,
  SKELETON,
  SPECTRE,
  MERCHANT,
  BANDIT,
  TEMPLAR,
  DEMON,
  ZOMBIE,
  CRAB,
  ARCHER,
]
const STAGE_W = 1280
const STAGE_H = 720
// 11 characters across 2 rows ⇒ 6 cols. SCALE drops from 7 → 4 to fit
// the slot width (≈ 213 CSS px) without overlapping into the dummy.
const SCALE = 4
const DUMMY_OFFSET_X = 65
const TRAIL_DURATION = 12
const HIT_TRIGGER_PROGRESS = 0.5
const TRAIL_START = 0.3
const TRAIL_END = 0.65

interface SceneCharacter {
  char: CharacterInstance
  dummy: CharacterInstance
  shadow: Graphics
  dummyShadow: Graphics
  trail: { x: number; y: number; age: number }[]
  hitTriggered: boolean
}

export function Bestiary() {
  const hostRef = useRef<HTMLDivElement | null>(null)
  const sceneRef = useRef<SceneCharacter[]>([])
  const [active, setActive] = useState<CharacterState>('idle')
  const [showBones, setShowBones] = useState(false)

  useEffect(() => {
    const host = hostRef.current
    if (!host) return
    const app = new Application()
    let cancelled = false
    let cleanup: (() => void) | null = null

    void app
      .init({
        width: STAGE_W,
        height: STAGE_H,
        background: 0x000000,
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

        // Décor — étoiles + ligne de sol.
        const stars = new Graphics()
        for (let i = 0; i < 70; i++) {
          const sx = Math.random() * STAGE_W
          const sy = Math.random() * STAGE_H * 0.5
          const w = Math.random() < 0.85 ? 1 : 2
          const h = Math.random() < 0.85 ? 1 : 2
          stars
            .rect(sx, sy, w, h)
            .fill({ color: 0xc8b89a, alpha: 0.2 + Math.random() * 0.4 })
        }
        app.stage.addChild(stars)

        // Layout grid : N persos, 2 rangées (1 si ≤ 6).
        const total = CHARACTERS.length
        const cols = Math.ceil(total / 2)
        const rows = Math.ceil(total / cols)
        const slotW = STAGE_W / cols
        const rowsY: readonly number[] =
          rows === 1 ? [STAGE_H * 0.78] : [STAGE_H * 0.42, STAGE_H * 0.85]

        // Une ligne de sol par rangée (alignée pile sous chaque slotY).
        const ground = new Graphics()
        for (const ry of rowsY) {
          ground.rect(0, ry, STAGE_W, 1).fill({ color: 0x2a1a22, alpha: 0.7 })
          ground.rect(0, ry + 1, STAGE_W, 1).fill({ color: 0x1a0c12, alpha: 0.4 })
        }
        app.stage.addChild(ground)

        // Personnages + plaques + ombres + dummies.
        const scene: SceneCharacter[] = CHARACTERS.map((def, i) => {
          const col = i % cols
          const row = Math.floor(i / cols)
          const slotY = rowsY[row]!

          const char = createCharacter(def, CHARACTER_PALETTE)
          ;(char.root as Container).scale.set(SCALE)
          // Centre du slot décalé légèrement à gauche pour laisser de la
          // place au dummy à sa droite (DUMMY_OFFSET_X dans le slot).
          char.baseX = slotW * (col + 0.35)
          char.baseY = slotY
          ;(char.root as Container).x = char.baseX
          ;(char.root as Container).y = char.baseY

          const shadow = new Graphics()
          shadow.ellipse(0, 0, 38, 4).fill({ color: 0x000000, alpha: 0.55 })
          shadow.x = char.baseX
          shadow.y = char.baseY + 4
          app.stage.addChild(shadow)
          app.stage.addChild(char.root as Container)

          // Plaque + ligne sang. Décalée à droite pour qu'elle reste
          // entre le perso et le dummy plutôt que sous l'un ou l'autre.
          const plate = new Text({
            text: def.name,
            style: {
              fontFamily: 'Cinzel Decorative, serif',
              fontWeight: '700',
              fontSize: 11,
              fill: 0x8a6a2a,
              letterSpacing: 2,
            },
          })
          plate.anchor.set(0.5, 0)
          plate.x = char.baseX + 32
          plate.y = char.baseY + 26
          app.stage.addChild(plate)

          const tick = new Graphics()
          tick.rect(-12, 0, 24, 1).fill(0x6e1818)
          tick.x = char.baseX + 32
          tick.y = char.baseY + 22
          app.stage.addChild(tick)

          // Dummy à droite.
          const dummy = createCharacter(DUMMY, CHARACTER_PALETTE)
          ;(dummy.root as Container).scale.set(SCALE)
          dummy.baseX = char.baseX + DUMMY_OFFSET_X
          dummy.baseY = char.baseY
          ;(dummy.root as Container).x = dummy.baseX
          ;(dummy.root as Container).y = dummy.baseY

          const dummyShadow = new Graphics()
          dummyShadow.ellipse(0, 0, 30, 4).fill({ color: 0x000000, alpha: 0.55 })
          dummyShadow.x = dummy.baseX
          dummyShadow.y = dummy.baseY + 4
          app.stage.addChild(dummyShadow)
          app.stage.addChild(dummy.root as Container)

          return { char, dummy, shadow, dummyShadow, trail: [], hitTriggered: false }
        })
        sceneRef.current = scene

        // Trails par-dessus tout.
        const trailGfx = new Graphics()
        app.stage.addChild(trailGfx)

        // Bones overlay.
        const bonesGfx = new Graphics()
        bonesGfx.visible = false
        app.stage.addChild(bonesGfx)

        let t = 0
        const tickFn = (tk: { deltaTime: number }) => {
          const dt = tk.deltaTime
          t += dt

          for (const entry of scene) {
            const { char, dummy } = entry
            updateCharacter(char, t, dt)

            if (char.state === 'attack') {
              const p = char.stateAge / ATTACK_DURATION
              if (p >= HIT_TRIGGER_PROGRESS && !entry.hitTriggered) {
                triggerState(dummy, 'hurt')
                entry.hitTriggered = true
              }
            } else {
              entry.hitTriggered = false
            }

            if (char.state === 'attack' && char.parts.weapon) {
              const p = char.stateAge / ATTACK_DURATION
              if (p >= TRAIL_START && p <= TRAIL_END) {
                const wSpec = char.def.parts.weapon!
                const tipLocal = { x: wSpec.pivot.x, y: wSpec.grid.length - 1 }
                const tw = (char.parts.weapon as Container).toGlobal(tipLocal)
                entry.trail.push({ x: tw.x, y: tw.y, age: 0 })
              }
            }
            for (const pt of entry.trail) pt.age += 1
            entry.trail = entry.trail.filter((pt) => pt.age < TRAIL_DURATION)
          }

          for (const entry of scene) {
            updateCharacter(entry.dummy, t, dt)
          }

          trailGfx.clear()
          for (const entry of scene) {
            if (entry.trail.length < 2) continue
            for (let i = 0; i < entry.trail.length - 1; i++) {
              const a = entry.trail[i]!
              const b = entry.trail[i + 1]!
              const lifeFactor = 1 - a.age / TRAIL_DURATION
              const alpha = lifeFactor * 0.7
              const width = 1 + lifeFactor * 4
              trailGfx
                .moveTo(a.x, a.y)
                .lineTo(b.x, b.y)
                .stroke({ color: 0xfff0a8, width, alpha })
            }
          }

          bonesGfx.clear()
          if (bonesGfx.visible) {
            for (const entry of scene) {
              const { char } = entry
              for (const node of char.def.rig) {
                const child = char.parts[node.part] as Container | undefined
                const parent = node.parent
                  ? (char.parts[node.parent] as Container | undefined)
                  : (char.root as Container)
                if (!child || !parent) continue
                const a = parent.toGlobal({ x: 0, y: 0 })
                const b = child.toGlobal({ x: 0, y: 0 })
                bonesGfx
                  .moveTo(a.x, a.y)
                  .lineTo(b.x, b.y)
                  .stroke({ color: 0x5a8294, width: 2, alpha: 0.5 })
              }
              for (const part of Object.values(char.parts)) {
                const p = (part as Container).toGlobal({ x: 0, y: 0 })
                bonesGfx.circle(p.x, p.y, 5).fill({ color: 0x000000, alpha: 0.6 })
                bonesGfx.circle(p.x, p.y, 4).fill(0x5a8294)
                bonesGfx.circle(p.x, p.y, 2).fill(0x000000)
              }
            }
          }
        }
        app.ticker.add(tickFn)

        cleanup = () => {
          app.ticker.remove(tickFn)
          for (const entry of scene) {
            disposeCharacter(entry.char)
            disposeCharacter(entry.dummy)
          }
          sceneRef.current = []
          app.destroy(true, { children: true })
        }

        // Expose bones overlay control via a closure-captured ref.
        ;(host as HTMLDivElement & { __bones?: Graphics }).__bones = bonesGfx
      })

    return () => {
      cancelled = true
      if (cleanup) cleanup()
    }
  }, [])

  // React → Pixi: trigger states and toggle bones from the buttons.
  useEffect(() => {
    const scene = sceneRef.current
    if (scene.length === 0) return
    if (active === 'idle') {
      for (const entry of scene) triggerState(entry.char, 'idle')
      return
    }
    scene.forEach((entry, i) => {
      window.setTimeout(() => triggerState(entry.char, active), i * 80)
    })
    const dur = active === 'attack' ? ATTACK_DURATION : HURT_DURATION
    const ms = dur * 16 + 400
    const reset = window.setTimeout(() => setActive('idle'), ms)
    return () => window.clearTimeout(reset)
  }, [active])

  useEffect(() => {
    const host = hostRef.current as
      | (HTMLDivElement & { __bones?: Graphics })
      | null
    if (!host?.__bones) return
    host.__bones.visible = showBones
  }, [showBones])

  return (
    <div className={styles.wrap}>
      <header className={styles.header}>
        <div className={styles.eyebrow}>Atelier · Rigging engine v1</div>
        <h1 className={styles.title}>Bestiaire Riggé</h1>
        <p className={styles.lede}>
          Quatre âmes, six bones chacune. Chaque créature est une pure data —
          le moteur de rigging fait le reste.
        </p>
        <div className={styles.controls}>
          <button
            type="button"
            className={`${styles.btn} ${active === 'idle' ? styles.active : ''}`}
            onClick={() => setActive('idle')}
          >
            Repos
          </button>
          <button
            type="button"
            className={`${styles.btn} ${active === 'attack' ? styles.active : ''}`}
            onClick={() => setActive('attack')}
          >
            Frappe
          </button>
          <button
            type="button"
            className={`${styles.btn} ${active === 'hurt' ? styles.active : ''}`}
            onClick={() => setActive('hurt')}
          >
            Châtiment
          </button>
          <button
            type="button"
            className={`${styles.btn} ${styles.bones} ${showBones ? styles.active : ''}`}
            onClick={() => setShowBones((v) => !v)}
          >
            {showBones ? 'Cacher les os' : 'Voir les os'}
          </button>
        </div>
      </header>
      <div className={styles.stage}>
        <div ref={hostRef} className={styles.host} />
      </div>
    </div>
  )
}
