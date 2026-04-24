import type { CSSProperties } from 'react'
import styles from './Divider.module.css'

export type DividerVariant = 'dashed' | 'single' | 'double' | 'vertical'

interface DividerProps {
  variant?: DividerVariant
  className?: string
  style?: CSSProperties
}

export function Divider({ variant = 'dashed', className, style }: DividerProps) {
  const variantClass =
    variant === 'single'
      ? styles.single
      : variant === 'double'
        ? styles.double
        : variant === 'vertical'
          ? styles.vertical
          : styles.divider
  return <div className={`${variantClass} ${className ?? ''}`.trim()} style={style} role="separator" />
}
