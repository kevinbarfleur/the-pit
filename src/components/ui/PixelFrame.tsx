import type { CSSProperties, ReactNode } from 'react'
import styles from './PixelFrame.module.css'

export type PixelFrameTone = 'default' | 'raised' | 'gild'

interface PixelFrameProps {
  tone?: PixelFrameTone
  title?: ReactNode
  right?: ReactNode
  className?: string
  style?: CSSProperties
  inner?: CSSProperties
  children?: ReactNode
}

export function PixelFrame({
  tone = 'default',
  title,
  right,
  className,
  style,
  inner,
  children,
}: PixelFrameProps) {
  const toneClass = tone === 'raised' ? styles.raised : tone === 'gild' ? styles.gild : ''
  return (
    <div className={`${styles.pf} ${toneClass} ${className ?? ''}`.trim()} style={style}>
      <span className={`${styles.corner} ${styles.cornerTL}`} aria-hidden>┏╍</span>
      <span className={`${styles.corner} ${styles.cornerTR}`} aria-hidden>╍┓</span>
      <span className={`${styles.corner} ${styles.cornerBL}`} aria-hidden>┗╍</span>
      <span className={`${styles.corner} ${styles.cornerBR}`} aria-hidden>╍┛</span>
      <span className={`${styles.rune} ${styles.runeTL}`} aria-hidden>◈</span>
      <span className={`${styles.rune} ${styles.runeTR}`} aria-hidden>◈</span>
      <span className={`${styles.rune} ${styles.runeBL}`} aria-hidden>◈</span>
      <span className={`${styles.rune} ${styles.runeBR}`} aria-hidden>◈</span>
      {title !== undefined && (
        <div className={styles.title}>
          <span aria-hidden>━━◆ </span>
          <span className={styles.titleText}>{title}</span>
          <span aria-hidden> ◆━━</span>
          {right !== undefined && <span className={styles.titleRight}>{right}</span>}
        </div>
      )}
      <div className={styles.inner} style={inner}>
        {children}
      </div>
    </div>
  )
}
