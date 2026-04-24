import styles from './Tier.module.css'

export type TierLevel = 0 | 1 | 2 | 3

interface TierProps {
  t: TierLevel
  className?: string
}

const GLYPHS: Record<TierLevel, string> = {
  0: '◈ T0',
  1: '◇ T1',
  2: '◆ T2',
  3: '○ T3',
}

export function Tier({ t, className }: TierProps) {
  const toneClass = styles[`t${t}` as const]
  return <span className={`${styles.tier} ${toneClass} ${className ?? ''}`.trim()}>{GLYPHS[t]}</span>
}
