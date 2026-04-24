import { useCallback, useMemo, useReducer } from 'react'
import { materializeWindow, type MaterializedWindow } from '../game/pit/generate'
import { STARTING_DEPTH, type PitNode, type PitNodeState } from '../game/pit/types'
import { farmRewardScaleBp } from '../game/pit/rewardScale'

/**
 * Run state for the Pit. Distinct from UI state (see `pitUiStore`): this
 * owns the game-truth information — player position, which nodes have been
 * cleared, and the seed anchoring the procedural graph.
 *
 * Per CLAUDE.md, game state does not live in Zustand. A local `useReducer`
 * keeps the contract honest and makes a later Convex migration mechanical
 * (swap the dispatcher, keep the selectors).
 *
 * TODO(convex): once the schema exists, back this hook with Convex queries
 * + mutations instead of local reducer state.
 */

interface RunState {
  runSeed: string
  currentId: string
  path: string[] // ordered list of committed node ids (player history)
  clearedAt: Map<string, { timesCleared: number; lastClearedAtDepth: number }>
  startedAtDepth: number
  deepestDepth: number // for future leaderboard surfacing
}

type Action =
  | { type: 'start'; runSeed: string; startDepth?: number }
  | { type: 'commit'; nodeId: string; nodeDepth: number }
  | { type: 'retreat'; nodeId: string }
  | { type: 'registerClear'; nodeId: string; clearedAtDepth: number }

function reducer(state: RunState, action: Action): RunState {
  switch (action.type) {
    case 'start': {
      const depth = action.startDepth ?? STARTING_DEPTH
      const rootId = rootNodeIdAtDepth(action.runSeed, depth)
      return {
        runSeed: action.runSeed,
        currentId: rootId,
        path: [rootId],
        clearedAt: new Map(),
        startedAtDepth: depth,
        deepestDepth: depth,
      }
    }
    case 'commit': {
      const path = state.path.includes(action.nodeId)
        ? state.path
        : [...state.path, action.nodeId]
      return {
        ...state,
        currentId: action.nodeId,
        path,
        deepestDepth: Math.max(state.deepestDepth, action.nodeDepth),
      }
    }
    case 'retreat': {
      return { ...state, currentId: action.nodeId }
    }
    case 'registerClear': {
      const prior = state.clearedAt.get(action.nodeId)
      const next = new Map(state.clearedAt)
      next.set(action.nodeId, {
        timesCleared: (prior?.timesCleared ?? 0) + 1,
        lastClearedAtDepth: action.clearedAtDepth,
      })
      return { ...state, clearedAt: next }
    }
  }
}

/**
 * Resolve a deterministic root node for a fresh run. We pick the leftmost
 * node of the starting depth row — every row is guaranteed ≥ 1 node.
 */
function rootNodeIdAtDepth(runSeed: string, depth: number): string {
  const w = materializeWindow(runSeed, depth, depth)
  const row = w.byDepth.get(depth)
  if (!row || row.length === 0) {
    throw new Error(`rootNodeIdAtDepth: empty row at depth ${depth}`)
  }
  return row[0].id
}

const INITIAL_STATE: RunState = (() => {
  const runSeed = 'pit-default'
  const rootId = rootNodeIdAtDepth(runSeed, STARTING_DEPTH)
  return {
    runSeed,
    currentId: rootId,
    path: [rootId],
    clearedAt: new Map(),
    startedAtDepth: STARTING_DEPTH,
    deepestDepth: STARTING_DEPTH,
  }
})()

export interface PitRun {
  /** Raw reducer state — mostly for display. */
  state: RunState
  /** The graph window currently materialized for rendering. */
  window: MaterializedWindow
  /** Depth of the player's current node — convenience selector. */
  currentDepth: number
  /** Resolve visual state for a node from its topology + run state. */
  nodeState: (node: PitNode) => PitNodeState
  /** Reward scale (bp) for replaying a cleared node at current depth. */
  rewardScaleFor: (node: PitNode) => number
  /** Can the player commit to this node from `currentId` in one step? */
  canCommit: (node: PitNode) => boolean

