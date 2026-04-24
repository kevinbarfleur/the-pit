/**
 * Deterministic Pit map generator. Pure functions only — no state, no I/O.
 *
 * The generator is split in two halves so chunks are independently derivable:
 *
 *   1. `generateChunkNodes(runSeed, chunkIndex)` produces every node in a
 *      chunk with empty `linksDown`. Depends only on the seed pair.
 *   2. `linkRows(runSeed, depthA, rowA, rowB)` fills the `linksDown` of rowA
 *      so that every rowB node receives ≥1 incoming link and every rowA
 *      node emits ≥1 outgoing link. Also deterministic from the seed pair.
 *
 * `materializeWindow(runSeed, fromDepth, toDepth)` orchestrates both for a
 * visible depth window, including the cross-chunk boundary.
 *
 * Rationale: generation must survive scrolling back and forth over the same
 * depths without drift, and must be cheap enough to call every render cycle
 * in the map view. Keeping the two halves separate also makes each trivially
 * property-testable.
 */

import { xoroshiro128plus } from 'pure-rand/generator/xoroshiro128plus'
import type { RandomGenerator } from 'pure-rand/types/RandomGenerator'
import {
  BOSS_EVERY,
  CHUNK_HEIGHT,
  MAX_COLUMNS,
  type PitChunk,
  type PitNode,
  type PitNodeType,
} from './types'

// --------------------- seeding ---------------------

/**
 * 32-bit FNV-1a hash over a string, xor-folded with a 32-bit int. Gives us
 * a deterministic numeric seed for `xoroshiro128plus` from an arbitrary
 * `runSeed` string + chunk/depth salt.
 */
function hashSeed(runSeed: string, salt: number): number {
  let h = 0x811c9dc5
  for (let i = 0; i < runSeed.length; i++) {
    h ^= runSeed.charCodeAt(i)
    h = Math.imul(h, 0x01000193)
  }
  h ^= salt | 0
  h = Math.imul(h, 0x01000193)
  return h | 0
}

/**
 * Thin convenience wrapper over the pure-rand xoroshiro128plus generator.
 * pure-rand v8 mutates the generator in place on each `.next()`, returning
 * a signed 32-bit integer. We fold to [0, 1) using the top 24 bits so the
 * result is stable across hosts and cheap to derive ints from.
 */
function cursor(runSeed: string, salt: number) {
  const rng: RandomGenerator = xoroshiro128plus(hashSeed(runSeed, salt))
  return {
    unit(): number {
      const n = rng.next()
      return ((n >>> 8) & 0xffffff) / 0x1000000
    },
    int(max: number): number {
      return Math.floor(this.unit() * max)
    },
  }
}

// --------------------- type + threat mixes ---------------------

/**
 * Weighted pick of node type for a non-boss row. Weights are depth-aware:
 * elites become more common as you descend; rest/shop stay roughly steady.
 */
function pickType(depth: number, roll: number): PitNodeType {
  // Depth-biased elite chance: 4% → 14% across depth [0, 200].
  const eliteChance = Math.min(0.14, 0.04 + depth * 0.0005)
  const weights: Array<[PitNodeType, number]> = [
    ['combat', 0.45],
    ['elite', eliteChance],
    ['event', 0.1],
    ['shop', 0.07],
    ['rest', 0.08],
    ['cache', 0.1],
    ['treasure', 0.05],
  ]
  const total = weights.reduce((s, [, w]) => s + w, 0)
  let r = roll * total
  for (const [type, w] of weights) {
    r -= w
    if (r <= 0) return type
  }
  return 'combat'
}

const TYPE_THREAT_MULT: Record<PitNodeType, number> = {
  combat: 1.0,
  elite: 1.55,
  boss: 2.4,
  event: 0.6, // event threat doesn't scale to combat — signals reward roll
  shop: 0,
  rest: 0,
  cache: 0.4,
  treasure: 0.3,
}

