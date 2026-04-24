import type { CSSProperties, ReactNode } from 'react'
import styles from './Panel.module.css'

interface PanelProps {
  raised?: boolean
  className?: string
  style?: CSSProperties
  children?: ReactNode
}

export function Panel({ raised, className, style, children }: PanelProps) {
  return (
    <div
      className={`${styles.panel} ${raised ? styles.raised : ''} ${className ?? ''}`.trim()}
      style={style}
    >
      {children}
    </div>
  )
}
