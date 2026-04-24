import { describe, it, expect } from 'vitest'
import fc from 'fast-check'
import { farmRewardScaleBp, rewardScaleBp } from './rewardScale'

const depthArb = fc.integer({ min: 0, max: 500 })

describe('rewardScaleBp', () => {
  it('is always full (10000) at or deeper than the node', () => {
    fc.assert(
      fc.property(depthArb, depthArb, (a, b) => {
        const current = Math.max(a, b)
        const node = Math.min(a, b)
        expect(rewardScaleBp(current, node)).toBe(10000)
      }),
      { numRuns: 60 },
    )
  })
})

describe('farmRewardScaleBp', () => {
  it('is bounded to [0, 10000]', () => {
    fc.assert(
      fc.property(depthArb, depthArb, (current, node) => {
        const s = farmRewardScaleBp(current, node)
        expect(s).toBeGreaterThanOrEqual(0)
        expect(s).toBeLessThanOrEqual(10000)
      }),
      { numRuns: 60 },
    )
  })

  it('is full at or deeper than the node', () => {
    fc.assert(
      fc.property(depthArb, depthArb, (a, b) => {
        const current = Math.min(a, b)
        const node = Math.max(a, b)
        expect(farmRewardScaleBp(current, node)).toBe(10000)
      }),
      { numRuns: 60 },
    )
  })

  it('is monotone non-increasing as the player descends away from the node', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 0, max: 100 }),
        fc.integer({ min: 100, max: 400 }),
        (nodeDepth, maxCurrent) => {
          let prev = 10000
          for (let c = nodeDepth; c <= maxCurrent; c++) {
            const s = farmRewardScaleBp(c, nodeDepth)
            expect(s).toBeLessThanOrEqual(prev)
            prev = s
          }
        },
      ),
      { numRuns: 20 },
    )
  })

  it('reaches zero at ~17 depth gap and stays zero', () => {
    for (let delta = 17; delta < 50; delta++) {
      expect(farmRewardScaleBp(delta, 0)).toBe(0)
    }
  })
})
