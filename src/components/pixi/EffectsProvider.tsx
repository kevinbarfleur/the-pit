import { createContext, useEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { EffectsEngine } from '../../pixi/EffectsEngine'

export type EffectsContextValue = EffectsEngine | null

export const EffectsContext = createContext<EffectsContextValue>(null)

export function EffectsProvider({ children }: { children: ReactNode }) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const [engine, setEngine] = useState<EffectsEngine | null>(null)

  useEffect(() => {
    if (typeof window === 'undefined') return
    const host = document.createElement('div')
    host.setAttribute('data-pit-effects-root', '')
    document.body.appendChild(host)
    containerRef.current = host

    const instance = new EffectsEngine(host)
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

  return <EffectsContext.Provider value={value}>{children}</EffectsContext.Provider>
}
