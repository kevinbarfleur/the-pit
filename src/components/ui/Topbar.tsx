import type { ReactNode } from 'react'
import { Pill } from './Pill'
import styles from './Topbar.module.css'

interface TopbarProps {
  title?: ReactNode
  brand?: ReactNode
  depth?: string | number
  torch?: string | number
  hp?: string
  gold?: string | number
  scrap?: number
  shards?: number
  right?: ReactNode
}

export function Topbar({
  title,
  brand = 'THE·PIT',
  depth,
  torch,
  hp,
  gold,
  scrap,
  shards,
  right,
}: TopbarProps) {
  return (
    <div className={styles.topbar}>
      <span className={styles.brand}>{brand}</span>
      <span className={styles.sep}>│</span>
      {title !== undefined && <span>{title}</span>}
      <div className={styles.right}>
        {depth !== undefined && (
          <Pill tone="c" dot>
            D{depth}
          </Pill>
        )}
        {torch !== undefined && (
          <Pill tone="a" dot>
            torch {torch}
          </Pill>
        )}
        {hp !== undefined && (
          <Pill tone="g" dot>
            hp {hp}
          </Pill>
        )}
        {gold !== undefined && <Pill tone="a">gold {gold}</Pill>}
        {scrap !== undefined && <Pill tone="g">scrap {scrap}</Pill>}
        {shards !== undefined && <Pill tone="v">shards {shards}</Pill>}
        {right}
      </div>
    </div>
  )
}
