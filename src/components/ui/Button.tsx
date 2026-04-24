import { forwardRef, useRef } from 'react'
import type { ButtonHTMLAttributes, PointerEvent, ReactNode } from 'react'
import { useEffects } from '../../hooks/useEffects'
import { useHoverDrip } from '../../hooks/useHoverDrip'
import styles from './Button.module.css'

export type ButtonVariant = 'default' | 'primary' | 'danger' | 'ghost'
export type ButtonSize = 'sm' | 'md' | 'lg'

interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  variant?: ButtonVariant
  size?: ButtonSize
  juicy?: boolean
  children: ReactNode
}

// Drip color by variant — matches the border accent, slightly wet-looking hue.
// We keep these as raw 0xRRGGBB numbers so PIXI.Graphics can consume them
// without an extra parse step per paint.
const DRIP_COLOR: Record<ButtonVariant, number> = {
  primary: 0x9ae66e,
  danger: 0xd45a5a,
  default: 0xb58b3a,
  ghost: 0x8a8a8a,
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'default', size = 'md', juicy, className, onPointerDown, children, ...rest },
  ref,
) {
  const engine = useEffects()
  const internalRef = useRef<HTMLButtonElement | null>(null)

  // Hover drip — applies to all juicy buttons; color matched to variant
  useHoverDrip(internalRef, { color: DRIP_COLOR[variant] }, juicy === true)

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
