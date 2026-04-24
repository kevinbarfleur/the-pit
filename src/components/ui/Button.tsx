import { forwardRef } from 'react'
import type { ButtonHTMLAttributes, PointerEvent, ReactNode } from 'react'
import { useImpact } from '../../hooks/useImpact'
import styles from './Button.module.css'

export type ButtonVariant = 'default' | 'primary' | 'danger' | 'ghost'
export type ButtonSize = 'sm' | 'md' | 'lg'

interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  variant?: ButtonVariant
  size?: ButtonSize
  juicy?: boolean
  children: ReactNode
}

const VARIANT_COLOR: Record<ButtonVariant, string> = {
  default: '#b58b3a',
  primary: '#9ae66e',
  danger: '#d45a5a',
  ghost: '#d8cfb8',
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'default', size = 'md', juicy, className, onPointerDown, children, ...rest },
  ref,
) {
  const emit = useImpact()

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
    if (juicy && emit) {
      emit({
        x: event.clientX,
        y: event.clientY,
        color: VARIANT_COLOR[variant],
      })
    }
    onPointerDown?.(event)
  }

  return (
    <button
      ref={ref}
      type={rest.type ?? 'button'}
      className={`${styles.btn} ${variantClass} ${sizeClass} ${className ?? ''}`.trim()}
      onPointerDown={handlePointerDown}
      {...rest}
    >
      {children}
    </button>
  )
})
