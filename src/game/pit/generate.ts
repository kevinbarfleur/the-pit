/**
 * Deterministic Pit map generator. Pure functions only — no state, no I/O.
 *
 * **Architecture (Slay-the-Spire-inspired):**
 *
 *   - The map is generated **chunk by chunk**. A chunk spans exactly
 *     CHUNK_HEIGHT depths and is a self-contained mini-act.
 *   - Inside a chunk: a single entry node at the top (col = bossCol),
 *     fan-out at depth+1 across distinct columns, walking paths that
 *     converge to a single boss node at the chunk's last depth.
 *   - Path walks use the canonical Slay rules: at each step, choose
 *     among `[col-1, col, col+1]` candidates filtered by no-cross and
 *     no-duplicate-edge constraints. Approach to the boss biases the
 *     candidates toward the boss column.
 *   - Every chunk's boss → next chunk's entry is a 1-edge link added
 *     by `materializeWindow`.
 *
 * **Why chunks**: keeps generation lazy + deterministic. Boss-to-boss
 * is one chunk. Players move forward by one boss every CHUNK_HEIGHT.
 *
 * **Cross-prevention**: the no-cross filter is the single most
 * important rule. Without it, the map degenerates to spaghetti. Every
 * candidate edge `(p_col → c_col)` between depths `d` and `d+1` is
 * rejected if there exists any other edge `(p2_col → c2_col)` between
 * the same depths such that `(p_col − p2_col) × (c_col − c2_col) < 0`
 * (strict opposite-sign of column delta = crossed).
 */

import { xoroshiro128plus } from 'pure-rand/generator/xoroshiro128plus'
import type { RandomGenerator } from 'pure-rand/types/RandomGenerator'
import {
  BOSS_EVERY,
  CHUNK_HEIGHT,
  MAX_COLUMNS,
  STARTING_DEPTH,
  type PitChunk,
  type PitNode,
  type PitNodeType,
} from './types'

/**
 * DEBUG scaffolding. For the first few depths of a fresh run we force
 * a rotation of node types so the player lands on a window that
 * exposes every unique hover effect. Keys are absolute depths.
 */
const FORCED_HOVER_TYPES: Record<number, PitNodeType[]> = {
  [STARTING_DEPTH]: ['combat'],
  [STARTING_DEPTH + 1]: ['rest', 'combat', 'shop'],
  [STARTING_DEPTH + 2]: ['event', 'elite', 'treasure'],
  [STARTING_DEPTH + 3]: ['cache', 'combat', 'rest'],
}

// =====================================================================
// Seeding helpers
// =====================================================================

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

interface Cursor {
  unit(): number
  int(max: number): number
  pick<T>(arr: T[]): T
}

function cursor(runSeed: string, salt: number): Cursor {
  const rng: RandomGenerator = xoroshiro128plus(hashSeed(runSeed, salt))
  return {
    unit(): number {
      const n = rng.next()
      return ((n >>> 8) & 0xffffff) / 0x1000000
    },
    int(max: number): number {
      return Math.floor(this.unit() * max)
    },
    pick<T>(arr: T[]): T {
      return arr[Math.floor(this.unit() * arr.length)]
    },
  }
}

// =====================================================================
// Type weights + threat
// =====================================================================

/**
 * Weighted pick of node type for a non-special depth. Probabilities
 * are tuned to match the Slay-the-Spire baseline distribution adapted
 * to our 8 node types:
 *   combat 50 % · event 20 % · shop 8 % · rest 12 % · elite 7 % ·
 *   cache 3 % (treasure handled by mid-chunk override).
 *
 * Elite chance is gated below depth 6 within a chunk (early floors get
 * no elites — players need a few combats to ramp).
 */
