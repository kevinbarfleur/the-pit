import { Container, Graphics } from 'pixi.js'
import type {
  AnimationFn,
  AnimationResult,
  CharacterDef,
  CharacterInstance,
  CharacterState,
  Palette,
  PartSpec,
} from '../game/characters/types'

/**
 * Rigging engine. Three public functions:
 *
 *   - `createCharacter(def, palette)` instantiates parts, mounts the
 *     rig hierarchy, and returns a live `CharacterInstance`.
 *   - `updateCharacter(char, t, dt)` advances one frame: ticks the
 *     state timer, picks the right animation (custom > default), runs
 *     it, then applies root-level transforms (translation/tint/alpha).
 *   - `triggerState(char, state)` flips the state machine.
 *
 * The engine is unaware of which character is which — it just resolves
 * parts by canonical name (`head`, `torso`, `armFront`, `armBack`,
 * `weapon`, `legs`, `tail`). Missing parts are silently ignored so
 * legless or tail-having creatures work as data, no engine fork.
 *
 * `defaultIdle` / `defaultAttack` / `defaultHurt` cover 80 % of cases.
 * A `def.animations.<state>` overrides them per-character — used when
 * a creature needs a special motion (witch's robe sway, spectre's
 * alpha pulse, etc.).
 */

export const ATTACK_DURATION = 35
export const HURT_DURATION = 30

// ---------- build ----------

function buildGfx(grid: readonly string[], palette: Palette): Graphics {
  const g = new Graphics()
  for (let y = 0; y < grid.length; y++) {
    const row = grid[y]!
    for (let x = 0; x < row.length; x++) {
      const ch = row[x]!
      const color = palette[ch]
      if (color === undefined) continue
      g.rect(x, y, 1, 1).fill(color)
    }
  }
  return g
}

function buildPart(spec: PartSpec, palette: Palette): Container {
  const c = new Container()
  c.addChild(buildGfx(spec.grid, palette))
  c.pivot.set(spec.pivot.x, spec.pivot.y)
  return c
}

export function createCharacter(
  def: CharacterDef,
  palette: Palette,
): CharacterInstance {
  const root = new Container()
  const parts: Record<string, Container> = {}

  for (const [name, spec] of Object.entries(def.parts)) {
    parts[name] = buildPart(spec, palette)
  }

  for (const node of def.rig) {
    const part = parts[node.part]
    if (!part) continue
    part.position.set(node.at[0], node.at[1])
    const parent = node.parent ? parts[node.parent] : root
    if (parent) parent.addChild(part)
  }

  return {
    root,
    parts,
    def,
    state: 'idle',
    stateAge: 0,
    idlePhase: Math.random() * Math.PI * 2,
    baseX: 0,
    baseY: 0,
    flipped: def.flipped ?? false,
  }
}

// ---------- runtime helpers ----------

function partsOf(char: CharacterInstance): Record<string, Container> {
  return char.parts as Record<string, Container>
}

function resetParts(char: CharacterInstance): void {
  for (const part of Object.values(partsOf(char))) {
    part.rotation = 0
    part.scale.set(1, 1)
  }
}

function tintCharacter(char: CharacterInstance, tint: number): void {
  for (const part of Object.values(partsOf(char))) {
    const gfx = part.children[0] as Graphics | undefined
    if (gfx) gfx.tint = tint
  }
}

export function triggerState(
  char: CharacterInstance,
  state: CharacterState,
): void {
  char.state = state
  char.stateAge = 0
}

export function disposeCharacter(char: CharacterInstance): void {
  ;(char.root as Container).destroy({ children: true })
}

// ---------- default animations ----------

export const defaultIdle: AnimationFn = (char, t) => {
  const parts = partsOf(char)
  const idlePose = char.def.idlePose ?? {}
  const phase = char.idlePhase
  const breathe = Math.sin(t * 0.04 + phase) * 0.025

  if (parts.torso) parts.torso.scale.set(1, 1 + breathe)
  if (parts.head) parts.head.rotation = Math.sin(t * 0.04 + phase + 0.7) * 0.025

  if (parts.armFront) {
    const base = idlePose.armFront ?? 0
    parts.armFront.rotation = base + Math.sin(t * 0.04 + phase + 0.5) * 0.03
  }
  if (parts.armBack) {
    const base = idlePose.armBack ?? 0
    parts.armBack.rotation = base + Math.sin(t * 0.04 + phase + 1.5) * 0.03
  }
  if (parts.weapon) {
    parts.weapon.rotation = idlePose.weapon ?? 0
  }
  if (parts.tail) parts.tail.rotation = Math.sin(t * 0.05 + phase) * 0.15

  return {
    rootDx: 0,
    rootDy: Math.round(Math.sin(t * 0.04 + phase) * 1.5),
    tint: 0xffffff,
  }
}

