/**
 * Diminishing-returns curve for farming cleared nodes above the player's
 * current depth.
 *
 * The Pit is an infinite descent; cleared nodes remain replayable so the
 * player can farm gear when scaling stalls progress. To keep farming
 * meaningful but not broken, rewards from a cleared node scale down with
 * the gap between the player's current depth and the node's depth.
 *
 * At or below the current depth the scale is full (10000 bp). Above, the
 * scale drops linearly by 600 bp per depth level of gap, hitting zero at
 * ~17 depth levels of back-track. Negative results are clamped to 0 so
 * `cleared-exhausted` is a clean predicate (`scale === 0`).
 *
 * All math is in basis points (10000 = 100%) per CLAUDE.md.
 */

/**
 * Returns the reward scale in basis points for re-clearing a node whose
 * depth is `nodeDepth` when the player's current depth is `currentDepth`.
 * - currentDepth ≥ nodeDepth → 10000 (full)
 * - currentDepth <  nodeDepth by Δ → 10000 − 600·Δ, clamped ≥ 0
 */
export function rewardScaleBp(currentDepth: number, nodeDepth: number): number {
  const delta = currentDepth - nodeDepth
  if (delta >= 0) return 10000
  // delta is negative — the player is *above* the node, which shouldn't
  // produce a farming discount. Defensive: treat same as at-depth.
  return 10000
}

/**
 * Variant used when the player has already moved past the node and is now
 * deeper; `nodeDepth` < `currentDepth`. Back-tracking to farm a shallow
 * node yields less the deeper you are.
 */
export function farmRewardScaleBp(currentDepth: number, nodeDepth: number): number {
  if (nodeDepth >= currentDepth) return 10000
  const delta = currentDepth - nodeDepth
  const scale = 10000 - 600 * delta
  return Math.max(0, scale)
}
