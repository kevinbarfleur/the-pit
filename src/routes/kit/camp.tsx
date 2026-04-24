import { createFileRoute, Link } from '@tanstack/react-router'
import {
  Button,
  Card,
  Menubar,
  PixelFrame,
  SegBar,
  Topbar,
} from '../../components/ui'
import styles from './wireframe.module.css'

export const Route = createFileRoute('/kit/camp')({
  component: CampWireframe,
})

function CampWireframe() {
  return (
    <div className={styles.pit}>
      <div className={styles.kitHeader}>
        <Link to="/kit" className={styles.kitLink}>
          ← /kit
        </Link>
        <span className={styles.grow} />
        <span>03 · camp hub · wireframe (no logic)</span>
      </div>
      <Topbar title="camp · descender @aria" gold="124" scrap={38} shards={2} torch="5/5" />
      <Menubar
        active="D"
        items={[
          { key: 'D', label: 'Delve' },
          { key: 'P', label: 'Passives' },
          { key: 'C', label: 'Cards' },
          { key: 'S', label: 'Shop' },
          { key: 'X', label: 'Codex' },
          { key: 'L', label: 'Leaderboard' },
        ]}
      />
      <div className={styles.body}>
        <div className={styles.col} style={{ flex: 1.5 }}>
          <PixelFrame title="Last run" right="D012 · 2h ago">
            <div className={`${styles.h} ${styles.between}`}>
              <span>D012 · Warden r.0</span>
              <span className={styles.r}>killed · boneworm</span>
            </div>
            <div className={styles.grid3} style={{ marginTop: 12 }}>
              <div>
                <div className={styles.dim} style={{ fontSize: 10 }}>
                  GOLD
                </div>
                <div className={styles.boneBr}>+84</div>
              </div>
              <div>
                <div className={styles.dim} style={{ fontSize: 10 }}>
                  SCRAP
                </div>
                <div className={styles.boneBr}>+12</div>
              </div>
              <div>
                <div className={styles.dim} style={{ fontSize: 10 }}>
                  SHARDS
                </div>
                <div className={styles.boneBr}>+1</div>
              </div>
            </div>
            <Button size="sm" variant="ghost" style={{ marginTop: 10 }}>
              view log →
            </Button>
          </PixelFrame>
          <PixelFrame title="Pinned upgrades" right="34 total" style={{ flex: 1 }}>
            <div className={styles.stack}>
              <div className={`${styles.h} ${styles.between}`}>
                <span>Torch capacity</span>
                <SegBar total={5} on={2} />
              </div>
              <div className={`${styles.h} ${styles.between}`}>
                <span>Scavenge II</span>
                <SegBar total={3} on={1} />
              </div>
              <div className={`${styles.h} ${styles.between}`}>
                <span>Thrift I</span>
                <SegBar total={2} on={0} />
              </div>
            </div>
            <Button size="sm" variant="ghost" style={{ marginTop: 12 }}>
              see all →
            </Button>
          </PixelFrame>
        </div>
        <div className={styles.col} style={{ flex: 1.3 }}>
          <PixelFrame tone="gild" title="Shop" right="3 offers">
            <div className={styles.stack}>
              <Card
                tier={2}
                name="Ember Hook"
                slot="mainhand"
                desc="on hit: burn 1"
                footer={
                  <>
                    <span className={styles.a}>45 gold</span>
                    <Button size="sm" variant="primary">
                      buy
                    </Button>
                  </>
                }
              />
              <Card
                tier={3}
                name="Rust Dagger"
                slot="mainhand"
                desc="+2 ATK · +0.1 spd"
                footer={
                  <>
                    <span className={styles.a}>18 gold</span>
                    <Button size="sm">buy</Button>
                  </>
                }
              />
            </div>
          </PixelFrame>
        </div>
      </div>
      <div className={styles.descendBar}>
        <Button variant="primary" size="lg" juicy style={{ padding: '14px 40px' }}>
          ▸ DESCEND INTO THE PIT <span style={{ color: 'var(--color-pit-gild)' }}>[D]</span>
        </Button>
        <span className={styles.dim} style={{ fontSize: 11 }}>
          depth D047 · runs 23 · cards 41/120
        </span>
      </div>
    </div>
  )
}