export const defaultAttack: AnimationFn = (char, t, p) => {
  const parts = partsOf(char)
  const f = char.flipped ? -1 : 1
  const idlePose = char.def.idlePose ?? {}
  const armBase = idlePose.armFront ?? 0
  const weaponBase = idlePose.weapon ?? 0

  let armRot = 0
  let weaponRot = 0
  let torsoRot = 0
  let headRot = 0
  let rootDx = 0

  if (p < 0.35) {
    // Windup: arm rises, wrist tightens to align weapon with arm.
    const q = p / 0.35
    const eased = q * q
    armRot = armBase + eased * (-3.0 - armBase)
    weaponRot = weaponBase + eased * (0 - weaponBase)
    torsoRot = -eased * 0.1
    headRot = -eased * 0.05
  } else if (p < 0.55) {
    // Strike: arm + weapon aligned, brutal swing down.
    const q = (p - 0.35) / 0.2
    const eased = q * (2 - q)
    armRot = -3.0 + eased * 2.6
    weaponRot = 0
    torsoRot = -0.1 + eased * 0.3
    headRot = -0.05 + eased * 0.2
    rootDx = eased * 6
  } else {
    // Recovery: arm returns to guard, wrist relaxes back to perpendicular.
    const q = (p - 0.55) / 0.45
    armRot = -0.4 + q * (armBase - -0.4)
    weaponRot = q * weaponBase
    torsoRot = 0.2 - q * 0.2
    headRot = 0.15 - q * 0.15
    rootDx = 6 - q * 6
  }

  if (parts.armFront) parts.armFront.rotation = armRot * f
  if (parts.weapon) parts.weapon.rotation = weaponRot * f
  if (parts.torso) parts.torso.rotation = torsoRot * f
  if (parts.head) parts.head.rotation = headRot * f
  if (parts.torso) parts.torso.scale.set(1, 1 + Math.sin(t * 0.08) * 0.01)

  return { rootDx: rootDx * f, rootDy: 0, tint: 0xffffff }
}

export const defaultHurt: AnimationFn = (char, _t, p) => {
  const parts = partsOf(char)
  const f = char.flipped ? -1 : 1
  const k = 1 - p

  if (parts.head) parts.head.rotation = 0.5 * k * Math.cos(p * Math.PI * 2)
  if (parts.torso) parts.torso.rotation = -0.25 * k * Math.cos(p * Math.PI)
  if (parts.armFront)
    parts.armFront.rotation = 0.4 * k * Math.sin(p * Math.PI * 4)
  if (parts.armBack)
    parts.armBack.rotation = 0.3 * k * Math.sin(p * Math.PI * 4 + 1)

  const rootDx = -8 * Math.pow(k, 2) + Math.sin(p * Math.PI * 9) * 1.5 * k
  const rootDy = -3 * k * Math.sin(p * Math.PI)

  const r = 0xff
  const g = Math.floor(0xff - k * 0xaa)
  const b = Math.floor(0xff - k * 0xaa)
  const tint = (r << 16) | (g << 8) | b

  return { rootDx: rootDx * f, rootDy, tint }
}

const DEFAULT_ANIMATIONS: Record<CharacterState, AnimationFn> = {
  idle: defaultIdle,
  attack: defaultAttack,
  hurt: defaultHurt,
}

// ---------- update ----------

export function updateCharacter(
  char: CharacterInstance,
  t: number,
  dt: number,
): void {
  // Tick the state timer first; non-idle states auto-return to idle.
  if (char.state !== 'idle') {
    char.stateAge += dt
    const dur = char.state === 'attack' ? ATTACK_DURATION : HURT_DURATION
    if (char.stateAge >= dur) {
      char.state = 'idle'
      char.stateAge = 0
    }
  }

  // Wipe per-part transforms before each frame so animations don't
  // accumulate (positions stay put — they're set once at build time).
  resetParts(char)

  const customAnim = char.def.animations?.[char.state]
  const animFn: AnimationFn = customAnim ?? DEFAULT_ANIMATIONS[char.state]

  let progress = 0
  if (char.state !== 'idle') {
    const dur = char.state === 'attack' ? ATTACK_DURATION : HURT_DURATION
    progress = Math.min(1, char.stateAge / dur)
  }

  const result: AnimationResult = animFn(char, t, progress)

  const root = char.root as Container
  root.x = char.baseX + (result.rootDx ?? 0)
  root.y = char.baseY + (result.rootDy ?? 0)
  tintCharacter(char, result.tint ?? 0xffffff)
  root.alpha = result.alpha ?? 1
}
