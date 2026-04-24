import { createContext, useEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { ChainsEngine } from '../../pixi/ChainsEngine'

export type ChainsContextValue = ChainsEngine | null

export const ChainsContext = createContext<ChainsContextValue>(null)

/**
 * Mounts a single `ChainsEngine` next to the `EffectsProvider`. Mirrors
 * the effects provider pattern exactly — a dedicated DOM host under
 * document.body, an engine initialised asynchronously, exposed via
 * context. Chains and effects are intentionally independent: zooming
 * out of a node may freeze chains while leaving other effects running.
 */
export function ChainsProvider({ children }: { children: ReactNode }) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const [engine, setEngine] = useState<ChainsEngine | null>(null)

  useEffect(() => {
    if (typeof window === 'undefined') return
    const host = document.createElement('div')
    host.setAttribute('data-pit-chains-root', '')
    document.body.appendChild(host)
    containerRef.current = host

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
  }, [])

  const value = useMemo(() => engine, [engine])

  return <ChainsContext.Provider value={value}>{children}</ChainsContext.Provider>
}
