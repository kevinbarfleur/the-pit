import styles from './Bar.module.css'

export type BarKind = 'hp' | 'mtr' | 'torch' | 'enemy'

interface BarLabel {
  l: string
  v: string
}

interface BarProps {
  kind: BarKind
  pct: number
  label?: BarLabel
  className?: string
}

export function Bar({ kind, pct, label, className }: BarProps) {
  const clamped = Math.max(0, Math.min(100, pct))
  return (
    <div className={`${styles.wrap} ${className ?? ''}`.trim()}>
      {label && (
        <div className={styles.label}>
          <span className={styles.l}>{label.l}</span>
          <span>{label.v}</span>
        </div>
      )}
      <div className={`${styles.bar} ${styles[kind]}`}>
        <span className={styles.fill} style={{ width: `${clamped}%` }} />
      </div>
    </div>
  )
}
