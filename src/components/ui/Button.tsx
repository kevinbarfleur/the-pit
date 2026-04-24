import { forwardRef, useRef } from 'react'
import type { ButtonHTMLAttributes, PointerEvent, ReactNode } from 'react'
import { useEffects } from '../../hooks/useEffects'
import { useHoverAura } from '../../hooks/useHoverAura'
import styles from './Button.module.css'

export type ButtonVariant = 'default' | 'primary' | 'danger' | 'ghost'
export type ButtonSize = 'sm' | 'md' | 'lg'

interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  variant?: ButtonVariant
  size?: ButtonSize
  juicy?: boolean
  children: ReactNode
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'default', size = 'md', juicy, className, onPointerDown, children, ...rest },
  ref,
) {
  const engine = useEffects()
  const internalRef = useRef<HTMLButtonElement | null>(null)

  // Hover aura only on primary juicy buttons — one accent per view rule
  const shouldAura = juicy === true && variant === 'primary'
  useHoverAura(internalRef, {}, shouldAura)

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
