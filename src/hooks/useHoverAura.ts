import { useEffect } from 'react'
import type { RefObject } from 'react'
import type { AttachConfig } from '../pixi/EffectsEngine'
import { useEffects } from './useEffects'

/**
 * Binds a hover-driven aura to an element. Six orbiting pixel motes appear
 * around the element while the pointer is over it, fade out on leave.
 */
export function useHoverAura<T extends HTMLElement>(
  ref: RefObject<T | null>,
  config: AttachConfig = {},
  enabled: boolean = true,
): void {
  const engine = useEffects()

  useEffect(() => {
    if (!engine || !enabled) return
    const el = ref.current
    if (!el) return

    const { id, detach } = engine.attachWithHandle(el, 'aura', config)

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
  }, [engine, enabled, config.color, config.intensity])
}
