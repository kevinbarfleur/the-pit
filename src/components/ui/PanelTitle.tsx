import type { ReactNode } from 'react'
import styles from './PanelTitle.module.css'

interface PanelTitleProps {
  right?: ReactNode
  children: ReactNode
}

export function PanelTitle({ right, children }: PanelTitleProps) {
  return (
    <div className={styles.title}>
      <span className={styles.triL} aria-hidden>◆━</span>
      <span>{children}</span>
      <span className={styles.line} aria-hidden />
      {right !== undefined && <span>{right}</span>}
      <span className={styles.triR} aria-hidden>━◆</span>
    </div>
  )
}
