import { createFileRoute, Link } from '@tanstack/react-router'
import {
  Bar,
  Button,
  Footer,
  Panel,
  PanelTitle,
  Pill,
  PixelFrame,
  Ribbon,
  Tier,
  Topbar,
} from '../../components/ui'
import styles from './wireframe.module.css'

export const Route = createFileRoute('/kit/combat')({
  component: CombatWireframe,
})

const LOADOUT: Array<[string, string, 0 | 1 | 2 | 3]> = [
  ['mhand', 'rust dagger', 3],
  ['ohand', 'bone buckler', 3],
  ['body', 'tattered cloak', 3],
  ['focus', 'whisper coil', 1],
]

function CombatWireframe() {
  return (
    <div className={styles.pit}>
      <div className={styles.kitHeader}>
        <Link to="/kit" className={styles.kitLink}>
          ← /kit
        </Link>
        <span className={styles.grow} />
        <span>08 · combat · wireframe (no logic)</span>
      </div>
      <Topbar
        title="combat · D015"
        hp="78/90"
        right={
          <>
            <Pill tone="c">focus 2</Pill>
            <Pill>1× ▶</Pill>
          </>
        }
      />
      <div className={styles.body}>
        <div className={styles.col} style={{ flex: 1 }}>
          <PixelFrame title="Aria" style={{ flex: 1 }}>
            <Bar kind="hp" pct={87} label={{ l: 'HP', v: '78 / 90' }} />
            <Bar kind="mtr" pct={42} label={{ l: 'Meter', v: '4,200 / 10,000' }} />
            <div className={`${styles.h} ${styles.between}`} style={{ fontSize: 11 }}>
              <span className={styles.dim}>FOCUS</span>
              <span className={styles.c}>● ● · ·</span>
            </div>
            <PanelTitle>Loadout</PanelTitle>
            <div className={styles.stack} style={{ gap: 4 }}>
              {LOADOUT.map(([slot, name, tier]) => (
                <div
                  key={slot}
                  className={styles.h}
                  style={{ fontSize: 11, padding: '4px 8px', border: '1px solid var(--color-pit-line)' }}
                >
                  <span
                    className={styles.dim}
                    style={{ width: 54, fontSize: 9, textTransform: 'uppercase' }}
                  >
                    {slot}
                  </span>
                  <Tier t={tier} />
                  <span>{name}</span>
                </div>
              ))}
            </div>
            <Ribbon>buffs · you</Ribbon>
            <div className={styles.h} style={{ gap: 6, flexWrap: 'wrap' }}>
              <Pill tone="r">burn 1 · 2t</Pill>
              <Pill tone="g">bleed 3</Pill>
            </div>
          </PixelFrame>
        </div>
        <div className={styles.col} style={{ flex: 1.5, background: 'var(--color-pit-ink-2)' }}>
          <PixelFrame tone="gild" title="Arena" style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
            <div className={styles.arena}>
              <div className={styles.arenaActor}>
                <div className={`${styles.arenaActorGlyph} ${styles.g}`}>@</div>
                <div className={styles.dim} style={{ fontSize: 10 }}>
                  aria
                </div>
              </div>
              <div className={styles.arenaActor}>
                <div className={`${styles.arenaActorGlyph} ${styles.r}`}>w</div>
                <div className={styles.dim} style={{ fontSize: 10 }}>
                  worm A
                </div>
              </div>
              <div className={styles.arenaActor}>
                <div className={`${styles.arenaActorGlyph} ${styles.r}`}>w</div>
                <div className={styles.dim} style={{ fontSize: 10 }}>
                  worm B
                </div>
              </div>
              <div className={styles.arenaFloat}>-22 ✦</div>
            </div>
            <div className={styles.combatToolbar}>
              <Button size="sm">1×</Button>
              <Button size="sm" variant="primary">
                2×
              </Button>
              <Button size="sm">4×</Button>
              <Button size="sm">‖</Button>
              <span className={styles.spacer} />
              <Button size="sm" juicy>
                focus <span style={{ color: 'var(--color-pit-gild)' }}>[F]</span>
              </Button>
              <Button size="sm" variant="danger">
                retreat <span style={{ color: 'var(--color-pit-gild)' }}>[R]</span>
              </Button>
            </div>
          </PixelFrame>
        </div>
        <div className={styles.col} style={{ flex: 1 }}>
          <PixelFrame title="Intent" style={{ flex: 1 }}>
            <Panel raised>
              <div className={`${styles.h} ${styles.between}`}>
                <span className={styles.boneBr}>worm A</span>
                <span className={styles.r}>37 / 50</span>
              </div>
              <Bar kind="enemy" pct={74} />
              <div className={`${styles.h} ${styles.between}`} style={{ marginTop: 6, fontSize: 11 }}>
                <span className={styles.dim}>next</span>
                <span className={styles.r}>bite 14 · 1.2s</span>
              </div>
            </Panel>
            <Panel raised>
              <div className={`${styles.h} ${styles.between}`}>
                <span className={styles.boneBr}>worm B</span>
                <span className={styles.r}>41 / 50</span>
              </div>
              <Bar kind="enemy" pct={82} />
              <div className={`${styles.h} ${styles.between}`} style={{ marginTop: 6, fontSize: 11 }}>
                <span className={styles.dim}>next</span>
                <span className={styles.r}>bite 14 · 0.8s</span>
              </div>
            </Panel>
            <Ribbon>log</Ribbon>
            <div className={styles.stack} style={{ gap: 2, fontSize: 11, overflow: 'auto' }}>
              <div>
                <span className={styles.dim}>[0:04]</span>{' '}
                <span className={styles.g}>crit</span> +22 → A
              </div>
              <div>
                <span className={styles.dim}>[0:03]</span> hit +12 → B
              </div>
              <div>
                <span className={styles.dim}>[0:02]</span>{' '}
                <span className={styles.r}>burn</span> tick −1
              </div>
              <div>
                <span className={styles.dim}>[0:01]</span> B applies burn 1
              </div>
              <div>
                <span className={styles.dim}>[0:00]</span> combat start
              </div>
            </div>
          </PixelFrame>
        </div>
      </div>
      <Footer
        items={[
          { k: 'space', l: 'pause' },
          { k: 'F', l: 'focus' },
          { k: 'R', l: 'retreat' },
          { k: 'esc', l: 'menu' },
        ]}
      />
    </div>
  )
}
