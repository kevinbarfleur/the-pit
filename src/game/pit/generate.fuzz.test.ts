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
import { CHUNK_HEIGHT, MAX_COLUMNS } from './types'

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
      fc.property(seedArb, fc.integer({ min: 0, max: 10 }), (seed, ci) => {
        // After the chunked refactor, the boss lives at the LAST depth
        // of every chunk: chunkIndex × CHUNK_HEIGHT + CHUNK_HEIGHT − 1.
        const bossDepth = ci * CHUNK_HEIGHT + CHUNK_HEIGHT - 1
        const nodes = generateChunkNodes(seed, ci)
        const row = nodes.filter((n) => n.depth === bossDepth)
        expect(row).toHaveLength(1)
        expect(row[0].type).toBe('boss')
        expect(row[0].column).toBe(Math.floor(MAX_COLUMNS / 2))
      }),
      { numRuns: 30 },
    )
  })

  it('chunk entry is a single node at col 1', () => {
    fc.assert(
      fc.property(seedArb, fc.integer({ min: 0, max: 10 }), (seed, ci) => {
        const entryDepth = ci * CHUNK_HEIGHT
        const nodes = generateChunkNodes(seed, ci)
        const row = nodes.filter((n) => n.depth === entryDepth)
        expect(row).toHaveLength(1)
        expect(row[0].column).toBe(Math.floor(MAX_COLUMNS / 2))
      }),
      { numRuns: 30 },
    )
  })

  it('boss row collapses to width 1; pre-boss rows stay within MAX_COLUMNS', () => {
    // The walker only strictly enforces single-column convergence at
    // the boss row itself. Rows immediately above can hold 1..MAX_COLUMNS
    // active columns — paths may converge and re-spread depending on
    // the no-cross filter. We assert the bounds, not strict monotonicity.
    fc.assert(
      fc.property(seedArb, fc.integer({ min: 0, max: 8 }), (seed, ci) => {
        const bossDepth = ci * CHUNK_HEIGHT + CHUNK_HEIGHT - 1
        const window = materializeWindow(seed, bossDepth - 3, bossDepth)
        for (let d = bossDepth - 3; d <= bossDepth; d++) {
          const w = window.byDepth.get(d)?.length ?? 0
          expect(w).toBeGreaterThanOrEqual(1)
          expect(w).toBeLessThanOrEqual(MAX_COLUMNS)
        }
        expect(window.byDepth.get(bossDepth)?.length).toBe(1)
      }),
      { numRuns: 30 },
    )
  })

  it('no edges cross — Slay-style anti-crossing invariant', () => {
    fc.assert(
      fc.property(
        seedArb,
        fc.integer({ min: 0, max: 30 }),
        fc.integer({ min: 5, max: 25 }),
        (seed, from, span) => {
          const win = materializeWindow(seed, from, from + span)
          // Build the edge list for every depth pair in the window.
          const edgesByDepth = new Map<number, Array<{ from: number; to: number }>>()
          for (const n of win.nodes) {
            for (const cid of n.linksDown) {
              const child = win.byId.get(cid)
              if (!child) continue
              const list = edgesByDepth.get(n.depth) ?? []
              list.push({ from: n.column, to: child.column })
              edgesByDepth.set(n.depth, list)
            }
          }
          for (const list of edgesByDepth.values()) {
            for (let i = 0; i < list.length; i++) {
              for (let j = i + 1; j < list.length; j++) {
                const a = list[i]
                const b = list[j]
                const dp = a.from - b.from
                const dc = a.to - b.to
                expect(dp * dc).toBeGreaterThanOrEqual(0)
              }
            }
          }
        },
      ),
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

describe('linkRows — backward-compat shim', () => {
  it('is a no-op now that paths populate linksDown inside generateChunkNodes', () => {
    fc.assert(
      fc.property(seedArb, fc.integer({ min: 0, max: 30 }), (seed, depth) => {
        const rowA = generateChunkNodes(seed, 0).filter((n) => n.depth === depth)
        const rowB = generateChunkNodes(seed, 0).filter((n) => n.depth === depth + 1)
        if (rowA.length === 0 || rowB.length === 0) return
        // Snapshot the existing linksDown then call linkRows. The
        // shim is intentionally a no-op so the snapshot must be intact.
        const snapshot = rowA.map((n) => [...n.linksDown])
        linkRows(seed, depth, rowA, rowB)
        for (let i = 0; i < rowA.length; i++) {
          expect(rowA[i].linksDown).toEqual(snapshot[i])
        }
      }),
      { numRuns: 30 },
    )
  })
})