  start: (runSeed: string, startDepth?: number) => void
  commit: (node: PitNode) => void
  retreat: (node: PitNode) => void
  registerClear: (node: PitNode) => void
}

/**
 * Window bounds around the current depth. The UI virtualizes this — we keep
 * a bit of headroom above (to permit backtrack scroll) and more room below
 * (so the player can see what they're descending into).
 */
const WINDOW_UP = 6
const WINDOW_DOWN = 10

export function usePitRun(): PitRun {
  const [state, dispatch] = useReducer(reducer, INITIAL_STATE)

  const window = useMemo(() => {
    const currentNode = currentNodeOf(state)
    const from = Math.max(0, currentNode.depth - WINDOW_UP)
    const to = currentNode.depth + WINDOW_DOWN
    return materializeWindow(state.runSeed, from, to)
    // The window recomputes iff the player moved OR the run reseeded.
    // Including `state` itself would re-run on every reducer dispatch —
    // we want the narrow subset.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.runSeed, state.currentId])

  const currentNode = window.byId.get(state.currentId) ?? currentNodeOf(state)
  const currentDepth = currentNode.depth

  const nodeState = useCallback(
    (node: PitNode): PitNodeState => {
      if (node.id === state.currentId) return 'current'
      const cleared = state.clearedAt.get(node.id)
      if (cleared) {
        const scale = farmRewardScaleBp(currentDepth, node.depth)
        return scale === 0 ? 'cleared-exhausted' : 'cleared'
      }
      // Bypassed: node is at a depth the player already crossed but wasn't
      // part of their path.
      if (node.depth < currentDepth && !state.path.includes(node.id)) {
        return 'bypassed'
      }
      // Locked: node is deeper than one step beyond current. Even reachable
      // branches further down read as "not yet" for the player — clarifies
      // which tile is actionable.
      if (node.depth > currentDepth + 1) return 'locked'
      // Fresh: reachable via a downlink from any cleared/current node.
      return 'fresh'
    },
    [state.currentId, state.path, state.clearedAt, currentDepth],
  )

  const rewardScaleFor = useCallback(
    (node: PitNode) => farmRewardScaleBp(currentDepth, node.depth),
    [currentDepth],
  )

  const canCommit = useCallback(
    (node: PitNode): boolean => {
      if (node.id === state.currentId) return false
      // Descend by one depth via a known downlink, or revisit an already
      // cleared node regardless of direction.
      if (state.clearedAt.has(node.id)) return true
      if (node.depth === currentDepth + 1) {
        return currentNode.linksDown.includes(node.id)
      }
      return false
    },
    [state.currentId, state.clearedAt, currentDepth, currentNode],
  )

  const start = useCallback((runSeed: string, startDepth?: number) => {
    dispatch({ type: 'start', runSeed, startDepth })
  }, [])
  const commit = useCallback((node: PitNode) => {
    dispatch({ type: 'commit', nodeId: node.id, nodeDepth: node.depth })
  }, [])
  const retreat = useCallback((node: PitNode) => {
    dispatch({ type: 'retreat', nodeId: node.id })
  }, [])
  const registerClear = useCallback(
    (node: PitNode) => {
      dispatch({ type: 'registerClear', nodeId: node.id, clearedAtDepth: currentDepth })
    },
    [currentDepth],
  )

  return {
    state,
    window,
    currentDepth,
    nodeState,
    rewardScaleFor,
    canCommit,
    start,
    commit,
    retreat,
    registerClear,
  }
}

function currentNodeOf(state: RunState): PitNode {
  // Parse `${depth}:${column}` to reconstruct the depth — used to bootstrap
  // the window without a second materialization pass.
  const [depthStr] = state.currentId.split(':')
  const depth = Number.parseInt(depthStr, 10)
  const w = materializeWindow(state.runSeed, depth, depth)
  const n = w.byId.get(state.currentId)
  if (!n) throw new Error(`currentNodeOf: node ${state.currentId} missing from window`)
  return n
}
