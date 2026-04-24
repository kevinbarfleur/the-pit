/**
 * Deterministic pixel-art shapes for floating islands.
 *
 * Every island renders two things:
 *   1. A top cap — an irregular "circle" with a 12-vertex polygon clip so
 *      no two islands are identical but all remain stable across renders
 *      (the same node id always draws the same shape).
 *   2. A swarm of stalactites underneath — small pointed pieces of
 *      broken earth dangling from the cap. Number, offset, width and
 *      height are all seeded off the id.
 *
 * The math lives here (not the component) so the ChainsEngine can read
 * the exact anchor points (centre-top for incoming chains, centre of the
 * longest stalactite for outgoing chains) without duplicating layout.
 */

export interface IslandShape {
  /** CSS `clip-path: polygon(...)` for the top cap. Unit: percentage. */
  clipPath: string
  stalactites: Stalactite[]
  /** Horizontal offset in % (0..100) of the point where outgoing chains
   *  should anchor — always roughly centred but nudged by the seed so it
   *  doesn't feel machined. */
  bottomAnchorPercent: number
  /** Same for incoming chains at the top edge. */
  topAnchorPercent: number
  /** Period (seconds) of the island's float bob. Staggered per id so a
   *  cluster of islands isn't breathing in unison. */
  floatPeriod: number
  floatDelay: number
}

export interface Stalactite {
  /** Horizontal centre in % of the island's width. 0 = left edge, 100 = right. */
  xPercent: number
  /** Width in px. */
  width: number
  /** Height in px — how far the stalactite descends. */
  height: number
  /** Top-edge offset in px below the top cap — some stalactites start
   *  slightly below the cap edge for a ragged, broken look. */
  topOffset: number
}

/**
 * 32-bit FNV-1a hash of a string. Identical to the one in generate.ts —
 * duplicated here to avoid pulling the generate module into components.
 */
function hashId(id: string): number {
  let h = 0x811c9dc5
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i)
    h = Math.imul(h, 0x01000193)
  }
  return h >>> 0
}

/** A small mulberry32-style PRNG seeded by a 32-bit int. Deterministic,
 *  cheap, no external deps on the hot path. */
function makeRng(seed: number) {
  let s = seed >>> 0
  return () => {
    s = (s + 0x6d2b79f5) >>> 0
    let t = s
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 0x100000000
  }
}

const VERTEX_COUNT = 14
const BASE_RADIUS = 46 // percentage of the island's width/2 used as r0

/**
 * Build the deformed-circle clip-path for the top cap. The cap is drawn
 * within a square CSS box, so all coordinates are in [0, 100] percent.
 * Vertices sit on a circle of radius `BASE_RADIUS` (%) with per-vertex
 * noise of ±8% applied by the seeded rng.
 */
function buildClipPath(rng: () => number): string {
  const cx = 50
  const cy = 50
  const verts: string[] = []
  for (let i = 0; i < VERTEX_COUNT; i++) {
    const t = (i / VERTEX_COUNT) * Math.PI * 2
    const r = BASE_RADIUS + (rng() * 2 - 1) * 8
    const x = cx + Math.cos(t) * r
    const y = cy + Math.sin(t) * r
    verts.push(`${x.toFixed(1)}% ${y.toFixed(1)}%`)
  }
  return `polygon(${verts.join(', ')})`
}

/**
 * Generate 3–5 stalactites spread across the underside. They cluster
 * slightly under the cap's centre but wander toward the edges — giving
 * the island a ragged, broken feel rather than a neat fringe.
 */
function buildStalactites(rng: () => number, islandSizePx: number): Stalactite[] {
  const count = 3 + Math.floor(rng() * 3) // 3..5
  const out: Stalactite[] = []
  // Reserve lanes so stalactites don't overlap horizontally.
  for (let i = 0; i < count; i++) {
    const laneStart = 15 + (i * 70) / count // spread across 15..85%
    const laneSpan = 70 / count
    const xPercent = laneStart + rng() * laneSpan
    // Width biased small so stalactites read as individual shards.
    const width = 4 + Math.floor(rng() * 5) // 4..8 px
    // Height biased to vary — the longest one usually sits near the centre.
    const centerBias = 1 - Math.abs(xPercent - 50) / 50 // 1 at centre, 0 at edges
    const baseHeight = islandSizePx * 0.18 + rng() * 10 + centerBias * 10
    const height = Math.round(baseHeight)
    const topOffset = Math.floor(rng() * 3) // 0..2 px below cap
    out.push({ xPercent, width, height, topOffset })
  }
  return out.sort((a, b) => a.xPercent - b.xPercent)
}

export function computeIslandShape(id: string, sizePx: number): IslandShape {
  const rng = makeRng(hashId(id))
  const clipPath = buildClipPath(rng)
  const stalactites = buildStalactites(rng, sizePx)
  const bottomAnchorPercent = 48 + rng() * 4 // 48..52%
  const topAnchorPercent = 48 + rng() * 4
  const floatPeriod = 1.8 + rng() * 1.2 // 1.8..3.0s
  const floatDelay = rng() * 2.5 // 0..2.5s
  return {
    clipPath,
    stalactites,
    bottomAnchorPercent,
    topAnchorPercent,
    floatPeriod,
    floatDelay,
  }
}
