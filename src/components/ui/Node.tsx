import { useRef } from 'react'
import type { HTMLAttributes, ReactNode } from 'react'
import { useAttachedEffect } from '../../hooks/useAttachedEffect'
import styles from './Node.module.css'

export type NodeVariant = 'normal' | 'now' | 'elite' | 'boss' | 'locked'

interface NodeProps extends HTMLAttributes<HTMLDivElement> {
  variant?: NodeVariant
  children: ReactNode
}

export function Node({ variant = 'normal', className, children, ...rest }: NodeProps) {
  const ref = useRef<HTMLDivElement | null>(null)

  // Auto-attach ambient effects for notable node variants.
  useAttachedEffect(ref, 'ripple', {}, variant === 'now')
  useAttachedEffect(ref, 'pulse', {}, variant === 'boss')

  const variantClass =
    variant === 'now'
      ? styles.now
      : variant === 'elite'
        ? styles.elite
        : variant === 'boss'
          ? styles.boss
          : variant === 'locked'
            ? styles.locked
            : ''
  return (
    <div ref={ref} className={`${styles.node} ${variantClass} ${className ?? ''}`.trim()} {...rest}>
      {children}
    </div>
  )
}
