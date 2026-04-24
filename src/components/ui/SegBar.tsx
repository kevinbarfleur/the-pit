import styles from './SegBar.module.css'

export type SegBarKind = 'green' | 'amber' | 'cyan' | 'violet'

interface SegBarProps {
  total: number
  on: number
  kind?: SegBarKind
  className?: string
}

export function SegBar({ total, on, kind = 'green', className }: SegBarProps) {
  const kindClass =
    kind === 'amber'
      ? styles.kindAmber
      : kind === 'cyan'
        ? styles.kindCyan
        : kind === 'violet'
          ? styles.kindViolet
          : ''
  return (
    <div className={`${styles.segbar} ${kindClass} ${className ?? ''}`.trim()}>
      {Array.from({ length: total }).map((_, i) => (
        <span key={i} className={`${styles.segment} ${i < on ? styles.on : ''}`} />
      ))}
    </div>
  )
}
