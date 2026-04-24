import { useCallback, useEffect } from 'react'
import { usePitRun } from '../../hooks/usePitRun'
import { usePitUiStore } from '../../stores/pitUiStore'
import { PitView } from './map/PitView'
import { ZoomTransition } from './transition/ZoomTransition'
import { RoomForType } from './rooms/RoomForType'
import styles from './PitScene.module.css'

/**
 * Top-level orchestrator for `/pit`. Owns the scene state machine and
 * routes rendering between the map, the zoom transition, and the node
 * rooms. Deliberately a single mount point — no TanStack sub-routes — so
 * the zoom transition can blend the map and the room without a route swap.
 */
export function PitScene() {
  const run = usePitRun()
  const scene = usePitUiStore((s) => s.scene)
  const pendingCommit = usePitUiStore((s) => s.pendingCommit)
  const cancelTransition = usePitUiStore((s) => s.cancelTransition)
  const enterNode = usePitUiStore((s) => s.enterNode)
  const returnToPit = usePitUiStore((s) => s.returnToPit)
  const startZoomOut = usePitUiStore((s) => s.startZoomOut)

  // Escape key cancels a pending zoom / triggers room exit.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return
      if (scene === 'zooming-in') cancelTransition()
      else if (scene === 'in-node') startZoomOut()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [scene, cancelTransition, startZoomOut])

  const onZoomInComplete = useCallback(() => {
    if (!pendingCommit) return
    const node = run.window.byId.get(pendingCommit.nodeId)
    if (node) run.commit(node)
    enterNode()
  }, [pendingCommit, run, enterNode])

  const onZoomOutComplete = useCallback(() => {
    if (pendingCommit) {
      const node = run.window.byId.get(pendingCommit.nodeId)
      if (node) run.registerClear(node)
    }
    returnToPit()
  }, [pendingCommit, run, returnToPit])

  const showMap = scene === 'pit' || scene === 'zooming-in' || scene === 'zooming-out'
  const showRoom = scene === 'in-node' || scene === 'zooming-out'
  const showTransition = scene === 'zooming-in' || scene === 'zooming-out'

  return (
    <div className={styles.scene}>
      {showMap && <PitView run={run} />}
      {showRoom && pendingCommit && (
        <div className={styles.roomLayer}>
          <RoomForType type={pendingCommit.nodeType} onExit={startZoomOut} />
        </div>
      )}
      {showTransition && pendingCommit && (
        <ZoomTransition
          anchor={pendingCommit.rect}
          direction={scene === 'zooming-in' ? 'in' : 'out'}
          onComplete={scene === 'zooming-in' ? onZoomInComplete : onZoomOutComplete}
        />
      )}
    </div>
  )
}
