import type { CSSProperties, HTMLAttributes, ReactNode } from 'react'
import styles from './Row.module.css'

interface RowProps extends HTMLAttributes<HTMLDivElement> {
  selected?: boolean
  children: ReactNode
  style?: CSSProperties
}

export function Row({ selected, className, children, ...rest }: RowProps) {
  return (
    <div className={`${styles.row} ${selected ? styles.sel : ''} ${className ?? ''}`.trim()} {...rest}>
      {children}
    </div>
  )
}
