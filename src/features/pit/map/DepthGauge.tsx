import styles from './DepthGauge.module.css'

interface DepthGaugeProps {
  currentDepth: number
  minDepth: number
  maxDepth: number
  cameraOffset: number
  rowHeight: number
}

/**
 * Left-side depth tachymeter. Ticks align with the shaft's rows so they
 * scroll in lockstep with the camera. Current depth highlighted with a
 * gild chevron on its own row.
 */
export function DepthGauge({
  currentDepth,
  minDepth,
  maxDepth,
  cameraOffset,
  rowHeight,
}: DepthGaugeProps) {
  const rows: number[] = []
  for (let d = minDepth; d <= maxDepth; d++) rows.push(d)
  return (
    <aside className={styles.gauge} aria-label="depth gauge">
      <div
        className={styles.ticks}
        style={{ transform: `translateY(${cameraOffset}px)` }}
      >
        {rows.map((d) => (
          <div
            key={d}
            className={styles.tick}
            style={{ top: d * rowHeight, height: rowHeight }}
            data-current={d === currentDepth}
          >
            <span className={styles.label}>D{String(d).padStart(3, '0')}</span>
            {d === currentDepth && <span className={styles.chevron}>◄</span>}
          </div>
        ))}
      </div>
    </aside>
  )
}
