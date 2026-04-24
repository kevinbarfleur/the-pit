import type { ReactNode } from 'react'
import { createFileRoute, Link } from '@tanstack/react-router'
import {
  Button,
  Node,
  Panel,
  Pill,
  PixelFrame,
  Topbar,
} from '../../components/ui'
import styles from './wireframe.module.css'

export const Route = createFileRoute('/kit/delve')({
  component: DelveWireframe,
})

function Row({ depth, nodes }: { depth: string; nodes: ReactNode }) {
  return (
    <div className={styles.mapDepthRow}>
      <span className={styles.mapDepthLabel}>D{depth}</span>
      <div className={styles.mapDepthNodes}>{nodes}</div>
    </div>
  )
}

function DelveWireframe() {
  return (
    <div className={styles.pit}>
      <div className={styles.kitHeader}>
        <Link to="/kit" className={styles.kitLink}>
          ← /kit
        </Link>
        <span className={styles.grow} />
        <span>07 · delve map · wireframe (no logic)</span>
      </div>
      <Topbar
        title="delve · D015"
        torch="3/5"
        hp="78/90"
        right={<Pill tone="c">focus 2</Pill>}
      />
      <div className={styles.body}>
        <div className={`${styles.col} ${styles.mapScroll}`}>
          <Row depth="020" nodes={<Node variant="boss">◈ THE PIT WARDEN</Node>} />
          <div className={styles.mapConnector}>│</div>
          <Row depth="019" nodes={<Node variant="locked">◇</Node>} />
          <div className={styles.mapConnector}>│</div>
          <Row
            depth="018"
            nodes={
              <>
                <Node variant="elite">◆</Node>
                <Node>⚔</Node>
              </>
            }
          />
          <div className={styles.mapConnector}>│ ╲</div>
          <Row depth="017" nodes={<Node>~</Node>} />
          <div className={styles.mapConnector}>╱ │ ╲</div>
          <Row
            depth="016"
            nodes={
              <>
                <Node>☩</Node>
                <Node>⚔</Node>
                <Node>⌂</Node>
              </>
            }
          />
          <div className={styles.mapConnector}>╲ │ ╱</div>
          <Row depth="015" nodes={<Node variant="now">◉</Node>} />
        </div>
        <div className={`${styles.col} ${styles.mapRight}`}>
          <PixelFrame tone="gild" title="Hovered" style={{ flex: 1 }}>
            <div className={styles.boneBr} style={{ fontSize: 14 }}>
              D016 · Combat
            </div>
            <div className={styles.dim} style={{ fontSize: 11 }}>
              boneworm pack · 2
            </div>
            <div className={styles.stack} style={{ marginTop: 10, gap: 6 }}>
              <div className={`${styles.h} ${styles.between}`}>
                <span className={styles.dim}>win est.</span>
                <span className={styles.g}>58%</span>
              </div>
              <div className={`${styles.h} ${styles.between}`}>
                <span className={styles.dim}>reward</span>
                <span>12 gold · 1×T3</span>
              </div>
              <div className={`${styles.h} ${styles.between}`}>
                <span className={styles.dim}>torch cost</span>
                <span className={styles.a}>1</span>
              </div>
            </div>
            <Panel>
              <div className={styles.dim} style={{ fontSize: 10 }}>
                LEGEND
              </div>
              <div style={{ fontSize: 11, lineHeight: 1.8 }}>
                ⚔ combat · ◆ elite · ~ event
                <br />
                ⌂ shop · ☩ rest · ◇ cache
                <br />
                ◈ boss
              </div>
            </Panel>
            <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: 6 }}>
              <Button variant="primary" juicy>
                commit node <span style={{ color: 'var(--color-pit-gild)' }}>[↵]</span>
              </Button>
              <Button variant="danger" size="sm">
                retreat <span style={{ color: 'var(--color-pit-gild)' }}>[esc]</span>
              </Button>
            </div>
          </PixelFrame>
        </div>
      </div>
    </div>
  )
}
