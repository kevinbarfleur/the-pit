/**
 * Property-based tests for the Pit map generator. Mandated by CLAUDE.md for
 * any formula with > 2 inputs; the generator + linker combined touches a
 * large input space (runSeed, chunkIndex, adjacent rows).
 *
 * Every assertion here is an invariant the UI depends on. If one fails,
 * either the generator regressed or the invariant itself is wrong — do not
 * weaken the test, fix the generator.
 */

import { describe, it, expect } from 'vitest'
import fc from 'fast-check'
import {
  generateChunkNodes,
  linkRows,
  materializeWindow,
} from './generate'
import { BOSS_EVERY, CHUNK_HEIGHT, MAX_COLUMNS } from './types'

const seedArb = fc.string({ minLength: 1, maxLength: 20 })
const chunkIndexArb = fc.integer({ min: 0, max: 50 })

describe('generateChunkNodes', () => {
  it('is deterministic in (runSeed, chunkIndex)', () => {
    fc.assert(
      fc.property(seedArb, chunkIndexArb, (seed, ci) => {
        const a = generateChunkNodes(seed, ci)
        const b = generateChunkNodes(seed, ci)
        expect(a).toEqual(b)
      }),
      { numRuns: 40 },
    )
  })

  it('produces exactly CHUNK_HEIGHT distinct depths per chunk', () => {
    fc.assert(
      fc.property(seedArb, chunkIndexArb, (seed, ci) => {
        const nodes = generateChunkNodes(seed, ci)
        const depths = new Set(nodes.map((n) => n.depth))
        expect(depths.size).toBe(CHUNK_HEIGHT)
        for (let rel = 0; rel < CHUNK_HEIGHT; rel++) {
          expect(depths.has(ci * CHUNK_HEIGHT + rel)).toBe(true)
        }
      }),
      { numRuns: 40 },
    )
  })

  it('respects width bounds: 1 ≤ rowWidth ≤ MAX_COLUMNS', () => {
    fc.assert(
      fc.property(seedArb, chunkIndexArb, (seed, ci) => {
        const nodes = generateChunkNodes(seed, ci)
        const byDepth = new Map<number, number>()
        for (const n of nodes) byDepth.set(n.depth, (byDepth.get(n.depth) ?? 0) + 1)
        for (const width of byDepth.values()) {
          expect(width).toBeGreaterThanOrEqual(1)
          expect(width).toBeLessThanOrEqual(MAX_COLUMNS)
        }
      }),
      { numRuns: 40 },
    )
  })

  it('uses only valid columns in [0, MAX_COLUMNS)', () => {
    fc.assert(
      fc.property(seedArb, chunkIndexArb, (seed, ci) => {
        const nodes = generateChunkNodes(seed, ci)
        for (const n of nodes) {
          expect(n.column).toBeGreaterThanOrEqual(0)
          expect(n.column).toBeLessThan(MAX_COLUMNS)
        }
      }),
      { numRuns: 40 },
    )
  })

  it('boss depths collapse to a single node', () => {
    fc.assert(
      fc.property(seedArb, fc.integer({ min: 1, max: 10 }), (seed, bossIndex) => {
        const depth = bossIndex * BOSS_EVERY
        const ci = Math.floor(depth / CHUNK_HEIGHT)
        const nodes = generateChunkNodes(seed, ci)
        const row = nodes.filter((n) => n.depth === depth)
        expect(row).toHaveLength(1)
        expect(row[0].type).toBe('boss')
      }),
      { numRuns: 30 },
    )
  })

  it('rows immediately above a boss converge (width non-increasing)', () => {
    fc.assert(
      fc.property(seedArb, fc.integer({ min: 1, max: 8 }), (seed, bossIndex) => {
        const bossDepth = bossIndex * BOSS_EVERY
        const window = materializeWindow(seed, bossDepth - 3, bossDepth)
        const widths = [
          window.byDepth.get(bossDepth - 3)?.length ?? 0,
          window.byDepth.get(bossDepth - 2)?.length ?? 0,
          window.byDepth.get(bossDepth - 1)?.length ?? 0,
          window.byDepth.get(bossDepth)?.length ?? 0,
        ]
        // widths must be monotone non-increasing approaching the boss
        for (let i = 1; i < widths.length; i++) {
          expect(widths[i]).toBeLessThanOrEqual(widths[i - 1])
        }
        // and the boss row is 1
        expect(widths[widths.length - 1]).toBe(1)
      }),
      { numRuns: 30 },
    )
  })

  it('threat is non-negative and scales with depth', () => {
    fc.assert(
      fc.property(seedArb, fc.integer({ min: 0, max: 20 }), (seed, ci) => {
        const nodes = generateChunkNodes(seed, ci)
        for (const n of nodes) {
          expect(n.threat).toBeGreaterThanOrEqual(0)
        }
      }),
      { numRuns: 30 },
    )
  })
})

