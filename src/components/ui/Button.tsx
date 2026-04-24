import { forwardRef, useRef } from 'react'
import type { ButtonHTMLAttributes, PointerEvent, ReactNode } from 'react'
import { useEffects } from '../../hooks/useEffects'
import { useHoverEffect } from '../../hooks/useHoverEffect'
import type { AttachKind } from '../../pixi/EffectsEngine'
import styles from './Button.module.css'

export type ButtonVariant = 'default' | 'primary' | 'danger' | 'ghost'
export type ButtonSize = 'sm' | 'md' | 'lg'

interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  variant?: ButtonVariant
  size?: ButtonSize
  juicy?: boolean
  children: ReactNode
}

// Hover effect assigned per variant — each variant has its own physical
// personality:
//   - primary: pixel ivy growing from the edges (growth)
//   - danger: liquid blood drip (flow)
//   - default: amber embers rising (buoyancy)
//   - ghost: no hover effect (kept intentionally muted; click still puffs)
const HOVER_KIND: Record<ButtonVariant, AttachKind | null> = {
  primary: 'grass',
  danger: 'drip-pool',
  default: 'embers',
  ghost: null,
}

// Raw 0xRRGGBB numbers fed straight to PIXI.Graphics.
const EFFECT_COLOR: Record<ButtonVariant, number> = {
  primary: 0x9ae66e,
  danger: 0xd45a5a,
  default: 0xd4a147,
  ghost: 0x8a8a8a,
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'default', size = 'md', juicy, className, onPointerDown, children, ...rest },
  ref,
) {
  const engine = useEffects()
  const internalRef = useRef<HTMLButtonElement | null>(null)

  // Hover-only effects for juicy buttons. Ghost is intentionally null.
  const hoverKind = HOVER_KIND[variant]
  const shouldHover = juicy === true && hoverKind !== null
  useHoverEffect(
    internalRef,
    hoverKind ?? 'grass',
    { color: EFFECT_COLOR[variant] },
    shouldHover,
  )

  const variantClass =
    variant === 'primary'
      ? styles.primary
      : variant === 'danger'
        ? styles.danger
        : variant === 'ghost'
          ? styles.ghost
          : ''

  const sizeClass = size === 'sm' ? styles.sm : size === 'lg' ? styles.lg : ''

  const handlePointerDown = (event: PointerEvent<HTMLButtonElement>) => {
    if (juicy && engine) {
      engine.emitBurst({
        x: event.clientX,
        y: event.clientY,
        variant,
      })
    }
    onPointerDown?.(event)
  }

  const setRefs = (node: HTMLButtonElement | null) => {
    internalRef.current = node
    if (typeof ref === 'function') ref(node)
    else if (ref) (ref as React.MutableRefObject<HTMLButtonElement | null>).current = node
  }

  return (
    <button
      ref={setRefs}
      type={rest.type ?? 'button'}
      className={`${styles.btn} ${variantClass} ${sizeClass} ${className ?? ''}`.trim()}
      onPointerDown={handlePointerDown}
      {...rest}
    >
      {children}
    </button>
  )
})