/** Basis points. Linear in depth, scaled by type multiplier. */
function threatAtDepth(depth: number, type: PitNodeType): number {
  const base = depth * 100 // 100 bp per depth level
  return Math.floor(base * TYPE_THREAT_MULT[type])
}

// --------------------- row width + columns ---------------------

/** Depth of the next boss at or after `depth`. */
function nextBossDepth(depth: number): number {
  return Math.ceil(depth / BOSS_EVERY) * BOSS_EVERY
}

/**
 * Width of a depth row. Boss depths are always 1. Rows in the 3 depths
 * immediately above a boss narrow 3→2→1 so branches converge. All other
 * rows are 1–3 with bias to 2.
 */
function pickWidth(depth: number, rng: ReturnType<typeof cursor>): number {
  if (depth > 0 && depth % BOSS_EVERY === 0) return 1
  const dist = nextBossDepth(depth) - depth
  if (dist === 1) return 1
  if (dist === 2) return 2
  if (dist === 3) return Math.min(3, rng.int(2) + 2) // 2 or 3, bias low
  const roll = rng.unit()
  if (roll < 0.2) return 1
  if (roll < 0.7) return 2
  return 3
}

/**
 * Pick `width` distinct columns in [0, MAX_COLUMNS), spread symmetrically.
 * Centers single nodes; uses 0/2 for width 2 (outer edges); uses 0/1/2 for
 * width 3 (full row).
 */
function pickColumns(width: number): number[] {
  if (width === 1) return [Math.floor(MAX_COLUMNS / 2)]
  if (width === 2) return [0, MAX_COLUMNS - 1]
  return Array.from({ length: MAX_COLUMNS }, (_, i) => i)
}

// --------------------- public generator ---------------------

/**
 * Generate every node of a chunk, with `linksDown: []`. Linking is handled
 * separately so the caller can honour cross-chunk boundaries.
 */
export function generateChunkNodes(runSeed: string, chunkIndex: number): PitNode[] {
  const rng = cursor(runSeed, chunkIndex)
  const nodes: PitNode[] = []

  for (let rel = 0; rel < CHUNK_HEIGHT; rel++) {
    const depth = chunkIndex * CHUNK_HEIGHT + rel
    const width = pickWidth(depth, rng)
    const columns = pickColumns(width)
    for (const col of columns) {
      const isBoss = depth > 0 && depth % BOSS_EVERY === 0
      const type: PitNodeType = isBoss ? 'boss' : pickType(depth, rng.unit())
      nodes.push({
        id: `${depth}:${col}`,
        depth,
        column: col,
        type,
        threat: threatAtDepth(depth, type),
        linksDown: [],
      })
    }
  }

  return nodes
}

/**
 * Compute deterministic downlinks from `rowA` to `rowB`. Mutates each rowA
 * node's `linksDown`. Guarantees:
 *   - every rowB node receives ≥ 1 incoming link;
 *   - every rowA node emits ≥ 1 outgoing link;
 *   - no duplicate links from a single node.
 *
 * The algorithm first assigns each rowB node to its closest-column rowA
 * neighbour (incoming guarantee), then patches any rowA node without an
 * outgoing link by pointing it at its closest-column rowB neighbour, and
 * finally adds at most one extra cross-link per rowA node at low
 * probability to create organic divergence.
 */
