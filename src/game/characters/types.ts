/**
 * Character rigging data types. A character is described as **pure
 * data** — a list of pixel-art parts (each a 2D char grid + pivot), a
 * rig hierarchy that wires parts to parents, and an optional bag of
 * custom animations that override the engine defaults.
 *
 * The engine (`src/pixi/CharacterEngine.ts`) is the only place that
 * knows how to *render* a definition. Adding a new character is a
 * matter of authoring data, not code.
 *
 * Naming conventions for `parts` keys are load-bearing — the default
 * animations look up parts by name. Canonical slots: `head`, `torso`,
 * `armBack`, `armFront`, `weapon`, `legs`, `tail`. Missing slots are
 * silently skipped, so a legless witch or a tail-having spectre work
 * without engine changes.
 */

export type CharacterState = 'idle' | 'attack' | 'hurt'

/** A 2D char-grid sprite with its pivot in grid coordinates. */
export interface PartSpec {
  /** Each row is a string; each char keys into the palette map. */
  grid: readonly string[]
  pivot: { x: number; y: number }
}

/** A node in the rig tree — links a part to its parent + offset. */
export interface RigNode {
  part: string
  /** `null` parents to the character root. */
  parent: string | null
  at: [number, number]
}

/**
 * Optional resting-pose rotations applied each idle frame as an
 * additive base before the breathing wiggle. Useful for things like
 * "weapon held perpendicular to the arm" without forcing the engine
 * to know about specific gear.
 */
export type IdlePose = Partial<Record<string, number>>

/**
 * A custom animation function. Runs each frame for the matching state.
 * `t` is a global tick counter (frames * deltaTime); `progress` is the
 * normalised position within the state for non-idle states (`0..1`),
 * and `0` for `idle`.
 *
 * Should mutate part rotations/scales directly. Returns root-level
 * transforms (translation, tint, alpha) the engine applies after.
 */
export interface AnimationResult {
  rootDx?: number
  rootDy?: number
  /** RGB int tint applied to every part's Graphics. */
  tint?: number
  alpha?: number
}

export type AnimationFn = (
  char: CharacterInstance,
  t: number,
  progress: number,
) => AnimationResult

/**
 * A character definition. `parts` and `rig` are mandatory; `idlePose`
 * and `animations` are optional sugar.
 */
export interface CharacterDef {
  name: string
  parts: Record<string, PartSpec>
  rig: readonly RigNode[]
  idlePose?: IdlePose
  animations?: Partial<Record<CharacterState, AnimationFn>>
  /** Mirror left-handed creatures by inverting horizontal motion. */
  flipped?: boolean
}

/** Palette: hex int per char key. Unknown chars are transparent. */
export type Palette = Record<string, number>

/**
 * A live instance of a character built by `createCharacter`. The Pixi
 * containers are exposed for direct stage attachment; the rest is
 * mutated by the engine each frame.
 *
 * The Pixi types are kept loose (`unknown`) here so that the pure data
 * layer doesn't drag a Pixi import — only the engine resolves the
 * concrete types.
 */
export interface CharacterInstance {
  root: unknown
  parts: Record<string, unknown>
  def: CharacterDef
  state: CharacterState
  stateAge: number
  idlePhase: number
  baseX: number
  baseY: number
  flipped: boolean
}
