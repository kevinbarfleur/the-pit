import { create } from 'zustand'
import type { PitNodeType } from '../game/pit/types'

/**
 * UI-only state for the Pit feature: scene machine, hover preview, and the
 * transition payload that the zoom uses as its anchor rect.
 *
 * Game truth (player position, cleared nodes, run seed) lives in
 * `usePitRun`. Per CLAUDE.md, Zustand is reserved for UI concerns.
 */

export type PitScene = 'pit' | 'zooming-in' | 'in-node' | 'zooming-out'

export interface PendingCommit {
  nodeId: string
  nodeType: PitNodeType
  /** Viewport-space rect of the node at click time — the zoom anchor. */
  rect: { x: number; y: number; width: number; height: number }
}

interface PitUiState {
  scene: PitScene
  hoveredId: string | null
  pendingCommit: PendingCommit | null

  setScene: (scene: PitScene) => void
  setHoveredId: (id: string | null) => void
  setPendingCommit: (p: PendingCommit | null) => void
  /** Kick off the zoom-in sequence from a confirmed commit. */
  startZoomIn: (p: PendingCommit) => void
  /** Transition finished — we are now inside the node's room. */
  enterNode: () => void
  /** Exit button pressed inside a room. */
  startZoomOut: () => void
  /** Zoom-out complete — back on the map. */
  returnToPit: () => void
  /** Hard reset (escape mid-transition). */
  cancelTransition: () => void
}

export const usePitUiStore = create<PitUiState>((set) => ({
  scene: 'pit',
  hoveredId: null,
  pendingCommit: null,

  setScene: (scene) => set({ scene }),
  setHoveredId: (hoveredId) => set({ hoveredId }),
  setPendingCommit: (pendingCommit) => set({ pendingCommit }),

  startZoomIn: (p) => set({ scene: 'zooming-in', pendingCommit: p }),
  enterNode: () => set({ scene: 'in-node' }),
  startZoomOut: () => set({ scene: 'zooming-out' }),
  returnToPit: () => set({ scene: 'pit', pendingCommit: null }),
  cancelTransition: () => set({ scene: 'pit', pendingCommit: null }),
}))
