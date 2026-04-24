import type { ReactNode } from 'react'
import styles from './Pill.module.css'

export type PillTone = 'neutral' | 'g' | 'a' | 'r' | 'v' | 'c'

interface PillProps {
  tone?: PillTone
  dot?: boolean
  className?: string
  children: ReactNode
}

export function Pill({ tone = 'neutral', dot, className, children }: PillProps) {
  const toneClass = tone === 'neutral' ? '' : styles[tone]
  return (
    <span className={`${styles.pill} ${toneClass} ${className ?? ''}`.trim()}>
      {dot && <span className={styles.dot} aria-hidden />}
      {children}
    </span>
  )
}
