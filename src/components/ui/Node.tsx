import type { HTMLAttributes, ReactNode } from 'react'
import styles from './Node.module.css'

export type NodeVariant = 'normal' | 'now' | 'elite' | 'boss' | 'locked'

interface NodeProps extends HTMLAttributes<HTMLDivElement> {
  variant?: NodeVariant
  children: ReactNode
}

export function Node({ variant = 'normal', className, children, ...rest }: NodeProps) {
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
    <div className={`${styles.node} ${variantClass} ${className ?? ''}`.trim()} {...rest}>
      {children}
    </div>
  )
}