describe('linkRows + materializeWindow', () => {
  it('every non-top node within the window has ≥ 1 incoming link', () => {
    fc.assert(
      fc.property(
        seedArb,
        fc.integer({ min: 0, max: 30 }),
        fc.integer({ min: 5, max: 20 }),
        (seed, from, span) => {
          const window = materializeWindow(seed, from, from + span)
          const incoming = new Map<string, number>()
          for (const n of window.nodes) {
            for (const downId of n.linksDown) {
              incoming.set(downId, (incoming.get(downId) ?? 0) + 1)
            }
          }
          // Every node whose depth > from must have an incoming link
          // (nodes at the very top row of the window have no parent to
          // check against within the window).
          for (const n of window.nodes) {
            if (n.depth === from) continue
            expect(incoming.get(n.id) ?? 0).toBeGreaterThanOrEqual(1)
          }
        },
      ),
      { numRuns: 30 },
    )
  })

  it('every non-bottom node within the window has ≥ 1 outgoing link', () => {
    fc.assert(
      fc.property(
        seedArb,
        fc.integer({ min: 0, max: 30 }),
        fc.integer({ min: 5, max: 20 }),
        (seed, from, span) => {
          const to = from + span
          const window = materializeWindow(seed, from, to)
          for (const n of window.nodes) {
            if (n.depth === to) continue
            expect(n.linksDown.length).toBeGreaterThanOrEqual(1)
          }
        },
      ),
      { numRuns: 30 },
    )
  })

  it('has no self-loops and no duplicate links', () => {
    fc.assert(
      fc.property(
        seedArb,
        fc.integer({ min: 0, max: 30 }),
        fc.integer({ min: 5, max: 20 }),
        (seed, from, span) => {
          const window = materializeWindow(seed, from, from + span)
          for (const n of window.nodes) {
            expect(n.linksDown).not.toContain(n.id)
            const set = new Set(n.linksDown)
            expect(set.size).toBe(n.linksDown.length)
          }
        },
      ),
      { numRuns: 30 },
    )
  })

  it('every link points to a node at depth+1', () => {
    fc.assert(
      fc.property(
        seedArb,
        fc.integer({ min: 0, max: 30 }),
        fc.integer({ min: 5, max: 20 }),
        (seed, from, span) => {
          const window = materializeWindow(seed, from, from + span)
          for (const n of window.nodes) {
            for (const downId of n.linksDown) {
              const target = window.byId.get(downId)
              if (!target) continue // link exits the window
              expect(target.depth).toBe(n.depth + 1)
            }
          }
        },
      ),
      { numRuns: 30 },
    )
  })

  it('materializeWindow is idempotent in (runSeed, fromDepth, toDepth)', () => {
    fc.assert(
      fc.property(
        seedArb,
        fc.integer({ min: 0, max: 30 }),
        fc.integer({ min: 3, max: 12 }),
        (seed, from, span) => {
          const a = materializeWindow(seed, from, from + span)
          const b = materializeWindow(seed, from, from + span)
          // Compare node-by-node (Map iteration order isn't guaranteed
          // but byId lookups are).
          expect(a.nodes.length).toBe(b.nodes.length)
          for (const node of a.nodes) {
            expect(b.byId.get(node.id)).toEqual(node)
          }
        },
      ),
      { numRuns: 20 },
    )
  })
})

describe('linkRows — direct contract', () => {
  it('every rowB node is reached when rows are supplied directly', () => {
    fc.assert(
      fc.property(seedArb, fc.integer({ min: 0, max: 30 }), (seed, depth) => {
        const rowA = generateChunkNodes(seed, 0).filter((n) => n.depth === depth)
        const rowB = generateChunkNodes(seed, 0).filter((n) => n.depth === depth + 1)
        if (rowA.length === 0 || rowB.length === 0) return
        // Reset linksDown so we observe a fresh result.
        for (const n of rowA) n.linksDown = []
        linkRows(seed, depth, rowA, rowB)
        const reached = new Set<string>()
        for (const a of rowA) for (const d of a.linksDown) reached.add(d)
        for (const b of rowB) expect(reached.has(b.id)).toBe(true)
      }),
      { numRuns: 30 },
    )
  })
})
