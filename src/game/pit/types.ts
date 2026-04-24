/**
 * Domain types for the Pit map. Pure data — no React, no Pixi, no storage.
 *
 * A Pit run is an infinite vertical descent through branching nodes. Depth
 * increases downward; players may backtrack to re-clear shallower nodes to
 * farm when the scaling pushes them too hard.
 *
 * The graph is materialized lazily by chunks of CHUNK_HEIGHT rows, seeded
 * by `(runSeed, chunkIndex)`. This keeps generation deterministic and lets
 * the UI only pay for the window it currently renders.
 */

export type PitNodeType =
  | 'combat'
  | 'elite'
  | 'boss'
  | 'event'
  | 'shop'
  | 'rest'
  | 'cache'
  | 'treasure'

export type PitNodeState =
  | 'fresh'
  | 'current'
  | 'cleared'
  | 'cleared-exhausted'
  | 'locked'
  | 'bypassed'

export interface PitNode {
  /** `${depth}:${column}` — stable across regeneration for the same runSeed. */
  id: string
  /** Absolute depth from the surface of the Pit. Runs start mid-Pit. */
  depth: number
  /** Column index within a depth row, in [0, MAX_COLUMNS). */
  column: number
  type: PitNodeType
  /** Basis points (10000 = parity with player power). Larger = harder. */
  threat: number
  /** Node ids at depth+1 reachable via chain from this node. */
  linksDown: string[]
}

export interface PitChunk {
  /** `floor(depth / CHUNK_HEIGHT)` */
  index: number
  seed: string
  /** Always exactly CHUNK_HEIGHT rows, one or more nodes per row. */
  nodes: PitNode[]
}

/**
 * Tracks player-side mutations over the deterministic topology. The pure
 * generator never produces this — only the run state hook does.
 */
export interface PitRunState {
  runSeed: string
  currentId: string
  /**
   * For each node the player has committed to and returned from:
   * how many times they've cleared it and at what depth their position was
   * on the last clear (drives the reward-scale curve).
   */
  clearedAt: Map<string, { timesCleared: number; lastClearedAtDepth: number }>
  /**
   * Stable, ordered history of committed node ids. Used to compute
   * `bypassed` siblings and to drive the chain "traversed" visual state.
   */
  path: string[]
}

export interface PitGraph {
  chunks: Map<number, PitChunk>
}

/** Number of depth rows per generated chunk. */
export const CHUNK_HEIGHT = 10

/** Hard cap on nodes per depth row. Typical rows carry 1–3 nodes. */
export const MAX_COLUMNS = 3

/**
 * Depth at which a fresh run begins. Player never sees the "surface" of
 * the Pit — we spawn them already mid-descent. Simplifies the visual
 * because there's no top edge of the shaft to render.
 */
export const STARTING_DEPTH = 50

/**
 * Every N depths a mandatory boss row appears. The row collapses to a
 * single centered node; the rows just above it narrow from width 3→2→1 so
 * branches converge cleanly into it.
 */
export const BOSS_EVERY = 20
