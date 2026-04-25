import { useCallback, useEffect, useRef } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { usePitRun } from '../../hooks/usePitRun'
import { usePlayerIdentity } from '../../hooks/usePlayerIdentity'
import { usePlayerProfile } from '../../hooks/usePlayerProfile'
import { useDepthSync } from '../../hooks/useRunLifecycle'
import { usePitUiStore } from '../../stores/pitUiStore'
import { ChainsProvider } from '../../components/pixi/ChainsProvider'
import { PitView } from './map/PitView'
import { ZoomTransition } from './transition/ZoomTransition'
import { RoomForType } from './rooms/RoomForType'
import styles from './PitScene.module.css'

const CHAINS_HOST_ID = 'pit-chains-host'

/**
 * Top-level orchestrator for `/pit`. Owns the scene state machine and
 * routes rendering between the map, the zoom transition, and the node
 * rooms.
 *
 * Convex wiring (perpetual descent): on mount we boot the local run
 * state from the player's persistent `seed` + `currentDepth` and let
 * `usePitRun` take over. As the player commits deeper, `useDepthSync`
 * pushes the new depth back to the profile — there is no run lifecycle,
 * just a continuous progress signal. Escape returns to the hub without
 * any "end" mutation; the next visit picks up exactly where we left.
 */
export function PitScene() {
  const navigate = useNavigate()
  const identity = usePlayerIdentity()
  const profile = usePlayerProfile(identity.playerId)
  const run = usePitRun()

  const scene = usePitUiStore((s) => s.scene)
  const pendingCommit = usePitUiStore((s) => s.pendingCommit)
  const cancelTransition = usePitUiStore((s) => s.cancelTransition)
  const enterNode = usePitUiStore((s) => s.enterNode)
  const returnToPit = usePitUiStore((s) => s.returnToPit)
  const startZoomOut = usePitUiStore((s) => s.startZoomOut)

  // Boot the local run state from the player's persistent seed +
  // currentDepth exactly once per mount. `run.start` is a reducer
  // dispatch; firing it again on the same seed would reset progress,
  // so guard with a ref.
  const startedRef = useRef(false)
  useEffect(() => {
    if (startedRef.current) return
    if (!profile) return
    run.start(profile.seed, profile.currentDepth)
    startedRef.current = true
  }, [profile, run])

  useDepthSync(identity.playerId, run.currentDepth)

  const handleExit = useCallback(() => {
    void navigate({ to: '/' })
  }, [navigate])

  // Escape: cancel transition / leave room / leave map.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return
      if (scene === 'zooming-in') cancelTransition()
      else if (scene === 'in-node') startZoomOut()
      else if (scene === 'pit') handleExit()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [scene, cancelTransition, startZoomOut, handleExit])

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
    <div className={styles.scene} data-zoom={showTransition ? 'active' : 'idle'}>
      <div id={CHAINS_HOST_ID} className={styles.chainsHost} aria-hidden="true" />
      <ChainsProvider mountTargetId={CHAINS_HOST_ID}>
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
      </ChainsProvider>
      {scene === 'pit' && (
        <button
          type="button"
          className={styles.exitBtn}
          onClick={handleExit}
          data-pit-chrome
        >
          ← surface <span className={styles.exitKbd}>esc</span>
        </button>
      )}
    </div>
  )
}
