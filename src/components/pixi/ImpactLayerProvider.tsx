import { createContext, useEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { ImpactLayer } from '../../pixi/ImpactLayer'

interface EmitOptions {
  x: number
  y: number
  color?: string
  count?: number
  spread?: number
}

export type ImpactEmitter = (options: EmitOptions) => void

export const ImpactContext = createContext<ImpactEmitter | null>(null)

export function ImpactLayerProvider({ children }: { children: ReactNode }) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const [layer, setLayer] = useState<ImpactLayer | null>(null)

  useEffect(() => {
    if (typeof window === 'undefined') return
    const host = document.createElement('div')
    host.setAttribute('data-pit-impact-root', '')
    document.body.appendChild(host)
    containerRef.current = host

    const instance = new ImpactLayer(host)
    let cancelled = false
    instance.init().then(() => {
      if (cancelled) return
      setLayer(instance)
    })

    return () => {
      cancelled = true
      instance.dispose()
      host.remove()
    }
  }, [])

  const emit = useMemo<ImpactEmitter>(() => {
    return (options) => {
      layer?.emitAt(options)
    }
  }, [layer])

  return <ImpactContext.Provider value={emit}>{children}</ImpactContext.Provider>
}
