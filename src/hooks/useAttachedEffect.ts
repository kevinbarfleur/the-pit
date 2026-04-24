import { useEffect } from 'react'
import type { RefObject } from 'react'
import type { AttachConfig, AttachKind } from '../pixi/EffectsEngine'
import { useEffects } from './useEffects'

/**
 * Attaches a passive Pixi effect (pulse/ripple/sparkle/drips) to a DOM element
 * for the lifetime of the component. Detaches automatically on unmount or when
 * the engine is unavailable.
 */
export function useAttachedEffect<T extends HTMLElement>(
  ref: RefObject<T | null>,
  kind: AttachKind,
  config: AttachConfig = {},
  active: boolean = true,
): void {
  const engine = useEffects()

  useEffect(() => {
    if (!engine || !active) return
    const el = ref.current
    if (!el) return
    const detach = engine.attach(el, kind, config)
    return () => {
      detach()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [engine, kind, active, config.color, config.intensity])
}
