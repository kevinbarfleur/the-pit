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

/**
 * Number of depth rows per generated chunk. A chunk is a self-contained
 * Slay-the-Spire-style mini-act:
 *   - depth 0 of the chunk = single entry node (col 1).
 *   - depths 1..CHUNK_HEIGHT-2 = exploration rows. Multiple paths walk
 *     from the entry's fan-out toward the boss with strict no-crossing
 *     and 1±1 column movement.
 *   - depth CHUNK_HEIGHT-1 of the chunk = single boss node (col 1).
 * Aligned with BOSS_EVERY so every chunk ends in a boss.
 */
export const CHUNK_HEIGHT = 20

/** Hard cap on nodes per depth row. */
export const MAX_COLUMNS = 3

/**
 * Depth at which a fresh run begins. Player never sees the "surface" of
 * the Pit — we spawn them already mid-descent.
 */
export const STARTING_DEPTH = 50

/**
 * Every N depths a mandatory boss appears as a single convergence node.
 * Equal to CHUNK_HEIGHT so every chunk's last row is a boss.
 */
export const BOSS_EVERY = 20