export function linkRows(
  runSeed: string,
  depthA: number,
  rowA: PitNode[],
  rowB: PitNode[],
): void {
  if (rowA.length === 0 || rowB.length === 0) return
  const rng = cursor(runSeed, (depthA << 8) ^ 0x9e3779b1)

  // Step 1 — every rowB node receives one incoming link.
  for (const b of rowB) {
    const a = closestByColumn(rowA, b.column)
    if (!a.linksDown.includes(b.id)) a.linksDown.push(b.id)
  }

  // Step 2 — every rowA node emits at least one link.
  for (const a of rowA) {
    if (a.linksDown.length === 0) {
      const b = closestByColumn(rowB, a.column)
      a.linksDown.push(b.id)
    }
  }

  // Step 3 — up to one bonus cross-link per rowA node at 25% probability,
  // only when the bonus target isn't already linked (no duplicates).
  for (const a of rowA) {
    if (rowB.length < 2) break
    if (rng.unit() > 0.25) continue
    // Pick a rowB node at a column offset by ±1 from a's column.
    const offset = rng.unit() < 0.5 ? -1 : 1
    const targetCol = a.column + offset
    const b = rowB.find((n) => n.column === targetCol)
    if (!b) continue
    if (a.linksDown.includes(b.id)) continue
    a.linksDown.push(b.id)
  }
}

function closestByColumn(row: PitNode[], col: number): PitNode {
  let best = row[0]
  let bestDist = Math.abs(best.column - col)
  for (let i = 1; i < row.length; i++) {
    const d = Math.abs(row[i].column - col)
    if (d < bestDist) {
      best = row[i]
      bestDist = d
    }
  }
  return best
}

// --------------------- window materialization ---------------------

export interface MaterializedWindow {
  /** Flat list of every node covered by [fromDepth, toDepth], linksDown set. */
  nodes: PitNode[]
  /** O(1) lookup by id. */
  byId: Map<string, PitNode>
  /** Nodes grouped by depth for row-wise rendering / linking. */
  byDepth: Map<number, PitNode[]>
  /** Which chunks were generated to cover the window. */
  chunks: Map<number, PitChunk>
}

/**
 * Materialize a continuous depth window [fromDepth, toDepth] inclusive.
 * Generates the covering chunks, fills cross-chunk links, and returns all
 * lookups the UI needs. Idempotent in `(runSeed, fromDepth, toDepth)`.
 */
export function materializeWindow(
  runSeed: string,
  fromDepth: number,
  toDepth: number,
): MaterializedWindow {
  if (toDepth < fromDepth) throw new Error('materializeWindow: toDepth < fromDepth')
  const firstChunk = Math.floor(fromDepth / CHUNK_HEIGHT)
  // We need one extra chunk past the last row so linksDown on the window's
  // last row point at real nodes.
  const lastChunk = Math.floor(toDepth / CHUNK_HEIGHT) + 1

  const chunks = new Map<number, PitChunk>()
  for (let ci = firstChunk; ci <= lastChunk; ci++) {
    const nodes = generateChunkNodes(runSeed, ci)
    chunks.set(ci, { index: ci, seed: `${runSeed}:${ci}`, nodes })
  }

  // Group every node produced so far by depth.
  const byDepth = new Map<number, PitNode[]>()
  for (const c of chunks.values()) {
    for (const n of c.nodes) {
      const row = byDepth.get(n.depth) ?? []
      row.push(n)
      byDepth.set(n.depth, row)
    }
  }
  // Sort rows by column so pickColumns output order is preserved for
  // deterministic linking.
  for (const row of byDepth.values()) row.sort((a, b) => a.column - b.column)

  // Link every pair of adjacent rows we have.
  const depths = Array.from(byDepth.keys()).sort((a, b) => a - b)
  for (let i = 0; i < depths.length - 1; i++) {
    const d = depths[i]
    if (depths[i + 1] !== d + 1) continue
    linkRows(runSeed, d, byDepth.get(d)!, byDepth.get(d + 1)!)
  }

  // Build the returned flat list, clipping to the requested window.
  const nodes: PitNode[] = []
  const byId = new Map<string, PitNode>()
  for (let d = fromDepth; d <= toDepth; d++) {
    const row = byDepth.get(d)
    if (!row) continue
    for (const n of row) {
      nodes.push(n)
      byId.set(n.id, n)
    }
  }

  return { nodes, byId, byDepth, chunks }
}