function pickType(depth: number, depthInChunk: number, roll: number): PitNodeType {
  const allowElite = depthInChunk >= 6
  const weights: Array<[PitNodeType, number]> = [
    ['combat', 0.5],
    ['elite', allowElite ? 0.07 + Math.min(0.07, depth * 0.0003) : 0],
    ['event', 0.2],
    ['shop', 0.08],
    ['rest', 0.12],
    ['cache', 0.03],
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
  event: 0.6,
  shop: 0,
  rest: 0,
  cache: 0.4,
  treasure: 0.3,
}

function threatAtDepth(depth: number, type: PitNodeType): number {
  return Math.floor(depth * 100 * TYPE_THREAT_MULT[type])
}

// =====================================================================
// Path walker
// =====================================================================

interface Edge {
  fromCol: number
  toCol: number
  /** Depth of the parent node (the child is at depth + 1). */
  depth: number
}

/**
 * Anti-crossing predicate. Returns true iff a hypothetical edge
 * `(parentCol → childCol)` between depths `d` and `d+1` would cross
 * any existing edge in `edges` at the same depth pair.
 *
 * Two edges (p1, c1) and (p2, c2) cross iff their column deltas have
 * opposite signs once you align their parents — i.e.
 *     (p1 - p2) × (c1 - c2) < 0
 * This is the canonical rule used by Slay the Spire's map generator.
 */
function crosses(
  edges: Edge[],
  parentCol: number,
  childCol: number,
  depth: number,
): boolean {
  for (const e of edges) {
    if (e.depth !== depth) continue
    if (e.fromCol === parentCol && e.toCol === childCol) continue
    const dp = parentCol - e.fromCol
    const dc = childCol - e.toCol
    if (dp * dc < 0) return true
  }
  return false
}

/**
 * Walk a single path from `(startCol, startDepth)` to `(endCol, endDepth)`
 * inclusive. At each step, picks a child column among `[col-1, col,
 * col+1]` filtered by:
 *   - within `[0, MAX_COLUMNS)`,
 *   - not duplicating an edge already in `edges`,
 *   - not crossing any edge in `edges`,
 *   - approaching the boss column when within `bossDepth - depth + 1`
 *     steps of the boss (forces convergence over the last 3 rows).
 *
 * Mutates `edges` in place by appending every new edge it walks.
 * Returns the visited (depth, col) cells in order.
 */
function walkPath(
  rng: Cursor,
  startCol: number,
  startDepth: number,
  endCol: number,
  endDepth: number,
  edges: Edge[],
): Array<{ depth: number; col: number }> {
  const visited: Array<{ depth: number; col: number }> = [
    { depth: startDepth, col: startCol },
  ]
  let curCol = startCol
  for (let d = startDepth; d < endDepth; d++) {
    const stepsLeft = endDepth - d
    let candidates = [-1, 0, 1]
      .map((dc) => curCol + dc)
      .filter((c) => c >= 0 && c < MAX_COLUMNS)

    // Boss-approach bias: each remaining step can move the column by
    // at most 1, so we must already be within `stepsLeft` columns of
    // the boss.
    const reachable = candidates.filter(
      (c) => Math.abs(c - endCol) <= stepsLeft - 1,
    )
    if (reachable.length > 0) candidates = reachable

    // Drop candidates that would create a duplicate edge from curCol.
    candidates = candidates.filter(
      (c) => !edges.some((e) => e.depth === d && e.fromCol === curCol && e.toCol === c),
    )

    // Drop candidates that would cross an existing edge.
    const safe = candidates.filter((c) => !crosses(edges, curCol, c, d))
    const pool = safe.length > 0 ? safe : candidates
    if (pool.length === 0) {
      // No legal move — force the closest column toward the boss.
      const fallback = curCol < endCol ? curCol + 1 : curCol > endCol ? curCol - 1 : curCol
      edges.push({ fromCol: curCol, toCol: fallback, depth: d })
      visited.push({ depth: d + 1, col: fallback })
      curCol = fallback
      continue
    }
    // Bias toward `endCol` when ties: prefer the column closest to it.
    pool.sort((a, b) => Math.abs(a - endCol) - Math.abs(b - endCol))
    const minDist = Math.abs(pool[0] - endCol)
    const tied = pool.filter((c) => Math.abs(c - endCol) === minDist)
    const next = rng.pick(tied)
    edges.push({ fromCol: curCol, toCol: next, depth: d })
    visited.push({ depth: d + 1, col: next })
    curCol = next
  }
  return visited
}

// =====================================================================
// Type assignment with Slay-style overrides
// =====================================================================

/**
 * Apply Slay-style placement constraints AFTER paths are built. The
 * key invariants:
 *   - boss row stays a single 'boss' node (already enforced by the
 *     walker).
 *   - depthInChunk = 0 (chunk entry) is always 'combat'.
 *   - depthInChunk = CHUNK_HEIGHT/2 favours 'treasure' (mid-chunk
 *     reward floor).
 *   - depthInChunk = CHUNK_HEIGHT-2 favours 'rest' (pre-boss heal).
 *   - elite / shop / rest cannot be consecutive on a path.
 *   - a parent with multiple children must offer different types.
 *   - FORCED_HOVER_TYPES still wins (debug scaffolding).
 */
function assignTypes(
  rng: Cursor,
  nodes: PitNode[],
  chunkIndex: number,
): void {
  const chunkStartDepth = chunkIndex * CHUNK_HEIGHT
  const bossDepth = chunkStartDepth + CHUNK_HEIGHT - 1
  const treasureDepth = chunkStartDepth + Math.floor(CHUNK_HEIGHT / 2)
  const restDepth = bossDepth - 1

  const byId = new Map<string, PitNode>()
  for (const n of nodes) byId.set(n.id, n)

  // Group nodes by depth for parent/child lookups.
  const byDepth = new Map<number, PitNode[]>()
  for (const n of nodes) {
    const row = byDepth.get(n.depth) ?? []
    row.push(n)
    byDepth.set(n.depth, row)
  }
  for (const row of byDepth.values()) row.sort((a, b) => a.column - b.column)

  for (const n of nodes) {
    const dInChunk = n.depth - chunkStartDepth
    if (n.depth === bossDepth) {
      n.type = 'boss'
      n.threat = threatAtDepth(n.depth, 'boss')
      continue
    }
    if (dInChunk === 0) {
      n.type = 'combat' // entry row always combat
    } else if (n.depth === treasureDepth) {
      n.type = 'treasure'
    } else if (n.depth === restDepth) {
      n.type = 'rest'
    } else {
      n.type = pickType(n.depth, dInChunk, rng.unit())
    }

    // Constraint: same-row siblings emerging from a shared parent
    // must be distinct types. We enforce by re-rolling until unique
    // among the parent's existing children.
    const parents = nodes.filter((p) => p.linksDown.includes(n.id))
    for (const p of parents) {
      const siblings = p.linksDown
        .map((id) => byId.get(id))
        .filter((s): s is PitNode => !!s && s.id !== n.id && s.type !== 'boss')
      let attempts = 0
      while (
        attempts < 6 &&
        siblings.some((s) => s.type === n.type) &&
        n.type !== 'combat' && // combat is allowed to repeat
        n.depth !== treasureDepth &&
        n.depth !== restDepth
      ) {
        n.type = pickType(n.depth, dInChunk, rng.unit())
        attempts++
      }
    }

    // Constraint: no elite / shop / rest immediately after the same
    // type along any incoming-link path.
    if (n.type === 'elite' || n.type === 'shop' || n.type === 'rest') {
      const consecutive = parents.some((p) => p.type === n.type)
      if (consecutive) n.type = 'combat'
    }

    n.threat = threatAtDepth(n.depth, n.type)
  }

  // FORCED_HOVER_TYPES override — applied last so debug scaffolding
  // wins regardless of the constraints above.
  for (const [depthStr, types] of Object.entries(FORCED_HOVER_TYPES)) {
    const d = Number(depthStr)
    const row = byDepth.get(d)
    if (!row) continue
    for (let i = 0; i < row.length && i < types.length; i++) {
      if (row[i].type === 'boss') continue
      row[i].type = types[i]
      row[i].threat = threatAtDepth(d, types[i])
    }
  }
}

// =====================================================================
// Public chunk generator
// =====================================================================

/**
 * Build all nodes of a single chunk: 1 entry → fan-out → walking
 * paths → single boss. Edges populated as `linksDown` on each node.
 *
 * Determinism: seeded by `(runSeed, chunkIndex)`. Same input always
 * produces the same chunk — cross-chunk navigation never re-rolls.
 */
export function generateChunkNodes(
  runSeed: string,
  chunkIndex: number,
): PitNode[] {
  const rng = cursor(runSeed, chunkIndex)
  const startDepth = chunkIndex * CHUNK_HEIGHT
  const bossDepth = startDepth + CHUNK_HEIGHT - 1
  const bossCol = Math.floor(MAX_COLUMNS / 2) // 1
  const entryCol = bossCol

  const edges: Edge[] = []
  const visitedSet = new Set<string>()
  const orderedCells: Array<{ depth: number; col: number }> = []
  const seeCell = (depth: number, col: number) => {
    const key = `${depth}:${col}`
    if (!visitedSet.has(key)) {
      visitedSet.add(key)
      orderedCells.push({ depth, col })
    }
  }

  // Entry node at depth = startDepth, col = entryCol.
  seeCell(startDepth, entryCol)
  // Boss node at depth = bossDepth, col = bossCol — we lock this in
  // even before paths are built so walks know to converge.
  seeCell(bossDepth, bossCol)

  // Fan-out: from the entry, drop edges to 3 distinct cols at depth+1.
  // Those three cells are the starting points of three independent
  // walks toward the boss. With MAX_COLUMNS = 3, every column is used.
  const fanOutDepth = startDepth + 1
  const fanOutCols = Array.from({ length: MAX_COLUMNS }, (_, i) => i)
  for (const c of fanOutCols) {
    edges.push({ fromCol: entryCol, toCol: c, depth: startDepth })
    seeCell(fanOutDepth, c)
  }

  // Walk each path from its fan-out cell to the boss.
  for (const startCol of fanOutCols) {
    const visits = walkPath(
      rng,
      startCol,
      fanOutDepth,
      bossCol,
      bossDepth,
      edges,
    )
    for (const v of visits) seeCell(v.depth, v.col)
  }

  // Materialise nodes (without types yet) + populate linksDown from
  // the edge list.
  const nodes: PitNode[] = orderedCells.map(({ depth, col }) => ({
    id: `${depth}:${col}`,
    depth,
    column: col,
    type: 'combat',
    threat: 0,
    linksDown: [],
  }))
  const byId = new Map(nodes.map((n) => [n.id, n]))
  for (const e of edges) {
    const parentId = `${e.depth}:${e.fromCol}`
    const childId = `${e.depth + 1}:${e.toCol}`
    const parent = byId.get(parentId)
    if (parent && !parent.linksDown.includes(childId)) {
      parent.linksDown.push(childId)
    }
  }

  // Assign types with Slay-style overrides.
  assignTypes(rng, nodes, chunkIndex)

  return nodes
}

/**
 * Backward-compat shim — paths already populate `linksDown` inside
 * `generateChunkNodes`. We only need `linkRows` to splice the boss of
 * one chunk to the entry of the next, so this is a no-op for normal
 * intra-chunk row pairs.
 */
export function linkRows(
  _runSeed: string,
  _depthA: number,
  _rowA: PitNode[],
  _rowB: PitNode[],
): void {
  // No-op. Cross-chunk linking handled in `materializeWindow`.
}

// =====================================================================
// Window materialisation
// =====================================================================

export interface MaterializedWindow {
  nodes: PitNode[]
  byId: Map<string, PitNode>
  byDepth: Map<number, PitNode[]>
  chunks: Map<number, PitChunk>
}

/**
 * Materialize a continuous depth window `[fromDepth, toDepth]` inclusive.
 * Generates the covering chunks, splices boss → next-entry links, and
 * returns the lookups the UI needs. Idempotent in the inputs.
 */
export function materializeWindow(
  runSeed: string,
  fromDepth: number,
  toDepth: number,
): MaterializedWindow {
  if (toDepth < fromDepth) {
    throw new Error('materializeWindow: toDepth < fromDepth')
  }
  const firstChunk = Math.floor(fromDepth / CHUNK_HEIGHT)
  // Need one chunk past the window so the last visible boss can link
  // forward to the next chunk's entry.
  const lastChunk = Math.floor(toDepth / CHUNK_HEIGHT) + 1

  const chunks = new Map<number, PitChunk>()
  for (let ci = firstChunk; ci <= lastChunk; ci++) {
    const nodes = generateChunkNodes(runSeed, ci)
    chunks.set(ci, { index: ci, seed: `${runSeed}:${ci}`, nodes })
  }

  // Cross-chunk linking: every boss → next chunk's entry node.
  for (let ci = firstChunk; ci < lastChunk; ci++) {
    const cur = chunks.get(ci)
    const nxt = chunks.get(ci + 1)
    if (!cur || !nxt) continue
    const bossDepth = (ci + 1) * CHUNK_HEIGHT - 1
    const entryDepth = bossDepth + 1
    const boss = cur.nodes.find((n) => n.depth === bossDepth)
    const entry = nxt.nodes.find(
      (n) => n.depth === entryDepth && n.column === Math.floor(MAX_COLUMNS / 2),
    )
    if (boss && entry && !boss.linksDown.includes(entry.id)) {
      boss.linksDown.push(entry.id)
    }
  }

  // Build flat lookups for the requested window.
  const byDepth = new Map<number, PitNode[]>()
  for (const c of chunks.values()) {
    for (const n of c.nodes) {
      const row = byDepth.get(n.depth) ?? []
      row.push(n)
      byDepth.set(n.depth, row)
    }
  }
  for (const row of byDepth.values()) row.sort((a, b) => a.column - b.column)

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

// =====================================================================
// Compatibility re-exports (kept so existing callers don't break)
// =====================================================================

export { BOSS_EVERY }
