import { useRef } from 'react'
import type { CSSProperties, ReactNode } from 'react'
import { Tier, type TierLevel } from './Tier'
import { useAttachedEffect } from '../../hooks/useAttachedEffect'
import styles from './Card.module.css'

interface CardProps {
  tier?: TierLevel | 'service'
  name?: ReactNode
  slot?: ReactNode
  desc?: ReactNode
  flavor?: ReactNode
  tags?: ReactNode
  selected?: boolean
  rare?: boolean
  footer?: ReactNode
  className?: string
  style?: CSSProperties
  children?: ReactNode
}

export function Card({
  tier,
  name,
  slot,
  desc,
  flavor,
  tags,
  selected,
  rare,
  footer,
  className,
  style,
  children,
}: CardProps) {
  const ref = useRef<HTMLDivElement | null>(null)

  // T0 cards get a subtle violet sparkle field as long as they're mounted.
  useAttachedEffect(ref, 'sparkle', {}, tier === 0)

  const hasHeader = tier !== undefined || slot !== undefined
  return (
    <div
      ref={ref}
      className={`${styles.card} ${selected ? styles.selected : ''} ${rare ? styles.rare : ''} ${className ?? ''}`.trim()}
      style={style}
    >
      {hasHeader && (
        <div className={styles.header}>
          {tier === 'service' ? (
            <span className={styles.sub} style={{ letterSpacing: '0.12em' }}>
              SERVICE
            </span>
          ) : tier !== undefined ? (
            <Tier t={tier} />
          ) : (
            <span />
          )}
          {slot !== undefined && <span className={styles.slot}>{slot}</span>}
        </div>
      )}
      {name !== undefined && <div className={styles.name}>{name}</div>}
      {desc !== undefined && <div className={styles.desc}>{desc}</div>}
      {tags !== undefined && <div className={styles.sub}>{tags}</div>}
      {flavor !== undefined && <div className={`${styles.sub} ${styles.subFlavor}`}>&ldquo;{flavor}&rdquo;</div>}
      {children}
      {footer !== undefined && <div className={styles.footer}>{footer}</div>}
    </div>
  )
}
