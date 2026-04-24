import { useEffect } from 'react'
import type { RefObject } from 'react'
import type { AttachConfig } from '../pixi/EffectsEngine'
import { useEffects } from './useEffects'

/**
 * Bind a hover-driven pixel-liquid drip to an element. Accumulates a pool at
 * the element's bottom-center, then drips from 3 columns (left / center /
 * right) with quasi-liquid physics. Color is inherited from the button
 * variant (caller passes it via config.color).
 *
 * While the pointer is over the element, the pool fills and columns grow
 * until they snap into falling droplets. When the pointer leaves, the
 * columns drain and the pool shrinks back to zero; the attachment is kept
 * around until unmount so that drainage can complete naturally.
 */
export function useHoverDrip<T extends HTMLElement>(
  ref: RefObject<T | null>,
  config: AttachConfig = {},
  enabled: boolean = true,
): void {
  const engine = useEffects()

  useEffect(() => {
    if (!engine || !enabled) return
    const el = ref.current
    if (!el) return

    const { id, detach } = engine.attachWithHandle(el, 'drip-pool', config)
    // starts disabled — no leak, no pool; enabled on hover
    engine.setEnabled(id, false)

    const onEnter = () => engine.setEnabled(id, true)
    const onLeave = () => engine.setEnabled(id, false)

    el.addEventListener('pointerenter', onEnter)
    el.addEventListener('pointerleave', onLeave)
    // also drain on blur (keyboard nav)
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
