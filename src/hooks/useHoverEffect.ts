import { useEffect } from 'react'
import type { RefObject } from 'react'
import type { AttachConfig, AttachKind } from '../pixi/EffectsEngine'
import { useEffects } from './useEffects'

/**
 * Bind a hover-driven attached effect to an element.
 *
 * Covers any AttachKind that supports setEnabled() (drip-pool, ivy, embers,
 * …). The effect attaches on mount (disabled), flips to enabled on
 * pointerenter / focus, back to disabled on pointerleave / blur, and cleanly
 * detaches on unmount so lingering drain/retract animations can complete.
 */
export function useHoverEffect<T extends HTMLElement>(
  ref: RefObject<T | null>,
  kind: AttachKind,
  config: AttachConfig = {},
  enabled: boolean = true,
): void {
  const engine = useEffects()

  useEffect(() => {
    if (!engine || !enabled) return
    const el = ref.current
    if (!el) return

    const { id, detach } = engine.attachWithHandle(el, kind, config)
    engine.setEnabled(id, false)

    const onEnter = () => engine.setEnabled(id, true)
    const onLeave = () => engine.setEnabled(id, false)

    el.addEventListener('pointerenter', onEnter)
    el.addEventListener('pointerleave', onLeave)
    el.addEventListener('focus', onEnter)
    el.addEventListener('blur', onLeave)

    return () => {
      el.removeEventListener('pointerenter', onEnter)
      el.removeEventListener('pointerleave', onLeave)
      el.removeEventListener('focus', onEnter)
      el.removeEventListener('blur', onLeave)
      detach()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [engine, enabled, kind, config.color, config.intensity])
}
