import { createContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { ChainsEngine } from '../../pixi/ChainsEngine'

export type ChainsContextValue = ChainsEngine | null

export const ChainsContext = createContext<ChainsContextValue>(null)

interface ChainsProviderProps {
  children: ReactNode
  /**
   * Optional id of a DOM element the engine's canvas should be
   * attached to. Default: document.body. When a specific host is
   * provided, the canvas is layered inside that element's stacking
   * context — use this to keep chains behind islands while still
   * letting the player see them over the shaft walls.
   */
  mountTargetId?: string
}

/**
 * Mounts a single `ChainsEngine` next to the `EffectsProvider`. Mirrors
 * the effects provider pattern — a dedicated DOM host, an engine
 * initialised asynchronously, exposed via context. Chains and effects
 * are intentionally independent: zooming out of a node may freeze
 * chains while leaving other effects running.
 */
export function ChainsProvider({ children, mountTargetId }: ChainsProviderProps) {
  const [engine, setEngine] = useState<ChainsEngine | null>(null)

  useEffect(() => {
    if (typeof window === 'undefined') return
    const host = document.createElement('div')
    host.setAttribute('data-pit-chains-root', '')
    const target: HTMLElement =
      (mountTargetId ? document.getElementById(mountTargetId) : null) ?? document.body
    target.appendChild(host)

    const instance = new ChainsEngine(host)
    let cancelled = false
    instance.init().then(() => {
      if (cancelled) return
      setEngine(instance)
    })

    return () => {
      cancelled = true
      instance.dispose()
      host.remove()
    }
  }, [mountTargetId])

  const value = useMemo(() => engine, [engine])

  return <ChainsContext.Provider value={value}>{children}</ChainsContext.Provider>
}
