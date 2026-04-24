import { Kbd } from './Kbd'
import styles from './Footer.module.css'

export interface FooterItem {
  k: string
  l: string
}

interface FooterProps {
  items: FooterItem[]
}

export function Footer({ items }: FooterProps) {
  return (
    <div className={styles.footer}>
      {items.map((it, i) => (
        <span key={i}>
          <Kbd>{it.k}</Kbd> <span className={styles.label}>{it.l}</span>
        </span>
      ))}
    </div>
  )
}
