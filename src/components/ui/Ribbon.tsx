import type { ReactNode } from 'react'
import styles from './Ribbon.module.css'

interface RibbonProps {
  children: ReactNode
}

export function Ribbon({ children }: RibbonProps) {
  return (
    <div className={styles.ribbon}>
      <span aria-hidden>▓▒░━━━━◆ </span>
      <span className={styles.text}>{children}</span>
      <span aria-hidden> ◆━━━━░▒▓</span>
    </div>
  )
}
