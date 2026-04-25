import { forwardRef } from 'react'
import type { CSSProperties } from 'react'
import { PixelFrame } from '../../components/ui'
import styles from './InfoCluster.module.css'

export type ClusterTone = 'bone' | 'gild' | 'amber' | 'violet' | 'red' | 'cyan'

interface InfoClusterProps {
  glyph: string
  label: string
  value: string
  /** Polar angle in degrees, 0 = pointing up, clockwise. */
  angleDeg: number
  /** Distance from the slot centre, in pixels. */
  radiusPx: number
  /** Per-cluster tilt for hand-drawn imperfection. */
  tiltDeg: number
  tone?: ClusterTone
}

const TONE_CLASS: Record<ClusterTone, string> = {
  bone: '',
  gild: styles.toneGild,
  amber: styles.toneAmber,
  violet: styles.toneViolet,
  red: styles.toneRed,
  cyan: styles.toneCyan,
}

/**
 * Runic info container orbiting the central CTA. Wraps a PixelFrame so
 * the corner runes (┏╍ ╍┓ ┗╍ ╍┛ + ◈) are inherited from the design
 * system. A per-cluster tilt rotates each frame a few degrees off-axis
 * so the five clusters never read as a clean stamped grid.
 *
 * `forwardRef` exposes the wrapper so the parent can measure its
 * bounding rect when wiring chain anchors against the central button.
 */
export const InfoCluster = forwardRef<HTMLDivElement, InfoClusterProps>(
  function InfoCluster(
    { glyph, label, value, angleDeg, radiusPx, tiltDeg, tone = 'bone' },
    ref,
  ) {
    const style = {
      ['--angle' as string]: `${angleDeg}deg`,
      ['--radius' as string]: `${radiusPx}px`,
      ['--tilt' as string]: `${tiltDeg}deg`,
    } as CSSProperties

    return (
      <div
        ref={ref}
        className={`${styles.cluster} ${TONE_CLASS[tone]}`.trim()}
        style={style}
      >
        <PixelFrame>
          <div className={styles.body}>
            <span className={styles.glyph}>{glyph}</span>
            <span className={styles.label}>{label}</span>
            <span className={styles.value}>{value}</span>
          </div>
        </PixelFrame>
      </div>
    )
  },
)
